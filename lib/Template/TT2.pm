#============================================================= -*-perl-*-
#
# Template::TT2
#
# DESCRIPTION
#   Front-end to the TT2 modules.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
# COPYRIGHT
#   Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#========================================================================

package Template::TT2;

use Template::TT2::Modules;
use Template::TT2::Class
    version     => 0.01,         # constructs VERSION and $VERSION
    debug       => 0,
    base        => 'Template::TT2::Base Badger::Prototype',
    filesystem  => 'FS VFS',
    mutators    => 'hub',
    import      => 'class',
    utils       => 'looks_like_number blessed is_object',
    constants   => 'TT2_HUB TT2_MODULES :types',
    constant    => {
        PRINT_METHOD => 'print',
        Template     => 'Template::TT2',
    },
    config      => [
        'HUB|hub|class:HUB|method:TT2_HUB',
        'MKDIR|mkdir|class:MKDIR=1',
        'ENCODING|encoding|class:ENCODING=0',
        'OUTPUT|output|class:OUTPUT',
        'OUTPUT_PATH|output_path|class:OUTPUT_PATH',
        'QUIET|quiet=0',
        'modules|MODULES|class:MODULES',
    ],
    messages    => {
        hub_config  => 'Configuration options are ignored when connecting to an existing hub',
    },
    exports     => {
        any         => 'Template TT2_MODULES',
    };

our $VERSION = 0.01;            # for ExtUtils::MakeMaker - not DRY, yuk
our $OUTPUT  = \*STDOUT unless defined $OUTPUT;

# preload all modules if we're running under mod_perl
TT2_MODULES->preload if $ENV{ MOD_PERL };


sub init {
    my ($self, $config) = @_;
    my $class = $self->class;
    my $debug = $config->{ DEBUG };

    # call the imported (from Badger::Class::Config) configure() method
    # to configure $self from $config according to the config spec above
    $self->configure($config, $config);

    # hub usually defaults to Template::TT2::Hub as defined by TT2_HUB 
    # constant, but this can be overridden with a config option or pkg var
    my $hub = $config->{ HUB }
        || return $self->error_msg( missing => 'hub' );

    if (ref $hub) {
        if (is_object(TT2_HUB, $hub)) {
            # we can attach to an existing hub object, but that means we 
            # have to ignore any other config arguments
            $self->warn_msg('hub_config')
                unless $self->{ QUIET } || keys %$config == 1;
    
            $self->{ hub } = $hub;
        }
        else {
            $self->error_msg( invalid => hub => $hub );
        }
    }
    else {
        # otherwise we've got a class name which we load and instantiate
        $self->{ hub } = class($hub)->load->instance($config);
    }

    $self->debug("connected to hub: $self->{ hub }") if DEBUG;

    # TODO: debug flags
    # convert textual DEBUG flags to number
#    $config->{ DEBUG } = debug_flags($self, $debug)
#        if defined $debug && ! looks_like_number $debug;

    # Trigger initialisation of service and context so that we can sample
    # any package variable defaults now before they go changing.  This is 
    # unlikely to affect anyone in the Real World, but we rely on this 
    # behaviour in the t/plugin/plugins.t test
    $self->context;

    return $self;
}


# TODO: this looks right to me (needs proto).  I wonder why I commented
# it out and replaced it with a mutator?  To allow objects to attach to an
# existing hub?

#sub hub {
#    return ref $_[0] eq HASH
#        ? $_[0]->{ hub }
#        : $_[0]->prototype->{ hub };
#}


sub process {
    my ($self, $input, $vars, @output) = @_;
    $vars ||= { };
    $self->output( $self->service->process($input, $vars), @output );
}


sub service {
    return $_[0]->{ service }
       ||= $_[0]->hub->service;
}


sub context {
    return $_[0]->{ context }
       ||= $_[0]->service->context;
}


sub output {
    shift->hub->output(@_);
}


sub module {
    shift->hub->module(@_);
}

sub preload {
    TT2_MODULES->preload;
}


# ttree wants this

sub module_version {
    return $VERSION;
}

sub DESTROY {
    my $self = shift;
    $self->{ hub }->destroy if $self->{ hub };
    delete $self->{ hub };
    return ();
}

1;


__END__

=head1 NAME

Template::TT2 - Template Toolkit v2

=head1 SYNOPSIS 

