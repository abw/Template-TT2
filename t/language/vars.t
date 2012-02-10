#============================================================= -*-perl-*-
#
# t/vars.t
#
# Template script testing variable use.
#
# Run with -h option for help.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 1996-2012 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib         => '../../lib ../../blib/lib ../../blib/arch',
    Filesystem  => 'Bin';

use Template::TT2::Test
    tests   => 61,
    debug   => 'Template::TT2::Parser',
    args    => \@ARGV;

use constant 
    ENGINE  => 'Template::TT2';

use Template::TT2;
use Template::TT2::Stash;
use Template::TT2::Constants 'TT2_EXCEPTION';


#use Template::Constants qw( :status );

# sample data
my ($a, $b, $c, $d, $e, $f, $g, $h, $i, $j, $k, $l, $m, 
    $n, $o, $p, $q, $r, $s, $t, $u, $v, $w, $x, $y, $z) = 
    qw( alpha bravo charlie delta echo foxtrot golf hotel india 
        juliet kilo lima mike november oscar papa quebec romeo 
        sierra tango umbrella victor whisky x-ray yankee zulu );

my @days   = qw( Monday Tuesday Wednesday Thursday Friday Saturday Sunday );
my $day    = -1;
my $count  = 0;
my $params = { 
    'a' => $a,
    'b' => $b,
    'c' => $c,
    'd' => $d,
    'e' => $e,
    'f' => {
        'g' => $g,
        'h' => $h,
        'i' => {
            'j' => $j,
            'k' => $k,
        },
    },
    'g' => "solo $g",
    'l' => $l,
    'r' => $r,
    's' => $s,
    't' => $t,
    'w' => $w,
    'n'      => sub { $count },
    'up'     => sub { ++$count },
    'down'   => sub { --$count },
    'reset'  => sub { $count = shift(@_) || 0 },
    'undef'  => sub { undef },
    'zero'   => sub { 0 },
    'one'    => sub { 'one' },
    'halt'   => sub { die TT2_EXCEPTION->new( type => 'stop', info => 'stopped') },
    'join'   => sub { join(shift, @_) },
    'split'  => sub { my $s = shift; $s = quotemeta($s); 
                      my @r = split(/$s/, shift); \@r },
    'magic'  => {
        'chant' => 'Hocus Pocus',
        'spell' => sub { join(" and a bit of ", @_) },
    }, 
    'day'    => {
        'prev' => \&yesterday,
        'this' => \&today,
        'next' => \&tomorrow,
    },
    'belief'   => \&belief,
    'people'   => sub { return qw( Tom Dick Larry ) },
    'gee'      =>  'g',
    "letter$a" => "'$a'",
    'yankee'   => \&yankee,
    '_private' => 123,
    '_hidden'  => 456,
    expose     => sub { undef $Template::TT2::Stash::PRIVATE },
    add        => sub { $_[0] + $_[1] },

    # don't define a 'z' - DEFAULT test relies on its non-existance
};

my $engines = {
    default => ENGINE->new({ INTERPOLATE => 1, ANYCASE => 1 }),
    notcase => ENGINE->new({ INTERPOLATE => 1, ANYCASE => 0 }),
};

test_expect(
    vars    => $params,
    engine  => $engines->{ default },
    engines => $engines,
);


#------------------------------------------------------------------------
# subs 
#------------------------------------------------------------------------

sub yesterday {
    return "All my troubles seemed so far away...";
}

sub today {
    my $when = shift || 'Now';
    return "$when it looks as though they're here to stay.";
}

sub tomorrow {
    my $dayno = shift;
    unless (defined $dayno) {
        $day++;
        $day %= 7;
        $dayno = $day;
    }
    return $days[$dayno];
}

sub belief {
    my @beliefs = @_;
    my $b = join(' and ', @beliefs);
    $b = '<nothing>' unless length $b;
    return "Oh I believe in $b.";
}

sub yankee {
    my $a = [];
    $a->[1] = { a => 1 };
    $a->[3] = { a => 2 };
    return $a;
}

__DATA__

#------------------------------------------------------------------------
# GET 
#------------------------------------------------------------------------

-- test nosuchvariable --
[[% nosuchvariable %]]
[$nosuchvariable]
-- expect --
[]
[]

-- test a GET get --
[% a %]
[% GET b %]
[% get c %]
-- expect --
alpha
bravo
charlie

-- test b GET b --
[% b %] [% GET b %]
-- expect --
bravo bravo

-- test interpolate --
$a $b ${c} ${d} [% e %]
-- expect --
alpha bravo charlie delta echo

-- test interpolate with braces --
[% letteralpha %]
[% ${"letter$a"} %]
[% GET ${"letter$a"} %]
-- expect --
'alpha'
'alpha'
'alpha'

-- test dot interpolate --
[% f.g %] [% f.$gee %] [% f.${gee} %]
-- expect --
golf golf golf

-- test dot interpolate with braces --
[% GET f.h %] [% get f.h %] [% f.${'h'} %] [% get f.${'h'} %]
-- expect --
hotel hotel hotel hotel

