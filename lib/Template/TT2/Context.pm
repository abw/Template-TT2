package Template::TT2::Context;

use Badger::Debug ':debug';
use Template::TT2::Modules;
use Template::TT2::Iterator;
use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Base',
    import    => 'class',
    words     => 'LOAD_',
    utils     => 'blessed is_object',
    accessors => 'hub',
    constants => 'CODE DEBUG_UNDEF DEBUG_CONTEXT DEBUG_DIRS DEBUG_FLAGS HASH
                  ARRAY SCALAR DELIMITER MSWIN32 :modules :status :error',
    constant  => {
        EXCEPTION => 'Badger::Exception',
    },
    messages  => {
        view_base_undef   => "View base is not defined: %s",
        view_base_invalid => "View base is not a %s object: %s => %s"
    };


our @LOADERS    = qw( templates plugins filters );

# generate lower_case accessor method to access UPPER_CASE items
# (a good reason why TT3 will be switching to lower case config options)

class->methods(
    map {
        my $m = uc $_;              # lexically scoped copy
        $_ => sub { $_[0]->{ $m } }
    }
    qw( stash blocks trim eval_perl load_perl )
);


sub init {
    my ($self, $config) = @_;
    my $class = $self->class;
    my $debug = $config->{ DEBUG } || $DEBUG;
    my ($key, $load_key, $value, $block, $blocks);

    $self->init_hub($config);

    # LOAD_TEMPLATES, LOAD_PLUGINS, LOAD_FILTERS - lists of providers
    foreach $key (@LOADERS) {
        $load_key = LOAD_ . uc $key;
        $value = $config->{ $key }
              || $config->{ $load_key }
              || $self->{ hub }->module($key);
        $value = [ $value ] 
            unless ref $value eq ARRAY;
        $self->{ $load_key } = $value;
    }

    # PREFIX_MAP maps prefixes to one or more template providers
    my $templates  = $self->{ LOAD_TEMPLATES };
    my $prefix_map = $self->{ PREFIX_MAP } = $config->{ PREFIX_MAP } || { };
    while (my ($key, $val) = each %$prefix_map) {
        $prefix_map->{ $key } = [ 
            ref $val 
              ? $val 
              : map { $templates->[$_] } 
                split(/\D+/, $val) 
        ] unless ref $val eq ARRAY;
    }

    # STASH can be pre-defined or is created using VARIABLES/PRE_F
    $self->{ STASH } = $config->{ STASH } || do {
        my $predefs  = $config->{ VARIABLES } || { };

        # hack to get stash to know about debug/strict modes
        $predefs->{ _DEBUG } = ($debug & DEBUG_UNDEF) ? 1 : 0
             unless defined $predefs->{ _DEBUG };
        $predefs->{ _STRICT } = $config->{ STRICT }
             unless defined $predefs->{ _STRICT };
        
        TT2_MODULES->module( stash => $predefs );
    };
    
    # compile any template BLOCKS specified as text
    $blocks = $config->{ BLOCKS } || { };
    $self->{ INIT_BLOCKS } = $self->{ BLOCKS } = { 
        map {
            $block = $blocks->{ $_ };
            $block = $self->template(\$block)
                unless ref $block;
            ($_ => $block);
        } 
        keys %$blocks
    };

    # define any VIEWS
    $self->define_views( $config->{ VIEWS } )
        if $config->{ VIEWS };

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # RECURSION - flag indicating if recursion into templates is supported
    # EVAL_PERL - flag indicating if PERL blocks should be processed
    # TRIM      - flag to remove leading and trailing whitespace from output
    # BLKSTACK  - list of hashes of BLOCKs defined in current template(s)
    # CONFIG    - original configuration hash
    # EXPOSE_BLOCKS - make blocks visible as pseudo-files
    # DEBUG_FORMAT  - format for generating template runtime debugging messages
    # DEBUG         - format for generating template runtime debugging messages
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    $self->{ RECURSION     } = $config->{ RECURSION } || 0;
    $self->{ EVAL_PERL     } = $config->{ EVAL_PERL } || 0;
    $self->{ TRIM          } = $config->{ TRIM      } || 0;
    $self->{ BLKSTACK      } = [ ];
    $self->{ CONFIG        } = $config;
    $self->{ DEBUG_FORMAT  } = $config->{ DEBUG_FORMAT };
    $self->{ DEBUG_DIRS    } = $debug & DEBUG_DIRS;
    $self->{ DEBUG         } = $debug & (DEBUG_CONTEXT | DEBUG_FLAGS);
    $self->{ OUTPUT_FS     } = $config->{ OUTPUT_FS };
    $self->{ EXPOSE_BLOCKS } = defined $config->{ EXPOSE_BLOCKS }
                                     ? $config->{ EXPOSE_BLOCKS } : 0;

    return $self;
}


#-----------------------------------------------------------------------
# Template methods
#-----------------------------------------------------------------------

sub template {
    my ($self, $name) = @_;
    my ($prefix, $blocks, $defblocks, $provider, $template, $error);
    my ($shortname, $blockname, $providers);

    $self->debug("template($name)") if DEBUG;

    # references to Template::TT2::Document (or sub-class) objects objects, 
    # or CODE references are assumed to be pre-compiled templates and are
    # returned intact
    return $name
        if (blessed $name && $name->isa(TT2_DOCUMENT))          # TODO: Template::Document
        || (ref($name) eq CODE);

    $shortname = $name;

    unless (ref $name) {
        
        $self->debug("looking for block [$name]") if DEBUG;

        # we first look in the BLOCKS hash for a BLOCK that may have 
        # been imported from a template (via PROCESS)
        return $template
            if ($template = $self->{ BLOCKS }->{ $name });
        
        # then we iterate through the BLKSTACK list to see if any of the
        # templates we're visiting define this BLOCK
        foreach $blocks (@{ $self->{ BLKSTACK } }) {
            return $template
                if $blocks && ($template = $blocks->{ $name });
        }
        
        # now it's time to ask the providers, so we look to see if any 
        # prefix is specified to indicate the desired provider set.
        if ($^O eq 'MSWin32') {
            # let C:/foo through
            $prefix = $1 if $shortname =~ s/^(\w{2,})://o;
        }
        else {
            $prefix = $1 if $shortname =~ s/^(\w+)://;
        }
        
        if (defined $prefix) {
            $providers = $self->{ PREFIX_MAP }->{ $prefix } 
                || $self->throw(
                    ERROR_FILE, 
                    "no providers for template prefix '$prefix'"
                )
        }
    }
    $providers = $self->{ PREFIX_MAP }->{ default }
        || $self->{ LOAD_TEMPLATES }
            unless $providers;


    # Finally we try the regular template providers which will 
    # handle references to files, text, etc., as well as templates
    # reference by name.  If

    $blockname = '';

    while ($shortname) {
        $self->debug("asking providers for [$shortname] [$blockname]") if DEBUG;

        foreach my $provider (@$providers) {
            $template = $provider->fetch($shortname, $prefix)
                || next;
            $self->debug("provider $provider returned compiled template $template\n") if DEBUG;
            if (length $blockname) {
                return $template 
                    if $template = $template->blocks->{ $blockname };
            }
            else {
                return $template;
            }
        }
        
        last if ref $shortname || ! $self->{ EXPOSE_BLOCKS };
        $shortname =~ s{/([^/]+)$}{} || last;
        $blockname = length $blockname ? "$1/$blockname" : $1;
    }

    $self->throw(ERROR_FILE, "$name: not found");
}


sub define_block {
    my ($self, $name, $block) = @_;

    # TODO: assert that refs are template objects or subs
    $block = $self->template(\$block)
        unless ref $block;

    $self->{ BLOCKS }->{ $name } = $block;
}


