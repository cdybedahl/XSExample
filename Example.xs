#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

MODULE = Example            PACKAGE = Example

void
hello()
    CODE:
        printf("Hello, world!\n");