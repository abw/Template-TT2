#============================================================= -*-perl-*-
#
# t/modules/hub.t
#
# Test script for Template::TT2::Hub
#
# Run with -h option for help.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2012 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib   => '../../lib ../../blib/arch';

use Template::TT2::Constants ':modules';
use Template::TT2::Hub;
use Template::TT2::Test
    tests => 1,
    debug => 'Template::TT2::Hub Template::TT2::Modules',
    args  => \@ARGV;
 
pass('Nothing tested yet');

# on hindsight, the following isn't supposed to work (which may be a 
# oversight on my part)   
#my $iter = TT2_HUB->module( iterator => [1,2,3] );
#ok( $iter, 'created iterator' );
#is( ref $iter, TT2_ITERATOR, 'iterator is a ' . TT2_ITERATOR );
