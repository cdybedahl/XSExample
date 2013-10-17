#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

MODULE = Example            PACKAGE = Example

void
hello1()
    CODE:
        printf("Hello, world!\n");


char *
hello2()
    CODE:
        RETVAL = "Hello, World!\n";
    OUTPUT:
        RETVAL

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

SV *
numbers1()
    PPCODE:
        mXPUSHi(17);
        mXPUSHi(42);
        mXPUSHi(4711);

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

SV *
numbers2()
    PPCODE:
        EXTEND(SP,3);
        ST(0) = sv_2mortal(newSViv(17));
        ST(1) = sv_2mortal(newSViv(42));
        ST(2) = sv_2mortal(newSViv(4711));
        XSRETURN(3);

int
testing(...)
    CODE:
        int i;
        for(i=0;i<items;i++)
        {
            printf("Testing (%s)\n", SvPV_nolen(ST(i)));
        }
        RETVAL = 17;
    OUTPUT:
        RETVAL
