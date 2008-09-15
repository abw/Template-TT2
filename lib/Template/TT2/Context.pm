package Template::TT2::Context;

use Template::TT2::Modules;
use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Base',
    import    => 'class',
    words     => 'LOAD_',
    constants => 'DEBUG_UNDEF DEBUG_CONTEXT DEBUG_DIRS DEBUG_FLAGS 
                  ARRAY DELIMITER',
    constant  => {
        MODULES => 'Template::TT2::Modules',
    };

our @LOADERS   = qw( templates plugins filters );

sub init {
    my ($self, $config) = @_;
    my $class = $self->class;
    my $debug = $config->{ DEBUG } || $DEBUG;
    my ($key, $load_key, $value, $block, $blocks);

    # LOAD_TEMPLATES, LOAD_PLUGINS, LOAD_FILTERS - lists of providers
    foreach $key (@LOADERS) {
        $load_key = LOAD_ . uc $key;
        $value = $config->{ $key }
              || $config->{ $load_key }
              || MODULES->module( $key => $config );
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

        # hack to get stash to know about debug mode
        $predefs->{ _DEBUG } = ($debug & DEBUG_UNDEF) ? 1 : 0
             unless defined $predefs->{ _DEBUG };
        
        MODULES->module( stash => $predefs );
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
    $self->{ EXPOSE_BLOCKS } = defined $config->{ EXPOSE_BLOCKS }
                                     ? $config->{ EXPOSE_BLOCKS } : 0;

    return $self;
}


sub reset {
#    shift->todo;
}

1;

__END__
sub template {
    my ($self, $name) = @_;
    my ($prefix, $blocks, $defblocks, $provider, $template, $error);
    my ($shortname, $blockname, $providers);

    $self->debug("template($name)") if $self->{ DEBUG };

    # references to Template::Document (or sub-class) objects objects, or
    # CODE references are assumed to be pre-compiled templates and are
    # returned intact
    return $name
        if UNIVERSAL::isa($name, 'Template::Document')
            || ref($name) eq 'CODE';

    $shortname = $name;

    unless (ref $name) {
        
        $self->debug("looking for block [$name]") if $self->{ DEBUG };

        # we first look in the BLOCKS hash for a BLOCK that may have 
        # been imported from a template (via PROCESS)
        return $template
            if ($template = $self->{ BLOCKS }->{ $name });
        
        # then we iterate through the BLKSTACK list to see if any of the
        # Template::Documents we're visiting define this BLOCK
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
            || return $self->throw( Template::Constants::ERROR_FILE,
                                    "no providers for template prefix '$prefix'");
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
        $self->debug("asking providers for [$shortname] [$blockname]") 
            if $self->{ DEBUG };

        foreach my $provider (@$providers) {
            ($template, $error) = $provider->fetch($shortname, $prefix);
            if ($error) {
                if ($error == Template::Constants::STATUS_ERROR) {
                    # $template contains exception object
                    if (UNIVERSAL::isa($template, 'Template::Exception')
                        && $template->type() eq Template::Constants::ERROR_FILE) {
                        $self->throw($template);
                    }
                    else {
                        $self->throw( Template::Constants::ERROR_FILE, $template );
                    }
                }
                # DECLINE is ok, carry on
            }
            elsif (length $blockname) {
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
        
    $self->throw(Template::Constants::ERROR_FILE, "$name: not found");
}


#------------------------------------------------------------------------
# plugin($name, \@args)
#
# Calls on each of the LOAD_PLUGINS providers in turn to fetch() (i.e. load
# and instantiate) a plugin of the specified name.  Additional parameters 
# passed are propagated to the new() constructor for the plugin.  
# Returns a reference to a new plugin object or other reference.  On 
# error, undef is returned and the appropriate error message is set for
# subsequent retrieval via error().
#------------------------------------------------------------------------

sub plugin {
    my ($self, $name, $args) = @_;
    my ($provider, $plugin, $error);
    
    $self->debug("plugin($name, ", defined $args ? @$args : '[ ]', ')')
        if $self->{ DEBUG };
    
    # request the named plugin from each of the LOAD_PLUGINS providers in turn
    foreach my $provider (@{ $self->{ LOAD_PLUGINS } }) {
        ($plugin, $error) = $provider->fetch($name, $args, $self);
        return $plugin unless $error;
        if ($error == Template::Constants::STATUS_ERROR) {
            $self->throw($plugin) if ref $plugin;
            $self->throw(Template::Constants::ERROR_PLUGIN, $plugin);
        }
    }
    
    $self->throw(Template::Constants::ERROR_PLUGIN, "$name: plugin not found");
}


#------------------------------------------------------------------------
# filter($name, \@args, $alias)
#
# Similar to plugin() above, but querying the LOAD_FILTERS providers to 
# return filter instances.  An alias may be provided which is used to
# save the returned filter in a local cache.
#------------------------------------------------------------------------

sub filter {
    my ($self, $name, $args, $alias) = @_;
    my ($provider, $filter, $error);
    
    $self->debug("filter($name, ", 
                 defined $args  ? @$args : '[ ]', 
                 defined $alias ? $alias : '<no alias>', ')')
        if $self->{ DEBUG };
    
    # use any cached version of the filter if no params provided
    return $filter 
        if ! $args && ! ref $name
            && ($filter = $self->{ FILTER_CACHE }->{ $name });
    
    # request the named filter from each of the FILTERS providers in turn
    foreach my $provider (@{ $self->{ LOAD_FILTERS } }) {
        ($filter, $error) = $provider->fetch($name, $args, $self);
        last unless $error;
        if ($error == Template::Constants::STATUS_ERROR) {
            $self->throw($filter) if ref $filter;
            $self->throw(Template::Constants::ERROR_FILTER, $filter);
        }
        # return $self->error($filter)
        #    if $error == &Template::Constants::STATUS_ERROR;
    }
    
    return $self->error("$name: filter not found")
        unless $filter;
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # commented out by abw on 19 Nov 2001 to fix problem with xmlstyle
    # plugin which may re-define a filter by calling define_filter()
    # multiple times.  With the automatic aliasing/caching below, any
    # new filter definition isn't seen.  Don't think this will cause
    # any problems as filters explicitly supplied with aliases will
    # still work as expected.
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # alias defaults to name if undefined
    # $alias = $name
    #     unless defined($alias) or ref($name) or $args;

    # cache FILTER if alias is valid
    $self->{ FILTER_CACHE }->{ $alias } = $filter
        if $alias;

    return $filter;
}


#------------------------------------------------------------------------
# view(\%config)
# 
# Create a new Template::View bound to this context.
#------------------------------------------------------------------------

sub view {
    my $self = shift;
    require Template::View;
    return Template::View->new($self, @_)
        || $self->throw(&Template::Constants::ERROR_VIEW, 
                        $Template::View::ERROR);
}


#------------------------------------------------------------------------
# process($template, \%params)         [% PROCESS template var=val ... %]
# process($template, \%params, $local) [% INCLUDE template var=val ... %]
#
# Processes the template named or referenced by the first parameter.
# The optional second parameter may reference a hash array of variable
# definitions.  These are set before the template is processed by
# calling update() on the stash.  Note that, unless the third parameter
# is true, the context is not localised and these, and any other
# variables set in the template will retain their new values after this
# method returns.  The third parameter is in place so that this method
# can handle INCLUDE calls: the stash will be localized.
#
# Returns the output of processing the template.  Errors are thrown
# as Template::Exception objects via die().  
#------------------------------------------------------------------------

sub process {
    my ($self, $template, $params, $localize) = @_;
    my ($trim, $blocks) = @$self{ qw( TRIM BLOCKS ) };
    my (@compiled, $name, $compiled);
    my ($stash, $component, $tblocks, $error, $tmpout);
    my $output = '';
    
    $template = [ $template ] unless ref $template eq 'ARRAY';
    
    $self->debug("process([ ", join(', '), @$template, ' ], ', 
                 defined $params ? $params : '<no params>', ', ', 
                 $localize ? '<localized>' : '<unlocalized>', ')')
        if $self->{ DEBUG };
    
    # fetch compiled template for each name specified
    foreach $name (@$template) {
        push(@compiled, $self->template($name));
    }

    if ($localize) {
        # localise the variable stash with any parameters passed
        $stash = $self->{ STASH } = $self->{ STASH }->clone($params);
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
            my $element = ref $compiled eq 'CODE' 
                ? { (name => (ref $name ? '' : $name), modtime => time()) }
                : $compiled;

            if (UNIVERSAL::isa($component, 'Template::Document')) {
                $element->{ caller } = $component->{ name };
                $element->{ callers } = $component->{ callers } || [];
                push(@{$element->{ callers }}, $element->{ caller });
            }

            $stash->set('component', $element);
            
            unless ($localize) {
                # merge any local blocks defined in the Template::Document
                # into our local BLOCKS cache
                @$blocks{ keys %$tblocks } = values %$tblocks
                    if UNIVERSAL::isa($compiled, 'Template::Document')
                    && ($tblocks = $compiled->blocks());
            }
            
            if (ref $compiled eq 'CODE') {
                $tmpout = &$compiled($self);
            }
            elsif (ref $compiled) {
                $tmpout = $compiled->process($self);
            }
            else {
                $self->throw('file', 
                             "invalid template reference: $compiled");
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
                if (UNIVERSAL::isa($component, 'Template::Document'));
        }
        $stash->set('component', $component);
    };
    $error = $@;
    
    if ($localize) {
        # ensure stash is delocalised before dying
        $self->{ STASH } = $self->{ STASH }->declone();
    }
    
    $self->throw(ref $error 
                 ? $error : (Template::Constants::ERROR_FILE, $error))
        if $error;
    
    return $output;
}


#------------------------------------------------------------------------
# include($template, \%params)    [% INCLUDE template   var = val, ... %]
#
# Similar to process() above but processing the template in a local 
# context.  Any variables passed by reference to a hash as the second
# parameter will be set before the template is processed and then 
# revert to their original values before the method returns.  Similarly,
# any changes made to non-global variables within the template will 
# persist only until the template is processed.
#
# Returns the output of processing the template.  Errors are thrown
# as Template::Exception objects via die().  
#------------------------------------------------------------------------

sub include {
    my ($self, $template, $params) = @_;
    return $self->process($template, $params, 'localize me!');
}

#------------------------------------------------------------------------
# insert($file)
#
# Insert the contents of a file without parsing.
#------------------------------------------------------------------------

sub insert {
    my ($self, $file) = @_;
    my ($prefix, $providers, $text, $error);
    my $output = '';

    my $files = ref $file eq 'ARRAY' ? $file : [ $file ];

    $self->debug("insert([ ", join(', '), @$files, " ])") 
        if $self->{ DEBUG };


    FILE: foreach $file (@$files) {
    my $name = $file;

    if ($^O eq 'MSWin32') {
        # let C:/foo through
        $prefix = $1 if $name =~ s/^(\w{2,})://o;
    }
    else {
        $prefix = $1 if $name =~ s/^(\w+)://;
    }

    if (defined $prefix) {
        $providers = $self->{ PREFIX_MAP }->{ $prefix } 
        || return $self->throw(Template::Constants::ERROR_FILE,
                   "no providers for file prefix '$prefix'");
    }
    else {
        $providers = $self->{ PREFIX_MAP }->{ default }
        || $self->{ LOAD_TEMPLATES };
    }

    foreach my $provider (@$providers) {
        ($text, $error) = $provider->load($name, $prefix);
        next FILE unless $error;
        if ($error == Template::Constants::STATUS_ERROR) {
        $self->throw($text) if ref $text;
        $self->throw(Template::Constants::ERROR_FILE, $text);
        }
    }
    $self->throw(Template::Constants::ERROR_FILE, "$file: not found");
    }
    continue {
    $output .= $text;
    }
    return $output;
}


#------------------------------------------------------------------------
# throw($type, $info, \$output)          [% THROW errtype "Error info" %]
#
# Throws a Template::Exception object by calling die().  This method
# may be passed a reference to an existing Template::Exception object;
# a single value containing an error message which is used to
# instantiate a Template::Exception of type 'undef'; or a pair of
# values representing the exception type and info from which a
# Template::Exception object is instantiated.  e.g.
#
#   $context->throw($exception);
#   $context->throw("I'm sorry Dave, I can't do that");
#   $context->throw('denied', "I'm sorry Dave, I can't do that");
#
# An optional third parameter can be supplied in the last case which 
# is a reference to the current output buffer containing the results
# of processing the template up to the point at which the exception 
# was thrown.  The RETURN and STOP directives, for example, use this 
# to propagate output back to the user, but it can safely be ignored
# in most cases.
# 
# This method rides on a one-way ticket to die() oblivion.  It does not 
# return in any real sense of the word, but should get caught by a 
# surrounding eval { } block (e.g. a BLOCK or TRY) and handled 
# accordingly, or returned to the caller as an uncaught exception.
#------------------------------------------------------------------------

sub throw {
    my ($self, $error, $info, $output) = @_;
    local $" = ', ';

    # die! die! die!
    if (UNIVERSAL::isa($error, 'Template::Exception')) {
    die $error;
    }
    elsif (defined $info) {
    die (Template::Exception->new($error, $info, $output));
    }
    else {
    $error ||= '';
    die (Template::Exception->new('undef', $error, $output));
    }

    # not reached
}


#------------------------------------------------------------------------
# catch($error, \$output)
#
# Called by various directives after catching an error thrown via die()
# from within an eval { } block.  The first parameter contains the errror
# which may be a sanitized reference to a Template::Exception object
# (such as that raised by the throw() method above, a plugin object, 
# and so on) or an error message thrown via die from somewhere in user
# code.  The latter are coerced into 'undef' Template::Exception objects.
# Like throw() above, a reference to a scalar may be passed as an
# additional parameter to represent the current output buffer
# localised within the eval block.  As exceptions are thrown upwards
# and outwards from nested blocks, the catch() method reconstructs the
# correct output buffer from these fragments, storing it in the
# exception object for passing further onwards and upwards.
#
# Returns a reference to a Template::Exception object..
#------------------------------------------------------------------------

sub catch {
    my ($self, $error, $output) = @_;

    if (UNIVERSAL::isa($error, 'Template::Exception')) {
    $error->text($output) if $output;
    return $error;
    }
    else {
    return Template::Exception->new('undef', $error, $output);
    }
}


#------------------------------------------------------------------------
# localise(\%params)
# delocalise()
#
# The localise() method creates a local copy of the current stash,
# allowing the existing state of variables to be saved and later 
# restored via delocalise().
#
# A reference to a hash array may be passed containing local variable 
# definitions which should be added to the cloned namespace.  These 
# values persist until delocalisation.
#------------------------------------------------------------------------

sub localise {
    my $self = shift;
    $self->{ STASH } = $self->{ STASH }->clone(@_);
}

sub delocalise {
    my $self = shift;
    $self->{ STASH } = $self->{ STASH }->declone();
}


#------------------------------------------------------------------------
# visit($document, $blocks)
#
# Each Template::Document calls the visit() method on the context
# before processing itself.  It passes a reference to the hash array
# of named BLOCKs defined within the document, allowing them to be 
# added to the internal BLKSTACK list which is subsequently used by
# template() to resolve templates.
# from a provider.
#------------------------------------------------------------------------

sub visit {
    my ($self, $document, $blocks) = @_;
    unshift(@{ $self->{ BLKSTACK } }, $blocks)
}


#------------------------------------------------------------------------
# leave()
#
# The leave() method is called when the document has finished
# processing itself.  This removes the entry from the BLKSTACK list
# that was added visit() above.  For persistence of BLOCK definitions,
# the process() method (i.e. the PROCESS directive) does some extra
# magic to copy BLOCKs into a shared hash.
#------------------------------------------------------------------------

sub leave {
    my $self = shift;
    shift(@{ $self->{ BLKSTACK } });
}


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
# define_filter($name, $filter, $is_dynamic)
#
# Adds a new FILTER definition to the local FILTER_CACHE.
#------------------------------------------------------------------------

sub define_filter {
    my ($self, $name, $filter, $is_dynamic) = @_;
    my ($result, $error);
    $filter = [ $filter, 1 ] if $is_dynamic;

    foreach my $provider (@{ $self->{ LOAD_FILTERS } }) {
    ($result, $error) = $provider->store($name, $filter);
    return 1 unless $error;
    $self->throw(&Template::Constants::ERROR_FILTER, $result)
        if $error == &Template::Constants::STATUS_ERROR;
    }
    $self->throw(&Template::Constants::ERROR_FILTER, 
         "FILTER providers declined to store filter $name");
}


#------------------------------------------------------------------------
# reset()
# 
# Reset the state of the internal BLOCKS hash to clear any BLOCK 
# definitions imported via the PROCESS directive.  Any original 
# BLOCKS definitions passed to the constructor will be restored.
#------------------------------------------------------------------------

sub reset {
    my ($self, $blocks) = @_;
    $self->{ BLKSTACK } = [ ];
    $self->{ BLOCKS   } = { %{ $self->{ INIT_BLOCKS } } };
}


#------------------------------------------------------------------------
# stash()
#
# Simple accessor methods to return the STASH values.  This is likely
# to be called quite often so we provide a direct method rather than
# relying on the slower AUTOLOAD.
#------------------------------------------------------------------------

sub stash {
    return $_[0]->{ STASH };
}


#------------------------------------------------------------------------
# define_vmethod($type, $name, \&sub)
#
# Passes $type, $name, and &sub on to stash->define_vmethod().
#------------------------------------------------------------------------
sub define_vmethod {
    my $self = shift;
    $self->stash->define_vmethod(@_);
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
