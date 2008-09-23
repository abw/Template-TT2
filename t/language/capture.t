#============================================================= -*-perl-*-
#
# t/language/capture.t
#
# Test that the output from a directive block can be assigned to a 
# variable.
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
    tests => 5,
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;

my $config = {
    POST_CHOMP => 1,
};

my $vars = {
    a => 'alpha',
    b => 'bravo',
};

test_expect(
    config => $config, 
    vars   => $vars,
);

__DATA__

-- test capture INCLUDE --
[% BLOCK foo %]
This is block foo, a is [% a %]
[% END %]
[% b = INCLUDE foo %]
[% c = INCLUDE foo a = 'amended' %]
b: <[% b %]>
c: <[% c %]>
-- expect --
b: <This is block foo, a is alpha>
c: <This is block foo, a is amended>

-- test capture BLOCK --
[% d = BLOCK %]
This is the block, a is [% a %]
[% END %]
[% a = 'charlie' %]
a: [% a %]   d: [% d %]
-- expect --
a: charlie   d: This is the block, a is alpha

-- test capture IF --
[% e = IF a == 'alpha' %]
a is [% a %]
[% ELSE %]
that was unexpected
[% END %]
e: [% e %]
-- expect --
e: a is alpha

-- test capture FOREACH --
[% a = FOREACH b = [1 2 3] %]
[% b %],
[%- END %]
a is [% a %]

-- expect --
a is 1,2,3,

-- test capture PROCESS FOREACH --
[% BLOCK userinfo %]
name: [% user +%]
[% END %]
[% out = PROCESS userinfo FOREACH user = [ 'tom', 'dick', 'larry' ] %]
Output:
[% out %]
-- expect --
Output:
name: tom
name: dick
name: larry



