%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

; Mode 7 matrix rendering / hardware port emulation.

%include "misc.inc"
%include "ppu/sprites.inc"
%include "ppu/screen.inc"
%include "ppu/ppu.inc"

section .text
EXPORT_C mode7_start

;%define old_sprites
EXTERN Ready_Line_Render,BaseDestPtr
EXTERN_C SNES_Screen8
EXTERN_C MosaicLine
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


EXPORT_C M7A    ,skipl
EXPORT_C M7B    ,skipl
EXPORT_C M7C    ,skipl
EXPORT_C M7D    ,skipl
EXPORT_C M7X_13 ,skipl
EXPORT_C M7Y_13 ,skipl
EXPORT_C M7H_13 ,skipl
EXPORT_C M7V_13 ,skipl
EXPORT_C M7X    ,skipl
EXPORT_C M7Y    ,skipl

;M7A, M7C are taken from here to help handle X-flip
EXPORT_C M7A_X  ,skipl
EXPORT_C M7C_X  ,skipl

MPY:    skipl   ; Mode 7 multiplication result
MPYL equ MPY    ; Mode 7 multiplication result: low byte
MPYM equ MPY+1  ; Mode 7 multiplication result: middle byte
MPYH equ MPY+2  ; Mode 7 multiplication result: high byte

EXPORT M7_Handler,skipl
EXPORT M7_Handler_EXTBG,skipl
EXPORT_C M7SEL,skipb    ; ab0000yx  ab=mode 7 repetition info,y=flip vertical,x=flip horizontal
EXPORT Redo_M7,skipb    ; vhyxdcba
M7_Used:    skipb
M7_Unused:  skipb
Redo_16x8:  skipb

%define SM7_Local_Bytes 16
%define SM7_Current_Line esp+12
%define SM7_BaseDestPtr esp+8
%define SM7_Lines esp+4
%define SM7_Layers esp

%if 0
;Need to convert this into something sensible for mode 7 rendering

;Window clipping likely affects EXTBG (TM/TS bit 1 'BG2')...

 mov al,[R8x8_Clipped]
 test al,al
 jz .no_window_clip

 mov al,[WSEL+edx]
 test al,8+2
 jpe .no_window_clip

 LOAD_WIN_TABLE 2
 test al,2
 jz .single_window_clip_2
 LOAD_WIN_TABLE 1
 shl al,2
.single_window_clip_2:
 
 test al,4
 mov al,[Win_Count_Out+edx]
 jz .draw_outside
 mov al,[Win_Count_In+edx]
 add edx,byte Win_Bands_In - Win_Bands_Out
.draw_outside:

 test al,al
 jz .done

 push edi
 push edx
 push ebx       ;vertical screen map address
 xor ebx,ebx
 push ecx       ;renderer
 mov bl,[Win_Bands_Out+edx]

 xor ecx,ecx
 mov cl,[Win_Bands_Out+edx+1]
 mov edx,[R8x8_BG_Table+16]
 sub cl,bl
 setz ch

 push edx
 push ebx
 push ecx

 cmp al,1
 je .last_run

 call Render_8x8_Run
 mov edx,[esp+20]
 mov edi,[esp+24]
 xor ebx,ebx
 xor ecx,ecx
 mov bl,[Win_Bands_Out+edx+2]

 mov cl,[Win_Bands_Out+edx+3]
 mov edx,[esp+8]
 sub cl,bl

 mov [esp+4],ebx
 mov [esp],ecx
.last_run:
 call Render_8x8_Run
 add esp,byte 28
 jmp short .done

.no_window_clip:
 push ebx       ;vertical screen map address
 push ecx       ;renderer
 push edx
 push byte 0    ;first pixel
 push dword 256 ;pixel count
 call Render_8x8_Run
 add esp,byte 20

.done:
%endif

section .text
ALIGNC
EXPORT_C SCREEN_MODE_7

 push ebx
 push edi
 mov al,[C_LABEL(TM)]
 mov ah,[C_LABEL(TS)]
