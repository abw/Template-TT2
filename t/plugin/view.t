#============================================================= -*-perl-*-
#
# t/plugin/view.t
#
# Tests the 'View' plugin.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2000,2008 Andy Wardley. All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Template::TT2::Test
    tests => 33,
    debug => 'Template::TT2::View Template::TT2::Plugin::View',
    args  => \@ARGV;


#-----------------------------------------------------------------------
# define a couple of classes for testing
#-----------------------------------------------------------------------

package Foo;

sub new {
    my $class = shift;
    bless { @_ }, $class;
}

sub present {
    my $self = shift;
    return '{ ' . join(', ', map { "$_ => $self->{ $_ }" } 
		       sort keys %$self) . ' }';
}

sub reverse {
    my $self = shift;
    return '{ ' . join(', ', map { "$_ => $self->{ $_ }" } 
		       reverse sort keys %$self) . ' }';
}


package Blessed::List;

sub as_list {
    my $self = shift;
    return @$self;
}


#-----------------------------------------------------------------------
# Go Nigel, go!
#-----------------------------------------------------------------------

package main;


my $vars = {
    foo => Foo->new( pi => 3.14, e => 2.718 ),
    blessed_list => bless([ "Hello", "World" ], 'Blessed::List'),
};

test_expect( vars => $vars );

__DATA__

-- test View --
[% USE View -%]
[[% View.prefix %]]
-- expect --
[]

-- test View with prefix --
[% USE View prefix='x' -%]
[[% View.prefix %]]
-- expect --
[x]

-- test View alias --
[% USE v = View -%]
[[% v.prefix %]]
-- expect --
[]

-- test View alias with prefix --
[% USE v = View prefix='y'-%]
[[% v.prefix %]]
-- expect --
[y]

-- test map default --
[% USE v = View( map => { default="any" } ) -%]
[[% v.map.default %]]
-- expect --
[any]

-- test prefix/suffix --
[% USE view( prefix=> 'foo/', suffix => '.tt2') -%]
[[% view.prefix %]bar[% view.suffix %]]
[[% view.template_name('baz') %]]
-- expect --
[foo/bar.tt2]
[foo/baz.tt2]

-- test view.print text --
[% USE view -%]
[% view.print('Hello World') %]
[% BLOCK text %]TEXT: [% item %][% END -%]
-- expect --
TEXT: Hello World

-- test view.print hash --
[% USE view -%]
[% view.print( { foo => 'bar' } ) %]
[% BLOCK hash %]HASH: {
[% FOREACH key = item.keys.sort -%]
   [% key %] => [% item.$key %]
[%- END %]
}
[% END -%]
-- expect --
HASH: {
   foo => bar
}

-- test view.clone --
[% USE view -%]
[% view = view.clone( prefix => 'my_' ) -%]
[% view.view('hash', { bar => 'baz' }) %]
[% BLOCK my_hash %]HASH: {
[% FOREACH key = item.keys.sort -%]
   [% key %] => [% item.$key %]
[%- END %]
}
[% END -%]
-- expect --
HASH: {
   bar => baz
}


-- test view prefix param --
[% USE view(prefix='my_') -%]
[% view.print( foo => 'wiz', bar => 'waz' ) %]
[% BLOCK my_hash %]KEYS: [% item.keys.sort.join(', ') %][% END %]

-- expect --
KEYS: bar, foo

-- test view.print(view) --
[% USE view -%]
[% view.print( view ) %]
[% BLOCK Template_TT2_View %]Printing a Template::TT2::View object[% END -%]
-- expect --
Printing a Template::TT2::View object

-- test view.print(view) with prefix --
[% USE view(prefix='my_') -%]
[% view.print( view ) %]
[% view.print( view, prefix='your_' ) %]
[% BLOCK my_Template_TT2_View %]Printing my Template::TT2::View object[% END -%]
[% BLOCK your_Template_TT2_View %]Printing your Template::TT2::View object[% END -%]
-- expect --
Printing my Template::TT2::View object
Printing your Template::TT2::View object

