%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

;
; Sprite render functions
;
; In all the sprite renderers...
;  eax = (internal)
;  ebx = (internal)
;  cl  = sprite counter for priority (internal)
;  ch  = sprite counter for set      (internal)
;  dl  = sprite priority identifier  (input)
;  dh  = (internal)
;  esi = current sprite              (internal)
;  edi = (internal)
;
; OAM decoder generates table with plot data per sprite tile-line
;  (X position, line-in-tile cache address, palette, X-flip, priority for
;  each sprite scanline, and time/range flags for each scanline)
; 14b address, 2bit XYflip, 3bit palette, 2bit priority, 9bit X pos
; (may pack priority, palette, X-flip, and bit 8 X pos in 1b)
; 4b/sprite line
; 34 sprite lines/scanline max + count + time/range + priority + pri flag
;  (34 * 4b = 136b + 8b)
; count = total sprites/tiles, and total sprites only including last per
;  priority
; 239 lines * 145b = 34,416b (~33.61k)
; However, with this, other tables can be removed (OAM_*, 1,664b (1.625k))
; Plotters will be greatly simplified, with less redundant handling

;#define Profile_Recache_OAM
%define ALT_CLEAR

%define SNEeSe_ppu_sprites_asm

%include "misc.inc"
%include "clear.inc"
%include "ppu/tiles.inc"
%include "ppu/screen.inc"
%include "ppu/ppu.inc"

section .text
EXPORT_C sprites_text_start
section .data
EXPORT_C sprites_data_start
section .bss
EXPORT_C sprites_bss_start

EXTERN Ready_Line_Render,BaseDestPtr
EXTERN_C SNES_Screen8
EXTERN HVBJOY

section .data
ALIGND
palette_obj:
 dd 0x8F8F8F8F, 0x9F9F9F9F, 0xAFAFAFAF, 0xBFBFBFBF
 dd 0xCFCFCFCF, 0xDFDFDFDF, 0xEFEFEFEF, 0xFFFFFFFF

; Sprite offset tables moved to ScreenL.S
Sprite_Size_Table:
db  1, -7,  2,-15
db  1, -7,  4,-31
db  1, -7,  8,-63
db  2,-15,  4,-31
db  2,-15,  8,-63
db  4,-31,  8,-63
db  0,  0,  0,  0
db  0,  0,  0,  0

section .bss
ALIGNB
;Line counts when last OBJ of specified priority was added
EXPORT_C OAM_Count_Priority,skipl 240

;OBJ counts (low byte) and OBJ line counts (high byte)
EXPORT_C OAM_Count,skipw 240

;Time/range overflow flags
EXPORT_C OAM_TimeRange,skipb 240
;'Complex' priority in-use flags
EXPORT_C OAM_Low_Before_High,skipb 240
;Priorities for 'complex' priority detection
EXPORT_C OAM_Lowest_Priority,skipb 240
;Tail entry for ring buffers
EXPORT OAM_Tail,skipb 240

;239 ring buffers of 34 OBJ line descriptors (32-bit)
EXPORT_C OAM_Lines,skipl 34*239

; AAAA AAAA AAAA AAxx YXPP CCCX XXXX XXXX
;  A - OAM sprite line-in-tile address
;  YXPP CCC  - bits 1-7 of OAM attribute word
;  X - X position

ALIGNB
EXPORT_C OAM,skipb 512+32   ; Buffer for OAM
EXPORT SpriteCount,skipl
EXPORT_C HiSprite ,skipl
EXPORT_C HiSpriteCnt1,skipl ; First set size and bit offset
EXPORT_C HiSpriteCnt2,skipl ; Second set size and bit offset
EXPORT_C OBBASE,skipl   ; VRAM location of sprite tiles 00-FF
EXPORT_C OBNAME,skipl   ; VRAM location of sprite tiles 100-1FF
EXPORT_C OAMAddress,skipl
EXPORT_C OAMAddress_VBL,skipl   ; Restore this at VBL
EXPORT_C HiSpriteAddr,skipl     ; OAM address of sprite in 512b table
EXPORT_C HiSpriteBits,skipl     ; OAM address of sprite in 32b table
ALIGNB
EXPORT Sprite_Size_Current,skipl
EXPORT_EQU sprsize_small,Sprite_Size_Current
EXPORT_EQU sprlim_small,Sprite_Size_Current+1
EXPORT_EQU sprsize_large,Sprite_Size_Current+2
EXPORT_EQU sprlim_large,Sprite_Size_Current+3
EXPORT Redo_OAM,skipb
EXPORT SPRLatch   ,skipb    ; Sprite Priority Rotation latch flag
EXPORT_C OBSEL    ,skipb    ; sssnnxbb  sss=sprite size,nn=upper 4k address,bb=offset
EXPORT OAMHigh    ,skipb
EXPORT OAM_Write_Low,skipb
EXPORT Pixel_Allocation_Tag,skipb

section .text
%define PS_Local_Bytes   16
%define PS_Lines         esp+12
%define PS_BaseDestPtr   esp+8
%define PS_Current_Line  esp+4
%define PS_Priority      esp

ALIGNC
EXPORT Plot_Sprites
 dec ebx
 push ebp
 and edx,byte 0x30
 push edi
 push ebx
 push edx

%ifdef NO_EARLY_CLEAR
 mov ebx,[PS_Current_Line]
 mov ebp,1
 inc ebx
 call Clear_Lines
%endif

 mov ebx,[PS_Current_Line]
 mov edi,[PS_BaseDestPtr]
 mov edx,[PS_Priority]
 jmp short .first_line

ALIGNC
.next_line:
%ifdef NO_EARLY_CLEAR
 mov ebx,[PS_Current_Line]
 mov ebp,1
 add ebx,byte 2
 call Clear_Lines
%endif

 mov ebx,[PS_Current_Line]
 mov edi,[PS_BaseDestPtr]
 mov edx,[PS_Priority]
 inc ebx
 add edi,GfxBufferLinePitch
 mov [PS_Current_Line],ebx
 mov [PS_BaseDestPtr],edi

