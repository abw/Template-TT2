package Template::Plugin::ProcFoo;
use base 'Template::Plugin::Procedural';

sub foo { "This is procfoofoo" }
sub bar { join(', ', "This is procfoobar", @_) }

1;
