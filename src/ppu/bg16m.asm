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

%define SNEeSe_ppu_bg16m_asm

%include "misc.inc"
%include "ppu/ppu.inc"
%include "ppu/tiles.inc"
%include "ppu/screen.inc"


%define R16x16MR_VMapOffset esp+16
%define R16x16MR_Plotter esp+12
%define R16x16MR_BG_Table esp+8
%define R16x16MR_Next_Pixel esp+4
%define R16x16MR_Pixel_Count esp
%define R16x16MR_Inner (4)

;VMapOffset = bg_line_offset (vscroll + current line) / bg tile size *
; 32 words (per line)
;Plotter = background plotting handler, passed:
; ebx = VRAM screen address of first tile
; ecx = pixel count to plot
; edi = pointer to destination surface, first pixel to be plotted
; ebp = pixel offset in first tile
;BG_Table = pointer to background structure
;Next_Pixel = first pixel in run to be plotted
;     (local) hscroll-adjusted pixel to be plotted next (not always updated)
;Pixel_Count = count of pixels in run to be plotted
;edx = pointer to background structure (same as passed on stack)
;edi = native pointer to destination surface, start of first line
; to be drawn in output

%if 0
C-pseudo code
void Render_16x16M_Run
(BGTABLE *bgtable, UINT8 *output, int vmapoffset, int nextpixel,
 int numpixels,
 void (*plotter)(UINT16 *screen_address, UINT8 pixeloffset,
  UINT8 pixelcount, UINT8 *output))
)
{
 UINT16 *screen_address;
 output += nextpixel;

 int clipped_count = Mosaic_Count[nextpixel];
 nextpixel = Mosaic_Line[nextpixel] + bgtable->hscroll & 0x1FF;

 if (nextpixel < 0x200)
 {
  screen_address = (UINT16 *) (bgtable->vlmapaddress + vmapoffset +
   nextpixel / 16;
 }
 else
 {
  nextpixel -= 0x200;
  screen_address = (UINT16 *) (bgtable->vrmapaddress + vmapoffset +
   nextpixel / 16;
 }

 if (clipped_count != Mosaic_Size)
 {
  ; left clipped

  plotter(screen_address, nextpixel & 15,
   min(numpixels, clipped_count), output);

  if (numpixels <= 0) return;

  screen_address += ((nextpixel & 15) + Mosaic_Size) >> 4;
  output += clipped_count;
  numpixels -= clipped_count;
  nextpixel += Mosaic_Size;
 }

 if (nextpixel <= 0x1FF)
 {
  int count = min(numpixels,
   nextpixel <= 256 ? 512 - nextpixel + Mosaic_Count[512 - nextpixel]);
  plotter (screen_address, nextpixel & 15, count, output);
 
  if (numpixels <= 0) return;
 
  output += count;
  numpixels -= count;
  nextpixel += count;
 }

 screen_address = (UINT16 *) (bgtable->vrmapaddress + vmapoffset) +
  (nextpixel - 0x200) / 16;

 plotter(screen_address, nextpixel & 15, numpixels, output);
}
%endif
ALIGNC
Render_16x16M_Run:
 mov ecx,[R16x16MR_Next_Pixel+R16x16MR_Inner]

 mov esi,[Mosaic_Size_Select]
 xor eax,eax
 add edi,ecx    ;first pixel
 mov al,[C_LABEL(MosaicCount)+ecx+esi]
 push eax
 mov al,[C_LABEL(MosaicLine)+ecx+esi]
 mov ecx,[HScroll+edx]
 and ecx,0x1FF
 add ecx,eax

 mov esi,[VLMapAddress+edx]
 mov ebx,[R16x16MR_VMapOffset+R16x16MR_Inner+4]
 cmp ecx,0x200
 jb .do_before_wrap
 sub ecx,0x200
 mov esi,[VRMapAddress+edx]
.do_before_wrap:

 mov ebp,ecx
 add ebx,esi

 shr ebp,4      ;(nextpixel / 16)

 pop esi
 mov eax,[Mosaic_Size]
 ;hscroll + first pixel, relative to screen of first tile to be plotted
 mov [R16x16MR_Next_Pixel+R16x16MR_Inner],ecx
 cmp esi,eax
 lea ebx,[ebx+ebp*2]
 jz .do_unclipped_before_wrap

 mov ebp,ecx
 add eax,ecx
 and ebp,byte 15
 mov ecx,[R16x16MR_Pixel_Count+R16x16MR_Inner]
 mov [R16x16MR_Next_Pixel+R16x16MR_Inner],eax   ;nextpixel += Mosaic_Size
 cmp ecx,esi

 ; left clipped
 jle .last_run

 sub ecx,esi
 push ebp
 mov [R16x16MR_Pixel_Count+R16x16MR_Inner+4],ecx    ;count -= Mosaic_Count[nextpixel]
 mov ecx,esi

;ebx = screen
;ecx = count
;ebp = pixel offset in tile
;edi = output

 call [R16x16MR_Plotter+R16x16MR_Inner+4]

 mov eax,[Mosaic_Size]
 pop ebp
 add eax,ebp

 shr eax,4
 add eax,eax
 add ebx,eax

.do_unclipped_before_wrap:
 mov ecx,0x1FF
 mov ebp,[R16x16MR_Next_Pixel+R16x16MR_Inner]
 cmp ecx,ebp
 jb .do_after_wrap

; int count = min(numpixels,
;  nextpixel <= 256 ? 256 : 511 - nextpixel + Mosaic_Count[511 - nextpixel]);
 mov eax,0x100
 sub ebp,eax
 jbe .fixup_done

.fixup:
 mov esi,[Mosaic_Size_Select]
 sub eax,ebp
 xor ecx,ecx
 mov cl,[C_LABEL(MosaicCount)+eax-1+esi]
 dec eax
 add eax,ecx
.fixup_done:

; plotter (screen_address, nextpixel & 15, count, output);
 and ebp,byte 15

 mov ecx,[R16x16MR_Pixel_Count+R16x16MR_Inner]
 cmp ecx,eax
 jle .last_run

 add [R16x16MR_Next_Pixel+R16x16MR_Inner],eax   ;nextpixel += count
 sub ecx,eax
 mov [R16x16MR_Pixel_Count+R16x16MR_Inner],ecx  ;numpixels -= count
 mov ecx,eax

; if (numpixels <= 0) return;
; output += count;

 call [R16x16MR_Plotter+R16x16MR_Inner]

 mov ebp,[R16x16MR_Next_Pixel+R16x16MR_Inner]

.do_after_wrap:
 mov ebx,0x1FF
 mov edx,[R16x16MR_BG_Table+R16x16MR_Inner]
 and ebx,ebp
 mov esi,[R16x16MR_VMapOffset+R16x16MR_Inner]
 shr ebx,4
 and ebp,byte 15
 add ebx,ebx
 mov ecx,[R16x16MR_Pixel_Count+R16x16MR_Inner]
 add ebx,esi
 mov esi,[VRMapAddress+edx]
 add ebx,esi

; screen_address = (UINT16 *) ((bgtable->vrmapaddress + vmapoffset) +
;  (nextpixel - 0x200) / 16);
;
; plotter(screen_address, nextpixel & 15, numpixels, output);

.last_run:
 jmp [R16x16MR_Plotter+R16x16MR_Inner]

%define R16x16M_Local_Bytes 32
%define R16x16M_Countdown esp+28
%define R16x16M_Current_Line_Mosaic esp+24
%define R16x16M_Plotter_Table esp+20
%define R16x16M_Clipped esp+16
%define R16x16M_BG_Table esp+12
%define R16x16M_Current_Line esp+8
%define R16x16M_BaseDestPtr esp+4
%define R16x16M_Lines esp

%macro Render_16x16M 1
ALIGNC
EXPORT_C Render_16x16M_C%1
%ifndef NO_NP_RENDER
 mov ecx,C_LABEL(Plot_Lines_NP_16x16M_Table_C%1)
 test al,al
 jnz .have_plotter
%endif

 mov ecx,C_LABEL(Plot_Lines_V_16x16M_Table_C%1)

.have_plotter:
%if %1 == 2
 mov eax,[M0_Color+edx]
 mov [Palette_Base],eax
%endif
 jmp Render_16x16M_Base
%endmacro

Render_16x16M 2
Render_16x16M 4
Render_16x16M 8

ALIGNC
Render_16x16M_Base:
 push dword [MosaicCountdown]
 push dword [LineCounter+edx]
 push ecx
 push esi
 push edx
 push ebx
 push edi
 push ebp

 mov eax,[SetAddress+edx]
 mov [TilesetAddress],eax

.next_line:
 mov edx,[R16x16M_BG_Table]

 mov eax,[R16x16M_Current_Line_Mosaic]
 call Sort_Screen_Height

 mov eax,[R16x16M_Current_Line_Mosaic]
;mov ebx,[Mosaic_Size_Select]
;xor ecx,ecx
;mov cl,[C_LABEL(MosaicCount)+eax+ebx]
;mov al,[C_LABEL(MosaicLine)+eax+ebx]
;push ecx
 SORT_TILES_16_TALL
;pop ecx
 mov ecx,[R16x16M_Countdown]
 test ecx,ecx
 jnz .no_reload
 mov ecx,[Mosaic_Size]
 mov [R16x16M_Countdown],ecx
.no_reload:
 mov ebp,[R16x16M_Lines]

 cmp ecx,ebp
 ja .no_multi
 mov ebp,ecx
.no_multi:
 cmp ebp,byte 8
 jb .not_too_many
 mov ebp,8
.not_too_many:
 mov edi,[R16x16M_BaseDestPtr]
 mov eax,ebp
 shl eax,8
 lea ecx,[edi+ebp*GfxBufferLineSlack]
 add eax,ecx

 mov ecx,[R16x16M_Plotter_Table]
 mov [R16x16M_BaseDestPtr],eax
 mov eax,[C_LABEL(SNES_Screen8)]
 add edi,eax
 mov ecx,[ecx+ebp*4-4]

 mov esi,[R16x16M_Clipped]
 push ebp
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
 mov edx,[R16x16M_BG_Table+24]
 sub cl,bl
 setz ch

 push edx
 push ebx
 push ecx

 dec al
 je .last_run

.not_last_run:
 mov [esp+28],al
 call Render_16x16M_Run

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
 call Render_16x16M_Run
 add esp,byte 32

.done:
 pop ebp

 mov eax,[R16x16M_Current_Line]
 mov ecx,[R16x16M_Lines]
 mov edx,[R16x16M_Countdown]
 add eax,ebp
 sub edx,ebp
 jne .no_update_linecounter
 mov [R16x16M_Current_Line_Mosaic],eax
.no_update_linecounter:
 sub ecx,ebp
 mov [R16x16M_Current_Line],eax
 mov [R16x16M_Countdown],edx
 mov [R16x16M_Lines],ecx

%ifndef LAYERS_PER_LINE
;cmp dword [R16x16M_Lines],0
 jnz .next_line
%endif

 mov edx,[R16x16M_BG_Table]
 mov al,[Tile_Priority_Used]
 mov [Priority_Used+edx],al
 mov ah,[Tile_Priority_Unused]
 mov [Priority_Unused+edx],ah

 add esp,byte R16x16M_Local_Bytes
 ret

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high, %3 = lines
%macro Plot_Lines_16x16M_C2 3
ALIGNC
%if %2 > 0
%%wrong_priority_last:
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Unused],cl
%endif
 add edi,ecx
 add ebp,ecx
%%return:
 ret

ALIGNC
%1_check:
 mov eax,[Mosaic_Size]
%%wrong_priority_same_tile:
 cmp ecx,eax
 jbe %%wrong_priority_last
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Unused],al
%endif
 add edi,eax
 add ebp,eax
 sub ecx,eax

 cmp ebp,byte 16
 jb %%wrong_priority_same_tile
