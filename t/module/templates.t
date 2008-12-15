#============================================================= -*-perl-*-
#
# t/module/templates.t
#
# Test the Template::TT2::Templates module.
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
use Badger::Filesystem '$Bin Dir';
use Template::TT2;
use Template::TT2::Modules;
use Template::TT2::Templates;
use Template::TT2::Constants ':status TT2_MODULES';
use Template::TT2::Test
    tests => 14,
    debug => 'Template::TT2::Templates',
    args  => \@ARGV;

use constant ENGINE => 'Template::TT2';

my $factory = TT2_MODULES;

# script may be being run in distribution root or 't' directory
my $dir     = Dir($Bin)->dir('templates')->must_exist;
my $src     = $dir->dir('src')->must_exist;
my $lib     = $dir->dir('lib')->must_exist;
my $file    = 'foo';
my $relfile = "./$dir/$file";
my $absfile = $dir->file($file)->absolute;
my $newfile = "$dir/foobar";
my $vars = {
    file    => $file,
    relfile => $relfile,
    absfile => $absfile,
    fixfile => \&update_file,
};


#------------------------------------------------------------------------
# This is used to test that source files are automatically reloaded
# when updated on disk.  we call it first to write a template file, 
# which is then included in one of the -- test --  sections below.
# Then we call update_file() (via the 'fixfile' variable) and 
# include it again to see if the new file contents were loaded.
#------------------------------------------------------------------------

sub update_file {
    local *FP;
    sleep(2);     # ensure file time stamps are different
    open(FP, ">$newfile") || die "$newfile: $!\n";
    print(FP @_) || die "failed to write $newfile: $!\n";
    close(FP);
}

update_file('This is the old content');


#------------------------------------------------------------------------
# instantiate a bunch of providers, using various different techniques, 
# with different load options but sharing the same parser;  then set them
# to work fetching some files and check they respond as expected
#------------------------------------------------------------------------

my $parser = $factory->parser(POST_CHOMP => 1);
ok( $parser );

my $provinc = $factory->templates(
    INCLUDE_PATH => $src, 
    PARSER       => $parser,
    TOLERANT     => 1
);
ok( $provinc );

my $provabs = $factory->templates({ 
    ABSOLUTE => 1, 
    PARSER   => $parser, 
});
ok( $provabs );

my $provrel = $factory->templates(
    RELATIVE => 1, 
    PARSER   => $parser, 
);
ok( $provrel );

ok( $provinc->parser == $provabs->parser );
ok( $provabs->parser == $provrel->parser );

ok( delivered( $provinc, $file    ) );
ok(  declined( $provinc, $absfile ) );
ok(  declined( $provinc, $relfile ) );

ok(  declined( $provabs, $file    ) );
ok( delivered( $provabs, $absfile ) );
ok(    denied( $provabs, $relfile ) );

ok(  declined( $provrel, $file    ) );
ok(    denied( $provrel, $absfile ) );
ok( delivered( $provrel, $relfile ) );


sub delivered {
    my ($provider, $file) = @_;
    my ($result, $error) = $provider->fetch($file);
    my $nice_result = defined $result ? $result : '<undef>';
    my $nice_error  = defined $error  ? $error : '<undef>';
#    print STDERR "$provider->fetch($file) -> [$nice_result] [$nice_error]\n"
#	if $DEBUG;
    return ! $error;
}

sub declined {
    my ($provider, $file) = @_;
    my ($result, $error) = $provider->fetch($file);
    my $nice_result = defined $result ? $result : '<undef>';
    my $nice_error  = defined $error  ? $error : '<undef>';
#    print STDERR "$provider->fetch($file) -> [$nice_result] [$nice_error]\n"
#	if $DEBUG;
    return ($error == STATUS_DECLINED);
}

sub denied {
    my ($provider, $file) = @_;
    my ($result, $error) = $provider->fetch($file);
#    print STDERR "$provider->fetch($file) -> [$result] [$error]\n"
#	if $DEBUG;
    return ($error == STATUS_ERROR);
}


