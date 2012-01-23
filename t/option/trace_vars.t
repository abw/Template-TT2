#============================================================= -*-perl-*-
#
# t/options/trace_vars.t
#
# Perl script to test static analysis of variables used.
#
# Written by Andy Wardley http://wardley.org/
#
# Copyright (C) 1996-2012 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib         => '../../lib',
    Filesystem  => 'Bin Dir';

use Template::TT2::Test
    tests       => 13,
    debug       => 'Template::TT2::VMethods',
    args        => \@ARGV;

my $tt       = Template::TT2->new( TRACE_VARS => 1 );
my $template = $tt->template(\*DATA) || die $tt->error;
my $vars     = $template->variables;

ok( $vars->{ foo }, 'foo is used' );
ok( $vars->{ bar }, 'bar is used' );
ok( $vars->{ bar }->{ baz }, 'bar.baz is used' );
ok( $vars->{ blam }, 'blam is used' );
ok( $vars->{ blam }->{ 0 }, 'blam.0 is used' );
ok( $vars->{ wig }, 'wig is used' );
ok( $vars->{ wig }->{ wam }, 'wig.wam is used' );
ok( $vars->{ wig }->{ wam }->{ bam }, 'wig.wam.bam is used' );

# NOTE: we don't currently detect variables being set, only those being
# fetched...

foreach my $letter ('a'..'e') {
    ok( $vars->{ $letter }, "$letter is used" );
}

# TODO: extend this so we can detect the variables f, g, x and y.z being
# assigned to.

__END__
Hello World 
[% foo -%]
[% bar.baz -%]
[% blam.0 -%]
[% wig(10).wam(a,b,c).bam(f = d, g = e) -%]
[% x = 10; y.z = 20 -%]
Goodbye
