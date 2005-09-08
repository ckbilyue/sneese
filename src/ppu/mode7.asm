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

; Mode 7 matrix rendering / hardware port emulation.

%define SNEeSe_ppu_mode7_asm

%include "misc.inc"
%include "ppu/sprites.inc"
%include "ppu/screen.inc"
%include "ppu/ppu.inc"

section .text
EXPORT mode7_start

;%define old_sprites
EXTERN Ready_Line_Render,BaseDestPtr
EXTERN_C SNES_Screen8
EXTERN_C MosaicCount,MosaicLine
EXTERN Tile_priority_bit

section .data
ALIGND
EXPORT M7_Handler_Table
dd M7_REPEAT,M7_CLIP,M7_CLIP,M7_CHAR0
dd M7P_REPEAT,M7P_CLIP,M7P_CLIP,M7P_CHAR0

section .bss
ALIGNB
EXPORT Mode7_AHX,skipl  ; M7A * (BG1HOFS - M7X) + (M7X << 8)
EXPORT Mode7_VY ,skipl  ; BG1VOFS - M7Y
EXPORT Mode7_CHXY,skipl ; M7C * (BG1HOFS - M7X) + (M7Y << 8)
; M7A * (BG1HOFS - M7X) + (M7X << 8) + M7B * (line + BG1VOFS - M7Y)
EXPORT Mode7_Line_X,skipl
; M7C * (BG1HOFS - M7X) + (M7Y << 8) + M7D * (line + BG1VOFS - M7Y)
EXPORT Mode7_Line_Y,skipl


EXPORT M7A      ,skipl
EXPORT M7B      ,skipl
EXPORT M7C      ,skipl
EXPORT M7D      ,skipl
EXPORT M7X_13   ,skipl
EXPORT M7Y_13   ,skipl
EXPORT M7H_13   ,skipl
EXPORT M7V_13   ,skipl
EXPORT M7X      ,skipl
EXPORT M7Y      ,skipl
EXPORT M7H      ,skipl
EXPORT M7V      ,skipl

;M7A, M7C are taken from here to help handle X-flip
EXPORT M7A_X    ,skipl
EXPORT M7C_X    ,skipl

;M7A, M7C are taken from here to help handle X-flip and mosaic
EXPORT M7A_XM   ,skipl
EXPORT M7C_XM   ,skipl


MPY:    skipl   ; Mode 7 multiplication result
MPYL equ MPY    ; Mode 7 multiplication result: low byte
MPYM equ MPY+1  ; Mode 7 multiplication result: middle byte
MPYH equ MPY+2  ; Mode 7 multiplication result: high byte

EXPORT M7_Handler,skipl
EXPORT M7_Handler_EXTBG,skipl
EXPORT EXTBG_Mask,skipb ; mask applied to BG enable for EXTBG
EXPORT M7SEL,skipb      ; ab0000yx  ab=mode 7 repetition info,y=flip vertical,x=flip horizontal
EXPORT Redo_M7,skipb    ; vhyxdcba
M7_Last_Write:skipb
M7_Used:    skipb
M7_Unused:  skipb
Redo_16x8:  skipb

; BG1 area |  BG2 area = displayed mode 7 background
; BG2 area = EXTBG, high priority

; BG1 area + BG2 area on main screen; both screens in 8-bit rendering
MERGED_WIN_DATA Mode7_Main,4
; BG1 area + BG2 area on sub screen (currently unused)
MERGED_WIN_DATA Mode7_Sub,4

;!BG1 area on main screen; both screens in 8-bit rendering
MERGED_WIN_DATA BG1_Main_Off,3
;!BG1 area on sub screen (currently unused)
MERGED_WIN_DATA BG1_Sub_Off,3

;!BG2 area on main screen; both screens in 8-bit rendering
MERGED_WIN_DATA BG2_Main_Off,3
;!BG2 area on sub screen (currently unused)
MERGED_WIN_DATA BG2_Sub_Off,3

;!BG1 area &  BG2 area = EXTBG, low priority
;main screen; both in 8-bit
MERGED_WIN_DATA Mode7_Main_EXTBG_Low,3
;sub screen
MERGED_WIN_DATA Mode7_Sub_EXTBG_Low,3

