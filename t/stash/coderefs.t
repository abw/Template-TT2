#============================================================= -*-perl-*-
#
# t/stash/coderefs.t
#
# Test the Template::TT2::Stash module and in particular, its ability to
# return code references.
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
    lib   => '../lib ../../lib ../../blib/lib ../../blib/arch';

use Template::TT2::Test
    tests => 4,
    debug => 'Template::TT2::Stash',
    args  => \@ARGV;

use Template::TT2::Stash;
use Template::TT2::Constants
    'TT2_STASH CODE';

sub hello {
    my $name = shift || 'World';
    return "Hello $name";
}

my $data  = {
    hello   => \&hello,
    greeter => sub {
        return \&hello;
    },
};


my $stash = TT2_STASH->new($data);

# call regular subroutine
is( $stash->get('hello'), 'Hello World', 'hello with no args' );
is( $stash->get('hello', ['Badger']), 'Hello Badger', 'hello with args' );

# call subroutine that returns a subroutine
my $sub = $stash->get('greeter');
is( ref $sub, CODE, 'greeter returns code ref' );
is( $sub->(), 'Hello World', 'called greeter' );

