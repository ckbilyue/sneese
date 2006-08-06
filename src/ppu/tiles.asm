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

;%define WATCH_RECACHE_SETS
;%define Profile_Recache_Sets
;%define NEVER_RECACHE_TILES
;%define NO_RECACHE_2BPL
%define ALT_RECACHE_4_8_BPL
;%define NO_RECACHE_4BPL
;%define NO_RECACHE_8BPL
;
;
; Tile Functions - In Assembler cos everything else is!
;  Line-from-tile plotters with tile caching
;
; VRAM tile address in %esi + LineAddress(Y) + VRAMAddress...
; Cache tile address varies by depth...
;
; Tile recache
;  esi = cache address   (input)
;      = tile address    (internal)
;  edi = cache address   (internal)
;  eax,ebx,ecx,edx,ebp destroyed
; In all the plotters...
;  esi = cache address   (input)
;  edi = cache address   (internal)
;      = screen address  (input)
; In check-first plotters...
;  dl  = palette bitmask (internal)
;        (except 8-bpl)
;  eax = pixels          (internal)
;  eax,dl destroyed
; In blank tile plotters
;  Nothing
; In no-check plotters...
;  ah  = palette bitmask (internal)
;        (except 8-bpl)
;  al  = pixels          (internal)
;  dl  = pixels          (internal)
;  ax,dl destroyed
;

%define SNEeSe_ppu_tiles_asm

%include "misc.inc"
%include "ppu/ppu.inc"
%include "ppu/tiles.inc"
%include "ppu/screen.inc"

EXTERN_C SNES_Screen8

section .text
EXPORT tiles_text_start
section .data
EXPORT tiles_data_start
section .bss
EXPORT tiles_bss_start

section .data
ALIGND
BPL0_2:
 dd 0x00000000,0xFD000000,0x00FD0000,0xFDFD0000
 dd 0x0000FD00,0xFD00FD00,0x00FDFD00,0xFDFDFD00
 dd 0x000000FD,0xFD0000FD,0x00FD00FD,0xFDFD00FD
 dd 0x0000FDFD,0xFD00FDFD,0x00FDFDFD,0xFDFDFDFD

BPL1_2:
 dd 0x00000000,0xFE000000,0x00FE0000,0xFEFE0000
 dd 0x0000FE00,0xFE00FE00,0x00FEFE00,0xFEFEFE00
 dd 0x000000FE,0xFE0000FE,0x00FE00FE,0xFEFE00FE
 dd 0x0000FEFE,0xFE00FEFE,0x00FEFEFE,0xFEFEFEFE

BPL0_4:
 dd 0x00000000,0xF1000000,0x00F10000,0xF1F10000
 dd 0x0000F100,0xF100F100,0x00F1F100,0xF1F1F100
 dd 0x000000F1,0xF10000F1,0x00F100F1,0xF1F100F1
 dd 0x0000F1F1,0xF100F1F1,0x00F1F1F1,0xF1F1F1F1

BPL1_4:
 dd 0x00000000,0xF2000000,0x00F20000,0xF2F20000
 dd 0x0000F200,0xF200F200,0x00F2F200,0xF2F2F200
 dd 0x000000F2,0xF20000F2,0x00F200F2,0xF2F200F2
 dd 0x0000F2F2,0xF200F2F2,0x00F2F2F2,0xF2F2F2F2

BPL2_4:
 dd 0x00000000,0xF4000000,0x00F40000,0xF4F40000
 dd 0x0000F400,0xF400F400,0x00F4F400,0xF4F4F400
 dd 0x000000F4,0xF40000F4,0x00F400F4,0xF4F400F4
 dd 0x0000F4F4,0xF400F4F4,0x00F4F4F4,0xF4F4F4F4

BPL3_4:
 dd 0x00000000,0xF8000000,0x00F80000,0xF8F80000
 dd 0x0000F800,0xF800F800,0x00F8F800,0xF8F8F800
 dd 0x000000F8,0xF80000F8,0x00F800F8,0xF8F800F8
 dd 0x0000F8F8,0xF800F8F8,0x00F8F8F8,0xF8F8F8F8

BPL0_8:
 dd 0x00000000,0x01000000,0x00010000,0x01010000
 dd 0x00000100,0x01000100,0x00010100,0x01010100
 dd 0x00000001,0x01000001,0x00010001,0x01010001
 dd 0x00000101,0x01000101,0x00010101,0x01010101

