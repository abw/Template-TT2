#============================================================= -*-perl-*-
#
# t/directive/stop.t
#
# Test the STOP directive.
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
    tests   => 7,
    debug   => 'Template::TT2::Parser Badger::Base',
    args    => \@ARGV;

use constant 
    ENGINE => 'Template::TT2';

use Template::TT2::Constants 'TT2_EXCEPTION';
use Template::TT2;

#$Template::Parser::DEBUG = 1;
$DEBUG = 1;

my $ttblocks = {
    header => sub { "This is the header\n" },
    footer => sub { "This is the footer\n" },
    halt1  => sub { die TT2_EXCEPTION->new( type => 'stop', info => 'big error' ) },
};
my $ttvars = {
    halt   => sub { die TT2_EXCEPTION->new( type => 'stop', info => 'big error' ) },
};
    
my $ttbare = ENGINE->new(BLOCKS => $ttblocks);
my $ttwrap = ENGINE->new({
    PRE_PROCESS  => 'header',
    POST_PROCESS => 'footer',
    BLOCKS       => $ttblocks,
});

my $engines = {
    bare    => $ttbare,
    wrapped => $ttwrap,
};

test_expect(
    vars    => $ttvars,
    engine  => $engines->{ bare },
    engines => $engines,
);

__END__

-- test STOP --
This is some text
[% STOP %]
More text
-- expect --
This is some text

-- test halt --
This is some text
[% halt %]
More text
-- expect --
This is some text

-- test INCLUDE halt1 --
This is some text
[% INCLUDE halt1 %]
More text
-- expect --
This is some text

-- test myblock1 --
This is some text
[% INCLUDE myblock1 %]
More text
[% BLOCK myblock1 -%]
This is myblock1
[% STOP %]
more of myblock1
[% END %]
-- expect --
This is some text
This is myblock1

-- test myblock2 --
This is some text
[% INCLUDE myblock2 %]
More text
[% BLOCK myblock2 -%]
This is myblock2
[% halt %]
more of myblock2
[% END %]
-- expect --
This is some text
This is myblock2


#------------------------------------------------------------------------
# ensure 'stop' exceptions get ignored by TRY...END blocks
#------------------------------------------------------------------------
-- test TRY STOP --
before
[% TRY -%]
trying
[% STOP -%]
tried
[% CATCH -%]
caught [[% error.type %]] - [% error.info %]
[% END %]
after

-- expect --
before
trying


#------------------------------------------------------------------------
# ensure PRE_PROCESS and POST_PROCESS templates get added with STOP
#------------------------------------------------------------------------

-- test PRE_PROCESS / POST_PROCESS --
-- use wrapped --
This is some text
[% STOP %]
More text
-- expect --
This is the header
This is some text
This is the footer

