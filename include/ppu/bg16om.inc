%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

%define RO16x16M_MAX_LINE_COUNT 8

%define RO16x16M_Local_Bytes 64+8+24
%define RO16x16M_Plotter_Table esp+60+8+24
%define RO16x16M_Clipped esp+56+8+24
%define RO16x16M_BG_Table esp+52+8+24
%define RO16x16M_Current_Line esp+48+8+24
%define RO16x16M_BaseDestPtr esp+44+8+24
%define RO16x16M_Lines esp+40+8+24

; contains bit for determining planes to affect
%define RO16x16M_OC_Flag esp+36+8+24

; Same as LineAddress(Y), additional vars for offset change code
%define RO16x16M_LineAddressOffset  esp+32+8+24
%define RO16x16M_LineAddressOffsetY esp+28+8+24

%define RO16x16M_FirstTile esp+24+8+24

; Scroll-adjusted tile map address for offset
;  change code when tile offset not changed
%define RO16x16M_MapAddress_Current esp+20+8+24

; Current render line # for offset change layers
; Used for vertical mosaic effect
%define RO16x16M_Current_Line_Offset esp+16+8+24

%define RO16x16M_TMapAddress esp+12+8+24
%define RO16x16M_BMapAddress esp+8+8+24
%define RO16x16M_RMapDifference esp+4+8+24

%define RO16x16MR_LastRunCount esp+8+24

;Plotter table, adjusted for line count
%define RO16x16MR_Plotter_Table esp+4+24
;Line count for updating remaining lines and output pointer
%define RO16x16MR_LineCount esp+24

%define RO16x16M_Runs_Left esp+20
%define RO16x16M_Output esp+16
%define RO16x16M_RunListPtr esp+12
%define RO16x16MR_VMapOffset esp+8
;VMapOffset can be eliminated by merging its value with VL/VRMapAddress?

%define RO16x16MR_BG_Table RO16x16_BG_Table
%define RO16x16MR_Next_Pixel esp+4
%define RO16x16MR_Pixel_Count esp
%define RO16x16MR_Inner (4)
%define RO16x16M_Inner (8)

;VMapOffset = bg_line_offset (vscroll + current line) / bg tile size *
; 32 words (per line)
;Plotter = background plotting handler, passed:
; ebx = VRAM screen address of first tile
;  cl = tile count to plot
; edi = pointer to destination surface, leftmost pixel of first tile
;  (even if clipped)

 ; ebx = tile address offset from first tile on line
 ;  (nextpixel + (hscroll & 7)) / 8 * 2
 ; esi = offset screen map address of first offset-change capable tile
 ;  to be drawn
 ;  VLMapAddressBG3 + OffsetChangeMap_VOffset +
 ;   HScroll_3 / 8 * 2 - (ebx ? 2 : 0)
 ; cl = # tiles
 ; ch = offset-change enable bit

;BG_Table = pointer to background structure
;Next_Pixel = first pixel in run to be plotted
;     (local) hscroll-adjusted pixel to be plotted next (not always updated)
;Pixel_Count = count of pixels in run to be plotted
;edx = pointer to background structure (same as passed on stack)
;edi = native pointer to destination surface, start of first line
; to be drawn in output

