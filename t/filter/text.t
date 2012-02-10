#============================================================= -*-perl-*-
#
# t/filter/text.t
#
# Test the various static text filters (i.e. those that don't take args)
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
    lib     => '../../lib ../../blib/lib ../../blib/arch';

use Template::TT2::Test
    tests   => 6,
    debug   => 'Template::TT2::Filters',
    args    => \@ARGV;

test_expect();

__DATA__
-- test upper --
[% FILTER upper %]
The cat sat on the mat
[% END %]
-- expect --
THE CAT SAT ON THE MAT

-- test lower --
[% FILTER lower %]
The Cat Sat on the Mat
[% END %]
-- expect --
the cat sat on the mat

-- test ucfirst --
[% 'hello world' | ucfirst %]
-- expect --
Hello world

-- test lcfirst --
[% 'Hello world' | lcfirst %]
-- expect --
hello world

-- test trim --
<<[% FILTER trim %]
   
          
The cat sat
on the
mat


[% END %]>>
-- expect --
<<The cat sat
on the
mat>>

-- test collapse --
<<[% FILTER collapse %]
   
          
The    cat     sat
on    the
mat


[% END %]>>
-- expect --
<<The cat sat on the mat>>

