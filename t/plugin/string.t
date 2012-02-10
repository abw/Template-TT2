#============================================================= -*-perl-*-
#
# t/plugin/string.t
#
# Test the String plugin
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
#
#========================================================================

use Badger
    lib   => '../../lib ../../blib/lib ../../blib/arch';

use Template::TT2::Test
    tests => 46,
    debug => 'Template::TT2::Plugin::String',
    args  => \@ARGV;

test_expect();

__DATA__
-- test empty string --
[% USE String -%]
string: [[% String.text %]]
-- expect --
string: []

-- test positional argument --
[% USE String 'hello world' -%]
string: [[% String.text %]]
-- expect --
string: [hello world]

-- test named parameter --
[% USE String text='hello world' -%]
string: [[% String.text %]]
-- expect --
string: [hello world]

-- test auto-stringy on empty --
[% USE String -%]
string: [[% String %]]
-- expect --
string: []

-- test auto-stringy with positional arg --
[% USE String 'hello world' -%]
string: [[% String %]]
-- expect --
string: [hello world]

-- test auto-stringy on named param --
[% USE String text='hello world' -%]
string: [[% String %]]
-- expect --
string: [hello world]

-- test append --
[% USE String text='hello' -%]
string: [[% String.append(' world') %]]
string: [[% String %]]
-- expect --
string: [hello world]
string: [hello world]

-- test copy --
[% USE String text='hello' -%]
[% copy = String.copy -%]
string: [[% String %]]
string: [[% copy %]]
-- expect --
string: [hello]
string: [hello]

-- test class new --
[% USE String -%]
[% hi = String.new('hello') -%]
[% lo = String.new('world') -%]
[% hw = String.new(text="$hi $lo") -%]
hi: [[% hi %]]
lo: [[% lo %]]
hw: [[% hw %]]
-- expect --
hi: [hello]
lo: [world]
hw: [hello world]

-- test object new --
[% USE hi = String 'hello' -%]
[% lo = hi.new('world') -%]
hi: [[% hi %]]
lo: [[% lo %]]
-- expect --
hi: [hello]
lo: [world]

-- test plugin alias --
[% USE hi = String 'hello' -%]
[% lo = hi.copy -%]
hi: [[% hi %]]
lo: [[% lo %]]
-- expect --
hi: [hello]
lo: [hello]

-- test plugin alias copy --
[% USE hi = String 'hello' -%]
[% lo = hi.copy.append(' world') -%]
hi: [[% hi %]]
lo: [[% lo %]]
-- expect --
hi: [hello]
lo: [hello world]

-- test plugin alias new copy --
[% USE hi = String 'hello' -%]
[% lo = hi.new('hey').append(' world') -%]
hi: [[% hi %]]
lo: [[% lo %]]
-- expect --
hi: [hello]
lo: [hey world]

-- test chomp --
[% USE hi=String "hello world\n" -%]
hi: [[% hi %]]
[% lo = hi.chomp -%]
hi: [[% hi %]]
lo: [[% lo %]]
-- expect --
hi: [hello world
]
hi: [hello world]
lo: [hello world]

-- test chop --
[% USE foo=String "foop" -%]
[[% foo.chop %]]
[[% foo.chop %]]
-- expect --
[foo]
[fo]

-- test left right centre center --
[% USE hi=String "hello" -%]
  left: [[% hi.copy.left(11) %]]
 right: [[% hi.copy.right(11) %]]
center: [[% hi.copy.center(11) %]]
centre: [[% hi.copy.centre(12) %]]
-- expect --
  left: [hello      ]
 right: [      hello]
center: [   hello   ]
centre: [   hello    ]

-- test upper lower capital --
[% USE str=String('hello world') -%]
 hi: [[% str.upper %]]
 hi: [[% str %]]
 lo: [[% str.lower %]]
cap: [[% str.capital %]]
-- expect --
 hi: [HELLO WORLD]
 hi: [HELLO WORLD]
 lo: [hello world]
cap: [Hello world]

-- test length --
[% USE str=String('hello world') -%]
len: [[% str.length %]]
-- expect --
len: [11]

-- test trim --
[% USE str=String("   \n\n\t\r hello\nworld\n\r  \n \r") -%]
[[% str.trim %]]
-- expect --
[hello
world]

-- test collapse --
[% USE str=String("   \n\n\t\r hello  \n \n\r world\n\r  \n \r") -%]
[[% str.collapse %]]
-- expect --
[hello world]

-- test append prepend --
[% USE str=String("hello") -%]
[[% str.append(' world') %]]
[[% str.prepend('well, ') %]]
-- expect --
[hello world]
[well, hello world]

-- test push unshift --
[% USE str=String("hello") -%]
[[% str.push(' world') %]]
[[% str.unshift('well, ') %]]
-- expect --
[hello world]
[well, hello world]

-- test pop shift --
[% USE str=String('foo bar') -%]
[[% str.copy.pop(' bar') %]]
[[% str.copy.shift('foo ') %]]
-- expect --
[foo]
[bar]

-- test truncate --
[% USE str=String('Hello World') -%]
[[% str.copy.truncate(5) %]]
[[% str.copy.truncate(8, '...') %]]
[[% str.copy.truncate(20, '...') %]]
-- expect --
[Hello]
[Hello...]
[Hello World]

