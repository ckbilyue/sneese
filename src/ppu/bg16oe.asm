%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

%define SNEeSe_ppu_bg16oe_asm

%include "misc.inc"
%include "ppu/ppu.inc"
%include "ppu/tiles.inc"
%include "ppu/screen.inc"


%define RO16E_Local_Bytes 56+24
%define RO16E_Plotter_Table esp+52+24
%define RO16E_Clipped esp+48+24
%define RO16E_BG_Table esp+44+24
%define RO16E_Current_Line esp+40+24
%define RO16E_BaseDestPtr esp+36+24
%define RO16E_Lines esp+32+24

; contains bit for determining planes to affect
%define RO16E_OC_Flag esp+28+24

; Same as LineAddress(Y), additional vars for offset change code
%define RO16E_LineAddressOffset  esp+24+24
%define RO16E_LineAddressOffsetY esp+20+24

%define RO16E_FirstTile esp+16+24

; Scroll-adjusted tile map address for offset
;  change code when tile offset not changed
%define RO16E_MapAddress_Current esp+12+24

%define RO16E_TMapAddress esp+8+24
%define RO16E_BMapAddress esp+4+24
%define RO16E_RMapDifference esp+24

%define RO16E_Runs_Left esp+20
%define RO16E_Output esp+16
%define RO16E_RunListPtr esp+12
%define RO16ER_VMapOffset esp+8
;VMapOffset can be eliminated by merging its value with VL/VRMapAddress?

%define RO16ER_Plotter_Table RO16E_Plotter_Table
%define RO16ER_BG_Table RO16E_BG_Table
%define RO16ER_Next_Pixel esp+4
%define RO16ER_Pixel_Count esp
%define RO16ER_Inner (4)
%define RO16E_Inner (8)

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
void Render_Offset_16_Even_Run
(BGTABLE *bgtable, UINT8 *output, int vmapoffset, int nextpixel,
 int numpixels,
 void (**plotter_table)(UINT16 *offset_screen_address, int tile_offset,
  UINT8 tilecount, UINT8 *output))
)
{
 UINT16 *offset_screen_address;
 int tile_offset = (nextpixel + (bgtable->hscroll & 7)) / 8;

 output += nextpixel;

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

  plotter_table[(tile_offset ? 1 : 0](offset_screen_address, tile_offset,
   1, output);

  if (numpixels <= 0) return;

  if (tile_offset) offset_screen_address ++;
  tile_offset ++;
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
    plotter_table[(tile_offset ? 1 : 0](offset_screen_address, tile_offset,
     1, output);
    return;
   }
  }
  else
  {
   runlength = 0x100 - nextpixel;
  }

  plotter_table[(tile_offset ? 1 : 0](offset_screen_address, tile_offset,
   runlength / 8, output);
  numpixels -= runlength;
  if (!numpixels) return;

  offset_screen_address += runlength / 8;
  tile_offset += runlength / 8;
  output += runlength;
  nextpixel += runlength;

  if (nextpixel < 0x100)
  {
   TileClip1Left &=
    *(UINT32 *)(ClipRightTable - numpixels);
   TileClip1Right &=
    *(UINT32 *)(ClipRightTable - numpixels + 4);
   plotter_table[1](offset_screen_address, tile_offset,
    1, output);
   return;
  }
 }

 screen_address = (UINT16 *) (bgtable->vrmapaddress + vmapoffset);
 if (numpixels >= 8)
 {
  plotter_table[1](offset_screen_address, tile_offset,
   numpixels / 8, output);
  if (!(numpixels & 7)) return;
  screen_address += numpixels / 8;
  tile_offset += numpixels / 8;
  output += numpixels & ~7;
 }

 TileClip1Left &=
  *(UINT32 *)(ClipRightTable - (numpixels & 7));
 TileClip1Right &=
  *(UINT32 *)(ClipRightTable - (numpixels & 7) + 4);
 plotter_table[1](offset_screen_address, tile_offset,
  1, output);
}
%endif
ALIGNC
Render_Offset_16_Even_Run:
 mov ecx,[HScroll_3]

 mov eax,[RO16ER_Next_Pixel+RO16ER_Inner]
 mov ebx,[HScroll+edx]
 and ecx,0xF8
 and ebx,byte 7
 add edi,eax    ;first pixel
 add ebx,eax
 add ecx,ebx

 mov eax,[VLMapAddressBG3]
 mov edx,[RO16ER_VMapOffset+RO16ER_Inner]
 cmp ecx,0x108
 jb .do_before_wrap
 sub ecx,0x100
 mov eax,[VRMapAddressBG3]
