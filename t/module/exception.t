#============================================================= -*-perl-*-
#
# t/module/exception.t
#
# Test the Template::TT2::Exception module.
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
    tests => 15,
    debug => 'Template::TT2::Exception Badger::Exception',
    args  => \@ARGV;

use Template::TT2::Exception;
use constant 
    EXCEPTION => 'Template::TT2::Exception';

my $text = 'the current output buffer';

my $e1 = EXCEPTION->new( 
    type => 'e1.type', 
    info => 'e1.info',
);
my $e2 = EXCEPTION->new({ 
    type => 'e2.type', 
    info => 'e2.info', 
    body => \$text,
});

ok( $e1, 'got error 1' );
ok( $e2, 'got error 2' );
is( $e1->type(), 'e1.type', 'error type' );
is( $e2->info(), 'e2.info', 'error info' );

my @ti = $e1->type_info();
is( $ti[0], 'e1.type', 'type_info error type' );
is( $ti[1], 'e1.info', 'type_info error info' );

is( $e2->text(), 'e2.type error - e2.info' );
is( $e2->body, 'the current output buffer' );

my $prepend = 'text to prepend ';
$e2->body(\$prepend);
is( $e2->body, 'text to prepend the current output buffer', 'appended body output' );

my @handlers = ('something', 'e2', 'e1.type');
is( $e1->match_type(@handlers), 'e1.type', 'match type e1' );
is( $e2->match_type(@handlers), 'e2', 'match type e2' );

my $e3 = EXCEPTION->new( type => 'e3.type', info => 'e3.info');
ok( $e3, 'got third exception' );
is( $e3->body, '', 'empty body');
is( $e3, 'e3.type error - e3.info', 'stringified error' );

# test to check that overloading fallback works properly
# by using a non explicitly defined op
isnt( $e3, "fish", 'not a fish');