BPL1_8:
 dd 0x00000000,0x02000000,0x00020000,0x02020000
 dd 0x00000200,0x02000200,0x00020200,0x02020200
 dd 0x00000002,0x02000002,0x00020002,0x02020002
 dd 0x00000202,0x02000202,0x00020202,0x02020202

BPL2_8:
 dd 0x00000000,0x04000000,0x00040000,0x04040000
 dd 0x00000400,0x04000400,0x00040400,0x04040400
 dd 0x00000004,0x04000004,0x00040004,0x04040004
 dd 0x00000404,0x04000404,0x00040404,0x04040404

BPL3_8:
 dd 0x00000000,0x08000000,0x00080000,0x08080000
 dd 0x00000800,0x08000800,0x00080800,0x08080800
 dd 0x00000008,0x08000008,0x00080008,0x08080008
 dd 0x00000808,0x08000808,0x00080808,0x08080808

BPL4_8:
 dd 0x00000000,0x10000000,0x00100000,0x10100000
 dd 0x00001000,0x10001000,0x00101000,0x10101000
 dd 0x00000010,0x10000010,0x00100010,0x10100010
 dd 0x00001010,0x10001010,0x00101010,0x10101010

BPL5_8:
 dd 0x00000000,0x20000000,0x00200000,0x20200000
 dd 0x00002000,0x20002000,0x00202000,0x20202000
 dd 0x00000020,0x20000020,0x00200020,0x20200020
 dd 0x00002020,0x20002020,0x00202020,0x20202020

BPL6_8:
 dd 0x00000000,0x40000000,0x00400000,0x40400000
 dd 0x00004000,0x40004000,0x00404000,0x40404000
 dd 0x00000040,0x40000040,0x00400040,0x40400040
 dd 0x00004040,0x40004040,0x00404040,0x40404040

BPL7_8:
 dd 0x00000000,0x80000000,0x00800000,0x80800000
 dd 0x00008000,0x80008000,0x00808000,0x80808000
 dd 0x00000080,0x80000080,0x00800080,0x80800080
 dd 0x00008080,0x80008080,0x00808080,0x80808080

ALIGND
EXPORT Tile_Line_8_2
EXPORT Tile_Line_8_4
 dd PLOT8_4BplTile
 dd PLOT8_4BplTile_X

EXPORT Tile_Line_16_2_Even
EXPORT Tile_Line_16_4_Even
 dd PLOT16_4BplTile_Even
 dd PLOT16_4BplTile_Even_X

EXPORT Tile_Line_16_2
EXPORT Tile_Line_16_4
 dd PLOT16_4BplTile
 dd PLOT16_4BplTile_X

EXPORT Tile_Line_8_8
 dd PLOT8_8BplTile
 dd PLOT8_8BplTile_X

EXPORT Tile_Line_16_8
 dd PLOT16_8BplTile
 dd PLOT16_8BplTile_X

section .bss
ALIGNB

EXPORT TileCache2,skipk 256
EXPORT TileCache4,skipk 128
EXPORT TileCache8,skipk 64

EXPORT TilesetAddress,skipl
EXPORT ColourBase,skipb
EXPORT PixMask,skipb

section .text

; In tile decoder (to be rewritten):
;  eax/ebp = pixels
;  ebx/ecx = bitplane LUT addressing
;  dl = line bitplanes OR'd together (clear bits = non-plotted pixels)
;  dh = line counter
;  esi = VRAM bitplane source address
;  edi = index for tile cache (*8)

ALIGNC
EXPORT Recache_Tile_Set
 push ebx
 push ebp
 push esi
 push edi
 mov edi,[esp+20]
 call Recache_Tile_Set_work
 pop edi
 pop esi
 pop ebp
 pop ebx
 ret

ALIGNC
EXPORT Recache_Tile_Set_work
%ifdef NEVER_RECACHE_TILES
 ret
%endif
 push eax
 push ebx
 push ecx
 push edx
 push ebp
 push esi

%ifdef Profile_Recache_Sets
EXTERN_C Tiles_Recached, Sets_Recached
 add [C_LABEL(Tiles_Recached)],edi
 inc dword [C_LABEL(Sets_Recached)]
%endif

%ifdef WATCH_RECACHE_SETS
EXTERN_C BreaksLast
 inc dword [C_LABEL(BreaksLast)]
%endif

%ifndef ALT_RECACHE_4_8_BPL
 xor ebx,ebx
 xor ecx,ecx
%endif

%ifndef NO_RECACHE_2BPL
 push edi
 mov edi,[Tile_Recache_Set_Begin]

