package HashObject;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
    bless $self, $class;
}

sub hello {
    my $self = shift;
    my $name = shift || $self->{ name };
    return "Hello $name";
}

sub goodbye {
    my $self = shift;
    return $self->no_such_method();
}

1;
