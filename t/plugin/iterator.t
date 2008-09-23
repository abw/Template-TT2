#============================================================= -*-perl-*-
#
# t/plugin/iterator.t
#
# Test script for Iterator plugin 
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
    tests => 1,
    debug => 'Template::TT2::Iterator',
    args  => \@ARGV;
    
test_expect(
    vars => {
        data => [ qw( foo bar baz qux wiz woz waz ) ],
    },
);

__DATA__

-- test iterator plugin --
[%  USE iterator(data) -%]
[%  FOREACH i IN iterator -%]
[%    IF iterator.first -%]
List of items:
[%    END -%]
   * [% i +%]
[%    IF iterator.last -%]
End of list
[%    END -%]
[% END -%]
-- expect --
List of items:
   * foo
   * bar
   * baz
   * qux
   * wiz
   * woz
   * waz
End of list