sub insert {
    my ($self, $file) = @_;
    my ($prefix, $providers, $data, $error);
    my $output = '';

    my $files = ref $file eq ARRAY ? $file : [ $file ];

    $self->debug("insert([ ", join(', '), @$files, " ])") 
        if DEBUG;

    FILE: foreach $file (@$files) {
        my $name = $file;

        if (MSWIN32) {
            # let C:/foo through
            $prefix = $1 if $name =~ s/^(\w{2,})://o;
        }
        else {
            $prefix = $1 if $name =~ s/^(\w+)://;
        }

        if (defined $prefix) {
            $providers = $self->{ PREFIX_MAP }->{ $prefix } 
                || return $self->throw(ERROR_FILE, "no providers for file prefix '$prefix'");
        }
        else {
            $providers = $self->{ PREFIX_MAP }->{ default }
                || $self->{ LOAD_TEMPLATES };
        }

        foreach my $provider (@$providers) {
            next FILE if $data = $provider->load($name);
        }
        $self->throw(ERROR_FILE, "$file: not found");
    }
    continue {
        $output .= $data->{ text };
    }
    return $output;
}


sub process {
    my ($self, $template, $params, $localize) = @_;
    my ($trim, $blocks) = @$self{ qw( TRIM BLOCKS ) };
    my (@compiled, $name, $compiled);
    my ($stash, $component, $tblocks, $error, $tmpout);
    my $output = '';
    
    $template = [ $template ] unless ref $template eq 'ARRAY';
    
    $self->debug(
        "process([ ", join(', '), @$template, ' ], ', 
             defined $params ? $params : '<no params>', ', ', 
             $localize ? '<localized>' : '<unlocalized>', ')'
    ) if DEBUG;
    
    # fetch compiled template for each name specified
    foreach $name (@$template) {
        push(@compiled, $self->template($name));
    }

    if ($localize) {
        # localise the variable stash with any parameters passed
        $stash = $self->{ STASH } = $self->{ STASH }->clone($params ? $params : ());
    } else {
        # update stash with any new parameters passed
        $self->{ STASH }->update($params);
        $stash = $self->{ STASH };
    }

    eval {
        # save current component
        eval { $component = $stash->get('component') };

        foreach $name (@$template) {
            $compiled = shift @compiled;
            $self->debug("compiled template: $name\n") if DEBUG;
            my $element = ref $compiled eq CODE 
                ? { (name => (ref $name ? '' : $name), modtime => time()) }
                : $compiled;

            if (blessed $component && $component->isa(TT2_DOCUMENT)) {
                $element->{ caller  } = $component->{ name };
                $element->{ callers } = $component->{ callers } || [];
                push(@{$element->{ callers }}, $element->{ caller });
            }

            $stash->set( component => $element );
            
            unless ($localize) {
                # merge any local blocks defined in the Template::Document
                # into our local BLOCKS cache
                @$blocks{ keys %$tblocks } = values %$tblocks
                    if (blessed $compiled && $compiled->isa(TT2_DOCUMENT))
                    && ($tblocks = $compiled->blocks());
            }
            
            if (ref $compiled eq CODE) {
                $tmpout = &$compiled($self);
            }
            elsif (ref $compiled) {
                $tmpout = $compiled->process($self);
            }
            else {
                $self->throw(ERROR_FILE, "invalid template reference: $compiled");
            }
            
            if ($trim) {
                for ($tmpout) {
                    s/^\s+//;
                    s/\s+$//;
                }
            }
            $output .= $tmpout;

            # pop last item from callers.  
            # NOTE - this will not be called if template throws an 
            # error.  The whole issue of caller and callers should be 
            # revisited to try and avoid putting this info directly into
            # the component data structure.  Perhaps use a local element
            # instead?

            pop(@{$element->{ callers }})
                if blessed $component && $component->isa(TT2_DOCUMENT);
        }
        $stash->set('component', $component);
    };
    $error = $@;
    
    if ($localize) {
        # ensure stash is delocalised before dying
        $self->{ STASH } = $self->{ STASH }->declone();
    }

    $self->throw(
        ref $error 
          ? $error 
          : (ERROR_FILE, $error)
    ) if $error;
    
    
    return $output;
}


