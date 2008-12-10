package Template::TT2::View;

use Template::TT2::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Template::TT2::Base',
    constants   => 'HASH',
    throws      => 'view',
    utils       => 'params';

our @BASEARGS = qw( context );
our $AUTOLOAD;
our $MAP = {
    HASH    => 'hash',
    ARRAY   => 'list',
    TEXT    => 'text',
    default => '',
};


sub new {
    my $class   = shift;
    my $context = shift;
    my $config  = params(@_);
    my $self    = bless {
        # TODO: weaken?
        _CONTEXT => $context,
    }, $class;
    $self->init($config);
}


sub init {
    my ($self, $config) = @_;

    # generate table mapping object types to templates
    my $map = $config->{ map } || { };
    $map->{ default } = $config->{ default } unless defined $map->{ default };
    $self->{ map } = {
        %$MAP,
        %$map,
    };

    # local BLOCKs definition table
    $self->{ _BLOCKS } = $config->{ blocks } || { };
    
    # name of presentation method which printed objects might provide
    $self->{ method } = defined $config->{ method } 
                              ? $config->{ method } : 'present';
    
    # view is sealed by default preventing variable update after 
    # definition, however we don't actually seal a view until the 
    # END of the view definition
    my $sealed = $config->{ sealed };
    $sealed = 1 unless defined $sealed;
    $self->{ sealed } = $sealed ? 1 : 0;

    # copy remaining config items from $config or set defaults
    foreach my $arg (qw( base prefix suffix notfound silent )) {
        $self->{ $arg } = $config->{ $arg } || '';
    }

    # name of data item used by view()
    $self->{ item } = $config->{ item } || 'item';

    # map methods of form ${include_prefix}_foobar() to include('foobar')?
    $self->{ include_prefix } = $config->{ include_prefix } || 'include_';
    # what about mapping foobar() to include('foobar')?
    $self->{ include_naked  } = defined $config->{ include_naked } 
                                      ? $config->{ include_naked } : 1;

    # map methods of form ${view_prefix}_foobar() to include('foobar')?
    $self->{ view_prefix } = $config->{ view_prefix } || 'view_';
    # what about mapping foobar() to view('foobar')?
    $self->{ view_naked  } = $config->{ view_naked  } || 0;

    # the view is initially unsealed, allowing directives in the initial 
    # view template to create data items via the AUTOLOAD; once sealed via
    # call to seal(), the AUTOLOAD will not update any internal items.
    delete @$config{ qw( base method map default prefix suffix notfound item 
                         include_prefix include_naked silent sealed
                         view_prefix view_naked blocks ) };
    $config = { %{ $self->{ base }->{ data } }, %$config }
        if $self->{ base };
    $self->{ data   } = $config;
    $self->{ SEALED } = 0;

    return $self;
}


sub seal {
    my $self = shift;
    $self->{ SEALED } = $self->{ sealed };
}


sub unseal {
    my $self = shift;
    $self->{ SEALED } = 0;
}


sub clone {
    my $self   = shift;
    my $clone  = bless { %$self }, ref $self;
    my $config = ref $_[0] eq HASH ? shift : { @_ };

    # merge maps
    $clone->{ map } = {
        %{ $self->{ map } },
        %{ $config->{ map } || { } },
    };

    # "map => { default=>'xxx' }" can be specified as "default => 'xxx'"
    $clone->{ map }->{ default } = $config->{ default }
        if defined $config->{ default };

    # update any remaining config items
    my @args = qw( base prefix suffix notfound item method include_prefix 
                   include_naked view_prefix view_naked );
    foreach my $arg (@args) {
        $clone->{ $arg } = $config->{ $arg } if defined $config->{ $arg };
    }
    push(@args, qw( default map ));
    delete @$config{ @args };

    # anything left is data
    my $data = $clone->{ data } = { %{ $self->{ data } } };
    @$data{ keys %$config } = values %$config;

    return $clone;
}


