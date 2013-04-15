use Test::More;
use Test::Exception;
use Demo::Heredoc::Parser;
use Data::Dumper;

my $p = Demo::Heredoc::Parser->new;

my $input = <<"INPUT";
say <<ENDA;
line 1
line 2
line 3
ENDD
INPUT

my $v = dies_ok { $p->parse($input) };

done_testing();

