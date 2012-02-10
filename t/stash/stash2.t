#============================================================= -*-perl-*-
#
# t/stash/stash2.t
#
# More tests for the Template::TT2::Stash module, this time via the 
# test_expect() function.
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
    lib   => '../lib ../../lib ../../blib/lib ../../blib/arch';

use Template::TT2::Test
    tests => 10,
    debug => 'Template::TT2::Stash',
    args  => \@ARGV;

use Template::TT2::Constants
    'DEBUG_UNDEF';

use constant
    ENGINE => 'Template::TT2';

use NumberLike;
use GetNumberLike;
use CmpOverload;

my $data  = {
    hello => sub {
        my $name = shift || 'World';
        return "Hello $name";
    },
    num     => NumberLike->new("TESTING"),
    getnum  => GetNumberLike->new,
    cmp_ol  => CmpOverload->new(),
};


my $engines = {
    'default' => ENGINE->new(),
    'warn'    => ENGINE->new( DEBUG => DEBUG_UNDEF, DEBUG_FORMAT => '' ),
    'strict'  => ENGINE->new( STRICT => 1 ),
};

test_expect(
    vars    => $data,
    engines => $engines,
);

__DATA__

#-----------------------------------------------------------------------------
# Undefined variables
#-----------------------------------------------------------------------------

-- test undefined variable ignore --
a: [% a %]
-- expect --
a: 

-- test undefined variable warning via DEBUG_UNDEF --
-- use warn --
[% TRY; a; CATCH; "ERROR: $error"; END %]
-- expect --
ERROR: undef error - Undefined variable: a

-- test undefined variable warning via STRICT --
-- use strict --
[% TRY; a; CATCH; "ERROR: $error"; END %]
-- expect --
ERROR: undef error - Undefined variable: a


#-----------------------------------------------------------------------------
# Assigning values
#-----------------------------------------------------------------------------

-- test set number --
[% n = 10 -%]
n is [% n %]
-- expect --
n is 10


-- test set string --
[% n = 'ten' -%]
n is [% n %]
-- expect --
n is ten


-- test hash auto-vivification --
[% b.c = 'charlie' -%]
b.c is [% b.c %]
-- expect --
b.c is charlie


#-----------------------------------------------------------------------
# try and pin down the numification bug
#-----------------------------------------------------------------------

-- test num.things --
[% FOREACH item IN num.things -%]
* [% item %]
[% END -%]
-- expect --
* foo
* bar
* baz

-- test num stringified --
[% num %]
-- expect --
PASS: stringified TESTING

-- test getnum --
[% getnum.num %]
-- expect --
PASS: stringified from GetNumberLike


#-----------------------------------------------------------------------------
# Exercise the object with the funky overloaded comparison
#-----------------------------------------------------------------------------

-- test overloaded comparison --
[% cmp_ol.hello %]
-- expect --
Hello
