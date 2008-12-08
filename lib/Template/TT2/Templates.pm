package Template::TT2::Templates;

use Template::TT2::Document;
use Template::TT2::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Template::TT2::Base',
    import      => 'class',
    utils       => 'blessed md5_hex textlike',
    codec       => 'unicode',
    accessors   => 'hub',
    filesystem  => 'FS VFS Cwd Dir File',
    constants   => 
       'SCALAR ARRAY HASH GLOB BLANK UNICODE DEBUG_TEMPLATES DEBUG_FLAGS 
        TT2_DOCUMENT TT2_CACHE TT2_STORE MSWIN32',
    constant    => {
        INPUT_TEXT    => 'input text',
        INPUT_FH      => 'input file handle',
        LOOKUP_PATH   => 0,     # slots in cached lookup results
        LOOKUP_TIME   => 1,
        TEXT_PREFIX   => 'md5:',
        URI_ROOT      => '/',
        IS_ABS_URI    => qr[^/],
    },
    config      => [
        'DOCUMENT|class:DOCUMENT|method:TT2_DOCUMENT',
#        'PARSER|class:PARSER|method:TT2_PARSER',
        'CACHE|class:CACHE|method:TT2_CACHE',
        'STORE|class:STORE|method:TT2_STORE',
        'INCLUDE_PATH|class:INCLUDE_PATH|method:Cwd',
        'DYNAMIC_PATH|class:DYNAMIC_PATH=0',
        'MAX_DIRS|class:MAX_DIRS=32',
        'STAT_TTL|class:STAT_TTL=1',
        'TOLERANT|class:TOLERANT=0',            # NOT USED
        'COMPILE_EXT|class:COMPILE_EXT|method:BLANK',
        'DEFAULT|class:DEFAULT',
        'UNICODE|method:UNICODE',
    ],
    messages => {
        deprecated    => "The %s option is deprecated.  The '%s' directory has been added to your INCLUDE_PATH instead.",
        no_absolute   => "The ABSOLUTE option has been deprecated.  Please add '/' to your INCLUDE_PATH",
        no_relative   => "The RELATIVE option has been deprecated.  Please add '.' to your INCLUDE_PATH",
        not_ref       => 'Template specified is not a reference: %s',
        bad_ref       => 'Template specified is an invalid reference: %s',
        bad_cache     => 'Template CACHE is an invalid reference: %s',
    };
        

# hack so that 'use bytes' will compile on versions of Perl earlier than
# 5.6, even though we never call _decode_unicode() on those systems
BEGIN {
    if ($] < 5.006) {
        package bytes;
        $INC{'bytes.pm'} = 1;
    }
}


sub init {
    my ($self, $config) = @_;
    my $class = $self->class;

    $self->configure($config);
    $self->init_hub($config);
    $self->init_path($config);
    $self->init_cache($config);
    $self->init_store($config);

    # warn that the ABSOLUTE and RELATIVE options are deprecated
    # save config for when we need to initiate a parser
    $self->{ config } = $config;
    
    return $self;
}


sub init_path {
    my ($self, $config) = @_;
    my ($path, $dir);
    
    # create a virtual filesystem across the INCLUDE_PATH
    $path = $self->{ INCLUDE_PATH } || $self->class->list_vars('INCLUDE_PATH');
    $path = [ $path ] unless ref $path eq ARRAY;

    # ABSOLUTE option is officially deprecated, but we can emulate it by 
    # adding '/' to the INCLUDE_PATH.  However, the handling of template
    # paths in templates has changed so it's not exactly the same thing. 
    if ($config->{ ABSOLUTE }) {
        $dir = FS->root;
        $self->warn_msg( deprecated => ABSOLUTE => $dir );
        push(@$path, $dir);
    }

    # ditto RELATIVE
    if ($config->{ RELATIVE }) {
        $dir = FS->cwd;
        $self->warn_msg( deprecated => RELATIVE => $dir );
        push(@$path, $dir);
    }

    $self->{ PATH } = $path;
    $self->{ FS   } = FS->new;
    $self->{ VFS  } = VFS->new( 
        root      => $path,
        dynamic   => $self->{ DYNAMIC_PATH },
        max_roots => $self->{ MAX_DIRS },
    );

    $self->debug(
        'Created template virtual filesystem across ', 
        join(', ', @$path), "\n"
    ) if DEBUG;
}