sub include {
    my ($self, $template, $params) = @_;
    return $self->process($template, $params, 'localize me!');
}


#-----------------------------------------------------------------------
# Variable methods
#-----------------------------------------------------------------------

sub define_vmethod {
    shift->stash->define_vmethod(@_);
}


sub define_vmethods {
    shift->stash->define_vmethods(@_);
}


#-----------------------------------------------------------------------
# Filter methods
#-----------------------------------------------------------------------

sub filter {
    my ($self, $name, $args, $alias) = @_;
    my ($provider, $filter, $error);
    
    $self->debug(
        "filter($name, ", 
        $self->dump_data_inline($args),
        defined $alias ? $alias : '<no alias>', 
        ')'
    ) if $DEBUG;
    
    # use any cached version of the filter if no params provided
    return $filter 
        if ! $args && ! ref $name
            && ($filter = $self->{ FILTER_CACHE }->{ $name });
    
    # request the named filter from each of the FILTERS providers in turn
    foreach $provider (@{ $self->{ LOAD_FILTERS } }) {
        last if $filter = $provider->filter($name, $self, $args ? @$args : ());
    }
    
    return $self->throw( filter => "$name: filter not found" )
        unless $filter;
    
    # cache FILTER if alias is valid
    $self->{ FILTER_CACHE }->{ $alias } = $filter
        if $alias;

    return $filter;
}


sub define_filter {
    my ($self, $name, $filter, $is_dynamic) = @_;
    $filter = [ $filter, 1 ] if $is_dynamic;

    return @{ $self->{ LOAD_FILTERS } }
            ? $self->{ LOAD_FILTERS }->[0]->filters( $name => $filter )
            : $self->throw( filter => "No FILTER providers defined to store filter: $name" );
}


#-----------------------------------------------------------------------
# Plugin methods.  TODO: should we have define_plugin() ?
#-----------------------------------------------------------------------

sub plugin {
    my ($self, $name, $args) = @_;
    my ($provider, $plugin, $error);
    
    $self->debug(
        "plugin($name, ", 
        $self->dump_data_inline($args), 
        ')' 
    ) if DEBUG;
    
    # request the named plugin from each of the LOAD_PLUGINS providers in turn
    foreach my $provider (@{ $self->{ LOAD_PLUGINS } }) {
        $self->debug("Asking plugin provider for $name\n") if DEBUG;
        return $plugin
            if defined ($plugin = $provider->plugin($name, $self, $args ? @$args : ()));
    }
    
    $self->throw( plugin => "$name: plugin not found" );
}


#-----------------------------------------------------------------------
# view methods
#-----------------------------------------------------------------------

sub view {
    class(TT2_VIEW)->load->instance(@_);
}

sub define_view {
    my ($self, $name, $params) = @_;
    my $base;
 
    if (defined $params->{ base }) {
        my $base = $self->{ STASH }->get( $params->{ base } );

        return $self->throw_msg( 
            ERROR_VIEW, view_base_undef => $params->{ base }
        ) unless $base;

        return $self->throw_msg(
            ERROR_VIEW, view_base_invalid => TT2_VIEW, $params->{ base }, $base
        ) unless is_object(TT2_VIEW, $base);
        
        $params->{ base } = $base;
    }
    my $view = $self->view($params);
    $view->seal();
    $self->{ STASH }->set($name, $view);
}

sub define_views {
    my ($self, $views) = @_;
    
    # a list reference is better because the order is deterministic (and so
    # allows an earlier VIEW to be the base for a later VIEW), but we'll 
    # accept a hash reference and assume that the user knows the order of
    # processing is undefined
    $views = [ %$views ] 
        if ref $views eq HASH;
    
    # make of copy so we don't destroy the original list reference
    my @items = @$views;
    my ($name, $view);
    
    while (@items) {
        $self->define_view(splice(@items, 0, 2));
    }
}


