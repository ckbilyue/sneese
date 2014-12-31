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

; Mode 7 matrix rendering / hardware port emulation.

%define SNEeSe_ppu_mode7_asm

%include "misc.inc"
%include "ppu/sprites.inc"
%include "ppu/screen.inc"
%include "ppu/ppu.inc"

section .text
EXPORT mode7_start

;%define old_sprites

section .bss
ALIGNB
EXPORT Mode7_AHX,skipl  ; M7A * (BG1HOFS - M7X) + (M7X << 8)
EXPORT Mode7_VY ,skipl  ; BG1VOFS - M7Y
EXPORT Mode7_CHXY,skipl ; M7C * (BG1HOFS - M7X) + (M7Y << 8)
; M7A * (BG1HOFS - M7X) + (M7X << 8) + M7B * (line + BG1VOFS - M7Y)
EXPORT Mode7_Line_X,skipl
; M7C * (BG1HOFS - M7X) + (M7Y << 8) + M7D * (line + BG1VOFS - M7Y)
EXPORT Mode7_Line_Y,skipl


EXPORT M7A      ,skipl
EXPORT M7B      ,skipl
EXPORT M7C      ,skipl
EXPORT M7D      ,skipl
EXPORT M7X_13   ,skipl
EXPORT M7Y_13   ,skipl
EXPORT M7H_13   ,skipl
EXPORT M7V_13   ,skipl
EXPORT M7X      ,skipl
EXPORT M7Y      ,skipl
EXPORT M7H      ,skipl
EXPORT M7V      ,skipl

;M7A, M7C are taken from here to help handle X-flip
EXPORT M7A_X    ,skipl
EXPORT M7C_X    ,skipl

;M7A, M7C are taken from here to help handle X-flip and mosaic
EXPORT M7A_XM   ,skipl
EXPORT M7C_XM   ,skipl


EXPORT MPY,skipl    ; Mode 7 multiplication result
MPYL equ MPY    ; Mode 7 multiplication result: low byte
MPYM equ MPY+1  ; Mode 7 multiplication result: middle byte
MPYH equ MPY+2  ; Mode 7 multiplication result: high byte

EXPORT EXTBG_Mask,skipb ; mask applied to BG enable for EXTBG
EXPORT M7SEL,skipb      ; ab0000yx  ab=mode 7 repetition info,y=flip vertical,x=flip horizontal
EXPORT Redo_M7,skipb    ; vhyxdcba
EXPORT M7_Last_Write,skipb
EXPORT M7_Used,skipb
EXPORT M7_Unused,skipb
EXPORT Redo_16x8,skipb

; BG1 area |  BG2 area = displayed mode 7 background
; BG2 area = EXTBG, high priority

; BG1 area + BG2 area on main screen; both screens in 8-bit rendering
MERGED_WIN_DATA Mode7_Main,4
; BG1 area + BG2 area on sub screen (currently unused)
MERGED_WIN_DATA Mode7_Sub,4

;!BG1 area on main screen; both screens in 8-bit rendering
MERGED_WIN_DATA BG1_Main_Off,3
;!BG1 area on sub screen (currently unused)
MERGED_WIN_DATA BG1_Sub_Off,3

;!BG2 area on main screen; both screens in 8-bit rendering
MERGED_WIN_DATA BG2_Main_Off,3
;!BG2 area on sub screen (currently unused)
MERGED_WIN_DATA BG2_Sub_Off,3

;!BG1 area &  BG2 area = EXTBG, low priority
;main screen; both in 8-bit
MERGED_WIN_DATA Mode7_Main_EXTBG_Low,3
;sub screen
MERGED_WIN_DATA Mode7_Sub_EXTBG_Low,3

; BG1 area &  BG2 area = EXTBG, normal priority
;main screen; both in 8-bit
MERGED_WIN_DATA Mode7_Main_EXTBG_Normal,3
;sub screen
MERGED_WIN_DATA Mode7_Sub_EXTBG_Normal,3

; BG1 area & !BG2 area = no EXTBG
;main screen; both in 8-bit
MERGED_WIN_DATA Mode7_Main_EXTBG_Off,3
;sub screen
MERGED_WIN_DATA Mode7_Sub_EXTBG_Off,3

