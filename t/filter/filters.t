#============================================================= -*-perl-*-
#
# t/filter/filters.t
#
# Test the Template::TT2::Filters module
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
# TODO: integrate the rest of the tests following the -- stop -- marker
# 
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Template::TT2::Test
    tests => 7,
    debug => 'Template::TT2::Filters',
    args  => \@ARGV;

use Badger::Filesystem '$Bin Dir';
use Template::TT2::Filters;
pass('loaded filters');

#------------------------------------------------------------------------
# hack to allow STDERR to be tied to a variable.
# (I'm really surprised there isn't a standard module which does this)
# UPDATE: there is now... but hey, I've already written the code.
#------------------------------------------------------------------------

package Tie::File2Str;

sub TIEHANDLE {
    my ($class, $textref) = @_;
    bless $textref, $class;
}
sub PRINT {
    my $self = shift;
    $$self .= join('', @_);
}



#------------------------------------------------------------------------
# now for the main event...
#------------------------------------------------------------------------

package main;

# tie STDERR to a variable
my $stderr = '';
#tie(*STDERR, "Tie::File2Str", \$stderr);

my ($a, $b, $c, $d) = qw( alpha bravo charlie delta );
my $vars = { 
    'a'      => $a,
    'b'      => $b,
    'c'      => $c,
    'd'      => $d,
    'list'   => [ $a, $b, $c, $d ],
    'text'   => 'The cat sat on the mat',
    stderr   => sub { $stderr },
    despace  => bless(\&despace, 'anything'),
    widetext => "wide:\x{65e5}\x{672c}\x{8a9e}",
};

my $filters = {
#    'nonfilt'    => 'nonsense',
    'microjive'  => \&microjive,
    'microsloth' => [ \&microsloth, 0 ],
    'censor'     => [ \&censor_factory, 1 ],
    'badfact'    => [ sub { return 'nonsense' }, 1 ],
    'badfilt'    => [ 'rubbish', 1 ],
    'barfilt'    => [ \&barf_up, 1 ],
};


my $tt_default = Template::TT2->new(
    INTERPOLATE => 1, 
    POST_CHOMP  => 1,
    FILTERS     => $filters,
) || die Template->error;

my $tt_eval_perl = Template::TT2->new(
    EVAL_PERL   => 1,
    FILTERS     => $filters,
    BARVAL      => 'some random value',
) || die Template->error;


$tt_eval_perl->context->define_filter('another', \&another, 1);

#tie(*STDERR, "Tie::File2Str", \$stderr);

test_expect(
    vars    => $vars,
    engine  => $tt_default,
    engines => {
        default  => $tt_default,
        evalperl => $tt_eval_perl,
    },
);



#------------------------------------------------------------------------
# custom filter subs 
#------------------------------------------------------------------------

sub microjive {
    my $text = shift;
    $text =~ s/microsoft/The 'Soft/sig;
    $text;
}

sub microsloth {
    my $text = shift;
    $text =~ s/microsoft/Microsloth/sig;
    $text;
}

sub censor_factory {
    my @forbidden = @_;
    return sub {
	my $text = shift;
	foreach my $word (@forbidden) {
	    $text =~ s/$word/[** CENSORED **]/sig;
	}
	return $text;
    }
}

sub barf_up {
    my $context = shift;
    my $foad    = shift || 0;

    if ($foad == 0) {
        return (undef, "barfed");
    }
    elsif ($foad == 1) {
	    return (undef, Template::Exception->new('dead', 'deceased'));
    }
    elsif ($foad == 2) {
	    die "keeled over\n";
    }
    else {
	    die (Template::Exception->new('unwell', 'sick as a parrot'));
    }
}

sub despace {
    my $text = shift;
    $text =~ s/\s+/_/g;
    return $text;
}

sub another {
    my ($context, $n) = @_;
    return sub {
	    my $text = shift;
	    return $text x $n;
    }
}

__DATA__

-- test basic format filter --
[% FILTER format %]
Hello World!
[% END %]
-- expect --
Hello World!