#-----------------------------------------------------------------------
# Flow control and exception handling methods.
#
# Using exceptions for flow control is usually something to be avoided.  
# However, we have little choice here because it's the only way to escape
# the pre-defined flow control (i.e. caller stack in Perl) in order to 
# implement directives like STOP and RETURN.  We also use it for THROW
# but that's more in keeping with what exceptions should be used for.
#-----------------------------------------------------------------------

sub flow_stop {
    my ($self, $outref) = @_;
    $self->flow_throw( stop => 'STOP' => $outref );
}


sub flow_return {
    my ($self, $outref) = @_;
    $self->flow_throw( return => 'RETURN' => $outref );
}


sub flow_throw {
    my ($self, $type, $info, $output) = @_;

    # This method is called by the code generated by the throw() method
    # in Template::TT2::Directive.  We have to jiggle the arguments around
    # a little to account for various combinations.  We're also being more
    # messy than we have to in order to remain compatible with old skool TT

    if (is_object(TT2_EXCEPTION, $type) || is_object(TT_EXCEPTION, $type)) {
        $self->debug("re-throwing exception object: ", ref $type, " => [$type]\n") if DEBUG;
        die $type;
    }
    elsif (defined $info) {
        $self->debug("creating new exception object: $type => $info\n") if DEBUG;
        die ( 
            TT2_EXCEPTION->new({
                type => $type, 
                info => $info, 
                body => $output
            }) 
        );
    }
    else {
        $type ||= '';
        die (
            TT2_EXCEPTION->new({
                type => undef, 
                info => $type, 
                body => $output,
            })
        );
    }
}


sub catch {
    my ($self, $error, $output) = @_;

    $self->debug("catch('$error', '$output')\n") if DEBUG;
    
    if (blessed $error && $error->isa(TT2_EXCEPTION)) {
        $error->body($output) if $output;
        return $error;
    }
    else {
        return TT2_EXCEPTION->new( 
            type => ERROR_UNDEF, 
            info => $error,
            body => $output,
        );
    }
}


#-----------------------------------------------------------------------
# All output functionality is delegated to the central hub.
#-----------------------------------------------------------------------

sub output_filesystem {
    shift->hub->output_filesystem;
}


sub output_file {
    shift->hub->output_file(@_);
}


sub output {
    shift->hub->output(@_);
}


#-----------------------------------------------------------------------
# Methods relating to variable and template scope.
#-----------------------------------------------------------------------

sub localise {
    my $self = shift;
    $self->{ STASH } = $self->{ STASH }->clone(@_);
}


sub delocalise {
    my $self = shift;
    $self->{ STASH } = $self->{ STASH }->declone();
}


sub visit {
    my ($self, $document, $blocks) = @_;
    unshift(@{ $self->{ BLKSTACK } }, $blocks)
}


sub leave {
    my $self = shift;
    shift(@{ $self->{ BLKSTACK } });
}


sub reset {
    my $self = shift;
    $self->{ BLKSTACK } = [ ];
    $self->{ BLOCKS   } = { %{ $self->{ INIT_BLOCKS } } };
}


#-----------------------------------------------------------------------
# Miscellaneous methods provided for generated template code to call.
#-----------------------------------------------------------------------

sub iterator {
    my ($self, $data) = @_;

    return (is_object(TT2_ITERATOR, $data) || is_object(TT_ITERATOR, $data)) 
        ? $data
        : TT2_ITERATOR->new($data);
}




    
1;

__END__

#------------------------------------------------------------------------
# view(\%config)
# 
# Create a new Template::View bound to this context.
#------------------------------------------------------------------------




#------------------------------------------------------------------------
# define_block($name, $block)
#
# Adds a new BLOCK definition to the local BLOCKS cache.  $block may
# be specified as a reference to a sub-routine or Template::Document
# object or as text which is compiled into a template.  Returns a true
# value (the $block reference or compiled block reference) if
# successful or undef on failure.  Call error() to retrieve the
# relevent error message (i.e. compilation failure).
#------------------------------------------------------------------------

