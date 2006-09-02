%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2006, Charles Bilyue'.
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

;%define REPORT_EVENTS
;%define DEBUG_IRQ

%define ZERO_TRIP_CYCLE_COUNTER


%define JOYC1_OPEN_BUS_BITS BITMASK(2,7)
%define JOYC2_OPEN_BUS_BITS BITMASK(5,7)
%define JOYC2_ALWAYS_HIGH_BITS BITMASK(2,4)

%define RDNMI_OPEN_BUS_BITS BITMASK(4,6)
%define TIMEUP_OPEN_BUS_BITS BITMASK(6,0)
%define HVBJOY_OPEN_BUS_BITS BITMASK(1,5)

%define RDNMI_VBLANK_START BIT(7)
%define HVBJOY_IN_VBLANK BIT(7)
%define HVBJOY_IN_HBLANK BIT(6)
%define HVBJOY_CONTROLLERS_BUSY BIT(0)

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
EXPORT Controller1_Pos  ,skipb  ; Shift count for controller 1 read
EXPORT Controller23_Pos ,skipb  ; Shift count for controller 2/3 read
EXPORT Controller45_Pos ,skipb  ; Shift count for controller 4/5 read

ALIGNB
; These are updated per VBL rather than per read!
EXPORT JOY1L,skipb
EXPORT JOY1H,skipb 3
EXPORT JOY2L,skipb
EXPORT JOY2H,skipb 3
; These are not updated yet
EXPORT JOY3L,skipb
EXPORT JOY3H,skipb 3
EXPORT JOY4L,skipb
EXPORT JOY4H,skipb 3

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

EXPORT LastRenderLine   ,skipl
EXPORT LastVBLLine      ,skipl

EXPORT FrameCount       ,skipl  ; Used for frameskipping
EXPORT Event_Handler    ,skipl  ; Used for render/HDMA timing/NMI/IRQ
EXPORT Fixed_Event      ,skipl  ; Used for render/HDMA timing
EXPORT Last_Trip        ,skipl  ; Clock cycle position of last scheduled event

HDMA_Next_Event:    skipl   ; Fixed event following HDMA

DMA_Next_Event:     skipl   ; Fixed event following DMA
DMA_Next_Trip:      skipl

Render_Next_Event:  skipl   ; Fixed event following render
Render_Next_Trip:   skipl

NMI_Event_Handler:  skipl   ; Event handler for Vblank start
NMI_Next_Event:     skipl   ; Fixed event following render
NMI_Next_Trip:      skipl

Vblank_Start:       skipl   ; Scanline of last Vblank start
EXPORT HTimer           ,skipl  ; IRQ position on scanline
EXPORT HTimer_Set       ,skipl  ; H-IRQ position set in $4207-8

EXPORT HTIMEL   ,skipb  ; H IRQ position low
EXPORT HTIMEH   ,skipb  ; H IRQ position high
                 skipb
                 skipb
EXPORT VTIMEL   ,skipb  ; V IRQ position low
EXPORT VTIMEH   ,skipb  ; V IRQ position high
                 skipb
                 skipb

FPSCount:       skipl   ; Count of frames executed this second
EXPORT FPSMaxTicks  ,skipl  ; Number of timer ticks after which FPS is calc'd
EXPORT FPSLast      ,skipl  ; Calculated FPS for last second
EXPORT BreaksLast   ,skipl  ; Render breaks for last frame

Latched_H:  skipl   ; These two are latched values!
Latched_V:  skipl

MEMSEL:     skipb   ; FastROM switch
EXPORT OPHCT,skipb  ; Whether reading lo or high byte
EXPORT OPVCT,skipb  ; Whether reading lo or high byte
RDNMI:      skipb   ; x000vvvv  x=disable/enable NMI,vvvv=version

;mask for RDNMI - (only) bit 7 cleared if NMI source raised and cleared
; during this frame
RDNMI_mask:skipb

EXPORT NMITIMEN,skipb   ; a0yx000b  a=NMI on/off,y=vert count,x=horiz count,b=joy read
; I/O port register - bit 7 affects H/V counter, all bits used for output
EXPORT WRIO,skipb       ; lxxxxxxx  l=counter latched when set
; I/O port register - value CPU is receiving
; RDIO register reads return this value ANDed with value in WRIO
EXPORT RDIO,skipb
EXPORT HVBJOY,skipb
; Nonzero if an IRQ set for current line has not been reached yet
;IRQ_set_this_line:skipb

IRQ_fired_this_line:skipb

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
 jmp %%less_than_1_fps
%%fps_update:
 mov [C_LABEL(FPSLast)],edx
%%less_than_1_fps:
 mov [C_LABEL(FPSTicks)],eax
 mov [FPSCount],eax
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

 mov byte [IRQ_fired_this_line],0

 inc dword [FPSCount]           ; For FPS counter - 0.25b14

;%define TRAP_HDMA_RELATCH
%ifdef TRAP_HDMA_RELATCH
EXTERN_C Dump_DMA
 pusha
 push byte 0
 call C_LABEL(Dump_DMA)
 pop edi
 popa
 LOAD_CYCLES
 call init_HDMA
 SAVE_CYCLES
 pusha
 push byte 1
 call C_LABEL(Dump_DMA)
 pop edi
 popa
%else
 LOAD_CYCLES
 call init_HDMA
 SAVE_CYCLES
%endif

 Update_FPS_Counter
 ret


%macro report_event 0
%ifdef REPORT_EVENTS
 push 8
 push dword [C_LABEL(EventTrip)]
 call C_LABEL(print_hexnum)

 push gap_str
 call C_LABEL(print_str)

 push 8
 push dword [C_LABEL(SNES_Cycles)]
 call C_LABEL(print_hexnum)

 push .str
 call C_LABEL(print_str)

 push dword [C_LABEL(Current_Line_Timing)]
 call C_LABEL(print_decnum)

 push nl_str
 call C_LABEL(print_str)
 add esp,4*8
