#============================================================= -*-perl-*-
#
# t/stash/xs-unicode.t
#
# Template script to test unicode data with the XS Stash
#
# Written by Andy Wardley <abw@wardley.org> based on code provided
# by Максим Вуец.
#
# Copyright (C) 1996-2012 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib => [
        '../../lib',
        '../../blib',
        '../../blib/arch',
    ];

use utf8;
use Template::TT2::Test
    #tests => 4,
    debug => 'Template::TT2::Stash',
    args  => \@ARGV;

BEGIN {
    unless ($] > 5.007) {
        skip_all("perl < 5.8 can't do unicode well enough\n");
    }
    eval {
        require Template::TT2::Stash::XS;
    };
    if ($@) {
    #    warn $@;
        skip_all('cannot load Template::TT2::Stash::XS');
    }
}

plan(4);

binmode STDOUT, ':utf8';


my $vars = {
    ascii => 'key',
    utf8  => 'ключ',
    hash  => {
        key  => 'value',
        ключ => 'значение'
    },
    str => 'щука'
};

test_expect(
    vars => $vars,
);

__DATA__
-- test ASCII key --
ascii = [% ascii %]
hash.$ascii = [% hash.$ascii %]
-- expect --
ascii = key
hash.$ascii = value

-- test UTF8 length --
str.length = [% str.length %]
-- expect --
str.length = 4

-- test UTF8 key fetch --
utf8 = [% utf8 %]
hash.$utf8 = hash.[% utf8 %] = [% hash.$utf8 %]
-- expect --
utf8 = ключ
hash.$utf8 = hash.ключ = значение

-- test UTF8 key assign --
[% value = hash.$utf8; hash.$value = utf8 -%]
value = [% value %]
hash.$value = hash.[% value %] = [% hash.$value %]
-- expect --
value = значение
hash.$value = hash.значение = ключ
