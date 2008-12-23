#============================================================= -*-Perl-*-
# 
# Template::TT2::Stash::XS
# 
# DESCRIPTION
#   Perl bootstrap for XS module. Inherits methods from 
#   Template::Stash when not implemented in the XS module.
#
#========================================================================

package Template::TT2::Stash::XS;

use strict;
use warnings;
use Template::TT2;
use Template::TT2::Stash;
our $AUTOLOAD;

BEGIN {
    require DynaLoader;
    @Template::TT2::Stash::XS::ISA = qw( DynaLoader Template::TT2::Stash );

    eval {
        bootstrap Template::TT2::Stash::XS $Template::TT2::VERSION;
    };
    if ($@) {
        die "Couldn't load Template::TT2::Stash::XS $Template::TT2::VERSION:\n\n$@\n";
    }
}

sub DESTROY {
    # no op
    1;
}

# catch missing method calls here so perl doesn't barf 
# trying to load *.al files 

sub AUTOLOAD {
    my ($self, @args) = @_;
    my @c    = caller(0);
    my $auto = $AUTOLOAD;

    $auto =~ s/.*:://;
    $self =~ s/=.*//;

    die "Can't locate object method \"$auto\"" .
        " via package \"$self\" at $c[1] line $c[2]\n";
}

1;

__END__

=head1 NAME

Template::TT2::Stash::XS - XS implementation of Template::TT2::Stash

=head1 SYNOPSIS

See L<Template::TT2::Stash>.

=head1 DESCRIPTION

This module is an XS implementation of L<Template::TT2::Stash>, written in
C for maximum speed.

=head1 METHODS

The following methods are implemented in addition to those inherited
from L<Template::TT2::Stash>.

=head2 get($var)

Method to get a variable value.

=head2 set($var,$value,$default)

Method to set a variable value.

=head2 dot($root,$item,$args,$lvalue)

Method to evaluate a dot operator.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::TT2>, L<Template::TT2::Stash>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
