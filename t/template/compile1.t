#============================================================= -*-perl-*-
#
# t/template/compile1.t
#
# Tests the Template::TT2::Provider maintaining a persistance cache
# of compiled templates by writing generated Perl code to files.
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
    lib         => '../../lib ../../blib/lib ../../blib/arch',
    Filesystem  => 'Bin';

use Template::TT2::Test
    tests => 9,
    debug => 'Template::TT2::Templates',
    args  => \@ARGV;

my $tdir   = Bin->dir('templates', 'compile')->must_exist;
my $config = {
    POST_CHOMP   => 1,
    INCLUDE_PATH => $tdir,
    COMPILE_EXT  => '.ttc',
    EVAL_PERL    => 1,
};

my @files = ('foo.ttc', 'complex.ttc', 'divisionbyzero.ttc' );
    
# delete any existing files
foreach my $f (@files) {
    my $file = $tdir->file($f);
    $file->delete if $file->exists;
}

test_expect( 
    config  => $config,
    dir     => $tdir,
);

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

-- test --
[%- # first pass, writes the compiled code to cache -%]
[% INCLUDE divisionbyzero %]
XXX
-- expect --
-- process --
undef error - Illegal division by zero at divisionbyzero line 1.
XXX                                       

-- test broken template --
[% TRY; PROCESS broken; CATCH; error; END %]
-- expect --
parse error - broken line 2: unexpected end of input

