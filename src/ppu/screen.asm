%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

; screen.asm
; Screen rendering code
; -BGMODE specific handlers, including specialized handlers for:
;   offset change in Modes 2, 4, and 6;
; -Basic BG scanline renderers;
; -Line offset in tile tables.
;

;%define MSR_PROFILING
%define NO_PLOTTER_PER_PRIORITY
%define WATCH_RENDER_BREAKS
;%define LAYERS_PER_LINE
;%define NO_NP_RENDER
;%define NO_OFFSET_CHANGE
;%define NO_OFFSET_CHANGE_DISABLE
;%define NO_EARLY_PRIORITY_ELIMINATION
;%define OFFSET_CHANGE_ELIMINATION

%ifdef NO_NP_RENDER
%define NO_EARLY_PRIORITY_ELIMINATION
%endif

%ifndef LAYERS_PER_LINE
%define NO_EARLY_PRIORITY_ELIMINATION
%endif

%define SNEeSe_ppu_screen_asm

%include "misc.inc"
%include "clear.inc"
%include "ppu/sprites.inc"
%include "ppu/ppu.inc"
%include "ppu/tiles.inc"
%include "ppu/screen.inc"

EXTERN_C SCREEN_MODE_7
EXTERN_C SNES_Screen8
EXTERN_C Offset_Change_Disable

EXTERN_C MosaicLine,MosaicCount

EXTERN_C use_mmx,use_fpu_copies,preload_cache,preload_cache_2

section .text
EXPORT_C screen_text_start
section .data
EXPORT_C screen_data_start
section .bss
EXPORT_C screen_bss_start

section .data
ALIGND
%macro Generate_Tile_Offset_Table 1
 dd 16*8*(%1)
 dd 16*8*(%1)+1
 dd 16*8*(%1)+2
 dd 16*8*(%1)+3
 dd 16*8*(%1)+4
 dd 16*8*(%1)+5
 dd 16*8*(%1)+6
 dd 16*8*(%1)+7
%endmacro

EXPORT Tile_Offset_Table_16_8
Generate_Tile_Offset_Table 0
Generate_Tile_Offset_Table 1

EXPORT Screen_Mode
 dd C_LABEL(SCREEN_MODE_0)
 dd C_LABEL(SCREEN_MODE_1)
 dd C_LABEL(SCREEN_MODE_2)
 dd C_LABEL(SCREEN_MODE_3)
 dd C_LABEL(SCREEN_MODE_4)
 dd C_LABEL(SCREEN_MODE_5)
 dd C_LABEL(SCREEN_MODE_6)
 dd C_LABEL(SCREEN_MODE_7)

palette_2bpl:
 dd 0x03030303, 0x07070707, 0x0B0B0B0B, 0x0F0F0F0F
 dd 0x13131313, 0x17171717, 0x1B1B1B1B, 0x1F1F1F1F
palette_4bpl:
 dd 0x0F0F0F0F, 0x1F1F1F1F, 0x2F2F2F2F, 0x3F3F3F3F
 dd 0x4F4F4F4F, 0x5F5F5F5F, 0x6F6F6F6F, 0x7F7F7F7F

palette_2bpl_mmx:
 dd 0x03030303, 0x03030303, 0x07070707, 0x07070707
 dd 0x0B0B0B0B, 0x0B0B0B0B, 0x0F0F0F0F, 0x0F0F0F0F
 dd 0x13131313, 0x13131313, 0x17171717, 0x17171717
 dd 0x1B1B1B1B, 0x1B1B1B1B, 0x1F1F1F1F, 0x1F1F1F1F
palette_4bpl_mmx:
 dd 0x0F0F0F0F, 0x0F0F0F0F, 0x1F1F1F1F, 0x1F1F1F1F
 dd 0x2F2F2F2F, 0x2F2F2F2F, 0x3F3F3F3F, 0x3F3F3F3F
 dd 0x4F4F4F4F, 0x4F4F4F4F, 0x5F5F5F5F, 0x5F5F5F5F
 dd 0x6F6F6F6F, 0x6F6F6F6F, 0x7F7F7F7F, 0x7F7F7F7F

ClipTableStart:
 db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
 db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
ClipLeftTable: ;ClipLeftTable[-first_pixel_offset]
 db 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF
 db 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF
ClipRightTable: ;ClipRightTable[-pixel_count]
 db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
 db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
;to clip both: ClipLeftTable[-first_pixel_offset] &
; ClipRightTable[-(first_pixel_offset + pixel_count)]

section .bss
;Z-buffer for display

;#L = tiles/pixels for layer # (low priority)
;#H = tiles/pixels for layer # (high priority)
;#S = sprites (# priority) 34 24 14 04
;BA = back area 00
;L7 = mode-7 EXTBG low priority 1
;N7 = mode-7 EXTBG low priority 2, mode-7 w/o EXTBG
;H7 = mode-7 EXTBG high priority

;modes 0-1
;layer 3H 3S 1H 2H 2S 1L 2L 1S 3H 4H 0S 3L 4L BA
;Z     38 34 32 31 24 22 21 14 12 11 04 02 01 00

;modes 2-6
;layer 3S 1H 2S 2H 1S 1L 0S 2L BA
;Z     34 32 24 22 14 12 04 02 00

;mode 7
;layer 3S 2S H7 1S N7 0S L7 BA
;Z     34 24 22 14 12 04 02 00

ALIGNB
EXPORT DisplayZ,skipb (8+256+8)
ALIGNB
EXPORT_C Current_Line_Render,skipl
EXPORT_C Last_Frame_Line,skipl
EXPORT Ready_Line_Render,skipl
EXPORT BaseDestPtr      ,skipl

EXPORT Render_Select,skipl  ; Base renderer
EXPORT Render_Mode  ,skipl  ; Mode renderer

BGLineCount:skipl
TileClip1:
TileClip1Left:skipl
TileClip1Right:skipl
TileClip2:
TileClip2Left:skipl
TileClip2Right:skipl

EXPORT LineAddress ,skipl   ; Address of tileset, + offset to line in tile
EXPORT LineAddressY,skipl   ; Same, for vertical flip
EXPORT TileMask    ,skipl   ; Tile address mask, for tileset wrap
Palette_Base:skipl

; Used for offset change map addressing
EXPORT OffsetChangeMap_VOffset,skipl    ; BG3VOFS + BG3SC
EXPORT OffsetChangeVMap_VOffset,skipl   ; BG3VOFS + BG3SC (for split-table)

EXPORT Display_Needs_Update,skipb
EXPORT Tile_Layers_Enabled,skipb
EXPORT Tile_priority_bit,skipb
Tile_Priority_Used:skipb
Tile_Priority_Unused:skipb

EXPORT OffsetChangeDetect1,skipb
EXPORT OffsetChangeDetect2,skipb
EXPORT OffsetChangeDetect3,skipb
EXPORT Redo_Layering,skipb
EXPORT Redo_Windowing,skipb

;YXCS 4321
;1-4 update clip window for BG 1-4
;S   update clip window for OBJ (sprites)
;C   update color window
;X   update window 1 area
;Y   update window 2 area


section .text
;ebx = first line, edi = destination base ptr, ebp = # lines
ALIGNC
EXPORT_C Render_Layering_Option_0   ; main-on-sub
 mov al,[SCR_TS]    ; Get BG status for sub screens
 mov ah,[SCR_TM]    ; Get BG status for main screens
 jmp dword [Render_Mode]

ALIGNC
EXPORT_C Render_Layering_Option_1   ; sub-on-main
 mov al,[SCR_TM]    ; Get BG status for main screens
 mov ah,[SCR_TS]    ; Get BG status for sub screens
 jmp dword [Render_Mode]

ALIGNC
EXPORT_C Render_Layering_Option_2   ; main-with-sub
 mov al,[SCR_TM]    ; Get BG status for main/sub screens
 mov ah,0
 jmp dword [Render_Mode]

