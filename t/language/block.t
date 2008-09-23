#============================================================= -*-perl-*-
#
# t/language/block.t
#
# Template script testing BLOCK definitions.  A BLOCK defined in a 
# template incorporated via INCLUDE should not be visible (i.e. 
# exported) to the calling template.  In the same case for PROCESS,
# the block should become visible.
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
    tests => 9,
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;

use Badger::Filesystem '$Bin Dir';
my $tlib = Dir($Bin, 'templates');

my $config = {
    INCLUDE_PATH => $tlib,	
    POST_CHOMP   => 1,
    BLOCKS       => {
	    header   => '<html><head><title>[% title %]</title></head><body>',
	    footer   => '</body></html>',
	    block_a  => sub { return 'this is block a' },
	    block_b  => sub { return 'this is block b' },
    },
};

test_expect(config => $config, vars => callsign, step => 0);

__DATA__
-- test hello --
hello world
-- expect --
hello world

-- test block def --
[% BLOCK foo; 'FOO'; END;
   PROCESS foo 
%]
-- expect --
FOO

-- test INCLUDE blockdef --
[% BLOCK block1 %]
This is the original block1
[% END %]
[% INCLUDE block1 %]
[% INCLUDE blockdef %]
[% INCLUDE block1 %]

-- expect --
This is the original block1
start of blockdef
end of blockdef
This is the original block1

-- test PROCESS blockdef --
[% BLOCK block1 %]
This is the original block1
[% END %]
[% INCLUDE block1 %]
[% PROCESS blockdef %]
[% INCLUDE block1 %]

-- expect --
This is the original block1
start of blockdef
end of blockdef
This is block 1, defined in blockdef, a is alpha

-- test pre-defined blocks --
[% INCLUDE block_a +%]
[% INCLUDE block_b %]
-- expect --
this is block a
this is block b

-- test header/footer --
[% INCLUDE header 
   title = 'A New Beginning'
+%]
A long time ago in a galaxy far, far away...
[% PROCESS footer %]

-- expect --
<html><head><title>A New Beginning</title></head><body>
A long time ago in a galaxy far, far away...
</body></html>

-- test namespace block --
[% BLOCK foo:bar %]
blah
[% END %]
[% PROCESS foo:bar %]
-- expect --
blah

-- test quoted block --
[% BLOCK 'hello html' -%]
Hello World!
[% END -%]
[% PROCESS 'hello html' %]
-- expect --
Hello World!

-- test BLOCK used before defined --
<[% INCLUDE foo %]>
[% BLOCK foo %][% END %]
-- expect --
<>