.first_line:
 and edx,byte 0x30
 shr edx,4
 mov cl,[C_LABEL(OAM_Count_Priority)+ebx*4+edx]
 shl edx,4

 test cl,cl
 jz near .check_line_count

 mov cl,[C_LABEL(OAM_Count)+ebx*2+1]
 mov al,[C_LABEL(OAM_Low_Before_High)+ebx]
 test al,al
 jnz near C_LABEL(Plot_Sprites_Low_Before_High).first_line

 xor eax,eax
 mov al,cl
 cmp cl,34
 jb .zero_head
 mov al,[OAM_Tail+ebx]
 test al,al
 jnz .zero_head
 mov al,34
.zero_head:
 shl ebx,4
 mov ch,cl
 mov esi,[PS_Current_Line]
 sub ch,al
 shl eax,2
 add ebx,esi
 sub cl,ch
 lea ebx,[C_LABEL(OAM_Lines)+eax+ebx*8-4]

.next_tile:
 mov dh,0x30
 mov eax,[ebx]
 and dh,ah
 sub ebx,byte 4
 cmp dh,dl      ; Check priority
 jne near .check_tile_count

 mov esi,eax
 mov edi,[PS_BaseDestPtr]
 shl esi,23
 add edi,[C_LABEL(SNES_Screen8)]
 sar esi,23
 add edi,esi    ; X-adjust

 mov esi,eax
 mov dl,ah
 shr esi,15
 and edx,byte 7*2   ; Get palette
 and esi,byte ~7    ; Tile line # address
 mov ebp,[palette_obj+edx*2]
 add esi,C_LABEL(TileCache4)

 add ah,ah
 js near .flip_x

 Plot_8_Paletted_Lines_noflip 0,esi,0

 mov dl,[PS_Priority]
 dec cl
 jnz near .next_tile
 jmp .check_count

ALIGNC
.flip_x:
 Plot_8_Paletted_Lines_Xflip 0,esi,0

 mov dl,[PS_Priority]

.check_tile_count:
 dec cl
 jnz near .next_tile

.check_count:
 add ebx,34*4
 add cl,ch
 mov ch,0
 jnz near .next_tile

.check_line_count:
 dec dword [PS_Lines]
 jnz near .next_line

.done:
 add esp,byte PS_Local_Bytes
 ret

ALIGNC
EXPORT_C Plot_Sprites_Low_Before_High
.first_line:
 xor eax,eax
 mov al,[OAM_Tail+ebx]
 shl ebx,4
 mov ch,al
 shl eax,2
 sub cl,ch
 add ebx,[PS_Current_Line]
 lea ebx,[C_LABEL(OAM_Lines)+eax+ebx*8]

.next_tile:
 mov dh,0x30
 mov eax,[ebx]
 and dh,ah
 add ebx,byte 4

 push ebx
 mov ebx,eax
 shl ebx,23
 push ecx
 mov edi,[PS_BaseDestPtr+8]
 sar ebx,23
 add edi,[C_LABEL(SNES_Screen8)]
 mov esi,eax

 cmp dh,dl      ; Check priority
 jnz near .bad_priority_plot

 mov dh,ah
 shr esi,15
 add edi,ebx        ; X-adjust
 shl dh,3           ; Palette
 and esi,byte ~7    ; Tile line # address
 or dh,0x8F
 add esi,C_LABEL(TileCache4)
 add ebx,DisplayZ+8

 add ah,ah
 mov ah,[Pixel_Allocation_Tag]
 js near .flip_x

 mov al,[esi]
 and al,dh
 jz .no_pixel_0

 mov ch,[ebx]
 test ch,ah
 jnz .no_pixel_0

 or ch,ah
 mov [edi],al
 mov [ebx],ch
.no_pixel_0:

 mov al,[esi + 4]
 and al,dh
 jz .no_pixel_4

 mov ch,[ebx + 4]
 test ch,ah
 jnz .no_pixel_4

 or ch,ah
 mov [edi + 4],al
 mov [ebx + 4],ch
.no_pixel_4:

 mov al,[esi + 1]
 and al,dh
 jz .no_pixel_1

 mov ch,[ebx + 1]
 test ch,ah
 jnz .no_pixel_1

 or ch,ah
 mov [edi + 1],al
 mov [ebx + 1],ch
.no_pixel_1:

 mov al,[esi + 5]
 and al,dh
 jz .no_pixel_5

 mov ch,[ebx + 5]
 test ch,ah
 jnz .no_pixel_5

 or ch,ah
 mov [edi + 5],al
 mov [ebx + 5],ch
.no_pixel_5:

 mov al,[esi + 2]
 and al,dh
 jz .no_pixel_2

 mov ch,[ebx + 2]
 test ch,ah
 jnz .no_pixel_2

 or ch,ah
 mov [edi + 2],al
 mov [ebx + 2],ch
.no_pixel_2:

 mov al,[esi + 6]
 and al,dh
 jz .no_pixel_6

 mov ch,[ebx + 6]
 test ch,ah
 jnz .no_pixel_6

 or ch,ah
 mov [edi + 6],al
 mov [ebx + 6],ch
.no_pixel_6:

 mov al,[esi + 3]
 and al,dh
 jz .no_pixel_3

 mov ch,[ebx + 3]
 test ch,ah
 jnz .no_pixel_3

 or ch,ah
 mov [edi + 3],al
 mov [ebx + 3],ch
.no_pixel_3:

 mov al,[esi + 7]
 and al,dh
 jz .no_pixel_7

 mov ch,[ebx + 7]
 test ch,ah
 jnz .no_pixel_7

 or ch,ah
 mov [edi + 7],al
 mov [ebx + 7],ch
.no_pixel_7:

 pop ecx
 pop ebx
 dec cl
 jnz near .next_tile
 jmp .check_tag

ALIGNC
.flip_x:
 mov al,[esi + 7]
 and al,dh
 jz .no_pixel_0_x

 mov ch,[ebx]
 test ch,ah
 jnz .no_pixel_0_x

 or ch,ah
 mov [edi],al
 mov [ebx],ch