.do_before_wrap:

 shr ebx,3
 mov ebp,ecx
 add eax,edx

 shr ebp,3      ;(nextpixel / 8)
 add ebx,byte -1

 ;hscroll + first pixel, relative to screen of first tile to be plotted
 sbb edx,edx
 sub ecx,byte 8
 inc ebx
 mov [RO16ER_Next_Pixel+RO16ER_Inner],ecx
 add ebx,ebx
 and edx,byte 2
 lea esi,[eax+ebp*2]

 sub esi,edx
 add edx,edx
 and ecx,byte 7
 jz .do_unclipped_before_wrap

 sub edi,ecx
 sub ecx,byte 8

 sub [RO16ER_Next_Pixel+RO16ER_Inner],ecx   ;nextpixel += 8 - (nextpixel & 7)
 add [RO16ER_Pixel_Count+RO16ER_Inner],ecx  ;count -= 8 - (nextpixel & 7)
 xor ecx,byte 7

 mov eax,[ClipLeftTable+ecx+1]      ;ClipLeftTable[-(nextpixel & 7)]
 mov [TileClip1Left],eax
 mov eax,[ClipLeftTable+ecx+1+4]
 mov [TileClip1Right],eax
 sub ecx,[RO16ER_Pixel_Count+RO16ER_Inner]

 cmp dword [RO16ER_Pixel_Count+RO16ER_Inner],0
 jl .clippedboth
 jz .last_tile

 mov cl,1
 mov eax,[RO16ER_Plotter_Table+RO16ER_Inner]
 ; ch contains bit for determining planes to affect
 mov ch,[RO16E_OC_Flag+RO16ER_Inner]
 call [eax+edx]

 mov edx,4

.do_unclipped_before_wrap:
 mov eax,-1
 mov ecx,0x100
 mov ebp,[RO16ER_Next_Pixel+RO16ER_Inner]
 mov [TileClip1Left],eax
 sub ecx,ebp
 mov [TileClip1Right],eax
 jz .do_unclipped_after_wrap

 mov eax,[RO16ER_Pixel_Count+RO16ER_Inner]
 cmp ecx,eax
 jbe .goodcountunclippedleft
 mov ecx,eax
 and ecx,byte ~7
 jz .clipped_last_before_wrap
.goodcountunclippedleft:

 sub eax,ecx    ;count -= pixels in unclipped tiles in left run
 add [RO16ER_Next_Pixel+RO16ER_Inner],ecx   ;nextpixel += 8 - (nextpixel & 7)
 shr ecx,3

 test eax,eax
 jz .last_run
 mov [RO16ER_Pixel_Count+RO16ER_Inner],eax

 mov eax,[RO16ER_Plotter_Table+RO16ER_Inner]
 ; ch contains bit for determining planes to affect
 mov ch,[RO16E_OC_Flag+RO16ER_Inner]
 call [eax+edx]

 mov ebp,[RO16ER_Next_Pixel+RO16ER_Inner]
 cmp ebp,0x100
 jae .do_unclipped_after_wrap

.clipped_last_before_wrap:
 mov ecx,[RO16ER_Pixel_Count+RO16ER_Inner]
 jmp .do_clipped_last_tile

.do_unclipped_after_wrap:
 mov eax,[RO16ER_Pixel_Count+RO16ER_Inner]
 mov esi,[RO16ER_VMapOffset+RO16ER_Inner]
 mov ecx,eax
 mov ebp,[VRMapAddressBG3]
 add esi,ebp
 shr eax,3
 jz .do_clipped_last_tile

 mov edx,4
 test ecx,7
 mov ecx,eax
 jz .last_run

 mov eax,[RO16ER_Plotter_Table+RO16ER_Inner]
 ; ch contains bit for determining planes to affect
 mov ch,[RO16E_OC_Flag+RO16ER_Inner]
 call [eax+edx]

 mov ecx,[RO16ER_Pixel_Count+RO16ER_Inner]

