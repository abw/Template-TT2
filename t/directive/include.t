#============================================================= -*-perl-*-
#
# t/directive/include.t
#
# Template script testing the INCLUDE and PROCESS directives.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Template::TT2::Test
    tests => 23,
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;

use Template::TT2;
use Badger::Filesystem '$Bin Dir';
use constant ENGINE => 'Template::TT2';

my $tdir = Dir($Bin, 'templates');

my ($a, $b, $c, $d, $e, $f, $g, $h, $i, $j, $k, $l, $m, 
    $n, $o, $p, $q, $r, $s, $t, $u, $v, $w, $x, $y, $z) = 
	qw( alpha bravo charlie delta echo foxtrot golf hotel india 
	    juliet kilo lima mike november oscar papa quebec romeo 
	    sierra tango umbrella victor whisky x-ray yankee zulu );

my $replace = { 
    'a' => $a,
    'b' => $b,
    'c' => {
	    'd' => $d,
	    'e' => $e,
	    'f' => {
	        'g' => $g,
	        'h' => $h,
	    },
    },
    'r'    => $r,
    's'	   => $s,
    't'    => $t,
};

my $tproc = ENGINE->new({ 
    INTERPOLATE  => 1,
    INCLUDE_PATH => $tdir,
    TRIM         => 1,
    AUTO_RESET   => 0,
    DEFAULT      => 'default',
});

my $incpath = [ $tdir, '/nowhere' ];
my $tt_reset = ENGINE->new({ 
    INTERPOLATE  => 1,
    INCLUDE_PATH => [ $tdir, '/nowhere/in/particular', $tdir->dir('subdir') ],
    TRIM         => 1,
    RECURSION    => 1,
    DEFAULT      => 'bad_default',
});
#$incpath->[1] = "$dir/lib";

# we want to process 'metadata' directly so that the correct top-level
# 'template' reference is set instead of 'input text'
my $output;
$tproc->process('metadata', $replace, \$output);
ok( $output, 'processed metadata' );
$replace->{ metaout } = $output;
$replace->{ metamod } = $tdir->file('metadata')->modified;

my $engines = {
    default => $tproc,
    reset   => $tt_reset,
};
test_expect(
    vars    => $replace,
    engine  => $engines->{ default },
    engines => $engines
);

__DATA__

-- test INCLUDE on remote block --
[% a %]
[% PROCESS incblock -%]
[% b %]
[% INCLUDE first_block %]
-- expect --
alpha
bravo
this is my first block, a is set to 'alpha'

-- test INCLUDE first block again --
[% INCLUDE first_block %]
-- expect --
this is my first block, a is set to 'alpha'

-- test INCLUDE first_block with args --
[% INCLUDE first_block a = 'abstract' %]
[% a %]
-- expect --
this is my first block, a is set to 'abstract'
alpha

-- test first_block again --
[% INCLUDE 'first_block' a = t %]
[% a %]
-- expect --
this is my first block, a is set to 'tango'
alpha

-- test second_block --
[% INCLUDE 'second_block' %]
-- expect --
this is my second block, a is initially set to 'alpha' and 
then set to 'sierra'  b is bravo  m is 98

-- test second_block with args --
[% INCLUDE second_block a = r, b = c.f.g, m = 97 %]
[% a %]
-- expect --
this is my second block, a is initially set to 'romeo' and 
then set to 'sierra'  b is golf  m is 97
alpha

-- test foo --
FOO: [% INCLUDE foo +%]
FOO: [% INCLUDE foo a = b -%]
-- expect --
FOO: This is the foo file, a is alpha
FOO: This is the foo file, a is bravo

-- test golf --
GOLF: [% INCLUDE $c.f.g %]
GOLF: [% INCLUDE $c.f.g  g = c.f.h %]
[% DEFAULT g = "a new $c.f.g" -%]
[% g %]
-- expect --
GOLF: This is the golf file, g is golf
GOLF: This is the golf file, g is hotel
a new golf

