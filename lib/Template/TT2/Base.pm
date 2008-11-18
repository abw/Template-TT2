package Template::TT2::Base;

use Badger::Debug ':dump';
use Template::TT2::Exception;
use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    import    => 'class',
    constants => 'TT2_HUB',
    vars      => {
        EXCEPTION => 'Template::TT2::Exception',
    },
    messages  => {
        deprecated => 'The %s option has been deprecated',
    };


sub init_hub {
    my ($self, $config) = @_;
    $self->{ hub } = $config->{ hub } || class(TT2_HUB)->load->name;
    return $self;
}

1;

