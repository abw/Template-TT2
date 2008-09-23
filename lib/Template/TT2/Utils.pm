package Template::TT2::Utils;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Utils',
    constant => {
        FH2TEXT => 'Template::TT2::Utils::FH2Text',
        PERLFH  => \*Template::TT2::Perl::PERLOUT,
    },
    exports  => {
        any => 'trim',
    };

sub trim ($) {
    my $text = shift;
    for ($text) {
        s/^\s+//;
        s/\s+$//;
    }
    return $text;
}

sub fh2text {
    my $glob = shift || PERLFH;
    my $text = @_ ? shift : '';
    my $tref = ref $text ? $text : \$text;
    tie $glob, FH2TEXT, $tref;
    return $tref;
}

package Template::TT2::Utils::FH2Text;

sub TIEHANDLE {
    my ($class, $textref) = @_;
    bless $textref, $class;
}

sub PRINT {
    my $self = shift;
    $$self .= join('', @_);
}

1;
