#============================================================= -*-Perl-*-
#
# Template::TT2::Parser
#
# DESCRIPTION
#   This module implements a LALR(1) parser and assocated support 
#   methods to parse template documents into the appropriate "compiled"
#   format.  Much of the parser DFA code (see _parse() method) is based 
#   on Francois Desarmenien's Parse::Yapp module.  Kudos to him.
# 
# AUTHOR
#   Andy Wardley <abw@wardley.org>
#
#============================================================================

package Template::TT2::Parser;

use Template::TT2::Hub;
use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Base',
    import    => 'class',
    constants => ':status :chomp :parse TT2_HUB',
    throws    => 'parse',
    config    => [
        'FACTORY|class:FACTORY=Template::TT2::Directive',
        'GRAMMAR|class:GRAMMAR=Template::TT2::Grammar',
        'TAG_STYLE|class:TAG_STYLE=default',
        'FILE_INFO=1',
        'EVAL_PERL=0',
    ];

use Template::TT2::Grammar 
    '@TABLE_NAMES';

our $TAG_STYLES  = {
    'default'   => [ '\[%',    '%\]'    ],
    'template1' => [ '[\[%]%', '%[\]%]' ],
    'metatext'  => [ '%%',     '%%'     ],
    'html'      => [ '<!--',   '-->'    ],
    'mason'     => [ '<%',     '>'      ],
    'asp'       => [ '<%',     '%>'     ],
    'php'       => [ '<\?',    '\?>'    ],
    'star'      => [ '\[\*',   '\*\]'   ],
};
$TAG_STYLES->{ template } = $TAG_STYLES->{ tt2 } = $TAG_STYLES->{ default };

our $DEFAULT_STYLE = {
    START_TAG   => $TAG_STYLES->{ default }->[0],
    END_TAG     => $TAG_STYLES->{ default }->[1],
    ANYCASE     => 0,
    INTERPOLATE => 0,
    PRE_CHOMP   => 0,
    POST_CHOMP  => 0,
    EVAL_PERL   => 0,
};

our $QUOTED_ESCAPES = {
        n => "\n",
        r => "\r",
        t => "\t",
};

# note that '-' must come first so Perl doesn't think it denotes a range
our $CHOMP_FLAGS  = qr/[-=~+]/;

sub init {
    my ($self, $config) = @_;
    my $grammar;

    # copy this so that on_warn, etc., from Badger:Base work
    $self->{ config } = $config;
    $self->configure($config);
    $self->{ info } = [ ];

#    my ($tagstyle, $debug, $start, $end, $defaults, $grammar, $hash, $key, $udef);

    # load and instantiate grammar if not already an object then ask it
    # for lextable, states and rules
    $grammar = $self->{ GRAMMAR };
    $grammar = class($grammar)->load->instance
        unless ref $grammar;
    # load grammar rules, states and lex table
    @$self{ @TABLE_NAMES } = $grammar->tables;

    use Data::Dumper;
#    $self->debug( Dumper($self));
#    $self->debug("setup {", join(",\n", map { "$_ => $self->{ $_ }" } keys %$self), "}\n");

    if (my $constants = $config->{ CONSTANTS }) {
        my $hub = $config->{ hub } || TT2_HUB;
        my $ns  = $config->{ NAMESPACE } ||= { };
        my $cns = $config->{ CONSTANTS_NAMESPACE } || 'constants';
        $self->debug("Asking hub to create constants: $hub") if DEBUG;
        $ns->{ $cns } = $hub->module( constants => $constants );
    }

    # build a FACTORY object to include any NAMESPACE definitions,
    # but only if FACTORY isn't already an object
    if ($config->{ NAMESPACE }) {
        if (ref $self->{ FACTORY }) {
            $self->warn("Cannot add NAMESPACE definition to existing FACTORY object\n");
        }
        else {
            $self->{ FACTORY } = class($self->{ FACTORY })->load->instance(
                NAMESPACE => $config->{ NAMESPACE } 
            );
        }
    } 
    else {
        $self->{ FACTORY } = class($self->{ FACTORY })->load->instance
            unless ref $self->{ FACTORY };
    }
    
    $self->new_style($config);

    $self->warn_msg( deprecated => 'V1DOLLAR') 
        if $config->{ V1DOLLAR };
        
    return $self;
}


