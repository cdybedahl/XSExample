# Introduction

Recently, I for the first time found myself needing to access a C library from Perl. Or, rather, I needed to access one for which I couldn't already find an interface module on CPAN. It probably says something about CPAN that I've been using Perl for over twenty years, eight of them professionally, before that happened. But in the end it did. So, armed with a good knowledge of Perl, a very basic knowledge of C and a nearly non-existent knowledge of Perl's XS interface system, I set out to write the glue myself. I knew that the `h2xs` script that I've used many times to create skeletons for new Perl module distributions is actually supposed to look at a C header file and auto-generate XS glue for it, so that's where I started. I aimed `h2xs` at the suitable header file and let it rip.

This resulted in something that didn't even compile, and which I had no idea how to fix. Or how to use, had I managed to make it run. Clearly, I didn't know enough to use that tool. I turned to the documentation, both that included with Perl and what I could find on the net. And yes, eventually I got something that worked. But it was irritatingly slow going. Perl's own documentation in this are, while pretty good, suffers from the too-common problem where every part of the documentation assumes you already know what's in all the other parts. Which makes it pretty hard to get started. As for what I found on the net, too much of it focused on how to wrangle h2xs, SWIG and similar tools into producing something that runs. But I soon realised that I didn't want that. Even if I got them to work, they'd produce interfaces that were raw translations of the C interfaces to Perl -- which works, but usually makes said interface feel awkward and un-Perlish. I wanted an interface that felt Perl-ish. Also, I wanted to understand what was going on under the hood, since that makes it extremely much easier to find and fix problems.

As of the time of writing, I have my interface about half done, without using any kind of templating or scaffolding tools. The hard parts are finished, and what remains is semi-mechanical work that only takes time. I also think I understand reasonably well what's going on. So, guessing that there will be other people out there in the same situation as me, I thought I'd write down what I've learned, in the hope of shorting the journey for them. And also, as always, in the hope that those wiser and more knowledgeable than myself may read and tell me about the tings I've misunderstood.

# Prerequisites

This text is written and the examples tested on machines running MacOS X Mountain Lion, using Perl version 5.18.1. Everything _should_ work the same on any Unix-like operating system and with Perls back to about 5.10 or so, but I haven't bothered to verify that. If you're on Windows, VMS, z/OS or something like that, I hope you know enough to translate the instructions to those yourself. I'll also assume that you have your environment set up to the point where you can download a C-based module from CPAN and successfully compile, test and install it.

The text also assumes that you are competent and comfortable with Perl, have a basic knowledge of C and know that "XS" has something to do with gluing Perl and C together.

# The very basics

Let's start at the very beginning, with an empty directory. I've called mine "XSExample". You can call yours whatever you like. If you intend to use revision control, this is probably a good point to do `git init` or similar. Anyway. In order to compile C extensions and interface them with Perl, we need a standard Perl module framework. So let's build the simplest one we can. Which takes two files, one of them in a subdirectory. First, the Perl module. Let's call it `Example`. It lives, of course, in `lib/Example.pm`, and the minimum contents are as follows:

    package Example;
    
    1;

On the top level we need a `Makefile.PL`. It's not very complicated either.

    use ExtUtils::MakeMaker;
    
    WriteMakefile(
        NAME => 'Example',
        VERSION => '0.1',
    );

There. Now you can do `make; make test; make install`. Sure, the test stage will only say that no tests are defined and the module doesn't actually do anything at all, but you can. It's a valid module, and it can be installed. It's a safe, comfortable starting point. Let's move on and put in the stuff we need to make C code callable from Perl. First, we need to expand on `Example.pm` a bit, so it looks like this:

    package Example;
    
    require XSLoader;
    XSLoader::load();
    
    1;

`XSLoader` was added to core in Perl version 5.6.0, by the way. If you want your module to work on Perls older than that, you're seriously on your own. You'll probably want to start by reading the docs for `DynaLoader`.

Now it's time to add the file where the actual Perl/C glue is going to live. Well, the main parts of it, anyway. It should be at the top level (as long as we're using `MakeMaker`, at least) and be named the same as the module, but with the suffix `.xs` instead of `.pm`. So, in our case `Example.xs`. It should start with these lines:

    #include "EXTERN.h"
    #include "perl.h"
    #include "XSUB.h"

    #include "ppport.h"

    MODULE = Example            PACKAGE = Example

The first three includes are files that live in the Perl installation. I haven't even tried to figure out what is in which one. All the documentation and all the examples I've been able to find always include all three of them, so let's just follow the trend there. The line with `MODULE` and `PACKAGE` marks the beginning of XS code (what's before is plain C), and also tells the `xsubpp` preprocessor which Perl package the following C functions should live in. We'll talk more about that later.

`ppport.h` is a bit special. _Really_ special, it turns out. It holds compatibility code for many different versions of Perl. Exactly what's in it may affect how you write your glue code, so you write your code with a particular copy of this file in mind. Given that, it cannot live in the Perl installation. Instead, you copy it to your module. Or, rather, you run a short Perl script that writes it for you. So run this:

    perl -MDevel::PPPort -E 'Devel::PPPort::WriteFile()'

There. Now you have a file called `ppport.h`. So far, so good. Now try this:

    perl ppport.h --help

Yes, that C header file is also a Perl script. Who came up with _that_ idea, I don't know. It's a script that'll look through your `.xs` file and suggest changes that'll make your code more compatible between Perl versions. Which is certainly useful, it's just not the world's most intuitive place to put a tool. In my opinion, at least.

Anyway, at this point you should be able to do `perl Makefile.PL && make` and see messages from the C compiler. Successful ones, hopefully. On my machine it produces an object file `Example.bs` that's zero bytes long. Which makes sense, since it doesn't actually have any functions. So let's add one. Below the `MODULE` line, add this:

    void
    hello1()
        CODE:
            printf("Hello, world!\n");

Run `make` again, and this time you should get an end result with some content. Even better, you should be able to run it, like this:

    perl -MExtUtils::testlib -MExample -E 'Example::hello1()'

Yay! An insanely complicated way of printing a string! And also a demonstration that it doesn't actually have to be all that complicated to call C code from Perl. This handful of lines is all you need to create a Perl module that dynamically loads code compiled from C, and runs it on request. Sure, it's not very useful C code. Particularly, it doesn't transfer any kind of information between itself and Perl. So let's talk about doing that next.

# Passing arguments, part 1