; BG1 area &  BG2 area = EXTBG, normal priority
;main screen; both in 8-bit
MERGED_WIN_DATA Mode7_Main_EXTBG_Normal,3
;sub screen
MERGED_WIN_DATA Mode7_Sub_EXTBG_Normal,3

; BG1 area & !BG2 area = no EXTBG
;main screen; both in 8-bit
MERGED_WIN_DATA Mode7_Main_EXTBG_Off,3
;sub screen
MERGED_WIN_DATA Mode7_Sub_EXTBG_Off,3

%define SM7_Local_Bytes 16
%define SM7_Current_Line esp+12
%define SM7_BaseDestPtr esp+8
%define SM7_Lines esp+4
%define SM7_Layers esp

; edx = address of window 1 bands
; esi = address of window 2 bands
; cl = count of window 1 bands
; ch = count of window 2 bands
; ebp = 0
; edi = address for output window area (BG_WIN_DATA)

section .text
ALIGNC
EXPORT SCREEN_MODE_7

 push ebx
 push edi
EXTERN_C Layer_Disable_Mask
 and al,[C_LABEL(Layer_Disable_Mask)]
 and ah,[C_LABEL(Layer_Disable_Mask)]
 push ebp

 ; we don't have to worry about if EXTBG is disabled, as BG2
 ; will be masked off here if it is
 ; if SETINI:6 (EXTBG enable) is clear, ignore BG2 enable (EXTBG)
 push eax

 test eax,0x303
 jnz .background_on

.background_off:
 mov edi,[C_LABEL(SNES_Screen8)]    ; (256+16)*(240+1) framebuffer
 ; Clear the framebuffer
 mov ebx,[SM7_BaseDestPtr]
 mov ebp,[SM7_Lines]
 add edi,ebx

 ; Clear the framebuffer
 call C_LABEL(Clear_Scanlines)

 test dword [SM7_Layers],0x1010
 jz .no_sprites

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,[SM7_Lines]
;inc ebx
 mov dl,0x00
 call Plot_Sprites

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,[SM7_Lines]
;inc ebx
 mov dl,0x10
 call Plot_Sprites

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,[SM7_Lines]
;inc ebx
 mov dl,0x20
 call Plot_Sprites

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,[SM7_Lines]
;inc ebx
 mov dl,0x30
 call Plot_Sprites
.no_sprites:

 add esp,byte SM7_Local_Bytes
 ret

;%1 = priority (0 = low, 1 = low/none, 2 = high)
%macro Render_Mode7_Background 1
%if %1 == 2
 test byte [SM7_Layers],2
 jz %%no_plot

 mov al,[M7_Unused]
 test al,al
 jz %%no_plot
%else
%if %1 == 0
 test byte [SM7_Layers],1
 jnz %%no_plot
%endif
%if %1 == 1
 test byte [SM7_Layers],1
 jz %%no_plot
%endif

 mov al,0
 mov [M7_Used],al
 mov [M7_Unused],al
%endif

 mov edi,[SM7_BaseDestPtr]
 add edi,[C_LABEL(SNES_Screen8)]

%if %1 == 2
 mov byte [Tile_priority_bit],0
%else
 mov byte [Tile_priority_bit],0x80
%endif

 mov ebp,256            ; Horizontal count
 mov edx,0              ; First pixel

%if %1 == 1
 mov al,[SM7_Layers]
 test al,2
 jz %%no_extbg

 call dword [M7_Handler_EXTBG]
 jmp %%no_plot

%%no_extbg:
;Window clipping likely affects EXTBG (TM/TS bit 1 'BG2')...

 push edi

 xor ebp,ebp
 mov edi,C_LABEL(TableWinMode7_Main_EXTBG_Off)

 mov edx,C_LABEL(TableWinMainBG1)
 mov esi,C_LABEL(TableWinSubBG1)

 mov al,[C_LABEL(TM)]
 mov bl,[C_LABEL(TS)]
 and al,1
 jz %%no_merge_sub
 and bl,al
 jz %%no_merge_main

 call C_LABEL(Intersect_Window_Area_OR)

 mov esi,C_LABEL(TableWinMode7_Main_EXTBG_Off)
 jmp %%got_bands

%%no_merge_main:
 mov esi,edx
%%no_merge_sub:
%%got_bands:
 mov al,[Win_Count+esi]
 test al,al
 jz .done

 mov edi,[esp]
 push eax
 push esi

