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
