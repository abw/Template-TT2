package Template::TT2::Class;

use Badger::Debug ':debug';
use Badger::Class
    version  => 0.01,
    uber     => 'Badger::Class',
    utils    => 'self_params',
    constant => {
        base_id   => 'Template::TT2',
        CONSTANTS => 'Template::TT2::Constants',
        UTILS     => 'Template::TT2::Utils',
    };


sub add_methods {
    my ($self, $params) = self_params(@_);
    while (my ($name, $code) = each %$params) {
        $self->method($name => $code)
            unless $self->method($name);
    }
    return $self;
}

1;
