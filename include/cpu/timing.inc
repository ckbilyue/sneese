%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

;%define SNEeSe_No_GUI
;%define DELAY_FRAMES 5
; CPU/interrupt/graphics timing implementation

; Fixed events (always at same time in frame):
; Scanline 0: hidden
; Scanline 1-224/239, dots   0- 21: Hblank
; Scanline 1-224/239, dots  22-277: Displayed screen
; Scanline 1-224/239, dots 278-339: Hblank, HDMA start
; Scanline 225/240: Vblank, NMI

; Variable events (software-specified time in frame):
;  H-IRQ - on a specific point on every scanline
;  V-IRQ - short time after beginning of a specific scanline
;  H+V-IRQ - on a specific point on the frame

%define ZERO_TRIP_CYCLE_COUNTER

%define RDNMI_VBLANK_START (1 << 7)
%define HVBJOY_IN_VBLANK (1 << 7)
%define HVBJOY_IN_HBLANK (1 << 6)
%define HVBJOY_CONTROLLERS_BUSY (1 << 0)

%include "misc.inc"
%include "ppu/screen.inc"
%include "cpu/dma.inc"
%include "apu/spc.inc"
%include "ppu/sprites.inc"
%include "cycles.inc"

EXTERN_C FPSTicks
EXTERN_C UPDATE_KEYS
EXTERN_C CONTROLLER_1_TYPE,CONTROLLER_2_TYPE
EXTERN_C MickeyMouse,MickeyRead,MouseButtons

%define FRAME_LIMIT 0
; Set this to force emulation loop to break after x frames have been
;  displayed (not emulated!) This does not save CPU regs, etc.!
;  Primary use is for profiling!
%define FRAME_LIMIT_PROFILE 0
; Set this to change behavior of FRAME_LIMIT to enable internal
;  profiling code
;%define VAR_FRAME_LIMIT
; Set this to force emulation loop to break after FrameLimit frames

section .bss
%if 0
ALIGND
EXPORT LineBG1OFS   ,skipw 2*239
ALIGND
EXPORT LineBG2OFS   ,skipw 2*239
ALIGND
EXPORT LineBG3OFS   ,skipw 2*239
ALIGND
EXPORT LineBG4OFS   ,skipw 2*239
ALIGND
EXPORT LineM7       ,skipw 6*239
EXPORT ScreenLineHoles  ,skipb (256+128)/8
%endif

JOYC1:      skipb   ; This holds the controller read control byte
EXPORT_C Controller1_Pos,skipb  ; Shift count for controller 1 read
EXPORT_C Controller23_Pos,skipb ; Shift count for controller 2/3 read
EXPORT_C Controller45_Pos,skipb ; Shift count for controller 4/5 read

ALIGNB
; These are updated per VBL rather than per read!
EXPORT_C JOY1L,skipb
EXPORT_C JOY1H,skipb 3
EXPORT_C JOY2L,skipb
EXPORT_C JOY2H,skipb 3
; These are not updated yet
EXPORT_C JOY3L,skipb
EXPORT_C JOY3H,skipb 3
EXPORT_C JOY4L,skipb
EXPORT_C JOY4H,skipb 3

RDDIV:
RDDIVL:     skipb   ; Quotient of divide
RDDIVH:     skipb
RDMPY:
RDMPYL:     skipb   ; Multiplication or remainder
RDMPYH:     skipb
WRMPY:
WRMPYA:     skipb   ; Multiplicand A
WRMPYB:     skipb   ; Multiplicand B
WRDIV:
WRDIVL:     skipb   ; Dividend C
WRDIVH:     skipb

EXPORT_C LastRenderLine ,skipl
EXPORT_C LastVBLLine    ,skipl

EXPORT FrameCount       ,skipl  ; Used for frameskipping
EXPORT Event_Handler    ,skipl  ; Used for render/HDMA timing/NMI/IRQ
EXPORT Fixed_Event      ,skipl  ; Used for render/HDMA timing
EXPORT Last_Trip        ,skipl  ; Clock cycle position of last scheduled event
HDMA_Next_Event:    skipl   ; Fixed event following HDMA
DMA_Next_Event:     skipl   ; Fixed event following DMA
DMA_Next_Trip:      skipl   ; Fixed event following DMA
Render_Next_Event:  skipl   ; Fixed event following render
Render_Next_Trip:   skipl   ; Fixed event following render
NMI_Event_Handler:  skipl   ; Event handler for NMI
Vblank_Start:       skipl   ; Scanline of last Vblank start
EXPORT HTimer           ,skipl  ; Clock cycle position of H-IRQ delay start

EXPORT_C HTIMEL ,skipb  ; H IRQ position low
EXPORT_C HTIMEH ,skipb  ; H IRQ position high
                 skipb
                 skipb
EXPORT_C VTIMEL ,skipb  ; V IRQ position low
EXPORT_C VTIMEH ,skipb  ; V IRQ position high
                 skipb
                 skipb

FPSCount:       skipl   ; Count of frames executed this second
EXPORT_C FPSMaxTicks,skipl  ; Number of timer ticks after which FPS is calc'd
EXPORT_C FPSLast    ,skipl  ; Calculated FPS for last second
EXPORT_C BreaksLast ,skipl  ; Render breaks for last frame

Latched_H:  skipl   ; These two are latched values!
Latched_V:  skipl

MEMSEL:     skipb   ; FastROM switch
; Hack for FF6 glitch, to be removed when timing improved
EXPORT_C FastROM_offset,skipb
EXPORT OPHCT,skipb  ; Whether reading lo or high byte
EXPORT OPVCT,skipb  ; Whether reading lo or high byte
RDNMI:      skipb   ; x000vvvv  x=disable/enable NMI,vvvv=version
EXPORT_C NMITIMEN,skipb ; a0yx000b  a=NMI on/off,y=vert count,x=horiz count,b=joy read
; I/O port register - bit 7 affects H/V counter, all bits used for output
EXPORT_C WRIO,skipb     ; lxxxxxxx  l=counter latched when set
; I/O port register - value CPU is receiving
; RDIO register reads return this value ANDed with value in WRIO
EXPORT_C RDIO,skipb
EXPORT HVBJOY,skipb
; Nonzero if an IRQ set for current line has not been reached yet
;IRQ_set_this_line:skipb

section .text

;R_Cycles = C_LABEL(EventTrip) - C_LABEL(SNES_Cycles), trips on <= zero

;%1 = Execute
%macro Update_Cycles 0-1 0
 mov eax,[C_LABEL(SNES_Cycles)] ; Update CPU and SPC cycles

 mov edi,[C_LABEL(SNES_Cycles)]
 sub edi,[C_LABEL(EventTrip)]

 cmp eax,CYCLES_REFRESH_START
 jb %%before_refresh
 add eax,byte CYCLES_IN_REFRESH
