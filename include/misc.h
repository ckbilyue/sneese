/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2006, Charles Bilyue'.
Portions copyright (c) 1998-2003, Brad Martin.
Portions copyright (c) 2003-2004, Daniel Horchner.
Portions copyright (c) 2004-2005, Nach. ( http://nsrt.edgeemu.com/ )
Unzip Technology, copyright (c) 1998 Gilles Vollant.
zlib Technology ( www.gzip.org/zlib/ ), Copyright (c) 1995-2003,
 Jean-loup Gailly ( jloup* *at* *gzip.org ) and Mark Adler
 ( madler* *at* *alumni.caltech.edu ).
JMA Technology, copyright (c) 2004-2005 NSRT Team. ( http://nsrt.edgeemu.com/ )
LZMA Technology, copyright (c) 2001-4 Igor Pavlov. ( http://www.7-zip.org )
Portions copyright (c) 2002 Andrea Mazzoleni. ( http://advancemame.sf.net )

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

#ifndef SNEeSe_misc_h
#define SNEeSe_misc_h

#if defined(__cplusplus)||defined(c_plusplus)
#define EXTERN extern "C"
#else
#define EXTERN extern
#endif


/* macros to clarify generation of literal bit masks */
#define BIT(bit) (1 << (bit))
/* lowest bit in mask, highest bit in mask */
#define BITMASK(lsb,msb) ((BIT((msb) - (lsb) + 1) - 1) << (lsb))


/* macros to help with building names from parts */
#define _CONCAT_NAME(PART1,PART2) PART1 ## PART2
#define CONCAT_NAME(PART1,PART2) _CONCAT_NAME(PART1,PART2)

#define _CONCAT_3_NAME(PART1,PART2,PART3) PART1 ## PART2 ## PART3
#define CONCAT_3_NAME(PART1,PART2,PART3) _CONCAT_3_NAME(PART1,PART2,PART3)

#define _CONCAT_4_NAME(PART1,PART2,PART3,PART4) \
 PART1 ## PART2 ## PART3 ## PART4
#define CONCAT_4_NAME(PART1,PART2,PART3,PART4) _CONCAT_4_NAME(PART1,PART2,PART3,PART4)

#define _CONCAT_5_NAME(PART1,PART2,PART3,PART4,PART5) \
 PART1 ## PART2 ## PART3 ## PART4 ## PART5
#define CONCAT_5_NAME(PART1,PART2,PART3,PART4,PART5) \
 _CONCAT_5_NAME(PART1,PART2,PART3,PART4,PART5)

#define _CONCAT_6_NAME(PART1,PART2,PART3,PART4,PART5,PART6) \
 PART1 ## PART2 ## PART3 ## PART4 ## PART5 ## PART6
#define CONCAT_6_NAME(PART1,PART2,PART3,PART4,PART5,PART6) \
 _CONCAT_6_NAME(PART1,PART2,PART3,PART4,PART5,PART6)

#define _CONCAT_7_NAME(PART1,PART2,PART3,PART4,PART5,PART6,PART7) \
 PART1 ## PART2 ## PART3 ## PART4 ## PART5 ## PART6 ## PART7
#define CONCAT_7_NAME(PART1,PART2,PART3,PART4,PART5,PART6,PART7) \
 _CONCAT_7_NAME(PART1,PART2,PART3,PART4,PART5,PART6,PART7)


#endif /* !defined(SNEeSe_misc_h) */
