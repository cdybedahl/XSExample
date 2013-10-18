# Introduction

Recently, I for the first time found myself needing to access a C library from Perl. Or, rather, I needed to access one for which I couldn't already find an interface module on CPAN. It probably says something about CPAN that I've been using Perl for over twenty years, eight of them professionally, before that happened. But in the end it did. So, armed with a good knowledge of Perl, a very basic knowledge of C and a nearly non-existent knowledge of Perl's XS interface system, I set out to write the glue myself. I knew that the `h2xs` script that I've used many times to create skeletons for new Perl module distributions is actually supposed to look at a C header file and auto-generate XS glue for it, so that's where I started. I aimed `h2xs` at the suitable header file and let it rip.

This resulted in something that didn't even compile, and which I had no idea how to fix. Or how to use, had I managed to make it run. Clearly, I didn't know enough to use that tool. I turned to the documentation, both that included with Perl and what I could find on the net. And yes, eventually I got something that worked. But it was irritatingly slow going. Perl's own documentation in this area, while pretty good, suffers from the too-common problem where every part of the documentation assumes you already know what's in all the other parts. Which makes it pretty hard to get started. As for what I found on the net, too much of it focused on how to wrangle h2xs, SWIG and similar tools into producing something that runs. But I soon realised that I didn't want that. Even if I got them to work, they'd produce interfaces that were raw translations of the C interfaces to Perl -- which works, but usually makes said interface feel awkward and un-Perlish. I wanted an interface that felt Perl-ish. Also, I wanted to understand what was going on under the hood, since that makes it extremely much easier to find and fix problems.

As of the time of writing, I have my interface about half done, without using any kind of templating or scaffolding tools. The hard parts are finished, and what remains is semi-mechanical work that only takes time. I also think I understand reasonably well what's going on. So, guessing that there will be other people out there in the same situation as me, I thought I'd write down what I've learned, in the hope of shorting the journey for them. And also, as always, in the hope that those wiser and more knowledgeable than myself may read and tell me about the tings I've misunderstood.

# Prerequisites

This text is written and the examples tested on machines running MacOS X Mountain Lion, using Perl version 5.18.1. Everything _should_ work the same on any Unix-like operating system and with Perls back to about 5.10 or so, but I haven't bothered to verify that. If you're on Windows, VMS, z/OS or something like that, I hope you know enough to translate the instructions to those yourself. I'll also assume that you have your environment set up to the point where you can download a C-based module from CPAN and successfully compile, test and install it.

The text also assumes that you are competent and comfortable with Perl, have a basic knowledge of C and know that "XS" has something to do with gluing Perl and C together.

# The very basics

Let's start at the very beginning, with an empty directory. I've called mine "XSExample". You can call yours whatever you like. If you intend to use revision control, this is probably a good point to do `git init` or similar. Anyway. In order to compile C extensions and interface them with Perl, we need a standard Perl module framework. So let's build the simplest one we can. Which takes two files, one of them in a subdirectory. First, the Perl module. Let's call it `Example`. It lives, of course, in `lib/Example.pm`, and the minimum contents are as follows:

```perl
    package Example;
    
    1;
```

On the top level we need a `Makefile.PL`. It's not very complicated either.

```perl
    use ExtUtils::MakeMaker;
    
    WriteMakefile(
        NAME => 'Example',
        VERSION => '0.1',
    );
```

There. Now you can do `make; make test; make install`. Sure, the test stage will only say that no tests are defined and the module doesn't actually do anything at all, but you can. It's a valid module, and it can be installed. It's a safe, comfortable starting point. Let's move on and put in the stuff we need to make C code callable from Perl. First, we need to expand on `Example.pm` a bit, so it looks like this:

```perl
    package Example;
    
    require XSLoader;
    XSLoader::load();
    
    1;
```

`XSLoader` was added to core in Perl version 5.6.0, by the way. If you want your module to work on Perls older than that, you're seriously on your own. You'll probably want to start by reading the docs for `DynaLoader`.

Now it's time to add the file where the actual Perl/C glue is going to live. Well, the main parts of it, anyway. It should be at the top level (as long as we're using `MakeMaker`, at least) and be named the same as the module, but with the suffix `.xs` instead of `.pm`. So, in our case `Example.xs`. It should start with these lines:

```
    #include "EXTERN.h"
    #include "perl.h"
    #include "XSUB.h"

    #include "ppport.h"

    MODULE = Example            PACKAGE = Example
```

