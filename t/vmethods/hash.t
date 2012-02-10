#============================================================= -*-perl-*-
#
# t/vmethods/hash.t
#
# Testing hash virtual variable methods.
#
# Run with -h option for help.
#
# Written by Andy Wardley <abw@cpan.org>
#
# Copyright (C) 1996-2012 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib     => '../../lib ../../blib/lib ../../blib/arch';

use Template::TT2::Test
    tests   => 10,
    debug   => 'Template::TT2::VMethods',
    args    => \@ARGV;

my $tt = Template::TT2->new;
my $tc = $tt->context;

$tc->define_vmethod(
    hash => dump => sub {
        my $hash = shift;
        return '{ ' 
            . join(', ', map { "$_ => '$hash->{$_}'" } sort keys %$hash)
            . ' }';
    }
);

my $vars = {
    hash      => { a => 'b', c => 'd' },
    uhash     => { tobe => '2b', nottobe => undef },
};

test_expect(
    vars => $vars
);

__DATA__

#------------------------------------------------------------------------
# hash virtual methods
#------------------------------------------------------------------------

-- test hash keys --
[% hash.keys.sort.join(', ') %]
-- expect --
a, c

-- test hash values --
[% hash.values.sort.join(', ') %]
-- expect --
b, d

-- test hash each --
[% hash.each.sort.join(', ') %]
-- expect --
a, b, c, d

-- test hash items --
[% hash.items.sort.join(', ') %]
-- expect --
a, b, c, d

-- test hash size --
[% hash.size %]
-- expect --
2

-- test hash.defined --
[% hash.defined('a') ? 'good' : 'bad' %]
[% hash.a.defined ? 'good' : 'bad' %]
[% hash.defined('x') ? 'bad' : 'good' %]
[% hash.x.defined ? 'bad' : 'good' %]
[% hash.defined ? 'good def' : 'bad def' %]
[% no_such_hash.defined ? 'bad no def' : 'good no def' %]
-- expect --
good
good
good
good
good def
good no def

-- test hash.defined again --
[% uhash.defined('tobe') ? 'good' : 'bad' %]
[% uhash.tobe.defined ? 'good' : 'bad' %]
[% uhash.exists('tobe') ? 'good' : 'bad' %]
[% uhash.defined('nottobe') ? 'bad' : 'good' %]
[% hash.nottobe.defined ? 'bad' : 'good' %]
[% uhash.exists('nottobe') ? 'good' : 'bad' %]
-- expect --
good
good
good
good
good
good

-- test hash.pairs --
[% FOREACH pair IN hash.pairs -%]
* [% pair.key %] => [% pair.value %]
[% END %]
-- expect --
* a => b
* c => d

-- test hash.list (old style) --
[% FOREACH pair IN hash.list -%]
* [% pair.key %] => [% pair.value %]
[% END %]
-- expect --
* a => b
* c => d



#------------------------------------------------------------------------
# user defined hash virtual methods
#------------------------------------------------------------------------

-- test hash.dump --
[% product = {
     id = 'abc-123',
     name = 'ABC Widget #123'
     price = 7.99
   };
   product.dump
%]
-- expect --
{ id => 'abc-123', name => 'ABC Widget #123', price => '7.99' }





