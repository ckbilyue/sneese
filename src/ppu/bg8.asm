%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2005, Charles Bilyue'.
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

%define SNEeSe_ppu_bg8_asm

%include "misc.inc"
%include "ppu/ppu.inc"
%include "ppu/tiles.inc"
%include "ppu/screen.inc"


%define R8x8_Local_Bytes_H 56
%define R8x8_Local_Bytes 52
%define R8x8_Plotter_Table_NP esp+52
%define R8x8_Plotter_Table esp+48
%define R8x8_Clipped esp+44
%define R8x8_BG_Table esp+40
%define R8x8_Current_Line esp+36
%define R8x8_BaseDestPtr esp+32
%define R8x8_Lines esp+28
%define R8x8_Runs_Left esp+24
%define R8x8_Output esp+20
%define R8x8_RunListPtr esp+16
%define R8x8R_VMapOffset esp+12
%define R8x8R_Plotter esp+8
%define R8x8R_BG_Table R8x8_BG_Table
%define R8x8R_Next_Pixel esp+4
%define R8x8R_Pixel_Count esp
%define R8x8R_Inner (4)

;VMapOffset = bg_line_offset (vscroll + current line) / bg tile size *
; 32 words (per line)
;Plotter = background plotting handler, passed:
; ebx = VRAM screen address of first tile
;  cl = tile count to plot
; edi = pointer to destination surface, leftmost pixel of first tile
;  (even if clipped)
; uses qword TileClip1 (dword TileClip1Left, dword TileClip1Right)
;BG_Table = pointer to background structure
;Next_Pixel = first pixel in run to be plotted
;     (local) hscroll-adjusted pixel to be plotted next (not always updated)
;Pixel_Count = count of pixels in run to be plotted
;edx = pointer to background structure (same as passed on stack)
;edi = native pointer to destination surface, start of first line
; to be drawn in output

%if 0
C-pseudo code
void Render_8x8_Run
(BGTABLE *bgtable, UINT8 *output, int vmapoffset, int nextpixel,
 int numpixels,
 void (*plotter)(UINT16 *screen_address, UINT8 tilecount, UINT8 *output))
)
{
 UINT16 *screen_address;

 output += nextpixel;

 nextpixel += bgtable->hscroll & 0xFF;
 if (nextpixel < 0x100)
 {
  screen_address = (UINT16 *) (bgtable->vlmapaddress + vmapoffset +
   nextpixel / 8 * 2);
 }
 else
 {
  nextpixel -= 0x100;
  screen_address = (UINT16 *) (bgtable->vrmapaddress + vmapoffset +
   nextpixel / 8 * 2);
 }

 if (nextpixel & 7)
 {
  output -= nextpixel & 7;
  TileClip1Left = *(UINT32 *)(ClipLeftTable - (nextpixel & 7));
  TileClip1Right = *(UINT32 *)(ClipLeftTable - (nextpixel & 7) + 4);

  if (numpixels < 8 - (nextpixel & 7))
  {
   TileClip1Left &=
    *(UINT32 *)(ClipRightTable - ((nextpixel & 7) + numpixels));
   TileClip1Right &=
    *(UINT32 *)(ClipRightTable - ((nextpixel & 7) + numpixels) + 4);
  }

  plotter(screen_address, 1, output);

  if (numpixels <= 0) return;

  screen_address ++;
  output += 8;
  nextpixel += 8 - (nextpixel & 7);
  numpixels -= 8 - (nextpixel & 7);
 }

 TileClip1Left = TileClip1Right = -1;

 if (nextpixel != 0x100)
 {
  UINT8 runlength;
  if (numpixels < 0x100 - nextpixel)
  {
   runlength = numpixels & ~7;
   if (!runlength)
   {
    TileClip1Left &=
     *(UINT32 *)(ClipRightTable - numpixels);
    TileClip1Right &=
     *(UINT32 *)(ClipRightTable - numpixels + 4);
    plotter(screen_address, 1, output);
    return;
   }
  }
  else
  {
   runlength = 0x100 - nextpixel;
  }

  plotter(screen_address, runlength / 8, output);
  numpixels -= runlength;
  if (!numpixels) return;

  screen_address += runlength / 8;
  output += runlength;
  nextpixel += runlength;

  if (nextpixel < 0x100)
  {
   TileClip1Left &=
    *(UINT32 *)(ClipRightTable - numpixels);
   TileClip1Right &=
    *(UINT32 *)(ClipRightTable - numpixels + 4);
   plotter(screen_address, 1, output);
   return;
  }
 }

 screen_address = (UINT16 *) (bgtable->vrmapaddress + vmapoffset);
 if (numpixels >= 8)
 {
  plotter(screen_address, numpixels / 8, output);
  if (!(numpixels & 7)) return;
  screen_address += numpixels / 8;
  output += numpixels & ~7;
 }

 TileClip1Left &=
  *(UINT32 *)(ClipRightTable - (numpixels & 7));
 TileClip1Right &=
  *(UINT32 *)(ClipRightTable - (numpixels & 7) + 4);
 plotter(screen_address, 1, output);
}
%endif
ALIGNC
Render_8x8_Run:
 xor ecx,ecx

 mov eax,[R8x8R_Next_Pixel+R8x8R_Inner]
 mov cl,[HScroll+edx]
 add edi,eax    ;first pixel
 add ecx,eax

 mov eax,[VLMapAddress+edx]
 mov ebx,[R8x8R_VMapOffset+R8x8R_Inner]
 cmp ecx,0x100
 jb .do_before_wrap
 sub ecx,0x100
 mov eax,[VRMapAddress+edx]
