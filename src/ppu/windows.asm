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

; windows.asm
; Screen windowing code
;

%define SNEeSe_ppu_windows_asm

%include "misc.inc"
%include "ppu/ppu.inc"
%include "ppu/screen.inc"

section .text
EXPORT_C windows_text_start
section .data
EXPORT_C windows_data_start
section .bss
EXPORT_C windows_bss_start

section .data
ALIGND
EXPORT ClipTableStart
 db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
 db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
EXPORT ClipLeftTable    ;ClipLeftTable[-first_pixel_offset]
 db 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF
 db 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF
EXPORT ClipRightTable   ;ClipRightTable[-pixel_count]
 db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
 db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
;to clip both: ClipLeftTable[-first_pixel_offset] &
; ClipRightTable[-(first_pixel_offset + pixel_count)]


section .bss
ALIGNB
EXPORT Window_Offset_First,skipl
EXPORT Window_Offset_Second,skipl

EXPORT_C WH0,skipb      ; Holds window 1 left position
EXPORT_C TM ,skipb      ; 000odcba  o=OBJ enable,a-d=BG1-4 enable
EXPORT_C WBGLOG,skipb   ; BG Window mask logic
EXPORT_C W12SEL ,skipb  ; Holds plane 1/2 window mask settings
EXPORT_C WH1,skipb      ; Holds window 1 right position
EXPORT_C TMW,skipb
EXPORT_C WOBJLOG,skipb  ; OBJ/Colour Window mask logic
EXPORT_C W34SEL ,skipb  ; Holds plane 3/4 window mask settings
EXPORT_C WH2,skipb      ; Holds window 2 left position
EXPORT_C TS ,skipb      ; 000odcba  o=OBJ enable,a-d=BG1-4 enable
EXPORT_C CGWSEL,skipb
EXPORT_C WOBJSEL,skipb  ; Holds colour/object window mask settings
EXPORT_C WH3,skipb      ; Holds window 2 right position
EXPORT_C TSW,skipb
EXPORT_C CGADSUB,skipb

;Layering vars
EXPORT Layers_Low       ; one of allowed TM, TS, or TM || TS
EXPORT Layers_High      ; one of allowed TS, TM, or 0

EXPORT_C Layering_Mode,skipb
EXPORT SCR_TM,skipb     ; TM taken from here
EXPORT SCR_TS,skipb     ; TS taken from here
EXPORT SCR_TMW,skipb    ; TMW taken from here
EXPORT SCR_TSW,skipb    ; TSW taken from here
EXPORT_C Layer_Disable_Mask,skipb   ; This is used to force planes to disable!

EXPORT TM_Allowed,skipb ; allowed layer mask & layer disable mask & TM
EXPORT TS_Allowed,skipb ; allowed layer mask & layer disable mask & TS
EXPORT Layers_In_Use,skipb  ; TM_Allowed | TS_Allowed

%macro WIN_DATA 1
ALIGNB
EXPORT_C TableWin%1
EXPORT_C Win%1_Count_Out,skipb
EXPORT_C Win%1_Bands_Out,skipb 2*2
EXPORT_C Win%1_Count_In,skipb
EXPORT_C Win%1_Bands_In,skipb 2
%endmacro

WIN_DATA 1
WIN_DATA 2

ALIGNB
EXPORT TileClip1
EXPORT TileClip1Left,skipl
EXPORT TileClip1Right,skipl
EXPORT TileClip2
EXPORT TileClip2Left,skipl
EXPORT TileClip2Right,skipl

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
 jmp .done
.not_flush_left:
 ; Window not flush left (1 inside, 1 or 2 outside)
 test cl,cl
 jz .flush_one_side     ; if (Left && Right == 255) window flush right;
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
 jmp .done
.flush_one_side:
 ; Window flush left, not flush right (1 inside, 1 outside)
 ; Window flush right, not flush left (1 inside, 1 outside)
 ; Inside range is (left,right), outside range is (right+1,left-1)
;dec eax                 ; Right outside edge = Left inside edge - 1
;inc edx                 ; Left outside edge = right inside edge + 1
 mov [Win_Bands_Out+edx+1],al
 mov byte [Win_Count_Out+edx],1 ; One band outside window (right+1,left-1)
 mov [Win_Bands_Out+edx],cl
 jmp .done
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

 ; compare window 2 left edge against window 1 right edge
 test ah,ah
 jz .or_win1right_edge

 cmp bl,ah      ;win2left, win1right
 ja .or_no_intersect

.or_win1right_edge:

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

 ; compare next band left edge against accumulated band right edge
 test ah,ah
 jz .or_win1right_edge2

 cmp bl,ah      ;win2left, win1right
 ja .or_no_intersect2

.or_win1right_edge2:

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

.or_no_intersect2:
 mov [edi+ebp*2+Win_Bands],al
 mov [edi+ebp*2+Win_Bands+1],ah
 inc ebp

 test ch,ch
 jnz .or_win1_loop
 mov ax,bx
 jmp .or_no_intersect

.or_last_band:
 mov [edi+ebp*2+Win_Bands],ax
 inc ebp

.or_copy_win2:
 mov cl,ch
 mov edx,esi
.or_copy_win1:
 test cl,cl
 jz .or_done
.or_copy_another:
 mov ax,[edx+Win_Bands]
 add edx,byte 2
 mov [edi+ebp*2+Win_Bands],ax
 inc ebp
 dec cl
 jnz .or_copy_another
.or_done:
 mov eax,ebp
 mov [edi+Win_Count],al
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


section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
