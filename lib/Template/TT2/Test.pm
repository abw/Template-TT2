package Template::TT2::Test;

use Badger::Test;       # to import ok(), is(), etc.
use Template::TT2;
use Template::TT2::Class
    version   => 0.01,
    base      => 'Badger::Test',
    constants => 'HASH',
    utils     => 'trim',
    exports   => {
        all   => 'callsign test_expect',
    };
    
our $MAGIC   = '\s* -- \s*';
our $ENGINE  = 'Template::TT2';
our $HANDLER = \&test_handler;
our $DATA;

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

    foreach my $test (@$tests) {
        if (grep(/skip/, @{ $test->{ inflags } })) {
            my $msg = $test->{ inflag }->{ skip };
            $msg = $msg eq '1' ? '' : " ($msg)";
            skip("$test->{ name }$msg");
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


#------------------------------------------------------------------------
# data_text()
#
# Returns the text from the DATA section and caches it locally so that
# we can fetch it again and again.  It also looks for an extra __END__ tag
# in the text (yes, an extra one coming after the first one), and removes
# anything after it.
#------------------------------------------------------------------------

#------------------------------------------------------------------------
# data_tests()
#
# Calls data_text() to read the text in the DATA section and splits it
# into a number of tests.  Each test starts with "-- test something --"
# where "something" (which can be anything) denotes the test name.
# It can be followed by any number of "-- any_flag --" lines denoting
# input flags.  Then the input text follows up to an "-- expect --"
# line, which can also be followed by a number of flag lines, then 
# the expected output from the test.  e.g.
#
#    -- test example --               # test name: "example"
#    -- parse_foo --                  # input flag: "parse_foo"
#    The [% a %] sat on the [% b %]   # test input
#    -- expect --                     # start of expected text
#    The cat sat on the mat           # expected test output
#
# Returns a list of tests, each of which is a hash array containing 
# 'name', 'input', and 'expect' items, 'inflags' and 'exflags' which
# are lists containing the input and output flags, and also 'inflag'
# and 'outflag' which are hashes containing the input and output flags 
# as keys so that you can C<if $test->{ inflag }->{ parse_foo }>, for 
# example.
#------------------------------------------------------------------------


#------------------------------------------------------------------------
# test_expect($config)
#
# Run each test in the data section and checks the output matches what
# was expected.  List or hash of named parameters is passed, including
# 'handler' as a reference to a subroutine which handles each test.
#------------------------------------------------------------------------


#------------------------------------------------------------------------
# diff_result($expect, $result)
#
# Generate list of differences between expected and resultant output.
#------------------------------------------------------------------------

#------------------------------------------------------------------------
# callsign()
#
# Returns a hash array mapping lower a..z to their phonetic alphabet 
# equivalents.
#------------------------------------------------------------------------


