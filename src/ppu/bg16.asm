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

%define SNEeSe_ppu_bg16_asm

%include "misc.inc"
%include "ppu/ppu.inc"
%include "ppu/tiles.inc"
%include "ppu/screen.inc"


%define R16x16R_VMapOffset esp+16
%define R16x16R_Plotter_Table esp+12
%define R16x16R_BG_Table esp+8
%define R16x16R_Next_Pixel esp+4
%define R16x16R_Pixel_Count esp
%define R16x16R_Inner (4)

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
void Render_16x16_Run
(BGTABLE *bgtable, UINT8 *output, int vmapoffset, int nextpixel,
 int numpixels,
 void (**plotter_table)(UINT16 *screen_address, UINT8 tilecount,
 UINT8 *output))
)
{
 UINT16 *screen_address;

 output += nextpixel;

 nextpixel += bgtable->hscroll & 0x1FF;
 if (nextpixel < 0x200)
 {
  screen_address = (UINT16 *) (bgtable->vlmapaddress + vmapoffset +
   nextpixel / 16 * 2);
 }
 else
 {
  nextpixel -= 0x200;
  screen_address = (UINT16 *) (bgtable->vrmapaddress + vmapoffset +
   nextpixel / 16 * 2);
 }

 if (nextpixel & 15)
 {
  output -= nextpixel & 15;
  TileClip1Left = *(UINT32 *)(ClipLeftTable - (nextpixel & 15));
  TileClip1Right = *(UINT32 *)(ClipLeftTable - (nextpixel & 15) + 4);
  TileClip2Left = *(UINT32 *)(ClipLeftTable - (nextpixel & 15) + 8);
  TileClip2Right = *(UINT32 *)(ClipLeftTable - (nextpixel & 15) + 12);

  if (numpixels < 16 - (nextpixel & 15))
  {
   TileClip1Left &=
    *(UINT32 *)(ClipRightTable - ((nextpixel & 15) + numpixels));
   TileClip1Right &=
    *(UINT32 *)(ClipRightTable - ((nextpixel & 15) + numpixels) + 4);
   TileClip2Left &=
    *(UINT32 *)(ClipRightTable - ((nextpixel & 15) + numpixels) + 8);
   TileClip2Right &=
    *(UINT32 *)(ClipRightTable - ((nextpixel & 15) + numpixels) + 12);
  }

  plotter_table[(nextpixel & 8) >> 2](screen_address, 2, output);

  if (numpixels <= 0) return;

  screen_address ++;
  output += 16;
  nextpixel += 16 - (nextpixel & 15);
  numpixels -= 16 - (nextpixel & 15);
 }

 TileClip1Left = TileClip1Right = TileClip2Left = TileClip2Right = -1;

 if (nextpixel != 0x200)
 {
  UINT8 runlength;
  if (numpixels < 0x200 - nextpixel)
  {
   runlength = numpixels & ~15;
   if (!runlength)
   {
    TileClip1Left &=
     *(UINT32 *)(ClipRightTable - numpixels);
    TileClip1Right &=
     *(UINT32 *)(ClipRightTable - numpixels + 4);
    TileClip2Left &=
     *(UINT32 *)(ClipRightTable - numpixels + 8);
    TileClip2Right &=
     *(UINT32 *)(ClipRightTable - numpixels + 12);
    plotter_table(screen_address, 2, output);
    return;
   }
  }
  else
  {
   runlength = 0x200 - nextpixel;
  }

  plotter_table(screen_address, runlength / 8, output);
  numpixels -= runlength;
  if (!numpixels) return;

  screen_address += runlength / 8;
  output += runlength;
  nextpixel += runlength;

  if (nextpixel < 0x200)
  {
   TileClip1Left &=
    *(UINT32 *)(ClipRightTable - numpixels);
   TileClip1Right &=
    *(UINT32 *)(ClipRightTable - numpixels + 4);
   TileClip1Left &=
    *(UINT32 *)(ClipRightTable - numpixels + 8);
   TileClip1Right &=
    *(UINT32 *)(ClipRightTable - numpixels + 12);
   plotter_table(screen_address, 2, output);
   return;
  }
 }

 screen_address = (UINT16 *) (bgtable->vrmapaddress + vmapoffset);
 if (numpixels >= 8)
 {
  plotter_table(screen_address, numpixels / 8, output);
  if (!(numpixels & 15)) return;
  screen_address += numpixels / 8;
  output += numpixels & ~15;
 }

 TileClip1Left &=
  *(UINT32 *)(ClipRightTable - (numpixels & 15));
 TileClip1Right &=
  *(UINT32 *)(ClipRightTable - (numpixels & 15) + 4);
 TileClip2Left &=
  *(UINT32 *)(ClipRightTable - (numpixels & 15) + 8);
 TileClip2Right &=
  *(UINT32 *)(ClipRightTable - (numpixels & 15) + 12);
 plotter_table(screen_address, 2, output);
}
%endif
ALIGNC
Render_16x16_Run:
 mov ecx,[HScroll+edx]
 mov eax,[R16x16R_Next_Pixel+R16x16R_Inner]
 and ecx,0x1FF

 add edi,eax    ;first pixel
 add ecx,eax

 mov eax,[VLMapAddress+edx]
 mov ebx,[R16x16R_VMapOffset+R16x16R_Inner]
 cmp ecx,0x200
 jb .do_before_wrap
 sub ecx,0x200
 mov eax,[VRMapAddress+edx]
