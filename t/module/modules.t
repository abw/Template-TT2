#============================================================= -*-perl-*-
#
# t/module/modules.t
#
# Test the Template::TT2::Modules module.
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
    lib   => '../../lib ../../blib/arch';

use Template::TT2::Test
    tests => 8,
    debug => 'Template::TT2::Modules Badger::Factory',
    args  => \@ARGV;

use Template::TT2::Modules;
Template::TT2::Modules->preload;

ok( $Template::TT2::Stash::VERSION,     'Template::TT2::Stash is loaded'     );
ok( $Template::TT2::Parser::VERSION,    'Template::TT2::Parser is loaded'    );
ok( $Template::TT2::Context::VERSION,   'Template::TT2::Context is loaded'   );
ok( $Template::TT2::Plugins::VERSION,   'Template::TT2::Plugins is loaded'   );
ok( $Template::TT2::Service::VERSION,   'Template::TT2::Service is loaded'   );
ok( $Template::TT2::Filters::VERSION,   'Template::TT2::Filters is loaded'   );
ok( $Template::TT2::Iterator::VERSION,  'Template::TT2::Iterator is loaded'  );
ok( $Template::TT2::Templates::VERSION, 'Template::TT2::Templates is loaded' );

