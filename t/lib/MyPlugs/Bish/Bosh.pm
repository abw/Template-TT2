package MyPlugs::Bish::Bosh;
use base 'Template::TT2::Plugin';

sub new {
    my ($class, $context, $value) = @_;
    bless {
	    VALUE => $value,
    }, $class;
}

sub output {
    my $self = shift;
    return "This is the Bish.Bosh plugin, value is $self->{ VALUE }";
}

1;
