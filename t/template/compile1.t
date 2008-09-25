#============================================================= -*-perl-*-
#
# t/template/compile1.t
#
# Tests the Template::TT2::Provider maintaining a persistance cache
# of compiled templates by writing generated Perl code to files.
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

use Badger::Filesystem '$Bin Dir';
my $tdir   = Dir($Bin, 'templates', 'compile');
my $config = {
    POST_CHOMP   => 1,
    INCLUDE_PATH => $tdir,
    COMPILE_EXT  => '.ttc',
    EVAL_PERL    => 1,
};

my @files = ('foo.ttc', 'complex.ttc');

# delete any existing files
foreach my $f (@files) {
    my $file = $tdir->file($f);
    $file->delete if $file->exists;
}

test_expect( config => $config );

# check files exist
foreach my $f (@files) {
    ok( $tdir->file($f)->exists, "$f exists" );
}


__DATA__
-- test INCLUDE evalperl --
[% INCLUDE evalperl %]
-- expect --
This file includes a perl block.

-- test INCLUDE foo --
[% TRY %]
[% INCLUDE foo %]
[% CATCH file %]
Error: [% error.type %] - [% error.info %]
[% END %]
-- expect --
This is the foo file, a is 

-- test INCLUDE complex --
[% META author => 'abw' version => 3.14 %]
[% INCLUDE complex %]
-- expect --
This is the header, title: Yet Another Template Test
This is a more complex file which includes some BLOCK definitions
This is the footer, author: abw, version: 3.14
- 3 - 2 - 1 

-- test INCLUDE baz --
[% INCLUDE baz %]
-- expect --
This is the baz file, a: 

-- test broken template --
[% TRY; PROCESS broken; CATCH; error; END %]
-- expect --
parse error - broken line 2: unexpected end of input




