#============================================================= -*-perl-*-
#
# t/table.t
#
# Tests the 'Table' plugin.
#
# Run with -h option for help.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2000-2006 Andy Wardley. All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#
#========================================================================

use Badger
    lib   => '../../lib ../../blib/lib ../../blib/arch';

use Template::TT2::Test
    tests => 10,
    debug => 'Template::TT2::Plugin::Table',
    args  => \@ARGV;

test_expect(
    config => { POST_CHOMP => 1 },
    vars   => {
        alphabet => [ 'a'..'z' ],
        empty    => [ ],
    },
);
 

#------------------------------------------------------------------------
# test input
#------------------------------------------------------------------------

__DATA__

-- test rows by column --
[% USE table(alphabet, rows=5) %]
[% FOREACH letter IN table.col(0) %]
[% letter %]..
[%- END +%]
[% FOREACH letter IN table.column(1) %]
[% letter %]..
[%- END %]
-- expect --
a..b..c..d..e..
f..g..h..i..j..

-- test rows by rows --
[% USE table(alphabet, rows=5) %]
[% FOREACH letter IN table.row(0) %]
[% letter %]..
[%- END +%]
[% FOREACH letter IN table.row(1) %]
[% letter %]..
[%- END %]
-- expect --
a..f..k..p..u..z..
b..g..l..q..v....

-- test rows by cols --
[% USE table(alphabet, rows=3) %]
[% FOREACH col IN table.cols %]
[% col.0 %] [% col.1 %] [% col.2 +%]
[% END %]
-- expect --
a b c
d e f
g h i
j k l
m n o
p q r
s t u
v w x
y z 

-- test rows by columns --
[% USE table(alphabet, rows=3) %]
[% FOREACH col IN table.columns %]
[% col.0 %] [% col.1 %] [% col.2 +%]
[% END %]
-- expect --
a b c
d e f
g h i
j k l
m n o
p q r
s t u
v w x
y z 

-- test columns no padding --
[% USE alpha = table(alphabet, columns=3, pad=0) %]
[% FOREACH group IN alpha.columns %]
[ [% group.first %] - [% group.last %] ([% group.size %] letters) ]
[% END %]
-- expect --
[ a - i (9 letters) ]
[ j - r (9 letters) ]
[ s - z (8 letters) ]

-- test overlap --
[% USE alpha = table(alphabet, rows=5, pad=0, overlap=1) %]
[% FOREACH group = alpha.col %]
[ [% group.first %] - [% group.last %] ([% group.size %] letters) ]
[% END %]
-- expect --
[ a - e (5 letters) ]
[ e - i (5 letters) ]
[ i - m (5 letters) ]
[ m - q (5 letters) ]
[ q - u (5 letters) ]
[ u - y (5 letters) ]
[ y - z (2 letters) ]


-- test rows no padding --
[% USE table(alphabet, rows=5, pad=0) %]
[% FOREACH col IN table.cols %]
[% col.join('-') +%]
[% END %]
-- expect --
a-b-c-d-e
f-g-h-i-j
k-l-m-n-o
p-q-r-s-t
u-v-w-x-y
z

-- test overlap no padding --
[% USE table(alphabet, rows=8, overlap=1 pad=0) %]
[% FOREACH col IN table.cols %]
[% FOREACH item IN col %][% item %] [% END +%]
[% END %]

-- expect --
a b c d e f g h 
h i j k l m n o 
o p q r s t u v 
v w x y z 

-- test inline data --
[% USE table([1,3,5], cols=5) %]
[% FOREACH t IN table.rows %]
[% t.join(', ') %]
[% END %]
-- expect --
1, 3, 5

-- test empty --
>
[% USE table(empty, rows=3) -%]
[% FOREACH col = table.cols -%]
col
[% FOREACH item = col -%]
item: [% item -%]
[% END -%]
[% END -%]
<
-- expect --
>
<
