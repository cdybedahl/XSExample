use Test::More;

BEGIN { use_ok('Example')}

is(Example::hello2(), "Hello, World!\n");
is(Example::hello3('World'), "Hello, World!\n");
is(Example::hello4("\0World"), "Hello, \0World!\n");

my @foo = Example::arrayret();
diag explain \@foo;

done_testing;