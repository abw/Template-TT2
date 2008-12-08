package Template::TT2::Modules;

use Badger::Factory::Class
    version   => 0.01,
    item      => 'module',
    path      => 'Template::TT2',
    constants => 'HASH',
    modules   => {
        constants => 'Template::TT2::Namespace::Constants',
    };

use Badger::Debug 'debug_args :dump';
    
#our @PRELOAD = ( $CONTEXT, $FILTERS, $ITERATOR, $PARSER,
#               $PLUGINS, $PROVIDER, $SERVICE, $STASH );

# the following is set at installation time by the Makefile.PL 
our $INSTDIR  = '';


sub preload {
    my $class = shift;
    $class->todo;

#    foreach my $module (@PRELOAD, @_) {
#        $class->load($module) || return;
#    };
    return 1;
}


#------------------------------------------------------------------------
# instdir($dir)
#
# Returns the root installation directory appended with any local 
# component directory passed as an argument.
#------------------------------------------------------------------------

sub instdir {
    my ($class, $dir) = @_;
    my $inst = $INSTDIR 
        || return $class->error("no installation directory");
    $inst =~ s[/$][]g;
    $inst .= "/$dir" if $dir;
    return $inst;
}



1;

__END__

