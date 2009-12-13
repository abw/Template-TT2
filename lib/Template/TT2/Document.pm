##============================================================= -*-Perl-*-
#
# Template::TT2::Document
#
# DESCRIPTION
#   Module defining a class of objects which encapsulate compiled
#   templates, storing additional block definitions and metadata 
#   as well as the compiled Perl sub-routine representing the main
#   template content.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#============================================================================

package Template::TT2::Document;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Base',
    constants => 'UNICODE :error',
    accessors => 'modified';

use Badger::Debug ':debug';

our ($COMPERR, $AUTOLOAD);

BEGIN {
    # UNICODE is supported in versions of Perl from 5.008 onwards
    if (UNICODE) {
        if ($] > 5.008) {
            # utf8::is_utf8() available from Perl 5.8.1 onwards
            *is_utf8 = \&utf8::is_utf8;
        }
        elsif ($] == 5.008) {
            # use Encode::is_utf8() for Perl 5.8.0
            require Encode;
            *is_utf8 = \&Encode::is_utf8;
        }
    }
}

sub new {
    my ($class, $doc) = @_;
    my ($block, $defblocks, $variables, $metadata) = @$doc{ 
        qw( BLOCK DEFBLOCKS VARIABLES METADATA ) 
    };
    $defblocks ||= { };
    $variables ||= { };
    $metadata  ||= { };

    # evaluate Perl code in $block to create sub-routine reference if necessary
    unless (ref $block) {
        local $SIG{__WARN__} = \&catch_warnings;
        $COMPERR = '';

        # DON'T LOOK NOW! - blindly untainting can make you go blind!
        $block =~ /(.*)/s;
        $block = $1;
        
        $block = eval $block;
        return $class->error($@)
            unless defined $block;
    }

    # same for any additional BLOCK definitions
    my $perl;
    $defblocks = {
        map {
            $perl = $defblocks->{ $_ };
            unless (ref $perl) {
                # MORE BLIND UNTAINTING - turn away if you're squeamish
                $perl =~ /(.*)/s;
                $perl = eval($1) 
                    || return $class->error($@);
            }
            $_ => $perl
        } 
        keys %$defblocks
    };

    $class->debug("metadata: ", $class->dump_data($metadata)) if DEBUG;
    
    bless {
        %$metadata,
        _BLOCK     => $block,
        _DEFBLOCKS => $defblocks,
        _VARIABLES => $variables,
        _HOT       => 0,
    }, $class;
}

sub block {
    return $_[0]->{ _BLOCK };
}

sub blocks {
    return $_[0]->{ _DEFBLOCKS };
}

sub variables {
    return $_[0]->{ _VARIABLES };
}

sub process {
    my ($self, $context) = @_;
    my $defblocks = $self->{ _DEFBLOCKS };
    my $output;


    # check we're not already visiting this template
    return $context->throw(ERROR_FILE, "recursion into '$self->{ name }'")
        if $self->{ _HOT } && ! $context->{ RECURSION };   ## RETURN ##

    $context->visit($self, $defblocks);

    $self->{ _HOT } = 1;
    eval {
        my $block = $self->{ _BLOCK };
        $output = &$block($context);
    };
    $self->{ _HOT } = 0;

    $context->leave();

    die $context->catch($@)
        if $@;
        
    return $output;
}

sub AUTOLOAD {
    my $self   = shift;
    my $method = $AUTOLOAD;

    die "Invalid class method $method called against $self\n"
        unless ref $self;
        
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    return $self->{ $method };
}


#========================================================================
#                     -----  PRIVATE METHODS -----
#========================================================================


#------------------------------------------------------------------------
# _dump()
#
# Debug method which returns a string representing the internal state
# of the object.
#------------------------------------------------------------------------

sub _dump {
    my $self = shift;
    my $dblks;
    my $output = "$self : $self->{ name }\n";

    $output .= "BLOCK: $self->{ _BLOCK }\nDEFBLOCKS:\n";

    if ($dblks = $self->{ _DEFBLOCKS }) {
        foreach my $b (keys %$dblks) {
            $output .= "    $b: $dblks->{ $b }\n";
        }
    }

    return $output;
}


#========================================================================
#                      ----- CLASS METHODS -----
#========================================================================

#------------------------------------------------------------------------
# as_perl($content)
#
# This method expects a reference to a hash passed as the first argument
# containing 3 items:
#     METADATA   # a hash of template metadata
#     BLOCK      # string containing Perl sub definition for main block
#     DEFBLOCKS  # hash containing further subs for addional BLOCK defs
# It returns a string containing Perl code which, when evaluated and 
# executed, will instantiate a new Template::TT2::Document object with the 
# above data.  On error, it returns undef with an appropriate error
# message set in $ERROR.
#------------------------------------------------------------------------

sub as_perl {
    my ($class, $content) = @_;
    my ($block, $defblocks, $metadata) = @$content{ qw( BLOCK DEFBLOCKS METADATA ) };
    my $utf8 = '';

    $block =~ s/\n/\n    /g;
    $block =~ s/\s+$//;

    if (grep { ref $_ eq 'CODE' } values %$defblocks) {
        $class->debug_caller();
        $class->error("cannot compile CODE reference in DEFBLOCKS\n");
    }

    $defblocks = join('', map {
        my $code = $defblocks->{ $_ };
        $code =~ s/\n/\n        /g;
        $code =~ s/\s*$//;
        sprintf("        '%s' => %s,\n", $_, $code);
    } keys %$defblocks);
    $defblocks =~ s/\s+$//;

    $metadata = join('', map { 
        my $x = $metadata->{ $_ }; 
        $x =~ s/(['\\])/\\$1/g; 
        sprintf("        %-10s => '%s',\n", "'$_'", $x);
    } keys %$metadata);
    $metadata =~ s/\s+$//;

    my $body = <<EOF;
$class->new({
    METADATA => {
$metadata
    },
    BLOCK => $block,
    DEFBLOCKS => {
$defblocks
    },
});
EOF

    if (UNICODE && is_utf8($body)) {
        $utf8 = "use utf8;\n";
        $content->{ utf8 } = 1;     # ugly hack to send notification back
    }

    return <<EOF;
#------------------------------------------------------------------------
# Compiled template generated by Template::TT2 version $Template::TT2::VERSION
#------------------------------------------------------------------------

use strict;
use warnings;
use Template::TT2::Modules;
use Template::TT2::Constants 'STATUS_DONE';
use $class;
$utf8

$body

EOF

}


#------------------------------------------------------------------------
# catch_warnings($msg)
#
# Installed as
#------------------------------------------------------------------------

sub catch_warnings {
    $COMPERR .= join('', @_); 
}

    
1;

__END__
