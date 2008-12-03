package Template::TT2::Plugin::Procedural;

use Template::TT2::Class
    version     => 0.01,
    debug       => 0,
    import      => 'class',
    base        => 'Template::TT2::Plugin',
    words       => 'refs PROXY',
    vars        => 'AUTOLOAD',
    constants   => 'PKG',
    messages    => {
        bad_method => 'Invalid method called: %s',
    };


sub load {
    my ($class, $context) = @_;

    # Create a proxy namespace that will be used for objects, e.g. 
    # Template::TT2::Plugin::Example::PROXY, and get a metaclass
    # object (Template::TT2::Class) to manipulate the symbol table for it. 
    my $proxy = class($class.PKG.PROXY);

    # Define new() and AUTOLOAD() methods for the proxy class if
    # they haven't already been created by a previous invocation
    $proxy->method(
        # the new() method is used by TT to create a plugin object instance
        new => sub {
            my $this;
            $class->debug("Creating new $class instance") if DEBUG;
            bless \$this, $_[0];
        },
    ) unless $proxy->method('new');
    

    $proxy->method(
        # the AUTOLOAD() gets called for every method called against it
        AUTOLOAD => sub {
            my $name = $AUTOLOAD; 
               $name =~ s/^.*:://;
               
            return if $name eq 'DESTROY';

            $class->debug("Constructing method for '$name' in '$class'") if DEBUG;

            # fetch the code reference for the function
            my $function = $class->can($name)
                 || return $class->error_msg( bad_method => $name );

            # create a wrapper subroutine closure around it which ignores 
            # the object reference but forwards all other arguments
            my $method = sub {
                shift @_;
                $class->debug("Called $name()") if DEBUG;
                return $function->(@_);
            };
            
            # now install that wrapper into the proxy symbol table so that
            # we can bypass this AUTOLOAD next time
            $proxy->add_methods( $name => $method );

            # now call the method we just created
            return $method->(@_);
        },
    ) unless $proxy->method('AUTOLOAD');

    # return the proxy class name for TT to call new() against
    return $proxy->name;
}

1;

__END__

=head1 NAME

Template::TT2::Plugin::Procedural - Base class for procedural plugins

=head1 SYNOPSIS

    package Template::TT2::Plugin::LWPSimple;
    use base qw(Template::Plugin::Procedural);
    use LWP::Simple;  # exports 'get'
    1;

    [% USE LWPSimple %]
    [% LWPSimple.get("http://www.tt2.org/") %]

=head1 DESCRIPTION

C<Template::TT2::Plugin::Procedural> is a base class for Template Toolkit
plugins that causes defined subroutines to be called directly rather
than as a method.  Essentially this means that subroutines will not
receive the class name or object as its first argument.

This is most useful when creating plugins for modules that normally
work by exporting subroutines that do not expect such additional
arguments.

Despite the fact that subroutines will not be called in an OO manner,
inheritance still function as normal.  A class that uses
C<Template::TT2::Plugin::Procedural> can be subclassed and both subroutines
defined in the subclass and subroutines defined in the original class
will be available to the Template Toolkit and will be called without
the class/object argument.

=head1 AUTHOR

Mark Fowler E<lt>mark@twoshortplanks.comE<gt> L<http://www.twoshortplanks.com>

Refactored for Template::TT2 by Andy Wardley.

=head1 COPYRIGHT

Copyright (C) 2002 Mark Fowler, 2008 Andy Wardley

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
