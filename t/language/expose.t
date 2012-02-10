#============================================================= -*-perl-*-
#
# t/language/expose.t
#
# Test EXPOSE_BLOCKS option
#
# Run with -h option for help.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 1996-2012 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib        => '../../lib ../../blib/lib ../../blib/arch',
    Filesystem => 'Bin';

use Template::TT2::Test
    tests => 5,
    debug => 'Template::TT2',
    args  => \@ARGV;

my $tlib = Bin->dir('templates');

my $tt_shielded = Template::TT2->new(
    INCLUDE_PATH => $tlib,
);

my $tt_exposed = Template::TT2->new(
    INCLUDE_PATH  => $tlib,
    EXPOSE_BLOCKS => 1,
);

my $vars = {
    a   => 'alpha',
    b   => 'bravo',
};

test_expect(
    vars    => $vars,
    engine  => $tt_shielded,
    engines => {
        shielded => $tt_shielded,
        exposed  => $tt_exposed,
    },
);

__DATA__
-- test unexposed block --
[% TRY; INCLUDE blockdef/block1; CATCH; error; END %]
-- expect --
file error - blockdef/block1: not found

-- test exposed block --
-- use exposed --
[% INCLUDE blockdef/block1 %]
-- expect --
This is block 1, defined in blockdef, a is alpha

-- test exposed block with args --
[% INCLUDE blockdef/block1 a='amazing' %]
-- expect --
This is block 1, defined in blockdef, a is amazing

-- test exposed missing -- 
[% TRY; INCLUDE blockdef/none; CATCH; error; END %]
-- expect --
file error - blockdef/none: not found

-- test internally nested blocks --
[% BLOCK one -%]
block one
[% BLOCK two -%]
this is block two, b is [% b %]
[% END -%]
two has been defined, let's now include it
[% INCLUDE one/two b='brilliant' -%]
end of block one
[% END -%]
[% INCLUDE one -%]
=
[% INCLUDE one/two b='brazen'-%]
--expect --
block one
two has been defined, let's now include it
this is block two, b is brilliant
end of block one
=
this is block two, b is brazen
