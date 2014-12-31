%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2015, Charles Bilyue.
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

%endif

%include "misc.inc"

section .data
EXPORT Xlat_ZSNES_6x6
         db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
         db 00h,00h,00h,00h,00h,00h,00h,00h,00h,30h,00h,00h,00h,00h,00h,00h
         db 00h,3Eh,33h,31h,3Fh,37h,2Fh,3Dh,3Ah,3Bh,35h,38h,39h,25h,28h,29h
         db 01h,02h,03h,04h,05h,06h,07h,08h,09h,0Ah,2Eh,40h,2Ah,32h,2Bh,36h
         db 3Ch,0Bh,0Ch,0Dh,0Eh,0Fh,10h,11h,12h,13h,14h,15h,16h,17h,18h,19h
         db 1Ah,1Bh,1Ch,1Dh,1Eh,1Fh,20h,21h,22h,23h,24h,2Ch,34h,2Dh,42h,26h
         db 41h,0Bh,0Ch,0Dh,0Eh,0Fh,10h,11h,12h,13h,14h,15h,16h,17h,18h,19h
         db 1Ah,1Bh,1Ch,1Dh,1Eh,1Fh,20h,21h,22h,23h,24h,43h,00h,44h,27h,00h
         db 0Dh,1Fh,0Fh,0Bh,0Bh,0Bh,0Bh,0Dh,0Fh,0Fh,0Fh,13h,13h,13h,0Bh,0Bh
         db 0Fh,0Bh,0Bh,19h,19h,19h,1Fh,1Fh,23h,19h,1Fh,0Dh,10h,23h,1Ah,10h
         db 0Bh,13h,19h,1Fh,18h,18h,0Bh,19h,00h,00h,00h,00h,00h,00h,00h,00h
         db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
         db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
         db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
         db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
         db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h

