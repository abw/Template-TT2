package Template::TT2::Filters;

use Template::TT2::VMethods 
    '$TEXT_VMETHODS';
    
use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Base',
    constants => 'HASH CODE TT2_FILTER',
    codecs    => 'uri url',
    accessors => 'hub',
    utils     => 'is_object',
    messages  => {
        bad_filter => "Invalid filter definition for '%s' (%s)",
    };

use Badger::Factory::Class
    item      => 'filter',
    path      => 'Template::TT2::Filter Template::Filter',
    filters   => {
        html            => \&html,
        html_para       => \&html_para,
        html_break      => \&html_para_break,
        html_para_break => \&html_para_break,
        html_line_break => \&html_line_break,
        uri             => \&encode_uri,
        url             => \&encode_url,
        stderr          => \&stderr,
        null            => \&null,

        html_entity     => [ \&html_entity_filter_factory, 1 ],
        format          => [ \&format_filter_factory,      1 ],
        indent          => [ \&indent_filter_factory,      1 ],
        remove          => [ \&remove_filter_factory,      1 ],
        repeat          => [ \&repeat_filter_factory,      1 ],
        replace         => [ \&replace_filter_factory,     1 ],
        truncate        => [ \&truncate_filter_factory,    1 ],
        stdout          => [ \&stdout_filter_factory,      1 ],
        redirect        => [ \&redirect_filter_factory,    1 ],

        eval            => [ \&eval_filter_factory,        1 ],
        evaltt          => [ \&eval_filter_factory,        1 ],  # alias
        perl            => [ \&perl_filter_factory,        1 ],
        evalperl        => [ \&perl_filter_factory,        1 ],  # alias

        # merge in various text virtual method that make sense when 
        # called as filters - note that any vmethods that take arguments
        # should be implemented as dynamic filters
        map { $_ => $TEXT_VMETHODS->{ $_ } }
        qw( upper lower ucfirst lcfirst trim collapse )
    };


# For some filters (like html_entity), we can select one or other delegate
# module depending on what's available and/or what the user requests. 
our $DELEGATE = { };


sub init {
    my ($self, $config) = @_;
    $config->{ filters } ||= $config->{ FILTERS };
    return $self->init_factory($config);
}


sub type_args {
    shift;
    return (@_);
}


sub found_ref_ARRAY {
    my ($self, $name, $list, @args) = @_;
    my $filter;
    
    # if the filters table contains an array ref, then it can be a dynamic
    # filter (in classic TT2 style): [&code, 1], or a module and class name
    # pair (in modern Badger::Factory style): ['My::Module', 'My::Module::Class']

    if (ref $list->[0] eq CODE) {
        # classic TT2 style: [\&coderef, $is_dynamic]
        if ($list->[1]) {
            # if the dynamic flag is set then the sub-routine is a factory 
            # which should be called to create the filter function
            $filter = $list->[0]->(@args);
            
            return $self->error_msg( bad_filter => $name, $filter )
                unless $filter && ref($filter) eq CODE;
        }
        else {
            # ...otherwise, it's a static filter sub-routine
            $filter = $list->[0];
        }
    }
    elsif (! ref $list->[0]) {
        # new-skool Badger::Factory style: ['Module::Name', 'Class::Name']
        return $self->SUPER::found_ref_ARRAY($list, @args);
    }
    else {
        return $self->error_msg( bad_filter => $name, $list->[0] );
    }

    return $filter;
}


sub found_ref_CODE {
    # if the filters table contains a code ref, then it's a static filter
    # $self, $name, $code = @_;
    return $_[2];
}


sub found_ref_object {
    my ($self, $name, $item) = @_;
    return is_object(TT2_FILTER, $item)
        ? $item
        : $self->error_msg( bad_filter => $name, $item );
}




sub construct {
    my ($self, $filter, @args) = @_;
    $self->debug("construct()");
    if (ref $filter eq CODE) {
        $self->debug("Found code: $filter");
    }
    else {
        return $self->todo('non-code refs');
    }
}


