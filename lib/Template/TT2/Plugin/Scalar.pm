package Template::TT2::Plugin::Scalar;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Plugin',
    vars      => 'AUTOLOAD',
    words     => 'CODE',
    constant  => {
        MONAD => 'Template::TT2::Monad::Scalar',
    },
    messages  => {
        undefined => 'Undefined value for scalar call: $item',
    };


sub load {
    my $class   = shift;
    my $context = shift
        || return $class->error_msg( missing => 'context' );
    
    # define .scalar vmethods for hash and list objects
    $context->define_vmethod( hash => scalar => \&scalar_monad );
    $context->define_vmethod( list => scalar => \&scalar_monad );

    return $class;
}


sub scalar_monad {
    # create a .scalar monad which wraps the hash- or list-based object
    # and delegates any method calls back to it, calling them in scalar 
    # context, e.g. foo.scalar.bar becomes $MONAD->new($foo)->bar and 
    # the monad calls $foo->bar in scalar context
    MONAD->new(shift);
}


sub new {
    my ($class, $context, @args) = @_;
    # create a scalar plugin object which will lookup a variable subroutine
    # and call it.  e.g. scalar.foo results in a call to foo() in scalar context
    my $self = bless {
        _CONTEXT => $context,
    }, $class;
    return $self;
}


sub AUTOLOAD {
    my $self = shift;
    my $item = $AUTOLOAD;
    $item =~ s/.*:://;
    return if $item eq 'DESTROY';
    
    # lookup the named values
    my $stash = $self->{ _CONTEXT }->stash;
    my $value = $stash->{ $item };

    if (! defined $value) {
        return $self->error_msg( undefined => $item );
    }
    elsif (ref $value eq CODE) {
        $value = $value->(@_);
    }
    return $value;
}


#-----------------------------------------------------------------------
# Monad class
#-----------------------------------------------------------------------

package Template::TT2::Monad::Scalar;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Base',
    vars      => 'AUTOLOAD',
    words     => 'CODE',
    vars      => 'AUTOLOAD',
    utils     => 'blessed',
    throws    => 'scalar',
    messages  => {
        undefined => 'Undefined value for scalar call: $item',
    };


sub new {
    my ($class, $this) = @_;
    bless \$this, $class;
}


sub AUTOLOAD {
    my $self = shift;
    my $this = $$self;
    my $item = $AUTOLOAD;
    $item =~ s/.*:://;
    return if $item eq 'DESTROY';
    
    # lookup the method...
    my $method = (blessed $this ? $this->can($item) : UNIVERSAL::can($this, $item))
        || return $self->error_msg( invalid => method => $item );

    # ...and call it in scalar context
    my $result = $method->($this, @_);

    return $result;
}

1;

__END__

=head1 NAME

Template::TT2::Plugin::Scalar - call object methods in scalar context

=head1 SYNOPSIS

    [% USE scalar %]
    
    # TT2 calls object methods in array context by default
    [% object.method %]
    
    # force it to use scalar context
    [% object.scalar.method %]
    
    # also works with subroutine references
    [% scalar.my_sub_ref %]

=head1 DESCRIPTION

The Template Toolkit calls user-defined subroutines and object methods
using Perl's array context by default.  This plugin module provides a way 
for you to call subroutines and methods in scalar context.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt> L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::TT2::Plugin>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
