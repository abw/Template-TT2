package Template::TT2::Iterator;

use Template::TT2::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Template::TT2::Base',
    utils       => 'blessed',
    accessors   => 'size max index count first last',
    constants   => 'HASH ARRAY STATUS_DONE',
    constant    => {
        ODD     => 'odd',
        EVEN    => 'even',
    };

*number = \&count;

our $AUTOLOAD;
our @ICFL      = qw( index count first last );
our @SMICFL    = qw( size max index count first last );
our @PREV_NEXT = qw( prev next ); 
our @MAX_INDEX = qw( max index );


sub new {
    my $class  = shift;
    my $data   = shift || [ ];
    my $params = shift || { };

    if (ref $data eq HASH) {
        # map a hash into a list of { key => ???, value => ??? } hashes,
        # one for each key, sorted by keys
        $data = [ 
            map { { key => $_, value => $data->{ $_ } } }
            sort keys %$data 
        ];
    }
    elsif (blessed $data && $data->can('as_list')) {
        $data = $data->as_list();
    }
    elsif (ref $data ne ARRAY) {
        # coerce any non-list data into an array reference
        $data  = [ $data ] ;
    }

    bless {
        init => $data,
    }, $class;
}


sub prepare {
    my $self  = shift;
    my $data  = $self->{ data } = $self->{ init };
    my $size  = scalar @$data;
    my $index = 0;

    $self->debug("preparing iterator: ", $self->dump_data_inline($data), "\n")
        if DEBUG;

    return undef
        unless $size;
    
    @$self{ @SMICFL }       # size, max, index, count, first last
        = ( $size, $size - 1, $index, 1, 1, $size > 1 ? 0 : 1, undef );
        
    @$self{ @PREV_NEXT }    # prev, next
        = (undef, $data->[$index + 1]);

    return $data
}


sub get_first {
    my $self = shift;
    my $data = $self->prepare
            || return (undef, STATUS_DONE);     # empty

    return $data->[0];
}


sub get_next {
    my $self = shift;
    my $data = $self->{ data } 
        || return $self->get_first;

    my ($max, $index) = @$self{ @MAX_INDEX };

    return (undef, STATUS_DONE)
        unless $index < $max;
        
    $index++;

    @$self{ @ICFL }         # index, count, first, last
        = ( $index, $index + 1, 0, $index == $max ? 1 : 0 );
        
    @$self{ @PREV_NEXT }    # prev, next
        = @$data[$index - 1, $index + 1];

    return $data->[$index];
}


sub get_all {
    my $self = shift;
    my $inc  = $self->{ data } ? 1 : 0;     # inc index if get_first has been called()
    my $data = $self->{ data }
            || $self->prepare
            || return (undef, STATUS_DONE);

    my ($max, $index) = @$self{ @MAX_INDEX };
    my @rest;

    $self->debug("index: $index  (+ inc: $inc)  max: $max") if DEBUG;

    # if there's still some data to go...
    if ($index + $inc <= $max) {
        # If get_first() has previously been called (i.e. $self->{ data }
        # is set) then $inc will contain 1 to indicate that we must increment
        # the index counter to step over the item already returned.
        $index += $inc;
        @rest = @$data[$index..$max];
        
        # update counters and flags
        @$self{ @ICFL }     # index, count, first, last
            = ( $max, $max + 1, 0, 1 );

        return \@rest;
    }
    else {
        return (undef, STATUS_DONE);
    }
}


sub odd {
    shift->{ count } % 2 ? 1 : 0
}


sub even {
    shift->{ count } % 2 ? 0 : 1
}


sub parity {
    shift->{ count } % 2 ? ODD : EVEN;
}

#========================================================================
#                   -----  PRIVATE DEBUG METHODS -----
#========================================================================

#------------------------------------------------------------------------
# _dump()
#
# Debug method which returns a string detailing the internal state of 
# the iterator object.
#------------------------------------------------------------------------

sub _dump {
    my $self = shift;
    join('',
         "  Data: ", $self->{ _DATA  }, "\n",
         " Index: ", $self->{ INDEX  }, "\n",
         "Number: ", $self->{ NUMBER }, "\n",
         "   Max: ", $self->{ MAX    }, "\n",
         "  Size: ", $self->{ SIZE   }, "\n",
         " First: ", $self->{ FIRST  }, "\n",
         "  Last: ", $self->{ LAST   }, "\n",
         "\n"
     );
}


1;

__END__