sub init_cache {
    my ($self, $config) = @_;
    my $cache = $self->{ CACHE };

    # In addition to the memory cache provided by Template::Cache (which
    # saves us from having to re-compile templates unless they've changed)
    # we also maintain a LOOKUP table which maps a template name to the 
    # specific file that provided it and the time that we should check it
    # again to see if it has changed (time now  + STAT_TTL seconds).  This 
    # saves us from making repeated stat() calls on a file (or reads from a 
    # database) in rapid succession when the chances of a file changing are
    # very slim.
    $self->{ LOOKUP } = { };

    # The default CACHE value is the name of the in-memory cache module
    # (Template::TT2::Cache), but can be set to a different module name or 
    # a cache object
    if (ref $cache) {
        # we'll be a bit lax here and only check that we've got an object,
        # a stronger approach would be to assert that $cache isa 
        # Template::Cache or Cache::Cache, or to check it can fetch()/store()
        $self->error_msg( bad_cache => $cache ) unless blessed $cache;
        $self->debug("Using user-supplied template cache: $cache\n") if DEBUG;
    }
    elsif (defined (my $size = $config->{ CACHE_SIZE })) {
        # create cache, note that CACHE_SIZE => 0 indicates no caching
        if ($size) {
            $self->debug("Creating template cache of limited size: $size\n") if DEBUG;
            class($cache)->load;
            $self->{ CACHE } = $cache->new( size => $size );
        }
        else {
            $self->debug("Template caching is disabled\n") if DEBUG;
        }
    }
    else {
        # create cache with default size (unlimited)
        $self->debug("Creating template cache of unlimited size\n") if DEBUG;
        class($cache)->load;
        $self->{ CACHE } = $cache->new;
    }
}


sub init_store {
    my ($self, $config) = @_;
    my $store = $self->{ STORE };
    my $cdir  = $config->{ COMPILE_DIR };
    my $cext  = $config->{ COMPILE_EXT };
    
    if (ref $store) {
        # use store object provided
        $self->error_msg( bad_store => $store ) unless blessed $store;
        $self->debug("Using user-supplied template store: $store\n") if DEBUG;
    }
    elsif (defined $cdir || $cext) {
        # create new store for compiled templates
        $self->debug("Creating template store in $cdir / $cext\n") if DEBUG;
        class($store)->load;
        $self->{ STORE } = $store->new( 
            directory => $cdir,
            extension => $cext,
        );
    }
    else {
        # we're not storing compiled templates
        delete $self->{ STORE };
    }
}


sub fetch {
    my ($self, $name) = @_;

    $self->debug("fetch($name)\n") if DEBUG;

    return $self->fetch_ref($name)
        unless textlike $name;          # allows objects which stringify

    return $self->fetch_name($name)
        || defined($self->{ DEFAULT })
        && $self->fetch_name($self->{ DEFAULT });
}


sub fetch_ref {
    my ($self, $ref, $alias) = @_;
    my $type = ref $ref
        || return $self->error_msg( not_ref => $ref );
    my ($text, $data, $uri);

    $self->debug("fetch_ref($ref)\n") if DEBUG;
    
    # $ref can be a SCALAR reference to template text or a GLOB reference
    # (file handle) from which the template text can be read.
    
    if ($type eq SCALAR) {
        $self->debug("read template source from SCALAR ref\n") if DEBUG;
        $alias = INPUT_TEXT unless defined $alias;
        $text  = $$ref;
    }
    elsif ($type eq GLOB) {
        $self->debug("read template source from GLOB ref\n") if DEBUG;
        local $/;
        $text  = <$ref>;
        $text  = decode($text) if $self->{ UNICODE };
        $alias = INPUT_FH unless defined $alias;
    }
    else {
        return $self->error_msg( bad_ref => $ref );
    }

    # generate unique cache key from text
    $uri = $self->text_id(\$text);
    
    # fetch from cache or prepare anew
    return $self->cache_fetch($uri)
        || $self->prepare({
                uri      => $uri,
                name     => $alias,
                text     => $text,
#                hello    => 'world',
                loaded   => 0,      # not loaded from a file
                modified => 0,      # modification time
            });
}


