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

use Template::TT2::Modules;
use Template::TT2::Class
    version    => 0.01,         # constructs VERSION and $VERSION
    debug      => 0,
    base       => 'Template::TT2::Base',
    constants  => ':types',
    filesystem => 'FS VFS',
    import     => 'class',
    utils      => 'looks_like_number blessed',
    constants  => 'TT2_MODULES',
    constant   => {
        PRINT_METHOD => 'print',
        SERVICE      => 'Template::TT2::Service',
    },
    exports    => {
        any    => 'TT2_MODULES',
    };

our $VERSION       = 0.01;       # for ExtUtils::MakeMaker - not DRY, yuk
our $MKDIR         = 1           unless defined $MKDIR;
our $ENCODING      = 0           unless defined $ENCODING;
our $OUTPUT        = \*STDOUT    unless defined $OUTPUT;
our $OUTPUT_PATH   = undef       unless defined $OUTPUT_PATH;
our $SERVICE       = SERVICE     unless defined $SERVICE;
our $DEBUG_BINMODE = 0           unless defined $DEBUG_BINMODE;
our @ARGS          = qw( MKDIR ENCODING OUTPUT OUTPUT_PATH );

# alias modules() to return Template::TT2::Modules class constant
*modules = \&TT2_MODULES;

sub init {
    my ($self, $config) = @_;
    my $class = $self->class;
    my $debug = $config->{ DEBUG };

    # convert textual DEBUG flags to number
#    $config->{ DEBUG } = debug_flags($self, $debug)
#        if defined $debug && ! looks_like_number $debug;

    # set values or defaults for MKDIR, ENCODING, etc.
    foreach my $arg (@ARGS) {
        $self->{ $arg } 
            = defined $config->{ $arg }
                    ? $config->{ $arg }
                    : $class->any_var($arg);
    }

    # create Badger::Filesystem::Directory object for file output,
    # check it exists, do a mkdir if the MKDIR flags says that's OK
    if ($self->{ OUTPUT_PATH }) {
        $self->debug("creating virtual filesystem for output in $self->{ OUTPUT_PATH }") if DEBUG;
        my $dir = FS->directory(  $self->{ OUTPUT_PATH } )
                    ->must_exist( $self->{ MKDIR       } );
        $self->{ OUTPUT_FS } = VFS->new( root => $dir );
    }
    else {
        $self->debug("output to filesystem") if DEBUG;
        $self->{ OUTPUT_FS }  = FS;
    }
    
    # load and instantiate service module
    my $service = $config->{ SERVICE } || $SERVICE;
    $self->{ SERVICE } = class($service)->load->instance($config);

    # save config for lazy methods that might want it
    $self->{ config } = $config;

    return $self;
}

sub process {
    my ($self, $input, $vars, @output) = @_;
    $vars ||= { };
    $self->output( $self->{ SERVICE }->process($input, $vars), @output );
}

sub output {
    my $self = shift;
    my $text = shift;
    my $dest = shift || $self->{ OUTPUT };
    my $args = @_ == 1 && ref $_[0] eq HASH ? shift : { @_ };

    # if no destination is specified and the OUTPUT config parameter
    # is a false value then we return the text generated
    return $text unless $dest;

    # Otherwise we can have a plain text file name or a reference of
    # some kind.  If we have an object with an overloaded stringification
    # method (like a Badger::Filesystem::File), as accepted by textlike(),
    # then we use that as a filename instead of treating it as an object.
    my $type = ref $dest;
#    $type = '' if textlike $dest;   # accept anything that has  file object

    $self->debug("output [$type] => $dest\n") if DEBUG;

    if (! $type) {
        my $file = $self->output_file($dest);
        $self->debug("output file: ", $file->definitive, "\n") if DEBUG;
        my $fh   = $file->write;
        my $enc  = defined $args->{ binmode  }
                         ? $args->{ binmode  } 
                 : defined $args->{ encoding }
                         ? $args->{ encoding } 
                 :         $self->{ ENCODING };

        # TODO: move this into Badger::Filesystem:File
        $fh->binmode($enc eq '1' ? () : $enc) if $enc;
        $self->debug("DEBUG_BINMODE: $DEBUG_BINMODE") if DEBUG;
        $DEBUG_BINMODE->($enc) if $DEBUG_BINMODE;   # hack for testing
        $fh->print($text);
        $fh->close;
    }
    elsif (blessed $dest) {
        my $code = $dest->can(PRINT_METHOD)
            || return $self->error_msg( bad_output => $dest );
        return $code->($dest, $text);          # call object's print() method
    }
    elsif ($type eq CODE) {
        return $dest->($text);          # call subroutine
    }
    elsif ($type eq GLOB) {
        return print $dest $text;       # print to GLOB (e.g. STDOUT)
    }
    elsif ($type eq SCALAR) {
        $$dest .= $text;                # append to text ref
        return $dest;
    }
    elsif ($type eq ARRAY) {
        push @$dest, $text;             # push onto list
        return $dest;
    }
    else {
        return $self->error_msg( bad_output => $dest );
    }
}

sub output_file {
    my $self = shift;
    my $file = $self->{ OUTPUT_FS }->file(@_);

    # make sure any intermediate directories between the OUTPUT_DIR and 
    # final destination exist, or can be created if the MKDIR flag is set
    $file->directory->must_exist($self->{ MKDIR });
    
    return $file;
}

#sub output_dir {
#    shift->{ OUTPUT_DIR };
#}

sub service {
    $_[0]->{ SERVICE };
}

sub context {
    $_[0]->{ SERVICE }->context;
}

sub module {
    my $self = shift;
    TT2_MODULES->module(@_);
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