.no_pixel_0_x:

 mov al,[esi + 3]
 and al,dh
 jz .no_pixel_4_x

 mov ch,[ebx + 4]
 test ch,ah
 jnz .no_pixel_4_x

 or ch,ah
 mov [edi + 4],al
 mov [ebx + 4],ch
.no_pixel_4_x:

 mov al,[esi + 6]
 and al,dh
 jz .no_pixel_1_x

 mov ch,[ebx + 1]
 test ch,ah
 jnz .no_pixel_1_x

 or ch,ah
 mov [edi + 1],al
 mov [ebx + 1],ch
.no_pixel_1_x:

 mov al,[esi + 2]
 and al,dh
 jz .no_pixel_5_x

 mov ch,[ebx + 5]
 test ch,ah
 jnz .no_pixel_5_x

 or ch,ah
 mov [edi + 5],al
 mov [ebx + 5],ch
.no_pixel_5_x:

 mov al,[esi + 5]
 and al,dh
 jz .no_pixel_2_x

 mov ch,[ebx + 2]
 test ch,ah
 jnz .no_pixel_2_x

 or ch,ah
 mov [edi + 2],al
 mov [ebx + 2],ch
.no_pixel_2_x:

 mov al,[esi + 1]
 and al,dh
 jz .no_pixel_6_x

 mov ch,[ebx + 6]
 test ch,ah
 jnz .no_pixel_6_x

 or ch,ah
 mov [edi + 6],al
 mov [ebx + 6],ch
.no_pixel_6_x:

 mov al,[esi + 4]
 and al,dh
 jz .no_pixel_3_x

 mov ch,[ebx + 3]
 test ch,ah
 jnz .no_pixel_3_x

 or ch,ah
 mov [edi + 3],al
 mov [ebx + 3],ch
.no_pixel_3_x:

 mov al,[esi]
 and al,dh
 jz .no_pixel_7_x

 mov ch,[ebx + 7]
 test ch,ah
 jnz .no_pixel_7_x

 or ch,ah
 mov [edi + 7],al
 mov [ebx + 7],ch
.no_pixel_7_x:

.check_tile_count:
 pop ecx
 pop ebx
 dec cl
 jnz near .next_tile

.check_tag:
 sub ebx,34*4
 add cl,ch
 mov ch,0
 jnz near .next_tile

 rol byte [Pixel_Allocation_Tag],1
 jnc .check_line_count

; Clear pixel allocation tag table
 mov edi,DisplayZ+8
 xor eax,eax
 mov ecx,256/32
 call Do_Clear

.check_line_count:
 dec dword [PS_Lines]
 jnz near Plot_Sprites.next_line

.done:
 add esp,byte PS_Local_Bytes
 ret

ALIGNC
.bad_priority_plot:
 mov dh,ah
 shr esi,15
 add edi,ebx        ; X-adjust
 shl dh,3           ; Palette
 and esi,byte ~7    ; Tile line # address
 or dh,0x8F
 add esi,C_LABEL(TileCache4)
 add ebx,DisplayZ+8

 add ah,ah
 mov ah,[Pixel_Allocation_Tag]
 js near .bad_priority_flip_x

 mov al,[esi]
 and al,dh
 jz .no_pixel_bp_0

 mov ch,[ebx]
 or ch,ah
 mov [ebx],ch
.no_pixel_bp_0:

 mov al,[esi + 4]
 and al,dh
 jz .no_pixel_bp_4

 mov ch,[ebx + 4]
 or ch,ah
 mov [ebx + 4],ch
.no_pixel_bp_4:

 mov al,[esi + 1]
 and al,dh
 jz .no_pixel_bp_1

 mov ch,[ebx + 1]
 or ch,ah
 mov [ebx + 1],ch
.no_pixel_bp_1:

 mov al,[esi + 5]
 and al,dh
 jz .no_pixel_bp_5

 mov ch,[ebx + 5]
 or ch,ah
 mov [ebx + 5],ch
.no_pixel_bp_5:

 mov al,[esi + 2]
 and al,dh
 jz .no_pixel_bp_2

 mov ch,[ebx + 2]
 or ch,ah
 mov [ebx + 2],ch
.no_pixel_bp_2:

 mov al,[esi + 6]
 and al,dh
 jz .no_pixel_bp_6

 mov ch,[ebx + 6]
 or ch,ah
 mov [ebx + 6],ch
.no_pixel_bp_6:

 mov al,[esi + 3]
 and al,dh
 jz .no_pixel_bp_3

 mov ch,[ebx + 3]
 or ch,ah
 mov [ebx + 3],ch
.no_pixel_bp_3:

 mov al,[esi + 7]
 and al,dh
 jz .no_pixel_bp_7

 mov ch,[ebx + 7]
 or ch,ah
 mov [ebx + 7],ch
.no_pixel_bp_7:

 pop ecx
 pop ebx
 dec cl
 jnz near .next_tile
 jmp .check_tag

ALIGNC
.bad_priority_flip_x:
 mov al,[esi + 7]
 and al,dh
 jz .no_pixel_bp_0_x

 mov ch,[ebx]
 or ch,ah
 mov [ebx],ch
.no_pixel_bp_0_x:

 mov al,[esi + 3]
 and al,dh
 jz .no_pixel_bp_4_x

 mov ch,[ebx + 4]
 or ch,ah
 mov [ebx + 4],ch
.no_pixel_bp_4_x:

 mov al,[esi + 6]
 and al,dh
 jz .no_pixel_bp_1_x

 mov ch,[ebx + 1]
 or ch,ah
 mov [ebx + 1],ch
.no_pixel_bp_1_x:

 mov al,[esi + 2]
 and al,dh
 jz .no_pixel_bp_5_x

 mov ch,[ebx + 5]
 or ch,ah
 mov [ebx + 5],ch
.no_pixel_bp_5_x:

 mov al,[esi + 5]
 and al,dh
 jz .no_pixel_bp_2_x

 mov ch,[ebx + 2]
 or ch,ah
 mov [ebx + 2],ch
