%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2005, Charles Bilyue'.
Portions Copyright (c) 2003-2004, Daniel Horchner.
Portions Copyright (c) 2004-2005, Nach. ( http://nsrt.edgeemu.com/ )
JMA Technology, Copyright (c) 2004-2005 NSRT Team. ( http://nsrt.edgeemu.com/ )
LZMA Technology, Copyright (c) 2001-4 Igor Pavlov. ( http://www.7-zip.org )
Portions Copyright (c) 2002 Andrea Mazzoleni. ( http://advancemame.sf.net )

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

EXTERN_C cpu_65c816_A,cpu_65c816_X,cpu_65c816_Y

section .text
EXPORT_C APUskip_text_start
section .data
EXPORT_C APUskip_data_start
section .bss
EXPORT_C APUskip_bss_start

section .bss
ALIGNB
EXPORT_C APUI00a,skipb  ; This is the APU value when APUI00b=0
EXPORT_C APUI00b,skipb  ; This is a count type of variable for flipping APUI00a
EXPORT_C APUI00c,skipb  ; Binary counter used in conjuction with APUI01c
C_LABEL(APUI01a):skipb  ; This is the APU value when APUI01b=0
C_LABEL(APUI01b):skipb  ; This is a count type of variable for flipping APUI01a
C_LABEL(APUI01c):skipb  ; Binary counter upper byte of APUI00c
C_LABEL(APUI02a):skipb  ; This is the APU value when APUI02b=0
C_LABEL(APUI02b):skipb  ; This is a count type of variable for flipping APUI02a
C_LABEL(APUI02c):skipb  ; Binary counter used in conjuction with APUI03c
C_LABEL(APUI03a):skipb  ; This is the APU value when APUI03b=0
C_LABEL(APUI03b):skipb  ; This is a count type of variable for flipping APUI03a
C_LABEL(APUI03c):skipb  ; Binary counter upper byte of APUI02c

section .text
ALIGNC
EXPORT_C Reset_APU_Skipper
 pusha
 ; Set eax to 0, as we're setting most everything to 0...
 xor eax,eax

 mov [C_LABEL(APUI00a)],al
 mov [C_LABEL(APUI00b)],al
 mov [C_LABEL(APUI00c)],al
 mov [C_LABEL(APUI01a)],al
 mov [C_LABEL(APUI01b)],al
 mov [C_LABEL(APUI01c)],al
 mov [C_LABEL(APUI02a)],al
 mov [C_LABEL(APUI02b)],al
 mov [C_LABEL(APUI02c)],al
 mov [C_LABEL(APUI03a)],al
 mov [C_LABEL(APUI03b)],al
 mov [C_LABEL(APUI03c)],al
 popa

 ret

ALIGNC
SNES_R2140_SKIP:    ; APUI00
 cmp byte [C_LABEL(APUI00b)],0
 jne .return_xl

 mov al,[C_LABEL(cpu_65c816_A)]
 inc byte [C_LABEL(APUI00b)]
 mov byte [C_LABEL(APUI01b)],0
 ret

.return_xl:
 cmp byte [C_LABEL(APUI00b)],1
 jne .return_yl

 mov al,[C_LABEL(cpu_65c816_X)]
 inc byte [C_LABEL(APUI00b)]
 mov byte [C_LABEL(APUI01b)],1
 ret

.return_yl:
 cmp byte [C_LABEL(APUI00b)],2
 jne .return_zero

 mov al,[C_LABEL(cpu_65c816_Y)]
 inc byte [C_LABEL(APUI00b)]
 mov byte [C_LABEL(APUI01b)],2
 ret

.return_zero:
 cmp byte [C_LABEL(APUI00b)],3
 jne .return_FF

 mov al,0
 inc byte [C_LABEL(APUI00b)]
 ret

.return_FF:
 cmp byte [C_LABEL(APUI00b)],4
 jne .return_55

 mov al,0xff
 inc byte [C_LABEL(APUI00b)]
 ret

.return_55:
 cmp byte [C_LABEL(APUI00b)],5
 jne .return_1

 mov al,0x55
 inc byte [C_LABEL(APUI00b)]
 ret

.return_1:
 cmp byte [C_LABEL(APUI00b)],6
 jne .return_AA

 mov al,1
 inc byte [C_LABEL(APUI00b)]
 ret

.return_AA:
 cmp byte [C_LABEL(APUI00b)],7
 jne .return_written

 mov al,0xAA
 mov byte [C_LABEL(APUI01b)],6
 inc byte [C_LABEL(APUI00b)]
 ret

.return_written:
 cmp byte [C_LABEL(APUI00b)],8
 jne .return_all

 mov al,[C_LABEL(APUI00a)]
 inc byte [C_LABEL(APUI00b)]
 ret

.return_all:
 mov al,[C_LABEL(APUI00c)]  ; New extra skipper, if all else fails this should work for 2140!
 inc byte [C_LABEL(APUI00c)]
 mov byte [C_LABEL(APUI01b)],0xb    ; This keeps high word at 0 during cycle (for now at least)
 cmp byte [C_LABEL(APUI00c)],0
 je  .reset_skipper
 ret

.reset_skipper:
 mov byte [C_LABEL(APUI00b)],0  ; Ensures the skipper switches off
 inc byte [C_LABEL(APUI01c)]
 mov byte [C_LABEL(APUI01b)],0
 ret

ALIGNC
SNES_R2141_SKIP:    ; APUI01
 cmp byte [C_LABEL(APUI01b)],0
 jne .return_xh

 mov al,[C_LABEL(cpu_65c816_A)+1]
 inc byte [C_LABEL(APUI01b)]
 ret

.return_xh:
 cmp byte [C_LABEL(APUI01b)],1
 jne .return_yh

 mov al,[C_LABEL(cpu_65c816_X)+1]
 inc byte [C_LABEL(APUI01b)]
 ret

.return_yh:
 cmp byte [C_LABEL(APUI01b)],2
 jne .return_al

 mov al,[C_LABEL(cpu_65c816_Y)+1]
 inc byte [C_LABEL(APUI01b)]
 ret

.return_al:
 cmp byte [C_LABEL(APUI01b)],3
 jne .return_xl

 mov al,[C_LABEL(cpu_65c816_A)]
 inc byte [C_LABEL(APUI01b)]
 ret

.return_xl:
 cmp byte [C_LABEL(APUI01b)],4
 jne .return_yl

 mov al,[C_LABEL(cpu_65c816_X)]
 inc byte [C_LABEL(APUI01b)]
 ret

.return_yl:
 cmp byte [C_LABEL(APUI01b)],5
 jne .return_BB

 mov al,[C_LABEL(cpu_65c816_Y)]
 inc byte [C_LABEL(APUI01b)]
 ret

.return_BB:
 cmp byte [C_LABEL(APUI01b)],6
 jne .return_zero

 mov al,0xBB
 inc byte [C_LABEL(APUI01b)]
 ret

.return_zero:
 cmp byte [C_LABEL(APUI01b)],7
 jne .return_FF

 mov al,0
 inc byte [C_LABEL(APUI01b)]
 ret

.return_FF:
 cmp byte [C_LABEL(APUI01b)],8
 jne .return_55

 mov al,0xff
 inc byte [C_LABEL(APUI01b)]
 ret

.return_55:
 cmp byte [C_LABEL(APUI01b)],9
 jne .return_written

 mov al,0x55
 inc byte [C_LABEL(APUI01b)]
 ret

.return_written:
 cmp byte [C_LABEL(APUI01b)],10
 jne .return_special

 mov al,[C_LABEL(APUI01a)]
 mov byte [C_LABEL(APUI01b)],0
 ret

.return_special:
 mov al,[C_LABEL(APUI01c)]  ; This can only be reached in special cases
 ret

ALIGNC
SNES_R2142_SKIP:    ; APUI02
 cmp byte [C_LABEL(APUI02b)],0
 jne .return_xl

 mov al,[C_LABEL(cpu_65c816_A)]
 inc byte [C_LABEL(APUI02b)]
 mov byte [C_LABEL(APUI03b)],0
 ret

.return_xl:
 cmp byte [C_LABEL(APUI02b)],1
 jne .return_yl

 mov al,[C_LABEL(cpu_65c816_X)]
 inc byte [C_LABEL(APUI02b)]
 mov byte [C_LABEL(APUI03b)],1
 ret

.return_yl:
 cmp byte [C_LABEL(APUI02b)],2
 jne .return_zero

 mov al,[C_LABEL(cpu_65c816_Y)]
 inc byte [C_LABEL(APUI02b)]
 mov byte [C_LABEL(APUI03b)],2
 ret

.return_zero:
 cmp byte [C_LABEL(APUI02b)],3
 jne .return_FF

 mov al,0
 inc byte [C_LABEL(APUI02b)]
 ret

.return_FF:
 cmp byte [C_LABEL(APUI02b)],4
 jne .return_55

 mov al,0xff
 inc byte [C_LABEL(APUI02b)]
 ret

.return_55:
 cmp byte [C_LABEL(APUI02b)],5
 jne .return_AA

 mov al,0x55
 inc byte [C_LABEL(APUI02b)]
 ret

.return_AA:
 cmp byte [C_LABEL(APUI02b)],6
 jne .return_written

 mov al,0xAA
 mov byte [C_LABEL(APUI03b)],6
 inc byte [C_LABEL(APUI02b)]
 ret

.return_written:
 mov al,[C_LABEL(APUI02a)]
 mov byte [C_LABEL(APUI02b)],0
 ret

ALIGNC
SNES_R2143_SKIP:    ; APUI03
 cmp byte [C_LABEL(APUI03b)],0
 jne .return_xh

 mov al,[C_LABEL(cpu_65c816_A)+1]
 inc byte [C_LABEL(APUI03b)]
 ret

.return_xh:
 cmp byte [C_LABEL(APUI03b)],1
 jne .return_yh

 mov al,[C_LABEL(cpu_65c816_X)+1]
 inc byte [C_LABEL(APUI03b)]
 ret

.return_yh:
 cmp byte [C_LABEL(APUI03b)],2
 jne .return_al

 mov al,[C_LABEL(cpu_65c816_Y)+1]
 inc byte [C_LABEL(APUI03b)]
 ret

.return_al:
 cmp byte [C_LABEL(APUI03b)],3
 jne .return_xl

 mov al,[C_LABEL(cpu_65c816_A)]
 inc byte [C_LABEL(APUI03b)]
 ret

.return_xl:
 cmp byte [C_LABEL(APUI03b)],4
 jne .return_yl

 mov al,[C_LABEL(cpu_65c816_X)]
 inc byte [C_LABEL(APUI03b)]
 ret

.return_yl:
 cmp byte [C_LABEL(APUI03b)],5
 jne .return_BB

 mov al,[C_LABEL(cpu_65c816_Y)]
 inc byte [C_LABEL(APUI03b)]
 ret

.return_BB:
 cmp byte [C_LABEL(APUI03b)],6
 jne .return_zero

 mov al,0xBB
 inc byte [C_LABEL(APUI03b)]
 ret

.return_zero:
 cmp byte [C_LABEL(APUI03b)],7
 jne .return_FF

 mov al,0
 inc byte [C_LABEL(APUI03b)]
 ret

.return_FF:
 cmp byte [C_LABEL(APUI03b)],8
 jne .return_55

 mov al,0xFF
 inc byte [C_LABEL(APUI03b)]
 ret

.return_55:
 cmp byte [C_LABEL(APUI03b)],9
 jne .return_written

 mov al,0x55
 inc byte [C_LABEL(APUI03b)]
 ret

.return_written:
 mov al,[C_LABEL(APUI03a)]
 mov byte [C_LABEL(APUI03b)],0
 ret

ALIGNC
SNES_W2140_SKIP:    ; APUI00
 mov [C_LABEL(APUI00a)],al
;cmp al,0xff
;je .alt
;mov byte [C_LABEL(APUI00b)],0
 ret
;.alt:
; mov byte [C_LABEL(APUI00b)],7
; ret

ALIGNC
SNES_W2141_SKIP:    ; APUI01
 mov [C_LABEL(APUI01a)],al
 mov byte [C_LABEL(APUI01b)],0
 ret

ALIGNC
SNES_W2142_SKIP:    ; APUI02
 mov [C_LABEL(APUI02a)],al
 mov byte [C_LABEL(APUI02b)],0
 ret

ALIGNC
SNES_W2143_SKIP:    ; APUI03
 mov [C_LABEL(APUI03a)],al
 mov byte [C_LABEL(APUI03b)],0
 ret

ALIGNC
EXPORT_C Make_APU_Skipper
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
