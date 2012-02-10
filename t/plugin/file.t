#============================================================= -*-perl-*-
#
# t/plugin/file.t
#
# Tests the File plugin.
#
# Run with -h option for help.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2000-2012 Andy Wardley. All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib        => '../../lib ../../blib/lib ../../blib/arch',
    Filesystem => 'Bin';

use Template::TT2::Test
    debug => 'Template::TT2::Plugin::Directory 
              Template::TT2::Plugin::File',
    tests => 11,
    args  => \@ARGV;

use Template::TT2::Plugin::File;
my $dir  = Bin->dir('data')->must_exist;
my $file = $dir->file( subdir1 => 'foo' );
my @stat = stat($file);

if ($^O eq 'MSWin32') {
    skip_all('skipping tests on MS Win 32 platform');
}

my $vars = {
    dir  => $dir,
    file => $file,
};
@$vars{ @Template::TT2::Plugin::File::STAT_KEYS } = @stat;

test_expect( vars => $vars );

__DATA__
-- test absolute path --
[% USE File('/foo/bar/baz.html', nostat=1) -%]
p: [% File.path %]
r: [% File.root %]
n: [% File.name %]
d: [% File.dir %]
e: [% File.ext %]
h: [% File.home %]
a: [% File.abs %]
-- expect --
p: /foo/bar/baz.html
r: 
n: baz.html
d: /foo/bar
e: html
h: ../..
a: /foo/bar/baz.html


-- test absolute path with alias --
[% USE f = File('foo/bar/baz.html', nostat=1) -%]
p: [% f.path %]
r: [% f.root %]
n: [% f.name %]
d: [% f.dir %]
e: [% f.ext %]
h: [% f.home %]
a: [% f.abs %]
-- expect --
p: foo/bar/baz.html
r: 
n: baz.html
d: foo/bar
e: html
h: ../..
a: foo/bar/baz.html


-- test relative path --
[% USE f = File('baz.html', nostat=1) -%]
p: [% f.path %]
r: [% f.root %]
n: [% f.name %]
d: [% f.dir %]
e: [% f.ext %]
h: [% f.home %]
a: [% f.abs %]
-- expect --
p: baz.html
r: 
n: baz.html
d: 
e: html
h: 
a: baz.html


-- test root option --
[% USE f = File('bar/baz.html', root='/foo', nostat=1) -%]
p: [% f.path %]
r: [% f.root %]
n: [% f.name %]
d: [% f.dir %]
e: [% f.ext %]
h: [% f.home %]
a: [% f.abs %]
-- expect --
p: bar/baz.html
r: /foo
n: baz.html
d: bar
e: html
h: ..
a: /foo/bar/baz.html


-- test rel method -- 
[% USE f = File('bar/baz.html', root='/foo', nostat=1) -%]
p: [% f.path %]
h: [% f.home %]
rel: [% f.rel('wiz/waz.html') %]
-- expect --
p: bar/baz.html
h: ..
rel: ../wiz/waz.html


-- test root option -- 
[% USE baz = File('foo/bar/baz.html', root='/tmp/tt2', nostat=1) -%]
[% USE waz = File('wiz/woz/waz.html', root='/tmp/tt2', nostat=1) -%]
[% baz.rel(waz) %]
-- expect --
../../wiz/woz/waz.html


-- test no access time --
[% USE f = File('foo/bar/baz.html', nostat=1) -%]
[[% f.atime %]]
-- expect --
[]


-- test real file path --
[% USE f = File(file) -%]
[% f.path %]
[% f.name %]
-- expect --
-- process --
[% dir %]/subdir1/foo
foo


-- test access time --
[% USE f = File(file) -%]
[% f.path %]
[% f.mtime %]
-- expect --
-- process --
[% dir %]/subdir1/foo
[% mtime %]


-- test modfication time --
[% USE file(file) -%]
[% file.path %]
[% file.mtime %]
-- expect --
-- process --
[% dir %]/subdir1/foo
[% mtime %]


-- test no filename --
[% TRY -%]
[% USE f = File('') -%]
n: [% f.name %]
[% CATCH -%]
Drat, there was a [% error.type %] error.
[% END %]
-- expect --
Drat, there was a File error.