The first three includes are files that live in the Perl installation. I haven't even tried to figure out what is in which one. All the documentation and all the examples I've been able to find always include all three of them, so let's just follow the trend there. The line with `MODULE` and `PACKAGE` marks the beginning of XS code (what's before is plain C), and also tells the `xsubpp` preprocessor which Perl package the following C functions should live in.

`ppport.h` is a bit special. _Really_ special, it turns out. It holds compatibility code for many different versions of Perl. Exactly what's in it may affect how you write your glue code, so you write your code with a particular copy of this file in mind. Given that, it cannot live in the Perl installation. Instead, you copy it to your module. Or, rather, you run a short Perl script that writes it for you. So run this:

    perl -MDevel::PPPort -E 'Devel::PPPort::WriteFile()'

There. Now you have a file called `ppport.h`. So far, so good. Now try this:

    perl ppport.h --help

Yes, that C header file is also a Perl script. Who came up with _that_ idea, I don't know. It's a script that'll look through your `.xs` file and suggest changes that'll make your code more compatible between Perl versions. Which is certainly useful, it's just not the world's most intuitive place to put a tool. In my opinion, at least.

Anyway, at this point you should be able to do `perl Makefile.PL && make` and see messages from the C compiler. Successful ones, hopefully. On my machine it produces an object file `Example.bs` that's zero bytes long. Which makes sense, since it doesn't actually have any functions. So let's add one. Below the `MODULE` line, add this:

```
    void
    hello1()
        CODE:
            printf("Hello, world!\n");
```

Run `make` again, and this time you should get an end result with some content. Even better, you should be able to run it, like this:

    perl -MExtUtils::testlib -MExample -E 'Example::hello1()'

Yay! An insanely complicated way of printing a string! And also a demonstration that it doesn't actually have to be all that complicated to call C code from Perl. This handful of lines is all you need to create a Perl module that dynamically loads code compiled from C, and runs it on request. Sure, it's not very useful C code. Particularly, it doesn't transfer any kind of information between itself and Perl. So let's talk about doing that next.

# Passing arguments, part 1

Let's begin by returning a string from our C function, so Perl can print it. In order to do that, we need to specify in our XS code what it is we're returning and where it comes from. Let's make it a whole new function, and add this to the bottom of `Example.xs`:

```
    char *
    hello2()
        CODE:
            RETVAL = "Hello, World!\n";
        OUTPUT:
            RETVAL
```

There. The first line, `char *`, says that our code returns a pointer to char. The `void` we used before meant, of course, that we didn't return anything. `RETVAL` is slightly magical, in that it is an easy way to return a single item from an XS function. A shortcut, you could say. We'll look at other ways of returning things to the Perl level later on. As you may already have suspected, passing information between the Perl level and the C level is where all the really complicated stuff is. Anyway, here we say that we return a pointer to `char` (that is, a C string) via `RETVAL`. Pretty straightforward. We could now run it the same way as before, but that gets tedious, so let's write a test instead. Add a file `t/00-example.t` (the directory name and the suffix are the only special parts of the name, but you knew that). Put this in the file:

```perl
    use Test::More;
    
    BEGIN { use_ok('Example')}
    
    is(Example::hello2(), "Hello, World!\n");
    
    done_testing;
```

There. Now you can do `perl Makefile.PL && make test`, and hopefully get told that everything works as expected. If not, you get to figure out what went wrong. Once it works, let's proceed to a full string round trip. Add this to the XS file:

```
    char *
    hello3(str)
        char *str;
        CODE:
        {
            char *buf = calloc(10+strlen(str),sizeof(char));
            sprintf(buf, "Hello, %s!\n", str);
            RETVAL = buf;
        }
        OUTPUT:
            RETVAL
```

And a test to `00-example.t` (before `done_testing;`, obviously):

    is(Example::hello3("World"), "Hello, World!\n");

Much is still the same. The main differences are that we now have an input parameter, and more than one line in the `CODE:` section. The input parameter is pretty straightforward, it's more or less plain old C. The same goes for the extra content in `CODE:`. The braces are stricly not necessary, but putting them in guarantees that the code is in a context where you can legally declare variables. So now we can give a string to our C function, and get another one back. All is good. Let's put in one more test just to make really sure:

    is(Example::hello3("\0World"), "Hello, \0World!\n");

