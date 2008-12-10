package Template::TT2::Plugin::View;

use Template::TT2::View;
use Template::TT2::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Template::TT2::Plugin',
    constant => {
        VIEW => 'Template::TT2::View',
    };

sub new {
    my $class   = shift;
    my $context = shift;
    my $view    = $class->VIEW->new($context, @_);
    $view->seal();
    return $view;
}

1;

__END__


=head1 NAME

Template::TT2::Plugin::View - Plugin to create views (Template::TT2::View)

=head1 SYNOPSIS

    [% USE view(
            prefix = 'splash/'          # template prefix/suffix
            suffix = '.tt2'             
            bgcol  = '#ffffff'          # and any other variables you 
            style  = 'Fancy HTML'       # care to define as view metadata,
            items  = [ foo, bar.baz ]   # including complex data and
            foo    = bar ? baz : x.y.z  # expressions
    %]
    
    [% view.title %]                    # access view metadata
    
    [% view.header(title = 'Foo!') %]   # view "methods" process blocks or
    [% view.footer %]                   # templates with prefix/suffix added

=head1 DESCRIPTION

This plugin module creates L<Template::TT2::View> objects.  Views are an
experimental feature in TT2 and will be removed, replaced or refactored for 
TT3.

Please consult L<Template::Manual::Views> and L<Template::TT2::View> for
further info.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::TT2::Plugin>, L<Template::TT2::View>, L<Template::Manual::Views>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
