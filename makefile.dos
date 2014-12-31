#
#
# SNEeSe, an Open Source Super NES emulator.
#
#
# Copyright (c) 1998-2015, Charles Bilyue.
# Portions copyright (c) 1998-2003, Brad Martin.
# Portions copyright (c) 2003-2004, Daniel Horchner.
# Portions copyright (c) 2004-2005, Nach. ( http://nsrt.edgeemu.com/ )
# Unzip Technology, copyright (c) 1998 Gilles Vollant.
# zlib Technology ( www.gzip.org/zlib/ ), Copyright (c) 1995-2003,
#  Jean-loup Gailly ( jloup* *at* *gzip.org ) and Mark Adler
#  ( madler* *at* *alumni.caltech.edu ).
# JMA Technology, copyright (c) 2004-2005 NSRT Team. ( http://nsrt.edgeemu.com/ )
# LZMA Technology, copyright (c) 2001-4 Igor Pavlov. ( http://www.7-zip.org )
# Portions copyright (c) 2002 Andrea Mazzoleni. ( http://advancemame.sf.net )
#
# This is free software.  See 'LICENSE' for details.
# You must read and accept the license prior to use.
#
#


PLATFORM := dos

# DOS (DJGPP, GCC)


# How to call the tools we need to use

NASM   := nasm -w+orphan-labels -w+macro-params -O20 -DC_LABELS_PREFIX=_
GCC    := gcc -Werror -Wall
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
PLATFORMOBJS := $(addprefix allegro/, platform.o)
PLATFORMRULES = rulesalg.inc

ZLIB   := 1 # comment this line to disable ZLIB support
ifdef ZLIB
MIOFLAGS := -lz
endif


include makefile.all
