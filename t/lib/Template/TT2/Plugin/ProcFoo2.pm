package Template::TT2::Plugin::ProcFoo2;
use base 'Template::TT2::Plugin::Procedural';

sub foo { "This is procfoo2foo" }
sub bar { join(', ', "This is procfoo2bar", @_) }

1;
