package Template::TT2::Plugin::ProcBar2;
use base 'Template::TT2::Plugin::ProcFoo2';

sub bar { "This is procbar2bar" }
sub baz { join(', ', "This is procbar2baz", @_) }

1;
