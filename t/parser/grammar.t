#============================================================= -*-perl-*-
#
# t/parser/grammar.t
#
# Test the Template::TT2::Grammar module.
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
    tests => 4,
    debug => 'Template::TT2::Grammar';

use Template::TT2::Grammar 
    '@TABLE_NAMES';

pass('loaded Template::TT2::Grammar');
is( $TABLE_NAMES[0], 'LEXTABLE', 'got LEXTABLE name' );
is( $TABLE_NAMES[1], 'STATES',   'got STATES name' );
is( $TABLE_NAMES[2], 'RULES',    'got RULES name' );
