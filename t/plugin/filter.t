#============================================================= -*-perl-*-
#
# t/plugin/filter.t
#
# Tests the File plugin.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2008-2009 Andy Wardley. All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( t/lib ./lib ../lib ../../lib );
use Template::TT2::Test
    debug => 'Template::TT2::Plugin::Filter Template::TT2::Plugin::Change', 
    tests => 7,
    args  => \@ARGV;

test_expect(
    vars => {
        munge => sub {
            return sub {
                my $text = shift;
                $text =~ s/foo/bar/g;
                return $text;
            }
        },
    },
);

__DATA__
-- test plugin filter --
[% USE Change -%]
OK
-- expect --
OK

-- test filter works with sub refs --
[% FILTER $munge -%]
foo bar baz bar foo
[% END %]
-- expect --
bar bar baz bar bar


-- test simple NoFoo plugin filter --
[% USE NoFoo -%]
[% FILTER $NoFoo -%]
Blah blah foo bar
[% END -%]
-- expect --
Blah blah  bar


-- test change filter --
[% USE Change ten='eleven'-%]
[% FILTER $Change -%]
This one goes up to ten
[% END -%]
-- expect --
This one goes up to eleven


-- test change filter with late args --
[% USE Change ten='eleven'-%]
[% FILTER $Change one='two' -%]
This one goes up to ten
[% END -%]
-- expect --
This two goes up to eleven

-- test simple filter with re-use --
# This uses Template::Plugin::SimpleFilter which is a subclass
# of Template::Plugin::Filter.  The test relates to this bug:
# https://rt.cpan.org/Ticket/Display.html?id=46691
[% USE SimpleFilter -%]
test 1: [% 'hello' | simple %]
[% INCLUDE simple2 %]
test 3: [% 'world' | simple %]
[% BLOCK simple2 -%]
[% USE SimpleFilter -%]
test 2: [% 'badger' | simple -%]
[% END -%]
-- expect --
test 1: **hello**
test 2: **badger**
test 3: **world**

-- test simple2 filter with re-use --
# Similar to the previous test but using Template::TT2::Plugin::SimpleFilter2
# which is a subclass of Template::TT2::Plugin::Filter
[% USE SimpleFilter2 -%]
test 1: [% 'hello' | simple2 %]
[% INCLUDE simple2 %]
test 3: [% 'world' | simple2 %]
[% BLOCK simple2 -%]
[% USE SimpleFilter2 -%]
test 2: [% 'badger' | simple2 -%]
[% END -%]
-- expect --
test 1: ++hello++
test 2: ++badger++
test 3: ++world++
