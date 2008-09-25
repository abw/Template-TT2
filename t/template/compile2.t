#============================================================= -*-perl-*-
#
# t/template/compile2.t
#
# Test that the compiled template files written by compile1.t can be 
# loaded and used.
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
    debug => 'Template::TT2::Templates',
    args  => \@ARGV;

use Template::TT2;
use constant ENGINE => 'Template::TT2';

use Badger::Filesystem '$Bin Dir';
my $tdir   = Dir($Bin, 'templates', 'compile');
my $config = {
    POST_CHOMP   => 1,
    INCLUDE_PATH => $tdir,
    COMPILE_EXT => '.ttc',
};

my @files = ('foo.ttc', 'complex.ttc');

# check compiled template files exist
foreach my $f (@files) {
    ok( $tdir->file($f)->exists, "$f exists" );
}

# ensure template metadata is saved in compiled file (bug fixed in v2.00)
my $out = '';
my $tt = ENGINE->new($config);
ok( $tt->process('baz', { showname => 1 }, \$out), 'processed baz' );
like( $out, qr/^name: baz/, 'name: baz matches' );

# we're going to hack on the foo.ttc file to change some key text.
# this way we can tell that the template was loaded from the compiled
# version and not the source.

my $compiled = $tdir->file('foo.ttc');
my @times    = (stat $compiled)[8,9];
my $foo      = $compiled->text;

$foo =~ s/the foo file/the hacked foo file/;

$compiled->write($foo);

# Set access/modification times back to what they were
utime( @times, $compiled );

test_expect( config => $config );


__DATA__
-- test INCLUDE hacked foo file --
[% INCLUDE foo a = 'any value' %]
-- expect --
This is the hacked foo file, a is any value

-- test INCLUDE complex --
[% META author => 'billg' version => 6.66  %]
[% INCLUDE complex %]
-- expect --
This is the header, title: Yet Another Template Test
This is a more complex file which includes some BLOCK definitions
This is the footer, author: billg, version: 6.66
- 3 - 2 - 1 