sub print {
    my $self = shift;

    # if final config hash is specified then create a clone and delegate to it
    # NOTE: potential problem when called print(\%data_hash1, \%data_hash2);
    if ((scalar @_ > 1) && (ref $_[-1] eq HASH)) {
        my $cfg = pop @_;
        my $clone = $self->clone($cfg)
            || return;
        return $clone->print(@_) 
            || $self->error($clone->error());
    }
    my ($item, $type, $template, $present);
    my $method = $self->{ method };
    my $map = $self->{ map };
    my $output = '';
    
    # print each argument
    foreach $item (@_) {
        my $newtype;
        
        if (! ($type = ref $item)) {
            # non-references are TEXT
            $type = 'TEXT';
            $template = $map->{ $type };
        }
        elsif (! defined ($template = $map->{ $type })) {
            # no specific map entry for object, maybe it implements a 
            # 'present' (or other) method?
            if ( $method && UNIVERSAL::can($item, $method) ) {
                $present = $item->$method($self);       ## call item method
                # undef returned indicates error, note that we expect 
                # $item to have called error() on the view
                return unless defined $present;
                $output .= $present;
                next;                                   ## NEXT
            }   
            elsif ( ref $item eq HASH
                    && defined($newtype = $item->{$method})
                    && defined($template = $map->{"$method=>$newtype"})) {
            }
            elsif ( defined($newtype)
                    && defined($template = $map->{"$method=>*"}) ) {
                $template =~ s/\*/$newtype/;
            }    
            elsif (! ($template = $map->{ default }) ) {
                # default not defined, so construct template name from type
                ($template = $type) =~ s/\W+/_/g;
            }
        }
        $self->debug("printing view '", $template || '', "', $item\n") if DEBUG;
        $output .= $self->view($template, $item)
            if $template;
    }
    return $output;
}


sub view {
    my ($self, $template, $item) = splice(@_, 0, 3);
    my $vars = ref $_[0] eq HASH ? shift : { @_ };
    $vars->{ $self->{ item } } = $item if defined $item;
    $self->include($template, $vars);
}


sub include {
    my ($self, $template, $vars) = @_;
    my $context = $self->{ _CONTEXT };

    $template = $self->template($template);

    $vars = { } unless ref $vars eq HASH;
    $vars->{ view } ||= $self;

    $context->include( $template, $vars );
}


sub template {
    my ($self, $name) = @_;
    my $context = $self->{ _CONTEXT };

    return $self->error("no view template specified")
        unless $name;

    my $notfound = $self->{ notfound };
    my $base = $self->{ base };
    my ($template, $block, $error);

    return $block
        if ($block = $self->{ _BLOCKS }->{ $name });
    
    # try the named template
    $template = $self->template_name($name);
    $self->debug("looking for $template\n") if DEBUG;
    eval { $template = $context->template($template) };

    # try asking the base view if not found
    if (($error = $@) && $base) {
        $self->debug("asking base for $name\n") if DEBUG;
        eval { $template = $base->template($name) };
    }

    # try the 'notfound' template (if defined) if that failed
    if (($error = $@) && $notfound) {
        unless ($template = $self->{ _BLOCKS }->{ $notfound }) {
            $notfound = $self->template_name($notfound);
            $self->debug("not found, looking for $notfound\n") if DEBUG;
            eval { $template = $context->template($notfound) };

            return $context->error($error)
                if $@;  # return first error
        }
    }
    elsif ($error) {
        $self->debug("no 'notfound'\n") if DEBUG;
        return $self->error($error);
    }
    return $template;
}

    
sub template_name {
    my ($self, $template) = @_;
    $template = $self->{ prefix } . $template . $self->{ suffix }
        if $template;

    $self->debug("template name: $template\n") if DEBUG;
    return $template;
}


sub default {
    my $self = shift;
    return @_ ? ($self->{ map }->{ default } = shift) 
              :  $self->{ map }->{ default };
}


sub AUTOLOAD {
    my $self = shift;
    my $item = $AUTOLOAD;
    $item =~ s/.*:://;
    return if $item eq 'DESTROY';

    if ($item =~ /^[\._]/) {
        return $self->error("attempt to view private member: $item");
    }
    elsif (exists $self->{ $item }) {
        # update existing config item (e.g. 'prefix') if unsealed
        return $self->error("cannot update config item in sealed view: $item")
            if @_ && $self->{ SEALED };
        $self->debug("accessing item: $item\n") if DEBUG;
        return @_ ? ($self->{ $item } = shift) : $self->{ $item };
    }
    elsif (exists $self->{ data }->{ $item }) {
        # get/update existing data item (must be unsealed to update)
        if (@_ && $self->{ SEALED }) {
            return $self->error("cannot update item in sealed view: $item")
                unless $self->{ silent };
            # ignore args if silent
            @_ = ();
        }
        $self->debug(@_ ? "updating data item: $item <= $_[0]\n" 
                        : "returning data item: $item\n") if DEBUG;
        return @_ ? ($self->{ data }->{ $item } = shift) 
                  :  $self->{ data }->{ $item };
    }
    elsif (@_ && ! $self->{ SEALED }) {
        # set data item if unsealed
        $self->debug("setting unsealed data: $item => @_\n") if DEBUG;
        $self->{ data }->{ $item } = shift;
    }
    elsif ($item =~ s/^$self->{ view_prefix }//) {
        $self->debug("returning view($item)\n") if DEBUG;
        return $self->view($item, @_);
    }
    elsif ($item =~ s/^$self->{ include_prefix }//) {
        $self->debug("returning include($item)\n") if DEBUG;
        return $self->include($item, @_);
    }
    elsif ($self->{ include_naked }) {
        $self->debug("returning naked include($item)\n") if DEBUG;
        return $self->include($item, @_);
    }
    elsif ($self->{ view_naked }) {
        $self->debug("returning naked view($item)\n") if DEBUG;
        return $self->view($item, @_);
    }
    else {
        return $self->error("no such view member: $item");
    }
}


