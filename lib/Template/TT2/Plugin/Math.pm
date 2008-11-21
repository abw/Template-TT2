package Template::TT2::Plugin::Math;

use Template::TT2::Class
    version  => 0.01,
    debug    => 0,
    import   => 'CLASS',
    base     => 'Template::TT2::Plugin',
    messages => {
        no_module => 'The %s module is not installed',
    };

our $HAS_MATH_TRIG  = eval { require Math::Trig };

our $METHODS = {
    abs     => sub { abs($_[0]);          },
    atan2   => sub { atan2($_[0], $_[1]); }, # prototyped (ugg)
    cos     => sub { cos($_[0]);          },
    exp     => sub { exp($_[0]);          },
    hex     => sub { hex($_[0]);          },
    int     => sub { int($_[0]);          },
    log     => sub { log($_[0]);          },
    oct     => sub { oct($_[0]);          },
    rand    => sub { rand($_[0]);         },
    sin     => sub { sin($_[0]);          },
    sqrt    => sub { sqrt($_[0]);         },
    srand   => sub { srand($_[0]);        },
    trig    => $HAS_MATH_TRIG,
    
    $HAS_MATH_TRIG 
        ? map { $_ => Math::Trig->can($_) } @Math::Trig::EXPORT
        : (),
};

sub new {
    my ($class, $context, $config) = @_;
    
    # user can provide trig/random flags which, when set true,
    # require us to assert that those modules are really available
    $class->error_msg( no_module => 'Math::Trig' )
        if $config->{ trig } && ! $HAS_MATH_TRIG;

    $context->define_vmethods( item => $METHODS );
    
    return $METHODS;
}


1;

__END__

=head1 NAME

Template::Plugin::Math - Plugin providing mathematical functions

=head1 SYNOPSIS

    [% USE Math;
    
       # function style
       Math.sqrt(9);            # 3
       
       # virtual method style
       n = 16;
       n.sqrt;                  # 4                  
    %]

=head1 DESCRIPTION

The Math plugin provides numerous mathematical functions for use
within templates.  

    [% USE Math %]

The plugin returns a hash array containing the various functions. 

    [% Math.sqrt(9) %]

It also defines the various functions as virtual methods.

    [% n = 16;  n.sqrt %]

=head1 METHODS

C<Template::Plugin::Math> makes available the following functions from
the Perl core:

=over 4

=item abs

=item atan2

=item cos

=item exp

=item hex

=item int

=item log

=item oct

=item rand

=item sin

=item sqrt

=item srand

=back

In addition, if the L<Math::Trig> module can be loaded, the following
functions are also available:

=over 4

=item pi

=item tan

=item csc

=item cosec

=item sec

=item cot

=item cotan

=item asin

=item acos

=item atan

=item acsc

=item acosec

=item asec

=item acot

=item acotan

=item sinh

=item cosh

=item tanh

=item csch

=item cosech

=item sech

=item coth

=item cotanh

=item asinh

=item acosh

=item atanh

=item acsch

=item acosech

=item asech

=item acoth

=item acotanh

=item rad2deg

=item rad2grad

=item deg2rad

=item deg2grad

=item grad2rad

=item grad2deg

=back

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt> L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

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
