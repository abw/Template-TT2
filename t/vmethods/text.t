#============================================================= -*-perl-*-
#
# t/vmethods/text.t
#
# Testing scalar (text) virtual variable methods.
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
    lib         => '../../lib',
    Filesystem  => 'Bin Dir';

use Template::TT2::Test
    tests       => 52,
    debug       => 'Template::TT2::VMethods',
    args        => \@ARGV;

use Template::TT2::Stash;

# define a new text method by direct monkey patching
$Template::TT2::Stash::SCALAR_OPS->{ commify } = \&commas;

# define vmethods using define_vmethod() interface.
my $tt = Template::TT2->new;

$tt->context->define_vmethod(
    item => commas => \&commas
);

# 'scalar' and 'text' are aliases for 'item'
$tt->context->define_vmethod(
    scalar => commas2 => \&commas
);
$tt->context->define_vmethod(
    text => commas3 => \&commas
);


sub commas {
    local $_ = shift;
    my $c = shift || ",";
    my $n = int(shift || 3);
    return $_ if $n<1;
    1 while s/^([-+]?\d+)(\d{$n})/$1$c$2/;
    return $_;
}

my $vars = {
    undef    => undef,
    zero     => 0,
    one      => 1,
    animal   => 'cat',
    string   => 'The cat sat on the mat',
    spaced   => '  The dog sat on the log',
    word     => 'bird',                       # The bird is the word
    WORD     => 'BIRD',
    the_bird => "\n  The  bird\n  is  the  word  \n  ",
    quotable => "Tim O'Reilly said \"Oh really?\"",
};

test_expect( vars => $vars );

__DATA__

#------------------------------------------------------------------------
# defined
#------------------------------------------------------------------------

-- test missing variable is undefined --
[% notdef.defined ? 'def' : 'undef' %]
-- expect --
undef

-- test explicitly undefined variable is undefined --
[% undef.defined ? 'def' : 'undef' %]
-- expect --
undef

-- test zero is defined--
[% zero.defined ? 'def' : 'undef' %]
-- expect --
def

-- test one is defined --
[% one; one.defined ? 'def' : 'undef' %]
-- expect --
1def

-- test text.length --
[% string.length %]
-- expect --
22

-- test text.sort.join --
[% string.sort.join %]
-- expect --
The cat sat on the mat

-- test text.split.join --
[% string.split.join('_') %]
-- expect --
The_cat_sat_on_the_mat

-- test text.split.join with args --
[% string.split(' ', 3).join('_') %]
-- expect --
The_cat_sat on the mat

-- test more splitting and joining --
[% spaced.split.join('_') %]
-- expect --
The_dog_sat_on_the_log

-- test even more splitting and joining --
[% spaced.split(' ').join('_') %]
-- expect --
__The_dog_sat_on_the_log

-- test text.list --
[% string.list.join %]
-- expect --
The cat sat on the mat

-- test text.hash --
[% string.hash.value %]
-- expect --
The cat sat on the mat

-- test text.size --
[% string.size %]
-- expect --
1

-- test text.upper --
[% string.upper %]
-- expect --
THE CAT SAT ON THE MAT

-- test text.lower --
[% string.lower %]
-- expect --
the cat sat on the mat

-- test text.ucfirst --
[% word.ucfirst %]
[% WORD.ucfirst %]
[% WORD.lower.ucfirst %]
-- expect --
Bird
BIRD
Bird

-- test text.lcfirst --
[% word.lcfirst %]
[% WORD.lcfirst %]
-- expect --
bird
bIRD

-- test text.trim --
>[% the_bird.trim %]<
-- expect --
>The  bird
  is  the  word<

-- test text.collapse --
>[% the_bird.collapse %]<
-- expect --
>The bird is the word<

-- test --
-- name text.squote --
[% quotable %]
[% quotable.squote %]
-- expect --
Tim O'Reilly said "Oh really?"
Tim O\'Reilly said "Oh really?"

-- test --
-- name text.dquote --
[% quotable %]
[% quotable.dquote %]
-- expect --
Tim O'Reilly said "Oh really?"
Tim O'Reilly said \"Oh really?\"

-- test text.repeat --
[% animal.repeat(3) %]
-- expect --
catcatcat

-- test text.search at end --
[% animal.search('at$') ? "found 'at\$'" : "didn't find 'at\$'" %]
-- expect --
found 'at$'

-- test text.search at start --
[% animal.search('^at') ? "found '^at'" : "didn't find '^at'" %]
-- expect --
didn't find '^at'

-- test text.match 'an' --
[% text = 'bandanna';
   text.match('an') ? 'match' : 'no match'
%]
-- expect --
match

-- test text.match on --
[% text = 'bandanna';
   text.match('on') ? 'match' : 'no match'
%]
-- expect --
no match

-- test text.match global an --
[% text = 'bandanna';
   text.match('an', 1).size %] matches
-- expect --
2 matches

