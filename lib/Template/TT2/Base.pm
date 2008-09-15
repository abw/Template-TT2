package Template::TT2::Base;

use Badger::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Base';


1;

__END__

sub config_item {
    my ($self, $name, $config) = @_;

    return
        defined $config->{ $name }
              ? $config->{ $name }
              : $self->class->any_var( uc $name );
}

sub init_item {
    my ($self, $name, $config) = @_;
    
    # $name can be [$local_key, $remote_key] which equates to
    # $self->{ $local_key } = $config->{ $foreign_key }, or just a 
    # single $name which we use for both
    my ($lkey, $rkey) 
        = ref $name eq ARRAY 
        ?  @$name 
        : [($name) x 2];
    
    # copy $config element $lkey or $rkey, or look for $rkey class var
    return (
        $self->{ $lkey } 
            = defined $config->{ $lkey }
            ?         $config->{ $lkey }
            : defined $config->{ $rkey }
            ?         $config->{ $rkey }
            : $self->class->any_var( uc $rkey )
    );
}


1;