%endif
%endmacro

ALIGNC
HDMA_Event:
section .data
.str:db " HDMA ",0
section .text

 report_event

 mov eax,[C_LABEL(EventTrip)]
 mov [Last_Trip],eax

 mov eax,[HDMA_Next_Event]
;mov dword [C_LABEL(EventTrip)],CYCLES_NEW_SCANLINE
 mov dword [FixedTrip],CYCLES_NEW_SCANLINE
;mov [Event_Handler],eax
 mov [Fixed_Event],eax
 LOAD_CYCLES
 call do_HDMA
 SAVE_CYCLES
%ifdef TRAP_HDMA_RELATCH
 pusha
 push byte 2
 call C_LABEL(Dump_DMA)
 pop edi
 popa
%endif
 call IRQ_Check_Late    ; chain

 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jl .no_chain
 jmp dword [Event_Handler]
.no_chain:

 jmp CPU_START  ; Return to CPU

ALIGNC
Enabling_IRQ_Event:
section .data
.str:db " enabling IRQ ",0
section .text

 report_event

 cmp byte [NMI_pin],NMI_Raised
 je .nmi_waiting

 mov al,CEM_Instruction_After_IRQ_Enable
 mov [CPU_Execution_Mode],al

.nmi_waiting:
 call IRQ_Check_Late    ; chain

 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jl .no_chain
 jmp dword [Event_Handler]
.no_chain:
 jmp CPU_START  ; Return to CPU

ALIGNC
IRQ_Enabled_Event:
section .data
.str:db " enabled IRQ ",0
section .text

 report_event

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
 cmp al,CEM_In_DMA
 je .no_irq
 cmp al,CEM_Clock_Stopped
 je .no_irq
 cmp al,CEM_Waiting_For_Interrupt
 jne .no_wai

%ifdef WAI_DELAY
 ; WAI delay after interrupt signal: 2 IO
 add dword [C_LABEL(SNES_Cycles)],_5A22_FAST_CYCLE * 2
%endif

 inc word [CPU_LABEL(PC)]

 mov byte [CPU_Execution_Mode],CEM_Normal_Execution

.no_wai:
 push edi
 LOAD_BASE
 JUMP_FLAG SNES_FLAG_I,.irq_disabled    ; Interrupts disabled?
 LOAD_PC
 LOAD_CYCLES

 GET_PBPC ebx
 GET_BYTE               ; Get opcode

 add R_Cycles,_5A22_FAST_CYCLE   ; hwint processing: 1 IO
 JUMP_NOT_FLAG SNES_FLAG_E,.native_irq
 call E1_IRQ
 jmp .irq_return
ALIGNC
.native_irq:
 call E0_IRQ
.irq_return:
 SAVE_CYCLES
.irq_disabled:
 pop edi

.no_irq:
 call IRQ_Check_Late    ; chain

 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jl .no_chain
 jmp dword [Event_Handler]
.no_chain:
 jmp CPU_START  ; Return to CPU

ALIGNC
DMA_Event:
section .data
.str:db " DMA ",0
section .text

 report_event

 mov byte [CPU_Execution_Mode],CEM_In_DMA

 ;2 slow bus cycle setup period
 add dword [C_LABEL(SNES_Cycles)],byte (2 * _5A22_SLOW_CYCLE)

 mov eax,[DMA_Next_Event]
 mov [Fixed_Event],eax
 mov eax,[DMA_Next_Trip]
 mov [FixedTrip],eax

 call IRQ_Check_Late    ; chain

 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jl .no_chain
 jmp dword [Event_Handler]
.no_chain:

 jmp CPU_START  ; Return to CPU

ALIGNC
Render_Event:
section .data
.str:db " render ",0
section .text

 report_event

 mov eax,[C_LABEL(EventTrip)]
 mov [Last_Trip],eax

 mov eax,[Render_Next_Event]
;mov [Event_Handler],eax
 mov [Fixed_Event],eax
 mov eax,[Render_Next_Trip]
;mov [C_LABEL(EventTrip)],eax
 mov [FixedTrip],eax
 RenderScanline
 call IRQ_Check_Late    ; chain

 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jl .no_chain
 jmp dword [Event_Handler]
.no_chain:

 jmp CPU_START  ; Return to CPU

ALIGNC
speed_cap_wait_hlt:
 hlt
 jmp IRQNewFrame.speed_cap_wait
ALIGNC
EXPORT IRQNewFrame              ; Check IRQ, Frame Skip
section .data
.str:db " new frame ",0
section .text

 report_event

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
 UpdateSPCTimer 0
 UpdateSPCTimer 1
 UpdateSPCTimer 2

 call C_LABEL(update_sound) ; Added by Butcha

;mov dword [C_LABEL(EventTrip)],CYCLES_HDMA_START
 mov dword [FixedTrip],CYCLES_HDMA_START
;mov dword [Event_Handler],HDMA_Event
 mov dword [Fixed_Event],HDMA_Event

 mov al,[HVBJOY]
 and al,~HVBJOY_IN_VBLANK   ; VBlank off
 mov [HVBJOY],al

 mov byte [RDNMI_mask],~0
 mov byte [RDNMI],VERSION_NUMBER_5A22   ; Clear NMI enabled bit in 0x4210
 mov byte [NMI_pin],NMI_None            ;clear NMI input

extern C_LABEL(Reload_OBSEL)
 call C_LABEL(Reload_OBSEL)

 xor eax,eax
 dec dword [FrameCount] ; Should we redraw the screen this frame?

 mov [C_LABEL(Current_Line_Timing)],eax ; Reset scanline counter

 mov byte [IRQ_fired_this_line],0

 mov edi,C_LABEL(IRQFirst)
 jnz .no_redraw

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
 jnz .no_speed_cap
 push ecx
 push edx
