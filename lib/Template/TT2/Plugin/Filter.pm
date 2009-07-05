package Template::TT2::Plugin::Filter;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Plugin',
    import    => 'class',
    utils     => 'weaken',
    words     => 'refs',
    constants => 'LAST HASH PKG';

our $DYNAMIC = 0 unless defined $DYNAMIC;


sub new {
    my ($class, $context, @args) = @_;
    my $config  = @args && ref $args[LAST] eq HASH ? pop(@args) : { };
    my $dynamic = $class->class->any_var('DYNAMIC');

    $class->debug("Plugin file is ", $dynamic ? 'DYNAMIC' : 'STATIC') if DEBUG;
    
    my $self = bless {
        _CONTEXT => $context,
        _DYNAMIC => $dynamic,
        _ARGS    => \@args,
        _CONFIG  => $config,
    }, $class;

    return $self->init($config)
        || $class->error($self->error());
}


sub init {
    return $_[0];
}


sub factory {
    my $self = shift;
    my $this = $self;
    
    # This causes problems: https://rt.cpan.org/Ticket/Display.html?id=46691
    # If the plugin is loaded twice in different templates (one INCLUDEd into
    # another) then the filter gets garbage collected when the inner template 
    # ends (at least, I think that's what's happening).  So I'm going to take
    # the "suck it and see" approach, comment it out, and wait for someone to
    # complain that this module is leaking memory.  

    # weaken($this);

    if ($self->{ _DYNAMIC }) {
        return $self->{ _DYNAMIC_FILTER } ||= [ 
            sub {
                my ($context, @args) = @_;
                my $config = @_ && ref $args[LAST] eq HASH ? pop(@args) : { };
                return sub {
                    $this->filter(shift, \@args, $config);
                };
            }, 
            1 
        ];
    }
    else {
        return $self->{ _STATIC_FILTER } ||= sub {
            $this->filter(shift);
        };
    }
}


sub filter {
    my ($self, $text, $args, $config) = @_;
    return $text;
}


sub merge_config {
    my ($self, $newcfg) = @_;
    my $owncfg = $self->{ _CONFIG };
    return $owncfg unless $newcfg;
    return { %$owncfg, %$newcfg };
}


sub merge_args {
    my ($self, $newargs) = @_;
    my $ownargs = $self->{ _ARGS };
    return $ownargs unless $newargs;
    return [ @$ownargs, @$newargs ];
}


sub install_filter {
    my ($self, $name) = @_;
    $self->{ _CONTEXT }->define_filter( $name => $self->factory );
    return $self;
}



1;

__END__

=head1 NAME

Template::TT2::Plugin::Filter - Base class for plugin filters

=head1 SYNOPSIS

    package Your::Plugin::Mungifier;
    use base 'Template::TT2::Plugin::Filter';
    
    sub filter {
        my ($self, $text) = @_;
        
        # ...mungify $text...
        
        return $text;
    }

In a template:

    # load the plugin 
    [% USE Mungifier %]
    
    # ...and use the returned object as a filter
    [% FILTER $Mungifier %]
      ...
    [% END %]

=head1 DESCRIPTION

This module implements a base class for plugin filters.  It hides
the underlying complexity involved in creating and using filters
that get defined and made available by loading a plugin.

To use the module, simply create your own plugin module as a subclass
of the C<Template::TT2::Plugin::Filter> module.

    package Your::Plugin::Mungifier;
    use base 'Template::TT2::Plugin::Filter';

Then define your C<filter()> method. When called, you get passed a reference
to your plugin object (C<$self>) and the text to be filtered.

    sub filter {
        my ($self, $text) = @_;
        
        # ...mungify $text...
        
        return $text;
    }

To use your custom plugin, you have to make sure that the Template
Toolkit knows about your plugin namespace.

    my $tt2 = Template->new({
        PLUGIN_BASE => 'Your::Plugin',
    });

Or for individual plugins you can do it like this:

    my $tt2 = Template->new({
        PLUGINS => {
            MyFilter => 'Your::Plugin::Mungifier',
        },
    });

Then you C<USE> your plugin in the normal way.

    [% USE Mungifier %]

The object returned is stored in the variable of the same name,
'C<Mungifier>'.  When you come to use it as a C<FILTER>, you should add
a dollar prefix.  This indicates that you want to use the filter 
stored in the variable 'C<Mungifier>' rather than the filter named 
'C<Mungifier>', which is an entirely different thing (see later for 
information on defining filters by name).

    [% FILTER $Mungifier %]
       ...text to be filtered...
    [% END %]

You can, of course, assign it to a different variable.

    [% USE blat = Mungifier %]
    
    [% FILTER $blat %]
       ...text to be filtered...
    [% END %]

