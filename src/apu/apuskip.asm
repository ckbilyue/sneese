%if 0

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

%endif

;
;
; APUskip.asm - Contains APU skipper
;
;

%include "misc.inc"
%include "ppu/ppu.inc"

EXTERN cpu_65c816_A,cpu_65c816_X,cpu_65c816_Y

section .text
EXPORT APUskip_text_start
section .data
EXPORT APUskip_data_start
section .bss
EXPORT APUskip_bss_start

section .bss
ALIGNB
EXPORT APUI00a,skipb    ; This is the APU value when APUI00b=0
EXPORT APUI00b,skipb    ; This is a count type of variable for flipping APUI00a
EXPORT APUI00c,skipb    ; Binary counter used in conjuction with APUI01c
APUI01a:skipb  ; This is the APU value when APUI01b=0
APUI01b:skipb  ; This is a count type of variable for flipping APUI01a
APUI01c:skipb  ; Binary counter upper byte of APUI00c
APUI02a:skipb  ; This is the APU value when APUI02b=0
APUI02b:skipb  ; This is a count type of variable for flipping APUI02a
APUI02c:skipb  ; Binary counter used in conjuction with APUI03c
APUI03a:skipb  ; This is the APU value when APUI03b=0
APUI03b:skipb  ; This is a count type of variable for flipping APUI03a
APUI03c:skipb  ; Binary counter upper byte of APUI02c

section .text
ALIGNC
EXPORT Reset_APU_Skipper
 pusha
 ; Set eax to 0, as we're setting most everything to 0...
 xor eax,eax

 mov [APUI00a],al
 mov [APUI00b],al
 mov [APUI00c],al
 mov [APUI01a],al
 mov [APUI01b],al
 mov [APUI01c],al
 mov [APUI02a],al
 mov [APUI02b],al
 mov [APUI02c],al
 mov [APUI03a],al
 mov [APUI03b],al
 mov [APUI03c],al
 popa

 ret

ALIGNC
SNES_R2140_SKIP:    ; APUI00
 cmp byte [APUI00b],0
 jne .return_xl

 mov al,[cpu_65c816_A]
 inc byte [APUI00b]
 mov byte [APUI01b],0
 ret

.return_xl:
 cmp byte [APUI00b],1
 jne .return_yl

 mov al,[cpu_65c816_X]
 inc byte [APUI00b]
 mov byte [APUI01b],1
 ret

.return_yl:
 cmp byte [APUI00b],2
 jne .return_zero

 mov al,[cpu_65c816_Y]
 inc byte [APUI00b]
 mov byte [APUI01b],2
 ret

.return_zero:
 cmp byte [APUI00b],3
 jne .return_FF

 mov al,0
 inc byte [APUI00b]
 ret

.return_FF:
 cmp byte [APUI00b],4
 jne .return_55

 mov al,0xff
 inc byte [APUI00b]
 ret

.return_55:
 cmp byte [APUI00b],5
 jne .return_1

 mov al,0x55
 inc byte [APUI00b]
 ret

.return_1:
 cmp byte [APUI00b],6
 jne .return_AA

 mov al,1
 inc byte [APUI00b]
 ret

.return_AA:
 cmp byte [APUI00b],7
 jne .return_written

 mov al,0xAA
 mov byte [APUI01b],6
 inc byte [APUI00b]
 ret

.return_written:
 cmp byte [APUI00b],8
 jne .return_all

 mov al,[APUI00a]
 inc byte [APUI00b]
 ret

.return_all:
 mov al,[APUI00c]  ; New extra skipper, if all else fails this should work for 2140!
 inc byte [APUI00c]
 mov byte [APUI01b],0xb    ; This keeps high word at 0 during cycle (for now at least)
 cmp byte [APUI00c],0
 je  .reset_skipper
 ret

.reset_skipper:
 mov byte [APUI00b],0  ; Ensures the skipper switches off
 inc byte [APUI01c]
 mov byte [APUI01b],0
 ret

ALIGNC
SNES_R2141_SKIP:    ; APUI01
 cmp byte [APUI01b],0
 jne .return_xh

 mov al,[cpu_65c816_A+1]
 inc byte [APUI01b]
 ret

.return_xh:
 cmp byte [APUI01b],1
 jne .return_yh

 mov al,[cpu_65c816_X+1]
 inc byte [APUI01b]
 ret

.return_yh:
 cmp byte [APUI01b],2
 jne .return_al

 mov al,[cpu_65c816_Y+1]
 inc byte [APUI01b]
 ret

.return_al:
 cmp byte [APUI01b],3
 jne .return_xl

 mov al,[cpu_65c816_A]
 inc byte [APUI01b]
 ret

.return_xl:
 cmp byte [APUI01b],4
 jne .return_yl

 mov al,[cpu_65c816_X]
 inc byte [APUI01b]
 ret

.return_yl:
 cmp byte [APUI01b],5
 jne .return_BB

 mov al,[cpu_65c816_Y]
 inc byte [APUI01b]
 ret

.return_BB:
 cmp byte [APUI01b],6
 jne .return_zero

 mov al,0xBB
 inc byte [APUI01b]
 ret

.return_zero:
 cmp byte [APUI01b],7
 jne .return_FF

 mov al,0
 inc byte [APUI01b]
 ret

