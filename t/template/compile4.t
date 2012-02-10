#============================================================= -*-perl-*-
#
# t/template/compile4.t
#
# This is similar to compile1.t but defines COMPILE_DIR as well as
# COMPILE_EXT.
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
    tests => 7,
    debug => 'Template::TT2::Templates',
    args  => \@ARGV;

my $tdir   = Bin->dir('templates')->must_exist;
my $incdir = $tdir->dir('compile')->must_exist(1);
my $cache  = $tdir->dir('cache');
my $config = {
    POST_CHOMP   => 1,
    INCLUDE_PATH => $incdir,
    COMPILE_DIR  => $cache,
    COMPILE_EXT  => '.ttc',
    ABSOLUTE     => 1,
};

# catch warnings that ABSOLUTE and RELATIVE options are deprecated
my @warnings;
$SIG{__WARN__} = sub {
    push(@warnings, shift);
};

$cache->delete if $cache->exists;
$cache->create;

test_expect(
    config => $config,
    vars   =>  {
        dir  => $incdir,
        blam => $incdir->file('blam'),
    },
);

ok( $warnings[0] =~ /The ABSOLUTE option is deprecated/, 'got ABSOLUTE warning' );


__DATA__
-- test INCLUDE foo --
[% TRY %]
[% INCLUDE foo %]
[% CATCH file %]
Error: [% error.type %] - [% error.info %]
[% END %]
-- expect --
This is the foo file, a is 

-- test INCLUDE complex --
[% META author => 'abw' version => 3.14 %]
[% INCLUDE complex %]
-- expect --
This is the header, title: Yet Another Template Test
This is a more complex file which includes some BLOCK definitions
This is the footer, author: abw, version: 3.14
- 3 - 2 - 1 

-- test INCLUDE bar/baz --
[% TRY %]
[% INCLUDE bar/baz word = 'wibble' %]
[% CATCH file %]
Error: [% error.type %] - [% error.info %]
[% END %]
-- expect --
This is file baz
The word is 'wibble'

-- test absolute path not found --
[% TRY; INCLUDE /no/where/no_such_file; CATCH; error; END %]
-- expect --
file error - /no/where/no_such_file: not found

-- test absolute path --
[% INCLUDE $blam %]
-- expect --
This is the blam file

-- test division by zero --
[%- # first pass, writes the compiled code to cache -%]
[% INCLUDE divisionbyzero -%]
xx
-- expect --
-- process --
undef error - Illegal division by zero at divisionbyzero line 1.
xx