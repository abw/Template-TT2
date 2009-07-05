package Template::TT2::Plugin::SimpleFilter2;
use base 'Template::TT2::Plugin::Filter';

sub init {
    my $self = shift;
    $self->{ _DYNAMIC } = 1;
    my $name = $self->{ _CONFIG }->{ name } || 'simple2';
    $self->install_filter($name);
    return $self;
}

sub filter {
    my ($self, $text, $args, $conf) = @_;
    return '++' . $text . '++';
}

1;