.no_pixel_bp_2_x:

 mov al,[esi + 1]
 and al,dh
 jz .no_pixel_bp_6_x

 mov ch,[ebx + 6]
 or ch,ah
 mov [ebx + 6],ch
.no_pixel_bp_6_x:

 mov al,[esi + 4]
 and al,dh
 jz .no_pixel_bp_3_x

 mov ch,[ebx + 3]
 or ch,ah
 mov [ebx + 3],ch
.no_pixel_bp_3_x:

 mov al,[esi]
 and al,dh
 jz .no_pixel_bp_7_x

 mov ch,[ebx + 7]
 or ch,ah
 mov [ebx + 7],ch
.no_pixel_bp_7_x:

 pop ecx
 pop ebx
 dec cl
 jnz near .next_tile
 jmp .check_tag

; In the precalculator...
;  eax = (internal)
;  edx = (internal)
;  ebx = current sprite          (internal)
;  cl  = sprite flags bit count  (internal)
;  ebp = (internal)
;  esi = sprite tables           (internal)
;  edi = sprite flags            (internal)
;
%macro Add_Sprite_Y_Check 0
 ; Check if sprite entirely offscreen
 mov al,dl
 mov bl,[esi+1]
 shl al,3
 cmp bl,239
 jb %%on_screen_y
 add al,bl
 dec al
 jns %%on_screen_y
%%off_screen:
 ret
%%on_screen_y:
%endmacro

%define ASXP_Lines_Left    esp
;%define ASXP_X_Position    esp+1       ;planned but not yet used
%define ASXP_Total_Size    esp+4
%define ASXP_Visible_Width esp+5

%define OAM_TIME_OVER (1 << 7)
%define OAM_RANGE_OVER (1 << 6)

;tiles are added to ring buffers in right-to-left order
;ring buffers handle time-overflow by spilling excess tiles

;starts with first+max-count or last (first+count-1) tile
ALIGNC
EXPORT_C Add_Sprite_X_Positive
;visible width count in dh, total count in dl
;esi = OAM 512 byte subtable address
;edi = OAM 32 byte subtable address
;ecx, esi, edi must be preserved!
 Add_Sprite_Y_Check
 ; Save visible width and total size, these won't be changing
 push ecx
 push edi
 push edx

 ; Get base tile #
 mov ebp,[esi]
 xor ebx,ebx
 shr ebp,16
 mov al,[esi+3]
 mov cl,dl
 and eax,byte 0x40
 jnz .flip_x

 ; If tile is X-flipped, set to last tile # instead of first
 mov dl,dh
 dec ebp
 jmp short .adjust_x_done

.flip_x:
 ; Set to first tile #
 sub dl,dh

.adjust_x_done:
 shl cl,3       ; Convert tiles to lines
 and edx,byte 0x7F      ; Size will always be less than this
 add ebp,edx
 mov bl,[esi+1] ; Get first line
 shl ebp,3
 push ecx

;ebx = current line
;cl = lines left
;dl = ASXP_Total_Size * 8
;ebp = tile # (leftmost as shown)
.next_line:
 ;If line never displayed, ignore line
 cmp bl,239
 jnb near .check_count

 ; Check OBJ count for line (if 32, set range over and ignore OBJ)
 mov al,[C_LABEL(OAM_Count)+ebx*2]
 cmp al,32
 jb .range_okay

 or byte [C_LABEL(OAM_TimeRange)+ebx],OAM_RANGE_OVER
 jmp .check_count

.range_okay:
 ; else increment OBJ count
 inc al
 mov ch,[ASXP_Visible_Width]
 mov [C_LABEL(OAM_Count)+ebx*2],al

 mov dl,[ASXP_Total_Size]
 mov dh,[esi+3]
 shl dl,3
 push ebp
 add dh,dh
 jc .flip_y

 ; line in sprite = line size - lines left
 sub dl,[ASXP_Lines_Left+4]
 jnz .adjust_y
 jmp short .adjust_y_done

.flip_y:
 ; line in sprite = lines left - 1
 mov dl,[ASXP_Lines_Left+4]
 dec dl
 jz .adjust_y_done

.adjust_y:
 ; convert tile # in ebp to tile line #
 mov edi,edx
 and edx,byte 0x38  ; tile offset
 shl edx,3+1        ; (lines / 8) * 16 tiles * 8 lines
 and edi,byte 7     ; line in tile
 add ebp,edx
 add ebp,edi

.adjust_y_done:
 ; setup pointer to line descriptors to be used, update line count
 ; edx = C_LABEL(OAM_Lines)+(ebx*34+((byte) [C_LABEL(OAM_Count)+ebx*2+1]))*4
 mov edx,ebx
 push ebx
 shl edx,5
 add edx,ebx
 xor eax,eax
 add edx,ebx

 ; Check tile count for line (if 34, set time over and ignore tiles)
 ; If will be over 34, set time over and adjust width
 mov al,[C_LABEL(OAM_Count)+ebx*2+1]
 mov cl,0
 cmp al,34
 je .time_over

 add edx,eax
 add al,ch
 cmp al,34
 ja .time_first_over

 mov [C_LABEL(OAM_Count)+ebx*2+1],al
 jmp .time_okay

.time_first_over:
 mov byte [C_LABEL(OAM_Count)+ebx*2+1],34
 sub al,34
 jmp short .list_wrap

.time_over:
 mov al,[OAM_Tail+ebx]
 add edx,eax
 add al,ch
 mov [OAM_Tail+ebx],al
 sub al,34
 jb .time_over_detect
 je .fixup_head

.list_wrap:
 mov cl,al
.fixup_head:
 mov [OAM_Tail+ebx],al
 sub ch,al

.time_over_detect:
 or byte [C_LABEL(OAM_TimeRange)+ebx],OAM_TIME_OVER

.time_okay:
 mov al,[C_LABEL(OAM_Count)+ebx*2+1]
 lea edx,[C_LABEL(OAM_Lines)+edx*4]
 push eax

; Determine if sprite sequence on line contains higher priorities
;  after lower priorities, set new last-tile-for-priority
 mov ah,[C_LABEL(OAM_Lowest_Priority)+ebx]
 mov al,[esi+3]
 and al,0x30
 cmp ah,al
 jb .low_before_high
 mov [C_LABEL(OAM_Lowest_Priority)+ebx],al
 jmp short .priority_done

