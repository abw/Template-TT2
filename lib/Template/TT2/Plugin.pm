package Template::TT2::Plugin;

use Template::TT2::Class
    version => 0.01,
    debug   => 0,
    base    => 'Template::TT2::Base';


sub load {
    return $_[0];
}


sub new {
    my $class = shift;
    bless { }, $class;
}


1;
