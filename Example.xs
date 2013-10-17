#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

typedef struct {
    double x;
    double y;
} point;

typedef point *Example;

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

long
sumthese(one, two, three)
    long one;
    long two;
    long three;
    CODE:
        RETVAL = one+two+three;
    OUTPUT:
        RETVAL

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

Example
new(class,xval,yval)
    char *class;
    double xval;
    double yval;
    CODE:
    {
        Example self;

        Newx(self, 1, point);
        self->x = xval;
        self->y = yval;
        RETVAL = self;
    }
    OUTPUT:
        RETVAL

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
