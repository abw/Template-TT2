#============================================================= -*-perl-*-
#
# t/plugin/pod.t
#
# Tests the 'Pod' plugin.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2001,2008 Andy Wardley. All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Template::TT2::Test
    tests => 7,
    debug => 'Template::TT2::Plugin::Pod',
    args  => \@ARGV;

use Badger::Filesystem '$Bin Dir';
my $pod       = Dir($Bin, 'pod')->must_exist;
my $templates = $pod->dir('templates')->must_exist;

eval "use Pod::POM";
if ($@) {
    skip_all('Pod::POM not installed');
}

my $config = {
    INCLUDE_PATH => $templates,
};

my $vars = {
    podloc => $pod,
};

test_expect(
    config => $config, 
    vars   => $vars,
);

__DATA__
-- test no such file --
[%  USE pod;
    pom = pod.parse("$podloc/no_such_file.pod");
    pom ? 'not ok' : 'ok'; ' - file does not exist';
%]
-- expect --
ok - file does not exist

-- test test1.pod --
[%  USE pod;
    pom = pod.parse("$podloc/test1.pod");
    pom ? 'ok' : 'not ok'; ' - file parsed';
    global.pom = pom;
    global.warnings = pod.warnings;
%]
-- expect --
ok - file parsed

-- test warnings --
[%  global.warnings.join("\n") %]
-- expect --
-- process --
spurious '>' at [% podloc %]/test1.pod line 17
spurious '>' at [% podloc %]/test1.pod line 21

-- test head1 --
[% FOREACH h1 IN global.pom.head1 -%]
* [% h1.title %]
[% END %]
-- expect --
* NAME
* SYNOPSIS
* DESCRIPTION
* THE END

-- test head2 --
[% FOREACH h2 = global.pom.head1.2.head2 -%]
+ [% h2.title %]
[% END %]
-- expect --
+ First Subsection
+ Second Subsection

-- test item.type --
[% PROCESS $item.type 
    FOREACH item IN global.pom.head1.2.content %]

[% BLOCK head2 -%]
<h2>[% item.title | trim %]</h2>
[% END %]

[% BLOCK text -%]
<p>[% item | trim %]</p>
[% END %]

[% BLOCK verbatim -%]
<pre>[% item | trim %]</pre>
[% END %]
-- expect --
<p>This is the description for My::Module.</p>
<pre>This is verbatim</pre>
<h2>First Subsection</h2>
<h2>Second Subsection</h2>

-- test pod view --
[%  VIEW v prefix='pod2html/';
	BLOCK list; 
	    view.print(i) FOREACH i = item; 
	END;
    END;
    v.print(global.pom);
%]
-- expect --
<!-- Pod to HTML conversion by the Template Toolkit version 2 -->
<h1>NAME</h1>

<p>
My::Module
</p>

<h1>SYNOPSIS</h1>

<pre>    use My::Module;</pre>

<h1>DESCRIPTION</h1>

<p>
This is the description for My::Module.
</p>
<pre>    This is verbatim</pre>
<h2>First Subsection</h2>

<p>
This is the first subsection.  foo-&gt;bar();
</p>

<h2>Second Subsection</h2>

<p>
This is the second subsection.  bar-&gt;baz();
</p>


<h1>THE END</h1>

<p>
This is the end.  Beautiful friend, the end.
</p>
