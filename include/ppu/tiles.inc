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

%ifndef SNEeSe_ppu_tiles_inc
%define SNEeSe_ppu_tiles_inc

%ifndef SNEeSe_ppu_tiles_asm
EXTERN Tile_Line_8_2,Tile_Line_8_4
EXTERN Tile_Line_16_2_Even,Tile_Line_16_4_Even
EXTERN Tile_Line_16_2,Tile_Line_16_4
EXTERN Sprite_Tile_Plot_8_4,Sprite_Tile_Plot_16_4
EXTERN Sprite_Tile_Plot_32_4,Sprite_Tile_Plot_64_4
EXTERN Tile_Line_8_8,Tile_Line_16_8
EXTERN TileCache2,TileCache4,TileCache8

EXTERN TilesetAddress
EXTERN ColourBase
EXTERN PixMask

EXTERN Recache_Tile_Set_work
EXTERN Invalidate_Tile_Caches
%endif

;Plot_2 and Plot_2_Z assume the following register contents:
; ebx = destination address of line-of-tile (Z-buffer)
; esi = line-of-tile address
; edi = destination address of line-of-tile (display surface)
;  cl = Z-position of pixels plotted
; Additionally, al & dl are trashed
;Plot_2_Paletted and Plot_2_Z_Paletted also assume:
;  dh = palette mask
;All plotters read from [esi+%1,%2], write to [edi+%3,%4], and do
; not plot zero pixels
;The sprite plotters in tiles.asm read from [ebx+%3,%4], checks Z value,
; and if pixels read are to be plotted, their Z-positions are tagged with
; a high value, even if they are not plotted - used to emulate sprite's
; first-come-first-serve pixel allocation.

;Pixel_1_in, Pixel_2_in, Pixel_1_out, Pixel_2_out
%macro Plot_2_Z_Paletted 4
 mov al,[ebx + %3]
 cmp al,cl
 jae %%no_plot_1

 mov al,[esi + %1]
 and al,dh
 jz %%no_plot_1

 mov [ebx + %3],cl
 mov [edi + %3],al
%%no_plot_1:

 mov dl,[ebx + %4]
 cmp dl,cl
 jae %%no_plot_2

 mov dl,[esi + %2]
 and dl,dh
 jz %%no_plot_2

 mov [ebx + %4],cl
 mov [edi + %4],dl
%%no_plot_2:
%endmacro

;Pixel_1_in, Pixel_2_in, Pixel_1_out, Pixel_2_out
%macro Plot_2_Z 4
 mov al,[ebx + %3]
 cmp al,cl
 jae %%no_plot_1

 mov al,[esi + %1]
 test al,al
 jz %%no_plot_1

 mov [ebx + %3],cl
 mov [edi + %3],al
%%no_plot_1:

 mov dl,[ebx + %4]
 cmp dl,cl
 jae %%no_plot_2

 mov dl,[esi + %2]
 test dl,dl
 jz %%no_plot_2

 mov [ebx + %4],cl
 mov [edi + %4],dl
%%no_plot_2:
%endmacro

;Pixel_1_in, Pixel_2_in, Pixel_1_out, Pixel_2_out
%macro Plot_2_Paletted 4
 mov al,[esi + %1]
 and al,dh
 jz %%no_plot_1

;mov [ebx + %3],cl
 mov [edi + %3],al
%%no_plot_1:

 mov dl,[esi + %2]
 and dl,dh
 jz %%no_plot_2

;mov [ebx + %4],cl
 mov [edi + %4],dl
%%no_plot_2:
%endmacro

;Pixel_1_in, Pixel_2_in, Pixel_1_out, Pixel_2_out
%macro Plot_2 4
 mov al,[esi + %1]
 test al,al
 jz %%no_plot_1

;mov [ebx + %3],cl
 mov [edi + %3],al
%%no_plot_1:

 mov dl,[esi + %2]
 test dl,dl
 jz %%no_plot_2

;mov [ebx + %4],cl
 mov [edi + %4],dl
%%no_plot_2:
%endmacro

;First_pixel_out
%macro Plot_4_base 1
 mov edx,eax
 shr edx,16
 test eax,0xFFFF
 jz %%skip2_not34
 test al,al
 jz %%skip1
 test ah,ah
 jz %%put1
 test dl,dl
 jz %%put12_skip3
 test dh,dh
 jz %%put123_skip4
 mov [edi + (%1)],eax
 jmp %%skip4

%%put12_skip3:
 mov [edi + (%1)],ax
 test dh,dh
 jnz %%skip3
 jmp %%skip4

%%put123_skip4:
 mov [edi + (%1)],ax
 mov [edi + (%1) + 2],dl
 jmp %%skip4

%%skip1:
 mov [edi + (%1) + 1],ah
 jmp %%skip2

%%put1:
 mov [edi + (%1)],al

%%skip2:
 test edx,edx
 jz %%skip4
