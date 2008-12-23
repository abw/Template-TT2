#============================================================= -*-perl-*-
#
# t/module/tt2.t
#
# Test the Template::TT2 front-end module.
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
    tests => 10,
    debug => 'Template::TT2',
    args  => \@ARGV;

use Template::TT2;
use Badger::Filesystem '$Bin Dir';
my  $dir = Dir($Bin);
my  $out;


#-----------------------------------------------------------------------
# test that preload() works
#-----------------------------------------------------------------------

Template::TT2->preload;

ok( $Template::TT2::Stash::VERSION,     'Template::TT2::Stash is loaded'     );
ok( $Template::TT2::Parser::VERSION,    'Template::TT2::Parser is loaded'    );
ok( $Template::TT2::Context::VERSION,   'Template::TT2::Context is loaded'   );
ok( $Template::TT2::Plugins::VERSION,   'Template::TT2::Plugins is loaded'   );
ok( $Template::TT2::Service::VERSION,   'Template::TT2::Service is loaded'   );
ok( $Template::TT2::Filters::VERSION,   'Template::TT2::Filters is loaded'   );
ok( $Template::TT2::Iterator::VERSION,  'Template::TT2::Iterator is loaded'  );
ok( $Template::TT2::Templates::VERSION, 'Template::TT2::Templates is loaded' );

#-----------------------------------------------------------------------
# check other housekeeping methods
#-----------------------------------------------------------------------

ok( Template::TT2->VERSION, 'VERSION()' );


#-----------------------------------------------------------------------
# check process() method
#-----------------------------------------------------------------------

my $tt = Template::TT2->new(
    INCLUDE_PATH => $dir->dir('templates'),
);

$tt->process('hello', undef, \$out)
    || die $tt->error;

is( $out, 'Hello World', 'Hello World' );
$out = '';

$tt->process('hello', { name => 'Badger' }, \$out)
    || die $tt->error;

is( $out, 'Hello Badger', 'Hello Badger' );
$out = '';


#-----------------------------------------------------------------------
# check other methods accessing service, context, etc.
#-----------------------------------------------------------------------

is( ref $tt->hub,     'Template::TT2::Hub', 'hub()' );
is( ref $tt->service, 'Template::TT2::Service', 'service()' );
is( ref $tt->context, 'Template::TT2::Context', 'context()' );
