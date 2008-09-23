#============================================================= -*-perl-*-
#
# t/directive/switch.t
#
# Template script testing SWITCH / CASE blocks
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
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;
    
test_expect(
    config => { POST_CHOMP => 1 },
    vars   => callsign,
);

__DATA__
#------------------------------------------------------------------------
# test simple case
#------------------------------------------------------------------------
-- test empty SWITCH --
before
[% SWITCH a %]
this is ignored
[% END %]
after
-- expect --
before
after

-- test single CASE --
before
[% SWITCH a %]
this is ignored
[% CASE x %]
not matched
[% END %]
after
-- expect --
before
after

-- test CASE not_defined --
before
[% SWITCH a %]
this is ignored
[% CASE not_defined %]
not matched
[% END %]
after
-- expect --
before
after

-- test CASE alpha --
before
[% SWITCH a %]
this is ignored
[% CASE 'alpha' %]
matched
[% END %]
after
-- expect --
before
matched
after

-- test CASE a --
before
[% SWITCH a %]
this is ignored
[% CASE a %]
matched
[% END %]
after
-- expect --
before
matched
after

-- test CASE b --
before
[% SWITCH a %]
this is ignored
[% CASE b %]
matched
[% END %]
after
-- expect --
before
after

-- test CASE a b --
before
[% SWITCH a %]
this is ignored
[% CASE a %]
matched
[% CASE b %]
not matched
[% END %]
after
-- expect --
before
matched
after

-- test CASE b a --
before
[% SWITCH a %]
this is ignored
[% CASE b %]
not matched
[% CASE a %]
matched
[% END %]
after
-- expect --
before
matched
after


#------------------------------------------------------------------------
# test default case
#------------------------------------------------------------------------
-- test empty CASE --
before
[% SWITCH a %]
this is ignored
[% CASE a %]
matched
[% CASE b %]
not matched
[% CASE %]
default not matched
[% END %]
after
-- expect --
before
matched
after

-- test CASE DEFAULT --
before
[% SWITCH a %]
this is ignored
[% CASE a %]
matched
[% CASE b %]
not matched
[% CASE DEFAULT %]
default not matched
[% END %]
after
-- expect --
before
matched
after

-- test CASE z x empty --
before
[% SWITCH a %]
this is ignored
[% CASE z %]
not matched
[% CASE x %]
not matched
[% CASE %]
default matched
[% END %]
after
-- expect --
before
default matched
after


-- test CASE z x DEFAULT --
before
[% SWITCH a %]
this is ignored
[% CASE z %]
not matched
[% CASE x %]
not matched
[% CASE DEFAULT %]
default matched
[% END %]
after
-- expect --
before
default matched
after


#------------------------------------------------------------------------
# test multiple matches
#------------------------------------------------------------------------

-- test CASE [ a b c ] --
before
[% SWITCH a %]
this is ignored
[% CASE [ a b c ] %]
matched
[% CASE d %]
not matched
[% CASE %]
default not matched
[% END %]
after
-- expect --
before
matched
after

-- test CASE [ a b c ] then a --
before
[% SWITCH a %]
this is ignored
[% CASE [ a b c ] %]
matched
[% CASE a %]
not matched, no drop-through
[% CASE DEFAULT %]
default not matched
[% END %]
after
-- expect --
before
matched
after


#-----------------------------------------------------------------------
# regex metacharacter quoting
# http://rt.cpan.org/Ticket/Display.html?id=24183
#-----------------------------------------------------------------------

-- test regex metacharacter quoting --
[% foo = 'a(b)'
   bar = 'a(b)';

   SWITCH foo;
     CASE bar;
       'ok';
     CASE;
       'not ok';
   END 
%]
-- expect --
ok
