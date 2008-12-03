#============================================================= -*-perl-*-
#
# t/plugin/directory.t
#
# Tests the Directory plugin.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2000-2008 Andy Wardley. All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib ../../blib/arch );
use Template::TT2::Test
    debug => 'Template::TT2::Plugin::Directory 
              Template::TT2::Plugin::File',
    tests => 15,
    args  => \@ARGV;

use Badger::Filesystem '$Bin Dir';
my $dir = Dir($Bin, 'data')->must_exist;

if ($^O eq 'MSWin32') {
    # Chicken!
    skip_all('skipping tests on MS Win 32 platform');
}

my $dot = $dir->absolute;
$dot =~ s/[^\/]+/../g;
$dot =~ s|^/||g;

my $vars = {
    cwd  => $Bin,
    dir  => $dir->path,
    dot  => $dot,
};

test_expect( vars => $vars );


__DATA__

-- test no directory --
[% TRY ;
     USE Directory ;
   CATCH ;
     error ;
   END
-%]
-- expect --
Directory error - No directory specified


-- test invalid directory --
[% TRY ;
     USE Directory('/no/such/place') ;
   CATCH ;
     error.type ; ' error on ' ; error.info.split(':').0 ;
   END
-%]
-- expect --
Directory error on /no/such/place


-- test data directory --
[% USE d = Directory(dir, nostat=1) -%]
[% d.path %]
-- expect --
-- process --
[% dir %]


-- test d.path --
[% USE d = Directory(dir) -%]
[% d.path %]
-- expect --
-- process --
[% dir %]


-- test directory.path --
[% USE directory(dir) -%]
[% directory.path %]
-- expect --
-- process --
[% dir %]


-- test directory scan --
[% USE d = Directory(dir) -%]
[% FOREACH f IN d.files -%]
   - [% f.name %]
[% END -%]
[% FOREACH f = d.dirs -%]
   * [% f.name %]
[% END %]
-- expect --
   - udata1
   - udata2
   * subdir1
   * subdir2


-- test nested --
[% USE dir = Directory(dir) -%]
[% INCLUDE dir %]
[% BLOCK dir -%]
* [% dir.name %]
[% FOREACH f = dir.files -%]
    - [% f.name %]
[% END -%]
[% FOREACH f = dir.dirs  -%]
[% f.scan -%]
[% INCLUDE dir dir=f FILTER indent(4) -%]
[% END -%]
[% END -%]
-- expect --
* data
    - udata1
    - udata2
    * subdir1
        - bar
        - foo
    * subdir2
        - baz


-- test nested another way --
[% USE dir = Directory(dir) -%]
* [% dir.path %]
[% INCLUDE dir %]
[% BLOCK dir;
     FOREACH f = dir.list ;
       IF f.isdir ; -%]
    * [% f.name %]
[%       f.scan ;
	 INCLUDE dir dir=f FILTER indent(4) ;
       ELSE -%]
    - [% f.name %]
[%     END ;
    END ;
   END -%]
-- expect --
-- process --
* [% dir %]
    * subdir1
        - bar
        - foo
    * subdir2
        - baz
    - udata1
    - udata2


-- test recurse --
[% USE d = Directory(dir, recurse=1) -%]
[% FOREACH f = d.files -%]
   - [% f.name %]
[% END -%]
[% FOREACH f = d.dirs -%]
   * [% f.name %]
[% END %]
-- expect --
   - udata1
   - udata2
   * subdir1
   * subdir2


-- test full paths --
[% USE dir = Directory(dir, recurse=1) -%]
* [% dir.path %]
[% INCLUDE dir %]
[% BLOCK dir;
     FOREACH f = dir.list ;
       IF f.isdir ; -%]
    * [% f.name %] => [% f.path %] => [% f.abs %]
[%       INCLUDE dir dir=f FILTER indent(4) ;
       ELSE -%]
    - [% f.name %] => [% f.path %] => [% f.abs %]
[%     END ;
    END ;
   END -%]
-- expect --
-- process --
* [% dir %]
    * subdir1 => [% dir %]/subdir1 => [% dir %]/subdir1
        - bar => [% dir %]/subdir1/bar => [% dir %]/subdir1/bar
        - foo => [% dir %]/subdir1/foo => [% dir %]/subdir1/foo
    * subdir2 => [% dir %]/subdir2 => [% dir %]/subdir2
        - baz => [% dir %]/subdir2/baz => [% dir %]/subdir2/baz
    - udata1 => [% dir %]/udata1 => [% dir %]/udata1
    - udata2 => [% dir %]/udata2 => [% dir %]/udata2


-- test home paths --
cwd: [% cwd %]
[% USE dir = Directory(dir, recurse=1, root=cwd) -%]
* [% dir.path %]
[% INCLUDE dir %]
[% BLOCK dir;
     FOREACH f = dir.list ;
	IF f.isdir ; -%]
    * [% f.name %] => [% f.home %]
[%       INCLUDE dir dir=f FILTER indent(4) ;
       ELSE -%]
    - [% f.name %] => [% f.home %]
[%     END ;
    END ;
   END -%]
-- expect --
-- process --
cwd: [% cwd %]
* [% dir %]
    * subdir1 => [% dot %]
        - bar => [% dot %]/..
        - foo => [% dot %]/..
    * subdir2 => [% dot %]
        - baz => [% dot %]/..
    - udata1 => [% dot %]
    - udata2 => [% dot %]


-- test directory file --
[% USE dir = Directory(dir) -%]
[% file = dir.file('udata1') -%]
[% file.name %]
-- expect --
udata1

-- test dot --
[% USE dir = Directory('.', root=dir) -%]
[% dir.name %]
[% FOREACH f = dir.files -%]
- [% f.name %]
[% END -%]
-- expect --
.
- udata1
- udata2


-- test --
[% VIEW filelist -%]

[% BLOCK file -%]
f [% item.name %] => [% item.path %]
[% END -%]

[% BLOCK directory  -%]
d [% item.name %] => [% item.path %]
[% item.content(view) | indent -%]
[% END -%]

[% END -%]
[% USE dir = Directory(dir, recurse=1) -%]
[% filelist.print(dir) %]
-- expect --
-- process --
d dir => [% dir %]
    f file1 => [% dir %]/file1
    f file2 => [% dir %]/file2
    d sub_one => [% dir %]/sub_one
        f bar => [% dir %]/sub_one/bar
        f foo => [% dir %]/sub_one/foo
    d sub_two => [% dir %]/sub_two
        f waz.html => [% dir %]/sub_two/waz.html
        f wiz.html => [% dir %]/sub_two/wiz.html
    f xyzfile => [% dir %]/xyzfile