Using the C<Template::TT2> module:

    use Template::TT2;
    
    my $tt = Template::TT2->new( %options );
    
Using the C<Template> alias:

    use Template::TT2 'Template';
    
    my $tt = Template->new( %options );

Processing templates:

    $tt->process( $template, \%vars, $output )
        || die $tt->error;
    
=head1 DESCRIPTION

The C<Template::TT2> distribution is a new implementation of version 2 of the
Template Toolkit (specifically, v2.21). It is a drop-in replacement for the
"old" C<Template> module and implements a 100% faithful version of the TT2
template language, warts and all.

Please see L<Template::TT2::Changes> for further information on what 
L<Template::TT2> does, why it exists, how it is similar/different to 
L<Template>, and what L<Badger>s have to do with all this.

This documentation describes the L<Template::TT2> module which provides 
an interface to the Template Toolkit for Perl programmers.  For more general
information on using the Template Toolkit please see the existing 
L<Template::Manual> documentation and mentally substitute L<Template> for 
L<Template::TT2> wherever you see a module name.

You can read the documentation online at the Template Toolkit web site:
L<http://template-toolkit.org/docs/index.html>.

=head1 METHODS

The following methods are defined in addition to those inherited from
L<Template::TT2::Base> and L<Badger::Base>.

=head2 new(\%config)

This constructor method is used to create a new C<Template::TT2> object.
The method is inherited from L<Badger::Base>.  See L<Template::Manual::Config>
for information on the configuration options it supports.

    my $tt = Template::TT2->new(
        INCLUDE_PATH => '/path/to/my/templates'
    );

=head2 process($input,\%vars,$output)

This method is used to process a template.

    $tt->process('message.html')
        || die $tt->error;

The first argument can be the name of a template file (located under the
L<INCLUDE_PATH|Template::Manual::Config/INCLUDE_PATH> as shown in the example
above.  It can also be specified as a reference to a text string containing 
the template text:

    my $template = 'Hello [% name or "World" %]';
    
    $tt->process(\$template)
        || die $tt->error;

Or as a reference to a file handle (e.g. L<IO::Handle>) or Perl C<GLOB>
(e.g. C<\*STDIN>) from which the template can read.  The following example
shows how the C<\*DATA> file handle can be used to read the template from 
the section of the file following the C<__DATA__> marker:

    $tt->process(\*DATA)
        || die $tt->error;
        
    __DATA__
    [% INCLUDE header %]
    This is a template defined in the __DATA__ section which is 
    accessible via the DATA "file handle".
    [% INCLUDE footer %]

A reference to a hash array may be passed as the second parameter, containing 
definitions of template variables.

    my $vars = {
        name => 'Badger',
    };
    
    $tt->process('message.html', $vars)
        || die $tt->error;

If the template is processed successfully then the generated output is printed
to C<STDOUT> and the method returns a true value (C<1>).  If an error is 
encountered then no output is generated and the method returns a false value
(C<undef>).

A third parameter may be passed to the method to specify a different output
location.   This can be the name of an output file relative to the 
L<OUTPUT_PATH|Template::Manual::Config/OUTPUT_PATH> directory (which must be 
specified as a configuration option).  You can use the same template
name for both input and output as long as your 
L<OUTPUT_PATH|Template::Manual::Config/OUTPUT_PATH> is not the same as your
L<INCLUDE_PATH|Template::Manual::Config/INCLUDE_PATH>).

    my $filename = 'message.html';
    
    $tt->process($filename, $vars, $filename)
        || die $tt->error;

The third parameter can also be a file handle or C<GLOB> opened ready for
output:

    use IO::File
    my $fh = IO::File->new('> output.html');
    
    $tt->process($filename, $vars, $fh)
        || die $tt->error;

Or a reference to a scalar variable to which the output will be appended to it
(note that any existing text in the variable is left intact).

    my $output;
    
    $tt->process($filename, $vars, \$output)
        || die $tt->error;
        
    print "Output: ", $output;

Or a reference to a subroutine which will be called, passing the output as a 
parameter.

    sub output {
        print "Output: ", shift;
    }
    
    $tt->process($filename, $vars, \&output)
        || die $tt->error;
        
Or a reference to an object which implements a C<print()> method (e.g. 
L<IO::Handle>, L<Badger::Filesystem::File>, L<Apache::Request>, etc.).
The C<print()> method will be called passing the generated output as a 
parameter.

    use Badger::Filesystem 'File';
    my $output = File('output.html');

    $tt->process($input, $vars, $output)
        || die $tt->error;