EXPORT Font_ZSNES_6x6
         db 0,0,0,0,0
         db 01110b
         db 10011b
         db 10101b
         db 11001b
         db 01110b; 0
         db 00100b
         db 01100b
         db 00100b
         db 00100b
         db 01110b; 1
         db 01110b
         db 10001b
         db 00110b
         db 01000b
         db 11111b; 2
         db 01110b
         db 10001b
         db 00110b
         db 10001b
         db 01110b; 3
         db 01010b
         db 10010b
         db 11111b
         db 00010b
         db 00010b; 4
         db 11111b
         db 10000b
         db 11110b
         db 00001b
         db 11110b; 5
         db 01110b
         db 10000b
         db 11110b
         db 10001b
         db 01110b; 6
         db 11111b
         db 00001b
         db 00010b
         db 00010b
         db 00010b; 7
         db 01110b
         db 10001b
         db 01110b
         db 10001b
         db 01110b; 8
         db 01110b
         db 10001b
         db 01111b
         db 00001b
         db 01110b; 9
         db 01110b
         db 10001b
         db 11111b
         db 10001b
         db 10001b; A
         db 11110b
         db 10001b
         db 11110b
         db 10001b
         db 11110b; B
         db 01110b
         db 10001b
         db 10000b
         db 10001b
         db 01110b; C
         db 11110b
         db 10001b
         db 10001b
         db 10001b
         db 11110b; D
         db 11111b
         db 10000b
         db 11110b
         db 10000b
         db 11111b; E
         db 11111b
         db 10000b
         db 11110b
         db 10000b
         db 10000b; F
         db 01111b
         db 10000b
         db 10011b
         db 10001b
         db 01110b; G
         db 10001b
         db 10001b
         db 11111b
         db 10001b
         db 10001b; H
         db 11111b
         db 00100b
         db 00100b
         db 00100b
         db 11111b; I
         db 01111b
         db 00010b
         db 00010b
         db 10010b
         db 01100b; J
         db 10010b
         db 10100b
         db 11100b
         db 10010b
         db 10001b; K
         db 10000b
         db 10000b
         db 10000b
         db 10000b
         db 11111b; L
         db 11011b
         db 10101b
         db 10101b
         db 10101b
         db 10001b; M
         db 11001b
         db 10101b
         db 10101b
         db 10101b
         db 10011b; N
         db 01110b
         db 10001b
         db 10001b
         db 10001b
         db 01110b; O
         db 11110b
         db 10001b
         db 11110b
         db 10000b
         db 10000b; P
         db 01110b
         db 10001b
         db 10101b
         db 10010b
         db 01101b; Q
         db 11110b
         db 10001b
         db 11110b
         db 10010b
         db 10001b; R
         db 01111b
         db 10000b
         db 01110b
         db 00001b
         db 11110b; S
         db 11111b
         db 00100b
         db 00100b
         db 00100b
         db 00100b; T
         db 10001b
         db 10001b
         db 10001b
         db 10001b
         db 01110b; U
         db 10001b
         db 10001b
         db 01010b
         db 01010b
         db 00100b; V
         db 10001b
         db 10101b
         db 10101b
         db 10101b
         db 01010b; W
         db 10001b
         db 01010b
         db 00100b
         db 01010b
         db 10001b; X
         db 10001b
         db 01010b
         db 00100b
         db 00100b
         db 00100b; Y
         db 11111b
         db 00010b
         db 00100b
         db 01000b
         db 11111b; Z
         db 00000b
         db 00000b
         db 11111b
         db 00000b
         db 00000b; -
         db 00000b
         db 00000b
         db 00000b
         db 00000b
         db 11111b; _
         db 01101b
         db 10010b
         db 00000b
         db 00000b
         db 00000b; ~
         db 00000b
         db 00000b
         db 00000b
         db 00000b
         db 00100b; .
         db 00001b
         db 00010b
         db 00100b
         db 01000b
         db 10000b; /
         db 00010b
         db 00100b
         db 01000b
         db 00100b
         db 00010b; <
         db 01000b
         db 00100b
         db 00010b
         db 00100b
         db 01000b; >
         db 01110b
         db 01000b
         db 01000b
         db 01000b
         db 01110b; [
         db 01110b
         db 00010b
         db 00010b
         db 00010b
         db 01110b; ]
         db 00000b
         db 00100b
         db 00000b
         db 00100b
         db 00000b; :
         db 01100b
         db 10011b
         db 01110b
         db 10011b
         db 01101b; &
         db 00100b
         db 00100b
         db 10101b
         db 01110b
         db 00100b; arrow
         db 01010b
         db 11111b
         db 01010b
         db 11111b
         db 01010b; #
         db 00000b
         db 11111b
         db 00000b
         db 11111b
         db 00000b; =
         db 01001b
         db 10010b
         db 00000b
         db 00000b
         db 00000b; "
         db 10000b
         db 01000b
         db 00100b
         db 00010b
         db 00001b; \ *
         db 10101b
         db 01110b
         db 11111b
         db 01110b
         db 10101b; *
         db 01110b
         db 10001b
         db 00110b
         db 00000b
         db 00100b; ?
         db 10001b
         db 00010b
         db 00100b
         db 01000b
         db 10001b; %
         db 00100b
         db 00100b
         db 11111b
         db 00100b
         db 00100b; +
         db 00000b
         db 00000b
         db 00000b
         db 00100b
         db 01000b; ,
         db 00110b
         db 01000b
         db 01000b
         db 01000b
         db 00110b; (
         db 01100b
         db 00010b
         db 00010b
         db 00010b
         db 01100b; )
         db 01110b
         db 10011b
         db 10111b
         db 10000b
         db 01110b; @
         db 00100b
         db 01000b
         db 00000b
         db 00000b
         db 00000b; '
         db 00100b
         db 00100b
         db 00100b
         db 00000b
         db 00100b; !
         db 01111b
         db 10100b
         db 01110b
         db 00101b
         db 11110b; $
         db 00000b
         db 00100b
         db 00000b
         db 00100b
         db 01000b; ;
         db 01000b
         db 00100b
         db 00000b
         db 00000b
         db 00000b; `
         db 00100b
         db 01010b
         db 00000b
         db 00000b
         db 00000b; ^
         db 00110b
         db 01000b
         db 11000b
         db 01000b
         db 00110b; {
         db 01100b
         db 00010b
         db 00011b
         db 00010b
         db 01100b; }

EXPORT Font_Modified_6x6
         db 0,0,0,0,0
         db 01110b
         db 10011b
         db 10101b
         db 11001b
         db 01110b; 0
         db 00100b
         db 01100b
         db 00100b
         db 00100b
         db 01110b; 1
         db 01110b
         db 10001b
         db 00110b
         db 01000b
         db 11111b; 2
         db 01110b
         db 10001b
         db 00110b
         db 10001b
         db 01110b; 3
         db 01010b
         db 10010b
         db 11111b
         db 00010b
         db 00010b; 4
         db 11111b
         db 10000b
         db 11110b
         db 00001b
         db 11110b; 5
         db 01110b
         db 10000b
         db 11110b
         db 10001b
         db 01110b; 6
         db 11111b
         db 00001b
         db 00010b
         db 00010b
         db 00010b; 7
         db 01110b
         db 10001b
         db 01110b
         db 10001b
         db 01110b; 8
         db 01110b
         db 10001b
         db 01111b
         db 00001b
         db 01110b; 9
         db 01110b
         db 10001b
         db 11111b
         db 10001b
         db 10001b; A
         db 11110b
         db 10001b
         db 11110b
         db 10001b
         db 11110b; B
         db 01110b
         db 10001b
         db 10000b
         db 10001b
         db 01110b; C
         db 11110b
         db 10001b
         db 10001b
         db 10001b
         db 11110b; D
         db 11111b
         db 10000b
         db 11111b
         db 10000b
         db 11111b; E
         db 11111b
         db 10000b
         db 11100b
         db 10000b
         db 10000b; F
         db 01110b
         db 10000b
         db 10011b
         db 10001b
         db 01110b; G
         db 10001b
         db 10001b
         db 11111b
         db 10001b
         db 10001b; H
         db 11111b
         db 00100b
         db 00100b
         db 00100b
         db 11111b; I
         db 01111b
         db 00010b
         db 00010b
         db 10010b
         db 01100b; J
         db 10001b
         db 10010b
         db 11100b
         db 10010b
         db 10001b; K
         db 10000b
         db 10000b
         db 10000b
         db 10000b
         db 11111b; L
         db 11011b
         db 10101b
         db 10101b
         db 10101b
         db 10001b; M
         db 11001b
         db 10101b
         db 10101b
         db 10101b
         db 10011b; N
         db 01110b
         db 10001b
         db 10001b
         db 10001b
         db 01110b; O
         db 11110b
         db 10001b
         db 11110b
         db 10000b
         db 10000b; P
         db 01110b
         db 10001b
         db 10001b
         db 10010b
         db 01101b; Q
         db 11110b
         db 10001b
         db 11110b
         db 10010b
         db 10001b; R
         db 01111b
         db 10000b
         db 01110b
         db 00001b
         db 11110b; S
         db 11111b
         db 00100b
         db 00100b
         db 00100b
         db 00100b; T
         db 10001b
         db 10001b
         db 10001b
         db 10001b
         db 01110b; U
         db 10001b
         db 10001b
         db 01010b
         db 01010b
         db 00100b; V
         db 10001b
         db 10101b
         db 10101b
         db 10101b
         db 01010b; W
         db 10001b
         db 01010b
         db 00100b
         db 01010b
         db 10001b; X
         db 10001b
         db 01010b
         db 00100b
         db 00100b
         db 00100b; Y
         db 11111b
         db 00010b
         db 00100b
         db 01000b
         db 11111b; Z
         db 00000b
         db 00000b
         db 11111b
         db 00000b
         db 00000b; -
         db 00000b
         db 00000b
         db 00000b
         db 00000b
         db 11111b; _
         db 01101b
         db 10010b
         db 00000b
         db 00000b
         db 00000b; ~
         db 00000b
         db 00000b
         db 00000b
         db 00000b
         db 00100b; .
         db 00001b
         db 00010b
         db 00100b
         db 01000b
         db 10000b; /
         db 00010b
         db 00100b
         db 01000b
         db 00100b
         db 00010b; <
         db 01000b
         db 00100b
         db 00010b
         db 00100b
         db 01000b; >
         db 01110b
         db 01000b
         db 01000b
         db 01000b
         db 01110b; [
         db 01110b
         db 00010b
         db 00010b
         db 00010b
         db 01110b; ]
         db 00000b
         db 00100b
         db 00000b
         db 00100b
         db 00000b; :
         db 01100b
         db 10011b
         db 01110b
         db 10011b
         db 01101b; &
         db 00100b
         db 00100b
         db 10101b
         db 01110b
         db 00100b; arrow
         db 01010b
         db 11111b
         db 01010b
         db 11111b
         db 01010b; #
         db 00000b
         db 11111b
         db 00000b
         db 11111b
         db 00000b; =
         db 01001b
         db 10010b
         db 00000b
         db 00000b
         db 00000b; "
         db 10000b
         db 01000b
         db 00100b
         db 00010b
         db 00001b; \ *
         db 10101b
         db 01110b
         db 11111b
         db 01110b
         db 10101b; *
         db 01110b
         db 10001b
         db 00110b
         db 00000b
         db 00100b; ?
         db 10001b
         db 00010b
         db 00100b
         db 01000b
         db 10001b; %
         db 00100b
         db 00100b
         db 11111b
         db 00100b
         db 00100b; +
         db 00000b
         db 00000b
         db 00000b
         db 00100b
         db 01000b; ,
         db 00110b
         db 01000b
         db 01000b
         db 01000b
         db 00110b; (
         db 01100b
         db 00010b
         db 00010b
         db 00010b
         db 01100b; )
         db 01110b
         db 10001b
         db 10111b
         db 10000b
         db 01110b; @
         db 00100b
         db 01000b
         db 00000b
         db 00000b
         db 00000b; '
         db 00100b
         db 00100b
         db 00100b
         db 00000b
         db 00100b; !
         db 01111b
         db 10100b
         db 01110b
         db 00101b
         db 11110b; $
         db 00000b
         db 00100b
         db 00000b
         db 00100b
         db 01000b; ;
         db 01000b
         db 00100b
         db 00000b
         db 00000b
         db 00000b; `
         db 00100b
         db 01010b
         db 00000b
         db 00000b
         db 00000b; ^
         db 00110b
         db 01000b
         db 11000b
         db 01000b
         db 00110b; {
         db 01100b
         db 00010b
         db 00011b
         db 00010b
         db 01100b; }