EXTERN C_LABEL(platform_yield)
 call C_LABEL(platform_yield)
 pop edx
 pop ecx
 jmp .speed_cap_wait    ;speed_cap_wait_hlt

.no_speed_cap:
 mov ebx,[C_LABEL(Timer_Counter_Throttle)]
 cmp ebx,[C_LABEL(FRAME_SKIP_MAX)]
 jb .no_cap_max_skip

.fast_forward:
 mov ebx,[C_LABEL(FRAME_SKIP_MAX)]
 mov [C_LABEL(Timer_Counter_Throttle)],eax  ; Reset speed-throttle timer
 jmp .have_skip_count

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
 LOAD_CYCLES
 call init_HDMA
 SAVE_CYCLES
 pusha
 push byte 1
 call C_LABEL(Dump_DMA)
 pop edi
 popa
%else
 LOAD_CYCLES
 call init_HDMA
 SAVE_CYCLES
%endif

 Update_FPS_Counter

 pusha
 call C_LABEL(update_sound_block)
 popa

 xor eax,eax
 jmp CPU_START_IRQ      ; Return to CPU

ALIGNC
EXPORT IRQFirstRender   ; Check HDMA, IRQ, Render
section .data
.str:db " irqfirstrender ",0
section .text

 report_event

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

 mov byte [IRQ_fired_this_line],0

 jmp CPU_START_IRQ      ; Return to CPU

ALIGNC
EXPORT IRQRender    ; Check HDMA, IRQ, Render
section .data
.str:db " irqrender ",0
section .text

 report_event

 mov dword [Last_Trip],0

 Update_Cycles

;mov dword [C_LABEL(EventTrip)],CYCLES_DISPLAY_START
 mov dword [FixedTrip],CYCLES_DISPLAY_START
;mov dword [Event_Handler],Render_Event
 mov dword [Fixed_Event],Render_Event

 mov eax,[C_LABEL(Current_Line_Timing)] ; Get current scanline
 inc eax
 mov [C_LABEL(Current_Line_Timing)],eax

 mov byte [IRQ_fired_this_line],0

 cmp [C_LABEL(LastRenderLine)],eax
 ja CPU_START_IRQ       ; Return to CPU
.end_of_display:
 mov eax,[NMI_Event_Handler]
 mov [HDMA_Next_Event],eax
;mov [Render_Next_Event],eax
;mov dword [Render_Next_Trip],CYCLES_NEW_SCANLINE
 jmp CPU_START_IRQ      ; Return to CPU

ALIGNC
VBL_Update_Controllers:
section .data
.str:db " update controllers ",0
section .text

 report_event

 mov dword [Last_Trip],0

 Update_Cycles

 mov eax,[C_LABEL(Current_Line_Timing)]
 inc eax
 mov [C_LABEL(Current_Line_Timing)],eax

 mov byte [IRQ_fired_this_line],0

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
 jmp CPU_START_IRQ      ; Return to CPU

ALIGNC
VBL:
section .data
.str:db " vblank ",0
section .text

 report_event

 mov dword [Last_Trip],0

 Update_Cycles

 mov eax,[C_LABEL(Current_Line_Timing)] ; Get current scanline
 inc eax
 mov [C_LABEL(Current_Line_Timing)],eax

 mov byte [IRQ_fired_this_line],0

 cmp [C_LABEL(LastVBLLine)],eax ; Needs adjustment for odd line?
 ja .not_end_of_frame
 mov dword [Event_Handler],IRQNewFrame
 mov dword [Fixed_Event],IRQNewFrame
.not_end_of_frame:
 jmp CPU_START_IRQ      ; Return to CPU

ALIGNC
EXPORT IRQFirst     ; Check HDMA, IRQ, Render
section .data
.str:db " irqfirst ",0
section .text

 report_event

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

 mov byte [IRQ_fired_this_line],0

 jmp CPU_START_IRQ      ; Return to CPU

ALIGNC
IRQNoRender:            ; Check HDMA, IRQ
section .data
.str:db " irqnorender ",0
section .text

 report_event

 mov dword [Last_Trip],0

 Update_Cycles

;mov dword [C_LABEL(EventTrip)],CYCLES_HDMA_START
 mov dword [FixedTrip],CYCLES_HDMA_START
;mov dword [Event_Handler],HDMA_Event
 mov dword [Fixed_Event],HDMA_Event

 mov eax,[C_LABEL(Current_Line_Timing)] ; Get current scanline
 inc eax
 mov [C_LABEL(Current_Line_Timing)],eax

 mov byte [IRQ_fired_this_line],0

 cmp [C_LABEL(LastRenderLine)],eax
 ja CPU_START_IRQ       ; Return to CPU
.end_of_display:
 mov eax,[NMI_Event_Handler]
 mov [HDMA_Next_Event],eax
;mov [Event_Handler],eax
;mov [Fixed_Event],eax
 jmp CPU_START_IRQ      ; Return to CPU

ALIGNC
EXPORT NMI
 UpdateDisplay  ;*

%ifndef SINGLE_STEP
 call C_LABEL(Copy_Screen)
 mov eax,[C_LABEL(Current_Line_Render)]
 mov [C_LABEL(Last_Frame_Line)],eax
%endif
;call C_LABEL(Display_Debug)

