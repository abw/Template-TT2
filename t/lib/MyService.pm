package MyService;
use base 'Template::TT2::Service';

sub process {
    return join(
        "\n",
        '<MY SERVICE>',
        shift->SUPER::process(@_),
        '</MY SERVICE>',
    );
}

1;
