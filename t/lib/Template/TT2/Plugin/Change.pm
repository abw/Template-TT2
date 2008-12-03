package Template::TT2::Plugin::Change;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Plugin::Filter';


sub init {
    my $self = shift;

    $self->debug("Change plugin filter init()\n") if DEBUG;
        
    $self->{ _DYNAMIC } = 1;
        
    # first arg can specify filter name
    $self->install_filter($self->{ _ARGS }->[0] || 'change');
        
    return $self;
}
    
sub filter {
    my ($self, $text, $args, $config) = @_;

    $self->debug("Running change plugin filter\n") if DEBUG;
    $self->debug("Args: ", $self->dump_data($args) ) if DEBUG;
    $self->debug("Config: ", $self->dump_data($config) ) if DEBUG;
        
    $config = $self->merge_config($config);
    my $regex = join('|', keys %$config);
        
    $text =~ s/($regex)/$config->{ $1 }/ge;
        
    return $text;
}
    
1;