.do_before_wrap:

 mov ebp,ecx
 add ebx,eax

 shr ebp,3      ;(nextpixel / 8)

 ;hscroll + first pixel, relative to screen of first tile to be plotted
 mov [R8x8R_Next_Pixel+R8x8R_Inner],ecx
 and ecx,byte 7
 lea ebx,[ebx+ebp*2]
 jz .do_unclipped_before_wrap

 sub edi,ecx
 sub ecx,byte 8

 sub [R8x8R_Next_Pixel+R8x8R_Inner],ecx ;nextpixel += 8 - (nextpixel & 7)
 mov esi,[R8x8R_Pixel_Count+R8x8R_Inner]
 add [R8x8R_Pixel_Count+R8x8R_Inner],ecx    ;count -= 8 - (nextpixel & 7)
 xor ecx,byte 7

 mov eax,[ClipLeftTable+ecx+1]      ;ClipLeftTable[-(nextpixel & 7)]
 mov [TileClip1Left],eax
 mov eax,[ClipLeftTable+ecx+1+4]
 mov [TileClip1Right],eax
 sub ecx,esi
 cmp dword [R8x8R_Pixel_Count+R8x8R_Inner],0
 jl .clippedboth
 jz .last_tile

 mov cl,1
 call [R8x8R_Plotter+R8x8R_Inner]

.do_unclipped_before_wrap:
 mov eax,-1
 mov ecx,0x100
 mov ebp,[R8x8R_Next_Pixel+R8x8R_Inner]
 mov [TileClip1Left],eax
 sub ecx,ebp
 mov [TileClip1Right],eax
 jz .do_unclipped_after_wrap

 mov eax,[R8x8R_Pixel_Count+R8x8R_Inner]
 cmp ecx,eax
 jbe .goodcountunclippedleft
 mov ecx,eax
 and ecx,byte ~7
 jz .clipped_last_before_wrap
.goodcountunclippedleft:

 sub eax,ecx    ;count -= pixels in unclipped tiles in left run
 add [R8x8R_Next_Pixel+R8x8R_Inner],ecx ;nextpixel += 8 - (nextpixel & 7)
 shr ecx,3

 test eax,eax
 jz .last_run
 mov [R8x8R_Pixel_Count+R8x8R_Inner],eax
 call [R8x8R_Plotter+R8x8R_Inner]

 mov ebp,[R8x8R_Next_Pixel+R8x8R_Inner]
 cmp ebp,0x100
 jae .do_unclipped_after_wrap

.clipped_last_before_wrap:
 mov ecx,[R8x8R_Pixel_Count+R8x8R_Inner]
 jmp .do_clipped_last_tile

.do_unclipped_after_wrap:
 mov edx,[R8x8R_BG_Table+R8x8R_Inner]
 mov eax,[R8x8R_Pixel_Count+R8x8R_Inner]
 mov esi,[R8x8R_VMapOffset+R8x8R_Inner]
 mov ecx,eax
 mov ebx,[VRMapAddress+edx]
 add ebx,esi
 shr eax,3
 jz .do_clipped_last_tile

 test ecx,7
 mov ecx,eax
 jz .last_run

 call [R8x8R_Plotter+R8x8R_Inner]

 mov ecx,[R8x8R_Pixel_Count+R8x8R_Inner]

.do_clipped_last_tile:
 and ecx,byte 7
 xor ecx,byte -1
.clippedboth:
 ; ClipRightTable[-((nextpixel & 7) + pixel_count)]
 mov eax,[ClipRightTable+ecx+1]
 and [TileClip1Left],eax
 mov eax,[ClipRightTable+ecx+1+4]
 and [TileClip1Right],eax

