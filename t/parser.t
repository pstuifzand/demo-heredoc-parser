use Test::More;
use Demo::Heredoc::Parser;

my $p = Demo::Heredoc::Parser->new;

my $v = $p->parse(<<"INPUT");
<<ENDA, <<ENDB, <<ENDC;
line 1
line 2
line 3
ENDA
line 4
line 5
ENDB
line 6
line 7
ENDC
INPUT

my $expected = [
    "line 1\nline 2\nline 3\n",
    "line 4\nline 5\n",
    "line 6\nline 7\n",
];
is_deeply($v, $expected);

done_testing();