.do_before_wrap:

 mov ebp,ecx
 add ebx,eax

 shr ebp,4      ;(nextpixel / 16)

 ;hscroll + first pixel, relative to screen of first tile to be plotted
 mov [R16x16R_Next_Pixel+R16x16R_Inner],ecx
 and ecx,byte 15
 lea ebx,[ebx+ebp*2]
 jz .do_unclipped_before_wrap

 sub edi,ecx
 sub ecx,byte 16

 sub [R16x16R_Next_Pixel+R16x16R_Inner],ecx ;nextpixel += 16 - (nextpixel & 15)
 mov esi,[R16x16R_Pixel_Count+R16x16R_Inner]
 add [R16x16R_Pixel_Count+R16x16R_Inner],ecx    ;count -= 16 - (nextpixel & 15)
 xor ecx,byte 15

 mov eax,[ClipLeftTable+ecx+1]      ;ClipLeftTable[-(nextpixel & 15)]
 mov [TileClip1Left],eax
 mov eax,[ClipLeftTable+ecx+1+4]
 mov [TileClip1Right],eax
 mov eax,[ClipLeftTable+ecx+1+8]
 mov [TileClip2Left],eax
 mov eax,[ClipLeftTable+ecx+1+12]
 mov [TileClip2Right],eax
 lea eax,[ecx+8+1]
 sub ecx,esi
 and eax,byte 8
 mov esi,[R16x16R_Plotter_Table+R16x16R_Inner]
 add esi,eax

 cmp dword [R16x16R_Pixel_Count+R16x16R_Inner],0
 jl .clippedboth
 jz .last_tile

 mov cl,2
 call [esi]

.do_unclipped_before_wrap:
 mov eax,-1
 mov ecx,0x200
 mov ebp,[R16x16R_Next_Pixel+R16x16R_Inner]
 mov [TileClip1Left],eax
 sub ecx,ebp
 mov [TileClip1Right],eax
 mov [TileClip2Left],eax
 mov [TileClip2Right],eax
 jz .do_unclipped_after_wrap

 mov eax,[R16x16R_Pixel_Count+R16x16R_Inner]
 cmp ecx,eax
 jbe .goodcountunclippedleft

 mov ecx,eax
 and ecx,byte ~15
 jz .clipped_last_before_wrap

.goodcountunclippedleft:
 sub eax,ecx    ;count -= pixels in unclipped tiles in left run
 add [R16x16R_Next_Pixel+R16x16R_Inner],ecx ;nextpixel += 16 - (nextpixel & 15)
 mov edx,ecx
 shr ecx,3

 mov esi,[R16x16R_Plotter_Table+R16x16R_Inner]

 test eax,eax
 jz .last_run
 mov [R16x16R_Pixel_Count+R16x16R_Inner],eax
 call [esi]

 mov ebp,[R16x16R_Next_Pixel+R16x16R_Inner]
 cmp ebp,0x200
 jae .do_unclipped_after_wrap

.clipped_last_before_wrap:
 mov ecx,[R16x16R_Pixel_Count+R16x16R_Inner]
 jmp .do_clipped_last_tile

