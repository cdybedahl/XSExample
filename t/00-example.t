use Test::More;

BEGIN { use_ok('Example')}
use Devel::Peek;

is(Example::hello2(), "Hello, World!\n");
is(Example::hello3('World'), "Hello, World!\n");
is(Example::hello5('World'), "Hello, World!\n");
is(Example::hello4("\0World"), "Hello, \0World!\n");

is_deeply([Example::numbers1()], [17,42,4711]);
is_deeply([Example::numbers2()], [17,42,4711]);

done_testing;