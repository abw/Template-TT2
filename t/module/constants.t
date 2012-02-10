#============================================================= -*-perl-*-
#
# t/modules/constants.t
#
# Test script for Template::TT2::Constants
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
    lib   => '../../lib ../../blib/arch';

use Template::TT2::Constants
    ':status CHOMP_COLLAPSE';

use Template::TT2::Test
    tests => 2,
    debug => 'Template::TT2::Constants',
    args  => \@ARGV;
    

ok( STATUS_DONE, 'imported STATUS_DONE' );
ok( CHOMP_COLLAPSE, 'imported CHOMP_COLLAPSE' );