EXTERN_C Layer_Disable_Mask
 and al,[C_LABEL(Layer_Disable_Mask)]
 and ah,[C_LABEL(Layer_Disable_Mask)]
 push ebp
 push eax

 mov eax,[SM7_Layers]
 test al,3
 jnz .background_main

 ;Hack in sub screen mode 7 if it's enabled
 and ah,3
 jz .background_off

 or al,ah
 mov [SM7_Layers],al

.background_main:
 and eax,byte 1
 jnz near .background_on

 ; we only reach here when bit 0 clear, bit 1 set
 test byte [C_LABEL(SETINI)],0x40
 jnz near .background_on
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
 test byte [C_LABEL(SETINI)],0x40
 jz %%no_plot

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
 mov al,[C_LABEL(SETINI)]
 test al,0x40
 jz %%no_extbg

 mov al,[SM7_Layers]
 test al,2
 jz %%no_extbg

 call dword [M7_Handler_EXTBG]
 jmp short %%no_plot

%%no_extbg:
 call dword [M7_Handler]
%else
 call dword [M7_Handler_EXTBG]
%endif
%%no_plot:
%endmacro

.background_on:
 call Recalc_Mode7

 jmp short .first_line

.next_line:
 inc dword [SM7_Current_Line]

.first_line:
 mov edx,[SM7_Current_Line]
%if 1
 ; Handle vertical mosaic
 mov al,[MosaicBG1]
 test al,al
 jz .no_mosaic
 mov eax,[Mosaic_Size_Select]
 mov dl,[C_LABEL(MosaicLine)+edx+eax]
.no_mosaic:
 ; End vertical mosaic
%endif

 mov al,[C_LABEL(M7SEL)]
 test al,2
 jz .no_flip_y

 xor edx,-1
 add edx,262
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

 test dword [SM7_Layers],0x1010
 jz .no_sprites_0

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,1
;inc ebx
 mov dl,0x00
 call Plot_Sprites
.no_sprites_0:

 Render_Mode7_Background 1

 test dword [SM7_Layers],0x1010
 jz .no_sprites_1

 mov ebx,[SM7_Current_Line]
 mov edi,[SM7_BaseDestPtr]
 mov ebp,1
;inc ebx
 mov dl,0x10
 call Plot_Sprites
.no_sprites_1:

 Render_Mode7_Background 2

 test dword [SM7_Layers],0x1010
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

 mov edi,[SM7_BaseDestPtr]
 add edi,GfxBufferLinePitch
 dec dword [SM7_Lines]
 mov [SM7_BaseDestPtr],edi  ; Point screen to next line
 jnz near C_LABEL(SCREEN_MODE_7).next_line

 add esp,byte SM7_Local_Bytes
 ret

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

.end_recalc_ac:
 mov dl,[Redo_M7]
 and dl,0xF5    ; Need to do any recalculating?
 jz near .end_recalc

 test dl,0xA0   ; Recalculate V or Y?
 jz .end_recalc_vy

 mov eax,[C_LABEL(BG1VOFS)]
 shl eax,(32 - 13)
 mov edi,[C_LABEL(M7Y)]
 shl edi,(32 - 13)
 sar eax,(32 - 13)
 sar edi,(32 - 13)
;mov [C_LABEL(M7V_13)],eax
 sub eax,edi
 mov [C_LABEL(M7Y_13)],edi
 mov [Mode7_VY],eax  ;(V - Y)

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
 sub eax,edi
;mov [C_LABEL(M7X_13)],edi

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
 test cl,cl
 jnz near %3_Mosaic

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
 mov ecx,[C_LABEL(M7A_X)]
 mov esi,[C_LABEL(M7C_X)]
 imul ecx,[Mosaic_Size]
 imul esi,[Mosaic_Size]
 push ecx
%if 0
;note - precalc mosaic A_X/C_X if in use
 jb .check_partial