%endif

%%next_tile:
 mov eax,ebp
 and ebp,byte 15
 shr eax,4
 add eax,eax
 add ebx,eax        ; Update screen pointer

EXPORT_C %1     ; Define label, entry point
 mov al,[ebx+1]

 Check_Tile_Priority %2, %1_check

 push ebx
 push ebp
 mov ebp,[LineAddressY]
 test al,al         ; Check Y flip
 mov si,[ebx]       ; Get tile #
 js %%flip_y
 mov ebp,[LineAddress]

%%flip_y:
 shl esi,3
 mov edx,eax
 add esi,ebp
 and edx,byte 7*4   ; Get palette

 mov ebp,[Palette_Base]

 mov edx,[palette_2bpl+edx]
 or edx,ebp         ; Adjust palette for mode 0
 pop ebp

 add al,al      ; Get X flip (now in MSB)
 mov eax,[Mosaic_Size]
 js %%xflip

%%flip_none_same_tile:
 push esi
 push ebp
 and ebp,byte 8
 add esi,ebp
 xor ebp,byte -1
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,[TilesetAddress]
 and esi,0xFFFF * 4 / 8 ; Clip to VRAM
 lea esi,[C_LABEL(TileCache2)+esi*8+ebp+1]
 pop ebp

 cmp ecx,eax
 ja %%flip_none_partial
 mov eax,ecx
