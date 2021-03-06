#============================================================= -*-perl-*-
#
# t/lanauge/tied.t
#
# Template script testing variable via a tied hash/list
#
# Written by Andy Wardley <abw@wardley.org>
#
# Run with -h option for help.
#
# Copyright (C) 1996-2012 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib         => '../../lib ../../blib/lib ../../blib/arch',
    Filesystem  => 'Bin';

use Template::TT2::Test
    debug   => 'Template::TT2::Parser',
    args    => \@ARGV;

use constant 
    ENGINE  => 'Template::TT2';

use Template::TT2::Stash;
use Template::TT2::Stash::Perl;
my $dir = Bin->dir('templates')->must_exist;
my $xs  = Template::TT2::Stash->xs_backend;

# 2 runs if we don't have XS stash, 3 if we do
plan( 11 * ($xs ? 3 : 2) );

our $STORE_PREFIX = '';
our $FETCH_PREFIX = '';


#------------------------------------------------------------------------
package My::Tied::Hash;
use Tie::Hash;
use base 'Tie::StdHash';

sub FETCH {
    my ($hash, $key) = @_;
    print STDERR "FETCH($key)\n" if $main::DEBUG;
    my $val = $hash->{ $key };
    return $val ? (ref $val ? $val : "$main::FETCH_PREFIX$val") : undef;
}

sub STORE { 
    my ($hash, $key, $val) = @_; 
    print STDERR "STORE($key, $val)\n" if $main::DEBUG;
    $hash->{ $key } = ref $val ? $val : "$main::STORE_PREFIX$val";
    return $val;
}

#------------------------------------------------------------------------
package My::Tied::List;
use Tie::Array;
use base 'Tie::StdArray';

sub FETCH {
    my ($list, $n) = @_;
    print STDERR "FETCH from list [$n]\n" if $main::DEBUG;
    my $val = $list->[ $n ];
    return $val ? (ref $val ? $val : "$main::FETCH_PREFIX$val") : undef;
}

sub STORE {
    my ($list, $n, $val) = @_;
    print STDERR "STORE to list [$n => $val]\n" if $main::DEBUG;
    $list->[$n] = ref $val ? $val : "$main::STORE_PREFIX$val";
}

#------------------------------------------------------------------------
package main;

run_tests('Template::TT2::Stash::Perl');
run_tests('Template::TT2::Stash');
run_tests('Template::TT2::Stash::XS')
    if $xs;

sub run_tests {
    my ($stash_type) = @_;

    # setup a tied hash and a tied list
    my @list;
    tie @list, 'My::Tied::List';
    push(@list, 10, 20, 30);

    my %hash = (a => 'alpha');
    tie %hash, 'My::Tied::Hash';
    $hash{ a } = 'alpha';
    $hash{ b } = 'bravo';
    $hash{ zero } = 0;
    $hash{ one } = 1;

    # now turn on the prefixes so we can track items going in 
    # and out of the tied hash/list
    local $FETCH_PREFIX = 'FETCH:';
    local $STORE_PREFIX = 'STORE:';

    my $data = {
        hash => \%hash,
        list => \@list,
    };

    my $stash = $stash_type->new($data);
    pass("Engaging $stash_type");

    test_expect(
        engine => ENGINE->new( STASH => $stash )
    );
}

__DATA__

#-----------------------------------------------------------------------------
# tied hash tests
#-----------------------------------------------------------------------------

-- test tied hash fetch --
[% hash.a %]
-- expect --
FETCH:alpha

-- test tied hash fetch again --
[% hash.b %]
-- expect --
FETCH:bravo

-- test tied hash store --
ready
set:[% hash.c = 'cosmos' %]
go:[% hash.c %]
-- expect --
ready
set:
go:FETCH:STORE:cosmos

-- test tied hash default --
[% DEFAULT hash.d = 'delta'; hash.d %]
-- expect --
FETCH:STORE:delta

-- test tied hash nested --
[% hash.foo.bar = 'one' -%]
[% hash.foo.bar %]
-- expect --
one

-- test tied hash nested person --
[% DEFAULT hash.person = { };
   hash.person.name  = 'Arthur Dent';
   hash.person.email = 'dent@tt2.org'; 
-%]
name:  [% hash.person.name %]
email: [% hash.person.email %]
-- expect --
name:  Arthur Dent
email: dent@tt2.org


#-----------------------------------------------------------------------------
# tied list tests
#-----------------------------------------------------------------------------

-- test tied list item --
[% list.0 %]
-- expect --
FETCH:10

-- test tied list vmethods --
[% list.first %]-[% list.last %]
-- expect --
FETCH:10-FETCH:30

-- test tied list push --
[% list.push(40); list.last %]
-- expect --
FETCH:40

-- test tied list assign --
[% list.4 = 50; list.4 %]
-- expect --
FETCH:STORE:50


