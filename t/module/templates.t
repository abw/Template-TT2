#============================================================= -*-perl-*-
#
# t/module/templates.t
#
# Test the Template::TT2::Templates module.
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
    lib         => '../../lib',
    Filesystem  => 'Bin Dir';

use Template::TT2::Test
    tests       => 41,
    debug       => 'Template::TT2::Templates',
    args        => \@ARGV;

use Template::TT2::Modules;
use Template::TT2::Templates;
use Template::TT2::Constants ':status TT2_MODULES';

use constant ENGINE => 'Template::TT2';

my $factory = TT2_MODULES;

# script may be being run in distribution root or 't' directory
my $dir     = Bin->dir('templates')->must_exist;
my $src     = $dir->dir('src')->must_exist;
my $lib     = $dir->dir('lib')->must_exist;
my $file    = 'foo';
my $relfile = "./t/module/templates/src/$file";
my $absfile = $src->file($file)->absolute;
my $newfile = $src->file('foobar');
my $vars = {
    file    => $file,
    relfile => $relfile,
    absfile => $absfile,
    fixfile => \&update_file,
};

# catch warnings that ABSOLUTE and RELATIVE options are deprecated
my @warnings;
$SIG{__WARN__} = sub {
    push(@warnings, shift);
};


#------------------------------------------------------------------------
# This is used to test that source files are automatically reloaded
# when updated on disk.  we call it first to write a template file, 
# which is then included in one of the -- test --  sections below.
# Then we call update_file() (via the 'fixfile' variable) and 
# include it again to see if the new file contents were loaded.
#------------------------------------------------------------------------

$newfile->write('This is the old content');

sub update_file {
    sleep(2);     # ensure file time stamps are different
    $newfile->write(@_);
}


#------------------------------------------------------------------------
# instantiate a bunch of providers, using various different techniques, 
# with different load options but sharing the same parser;  then set them
# to work fetching some files and check they respond as expected
#------------------------------------------------------------------------

my $parser = $factory->parser(
    POST_CHOMP => 1
);
ok( $parser, 'created parser' );

my $provinc = $factory->templates(
    INCLUDE_PATH => $src, 
    PARSER       => $parser,
    TOLERANT     => 1
);
ok( $provinc, 'created provider with INCLUDE_PATH' );

my $provabs = $factory->templates({
    ABSOLUTE => 1,
    PARSER   => $parser,
});
ok( $provabs, 'created provider with ABSOLUTE option' );

my $provrel = $factory->templates(
    RELATIVE => 1,
    PARSER   => $parser,
);
ok( $provrel, 'created provider with RELATIVE option' );

ok( $provinc->parser == $provabs->parser, 'first and second providers share a parser' );
ok( $provabs->parser == $provrel->parser, 'second and third providers share a parser' );

ok( delivered( $provinc, $file    ), 'provider 1 delivered $file' );
ok(  declined( $provinc, $absfile ), 'provider 1 declined $absfile' );
ok(  declined( $provinc, $relfile ), 'provider 1 declined $relfile' );

ok(  declined( $provabs, $file    ), 'provider 2 declined $file' );
ok( delivered( $provabs, $absfile ), 'provider 2 delivered $absfile' );

# We used to treat relative paths, e.g. [% INCLUDE ./foo %] as being relative 
# to the current working directory (in the Unix shell sense, not the directory
# of the template making the INCLUDE call), but it was a deeply flawed concept.
# In TT3 relative paths will be relative to the current template location and
# it will make much more sense.  As an in-between measure we've effectively 
# deprecated the RELATIVE option.  We still allow relative paths (e.g. 
# starting with a '.') to be specified, but they're treated as relative to the
# INCLUDE_PATH, so they effectively have the same end result as paths using
# absolute or floating paths, e.g. header == /header == ./header

#ok(    denied( $provabs, $relfile ), 'provider 2 denied $relfile' );
ok( delivered( $provabs, $relfile ), 'provider 2 denied $relfile' );

