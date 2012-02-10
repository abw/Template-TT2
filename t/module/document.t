#============================================================= -*-perl-*-
#
# t/module/document.t
#
# Test the Template::Document module.
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
    tests => 16,
    debug => 'Template::TT2::Document',
    args  => \@ARGV;

use Template::TT2::Document;
use constant {
    ENGINE   => 'Template::TT2',
    DOCUMENT => 'Template::TT2::Document',
};


#------------------------------------------------------------------------
# define a dummy context object for runtime processing
#------------------------------------------------------------------------
package Template::DummyContext;
sub new   { bless { }, shift }
sub visit { }
sub leave { }

package main;

#------------------------------------------------------------------------
# create a document and check accessor methods for blocks and metadata
#------------------------------------------------------------------------
my $doc = DOCUMENT->new({
    BLOCK     => sub { my $c = shift; return "some output" },
    DEFBLOCKS => {
	    foo => sub { return 'the foo block' },
	    bar => sub { return 'the bar block' },
    },
    METADATA  => {
	    author  => 'Andy Wardley',
	    version => 3.14,
    },
});

my $c = Template::DummyContext->new();

ok( $doc, 'created document' );
is( $doc->author(), 'Andy Wardley', 'document author' );
is( $doc->version(), 3.14, 'document version' );
is( $doc->process($c), 'some output', 'generated output from process()' );
is( ref($doc->block()), 'CODE', 'CODE block' );
is( ref($doc->blocks->{ foo }), 'CODE', 'foo block is code' );
is( ref($doc->blocks->{ bar }), 'CODE', 'bar block is code' );
is( $doc->block->(), 'some output', 'ran main block' );
is( $doc->blocks->{ foo }->(), 'the foo block', 'ran foo block' );
is( $doc->blocks->{ bar }->(), 'the bar block', 'ran bar block' );

test_expect( vars => { mydoc => $doc } );

__END__
-- test metadata --
# test metadata
[% META
   author = 'Tom Smith'
   version = 1.23 
-%]
version [% template.version %] by [% template.author %]
-- expect --
version 1.23 by Tom Smith

# test local block definitions are accessible
-- test local block defs --
[% BLOCK foo -%]
   This is block foo
[% INCLUDE bar -%]
   This is the end of block foo
[% END -%]
[% BLOCK bar -%]
   This is block bar
[% END -%]
[% PROCESS foo %]
-- expect --
   This is block foo
   This is block bar
   This is the end of block foo

-- test title --
[% META title = 'My Template Title' -%]
[% BLOCK header -%]
title: [% template.title or title %]
[% END -%]
[% INCLUDE header %]
-- expect --
title: My Template Title

-- test header --
[% BLOCK header -%]
HEADER
component title: [% component.name %]
 template title: [% template.name %]
[% END -%]
component title: [% component.name %]
 template title: [% template.name %]
[% PROCESS header %]
-- expect --
component title: input text
 template title: input text
HEADER
component title: header
 template title: input text

-- test header title --
[% META title = 'My Template Title' -%]
[% BLOCK header -%]
title: [% title or template.title  %]
[% END -%]
[% INCLUDE header title = 'A New Title' %]
[% INCLUDE header %]
-- expect --
title: A New Title

title: My Template Title

-- test include mydoc --
[% INCLUDE $mydoc %]
-- expect --
some output

-- stop --
# test for component.caller and component.callers patch
-- test --
[% INCLUDE one;
   INCLUDE two;
   INCLUDE three;
%]
-- expect --
one, three
two, three