.low_before_high:
 mov byte [C_LABEL(OAM_Low_Before_High)+ebx],0xFF

.priority_done:
 ; setup flags & X position of tiles in line descriptor
 and eax,0x30
 shr eax,4
 lea ebx,[C_LABEL(OAM_Count_Priority)+eax+ebx*4]
 pop eax
 mov [ebx],al

 mov ah,0xFE
 mov bh,[esi+3]
 and ah,bh
 and bh,0x40
 mov al,[esi]
 jz .Flip_None

 ;cl = lines left (including current)
 ;ch = tile count for line, dl = OBJ size in pixel width/height
 ;ebp = tile # (not Y adjusted)
 ;esi = OAM pointer
 ;sprite line = cl - 1 (Y flip), dl - cl (no Y flip)
 call C_LABEL(Add_Sprite_X_Positive_Flip_X)
 pop ebx
 pop ebp
 jmp short .check_count

.Flip_None:
 call C_LABEL(Add_Sprite_X_Positive_Flip_None)
 pop ebx
.check_count_time_over:
 pop ebp

.check_count:
 inc bl
 dec byte [ASXP_Lines_Left]
 jnz near .next_line

 pop eax
 pop edx
 pop edi
 pop ecx
 ret

;starts with first or last (first+max-1) tile
ALIGNC
EXPORT_C Add_Sprite_X_Negative
;visible width count in dh, total count in dl
;esi = OAM 512 byte subtable address
;edi = OAM 32 byte subtable address
;ecx, esi, edi must be preserved!
 Add_Sprite_Y_Check
 ; Save visible width and total size, these won't be changing
 push ecx
 push edi
 push edx

 ; Get base tile #
 mov ebp,[esi]
 xor ebx,ebx
 shr ebp,16
 mov al,[esi+3]
 mov cl,dl
 and eax,byte 0x40
 jnz .flip_x

 ; If tile is X-flipped, set to last tile # instead of first
 and edx,byte 0x7F      ; Size will always be less than this
 dec ebp
 add ebp,edx

.flip_x:
 shl cl,3       ; Convert tiles to lines
 mov bl,[esi+1] ; Get first line
 shl ebp,3          ; tile # * 8 lines
 push ecx

;ebx = current line
;cl = lines left
;dl = ASXP_Total_Size * 8
;ebp = tile # (leftmost as shown)
.next_line:
 ;If line never displayed, ignore line
 cmp bl,239
 jnb near .check_count

 ; Check OBJ count for line (if 32, set range over and ignore OBJ)
 mov al,[C_LABEL(OAM_Count)+ebx*2]
 cmp al,32
 jb .range_okay

 or byte [C_LABEL(OAM_TimeRange)+ebx],OAM_RANGE_OVER
 jmp .check_count

.range_okay:
 ; increment OBJ count
 inc al
 mov ch,[ASXP_Visible_Width]
 mov [C_LABEL(OAM_Count)+ebx*2],al

 mov dl,[ASXP_Total_Size]
 mov dh,[esi+3]
 shl dl,3
 push ebp
 add dh,dh
 jc .flip_y

 ; line in sprite = line size - lines left
 sub dl,[ASXP_Lines_Left+4]
 jnz .adjust_y
 jmp short .adjust_y_done

.flip_y:
 ; line in sprite = lines left - 1
 mov dl,[ASXP_Lines_Left+4]
 dec dl
 jz .adjust_y_done

.adjust_y:
 ; convert tile # in ebp to tile line #
 mov edi,edx
 and edx,byte 0x38  ; tile offset
 shl edx,3+1        ; (lines / 8) * 16 tiles * 8 lines
 and edi,byte 7     ; line in tile
 add ebp,edx
 add ebp,edi

.adjust_y_done:
 ; setup pointer to line descriptors to be used, update line count
 ; edx = C_LABEL(OAM_Lines)+(ebx*34+((byte) [C_LABEL(OAM_Count)+ebx*2+1]))*4
 mov edx,ebx
 push ebx
 shl edx,5
 add edx,ebx
 xor eax,eax
 add edx,ebx

 ; Check tile count for line (if 34, set time over and ignore tiles)
 ; If will be over 34, set time over and adjust width
 mov al,[C_LABEL(OAM_Count)+ebx*2+1]
 mov cl,0
 cmp al,34
 je .time_over

 add edx,eax
 add al,ch
 cmp al,34
 ja .time_first_over

 mov [C_LABEL(OAM_Count)+ebx*2+1],al
 jmp short .time_okay

.time_first_over:
 mov byte [C_LABEL(OAM_Count)+ebx*2+1],34
 sub al,34
 jmp short .list_wrap

.time_over:
 mov al,[OAM_Tail+ebx]
 add edx,eax
 add al,ch
 mov [OAM_Tail+ebx],al
 sub al,34
 jb .time_over_detect
 je .fixup_head

.list_wrap:
 mov cl,al
.fixup_head:
 mov [OAM_Tail+ebx],al
 sub ch,al

.time_over_detect:
 or byte [C_LABEL(OAM_TimeRange)+ebx],OAM_TIME_OVER

.time_okay:
 mov al,[C_LABEL(OAM_Count)+ebx*2+1]
 lea edx,[C_LABEL(OAM_Lines)+edx*4]
 push eax

; Determine if sprite sequence on line contains higher priorities
;  after lower priorities, set new last-tile-for-priority
 mov ah,[C_LABEL(OAM_Lowest_Priority)+ebx]
 mov al,[esi+3]
 and al,0x30
 cmp ah,al
 jb .low_before_high
 mov [C_LABEL(OAM_Lowest_Priority)+ebx],al
 jmp short .priority_done

.low_before_high:
 mov byte [C_LABEL(OAM_Low_Before_High)+ebx],0xFF

