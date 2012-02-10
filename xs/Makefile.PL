use lib qw( ../lib ./lib );
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'Template::TT2::Stash::XS',
    'C'            => [ qw( Stash.c ) ],
    'XS'           => { 'Stash.xs' => 'Stash.c' },
    'OBJECT'       => 'Stash.o',
    'VERSION_FROM' => '../lib/Template/TT2.pm',
    'NORECURS'     => 1,
);

