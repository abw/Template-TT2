#============================================================= -*-perl-*-
#
# t/language/args.t
#
# Testing the passing of positional and named arguments to sub-routines
# and object methods.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.
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
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;
    
use Template::TT2::Constants ':status';

#------------------------------------------------------------------------
# define simple object and package sub for reporting arguments passed
#------------------------------------------------------------------------

package MyObj;
use base 'Template::TT2::Base';

sub foo {
    my $self = shift;
    return "object:\n" . args(@_);
}

sub args {
    my @args = @_;
    my $named = ref $args[$#args] eq 'HASH' ? pop @args : { };
    local $" = ', ';
    
    return "  ARGS: [ @args ]\n NAMED: { "
	. join(', ', map { "$_ => $named->{ $_ }" } sort keys %$named)
	. " }\n";
}


#------------------------------------------------------------------------
# main tests
#------------------------------------------------------------------------

package main;

my $replace = callsign();
$replace->{ args } = \&MyObj::args;
$replace->{ obj  } = MyObj->new();

test_expect(
    config => { INTERPOLATE => 1 }, 
    vars   => $replace,
);


__DATA__
-- test positional args --
[% args(a b c) %]
-- expect --
  ARGS: [ alpha, bravo, charlie ]
 NAMED: {  }

-- test positional args and named params --
[% args(a b c d=e f=g) %]
-- expect --
  ARGS: [ alpha, bravo, charlie ]
 NAMED: { d => echo, f => golf }

-- test mixed with commas --
[% args(a, b, c, d=e, f=g) %]
-- expect --
  ARGS: [ alpha, bravo, charlie ]
 NAMED: { d => echo, f => golf }

-- test trailing comma --
[% args(a, b, c, d=e, f=g,) %]
-- expect --
  ARGS: [ alpha, bravo, charlie ]
 NAMED: { d => echo, f => golf }

-- test interspersed positional args and named params --
[% args(d=e, a, b, f=g, c) %]
-- expect --
  ARGS: [ alpha, bravo, charlie ]
 NAMED: { d => echo, f => golf }

-- test object call mixed --
[% obj.foo(d=e, a, b, f=g, c) %]
-- expect --
object:
  ARGS: [ alpha, bravo, charlie ]
 NAMED: { d => echo, f => golf }

-- test object call just args --
[% obj.foo(d=e, a, b, f=g, c).split("\n").1 %]
-- expect --
  ARGS: [ alpha, bravo, charlie ]

