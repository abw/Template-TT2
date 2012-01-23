#============================================================= -*-perl-*-
#
# t/option/chomp.t
#
# Test the PRE_CHOMP and POST_CHOMP options.
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
use Badger::Filesystem '$Bin Dir';
use Template::TT2::Test
    tests => 59,
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;

use Template::TT2::Constants ':chomp';
use constant ENGINE => 'Template::TT2';
my  $tdir = Dir($Bin, 'templates');

is( CHOMP_NONE, 0, 'CHOMP_NONE' );
is( CHOMP_ONE, 1, 'CHOMP_ONE' );
is( CHOMP_ALL, 1, 'CHOMP_ALL' );
is( CHOMP_COLLAPSE, 2, 'CHOMP_COLLAPSE' );
is( CHOMP_GREEDY, 3, 'CHOMP_GREEDY' );

my $blocks = {
    foo     => "\n[% foo %]\n",
    bar     => "\n[%- bar -%]\n",
    baz     => "\n[%+ baz +%]\n",
    ding    => "!\n\n[%~ ding ~%]\n\n!",
    dong    => "!\n\n[%= dong =%]\n\n!",
    dang    => "Hello[%# blah blah blah -%]\n!",
    winsux1 => "[% ding -%]\015\012[% dong %]",
    winsux2 => "[% ding -%]\015\012\015\012[% dong %]",
    winsux3 => "[% ding +%]\015\012[%- dong %]",
    winsux4 => "[% ding +%]\015\012\015\012[%- dong %]",
};


#------------------------------------------------------------------------
# tests without any CHOMP options set
#------------------------------------------------------------------------

my $tt2 = ENGINE->new({
    BLOCKS => $blocks,
});

my $vars = {
    foo  => 3.14,
    bar  => 2.718,
    baz  => 1.618,
    ding => 'Hello',
    dong => 'World'  
};

my $out;
ok( $tt2->process('foo', $vars, \$out), 'process foo' );
is( $out, "\n3.14\n", 'pi' );

$out = '';
ok( $tt2->process('bar', $vars, \$out), 'process bar' );
is( $out, "2.718", 'e' );

$out = '';
ok( $tt2->process('baz', $vars, \$out), 'process baz' );
is( $out, "\n1.618\n", 'phi' );

$out = '';
ok( $tt2->process('ding', $vars, \$out), 'process ding' );
is( $out, "!Hello!", 'hello' );

$out = '';
ok( $tt2->process('dong', $vars, \$out), 'process dong' );
is( $out, "! World !", 'world' );

$out = '';
ok( $tt2->process('dang', $vars, \$out), 'process dang' );
is( $out, "Hello!", 'hello again' );


#------------------------------------------------------------------------
# tests with the PRE_CHOMP option set
#------------------------------------------------------------------------

$tt2 = ENGINE->new({
    PRE_CHOMP => 1,
    BLOCKS => $blocks,
});

$out = '';
ok( $tt2->process('foo', $vars, \$out), 'process foo pre chomp');
is( $out, "3.14\n", 'pre pi' );

$out = '';
ok( $tt2->process('bar', $vars, \$out), 'process bar pre chomp');
is( $out, "2.718", 'pre e' );

$out = '';
ok( $tt2->process('baz', $vars, \$out), 'process baz pre chomp');
is( $out, "\n1.618\n", 'pre phi' );

$out = '';
ok( $tt2->process('ding', $vars, \$out), 'process ding pre chomp');
is( $out, "!Hello!", 'pre hello' );

$out = '';
ok( $tt2->process('dong', $vars, \$out), 'process dong pre chomp');
is( $out, "! World !", 'pre world' );

$out = '';
ok( $tt2->process('dang', $vars, \$out), 'process dang pre chomp');
is( $out, "Hello!", 'pre hello again' );


#------------------------------------------------------------------------
# tests with the POST_CHOMP option set
#------------------------------------------------------------------------

$tt2 = ENGINE->new({
    POST_CHOMP   => 1,
    INCLUDE_PATH => [$tdir],
    BLOCKS       => $blocks,
});

$out = '';
ok( $tt2->process('foo', $vars, \$out), 'process foo post chomp');
is( $out, "\n3.14", 'post pi' );

$out = '';
ok( $tt2->process('bar', $vars, \$out), 'process bar post chomp');
is( $out, "2.718", 'post e' );

$out = '';
ok( $tt2->process('baz', $vars, \$out), 'process baz post chomp');
is( $out, "\n1.618\n", 'post phi' );

