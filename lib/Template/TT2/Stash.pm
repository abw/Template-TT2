package Template::TT2::Stash;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Base',
    utils     => 'blessed reftype looks_like_number',
    throws    => 'undef',           # default exception type
    import    => 'class',
    constants => ':types :stash',
    constant  => {
        DOT   => 'dot',
    },
    messages  => {
        bad_dot    => 'Invalid dot operation: %s.%s',
        bad_assign => 'Invalid assignment to %s.%s',
        undefined  => '<2> is undefined for <1>',
    };

use Template::TT2::VMethods;
use Badger::Debug ':dump debug_caller';


#------------------------------------------------------------------------
# Virtual Methods
#
# If any of $ROOT_OPS, $SCALAR_OPS, $HASH_OPS or $LIST_OPS are already
# defined then we merge their contents with the default virtual methods
# define by Template::TT2::VMethods.  Otherwise we can directly alias the 
# corresponding Template::TT2::VMethod package vars.
#------------------------------------------------------------------------

our $ROOT_OPS = defined $ROOT_OPS 
    ? { %{$Template::TT2::VMethods::ROOT_VMETHODS}, %$ROOT_OPS }
    :     $Template::TT2::VMethods::ROOT_VMETHODS;

our $SCALAR_OPS = defined $SCALAR_OPS 
    ? { %{$Template::TT2::VMethods::TEXT_VMETHODS}, %$SCALAR_OPS }
    :     $Template::TT2::VMethods::TEXT_VMETHODS;

our $HASH_OPS = defined $HASH_OPS 
    ? { %{$Template::TT2::VMethods::HASH_VMETHODS}, %$HASH_OPS }
    :     $Template::TT2::VMethods::HASH_VMETHODS;

our $LIST_OPS = defined $LIST_OPS 
    ? { %{$Template::TT2::VMethods::LIST_VMETHODS}, %$LIST_OPS }
    :     $Template::TT2::VMethods::LIST_VMETHODS;


#-----------------------------------------------------------------------
# load Template::TT2::Stash::XS if we can
#   or Template::TT2::Stash::Perl if not
#-----------------------------------------------------------------------

our $PRIVATE = STASH_PRIVATE;
our $IMPORT  = STASH_IMPORT;
our $BACKEND;

$Template::TT2::Stash::XS::DEBUG   = DEBUG;
$Template::TT2::Stash::Perl::DEBUG = DEBUG;

eval "use Template::TT2::Stash::XS";
if ($@) {
    require Template::TT2::Stash::Perl;
    $BACKEND = 'Template::TT2::Stash::Perl';
}
else {
    $BACKEND = 'Template::TT2::Stash::XS';
}

sub new {
    my $class   = shift;
    my $params  = ref $_[0] eq HASH ? shift : { @_ };
    my $backend = ($class eq __PACKAGE__)
        ? $BACKEND
        : $class;
    $class->debug("creating $backend stash") if DEBUG;
    bless {
        global  => { },
        %$params,
        %$ROOT_OPS,
        _PARENT => undef,
        _DEBUG  => $DEBUG,
    }, $backend;
}

sub clone {
    my $self   = shift;
    my $params = @_ == 1 ? shift : { @_ };
    my $import = $params->{ $IMPORT };
    $params ||= { };

    # handle the magic 'import' variable
    if (defined $import && ref $import && reftype $import eq HASH) {
        delete $params->{ import };
    }
    else {
        undef $import;
    }

    my $clone = bless { 
        %$self,         # copy all parent members
        %$params,       # copy all new data
        '_PARENT' => $self,     # link to parent
    }, ref $self;
    
    # perform hash import if defined
    &{ $HASH_OPS->{ import } }($clone, $import)
        if defined $import;

    return $clone;
}

sub declone {
    my $self = shift;
    $self->{ _PARENT } || $self;
}

sub get {
    shift->not_implemented('in base class');
}

sub set {
    shift->not_implemented('in base class');
}

sub getref {
    my ($self, $ident, $args) = @_;
    my $dot = $self->can(DOT)
        || $self->error("Cannot locate dot() method for $self");  # lookup method once and call direct
    my ($root, $item, $result);
    $root = $self;

    if (ref $ident eq ARRAY
        || ($ident =~ /\./) 
        && ($ident = [ map { s/\(.*$//; ($_, 0) } split(/\./, $ident) ])) {
        my $size = $#$ident;

        foreach (my $i = 0; $i <= $size; $i += 2) {
            ($item, $args) = @$ident[$i, $i + 1]; 
            last if $i >= $size - 2;  # don't evaluate last node
            last unless defined 
                ($root = $dot->($self, $root, $item, $args));
        }
    }
    else {
        $item = $ident;
    }
    
    if (defined $root) {
        return sub { 
            my @args = (@{$args||[]}, @_);
            $dot->($self, $root, $item, \@args);
        }
    }
    else {
        return sub { '' };
    }
}

sub update {
    my ($self, $params) = @_;

    # look out for magical 'import' argument to import another hash
    my $import = $params->{ $IMPORT };
    if (defined $import && ref $import && reftype $import eq HASH) {
        @$self{ keys %$import } = values %$import;
        delete $params->{ import };
    }

    @$self{ keys %$params } = values %$params;
}

sub undefined {
    my ($self, $ident, $args);
    return '';
}

sub define_vmethod {
    my ($class, $type, $name, $sub) = @_;
    my $op;
    $type = lc $type;

    if ($type =~ /^scalar|item$/) {
        $op = $SCALAR_OPS;
    }
    elsif ($type eq 'hash') {
        $op = $HASH_OPS;
    }
    elsif ($type =~ /^list|array$/) {
        $op = $LIST_OPS;
    }
    else {
        $class->error("Invalid vmethod type: $type");
    }

    $op->{ $name } = $sub;

    return 1;
}

sub define_vmethods {
    my ($class, $type, $vmethods) = @_;
    while (my ($name, $code) = each %$vmethods) {
        $class->define_vmethod($type, $name, $code);
    }
}

1;

__END__
