PLATFORM := dos

# DOS (DJGPP, GCC)


# How to call the tools we need to use

NASM   := nasm -w+orphan-labels -w+macro-params -O3 -DC_LABELS_PREFIX=_
GCC    := gcc -Werror -Wall -Wno-deprecated
RM     := rm -f
MD     := mkdir


# Default filename extension for executables
EXE_EXT := .exe


# How to inform the linker of libraries we're using

ALLEG  := -lalleg


# Set up build for this platform.

SUFFIX :=
AFLAGS := -f coff
GXX    := gxx


include makefile.all
