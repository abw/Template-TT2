#============================================================= -*-perl-*-
#
# t/filter/dynamic.t
#
# Test the various dynamic filters (i.e. those that take arguments)
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
    tests => 15,
    debug => 'Template::TT2::Filters',
    args  => \@ARGV;

test_expect();

__DATA__
-- test single line format --
[% FILTER format('++%s++') %]Hello World[% END %]
[% FILTER format %]Hello World[% END %]
-- expect --
++Hello World++
Hello World

-- test bold italic format --
[% FILTER bold = format('<b>%s</b>') -%]
This is bold
[% END +%]
[% FILTER italic = format('<i>%s</i>') -%]
This is italic
[% END +%]
[% 'This is both' FILTER bold FILTER italic -%]
-- expect --
<b>This is bold</b>
<i>This is italic</i>
<i><b>This is both</b></i>

-- test nested format --
[% "foo" FILTER format("<< %s >>") FILTER format("=%s=") %]
-- expect --
=<< foo >>=

-- test indent --
[% FILTER indent -%]
The cat sat
on the mat
[% END %]
-- expect --
    The cat sat
    on the mat

-- test indent two spaces --
[% FILTER indent(2) -%]
The cat sat
on the mat
[% END %]
-- expect --
  The cat sat
  on the mat

-- test indent by prefix --
[% FILTER indent('>> ') -%]
The cat sat
on the mat
[% END %]
-- expect --
>> The cat sat
>> on the mat

-- test double indent --
[% text = 'The cat sat on the mat';
   text | indent('> ') | indent('+') %]
-- expect --
+> The cat sat on the mat

-- test truncate to specific length --
[% 'The cat sat on the mat' FILTER truncate(10) %]
-- expect --
The cat...

-- test truncate to default length --
[% 'The cat sat on the mat and the dog sat on the log' FILTER truncate %]
-- expect --
The cat sat on the mat and th...

-- test truncate to various lengths --
[% 'Hello World' | truncate(8) +%]
[% 'Hello World' | truncate(10) +%]
[% 'Hello World' | truncate(20) +%]
[% 'Hello World' | truncate(11) +%]
-- expect --
Hello...
Hello W...
Hello World
Hello World

-- test no truncate --
[% FILTER truncate(25) %]
Nothing much to say
[% END %]
-- expect --
Nothing much to say

-- test repeat --
[% "foo..." FILTER repeat(5) %]
-- expect --
foo...foo...foo...foo...foo...

-- test repeat block --
[% FILTER repeat(3) -%]
Am I repeating myself?
[% END %]
-- expect --
Am I repeating myself?
Am I repeating myself?
Am I repeating myself?

-- test remove --
[% text = 'The cat sat on the mat' -%]
[% text FILTER remove(' ') +%]
[% text FILTER remove('\s+') +%]
[% text FILTER remove('cat') +%]
[% text FILTER remove('at') +%]
[% text FILTER remove('at', 'splat') +%]
-- expect --
Thecatsatonthemat
Thecatsatonthemat
The  sat on the mat
The c s on the m
The c s on the m

-- test replace --
[% text = 'The cat sat on the mat' -%]
[% text FILTER replace(' ', '_') +%]
[% text FILTER replace('sat', 'shat') +%]
[% text FILTER replace('at', 'plat') +%]
-- expect --
The_cat_sat_on_the_mat
The cat shat on the mat
The cplat splat on the mplat

