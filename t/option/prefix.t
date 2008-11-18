#============================================================= -*-perl-*-
#
# t/option/prefix_map.t
#
# Test template prefixes within INCLUDE, etc., directives.
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
    tests => 7,
    debug => 'Template::TT2::Templates',
    args  => \@ARGV;

use Template::TT2::Modules;
use constant TT2_MODULES => 'Template::TT2::Modules';
use Badger::Filesystem '$Bin Dir';
my $tdir = Dir($Bin, 'templates')->must_exist;

# we'll try two different ways of creating Template::TT2::Templates objects,
# just to make sure they both work.
my $one_prov = TT2_MODULES->module( 
    templates => { 
        INCLUDE_PATH => $tdir->dir('prefix_one'),
    }
);
my $two_prov = TT2_MODULES->templates( 
    INCLUDE_PATH => $tdir->dir('prefix_two'),
);

my $config = {
    LOAD_TEMPLATES => [ $one_prov, $two_prov ],
    PREFIX_MAP   => {
        src => '0',
        lib => '1',
        all => '0, 1',
    },
};

test_expect( config => $config );

__DATA__
-- test INCLUDE foo --
[% INCLUDE foo a=10 %]
-- expect --
This is the foo file, a is 10

-- test INCLUDE src:foo --
[% INCLUDE src:foo a=20 %]
-- expect --
This is the foo file, a is 20

-- test INCLUDE all::foo --
[% INCLUDE all:foo a=30 %]
-- expect --
This is the foo file, a is 30

-- test INCLUDE lib:bar --
[% INCLUDE lib:bar a=30 %]
-- expect --
This is the bar file, a is 30

-- test INCLUDE all::bar --
[% INCLUDE all:bar a=40 %]
-- expect --
This is the bar file, a is 40

-- test TRY INCLUDE lib:foo --
[% TRY;
    INCLUDE lib:foo a=50 ;
   CATCH;
    error;
   END
%]
-- expect --
file error - lib:foo: not found

-- test INSERT src:foo --
[% INSERT src:foo %]
-- expect --
This is the foo file, a is [% a -%]