;mov [R8x8_Runs_Left],eax
;mov [R8x8_Output],edi
;mov [R8x8_RunListPtr],esi
 xor edx,edx
;mov [R8x8R_Plotter],ecx    ;renderer
 mov dl,[Win_Bands+esi]

 xor ecx,ecx
 mov cl,[Win_Bands+esi+1]
 sub cl,dl
 setz ch

 dec al
 mov ebp,ecx
 je .last_run

.not_last_run:
;mov [R8x8_Runs_Left],al
 mov [esp+4],al
 call dword [M7_Handler]

;mov esi,[R8x8_RunListPtr]
 mov esi,[esp]
;mov edi,[R8x8_Output]
 mov edi,[esp+8]
 xor edx,edx
 xor ecx,ecx
 mov dl,[Win_Bands+esi+2]

 mov cl,[Win_Bands+esi+3]
 add esi,byte 2
 sub cl,dl
;mov [R8x8_RunListPtr],esi
 mov [esp],esi
 mov ebp,ecx

;mov al,[R8x8_Runs_Left]
 mov al,[esp+4]
 dec al
 jne .not_last_run
.last_run:
 call dword [M7_Handler]

 add esp,byte 8
.done:
 add esp,byte 4
%else
 call dword [M7_Handler_EXTBG]
%endif
%%no_plot:
%endmacro

.background_on:
 and ah,3
 or al,ah
 mov [SM7_Layers],al

 call Recalc_Mode7

 jmp .first_line

.next_line:
 inc dword [SM7_Current_Line]

.first_line:
 mov edx,[SM7_Current_Line]

 ; Handle vertical mosaic
 mov al,[MosaicBG1]
 test al,al
 jz .no_mosaic
 mov eax,[Mosaic_Size_Select]
 mov dl,[C_LABEL(MosaicLine)+edx+eax]
.no_mosaic:
 ; End vertical mosaic

 mov al,[C_LABEL(M7SEL)]
 test al,2
 jz .no_flip_y

 xor edx,-1
 add edx,256
.no_flip_y:

 mov ecx,[Mode7_VY]
 mov ebx,[C_LABEL(M7B)]
 add edx,ecx
 imul ebx,edx
 imul edx,[C_LABEL(M7D)]
 mov ecx,[Mode7_AHX]
 mov esi,[Mode7_CHXY]
 add ebx,ecx
 add edx,esi

 test al,1
 jz .no_flip_x

 mov ecx,[C_LABEL(M7A)]
 mov esi,[C_LABEL(M7C)]
 sub ebx,ecx
 sub edx,esi
 shl ecx,8
 shl esi,8
 add ebx,ecx
 add edx,esi
.no_flip_x:

 mov [Mode7_Line_X],ebx
 mov [Mode7_Line_Y],edx


 mov edi,[C_LABEL(SNES_Screen8)]    ; (256+16)*(240+1) framebuffer
 ; Clear the framebuffer
 mov ebx,[SM7_BaseDestPtr]
 mov ebp,1
 add edi,ebx

 ; Clear the framebuffer
 call C_LABEL(Clear_Scanlines_Preload)

 Render_Mode7_Background 0

 test byte [SM7_Layers],0x10
 jz .no_sprites_0

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,1
;inc ebx
 mov dl,0x00
 call Plot_Sprites
.no_sprites_0:

 Render_Mode7_Background 1

 test byte [SM7_Layers],0x10
 jz .no_sprites_1

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,1
;inc ebx
 mov dl,0x10
 call Plot_Sprites
.no_sprites_1:

 Render_Mode7_Background 2

 test byte [SM7_Layers],0x10
 jz .no_sprites_23

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,1
;inc ebx
 mov dl,0x20
 call Plot_Sprites

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,1
;inc ebx
 mov dl,0x30
 call Plot_Sprites
.no_sprites_23:

 test byte [SM7_Layers+1],0x10
 jz .no_sprites_alt

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,1
;inc ebx
 mov dl,0x00
 call Plot_Sprites

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,1
;inc ebx
 mov dl,0x10
 call Plot_Sprites

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,1
;inc ebx
 mov dl,0x20
 call Plot_Sprites

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,1
;inc ebx
 mov dl,0x30
 call Plot_Sprites
.no_sprites_alt:

 mov edi,[SM7_BaseDestPtr]
 add edi,GfxBufferLinePitch
 dec dword [SM7_Lines]
 mov [SM7_BaseDestPtr],edi  ; Point screen to next line
 jnz SCREEN_MODE_7.next_line

 add esp,byte SM7_Local_Bytes
 ret

%macro SIGN_EXTEND 2 ;reg,bits
 and (%1),BITMASK(0,(%2) - 1)
 xor (%1),BIT((%2) - 1)
 sub (%1),BIT((%2) - 1)
%endmacro

%macro SIGN_EXTEND_ALT 4 ;reg,reg2,bits,bit
 mov %2,%1
 and %1,BIT(%4)
 and %2,BITMASK(0,(%3) - 1)
 xor %1,BIT(%4)
 sar %1,(%4) - (%3)
 sub %2,BIT(%3)
 add %1,%2
%endmacro

Recalc_Mode7:
 mov dl,[Redo_M7]
 and dl,0x05    ; Need to do any recalculating?
 jz .end_recalc_ac

 mov al,[C_LABEL(M7SEL)]
 shl al,8
 mov ebx,[C_LABEL(M7A)]
 mov eax,[C_LABEL(M7C)]
 sbb edx,edx
 xor ebx,edx
 xor eax,edx
 and edx,byte 1
 add ebx,edx
 add eax,edx
 mov [C_LABEL(M7A_X)],ebx
 mov [C_LABEL(M7C_X)],eax

 mov dl,[MosaicBG1]
 test dl,dl
 jz .end_recalc_ac

 imul ebx,[Mosaic_Size]
 imul eax,[Mosaic_Size]
 mov [C_LABEL(M7A_XM)],ebx
 mov [C_LABEL(M7C_XM)],eax

.end_recalc_ac:
 mov dl,[Redo_M7]
 and dl,0xF5    ; Need to do any recalculating?
 jz .end_recalc

 test dl,0xA0   ; Recalculate V or Y?
 jz .end_recalc_vy

 mov eax,[C_LABEL(BG1VOFS)]
 shl eax,(32 - 13)
 mov edi,[C_LABEL(M7Y)]
 shl edi,(32 - 13)
 sar eax,(32 - 13)
 sar edi,(32 - 13)
;mov [C_LABEL(M7V_13)],eax
 sub eax,edi        ;(V - Y)
 mov [C_LABEL(M7Y_13)],edi
;there are only 11 significant result bits - a hidden sign bit (13) and the
;low 10 result bits
 SIGN_EXTEND_ALT eax,ecx,10,13

 mov [Mode7_VY],eax ;(V - Y)

.end_recalc_vy:
 test dl,0x75   ; Recalculate A, C, H, X, or Y?
 jz .end_recalc

;test dl,0x50   ; Recalculate H or X?
;jnz .recalc_hx
 mov eax,[C_LABEL(BG1HOFS)]
 shl eax,(32 - 13)
 mov edi,[C_LABEL(M7X)]
 shl edi,(32 - 13)
 sar eax,(32 - 13)
 sar edi,(32 - 13)
;mov [C_LABEL(M7H_13)],eax
 sub eax,edi        ;(H - X)
;mov [C_LABEL(M7X_13)],edi
;there are only 11 significant result bits - a hidden sign bit (13) and the
;low 10 result bits
 SIGN_EXTEND_ALT eax,ecx,10,13

 test dl,0x51   ; Recalculate A, H, or X?
 jz .recalc_c

 push eax
;mov ebx,[C_LABEL(M7X_13)]
 mov ebx,edi
 imul eax,[C_LABEL(M7A)]
 shl ebx,8
 add eax,ebx
 mov [Mode7_AHX],eax    ;A * (H - X) + (X << 8)
 pop eax
 test dl,0x74   ; Recalculate C, H, X, or Y?
 jz  .end_recalc

.recalc_c:
 mov ebx,[C_LABEL(M7Y_13)]
 imul eax,[C_LABEL(M7C)]
 shl ebx,8
 add eax,ebx
 mov [Mode7_CHXY],eax   ;C * (H - X) + (Y << 8)

.end_recalc:
 mov byte [Redo_M7],0   ; Done with recalculating
 ret

