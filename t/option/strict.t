#============================================================= -*-perl-*-
#
# t/strict.t
#
# Test strict mode.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 1996-2009 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Template::TT2::Test
    tests => 6,
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;

use Template::TT2::Stash::Perl;
$Template::TT2::Stash::BACKEND = 'Template::TT2::Stash::Perl';

my $template = Template::TT2->new(
    STRICT => 1
);

my $vars = {
    foo => 10, 
    bar => undef, 
    baz => { 
        boz => undef 
    }
};

test_expect(
    vars   => $vars,
    engine => $template,
);

__DATA__
-- test defined variable --
[% foo %]
-- expect --
10

-- test variable with undefined value --
[% TRY; bar; CATCH; error; END %]
-- expect --
undef error - Undefined variable: bar

-- test dotted variable with undefined value --
[% TRY; baz.boz; CATCH; error; END %]
-- expect --
undef error - Undefined variable: baz.boz

-- test undefined first part of dotted.variable --
[% TRY; wiz.bang; CATCH; error; END %]
-- expect --
undef error - Undefined variable: wiz.bang

-- test undefined second part of dotted.variable --
[% TRY; baz.booze; CATCH; error; END %]
-- expect --
undef error - Undefined variable: baz.booze

-- test dotted.variable with args --
[% TRY; baz(10).booze(20, 'blah', "Foo $foo"); CATCH; error; END %]
-- expect --
undef error - Undefined variable: baz(10).booze(20, 'blah', 'Foo 10')

