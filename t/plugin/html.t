#============================================================= -*-perl-*-
#
# t/plugin/html.t
#
# Tests the 'HTML' plugin.
#
# Run with -h option for help.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2001,2012 Andy Wardley. All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib   => '../lib ../../lib ../../blib/lib ../../blib/arch';

use Template::TT2::Test
    tests => 7,
    debug => 'Template::TT2::Plugin::HTML',
    args  => \@ARGV;

test_expect(); 

__DATA__

-- test HTML plugin loads --
[% USE HTML -%]
OK
-- expect --
OK

-- test html plugin loads --
[% USE html -%]
OK
-- expect --
OK

-- test Html plugin loads --
[% USE Html -%]
OK
-- expect --
OK

-- test html.url --
[% USE html; html.url('my file.html') -%]
-- expect --
my%20file.html

-- test html.escape --
[% USE HTML -%]
[% HTML.escape("if (a < b && c > d) ...") %]
-- expect --
if (a &lt; b &amp;&amp; c &gt; d) ...

-- test element --
[% USE HTML(sorted=1) -%]
[% HTML.element(table => { border => 1, cellpadding => 2 }) %]
-- expect --
<table border="1" cellpadding="2">

-- test attributes --
[% USE HTML -%]
[% HTML.attributes(border => 1, cellpadding => 2).split.sort.join %]
-- expect --
border="1" cellpadding="2"

