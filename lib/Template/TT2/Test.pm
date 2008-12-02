package Template::TT2::Test;

use Template::TT2::Class
    version   => 0.01,
    base      => 'Badger::Test',
    constants => 'HASH',
    utils     => 'trim',
    exports   => {
        all   => 'callsign test_expect',
    };

use Badger::Test;       # to import ok(), is(), etc.
    
our $MAGIC   = '\s* -- \s*';
our $ENGINE  = 'Template::TT2';
our $HANDLER = \&test_handler;
our $DATA;

require Template::TT2;

sub data_text {
    return $DATA if defined $DATA;
    local $/ = undef;
    no warnings;
    $DATA = <main::DATA>;
    $DATA =~ s/^__END__.*//sm;
    return $DATA;
}

sub data_tests {
    my $source = shift || data_text();
    my (@tests, $test, $input, $expect);
    my $count = 0;

    # remove any comment lines
    $source =~ s/^#.*?\n//gm;

    # remove the leading backslash from any escaped comments,
    # e.g. \# this comment really should be in the input/output
    $source =~ s/^\\#/#/gm;

    # remove anything before '-- start --' and/or after '-- stop --'
    $source =~ s/ .*? ^ $MAGIC start $MAGIC \n //smix;
    $source =~ s/ ^ $MAGIC stop  $MAGIC \n .* //smix;

    @tests = split(/ ^ $MAGIC test /mix, $source);

    # if the first line of the file was '-- test --' (optional) then the 
    # first test will be empty and can be discarded
    shift(@tests) if $tests[0] =~ /^\s*$/;

    foreach $test (@tests) {
        $test =~ s/ ^ \s* (.*?) $MAGIC \n //x;
        my $name = $1 || 'test ' . ++$count;
        
        unless (length $test) {
            warn "Ignoring blank test\n";
            next; 
        }
        
        # split input by a line like "-- expect --"
        ($input, $expect) = 
            split(/ ^ $MAGIC expect $MAGIC \n/mix, $test);
        $expect = '' 
            unless defined $expect;
        
        my (@inflags, $inflag, @exflags, $exflag, $param, $value);
        while ($input =~ s/ ^ $MAGIC (.*?) $MAGIC \n //mx) {
            $param = $1;
            $value = ($param =~ s/^(\w+)\s+(.+)$/$1/) ? $2 : 1;
            push(@inflags, $param);
            $inflag->{ $param } = $value;
        }

        while ($expect =~ s/ ^ $MAGIC (.*?) $MAGIC \n //mx) {
            $param = $1;
            $value = ($param =~ s/^(\w+)\s+(.+)$/$1/) ? $2 : 1;
            push(@exflags, $param);
            $exflag->{ $param } = $value;
        }
        
        $test = {
            name    => $name,
            input   => trim $input,
            expect  => trim $expect,
            inflags => \@inflags,
            inflag  => $inflag,
            exflags => \@exflags,
            exflag  => $exflag,
        };
    }

    return wantarray ? @tests : \@tests;
}

sub test_expect {
    my $config  = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $tests   = $config->{ tests   } || data_tests();
    my $handler = $config->{ handler } || $HANDLER;
    my $guard;

    foreach my $test (@$tests) {
        # handle -- skip -- flag
        if (grep(/skip/, @{ $test->{ inflags } })) {
            my $msg = $test->{ inflag }->{ skip };
            $msg = $msg eq '1' ? '' : " ($msg)";
            skip_some(1, "$test->{ name }$msg");
            next;
        }
        
        # handle -- only something -- flag
        if ( ($guard = $test->{ inflag }->{ only })  
        && ! $config->{ vars }->{ $guard } ) {
            skip_some(1, "$test->{ name } (only for $guard)");
            next;
        }

        if ($config->{ step }) {
            print STDERR "\n# ready to run: $test->{ name }   (press ENTER)";
            my $ans = <STDIN>;
            chomp $ans;
            exit if ($ans eq 'q');
        };

        my $result = &$handler($test, $config);
        chomp $result;

        if ($result eq $test->{ expect }) {
            ok(1, $test->{ name });
        }
        else {
            # pass it over to is() to make pretty 
            is( $result, $test->{ expect }, $test->{ name });
        }
    }
}

sub test_handler {
    my ($test, $config) = @_;
    my $engine = $config->{ engine }
        ||= $ENGINE->new($config->{ config } || { });

    if (my $use = $test->{ inflag }->{ use }) {
        $engine = $config->{ engine } = $config->{ engines }->{ $use }
            || die "Invalid engine specified: $use\nEngines available: ", 
                    join(', ', keys %{ $config->{ engines } || { } }), 
                    "\n";
    }
    my $in  = $test->{ input };
    my $out = '';
    
    $engine->process(\$in, $config->{ vars }, \$out);

    if ($test->{ exflag }->{ process }) {
        my ($expin, $expout);
        $expin = $test->{ expect };
        $engine->process(\$expin, $config->{ vars }, \$expout);
        $test->{ expect } = $expout;
    }

    return trim $out;
}

sub callsign {
    my %callsign;
    @callsign{ 'a'..'z' } = qw( 
        alpha bravo charlie delta echo foxtrot golf hotel india 
        juliet kilo lima mike november oscar papa quebec romeo 
        sierra tango umbrella victor whisky x-ray yankee zulu 
    );
    return \%callsign;
}

1;


