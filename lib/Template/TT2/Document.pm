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
    constants => 'UNICODE :error';

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
    my ($block, $defblocks, $metadata) = @$doc{ 
        qw( BLOCK DEFBLOCKS METADATA ) 
    };
    $defblocks ||= { };
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
    @$defblocks{ keys %$defblocks } = 
        # MORE BLIND UNTAINTING - turn away if you're squeamish
        map { 
            ref($_) 
                ? $_ 
                : ( /(.*)/s && eval($1) or return $class->error($@) )
            } values %$defblocks;
    
    bless {
        %$metadata,
        _BLOCK     => $block,
        _DEFBLOCKS => $defblocks,
        _HOT       => 0,
    }, $class;
}

sub block {
    return $_[0]->{ _BLOCK };
}

sub blocks {
    return $_[0]->{ _DEFBLOCKS };
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

    $block =~ s/\n/\n    /g;
    $block =~ s/\s+$//;

    $defblocks = join('', map {
        my $code = $defblocks->{ $_ };
        $code =~ s/\n/\n        /g;
        $code =~ s/\s*$//;
        "        '$_' => $code,\n";
    } keys %$defblocks);
    $defblocks =~ s/\s+$//;

    $metadata = join('', map { 
        my $x = $metadata->{ $_ }; 
        $x =~ s/(['\\])/\\$1/g; 
        "        '$_' => '$x',\n";
    } keys %$metadata);
    $metadata =~ s/\s+$//;

    return <<EOF
#------------------------------------------------------------------------
# Compiled template generated by Template::TT2 version $Template::TT2::VERSION
#------------------------------------------------------------------------

use Template::TT2::Modules;
use Template::TT2::Constants 'STATUS_DONE';
use $class;

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
}


#------------------------------------------------------------------------
# write_perl_file($filename, \%content)
#
# This method calls as_perl() to generate the Perl code to represent a
# compiled template with the content passed as the second argument.
# It then writes this to the file denoted by the first argument.
#
# Returns 1 on success.  On error, sets the $ERROR package variable
# to contain an error message and returns undef.
#------------------------------------------------------------------------

sub write_perl_file {
    my ($class, $file, $content) = @_;
    my ($fh, $tmpfile);
    
    return $class->error("invalid filename: $file")
        unless $file =~ /^(.+)$/s;

    eval {
        require File::Temp;
        require File::Basename;
        ($fh, $tmpfile) = File::Temp::tempfile( 
            DIR => File::Basename::dirname($file) 
        );
        my $perlcode = $class->as_perl($content) || die $!;
        
        if (UNICODE && is_utf8($perlcode)) {
            $perlcode = "use utf8;\n\n$perlcode";
            binmode $fh, ":utf8";
        }
        print $fh $perlcode;
        close($fh);
    };
    return $class->error($@) if $@;
    return rename($tmpfile, $file)
        || $class->error($!);
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