%define SM7_Local_Bytes 16
%define SM7_Current_Line esp+12
%define SM7_BaseDestPtr esp+8
%define SM7_Lines esp+4
%define SM7_Layers esp

; edx = address of window 1 bands
; esi = address of window 2 bands
; cl = count of window 1 bands
; ch = count of window 2 bands
; ebp = 0
; edi = address for output window area (BG_WIN_DATA)

section .text
ALIGNC
EXPORT Reset_Mode_7
%if 0
extern _Reset_Mode_7
 pusha
 call _Reset_Mode_7
 popa
 ret
%else
 ; Set eax to 0, as we're setting most everything to 0...
 xor eax,eax

 mov [M7SEL],al
 mov byte [Redo_M7],0xFF
 mov byte [M7_Last_Write],al
 mov byte [Redo_16x8],0
 mov [MPY],eax
 mov [M7A],eax
 mov [M7B],eax
 mov [M7C],eax
 mov [M7D],eax
 mov [M7X_13],eax
 mov [M7Y_13],eax
;mov [M7H_13],eax
;mov [M7V_13],eax
 mov [M7X],eax
 mov [M7Y],eax
 mov [M7H],eax
 mov [M7V],eax

 ret
%endif

Do_16x8_Multiply:
 push ebx
 movsx ebx,byte [M7B+1]
 mov byte [Redo_16x8],0
 imul ebx,[M7A]    ; I think signed is used makes most sense!
 mov [MPY],ebx
 mov al,[edx]
 pop ebx
 ret

ALIGNC
EXPORT SNES_R2134 ; MPYL
 mov edx,MPYL
 cmp byte [Redo_16x8],0
 jnz Do_16x8_Multiply
 mov al,[edx]
 mov [Last_Bus_Value_PPU1],al
 ret

ALIGNC
EXPORT SNES_R2135 ; MPYM
 mov edx,MPYM
 cmp byte [Redo_16x8],0
 jnz Do_16x8_Multiply
 mov al,[edx]
 mov [Last_Bus_Value_PPU1],al
 ret

ALIGNC
EXPORT SNES_R2136 ; MPYH
 mov edx,MPYH
 cmp byte [Redo_16x8],0
 jnz Do_16x8_Multiply
 mov al,[edx]
 mov [Last_Bus_Value_PPU1],al
 ret

ALIGNC
EXPORT SNES_W_M7H ; 210D - handle mode 7 register update
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7H],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [M7H],ebx
 mov dl,0x40    ; Recalculate H
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W_M7V ; 210E - handle mode 7 register update
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7V],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [M7V],ebx
 mov dl,0x80    ; Recalculate V
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211A ; M7SEL   ; New for 0.12
 cmp al,[M7SEL]
 je .no_change
 UpdateDisplay  ;*
 push ebx
 push eax
 mov [M7SEL],al

 shl al,8
 mov ebx,[M7A]
 mov eax,[M7C]
 sbb edx,edx
 xor ebx,edx
 xor eax,edx
 and edx,byte 1
 add ebx,edx
 add eax,edx
 mov [M7A_X],ebx
 mov [M7C_X],eax

 pop eax
 pop ebx

.no_change:
 ret

ALIGNC
EXPORT SNES_W211B ; M7A
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7A],ebx
 je .no_change

 UpdateDisplay  ;*M7
 ; Used for matrix render and 16-bit M7A * 8-bit = 24-bit multiply
 mov [M7A],ebx
 mov dl,0x01    ; Recalculate A
 or [Redo_M7],dl
 mov byte [Redo_16x8],-1
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211C ; M7B
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7B],ebx
 je .no_change

 UpdateDisplay  ;*M7
 ; Used for matrix render and 16-bit * 8-bit M7B high byte = 24-bit multiply
 mov [M7B],ebx
 mov dl,0x02    ; Recalculate B
 or [Redo_M7],dl
 mov byte [Redo_16x8],-1
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211D ; M7C
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7C],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [M7C],ebx
 mov dl,0x04    ; Recalculate C
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211E ; M7D
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7D],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [M7D],ebx
 mov dl,0x08    ; Recalculate D
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211F ; M7X
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7X],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [M7X],ebx
 mov dl,0x10    ; Recalculate X
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W2120 ; M7Y
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7Y],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [M7Y],ebx
 mov dl,0x20    ; Recalculate Y
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