-- test filter aliasing --
[% FILTER comment = format('<!-- %s -->') %]
Hello World!
[% END +%]
[% "Goodbye, cruel World" FILTER comment %]
-- expect --
<!-- Hello World! -->
<!-- Goodbye, cruel World -->

-- test more filter aliasing --
[% "Foo" FILTER test1 = format('+++ %-4s +++') +%]
[% FOREACH item IN [ 'Bar' 'Baz' 'Duz' 'Doze' ] %]
  [% item FILTER test1 +%]
[% END %]
[% "Wiz" FILTER test1 = format("*** %-4s ***") +%]
[% "Waz" FILTER test1 +%]
-- expect --
+++ Foo  +++
  +++ Bar  +++
  +++ Baz  +++
  +++ Duz  +++
  +++ Doze +++
*** Wiz  ***
*** Waz  ***


#------------------------------------------------------------------------
# test custom filters
#------------------------------------------------------------------------

-- test microjive --
[% FILTER microjive %]
The "Halloween Document", leaked to Eric Raymond from an insider
at Microsoft, illustrated Microsoft's strategy of "Embrace,
Extend, Extinguish"
[% END %]
-- expect --
The "Halloween Document", leaked to Eric Raymond from an insider
at The 'Soft, illustrated The 'Soft's strategy of "Embrace,
Extend, Extinguish"

-- test microsloth --
[% FILTER microsloth %]
The "Halloween Document", leaked to Eric Raymond from an insider
at Microsoft, illustrated Microsoft's strategy of "Embrace,
Extend, Extinguish"
[% END %]
-- expect --
The "Halloween Document", leaked to Eric Raymond from an insider
at Microsloth, illustrated Microsloth's strategy of "Embrace,
Extend, Extinguish"

-- test censor --
[% FILTER censor('bottom' 'nipple') %]
At the bottom of the hill, he had to pinch the
nipple to reduce the oil flow.
[% END %]
-- expect --
At the [** CENSORED **] of the hill, he had to pinch the
[** CENSORED **] to reduce the oil flow.




-- stop --


#------------------------------------------------------------------------
# test failures
#------------------------------------------------------------------------
-- test --
[% TRY %]
[% FILTER nonfilt %]
blah blah blah
[% END %]
[% CATCH %]
BZZZT: [% error.type %]: [% error.info %]
[% END %]
-- expect --
BZZZT: filter: invalid FILTER entry for 'nonfilt' (not a CODE ref)

-- test --
[% TRY %]
[% FILTER badfact %]
blah blah blah
[% END %]
[% CATCH %]
BZZZT: [% error.type %]: [% error.info %]
[% END %]
-- expect --
BZZZT: filter: invalid FILTER for 'badfact' (not a CODE ref)

-- test --
[% TRY %]
[% FILTER badfilt %]
blah blah blah
[% END %]
[% CATCH %]
BZZZT: [% error.type %]: [% error.info %]
[% END %]
-- expect --
BZZZT: filter: invalid FILTER entry for 'badfilt' (not a CODE ref)

-- test --
[% TRY;
     "foo" | barfilt;
   CATCH;
     "$error.type: $error.info";
   END
%]
-- expect --
filter: barfed

-- test --
[% TRY;
     "foo" | barfilt(1);
   CATCH;
     "$error.type: $error.info";
   END
%]
-- expect --
dead: deceased

-- test --
[% TRY;
     "foo" | barfilt(2);
   CATCH;
     "$error.type: $error.info";
   END
%]
-- expect --
filter: keeled over

-- test --
[% TRY;
     "foo" | barfilt(3);
   CATCH;
     "$error.type: $error.info";
   END
%]
-- expect --
unwell: sick as a parrot



-- test --
[% percent = '%'
   left    = "[$percent"
   right   = "$percent]"
   dir     = "$left a $right blah blah $left b $right"
%]
[% dir +%]
FILTER [[% dir | eval %]]
FILTER [[% dir | evaltt %]]
-- expect --
[% a %] blah blah [% b %]
FILTER [alpha blah blah bravo]
FILTER [alpha blah blah bravo]