%%flip_none_partial:
 mov bl,[esi+ebp]
 pop esi
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],al
%endif
 and bl,dl
 jz %%flip_none_empty_run

;eax = count, esi = source base, ebp = offset, edi = dest, ecx = # left
;edx = palette, bl = pixel
 add ebp,eax
 sub ecx,eax

%%flip_none_next_pixel:
%assign PLM16x16_Dest_Offset 0
%rep %3
 mov [edi+PLM16x16_Dest_Offset],bl
%assign PLM16x16_Dest_Offset (PLM16x16_Dest_Offset + GfxBufferLinePitch)
%endrep
 inc edi
 dec eax
 jnz %%flip_none_next_pixel

 mov eax,[Mosaic_Size]
 test ecx,ecx
 jz %%flip_none_return

 cmp ebp,byte 16
 jb %%flip_none_same_tile

 pop ebx
 jmp %%next_tile

ALIGNC
%%flip_none_empty_run:
 add edi,eax
 add ebp,eax
 sub ecx,eax
 jz %%flip_none_return

 cmp ebp,byte 16
 jb %%flip_none_same_tile

 pop ebx
 jmp %%next_tile

%%flip_none_return:
 pop ebx
 ret

ALIGNC
%%xflip:
 xor ebp,byte -1
%%flip_x_same_tile:
 push esi
 push ebp
 and ebp,byte 8
 add esi,ebp
 xor ebp,byte 8
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,[TilesetAddress]
 and esi,0xFFFF * 4 / 8 ; Clip to VRAM
 lea esi,[C_LABEL(TileCache2)+esi*8+ebp+8]
 pop ebp

 cmp ecx,eax
 ja %%flip_x_partial
 mov eax,ecx
