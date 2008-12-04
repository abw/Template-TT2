package Template::TT2::Plugins;
    
use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Base',
    constants => 'HASH CODE TT2_PLUGIN',
    accessors => 'hub',
    utils     => 'is_object',
    messages  => {
        bad_plugin => "Invalid plugin definition for '%s' (%s)",
    };

use Badger::Factory::Class
    item      => 'plugin',
    path      => 'Template::TT2::Plugin Template::Plugin',
    plugins   => { 
        cgi   => 'Template::TT2::Plugin::CGI',
        url   => 'Template::TT2::Plugin::URL',
        html  => 'Template::TT2::Plugin::HTML',
    };


sub type_args {
    shift;
    return (@_);
}

sub load {
    my ($self, $type, $context) = @_;
    my $class = $self->SUPER::load($type);
    $class->load($context);
}

sub init {
    my ($self, $config) = @_;
    $config->{ plugins } ||= $config->{ PLUGINS };
    return $self->init_factory($config);
}

1;
