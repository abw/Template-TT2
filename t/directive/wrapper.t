#============================================================= -*-perl-*-
#
# t/directive/wrapper.t
#
# Template script testing the WRAPPER directive.
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
    tests => 8,
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;

use Badger::Filesystem '$Bin Dir';
use constant ENGINE => 'Template::TT2';
my $tdir = Dir($Bin, 'templates');

test_expect(
    vars   => callsign,
    config => {
        INCLUDE_PATH => $tdir,
        TRIM         => 1,
    },
);

__DATA__

-- test internal wrapper --
[% BLOCK mypage %]
This is the header
[% content %]
This is the footer
[% END -%]
[% WRAPPER mypage -%]
This is the content
[%- END %]
-- expect --
This is the header
This is the content
This is the footer

-- test external wrapper --
[% WRAPPER mywrap
   title = 'Another Test' -%]
This is some more content
[%- END %]
-- expect --
Wrapper Header
Title: Another Test
This is some more content
Wrapper Footer

-- test external wrapper again --
[% WRAPPER mywrap
   title = 'Another Test' -%]
This is some content
[%- END %]
-- expect --
Wrapper Header
Title: Another Test
This is some content
Wrapper Footer


-- test nested wrappers --
[% WRAPPER page
   title = 'My Interesting Page'
%]
[% WRAPPER section
   title = 'Quantum Mechanics'
-%]
Quantum mechanics is a very interesting subject wish 
should prove easy for the layman to fully comprehend.
[%- END %]

[% WRAPPER section
   title = 'Desktop Nuclear Fusion for under $50'
-%]
This describes a simple device which generates significant 
sustainable electrical power from common tap water by process 
of nuclear fusion.
[%- END %]
[% END %]

[% BLOCK page -%]
<h1>[% title %]</h1>
[% content %]
<hr>
[% END %]

[% BLOCK section -%]
<p>
<h2>[% title %]</h2>
[% content %]
</p>
[% END %]

-- expect --
<h1>My Interesting Page</h1>

<p>
<h2>Quantum Mechanics</h2>
Quantum mechanics is a very interesting subject wish 
should prove easy for the layman to fully comprehend.
</p>

<p>
<h2>Desktop Nuclear Fusion for under $50</h2>
This describes a simple device which generates significant 
sustainable electrical power from common tap water by process 
of nuclear fusion.
</p>

<hr>

-- test side-effect chain --
[% PROCESS $s WRAPPER section FOREACH s = [ 'one' 'two' ] %]
[% BLOCK one; title = 'Block One' %]This is one[% END %]
[% BLOCK two; title = 'Block Two' %]This is two[% END %]
[% BLOCK section %]
<h1>[% title %]</h1>
<p>
[% content %]
</p>
[% END %]
-- expect --
<h1>Block One</h1>
<p>
This is one
</p><h1>Block Two</h1>
<p>
This is two
</p>

-- test PROCESS in WRAPPER --
[% BLOCK one; title = 'Block One' %]This is one[% END %]
[% BLOCK section %]
<h1>[% title %]</h1>
<p>
[% content %]
</p>
[% END %]
[% WRAPPER section -%]
[% PROCESS one %]
[%- END %]
title: [% title %]
-- expect --
<h1>Block One</h1>
<p>
This is one
</p>
title: Block One

-- test WRAPPER with args --
[% title = "foo" %]
[% WRAPPER outer title="bar" -%]
The title is [% title %]
[%- END -%]
[% BLOCK outer -%]
outer [[% title %]]: [% content %]
[%- END %]
-- expect --
outer [bar]: The title is foo

-- test WRAPPER multiple templates --
[% BLOCK a; "<a>$content</a>"; END; 
   BLOCK b; "<b>$content</b>"; END;
   BLOCK c; "<c>$content</c>"; END;
   WRAPPER a + b + c; 'FOO'; END;
%]
-- expect --
<a><b><c>FOO</c></b></a>

-- stop --
# This next text demonstrates a limitation in the parser
# http://tt2.org/pipermail/templates/2006-January/008197.html

-- test--
[% BLOCK a; "<a>$content</a>"; END; 
   BLOCK b; "<b>$content</b>"; END;
   BLOCK c; "<c>$content</c>"; END;
   A='a'; 
   B='b';
   C='c';
   WRAPPER $A + $B + $C; 'BAR'; END;
%]
-- expect --
<a><b><c>BAR</c></b></a>