#------------------------------------------------------------------------
# new_style(\%config)
# 
# Install a new (stacked) parser style.  This feature is currently 
# experimental but should mimic the previous behaviour with regard to 
# TAG_STYLE, START_TAG, END_TAG, etc.
#------------------------------------------------------------------------

sub new_style {
    my ($self, $config) = @_;
    my $styles = $self->{ STYLE } ||= [ ];
    my ($tagstyle, $tags, $start, $end, $key);

    # clone new style from previous or default style
    my $style  = { %{ $styles->[-1] || $DEFAULT_STYLE } };

    # expand START_TAG and END_TAG from specified TAG_STYLE
    if ($tagstyle = $config->{ TAG_STYLE }) {
        return $self->error("Invalid tag style: $tagstyle")
            unless defined ($tags = $TAG_STYLES->{ $tagstyle });
        ($start, $end) = @$tags;
        $config->{ START_TAG } ||= $start;
        $config->{   END_TAG } ||= $end;
    }

    foreach $key (keys %$DEFAULT_STYLE) {
        $style->{ $key } = $config->{ $key } if defined $config->{ $key };
        $self->debug("style: $key => $style->{ $key }\n") if DEBUG;
    }
    push(@$styles, $style);
    return $style;
}


#------------------------------------------------------------------------
# old_style()
#
# Pop the current parser style and revert to the previous one.  See 
# new_style().   ** experimental **
#------------------------------------------------------------------------

sub old_style {
    my $self = shift;
    my $styles = $self->{ STYLE };
    return $self->error('only 1 parser style remaining')
        unless (@$styles > 1);
    pop @$styles;
    return $styles->[-1];
}


#------------------------------------------------------------------------
# parse($text, $data)
#
# Parses the text string, $text and returns a hash array representing
# the compiled template block(s) as Perl code, in the format expected
# by Template::Document.
#------------------------------------------------------------------------

sub parse {
    my ($self, $text, $info) = @_;
    my ($tokens, $block);

    # TODO: fix up DEBUG option
    $info->{ DEBUG } = $self->{ DEBUG_DIRS } || 0
        unless defined $info->{ DEBUG };

#    print "info: { ", join(', ', map { "$_ => $info->{ $_ }" } keys %$info), " }\n";

    # store for blocks defined in the template (see define_block())
    my $defblock = local $self->{ DEFBLOCK } = { };
    my $metadata = local $self->{ METADATA } = [ ];
    local $self->{ DEFBLOCKS } = [ ];
#   local $self->{ TEMPLATE_NAME } = 

    # split file into TEXT/DIRECTIVE chunks
    $tokens = $self->split_text($text)
        || return undef;                                    ## RETURN ##

    $self->debug("tokens: ", $self->dump_data($tokens), "\n") if DEBUG;

#    $self->debug("INFO: ", $self->dump_data($info), "\n");
    push(@{ $self->{ info } }, $info);

    # parse chunks
    $block = $self->_parse($tokens, $info);
    
    pop(@{ $self->{ info } });

    return undef unless $block;                             ## RETURN ##

    $self->debug("compiled main template document block:\n$block") if DEBUG;

    return {
        BLOCK     => $block,
        DEFBLOCKS => $defblock,
        METADATA  => { @$metadata },
    };
}



#------------------------------------------------------------------------
# split_text($text)
#
# Split input template text into directives and raw text chunks.
#------------------------------------------------------------------------