.do_clipped_last_tile:
 and ecx,byte 7
 mov edx,4
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
 mov eax,[RO16ER_Plotter_Table+RO16ER_Inner]
 ; ch contains bit for determining planes to affect
 mov ch,[RO16E_OC_Flag+RO16ER_Inner]
 call [eax+edx]

 ret

; -Tile on left edge of screen not affected by V-offset change
; -Offset change map is scrollable - always 8x8

;depth, tile height
%macro Render_Offset_16_Even 2
ALIGNC
EXPORT_C Render_Offset_16x%2_Even_C%1
%ifndef NO_OFFSET_CHANGE
%ifndef NO_OFFSET_CHANGE_DISABLE
 cmp byte [C_LABEL(Offset_Change_Disable)],0    ; Hack to disable offset change
 jnz near C_LABEL(Render_16x%2_Even_C%1)
%endif  ; !NO_OFFSET_CHANGE_DISABLE
%else   ; NO_OFFSET_CHANGE
 jmp C_LABEL(Render_16x%2_Even_C%1)
%endif  ; NO_OFFSET_CHANGE

%ifdef OFFSET_CHANGE_ELIMINATION
 ;mode 6: 4-plane tiles, split offset table
 mov cl,[OffsetChangeDetect3]
 test cl,[OC_Flag+edx]
 jz near C_LABEL(Render_16x%2_Even_C%1)
%endif

 cmp byte [Mosaic+edx],0
 jnz near C_LABEL(Render_Offset_16x%2M_Even_C%1)

%ifndef NO_NP_RENDER
 mov ecx,C_LABEL(Plot_Lines_NP_Offset_16x%2_Even_Table_C%1)
 test al,al
 jnz .have_plotter
%endif

 mov ecx,C_LABEL(Plot_Lines_V_Offset_16x%2_Even_Table_C%1)
.have_plotter:

 push ecx
 push esi
 push edx ;BG_Table
 push ebx ;Current_Line
 push edi ;BaseDestPtr
 push ebp ;Lines
 sub esp,byte RO16E_Local_Bytes-24

 ; ch contains bit for determining planes to affect
 mov ch,[OC_Flag+edx]
 mov eax,[SetAddress+edx]
 mov [RO16E_OC_Flag],ch
 mov [TilesetAddress],eax

.next_line:
 mov edx,[RO16E_BG_Table]

 mov eax,[RO16E_Current_Line]
 call Sort_Screen_Height

 mov eax,[RO16E_Current_Line]
 SORT_TILES_%2_TALL [RO16E_MapAddress_Current]

 ; Corrupts eax,ecx,ebp
 mov eax,[TLMapAddress+edx]
 mov ecx,[RO16E_Current_Line]
 mov edi,[BLMapAddress+edx]
 mov ebp,[VScroll+edx]
 mov [RO16E_TMapAddress],eax
 add ecx,ebp
 mov [RO16E_BMapAddress],edi
 mov ebp,[RO16E_MapAddress_Current]

 and ch,(%2) / 8
;global Tile_Height
;Tile_Height equ $-1    ; 1 = 8x8, 16x8, 2 = 16x16
 jz .current_line_in_screen_map_top
 mov eax,edi
