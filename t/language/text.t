#============================================================= -*-perl-*-
#
# t/language/text.t
#
# Test general text blocks, ensuring all characters can be used.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Template::TT2::Test
    tests => 14,
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;

use constant ENGINE => 'Template::TT2';

#------------------------------------------------------------------------
package Stringy;

use overload '""' => \&asString;

sub asString {
    my $self = shift;
    return $$self;
}

sub new {
    my ($class, $val) = @_;
    return bless \$val, $class;
}

#------------------------------------------------------------------------
package main;

my $engines = {
    basic  => ENGINE->new(),
    interp => ENGINE->new(INTERPOLATE => 1),
};

my $vars = callsign();

my $v2 = {
    ref    => sub { my $a = shift; "$a\[" . ref($a) . ']' },
    sfoo   => Stringy->new('foo'),
    sbar   => Stringy->new('bar'),
};

@$vars{ keys %$v2 } = values %$v2;

test_expect(
    vars    => $vars,
    engine  => $engines->{ basic },
    engines => $engines,
);

__DATA__

-- test various characters --
This is a text block "hello" 'hello' 1/3 1\4 <html> </html>
$ @ { } @{ } ${ } # ~ ' ! % *foo
$a ${b} $c
-- expect --
This is a text block "hello" 'hello' 1/3 1\4 <html> </html>
$ @ { } @{ } ${ } # ~ ' ! % *foo
$a ${b} $c

-- test HTML elements and entities --
<table width=50%>&copy;
-- expect --
<table width=50%>&copy;

-- test comments in tag --
[% foo = 'Hello World' -%]
start
[%
#
# [% foo %]
#
#
-%]
end
-- expect --
start
end

-- test commented tag in tag --
pre
[%
# [% PROCESS foo %]
-%]
mid
[% BLOCK foo; "This is foo"; END %]
-- expect --
pre
mid

-- test interpolate --
-- use interp --
This is a text block "hello" 'hello' 1/3 1\4 <html> </html>
\$ @ { } @{ } \${ } # ~ ' ! % *foo
$a ${b} $c
-- expect --
This is a text block "hello" 'hello' 1/3 1\4 <html> </html>
$ @ { } @{ } ${ } # ~ ' ! % *foo
alpha bravo charlie

-- test interpolate HTML --
<table width=50%>&copy;
-- expect --
<table width=50%>&copy;

-- test interpolate comments --
[% foo = 'Hello World' -%]
start
[%
#
# [% foo %]
#
#
-%]
end
-- expect --
start
end

-- test interpolate commented tag in tag --
pre
[%
#
# [% PROCESS foo %]
#
-%]
mid
[% BLOCK foo; "This is foo"; END %]
-- expect --
pre
mid

-- test single quotes in double quotes --
[% a = "C'est un test"; a %]
-- expect --
C'est un test

-- test same for META --
[% META title = "C'est un test" -%]
[% component.title -%]
-- expect --
C'est un test

-- test escape single quote --
[% META title = 'C\'est un autre test' -%]
[% component.title -%]
-- expect --
C'est un autre test

-- test escaped double quote --
[% META title = "C'est un \"test\"" -%]
[% component.title -%]
-- expect --
C'est un "test"

-- test foo/bar --
[% sfoo %]/[% sbar %]
-- expect --
foo/bar

-- test ref --
[%  s1 = "$sfoo"
    s2 = "$sbar ";
    s3  = sfoo;
    ref(s1);
    '/';
    ref(s2);
    '/';
    ref(s3);
-%]
-- expect --
foo[]/bar []/foo[Stringy]