EXPORT Xlat_6x8
         db 00h
         db 0C0h,0C1h,0C2h,0C3h,0C4h,0C5h,0C6h,0C7h
         db 00h,00h,00h,00h,00h,00h,00h
         db 00h,00h,00h,00h,00h,00h,00h,00h,00h,30h,00h,00h,00h,00h,00h,00h
         db 00h,01h,02h,03h,04h,05h,06h,07h,08h,09h,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh
         db 10h,11h,12h,13h,14h,15h,16h,17h,18h,19h,1Ah,1Bh,1Ch,1Dh,1Eh,1Fh
         db 20h,21h,22h,23h,24h,25h,26h,27h,28h,29h,2Ah,2Bh,2Ch,2Dh,2Eh,2Fh
         db 30h,31h,32h,33h,34h,35h,36h,37h,38h,39h,3Ah,3Bh,3Ch,3Dh,3Eh,3Fh
         db 40h,41h,42h,43h,44h,45h,46h,47h,48h,49h,4Ah,4Bh,4Ch,4Dh,4Eh,4Fh
         db 50h,51h,52h,53h,54h,55h,56h,57h,58h,59h,5Ah,5Bh,5Ch,5Dh,5Eh,5Fh
         db 60h,60h,60h,60h,60h,60h,60h,60h,60h,60h,60h,60h,60h,60h,60h,60h
         db 60h,60h,60h,60h,60h,60h,60h,60h,60h,60h,60h,60h,60h,60h,60h,60h
         db 00h,61h,62h,63h,64h,65h,66h,67h,68h,69h,6Ah,6Bh,6Ch,6Dh,6Eh,6Fh
         db 70h,71h,72h,73h,74h,75h,76h,77h,78h,79h,7Ah,7Bh,7Ch,7Dh,7Eh,7Fh
         db 80h,81h,82h,83h,84h,85h,86h,87h,88h,89h,8Ah,8Bh,8Ch,8Dh,8Eh,8Fh
         db 90h,91h,92h,93h,94h,95h,96h,97h,98h,99h,9Ah,9Bh,9Ch,9Dh,9Eh,9Fh
         db 0A0h,0A1h,0A2h,0A3h,0A4h,0A5h,0A6h,0A7h
         db 0A8h,0A9h,0AAh,0ABh,0ACh,0ADh,0AEh,0AFh
         db 0B0h,0B1h,0B2h,0B3h,0B4h,0B5h,0B6h,0B7h
         db 0B8h,0B9h,0BAh,0BBh,0BCh,0BDh,0BEh,0BFh

