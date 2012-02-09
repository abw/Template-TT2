#============================================================= -*-perl-*-
#
# t/filter/eval.t
#
# Test the filter that evaluate TT and Perl code.
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
    lib     => '../../lib ../../blib/arch';

use Template::TT2::Test
    debug   => 'Template::TT2::Filters Badger::Factory',
    args    => \@ARGV,
    tests   => 12;

test_expect(
    engines => {
        evalperl => Template::TT2->new( EVAL_PERL => 1 ),
    },
);


__DATA__
-- test eval and evaltt --
[% a       = 'alpha',
   b       = 'bravo'
   percent = '%'
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

-- test eval syntax error -- 
[% TRY %]
[% dir = "[\% FOREACH a = { 1 2 3 } %\]a: [\% a %\]\n[\% END %\]" %]
[% dir | eval %]
[% CATCH %]
error: [[% error.type %]] [[% error.info %]]
[% END %]
-- expect --
error: [parse] [input text line 1: unexpected token (1)
  [% FOREACH a = { 1 2 3 } %]]


-- test EVAL_PERL not set --
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


-- test evalperl --
-- use evalperl --
[% baz = 'some random value';
   FILTER evalperl %]
   $a = 10;
   $b = 20;
   $stash->{ foo } = $a + $b;
   $stash->{ bar } = $stash->get('baz');
   "all done"
[% END +%]
foo: [% foo +%]
bar: [% bar %]
-- expect --
all done
foo: 30
bar: some random value


-- test define static filter in perl code --
[% PERL %]
# static filter subroutine
$context->define_filter( bar => sub {
    my $text = shift; 
    $text =~ s/^/bar: /gm;
    return $text;
});
[% END -%]
[% FILTER bar -%]
The cat sat on the mat
The dog sat on the log
[% END %]
-- expect --
bar: The cat sat on the mat
bar: The dog sat on the log

-- test define dynamic filter in perl code --
[% PERL %]
# dynamic filter factory
$context->define_filter( baz => [
    sub {
	    my $context = shift;
	    my $word = shift || 'baz';
	    return sub {
	        my $text = shift; 
            $text =~ s/^/$word: /gm;
	        return $text;
	    };
    }, 1 ]);
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




-- test sub returning filter object --
-- use evalperl --
[% PERL %]
$stash->set('merlyn', bless \&merlyn1, 'Template::TT2::Filter');
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


-- test sub returning filter sub --
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


-- test defining filter alias via filter() --
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

-- test defining filter via define_filter() --
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


-- test evalperl side-effect --
[% '$stash->{ a } = 25' FILTER evalperl %]
[% a %]
-- expect --
25
25

-- test perl side-effect --
[% '$stash->{ a } = 25' FILTER perl %]
[% a %]
-- expect --
25
25

