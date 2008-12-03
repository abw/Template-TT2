#============================================================= -*-perl-*-
#
# t/plugin/filter.t
#
# Tests the File plugin.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2008 Andy Wardley. All Rights Reserved.
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
    tests => 5,
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