We run this -- and it blows up. Which isn't so strange, once you think about it. We use `strlen()` to get the length of the incoming string, and that function counts characters until it runs into a null byte. Like the one we just put at the beginning of the string we sent as an argument. So, yes, that doesn't work. But Perl in general has no problem dealing with strings with null bytes in them. So what's going on here, really?

# Typemaps and SVs

What's going on is, obviously, that Perl doesn't work with C strings internally. Here is a version of `hello3()` (cleverly called `hello4()`) that uses Perl's native string representation. If you add it to the XS file and change the failing test to call `hello4()` instead of `hello3()`, the tests should start passing again.

```
    SV *
    hello4(str)
        SV *str;
        CODE:
        {
            SV *buf = newSVpvs("Hello, ");
            sv_catpvn(buf, SvPV_nolen(str), SvCUR(str));
            sv_catpvs(buf, "!\n");
            RETVAL = buf;
        }
        OUTPUT:
            RETVAL
```

You recognize the overall structure, I hope. There's the return type, the function name, the input parameter name and type, the `CODE:` bit and the `OUTPUT:` bit that still uses `RETVAL`. But the rest is different. The parameter and return types are pointers to something called an `SV`, and the code seems to be functions operating on things with names including "SV" and "PV". "SV", in this context, stands for "Scalar Value". As the name hints, they are what perl uses to store scalar values. Since scalar values can be several different kinds of things, there are several subtypes of `SV`s. There are `SViv`, for integers. `SVnv` for floating point values. `SVrv` for references. And, as used here, `SVpv` for strings ("pv" is for "pointer value"). So `hello4()` here gets handed a scalar value. It then creates a new scalar value, of the string subtype, based on the C constant string `"Hello, "`. It then concatenates the input string onto the end of that, tacks the static string `"!\n"` on at the end and finally returns the result to the caller. The functions (or sometimes macros) used, `newSVpvs()`, `sv_catpvn()`, `SvPV_nolen()`, `SvCUR()` and `sv_catpvs()`, I found by reading the `perlapi` documentation page. It's organized for reference rather than introduction, but it does document the public C-level API to Perl, so if you're going to do something serious with XS you'd better get used to searching for stuff in it. It's not that hard to understand, once you get used to the basic terminology. Using these functions to do things isn't all that different from working at the Perl level, except you have to care about a _lot_ more detail.

"But wait," you say now, since you're a clever reader. "If Perl works on SVs internally, how come we could work with ordinary char pointers before?"

The answer is, quite obviously, that there was conversion going on. One of the major things the XS layer does is convert between Perl data types and whatever weird kind of stuff the C level uses at the moment. In order to do that, it uses _typemaps_. Typemaps are conceptually quite simple, although if you look at what some common modules on CPAN use it's obvious that they can get very complicated indeed. But basically, a typemap has three parts. One part that connects a C-level declaration to a label, one part that specifies how stuff with a certain label should be converted from C to Perl and a third part that specifies how stuff with a certain label should be converted from Perl to C. A bunch of declarations like this for the basic C data types come with Perl. So let's have a look. Bring up a shell window and run `perldoc -m ExtUtils::typemap`. What you see is the actual `typemap` file that's been used every time you've run a compile while reading this article.

The first part is pretty straightforward, and makes it rather obvious why the translation takes the way via a label instead of specifying direct translation between C types and Perl types: a lot of C types map to the same Perl type. Perl has strings. C has at least `char *`, `unsigned char *` and `const char *`. As you can see in the file, all those three map to the label `T_PV`.

The next part (under the line of hash marks) is called `INPUT`. Those are the rules for going from Perl values to C values. If you search down a bit, you'll eventually find an entry that looks like this:

```
    T_PV
        $var = ($type)SvPV_nolen($arg)
```

Without even knowing the exact rules for typemaps, we can guess how that works. In order to assign an argument to a C variable, XS runs `SvPV_nolen()` on the argument and typecasts the result to the exact type variant wanted at the C level. So that's how the Perl string "Hello" in our test code got converted to the corresponding C string that the function `hello3()` wanted. If we keep reading down the typemap file, we soon come to the last section, naturally enough called `OUTPUT`. In that section, we can find this:

```
    T_PV
        sv_setpv((SV*)$arg, $var);
```

