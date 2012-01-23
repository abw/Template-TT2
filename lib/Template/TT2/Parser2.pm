# This is a subclass of the regular parser, but using a grammar containing
# states as list refs instead of hash refs.

package Template::TT2::Parser2;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Parser',
    constants => ':parse';

our $GRAMMAR = 'Template::TT2::Grammar2';


sub _parse {
    my ($self, $tokens, $info) = @_;
    my ($token, $value, $text, $line, $inperl);
    my ($state, $stateno, $status, $action, $lookup, $coderet);
    my ($lhs, $len, $code);         # rule contents
    my $stack = [ [ 0, undef ] ];   # DFA stack
    
    # retrieve internal rule and state tables
    my ($states, $rules) = @$self{ qw( STATES RULES ) };

    # call the grammar set_factory method to install emitter factory
    $self->{ GRAMMAR }->install_factory($self->{ FACTORY });

    $line = $inperl = 0;
    local $self->{ LINE   } = \$line;
    local $self->{ FILE   } = $info->{ name };
    local $self->{ INPERL } = \$inperl;

    $status = PARSE_CONTINUE;
    my $in_string = 0;

    my $result = eval {
        while(1) {
            # get state number and state
            $stateno =  $stack->[-1]->[0];
            $state   = $states->[$stateno];
    
            $self->debug("stateno: $stateno\n") if DEBUG;
            $self->debug("state: $state\n") if DEBUG;
    
            # see if any lookaheads exist for the current state
            if (defined $state->[STATE_ACTIONS]) {
    
                # get next token and expand any directives (i.e. token is an 
                # array ref) onto the front of the token list
                while (! defined $token && @$tokens) {
                    $token = shift(@$tokens);
                    if (ref $token) {
                        ($text, $line, $token) = @$token;
                        if (ref $token) {
                            if ($info->{ DEBUG } && ! $in_string) {
                                # - - - - - - - - - - - - - - - - - - - - - - - - -
                                # This is gnarly.  Look away now if you're easily
                                # frightened.  We're pushing parse tokens onto the
                                # pending list to simulate a DEBUG directive like so:
                                # [% DEBUG msg line='20' text='INCLUDE foo' %]
                                # - - - - - - - - - - - - - - - - - - - - - - - - -
                                my $dtext = $text;
                                $dtext =~ s[(['\\])][\\$1]g;
                                unshift(@$tokens, 
                                        DEBUG   => 'DEBUG',
                                        IDENT   => 'msg',
                                        IDENT   => 'line',
                                        ASSIGN  => '=',
                                        LITERAL => "'$line'",
                                        IDENT   => 'text',
                                        ASSIGN  => '=',
                                        LITERAL => "'$dtext'",
                                        IDENT   => 'file',
                                        ASSIGN  => '=',
                                        LITERAL => "'$info->{ name }'",
                                        (';') x 2,
                                        @$token, 
                                        (';') x 2);
                            }
                            else {
                                unshift(@$tokens, @$token, (';') x 2);
                                $self->debug(
                                    "expanded directive token stream: ", 
                                    $self->dump_data_inline($tokens), 
                                    "\n"
                                ) if DEBUG;
                            }
                            $token = undef;  # force redo
                        }
                        elsif ($token eq 'ITEXT') {
                            if ($inperl) {
                                # don't perform interpolation in PERL blocks
                                $token = 'TEXT';
                                $value = $text;
                            }
                            else {
                                unshift(@$tokens, 
                                        @{ $self->interpolate_text($text, $line) });
                                $token = undef; # force redo
                            }
                        }
                    }
                    else {
                        # toggle string flag to indicate if we're crossing
                        # a string boundary
                        $in_string = ! $in_string if $token eq '"';
                        $value = shift(@$tokens);
                    }
                };
                # clear undefined token to avoid 'undefined variable blah blah'
                # warnings and let the parser logic pick it up in a minute
                $token = '' unless defined $token;
    
                # get the next state for the current lookahead token
                $action = defined ($lookup = $state->[STATE_ACTIONS]->{ $token })
                          ? $lookup
                          : defined ($lookup = $state->[STATE_DEFAULT])
                            ? $lookup
                            : undef;
            }
            else {
                # no lookahead actions
                $action = $state->[STATE_DEFAULT];
            }
    
            # ERROR: no ACTION
            last unless defined $action;
    
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            # shift (+ive ACTION)
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            if ($action > 0) {
                push(@$stack, [ $action, $value ]);
                $token = $value = undef;
                redo;
            };
    
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            # reduce (-ive ACTION)
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            ($lhs, $len, $code) = @{ $rules->[ -$action ] };
    
            # no action imples ACCEPTance
            $action
                or $status = PARSE_ACCEPT;

            if ($code) {
                $coderet = &$code( 
                    $self,
                    $len ? map { $_->[1] } @$stack[ -$len .. -1 ] : ()  
                );
            }
            else {
                # no subroutine indicates default action which is to return
                # $_[1].  We just have to be careful because it'll be $len
                # items down in the stack
                $coderet = $stack->[-$len]->[1];
            }
            
#            $self->debug("status: $status   returned: $coderet\n");

            # reduce stack by $len
            splice(@$stack, -$len, $len);
    
            # ACCEPT
            return $coderet                                     ## RETURN ##
                if $status == PARSE_ACCEPT;
    
            # ABORT
            return undef                                        ## RETURN ##
                if $status == PARSE_ABORT;
    
            # ERROR
            last 
                if $status == PARSE_ERROR;
        }
        continue {
            push(
                @$stack, 
                [ 
                    $states->[ $stack->[-1][0] ]->[STATE_GOTOS]->{ $lhs }, 
                    $coderet 
                ]
            );
        }
    };   # eval
    return $result if $result;
    
    if ($@) {
        my $err = $@;
        chomp $err;
        return $self->_parse_error($err);
    }
    
    # ERROR                                                 ## RETURN ##
    return $self->_parse_error('unexpected end of input')
        unless defined $value;

    # munge text of last directive to make it readable
#    $text =~ s/\n/\\n/g;

    return $self->_parse_error("unexpected end of directive", $text)
        if $value eq ';';   # end of directive SEPARATOR

    return $self->_parse_error("unexpected token ($value)", $text);
}

1;