ALIGNC
Update_Offset_Change:
 mov byte [Redo_Offset_Change],0

 mov al,[Redo_Offset_Change_VOffsets]
 LOAD_BG_TABLE 3
 test al,al
 jz .no_recalc_voffsets

 mov byte [Redo_Offset_Change_VOffsets],0

;OffsetChangeMap_VOffset = ((BG3VOFS / 8) & 0x1F) * 64 +
; (BG3VOFS & 0x100 ? BLMapAddressBG3 - TLMapAddressBG3 : 0);
;OffsetChangeVMap_VOffset = ((BG3VOFS / 8 + 1) & 0x1F) * 64 +
; ((BG3VOFS + 8) & 0x100 ? BLMapAddressBG3 - TLMapAddressBG3 : 0) -
; OffsetChangeMap_VOffset;
 mov edi,[VScroll+edx]
 shl edi,3          ; divided by 8 (base tile size),
 mov ebx,[VScroll+edx]
 and edi,(0x1F << 6)    ; * 2 (16-bit words) * 32 (row)

 and bh,1
 jz .offset_line_in_map_top

 mov ebx,[BLMapAddress+edx]
 add edi,ebx
 mov ebx,[TLMapAddress+edx]
 sub edi,ebx
.offset_line_in_map_top:

 mov [OffsetChangeMap_VOffset],edi

 mov ebx,[VScroll+edx]
 add edi,byte 32*2      ; next row
 add ebx,byte 8
 and edi,(0x1F << 6)    ; * 2 (16-bit words) * 32 (row)

 and bh,1
 jz .vmap_offset_line_in_map_top

 mov ebx,[BLMapAddress+edx]
 add edi,ebx
 mov ebx,[TLMapAddress+edx]
 sub edi,ebx
.vmap_offset_line_in_map_top:

 mov ebx,[OffsetChangeMap_VOffset]
 sub edi,ebx
 mov [OffsetChangeVMap_VOffset],edi

.no_recalc_voffsets:

 ; Update BG3 position for offset change
 LOAD_BG_TABLE 3

 mov ecx,[HScroll+edx]

 mov esi,TLMapAddress
 mov edi,TRMapAddress
 and ch,1   ;8x8 tile size
 jz .first_tile_in_left_screen_map
 add esi,byte (TRMapAddress-TLMapAddress)
 add edi,byte (TLMapAddress-TRMapAddress)
.first_tile_in_left_screen_map:

 mov esi,[esi+edx]
 mov edi,[edi+edx]
 mov [VLMapAddress+edx],esi
 mov [VRMapAddress+edx],edi

%ifdef OFFSET_CHANGE_ELIMINATION
 xor eax,eax
 mov ebx,[OffsetChangeMap_VOffset]
 mov al,[HScroll + edx]
 mov cl,32
 shr eax,3
 add esi,ebx
 sub cl,al
 lea esi,[esi+eax*2]

 mov edx,[OffsetChangeVMap_VOffset]
 add edi,ebx

 mov ah,0
 mov bl,0

.detect_loop:
 mov ch,[esi+1]

 or ah,ch
 mov bh,[esi+1+edx]

 add esi,byte 2
 or bl,bh

 dec cl
 jnz .detect_loop

 add cl,al
 jz .detect_end

 mov al,0
 mov esi,edi
 jmp short .detect_loop

.detect_end:
 mov [OffsetChangeDetect1],ah
 or ah,bl
 mov [OffsetChangeDetect2],bl
 mov [OffsetChangeDetect3],ah
%endif

 ret

%macro SORT_OFFSET_CHANGE 0
 test byte [Tile_Layers_Enabled],3  ;BG1 || BG2
 jz %%no_recalc

 mov al,[BGMODE_Allowed_Offset_Change]
 test al,al
 jz %%no_recalc

 mov al,[Redo_Offset_Change]
 test al,al
 jz %%no_recalc

 call Update_Offset_Change

%%no_recalc:
%endmacro

ALIGNC
EXPORT_C Clear_Scanlines
;edi = dest address, ebp = line count
 mov al,[C_LABEL(use_fpu_copies)]
 test al,al
 jnz .clear_fpu

 mov al,[C_LABEL(use_mmx)]
 test al,al
 jnz .clear_mmx

 xor eax,eax

 mov ecx,256/4
 push es
 mov edx,ds
 mov es,edx
 cld

 cmp byte [C_LABEL(preload_cache)],0
 jnz near C_LABEL(Clear_Scanlines_Preload).clear_loop

.clear_loop:
 rep stosd

 add edi,byte GfxBufferLineSlack    ; Point screen to next line
 dec ebp
 mov ecx,256/4
 jnz .clear_loop

 pop es
 ret

ALIGNC
.clear_fpu:
 fldz
 mov ecx,256/16

.clear_fpu_loop:
 fst qword [edi+0]
 fst qword [edi+8]
 add edi,byte 16
 dec ecx
 jnz .clear_fpu_loop

 add edi,byte GfxBufferLineSlack    ; Point screen to next line
 dec ebp
 mov ecx,256/16
 jnz .clear_fpu_loop

 fstp st0
 ret

ALIGNC
.clear_mmx:
 pxor mm0,mm0
 mov ecx,256/16

.clear_mmx_loop:
 movq [edi+0],mm0
 movq [edi+8],mm0
 add edi,byte 16
 dec ecx
 jnz .clear_mmx_loop

 add edi,byte GfxBufferLineSlack    ; Point screen to next line
 dec ebp
 mov ecx,256/16
 jnz .clear_mmx_loop

 emms
 ret

ALIGNC
EXPORT_C Clear_Scanlines_Preload
;edi = dest address, ebp = line count
 cmp byte [C_LABEL(preload_cache_2)],0
 jz near C_LABEL(Clear_Scanlines)

 mov al,[C_LABEL(use_fpu_copies)]
 test al,al
 jnz .clear_fpu

 mov al,[C_LABEL(use_mmx)]
 test al,al
 jnz near .clear_mmx

 xor eax,eax

 mov ecx,256/4
 push es
 mov edx,ds
 mov es,edx
 cld

.clear_loop:
 ; Load area to clear into cache
 mov bl,[edi+0]
 mov bl,[edi+32*1]
 mov bl,[edi+32*2]
 mov bl,[edi+32*3]
 mov bl,[edi+32*4]
 mov bl,[edi+32*5]
 mov bl,[edi+32*6]
 mov bl,[edi+32*7]
 mov bl,[edi+16]
 mov bl,[edi+16*3]
 mov bl,[edi+16*5]
 mov bl,[edi+16*7]
 mov bl,[edi+16*9]
 mov bl,[edi+16*11]
 mov bl,[edi+16*13]
 mov bl,[edi+16*15]

 rep stosd

 add edi,byte GfxBufferLineSlack    ; Point screen to next line
 dec ebp
 mov ecx,256/4
 jnz .clear_loop

 pop es
 ret

ALIGNC
.clear_fpu:
 fldz
 mov ecx,256/16

.clear_fpu_next_line:
 ; Load area to clear into cache
 mov bl,[edi+0]
 mov bl,[edi+32*1]
 mov bl,[edi+32*2]
 mov bl,[edi+32*3]
 mov bl,[edi+32*4]
 mov bl,[edi+32*5]
 mov bl,[edi+32*6]
 mov bl,[edi+32*7]

.clear_fpu_loop:
 fst qword [edi+0]
 fst qword [edi+8]
 add edi,byte 16
 dec ecx
 jnz .clear_fpu_loop

 add edi,byte GfxBufferLineSlack    ; Point screen to next line
 dec ebp
 mov ecx,256/16
 jnz .clear_fpu_next_line

 fstp st0
 ret

ALIGNC
.clear_mmx:
 pxor mm0,mm0
 mov ecx,256/16

.clear_mmx_next_line:
 ; Load area to clear into cache
 mov bl,[edi+0]
 mov bl,[edi+32*1]
 mov bl,[edi+32*2]
 mov bl,[edi+32*3]
 mov bl,[edi+32*4]
 mov bl,[edi+32*5]
 mov bl,[edi+32*6]
 mov bl,[edi+32*7]

.clear_mmx_loop:
 movq [edi+0],mm0
 movq [edi+8],mm0
 add edi,byte 16
 dec ecx
 jnz .clear_mmx_next_line

 add edi,byte GfxBufferLineSlack    ; Point screen to next line
 dec ebp
 mov ecx,256/16
 jnz .clear_mmx_loop

 emms
 ret

ALIGNC
EXPORT_C Update_Display
 ; edx = number of lines to recache
 mov edx,[Ready_Line_Render]
 push eax
 sub edx,[C_LABEL(Current_Line_Render)]
 mov ah,[C_LABEL(INIDISP)]
 mov [Display_Needs_Update],dh
 test ah,ah         ; Check for screen off
 js near .screen_off
 push ebx
 push ecx
 push edi
 push ebp
 push esi
 push edx

 xor eax,eax
 mov [Priority_Used_BG1],ax
 mov [Priority_Used_BG2],ax
 mov [Priority_Used_BG3],ax
 mov [Priority_Used_BG4],ax

%ifdef WATCH_RENDER_BREAKS
EXTERN_C BreaksLast
 inc dword [C_LABEL(BreaksLast)]
%endif

extern BGMODE_Tile_Layer_Mask
 mov al,[SCR_TM]
 mov bl,[BGMODE_Tile_Layer_Mask]
 or al,[SCR_TS]
 and al,bl
 mov [Tile_Layers_Enabled],al
 jz near .no_tile_layers

extern Tile_Recache_Set_End,Tile_Recache_Set_Begin,Recache_Tile_Set
 mov edi,[Tile_Recache_Set_End]
 inc edi
 js .no_tile_recache_needed ; No set to recache?
 sub edi,[Tile_Recache_Set_Begin]
 mov byte [Redo_Offset_Change],0xFF
 call Recache_Tile_Set
 mov edi,-2
 mov [Tile_Recache_Set_Begin],edi
 mov [Tile_Recache_Set_End],edi
.no_tile_recache_needed:

 test byte [Tile_Layers_Enabled],0x10
 jz .no_oam_recache_needed
 mov al,[Redo_OAM]
 test al,al
 jz .no_oam_recache_needed
 call C_LABEL(Recache_OAM)
.no_oam_recache_needed:

 SORT_OFFSET_CHANGE

.no_tile_layers:

 cmp byte [Redo_Layering],0
 jz .no_layering_recalc_needed
 call C_LABEL(Update_Layering)
.no_layering_recalc_needed:

 cmp byte [Redo_Windowing],0
 jz .no_window_recalc_needed
 call C_LABEL(Recalc_Window_Effects)
.no_window_recalc_needed:

 mov ebx,[C_LABEL(Current_Line_Render)]
 mov edi,[BaseDestPtr]
 inc ebx
 mov ebp,[esp]

 call dword [Render_Select]

 pop edx
 pop esi
 pop ebp
 pop edi
 pop ecx
 pop ebx
 add [C_LABEL(Current_Line_Render)],edx

 mov eax,GfxBufferLinePitch
 imul eax,edx
 add [BaseDestPtr],eax
 pop eax
.return:
 ret

ALIGNC
.screen_off:
 push ebx
 push ecx
 push edi
 push ebp
 push esi
 push edx

 mov ebp,edx
 mov edi,[C_LABEL(SNES_Screen8)]    ; (256+16)*(239+1) framebuffer
 mov ebx,[BaseDestPtr]
 add edi,ebx

 ; Clear the framebuffer
 call C_LABEL(Clear_Scanlines)

 pop edx
 pop esi
 pop ebp
 pop edi
 pop ecx
 pop ebx
 add [C_LABEL(Current_Line_Render)],edx

 mov eax,GfxBufferLinePitch
 imul eax,edx
 add [BaseDestPtr],eax
 pop eax
 ret

;al = left edge, cl = right edge + 1
ALIGNC
EXPORT_C Recalc_Window_Bands
 test cl,cl         ; 0 = 255 (right edge)
 jz .one_inside
 cmp cl,al
 jbe .full_outside  ; if (Right < Left) full range outside window;
.one_inside:
 mov [Win_Bands_In+edx],al
 test al,al

 mov byte [Win_Count_In+edx],1  ; One band inside window (left,right)
 mov [Win_Bands_In+edx+1],cl
 jnz .not_flush_left    ; if (!Left) window flush left;
 test cl,cl
 jnz .flush_one_side    ; if (!Left && Right == 255) full range inside;
 ; Full range inside window
 mov byte [Win_Count_Out+edx],0     ; No bands outside window
 jmp short .done
.not_flush_left:
 ; Window not flush left (1 inside, 1 or 2 outside)
 test cl,cl
 je .flush_one_side     ; if (Left && Right == 255) window flush right;
 ; Window not flush left or right (1 inside, 2 outside)
 ; Inside range is (left,right)
 ; Outside range 1 is (0,left-1)
 ; Outside range 2 is (right+1,255)
;dec eax                ; Right outside edge 1 = Left inside edge - 1
;inc edx                ; Left outside edge 2 = right inside edge + 1
 mov byte [Win_Count_Out+edx],2 ; One band outside window (right+1,left-1)
 mov [Win_Bands_Out+edx+1],al
 mov byte [Win_Bands_Out+edx],0
 mov [Win_Bands_Out+edx+2],cl
 mov byte [Win_Bands_Out+edx+3],0
 jmp short .done
.flush_one_side:
 ; Window flush left, not flush right (1 inside, 1 outside)
 ; Window flush right, not flush left (1 inside, 1 outside)
 ; Inside range is (left,right), outside range is (right+1,left-1)
;dec eax                 ; Right outside edge = Left inside edge - 1
;inc edx                 ; Left outside edge = right inside edge + 1
 mov [Win_Bands_Out+edx+1],al
 mov byte [Win_Count_Out+edx],1 ; One band outside window (right+1,left-1)
 mov [Win_Bands_Out+edx],cl
 jmp short .done
.full_outside:
 ; Full range outside window (0 inside, 1 outside)
 mov byte [Win_Count_Out+edx],1     ; One band outside window
 mov dword [Win_Bands_Out+edx],0    ; Full range band
 mov byte [Win_Count_In+edx],0  ; No bands inside window
.done:
 ret

;%1 = Left,%2 = Right,%3 = Window table
%macro Recalc_Single_Window 3
 LOAD_WIN_TABLE %3
 mov al,[%1]
 mov cl,[%2]
 call C_LABEL(Recalc_Window_Bands)
%endmacro

%macro Recalc_Window_BG_Main 1
 mov al,[SCR_TM]
 LOAD_BG_TABLE %1,edi
 mov cl,[SCR_TMW]
 mov esi,BG_Win_Main
 and al,cl
 call C_LABEL(Recalc_Window_Area_BG)
%endmacro

%macro Recalc_Window_BG_Sub 1
 mov al,[SCR_TS]
 LOAD_BG_TABLE %1,edi
 mov cl,[SCR_TSW]
 mov esi,BG_Win_Sub
 and al,cl
 call C_LABEL(Recalc_Window_Area_BG)
%endmacro

ALIGNC
EXPORT_C Recalc_Window_Area_BG

 test al,[BG_Flag+edi]
 jz .no_clip

 mov ax,[WSEL+edi]  ;WSEL, WLOG
 test al,8+2
 jz .no_clip

 jpe .intersect

 add edi,esi

 LOAD_WIN_TABLE 2
 test al,2
 jz .single_window_clip_2
 LOAD_WIN_TABLE 1
 shl al,2
.single_window_clip_2:
 
 ; we want drawn areas, not window areas, so we need the inverted results...
 test al,4
 jz .draw_outside
 add edx,byte Win_In - Win_Out
.draw_outside:

 mov al,[Win_Count+edx]
 mov [edi+Win_Count],al
 test al,al
 jz .no_runs

.next_run:
 mov cx,[edx+Win_Bands]
 add edx,byte 2
 mov [edi+Win_Bands],cx
 add edi,byte 2
 dec al
 jnz .next_run

.no_runs:
 ret

.no_clip:
 mov byte [edi+esi+Win_Count],1
 mov byte [edi+esi+Win_Bands+0],0
 mov byte [edi+esi+Win_Bands+1],0
 ret

; Method of generation depends on logic mode.
;  OR logic uses AND on the bands outside the window area to compute
; the areas to be drawn.  No seperate bands can end up adjacent to each
; other, so coalesence is unnecessary.
;  AND logic uses OR on the bands outside the window area to compute
; the areas to be drawn, logic code handles coalescence of adjacent
; bands.
;  XOR and XNOR logic use a sorted set of window edges, with duplicate
; edges discarded.


 ;logic - 00 = or; 01 = and; 10 = xor; 11 = xnor
 ; we want drawn areas, not window areas, so we need the inverted results...
 ; or   = and of outside
 ; and  = or of outside
 ; xor  = xor of inside 1, outside 2
 ; xnor = xor of outside both

 ; edi = BG table
 ; esi = screen offset in BG table
.intersect:
 and ah,3
 cmp ah,1
 je .intersect_and_setup
 ja .intersect_xor_check

;each intersect setup code chains to an intersect handler
;each intersect handler expects the following register state:
; edx = address of window 1 bands
; esi = address of window 2 bands
; cl = count of window 1 bands
; ch = count of window 2 bands
; ebp = 0
; edi = address for output window area (BG_WIN_DATA)

;for OR window logic, we use AND of inverted (outside) areas
.intersect_or_setup:
 add edi,esi

 LOAD_WIN_TABLE 1
 LOAD_WIN_TABLE 2,esi
 xor ebp,ebp

 ; we want drawn areas, not window areas, so we need the inverted results...
 test al,1
 jz .or_draw_outside_1
 add edx,byte Win_In - Win_Out
.or_draw_outside_1:

 test al,4
 jz .or_draw_outside_2
 add esi,byte Win_In - Win_Out
.or_draw_outside_2:

.intersect_and_entry:
 mov cl,[Win_Count+edx]
 test cl,cl
 jz .and_no_more_bands

 mov ch,[Win_Count+esi]
 test ch,ch
 jz .and_no_more_bands

.and_win1_loop:
 push ecx
 mov ax,[edx+Win_Bands]
 dec ah
 push esi

.and_win2_loop:
 mov bx,[esi+Win_Bands]
 dec bh

 cmp al,bh      ;win1left, win2right
 ja .and_no_intersect

 cmp bl,ah      ;win2left, win1right
 ja .and_no_more_intersect

 cmp bl,al
 ja .and_max_left
 mov bl,al
.and_max_left:

 mov [edi+ebp*2+Win_Bands],bl

 cmp bh,ah
 jb .and_min_right
 mov bh,ah
.and_min_right:

 inc bh
 mov [edi+ebp*2+Win_Bands+1],bh
 inc ebp

 add esi,byte 2
 dec ch
 jnz .and_win2_loop

.and_no_more_intersect:
 pop esi
 pop ecx

 add edx,byte 2
 dec cl
 jnz .and_win1_loop

.and_no_more_bands:
 mov eax,ebp
 mov [edi+Win_Count],al
 ret

.and_no_intersect:
 add esi,byte 2
 dec ch
 mov [esp],esi
 mov [esp+4],ecx
 jnz .and_win2_loop
 add esp,byte 8
 jmp .and_no_more_bands


;for AND window logic, we use OR of inverted (outside) areas
.intersect_and_setup:
 add edi,esi

 LOAD_WIN_TABLE 1
 LOAD_WIN_TABLE 2,esi
 xor ebp,ebp

 ; we want drawn areas, not window areas, so we need the inverted results...
 test al,1
 jz .and_draw_outside_1
 add edx,byte Win_In - Win_Out
.and_draw_outside_1:

 test al,4
 jz .and_draw_outside_2
 add esi,byte Win_In - Win_Out
.and_draw_outside_2:

.intersect_or_entry:
 mov cl,[Win_Count+edx]
 test cl,cl
 jz .or_copy_win2

 mov ch,[Win_Count+esi]
 test ch,ch
 jz .or_copy_win1

.or_win1_loop:
 ; start with leftmost window bands
 mov al,[edx+Win_Bands]
 mov bl,[esi+Win_Bands]
 cmp al,bl
 jbe .or_no_swap
 rol cx,8
 mov ebx,edx
 mov edx,esi
 mov esi,ebx
.or_no_swap:

 mov ax,[edx+Win_Bands]

.or_win2_loop:
 mov bx,[esi+Win_Bands]

 ; compare left edges against right edges
 test bh,bh
 jz .or_win2right_edge

 cmp al,bh      ;win1left, win2right
 ja .or_no_intersect

.or_win2right_edge:
 test ah,ah
 jz .or_win1right_edge

 cmp bl,ah      ;win2left, win1right
 ja .or_no_intersect

.or_win1right_edge:
 cmp al,bl
 jb .or_min_left
 mov al,bl
.or_min_left:

 dec ah
 dec bh
 cmp ah,bh
 ja .or_max_right
 mov ah,bh
.or_max_right:
 inc ah

 add esi,byte 2
 dec ch
 jnz .or_win2_loop

.or_no_intersect:
 dec cl
 jz .or_last_band

 mov bx,[edx+Win_Bands+2]
 add edx,byte 2

 ; compare left edges against right edges

 test bh,bh
 jz .or_win2right_edge2

 cmp al,bh      ;win1left, win2right
 ja .or_no_intersect2

.or_win2right_edge2:
 test ah,ah
 jz .or_win1right_edge2

 cmp bl,ah      ;win2left, win1right
 ja .or_no_intersect2

.or_win1right_edge2:
 cmp al,bl
 jb .or_min_left2
 mov al,bl
.or_min_left2:

 dec ah
 dec bh
 cmp ah,bh
 ja .or_max_right2
 mov ah,bh
.or_max_right2:
 inc ah

 test ch,ch
 jnz .or_win2_loop
 jmp .or_no_intersect

.or_swap_windows:
 rol cx,8
 mov ebx,edx
 mov edx,esi
 mov esi,ebx
 mov bx,[edx+Win_Bands]
 dec bh

.or_no_intersect2:
 mov [edi+ebp*2+Win_Bands],al
 mov [edi+ebp*2+Win_Bands+1],ah
 inc ebp

 test ch,ch
 jnz .or_win1_loop
 mov ax,bx
 jmp .or_no_intersect

.or_last_band:
 test ch,ch
 jnz .or_swap_windows

 mov [edi+ebp*2+Win_Bands],ax
 inc ebp

 mov eax,ebp
 mov [edi+Win_Count],al
.or_done:
 ret

.or_copy_win2:
 mov cl,ch
 mov edx,esi
.or_copy_win1:
 mov [edi+Win_Count],cl
 dec cl
 js .or_done
.or_copy_another:
 mov ax,[edx+ebp*2+Win_Bands]
 mov [edi+ebp*2+Win_Bands],ax
 inc ebp
 dec cl
 jns .or_copy_another
 ret


;if we're doing xor, we flip the inversion of one of the windows
.intersect_xor_check:
 ;fixup for xor/xnor
 and ah,1
 xor al,ah

.intersect_xor_setup:
 add edi,esi

 LOAD_WIN_TABLE 1
 LOAD_WIN_TABLE 2,esi

 ; we want drawn areas, not window areas, so we need the inverted results...
 test al,1
 jnz .xor_draw_outside_1
 add edx,byte Win_In - Win_Out
.xor_draw_outside_1:

 test al,4
 jz .xor_draw_outside_2
 add esi,byte Win_In - Win_Out
.xor_draw_outside_2:

.intersect_xor_entry:
EXTERN_C xor_bands
 mov cl,[Win_Count+edx]
 mov ch,[Win_Count+esi]

%if Win_Bands
 add edx,Win_Bands
 add esi,Win_Bands
%endif

 push edi
 xor eax,eax
 add edi,byte Win_Bands
 mov al,ch
 and ecx,byte 0x7F
 push edi
 push eax
 push ecx
 push esi
 push edx
 call C_LABEL(xor_bands)
 mov edi,[esp+20]
 add esp,byte 24
 mov [edi+Win_Count],al
 ret

EXPORT_EQU_C Intersect_Window_Area_AND,C_LABEL(Recalc_Window_Area_BG).intersect_and_entry
EXPORT_EQU_C Intersect_Window_Area_OR,C_LABEL(Recalc_Window_Area_BG).intersect_or_entry
EXPORT_EQU_C Intersect_Window_Area_XOR,C_LABEL(Recalc_Window_Area_BG).intersect_xor_entry

ALIGNC
EXPORT_C Recalc_Window_Effects
 push eax
 push ecx
 push edx
 push ebx
 push ebp
 push esi
 push edi

 test byte [Redo_Windowing],Redo_Win(1)
 jz .win1_ok

 Recalc_Single_Window C_LABEL(WH0), C_LABEL(WH1), 1

.win1_ok:
 test byte [Redo_Windowing],Redo_Win(2)
 jz .win2_ok

 Recalc_Single_Window C_LABEL(WH2), C_LABEL(WH3), 2

.win2_ok:


 mov al,[Redo_Windowing]
 and al,[Layers_In_Use]

 push eax
 test al,Redo_Win_BG(1)
 jz .bg1_ok

 Recalc_Window_BG_Main 1
 Recalc_Window_BG_Sub 1
.bg1_ok:


 mov al,[esp]
 test al,Redo_Win_BG(2)
 jz .bg2_ok

 Recalc_Window_BG_Main 2
 Recalc_Window_BG_Sub 2
.bg2_ok:


 mov al,[esp]
 test al,Redo_Win_BG(3)
 jz .bg3_ok

 Recalc_Window_BG_Main 3
 Recalc_Window_BG_Sub 3
.bg3_ok:


 mov al,[esp]
 test al,Redo_Win_BG(4)
 jz .bg4_ok

 Recalc_Window_BG_Main 4
 Recalc_Window_BG_Sub 4
.bg4_ok:


 mov al,[Layers_In_Use]
 xor al,0xFF
 and al,[Redo_Windowing]
 and al,~(Redo_Win(1) | Redo_Win(2))
 mov [Redo_Windowing],al

 pop eax

 pop edi
 pop esi
 pop ebp
 pop ebx
 pop edx
 pop ecx
 pop eax
 ret

; max output bands is 1 more than max input bands; only in case where
;neither outermost band edges are at screen edge
EXPORT_C Invert_Window_Bands
;esi = base address for input bands; first byte is count
;edi = base address for output bands; first byte is count
;edx = count of bands output (count up)
;ecx = count of bands input (count down)

 xor ecx,ecx
 xor edx,edx ;current output
 mov cl,[esi]
 test ecx,ecx
 jnz .no_bands

 xor eax,eax
 mov ah,[esi+1]
 test ah,ah
 jz .no_left_edge_band
 mov [edi+1],eax        ;00 xx
 inc edx

.no_left_edge_band:
 dec ecx
 jz .last_band

.next_band:
 mov ax,[esi+2]
 mov [edi+edx*2+1],ax
 add esi,2
 inc edx
 dec ecx
 jnz .next_band

.last_band:
 mov cl,[esi+2]
 test cl,cl
 jz .no_more_bands
 mov [edi+edx*2+1],cx   ;xx 00
 inc edx
.no_more_bands:
 mov [edi],dl
 ret

.no_bands:
 mov dword [edi],1      ;01 00 00 - 1 band, full area
 ret

; windows:
%if 0
 There are 5 basic window types for purposes of calculating
  intersections:

  1) full area (no invert: left = 0, right = 255; invert: left > right);
  2) no area (no invert: left > right; invert: left = 0, right = 255);
  3) flush to left side (no invert: left = 0, right < 255;
   invert: left > 0, right = 255);
  4) flush to right side (no invert: left > 0, right = 255;
   invert: left = 0, right < 255);
  5) flush to neither side (no invert: left > 0, right < 255);
  6) two runs, flush to either side (invert: left > 0, right < 255).

 Intersections can produce the following in addition:
  7) two runs: one flush to left side, one flush to neither side;
  8) two runs: one flush to right side, one flush to neither side;
  9) two runs, flush to neither side;
  10) three runs: two flush to either side, one in center.

 Types 1 and 2 are the easiest to intersect.
  1) result of OR is full area;
   result of AND is other window;
   result of XOR is other window inverted;
   result of XNOR is other window.
  2) result of OR is other window;
   result of AND is no area;
   result of XOR is other window;
   result of XNOR is other window inverted.

TMW/TSW clipping is only done inside window areas defined by
 WH0-WH1 (window 1) and WH2-WH3 (window 2), when enabled
 (W12SEL/W34SEL/WOBJSEL odd bits).

Window areas can be inverted (W12SEL/W34SEL/WOBJSEL even bits).

When specified areas of windows 1/2 overlap, final window area is determined
 by specified logic (WBGLOG/WOBJLOG).

Color arithmetic is done inside the area of the color window.

w2  w1
 /\/\  /--+ enable
 ||||  |/-+ invert window area
 76543210
 \  /\  /
 BG2 BG1 - ($2123) W12SEL
 BG4 BG3 - ($2124) W34SEL
 COL OBJ - ($2125) WOBJSEL

 COL = Color window - related to CGWSEL ($2130)

WH0-WH1 Left and right position for window 1
WH2-WH3 Left and right position for window 2
 if (left > right) no window range

       /+-+ logic - 00 = or; 01 = and; 10 = xor; 11 = xnor
       ||
 76543210
 \/||||\/
BG4||||BG1 ($212A: WBGLOG)
   \/\/OBJ ($212B: WOBJLOG)
 BG3  BG2 ($212A: WBGLOG)
      COL ($212B: WOBJLOG)
 bits 4-7 are ignored in $212B: WOBJLOG

 bits 5-7 are ignored in $212C-212F (TM, TS, TMW, TSW)
 76543210
 xxx||||\-+ BG1
    |||\--+ BG2
    ||\---+ BG3
    |\----+ BG4
    \-----+ OBJ
 ($212C) TM specifies layers to be used as main screen
 ($212D) TS specifics layers to be used as sub screen, for screen arithmetic
 ($212E) TMW is mask to be inverted and applied with bitwise AND to TM
  inside window areas
 ($212F) TSW is mask to be inverted and applied with bitwise AND to TS
  inside window areas

 $2130 - CGWSEL
 76543210
 ||||xx|\-+ 1 = enable direct color mode (for BGMODEs 3,4,7)
 ||||  \--+ 0 = arithmetic with fixed color; 1 = arithmetic with screen
 ||\+-----+ sub screen normal display select \ 00 = on; 01 = on inside
 \+-------+ main screen normal display select/ 10 = on outside; 11 = off

 $2131 - CGADSUB

 76543210
 |||||||\-+ enable color arithmetic for BG1
 ||||||\--+ enable color arithmetic for BG2
 |||||\---+ enable color arithmetic for BG3
 ||||\----+ enable color arithmetic for BG4
 |||\-----+ enable color arithmetic for OBJ
 ||\------+ enable color arithmetic for back area
 |\-------+ 1 = halve-result of arithmetic (except for back area)
 \--------+ 0 = color addition; 1 = color subtraction
%endif

;Variable priority loads dh from Tile_priority_bit
;All assume al == high byte of screen tile
;%1 = priority - 0 = none, 1 = low, 2 = high, 3 = variable
;%2 = branch label
%macro Check_Tile_Priority 2
%if %1 == 1
 test al,0x20
 jnz %2
%endif

%if %1 == 2
 test al,0x20
 jz %2
%endif

%if %1 == 3
 mov dh,[Tile_priority_bit]
 xor dh,al
 and dh,0x20        ; Check tile priority
 jz %2
%endif
%endmacro

; esi is screen address, works cos we only plot until wraparound!
; ch contains the X counter
; cl contains the screen addition for palette offsetting (2bpl only)
; edi is the address to draw to..
; LineAddress contains the location for the SNES tile data
; LineAddress(Y) must be offset to the correct line for that row
; LineAddressY is used for Y-flip

%include "ppu/bg8.inc"
%include "ppu/bg16.inc"

%if 0
 Mode 2 is a special snes mode - It is known as offset change mode,
  basically the snes has the ability to change the horizontal and/or
  vertical offset of each column on the screen, a pig to emulate but
  here is the information:

  BG1 & BG2 are 16 colour planes (this much was simple to find out)
  BG3 - This does not exist but its address in VRAM is very important!

  What happens is the horizontal and verticle information is written to
  BG2 address's BG2+0 -  BG2+63, this gives 128 bytes (since VRAM is a
  word addressed system). BG2+0 -  BG2+31 is the address for changing
  the horizontal value BG2+32 - BG2+63 is the address for changing the
  vertical value

  There are 32 values per BG mode since there are 32 tiles horizontally across the screen! My
  best guess is this value is immune to scrolling (otherwise it would make more sense to
  give a 64 tile range in case of extra width modes).

  Ok, the only other thing you need to know is what do the values at address BG2+x do.

  Well its the same for horiz as vertical the values are encoded as :

  00           | 01          | 02           | 03          |.......| 62            | 63
  col 0 offset | col 0 flags | col 1 offset | col 1 flags |.......| col 31 offset | col 31 flags

  The flags as far as I can tell are :

   bit 7 6 5 4 3 2 1 0
       ? y x ? ? ? ? ?		where	y = affect bg1
    				x = affect bg0

    			The above information came from me Savoury SnaX

Addendum by TRAC (0.33 -> 0.34)
 BG modes 2/4/6 have offset change support.
 Offset change info is always stored at address set via BG3SC ($2109)?

 Offset change info is stored one word per (width 8) tile, which appears
  to have the format of:

  FEDCBA9786543210
  421xxxoooooooooo

  4 = reserved in modes 2/6 - vertical select in mode 4
  o = offset
  1 = enable for first layer
  2 = enable for second layer

 The (width 8) tile on the left edge of a layer cannot have its offset
  changed. It will always use standard H/V scroll.

 The offset change map is used for the remaining width of the screen.
  The maximum number of displayed tiles is 33, and the leftmost tile is
  excluded, hence there is data in the table for 32 tiles.

 There are one or two sets of data for the scanline. Each set is 32 words
  (one word per tile). In BG modes 2 and 6 there are two: one for
  horizontal, followed by one for vertical. In BG mode 4, there is one,
  shared between horizontal and vertical.

 Mode 4 stores only one word of offset change data per tile - bit 15
  of a word entry determines if it is used for changing horizontal or
  vertical offset (set for vertical).

 When offset change is enabled for a tile, it replaces the standard offset
  (BG#HOFS, BG#VOFS) value for that tile (horizontal offset replaces
  BG#HOFS, vertical offset + 1 replaces BG#VOFS).

 The BG3 scroll registers move the offset change map. The scrolling is
  limited to increments of 8.

 ; word offset in offset change map of first offset change entry
 OffsetChangeMap_X = BG3HOFS >> 3;
 ; word offset in row in offset change map to use
 OffsetChangeMap_Y = (BG3VOFS >> 3) << 5;

 Note that the offset change map does wrap rows back to themselves like
  any other layer.

%endif

%include "ppu/bg8o.inc"
%include "ppu/bg16o.inc"

%include "ppu/bg16e.inc"

%include "ppu/bg16oe.inc"

;Sets up VLMapAddress and VRMapAddress

;Uses mosaic setting, horizontal/vertical offsets, screen map size and
;current scanline
;eax = C_LABEL(Current_Line_Render)
ALIGNC
Sort_Screen_Height_Mosaic:
 Get_Current_Line
Sort_Screen_Height:
 ; Corrupts eax,ebx,ecx,esi
 mov bl,[HScroll+1+edx]
 mov ecx,TLMapAddress
 mov bh,[TileWidth+edx]     ; 1 = 8x8, 2 = 16x8, 16x16
 mov esi,TRMapAddress
 test bl,bh
 jz .first_tile_in_left_screen_map
 add ecx,byte (TRMapAddress-TLMapAddress)
 add esi,byte (TLMapAddress-TRMapAddress)
.first_tile_in_left_screen_map:
 mov bl,[TileHeight+edx]    ; 1 = 8x8, 16x8, 2 = 16x16
 add eax,[VScroll+edx]
 test ah,bl
 jz .line_in_top_screen_map

 mov eax,[edx+ecx+(BLMapAddress-TLMapAddress)]
 mov ebx,[edx+esi+(BLMapAddress-TLMapAddress)]
 mov [VRMapAddress+edx],ebx
 mov [VLMapAddress+edx],eax
 ret

ALIGNC
.line_in_top_screen_map:
 mov eax,[edx+ecx]
 mov ebx,[edx+esi]
 mov [VRMapAddress+edx],ebx
 mov [VLMapAddress+edx],eax
 ret

;%1 = planenum, 2 = priority
%macro RENDER_LINE 2
 LOAD_BG_TABLE %1

%if %2 == 0
 xor eax,eax
 mov [Tile_Priority_Used],ax
%else
 mov al,[Priority_Unused+edx]
 test al,al
 jz %%no_plot

 mov al,[Priority_Used+edx]
 cmp al,1
 sbb al,al
%endif

 ; set up depth
 mov byte [Tile_priority_bit],(1 - (%2)) << (13 - 8)

 ; tile size and depth selected in BGMODE write handler
 call dword [LineRender+edx]
%%no_plot:
%endmacro

;%1 = planenum
%macro RENDER_LINE_NP 1
 LOAD_BG_TABLE %1

 mov al,1
 ; tile size and depth selected in BGMODE write handler
 call dword [LineRender+edx]
%endmacro

%if 0
 Mode 0 - 4 background layers, 8x8 and 16x16 tile sizes
  2bpl tile depth in all layers
  special: each background layer has its own set of palettes

 Mode 1 - 3 background layers, 8x8 and 16x16 tile sizes
  4bpl tile depth in layers 1 and 2, 2bpl tile depth in layer 3
  special: BG3 high priority selection
%endif

%define SM01_Local_Bytes 20
%define SM01_Layers_Copy esp+16
%define SM01_Current_Line esp+12
%define SM01_BaseDestPtr esp+8
%define SM01_Lines esp+4
%define SM01_Layers esp

%macro Check_Present_Layer 2
 test byte %2,1 << ((%1)-1)
%endmacro

%macro Jump_Present_Layer 3
 Check_Present_Layer (%1),%2
 jnz (%3)
%endmacro

%macro Jump_Not_Present_Layer 3
 Check_Present_Layer (%1),%2
 jz (%3)
%endmacro

%macro Check_Present_OBJ 1
 test byte %1,0x10
%endmacro

%macro Jump_Present_OBJ 2
 Check_Present_OBJ %1
 jnz (%2)
%endmacro

%macro Jump_Not_Present_OBJ 2
 Check_Present_OBJ %1
 jz (%2)
%endmacro

%macro Jump_BG3_Highest 1
 cmp byte [C_LABEL(Base_BGMODE)],1
 jne %%not_highest
 test byte [C_LABEL(BGMODE)],8
 jnz (%1)
%%not_highest:
%endmacro

%macro Jump_Not_BG3_Highest 1
 cmp byte [C_LABEL(Base_BGMODE)],1
 jne (%1)
 test byte [C_LABEL(BGMODE)],8
 jz (%1)
%endmacro

;requires current line in ebx, uses cl
%macro Check_Present_OBJ_Priority 1
 mov cl,[OAM_Count_Priority+ebx*4-4+(%1)]
 test cl,cl
%endmacro

%macro Jump_Present_OBJ_Priority 2
 Check_Present_OBJ_Priority (%1)
 jnz (%2)
%endmacro

%macro Jump_Not_Present_OBJ_Priority 2
 Check_Present_OBJ_Priority (%1)
 jz (%2)
%endmacro

%macro Get_Clip_Window 1
 mov esi,[Window_Offset_First+(%1)*4]
%endmacro

%macro Render_SM01 2
 Jump_Not_Present_Layer 4,[SM01_Layers+%1],%%bg4_lo_done
 mov ebx,[SM01_Current_Line]
 mov edi,[SM01_BaseDestPtr]
 mov ebp,%2

 Get_Clip_Window %1

%ifndef NO_EARLY_PRIORITY_ELIMINATION
 Jump_Present_Layer 3,[SM01_Layers+%1],%%bg4_lo_priority
 Jump_Not_Present_OBJ [SM01_Layers+%1],%%bg4_no_priority
 Jump_Present_OBJ_Priority 0,%%bg4_lo_priority

%%bg4_no_priority:
 
 RENDER_LINE_NP 4
 and byte [SM01_Layers+%1],~8
 jmp %%bg3_done

%%bg4_lo_priority:
%endif
 RENDER_LINE 4,0

%%bg4_lo_done:

 Jump_Not_Present_Layer 3,[SM01_Layers+%1],%%bg3_lo_done
 mov ebx,[SM01_Current_Line]
 mov edi,[SM01_BaseDestPtr]
 mov ebp,%2

 Get_Clip_Window %1

%ifndef NO_EARLY_PRIORITY_ELIMINATION
 Jump_BG3_Highest %%bg3_lo_priority
 Jump_Present_Layer 4,[SM01_Layers+%1],%%bg3_lo_priority
 Jump_Not_Present_OBJ [SM01_Layers+%1],%%bg3_no_priority
 Jump_Present_OBJ_Priority 0,%%bg3_lo_priority

%%bg3_no_priority:
 RENDER_LINE_NP 3
 and byte [SM01_Layers+%1],~4
 jmp %%bg3_done

%%bg3_lo_priority:
%endif
 RENDER_LINE 3,0

%%bg3_lo_done:

 Jump_Not_Present_OBJ [SM01_Layers+%1],%%no_sprites_0

 mov ebx,[SM01_Current_Line]
 mov edi,[SM01_BaseDestPtr]
 mov ebp,%2
;inc ebx
 mov dl,0x00
 call Plot_Sprites
%%no_sprites_0:

 Jump_Not_Present_Layer 4,[SM01_Layers+%1],%%bg4_hi_done
 mov ebx,[SM01_Current_Line]
 mov edi,[SM01_BaseDestPtr]
 mov ebp,%2

 Get_Clip_Window %1

 RENDER_LINE 4,1
%%bg4_hi_done:

 Jump_Not_Present_Layer 3,[SM01_Layers+%1],%%bg3_hi_done
 Jump_BG3_Highest %%bg3_hi_done
 mov ebx,[SM01_Current_Line]
 mov edi,[SM01_BaseDestPtr]
 mov ebp,%2

 Get_Clip_Window %1

 RENDER_LINE 3,1
%%bg3_hi_done:
%%bg3_done:

 Jump_Not_Present_OBJ [SM01_Layers+%1],%%no_sprites_1

 mov ebx,[SM01_Current_Line]
 mov edi,[SM01_BaseDestPtr]
 mov ebp,%2
;inc ebx
 mov dl,0x10
 call Plot_Sprites
%%no_sprites_1:

 Jump_Not_Present_Layer 2,[SM01_Layers+%1],%%bg2_lo_done
 mov ebx,[SM01_Current_Line]
 mov edi,[SM01_BaseDestPtr]
 mov ebp,%2

 Get_Clip_Window %1

%ifndef NO_EARLY_PRIORITY_ELIMINATION
 Jump_Present_Layer 1,[SM01_Layers+%1],%%bg2_lo_priority
 Jump_Not_Present_OBJ [SM01_Layers+%1],%%bg2_no_priority
 Jump_Present_OBJ_Priority 2,%%bg2_lo_priority

%%bg2_no_priority:
 RENDER_LINE_NP 2
 and byte [SM01_Layers+%1],~2
 jmp %%bg1_done

%%bg2_lo_priority:
%endif
 RENDER_LINE 2,0

%%bg2_lo_done:

 Jump_Not_Present_Layer 1,[SM01_Layers+%1],%%bg1_lo_done
 mov ebx,[SM01_Current_Line]
 mov edi,[SM01_BaseDestPtr]
 mov ebp,%2

 Get_Clip_Window %1

%ifndef NO_EARLY_PRIORITY_ELIMINATION
 Jump_Present_Layer 2,[SM01_Layers+%1],%%bg1_lo_priority
 Jump_Not_Present_OBJ [SM01_Layers+%1],%%bg1_no_priority
 Jump_Present_OBJ_Priority 2,%%bg1_lo_priority

%%bg1_no_priority:
 RENDER_LINE_NP 1
 and byte [SM01_Layers+%1],~1
 jmp %%bg1_done

%%bg1_lo_priority:
%endif
 RENDER_LINE 1,0

%%bg1_lo_done:

 Jump_Not_Present_OBJ [SM01_Layers+%1],%%no_sprites_2

 mov ebx,[SM01_Current_Line]
 mov edi,[SM01_BaseDestPtr]
 mov ebp,%2
;inc ebx
 mov dl,0x20
 call Plot_Sprites
%%no_sprites_2:

 Jump_Not_Present_Layer 2,[SM01_Layers+%1],%%bg2_hi_done
 mov ebx,[SM01_Current_Line]
 mov edi,[SM01_BaseDestPtr]
 mov ebp,%2

 Get_Clip_Window %1

 RENDER_LINE 2,1
%%bg2_hi_done:

 Jump_Not_Present_Layer 1,[SM01_Layers+%1],%%bg1_hi_done
 mov ebx,[SM01_Current_Line]
 mov edi,[SM01_BaseDestPtr]
 mov ebp,%2

 Get_Clip_Window %1

 RENDER_LINE 1,1
%%bg1_hi_done:
%%bg1_done:

 Jump_Not_Present_OBJ [SM01_Layers+%1],%%no_sprites_3

 mov ebx,[SM01_Current_Line]
 mov edi,[SM01_BaseDestPtr]
 mov ebp,%2
;inc ebx
 mov dl,0x30
 call Plot_Sprites
%%no_sprites_3:

 Jump_Not_BG3_Highest %%bg3_max_done
 Jump_Not_Present_Layer 3,[SM01_Layers+%1],%%bg3_max_done
 mov ebx,[SM01_Current_Line]
 mov edi,[SM01_BaseDestPtr]
 mov ebp,%2

 Get_Clip_Window %1

 RENDER_LINE 3,1
%%bg3_max_done:

%endmacro

ALIGNC
EXPORT_C SCREEN_MODE_0
EXPORT_C SCREEN_MODE_1
 push eax
 push ebx
 push edi
 push ebp
 push eax

.next_line:
 mov edi,[C_LABEL(SNES_Screen8)]    ; (256+16)*(239+1) framebuffer
 ; Clear the framebuffer
 mov ebx,[SM01_BaseDestPtr]
%ifdef LAYERS_PER_LINE
 mov ebp,1
%else
 mov ebp,[SM01_Lines]
%endif

 add edi,ebx

 ; Clear the framebuffer
 call C_LABEL(Clear_Scanlines)

%ifndef LAYERS_PER_LINE
 Render_SM01 0,[SM01_Lines]
 Render_SM01 1,[SM01_Lines]
%else
 Render_SM01 0,1
 Render_SM01 1,1

 mov eax,[SM01_Layers_Copy]
 mov [SM01_Layers],eax

 mov edi,[SM01_BaseDestPtr]
 inc dword [SM01_Current_Line]
 add edi,GfxBufferLinePitch
 dec dword [SM01_Lines]
 mov [SM01_BaseDestPtr],edi
 jnz near .next_line
%endif

 add esp,byte SM01_Local_Bytes
 ret

%if 0
 Mode 2 - 2 background layers, 8x8 and 16x16 tile sizes
  4bpl tile depth in layers 1 and 2
  special: offset change data (h and v) stored in layer 3

 Mode 3 - 2 background layers, 8x8 and 16x16 tile sizes
  8bpl tile depth in layer 1, 4bpl tile depth in layer 2
  special: direct color mode

 Mode 4 - 2 background layers, 8x8 and 16x16 tile sizes
  8bpl tile depth in layer 1, 2bpl tile depth in layer 2
  special: direct color mode
           offset change data (h or v?) stored in layer 3

 Mode 5 - 2 background layers, 16x8 and 16x16 tile sizes
  4bpl tile depth in layer 1, 2bpl tile depth in layer 2
  special: 512 mode

 Mode 6 - 1 background layer, 16x8 and 16x16 tile sizes
  4bpl tile depth in layer 1
  special: 512 mode
           offset change data (h and v?) stored in layer 3 (?)
%endif

%define SM26_Local_Bytes 20
%define SM26_Layers_Copy esp+16
%define SM26_Current_Line esp+12
%define SM26_BaseDestPtr esp+8
%define SM26_Lines esp+4
%define SM26_Layers esp

%macro Render_SM26 2
 Jump_Not_Present_Layer 2,[SM26_Layers+%1],%%bg2_lo_done
 mov ebx,[SM26_Current_Line]
 mov edi,[SM26_BaseDestPtr]
 mov ebp,%2

 Get_Clip_Window %1

%ifndef NO_EARLY_PRIORITY_ELIMINATION
 Jump_Present_Layer 1,[SM26_Layers+%1],%%bg2_lo_priority
 Jump_Not_Present_OBJ [SM26_Layers+%1],%%bg2_no_priority
 Jump_Present_OBJ_Priority 0,%%bg2_lo_priority
 Jump_Present_OBJ_Priority 1,%%bg2_lo_priority

%%bg2_no_priority:
 RENDER_LINE_NP 2
 and byte [SM26_Layers+%1],~2
 jmp %%bg2_done

%%bg2_lo_priority:
%endif
 RENDER_LINE 2,0

%%bg2_lo_done:

 Jump_Not_Present_OBJ [SM26_Layers+%1],%%no_sprites_0

 mov ebx,[SM26_Current_Line]
 mov edi,[SM26_BaseDestPtr]
 mov ebp,%2
;inc ebx
 mov dl,0x00
 call Plot_Sprites
%%no_sprites_0:

 Jump_Not_Present_Layer 1,[SM26_Layers+%1],%%bg1_lo_done
 mov ebx,[SM26_Current_Line]
 mov edi,[SM26_BaseDestPtr]
 mov ebp,%2

 Get_Clip_Window %1

%ifndef NO_EARLY_PRIORITY_ELIMINATION
 Jump_Present_Layer 2,[SM26_Layers+%1],%%bg1_lo_priority
 Jump_Not_Present_OBJ [SM26_Layers+%1],%%bg1_no_priority
 Jump_Present_OBJ_Priority 1,%%bg1_lo_priority
 Jump_Present_OBJ_Priority 2,%%bg1_lo_priority

%%bg1_no_priority:
 RENDER_LINE_NP 1
 and byte [SM26_Layers+%1],~1
 jmp %%bg1_done

%%bg1_lo_priority:
%endif
 RENDER_LINE 1,0

%%bg1_lo_done:

 Jump_Not_Present_OBJ [SM26_Layers+%1],%%no_sprites_1

 mov ebx,[SM26_Current_Line]
 mov edi,[SM26_BaseDestPtr]
 mov ebp,%2
;inc ebx
 mov dl,0x10
 call Plot_Sprites
%%no_sprites_1:

 Jump_Not_Present_Layer 2,[SM26_Layers+%1],%%bg2_hi_done
 mov ebx,[SM26_Current_Line]
 mov edi,[SM26_BaseDestPtr]
 mov ebp,%2

 Get_Clip_Window %1

 RENDER_LINE 2,1
%%bg2_hi_done:
%%bg2_done:

 Jump_Not_Present_OBJ [SM26_Layers+%1],%%no_sprites_2

 mov ebx,[SM26_Current_Line]
 mov edi,[SM26_BaseDestPtr]
 mov ebp,%2
;inc ebx
 mov dl,0x20
 call Plot_Sprites
%%no_sprites_2:

 Jump_Not_Present_Layer 1,[SM26_Layers+%1],%%bg1_hi_done
 mov ebx,[SM26_Current_Line]
 mov edi,[SM26_BaseDestPtr]
 mov ebp,%2

 Get_Clip_Window %1

 RENDER_LINE 1,1
%%bg1_hi_done:
%%bg1_done:

 Jump_Not_Present_OBJ [SM26_Layers+%1],%%no_sprites_3

 mov ebx,[SM26_Current_Line]
 mov edi,[SM26_BaseDestPtr]
 mov ebp,%2
;inc ebx
 mov dl,0x30
 call Plot_Sprites
%%no_sprites_3:

%endmacro

EXPORT_C SCREEN_MODE_2
EXPORT_C SCREEN_MODE_3
EXPORT_C SCREEN_MODE_4
EXPORT_C SCREEN_MODE_5
EXPORT_C SCREEN_MODE_6

 push eax
 push ebx
 push edi
 push ebp
 push eax

.next_line:
 mov edi,[C_LABEL(SNES_Screen8)]    ; (256+16)*(239+1) framebuffer
 ; Clear the framebuffer
 mov ebx,[SM26_BaseDestPtr]
%ifdef LAYERS_PER_LINE
 mov ebp,1
%else
 mov ebp,[SM26_Lines]
%endif

 add edi,ebx

 ; Clear the framebuffer
 call C_LABEL(Clear_Scanlines)

%ifndef LAYERS_PER_LINE
 Render_SM26 0,[SM26_Lines]
 Render_SM26 1,[SM26_Lines]
%else
 Render_SM26 0,1
 Render_SM26 1,1

 mov eax,[SM26_Layers_Copy]
 mov [SM26_Layers],eax

 mov edi,[SM26_BaseDestPtr]
 inc dword [SM26_Current_Line]
 add edi,GfxBufferLinePitch
 dec dword [SM26_Lines]
 mov [SM26_BaseDestPtr],edi
 jnz near .next_line
%endif

 add esp,byte SM26_Local_Bytes
 ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
