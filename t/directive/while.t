#============================================================= -*-perl-*-
#
# t/directive/while.t
#
# Test the WHILE directive
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
    tests => 11,
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;

# set low limit on WHILE's maximum iteration count
use Template::TT2::Directive;
$Template::TT2::Directive::WHILE_MAX = 100;

my $config = {
    INTERPOLATE => 1, 
    POST_CHOMP  => 1,
};

my @list = ( 'x-ray', 'yankee', 'zulu', );
my @pending;
my $vars  = {
    'a'     => 'alpha',
    'b'     => 'bravo',
    'c'     => 'charlie',
    'd'     => 'delta',
    'dec'   => sub { --$_[0] },
    'inc'   => sub { ++$_[0] },
    'reset' => sub { @pending = @list; "Reset list\n" },
    'next'  => sub { shift @pending },
    'true'  => 1,
};

test_expect(
    config => $config, 
    vars   => $vars,
);

__DATA__
-- test WHILE nothing --
before
[% WHILE bollocks %]
do nothing
[% END %]
after
-- expect --
before
after

-- test WHILE dec --
Commence countdown...
[% a = 10 %]
[% WHILE a %]
[% a %]..[% a = dec(a) %]
[% END +%]
The end
-- expect --
Commence countdown...
10..9..8..7..6..5..4..3..2..1..
The end

-- test WHILE next --
[% reset %]
[% WHILE (item = next) %]
item: [% item +%]
[% END %]
-- expect --
Reset list
item: x-ray
item: yankee
item: zulu

-- test BREAK --
[% reset %]
[% WHILE (item = next) %]
item: [% item +%]
[% BREAK IF item == 'yankee' %]
[% END %]
Finis
-- expect --
Reset list
item: x-ray
item: yankee
Finis

-- test WHILE side-effect --
[% reset %]
[% "* $item\n" WHILE (item = next) %]
-- expect --
Reset list
* x-ray
* yankee
* zulu

-- test $WHILE_MAX --
[% TRY %]
[% WHILE true %].[% END %]
[% CATCH +%]
error: [% error.info %]
[% END %]
-- expect --
...................................................................................................
error: WHILE loop terminated (> 100 iterations)


-- test NEXT --
[% reset %]
[% WHILE (item = next) %]
[% NEXT IF item == 'yankee' -%]
* [% item +%]
[% END %]
-- expect --
Reset list
* x-ray
* zulu

-- test LAST nested in SWITCH --
[%  
    i = 1;
    WHILE i <= 10;
        SWITCH i;
        CASE 5;
            i = i + 1;
            NEXT;
        CASE 8;
            LAST;
        END;
        "$i\n";
        i = i + 1;
    END;
-%]
-- expect --
1
2
3
4
6
7

-- test LAST nested in IF --
[%
    i = 1;
    WHILE i <= 10;
        IF 1;
            IF i == 5; i = i + 1; NEXT; END;
            IF i == 8; LAST; END;
        END;
        "$i\n";
        i = i + 1;
    END;
-%]
-- expect --
1
2
3
4
6
7

-- test LAST nested deep --
[%
    i = 1;
    WHILE i <= 4;
        j = 1;
        WHILE j <= 4;
            k = 1;
            SWITCH j;
            CASE 2;
                WHILE k == 1; LAST; END;
            CASE 3;
                IF j == 3; j = j + 1; NEXT; END;
            END;
            "$i,$j,$k\n";
            j = j + 1;
        END;
        i = i + 1;
    END;
-%]
-- expect --
1,1,1
1,2,1
1,4,1
2,1,1
2,2,1
2,4,1
3,1,1
3,2,1
3,4,1
4,1,1
4,2,1
4,4,1

-- test LAST side-effected --
[%
    k = 1;
    LAST WHILE k == 1;
    "$k\n";
-%]
-- expect --
1
