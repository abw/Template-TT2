#============================================================= -*-perl-*-
#
# t/filter/uri_url.t
#
# Test the uri and url filters.
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
    tests => 6,
    debug => 'Template::TT2::Filters',
    args  => \@ARGV;

test_expect(
    vars => {
        ttdotorg => 'http://template-toolkit.org/',
        message  => 'hello world!',
        widetext => "wide:\x{65e5}\x{672c}\x{8a9e}",
    },
);

__DATA__
-- test spaces uri encoded --
[% message | uri %]
-- expect --
hello%20world!

-- test uri encoded url --
[% ttdotorg | uri %]
-- expect --
http%3A%2F%2Ftemplate-toolkit.org%2F

-- test wide text url encoded --
[% widetext | uri %]
-- expect --
wide%3A%E6%97%A5%E6%9C%AC%E8%AA%9E


-- test spaces url encoded --
[% message | url %]
-- expect --
hello%20world!

-- test url encoded url --
[% ttdotorg | url %]
-- expect --
http://template-toolkit.org/

-- test wide text url encoded --
[% widetext | url %]
-- expect --
wide:%E6%97%A5%E6%9C%AC%E8%AA%9E

