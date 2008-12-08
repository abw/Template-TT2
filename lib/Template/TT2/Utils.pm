package Template::TT2::Utils;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Utils',
    constants => 'REFS PKG UNICODE',
    constant  => {
        FH2TEXT   => 'Template::TT2::Utils::FH2Text',
        PERLFH    => \*Template::TT2::Perl::PERLOUT,
        FILE_TEMP => 'File::Temp',
    },
    exports   => {
        any   => 'trim',
        hooks => {
            tempfile => \&_export_file_temp,
        },
    };

sub _export_file_temp {
    my ($class, $target, $symbol, $symbols) = @_;
    require File::Temp;
    no strict REFS;
    $class->export_symbol($target, $symbol, \&{ FILE_TEMP.PKG.$symbol });
}

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
