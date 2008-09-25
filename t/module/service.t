#============================================================= -*-perl-*-
#
# t/module/service.t
#
# Test the Template::Service module.
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
    tests => 14,
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;

use Badger::Filesystem '$Bin Dir';
use constant ENGINE => 'Template::TT2';

my $dir    = Dir($Bin, 'templates')->must_exist;
my $src    = $dir->dir('src');
my $lib    = $dir->dir('lib');
my $config = {
    INCLUDE_PATH => [$src, $lib],
    PRE_PROCESS  => [ 'config', 'header' ],
    POST_PROCESS => 'footer',
    BLOCKS       => { 
	    demo     => sub { return 'This is a demo' },
	    astext   => "Another template block, a is '[% a %]'",
    },
    ERROR        => {
	    barf     => 'barfed',
	    default  => 'error',
    },
};
my $tt1 = ENGINE->new($config);

$config->{ AUTO_RESET } = 0;
my $tt2 = ENGINE->new($config);

$config->{ ERROR } = 'barfed';
my $tt3 = ENGINE->new($config);

$config->{ PRE_PROCESS  } = 'before';
$config->{ POST_PROCESS } = 'after';
$config->{ PROCESS } = 'process';
$config->{ WRAPPER } = 'outer';
my $tt4 = ENGINE->new($config);

$config->{ WRAPPER } = [ 'outer', 'inner' ];
my $tt5 = ENGINE->new($config);

my $vars = {
    title => 'Joe Random Title',
};

my $engines = {
    tt1 => $tt1, 
    tt2 => $tt2, 
    tt3 => $tt3,
    wrapper => $tt4,
    nested  => $tt5,
};

test_expect(
    vars    => $vars,
    engine  => $engines->{ tt1 },
    engines => $engines,
);


__END__
# test that headers and footers get added
-- test header and footer --
This is some text
-- expect --
header:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
This is some text[service footer]

# test that the 'demo' block (template sub) is defined
-- test demo block --
[% INCLUDE demo %]
-- expect --
header:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
This is a demo[service footer]

# and also the 'astext' block (template text)
-- test astext --
[% INCLUDE astext a = 'artifact' %]
-- expect --
header:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
Another template block, a is 'artifact'[service footer]

# test that 'barf' exception gets redirected to the correct error template
-- test error template --
[% THROW barf 'Not feeling too good' %]
-- expect --
header:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
barfed: [barf] [Not feeling too good]
[service footer]

# test all other errors get redirected correctly
-- test errors --
[% INCLUDE no_such_file %]
-- expect --
header:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
error: [file] [no_such_file: not found]
[service footer]

# import some block definitions from 'blockdef'...
-- test block defs --
[% PROCESS blockdef -%]
[% INCLUDE block1
   a = 'alpha'
%]
-- expect --
header:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
start of blockdef

end of blockdef
This is block 1, defined in blockdef, a is alpha
[service footer]

# ...and make sure they go away for the next service
-- test reset --
[% INCLUDE block1 %]
-- expect --
header:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
error: [file] [block1: not found]
[service footer]

# now try it again with AUTO_RESET turned off...
-- test reset off --
-- use tt2 --
[% PROCESS blockdef -%]
[% INCLUDE block1
   a = 'alpha'
%]
-- expect --
header:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
start of blockdef

end of blockdef
This is block 1, defined in blockdef, a is alpha
[service footer]

# ...and the block definitions should persist
-- test blocks persist --
[% INCLUDE block1 a = 'alpha' %]
-- expect --
header:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
This is block 1, defined in blockdef, a is alpha
[service footer]

# test that the 'demo' block is still defined
-- test demo block defined --
[% INCLUDE demo %]
-- expect --
header:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
This is a demo[service footer]

# and also the 'astext' block
-- test astext block defined --
[% INCLUDE astext a = 'artifact' %]
-- expect --
header:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
Another template block, a is 'artifact'[service footer]

# test that a single ERROR template can be specified
-- test single error template --
-- use tt3 --
[% THROW food 'cabbages' %]
-- expect --
header:
  title: Joe Random Title
  menu: This is the menu, defined in 'config'
barfed: [food] [cabbages]
[service footer]

-- test layout wrapper --
-- use wrapper --
[% title = 'The Foo Page' -%]
begin page content
title is "[% title %]"
end page content
-- expect --
This comes before
<outer title="The Foo Page">
begin process
begin page content
title is "The Foo Page"
end page contentend process
</outer>
This comes after

-- test nested layout wrappers --
-- use nested --
[% title = 'The Bar Page' -%]
begin page content
title is "[% title %]"
end page content
-- expect --
This comes before
<outer title="inner The Bar Page">
<inner title="The Bar Page">
begin process
begin page content
title is "The Bar Page"
end page contentend process
</inner>

</outer>
This comes after