%%before_refresh:

 sub eax,[SPC_last_cycles]
 mov [C_LABEL(SNES_Cycles)],edi
 mov [SPC_last_cycles],edi

%ifidni %1,Execute
 cmp byte [C_LABEL(SPC_ENABLED)],0
 jz %%no_spc
 add eax,[SPC_CPU_cycles]
 Execute_SPC
%%no_spc:
%else
 add [SPC_CPU_cycles],eax
%endif
%endmacro

; Uses 012-local labels, corrupts edx, zeroes eax
%macro Update_FPS_Counter 0
 mov edx,[C_LABEL(FPSMaxTicks)]
 xor eax,eax
 cmp [C_LABEL(FPSTicks)],edx
 jb %%no_update
 mov edx,[FPSCount]
 je %%fps_update
 cmp edx,byte 1
 ja %%fps_update
 mov dword [C_LABEL(FPSLast)],0
 jmp short %%less_than_1_fps
%%fps_update:
 mov [C_LABEL(FPSLast)],edx
%%less_than_1_fps:
 mov [C_LABEL(FPSTicks)],eax
 mov [FPSCount],eax
ALIGNC
%%no_update:
%endmacro

; CPU/Render/Display/Blanking timing
; Master clock: 21.47MHz   Dot clock: masterclock/4
; Vblank: Lines (DisplayEnd + 1) to 0
; Display: Lines 1 to DisplayEnd
; < 22d Hblank><256d display       >< 64d Hblank> (render)
; <512c exec  >< 40c memory refresh><816c exec  > (execution)

; Keep one fixed event cycle-target/handler pointer
; Keep one variable (may be fixed or IRQ)
ALIGNC
EXPORT IRQNewFrameReset

 mov dword [Last_Trip],0

 mov dword [C_LABEL(EventTrip)],CYCLES_HDMA_START
 mov dword [FixedTrip],CYCLES_HDMA_START
 mov dword [Event_Handler],HDMA_Event
 mov dword [Fixed_Event],HDMA_Event
 mov dword [HDMA_Next_Event],C_LABEL(IRQFirstRender)

 ; Reset frameskip counter
 mov ebx,1
 cmp ebx,[C_LABEL(FRAME_SKIP_MIN)]
 ja .no_fix_framecount
 mov ebx,[C_LABEL(FRAME_SKIP_MIN)]
.no_fix_framecount:
 mov [FrameCount],ebx

 xor eax,eax
 mov [C_LABEL(Timer_Counter_Throttle)],eax  ; Reset speed-throttle timer
 mov [C_LABEL(Current_Line_Timing)],eax     ; Reset scanline counter
 inc dword [FPSCount]           ; For FPS counter - 0.25b14

;%define TRAP_HDMA_RELATCH
%ifdef TRAP_HDMA_RELATCH
EXTERN_C Dump_DMA
 pusha
 push byte 0
 call C_LABEL(Dump_DMA)
 pop edi
 popa
 RELATCH_HDMA
 pusha
 push byte 1
 call C_LABEL(Dump_DMA)
 pop edi
 popa
%else
 RELATCH_HDMA
%endif

 Update_FPS_Counter
 ret

ALIGNC
HDMA_Event:
 mov eax,[C_LABEL(EventTrip)]
 mov [Last_Trip],eax

 mov eax,[HDMA_Next_Event]
;mov dword [C_LABEL(EventTrip)],CYCLES_NEW_SCANLINE
 mov dword [FixedTrip],CYCLES_NEW_SCANLINE
;mov [Event_Handler],eax
 mov [Fixed_Event],eax
 cmp byte [HDMAON],0
 jz .no_HDMA
 LOAD_CYCLES
 add R_65c816_Cycles,byte 18    ; HDMA processing
 call do_HDMA
 SAVE_CYCLES
%ifdef TRAP_HDMA_RELATCH
 pusha
 push byte 2
 call C_LABEL(Dump_DMA)
 pop edi
 popa
%endif
.no_HDMA:
 call HIRQ_Check_Late   ; chain

 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jl .no_chain
 jmp dword [Event_Handler]
.no_chain:

 jmp near CPU_START     ; Return to CPU

ALIGNC
Enabling_IRQ_Event:
 call HIRQ_Check_Late   ; chain

 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jl .no_chain
 jmp dword [Event_Handler]
.no_chain:
 jmp near CPU_START     ; Return to CPU

ALIGNC
IRQ_Enabled_Event:
 mov al,[CPU_Execution_Mode]
 cmp al,CEM_Instruction_After_IRQ_Enable
 jne .mode_changed

 mov al,CEM_Normal_Execution
 mov [CPU_Execution_Mode],al

.mode_changed:
 mov al,[IRQ_pin]
 test al,al
 jz .no_irq

 mov al,[CPU_Execution_Mode]
 cmp al,CEM_Clock_Stopped
 je .no_irq
 cmp al,CEM_Waiting_For_Interrupt
 jne .no_wai

%ifdef WAI_DELAY
 ; WAI delay after interrupt signal: 2 IO
 add dword [C_LABEL(SNES_Cycles)],byte 12   ;*
%endif

 inc word [CPU_LABEL(PC)]

 mov byte [CPU_Execution_Mode],CEM_Normal_Execution

.no_wai:
 push edi
 LOAD_BASE
 JUMP_FLAG SNES_FLAG_I,.irq_disabled    ; Interrupts disabled?
 LOAD_CYCLES
 JUMP_NOT_FLAG SNES_FLAG_E,.native_irq
 add R_65c816_Cycles,byte 52    ; IRQ processing: 2 IO + 5 bank0
 call E1_IRQ
 jmp .irq_return
ALIGNC
.native_irq:
 add R_65c816_Cycles,byte 60    ; IRQ processing: 2 IO + 6 bank0
 call E0_IRQ
.irq_return:
 SAVE_CYCLES
.irq_disabled:
 pop edi

.no_irq:
 call HIRQ_Check_Late   ; chain

 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jl .no_chain
 jmp dword [Event_Handler]
.no_chain:
 jmp near CPU_START     ; Return to CPU

ALIGNC
DMA_Event:
 mov eax,[C_LABEL(EventTrip)]
 mov [Last_Trip],eax

 mov eax,[DMA_Next_Event]
;mov [Event_Handler],eax
 mov [Fixed_Event],eax
 mov eax,[DMA_Next_Trip]
;mov [C_LABEL(EventTrip)],eax
 mov [FixedTrip],eax
