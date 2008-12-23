#============================================================= -*-perl-*-
#
# t/module/tt2t.t
#
# Test the Template::TT2 front-end module using the Template alias.
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

use Template::TT2 'Template';           # alias Template to Template::TT2 
use Badger::Filesystem '$Bin Dir';
my  $dir = Dir($Bin);
my  $out;

# the old Template module can't do this, but Template::TT2 can
Template->preload;

ok( $Template::TT2::Stash::VERSION,     'Template::TT2::Stash is loaded'     );
ok( $Template::TT2::Parser::VERSION,    'Template::TT2::Parser is loaded'    );
ok( $Template::TT2::Context::VERSION,   'Template::TT2::Context is loaded'   );
ok( $Template::TT2::Plugins::VERSION,   'Template::TT2::Plugins is loaded'   );
ok( $Template::TT2::Service::VERSION,   'Template::TT2::Service is loaded'   );
ok( $Template::TT2::Filters::VERSION,   'Template::TT2::Filters is loaded'   );
ok( $Template::TT2::Iterator::VERSION,  'Template::TT2::Iterator is loaded'  );
ok( $Template::TT2::Templates::VERSION, 'Template::TT2::Templates is loaded' );

my $tt = Template->new(
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

