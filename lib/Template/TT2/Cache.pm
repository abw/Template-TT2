#========================================================================
#
# Template::TT2::Cache
#
# DESCRIPTION
#   A simple cache for compiled templates.  It can be size limited and
#   will retain the most recently used templates and discard the least
#   recently used.
# 
# AUTHOR
#   Andy Wardley <abw@wardley.org>
#
#========================================================================

package Template::TT2::Cache;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Base',
    words     => 'CACHE_SIZE',
    constants => ':cache',
    constant  => {
        PREV  => 0,
        NAME  => 1,
        DATA  => 2, 
        NEXT  => 3,
    };

our $CACHE_SIZE = CACHE_UNLIMITED;


sub init {
    my ($self, $config) = @_;

    # 'size' is the new skool name for the old skool CACHE_SIZE
    $config->{ size } = $config->{ CACHE_SIZE }
        if defined $config->{ CACHE_SIZE };

    # if neither is defined in $config then we use $CACHE_SIZE
    $config->{ size } = $self->class->any_var(CACHE_SIZE)
        unless defined $config->{ size };
    
    $self->{ size } = $config->{ size };        # max slots allowed
    $self->{ slot } = { };                      # slot lookup by name
    $self->{ used } = 0;                        # number of slots used

    # TODO: add time?

    return $self;
}


sub set {
    my ($self, $name, $data) = @_;
    my $size = $self->{ size };
    my ($head, $slot);

    return $self->error("name not defined from ", join(', ', caller(0)), "\n")
        unless defined $name;

    if ($size == CACHE_UNLIMITED) {
        # no size limit so cache everything directly in slot hash.
        # NOTE: this is an optimisation which changes the shape of the data
        # stored in the cache so you can't change the size once a cache is live
        $self->debug("adding data to cache for '$name'\n") if DEBUG;
        $self->{ slot }->{ $name } = \$data;    # store ref so always true
        return 1;
    }
    elsif ($size <= 0) {
        # cache size of 0 indicates no caching, also treat any other negative
        # numbers (other than the special CACHE_UNLIMITED value of -1) as 0
        return 0;
    }
    
    # at this point we know we have a positive, non-zero cache size
    
    if ($slot = $self->{ slot }->{ $name }) {
        # we 've got an existing slot for the name provided so we store the
        # new data in the old slot and pull it out of it's current position
        # in the list ready to add at the head below
        $self->debug("recycling existing cache slot for '$name'\n") if DEBUG;
        $self->_remove_slot($slot);
        $slot->[ DATA ] = $data;
    }
    elsif ($self->{ used } >= $size) {
        # all slots are filled so recycle the least recently used
        $self->debug("recycling oldest cache slot '$self->{tail}->[NAME]' for '$name'\n") if DEBUG;
            
        # remove the last slot (least recently used)
        $slot = $self->_remove_slot($self->{ tail });

        # delete old slot lookup entry and add a new one
        delete $self->{ slot }->{ $slot->[ NAME ] };
        $self->{ slot }->{ $name } = $slot;

        # add the name and data to the slot
        $slot->[ NAME ] = $name;
        $slot->[ DATA ] = $data;
    }
    else {
        # we're under the size limit so create a new slot
        $self->debug("adding new cache slot for '$name'\n") if DEBUG;
        $slot = [ undef, $name, $data, undef ];
        $self->{ slot }->{ $name } = $slot;
        $self->{ used }++;
    }

    # add slot to head of list to indicate most recently used
    $self->_insert_slot($slot);
    
    return 1;
}


sub get {
    my ($self, $name) = @_;

    # fetch slot by name
    my $slot = $self->{ slot }->{ $name }
        || return $self->decline("not found in cache: $name");

    # if size is unlimited then the cache holds a reference to the 
    # original data rather than a slot record
    return $$slot
        if $self->{ size } == CACHE_UNLIMITED;

    # otherwise cache is size limited so we need to move the slot up to
    # the head of list (if it's not already there) to indicate that it 
    # has been used most recently
    unless($self->{ head } == $slot) {
        $self->_remove_slot($slot);
        $self->_insert_slot($slot);
    }

    return $slot->[ DATA ];
}


sub clear {
    my $self = shift;
    my ($slot, $next);

    $self->debug("clearing cache slots\n") if $self->{ DEBUG };

    $slot = $self->{ head };

    while ($slot) {
        $next = $slot->[ NEXT ];
        undef $slot->[ PREV ];
        undef $slot->[ NEXT ];
        $slot = $next;
    }
    undef $self->{ head };
    undef $self->{ tail };
    $self->{ used } = 0;
}


sub _insert_slot {
    my ($self, $slot) = @_;
    my $head = $self->{ head };

    # add slot at head of list, pointing forwards to old head
    $head->[ PREV ] = $slot if $head;
    $slot->[ NEXT ] = $head;
    $slot->[ PREV ] = undef;
    $self->{ head } = $slot;
    $self->{ tail } = $slot unless $self->{ tail };

    return $slot;
}


