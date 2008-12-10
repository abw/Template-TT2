#============================================================= -*-perl-*-
#
# t/langauge/view.t
#
# Tests the 'VIEW' directive.
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
use lib '/home/abw/projects/badger/lib';
use lib qw( ./lib ../lib ../../lib );
use constant 
    ENGINE => 'Template::TT2';
use Template::TT2::Test
    tests => 24,
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


#------------------------------------------------------------------------
# check we can create a view via the context view() method
#------------------------------------------------------------------------

package main;

my $vars = {
    foo => Foo->new( pi => 3.14, e => 2.718 ),
    blessed_list => bless([ "Hello", "World" ], 'Blessed::List'),
};

my $template = ENGINE->new();
my $context  = $template->context();
my $view     = $context->view( );
ok( $view, 'created view' );

$view = $context->view( prefix => 'my' );
ok( $view, 'created view with prefix' );
is( $view->prefix(), 'my', 'got view prefix' );


#-----------------------------------------------------------------------
# run tests in DATA section
#-----------------------------------------------------------------------

test_expect( vars => $vars );

__DATA__

-- test VIEW prefix argument --
[% VIEW fred prefix='blat_' %]
This is the view
[% END -%]
[% BLOCK blat_foo; 'This is blat_foo'; END -%]
[% fred.view_foo %]
-- expect --
This is blat_foo

-- test view.prefix set --
[% VIEW fred %]
This is the view
[% view.prefix = 'blat_' %]
[% END -%]
[% BLOCK blat_foo; 'This is blat_foo'; END -%]
[% fred.view_foo %]
-- expect --
This is blat_foo

-- test view alias --
[% VIEW fred %]
This is the view
[% view.prefix = 'blat_' %]
[% view.thingy = 'bloop' %]
[% fred.name = 'Freddy' %]
[% END -%]
[% fred.prefix %]
[% fred.thingy %]
[% fred.name %]
-- expect --
blat_
bloop
Freddy


-- test view sealed --
[% VIEW fred prefix='blat_'; view.name='Fred'; END -%]
[% fred.prefix %]
[% fred.name %]
[% TRY;
     fred.prefix = 'nonblat_';
   CATCH;
     error;
   END
%]
[% TRY;
     fred.name = 'Derek';
   CATCH;
     error;
   END
%]
-- expect --
blat_
Fred
view error - cannot update config item in sealed view: prefix
view error - cannot update item in sealed view: name

-- test notfound --
[% VIEW foo prefix='blat_' default="default" notfound="notfound"
     title="fred" age=23 height=1.82 %]
[% view.other = 'another' %]
[% END -%]
[% BLOCK blat_hash -%]
[% FOREACH key = item.keys.sort -%]
   [% key %] => [% item.$key %]
[% END -%]
[% END -%]
[% foo.print(foo.data) %]
-- expect --
   age => 23
   height => 1.82
   other => another
   title => fred

-- test hello --
[% VIEW foo %]
[% BLOCK hello -%]
Hello World!
[% END %]
[% BLOCK goodbye -%]
Goodbye World!
[% END %]
[% END -%]
[% TRY; INCLUDE foo; CATCH; error; END %]
[% foo.include_hello %]
-- expect --
file error - foo: not found
Hello World!

-- test title --
[% title = "Previous Title" -%]
[% VIEW foo 
     include_naked = 1
     title = title or 'Default Title'
     copy  = 'me, now'
-%]

[% view.bgcol = '#ffffff' -%]

[% BLOCK header -%]
Header:  bgcol: [% view.bgcol %]
         title: [% title %]
    view.title: [% view.title %]
[%- END %]

[% BLOCK footer -%]
&copy; Copyright [% view.copy %]
[%- END %]

[% END -%]
[% title = 'New Title' -%]
[% foo.header %]
[% foo.header(bgcol='#dead' title="Title Parameter") %]
[% foo.footer %]
[% foo.footer(copy="you, then") %]

-- expect --
Header:  bgcol: #ffffff
         title: New Title
    view.title: Previous Title
Header:  bgcol: #ffffff
         title: Title Parameter
    view.title: Previous Title
&copy; Copyright me, now
&copy; Copyright me, now


-- test attributes --
[% VIEW foo 
    title  = 'My View' 
    author = 'Andy Wardley'
    bgcol  = bgcol or '#ffffff'
-%]
[% view.arg1 = 'argument #1' -%]
[% view.data.arg2 = 'argument #2' -%]
[% END -%]
 [% foo.title %]
 [% foo.author %]
 [% foo.bgcol %]
 [% foo.arg1 %]
 [% foo.arg2 %]
[% bar = foo.clone( title='New View', arg1='New Arg1' ) %]cloned!
 [% bar.title %]
 [% bar.author %]
 [% bar.bgcol %]
 [% bar.arg1 %]
 [% bar.arg2 %]
originals:
 [% foo.title %]
 [% foo.arg1 %]


-- expect --
 My View
 Andy Wardley
 #ffffff
 argument #1
 argument #2
cloned!
 New View
 Andy Wardley
 #ffffff
 New Arg1
 argument #2
originals:
 My View
 argument #1


-- test header block --
[% VIEW basic title = "My Web Site" %]
  [% BLOCK header -%]
  This is the basic header: [% title or view.title %]
  [%- END -%]
[% END -%]

