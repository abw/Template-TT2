#============================================================= -*-perl-*-
#
# t/directive/tags.t
#
# Template script testing TAGS parse-time directive to switch the
# tokens that mark start and end of directive tags.
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
    tests => 16,
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;

use constant ENGINE => 'Template::TT2';

my $params = {
    'a'  => 'alpha',
    'b'  => 'bravo',
    'c'  => 'charlie',
    'd'  => 'delta',
    'e'  => 'echo',
    tags  => 'my tags',
    flags => 'my flags',
};

my $engines = {
    basic => ENGINE->new( INTERPOLATE => 1 ),
    htags => ENGINE->new( TAG_STYLE => 'html' ),
    stags => ENGINE->new( START_TAG => '\[\*',  END_TAG => '\*\]' ),
};

test_expect(
    vars    => $params,
    engine  => $engines->{ basic },
    engines => $engines,
);

__DATA__

-- test normal tags --
[%a%] [% a %] [% a %]
-- expect --
alpha alpha alpha

-- test TAGS redefine --
Redefining tags
[% TAGS (+ +) %]
[% a %]
[% b %]
(+ c +)
-- expect --
Redefining tags

[% a %]
[% b %]
charlie

-- test two TAGS --
[% a %]
[% TAGS (+ +) %]
[% a %]
%% b %%
(+ c +)
(+ TAGS <* *> +)
(+ d +)
<* e *>
-- expect --
alpha

[% a %]
%% b %%
charlie

(+ d +)
echo

-- test TAGS default --
[% TAGS default -%]
[% a %]
%% b %%
(+ c +)
-- expect --
alpha
%% b %%
(+ c +)

-- test TAGS template --
# same as 'default'
[% TAGS template -%]
[% a %]
%% b %%
(+ c +)
-- expect --
alpha
%% b %%
(+ c +)

-- test TAGS metatext --
[% TAGS metatext -%]
[% a %]
%% b %%
<* c *>
-- expect --
[% a %]
bravo
<* c *>

-- test TAGS template1 --
[% TAGS template1 -%]
[% a %]
%% b %%
(+ c +)
-- expect --
alpha
bravo
(+ c +)

-- test TAGS html --
[% TAGS html -%]
[% a %]
%% b %%
<!-- c -->
-- expect --
[% a %]
%% b %%
charlie

-- test TAGS asp --
[% TAGS asp -%]
[% a %]
%% b %%
<!-- c -->
<% d %>
<? e ?>
-- expect --
[% a %]
%% b %%
<!-- c -->
delta
<? e ?>

-- test TAGS php --
[% TAGS php -%]
[% a %]
%% b %%
<!-- c -->
<% d %>
<? e ?>
-- expect --
[% a %]
%% b %%
<!-- c -->
<% d %>
echo

#------------------------------------------------------------------------
# test processor with pre-defined TAG_STYLE
#------------------------------------------------------------------------
-- test html TAG_STYLE --
-- use htags --
[% TAGS ignored -%]
[% a %]
<!-- c -->
more stuff
-- expect --
[% TAGS ignored -%]
[% a %]
charlie
more stuff

#------------------------------------------------------------------------
# test processor with pre-defined START_TAG and END_TAG
#------------------------------------------------------------------------
-- test START_TAG and END_TAG --
-- use stags --
[% TAGS ignored -%]
<!-- also totally ignored and treated as text -->
[* a *]
blah [* b *] blah
-- expect --
[% TAGS ignored -%]
<!-- also totally ignored and treated as text -->
alpha
blah bravo blah


#------------------------------------------------------------------------
# XML style tags
#------------------------------------------------------------------------

-- test XML tag style --
-- use basic --
[% TAGS <tt: > -%]
<tt:a=10->
a: <tt:a>
<tt:FOR a = [ 1, 3, 5, 7 ]->
<tt:a>
<tt:END->
-- expect --
a: 10
1
3
5
7

-- test TAGS star --
[% TAGS star -%]
[* a = 10 -*]
a is [* a *]
-- expect --
a is 10

-- test tags --
[% tags; flags %]
[* a = 10 -*]
a is [* a *]
-- expect --
my tagsmy flags
[* a = 10 -*]
a is [* a *]

-- test flags --
flags: [% flags | html %]
tags: [% tags | html %]
-- expect --
flags: my flags
tags: my tags

