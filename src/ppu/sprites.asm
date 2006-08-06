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

EXTERN Ready_Line_Render,BaseDestPtr
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
EXPORT Sprite_Size_Current_X,skipl
EXPORT_EQU sprsize_small_x,Sprite_Size_Current_X
EXPORT_EQU sprlim_small_x,Sprite_Size_Current_X+1
EXPORT_EQU sprsize_large_x,Sprite_Size_Current_X+2
EXPORT_EQU sprlim_large_x,Sprite_Size_Current_X+3
EXPORT Sprite_Size_Current_Y,skipl
EXPORT_EQU sprsize_small_y,Sprite_Size_Current_Y
EXPORT_EQU sprlim_small_y,Sprite_Size_Current_Y+1
EXPORT_EQU sprsize_large_y,Sprite_Size_Current_Y+2
EXPORT_EQU sprlim_large_y,Sprite_Size_Current_Y+3

OBJ_vflip_fixup:skipb   ; value to XOR with OBJ current line for v-flip
                        ; used for rectangular (undocumented) OBJ
EXPORT Redo_OAM,skipb
EXPORT SPRLatch   ,skipb    ; Sprite Priority Rotation latch flag
EXPORT OBSEL    ,skipb      ; sssnnxbb  sss=sprite size,nn=upper 4k address,bb=offset
EXPORT OAMHigh    ,skipb
EXPORT OAM_Write_Low,skipb
EXPORT Pixel_Allocation_Tag,skipb

section .text
%define PS_Local_Bytes   16
%define PS_Lines         esp+12
%define PS_BaseDestPtr   esp+8
%define PS_Current_Line  esp+4
%define PS_Priority      esp


ALIGNC
EXPORT Reset_Sprites
 pusha
 ; Set eax to 0, as we're setting most everything to 0...
 xor eax,eax

 ; Reset sprite renderer vars
 mov byte [C_LABEL(HiSprite)],0
 mov dword [C_LABEL(HiSpriteAddr)],C_LABEL(OAM)+0x000
 mov dword [C_LABEL(HiSpriteBits)],C_LABEL(OAM)+0x200
 mov dword [C_LABEL(HiSpriteCnt1)],0x8007
 mov dword [C_LABEL(HiSpriteCnt2)],0x0007
 mov byte [Redo_OAM],-1
 mov ecx,[Sprite_Size_Table]
 mov edx,[Sprite_Size_Table+4]
 mov [Sprite_Size_Current_X],ecx
 mov [Sprite_Size_Current_Y],edx
 mov byte [Pixel_Allocation_Tag],1
 mov [C_LABEL(OBBASE)],eax
 mov [C_LABEL(OBNAME)],eax

 ; Reset sprite port vars
 mov [C_LABEL(OAMAddress)],eax
 mov [C_LABEL(OAMAddress_VBL)],eax
 mov [OAMHigh],al
 mov [OAM_Write_Low],al
 mov [SPRLatch],al
 mov [C_LABEL(OBSEL)],al

; Clear pixel allocation tag table
 mov edi,DisplayZ+8
 xor eax,eax
 mov ecx,256/32
 call Do_Clear

 popa
 ret

ALIGNC
EXPORT SNES_R2138 ; OAMDATAREAD
 mov edx,[C_LABEL(OAMAddress)]
 mov al,[OAMHigh]
 cmp edx,0x100  ; if address >= 0x100...
 jb .no_mirror
 and edx,0x10F   ; ignore disconnected lines

.no_mirror:
 xor al,1
 mov [OAMHigh],al
 jnz .read_low

 mov al,[C_LABEL(OAM)+edx*2+1]

 mov edx,[C_LABEL(OAMAddress)]
 inc edx
 and edx,0x1FF  ; address is 9 bits
 mov [C_LABEL(OAMAddress)],edx

 mov [Last_Bus_Value_PPU1],al
 ret

ALIGNC
.read_low:
 mov al,[C_LABEL(OAM)+edx*2]

 mov [Last_Bus_Value_PPU1],al
 ret

