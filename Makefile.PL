#!/usr/bin/perl -w                                         # -*- perl -*-

use strict;
use warnings;
use 5.006;
use ExtUtils::MakeMaker;
use Config;

our $MAKE  = $Config{'make'}; 
our $TT_XS = 1;
our (%config, %ttconfig);

# read command line args putting TT_* into $ttconfig and
# everything else (regular Makefile.PL args, e.g. PREFIX)
# goes into $config

while (@ARGV) {
    my $arg = shift @ARGV;
    print "[$arg]\n";
    if ($arg =~ /^-*no_?xs$/i) {
        $TT_XS = 0;
    }
    else {
        my ($k, $v) = split(/=/, $arg, 2);
        $config{ $k } = $v || 0;
    }
};

if ($TT_XS) {
print <<EOF;
The XS module(s) will be included in the build.
Use the --no_xs option to disable them.
e.g. perl Makefile.PL --no_xs
EOF
}
else {
print <<EOF;
The XS module(s) will not be included in the build.
EOF
}


my %opts = (
    'NAME'         => 'Template-TT2',
    'VERSION_FROM' => 'lib/Template/TT2.pm',
#   'EXE_FILES'    => [ 'bin/tpage', 'bin/ttree' ],
    'PMLIBDIRS'    => [ 'lib' ], 
    'DIR'          => [ ],
    'PREREQ_PM'    => { 
#       AppConfig  => 1.56,
        Badger     => 0.09,
    },
    'dist'         => {
        'COMPRESS' => 'gzip',
        'SUFFIX'   => 'gz',
    },
    'test'         => {
        'TESTS'    => join(' ', map { glob } qw( t/*/*.t )),
    },
);

push @{ $opts{'DIR'} }, 'xs' if $TT_XS;



# Handle dev versions in our check
my $mmv = $ExtUtils::MakeMaker::VERSION;
$mmv =~ s/\_.+//;

if ($mmv >= 5.43) {
    $opts{ AUTHOR   } = 'Andy Wardley <abw@wardley.org>';
    $opts{ ABSTRACT } = 'comprehensive template processing system',
}

if ($ExtUtils::MakeMaker::VERSION ge '6.30_00') {
    $opts{'LICENSE' } = 'perl';
} 

WriteMakefile( %opts );

    print <<EOF;

Configuration complete.  You should now run '$MAKE', '$MAKE test' and 
then '$MAKE install'.   See the README file for further information.
EOF

