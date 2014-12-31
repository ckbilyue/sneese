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

;
; Sprite render functions
;
; In all the sprite renderers...
;  eax = (internal)
;  ebx = (internal)
;  cl  = sprite counter for priority (internal)
;  ch  = sprite counter for set      (internal)
;  dl  = sprite priority identifier  (input)
;  dh  = (internal)
;  esi = current sprite              (internal)
;  edi = (internal)
;
; OAM decoder generates table with plot data per sprite tile-line
;  (X position, line-in-tile cache address, palette, X-flip, priority for
;  each sprite scanline, and time/range flags for each scanline)
; 14b address, 2bit XYflip, 3bit palette, 2bit priority, 9bit X pos
; (may pack priority, palette, X-flip, and bit 8 X pos in 1b)
; 4b/sprite line
; 34 sprite lines/scanline max + count + time/range + priority + pri flag
;  (34 * 4b = 136b + 8b)
; count = total sprites/tiles, and total sprites only including last per
;  priority
; 239 lines * 145b = 34,416b (~33.61k)
; However, with this, other tables can be removed (OAM_*, 1,664b (1.625k))
; Plotters will be greatly simplified, with less redundant handling

;#define Profile_Recache_OAM
%define ALT_CLEAR

%define SNEeSe_ppu_sprites_asm

%include "misc.inc"
%include "clear.inc"
%include "ppu/tiles.inc"
%include "ppu/screen.inc"
%include "ppu/ppu.inc"

section .text
EXPORT sprites_text_start
section .data
EXPORT sprites_data_start
section .bss
EXPORT sprites_bss_start

EXTERN HVBJOY

section .data
ALIGND
palette_obj:
 dd 0x8F8F8F8F, 0x9F9F9F9F, 0xAFAFAFAF, 0xBFBFBFBF
 dd 0xCFCFCFCF, 0xDFDFDFDF, 0xEFEFEFEF, 0xFFFFFFFF

; Sprite offset tables moved to ScreenL.S
; abc - a = X or Y, b = s(ize) or l(imit), c = s(mall) or l(arge)
; Xss, Xls, Xsl, Xll, Yss, Yls, Ysl, Yll
Sprite_Size_Table:
db  1, -7,  2,-15,  1, -7,  2,-15   ;   8x8, 16x16
db  1, -7,  4,-31,  1, -7,  4,-31   ;   8x8, 32x32
db  1, -7,  8,-63,  1, -7,  8,-63   ;   8x8, 64x64
db  2,-15,  4,-31,  2,-15,  4,-31   ; 16x16, 32x32
db  2,-15,  8,-63,  2,-15,  8,-63   ; 16x16, 64x64
db  4,-31,  8,-63,  4,-31,  8,-63   ; 32x32, 64x64
db  2,-15,  4,-31,  4,-31,  8,-63   ; 16x32, 32x64
db  2,-15,  4,-31,  4,-31,  4,-31   ; 16x32, 32x32

section .bss
ALIGNB
;Line counts when last OBJ of specified priority was added
EXPORT OAM_Count_Priority,skipl 240

;OBJ counts (low byte) and OBJ line counts (high byte)
EXPORT OAM_Count,skipw 240

;Time/range overflow flags
EXPORT OAM_TimeRange,skipb 240
;'Complex' priority in-use flags
EXPORT OAM_Low_Before_High,skipb 240
;Priorities for 'complex' priority detection
EXPORT OAM_Lowest_Priority,skipb 240
;Tail entry for ring buffers
EXPORT OAM_Tail,skipb 240

;239 ring buffers of 34 OBJ line descriptors (32-bit)
EXPORT OAM_Lines,skipl 34*239

; AAAA AAAA AAAA AAxx YXPP CCCX XXXX XXXX
;  A - OAM sprite line-in-tile address
;  YXPP CCC  - bits 1-7 of OAM attribute word
;  X - X position

ALIGNB
EXPORT OAM,skipb 512+32     ; Buffer for OAM
EXPORT SpriteCount,skipl
EXPORT HiSprite ,skipl
EXPORT HiSpriteCnt1,skipl   ; First set size and bit offset
EXPORT HiSpriteCnt2,skipl   ; Second set size and bit offset
EXPORT OBBASE,skipl         ; VRAM location of sprite tiles 00-FF
EXPORT OBNAME,skipl         ; VRAM location of sprite tiles 100-1FF
EXPORT OAMAddress,skipl
EXPORT OAMAddress_VBL,skipl ; Restore this at VBL
EXPORT HiSpriteAddr,skipl   ; OAM address of sprite in 512b table
EXPORT HiSpriteBits,skipl   ; OAM address of sprite in 32b table

