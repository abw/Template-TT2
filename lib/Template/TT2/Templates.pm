# TODO
#    allow STAT_TTL tp be -1 for never expire

package Template::TT2::Templates;

use Badger::Filesystem 
    'FS VFS Cwd Dir File';
use Badger::Debug 
    ':debug';
use Template::TT2::Constants  
    'SCALAR ARRAY GLOB BLANK UNICODE DEBUG_TEMPLATES DEBUG_FLAGS 
     TT2_DOCUMENT MSWIN32';
use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Base',
    import    => 'class',
    utils     => 'blessed md5_hex textlike',
    codec     => 'unicode',
    constants => 'SCALAR HASH GLOB',
    constant  => {
        INPUT_TEXT    => 'input text',
        INPUT_FH      => 'input file handle',
        LOOKUP_PATH   => 0,     # slots in cached lookup results
        LOOKUP_TIME   => 1,
        TEXT_PREFIX   => 'md5:',
        URI_ROOT      => '/',
        IS_ABS_URI    => qr[^/],
    },
    defaults  => {
        DOCUMENT      => TT2_DOCUMENT,      # TODO: use Template::Modules
        PARSER        => 'Template::TT2::Parser',
        CACHE         => 'Template::TT2::Cache',
        STORE         => 'Template::TT2::Store',
        INCLUDE_PATH  => Cwd,
        DYNAMIC_PATH  => 0,
        MAX_DIRS      => 32,
        STAT_TTL      => 1,
        TOLERANT      => 0,
        COMPILE_EXT   => BLANK,
        DEFAULT       => undef,
        UNICODE       => UNICODE,
    },
    messages => {
        no_absolute   => "The ABSOLUTE option has been deprecated.  Please add '/' to your INCLUDE_PATH",
        no_relative   => "The RELATIVE option has been deprecated.  Please add '.' to your INCLUDE_PATH",
        not_ref       => 'Template specified is not a reference: %s',
        bad_ref       => 'Template specified is an invalid reference: %s',
        bad_cache     => 'Template CACHE is an invalid reference: %s',
    };
        
use Template::TT2::Document;

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

    $self->init_defaults($config);          # from Template::TT2::Base
    $self->init_path($config);
    $self->init_cache($config);
    $self->init_store($config);

    # warn that the ABSOLUTE and RELATIVE options are deprecated
    $self->warn_msg('no_absolute') if $config->{ ABSOLUTE };
    $self->warn_msg('no_relative') if $config->{ RELATIVE };

    # save config for when we need to initiate a parser
    $self->{ config } = $config;
    
    return $self;
}