%%flip_x_partial:
 mov bl,[esi+ebp]
 pop esi
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],al
%endif
 and bl,dl
 jz %%flip_x_empty_run

;eax = count, esi = source base, ebp = offset, edi = dest, ecx = # left
;edx = palette, bl = pixel
 sub ebp,eax
 sub ecx,eax

%%flip_x_next_pixel:
%assign PLM16x16_Dest_Offset 0
%rep %3
 mov [edi+PLM16x16_Dest_Offset],bl
%assign PLM16x16_Dest_Offset (PLM16x16_Dest_Offset + GfxBufferLinePitch)
%endrep
 inc edi
 dec eax
 jnz %%flip_x_next_pixel

 mov eax,[Mosaic_Size]
 test ecx,ecx
 jz %%flip_x_return

 cmp ebp,byte ~16
 ja %%flip_x_same_tile

 pop ebx
 xor ebp,byte -1
 jmp %%next_tile

%%flip_x_empty_run:
 add edi,eax
 sub ebp,eax
 sub ecx,eax
 jz %%flip_x_return

 cmp ebp,byte ~16
 ja %%flip_x_same_tile

 pop ebx
 xor ebp,byte -1
 jmp %%next_tile

%%flip_x_return:
 pop ebx
 ret
%endmacro

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high, %3 = lines
%macro Plot_Lines_16x16M_C4 3
ALIGNC
%if %2 > 0
%%wrong_priority_last:
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Unused],cl
%endif
 add edi,ecx
 add ebp,ecx