.priority_done:
 ; setup flags & X position of tiles in line descriptor
 and eax,0x30
 shr eax,4
 lea ebx,[C_LABEL(OAM_Count_Priority)+eax+ebx*4]
 pop eax
 mov [ebx],al

 mov ah,[ASXP_Total_Size+8]
 mov bh,[esi+3]
 dec ah
 or bh,1
 mov al,[esi]
 shl ah,3
 add al,ah
 mov ah,bh
 jnc .no_carry
 xor ah,1

.no_carry:
 and bh,0x40
 jz .Flip_None

 ;cl = lines left (including current)
 ;ch = tile count for line, dl = OBJ size in pixel width/height
 ;ebp = tile # (not Y adjusted)
 ;esi = OAM pointer
 ;sprite line = cl - 1 (Y flip), dl - cl (no Y flip)
 call C_LABEL(Add_Sprite_X_Negative_Flip_X)
 pop ebx
 pop ebp
 jmp short .check_count

.Flip_None:
 call C_LABEL(Add_Sprite_X_Negative_Flip_None)
 pop ebx
.check_count_time_over:
 pop ebp

.check_count:
 inc bl
 dec byte [ASXP_Lines_Left]
 jnz near .next_line

 pop eax
 pop edx
 pop edi
 pop ecx
 ret

ALIGNC
;ebp += (count - 1) * 8; al += (count - 1) * 8;
EXPORT_C Add_Sprite_X_Positive_Flip_None
 xor ebx,ebx
 mov bl,ch
 add bl,cl
 dec bl
 shl ebx,3
 add al,bl
;add ebp,ebx
.next_tile:
 ; compute tile line #'s and store line descriptors
 push ebp
 and ebp,511*8+7
 cmp ebp,256*8
 mov edi,[C_LABEL(OBNAME)]
 jae .name
 mov edi,[C_LABEL(OBBASE)]
.name:
 and eax,0x3FFFF
 add ebp,edi
 shl ebp,18
 or eax,ebp

 pop ebp
 ;eax = prepared tile descriptor

 mov [edx],eax
 sub al,byte 8
 sub ebp,byte 8
 add edx,byte 4

 dec ch
 jnz .next_tile

 sub edx,34*4
 add ch,cl
 mov cl,0
 jnz .next_tile

 ret

ALIGNC
;ebp -= (count - 1) * 8; al += (count - 1) * 8;
EXPORT_C Add_Sprite_X_Positive_Flip_X
 xor ebx,ebx
 mov bl,ch
 add bl,cl
 dec bl
 shl ebx,3
 add al,bl
;sub ebp,ebx
.next_tile:
 ; compute tile line #'s and store line descriptors
 push ebp
 and ebp,511*8+7
 cmp ebp,256*8
 mov edi,[C_LABEL(OBNAME)]
 jae .name
 mov edi,[C_LABEL(OBBASE)]
.name:
 and eax,0x3FFFF
 add ebp,edi
 shl ebp,18
 or eax,ebp

 pop ebp
 ;eax = prepared tile descriptor

 mov [edx],eax
 sub al,byte 8
 add ebp,byte 8
 add edx,byte 4

 dec ch
 jnz .next_tile

 sub edx,34*4
 add ch,cl
 mov cl,0
 jnz .next_tile

 ret

ALIGNC
;ebp += (count - 1) * 8; al += (count - 1) * 8;
;if al < ((count - 1) * 8) ah ^= 1;
EXPORT_C Add_Sprite_X_Negative_Flip_None
.next_tile:
 ; compute tile line #'s and store line descriptors
 push ebp
 and ebp,511*8+7
 cmp ebp,256*8
 mov edi,[C_LABEL(OBNAME)]
 jae .name
 mov edi,[C_LABEL(OBBASE)]
.name:
 and eax,0x3FFFF
 add ebp,edi
 shl ebp,18
 or eax,ebp

 pop ebp
 ;eax = prepared tile descriptor

 mov [edx],eax
 sub al,byte 8
 jnc .no_carry
 xor ah,1

.no_carry:
 sub ebp,byte 8
 add edx,byte 4

 dec ch
 jnz .next_tile

 sub edx,34*4
 add ch,cl
 mov cl,0
 jnz .next_tile

 ret

ALIGNC
;ebp -= (count - 1) * 8; al += (count - 1) * 8;
;if al < ((count - 1) * 8) ah ^= 1;
EXPORT_C Add_Sprite_X_Negative_Flip_X
.next_tile:
 ; compute tile line #'s and store line descriptors
 push ebp
 and ebp,511*8+7
 cmp ebp,256*8
 mov edi,[C_LABEL(OBNAME)]
 jae .name
 mov edi,[C_LABEL(OBBASE)]
.name:
 and eax,0x3FFFF
 add ebp,edi
 shl ebp,18
 or eax,ebp

 pop ebp
 ;eax = prepared tile descriptor

 mov [edx],eax
 sub al,byte 8
 jnc .no_carry
 xor ah,1

.no_carry:
 add ebp,byte 8
 add edx,byte 4

 dec ch
 jnz .next_tile

 sub edx,34*4
 add ch,cl
 mov cl,0
 jnz .next_tile

 ret

ALIGNC
EXPORT_C Recache_OAM

%ifdef Profile_Recache_OAM
 inc dword [C_LABEL(Calls_Recache_OAM)]
%endif

; Clear count tables
 mov edi,C_LABEL(OAM_Count_Priority)
 xor eax,eax
 mov ecx,240*4/32
 call Do_Clear

 mov edi,C_LABEL(OAM_Count)
 mov ecx,240*2/32
 call Do_Clear
        
 mov edi,OAM_Tail
 mov ecx,224/32
 call Do_Clear

 mov bl,[edi]
 mov [edi],eax
 mov [edi+4],eax
 mov [edi+8],eax
 mov [edi+12],eax

 mov edi,C_LABEL(OAM_TimeRange)
 mov ecx,224/32
 call Do_Clear

 mov bl,[edi]
 mov [edi],eax
 mov [edi+4],eax
 mov [edi+8],eax
 mov [edi+12],eax

 mov edi,C_LABEL(OAM_Low_Before_High)
 mov ecx,224/32
 call Do_Clear

 mov bl,[edi]
 mov [edi],eax
 mov [edi+4],eax
 mov [edi+8],eax
 mov [edi+12],eax

 mov edi,C_LABEL(OAM_Lowest_Priority)
 mov ecx,224/32
 dec eax
 call Do_Clear

 mov bl,[edi]
 mov [edi],eax
 mov [edi+4],eax
 mov [edi+8],eax
 mov [edi+12],eax

 mov al,[C_LABEL(OBSEL)]
