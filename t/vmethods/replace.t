#============================================================= -*-perl-*-
#
# t/vmethods/replace.t
#
# Testing the 'replace' scalar virtual method, and in particular the
# use of backreferences.
#
# Written by Andy Wardley <abw@cpan.org> and Sergey Martynoff 
# <sergey@martynoff.info>
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
    tests       => 19,
    debug       => 'Template::TT2::VMethods',
    args        => \@ARGV;

test_expect();

__DATA__
-- test two backrefs --
[% text = 'The cat sat on the mat';
   text.replace( '(\w+) sat on the (\w+)',
                 'dirty $1 shat on the filthy $2' )
%]
-- expect --
The dirty cat shat on the filthy mat


# test more than 9 captures to make sure $10, $11, etc., work ok
-- test ten+ backrefs --
[% text = 'one two three four five six seven eight nine ten eleven twelve thirteen';
   text.replace(
      '(\w+) (\w+) (\w+) (\w+) (\w+) (\w+) (\w+) (\w+) (\w+) (\w+) (\w+) (\w+)',
      '[$12-$11-$10-$9-$8-$7-$6-$5-$4-$3-$2-$1]'
   )
%]
-- expect --
[twelve-eleven-ten-nine-eight-seven-six-five-four-three-two-one] thirteen


-- test repeat backrefs --
[% text = 'one two three four five six seven eight nine ten eleven twelve thirteen';
   text.replace(
      '(\w+) ',
      '[$1]-'
   )
%]
-- expect --
[one]-[two]-[three]-[four]-[five]-[six]-[seven]-[eight]-[nine]-[ten]-[eleven]-[twelve]-thirteen

-- test one backref --
[% var = 'foo'; var.replace('f(o+)$', 'b$1') %]
-- expect --
boo

-- test three backrefs --
[% var = 'foo|bar/baz'; var.replace('(fo+)\|(bar)(.*)$', '[ $1, $2, $3 ]') %]
-- expect --
[ foo, bar, /baz ]


#------------------------------------------------------------------------
# tests based on Sergey's test script: http://martynoff.info/tt2/
#------------------------------------------------------------------------

-- test simple replace --
[% text = 'foo bar';
   text.replace('foo', 'bar')
%]
-- expect --
bar bar


-- test complex replace --
[% text = 'foo bar';
   text.replace('(f)(o+)', '$2$1')
%]
-- expect --
oof bar

-- test optional replace --
[% text = 'foo bar foo';
   text.replace('(?i)FOO', 'zoo')
%]
-- expect --
zoo bar zoo


#------------------------------------------------------------------------
# references to $n vars that don't exists are ignored
#------------------------------------------------------------------------

-- test invalid reference --
[% text = 'foo bar';
   text.replace('(f)(o+)', '$20$1')
%]
-- expect --
f bar

-- test another invalid reference --
[% text = 'foo bar';
   text.replace('(f)(o+)', '$2$10')
%]
-- expect --
oo bar

-- test multi reference madness --
[% text = 'foo fgoo foooo bar';
   text.replace('((?:f([^o]*)(o+)\s)+)', '1=$1;2=$2;3=$3;')
%]
-- expect --
1=foo fgoo foooo ;2=;3=oooo;bar


#------------------------------------------------------------------------
# $n in source string should not be interpolated
#------------------------------------------------------------------------

-- test non interpolation --
[% text = 'foo $1 bar';
   text.replace('(foo)(.*)(bar)', '$1$2$3')
%]
-- expect --
foo $1 bar

-- test more non interpolation --
[% text = 'foo $1 bar';
   text.replace('(foo)(.*)(bar)', '$3$2$1')
%]
-- expect --
bar $1 foo

-- test even more non interpolation --
[% text = 'foo $200bar foobar';
   text.replace('(f)(o+)', 'zoo')
%]
-- expect --
zoo $200bar zoobar


#------------------------------------------------------------------------
# escaped \$ in replacement string
#------------------------------------------------------------------------

-- test escaped dollar --
[% text = 'foo bar';
   text.replace('(f)(o+)', '\\$2$1')
%]
-- expect --
$2f bar


-- test escaped backslash --
[% text = 'foo bar';
   text.replace('(f)(o+)', 'x$1\\\\y$2'); # this is 'x$1\\y$2'
%]
-- expect --
xf\yoo bar

-- test backslash again --
[% text = 'foo bar';
   text.replace('(f)(o+)', '$2\\\\$1');   # this is '$2\\$1'
%]
-- expect --
oo\f bar

-- test escape all over --
[% text = 'foo bar';
   text.replace('(f)(o+)', '$2\\\\\\$1'); # this is '$2\\\$')
%]
-- expect --
oo\$1 bar


-- test exclamation --
[% text = 'foo bar foobar';
   text.replace('(o)|([ar])', '$2!')
%]
-- expect --
f!! ba!r! f!!ba!r!


