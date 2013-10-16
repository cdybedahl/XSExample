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

AV *
arrayret()
    CODE:
        SV *list[3];
        list[0] = sv_2mortal(newSViv(1));
        list[1] = sv_2mortal(newSViv(2));
        list[2] = sv_2mortal(newSViv(3));
        RETVAL = av_make(3, list );
    OUTPUT:
        RETVAL
