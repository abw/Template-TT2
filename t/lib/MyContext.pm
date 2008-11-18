package MyContext;
use base 'Template::TT2::Context';

sub process {
    return join(
        "\n",
        '<MY CONTEXT>',
        shift->SUPER::process(@_),
        '</MY CONTEXT>',
    );
}

1;