.last_tile:
 mov cl,1
.last_run:
 jmp [R8x8R_Plotter+R8x8R_Inner]

%macro Render_8x8 1
ALIGNC
EXPORT_C Render_8x8_C%1
 cmp byte [Mosaic+edx],0
 jnz C_LABEL(Render_8x8M_C%1)

%if %1 == 2
 mov ecx,[M0_Color+edx]
 mov [Palette_Base],ecx
%endif

 mov ecx,C_LABEL(Plot_Lines_V_8x8_Table_C%1)
 test al,al
 jnz .plotter_high

 cmp byte [Tile_priority_bit],0
 jnz Render_8x8_Low

.plotter_high:
 push dword C_LABEL(Plot_Lines_NP_8x8_Table_C%1)
 jmp Render_8x8_High
%endmacro

Render_8x8 2
Render_8x8 4
Render_8x8 8

;%1 = label, %2 = priority
%macro Render_8x8_Base 2
ALIGNC
%1:
 push ecx
 push esi
 push edx ;BG_Table
 push ebx ;Current_Line
 push edi ;BaseDestPtr
 push ebp ;Lines
 sub esp,byte R8x8_Local_Bytes-24

 mov eax,[SetAddress+edx]
 mov [TilesetAddress],eax

.next_line:
 mov edx,[R8x8_BG_Table]

 mov eax,[R8x8_Current_Line]

%if %2 > 0
 mov cl,[Priority_Unused+edx+eax*2]
 test cl,cl
 jz .no_plot
%endif

 call Sort_Screen_Height
                
%if %2 == 0
 xor eax,eax
 mov [Tile_Priority_Used],ax
%endif

 mov eax,[R8x8_Current_Line]
 SORT_TILES_8_TALL
 mov ebp,[R8x8_Lines] ;*
;cmp ebp,byte 1
;je .no_multi

 ;esi = 7 - ((VScroll + Current_Line) & 7)

 cmp esi,ebp
 jae .no_multi
 lea ebp,[esi+1]
.no_multi:
 mov edi,[R8x8_BaseDestPtr]
%if %2 > 0
 mov esi,[R8x8_Current_Line]
%endif
 mov eax,ebp
 shl eax,8
 lea ecx,[edi+ebp*GfxBufferLineSlack]
 add eax,ecx

%if %2 == 0
 mov ecx,[R8x8_Plotter_Table]
%else
 mov cl,[Priority_Used+edx+esi*2]
 cmp cl,1
 mov ecx,[R8x8_Plotter_Table_NP]
 jc .plotter_np
 mov ecx,[R8x8_Plotter_Table]
.plotter_np:
%endif
 mov [BGLineCount],ebp ;*
 cmp ebp,byte 1
 mov [R8x8_BaseDestPtr],eax
 sbb ebp,ebp
 mov eax,[C_LABEL(SNES_Screen8)]
 add edi,eax
 mov ecx,[ecx+ebp*4+4]

 mov esi,[R8x8_Clipped]
 mov al,[Win_Count+edx+esi]

 test al,al
 jz .done

 mov [R8x8_Runs_Left],eax
 lea edx,[Win_Bands+edx+esi]

 mov [R8x8_Output],edi
 mov [R8x8_RunListPtr],edx
 mov [R8x8R_VMapOffset],ebx ;vertical screen map address
 xor ebx,ebx
 mov [R8x8R_Plotter],ecx    ;renderer
 mov bl,[edx]

 xor ecx,ecx
 mov cl,[edx+1]
 mov edx,[R8x8_BG_Table]
 sub cl,bl
 setz ch

 mov [R8x8R_Next_Pixel],ebx
 mov [R8x8R_Pixel_Count],ecx

 dec al
 je .last_run

.not_last_run:
 mov [R8x8_Runs_Left],al
 call Render_8x8_Run

 mov edx,[R8x8_RunListPtr]
 mov edi,[R8x8_Output]
 xor ebx,ebx
 xor ecx,ecx
 mov bl,[edx+2]

 mov cl,[edx+3]
 add edx,byte 2
 sub cl,bl
 mov [R8x8_RunListPtr],edx
 mov edx,[R8x8_BG_Table]

 mov [R8x8R_Next_Pixel],ebx
 mov [R8x8R_Pixel_Count],ecx

 mov al,[R8x8_Runs_Left]
 dec al
 jne .not_last_run
.last_run:
 call Render_8x8_Run

.done:

 mov ebp,[BGLineCount] ;*
%if %2 == 0
 mov edx,[R8x8_BG_Table]
%endif
 mov eax,[R8x8_Current_Line]