EXPORT Font_6x8
         db 0,0,0,0,0,0,0,0

         db 001000b; !
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 000000b
         db 001000b
         db 000000b

         db 010100b; "
         db 010100b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 010100b; #
         db 010100b
         db 111110b
         db 010100b
         db 111110b
         db 010100b
         db 010100b
         db 000000b

         db 001000b; $
         db 011110b
         db 100000b
         db 011100b
         db 000010b
         db 111100b
         db 001000b
         db 000000b

         db 000000b; %
         db 110001b
         db 110010b
         db 000100b
         db 001000b
         db 010011b
         db 100011b
         db 000000b

         db 001000b; &
         db 010100b
         db 010100b
         db 011101b
         db 100010b
         db 100010b
         db 011101b
         db 000000b

         db 000100b; '
         db 000100b
         db 001000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 000100b; (
         db 001000b
         db 010000b
         db 010000b
         db 010000b
         db 001000b
         db 000100b
         db 000000b

         db 010000b; )
         db 001000b
         db 000100b
         db 000100b
         db 000100b
         db 001000b
         db 010000b
         db 000000b

         db 000000b; *
         db 010010b
         db 001100b
         db 111111b
         db 001100b
         db 010010b
         db 000000b
         db 000000b

         db 000000b; +
         db 001000b
         db 001000b
         db 111110b
         db 001000b
         db 001000b
         db 000000b
         db 000000b

         db 000000b; ,
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 001000b
         db 001000b
         db 010000b

         db 000000b; -
         db 000000b
         db 000000b
         db 111110b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 000000b; .
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 001000b
         db 001000b
         db 000000b

         db 000000b; /
         db 000001b
         db 000010b
         db 000100b
         db 001000b
         db 010000b
         db 100000b
         db 000000b

         db 011100b; 0
         db 100010b
         db 101010b
         db 101010b
         db 101010b
         db 100010b
         db 011100b
         db 000000b

         db 001000b; 1
         db 011000b
         db 101000b
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 000000b

         db 011100b; 2
         db 100010b
         db 000010b
         db 000100b
         db 001000b
         db 010000b
         db 111110b
         db 000000b

         db 011100b; 3
         db 100010b
         db 000010b
         db 001100b
         db 000010b
         db 100010b
         db 011100b
         db 000000b

         db 000100b; 4
         db 001100b
         db 010100b
         db 100100b
         db 111110b
         db 000100b
         db 000100b
         db 000000b

         db 111110b; 5
         db 100000b
         db 111100b
         db 000010b
         db 000010b
         db 100010b
         db 011100b
         db 000000b

         db 001100b; 6
         db 010000b
         db 100000b
         db 111100b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 111110b; 7
         db 000010b
         db 000010b
         db 000100b
         db 001000b
         db 001000b
         db 001000b
         db 000000b

         db 011100b; 8
         db 100010b
         db 100010b
         db 011100b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 011100b; 9
         db 100010b
         db 100010b
         db 011110b
         db 000010b
         db 000100b
         db 011000b
         db 000000b

         db 000000b; :
         db 001000b
         db 001000b
         db 000000b
         db 000000b
         db 001000b
         db 001000b
         db 000000b

         db 000000b; ;
         db 001000b
         db 001000b
         db 000000b
         db 000000b
         db 001000b
         db 001000b
         db 010000b

         db 000000b; <
         db 000011b
         db 001100b
         db 110000b
         db 001100b
         db 000011b
         db 000000b
         db 000000b

         db 000000b; =
         db 000000b
         db 111110b
         db 000000b
         db 111110b
         db 000000b
         db 000000b
         db 000000b

         db 000000b; >
         db 110000b
         db 001100b
         db 000011b
         db 001100b
         db 110000b
         db 000000b
         db 000000b

         db 011100b; ?
         db 100010b
         db 000010b
         db 000100b
         db 001000b
         db 000000b
         db 001000b
         db 000000b

         db 011100b; @
         db 100010b
         db 101110b
         db 101010b
         db 101110b
         db 100000b
         db 011110b
         db 000000b

         db 011100b; A
         db 100010b
         db 100010b
         db 111110b
         db 100010b
         db 100010b
         db 100010b
         db 000000b

         db 111100b; B
         db 100010b
         db 100010b
         db 111100b
         db 100010b
         db 100010b
         db 111100b
         db 000000b

         db 001110b; C
         db 010000b
         db 100000b
         db 100000b
         db 100000b
         db 010000b
         db 001110b
         db 000000b

         db 111000b; D
         db 100100b
         db 100010b
         db 100010b
         db 100010b
         db 100100b
         db 111000b
         db 000000b

         db 111110b; E
         db 100000b
         db 100000b
         db 111100b
         db 100000b
         db 100000b
         db 111110b
         db 000000b

         db 111110b; F
         db 100000b
         db 100000b
         db 111100b
         db 100000b
         db 100000b
         db 100000b
         db 000000b

         db 011100b; G
         db 100010b
         db 100000b
         db 100110b
         db 100010b
         db 100010b
         db 011110b
         db 000000b

         db 100010b; H
         db 100010b
         db 100010b
         db 111110b
         db 100010b
         db 100010b
         db 100010b
         db 000000b

         db 011100b; I
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 011100b
         db 000000b

         db 000010b; J
         db 000010b
         db 000010b
         db 000010b
         db 000010b
         db 100010b
         db 011100b
         db 000000b

         db 100010b; K
         db 100100b
         db 101000b
         db 110000b
         db 101000b
         db 100100b
         db 100010b
         db 000000b

         db 100000b; L
         db 100000b
         db 100000b
         db 100000b
         db 100000b
         db 100000b
         db 111110b
         db 000000b

         db 100010b; M
         db 110110b
         db 111110b
         db 101010b
         db 100010b
         db 100010b
         db 100010b
         db 000000b

         db 100010b; N
         db 100010b
         db 110010b
         db 101010b
         db 100110b
         db 100010b
         db 100010b
         db 000000b

         db 011100b; O
         db 100010b
         db 100010b
         db 100010b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 111100b; P
         db 100010b
         db 100010b
         db 111100b
         db 100000b
         db 100000b
         db 100000b
         db 000000b

         db 011000b; Q
         db 100100b
         db 100100b
         db 100100b
         db 100100b
         db 101100b
         db 011010b
         db 000000b

         db 111100b; R
         db 100010b
         db 100010b
         db 111100b
         db 100100b
         db 100010b
         db 100010b
         db 000000b

         db 011100b; S
         db 100010b
         db 100000b
         db 011100b
         db 000010b
         db 100010b
         db 011100b
         db 000000b

         db 111110b; T
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 000000b

         db 100010b; U
         db 100010b
         db 100010b
         db 100010b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 100010b; V
         db 100010b
         db 100010b
         db 100010b
         db 010100b
         db 011100b
         db 001000b
         db 000000b

         db 100010b; W
         db 100010b
         db 100010b
         db 101010b
         db 101010b
         db 110110b
         db 100010b
         db 000000b

         db 100001b; X
         db 100001b
         db 010010b
         db 001100b
         db 010010b
         db 100001b
         db 100001b
         db 000000b

         db 100010b; Y
         db 100010b
         db 010100b
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 000000b

         db 111110b; Z
         db 000010b
         db 000100b
         db 001000b
         db 010000b
         db 100000b
         db 111110b
         db 000000b

         db 011100b; [
         db 010000b
         db 010000b
         db 010000b
         db 010000b
         db 010000b
         db 011100b
         db 000000b

         db 000000b; \ *
         db 100000b
         db 010000b
         db 001000b
         db 000100b
         db 000010b
         db 000001b
         db 000000b

         db 011100b; ]
         db 000100b
         db 000100b
         db 000100b
         db 000100b
         db 000100b
         db 011100b
         db 000000b

         db 001000b; ^
         db 010100b
         db 100010b
         db 100010b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 000000b; _
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 111111b

         db 001000b; `
         db 001000b
         db 000100b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 000000b; a
         db 000000b
         db 011100b
         db 000010b
         db 011110b
         db 100010b
         db 011110b
         db 000000b

         db 100000b; b
         db 100000b
         db 111100b
         db 100010b
         db 100010b
         db 100010b
         db 111100b
         db 000000b

         db 000000b; c
         db 000000b
         db 011100b
         db 100000b
         db 100000b
         db 100000b
         db 011100b
         db 000000b

         db 000010b; d
         db 000010b
         db 011110b
         db 100010b
         db 100010b
         db 100010b
         db 011110b
         db 000000b

         db 000000b; e
         db 000000b
         db 011100b
         db 100010b
         db 111110b
         db 100000b
         db 011100b
         db 000000b

         db 001110b; f
         db 010000b
         db 111100b
         db 010000b
         db 010000b
         db 010000b
         db 010000b
         db 000000b

         db 000000b; g
         db 000000b
         db 011110b
         db 100010b
         db 100010b
         db 011110b
         db 000010b
         db 011100b

         db 100000b; h
         db 100000b
         db 111100b
         db 100010b
         db 100010b
         db 100010b
         db 100010b
         db 000000b

         db 001000b; i
         db 000000b
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 000100b
         db 000000b

         db 000100b; j
         db 000000b
         db 000100b
         db 000100b
         db 000100b
         db 000100b
         db 000100b
         db 111000b

         db 100000b; k
         db 100000b
         db 100010b
         db 100100b
         db 111000b
         db 100100b
         db 100010b
         db 000000b

         db 001000b; l
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 000100b
         db 000000b

         db 000000b; m
         db 000000b
         db 111100b
         db 101010b
         db 101010b
         db 101010b
         db 101010b
         db 000000b

         db 000000b; n
         db 000000b
         db 111100b
         db 100010b
         db 100010b
         db 100010b
         db 100010b
         db 000000b

         db 000000b; o
         db 000000b
         db 011100b
         db 100010b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 000000b; p
         db 000000b
         db 111100b
         db 100010b
         db 100010b
         db 111100b
         db 100000b
         db 100000b

         db 000000b; q
         db 000000b
         db 011110b
         db 100010b
         db 100010b
         db 011110b
         db 000010b
         db 000010b

         db 000000b; r
         db 000000b
         db 111100b
         db 100010b
         db 100000b
         db 100000b
         db 100000b
         db 000000b

         db 000000b; s
         db 000000b
         db 011100b
         db 100000b
         db 011100b
         db 000010b
         db 111100b
         db 000000b

         db 010000b; t
         db 010000b
         db 111100b
         db 010000b
         db 010000b
         db 010000b
         db 001100b
         db 000000b

         db 000000b; u
         db 000000b
         db 100010b
         db 100010b
         db 100010b
         db 100010b
         db 011110b
         db 000000b

         db 000000b; v
         db 000000b
         db 100010b
         db 100010b
         db 100010b
         db 010100b
         db 001000b
         db 000000b

         db 000000b; w
         db 000000b
         db 100010b
         db 100010b
         db 101010b
         db 101010b
         db 010100b
         db 000000b

         db 000000b; x
         db 000000b
         db 100001b
         db 010010b
         db 001100b
         db 010010b
         db 100001b
         db 000000b

         db 000000b; y
         db 000000b
         db 100010b
         db 100010b
         db 100010b
         db 011100b
         db 001000b
         db 010000b

         db 000000b; z
         db 000000b
         db 111110b
         db 000100b
         db 001000b
         db 010000b
         db 111110b
         db 000000b

         db 000110b; {
         db 001000b
         db 001000b
         db 110000b
         db 001000b
         db 001000b
         db 000110b
         db 000000b

         db 001000b; |
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 000000b

         db 110000b; }
         db 001000b
         db 001000b
         db 000110b
         db 001000b
         db 001000b
         db 110000b
         db 000000b

         db 011101b; ~
         db 100110b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 000011b; 
         db 001110b
         db 111000b
         db 100000b
         db 000011b
         db 001110b
         db 111000b
         db 000000b

         db 000000b
         db 111110b
         db 100010b
         db 100010b
         db 100010b
         db 100010b
         db 111110b
         db 000000b

         db 001000b
         db 000000b
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 001000b
         db 000000b

         db 000000b
         db 001000b
         db 011110b
         db 100000b
         db 011110b
         db 001000b
         db 000000b
         db 000000b

         db 001100b
         db 010010b
         db 010000b
         db 111100b
         db 010000b
         db 010000b
         db 111110b
         db 000000b

         db 100001b
         db 011110b
         db 100001b
         db 011110b
         db 100001b
         db 000000b
         db 000000b
         db 000000b

         db 100010b
         db 100010b
         db 010100b
         db 001000b
         db 011100b
         db 001000b
         db 001000b
         db 000000b

         db 001000b
         db 001000b
         db 001000b
         db 000000b
         db 001000b
         db 001000b
         db 001000b
         db 000000b

         db 011110b
         db 100000b
         db 011110b
         db 100001b
         db 011110b
         db 000001b
         db 011110b
         db 000000b

         db 010010b
         db 010010b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 011110b
         db 100001b
         db 101101b
         db 101001b
         db 101101b
         db 100001b
         db 011110b
         db 000000b

         db 000000b
         db 011100b
         db 100100b
         db 011110b
         db 000000b
         db 111110b
         db 000000b
         db 000000b

         db 000000b
         db 001001b
         db 010010b
         db 100100b
         db 010010b
         db 001001b
         db 000000b
         db 000000b

         db 111110b
         db 000010b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 000000b
         db 000000b
         db 000000b
         db 111110b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 011110b
         db 100001b
         db 101101b
         db 101101b
         db 101101b
         db 101011b
         db 100001b
         db 011110b

         db 111110b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 011100b
         db 100010b
         db 011100b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 001000b
         db 001000b
         db 111110b
         db 001000b
         db 001000b
         db 000000b
         db 111110b
         db 000000b

         db 011100b
         db 000010b
         db 000100b
         db 001000b
         db 011110b
         db 000000b
         db 000000b
         db 000000b

         db 111100b
         db 000010b
         db 001100b
         db 000010b
         db 111100b
         db 000000b
         db 000000b
         db 000000b

         db 000100b
         db 001000b
         db 010000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 000000b
         db 000000b
         db 100100b
         db 100100b
         db 100100b
         db 100100b
         db 111110b
         db 100000b

         db 011110b
         db 111010b
         db 111010b
         db 011010b
         db 001010b
         db 001010b
         db 001010b
         db 000000b

         db 000000b
         db 000000b
         db 001000b
         db 001000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 000000b
         db 001000b
         db 010000b

         db 001000b
         db 011000b
         db 001000b
         db 001000b
         db 001000b
         db 000000b
         db 000000b
         db 000000b

         db 011100b
         db 100010b
         db 100010b
         db 011100b
         db 000000b
         db 111110b
         db 000000b
         db 000000b

         db 000000b
         db 100100b
         db 010010b
         db 001001b
         db 010010b
         db 100100b
         db 000000b
         db 000000b

         db 010000b
         db 110001b
         db 010010b
         db 010101b
         db 001011b
         db 010101b
         db 100001b
         db 000000b

         db 010000b
         db 110001b
         db 010010b
         db 010100b
         db 001011b
         db 010001b
         db 100010b
         db 000111b

         db 110000b
         db 001000b
         db 011001b
         db 001010b
         db 110101b
         db 001011b
         db 010101b
         db 000001b

         db 001000b
         db 000000b
         db 001000b
         db 010000b
         db 100000b
         db 100010b
         db 011100b
         db 000000b

         db 110000b
         db 001000b
         db 010100b
         db 100010b
         db 111110b
         db 100010b
         db 100010b
         db 000000b

         db 000110b
         db 001000b
         db 010100b
         db 100010b
         db 111110b
         db 100010b
         db 100010b
         db 000000b

         db 011100b
         db 100010b
         db 011100b
         db 100010b
         db 111110b
         db 100010b
         db 100010b
         db 000000b

         db 011001b
         db 100111b
         db 001010b
         db 010001b
         db 011111b
         db 010001b
         db 010001b
         db 000000b

         db 100010b
         db 000000b
         db 011100b
         db 100010b
         db 111110b
         db 100010b
         db 100010b
         db 000000b

         db 001100b
         db 010010b
         db 011100b
         db 100010b
         db 111110b
         db 100010b
         db 100010b
         db 000000b

         db 000111b
         db 001100b
         db 001100b
         db 010111b
         db 011100b
         db 100100b
         db 100111b
         db 000000b

         db 001110b
         db 010000b
         db 100000b
         db 100000b
         db 010000b
         db 001110b
         db 000100b
         db 001000b

         db 010000b
         db 001000b
         db 111110b
         db 100000b
         db 111100b
         db 100000b
         db 111110b
         db 000000b

         db 000100b
         db 001000b
         db 111110b
         db 100000b
         db 111100b
         db 100000b
         db 111110b
         db 000000b

         db 011000b
         db 100100b
         db 111110b
         db 100000b
         db 111100b
         db 100000b
         db 111110b
         db 000000b

         db 100010b
         db 000000b
         db 111110b
         db 100000b
         db 111100b
         db 100000b
         db 111110b
         db 000000b

         db 010000b
         db 001000b
         db 011110b
         db 001000b
         db 001000b
         db 001000b
         db 011110b
         db 000000b

         db 000110b
         db 001000b
         db 011110b
         db 001000b
         db 001000b
         db 001000b
         db 011110b
         db 000000b

         db 001000b
         db 100010b
         db 011100b
         db 001000b
         db 001000b
         db 001000b
         db 011100b
         db 000000b

         db 100010b
         db 000000b
         db 011100b
         db 001000b
         db 001000b
         db 001000b
         db 011100b
         db 000000b

         db 011110b
         db 010001b
         db 010001b
         db 111101b
         db 010001b
         db 010001b
         db 011110b
         db 000000b

         db 011101b
         db 100110b
         db 110001b
         db 101001b
         db 100101b
         db 100011b
         db 100001b
         db 000000b

         db 010000b
         db 001000b
         db 011100b
         db 100010b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 000100b
         db 001000b
         db 011100b
         db 100010b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 011000b
         db 100100b
         db 011100b
         db 100010b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 011101b
         db 100110b
         db 001110b
         db 010001b
         db 010001b
         db 010001b
         db 001110b
         db 000000b

         db 100010b
         db 011100b
         db 100010b
         db 100010b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 000000b
         db 100001b
         db 010010b
         db 001100b
         db 010010b
         db 100001b
         db 000000b
         db 000000b

         db 001110b
         db 010001b
         db 010011b
         db 010101b
         db 011001b
         db 010001b
         db 101110b
         db 000000b

         db 010000b
         db 001000b
         db 100010b
         db 100010b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 000100b
         db 001000b
         db 100010b
         db 100010b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 001000b
         db 010100b
         db 100010b
         db 100010b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 100010b
         db 000000b
         db 100010b
         db 100010b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 000010b
         db 000100b
         db 100010b
         db 100010b
         db 011100b
         db 001000b
         db 001000b
         db 000000b

         db 100000b
         db 100000b
         db 111110b
         db 100001b
         db 111110b
         db 100000b
         db 100000b
         db 000000b

         db 011100b
         db 100010b
         db 100010b
         db 100100b
         db 100010b
         db 100010b
         db 100100b
         db 100000b

         db 010000b
         db 001000b
         db 011100b
         db 000010b
         db 011110b
         db 100010b
         db 011110b
         db 000000b

         db 000100b
         db 001000b
         db 011100b
         db 000010b
         db 011110b
         db 100010b
         db 011110b
         db 000000b

         db 011000b
         db 100100b
         db 011100b
         db 000010b
         db 011110b
         db 100010b
         db 011110b
         db 000000b

         db 011101b
         db 100110b
         db 001110b
         db 000001b
         db 001111b
         db 010001b
         db 001111b
         db 000000b

         db 100010b
         db 000000b
         db 011100b
         db 000010b
         db 011110b
         db 100010b
         db 011110b
         db 000000b

         db 001000b
         db 010100b
         db 011100b
         db 000010b
         db 011110b
         db 100010b
         db 011110b
         db 000000b

         db 000000b
         db 000000b
         db 011110b
         db 000101b
         db 011111b
         db 100110b
         db 011101b
         db 000000b

         db 000000b
         db 000000b
         db 011110b
         db 100000b
         db 100000b
         db 100000b
         db 011100b
         db 001000b

         db 010000b
         db 001000b
         db 011100b
         db 100010b
         db 111110b
         db 100000b
         db 011100b
         db 000000b

         db 000100b
         db 001000b
         db 011100b
         db 100010b
         db 111110b
         db 100000b
         db 011100b
         db 000000b

         db 011000b
         db 100100b
         db 011100b
         db 100010b
         db 111110b
         db 100000b
         db 011110b
         db 000000b

         db 100010b
         db 000000b
         db 011100b
         db 100010b
         db 111110b
         db 100000b
         db 011110b
         db 000000b

         db 010000b
         db 001000b
         db 000000b
         db 001000b
         db 001000b
         db 001000b
         db 000100b
         db 000000b

         db 000100b
         db 001000b
         db 000000b
         db 001000b
         db 001000b
         db 001000b
         db 000100b
         db 000000b

         db 011000b
         db 100100b
         db 000000b
         db 001000b
         db 001000b
         db 001000b
         db 000100b
         db 000000b

         db 000000b
         db 010010b
         db 000000b
         db 001000b
         db 001000b
         db 001000b
         db 000100b
         db 000000b

         db 010000b
         db 111111b
         db 000100b
         db 001110b
         db 010001b
         db 010001b
         db 001110b
         db 000000b

         db 011101b
         db 100110b
         db 000000b
         db 011110b
         db 010001b
         db 010001b
         db 010001b
         db 000000b

         db 010000b
         db 001000b
         db 000000b
         db 011100b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 000100b
         db 001000b
         db 000000b
         db 011100b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 011000b
         db 100100b
         db 000000b
         db 011100b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 011010b
         db 101100b
         db 000000b
         db 011100b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 000000b
         db 100010b
         db 000000b
         db 011100b
         db 100010b
         db 100010b
         db 011100b
         db 000000b

         db 000000b
         db 001000b
         db 000000b
         db 111110b
         db 000000b
         db 001000b
         db 000000b
         db 000000b

         db 000000b
         db 000000b
         db 011100b
         db 100110b
         db 101010b
         db 110010b
         db 011100b
         db 000000b

         db 010000b
         db 001000b
         db 000000b
         db 100010b
         db 100010b
         db 100010b
         db 011110b
         db 000000b

         db 000100b
         db 001000b
         db 000000b
         db 100010b
         db 100010b
         db 100010b
         db 011110b
         db 000000b

         db 001000b
         db 110110b
         db 000000b
         db 100010b
         db 100010b
         db 100010b
         db 011110b
         db 000000b

         db 000000b
         db 100010b
         db 000000b
         db 100010b
         db 100010b
         db 100010b
         db 011110b
         db 000000b

         db 000100b
         db 001000b
         db 000000b
         db 100010b
         db 100010b
         db 011100b
         db 001000b
         db 010000b

         db 100000b
         db 100000b
         db 111100b
         db 100010b
         db 100010b
         db 111100b
         db 100000b
         db 100000b

         db 000000b
         db 100010b
         db 000000b
         db 100010b
         db 100010b
         db 011100b
         db 001000b
         db 010000b

         db 000000b; Border TL
         db 011111b
         db 010000b
         db 010111b
         db 010100b
         db 010100b
         db 010100b
         db 010100b

         db 000000b; Border T
         db 111111b
         db 000000b
         db 111111b
         db 000000b
         db 000000b
         db 000000b
         db 000000b

         db 000000b; Border TR
         db 111110b
         db 000010b
         db 111010b
         db 001010b
         db 001010b
         db 001010b
         db 001010b

         db 010100b; Border ML
         db 010100b
         db 010100b
         db 010100b
         db 010100b
         db 010100b
         db 010100b
         db 010100b

         db 001010b; Border MR
         db 001010b
         db 001010b
         db 001010b
         db 001010b
         db 001010b
         db 001010b
         db 001010b

         db 010100b; Border BL
         db 010100b
         db 010100b
         db 010111b
         db 010000b
         db 011111b
         db 000000b
         db 000000b

         db 000000b; Border B
         db 000000b
         db 000000b
         db 111111b
         db 000000b
         db 111111b
         db 000000b
         db 000000b

         db 001010b; Border BR
         db 001010b
         db 001010b
         db 111010b
         db 000010b
         db 111110b
         db 000000b
         db 000000b
