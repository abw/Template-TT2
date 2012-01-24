#============================================================= -*-perl-*-
#
# t/template/compile3.t
#
# Third test in the compile<n>.t trilogy.  Checks that modifications
# to a source template result in a re-compilation of the template.
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
    lib         => '../../lib',
    Filesystem  => 'Bin Dir';

use Template::TT2::Test
    tests => 14,
    debug => 'Template::TT2::Templates',
    args  => \@ARGV;

use constant 
    ENGINE => 'Template::TT2';

#use File::Copy;

my $tdir   = Bin->dir('templates', 'compile');
my $config = {
    POST_CHOMP   => 1,
    INCLUDE_PATH => $tdir,
    COMPILE_EXT  => '.ttc',
    THROW        => 1,
};

my $COUNT = 1;


# test process fails when EVAL_PERL not set
my $tt = ENGINE->new($config);
my $out;
ok( ! $tt->try( process => "evalperl", { }, \$out ), 'evalperl failed' );
is( $tt->error->type, 'perl', 'got perl error' );
is( $tt->error->info, 'EVAL_PERL not set', 'EVAL_PERL not not' );

# test it works when EVAL_PERL is set
$config->{ EVAL_PERL } = 1;
$tt = ENGINE->new($config);
ok( $tt->process("evalperl", { }, \$out), 'processed with EVAL_PERL' );


my $file    = $tdir->file('complex');
my $backup  = $tdir->file('complex.org');

# check compiled template file exists and grab modification time
ok( $file->exists, "$file exists" );
my $mod = $file->modified;

# save copy of the source file because we're going to try to break it
#copy($file, "$file.org") || die "failed to copy $file to $file.org\n";
$file->copy_to($backup) || die "failed to copy $file to $backup\n";

# sleep for a couple of seconds to ensure clock has ticked
pass('Taking a nap...');
sleep(2);
pass('Woken up');

# append a harmless newline to the end of the source file to change
# its modification time - this should force it to be reloaded
append_file("\n");

my $replace = {
    # define 'bust_it' to append a lone "[% TRY %]" onto the end of the 
    # source file to cause re-compilation to fail
    bust_it   => sub { 
        append_file('[% TRY %]') 
    },
    # The error line number reported varies from one version of Perl to 
    # another.  This function checks it's close enough (+/- 4);
    near_line => sub {
        my ($warning, $n) = @_;
        if ($warning =~ s/line (\d+)/line ${n}ish/) {
            my $diff = abs($1 - $n);
            if ($diff < 4) {
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

$file->restat;
ok( $file->modified->after($mod), 'file has been modified' );

# restore original source file
$backup->copy_to($file) || die "failed to copy $backup to $file\n";

#------------------------------------------------------------------------

sub append_file {
    pass('Drifting off to snuggle-bunny land... #' . $COUNT);
    sleep(2);     # ensure file time stamps are different
    pass('Awoke with a start! #' . $COUNT++);
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