-- test -- 
[% TRY %]
[% dir = "[\% FOREACH a = { 1 2 3 } %\]a: [\% a %\]\n[\% END %\]" %]
[% dir | eval %]
[% CATCH %]
error: [[% error.type %]] [[% error.info %]]
[% END %]
-- expect --
error: [file] [parse error - input text line 1: unexpected token (1)
  [% FOREACH a = { 1 2 3 } %]]


-- test --
nothing
[% TRY;
    '$x = 10; $b = 20; $x + $b' | evalperl;
   CATCH;
     "$error.type: $error.info";
   END
+%]
happening
-- expect --
nothing
perl: EVAL_PERL is not set
happening


-- test --
-- use evalperl --
[% FILTER evalperl %]
   $a = 10;
   $b = 20;
   $stash->{ foo } = $a + $b;
   $stash->{ bar } = $context->config->{ BARVAL };
   "all done"
[% END +%]
foo: [% foo +%]
bar: [% bar %]
-- expect --
all done
foo: 30
bar: some random value


-- test --
[% PERL %]
# static filter subroutine
$Template::Filters::FILTERS->{ bar } = sub {
    my $text = shift; 
    $text =~ s/^/bar: /gm;
    return $text;
};
[% END -%]
[% FILTER bar -%]
The cat sat on the mat
The dog sat on the log
[% END %]
-- expect --
bar: The cat sat on the mat
bar: The dog sat on the log

-- test --
[% PERL %]
# dynamic filter factory
$Template::Filters::FILTERS->{ baz } = [
    sub {
	my $context = shift;
	my $word = shift || 'baz';
	return sub {
	    my $text = shift; 
            $text =~ s/^/$word: /gm;
	    return $text;
	};
    }, 1 ];
[% END -%]
[% FILTER baz -%]
The cat sat on the mat
The dog sat on the log
[% END %]
[% FILTER baz('wiz') -%]
The cat sat on the mat
The dog sat on the log
[% END %]

-- expect --
baz: The cat sat on the mat
baz: The dog sat on the log

wiz: The cat sat on the mat
wiz: The dog sat on the log


-- test --
-- use evalperl --
[% PERL %]
$stash->set('merlyn', bless \&merlyn1, 'ttfilter');
sub merlyn1 {
    my $text = shift || '<no text>';
    $text =~ s/stone/henge/g;
    return $text;
}
[% END -%]
[% FILTER $merlyn -%]
Let him who is without sin cast the first stone.
[% END %]
-- expect --
Let him who is without sin cast the first henge.

-- test --
-- use evalperl --
[% PERL %]
$stash->set('merlyn', sub { \&merlyn2 });
sub merlyn2 {
    my $text = shift || '<no text>';
    $text =~ s/stone/henge/g;
    return $text;
}
[% END -%]
[% FILTER $merlyn -%]
Let him who is without sin cast the first stone.
[% END %]
-- expect --
Let him who is without sin cast the first henge.

-- test --
[% myfilter = 'html' -%]
[% FILTER $myfilter -%]
<html>
[% END %]
-- expect --
&lt;html&gt;

-- test --
[% FILTER $despace -%]
blah blah blah
[%- END %]
-- expect --
blah_blah_blah

-- test --
-- use evalperl --
[% PERL %]
$context->filter(\&newfilt, undef, 'myfilter');
sub newfilt {
    my $text = shift;
    $text =~ s/\s+/=/g;
    return $text;
}
[% END -%]
[% FILTER myfilter -%]
This is a test
[%- END %]
-- expect --
This=is=a=test

-- test --
[% PERL %]
$context->define_filter('xfilter', \&xfilter);
sub xfilter {
    my $text = shift;
    $text =~ s/\s+/X/g;
    return $text;
}
[% END -%]
[% FILTER xfilter -%]
blah blah blah
[%- END %]
-- expect --
blahXblahXblah


-- test --
[% FILTER another(3) -%]
foo bar baz
[% END %]
-- expect --
foo bar baz
foo bar baz
foo bar baz

-- test --
[% '$stash->{ a } = 25' FILTER evalperl %]
[% a %]
-- expect --
25
25

-- test --
[% '$stash->{ a } = 25' FILTER perl %]
[% a %]
-- expect --
25
25