sub fetch_name {
    my ($self, $name) = @_;
    my ($data, $uri, $info, $file, $text);
#   my $path = $self->{ VFS }->absolute($name);   # TODO: should be URI space not, native FS
#   my $path = ($name =~ IS_ABS_URI) ? $name : URI_ROOT.$name;
    my $path = $name;

    $self->debug("fetch_name($name) => $path\n") if DEBUG;

    # If we're not using a DYNAMIC_PATH then the absolute uri for the 
    # template name will always map to the same template file.  We maintain
    # a lookup table which tells us if a requested template has previously 
    # been found or not found and when that happened.  This allows us to skip 
    # a full INCLUDE_PATH search if the information is recent enough.  e.g.
    #      /site/header  => ['/full/path/to/site/header', $time]  # FOUND
    #      /missing/file => [undef, $time]                        # NOT FOUND
    
    STATIC_LOOKUP: {
        last STATIC_LOOKUP 
            if $self->{ DYNAMIC_PATH };
            
        last STATIC_LOOKUP 
            unless $data = $self->{ LOOKUP }->{ $path };
        
        # delete and ignore lookup entry if it's gone stale
        # TODO: offset on entry, save the addition on each check
        if (time > $data->[LOOKUP_TIME]) {
            $self->debug("$path lookup data has expired\n") if DEBUG;
            delete $self->{ LOOKUP }->{ $path };
            last STATIC_LOOKUP;                             # STALE LOOKUP
        }
            
        # if the lookup failed then it'll fail again so we can bail early
        unless ($uri = $data->[LOOKUP_PATH]) {
            $self->debug("$path was previously not found\n") if DEBUG;
            return undef;                                   # NOT FOUND 
        }
            
        # otherwise we have a definitive uri which we can use to fetch
        # the compiled template from the cache without having to trawl 
        # through all INCLUDE_PATH directories on the disk
        $self->debug("$path was previously found as $uri\n") if DEBUG;
            
        if ($data = $self->cache_fetch($uri)) {             # TODO: modified?
            return $data;                                   # FOUND
        }
        else {
            $self->debug("$uri has expired from the cache\n") if DEBUG;
            delete $self->{ LOOKUP }->{ $path };
        }
    }

    $data = $self->load($path)
        || return $self->missing($path);                    # NOT FOUND

    $uri = $data->{ uri } 
        ||= $path;
        
    $self->debug("$path found at $uri\n") if DEBUG;
    
    # check for cached template or prepare from source
    return $self->cache_fetch($uri, $data->{ modified })    # FOUND IN CACHE
        || $self->prepare($data);                           # PREPARED AFRESH
}


sub load {
    my ($self, $path) = @_;
    my $file = $self->{ VFS }->file($path);
    return undef
        unless $file->exists;
    my $uri  = $file->definitive;
    my $text = $file->text;

    $text = decode($text) 
        if $self->{ UNICODE };
    
    return {
        uri      => $uri,
        name     => $file->name,
        path     => $path,
        text     => $text,
        loaded   => time,
        modified => $file->modified,
   };
}


sub missing {
    my ($self, $path) = @_;
    $self->debug("$path not found\n") if DEBUG;
    $self->{ LOOKUP }->{ $path } = [undef,time + $self->{ STAT_TTL }]
        unless $self->{ DYNAMIC_PATH };
    return undef;
}


sub text_id {
    my ($self, $textref) = @_;
    return $self->TEXT_PREFIX . md5_hex($$textref);
}


