use Test::More;

BEGIN { use_ok('Example')}
use Devel::Peek;

is(Example::hello2(), "Hello, World!\n");
is(Example::hello3('World'), "Hello, World!\n");
is(Example::hello5('World'), "Hello, World!\n");
is(Example::hello4("\0World"), "Hello, \0World!\n");

is_deeply([Example::numbers1()], [17,42,4711]);
is_deeply([Example::numbers2()], [17,42,4711]);

is(Example::sumthese(1,2,3), 6);

is_deeply([Example::lengths1("foo", "bar", "gazonk", 17)], [16,16,16,0]);

done_testing;