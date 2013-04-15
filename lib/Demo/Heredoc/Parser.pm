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
statement     ::= expressions semi_colon action => ::first
                | newline

expressions   ::= expression+            separator => comma
expression    ::= heredoc                action => ::first
heredoc       ::= (marker) literal       action => ::first

:lexeme         ~ marker     pause => before
:lexeme         ~ newline    pause => before

marker          ~ '<<'
semi_colon      ~ ';'
newline         ~ [\n]
literal         ~ [.]
comma           ~ ','

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
    my %options = (
        #trace_values    => 1,
        #trace_terminals => 1,
    );

    my $re = Marpa::R2::Scanless::R->new({ %options, grammar => $self->{grammar} });
    my $pos = $re->read(\$input);
    die "error" if $pos < 0;

    my $last_heredoc_end;

    while ($pos < length $input) {
        pos($input) = $pos;

        $last_heredoc_end //= index($input, "\n", $pos) + 1;

        if (my ($name) = $input =~ m/\G<<(\w+)/msgc) {
            my $s = pos($input);
            pos($input) = $last_heredoc_end;
            my ($literal) = $input =~ m/\G(.+)^$name\n/gmsc;
            $re->lexeme_read('marker', $pos, 2, '<<') // die $re->show_progress;
            $re->lexeme_read('literal', $last_heredoc_end, length($literal), $literal) // die $re->show_progress;
            $last_heredoc_end = pos($input);
            $pos = $re->resume($s);
        }
        elsif ($input =~ m/\G\n/gmsc) {
            my $p = $last_heredoc_end;
            undef $last_heredoc_end;
            #$re->lexeme_read('newline', $pos, 0, "");
            $pos = $re->resume($p);
        }
    }

    my $v = $re->value;
    return $$v;
}

1;
