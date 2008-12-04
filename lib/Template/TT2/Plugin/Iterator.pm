package Template::TT2::Plugin::Iterator;

use Template::TT2::Iterator;
use Template::TT2::Class
    version     => 0.01,
    debug       => 0,
    import      => 'class',
    base        => 'Template::TT2::Plugin',
    constants   => 'TT2_ITERATOR';


sub new {
    # class, context
    shift; shift;
    TT2_ITERATOR->new(@_);
}

1;

__END__

=head1 NAME

Template::TT2::Plugin::Iterator - Plugin to create an iterators

=head1 SYNOPSIS

    [% USE iterator(list, args) %]
    
    [% FOREACH item = iterator %]
       [% '<ul>' IF iterator.first %]
       <li>[% item %]
       [% '</ul>' IF iterator.last %]
    [% END %]

=head1 DESCRIPTION

The iterator plugin provides a way to create a L<Template::TT2::Iterator> object 
to iterate over a data set.  An iterator is implicitly automatically by the
L<FOREACH> directive.  This plugin allows the iterator to be explicitly created
with a given name.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::TT2::Plugin>, L<Template::TT2::Iterator>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
