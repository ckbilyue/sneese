%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

%define SNEeSe_ppu_bg16o_asm

%include "misc.inc"
%include "ppu/ppu.inc"
%include "ppu/tiles.inc"
%include "ppu/screen.inc"


%define RO16x16_Local_Bytes 56+24
%define RO16x16_Plotter_Table esp+52+24
%define RO16x16_Clipped esp+48+24
%define RO16x16_BG_Table esp+44+24
%define RO16x16_Current_Line esp+40+24
%define RO16x16_BaseDestPtr esp+36+24
%define RO16x16_Lines esp+32+24

; contains bit for determining planes to affect
%define RO16x16_OC_Flag esp+28+24

; Same as LineAddress(Y), additional vars for offset change code
%define RO16x16_LineAddressOffset  esp+24+24
%define RO16x16_LineAddressOffsetY esp+20+24

%define RO16x16_FirstTile esp+16+24

; Scroll-adjusted tile map address for offset
;  change code when tile offset not changed
%define RO16x16_MapAddress_Current esp+12+24

%define RO16x16_TMapAddress esp+8+24
%define RO16x16_BMapAddress esp+4+24
%define RO16x16_RMapDifference esp+24

%define RO16x16_Runs_Left esp+20
%define RO16x16_Output esp+16
%define RO16x16_RunListPtr esp+12
%define RO16x16R_VMapOffset esp+8
;VMapOffset can be eliminated by merging its value with VL/VRMapAddress?

%define RO16x16R_Plotter_Table RO16x16_Plotter_Table
%define RO16x16R_BG_Table RO16x16_BG_Table
%define RO16x16R_Next_Pixel esp+4
%define RO16x16R_Pixel_Count esp
%define RO16x16R_Inner (4)
%define RO16x16_Inner (8)

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
void Render_Offset_16x16_Run
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
Render_Offset_16x16_Run:
 mov ecx,[HScroll_3]

 mov eax,[RO16x16R_Next_Pixel+RO16x16R_Inner]
 mov ebx,[HScroll+edx]
 and ecx,0xF8
 and ebx,byte 7
 add edi,eax    ;first pixel
 add ebx,eax
 add ecx,ebx

 mov eax,[VLMapAddressBG3]
 mov edx,[RO16x16R_VMapOffset+RO16x16R_Inner]
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
 mov [RO16x16R_Next_Pixel+RO16x16R_Inner],ecx
;add ebx,ebx
 and edx,byte 2
 lea esi,[eax+ebp*2]

 sub esi,edx
 add edx,edx
 and ecx,byte 7
 jz .do_unclipped_before_wrap

 sub edi,ecx
 sub ecx,byte 8

 sub [RO16x16R_Next_Pixel+RO16x16R_Inner],ecx   ;nextpixel += 8 - (nextpixel & 7)
 add [RO16x16R_Pixel_Count+RO16x16R_Inner],ecx  ;count -= 8 - (nextpixel & 7)
 xor ecx,byte 7

 mov eax,[ClipLeftTable+ecx+1]      ;ClipLeftTable[-(nextpixel & 7)]
 mov [TileClip1Left],eax
 mov eax,[ClipLeftTable+ecx+1+4]
 mov [TileClip1Right],eax
 sub ecx,[RO16x16R_Pixel_Count+RO16x16R_Inner]

 cmp dword [RO16x16R_Pixel_Count+RO16x16R_Inner],0
 jl .clippedboth
 jz .last_tile

 mov cl,1
 mov eax,[RO16x16R_Plotter_Table+RO16x16R_Inner]
 ; ch contains bit for determining planes to affect
 mov ch,[RO16x16_OC_Flag+RO16x16R_Inner]
 call [eax+edx]

 mov edx,4

.do_unclipped_before_wrap:
 mov eax,-1
 mov ecx,0x100
 mov ebp,[RO16x16R_Next_Pixel+RO16x16R_Inner]
 mov [TileClip1Left],eax
 sub ecx,ebp
 mov [TileClip1Right],eax
 jz .do_unclipped_after_wrap

 mov eax,[RO16x16R_Pixel_Count+RO16x16R_Inner]
 cmp ecx,eax
 jbe .goodcountunclippedleft
 mov ecx,eax
 and ecx,byte ~7
 jz .clipped_last_before_wrap
.goodcountunclippedleft:

 sub eax,ecx    ;count -= pixels in unclipped tiles in left run
 add [RO16x16R_Next_Pixel+RO16x16R_Inner],ecx   ;nextpixel += 8 - (nextpixel & 7)
 shr ecx,3

 test eax,eax
 jz .last_run
 mov [RO16x16R_Pixel_Count+RO16x16R_Inner],eax

 mov eax,[RO16x16R_Plotter_Table+RO16x16R_Inner]
 ; ch contains bit for determining planes to affect
 mov ch,[RO16x16_OC_Flag+RO16x16R_Inner]
 call [eax+edx]

 mov ebp,[RO16x16R_Next_Pixel+RO16x16R_Inner]
 cmp ebp,0x100
 jae .do_unclipped_after_wrap

.clipped_last_before_wrap:
 mov ecx,[RO16x16R_Pixel_Count+RO16x16R_Inner]
 jmp .do_clipped_last_tile

.do_unclipped_after_wrap:
 mov eax,[RO16x16R_Pixel_Count+RO16x16R_Inner]
 mov esi,[RO16x16R_VMapOffset+RO16x16R_Inner]
 mov ecx,eax
 mov ebp,[VRMapAddressBG3]
 add esi,ebp
 shr eax,3
 jz .do_clipped_last_tile

 mov edx,4
 test ecx,7
 mov ecx,eax
 jz .last_run

 mov eax,[RO16x16R_Plotter_Table+RO16x16R_Inner]
 ; ch contains bit for determining planes to affect
 mov ch,[RO16x16_OC_Flag+RO16x16R_Inner]
 call [eax+edx]

 mov ecx,[RO16x16R_Pixel_Count+RO16x16R_Inner]

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
 mov eax,[RO16x16R_Plotter_Table+RO16x16R_Inner]
 ; ch contains bit for determining planes to affect
 mov ch,[RO16x16_OC_Flag+RO16x16R_Inner]
 call [eax+edx]

 ret

; -Tile on left edge of screen not affected by V-offset change
; -Offset change map is scrollable - always 8x8

%macro Render_Offset_16x16 1
ALIGNC
EXPORT_C Render_Offset_16x16_C%1
%ifndef NO_OFFSET_CHANGE
%ifndef NO_OFFSET_CHANGE_DISABLE
 cmp byte [C_LABEL(Offset_Change_Disable)],0    ; Hack to disable offset change
 jnz near C_LABEL(Render_16x16_C%1)
%endif  ; !NO_OFFSET_CHANGE_DISABLE
%else   ; NO_OFFSET_CHANGE
 jmp C_LABEL(Render_16x16_C%1)
%endif  ; NO_OFFSET_CHANGE

%ifdef OFFSET_CHANGE_ELIMINATION
%if %1 == 4     ;mode 2: 4-plane tiles, split offset table
 mov cl,[OffsetChangeDetect3]
 test cl,[OC_Flag+edx]
 jz near C_LABEL(Render_16x16_C%1)
%else           ;mode 4: 2- and 8-plane tiles, unified offset table
 mov cl,[OffsetChangeDetect1]
 test cl,[OC_Flag+edx]
 jz near C_LABEL(Render_16x16_C%1)
%endif
%endif

 cmp byte [Mosaic+edx],0
 jnz near C_LABEL(Render_Offset_16x16M_C%1)

%ifndef NO_NP_RENDER
 mov ecx,C_LABEL(Plot_Lines_NP_Offset_16x16_Table_C%1)
 test al,al
 jnz .have_plotter
%endif

 mov ecx,C_LABEL(Plot_Lines_V_Offset_16x16_Table_C%1)
.have_plotter:

 jmp Render_Offset_16x16_Base
%endmacro

Render_Offset_16x16 2
Render_Offset_16x16 4
Render_Offset_16x16 8

ALIGNC
Render_Offset_16x16_Base:
 push ecx
 push esi
 push edx ;BG_Table
 push ebx ;Current_Line
 push edi ;BaseDestPtr
 push ebp ;Lines
 sub esp,byte RO16x16_Local_Bytes-24

 ; ch contains bit for determining planes to affect
 mov ch,[OC_Flag+edx]
 mov eax,[SetAddress+edx]
 mov [RO16x16_OC_Flag],ch
 mov [TilesetAddress],eax

.next_line:
 mov edx,[RO16x16_BG_Table]

 mov eax,[RO16x16_Current_Line]
 call Sort_Screen_Height

 mov eax,[RO16x16_Current_Line]
 SORT_TILES_16_TALL [RO16x16_MapAddress_Current]

 ; Corrupts eax,ecx,ebp
 mov eax,[TLMapAddress+edx]
 mov ecx,[RO16x16_Current_Line]
 mov edi,[BLMapAddress+edx]
 mov ebp,[VScroll+edx]
 mov [RO16x16_TMapAddress],eax
 add ecx,ebp
 mov [RO16x16_BMapAddress],edi
 mov ebp,[RO16x16_MapAddress_Current]

 and ch,2
;global Tile_Height
;Tile_Height equ $-1    ; 1 = 8x8, 16x8, 2 = 16x16
 jz .current_line_in_screen_map_top
 mov eax,edi
.current_line_in_screen_map_top:
 add eax,ebp

 mov ebp,[HScroll+edx]
 mov [RO16x16_MapAddress_Current],eax
 shr ebp,3
 mov eax,[TRMapAddress+edx]
 mov ecx,[TLMapAddress+edx]
 mov [RO16x16_FirstTile],ebp   ;FirstTile = (HScroll / 8) * 2

 sub eax,ecx
 mov [RO16x16_RMapDifference],eax

 mov eax,[C_LABEL(SNES_Screen8)]
 mov edi,[RO16x16_BaseDestPtr]
 add edi,eax

 mov esi,[RO16x16_Clipped]
 mov al,[Win_Count+edx+esi]

 test al,al
 jz .done

 mov ebx,[OffsetChangeMap_VOffset]
 mov [RO16x16_Runs_Left],eax
 lea edx,[Win_Bands+edx+esi]

 mov [RO16x16_Output],edi
 mov [RO16x16_RunListPtr],edx
 mov [RO16x16R_VMapOffset],ebx    ;vertical screen map address
 xor ebx,ebx
;mov [RO16x16R_Plotter_Table],ecx ;renderer
 mov bl,[edx]

 xor ecx,ecx
 mov cl,[edx+1]
 mov edx,[RO16x16_BG_Table]
 sub cl,bl
 setz ch

 mov [RO16x16R_Next_Pixel],ebx
 mov [RO16x16R_Pixel_Count],ecx

 dec al
 je .last_run

.not_last_run:
 mov [RO16x16_Runs_Left],al
 call Render_Offset_16x16_Run

 mov edx,[RO16x16_RunListPtr]
 mov edi,[RO16x16_Output]
 xor ebx,ebx
 xor ecx,ecx
 mov bl,[edx+2]

 mov cl,[edx+3]
 add edx,byte 2
 sub cl,bl
 mov [RO16x16_RunListPtr],edx
 mov edx,[RO16x16_BG_Table]

 mov [RO16x16R_Next_Pixel],ebx
 mov [RO16x16R_Pixel_Count],ecx

 mov al,[RO16x16_Runs_Left]
 dec al
 jne .not_last_run
.last_run:
 call Render_Offset_16x16_Run

.done:

%ifndef LAYERS_PER_LINE
 mov edi,[RO16x16_BaseDestPtr]
 inc dword [RO16x16_Current_Line]
 add edi,GfxBufferLinePitch
 dec dword [RO16x16_Lines]
 mov [RO16x16_BaseDestPtr],edi ; Point screen to next line
 jnz near .next_line
%endif

 mov edx,[RO16x16_BG_Table]
 mov al,[Tile_Priority_Used]
 mov [Priority_Used+edx],al
 mov ah,[Tile_Priority_Unused]
 mov [Priority_Unused+edx],ah

 add esp,byte RO16x16_Local_Bytes
 ret

;%define RO16x16_Inner 4

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high
%macro Plot_Lines_Offset_16x16_C4 2
%if %2 > 0
%%return:
 ret

ALIGNC
%1_check:
 pop ebx
 pop esi
 pop ecx

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
 push ecx
 mov dh,[1+esi]     ; Horizontal offset change map
 push eax

 mov ebp,[RO16x16_FirstTile+RO16x16_Inner+8]
 mov eax,[OffsetChangeVMap_VOffset]
 test dh,ch         ; H-offset enabled?
 jz .have_h_offset
 mov dl,[esi]
 mov ebp,edx
 shr ebp,3
.have_h_offset:

 mov dh,[1+esi+eax] ; Vertical offset change map
 test dh,ch         ; V-offset enabled?
 jz .No_VChange
 mov dl,[esi+eax]
 mov eax,[RO16x16_Current_Line+RO16x16_Inner+8]
 add eax,edx

.calc_v_offset:
 and ah,2
 mov esi,[RO16x16_TMapAddress+RO16x16_Inner+8]
 jz .line_in_screen_map_top
 mov esi,[RO16x16_BMapAddress+RO16x16_Inner+8]
.line_in_screen_map_top:

 ; al contains real Y offset for next tile
 shl eax,2          ; Get screen offset
 mov ecx,0x1F0*4    ; Current line + V scroll * 32words
 and ecx,eax
 and eax,byte 0x0F*4    ; Offset into table of line offsets
 mov edx,16*8+7
 mov eax,[Tile_Offset_Table_16_8+eax]
 sub edx,eax
 add esi,ecx
 jmp short .have_v_offset

.LeftEdge:
 push ecx
 push esi

 mov ebp,[RO16x16_FirstTile+RO16x16_Inner+8]

.No_VChange:
 mov eax,[LineAddress]
 mov esi,[RO16x16_MapAddress_Current+RO16x16_Inner+8]
 mov edx,[LineAddressY]

.have_v_offset:
 add ebp,ebx
 inc ebx            ; Update X offset
 mov [RO16x16_LineAddressOffset+RO16x16_Inner+8],eax
 push ebx
 mov ebx,ebp
 and ebp,byte 63    ; X offset wrap
 and ebx,byte 64
 mov [RO16x16_LineAddressOffsetY+RO16x16_Inner+12],edx
 mov ebx,[RO16x16_RMapDifference+RO16x16_Inner+12]
 jz  .tile_in_screen_map_left
 add esi,ebx
.tile_in_screen_map_left:
 mov ebx,ebp
 and ebp,byte ~1

 mov al,[esi+ebp+1] ; Combine X and Y offsets into tile map
 Check_Tile_Priority %2, near %1_check

 mov si,[esi+ebp]   ; Get tile #
 mov ebp,[RO16x16_LineAddressOffsetY+RO16x16_Inner+12]
 test al,al         ; Check Y flip
 js .flip_y
 mov ebp,[RO16x16_LineAddressOffset+RO16x16_Inner+12]

.flip_y:
 shl esi,3
 mov edx,eax
 add esi,ebp
 and edx,byte 7*4   ; Get palette
 and ebx,byte 1
 add al,al      ; Get X flip (now in MSB)
 mov ebp,[palette_4bpl+edx]
 mov edx,[TilesetAddress]
 js near .xflip

 lea esi,[esi+ebx*8]
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM

 Plot_8_Paletted_Lines_noflip 0,C_LABEL(TileCache4)+esi*8,0

 pop ebx
 pop esi
 pop ecx

 add edi,byte 8
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 dec cl
 jnz near .next_tile

 ret

ALIGNC
.xflip:
 shl ebx,3
 add esi,byte 8
 sub esi,ebx
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF * 2 / 8 ; Clip to VRAM

 Plot_8_Paletted_Lines_Xflip 0,C_LABEL(TileCache4)+esi*8,0

 pop ebx
 pop esi
 pop ecx

 add edi,byte 8
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 dec cl
 jnz near .next_tile

 ret
%endmacro

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high
%macro Plot_Lines_Offset_16x16_C2 2
%if %2 > 0
%%return:
 ret

ALIGNC
%1_check:
 pop ebx
 pop esi
 pop ecx

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
 mov eax,esi
 push ecx
 add eax,byte 2
 mov dh,[1+esi]     ; Offset change map
 push eax

 mov ebp,[RO16x16_FirstTile+RO16x16_Inner+8]
 mov eax,[RO16x16_Current_Line+RO16x16_Inner+8]
 test dh,ch         ; Offset enabled?
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
 mov esi,[RO16x16_TMapAddress+RO16x16_Inner+8]
 jz  .line_in_screen_map_top
 mov esi,[RO16x16_BMapAddress+RO16x16_Inner+8]
.line_in_screen_map_top:

 ; al contains real Y offset for next tile
 shl eax,2          ; Get screen offset
 mov ecx,0x1F0*4    ; Current line + V scroll * 32words
 and ecx,eax
 and eax,byte 0x0F*4    ; Offset into table of line offsets
 mov edx,16*8+7
 mov eax,[Tile_Offset_Table_16_8+eax]
 sub edx,eax
 add esi,ecx
 jmp short .have_v_offset

.LeftEdge:
 push ecx
 push esi

 mov ebp,[RO16x16_FirstTile+RO16x16_Inner+8]

.No_VChange:
 mov eax,[LineAddress]
 mov esi,[RO16x16_MapAddress_Current+RO16x16_Inner+8]
 mov edx,[LineAddressY]

.have_v_offset:
 add ebp,ebx
 inc ebx            ; Update X offset
 mov [RO16x16_LineAddressOffset+RO16x16_Inner+8],eax
 push ebx
 mov ebx,ebp
 and ebp,byte 63    ; X offset wrap
 and ebx,byte 64
 mov [RO16x16_LineAddressOffsetY+RO16x16_Inner+12],edx
 mov ebx,[RO16x16_RMapDifference+RO16x16_Inner+12]
 jz  .tile_in_screen_map_left
 add esi,ebx
.tile_in_screen_map_left:
 mov ebx,ebp
 and ebp,byte ~1

 mov al,[esi+ebp+1] ; Combine X and Y offsets into tile map
 Check_Tile_Priority %2, near %1_check

 mov si,[esi+ebp]   ; Get tile #
 mov ebp,[RO16x16_LineAddressOffsetY+RO16x16_Inner+12]
 test al,al         ; Check Y flip
 js .flip_y
 mov ebp,[RO16x16_LineAddressOffset+RO16x16_Inner+12]

.flip_y:
 shl esi,3
 mov edx,eax
 add esi,ebp
 and edx,byte 7*4   ; Get palette
 and ebx,byte 1
 add al,al      ; Get X flip (now in MSB)
 mov ebp,[palette_2bpl+edx]
 mov edx,[TilesetAddress]
 js near .xflip

 lea esi,[esi+ebx*8]
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF * 4 / 8 ; Clip to VRAM

 Plot_8_Paletted_Lines_noflip 0,C_LABEL(TileCache2)+esi*8,0

 pop ebx
 pop esi
 pop ecx

 add edi,byte 8
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 dec cl
 jnz near .next_tile

 ret

ALIGNC
.xflip:
 shl ebx,3
 add esi,byte 8
 sub esi,ebx
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF * 4 / 8 ; Clip to VRAM

 Plot_8_Paletted_Lines_Xflip 0,C_LABEL(TileCache2)+esi*8,0

 pop ebx
 pop esi
 pop ecx

 add edi,byte 8
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 dec cl
 jnz near .next_tile

 ret
%endmacro

;%1 = label, %2 = priority - 0 = none, 1 = low, 2 = high
%macro Plot_Lines_Offset_16x16_C8 2
%if %2 > 0
%%return:
 ret

ALIGNC
%1_check:
 pop ebx
 pop esi
 pop ecx

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
 mov eax,esi
 push ecx
 add eax,byte 2
 mov dh,[1+esi]     ; Offset change map
 push eax

 mov ebp,[RO16x16_FirstTile+RO16x16_Inner+8]
 mov eax,[RO16x16_Current_Line+RO16x16_Inner+8]
 test dh,ch         ; Offset enabled?
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
 mov esi,[RO16x16_TMapAddress+RO16x16_Inner+8]
 jz  .line_in_screen_map_top
 mov esi,[RO16x16_BMapAddress+RO16x16_Inner+8]
.line_in_screen_map_top:

 ; al contains real Y offset for next tile
 shl eax,2          ; Get screen offset
 mov ecx,0x1F0*4    ; Current line + V scroll * 32words
 and ecx,eax
 and eax,byte 0x0F*4    ; Offset into table of line offsets
 mov edx,16*8+7
 mov eax,[Tile_Offset_Table_16_8+eax]
 sub edx,eax
 add esi,ecx
 jmp short .have_v_offset

.LeftEdge:
 push ecx
 push esi

 mov ebp,[RO16x16_FirstTile+RO16x16_Inner+8]

.No_VChange:
 mov eax,[LineAddress]
 mov esi,[RO16x16_MapAddress_Current+RO16x16_Inner+8]
 mov edx,[LineAddressY]

.have_v_offset:
 add ebp,ebx
 inc ebx            ; Update X offset
 mov [RO16x16_LineAddressOffset+RO16x16_Inner+8],eax
 push ebx
 mov ebx,ebp
 and ebp,byte 63    ; X offset wrap
 and ebx,byte 64
 mov [RO16x16_LineAddressOffsetY+RO16x16_Inner+12],edx
 mov ebx,[RO16x16_RMapDifference+RO16x16_Inner+12]
 jz  .tile_in_screen_map_left
 add esi,ebx
.tile_in_screen_map_left:
 mov ebx,ebp
 and ebp,byte ~1

 mov al,[esi+ebp+1] ; Combine X and Y offsets into tile map
 Check_Tile_Priority %2, near %1_check

 mov si,[esi+ebp]   ; Get tile #
 mov ebp,[RO16x16_LineAddressOffsetY+RO16x16_Inner+12]
 test al,al         ; Check Y flip
 js .flip_y
 mov ebp,[RO16x16_LineAddressOffset+RO16x16_Inner+12]

.flip_y:
 shl esi,3
 add esi,ebp
 and ebx,byte 1
 add al,al      ; Get X flip (now in MSB)
 mov edx,[TilesetAddress]
 js near .xflip

 lea esi,[esi+ebx*8]
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF / 8 ; Clip to VRAM

 Plot_8_Lines_noflip 0,C_LABEL(TileCache8)+esi*8,0

 pop ebx
 pop esi
 pop ecx

 add edi,byte 8
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 dec cl
 jnz near .next_tile

 ret

ALIGNC
.xflip:
 shl ebx,3
 add esi,byte 8
 sub esi,ebx
 and esi,0x3FF * 8 + 7  ; Clip to tileset
 add esi,edx
 and esi,0xFFFF / 8 ; Clip to VRAM

 Plot_8_Lines_Xflip 0,C_LABEL(TileCache8)+esi*8,0

 pop ebx
 pop esi
 pop ecx

 add edi,byte 8
%if %2 == 1 || %2 == 3
 mov [Tile_Priority_Used],cl
%endif
 dec cl
 jnz near .next_tile

 ret
%endmacro

;%1 = depth
%macro Generate_Line_Plotters_Offset_16x16 1
%ifndef NO_NP_RENDER
 Plot_Lines_Offset_16x16_C%1 Plot_Lines_NP_Offset_16x16_C%1,0
%endif
 Plot_Lines_Offset_16x16_C%1 Plot_Lines_V_Offset_16x16_C%1,3
%endmacro

Generate_Line_Plotters_Offset_16x16 4
Generate_Line_Plotters_Offset_16x16 2
Generate_Line_Plotters_Offset_16x16 8

section .data
%macro Generate_Line_Plotter_Table_Offset_16x16 2
EXPORT_C Plot_Lines_%1_Offset_16x16_Table_C%2
dd C_LABEL(Plot_Lines_%1_Offset_16x16_C%2).LeftEdge
dd C_LABEL(Plot_Lines_%1_Offset_16x16_C%2)
%endmacro

%ifndef NO_NP_RENDER
Generate_Line_Plotter_Table_Offset_16x16 NP,4
Generate_Line_Plotter_Table_Offset_16x16 NP,2
Generate_Line_Plotter_Table_Offset_16x16 NP,8
%endif

Generate_Line_Plotter_Table_Offset_16x16 V,4
Generate_Line_Plotter_Table_Offset_16x16 V,2
Generate_Line_Plotter_Table_Offset_16x16 V,8

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