;do DMA here
 call HIRQ_Check_Late   ; chain

 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jl .no_chain
 jmp dword [Event_Handler]
.no_chain:

 jmp near CPU_START     ; Return to CPU

ALIGNC
Render_Event:
 mov eax,[C_LABEL(EventTrip)]
 mov [Last_Trip],eax

 mov eax,[Render_Next_Event]
;mov [Event_Handler],eax
 mov [Fixed_Event],eax
 mov eax,[Render_Next_Trip]
;mov [C_LABEL(EventTrip)],eax
 mov [FixedTrip],eax
 RenderScanline
 call HIRQ_Check_Late   ; chain

 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jl .no_chain
 jmp dword [Event_Handler]
.no_chain:

 jmp near CPU_START     ; Return to CPU

ALIGNC
speed_cap_wait_hlt:
 hlt
 jmp near IRQNewFrame.speed_cap_wait
ALIGNC
EXPORT IRQNewFrame              ; Check IRQ, Frame Skip
%ifdef DELAY_FRAMES
 push dword DELAY_FRAMES
EXTERN_C rest
 call C_LABEL(rest)
 add esp,4
%endif

 mov dword [Last_Trip],0

 ; Force SPC to catch up to eliminate lags and improve sound
 Update_Cycles Execute

 ; Update SPC timers to prevent overflow
 Update_SPC_Timer 0
 Update_SPC_Timer 1
 Update_SPC_Timer 2

 call C_LABEL(update_sound) ; Added by Butcha

;mov dword [C_LABEL(EventTrip)],CYCLES_HDMA_START
 mov dword [FixedTrip],CYCLES_HDMA_START
;mov dword [Event_Handler],HDMA_Event
 mov dword [Fixed_Event],HDMA_Event

 mov al,[HVBJOY]
 and al,~HVBJOY_IN_VBLANK   ; VBlank off
 mov [HVBJOY],al
 mov byte [RDNMI],VERSION_NUMBER_5A22   ; Clear NMI enabled bit in 0x4210

 mov al,[C_LABEL(INIDISP)]
 test al,al
 js .forced_blank
 mov eax,[C_LABEL(OAMAddress_VBL)]
 ; Restore OAM address and reset OAM read/write odd/even select
 ;  every Vblank, unless we're in forced blank
 mov [C_LABEL(OAMAddress)],eax
 xor eax,eax
 mov [OAMHigh],al
.forced_blank:

 xor eax,eax
 dec dword [FrameCount] ; Should we redraw the screen this frame?
 mov [C_LABEL(Current_Line_Timing)],eax ; Reset scanline counter
 mov edi,C_LABEL(IRQFirst)
 jnz near .no_redraw

 ; this frame not skipped - determine how many frames following to skip
 inc dword [FPSCount]   ; For FPS counter - 0.25b14
 mov edi,C_LABEL(IRQFirstRender)

; If fast-forward is on, skip the speed-throttle logic
EXTERN_C fast_forward_enabled
 push ecx
 push edx
 call C_LABEL(fast_forward_enabled)
 pop edx
 pop ecx
 test al,al
 mov eax,0
 jnz .fast_forward

; If minimum frameskip set, don't wait for timer to tell us to draw one
 cmp [C_LABEL(FRAME_SKIP_MIN)],eax
 jnz .no_speed_cap

; Wait for timer to tell us to draw a frame
.speed_cap_wait:
 mov ebx,[C_LABEL(Timer_Counter_Throttle)]
 test ebx,ebx
; HLT should be more multi-tasking friendly but appears
; to cause problems with pure DOS in some cases?
 jz .speed_cap_wait    ;speed_cap_wait_hlt

.no_speed_cap:
 mov ebx,[C_LABEL(Timer_Counter_Throttle)]
 cmp ebx,[C_LABEL(FRAME_SKIP_MAX)]
 jb .no_cap_max_skip

.fast_forward:
 mov ebx,[C_LABEL(FRAME_SKIP_MAX)]
 mov [C_LABEL(Timer_Counter_Throttle)],eax  ; Reset speed-throttle timer
 jmp short .have_skip_count

.no_cap_max_skip:
 sub [C_LABEL(Timer_Counter_Throttle)],ebx  ; Update speed-throttle timer

 cmp ebx,[C_LABEL(FRAME_SKIP_MIN)]
 ja .no_cap_min_skip
 mov ebx,[C_LABEL(FRAME_SKIP_MIN)]

.no_cap_min_skip:
.have_skip_count:
 mov [FrameCount],ebx   ; Reset frame counter

%ifdef DEBUG
 inc dword [C_LABEL(Frames)]

%if FRAME_LIMIT
 cmp dword [C_LABEL(Frames)],FRAME_LIMIT
 jne .no_limit
%if FRAME_LIMIT_PROFILE
EXTERN_C Profiler_Start
 mov byte [C_LABEL(Profiler_Start)],1
%else
 ret
%endif
.no_limit:
%endif
%endif

 mov al,[C_LABEL(INIDISP)]
 and al,0x0F
 cmp al,[C_LABEL(BrightnessLevel)]
 je .same_brightness
 mov byte [C_LABEL(PaletteChanged)],1
 mov [C_LABEL(BrightnessLevel)],al
.same_brightness:

.no_redraw:
 mov [HDMA_Next_Event],edi

 xor byte [STAT78],0x80 ; Toggle current field

%ifdef TRAP_HDMA_RELATCH
 pusha
 push byte 0
 call C_LABEL(Dump_DMA)
 pop edi
 popa
 RELATCH_HDMA
 pusha
 push byte 1
 call C_LABEL(Dump_DMA)
 pop edi
 popa
%else
 RELATCH_HDMA
%endif

 Update_FPS_Counter

 pusha
 call C_LABEL(update_sound_block)
 popa

 xor eax,eax
 jmp near CPU_START_IRQ ; Return to CPU

ALIGNC
EXPORT_C IRQFirstRender ; Check HDMA, IRQ, Render
 mov dword [Last_Trip],0

;mov dword [C_LABEL(EventTrip)],CYCLES_DISPLAY_START
 mov dword [FixedTrip],CYCLES_DISPLAY_START
;mov dword [Event_Handler],Render_Event
 mov dword [Fixed_Event],Render_Event
 mov dword [Render_Next_Event],HDMA_Event
 mov dword [Render_Next_Trip],CYCLES_HDMA_START
 mov dword [HDMA_Next_Event],C_LABEL(IRQRender)

 Render_Start_Frame ; Reset framebuffer render address

 Update_Cycles

 mov eax,[C_LABEL(Current_Line_Timing)] ; Get current scanline
 inc eax
 mov [C_LABEL(Current_Line_Timing)],eax
 jmp near CPU_START_IRQ ; Return to CPU

