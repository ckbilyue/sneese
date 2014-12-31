%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2015, Charles Bilyue.
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

%ifndef SNEeSe_ppu_screen_inc
%define SNEeSe_ppu_screen_inc

%define NO_EARLY_CACHE_LOAD

EXTERN MosaicLine,MosaicCount
EXTERN SNES_Screen8

%ifndef SNEeSe_ppu_screen_asm

EXTERN Clear_Scanlines,Clear_Scanlines_Preload
EXTERN Zbase,Zpositions,Zbase_main,Zbase_sub
EXTERN screen_text_start,screen_data_start,screen_bss_start
EXTERN Tile_Offset_Table_16_8

EXTERN palette_2bpl,palette_4bpl

EXTERN MosaicCountdown
EXTERN BGLineCount

EXTERN LineAddress,LineAddressY
EXTERN TileMask
EXTERN Palette_Base

EXTERN OffsetChangeMap_HOffset,OffsetChangeMap_VOffset
EXTERN OffsetChangeVMap_VOffset
EXTERN Offset_Change_Disable

EXTERN Current_Line_Render,Last_Frame_Line
EXTERN Ready_Line_Render,BaseDestPtr
EXTERN Display_Needs_Update

EXTERN Tile_priority_bit
EXTERN Tile_Priority_Used
EXTERN Tile_Priority_Unused

EXTERN Update_Display_asm
EXTERN Tile_Width,Tile_Height
EXTERN NO_PLANES

EXTERN Sort_Screen_Height_Mosaic
EXTERN Sort_Screen_Height

EXTERN Render_Select,Render_Mode
%endif

EXTERN Screen_Mode

EXTERN SCREEN_MODE_0_1
EXTERN SCREEN_MODE_2_6

EXTERN Render_Layering_Option_0
EXTERN Render_Layering_Option_1
EXTERN Render_Layering_Option_2

%ifndef SNEeSe_ppu_mode7_asm
EXTERN SNES_R2134,SNES_R2135,SNES_R2136
EXTERN SNES_W211A,SNES_W211B,SNES_W211C,SNES_W211D
EXTERN SNES_W211E,SNES_W211F,SNES_W2120

EXTERN SCREEN_MODE_7

EXTERN Reset_Mode_7

EXTERN M7H_13,M7V_13
EXTERN Redo_M7
EXTERN M7SEL
EXTERN EXTBG_Mask
EXTERN M7_Handler_Table,M7_Handler
%endif


%ifndef SNEeSe_ppu_bg8_asm
EXTERN Render_8x8_C2,Render_8x8_C4,Render_8x8_C8
%endif

%ifndef SNEeSe_ppu_bg8m_asm
EXTERN Render_8x8M_C2,Render_8x8M_C4,Render_8x8M_C8
%endif

%ifndef SNEeSe_ppu_bg8o_asm
EXTERN Render_Offset_8x8_C2
EXTERN Render_Offset_8x8_C4
EXTERN Render_Offset_8x8_C8
%endif

%ifndef SNEeSe_ppu_bg8om_asm
EXTERN Render_Offset_8x8M_C2
EXTERN Render_Offset_8x8M_C4
EXTERN Render_Offset_8x8M_C8
%endif

%ifndef SNEeSe_ppu_bg16_asm
EXTERN Render_16x16_C2,Render_16x16_C4,Render_16x16_C8
%endif

%ifndef SNEeSe_ppu_bg16m_asm
EXTERN Render_16x16M_C2,Render_16x16M_C4,Render_16x16M_C8
%endif

%ifndef SNEeSe_ppu_bg16o_asm
EXTERN Render_Offset_16x16_C2
EXTERN Render_Offset_16x16_C4
EXTERN Render_Offset_16x16_C8
%endif

%ifndef SNEeSe_ppu_bg16om_asm
EXTERN Render_Offset_16x16M_C2
EXTERN Render_Offset_16x16M_C4
EXTERN Render_Offset_16x16M_C8
%endif