%%skip2_not34:
 test dl,dl
 jz %%skip3
 test dh,dh
 jz %%put3_skip4
 mov [edi + (%1) + 2],dx
 jmp %%skip4

%%put3_skip4:
 mov [edi + (%1) + 2],dl
 jmp %%skip4

%%skip3:
 mov [edi + (%1) + 3],dh

%%skip4:
%endmacro

;Source_address, First_pixel_in, First_pixel_out
%macro Plot_4_Paletted_noflip 3
 mov eax,[%1 + %2]
 and eax,ebp
 jz %%skip4
 Plot_4_base %3
%%skip4:
%endmacro

;Source_address, First_pixel_in, First_pixel_out
%macro Plot_4_Paletted_Xflip 3
 mov eax,[%1 + %2]
 and eax,ebp
 jz %%skip4
 bswap eax
 Plot_4_base %3
%%skip4:
%endmacro

;Source_address, First_pixel_in, First_pixel_out, Clipmask
%macro Plot_4_Paletted_Clip_noflip 4
 mov eax,[%1 + %2]
 mov edx,[%4]
 and eax,edx
 jz %%skip4
 and eax,ebp
 Plot_4_base %3
%%skip4:
%endmacro

;Source_address, First_pixel_in, First_pixel_out, Clipmask
%macro Plot_4_Paletted_Clip_Xflip 4
 mov eax,[%1 + %2]
 mov edx,[%4]
 bswap eax
 and eax,edx
 jz %%skip4
 and eax,ebp
 Plot_4_base %3
%%skip4:
%endmacro

;Source_address, First_pixel_in, First_pixel_out
%macro Plot_4_noflip 3
 mov eax,[%1 + %2]
 test eax,eax
 jz %%skip4
 Plot_4_base %3
%%skip4:
%endmacro

;Source_address, First_pixel_in, First_pixel_out
%macro Plot_4_Xflip 3
 mov eax,[%1 + %2]
 test eax,eax
 jz %%skip4
 bswap eax
 Plot_4_base %3
%%skip4:
%endmacro

;Source_address, First_pixel_in, First_pixel_out, Clipmask
%macro Plot_4_Clip_noflip 4
 mov eax,[%1 + %2]
 mov edx,[%4]
 and eax,edx
 jz %%skip4
 Plot_4_base %3
%%skip4:
%endmacro

;Source_address, First_pixel_in, First_pixel_out, Clipmask
%macro Plot_4_Clip_Xflip 4
 mov eax,[%1 + %2]
 mov edx,[%4]
 bswap eax
 and eax,edx
 jz %%skip4
 Plot_4_base %3
%%skip4:
%endmacro

;Source_address, First_pixel_in, First_pixel_out
%macro Plot_4_Even_Paletted_noflip 3
 xor eax,edx
 xor edx,edx
 mov al,[%1 + %2 + 6]
 mov dl,[%1 + %2 + 2]
 shl eax,8
 shl edx,8
 mov al,[%1 + %2 + 4]
 shl eax,16
 mov dl,[%1]
 or eax,edx

 jz %%skip4
 and eax,ebp
 Plot_4_base %3
%%skip4:
%endmacro

;Source_address, First_pixel_in, First_pixel_out
%macro Plot_4_Even_Paletted_Xflip 3
 xor eax,edx
 xor edx,edx
 mov al,[%1]
 mov dl,[%1 + %2 + 4]
 shl eax,8
 shl edx,8
 mov al,[%1 + %2 + 2]
 shl eax,16
 mov dl,[%1 + %2 + 6]
 or eax,edx

 jz %%skip4
 and eax,ebp
 Plot_4_base %3
%%skip4:
%endmacro

;Source_address, First_pixel_in, First_pixel_out, Clipmask
%macro Plot_4_Even_Paletted_Clip_noflip 4
 xor eax,edx
 xor edx,edx
 mov al,[%1 + %2 + 6]
 mov dl,[%1 + %2 + 2]
 shl eax,8
 shl edx,8
 mov al,[%1 + %2 + 4]
 shl eax,16
 mov dl,[%1]
 or eax,edx
 mov edx,[%4]
 and eax,edx

 jz %%skip4
 and eax,ebp
 Plot_4_base %3
%%skip4:
%endmacro

;Source_address, First_pixel_in, First_pixel_out, Clipmask
%macro Plot_4_Even_Paletted_Clip_Xflip 4
 xor eax,edx
 xor edx,edx
 mov al,[%1]
 mov dl,[%1 + %2 + 4]
 shl eax,8
 shl edx,8
 mov al,[%1 + %2 + 2]
 shl eax,16
 mov dl,[%1 + %2 + 6]
 or eax,edx
 mov edx,[%4]
 and eax,edx

 jz %%skip4
 and eax,ebp
 Plot_4_base %3
%%skip4:
%endmacro