sub init_path {
    my ($self, $config) = @_;
    my $path;
    
    # create a virtual filesystem across the INCLUDE_PATH
    $path = $config->{ INCLUDE_PATH } || $self->class->list_vars('INCLUDE_PATH');
    $path = [ $path ] unless ref $path eq ARRAY;
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
    
    if (ref $store) {
        # use store object provided
        $self->error_msg( bad_store => $store ) unless blessed $store;
        $self->debug("Using user-supplied template store: $store\n") if DEBUG;
    }
    elsif (defined $cdir) {
        # create new store for compiled templates
        $self->debug("Creating template store in $cdir\n") if DEBUG;
        class($store)->load;
        $self->{ STORE } = $store->new( 
            directory => $cdir,
            extension => $config->{ COMPILE_EXT },
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
        if ref $name;

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
                hello    => 'world',
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

# compile template source
# ($template, $error) = $self->_compile($template, $self->_compiled_filename($name) );
# Store compiled template and return it
# return $self->store($name, $template->{data}) ;
# $self->store_cached($path, $data);
    
 # cache result for next time if paths are static
#    $self->{ LOOKUP }->{ $uri } = [$path, time]
#        unless $self->{ DYNAMIC_PATH };
        

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

        # modification times don't match so drop through
        $self->debug("cached modification time $data->{ time } does not match $modified") if DEBUG;
    }

    if ($self->{ STORE } && ($data = $self->{ STORE }->get($id))) {
        $self->debug("$id found in the store\n") if DEBUG;
        # TODO: check modified time
        return $data;
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
    
#    $self->debug("parsed data: ", $self->dump_data($parsed), "\n") if DEBUG;
    
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

    # load and instantiate parser class if not already an object
    $parser = $self->{ PARSER };
    $parser = $self->{ PARSER }
            = class($parser)->load->instance($self->{ config })
              unless blessed $self->{ PARSER };

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


sub OLD_fetch_path {
    my ($self, $path) = @_;
    my $stat_max = time - $self->{ STAT_TTL };
    my ($stat_time, $data, $file, $text);

    $self->debug("fetch_file($path)\n") if DEBUG;

    # see if the named template is in the cache
    if ($self->{ CACHE } && ($data = $self->{ CACHE }->get($path))) {
        return $self->todo('handing cached data');
        #return $self->refresh($data);
    }

    # see if it's been compiled and saved to disk
    if ($self->{ COMPILE_DIR } && $self->_compiled_is_current($path)) {
        $self->todo('compiled templates');
        # require() the compiled template.
        #my $compiled_template = $self->_load_compiled( $self->_compiled_filename($name) );

        # Store and return the compiled template
        #return $self->store( $name, $compiled_template ) if $compiled_template;

        # Problem loading compiled template:
        # warn and continue to fetch source template
        #warn($self->error(), "\n");
    }

    $file = FS->file($path);
    
    if ($file->exists) {
        $self->debug("template file exists: ", $file->definitive, "\n") if DEBUG;
        $text = $file->text;
        $text = decode($text) if $self->{ UNICODE };
        $data = {
            name => $path,
            path => $path,
            text => $text,
            time => $file->modified,
            load => time,
        };
        $self->todo('return loaded template data');
        # compile template source
        # ($template, $error) = $self->_compile($template, $self->_compiled_filename($name) );
        # Store compiled template and return it
        # return $self->store($name, $template->{data}) ;
    }
    else {
        $self->debug("template $path file does not exist: ", $file->definitive, "\n") if DEBUG;
    }
    
    $self->{ NOT_FOUND }->{ $path } = time;

    return $self->decline( not_found => template => $path );
}

1;


__END__    

        # write the Perl code to the file $compfile, if defined
        if ($compfile) {
            my $basedir = &File::Basename::dirname($compfile);
            $basedir =~ /(.*)/;
            $basedir = $1;

            unless (-d $basedir) {
                eval { File::Path::mkpath($basedir) };
                $error = "failed to create compiled templates directory: $basedir ($@)"
                    if ($@);
            }

            unless ($error) {
                my $docclass = $self->{ DOCUMENT };
                $error = 'cache failed to write '
                    . &File::Basename::basename($compfile)
                    . ': ' . $docclass->error()
                    unless $docclass->write_perl_file($compfile, $parsedoc);
            }

            # set atime and mtime of newly compiled file, don't bother
            # if time is undef
            if (!defined($error) && defined $data->{ time }) {
                my ($cfile) = $compfile =~ /^(.+)$/s or do {
                    return("invalid filename: $compfile",
                           Template::Constants::STATUS_ERROR);
                };

                my ($ctime) = $data->{ time } =~ /^(\d+)$/;
                unless ($ctime || $ctime eq 0) {
                    return("invalid time: $ctime",
                           Template::Constants::STATUS_ERROR);
                }
                utime($ctime, $ctime, $cfile);

                $self->debug(" cached compiled template to file [$compfile]")
                    if $self->{ DEBUG };
            }
        }


_init
_load
_load( $name )

Load the template from the database and return a hash containing its name,
content, the time it was last modified, and the time it was loaded (now).

 ->fetch( $name )

_modified( $name, $time )


$time = $obj->_template_modified($path)

$data = $obj->_template_content($path)
# ($data, $error, $mtime) = $obj->_template_content($path)

encoding, preload

#------------------------------------------------------------------------
# _fetch_path($name)
#
# Fetch a file from cache or disk by specification of an absolute cache
# name (e.g. 'header') or filename relative to one of the INCLUDE_PATH
# directories.  If the file isn't already cached and can be found and
# loaded, it is compiled and cached under the full filename.
#------------------------------------------------------------------------

sub _fetch_path {
    my ($self, $name) = @_;

    $self->debug("_fetch_path($name)") if $self->{ DEBUG };

    # the template may have been stored using a non-filename name
    # so look for the plain name in the cache first
    if ((my $slot = $self->{ LOOKUP }->{ $name })) {
        # cached entry exists, so refresh slot and extract data
        my ($data, $error) = $self->_refresh($slot);

        return $error
            ? ($data, $error)
            : ($slot->[ DATA ], $error );
    }

    my $paths = $self->paths
        || return ( $self->error, Template::Constants::STATUS_ERROR );

    # search the INCLUDE_PATH for the file, in cache or on disk
    foreach my $dir (@$paths) {
        my $path = File::Spec->catfile($dir, $name);

        $self->debug("searching path: $path\n") if $self->{ DEBUG };

        my ($data, $error) = $self->_fetch( $path, $name );

        # Return if no error or if a serious error.
        return ( $data, $error )
            if !$error || $error == Template::Constants::STATUS_ERROR;

    }

    # not found in INCLUDE_PATH, now try DEFAULT
    return $self->_fetch_path( $self->{DEFAULT} )
        if defined $self->{DEFAULT} && $name ne $self->{DEFAULT};

    # We could not handle this template name
    return (undef, Template::Constants::STATUS_DECLINED);
}

sub _compiled_filename {
    my ($self, $file) = @_;
    my ($compext, $compdir) = @$self{ qw( COMPILE_EXT COMPILE_DIR ) };
    my ($path, $compiled);

    return undef
        unless $compext || $compdir;

    $path = $file;
    $path =~ /^(.+)$/s or die "invalid filename: $path";
    $path =~ s[:][]g if $^O eq 'MSWin32';

    $compiled = "$path$compext";
    $compiled = File::Spec->catfile($compdir, $compiled) if length $compdir;

    return $compiled;
}

sub _load_compiled {
    my ($self, $file) = @_;
    my $compiled;

    # load compiled template via require();  we zap any
    # %INC entry to ensure it is reloaded (we don't
    # want 1 returned by require() to say it's in memory)
    delete $INC{ $file };
    eval { $compiled = require $file; };
    return $@
        ? $self->error("compiled template $compiled: $@")
        : $compiled;
}

#------------------------------------------------------------------------
# _load($name, $alias)
#
# Load template text from a string ($name = scalar ref), GLOB or file
# handle ($name = ref), or from an absolute filename ($name = scalar).
# Returns a hash array containing the following items:
#   name    filename or $alias, if provided, or 'input text', etc.
#   text    template text
#   time    modification time of file, or current time for handles/strings
#   load    time file was loaded (now!)
#
# On error, returns ($error, STATUS_ERROR), or (undef, STATUS_DECLINED)
# if TOLERANT is set.
#------------------------------------------------------------------------

sub load {
    my ($self, $name, $alias) = @_;
    my ($data, $error);
    my $tolerant = $self->{ TOLERANT };
    my $now = time;

    $alias = $name unless defined $alias or ref $name;

    $self->debug("_load($name, ", defined $alias ? $alias : '<no alias>',
                 ')') if $self->{ DEBUG };

    # Otherwise, it's the name of the template
    if ( $self->_template_modified( $name ) ) {  # does template exist?
        my ($text, $error, $mtime ) = $self->_template_content( $name );
        unless ( $error )  {
            $text = $self->_decode_unicode($text) if $self->{ UNICODE };
            return {
                name => $alias,
                path => $name,
                text => $text,
                time => $mtime,
                load => $now,
            };
        }

        return ( "$alias: $!", Template::Constants::STATUS_ERROR )
            unless $tolerant;
    }

    # Unable to process template, pass onto the next Provider.
    return (undef, Template::Constants::STATUS_DECLINED);
}


#------------------------------------------------------------------------
# _refresh(\@slot)
#
# Private method called to mark a cache slot as most recently used.
# A reference to the slot array should be passed by parameter.  The
# slot is relocated to the head of the linked list.  If the file from
# which the data was loaded has been upated since it was compiled, then
# it is re-loaded from disk and re-compiled.
#------------------------------------------------------------------------

sub _refresh {
    my ($self, $slot) = @_;
    my $stat_ttl = $self->{ STAT_TTL };
    my ($head, $file, $data, $error);

    $self->debug("_refresh([ ",
                 join(', ', map { defined $_ ? $_ : '<undef>' } @$slot),
                 '])') if $self->{ DEBUG };

    # if it's more than $STAT_TTL seconds since we last performed a
    # stat() on the file then we need to do it again and see if the file
    # time has changed
    my $now = time;
    my $expires_in_sec = $slot->[ STAT ] + $stat_ttl - $now;

    if ( $expires_in_sec <= 0 ) {  # Time to check!
        $slot->[ STAT ] = $now;

        # Grab mtime of template.
        # Seems like this should be abstracted to compare to
        # just ask for a newer compiled template (if it's newer)
        # and let that check for a newer template source.
        my $template_mtime = $self->_template_modified( $slot->[ NAME ] );
        if ( ! defined $template_mtime || ( $template_mtime != $slot->[ LOAD ] )) {
            $self->debug("refreshing cache file ", $slot->[ NAME ])
                if $self->{ DEBUG };

            ($data, $error) = $self->_load($slot->[ NAME ], $slot->[ DATA ]->{ name });
            ($data, $error) = $self->_compile($data)
                unless $error;

            if ($error) {
                # if the template failed to load/compile then we wipe out the
                # STAT entry.  This forces the provider to try and reload it
                # each time instead of using the previously cached version
                # until $STAT_TTL is next up
                $slot->[ STAT ] = 0;
            }
            else {
                $slot->[ DATA ] = $data->{ data };
                $slot->[ LOAD ] = $data->{ time };
            }
        }

    } elsif ( $self->{ DEBUG } ) {
        $self->debug( sprintf('STAT_TTL not met for file [%s].  Expires in %d seconds',
                        $slot->[ NAME ], $expires_in_sec ) );
    }

    # Move this slot to the head of the list
    unless( $self->{ HEAD } == $slot ) {
        # remove existing slot from usage chain...
        if ($slot->[ PREV ]) {
            $slot->[ PREV ]->[ NEXT ] = $slot->[ NEXT ];
        }
        else {
            $self->{ HEAD } = $slot->[ NEXT ];
        }
        if ($slot->[ NEXT ]) {
            $slot->[ NEXT ]->[ PREV ] = $slot->[ PREV ];
        }
        else {
            $self->{ TAIL } = $slot->[ PREV ];
        }

        # ..and add to start of list
        $head = $self->{ HEAD };
        $head->[ PREV ] = $slot if $head;
        $slot->[ PREV ] = undef;
        $slot->[ NEXT ] = $head;
        $self->{ HEAD } = $slot;
    }

    return ($data, $error);
}



#------------------------------------------------------------------------
# _store($name, $data)
#
# Private method called to add a data item to the cache.  If the cache
# size limit has been reached then the oldest entry at the tail of the
# list is removed and its slot relocated to the head of the list and
# reused for the new data item.  If the cache is under the size limit,
# or if no size limit is defined, then the item is added to the head
# of the list.
# Returns compiled template
#------------------------------------------------------------------------

sub _store {
    my ($self, $name, $data, $compfile) = @_;
    my $size = $self->{ SIZE };
    my ($slot, $head);

    # Return if memory cache disabled.  (overridding code should also check)
    # $$$ What's the expected behaviour of store()?  Can't tell from the
    # docs if you can call store() when SIZE = 0.
    return $data->{data} if defined $size and !$size;

    # extract the compiled template from the data hash
    $data = $data->{ data };
    $self->debug("_store($name, $data)") if $self->{ DEBUG };

    # check the modification time -- extra stat here
    my $load = $self->_modified($name);

    if (defined $size && $self->{ SLOTS } >= $size) {
        # cache has reached size limit, so reuse oldest entry
        $self->debug("reusing oldest cache entry (size limit reached: $size)\nslots: $self->{ SLOTS }") if $self->{ DEBUG };

        # remove entry from tail of list
        $slot = $self->{ TAIL };
        $slot->[ PREV ]->[ NEXT ] = undef;
        $self->{ TAIL } = $slot->[ PREV ];

        # remove name lookup for old node
        delete $self->{ LOOKUP }->{ $slot->[ NAME ] };

        # add modified node to head of list
        $head = $self->{ HEAD };
        $head->[ PREV ] = $slot if $head;
        @$slot = ( undef, $name, $data, $load, $head, time );
        $self->{ HEAD } = $slot;

        # add name lookup for new node
        $self->{ LOOKUP }->{ $name } = $slot;
    }
    else {
        # cache is under size limit, or none is defined

        $self->debug("adding new cache entry") if $self->{ DEBUG };

        # add new node to head of list
        $head = $self->{ HEAD };
        $slot = [ undef, $name, $data, $load, $head, time ];
        $head->[ PREV ] = $slot if $head;
        $self->{ HEAD } = $slot;
        $self->{ TAIL } = $slot unless $self->{ TAIL };

        # add lookup from name to slot and increment nslots
        $self->{ LOOKUP }->{ $name } = $slot;
        $self->{ SLOTS }++;
    }

    return $data;
}


#------------------------------------------------------------------------
# _compile($data)
#
# Private method called to parse the template text and compile it into
# a runtime form.  Creates and delegates a Template::Parser object to
# handle the compilation, or uses a reference passed in PARSER.  On
# success, the compiled template is stored in the 'data' item of the
# $data hash and returned.  On error, ($error, STATUS_ERROR) is returned,
# or (undef, STATUS_DECLINED) if the TOLERANT flag is set.
# The optional $compiled parameter may be passed to specify
# the name of a compiled template file to which the generated Perl
# code should be written.  Errors are (for now...) silently
# ignored, assuming that failures to open a file for writing are
# intentional (e.g directory write permission).
#------------------------------------------------------------------------

sub _compile {
    my ($self, $data, $compfile) = @_;
    my $text = $data->{ text };
    my ($parsedoc, $error);

    $self->debug("_compile($data, ",
                 defined $compfile ? $compfile : '<no compfile>', ')')
        if $self->{ DEBUG };

    my $parser = $self->{ PARSER }
        ||= Template::Config->parser($self->{ PARAMS })
        ||  return (Template::Config->error(), Template::Constants::STATUS_ERROR);

    # discard the template text - we don't need it any more
    delete $data->{ text };

    # call parser to compile template into Perl code
    if ($parsedoc = $parser->parse($text, $data)) {

        $parsedoc->{ METADATA } = {
            'name'    => $data->{ name },
            'modtime' => $data->{ time },
            %{ $parsedoc->{ METADATA } },
        };

        # write the Perl code to the file $compfile, if defined
        if ($compfile) {
            my $basedir = &File::Basename::dirname($compfile);
            $basedir =~ /(.*)/;
            $basedir = $1;

            unless (-d $basedir) {
                eval { File::Path::mkpath($basedir) };
                $error = "failed to create compiled templates directory: $basedir ($@)"
                    if ($@);
            }

            unless ($error) {
                my $docclass = $self->{ DOCUMENT };
                $error = 'cache failed to write '
                    . &File::Basename::basename($compfile)
                    . ': ' . $docclass->error()
                    unless $docclass->write_perl_file($compfile, $parsedoc);
            }

            # set atime and mtime of newly compiled file, don't bother
            # if time is undef
            if (!defined($error) && defined $data->{ time }) {
                my ($cfile) = $compfile =~ /^(.+)$/s or do {
                    return("invalid filename: $compfile",
                           Template::Constants::STATUS_ERROR);
                };

                my ($ctime) = $data->{ time } =~ /^(\d+)$/;
                unless ($ctime || $ctime eq 0) {
                    return("invalid time: $ctime",
                           Template::Constants::STATUS_ERROR);
                }
                utime($ctime, $ctime, $cfile);

                $self->debug(" cached compiled template to file [$compfile]")
                    if $self->{ DEBUG };
            }
        }

        unless ($error) {
            return $data                                        ## RETURN ##
                if $data->{ data } = $DOCUMENT->new($parsedoc);
            $error = $Template::Document::ERROR;
        }
    }
    else {
        $error = Template::Exception->new( 'parse', "$data->{ name } " .
                                           $parser->error() );
    }

    # return STATUS_ERROR, or STATUS_DECLINED if we're being tolerant
    return $self->{ TOLERANT }
        ? (undef, Template::Constants::STATUS_DECLINED)
        : ($error,  Template::Constants::STATUS_ERROR)
}

#------------------------------------------------------------------------
# _compiled_is_current( $template_name )
#
# Returns true if $template_name and its compiled name
# exist and they have the same mtime.
#------------------------------------------------------------------------

sub _compiled_is_current {
    my ( $self, $template_name ) = @_;
    my $compiled_name   = $self->_compiled_filename($template_name) || return;
    my $compiled_mtime  = (stat($compiled_name))[9] || return;
    my $template_mtime  = $self->_template_modified( $template_name ) || return;

    # This was >= in the 2.15, but meant that downgrading
    # a source template would not get picked up.
    return $compiled_mtime == $template_mtime;
}


#------------------------------------------------------------------------
# _template_modified($path)
#
# Returns the last modified time of the $path.
# Returns undef if the path does not exist.
# Override if templates are not on disk, for example
#------------------------------------------------------------------------

sub _template_modified {
    my $self = shift;
    my $template = shift || return;
    return (stat( $template ))[9];
}

#------------------------------------------------------------------------
# _template_content($path)
#
# Fetches content pointed to by $path.
# Returns the content in scalar context.
# Returns ($data, $error, $mtime) in list context where
#   $data       - content
#   $error      - error string if there was an error, otherwise undef
#   $mtime      - last modified time from calling stat() on the path
#------------------------------------------------------------------------

sub _template_content {
    my ($self, $path) = @_;

    return (undef, "No path specified to fetch content from ")
        unless $path;

    my $data;
    my $mod_date;
    my $error;

    local *FH;
    if (open(FH, "< $path")) {
        local $/;
        binmode(FH);
        $data = <FH>;
        $mod_date = (stat($path))[9];
        close(FH);
    }
    else {
        $error = "$path: $!";
    }

    return wantarray
        ? ( $data, $error, $mod_date )
        : $data;
}


#------------------------------------------------------------------------
# _modified($name)
# _modified($name, $time)
#
# When called with a single argument, it returns the modification time
# of the named template.  When called with a second argument it returns
# true if $name has been modified since $time.
#------------------------------------------------------------------------

sub _modified {
    my ($self, $name, $time) = @_;
    my $load = $self->_template_modified($name)
        || return $time ? 1 : 0;

    return $time
         ? $load > $time
         : $load;
}

#------------------------------------------------------------------------
# _dump()
#
# Debug method which returns a string representing the internal object
# state.
#------------------------------------------------------------------------

sub _dump {
    my $self = shift;
    my $size = $self->{ SIZE };
    my $parser = $self->{ PARSER };
    $parser = $parser ? $parser->_dump() : '<no parser>';
    $parser =~ s/\n/\n    /gm;
    $size = 'unlimited' unless defined $size;

    my $output = "[Template::Provider] {\n";
    my $format = "    %-16s => %s\n";
    my $key;

    $output .= sprintf($format, 'INCLUDE_PATH',
                       '[ ' . join(', ', @{ $self->{ INCLUDE_PATH } }) . ' ]');
    $output .= sprintf($format, 'CACHE_SIZE', $size);

    foreach $key (qw( ABSOLUTE RELATIVE TOLERANT DELIMITER
                      COMPILE_EXT COMPILE_DIR )) {
        $output .= sprintf($format, $key, $self->{ $key });
    }
    $output .= sprintf($format, 'PARSER', $parser);


    local $" = ', ';
    my $lookup = $self->{ LOOKUP };
    $lookup = join('', map {
        sprintf("    $format", $_, defined $lookup->{ $_ }
                ? ('[ ' . join(', ', map { defined $_ ? $_ : '<undef>' }
                               @{ $lookup->{ $_ } }) . ' ]') : '<undef>');
    } sort keys %$lookup);
    $lookup = "{\n$lookup    }";

    $output .= sprintf($format, LOOKUP => $lookup);

    $output .= '}';
    return $output;
}


#------------------------------------------------------------------------
# _dump_cache()
#
# Debug method which prints the current state of the cache to STDERR.
#------------------------------------------------------------------------

sub _dump_cache {
    my $self = shift;
    my ($node, $lut, $count);

    $count = 0;
    if ($node = $self->{ HEAD }) {
        while ($node) {
            $lut->{ $node } = $count++;
            $node = $node->[ NEXT ];
        }
        $node = $self->{ HEAD };
        print STDERR "CACHE STATE:\n";
        print STDERR "  HEAD: ", $self->{ HEAD }->[ NAME ], "\n";
        print STDERR "  TAIL: ", $self->{ TAIL }->[ NAME ], "\n";
        while ($node) {
            my ($prev, $name, $data, $load, $next) = @$node;
#           $name = '...' . substr($name, -10) if length $name > 10;
            $prev = $prev ? "#$lut->{ $prev }<-": '<undef>';
            $next = $next ? "->#$lut->{ $next }": '<undef>';
            print STDERR "   #$lut->{ $node } : [ $prev, $name, $data, $load, $next ]\n";
            $node = $node->[ NEXT ];
        }
    }
}

#------------------------------------------------------------------------
# _decode_unicode
#
# Decodes encoded unicode text that starts with a BOM and
# turns it into perl's internal representation
#------------------------------------------------------------------------

sub _decode_unicode {
    my $self   = shift;
    my $string = shift;
    return undef unless defined $string;

    use bytes;
    require Encode;

    return $string if Encode::is_utf8( $string );

    # try all the BOMs in order looking for one (order is important
    # 32bit BOMs look like 16bit BOMs)

    my $count  = 0;

    while ($count < @{ $boms }) {
        my $enc = $boms->[$count++];
        my $bom = $boms->[$count++];

        # does the string start with the bom?
        if ($bom eq substr($string, 0, length($bom))) {
            # decode it and hand it back
            return Encode::decode($enc, substr($string, length($bom)), 1);
        }
    }

    return $self->{ ENCODING }
        ? Encode::decode( $self->{ ENCODING }, $string )
        : $string;
}


1;

__END__

=head1 NAME

Template::Provider - Provider module for loading/compiling templates

=head1 SYNOPSIS

    $provider = Template::Provider->new(\%options);
    
    ($template, $error) = $provider->fetch($name);

=head1 DESCRIPTION

The L<Template::Provider> is used to load, parse, compile and cache template
documents. This object may be sub-classed to provide more specific facilities
for loading, or otherwise providing access to templates.

The L<Template::Context> objects maintain a list of L<Template::Provider>
objects which are polled in turn (via L<fetch()|Template::Context#fetch()>) to
return a requested template. Each may return a compiled template, raise an
error, or decline to serve the request, giving subsequent providers a chance
to do so.

The L<Template::Provider> can also be subclassed to provide templates from
a different source, e.g. a database. See L<SUBCLASSING> below.

This documentation needs work.

=head1 PUBLIC METHODS

=head2 new(\%options) 

Constructor method which instantiates and returns a new C<Template::Provider>
object.  A reference to a hash array of configuration options may be passed.

See L<CONFIGURATION OPTIONS> below for a summary of configuration options
and L<Template::Manual::Config> for full details.

=head2 fetch($name)

Returns a compiled template for the name specified. If the template cannot be
found then C<(undef, STATUS_DECLINED)> is returned. If an error occurs (e.g.
read error, parse error) then C<($error, STATUS_ERROR)> is returned, where
C<$error> is the error message generated. If the L<TOLERANT> option is set the
the method returns C<(undef, STATUS_DECLINED)> instead of returning an error.

=head2 store($name, $template)

Stores the compiled template, C<$template>, in the cache under the name, 
C<$name>.  Susbequent calls to C<fetch($name)> will return this template in
preference to any disk-based file.

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
to the C<Template::Provider> L<new()> constructor. Please consult
L<Template::Manual::Config> for further details and examples of each
configuration option in use.

=head2 INCLUDE_PATH

The L<INCLUDE_PATH|Template::Manual::Config#INCLUDE_PATH> option is used to
specify one or more directories in which template files are located.

    # single path
    my $provider = Template::Provider->new({
        INCLUDE_PATH => '/usr/local/templates',
    });

    # multiple paths
    my $provider = Template::Provider->new({
        INCLUDE_PATH => [ '/usr/local/templates', 
                          '/tmp/my/templates' ],
    });

=head2 ABSOLUTE

The L<ABSOLUTE|Template::Manual::Config#ABSOLUTE> flag is used to indicate if
templates specified with absolute filenames (e.g. 'C</foo/bar>') should be
processed. It is disabled by default and any attempt to load a template by
such a name will cause a 'C<file>' exception to be raised.

    my $provider = Template::Provider->new({
        ABSOLUTE => 1,
    });

=head2 RELATIVE

The L<RELATIVE|Template::Manual::Config#RELATIVE> flag is used to indicate if
templates specified with filenames relative to the current directory (e.g.
C<./foo/bar> or C<../../some/where/else>) should be loaded. It is also disabled
by default, and will raise a C<file> error if such template names are
encountered.

    my $provider = Template::Provider->new({
        RELATIVE => 1,
    });

=head2 DEFAULT

The L<DEFAULT|Template::Manual::Config#DEFAULT> option can be used to specify
a default template which should be used whenever a specified template can't be
found in the L<INCLUDE_PATH>.

    my $provider = Template::Provider->new({
        DEFAULT => 'notfound.html',
    });

If a non-existant template is requested through the L<Template>
L<process()|Template#process()> method, or by an C<INCLUDE>, C<PROCESS> or
C<WRAPPER> directive, then the C<DEFAULT> template will instead be processed, if
defined. Note that the C<DEFAULT> template is not used when templates are
specified with absolute or relative filenames, or as a reference to a input
file handle or text string.

=head2 ENCODING

The Template Toolkit will automatically decode Unicode templates that
have a Byte Order Marker (BOM) at the start of the file.  This option
can be used to set the default encoding for templates that don't define
a BOM.

    my $provider = Template::Provider->new({
        ENCODING => 'utf8',
    });

See L<Encode> for further information.

=head2 CACHE_SIZE

The L<CACHE_SIZE|Template::Manual::Config#CACHE_SIZE> option can be used to
limit the number of compiled templates that the module should cache. By
default, the L<CACHE_SIZE|Template::Manual::Config#CACHE_SIZE> is undefined
and all compiled templates are cached.

    my $provider = Template::Provider->new({
        CACHE_SIZE => 64,   # only cache 64 compiled templates
    });


=head2 STAT_TTL

The L<STAT_TTL|Template::Manual::Config#STAT_TTL> value can be set to control
how long the C<Template::Provider> will keep a template cached in memory
before checking to see if the source template has changed.

    my $provider = Template::Provider->new({
        STAT_TTL => 60,  # one minute
    });

=head2 COMPILE_EXT

The L<COMPILE_EXT|Template::Manual::Config#COMPILE_EXT> option can be
provided to specify a filename extension for compiled template files.
It is undefined by default and no attempt will be made to read or write 
any compiled template files.

    my $provider = Template::Provider->new({
        COMPILE_EXT => '.ttc',
    });

=head2 COMPILE_DIR

The L<COMPILE_DIR|Template::Manual::Config#COMPILE_DIR> option is used to
specify an alternate directory root under which compiled template files should
be saved.

    my $provider = Template::Provider->new({
        COMPILE_DIR => '/tmp/ttc',
    });

=head2 TOLERANT

The L<TOLERANT|Template::Manual::Config#TOLERANT> flag can be set to indicate
that the C<Template::Provider> module should ignore any errors encountered while
loading a template and instead return C<STATUS_DECLINED>.

=head2 PARSER

The L<PARSER|Template::Manual::Config#PARSER> option can be used to define
a parser module other than the default of L<Template::Parser>.

    my $provider = Template::Provider->new({
        PARSER => MyOrg::Template::Parser->new({ ... }),
    });

=head2 DEBUG

The L<DEBUG|Template::Manual::Config#DEBUG> option can be used to enable
debugging messages from the L<Template::Provider> module by setting it to include
the C<DEBUG_PROVIDER> value.

    use Template::Constants qw( :debug );
    
    my $template = Template->new({
        DEBUG => DEBUG_PROVIDER,
    });

=head1 SUBCLASSING

The C<Template::Provider> module can be subclassed to provide templates from a 
different source (e.g. a database).  In most cases you'll just need to provide
custom implementations of the C<_template_modified()> and C<_template_content()>
methods.  If your provider requires and custom initialisation then you'll also
need to implement a new C<_init()> method.

Caching in memory and on disk will still be applied (if enabled)
when overriding these methods.

=head2 _template_modified($path)

Returns a timestamp of the C<$path> passed in by calling C<stat()>.
This can be overridden, for example, to return a last modified value from
a database.  The value returned should be a timestamp value (as returned by C<time()>,
although a sequence number should work as well.

=head2 _template_content($path)

This method returns the content of the template for all C<INCLUDE>, C<PROCESS>,
and C<INSERT> directives.

When called in scalar context, the method returns the content of the template
located at C<$path>, or C<undef> if C<$path> is not found.

When called in list context it returns C<($content, $error, $mtime)>,
where C<$content> is the template content, C<$error> is an error string
(e.g. "C<$path: File not found>"), and C<$mtime> is the template modification
time.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt> L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2007 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template>, L<Template::Parser>, L<Template::Context>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:


