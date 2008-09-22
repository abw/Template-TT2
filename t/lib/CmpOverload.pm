#-----------------------------------------------------------------------
# an object without overloaded comparison.
# http://rt.cpan.org/Ticket/Display.html?id=24044
#-----------------------------------------------------------------------

package CmpOverload;

use overload ('cmp' => 'compare_overload', '<=>', 'compare_overload');

sub new { bless {}, shift };

sub hello {
    return "Hello";
}

sub compare_overload {
    die "Mayhem!";
}

1;