%if %2 == 0
 mov bx,[Tile_Priority_Used]
 or [Priority_Used+edx],bx
 mov [Priority_Used+edx+eax*2],bx
%endif

 mov ecx,[R8x8_Lines]
 add eax,ebp
 sub ecx,ebp
 mov [R8x8_Current_Line],eax
 mov [R8x8_Lines],ecx

%ifndef LAYERS_PER_LINE
;cmp dword [R8x8_Lines],0
 jnz .next_line
%endif

%if %2 == 0
;mov edx,[R8x8_BG_Table]
;mov al,[Tile_Priority_Used]
;mov [Priority_Used+edx],al
;mov ah,[Tile_Priority_Unused]
;mov [Priority_Unused+edx],ah

 add esp,byte R8x8_Local_Bytes
%else
 add esp,byte R8x8_Local_Bytes_H
%endif
 ret

%if %2 > 0
ALIGNC
.no_plot:
 mov ebp,[R8x8_Lines]
 cmp ebp,byte 1
 je .no_plot_no_multi
                                
 mov edi,[VScroll+edx]
 mov eax,[R8x8_Current_Line]
 add edi,eax
 mov eax,8
 and edi,byte 7
 sub eax,edi

 cmp eax,ebp
 ja .no_plot_no_multi
 mov ebp,eax
.no_plot_no_multi:
 mov edi,[R8x8_BaseDestPtr]
 mov eax,ebp
 shl eax,8
 lea ecx,[edi+ebp*GfxBufferLineSlack]
 add eax,ecx
 mov [R8x8_BaseDestPtr],eax

 mov eax,[R8x8_Current_Line]
 mov ecx,[R8x8_Lines]
 add eax,ebp
 sub ecx,ebp
 mov [R8x8_Current_Line],eax
 mov [R8x8_Lines],ecx

%ifndef LAYERS_PER_LINE
;cmp dword [R8x8_Lines],0
 jnz .next_line
%endif

 add esp,byte R8x8_Local_Bytes_H
 ret
%endif
%endmacro

Render_8x8_Base Render_8x8_Low,0
Render_8x8_Base Render_8x8_High,1

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high, %3 = multi-line
%macro Plot_Lines_8x8_C2 3
%if %2 > 0
%%return:
 ret

ALIGNC
%1_check:
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Unused],cl
%endif
 add ebx,byte 2     ; Update screen pointer
 add edi,byte 8
 dec cl
 jz %%return
%else
ALIGNC
%endif

EXPORT_C %1     ; Define label, entry point
%%next_tile:
 mov al,[ebx+1]

 Check_Tile_Priority %2, %1_check

%if %3
 push ecx
 mov ecx,-1
%endif
 mov ebp,[LineAddressY]
 test al,al         ; Check Y flip
 mov si,[ebx]       ; Get tile #
 js %%flip_y
 mov ebp,[LineAddress]
%if %3
 add ecx,byte (1 * 2)
%endif

%%flip_y:
 shl esi,3
 mov edx,eax
 add esi,ebp
 mov ebp,[TilesetAddress]
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 and edx,byte 7*4   ; Get palette
 add esi,ebp

 mov ebp,[Palette_Base]
 and esi,0xFFFF * 4 / 8 ; Clip to VRAM

 mov edx,[palette_2bpl+edx]
 add ebx,byte 2     ; Update screen pointer
 or ebp,edx         ; Adjust palette for mode 0

%if %3
 push ebx
 mov ebx,[BGLineCount]
%endif

%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif

 add al,al      ; Get X flip (now in MSB)
 js %%xflip

 Plot_8_Paletted_Lines_Clip_noflip (%3),C_LABEL(TileCache2)+esi*8,0,TileClip1
%if %3
 pop ebx
 pop ecx
%endif

 add edi,byte 8
 dec cl
 jnz %%next_tile
 ret

ALIGNC
%%xflip:
 Plot_8_Paletted_Lines_Clip_Xflip (%3),C_LABEL(TileCache2)+esi*8,0,TileClip1
%if %3
 pop ebx
 pop ecx
%endif

 add edi,byte 8
 dec cl
 jnz %%next_tile
 ret
%endmacro

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high, %3 = multi-line
%macro Plot_Lines_8x8_C4 3
%if %2 > 0
%%return:
 ret

ALIGNC
%1_check:
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Unused],cl
%endif
 add ebx,byte 2     ; Update screen pointer
 add edi,byte 8
 dec cl
 jz %%return
%else
ALIGNC
%endif

EXPORT_C %1     ; Define label, entry point
%%next_tile:
 mov al,[ebx+1]

 Check_Tile_Priority %2, %1_check