EXPORT NMI_NoRender
section .data
.str:db " nmi_norender ",0
section .text

 report_event

 mov dword [Last_Trip],0

 mov dword [Event_Handler],VBL_Update_Controllers
 mov dword [Fixed_Event],VBL_Update_Controllers
 Update_Cycles

 mov al,[HVBJOY]
 ; VBlank on, controllers being read
 or al,HVBJOY_IN_VBLANK | HVBJOY_CONTROLLERS_BUSY
 mov [HVBJOY],al

 mov al,RDNMI_VBLANK_START | VERSION_NUMBER_5A22
 and al,[RDNMI_mask]    ; ensure only one vblank NMI per frame
 mov [RDNMI],al         ; Set NMI enabled bit in 0x4210

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

 mov eax,[C_LABEL(Current_Line_Timing)]
 inc eax
 mov [C_LABEL(Current_Line_Timing)],eax

 mov byte [IRQ_fired_this_line],0

 mov [Vblank_Start],eax
CheckNMI:
%ifdef DEBUG
 mov al,[CPU_LABEL(PB)]
 mov [C_LABEL(OLD_PB)],al   ; Save program bank
 mov eax,[CPU_LABEL(PC)]
 mov [C_LABEL(OLD_PC)],eax  ; Save program counter
%endif
 cmp byte [NMI_pin],NMI_Raised  ;NMI input raised previously?
 je .setup_nmi

 cmp byte [NMI_pin],NMI_Acknowledged
 jz .CHECK_KEYS

 test byte [RDNMI],RDNMI_VBLANK_START
 jz .CHECK_KEYS

 test byte [C_LABEL(NMITIMEN)],0x80
 jz .CHECK_KEYS         ; NMI off? (via hardware register)

 cmp byte [CPU_Execution_Mode],CEM_In_DMA
 je .CHECK_KEYS

 mov byte [NMI_pin],NMI_Raised          ;raise NMI input

.setup_nmi:
 ;setup chain to next timing event
 mov eax,[Fixed_Event]
 mov edx,[FixedTrip]
 mov [NMI_Next_Event],eax
 mov [NMI_Next_Trip],edx

 ;NMI executes after one opcode
 mov eax,[C_LABEL(SNES_Cycles)]
 inc eax
 mov [FixedTrip],eax
 mov [C_LABEL(EventTrip)],eax
 mov eax,NMI_Event
 mov [Fixed_Event],eax
 mov [Event_Handler],eax

.CHECK_KEYS:
 call C_LABEL(UPDATE_KEYS)
 test eax,eax
 jnz .break



; Return to emulation
 mov eax,[C_LABEL(Current_Line_Timing)] ; Get current scanline
 jmp CPU_START_IRQ      ; Return to CPU

.break:
 mov ebx,[CPU_LABEL(PB_Shifted)]
 mov bx,[CPU_LABEL(PC)]

 LOAD_CYCLES
 GET_BYTE
 mov [C_LABEL(Map_Byte)],al


 mov eax,[C_LABEL(Current_Line_Timing)] ; Get current scanline
 call IRQ_Check_Newline
 
.no_irq_check:
 ret


ALIGNC
NMI_Setup_Event:
section .data
.str:db " nmi setup ",0
section .text

 report_event

 ;NMI executes after one opcode
 mov eax,[C_LABEL(SNES_Cycles)]
 inc eax
 mov [FixedTrip],eax
 mov [C_LABEL(EventTrip)],eax
 mov eax,NMI_Event
 mov [Fixed_Event],eax
 mov [Event_Handler],eax

 jmp CPU_START.execute_opcode


ALIGNC
NMI_Event:
section .data
.str:db " nmi ",0
section .text

 report_event

 mov eax,[NMI_Next_Event]
 mov [Fixed_Event],eax
 mov eax,[NMI_Next_Trip]
 mov [FixedTrip],eax

 mov al,[CPU_Execution_Mode]
 cmp al,CEM_In_DMA
 je .no_nmi
 cmp al,CEM_Clock_Stopped
 je .no_nmi
 cmp al,CEM_Waiting_For_Interrupt
 jne .no_wai

%ifdef WAI_DELAY
 ; WAI delay after interrupt signal: 2 IO
 add dword [C_LABEL(SNES_Cycles)],_5A22_FAST_CYCLE * 2
%endif

 inc word [CPU_LABEL(PC)]

 mov byte [CPU_Execution_Mode],CEM_Normal_Execution

.no_wai:
 mov byte [NMI_pin],NMI_Acknowledged    ;acknowledge NMI input

 push edi
 LOAD_PC
 LOAD_CYCLES
 LOAD_BASE

 GET_PBPC ebx
 GET_BYTE               ; Get opcode
 add R_Cycles,_5A22_FAST_CYCLE   ; hwint processing: 1 IO
 JUMP_NOT_FLAG SNES_FLAG_E,.E0_NMI      ; Are we in emulation mode?

.E1_NMI:
 ; Emulation mode NMI

 mov eax,[CPU_LABEL(PC)]
 E1_PUSH_W
;CLR_FLAG SNES_FLAG_B   ; Clear break bit on stack
 E1_SETUPFLAGS 0        ; put flags into SNES packed flag format
;SET_FLAG SNES_FLAG_B
 E1_PUSH_B

 mov ebx,0xFFFA         ; Get Emulation mode IRQ vector

 jmp .NMI_completion

ALIGNC
.E0_NMI:
 ; Native mode NMI

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
;CLR_FLAG SNES_FLAG_D   ; Disable decimal mode
 STORE_FLAGS_D 0
 SAVE_CYCLES
 pop edi
.no_nmi:
 call IRQ_Check_Late    ; chain

 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jl .no_chain
 jmp dword [Event_Handler]
.no_chain:

 jmp CPU_START  ; Return to CPU

ALIGNC
IRQ_Event:
section .data
.str:db " irq ",0
section .text

 report_event

 mov eax,[C_LABEL(EventTrip)]
 mov [Last_Trip],eax

