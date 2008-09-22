package Template::TT2::Base;

use Template::TT2::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Base',
    import   => 'class',
    words    => 'DEFAULTS',
    messages => {
        deprecated => 'The %s option has been deprecated',
    };

use Badger::Debug ':dump';

sub init_defaults {
    my ($self, $config) = @_;
    my $class = $self->class;

    # Set values from $config or use the default values in package variables 
    # created by the 'defaults' class hook.  We use the keys in $DEFAULTS to 
    # tell us what to look for, but look for values in package variables 
    # rather than using those in the $DEFAULTS hash.  This is to allow a
    # user to pre-defined the package vars to some value other than the 
    # default.  It also make inheritance work (i.e. a subclass can define
    # a different $CACHE, for example)
    my $defaults = $self->class->hash_vars(DEFAULTS);
    foreach my $key (keys %$defaults) {
        $self->{ $key } = 
            defined $config->{ $key }
                  ? $config->{ $key }
                  : $class->any_var($key);
        $self->debug("default: $key => $self->{ $key }\n") if DEBUG;
    }
}


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

