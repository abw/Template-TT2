package Template::TT2::Plugin::Pod;

use Template::TT2::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Template::TT2::Plugin';

use Pod::POM;

sub new {
    # class, context
    shift; shift;
    Pod::POM->new(@_);
}


1;

__END__

=head1 NAME

Template::TT2::Plugin::Pod - Plugin interface to Pod::POM (Pod Object Model)

=head1 SYNOPSIS

    [% USE Pod(podfile) %]
    
    [% FOREACH head1 = Pod.head1;
         FOREACH head2 = head1/head2;
           ...
         END;
       END
    %]

=head1 DESCRIPTION

This plugin is an interface to the L<Pod::POM> module.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::TT2::Plugin>, L<Pod::POM>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
