#============================================================= -*-perl-*-
#
# t/option/constants.t
#
# Test constant folding via Template::TT2::Namespace::Constants
#
# Run with -h option for help.
#
# Written by Andy Wardley <abw@andywardley.com>
#
# Copyright (C) 1996-2012 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib     => '../../lib';

use Template::TT2::Test
    tests   => 28,
    debug   => 'Template::TT2::Namespace::Constants',
    args    => \@ARGV;

use constant ENGINE => 'Template::TT2';

use Template::TT2::Stash;
use Template::TT2::Directive;
use Template::TT2::Parser;
use Template::TT2::Namespace::Constants;

my $n = 0;
my $constants = {
    author => 'Andy \'Badger\' Wardley',
    single => 'foo\'bar',
    double => "foo'bar",
    joint  => ', ',
    col => {
        back => '#ffffff',
        text => '#000000',
    },
    counter => sub { $n++ },
};

my $namespace = Template::TT2::Namespace::Constants->new( $constants );
ok( $namespace, 'created constants namespace' );

is( $namespace->ident([ 'constants', 0, "'author'", 0 ]), q{'Andy \'Badger\' Wardley'}, 
    'author match' );
is( $namespace->ident([ 'constants', 0, "'single'", 0 ]), "'foo\\'bar'", 
    'single match' );
is( $namespace->ident([ 'constants', 0, "'double'", 0 ]), "'foo\\'bar'", 
    'double match' );
is( $namespace->ident([ 'constants', 0, "'col'", 0, "'back'", 0 ]), "'#ffffff'", 
    'col.back match' );
is( $namespace->ident([ 'constants', 0, "'col'", 0, "'text'", 0 ]), "'#000000'", 
    'col.text match' );

my $factory = Template::TT2::Directive->new({
    NAMESPACE => {
        const => $namespace,
    }
});
ok( $factory, 'created Template::TT2::Directive factory' );

my $parser = Template::TT2::Parser->new( FACTORY => $factory );
ok( $parser, 'created Template::TT2::Parser parser' );

my $parsed = $parser->parse(<<EOF);
hello [% const.author %]
[% "back is \$const.col.back" %] and text is [% const.col.text %]
but a col is still a [% col.user %]
EOF

die "parser error: ", $parser->error(), "\n"
    unless $parsed;

my $text = $parsed->{ BLOCK };

ok( scalar $text =~ /'Andy \\'Badger\\' Wardley'/, 'author folded' );
ok( scalar $text =~ /"back is " . '#ffffff'/, 'col.back folded' );
ok( scalar $text =~ /stash->get\(\['col', 0, 'user', 0\]\)/, 'col.user unfolded' );


$parser = Template::TT2::Parser->new({
    NAMESPACE => {
        const => $namespace,
    }
});

ok( $parser, 'created Template::TT2::Parser parser' );

$parsed = $parser->parse(<<EOF);
hello [% const.author %]
[% "back is \$const.col.back" %] and text is [% const.col.text %]
but a col is still a [% col.user %]
EOF

die "parser error: ", $parser->error(), "\n"
    unless $parsed;

$text = $parsed->{ BLOCK };

ok( scalar $text =~ /'Andy \\'Badger\\' Wardley'/, 'author folded' );
ok( scalar $text =~ /"back is " . '#ffffff'/, 'col.back folded' );
ok( scalar $text =~ /stash->get\(\['col', 0, 'user', 0\]\)/, 'col.user unfolded' );

#------------------------------------------------------------------------

my $tt1 = Template::TT2->new({
    NAMESPACE => {
        const => $namespace,
    },
});
ok( $tt1, 'created tt1' );

my $const2 = {
    author => 'abw',
    joint  => ' is the new ',
    col => {
        back => 'orange',
        text => 'black',
    },
    fave => 'back',
};

my $tt2 = Template::TT2->new({
    CONSTANTS => $const2,
});
ok( $tt2, 'created tt2' );

my $tt3 = Template::TT2->new({
    CONSTANTS => $const2,
    CONSTANTS_NAMESPACE => 'const',
});
ok( $tt3, 'created tt3' );

my $engines = {
    tt1 => $tt1, 
    tt2 => $tt2, 
    tt3 => $tt3,
};

my $vars = {
    col => {
        user => 'red',
        luza => 'blue',
    },
    constants => $constants,
};

test_expect(
    engine  => $tt1,
    engines => $engines, 
    vars    => $vars
);

__DATA__
-- test constants --
hello [% const.author %]
[% "back is $const.col.back" %] and text is [% const.col.text %]
col.user is [% col.user %]
-- expect --
hello Andy 'Badger' Wardley
back is #ffffff and text is #000000
col.user is red

-- test virtual methods on constants --
# look ma!  I can even call virtual methods on contants!
[% const.col.keys.sort.join(', ') %]
-- expect --
back, text

-- test passing constant arguments --
# and even pass constant arguments to constant virtual methods!
[% const.col.keys.sort.join(const.joint) %]
-- expect --
back, text

-- test constant subs --
# my constants can be subs, etc.
zero [% const.counter %]
one [% const.counter %]
-- expect --
zero 0
one 1

-- test engine2 --
-- use tt2 --
[% "$constants.author thinks " %]
[%- constants.col.values.sort.reverse.join(constants.joint) %]
-- expect --
abw thinks orange is the new black

-- test engine3 --
-- use tt3 --
[% "$const.author thinks " -%]
[% const.col.values.sort.reverse.join(const.joint) %]
-- expect --
abw thinks orange is the new black

-- test missing constant --
no [% const.foo %]?
-- expect --
no ?

-- test interpolated --
fave [% const.fave %]
col  [% const.col.${const.fave} %]
-- expect --
fave back
col  orange

-- test defer references --
-- use tt2 --
[% "$key\n" FOREACH key = constants.col.keys.sort %]
-- expect --
back
text

-- test assign to a constant --
-- use tt3 --
a: [% const.author %]
b: [% const.author = 'Fred Smith' %]
c: [% const.author %]
-- expect --
a: abw
b: 
c: abw
