#============================================================= -*-perl-*-
#
# Template::TT2
#
# DESCRIPTION
#   Front-end to the TT2 modules.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
# COPYRIGHT
#   Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#========================================================================

package Template::TT2;

use Template::TT2::Class
    version    => 0.01,         # constructs VERSION and $VERSION
    debug      => 0,
    base       => 'Template::TT2::Base Badger::Prototype',
    constants  => ':types',
    filesystem => 'FS VFS',
    mutators   => 'hub',
    import     => 'class',
    utils      => 'looks_like_number blessed is_object',
    constants  => 'TT2_HUB',
    constant   => {
        PRINT_METHOD => 'print',
    },
    config     => [
        'HUB|hub|class:HUB|method:TT2_HUB',
        'MKDIR|mkdir|class:MKDIR=1',
        'ENCODING|encoding|class:ENCODING=0',
        'OUTPUT|output|class:OUTPUT',
        'OUTPUT_PATH|output_path|class:OUTPUT_PATH',
        'QUIET|quiet=0',
        'modules|MODULES|class:MODULES',
    ],
    messages    => {
        hub_config => 'Configuration options are ignored when connecting to an existing hub',
    };

our $VERSION = 0.01;    # for ExtUtils::MakeMaker - not DRY, yuk
our $OUTPUT  = \*STDOUT unless defined $OUTPUT;


sub init {
    my ($self, $config) = @_;
    my $class = $self->class;
    my $debug = $config->{ DEBUG };

    # call the imported (from Badger::Class::Config) configure() method
    # to configure $self from $config according to the config spec above
    $self->configure($config, $config);

    # hub usually defaults to Template::TT2::Hub as defined by TT2_HUB 
    # constant, but this can be overridden with a config option or pkg var
    my $hub = $config->{ HUB }
        || return $self->error_msg( missing => 'hub' );

    if (ref $hub) {
        if (is_object(TT2_HUB, $hub)) {
            # we can attach to an existing hub object, but that means we 
            # have to ignore any other config arguments
            $self->warn_msg('hub_config')
                unless $self->{ QUIET } || keys %$config == 1;
    
            $self->{ hub } = $hub;
        }
        else {
            $self->error_msg( invalid => hub => $hub );
        }
    }
    else {
        # otherwise we've got a class name which we load and instantiate
        $self->{ hub } = class($hub)->load->instance($config);
    }

    $self->debug("connected to hub: $self->{ hub }") if DEBUG;

    # convert textual DEBUG flags to number
#    $config->{ DEBUG } = debug_flags($self, $debug)
#        if defined $debug && ! looks_like_number $debug;

    # TODO: delete this, make the hub create other objects and pass 
    # hub reference along to context, filters, plugins, etc

    # create Badger::Filesystem::Directory object for file output,
    # check it exists, do a mkdir if the MKDIR flags says that's OK
#    if ($self->{ OUTPUT_PATH }) {
#        $self->debug("creating virtual filesystem for output in $self->{ OUTPUT_PATH }") if DEBUG;
#        my $dir = FS->directory(  $self->{ OUTPUT_PATH } )
#                    ->must_exist( $self->{ MKDIR       } );
#        $self->{ OUTPUT_FS } = VFS->new( root => $dir );
#    }
#    else {
#        $self->debug("output to filesystem") if DEBUG;
#        $self->{ OUTPUT_FS }  = FS;
#    }
#    # save output filesystem back into config for context to share
#    # with plugins, filters, etc., (e.g. redirect filter)
#    $config->{ OUTPUT_FS } = $self->{ OUTPUT_FS };
#    

    return $self;
}

#sub hub {
#    return ref $_[0] eq HASH
#        ? $_[0]->{ hub }
#        : $_[0]->prototype->{ hub };
#}

sub process {
    my ($self, $input, $vars, @output) = @_;
    $vars ||= { };
    $self->output( $self->service->process($input, $vars), @output );
}

sub service {
    return $_[0]->{ service }
       ||= $_[0]->hub->service;
}

sub context {
    return $_[0]->{ context }
       ||= $_[0]->service->context;
}

sub output {
    shift->hub->output(@_);
}

sub module {
    shift->hub->module(@_);
}

sub destroy {
    my $self = shift;
    $self->{ hub }->destroy;
    delete $self->{ hub };
    return ();
}

sub DESTROY {
    shift->destroy;
}

1;


__END__

    # prepare a namespace handler for any CONSTANTS definition
    if (my $constants = $config->{ CONSTANTS }) {
        my $ns  = $config->{ NAMESPACE } ||= { };
        my $cns = $config->{ CONSTANTS_NAMESPACE } || 'constants';
        $constants = Template::Config->constants($constants)
            || return $self->error(Template::Config->error);
        $ns->{ $cns } = $constants;
    }
    
# preload all modules if we're running under mod_perl
#Template::Config->preload() if $ENV{ MOD_PERL };





1;

__END__

=head1 NAME

Template::TT2 - Template Toolkit v2

=head1 SYNOPSIS 

    use Template::TT2;
    
=head1 DESCRIPTION

TODO

=head1 METHODS

TODO

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
# Textmate: is shiny
