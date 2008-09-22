package ListObject;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = @_ && ref $_[0] eq 'ARRAY' ? shift : [ @_ ];
    bless $self, $class;
}

sub zero {
    shift->[0];
}

sub one {
    shift->[1];
}

sub two {
    my $self = shift;
    return @_ 
        ? ($self->[2] = shift)
        :  $self->[2];
}

1;
