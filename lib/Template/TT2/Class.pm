package Template::TT2::Class;

use Badger::Debug ':debug';
use Badger::Class
    version  => 0.01,
    uber     => 'Badger::Class',
    constant => {
        base_id   => 'Template::TT2',
        CONSTANTS => 'Template::TT2::Constants',
        UTILS     => 'Template::TT2::Utils',
    };

1;

        