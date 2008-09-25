#============================================================= -*-perl-*-
#
# t/template/compile4.t
#
# This is similar to compile1.t but defines COMPILE_DIR as well as
# COMPILE_EXT.
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
    tests => 14,
    debug => 'Template::TT2::Templates',
    args  => \@ARGV;

use Badger::Filesystem '$Bin Dir';
my $tdir   = Dir($Bin, 'templates')->must_exist;
my $incdir = $tdir->dir('compile')->must_exist(1);
my $cache  = $tdir->dir('cache');
my $config = {
    POST_CHOMP   => 1,
    INCLUDE_PATH => $incdir,
    COMPILE_DIR  => $cache,
    COMPILE_EXT  => '.ttc',
    ABSOLUTE     => 1,
};

$cache->delete;

exit();
# delete any existing cache files
rmtree($cdir) if -d $cdir;
mkpath($cdir);

test_expect(\*DATA, $ttcfg, { root => abs_path($dir) } );


__DATA__
-- test --
[% TRY %]
[% INCLUDE foo %]
[% CATCH file %]
Error: [% error.type %] - [% error.info %]
[% END %]
-- expect --
This is the foo file, a is 

-- test --
[% META author => 'abw' version => 3.14 %]
[% INCLUDE complex %]
-- expect --
This is the header, title: Yet Another Template Test
This is a more complex file which includes some BLOCK definitions
This is the footer, author: abw, version: 3.14
- 3 - 2 - 1 

-- test --
[% TRY %]
[% INCLUDE bar/baz word = 'wibble' %]
[% CATCH file %]
Error: [% error.type %] - [% error.info %]
[% END %]
-- expect --
This is file baz
The word is 'wibble'

-- test --
[% INCLUDE "$root/src/blam" %]
-- expect --
This is the blam file