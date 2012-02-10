#============================================================= -*-perl-*-
#
# t/pod/kwalitee.t
#
# Use Test::Pod (if available) to test the POD documentation.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2008-2012 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib   => '../../lib ../../blib/lib ../../blib/arch';

use Test::More;

unless ( $ENV{AUTOMATED_TESTING} or $ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Author tests not required for installation" );
}

eval "use Test::Pod 1.00";
plan( skip_all => "Test::Pod 1.00 required for testing POD" ) if $@;
all_pod_files_ok();

