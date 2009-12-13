#============================================================= -*-perl-*-
#
# t/plugin/wrap.t
#
# Template script testing wrap plugin.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#
#========================================================================

use strict;
use lib qw( ./lib ../lib ../../lib ../../blib/lib ../../blib/arch );
use Template::TT2::Test
    tests => 5,
    debug => 'Template::TT2::Plugin::Scalar',
    args  => \@ARGV;

eval "use Text::Wrap";
skip_all('Text::Wrap not installed') if $@;

test_expect;
 

#------------------------------------------------------------------------
# test input
#------------------------------------------------------------------------

__DATA__
-- test basic wrap --
[% USE Wrap -%]
[% text = BLOCK -%]
This is a long block of text that goes on for a long long time and then carries on some more after that, it's very interesting, NOT!
[%- END -%]
[% text = BLOCK; text FILTER replace('\s+', ' '); END -%]
[% Wrap(text, 25,) %]
-- expect --
This is a long block of
text that goes on for a
long long time and then
carries on some more
after that, it's very
interesting, NOT!

-- test wrap filter --
[% FILTER wrap -%]
This is a long block of text that goes on for a long long time and then carries on some more after that, it's very interesting, NOT!
[% END %]
-- expect --
This is a long block of text that goes on for a long long time and then
carries on some more after that, it's very interesting, NOT!

-- test wrap filter with single argument --
[% USE wrap -%]
[% FILTER wrap(25) -%]
This is a long block of text that goes on for a long long time and then carries on some more after that, it's very interesting, NOT!
[% END %]
-- expect --
This is a long block of
text that goes on for a
long long time and then
carries on some more
after that, it's very
interesting, NOT!

-- test wrap filter with multiple arguments --
[% FILTER wrap(10, '> ', '+ ') -%]
The cat sat on the mat and then sat on the flat.
[%- END %]
-- expect --
> The cat
+ sat on
+ the mat
+ and
+ then
+ sat on
+ the
+ flat.

-- test bullet point wrap --
[% USE wrap -%]
[% FILTER bullet = wrap(40, '* ', '  ') -%]
First, attach the transmutex multiplier to the cross-wired quantum
homogeniser.
[%- END %]
[% FILTER remove('\s+(?=\n)') -%]
[% FILTER bullet -%]
Then remodulate the shield to match the harmonic frequency, taking 
care to correct the phase difference.
[% END %]
[% END %]
-- expect --
* First, attach the transmutex
  multiplier to the cross-wired quantum
  homogeniser.
* Then remodulate the shield to match
  the harmonic frequency, taking
  care to correct the phase difference.
