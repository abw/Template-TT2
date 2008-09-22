#------------------------------------------------------------------------
# An object for tracking down a bug with DBIx::Class where TT is causing 
# the numification operator to be called.  Matt S Trout suggests we've 
# got a truth test somewhere that should be a defined but that doesn't 
# appear to be the case...
# http://rt.cpan.org/Ticket/Display.html?id=23763
#------------------------------------------------------------------------

package NumberLike;

use overload 
    '""' => 'stringify',
    '0+' => 'numify', 
    fallback => 1;

sub new {
    my ($class, $text) = @_;
    bless \$text, $class;
}

sub numify {
    my $self = shift;
    return "FAIL: numified $$self";
}

sub stringify {
    my $self = shift;
    return "PASS: stringified $$self";
}

sub things {
    return [qw( foo bar baz )];
}

1;