#============================================================= -*-perl-*-
#
# t/plugin/procedural.t
#
# Template script testing the procedural template plugin
#
# Written by Mark Fowler <mark@twoshortplanks.com>
# Updated by Andy Wardley for Template::TT2
#
# Copyright 2002 Mark Fowler, 2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib '/home/abw/projects/badger/lib';
use lib qw( t/lib ./lib ../lib ../../lib );
use Template::TT2::Test
    debug => "Template::TT2::Plugin::Procedural Template::TT2::Plugins
              Template::TT2::Parser",
    tests => 9,
    args  => \@ARGV;

test_expect(
    vars => {
        # we may not have Template-Toolkit installed
        I_HAZ_TTP => eval { require Template::Plugin::Procedural },
        I_HAZ_NOT => 0,
    }
);

__DATA__
-- test ProcFoo --
-- only I_HAZ_TTP --
[% USE ProcFoo -%]
[% ProcFoo.foo %]
[% ProcFoo.bar %]
[% ProcFoo.bar(10, 20) %]
-- expect --
This is procfoofoo
This is procfoobar
This is procfoobar, 10, 20

-- test ProcFoo alias --
-- only I_HAZ_TTP --
[% USE pf = ProcFoo -%]
[% pf.foo %]
[% pf.bar %]
[% pf.bar(1.618, 2.718) %]
-- expect --
This is procfoofoo
This is procfoobar
This is procfoobar, 1.618, 2.718


-- test ProcBar --
-- only I_HAZ_TTP --
[% USE ProcBar -%]
[% ProcBar.foo %]
[% ProcBar.bar %]
[% ProcBar.baz %]
-- expect --
This is procfoofoo
This is procbarbar
This is procbarbaz


-- test ProcBaz --
-- only I_HAZ_TTP --
[% USE ProcBaz -%]
[% ProcBaz.foo %]
[% ProcBaz.bar %]
[% ProcBaz.baz %]
-- expect --
This is procfoofoo
This is procbarbar
This is procbazbaz


-- test ProcFoo2 --
[% USE ProcFoo2 -%]
[% ProcFoo2.foo %]
[% ProcFoo2.bar %]
[% ProcFoo2.bar(10, 20) %]
-- expect --
This is procfoo2foo
This is procfoo2bar
This is procfoo2bar, 10, 20


-- test ProcFoo2 alias --
[% USE pf = ProcFoo2 -%]
[% pf.foo %]
[% pf.bar %]
[% pf.bar(1.618, 2.718) %]
-- expect --
This is procfoo2foo
This is procfoo2bar
This is procfoo2bar, 1.618, 2.718


-- test ProcBar2 --
[% USE ProcBar2 -%]
[% ProcBar2.foo %]
[% ProcBar2.bar %]
[% ProcBar2.baz %]
-- expect --
This is procfoo2foo
This is procbar2bar
This is procbar2baz


-- test ProcBaz2 with alias --
[% USE pbz2 = ProcBaz2 -%]
[% pbz2.foo %]
[% pbz2.bar %]
[% pbz2.baz %]
-- expect --
This is procfoo2foo
This is procbar2bar
This is procbaz2baz

-- test errors get thrown when invalid methods are called --
[% USE ProcFoo2;
   TRY;
      ProcFoo2.dysfunctional;
   CATCH;
      "Caught error: $error\n";
   END;
%]
-- expect --
Caught error: plugin.procfoo2 error - Invalid method called: dysfunctional
