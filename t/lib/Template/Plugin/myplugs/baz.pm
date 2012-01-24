package Template::Plugin::myplugs::baz;

# This is not the Template::Plugin::MyPlugs::Baz module you're looking for.
#-----------------------------------------------------------------------------
# Some filesystems are case insensitive (e.g. Apple's HFS with default 
# settings) which means this module might get loaded accidentally when
# we're actually after the MyPlugs::Baz module.  Badger::Class works 
# around this by checking not only that the filesystem reports the 
# module as being loaded, but also that the symbol table for the requested
# module is not empty.

our $VERSION = 4.20;

print "loaded Template::Plugin::myplugs::baz (you must have a case insensitive filesystem?)\n";

1;
