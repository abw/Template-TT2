#============================================================= -*-perl-*-
#
# t/option/process.t
#
# Test the PROCESS option.
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
    tests => 4,
    debug => 'Template::TT2::Service Template::TT2::Templates Template::TT2::Context',
    args  => \@ARGV;

use Template::TT2;
use Badger::Filesystem '$Bin Dir';
use constant ENGINE => 'Template::TT2';
my $tdir = Dir($Bin, 'templates');

my $config = {
    INCLUDE_PATH => [$tdir],
    PROCESS      => 'content',
    TRIM         => 1,
};
my $tt1 = ENGINE->new($config);

$config->{ PRE_PROCESS  } = 'config';
$config->{ PROCESS      } = ['header', 'content'];
$config->{ POST_PROCESS } = 'footer';
$config->{ TRIM         } = 0;
my $tt2 = ENGINE->new($config);

$config->{ PRE_PROCESS  } = ['config', 'header.tt2'];
$config->{ PROCESS      } = '';
my $tt3 = ENGINE->new($config);

my $engines = {
    tt1 => $tt1,
    tt2 => $tt2,
    tt3 => $tt3,
};

my $vars = {
    title => 'Joe Random Title',
};

test_expect(
    vars    => $vars,
    engine  => $engines->{ tt1 },
    engines => $engines,
);


__END__

-- test content PROCESS  --
This is the first test
-- expect --
This is the main content wrapper for "untitled"
This is the first test
This is the end.

-- test META in header --
[% META title = 'Test 2' -%]
This is the second test
-- expect --
This is the main content wrapper for "Test 2"
This is the second test
This is the end.

-- test PRE/POST/PROCESS --
-- use tt2 --
[% META title = 'Test 3' -%]
This is the third test
-- expect --
header:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
This is the main content wrapper for "Test 3"
This is the third test
This is the end.
footer

-- test PRE_PROCESS --
-- use tt3 --
[% META title = 'Test 3' -%]
This is the third test
-- expect --
header.tt2:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
footer