ALIGNC
EXPORT SNES_W2101 ; OBSEL
 cmp [C_LABEL(OBSEL)],al
 je .no_change

 UpdateDisplay  ;*
 push ebx
 mov [C_LABEL(OBSEL)],al    ; Get our copy of this
 mov ebx,eax
 shr eax,5
 and eax,byte 7
 mov edx,[Sprite_Size_Table+eax*8]
 mov eax,[Sprite_Size_Table+eax*8+4]
 mov [Sprite_Size_Current_X],edx
 mov [Sprite_Size_Current_Y],eax
 mov eax,ebx
 mov edx,eax
 and ebx,byte 3<<3  ; Name address 0000 0000 000n n000
 and edx,byte 3     ; Base address 0000 0000 0000 0xbb
;shl ebx,10         ; Name is either 0x0000,0x1000,0x2000,0x3000 words
;shl edx,14         ; Base is either 0x0000,0x2000,0x4000,0x6000 words
 shl ebx,8          ; Name is either 0x0000,0x0800,0x1000,0x1800 lines
 shl edx,12         ; Base is either 0x0000,0x1000,0x2000,0x3000 lines
 add ebx,edx
;and edx,0xFFFF
;and ebx,0xFFFF
 and edx,0x3FFF
 and ebx,0x3FFF
;add edx,edx        ; Convert to offsets into tile cache
;add ebx,ebx
;add edx,C_LABEL(TileCache4)
;add ebx,C_LABEL(TileCache4)
 mov [C_LABEL(OBBASE)],edx
 mov [C_LABEL(OBNAME)],ebx
 pop ebx
 mov byte [Redo_OAM],-1
.no_change:
 ret

ALIGNC
EXPORT SNES_W2102 ; OAMADDL
 UpdateDisplay  ;*
 push ebx
 xor ebx,ebx
 mov [OAMHigh],bh
 mov [C_LABEL(OAMAddress)],al
 mov [C_LABEL(OAMAddress_VBL)],al
 pop ebx
 ret

ALIGNC
EXPORT SNES_W2103 ; OAMADDH
 UpdateDisplay  ;*
 push ebx
 mov ebx,[C_LABEL(OAMAddress_VBL)]
 xor edx,edx
 mov bh,1
 mov [OAMHigh],dl
 and bh,al      ; Only want MSB of address
 mov dl,0x80
 mov [C_LABEL(OAMAddress_VBL)+1],bh
 and dl,al      ; Is priority rotation bit set?
 mov [C_LABEL(OAMAddress)],ebx
 mov [SPRLatch],dl
 pop ebx
 ret

ALIGNC
EXPORT SNES_W2104 ; OAMDATA
 push ebx
 cmp byte [HVBJOY], 0
 js .in_vblank

 cmp byte [C_LABEL(INIDISP)], 0
 jns .no_increment  ;.no_change

.in_vblank:
 xor ebx,ebx
 mov edx,[C_LABEL(OAMAddress)]
 mov bl,[OAMHigh]
 cmp edx,0x100  ; if address >= 0x100, byte access
 jnb .byte_access

 xor ebx,byte 1
 mov [OAMHigh],bl
 jnz .write_low

 mov bl,[OAM_Write_Low]
 mov bh,al
 cmp [C_LABEL(OAM)+edx*2],bx
 je .no_change
 UpdateDisplay  ;*
 mov edx,[C_LABEL(OAMAddress)]
 mov byte [Redo_OAM],-1
 mov [C_LABEL(OAM)+edx*2],bx
.no_change:
 mov edx,[C_LABEL(OAMAddress)]
 inc edx
 and edx,0x1FF  ; address is 9 bits
 mov [C_LABEL(OAMAddress)],edx
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
 cmp [C_LABEL(OAM)+edx*2+ebx],al
 je .ba_no_change
 push edx
 UpdateDisplay  ;*
 pop edx
 mov byte [Redo_OAM],-1
 mov [C_LABEL(OAM)+edx*2+ebx],al
.ba_no_change:

 xor ebx,byte 1
 mov [OAMHigh],bl
 jnz .no_increment

 mov edx,[C_LABEL(OAMAddress)]
 inc edx
 and edx,0x1FF  ; address is 9 bits
 mov [C_LABEL(OAMAddress)],edx
 pop ebx
 ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
