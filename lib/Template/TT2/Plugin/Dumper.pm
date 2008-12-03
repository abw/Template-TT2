package Template::TT2::Plugin::Dumper;

use Template::TT2::Class
    version    => 0.01,
    debug      => 0,
    import     => 'class',
    base       => 'Template::TT2::Plugin',
    words      => 'refs',
    constants  => 'PKG',
    constant   => {
        DATA_DUMPER => 'Data::Dumper',
    };

use Data::Dumper;

our $AUTOLOAD;
our @DUMPER_ARGS = qw( Indent Pad Varname Purity Useqq Terse Freezer
                       Toaster Deepcopy Quotekeys Bless Maxdepth );

sub new {
    my ($class, $context, $params) = @_;
    my ($key, $val);
    $params ||= { };

    # look for parameters that can be used to set DD pkg vars
    foreach my $arg (@DUMPER_ARGS) {
        no strict refs;
        if ( defined ($val = $params->{ lc $arg })
        or   defined ($val = $params->{ $arg    }) ) {
            ${ DATA_DUMPER.PKG.$arg } = $val;
        }
    }

    bless { 
        _context => $context,
    }, $class;
}


sub dump {
    my $self    = shift;
    my $content = Dumper @_;
    return $content;
}


sub dump_html {
    my $self    = shift;
    my $content = Dumper @_;
    my $filter  = $self->{ _html_filter }
              ||= $self->{ _context }->filter('html');
    return $filter->($content);
}

1;

__END__

=head1 NAME

Template::TT2::Plugin::Dumper - Plugin interface to Data::Dumper

=head1 SYNOPSIS

    [% USE Dumper %]
    
    [% Dumper.dump(variable) %]
    [% Dumper.dump_html(variable) %]

=head1 DESCRIPTION

This is a very simple Template Toolkit Plugin Interface to the L<Data::Dumper>
module.  A C<Dumper> object will be instantiated via the following directive:

    [% USE Dumper %]

As a standard plugin, you can also specify its name in lower case:

    [% USE dumper %]

The C<Data::Dumper> C<Pad>, C<Indent> and C<Varname> options are supported
as constructor arguments to affect the output generated.  See L<Data::Dumper>
for further details.

    [% USE dumper(Indent=0, Pad="<br>") %]

These options can also be specified in lower case.

    [% USE dumper(indent=0, pad="<br>") %]

=head1 METHODS

There are two methods supported by the C<Dumper> object.  Each will
output into the template the contents of the variables passed to the
object method.

=head2 dump()

Generates a raw text dump of the data structure(s) passed

    [% USE Dumper %]
    [% Dumper.dump(myvar) %]
    [% Dumper.dump(myvar, yourvar) %]

=head2 dump_html()

Generates a dump of the data structures, as per L<dump()>, but with the 
characters E<lt>, E<gt> and E<amp> converted to their equivalent HTML
entities and newlines converted to E<lt>brE<gt>.

    [% USE Dumper %]
    [% Dumper.dump_html(myvar) %]

=head1 AUTHORS

Written by Simon Matthews E<lt>sam@tt2.orgE<gt>.  Updated for Template::TT2
by Andy Wardley.

=head1 COPYRIGHT

Copyright (C) 2000-2008 Simon Matthews, Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::TT2::Plugin>, L<Data::Dumper>

