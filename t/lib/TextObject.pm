package TextObject;

use Template::TT2::Class
    as_text => 'text';
    

sub new {
    my $class = shift;
    my $text  = shift;
    bless \$text, $class;
}

sub text {
    my $self = shift;
    return $$self;
}

1;
