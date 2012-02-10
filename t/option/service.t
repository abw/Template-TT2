#============================================================= -*-perl-*-
#
# t/option/service.t
#
# Test the SERVICE option.
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
    tests => 2,
    debug => 'Template::TT2::Service-NOT
              Badger::Factory
              Template::TT2::Hub',
    args  => \@ARGV;

use Template::TT2;
use constant {
    ENGINE => 'Template::TT2',
    HUB    => 'Template::TT2::Hub',
};
use YourService;

my $tt_my_service = ENGINE->new(
    SERVICE => 'MyService',
);

my $tt_your_service = ENGINE->new(
    SERVICE => YourService->new( hub => HUB ),
);
my $vars = { };

test_expect(
    vars    => $vars,
    engines => {
        my_service   => $tt_my_service,
        your_service => $tt_your_service,
    },
);


__DATA__
-- test SERVICE module name --
-- use my_service --
Hello World
-- expect --
<MY SERVICE>
Hello World
</MY SERVICE>

-- test SERVICE object --
-- use your_service --
Hello World
-- expect --
<YOUR SERVICE>
Hello World
</YOUR SERVICE>
