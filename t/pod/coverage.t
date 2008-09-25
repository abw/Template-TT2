#============================================================= -*-perl-*-
#
# t/pod_coverage.t
#
# Use Test::Pod::Coverage (if available) to test the POD documentation.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib );
use Test::More;

eval "use Test::Pod::Coverage 1.00";
plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD coverage" if $@;
plan tests => 1;
pass('not checking POD coverage yet');

#pod_coverage_ok('Template::TT2');
#pod_coverage_ok('Template::TT2::Base');
#pod_coverage_ok('Template::TT2::Class');
#pod_coverage_ok('Template::Context');
#pod_coverage_ok('Template::Document');
#pod_coverage_ok('Template::Exception');
#pod_coverage_ok('Template::Filters');
#pod_coverage_ok('Template::Iterator');
#pod_coverage_ok('Template::Parser');
#pod_coverage_ok('Template::Plugin');
#pod_coverage_ok('Template::Plugins');
#pod_coverage_ok('Template::Provider');
#pod_coverage_ok('Template::Service');
#pod_coverage_ok('Template::Stash');
#pod_coverage_ok('Template::Test');
#pod_coverage_ok('Template::View');
#pod_coverage_ok('Template::VMethods');
#pod_coverage_ok('Template::Namespace::Constants');
#pod_coverage_ok('Template::Stash::Context');
#pod_coverage_ok('Template::Stash::XS');

#all_pod_coverage_ok();