exit;


#------------------------------------------------------------------------
# Test if can fetch from a file handle
#------------------------------------------------------------------------

my $ttglob = Template->new || die "$Template::ERROR\n";
ok( $ttglob, 'Created template for glob test' );

# Make sure we have a multi-line template file so $/ is tested.
my $glob_file = abs_path($dir) . '/baz';

open GLOBFILE, $glob_file or die "Failed to open '$absfile': $!";
my $outstr = '';

$ttglob->process( \*GLOBFILE, { a => 'globtest' }, \$outstr ) || die $ttglob->error;

close GLOBFILE;

my $glob_expect = "This is the baz file, a: globtest\n";

my $ok = $glob_expect eq $outstr;

ok( $ok, $ok ? 'Fetch template from file handle' : <<EOF );
template text did not match template from file handle
MATCH FAILED
expect: $glob_expect
output: $outstr
EOF


#------------------------------------------------------------------------
# now we'll fold those providers up into some Template objects that
# we can pass to text_expect() to do some template driven testing
#------------------------------------------------------------------------

my $ttinc = Template->new( LOAD_TEMPLATES => [ $provinc ] )
    || die "$Template::ERROR\n";
ok( $ttinc );

my $ttabs = Template->new( LOAD_TEMPLATES => [ $provabs ] )
    || die "$Template::ERROR\n";
ok( $ttabs );

my $ttrel = Template->new( LOAD_TEMPLATES => [ $provrel ] )
    || die "$Template::ERROR\n";
ok( $ttrel );


#------------------------------------------------------------------------
# here's a test of the dynamic path capability.  we'll define a handler
# sub and an object to return a dynamic list of paths
#------------------------------------------------------------------------

package My::DPaths;

sub new {
    my ($class, @paths) = @_;
    bless \@paths, $class;
}
sub paths {
    my $self = shift;
    return [ @$self ];
}

package main;

sub dpaths {
    return [ "$lib/one", "$lib/two" ],
}

# this one is designed to test the $MAX_DIRS runaway limit
$Template::TT2::Templates::MAX_DIRS = 42;

sub badpaths {
    return [ \&badpaths ],
}

my $dpaths = My::DPaths->new("$lib/two", "$lib/one");

my $ttd1 = Template->new({
    INCLUDE_PATH => [ \&dpaths, $dir ],
    PARSER => $parser,
}) || die "$Template::ERROR\n";
ok( $ttd1, 'dynamic path (sub) template object created' );

my $ttd2 = Template->new({
    INCLUDE_PATH => [ $dpaths, $dir ],
    PARSER => $parser,
}) || die "$Template::ERROR\n";
ok( $ttd1, 'dynamic path (obj) template object created' );

my $ttd3 = Template->new({
    INCLUDE_PATH => [ \&badpaths ],
    PARSER => $parser,
}) || die "$Template::ERROR\n";
ok( $ttd3, 'dynamic path (bad) template object created' );


my $uselist = [ 
    ttinc  => $ttinc, 
    ttabs  => $ttabs, 
    ttrel  => $ttrel,
	ttd1   => $ttd1, 
    ttd2   => $ttd2, 
    ttdbad => $ttd3 ];

test_expect(\*DATA, $uselist, $vars);


__DATA__
-- test --
-- use ttinc --
[% TRY %]
[% INCLUDE foo %]
[% INCLUDE $relfile %]
[% CATCH file %]
Error: [% error.type %] - [% error.info.split(': ').1 %]
[% END %]
-- expect --
This is the foo file, a is Error: file - not found


-- test --
[% TRY %]
[% INCLUDE foo %]
[% INCLUDE $absfile %]
[% CATCH file %]
Error: [% error.type %] - [% error.info.split(': ').1 %]
[% END %]
-- expect --
This is the foo file, a is Error: file - not found


