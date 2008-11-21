package Template::TT2::Plugin::Format;


use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Template::TT2::Plugin';
    

sub new {
    my ($class, $context, $format) = @_;
    return defined $format
        ?   make_formatter($format)
        : \&make_formatter;
}


sub make_formatter {
    my $format = shift;
    $format = '%s' unless defined $format;
    return sub { 
        my @args = @_;
        push(@args, '') unless @args;
        return sprintf($format, @args); 
    }
}


1;

__END__

=head1 NAME

Template::TT2::Plugin::Format - Plugin to create formatting functions

=head1 SYNOPSIS

    [% USE format %]
    [% commented = format('# %s') %]
    [% commented('The cat sat on the mat') %]
    
    [% USE bold = format('<b>%s</b>') %]
    [% bold('Hello') %]

=head1 DESCRIPTION

The format plugin constructs sub-routines which format text according to
a C<printf()>-like format string.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt> L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2007 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::Plugin>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
