#============================================================= -*-perl-*-
#
# t/modules/iterator.t
#
# Test script for Template::TT2::Iterator and 
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
    lib   => '../../lib ../../blib/lib ../../blib/arch';

use Template::TT2::Test
    tests => 30,
    debug => 'Template::TT2::Iterator',
    args  => \@ARGV;
    
use Template::TT2::Constants ':status';
use Template::TT2::Iterator;
use constant ITERATOR => 'Template::TT2::Iterator';

my $data = [ qw( foo bar baz qux wiz woz waz ) ];
my $vars = {
    data => $data,
};

my $i1 = ITERATOR->new($data);
ok( $i1->get_first() eq 'foo', 'get_first()' );
ok( $i1->get_next()  eq 'bar', 'get_next()' );
ok( $i1->get_next()  eq 'baz', 'get_next() again' );

my $rest = $i1->get_all();
ok( scalar @$rest == 4, '4 items left' );
ok( $rest->[0] eq 'qux', 'first remaining item is qux' );
ok( $rest->[3] eq 'waz', 'final remaining item is waz' );

my ($val, $err) = $i1->get_next();
ok( ! $val, 'no next value' );
is( $err, STATUS_DONE, 'status done' );

($val, $err) = $i1->get_all();
ok( ! $val, 'no all value' );
is( $err, STATUS_DONE, 'also status done' );

($val, $err) = $i1->get_first();
is( $i1->get_first(), 'foo', 'got first after reset' );
is( $i1->get_next(), 'bar', 'got next after reset' );
$rest = $i1->get_all();
ok( scalar @$rest == 5, 'got 5 more after reset' );


# get_all with a few values in the iterator
my $i2 = ITERATOR->new($data);
($rest, $err) = $i2->get_all();
is( scalar @$rest, 7, 'got seven items' );
ok( ! $err, 'i2 no error');
($val, $err) = $i2->get_all();
ok( ! $val, 'i2 no value');
is( $err, STATUS_DONE, 'i2 all done' );

# get_all with a single value.
my $i3 = ITERATOR->new(['foo']);
($rest, $err) = $i3->get_all();
is( scalar @$rest, 1, 'got one item' );
is( pop @$rest, 'foo', 'got foo' );
ok( ! $err, 'i3 no error');
($val, $err) = $i3->get_all();
ok( ! $val, 'i3 no value' );
is( $err, STATUS_DONE, 'i3 all done' );

# get_all with an empty array
my $i4 = ITERATOR->new([]);
($val, $err) = $i4->get_all();
ok( ! $val, 'i4 no value' );
is( $err, STATUS_DONE, 'i4 all done' );



test_expect(
    config => { POST_CHOMP => 1 }, 
    vars   => $vars
);

__DATA__

-- test loop over list ref --
[% items = [ 'foo' 'bar' 'baz' 'qux' ] %]
[% FOREACH i IN items %]
   * [% i +%]
[% END %]
-- expect --
   * foo
   * bar
   * baz
   * qux

-- test loop.index and loop.max --
[% items = [ 'foo' 'bar' 'baz' 'qux' ] %]
[% FOREACH i = items %]
   #[% loop.index %]/[% loop.max %] [% i +%]
[% END %]
-- expect --
   #0/3 foo
   #1/3 bar
   #2/3 baz
   #3/3 qux

-- test loop.count and loop.size --
[% items = [ 'foo' 'bar' 'baz' 'qux' ] %]
[% FOREACH i = items %]
   #[% loop.count %]/[% loop.size %] [% i +%]
[% END %]
-- expect --
   #1/4 foo
   #2/4 bar
   #3/4 baz
   #4/4 qux

-- test number as alias for count --
[% items = [ 'foo' 'bar' 'baz' 'qux' ] %]
[% FOREACH i = items %]
   #[% loop.number %]/[% loop.size %] [% i +%]
[% END %]
-- expect --
   #1/4 foo
   #2/4 bar
   #3/4 baz
   #4/4 qux

-- test loop.prev and loop.next --
[% FOREACH i = [ 'foo' 'bar' 'baz' 'qux' ] %]
[% "$loop.prev<-" IF loop.prev -%][[% i -%]][% "->$loop.next" IF loop.next +%]
[% END %]
-- expect --
[foo]->bar
foo<-[bar]->baz
bar<-[baz]->qux
baz<-[qux]


-- test even/odd/parity --
[% FOREACH item IN [1..10] -%]
* [% loop.count %] [% loop.odd %] [% loop.even %] [% loop.parity +%]
[% END -%]
-- expect --
* 1 1 0 odd
* 2 0 1 even
* 3 1 0 odd
* 4 0 1 even
* 5 1 0 odd
* 6 0 1 even
* 7 1 0 odd
* 8 0 1 even
* 9 1 0 odd
* 10 0 1 even