sub cache_fetch {
    my ($self, $id, $modified) = @_;
    my $data;
    
    # see if the named template is in the cache
    if ($self->{ CACHE } && ($data = $self->{ CACHE }->get($id))) {
        $self->debug("$id found in the cache\n") if DEBUG;
        
        if (! $modified || $modified == $data->{ modified }) {
            # return cached document object unequivically if there's no
            # $modified argument for us to compare against or if it 
            # matches that of the template source it was created from
            $self->debug("returning $data->{ document }\n") if DEBUG;
            
            # create/update LOOKUP entry for faster path matching
            $self->add_lookup_path($data);

            return $data->{ document };
        }
        $self->debug("cached modification time $data->{ modified } does not match $modified") if DEBUG;
    }

    if ($self->{ STORE } && ($data = $self->{ STORE }->get($id))) {
        $self->debug("$id found in the store\n") if DEBUG;
        
        # as above with the only difference being that $data returned from
        # the store is already a Template::TT2::Document object.
        if (! $modified || $modified == $data->modified) {      # TODO: ->modified($modified)
            $self->debug("returning $data\n") if DEBUG;
            $self->add_lookup_path($data);
            return $data;
        }
        $self->debug("stored modification time $data->{ modified } does not match $modified") if DEBUG;
    }
    
    return undef;
}

    
sub cache_store {
    my ($self, $id, $data) = @_;
    my $parsed = delete($data->{ parsed });     # we don't want this in memory
    my $file;

    if ($self->{ CACHE }) {
        $self->debug("storing $id in memory cache\n") if DEBUG;
        $self->{ CACHE }->set($id, $data);
    }
    
    $self->debug("parsed data: ", $self->dump_data($parsed), "\n") if DEBUG;
    
    # add to store - this needs refactoring along with Template::TT2::Document
    if ($parsed && $self->{ STORE }) {
        $self->debug("storing $id in compiled template store\n") if DEBUG;
        $self->{ STORE }->set($id, $parsed);
    }
}


sub prepare {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $text = delete($args->{ text }) || return $self->error('No text to compile');
    my ($parser, $parsed, $doctype, $document);

#    $self->debug_caller;
#    $self->debug("prepare(", $self->dump_data_inline($args), ")\n")
#        if DEBUG;          # NOTE: text has been deleted aready

    $parser = $self->parser;

    # have the parser parse the template
    $parsed = $parser->parse($text, $args)
        || return $self->error("Parser returned false value");  # shouldn't happen?
        
    # augment metadata with the name and modification time
    $parsed->{ METADATA } = {
        name     => $args->{ name     },
        modtime  => $args->{ modified },    # old skool
        modified => $args->{ modified },    # new skool
        %{ $parsed->{ METADATA } },
    };

    # save the parsed data back into the args 
    $args->{ parsed } = $parsed;

    # create document object
    $document = $args->{ document } = $self->{ DOCUMENT }->new($parsed);

    # add to cache to save re-compiling templates
    $self->cache_store($args->{ uri }, $args)
        if $args->{ uri } && $self->{ CACHE };

    # add to LOOKUP table for faster path resolution next time
    $self->add_lookup_path($args);

    $self->debug("prepared document: $document\n") if DEBUG;
        
    return $document;
}


sub add_lookup_path {
    my ($self, $args) = @_;

    return 
        if   $self->{ DYNAMIC_PATH }
        or ! $args->{ uri      }        # must have unique id
        or ! $args->{ path     }        # must have path it came from
        or ! $args->{ modified };       # must have modification time
    
    $self->{ LOOKUP }->{ $args->{ path } } = [
        $args->{ uri      }, 
        $args->{ modified } + $self->{ STAT_TTL }
    ];       
    $self->debug(
        "added LOOKUP entry for $args->{ path } => [$args->{ uri }, ",
        $args->{ modified } + $self->{ STAT_TTL },
        "]\n"
    ) if DEBUG;
}


sub parser {
    return $_[0]->{ parser } 
       ||= $_[0]->hub->module('parser');
}


