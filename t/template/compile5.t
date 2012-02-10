#============================================================= -*-perl-*-
#
# t/compile/compile5.t
#
# Test that the compiled template files written by compile4.t can be 
# loaded and used.  Similar to compile2.t but using COMPILE_DIR as well
# as COMPILE_EXT.
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
    Filesystem  => 'Bin Dir';

use Template::TT2::Test
    tests => 10,
    debug => 'Template::TT2::Templates',
    args  => \@ARGV;

my $tdir   = Bin->dir('templates')->must_exist;
my $incdir = $tdir->dir('compile')->must_exist(1);
my $cache  = $tdir->dir('cache');
my $comps  = Dir($cache, $incdir);
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

my @files = ('foo.ttc', 'complex.ttc', 'blam.ttc');

# check compiled template files exist
foreach my $f (@files) {
    ok( $comps->file($f)->exists, "$f exists" );
}

# we're going to hack on the compiled 'foo' file to change some key text.
# this way we can tell that the template was loaded from the compiled
# version and not the source.
my ($compiled, $content, @times);
$compiled =  $comps->file('foo.ttc')->must_exist;
@times    =  (stat $compiled)[8,9];
$content  =  $compiled->text;
$content  =~ s/the foo file/the newly hacked foo file/;
$compiled->write($content);
utime( @times, $compiled );     # reset modification times
pass('tweaked foo.ttc');

# same again for 'blam'
$compiled =  $comps->file('blam.ttc');
@times    =  (stat $compiled)[8,9];
$content  =  $compiled->text;
$content  =~ s/blam/wam-bam/g;
$compiled->write($content);
utime( @times, $compiled );     # reset modification times
pass('tweaked blam.ttc');

test_expect( 
    config => $config,
    vars   => {
        dir  => $incdir,
        blam => $incdir->file('blam'),
    },
);

ok( $warnings[0] =~ /The ABSOLUTE option is deprecated/, 'got ABSOLUTE warning' );

# cleanup cache directory
#rmtree($cdir) if -d $cdir;


__DATA__
-- test INCLUDE foo --
[% INCLUDE foo a = 'any value' %]
-- expect --
This is the newly hacked foo file, a is any value

-- test INCLUDE complex --
[% META author => 'billg' version => 6.66  %]
[% INCLUDE complex %]
-- expect --
This is the header, title: Yet Another Template Test
This is a more complex file which includes some BLOCK definitions
This is the footer, author: billg, version: 6.66
- 3 - 2 - 1 

-- test INCLUDE blam --
[% INCLUDE $blam %]
-- expect --
This is the wam-bam file

-- test divisionbyzero --
[%- # second pass, reads the compiled code from cache -%]
[% INCLUDE divisionbyzero -%]
xx
-- expect --
-- process --
undef error - Illegal division by zero at divisionbyzero line 1.
xx
