package Demo::Heredoc::Parser;

use 5.10.0;
use strict;
use warnings;
use Marpa::R2 '2.052000';

sub new {
    my $class = shift;

    my $grammar = Marpa::R2::Scanless::G->new({
        default_action => '::array',

        source => \<<'GRAMMAR',

:start        ::= statements

statements    ::= statement+

# Statement should handle their own semi_colons

statement     ::= expressions semi_colon action => ::first
                | newline

expressions   ::= expression+            separator => comma

expression    ::= heredoc                action => ::first
                | 'say' expressions

# The heredoc rule is different from how the source code actually looks The
# pause adverb allows to send only the parts the are useful

heredoc       ::= (<heredoc op>) <heredoc terminator>       action => ::first

# Pause at <heredoc terminator> and at newlines.
:lexeme         ~ <heredoc terminator>    pause => before
:lexeme         ~ newline    pause => before

<heredoc op>    ~ '<<'
semi_colon      ~ ';'
comma           ~ ','
newline         ~ [\n]

# The syntax here is for the terminator itself.
# The actual value of the <heredoc terminator> lexeme will
# the heredoc, which will be provided by the external heredoc scanner.
<heredoc terminator>         ~ [\w]+

# Only discard horizontal whitespace. If "\n" is included the parser won't
# pause at the end of line.

:discard        ~ ws
ws              ~ [ \t]+

GRAMMAR
    });

    my $self = {
        grammar => $grammar,
    };

    return bless $self, $class;
}

sub parse {
    my ( $self, $input ) = @_;

    my $re = Marpa::R2::Scanless::R->new( { grammar => $self->{grammar} } );

    # Start the parse
    my $pos = $re->read( \$input );
    die "error" if $pos < 0;

    my $last_heredoc_end;

    # Loop while the parse has't moved past the end
    PARSE_SEGMENT: while ( $pos < length $input ) {

        my $lexeme = $re->pause_lexeme();
        my ( $start_of_pause_lexeme, $length_of_pause_lexeme ) =
            $re->pause_span();
        my $end_of_pause_lexeme = $start_of_pause_lexeme + $length_of_pause_lexeme;

        if ( $re->pause_lexeme() eq 'newline' ) {

            # Resume from the end of the last heredoc, if there
            # was one.  Otherwise just resume at the start of the
            # next line.
            $pos = $re->resume( $last_heredoc_end // $end_of_pause_lexeme );
            $last_heredoc_end = undef;
            next PARSE_SEGMENT;
        } ## end if ( $re->pause_lexeme() eq 'newline' )

        # If we are here, the pause lexeme was <heredoc terminator>

        # Find the <heredoc terminator>
        my $terminator = $re->literal($start_of_pause_lexeme, $length_of_pause_lexeme);

        my $heredoc_start = $last_heredoc_end
            // ( index( $input, "\n", $pos ) + 1 );

        # Find the literal text between the end of the last heredoc
	# and the heredoc terminator for this heredoc
        pos $input = $heredoc_start;
        my ($literal) = ( $input =~ m/\G(.*)^$terminator\n/gmsc );
        die "Heredoc terminator $terminator not found before end of input"
            if not defined $literal;

        # Pass the heredoc to the parser as the value of <heredoc terminator>
        $re->lexeme_read( 'heredoc terminator', $heredoc_start, length($literal),
            $literal ) // die $re->show_progress;

        # Save of the position of the end of the match
        # The next heredoc literal starts there if there is one
        $last_heredoc_end = pos $input;

        # Resume parsing from the end of the <heredoc terminator> lexeme
        $pos = $re->resume($end_of_pause_lexeme);

    } ## end PARSE_SEGMENT: while ( $pos < length $input )

    my $v = $re->value;
    return $$v;
} ## end sub parse

1;