%ifdef DEBUG_IRQ
 pusha
 LOAD_CYCLES
 GET_CYCLES eax
 push eax

 push dword irqfire_str
 call C_LABEL(print_str)
 add esp,4

 call C_LABEL(print_decnum)

 push dword comma_str
 call C_LABEL(print_str)

 push dword [C_LABEL(Current_Line_Timing)]
 call C_LABEL(print_decnum)

 push nl_str
 call C_LABEL(print_str)
 add esp,4*4
 popa
%endif

 mov dh,0x80        ; Internal IRQ
 mov [IRQ_fired_this_line],dh
 or [IRQ_pin],dh

 mov al,[CPU_Execution_Mode]
 cmp al,CEM_In_DMA
 je .no_irq
 cmp al,CEM_Clock_Stopped
 je .no_irq
 cmp al,CEM_Instruction_After_IRQ_Enable
 je .no_irq
 cmp al,CEM_Waiting_For_Interrupt
 jne .no_wai

%ifdef WAI_DELAY
 ; WAI delay after interrupt signal: 2 IO
 add dword [C_LABEL(SNES_Cycles)],_5A22_FAST_CYCLE * 2
%endif

 inc word [CPU_LABEL(PC)]

 mov byte [CPU_Execution_Mode],CEM_Normal_Execution

.no_wai:
 push edi
 LOAD_BASE
 JUMP_FLAG SNES_FLAG_I,.irq_disabled    ; Interrupts disabled?

 LOAD_PC
 LOAD_CYCLES

 GET_PBPC ebx
 GET_BYTE               ; Get opcode

 add R_Cycles,_5A22_FAST_CYCLE   ; hwint processing: 1 IO
 JUMP_NOT_FLAG SNES_FLAG_E,.native_irq
 call E1_IRQ
 jmp .irq_return
ALIGNC
.native_irq:
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
 jmp CPU_START  ; Return to CPU

ALIGNC
IRQ_Check_Newline:
 mov bl,[C_LABEL(NMITIMEN)]

 mov edx,[FixedTrip]

 cmp byte [NMI_pin],NMI_Raised
 je .nmi_bypass

 test bl,0x30       ; IRQ enabled?
 jz .no_irq
 test bl,0x20       ; V-IRQ enabled?
 jz .no_virq
 mov ebx,[C_LABEL(Current_Line_Timing)]
 cmp [C_LABEL(VTIMEL)],ebx
 jne .no_irq
.no_virq:
 mov ebx,[HTimer]
 cmp edx,ebx
 jb .no_irq         ; Next static event is before IRQ?

%ifdef DEBUG_IRQ
 pusha
 push dword irqcnl_str
 call C_LABEL(print_str)
 add esp,4
 popa
%endif

 mov [C_LABEL(EventTrip)],ebx
 mov dword [Event_Handler],IRQ_Event
 ret

.nmi_bypass:
.no_irq:
 mov ebx,[Fixed_Event]
 mov [C_LABEL(EventTrip)],edx
 mov [Event_Handler],ebx
 ret


ALIGNC
; This can only trash ebx/edx!
IRQ_Check:
 SAVE_CYCLES edx
 cmp byte [NMI_pin],NMI_Raised
 je .nmi_bypass

 mov [Last_Trip],edx

 mov bl,[C_LABEL(NMITIMEN)]

 mov edx,[FixedTrip]

 test bl,0x30       ; IRQ enabled?
 jz .no_irq
 test bl,0x20       ; V-IRQ enabled?
 jz .no_virq
 mov ebx,[C_LABEL(Current_Line_Timing)]
 cmp [C_LABEL(VTIMEL)],ebx
 jne .no_irq
.no_virq:
 mov ebx,[HTimer]
 cmp edx,ebx
 jb .no_irq         ; Next static event is before IRQ?
 cmp [C_LABEL(SNES_Cycles)],ebx ; Check against current cycle
 jbe .before_irq    ; Are we after the IRQ position?

;mov ebx,[esp]      ;should we do this?

 ;IRQ already fired on this line?
 cmp byte [IRQ_fired_this_line],0
 jnz .no_irq

.before_irq:
%ifdef DEBUG_IRQ
 pusha
 push dword irqc_str
 call C_LABEL(print_str)
 add esp,4
 popa
%endif

 mov [C_LABEL(EventTrip)],ebx
 mov dword [Event_Handler],IRQ_Event
 jmp .fixup_timing

.nmi_bypass:
 mov edx,[FixedTrip]
.no_irq:
 mov ebx,[Fixed_Event]
 mov [C_LABEL(EventTrip)],edx
 mov [Event_Handler],ebx
.fixup_timing:
 LOAD_CYCLES edx
 ret


ALIGNC
; This can only trash ebx/edi!
IRQ_Check_Late:
 mov bl,[C_LABEL(NMITIMEN)]

 mov edi,[FixedTrip]

 cmp byte [NMI_pin],NMI_Raised
 je .nmi_bypass

 test bl,0x30       ; IRQ enabled?
 jz .no_irq
 test bl,0x20       ; V-IRQ enabled?
 jz .no_virq
 mov ebx,[C_LABEL(Current_Line_Timing)]
 cmp [C_LABEL(VTIMEL)],ebx
 jne .no_irq
.no_virq:
 mov ebx,[HTimer]
 cmp edi,ebx
 jb .no_irq         ; Next static event is before IRQ?
 cmp [Last_Trip],ebx    ; Check against last event trip cycle
 jb  .before_irq    ; Are we after the IRQ?

;mov ebx,[esp]      ;should we do this?

 ;IRQ already fired on this line?
 cmp byte [IRQ_fired_this_line],0
 jnz .no_irq

.before_irq:
%ifdef DEBUG_IRQ
 pusha
 push dword irqcl_str
 call C_LABEL(print_str)
 add esp,4
 popa
