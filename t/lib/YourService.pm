package YourService;
use base 'Template::TT2::Service';

sub process {
    return join(
        "\n",
        '<YOUR SERVICE>',
        shift->SUPER::process(@_),
        '</YOUR SERVICE>',
    );
}

1;