-- test text.match global an --
[% text = 'bandanna' -%]
matches are [% text.match('an+', 1).join(', ') %]
-- expect --
matches are an, ann

-- test text.match global on --
[% text = 'bandanna';
   text.match('on+', 1) ? 'match' : 'no match'
%]
-- expect --
no match

-- test text substr method --
[% text = 'Hello World' -%]
a: [% text.substr(6) %]!
b: [% text.substr(0, 5) %]!
c: [% text.substr(0, 5, 'Goodbye') %]!
d: [% text %]!
-- expect --
a: World!
b: Hello!
c: Goodbye World!
d: Hello World!

-- test another text substr method --
[% text = 'foo bar baz wiz waz woz' -%]
a: [% text.substr(4, 3) %]
b: [% text.substr(12) %]
c: [% text.substr(0, 11, 'FOO') %]
d: [% text %]
-- expect --
a: bar
b: wiz waz woz
c: FOO wiz waz woz
d: foo bar baz wiz waz woz


-- test text.remove --
[% text = 'hello world!';
   text.remove('\s+world')
%]
-- expect --
hello!



-- test chunk left --
[% string = 'TheCatSatTheMat' -%]
[% string.chunk(3).join(', ') %]
-- expect --
The, Cat, Sat, The, Mat

-- test chunk leftover --
[% string = 'TheCatSatonTheMat' -%]
[% string.chunk(3).join(', ') %]
-- expect --
The, Cat, Sat, onT, heM, at

-- test chunk right --
[% string = 'TheCatSatTheMat' -%]
[% string.chunk(-3).join(', ') %]
-- expect --
The, Cat, Sat, The, Mat

-- test chunk rightover --
[% string = 'TheCatSatonTheMat' -%]
[% string.chunk(-3).join(', ') %]
-- expect --
Th, eCa, tSa, ton, The, Mat

-- test chunk ccard  --
[% ccard_no = "1234567824683579";
   ccard_no.chunk(4).join
%]
-- expect --
1234 5678 2468 3579


-- test text.repeat --
[% string = 'foo' -%]
[% string.repeat(3) %]
-- expect --
foofoofoo

-- test search and replace --
[% string1 = 'foobarfoobarfoo'
   string2 = 'foobazfoobazfoo'
-%]
[% string1.search('bar') ? 'ok' : 'not ok' %]
[% string2.search('bar') ? 'not ok' : 'ok' %]
[% string1.replace('bar', 'baz') %]
[% string2.replace('baz', 'qux') %]
-- expect --
ok
ok
foobazfoobazfoo
fooquxfooquxfoo

-- test matching --
[% string1 = 'foobarfoobarfoo'
   string2 = 'foobazfoobazfoo'
-%]
[% string1.match('bar') ? 'ok' : 'not ok' %]
[% string2.match('bar') ? 'not ok' : 'ok' %]
-- expect --
ok
ok

-- test replacing --
[% string = 'foo     bar   ^%$ baz' -%]
[% string.replace('\W+', '_') %]
-- expect --
foo_bar_baz

-- test more replacing --
[% var = 'value99' ;
   var.replace('value', '')
%]
-- expect --
99

-- test bob --
[% bob = "0" -%]
bob: [% bob.replace('0','') %].
-- expect --
bob: .

-- test multi match --
[% string = 'The cat sat on the mat';
   match  = string.match('The (\w+) (\w+) on the (\w+)');
-%]
[% match.0 %].[% match.1 %]([% match.2 %])
-- expect --
cat.sat(mat)

-- test complex match --
[% string = 'The cat sat on the mat' -%]
[% IF (match  = string.match('The (\w+) sat on the (\w+)')) -%]
matched animal: [% match.0 %]  place: [% match.1 %]
[% ELSE -%]
no match
[% END -%]
[% IF (match  = string.match('The (\w+) shat on the (\w+)')) -%]
matched animal: [% match.0 %]  place: [% match.1 %]
[% ELSE -%]
no match
[% END -%]
-- expect --
matched animal: cat  place: mat
no match


-- test bignum commify --
[% big_num = "1234567890"; big_num.commify %]
-- expect --
1,234,567,890

-- test bignum commify with args --
[% big_num = "1234567890"; big_num.commify(":", 2) %]
-- expect --
12:34:56:78:90

-- test more commifying --
[% big_num = "1234567812345678"; big_num.commify(" ", 4) %]
-- expect --
1234 5678 1234 5678

-- test even more commifying --
[% big_num = "hello world"; big_num.commify %]
-- expect --
hello world

-- test bignum commas --
[% big_num = "1234567890"; big_num.commas %]
-- expect --
1,234,567,890

-- test bignum commas2 --
[% big_num = "1234567890"; big_num.commas2 %]
-- expect --
1,234,567,890

-- test bignum commas3 --
[% big_num = "1234567890"; big_num.commas3 %]
-- expect --
1,234,567,890

