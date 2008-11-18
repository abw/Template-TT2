#============================================================= -*-Perl-*-
#
# Template::Service
#
# DESCRIPTION
#   Template processing service which adds PRE_PROCESS/POST_PROCESS
#   templates, error handling and various other "wrapper" features.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#============================================================================

package Template::TT2::Service;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Base',
    utils     => 'is_object',
    mutators  => 'hub',
    constants => 'DELIMITER ARRAY HASH CODE DEBUG_SERVICE TT2_EXCEPTION FLOW_STOP',
    config    => [
        'ERROR|ERRORS',
        'AUTO_RESET=1',
    ];
 
our @LIST_ARGS = qw( PRE_PROCESS POST_PROCESS PROCESS WRAPPER );


sub init {
    my ($self, $config) = @_;
    my ($key, $value, $context, $block, $blocks);

    $self->debug("service config: ", $self->dump_data($config)) if DEBUG;

    $self->configure($config);
    $self->init_hub($config);
    
    # coerce PRE_PROCESS, PROCESS and POST_PROCESS to arrays if necessary, 
    # by splitting on non-word characters
    foreach $key (@LIST_ARGS) {
        if (defined ($value = $config->{ $key })) {
            $value = [ split(DELIMITER, $value) ] 
                unless ref $value eq ARRAY;
        }
        else {
            $value = [ ];
        }
        $self->{ $key } = $value;
    }

    # unset PROCESS option unless explicitly specified in config
    $self->{ PROCESS } = undef
        unless defined $config->{ PROCESS };
    
    $self->{ DEBUG } = ($config->{ DEBUG } || 0) & DEBUG_SERVICE;
        
    return $self;
}


sub process {
    my $self    = shift;
    my $name    = shift;
    my $vars    = @_ == 1 && ref $_[0] eq HASH ? shift : { @_ };
    my $context = $self->context;
    my ($template, $item, $output, $procout, $error);
    $output = $procout = '';

    $self->debug( "process($name, ", $vars || '<no vars>', ')')
        if DEBUG;

    $context->reset
        if $self->{ AUTO_RESET };

    # pre-request compiled template from context so that we can alias it 
    # in the stash for pre-processed templates to reference
    $template = $context->template($name);

    # add template reference to variables
    local $vars->{ template } ||= $template
        unless ref $template eq CODE;

    $context->localise($vars);

    SERVICE: {
        # PRE_PROCESS
        eval {
            foreach $name (@{ $self->{ PRE_PROCESS } }) {
                $self->debug("PRE_PROCESS: $name") if DEBUG;
                $output .= $context->process($name);
            }
        };
        last SERVICE if ($error = $@);

        # PROCESS
        eval {
            foreach $name (@{ $self->{ PROCESS } || [ $template ] }) {
                $self->debug("PROCESS: $name") if DEBUG;
                $procout .= $context->process($name);
            }
        };
        if ($error = $@) {
            last SERVICE
                unless defined ($procout = $self->recover($error));
            
        }
        
        if (defined $procout) {
            # WRAPPER
            eval {
                foreach $name (reverse @{ $self->{ WRAPPER } }) {
                    $self->debug("WRAPPER: $name") if DEBUG;
                    $procout = $context->process($name, { content => $procout });
                }
            };
            last SERVICE if ($error = $@);
            $output .= $procout;
        }
        
        # POST_PROCESS
        eval {
            foreach $name (@{ $self->{ POST_PROCESS } }) {
                $self->debug("POST_PROCESS: $name") if DEBUG;
                $output .= $context->process($name);
            }
        };
        last SERVICE if ($error = $@);
    }

    $context->delocalise;

    return $error
        ? $self->error($error)
        : $output;
}


sub recover {
    my ($self, $error) = @_;
    my $context = $self->context;
    my ($hkey, $handler);

    $self->debug("recover($error)\n") if DEBUG;
    
    # there shouldn't ever be a non-exception object received at this
    # point... unless a module like CGI::Carp messes around with the 
    # DIE handler. 
    return undef
        unless is_object(TT2_EXCEPTION, $error);

    # a 'stop' exception is thrown by [% STOP %] - we return the output
    # buffer stored in the exception object
    return $error->body()
        if $error->type() eq FLOW_STOP;

    my $handlers = $self->{ ERROR }
        || return undef;                    ## RETURN

    if (ref $handlers eq HASH) {
        if ($hkey = $error->match_type(keys %$handlers)) {
            $handler = $handlers->{ $hkey };
            $self->debug("using error handler for $hkey") if DEBUG;
        }
        elsif ($handler = $handlers->{ default }) {
            # use default handler
            $self->debug("using default error handler") if DEBUG;
        }
        else {
            return undef;                   ## RETURN
        }
    }
    else {
        $handler = $handlers;
        $self->debug("using default error handler") if $DEBUG;
    }
    
    return $context->process($handler, { error => $error });
}


sub context {
    return $_[0]->{ context }
       ||= $_[0]->hub->context;
}


sub _dump {
    my $self = shift;
    my $context = $self->{ CONTEXT }->_dump();
    $context =~ s/\n/\n    /gm;

    my $error = $self->{ ERROR };
    $error = join('', 
          "{\n",
          (map { "    $_ => $error->{ $_ }\n" }
           keys %$error),
          "}\n")
    if ref $error;
    
    local $" = ', ';
    return <<EOF;
$self
PRE_PROCESS  => [ @{ $self->{ PRE_PROCESS } } ]
POST_PROCESS => [ @{ $self->{ POST_PROCESS } } ]
ERROR        => $error
CONTEXT      => $context
EOF
}


1;
