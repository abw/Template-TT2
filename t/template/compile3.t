#============================================================= -*-perl-*-
#
# t/template/compile3.t
#
# Third test in the compile<n>.t trilogy.  Checks that modifications
# to a source template result in a re-compilation of the template.
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
    tests => 14,
    debug => 'Template::TT2::Templates',
    args  => \@ARGV;

use File::Copy;
use Template::TT2;
use constant ENGINE => 'Template::TT2';

use Badger::Filesystem '$Bin Dir';
my $tdir   = Dir($Bin, 'templates', 'compile');
my $config = {
    POST_CHOMP   => 1,
    INCLUDE_PATH => $tdir,
    COMPILE_EXT  => '.ttc',
};

# test process fails when EVAL_PERL not set
my $tt = ENGINE->new($config);
my $out;
ok( ! $tt->try( process => "evalperl", { }, \$out ), 'evalperl failed' );
is( $tt->error->type, 'perl', 'got perl error' );
is( $tt->error->info, 'EVAL_PERL not set', 'EVAL_PERL not not' );

# ensure we can run compiled templates without loading parser
# (fix for "Can't locate object method "TIEHANDLE" via package 
# Template::String..." bug)
$config->{ EVAL_PERL } = 1;
$tt = ENGINE->new($config);
ok( $tt->process("evalperl", { }, \$out), 'processed with EVAL_PERL' );

my $file = $tdir->file('complex');

# check compiled template file exists and grab modification time
ok( $file->exists, "$file exists" );
my $mod = $file->modified;

# save copy of the source file because we're going to try to break it
copy($file, "$file.org") || die "failed to copy $file to $file.org\n";

# sleep for a couple of seconds to ensure clock has ticked
pass('Taking a nap...');
sleep(2);
pass('Woken up');

# append a harmless newline to the end of the source file to change
# its modification time
append_file("\n");

# define 'bust_it' to append a lone "[% TRY %]" onto the end of the 
# source file to cause re-compilation to fail
my $replace = {
    bust_it   => sub { append_file('[% TRY %]') },
    near_line => sub {
        my ($warning, $n) = @_;
        if ($warning =~ s/line (\d+)/line ${n}ish/) {
            my $diff = abs($1 - $n);
            if ($diff < 4) {
                # That's close enough for rock'n'roll.  The line
                # number reported appears to vary from one version of
                # Perl to another
                return $warning;
            }
            else {
                return $warning . " (where 'ish' means $diff!)";
            }
        }
        else {
            return "no idea what line number that is\n";
        }
    }
};

test_expect(
    vars   => $replace,
    config => $config,
);

$file->stat;
ok( $file->modified > $mod, 'file has been modified' );

# restore original source file
copy("$file.org", $file) || die "failed to copy $file.org to $file\n";

#------------------------------------------------------------------------

sub append_file {
    pass('Drifting off to snuggle-bunny land...');
    sleep(2);     # ensure file time stamps are different
    pass('Awoke with a start');
    $file->append(@_);
}

#------------------------------------------------------------------------

__DATA__

-- test complex first --
[% META author => 'albert' version => 'emc2'  %]
[% INCLUDE complex %]
-- expect --
This is the header, title: Yet Another Template Test
This is a more complex file which includes some BLOCK definitions
This is the footer, author: albert, version: emc2
- 3 - 2 - 1 

-- test complex broken --
[%# we want to break 'compile' to check that errors get reported -%]
[% CALL bust_it -%]
[% TRY; INCLUDE complex; CATCH; near_line("$error", 18); END %]
-- expect --
parse error - complex line 18ish: unexpected end of input

-- stop --

NOTE: the above test returns a nested exception in TTv2:
  file error - parse error - complex line 18ish: unexpected end of input
