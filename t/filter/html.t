#============================================================= -*-perl-*-
#
# t/filter/html.t
#
# Test the various html filters.
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
    lib     => '../../lib ../../blib/lib ../../blib/arch';

use Template::TT2::Test
    tests   => 9,
    debug   => 'Template::TT2::Filters',
    args    => \@ARGV;

test_expect(
    vars => {
        animals => join(
            "\n\n",
            'The cat sat on the mat',
            'The dog sat on the log',
            "The fish lay on the dish\nand wiggled\n",
        ),
    },
);

__DATA__
-- test html encoding --
[% FILTER html %]
This is some html text
All the <tags> should be escaped & protected
[% END %]
-- expect --
This is some html text
All the &lt;tags&gt; should be escaped &amp; protected

-- test html in filter block --
[% text = "The <cat> sat on the <mat>" %]
[% FILTER html %]
   text: [% text %]
[% END %]
-- expect --
   text: The &lt;cat&gt; sat on the &lt;mat&gt;

-- test html side-effect filter --
[% text = "The <cat> sat on the <mat>" %]
[% text FILTER html %]
-- expect --
The &lt;cat&gt; sat on the &lt;mat&gt;

-- test encoded quotes --
[% FILTER html %]
"It isn't what I expected", he replied.
[% END %]
-- expect --
&quot;It isn't what I expected&quot;, he replied.

-- test html_para --
[% animals | html_para %]
-- expect --
<p>
The cat sat on the mat
</p>

<p>
The dog sat on the log
</p>

<p>
The fish lay on the dish
and wiggled
</p>

-- test html_break --
[% animals | html_break %]
-- expect --
The cat sat on the mat
<br />
<br />
The dog sat on the log
<br />
<br />
The fish lay on the dish
and wiggled

-- test html_para_break --
[%  animals FILTER html_para_break %]
-- expect --
The cat sat on the mat
<br />
<br />
The dog sat on the log
<br />
<br />
The fish lay on the dish
and wiggled

-- test html_line_break --
[% animals FILTER html_line_break %]
-- expect --
The cat sat on the mat<br />
<br />
The dog sat on the log<br />
<br />
The fish lay on the dish<br />
and wiggled<br />

-- test xml filter --
[% FILTER xml %]
"It isn't what I expected", he replied.
[% END %]
-- expect --
&quot;It isn&apos;t what I expected&quot;, he replied.