ok(  declined( $provrel, $file    ), 'provider 3 declined $file' );
ok(    denied( $provrel, $absfile ), 'provider 3 denied $absfile' );
ok( delivered( $provrel, $relfile ), 'provider 3 delivered $relfile' );


# This has all been simplified so that the new provider return value is
# a single template or undef to indicate declined.  Real hard errors are
# thrown as exceptions.

sub delivered {
    my ($provider, $file) = @_;
    return $provider->fetch($file);
}

sub declined {
    my ($provider, $file) = @_;
    return ! $provider->fetch($file);
}

sub denied {
    my ($provider, $file) = @_;
    return ! $provider->fetch($file);
}


#------------------------------------------------------------------------
# Test if can fetch from a file handle
#------------------------------------------------------------------------

my $ttglob = ENGINE->new;
ok( $ttglob, 'Created template for glob test' );

# Make sure we have a multi-line template file so $/ is tested.
my $glob_file = $dir->file('baz')->must_exist;
my $glob_path = $glob_file->definitive;

open GLOBFILE, $glob_path or die "Failed to open '$glob_path': $!";
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

my $ttinc = ENGINE->new( LOAD_TEMPLATES => [ $provinc ] )
    || die "$Template::ERROR\n";
ok( $ttinc );

my $ttabs = ENGINE->new( LOAD_TEMPLATES => [ $provabs ] )
    || die "$Template::ERROR\n";
ok( $ttabs );

my $ttrel = ENGINE->new( LOAD_TEMPLATES => [ $provrel ] )
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
    return [ $lib->dir('one'), $lib->dir('two') ],
}

# this one is designed to test the $MAX_DIRS runaway limit
$Template::TT2::Templates::MAX_DIRS = 42;

sub badpaths {
    return [ \&badpaths ],
}

my $dpaths = My::DPaths->new(
    $lib->dir('two'), 
    $lib->dir('one'),
);

my $ttd1 = ENGINE->new({
    INCLUDE_PATH => [ \&dpaths, $src ],
    PARSER => $parser,
}) || die "$Template::ERROR\n";
ok( $ttd1, 'dynamic path (sub) template object created' );

my $ttd2 = ENGINE->new({
    INCLUDE_PATH => [ $dpaths, $dir ],
    PARSER       => $parser,
}) || die "$Template::ERROR\n";
ok( $ttd1, 'dynamic path (obj) template object created' );

my $ttd3 = ENGINE->new({
    INCLUDE_PATH => [ \&badpaths ],
    PARSER => $parser,
}) || die "$Template::ERROR\n";
ok( $ttd3, 'dynamic path (bad) template object created' );


my $engines = {
    ttinc  => $ttinc, 
    ttabs  => $ttabs, 
    ttrel  => $ttrel,
	ttd1   => $ttd1, 
    ttd2   => $ttd2, 
    ttdbad => $ttd3 
};

test_expect(
    engines => $engines,
    engine  => $engines->{ ttinc },
    vars    => $vars,
);

ok( $warnings[0] =~ /The ABSOLUTE option is deprecated/, 'got ABSOLUTE warning' );
ok( $warnings[1] =~ /The RELATIVE option is deprecated/, 'got RELATIVE warning' );

__DATA__
-- test ttinc include relative file --
-- use ttinc --
[% TRY %]
[% INCLUDE foo %]
[% INCLUDE $relfile %]
[% CATCH file %]
Error: [% error.type %] - [% error.info.split(': ').1 %]
[% END %]
-- expect --
This is the foo file, a is Error: file - not found


-- test ttinc include absolute file --
[% TRY %]
[% INCLUDE foo %]
[% INCLUDE $absfile %]
[% CATCH file %]
Error: [% error.type %] - [% error.info.split(': ').1 %]
[% END %]
-- expect --
This is the foo file, a is Error: file - not found


-- test ttinc insert absolute file --
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

