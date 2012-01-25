#============================================================= -*-perl-*-
#
# t/stash/stash.t
#
# Test the Template::TT2::Stash module.
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
    lib => [
        '../lib',
        '../../lib',
        '../../blib',
        '../../blib/arch',
    ];

use Template::TT2::Constants qw( :status :debug );
use Template::TT2::Test
    tests => 62,
    debug => 'Template::TT2::Stash',
    args  => \@ARGV;

use Template::TT2::Stash;
our $STASH = 'Template::TT2::Stash';
    
# test modules defined in t/lib
use NumberLike;
use GetNumberLike;
use CmpOverload;
use TextObject;
use ListObject;
use HashObject;


# define some data
my $count = 1;
my $data  = {
    text     => 'Hello World',
    number   =>  42,
    negative => -42,
    hash     => {
        text => 'Hash text',
        more => 'More text',
        hash => {
            foo => 'bar',
        },
        list => [
            1.618, 2.718, 3.142, 
        ],
        code => sub {
            my $a = shift || 10;
            my $b = shift || 20;
            return $a + $b;
        },
    },
    list     => [
        'List text',
        { 
            phi => 1.618,
            e   => 2.718,
            pi  => 3.142
        },
        sub {
            my $a = shift || 30;
            my $b = shift || 20;
            return $a - $b;
        },
    ],
    primes   => [2,3,5,7,11,13,17,19],
    counter  => sub { $count++ },
    subhash  => sub {
        return {
            x => 10,
            y => 20,
        };
    },
    hello    => sub {
        my $name = shift || 'World';
        return "Hello $name";
    },
    textobj  => TextObject->new('a text object'),
    hashobj  => HashObject->new( name => 'Badger' ),
    listobj  => ListObject->new(10, 20, 30),
    
    object      => bless({ name => 'an object' }, 'AnObject'),
    objectifier => sub { bless({ name => 'another object' }, 'AnObject') },
};


my $stash = $STASH->new($data);


#-----------------------------------------------------------------------
# data tests
#-----------------------------------------------------------------------

# get scalar data types
is( $stash->get('text'), 'Hello World', 'got text' );
is( $stash->get('number'), 42, 'got number' );
is( $stash->get('negative'), -42, 'got negative number' );

# also try canonical form
is( $stash->get(['text']), 'Hello World', 'got text from list ref with no args' );
is( $stash->get([text => 0]), 'Hello World', 'got text from list ref with zero args' );
is( $stash->get([text => undef]), 'Hello World', 'got text from list ref with undef args' );
is( $stash->get([text => [1,2,3]]), 'Hello World', 'got text from list ref with three args' );

# get hash elements
is( $stash->get('hash.text'), 'Hash text', 'got hash text' );
is( $stash->get('hash.hash.foo'), 'bar', 'got hash hash text' );
is( $stash->get('hash.list.0'), 1.618, 'got hash list number' );
is( $stash->get('hash.list.-1'), 3.142, 'got hash list number from end' );
is( $stash->get('hash.code'), 30, 'got hash code' );

# also try canonical form
is( $stash->get([hash => 0, text => 0]), 'Hash text', 'got hash text from list ref' );
is( $stash->get([hash => 0, hash => 0, 'foo']), 'bar', 'got hash hash text from list ref' );

is( $stash->get([hash => 0, list => 0, 0]), 1.618, 'got hash list number from list ref' );
is( $stash->get([hash => 0, list => 0, -1, 0]), 3.142, 'got hash list number from end from list ref' );
is( $stash->get([hash => 0, code => 0]), 30, 'got hash code from list ref' );
is( $stash->get([hash => 0, code => [42, 378]]), 420, 'got hash code with args from list ref' );
is( join('. ', @{ $stash->get([hash => 0, ['text', 'more']]) }), 
    'Hash text. More text', 'got hash slice' );

# get list elements
is( $stash->get('list.0'), 'List text', 'got list text' );
is( $stash->get('list.1.phi'), 1.618, 'got list hash item' );
is( $stash->get('list.-2.e'), 2.718, 'got list hash item from end' );
is( $stash->get('list.2'), 10, 'got list code' );
is( $stash->get('list.-1'), 10, 'got list code from end' );