-- test bar/baz --
BAZ: [% INCLUDE bar/baz %]
BAZ: [% INCLUDE bar/baz word='wizzle' %]
BAZ: [% INCLUDE "bar/baz" %]
-- expect --
BAZ: This is file baz
The word is 'qux'
BAZ: This is file baz
The word is 'wizzle'
BAZ: This is file baz
The word is 'qux'

-- test bar/baz.txt --
BAZ: [% INCLUDE bar/baz.txt %]
BAZ: [% INCLUDE bar/baz.txt time = 'nigh' %]
-- expect --
BAZ: This is file baz
The word is 'qux'
The time is now
BAZ: This is file baz
The word is 'qux'
The time is nigh

-- test bamboozle --
[% BLOCK bamboozle -%]
This is bamboozle
[%- END -%]
Block defined...
[% blockname = 'bamboozle' -%]
[% INCLUDE $blockname %]
End
-- expect --
Block defined...
This is bamboozle
End


# test that BLOCK definitions get AUTO_RESET (i.e. cleared) by default
-- test AUTO_RESET --
-- use reset --
[% a %]
[% PROCESS incblock -%]
[% INCLUDE first_block %]
[% INCLUDE second_block %]
[% b %]
-- expect --
alpha
this is my first block, a is set to 'alpha'
this is my second block, a is initially set to 'alpha' and 
then set to 'sierra'  b is bravo  m is 98
bravo

-- test first_block not found --
[% TRY %]
[% INCLUDE first_block %]
[% CATCH file %]
ERROR: [% error.info %]
[% END %]
-- expect --
ERROR: first_block: not found

-- test meta output --
-- use default --
[% metaout %]
-- expect --
-- process --
TITLE: The cat sat on the mat
metadata last modified [% metamod %]

-- test recursion -- 
[% TRY %]
[% PROCESS recurse counter = 1 %]
[% CATCH file -%]
[% error.info %]
[% END %]
-- expect --
recursion count: 1
recursion into 'my file'

-- test default file --
[% INCLUDE nosuchfile %]
-- expect --
This is the default file

-- test recursion count -- 
-- use reset --
[% TRY %]
[% PROCESS recurse counter = 1 %]
[% CATCH file %]
[% error.info %]
[% END %]
-- expect --
recursion count: 1
recursion count: 2
recursion count: 3

-- test nosuchfile not found --
[% TRY;
   INCLUDE nosuchfile;
   CATCH;
   "ERROR: $error";
   END
%]
-- expect --
ERROR: file error - nosuchfile: not found

-- test src:foo --
[% INCLUDE src:foo %]
[% BLOCK src:foo; "This is foo!"; END %]
-- expect --
This is foo!

-- test INCLUDE expr args --
[% a = ''; b = ''; d = ''; e = 0 %]
[% INCLUDE foo name = a or b or 'c'
               item = d or e or 'f' -%]
[% BLOCK foo; "name: $name  item: $item\n"; END %]
-- expect --
name: c  item: f

-- test more expressions --
[% style = 'light'; your_title="Hello World" -%]
[% INCLUDE foo 
         title = my_title or your_title or default_title
         bgcol = (style == 'dark' ? '#000000' : '#ffffff') %]
[% BLOCK foo; "title: $title\nbgcol: $bgcol\n"; END %]
-- expect --
title: Hello World
bgcol: #ffffff

-- test myhash --
[% myhash = {
    name  = 'Tom'
    item  = 'teacup'
   }
-%]
[% INCLUDE myblock
    name = 'Fred'
    item = 'fish'
%]
[% INCLUDE myblock
     import=myhash
%]
import([% import %])
[% PROCESS myblock
     import={ name = 'Tim', item = 'teapot' }
%]
import([% import %])
[% BLOCK myblock %][% name %] has a [% item %][% END %]
-- expect --
Fred has a fish
Tom has a teacup
import()
Tim has a teapot
import()

