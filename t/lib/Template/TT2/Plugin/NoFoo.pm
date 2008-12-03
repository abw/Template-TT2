package Template::TT2::Plugin::NoFoo;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Plugin::Filter';


sub filter {
    my ($self, $text) = @_;
    $text =~ s/foo//g;
    return $text;
}
    
1;