# also try canonical form
is( $stash->get([list => 0, 0]), 'List text', 'got list text from list ref' );
is( $stash->get([list => 0, 1 => 0, phi => 0]), 1.618, 'got list hash item from list ref' );
is( $stash->get([list => 0, -2 => 0, e => 0]), 2.718, 'got list hash item from end from list ref' );
is( $stash->get([list => 0, 2 => 0]), 10, 'got list code from list ref' );
is( $stash->get([list => 0, 2 => [100,58]]), 42, 'got list code with args from list ref' );
is( join(', ', @{ $stash->get([primes => 0, [3, 2, 1, 0]]) }), 
    '7, 5, 3, 2', 'got list slice' );

# call sub
is( $stash->get('counter'), 1, 'got counter sub' );
is( $stash->get(['counter']), 2, 'got counter sub from list ref' );

# call sub returning hash ref, then access item in hash
is( $stash->get('subhash.x'), 10, 'got sub hash x' );

# call sub with args
is( $stash->get('hello'), 'Hello World', 'called sub without args' );
is( $stash->get([ hello => ['Badger']]), 'Hello Badger', 'called sub with args' );

# call text object method
is( $stash->get('textobj.text'), 'a text object', 'called text object method' );
is( $stash->get([ textobj => 0, text => 0 ]), 'a text object', 'called text object method from list ref' );

# call hash object method
is( $stash->get('hashobj.hello'), 'Hello Badger', 'called hash object method' );
is( $stash->get([ hashobj => 0, hello => 0 ]), 'Hello Badger', 'called hash object method from list ref' );
is( $stash->get([ hashobj => 0, hello => ['Ferret'] ]), 'Hello Ferret', 'called hash object method with args' );
is( $stash->get('hashobj.name'), 'Badger', 'exposed hash object element' );
is( $stash->get([ hashobj => 0, name => 0 ]), 'Badger', 'exposed hash object element from list ref' );

# call list object method
is( $stash->get('listobj.zero'), 10, 'called list object method' );
is( $stash->get([ listobj => 0, one => 0 ]), 20, 'called list object method from list ref' );
is( $stash->get([ listobj => 0, two => [40] ]), 40, 'called list object method with args' );
is( $stash->get('listobj.two'), 40, 'called list object method for updated value' );
is( $stash->get('listobj.2'), 40, 'exposed list object element' );
is( $stash->get([ listobj => 0, 1 => 0 ]), 20, 'exposed list object element from list ref' );



#-----------------------------------------------------------------------
# vmethods
#-----------------------------------------------------------------------

# text vmethods
is( $stash->get('text.length'), 11, 'called text.length' );
is( $stash->get([text => 0, length => 0]), 11, 'called text.length from list ref' );
is( $stash->get([text => 0, repeat => [3]]), 
    'Hello WorldHello WorldHello World', 
    'called text.repeat with args' );

# upgrade object to scalar vmethod
is( $stash->get('textobj.length'), 13, 'called textobj.length' );

# upgrade to list method
is( $stash->get('text.join'), 'Hello World', 'called text.join' );
is( $stash->get('textobj.join'), 'a text object', 'called textobj.join' );

# list vmethods
is( $stash->get('list.size'), 3, 'called list.size' );
is( $stash->get([list => 0, size => 0]), 3, 'called list.size from list ref' );

# hash vmethods
is( $stash->get('hash.keys.sort.join'), 'code hash list more text', 'called hash.keys.sort.join' );
is( $stash->get([ hash => 0, keys => 0, sort => 0, join => [', ']]), 'code, hash, list, more, text', 
    'called hash.keys.sort.join with args' );
    


#-----------------------------------------------------------------------
# clone
#-----------------------------------------------------------------------

my $clone = $stash->clone( number => 420, answer => 42 );
is( $clone->get('number'), 420, 'got new number from clone' );
is( $clone->get('answer'), 42, 'got answer from clone' );
is( $stash->get('number'), 42, 'got unchanged number from original stash' );
is( $stash->get('answer'), '', 'got no answer from original stash' );


#-----------------------------------------------------------------------
# set
#-----------------------------------------------------------------------

#is( $stash->set('x', 10), 10, 'set x to 10' );

__END__