%if 0
C-pseudo code
void Render_Offset_16x16M_Run
(BGTABLE *bgtable, UINT8 *output, int vmapoffset, int nextpixel,
 int numpixels,
 void (**plotter_table)(UINT16 *offset_screen_address, int tile_offset,
  UINT8 pixeloffset, UINT8 pixelcount, UINT8 *output))
)
{
 UINT16 *offset_screen_address;
 int clipped_count = Mosaic_Count[nextpixel];
 int tile_offset;

 output += nextpixel;

 nextpixel = Mosaic_Line[nextpixel];
 tile_offset = (nextpixel + (bgtable->hscroll & 7)) / 8;

 nextpixel += (bgtable->hscroll & 7) + bg3table.hscroll & 0xF8;
 if (nextpixel < 0x108)
 {
  offset_screen_address = (UINT16 *) (bg3table.vlmapaddress + vmapoffset +
   nextpixel / 8 * 2 - (tile_offset ? 2 : 0));
 }
 else
 {
  nextpixel -= 0x100;
  offset_screen_address = (UINT16 *) (bg3table.vrmapaddress + vmapoffset +
   nextpixel / 8 * 2 - (tile_offset ? 2 : 0));
 }

 nextpixel -= 8;

 if (clipped_count != Mosaic_Size)
 {
  ; left clipped

  plotter_table[(tile_offset ? 1 : 0](offset_screen_address, tile_offset,
   nextpixel & 7, min(numpixels, clipped_count), output);

  if (numpixels <= clipped_count) return;

  offset_screen_address += ((nextpixel & 7) + Mosaic_Size) >> 3;
  tile_offset += ((nextpixel & 7) + Mosaic_Size) >> 3;
  output += clipped_count;
  numpixels -= clipped_count;
  nextpixel += Mosaic_Size;
 }

 if (nextpixel <= 0xFF)
 {
  int count = min(numpixels, 255 - nextpixel + Mosaic_Count[255 - nextpixel];
  plotter (screen_address, nextpixel & 7, count, output);
  plotter_table[(tile_offset ? 1 : 0](offset_screen_address, tile_offset,
   nextpixel & 7, count, output);
 
  if (numpixels <= count) return;
 
  tile_offset += ((nextpixel & 7) + count) >> 3;
  output += count;
  numpixels -= count;
  nextpixel += count;
 }

 offset_screen_address = (UINT16 *) (bg3table.vrmapaddress + vmapoffset) +
  (nextpixel - 0x100) / 8;

 plotter_table[1](offset_screen_address, tile_offset,
  nextpixel & 7, numpixels, output);
}
%endif
ALIGNC
Render_Offset_16x16M_Run:
 mov ecx,[RO16x16MR_Next_Pixel+RO16x16MR_Inner]
 mov esi,[Mosaic_Size_Select]
 xor eax,eax
 add edi,ecx    ;first pixel
 mov al,[C_LABEL(MosaicCount)+ecx+esi]
 mov [RO16x16MR_LastRunCount+RO16x16MR_Inner],eax
 mov al,[C_LABEL(MosaicLine)+ecx+esi]
 mov ecx,[HScroll_3]

 mov ebx,[HScroll+edx]
 and ecx,0xF8
 and ebx,byte 7
 add ebx,eax
 add ecx,ebx

 mov eax,[VLMapAddressBG3]
 mov edx,[RO16x16MR_VMapOffset+RO16x16MR_Inner]
 cmp ecx,0x108
 jb .do_before_wrap
 sub ecx,0x100
 mov eax,[VRMapAddressBG3]
.do_before_wrap:

 shr ebx,3
 mov ebp,ecx
 add eax,edx

 shr ecx,3      ;(nextpixel / 8)
 add ebx,byte -1

 ;hscroll + first pixel, relative to screen of first tile to be plotted
 sbb edx,edx
 sub ebp,byte 8
 inc ebx
 and edx,byte 2
 add ebx,ebx
 lea esi,[eax+ecx*2]

 sub esi,edx
 mov ecx,[Mosaic_Size]
 add edx,edx
 mov eax,[RO16x16MR_LastRunCount+RO16x16MR_Inner]
 mov [RO16x16MR_Next_Pixel+RO16x16MR_Inner],ebp
 cmp eax,ecx
 jz .do_unclipped_before_wrap

 mov ecx,[RO16x16MR_Pixel_Count+RO16x16MR_Inner]
 and ebp,byte 7
 cmp ecx,eax

 ; left clipped
 jle .last_run

 sub ecx,eax
 mov [RO16x16MR_LastRunCount+RO16x16MR_Inner],ebp
 mov [RO16x16MR_Pixel_Count+RO16x16MR_Inner],ecx    ;count -= Mosaic_Count[nextpixel]

 mov ecx,eax

 mov eax,[RO16x16MR_Plotter_Table+RO16x16MR_Inner]
 call [eax+edx]

 mov eax,[Mosaic_Size]
 add [RO16x16MR_Next_Pixel+RO16x16MR_Inner],eax
 mov ebp,[RO16x16MR_LastRunCount+RO16x16MR_Inner]
 add eax,ebp

 shr eax,3
 add eax,eax
 add ebx,eax
 lea esi,[esi+eax-2]

 mov edx,4

.do_unclipped_before_wrap:
 mov eax,0xFF
 mov ebp,[RO16x16MR_Next_Pixel+RO16x16MR_Inner]
 sub eax,ebp
 jl .do_after_wrap
 jb .no_fixup

; int count = min(numpixels, 255 - nextpixel + Mosaic_Count[255 - nextpixel];
; plotter (screen_address, nextpixel & 7, count, output);
 mov ebp,[Mosaic_Size_Select]
 xor ecx,ecx
 mov cl,[C_LABEL(MosaicCount)+eax+ebp]
 mov ebp,[RO16x16MR_Next_Pixel+RO16x16MR_Inner]
 add eax,ecx

.no_fixup:
 mov ecx,[RO16x16MR_Pixel_Count+RO16x16MR_Inner]
 and ebp,byte 7
 cmp ecx,eax
 jle .last_run

 add [RO16x16MR_Next_Pixel+RO16x16MR_Inner],eax ;nextpixel += count
 sub ecx,eax
 mov [RO16x16MR_Pixel_Count+RO16x16MR_Inner],ecx    ;numpixels -= count
 mov ecx,eax

; if (numpixels <= 0) return;
; output += count;

 mov eax,[RO16x16MR_Plotter_Table+RO16x16MR_Inner]
 call [eax+edx]

 shr ebp,3
 add ebp,ebp
 add ebx,ebp

 mov ebp,[RO16x16MR_Next_Pixel+RO16x16MR_Inner]

.do_after_wrap:
 mov edx,0xFF
 and edx,ebp
 mov esi,[RO16x16MR_VMapOffset+RO16x16MR_Inner]
 shr edx,3
 and ebp,byte 7
 add edx,edx
 mov ecx,[RO16x16MR_Pixel_Count+RO16x16MR_Inner]
 add esi,edx
 mov edx,[VRMapAddressBG3]
 add esi,edx

 mov edx,4

.last_run:
 mov eax,[RO16x16MR_Plotter_Table+RO16x16MR_Inner]
 call [eax+edx]

 ret

; -Tile on left edge of screen not affected by V-offset change
; -Offset change map is scrollable - always 8x8

%macro Render_Offset_16x16M 1
ALIGNC
EXPORT_C Render_Offset_16x16M_C%1
%ifndef NO_NP_RENDER
 mov ecx,C_LABEL(Plot_Lines_NP_Offset_16x16M_Table_C%1)
 test al,al
 jnz .have_plotter
%endif

 mov ecx,C_LABEL(Plot_Lines_V_Offset_16x16M_Table_C%1)
.have_plotter:
%if %1 == 2
 mov esi,[M0_Color+edx]
 mov [Palette_Base],esi
%endif

 jmp Render_Offset_16x16M_Base
%endmacro

Render_Offset_16x16M 2
Render_Offset_16x16M 4
Render_Offset_16x16M 8

ALIGNC
Render_Offset_16x16M_Base:
 push ecx
 push esi
 push edx ;BG_Table
 push ebx ;Current_Line
 push edi ;BaseDestPtr
 push ebp ;Lines
 sub esp,byte RO16x16M_Local_Bytes-24

 ; ch contains bit for determining planes to affect
 mov ch,[OC_Flag+edx]
 mov eax,[SetAddress+edx]
 mov [RO16x16M_OC_Flag],ch
 mov [TilesetAddress],eax

.next_line:
 mov edx,[RO16x16M_BG_Table]

 mov eax,[RO16x16M_Current_Line]
 mov ebx,[Mosaic_Size_Select]
 xor ecx,ecx
 mov cl,[C_LABEL(MosaicCount)+eax+ebx]
 mov al,[C_LABEL(MosaicLine)+eax+ebx]
 mov [RO16x16M_Current_Line_Offset],eax
 mov [RO16x16MR_LineCount],ecx
 call Sort_Screen_Height

 mov eax,[RO16x16M_Current_Line_Offset]
 SORT_TILES_16_TALL [RO16x16M_MapAddress_Current]

 ; Corrupts eax,ecx,ebp
 mov eax,[TLMapAddress+edx]
 mov ecx,[RO16x16M_Current_Line_Offset]
 mov edi,[BLMapAddress+edx]
 mov ebp,[VScroll+edx]
 mov [RO16x16M_TMapAddress],eax
 add ecx,ebp
 mov [RO16x16M_BMapAddress],edi
 mov ebp,[RO16x16M_MapAddress_Current]

 and ch,2
;global Tile_Height
;Tile_Height equ $-1    ; 1 = 8x8, 16x8, 2 = 16x16
 jz .current_line_in_screen_map_top
 mov eax,edi
.current_line_in_screen_map_top:
 add eax,ebp

 mov ebp,[HScroll+edx]
 mov [RO16x16M_MapAddress_Current],eax
 shr ebp,3
 mov eax,[TRMapAddress+edx]
 mov ecx,[TLMapAddress+edx]
 mov [RO16x16M_FirstTile],ebp   ;FirstTile = (HScroll / 8)

 sub eax,ecx
 mov [RO16x16M_RMapDifference],eax

 mov ebp,[RO16x16M_Lines]
 mov ecx,[RO16x16MR_LineCount]

 cmp ecx,ebp
 ja .no_multi
 mov ebp,ecx
.no_multi:
 cmp ebp,byte RO16x16M_MAX_LINE_COUNT
 jb .not_too_many
 mov ebp,RO16x16M_MAX_LINE_COUNT
.not_too_many:
 mov [RO16x16MR_LineCount],ebp
 mov ecx,[RO16x16M_Plotter_Table]
 lea eax,[ecx+ebp*8-8]
 mov [RO16x16MR_Plotter_Table],eax  ;renderer

 mov eax,[C_LABEL(SNES_Screen8)]
 mov edi,[RO16x16M_BaseDestPtr]
 add edi,eax

 mov esi,[RO16x16M_Clipped]
 mov al,[Win_Count+edx+esi]

 test al,al
 jz .done

 mov ebx,[OffsetChangeMap_VOffset]
 mov [RO16x16M_Runs_Left],eax
 lea edx,[Win_Bands+edx+esi]

 mov [RO16x16M_Output],edi
 mov [RO16x16M_RunListPtr],edx
 mov [RO16x16MR_VMapOffset],ebx ;vertical screen map address
 xor ebx,ebx
 mov bl,[edx]

 xor ecx,ecx
 mov cl,[edx+1]
 mov edx,[RO16x16M_BG_Table]
 sub cl,bl
 setz ch

 mov [RO16x16MR_Next_Pixel],ebx
 mov [RO16x16MR_Pixel_Count],ecx

 dec al
 je .last_run

.not_last_run:
 mov [RO16x16M_Runs_Left],al
 call Render_Offset_16x16M_Run

 mov edx,[RO16x16M_RunListPtr]
 mov edi,[RO16x16M_Output]
 xor ebx,ebx
 xor ecx,ecx
 mov bl,[edx+2]

 mov cl,[edx+3]
 add edx,byte 2
 sub cl,bl
 mov [RO16x16M_RunListPtr],edx
 mov edx,[RO16x16M_BG_Table]

 mov [RO16x16MR_Next_Pixel],ebx
 mov [RO16x16MR_Pixel_Count],ecx

 mov al,[RO16x16M_Runs_Left]
 dec al
 jne .not_last_run
.last_run:
 call Render_Offset_16x16M_Run

.done:

 mov ebp,[RO16x16MR_LineCount]
 mov ecx,[RO16x16M_Lines]
 mov eax,[RO16x16M_Current_Line]
 sub ecx,ebp
 add eax,ebp
 mov [RO16x16M_Lines],ecx
 mov edi,[RO16x16M_BaseDestPtr]
 mov [RO16x16M_Current_Line],eax
 mov eax,ebp
 shl eax,8
 lea ecx,[edi+ebp*GfxBufferLineSlack]
 add eax,ecx
 mov [RO16x16M_BaseDestPtr],eax

%ifndef LAYERS_PER_LINE
 cmp dword [RO16x16M_Lines],0
 jnz near .next_line
%endif

 mov edx,[RO16x16M_BG_Table]
 mov al,[Tile_Priority_Used]
 mov [Priority_Used+edx],al
 mov ah,[Tile_Priority_Unused]
 mov [Priority_Unused+edx],ah

 add esp,byte RO16x16M_Local_Bytes
 ret

;%define RO16x16M_Inner 12

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high, %3 = lines
%macro Plot_Lines_Offset_16x16M_C4 3
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
 pop ebp
 pop ebx
 pop esi

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

 cmp ebp,byte 8
 jb %%wrong_priority_same_tile
%endif

%%next_tile:
 mov eax,ebp
 and ebp,byte 7
 shr eax,3
 add ebx,eax        ; Update screen pointer
 lea esi,[esi+eax*2-2]

EXPORT_C %1     ; Define label, entry point
 lea eax,[esi+2]
 mov dh,[1+esi]     ; Offset change map
 push eax
 push ebx
 push ebp

 mov ebp,[RO16x16M_FirstTile+RO16x16M_Inner+12]
 mov eax,[OffsetChangeVMap_VOffset]
 test dh,[RO16x16M_OC_Flag+RO16x16M_Inner+12]   ; H-offset enabled?
 jz .have_h_offset
 mov dl,[esi]
 mov ebp,edx
 shr ebp,3
.have_h_offset:

 mov dh,[1+esi+eax] ; Vertical offset change map
 test dh,[RO16x16M_OC_Flag+RO16x16M_Inner+12]   ; V-offset enabled?
 jz .No_VChange
 mov dl,[esi+eax]
 mov eax,[RO16x16M_Current_Line_Offset+RO16x16M_Inner+12]
 add eax,edx

.calc_v_offset:
 and ah,2
 mov esi,[RO16x16M_TMapAddress+RO16x16M_Inner+12]
 jz .line_in_screen_map_top
 mov esi,[RO16x16M_BMapAddress+RO16x16M_Inner+12]
.line_in_screen_map_top:

 ; al contains real Y offset for next tile
 shl eax,2          ; Get screen offset
 push ecx
 mov ecx,0x1F0*4    ; Current line + V scroll * 32words
 and ecx,eax
 and eax,byte 0x0F*4    ; Offset into table of line offsets
 mov edx,16*8+7
 mov eax,[Tile_Offset_Table_16_8+eax]
 sub edx,eax
 add esi,ecx
 pop ecx
 jmp short .have_v_offset

.LeftEdge:
 push esi
 push ebx
 push ebp

 mov ebp,[RO16x16M_FirstTile+RO16x16M_Inner+12]

.No_VChange:
 mov eax,[LineAddress]
 mov esi,[RO16x16M_MapAddress_Current+RO16x16M_Inner+12]
 mov edx,[LineAddressY]

.have_v_offset:
 add ebp,ebx
 mov [RO16x16M_LineAddressOffset+RO16x16M_Inner+12],eax
 mov ebx,ebp
 and ebp,byte 63    ; X offset wrap
 and ebx,byte 64
 mov [RO16x16M_LineAddressOffsetY+RO16x16M_Inner+12],edx
 mov ebx,[RO16x16M_RMapDifference+RO16x16M_Inner+12]
 jz  .tile_in_screen_map_left
 add esi,ebx
.tile_in_screen_map_left:
 mov ebx,ebp
 and ebp,byte ~1

 mov al,[esi+ebp+1] ; Combine X and Y offsets into tile map
 Check_Tile_Priority %2, near %1_check

 mov si,[esi+ebp]   ; Get tile #
 mov ebp,[RO16x16M_LineAddressOffsetY+RO16x16M_Inner+12]
 test al,al         ; Check Y flip
 js .flip_y
 mov ebp,[RO16x16M_LineAddressOffset+RO16x16M_Inner+12]

.flip_y:
 shl esi,3
 mov edx,eax
 add esi,ebp
 and edx,byte 7*4   ; Get palette
 and ebx,byte 1
 add al,al      ; Get X flip (now in MSB)
 mov ebp,[TilesetAddress]
 mov edx,[palette_4bpl+edx]
 mov eax,[Mosaic_Size]
 js near %%xflip

 lea esi,[esi+ebx*8]
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,ebp
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM

 pop ebp
 lea esi,[C_LABEL(TileCache4)+esi*8]

%%flip_none_same_tile:
 cmp ecx,eax
 ja %%flip_none_partial
 mov eax,ecx
%%flip_none_partial:
 mov bl,[esi+ebp]
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
%undef PLM16x16_Dest_Offset
 inc edi
 dec eax
 jnz %%flip_none_next_pixel

 mov eax,[Mosaic_Size]
 test ecx,ecx
 jz %%flip_none_return

 cmp ebp,byte 8
 jb %%flip_none_same_tile

 pop ebx
 pop esi
 jmp %%next_tile

%%flip_none_empty_run:
 add edi,eax
 add ebp,eax
 sub ecx,eax
 jz %%flip_none_return

 cmp ebp,byte 8
 jb %%flip_none_same_tile

 pop ebx
 pop esi
 jmp %%next_tile

%%flip_none_return:
 pop ebx
 pop esi
 ret

ALIGNC
%%xflip:
 shl ebx,3
 add esi,byte 8
 sub esi,ebx
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,ebp
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM

 pop ebp
 lea esi,[C_LABEL(TileCache4)+esi*8+8]
 xor ebp,byte -1
%%flip_x_same_tile:
 cmp ecx,eax
 ja %%flip_x_partial
 mov eax,ecx
%%flip_x_partial:
 mov bl,[esi+ebp]
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
%undef PLM16x16_Dest_Offset
 inc edi
 dec eax
 jnz %%flip_x_next_pixel

 mov eax,[Mosaic_Size]
 test ecx,ecx
 jz %%flip_x_return

 cmp ebp,byte ~8
 ja %%flip_x_same_tile

 pop ebx
 pop esi
 xor ebp,byte -1
 jmp %%next_tile

%%flip_x_empty_run:
 add edi,eax
 sub ebp,eax
 sub ecx,eax
 jz %%flip_x_return

 cmp ebp,byte ~8
 ja %%flip_x_same_tile

 pop ebx
 pop esi
 xor ebp,byte -1
 jmp %%next_tile

%%flip_x_return:
 pop ebx
 pop esi
 ret
%endmacro

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high, %3 = lines
%macro Plot_Lines_Offset_16x16M_C2 3
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
 pop ebp
 pop ebx
 pop esi

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

 cmp ebp,byte 8
 jb %%wrong_priority_same_tile
%endif

%%next_tile:
 mov eax,ebp
 and ebp,byte 7
 shr eax,3
 add ebx,eax        ; Update screen pointer
 lea esi,[esi+eax*2-2]

EXPORT_C %1     ; Define label, entry point
 lea eax,[esi+2]
 mov dh,[1+esi]     ; Offset change map
 push eax
 push ebx
 push ebp

 mov ebp,[RO16x16M_FirstTile+RO16x16M_Inner+12]
 mov eax,[RO16x16M_Current_Line_Offset+RO16x16M_Inner+12]
 test dh,[RO16x16M_OC_Flag+RO16x16M_Inner+12]   ; Offset enabled?
 jz .No_VChange

 test dh,dh         ; vertical offset?
 jnz .calc_v_offset

 mov dl,[esi]
 mov ebp,edx
 shr ebp,3
 jmp .No_VChange

.calc_v_offset:
 mov dl,[esi]
 add eax,edx

 and ah,2
 mov esi,[RO16x16M_TMapAddress+RO16x16M_Inner+12]
 jz .line_in_screen_map_top
 mov esi,[RO16x16M_BMapAddress+RO16x16M_Inner+12]
.line_in_screen_map_top:

 ; al contains real Y offset for next tile
 shl eax,2          ; Get screen offset
 push ecx
 mov ecx,0x1F0*4    ; Current line + V scroll * 32words
 and ecx,eax
 and eax,byte 0x0F*4    ; Offset into table of line offsets
 mov edx,16*8+7
 mov eax,[Tile_Offset_Table_16_8+eax]
 sub edx,eax
 add esi,ecx
 pop ecx
 jmp short .have_v_offset

.LeftEdge:
 push esi
 push ebx
 push ebp

 mov ebp,[RO16x16M_FirstTile+RO16x16M_Inner+12]

.No_VChange:
 mov eax,[LineAddress]
 mov esi,[RO16x16M_MapAddress_Current+RO16x16M_Inner+12]
 mov edx,[LineAddressY]

.have_v_offset:
 add ebp,ebx
 mov [RO16x16M_LineAddressOffset+RO16x16M_Inner+12],eax
 mov ebx,ebp
 and ebp,byte 63    ; X offset wrap
 and ebx,byte 64
 mov [RO16x16M_LineAddressOffsetY+RO16x16M_Inner+12],edx
 mov ebx,[RO16x16M_RMapDifference+RO16x16M_Inner+12]
 jz  .tile_in_screen_map_left
 add esi,ebx
.tile_in_screen_map_left:
 mov ebx,ebp
 and ebp,byte ~1

 mov al,[esi+ebp+1] ; Combine X and Y offsets into tile map
 Check_Tile_Priority %2, near %1_check

 mov si,[esi+ebp]   ; Get tile #
 mov ebp,[RO16x16M_LineAddressOffsetY+RO16x16M_Inner+12]
 test al,al         ; Check Y flip
 js .flip_y
 mov ebp,[RO16x16M_LineAddressOffset+RO16x16M_Inner+12]

.flip_y:
 shl esi,3
 mov edx,eax
 add esi,ebp
 and edx,byte 7*4   ; Get palette
 and ebx,byte 1
 add al,al      ; Get X flip (now in MSB)
 mov ebp,[TilesetAddress]
 mov edx,[palette_2bpl+edx]
 mov eax,[Mosaic_Size]
 js near %%xflip

 lea esi,[esi+ebx*8]
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,ebp
 and esi,0xFFFF * 4 / 8 ; Clip to VRAM

 pop ebp
 lea esi,[C_LABEL(TileCache2)+esi*8]

%%flip_none_same_tile:
 cmp ecx,eax
 ja %%flip_none_partial
 mov eax,ecx
%%flip_none_partial:
 mov bl,[esi+ebp]
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
%undef PLM16x16_Dest_Offset
 inc edi
 dec eax
 jnz %%flip_none_next_pixel

 mov eax,[Mosaic_Size]
 test ecx,ecx
 jz %%flip_none_return

 cmp ebp,byte 8
 jb %%flip_none_same_tile

 pop ebx
 pop esi
 jmp %%next_tile

%%flip_none_empty_run:
 add edi,eax
 add ebp,eax
 sub ecx,eax
 jz %%flip_none_return

 cmp ebp,byte 8
 jb %%flip_none_same_tile

 pop ebx
 pop esi
 jmp %%next_tile

%%flip_none_return:
 pop ebx
 pop esi
 ret

ALIGNC
%%xflip:
 shl ebx,3
 add esi,byte 8
 sub esi,ebx
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,ebp
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM

 pop ebp
 lea esi,[C_LABEL(TileCache2)+esi*8+8]
 xor ebp,byte -1
%%flip_x_same_tile:
 cmp ecx,eax
 ja %%flip_x_partial
 mov eax,ecx
%%flip_x_partial:
 mov bl,[esi+ebp]
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
%undef PLM16x16_Dest_Offset
 inc edi
 dec eax
 jnz %%flip_x_next_pixel

 mov eax,[Mosaic_Size]
 test ecx,ecx
 jz %%flip_x_return

 cmp ebp,byte ~8
 ja %%flip_x_same_tile

 pop ebx
 pop esi
 xor ebp,byte -1
 jmp %%next_tile

%%flip_x_empty_run:
 add edi,eax
 sub ebp,eax
 sub ecx,eax
 jz %%flip_x_return

 cmp ebp,byte ~8
 ja %%flip_x_same_tile

 pop ebx
 pop esi
 xor ebp,byte -1
 jmp %%next_tile

%%flip_x_return:
 pop ebx
 pop esi
 ret
%endmacro

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high, %3 = lines
%macro Plot_Lines_Offset_16x16M_C8 3
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
 pop ebp
 pop ebx
 pop esi

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

 cmp ebp,byte 8
 jb %%wrong_priority_same_tile
%endif

%%next_tile:
 mov eax,ebp
 and ebp,byte 7
 shr eax,3
 add ebx,eax        ; Update screen pointer
 lea esi,[esi+eax*2-2]

EXPORT_C %1     ; Define label, entry point
 lea eax,[esi+2]
 mov dh,[1+esi]     ; Offset change map
 push eax
 push ebx
 push ebp

 mov ebp,[RO16x16M_FirstTile+RO16x16M_Inner+12]
 mov eax,[RO16x16M_Current_Line_Offset+RO16x16M_Inner+12]
 test dh,[RO16x16M_OC_Flag+RO16x16M_Inner+12]   ; Offset enabled?
 jz .No_VChange

 test dh,dh         ; vertical offset?
 jnz .calc_v_offset

 mov dl,[esi]
 mov ebp,edx
 shr ebp,3
 jmp .No_VChange

.calc_v_offset:
 mov dl,[esi]
 add eax,edx

 and ah,2
 mov esi,[RO16x16M_TMapAddress+RO16x16M_Inner+12]
 jz .line_in_screen_map_top
 mov esi,[RO16x16M_BMapAddress+RO16x16M_Inner+12]
.line_in_screen_map_top:

 ; al contains real Y offset for next tile
 shl eax,2          ; Get screen offset
 push ecx
 mov ecx,0x1F0*4    ; Current line + V scroll * 32words
 and ecx,eax
 and eax,byte 0x0F*4    ; Offset into table of line offsets
 mov edx,16*8+7
 mov eax,[Tile_Offset_Table_16_8+eax]
 sub edx,eax
 add esi,ecx
 pop ecx
 jmp short .have_v_offset

.LeftEdge:
 push esi
 push ebx
 push ebp

 mov ebp,[RO16x16M_FirstTile+RO16x16M_Inner+12]

.No_VChange:
 mov eax,[LineAddress]
 mov esi,[RO16x16M_MapAddress_Current+RO16x16M_Inner+12]
 mov edx,[LineAddressY]

.have_v_offset:
 add ebp,ebx
 mov [RO16x16M_LineAddressOffset+RO16x16M_Inner+12],eax
 mov ebx,ebp
 and ebp,byte 63    ; X offset wrap
 and ebx,byte 64
 mov [RO16x16M_LineAddressOffsetY+RO16x16M_Inner+12],edx
 mov ebx,[RO16x16M_RMapDifference+RO16x16M_Inner+12]
 jz  .tile_in_screen_map_left
 add esi,ebx
.tile_in_screen_map_left:
 mov ebx,ebp
 and ebp,byte ~1

 mov al,[esi+ebp+1] ; Combine X and Y offsets into tile map
 Check_Tile_Priority %2, near %1_check

 mov si,[esi+ebp]   ; Get tile #
 mov ebp,[RO16x16M_LineAddressOffsetY+RO16x16M_Inner+12]
 test al,al         ; Check Y flip
 js .flip_y
 mov ebp,[RO16x16M_LineAddressOffset+RO16x16M_Inner+12]

.flip_y:
 shl esi,3
 add esi,ebp

 add al,al      ; Get X flip (now in MSB)
 mov ebp,[TilesetAddress]
 mov eax,[Mosaic_Size]
 js near %%xflip

 lea esi,[esi+ebx*8]
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,ebp
 and esi,0xFFFF / 8 ; Clip to VRAM

 pop ebp
 lea esi,[C_LABEL(TileCache8)+esi*8]

%%flip_none_same_tile:
 cmp ecx,eax
 ja %%flip_none_partial
 mov eax,ecx
%%flip_none_partial:
 mov dl,[esi+ebp]
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
%undef PLM16x16_Dest_Offset
 inc edi
 dec eax
 jnz %%flip_none_next_pixel

 mov eax,[Mosaic_Size]
 test ecx,ecx
 jz %%flip_none_return

 cmp ebp,byte 8
 jb %%flip_none_same_tile

 pop ebx
 pop esi
 jmp %%next_tile

ALIGNC
%%flip_none_empty_run:
 add edi,eax
 add ebp,eax
 sub ecx,eax
 jz %%flip_none_return

 cmp ebp,byte 8
 jb %%flip_none_same_tile

 pop ebx
 pop esi
 jmp %%next_tile

%%flip_none_return:
 pop ebx
 pop esi
 ret

ALIGNC
%%xflip:
 shl ebx,3
 add esi,byte 8
 sub esi,ebx
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,ebp
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM

 pop ebp
 lea esi,[C_LABEL(TileCache8)+esi*8+8]
 xor ebp,byte -1
%%flip_x_same_tile:
 cmp ecx,eax
 ja %%flip_x_partial
 mov eax,ecx
%%flip_x_partial:
 mov dl,[esi+ebp]
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
%undef PLM16x16_Dest_Offset
 inc edi
 dec eax
 jnz %%flip_x_next_pixel

 mov eax,[Mosaic_Size]
 test ecx,ecx
 jz %%flip_x_return

 cmp ebp,byte ~8
 ja %%flip_x_same_tile

 pop ebx
 pop esi
 xor ebp,byte -1
 jmp %%next_tile

ALIGNC
%%flip_x_empty_run:
 add edi,eax
 sub ebp,eax
 sub ecx,eax
 jz %%flip_x_return

 cmp ebp,byte ~8
 ja %%flip_x_same_tile

 pop ebx
 pop esi
 xor ebp,byte -1
 jmp %%next_tile

%%flip_x_return:
 pop ebx
 pop esi
 ret
%endmacro

;%1 = depth, %2 = count
%macro Generate_Line_Plotters_Offset_16x16M 2
%ifndef NO_NP_RENDER
 Plot_Lines_Offset_16x16M_C%1 Plot_Lines_%2_NP_Offset_16x16M_C%1,0,%2
%endif
 Plot_Lines_Offset_16x16M_C%1 Plot_Lines_%2_V_Offset_16x16M_C%1,3,%2
%endmacro

%macro Generate_Line_Plotters_Offset_16x16M_Depth 1
Generate_Line_Plotters_Offset_16x16M %1,1
Generate_Line_Plotters_Offset_16x16M %1,2
Generate_Line_Plotters_Offset_16x16M %1,3
Generate_Line_Plotters_Offset_16x16M %1,4
Generate_Line_Plotters_Offset_16x16M %1,5
Generate_Line_Plotters_Offset_16x16M %1,6
Generate_Line_Plotters_Offset_16x16M %1,7
Generate_Line_Plotters_Offset_16x16M %1,8
%endmacro

Generate_Line_Plotters_Offset_16x16M_Depth 2
Generate_Line_Plotters_Offset_16x16M_Depth 4
Generate_Line_Plotters_Offset_16x16M_Depth 8

section .data
%macro Generate_Line_Plotter_Offsets_16x16M 3
dd C_LABEL(Plot_Lines_%3_%1_Offset_16x16M_C%2).LeftEdge
dd C_LABEL(Plot_Lines_%3_%1_Offset_16x16M_C%2)
%endmacro

;%1 = type, %2 = depth
%macro Generate_Line_Plotter_Table_Offset_16x16M 2
ALIGND
EXPORT_C Plot_Lines_%1_Offset_16x16M_Table_C%2
%assign GLPTO_16x16M_Count 1
%rep RO16x16M_MAX_LINE_COUNT
Generate_Line_Plotter_Offsets_16x16M %1,%2,GLPTO_16x16M_Count
%assign GLPTO_16x16M_Count GLPTO_16x16M_Count+1
%endrep
%undef GLPTO_16x16M_Count
%endmacro

%ifndef NO_NP_RENDER
Generate_Line_Plotter_Table_Offset_16x16M NP,2
Generate_Line_Plotter_Table_Offset_16x16M NP,4
Generate_Line_Plotter_Table_Offset_16x16M NP,8
%endif

Generate_Line_Plotter_Table_Offset_16x16M V,2
Generate_Line_Plotter_Table_Offset_16x16M V,4
Generate_Line_Plotter_Table_Offset_16x16M V,8

section .text