.do_unclipped_after_wrap:
 mov edx,[R16x16R_BG_Table+R16x16R_Inner]
 mov eax,[R16x16R_Pixel_Count+R16x16R_Inner]
 mov esi,[R16x16R_VMapOffset+R16x16R_Inner]
 mov ecx,eax
 mov ebx,[VRMapAddress+edx]
 add ebx,esi
 shr eax,4
 jz .do_clipped_last_tile

 add eax,eax

 test ecx,15
 mov esi,[R16x16R_Plotter_Table+R16x16R_Inner]
 mov ecx,eax
 jz .last_run

 call [esi]

 mov ecx,[R16x16R_Pixel_Count+R16x16R_Inner]

.do_clipped_last_tile:
 and ecx,byte 15
 xor ecx,byte -1

 mov esi,[R16x16R_Plotter_Table+R16x16R_Inner]

.clippedboth:
 ; ClipRightTable[-((nextpixel & 15) + pixel_count)]
 mov eax,[ClipRightTable+ecx+1]
 and [TileClip1Left],eax
 mov eax,[ClipRightTable+ecx+1+4]
 and [TileClip1Right],eax
 mov eax,[ClipRightTable+ecx+1+8]
 and [TileClip2Left],eax
 mov eax,[ClipRightTable+ecx+1+12]
 and [TileClip2Right],eax

.last_tile:
 mov cl,2
.last_run:
 jmp [esi]

%define R16x16_Local_Bytes 24
%define R16x16_Plotter_Table esp+20
%define R16x16_Clipped esp+16
%define R16x16_BG_Table esp+12
%define R16x16_Current_Line esp+8
%define R16x16_BaseDestPtr esp+4
%define R16x16_Lines esp

%macro Render_16x16 1
ALIGNC
EXPORT_C Render_16x16_C%1
 cmp byte [Mosaic+edx],0
 jnz C_LABEL(Render_16x16M_C%1)

%if %1 == 2
 mov ecx,[M0_Color+edx]
 mov [Palette_Base],ecx
%endif

%ifndef NO_NP_RENDER
 mov ecx,C_LABEL(Plot_Lines_NP_16x16_Table_C%1)
 test al,al
 jnz .have_plotter
%endif

 mov ecx,C_LABEL(Plot_Lines_V_16x16_Table_C%1)

.have_plotter:
 jmp Render_16x16_Base
%endmacro

Render_16x16 2
Render_16x16 4
Render_16x16 8

ALIGNC
Render_16x16_Base:
 push ecx
 push esi
 push edx
 push ebx
 push edi
 push ebp

 mov ecx,[SetAddress+edx]
 mov [TilesetAddress],ecx

.next_line:
 mov edx,[R16x16_BG_Table]

 mov eax,[R16x16_Current_Line]
 call Sort_Screen_Height

 mov eax,[R16x16_Current_Line]
 SORT_TILES_16_TALL
 mov ebp,[R16x16_Lines] ;*
 and esi,byte 7
;cmp ebp,byte 1
;je .no_multi

 ;esi = 7 - ((VScroll + Current_Line) & 7)

 cmp esi,ebp
 jae .no_multi
 lea ebp,[esi+1]
.no_multi:
 mov edi,[R16x16_BaseDestPtr]
 mov eax,ebp
 shl eax,8
 lea ecx,[edi+ebp*GfxBufferLineSlack]
 add eax,ecx

 mov ecx,[R16x16_Plotter_Table]

 mov [BGLineCount],ebp ;*
 cmp ebp,byte 1
 mov [R16x16_BaseDestPtr],eax
 sbb ebp,ebp
 mov eax,[C_LABEL(SNES_Screen8)]
 add edi,eax
 lea ecx,[ecx+ebp*4+4]

 mov esi,[R16x16_Clipped]
 mov al,[Win_Count+edx+esi]

 test al,al
 jz .done

 push eax
 lea edx,[Win_Bands+edx+esi]

 push edi
 push edx
 push ebx       ;vertical screen map address
 xor ebx,ebx
 push ecx       ;renderer
 mov bl,[edx]

 xor ecx,ecx
 mov cl,[edx+1]
 mov edx,[R16x16_BG_Table+20]
 sub cl,bl
 setz ch

 push edx
 push ebx
 push ecx

 dec al
 je .last_run

