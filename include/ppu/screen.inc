%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

%ifndef SNEeSe_ppu_screen_inc
%define SNEeSe_ppu_screen_inc

%define NO_EARLY_CACHE_LOAD

%ifndef SNEeSe_ppu_screen_asm

EXTERN_C Clear_Scanlines,Clear_Scanlines_Preload
EXTERN DisplayZ
EXTERN Zbase,Zpositions,Zbase_main,Zbase_sub
EXTERN_C screen_text_start,screen_data_start,screen_bss_start
EXTERN Tile_Offset_Table_64_8
EXTERN Screen_Mode
EXTERN LineAddress,LineAddressY
EXTERN TileMask
EXTERN OffsetChangeMap_HOffset,OffsetChangeMap_VOffset
EXTERN OffsetChangeVMap_VOffset
EXTERN_C Current_Line_Render,Last_Frame_Line
EXTERN Ready_Line_Render,BaseDestPtr
EXTERN Display_Needs_Update
EXTERN Render_Select,Render_Mode
EXTERN Redo_Windowing
EXTERN_C Render_Layering_Option_0
EXTERN_C Render_Layering_Option_1
EXTERN_C Render_Layering_Option_2
EXTERN_C Update_Display
EXTERN_C Recalc_Window_Effects
EXTERN_C Recalc_Window_Area_BG
EXTERN_C Intersect_Window_Area_AND
EXTERN_C Intersect_Window_Area_OR
EXTERN_C Intersect_Window_Area_XOR
EXTERN_C Render_8x8_C2,Render_16x16_C2
EXTERN_C Render_8x8_C4,Render_16x16_C4
EXTERN_C Render_8x8_C8,Render_16x16_C8
EXTERN_C Render_Offset_8x8_C2,Render_Offset_16x16_C2
EXTERN_C Render_Offset_8x8_C4,Render_Offset_16x16_C4
EXTERN_C Render_Offset_8x8_C8,Render_Offset_16x16_C8
EXTERN_C Render_16x8_Even_C2,Render_16x16_Even_C2
EXTERN_C Render_16x8_Even_C4,Render_16x16_Even_C4
EXTERN_C Render_Offset_16x8_Even_C4,Render_Offset_16x16_Even_C4
EXTERN Tile_Width,Tile_Height
EXTERN NO_PLANES
EXTERN_C SCREEN_MODE_0
EXTERN_C SCREEN_MODE_1
EXTERN_C SCREEN_MODE_2
EXTERN_C SCREEN_MODE_3
EXTERN_C SCREEN_MODE_4
EXTERN_C SCREEN_MODE_5
EXTERN_C SCREEN_MODE_6
%endif

%define GfxBufferLineSlack (1 << GfxBufferLineSlackShift)
%define GfxBufferLineSlackShift 3
%define GfxBufferLinePitch (256+GfxBufferLineSlack)

%define Redo_Win_BG(x) (1 << ((x) - 1))
%define Redo_Win_OBJ (1 << 4)
%define Redo_Win_Color (1 << 5)
%define Redo_Win(x) (1 << (6 + (x) - 1))

%macro Render_Start_Frame 0
 mov dword [BaseDestPtr],0
 mov dword [C_LABEL(Current_Line_Render)],0
 mov dword [Ready_Line_Render],0
 mov dword [NMI_Event_Handler],C_LABEL(NMI)
%endmacro

%macro Render_Start_Frame_Skipped 0
 mov dword [C_LABEL(Current_Line_Render)],1024
 mov dword [NMI_Event_Handler],C_LABEL(NMI_NoRender)
%endmacro

%macro UpdateDisplay 0
;mov edx,[Ready_Line_Render]
;sub edx,[C_LABEL(Current_Line_Render)]
;jbe  %%no_update_needed
 mov dl,[Display_Needs_Update]
 test dl,dl
 jz  %%no_update_needed
 call C_LABEL(Update_Display)
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
 add edi,byte GfxBufferLineSlack
 mov [ScreenDestPtr],edi
%endif
%endmacro

%macro Get_Current_Line 0
; parameters: none
; uses: eax (C_LABEL(Current_Line_Render)), ebx
; returns: eax

 ; Handle vertical mosaic
 mov bl,[Mosaic+edx]
 test bl,bl
 jz %%no_mosaic
 mov ebx,[Mosaic_Size_Select]
 mov al,[C_LABEL(MosaicLine)+eax+ebx]
%%no_mosaic:
 ; End vertical mosaic
%endmacro

; v0.25 - One macro for 8x8 and 16x8 tiles
;%1 = offset_change
%macro SORT_TILES_8_TALL 0-1 0
; parameters: edx
; uses: eax (C_LABEL(Current_Line_Render), mosaic-adjusted), esi
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
; uses: eax (C_LABEL(Current_Line_Render), mosaic-adjusted), ecx, esi
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

%endif ; !defined(SNEeSe_ppu_screen_inc)