sub _remove_slot {
    my ($self, $slot) = @_;
    my $prev;

    # fix link from previous slot forward to this slot
    if ($prev = $slot->[ PREV ]) {
        $prev->[ NEXT ] = $slot->[ NEXT ];
        $slot->[ PREV ] = undef;
    }
    else {
        $self->{ head } = $slot->[ NEXT ];
    }

    # fix link from next slot backward to this slot
    if ($slot->[ NEXT ]) {
        $slot->[ NEXT ]->[ PREV ] = $prev;
        $slot->[ NEXT ] = undef;
    }
    else {
        $self->{ tail } = $prev;
    }

    return $slot;
}


sub _slot_report {
    my $self   = shift;
    my $output = '';
    my $slot   = $self->{ head };
    
    return $self->not_implemented('for unlimited size cache')
        if $self->{ size } == CACHE_UNLIMITED;

    while ($slot) {
        my ($prev, $name, $data, $next) = @$slot;
        my $prevname = $prev ? $prev->[NAME] : '<NULL>';
        my $nextname = $next ? $next->[NAME] : '<NULL>';
        $output .= "$prevname <-- [$name] --> ${nextname}\n";
        $slot = $next;
    }
    $output .= "tail: $self->{ tail }->[NAME]\n";
    return $output;
}


sub DESTROY {
    shift->clear;
}


1;

__END__

=head1 NAME

Template::TT2::Cache - in-memory cache for template components

=head1 SYNOPSIS

    use Template::TT2::Cache;
    
    my $cache = Template::TT2::Cache->new( size => 32 );
    
    $cache->set( foo => $foo );
    
    # ...later...
    
    $foo = $cache->get('foo')
        || warn "foo has expired from cache\n";

=head1 DESCRIPTION

The C<Template::TT2::Cache> module implements a simple in-memory cache for
compiled template documents.

The most time-consuming part of processing a template is the initial phase in
which we read in the template source, parse it, and compile it into Perl code.
The Perl code is then evaluated and should result in an object being created
which implements the functionality of the original template. Fortunately, we
only need to compile the template once and can then re-use the generated
object as many times as we like.

C<Template::TT2::Cache> provides a simple mechanism for limiting the number of
templates that are cached and automatically discards the least-recently-used
component when the limit is reached.

It also defines a simple API and can act as a base class for modules that
implement different caching mechanisms. The API is deliberately compatible
with the L<Cache::Cache> modules, allowing you to use any of them as a direct
replacement for C<Template::TT2::Cache>.

=head1 METHODS

=head2 new()

Constructor method which creates a new C<Template::TT2::Cache> object.  

    use Template::TT2::Cache;
    
    my $cache = Template::TT2::Cache->new();

The C<CACHE_SIZE> parameter can be provided to define a limit to the
number of items that the cache will store at any one time.

    my $cache = Template::TT2::Cache->new( CACHE_SIZE => 32 );

The C<size> parameter can be used as a direct alias for C<CACHE_SIZE>.

    my $cache = Template::TT2::Cache->new( size => 32 );

Set C<size> to C<0> to disable any caching.

    my $cache = Template::TT2::Cache->new( size => 0 );

The default C<size> value is C<-1> which indicates an unlimited size.
The L<Template::TT2::Constants> module defines the C<CACHE_UNLIMITED>
constant for this value.
    
    use Template::TT2::Constants 'CACHE_UNLIMITED';
    
    my $cache = Template::TT2::Cache->new( size => CACHE_UNLIMITED );

=head2 set($name, $component)

Add an item to the cache.  The first argument provides a name for the
component passed as the second argument, by which it can subsequently
be fetched via the C<get()> method.

    $cache->set( foo => $foo_component );

=head2 get($name)

Fetch an item from the cache previously stored by calling C<set()>.
If the item is not in the cache, either because it was never been 
put in the cache or because it was, but has subsequently expired, 
then the method returns C<undef>.

=head2 clear()

This method deletes all items from the cache and frees the memory associated
with the cache slots. It is called automatically by the L<DESTROY> method when
the cache object goes out of scope.

For the technically minded, the Least-Recently-Used algorithm implements a
doubly linked list of slots. Perl cannot free this data structure
automatically due to the circular references between the forward (C<NEXT>) and
backward (C<PREV>) references. This method walks the list explciitly deleting
all the C<NEXT/PREV> references, allowing the proper cleanup to occur and
memory to be repooled.

=head1 INTERNAL METHODS

=head2 _insert_slot(\@slot)

Internal method to insert a cache slot at the head of the linked list.
New slots are always inserted at the head of the list.  Each time an 
entry is fetched from the cache, we remove the slot from its current
position in the list and re-insert it at the head.  Thus, the list remain
sorted in most-recently-used to least-recently-used order.

    # first and last items in slot are prev/next references which the
    # _insert_slot() method will fill in
    $self->_insert_slot([undef, $name, $data, undef]);

=head2 _remove_slot(\@slot)

Internal method to remove a slot from the linked list.

    $self->_remove_slot($slot);

=head2 DESTROY

Perl calls this method automatically when the cache object goes out of
scope.  It calls the L<clear()> method to release the memory
retained by the cache slots.

=head1 AUTHOR

Andy Wardley  L<http://wardley.org>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 ROADMAP

This module will become C<Template::Cache> in version 3 of the Template
Toolkit.

=head1 SEE ALSO

See L<Cache::Cache> for various different caching modules that implement
different caching strategies and can be used in place of
C<Template::TT2::Cache>.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:


