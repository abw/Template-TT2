#============================================================= -*-perl-*-
#
# t/template.t
#
# Test the Template module.
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
use lib  qw( ./lib ../lib );
use lib  '/home/abw/projects/badger/lib';               # TMP
use Template::TT2;
use Template::TT2::Test
    tests => 10,
    debug => 'Template',
    args  => \@ARGV;

use Badger::Filesystem '$Bin Dir';

my $dir = Dir($Bin);
my $out;

my $tt2 = Template::TT2->new({
    INCLUDE_PATH => [$dir->dir('src'), $dir->dir('lib')],	
    OUTPUT       => \$out,
});
ok( $tt2, 'created Template::TT2 object' );
ok( $tt2->process('hello'), 'processed hello with no vars' );
is( $out, "Hello World!\n", 'Hello World' );
ok( $tt2->process('hello', { name => 'Badger' }), 'processed hello with name' );
is( $out, "Hello Badger!\n", 'Hello Badger' );

ok( ! $tt2->try( process => 'this_file_does_not_exist' ), 'cannot process missing file' );

__END__

ok( ! $tt->process('this_file_does_not_exist') );
my $error = $tt->error();
ok( $error->type() eq 'file' );
ok( $error->info() eq 'this_file_does_not_exist: not found' );

my @output;
$tt->process('header', undef, \@output);
ok(length($output[-1]));

sub myout {
  my $output = shift;
  ok($output)
}

ok($tt->process('header', undef, \&myout));

$out = Myout->new();

ok($tt->process('header', undef, $out));

package Myout;
use Template::Test;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  bless($self, $class);
  return $self;
}
sub print {
  my $output = shift;
  ok($output);
}
