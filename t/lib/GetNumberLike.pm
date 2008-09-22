package GetNumberLike;
use NumberLike;

sub new {
    my ($class, $text) = @_;
    bless { }, $class;
}

sub num {
    NumberLike->new("from GetNumberLike");
}

1;