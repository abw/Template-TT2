package Template::TT2::Modules;

use Badger::Factory::Class
    version   => 0.01,
    item      => 'module',
    path      => 'Template::TT2',
    constants => 'HASH',
    modules   => {
        constants => 'Template::TT2::Namespace::Constants',
    },
    messages  => {
        preload => 'Failed to preload %s module (not found)',
    };

our @PRELOAD = qw( context templates plugins filters parser iterator service stash );

sub preload {
    my $self = shift->prototype;
    
    foreach my $module (@PRELOAD, @_) {
        $self->find($module) 
            || return $self->error_msg( preload => $module );
    };
}

1;

__END__

