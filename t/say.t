use Test::More;
use Demo::Heredoc::Parser;
use Data::Dumper;

my $p = Demo::Heredoc::Parser->new;

my $v = $p->parse(<<"INPUT");
say <<ENDA, <<ENDB, <<ENDC; say <<ENDD;
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
line 8
line 9
ENDD
INPUT

my $expected = 
[
    [
        [
            'say', [
                "line 1\nline 2\nline 3\n",
                "line 4\nline 5\n",
                "line 6\nline 7\n",
            ],
        ],
    ],
    [
        [
            'say', [
                "line 8\nline 9\n",
            ],
        ],
    ]
];

is_deeply($v, $expected);

done_testing();