-- test append --
[% USE String('foo') -%]
[[% String.append(' ').repeat(4) %]]
-- expect --
[foo foo foo foo ]

-- test format --
[% USE String('foo') -%]
[% String.format("[%s]") %]
-- expect --
[foo]

-- test replace --
[% USE String('foo bar foo baz') -%]
[[% String.replace('foo', 'oof') %]]
-- expect --
[oof bar oof baz]

-- test remove --
[% USE String('foo bar foo baz') -%]
[[% String.copy.remove('foo\s*') %]]
[[% String.copy.remove('ba[rz]\s*') %]]
-- expect --
[bar baz]
[foo foo ]

-- test split join --
[% USE String('foo bar foo baz') -%]
[[% String.split.join(', ') %]]
-- expect --
[foo, bar, foo, baz]

-- test split args --
[% USE String('foo bar foo baz') -%]
[[% String.split(' bar ').join(', ') %]]
-- expect --
[foo, foo baz]

-- test join args --
[% USE String('foo bar foo baz') -%]
[[% String.split(' bar ').join(', ') %]]
-- expect --
[foo, foo baz]

-- test split join args --
[% USE String('foo bar foo baz') -%]
[[% String.split('\s+').join(', ') %]]
-- expect --
[foo, bar, foo, baz]

-- test Have you seen my badger? --
[% USE String('foo bar foo baz') -%]
[[% String.split('\s+', 2).join(', ') %]]
-- expect --
[foo, bar foo baz]


-- test He said he was just popping out for a newspaper --
[% USE String('foo bar foo baz') -%]
[% String.search('foo') ? 'ok' : 'not ok' %]
[% String.search('fooz') ? 'not ok' : 'ok' %]
[% String.search('^foo') ? 'ok' : 'not ok' %]
[% String.search('^bar') ? 'not ok' : 'ok' %]
-- expect --
ok
ok
ok
ok


-- test That was 3 days ago --
[% USE String 'foo < bar' filter='html' -%]
[% String %]
-- expect --
foo &lt; bar

-- test I wouldn't be surprised --
[% USE String 'foo bar' filter='uri' -%]
[% String %]
-- expect --
foo%20bar

-- test if he was lying drunk in a ditch somewhere. --
[% USE String 'foo bar' filters='uri' -%]
[% String %]
-- expect --
foo%20bar

-- test It wouldn't be the first time. --
[% USE String '   foo bar    ' filters=['trim' 'uri'] -%]
[[% String %]]
-- expect --
[foo%20bar]

-- test Sigh.  Badgers will be badgers. --
[% USE String '   foo bar    ' filter='trim, uri' -%]
[[% String %]]
-- expect --
[foo%20bar]

-- test I guess you can take a badger out of the forest --
[% USE String '   foo bar    ' filters='trim, uri' -%]
[[% String %]]
-- expect --
[foo%20bar]

-- test but you can't take the forest out of a badger. --
[% USE String 'foo bar' filters={ replace=['bar', 'baz'],
				  trim='', uri='' } -%]
[[% String %]]
-- expect --
[foo%20baz]

-- test Snake!  Snake! --
[% USE String 'foo bar' filters=[ 'replace', ['bar', 'baz'],
				  'trim', 'uri' ] -%]
[[% String %]]
-- expect --
[foo%20baz]

-- test Are we nearly done? --
[% USE String 'foo bar' -%]
[% String %]
[% String.filter('uri') %]
[% String.filter('replace', 'bar', 'baz') %]
[% String.output_filter('uri') -%]
[% String %]
[% String.output_filter({ repeat => [3] }) -%]
[% String %]
-- expect --
foo bar
foo%20bar
foo baz
foo%20bar
foo%20barfoo%20barfoo%20bar

-- test Thank you for playing along at home. --
[% USE String;
   a = 'HeLLo';
   b = 'hEllO';
   a == b ? "not ok 0\n" : "ok 0\n";
   String.new(a) == String.new(b) ? "not ok 1\n" : "ok 1\n";
   String.new(a).lower == String.new(b).lower ? "ok 2\n" : "not ok 2\n";
   String.new(a).lower.equals(String.new(b).lower) ? "ok 3\n" : "not ok 3\n";
   a.search("(?i)^$b\$") ? "ok 4\n" : "not ok 4\n";
-%]
-- expect --
ok 0
ok 1
ok 2
ok 3
ok 4

-- test We hope you enjoyed these tests. --
[% USE String('Hello World') -%]
a: [% String.substr(6) %]!
b: [% String.substr(0, 5) %]!
c: [% String.substr(0, 5, 'Goodbye') %]!
d: [% String %]!
-- expect --
a: World!
b: Hello!
c: Hello!
d: Goodbye World!

-- test The soundtrack is available in the foyer --
[% USE str = String('foo bar baz wiz waz woz') -%]
a: [% str.substr(4, 3) %]
b: [% str.substr(12) %]
c: [% str.substr(0, 11, 'FOO') %]
d: [% str %]
-- expect --
a: bar
b: wiz waz woz
c: foo bar baz
d: FOO wiz waz woz