;Multi-line, Source_address, First_pixel_out, Clipmask
%macro Plot_4_Even_Paletted_Lines_Clip_noflip 4
%if (%1)
 push edi
%endif
%%loop:
 Plot_4_Even_Paletted_Clip_noflip (%2),0,(%3),(%4)
%if (%1)
 add esi,ecx
 add edi,GfxBufferLinePitch
 dec ebx
 jnz %%loop
 pop edi
%endif
%endmacro

;Multi-line, Source_address, First_pixel_out, Clipmask
%macro Plot_4_Even_Paletted_Lines_Clip_Xflip 4
%if (%1)
 push edi
%endif
%%loop:
 Plot_4_Even_Paletted_Clip_Xflip (%2),0,(%3),(%4)
%if (%1)
 add esi,ecx
 add edi,GfxBufferLinePitch
 dec ebx
 jnz %%loop
 pop edi
%endif
%endmacro

;Multi-line, Source_address, First_pixel_out
%macro Plot_8_Paletted_Lines_noflip 3
%if (%1)
 push edi
%endif
%%loop:
 Plot_4_Paletted_noflip (%2),0,(%3)+0
 Plot_4_Paletted_noflip (%2),4,(%3)+4
%if (%1)
 add esi,ecx
 add edi,GfxBufferLinePitch
 dec ebx
 jnz %%loop
 pop edi
%endif
%endmacro

;Multi-line, Source_address, First_pixel_out
%macro Plot_8_Paletted_Lines_Xflip 3
%if (%1)
 push edi
%endif
%%loop:
 Plot_4_Paletted_Xflip (%2),0,(%3)+4
 Plot_4_Paletted_Xflip (%2),4,(%3)+0
%if (%1)
 add esi,ecx
 add edi,GfxBufferLinePitch
 dec ebx
 jnz %%loop
 pop edi
%endif
%endmacro

;Multi-line, Source_address, First_pixel_out, Clipmask
%macro Plot_8_Paletted_Lines_Clip_noflip 4
%if (%1)
 push edi
%endif
%%loop:
 Plot_4_Paletted_Clip_noflip (%2),0,(%3)+0,(%4)+0
 Plot_4_Paletted_Clip_noflip (%2),4,(%3)+4,(%4)+4
%if (%1)
 add esi,ecx
 add edi,GfxBufferLinePitch
 dec ebx
 jnz %%loop
 pop edi
%endif
%endmacro

;Multi-line, Source_address, First_pixel_out, Clipmask
%macro Plot_8_Paletted_Lines_Clip_Xflip 4
%if (%1)
 push edi
%endif
%%loop:
 Plot_4_Paletted_Clip_Xflip (%2),0,(%3)+4,(%4)+4
 Plot_4_Paletted_Clip_Xflip (%2),4,(%3)+0,(%4)+0
%if (%1)
 add esi,ecx
 add edi,GfxBufferLinePitch
 dec ebx
 jnz %%loop
 pop edi
%endif
%endmacro

;Multi-line, Source_address, First_pixel_out
%macro Plot_8_Lines_noflip 3
%if (%1)
 push edi
%endif
%%loop:
 Plot_4_noflip (%2),0,(%3)+0
 Plot_4_noflip (%2),4,(%3)+4
%if (%1)
 add esi,ecx
 add edi,GfxBufferLinePitch
 dec ebx
 jnz %%loop
 pop edi
%endif
%endmacro

;Multi-line, Source_address, First_pixel_out
%macro Plot_8_Lines_Xflip 3
%if (%1)
 push edi
%endif
%%loop:
 Plot_4_Xflip (%2),0,(%3)+4
 Plot_4_Xflip (%2),4,(%3)+0
%if (%1)
 add esi,ecx
 add edi,GfxBufferLinePitch
 dec ebx
 jnz %%loop
 pop edi
%endif
%endmacro

;Multi-line, Source_address, First_pixel_out, Clipmask
%macro Plot_8_Lines_Clip_noflip 4
%if (%1)
 push edi
%endif
%%loop:
 Plot_4_Clip_noflip (%2),0,(%3)+0,(%4)+0
 Plot_4_Clip_noflip (%2),4,(%3)+4,(%4)+4
%if (%1)
 add esi,ecx
 add edi,GfxBufferLinePitch
 dec ebx
 jnz %%loop
 pop edi
%endif
%endmacro

;Multi-line, Source_address, First_pixel_out, Clipmask
%macro Plot_8_Lines_Clip_Xflip 4
%if (%1)
 push edi
%endif
%%loop:
 Plot_4_Clip_Xflip (%2),0,(%3)+4,(%4)+4
 Plot_4_Clip_Xflip (%2),4,(%3)+0,(%4)+0
%if (%1)
 add esi,ecx
 add edi,GfxBufferLinePitch
 dec ebx
 jnz %%loop
 pop edi
%endif
%endmacro

%endif ; !defined(SNEeSe_ppu_tiles_inc)