1;

__END__    

=head1 NAME

Template::TT2::Templates - Provider module for loading/compiling templates

=head1 SYNOPSIS

    use Template::TT2::Templates;
    
    my $templates = Template::TT2::Templates->new(\%options);
    my $template  = $templates->fetch('example.tt2')
        || die $templates->reason;

=head1 INTRODUCTION

The L<Template::TT2> distribution is a new implementation of the Template 
Toolkit v2.  It is a legacy version of the TT2 language written on top of
the generic L<Badger> modules.  

This module supercedes L<Template::Provider>.  In-memory caching of templates
is now delegated to the L<Template::TT2::Cache> module.  Persistent storage
of compiled templates is now delegated to the L<Template::TT2::Store> module.

The documentation has has a quick make-over, but may be incorrect or 
incomplete in places.

=head1 DESCRIPTION

The L<Template::TT2::Templates> is used to load, parse, compile and cache
template documents. This object may be sub-classed to provide more specific
facilities for loading, or otherwise providing access to templates.

The L<Template::TT2::Context> objects maintain a list of
L<Template::TT2::Templates> objects which are polled in turn (via L<fetch()>)
to return a requested template. Each may return a compiled template, raise an
error, or decline to serve the request, giving subsequent providers a chance
to do so.

=head1 PUBLIC METHODS

The following methods are implemented in addition to those inherited from 
the L<Template::TT2::Base> module and its base class, L<Badger::Base>.

=head2 fetch($name)

Returns a compiled template for the name specified. If the template cannot be
found then C<(undef)> is returned. Errors are thrown as exceptions.

=head2 load($name)

Loads a template but does not compile it.  Returns a reference to a hash
array containing information about the template and its source text.

=head2 text_id()

=head1 PRIVATE METHODS

These methods are used internally.

=head2 init_path($config)

Initialises the C<INCLUDE_PATH> and related parameters.

=head2 init_cache($config)

Initialises the L<cache|Template::TT2::Cache> used for caching compiled
templates in memory.

=head2 init_store($config)

Initialises the L<store|Template::TT2::Store> used for storing compiled
templates on disk.

=head2 fetch_ref($ref)

Fetches a template from a reference (e.g. reference to text, file handle, 
etc).

=head2 fetch_name($name)

Fetches a template by name.

=head2 missing($name)

Called internally when a requested template cannot be found.  This method
can be re-defined in a subclass to implement a different behaviour.

=head2 cache_fetch($name)

Fetches a pre-compiled template. It looks first in the in-memory cache, then
in the persistent store (where applicable). Returns the compiled template or
C<undef> if not found.

=head2 cache_store($name,$template)

Stores a compiled template in the in-memory cache and/or on-disk store 
(where applicable).

=head2 prepare($data)

Compiles the template data structure returned by L<load()> into a 
template object.

=head2 add_lookup_path($path)

Used internally for path lookup optimisation.

=head2 parser

Returns a L<parse|Template::TT2::Parser> object for compiling templates.

=head1 TODO: OLD METHODS

These methods were defined in L<Template::Provider>.  Do we need to provide
them, or equivalents of them?

=head2 include_path(\@newpath)

Accessor method for the C<INCLUDE_PATH> setting.  If called with an
argument, this method will replace the existing C<INCLUDE_PATH> with
the new value.

=head2 paths()

This method generates a copy of the C<INCLUDE_PATH> list.  Any elements in the
list which are dynamic generators (e.g. references to subroutines or objects
implementing a C<paths()> method) will be called and the list of directories 
returned merged into the output list.

It is possible to provide a generator which returns itself, thus sending
this method into an infinite loop.  To detect and prevent this from happening,
the C<$MAX_DIRS> package variable, set to C<64> by default, limits the maximum
number of paths that can be added to, or generated for the output list.  If
this number is exceeded then the method will immediately return an error 
reporting as much.

=head1 CONFIGURATION OPTIONS

The following list summarises the configuration options that can be provided
to the C<Template::TT2::Templates> L<new()> constructor. Please consult
L<Template::Manual::Config> for further details and examples of each
configuration option in use.

