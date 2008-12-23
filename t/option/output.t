#============================================================= -*-perl-*-
#
# t/option/output.t
#
# Test the OUTPUT and OUTPUT_PATH options of the Template.pm module.
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
    tests => 29,
    debug => 'Template::TT2 Template::TT2::Hub',
    args  => \@ARGV;

use Badger::Filesystem '$Bin Dir';
use constant ENGINE => 'Template::TT2';

my $dir   = Dir($Bin, 'templates')->must_exist;
my $out   = $dir->dir('output')->must_exist(1);
my $src   = $dir->dir('prefix_one');          # reuse foo template
my $name1 = 'foo.bar';
my $name2 = 'foo.baz';
my $file1 = $out->file($name1);
my $file2 = $out->file($name2);

#------------------------------------------------------------------------

my $tt = ENGINE->new({
    INCLUDE_PATH => $src,
});

$file1->delete if $file1->exists;
ok( $tt->process('foo', &callsign, $file1->path), "processed template into file path");
ok( $file1->exists, "file $file1 exists" );
is( $file1->text, "This is the foo file, a is alpha", 'got template output' );
$file1->delete;

ok( $tt->process('foo', &callsign, $file1), "processed template into file object");
ok( $file1->exists, "file $file1 exists again" );
is( $file1->text, "This is the foo file, a is alpha", 'got template output again' );
$file1->delete;

#------------------------------------------------------------------------

$tt = ENGINE->new({
    INCLUDE_PATH => $src,
    OUTPUT_PATH  => $out,
});

$file1->delete if $file1->exists;
ok( $tt->process('foo', &callsign, $name1), "processed template into file name");
ok( $file1->exists, "file $file1 exists yet again" );
is( $file1->text, "This is the foo file, a is alpha", 'got template output yet again' );
$file1->delete;

ok( $tt->process('foo', &callsign, $file1), "processed template into file object");
ok( $file1->exists, "file $file1 exists again" );
is( $file1->text, "This is the foo file, a is alpha", 'got template output again' );
$file1->delete;


#------------------------------------------------------------------------

$tt = ENGINE->new({
    INCLUDE_PATH => $src,
    OUTPUT_PATH  => $out,
    OUTPUT       => $file2,
});

ok( $tt->process('foo', &callsign, $file1), "processed template into explicit file1");
ok( $file1->exists, "file $file1 exists" );
is( $file1->text, "This is the foo file, a is alpha", 'file1 output' );
$file1->delete;

ok( $tt->process('foo', &callsign, '/foo.bar'), "processed template with absolute output");
ok( $file1->exists, "file $file1 exists through absolute path" );
is( $file1->text, "This is the foo file, a is alpha", '/foo.bar output' );
$file1->delete;

ok( $tt->process('foo', &callsign), 'processed template into implicit file2' );
ok( $file2->exists, "file $file2 exists again" );
is( $file2->text, "This is the foo file, a is alpha", 'file2 output' );
$file2->delete;


#------------------------------------------------------------------------
# test passing options like 'binmode' to Template process() method to 
# ensure they get passed onto _output() subroutine.
#------------------------------------------------------------------------

# hack for testing
our $MESSAGE = 'FAIL';

my $tt3 = ENGINE->new({
    INCLUDE_PATH => $src,
    OUTPUT_PATH  => $out,
    OUTPUT       => $name2,
});

$tt3->hub->install_binmode_debugger(sub { $MESSAGE = join('', @_) });

ok( $tt3->process('foo', &callsign, undef, { binmode => 1 }), 'processed in subclass' );
ok( $file2->exists, 'output file exists' );
is( $MESSAGE, 1, 'set binmode via hashref' );
$file2->delete;

$MESSAGE = 'reset';

ok( $tt3->process('foo', &callsign, $name2, binmode => ':utf8'), 'processed again' );
ok( $file2->exists, 'output file exists' );
is( $MESSAGE, ":utf8", 'set binmode via arglist' );
$file2->delete;


#-----------------------------------------------------------------------
# try setting OUTPUT_PATH to 0 - this should prevent any file based 
# output
#-----------------------------------------------------------------------

my $tt4 = ENGINE->new({
    INCLUDE_PATH => $src,
    OUTPUT_PATH  => 0,
});

ok( ! $tt4->process('foo', &callsign, $name2 ), 'process failed with OUTPUT_PATH disabled' );
is( $tt4->reason->info, 'Cannot create filesystem output - OUTPUT_PATH is disabled', 'got filesystem error' );


