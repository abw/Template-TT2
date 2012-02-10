#============================================================= -*-perl-*-
#
# t/template/templates.t
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
    tests => 2,
    debug => 'Template::TT2::Templates',
    args  => \@ARGV;

use Template::TT2::Templates;
our $TEMPLATES = 'Template::TT2::Templates';

my $tdir = Bin->dir('templates');

my $ts = $TEMPLATES->new(
    INCLUDE_PATH => [
        $tdir->dir('inc_one'),
        $tdir->dir('inc_two'),
    ],
);
ok( $ts, 'created Template::Templates' );

my $one = $ts->fetch('one');
ok( $one, 'got template one' );