;%1 = mode, %2 = priority, %3 = label
%macro M7_Generate_Handler 3
ALIGNC
%3:
 mov eax,[Mode7_Line_X]
 mov ebx,[Mode7_Line_Y]

 mov cl,[MosaicBG1]
 add edi,edx
 test cl,cl
 jnz %3_Mosaic

 mov ecx,[C_LABEL(M7A_X)]
 imul ecx,edx
 imul edx,[C_LABEL(M7C_X)]
 add eax,ecx
 add ebx,edx

 mov ecx,[C_LABEL(M7A_X)]
 mov esi,[C_LABEL(M7C_X)]
 jmp .first_pixel

M7_HANDLE_%1 %2,0

ALIGNC
%3_Mosaic:
 mov esi,[Mosaic_Size_Select]
 xor ecx,ecx
 mov cl,[C_LABEL(MosaicLine)+edx+esi]
 mov dl,[C_LABEL(MosaicCount)+edx+esi]
 mov esi,[C_LABEL(M7A_X)]
 imul esi,ecx
 imul ecx,[C_LABEL(M7C_X)]
 add eax,esi
 add ebx,ecx

 mov ecx,[C_LABEL(M7A_XM)]
 mov esi,[C_LABEL(M7C_XM)]
 push ecx
 mov ecx,edx
 jmp .check_partial

M7_HANDLE_%1 %2,1
%endmacro

;%1 = mode
%macro M7_Generate_Handlers 1
;No priority
M7_Generate_Handler %1, 0, M7_%1

;EXTBG
M7_Generate_Handler %1, 1, M7P_%1
%endmacro

;ebp = pixel count
;eax,ebx = X,Y
;X + M7A, Y + M7C

;%1 = priority, %2 = mosaic
%macro M7_HANDLE_REPEAT 2
.pixel_loop:
 add eax,ecx
 add ebx,esi
.first_pixel:
%if %2
;ecx = max repetition count of first pixel from MosaicSize lookup
 mov ecx,[Mosaic_Size]
.check_partial:
 cmp ebp,ecx
 ja .partial
 mov ecx,ebp
.partial:
 sub ebp,ecx
 push ebp
 mov ebp,ecx
%endif

 push eax
 push ebx

;before:
;eax = X offset
;ebx = Y offset
;during:
;ecx = (eax >> 8) & 7
;edx = (ebx >> 8) & 7
;ecx = ecx + edx * 8
;eax = (eax >> 11) & 0x7F
;ebx = (ebx >> 3) & (0x7F << 8)
;eax = ebx + eax * 2
;after:
;eax = X tile
;ebx = Y tile
;ecx = X offset in tile
;edx = Y offset in tile
 mov ecx,eax
 mov edx,ebx

; Convert Screen X,Y location to SNES Pic location

 ; Assumes eax is X coord 0-1023, ebx is Y 0-1023
 ; Tile Position*128 (words) cos thats width of map
 shr ebx,3
 and eax,0x7F << 11
 shr eax,10             ; Screen map X offset
 and ebx,0x7F << 8      ; Screen map Y offset
 shr edx,4
 and ecx,7 << 8    ; Get pixel shift within tile
 shr ecx,7
 and edx,byte 7 << 4
 add ecx,edx    ; Add X+Y offsets together
 mov dl,[C_LABEL(VRAM)+eax+ebx] ; Got Tile Number

 shl edx,7          ; Get offset to tile data

%if %1
 mov al,[Tile_priority_bit]
 mov cl,[C_LABEL(VRAM)+edx+ecx+1]   ; Add X+Y offset
 xor al,cl

 and cl,0x7F
%else
 mov cl,[C_LABEL(VRAM)+edx+ecx+1]   ; Add X+Y offset
 test cl,cl
%endif
 jz .no_pixel

%if %1
 test al,al
 jns .bad_priority
%endif

%if %2
.again:
 mov [edi],cl
 inc edi
 dec ebp
 jnz .again
%else
 mov [edi],cl
%endif

%if %1
 mov [M7_Used],cl
%endif

.no_pixel:
 pop ebx
 pop eax
%if %2
 mov ecx,[esp+4]
 add edi,ebp
 pop ebp

 test ebp,ebp
%else
 mov ecx,[C_LABEL(M7A_X)]

 inc edi
 dec ebp
%endif

 jnz .pixel_loop

%if %2
 add esp,byte 4
%endif

 ret

%if %1
ALIGNC
.bad_priority:
 mov al,0xFF
 pop ebx
 mov [M7_Unused],al
 pop eax
