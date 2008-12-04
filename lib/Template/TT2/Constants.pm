#============================================================= -*-Perl-*-
#
# Template::TT2::Constants
#
# DESCRIPTION
#   Constants for verion 2 of the Template Toolkit.
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
#============================================================================
 
package Template::TT2::Constants;

use Badger::Class
    version  => 0.01,
    base     => 'Badger::Constants',
    utils    => 'looks_like_number',
    exports  => {
        tags => {
            modules => 'TT2_HUB TT2_MODULES TT2_CONTEXT TT2_DOCUMENT 
                        TT2_EXCEPTION TT2_ITERATOR TT2_PARSER TT2_CACHE 
                        TT2_STORE TT2_FILTER TT2_PLUGIN 
                        TT_DOCUMENT TT_EXCEPTION TT_ITERATOR',
            status  => 'STATUS_OK STATUS_RETURN STATUS_STOP STATUS_DONE
                        STATUS_DECLINED STATUS_ERROR',
            error   => 'ERROR_FILE ERROR_VIEW ERROR_UNDEF ERROR_PERL 
                        ERROR_RETURN ERROR_FILTER ERROR_PLUGIN',
            chomp   => 'CHOMP_NONE CHOMP_ALL CHOMP_ONE CHOMP_COLLAPSE 
                        CHOMP_GREEDY',
            parse   => 'PARSE_CONTINUE PARSE_ACCEPT PARSE_ERROR PARSE_ABORT
                        STATE_DEFAULT STATE_ACTIONS STATE_GOTOS',
            debug   => 'DEBUG_OFF DEBUG_ON DEBUG_UNDEF DEBUG_VARS 
                        DEBUG_DIRS DEBUG_STASH DEBUG_CONTEXT DEBUG_PARSER
                        DEBUG_TEMPLATES DEBUG_PLUGINS DEBUG_FILTERS 
                        DEBUG_SERVICE DEBUG_ALL DEBUG_CALLER DEBUG_FLAGS',
            cache   => 'CACHE_UNLIMITED',
            flow    => 'FLOW_STOP',
            stash   => 'STASH_PRIVATE STASH_IMPORT',
        },
        any => 'MSWIN32 UNICODE',
    },
    constant => {
        # modules
        TT2_HUB         => 'Template::TT2::Hub',
        TT2_MODULES     => 'Template::TT2::Modules',
        TT2_CONTEXT     => 'Template::TT2::Context',
        TT2_DOCUMENT    => 'Template::TT2::Document',
        TT2_EXCEPTION   => 'Template::TT2::Exception',
        TT2_ITERATOR    => 'Template::TT2::Iterator',
        TT2_PARSER      => 'Template::TT2::Parser',
        TT2_CACHE       => 'Template::TT2::Cache',
        TT2_STORE       => 'Template::TT2::Store',
        TT2_FILTER      => 'Template::TT2::Filter',
        TT2_PLUGIN      => 'Template::TT2::Plugin',

        # for backward/forward compatibility
        TT_DOCUMENT     => 'Template::Document',
        TT_EXCEPTION    => 'Template::Exception',
        TT_ITERATOR     => 'Template::Iterator',
        
        # STATUS constants returned by directives
        STATUS_OK       =>   0,         # ok
        STATUS_RETURN   =>   1,         # ok, block ended by RETURN
        STATUS_STOP     =>   2,         # ok, stoppped by STOP 
        STATUS_DONE     =>   3,         # ok, iterator done
        STATUS_DECLINED =>   4,         # ok, declined to service request
        STATUS_ERROR    => 255,         # error condition

        # ERROR constants for indicating exception types
        ERROR_RETURN    =>  'return',   # return a status code
        ERROR_FILE      =>  'file',     # file error: I/O, parse, recursion
        ERROR_VIEW      =>  'view',     # view error
        ERROR_UNDEF     =>  'undef',    # undefined variable value used
        ERROR_PERL      =>  'perl',     # error in [% PERL %] block
        ERROR_FILTER    =>  'filter',   # filter error
        ERROR_PLUGIN    =>  'plugin',   # plugin error

        # CHOMP constants for PRE_CHOMP and POST_CHOMP
        CHOMP_NONE      => 0,           # do not remove whitespace
        CHOMP_ALL       => 1,           # remove whitespace up to newline
        CHOMP_ONE       => 1,           # new name for CHOMP_ALL
        CHOMP_COLLAPSE  => 2,           # collapse whitespace to a single space
        CHOMP_GREEDY    => 3,           # remove all whitespace including newlines
        
        # parser constants
        PARSE_CONTINUE  => 0,
        PARSE_ACCEPT    => 1,
        PARSE_ERROR     => 2,
        PARSE_ABORT     => 3,
        
        # slots in the state table entries
        STATE_DEFAULT   => 0,
        STATE_ACTIONS   => 1,
        STATE_GOTOS     => 2,
        
        # DEBUG constants to enable various debugging options
        DEBUG_OFF       =>    0,        # do nothing
        DEBUG_ON        =>    1,        # basic debugging flag
        DEBUG_UNDEF     =>    2,        # throw undef on undefined variables
        DEBUG_VARS      =>    4,        # general variable debugging
        DEBUG_DIRS      =>    8,        # directive debugging
        DEBUG_STASH     =>   16,        # general stash debugging
        DEBUG_CONTEXT   =>   32,        # context debugging
        DEBUG_PARSER    =>   64,        # parser debugging
        DEBUG_TEMPLATES =>  128,        # templates debugging
        DEBUG_PLUGINS   =>  256,        # plugins debugging
        DEBUG_FILTERS   =>  512,        # filters debugging
        DEBUG_SERVICE   => 1024,        # context debugging
        DEBUG_ALL       => 2047,        # everything

        # extra debugging flags
        DEBUG_CALLER    => 4096,        # add caller file/line
        DEBUG_FLAGS     => 4096,        # bitmask to extract flags

        # CACHE controls
        CACHE_UNLIMITED => 0,           # no limit to size of template cache
        
        # special exceptions types that implement flow control
        FLOW_STOP       => 'stop',      # stop execution, e.g. STOP directive

        # stash defaults
        STASH_PRIVATE   => qr/^[_.]/,   # private members begin with _ or .
        STASH_IMPORT    => 'import',    # magical import variable

        MSWIN32         => $^O eq 'MSWin32' ? 1 : 0,
        UNICODE         => $] > 5.007       ? 1 : 0,
    };