sub define_block {
    my ($self, $name, $block) = @_;
    $block = $self->template(\$block)
    || return undef
        unless ref $block;
    $self->{ BLOCKS }->{ $name } = $block;
}


#------------------------------------------------------------------------
# debugging($command, @args, \%params)
#
# Method for controlling the debugging status of the context.  The first
# argument can be 'on' or 'off' to enable/disable debugging, 'format'
# to define the format of the debug message, or 'msg' to generate a 
# debugging message reporting the file, line, message text, etc., 
# according to the current debug format.
#------------------------------------------------------------------------

sub debugging {
    my $self = shift;
    my $hash = ref $_[-1] eq 'HASH' ? pop : { };
    my @args = @_;

#    print "*** debug(@args)\n";
    if (@args) {
    if ($args[0] =~ /^on|1$/i) {
        $self->{ DEBUG_DIRS } = 1;
        shift(@args);
    }
    elsif ($args[0] =~ /^off|0$/i) {
        $self->{ DEBUG_DIRS } = 0;
        shift(@args);
    }
    }

    if (@args) {
    if ($args[0] =~ /^msg$/i) {
            return unless $self->{ DEBUG_DIRS };
        my $format = $self->{ DEBUG_FORMAT };
        $format = $DEBUG_FORMAT unless defined $format;
        $format =~ s/\$(\w+)/$hash->{ $1 }/ge;
        return $format;
    }
    elsif ($args[0] =~ /^format$/i) {
        $self->{ DEBUG_FORMAT } = $args[1];
    }
    # else ignore
    }

    return '';
}


#------------------------------------------------------------------------
# AUTOLOAD
#
# Provides pseudo-methods for read-only access to various internal 
# members.  For example, templates(), plugins(), filters(),
# eval_perl(), load_perl(), etc.  These aren't called very often, or
# may never be called at all.
#------------------------------------------------------------------------

sub AUTOLOAD {
    my $self   = shift;
    my $method = $AUTOLOAD;
    my $result;

    $method =~ s/.*:://;
    return if $method eq 'DESTROY';

    warn "no such context method/member: $method\n"
    unless defined ($result = $self->{ uc $method });

    return $result;
}


#------------------------------------------------------------------------
# DESTROY
#
# Stash may contain references back to the Context via macro closures,
# etc.  This breaks the circular references. 
#------------------------------------------------------------------------

sub DESTROY {
    my $self = shift;
    undef $self->{ STASH };
}



#========================================================================
#                     -- PRIVATE METHODS --
#========================================================================

#------------------------------------------------------------------------
# _init(\%config)
#
# Initialisation method called by Template::Base::new()
#------------------------------------------------------------------------


#------------------------------------------------------------------------
# _dump()
#
# Debug method which returns a string representing the internal state
# of the context object.
#------------------------------------------------------------------------

sub _dump {
    my $self = shift;
    my $output = "[Template::Context] {\n";
    my $format = "    %-16s => %s\n";
    my $key;

    foreach $key (qw( RECURSION EVAL_PERL TRIM )) {
    $output .= sprintf($format, $key, $self->{ $key });
    }
    foreach my $pname (qw( LOAD_TEMPLATES LOAD_PLUGINS LOAD_FILTERS )) {
    my $provtext = "[\n";
    foreach my $prov (@{ $self->{ $pname } }) {
        $provtext .= $prov->_dump();
#       $provtext .= ",\n";
    }
    $provtext =~ s/\n/\n        /g;
    $provtext =~ s/\s+$//;
    $provtext .= ",\n    ]";
    $output .= sprintf($format, $pname, $provtext);
    }
    $output .= sprintf($format, STASH => $self->{ STASH }->_dump());
    $output .= '}';
    return $output;
}


1;

__END__