%if %2
 mov ecx,[esp+4]
 add edi,ebp
 pop ebp

 test ebp,ebp
%else
 mov ecx,[C_LABEL(M7A_X)]

 inc edi
 dec ebp
%endif
 jnz .pixel_loop

%if %2
 add esp,byte 4
%endif

 ret
%endif

%endmacro

; New for v0.16, tile 0 repeat support
;%1 = priority, %2 = mosaic
%macro M7_HANDLE_CHAR0 2
.pixel_loop:
 add eax,ecx
 add ebx,esi
.first_pixel:
%if %2
 mov ecx,[Mosaic_Size]
.check_partial:
 cmp ebp,ecx
 ja .partial
 mov ecx,ebp
.partial:
 sub ebp,ecx
 push ebp
 mov ebp,ecx
%endif

 cmp eax,0x3FFFF    ; If outside screen range we use tile 0
 ja .use_tile_0
 cmp ebx,0x3FFFF
 ja .use_tile_0

; Convert Screen X,Y location to SNES Pic location

 ; Assumes eax is X coord 0-1023, bbx is Y 0-1023
 push eax
 push ebx

 mov ecx,eax
 mov edx,ebx

; Convert Screen X,Y location to SNES Pic location

 ; Assumes eax is X coord 0-1023, ebx is Y 0-1023
 shr ecx,7
 and eax,0x7F << 11
 shr edx,4
 and ebx,0x7F << 11
 shr eax,10     ; Get Tile Position (in 128 by 128 map)
 and ecx,byte 7 << 1    ; Get pixel shift within tile
 shr ebx,3      ; Tile Position*128 (words) cos thats width of map
 and edx,byte 7 << 4
 add ecx,edx    ; Add X+Y offsets together
 mov dl,[C_LABEL(VRAM)+eax+ebx] ; Got Tile Number
    
 shl edx,7          ; Get offset to tile data

%if %1
 mov al,[Tile_priority_bit]
 mov cl,[C_LABEL(VRAM)+edx+ecx+1]   ; Add X+Y offset
 xor al,cl

 and cl,0x7F
%else
 mov cl,[C_LABEL(VRAM)+edx+ecx+1]   ; Add X+Y offset
 test cl,cl
%endif
 jz .no_pixel

%if %1
 test al,al
 jns .bad_priority
%endif

%if %2
.again:
 mov [edi],cl
 inc edi
 dec ebp
 jnz .again
%else
 mov [edi],cl
%endif

%if %1
 mov [M7_Used],cl
%endif

.no_pixel:
 pop ebx
 pop eax
%if %2
 mov ecx,[esp+4]
 add edi,ebp
 pop ebp

 test ebp,ebp
 jnz .pixel_loop
%else
 mov ecx,[C_LABEL(M7A_X)]

 inc edi
 dec ebp
 jnz .pixel_loop
%endif

%if %2
 add esp,byte 4
%endif

 ret

%if %1
ALIGNC
.bad_priority:
 mov al,0xFF
 pop ebx
 mov [M7_Unused],al
 pop eax
%if %2
 mov ecx,[esp+4]
 add edi,ebp
 pop ebp

 test ebp,ebp
%else
 mov ecx,[C_LABEL(M7A_X)]

 inc edi
 dec ebp
%endif
 jnz .pixel_loop

%if %2
 add esp,byte 4
%endif

 ret
%endif

ALIGNC
.use_tile_0:
 mov ecx,eax
 mov edx,ebx

; Convert Screen X,Y location to SNES Pic location

 ; Assumes eax is X coord 0-1023, ebx is Y 0-1023
 shr ecx,7
 and edx,7 << 8
 shr edx,4
 and ecx,byte 7 << 1    ; Get pixel shift within tile
    
%if %1
 mov dl,[C_LABEL(VRAM)+edx+ecx+1]   ; Add X+Y offset
 mov cl,[Tile_priority_bit]
 xor cl,dl

 and dl,0x7F
%else
 mov dl,[C_LABEL(VRAM)+edx+ecx+1]   ; Add X+Y offset
 test dl,dl
%endif
 jz .no_pixel_2

%if %1
 test cl,cl
 jns .bad_priority
%endif

%if %2
.t0_again:
 mov [edi],dl
 inc edi
 dec ebp
 jnz .t0_again
%else
 mov [edi],dl
%endif

%if %1
 mov [M7_Used],dl
%endif