%endif
 jmp .first_pixel

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
 jnz near .pixel_loop

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
 ja near .use_tile_0
 cmp ebx,0x3FFFF
 ja near .use_tile_0

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
 jnz near .pixel_loop
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
 jnz near .pixel_loop

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

 jnz near .pixel_loop

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
 ja near .pixel_covered
 cmp ebx,0x3FFFF
 ja near .pixel_covered

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
 jnz near .pixel_loop
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
 jnz near .pixel_loop

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
EXPORT_C Reset_Mode_7
 ; Set eax to 0, as we're setting most everything to 0...
 xor eax,eax

 mov [C_LABEL(M7SEL)],al
 mov byte [Redo_M7],0xFF
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
 ret

ALIGNC
EXPORT SNES_R2135 ; MPYM
 mov edx,MPYM
 cmp byte [Redo_16x8],0
 jnz Do_16x8_Multiply
 mov al,[edx]
 ret

ALIGNC
EXPORT SNES_R2136 ; MPYH
 mov edx,MPYH
 cmp byte [Redo_16x8],0
 jnz Do_16x8_Multiply
 mov al,[edx]
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
 mov [C_LABEL(M7A_X)],ebx
 mov bl,[C_LABEL(M7SEL)]
 mov [C_LABEL(M7C_X)],eax

 shr ebx,6
 and ebx,3
 mov eax,[M7_Handler_Table+ebx*4]
 mov [M7_Handler],eax
 mov ebx,[M7_Handler_Table+ebx*4+16]
 pop eax
 mov [M7_Handler_EXTBG],ebx
 pop ebx

.no_change:
 ret

ALIGNC
EXPORT SNES_W211B ; M7A
 UpdateDisplay  ;*M7
 ; Used for matrix render and 16-bit M7A * 8-bit = 24-bit multiply
 push eax
 mov ah,al
 mov al,[C_LABEL(M7A)+1]
 cwde
 mov [C_LABEL(M7A)],eax
 mov al,0x01    ; Recalculate A
 or [Redo_M7],al
 mov byte [Redo_16x8],-1
 pop eax
 ret

ALIGNC
EXPORT SNES_W211C ; M7B
 UpdateDisplay  ;*M7
 ; Used for matrix render and 16-bit * 8-bit M7B high byte = 24-bit multiply
 push eax
 mov ah,al
 mov al,[C_LABEL(M7B)+1]
 cwde
 mov [C_LABEL(M7B)],eax
 mov al,0x02    ; Recalculate B
 or [Redo_M7],al
 mov byte [Redo_16x8],-1
 pop eax
 ret

ALIGNC
EXPORT SNES_W211D ; M7C
 UpdateDisplay  ;*M7
 push eax
 mov ah,al
 mov al,[C_LABEL(M7C)+1]
 cwde
 mov [C_LABEL(M7C)],eax
 mov al,0x04    ; Recalculate C
 or [Redo_M7],al
 pop eax
 ret

ALIGNC
EXPORT SNES_W211E ; M7D
 UpdateDisplay  ;*M7
 push eax
 mov ah,al
 mov al,[C_LABEL(M7D)+1]
 cwde
 mov [C_LABEL(M7D)],eax
 mov al,0x08    ; Recalculate D
 or [Redo_M7],al
 pop eax
 ret

ALIGNC
EXPORT SNES_W211F ; M7X
 UpdateDisplay  ;*M7
 push eax
 mov ah,al
 mov al,[C_LABEL(M7X)+1]
 mov [C_LABEL(M7X)],ax

;shl eax,0x13
;sar eax,0x13
;mov [C_LABEL(M7X_13)],eax
 mov al,0x10    ; Recalculate X
 or [Redo_M7],al
 pop eax
 ret

ALIGNC
EXPORT SNES_W2120 ; M7Y
 UpdateDisplay  ;*M7
 push eax
 mov ah,al
 mov al,[C_LABEL(M7Y)+1]
 mov [C_LABEL(M7Y)],ax

;shl eax,0x13
;sar eax,0x13
;mov [C_LABEL(M7Y_13)],eax
 mov al,0x20    ; Recalculate Y
 or [Redo_M7],al
 pop eax
 ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