.return_FF:
 cmp byte [APUI01b],8
 jne .return_55

 mov al,0xff
 inc byte [APUI01b]
 ret

.return_55:
 cmp byte [APUI01b],9
 jne .return_written

 mov al,0x55
 inc byte [APUI01b]
 ret

.return_written:
 cmp byte [APUI01b],10
 jne .return_special

 mov al,[APUI01a]
 mov byte [APUI01b],0
 ret

.return_special:
 mov al,[APUI01c]  ; This can only be reached in special cases
 ret

ALIGNC
SNES_R2142_SKIP:    ; APUI02
 cmp byte [APUI02b],0
 jne .return_xl

 mov al,[cpu_65c816_A]
 inc byte [APUI02b]
 mov byte [APUI03b],0
 ret

.return_xl:
 cmp byte [APUI02b],1
 jne .return_yl

 mov al,[cpu_65c816_X]
 inc byte [APUI02b]
 mov byte [APUI03b],1
 ret

.return_yl:
 cmp byte [APUI02b],2
 jne .return_zero

 mov al,[cpu_65c816_Y]
 inc byte [APUI02b]
 mov byte [APUI03b],2
 ret

.return_zero:
 cmp byte [APUI02b],3
 jne .return_FF

 mov al,0
 inc byte [APUI02b]
 ret

.return_FF:
 cmp byte [APUI02b],4
 jne .return_55

 mov al,0xff
 inc byte [APUI02b]
 ret

.return_55:
 cmp byte [APUI02b],5
 jne .return_AA

 mov al,0x55
 inc byte [APUI02b]
 ret

.return_AA:
 cmp byte [APUI02b],6
 jne .return_written

 mov al,0xAA
 mov byte [APUI03b],6
 inc byte [APUI02b]
 ret

.return_written:
 mov al,[APUI02a]
 mov byte [APUI02b],0
 ret

ALIGNC
SNES_R2143_SKIP:    ; APUI03
 cmp byte [APUI03b],0
 jne .return_xh

 mov al,[cpu_65c816_A+1]
 inc byte [APUI03b]
 ret

.return_xh:
 cmp byte [APUI03b],1
 jne .return_yh

 mov al,[cpu_65c816_X+1]
 inc byte [APUI03b]
 ret

.return_yh:
 cmp byte [APUI03b],2
 jne .return_al

 mov al,[cpu_65c816_Y+1]
 inc byte [APUI03b]
 ret

.return_al:
 cmp byte [APUI03b],3
 jne .return_xl

 mov al,[cpu_65c816_A]
 inc byte [APUI03b]
 ret

.return_xl:
 cmp byte [APUI03b],4
 jne .return_yl

 mov al,[cpu_65c816_X]
 inc byte [APUI03b]
 ret

.return_yl:
 cmp byte [APUI03b],5
 jne .return_BB

 mov al,[cpu_65c816_Y]
 inc byte [APUI03b]
 ret

.return_BB:
 cmp byte [APUI03b],6
 jne .return_zero

 mov al,0xBB
 inc byte [APUI03b]
 ret

.return_zero:
 cmp byte [APUI03b],7
 jne .return_FF

 mov al,0
 inc byte [APUI03b]
 ret

.return_FF:
 cmp byte [APUI03b],8
 jne .return_55

 mov al,0xFF
 inc byte [APUI03b]
 ret

.return_55:
 cmp byte [APUI03b],9
 jne .return_written

 mov al,0x55
 inc byte [APUI03b]
 ret

.return_written:
 mov al,[APUI03a]
 mov byte [APUI03b],0
 ret

ALIGNC
SNES_W2140_SKIP:    ; APUI00
 mov [APUI00a],al
;cmp al,0xff
;je .alt
;mov byte [APUI00b],0
 ret
;.alt:
; mov byte [APUI00b],7
; ret

ALIGNC
SNES_W2141_SKIP:    ; APUI01
 mov [APUI01a],al
 mov byte [APUI01b],0
 ret

ALIGNC
SNES_W2142_SKIP:    ; APUI02
 mov [APUI02a],al
 mov byte [APUI02b],0
 ret

ALIGNC
SNES_W2143_SKIP:    ; APUI03
 mov [APUI03a],al
 mov byte [APUI03b],0
 ret

ALIGNC
EXPORT Make_APU_Skipper
 pusha
 mov eax,SNES_R2140_SKIP
 mov edx,SNES_R2141_SKIP
 mov esi,SNES_R2142_SKIP
 mov edi,SNES_R2143_SKIP

 mov ebx,Read_21_Address(0x40)
 mov cl,0x40 / 4

.set_read_loop:
 mov [ebx],eax
 mov [ebx+1*4],edx
 mov [ebx+2*4],esi
 mov [ebx+3*4],edi
 add ebx,4*4
 dec cl
 jnz .set_read_loop

 mov eax,SNES_W2140_SKIP
 mov edx,SNES_W2141_SKIP
 mov esi,SNES_W2142_SKIP
 mov edi,SNES_W2143_SKIP

 mov ebx,Write_21_Address(0x40)
 mov cl,0x40 / 4

.set_write_loop:
 mov [ebx],eax
 mov [ebx+1*4],edx
 mov [ebx+2*4],esi
 mov [ebx+3*4],edi
 add ebx,4*4
 dec cl
 jnz .set_write_loop

 popa
 ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