.not_last_run:
 mov [esp+28],al
 call Render_16x16_Run

 mov edx,[esp+20]
 mov edi,[esp+24]
 xor ebx,ebx
 xor ecx,ecx
 mov bl,[edx+2]

 mov cl,[edx+3]
 add edx,byte 2
 sub cl,bl
 mov [esp+20],edx
 mov edx,[esp+8]

 mov [esp+4],ebx
 mov [esp],ecx

 mov al,[esp+28]
 dec al
 jne .not_last_run
.last_run:
 call Render_16x16_Run
 add esp,byte 32

.done:

 mov ebp,[BGLineCount] ;*
 mov eax,[R16x16_Current_Line]
 mov ecx,[R16x16_Lines]
 add eax,ebp
 sub ecx,ebp
 mov [R16x16_Current_Line],eax
 mov [R16x16_Lines],ecx

%ifndef LAYERS_PER_LINE
;cmp dword [R16x16_Lines],0
 jnz .next_line
%endif

 mov edx,[R16x16_BG_Table]
 mov al,[Tile_Priority_Used]
 mov [Priority_Used+edx],al
 mov ah,[Tile_Priority_Unused]
 mov [Priority_Unused+edx],ah

 add esp,byte R16x16_Local_Bytes
 ret

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high, %3 = multi-line
%macro Plot_Lines_16x16_C2 2-3 1
%if %2 > 0
%%return:
 ret

ALIGNC
%1_check:
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Unused],cl
%endif
 add ebx,byte 2     ; Update screen pointer
 add edi,byte 16
 sub cl,2
 jle %%return
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
 and edx,byte 7*4   ; Get palette
 add ebx,byte 2     ; Update screen pointer
 mov ebp,[Palette_Base]
 mov edx,[palette_2bpl+edx]
 or ebp,edx         ; Adjust palette for mode 0
 mov edx,[TilesetAddress]
 add al,al      ; Get X flip (now in MSB)

%if %3
 push ebx
 mov ebx,[BGLineCount]
%endif

 push esi
 js %%xflip

 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF * 4 / 8 ; Clip to VRAM

 Plot_8_Paletted_Lines_Clip_noflip (%3),C_LABEL(TileCache2)+esi*8,0,TileClip1

 pop esi
%if %3
 dec byte [esp+4]
%else
 dec cl
%endif
 jle %%early_out
%%leftedge_noflip:
 add esi,byte 8
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,[TilesetAddress]
 and esi,0xFFFF * 4 / 8 ; Clip to VRAM

%if %3
 mov ebx,[BGLineCount]
%endif

 Plot_8_Paletted_Lines_Clip_noflip (%3),C_LABEL(TileCache2)+esi*8,8,TileClip2

%if %3
 pop ebx
 pop ecx
%endif

%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 add edi,byte 16
 dec cl
 jg %%next_tile
 ret

%%early_out:
%if %3
 pop ebx
 pop ecx
%endif
 ret

ALIGNC
%%xflip:
 add esi,byte 8

 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF * 4 / 8 ; Clip to VRAM

 Plot_8_Paletted_Lines_Clip_Xflip (%3),C_LABEL(TileCache2)+esi*8,0,TileClip1

 pop esi
%if %3
 dec byte [esp+4]
%else
 dec cl
%endif
 jle %%early_out
%%leftedge_xflip:
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,[TilesetAddress]
 and esi,0xFFFF * 4 / 8 ; Clip to VRAM

%if %3
 mov ebx,[BGLineCount]
%endif
 Plot_8_Paletted_Lines_Clip_Xflip (%3),C_LABEL(TileCache2)+esi*8,8,TileClip2

%if %3
 pop ebx
 pop ecx
%endif

%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 add edi,byte 16
 dec cl
 jg %%next_tile
 ret

.LeftEdge:
 mov al,[ebx+1]

 Check_Tile_Priority %2, %1_check

 dec cl
 mov ebp,[LineAddressY]
 test al,al         ; Check Y flip
 mov si,[ebx]       ; Get tile #
%if %3
 push ecx
 mov ecx,-1
%endif
 js %%leftedge_flip_y
 mov ebp,[LineAddress]
