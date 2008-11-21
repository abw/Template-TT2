#============================================================= -*-perl-*-
#
# t/plugin/format.t
#
# Template script testing the format plugin.
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
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Template::TT2::Test
    tests => 4,
    debug => 'Template::TT2::Plugin::Format Template::TT2::Parser',
    args  => \@ARGV;

my ($a, $b, $c, $d) = qw( alpha bravo charlie delta );
my $vars = { 
    a => $a,
    b => $b,
    c => $c,
    d => $d,
};

test_expect(
    config => { INTERPOLATE => 1, POST_CHOMP => 1 }, 
    vars   => $vars
);
 

#------------------------------------------------------------------------
# test input
#------------------------------------------------------------------------

__DATA__
-- test format factory --
[% USE format %]
[% bold = format('<b>%s</b>') %]
[% ital = format('<i>%s</i>') %]
[% bold('heading') +%]
[% ital('author')  +%]
${ ital('affil.') }
[% bold('footing')  +%]
$bold
-- expect --
<b>heading</b>
<i>author</i>
<i>affil.</i>
<b>footing</b>
<b></b>

-- test format list item --
[% USE format('<li> %s') %]
[% FOREACH item IN [ a b c d ] %]
[% format(item) +%]
[% END %]
-- expect --
<li> alpha
<li> bravo
<li> charlie
<li> delta

-- test bold/ital --
[% USE bold = format("<b>%s</b>") %]
[% USE ital = format("<i>%s</i>") %]
[% bold('This is bold')   +%]
[% ital('This is italic') +%]
-- expect --
<b>This is bold</b>
<i>This is italic</i>

-- test padleft/padright --
[% USE padleft  = format('%-*s') %]
[% USE padright = format('%*s')  %]
[% padleft(10, a) %]-[% padright(10, b) %]

-- expect --
alpha     -     bravo