ALIGNC
EXPORT_C IRQRender  ; Check HDMA, IRQ, Render
 mov dword [Last_Trip],0

 Update_Cycles

;mov dword [C_LABEL(EventTrip)],CYCLES_DISPLAY_START
 mov dword [FixedTrip],CYCLES_DISPLAY_START
;mov dword [Event_Handler],Render_Event
 mov dword [Fixed_Event],Render_Event

 mov eax,[C_LABEL(Current_Line_Timing)] ; Get current scanline
 inc eax
 mov [C_LABEL(Current_Line_Timing)],eax
 cmp [C_LABEL(LastRenderLine)],eax
 jbe .end_of_display
 jmp near CPU_START_IRQ ; Return to CPU
ALIGNC
.end_of_display:
 mov eax,[NMI_Event_Handler]
 mov [Render_Next_Event],eax
 mov dword [Render_Next_Trip],CYCLES_NEW_SCANLINE
 jmp near CPU_START_IRQ ; Return to CPU

ALIGNC
VBL_Update_Controllers:
 mov dword [Last_Trip],0

 Update_Cycles

 mov eax,[C_LABEL(Current_Line_Timing)]
 inc eax
 mov [C_LABEL(Current_Line_Timing)],eax
 sub eax,[Vblank_Start]
 cmp eax,byte 3
 jb .no_controller_update

EXTERN_C update_controllers
 call C_LABEL(update_controllers)
 mov dword [Event_Handler],VBL
 mov dword [Fixed_Event],VBL
 and byte [HVBJOY],~HVBJOY_CONTROLLERS_BUSY ; Controllers ready
.no_controller_update:
 mov eax,[C_LABEL(Current_Line_Timing)] ; Get current scanline
 jmp near CPU_START_IRQ ; Return to CPU

ALIGNC
VBL:
 mov dword [Last_Trip],0

 Update_Cycles

 mov eax,[C_LABEL(Current_Line_Timing)] ; Get current scanline
 inc eax
 mov [C_LABEL(Current_Line_Timing)],eax
 cmp [C_LABEL(LastVBLLine)],eax ; Needs adjustment for odd line?
 ja .not_end_of_frame
 mov dword [Event_Handler],IRQNewFrame
 mov dword [Fixed_Event],IRQNewFrame
.not_end_of_frame:
 jmp near CPU_START_IRQ ; Return to CPU

ALIGNC
EXPORT_C IRQFirst   ; Check HDMA, IRQ, Render
 mov dword [Last_Trip],0

;mov dword [C_LABEL(EventTrip)],CYCLES_HDMA_START
 mov dword [FixedTrip],CYCLES_HDMA_START
;mov dword [Event_Handler],HDMA_Event
 mov dword [Fixed_Event],HDMA_Event
 mov dword [HDMA_Next_Event],IRQNoRender

 Render_Start_Frame_Skipped

 Update_Cycles

 mov eax,[C_LABEL(Current_Line_Timing)] ; Get current scanline
 inc eax
 mov [C_LABEL(Current_Line_Timing)],eax
 jmp near CPU_START_IRQ ; Return to CPU

ALIGNC
IRQNoRender:            ; Check HDMA, IRQ
 mov dword [Last_Trip],0

 Update_Cycles

 mov eax,[C_LABEL(Current_Line_Timing)] ; Get current scanline
 inc eax
 mov [C_LABEL(Current_Line_Timing)],eax
 cmp [C_LABEL(LastRenderLine)],eax
 jbe .end_of_display
;mov dword [C_LABEL(EventTrip)],CYCLES_HDMA_START
 mov dword [FixedTrip],CYCLES_HDMA_START
;mov dword [Event_Handler],HDMA_Event
 mov dword [Fixed_Event],HDMA_Event
 jmp near CPU_START_IRQ ; Return to CPU
ALIGNC
.end_of_display:
 mov eax,[NMI_Event_Handler]
 mov [Event_Handler],eax
 mov [Fixed_Event],eax
 jmp near CPU_START_IRQ ; Return to CPU

ALIGNC
EXPORT_C NMI
 UpdateDisplay  ;*
 mov ax,[C_LABEL(Real_SNES_Palette)]
 push eax

 mov al,[C_LABEL(fixedpalettecheck)]
 test al,al
 jz .Do_Copy

.Fixed_Back_Color_Add_Hack:
 mov eax,[C_LABEL(COLDATA)]
%if 1
 push ebx
 mov bx,[C_LABEL(Real_SNES_Palette)]
 push ecx
 push edx
 mov ecx,((1<<5)+(1<<10)+(1<<15))
 mov edx,ebx

 ; get LSBs
 and edx,ecx
 and ebx,~((1<<5)+(1<<10)+(1<<15))
 and ecx,eax
 and eax,~((1<<5)+(1<<10)+(1<<15))
 ; add LSBs
 add ecx,edx
 mov edx,((2<<5)+(2<<10)+(2<<15))
 ; add colors
 add eax,ebx
 and edx,ecx
 mov ebx,((1<<5)+(1<<10)+(1<<15))
 add eax,edx
 and ecx,ebx
 and ebx,eax
 add eax,ecx
 ; Perform saturation

 ; save carry bits
 mov edx,ebx
 ; correct for carry/overflow into LSBs of adjacent color components
 sub eax,ebx
 shr edx,5      ; shift carry bits down to color LSBs
 neg edx        ; subtract from zero to get mask...
 add edx,ebx    ; add in carry bits to correct for borrows
 or eax,edx     ; apply saturation mask

.Add_Hack_End:
 pop edx
 pop ecx
 pop ebx
%endif
 mov [C_LABEL(Real_SNES_Palette)],ax

 mov byte [C_LABEL(PaletteChanged)],1

.Do_Copy:
 cmp byte [C_LABEL(FPS_ENABLED)],0
 jz .no_fps_counter
%ifndef SNEeSe_No_GUI
 call C_LABEL(ShowFPS)
%endif
.no_fps_counter:
 cmp byte [C_LABEL(BREAKS_ENABLED)],0
 jz .no_breaks_counter
%ifndef SNEeSe_No_GUI
 call C_LABEL(ShowBreaks)
%endif
.no_breaks_counter:
 mov dword [C_LABEL(BreaksLast)],0
%ifndef SINGLE_STEP
 call C_LABEL(Copy_Screen)
 mov eax,[C_LABEL(Current_Line_Render)]
 mov [C_LABEL(Last_Frame_Line)],eax
%endif
;call C_LABEL(Display_Debug)

 pop eax
 mov [C_LABEL(Real_SNES_Palette)],ax
EXPORT_C NMI_NoRender
 mov dword [Last_Trip],0

 mov dword [Event_Handler],VBL_Update_Controllers
 mov dword [Fixed_Event],VBL_Update_Controllers
 Update_Cycles

 mov al,[HVBJOY]
 ; VBlank on, controllers being read
 or al,HVBJOY_IN_VBLANK | HVBJOY_CONTROLLERS_BUSY
 mov [HVBJOY],al

 mov al,RDNMI_VBLANK_START | VERSION_NUMBER_5A22
 mov [RDNMI],al         ; Set NMI enabled bit in 0x4210

 mov eax,[C_LABEL(Current_Line_Timing)]
 inc eax
 mov [C_LABEL(Current_Line_Timing)],eax
 mov [Vblank_Start],eax
CheckNMI:
%ifdef DEBUG
 mov al,[CPU_LABEL(PB)]
 mov [C_LABEL(OLD_PB)],al   ; Save program bank
 mov eax,[CPU_LABEL(PC)]
 mov [C_LABEL(OLD_PC)],eax  ; Save program counter
%endif
 test byte [C_LABEL(NMITIMEN)],0x80
 jz .CHECK_KEYS         ; NMI off? (via hardware register)

 ; Neill's timing doc: 19-23 clock delay
;mov dword [C_LABEL(EventTrip)],CYCLES_NMI_DELAY
 mov dword [FixedTrip],CYCLES_NMI_DELAY
;mov dword [Event_Handler],NMI_Event
 mov dword [Fixed_Event],NMI_Event

.CHECK_KEYS:
 call C_LABEL(UPDATE_KEYS)
 test eax,eax
 jnz .break

; Return to emulation
 mov eax,[C_LABEL(Current_Line_Timing)] ; Get current scanline
 jmp near CPU_START_IRQ ; Return to CPU

.break:
;pusha
 mov ebx,[CPU_LABEL(PB_Shifted)]
 mov bx,[CPU_LABEL(PC)]

 LOAD_CYCLES
 GET_BYTE
 mov [C_LABEL(Map_Byte)],al

;popa

 mov eax,[C_LABEL(Current_Line_Timing)] ; Get current scanline
 CheckVIRQ
 ret

ALIGNC
NMI_Event:
 mov eax,[C_LABEL(EventTrip)]
 mov [Last_Trip],eax

;mov dword [C_LABEL(EventTrip)],CYCLES_NEW_SCANLINE
 mov dword [FixedTrip],CYCLES_NEW_SCANLINE
;mov dword [Event_Handler],VBL_Update_Controllers
 mov dword [Fixed_Event],VBL_Update_Controllers

 mov al,[CPU_Execution_Mode]
 cmp al,CEM_Clock_Stopped
 je near .no_nmi
 cmp al,CEM_Waiting_For_Interrupt
 jne .no_wai

%ifdef WAI_DELAY
 ; WAI delay after interrupt signal: 2 IO
 add dword [C_LABEL(SNES_Cycles)],byte 12   ;*
%endif

 inc word [CPU_LABEL(PC)]

 mov byte [CPU_Execution_Mode],CEM_Normal_Execution

.no_wai:
 push edi
 LOAD_BASE
 LOAD_CYCLES
%ifdef FAST_STACK_ACCESS_EMULATION_MODE
 JUMP_NOT_FLAG SNES_FLAG_E,.E0_NMI,near ; Are we in emulation mode?
%else
 JUMP_NOT_FLAG SNES_FLAG_E,.E0_NMI,near ; Are we in emulation mode?
%endif

.E1_NMI:
 ; Emulation mode NMI

 add R_65c816_Cycles,byte 52    ; IRQ processing: 2 IO + 5 bank0

 mov eax,[CPU_LABEL(PC)]
 E1_PUSH_W
;CLR_FLAG SNES_FLAG_B   ; Clear break bit on stack
 E1_SETUPFLAGS 0        ; put flags into SNES packed flag format
;SET_FLAG SNES_FLAG_B
 E1_PUSH_B

 mov eax,[C_LABEL(NMI_Evector)] ; Get Emulation mode NMI vector
;7.12.2 In the Emulation mode, the PBR and DBR registers are cleared to 00
;when a hardware interrupt, BRK or COP is executed. In this case, previous
;contents of the PBR are not automatically saved.
 mov byte [CPU_LABEL(DB)],0

 mov ebx,0xFFFA         ; Get Emulation mode IRQ vector

 jmp .NMI_completion

ALIGNC
.E0_NMI:
 ; Native mode NMI

 add R_65c816_Cycles,byte 60    ; IRQ processing: 2 IO + 6 bank0

 mov al,[CPU_LABEL(PB)]
 E0_PUSH_B
 mov eax,[CPU_LABEL(PC)]
 E0_PUSH_W
 E0_SETUPFLAGS          ; put flags into SNES packed flag format
 E0_PUSH_B

 mov ebx,0xFFEA         ; Get Native mode IRQ vector
.NMI_completion:
 xor eax,eax
 GET_WORD
 mov [CPU_LABEL(PC)],eax    ; Setup PC vector
 mov byte [CPU_LABEL(PB)],0     ; Setup bank
;SET_FLAG SNES_FLAG_I   ; Disable IRQs
 STORE_FLAGS_I 1
%ifndef NO_FASTROM
 mov byte [C_LABEL(CycleTable)],4   ; SlowROM bank
%endif
;CLR_FLAG SNES_FLAG_D   ; Disable decimal mode
 STORE_FLAGS_D 0
 SAVE_CYCLES
 pop edi
.no_nmi:
 call HIRQ_Check_Late   ; chain

 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jl .no_chain
 jmp dword [Event_Handler]
.no_chain:

 jmp near CPU_START

ALIGNC
VIRQ_Event:
 mov eax,[C_LABEL(EventTrip)]
 mov [Last_Trip],eax

 mov dh,0x80        ; V-IRQ
 jmp short HIRQ_Event.do_IRQ

ALIGNC
HIRQ_Event:
 mov eax,[C_LABEL(EventTrip)]
 mov [Last_Trip],eax

 mov dh,0x40        ; H-IRQ
;test dl,0x20      ; Vertical IRQ enabled?
;jz .no_virq
;mov dh,0xC0       ; H+V-IRQ
.do_IRQ:
;mov dh,[C_LABEL(NMITIMEN)]
;and dh,0x30
;shl dh,2
;mov byte [TIMEUP],0x80 ; Set IRQ recv'd flag
 or [IRQ_pin],dh

 mov al,[CPU_Execution_Mode]
 cmp al,CEM_Clock_Stopped
 je .no_irq
 cmp al,CEM_Instruction_After_IRQ_Enable
 je .no_irq
 cmp al,CEM_Waiting_For_Interrupt
 jne .no_wai

