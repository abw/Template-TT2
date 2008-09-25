package Template::TT2::Stash::Perl;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Stash',
    utils     => 'blessed reftype looks_like_number',
    constants => ':types :stash',
    constant  => {
        DOT   => 'dot',
    };

our ($PRIVATE, $IMPORT, $ROOT_OPS, $SCALAR_OPS, $HASH_OPS, $LIST_OPS); 
*PRIVATE    = \$Template::TT2::Stash::PRIVATE;
*IMPORT     = \$Template::TT2::Stash::IMPORT;
*ROOT_OPS   = \$Template::TT2::Stash::ROOT_OPS;
*SCALAR_OPS = \$Template::TT2::Stash::SCALAR_OPS;
*HASH_OPS   = \$Template::TT2::Stash::HASH_OPS;
*LIST_OPS   = \$Template::TT2::Stash::LIST_OPS;

sub get {
    my ($self, $ident, $opts) = @_;
    my $dot = $self->can(DOT);  # lookup method once and call direct
    my ($name, $args, $root, $result);
    $root = $self;

    if (ref $ident eq ARRAY
        || ($ident =~ /\./) 
        && ($ident = [ map { s/\(.*$//; ($_, 0) } split(/\./, $ident) ])) {
        my $size = $#$ident;

        $self->debug("get(", $self->dump_data_inline($ident), ', ', $opts || 0, ')') if DEBUG;

        # if $ident is a list reference, then we evaluate each item in the 
        # identifier against the previous result, using the root stash 
        # ($self) as the first implicit 'result'...
        foreach (my $i = 0; $i <= $size; $i += 2) {
            $result = $dot->($self, $root, @$ident[$i, $i+1]);
            last unless defined $result;
            $root = $result;
        }
    }
    else {
        $result = $dot->($self, $root, $ident, $opts);
    }

    return 
        defined $result 
              ? $result 
              : $self->undefined($ident, $opts);
}

sub set {
    my ($self, $ident, $value, $default) = @_;
    my $dot = $self->can(DOT);  # lookup method once and call direct
    my ($root, $result, $error);

    $root = $self;

    ELEMENT: {
        if (ref $ident eq ARRAY
            || ($ident =~ /\./) 
            && ($ident = [ map { s/\(.*$//; ($_, 0) }
                           split(/\./, $ident) ])) {
            
            # a compound identifier may contain multiple elements (e.g. 
            # foo.bar.baz) and we must first resolve all but the last, 
            # using dot() with the $lvalue flag set which will create 
            # intermediate hashes if necessary...
            my $size = $#$ident;
            foreach (my $i = 0; $i < $size - 2; $i += 2) {
                $result = $dot->($self, $root, @$ident[$i, $i+1], 1);
                last ELEMENT unless defined $result;
                $root = $result;
            }
            
            # then we call _assign() to assign the value to the last element
            $result = $self->assign($root, @$ident[$size-1, $size], 
                                    $value, $default);
        }
        else {
            $result = $self->assign($root, $ident, 0, $value, $default);
        }
    }
    
    return 
        defined $result 
              ? $result 
              : '';
}

sub dot {
    my ($self, $root, $item, $args, $lvalue) = @_;
    my $rootref = ref $root;
    my $atroot  = (blessed $root && $root->isa(ref $self));
    my ($value, @result);

    $args ||= [ ];
    $lvalue ||= 0;

    $self->debug(
        "dot(root=$root, item=$item, args=[", 
        join(', ', @$args), 
        "], $lvalue)\n"
    ) if DEBUG;

    # return undef without an error if either side of the dot is unviable
    return undef unless defined($root) and defined($item);

    # or if an attempt is made to access a private member, starting _ or .
    return undef if $PRIVATE && $item =~ $PRIVATE;

    if ($atroot || $rootref eq HASH) {
        # if $root is a regular HASH or a Template::Stash kinda HASH (the 
        # *real* root of everything).  We first lookup the named key 
        # in the hash, or create an empty hash in its place if undefined
        # and the $lvalue flag is set.  Otherwise, we check the HASH_OPS
        # pseudo-methods table, calling the code if found, or return undef.
        
        if (defined($value = $root->{ $item })) {
            return $value unless ref $value eq CODE;        ## RETURN
            @result = &$value(@$args);                      ## @result
        }
        elsif ($lvalue) {
            # we create an intermediate hash if this is an lvalue
            return $root->{ $item } = { };                  ## RETURN
        }
        # ugly hack: only allow import vmeth to be called on root stash
        elsif (($value = $HASH_OPS->{ $item })
               && ! $atroot || $item eq $IMPORT) {
            @result = &$value($root, @$args);               ## @result
        }
        elsif (ref $item eq ARRAY) {
            # hash slice
            return [@$root{@$item}];                        ## RETURN
        }
    }
    elsif ($rootref eq ARRAY) {    
        # if root is an ARRAY then we check for a LIST_OPS pseudo-method 
        # or return the numerical index into the array, or undef
        if (looks_like_number $item) {
            $value = $root->[$item];
            return $value unless ref $value eq CODE;        ## RETURN
            @result = &$value(@$args);                      ## @result
        }
        elsif ($value = $LIST_OPS->{ $item }) {
            @result = &$value($root, @$args);               ## @result
        }
        elsif (ref $item eq ARRAY) {
            # array slice
            return [@$root[@$item]];                        ## RETURN
        }
    }
    elsif (blessed $root) {
        # if $root is an object then we call the item as a method.
        # If that fails then we try to fallback on HASH behaviour if 
        # possible.
        eval { @result = $root->$item(@$args); };       
        
        if ($@) {
            # temporary hack - required to propogate errors thrown
            # by views; if $@ is a ref (e.g. Template::Exception
            # object then we assume it's a real error that needs
            # real throwing

            my $class = ref($root) || $root;
            $self->throw("$@")
                if ref($@) 
                   || ($@ !~ /^Can't locate object method/);

            my $type = reftype $root;
            
            # failed to call object method, so try some fallbacks
            if ($type eq HASH) {
                if(defined($value = $root->{ $item })) {
                    return $value unless ref $value eq CODE;      ## RETURN
                    @result = &$value(@$args);
                }
                elsif ($value = $HASH_OPS->{ $item }) {
                    @result = &$value($root, @$args);
                }
                elsif ($value = $LIST_OPS->{ $item }) {
                    @result = &$value([$root], @$args);
                }
            }
            elsif ($type eq ARRAY) {
                if( $value = $LIST_OPS->{ $item }) {
                   @result = &$value($root, @$args);
                }
                elsif(looks_like_number $item) {
                   $value = $root->[$item];
                   return $value unless ref $value eq CODE;         ## RETURN
                   @result = &$value(@$args);                       ## @result
                }
                elsif (ref $item eq ARRAY) {
                    # array slice
                    return [@$root[@$item]];                        ## RETURN
                }
            }
            elsif ($value = $SCALAR_OPS->{ $item }) {
                @result = &$value($root, @$args);
            }
            elsif ($value = $LIST_OPS->{ $item }) {
                @result = &$value([$root], @$args);
            }
            elsif ($self->{ _DEBUG }) {
                @result = (undef, $@);
            }
        }
    }
    elsif (($value = $SCALAR_OPS->{ $item }) && ! $lvalue) {
        # at this point, it doesn't look like we've got a reference to
        # anything we know about, so we try the SCALAR_OPS pseudo-methods
        # table (but not for l-values)
        @result = &$value($root, @$args);           ## @result
    }
    elsif (($value = $LIST_OPS->{ $item }) && ! $lvalue) {
        # last-ditch: can we promote a scalar to a one-element
        # list and apply a LIST_OPS virtual method?
        @result = &$value([$root], @$args);
    }
    elsif ($self->{ _DEBUG }) {
        $self->error_msg( bad_dot => $root, $item );
    }
    else {
        @result = ();
    }

    # fold multiple return items into a list unless first item is undef
    if (defined $result[0]) {
        return                              ## RETURN
            scalar @result > 1 
                ? [@result] 
                :  $result[0];
    }
    elsif (defined $result[1]) {
        return $self->error($result[1]);
    }
    elsif ($self->{ _DEBUG }) {
        return $self->error( undefined => $root, $item );
    }

    return undef;
}

sub assign {
    my ($self, $root, $item, $args, $value, $default) = @_;
    my $rootref = ref $root;
    my $atroot  = ($root eq $self);
    my $result;
    $args ||= [ ];
    $default ||= 0;

    # return undef without an error if either side of the dot is unviable
    return undef unless $root and defined $item;

    # or if an attempt is made to update a private member, starting _ or .
    return undef if $PRIVATE && $item =~ $PRIVATE;
    
    if ($rootref eq HASH || $atroot) {
        # if the root is a hash we set the named key
        return ($root->{ $item } = $value)          ## RETURN
            unless $default && $root->{ $item };
    }
    elsif ($rootref eq ARRAY && looks_like_number $item) {
        # or set a list item by index number
        return ($root->[$item] = $value)            ## RETURN
            unless $default && $root->{ $item };
    }
    elsif (blessed $root) {
        # try to call the item as a method of an object
        return $root->$item(@$args, $value)         ## RETURN
            unless $default && $root->$item();
    }
    else {
        $self->error_msg( bad_assign => $root, $item );
    }

    return undef;
}

1;

__END__
