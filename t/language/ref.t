#============================================================= -*-perl-*-
#
# t/language/ref.t
#
# Template script testing variable references.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib => [
        '../lib',
        '../../lib',
        '../../blib',
        '../../blib/arch',
    ];

use Template::TT2::Test
    tests => 6,
    debug => 'Template::TT2::Stash',
    args  => \@ARGV;

local $" = ', ';

my $vars = { 
    a => sub { return "a sub [@_]" },
    j => { k => 3, l => 5, m => { n => sub { "nsub [@_]" } } },
    z => sub { my $sub = shift; return "z called " . &$sub(10, 20, 30) },
};

test_expect( vars => $vars );

__DATA__
-- test subs --
a: [% a %]
a(5): [% a(5) %]
a(5,10): [% a(5,10) %]
-- expect --
a: a sub []
a(5): a sub [5]
a(5,10): a sub [5, 10]

-- test sub ref --
[% b = \a -%]
b: [% b %]
b(5): [% b(5) %]
b(5,10): [% b(5,10) %]
-- expect --
b: a sub []
b(5): a sub [5]
b(5,10): a sub [5, 10]

-- test sub ref with args --
[% c = \a(10,20) -%]
c: [% c %]
c(30): [% c(30) %]
c(30,40): [% c(30,40) %]
-- expect --
c: a sub [10, 20]
c(30): a sub [10, 20, 30]
c(30,40): a sub [10, 20, 30, 40]

-- test sub ref as arg --
[% z(\a) %]
-- expect --
z called a sub [10, 20, 30]

-- test dotted ref --
[% f = \j.k -%]
f: [% f %]
-- expect --
f: 3

-- test double dotted ref --
[% f = \j.m.n -%]
f: [% f %]
f(11): [% f(11) %]
-- expect --
f: nsub []
f(11): nsub [11]