%ifdef WAI_DELAY
 ; WAI delay after interrupt signal: 2 IO
 add dword [C_LABEL(SNES_Cycles)],byte 12   ;*
%endif

 inc word [CPU_LABEL(PC)]

 mov byte [CPU_Execution_Mode],CEM_Normal_Execution

.no_wai:
 push edi
 LOAD_BASE
 JUMP_FLAG SNES_FLAG_I,.irq_disabled    ; Interrupts disabled?
 LOAD_CYCLES
 JUMP_NOT_FLAG SNES_FLAG_E,.native_irq
 add R_65c816_Cycles,byte 52    ; IRQ processing: 2 IO + 5 bank0
 call E1_IRQ
 jmp .irq_return
ALIGNC
.native_irq:
 add R_65c816_Cycles,byte 60    ; IRQ processing: 2 IO + 6 bank0
 call E0_IRQ
.irq_return:
 SAVE_CYCLES
.irq_disabled:
 pop edi

.no_irq:
 mov edi,[FixedTrip]
 mov ebx,[Fixed_Event]
 mov [C_LABEL(EventTrip)],edi
 mov [Event_Handler],ebx
 jmp near CPU_START

ALIGNC
; This can only trash ebx/edx!
HIRQ_Check:
 SAVE_CYCLES edx
 push edx
 mov bl,[C_LABEL(NMITIMEN)]
 test bl,0x10       ; H-IRQ enabled?
 jz .no_irq
 test bl,0x20       ; V-IRQ enabled?
 jz .no_virq
 mov edx,[C_LABEL(Current_Line_Timing)]
 cmp [C_LABEL(VTIMEL)],edx
 jne .no_irq
.no_virq:
 mov ebx,[HTimer]
 mov edx,[FixedTrip]
 cmp [esp],ebx      ; Check against current cycle
 jae .past_irq      ; Are we after the IRQ position?
 cmp edx,ebx
 jb .past_irq       ; Next static event is before IRQ?
 mov [C_LABEL(EventTrip)],ebx
 mov dword [Event_Handler],HIRQ_Event
 jmp short .no_irq
.past_irq:
 mov ebx,[Fixed_Event]
 mov [C_LABEL(EventTrip)],edx
 mov [Event_Handler],ebx
.no_irq:
 pop edx
 LOAD_CYCLES
 ret

ALIGNC
; This can only trash ebx/edi!
HIRQ_Check_Late:
 mov bl,[C_LABEL(NMITIMEN)]
 mov edi,[FixedTrip]
 test bl,0x10       ; H-IRQ enabled?
 jz .no_irq
 test bl,0x20       ; V-IRQ enabled?
 jz .no_virq
 mov ebx,[C_LABEL(Current_Line_Timing)]
 cmp [C_LABEL(VTIMEL)],ebx
 jne .no_irq
.no_virq:
 mov ebx,[HTimer]
 cmp [Last_Trip],ebx    ; Check against last event trip cycle
 jae .no_irq        ; Are we after the IRQ?
 cmp edi,ebx
 jb .no_irq         ; Next static event is before IRQ?
 mov [C_LABEL(EventTrip)],ebx
 mov dword [Event_Handler],HIRQ_Event
 ret
.no_irq:
 mov ebx,[Fixed_Event]
 mov [C_LABEL(EventTrip)],edi
 mov [Event_Handler],ebx
 ret

ALIGNC
EXPORT SNES_R2137 ; SLHV  ; This latches the counter for horizontal/vertical data!
 ;counters cannot be latched if I/O port bit 7 held low
 mov al,[C_LABEL(WRIO)]
 and al,[C_LABEL(RDIO)]
 jns .no_change

 push ebx
 GET_CYCLES ebx

 xor edx,edx

 ; Set up H counters to cycles executed / 4, V counter to current scanline

 ; All this below ensures bits 9-15 to be same as bits 1-7
 ; (open bus kludge)
 shr ebx,2
 mov al,0xFE
 cmp ebx,128
 jb .before_refresh
 add ebx,byte 10    ; Adjust for memory refresh cycles
.before_refresh:

 cmp ebx,DOTS_PER_SCANLINE
 jb .before_next_line
 sub ebx,DOTS_PER_SCANLINE
 inc edx            ; Adjust if we're on the next line
.before_next_line:

 and bh,1
 and al,bl
 or bh,al
 mov [Latched_H],ebx    ; Cycles / 4 = rough H counter

 mov ebx,[C_LABEL(Current_Line_Timing)]
 mov al,0xFE
 add ebx,edx        ; fixup for next line

 mov edx,[C_LABEL(LastVBLLine)]
 cmp ebx,edx
 jbe .before_next_frame
 sub ebx,edx        ; fixup for next frame
.before_next_frame:

 and bh,1
 and al,bl
 or bh,al
 mov [Latched_V],ebx

 mov al,0
 pop ebx
 mov [OPHCT],al
 mov [OPVCT],al
.no_change:
 mov al,0x21    ;open bus kludge
 ret

ALIGNC
EXPORT SNES_R213C ; OPHCT
 xor byte [OPHCT],1
 jz .return_high
 mov al,[Latched_H]
 ret
.return_high:
 mov al,[Latched_H+1]
 ret

ALIGNC
EXPORT SNES_R213D ; OPVCT
 xor byte [OPVCT],1
 jz .return_high
 mov al,[Latched_V]
 ret
.return_high:
 mov al,[Latched_V+1]
 ret

; Write to 40xx handlers
ALIGNC
EXPORT SNES_W4016 ; JOYC1
 test al,1
 jnz .no_ready_reset
 push eax
 mov al,[JOYC1]
 test al,1
 jz .no_reset
 mov al,16
 mov [C_LABEL(Controller1_Pos)],al
 mov [C_LABEL(Controller23_Pos)],al
 mov [C_LABEL(Controller45_Pos)],al
.no_reset:
 pop eax
.no_ready_reset:
 mov [JOYC1],al
 ret

ALIGNC
EXPORT SNES_W4017 ; JOYC2
 ret

; Read from 40xx handlers
%if 0
 SNEeSe 0.13, random speculation time, this register or at least bit 0
  handles input for controller 1

 v0.15 17th bit is an indication of joypad connected status

 $4016 is very similar in function (almost identical) to the register at
  the same address on the NES/Famicom