%if %3
 add ecx,byte (1 * 2)
%endif

%%leftedge_flip_y:
 shl esi,3
 mov edx,eax
 add esi,ebp
 and edx,byte 7*4   ; Get palette
 add ebx,byte 2     ; Update screen pointer
 mov ebp,[Palette_Base]
 mov edx,[palette_2bpl+edx]
 or ebp,edx         ; Adjust palette for mode 0
 mov edx,[TilesetAddress]
 add al,al      ; Get X flip (now in MSB)

%if %3
 push ebx
 mov ebx,[BGLineCount]
%endif

 jns %%leftedge_noflip
 jmp %%leftedge_xflip
%endmacro

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high, %3 = multi-line
%macro Plot_Lines_16x16_C4 2-3 1
%if %2 > 0
%%return:
 ret

ALIGNC
%1_check:
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Unused],cl
%endif
 add ebx,byte 2     ; Update screen pointer
 add edi,byte 16
 sub cl,2
 jle %%return
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
 add ebx,byte 2     ; Update screen pointer
 and edx,byte 7*4   ; Get palette
 mov ebp,[palette_4bpl+edx]
 add al,al      ; Get X flip (now in MSB)
 mov edx,[TilesetAddress]

%if %3
 push ebx
 mov ebx,[BGLineCount]
%endif

 push esi
 js %%xflip

 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM

 Plot_8_Paletted_Lines_Clip_noflip (%3),C_LABEL(TileCache4)+esi*8,0,TileClip1

 pop esi
%if %3
 dec byte [esp+4]
%else
 dec cl
%endif
 jle %%early_out
%%leftedge_noflip:
 add esi,byte 8
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,[TilesetAddress]
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM

%if %3
 mov ebx,[BGLineCount]
%endif

 Plot_8_Paletted_Lines_Clip_noflip (%3),C_LABEL(TileCache4)+esi*8,8,TileClip2

%if %3
 pop ebx
 pop ecx
%endif

%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 add edi,byte 16
 dec cl
 jg %%next_tile
 ret

%%early_out:
%if %3
 pop ebx
 pop ecx
%endif
 ret

ALIGNC
%%xflip:
 add esi,byte 8

 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM

 Plot_8_Paletted_Lines_Clip_Xflip (%3),C_LABEL(TileCache4)+esi*8,0,TileClip1

 pop esi
%if %3
 dec byte [esp+4]
%else
 dec cl
%endif
 jle %%early_out
%%leftedge_xflip:
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,[TilesetAddress]
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM

%if %3
 mov ebx,[BGLineCount]
%endif
 Plot_8_Paletted_Lines_Clip_Xflip (%3),C_LABEL(TileCache4)+esi*8,8,TileClip2

%if %3
 pop ebx
 pop ecx
%endif

%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 add edi,byte 16
 dec cl
 jg %%next_tile
 ret

.LeftEdge:
 mov al,[ebx+1]

 Check_Tile_Priority %2, %1_check

 dec cl
 mov ebp,[LineAddressY]
 test al,al         ; Check Y flip
 mov si,[ebx]       ; Get tile #
%if %3
 push ecx
 mov ecx,-1
%endif
 js %%leftedge_flip_y
 mov ebp,[LineAddress]
%if %3
 add ecx,byte (1 * 2)
%endif

%%leftedge_flip_y:
 shl esi,3
 mov edx,eax
 add esi,ebp
 add ebx,byte 2     ; Update screen pointer
 and edx,byte 7*4   ; Get palette
 mov ebp,[palette_4bpl+edx]
 add al,al      ; Get X flip (now in MSB)
 mov edx,[TilesetAddress]

%if %3
 push ebx
 mov ebx,[BGLineCount]
%endif

 jns %%leftedge_noflip
 jmp %%leftedge_xflip
%endmacro

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high, %3 = multi-line
%macro Plot_Lines_16x16_C8 2-3 1
%if %2 > 0
%%return:
 ret

ALIGNC
%1_check:
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Unused],cl
%endif
 add ebx,byte 2     ; Update screen pointer
 add edi,byte 16
 sub cl,2
 jle %%return
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
 add al,al      ; Get X flip (now in MSB)

%if %3
 push ebx
 mov ebx,[BGLineCount]