-- test notfound option --
[% USE view(prefix='my_', notfound='any' ) -%]
[% view.print( view ) %]
[% view.print( view, prefix='your_' ) %]
[% BLOCK my_any %]Printing any of my objects[% END -%]
[% BLOCK your_any %]Printing any of your objects[% END -%]
-- expect --
Printing any of my objects
Printing any of your objects

-- test prefix/map options catchall --
[% USE view(prefix => 'my_', map => { default => 'catchall' } ) -%]
[% view.print( view ) %]
[% view.print( view, default="catchsome" ) %]
[% BLOCK my_catchall %]Catching all defaults[% END -%]
[% BLOCK my_catchsome %]Catching some defaults[% END -%]
-- expect --
Catching all defaults
Catching some defaults

-- test prefix/map options catchnone --
[% USE view(prefix => 'my_', map => { default => 'catchnone' } ) -%]
[% view.default %]
[% view.default = 'catchall' -%]
[% view.default %]
[% view.print( view ) %]
[% view.print( view, default="catchsome" ) %]
[% BLOCK my_catchall %]Catching all defaults[% END -%]
[% BLOCK my_catchsome %]Catching some defaults[% END -%]
-- expect --
catchnone
catchall
Catching all defaults
Catching some defaults

-- test lost --
[% USE view(prefix='my_', default='catchall' notfound='lost') -%]
[% view.print( view ) %]
[% BLOCK my_lost %]Something has been found[% END -%]
-- expect --
Something has been found

-- test heroes --
[% USE view -%]
[% TRY ;
     view.print( view ) ;
#   CATCH view ;
   CATCH;
     "[$error.type] $error.info" ;
   END
%]
-- expect --
[view] file error - Template_TT2_View: not found

-- test Bagpuss wept --
[% USE view -%]
[% view.print( foo ) %]
-- expect --
{ e => 2.718, pi => 3.14 }

-- test Oliver Postgate 1925-2008 RIP --
[% USE view -%]
[% view.print( foo, method => 'reverse' ) %]
-- expect --
{ pi => 3.14, e => 2.718 }

-- test let's get naked! --
[% USE view(prefix='my_', include_naked=0, view_naked=1) -%]
[% BLOCK my_foo; "Foo: $item"; END -%]
[[% view.view_foo(20) %]]
[[% view.foo(30) %]]
-- expect --
[Foo: 20]
[Foo: 30]

-- test view naked --
[% USE view(prefix='my_', include_naked=0, view_naked=0) -%]
[% BLOCK my_foo; "Foo: $item"; END -%]
[[% view.view_foo(20) %]]
[% TRY ;
     view.foo(30) ;
   CATCH ;
     error.info ;
   END
%]
-- expect --
[Foo: 20]
no such view member: foo

-- test my hash --
[% USE view(map => { HASH => 'my_hash', ARRAY => 'your_list' }) -%]
[% BLOCK text %]TEXT: [% item %][% END -%]
[% BLOCK my_hash %]HASH: [% item.keys.sort.join(', ') %][% END -%]
[% BLOCK your_list %]LIST: [% item.join(', ') %][% END -%]
[% view.print("some text") %]
[% view.print({ alpha => 'a', bravo => 'b' }) %]
[% view.print([ 'charlie', 'delta' ]) %]
-- expect --
TEXT: some text
HASH: alpha, bravo
LIST: charlie, delta

-- test your bud --
[% USE view(item => 'thing',
	    map => { HASH => 'my_hash', ARRAY => 'your_list' }) -%]
[% BLOCK text %]TEXT: [% thing %][% END -%]
[% BLOCK my_hash %]HASH: [% thing.keys.sort.join(', ') %][% END -%]
[% BLOCK your_list %]LIST: [% thing.join(', ') %][% END -%]
[% view.print("some text") %]
[% view.print({ alpha => 'a', bravo => 'b' }) %]
[% view.print([ 'charlie', 'delta' ]) %]
-- expect --
TEXT: some text
HASH: alpha, bravo
LIST: charlie, delta