%%return:
 ret

ALIGNC
%1_check:
 mov eax,[Mosaic_Size]
%%wrong_priority_same_tile:
 cmp ecx,eax
 jbe %%wrong_priority_last
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Unused],al
%endif
 add edi,eax
 add ebp,eax
 sub ecx,eax

 cmp ebp,byte 16
 jb %%wrong_priority_same_tile
%endif

%%next_tile:
 mov eax,ebp
 and ebp,byte 15
 shr eax,4
 add eax,eax
 add ebx,eax        ; Update screen pointer

EXPORT_C %1     ; Define label, entry point
 mov al,[ebx+1]

 Check_Tile_Priority %2, %1_check

 push ebx
 push ebp
 mov ebp,[LineAddressY]
 test al,al         ; Check Y flip
 mov si,[ebx]       ; Get tile #
 js %%flip_y
 mov ebp,[LineAddress]

%%flip_y:
 shl esi,3
 mov edx,eax
 add esi,ebp
 and edx,byte 7*4   ; Get palette

 mov edx,[palette_4bpl+edx]
 pop ebp

 add al,al      ; Get X flip (now in MSB)
 mov eax,[Mosaic_Size]
 js %%xflip

%%flip_none_same_tile:
 push esi
 push ebp
 and ebp,byte 8
 add esi,ebp
 xor ebp,byte -1
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,[TilesetAddress]
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM
 lea esi,[C_LABEL(TileCache4)+esi*8+ebp+1]
 pop ebp

 cmp ecx,eax
 ja %%flip_none_partial
 mov eax,ecx
%%flip_none_partial:
 mov bl,[esi+ebp]
 pop esi
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],al
%endif
 and bl,dl
 jz %%flip_none_empty_run

;eax = count, esi = source base, ebp = offset, edi = dest, ecx = # left
;edx = palette, bl = pixel
 add ebp,eax
 sub ecx,eax

%%flip_none_next_pixel:
%assign PLM16x16_Dest_Offset 0
%rep %3
 mov [edi+PLM16x16_Dest_Offset],bl
%assign PLM16x16_Dest_Offset (PLM16x16_Dest_Offset + GfxBufferLinePitch)
%endrep
 inc edi
 dec eax
 jnz %%flip_none_next_pixel

 mov eax,[Mosaic_Size]
 test ecx,ecx
 jz %%flip_none_return

 cmp ebp,byte 16
 jb %%flip_none_same_tile

 pop ebx
 jmp %%next_tile

%%flip_none_empty_run:
 add edi,eax
 add ebp,eax
 sub ecx,eax
 jz %%flip_none_return

 cmp ebp,byte 16
 jb %%flip_none_same_tile

 pop ebx
 jmp %%next_tile

%%flip_none_return:
 pop ebx
 ret

ALIGNC
%%xflip:
 xor ebp,byte -1
%%flip_x_same_tile:
 push esi
 push ebp
 and ebp,byte 8
 add esi,ebp
 xor ebp,byte 8
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,[TilesetAddress]
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM
 lea esi,[C_LABEL(TileCache4)+esi*8+ebp+8]
 pop ebp

 cmp ecx,eax
 ja %%flip_x_partial
 mov eax,ecx
%%flip_x_partial:
 mov bl,[esi+ebp]
 pop esi
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],al
%endif
 and bl,dl
 jz %%flip_x_empty_run

;eax = count, esi = source base, ebp = offset, edi = dest, ecx = # left
;edx = palette, bl = pixel
 sub ebp,eax
 sub ecx,eax

%%flip_x_next_pixel:
%assign PLM16x16_Dest_Offset 0
%rep %3
 mov [edi+PLM16x16_Dest_Offset],bl
%assign PLM16x16_Dest_Offset (PLM16x16_Dest_Offset + GfxBufferLinePitch)
%endrep
 inc edi
 dec eax
 jnz %%flip_x_next_pixel

 mov eax,[Mosaic_Size]
 test ecx,ecx
 jz %%flip_x_return

 cmp ebp,byte ~16
 ja %%flip_x_same_tile

 pop ebx
 xor ebp,byte -1
 jmp %%next_tile

%%flip_x_empty_run:
 add edi,eax
 sub ebp,eax
 sub ecx,eax
 jz %%flip_x_return

 cmp ebp,byte ~16
 ja %%flip_x_same_tile

 pop ebx
 xor ebp,byte -1
 jmp %%next_tile

%%flip_x_return:
 pop ebx
 ret
%endmacro

;for mosaic, keep track of # pixels done, return # tiles in next set skipped

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high, %3 = lines
%macro Plot_Lines_16x16M_C8 3
ALIGNC
%if %2 > 0
%%wrong_priority_last:
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Unused],cl
%endif
 add edi,ecx
 add ebp,ecx
%%return:
 ret

ALIGNC
%1_check:
 mov eax,[Mosaic_Size]
%%wrong_priority_same_tile:
 cmp ecx,eax
 jbe %%wrong_priority_last
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Unused],al
%endif
 add edi,eax
 add ebp,eax
 sub ecx,eax

 cmp ebp,byte 16
 jb %%wrong_priority_same_tile
%endif

%%next_tile:
 mov eax,ebp
 and ebp,byte 15
 shr eax,4
 add eax,eax
 add ebx,eax        ; Update screen pointer

EXPORT_C %1     ; Define label, entry point
 mov al,[ebx+1]

 Check_Tile_Priority %2, %1_check

 push ebp
 mov si,[ebx]       ; Get tile #
 shl esi,3          ; 8
 test al,al ; Check Y flip
 mov ebp,[LineAddressY]
 js %%flip_y
 mov ebp,[LineAddress]

%%flip_y:

 add esi,ebp
 pop ebp

 add al,al      ; Get X flip (now in MSB)
 mov eax,[Mosaic_Size]
 js %%xflip

%%flip_none_same_tile:

 push esi
 push ebp
 and ebp,byte 8
 add esi,ebp
 xor ebp,byte -1
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,[TilesetAddress]
 and esi,0xFFFF / 8 ; Clip to VRAM
 lea esi,[C_LABEL(TileCache8)+esi*8+ebp+1]
 pop ebp

 cmp ecx,eax
 ja %%flip_none_partial
 mov eax,ecx
%%flip_none_partial:
 mov dl,[esi+ebp]
 pop esi
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],al
%endif
 test dl,dl
 jz %%flip_none_empty_run

;eax = count, esi = source base, ebp = offset, edi = dest, ecx = # left
;ebx = screen map, dl = pixel
 add ebp,eax
 sub ecx,eax

%%flip_none_next_pixel:
%assign PLM16x16_Dest_Offset 0
%rep %3
 mov [edi+PLM16x16_Dest_Offset],dl
%assign PLM16x16_Dest_Offset (PLM16x16_Dest_Offset + GfxBufferLinePitch)
%endrep
 inc edi
 dec eax
 jnz %%flip_none_next_pixel

 mov eax,[Mosaic_Size]
 test ecx,ecx
 jz %%flip_none_return

 cmp ebp,byte 16
 jb %%flip_none_same_tile

 jmp %%next_tile

ALIGNC
%%flip_none_empty_run:
 add edi,eax
 add ebp,eax
 sub ecx,eax
 jz %%flip_none_return

 cmp ebp,byte 16
 jb %%flip_none_same_tile

 jmp %%next_tile

%%flip_none_return:
 ret