1;


__END__

=head1 NAME

Template::TT2::View - customised view of a template processing context

=head1 SYNOPSIS

    # define a view
    [% VIEW view
            # some standard args
            prefix        => 'my_', 
            suffix        => '.tt2',
            notfound      => 'no_such_file'
            ...

            # any other data
            title         => 'My View title'
            other_item    => 'Joe Random Data'
            ...
    %]
       # add new data definitions, via 'my' self reference
       [% my.author = "$abw.name <$abw.email>" %]
       [% my.copy   = "&copy; Copyright 2000 $my.author" %]

       # define a local block
       [% BLOCK header %]
       This is the header block, title: [% title or my.title %]
       [% END %]

    [% END %]

    # access data items for view
    [% view.title %]
    [% view.other_item %]

    # access blocks directly ('include_naked' option, set by default)
    [% view.header %]
    [% view.header(title => 'New Title') %]

    # non-local templates have prefix/suffix attached
    [% view.footer %]           # => [% INCLUDE my_footer.tt2 %]

    # more verbose form of block access
    [% view.include( 'header', title => 'The Header Title' ) %]
    [% view.include_header( title => 'The Header Title' ) %]

    # very short form of above ('include_naked' option, set by default)
    [% view.header( title => 'The Header Title' ) %]

    # non-local templates have prefix/suffix attached
    [% view.footer %]           # => [% INCLUDE my_footer.tt2 %]

    # fallback on the 'notfound' template ('my_no_such_file.tt2')
    # if template not found 
    [% view.include('missing') %]
    [% view.include_missing %]
    [% view.missing %]

    # print() includes a template relevant to argument type
    [% view.print("some text") %]     # type=TEXT, template='text'

    [% BLOCK my_text.tt2 %]           # 'text' with prefix/suffix
       Text: [% item %]
    [% END %]

    # now print() a hash ref, mapped to 'hash' template
    [% view.print(some_hash_ref) %]   # type=HASH, template='hash'

    [% BLOCK my_hash.tt2 %]           # 'hash' with prefix/suffix
       hash keys: [% item.keys.sort.join(', ')
    [% END %]

    # now print() a list ref, mapped to 'list' template
    [% view.print(my_list_ref) %]     # type=ARRAY, template='list'

    [% BLOCK my_list.tt2 %]           # 'list' with prefix/suffix
       list: [% item.join(', ') %]
    [% END %]

    # print() maps 'My::Object' to 'My_Object'
    [% view.print(myobj) %]

    [% BLOCK my_My_Object.tt2 %]
       [% item.this %], [% item.that %]
    [% END %]

    # update mapping table
    [% view.map.ARRAY = 'my_list_template' %]
    [% view.map.TEXT  = 'my_text_block'    %]


    # change prefix, suffix, item name, etc.
    [% view.prefix = 'your_' %]
    [% view.default = 'anyobj' %]
    ...

=head1 DESCRIPTION

This is an experimental module.  It is provided for backward compatability
with TT2, but will be removed, replaced or refactored for TT3.

A view is an object that is typically used to present data structures.  For
example, a view can be used to present an XML DOM, by presenting each 
element using an appropriately named template (e.g. rendering C<wibble>
elements via the C<my_xml/wibble> template).

The view can be configured to automatically add a prefix (e.g. C<my_xml/>)
or suffix to the generated template name.  It also allows you to define
custom mappings between data types and template names.

=head1 METHODS

=head2 new($context, \%config)

Creates a new C<Template::TT2::View> presenting a custom view of the specified 
C<$context> object.

A reference to a hash array of configuration options may be passed as the 
second argument.

=over 4

=item prefix

Prefix added to all template names.

    [% USE view(prefix => 'my_') %]
    [% view.view('foo', a => 20) %]     # => my_foo

=item suffix

Suffix added to all template names.

    [% USE view(suffix => '.tt2') %]
    [% view.view('foo', a => 20) %]     # => foo.tt2

=item map 

Hash array mapping reference types to template names.  The print() 
method uses this to determine which template to use to present any
particular item.  The TEXT, HASH and ARRAY items default to 'test', 
'hash' and 'list' appropriately.

    [% USE view(map => { ARRAY   => 'my_list', 
                         HASH    => 'your_hash',
                         My::Foo => 'my_foo', } ) %]

    [% view.print(some_text) %]         # => text
    [% view.print(a_list) %]            # => my_list
    [% view.print(a_hash) %]            # => your_hash
    [% view.print(a_foo) %]             # => my_foo

    [% BLOCK text %]
       Text: [% item %]
    [% END %]

    [% BLOCK my_list %]
       list: [% item.join(', ') %]
    [% END %]

    [% BLOCK your_hash %]
       hash keys: [% item.keys.sort.join(', ')
    [% END %]

    [% BLOCK my_foo %] 
       Foo: [% item.this %], [% item.that %]
    [% END %]

=item method

Name of a method which objects passed to print() may provide for presenting
themselves to the view.  If a specific map entry can't be found for an 
object reference and it supports the method (default: 'present') then 
the method will be called, passing the view as an argument.  The object 
can then make callbacks against the view to present itself.

    package Foo;

    sub present {
        my ($self, $view) = @_;
        return "a regular view of a Foo\n";
    }

    sub debug {
        my ($self, $view) = @_;
        return "a debug view of a Foo\n";
    }

In a template:

    [% USE view %]
    [% view.print(my_foo_object) %]     # a regular view of a Foo

    [% USE view(method => 'debug') %]
    [% view.print(my_foo_object) %]     # a debug view of a Foo

=item default

Default template to use if no specific map entry is found for an item.

    [% USE view(default => 'my_object') %]

    [% view.print(objref) %]            # => my_object

If no map entry or default is provided then the view will attempt to 
construct a template name from the object class, substituting any 
sequence of non-word characters to single underscores, e.g.

    # 'fubar' is an object of class Foo::Bar
    [% view.print(fubar) %]             # => Foo_Bar

Any current prefix and suffix will be added to both the default template 
name and any name constructed from the object class.

=item notfound

Fallback template to use if any other isn't found.

=item item

Name of the template variable to which the print() method assigns the current
item.  Defaults to 'item'.

    [% USE view %]
    [% BLOCK list %] 
       [% item.join(', ') %] 
    [% END %]
    [% view.print(a_list) %]

    [% USE view(item => 'thing') %]
    [% BLOCK list %] 
       [% thing.join(', ') %] 
    [% END %]
    [% view.print(a_list) %]

=item view_prefix

Prefix of methods which should be mapped to view() by AUTOLOAD.  Defaults
to 'view_'.

    [% USE view %]
    [% view.view_header() %]                    # => view('header')

    [% USE view(view_prefix => 'show_me_the_' %]
    [% view.show_me_the_header() %]             # => view('header')

=item view_naked

Flag to indcate if any attempt should be made to map method names to 
template names where they don't match the view_prefix.  Defaults to 0.

    [% USE view(view_naked => 1) %]

    [% view.header() %]                 # => view('header')

=back

=head2 clone(\%params)

Creates a copy of the view, updated with any additional configuration
parameters passed as arguments.

=head2 seal()

Seals the view preventing it from any further changes.

=head2 unseal()

Unseals the view, allowing further changes.

=head2 print(@items,\%config)

Prints each of C<@items> in turn by mapping each to an appropriate template
using the internal C<map> hash. If an entry isn't found and the item is an
object that implements a C<present()> method (or whatever method is named in 
the internal C<method> item, then the method will be called.  A reference to 
the view is passed as the first argument which the method may used to make 
callbacks to the view.

If the C<present()> method isn't implemented, then the C<default> map entry is
used if defined. The final argument may be a reference to a hash array
providing local overrides to the internal defaults for various items
(C<prefix>, C<suffix>, etc).

=head2 view($template,$item,\%vars)

Wrapper around L<include()> which expects a template name, C<$template>,
followed by a data item, C<$item>, and optionally, a reference to a hash array
of template variables C<$vars>.

The C<$item> is added to the C<$vars> hash (which is created if necessary)
as the C<item> key (or whatever key is defined by the L<item> configuration
option).  The template is then processed via L<include()>.

=head2 include($template, \%vars)

This is a wrapper around the L<Template::TT2::Context>
L<include()|Template::TT2::Context/include()> method for processing a view
template.

A reference to the view object is first added to the C<$vars> hash reference
as the C<view> item.  

=head template($name)

Returns a compiled template for the specified template name.

=head2 template_name($name)

Returns the name of the specified template with any appropriate prefix
and/or suffix added.

=head2 default($val)

Returns the name of the default template, if defined.

=head2 AUTOLOAD

The C<AUTOLOAD> method provides access to all the configuration items and 
data values stored in the view.

It also delegates any methods of the form C<view_xxx(...)> and 
C<include_yyy(...)> to calls to C<view( xxx =E<gt> ... )> and 
C<include( yyy =E<gt> ... )> respectively.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2000-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::TT2::Plugin::View>

=cut
