package NonPlugin::Module;
use base 'Badger::Base';

sub new {
    my ($class, $value) = @_;
    bless {
	    VALUE => $value,
    }, $class;
}

sub output {
    my $self = shift;
    return "This is the NonPlugin::Module module, value is $self->{ VALUE }";
}

1;