The third output argument can be followed by a list or reference to a hash
array of named parameters providing further options for the output. The only
option currently supported is C<binmode> which, when set to any true value
will ensure that files created (but not any existing file handles passed) will
be set to binary mode.

    # either: hash reference of options
    $tt->process($infile, $vars, $outfile, { binmode => 1 })
        || die $tt->error;

    # or: list of name, value pairs
    $tt->process($infile, $vars, $outfile, binmode => 1)
        || die $tt->error;

Alternately, the C<binmode> argument can specify a particular IO layer such as
C<:utf8>.

    $tt->process($infile, $vars, $outfile, binmode => ':utf8')
        || die $tt->error;

The C<encoding> option is provided as an alias for C<binmode>.

    $tt->process($infile, $vars, $outfile, encoding => ':utf8')
        || die $tt->error;

The L<OUTPUT|Template::Manual::Config/OUTPUT> configuration option can be used
to specify a default output location other than C<\*STDOUT>. The The
L<OUTPUT_PATH|Template::Manual::Config/OUTPUT_PATH> configuration option can
be used to specify the directory for output files.

    my $tt = Template::TT2->new(
        OUTPUT      => sub { ... },       # default output
        OUTPUT_PATH => '/tmp',
        ...
    );

    # use default OUTPUT (sub is called)
    $tt->process($infile, $vars)
        || die $tt->error;

    # write file to '/tmp/welcome.html'
    $tt->process($infile, $vars, 'welcome.html')
        || die $tt->error;

=head2 error()

This method is inherited from L<Badger::Base>.  It can be used to inspect
any error raised by a call to the L<process()> method.  It returns a 
L<Template::TT2::Exception> object.

    $tt->process($infile)
        || die $tt->error;

=head1 INTERNAL METHODS

These methods, while not strictly private, are generally intended for 
internal use.

=head2 hub()

Returns a reference to a L<Template::TT2::Hub> object or class name through
which the C<Template::TT2> object can access other template sub-systems
(e.g. templates, plugins, etc).

    my $hub = $tt->hub;

=head2 service()

Returns a reference to a L<Template::TT2::Service> object which is responsible
for adding headers (L<PRE_PROCESS|Template::Manual::Config/PRE_PROCESS>),
footers (L<POST_PROCESS|Template::Manual::Config/POST_PROCESS>), wrappers
(L<WRAPPER|Template::Manual::Config/WRAPPER>) and/or layout templates
(L<PROCESS|Template::Manual::Config/PROCESS>) to a page template.  It also
performs error handling (L<ERROR|Template::Manual::Config/ERROR>) and various
other niceties.  The L<process()> method delegates to this object.

    my $service = $tt->service;

=head2 context()

Returns a reference to a L<Template::TT2::Context> object which is responsible
for lower-level template processing, and for storing the state of the current
environment (variables, templates, plugins, etc).

    my $context = $tt->context;

=head2 output()

A method of convenience which delegates to the
L<output()|Template::TT2::Hub/output()> method of the
L<hub|Template::TT2::Hub> object. This is used to redirect template output to
the appropriate location.

=head2 module()

A method of convenience which delegates to the
L<output()|Template::TT2::Hub/output()> method of the
L<hub|Template::TT2::Hub> object. This is used to redirect template output to
the appropriate location.

=head2 preload()

Delegates to the L<preload()|Template::TT2::Modules/preload()> method in 
L<Template::TT2::Modules> which loads all the core TT2 modules.  This is 
called automatically when the module is used under the C<mod_perl>
environment.  You can call it yourself if you want to take the hit of 
loading and compiling all the Perl modules up-front.  Otherwise they will
be loaded on demand if and when required.

=head2 module_version()

Also returns the version number of the C<Template::TT2> module. This is
provided for backwards compatibility with the L<ttree> program which uses it.
It will be removed in TT3 in favour of the L<VERSION()> method.

=head2 VERSION()

Returns the version number of the C<Template::TT2> module.

=head2 DESTROY()

This method is called automatically by Perl when the C<Template::TT2> object
goes out of scope and is garbage collected. It calls the L<Template::TT2::Hub>
L<destroy()|Template::TT2::Hub/destroy()> method to give the hub a chance to
clean itself up.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
# Textmate: is shiny
