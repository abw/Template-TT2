#============================================================= -*-perl-*-
#
# t/option/context.t
#
# Test the CONTEXT option.
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
use lib qw( t/lib ./lib ../lib ../../lib );
use Template::TT2::Test
    tests => 1,
    debug => 'Template::TT2::Context
              Template::TT2::Hub',
    args  => \@ARGV;

test_expect(
    config => {
        CONTEXT => 'MyContext',
    },
);


__DATA__
-- test CONTEXT module name --
Hello World
-- expect --
<MY CONTEXT>
Hello World
</MY CONTEXT>