#-----------------------------------------------------------------------
# static filters
#-----------------------------------------------------------------------

sub html {
    my $text = shift;
    for ($text) {
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
        s/"/&quot;/g;
    }
    return $text;
}


sub html_para  {
    my $text = shift;
    return "<p>\n" 
         .  join("\n</p>\n\n<p>\n", split(/(?:\r?\n){2,}/, $text))
         . "</p>\n";
}


sub html_para_break  {
    my $text = shift;
    $text =~ s|(\r?\n){2,}|$1<br />$1<br />$1|g;
    return $text;
}


sub html_line_break  {
    my $text = shift;
    $text =~ s|(\r?\n)|<br />$1|g;
    return $text;
}



#-----------------------------------------------------------------------
# dynamic filters
#-----------------------------------------------------------------------

sub format_filter_factory {
    my ($context, $format) = @_;
    $format = '%s' unless defined $format;

    return sub {
        my $text = shift;
        $text = '' unless defined $text;
        return join("\n", map{ sprintf($format, $_) } split(/\n/, $text));
    }
}


sub indent_filter_factory {
    my ($context, $pad) = @_;
    $pad = 4 unless defined $pad;
    $pad = ' ' x $pad if $pad =~ /^\d+$/;

    return sub {
        my $text = shift;
        $text = '' unless defined $text;
        $text =~ s/^/$pad/mg;
        return $text;
    }
}


sub remove_filter_factory {
    my ($context, $search) = @_;

    return sub {
        my $text = shift;
        $text = '' unless defined $text;
        $text =~ s/$search//g;
        return $text;
    }
}


sub repeat_filter_factory {
    my ($context, $iter) = @_;
    $iter = 1 unless defined $iter and length $iter;

    return sub {
        my $text = shift;
        $text = '' unless defined $text;
        return join('\n', $text) x $iter;
    }
}


sub replace_filter_factory {
    my ($context, $search, $replace) = @_;
    $search = '' unless defined $search;
    $replace = '' unless defined $replace;

    return sub {
        my $text = shift;
        $text = '' unless defined $text;
        $text =~ s/$search/$replace/g;
        return $text;
    }
}


sub truncate_filter_factory {
    my ($context, $len, $char) = @_;
    $len = 32 unless defined $len;
    $char = "..." unless defined $char;

    return sub {
        my $text = shift;
        return $text if length $text <= $len;
        return substr($text, 0, $len - length($char)) . $char;
    }
}


#-----------------------------------------------------------------------
# special handling for html_entity
#-----------------------------------------------------------------------

sub use_html_entities {
    require HTML::Entities;
    return ($DELEGATE->{ HTML_ENTITY } = \&HTML::Entities::encode_entities);
}

sub use_apache_util {
    require Apache::Util;
    Apache::Util::escape_html('');      # TODO: explain this
    return ($DELEGATE->{ HTML_ENTITY } = \&Apache::Util::escape_html);
}

sub html_entity_filter_factory {
    my $context = shift;
    my $haz;
    
    # if Apache::Util is installed then we use escape_html
    $haz = $DELEGATE->{ HTML_ENTITY } 
       ||  eval { use_apache_util()   }
       ||  eval { use_html_entities() }
       ||  -1;      # we use -1 for "not available" because it's a true value

    return ref $haz eq CODE
        ? $haz
        : $context->error('Cannot location Apache::Util or HTML::Entities for html_entity filter');
}


#-----------------------------------------------------------------------
# filters for redirecting to STDOUT, STDERR or a file 
#-----------------------------------------------------------------------

sub null {
    return '';
}

sub stderr {
    print STDERR @_; 
    return '';
}

sub stdout_filter_factory {
    my ($context, $options) = @_;

    $options = { binmode => $options } unless ref $options;

    sub {
        my $text = shift;
        binmode(STDOUT) if $options->{ binmode };
        print STDOUT $text;
        return '';
    }
}

