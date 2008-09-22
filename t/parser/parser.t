#============================================================= -*-perl-*-
#
# t/parser/parser.t
#
# Test the Template::TT2::Parser module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Template::TT2::Test
    tests  => 25,
    debug  => 'Template::TT2::Base Template::TT2::Parser',
    args   => \@ARGV,
    import => 'callsign :default';

use Template::TT2;
use Template::TT2::Parser;
pass("Loaded Template::TT2::Parser module");

my $parser = Template::TT2::Parser->new;
ok( $parser, 'created Template::TT2::Parser object' );

my $result = $parser->parse("Hello [% name %]");
ok( $result, 'got parsed result' );

our $WARNING;

my $p2 = Template::TT2::Parser->new({
    on_warn   => sub { $WARNING = shift },
    START_TAG => '\[\*',
    END_TAG   => '\*\]',
    ANYCASE   => 1,
    PRE_CHOMP => 1,
    V1DOLLAR  => 1,         # DEPRECATED
});

# check we got the deprecated option warning
is( $WARNING, 'The V1DOLLAR option has been deprecated', 'V1DOLLAR option is deprecated' );

# test new/old styles
my $s1 = $p2->new_style( { TAG_STYLE => 'metatext', PRE_CHOMP => 0, POST_CHOMP => 1 } );
ok( $s1, 'created new parser style' );
is( $s1->{ START_TAG  }, '%%', 'got new START_TAG' );
is( $s1->{ PRE_CHOMP  }, 0, 'got new PRE_CHOMP' );
is( $s1->{ POST_CHOMP }, 1, 'got new POST_CHOMP' );

my $s2 = $p2->old_style();
ok( $s2, 'reverted to old style' );
is( $s2->{ START_TAG  }, '\[\*', 'got old style START_TAG' );
is( $s2->{ PRE_CHOMP  }, 1, 'got old PRE_CHOMP' );
is( $s2->{ POST_CHOMP }, 0, 'got old POST_CHOMP' );

my $p3 = Template::TT2::Parser->new({
    TAG_STYLE   => 'html',
    POST_CHOMP  => 1,
    ANYCASE     => 1,
    INTERPOLATE => 1,
});

my $p4 = Template::TT2::Parser->new({
    ANYCASE => 0,
});

my $tt = {
    tt1 => Template::TT2->new(ANYCASE => 1),
    tt2 => Template::TT2->new(PARSER => $p2),
    tt3 => Template::TT2->new(PARSER => $p3),
    tt4 => Template::TT2->new(PARSER => $p4),
};

my $replace = &callsign;
$replace->{ alist  } = [ 'foo', 0, 'bar', 0 ];
$replace->{ wintxt } = "foo\r\n\r\nbar\r\n\r\nbaz";
$replace->{ data   } = { first => 11, last => 42 };

test_expect({
    engines => $tt,
    engine  => $tt->{ tt1 },
    vars    => $replace,
});


__DATA__
#------------------------------------------------------------------------
# tt1 - ANYCASE set
#------------------------------------------------------------------------
-- test ANYCASE option --
start $a
[% BLOCK a %]
this is a
[% END %]
=[% INCLUDE a %]=
=[% include a %]=
end
-- expect --
start $a

=
this is a
=
=
this is a
=
end

-- test ANYCASE post-dot protection --
[% data.first; ' to '; data.last %]
-- expect --
11 to 42


#------------------------------------------------------------------------
# tt2 has different TAG_STYLE
#------------------------------------------------------------------------
-- test TAG_STYLE --
-- use tt2 --
begin
[% this will be ignored %]
[* a *]
end
-- expect --
begin
[% this will be ignored %]alpha
end

-- test V1DOLLAR is now deprecated --
$b does nothing: 
[* c = 'b'; 'hello' *]
stuff: 
[* $c *]
-- expect --
$b does nothing: hello
stuff: bravo

#------------------------------------------------------------------------
# tt3 has HTML TAG_STYLE and INTERPOLATE set
#------------------------------------------------------------------------
-- test HTML TAG_STYLE --
-- use tt3 --
begin
[% this will be ignored %]
<!-- a -->
end

-- expect --
begin
[% this will be ignored %]
alphaend

-- test INTERPOLATE option --
$b does something: 
<!-- c = 'b'; 'hello' -->
stuff: 
<!-- $c -->
end
-- expect --
bravo does something: 
hellostuff: 
bravoend


#------------------------------------------------------------------------
# tt4 has ANYCASE set explicitly to 0
#------------------------------------------------------------------------
-- test ANYCASE off --
-- use tt4 --
start $a[% 'include' = 'hello world' %]
[% BLOCK a -%]
this is a
[%- END %]
=[% INCLUDE a %]=
=[% include %]=
end
-- expect --
start $a

=this is a=
=hello world=
end


#------------------------------------------------------------------------
# misc tests
#-----------------------------------------------------------------------

-- test quotes across multiple lines --
[% sql = "
     SELECT *
     FROM table"
-%]
SQL: [% sql %]
-- expect --
SQL: 
     SELECT *
     FROM table

-- test escaped characters in double quotes --
[% a = "\a\b\c\ndef" -%]
a: [% a %]
-- expect --
a: abc
def

-- test more backslashes --
[% a = "\f\o\o"
   b = "a is '$a'"
   c = "b is \$100"
-%]
a: [% a %]  b: [% b %]  c: [% c %]

-- expect --
a: foo  b: a is 'foo'  c: b is $100

-- test escaped start/end tags --
[% tag = {
      a => "[\%"
      z => "%\]"
   }
   quoted = "[\% INSERT foo %\]"
-%]
A directive looks like: [% tag.a %] INCLUDE foo [% tag.z %]
The quoted value is [% quoted %]

-- expect --
A directive looks like: [% INCLUDE foo %]
The quoted value is [% INSERT foo %]

-- test Win32 newlines --
=[% wintxt | replace("(\r\n){2,}", "\n<break>\n") %]

-- expect --
=foo
<break>
bar
<break>
baz

-- test newlines and tabs --
[% nl  = "\n"
   tab = "\t"
-%]
blah blah[% nl %][% tab %]x[% nl; tab %]y[% nl %]end
-- expect --
blah blah
	x
	y
end