-- test --
[% TRY %]
[% INSERT foo +%]
[% INSERT $absfile %]
[% CATCH file %]
Error: [% error %]
[% END %]
-- expect --
-- process --
[% TAGS [* *] %]
This is the foo file, a is [% a -%]
Error: file error - [* absfile *]: not found

#------------------------------------------------------------------------

-- test --
-- use ttrel --
[% TRY %]
[% INCLUDE $relfile %]
[% INCLUDE foo %]
[% CATCH file -%]
Error: [% error.type %] - [% error.info %]
[% END %]
-- expect --
This is the foo file, a is Error: file - foo: not found

-- test --
[% TRY %]
[% INCLUDE $relfile -%]
[% INCLUDE $absfile %]
[% CATCH file %]
Error: [% error.type %] - [% error.info.split(': ').1 %]
[% END %]
-- expect --
This is the foo file, a is Error: file - absolute paths are not allowed (set ABSOLUTE option)


-- test --
foo: [% TRY; INSERT foo;      CATCH; "$error\n"; END %]
rel: [% TRY; INSERT $relfile; CATCH; "$error\n"; END +%]
abs: [% TRY; INSERT $absfile; CATCH; "$error\n"; END %]
-- expect --
-- process --
[% TAGS [* *] %]
foo: file error - foo: not found
rel: This is the foo file, a is [% a -%]
abs: file error - [* absfile *]: absolute paths are not allowed (set ABSOLUTE option)

#------------------------------------------------------------------------

-- test --
-- use ttabs --
[% TRY %]
[% INCLUDE $absfile %]
[% INCLUDE foo %]
[% CATCH file %]
Error: [% error.type %] - [% error.info %]
[% END %]
-- expect --
This is the foo file, a is Error: file - foo: not found

-- test --
[% TRY %]
[% INCLUDE $absfile %]
[% INCLUDE $relfile %]
[% CATCH file %]
Error: [% error.type %] - [% error.info.split(': ').1 %]
[% END %]
-- expect --
This is the foo file, a is Error: file - relative paths are not allowed (set RELATIVE option)


-- test --
foo: [% TRY; INSERT foo;      CATCH; "$error\n"; END %]
rel: [% TRY; INSERT $relfile; CATCH; "$error\n"; END %]
abs: [% TRY; INSERT $absfile; CATCH; "$error\n"; END %]
-- expect --
-- process --
[% TAGS [* *] %]
foo: file error - foo: not found
rel: file error - [* relfile *]: relative paths are not allowed (set RELATIVE option)
abs: This is the foo file, a is [% a -%]



#------------------------------------------------------------------------
# test that files updated on disk are automatically reloaded.
#------------------------------------------------------------------------

-- test --
-- use ttinc --
[% INCLUDE foobar %]
-- expect --
This is the old content

-- test --
[% CALL fixfile('This is the new content') %]
[% INCLUDE foobar %]
-- expect --
This is the new content

#------------------------------------------------------------------------
# dynamic path tests 
#------------------------------------------------------------------------

-- test --
-- use ttd1 --
foo: [% PROCESS foo | trim +%]
bar: [% PROCESS bar | trim +%]
baz: [% PROCESS baz a='alpha' | trim %]
-- expect --
foo: This is one/foo
bar: This is two/bar
baz: This is the baz file, a: alpha

-- test --
foo: [% INSERT foo | trim +%]
bar: [% INSERT bar | trim +%]
-- expect --
foo: This is one/foo
bar: This is two/bar

-- test --
-- use ttd2 --
foo: [% PROCESS foo | trim +%]
bar: [% PROCESS bar | trim +%]
baz: [% PROCESS baz a='alpha' | trim %]
-- expect --
foo: This is two/foo
bar: This is two/bar
baz: This is the baz file, a: alpha

-- test --
foo: [% INSERT foo | trim +%]
bar: [% INSERT bar | trim +%]
-- expect --
foo: This is two/foo
bar: This is two/bar

-- test --
-- use ttdbad --
[% TRY; INCLUDE foo; CATCH; e; END %]
-- expect --
file error - INCLUDE_PATH exceeds 42 directories