%endif

ALIGNC
EXPORT SNES_R4016 ; JOYC1
 test byte [JOYC1],1
 jz .read_enabled
 mov al,0
 or al,0x40     ;open bus kludge
 ret

.read_enabled:
 push ecx
 push ebx
 cmp byte [C_LABEL(CONTROLLER_1_TYPE)],1    ; Is mouse plugged in?
 je .do_mouse

 mov cl,[C_LABEL(Controller1_Pos)]
 dec cl
 mov ebx,[C_LABEL(JOY1L)]
 mov [C_LABEL(Controller1_Pos)],cl
 ror ebx,cl
 mov al,1
 and al,bl
 pop ebx
 pop ecx
 or al,0x40     ;open bus kludge
 ret

.unused:
 mov byte [C_LABEL(Controller1_Pos)],16
 mov al,1           ; Joypad connected
 pop ebx
 pop ecx
 or al,0x40     ;open bus kludge
 ret

ALIGNC
.do_mouse:
 mov cl,[C_LABEL(Controller1_Pos)]
 dec cl
 and cl,0x0F
 mov [C_LABEL(Controller1_Pos)],cl
 mov bx,[C_LABEL(MickeyRead)]
 shr bx,cl
 mov al,1
 and al,bl
 pop ebx
 pop ecx
 or al,0x40     ;open bus kludge
 ret

ALIGNC
EXPORT SNES_R4017 ; JOYC2
 test byte [JOYC1],1
 jz .read_enabled
 mov al,0
 or al,0x5C     ;open bus kludge
 ret

.read_enabled:
 push ecx
 push ebx
 cmp byte [C_LABEL(CONTROLLER_2_TYPE)],1    ; Is mouse plugged in?
 je .do_mouse

 mov cl,[C_LABEL(Controller23_Pos)]
 dec cl
 mov ebx,[C_LABEL(JOY2L)]
 mov [C_LABEL(Controller23_Pos)],cl
 ror ebx,cl
 mov al,bl
 and al,1
 pop ebx
 pop ecx
 or al,0x5C     ;open bus kludge
 ret

.unused:
 mov byte [C_LABEL(Controller23_Pos)],16
 mov al,1           ; (???) Return 0 this bit is for mtap I think
 pop ebx
 pop ecx
 or al,0x5C     ;open bus kludge
 ret

ALIGNC
.do_mouse:
 mov cl,[C_LABEL(Controller23_Pos)]
 dec cl
 and cl,0x0F
 mov [C_LABEL(Controller23_Pos)],cl
 mov bx,[C_LABEL(MickeyRead)]
 shr bx,cl
 mov al,bl
 and al,1
 pop ebx
 pop ecx
 or al,0x5C     ;open bus kludge
 ret


; Read from 42xx handlers
ALIGNC
EXPORT SNES_R4200 ; NMITIMEN
 mov al,[C_LABEL(NMITIMEN)]
 ret

ALIGNC
EXPORT SNES_R4202 ; WRMPYA
 mov al,[WRMPYA]
 ret

ALIGNC
EXPORT SNES_R4203 ; WRMPYB
 mov al,[WRMPYB]
 ret

ALIGNC
EXPORT SNES_R4210 ; RDNMI
 mov al,[RDNMI]
 or al,0x40     ;open bus kludge
 mov byte [RDNMI],VERSION_NUMBER_5A22   ; NMI on/off + version #
 ret

ALIGNC
EXPORT SNES_R4211 ; TIMEUP
 ; Should return bit 7 set if IRQ active, bit 6 set if cur line = V count
;mov al,[TIMEUP]
;mov byte [TIMEUP],0
 mov al,[IRQ_pin]
 test al,0xC0
 jz .no_irq
 mov al,0x80
 and byte [IRQ_pin],0x1F    ; Clear H/V IRQ
.no_irq:

 or al,0x42     ;open bus kludge

 ret

ALIGNC
EXPORT SNES_R4212 ; HVBJOY
; Excerpts: Neill Corlett's "SNES Timing: The Brutal Truth" Version: 1.0b
;  <-22 dots-> <------------256 dots--------------> <-62 dots->
; 5. Something freaky
; -------------------
; On every scanline, starting at dot 128, the CPU appears to be frozen for 40
; master cycles.  DMA is also apparently frozen during this time.  This happens
; whether the scanline is visible or not, and whether HDMA is enabled or not.
;
; My current theory is that this time is used for refreshing RAM.
; *End excerpts*
 GET_CYCLES edx
 mov al,[HVBJOY]
 cmp edx,CYCLES_HBLANK_START    ; Hblank after display
 jae .hblank
 cmp edx,CYCLES_DISPLAY_START   ; Hblank before display
 jae .no_hblank
.hblank:
 or al,HVBJOY_IN_HBLANK ; We're in Hblank...
.no_hblank:

 or al,0x02     ;open bus kludge
 ret

ALIGNC
EXPORT SNES_R4213 ; RDIO
 mov al,[C_LABEL(RDIO)]
 and al,[C_LABEL(WRIO)]
 ret

ALIGNC
EXPORT SNES_R4214 ; RDDIVL
 mov al,[RDDIVL]
 ret

ALIGNC
EXPORT SNES_R4215 ; RDDIVH
 mov al,[RDDIVH]
 ret

ALIGNC
EXPORT SNES_R4216 ; RDMPYL
 mov al,[RDMPYL]
 ret

ALIGNC
EXPORT SNES_R4217 ; RDMPYH
 mov al,[RDMPYH]
 ret

ALIGNC
EXPORT SNES_R4218 ; JOY1L
 cmp byte [C_LABEL(CONTROLLER_1_TYPE)],1    ; Is mouse plugged in?
 je .mouse
 mov al,[C_LABEL(JOY1L)]
 ret

.mouse:
 mov al,[C_LABEL(MouseButtons)]
 or al,0x01
 ret

ALIGNC
EXPORT SNES_R4219 ; JOY1H
 mov al,[C_LABEL(JOY1H)]
 ret

ALIGNC
EXPORT SNES_R421A ; JOY2L
 cmp byte [C_LABEL(CONTROLLER_2_TYPE)],1    ; Is mouse plugged in?
 je .mouse
 mov al,[C_LABEL(JOY2L)]
 ret

.mouse:
 mov al,[C_LABEL(MouseButtons)]
 or al,0x01
 ret

ALIGNC
EXPORT SNES_R421B ; JOY2H
 mov al,[C_LABEL(JOY2H)]
 ret

ALIGNC
EXPORT SNES_R421C ; JOY3L
 mov al,[C_LABEL(JOY3L)]
 ret

