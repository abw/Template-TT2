#============================================================= -*-perl-*-
#
# t/language/next_last.t
#
# Template script testing NEXT/LAST directives.
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
    lib         => '../../lib',
    Filesystem  => 'Bin Dir';

use Template::TT2::Test
    tests       => 4,
    debug       => 'Template::TT2::Parser',
    args        => \@ARGV;

test_expect();

__DATA__
-- test foreach next --
[%  FOREACH i IN [1..5];
        i;
        IF loop.even;
            "\n";
            NEXT;
        END; 
        ' is odd';
        "\n";
    END
%]
-- expect --
1 is odd
2
3 is odd
4
5 is odd

-- test next nested in for/while --
[%  FOREACH i IN [1..9];
        "${i}: ";
        j = 0;
        WHILE j < i;
            j = j + 1;
            NEXT IF j > 3;
            "${j} ";
        END;
        "\n";
    END;
%]
-- expect --
1: 1 
2: 1 2 
3: 1 2 3 
4: 1 2 3 
5: 1 2 3 
6: 1 2 3 
7: 1 2 3 
8: 1 2 3 
9: 1 2 3 

-- test foreach last --
[%  FOREACH n IN [1..5];
        LAST IF n > 3;
        n;
    END
%]
-- expect --
123

-- test last nested in for/while --
[%  FOREACH i IN [1..9];
        "${i}: ";
        j = 0;
        WHILE j < i;
            j = j + 1;
            LAST IF j > 3;
            "${j} ";
        END;
        "\n";
    END;
%]
-- expect --
1: 1 
2: 1 2 
3: 1 2 3 
4: 1 2 3 
5: 1 2 3 
6: 1 2 3 
7: 1 2 3 
8: 1 2 3 
9: 1 2 3 
