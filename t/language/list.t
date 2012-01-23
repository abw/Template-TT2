#============================================================= -*-perl-*-
#
# t/language/list.t
#
# Tests list references as variables, including virtual-methods such
# as first(), last(), etc.
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
    tests => 19,
    debug => 'Template::TT2::Stash',
    args  => \@ARGV;
    
use Template::TT2::Constants ':status';

# sample data
my ($a, $b, $c, $d, $e, $f, $g, $h, $i, $j, $k, $l, $m, 
    $n, $o, $p, $q, $r, $s, $t, $u, $v, $w, $x, $y, $z) = 
    qw( alpha bravo charlie delta echo foxtrot golf hotel india 
        juliet kilo lima mike november oscar papa quebec romeo 
        sierra tango umbrella victor whisky x-ray yankee zulu );

my $data = [ $r, $j, $s, $t, $y, $e, $f, $z ];
my $vars = { 
    'a'  => $a,
    'b'  => $b,
    'c'  => $c,
    'd'  => $d,
    'e'  => $e,
    data => $data,
    days => [ qw( Mon Tue Wed Thu Fri Sat Sun ) ],
    wxyz => [ 
        { id => $z, name => 'Zebedee', rank => 'aa' },
        { id => $y, name => 'Yinyang', rank => 'ba' },
        { id => $x, name => 'Xeexeez', rank => 'ab' },
        { id => $w, name => 'Warlock', rank => 'bb' }, 
    ],
    inst => [
        { name => 'piano', url => '/roses.html'  },
        { name => 'flute', url => '/blow.html'   },
        { name => 'organ', url => '/tulips.html' }, 
    ],
    nest => [ [ 3, 1, 4 ], [ 2, [ 7, 1, 8 ] ] ],
};

test_expect( vars => $vars );


__DATA__

#------------------------------------------------------------------------
# GET 
#------------------------------------------------------------------------
-- test numerical list item --
[% data.0 %] and [% data.1 %]
-- expect --
romeo and juliet

-- test first/last vmethods --
[% data.first %] - [% data.last %]
-- expect --
romeo - zulu

-- test size/max vmethods --
[% data.size %] [% data.max %]
-- expect --
8 7

-- test join vmethod --
[% data.join(', ') %]
-- expect --
romeo, juliet, sierra, tango, yankee, echo, foxtrot, zulu

-- test reverse join --
[% data.reverse.join(', ') %]
-- expect --
zulu, foxtrot, echo, yankee, tango, sierra, juliet, romeo

-- test sort reverse join --
[% data.sort.reverse.join(' - ') %]
-- expect --
zulu - yankee - tango - sierra - romeo - juliet - foxtrot - echo

-- test FOREACH over sorted list --
[% FOREACH item IN wxyz.sort('id') -%]
* [% item.name %]
[% END %]
-- expect --
* Warlock
* Xeexeez
* Yinyang
* Zebedee

-- test sorted by rank --
[% FOREACH item IN wxyz.sort('rank') -%]
* [% item.name %]
[% END %]
-- expect --
* Zebedee
* Xeexeez
* Yinyang
* Warlock

-- test anonymous list range --
[% FOREACH n IN [0..6] -%]
[% days.$n +%]
[% END -%]
-- expect --
Mon
Tue
Wed
Thu
Fri
Sat
Sun

-- test more joining --
[% data = [ 'one', 'two', data.first ] -%]
[% data.join(', ') %]
-- expect --
one, two, romeo

-- test sort and nsort --
[% data = [ 90, 8, 70, 6, 1, 11, 10, 2, 5, 50, 52 ] -%]
 sort: [% data.sort.join(', ') %]
nsort: [% data.nsort.join(', ') %]
-- expect --
 sort: 1, 10, 11, 2, 5, 50, 52, 6, 70, 8, 90
nsort: 1, 2, 5, 6, 8, 10, 11, 50, 52, 70, 90

-- test push --
[% ilist = [] -%]
[% ilist.push("<a href=\"$i.url\">$i.name</a>") FOREACH i = inst -%]
[% ilist.join(",\n") -%]
[% global.ilist = ilist -%]
-- expect --
<a href="/roses.html">piano</a>,
<a href="/blow.html">flute</a>,
<a href="/tulips.html">organ</a>

-- test pop -- 
[% global.ilist.pop %]
-- expect --
<a href="/tulips.html">organ</a>

-- test shift -- 
[% global.ilist.shift %]
-- expect --
<a href="/roses.html">piano</a>

-- test unshift -- 
[% global.ilist.unshift('another') -%]
[% global.ilist.join(', ') %]
-- expect --
another, <a href="/blow.html">flute</a>

-- test nested --
[% nest.0.0 %].[% nest.0.1 %][% nest.0.2 +%]
[% nest.1.shift %].[% nest.1.0.join('') %]
-- expect --
3.14
2.718

-- test list of hashes --
[% # define some initial data
   people   => [ 
     { id => 'tom',   name => 'Tom'     },
     { id => 'dick',  name => 'Richard' },
     { id => 'larry', name => 'Larry'   },
   ]
-%]
[% folk = [] -%]
[% folk.push("<a href=\"${person.id}.html\">$person.name</a>")
       FOREACH person = people.sort('name') -%]
[% folk.join(",\n") -%]
-- expect --
<a href="larry.html">Larry</a>,
<a href="dick.html">Richard</a>,
<a href="tom.html">Tom</a>

-- test grep join --
[% data.grep('r').join(', ') %]
-- expect --
romeo, sierra, foxtrot

-- test anchored grep join --
[% data.grep('^r').join(', ') %]
-- expect --
romeo
