package Template::TT2::Modules;

use Badger::Factory::Class
    version   => 0.01,
    item      => 'module',
    path      => 'Template::TT2',
    constants => 'HASH',
    modules   => {
        templates => 'Template::TT2::Provider',
        constants => 'Template::TT2::Namespace::Constants',
    };
    
#our @PRELOAD = ( $CONTEXT, $FILTERS, $ITERATOR, $PARSER,
#               $PLUGINS, $PROVIDER, $SERVICE, $STASH );

# the following is set at installation time by the Makefile.PL 
our $INSTDIR  = '';


sub type_args {
    my $self = shift;
    my $type = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    return ($type, $args);
}


sub preload {
    my $class = shift;

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