-- test interpolate scoped around dot --
$f.h ${f.g} ${f.h}.gif
-- expect --
hotel golf hotel.gif

-- test GET get dotted --
[% f.i.j %] [% GET f.i.j %] [% get f.i.k %]
-- expect --
juliet juliet kilo

-- test braced quotes --
[% f.i.j %] $f.i.k [% f.${'i'}.${"j"} %] ${f.i.k}.gif
-- expect --
juliet kilo juliet kilo.gif

-- test double quote interpolation --
[% 'this is literal text' %]
[% GET 'so is this' %]
[% "this is interpolated text containing $r and $f.i.j" %]
[% GET "$t?" %]
[% "<a href=\"${f.i.k}.html\">$f.i.k</a>" %]
-- expect --
this is literal text
so is this
this is interpolated text containing romeo and juliet
tango?
<a href="kilo.html">kilo</a>

-- test assign double quoted interpolation --
[% name = "$a $b $w" -%]
Name: $name
-- expect --
Name: alpha bravo whisky

-- test join dotted sub --
[% join('--', a b, c, f.i.j) %]
-- expect --
alpha--bravo--charlie--juliet

-- test split sub --
[% text = 'The cat sat on the mat' -%]
[% FOREACH word IN split(' ', text) -%]<$word> [% END %]
-- expect --
<The> <cat> <sat> <on> <the> <mat> 

-- test magic chant -- 
[% magic.chant %] [% GET magic.chant %]
[% magic.chant('foo') %] [% GET magic.chant('foo') %]
-- expect --
Hocus Pocus Hocus Pocus
Hocus Pocus Hocus Pocus

-- test magic spell -- 
<<[% magic.spell %]>>
[% magic.spell(a b c) %]
-- expect --
<<>>
alpha and a bit of bravo and a bit of charlie

-- test one one one --
[% one %] [% one('two', 'three') %] [% one(2 3) %]
-- expect --
one one one

-- test day.prev day.next --
[% day.prev %]
[% day.this %]
[% belief('yesterday') %]
-- expect --
All my troubles seemed so far away...
Now it looks as though they're here to stay.
Oh I believe in yesterday.

-- test yesterday --
Yesterday, $day.prev
$day.this
${belief('yesterday')}
-- expect --
Yesterday, All my troubles seemed so far away...
Now it looks as though they're here to stay.
Oh I believe in yesterday.

-- test caseless --
-- use notcase --
[% day.next %]
$day.next
-- expect --
Monday
Tuesday

-- test day next trickery --
[% FOREACH [ 1 2 3 4 5 ] %]$day.next [% END %]
-- expect --
Wednesday Thursday Friday Saturday Sunday 

-- test halt --
-- use default --
before
[% halt %]
after

-- expect --
before

-- test loop count --
[% FOREACH k = yankee -%]
[% loop.count %]. [% IF k; k.a; ELSE %]undef[% END %]
[% END %]
-- expect --
1. undef
2. 1
3. undef
4. 2


#------------------------------------------------------------------------
# CALL 
#------------------------------------------------------------------------

-- test CALL --
before [% CALL a %]a[% CALL b %]n[% CALL c %]d[% CALL d %] after
-- expect --
before and after

-- test CALL undef --
..[% CALL undef %]..
-- expect --
....

-- test CALL zero  --
..[% CALL zero %]..
-- expect --
....

-- test CALL n --
..[% n %]..[% CALL n %]..
-- expect --
..0....

-- test CALL up --
..[% up %]..[% CALL up %]..[% n %]
-- expect --
..1....2

-- test CALL reset --
[% CALL reset %][% n %]
-- expect --
0

-- test CALL reset(100) --
[% CALL reset(100) %][% n %]
-- expect --
100

#------------------------------------------------------------------------
# SET 
#------------------------------------------------------------------------

-- test a=a --
[% a = a %] $a
[% a = b %] $a
-- expect --
 alpha
 bravo

-- test SET a=a -- 
[% SET a = a %] $a
[% SET a = b %] $a
[% SET a = $c %] [$a]
[% SET a = $gee %] $a
[% SET a = ${gee} %] $a
-- expect --
 alpha
 bravo
 []
 solo golf
 solo golf

-- test a=b --
[% a = b
   b = c
   c = d
   d = e
%][% a %] [% b %] [% c %] [% d %]
-- expect --
bravo charlie delta echo

-- test SET a=c --
[% SET
   a = c
   b = d
   c = e
%]$a $b $c
-- expect --
charlie delta echo

-- test set 'include' --
[% 'a' = d
   'include' = e
   'INCLUDE' = f.g
%][% a %]-[% ${'include'} %]-[% ${'INCLUDE'} %]
-- expect --
delta-echo-golf

-- test assign dotted --
[% a = f.g %] $a
[% a = f.i.j %] $a
-- expect --
 golf
 juliet

