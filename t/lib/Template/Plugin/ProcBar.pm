package Template::Plugin::ProcBar;
use base 'Template::Plugin::ProcFoo';

sub bar { "This is procbarbar" }
sub baz { join(', ', "This is procbarbaz", @_) }

1;
