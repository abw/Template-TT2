#============================================================= -*-perl-*-
#
# t/math.t
#
# Test the Math plugin module.
#
# Written by Andy Wardley <abw@wardley.org> and ...
#
# Copyright (C) 2002 Andy Wardley. All Rights Reserved.
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
    tests => 21,
    debug => 'Template::TT2::Plugins',
    args  => \@ARGV;

my $vars = {
    has_trig  => eval { require Math::Trig } || 0,
};
    
test_expect( vars => $vars );

__DATA__
-- test sqrt --
[% USE Math; Math.sqrt(9) %]
-- expect --
3

-- test abs --
[% USE Math; Math.abs(-1) %]
-- expect --
1

-- test atan --
[% USE Math; Math.atan2(42, 42).substr(0,17) %]
-- expect --
0.785398163397448

-- test cos --
[% USE Math; Math.cos(2).substr(0,18) %]
-- expect --
-0.416146836547142

-- test exp --
[% USE Math; Math.exp(6).substr(0,16) %]
-- expect --
403.428793492735

-- test hex --
[% USE Math; Math.hex(42) %]
-- expect --
66

-- test int --
[% USE Math; Math.int(9.9) %]
-- expect --
9

-- test log --
[% USE Math; Math.log(42).substr(0,15) %]
-- expect --
3.7376696182833

-- test oct --
[% USE Math; Math.oct(72) %]
-- expect --
58

-- test sin --
[% USE Math; Math.sin(0.304).substr(0,17) %]
-- expect --
0.299339178269093

-- test trig --
[%  IF has_trig;
      USE Math;
        "Pi: "; Math.pi.substr(0, 10);
    ELSE;
      TRY; 
        USE Math trig=1;
      CATCH;
        error;
      END;
    END;
%]
-- expect --  
-- process --
[% IF has_trig -%]
Pi: 3.14159265
[%- ELSE -%]
plugin.math error - The Math::Trig module is not installed
[%- END -%]



#-----------------------------------------------------------------------
# test vmethods
#-----------------------------------------------------------------------

-- test n.sqrt --
[% USE Math; n = 9; n.sqrt %]
-- expect --
3

-- test n.abs --
[% USE Math; n = -1; n.abs %]
-- expect --
1

-- test n.atan(m) --
[% USE Math; n=42; n.atan2(42).substr(0,17) %]
-- expect --
0.785398163397448

-- test n.cos --
[% USE Math; n=2; n.cos.substr(0,18) %]
-- expect --
-0.416146836547142

-- test n.exp --
[% USE Math; n=6; n.exp.substr(0,16) %]
-- expect --
403.428793492735

-- test n.hex --
[% USE Math; n=42; n.hex %]
-- expect --
66

-- test n.int --
[% USE Math; n=9.9; n.int %]
-- expect --
9

-- test n.log --
[% USE Math; n=42; n.log(42).substr(0,15) %]
-- expect --
3.7376696182833

-- test n.oct --
[% USE Math; n=72; n.oct(72) %]
-- expect --
58

-- test n.sin --
[% USE Math; n=0.304; n.sin(0.304).substr(0,17) %]
-- expect --
0.299339178269093
