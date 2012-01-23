#============================================================= -*-perl-*-
#
# t/plugin/image.t
#
# Tests the Image plugin.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2002,2008,2012 Andy Wardley. All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib         => '../../lib',
    Filesystem  => 'Bin Dir';

use Template::TT2::Test
    tests       => 7,
    debug       => 'Template::TT2::Plugin::Image',
    args        => \@ARGV;

my $dir = Bin->dir('data', 'images')->must_exist;

eval "use Image::Info";
if ($@) {
    eval "use Image::Size";
    skip_all('Neither Image::Info nor Image::Size installed') if $@;
}

my $vars = {
    dir  => $dir,
    file => {
        power => $dir->file('tt2_powered_grey.png'),
        hover => $dir->file('tt2_powered_orange.png'),
        name  => 'tt2_powered_orange.png',
    },
};


test_expect( vars => $vars);

__DATA__
-- test no argument --
[% TRY; USE Image; CATCH; error; END %]
-- expect --
plugin.image error - No image file specified


-- test positional argument --
[% USE Image(file.power) -%]
file: [% Image.file %]
size: [% Image.size.join(', ') %]
width: [% Image.width %]
height: [% Image.height %]
-- expect --
-- process --
file: [% file.power %]
size: 80, 15
width: 80
height: 15


-- test named parameter --
[% USE image(name = file.power) -%]
name: [% image.name %]
file: [% image.file %]
width: [% image.width %]
height: [% image.height %]
size: [% image.size.join(', ') %]
-- expect --
-- process --
name: [% file.power %]
file: [% file.power %]
width: 80
height: 15
size: 80, 15


-- test image.attr --
[% USE image file.hover -%]
attr: [% image.attr %]
-- expect --
attr: width="80" height="15"


-- test image.tag --
[% USE image file.power -%]
tag: [% image.tag %]
tag: [% image.tag(class="myimage", alt="image") %]
-- expect --
-- process --
tag: <img src="[% file.power %]" width="80" height="15" alt="" />
tag: <img src="[% file.power %]" width="80" height="15" alt="image" class="myimage" />


-- test root option --
[% USE image( root=dir name=file.name ) -%]
[% image.tag %]
-- expect --
-- process --
<img src="[% file.name %]" width="80" height="15" alt="" />


-- test separate file and name --
[% USE image( file= file.power  name="other.jpg" alt="myfile") -%]
[% image.tag %]
-- expect --
<img src="other.jpg" width="80" height="15" alt="myfile" />
