package Template::TT2::Hub;

use Template::TT2::Class
    version    => 0.01,
    debug      => 0,
    base       => 'Template::TT2::Modules',
    utils      => 'blessed',
    filesystem => 'VFS FS',
    constants  => 'HASH ARRAY CODE GLOB SCALAR',
    constant   => {
        PRINT_METHOD => 'print',
    },
    config     => [
        'QUIET|quiet=0',
        'ENCODING|encoding=0',
        'MKDIR|mkdir=1',
        'OUTPUT|output',
        'OUTPUT_PATH|output_path',
    ],
    messages   => {
        bad_output => 'Invalid output specified: %s',
    };

our $DEBUG_BINMODE  = 0 unless defined $DEBUG_BINMODE;      # for testing
our @MODULE_ALIASES = qw( SERVICE CONTEXT PARSER );

sub install_binmode_debugger {
    my $self = shift;
    $DEBUG_BINMODE = shift;
}

#-----------------------------------------------------------------------
# factory methods
#-----------------------------------------------------------------------

sub type_args {
    my $self = shift;
    my $type = shift;

    # Hmmm... this isn't quite right.  It works fine for creating
    # sub-systems that need to share the master config, but it fails
    # if we want to create, say, an iterator, providing our own data
    #    $self->warn("Ignoring additional arguments to create $type") if @_;
    #    return ($type, $self->{ config });

    # OK, let's try this:
    return ($type, @_ ? @_ : $self->{ config });

}

sub found_object {
#   my ($self, $name, $item, @args) = @_;
    return $_[2];
}


#-----------------------------------------------------------------------
# constructor method
#-----------------------------------------------------------------------


sub init {
    my ($self, $config) = @_;

    # TODO: QUIET => ON_WARN
    $self->configure($config);

    # rewrite any TT2 options that define alternate modules (e.g. SERVICE)
    # into a 'modules' hash that the base class Badger::Factory can use
    foreach my $alias (@MODULE_ALIASES) {
        $config->{ modules }->{ lc $alias } ||= $config->{ $alias }
            if $config->{ $alias };
    }

    $self->debug("hub config (post-cleanup): ", $self->dump_data($config))
        if DEBUG;
    
    # copy the config and stuff ourselves in it as a (yes, circular) 
    # reference for delegate components to use to refer back to us.
    $self->{ config } = {
        %$config,
        hub => $self,
    };
    
    $self->init_factory($config);
    
    return $self;
}

sub service {
    my $self = shift->prototype;
    return $self->{ service }
       ||= $self->module('service');
}

sub context {
    my $self = shift->prototype;
    return $self->{ context }
       ||= $self->module('context');
}

sub output {
    my $self = shift->prototype;
    my $text = shift;
    my $dest = shift || $self->{ config }->{ OUTPUT };
    my $args = @_ == 1 && ref $_[0] eq HASH ? shift : { @_ };

    # if no destination is specified and the OUTPUT config parameter
    # is a false value then we return the text generated
    return $text unless $dest;

    # Otherwise we've got a plain text file name or reference of some kind
    my $type = ref $dest;

    $self->debug("output [$type] => $dest\n") if DEBUG;

    if (! $type) {
        $self->output_file($dest, $text, $args);    # output to file
    }
    elsif (blessed $dest) {
        my $code = $dest->can(PRINT_METHOD)
            || return $self->error_msg( bad_output => $dest );
        return $code->($dest, $text);               # call object's print() method
    }
    elsif ($type eq CODE) {
        return $dest->($text);                      # call subroutine
    }
    elsif ($type eq GLOB) {
        return print $dest $text;                   # print to GLOB (e.g. STDOUT)
    }
    elsif ($type eq SCALAR) {
        $$dest .= $text;                            # append to text ref
        return $dest;
    }
    elsif ($type eq ARRAY) {
        push @$dest, $text;                         # push onto list
        return $dest;
    }
    else {
        return $self->error_msg( bad_output => $dest );
    }
}


sub output_filesystem {
    my $self = shift->prototype;
    
    return $self->{ OUTPUT_FS } ||= do {
        my $config = $self->{ config };
        
        if ($config->{ OUTPUT_PATH }) {
            # create a Badger::Filesystem::Directory object for file output,
            $self->debug("creating virtual filesystem for output in $config->{ OUTPUT_PATH }") if DEBUG;
            
            # check it exists, do a mkdir if the MKDIR flags says that's OK
            my $dir = FS->directory(  $config->{ OUTPUT_PATH } )
                        ->must_exist( $config->{ MKDIR       } );

            # create virtual filesystem with root at $dir (value drops through)
            VFS->new( root => $dir );   
        }
        elsif (defined $config->{ OUTPUT_PATH }) {
            # OUTPUT_PATH was explicitly set false - no output for you!
            return $self->error('Cannot create filesystem output - OUTPUT_PATH is disabled');
        }
        else {
            $self->debug("output to filesystem") if DEBUG;
            FS->new;
        }
    };
}


sub output_file {
    my $self = shift->prototype;
    my $file = $self->output_filesystem->file(shift);

    $self->debug("output file: ", $file->definitive, "\n") if DEBUG;

    # make sure any intermediate directories between the OUTPUT_DIR and 
    # final destination exist, or can be created if the MKDIR flag is set
    $file->directory->must_exist($self->{ config }->{ MKDIR });
    
    # return the Badger::File object if no additional arguments passed
    return $file unless @_;
    
    # otherwise, arguments are ($text, %args)
    my $text = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $fh   = $file->write;
    my $enc  = defined $args->{ binmode  }
                     ? $args->{ binmode  } 
             : defined $args->{ encoding }
                     ? $args->{ encoding } 
             :         $self->{ config   }->{ ENCODING };

    # hack for testing - allows us to check that binmode/encoding options
    # are properly forwarded to this point
    $DEBUG_BINMODE->($enc) if $DEBUG_BINMODE;   # hack for testing
  
    # TODO: move this into Badger::Filesystem:File
    $fh->binmode($enc eq '1' ? () : $enc) if $enc;
    $fh->print($text);
    $fh->close;

    return $file;
}


sub destroy {
    my $self = shift;

    # if called as a class method we cleanup any prototype object
    # stored as a singleton in the $PROTOTYPE package variable
    return $self->prototype(undef)
        unless ref $self;

    $self->debug("destroying hub: $self") if $DEBUG;

    # probably not necessary but doesn't hurt just in case there are 
    # other references to $self->{ config } keeping it live
    delete $self->{ config }->{ hub };
    
    # empty content of $self to break any circular references that
    # we may have established with other items that point back to us
    %$self = ();
}

sub DESTROY {
    my $self = shift;
    $self->destroy if %$self;
}



1;