ALIGNB
EXPORT Redo_OAM,skipb
EXPORT SPRLatch   ,skipb    ; Sprite Priority Rotation latch flag
EXPORT OBSEL      ,skipb    ; sssnnxbb  sss=sprite size,nn=upper 4k address,bb=offset
EXPORT OBSEL_write,skipb
EXPORT OAMHigh    ,skipb
EXPORT OAM_Write_Low,skipb

section .text
%define PS_Local_Bytes   16
%define PS_Lines         esp+12
%define PS_BaseDestPtr   esp+8
%define PS_Current_Line  esp+4
%define PS_Priority      esp


ALIGNC
EXPORT Reset_Sprites_asm
 pusha
EXTERN Reset_Sprites
 call Reset_Sprites
 popa
 ret

ALIGNC
EXPORT SNES_R2138 ; OAMDATAREAD
 mov edx,[OAMAddress]
 mov al,[OAMHigh]
 cmp edx,0x100  ; if address >= 0x100...
 jb .no_mirror
 and edx,0x10F   ; ignore disconnected lines

.no_mirror:
 xor al,1
 mov [OAMHigh],al
 jnz .read_low

 mov al,[OAM+edx*2+1]

 mov edx,[OAMAddress]
 inc edx
 and edx,0x1FF  ; address is 9 bits
 mov [OAMAddress],edx

 mov [Last_Bus_Value_PPU1],al
 ret

ALIGNC
.read_low:
 mov al,[OAM+edx*2]

 mov [Last_Bus_Value_PPU1],al
 ret

ALIGNC
EXPORT SNES_W2101 ; OBSEL
 cmp [OBSEL_write],al
 je .no_change

 UpdateDisplay  ;*
 mov [OBSEL_write],al  ; Get our copy of this

.no_change:
 ret

ALIGNC
EXPORT SNES_W2102 ; OAMADDL
 UpdateDisplay  ;*
 mov edx,[OAMAddress_VBL]
 mov byte [OAMHigh],0
 mov dl,al
 mov [OAMAddress_VBL],al
 mov [OAMAddress],edx
 ret

ALIGNC
EXPORT SNES_W2103 ; OAMADDH
 UpdateDisplay  ;*
 push ebx
 mov ebx,[OAMAddress_VBL]
 mov bh,1
 mov [OAMHigh],dl
 and bh,al      ; Only want MSB of address
 mov dl,0x80
 mov [OAMAddress_VBL+1],bh
 and dl,al      ; Is priority rotation bit set?
 mov [OAMAddress],ebx
 mov [SPRLatch],dl
 pop ebx
 ret

ALIGNC
EXPORT SNES_W2104 ; OAMDATA
 push ebx
 cmp byte [HVBJOY], 0
 js .in_vblank

 cmp byte [INIDISP], 0
 jns .no_increment  ;.no_change

.in_vblank:
 xor ebx,ebx
 mov edx,[OAMAddress]
 mov bl,[OAMHigh]
 cmp edx,0x100  ; if address >= 0x100, byte access
 jnb .byte_access

 xor ebx,byte 1
 mov [OAMHigh],bl
 jnz .write_low

 mov bl,[OAM_Write_Low]
 mov bh,al
 cmp [OAM+edx*2],bx
 je .no_change
 UpdateDisplay  ;*
 mov edx,[OAMAddress]
 mov byte [Redo_OAM],-1
 mov [OAM+edx*2],bx
.no_change:
 mov edx,[OAMAddress]
 inc edx
 and edx,0x1FF  ; address is 9 bits
 mov [OAMAddress],edx
.no_increment:
.ignore_write:
 pop ebx
 ret
ALIGNC
.write_low:
 mov [OAM_Write_Low],al
 pop ebx
 ret

ALIGNC
.byte_access:
 and edx,0x10F   ; ignore disconnected lines
 cmp [OAM+edx*2+ebx],al
 je .ba_no_change
 push edx
 UpdateDisplay  ;*
 pop edx
 mov byte [Redo_OAM],-1
 mov [OAM+edx*2+ebx],al
.ba_no_change:

 xor ebx,byte 1
 mov [OAMHigh],bl
 jnz .no_increment

 mov edx,[OAMAddress]
 inc edx
 and edx,0x1FF  ; address is 9 bits
 mov [OAMAddress],edx
 pop ebx
 ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