ALIGNC
EXPORT SNES_R421D ; JOY3H
 mov al,[C_LABEL(JOY3H)]
 ret

ALIGNC
EXPORT SNES_R421E ; JOY4L
 mov al,[C_LABEL(JOY4L)]
 ret

ALIGNC
EXPORT SNES_R421F ; JOY4H
 mov al,[C_LABEL(JOY4H)]
 ret

; Write to 42xx handlers
ALIGNC
EXPORT SNES_W4200 ; NMITIMEN
; a0yx000b  a=NMI on/off,y=vert count,x=horiz count,b=joy read
 cmp [C_LABEL(NMITIMEN)],al
 je .no_change
 push ebx
 mov bl,[C_LABEL(NMITIMEN)]
 mov [C_LABEL(NMITIMEN)],al
 xor bl,al
 and bl,0x30
 jz .no_irq_change
 call HIRQ_Check
.no_irq_change:
 pop ebx
.no_change:
 and byte [IRQ_pin],0x1F
 ret

ALIGNC
EXPORT SNES_W4201 ; WRIO
 mov dl,[C_LABEL(WRIO)]
 cmp dl,al
 je .no_change

 push eax
 xor dl,al
 jns .no_latch

 test al,al
 js .no_latch

 call SNES_R2137
.no_latch:

 pop eax
 mov [C_LABEL(WRIO)],al
.no_change:
 ret

ALIGNC
EXPORT SNES_W4202 ; WRMPYA
 mov [WRMPYA],al
 ret

ALIGNC
EXPORT SNES_W4203 ; WRMPYB
 push eax
 mov [WRMPYB],al
 mul byte [WRMPYA]  ; Do the multiplication
 mov [RDMPY],ax
 pop eax
 ret

ALIGNC
EXPORT SNES_W4204 ; WRDIVL
 mov [WRDIVL],al
 ret

ALIGNC
EXPORT SNES_W4205 ; WRDIVH
 mov [WRDIVH],al
 ret

ALIGNC
EXPORT SNES_W4206 ; WRDIVB
 push eax
 push ebx
;push edx
 test al,al
 jz .divide_by_zero
 xor ebx,ebx
 xor edx,edx    ; Divide uses DX:AX / BX
 mov bl,al
 mov ax,[WRDIV]
 div bx         ; Result is ax=quotient,dx=remainder
 mov [RDDIV],ax
 mov [RDMPY],dx
;pop edx
 pop ebx
 pop eax
 ret

.divide_by_zero:
 mov ax,[WRDIV]
 mov [RDMPY],ax
 mov word [RDDIV],0xFFFF
;pop edx
 pop ebx
 pop eax
 ret

ALIGNC
EXPORT SNES_W4207 ; HTIMEL
 push ebx
 mov ebx,[C_LABEL(HTIMEL)]
 cmp al,bl
 je .no_change
 mov bl,al
 mov [C_LABEL(HTIMEL)],ebx

 cmp ebx,DOTS_PER_SCANLINE
 jae .Invalid_HTimer

 shl ebx,2

 ; Do some magic for the memory refresh 'missing' cycles
 cmp ebx,CYCLES_REFRESH_START   ; Before memory refresh
 jb .not_in_refresh
 cmp ebx,CYCLES_REFRESH_END     ; During memory refresh
 jb .in_refresh
 sub ebx,byte CYCLES_IN_REFRESH
 jmp short .not_in_refresh
ALIGNC
.in_refresh:
 mov ebx,CYCLES_REFRESH_START   ; During memory refresh
.not_in_refresh:
 mov [HTimer],ebx
 test byte [C_LABEL(NMITIMEN)],0x10
 jz .no_change
 call HIRQ_Check
.no_change:
 pop ebx
 ret

ALIGNC
.Invalid_HTimer:
 mov dword [HTimer],-1
 pop ebx
 ret

ALIGNC
EXPORT SNES_W4208 ; HTIMEH
 push eax
 push ebx
 mov ebx,[C_LABEL(HTIMEL)]
 and al,1
 and bh,1
 cmp al,bh
 je .no_change
 mov bh,al
 mov [C_LABEL(HTIMEL)],ebx

 cmp ebx,DOTS_PER_SCANLINE
 jae .Invalid_HTimer

 shl ebx,2

 ; Do some magic for the memory refresh 'missing' cycles
 cmp ebx,CYCLES_REFRESH_START   ; Before memory refresh
 jb .not_in_refresh
 cmp ebx,CYCLES_REFRESH_END     ; During memory refresh
 jb .in_refresh
 sub ebx,byte CYCLES_IN_REFRESH
 jmp short .not_in_refresh
ALIGNC
.in_refresh:
 mov ebx,CYCLES_REFRESH_START   ; During memory refresh
.not_in_refresh:
 mov [HTimer],ebx
 test byte [C_LABEL(NMITIMEN)],0x10
 jz .no_change
 call HIRQ_Check
.no_change:
 pop ebx
 pop eax
 ret

ALIGNC
.Invalid_HTimer:
 mov dword [HTimer],-1
 pop ebx
 pop eax
 ret

ALIGNC
EXPORT SNES_W4209 ; VTIMEL
 push ebx
 mov ebx,[C_LABEL(VTIMEL)]
 cmp al,bl
 je .no_change
 mov [C_LABEL(VTIMEL)],al
 test byte [C_LABEL(NMITIMEN)],0x20
 jz .no_change
 call HIRQ_Check
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W420A ; VTIMEH   ; Handled in screen core!
 push eax
 push ebx
 mov ebx,[C_LABEL(VTIMEL)]
 and al,1
 and bh,1
 cmp al,bh
 je .no_change
 mov [C_LABEL(VTIMEH)],al
 test byte [C_LABEL(NMITIMEN)],0x20
 jz .no_change
 call HIRQ_Check
.no_change:
 pop ebx
 pop eax
 ret

ALIGNC
EXPORT SNES_W420D ; MEMSEL    ; FastROM switch
%ifndef NO_FASTROM
 push eax
 and al,1
 shl al,7               ; Set bit 7 to switch flag

 test [CPU_LABEL(PB_Shifted)+2],al   ; Check bus speed against PB
 mov [MEMSEL],al
 mov al,[C_LABEL(FastROM_offset)]
 jnz .fastrom
 mov al,4
.fastrom:
 mov [C_LABEL(CycleTable)],al   ; Update bus speed

 pop eax
%endif
 push eax
 push ecx
 push edx
 push eax
EXTERN_C set_upper_rom_speed
 call C_LABEL(set_upper_rom_speed)
 pop eax
 pop edx
 pop ecx
 pop eax
 ret
