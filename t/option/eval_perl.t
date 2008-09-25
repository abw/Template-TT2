#============================================================= -*-perl-*-
#
# t/option/eval_perl.t
#
# Test the evaluation of PERL and RAWPERL blocks.
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
    tests => 9,
    debug => 'Template::TT2::Templates',
    args  => \@ARGV;

use Template::TT2;
use Badger::Filesystem '$Bin Dir';
use constant ENGINE => 'Template::TT2';

my $tdir = Dir($Bin, 'templates', 'eval_perl')->must_exist;

my $tt_no_perl = ENGINE->new({ 
    INTERPOLATE  => 1, 
    POST_CHOMP   => 1,
    EVAL_PERL    => 0,
    INCLUDE_PATH => $tdir,
});

my $tt_do_perl = ENGINE->new({ 
    INTERPOLATE  => 1, 
    POST_CHOMP   => 1,
    EVAL_PERL    => 1,
    INCLUDE_PATH => $tdir,
});

my $engines = {
    no_perl => $tt_no_perl, 
    do_perl => $tt_do_perl,
};

test_expect(
    vars    => callsign,
    engine  => $engines->{ no_perl },
    engines => $engines,
);

__DATA__

-- test PERL with no EVAL_PERL --
[% META 
   author  = 'Andy Wardley'
   title   = 'Test Template $foo #6'
   version = 1.23
%]
[% TRY %]
[% PERL %]
    my $output = "author: [% template.author %]\n";
    $stash->set('a', 'The cat sat on the mat');
    $output .= "more perl generated output\n";
    print $output;
[% END %]
[% CATCH %]
Not allowed: [% error +%]
[% END %]
a: [% a +%]
a: $a
-- expect --
Not allowed: perl error - EVAL_PERL not set
a: alpha
a: alpha

-- test RAWPERL with no EVAL_PERL --
[% TRY %]
[% RAWPERL %]
$output .= "The cat sat on the mouse mat\n";
$stash->set('b', 'The cat sat where?');
[% END %]
[% CATCH %]
Still not allowed: [% error +%]
[% END %]
b: [% b +%]
b: $b
-- expect --
Still not allowed: perl error - EVAL_PERL not set
b: bravo
b: bravo

-- test PERL block syntax is loose --
[% TRY %]
nothing
[% PERL %]
We don't care about correct syntax within PERL blocks if EVAL_PERL isn't set.
They're simply ignored.
[% END %]
[% CATCH %]
ERROR: [% error.type %]: [% error.info %]
[% END %]
-- expect --
nothing
ERROR: perl: EVAL_PERL not set

-- test INCLUDE badrawperl --
some stuff
[% TRY %]
[% INCLUDE badrawperl %]
[% CATCH %]
ERROR: [[% error.type %]] [% error.info %]
[% END %]
-- expect --
some stuff
This is some text
ERROR: [perl] EVAL_PERL not set

-- test badrawperl with EVAL_PERL --
-- use do_perl --
some stuff
[% TRY %]
[% INCLUDE badrawperl %]
[% CATCH +%]
ERROR: [[% error.type %]]
[% END %]
-- expect --
some stuff
This is some text
more stuff goes here
ERROR: [undef]

-- test PERL block with EVAL_PERL --
-- use do_perl --
[% META author = 'Andy Wardley' %]
[% PERL %]
    my $output = "author: [% template.author %]\n";
    $stash->set('a', 'The cat sat on the mat');
    $output .= "more perl generated output\n";
    print $output;
[% END %]
-- expect --
author: Andy Wardley
more perl generated output

-- test PERL and RAWPERL --
-- use do_perl --
[% META 
   author  = 'Andy Wardley'
   title   = 'Test Template $foo #6'
   version = 3.14
%]
[% PERL %]
    my $output = "author: [% template.author %]\n";
    $stash->set('a', 'The cat sat on the mat');
    $output .= "more perl generated output\n";
    print $output;
[% END %]
a: [% a +%]
a: $a
[% RAWPERL %]
$output .= "The cat sat on the mouse mat\n";
$stash->set('b', 'The cat sat where?');
[% END %]
b: [% b +%]
b: $b
-- expect --
author: Andy Wardley
more perl generated output
a: The cat sat on the mat
a: The cat sat on the mat
The cat sat on the mouse mat
b: The cat sat where?
b: The cat sat where?

-- test PERLOUT --
[% BLOCK foo %]This is block foo[% END %]
[% PERL %]
print $context->include('foo');
print PERLOUT "\nbar\n";
[% END %]
The end
-- expect --
This is block foo
bar
The end

-- test PERL die --
[% TRY %]
   [%- PERL %] die "nothing to live for\n" [% END %]
[% CATCH %]
   error: [% error %]
[% END %]
-- expect --
   error: undef error - nothing to live for