%endif

 mov [C_LABEL(EventTrip)],ebx
 mov dword [Event_Handler],IRQ_Event
 ret

.nmi_bypass:
.no_irq:
 mov ebx,[Fixed_Event]
 mov [C_LABEL(EventTrip)],edi
 mov [Event_Handler],ebx
 ret

EXTERN PPU2_Latch_External


ALIGNC
EXPORT SNES_R2137 ; SLHV  ; This latches the counter for horizontal/vertical data!
 ;counters cannot be latched if I/O port bit 7 held low
 mov al,[C_LABEL(WRIO)]
 and al,[C_LABEL(RDIO)]
 jns .no_change

 cmp byte [PPU2_Latch_External],0
 jnz .no_change
.latch:
 or byte [STAT78],BIT(6)    ; Raise latch flag

 push ebx
 GET_CYCLES ebx

 xor edx,edx

 ; Set up H counters to cycles executed / 4, V counter to current scanline

 ;Fixup for 'long' dots
 cmp ebx,LONG_DOT_1_START
 jbe .before_long_dots
 sub ebx,CYCLES_HALF_DOT
 cmp ebx,LONG_DOT_2_START
 jbe .before_long_dots
 sub ebx,CYCLES_HALF_DOT
.before_long_dots:

 shr ebx,2
 cmp ebx,DOTS_BEFORE_REFRESH
 jb .before_refresh
 add ebx,DOTS_IN_REFRESH        ; Adjust for memory refresh cycles
.before_refresh:

 cmp ebx,DOTS_PER_SCANLINE_REPORTED
 jb .before_next_line
 sub ebx,DOTS_PER_SCANLINE_REPORTED
 inc edx            ; Adjust if we're on the next line
.before_next_line:

 mov [Latched_H],ebx    ; H counter

 mov ebx,[C_LABEL(Current_Line_Timing)]
 add ebx,edx        ; fixup for next line

 mov edx,[C_LABEL(LastVBLLine)]
 cmp ebx,edx
 jbe .before_next_frame
 sub ebx,edx        ; fixup for next frame
 dec ebx
.before_next_frame:

 mov [Latched_V],ebx

 pop ebx
.no_change:
 jmp CPU_OPEN_BUS_READ  ;return open bus value

ALIGNC
EXPORT SNES_R213C ; OPHCT
 xor byte [OPHCT],1
 jz .return_high
 mov al,[Latched_H]
 mov [Last_Bus_Value_PPU2],al
 ret
.return_high:
 mov al,[Latched_H+1]
 mov dl,[Last_Bus_Value_PPU2]
 and al,1
 and dl,~1
 add al,dl
 mov [Last_Bus_Value_PPU2],al
 ret

ALIGNC
EXPORT SNES_R213D ; OPVCT
 xor byte [OPVCT],1
 jz .return_high
 mov al,[Latched_V]
 mov [Last_Bus_Value_PPU2],al
 ret
.return_high:
 mov al,[Latched_V+1]
 mov dl,[Last_Bus_Value_PPU2]
 and al,1
 and dl,~1
 add al,dl
 mov [Last_Bus_Value_PPU2],al
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
 add R_65c816_Cycles,_5A22_LEGACY_CYCLE - _5A22_FAST_CYCLE
 ret

ALIGNC
EXPORT SNES_W4017 ; JOYC2
 add R_65c816_Cycles,_5A22_LEGACY_CYCLE - _5A22_FAST_CYCLE
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

.fixup_read:
 ;merge in open bus bits
 mov dl,[C_LABEL(Last_Bus_Value_A)]
 and dl,JOYC1_OPEN_BUS_BITS

 or al,dl

 add R_65c816_Cycles,_5A22_LEGACY_CYCLE - _5A22_FAST_CYCLE
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
 jmp .fixup_read

.unused:
 mov byte [C_LABEL(Controller1_Pos)],16
 mov al,1           ; Joypad connected
 pop ebx
 pop ecx
 jmp .fixup_read

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
 jmp .fixup_read

ALIGNC
EXPORT SNES_R4017 ; JOYC2
 test byte [JOYC1],1
 jz .read_enabled
 mov al,0

.fixup_read:

 ;merge in open bus bits
 mov dl,[C_LABEL(Last_Bus_Value_A)]
 or al,JOYC2_ALWAYS_HIGH_BITS
 and dl,JOYC2_OPEN_BUS_BITS

 or al,dl

 add R_65c816_Cycles,_5A22_LEGACY_CYCLE - _5A22_FAST_CYCLE
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
 jmp .fixup_read

.unused:
 mov byte [C_LABEL(Controller23_Pos)],16
 mov al,1           ; (???) Return 0 this bit is for mtap I think
 pop ebx
 pop ecx
 jmp .fixup_read

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
 jmp .fixup_read


; Read from 42xx handlers
ALIGNC
EXPORT SNES_R4210 ; RDNMI
 mov al,[RDNMI]
 test al,al
 js .got_nmi_source

 mov edx,[C_LABEL(Current_Line_Timing)]
 cmp edx,[C_LABEL(LastRenderLine)]
 jb .no_reset

 test byte [RDNMI_mask],RDNMI_VBLANK_START
 jns .no_reset

 GET_CYCLES edx

 shr edx,2

 ;if we're on the next scanline, add 1 to the scanline count
 cmp edx,USABLE_DOTS_PER_SCANLINE       ;dot count excluding refresh period
 sbb edx,edx
;inc edx        ;don't add 1, as comparing against NMI line - 1

 add edx,[C_LABEL(Current_Line_Timing)]

 cmp edx,[C_LABEL(LastRenderLine)]
 jb .no_reset

 or al,RDNMI_VBLANK_START

