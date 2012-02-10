#============================================================= -*-perl-*-
#
# t/template/fileline.t
#
# Test the reporting of template file and line number in errors.
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
# NOTE: the file: in the second test was previously test/lib/warning
#
#========================================================================

use Badger
    lib         => '../../lib ../../blib/lib ../../blib/arch',
    Filesystem  => 'Bin';

use Template::TT2::Test
    tests => 4,
    debug => 'Template::TT2::Parser',
    args  => \@ARGV;

use Template::TT2::Document;
use constant ENGINE => 'Template::TT2';
my $dir = Bin->dir('templates', 'fileline')->must_exist;

my $warning;
local $SIG{__WARN__} = sub {
    $warning = shift;
};

my $vars = {
    warning => sub { return $warning },
    file => sub {
        $warning =~ /at (.*?) line/;
        my $file = $1;
        # The error returned includes a reference to the eval string
        # e.g. ' ...at (eval 1) line 1'.  On some platforms (notably
        # FreeBSD and variants like OSX), the (eval $n) part contains
        # a different number, presumably because it has previously 
        # performed additional string evals.  It's not important to 
        # the success or failure of the test, so we delete it.
        # Thanks to Andreas Koenig for identifying the problem.
        # http://rt.cpan.org/Public/Bug/Display.html?id=20807
        $file =~ s/eval\s+\d+/eval/;

        # handle backslashes on Win32 by converting them to forward slashes
        $file =~ s!\\!/!g if $^O eq 'MSWin32';
        return $file;
    },
    line => sub {
        $warning =~ /line (\d*)/;
        return $1;
    },
    warn => sub {
        $warning =~ /(.*?) at /;
        return $1;
    },
};

my $tt2err  = ENGINE->new({ INCLUDE_PATH => $dir });
my $tt2not  = ENGINE->new({ INCLUDE_PATH => $dir, FILE_INFO => 0 });
my $engines = {
    err => $tt2err,
    not => $tt2not,
};

test_expect(
    vars    => $vars,
    engine  => $engines->{ err },
    engines => $engines,
);


__DATA__
-- test hello --
[% place = 'World' -%]
Hello [% place %]
[% a = a + 1 -%]
file: [% file %]
line: [% line %]
warn: [% warn %]
-- expect --
-- process --
Hello World
file: input text
line: 3
warn: Argument "" isn't numeric in addition (+)

-- test warning --
[% INCLUDE warning -%]
file: [% file.chunk(-16).last %]
line: [% line %]
warn: [% warn %]
-- expect --
Hello
World
file: warning
line: 2
warn: Argument "" isn't numeric in addition (+)

-- test not warning --
-- use not --
[% INCLUDE warning -%]
file: [% file.chunk(-16).last %]
line: [% line %]
warn: [% warn %]
-- expect --
Hello
World
file: (eval)
line: 12
warn: Argument "" isn't numeric in addition (+)

-- test chomp --
[% TRY; 
     INCLUDE chomp; 
   CATCH; 
     error; 
   END 
%]
-- expect --
parse error - chomp line 6: unexpected token (END)
  [% END %]
