#============================================================= -*-perl-*-
#
# t/directive/throw.t
#
# Test the THROW directive.
#
# Run with -h option for help.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 1996-2012 Andy Wardley. All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib     => '../../lib ../../blib/lib ../../blib/arch';

use Template::TT2::Test
    tests   => 5,
    debug   => 'Template::TT2::Parser',
    args    => \@ARGV;

test_expect();
 

__DATA__
-- test throw chicken --
[% me = 'I' -%]
[% TRY -%]
   [%- THROW chicken "Failed failed failed" 'boo' name='Fred' -%]
[% CATCH -%]
ERROR: [% error.type %] - [% error.info.0 %]/[% error.info.1 %]/[% error.info.name %]
[% END %]
-- expect --
ERROR: chicken - Failed failed failed/boo/Fred

-- test throw eggs --
[% TRY -%]
[% THROW food 'eggs' -%]
[% CATCH -%]
ERROR: [% error.type %] / [% error.info %]
[% END %]

-- expect --
ERROR: food / eggs

# test throwing multiple params
-- test throw pi --
[% pi = 3.14
   e  = 2.718 -%]
[% TRY -%]
[% THROW foo pi e msg="fell over" reason="brain exploded" -%]
[% CATCH -%]
[% error.type %]: pi=[% error.info.0 %]  e=[% error.info.1 %]
     I [% error.info.msg %] because my [% error.info.reason %]!
[% END %]
-- expect --
foo: pi=3.14  e=2.718
     I fell over because my brain exploded!

-- test catch anything --
[% TRY -%]
[% THROW foo 'one' 2 three=3.14 -%]
[% CATCH -%]
   [% error.type %]
   [% error.info.0 %]
   [% error.info.1 %]
   [% error.info.three %]
   [%- FOREACH e = error.info.args %]
   * [% e %]
   [%- END %]
[% END %]
-- expect --
   foo
   one
   2
   3.14
   * one
   * 2

-- test catch food --
[% TRY -%]
[% THROW food 'eggs' 'flour' msg="Missing Ingredients" -%]
[% CATCH food -%]
   [% error.info.msg %]
[% FOREACH item = error.info.args -%]
      * [% item %]
[% END -%]
[% END %]
-- expect --
   Missing Ingredients
      * eggs
      * flour



