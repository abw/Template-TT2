#============================================================= -*-perl-*-
#
# t/template/unicode.t
#
# Test the handling of Unicode text in templates.
#
# Run with -h option for help.
#
# Written by Mark Fowler <mark@twoshortplanks.com> for Template v2, 
# adapted by Andy Wardley for Template-TT2
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
# TODO: clean up temporary file
#
#========================================================================

use Badger
    lib         => '../../lib ../../blib/lib ../../blib/arch',
    Filesystem  => 'Bin VFS';
use Template::TT2;
use Template::TT2::Constants 'UNICODE MSWIN32';
use Template::TT2::Test
    debug => 'Template::TT2::Store Template::TT2::Templates',
    args  => \@ARGV;
use constant 
    ENGINE => 'Template::TT2';
use bytes;

if (UNICODE) {
    plan(30);
}
else {
    skip_all("Insufficient Unicode support in this version of Perl");    
}

# temporary directory for cache files
my $tmp = Bin->dir('tmp')->must_exist(1);
my $vfs = VFS->new( root => $tmp );

# This is 'moose...' (with slashes in the 'o's them, and the '...' as one char).
my $moose = "m\x{f8}\x{f8}se\x{2026}";

# extension for compiled templates
my $ext = '.ttc';

# create some templates in various encodings to be 100% sure they contain
# the right text
my $encodings = {
    'UTF-8'    => "\x{ef}\x{bb}\x{bf}m\x{c3}\x{b8}\x{c3}\x{b8}se\x{e2}\x{80}\x{a6}",
    'UTF-16BE' => "\x{fe}\x{ff}\x{0}m\x{0}\x{f8}\x{0}\x{f8}\x{0}s\x{0}e &",
    'UTF-16LE' => "\x{ff}\x{fe}m\x{0}\x{f8}\x{0}\x{f8}\x{0}s\x{0}e\x{0}& ",
    'UTF-32BE' => "\x{0}\x{0}\x{fe}\x{ff}\x{0}\x{0}\x{0}m\x{0}\x{0}\x{0}\x{f8}\x{0}\x{0}\x{0}\x{f8}\x{0}\x{0}\x{0}s\x{0}\x{0}\x{0}e\x{0}\x{0} &",
    'UTF-32LE' => "\x{ff}\x{fe}\x{0}\x{0}m\x{0}\x{0}\x{0}\x{f8}\x{0}\x{0}\x{0}\x{f8}\x{0}\x{0}\x{0}s\x{0}\x{0}\x{0}e\x{0}\x{0}\x{0}& \x{0}\x{0}",
};

# deleted any previously compiled templates
foreach my $encoding (keys %$encodings) {
    my $uri = $tmp;
    $uri =~ s[:][]g if MSWIN32;
    my $file = $vfs->file($uri, $encoding . $ext);
    if ($file->exists) {
        ok( $file->delete, 'deleted previously compiled template for ' . $file->name );
    }
    else {
        pass("no previously compiled template for " . $file->name );
    }
}

# write the above encoding into template files in tmp dir
foreach my $encoding (keys %$encodings) {
    my $file = $tmp->file($encoding);
    my $fh   = $file->write;
    $fh->binmode(':raw');
    $fh->print($encodings->{ $encoding });
    $fh->close;
}

# run through twice, the second time around should have the templates 
# cached in memory.
my $tta = engine($tmp);
test_encodings("first try",        $tta, $encodings, $moose);
test_encodings("cached in memory", $tta, $encodings, $moose);

# now we test everything again to see if the compiled templates
# were written in a consistent state and read back again OK
my $ttb = engine($tmp);
test_encodings("compiled",               $ttb, $encodings, $moose);
test_encodings("compiled and in memory", $ttb, $encodings, $moose);

# at the end of it, we should have a compiled .ttc file in the tmp
# directory for each encoding
foreach my $encoding (keys %$encodings) {
    my $uri = $tmp;
    $uri =~ s[:][]g if MSWIN32;
    my $file = $vfs->file($uri, $encoding . $ext);
    ok( $file->exists, "$encoding$ext is compiled" );
    $file->delete;
}

sub engine {
    my $dir = shift;
    ENGINE->new( 
        INCLUDE_PATH => $dir,
        COMPILE_DIR  => $dir,
        COMPILE_EXT  => $ext,
    );
}

sub test_encodings {
    my ($name, $tt, $encodings, $expect) = @_;

    foreach my $encoding (keys %$encodings) {
        my $output;
        $tt->process($encoding, {}, \$output)
            or $output = $tt->error;
        is(reasciify($output), reasciify($expect), "$name - $encoding");
    }
}


#------------------------------------------------------------------------
# reascify($string)
#
# escape all the high and low chars to \x{..} sequences
#------------------------------------------------------------------------

sub reasciify {
    my $string = shift;
    $string = join '', map {
        my $ord = ord($_);
        ($ord > 127 || ($ord < 32 && $ord != 10))
            ? sprintf '\x{%x}', $ord
            : $_
        } split //, $string;
    return $string;
}


