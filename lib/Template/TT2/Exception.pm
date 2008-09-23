package Template::TT2::Exception;

use Template::TT2::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Exception';

sub init {
    my ($self, $config) = @_;
    $self->{ body } = $config->{ body };
    $self->SUPER::init($config);
    return $self;
}

sub body {
    my ($self, $more) = @_;
    my $body = $self->{ body };
    
    if ($more) {
	    $$more .= $$body if $body && $body ne $more;
	    $self->{ body } = $more;
	    return '';
	}
    elsif ($body) {
	    return $$body;
    }
    else {
	    return '';
    }
}

1;