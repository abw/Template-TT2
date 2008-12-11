package Template::TT2::Namespace::Constants;

use Template::TT2::Modules;
use Template::TT2::Directive;
use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Base',
    constants => 'TT2_MODULES TT2_DIRECTIVE';


sub init {
    my ($self, $config) = @_;
    $self->{ STASH } = TT2_MODULES->module( stash => $config );
    return $self;
}



#------------------------------------------------------------------------
# ident(\@ident)                                             foo.bar(baz)
#------------------------------------------------------------------------

sub ident {
    my ($self, $ident) = @_;
    my @save = @$ident;

    # discard first node indicating constants namespace
    splice(@$ident, 0, 2);

    my $nelems = @$ident / 2;
    my ($e, $result);
    local $" = ', ';

    $self->debug("constant ident [ @$ident ] ") if DEBUG;

    foreach $e (0..$nelems-1) {
        # node name must be a constant
        unless ($ident->[$e * 2] =~ s/^'(.+)'$/$1/s) {
            $self->debug(" * deferred (non-constant item: ", $ident->[$e * 2], ")\n")
                if DEBUG;
            return TT2_DIRECTIVE->ident(\@save);
        }

        # if args is non-zero then it must be eval'ed 
        if ($ident->[$e * 2 + 1]) {
            my $args = $ident->[$e * 2 + 1];
            my $comp = eval "$args";
            if ($@) {
                $self->debug(" * deferred (non-constant args: $args)\n") if DEBUG;
                return TT2_DIRECTIVE->ident(\@save);
            }
            $self->debug("($args) ") if $comp && DEBUG;
            $ident->[$e * 2 + 1] = $comp;
        }
    }


    $result = $self->{ STASH }->get($ident);

    if (! length $result || ref $result) {
        my $reason = length $result ? 'reference' : 'no result';
        $self->debug(" * deferred ($reason)\n") if DEBUG;
        return TT2_DIRECTIVE->ident(\@save);
    }

    $result =~ s/'/\\'/g;

    $self->debug(" * resolved => '$result'\n") if DEBUG;

    return "'$result'";
}

1;

__END__

=head1 NAME

Template::TT2::Namespace::Constants - Compile time constant folding

=head1 SYNOPSIS

    # easy way to define constants
    use Template::TT2;
    
    my $tt = Template::TT2->new({
        CONSTANTS => {
            pi => 3.14,
            e  => 2.718,
        },
    });

    # nitty-gritty, hands-dirty way
    use Template::TT2::Namespace::Constants;
    
    my $tt = Template::TT2->new({
        NAMESPACE => {
            constants => Template::TT2::Namespace::Constants->new({
                pi => 3.14,
                e  => 2.718,
            },
        },
    });

=head1 DESCRIPTION

The C<Template::Namespace::Constants> module implements a namespace handler
which is plugged into the C<Template::TT2::Directive> compiler module.  This then
performs compile time constant folding of variables in a particular namespace.

=head1 METHODS

=head2 new(\%constants)

The new() constructor method creates and returns a reference to a new
Template::TT2::Namespace::Constants object.  This creates an internal stash
to store the constant variable definitions passed as arguments.

    my $handler = Template::TT2::Namespace::Constants->new({
        pi => 3.14,
        e  => 2.718,
    });

=head2 ident(\@ident)

Method called to resolve a variable identifier into a compiled form.  In this
case, the method fetches the corresponding constant value from its internal
stash and returns it.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::TT2::Directive>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