%ifndef SNEeSe_ppu_bg16e_asm
EXTERN Render_16x8_Even_C2,Render_16x16_Even_C2
EXTERN Render_16x8_Even_C4,Render_16x16_Even_C4
%endif

%ifndef SNEeSe_ppu_bg16me_asm
EXTERN Render_16x8M_Even_C2,Render_16x16M_Even_C2
EXTERN Render_16x8M_Even_C4,Render_16x16M_Even_C4
%endif

%ifndef SNEeSe_ppu_bg16oe_asm
EXTERN Render_Offset_16x8_Even_C4,Render_Offset_16x16_Even_C4
%endif

%ifndef SNEeSe_ppu_bg16ome_asm
EXTERN Render_Offset_16x8M_Even_C4,Render_Offset_16x16M_Even_C4
%endif


%ifndef SNEeSe_ppu_windows_asm
EXTERN ClipTableStart,ClipLeftTable,ClipRightTable
EXTERN TileClip1,TileClip1Left,TileClip1Right
EXTERN TileClip2,TileClip2Left,TileClip2Right

EXTERN Redo_Layering,Redo_Windowing
EXTERN Recalc_Window_Effects
EXTERN Recalc_Window_Area_BG
EXTERN Intersect_Window_Area_AND
EXTERN Intersect_Window_Area_OR
EXTERN Intersect_Window_Area_XOR

EXTERN W12SEL,W34SEL,WOBJSEL,WBGLOG,WOBJLOG,CGWSEL,CGADSUB
EXTERN WH0,WH1,WH2,WH3
EXTERN TM,TS,TMW,TSW

EXTERN Window_Offsets
Window_Offset_First  equ Window_Offsets
Window_Offset_Second equ (Window_Offsets + 4)

EXTERN TM_Allowed,TS_Allowed,Layers_In_Use
EXTERN Layers_Low,Layers_High
EXTERN SCR_TM,SCR_TS,SCR_TMW,SCR_TSW
EXTERN Layer_Disable_Mask,Layering_Mode

%macro EXTERN_WIN_DATA 1
EXTERN TableWin%1
EXTERN Win%1_Count_Out
EXTERN Win%1_Bands_Out
EXTERN Win%1_Count_In
EXTERN Win%1_Bands_In
%endmacro

EXTERN_WIN_DATA 1
EXTERN_WIN_DATA 2

%macro MERGED_WIN_DATA 2
EXPORT TableWin%1
EXPORT Win%1_Count,skipb
EXPORT Win%1_Bands,skipb 2*%2
%endmacro

%macro EXTERN_MERGED_WIN_DATA 2
EXTERN TableWin%1
EXTERN Win%1_Count
EXTERN Win%1_Bands
%endmacro

%endif

%define GfxBufferLinePitch (256)

%define Redo_Win_BG(x) BIT((x) - 1)
%define Redo_Win_OBJ BIT(4)
%define Redo_Win_Color BIT(5)
%define Redo_Win(x) BIT(6 + (x) - 1)

%macro Render_Start_Frame 0
 mov dword [BaseDestPtr],0
 mov dword [Current_Line_Render],0
 mov dword [Ready_Line_Render],0
 mov dword [NMI_Event_Handler],NMI
 mov dword [MosaicCountdown],0
%endmacro

%macro Render_Start_Frame_Skipped 0
 mov dword [Current_Line_Render],1024
 mov dword [NMI_Event_Handler],NMI_NoRender
%endmacro

%macro UpdateDisplay 0
;mov edx,[Ready_Line_Render]
;sub edx,[Current_Line_Render]
;jbe  %%no_update_needed
 mov dl,[Display_Needs_Update]
 test dl,dl
 jz  %%no_update_needed
 call Update_Display_asm
%%no_update_needed:
%endmacro