%ifdef ALT_RECACHE_4_8_BPL
%define NO_RECACHE_4BPL
%define NO_RECACHE_8BPL
%endif

 shl edi,5      ; index for tile cache (*8)
 lea esi,[C_LABEL(VRAM)+edi*2]  ; address in VRAM of first 2bpl tile to recache

.2bpl_tile_loop:
%ifdef ALT_RECACHE_4_8_BPL
 xor ebx,ebx
 xor ecx,ecx
%endif
 mov dh,32

 mov bl,[esi]
 mov bl,[esi+16*2]
 mov bl,[C_LABEL(TileCache2)+edi*8]
 mov bl,[C_LABEL(TileCache2)+edi*8+16*2]
 mov bl,[C_LABEL(TileCache2)+edi*8+16*4]
 mov bl,[C_LABEL(TileCache2)+edi*8+16*6]
 mov bl,[C_LABEL(TileCache2)+edi*8+16*8]
 mov bl,[C_LABEL(TileCache2)+edi*8+16*10]
 mov bl,[C_LABEL(TileCache2)+edi*8+16*12]
 mov bl,[C_LABEL(TileCache2)+edi*8+16*14]

.2bpl_line_loop:
 ;  Bp0=*(LineAddress+0)
 mov dl,[esi]
 mov bl,0x0F
 mov cl,0xF0
 and cl,dl
 and bl,dl
 shr cl,2
 mov ebp,[BPL0_2+ebx*4]
 mov bl,0x0F
 mov eax,[BPL0_2+ecx]

 ;  Bp1=*(LineAddress+1)
 mov cl,[esi+1]
 and bl,cl
 and cl,0xF0
 shr cl,2
 or ebp,[BPL1_2+ebx*4]
 or eax,[BPL1_2+ecx]

%ifdef ALT_RECACHE_4_8_BPL
 push ebp
 push eax
%endif
 mov [C_LABEL(TileCache2)+edi*8],eax
 add esi,byte 2
 mov [C_LABEL(TileCache2)+edi*8+4],ebp
 inc edi
 dec dh
 jnz .2bpl_line_loop

%ifdef ALT_RECACHE_4_8_BPL
 mov dh,8

 mov bl,[C_LABEL(TileCache4)+edi*4-16*8]
 mov bl,[C_LABEL(TileCache4)+edi*4-16*6]
 mov bl,[C_LABEL(TileCache4)+edi*4-16*4]
 mov bl,[C_LABEL(TileCache4)+edi*4-16*2]

.4bpl_line_loop:
 ;2bpl 0/1/2/3:7, 4bpl 0/1:7, 8bpl 0:7
 ;combine lines from 2-bpl tiles 2 & 3
 mov ebp,[esp+64]
 mov ecx,[esp+64+4]
 pop eax
 pop ebx
 ; shift high tile up and remove bits for combine
 shl eax,2
 and ebp,~0x0C0C0C0C
 shl ebx,2
 and ecx,~0x0C0C0C0C
 and eax,~0x03030303
 and ebx,~0x03030303
 ; combine lines
 or eax,ebp
 or ebx,ecx
 ; save for later
 mov [esp+64-8],eax
 mov [esp+64-8+4],ebx
 ; and store in 4-bpl tile 1 line
 mov [C_LABEL(TileCache4)-8+edi*4],eax
 mov [C_LABEL(TileCache4)-4+edi*4],ebx

 ;combine lines from 2-bpl tiles 0 & 1
 mov eax,[esp+64*2-8]
 mov ebx,[esp+64*2-8+4]
 mov ebp,[esp+64*2-8+64]
 mov ecx,[esp+64*2-8+64+4]
 ; shift high tile up and remove bits for combine
 shl eax,2
 and ebp,~0x0C0C0C0C
 shl ebx,2
 and ecx,~0x0C0C0C0C
 and eax,~0x03030303
 and ebx,~0x03030303
 ; combine lines
 or eax,ebp
 or ebx,ecx
 ; save for later
 mov [esp+64*2+64-8],eax
 mov [esp+64*2+64-8+4],ebx
 ; and store in 4-bpl tile 0 line
 mov [C_LABEL(TileCache4)-64-8+edi*4],eax
 mov [C_LABEL(TileCache4)-64-4+edi*4],ebx

 sub edi,byte 2
 dec dh
 jnz .4bpl_line_loop

 mov bl,[C_LABEL(TileCache8)+edi*2+16*2-16*4]
 mov bl,[C_LABEL(TileCache8)+edi*2+16*2-16*2]

 mov dh,8

