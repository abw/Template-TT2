#============================================================= -*-perl-*-
#
# t/option/anycase.t
#
# Test the ANYCASE option.
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
    lib   => '../../lib ../../blib/lib ../../blib/arch';

use Template::TT2::Test
    tests => 6,
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;

my $default = Template::TT2->new({
    POST_CHOMP => 1,
});

my $anycase = Template::TT2->new({ 
    ANYCASE    => 1, 
    POST_CHOMP => 1,
});

my $vars = callsign;
$vars->{ data } = { first => 11, last => 42 };

test_expect(
    vars    => $vars,
    engine  => $default,
    engines => {
        default => $default,
        anycase => $anycase,
    },
);

__DATA__

-- test lower case reserved word vars --
[% include = a %]
[% for = b %]
i([% include %])
f([% for %])
-- expect --
i(alpha)
f(bravo)

-- test upper AND --
[% IF a AND b %]
good
[% ELSE %]
bad
[% END %]
-- expect --
good

-- test lower and or not --
# 'and', 'or' and 'not' can ALWAYS be expressed in lower case, regardless
# of CASE sensitivity option.
[% IF a and b %]
good
[% ELSE %]
bad
[% END %]
-- expect --
good

-- test anycase --
-- use anycase --
[% include foo bar='baz' %]
[% BLOCK foo %]this is foo, bar = [% bar %][% END %]
-- expect --
this is foo, bar = baz

-- test div mod --
[% 10 div 3 %] [% 10 DIV 3 +%]
[% 10 mod 3 %] [% 10 MOD 3 %]
-- expect --
3 3
1 1

-- test ANYCASE post-dot protection --
[% data.first; ' to '; data.last %]
-- expect --
11 to 42

