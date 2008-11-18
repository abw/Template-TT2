#============================================================= -*-perl-*-
#
# t/filter/output.t
#
# Test the various filters that redirect output
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
    tests => 5,
    debug => 'Template::TT2::Filters',
    args  => \@ARGV;

use Badger::Filesystem '$Bin Dir';
my $tmp = Dir($Bin, 'tmp')->must_exist(1);

#------------------------------------------------------------------------
# class to tie a file handle to a variable.
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

my $filename = 'evidence';
my $outfile  = $tmp->file($filename);
$outfile->delete if $outfile->exists;

my ($stdout, $stderr) = ('') x 2;
my $vars = { 
    tmp        => $tmp,
    filename   => $filename,
    file       => $outfile,
    stdout     => sub { $stdout },
    stderr     => sub { $stderr },
    tie_stdout => sub {
        tie(*STDOUT, "Tie::File2Str", \$stdout);
    },
    tie_stderr => sub {
        tie(*STDERR, "Tie::File2Str", \$stderr);
    },
    untie_stdout => sub { 
        no warnings 'untie';
        untie *STDOUT;
    },
    untie_stderr => sub { 
        no warnings 'untie';
        untie *STDERR;
    },
};

test_expect( 
    vars   => $vars,
    config => {
        OUTPUT_PATH => $tmp->path,
    },
    engines => {
        no_output => Template::TT2->new( OUTPUT_PATH => 0 )
    },
);

__DATA__

-- test Who broke the lawnmower? --
[% CALL tie_stdout;
   'Who broke the lawnmower?' | stdout;
   CALL untie_stdout
-%]
stdout: [% stdout %]
-- expect --
stdout: Who broke the lawnmower?

-- test Your badger broke the lawnmower --
[% CALL tie_stderr; 
   'Your badger broke the lawnmower' | stderr;
   CALL untie_stderr 
-%]
stderr: [% stderr %]
-- expect --
stderr: Your badger broke the lawnmower

-- test He drove it into a tree --
[% FILTER redirect(filename) -%]
The badger drove the lawnmower into a tree.
Witnesses say he had been drinking.
[% END -%]
file exists: [% file.exists ? 'yes' : 'no' %]
-- expect --
file exists: yes

-- test He had been drinking --
[% file.text %]
-- expect --
The badger drove the lawnmower into a tree.
Witnesses say he had been drinking.

-- test No more lawnmower frolics --
-- use no_output --
[% TRY; 
     FILTER redirect(filename) -%]
He is not allowed to use the lawnmower any more
[%   END;
   CATCH; 
     error;
   END;
-%]
-- expect --
redirect error - Cannot create filesystem output - OUTPUT_PATH is disabled