;and al,0xE0 ;???
 cmp al,0xC0    ; If invalid size selected, no sprites to plot
 jnb near .done

 mov ecx,[C_LABEL(HiSpriteCnt1)]    ; Size of first set and bit offset
 mov eax,[C_LABEL(HiSpriteCnt2)]
 mov esi,[C_LABEL(HiSpriteAddr)]
 test ah,ah
 mov edi,[C_LABEL(HiSpriteBits)]
 jz .is_zero
 push byte 0
.is_zero:
 push eax
 jmp short .next_sprite

; Tile attribute word: YXPP CCCT TTTT TTTT
;  Where:
;   Y, X are vertical/horizontal flip
;   P is priority
;   C is color palette selector
;   T is tile number
;

; AAAA AAAA AAAA AAAA YXPP CCCX XXXX XXXX
;  A - OAM sprite line-in-tile address
;  YXPP CCC  - bits 1-7 of OAM attribute word
;  X - X position
ALIGNC
.next_sprite:
;esi = OAM 512 byte subtable address OAM+(0-511)
;edi = OAM 32 byte subtable address OAM+(512-543)
;cl = variable shift count for OAM subtable (1, 3, 5, 7)
;ch = count left in current decode pass (1-128)

;Perform clipping & determine visible range
;Get size
 mov ah,[edi]
 mov edx,[Sprite_Size_Current]

 ;Shift size bit into carry
 shl ah,cl
 jnc .do_small

 ;dl = sprite size in tiles
 ;dh = lower limit for negative X position
 shr edx,16
 mov al,[esi]   ; ax = X

 ;Get X sign bit
 shr ah,8
 jnc .do_positive

 ;Determine if sprite is entirely offscreen
 cmp al,dh
 jnb .do_negative
 jmp short .off_screen

ALIGNC
.do_small:
 ;dl = sprite size in tiles
 ;dh = lower limit for negative X position
 mov al,[esi]  ; ax = X

 ;Get X sign bit
 shr ah,8
 jnc .do_positive

 ;Determine if sprite is entirely offscreen
 cmp al,dh
 jb .off_screen

.do_negative:
;# tiles -= 32 - ((X + 7) & FF) / 8 for -X
 add eax,byte 7
 mov dh,dl
 shr eax,3
 xor al,0xFF
 add al,33
 sub dh,al
;visible width count in dh, total count in dl
;esi = OAM 512 byte subtable address
;edi = OAM 32 byte subtable address
;ecx, esi, edi must be preserved!
 call C_LABEL(Add_Sprite_X_Negative)
 jmp short .off_screen

.do_positive:
;# tiles <= 32 - (X & 0xFF) / 8 for +X
 shr al,3
 mov dh,dl
 xor al,0xFF
 add al,33
;max visible count in al

;dl = min(max count(al), total count(dl))
 sub al,dl
 sbb bl,bl
 and bl,al
 add dh,bl
;visible width count in dh, total count in dl
;esi = OAM 512 byte subtable address
;edi = OAM 32 byte subtable address
;ecx, esi, edi must be preserved!
 call C_LABEL(Add_Sprite_X_Positive)
 jmp short .off_screen

ALIGNC
.off_screen:
 sub cl,2   ; Adjust variable shift count
 jnc .bits_left
 and cl,7
 inc edi    ; Goto next sprite X-MSB/size byte