%endif

 push esi
 js %%xflip

 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,ebp
 and esi,0xFFFF / 8 ; Clip to VRAM

 Plot_8_Lines_Clip_noflip (%3),C_LABEL(TileCache8)+esi*8,0,TileClip1

 pop esi
%if %3
 dec byte [esp+4]
%else
 dec cl
%endif
 jle %%early_out
%%leftedge_noflip:
 add esi,byte 8
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,[TilesetAddress]
 and esi,0xFFFF / 8 ; Clip to VRAM

%if %3
 mov ebx,[BGLineCount]
%endif
 Plot_8_Lines_Clip_noflip (%3),C_LABEL(TileCache8)+esi*8,8,TileClip2

%if %3
 pop ebx
 pop ecx
%endif

%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 add edi,byte 16
 dec cl
 jg %%next_tile
 ret

%%early_out:
%if %3
 pop ebx
 pop ecx
%endif
 ret

ALIGNC
%%xflip:
 add esi,byte 8

 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,ebp
 and esi,0xFFFF / 8 ; Clip to VRAM

 Plot_8_Lines_Clip_Xflip (%3),C_LABEL(TileCache8)+esi*8,0,TileClip1

 pop esi
%if %3
 dec byte [esp+4]
%else
 dec cl
%endif
 jle %%early_out
%%leftedge_xflip:
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,[TilesetAddress]
 and esi,0xFFFF / 8 ; Clip to VRAM

%if %3
 mov ebx,[BGLineCount]
%endif
 Plot_8_Lines_Clip_Xflip (%3),C_LABEL(TileCache8)+esi*8,8,TileClip2

%if %3
 pop ebx
 pop ecx
%endif

%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 add edi,byte 16
 dec cl
 jg %%next_tile
 ret

.LeftEdge:
 mov al,[ebx+1]

 Check_Tile_Priority %2, %1_check

 dec cl
 mov si,[ebx]       ; Get tile #
 add ebx,byte 2     ; Update screen pointer
 shl esi,3
%if %3
 push ecx
 mov ecx,-1
%endif
 test al,al         ; Check Y flip
 mov ebp,[LineAddressY]
 js %%leftedge_flip_y
 mov ebp,[LineAddress]
%if %3
 add ecx,byte (1 * 2)
%endif

%%leftedge_flip_y:
 add esi,ebp
 add al,al      ; Get X flip (now in MSB)
 mov edx,[TilesetAddress]

%if %3
 push ebx
 mov ebx,[BGLineCount]
%endif

 jns %%leftedge_noflip
 jmp %%leftedge_xflip
%endmacro

;%1 = depth, %2 = count
%macro Generate_Line_Plotters_16x16 2
%ifndef NO_NP_RENDER
 Plot_Lines_16x16_C%1 Plot_Lines_%2_NP_16x16_C%1,0,%2
%endif
 Plot_Lines_16x16_C%1 Plot_Lines_%2_V_16x16_C%1,3,%2
%endmacro

%macro Generate_Line_Plotters_16x16_Depth 1
Generate_Line_Plotters_16x16 %1,0
Generate_Line_Plotters_16x16 %1,1
%endmacro

Generate_Line_Plotters_16x16_Depth 2
Generate_Line_Plotters_16x16_Depth 4
Generate_Line_Plotters_16x16_Depth 8

section .data
ALIGND

;%1 = type, %2 = depth
%macro Generate_Line_Plotter_Table_16x16 2
EXPORT_C Plot_Lines_%1_16x16_Table_C%2
dd C_LABEL(Plot_Lines_0_%1_16x16_C%2)
dd C_LABEL(Plot_Lines_1_%1_16x16_C%2)
dd C_LABEL(Plot_Lines_0_%1_16x16_C%2).LeftEdge
dd C_LABEL(Plot_Lines_1_%1_16x16_C%2).LeftEdge
%endmacro

%ifndef NO_NP_RENDER
Generate_Line_Plotter_Table_16x16 NP,2
Generate_Line_Plotter_Table_16x16 NP,4
Generate_Line_Plotter_Table_16x16 NP,8
%endif

Generate_Line_Plotter_Table_16x16 V,2
Generate_Line_Plotter_Table_16x16 V,4
Generate_Line_Plotter_Table_16x16 V,8

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