sub redirect_filter_factory {
    my ($context, $path, $options) = @_;
    
    # see if an output filesystem is available (i.e. OUTPUT_PATH is defined)
    $context->try('output_filesystem')
        || return $context->throw( redirect => $context->reason->info );

    $context->throw( redirect => "Relative filenames are not supported for redirects: $path")
        if $path =~ m{(^|/)\.\./};

    # TODO: handle options, merge code with that in Template::TT2
    
    # $options = { binmode => $options } unless ref $options;
    
    sub {
        $context->output_file($path, shift);
        return '';
    }
}


#-----------------------------------------------------------------------
# filters for evaluating TT code or Perl
#-----------------------------------------------------------------------

sub eval_filter_factory {
    my $context = shift;

    return sub {
        my $text = shift;
        $context->process(\$text);
    }
}

sub perl_filter_factory {
    my $context = shift;
    my $stash = $context->stash;

    $context->throw( perl => 'EVAL_PERL is not set' )
        unless $context->eval_perl;
        
    return sub {
        my $text = shift;
        local($Template::Perl::context) = $context;
        local($Template::Perl::stash)   = $stash;
        my $perl = <<EOF;
package Template::Perl; 
\$stash = \$context->stash(); 
$text
EOF
        $context->debug("Evaluating Perl: $perl") if DEBUG;
        my $out = eval $perl;
        $context->throw($@) if $@;
        return $out;
    }
}



1;
__END__;

our $FILTERS = {
    'redirect'    => [ \&redirect_filter_factory,    1 ],
    'file'        => [ \&redirect_filter_factory,    1 ],  # alias
};

sub OLD_fetch {
    my ($self, $name, $args, $context) = @_;
    my ($factory, $is_dynamic, $filter, $error);

    $self->debug("fetch($name, ", 
                 defined $args ? ('[ ', join(', ', @$args), ' ]') : '<no args>', ', ',
                 defined $context ? $context : '<no context>', 
                 ')') if $self->{ DEBUG };

    # allow $name to be specified as a reference to 
    # a plugin filter object;  any other ref is 
    # assumed to be a coderef and hence already a filter;
    # non-refs are assumed to be regular name lookups

    if (ref $name) {
        if (UNIVERSAL::isa($name, $PLUGIN_FILTER)) {
            $factory = $name->factory()
                || return $self->error($name->error());
        }
        else {
            return $name;
        }
    }
    ...etc...
}



sub _init {
    my ($self, $params) = @_;

    $self->{ FILTERS  } = $params->{ FILTERS } || { };
    $self->{ TOLERANT } = $params->{ TOLERANT }  || 0;
    $self->{ DEBUG    } = ( $params->{ DEBUG } || 0 )
                          & Template::Constants::DEBUG_FILTERS;


    return $self;
}



sub _dump {
    my $self = shift;
    my $output = "[Template::Filters] {\n";
    my $format = "    %-16s => %s\n";
    my $key;

    foreach $key (qw( TOLERANT )) {
        my $val = $self->{ $key };
        $val = '<undef>' unless defined $val;
        $output .= sprintf($format, $key, $val);
    }

    my $filters = $self->{ FILTERS };
    $filters = join('', map { 
        sprintf("    $format", $_, $filters->{ $_ });
    } keys %$filters);
    $filters = "{\n$filters    }";
    
    $output .= sprintf($format, 'FILTERS (local)' => $filters);

    $filters = $FILTERS;
    $filters = join('', map { 
        my $f = $filters->{ $_ };
        my ($ref, $dynamic) = ref $f eq 'ARRAY' ? @$f : ($f, 0);
        sprintf("    $format", $_, $dynamic ? 'dynamic' : 'static');
    } sort keys %$filters);
    $filters = "{\n$filters    }";
    
    $output .= sprintf($format, 'FILTERS (global)' => $filters);

    $output .= '}';
    return $output;
}


