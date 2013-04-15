package Demo::Heredoc::Parser;
use 5.10.0;
use Marpa::R2 '2.051_009';
use Data::Dumper;

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

heredoc       ::= (marker) literal       action => ::first

# Pause at the marker and at newlines. Pausing at the newline will
# actually pause the parser at every newline
:lexeme         ~ marker     pause => before
:lexeme         ~ newline    pause => before

marker          ~ '<<'
semi_colon      ~ ';'
newline         ~ [\n]

# The literal lexeme will always be provided by the external heredoc scanner So
# this could be anything.

literal         ~ [.]

comma           ~ ','

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
    my ($self, $input) = @_;

    my $re = Marpa::R2::Scanless::R->new({ grammar => $self->{grammar} });

    # Start the parse
    my $pos = $re->read(\$input);
    die "error" if $pos < 0;

    my $last_heredoc_end;

    # Loop while the parse has't moved past the end
    while ($pos < length $input) {
        # Set pos of $input for \G
        pos($input) = $pos;

        # Find the end of the line
        $last_heredoc_end //= index($input, "\n", $pos) + 1;

        # Parse the start of a heredoc
        if (my ($name) = $input =~ m/\G<<(\w+)/msgc) {
            # Save the position where the heredoc marker ends
            my $last_parse_end = pos($input);

            # Set pos of $input to the end of the previous heredoc
            pos($input) = $last_heredoc_end;

            # Find the literal text between the end of the last heredoc and the marker
            if (my ($literal) = $input =~ m/\G(.*)^$name\n/gmsc) {
                # If found, pass the lexemes to the parser so it knows what we found
                $re->lexeme_read('marker', $pos, 2, '<<') // die $re->show_progress;
                $re->lexeme_read('literal', $last_heredoc_end, length($literal), $literal) // die $re->show_progress;

                # Save of the position of the end of the match
                # The next heredoc literal starts there if there is one
                $last_heredoc_end = pos($input);

                # Resume parsing from where we last paused
                $pos = $re->resume($last_parse_end);
            }
            else {
                die "Heredoc marker $name not found before end of input";
            }
        }
        # Match end of the line
        elsif ($input =~ m/\G$/gmsc) {
            # Cleanup for the next line with heredoc markers.
            my $p = $last_heredoc_end;
            undef $last_heredoc_end;

            # Resume from the end of the last heredoc.
            $pos = $re->resume($p);
        }
    }

    my $v = $re->value;
    return $$v;
}

1;