.8bpl_line_loop:
 ;combine lines from 4-bpl tiles 0 & 1
 mov ebp,[esp+64*2]
 mov ecx,[esp+64*2+4]
 pop eax
 pop ebx
 ; shift high tile up and remove bits for combine
 shl eax,4
 and ebp,~0xF0F0F0F0
 shl ebx,4
 and ecx,~0xF0F0F0F0
 and eax,~0x0F0F0F0F
 and ebx,~0x0F0F0F0F
 ; combine lines
 or eax,ebp
 or ebx,ecx
 ; store new line 8-bpl line
 mov [C_LABEL(TileCache8)-8+16*2+edi*2],eax
 mov [C_LABEL(TileCache8)-4+16*2+edi*2],ebx

 sub edi,byte 4
 dec dh
 jnz .8bpl_line_loop

 sub esp,byte -128
 add edi,byte 32+16
%endif

 dec dword [esp]
 jnz .2bpl_tile_loop

 pop eax

%endif

%ifndef NO_RECACHE_4BPL
 mov edi,[Tile_Recache_Set_Begin]
 mov edx,[Tile_Recache_Set_End]
 inc edx        ; edx = (Tile_Recache_Set_End / 2) + 1
 sub edx,edi    ; Count of 4bpl tiles to recache

 shl edi,4      ; edi = Tile_Recache_Set_Begin / 2
 add edx,edx

 push edx
 lea esi,[C_LABEL(VRAM)+edi*4]  ; address in VRAM of first 4bpl tile to recache

.4bpl_tile_loop:
 mov dh,8

.4bpl_line_loop:
 mov cl,[C_LABEL(TileCache4)+edi*8]
 ;  Bp0=*(LineAddress+0)
 mov dl,[esi]
 mov bl,0x0F
 mov cl,0xF0
 and cl,dl
 and bl,dl
 shr cl,2
 mov ebp,[BPL0_4+ebx*4]
 mov bl,0x0F
 mov eax,[BPL0_4+ecx]

 ;  Bp1=*(LineAddress+1)
 mov cl,[esi+1]
 and bl,cl
 and cl,0xF0
 shr cl,2
 or ebp,[BPL1_4+ebx*4]
 mov bl,0x0F
 or eax,[BPL1_4+ecx]

 ;  Bp2=*(LineAddress+16)
 mov cl,[esi+16]
 and bl,cl
 and cl,0xF0
 shr cl,2
 or ebp,[BPL2_4+ebx*4]
 mov bl,0x0F
 or eax,[BPL2_4+ecx]

 ;  Bp3=*(LineAddress+17)
 mov cl,[esi+17]
 and bl,cl
 and cl,0xF0
 shr cl,2
 or ebp,[BPL3_4+ebx*4]
 or eax,[BPL3_4+ecx]

 mov [C_LABEL(TileCache4)+edi*8],eax
 add esi,byte 2
 mov [C_LABEL(TileCache4)+edi*8+4],ebp
 inc edi
 dec dh
 jnz .4bpl_line_loop

 add esi,byte 16
 dec dword [esp]
 jnz .4bpl_tile_loop

 pop eax
%endif

%ifndef NO_RECACHE_8BPL
 mov edi,[Tile_Recache_Set_Begin]
 mov edx,[Tile_Recache_Set_End]
 inc edx        ; edx = (Tile_Recache_Set_End / 4) + 1
 sub edx,edi    ; Count of 8bpl tiles to recache

 shl edi,3      ; index for tile cache (*8)
 push edx
 lea esi,[C_LABEL(VRAM)+edi*8]  ; address in VRAM of first 8bpl tile to recache

.8bpl_tile_loop:
 mov dh,8

