package Template::Plugin::ProcBaz;
use base 'Template::Plugin::ProcBar';

sub baz { join(', ', "This is procbazbaz", @_) }

1;
