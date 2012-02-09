#============================================================= -*-perl-*-
#
# t/language/plusfile.t
#
# Test ability to specify INCLUDE/PROCESS/WRAPPER files in the 
# form "foo+bar+baz".
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
    lib        => '../../lib ../../blib/arch',
    Filesystem => 'Bin';

use Template::TT2::Test
    tests => 6,
    debug => 'Template::TT2::Templates',
    args  => \@ARGV;

use Template::TT2 'TT2_MODULES';
my $tdir = Bin->dir('templates', 'plusfile')->must_exist;

test_expect( config => { INCLUDE_PATH => $tdir });

__DATA__
-- test INCLUDE foo --
[% INCLUDE foo %]
[% BLOCK foo; "This is foo!"; END %]
-- expect --
This is foo!

-- test INCLUDE foo+bar --
[% INCLUDE foo+bar -%]
[% BLOCK foo; "This is foo!\n"; END %]
[% BLOCK bar; "This is bar!\n"; END %]
-- expect --
This is foo!
This is bar!

-- test PROCESS foo+bar --
[% PROCESS foo+bar -%]
[% BLOCK foo; "This is foo!\n"; END %]
[% BLOCK bar; "This is bar!\n"; END %]
-- expect --
This is foo!
This is bar!

-- test WRAPPER edge + box + indent --
[% WRAPPER edge + box + indent
     title = "The Title" -%]
My content
[% END -%]
[% BLOCK indent -%]
<indent>
[% content -%]
</indent>
[% END -%]
[% BLOCK box -%]
<box>
[% content -%]
</box>
[% END -%]
[% BLOCK edge -%]
<edge>
[% content -%]
</edge>
[% END -%]
-- expect --
<edge>
<box>
<indent>
My content
</indent>
</box>
</edge>


-- test INSERT foo+bar/baz --
[% INSERT foo+bar/baz %]
-- expect --
This is the foo file, a is [% a -%][% DEFAULT word = 'qux' -%]
This is file baz
The word is '[% word %]'

-- test INSERT "$file1" + "$file2" --
[% file1 = 'foo'
   file2 = 'bar/baz'
-%]
[% INSERT "$file1" + "$file2" %]
-- expect --
This is the foo file, a is [% a -%][% DEFAULT word = 'qux' -%]
This is file baz
The word is '[% word %]'