.current_line_in_screen_map_top:
 add eax,ebp

 mov ebp,[HScroll+edx]
 mov [RO16E_MapAddress_Current],eax
 shr ebp,3
 mov eax,[TRMapAddress+edx]
 add ebp,ebp
 mov ecx,[TLMapAddress+edx]
 mov [RO16E_FirstTile],ebp  ;FirstTile = (HScroll / 8) * 2

 sub eax,ecx
 mov [RO16E_RMapDifference],eax

 mov eax,[C_LABEL(SNES_Screen8)]
 mov edi,[RO16E_BaseDestPtr]
 add edi,eax

 mov esi,[RO16E_Clipped]
 mov al,[Win_Count+edx+esi]

 test al,al
 jz .done

 mov ebx,[OffsetChangeMap_VOffset]
 mov [RO16E_Runs_Left],eax
 lea edx,[Win_Bands+edx+esi]

 mov [RO16E_Output],edi
 mov [RO16E_RunListPtr],edx
 mov [RO16ER_VMapOffset],ebx    ;vertical screen map address
 xor ebx,ebx
 mov bl,[edx]

 xor ecx,ecx
 mov cl,[edx+1]
 mov edx,[RO16E_BG_Table]
 sub cl,bl
 setz ch

 mov [RO16ER_Next_Pixel],ebx
 mov [RO16ER_Pixel_Count],ecx

 dec al
 je .last_run

.not_last_run:
 mov [RO16E_Runs_Left],al
 call Render_Offset_16_Even_Run

 mov edx,[RO16E_RunListPtr]
 mov edi,[RO16E_Output]
 xor ebx,ebx
 xor ecx,ecx
 mov bl,[edx+2]

 mov cl,[edx+3]
 add edx,byte 2
 sub cl,bl
 mov [RO16E_RunListPtr],edx
 mov edx,[RO16E_BG_Table]

 mov [RO16ER_Next_Pixel],ebx
 mov [RO16ER_Pixel_Count],ecx

 mov al,[RO16E_Runs_Left]
 dec al
 jne .not_last_run
.last_run:
 call Render_Offset_16_Even_Run

.done:

%ifndef LAYERS_PER_LINE
 mov edi,[RO16E_BaseDestPtr]
 inc dword [RO16E_Current_Line]
 add edi,GfxBufferLinePitch
 dec dword [RO16E_Lines]
 mov [RO16E_BaseDestPtr],edi ; Point screen to next line
 jnz near .next_line
%endif

 mov edx,[RO16E_BG_Table]
 mov al,[Tile_Priority_Used]
 mov [Priority_Used+edx],al
 mov ah,[Tile_Priority_Unused]
 mov [Priority_Unused+edx],ah

 add esp,byte RO16E_Local_Bytes
 ret
%endmacro

Render_Offset_16_Even 4,8
Render_Offset_16_Even 4,16

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high, %3 = tile height
%macro Plot_Lines_Offset_16_Even_C4 3
%if %2 > 0
%%return:
 ret

ALIGNC
%1_check:
 pop ebx
 pop esi

%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Unused],cl
%endif
 add edi,byte 8
 dec cl
 jz %%return
%else
ALIGNC
%endif

EXPORT_C %1     ; Define label, entry point
.next_tile:
 lea eax,[esi+2]
 mov dh,[1+esi]     ; Horizontal offset change map
 push eax

 mov ebp,[RO16E_FirstTile+RO16E_Inner+4]
 mov eax,[OffsetChangeVMap_VOffset]
 test dh,ch         ; H-offset enabled?
 jz .have_h_offset
 mov dl,[esi]
 mov ebp,edx
 shr ebp,3
 add ebp,ebp
.have_h_offset:

 mov dh,[1+esi+eax] ; Vertical offset change map
 test dh,ch         ; V-offset enabled?
 jz .No_VChange
 mov dl,[esi+eax]
 mov eax,[RO16E_Current_Line+RO16E_Inner+4]
 add eax,edx

.calc_v_offset:
 and ah,(%3) / 8
 mov esi,[RO16E_TMapAddress+RO16E_Inner+4]
 jz .line_in_screen_map_top
 mov esi,[RO16E_BMapAddress+RO16E_Inner+4]
.line_in_screen_map_top:

 ; al contains real Y offset for next tile
 push ecx
%if %3 == 8
 mov ecx,0xF8
 mov edx,7
 and ecx,eax
 and eax,byte 7
 sub edx,eax
 lea esi,[esi+ecx*8]    ; Get screen offset
%else
 shl eax,2          ; Get screen offset
 mov ecx,0x1F0*4    ; Current line + V scroll * 32words
 and ecx,eax
 and eax,byte 0x0F*4    ; Offset into table of line offsets
 mov edx,16*8+7
 mov eax,[Tile_Offset_Table_16_8+eax]
 sub edx,eax
 add esi,ecx
