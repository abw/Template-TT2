#============================================================= -*-perl-*-
#
# t/directive/macro.t
#
# Template script testing the MACRO directives.
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
    lib         => '../../lib ../../blib/lib ../../blib/arch',
    Filesystem  => 'Bin';

use Template::TT2::Test
    tests       => 9,
    debug       => 'Template::TT2::Parser',
    args        => \@ARGV;

test_expect(
    vars   => callsign,
    config => {
        INCLUDE_PATH => Bin->dir('templates')->must_exist,
        EVAL_PERL    => 1,
        TRIM         => 1,
    }
);

__DATA__

-- test foo MACRO --
[% MACRO foo INCLUDE foo -%]
foo: [% foo %]
foo(b): [% foo(a = b) %]
-- expect --
foo: This is the foo file, a is alpha
foo(b): This is the foo file, a is bravo

-- test MACRO gone --
foo: [% foo %].
-- expect --
foo: .

-- test foo MACRO with arg --
[% MACRO foo(a) INCLUDE foo -%]
foo: [% foo %]
foo(c): [% foo(c) %]
-- expect --
foo: This is the foo file, a is
foo(c): This is the foo file, a is charlie


-- test BLOCK MACRO --
[% BLOCK mypage %]
Header
[% content %]
Footer
[% END %]

[%- MACRO content BLOCK -%]
This is a macro which encapsulates a template block.
a: [% a -%]
[% END -%]

begin
[% INCLUDE mypage %]
mid
[% INCLUDE mypage a = 'New Alpha' %]
end
-- expect --
begin
Header
This is a macro which encapsulates a template block.
a: alpha
Footer
mid
Header
This is a macro which encapsulates a template block.
a: New Alpha
Footer
end

-- test user_row MACRO --
[% BLOCK table %]
<table>
[% rows %]
</table>
[% END -%]

[% # define some dummy data
   udata = [
      { id => 'foo', name => 'Fubar' },
      { id => 'bar', name => 'Babar' }
   ] 
-%]

[% # define a macro to print each row of user data
   MACRO user_summary INCLUDE user_row FOREACH user = udata 
%]

[% # here's the block for each row
   BLOCK user_row %]
<tr>
  <td>[% user.id %]</td>
  <td>[% user.name %]</td>
</tr>
[% END -%]

[% # now we can call the main table template, and alias our macro to 'rows' 
   INCLUDE table 
     rows = user_summary
%]
-- expect --
<table>
<tr>
  <td>foo</td>
  <td>Fubar</td>
</tr><tr>
  <td>bar</td>
  <td>Babar</td>
</tr>
</table>

-- test MACRO BLOCK --
[% MACRO one BLOCK -%]
one: [% title %]
[% END -%]
[% saveone = one %]
[% MACRO two BLOCK; title="2[$title]" -%]
two: [% title %] -> [% saveone %]
[% END -%]
[% two(title="The Title") %]
-- expect --
two: 2[The Title] -> one:

-- test one BLOCK --
[% MACRO one BLOCK -%]
one: [% title %]
[% END -%]
[% saveone = \one %]
[% MACRO two BLOCK; title="2[$title]" -%]
two: [% title %] -> [% saveone %]
[% END -%]
[% two(title="The Title") %]
-- expect --
two: 2[The Title] -> one: 2[The Title]

-- test number macro --
[% MACRO number(n) GET n.chunk(-3).join(',') -%]
[% number(1234567) %]
-- expect --
1,234,567

-- test perl macro --
[% MACRO triple(n) PERL %]
    my $n = $stash->get('n');
    print $n * 3;
[% END -%]
[% triple(10) %]
-- expect --
30