=head2 INCLUDE_PATH

The L<INCLUDE_PATH|Template::Manual::Config#INCLUDE_PATH> option is used to
specify one or more directories in which template files are located.

    # single path
    my $provider = Template::TT2::Templates->new({
        INCLUDE_PATH => '/usr/local/templates',
    });

    # multiple paths
    my $provider = Template::TT2::Templates->new({
        INCLUDE_PATH => [ 
            '/usr/local/templates', 
            '/tmp/my/templates' 
        ],
    });

=head2 ABSOLUTE

The C<ABSOLUTE|Template::Manual::Config#ABSOLUTE> option is deprecated. If you
want to access templates anywhere on your filesystem then you should add your
root directory (e.g. C<'/'> to the L<INCLUDE_PATH> or leave the L<INCLUDE_PATH>
undefined.

We still accept the C<ABSOLUTE> option and Do The Right Thing[tm] in 
adding the root directory to the L<INCLUDE_PATH>.  However a warning will
be raised.

TODO: check this works as advertised - I suspect there are some edge cases.

=head2 RELATIVE

The L<RELATIVE|Template::Manual::Config#RELATIVE> option is also deprecated.
It was broken anyway.  If you want to access templates relative to your 
current working directory then add the directory to the L<INCLUDE_PATH> or
leave L<INCLUDE_PATH> undefined.

TODO: check this works as advertised - I suspect there are some edge cases.

=head2 DEFAULT

The L<DEFAULT|Template::Manual::Config#DEFAULT> option can be used to specify
a default template which should be used whenever a specified template can't be
found in the L<INCLUDE_PATH>.

    my $provider = Template::TT2::Templates->new({
        DEFAULT => 'notfound.html',
    });

If a non-existant template is requested through the L<Template>
L<process()|Template#process()> method, or by an C<INCLUDE>, C<PROCESS> or
C<WRAPPER> directive, then the C<DEFAULT> template will instead be processed,
if defined. Note that the C<DEFAULT> template is not used when templates are
specified with absolute or relative filenames, or as a reference to a input
file handle or text string.

=head2 STAT_TTL

The L<STAT_TTL|Template::Manual::Config#STAT_TTL> value can be set to control
how long the C<Template::TT2::Templates> will keep a template cached in memory
before checking to see if the source template has changed.

    my $provider = Template::TT2::Templates->new({
        STAT_TTL => 60,  # one minute
    });

=head2 PARSER

The L<PARSER|Template::Manual::Config#PARSER> option can be used to define
a parser module other than the default of L<Template::TT2::Parser>.

    my $provider = Template::TT2::Templates->new({
        PARSER => MyOrg::Template::Parser->new({ ... }),
    });

=head2 CACHE

A reference to a L<cache|Template::TT2::Cache> object or the name of a 
cache class to use for caching compiled templates in memory.  Defaults
to L<Template::TT2::Cache> which is sufficiently API compatible with
L<Cache::Cache> to allow you to use any of the L<Cache::Cache> modules
as a drop-in replacement.

If you specify a class name then all of the configuration options will
be forwarded to the constructor method.  This means in practice that
L<Template::Templates> also accepts all the configuration items of 
L<Template::TT2::Cache> or your own caching module.

=head2 STORE

A reference to a L<storage|Template::TT2::Store> object or the name of a 
cache class to use for storing compiled templates on disk.  Defaults
to L<Template::TT2::Store>.

If you specify a class name then all of the configuration options will
be forwarded to the constructor method.  This means in practice that
L<Template::Templates> also accepts all the configuration items of 
L<Template::TT2::Store> or your own storage module.

=head1 TODO

Allow STAT_TTL to be -1 for "never expire".

Handle C<INCLUDE_PATH =E<gt> 'prefix:/path'>.  This is being used in the
F<t/plugin/pod.t> test. 

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::TT2>, L<Template::TT2::Parser>, L<Template::TT2::Context>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:


