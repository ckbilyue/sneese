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

EXPORT palette_2bpl
 dd 0x03030303, 0x07070707, 0x0B0B0B0B, 0x0F0F0F0F
 dd 0x13131313, 0x17171717, 0x1B1B1B1B, 0x1F1F1F1F
EXPORT palette_4bpl
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

section .bss
;Z-buffer for display

;#L = tiles/pixels for layer # (low priority)
;#H = tiles/pixels for layer # (high priority)
;#S = sprites (# priority) 34 24 14 04
;BA = back area 00
;L7 = (2L) mode-7 EXTBG low priority 1
;N7 = (1L) mode-7 EXTBG low priority 2, mode-7 w/o EXTBG
;H7 = (2H) mode-7 EXTBG high priority

;modes 0-1
;layer 3H 3S 1H 2H 2S 1L 2L 1S 3H 4H 0S 3L 4L BA
;Z     38 34 32 31 24 22 21 14 12 11 04 02 01 00

;modes 2-7
;layer 3S 1H 2S 2H 1S 1L 0S 2L BA
;Z     34 32 24 22 14 12 04 02 00

ALIGNB
EXPORT DisplayZ,skipb (8+256+8)
ALIGNB
EXPORT_C Current_Line_Render,skipl
EXPORT_C Last_Frame_Line,skipl
EXPORT Ready_Line_Render,skipl
EXPORT BaseDestPtr      ,skipl

EXPORT Render_Select,skipl  ; Base renderer
EXPORT Render_Mode  ,skipl  ; Mode renderer

%if 0
MOSAIC
Mosaic effect uses a scanline countdown register, which is loaded at
scanline 1, and reloaded at start of every scanline where it is 0.

Backgrounds with enable bits set in MOSAIC register do not update their
scanline counters except on MOSAIC countdown reload.  If mosaic effect is
enabled on a non-reload scanline, it will continue to use the previous
line's counter.  If enabled on a reload scanline, it will use the current
line's counter.

Countdown register always counts down on every line during display period
(force blank not tested), even when effect is not enabled on any
background, or when size is set to 0.  Countdown register is shared for all
backgrounds.
%endif
;Countdown register for MOSAIC
EXPORT MosaicCountdown  ,skipl

EXPORT BGLineCount ,skipl

EXPORT LineAddress ,skipl   ; Address of tileset, + offset to line in tile
EXPORT LineAddressY,skipl   ; Same, for vertical flip
EXPORT TileMask    ,skipl   ; Tile address mask, for tileset wrap
EXPORT Palette_Base,skipl

; Used for offset change map addressing
EXPORT OffsetChangeMap_VOffset,skipl    ; BG3VOFS + BG3SC
EXPORT OffsetChangeVMap_VOffset,skipl   ; BG3VOFS + BG3SC (for split-table)

EXPORT Display_Needs_Update,skipb
EXPORT Tile_Layers_Enabled,skipb
EXPORT Tile_priority_bit,skipb
EXPORT Tile_Priority_Used,skipb
EXPORT Tile_Priority_Unused,skipb

EXPORT OffsetChangeDetect1,skipb
EXPORT OffsetChangeDetect2,skipb
EXPORT OffsetChangeDetect3,skipb

EXPORT_C Offset_Change_Disable  ,skipb

section .text
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
 jmp .detect_loop

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
 jnz C_LABEL(Clear_Scanlines_Preload).clear_loop

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
 jz C_LABEL(Clear_Scanlines)

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
 mov byte [Display_Needs_Update],0

 push ebx
 push ecx
 push edi
 push ebp
 push esi
 push edx

;handle mosaic - setup linecounters for first line drawn
%if 0
LineCounter_BG[no mosaic] = current_line
if (!MosaicCountdown)
{
 LineCounter_BG[mosaic] = current_line
}
%endif
 mov cl,[MosaicCountdown]
 mov al,[MOSAIC]
 mov ebx,[C_LABEL(Current_Line_Render)]
 add cl,255
 sbb cl,cl
 inc ebx
 and al,cl

 test al,1
 jnz .no_update_linecounter_bg1
 mov [LineCounter_BG1],ebx
.no_update_linecounter_bg1:
 test al,2
 jnz .no_update_linecounter_bg2
 mov [LineCounter_BG2],ebx
.no_update_linecounter_bg2:
 test al,4
 jnz .no_update_linecounter_bg3
 mov [LineCounter_BG3],ebx
.no_update_linecounter_bg3:
 test al,8
 jnz .no_update_linecounter_bg4
 mov [LineCounter_BG4],ebx
.no_update_linecounter_bg4:

 mov ah,[C_LABEL(INIDISP)]
 test ah,ah         ; Check for screen off
 js .screen_off

 cmp byte [Redo_Layering],0
 jz .no_layering_recalc_needed
 call C_LABEL(Update_Layering)
.no_layering_recalc_needed:

 xor eax,eax
 mov [Priority_Used_BG1],ax
 mov [Priority_Used_BG2],ax
 mov [Priority_Used_BG3],ax
 mov [Priority_Used_BG4],ax

%ifdef WATCH_RENDER_BREAKS
EXTERN_C BreaksLast
 inc dword [C_LABEL(BreaksLast)]
%endif

 mov al,[SCR_TM]
 mov bl,[BGMODE_Tile_Layer_Mask]
 or al,[SCR_TS]
 and al,bl
 mov [Tile_Layers_Enabled],al
 jz .no_tile_layers

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
 call C_LABEL(Check_OAM_Recache)
.no_oam_recache_needed:

 SORT_OFFSET_CHANGE

.no_tile_layers:

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
 mov ebx,[C_LABEL(Current_Line_Render)]
 add ebx,edx
 mov [C_LABEL(Current_Line_Render)],ebx

 mov al,[MOSAIC]
 test al,1
 jnz .mosaic_bg1
 mov [LineCounter_BG1],ebx
.mosaic_bg1:
 test al,2
 jnz .mosaic_bg2
 mov [LineCounter_BG2],ebx
.mosaic_bg2:
 test al,4
 jnz .mosaic_bg3
 mov [LineCounter_BG3],ebx
.mosaic_bg3:
 test al,8
 jnz .mosaic_bg4
 mov [LineCounter_BG4],ebx
.mosaic_bg4:

;if (countdown >= linecount) countdown -= linecount;
;else
;{
; line += countdown + MosaicLine[linecount - countdown - 1];
; countdown = MosaicCount[linecount - countdown];
; if (countdown == size) countdown = 0;
;}
 mov eax,[MosaicCountdown]
 mov ebp,eax
 sub eax,edx
 jge .mosaic_fixup_done

 mov esi,[Mosaic_Size_Select]
 xor eax,-1
 xor ecx,ecx
 xor ebx,ebx
 mov cl,[C_LABEL(MosaicCount)+esi+eax+1]  ;1
 mov bl,[C_LABEL(MosaicLine)+esi+eax+1-1] ;6c
 mov eax,[Mosaic_Size] ;1
 add ebx,ebp           ;6c
 cmp ecx,eax           ;
 sbb eax,eax
 and eax,ecx
.mosaic_fixup_done:
 mov [MosaicCountdown],eax

 mov al,[MOSAIC]
 mov ebx,[LineCounter_BG1]
 mov ecx,[LineCounter_BG2]
 mov esi,[LineCounter_BG3]
 mov edi,[LineCounter_BG4]

 test al,1
 jz .no_mosaic_bg1
 add [LineCounter_BG1],ebp
.no_mosaic_bg1:
 test al,2
 jz .no_mosaic_bg2
 add [LineCounter_BG2],ebp
.no_mosaic_bg2:
 test al,4
 jz .no_mosaic_bg3
 add [LineCounter_BG3],ebp
.no_mosaic_bg3:
 test al,8
 jz .no_mosaic_bg4
 add [LineCounter_BG4],ebp
.no_mosaic_bg4:

 pop esi
 pop ebp
 pop edi
 pop ecx
 pop ebx

 mov eax,GfxBufferLinePitch
 imul eax,edx
 add [BaseDestPtr],eax
 pop eax
.return:
 ret

ALIGNC
.screen_off:
 mov ebp,edx
 mov edi,[C_LABEL(SNES_Screen8)]    ; (256+16)*(239+1) framebuffer
 mov ebx,[BaseDestPtr]
 add edi,ebx

 ; Clear the framebuffer
 call C_LABEL(Clear_Scanlines)

 pop edx
 mov ebx,[C_LABEL(Current_Line_Render)]
 add ebx,edx
 mov [C_LABEL(Current_Line_Render)],ebx

 mov al,[MOSAIC]
 test al,1
 jnz .so_mosaic_bg1
 mov [LineCounter_BG1],ebx
.so_mosaic_bg1:
 test al,2
 jnz .so_mosaic_bg2
 mov [LineCounter_BG2],ebx
.so_mosaic_bg2:
 test al,4
 jnz .so_mosaic_bg3
 mov [LineCounter_BG3],ebx
.so_mosaic_bg3:
 test al,8
 jnz .so_mosaic_bg4
 mov [LineCounter_BG4],ebx
.so_mosaic_bg4:

;if (countdown >= linecount) countdown -= linecount;
;else
;{
; line += countdown + MosaicLine[linecount - countdown - 1];
; countdown = MosaicCount[linecount - countdown];
; if (countdown == size) countdown = 0;
;}
 mov eax,[MosaicCountdown]
 mov ebp,eax
 sub eax,edx
 jge .so_mosaic_fixup_done

 mov esi,[Mosaic_Size_Select]
 xor eax,-1
 xor ecx,ecx
 xor ebx,ebx
 mov ecx,[C_LABEL(MosaicCount)+esi+eax+1]
 mov ebx,[C_LABEL(MosaicLine)+esi+eax+1-1]
 mov eax,[Mosaic_Size]
 add ebx,ebp
 cmp ecx,eax
 sbb eax,eax
 and ecx,eax
 mov [MosaicCountdown],cl

 mov al,[MOSAIC]
 mov ebx,[LineCounter_BG1]
 mov ecx,[LineCounter_BG2]
 mov esi,[LineCounter_BG3]
 mov edi,[LineCounter_BG4]

 test al,1
 jz .so_no_mosaic_bg1
 add [LineCounter_BG1],ebp
.so_no_mosaic_bg1:
 test al,2
 jz .so_no_mosaic_bg2
 add [LineCounter_BG2],ebp
.so_no_mosaic_bg2:
 test al,4
 jz .so_no_mosaic_bg3
 add [LineCounter_BG3],ebp
.so_no_mosaic_bg3:
 test al,8
 jz .so_no_mosaic_bg4
 add [LineCounter_BG4],ebp
.so_no_mosaic_bg4:

.so_mosaic_fixup_done:
 mov [MosaicCountdown],eax

 pop esi
 pop ebp
 pop edi
 pop ecx
 pop ebx

 mov eax,GfxBufferLinePitch
 imul eax,edx
 add [BaseDestPtr],eax
 pop eax
 ret

; esi is screen address, works cos we only plot until wraparound!
; ch contains the X counter
; cl contains the screen addition for palette offsetting (2bpl only)
; edi is the address to draw to..
; LineAddress contains the location for the SNES tile data
; LineAddress(Y) must be offset to the correct line for that row
; LineAddressY is used for Y-flip

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

;Sets up VLMapAddress and VRMapAddress

;Uses mosaic setting, horizontal/vertical offsets, screen map size and
;current scanline
;eax = C_LABEL(Current_Line_Render)
ALIGNC
EXPORT Sort_Screen_Height_Mosaic
 Get_Current_Line
EXPORT Sort_Screen_Height
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
 jnz .next_line
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
 jnz .next_line
%endif

 add esp,byte SM26_Local_Bytes
 ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
