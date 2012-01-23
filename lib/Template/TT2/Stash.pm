package Template::TT2::Stash;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Base',
    utils     => 'blessed reftype looks_like_number',
    throws    => 'undef',           # default exception type
    import    => 'class',
    constants => ':types :stash ERROR_UNDEF',
    constant  => {
        DOT   => 'dot',
    },
    messages  => {
        bad_dot    => 'Invalid dot operation: %s.%s',
        bad_assign => 'Invalid assignment to %s.%s',
        dot_undef  => '<2> is undefined for <1>',
        undefined  => 'Undefined variable: <1>',
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


INIT: {
    # pre-set $DEBUG flags in backend stashes
    $Template::TT2::Stash::XS::DEBUG   = DEBUG;
    $Template::TT2::Stash::Perl::DEBUG = DEBUG;

    # $BACKEND might be pre-defined by end user in which case, leave it alone
    unless (defined $BACKEND) {
        # otherwise look for XS goodness or fall back on pure Perl
        eval "use Template::TT2::Stash::XS";

        if ($@) {
            require Template::TT2::Stash::Perl;
            $BACKEND = 'Template::TT2::Stash::Perl';
        }
        else {
            $BACKEND = 'Template::TT2::Stash::XS';
        }
    }
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
    my ($self, $ident, $args) = @_;

    if ($self->{ _STRICT }) {
        # Sorry, but we can't provide a sensible source file and line without
        # re-designing the whole architecure of TT (see TT3)
        $self->throw_msg( 
            ERROR_UNDEF, undefined => $self->_reconstruct_ident($ident)
        );
    }
    else {
        # There was a time when I thought this was a good idea. But it's not.
        return '';
    }
}
 
sub _reconstruct_ident {
    my ($self, $ident) = @_;
    my ($name, $args, @output);
    my @input = ref $ident eq 'ARRAY' ? @$ident : ($ident);
 
    while (@input) {
        $name = shift @input;
        $args = shift @input || 0;
        $name .= '(' . join(', ', map { /^\d+$/ ? $_ : "'$_'" } @$args) . ')'
            if $args && ref $args eq 'ARRAY';
        push(@output, $name);
    }
    
    return join('.', @output);
}


sub define_vmethod {
    my ($class, $type, $name, $sub) = @_;
    my $op;
    $type = lc $type;

    if ($type =~ /^scalar|item|text$/) {
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

=head1 NAME

Template::TT2::Stash - template variable stash

=head1 SYNOPSIS

    use Template::TT2::Stash;
    
    my $stash = Template::TT2::Stash->new(
        answer => 42,
        arthur => {
            name  => 'Arthur Dent',
        },
        friends => ['Ford', 'Trillian'],
        hello   => sub {
            my $name = shift;
            "Hello $name!";
        },
    );
    
    # simple form: 'foo.bar'
    $stash->get('answer');                      # 42
    $stash->get('arthur.name');                 # Arthur Dent

    # expanded form: [foo => \@args, bar => \@args, ... ]
    $stash->get([ answer => 0 ]);               # 42
    $stash->get([ arthur => 0, name => 0 ]);    # Arthur Dent
    $stash->get([ hello => ['World'] ]);        # Hello World!
    
    # setting variable values
    $stash->set( x => 100 );
    $stash->set(\@expanded, $value);
    
    # default variable value
    $stash->set( x => 100, 1);
    $stash->set(\@expanded, $value, 1);
    
    # set variable values en masse
    $stash->update(\%new_vars)
    
    # methods for (de-)localising variables
    $stash = $stash->clone(\%new_vars);
    $stash = $stash->declone();

=head1 DESCRIPTION

The C<Template::TT2::Stash> module defines an object class which is used to
store variable values for the runtime use of the template processor. Variable
values are stored internally in a hash reference (which itself is blessed to
create the object) and are accessible via the L<get()> and L<set()> methods.

Variables may reference hash arrays, lists, subroutines and objects
as well as simple values.  The stash automatically performs the right
magic when dealing with variables, calling code or object methods,
indexing into lists, hashes, etc.

The stash has L<clone()> and L<declone()> methods which are used by the
template processor to make temporary copies of the stash for
localising changes made to variables.

The C<Template::TT2::Stash> acts as a simple front-end to either 
L<Template::TT2::Stash::XS> or L<Template::TT2::Stash::Perl>, depending
on which you have available.

=head1 METHODS

The following methods are implemented in addition to those inherited
from L<Template::TT2::Base> and L<Badger::Base>.

=head2 new(\%params)

The C<new()> constructor method creates and returns a reference to a new
C<Template::TT2::Stash> object.  

    my $stash = Template::TT2::Stash->new();

A list or reference to a hash array of variable definitions can be passed
as arguments to initialise the stash.

    my $stash = Template::TT2::Stash->new(
        var1 => 'value1', 
        var2 => 'value2' 
    );

=head2 get($variable)

The C<get()> method retrieves the variable named by the first parameter.

    $value = $stash->get('var1');

Dotted compound variables can be retrieved by specifying the variable
elements by reference to a list.  Each node in the variable occupies
two entries in the list.  The first gives the name of the variable
element, the second is a reference to a list of arguments for that 
element, or C<0> if none.

    # TT 
    [% foo.bar(10).baz(20) %]
    
    # Perl equivalent
    $stash->get([ 'foo', 0, 'bar', [ 10 ], 'baz', [ 20 ] ]);

=head2 set($variable, $value, $default)

The C<set()> method sets the variable name in the first parameter to the 
value specified in the second.

    $stash->set('var1', 'value1');

If the third parameter evaluates to a true value, the variable is
set only if it did not have a true value before.

    $stash->set('var2', 'default_value', 1);

Dotted compound variables may be specified as per L<get()> above.

    # TT 
    [% foo.bar = 30 %]
    
    # Perl equivalent
    $stash->set([ 'foo', 0, 'bar', 0 ], 30);

The magical variable 'C<IMPORT>' can be specified whose corresponding
value should be a hash reference.  The contents of the hash array are
copied (i.e. imported) into the current namespace.

    # foo.bar = baz, foo.wiz = waz
    $stash->set('foo', { 'bar' => 'baz', 'wiz' => 'waz' });
    
    # import 'foo' into main namespace: bar = baz, wiz = waz
    $stash->set('IMPORT', $stash->get('foo'));

=head2 update(\%vars)

This method can be called to update the stash with new variables.  

    $stash->update({
        foo => 10,
        bar => 20,
    });

=head2 clone(\%params)

The C<clone()> method creates and returns a new C<Template::TT2::Stash> object
which represents a localised copy of the parent stash. Variables can be freely
updated in the cloned stash and when L<declone()> is called, the original stash
is returned with all its members intact and in the same state as they were
before C<clone()> was called.

For convenience, a hash of parameters may be passed into C<clone()> which 
is used to update any simple variable (i.e. those that don't contain any 
namespace elements like C<foo> and C<bar> but not C<foo.bar>) variables while 
cloning the stash.  For adding and updating complex variables, the L<set()> 
method should be used after calling C<clone().>  This will correctly resolve
and/or create any necessary namespace hashes.

A cloned stash maintains a reference to the stash that it was copied 
from in its C<_PARENT> member.

=head2 declone()

The C<declone()> method returns the C<_PARENT> reference and can be used to
restore the state of a stash as described above.

=head2 define_vmethod($type,$name,\&code)

This method can be used to define a new 
L<virtual method|Template::Manual::VMethods>.

    $stash->define_vmethod( text => jumble => sub {
        my $text = shift;
        # do something to $text;
        return $text;
    } );

=head2 define_vmethods($type,\%vmethods)

This method can be used to define several new 
L<virtual methods|Template::Manual::VMethods> in one go.

    $stash->define_vmethods( 
        text => {
            jumble => sub { ... },
            fumble => sub { ... },
            bumble => sub { ... },
        }
    );

=head2 getref($variable)

This method is used to implement the undocumented variable reference
feature in TT2.  Although not widely known (due to the intentional lack
of documentation), it is possible to create a "reference" to a template
variable which can be evaluated at some later date.  For the technically
minded, it performs a partial evaluation of any dotted components in the
variable and then creates a closure which evaluates the final element 
when called.

=head2 undefined($name,$args)

This method is called when an undefined variable is encountered.  It returns
a zero-length string (e.g. C<''>).  Subclasses may re-define this to implement
alternate behaviours.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::TT2>, L<Template::TT2::Stash::Perl>, L<Template::TT2::Stash::XS>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