sub split_text {
    my ($self, $text) = @_;
    my ($pre, $dir, $prelines, $dirlines, $postlines, $chomp, $tags, @tags);
    my $style = $self->{ STYLE }->[-1];
    my ($start, $end, $prechomp, $postchomp, $interp ) = 
        @$style{ qw( START_TAG END_TAG PRE_CHOMP POST_CHOMP INTERPOLATE ) };
    my $tags_dir = $self->{ANYCASE} ? qr<TAGS>i : qr<TAGS>;

    my @tokens = ();
    my $line = 1;

    return \@tokens                                         ## RETURN ##
        unless defined $text && length $text;

    # extract all directives from the text
    while ($text =~ s/
           ^(.*?)               # $1 - start of line up to directive
           (?:
            $start          # start of tag
            (.*?)           # $2 - tag contents
            $end            # end of tag
            )
           //sx) {
        
        ($pre, $dir) = ($1, $2);
        $pre = '' unless defined $pre;
        $dir = '' unless defined $dir;
        
        $prelines  = ($pre =~ tr/\n//);  # newlines in preceeding text
        $dirlines  = ($dir =~ tr/\n//);  # newlines in directive tag
        $postlines = 0;                  # newlines chomped after tag
        
        for ($dir) {
            if (/^\#/) {
                # comment out entire directive except for any end chomp flag
                $dir = ($dir =~ /($CHOMP_FLAGS)$/o) ? $1 : '';
            }
            else {
                s/^($CHOMP_FLAGS)?\s*//so;
                # PRE_CHOMP: process whitespace before tag
                $chomp = $1 ? $1 : $prechomp;
                $chomp =~ tr/-=~+/1230/;
                if ($chomp && $pre) {
                    # chomp off whitespace and newline preceding directive
                    if ($chomp == CHOMP_ALL) { 
                        $pre =~ s{ (\n|^) [^\S\n]* \z }{}mx;
                    }
                    elsif ($chomp == CHOMP_COLLAPSE) { 
                        $pre =~ s{ (\s+) \z }{ }x;
                    }
                    elsif ($chomp == CHOMP_GREEDY) { 
                        $pre =~ s{ (\s+) \z }{}x;
                    }
                }
            }
            
            # POST_CHOMP: process whitespace after tag
            s/\s*($CHOMP_FLAGS)?\s*$//so;
            $chomp = $1 ? $1 : $postchomp;
            $chomp =~ tr/-=~+/1230/;
            if ($chomp) {
                if ($chomp == CHOMP_ALL) { 
                    $text =~ s{ ^ ([^\S\n]* \n) }{}x  
                        && $postlines++;
                }
                elsif ($chomp == CHOMP_COLLAPSE) { 
                    $text =~ s{ ^ (\s+) }{ }x  
                        && ($postlines += $1=~y/\n//);
                }
                # any trailing whitespace
                elsif ($chomp == CHOMP_GREEDY) { 
                    $text =~ s{ ^ (\s+) }{}x  
                        && ($postlines += $1=~y/\n//);
                }
            }
        }
            
        # any text preceding the directive can now be added
        if (length $pre) {
            push(@tokens, $interp
                 ? [ $pre, $line, 'ITEXT' ]
                 : ('TEXT', $pre) );
        }
        $line += $prelines;
            
        # and now the directive, along with line number information
        if (length $dir) {
            # the TAGS directive is a compile-time switch
            if ($dir =~ /^$tags_dir\s+(.*)/) {
                @tags = split(/\s+/, $1);
                if (scalar @tags > 1) {
                    ($start, $end) = map { quotemeta($_) } @tags;
                }
                elsif ($tags = $TAG_STYLES->{ $tags[0] }) {
                    ($start, $end) = @$tags;
                }
                else {
                    $self->warn("invalid TAGS style: $tags[0]\n");
                }
            }
            else {
                # DIRECTIVE is pushed as:
                #   [ $dirtext, $line_no(s), \@tokens ]
                push(@tokens, 
                     [ $dir, 
                       ($dirlines 
                        ? sprintf("%d-%d", $line, $line + $dirlines)
                        : $line),
                       $self->tokenise_directive($dir) ]);
            }
        }
            
        # update line counter to include directive lines and any extra
        # newline chomped off the start of the following text
        $line += $dirlines + $postlines;
    }
        
    # anything remaining in the string is plain text 
    push(@tokens, $interp 
         ? [ $text, $line, 'ITEXT' ]
         : ( 'TEXT', $text) )
        if length $text;
        
    return \@tokens;                                        ## RETURN ##
}
    


#------------------------------------------------------------------------
# interpolate_text($text, $line)
#
# Examines $text looking for any variable references embedded like
# $this or like ${ this }.
#------------------------------------------------------------------------

sub interpolate_text {
    my ($self, $text, $line) = @_;
    my @tokens  = ();
    my ($pre, $var, $dir);


   while ($text =~
           /
           ( (?: \\. | [^\$] ){1,3000} ) # escaped or non-'$' character [$1]
           |
           ( \$ (?:                 # embedded variable            [$2]
             (?: \{ ([^\}]*) \} )   # ${ ... }                     [$3]
             |
             ([\w\.]+)              # $word                        [$4]
             )
           )
        /gx) {

        ($pre, $var, $dir) = ($1, $3 || $4, $2);

        # preceding text
        if (defined($pre) && length($pre)) {
            $line += $pre =~ tr/\n//;
            $pre =~ s/\\\$/\$/g;
            push(@tokens, 'TEXT', $pre);
        }
        # $variable reference
        if ($var) {
            $line += $dir =~ tr/\n/ /;
            push(@tokens, [ $dir, $line, $self->tokenise_directive($var) ]);
        }
        # other '$' reference - treated as text
        elsif ($dir) {
            $line += $dir =~ tr/\n//;
            push(@tokens, 'TEXT', $dir);
        }
    }

    return \@tokens;
}



#------------------------------------------------------------------------
# tokenise_directive($text)
#
# Called by the private _parse() method when it encounters a DIRECTIVE
# token in the list provided by the split_text() or interpolate_text()
# methods.  The directive text is passed by parameter.
#
# The method splits the directive into individual tokens as recognised
# by the parser grammar (see Template::Grammar for details).  It
# constructs a list of tokens each represented by 2 elements, as per
# split_text() et al.  The first element contains the token type, the
# second the token itself.
#
# The method tokenises the string using a complex (but fast) regex.
# For a deeper understanding of the regex magic at work here, see
# Jeffrey Friedl's excellent book "Mastering Regular Expressions",
# from O'Reilly, ISBN 1-56592-257-3
#
# Returns a reference to the list of chunks (each one being 2 elements) 
# identified in the directive text.  On error, the internal _ERROR string 
# is set and undef is returned.
#------------------------------------------------------------------------

sub tokenise_directive {
    my ($self, $text, $line) = @_;
    my ($token, $uctoken, $type, $lookup);
    my $lextable = $self->{ LEXTABLE };
    my $style    = $self->{ STYLE }->[-1];
    my ($anycase, $start, $end) = @$style{ qw( ANYCASE START_TAG END_TAG ) };
    my @tokens = ( );

    while ($text =~ 
            / 
                # strip out any comments
                (\#[^\n]*)
           |
                # a quoted phrase matches in $3
                (["'])                   # $2 - opening quote, ' or "
                (                        # $3 - quoted text buffer
                    (?:                  # repeat group (no backreference)
                        \\\\             # an escaped backslash \\
                    |                    # ...or...
                        \\\2             # an escaped quote \" or \' (match $1)
                    |                    # ...or...
                        .                # any other character
                    |   \n
                    )*?                  # non-greedy repeat
                )                        # end of $3
                \2                       # match opening quote
            |
                # an unquoted number matches in $4
                (-?\d+(?:\.\d+)?)       # numbers
            |
                # filename matches in $5
                ( \/?\w+(?:(?:\/|::?)\w*)+ | \/\w+)
            |
                # an identifier matches in $6
                (\w+)                    # variable identifier
            |   
                # an unquoted word or symbol matches in $7
                (   [(){}\[\]:;,\/\\]    # misc parenthesis and symbols
#               |   \->                  # arrow operator (for future?)
                |   [+\-*]               # math operations
                |   \$\{?                # dollar with option left brace
                |   =>                   # like '='
                |   [=!<>]?= | [!<>]     # eqality tests
                |   &&? | \|\|?          # boolean ops
                |   \.\.?                # n..n sequence
                |   \S+                  # something unquoted
                )                        # end of $7
            /gmxo) {

        # ignore comments to EOL
        next if $1;

        # quoted string
        if (defined ($token = $3)) {
            # double-quoted string may include $variable references
            if ($2 eq '"') {
                if ($token =~ /[\$\\]/) {
                    $type = 'QUOTED';
                    # unescape " and \ but leave \$ escaped so that 
                        # interpolate_text() doesn't incorrectly treat it
                    # as a variable reference
#                   $token =~ s/\\([\\"])/$1/g;
                        for ($token) {
                                s/\\([^\$nrt])/$1/g;
                                s/\\([nrt])/$QUOTED_ESCAPES->{ $1 }/ge;
                        }
                    push(@tokens, ('"') x 2,
                                  @{ $self->interpolate_text($token) },
                                  ('"') x 2);
                    next;
                }
                else {
                    $type = 'LITERAL';
                    $token =~ s['][\\']g;
                    $token = "'$token'";
                }
            } 
            else {
                $type = 'LITERAL';
                $token = "'$token'";
            }
        }
        # number
        elsif (defined ($token = $4)) {
            $type = 'NUMBER';
        }
        elsif (defined($token = $5)) {
            $type = 'FILENAME';
        }
        elsif (defined($token = $6)) {
            # Fold potential keywords to UPPER CASE if the ANYCASE option is
            # set, unless (we've got some preceeding tokens and) the previous
            # token is a DOT op.  This prevents the 'last' in 'data.last'
            # from being interpreted as the LAST keyword.
            $uctoken = 
                ($anycase && (! @tokens || $tokens[-2] ne 'DOT'))
                    ? uc $token
                    :    $token;
            if (defined ($type = $lextable->{ $uctoken })) {
                $token = $uctoken;
            }
            else {
                $type = 'IDENT';
            }
        }
        elsif (defined ($token = $7)) {
            # reserved words may be in lower case unless case sensitive
            $uctoken = $anycase ? uc $token : $token;
            unless (defined ($type = $lextable->{ $uctoken })) {
                $type = 'UNQUOTED';
            }
        }

        push(@tokens, $type, $token);

#       print(STDERR " +[ $type, $token ]\n")
#           if $DEBUG;
    }

#    print STDERR "tokenise directive() returning:\n  [ @tokens ]\n"
#       if $DEBUG;

    return \@tokens;                                        ## RETURN ##
}


#------------------------------------------------------------------------
# define_block($name, $block)
#
# Called by the parser 'defblock' rule when a BLOCK definition is 
# encountered in the template.  The name of the block is passed in the 
# first parameter and a reference to the compiled block is passed in
# the second.  This method stores the block in the $self->{ DEFBLOCK }
# hash which has been initialised by parse() and will later be used 
# by the same method to call the store() method on the calling cache
# to define the block "externally".
#------------------------------------------------------------------------

sub define_block {
    my ($self, $name, $block) = @_;
    my $defblock = $self->{ DEFBLOCK } 
        || return undef;

    $self->debug("compiled block '$name':\n$block") if DEBUG;

    $defblock->{ $name } = $block;
    
    return undef;
}

sub push_defblock {
    my $self = shift;
    my $stack = $self->{ DEFBLOCK_STACK } ||= [];
    push(@$stack, $self->{ DEFBLOCK } );
    $self->{ DEFBLOCK } = { };
}

sub pop_defblock {
    my $self  = shift;
    my $defs  = $self->{ DEFBLOCK };
    my $stack = $self->{ DEFBLOCK_STACK } || return $defs;
    return $defs unless @$stack;
    $self->{ DEFBLOCK } = pop @$stack;
    return $defs;
}


#------------------------------------------------------------------------
# add_metadata(\@setlist)
#------------------------------------------------------------------------

sub add_metadata {
    my ($self, $setlist) = @_;
    my $metadata = $self->{ METADATA } 
        || return undef;

    push(@$metadata, @$setlist);
    
    return undef;
}


#------------------------------------------------------------------------
# location()
#
# Return Perl comment indicating current parser file and line
#------------------------------------------------------------------------

sub location {
    my $self = shift;
    return "\n" unless $self->{ FILE_INFO };
    my $line = ${ $self->{ LINE } };
    my $info = $self->{ info }->[-1];
    my $file = $info->{ path } || $info->{ name } 
        || '(unknown template)';
    $line =~ s/\-.*$//; # might be 'n-n'
    return "#line $line \"$file\"\n";
}


#========================================================================
#                     -----  PRIVATE METHODS -----
#========================================================================

#------------------------------------------------------------------------
# _parse(\@tokens, \@info)
#
# Parses the list of input tokens passed by reference and returns a 
# Template::Directive::Block object which contains the compiled 
# representation of the template. 
#
# This is the main parser DFA loop.  See embedded comments for 
# further details.
#
# On error, undef is returned and the internal _ERROR field is set to 
# indicate the error.  This can be retrieved by calling the error() 
# method.
#------------------------------------------------------------------------

sub _parse {
    my ($self, $tokens, $info) = @_;
    my ($token, $value, $text, $line, $inperl);
    my ($state, $stateno, $status, $action, $lookup, $coderet, @codevars);
    my ($lhs, $len, $code);         # rule contents
    my $stack = [ [ 0, undef ] ];   # DFA stack

# DEBUG
#   local $" = ', ';

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

    while(1) {
        # get state number and state
        $stateno =  $stack->[-1]->[0];
        $state   = $states->[$stateno];

#        $self->debug("stateno: $stateno\n");
#        $self->debug("state: $state\n");

        # see if any lookaheads exist for the current state
        if (exists $state->{'ACTIONS'}) {

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
            $action = defined ($lookup = $state->{'ACTIONS'}->{ $token })
                      ? $lookup
                      : defined ($lookup = $state->{'DEFAULT'})
                        ? $lookup
                        : undef;
        }
        else {
            # no lookahead actions
            $action = $state->{'DEFAULT'};
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

        # use dummy sub if code ref doesn't exist
        $code = sub { $_[1] }
            unless $code;

        @codevars = $len
                ?   map { $_->[1] } @$stack[ -$len .. -1 ]
                :   ();

        eval {
            $coderet = &$code( $self, @codevars );
        };
        if ($@) {
            my $err = $@;
            chomp $err;
            return $self->_parse_error($err);
        }

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
        push(@$stack, [ $states->[ $stack->[-1][0] ]->{'GOTOS'}->{ $lhs }, 
              $coderet ]), 
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



#------------------------------------------------------------------------
# _parse_error($msg, $dirtext)
#
# Method used to handle errors encountered during the parse process
# in the _parse() method.  
#------------------------------------------------------------------------

sub _parse_error {
    my ($self, $msg, $text) = @_;
    my $file = $self->{ FILE } || '';
    my $line = $self->{ LINE };
    $line = ref($line) ? $$line : $line;
    $line = 'unknown' unless $line;

    $msg .= "\n  [% $text %]"
        if defined $text;

    return $self->error("$file line $line: $msg");
}


#------------------------------------------------------------------------
# _dump()
# 
# Debug method returns a string representing the internal state of the 
# object.
#------------------------------------------------------------------------

sub _dump {
    my $self = shift;
    my $output = "[Template::Parser] {\n";
    my $format = "    %-16s => %s\n";
    my $key;

    foreach $key (qw( START_TAG END_TAG TAG_STYLE ANYCASE INTERPOLATE 
                      PRE_CHOMP POST_CHOMP V1DOLLAR )) {
        my $val = $self->{ $key };
        $val = '<undef>' unless defined $val;
        $output .= sprintf($format, $key, $val);
    }

    $output .= '}';
    return $output;
}


1;

__END__

# COPYRIGHT
#   Copyright (C) 1996-2007 Andy Wardley.  All Rights Reserved.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#   The following copyright notice appears in the Parse::Yapp 
#   documentation.  
#
#      The Parse::Yapp module and its related modules and shell
#      scripts are copyright (c) 1998 Francois Desarmenien,
#      France. All rights reserved.
#
#      You may use and distribute them under the terms of either
#      the GNU General Public License or the Artistic License, as
#      specified in the Perl README file.
# 