.bits_left:
 add esi,byte 4 ; Goto next sprite XYAA dword
 dec ch         ; Check sprite list count
 jnz near .next_sprite
 mov ch,[1+esp] ; Get next list count
 sub esi,0x200  ; Adjust pointers to sprite 127 (if we're at end)
 sub edi,byte 0x20
 add esp,byte 4
 test ch,ch     ; Continue if valid list
 jnz near .next_sprite

.done:
 mov byte [Redo_OAM],0

 ret

ALIGNC
EXPORT_C Reset_Sprites
 pusha
 ; Set eax to 0, as we're setting most everything to 0...
 xor eax,eax

 ; Reset sprite renderer vars
 mov byte [C_LABEL(HiSprite)],0
 mov dword [C_LABEL(HiSpriteAddr)],C_LABEL(OAM)+0x000
 mov dword [C_LABEL(HiSpriteBits)],C_LABEL(OAM)+0x200
 mov dword [C_LABEL(HiSpriteCnt1)],0x8007
 mov dword [C_LABEL(HiSpriteCnt2)],0x0007
 mov byte [Redo_OAM],-1
 mov byte [sprsize_small],1
 mov byte [sprsize_large],2
 mov byte [sprlim_small],-7
 mov byte [sprlim_large],-15
 mov byte [Pixel_Allocation_Tag],1
 mov [C_LABEL(OBBASE)],eax
 mov [C_LABEL(OBNAME)],eax

 ; Reset sprite port vars
 mov [C_LABEL(OAMAddress)],eax
 mov [C_LABEL(OAMAddress_VBL)],eax
 mov [OAMHigh],al
 mov [OAM_Write_Low],al
 mov [SPRLatch],al
 mov [C_LABEL(OBSEL)],al

; Clear pixel allocation tag table
 mov edi,DisplayZ+8
 xor eax,eax
 mov ecx,256/32
 call Do_Clear

 popa
 ret

ALIGNC
EXPORT SNES_R2138 ; OAMDATAREAD
 mov edx,[C_LABEL(OAMAddress)]
 mov al,[OAMHigh]
 cmp edx,0x100  ; if address >= 0x100...
 jb .no_mirror
 and edx,0x10F   ; ignore disconnected lines

.no_mirror:
 xor al,1
 mov [OAMHigh],al
 jnz .read_low

 mov al,[C_LABEL(OAM)+edx*2+1]

 mov edx,[C_LABEL(OAMAddress)]
 inc edx
 and edx,0x1FF  ; address is 9 bits
 mov [C_LABEL(OAMAddress)],edx
 ret

ALIGNC
.read_low:
 mov al,[C_LABEL(OAM)+edx*2]
 ret

ALIGNC
EXPORT SNES_W2101 ; OBSEL
 cmp [C_LABEL(OBSEL)],al
 je near .no_change

 UpdateDisplay  ;*
 push ebx
 mov [C_LABEL(OBSEL)],al    ; Get our copy of this
 mov ebx,eax
 shr eax,5
 and eax,byte 7
 mov edx,[Sprite_Size_Table+eax*4]
 mov [Sprite_Size_Current],edx
 mov eax,ebx
 mov edx,eax
 and ebx,byte 3<<3  ; Name address 0000 0000 000n n000
 and edx,byte 3     ; Base address 0000 0000 0000 0xbb
;shl ebx,10         ; Name is either 0x0000,0x1000,0x2000,0x3000 words
;shl edx,14         ; Base is either 0x0000,0x2000,0x4000,0x6000 words
 shl ebx,8          ; Name is either 0x0000,0x0800,0x1000,0x1800 lines
 shl edx,12         ; Base is either 0x0000,0x1000,0x2000,0x3000 lines
 add ebx,edx
;and edx,0xFFFF
;and ebx,0xFFFF
 and edx,0x3FFF
 and ebx,0x3FFF
;add edx,edx        ; Convert to offsets into tile cache
;add ebx,ebx
;add edx,C_LABEL(TileCache4)
;add ebx,C_LABEL(TileCache4)
 mov [C_LABEL(OBBASE)],edx
 mov [C_LABEL(OBNAME)],ebx
 pop ebx
 mov byte [Redo_OAM],-1
.no_change:
 ret

ALIGNC
EXPORT SNES_W2102 ; OAMADDL
 UpdateDisplay  ;*
 push ebx
 xor ebx,ebx
 mov [OAMHigh],bh
 mov bl,al
 mov [C_LABEL(OAMAddress)],ebx
 mov [C_LABEL(OAMAddress_VBL)],ebx

 cmp byte [SPRLatch],0
 ;if priority latch is off, do we ignore write or reset priority?
 jz near .priority_no_change

.priority_update:
 shr ebx,byte 1     ;convert address to OBJ #
 cmp [C_LABEL(HiSprite)],bl
 je .priority_no_change
 mov [C_LABEL(HiSprite)],bl
 shl ebx,2
 mov byte [Redo_OAM],-1
;sub ebx,byte 4
;and ebx,0x1FC
 mov [C_LABEL(HiSpriteAddr)],ebx
 shr ebx,4
 add ebx,0x200
 mov [C_LABEL(HiSpriteBits)],ebx
 mov bl,[C_LABEL(HiSprite)]
 mov bh,128
 mov [C_LABEL(HiSpriteCnt2)+1],bl   ;
 sub bh,bl
 mov [C_LABEL(HiSpriteCnt1)+1],bh   ;
 mov bh,7
 add bl,bl
 sub bh,bl
 and bh,7
 mov [C_LABEL(HiSpriteCnt1)],bh ;

 mov ebx,C_LABEL(OAM)
 add [C_LABEL(HiSpriteAddr)],ebx
 add [C_LABEL(HiSpriteBits)],ebx
.priority_no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W2103 ; OAMADDH
 UpdateDisplay  ;*
 push ebx
 xor ebx,ebx
 mov [OAMHigh],bl
 mov bh,1
 and bh,al      ; Only want MSB of address
 mov [C_LABEL(OAMAddress_VBL)+1],bh
 mov [C_LABEL(OAMAddress)+1],bh
 test al,al     ; Is priority rotation bit set?
 js .latch_priority_rotation
 mov [SPRLatch],bl
 pop ebx
 ret

ALIGNC
.latch_priority_rotation:
 mov byte [SPRLatch],-1
 mov ebx,[C_LABEL(OAMAddress)]
 jmp SNES_W2102.priority_update

ALIGNC
EXPORT SNES_W2104 ; OAMDATA
 push ebx
 cmp byte [HVBJOY], 0
 js .in_vblank

 cmp byte [C_LABEL(INIDISP)], 0
 jns near .no_increment  ;.no_change

.in_vblank:
 xor ebx,ebx
 mov edx,[C_LABEL(OAMAddress)]
 mov bl,[OAMHigh]
 cmp edx,0x100  ; if address >= 0x100, byte access
 jnb .byte_access

 xor ebx,byte 1
 mov [OAMHigh],bl
 jnz .write_low

 mov bl,[OAM_Write_Low]
 mov bh,al
 cmp [C_LABEL(OAM)+edx*2],bx
 je .no_change
 UpdateDisplay  ;*
 mov edx,[C_LABEL(OAMAddress)]
 mov byte [Redo_OAM],-1
 mov [C_LABEL(OAM)+edx*2],bx
.no_change:
 mov edx,[C_LABEL(OAMAddress)]
 inc edx
 and edx,0x1FF  ; address is 9 bits
 mov [C_LABEL(OAMAddress)],edx
.no_increment:
.ignore_write:
 pop ebx
 ret
ALIGNC
.write_low:
 mov [OAM_Write_Low],al
 pop ebx
 ret

ALIGNC
.byte_access:
 and edx,0x10F   ; ignore disconnected lines
 cmp [C_LABEL(OAM)+edx*2+ebx],al
 je .ba_no_change
 push edx
 UpdateDisplay  ;*
 pop edx
 mov byte [Redo_OAM],-1
 mov [C_LABEL(OAM)+edx*2+ebx],al
.ba_no_change:

 xor ebx,byte 1
 mov [OAMHigh],bl
 jnz .no_increment

 mov edx,[C_LABEL(OAMAddress)]
 inc edx
 and edx,0x1FF  ; address is 9 bits
 mov [C_LABEL(OAMAddress)],edx
 pop ebx
 ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
