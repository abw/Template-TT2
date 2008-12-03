package Template::TT2::Plugin::ProcBaz2;
use base 'Template::TT2::Plugin::ProcBar2';

sub baz { join(', ', "This is procbaz2baz", @_) }

1;