%macro RenderScanline 0
 inc dword [Ready_Line_Render]
 mov byte [Display_Needs_Update],1
%if 0
 mov eax,[Ready_Line_Render]
 inc eax
 mov ebx,[BG1VOFS]
 mov [Ready_Line_Render],eax
 mov esi,[BG1HOFS]
 mov [eax*4+LineBG1OFS+0],bx
 mov edi,[BG2VOFS]
 mov [eax*4+LineBG1OFS+4],si
 mov ebx,[BG2HOFS]
 mov [eax*4+LineBG2OFS+0],di
 mov esi,[BG3VOFS]
 mov [eax*4+LineBG2OFS+4],bx
 mov edi,[BG3HOFS]
 mov [eax*4+LineBG3OFS+0],si
 mov ebx,[BG4VOFS]
 mov [eax*4+LineBG3OFS+4],di
 mov esi,[BG4HOFS]
 mov [eax*4+LineBG4OFS+0],bx
 mov [eax*4+LineBG4OFS+4],si
%endif
%if 0
 mov edi,[ScreenDestPtr]
 xor eax,eax
 mov ebp,byte 256/32

ALIGNC
%%clear_loop:
 lea esi,[16+edi]
 mov [edi],eax
 mov [4+edi],eax
 mov [8+edi],eax
 mov [12+edi],eax
 mov %eax,[esi]
 lea edi,[16+esi]
 mov [4+esi],eax
 mov [8+esi],eax
 mov [12+esi],eax
 dec ebp
 jnz %%clear_loop

 mov ah,[_INIDISP]
 test ah,ah     ; Check for screen off
 js %%screen_off

 mov bl,[SCR_TM]    ; Get BG status for main screens
 call [Render_Mode]
 mov bl,[SCR_TS]    ; Get BG status for sub screens
 call [Render_Mode]
 mov edi,[ScreenDestPtr]
 add edi,256        ; Point screen to next line
%%screen_off:
 mov [ScreenDestPtr],edi
%endif
%endmacro

%macro Get_Current_Line 0
; parameters: none
; uses: eax (Current_Line_Render), ebx
; returns: eax

 ; Handle vertical mosaic
 mov bl,[Mosaic+edx]
 test bl,bl
 jz %%no_mosaic
 mov ebx,[Mosaic_Size_Select]
 mov al,[MosaicLine+eax+ebx]
%%no_mosaic:
 ; End vertical mosaic
%endmacro

; v0.25 - One macro for 8x8 and 16x8 tiles
;%1 = offset_change
%macro SORT_TILES_8_TALL 0-1 0
; parameters: edx
; uses: eax (Current_Line_Render, mosaic-adjusted), esi
; returns: ebx, LineAddress, LineAddressY

 add eax,[VScroll+edx]
 mov ebx,eax
 and eax,byte 7 ; Line offset in tile
 shl ebx,3      ; Get screen offset
 mov esi,7
 and ebx,0xF8*8 ; Current line + V scroll * 32words
 sub esi,eax
%ifnidni %1,0
 mov %1,ebx
%endif
 mov [LineAddress],eax
 mov [LineAddressY],esi
%endmacro

%macro SORT_TILES_16_TALL 0-1 0
; parameters: edx
; uses: eax (Current_Line_Render, mosaic-adjusted), ecx, esi
; returns: ebx, LineAddress, LineAddressY

 add eax,[VScroll+edx]
 mov ebx,eax
 and eax,byte 0x0F  ; Offset into table of line offsets
 shl ebx,2          ; Get screen offset
 mov esi,16*8+7
 and ebx,0x1F0*4    ; Current line + V scroll * 32words
 mov ecx,[Tile_Offset_Table_16_8+eax*4]
%ifnidni %1,0
 mov %1,ebx
%endif
 sub esi,ecx
 mov [LineAddress],ecx
 mov [LineAddressY],esi
%endmacro

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

%endif ; !defined(SNEeSe_ppu_screen_inc)