[%- VIEW fancy 
      title = "<fancy>$basic.title</fancy>"
      basic = basic 
%]
  [% BLOCK header ; view.basic.header(title = title or view.title) %]
  Fancy new part of header
  [%- END %]
[% END -%]
===
[% basic.header %]
[% basic.header( title = "New Title" ) %]
===
[% fancy.header %]
[% fancy.header( title = "Fancy Title" ) %]
-- expect --
===
  This is the basic header: My Web Site
  This is the basic header: New Title
===
  This is the basic header: <fancy>My Web Site</fancy>
  Fancy new part of header
  This is the basic header: Fancy Title
  Fancy new part of header

-- test lost --
[% VIEW baz  notfound='lost' %]
[% BLOCK lost; 'lost, not found'; END %]
[% END -%]
[% baz.any %]
-- expect --
lost, not found

-- test outer --
[% VIEW woz  prefix='outer_' %]
[% BLOCK wiz; 'The inner wiz'; END %]
[% END -%]
[% BLOCK outer_waz; 'The outer waz'; END -%]
[% woz.wiz %]
[% woz.waz %]
-- expect --
The inner wiz
The outer waz

-- test file/directory --
[% VIEW foo %]

   [% BLOCK file -%]
      File: [% item.name %]
   [%- END -%]

   [% BLOCK directory -%]
      Dir: [% item.name %]
   [%- END %]

[% END -%]
[% foo.view_file({ name => 'some_file' }) %]
[% foo.include_file(item => { name => 'some_file' }) %]
[% foo.view('directory', { name => 'some_dir' }) %]
-- expect --
      File: some_file
      File: some_file
      Dir: some_dir

-- test parent/super --
[% BLOCK parent -%]
This is the base block
[%- END -%]
[% VIEW super %]
   [%- BLOCK parent -%]
   [%- INCLUDE parent | replace('base', 'super') -%]
   [%- END -%]
[% END -%]
base: [% INCLUDE parent %]
super: [% super.parent %]
-- expect --
base: This is the base block
super: This is the super block

-- test plain/fancy --
[% BLOCK foo -%]
public foo block
[%- END -%]
[% VIEW plain %]
   [% BLOCK foo -%]
<plain>[% PROCESS foo %]</plain>
   [%- END %]
[% END -%]
[% VIEW fancy %]
   [% BLOCK foo -%]
   [%- plain.foo | replace('plain', 'fancy') -%]
   [%- END %]
[% END -%]
[% plain.foo %]
[% fancy.foo %]
-- expect --
<plain>public foo block</plain>
<fancy>public foo block</fancy>

-- test blessed --
[% VIEW foo %]
[% BLOCK Blessed_List -%]
This is a list: [% item.as_list.join(', ') %]
[% END -%]
[% END -%]
[% foo.print(blessed_list) %]
-- expect --
This is a list: Hello, World

-- test value --
[% VIEW my.foo value=33; END -%]
n: [% my.foo.value %]
-- expect --
n: 33

-- test one/two --
[% VIEW parent -%]
[% BLOCK one %]This is base one[% END %]
[% BLOCK two %]This is base two[% END %]
[% END -%]

[%- VIEW child1 base=parent %]
[% BLOCK one %]This is child1 one[% END %]
[% END -%]

[%- VIEW child2 base=parent %]
[% BLOCK two %]This is child2 two[% END %]
[% END -%]

[%- VIEW child3 base=child2 %]
[% BLOCK two %]This is child3 two[% END %]
[% END -%]

[%- FOREACH child = [ child1, child2, child3 ] -%]
one: [% child.one %]
[% END -%]
[% FOREACH child = [ child1, child2, child3 ] -%]
two: [% child.two %]
[% END %]

-- expect --
one: This is child1 one
one: This is base one
one: This is base one
two: This is base two
two: This is child2 two
two: This is child3 two

-- test prefix/value --
[% VIEW my.view.default
        prefix = 'view/default/'
        value  = 3.14;
   END
-%]
value: [% my.view.default.value %]
-- expect --
value: 3.14

-- test base views --
[% VIEW my.view.default
        prefix = 'view/default/'
        value  = 3.14;
   END;
   VIEW my.view.one
        base   = my.view.default
        prefix = 'view/one/';
   END;
   VIEW my.view.two
	base  = my.view.default
        value = 2.718;
   END;
-%]
[% BLOCK view/default/foo %]Default foo[% END -%]
[% BLOCK view/one/foo %]One foo[% END -%]
0: [% my.view.default.foo %]
1: [% my.view.one.foo %]
2: [% my.view.two.foo %]
0: [% my.view.default.value %]
1: [% my.view.one.value %]
2: [% my.view.two.value %]
-- expect --
0: Default foo
1: One foo
2: Default foo
0: 3.14
1: 3.14
2: 2.718

-- test sealed --
[% VIEW foo number = 10 sealed = 0; END -%]
a: [% foo.number %]
b: [% foo.number = 20 %]
c: [% foo.number %]
d: [% foo.number(30) %]
e: [% foo.number %]
-- expect --
a: 10
b: 
c: 20
d: 30
e: 30

-- test silent --
[% VIEW foo number = 10 silent = 1; END -%]
a: [% foo.number %]
b: [% foo.number = 20 %]
c: [% foo.number %]
d: [% foo.number(30) %]
e: [% foo.number %]
-- expect --
a: 10
b: 
c: 10
d: 10
e: 10