.no_pixel_2:
%if %2
 mov ecx,[esp+4]
 add edi,ebp
 pop ebp

 test ebp,ebp
%else
 mov ecx,[C_LABEL(M7A_X)]

 inc edi
 dec ebp
%endif

 jnz .pixel_loop

%if %2
 add esp,byte 4
%endif

 ret

%endmacro

;%1 = priority, %2 = mosaic
%macro M7_HANDLE_CLIP 2
.pixel_loop:
 add eax,ecx
 add ebx,esi
.first_pixel:
%if %2
 mov ecx,[Mosaic_Size]
.check_partial:
 cmp ebp,ecx
 ja .partial
 mov ecx,ebp
.partial:
 sub ebp,ecx
 push ebp
 mov ebp,ecx
 mov ecx,[esp+4]
%endif

 cmp eax,0x3FFFF    ; If outside screen range we simply skip the pixel
 ja .pixel_covered
 cmp ebx,0x3FFFF
 ja .pixel_covered

; Convert Screen X,Y location to SNES Pic location

 ; Assumes eax is X coord 0-1023, ebx is Y 0-1023
 push eax
 push ebx

 mov ecx,eax
 mov edx,ebx

; Convert Screen X,Y location to SNES Pic location

 ; Assumes eax is X coord 0-1023, ebx is Y 0-1023
 shr ecx,7
 and eax,0x7F << 11
 shr edx,4
 and ebx,0x7F << 11
 shr eax,10     ; Get Tile Position (in 128 by 128 map)
 and ecx,byte 7 << 1    ; Get pixel shift within tile
 shr ebx,3      ; Tile Position*128 (words) cos thats width of map
 and edx,byte 7 << 4
 add ecx,edx    ; Add X+Y offsets together
 mov dl,[C_LABEL(VRAM)+eax+ebx] ; Got Tile Number
    
 shl edx,7          ; Get offset to tile data

%if %1
 mov al,[Tile_priority_bit]
 mov cl,[C_LABEL(VRAM)+edx+ecx+1]   ; Add X+Y offset
 xor al,cl

 and cl,0x7F
%else
 mov cl,[C_LABEL(VRAM)+edx+ecx+1]   ; Add X+Y offset
 test cl,cl
%endif
 jz .no_pixel

%if %1
 test al,al
 jns .bad_priority
%endif

%if %2
.again:
 mov [edi],cl
 inc edi
 dec ebp
 jnz .again
%else
 mov [edi],cl
%endif

%if %1
 mov [M7_Used],cl
%endif

.no_pixel:
 pop ebx
 pop eax

%if %2
 mov ecx,[esp+4]
%else
 mov ecx,[C_LABEL(M7A_X)]
%endif

%if %1 == 0
.pixel_covered:
%endif

%if %2
 add edi,ebp
 pop ebp

 test ebp,ebp
 jnz .pixel_loop
%else
 inc edi

 dec ebp
 jnz .pixel_loop
%endif

%if %2
 add esp,byte 4
%endif

 ret

%if %1
ALIGNC
.bad_priority:
 mov al,0xFF
 pop ebx
 mov [M7_Unused],al
 pop eax
%if %2
 mov ecx,[esp+4]
%else
 mov ecx,[C_LABEL(M7A_X)]
%endif

.pixel_covered:

%if %2
 add edi,ebp
 pop ebp

 test ebp,ebp
%else
 inc edi

 dec ebp
%endif
 jnz .pixel_loop

%if %2
 add esp,byte 4
%endif

 ret
%endif

%endmacro

M7_Generate_Handlers REPEAT
M7_Generate_Handlers CHAR0
M7_Generate_Handlers CLIP

ALIGNC
EXPORT Reset_Mode_7
 ; Set eax to 0, as we're setting most everything to 0...
 xor eax,eax

 mov [C_LABEL(M7SEL)],al
 mov byte [Redo_M7],0xFF
 mov byte [M7_Last_Write],al
 mov dword [M7_Handler],M7_REPEAT
 mov dword [M7_Handler_EXTBG],M7P_REPEAT
 mov byte [Redo_16x8],0
 mov [MPY],eax
 mov [C_LABEL(M7A)],eax
 mov [C_LABEL(M7B)],eax
 mov [C_LABEL(M7C)],eax
 mov [C_LABEL(M7D)],eax
 mov [C_LABEL(M7X_13)],eax
 mov [C_LABEL(M7Y_13)],eax