Looking up `sv_setpv()` in `perlapi`, we see that it simply copies a nul-terminated string pointed at by its second argument into an `SvPV` pointed at by its first argument. So that's how the C string `buf` in `hello3()` gets converted to a Perl string that `Test::More` can use. Conceptually, both the input and output stages are quite straighforward and easy to understand. It's just that, as always with C, there are a vast amount of details that must be exactly right (and we haven't even mentioned memory management yet). But for the moment, we have at least a basic grasp of what's going on.

# Returning a list

C functions can only return a single value. Perl functions frequently return several. So a fair part of turning a C-like interface into a Perl-like interface will be turning C's "send a pointer for the function to put stuff in" interfaces into Perl's "send and return lists" interfaces. Which makes it useful to know how to write an XSUB (that is, an XS function like the ones we've been working with so far) that builds and returns a list.

At this point, you may think "Hey, that's easy! I read perlapi and saw all those functions dealing with AVs, I'll just make one of those and return it!". Which makes sense. Unfortunately, it's dead wrong. You don't notice it much while working at the Perl level, but there is a difference between lists and arrays, and when we're digging around down here we notice it a lot. There are functions and macros that deal with AV (Array Value) objects and HV (Hash Value) objects, but what we return from a function is a list, not an array. If you try returning an AV, you'll find that the standard typemap wraps it in an RV (Reference Value), and what you get in your Perl code is a reference to the array you built. Which is useful, but not what we want here.

So what do we do here? Well, conceptually it's simple. We put stuff on the return stack. Which is actually what the RETVAL magic does too, except it always puts a single value there. If we want to return more than one value, we have to forego the magic and do the work ourselves. To help us do that, there are a number of macros. To see some of them in action, let's build a function that returns a list of three numbers.

```
    SV *
    numbers1()
        PPCODE:
            mXPUSHi(17);
            mXPUSHi(42);
            mXPUSHi(4711);
```

Looks easy enough, doesn't it? We recognize the basic structure, even if most of the detail is as yet unfamiliar. Let's go through them bit by bit. The `SV *` return code is recommended by the documentation for the cases where we're returning something that's not a simple C type, so that's what we use here. There used to be a recommendation to use `void`, but apparently that caused problems for some combination of operating systems, C compilers and such. `numbers1()` gives the function its name and declares that it takes no arguments, as we've seen before. `PPCODE` is new. Basically, it says that we'll be handling putting things on the return stack ourselves. With the `CODE` we've used so far, there can only be zero or one returned value, and it's handled via `RETVAL`. With `PPCODE`, there can be any number (including zero), but we have to put them onto the stack ourselves, and also make sure that the stack has enough room for them. Which brings us to the most complicated bit of this explanation: `mXPUSHi()`. This is one of a large number of related macros with fairly logically made-up names. The central bit is "PUSH", which describes what's being done: pushing something onto the return stack. The final "i" says that what we're pusing is an integer. The "X" says that the stack will be automatically extended to make room for the push, if needed. I don't know what the "m" is supposed to be mnemonic for, but its meaning is basically to make sure to use a freshly created `SV` to store the data. Without the "m", the system may elect to reuse a spare `SV` it has lying around. Which is bad, since what gets stored is really the C pointer to the `SV`, so if the same one gets reused more than once on the same stack the later values will overwrite the earlier ones. Which would be bad.

So. What we do when we say `mXPUSHi(17)` is to create a new `SV`, store an `IV` (that is, Integer Value) with the value 17 in it, make the `SV` mortal, make sure there's a free spot on the stack, and then put the address of the `SV` on the stack. Easy to use, although a lot happens behind the scenes when you use it. As mentioned, there are lots of `PUSH` variants. They're all listed in perlapi. There you can also find macros to manually extend the stack by a given number of entries, and ways of accessing those entries directly. The example above is not even close to being the only way you can put three numbers on the return stack.

And at this point you should, if you've been paying attention, be wondering what the frak "make the `SV` mortal" means.

# The lifecycle of `SV`s

This is where we finally get into Perl's memory management. As you are probably aware, Perl uses [reference-counting garbage collection](https://en.wikipedia.org/wiki/Garbage_collection_%28computer_science%29#Reference_counting). This works transparently (mostly) at the Perl level, where perl itself is creating and destroying your objects. But now we are creating and destroying things outside its control. So we need to take care to get the reference counts right.

Oh, and we need to take care of memory we allocate ourselves too, of course. Go back and have a look at our `hello3()` example. See how we do a `calloc()` but no `free()`? Yeah, that code leaks memory. The standard typemap for `char *` uses `sv_setpv()` when it converts from C to Perl, and that functions copies the C string into an `SV`, after which it doesn't touch the C string again. So we need to free it ourselves -- but not until perl has copied it. In order to do that, we need to introduce a new XSUB section:

```
    char *
    hello5(str)
        char *str;
        CODE:
            char *buf = calloc(10+strlen(str),sizeof(char));
            sprintf(buf, "Hello, %s!\n", str);
            RETVAL = buf;
        OUTPUT:
            RETVAL
        CLEANUP:
            Safefree(buf);
```

Most of that is intact from before. The difference is that the braces enclosing the `CODE` section are gone, and a `CLEANUP` section is added. The braces had to go in order to make the `buf` variable visible in the `CLEANUP` section, so it can be freed there (by the way, read about `PREINIT` in the perlxs documentation page to see how to solve the problem of having to declare variables early enough in the code). `Safefree()` is a utility function perl provides to hide all the quirks of `free()` in all the different environments where Perl can run. It's documented in the perlclib documentation page, along with its many siblings. We shouldn't really have used a raw `calloc()` like that, for example. Fixing that is left as an exercise for the reader.

Anyway. Reference counts. All perl values have one. When you create something it usually gets its reference count set to 1, on the assupmtion that you want to keep it around for a bit. Earlier, in `hello4()`, we used `newSVpvs()` to create an `SV` holding a string, for example. That started out with a reference count of 1, which we never changed. It got returned to, in our case, the test script, where it was compared to a another string and never used again. Which also sounds like a memory leak, doesn't it? Our `SV` started out with a reference count of 1, nothing ever decreased it, and so it'll never get garbage collected. But if we decrement the reference count of it in our function (using `SvREFCNT_dec()`), not only doesn't it work as intended, the perl interpreter actually crashes! What to do?

The answer is actually "nothing". The code is correct as given. One part of the reason why is another bit of `RETVAL` magic. If you use `RETVAL` to return an `SV`, that `SV` will automatically be marked as _mortal_. The other part of the reason why is the concept of mortal values. Marking a value as mortal tells perl that you don't really care about the value, but you need it to hang around just a little longer. Long enough for it to be returned to the caller and used in a comparison, say. Or returned and being assigned to a varaible. In which case its reference count would first be increased to 2 at the assignment, and then decreased to 1 again whenever the mortality kicked in (and eventually zero when the variable it was assigned to goes out of scope). Exactly when it does kick in is deliberately not specified. All you as the programmer know is that it will happen [soon](http://www.wowwiki.com/Soon).

Anyway. In `hello4()` the mortality was handled by the `RETVAL` magic. In `numbers1()`, it's handled by the `mXPUSHi()` macro. In general, if you're using a function or macro that creates `SV`s for you as a part of doing something else, it'll probably also mark them as mortal. But if you create one specifically, you have to mark it as mortal yourself. Here's an alternative way of returning a list of three numbers:

```
    SV *
    numbers2()
        PPCODE:
            EXTEND(SP,3);
            ST(0) = sv_2mortal(newSViv(17));
            ST(1) = sv_2mortal(newSViv(42));
            ST(2) = sv_2mortal(newSViv(4711));
            XSRETURN(3);
```

At this point you could probably just look up the various functions in perlapi and figure out how this works, but let's talk it through anyway. `EXTEND` is a macro that makes sure there's enough space on the stack. When I try it, the code still seems to work fine without that line, but the way the documentation is worded makes me think that it _may_ work without the `EXTEND`, but that it _will_ work with it. So I left it in. `ST()` is a macro used to access stack entries. Here we use it to put `SV`s on the stack. `sv_2mortal()` does exactly what it says on the label, it turns an `SV` mortal. `newSViv()` creates a fresh new SV holding an IV, and finally `XSRETURN()` returns from the function with three things on the return stack. If the number you give here is less than the number of things you've put on the stack, some things will get lost. If the number you give here is greater than the number of things you put on the stack, whatever garbage was in the extra memory locations will be returned. Which may, depending on circumstances and luck, cause garbage data in your program, your program crashing, the perl interpreter crashing or an exploitable security hole. So make sure to get that number right. Or use the `PUSH` macros, which keep count for you.

# Passing arguments, part 2

Now that we've started looking at the stack, we can also look at the other end of functions returning multiple values. That is, calling them with multiple values. For a fixed number of arguments, it's really easy: just list them at the beginning.

```
    long
    sumthese(one, two, three)
        long one;
        long two;
        long three;
        CODE:
            RETVAL = one+two+three;
        OUTPUT:
            RETVAL
```

Exercise for the interested reader: what actually happens if you call this from Perl with values that aren't `long`s? Not just what result you get, but what happens along the way to get you that result?

OK, now we can do that. But in Perl it's common with functions that can take a variable number of arguments. _Very_ common, actually. In a way all of them always do, and the sort of limit we've imposed so far is the aberration. So we'd better figure out how to make the variable thing happen at the C level. Fortunately, it's not that hard. We put `...` (that is, literal three period characters) in the argument list after the function name, after any mandatory arguments. Once we've done that, we get a magically created integer variable called `items` that says how many arguments were really passed (including the mandatory ones). We can then pick them off the stack. Here's an example, that provides the highly useful (under extremely limited circumstances) service of telling you how much space has been allocated for string storage for the values it recieves as arguments. It does this by returning a list of values, each corresponding to a provided argument.

```
    SV *
    lengths1(...)
        PPCODE:
            int i;
            for(i=0;i<items;i++)
            {
                if(SvPOK(ST(i)))
                {
                    size_t len = SvLEN(ST(i));
                    mXPUSHi(len);
                }
                else
                {
                    mXPUSHi(0);
                }
            }
```

There are two noteworthy things here. The use of an intermediate variable for the length, and the `SvPOK()` macro.

The intermediate value is needed because there is only one stack. The incoming arguments are in the same place the outgoing results will be put in. So using `ST(i)` to read from a stack slot while writing to the same slot with `mXPUSHi()` is unlikely to work well. On my machine, it causes a core dump, even. So we read first, remember what we read, and then store a result.

`SvPOK()` is used here to check that the `SV` we're getting the string storage size for actually has a string value. We haven't needed to do that sort of check before, since with named arguments we have had typemaps to force the Perl values into what we asked for. But now that we're picking things straight off the stack (and we never told Perl what we want in the first place), we need to check ourselves that the values make sense for our needs. As you may already have seen in perlapi, there is a large variety of different macros for this. Some of them simply check, like the one we use here. Others actually force the value to be converted to what we need (which sometimes can result in a loss of information, so be careful). Anyway, here we simply check if the `SV` is valid as a string, and if it is we add an `SvIV` with the length of the string buffer to the stack. If it's not valid as a string, we assume that it never had a string buffer allocated and push a zero value.

If you haven't figured out the exercise for the reader after the previous example, you can get a hint from this one by adding a mandatory first argument of type `char *`, call it with a series of numbers and watch the results.

So now we can both accept and return variable numbers of arguments. Sweet! We're done! ...or maybe not quite. We haven't looked at actual arrays yet. Or hashes. Or references. Or, perhaps most interesting, objects. Actually, let's do objects next.

# Orienting Objects

A perl object is simply a reference that's been associated with a package. A method is nothing more than a function that expects such a reference as its first argument. And, as it turns out, we can set up an `SV` to hold a C pointer. Which makes no sense at the Perl level, but at the XS level we're talking about here it means that Perl objects can be C data structures. This is entirely intentional on behalf of the Perl developers. The `xsubpp` preprocessor and the standard typemap will both help us do it. So let's have a go at it. Let's make one of the standard example classes from nearly all OO literature ever: a point in a Cartesian coordinate system.

Also, just because we're lazy, let's squeeze it into the `Example` module we're already using. We begin by adding the C data type we need to represent our points. _Above_ the `MODULE` keyword in `Example.xs`, add these declarations.

```
    typedef struct {
        double x;
        double y;
    } point;
    
    typedef point *Example;
```

So that is a struct called `point`, with two floating point members called `x` and `y`, plus a data type `Example` that's a pointer to a `point`. The next thing we'll do is to tell `xsubpp` what to do when it sees `Example` in an XSUB declaration. The way we do that is with a typemap entry. Since this is the first time we'll be using one of those beyond the standard ones that come with Perl, the first thing we need to do is to create a new file called, imaginatively enough, `typemap`. In that file, put this single line:

```
    Example     T_PTROBJ
```

You can look up `T_PTROBJ` in the standard typemap (`perldoc -m ExtUtils::typemap`, if you don't remember the easy way to look at it) to see what will happen when going between the Perl and C worlds via the `Example` route. The input section is pretty scary, and I by no means understand all of it, but it's pretty clear that it checks that the reference value looks sane and then converts it to a C pointer. The output direction is much simpler, it just uses the `sv_setref_pv()` function to wrap the pointer in an `SV` and an `RV` and blesses the `RV` into the package with the same name as the datatype. That is why we have the second `typedef` above, by the way. If we hadn't put it in, `xsubpp` would've auto-generated a name from the C data type (`point *`) and the object would have ended up blessed into the class `pointPtr`.

So far so good. The next thing we need is a constructor. Traditionally, that's a class method called `new`. Let's go with that.

```
    Example
    new(class,xval,yval)
        char *class;
        double xval;
        double yval;
        CODE:
        {
            Example obj;
    
            Newx(self, 1, point);
            self->x = xval;
            self->y = yval;
            RETVAL = self;
        }
        OUTPUT:
            RETVAL
```

There is really nothing strange here. The only new bit is `Newx()`, and that's simply the recommended wrapper for `malloc()`. To check that this works as intended, let's add a couple of lines to `t/00-example.t`. Which I have been adding things to along the way, I've just been too lazy to mention them here. Anyway.

```
    my $obj = Example->new(1.0,2.0);
    isa_ok($obj, 'Example');
```

Compile, run tests and it should work beautifully. We have a Perl object implemented as a C struct! Let's add a method. Or methods, even. Setters and getters seems like obvious things to want to have.

```
    double
    get_x(self)
        Example self;
        CODE:
            RETVAL = self->x;
        OUTPUT:
            RETVAL
    
    double
    get_y(self)
        Example self;
        CODE:
            RETVAL = self->y;
        OUTPUT:
            RETVAL
    
    void
    set_x(self, xval)
        Example self;
        double xval;
        CODE:
            self->x = xval;
    
    void
    set_y(self, yval)
        Example self;
        double yval;
        CODE:
            self->y = yval;
```

Let's mention the tests this time:

```
    is($obj->get_x, 1.0);
    is($obj->get_y, 2.0);
    $obj->set_x(0);
    $obj->set_y(0);
    is($obj->get_x, 0.0);
    is($obj->get_y, 0.0);
```

And at least when I run it, it works. I don't think there's all that much to say about these functions. They're exactly like ones we've seen before, except they use the normal Perl object calling convention with the pointer to the object as the first argument, and that argument has the `Example` type.

# Hashes and arrays

I guess we should say something about those as well, although honestly for the things I've been doing with XS I've had surprisingly little use for them. It may be that once you feel the need to descend below the level that Perl itself can provide, you've already gone outside the bounds of what Perl arrays and hashes are really good for. The main thing that can be usefully done with hashes and arrays at the C level is, I think, to create them, fill them with something and pass references to them up to the Perl level for later use there (but note that we already passed lists back to Perl, and passing simple hashes is a special case of that with alternating keys and values).

So. Anyway. The reference bit we don't have to think about that much, since the standard typemap takes care of creating them when we declare functions as returning pointers to `HV`s or `AV`s. Let's write a method for the `Example` class that returns a reference to a hash with the contents of the object (that is, keys `x` and `y` with corresponding values).

```
    HV *
    attributes(self)
        Example self;
        CODE:
        {
            HV *hash = newHV();
            SV **result;
            result = hv_stores(hash, "x", newSVnv(self->x));
            if (result == NULL)
            {
                croak("Storing value %f to key x failed", self->x);
            }
            result = hv_stores(hash, "y", newSVnv(self->y));
            if (result == NULL)
            {
                croak("Storing value %f to key y failed", self->y);
            }
            RETVAL = hash;
        }
        OUTPUT:
            RETVAL
```

Add your own tests. Something like `ok(exists $obj->attributes->{"x"})`, maybe. Anyway, most of that function should be obvious. `newHV()` we haven't seen before, but it's pretty self-explanatory. `hv_stores()`, on the other hand, merits some talking about. It's one of three macros listed in perlapi that stores things in an `HV`. The main difference between them is how the hash key is specified. `hv_stores()` has the simplest possible case, in that it uses a C string constant. The other two variants, `hv_store()` and `hv_store_ent()`, use respectively a C string pointer with its length (as two separate arguments) and an `SV` to specify the key. Both of them also take a precomputed hash value as their final argument. If that argument is 0, perl will calculate the hash value. All three of them "take over" one reference count. You may have noted that in the example above we create new `SV`s to hold the values, but we don't make them mortal or otherwise reduce their reference count. The `hv_store_` macros are set up to take ownership of already existing reference counts precisely to make the kind of case we have here require less code. This does, however, have the consequence that if the storage operation fails, _then_ we should decrement the reference count. The main cause of that happening is storing things in tied hashes (or arrays), so since we create our own very tiny hash here I chose to ignore that problem in favour of making the example shorter and easier to understand. But the code above would leak an `SV` every time it failed to store it.

There are plenty of other macros and functions that do things to or with `HV`s, but you can read about those yourself in perlapi.

For completeness sake, here's an example returning a reference to an array with the object's values.

```
    AV *
    value_aref(self)
        Example self;
        CODE:
        {
            AV *ary = newAV();
            SV **result;
            result = av_store(ary, 0, newSVnv(self->x));
            if (result == NULL)
            {
                croak("Storing value %f to position 0 failed", self->x);
            }
            result = av_store(ary, 1, newSVnv(self->y));
            if (result == NULL)
            {
                croak("Storing value %f to position 1 failed", self->y);
            }
            RETVAL = ary;
        }
        OUTPUT:
            RETVAL
```

Note the vast difference from the previous example. Or not. `av_store()` works exactly like the `hv_store_*` macros, except that it takes an integer as the key and only has one variant (so if you have an `SV` holding the key, you need to use `SvIV()` to extract it). Reference counts are handled the same as for `HV`s as well, so this example also leaks memory when storing fails.

# Odds and Ends

There are a couple more data types that I feel I should mention, although I won't try to come up with examples for them. But it should make reading the actual documentation easier if you have some idea what they are.

A `CV` is a Code Value. That is, what a code reference at the Perl level is pointing at. Doing something useful with these requires more knowledge of perl's internals than I currently possess, so I can't say anything about them.

A `GV` is a Glob Value. That is, it's a typeglob. You shouldn't encounter those unless you're accessing actual Perl-level variables. in which case, I hope you've read far more documentation than just this document.

Perl comes with a lot of documentation. The parts of it that talk about perl's internals and how to interface to them from C are fairly hard to get into, since they suffer from what someone called "Unix-style documentation syndrome". That is, every part assumes you've already read all the other parts. Which is fine for reference, but makes it quite forbidding for the newbie. After reading this document, I hope you have enough of a sense of how the lower levels of perl that the actual documentation will be less hard to understand. That said, you still probably will have to come back to some documentation over and over again in order to understand all of it. A useful reading order might be something like this:

perlapi
:       Skim this. A lot will be quite clear if you tried out the examples here, while other parts will be incomprehensible. You should still be able to get a sense of what can be done, and what goes on under the hood.

perlxstut
:       The XS tutorial that comes with Perl isn't bad, but it does have a very different aim than this document. It's primary goal seems to be to help the reader auto-generate as much as possible of a literal translation of a C API into Perl. This document has deliberately talked very little about using external C libraries, since I found that to be the easy part. You make sense of the incoming arguments, call the external function, then build something up with what you got back that makes sense to a Perl programmer.

perlxs
:       The actual specification of the XS language. There's more to it than I've used here.

perlclib
:       What you should be using instead of the old, familiar C functions. Do use them. Keep in mind that perl is written to run on dozens of Unix variants, Microsoft Windows, Digital (or, I guess, HP) VMS, IBM z/OS and others. You'd have to be a very peculiar sort of masochist to want to support all of those yourself.

perlxstypemap
:       More about typemaps. Documentation of the standard typemap entries.

perlguts
:       About perl's internals. Read until it feels like your brain is bleeding, then stop (it will happen, if not before so when you run into the Dread Pirate Unicode).

perlapi
:       Yes, again. After your battle with perlguts, more of it should make sense.

perlcall
:       How to call perl functions from your C code. Have a look.

Intersperse your reading with writing code. Experiment. Try things. Try to see how many ways you can find to make the perl interpreter crash. Have fun. At some point, start looking at the source to perl itself. Cry out in horror and run back to the safe, friendly perlapi page. Resolve to try again later.

That's it. So, good luck. Let us know how it all turns out, right? And if this helps you achieve world domination, I want a cut.