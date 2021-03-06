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
#   Copyright (C) 1996-2012 Andy Wardley.  All Rights Reserved.
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
            modules => 'TT2_CACHE TT2_CONTEXT TT2_DIRECTIVE TT2_DOCUMENT
                        TT2_EXCEPTION TT2_FILTER TT2_HUB TT2_ITERATOR 
                        TT2_MODULES TT2_PARSER TT2_PLUGIN TT2_STORE 
                        TT2_STASH TT2_VIEW
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
                        DEBUG_SERVICE DEBUG_ALL DEBUG_CALLER DEBUG_FLAGS
                        @DEBUG_VALUES $DEBUG_OPTIONS',
            cache   => 'CACHE_UNLIMITED',
            flow    => 'FLOW_STOP',
            stash   => 'STASH_PRIVATE STASH_IMPORT STASH_UNDEF',
        },
        any => 'MSWIN32 UNICODE',
    },
    constant => {
        # modules
        TT2_CACHE       => 'Template::TT2::Cache',
        TT2_CONTEXT     => 'Template::TT2::Context',
        TT2_DIRECTIVE   => 'Template::TT2::Directive',
        TT2_DOCUMENT    => 'Template::TT2::Document',
        TT2_EXCEPTION   => 'Template::TT2::Exception',
        TT2_FILTER      => 'Template::TT2::Filter',
        TT2_HUB         => 'Template::TT2::Hub',
        TT2_ITERATOR    => 'Template::TT2::Iterator',
        TT2_MODULES     => 'Template::TT2::Modules',
        TT2_PARSER      => 'Template::TT2::Parser',
        TT2_PLUGIN      => 'Template::TT2::Plugin',
        TT2_STORE       => 'Template::TT2::Store',
        TT2_STASH       => 'Template::TT2::Stash',
        TT2_VIEW        => 'Template::TT2::View',

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

        MSWIN32         => $^O eq 'MSWin32' ? 1 : 0,
        UNICODE         => $] > 5.007       ? 1 : 0,

        # NOTE: for some unknown reason, I'm getting a segfault when the 
        # qr// isn't the last item.  This is almost certainly a bug in Perl.
        
        # stash defaults
        STASH_IMPORT    => 'import',    # magical import variable
        STASH_PRIVATE   => qr/^[_.]/,   # private members begin with _ or .
    };

our @DEBUG_VALUES = qw( 
    DEBUG_OFF DEBUG_ON DEBUG_UNDEF DEBUG_VARS DEBUG_DIRS DEBUG_STASH 
    DEBUG_CONTEXT DEBUG_PARSER DEBUG_TEMPLATES DEBUG_PLUGINS DEBUG_FILTERS
    DEBUG_SERVICE DEBUG_ALL DEBUG_CALLER
);

our $DEBUG_OPTIONS = {
    off       => DEBUG_OFF,
    on        => DEBUG_ON,
    undef     => DEBUG_UNDEF,
    vars      => DEBUG_VARS,
    dirs      => DEBUG_DIRS,
    stash     => DEBUG_STASH,
    context   => DEBUG_CONTEXT,
    parser    => DEBUG_PARSER,
    templates => DEBUG_TEMPLATES,
    plugins   => DEBUG_PLUGINS,
    filters   => DEBUG_FILTERS,
    service   => DEBUG_SERVICE,
    all       => DEBUG_ALL,
    caller    => DEBUG_CALLER,
};


1;

__END__

=head1 NAME

Template::Constants - Defines constants for the Template Toolkit

=head1 SYNOPSIS

    use Template::TT2::Constants qw( :status :error :all );

=head1 DESCRIPTION

The C<Template::Constants> modules defines, and optionally exports into the
caller's namespace, a number of constants used by the L<Template> package.
It is a subclass of L<Badger::Contants> and inherits all of the consant
definitions that it provides.

Constants may be used by specifying the C<Template::TT2::Constants> package 
explicitly:

    use Template::TT2::Constants;
    print Template::TT2::Constants::STATUS_DECLINED;

Constants may be imported into the caller's namespace by naming them as 
options to the C<use Template::TT2::Constants> statement:

    use Template::TT2::Constants qw( STATUS_DECLINED );
    print STATUS_DECLINED;

Alternatively, one of the tagset identifiers listed below may be specified
to import sets of constants: 'C<:status>', 'C<:error>', 'C<:all>'.

    use Template::TT2::Constants qw( :status );
    print STATUS_DECLINED;

