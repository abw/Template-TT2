#============================================================= -*-perl-*-
#
# t/language/directive.t
#
# Test basic directive layout and processing options.
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
    tests => 35,
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;

use Badger::Filesystem '$Bin Dir';
use constant ENGINE => 'Template::TT2';

my $tdir = Dir($Bin, 'templates')->must_exist;

my $engines = {
    tt   => ENGINE->new(),
    pre  => ENGINE->new( PRE_CHOMP => 1 ),
    post => ENGINE->new( POST_CHOMP => 1 ),
    trim => ENGINE->new( INCLUDE_PATH => $tdir, TRIM => 1 ),
};

test_expect(
    vars    => callsign,
    engine  => $engines->{ tt },
    engines => $engines,
);


__DATA__
#------------------------------------------------------------------------
# basic directives
#------------------------------------------------------------------------
-- test whitespace in tags --
[% a %]
[%a%]
-- expect --
alpha
alpha

-- test whitespace before tags --
pre [% a %]
pre[% a %]
-- expect --
pre alpha
prealpha

-- test whitespace after tags --
[% a %] post
[% a %]post
-- expect --
alpha post
alphapost

-- test whitespace around tags --
pre [% a %] post
pre[% a %]post
-- expect --
pre alpha post
prealphapost

-- test touching tags --
[% a %][%b%][% c %]
-- expect --
alphabravocharlie

-- test newlines in tags --
[% 
a %][%b
%][%
c
%][%
         d
%]
-- expect --
alphabravocharliedelta


#------------------------------------------------------------------------
# comments
#------------------------------------------------------------------------
-- test comment tag --
[%# this is a comment which should
    be ignored in totality
%]hello world
-- expect --
hello world

-- test one line comment -- 
[% # this is a one-line comment
   a
%]
-- expect --
alpha

-- test two line comment -- 
[% # this is a two-line comment
   a =
   # here's the next line
   b
-%]
[% a %]
-- expect --
bravo

-- test comment on end of lines --
[% a = c   # this is a comment on the end of the line
   b = d   # so is this
-%]
a: [% a %]
b: [% b %]
-- expect --
a: charlie
b: delta

-- test comment inline tag --
[% a # this is a comment %]
-- expect --
alpha


#------------------------------------------------------------------------
# manual chomping
#------------------------------------------------------------------------

-- test no chomping --
[% a %]
[% b %]
-- expect --
alpha
bravo

-- test explicit post chomp --
[% a -%]
[% b %]
-- expect --
alphabravo

-- test post chomp only newline --
[% a -%]
     [% b %]
-- expect --
alpha     bravo

-- test explicit pre chomp --
[% a %]
[%- b %]
-- expect --
alphabravo

-- test pre chomp whitespace and newline --
[% a %]
     [%- b %]
-- expect --
alphabravo

-- test start/end no chomp --
start
[% a %]
[% b %]
end
-- expect --
start
alpha
bravo
end

-- test start pre chomp --
start
[%- a %]
[% b -%]
end
-- expect --
startalpha
bravoend

-- test start mid post chomp --
start
[%- a -%]
[% b -%]
end
-- expect --
startalphabravoend

-- test start mid pre chomp--
start
[%- a %]
[%- b -%]
end
-- expect --
startalphabravoend


#------------------------------------------------------------------------
# PRE_CHOMP enabled 
#------------------------------------------------------------------------

-- test pre chomp enabled --
-- use pre --
start
[% a %]
mid
[% b %]
end
-- expect --
startalpha
midbravo
end

-- test chompy --
start
     [% a %]
mid
	[% b %]
end
-- expect --
startalpha
midbravo
end

-- test chompy chompy --
start
[%+ a %]
mid
[% b %]
end
-- expect --
start
alpha
midbravo
end

-- test yum yum --
start
   [%+ a %]
mid
[% b %]
end
-- expect --
start
   alpha
midbravo
end

-- test munchy munchy--
start
   [%- a %]
mid
   [%- b %]
end
-- expect --
startalpha
midbravo
end


#------------------------------------------------------------------------
# POST_CHOMP enabled 
#------------------------------------------------------------------------

-- test post chomp enabled --
-- use post --
start
[% a %]
mid
[% b %]
end
-- expect --
start
alphamid
bravoend

-- test post chomp munchy --
start
     [% a %]
mid
	[% b %]        
end
-- expect --
start
     alphamid
	bravoend

-- test gobble gobble --
start
[% a +%]
mid
[% b %]
end
-- expect --
start
alpha
mid
bravoend

-- test wibble --
start
[% a +%]   
[% b +%]
end
-- expect --
start
alpha   
bravo
end

-- test wobble --
start
[% a -%]
mid
[% b -%]
end
-- expect --
start
alphamid
bravoend


#------------------------------------------------------------------------
# TRIM enabled
#------------------------------------------------------------------------
-- test trim enabled --
-- use trim --

[% INCLUDE trim_me %]


-- expect --
I am a template element file which will get TRIMmed


-- test trim block --
[% BLOCK foo %]

this is block foo

[% END -%]

[% BLOCK bar %]

this is block bar

[% END %]

[% INCLUDE foo %]
[% INCLUDE bar %]
end
-- expect --
this is block foo
this is block bar
end


-- test trim more blocks --
<foo>[% PROCESS foo %]</foo>
<bar>[% PROCESS bar %]</bar>
[% BLOCK foo %]

this is block foo

[% END -%]
[% BLOCK bar %]

this is block bar

[% END -%]
end
-- expect --
<foo>this is block foo</foo>
<bar>this is block bar</bar>
end


-- test trim words --
[% r; r = s; "-"; r %].
-- expect --
romeo-sierra.

-- test IF ELSIF ELSE END --
[% IF a; b; ELSIF c; d; ELSE; s; END %]
-- expect --
bravo

