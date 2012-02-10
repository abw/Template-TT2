#============================================================= -*-perl-*-
#
# t/template/document.t
#
# Test the Template::Templates module.
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
    tests => 5,
    debug => 'Template::TT2::Document',
    args  => \@ARGV;

my $tdir   = Bin->dir('templates');
my $ENGINE = 'Template::TT2';

my $tt = $ENGINE->new(
    INCLUDE_PATH => [
        $tdir->dir('inc_one'),
        $tdir->dir('inc_two'),
    ],
);
ok( $tt, 'created Template object' );

my $out;

$tt->process('foo/bar', undef, \$out) || die $tt->error;
ok( $out, 'processed foo/bar' );
is( $out, 'This is foo/bar, file is bar in foo', 'got template.name, etc' );

$out = '';
$tt->process('foo/baz', undef, \$out) || die $tt->error;
ok( $out, 'processed foo/baz' );
is( $out, 'This is foo/baz, author is abw', 'got template.author from META' );