-- test share a bowl --
[% USE view -%]
[% view.print('Hello World') %]
[% view1 = view.clone( prefix='my_') -%]
[% view1.print('Hello World') %]
[% view2 = view1.clone( prefix='dud_', notfound='no_text' ) -%]
[% view2.print('Hello World') %]
[% BLOCK text %]TEXT: [% item %][% END -%]
[% BLOCK my_text %]MY TEXT: [% item %][% END -%]
[% BLOCK dud_no_text %]NO TEXT: [% item %][% END -%]
-- expect --
TEXT: Hello World
MY TEXT: Hello World
NO TEXT: Hello World

-- test take a hit --
[% USE view( prefix = 'base_', default => 'any' ) -%]
[% view1 = view.clone( prefix => 'one_') -%]
[% view2 = view.clone( prefix => 'two_') -%]
[% view.default %] / [% view.map.default %]
[% view1.default = 'anyone' -%]
[% view1.default %] / [% view1.map.default %]
[% view2.map.default = 'anytwo' -%]
[% view2.default %] / [% view2.map.default %]
[% view.print("Hello World") %] / [% view.print(blessed_list) %]
[% view1.print("Hello World") %] / [% view1.print(blessed_list) %]
[% view2.print("Hello World") %] / [% view2.print(blessed_list) %]
[% BLOCK base_text %]ANY TEXT: [% item %][% END -%]
[% BLOCK one_text %]ONE TEXT: [% item %][% END -%]
[% BLOCK two_text %]TWO TEXT: [% item %][% END -%]
[% BLOCK base_any %]BASE ANY: [% item.as_list.join(', ') %][% END -%]
[% BLOCK one_anyone %]ONE ANY: [% item.as_list.join(', ') %][% END -%]
[% BLOCK two_anytwo %]TWO ANY: [% item.as_list.join(', ') %][% END -%]
-- expect --
any / any
anyone / anyone
anytwo / anytwo
ANY TEXT: Hello World / BASE ANY: Hello, World
ONE TEXT: Hello World / ONE ANY: Hello, World
TWO TEXT: Hello World / TWO ANY: Hello, World

-- test chill --
[% USE view( prefix => 'my_', item => 'thing' ) -%]
[% view.view('thingy', [ 'foo', 'bar'] ) %]
[% BLOCK my_thingy %]thingy: [ [% thing.join(', ') %] ][%END %]
-- expect --
thingy: [ foo, bar ]

-- test introspection --
[% USE view -%]
[% view.map.${'Template::TT2::View'} = 'myview' -%]
[% view.print(view) %]
[% BLOCK myview %]MYVIEW[% END%]
-- expect --
MYVIEW

-- test reflection --
[% USE view -%]
[% view.include('greeting', msg => 'Hello World!') %]
[% BLOCK greeting %]msg: [% msg %][% END -%]
-- expect --
msg: Hello World!

-- test like a black mirror --
[% USE view( prefix="my_" )-%]
[% view.include('greeting', msg => 'Hello World!') %]
[% BLOCK my_greeting %]msg: [% msg %][% END -%]
-- expect --
msg: Hello World!

-- test How much more black could this be? --
[% USE view( prefix="my_" )-%]
[% view.include_greeting( msg => 'Hello World!') %]
[% BLOCK my_greeting %]msg: [% msg %][% END -%]
-- expect --
msg: Hello World!

-- test The answer is none --
[% USE view( prefix="my_" )-%]
[% INCLUDE $view.template('greeting')
   msg = 'Hello World!' %]
[% BLOCK my_greeting %]msg: [% msg %][% END -%]
-- expect --
msg: Hello World!

-- test None more black --
[% USE view( title="My View" )-%]
[% view.title %]
-- expect --
My View

-- test chartreuse is the new black --
[% USE view( title="My View" )-%]
[% newview = view.clone( col = 'Chartreuse') -%]
[% newerview = newview.clone( title => 'New Title' ) -%]
[% view.title %]
[% newview.title %]
[% newview.col %]
[% newerview.title %]
[% newerview.col %]
-- expect --
My View
My View
Chartreuse
New Title
Chartreuse