.8bpl_line_loop:
 mov cl,[C_LABEL(TileCache8)+edi*8]
 ;  Bp0=*(LineAddress+0)
 mov dl,[esi]
 mov bl,0x0F
 mov cl,0xF0
 and cl,dl
 and bl,dl
 shr cl,2
 mov ebp,[BPL0_8+ebx*4]
 mov bl,0x0F
 mov eax,[BPL0_8+ecx]

 ;  Bp1=*(LineAddress+1)
 mov cl,[esi+1]
 and bl,cl
 and cl,0xF0
 shr cl,2
 or ebp,[BPL1_8+ebx*4]
 mov bl,0x0F
 or eax,[BPL1_8+ecx]

 ;  Bp2=*(LineAddress+16)
 mov cl,[esi+16]
 and bl,cl
 and cl,0xF0
 shr cl,2
 or ebp,[BPL2_8+ebx*4]
 mov bl,0x0F
 or eax,[BPL2_8+ecx]

 ;  Bp3=*(LineAddress+17)
 mov cl,[esi+17]
 and bl,cl
 and cl,0xF0
 shr cl,2
 or ebp,[BPL3_8+ebx*4]
 mov bl,0x0F
 or eax,[BPL3_8+ecx]

 ;  Bp4=*(LineAddress+32)
 mov cl,[esi+32]
 and bl,cl
 and cl,0xF0
 shr cl,2
 or ebp,[BPL4_8+ebx*4]
 mov bl,0x0F
 or eax,[BPL4_8+ecx]

 ;  Bp5=*(LineAddress+33)
 mov cl,[esi+33]
 and bl,cl
 and cl,0xF0
 shr cl,2
 or ebp,[BPL5_8+ebx*4]
 mov bl,0x0F
 or eax,[BPL5_8+ecx]

 ;  Bp6=*(LineAddress+48)
 mov cl,[esi+48]
 and bl,cl
 and cl,0xF0
 shr cl,2
 or ebp,[BPL6_8+ebx*4]
 mov bl,0x0F
 or eax,[BPL6_8+ecx]

 ;  Bp7=*(LineAddress+49)
 mov cl,[esi+49]
 and bl,cl
 and cl,0xF0
 shr cl,2
 or ebp,[BPL7_8+ebx*4]
 or eax,[BPL7_8+ecx]

 mov [C_LABEL(TileCache8)+edi*8],eax
 add esi,byte 2
 mov [C_LABEL(TileCache8)+edi*8+4],ebp
 inc edi
 dec dh
 jnz .8bpl_line_loop

 add esi,byte 48
 dec dword [esp]
 jnz .8bpl_tile_loop

 pop eax
%endif
 pop esi
 pop ebp
 pop edx
 pop ecx
 pop ebx
 pop eax
 ret

%macro P8_Plot_8 1-2 0  ;Xflip,Add=0
 and esi,0x3FF*64+8*7
 add esi,[TilesetAddress]

%ifnidni %1,Xflip
 Plot_2 0,4,0,4
 Plot_2 1,5,1,5
 Plot_2 2,6,2,6
 Plot_2 3,7,3,7
%else
 Plot_2 7,3,0,4
 Plot_2 6,2,1,5
 Plot_2 5,1,2,6
 Plot_2 4,0,3,7
%endif
%endmacro

%macro P16_Plot_8 1-2 0 ;Xflip,Add=0
%ifnidni %1,Xflip
 push esi
 call PLOT8_8BplTile
 pop esi
 add esi,byte 64
 add edi,byte 8
 call PLOT8_8BplTile
 sub edi,byte 8
%else
 push esi
 add esi,byte 64
 call PLOT8_8BplTile_X
 pop esi
 add edi,byte 8
 call PLOT8_8BplTile_X
 sub edi,byte 8
%endif
%endmacro

%macro P8_Plot_4 1-2 0    ;Xflip,Add=0
 and esi,0x3FF*64+8*7
 add esi,[TilesetAddress]

%ifnidni %1,Xflip
 Plot_2_Paletted 0,4,0+%2,4+%2
 Plot_2_Paletted 1,5,1+%2,5+%2
 Plot_2_Paletted 2,6,2+%2,6+%2
 Plot_2_Paletted 3,7,3+%2,7+%2
%else
 Plot_2_Paletted 7,3,0+%2,4+%2
 Plot_2_Paletted 6,2,1+%2,5+%2
 Plot_2_Paletted 5,1,2+%2,6+%2
 Plot_2_Paletted 4,0,3+%2,7+%2
%endif
%endmacro

%macro P8_Plot_Half_4 1-2 0 ;Xflip,Add=0
 and esi,0x3FF*64+8*7
 add esi,[TilesetAddress]

%ifnidni %1,Xflip
 Plot_2_Paletted 0,4,0,2
 Plot_2_Paletted 2,6,1,3
%else
 Plot_2_Paletted 6,2,0,2
 Plot_2_Paletted 4,0,1,3
%endif
%endmacro

%macro P16_Plot_Half_4 1-2 0    ;Xflip,Add=0
%ifnidni %1,Xflip
 push esi
 call PLOT8_4BplTile_Even
 pop esi
 add esi,byte 64
 add edi,byte 4
 call PLOT8_4BplTile_Even
 sub edi,byte 4
