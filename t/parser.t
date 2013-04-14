use Test::More;
use Demo::Heredoc::Parser;

my $p = Demo::Heredoc::Parser->new;

my $v = $p->parse(<<"INPUT");
x = <<END;
line 1
line 2
line 3
END
INPUT

my $expected = [
    [
        'x', "line 1\nline 2\nline 3\n",
    ],
];

is_deeply($v, $expected);

done_testing();