ALIGNC
%%xflip:
 xor ebp,byte -1
%%flip_x_same_tile:
 push esi
 push ebp
 and ebp,byte 8
 add esi,ebp
 xor ebp,byte 8
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,[TilesetAddress]
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM
 lea esi,[C_LABEL(TileCache8)+esi*8+ebp+8]
 pop ebp

 cmp ecx,eax
 ja %%flip_x_partial
 mov eax,ecx
%%flip_x_partial:
 mov dl,[esi+ebp]
 pop esi
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],al
%endif
 test dl,dl
 jz %%flip_x_empty_run

;eax = count, esi = source base, ebp = offset, edi = dest, ecx = # left
;ebx = screen map, dl = pixel
 sub ebp,eax
 sub ecx,eax

%%flip_x_next_pixel:
%assign PLM16x16_Dest_Offset 0
%rep %3
 mov [edi+PLM16x16_Dest_Offset],dl
%assign PLM16x16_Dest_Offset (PLM16x16_Dest_Offset + GfxBufferLinePitch)
%endrep
 inc edi
 dec eax
 jnz %%flip_x_next_pixel

 mov eax,[Mosaic_Size]
 test ecx,ecx
 jz %%flip_x_return

 cmp ebp,byte ~16
 ja %%flip_x_same_tile

 xor ebp,byte -1
 jmp %%next_tile

ALIGNC
%%flip_x_empty_run:
 add edi,eax
 sub ebp,eax
 sub ecx,eax
 jz %%flip_x_return

 cmp ebp,byte ~16
 ja %%flip_x_same_tile

 xor ebp,byte -1
 jmp %%next_tile

%%flip_x_return:
 ret
%endmacro

;%1 = depth, %2 = count
%macro Generate_Line_Plotters_16x16M 2
%ifndef NO_NP_RENDER
 Plot_Lines_16x16M_C%1 Plot_Lines_%2_NP_16x16M_C%1,0,%2
%endif
 Plot_Lines_16x16M_C%1 Plot_Lines_%2_V_16x16M_C%1,3,%2
%endmacro

%macro Generate_Line_Plotters_16x16M_Depth 1
Generate_Line_Plotters_16x16M %1,1
Generate_Line_Plotters_16x16M %1,2
Generate_Line_Plotters_16x16M %1,3
Generate_Line_Plotters_16x16M %1,4
Generate_Line_Plotters_16x16M %1,5
Generate_Line_Plotters_16x16M %1,6
Generate_Line_Plotters_16x16M %1,7
Generate_Line_Plotters_16x16M %1,8
%endmacro

Generate_Line_Plotters_16x16M_Depth 2
Generate_Line_Plotters_16x16M_Depth 4
Generate_Line_Plotters_16x16M_Depth 8

section .data
;%1 = type, %2 = depth
%macro Generate_Line_Plotter_Table_16x16M 2
ALIGND
EXPORT_C Plot_Lines_%1_16x16M_Table_C%2
dd C_LABEL(Plot_Lines_1_%1_16x16M_C%2)
dd C_LABEL(Plot_Lines_2_%1_16x16M_C%2)
dd C_LABEL(Plot_Lines_3_%1_16x16M_C%2)
dd C_LABEL(Plot_Lines_4_%1_16x16M_C%2)
dd C_LABEL(Plot_Lines_5_%1_16x16M_C%2)
dd C_LABEL(Plot_Lines_6_%1_16x16M_C%2)
dd C_LABEL(Plot_Lines_7_%1_16x16M_C%2)
dd C_LABEL(Plot_Lines_8_%1_16x16M_C%2)
%endmacro

%ifndef NO_NP_RENDER
Generate_Line_Plotter_Table_16x16M NP,2
Generate_Line_Plotter_Table_16x16M NP,4
Generate_Line_Plotter_Table_16x16M NP,8
%endif

Generate_Line_Plotter_Table_16x16M V,2
Generate_Line_Plotter_Table_16x16M V,4
Generate_Line_Plotter_Table_16x16M V,8

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
