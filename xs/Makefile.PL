use lib qw( ../lib ./lib );
use ExtUtils::MakeMaker;
use Template::TT2;

WriteMakefile(
    'NAME'     => 'Template::TT2::Stash::XS',
    'C'        => [ qw( Stash.c ) ],
    'XS'       => { 'Stash.xs' => 'Stash.c' },
    'OBJECT'   => 'Stash.o',
    'VERSION'  => $Template::TT2::VERSION,
    'NORECURS' => 1,
);