-- test ttrel include relative file --
-- use ttrel --
[% TRY %]
[% INCLUDE $relfile %]
[% INCLUDE foo %]
[% CATCH file -%]
Error: [% error.type %] - [% error.info %]
[% END %]
-- expect --
This is the foo file, a is Error: file - foo: not found

-- test ttrel include absolute file --
[% TRY %]
[% INCLUDE $relfile -%]
[% INCLUDE $absfile %]
[% CATCH file %]
Error: [% error.type %] - [% error.info.split(': ').1 %]
[% END %]
-- expect --
This is the foo file, a is Error: file - not found


-- test ttrel insert abs/rel --
foo: [% TRY; INSERT foo;      CATCH; "$error\n"; END %]
rel: [% TRY; INSERT $relfile; CATCH; "$error\n"; END +%]
abs: [% TRY; INSERT $absfile; CATCH; "$error\n"; END %]
-- expect --
-- process --
[% TAGS [* *] %]
foo: file error - foo: not found
rel: This is the foo file, a is [% a -%]
abs: file error - [* absfile *]: not found

#------------------------------------------------------------------------

-- test ttabs include absolute --
-- use ttabs --
[% TRY %]
[% INCLUDE $absfile %]
[% INCLUDE foo %]
[% CATCH file +%]
Error: [% error.type %] - [% error.info %]
[% END %]
-- expect --
This is the foo file, a is 
Error: file - foo: not found

-- test ttabs include both --
[% TRY %]
[% INCLUDE $absfile +%]
[% INCLUDE $relfile %]
[% CATCH file %]
Error: [% error.type %] - [% error.info.split(': ').1 %]
[% END %]
-- expect --
This is the foo file, a is 
This is the foo file, a is 

-- test ttabs insert abs/rel --
foo: [% TRY; INSERT foo;      CATCH; "$error\n"; END %]
rel: [% TRY; INSERT $relfile; CATCH; "$error\n"; END +%]
abs: [% TRY; INSERT $absfile; CATCH; "$error\n"; END +%]
-- expect --
-- process --
[% TAGS [* *] %]
foo: file error - foo: not found
rel: This is the foo file, a is [% a -%]
abs: This is the foo file, a is [% a -%]



#------------------------------------------------------------------------
# test that files updated on disk are automatically reloaded.
#------------------------------------------------------------------------

-- test ttinc fixfile prepare --
-- use ttinc --
[% INCLUDE foobar %]
-- expect --
This is the old content

-- test ttinc fixfile process --
[% CALL fixfile('This is the new content') %]
[% INCLUDE foobar %]
-- expect --
This is the new content

#------------------------------------------------------------------------
# dynamic path tests 
#------------------------------------------------------------------------

-- test ttd1 dynamic path process --
-- use ttd1 --
foo: [% PROCESS foo | trim +%]
bar: [% PROCESS bar | trim +%]
baz: [% PROCESS baz a='alpha' | trim %]
-- expect --
foo: This is one/foo
bar: This is two/bar
baz: This is the baz file, a: alpha

-- test ttd1 dynamic path insert --
foo: [% INSERT foo | trim +%]
bar: [% INSERT bar | trim +%]
-- expect --
foo: This is one/foo
bar: This is two/bar

-- test ttd2 dynamic path process --
-- use ttd2 --
foo: [% PROCESS foo | trim +%]
bar: [% PROCESS bar | trim +%]
baz: [% PROCESS baz a='alpha' | trim %]
-- expect --
foo: This is two/foo
bar: This is two/bar
baz: This is the baz file, a: alpha

-- test ttd2 dynamic path insert --
foo: [% INSERT foo | trim +%]
bar: [% INSERT bar | trim +%]
-- expect --
foo: This is two/foo
bar: This is two/bar

-- test ttdbad --
-- use ttdbad --
[% TRY; INCLUDE foo; CATCH; e; END %]
-- expect --
undef error - filesystem.virtual error - The number of virtual filesystem roots exceeds the max_roots limit of 42
