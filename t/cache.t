#============================================================= -*-perl-*-
#
# t/cache.t
#
# Test the Template::TT2::Cache module.  Run with -d for debugging,
# -c for colour, -s for test summary.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib );
use Template::TT2::Test
    tests => 18,
    debug => 'Template::TT2::Cache',
    args  => \@ARGV;

use Template::TT2::Cache;


#------------------------------------------------------------------------
# some basic test of get/set methods
#------------------------------------------------------------------------

my $pkg = 'Template::TT2::Cache';
my $cache = $pkg->new( size => 3 );
ok( $cache, 'created a cache object' );

# add one
ok( $cache->set( pi => 3.14 ), 'set pi' );
is( $cache->get('pi'), 3.14, 'get pi' );
is( $cache->get('pi'), 3.14, 'get pi again' );

# add another
ok( $cache->set( e => 2.71 ), 'set e' );
is( $cache->get('e'), 2.71, 'get e' );
is( $cache->get('e'), 2.71, 'get e again' );

# update 
ok( $cache->set( e => 2.718 ), 'set e more precise' );
is( $cache->get('e'), 2.718, 'get e more precise' );

# add another
ok( $cache->set( a => 'foo' ), 'set a' );

# check we can still get them all
is( $cache->get('pi'), 3.14, 'still got pi' );
is( $cache->get('e'), 2.718, 'still got e' );
is( $cache->get('a'), 'foo', 'still got a' );

# this should push us over the size limit
ok( $cache->set( b => 'bar' ), 'set b' );

# pi should have been discarded
ok( ! defined $cache->get('pi'),'no more pi' );
ok( $cache->declined(), 'cache declined pi' );
is( $cache->error(), "not found in cache: pi", 'cache declined pi error' );

# but e should still be there
is( $cache->get('e'), 2.718, 'still got e though' );

#print STDERR $cache->_slot_report() if $DEBUG;

__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

