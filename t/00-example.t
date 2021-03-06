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

my $obj = Example->new(1.0,2.0);
isa_ok($obj, 'Example');
is($obj->get_x, 1.0);
is($obj->get_y, 2.0);
$obj->set_x(0);
$obj->set_y(0);
is($obj->get_x, 0.0);
is($obj->get_y, 0.0);
is($obj->x(17), 17.0);

is_deeply([ sort values( %{$obj->attributes} ) ], [ 0, 17 ]);
is_deeply( $obj->value_aref, [17,0]);

done_testing;