%else
 push esi
 add esi,byte 64
 call PLOT8_4BplTile_Even_X
 pop esi
 add edi,byte 4
 call PLOT8_4BplTile_Even_X
 sub edi,byte 4
%endif
%endmacro

%macro P16_Plot_4 1-2 0 ;Xflip,Add=0
%ifnidni %1,Xflip
 push esi
 call PLOT8_4BplTile
 pop esi
 add esi,byte 64
 add edi,byte 8
 call PLOT8_4BplTile
 sub edi,byte 8
%else
 push esi
 add esi,byte 64
 call PLOT8_4BplTile_X
 pop esi
 add edi,byte 8
 call PLOT8_4BplTile_X
 sub edi,byte 8
%endif
%endmacro

%macro P8_Plot_2 1-2 0  ;Xflip,Add=0
 P8_Plot_4 %1,%2
%endmacro

%macro P8_Plot_Half_2 1-2 0 ;Xflip,Add=0
 P8_Plot_Half_4 %1,%2
%endmacro

%macro P16_Plot_Half_2 1-2 0    ;Xflip,Add=0
%ifnidni %1,Xflip
 push esi
 call PLOT8_2BplTile_Even
 pop esi
 add esi,byte 64
 add edi,byte 4
 call PLOT8_2BplTile_Even
 sub edi,byte 4
%else
 push esi
 add esi,byte 64
 call PLOT8_2BplTile_Even_X
 pop esi
 add edi,byte 4
 call PLOT8_2BplTile_Even_X
 sub edi,byte 4
%endif
%endmacro

%macro P16_Plot_2 1-2 0 ;Xflip,Add=0
%ifnidni %1,Xflip
 push esi
 call PLOT8_2BplTile
 pop esi
 add esi,byte 64
 add edi,byte 8
 call PLOT8_2BplTile
 sub edi,byte 8
%else
 push esi
 add esi,byte 64
 call PLOT8_2BplTile_X
 pop esi
 add edi,byte 8
 call PLOT8_2BplTile_X
 sub edi,byte 8
%endif
%endmacro

EXPORT tile_plotters_text_start
ALIGNC
PLOT8_8BplTile:
 P8_Plot_8 noflip
 ret

ALIGNC
PLOT8_8BplTile_X:
 P8_Plot_8 Xflip
 ret

ALIGNC
PLOT8_4BplTile:
 P8_Plot_4 noflip
 ret

ALIGNC
PLOT8_4BplTile_X:
 P8_Plot_4 Xflip
 ret

ALIGNC
PLOT8_2BplTile:
 P8_Plot_2 noflip
 ret

ALIGNC
PLOT8_2BplTile_X:
 P8_Plot_2 Xflip
 ret

PLOT8_4BplTile_Even:
 P8_Plot_Half_4 noflip
 ret

PLOT8_4BplTile_Even_X:
 P8_Plot_Half_4 Xflip
 ret

PLOT8_2BplTile_Even:
 P8_Plot_Half_2 noflip
 ret

PLOT8_2BplTile_Even_X:
 P8_Plot_Half_2 Xflip
 ret

ALIGNC
PLOT16_4BplTile_Even:
 P16_Plot_Half_4 noflip
 ret

ALIGNC
PLOT16_4BplTile_Even_X:
 P16_Plot_Half_4 Xflip
 ret

ALIGNC
PLOT16_2BplTile_Even:
 P16_Plot_Half_2 noflip
 ret

ALIGNC
PLOT16_2BplTile_Even_X:
 P16_Plot_Half_2 Xflip
 ret

ALIGNC
PLOT16_8BplTile:
 P16_Plot_8 noflip
 ret

ALIGNC
PLOT16_8BplTile_X:
 P16_Plot_8 Xflip
 ret

ALIGNC
PLOT16_4BplTile:
 P16_Plot_4 noflip
 ret

ALIGNC
PLOT16_4BplTile_X:
 P16_Plot_4 Xflip
 ret

ALIGNC
PLOT16_2BplTile:
 P16_Plot_2 noflip
 ret

ALIGNC
PLOT16_2BplTile_X:
 P16_Plot_2 Xflip
 ret

ALIGNC
EXPORT Invalidate_Tile_Caches
 mov dword [Tile_Recache_Set_Begin],0
 mov dword [Tile_Recache_Set_End],0x3FF
 ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