%endif
 pop ecx
 jmp short .have_v_offset

.LeftEdge:
 push esi

 mov ebp,[RO16E_FirstTile+RO16E_Inner+4]

.No_VChange:
 mov eax,[LineAddress]
 mov esi,[RO16E_MapAddress_Current+RO16E_Inner+4]
 mov edx,[LineAddressY]

.have_v_offset:
 add ebp,ebx
 add ebx,byte 2     ; Update X offset
 mov [RO16E_LineAddressOffset+RO16E_Inner+4],eax
 push ebx
 mov ebx,ebp
 and ebp,byte 31*2  ; X offset wrap
 mov [RO16E_LineAddressOffsetY+RO16E_Inner+8],edx
 add esi,ebp        ; Combine X and Y offsets into tile map
 and ebx,byte 32*2
 mov ebx,[RO16E_RMapDifference+RO16E_Inner+8]
 jz  .tile_in_screen_map_left
 add esi,ebx
.tile_in_screen_map_left:

 mov al,[esi+1]
 Check_Tile_Priority %2, near %1_check

 mov ebp,[RO16E_LineAddressOffsetY+RO16E_Inner+8]
 test al,al         ; Check Y flip
 mov si,[esi]       ; Get tile #
 js .flip_y
 mov ebp,[RO16E_LineAddressOffset+RO16E_Inner+8]

.flip_y:
 shl esi,3
 mov edx,eax
 add esi,ebp
 and edx,byte 7*4   ; Get palette

 push esi
 mov ebp,[palette_4bpl+edx]
 mov edx,[TilesetAddress]

 add al,al      ; Get X flip (now in MSB)
 js near .xflip

 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM

 Plot_4_Even_Paletted_Lines_Clip_noflip 0,C_LABEL(TileCache4)+esi*8,0,TileClip1Left

 pop esi
 add esi,byte 8
 mov edx,[TilesetAddress]
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM
 Plot_4_Even_Paletted_Lines_Clip_noflip 0,C_LABEL(TileCache4)+esi*8,4,TileClip1Right

 pop ebx
 pop esi

 add edi,byte 8
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 dec cl
 jnz near .next_tile

 ret

ALIGNC
.xflip:
 add esi,byte 8

 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM

 Plot_4_Even_Paletted_Lines_Clip_Xflip 0,C_LABEL(TileCache4)+esi*8,0,TileClip1Left

 pop esi
 mov edx,[TilesetAddress]
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM
 Plot_4_Even_Paletted_Lines_Clip_Xflip 0,C_LABEL(TileCache4)+esi*8,4,TileClip1Right

 pop ebx
 pop esi

 add edi,byte 8
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 dec cl
 jnz near .next_tile

 ret
%endmacro

;%1 = depth, %2 = tile height
%macro Generate_Line_Plotters_Offset_16_Even 2
%ifndef NO_NP_RENDER
 Plot_Lines_Offset_16_Even_C%1 Plot_Lines_NP_Offset_16x%2_Even_C%1,0,%2
%endif
 Plot_Lines_Offset_16_Even_C%1 Plot_Lines_V_Offset_16x%2_Even_C%1,3,%2
%endmacro

Generate_Line_Plotters_Offset_16_Even 4,8
Generate_Line_Plotters_Offset_16_Even 4,16

section .data
%macro Generate_Line_Plotter_Table_Offset_16_Even 3
EXPORT_C Plot_Lines_%1_Offset_16x%3_Even_Table_C%2
dd C_LABEL(Plot_Lines_%1_Offset_16x%3_Even_C%2).LeftEdge
dd C_LABEL(Plot_Lines_%1_Offset_16x%3_Even_C%2)
%endmacro

%ifndef NO_NP_RENDER
Generate_Line_Plotter_Table_Offset_16_Even NP,4,8
Generate_Line_Plotter_Table_Offset_16_Even NP,4,16
%endif

Generate_Line_Plotter_Table_Offset_16_Even V,4,8
Generate_Line_Plotter_Table_Offset_16_Even V,4,16

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