.got_nmi_source:
 and al,[RDNMI_mask]    ; ensure only one NMI per frame
 jns .no_reset  ;RDNMI_VBLANK_START not set

 test byte [C_LABEL(NMITIMEN)],0x80
 jz .no_nmi             ; NMI masked off?

 cmp byte [NMI_pin],NMI_None
 jne .no_nmi

 mov byte [NMI_pin],NMI_Raised ;*NMI
 ; event should trigger after this opcode, triggering NMI
.no_nmi:

 mov byte [RDNMI],VERSION_NUMBER_5A22   ; clear NMI source
 mov byte [RDNMI_mask],~RDNMI_VBLANK_START
.no_reset:
 ;merge in open bus bits
 mov dl,[C_LABEL(Last_Bus_Value_A)]
 and dl,RDNMI_OPEN_BUS_BITS

 or al,dl
 ret

ALIGNC
EXPORT SNES_R4211 ; TIMEUP
 mov al,[IRQ_pin]
 and al,0x80
 jz .no_irq
 and byte [IRQ_pin],~0x80   ; Clear Internal IRQ
.no_irq:

 ;merge in open bus bits
 mov dl,[C_LABEL(Last_Bus_Value_A)]
 and dl,TIMEUP_OPEN_BUS_BITS

 or al,dl

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

 ;merge in open bus bits
 mov dl,[C_LABEL(Last_Bus_Value_A)]
 and dl,HVBJOY_OPEN_BUS_BITS

 or al,dl
 ret

ALIGNC
EXPORT SNES_R4213 ; RDIO
 mov al,[C_LABEL(RDIO)]
 and al,[C_LABEL(WRIO)]

 cmp byte [PPU2_Latch_External],0
 jz .no_latch
 and al,~BIT(7)
.no_latch:

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

%ifdef DEBUG_IRQ
 pusha
 GET_CYCLES edx
 push edx
 push byte 2
 movzx eax,al
 push eax

 push dword nmitimen_str
 call C_LABEL(print_str)
 add esp,4

 call C_LABEL(print_hexnum)

 push dword at_str
 call C_LABEL(print_str)
 add esp,4*3

 call C_LABEL(print_decnum)

 push dword comma_str
 call C_LABEL(print_str)

 push dword [C_LABEL(Current_Line_Timing)]
 call C_LABEL(print_decnum)

 push nl_str
 call C_LABEL(print_str)
 add esp,4*4
 popa
%endif

 push ebx
 mov bl,[C_LABEL(NMITIMEN)]
 xor bl,al
 mov [C_LABEL(NMITIMEN)],al
 jns .no_nmi_change

 test byte [RDNMI],RDNMI_VBLANK_START
 jz .no_nmi_change

.nmi_change:
 test al,0x80
 jnz .nmi_on
.nmi_off:
 mov byte [NMI_pin],NMI_None
 jmp .no_nmi_change

.nmi_on:
 mov byte [NMI_pin],NMI_Raised

 ;setup NMI to execute after one opcode
 mov edx,[FixedTrip]
 mov [NMI_Next_Trip],edx
 mov edx,[Fixed_Event]
 mov [NMI_Next_Event],edx

 mov edx,NMI_Setup_Event
 mov [Fixed_Event],edx
 mov [Event_Handler],edx
 SAVE_CYCLES edx
 mov [FixedTrip],edx
 mov [C_LABEL(EventTrip)],edx
 LOAD_CYCLES edx

.no_nmi_change:
 test bl,0x30
 jz .no_irq_change

 test al,0x30
 jnz .irq_enabled

 mov byte [IRQ_fired_this_line],0
 and byte [IRQ_pin],~0x80   ; Clear Internal IRQ
 jmp .irq_reschedule

.irq_enabled:
 mov edx,eax
 shr edx,5  ;shift out bit 4
 sbb edx,edx
 and edx,[HTimer_Set]
 mov [HTimer],edx

.irq_reschedule:
 call IRQ_Check
.no_irq_change:
 pop ebx
.no_change:
 ret

ALIGNC
EXPORT SNES_W4201 ; WRIO
 mov dl,[C_LABEL(WRIO)]
 xor dl,al
 jz .no_change ;no latch?
 mov dl,[C_LABEL(WRIO)]
 push eax

 ;latch only on 1-to-0 transition
 or dl,al
 xor dl,al
 jns .no_latch

 ; dodgy way to simulate latch delay
 add R_Cycles,CYCLES_PER_DOT
 call SNES_R2137
 sub R_Cycles,CYCLES_PER_DOT

 mov al,[C_LABEL(WRIO)]
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

Update_HTimer:
 cmp edx,DOTS_PER_SCANLINE_REPORTED
 jae .Invalid_HTimer

 shl edx,2

 ; Do some magic for the memory refresh 'missing' cycles
 cmp edx,CYCLES_REFRESH_START   ; Before memory refresh
 jb .got_timer
 cmp edx,CYCLES_REFRESH_END
 jae .after_refresh
 mov edx,CYCLES_REFRESH_START   ; During memory refresh
 jmp .got_timer
ALIGNC
.after_refresh:
 sub edx,byte CYCLES_IN_REFRESH ; After memory refresh
.got_timer:
 mov [HTimer_Set],edx
 test byte [C_LABEL(NMITIMEN)],0x10
 jz .no_change
 mov [HTimer],edx
 push ebx
 call IRQ_Check
 pop ebx
.no_change:
 ret

ALIGNC
.Invalid_HTimer:
 mov edx,-1
 jmp .got_timer