Consult the documentation for the C<Exporter> and/or C<Badger::Exporter>
modules for more information  on exporting variables.

=head1 EXPORTABLE TAG SETS

The following tag sets and associated constants are defined: 

=head2 :cache

Exports the following constants which can be used to indicate an unlimited
template cache size via the C<CACHE_SIZE> option

    CACHE_UNLIMITED         # unlimited cache size

=head2 :chomp

Exports the following constants used to control whitespace chomping behaviour
via the C<PRE_CHOMP> and C<POST_CHOMP> options.

    CHOMP_NONE              # do not remove whitespace
    CHOMP_ONE               # remove whitespace to newline
    CHOMP_ALL               # old name for CHOMP_ONE (deprecated)
    CHOMP_COLLAPSE          # collapse whitespace to a single space
    CHOMP_GREEDY            # remove all whitespace including newlines

=head2 :debug

Exports the following constants used to enable debugging in various different
components via the C<DEBUG> option.

    DEBUG_OFF               # do nothing
    DEBUG_ON                # basic debugging flag
    DEBUG_UNDEF             # throw undef on undefined variables
    DEBUG_VARS              # general variable debugging
    DEBUG_DIRS              # directive debugging
    DEBUG_STASH             # general stash debugging
    DEBUG_CONTEXT           # context debugging
    DEBUG_PARSER            # parser debugging
    DEBUG_PROVIDER          # provider debugging
    DEBUG_PLUGINS           # plugins debugging
    DEBUG_FILTERS           # filters debugging
    DEBUG_SERVICE           # context debugging
    DEBUG_ALL               # everything
    DEBUG_CALLER            # add caller file/line info
    DEBUG_FLAGS             # bitmap used internally

=head2 :error

Exports the following constants used internally to indicate different
exception types.

    ERROR_RETURN            # return a status code (e.g. 'stop')
    ERROR_FILE              # file error: I/O, parse, recursion
    ERROR_UNDEF             # undefined variable value used
    ERROR_PERL              # error in [% PERL %] block
    ERROR_FILTER            # filter error
    ERROR_PLUGIN            # plugin error

=head2 :flow

Exports the following constant that is used internally for flow control in 
templates.

    FLOW_STOP               # used to implement [% STOP %] directive

=head2 :parse

Exports the following constants used internally in the template parser.

    PARSE_CONTINUE          # carry on
    PARSE_ACCEPT            # jolly good
    PARSE_ERROR             # oh noes
    PARSE_ABORT             # I give up
    STATE_DEFAULT           # default action
    STATE_ACTIONS           # specific actions
    STATE_GOTOS             # goto table for next state

=head2 :status

Exports the following constants used as status codes.

    STATUS_OK               # no problem, continue
    STATUS_RETURN           # ended current block then continue (ok)
    STATUS_STOP             # controlled stop (ok) 
    STATUS_DONE             # iterator is all done (ok)
    STATUS_DECLINED         # provider declined to service request (ok)
    STATUS_ERROR            # general error condition (not ok)

=head2 :stash

Exports the following constant used internally in the variable stash.

    STASH_IMPORT            # name of the magical 'import' variable
    STASH_PRIVATE           # regex to match private data members

=head2 :modules

Exports the following constants that define the module names of various TT2 
components.

    TT2_CACHE               # Template::TT2::Cache
    TT2_CONTEXT             # Template::TT2::Context
    TT2_DIRECTIVE           # Template::TT2::Directive
    TT2_DOCUMENT            # Template::TT2::Document
    TT2_EXCEPTION           # Template::TT2::Exception
    TT2_FILTER              # Template::TT2::Filter
    TT2_HUB                 # Template::TT2::Hub
    TT2_ITERATOR            # Template::TT2::Iterator
    TT2_MODULES             # Template::TT2::Modules
    TT2_PARSER              # Template::TT2::Parser
    TT2_PLUGIN              # Template::TT2::Plugin
    TT2_STORE               # Template::TT2::Store
    TT2_STASH               # Template::TT2::Stash
    TT2_VIEW                # Template::TT2::View

The following are also included for backward/forward compatibility with 
other versions of the Template Toolkit.

    TT_DOCUMENT             # Template::Document
    TT_EXCEPTION            # Template::Exception
    TT_ITERATOR             # Template::Iterator

=head2 :all

Exports all the above constants.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt> L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2012 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template>, C<Badger::Constants>, L<Badger::Exporter>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