$out = '';
ok( $tt2->process('ding', $vars, \$out), 'process ding post chomp');
is( $out, "!Hello!", 'post hello' );

$out = '';
ok( $tt2->process('dong', $vars, \$out), 'process dong post chomp');
is( $out, "! World !", 'post world' );

$out = '';
ok( $tt2->process('dang', $vars, \$out), 'process dang post chomp');
is( $out, "Hello!", 'post hello again' );

$out = '';
ok( $tt2->process('winsux1', $vars, \$out), 'winsux1' );
is( od($out), "HelloWorld", 'winsux1 out' );

$out = '';
ok( $tt2->process('winsux2', $vars, \$out), 'winsux2' );
is( od($out), 'Hello\015\012World', 'winsux2 out' );

$out = '';
ok( $tt2->process('winsux3', $vars, \$out), 'winsux3' );
is( od($out), "HelloWorld", 'winsux3 out' );

$out = '';
ok( $tt2->process('winsux4', $vars, \$out), 'winsux4' );
is( od($out), 'Hello\015\012World', 'winsux4 out' );

$out = '';
ok( $tt2->process('dos_newlines', $vars, \$out), 'dos_newlines' );
is( od($out), "HelloWorld", 'dos_newlines out' );

sub od{
    join(
        '', 
        map {
            my $ord = ord($_);
            ($ord > 127 || $ord < 32 )
                ? sprintf '\0%lo', $ord
                : $_
        } 
        split //, shift()
    );
}

my $engines = {
    tt_pre_none  => ENGINE->new(PRE_CHOMP  => CHOMP_NONE),
    tt_pre_one   => ENGINE->new(PRE_CHOMP  => CHOMP_ONE),
    tt_pre_all   => ENGINE->new(PRE_CHOMP  => CHOMP_ALL),
    tt_pre_coll  => ENGINE->new(PRE_CHOMP  => CHOMP_COLLAPSE),
    tt_post_none => ENGINE->new(POST_CHOMP => CHOMP_NONE),
    tt_post_one  => ENGINE->new(POST_CHOMP => CHOMP_ONE),
    tt_post_all  => ENGINE->new(POST_CHOMP => CHOMP_ALL),
    tt_post_coll => ENGINE->new(POST_CHOMP => CHOMP_COLLAPSE),
};

test_expect(
    engines => $engines,
    engine  => $engines->{ tt_pre_none },
);


__DATA__

#------------------------------------------------------------------------
# tt_pre_none
#------------------------------------------------------------------------
-- test no chomping --
begin[% a = 10; b = 20 %]
     [% a %]
     [% b %]
end
-- expect --
begin
     10
     20
end


#------------------------------------------------------------------------
# tt_pre_one
#------------------------------------------------------------------------
-- test pre chomp one --
-- use tt_pre_one --
begin[% a = 10; b = 20 %]
     [% a %]
     [% b %]
end
-- expect --
begin1020
end


#------------------------------------------------------------------------
# tt_pre_all
#------------------------------------------------------------------------
-- test pre chomp all --
-- use tt_pre_all --
begin[% a = 10; b = 20 %]
     [% a %]
     [% b %]
end
-- expect --
begin1020
end


#------------------------------------------------------------------------
# tt_pre_coll
#------------------------------------------------------------------------
-- test pre chomp collapse --
-- use tt_pre_coll --
begin[% a = 10; b = 20 %]
     [% a %]
     [% b %]
end
-- expect --
begin 10 20
end


#------------------------------------------------------------------------
# tt_post_none
#------------------------------------------------------------------------
-- test post chomp none --
-- use tt_post_none --
begin[% a = 10; b = 20 %]
     [% a %]
     [% b %]
end
-- expect --
begin
     10
     20
end


#------------------------------------------------------------------------
# tt_post_all
#------------------------------------------------------------------------
-- test post chomp all --
-- use tt_post_all --
begin[% a = 10; b = 20 %]
     [% a %]
     [% b %]
end
-- expect --
begin     10     20end


#------------------------------------------------------------------------
# tt_post_one
#------------------------------------------------------------------------
-- test post chomp one --
-- use tt_post_one --
begin[% a = 10; b = 20 %]
     [% a %]
     [% b %]
end
-- expect --
begin     10     20end


#------------------------------------------------------------------------
# tt_post_coll
#------------------------------------------------------------------------
-- test post chomp collapse --
-- use tt_post_coll --
begin[% a = 10; b = 20 %]     
[% a %]     
[% b %]     
end
-- expect --
begin 10 20 end