1;

__END__
our $DEBUG_FLAGS = {
    off      => DEBUG_OFF,
    on       => DEBUG_ON,
    undef    => DEBUG_UNDEF,
    vars     => DEBUG_VARS,
    dirs     => DEBUG_DIRS,
    stash    => DEBUG_STASH,
    context  => DEBUG_CONTEXT,
    parser   => DEBUG_PARSER,
    provider => DEBUG_PROVIDER,
    plugins  => DEBUG_PLUGINS,
    filters  => DEBUG_FILTERS,
    service  => DEBUG_SERVICE,
    all      => DEBUG_ALL,
    caller   => DEBUG_CALLER,
};


sub debug_flags {
    my ($self, $debug) = @_;
    my (@flags, $flag, $value);
    $debug = $self unless defined($debug) || ref($self);
    
    if ($debug =~ /^\d+$/) {
        foreach $flag (@DEBUG) {
            next if $flag =~ /^DEBUG_(OFF|ALL|FLAGS)$/;

            # don't trash the original
            my $copy = $flag;
            $flag =~ s/^DEBUG_//;
            $flag = lc $flag;
            return $self->error("no value for flag: $flag")
                unless defined($value = $DEBUG_OPTIONS->{ $flag });
            $flag = $value;

            if ($debug & $flag) {
                $value = $DEBUG_OPTIONS->{ $flag };
                return $self->error("no value for flag: $flag") unless defined $value;
                push(@flags, $value);
            }
        }
        return wantarray ? @flags : join(', ', @flags);
    }
    else {
        @flags = split(/\W+/, $debug);
        $debug = 0;
        foreach $flag (@flags) {
            $value = $DEBUG_OPTIONS->{ $flag };
            return $self->error("unknown debug flag: $flag") unless defined $value;
            $debug |= $value;
        }
        return $debug;
    }
}


1;

__END__

=head1 NAME

Template::Constants - Defines constants for the Template Toolkit

=head1 SYNOPSIS

    use Template::Constants qw( :status :error :all );

=head1 DESCRIPTION

The C<Template::Constants> modules defines, and optionally exports into the
caller's namespace, a number of constants used by the L<Template> package.

Constants may be used by specifying the C<Template::Constants> package 
explicitly:

    use Template::Constants;
    print Template::Constants::STATUS_DECLINED;

Constants may be imported into the caller's namespace by naming them as 
options to the C<use Template::Constants> statement:

    use Template::Constants qw( STATUS_DECLINED );
    print STATUS_DECLINED;

Alternatively, one of the following tagset identifiers may be specified
to import sets of constants: 'C<:status>', 'C<:error>', 'C<:all>'.

    use Template::Constants qw( :status );
    print STATUS_DECLINED;

Consult the documentation for the C<Exporter> module for more information 
on exporting variables.

=head1 EXPORTABLE TAG SETS

The following tag sets and associated constants are defined: 

    :status
        STATUS_OK             # no problem, continue
        STATUS_RETURN         # ended current block then continue (ok)
        STATUS_STOP           # controlled stop (ok) 
        STATUS_DONE           # iterator is all done (ok)
        STATUS_DECLINED       # provider declined to service request (ok)
        STATUS_ERROR          # general error condition (not ok)

    :error
        ERROR_RETURN          # return a status code (e.g. 'stop')
        ERROR_FILE            # file error: I/O, parse, recursion
        ERROR_UNDEF           # undefined variable value used
        ERROR_PERL            # error in [% PERL %] block
        ERROR_FILTER          # filter error
        ERROR_PLUGIN          # plugin error

    :chomp                  # for PRE_CHOMP and POST_CHOMP
        CHOMP_NONE            # do not remove whitespace
        CHOMP_ONE             # remove whitespace to newline
        CHOMP_ALL             # old name for CHOMP_ONE (deprecated)
        CHOMP_COLLAPSE        # collapse whitespace to a single space
        CHOMP_GREEDY          # remove all whitespace including newlines

    :debug
        DEBUG_OFF             # do nothing
        DEBUG_ON              # basic debugging flag
        DEBUG_UNDEF           # throw undef on undefined variables
        DEBUG_VARS            # general variable debugging
        DEBUG_DIRS            # directive debugging
        DEBUG_STASH           # general stash debugging
        DEBUG_CONTEXT         # context debugging
        DEBUG_PARSER          # parser debugging
        DEBUG_PROVIDER        # provider debugging
        DEBUG_PLUGINS         # plugins debugging
        DEBUG_FILTERS         # filters debugging
        DEBUG_SERVICE         # context debugging
        DEBUG_ALL             # everything
        DEBUG_CALLER          # add caller file/line info
        DEBUG_FLAGS           # bitmap used internally

    :all
        All the above constants.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt> L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2007 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template>, C<Exporter>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