;mov [C_LABEL(M7H_13)],eax
;mov [C_LABEL(M7V_13)],eax
 mov [C_LABEL(M7X)],eax
 mov [C_LABEL(M7Y)],eax
 mov [C_LABEL(M7H)],eax
 mov [C_LABEL(M7V)],eax

 ret

Do_16x8_Multiply:
 push ebx
 movsx ebx,byte [C_LABEL(M7B)+1]
 mov byte [Redo_16x8],0
 imul ebx,[C_LABEL(M7A)]    ; I think signed is used makes most sense!
 mov [MPY],ebx
 mov al,[edx]
 pop ebx
 ret

ALIGNC
EXPORT SNES_R2134 ; MPYL
 mov edx,MPYL
 cmp byte [Redo_16x8],0
 jnz Do_16x8_Multiply
 mov al,[edx]
 mov [Last_Bus_Value_PPU1],al
 ret

ALIGNC
EXPORT SNES_R2135 ; MPYM
 mov edx,MPYM
 cmp byte [Redo_16x8],0
 jnz Do_16x8_Multiply
 mov al,[edx]
 mov [Last_Bus_Value_PPU1],al
 ret

ALIGNC
EXPORT SNES_R2136 ; MPYH
 mov edx,MPYH
 cmp byte [Redo_16x8],0
 jnz Do_16x8_Multiply
 mov al,[edx]
 mov [Last_Bus_Value_PPU1],al
 ret

ALIGNC
EXPORT SNES_W_M7H ; 210D - handle mode 7 register update
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [C_LABEL(M7H)],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [C_LABEL(M7H)],ebx
 mov dl,0x40    ; Recalculate H
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W_M7V ; 210E - handle mode 7 register update
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [C_LABEL(M7V)],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [C_LABEL(M7V)],ebx
 mov dl,0x80    ; Recalculate V
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211A ; M7SEL   ; New for 0.12
 cmp al,[C_LABEL(M7SEL)]
 je .no_change
 UpdateDisplay  ;*
 push ebx
 push eax
 mov [C_LABEL(M7SEL)],al

 shl al,8
 mov ebx,[C_LABEL(M7A)]
 mov eax,[C_LABEL(M7C)]
 sbb edx,edx
 xor ebx,edx
 xor eax,edx
 and edx,byte 1
 add ebx,edx
 add eax,edx
 mov dl,[C_LABEL(M7SEL)]
 mov [C_LABEL(M7A_X)],ebx

 shr edx,6
 mov [C_LABEL(M7C_X)],eax

 and edx,3
 mov eax,[M7_Handler_Table+edx*4]
 mov [M7_Handler],eax
 mov ebx,[M7_Handler_Table+edx*4+16]
 pop eax
 mov [M7_Handler_EXTBG],ebx
 pop ebx

.no_change:
 ret

ALIGNC
EXPORT SNES_W211B ; M7A
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [C_LABEL(M7A)],ebx
 je .no_change

 UpdateDisplay  ;*M7
 ; Used for matrix render and 16-bit M7A * 8-bit = 24-bit multiply
 mov [C_LABEL(M7A)],ebx
 mov dl,0x01    ; Recalculate A
 or [Redo_M7],dl
 mov byte [Redo_16x8],-1
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211C ; M7B
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [C_LABEL(M7B)],ebx
 je .no_change

 UpdateDisplay  ;*M7
 ; Used for matrix render and 16-bit * 8-bit M7B high byte = 24-bit multiply
 mov [C_LABEL(M7B)],ebx
 mov dl,0x02    ; Recalculate B
 or [Redo_M7],dl
 mov byte [Redo_16x8],-1
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211D ; M7C
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [C_LABEL(M7C)],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [C_LABEL(M7C)],ebx
 mov dl,0x04    ; Recalculate C
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211E ; M7D
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [C_LABEL(M7D)],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [C_LABEL(M7D)],ebx
 mov dl,0x08    ; Recalculate D
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211F ; M7X
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [C_LABEL(M7X)],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [C_LABEL(M7X)],ebx
 mov dl,0x10    ; Recalculate X
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W2120 ; M7Y
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [C_LABEL(M7Y)],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [C_LABEL(M7Y)],ebx
 mov dl,0x20    ; Recalculate Y
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
