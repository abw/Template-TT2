#!/usr/bin/perl -w                                         # -*- perl -*-

use strict;
use warnings;
use 5.006;
use ExtUtils::MakeMaker;
use Config;

my %opts = (
    'NAME'         => 'Template-TT2',
    'VERSION_FROM' => 'lib/Template/TT2.pm',
#    'EXE_FILES'    => [ 'bin/tpage', 'bin/ttree' ],
    'PMLIBDIRS'    => [ 'lib' ], 
    'DIR'          => ['xs'],
    'PREREQ_PM'    => { 
#        AppConfig  => 1.56,
        Badger     => 0.04,
    },
    'dist'         => {
        'COMPRESS' => 'gzip',
        'SUFFIX'   => 'gz',
    },
    'test'         => {
        'TESTS'    => join(' ', map { glob } qw( t/*/*.t )),
    },
);

our $MAKE = $Config{'make'}; 

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

