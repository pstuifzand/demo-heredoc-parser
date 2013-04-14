package Demo::Heredoc::Parser;
use 5.10.0;
use Marpa::R2 '2.051_009';
use Data::Dumper;

sub new {
    my $class = shift;
    my $grammar = Marpa::R2::Scanless::G->new({
        default_action => '::array',

        source => \<<'GRAMMAR',
:start        ::= file

file          ::= heredoc

heredoc       ::= var ('=' marker name) literal (name)

:lexeme         ~ marker pause => after
:lexeme         ~ literal

marker          ~ '<<'
name            ~ [A-Z]+
var             ~ [a-z]+
literal         ~ [.]

:discard   ~ ws
ws         ~ [\s]+

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
    die if $pos < 0;

    if ($pos < length $input) {
        pos($input) = $pos;
        my ($name) = $input =~ m/\G(\w+);\n/gc;
        my $s = pos($input);
        $re->lexeme_read('name', $pos, length($name), $name) // die;
        my ($literal) = $input =~ m/\G(.+)^$name\n/gmsc;
        $re->lexeme_read('literal', $s, length($literal), $literal) // die $re->show_progress;
        $re->lexeme_read('name', pos($input)-length($name)-1, length($name), $name) // die $re->show_progress;
        $re->resume(pos($input));
    }

    my $v = $re->value;
    return $$v;
}

1;