%if %3
 push ecx
 mov ecx,-1
%endif
 mov ebp,[LineAddressY]
 test al,al         ; Check Y flip
 mov si,[ebx]       ; Get tile #
 js %%flip_y
 mov ebp,[LineAddress]
%if %3
 add ecx,byte (1 * 2)
%endif

%%flip_y:
 shl esi,3
 mov edx,eax
 add esi,ebp
 mov ebp,[TilesetAddress]
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 and edx,byte 7*4   ; Get palette
 add esi,ebp

 add ebx,byte 2     ; Update screen pointer
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM
 mov ebp,[palette_4bpl+edx]

%if %3
 push ebx
 mov ebx,[BGLineCount]
%endif

%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif

 add al,al      ; Get X flip (now in MSB)
 js %%xflip

 Plot_8_Paletted_Lines_Clip_noflip (%3),C_LABEL(TileCache4)+esi*8,0,TileClip1
%if %3
 pop ebx
 pop ecx
%endif

 add edi,byte 8
 dec cl
 jnz %%next_tile
 ret

ALIGNC
%%xflip:
 Plot_8_Paletted_Lines_Clip_Xflip (%3),C_LABEL(TileCache4)+esi*8,0,TileClip1
%if %3
 pop ebx
 pop ecx
%endif

 add edi,byte 8
 dec cl
 jnz %%next_tile
 ret
%endmacro

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high, %3 = multi-line
%macro Plot_Lines_8x8_C8 3
%if %2 > 0
%%return:
 ret

ALIGNC
%1_check:
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Unused],cl
%endif
 add ebx,byte 2     ; Update screen pointer
 add edi,byte 8
 dec cl
 jz %%return
%else
ALIGNC
%endif

EXPORT_C %1     ; Define label, entry point
%%next_tile:
 mov al,[ebx+1]

 Check_Tile_Priority %2, %1_check

 mov si,[ebx]       ; Get tile #
 add ebx,byte 2     ; Update screen pointer
 shl esi,3
%if %3
 push ecx
 mov ecx,-1
%endif
 test al,al         ; Check Y flip
 mov ebp,[LineAddressY]
 js %%flip_y
 mov ebp,[LineAddress]
%if %3
 add ecx,byte (1 * 2)
%endif

%%flip_y:
 add esi,ebp
 mov ebp,[TilesetAddress]
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,ebp
 and esi,0xFFFF / 8 ; Clip to VRAM

%if %3
 push ebx
 mov ebx,[BGLineCount]
%endif

%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif

 add al,al      ; Get X flip (now in MSB)
 js %%xflip

 Plot_8_Lines_Clip_noflip (%3),C_LABEL(TileCache8)+esi*8,0,TileClip1
%if %3
 pop ebx
 pop ecx
%endif

 add edi,byte 8
 dec cl
 jnz %%next_tile
 ret

ALIGNC
%%xflip:
 Plot_8_Lines_Clip_Xflip (%3),C_LABEL(TileCache8)+esi*8,0,TileClip1
%if %3
 pop ebx
 pop ecx
%endif

 add edi,byte 8
 dec cl
 jnz %%next_tile
 ret
%endmacro

;%1 = depth, %2 = count
%macro Generate_Line_Plotters_8x8 2
%ifndef NO_NP_RENDER
 Plot_Lines_8x8_C%1 Plot_Lines_%2_NP_8x8_C%1,0,%2
%endif
 Plot_Lines_8x8_C%1 Plot_Lines_%2_V_8x8_C%1,3,%2
%endmacro

%macro Generate_Line_Plotters_8x8_Depth 1
Generate_Line_Plotters_8x8 %1,0
Generate_Line_Plotters_8x8 %1,1
%endmacro

Generate_Line_Plotters_8x8_Depth 2
Generate_Line_Plotters_8x8_Depth 4
Generate_Line_Plotters_8x8_Depth 8

section .data
ALIGND

;%1 = type, %2 = depth
%macro Generate_Line_Plotter_Table_8x8 2
EXPORT_C Plot_Lines_%1_8x8_Table_C%2
dd C_LABEL(Plot_Lines_0_%1_8x8_C%2)
dd C_LABEL(Plot_Lines_1_%1_8x8_C%2)
%endmacro

%ifndef NO_NP_RENDER
Generate_Line_Plotter_Table_8x8 NP,2
Generate_Line_Plotter_Table_8x8 NP,4
Generate_Line_Plotter_Table_8x8 NP,8
%endif

Generate_Line_Plotter_Table_8x8 V,2
Generate_Line_Plotter_Table_8x8 V,4
Generate_Line_Plotter_Table_8x8 V,8

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