-- test f.g = r --
[% f.g = r %] $f.g
[% f.i.j = s %] $f.i.j
[% f.i.k = f.i.j %] ${f.i.k}
-- expect --
 romeo
 sierra
 sierra

-- test user hash --
[% user = {
    id = 'abw'
    name = 'Andy Wardley'
    callsign = "[-$a-$b-$w-]"
   }
-%]
${user.id} ${ user.id } $user.id ${user.id}.gif
[% message = "$b: ${ user.name } (${user.id}) ${ user.callsign }" -%]
MSG: $message
-- expect --
abw abw abw abw.gif
MSG: bravo: Andy Wardley (abw) [-alpha-bravo-whisky-]

-- test bogon generator --
[% product = {
     id   => 'XYZ-2000',
     desc => 'Bogon Generator',
     cost => 678,
   }
-%]
The $product.id $product.desc costs \$${product.cost}.00
-- expect --
The XYZ-2000 Bogon Generator costs $678.00

-- test g spot --
[% data => {
       g => 'my data'
   }
   complex = {
       gee => 'g'
   }
-%]
[% data.${complex.gee} %]
-- expect --
my data


#------------------------------------------------------------------------
# DEFAULT
#------------------------------------------------------------------------

-- test DEFAULT --
[% a %]
[% DEFAULT a = b -%]
[% a %]
-- expect --
alpha
alpha

-- test DEFAULT a=b --
[% a = '' -%]
[% DEFAULT a = b -%]
[% a %]
-- expect --
bravo

-- test DEFAULT a=c --
[% a = ''   b = '' -%]
[% DEFAULT 
   a = c
   b = d
   z = r
-%]
[% a %] [% b %] [% z %]
-- expect --
charlie delta romeo


#------------------------------------------------------------------------
# 'global' vars
#------------------------------------------------------------------------

-- test global.version set --
[% global.version = '3.14' -%]
Version: [% global.version %]
-- expect --
Version: 3.14

-- test global.version get --
Version: [% global.version %]
-- expect --
Version: 3.14

-- test global.newversion --
[% global.newversion = global.version + 1 -%]
Version: [% global.version %]
Version: [% global.newversion %]
-- expect --
Version: 3.14
Version: 4.14

-- test get both globals --
Version: [% global.version %]
Version: [% global.newversion %]
-- expect --
Version: 3.14
Version: 4.14

-- test hash import --
[% hash1 = {
      foo => 'Foo',
      bar => 'Bar',
   }
   hash2 = {
      wiz => 'Wiz',
      woz => 'Woz',
   }
-%]
[% hash1.import(hash2) -%]
keys: [% hash1.keys.sort.join(', ') %]
-- expect --
keys: bar, foo, wiz, woz

-- test import mage --
[% mage = { 
      name    =>    'Gandalf', 
      aliases =>  [ 'Mithrandir', 'Olorin', 'Incanus' ] 
   }
-%]
[% import(mage) -%]
[% name %]
[% aliases.join(', ') %]
-- expect --
Gandalf
Mithrandir, Olorin, Incanus


# test private variables
-- test private variables --
[[% _private %]][[% _hidden %]]
-- expect --
[][]

# make them visible
-- test exposed variables --
[% CALL expose -%]
[[% _private %]][[% _hidden %]]
-- expect --
[123][456]


# Stas reported a problem with spacing in expressions but I can't
# seem to reproduce it...
-- test expression spacing --
[% a = 4 -%]
[% b=6 -%]
[% c = a + b -%]
[% d=a+b -%]
[% c %]/[% d %]
-- expect --
10/10

-- test abc=123 --
[% a = 1
   b = 2
   c = 3
-%]
[% d = 1+1 %]d: [% d %]
[% e = a+b %]e: [% e %]
-- expect --
d: 2
e: 3


# these tests check that the incorrect precedence in the parser has now
# been fixed, thanks to Craig Barrat.
-- test parser precedence --
[%  1 || 0 && 0  # should be 1 || (0&&0), not (1||0)&&0 %]
-- expect --
1

-- test more parser precedence --
[%  1 + !0 + 1  # should be 1 + (!0) + 0, not 1 + !(0 + 1) %]
-- expect --
3

-- test even more parser precedence --
[% "x" _ "y" == "y"; ','  # should be ("x"_"y")=="y", not "x"_("y"=="y") %]
-- expect --
,

-- test How many parser precedence test --
[% "x" _ "y" == "xy"      # should be ("x"_"y")=="xy", not "x"_("y"=="xy") %]
-- expect --
1

-- test must a man run --
[% add(3, 5) %]
-- expect --
8

-- test before you can call him a man? --
[% add(3 + 4, 5 + 7) %]
-- expect --
19

-- test The answer my friend --
[% a = 10;
   b = 20;
   c = 30;
   add(add(a,b+1),c*3);
%]
-- expect --
121

-- test is a about ten --
[% a = 10;
   b = 20;
   c = 30;
   d = 5;
   e = 7;
   add(a+5, b < 10 ? c : d + e*5);
-%]
-- expect --
55

