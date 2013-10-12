use Test::More;

BEGIN { use_ok('Example')}

is(Example::hello2(), "Hello, World!\n");
is(Example::hello3('World'), "Hello, World!\n");

done_testing;