%macro debug_irq_output 2
%ifdef DEBUG_IRQ
 pusha
 GET_CYCLES eax
 push eax

 push dword %1
 call C_LABEL(print_str)

 push dword %2
 call C_LABEL(print_decnum)

 push dword at_str
 call C_LABEL(print_str)
 add esp,4*3

 call C_LABEL(print_decnum)

 push dword comma_str
 call C_LABEL(print_str)

 push dword [C_LABEL(Current_Line_Timing)]
 call C_LABEL(print_decnum)

 push nl_str
 call C_LABEL(print_str)
 add esp,4*4
 popa
%endif
%endmacro

ALIGNC
EXPORT SNES_W4207 ; HTIMEL
 mov edx,[C_LABEL(HTIMEL)]
 cmp al,dl
 je .no_change
 mov dl,al
 mov [C_LABEL(HTIMEL)],edx

 debug_irq_output htime_str,[C_LABEL(HTIMEL)]

 call Update_HTimer
.no_change:
 ret

ALIGNC
EXPORT SNES_W4208 ; HTIMEH
 push eax
 mov edx,[C_LABEL(HTIMEL)]
 and al,1
 cmp al,dh
 je .no_change
 mov dh,al
 mov [C_LABEL(HTIMEL)],edx

 debug_irq_output htime_str,[C_LABEL(HTIMEL)]

 call Update_HTimer
.no_change:
 pop eax
 ret

ALIGNC
EXPORT SNES_W4209 ; VTIMEL
 mov edx,[C_LABEL(VTIMEL)]
 cmp al,dl
 je .no_change
 mov [C_LABEL(VTIMEL)],al

 debug_irq_output vtime_str,[C_LABEL(VTIMEL)]

 test byte [C_LABEL(NMITIMEN)],0x20
 jz .no_change
 push ebx
 call IRQ_Check
 pop ebx
.no_change:
 ret

ALIGNC
EXPORT SNES_W420A ; VTIMEH
 push eax
 mov edx,[C_LABEL(VTIMEL)]
 and al,1
 cmp al,dh
 je .no_change
 mov [C_LABEL(VTIMEH)],al

 debug_irq_output vtime_str,[C_LABEL(VTIMEL)]

 test byte [C_LABEL(NMITIMEN)],0x20
 jz .no_change
 push ebx
 call IRQ_Check
 pop ebx
.no_change:
 pop eax
 ret


ALIGNC
EXPORT SNES_W420B ; MDMAEN
 or [C_LABEL(MDMAEN)],al

 debug_dma_output mdmaen_str

 test al,al     ;don't repeat setup if no new channels
 jz .no_dma

 push ebx

 SAVE_CYCLES ebx

 ;setup event chain for DMA
 mov edx,[FixedTrip]

 ;next line is correct - but causes problems without cycle-based
 ; event-handling (as opposed to opcode-based)
;add ebx,byte _5A22_FAST_CYCLE  ;delay of 1 bus cycle
 mov [FixedTrip],ebx
 mov [C_LABEL(EventTrip)],ebx

 mov [DMA_Next_Trip],edx

 mov ebx,[Fixed_Event]
 mov edx,DMA_Event
 mov [DMA_Next_Event],ebx
 mov [Fixed_Event],edx
 mov [Event_Handler],edx

 LOAD_CYCLES edx

 pop ebx

.no_dma:
 ret


ALIGNC
EXPORT SNES_W420D ; MEMSEL    ; FastROM switch
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


; bits for the SPC700
ALIGNC
SNES_R2140_SPC: ; APUIO0
SNES_R2141_SPC: ; APUIO1
SNES_R2142_SPC: ; APUIO2
SNES_R2143_SPC: ; APUIO3
 Execute_SPC SaveCycles
 push eax
 push ecx

 push ebx
 call C_LABEL(SPC_READ_PORT_W)
 add esp,4
 pop ecx
 pop edx
 and eax,0xFF
 and edx,0xFFFFFF00
 add eax,edx
 ret

ALIGNC
SNES_W2140_SPC: ; APUIO0
SNES_W2141_SPC: ; APUIO1
SNES_W2142_SPC: ; APUIO2
SNES_W2143_SPC: ; APUIO3
 Execute_SPC SaveCycles
 push eax
 push ecx

 push eax
 push ebx
 call C_LABEL(SPC_WRITE_PORT_R)
 add esp,8
 pop ecx
 pop eax
 ret
%if 0
 push eax
 push ecx
 push eax

 push ebx
 call C_LABEL(SPC_READ_PORT_R)
 add esp,4

 cmp al,[esp]
 jne .change
 test al,al
 jz .no_change

.change:
 Execute_SPC SaveCycles

 push ebx
 call C_LABEL(SPC_WRITE_PORT_R)
 add esp,8

 pop ecx
 pop eax
 ret

.no_change:
 pop edx
 pop ecx
 pop eax
 ret
%endif

ALIGNC
EXPORT Make_SPC
 pusha
 mov eax,SNES_R2140_SPC
 mov edx,SNES_R2141_SPC
 mov esi,SNES_R2142_SPC
 mov edi,SNES_R2143_SPC

 mov ebx,Read_21_Address(0x40)
 mov cl,0x40 / 4

.set_read_loop:
 mov [ebx],eax
 mov [ebx+1*4],edx
 mov [ebx+2*4],esi
 mov [ebx+3*4],edi
 add ebx,byte 4*4
 dec cl
 jnz .set_read_loop

 mov eax,SNES_W2140_SPC
 mov edx,SNES_W2141_SPC
 mov esi,SNES_W2142_SPC
 mov edi,SNES_W2143_SPC

 mov ebx,Write_21_Address(0x40)
 mov cl,0x40 / 4

.set_write_loop:
 mov [ebx],eax
 mov [ebx+1*4],edx
 mov [ebx+2*4],esi
 mov [ebx+3*4],edi
 add ebx,byte 4*4
 dec cl
 jnz .set_write_loop

 popa
 ret