TODO:
  assignment
  lvalue hash creation in dotop
  vmethods
  exposing objects to vmethods
  scalar list vmethods
  
__END__
        
    
    foo => 10,
    bar => {
        baz => 20,
    },
    hashobj => HashObject->new({ planet => 'World' }),
    listobj => ListObject->new([10, 20, 30], 'ListObject'),
    num     => NumberLike->new("TESTING"),
    getnum  => GetNumberLike->new,
    cmp_ol  => CmpOverload->new(),
    clean   => sub {
        my $error = shift;
        $error =~ s/(\s*\(.*?\))?\s+at.*$//;
        return $error;
    },
};


my $ttlist = [
    'default' => Template->new(),
    'warn'    => Template->new(DEBUG => DEBUG_UNDEF, DEBUG_FORMAT => ''),
];

test_expect(\*DATA, $ttlist, $data);

__DATA__
-- test --
a: [% a %]
-- expect --
a: 

-- test --
-- use warn --
[% TRY; a; CATCH; "ERROR: $error"; END %]
-- expect --
ERROR: undef error - a is undefined


-- test --
[% myitem = 'foo' -%]
[% myitem.hash.value %]
-- expect --
foo

-- test --
[% myitem = 'foo'
   mylist = [ 'one', myitem, 'three' ]
   global.mylist = mylist
-%]
[% mylist.item %]
0: [% mylist.item(0) %]
1: [% mylist.item(1) %]
2: [% mylist.item(2) %]
-- expect --
one
0: one
1: foo
2: three

-- test --
[% "* $item\n" FOREACH item = global.mylist -%]
[% "+ $item\n" FOREACH item = global.mylist.list -%]
-- expect --
* one
* foo
* three
+ one
+ foo
+ three

-- test --
[% global.mylist.push('bar');
   "* $item.key => $item.value\n" FOREACH item = global.mylist.hash -%]
-- expect --
* one => foo
* three => bar

-- test --
[% obj.name.list.first %]
-- expect --
an object

-- test --
[% obj.items.first %]
-- expect --
name

-- test --
[% obj.items.1 %]
-- expect --
an object

-- test --
[% bop.first.name %]
-- expect --
an object

-- test --
[% listobj.0 %] / [% listobj.first %]
-- expect --
10 / 10

-- test --
[% listobj.2 %] / [% listobj.last %]
-- expect --
30 / 30

-- test --
[% listobj.join(', ') %]
-- expect --
10, 20, 30

-- test --
=[% size %]=
-- expect --
==

-- test --
[% foo = { "one" = "bar" "" = "empty" } -%]
foo is { [% FOREACH k IN foo.keys.sort %]"[% k %]" = "[% foo.$k %]" [% END %]}
setting foo.one to baz
[% fookey = "one" foo.$fookey = "baz" -%]
foo is { [% FOREACH k IN foo.keys.sort %]"[% k %]" = "[% foo.$k %]" [% END %]}
setting foo."" to quux
[% fookey = "" foo.$fookey = "full" -%]
foo is { [% FOREACH k IN foo.keys.sort %]"[% k %]" = "[% foo.$k %]" [% END %]}
--expect --
foo is { "" = "empty" "one" = "bar" }
setting foo.one to baz
foo is { "" = "empty" "one" = "baz" }
setting foo."" to quux
foo is { "" = "full" "one" = "baz" }


# test Dave Howorth's patch (v2.15) which makes the stash more strict
# about what it considers to be a missing method error

-- test --
[% hashobj.hello %]
-- expect --
Hello World

-- test --
[% TRY; hashobj.goodbye; CATCH; "ERROR: "; clean(error); END %]
-- expect --
ERROR: undef error - Can't locate object method "no_such_method" via package "HashObject"


#-----------------------------------------------------------------------
# try and pin down the numification bug
#-----------------------------------------------------------------------

-- test --
[% FOREACH item IN num.things -%]
* [% item %]
[% END -%]
-- expect --
* foo
* bar
* baz

-- test --
[% num %]
-- expect --
PASS: stringified Numbersome

-- test --
[% getnum.num %]
-- expect --
PASS: stringified from GetNumbersome


# Exercise the object with the funky overloaded comparison

-- test --
[% cmp_ol.hello %]
-- expect --
Hello