Any configuration parameters passed to the plugin constructor from the
C<USE> directive are stored internally in the object for inspection by
the C<filter()> method (or indeed any other method).  Positional
arguments are stored as a reference to a list in the C<_ARGS> item while
named configuration parameters are stored as a reference to a hash
array in the C<_CONFIG> item.

For example, loading a plugin as shown here:

    [% USE blat = Mungifier 'foo' 'bar' baz = 'blam' %]

would allow the C<filter()> method to do something like this:

    sub filter {
        my ($self, $text) = @_;
        
        my $args = $self->{ _ARGS   };  # [ 'foo', 'bar' ]
        my $conf = $self->{ _CONFIG };  # { baz => 'blam' }
        
        # ...munge $text...
        
        return $text;
    }

By default, plugins derived from this module will create static
filters.  A static filter is created once when the plugin gets 
loaded via the C<USE> directive and re-used for all subsequent
C<FILTER> operations.  That means that any argument specified with
the C<FILTER> directive are ignored.

Dynamic filters, on the other hand, are re-created each time 
they are used by a C<FILTER> directive.  This allows them to act
on any parameters passed from the C<FILTER> directive and modify
their behaviour accordingly.  

There are two ways to create a dynamic filter.  The first is to
define a C<$DYNAMIC> class variable set to a true value.

    package Your::Plugin::Mungifier;
    use base 'Template::Plugin::Filter';
    our $DYNAMIC = 1;

The other way is to set the internal C<_DYNAMIC> value within the C<init()>
method which gets called by the C<new()> constructor.

    sub init {
        my $self = shift;
        $self->{ _DYNAMIC } = 1;
        return $self;
    }

When this is set to a true value, the plugin will automatically
create a dynamic filter.  The outcome is that the C<filter()> method
will now also get passed a reference to an array of postional
arguments and a reference to a hash array of named parameters.

So, using a plugin filter like this:

    [% FILTER $blat 'foo' 'bar' baz = 'blam' %]

would allow the C<filter()> method to work like this:

    sub filter {
        my ($self, $text, $args, $conf) = @_;
        
        # $args = [ 'foo', 'bar' ]
        # $conf = { baz => 'blam' }
    }

In this case can pass parameters to both the USE and FILTER directives,
so your filter() method should probably take that into account.  

    [% USE Mungifier 'foo' wiz => 'waz' %]
    
    [% FILTER $Mungifier 'bar' biz => 'baz' %]
       ...
    [% END %]

You can use the C<merge_args()> and C<merge_config()> methods to do a quick
and easy job of merging the local (e.g. C<FILTER>) parameters with the
internal (e.g. C<USE>) values and returning new sets of conglomerated
data.

    sub filter {
        my ($self, $text, $args, $conf) = @_;
        
        $args = $self->merge_args($args); 
        $conf = $self->merge_config($conf);
        
        # $args = [ 'foo', 'bar' ]      
        # $conf = { wiz => 'waz', biz => 'baz' }        
        ...
    }

You can also have your plugin install itself as a named filter by
calling the C<install_filter()> method from the C<init()> method.  You 
should provide a name for the filter, something that you might 
like to make a configuration option.

    sub init {
        my $self = shift;
        my $name = $self->{ _CONFIG }->{ name } || 'mungifier';
        $self->install_filter($name);
        return $self;
    }

This allows the plugin filter to be used as follows:

    [% USE MyFilter %]
    
    [% FILTER mungifier %] 
       ... 
    [% END %]

or

    [% USE Mungifier name='munge' %]
        
    [% FILTER munge %] 
       ... 
    [% END %]

Alternately, you can allow a filter name to be specified as the 
first positional argument.

    sub init {
        my $self = shift;
        my $name = $self->{ _ARGS }->[0] || 'myfilter';
        $self->install_filter($name);
        return $self;
    }

    [% USE Mungifier 'munge' %]
    
    [% FILTER munge %]
       ...
    [% END %]

=head1 EXAMPLE

Here's a complete example of a plugin filter module.

    package My::Template::Plugin::Change;
    use base 'Template::TT2::Plugin::Filter';
    
    sub init {
        my $self = shift;
        
        $self->{ _DYNAMIC } = 1;
        
        # first arg can specify filter name
        $self->install_filter($self->{ _ARGS }->[0] || 'change');
        
        return $self;
    }
    
    sub filter {
        my ($self, $text, $args, $config) = @_;
        
        $config = $self->merge_config($config);
        my $regex = join('|', keys %$config);
        
        $text =~ s/($regex)/$config->{ $1 }/ge;
        
        return $text;
    }
    
    1;

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::TT2::Plugin>, L<Template::TT2::Filters>, L<Template::Manual::Filters>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
