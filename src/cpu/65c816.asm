%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

; SNEeSe 65c816 CPU emulation core
; Originally written by Lee Hammerton in AT&T assembly
; Maintained/rewritten/ported to NASM by Charles Bilyue'
;
; Compile under NASM

; To do: move cycle addition into opcode handlers
;        improved bus speed selection

;%define ADD_CYCLES_FIRST
;CPU instruction tracker is broken!
;DO NOT UNCOMMENT THE FOLLOWING LINE!
;%define TRACKERS 1048576

%define VERSION_NUMBER_5A22 2

;%define SINGLE_STEP

;%define WATCH_FLAG_BREAKS
;%define FAST_STACK_ACCESS_NATIVE_MODE
%define FAST_STACK_ACCESS_EMULATION_MODE

; This file contains:
;  CPU core info
;  Reset
;  Execution Loop
;  Invalid Opcode Handler
;  Flag format conversion tables
;  Variable definitions (registers, interrupt vectors, etc.)
;  CPU opcode emulation handlers
;  CPU opcode handler tables
;  CPU opcode timing tables
;
; CPU core info:
;  All general registers are now used in 65c816 emulation:
;   EAX,EBX are used by the memory mapper;
;   ECX is used to hold P register;
;   EDX is used as memory mapper work register;
;   EBP is used to hold scanline cycle counter;
;   ESI is used by the opcode fetcher;
;   EDI is used to hold base address to CPU register set.
;
;    Accumulator         - CPU_LABEL(A)
;    X index             - CPU_LABEL(X)
;    Y index             - CPU_LABEL(Y)
;    Stack pointer       - CPU_LABEL(S)
;    Direct address      - CPU_LABEL(D)
;    Program Counter     - CPU_LABEL(PC)
;    Program Bank        - CPU_LABEL(PB), CPU_LABEL(PB_Shifted)
;    Data Bank           - CPU_LABEL(DB), CPU_LABEL(DB_Shifted)
;    Processor status    - _P,_P_B,_P_W
;                True x86 layout = |V|-|-|-|S|Z|-|A|-|-|-|C|
;       Native mode 65816 layout =       |E|N|V|M|X|D|I|Z|C|
;    Emulation mode 65816 layout =       |E|N|V|1|B|D|I|Z|C|
;                            Using       |E|N|Z|I|D|X|M|V|C|
;                                                  |B|1|
;
; Identifiers/labels
;  Identifiers beginning with "R_" are register aliases.
;  Identifiers beginning with "B_" are 'based' data (1-byte offset) aliases.
;  Identifiers beginning with "_" MAY BE local aliases for more
;   complex global identifiers.
;  FUTURE: Change prefix for complex identifier local aliases to "I_" or "L_".
;   (Internal or Local)
; CPU timing
;  According to Neill Corlett's SNES timing doc, main CPU clock is
;   21.47727MHz, 1360 clocks/scanline.
;
;  SNES PPU timing and interrupt timing is specific to ROM country,
;   set by ROM loader.
;  65c816 runs with many waitstates added in for bus access, bringing
;   effective CPU speed between 2.68MHz (minimum) and 3.58MHz (maximum).
;
;  Now adding base opcode cycle counts, *8 for SlowROM banks and *6 for
;   FastROM banks. This is INACCURATE! But close enough for now.
;
; Core Flaws
;  'Fast' native mode stack is incorrect outside WRAM (0000-1FFF) - values
;   read are undefined (no read is done) and values written are ignored:
;   should fallback, disabled for now.
;
; SPC relative timing calculation (for parallel execution)
;
;  SPC execution is on-demand, and CPU and SPC synchronize on
;   certain CPU events and on CPU<>SPC communication. Executed CPU
;   cycles are counted and depleted when SPC execution catches up.
;
;

%include "misc.inc"
%include "cycles.inc"
%include "cpu/cpumem.inc"
%include "ppu/screen.inc"
%include "cpu/regs.inc"
%include "ppu/ppu.inc"

EXTERN_C Map_Address,Map_Byte
EXTERN_C OLD_PB,OLD_PC
EXTERN_C RomAddress
EXTERN_C LastIns,InsAddress

EXTERN_C FRAME_SKIP_MIN,FRAME_SKIP_MAX,Timer_Counter_Throttle
EXTERN_C SNES_Screen8
EXTERN_C PaletteChanged
EXTERN_C BrightnessLevel
EXTERN_C Real_SNES_Palette,fixedpalettecheck,SetPalette
EXTERN_C ShowFPS,ShowBreaks
EXTERN_C Copy_Screen
EXTERN_C update_sound, update_sound_block

EXTERN_C SPC_ENABLED
EXTERN_C SPC_Cycles
EXTERN_C TotalCycles
EXTERN_C Wrap_SPC_Cyclecounter
EXTERN_C SPC_START

EXTERN_C SPC_CPU_cycle_divisor
EXTERN_C SPC_CPU_cycle_multiplicand

EXTERN_C InvalidOpcode,InvalidJump
EXTERN Invalidate_Tile_Caches
EXTERN_C Reset_CGRAM

%ifdef DEBUG
EXTERN_C Frames
;EXTERN_C Timer_Counter_FPS
%endif

section .text
EXPORT_C CPU_text_start
section .data
EXPORT_C CPU_data_start
section .bss
EXPORT_C CPU_bss_start

%define CPU_LABEL(x) C_LABEL(cpu_65c816_ %+ x)

%define R_Base      R_65c816_Base   ; Base pointer to register set
%define R_Cycles    R_65c816_Cycles ; Cycle counter
%define R_NativePC  R_65c816_NativePC

;  True 65816 layout, Native Mode    = |E|N|V|M|X|D|I|Z|C|
;  True 65816 layout, Emulation Mode = |E|N|V|1|B|D|I|Z|C|

; These are the bits for flag set/clr operations
; |E|N|Z|I|D|X|M|V|C|
;           |B|1|

SNES_FLAG_C equ 1   ; Carry
SNES_FLAG_V equ 2   ; Overflow
SNES_FLAG_M equ 4   ; When E=0: Memory/accumulator operations 8-bit
SNES_FLAG_1 equ 4   ; When E=1: This bit is always set
SNES_FLAG_X equ 8   ; When E=0: Index registers 8-bit
SNES_FLAG_B equ 8   ; When E=1: Break (clear only on stack after IRQ/NMI)
SNES_FLAG_D equ 0x10    ; Decimal ADC/SBC mode
SNES_FLAG_I equ 0x20    ; Interrupt Disable
SNES_FLAG_Z equ 0x40    ; Zero result
SNES_FLAG_N equ 0x80    ; Negative result
SNES_FLAG_E equ 0x100   ; Emulation mode

SNES_FLAG_B1 equ (SNES_FLAG_B | SNES_FLAG_1)
SNES_FLAG_MX equ (SNES_FLAG_M | SNES_FLAG_X)
SNES_FLAG_NZ equ (SNES_FLAG_N | SNES_FLAG_Z)
SNES_FLAG_NZC equ (SNES_FLAG_NZ | SNES_FLAG_C)

REAL_SNES_FLAG_C equ 1  ; See descriptions above
REAL_SNES_FLAG_Z equ 2
REAL_SNES_FLAG_I equ 4
REAL_SNES_FLAG_D equ 8
REAL_SNES_FLAG_X equ 0x10
REAL_SNES_FLAG_B equ 0x10
REAL_SNES_FLAG_M equ 0x20
REAL_SNES_FLAG_1 equ 0x20
REAL_SNES_FLAG_V equ 0x40
REAL_SNES_FLAG_N equ 0x80
REAL_SNES_FLAG_E equ 0x100

section .bss
ALIGNB
%define B_IRQ_Nvector       [R_Base-CPU_Register_Base+C_LABEL(IRQ_Nvector)]
%define B_IRQ_Noffset       [R_Base-CPU_Register_Base+C_LABEL(IRQ_Noffset)]
%define B_NMI_Nvector       [R_Base-CPU_Register_Base+C_LABEL(NMI_Nvector)]
%define B_NMI_Noffset       [R_Base-CPU_Register_Base+C_LABEL(NMI_Noffset)]
%define B_BRK_Nvector       [R_Base-CPU_Register_Base+C_LABEL(BRK_Nvector)]
%define B_BRK_Noffset       [R_Base-CPU_Register_Base+C_LABEL(BRK_Noffset)]
%define B_COP_Nvector       [R_Base-CPU_Register_Base+C_LABEL(COP_Nvector)]
%define B_COP_Noffset       [R_Base-CPU_Register_Base+C_LABEL(COP_Noffset)]
%define B_IRQ_Evector       [R_Base-CPU_Register_Base+C_LABEL(IRQ_Evector)]
%define B_IRQ_Eoffset       [R_Base-CPU_Register_Base+C_LABEL(IRQ_Eoffset)]
%define B_NMI_Evector       [R_Base-CPU_Register_Base+C_LABEL(NMI_Evector)]
%define B_NMI_Eoffset       [R_Base-CPU_Register_Base+C_LABEL(NMI_Eoffset)]
%define B_COP_Evector       [R_Base-CPU_Register_Base+C_LABEL(COP_Evector)]
%define B_COP_Eoffset       [R_Base-CPU_Register_Base+C_LABEL(COP_Eoffset)]
%define B_RES_Evector       [R_Base-CPU_Register_Base+C_LABEL(RES_Evector)]
%define B_RES_Eoffset       [R_Base-CPU_Register_Base+C_LABEL(RES_Eoffset)]
%define B_PB_Shifted        [R_Base-CPU_Register_Base+CPU_LABEL(PB_Shifted)]
%define B_PB                [R_Base-CPU_Register_Base+CPU_LABEL(PB)]
%define B_PC                [R_Base-CPU_Register_Base+CPU_LABEL(PC)]
%define B_P                 [R_Base-CPU_Register_Base+CPU_LABEL(P)]
%define B_SNES_Cycles       [R_Base-CPU_Register_Base+C_LABEL(SNES_Cycles)]
%define B_EventTrip         [R_Base-CPU_Register_Base+C_LABEL(EventTrip)]
%define B_A                 [R_Base-CPU_Register_Base+CPU_LABEL(A)]
%define B_B                 byte [R_Base-CPU_Register_Base+CPU_LABEL(B)]
%define B_X                 [R_Base-CPU_Register_Base+CPU_LABEL(X)]
%define B_XH                byte [R_Base-CPU_Register_Base+CPU_LABEL(XH)]
%define B_Y                 [R_Base-CPU_Register_Base+CPU_LABEL(Y)]
%define B_YH                byte [R_Base-CPU_Register_Base+CPU_LABEL(YH)]
%define B_D                 [R_Base-CPU_Register_Base+CPU_LABEL(D)]
%define B_DL                byte [R_Base-CPU_Register_Base+CPU_LABEL(DL)]
%define B_DH                byte [R_Base-CPU_Register_Base+CPU_LABEL(DH)]
%define B_S                 [R_Base-CPU_Register_Base+CPU_LABEL(S)]
%define B_SL                byte [R_Base-CPU_Register_Base+CPU_LABEL(SL)]
%define B_SH                byte [R_Base-CPU_Register_Base+CPU_LABEL(SH)]
%define B_DB_Shifted        [R_Base-CPU_Register_Base+CPU_LABEL(DB_Shifted)]
%define B_DB                [R_Base-CPU_Register_Base+CPU_LABEL(DB)]
%define B_OpTable           [R_Base-CPU_Register_Base+OpTable]
%define B_PBOffset          [R_Base-CPU_Register_Base+C_LABEL(PBOffset)]
%define B_FixedTrip         [R_Base-CPU_Register_Base+FixedTrip]
%define B_SPC_last_cycles   [R_Base-CPU_Register_Base+SPC_last_cycles]
%define B_SPC_CPU_cycles    [R_Base-CPU_Register_Base+SPC_CPU_cycles]
%define B_SPC_cycles_left   [R_Base-CPU_Register_Base+SPC_cycles_left]
%define B_SPC_CPU_cycles_mul    [R_Base-CPU_Register_Base+SPC_CPU_cycles_mul]

%if 1
%define B_E_flag            [R_Base-CPU_Register_Base+_E_flag]
%define B_N_flag            [R_Base-CPU_Register_Base+_N_flag]
%define B_V_flag            [R_Base-CPU_Register_Base+_V_flag]
%define B_M1_flag           [R_Base-CPU_Register_Base+_M1_flag]
%define B_XB_flag           [R_Base-CPU_Register_Base+_XB_flag]
%define B_D_flag            [R_Base-CPU_Register_Base+_D_flag]
%define B_I_flag            [R_Base-CPU_Register_Base+_I_flag]
%define B_Z_flag            [R_Base-CPU_Register_Base+_Z_flag]
%define B_C_flag            [R_Base-CPU_Register_Base+_C_flag]
%else
%define B_E_flag [_E_flag]
%define B_N_flag [_N_flag]
%define B_V_flag [_V_flag]
%define B_M1_flag [_M1_flag]
%define B_XB_flag [_XB_flag]
%define B_D_flag [_D_flag]
%define B_I_flag [_I_flag]
%define B_Z_flag [_Z_flag]
%define B_C_flag [_C_flag]
%endif

EXPORT_C IRQ_Nvector,skipl
EXPORT_C IRQ_Noffset,skipl
EXPORT_C NMI_Nvector,skipl
EXPORT_C NMI_Noffset,skipl
EXPORT_C BRK_Nvector,skipl
EXPORT_C BRK_Noffset,skipl
EXPORT_C COP_Nvector,skipl
EXPORT_C COP_Noffset,skipl
EXPORT_C IRQ_Evector,skipl
EXPORT_C IRQ_Eoffset,skipl
EXPORT_C NMI_Evector,skipl
EXPORT_C NMI_Eoffset,skipl
EXPORT_C COP_Evector,skipl
EXPORT_C COP_Eoffset,skipl
EXPORT_C RES_Evector,skipl
EXPORT_C RES_Eoffset,skipl

; v0.25 - New system for CPU timings... there are now ten paired tables,
; not five single tables. Each pair of tables has a 256-byte SlowROM
; table first, then a 256-byte FastROM table immediately following.
; The address of the current table pair is OpTable+0x400.

; v0.25 - OpTable holds pointer to current opcode emulation/timing tables,
; removes the need for multiple CPU loops.

CPU_Register_Base:

EXPORT CPU_LABEL(PB_Shifted),skipl  ; Program Bank
EXPORT_EQU CPU_LABEL(PB),CPU_LABEL(PB_Shifted) + 2

EXPORT CPU_LABEL(PC),skipl  ; Program Counter
EXPORT CPU_LABEL(P) ,skipl  ; Processor status (flags)
EXPORT_C SNES_Cycles,skipl  ; Scanline cycle count for CPU (0-EventTrip)
EXPORT_C EventTrip  ,skipl  ; Cycle of next event on this scanline

EXPORT CPU_LABEL(A) ,skipl  ; Accumulator
EXPORT_EQU CPU_LABEL(B),CPU_LABEL(A)+1

EXPORT CPU_LABEL(X) ,skipl  ; X and Y indices
EXPORT CPU_LABEL(Y) ,skipl
EXPORT_EQU CPU_LABEL(XH),CPU_LABEL(X)+1
EXPORT_EQU CPU_LABEL(YH),CPU_LABEL(Y)+1

EXPORT CPU_LABEL(D) ,skipl  ; Direct address
EXPORT_EQU CPU_LABEL(DL),CPU_LABEL(D)
EXPORT_EQU CPU_LABEL(DH),CPU_LABEL(D)+1

EXPORT CPU_LABEL(S) ,skipl  ; Stack pointer
EXPORT_EQU CPU_LABEL(SL),CPU_LABEL(S)
EXPORT_EQU CPU_LABEL(SH),CPU_LABEL(S)+1


EXPORT CPU_LABEL(DB_Shifted),skipl  ; Data Bank
EXPORT_EQU CPU_LABEL(DB),CPU_LABEL(DB_Shifted) + 2

OpTable:skipl

; v0.25 - Holds memory mapper read handler for current program bank.
EXPORT_C PBOffset   ,skipl

EXPORT FixedTrip    ,skipl  ; Cycle of next fixed event on this scanline

EXPORT SPC_last_cycles      ,skipl
EXPORT SPC_CPU_cycles       ,skipl
EXPORT SPC_cycles_left      ,skipl
EXPORT SPC_CPU_cycles_mul   ,skipl

; For when I make the back color +/- hacks really do +/-
EXPORT RealColor0   ,skipl

_D_flag:skipb
_N_flag:skipb
_M1_flag:skipb
_XB_flag:skipb
_C_flag:skipb
_I_flag:skipb
EXPORT CPU_Execution_Mode,skipb
;CPU executing instructions normally
%define CEM_Normal_Execution 0
;CPU executing instruction immediately following one which
; caused an I-flag transition of high to low (CLI, PLP, RTI)
; The CPU will not acknowledge an IRQ until this instruction
; is completed.
%define CEM_Instruction_After_IRQ_Enable 1

;CPU in a state where no instructions are executed (this
; number and all above it)
%define CEM_Do_Not_Execute 2
;CPU is waiting for an interrupt after executing WAI opcode
%define CEM_Waiting_For_Interrupt 2
;CPU has stopped its clock after executing STP opcode
%define CEM_Clock_Stopped 3

EXPORT IRQ_pin      ,skipb
_E_flag:skipb
_Z_flag:skipb
EXPORT In_CPU,skipb         ; nonzero if CPU is executing

EXPORT_C FPS_ENABLED            ,skipb
_V_flag:skipb
EXPORT_C BREAKS_ENABLED         ,skipb

section .data
%define opcode_clocks(bytes, internal, bank0, bus, speed) ((internal * 6) + (bank0 * 8) + (bus * 6) + ((bytes * 8) - (bytes * speed * 2)))
; bytes, internal operations, bank 0 accesses, other bus accesses, speed
;  speed = 0 for SlowROM, 1 for FastROM
; Direct addressing: +1 IO if DL != 0
; Branch relative: +1 IO if branch taken

ALIGND
OpTableE0:
dd  C_LABEL(E0_BRK)       ,C_LABEL(E0_ORA_Od_xO)    ; 00
dd  C_LABEL(E0_COP)       ,C_LABEL(OpM0_0x03)
dd  C_LABEL(OpE0M0_0x04)  ,C_LABEL(E0_ORA_d)
dd  C_LABEL(OpE0M0_0x06)  ,C_LABEL(E0_ORA_IdI)
dd  C_LABEL(E0_PHP)       ,C_LABEL(OpM0_0x09)
dd  C_LABEL(OpM0_0x0A)    ,C_LABEL(E0_PHD)
dd  C_LABEL(OpM0_0x0C)    ,C_LABEL(OpM0_0x0D)
dd  C_LABEL(OpM0_0x0E)    ,C_LABEL(OpM0_0x0F)
dd  C_LABEL(ALL_BPL)      ,C_LABEL(OpE0M0X0_0x11)   ; 10
dd  C_LABEL(E0_ORA_OdO)   ,C_LABEL(OpM0_0x13)
dd  C_LABEL(OpE0M0_0x14)  ,C_LABEL(E0_ORA_d_x)
dd  C_LABEL(OpE0M0_0x16)  ,C_LABEL(E0_ORA_IdI_y)
dd  C_LABEL(ALL_CLC)      ,C_LABEL(E0_ORA_a_y)
dd  C_LABEL(OpM0_0x1A)    ,C_LABEL(E0_TCS)
dd  C_LABEL(OpM0_0x1C)    ,C_LABEL(E0_ORA_a_x)
dd  C_LABEL(OpM0_0x1E)    ,C_LABEL(E0_ORA_al_x)
dd  C_LABEL(E0_JSR_a)     ,C_LABEL(E0_AND_Od_xO)    ; 20
dd  C_LABEL(E0_JSL_al)    ,C_LABEL(OpM0_0x23)
dd  C_LABEL(E0_BIT_d)     ,C_LABEL(E0_AND_d)
dd  C_LABEL(OpE0M0_0x26)  ,C_LABEL(E0_AND_IdI)
dd  C_LABEL(E0_PLP)       ,C_LABEL(OpM0_0x29)
dd  C_LABEL(OpM0_0x2A)    ,C_LABEL(E0_PLD)
dd  C_LABEL(OpM0_0x2C)    ,C_LABEL(OpM0_0x2D)
dd  C_LABEL(OpM0_0x2E)    ,C_LABEL(OpM0_0x2F)
dd  C_LABEL(ALL_BMI)      ,C_LABEL(OpE0M0X0_0x31)   ; 30
dd  C_LABEL(E0_AND_OdO)   ,C_LABEL(OpM0_0x33)
dd  C_LABEL(E0_BIT_d_x)   ,C_LABEL(E0_AND_d_x)
dd  C_LABEL(OpE0M0_0x36)  ,C_LABEL(E0_AND_IdI_y)
dd  C_LABEL(ALL_SEC)      ,C_LABEL(E0_AND_a_y)
dd  C_LABEL(OpM0_0x3A)    ,C_LABEL(ALL_TSC)
dd  C_LABEL(E0_BIT_a_x)   ,C_LABEL(E0_AND_a_x)
dd  C_LABEL(OpM0_0x3E)    ,C_LABEL(E0_AND_al_x)
dd  C_LABEL(E0_RTI)       ,C_LABEL(E0_EOR_Od_xO)    ; 40
dd  C_LABEL(ALL_INVALID)  ,C_LABEL(OpM0_0x43)
dd  C_LABEL(E0_MVP)       ,C_LABEL(E0_EOR_d)
dd  C_LABEL(OpE0M0_0x46)  ,C_LABEL(E0_EOR_IdI)
dd  C_LABEL(E0_PHA)       ,C_LABEL(OpM0_0x49)
dd  C_LABEL(OpM0_0x4A)    ,C_LABEL(E0_PHK)
dd  C_LABEL(ALL_JMP_a)    ,C_LABEL(OpM0_0x4D)
dd  C_LABEL(OpM0_0x4E)    ,C_LABEL(OpM0_0x4F)
dd  C_LABEL(ALL_BVC)      ,C_LABEL(OpE0M0X0_0x51)   ; 50
dd  C_LABEL(E0_EOR_OdO)   ,C_LABEL(OpM0_0x53)
dd  C_LABEL(E0_MVN)       ,C_LABEL(E0_EOR_d_x)
dd  C_LABEL(OpE0M0_0x56)  ,C_LABEL(E0_EOR_IdI_y)
dd  C_LABEL(ALL_CLI)      ,C_LABEL(E0_EOR_a_y)
dd  C_LABEL(E0_PHY)       ,C_LABEL(ALL_TCD)
dd  C_LABEL(ALL_JML_al)   ,C_LABEL(E0_EOR_a_x)
dd  C_LABEL(OpM0_0x5E)    ,C_LABEL(E0_EOR_al_x)
dd  C_LABEL(E0_RTS)       ,C_LABEL(E0_ADC_Od_xO)    ; 60
dd  C_LABEL(E0_PER)       ,C_LABEL(OpM0_0x63)
dd  C_LABEL(OpE0M0_0x64)  ,C_LABEL(E0_ADC_d)
dd  C_LABEL(OpE0M0_0x66)  ,C_LABEL(E0_ADC_IdI)
dd  C_LABEL(E0_PLA)       ,C_LABEL(OpM0_0x69)
dd  C_LABEL(OpM0_0x6A)    ,C_LABEL(E0_RTL)
dd  C_LABEL(ALL_JMP_OaO)  ,C_LABEL(OpM0_0x6D)
dd  C_LABEL(OpM0_0x6E)    ,C_LABEL(OpM0_0x6F)
dd  C_LABEL(ALL_BVS)      ,C_LABEL(OpE0M0X0_0x71)   ; 70
dd  C_LABEL(E0_ADC_OdO)   ,C_LABEL(OpM0_0x73)
dd  C_LABEL(OpE0M0_0x74)  ,C_LABEL(E0_ADC_d_x)
dd  C_LABEL(OpE0M0_0x76)  ,C_LABEL(E0_ADC_IdI_y)
dd  C_LABEL(ALL_SEI)      ,C_LABEL(E0_ADC_a_y)
dd  C_LABEL(E0_PLY)       ,C_LABEL(ALL_TDC)
dd  C_LABEL(ALL_JMP_Oa_xO),C_LABEL(E0_ADC_a_x)
dd  C_LABEL(OpM0_0x7E)    ,C_LABEL(E0_ADC_al_x)
dd  C_LABEL(ALL_BRA)      ,C_LABEL(OpE0M0_0x81)     ; 80
dd  C_LABEL(ALL_BRL)      ,C_LABEL(OpM0_0x83)
dd  C_LABEL(OpE0X0_0x84)  ,C_LABEL(OpE0M0_0x85)
dd  C_LABEL(OpE0X0_0x86)  ,C_LABEL(OpE0M0_0x87)
dd  C_LABEL(OpX0_0x88)    ,C_LABEL(E0_BIT_i)
dd  C_LABEL(E0_TXA)       ,C_LABEL(E0_PHB)
dd  C_LABEL(OpX0_0x8C)    ,C_LABEL(OpM0_0x8D)
dd  C_LABEL(OpX0_0x8E)    ,C_LABEL(OpM0_0x8F)
dd  C_LABEL(ALL_BCC)      ,C_LABEL(OpE0M0X0_0x91)   ; 90
dd  C_LABEL(OpE0M0_0x92)  ,C_LABEL(OpM0_0x93)
dd  C_LABEL(OpE0X0_0x94)  ,C_LABEL(OpE0M0_0x95)
dd  C_LABEL(OpE0X0_0x96)  ,C_LABEL(OpE0M0_0x97)
dd  C_LABEL(E0_TYA)       ,C_LABEL(OpM0_0x99)
dd  C_LABEL(E0_TXS)       ,C_LABEL(E0_TXY)
dd  C_LABEL(OpM0_0x9C)    ,C_LABEL(OpM0_0x9D)
dd  C_LABEL(OpM0_0x9E)    ,C_LABEL(OpM0_0x9F)
dd  C_LABEL(OpX0_0xA0)    ,C_LABEL(E0_LDA_Od_xO)    ; A0
dd  C_LABEL(OpX0_0xA2)    ,C_LABEL(OpM0_0xA3)
dd  C_LABEL(E0_LDY_d)     ,C_LABEL(E0_LDA_d)
dd  C_LABEL(E0_LDX_d)     ,C_LABEL(E0_LDA_IdI)
dd  C_LABEL(E0_TAY)       ,C_LABEL(OpM0_0xA9)
dd  C_LABEL(E0_TAX)       ,C_LABEL(E0_PLB)
dd  C_LABEL(OpX0_0xAC)    ,C_LABEL(OpM0_0xAD)
dd  C_LABEL(OpX0_0xAE)    ,C_LABEL(OpM0_0xAF)
dd  C_LABEL(ALL_BCS)      ,C_LABEL(OpE0M0X0_0xB1)   ; B0
dd  C_LABEL(E0_LDA_OdO)   ,C_LABEL(OpM0_0xB3)
dd  C_LABEL(E0_LDY_d_x)   ,C_LABEL(E0_LDA_d_x)
dd  C_LABEL(E0_LDX_d_y)   ,C_LABEL(E0_LDA_IdI_y)
dd  C_LABEL(ALL_CLV)      ,C_LABEL(E0_LDA_a_y)
dd  C_LABEL(E0_TSX)       ,C_LABEL(E0_TYX)
dd  C_LABEL(E0_LDY_a_x)   ,C_LABEL(E0_LDA_a_x)
dd  C_LABEL(E0_LDX_a_y)   ,C_LABEL(E0_LDA_al_x)
dd  C_LABEL(OpX0_0xC0)    ,C_LABEL(E0_CMP_Od_xO)    ; C0
dd  C_LABEL(E0_REP)       ,C_LABEL(OpM0_0xC3)
dd  C_LABEL(E0_CPY_d)     ,C_LABEL(E0_CMP_d)
dd  C_LABEL(OpE0M0_0xC6)  ,C_LABEL(E0_CMP_IdI)
dd  C_LABEL(OpX0_0xC8)    ,C_LABEL(OpM0_0xC9)
dd  C_LABEL(OpX0_0xCA)    ,C_LABEL(ALL_WAI)
dd  C_LABEL(OpX0_0xCC)    ,C_LABEL(OpM0_0xCD)
dd  C_LABEL(OpM0_0xCE)    ,C_LABEL(OpM0_0xCF)
dd  C_LABEL(ALL_BNE)      ,C_LABEL(OpE0M0X0_0xD1)   ; D0
dd  C_LABEL(E0_CMP_OdO)   ,C_LABEL(OpM0_0xD3)
dd  C_LABEL(E0_PEI)       ,C_LABEL(E0_CMP_d_x)
dd  C_LABEL(OpE0M0_0xD6)  ,C_LABEL(E0_CMP_IdI_y)
dd  C_LABEL(ALL_CLD)      ,C_LABEL(E0_CMP_a_y)
dd  C_LABEL(E0_PHX)       ,C_LABEL(ALL_INVALID)
dd  C_LABEL(ALL_JML_OaO)  ,C_LABEL(E0_CMP_a_x)
dd  C_LABEL(OpM0_0xDE)    ,C_LABEL(E0_CMP_al_x)
dd  C_LABEL(OpX0_0xE0)    ,C_LABEL(E0_SBC_Od_xO)    ; E0
dd  C_LABEL(E0_SEP)       ,C_LABEL(OpM0_0xE3)
dd  C_LABEL(E0_CPX_d)     ,C_LABEL(E0_SBC_d)
dd  C_LABEL(OpE0M0_0xE6)  ,C_LABEL(E0_SBC_IdI)
dd  C_LABEL(OpX0_0xE8)    ,C_LABEL(OpM0_0xE9)
dd  C_LABEL(ALL_NOP)      ,C_LABEL(ALL_XBA)
dd  C_LABEL(OpX0_0xEC)    ,C_LABEL(OpM0_0xED)
dd  C_LABEL(OpM0_0xEE)    ,C_LABEL(OpM0_0xEF)
dd  C_LABEL(ALL_BEQ)      ,C_LABEL(OpE0M0X0_0xF1)   ; F0
dd  C_LABEL(E0_SBC_OdO)   ,C_LABEL(OpM0_0xF3)
dd  C_LABEL(E0_PEA)       ,C_LABEL(E0_SBC_d_x)
dd  C_LABEL(OpE0M0_0xF6)  ,C_LABEL(E0_SBC_IdI_y)
dd  C_LABEL(ALL_SED)      ,C_LABEL(E0_SBC_a_y)
dd  C_LABEL(E0_PLX)       ,C_LABEL(E0_XCE)
dd  C_LABEL(E0_JSR_Oa_xO) ,C_LABEL(E0_SBC_a_x)
dd  C_LABEL(OpM0_0xFE)    ,C_LABEL(E0_SBC_al_x)

; bytes, internal operations, bank 0 accesses, other bus accesses, speed
;  speed = 0 for SlowROM, 1 for FastROM
CCTableE0:
; SlowROM
db opcode_clocks(2, 0, 6, 0, 0) ; 00 BRK
db opcode_clocks(2, 1, 2, 2, 0) ; 01 ORA (d,x)
db opcode_clocks(2, 0, 6, 0, 0) ; 02 COP
db opcode_clocks(2, 1, 2, 0, 0) ; 03 ORA d,s
db opcode_clocks(2, 1, 4, 0, 0) ; 04 TSB d
db opcode_clocks(2, 0, 2, 0, 0) ; 05 ORA d
db opcode_clocks(2, 1, 4, 0, 0) ; 06 ASL d
db opcode_clocks(2, 0, 3, 2, 0) ; 07 ORA [d]
  								
db opcode_clocks(1, 1, 1, 0, 0) ; 08 PHP
db opcode_clocks(3, 0, 0, 0, 0) ; 09 ORA i
db opcode_clocks(1, 1, 0, 0, 0) ; 0A SLA
db opcode_clocks(1, 1, 2, 0, 0) ; 0B PHD
db opcode_clocks(3, 1, 0, 4, 0) ; 0C TSB a
db opcode_clocks(3, 0, 0, 2, 0) ; 0D ORA a
db opcode_clocks(3, 1, 0, 4, 0) ; 0E ASL a
db opcode_clocks(4, 0, 0, 2, 0) ; 0F ORA al
  								
db opcode_clocks(2, 0, 0, 0, 0) ; 10 BPL r
db opcode_clocks(2, 1, 2, 2, 0) ; 11 ORA (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; 12 ORA (d)
db opcode_clocks(2, 2, 2, 2, 0) ; 13 ORA (d,s),y
db opcode_clocks(2, 1, 4, 0, 0) ; 14 TRB d
db opcode_clocks(2, 1, 2, 0, 0) ; 15 ORA d,x
db opcode_clocks(2, 2, 4, 0, 0) ; 16 ASL d,x
db opcode_clocks(2, 0, 3, 2, 0) ; 17 ORA [d],y
  								
db opcode_clocks(1, 1, 0, 0, 0) ; 18 CLC
db opcode_clocks(3, 1, 0, 2, 0) ; 19 ORA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 1A INA
db opcode_clocks(1, 1, 0, 0, 0) ; 1B TCS
db opcode_clocks(3, 1, 0, 4, 0) ; 1C TRB a
db opcode_clocks(3, 1, 0, 2, 0) ; 1D ORA a,x
db opcode_clocks(3, 2, 0, 4, 0) ; 1E ASL a,x
db opcode_clocks(4, 0, 0, 2, 0) ; 1F ORA al,x
  								
db opcode_clocks(3, 1, 2, 0, 0) ; 20 JSR a
db opcode_clocks(2, 1, 2, 2, 0) ; 21 AND (d,x)
db opcode_clocks(4, 1, 3, 0, 0) ; 22 JSL al
db opcode_clocks(2, 1, 2, 0, 0) ; 23 AND d,s
db opcode_clocks(2, 0, 2, 0, 0) ; 24 BIT d
db opcode_clocks(2, 0, 2, 0, 0) ; 25 AND d
db opcode_clocks(2, 1, 4, 0, 0) ; 26 ROL d
db opcode_clocks(2, 0, 3, 2, 0) ; 27 AND [d]
  								
db opcode_clocks(1, 2, 1, 0, 0) ; 28 PLP
db opcode_clocks(3, 0, 0, 0, 0) ; 29 AND i
db opcode_clocks(1, 1, 0, 0, 0) ; 2A RLA
db opcode_clocks(1, 2, 2, 0, 0) ; 2B PLD
db opcode_clocks(3, 0, 0, 2, 0) ; 2C BIT a
db opcode_clocks(3, 0, 0, 2, 0) ; 2D AND a
db opcode_clocks(3, 1, 0, 4, 0) ; 2E ROL a
db opcode_clocks(4, 0, 0, 2, 0) ; 2F AND al
  								
db opcode_clocks(2, 0, 0, 0, 0) ; 30 BMI r
db opcode_clocks(2, 1, 2, 2, 0) ; 31 AND (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; 32 AND (d)
db opcode_clocks(2, 2, 2, 2, 0) ; 33 AND (d,s),y
db opcode_clocks(2, 1, 2, 0, 0) ; 34 BIT d,x
db opcode_clocks(2, 1, 2, 0, 0) ; 35 AND d,x
db opcode_clocks(2, 2, 4, 0, 0) ; 36 ROL d,x
db opcode_clocks(2, 0, 3, 2, 0) ; 37 AND [d],y
  								
db opcode_clocks(1, 1, 0, 0, 0) ; 38 SEC
db opcode_clocks(3, 1, 0, 2, 0) ; 39 AND a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 3A DEA
db opcode_clocks(1, 1, 0, 0, 0) ; 3B TSC
db opcode_clocks(3, 1, 0, 2, 0) ; 3C BIT a,x
db opcode_clocks(3, 1, 0, 2, 0) ; 3D AND a,x
db opcode_clocks(3, 2, 0, 4, 0) ; 3E ROL a,x
db opcode_clocks(4, 0, 0, 2, 0) ; 3F AND al,x
  								
db opcode_clocks(1, 2, 4, 0, 0) ; 40 RTI
db opcode_clocks(2, 1, 2, 2, 0) ; 41 EOR (d,x)
db opcode_clocks(2, 0, 0, 0, 0) ; 42 WDM *
db opcode_clocks(2, 1, 2, 0, 0) ; 43 EOR d,s
db opcode_clocks(3, 2, 0, 2, 0) ; 44 MVP
db opcode_clocks(2, 0, 2, 0, 0) ; 45 EOR d
db opcode_clocks(2, 1, 4, 0, 0) ; 46 LSR d
db opcode_clocks(2, 0, 3, 2, 0) ; 47 EOR [d]
  								
db opcode_clocks(1, 1, 2, 0, 0) ; 48 PHA
db opcode_clocks(3, 0, 0, 0, 0) ; 49 EOR i
db opcode_clocks(1, 1, 0, 0, 0) ; 4A SRA
db opcode_clocks(1, 1, 1, 0, 0) ; 4B PHK
db opcode_clocks(3, 0, 0, 0, 0) ; 4C JMP a
db opcode_clocks(3, 0, 0, 2, 0) ; 4D EOR a
db opcode_clocks(3, 1, 0, 4, 0) ; 4E LSR a
db opcode_clocks(4, 0, 0, 2, 0) ; 4F EOR al
  								
db opcode_clocks(2, 0, 0, 0, 0) ; 50 BVC r
db opcode_clocks(2, 1, 2, 2, 0) ; 51 EOR (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; 52 EOR (d)
db opcode_clocks(2, 2, 2, 2, 0) ; 53 EOR (d,s),y
db opcode_clocks(3, 2, 0, 2, 0) ; 54 MVN
db opcode_clocks(2, 1, 2, 0, 0) ; 55 EOR d,x
db opcode_clocks(2, 2, 4, 0, 0) ; 56 LSR d,x
db opcode_clocks(2, 0, 3, 2, 0) ; 57 EOR [d],y
  								
db opcode_clocks(1, 1, 0, 0, 0) ; 58 CLI
db opcode_clocks(3, 1, 0, 2, 0) ; 59 EOR a,y
db opcode_clocks(1, 1, 2, 0, 0) ; 5A PHY
db opcode_clocks(1, 1, 0, 0, 0) ; 5B TCD
db opcode_clocks(4, 0, 0, 0, 0) ; 5C JML al
db opcode_clocks(3, 1, 0, 2, 0) ; 5D EOR a,x
db opcode_clocks(3, 2, 0, 4, 0) ; 5E LSR a,x
db opcode_clocks(4, 0, 0, 2, 0) ; 5F EOR al,x
  								
db opcode_clocks(1, 3, 2, 0, 0) ; 60 RTS
db opcode_clocks(2, 1, 2, 2, 0) ; 61 ADC (d,x)
db opcode_clocks(3, 1, 2, 0, 0) ; 62 PER
db opcode_clocks(2, 1, 2, 0, 0) ; 63 ADC d,s
db opcode_clocks(2, 0, 2, 0, 0) ; 64 STZ d
db opcode_clocks(2, 0, 2, 0, 0) ; 65 ADC d
db opcode_clocks(2, 1, 4, 0, 0) ; 66 ROR d
db opcode_clocks(2, 0, 3, 2, 0) ; 67 ADC [d]
  								
db opcode_clocks(1, 2, 2, 0, 0) ; 68 PLA
db opcode_clocks(3, 0, 0, 0, 0) ; 69 ADC i
db opcode_clocks(1, 1, 0, 0, 0) ; 6A RRA
db opcode_clocks(1, 2, 3, 0, 0) ; 6B RTL
db opcode_clocks(3, 0, 2, 0, 0) ; 6C JMP (a)
db opcode_clocks(3, 0, 0, 2, 0) ; 6D ADC a
db opcode_clocks(3, 1, 0, 4, 0) ; 6E ROR a
db opcode_clocks(4, 0, 0, 2, 0) ; 6F ADC al
  								
db opcode_clocks(2, 0, 0, 0, 0) ; 70 BVS r
db opcode_clocks(2, 1, 2, 2, 0) ; 71 ADC (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; 72 ADC (d)
db opcode_clocks(2, 2, 2, 2, 0) ; 73 ADC (d,s),y
db opcode_clocks(2, 1, 2, 0, 0) ; 74 STZ d,x
db opcode_clocks(2, 1, 2, 0, 0) ; 75 ADC d,x
db opcode_clocks(2, 2, 4, 0, 0) ; 76 ROR d,x
db opcode_clocks(2, 0, 3, 2, 0) ; 77 ADC [d],y
  								
db opcode_clocks(1, 1, 0, 0, 0) ; 78 SEI
db opcode_clocks(3, 1, 0, 2, 0) ; 79 ADC a,y
db opcode_clocks(1, 2, 2, 0, 0) ; 7A PLY
db opcode_clocks(1, 1, 0, 0, 0) ; 7B TDC
db opcode_clocks(3, 1, 0, 2, 0) ; 7C JMP (a,x) - bus access in PB
db opcode_clocks(3, 1, 0, 2, 0) ; 7D ADC a,x
db opcode_clocks(3, 2, 0, 4, 0) ; 7E ROR a,x
db opcode_clocks(4, 0, 0, 2, 0) ; 7F ADC al,x
  								
db opcode_clocks(2, 0, 0, 0, 0) ; 80 BRA r
db opcode_clocks(2, 1, 2, 2, 0) ; 81 STA (d,x)
db opcode_clocks(3, 1, 0, 0, 0) ; 82 BRL rl
db opcode_clocks(2, 1, 2, 0, 0) ; 83 STA d,s
db opcode_clocks(2, 0, 2, 0, 0) ; 84 STY d
db opcode_clocks(2, 0, 2, 0, 0) ; 85 STA d
db opcode_clocks(2, 0, 2, 0, 0) ; 86 STX d
db opcode_clocks(2, 0, 3, 2, 0) ; 87 STA [d]
  								
db opcode_clocks(1, 1, 0, 0, 0) ; 88 DEY
db opcode_clocks(3, 0, 0, 0, 0) ; 89 BIT i
db opcode_clocks(1, 1, 0, 0, 0) ; 8A TXA
db opcode_clocks(1, 1, 1, 0, 0) ; 8B PHB
db opcode_clocks(3, 0, 0, 2, 0) ; 8C STY a
db opcode_clocks(3, 0, 0, 2, 0) ; 8D STA a
db opcode_clocks(3, 0, 0, 2, 0) ; 8E STX a
db opcode_clocks(4, 0, 0, 2, 0) ; 8F STA al
  								
db opcode_clocks(2, 0, 0, 0, 0) ; 90 BCC r
db opcode_clocks(2, 1, 2, 2, 0) ; 91 STA (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; 92 STA (d)
db opcode_clocks(2, 2, 2, 2, 0) ; 93 STA (d,s),y
db opcode_clocks(2, 1, 2, 0, 0) ; 94 STY d,x
db opcode_clocks(2, 1, 2, 0, 0) ; 95 STA d,x
db opcode_clocks(2, 1, 2, 0, 0) ; 96 STX d,y
db opcode_clocks(2, 0, 3, 2, 0) ; 97 STA [d],y
  								
db opcode_clocks(1, 1, 0, 0, 0) ; 98 TYA
db opcode_clocks(3, 1, 0, 2, 0) ; 99 STA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 9A TXS
db opcode_clocks(1, 1, 0, 0, 0) ; 9B TXY
db opcode_clocks(3, 0, 0, 2, 0) ; 9C STZ a
db opcode_clocks(3, 1, 0, 2, 0) ; 9D STA a,x
db opcode_clocks(3, 1, 0, 2, 0) ; 9E STZ a,x
db opcode_clocks(4, 0, 0, 2, 0) ; 9F STA al,x
  								
db opcode_clocks(3, 0, 0, 0, 0) ; A0 LDY i
db opcode_clocks(2, 1, 2, 2, 0) ; A1 LDA (d,x)
db opcode_clocks(3, 0, 0, 0, 0) ; A2 LDX i
db opcode_clocks(2, 1, 2, 0, 0) ; A3 LDA d,s
db opcode_clocks(2, 0, 2, 0, 0) ; A4 LDY d
db opcode_clocks(2, 0, 2, 0, 0) ; A5 LDA d
db opcode_clocks(2, 0, 2, 0, 0) ; A6 LDX d
db opcode_clocks(2, 0, 3, 2, 0) ; A7 LDA [d]
  								
db opcode_clocks(1, 1, 0, 0, 0) ; A8 TAY
db opcode_clocks(3, 0, 0, 0, 0) ; A9 LDA i
db opcode_clocks(1, 1, 0, 0, 0) ; AA TAX
db opcode_clocks(1, 2, 1, 0, 0) ; AB PLB
db opcode_clocks(3, 0, 0, 2, 0) ; AC LDY a
db opcode_clocks(3, 0, 0, 2, 0) ; AD LDA a
db opcode_clocks(3, 0, 0, 2, 0) ; AE LDX a
db opcode_clocks(4, 0, 0, 2, 0) ; AF LDA al
  								
db opcode_clocks(2, 0, 0, 0, 0) ; B0 BCS r
db opcode_clocks(2, 1, 2, 2, 0) ; B1 LDA (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; B2 LDA (d)
db opcode_clocks(2, 2, 2, 2, 0) ; B3 LDA (d,s),y
db opcode_clocks(2, 1, 2, 0, 0) ; B4 LDY d,x
db opcode_clocks(2, 1, 2, 0, 0) ; B5 LDA d,x
db opcode_clocks(2, 1, 2, 0, 0) ; B6 LDX d,y
db opcode_clocks(2, 0, 3, 2, 0) ; B7 LDA [d],y
  								
db opcode_clocks(1, 1, 0, 0, 0) ; B8 CLV
db opcode_clocks(3, 1, 0, 2, 0) ; B9 LDA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; BA TSX
db opcode_clocks(1, 1, 0, 0, 0) ; BB TYX
db opcode_clocks(3, 1, 0, 2, 0) ; BC LDY a,x
db opcode_clocks(3, 1, 0, 2, 0) ; BD LDA a,x
db opcode_clocks(3, 1, 0, 2, 0) ; BE LDX a,y
db opcode_clocks(4, 0, 0, 2, 0) ; BF LDA al,x
  								
db opcode_clocks(3, 0, 0, 0, 0) ; C0 CPY i
db opcode_clocks(2, 1, 2, 2, 0) ; C1 CMP (d,x)
db opcode_clocks(2, 1, 0, 0, 0) ; C2 REP i
db opcode_clocks(2, 1, 2, 0, 0) ; C3 CMP d,s
db opcode_clocks(2, 0, 2, 0, 0) ; C4 CPY d
db opcode_clocks(2, 0, 2, 0, 0) ; C5 CMP d
db opcode_clocks(2, 1, 4, 0, 0) ; C6 DEC d
db opcode_clocks(2, 0, 3, 2, 0) ; C7 CMP [d]
  								
db opcode_clocks(1, 1, 0, 0, 0) ; C8 INY
db opcode_clocks(3, 0, 0, 0, 0) ; C9 CMP i
db opcode_clocks(1, 1, 0, 0, 0) ; CA DEX
db opcode_clocks(1, 2, 0, 0, 0) ; CB WAI
db opcode_clocks(3, 0, 0, 2, 0) ; CC CPY a
db opcode_clocks(3, 0, 0, 2, 0) ; CD CMP a
db opcode_clocks(3, 1, 0, 4, 0) ; CE DEC a
db opcode_clocks(4, 0, 0, 2, 0) ; CF CMP al
  								
db opcode_clocks(2, 0, 0, 0, 0) ; D0 BNE r
db opcode_clocks(2, 1, 2, 2, 0) ; D1 CMP (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; D2 CMP (d)
db opcode_clocks(2, 2, 2, 2, 0) ; D3 CMP (d,s),y
db opcode_clocks(2, 0, 4, 0, 0) ; D4 PEI
db opcode_clocks(2, 1, 2, 0, 0) ; D5 CMP d,x
db opcode_clocks(2, 2, 4, 0, 0) ; D6 DEC d,x
db opcode_clocks(2, 0, 3, 2, 0) ; D7 CMP [d],y
  								
db opcode_clocks(1, 1, 0, 0, 0) ; D8 CLD
db opcode_clocks(3, 1, 0, 2, 0) ; D9 CMP a,y
db opcode_clocks(1, 1, 2, 0, 0) ; DA PHX
db opcode_clocks(1, 2, 0, 0, 0) ; DB STP *
db opcode_clocks(3, 0, 3, 0, 0) ; DC JML (a)
db opcode_clocks(3, 1, 0, 2, 0) ; DD CMP a,x
db opcode_clocks(3, 2, 0, 4, 0) ; DE DEC a,x
db opcode_clocks(4, 0, 0, 2, 0) ; DF CMP al,x
  								
db opcode_clocks(3, 0, 0, 0, 0) ; E0 CPX i
db opcode_clocks(2, 1, 2, 2, 0) ; E1 SBC (d,x)
db opcode_clocks(2, 1, 0, 0, 0) ; E2 SEP i
db opcode_clocks(2, 1, 2, 0, 0) ; E3 SBC d,s
db opcode_clocks(2, 0, 2, 0, 0) ; E4 CPX d
db opcode_clocks(2, 0, 2, 0, 0) ; E5 SBC d
db opcode_clocks(2, 1, 4, 0, 0) ; E6 INC d
db opcode_clocks(2, 0, 3, 2, 0) ; E7 SBC [d]
  								
db opcode_clocks(1, 1, 0, 0, 0) ; E8 INX
db opcode_clocks(3, 0, 0, 0, 0) ; E9 SBC i
db opcode_clocks(1, 1, 0, 0, 0) ; EA NOP
db opcode_clocks(1, 2, 0, 0, 0) ; EB XBA
db opcode_clocks(3, 0, 0, 2, 0) ; EC CPX a
db opcode_clocks(3, 0, 0, 2, 0) ; ED SBC a
db opcode_clocks(3, 1, 0, 4, 0) ; EE INC a
db opcode_clocks(4, 0, 0, 2, 0) ; EF SBC al
  								
db opcode_clocks(2, 0, 0, 0, 0) ; F0 BEQ r
db opcode_clocks(2, 1, 2, 2, 0) ; F1 SBC (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; F2 SBC (d)
db opcode_clocks(2, 2, 2, 2, 0) ; F3 SBC (d,s),y
db opcode_clocks(3, 0, 2, 0, 0) ; F4 PEA
db opcode_clocks(2, 1, 2, 0, 0) ; F5 SBC d,x
db opcode_clocks(2, 2, 4, 0, 0) ; F6 INC d,x
db opcode_clocks(2, 0, 3, 2, 0) ; F7 SBC [d],y
  								
db opcode_clocks(1, 1, 0, 0, 0) ; F8 SED
db opcode_clocks(3, 1, 0, 2, 0) ; F9 SBC a,y
db opcode_clocks(1, 2, 2, 0, 0) ; FA PLX
db opcode_clocks(1, 1, 0, 0, 0) ; FB XCE
db opcode_clocks(3, 1, 2, 2, 0) ; FC JSR (a,x) - bus access in PB
db opcode_clocks(3, 1, 0, 2, 0) ; FD SBC a,x
db opcode_clocks(3, 2, 0, 4, 0) ; FE INC a,x
db opcode_clocks(4, 0, 0, 2, 0) ; FF SBC al,x

; FastROM
db opcode_clocks(2, 0, 6, 0, 1) ; 00 BRK
db opcode_clocks(2, 1, 2, 2, 1) ; 01 ORA (d,x)
db opcode_clocks(2, 0, 6, 0, 1) ; 02 COP
db opcode_clocks(2, 1, 2, 0, 1) ; 03 ORA d,s
db opcode_clocks(2, 1, 4, 0, 1) ; 04 TSB d
db opcode_clocks(2, 0, 2, 0, 1) ; 05 ORA d
db opcode_clocks(2, 1, 4, 0, 1) ; 06 ASL d
db opcode_clocks(2, 0, 3, 2, 1) ; 07 ORA [d]
							
db opcode_clocks(1, 1, 1, 0, 1) ; 08 PHP
db opcode_clocks(3, 0, 0, 0, 1) ; 09 ORA i
db opcode_clocks(1, 1, 0, 0, 1) ; 0A SLA
db opcode_clocks(1, 1, 2, 0, 1) ; 0B PHD
db opcode_clocks(3, 1, 0, 4, 1) ; 0C TSB a
db opcode_clocks(3, 0, 0, 2, 1) ; 0D ORA a
db opcode_clocks(3, 1, 0, 4, 1) ; 0E ASL a
db opcode_clocks(4, 0, 0, 2, 1) ; 0F ORA al
							
db opcode_clocks(2, 0, 0, 0, 1) ; 10 BPL r
db opcode_clocks(2, 1, 2, 2, 1) ; 11 ORA (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; 12 ORA (d)
db opcode_clocks(2, 2, 2, 2, 1) ; 13 ORA (d,s),y
db opcode_clocks(2, 1, 4, 0, 1) ; 14 TRB d
db opcode_clocks(2, 1, 2, 0, 1) ; 15 ORA d,x
db opcode_clocks(2, 2, 4, 0, 1) ; 16 ASL d,x
db opcode_clocks(2, 0, 3, 2, 1) ; 17 ORA [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; 18 CLC
db opcode_clocks(3, 1, 0, 2, 1) ; 19 ORA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 1A INA
db opcode_clocks(1, 1, 0, 0, 1) ; 1B TCS
db opcode_clocks(3, 1, 0, 4, 1) ; 1C TRB a
db opcode_clocks(3, 1, 0, 2, 1) ; 1D ORA a,x
db opcode_clocks(3, 2, 0, 4, 1) ; 1E ASL a,x
db opcode_clocks(4, 0, 0, 2, 1) ; 1F ORA al,x
							
db opcode_clocks(3, 1, 2, 0, 1) ; 20 JSR a
db opcode_clocks(2, 1, 2, 2, 1) ; 21 AND (d,x)
db opcode_clocks(4, 1, 3, 0, 1) ; 22 JSL al
db opcode_clocks(2, 1, 2, 0, 1) ; 23 AND d,s
db opcode_clocks(2, 0, 2, 0, 1) ; 24 BIT d
db opcode_clocks(2, 0, 2, 0, 1) ; 25 AND d
db opcode_clocks(2, 1, 4, 0, 1) ; 26 ROL d
db opcode_clocks(2, 0, 3, 2, 1) ; 27 AND [d]
							
db opcode_clocks(1, 2, 1, 0, 1) ; 28 PLP
db opcode_clocks(3, 0, 0, 0, 1) ; 29 AND i
db opcode_clocks(1, 1, 0, 0, 1) ; 2A RLA
db opcode_clocks(1, 2, 2, 0, 1) ; 2B PLD
db opcode_clocks(3, 0, 0, 2, 1) ; 2C BIT a
db opcode_clocks(3, 0, 0, 2, 1) ; 2D AND a
db opcode_clocks(3, 1, 0, 4, 1) ; 2E ROL a
db opcode_clocks(4, 0, 0, 2, 1) ; 2F AND al
							
db opcode_clocks(2, 0, 0, 0, 1) ; 30 BMI r
db opcode_clocks(2, 1, 2, 2, 1) ; 31 AND (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; 32 AND (d)
db opcode_clocks(2, 2, 2, 2, 1) ; 33 AND (d,s),y
db opcode_clocks(2, 1, 2, 0, 1) ; 34 BIT d,x
db opcode_clocks(2, 1, 2, 0, 1) ; 35 AND d,x
db opcode_clocks(2, 2, 4, 0, 1) ; 36 ROL d,x
db opcode_clocks(2, 0, 3, 2, 1) ; 37 AND [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; 38 SEC
db opcode_clocks(3, 1, 0, 2, 1) ; 39 AND a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 3A DEA
db opcode_clocks(1, 1, 0, 0, 1) ; 3B TSC
db opcode_clocks(3, 1, 0, 2, 1) ; 3C BIT a,x
db opcode_clocks(3, 1, 0, 2, 1) ; 3D AND a,x
db opcode_clocks(3, 2, 0, 4, 1) ; 3E ROL a,x
db opcode_clocks(4, 0, 0, 2, 1) ; 3F AND al,x
							
db opcode_clocks(1, 2, 4, 0, 1) ; 40 RTI
db opcode_clocks(2, 1, 2, 2, 1) ; 41 EOR (d,x)
db opcode_clocks(2, 0, 0, 0, 1) ; 42 WDM *
db opcode_clocks(2, 1, 2, 0, 1) ; 43 EOR d,s
db opcode_clocks(3, 2, 0, 2, 1) ; 44 MVP
db opcode_clocks(2, 0, 2, 0, 1) ; 45 EOR d
db opcode_clocks(2, 1, 4, 0, 1) ; 46 LSR d
db opcode_clocks(2, 0, 3, 2, 1) ; 47 EOR [d]
							
db opcode_clocks(1, 1, 2, 0, 1) ; 48 PHA
db opcode_clocks(3, 0, 0, 0, 1) ; 49 EOR i
db opcode_clocks(1, 1, 0, 0, 1) ; 4A SRA
db opcode_clocks(1, 1, 1, 0, 1) ; 4B PHK
db opcode_clocks(3, 0, 0, 0, 1) ; 4C JMP a
db opcode_clocks(3, 0, 0, 2, 1) ; 4D EOR a
db opcode_clocks(3, 1, 0, 4, 1) ; 4E LSR a
db opcode_clocks(4, 0, 0, 2, 1) ; 4F EOR al
							
db opcode_clocks(2, 0, 0, 0, 1) ; 50 BVC r
db opcode_clocks(2, 1, 2, 2, 1) ; 51 EOR (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; 52 EOR (d)
db opcode_clocks(2, 2, 2, 2, 1) ; 53 EOR (d,s),y
db opcode_clocks(3, 2, 0, 2, 1) ; 54 MVN
db opcode_clocks(2, 1, 2, 0, 1) ; 55 EOR d,x
db opcode_clocks(2, 2, 4, 0, 1) ; 56 LSR d,x
db opcode_clocks(2, 0, 3, 2, 1) ; 57 EOR [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; 58 CLI
db opcode_clocks(3, 1, 0, 2, 1) ; 59 EOR a,y
db opcode_clocks(1, 1, 2, 0, 1) ; 5A PHY
db opcode_clocks(1, 1, 0, 0, 1) ; 5B TCD
db opcode_clocks(4, 0, 0, 0, 1) ; 5C JML al
db opcode_clocks(3, 1, 0, 2, 1) ; 5D EOR a,x
db opcode_clocks(3, 2, 0, 4, 1) ; 5E LSR a,x
db opcode_clocks(4, 0, 0, 2, 1) ; 5F EOR al,x
							
db opcode_clocks(1, 3, 2, 0, 1) ; 60 RTS
db opcode_clocks(2, 1, 2, 2, 1) ; 61 ADC (d,x)
db opcode_clocks(3, 1, 2, 0, 1) ; 62 PER
db opcode_clocks(2, 1, 2, 0, 1) ; 63 ADC d,s
db opcode_clocks(2, 0, 2, 0, 1) ; 64 STZ d
db opcode_clocks(2, 0, 2, 0, 1) ; 65 ADC d
db opcode_clocks(2, 1, 4, 0, 1) ; 66 ROR d
db opcode_clocks(2, 0, 3, 2, 1) ; 67 ADC [d]
							
db opcode_clocks(1, 2, 2, 0, 1) ; 68 PLA
db opcode_clocks(3, 0, 0, 0, 1) ; 69 ADC i
db opcode_clocks(1, 1, 0, 0, 1) ; 6A RRA
db opcode_clocks(1, 2, 3, 0, 1) ; 6B RTL
db opcode_clocks(3, 0, 2, 0, 1) ; 6C JMP (a)
db opcode_clocks(3, 0, 0, 2, 1) ; 6D ADC a
db opcode_clocks(3, 1, 0, 4, 1) ; 6E ROR a
db opcode_clocks(4, 0, 0, 2, 1) ; 6F ADC al
							
db opcode_clocks(2, 0, 0, 0, 1) ; 70 BVS r
db opcode_clocks(2, 1, 2, 2, 1) ; 71 ADC (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; 72 ADC (d)
db opcode_clocks(2, 2, 2, 2, 1) ; 73 ADC (d,s),y
db opcode_clocks(2, 1, 2, 0, 1) ; 74 STZ d,x
db opcode_clocks(2, 1, 2, 0, 1) ; 75 ADC d,x
db opcode_clocks(2, 2, 4, 0, 1) ; 76 ROR d,x
db opcode_clocks(2, 0, 3, 2, 1) ; 77 ADC [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; 78 SEI
db opcode_clocks(3, 1, 0, 2, 1) ; 79 ADC a,y
db opcode_clocks(1, 2, 2, 0, 1) ; 7A PLY
db opcode_clocks(1, 1, 0, 0, 1) ; 7B TDC
db opcode_clocks(3, 1, 0, 2, 1) ; 7C JMP (a,x) - bus access in PB
db opcode_clocks(3, 1, 0, 2, 1) ; 7D ADC a,x
db opcode_clocks(3, 2, 0, 4, 1) ; 7E ROR a,x
db opcode_clocks(4, 0, 0, 2, 1) ; 7F ADC al,x
							
db opcode_clocks(2, 0, 0, 0, 1) ; 80 BRA r
db opcode_clocks(2, 1, 2, 2, 1) ; 81 STA (d,x)
db opcode_clocks(3, 1, 0, 0, 1) ; 82 BRL rl
db opcode_clocks(2, 1, 2, 0, 1) ; 83 STA d,s
db opcode_clocks(2, 0, 2, 0, 1) ; 84 STY d
db opcode_clocks(2, 0, 2, 0, 1) ; 85 STA d
db opcode_clocks(2, 0, 2, 0, 1) ; 86 STX d
db opcode_clocks(2, 0, 3, 2, 1) ; 87 STA [d]
							
db opcode_clocks(1, 1, 0, 0, 1) ; 88 DEY
db opcode_clocks(3, 0, 0, 0, 1) ; 89 BIT i
db opcode_clocks(1, 1, 0, 0, 1) ; 8A TXA
db opcode_clocks(1, 1, 1, 0, 1) ; 8B PHB
db opcode_clocks(3, 0, 0, 2, 1) ; 8C STY a
db opcode_clocks(3, 0, 0, 2, 1) ; 8D STA a
db opcode_clocks(3, 0, 0, 2, 1) ; 8E STX a
db opcode_clocks(4, 0, 0, 2, 1) ; 8F STA al
							
db opcode_clocks(2, 0, 0, 0, 1) ; 90 BCC r
db opcode_clocks(2, 1, 2, 2, 1) ; 91 STA (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; 92 STA (d)
db opcode_clocks(2, 2, 2, 2, 1) ; 93 STA (d,s),y
db opcode_clocks(2, 1, 2, 0, 1) ; 94 STY d,x
db opcode_clocks(2, 1, 2, 0, 1) ; 95 STA d,x
db opcode_clocks(2, 1, 2, 0, 1) ; 96 STX d,y
db opcode_clocks(2, 0, 3, 2, 1) ; 97 STA [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; 98 TYA
db opcode_clocks(3, 1, 0, 2, 1) ; 99 STA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 9A TXS
db opcode_clocks(1, 1, 0, 0, 1) ; 9B TXY
db opcode_clocks(3, 0, 0, 2, 1) ; 9C STZ a
db opcode_clocks(3, 1, 0, 2, 1) ; 9D STA a,x
db opcode_clocks(3, 1, 0, 2, 1) ; 9E STZ a,x
db opcode_clocks(4, 0, 0, 2, 1) ; 9F STA al,x
							
db opcode_clocks(3, 0, 0, 0, 1) ; A0 LDY i
db opcode_clocks(2, 1, 2, 2, 1) ; A1 LDA (d,x)
db opcode_clocks(3, 0, 0, 0, 1) ; A2 LDX i
db opcode_clocks(2, 1, 2, 0, 1) ; A3 LDA d,s
db opcode_clocks(2, 0, 2, 0, 1) ; A4 LDY d
db opcode_clocks(2, 0, 2, 0, 1) ; A5 LDA d
db opcode_clocks(2, 0, 2, 0, 1) ; A6 LDX d
db opcode_clocks(2, 0, 3, 2, 1) ; A7 LDA [d]
							
db opcode_clocks(1, 1, 0, 0, 1) ; A8 TAY
db opcode_clocks(3, 0, 0, 0, 1) ; A9 LDA i
db opcode_clocks(1, 1, 0, 0, 1) ; AA TAX
db opcode_clocks(1, 2, 1, 0, 1) ; AB PLB
db opcode_clocks(3, 0, 0, 2, 1) ; AC LDY a
db opcode_clocks(3, 0, 0, 2, 1) ; AD LDA a
db opcode_clocks(3, 0, 0, 2, 1) ; AE LDX a
db opcode_clocks(4, 0, 0, 2, 1) ; AF LDA al
							
db opcode_clocks(2, 0, 0, 0, 1) ; B0 BCS r
db opcode_clocks(2, 1, 2, 2, 1) ; B1 LDA (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; B2 LDA (d)
db opcode_clocks(2, 2, 2, 2, 1) ; B3 LDA (d,s),y
db opcode_clocks(2, 1, 2, 0, 1) ; B4 LDY d,x
db opcode_clocks(2, 1, 2, 0, 1) ; B5 LDA d,x
db opcode_clocks(2, 1, 2, 0, 1) ; B6 LDX d,y
db opcode_clocks(2, 0, 3, 2, 1) ; B7 LDA [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; B8 CLV
db opcode_clocks(3, 1, 0, 2, 1) ; B9 LDA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; BA TSX
db opcode_clocks(1, 1, 0, 0, 1) ; BB TYX
db opcode_clocks(3, 1, 0, 2, 1) ; BC LDY a,x
db opcode_clocks(3, 1, 0, 2, 1) ; BD LDA a,x
db opcode_clocks(3, 1, 0, 2, 1) ; BE LDX a,y
db opcode_clocks(4, 0, 0, 2, 1) ; BF LDA al,x
							
db opcode_clocks(3, 0, 0, 0, 1) ; C0 CPY i
db opcode_clocks(2, 1, 2, 2, 1) ; C1 CMP (d,x)
db opcode_clocks(2, 1, 0, 0, 1) ; C2 REP i
db opcode_clocks(2, 1, 2, 0, 1) ; C3 CMP d,s
db opcode_clocks(2, 0, 2, 0, 1) ; C4 CPY d
db opcode_clocks(2, 0, 2, 0, 1) ; C5 CMP d
db opcode_clocks(2, 1, 4, 0, 1) ; C6 DEC d
db opcode_clocks(2, 0, 3, 2, 1) ; C7 CMP [d]
							
db opcode_clocks(1, 1, 0, 0, 1) ; C8 INY
db opcode_clocks(3, 0, 0, 0, 1) ; C9 CMP i
db opcode_clocks(1, 1, 0, 0, 1) ; CA DEX
db opcode_clocks(1, 2, 0, 0, 1) ; CB WAI
db opcode_clocks(3, 0, 0, 2, 1) ; CC CPY a
db opcode_clocks(3, 0, 0, 2, 1) ; CD CMP a
db opcode_clocks(3, 1, 0, 4, 1) ; CE DEC a
db opcode_clocks(4, 0, 0, 2, 1) ; CF CMP al
							
db opcode_clocks(2, 0, 0, 0, 1) ; D0 BNE r
db opcode_clocks(2, 1, 2, 2, 1) ; D1 CMP (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; D2 CMP (d)
db opcode_clocks(2, 2, 2, 2, 1) ; D3 CMP (d,s),y
db opcode_clocks(2, 0, 4, 0, 1) ; D4 PEI
db opcode_clocks(2, 1, 2, 0, 1) ; D5 CMP d,x
db opcode_clocks(2, 2, 4, 0, 1) ; D6 DEC d,x
db opcode_clocks(2, 0, 3, 2, 1) ; D7 CMP [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; D8 CLD
db opcode_clocks(3, 1, 0, 2, 1) ; D9 CMP a,y
db opcode_clocks(1, 1, 2, 0, 1) ; DA PHX
db opcode_clocks(1, 2, 0, 0, 1) ; DB STP *
db opcode_clocks(3, 0, 3, 0, 1) ; DC JML (a)
db opcode_clocks(3, 1, 0, 2, 1) ; DD CMP a,x
db opcode_clocks(3, 2, 0, 4, 1) ; DE DEC a,x
db opcode_clocks(4, 0, 0, 2, 1) ; DF CMP al,x
							
db opcode_clocks(3, 0, 0, 0, 1) ; E0 CPX i
db opcode_clocks(2, 1, 2, 2, 1) ; E1 SBC (d,x)
db opcode_clocks(2, 1, 0, 0, 1) ; E2 SEP i
db opcode_clocks(2, 1, 2, 0, 1) ; E3 SBC d,s
db opcode_clocks(2, 0, 2, 0, 1) ; E4 CPX d
db opcode_clocks(2, 0, 2, 0, 1) ; E5 SBC d
db opcode_clocks(2, 1, 4, 0, 1) ; E6 INC d
db opcode_clocks(2, 0, 3, 2, 1) ; E7 SBC [d]
							
db opcode_clocks(1, 1, 0, 0, 1) ; E8 INX
db opcode_clocks(3, 0, 0, 0, 1) ; E9 SBC i
db opcode_clocks(1, 1, 0, 0, 1) ; EA NOP
db opcode_clocks(1, 2, 0, 0, 1) ; EB XBA
db opcode_clocks(3, 0, 0, 2, 1) ; EC CPX a
db opcode_clocks(3, 0, 0, 2, 1) ; ED SBC a
db opcode_clocks(3, 1, 0, 4, 1) ; EE INC a
db opcode_clocks(4, 0, 0, 2, 1) ; EF SBC al
							
db opcode_clocks(2, 0, 0, 0, 1) ; F0 BEQ r
db opcode_clocks(2, 1, 2, 2, 1) ; F1 SBC (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; F2 SBC (d)
db opcode_clocks(2, 2, 2, 2, 1) ; F3 SBC (d,s),y
db opcode_clocks(3, 0, 2, 0, 1) ; F4 PEA
db opcode_clocks(2, 1, 2, 0, 1) ; F5 SBC d,x
db opcode_clocks(2, 2, 4, 0, 1) ; F6 INC d,x
db opcode_clocks(2, 0, 3, 2, 1) ; F7 SBC [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; F8 SED
db opcode_clocks(3, 1, 0, 2, 1) ; F9 SBC a,y
db opcode_clocks(1, 2, 2, 0, 1) ; FA PLX
db opcode_clocks(1, 1, 0, 0, 1) ; FB XCE
db opcode_clocks(3, 1, 2, 2, 1) ; FC JSR (a,x) - bus access in PB
db opcode_clocks(3, 1, 0, 2, 1) ; FD SBC a,x
db opcode_clocks(3, 2, 0, 4, 1) ; FE INC a,x
db opcode_clocks(4, 0, 0, 2, 1) ; FF SBC al,x

OpTablePm:
dd  C_LABEL(E0_BRK)       ,C_LABEL(EM_ORA_Od_xO)    ; 00
dd  C_LABEL(E0_COP)       ,C_LABEL(OpM1_0x03)
dd  C_LABEL(OpE0M1_0x04)  ,C_LABEL(EM_ORA_d)
dd  C_LABEL(OpE0M1_0x06)  ,C_LABEL(EM_ORA_IdI)
dd  C_LABEL(E0_PHP)       ,C_LABEL(OpM1_0x09)
dd  C_LABEL(OpM1_0x0A)    ,C_LABEL(E0_PHD)
dd  C_LABEL(OpM1_0x0C)    ,C_LABEL(OpM1_0x0D)
dd  C_LABEL(OpM1_0x0E)    ,C_LABEL(OpM1_0x0F)
dd  C_LABEL(ALL_BPL)      ,C_LABEL(OpE0M1X0_0x11)   ; 10
dd  C_LABEL(EM_ORA_OdO)   ,C_LABEL(OpM1_0x13)
dd  C_LABEL(OpE0M1_0x14)  ,C_LABEL(EM_ORA_d_x)
dd  C_LABEL(OpE0M1_0x16)  ,C_LABEL(EM_ORA_IdI_y)
dd  C_LABEL(ALL_CLC)      ,C_LABEL(EM_ORA_a_y)
dd  C_LABEL(OpM1_0x1A)    ,C_LABEL(E0_TCS)
dd  C_LABEL(OpM1_0x1C)    ,C_LABEL(EM_ORA_a_x)
dd  C_LABEL(OpM1_0x1E)    ,C_LABEL(EM_ORA_al_x)
dd  C_LABEL(E0_JSR_a)     ,C_LABEL(EM_AND_Od_xO)    ; 20
dd  C_LABEL(E0_JSL_al)    ,C_LABEL(OpM1_0x23)
dd  C_LABEL(EM_BIT_d)     ,C_LABEL(EM_AND_d)
dd  C_LABEL(OpE0M1_0x26)  ,C_LABEL(EM_AND_IdI)
dd  C_LABEL(E0_PLP)       ,C_LABEL(OpM1_0x29)
dd  C_LABEL(OpM1_0x2A)    ,C_LABEL(E0_PLD)
dd  C_LABEL(OpM1_0x2C)    ,C_LABEL(OpM1_0x2D)
dd  C_LABEL(OpM1_0x2E)    ,C_LABEL(OpM1_0x2F)
dd  C_LABEL(ALL_BMI)      ,C_LABEL(OpE0M1X0_0x31)   ; 30
dd  C_LABEL(EM_AND_OdO)   ,C_LABEL(OpM1_0x33)
dd  C_LABEL(EM_BIT_d_x)   ,C_LABEL(EM_AND_d_x)
dd  C_LABEL(OpE0M1_0x36)  ,C_LABEL(EM_AND_IdI_y)
dd  C_LABEL(ALL_SEC)      ,C_LABEL(EM_AND_a_y)
dd  C_LABEL(OpM1_0x3A)    ,C_LABEL(ALL_TSC)
dd  C_LABEL(EM_BIT_a_x)   ,C_LABEL(EM_AND_a_x)
dd  C_LABEL(OpM1_0x3E)    ,C_LABEL(EM_AND_al_x)
dd  C_LABEL(E0_RTI)       ,C_LABEL(EM_EOR_Od_xO)    ; 40
dd  C_LABEL(ALL_INVALID)  ,C_LABEL(OpM1_0x43)
dd  C_LABEL(E0_MVP)       ,C_LABEL(EM_EOR_d)
dd  C_LABEL(OpE0M1_0x46)  ,C_LABEL(EM_EOR_IdI)
dd  C_LABEL(EM_PHA)       ,C_LABEL(OpM1_0x49)
dd  C_LABEL(OpM1_0x4A)    ,C_LABEL(E0_PHK)
dd  C_LABEL(ALL_JMP_a)    ,C_LABEL(OpM1_0x4D)
dd  C_LABEL(OpM1_0x4E)    ,C_LABEL(OpM1_0x4F)
dd  C_LABEL(ALL_BVC)      ,C_LABEL(OpE0M1X0_0x51)   ; 50
dd  C_LABEL(EM_EOR_OdO)   ,C_LABEL(OpM1_0x53)
dd  C_LABEL(E0_MVN)       ,C_LABEL(EM_EOR_d_x)
dd  C_LABEL(OpE0M1_0x56)  ,C_LABEL(EM_EOR_IdI_y)
dd  C_LABEL(ALL_CLI)      ,C_LABEL(EM_EOR_a_y)
dd  C_LABEL(E0_PHY)       ,C_LABEL(ALL_TCD)
dd  C_LABEL(ALL_JML_al)   ,C_LABEL(EM_EOR_a_x)
dd  C_LABEL(OpM1_0x5E)    ,C_LABEL(EM_EOR_al_x)
dd  C_LABEL(E0_RTS)       ,C_LABEL(EM_ADC_Od_xO)    ; 60
dd  C_LABEL(E0_PER)       ,C_LABEL(OpM1_0x63)
dd  C_LABEL(OpE0M1_0x64)  ,C_LABEL(EM_ADC_d)
dd  C_LABEL(OpE0M1_0x66)  ,C_LABEL(EM_ADC_IdI)
dd  C_LABEL(EM_PLA)       ,C_LABEL(OpM1_0x69)
dd  C_LABEL(OpM1_0x6A)    ,C_LABEL(E0_RTL)
dd  C_LABEL(ALL_JMP_OaO)  ,C_LABEL(OpM1_0x6D)
dd  C_LABEL(OpM1_0x6E)    ,C_LABEL(OpM1_0x6F)
dd  C_LABEL(ALL_BVS)      ,C_LABEL(OpE0M1X0_0x71)   ; 70
dd  C_LABEL(EM_ADC_OdO)   ,C_LABEL(OpM1_0x73)
dd  C_LABEL(OpE0M1_0x74)  ,C_LABEL(EM_ADC_d_x)
dd  C_LABEL(OpE0M1_0x76)  ,C_LABEL(EM_ADC_IdI_y)
dd  C_LABEL(ALL_SEI)      ,C_LABEL(EM_ADC_a_y)
dd  C_LABEL(E0_PLY)       ,C_LABEL(ALL_TDC)
dd  C_LABEL(ALL_JMP_Oa_xO),C_LABEL(EM_ADC_a_x)
dd  C_LABEL(OpM1_0x7E)    ,C_LABEL(EM_ADC_al_x)
dd  C_LABEL(ALL_BRA)      ,C_LABEL(OpE0M1_0x81)     ; 80
dd  C_LABEL(ALL_BRL)      ,C_LABEL(OpM1_0x83)
dd  C_LABEL(OpE0X0_0x84)  ,C_LABEL(OpE0M1_0x85)
dd  C_LABEL(OpE0X0_0x86)  ,C_LABEL(OpE0M1_0x87)
dd  C_LABEL(OpX0_0x88)    ,C_LABEL(EM_BIT_i)
dd  C_LABEL(EM_TXA)       ,C_LABEL(E0_PHB)
dd  C_LABEL(OpX0_0x8C)    ,C_LABEL(OpM1_0x8D)
dd  C_LABEL(OpX0_0x8E)    ,C_LABEL(OpM1_0x8F)
dd  C_LABEL(ALL_BCC)      ,C_LABEL(OpE0M1X0_0x91)   ; 90
dd  C_LABEL(OpE0M1_0x92)  ,C_LABEL(OpM1_0x93)
dd  C_LABEL(OpE0X0_0x94)  ,C_LABEL(OpE0M1_0x95)
dd  C_LABEL(OpE0X0_0x96)  ,C_LABEL(OpE0M1_0x97)
dd  C_LABEL(EM_TYA)       ,C_LABEL(OpM1_0x99)
dd  C_LABEL(E0_TXS)       ,C_LABEL(E0_TXY)
dd  C_LABEL(OpM1_0x9C)    ,C_LABEL(OpM1_0x9D)
dd  C_LABEL(OpM1_0x9E)    ,C_LABEL(OpM1_0x9F)
dd  C_LABEL(OpX0_0xA0)    ,C_LABEL(EM_LDA_Od_xO)    ; A0
dd  C_LABEL(OpX0_0xA2)    ,C_LABEL(OpM1_0xA3)
dd  C_LABEL(E0_LDY_d)     ,C_LABEL(EM_LDA_d)
dd  C_LABEL(E0_LDX_d)     ,C_LABEL(EM_LDA_IdI)
dd  C_LABEL(E0_TAY)       ,C_LABEL(OpM1_0xA9)
dd  C_LABEL(E0_TAX)       ,C_LABEL(E0_PLB)
dd  C_LABEL(OpX0_0xAC)    ,C_LABEL(OpM1_0xAD)
dd  C_LABEL(OpX0_0xAE)    ,C_LABEL(OpM1_0xAF)
dd  C_LABEL(ALL_BCS)      ,C_LABEL(OpE0M1X0_0xB1)   ; B0
dd  C_LABEL(EM_LDA_OdO)   ,C_LABEL(OpM1_0xB3)
dd  C_LABEL(E0_LDY_d_x)   ,C_LABEL(EM_LDA_d_x)
dd  C_LABEL(E0_LDX_d_y)   ,C_LABEL(EM_LDA_IdI_y)
dd  C_LABEL(ALL_CLV)      ,C_LABEL(EM_LDA_a_y)
dd  C_LABEL(E0_TSX)       ,C_LABEL(E0_TYX)
dd  C_LABEL(E0_LDY_a_x)   ,C_LABEL(EM_LDA_a_x)
dd  C_LABEL(E0_LDX_a_y)   ,C_LABEL(EM_LDA_al_x)
dd  C_LABEL(OpX0_0xC0)    ,C_LABEL(EM_CMP_Od_xO)    ; C0
dd  C_LABEL(E0_REP)       ,C_LABEL(OpM1_0xC3)
dd  C_LABEL(E0_CPY_d)     ,C_LABEL(EM_CMP_d)
dd  C_LABEL(OpE0M1_0xC6)  ,C_LABEL(EM_CMP_IdI)
dd  C_LABEL(OpX0_0xC8)    ,C_LABEL(OpM1_0xC9)
dd  C_LABEL(OpX0_0xCA)    ,C_LABEL(ALL_WAI)
dd  C_LABEL(OpX0_0xCC)    ,C_LABEL(OpM1_0xCD)
dd  C_LABEL(OpM1_0xCE)    ,C_LABEL(OpM1_0xCF)
dd  C_LABEL(ALL_BNE)      ,C_LABEL(OpE0M1X0_0xD1)   ; D0
dd  C_LABEL(EM_CMP_OdO)   ,C_LABEL(OpM1_0xD3)
dd  C_LABEL(E0_PEI)       ,C_LABEL(EM_CMP_d_x)
dd  C_LABEL(OpE0M1_0xD6)  ,C_LABEL(EM_CMP_IdI_y)
dd  C_LABEL(ALL_CLD)      ,C_LABEL(EM_CMP_a_y)
dd  C_LABEL(E0_PHX)       ,C_LABEL(ALL_INVALID)
dd  C_LABEL(ALL_JML_OaO)  ,C_LABEL(EM_CMP_a_x)
dd  C_LABEL(OpM1_0xDE)    ,C_LABEL(EM_CMP_al_x)
dd  C_LABEL(OpX0_0xE0)    ,C_LABEL(EM_SBC_Od_xO)    ; E0
dd  C_LABEL(E0_SEP)       ,C_LABEL(OpM1_0xE3)
dd  C_LABEL(E0_CPX_d)     ,C_LABEL(EM_SBC_d)
dd  C_LABEL(OpE0M1_0xE6)  ,C_LABEL(EM_SBC_IdI)
dd  C_LABEL(OpX0_0xE8)    ,C_LABEL(OpM1_0xE9)
dd  C_LABEL(ALL_NOP)      ,C_LABEL(ALL_XBA)
dd  C_LABEL(OpX0_0xEC)    ,C_LABEL(OpM1_0xED)
dd  C_LABEL(OpM1_0xEE)    ,C_LABEL(OpM1_0xEF)
dd  C_LABEL(ALL_BEQ)      ,C_LABEL(OpE0M1X0_0xF1)   ; F0
dd  C_LABEL(EM_SBC_OdO)   ,C_LABEL(OpM1_0xF3)
dd  C_LABEL(E0_PEA)       ,C_LABEL(EM_SBC_d_x)
dd  C_LABEL(OpE0M1_0xF6)  ,C_LABEL(EM_SBC_IdI_y)
dd  C_LABEL(ALL_SED)      ,C_LABEL(EM_SBC_a_y)
dd  C_LABEL(E0_PLX)       ,C_LABEL(E0_XCE)
dd  C_LABEL(E0_JSR_Oa_xO) ,C_LABEL(EM_SBC_a_x)
dd  C_LABEL(OpM1_0xFE)    ,C_LABEL(EM_SBC_al_x)

; bytes, internal operations, bank 0 accesses, other bus accesses, speed
;  speed = 0 for SlowROM, 1 for FastROM
CCTablePm:
; SlowROM
db opcode_clocks(2, 0, 6, 0, 0) ; 00 BRK
db opcode_clocks(2, 1, 2, 1, 0) ; 01 ORA (d,x)
db opcode_clocks(2, 0, 6, 0, 0) ; 02 COP
db opcode_clocks(2, 1, 1, 0, 0) ; 03 ORA d,s
db opcode_clocks(2, 1, 2, 0, 0) ; 04 TSB d
db opcode_clocks(2, 0, 1, 0, 0) ; 05 ORA d
db opcode_clocks(2, 1, 2, 0, 0) ; 06 ASL d
db opcode_clocks(2, 0, 3, 1, 0) ; 07 ORA [d]
								
db opcode_clocks(1, 1, 1, 0, 0) ; 08 PHP
db opcode_clocks(2, 0, 0, 0, 0) ; 09 ORA i
db opcode_clocks(1, 1, 0, 0, 0) ; 0A SLA
db opcode_clocks(1, 1, 2, 0, 0) ; 0B PHD
db opcode_clocks(3, 1, 0, 2, 0) ; 0C TSB a
db opcode_clocks(3, 0, 0, 1, 0) ; 0D ORA a
db opcode_clocks(3, 1, 0, 2, 0) ; 0E ASL a
db opcode_clocks(4, 0, 0, 1, 0) ; 0F ORA al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 10 BPL r
db opcode_clocks(2, 1, 2, 1, 0) ; 11 ORA (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 12 ORA (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 13 ORA (d,s),y
db opcode_clocks(2, 1, 2, 0, 0) ; 14 TRB d
db opcode_clocks(2, 1, 1, 0, 0) ; 15 ORA d,x
db opcode_clocks(2, 2, 2, 0, 0) ; 16 ASL d,x
db opcode_clocks(2, 0, 3, 1, 0) ; 17 ORA [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 18 CLC
db opcode_clocks(3, 1, 0, 1, 0) ; 19 ORA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 1A INA
db opcode_clocks(1, 1, 0, 0, 0) ; 1B TCS
db opcode_clocks(3, 1, 0, 2, 0) ; 1C TRB a
db opcode_clocks(3, 1, 0, 1, 0) ; 1D ORA a,x
db opcode_clocks(3, 2, 0, 2, 0) ; 1E ASL a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 1F ORA al,x
								
db opcode_clocks(3, 1, 2, 0, 0) ; 20 JSR a
db opcode_clocks(2, 1, 2, 1, 0) ; 21 AND (d,x)
db opcode_clocks(4, 1, 3, 0, 0) ; 22 JSL al
db opcode_clocks(2, 1, 1, 0, 0) ; 23 AND d,s
db opcode_clocks(2, 0, 1, 0, 0) ; 24 BIT d
db opcode_clocks(2, 0, 1, 0, 0) ; 25 AND d
db opcode_clocks(2, 1, 2, 0, 0) ; 26 ROL d
db opcode_clocks(2, 0, 3, 1, 0) ; 27 AND [d]
								
db opcode_clocks(1, 2, 1, 0, 0) ; 28 PLP
db opcode_clocks(2, 0, 0, 0, 0) ; 29 AND i
db opcode_clocks(1, 1, 0, 0, 0) ; 2A RLA
db opcode_clocks(1, 2, 2, 0, 0) ; 2B PLD
db opcode_clocks(3, 0, 0, 1, 0) ; 2C BIT a
db opcode_clocks(3, 0, 0, 1, 0) ; 2D AND a
db opcode_clocks(3, 1, 0, 2, 0) ; 2E ROL a
db opcode_clocks(4, 0, 0, 1, 0) ; 2F AND al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 30 BMI r
db opcode_clocks(2, 1, 2, 1, 0) ; 31 AND (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 32 AND (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 33 AND (d,s),y
db opcode_clocks(2, 1, 1, 0, 0) ; 34 BIT d,x
db opcode_clocks(2, 1, 1, 0, 0) ; 35 AND d,x
db opcode_clocks(2, 2, 2, 0, 0) ; 36 ROL d,x
db opcode_clocks(2, 0, 3, 1, 0) ; 37 AND [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 38 SEC
db opcode_clocks(3, 1, 0, 1, 0) ; 39 AND a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 3A DEA
db opcode_clocks(1, 1, 0, 0, 0) ; 3B TSC
db opcode_clocks(3, 1, 0, 1, 0) ; 3C BIT a,x
db opcode_clocks(3, 1, 0, 1, 0) ; 3D AND a,x
db opcode_clocks(3, 2, 0, 2, 0) ; 3E ROL a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 3F AND al,x
								
db opcode_clocks(1, 2, 4, 0, 0) ; 40 RTI
db opcode_clocks(2, 1, 2, 1, 0) ; 41 EOR (d,x)
db opcode_clocks(2, 0, 0, 0, 0) ; 42 WDM *
db opcode_clocks(2, 1, 1, 0, 0) ; 43 EOR d,s
db opcode_clocks(3, 2, 0, 2, 0) ; 44 MVP
db opcode_clocks(2, 0, 1, 0, 0) ; 45 EOR d
db opcode_clocks(2, 1, 2, 0, 0) ; 46 LSR d
db opcode_clocks(2, 0, 3, 1, 0) ; 47 EOR [d]
								
db opcode_clocks(1, 1, 1, 0, 0) ; 48 PHA
db opcode_clocks(2, 0, 0, 0, 0) ; 49 EOR i
db opcode_clocks(1, 1, 0, 0, 0) ; 4A SRA
db opcode_clocks(1, 1, 1, 0, 0) ; 4B PHK
db opcode_clocks(3, 0, 0, 0, 0) ; 4C JMP a
db opcode_clocks(3, 0, 0, 1, 0) ; 4D EOR a
db opcode_clocks(3, 1, 0, 2, 0) ; 4E LSR a
db opcode_clocks(4, 0, 0, 1, 0) ; 4F EOR al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 50 BVC r
db opcode_clocks(2, 1, 2, 1, 0) ; 51 EOR (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 52 EOR (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 53 EOR (d,s),y
db opcode_clocks(3, 2, 0, 2, 0) ; 54 MVN
db opcode_clocks(2, 1, 1, 0, 0) ; 55 EOR d,x
db opcode_clocks(2, 2, 2, 0, 0) ; 56 LSR d,x
db opcode_clocks(2, 0, 3, 1, 0) ; 57 EOR [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 58 CLI
db opcode_clocks(3, 1, 0, 1, 0) ; 59 EOR a,y
db opcode_clocks(1, 1, 2, 0, 0) ; 5A PHY
db opcode_clocks(1, 1, 0, 0, 0) ; 5B TCD
db opcode_clocks(4, 0, 0, 0, 0) ; 5C JML al
db opcode_clocks(3, 1, 0, 1, 0) ; 5D EOR a,x
db opcode_clocks(3, 2, 0, 2, 0) ; 5E LSR a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 5F EOR al,x
								
db opcode_clocks(1, 3, 2, 0, 0) ; 60 RTS
db opcode_clocks(2, 1, 2, 1, 0) ; 61 ADC (d,x)
db opcode_clocks(3, 1, 2, 0, 0) ; 62 PER
db opcode_clocks(2, 1, 1, 0, 0) ; 63 ADC d,s
db opcode_clocks(2, 0, 1, 0, 0) ; 64 STZ d
db opcode_clocks(2, 0, 1, 0, 0) ; 65 ADC d
db opcode_clocks(2, 1, 2, 0, 0) ; 66 ROR d
db opcode_clocks(2, 0, 3, 1, 0) ; 67 ADC [d]
								
db opcode_clocks(1, 2, 1, 0, 0) ; 68 PLA
db opcode_clocks(2, 0, 0, 0, 0) ; 69 ADC i
db opcode_clocks(1, 1, 0, 0, 0) ; 6A RRA
db opcode_clocks(1, 2, 3, 0, 0) ; 6B RTL
db opcode_clocks(3, 0, 2, 0, 0) ; 6C JMP (a)
db opcode_clocks(3, 0, 0, 1, 0) ; 6D ADC a
db opcode_clocks(3, 1, 0, 2, 0) ; 6E ROR a
db opcode_clocks(4, 0, 0, 1, 0) ; 6F ADC al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 70 BVS r
db opcode_clocks(2, 1, 2, 1, 0) ; 71 ADC (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 72 ADC (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 73 ADC (d,s),y
db opcode_clocks(2, 1, 1, 0, 0) ; 74 STZ d,x
db opcode_clocks(2, 1, 1, 0, 0) ; 75 ADC d,x
db opcode_clocks(2, 2, 2, 0, 0) ; 76 ROR d,x
db opcode_clocks(2, 0, 3, 1, 0) ; 77 ADC [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 78 SEI
db opcode_clocks(3, 1, 0, 1, 0) ; 79 ADC a,y
db opcode_clocks(1, 2, 2, 0, 0) ; 7A PLY
db opcode_clocks(1, 1, 0, 0, 0) ; 7B TDC
db opcode_clocks(3, 1, 0, 2, 0) ; 7C JMP (a,x) - bus access in PB
db opcode_clocks(3, 1, 0, 1, 0) ; 7D ADC a,x
db opcode_clocks(3, 2, 0, 2, 0) ; 7E ROR a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 7F ADC al,x
								
db opcode_clocks(2, 0, 0, 0, 0) ; 80 BRA r
db opcode_clocks(2, 1, 2, 1, 0) ; 81 STA (d,x)
db opcode_clocks(3, 1, 0, 0, 0) ; 82 BRL rl
db opcode_clocks(2, 1, 1, 0, 0) ; 83 STA d,s
db opcode_clocks(2, 0, 2, 0, 0) ; 84 STY d
db opcode_clocks(2, 0, 1, 0, 0) ; 85 STA d
db opcode_clocks(2, 0, 2, 0, 0) ; 86 STX d
db opcode_clocks(2, 0, 3, 1, 0) ; 87 STA [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; 88 DEY
db opcode_clocks(2, 0, 0, 0, 0) ; 89 BIT i
db opcode_clocks(1, 1, 0, 0, 0) ; 8A TXA
db opcode_clocks(1, 1, 1, 0, 0) ; 8B PHB
db opcode_clocks(3, 0, 0, 2, 0) ; 8C STY a
db opcode_clocks(3, 0, 0, 1, 0) ; 8D STA a
db opcode_clocks(3, 0, 0, 2, 0) ; 8E STX a
db opcode_clocks(4, 0, 0, 1, 0) ; 8F STA al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 90 BCC r
db opcode_clocks(2, 1, 2, 1, 0) ; 91 STA (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 92 STA (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 93 STA (d,s),y
db opcode_clocks(2, 1, 2, 0, 0) ; 94 STY d,x
db opcode_clocks(2, 1, 1, 0, 0) ; 95 STA d,x
db opcode_clocks(2, 1, 2, 0, 0) ; 96 STX d,y
db opcode_clocks(2, 0, 3, 1, 0) ; 97 STA [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 98 TYA
db opcode_clocks(3, 1, 0, 1, 0) ; 99 STA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 9A TXS
db opcode_clocks(1, 1, 0, 0, 0) ; 9B TXY
db opcode_clocks(3, 0, 0, 1, 0) ; 9C STZ a
db opcode_clocks(3, 1, 0, 1, 0) ; 9D STA a,x
db opcode_clocks(3, 1, 0, 1, 0) ; 9E STZ a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 9F STA al,x
								
db opcode_clocks(3, 0, 0, 0, 0) ; A0 LDY i
db opcode_clocks(2, 1, 2, 1, 0) ; A1 LDA (d,x)
db opcode_clocks(3, 0, 0, 0, 0) ; A2 LDX i
db opcode_clocks(2, 1, 1, 0, 0) ; A3 LDA d,s
db opcode_clocks(2, 0, 2, 0, 0) ; A4 LDY d
db opcode_clocks(2, 0, 1, 0, 0) ; A5 LDA d
db opcode_clocks(2, 0, 2, 0, 0) ; A6 LDX d
db opcode_clocks(2, 0, 3, 1, 0) ; A7 LDA [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; A8 TAY
db opcode_clocks(2, 0, 0, 0, 0) ; A9 LDA i
db opcode_clocks(1, 1, 0, 0, 0) ; AA TAX
db opcode_clocks(1, 2, 1, 0, 0) ; AB PLB
db opcode_clocks(3, 0, 0, 2, 0) ; AC LDY a
db opcode_clocks(3, 0, 0, 1, 0) ; AD LDA a
db opcode_clocks(3, 0, 0, 2, 0) ; AE LDX a
db opcode_clocks(4, 0, 0, 1, 0) ; AF LDA al
								
db opcode_clocks(2, 0, 0, 0, 0) ; B0 BCS r
db opcode_clocks(2, 1, 2, 1, 0) ; B1 LDA (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; B2 LDA (d)
db opcode_clocks(2, 2, 2, 1, 0) ; B3 LDA (d,s),y
db opcode_clocks(2, 1, 2, 0, 0) ; B4 LDY d,x
db opcode_clocks(2, 1, 1, 0, 0) ; B5 LDA d,x
db opcode_clocks(2, 1, 2, 0, 0) ; B6 LDX d,y
db opcode_clocks(2, 0, 3, 1, 0) ; B7 LDA [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; B8 CLV
db opcode_clocks(3, 1, 0, 1, 0) ; B9 LDA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; BA TSX
db opcode_clocks(1, 1, 0, 0, 0) ; BB TYX
db opcode_clocks(3, 1, 0, 2, 0) ; BC LDY a,x
db opcode_clocks(3, 1, 0, 1, 0) ; BD LDA a,x
db opcode_clocks(3, 1, 0, 2, 0) ; BE LDX a,y
db opcode_clocks(4, 0, 0, 1, 0) ; BF LDA al,x
								
db opcode_clocks(3, 0, 0, 0, 0) ; C0 CPY i
db opcode_clocks(2, 1, 2, 1, 0) ; C1 CMP (d,x)
db opcode_clocks(2, 1, 0, 0, 0) ; C2 REP i
db opcode_clocks(2, 1, 1, 0, 0) ; C3 CMP d,s
db opcode_clocks(2, 0, 2, 0, 0) ; C4 CPY d
db opcode_clocks(2, 0, 1, 0, 0) ; C5 CMP d
db opcode_clocks(2, 1, 2, 0, 0) ; C6 DEC d
db opcode_clocks(2, 0, 3, 1, 0) ; C7 CMP [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; C8 INY
db opcode_clocks(2, 0, 0, 0, 0) ; C9 CMP i
db opcode_clocks(1, 1, 0, 0, 0) ; CA DEX
db opcode_clocks(1, 2, 0, 0, 0) ; CB WAI
db opcode_clocks(3, 0, 0, 2, 0) ; CC CPY a
db opcode_clocks(3, 0, 0, 1, 0) ; CD CMP a
db opcode_clocks(3, 1, 0, 2, 0) ; CE DEC a
db opcode_clocks(4, 0, 0, 1, 0) ; CF CMP al
								
db opcode_clocks(2, 0, 0, 0, 0) ; D0 BNE r
db opcode_clocks(2, 1, 2, 1, 0) ; D1 CMP (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; D2 CMP (d)
db opcode_clocks(2, 2, 2, 1, 0) ; D3 CMP (d,s),y
db opcode_clocks(2, 0, 4, 0, 0) ; D4 PEI
db opcode_clocks(2, 1, 1, 0, 0) ; D5 CMP d,x
db opcode_clocks(2, 2, 2, 0, 0) ; D6 DEC d,x
db opcode_clocks(2, 0, 3, 1, 0) ; D7 CMP [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; D8 CLD
db opcode_clocks(3, 1, 0, 1, 0) ; D9 CMP a,y
db opcode_clocks(1, 1, 2, 0, 0) ; DA PHX
db opcode_clocks(1, 2, 0, 0, 0) ; DB STP *
db opcode_clocks(3, 0, 3, 0, 0) ; DC JML (a)
db opcode_clocks(3, 1, 0, 1, 0) ; DD CMP a,x
db opcode_clocks(3, 2, 0, 2, 0) ; DE DEC a,x
db opcode_clocks(4, 0, 0, 1, 0) ; DF CMP al,x
								
db opcode_clocks(3, 0, 0, 0, 0) ; E0 CPX i
db opcode_clocks(2, 1, 2, 1, 0) ; E1 SBC (d,x)
db opcode_clocks(2, 1, 0, 0, 0) ; E2 SEP i
db opcode_clocks(2, 1, 1, 0, 0) ; E3 SBC d,s
db opcode_clocks(2, 0, 2, 0, 0) ; E4 CPX d
db opcode_clocks(2, 0, 1, 0, 0) ; E5 SBC d
db opcode_clocks(2, 1, 2, 0, 0) ; E6 INC d
db opcode_clocks(2, 0, 3, 1, 0) ; E7 SBC [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; E8 INX
db opcode_clocks(2, 0, 0, 0, 0) ; E9 SBC i
db opcode_clocks(1, 1, 0, 0, 0) ; EA NOP
db opcode_clocks(1, 2, 0, 0, 0) ; EB XBA
db opcode_clocks(3, 0, 0, 2, 0) ; EC CPX a
db opcode_clocks(3, 0, 0, 1, 0) ; ED SBC a
db opcode_clocks(3, 1, 0, 2, 0) ; EE INC a
db opcode_clocks(4, 0, 0, 1, 0) ; EF SBC al
								
db opcode_clocks(2, 0, 0, 0, 0) ; F0 BEQ r
db opcode_clocks(2, 1, 2, 1, 0) ; F1 SBC (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; F2 SBC (d)
db opcode_clocks(2, 2, 2, 1, 0) ; F3 SBC (d,s),y
db opcode_clocks(3, 0, 2, 0, 0) ; F4 PEA
db opcode_clocks(2, 1, 1, 0, 0) ; F5 SBC d,x
db opcode_clocks(2, 2, 2, 0, 0) ; F6 INC d,x
db opcode_clocks(2, 0, 3, 1, 0) ; F7 SBC [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; F8 SED
db opcode_clocks(3, 1, 0, 1, 0) ; F9 SBC a,y
db opcode_clocks(1, 2, 2, 0, 0) ; FA PLX
db opcode_clocks(1, 1, 0, 0, 0) ; FB XCE
db opcode_clocks(3, 1, 2, 2, 0) ; FC JSR (a,x) - bus access in PB
db opcode_clocks(3, 1, 0, 1, 0) ; FD SBC a,x
db opcode_clocks(3, 2, 0, 2, 0) ; FE INC a,x
db opcode_clocks(4, 0, 0, 1, 0) ; FF SBC al,x

; FastROM
db opcode_clocks(2, 0, 6, 0, 1) ; 00 BRK
db opcode_clocks(2, 1, 2, 1, 1) ; 01 ORA (d,x)
db opcode_clocks(2, 0, 6, 0, 1) ; 02 COP
db opcode_clocks(2, 1, 1, 0, 1) ; 03 ORA d,s
db opcode_clocks(2, 1, 2, 0, 1) ; 04 TSB d
db opcode_clocks(2, 0, 1, 0, 1) ; 05 ORA d
db opcode_clocks(2, 1, 2, 0, 1) ; 06 ASL d
db opcode_clocks(2, 0, 3, 1, 1) ; 07 ORA [d]
							
db opcode_clocks(1, 1, 1, 0, 1) ; 08 PHP
db opcode_clocks(2, 0, 0, 0, 1) ; 09 ORA i
db opcode_clocks(1, 1, 0, 0, 1) ; 0A SLA
db opcode_clocks(1, 1, 2, 0, 1) ; 0B PHD
db opcode_clocks(3, 1, 0, 2, 1) ; 0C TSB a
db opcode_clocks(3, 0, 0, 1, 1) ; 0D ORA a
db opcode_clocks(3, 1, 0, 2, 1) ; 0E ASL a
db opcode_clocks(4, 0, 0, 1, 1) ; 0F ORA al
							
db opcode_clocks(2, 0, 0, 0, 1) ; 10 BPL r
db opcode_clocks(2, 1, 2, 1, 1) ; 11 ORA (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 12 ORA (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 13 ORA (d,s),y
db opcode_clocks(2, 1, 2, 0, 1) ; 14 TRB d
db opcode_clocks(2, 1, 1, 0, 1) ; 15 ORA d,x
db opcode_clocks(2, 2, 2, 0, 1) ; 16 ASL d,x
db opcode_clocks(2, 0, 3, 1, 1) ; 17 ORA [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; 18 CLC
db opcode_clocks(3, 1, 0, 1, 1) ; 19 ORA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 1A INA
db opcode_clocks(1, 1, 0, 0, 1) ; 1B TCS
db opcode_clocks(3, 1, 0, 2, 1) ; 1C TRB a
db opcode_clocks(3, 1, 0, 1, 1) ; 1D ORA a,x
db opcode_clocks(3, 2, 0, 2, 1) ; 1E ASL a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 1F ORA al,x
							
db opcode_clocks(3, 1, 2, 0, 1) ; 20 JSR a
db opcode_clocks(2, 1, 2, 1, 1) ; 21 AND (d,x)
db opcode_clocks(4, 1, 3, 0, 1) ; 22 JSL al
db opcode_clocks(2, 1, 1, 0, 1) ; 23 AND d,s
db opcode_clocks(2, 0, 1, 0, 1) ; 24 BIT d
db opcode_clocks(2, 0, 1, 0, 1) ; 25 AND d
db opcode_clocks(2, 1, 2, 0, 1) ; 26 ROL d
db opcode_clocks(2, 0, 3, 1, 1) ; 27 AND [d]
							
db opcode_clocks(1, 2, 1, 0, 1) ; 28 PLP
db opcode_clocks(2, 0, 0, 0, 1) ; 29 AND i
db opcode_clocks(1, 1, 0, 0, 1) ; 2A RLA
db opcode_clocks(1, 2, 2, 0, 1) ; 2B PLD
db opcode_clocks(3, 0, 0, 1, 1) ; 2C BIT a
db opcode_clocks(3, 0, 0, 1, 1) ; 2D AND a
db opcode_clocks(3, 1, 0, 2, 1) ; 2E ROL a
db opcode_clocks(4, 0, 0, 1, 1) ; 2F AND al
							
db opcode_clocks(2, 0, 0, 0, 1) ; 30 BMI r
db opcode_clocks(2, 1, 2, 1, 1) ; 31 AND (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 32 AND (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 33 AND (d,s),y
db opcode_clocks(2, 1, 1, 0, 1) ; 34 BIT d,x
db opcode_clocks(2, 1, 1, 0, 1) ; 35 AND d,x
db opcode_clocks(2, 2, 2, 0, 1) ; 36 ROL d,x
db opcode_clocks(2, 0, 3, 1, 1) ; 37 AND [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; 38 SEC
db opcode_clocks(3, 1, 0, 1, 1) ; 39 AND a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 3A DEA
db opcode_clocks(1, 1, 0, 0, 1) ; 3B TSC
db opcode_clocks(3, 1, 0, 1, 1) ; 3C BIT a,x
db opcode_clocks(3, 1, 0, 1, 1) ; 3D AND a,x
db opcode_clocks(3, 2, 0, 2, 1) ; 3E ROL a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 3F AND al,x
							
db opcode_clocks(1, 2, 4, 0, 1) ; 40 RTI
db opcode_clocks(2, 1, 2, 1, 1) ; 41 EOR (d,x)
db opcode_clocks(2, 0, 0, 0, 1) ; 42 WDM *
db opcode_clocks(2, 1, 1, 0, 1) ; 43 EOR d,s
db opcode_clocks(3, 2, 0, 2, 1) ; 44 MVP
db opcode_clocks(2, 0, 1, 0, 1) ; 45 EOR d
db opcode_clocks(2, 1, 2, 0, 1) ; 46 LSR d
db opcode_clocks(2, 0, 3, 1, 1) ; 47 EOR [d]
							
db opcode_clocks(1, 1, 1, 0, 1) ; 48 PHA
db opcode_clocks(2, 0, 0, 0, 1) ; 49 EOR i
db opcode_clocks(1, 1, 0, 0, 1) ; 4A SRA
db opcode_clocks(1, 1, 1, 0, 1) ; 4B PHK
db opcode_clocks(3, 0, 0, 0, 1) ; 4C JMP a
db opcode_clocks(3, 0, 0, 1, 1) ; 4D EOR a
db opcode_clocks(3, 1, 0, 2, 1) ; 4E LSR a
db opcode_clocks(4, 0, 0, 1, 1) ; 4F EOR al
							
db opcode_clocks(2, 0, 0, 0, 1) ; 50 BVC r
db opcode_clocks(2, 1, 2, 1, 1) ; 51 EOR (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 52 EOR (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 53 EOR (d,s),y
db opcode_clocks(3, 2, 0, 2, 1) ; 54 MVN
db opcode_clocks(2, 1, 1, 0, 1) ; 55 EOR d,x
db opcode_clocks(2, 2, 2, 0, 1) ; 56 LSR d,x
db opcode_clocks(2, 0, 3, 1, 1) ; 57 EOR [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; 58 CLI
db opcode_clocks(3, 1, 0, 1, 1) ; 59 EOR a,y
db opcode_clocks(1, 1, 2, 0, 1) ; 5A PHY
db opcode_clocks(1, 1, 0, 0, 1) ; 5B TCD
db opcode_clocks(4, 0, 0, 0, 1) ; 5C JML al
db opcode_clocks(3, 1, 0, 1, 1) ; 5D EOR a,x
db opcode_clocks(3, 2, 0, 2, 1) ; 5E LSR a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 5F EOR al,x
							
db opcode_clocks(1, 3, 2, 0, 1) ; 60 RTS
db opcode_clocks(2, 1, 2, 1, 1) ; 61 ADC (d,x)
db opcode_clocks(3, 1, 2, 0, 1) ; 62 PER
db opcode_clocks(2, 1, 1, 0, 1) ; 63 ADC d,s
db opcode_clocks(2, 0, 1, 0, 1) ; 64 STZ d
db opcode_clocks(2, 0, 1, 0, 1) ; 65 ADC d
db opcode_clocks(2, 1, 2, 0, 1) ; 66 ROR d
db opcode_clocks(2, 0, 3, 1, 1) ; 67 ADC [d]
							
db opcode_clocks(1, 2, 1, 0, 1) ; 68 PLA
db opcode_clocks(2, 0, 0, 0, 1) ; 69 ADC i
db opcode_clocks(1, 1, 0, 0, 1) ; 6A RRA
db opcode_clocks(1, 2, 3, 0, 1) ; 6B RTL
db opcode_clocks(3, 0, 2, 0, 1) ; 6C JMP (a)
db opcode_clocks(3, 0, 0, 1, 1) ; 6D ADC a
db opcode_clocks(3, 1, 0, 2, 1) ; 6E ROR a
db opcode_clocks(4, 0, 0, 1, 1) ; 6F ADC al
							
db opcode_clocks(2, 0, 0, 0, 1) ; 70 BVS r
db opcode_clocks(2, 1, 2, 1, 1) ; 71 ADC (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 72 ADC (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 73 ADC (d,s),y
db opcode_clocks(2, 1, 1, 0, 1) ; 74 STZ d,x
db opcode_clocks(2, 1, 1, 0, 1) ; 75 ADC d,x
db opcode_clocks(2, 2, 2, 0, 1) ; 76 ROR d,x
db opcode_clocks(2, 0, 3, 1, 1) ; 77 ADC [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; 78 SEI
db opcode_clocks(3, 1, 0, 1, 1) ; 79 ADC a,y
db opcode_clocks(1, 2, 2, 0, 1) ; 7A PLY
db opcode_clocks(1, 1, 0, 0, 1) ; 7B TDC
db opcode_clocks(3, 1, 0, 2, 1) ; 7C JMP (a,x) - bus access in PB
db opcode_clocks(3, 1, 0, 1, 1) ; 7D ADC a,x
db opcode_clocks(3, 2, 0, 2, 1) ; 7E ROR a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 7F ADC al,x
							
db opcode_clocks(2, 0, 0, 0, 1) ; 80 BRA r
db opcode_clocks(2, 1, 2, 1, 1) ; 81 STA (d,x)
db opcode_clocks(3, 1, 0, 0, 1) ; 82 BRL rl
db opcode_clocks(2, 1, 1, 0, 1) ; 83 STA d,s
db opcode_clocks(2, 0, 2, 0, 1) ; 84 STY d
db opcode_clocks(2, 0, 1, 0, 1) ; 85 STA d
db opcode_clocks(2, 0, 2, 0, 1) ; 86 STX d
db opcode_clocks(2, 0, 3, 1, 1) ; 87 STA [d]
							
db opcode_clocks(1, 1, 0, 0, 1) ; 88 DEY
db opcode_clocks(2, 0, 0, 0, 1) ; 89 BIT i
db opcode_clocks(1, 1, 0, 0, 1) ; 8A TXA
db opcode_clocks(1, 1, 1, 0, 1) ; 8B PHB
db opcode_clocks(3, 0, 0, 2, 1) ; 8C STY a
db opcode_clocks(3, 0, 0, 1, 1) ; 8D STA a
db opcode_clocks(3, 0, 0, 2, 1) ; 8E STX a
db opcode_clocks(4, 0, 0, 1, 1) ; 8F STA al
							
db opcode_clocks(2, 0, 0, 0, 1) ; 90 BCC r
db opcode_clocks(2, 1, 2, 1, 1) ; 91 STA (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 92 STA (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 93 STA (d,s),y
db opcode_clocks(2, 1, 2, 0, 1) ; 94 STY d,x
db opcode_clocks(2, 1, 1, 0, 1) ; 95 STA d,x
db opcode_clocks(2, 1, 2, 0, 1) ; 96 STX d,y
db opcode_clocks(2, 0, 3, 1, 1) ; 97 STA [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; 98 TYA
db opcode_clocks(3, 1, 0, 1, 1) ; 99 STA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 9A TXS
db opcode_clocks(1, 1, 0, 0, 1) ; 9B TXY
db opcode_clocks(3, 0, 0, 1, 1) ; 9C STZ a
db opcode_clocks(3, 1, 0, 1, 1) ; 9D STA a,x
db opcode_clocks(3, 1, 0, 1, 1) ; 9E STZ a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 9F STA al,x
							
db opcode_clocks(3, 0, 0, 0, 1) ; A0 LDY i
db opcode_clocks(2, 1, 2, 1, 1) ; A1 LDA (d,x)
db opcode_clocks(3, 0, 0, 0, 1) ; A2 LDX i
db opcode_clocks(2, 1, 1, 0, 1) ; A3 LDA d,s
db opcode_clocks(2, 0, 2, 0, 1) ; A4 LDY d
db opcode_clocks(2, 0, 1, 0, 1) ; A5 LDA d
db opcode_clocks(2, 0, 2, 0, 1) ; A6 LDX d
db opcode_clocks(2, 0, 3, 1, 1) ; A7 LDA [d]
							
db opcode_clocks(1, 1, 0, 0, 1) ; A8 TAY
db opcode_clocks(2, 0, 0, 0, 1) ; A9 LDA i
db opcode_clocks(1, 1, 0, 0, 1) ; AA TAX
db opcode_clocks(1, 2, 1, 0, 1) ; AB PLB
db opcode_clocks(3, 0, 0, 2, 1) ; AC LDY a
db opcode_clocks(3, 0, 0, 1, 1) ; AD LDA a
db opcode_clocks(3, 0, 0, 2, 1) ; AE LDX a
db opcode_clocks(4, 0, 0, 1, 1) ; AF LDA al
							
db opcode_clocks(2, 0, 0, 0, 1) ; B0 BCS r
db opcode_clocks(2, 1, 2, 1, 1) ; B1 LDA (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; B2 LDA (d)
db opcode_clocks(2, 2, 2, 1, 1) ; B3 LDA (d,s),y
db opcode_clocks(2, 1, 2, 0, 1) ; B4 LDY d,x
db opcode_clocks(2, 1, 1, 0, 1) ; B5 LDA d,x
db opcode_clocks(2, 1, 2, 0, 1) ; B6 LDX d,y
db opcode_clocks(2, 0, 3, 1, 1) ; B7 LDA [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; B8 CLV
db opcode_clocks(3, 1, 0, 1, 1) ; B9 LDA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; BA TSX
db opcode_clocks(1, 1, 0, 0, 1) ; BB TYX
db opcode_clocks(3, 1, 0, 2, 1) ; BC LDY a,x
db opcode_clocks(3, 1, 0, 1, 1) ; BD LDA a,x
db opcode_clocks(3, 1, 0, 2, 1) ; BE LDX a,y
db opcode_clocks(4, 0, 0, 1, 1) ; BF LDA al,x
							
db opcode_clocks(3, 0, 0, 0, 1) ; C0 CPY i
db opcode_clocks(2, 1, 2, 1, 1) ; C1 CMP (d,x)
db opcode_clocks(2, 1, 0, 0, 1) ; C2 REP i
db opcode_clocks(2, 1, 1, 0, 1) ; C3 CMP d,s
db opcode_clocks(2, 0, 2, 0, 1) ; C4 CPY d
db opcode_clocks(2, 0, 1, 0, 1) ; C5 CMP d
db opcode_clocks(2, 1, 2, 0, 1) ; C6 DEC d
db opcode_clocks(2, 0, 3, 1, 1) ; C7 CMP [d]
							
db opcode_clocks(1, 1, 0, 0, 1) ; C8 INY
db opcode_clocks(2, 0, 0, 0, 1) ; C9 CMP i
db opcode_clocks(1, 1, 0, 0, 1) ; CA DEX
db opcode_clocks(1, 2, 0, 0, 1) ; CB WAI
db opcode_clocks(3, 0, 0, 2, 1) ; CC CPY a
db opcode_clocks(3, 0, 0, 1, 1) ; CD CMP a
db opcode_clocks(3, 1, 0, 2, 1) ; CE DEC a
db opcode_clocks(4, 0, 0, 1, 1) ; CF CMP al
							
db opcode_clocks(2, 0, 0, 0, 1) ; D0 BNE r
db opcode_clocks(2, 1, 2, 1, 1) ; D1 CMP (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; D2 CMP (d)
db opcode_clocks(2, 2, 2, 1, 1) ; D3 CMP (d,s),y
db opcode_clocks(2, 0, 4, 0, 1) ; D4 PEI
db opcode_clocks(2, 1, 1, 0, 1) ; D5 CMP d,x
db opcode_clocks(2, 2, 2, 0, 1) ; D6 DEC d,x
db opcode_clocks(2, 0, 3, 1, 1) ; D7 CMP [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; D8 CLD
db opcode_clocks(3, 1, 0, 1, 1) ; D9 CMP a,y
db opcode_clocks(1, 1, 2, 0, 1) ; DA PHX
db opcode_clocks(1, 2, 0, 0, 1) ; DB STP *
db opcode_clocks(3, 0, 3, 0, 1) ; DC JML (a)
db opcode_clocks(3, 1, 0, 1, 1) ; DD CMP a,x
db opcode_clocks(3, 2, 0, 2, 1) ; DE DEC a,x
db opcode_clocks(4, 0, 0, 1, 1) ; DF CMP al,x
							
db opcode_clocks(3, 0, 0, 0, 1) ; E0 CPX i
db opcode_clocks(2, 1, 2, 1, 1) ; E1 SBC (d,x)
db opcode_clocks(2, 1, 0, 0, 1) ; E2 SEP i
db opcode_clocks(2, 1, 1, 0, 1) ; E3 SBC d,s
db opcode_clocks(2, 0, 2, 0, 1) ; E4 CPX d
db opcode_clocks(2, 0, 1, 0, 1) ; E5 SBC d
db opcode_clocks(2, 1, 2, 0, 1) ; E6 INC d
db opcode_clocks(2, 0, 3, 1, 1) ; E7 SBC [d]
							
db opcode_clocks(1, 1, 0, 0, 1) ; E8 INX
db opcode_clocks(2, 0, 0, 0, 1) ; E9 SBC i
db opcode_clocks(1, 1, 0, 0, 1) ; EA NOP
db opcode_clocks(1, 2, 0, 0, 1) ; EB XBA
db opcode_clocks(3, 0, 0, 2, 1) ; EC CPX a
db opcode_clocks(3, 0, 0, 1, 1) ; ED SBC a
db opcode_clocks(3, 1, 0, 2, 1) ; EE INC a
db opcode_clocks(4, 0, 0, 1, 1) ; EF SBC al
							
db opcode_clocks(2, 0, 0, 0, 1) ; F0 BEQ r
db opcode_clocks(2, 1, 2, 1, 1) ; F1 SBC (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; F2 SBC (d)
db opcode_clocks(2, 2, 2, 1, 1) ; F3 SBC (d,s),y
db opcode_clocks(3, 0, 2, 0, 1) ; F4 PEA
db opcode_clocks(2, 1, 1, 0, 1) ; F5 SBC d,x
db opcode_clocks(2, 2, 2, 0, 1) ; F6 INC d,x
db opcode_clocks(2, 0, 3, 1, 1) ; F7 SBC [d],y
							
db opcode_clocks(1, 1, 0, 0, 1) ; F8 SED
db opcode_clocks(3, 1, 0, 1, 1) ; F9 SBC a,y
db opcode_clocks(1, 2, 2, 0, 1) ; FA PLX
db opcode_clocks(1, 1, 0, 0, 1) ; FB XCE
db opcode_clocks(3, 1, 2, 2, 1) ; FC JSR (a,x) - bus access in PB
db opcode_clocks(3, 1, 0, 1, 1) ; FD SBC a,x
db opcode_clocks(3, 2, 0, 2, 1) ; FE INC a,x
db opcode_clocks(4, 0, 0, 1, 1) ; FF SBC al,x

OpTablePx:
dd  C_LABEL(E0_BRK)       ,C_LABEL(E0_ORA_Od_xO)    ; 00
dd  C_LABEL(E0_COP)       ,C_LABEL(OpM0_0x03)
dd  C_LABEL(OpE0M0_0x04)  ,C_LABEL(E0_ORA_d)
dd  C_LABEL(OpE0M0_0x06)  ,C_LABEL(E0_ORA_IdI)
dd  C_LABEL(E0_PHP)       ,C_LABEL(OpM0_0x09)
dd  C_LABEL(OpM0_0x0A)    ,C_LABEL(E0_PHD)
dd  C_LABEL(OpM0_0x0C)    ,C_LABEL(OpM0_0x0D)
dd  C_LABEL(OpM0_0x0E)    ,C_LABEL(OpM0_0x0F)
dd  C_LABEL(ALL_BPL)      ,C_LABEL(OpE0M0X1_0x11)   ; 10
dd  C_LABEL(E0_ORA_OdO)   ,C_LABEL(OpM0_0x13)
dd  C_LABEL(OpE0M0_0x14)  ,C_LABEL(E0_ORA_d_x)
dd  C_LABEL(OpE0M0_0x16)  ,C_LABEL(E0_ORA_IdI_y)
dd  C_LABEL(ALL_CLC)      ,C_LABEL(E0_ORA_a_y)
dd  C_LABEL(OpM0_0x1A)    ,C_LABEL(E0_TCS)
dd  C_LABEL(OpM0_0x1C)    ,C_LABEL(E0_ORA_a_x)
dd  C_LABEL(OpM0_0x1E)    ,C_LABEL(E0_ORA_al_x)
dd  C_LABEL(E0_JSR_a)     ,C_LABEL(E0_AND_Od_xO)    ; 20
dd  C_LABEL(E0_JSL_al)    ,C_LABEL(OpM0_0x23)
dd  C_LABEL(E0_BIT_d)     ,C_LABEL(E0_AND_d)
dd  C_LABEL(OpE0M0_0x26)  ,C_LABEL(E0_AND_IdI)
dd  C_LABEL(E0_PLP)       ,C_LABEL(OpM0_0x29)
dd  C_LABEL(OpM0_0x2A)    ,C_LABEL(E0_PLD)
dd  C_LABEL(OpM0_0x2C)    ,C_LABEL(OpM0_0x2D)
dd  C_LABEL(OpM0_0x2E)    ,C_LABEL(OpM0_0x2F)
dd  C_LABEL(ALL_BMI)      ,C_LABEL(OpE0M0X1_0x31)   ; 30
dd  C_LABEL(E0_AND_OdO)   ,C_LABEL(OpM0_0x33)
dd  C_LABEL(E0_BIT_d_x)   ,C_LABEL(E0_AND_d_x)
dd  C_LABEL(OpE0M0_0x36)  ,C_LABEL(E0_AND_IdI_y)
dd  C_LABEL(ALL_SEC)      ,C_LABEL(E0_AND_a_y)
dd  C_LABEL(OpM0_0x3A)    ,C_LABEL(ALL_TSC)
dd  C_LABEL(E0_BIT_a_x)   ,C_LABEL(E0_AND_a_x)
dd  C_LABEL(OpM0_0x3E)    ,C_LABEL(E0_AND_al_x)
dd  C_LABEL(E0_RTI)       ,C_LABEL(E0_EOR_Od_xO)    ; 40
dd  C_LABEL(ALL_INVALID)  ,C_LABEL(OpM0_0x43)
dd  C_LABEL(EX_MVP)       ,C_LABEL(E0_EOR_d)
dd  C_LABEL(OpE0M0_0x46)  ,C_LABEL(E0_EOR_IdI)
dd  C_LABEL(E0_PHA)       ,C_LABEL(OpM0_0x49)
dd  C_LABEL(OpM0_0x4A)    ,C_LABEL(E0_PHK)
dd  C_LABEL(ALL_JMP_a)    ,C_LABEL(OpM0_0x4D)
dd  C_LABEL(OpM0_0x4E)    ,C_LABEL(OpM0_0x4F)
dd  C_LABEL(ALL_BVC)      ,C_LABEL(OpE0M0X1_0x51)   ; 50
dd  C_LABEL(E0_EOR_OdO)   ,C_LABEL(OpM0_0x53)
dd  C_LABEL(EX_MVN)       ,C_LABEL(E0_EOR_d_x)
dd  C_LABEL(OpE0M0_0x56)  ,C_LABEL(E0_EOR_IdI_y)
dd  C_LABEL(ALL_CLI)      ,C_LABEL(E0_EOR_a_y)
dd  C_LABEL(EX_PHY)       ,C_LABEL(ALL_TCD)
dd  C_LABEL(ALL_JML_al)   ,C_LABEL(E0_EOR_a_x)
dd  C_LABEL(OpM0_0x5E)    ,C_LABEL(E0_EOR_al_x)
dd  C_LABEL(E0_RTS)       ,C_LABEL(E0_ADC_Od_xO)    ; 60
dd  C_LABEL(E0_PER)       ,C_LABEL(OpM0_0x63)
dd  C_LABEL(OpE0M0_0x64)  ,C_LABEL(E0_ADC_d)
dd  C_LABEL(OpE0M0_0x66)  ,C_LABEL(E0_ADC_IdI)
dd  C_LABEL(E0_PLA)       ,C_LABEL(OpM0_0x69)
dd  C_LABEL(OpM0_0x6A)    ,C_LABEL(E0_RTL)
dd  C_LABEL(ALL_JMP_OaO)  ,C_LABEL(OpM0_0x6D)
dd  C_LABEL(OpM0_0x6E)    ,C_LABEL(OpM0_0x6F)
dd  C_LABEL(ALL_BVS)      ,C_LABEL(OpE0M0X1_0x71)   ; 70
dd  C_LABEL(E0_ADC_OdO)   ,C_LABEL(OpM0_0x73)
dd  C_LABEL(OpE0M0_0x74)  ,C_LABEL(E0_ADC_d_x)
dd  C_LABEL(OpE0M0_0x76)  ,C_LABEL(E0_ADC_IdI_y)
dd  C_LABEL(ALL_SEI)      ,C_LABEL(E0_ADC_a_y)
dd  C_LABEL(EX_PLY)       ,C_LABEL(ALL_TDC)
dd  C_LABEL(ALL_JMP_Oa_xO),C_LABEL(E0_ADC_a_x)
dd  C_LABEL(OpM0_0x7E)    ,C_LABEL(E0_ADC_al_x)
dd  C_LABEL(ALL_BRA)      ,C_LABEL(OpE0M0_0x81)     ; 80
dd  C_LABEL(ALL_BRL)      ,C_LABEL(OpM0_0x83)
dd  C_LABEL(OpE0X1_0x84)  ,C_LABEL(OpE0M0_0x85)
dd  C_LABEL(OpE0X1_0x86)  ,C_LABEL(OpE0M0_0x87)
dd  C_LABEL(OpX1_0x88)    ,C_LABEL(E0_BIT_i)
dd  C_LABEL(E0_TXA)       ,C_LABEL(E0_PHB)
dd  C_LABEL(OpX1_0x8C)    ,C_LABEL(OpM0_0x8D)
dd  C_LABEL(OpX1_0x8E)    ,C_LABEL(OpM0_0x8F)
dd  C_LABEL(ALL_BCC)      ,C_LABEL(OpE0M0X1_0x91)   ; 90
dd  C_LABEL(OpE0M0_0x92)  ,C_LABEL(OpM0_0x93)
dd  C_LABEL(OpE0X1_0x94)  ,C_LABEL(OpE0M0_0x95)
dd  C_LABEL(OpE0X1_0x96)  ,C_LABEL(OpE0M0_0x97)
dd  C_LABEL(E0_TYA)       ,C_LABEL(OpM0_0x99)
dd  C_LABEL(E0_TXS)       ,C_LABEL(EX_TXY)
dd  C_LABEL(OpM0_0x9C)    ,C_LABEL(OpM0_0x9D)
dd  C_LABEL(OpM0_0x9E)    ,C_LABEL(OpM0_0x9F)
dd  C_LABEL(OpX1_0xA0)    ,C_LABEL(E0_LDA_Od_xO)    ; A0
dd  C_LABEL(OpX1_0xA2)    ,C_LABEL(OpM0_0xA3)
dd  C_LABEL(EX_LDY_d)     ,C_LABEL(E0_LDA_d)
dd  C_LABEL(EX_LDX_d)     ,C_LABEL(E0_LDA_IdI)
dd  C_LABEL(EX_TAY)       ,C_LABEL(OpM0_0xA9)
dd  C_LABEL(EX_TAX)       ,C_LABEL(E0_PLB)
dd  C_LABEL(OpX1_0xAC)    ,C_LABEL(OpM0_0xAD)
dd  C_LABEL(OpX1_0xAE)    ,C_LABEL(OpM0_0xAF)
dd  C_LABEL(ALL_BCS)      ,C_LABEL(OpE0M0X1_0xB1)   ; B0
dd  C_LABEL(E0_LDA_OdO)   ,C_LABEL(OpM0_0xB3)
dd  C_LABEL(EX_LDY_d_x)   ,C_LABEL(E0_LDA_d_x)
dd  C_LABEL(EX_LDX_d_y)   ,C_LABEL(E0_LDA_IdI_y)
dd  C_LABEL(ALL_CLV)      ,C_LABEL(E0_LDA_a_y)
dd  C_LABEL(EX_TSX)       ,C_LABEL(EX_TYX)
dd  C_LABEL(EX_LDY_a_x)   ,C_LABEL(E0_LDA_a_x)
dd  C_LABEL(EX_LDX_a_y)   ,C_LABEL(E0_LDA_al_x)
dd  C_LABEL(OpX1_0xC0)    ,C_LABEL(E0_CMP_Od_xO)    ; C0
dd  C_LABEL(E0_REP)       ,C_LABEL(OpM0_0xC3)
dd  C_LABEL(EX_CPY_d)     ,C_LABEL(E0_CMP_d)
dd  C_LABEL(OpE0M0_0xC6)  ,C_LABEL(E0_CMP_IdI)
dd  C_LABEL(OpX1_0xC8)    ,C_LABEL(OpM0_0xC9)
dd  C_LABEL(OpX1_0xCA)    ,C_LABEL(ALL_WAI)
dd  C_LABEL(OpX1_0xCC)    ,C_LABEL(OpM0_0xCD)
dd  C_LABEL(OpM0_0xCE)    ,C_LABEL(OpM0_0xCF)
dd  C_LABEL(ALL_BNE)      ,C_LABEL(OpE0M0X1_0xD1)   ; D0
dd  C_LABEL(E0_CMP_OdO)   ,C_LABEL(OpM0_0xD3)
dd  C_LABEL(E0_PEI)       ,C_LABEL(E0_CMP_d_x)
dd  C_LABEL(OpE0M0_0xD6)  ,C_LABEL(E0_CMP_IdI_y)
dd  C_LABEL(ALL_CLD)      ,C_LABEL(E0_CMP_a_y)
dd  C_LABEL(EX_PHX)       ,C_LABEL(ALL_INVALID)
dd  C_LABEL(ALL_JML_OaO)  ,C_LABEL(E0_CMP_a_x)
dd  C_LABEL(OpM0_0xDE)    ,C_LABEL(E0_CMP_al_x)
dd  C_LABEL(OpX1_0xE0)    ,C_LABEL(E0_SBC_Od_xO)    ; E0
dd  C_LABEL(E0_SEP)       ,C_LABEL(OpM0_0xE3)
dd  C_LABEL(EX_CPX_d)     ,C_LABEL(E0_SBC_d)
dd  C_LABEL(OpE0M0_0xE6)  ,C_LABEL(E0_SBC_IdI)
dd  C_LABEL(OpX1_0xE8)    ,C_LABEL(OpM0_0xE9)
dd  C_LABEL(ALL_NOP)      ,C_LABEL(ALL_XBA)
dd  C_LABEL(OpX1_0xEC)    ,C_LABEL(OpM0_0xED)
dd  C_LABEL(OpM0_0xEE)    ,C_LABEL(OpM0_0xEF)
dd  C_LABEL(ALL_BEQ)      ,C_LABEL(OpE0M0X1_0xF1)   ; F0
dd  C_LABEL(E0_SBC_OdO)   ,C_LABEL(OpM0_0xF3)
dd  C_LABEL(E0_PEA)       ,C_LABEL(E0_SBC_d_x)
dd  C_LABEL(OpE0M0_0xF6)  ,C_LABEL(E0_SBC_IdI_y)
dd  C_LABEL(ALL_SED)      ,C_LABEL(E0_SBC_a_y)
dd  C_LABEL(EX_PLX)       ,C_LABEL(E0_XCE)
dd  C_LABEL(E0_JSR_Oa_xO) ,C_LABEL(E0_SBC_a_x)
dd  C_LABEL(OpM0_0xFE)    ,C_LABEL(E0_SBC_al_x)

; bytes, internal operations, bank 0 accesses, other bus accesses, speed
;  speed = 0 for SlowROM, 1 for FastROM
CCTablePx:
; SlowROM
db opcode_clocks(2, 0, 6, 0, 0) ; 00 BRK
db opcode_clocks(2, 1, 2, 2, 0) ; 01 ORA (d,x)
db opcode_clocks(2, 0, 6, 0, 0) ; 02 COP
db opcode_clocks(2, 1, 2, 0, 0) ; 03 ORA d,s
db opcode_clocks(2, 1, 4, 0, 0) ; 04 TSB d
db opcode_clocks(2, 0, 2, 0, 0) ; 05 ORA d
db opcode_clocks(2, 1, 4, 0, 0) ; 06 ASL d
db opcode_clocks(2, 0, 3, 2, 0) ; 07 ORA [d]
								
db opcode_clocks(1, 1, 1, 0, 0) ; 08 PHP
db opcode_clocks(3, 0, 0, 0, 0) ; 09 ORA i
db opcode_clocks(1, 1, 0, 0, 0) ; 0A SLA
db opcode_clocks(1, 1, 2, 0, 0) ; 0B PHD
db opcode_clocks(3, 1, 0, 4, 0) ; 0C TSB a
db opcode_clocks(3, 0, 0, 2, 0) ; 0D ORA a
db opcode_clocks(3, 1, 0, 4, 0) ; 0E ASL a
db opcode_clocks(4, 0, 0, 2, 0) ; 0F ORA al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 10 BPL r
db opcode_clocks(2, 0, 2, 2, 0) ; 11 ORA (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; 12 ORA (d)
db opcode_clocks(2, 2, 2, 2, 0) ; 13 ORA (d,s),y
db opcode_clocks(2, 1, 4, 0, 0) ; 14 TRB d
db opcode_clocks(2, 1, 2, 0, 0) ; 15 ORA d,x
db opcode_clocks(2, 2, 4, 0, 0) ; 16 ASL d,x
db opcode_clocks(2, 0, 3, 2, 0) ; 17 ORA [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 18 CLC
db opcode_clocks(3, 0, 0, 2, 0) ; 19 ORA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 1A INA
db opcode_clocks(1, 1, 0, 0, 0) ; 1B TCS
db opcode_clocks(3, 1, 0, 4, 0) ; 1C TRB a
db opcode_clocks(3, 0, 0, 2, 0) ; 1D ORA a,x
db opcode_clocks(3, 2, 0, 4, 0) ; 1E ASL a,x
db opcode_clocks(4, 0, 0, 2, 0) ; 1F ORA al,x
								
db opcode_clocks(3, 1, 2, 0, 0) ; 20 JSR a
db opcode_clocks(2, 1, 2, 2, 0) ; 21 AND (d,x)
db opcode_clocks(4, 1, 3, 0, 0) ; 22 JSL al
db opcode_clocks(2, 1, 2, 0, 0) ; 23 AND d,s
db opcode_clocks(2, 0, 2, 0, 0) ; 24 BIT d
db opcode_clocks(2, 0, 2, 0, 0) ; 25 AND d
db opcode_clocks(2, 1, 4, 0, 0) ; 26 ROL d
db opcode_clocks(2, 0, 3, 2, 0) ; 27 AND [d]
								
db opcode_clocks(1, 2, 1, 0, 0) ; 28 PLP
db opcode_clocks(3, 0, 0, 0, 0) ; 29 AND i
db opcode_clocks(1, 1, 0, 0, 0) ; 2A RLA
db opcode_clocks(1, 2, 2, 0, 0) ; 2B PLD
db opcode_clocks(3, 0, 0, 2, 0) ; 2C BIT a
db opcode_clocks(3, 0, 0, 2, 0) ; 2D AND a
db opcode_clocks(3, 1, 0, 4, 0) ; 2E ROL a
db opcode_clocks(4, 0, 0, 2, 0) ; 2F AND al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 30 BMI r
db opcode_clocks(2, 0, 2, 2, 0) ; 31 AND (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; 32 AND (d)
db opcode_clocks(2, 2, 2, 2, 0) ; 33 AND (d,s),y
db opcode_clocks(2, 1, 2, 0, 0) ; 34 BIT d,x
db opcode_clocks(2, 1, 2, 0, 0) ; 35 AND d,x
db opcode_clocks(2, 2, 4, 0, 0) ; 36 ROL d,x
db opcode_clocks(2, 0, 3, 2, 0) ; 37 AND [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 38 SEC
db opcode_clocks(3, 0, 0, 2, 0) ; 39 AND a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 3A DEA
db opcode_clocks(1, 1, 0, 0, 0) ; 3B TSC
db opcode_clocks(3, 0, 0, 2, 0) ; 3C BIT a,x
db opcode_clocks(3, 0, 0, 2, 0) ; 3D AND a,x
db opcode_clocks(3, 2, 0, 4, 0) ; 3E ROL a,x
db opcode_clocks(4, 0, 0, 2, 0) ; 3F AND al,x
								
db opcode_clocks(1, 2, 4, 0, 0) ; 40 RTI
db opcode_clocks(2, 1, 2, 2, 0) ; 41 EOR (d,x)
db opcode_clocks(2, 0, 0, 0, 0) ; 42 WDM *
db opcode_clocks(2, 1, 2, 0, 0) ; 43 EOR d,s
db opcode_clocks(3, 2, 0, 2, 0) ; 44 MVP
db opcode_clocks(2, 0, 2, 0, 0) ; 45 EOR d
db opcode_clocks(2, 1, 4, 0, 0) ; 46 LSR d
db opcode_clocks(2, 0, 3, 2, 0) ; 47 EOR [d]
								
db opcode_clocks(1, 1, 2, 0, 0) ; 48 PHA
db opcode_clocks(3, 0, 0, 0, 0) ; 49 EOR i
db opcode_clocks(1, 1, 0, 0, 0) ; 4A SRA
db opcode_clocks(1, 1, 1, 0, 0) ; 4B PHK
db opcode_clocks(3, 0, 0, 0, 0) ; 4C JMP a
db opcode_clocks(3, 0, 0, 2, 0) ; 4D EOR a
db opcode_clocks(3, 1, 0, 4, 0) ; 4E LSR a
db opcode_clocks(4, 0, 0, 2, 0) ; 4F EOR al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 50 BVC r
db opcode_clocks(2, 0, 2, 2, 0) ; 51 EOR (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; 52 EOR (d)
db opcode_clocks(2, 2, 2, 2, 0) ; 53 EOR (d,s),y
db opcode_clocks(3, 2, 0, 2, 0) ; 54 MVN
db opcode_clocks(2, 1, 2, 0, 0) ; 55 EOR d,x
db opcode_clocks(2, 2, 4, 0, 0) ; 56 LSR d,x
db opcode_clocks(2, 0, 3, 2, 0) ; 57 EOR [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 58 CLI
db opcode_clocks(3, 0, 0, 2, 0) ; 59 EOR a,y
db opcode_clocks(1, 1, 1, 0, 0) ; 5A PHY
db opcode_clocks(1, 1, 0, 0, 0) ; 5B TCD
db opcode_clocks(4, 0, 0, 0, 0) ; 5C JML al
db opcode_clocks(3, 0, 0, 2, 0) ; 5D EOR a,x
db opcode_clocks(3, 2, 0, 4, 0) ; 5E LSR a,x
db opcode_clocks(4, 0, 0, 2, 0) ; 5F EOR al,x
								
db opcode_clocks(1, 3, 2, 0, 0) ; 60 RTS
db opcode_clocks(2, 1, 2, 2, 0) ; 61 ADC (d,x)
db opcode_clocks(3, 1, 2, 0, 0) ; 62 PER
db opcode_clocks(2, 1, 2, 0, 0) ; 63 ADC d,s
db opcode_clocks(2, 0, 2, 0, 0) ; 64 STZ d
db opcode_clocks(2, 0, 2, 0, 0) ; 65 ADC d
db opcode_clocks(2, 1, 4, 0, 0) ; 66 ROR d
db opcode_clocks(2, 0, 3, 2, 0) ; 67 ADC [d]
								
db opcode_clocks(1, 2, 2, 0, 0) ; 68 PLA
db opcode_clocks(3, 0, 0, 0, 0) ; 69 ADC i
db opcode_clocks(1, 1, 0, 0, 0) ; 6A RRA
db opcode_clocks(1, 2, 3, 0, 0) ; 6B RTL
db opcode_clocks(3, 0, 2, 0, 0) ; 6C JMP (a)
db opcode_clocks(3, 0, 0, 2, 0) ; 6D ADC a
db opcode_clocks(3, 1, 0, 4, 0) ; 6E ROR a
db opcode_clocks(4, 0, 0, 2, 0) ; 6F ADC al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 70 BVS r
db opcode_clocks(2, 0, 2, 2, 0) ; 71 ADC (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; 72 ADC (d)
db opcode_clocks(2, 2, 2, 2, 0) ; 73 ADC (d,s),y
db opcode_clocks(2, 1, 2, 0, 0) ; 74 STZ d,x
db opcode_clocks(2, 1, 2, 0, 0) ; 75 ADC d,x
db opcode_clocks(2, 2, 4, 0, 0) ; 76 ROR d,x
db opcode_clocks(2, 0, 3, 2, 0) ; 77 ADC [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 78 SEI
db opcode_clocks(3, 0, 0, 2, 0) ; 79 ADC a,y
db opcode_clocks(1, 2, 1, 0, 0) ; 7A PLY
db opcode_clocks(1, 1, 0, 0, 0) ; 7B TDC
db opcode_clocks(3, 1, 0, 2, 0) ; 7C JMP (a,x) - bus access in PB
db opcode_clocks(3, 0, 0, 2, 0) ; 7D ADC a,x
db opcode_clocks(3, 2, 0, 4, 0) ; 7E ROR a,x
db opcode_clocks(4, 0, 0, 2, 0) ; 7F ADC al,x
								
db opcode_clocks(2, 0, 0, 0, 0) ; 80 BRA r
db opcode_clocks(2, 1, 2, 2, 0) ; 81 STA (d,x)
db opcode_clocks(3, 1, 0, 0, 0) ; 82 BRL rl
db opcode_clocks(2, 1, 2, 0, 0) ; 83 STA d,s
db opcode_clocks(2, 0, 1, 0, 0) ; 84 STY d
db opcode_clocks(2, 0, 2, 0, 0) ; 85 STA d
db opcode_clocks(2, 0, 1, 0, 0) ; 86 STX d
db opcode_clocks(2, 0, 3, 2, 0) ; 87 STA [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; 88 DEY
db opcode_clocks(3, 0, 0, 0, 0) ; 89 BIT i
db opcode_clocks(1, 1, 0, 0, 0) ; 8A TXA
db opcode_clocks(1, 1, 1, 0, 0) ; 8B PHB
db opcode_clocks(3, 0, 0, 1, 0) ; 8C STY a
db opcode_clocks(3, 0, 0, 2, 0) ; 8D STA a
db opcode_clocks(3, 0, 0, 1, 0) ; 8E STX a
db opcode_clocks(4, 0, 0, 2, 0) ; 8F STA al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 90 BCC r
db opcode_clocks(2, 1, 2, 2, 0) ; 91 STA (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; 92 STA (d)
db opcode_clocks(2, 2, 2, 2, 0) ; 93 STA (d,s),y
db opcode_clocks(2, 1, 1, 0, 0) ; 94 STY d,x
db opcode_clocks(2, 1, 2, 0, 0) ; 95 STA d,x
db opcode_clocks(2, 1, 1, 0, 0) ; 96 STX d,y
db opcode_clocks(2, 0, 3, 2, 0) ; 97 STA [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 98 TYA
db opcode_clocks(3, 1, 0, 2, 0) ; 99 STA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 9A TXS
db opcode_clocks(1, 1, 0, 0, 0) ; 9B TXY
db opcode_clocks(3, 0, 0, 2, 0) ; 9C STZ a
db opcode_clocks(3, 1, 0, 2, 0) ; 9D STA a,x
db opcode_clocks(3, 1, 0, 2, 0) ; 9E STZ a,x
db opcode_clocks(4, 0, 0, 2, 0) ; 9F STA al,x
								
db opcode_clocks(2, 0, 0, 0, 0) ; A0 LDY i
db opcode_clocks(2, 1, 2, 2, 0) ; A1 LDA (d,x)
db opcode_clocks(2, 0, 0, 0, 0) ; A2 LDX i
db opcode_clocks(2, 1, 2, 0, 0) ; A3 LDA d,s
db opcode_clocks(2, 0, 1, 0, 0) ; A4 LDY d
db opcode_clocks(2, 0, 2, 0, 0) ; A5 LDA d
db opcode_clocks(2, 0, 1, 0, 0) ; A6 LDX d
db opcode_clocks(2, 0, 3, 2, 0) ; A7 LDA [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; A8 TAY
db opcode_clocks(3, 0, 0, 0, 0) ; A9 LDA i
db opcode_clocks(1, 1, 0, 0, 0) ; AA TAX
db opcode_clocks(1, 2, 1, 0, 0) ; AB PLB
db opcode_clocks(3, 0, 0, 1, 0) ; AC LDY a
db opcode_clocks(3, 0, 0, 2, 0) ; AD LDA a
db opcode_clocks(3, 0, 0, 1, 0) ; AE LDX a
db opcode_clocks(4, 0, 0, 2, 0) ; AF LDA al
								
db opcode_clocks(2, 0, 0, 0, 0) ; B0 BCS r
db opcode_clocks(2, 0, 2, 2, 0) ; B1 LDA (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; B2 LDA (d)
db opcode_clocks(2, 2, 2, 2, 0) ; B3 LDA (d,s),y
db opcode_clocks(2, 1, 1, 0, 0) ; B4 LDY d,x
db opcode_clocks(2, 1, 2, 0, 0) ; B5 LDA d,x
db opcode_clocks(2, 1, 1, 0, 0) ; B6 LDX d,y
db opcode_clocks(2, 0, 3, 2, 0) ; B7 LDA [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; B8 CLV
db opcode_clocks(3, 0, 0, 2, 0) ; B9 LDA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; BA TSX
db opcode_clocks(1, 1, 0, 0, 0) ; BB TYX
db opcode_clocks(3, 0, 0, 1, 0) ; BC LDY a,x
db opcode_clocks(3, 0, 0, 2, 0) ; BD LDA a,x
db opcode_clocks(3, 0, 0, 1, 0) ; BE LDX a,y
db opcode_clocks(4, 0, 0, 2, 0) ; BF LDA al,x
								
db opcode_clocks(2, 0, 0, 0, 0) ; C0 CPY i
db opcode_clocks(2, 1, 2, 2, 0) ; C1 CMP (d,x)
db opcode_clocks(2, 1, 0, 0, 0) ; C2 REP i
db opcode_clocks(2, 1, 2, 0, 0) ; C3 CMP d,s
db opcode_clocks(2, 0, 1, 0, 0) ; C4 CPY d
db opcode_clocks(2, 0, 2, 0, 0) ; C5 CMP d
db opcode_clocks(2, 1, 4, 0, 0) ; C6 DEC d
db opcode_clocks(2, 0, 3, 2, 0) ; C7 CMP [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; C8 INY
db opcode_clocks(3, 0, 0, 0, 0) ; C9 CMP i
db opcode_clocks(1, 1, 0, 0, 0) ; CA DEX
db opcode_clocks(1, 2, 0, 0, 0) ; CB WAI
db opcode_clocks(3, 0, 0, 1, 0) ; CC CPY a
db opcode_clocks(3, 0, 0, 2, 0) ; CD CMP a
db opcode_clocks(3, 1, 0, 4, 0) ; CE DEC a
db opcode_clocks(4, 0, 0, 2, 0) ; CF CMP al
								
db opcode_clocks(2, 0, 0, 0, 0) ; D0 BNE r
db opcode_clocks(2, 0, 2, 2, 0) ; D1 CMP (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; D2 CMP (d)
db opcode_clocks(2, 2, 2, 2, 0) ; D3 CMP (d,s),y
db opcode_clocks(2, 0, 4, 0, 0) ; D4 PEI
db opcode_clocks(2, 1, 2, 0, 0) ; D5 CMP d,x
db opcode_clocks(2, 2, 4, 0, 0) ; D6 DEC d,x
db opcode_clocks(2, 0, 3, 2, 0) ; D7 CMP [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; D8 CLD
db opcode_clocks(3, 0, 0, 2, 0) ; D9 CMP a,y
db opcode_clocks(1, 1, 1, 0, 0) ; DA PHX
db opcode_clocks(1, 2, 0, 0, 0) ; DB STP *
db opcode_clocks(3, 0, 3, 0, 0) ; DC JML (a)
db opcode_clocks(3, 0, 0, 2, 0) ; DD CMP a,x
db opcode_clocks(3, 2, 0, 4, 0) ; DE DEC a,x
db opcode_clocks(4, 0, 0, 2, 0) ; DF CMP al,x
								
db opcode_clocks(2, 0, 0, 0, 0) ; E0 CPX i
db opcode_clocks(2, 1, 2, 2, 0) ; E1 SBC (d,x)
db opcode_clocks(2, 1, 0, 0, 0) ; E2 SEP i
db opcode_clocks(2, 1, 2, 0, 0) ; E3 SBC d,s
db opcode_clocks(2, 0, 1, 0, 0) ; E4 CPX d
db opcode_clocks(2, 0, 2, 0, 0) ; E5 SBC d
db opcode_clocks(2, 1, 4, 0, 0) ; E6 INC d
db opcode_clocks(2, 0, 3, 2, 0) ; E7 SBC [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; E8 INX
db opcode_clocks(3, 0, 0, 0, 0) ; E9 SBC i
db opcode_clocks(1, 1, 0, 0, 0) ; EA NOP
db opcode_clocks(1, 2, 0, 0, 0) ; EB XBA
db opcode_clocks(3, 0, 0, 1, 0) ; EC CPX a
db opcode_clocks(3, 0, 0, 2, 0) ; ED SBC a
db opcode_clocks(3, 1, 0, 4, 0) ; EE INC a
db opcode_clocks(4, 0, 0, 2, 0) ; EF SBC al
								
db opcode_clocks(2, 0, 0, 0, 0) ; F0 BEQ r
db opcode_clocks(2, 0, 2, 2, 0) ; F1 SBC (d),y
db opcode_clocks(2, 0, 2, 2, 0) ; F2 SBC (d)
db opcode_clocks(2, 2, 2, 2, 0) ; F3 SBC (d,s),y
db opcode_clocks(3, 0, 2, 0, 0) ; F4 PEA
db opcode_clocks(2, 1, 2, 0, 0) ; F5 SBC d,x
db opcode_clocks(2, 2, 4, 0, 0) ; F6 INC d,x
db opcode_clocks(2, 0, 3, 2, 0) ; F7 SBC [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; F8 SED
db opcode_clocks(3, 0, 0, 2, 0) ; F9 SBC a,y
db opcode_clocks(1, 2, 1, 0, 0) ; FA PLX
db opcode_clocks(1, 1, 0, 0, 0) ; FB XCE
db opcode_clocks(3, 1, 2, 2, 0) ; FC JSR (a,x) - bus access in PB
db opcode_clocks(3, 0, 0, 2, 0) ; FD SBC a,x
db opcode_clocks(3, 2, 0, 4, 0) ; FE INC a,x
db opcode_clocks(4, 0, 0, 2, 0) ; FF SBC al,x

; FastROM
db opcode_clocks(2, 0, 6, 0, 1) ; 00 BRK
db opcode_clocks(2, 1, 2, 2, 1) ; 01 ORA (d,x)
db opcode_clocks(2, 0, 6, 0, 1) ; 02 COP
db opcode_clocks(2, 1, 2, 0, 1) ; 03 ORA d,s
db opcode_clocks(2, 1, 4, 0, 1) ; 04 TSB d
db opcode_clocks(2, 0, 2, 0, 1) ; 05 ORA d
db opcode_clocks(2, 1, 4, 0, 1) ; 06 ASL d
db opcode_clocks(2, 0, 3, 2, 1) ; 07 ORA [d]
								
db opcode_clocks(1, 1, 1, 0, 1) ; 08 PHP
db opcode_clocks(3, 0, 0, 0, 1) ; 09 ORA i
db opcode_clocks(1, 1, 0, 0, 1) ; 0A SLA
db opcode_clocks(1, 1, 2, 0, 1) ; 0B PHD
db opcode_clocks(3, 1, 0, 4, 1) ; 0C TSB a
db opcode_clocks(3, 0, 0, 2, 1) ; 0D ORA a
db opcode_clocks(3, 1, 0, 4, 1) ; 0E ASL a
db opcode_clocks(4, 0, 0, 2, 1) ; 0F ORA al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 10 BPL r
db opcode_clocks(2, 0, 2, 2, 1) ; 11 ORA (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; 12 ORA (d)
db opcode_clocks(2, 2, 2, 2, 1) ; 13 ORA (d,s),y
db opcode_clocks(2, 1, 4, 0, 1) ; 14 TRB d
db opcode_clocks(2, 1, 2, 0, 1) ; 15 ORA d,x
db opcode_clocks(2, 2, 4, 0, 1) ; 16 ASL d,x
db opcode_clocks(2, 0, 3, 2, 1) ; 17 ORA [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 18 CLC
db opcode_clocks(3, 0, 0, 2, 1) ; 19 ORA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 1A INA
db opcode_clocks(1, 1, 0, 0, 1) ; 1B TCS
db opcode_clocks(3, 1, 0, 4, 1) ; 1C TRB a
db opcode_clocks(3, 0, 0, 2, 1) ; 1D ORA a,x
db opcode_clocks(3, 2, 0, 4, 1) ; 1E ASL a,x
db opcode_clocks(4, 0, 0, 2, 1) ; 1F ORA al,x
								
db opcode_clocks(3, 1, 2, 0, 1) ; 20 JSR a
db opcode_clocks(2, 1, 2, 2, 1) ; 21 AND (d,x)
db opcode_clocks(4, 1, 3, 0, 1) ; 22 JSL al
db opcode_clocks(2, 1, 2, 0, 1) ; 23 AND d,s
db opcode_clocks(2, 0, 2, 0, 1) ; 24 BIT d
db opcode_clocks(2, 0, 2, 0, 1) ; 25 AND d
db opcode_clocks(2, 1, 4, 0, 1) ; 26 ROL d
db opcode_clocks(2, 0, 3, 2, 1) ; 27 AND [d]
								
db opcode_clocks(1, 2, 1, 0, 1) ; 28 PLP
db opcode_clocks(3, 0, 0, 0, 1) ; 29 AND i
db opcode_clocks(1, 1, 0, 0, 1) ; 2A RLA
db opcode_clocks(1, 2, 2, 0, 1) ; 2B PLD
db opcode_clocks(3, 0, 0, 2, 1) ; 2C BIT a
db opcode_clocks(3, 0, 0, 2, 1) ; 2D AND a
db opcode_clocks(3, 1, 0, 4, 1) ; 2E ROL a
db opcode_clocks(4, 0, 0, 2, 1) ; 2F AND al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 30 BMI r
db opcode_clocks(2, 0, 2, 2, 1) ; 31 AND (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; 32 AND (d)
db opcode_clocks(2, 2, 2, 2, 1) ; 33 AND (d,s),y
db opcode_clocks(2, 1, 2, 0, 1) ; 34 BIT d,x
db opcode_clocks(2, 1, 2, 0, 1) ; 35 AND d,x
db opcode_clocks(2, 2, 4, 0, 1) ; 36 ROL d,x
db opcode_clocks(2, 0, 3, 2, 1) ; 37 AND [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 38 SEC
db opcode_clocks(3, 0, 0, 2, 1) ; 39 AND a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 3A DEA
db opcode_clocks(1, 1, 0, 0, 1) ; 3B TSC
db opcode_clocks(3, 0, 0, 2, 1) ; 3C BIT a,x
db opcode_clocks(3, 0, 0, 2, 1) ; 3D AND a,x
db opcode_clocks(3, 2, 0, 4, 1) ; 3E ROL a,x
db opcode_clocks(4, 0, 0, 2, 1) ; 3F AND al,x
								
db opcode_clocks(1, 2, 4, 0, 1) ; 40 RTI
db opcode_clocks(2, 1, 2, 2, 1) ; 41 EOR (d,x)
db opcode_clocks(2, 0, 0, 0, 1) ; 42 WDM *
db opcode_clocks(2, 1, 2, 0, 1) ; 43 EOR d,s
db opcode_clocks(3, 2, 0, 2, 1) ; 44 MVP
db opcode_clocks(2, 0, 2, 0, 1) ; 45 EOR d
db opcode_clocks(2, 1, 4, 0, 1) ; 46 LSR d
db opcode_clocks(2, 0, 3, 2, 1) ; 47 EOR [d]
								
db opcode_clocks(1, 1, 2, 0, 1) ; 48 PHA
db opcode_clocks(3, 0, 0, 0, 1) ; 49 EOR i
db opcode_clocks(1, 1, 0, 0, 1) ; 4A SRA
db opcode_clocks(1, 1, 1, 0, 1) ; 4B PHK
db opcode_clocks(3, 0, 0, 0, 1) ; 4C JMP a
db opcode_clocks(3, 0, 0, 2, 1) ; 4D EOR a
db opcode_clocks(3, 1, 0, 4, 1) ; 4E LSR a
db opcode_clocks(4, 0, 0, 2, 1) ; 4F EOR al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 50 BVC r
db opcode_clocks(2, 0, 2, 2, 1) ; 51 EOR (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; 52 EOR (d)
db opcode_clocks(2, 2, 2, 2, 1) ; 53 EOR (d,s),y
db opcode_clocks(3, 2, 0, 2, 1) ; 54 MVN
db opcode_clocks(2, 1, 2, 0, 1) ; 55 EOR d,x
db opcode_clocks(2, 2, 4, 0, 1) ; 56 LSR d,x
db opcode_clocks(2, 0, 3, 2, 1) ; 57 EOR [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 58 CLI
db opcode_clocks(3, 0, 0, 2, 1) ; 59 EOR a,y
db opcode_clocks(1, 1, 1, 0, 1) ; 5A PHY
db opcode_clocks(1, 1, 0, 0, 1) ; 5B TCD
db opcode_clocks(4, 0, 0, 0, 1) ; 5C JML al
db opcode_clocks(3, 0, 0, 2, 1) ; 5D EOR a,x
db opcode_clocks(3, 2, 0, 4, 1) ; 5E LSR a,x
db opcode_clocks(4, 0, 0, 2, 1) ; 5F EOR al,x
								
db opcode_clocks(1, 3, 2, 0, 1) ; 60 RTS
db opcode_clocks(2, 1, 2, 2, 1) ; 61 ADC (d,x)
db opcode_clocks(3, 1, 2, 0, 1) ; 62 PER
db opcode_clocks(2, 1, 2, 0, 1) ; 63 ADC d,s
db opcode_clocks(2, 0, 2, 0, 1) ; 64 STZ d
db opcode_clocks(2, 0, 2, 0, 1) ; 65 ADC d
db opcode_clocks(2, 1, 4, 0, 1) ; 66 ROR d
db opcode_clocks(2, 0, 3, 2, 1) ; 67 ADC [d]
								
db opcode_clocks(1, 2, 2, 0, 1) ; 68 PLA
db opcode_clocks(3, 0, 0, 0, 1) ; 69 ADC i
db opcode_clocks(1, 1, 0, 0, 1) ; 6A RRA
db opcode_clocks(1, 2, 3, 0, 1) ; 6B RTL
db opcode_clocks(3, 0, 2, 0, 1) ; 6C JMP (a)
db opcode_clocks(3, 0, 0, 2, 1) ; 6D ADC a
db opcode_clocks(3, 1, 0, 4, 1) ; 6E ROR a
db opcode_clocks(4, 0, 0, 2, 1) ; 6F ADC al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 70 BVS r
db opcode_clocks(2, 0, 2, 2, 1) ; 71 ADC (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; 72 ADC (d)
db opcode_clocks(2, 2, 2, 2, 1) ; 73 ADC (d,s),y
db opcode_clocks(2, 1, 2, 0, 1) ; 74 STZ d,x
db opcode_clocks(2, 1, 2, 0, 1) ; 75 ADC d,x
db opcode_clocks(2, 2, 4, 0, 1) ; 76 ROR d,x
db opcode_clocks(2, 0, 3, 2, 1) ; 77 ADC [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 78 SEI
db opcode_clocks(3, 0, 0, 2, 1) ; 79 ADC a,y
db opcode_clocks(1, 2, 1, 0, 1) ; 7A PLY
db opcode_clocks(1, 1, 0, 0, 1) ; 7B TDC
db opcode_clocks(3, 1, 0, 2, 1) ; 7C JMP (a,x) - bus access in PB
db opcode_clocks(3, 0, 0, 2, 1) ; 7D ADC a,x
db opcode_clocks(3, 2, 0, 4, 1) ; 7E ROR a,x
db opcode_clocks(4, 0, 0, 2, 1) ; 7F ADC al,x
								
db opcode_clocks(2, 0, 0, 0, 1) ; 80 BRA r
db opcode_clocks(2, 1, 2, 2, 1) ; 81 STA (d,x)
db opcode_clocks(3, 1, 0, 0, 1) ; 82 BRL rl
db opcode_clocks(2, 1, 2, 0, 1) ; 83 STA d,s
db opcode_clocks(2, 0, 1, 0, 1) ; 84 STY d
db opcode_clocks(2, 0, 2, 0, 1) ; 85 STA d
db opcode_clocks(2, 0, 1, 0, 1) ; 86 STX d
db opcode_clocks(2, 0, 3, 2, 1) ; 87 STA [d]
								
db opcode_clocks(1, 1, 0, 0, 1) ; 88 DEY
db opcode_clocks(3, 0, 0, 0, 1) ; 89 BIT i
db opcode_clocks(1, 1, 0, 0, 1) ; 8A TXA
db opcode_clocks(1, 1, 1, 0, 1) ; 8B PHB
db opcode_clocks(3, 0, 0, 1, 1) ; 8C STY a
db opcode_clocks(3, 0, 0, 2, 1) ; 8D STA a
db opcode_clocks(3, 0, 0, 1, 1) ; 8E STX a
db opcode_clocks(4, 0, 0, 2, 1) ; 8F STA al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 90 BCC r
db opcode_clocks(2, 1, 2, 2, 1) ; 91 STA (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; 92 STA (d)
db opcode_clocks(2, 2, 2, 2, 1) ; 93 STA (d,s),y
db opcode_clocks(2, 1, 1, 0, 1) ; 94 STY d,x
db opcode_clocks(2, 1, 2, 0, 1) ; 95 STA d,x
db opcode_clocks(2, 1, 1, 0, 1) ; 96 STX d,y
db opcode_clocks(2, 0, 3, 2, 1) ; 97 STA [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 98 TYA
db opcode_clocks(3, 1, 0, 2, 1) ; 99 STA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 9A TXS
db opcode_clocks(1, 1, 0, 0, 1) ; 9B TXY
db opcode_clocks(3, 0, 0, 2, 1) ; 9C STZ a
db opcode_clocks(3, 1, 0, 2, 1) ; 9D STA a,x
db opcode_clocks(3, 1, 0, 2, 1) ; 9E STZ a,x
db opcode_clocks(4, 0, 0, 2, 1) ; 9F STA al,x
								
db opcode_clocks(2, 0, 0, 0, 1) ; A0 LDY i
db opcode_clocks(2, 1, 2, 2, 1) ; A1 LDA (d,x)
db opcode_clocks(2, 0, 0, 0, 1) ; A2 LDX i
db opcode_clocks(2, 1, 2, 0, 1) ; A3 LDA d,s
db opcode_clocks(2, 0, 1, 0, 1) ; A4 LDY d
db opcode_clocks(2, 0, 2, 0, 1) ; A5 LDA d
db opcode_clocks(2, 0, 1, 0, 1) ; A6 LDX d
db opcode_clocks(2, 0, 3, 2, 1) ; A7 LDA [d]
								
db opcode_clocks(1, 1, 0, 0, 1) ; A8 TAY
db opcode_clocks(3, 0, 0, 0, 1) ; A9 LDA i
db opcode_clocks(1, 1, 0, 0, 1) ; AA TAX
db opcode_clocks(1, 2, 1, 0, 1) ; AB PLB
db opcode_clocks(3, 0, 0, 1, 1) ; AC LDY a
db opcode_clocks(3, 0, 0, 2, 1) ; AD LDA a
db opcode_clocks(3, 0, 0, 1, 1) ; AE LDX a
db opcode_clocks(4, 0, 0, 2, 1) ; AF LDA al
								
db opcode_clocks(2, 0, 0, 0, 1) ; B0 BCS r
db opcode_clocks(2, 0, 2, 2, 1) ; B1 LDA (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; B2 LDA (d)
db opcode_clocks(2, 2, 2, 2, 1) ; B3 LDA (d,s),y
db opcode_clocks(2, 1, 1, 0, 1) ; B4 LDY d,x
db opcode_clocks(2, 1, 2, 0, 1) ; B5 LDA d,x
db opcode_clocks(2, 1, 1, 0, 1) ; B6 LDX d,y
db opcode_clocks(2, 0, 3, 2, 1) ; B7 LDA [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; B8 CLV
db opcode_clocks(3, 0, 0, 2, 1) ; B9 LDA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; BA TSX
db opcode_clocks(1, 1, 0, 0, 1) ; BB TYX
db opcode_clocks(3, 0, 0, 1, 1) ; BC LDY a,x
db opcode_clocks(3, 0, 0, 2, 1) ; BD LDA a,x
db opcode_clocks(3, 0, 0, 1, 1) ; BE LDX a,y
db opcode_clocks(4, 0, 0, 2, 1) ; BF LDA al,x
								
db opcode_clocks(2, 0, 0, 0, 1) ; C0 CPY i
db opcode_clocks(2, 1, 2, 2, 1) ; C1 CMP (d,x)
db opcode_clocks(2, 1, 0, 0, 1) ; C2 REP i
db opcode_clocks(2, 1, 2, 0, 1) ; C3 CMP d,s
db opcode_clocks(2, 0, 1, 0, 1) ; C4 CPY d
db opcode_clocks(2, 0, 2, 0, 1) ; C5 CMP d
db opcode_clocks(2, 1, 4, 0, 1) ; C6 DEC d
db opcode_clocks(2, 0, 3, 2, 1) ; C7 CMP [d]
								
db opcode_clocks(1, 1, 0, 0, 1) ; C8 INY
db opcode_clocks(3, 0, 0, 0, 1) ; C9 CMP i
db opcode_clocks(1, 1, 0, 0, 1) ; CA DEX
db opcode_clocks(1, 2, 0, 0, 1) ; CB WAI
db opcode_clocks(3, 0, 0, 1, 1) ; CC CPY a
db opcode_clocks(3, 0, 0, 2, 1) ; CD CMP a
db opcode_clocks(3, 1, 0, 4, 1) ; CE DEC a
db opcode_clocks(4, 0, 0, 2, 1) ; CF CMP al
								
db opcode_clocks(2, 0, 0, 0, 1) ; D0 BNE r
db opcode_clocks(2, 0, 2, 2, 1) ; D1 CMP (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; D2 CMP (d)
db opcode_clocks(2, 2, 2, 2, 1) ; D3 CMP (d,s),y
db opcode_clocks(2, 0, 4, 0, 1) ; D4 PEI
db opcode_clocks(2, 1, 2, 0, 1) ; D5 CMP d,x
db opcode_clocks(2, 2, 4, 0, 1) ; D6 DEC d,x
db opcode_clocks(2, 0, 3, 2, 1) ; D7 CMP [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; D8 CLD
db opcode_clocks(3, 0, 0, 2, 1) ; D9 CMP a,y
db opcode_clocks(1, 1, 1, 0, 1) ; DA PHX
db opcode_clocks(1, 2, 0, 0, 1) ; DB STP *
db opcode_clocks(3, 0, 3, 0, 1) ; DC JML (a)
db opcode_clocks(3, 0, 0, 2, 1) ; DD CMP a,x
db opcode_clocks(3, 2, 0, 4, 1) ; DE DEC a,x
db opcode_clocks(4, 0, 0, 2, 1) ; DF CMP al,x
								
db opcode_clocks(2, 0, 0, 0, 1) ; E0 CPX i
db opcode_clocks(2, 1, 2, 2, 1) ; E1 SBC (d,x)
db opcode_clocks(2, 1, 0, 0, 1) ; E2 SEP i
db opcode_clocks(2, 1, 2, 0, 1) ; E3 SBC d,s
db opcode_clocks(2, 0, 1, 0, 1) ; E4 CPX d
db opcode_clocks(2, 0, 2, 0, 1) ; E5 SBC d
db opcode_clocks(2, 1, 4, 0, 1) ; E6 INC d
db opcode_clocks(2, 0, 3, 2, 1) ; E7 SBC [d]
								
db opcode_clocks(1, 1, 0, 0, 1) ; E8 INX
db opcode_clocks(3, 0, 0, 0, 1) ; E9 SBC i
db opcode_clocks(1, 1, 0, 0, 1) ; EA NOP
db opcode_clocks(1, 2, 0, 0, 1) ; EB XBA
db opcode_clocks(3, 0, 0, 1, 1) ; EC CPX a
db opcode_clocks(3, 0, 0, 2, 1) ; ED SBC a
db opcode_clocks(3, 1, 0, 4, 1) ; EE INC a
db opcode_clocks(4, 0, 0, 2, 1) ; EF SBC al
								
db opcode_clocks(2, 0, 0, 0, 1) ; F0 BEQ r
db opcode_clocks(2, 0, 2, 2, 1) ; F1 SBC (d),y
db opcode_clocks(2, 0, 2, 2, 1) ; F2 SBC (d)
db opcode_clocks(2, 2, 2, 2, 1) ; F3 SBC (d,s),y
db opcode_clocks(3, 0, 2, 0, 1) ; F4 PEA
db opcode_clocks(2, 1, 2, 0, 1) ; F5 SBC d,x
db opcode_clocks(2, 2, 4, 0, 1) ; F6 INC d,x
db opcode_clocks(2, 0, 3, 2, 1) ; F7 SBC [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; F8 SED
db opcode_clocks(3, 0, 0, 2, 1) ; F9 SBC a,y
db opcode_clocks(1, 2, 1, 0, 1) ; FA PLX
db opcode_clocks(1, 1, 0, 0, 1) ; FB XCE
db opcode_clocks(3, 1, 2, 2, 1) ; FC JSR (a,x) - bus access in PB
db opcode_clocks(3, 0, 0, 2, 1) ; FD SBC a,x
db opcode_clocks(3, 2, 0, 4, 1) ; FE INC a,x
db opcode_clocks(4, 0, 0, 2, 1) ; FF SBC al,x

OpTableMX:
dd  C_LABEL(E0_BRK)       ,C_LABEL(EM_ORA_Od_xO)    ; 00
dd  C_LABEL(E0_COP)       ,C_LABEL(OpM1_0x03)
dd  C_LABEL(OpE0M1_0x04)  ,C_LABEL(EM_ORA_d)
dd  C_LABEL(OpE0M1_0x06)  ,C_LABEL(EM_ORA_IdI)
dd  C_LABEL(E0_PHP)       ,C_LABEL(OpM1_0x09)
dd  C_LABEL(OpM1_0x0A)    ,C_LABEL(E0_PHD)
dd  C_LABEL(OpM1_0x0C)    ,C_LABEL(OpM1_0x0D)
dd  C_LABEL(OpM1_0x0E)    ,C_LABEL(OpM1_0x0F)
dd  C_LABEL(ALL_BPL)      ,C_LABEL(OpE0M1X1_0x11)   ; 10
dd  C_LABEL(EM_ORA_OdO)   ,C_LABEL(OpM1_0x13)
dd  C_LABEL(OpE0M1_0x14)  ,C_LABEL(EM_ORA_d_x)
dd  C_LABEL(OpE0M1_0x16)  ,C_LABEL(EM_ORA_IdI_y)
dd  C_LABEL(ALL_CLC)      ,C_LABEL(EM_ORA_a_y)
dd  C_LABEL(OpM1_0x1A)    ,C_LABEL(E0_TCS)
dd  C_LABEL(OpM1_0x1C)    ,C_LABEL(EM_ORA_a_x)
dd  C_LABEL(OpM1_0x1E)    ,C_LABEL(EM_ORA_al_x)
dd  C_LABEL(E0_JSR_a)     ,C_LABEL(EM_AND_Od_xO)    ; 20
dd  C_LABEL(E0_JSL_al)    ,C_LABEL(OpM1_0x23)
dd  C_LABEL(EM_BIT_d)     ,C_LABEL(EM_AND_d)
dd  C_LABEL(OpE0M1_0x26)  ,C_LABEL(EM_AND_IdI)
dd  C_LABEL(E0_PLP)       ,C_LABEL(OpM1_0x29)
dd  C_LABEL(OpM1_0x2A)    ,C_LABEL(E0_PLD)
dd  C_LABEL(OpM1_0x2C)    ,C_LABEL(OpM1_0x2D)
dd  C_LABEL(OpM1_0x2E)    ,C_LABEL(OpM1_0x2F)
dd  C_LABEL(ALL_BMI)      ,C_LABEL(OpE0M1X1_0x31)   ; 30
dd  C_LABEL(EM_AND_OdO)   ,C_LABEL(OpM1_0x33)
dd  C_LABEL(EM_BIT_d_x)   ,C_LABEL(EM_AND_d_x)
dd  C_LABEL(OpE0M1_0x36)  ,C_LABEL(EM_AND_IdI_y)
dd  C_LABEL(ALL_SEC)      ,C_LABEL(EM_AND_a_y)
dd  C_LABEL(OpM1_0x3A)    ,C_LABEL(ALL_TSC)
dd  C_LABEL(EM_BIT_a_x)   ,C_LABEL(EM_AND_a_x)
dd  C_LABEL(OpM1_0x3E)    ,C_LABEL(EM_AND_al_x)
dd  C_LABEL(E0_RTI)       ,C_LABEL(EM_EOR_Od_xO)    ; 40
dd  C_LABEL(ALL_INVALID)  ,C_LABEL(OpM1_0x43)
dd  C_LABEL(EX_MVP)       ,C_LABEL(EM_EOR_d)
dd  C_LABEL(OpE0M1_0x46)  ,C_LABEL(EM_EOR_IdI)
dd  C_LABEL(EM_PHA)       ,C_LABEL(OpM1_0x49)
dd  C_LABEL(OpM1_0x4A)    ,C_LABEL(E0_PHK)
dd  C_LABEL(ALL_JMP_a)    ,C_LABEL(OpM1_0x4D)
dd  C_LABEL(OpM1_0x4E)    ,C_LABEL(OpM1_0x4F)
dd  C_LABEL(ALL_BVC)      ,C_LABEL(OpE0M1X1_0x51)   ; 50
dd  C_LABEL(EM_EOR_OdO)   ,C_LABEL(OpM1_0x53)
dd  C_LABEL(EX_MVN)       ,C_LABEL(EM_EOR_d_x)
dd  C_LABEL(OpE0M1_0x56)  ,C_LABEL(EM_EOR_IdI_y)
dd  C_LABEL(ALL_CLI)      ,C_LABEL(EM_EOR_a_y)
dd  C_LABEL(EX_PHY)       ,C_LABEL(ALL_TCD)
dd  C_LABEL(ALL_JML_al)   ,C_LABEL(EM_EOR_a_x)
dd  C_LABEL(OpM1_0x5E)    ,C_LABEL(EM_EOR_al_x)
dd  C_LABEL(E0_RTS)       ,C_LABEL(EM_ADC_Od_xO)    ; 60
dd  C_LABEL(E0_PER)       ,C_LABEL(OpM1_0x63)
dd  C_LABEL(OpE0M1_0x64)  ,C_LABEL(EM_ADC_d)
dd  C_LABEL(OpE0M1_0x66)  ,C_LABEL(EM_ADC_IdI)
dd  C_LABEL(EM_PLA)       ,C_LABEL(OpM1_0x69)
dd  C_LABEL(OpM1_0x6A)    ,C_LABEL(E0_RTL)
dd  C_LABEL(ALL_JMP_OaO)  ,C_LABEL(OpM1_0x6D)
dd  C_LABEL(OpM1_0x6E)    ,C_LABEL(OpM1_0x6F)
dd  C_LABEL(ALL_BVS)      ,C_LABEL(OpE0M1X1_0x71)   ; 70
dd  C_LABEL(EM_ADC_OdO)   ,C_LABEL(OpM1_0x73)
dd  C_LABEL(OpE0M1_0x74)  ,C_LABEL(EM_ADC_d_x)
dd  C_LABEL(OpE0M1_0x76)  ,C_LABEL(EM_ADC_IdI_y)
dd  C_LABEL(ALL_SEI)      ,C_LABEL(EM_ADC_a_y)
dd  C_LABEL(EX_PLY)       ,C_LABEL(ALL_TDC)
dd  C_LABEL(ALL_JMP_Oa_xO),C_LABEL(EM_ADC_a_x)
dd  C_LABEL(OpM1_0x7E)    ,C_LABEL(EM_ADC_al_x)
dd  C_LABEL(ALL_BRA)      ,C_LABEL(OpE0M1_0x81)     ; 80
dd  C_LABEL(ALL_BRL)      ,C_LABEL(OpM1_0x83)
dd  C_LABEL(OpE0X1_0x84)  ,C_LABEL(OpE0M1_0x85)
dd  C_LABEL(OpE0X1_0x86)  ,C_LABEL(OpE0M1_0x87)
dd  C_LABEL(OpX1_0x88)    ,C_LABEL(EM_BIT_i)
dd  C_LABEL(EM_TXA)       ,C_LABEL(E0_PHB)
dd  C_LABEL(OpX1_0x8C)    ,C_LABEL(OpM1_0x8D)
dd  C_LABEL(OpX1_0x8E)    ,C_LABEL(OpM1_0x8F)
dd  C_LABEL(ALL_BCC)      ,C_LABEL(OpE0M1X1_0x91)   ; 90
dd  C_LABEL(OpE0M1_0x92)  ,C_LABEL(OpM1_0x93)
dd  C_LABEL(OpE0X1_0x94)  ,C_LABEL(OpE0M1_0x95)
dd  C_LABEL(OpE0X1_0x96)  ,C_LABEL(OpE0M1_0x97)
dd  C_LABEL(EM_TYA)       ,C_LABEL(OpM1_0x99)
dd  C_LABEL(E0_TXS)       ,C_LABEL(EX_TXY)
dd  C_LABEL(OpM1_0x9C)    ,C_LABEL(OpM1_0x9D)
dd  C_LABEL(OpM1_0x9E)    ,C_LABEL(OpM1_0x9F)
dd  C_LABEL(OpX1_0xA0)    ,C_LABEL(EM_LDA_Od_xO)    ; A0
dd  C_LABEL(OpX1_0xA2)    ,C_LABEL(OpM1_0xA3)
dd  C_LABEL(EX_LDY_d)     ,C_LABEL(EM_LDA_d)
dd  C_LABEL(EX_LDX_d)     ,C_LABEL(EM_LDA_IdI)
dd  C_LABEL(EX_TAY)       ,C_LABEL(OpM1_0xA9)
dd  C_LABEL(EX_TAX)       ,C_LABEL(E0_PLB)
dd  C_LABEL(OpX1_0xAC)    ,C_LABEL(OpM1_0xAD)
dd  C_LABEL(OpX1_0xAE)    ,C_LABEL(OpM1_0xAF)
dd  C_LABEL(ALL_BCS)      ,C_LABEL(OpE0M1X1_0xB1)   ; B0
dd  C_LABEL(EM_LDA_OdO)   ,C_LABEL(OpM1_0xB3)
dd  C_LABEL(EX_LDY_d_x)   ,C_LABEL(EM_LDA_d_x)
dd  C_LABEL(EX_LDX_d_y)   ,C_LABEL(EM_LDA_IdI_y)
dd  C_LABEL(ALL_CLV)      ,C_LABEL(EM_LDA_a_y)
dd  C_LABEL(EX_TSX)       ,C_LABEL(EX_TYX)
dd  C_LABEL(EX_LDY_a_x)   ,C_LABEL(EM_LDA_a_x)
dd  C_LABEL(EX_LDX_a_y)   ,C_LABEL(EM_LDA_al_x)
dd  C_LABEL(OpX1_0xC0)    ,C_LABEL(EM_CMP_Od_xO)    ; C0
dd  C_LABEL(E0_REP)       ,C_LABEL(OpM1_0xC3)
dd  C_LABEL(EX_CPY_d)     ,C_LABEL(EM_CMP_d)
dd  C_LABEL(OpE0M1_0xC6)  ,C_LABEL(EM_CMP_IdI)
dd  C_LABEL(OpX1_0xC8)    ,C_LABEL(OpM1_0xC9)
dd  C_LABEL(OpX1_0xCA)    ,C_LABEL(ALL_WAI)
dd  C_LABEL(OpX1_0xCC)    ,C_LABEL(OpM1_0xCD)
dd  C_LABEL(OpM1_0xCE)    ,C_LABEL(OpM1_0xCF)
dd  C_LABEL(ALL_BNE)      ,C_LABEL(OpE0M1X1_0xD1)   ; D0
dd  C_LABEL(EM_CMP_OdO)   ,C_LABEL(OpM1_0xD3)
dd  C_LABEL(E0_PEI)       ,C_LABEL(EM_CMP_d_x)
dd  C_LABEL(OpE0M1_0xD6)  ,C_LABEL(EM_CMP_IdI_y)
dd  C_LABEL(ALL_CLD)      ,C_LABEL(EM_CMP_a_y)
dd  C_LABEL(EX_PHX)       ,C_LABEL(ALL_INVALID)
dd  C_LABEL(ALL_JML_OaO)  ,C_LABEL(EM_CMP_a_x)
dd  C_LABEL(OpM1_0xDE)    ,C_LABEL(EM_CMP_al_x)
dd  C_LABEL(OpX1_0xE0)    ,C_LABEL(EM_SBC_Od_xO)    ; E0
dd  C_LABEL(E0_SEP)       ,C_LABEL(OpM1_0xE3)
dd  C_LABEL(EX_CPX_d)     ,C_LABEL(EM_SBC_d)
dd  C_LABEL(OpE0M1_0xE6)  ,C_LABEL(EM_SBC_IdI)
dd  C_LABEL(OpX1_0xE8)    ,C_LABEL(OpM1_0xE9)
dd  C_LABEL(ALL_NOP)      ,C_LABEL(ALL_XBA)
dd  C_LABEL(OpX1_0xEC)    ,C_LABEL(OpM1_0xED)
dd  C_LABEL(OpM1_0xEE)    ,C_LABEL(OpM1_0xEF)
dd  C_LABEL(ALL_BEQ)      ,C_LABEL(OpE0M1X1_0xF1)   ; F0
dd  C_LABEL(EM_SBC_OdO)   ,C_LABEL(OpM1_0xF3)
dd  C_LABEL(E0_PEA)       ,C_LABEL(EM_SBC_d_x)
dd  C_LABEL(OpE0M1_0xF6)  ,C_LABEL(EM_SBC_IdI_y)
dd  C_LABEL(ALL_SED)      ,C_LABEL(EM_SBC_a_y)
dd  C_LABEL(EX_PLX)       ,C_LABEL(E0_XCE)
dd  C_LABEL(E0_JSR_Oa_xO) ,C_LABEL(EM_SBC_a_x)
dd  C_LABEL(OpM1_0xFE)    ,C_LABEL(EM_SBC_al_x)

; bytes, internal operations, bank 0 accesses, other bus accesses, speed
;  speed = 0 for SlowROM, 1 for FastROM
CCTableMX:
; SlowROM
db opcode_clocks(2, 0, 6, 0, 0) ; 00 BRK
db opcode_clocks(2, 1, 2, 1, 0) ; 01 ORA (d,x)
db opcode_clocks(2, 0, 6, 0, 0) ; 02 COP
db opcode_clocks(2, 1, 1, 0, 0) ; 03 ORA d,s
db opcode_clocks(2, 1, 2, 0, 0) ; 04 TSB d
db opcode_clocks(2, 0, 1, 0, 0) ; 05 ORA d
db opcode_clocks(2, 1, 2, 0, 0) ; 06 ASL d
db opcode_clocks(2, 0, 3, 1, 0) ; 07 ORA [d]
								
db opcode_clocks(1, 1, 1, 0, 0) ; 08 PHP
db opcode_clocks(2, 0, 0, 0, 0) ; 09 ORA i
db opcode_clocks(1, 1, 0, 0, 0) ; 0A SLA
db opcode_clocks(1, 1, 2, 0, 0) ; 0B PHD
db opcode_clocks(3, 1, 0, 2, 0) ; 0C TSB a
db opcode_clocks(3, 0, 0, 1, 0) ; 0D ORA a
db opcode_clocks(3, 1, 0, 2, 0) ; 0E ASL a
db opcode_clocks(4, 0, 0, 1, 0) ; 0F ORA al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 10 BPL r
db opcode_clocks(2, 0, 2, 1, 0) ; 11 ORA (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 12 ORA (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 13 ORA (d,s),y
db opcode_clocks(2, 1, 2, 0, 0) ; 14 TRB d
db opcode_clocks(2, 1, 1, 0, 0) ; 15 ORA d,x
db opcode_clocks(2, 2, 2, 0, 0) ; 16 ASL d,x
db opcode_clocks(2, 0, 3, 1, 0) ; 17 ORA [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 18 CLC
db opcode_clocks(3, 0, 0, 1, 0) ; 19 ORA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 1A INA
db opcode_clocks(1, 1, 0, 0, 0) ; 1B TCS
db opcode_clocks(3, 1, 0, 2, 0) ; 1C TRB a
db opcode_clocks(3, 0, 0, 1, 0) ; 1D ORA a,x
db opcode_clocks(3, 2, 0, 2, 0) ; 1E ASL a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 1F ORA al,x
								
db opcode_clocks(3, 1, 2, 0, 0) ; 20 JSR a
db opcode_clocks(2, 1, 2, 1, 0) ; 21 AND (d,x)
db opcode_clocks(4, 1, 3, 0, 0) ; 22 JSL al
db opcode_clocks(2, 1, 1, 0, 0) ; 23 AND d,s
db opcode_clocks(2, 0, 1, 0, 0) ; 24 BIT d
db opcode_clocks(2, 0, 1, 0, 0) ; 25 AND d
db opcode_clocks(2, 1, 2, 0, 0) ; 26 ROL d
db opcode_clocks(2, 0, 3, 1, 0) ; 27 AND [d]
								
db opcode_clocks(1, 2, 1, 0, 0) ; 28 PLP
db opcode_clocks(2, 0, 0, 0, 0) ; 29 AND i
db opcode_clocks(1, 1, 0, 0, 0) ; 2A RLA
db opcode_clocks(1, 2, 2, 0, 0) ; 2B PLD
db opcode_clocks(3, 0, 0, 1, 0) ; 2C BIT a
db opcode_clocks(3, 0, 0, 1, 0) ; 2D AND a
db opcode_clocks(3, 1, 0, 2, 0) ; 2E ROL a
db opcode_clocks(4, 0, 0, 1, 0) ; 2F AND al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 30 BMI r
db opcode_clocks(2, 0, 2, 1, 0) ; 31 AND (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 32 AND (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 33 AND (d,s),y
db opcode_clocks(2, 1, 1, 0, 0) ; 34 BIT d,x
db opcode_clocks(2, 1, 1, 0, 0) ; 35 AND d,x
db opcode_clocks(2, 2, 2, 0, 0) ; 36 ROL d,x
db opcode_clocks(2, 0, 3, 1, 0) ; 37 AND [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 38 SEC
db opcode_clocks(3, 0, 0, 1, 0) ; 39 AND a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 3A DEA
db opcode_clocks(1, 1, 0, 0, 0) ; 3B TSC
db opcode_clocks(3, 0, 0, 1, 0) ; 3C BIT a,x
db opcode_clocks(3, 0, 0, 1, 0) ; 3D AND a,x
db opcode_clocks(3, 2, 0, 2, 0) ; 3E ROL a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 3F AND al,x
								
db opcode_clocks(1, 2, 4, 0, 0) ; 40 RTI
db opcode_clocks(2, 1, 2, 1, 0) ; 41 EOR (d,x)
db opcode_clocks(2, 0, 0, 0, 0) ; 42 WDM *
db opcode_clocks(2, 1, 1, 0, 0) ; 43 EOR d,s
db opcode_clocks(3, 2, 0, 2, 0) ; 44 MVP
db opcode_clocks(2, 0, 1, 0, 0) ; 45 EOR d
db opcode_clocks(2, 1, 2, 0, 0) ; 46 LSR d
db opcode_clocks(2, 0, 3, 1, 0) ; 47 EOR [d]
								
db opcode_clocks(1, 1, 1, 0, 0) ; 48 PHA
db opcode_clocks(2, 0, 0, 0, 0) ; 49 EOR i
db opcode_clocks(1, 1, 0, 0, 0) ; 4A SRA
db opcode_clocks(1, 1, 1, 0, 0) ; 4B PHK
db opcode_clocks(3, 0, 0, 0, 0) ; 4C JMP a
db opcode_clocks(3, 0, 0, 1, 0) ; 4D EOR a
db opcode_clocks(3, 1, 0, 2, 0) ; 4E LSR a
db opcode_clocks(4, 0, 0, 1, 0) ; 4F EOR al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 50 BVC r
db opcode_clocks(2, 0, 2, 1, 0) ; 51 EOR (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 52 EOR (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 53 EOR (d,s),y
db opcode_clocks(3, 2, 0, 2, 0) ; 54 MVN
db opcode_clocks(2, 1, 1, 0, 0) ; 55 EOR d,x
db opcode_clocks(2, 2, 2, 0, 0) ; 56 LSR d,x
db opcode_clocks(2, 0, 3, 1, 0) ; 57 EOR [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 58 CLI
db opcode_clocks(3, 0, 0, 1, 0) ; 59 EOR a,y
db opcode_clocks(1, 1, 1, 0, 0) ; 5A PHY
db opcode_clocks(1, 1, 0, 0, 0) ; 5B TCD
db opcode_clocks(4, 0, 0, 0, 0) ; 5C JML al
db opcode_clocks(3, 0, 0, 1, 0) ; 5D EOR a,x
db opcode_clocks(3, 2, 0, 2, 0) ; 5E LSR a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 5F EOR al,x
								
db opcode_clocks(1, 3, 2, 0, 0) ; 60 RTS
db opcode_clocks(2, 1, 2, 1, 0) ; 61 ADC (d,x)
db opcode_clocks(3, 1, 2, 0, 0) ; 62 PER
db opcode_clocks(2, 1, 1, 0, 0) ; 63 ADC d,s
db opcode_clocks(2, 0, 1, 0, 0) ; 64 STZ d
db opcode_clocks(2, 0, 1, 0, 0) ; 65 ADC d
db opcode_clocks(2, 1, 2, 0, 0) ; 66 ROR d
db opcode_clocks(2, 0, 3, 1, 0) ; 67 ADC [d]
								
db opcode_clocks(1, 2, 1, 0, 0) ; 68 PLA
db opcode_clocks(2, 0, 0, 0, 0) ; 69 ADC i
db opcode_clocks(1, 1, 0, 0, 0) ; 6A RRA
db opcode_clocks(1, 2, 3, 0, 0) ; 6B RTL
db opcode_clocks(3, 0, 2, 0, 0) ; 6C JMP (a)
db opcode_clocks(3, 0, 0, 1, 0) ; 6D ADC a
db opcode_clocks(3, 1, 0, 2, 0) ; 6E ROR a
db opcode_clocks(4, 0, 0, 1, 0) ; 6F ADC al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 70 BVS r
db opcode_clocks(2, 0, 2, 1, 0) ; 71 ADC (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 72 ADC (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 73 ADC (d,s),y
db opcode_clocks(2, 1, 1, 0, 0) ; 74 STZ d,x
db opcode_clocks(2, 1, 1, 0, 0) ; 75 ADC d,x
db opcode_clocks(2, 2, 2, 0, 0) ; 76 ROR d,x
db opcode_clocks(2, 0, 3, 1, 0) ; 77 ADC [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 78 SEI
db opcode_clocks(3, 0, 0, 1, 0) ; 79 ADC a,y
db opcode_clocks(1, 2, 1, 0, 0) ; 7A PLY
db opcode_clocks(1, 1, 0, 0, 0) ; 7B TDC
db opcode_clocks(3, 1, 0, 2, 0) ; 7C JMP (a,x) - bus access in PB
db opcode_clocks(3, 0, 0, 1, 0) ; 7D ADC a,x
db opcode_clocks(3, 2, 0, 2, 0) ; 7E ROR a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 7F ADC al,x
								
db opcode_clocks(2, 0, 0, 0, 0) ; 80 BRA r
db opcode_clocks(2, 1, 2, 1, 0) ; 81 STA (d,x)
db opcode_clocks(3, 1, 0, 0, 0) ; 82 BRL rl
db opcode_clocks(2, 1, 1, 0, 0) ; 83 STA d,s
db opcode_clocks(2, 0, 1, 0, 0) ; 84 STY d
db opcode_clocks(2, 0, 1, 0, 0) ; 85 STA d
db opcode_clocks(2, 0, 1, 0, 0) ; 86 STX d
db opcode_clocks(2, 0, 3, 1, 0) ; 87 STA [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; 88 DEY
db opcode_clocks(2, 0, 0, 0, 0) ; 89 BIT i
db opcode_clocks(1, 1, 0, 0, 0) ; 8A TXA
db opcode_clocks(1, 1, 1, 0, 0) ; 8B PHB
db opcode_clocks(3, 0, 0, 1, 0) ; 8C STY a
db opcode_clocks(3, 0, 0, 1, 0) ; 8D STA a
db opcode_clocks(3, 0, 0, 1, 0) ; 8E STX a
db opcode_clocks(4, 0, 0, 1, 0) ; 8F STA al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 90 BCC r
db opcode_clocks(2, 1, 2, 1, 0) ; 91 STA (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 92 STA (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 93 STA (d,s),y
db opcode_clocks(2, 1, 1, 0, 0) ; 94 STY d,x
db opcode_clocks(2, 1, 1, 0, 0) ; 95 STA d,x
db opcode_clocks(2, 1, 1, 0, 0) ; 96 STX d,y
db opcode_clocks(2, 0, 3, 1, 0) ; 97 STA [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 98 TYA
db opcode_clocks(3, 1, 0, 1, 0) ; 99 STA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 9A TXS
db opcode_clocks(1, 1, 0, 0, 0) ; 9B TXY
db opcode_clocks(3, 0, 0, 1, 0) ; 9C STZ a
db opcode_clocks(3, 1, 0, 1, 0) ; 9D STA a,x
db opcode_clocks(3, 1, 0, 1, 0) ; 9E STZ a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 9F STA al,x
								
db opcode_clocks(2, 0, 0, 0, 0) ; A0 LDY i
db opcode_clocks(2, 1, 2, 1, 0) ; A1 LDA (d,x)
db opcode_clocks(2, 0, 0, 0, 0) ; A2 LDX i
db opcode_clocks(2, 1, 1, 0, 0) ; A3 LDA d,s
db opcode_clocks(2, 0, 1, 0, 0) ; A4 LDY d
db opcode_clocks(2, 0, 1, 0, 0) ; A5 LDA d
db opcode_clocks(2, 0, 1, 0, 0) ; A6 LDX d
db opcode_clocks(2, 0, 3, 1, 0) ; A7 LDA [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; A8 TAY
db opcode_clocks(2, 0, 0, 0, 0) ; A9 LDA i
db opcode_clocks(1, 1, 0, 0, 0) ; AA TAX
db opcode_clocks(1, 2, 1, 0, 0) ; AB PLB
db opcode_clocks(3, 0, 0, 1, 0) ; AC LDY a
db opcode_clocks(3, 0, 0, 1, 0) ; AD LDA a
db opcode_clocks(3, 0, 0, 1, 0) ; AE LDX a
db opcode_clocks(4, 0, 0, 1, 0) ; AF LDA al
								
db opcode_clocks(2, 0, 0, 0, 0) ; B0 BCS r
db opcode_clocks(2, 0, 2, 1, 0) ; B1 LDA (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; B2 LDA (d)
db opcode_clocks(2, 2, 2, 1, 0) ; B3 LDA (d,s),y
db opcode_clocks(2, 1, 1, 0, 0) ; B4 LDY d,x
db opcode_clocks(2, 1, 1, 0, 0) ; B5 LDA d,x
db opcode_clocks(2, 1, 1, 0, 0) ; B6 LDX d,y
db opcode_clocks(2, 0, 3, 1, 0) ; B7 LDA [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; B8 CLV
db opcode_clocks(3, 0, 0, 1, 0) ; B9 LDA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; BA TSX
db opcode_clocks(1, 1, 0, 0, 0) ; BB TYX
db opcode_clocks(3, 0, 0, 1, 0) ; BC LDY a,x
db opcode_clocks(3, 0, 0, 1, 0) ; BD LDA a,x
db opcode_clocks(3, 0, 0, 1, 0) ; BE LDX a,y
db opcode_clocks(4, 0, 0, 1, 0) ; BF LDA al,x
								
db opcode_clocks(2, 0, 0, 0, 0) ; C0 CPY i
db opcode_clocks(2, 1, 2, 1, 0) ; C1 CMP (d,x)
db opcode_clocks(2, 1, 0, 0, 0) ; C2 REP i
db opcode_clocks(2, 1, 1, 0, 0) ; C3 CMP d,s
db opcode_clocks(2, 0, 1, 0, 0) ; C4 CPY d
db opcode_clocks(2, 0, 1, 0, 0) ; C5 CMP d
db opcode_clocks(2, 1, 2, 0, 0) ; C6 DEC d
db opcode_clocks(2, 0, 3, 1, 0) ; C7 CMP [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; C8 INY
db opcode_clocks(2, 0, 0, 0, 0) ; C9 CMP i
db opcode_clocks(1, 1, 0, 0, 0) ; CA DEX
db opcode_clocks(1, 2, 0, 0, 0) ; CB WAI
db opcode_clocks(3, 0, 0, 1, 0) ; CC CPY a
db opcode_clocks(3, 0, 0, 1, 0) ; CD CMP a
db opcode_clocks(3, 1, 0, 2, 0) ; CE DEC a
db opcode_clocks(4, 0, 0, 1, 0) ; CF CMP al
								
db opcode_clocks(2, 0, 0, 0, 0) ; D0 BNE r
db opcode_clocks(2, 0, 2, 1, 0) ; D1 CMP (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; D2 CMP (d)
db opcode_clocks(2, 2, 2, 1, 0) ; D3 CMP (d,s),y
db opcode_clocks(2, 0, 4, 0, 0) ; D4 PEI
db opcode_clocks(2, 1, 1, 0, 0) ; D5 CMP d,x
db opcode_clocks(2, 2, 2, 0, 0) ; D6 DEC d,x
db opcode_clocks(2, 0, 3, 1, 0) ; D7 CMP [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; D8 CLD
db opcode_clocks(3, 0, 0, 1, 0) ; D9 CMP a,y
db opcode_clocks(1, 1, 1, 0, 0) ; DA PHX
db opcode_clocks(1, 2, 0, 0, 0) ; DB STP *
db opcode_clocks(3, 0, 3, 0, 0) ; DC JML (a)
db opcode_clocks(3, 0, 0, 1, 0) ; DD CMP a,x
db opcode_clocks(3, 2, 0, 2, 0) ; DE DEC a,x
db opcode_clocks(4, 0, 0, 1, 0) ; DF CMP al,x
								
db opcode_clocks(2, 0, 0, 0, 0) ; E0 CPX i
db opcode_clocks(2, 1, 2, 1, 0) ; E1 SBC (d,x)
db opcode_clocks(2, 1, 0, 0, 0) ; E2 SEP i
db opcode_clocks(2, 1, 1, 0, 0) ; E3 SBC d,s
db opcode_clocks(2, 0, 1, 0, 0) ; E4 CPX d
db opcode_clocks(2, 0, 1, 0, 0) ; E5 SBC d
db opcode_clocks(2, 1, 2, 0, 0) ; E6 INC d
db opcode_clocks(2, 0, 3, 1, 0) ; E7 SBC [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; E8 INX
db opcode_clocks(2, 0, 0, 0, 0) ; E9 SBC i
db opcode_clocks(1, 1, 0, 0, 0) ; EA NOP
db opcode_clocks(1, 2, 0, 0, 0) ; EB XBA
db opcode_clocks(3, 0, 0, 1, 0) ; EC CPX a
db opcode_clocks(3, 0, 0, 1, 0) ; ED SBC a
db opcode_clocks(3, 1, 0, 2, 0) ; EE INC a
db opcode_clocks(4, 0, 0, 1, 0) ; EF SBC al
								
db opcode_clocks(2, 0, 0, 0, 0) ; F0 BEQ r
db opcode_clocks(2, 0, 2, 1, 0) ; F1 SBC (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; F2 SBC (d)
db opcode_clocks(2, 2, 2, 1, 0) ; F3 SBC (d,s),y
db opcode_clocks(3, 0, 2, 0, 0) ; F4 PEA
db opcode_clocks(2, 1, 1, 0, 0) ; F5 SBC d,x
db opcode_clocks(2, 2, 2, 0, 0) ; F6 INC d,x
db opcode_clocks(2, 0, 3, 1, 0) ; F7 SBC [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; F8 SED
db opcode_clocks(3, 0, 0, 1, 0) ; F9 SBC a,y
db opcode_clocks(1, 2, 1, 0, 0) ; FA PLX
db opcode_clocks(1, 1, 0, 0, 0) ; FB XCE
db opcode_clocks(3, 1, 2, 2, 0) ; FC JSR (a,x) - bus access in PB
db opcode_clocks(3, 0, 0, 1, 0) ; FD SBC a,x
db opcode_clocks(3, 2, 0, 2, 0) ; FE INC a,x
db opcode_clocks(4, 0, 0, 1, 0) ; FF SBC al,x

; FastROM
db opcode_clocks(2, 0, 6, 0, 1) ; 00 BRK
db opcode_clocks(2, 1, 2, 1, 1) ; 01 ORA (d,x)
db opcode_clocks(2, 0, 6, 0, 1) ; 02 COP
db opcode_clocks(2, 1, 1, 0, 1) ; 03 ORA d,s
db opcode_clocks(2, 1, 2, 0, 1) ; 04 TSB d
db opcode_clocks(2, 0, 1, 0, 1) ; 05 ORA d
db opcode_clocks(2, 1, 2, 0, 1) ; 06 ASL d
db opcode_clocks(2, 0, 3, 1, 1) ; 07 ORA [d]
								
db opcode_clocks(1, 1, 1, 0, 1) ; 08 PHP
db opcode_clocks(2, 0, 0, 0, 1) ; 09 ORA i
db opcode_clocks(1, 1, 0, 0, 1) ; 0A SLA
db opcode_clocks(1, 1, 2, 0, 1) ; 0B PHD
db opcode_clocks(3, 1, 0, 2, 1) ; 0C TSB a
db opcode_clocks(3, 0, 0, 1, 1) ; 0D ORA a
db opcode_clocks(3, 1, 0, 2, 1) ; 0E ASL a
db opcode_clocks(4, 0, 0, 1, 1) ; 0F ORA al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 10 BPL r
db opcode_clocks(2, 0, 2, 1, 1) ; 11 ORA (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 12 ORA (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 13 ORA (d,s),y
db opcode_clocks(2, 1, 2, 0, 1) ; 14 TRB d
db opcode_clocks(2, 1, 1, 0, 1) ; 15 ORA d,x
db opcode_clocks(2, 2, 2, 0, 1) ; 16 ASL d,x
db opcode_clocks(2, 0, 3, 1, 1) ; 17 ORA [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 18 CLC
db opcode_clocks(3, 0, 0, 1, 1) ; 19 ORA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 1A INA
db opcode_clocks(1, 1, 0, 0, 1) ; 1B TCS
db opcode_clocks(3, 1, 0, 2, 1) ; 1C TRB a
db opcode_clocks(3, 0, 0, 1, 1) ; 1D ORA a,x
db opcode_clocks(3, 2, 0, 2, 1) ; 1E ASL a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 1F ORA al,x
								
db opcode_clocks(3, 1, 2, 0, 1) ; 20 JSR a
db opcode_clocks(2, 1, 2, 1, 1) ; 21 AND (d,x)
db opcode_clocks(4, 1, 3, 0, 1) ; 22 JSL al
db opcode_clocks(2, 1, 1, 0, 1) ; 23 AND d,s
db opcode_clocks(2, 0, 1, 0, 1) ; 24 BIT d
db opcode_clocks(2, 0, 1, 0, 1) ; 25 AND d
db opcode_clocks(2, 1, 2, 0, 1) ; 26 ROL d
db opcode_clocks(2, 0, 3, 1, 1) ; 27 AND [d]
								
db opcode_clocks(1, 2, 1, 0, 1) ; 28 PLP
db opcode_clocks(2, 0, 0, 0, 1) ; 29 AND i
db opcode_clocks(1, 1, 0, 0, 1) ; 2A RLA
db opcode_clocks(1, 2, 2, 0, 1) ; 2B PLD
db opcode_clocks(3, 0, 0, 1, 1) ; 2C BIT a
db opcode_clocks(3, 0, 0, 1, 1) ; 2D AND a
db opcode_clocks(3, 1, 0, 2, 1) ; 2E ROL a
db opcode_clocks(4, 0, 0, 1, 1) ; 2F AND al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 30 BMI r
db opcode_clocks(2, 0, 2, 1, 1) ; 31 AND (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 32 AND (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 33 AND (d,s),y
db opcode_clocks(2, 1, 1, 0, 1) ; 34 BIT d,x
db opcode_clocks(2, 1, 1, 0, 1) ; 35 AND d,x
db opcode_clocks(2, 2, 2, 0, 1) ; 36 ROL d,x
db opcode_clocks(2, 0, 3, 1, 1) ; 37 AND [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 38 SEC
db opcode_clocks(3, 0, 0, 1, 1) ; 39 AND a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 3A DEA
db opcode_clocks(1, 1, 0, 0, 1) ; 3B TSC
db opcode_clocks(3, 0, 0, 1, 1) ; 3C BIT a,x
db opcode_clocks(3, 0, 0, 1, 1) ; 3D AND a,x
db opcode_clocks(3, 2, 0, 2, 1) ; 3E ROL a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 3F AND al,x
								
db opcode_clocks(1, 2, 4, 0, 1) ; 40 RTI
db opcode_clocks(2, 1, 2, 1, 1) ; 41 EOR (d,x)
db opcode_clocks(2, 0, 0, 0, 1) ; 42 WDM *
db opcode_clocks(2, 1, 1, 0, 1) ; 43 EOR d,s
db opcode_clocks(3, 2, 0, 2, 1) ; 44 MVP
db opcode_clocks(2, 0, 1, 0, 1) ; 45 EOR d
db opcode_clocks(2, 1, 2, 0, 1) ; 46 LSR d
db opcode_clocks(2, 0, 3, 1, 1) ; 47 EOR [d]
								
db opcode_clocks(1, 1, 1, 0, 1) ; 48 PHA
db opcode_clocks(2, 0, 0, 0, 1) ; 49 EOR i
db opcode_clocks(1, 1, 0, 0, 1) ; 4A SRA
db opcode_clocks(1, 1, 1, 0, 1) ; 4B PHK
db opcode_clocks(3, 0, 0, 0, 1) ; 4C JMP a
db opcode_clocks(3, 0, 0, 1, 1) ; 4D EOR a
db opcode_clocks(3, 1, 0, 2, 1) ; 4E LSR a
db opcode_clocks(4, 0, 0, 1, 1) ; 4F EOR al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 50 BVC r
db opcode_clocks(2, 0, 2, 1, 1) ; 51 EOR (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 52 EOR (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 53 EOR (d,s),y
db opcode_clocks(3, 2, 0, 2, 1) ; 54 MVN
db opcode_clocks(2, 1, 1, 0, 1) ; 55 EOR d,x
db opcode_clocks(2, 2, 2, 0, 1) ; 56 LSR d,x
db opcode_clocks(2, 0, 3, 1, 1) ; 57 EOR [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 58 CLI
db opcode_clocks(3, 0, 0, 1, 1) ; 59 EOR a,y
db opcode_clocks(1, 1, 1, 0, 1) ; 5A PHY
db opcode_clocks(1, 1, 0, 0, 1) ; 5B TCD
db opcode_clocks(4, 0, 0, 0, 1) ; 5C JML al
db opcode_clocks(3, 0, 0, 1, 1) ; 5D EOR a,x
db opcode_clocks(3, 2, 0, 2, 1) ; 5E LSR a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 5F EOR al,x
								
db opcode_clocks(1, 3, 2, 0, 1) ; 60 RTS
db opcode_clocks(2, 1, 2, 1, 1) ; 61 ADC (d,x)
db opcode_clocks(3, 1, 2, 0, 1) ; 62 PER
db opcode_clocks(2, 1, 1, 0, 1) ; 63 ADC d,s
db opcode_clocks(2, 0, 1, 0, 1) ; 64 STZ d
db opcode_clocks(2, 0, 1, 0, 1) ; 65 ADC d
db opcode_clocks(2, 1, 2, 0, 1) ; 66 ROR d
db opcode_clocks(2, 0, 3, 1, 1) ; 67 ADC [d]
								
db opcode_clocks(1, 2, 1, 0, 1) ; 68 PLA
db opcode_clocks(2, 0, 0, 0, 1) ; 69 ADC i
db opcode_clocks(1, 1, 0, 0, 1) ; 6A RRA
db opcode_clocks(1, 2, 3, 0, 1) ; 6B RTL
db opcode_clocks(3, 0, 2, 0, 1) ; 6C JMP (a)
db opcode_clocks(3, 0, 0, 1, 1) ; 6D ADC a
db opcode_clocks(3, 1, 0, 2, 1) ; 6E ROR a
db opcode_clocks(4, 0, 0, 1, 1) ; 6F ADC al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 70 BVS r
db opcode_clocks(2, 0, 2, 1, 1) ; 71 ADC (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 72 ADC (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 73 ADC (d,s),y
db opcode_clocks(2, 1, 1, 0, 1) ; 74 STZ d,x
db opcode_clocks(2, 1, 1, 0, 1) ; 75 ADC d,x
db opcode_clocks(2, 2, 2, 0, 1) ; 76 ROR d,x
db opcode_clocks(2, 0, 3, 1, 1) ; 77 ADC [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 78 SEI
db opcode_clocks(3, 0, 0, 1, 1) ; 79 ADC a,y
db opcode_clocks(1, 2, 1, 0, 1) ; 7A PLY
db opcode_clocks(1, 1, 0, 0, 1) ; 7B TDC
db opcode_clocks(3, 1, 0, 2, 1) ; 7C JMP (a,x) - bus access in PB
db opcode_clocks(3, 0, 0, 1, 1) ; 7D ADC a,x
db opcode_clocks(3, 2, 0, 2, 1) ; 7E ROR a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 7F ADC al,x
								
db opcode_clocks(2, 0, 0, 0, 1) ; 80 BRA r
db opcode_clocks(2, 1, 2, 1, 1) ; 81 STA (d,x)
db opcode_clocks(3, 1, 0, 0, 1) ; 82 BRL rl
db opcode_clocks(2, 1, 1, 0, 1) ; 83 STA d,s
db opcode_clocks(2, 0, 1, 0, 1) ; 84 STY d
db opcode_clocks(2, 0, 1, 0, 1) ; 85 STA d
db opcode_clocks(2, 0, 1, 0, 1) ; 86 STX d
db opcode_clocks(2, 0, 3, 1, 1) ; 87 STA [d]
								
db opcode_clocks(1, 1, 0, 0, 1) ; 88 DEY
db opcode_clocks(2, 0, 0, 0, 1) ; 89 BIT i
db opcode_clocks(1, 1, 0, 0, 1) ; 8A TXA
db opcode_clocks(1, 1, 1, 0, 1) ; 8B PHB
db opcode_clocks(3, 0, 0, 1, 1) ; 8C STY a
db opcode_clocks(3, 0, 0, 1, 1) ; 8D STA a
db opcode_clocks(3, 0, 0, 1, 1) ; 8E STX a
db opcode_clocks(4, 0, 0, 1, 1) ; 8F STA al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 90 BCC r
db opcode_clocks(2, 1, 2, 1, 1) ; 91 STA (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 92 STA (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 93 STA (d,s),y
db opcode_clocks(2, 1, 1, 0, 1) ; 94 STY d,x
db opcode_clocks(2, 1, 1, 0, 1) ; 95 STA d,x
db opcode_clocks(2, 1, 1, 0, 1) ; 96 STX d,y
db opcode_clocks(2, 0, 3, 1, 1) ; 97 STA [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 98 TYA
db opcode_clocks(3, 1, 0, 1, 1) ; 99 STA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 9A TXS
db opcode_clocks(1, 1, 0, 0, 1) ; 9B TXY
db opcode_clocks(3, 0, 0, 1, 1) ; 9C STZ a
db opcode_clocks(3, 1, 0, 1, 1) ; 9D STA a,x
db opcode_clocks(3, 1, 0, 1, 1) ; 9E STZ a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 9F STA al,x
								
db opcode_clocks(2, 0, 0, 0, 1) ; A0 LDY i
db opcode_clocks(2, 1, 2, 1, 1) ; A1 LDA (d,x)
db opcode_clocks(2, 0, 0, 0, 1) ; A2 LDX i
db opcode_clocks(2, 1, 1, 0, 1) ; A3 LDA d,s
db opcode_clocks(2, 0, 1, 0, 1) ; A4 LDY d
db opcode_clocks(2, 0, 1, 0, 1) ; A5 LDA d
db opcode_clocks(2, 0, 1, 0, 1) ; A6 LDX d
db opcode_clocks(2, 0, 3, 1, 1) ; A7 LDA [d]
								
db opcode_clocks(1, 1, 0, 0, 1) ; A8 TAY
db opcode_clocks(2, 0, 0, 0, 1) ; A9 LDA i
db opcode_clocks(1, 1, 0, 0, 1) ; AA TAX
db opcode_clocks(1, 2, 1, 0, 1) ; AB PLB
db opcode_clocks(3, 0, 0, 1, 1) ; AC LDY a
db opcode_clocks(3, 0, 0, 1, 1) ; AD LDA a
db opcode_clocks(3, 0, 0, 1, 1) ; AE LDX a
db opcode_clocks(4, 0, 0, 1, 1) ; AF LDA al
								
db opcode_clocks(2, 0, 0, 0, 1) ; B0 BCS r
db opcode_clocks(2, 0, 2, 1, 1) ; B1 LDA (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; B2 LDA (d)
db opcode_clocks(2, 2, 2, 1, 1) ; B3 LDA (d,s),y
db opcode_clocks(2, 1, 1, 0, 1) ; B4 LDY d,x
db opcode_clocks(2, 1, 1, 0, 1) ; B5 LDA d,x
db opcode_clocks(2, 1, 1, 0, 1) ; B6 LDX d,y
db opcode_clocks(2, 0, 3, 1, 1) ; B7 LDA [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; B8 CLV
db opcode_clocks(3, 0, 0, 1, 1) ; B9 LDA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; BA TSX
db opcode_clocks(1, 1, 0, 0, 1) ; BB TYX
db opcode_clocks(3, 0, 0, 1, 1) ; BC LDY a,x
db opcode_clocks(3, 0, 0, 1, 1) ; BD LDA a,x
db opcode_clocks(3, 0, 0, 1, 1) ; BE LDX a,y
db opcode_clocks(4, 0, 0, 1, 1) ; BF LDA al,x
								
db opcode_clocks(2, 0, 0, 0, 1) ; C0 CPY i
db opcode_clocks(2, 1, 2, 1, 1) ; C1 CMP (d,x)
db opcode_clocks(2, 1, 0, 0, 1) ; C2 REP i
db opcode_clocks(2, 1, 1, 0, 1) ; C3 CMP d,s
db opcode_clocks(2, 0, 1, 0, 1) ; C4 CPY d
db opcode_clocks(2, 0, 1, 0, 1) ; C5 CMP d
db opcode_clocks(2, 1, 2, 0, 1) ; C6 DEC d
db opcode_clocks(2, 0, 3, 1, 1) ; C7 CMP [d]
								
db opcode_clocks(1, 1, 0, 0, 1) ; C8 INY
db opcode_clocks(2, 0, 0, 0, 1) ; C9 CMP i
db opcode_clocks(1, 1, 0, 0, 1) ; CA DEX
db opcode_clocks(1, 2, 0, 0, 1) ; CB WAI
db opcode_clocks(3, 0, 0, 1, 1) ; CC CPY a
db opcode_clocks(3, 0, 0, 1, 1) ; CD CMP a
db opcode_clocks(3, 1, 0, 2, 1) ; CE DEC a
db opcode_clocks(4, 0, 0, 1, 1) ; CF CMP al
								
db opcode_clocks(2, 0, 0, 0, 1) ; D0 BNE r
db opcode_clocks(2, 0, 2, 1, 1) ; D1 CMP (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; D2 CMP (d)
db opcode_clocks(2, 2, 2, 1, 1) ; D3 CMP (d,s),y
db opcode_clocks(2, 0, 4, 0, 1) ; D4 PEI
db opcode_clocks(2, 1, 1, 0, 1) ; D5 CMP d,x
db opcode_clocks(2, 2, 2, 0, 1) ; D6 DEC d,x
db opcode_clocks(2, 0, 3, 1, 1) ; D7 CMP [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; D8 CLD
db opcode_clocks(3, 0, 0, 1, 1) ; D9 CMP a,y
db opcode_clocks(1, 1, 1, 0, 1) ; DA PHX
db opcode_clocks(1, 2, 0, 0, 1) ; DB STP *
db opcode_clocks(3, 0, 3, 0, 1) ; DC JML (a)
db opcode_clocks(3, 0, 0, 1, 1) ; DD CMP a,x
db opcode_clocks(3, 2, 0, 2, 1) ; DE DEC a,x
db opcode_clocks(4, 0, 0, 1, 1) ; DF CMP al,x
								
db opcode_clocks(2, 0, 0, 0, 1) ; E0 CPX i
db opcode_clocks(2, 1, 2, 1, 1) ; E1 SBC (d,x)
db opcode_clocks(2, 1, 0, 0, 1) ; E2 SEP i
db opcode_clocks(2, 1, 1, 0, 1) ; E3 SBC d,s
db opcode_clocks(2, 0, 1, 0, 1) ; E4 CPX d
db opcode_clocks(2, 0, 1, 0, 1) ; E5 SBC d
db opcode_clocks(2, 1, 2, 0, 1) ; E6 INC d
db opcode_clocks(2, 0, 3, 1, 1) ; E7 SBC [d]
								
db opcode_clocks(1, 1, 0, 0, 1) ; E8 INX
db opcode_clocks(2, 0, 0, 0, 1) ; E9 SBC i
db opcode_clocks(1, 1, 0, 0, 1) ; EA NOP
db opcode_clocks(1, 2, 0, 0, 1) ; EB XBA
db opcode_clocks(3, 0, 0, 1, 1) ; EC CPX a
db opcode_clocks(3, 0, 0, 1, 1) ; ED SBC a
db opcode_clocks(3, 1, 0, 2, 1) ; EE INC a
db opcode_clocks(4, 0, 0, 1, 1) ; EF SBC al
								
db opcode_clocks(2, 0, 0, 0, 1) ; F0 BEQ r
db opcode_clocks(2, 0, 2, 1, 1) ; F1 SBC (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; F2 SBC (d)
db opcode_clocks(2, 2, 2, 1, 1) ; F3 SBC (d,s),y
db opcode_clocks(3, 0, 2, 0, 1) ; F4 PEA
db opcode_clocks(2, 1, 1, 0, 1) ; F5 SBC d,x
db opcode_clocks(2, 2, 2, 0, 1) ; F6 INC d,x
db opcode_clocks(2, 0, 3, 1, 1) ; F7 SBC [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; F8 SED
db opcode_clocks(3, 0, 0, 1, 1) ; F9 SBC a,y
db opcode_clocks(1, 2, 1, 0, 1) ; FA PLX
db opcode_clocks(1, 1, 0, 0, 1) ; FB XCE
db opcode_clocks(3, 1, 2, 2, 1) ; FC JSR (a,x) - bus access in PB
db opcode_clocks(3, 0, 0, 1, 1) ; FD SBC a,x
db opcode_clocks(3, 2, 0, 2, 1) ; FE INC a,x
db opcode_clocks(4, 0, 0, 1, 1) ; FF SBC al,x

OpTableE1:
dd  C_LABEL(E1_BRK)       ,C_LABEL(EM_ORA_Od_xO)    ; 00
dd  C_LABEL(E1_COP)       ,C_LABEL(OpM1_0x03)
dd  C_LABEL(OpE1_0x04)    ,C_LABEL(EM_ORA_d)
dd  C_LABEL(OpE1_0x06)    ,C_LABEL(EM_ORA_IdI)
dd  C_LABEL(E1_PHP)       ,C_LABEL(OpM1_0x09)
dd  C_LABEL(OpM1_0x0A)    ,C_LABEL(E1_PHD)
dd  C_LABEL(OpM1_0x0C)    ,C_LABEL(OpM1_0x0D)
dd  C_LABEL(OpM1_0x0E)    ,C_LABEL(OpM1_0x0F)
dd  C_LABEL(ALL_BPL)      ,C_LABEL(OpE1_0x11)       ; 10
dd  C_LABEL(EM_ORA_OdO)   ,C_LABEL(OpM1_0x13)
dd  C_LABEL(OpE1_0x14)    ,C_LABEL(EM_ORA_d_x)
dd  C_LABEL(OpE1_0x16)    ,C_LABEL(EM_ORA_IdI_y)
dd  C_LABEL(ALL_CLC)      ,C_LABEL(EM_ORA_a_y)
dd  C_LABEL(OpM1_0x1A)    ,C_LABEL(E1_TCS)
dd  C_LABEL(OpM1_0x1C)    ,C_LABEL(EM_ORA_a_x)
dd  C_LABEL(OpM1_0x1E)    ,C_LABEL(EM_ORA_al_x)
dd  C_LABEL(E1_JSR_a)     ,C_LABEL(EM_AND_Od_xO)    ; 20
dd  C_LABEL(E1_JSL_al)    ,C_LABEL(OpM1_0x23)
dd  C_LABEL(EM_BIT_d)     ,C_LABEL(EM_AND_d)
dd  C_LABEL(OpE1_0x26)    ,C_LABEL(EM_AND_IdI)
dd  C_LABEL(E1_PLP)       ,C_LABEL(OpM1_0x29)
dd  C_LABEL(OpM1_0x2A)    ,C_LABEL(E1_PLD)
dd  C_LABEL(OpM1_0x2C)    ,C_LABEL(OpM1_0x2D)
dd  C_LABEL(OpM1_0x2E)    ,C_LABEL(OpM1_0x2F)
dd  C_LABEL(ALL_BMI)      ,C_LABEL(OpE1_0x31)       ; 30
dd  C_LABEL(EM_AND_OdO)   ,C_LABEL(OpM1_0x33)
dd  C_LABEL(EM_BIT_d_x)   ,C_LABEL(EM_AND_d_x)
dd  C_LABEL(OpE1_0x36)    ,C_LABEL(EM_AND_IdI_y)
dd  C_LABEL(ALL_SEC)      ,C_LABEL(EM_AND_a_y)
dd  C_LABEL(OpM1_0x3A)    ,C_LABEL(ALL_TSC)
dd  C_LABEL(EM_BIT_a_x)   ,C_LABEL(EM_AND_a_x)
dd  C_LABEL(OpM1_0x3E)    ,C_LABEL(EM_AND_al_x)
dd  C_LABEL(E1_RTI)       ,C_LABEL(EM_EOR_Od_xO)    ; 40
dd  C_LABEL(ALL_INVALID)  ,C_LABEL(OpM1_0x43)
dd  C_LABEL(EX_MVP)       ,C_LABEL(EM_EOR_d)
dd  C_LABEL(OpE1_0x46)    ,C_LABEL(EM_EOR_IdI)
dd  C_LABEL(EM_PHA)       ,C_LABEL(OpM1_0x49)
dd  C_LABEL(OpM1_0x4A)    ,C_LABEL(E1_PHK)
dd  C_LABEL(ALL_JMP_a)    ,C_LABEL(OpM1_0x4D)
dd  C_LABEL(OpM1_0x4E)    ,C_LABEL(OpM1_0x4F)
dd  C_LABEL(ALL_BVC)      ,C_LABEL(OpE1_0x51)       ; 50
dd  C_LABEL(EM_EOR_OdO)   ,C_LABEL(OpM1_0x53)
dd  C_LABEL(EX_MVN)       ,C_LABEL(EM_EOR_d_x)
dd  C_LABEL(OpE1_0x56)    ,C_LABEL(EM_EOR_IdI_y)
dd  C_LABEL(ALL_CLI)      ,C_LABEL(EM_EOR_a_y)
dd  C_LABEL(E1_PHY)       ,C_LABEL(ALL_TCD)
dd  C_LABEL(ALL_JML_al)   ,C_LABEL(EM_EOR_a_x)
dd  C_LABEL(OpM1_0x5E)    ,C_LABEL(EM_EOR_al_x)
dd  C_LABEL(E1_RTS)       ,C_LABEL(EM_ADC_Od_xO)    ; 60
dd  C_LABEL(E1_PER)       ,C_LABEL(OpM1_0x63)
dd  C_LABEL(OpE1_0x64)    ,C_LABEL(EM_ADC_d)
dd  C_LABEL(OpE1_0x66)    ,C_LABEL(EM_ADC_IdI)
dd  C_LABEL(E1_PLA)       ,C_LABEL(OpM1_0x69)
dd  C_LABEL(OpM1_0x6A)    ,C_LABEL(E1_RTL)
dd  C_LABEL(ALL_JMP_OaO)  ,C_LABEL(OpM1_0x6D)
dd  C_LABEL(OpM1_0x6E)    ,C_LABEL(OpM1_0x6F)
dd  C_LABEL(ALL_BVS)      ,C_LABEL(OpE1_0x71)       ; 70
dd  C_LABEL(EM_ADC_OdO)   ,C_LABEL(OpM1_0x73)
dd  C_LABEL(OpE1_0x74)    ,C_LABEL(EM_ADC_d_x)
dd  C_LABEL(OpE1_0x76)    ,C_LABEL(EM_ADC_IdI_y)
dd  C_LABEL(ALL_SEI)      ,C_LABEL(EM_ADC_a_y)
dd  C_LABEL(E1_PLY)       ,C_LABEL(ALL_TDC)
dd  C_LABEL(ALL_JMP_Oa_xO),C_LABEL(EM_ADC_a_x)
dd  C_LABEL(OpM1_0x7E)    ,C_LABEL(EM_ADC_al_x)
dd  C_LABEL(ALL_BRA)      ,C_LABEL(OpE1_0x81)       ; 80
dd  C_LABEL(ALL_BRL)      ,C_LABEL(OpM1_0x83)
dd  C_LABEL(OpE1_0x84)    ,C_LABEL(OpE1_0x85)
dd  C_LABEL(OpE1_0x86)    ,C_LABEL(OpE1_0x87)
dd  C_LABEL(OpX1_0x88)    ,C_LABEL(EM_BIT_i)
dd  C_LABEL(EM_TXA)       ,C_LABEL(E1_PHB)
dd  C_LABEL(OpX1_0x8C)    ,C_LABEL(OpM1_0x8D)
dd  C_LABEL(OpX1_0x8E)    ,C_LABEL(OpM1_0x8F)
dd  C_LABEL(ALL_BCC)      ,C_LABEL(OpE1_0x91)       ; 90
dd  C_LABEL(OpE1_0x92)    ,C_LABEL(OpM1_0x93)
dd  C_LABEL(OpE1_0x94)    ,C_LABEL(OpE1_0x95)
dd  C_LABEL(OpE1_0x96)    ,C_LABEL(OpE1_0x97)
dd  C_LABEL(EM_TYA)       ,C_LABEL(OpM1_0x99)
dd  C_LABEL(E1_TXS)       ,C_LABEL(EX_TXY)
dd  C_LABEL(OpM1_0x9C)    ,C_LABEL(OpM1_0x9D)
dd  C_LABEL(OpM1_0x9E)    ,C_LABEL(OpM1_0x9F)
dd  C_LABEL(OpX1_0xA0)    ,C_LABEL(EM_LDA_Od_xO)    ; A0
dd  C_LABEL(OpX1_0xA2)    ,C_LABEL(OpM1_0xA3)
dd  C_LABEL(EX_LDY_d)     ,C_LABEL(EM_LDA_d)
dd  C_LABEL(EX_LDX_d)     ,C_LABEL(EM_LDA_IdI)
dd  C_LABEL(EX_TAY)       ,C_LABEL(OpM1_0xA9)
dd  C_LABEL(EX_TAX)       ,C_LABEL(E1_PLB)
dd  C_LABEL(OpX1_0xAC)    ,C_LABEL(OpM1_0xAD)
dd  C_LABEL(OpX1_0xAE)    ,C_LABEL(OpM1_0xAF)
dd  C_LABEL(ALL_BCS)      ,C_LABEL(OpE1_0xB1)       ; B0
dd  C_LABEL(EM_LDA_OdO)   ,C_LABEL(OpM1_0xB3)
dd  C_LABEL(EX_LDY_d_x)   ,C_LABEL(EM_LDA_d_x)
dd  C_LABEL(EX_LDX_d_y)   ,C_LABEL(EM_LDA_IdI_y)
dd  C_LABEL(ALL_CLV)      ,C_LABEL(EM_LDA_a_y)
dd  C_LABEL(EX_TSX)       ,C_LABEL(EX_TYX)
dd  C_LABEL(EX_LDY_a_x)   ,C_LABEL(EM_LDA_a_x)
dd  C_LABEL(EX_LDX_a_y)   ,C_LABEL(EM_LDA_al_x)
dd  C_LABEL(OpX1_0xC0)    ,C_LABEL(EM_CMP_Od_xO)    ; C0
dd  C_LABEL(E1_REP)       ,C_LABEL(OpM1_0xC3)
dd  C_LABEL(EX_CPY_d)     ,C_LABEL(EM_CMP_d)
dd  C_LABEL(OpE1_0xC6)    ,C_LABEL(EM_CMP_IdI)
dd  C_LABEL(OpX1_0xC8)    ,C_LABEL(OpM1_0xC9)
dd  C_LABEL(OpX1_0xCA)    ,C_LABEL(ALL_WAI)
dd  C_LABEL(OpX1_0xCC)    ,C_LABEL(OpM1_0xCD)
dd  C_LABEL(OpM1_0xCE)    ,C_LABEL(OpM1_0xCF)
dd  C_LABEL(ALL_BNE)      ,C_LABEL(OpE1_0xD1)       ; D0
dd  C_LABEL(EM_CMP_OdO)   ,C_LABEL(OpM1_0xD3)
dd  C_LABEL(E1_PEI)       ,C_LABEL(EM_CMP_d_x)
dd  C_LABEL(OpE1_0xD6)    ,C_LABEL(EM_CMP_IdI_y)
dd  C_LABEL(ALL_CLD)      ,C_LABEL(EM_CMP_a_y)
dd  C_LABEL(E1_PHX)       ,C_LABEL(ALL_INVALID)
dd  C_LABEL(ALL_JML_OaO)  ,C_LABEL(EM_CMP_a_x)
dd  C_LABEL(OpM1_0xDE)    ,C_LABEL(EM_CMP_al_x)
dd  C_LABEL(OpX1_0xE0)    ,C_LABEL(EM_SBC_Od_xO)    ; E0
dd  C_LABEL(E1_SEP)       ,C_LABEL(OpM1_0xE3)
dd  C_LABEL(EX_CPX_d)     ,C_LABEL(EM_SBC_d)
dd  C_LABEL(OpE1_0xE6)    ,C_LABEL(EM_SBC_IdI)
dd  C_LABEL(OpX1_0xE8)    ,C_LABEL(OpM1_0xE9)
dd  C_LABEL(ALL_NOP)      ,C_LABEL(ALL_XBA)
dd  C_LABEL(OpX1_0xEC)    ,C_LABEL(OpM1_0xED)
dd  C_LABEL(OpM1_0xEE)    ,C_LABEL(OpM1_0xEF)
dd  C_LABEL(ALL_BEQ)      ,C_LABEL(OpE1_0xF1)       ; F0
dd  C_LABEL(EM_SBC_OdO)   ,C_LABEL(OpM1_0xF3)
dd  C_LABEL(E1_PEA)       ,C_LABEL(EM_SBC_d_x)
dd  C_LABEL(OpE1_0xF6)    ,C_LABEL(EM_SBC_IdI_y)
dd  C_LABEL(ALL_SED)      ,C_LABEL(EM_SBC_a_y)
dd  C_LABEL(E1_PLX)       ,C_LABEL(E1_XCE)
dd  C_LABEL(E1_JSR_Oa_xO) ,C_LABEL(EM_SBC_a_x)
dd  C_LABEL(OpM1_0xFE)    ,C_LABEL(EM_SBC_al_x)

; bytes, internal operations, bank 0 accesses, other bus accesses, speed
;  speed = 0 for SlowROM, 1 for FastROM
CCTableE1:
; SlowROM
db opcode_clocks(2, 0, 5, 0, 0) ; 00 BRK
db opcode_clocks(2, 1, 2, 1, 0) ; 01 ORA (d,x)
db opcode_clocks(2, 0, 5, 0, 0) ; 02 COP
db opcode_clocks(2, 1, 1, 0, 0) ; 03 ORA d,s
db opcode_clocks(2, 1, 2, 0, 0) ; 04 TSB d
db opcode_clocks(2, 0, 1, 0, 0) ; 05 ORA d
db opcode_clocks(2, 1, 2, 0, 0) ; 06 ASL d
db opcode_clocks(2, 0, 3, 1, 0) ; 07 ORA [d]
								
db opcode_clocks(1, 1, 1, 0, 0) ; 08 PHP
db opcode_clocks(2, 0, 0, 0, 0) ; 09 ORA i
db opcode_clocks(1, 1, 0, 0, 0) ; 0A SLA
db opcode_clocks(1, 1, 2, 0, 0) ; 0B PHD
db opcode_clocks(3, 1, 0, 2, 0) ; 0C TSB a
db opcode_clocks(3, 0, 0, 1, 0) ; 0D ORA a
db opcode_clocks(3, 1, 0, 2, 0) ; 0E ASL a
db opcode_clocks(4, 0, 0, 1, 0) ; 0F ORA al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 10 BPL r
db opcode_clocks(2, 0, 2, 1, 0) ; 11 ORA (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 12 ORA (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 13 ORA (d,s),y
db opcode_clocks(2, 1, 2, 0, 0) ; 14 TRB d
db opcode_clocks(2, 1, 1, 0, 0) ; 15 ORA d,x
db opcode_clocks(2, 2, 2, 0, 0) ; 16 ASL d,x
db opcode_clocks(2, 0, 3, 1, 0) ; 17 ORA [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 18 CLC
db opcode_clocks(3, 0, 0, 1, 0) ; 19 ORA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 1A INA
db opcode_clocks(1, 1, 0, 0, 0) ; 1B TCS
db opcode_clocks(3, 1, 0, 2, 0) ; 1C TRB a
db opcode_clocks(3, 0, 0, 1, 0) ; 1D ORA a,x
db opcode_clocks(3, 2, 0, 2, 0) ; 1E ASL a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 1F ORA al,x
								
db opcode_clocks(3, 1, 2, 0, 0) ; 20 JSR a
db opcode_clocks(2, 1, 2, 1, 0) ; 21 AND (d,x)
db opcode_clocks(4, 1, 3, 0, 0) ; 22 JSL al
db opcode_clocks(2, 1, 1, 0, 0) ; 23 AND d,s
db opcode_clocks(2, 0, 1, 0, 0) ; 24 BIT d
db opcode_clocks(2, 0, 1, 0, 0) ; 25 AND d
db opcode_clocks(2, 1, 2, 0, 0) ; 26 ROL d
db opcode_clocks(2, 0, 3, 1, 0) ; 27 AND [d]
								
db opcode_clocks(1, 2, 1, 0, 0) ; 28 PLP
db opcode_clocks(2, 0, 0, 0, 0) ; 29 AND i
db opcode_clocks(1, 1, 0, 0, 0) ; 2A RLA
db opcode_clocks(1, 2, 2, 0, 0) ; 2B PLD
db opcode_clocks(3, 0, 0, 1, 0) ; 2C BIT a
db opcode_clocks(3, 0, 0, 1, 0) ; 2D AND a
db opcode_clocks(3, 1, 0, 2, 0) ; 2E ROL a
db opcode_clocks(4, 0, 0, 1, 0) ; 2F AND al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 30 BMI r
db opcode_clocks(2, 0, 2, 1, 0) ; 31 AND (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 32 AND (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 33 AND (d,s),y
db opcode_clocks(2, 1, 1, 0, 0) ; 34 BIT d,x
db opcode_clocks(2, 1, 1, 0, 0) ; 35 AND d,x
db opcode_clocks(2, 2, 2, 0, 0) ; 36 ROL d,x
db opcode_clocks(2, 0, 3, 1, 0) ; 37 AND [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 38 SEC
db opcode_clocks(3, 0, 0, 1, 0) ; 39 AND a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 3A DEA
db opcode_clocks(1, 1, 0, 0, 0) ; 3B TSC
db opcode_clocks(3, 0, 0, 1, 0) ; 3C BIT a,x
db opcode_clocks(3, 0, 0, 1, 0) ; 3D AND a,x
db opcode_clocks(3, 2, 0, 2, 0) ; 3E ROL a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 3F AND al,x
								
db opcode_clocks(1, 2, 3, 0, 0) ; 40 RTI
db opcode_clocks(2, 1, 2, 1, 0) ; 41 EOR (d,x)
db opcode_clocks(2, 0, 0, 0, 0) ; 42 WDM *
db opcode_clocks(2, 1, 1, 0, 0) ; 43 EOR d,s
db opcode_clocks(3, 2, 0, 2, 0) ; 44 MVP
db opcode_clocks(2, 0, 1, 0, 0) ; 45 EOR d
db opcode_clocks(2, 1, 2, 0, 0) ; 46 LSR d
db opcode_clocks(2, 0, 3, 1, 0) ; 47 EOR [d]
								
db opcode_clocks(1, 1, 1, 0, 0) ; 48 PHA
db opcode_clocks(2, 0, 0, 0, 0) ; 49 EOR i
db opcode_clocks(1, 1, 0, 0, 0) ; 4A SRA
db opcode_clocks(1, 1, 1, 0, 0) ; 4B PHK
db opcode_clocks(3, 0, 0, 0, 0) ; 4C JMP a
db opcode_clocks(3, 0, 0, 1, 0) ; 4D EOR a
db opcode_clocks(3, 1, 0, 2, 0) ; 4E LSR a
db opcode_clocks(4, 0, 0, 1, 0) ; 4F EOR al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 50 BVC r
db opcode_clocks(2, 0, 2, 1, 0) ; 51 EOR (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 52 EOR (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 53 EOR (d,s),y
db opcode_clocks(3, 2, 0, 2, 0) ; 54 MVN
db opcode_clocks(2, 1, 1, 0, 0) ; 55 EOR d,x
db opcode_clocks(2, 2, 2, 0, 0) ; 56 LSR d,x
db opcode_clocks(2, 0, 3, 1, 0) ; 57 EOR [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 58 CLI
db opcode_clocks(3, 0, 0, 1, 0) ; 59 EOR a,y
db opcode_clocks(1, 1, 1, 0, 0) ; 5A PHY
db opcode_clocks(1, 1, 0, 0, 0) ; 5B TCD
db opcode_clocks(4, 0, 0, 0, 0) ; 5C JML al
db opcode_clocks(3, 0, 0, 1, 0) ; 5D EOR a,x
db opcode_clocks(3, 2, 0, 2, 0) ; 5E LSR a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 5F EOR al,x
								
db opcode_clocks(1, 3, 2, 0, 0) ; 60 RTS
db opcode_clocks(2, 1, 2, 1, 0) ; 61 ADC (d,x)
db opcode_clocks(3, 1, 2, 0, 0) ; 62 PER
db opcode_clocks(2, 1, 1, 0, 0) ; 63 ADC d,s
db opcode_clocks(2, 0, 1, 0, 0) ; 64 STZ d
db opcode_clocks(2, 0, 1, 0, 0) ; 65 ADC d
db opcode_clocks(2, 1, 2, 0, 0) ; 66 ROR d
db opcode_clocks(2, 0, 3, 1, 0) ; 67 ADC [d]
								
db opcode_clocks(1, 2, 1, 0, 0) ; 68 PLA
db opcode_clocks(2, 0, 0, 0, 0) ; 69 ADC i
db opcode_clocks(1, 1, 0, 0, 0) ; 6A RRA
db opcode_clocks(1, 2, 3, 0, 0) ; 6B RTL
db opcode_clocks(3, 0, 2, 0, 0) ; 6C JMP (a)
db opcode_clocks(3, 0, 0, 1, 0) ; 6D ADC a
db opcode_clocks(3, 1, 0, 2, 0) ; 6E ROR a
db opcode_clocks(4, 0, 0, 1, 0) ; 6F ADC al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 70 BVS r
db opcode_clocks(2, 0, 2, 1, 0) ; 71 ADC (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 72 ADC (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 73 ADC (d,s),y
db opcode_clocks(2, 1, 1, 0, 0) ; 74 STZ d,x
db opcode_clocks(2, 1, 1, 0, 0) ; 75 ADC d,x
db opcode_clocks(2, 2, 2, 0, 0) ; 76 ROR d,x
db opcode_clocks(2, 0, 3, 1, 0) ; 77 ADC [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 78 SEI
db opcode_clocks(3, 0, 0, 1, 0) ; 79 ADC a,y
db opcode_clocks(1, 2, 1, 0, 0) ; 7A PLY
db opcode_clocks(1, 1, 0, 0, 0) ; 7B TDC
db opcode_clocks(3, 1, 0, 2, 0) ; 7C JMP (a,x) - bus access in PB
db opcode_clocks(3, 0, 0, 1, 0) ; 7D ADC a,x
db opcode_clocks(3, 2, 0, 2, 0) ; 7E ROR a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 7F ADC al,x
								
db opcode_clocks(2, 0, 0, 0, 0) ; 80 BRA r
db opcode_clocks(2, 1, 2, 1, 0) ; 81 STA (d,x)
db opcode_clocks(3, 1, 0, 0, 0) ; 82 BRL rl
db opcode_clocks(2, 1, 1, 0, 0) ; 83 STA d,s
db opcode_clocks(2, 0, 1, 0, 0) ; 84 STY d
db opcode_clocks(2, 0, 1, 0, 0) ; 85 STA d
db opcode_clocks(2, 0, 1, 0, 0) ; 86 STX d
db opcode_clocks(2, 0, 3, 1, 0) ; 87 STA [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; 88 DEY
db opcode_clocks(2, 0, 0, 0, 0) ; 89 BIT i
db opcode_clocks(1, 1, 0, 0, 0) ; 8A TXA
db opcode_clocks(1, 1, 1, 0, 0) ; 8B PHB
db opcode_clocks(3, 0, 0, 1, 0) ; 8C STY a
db opcode_clocks(3, 0, 0, 1, 0) ; 8D STA a
db opcode_clocks(3, 0, 0, 1, 0) ; 8E STX a
db opcode_clocks(4, 0, 0, 1, 0) ; 8F STA al
								
db opcode_clocks(2, 0, 0, 0, 0) ; 90 BCC r
db opcode_clocks(2, 1, 2, 1, 0) ; 91 STA (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; 92 STA (d)
db opcode_clocks(2, 2, 2, 1, 0) ; 93 STA (d,s),y
db opcode_clocks(2, 1, 1, 0, 0) ; 94 STY d,x
db opcode_clocks(2, 1, 1, 0, 0) ; 95 STA d,x
db opcode_clocks(2, 1, 1, 0, 0) ; 96 STX d,y
db opcode_clocks(2, 0, 3, 1, 0) ; 97 STA [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; 98 TYA
db opcode_clocks(3, 1, 0, 1, 0) ; 99 STA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; 9A TXS
db opcode_clocks(1, 1, 0, 0, 0) ; 9B TXY
db opcode_clocks(3, 0, 0, 1, 0) ; 9C STZ a
db opcode_clocks(3, 1, 0, 1, 0) ; 9D STA a,x
db opcode_clocks(3, 1, 0, 1, 0) ; 9E STZ a,x
db opcode_clocks(4, 0, 0, 1, 0) ; 9F STA al,x
								
db opcode_clocks(2, 0, 0, 0, 0) ; A0 LDY i
db opcode_clocks(2, 1, 2, 1, 0) ; A1 LDA (d,x)
db opcode_clocks(2, 0, 0, 0, 0) ; A2 LDX i
db opcode_clocks(2, 1, 1, 0, 0) ; A3 LDA d,s
db opcode_clocks(2, 0, 1, 0, 0) ; A4 LDY d
db opcode_clocks(2, 0, 1, 0, 0) ; A5 LDA d
db opcode_clocks(2, 0, 1, 0, 0) ; A6 LDX d
db opcode_clocks(2, 0, 3, 1, 0) ; A7 LDA [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; A8 TAY
db opcode_clocks(2, 0, 0, 0, 0) ; A9 LDA i
db opcode_clocks(1, 1, 0, 0, 0) ; AA TAX
db opcode_clocks(1, 2, 1, 0, 0) ; AB PLB
db opcode_clocks(3, 0, 0, 1, 0) ; AC LDY a
db opcode_clocks(3, 0, 0, 1, 0) ; AD LDA a
db opcode_clocks(3, 0, 0, 1, 0) ; AE LDX a
db opcode_clocks(4, 0, 0, 1, 0) ; AF LDA al
								
db opcode_clocks(2, 0, 0, 0, 0) ; B0 BCS r
db opcode_clocks(2, 0, 2, 1, 0) ; B1 LDA (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; B2 LDA (d)
db opcode_clocks(2, 2, 2, 1, 0) ; B3 LDA (d,s),y
db opcode_clocks(2, 1, 1, 0, 0) ; B4 LDY d,x
db opcode_clocks(2, 1, 1, 0, 0) ; B5 LDA d,x
db opcode_clocks(2, 1, 1, 0, 0) ; B6 LDX d,y
db opcode_clocks(2, 0, 3, 1, 0) ; B7 LDA [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; B8 CLV
db opcode_clocks(3, 0, 0, 1, 0) ; B9 LDA a,y
db opcode_clocks(1, 1, 0, 0, 0) ; BA TSX
db opcode_clocks(1, 1, 0, 0, 0) ; BB TYX
db opcode_clocks(3, 0, 0, 1, 0) ; BC LDY a,x
db opcode_clocks(3, 0, 0, 1, 0) ; BD LDA a,x
db opcode_clocks(3, 0, 0, 1, 0) ; BE LDX a,y
db opcode_clocks(4, 0, 0, 1, 0) ; BF LDA al,x
								
db opcode_clocks(2, 0, 0, 0, 0) ; C0 CPY i
db opcode_clocks(2, 1, 2, 1, 0) ; C1 CMP (d,x)
db opcode_clocks(2, 1, 0, 0, 0) ; C2 REP i
db opcode_clocks(2, 1, 1, 0, 0) ; C3 CMP d,s
db opcode_clocks(2, 0, 1, 0, 0) ; C4 CPY d
db opcode_clocks(2, 0, 1, 0, 0) ; C5 CMP d
db opcode_clocks(2, 1, 2, 0, 0) ; C6 DEC d
db opcode_clocks(2, 0, 3, 1, 0) ; C7 CMP [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; C8 INY
db opcode_clocks(2, 0, 0, 0, 0) ; C9 CMP i
db opcode_clocks(1, 1, 0, 0, 0) ; CA DEX
db opcode_clocks(1, 2, 0, 0, 0) ; CB WAI
db opcode_clocks(3, 0, 0, 1, 0) ; CC CPY a
db opcode_clocks(3, 0, 0, 1, 0) ; CD CMP a
db opcode_clocks(3, 1, 0, 2, 0) ; CE DEC a
db opcode_clocks(4, 0, 0, 1, 0) ; CF CMP al
								
db opcode_clocks(2, 0, 0, 0, 0) ; D0 BNE r
db opcode_clocks(2, 0, 2, 1, 0) ; D1 CMP (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; D2 CMP (d)
db opcode_clocks(2, 2, 2, 1, 0) ; D3 CMP (d,s),y
db opcode_clocks(2, 0, 4, 0, 0) ; D4 PEI
db opcode_clocks(2, 1, 1, 0, 0) ; D5 CMP d,x
db opcode_clocks(2, 2, 2, 0, 0) ; D6 DEC d,x
db opcode_clocks(2, 0, 3, 1, 0) ; D7 CMP [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; D8 CLD
db opcode_clocks(3, 0, 0, 1, 0) ; D9 CMP a,y
db opcode_clocks(1, 1, 1, 0, 0) ; DA PHX
db opcode_clocks(1, 2, 0, 0, 0) ; DB STP *
db opcode_clocks(3, 0, 3, 0, 0) ; DC JML (a)
db opcode_clocks(3, 0, 0, 1, 0) ; DD CMP a,x
db opcode_clocks(3, 2, 0, 2, 0) ; DE DEC a,x
db opcode_clocks(4, 0, 0, 1, 0) ; DF CMP al,x
								
db opcode_clocks(2, 0, 0, 0, 0) ; E0 CPX i
db opcode_clocks(2, 1, 2, 1, 0) ; E1 SBC (d,x)
db opcode_clocks(2, 1, 0, 0, 0) ; E2 SEP i
db opcode_clocks(2, 1, 1, 0, 0) ; E3 SBC d,s
db opcode_clocks(2, 0, 1, 0, 0) ; E4 CPX d
db opcode_clocks(2, 0, 1, 0, 0) ; E5 SBC d
db opcode_clocks(2, 1, 2, 0, 0) ; E6 INC d
db opcode_clocks(2, 0, 3, 1, 0) ; E7 SBC [d]
								
db opcode_clocks(1, 1, 0, 0, 0) ; E8 INX
db opcode_clocks(2, 0, 0, 0, 0) ; E9 SBC i
db opcode_clocks(1, 1, 0, 0, 0) ; EA NOP
db opcode_clocks(1, 2, 0, 0, 0) ; EB XBA
db opcode_clocks(3, 0, 0, 1, 0) ; EC CPX a
db opcode_clocks(3, 0, 0, 1, 0) ; ED SBC a
db opcode_clocks(3, 1, 0, 2, 0) ; EE INC a
db opcode_clocks(4, 0, 0, 1, 0) ; EF SBC al
								
db opcode_clocks(2, 0, 0, 0, 0) ; F0 BEQ r
db opcode_clocks(2, 0, 2, 1, 0) ; F1 SBC (d),y
db opcode_clocks(2, 0, 2, 1, 0) ; F2 SBC (d)
db opcode_clocks(2, 2, 2, 1, 0) ; F3 SBC (d,s),y
db opcode_clocks(3, 0, 2, 0, 0) ; F4 PEA
db opcode_clocks(2, 1, 1, 0, 0) ; F5 SBC d,x
db opcode_clocks(2, 2, 2, 0, 0) ; F6 INC d,x
db opcode_clocks(2, 0, 3, 1, 0) ; F7 SBC [d],y
								
db opcode_clocks(1, 1, 0, 0, 0) ; F8 SED
db opcode_clocks(3, 0, 0, 1, 0) ; F9 SBC a,y
db opcode_clocks(1, 2, 1, 0, 0) ; FA PLX
db opcode_clocks(1, 1, 0, 0, 0) ; FB XCE
db opcode_clocks(3, 1, 2, 2, 0) ; FC JSR (a,x) - bus access in PB
db opcode_clocks(3, 0, 0, 1, 0) ; FD SBC a,x
db opcode_clocks(3, 2, 0, 2, 0) ; FE INC a,x
db opcode_clocks(4, 0, 0, 1, 0) ; FF SBC al,x

; FastROM
db opcode_clocks(2, 0, 5, 0, 1) ; 00 BRK
db opcode_clocks(2, 1, 2, 1, 1) ; 01 ORA (d,x)
db opcode_clocks(2, 0, 5, 0, 1) ; 02 COP
db opcode_clocks(2, 1, 1, 0, 1) ; 03 ORA d,s
db opcode_clocks(2, 1, 2, 0, 1) ; 04 TSB d
db opcode_clocks(2, 0, 1, 0, 1) ; 05 ORA d
db opcode_clocks(2, 1, 2, 0, 1) ; 06 ASL d
db opcode_clocks(2, 0, 3, 1, 1) ; 07 ORA [d]
								
db opcode_clocks(1, 1, 1, 0, 1) ; 08 PHP
db opcode_clocks(2, 0, 0, 0, 1) ; 09 ORA i
db opcode_clocks(1, 1, 0, 0, 1) ; 0A SLA
db opcode_clocks(1, 1, 2, 0, 1) ; 0B PHD
db opcode_clocks(3, 1, 0, 2, 1) ; 0C TSB a
db opcode_clocks(3, 0, 0, 1, 1) ; 0D ORA a
db opcode_clocks(3, 1, 0, 2, 1) ; 0E ASL a
db opcode_clocks(4, 0, 0, 1, 1) ; 0F ORA al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 10 BPL r
db opcode_clocks(2, 0, 2, 1, 1) ; 11 ORA (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 12 ORA (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 13 ORA (d,s),y
db opcode_clocks(2, 1, 2, 0, 1) ; 14 TRB d
db opcode_clocks(2, 1, 1, 0, 1) ; 15 ORA d,x
db opcode_clocks(2, 2, 2, 0, 1) ; 16 ASL d,x
db opcode_clocks(2, 0, 3, 1, 1) ; 17 ORA [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 18 CLC
db opcode_clocks(3, 0, 0, 1, 1) ; 19 ORA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 1A INA
db opcode_clocks(1, 1, 0, 0, 1) ; 1B TCS
db opcode_clocks(3, 1, 0, 2, 1) ; 1C TRB a
db opcode_clocks(3, 0, 0, 1, 1) ; 1D ORA a,x
db opcode_clocks(3, 2, 0, 2, 1) ; 1E ASL a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 1F ORA al,x
								
db opcode_clocks(3, 1, 2, 0, 1) ; 20 JSR a
db opcode_clocks(2, 1, 2, 1, 1) ; 21 AND (d,x)
db opcode_clocks(4, 1, 3, 0, 1) ; 22 JSL al
db opcode_clocks(2, 1, 1, 0, 1) ; 23 AND d,s
db opcode_clocks(2, 0, 1, 0, 1) ; 24 BIT d
db opcode_clocks(2, 0, 1, 0, 1) ; 25 AND d
db opcode_clocks(2, 1, 2, 0, 1) ; 26 ROL d
db opcode_clocks(2, 0, 3, 1, 1) ; 27 AND [d]
								
db opcode_clocks(1, 2, 1, 0, 1) ; 28 PLP
db opcode_clocks(2, 0, 0, 0, 1) ; 29 AND i
db opcode_clocks(1, 1, 0, 0, 1) ; 2A RLA
db opcode_clocks(1, 2, 2, 0, 1) ; 2B PLD
db opcode_clocks(3, 0, 0, 1, 1) ; 2C BIT a
db opcode_clocks(3, 0, 0, 1, 1) ; 2D AND a
db opcode_clocks(3, 1, 0, 2, 1) ; 2E ROL a
db opcode_clocks(4, 0, 0, 1, 1) ; 2F AND al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 30 BMI r
db opcode_clocks(2, 0, 2, 1, 1) ; 31 AND (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 32 AND (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 33 AND (d,s),y
db opcode_clocks(2, 1, 1, 0, 1) ; 34 BIT d,x
db opcode_clocks(2, 1, 1, 0, 1) ; 35 AND d,x
db opcode_clocks(2, 2, 2, 0, 1) ; 36 ROL d,x
db opcode_clocks(2, 0, 3, 1, 1) ; 37 AND [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 38 SEC
db opcode_clocks(3, 0, 0, 1, 1) ; 39 AND a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 3A DEA
db opcode_clocks(1, 1, 0, 0, 1) ; 3B TSC
db opcode_clocks(3, 0, 0, 1, 1) ; 3C BIT a,x
db opcode_clocks(3, 0, 0, 1, 1) ; 3D AND a,x
db opcode_clocks(3, 2, 0, 2, 1) ; 3E ROL a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 3F AND al,x
								
db opcode_clocks(1, 2, 3, 0, 1) ; 40 RTI
db opcode_clocks(2, 1, 2, 1, 1) ; 41 EOR (d,x)
db opcode_clocks(2, 0, 0, 0, 1) ; 42 WDM *
db opcode_clocks(2, 1, 1, 0, 1) ; 43 EOR d,s
db opcode_clocks(3, 2, 0, 2, 1) ; 44 MVP
db opcode_clocks(2, 0, 1, 0, 1) ; 45 EOR d
db opcode_clocks(2, 1, 2, 0, 1) ; 46 LSR d
db opcode_clocks(2, 0, 3, 1, 1) ; 47 EOR [d]
								
db opcode_clocks(1, 1, 1, 0, 1) ; 48 PHA
db opcode_clocks(2, 0, 0, 0, 1) ; 49 EOR i
db opcode_clocks(1, 1, 0, 0, 1) ; 4A SRA
db opcode_clocks(1, 1, 1, 0, 1) ; 4B PHK
db opcode_clocks(3, 0, 0, 0, 1) ; 4C JMP a
db opcode_clocks(3, 0, 0, 1, 1) ; 4D EOR a
db opcode_clocks(3, 1, 0, 2, 1) ; 4E LSR a
db opcode_clocks(4, 0, 0, 1, 1) ; 4F EOR al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 50 BVC r
db opcode_clocks(2, 0, 2, 1, 1) ; 51 EOR (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 52 EOR (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 53 EOR (d,s),y
db opcode_clocks(3, 2, 0, 2, 1) ; 54 MVN
db opcode_clocks(2, 1, 1, 0, 1) ; 55 EOR d,x
db opcode_clocks(2, 2, 2, 0, 1) ; 56 LSR d,x
db opcode_clocks(2, 0, 3, 1, 1) ; 57 EOR [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 58 CLI
db opcode_clocks(3, 0, 0, 1, 1) ; 59 EOR a,y
db opcode_clocks(1, 1, 1, 0, 1) ; 5A PHY
db opcode_clocks(1, 1, 0, 0, 1) ; 5B TCD
db opcode_clocks(4, 0, 0, 0, 1) ; 5C JML al
db opcode_clocks(3, 0, 0, 1, 1) ; 5D EOR a,x
db opcode_clocks(3, 2, 0, 2, 1) ; 5E LSR a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 5F EOR al,x
								
db opcode_clocks(1, 3, 2, 0, 1) ; 60 RTS
db opcode_clocks(2, 1, 2, 1, 1) ; 61 ADC (d,x)
db opcode_clocks(3, 1, 2, 0, 1) ; 62 PER
db opcode_clocks(2, 1, 1, 0, 1) ; 63 ADC d,s
db opcode_clocks(2, 0, 1, 0, 1) ; 64 STZ d
db opcode_clocks(2, 0, 1, 0, 1) ; 65 ADC d
db opcode_clocks(2, 1, 2, 0, 1) ; 66 ROR d
db opcode_clocks(2, 0, 3, 1, 1) ; 67 ADC [d]
								
db opcode_clocks(1, 2, 1, 0, 1) ; 68 PLA
db opcode_clocks(2, 0, 0, 0, 1) ; 69 ADC i
db opcode_clocks(1, 1, 0, 0, 1) ; 6A RRA
db opcode_clocks(1, 2, 3, 0, 1) ; 6B RTL
db opcode_clocks(3, 0, 2, 0, 1) ; 6C JMP (a)
db opcode_clocks(3, 0, 0, 1, 1) ; 6D ADC a
db opcode_clocks(3, 1, 0, 2, 1) ; 6E ROR a
db opcode_clocks(4, 0, 0, 1, 1) ; 6F ADC al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 70 BVS r
db opcode_clocks(2, 0, 2, 1, 1) ; 71 ADC (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 72 ADC (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 73 ADC (d,s),y
db opcode_clocks(2, 1, 1, 0, 1) ; 74 STZ d,x
db opcode_clocks(2, 1, 1, 0, 1) ; 75 ADC d,x
db opcode_clocks(2, 2, 2, 0, 1) ; 76 ROR d,x
db opcode_clocks(2, 0, 3, 1, 1) ; 77 ADC [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 78 SEI
db opcode_clocks(3, 0, 0, 1, 1) ; 79 ADC a,y
db opcode_clocks(1, 2, 1, 0, 1) ; 7A PLY
db opcode_clocks(1, 1, 0, 0, 1) ; 7B TDC
db opcode_clocks(3, 1, 0, 2, 1) ; 7C JMP (a,x) - bus access in PB
db opcode_clocks(3, 0, 0, 1, 1) ; 7D ADC a,x
db opcode_clocks(3, 2, 0, 2, 1) ; 7E ROR a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 7F ADC al,x
								
db opcode_clocks(2, 0, 0, 0, 1) ; 80 BRA r
db opcode_clocks(2, 1, 2, 1, 1) ; 81 STA (d,x)
db opcode_clocks(3, 1, 0, 0, 1) ; 82 BRL rl
db opcode_clocks(2, 1, 1, 0, 1) ; 83 STA d,s
db opcode_clocks(2, 0, 1, 0, 1) ; 84 STY d
db opcode_clocks(2, 0, 1, 0, 1) ; 85 STA d
db opcode_clocks(2, 0, 1, 0, 1) ; 86 STX d
db opcode_clocks(2, 0, 3, 1, 1) ; 87 STA [d]
								
db opcode_clocks(1, 1, 0, 0, 1) ; 88 DEY
db opcode_clocks(2, 0, 0, 0, 1) ; 89 BIT i
db opcode_clocks(1, 1, 0, 0, 1) ; 8A TXA
db opcode_clocks(1, 1, 1, 0, 1) ; 8B PHB
db opcode_clocks(3, 0, 0, 1, 1) ; 8C STY a
db opcode_clocks(3, 0, 0, 1, 1) ; 8D STA a
db opcode_clocks(3, 0, 0, 1, 1) ; 8E STX a
db opcode_clocks(4, 0, 0, 1, 1) ; 8F STA al
								
db opcode_clocks(2, 0, 0, 0, 1) ; 90 BCC r
db opcode_clocks(2, 1, 2, 1, 1) ; 91 STA (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; 92 STA (d)
db opcode_clocks(2, 2, 2, 1, 1) ; 93 STA (d,s),y
db opcode_clocks(2, 1, 1, 0, 1) ; 94 STY d,x
db opcode_clocks(2, 1, 1, 0, 1) ; 95 STA d,x
db opcode_clocks(2, 1, 1, 0, 1) ; 96 STX d,y
db opcode_clocks(2, 0, 3, 1, 1) ; 97 STA [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; 98 TYA
db opcode_clocks(3, 1, 0, 1, 1) ; 99 STA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; 9A TXS
db opcode_clocks(1, 1, 0, 0, 1) ; 9B TXY
db opcode_clocks(3, 0, 0, 1, 1) ; 9C STZ a
db opcode_clocks(3, 1, 0, 1, 1) ; 9D STA a,x
db opcode_clocks(3, 1, 0, 1, 1) ; 9E STZ a,x
db opcode_clocks(4, 0, 0, 1, 1) ; 9F STA al,x
								
db opcode_clocks(2, 0, 0, 0, 1) ; A0 LDY i
db opcode_clocks(2, 1, 2, 1, 1) ; A1 LDA (d,x)
db opcode_clocks(2, 0, 0, 0, 1) ; A2 LDX i
db opcode_clocks(2, 1, 1, 0, 1) ; A3 LDA d,s
db opcode_clocks(2, 0, 1, 0, 1) ; A4 LDY d
db opcode_clocks(2, 0, 1, 0, 1) ; A5 LDA d
db opcode_clocks(2, 0, 1, 0, 1) ; A6 LDX d
db opcode_clocks(2, 0, 3, 1, 1) ; A7 LDA [d]
								
db opcode_clocks(1, 1, 0, 0, 1) ; A8 TAY
db opcode_clocks(2, 0, 0, 0, 1) ; A9 LDA i
db opcode_clocks(1, 1, 0, 0, 1) ; AA TAX
db opcode_clocks(1, 2, 1, 0, 1) ; AB PLB
db opcode_clocks(3, 0, 0, 1, 1) ; AC LDY a
db opcode_clocks(3, 0, 0, 1, 1) ; AD LDA a
db opcode_clocks(3, 0, 0, 1, 1) ; AE LDX a
db opcode_clocks(4, 0, 0, 1, 1) ; AF LDA al
								
db opcode_clocks(2, 0, 0, 0, 1) ; B0 BCS r
db opcode_clocks(2, 0, 2, 1, 1) ; B1 LDA (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; B2 LDA (d)
db opcode_clocks(2, 2, 2, 1, 1) ; B3 LDA (d,s),y
db opcode_clocks(2, 1, 1, 0, 1) ; B4 LDY d,x
db opcode_clocks(2, 1, 1, 0, 1) ; B5 LDA d,x
db opcode_clocks(2, 1, 1, 0, 1) ; B6 LDX d,y
db opcode_clocks(2, 0, 3, 1, 1) ; B7 LDA [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; B8 CLV
db opcode_clocks(3, 0, 0, 1, 1) ; B9 LDA a,y
db opcode_clocks(1, 1, 0, 0, 1) ; BA TSX
db opcode_clocks(1, 1, 0, 0, 1) ; BB TYX
db opcode_clocks(3, 0, 0, 1, 1) ; BC LDY a,x
db opcode_clocks(3, 0, 0, 1, 1) ; BD LDA a,x
db opcode_clocks(3, 0, 0, 1, 1) ; BE LDX a,y
db opcode_clocks(4, 0, 0, 1, 1) ; BF LDA al,x
								
db opcode_clocks(2, 0, 0, 0, 1) ; C0 CPY i
db opcode_clocks(2, 1, 2, 1, 1) ; C1 CMP (d,x)
db opcode_clocks(2, 1, 0, 0, 1) ; C2 REP i
db opcode_clocks(2, 1, 1, 0, 1) ; C3 CMP d,s
db opcode_clocks(2, 0, 1, 0, 1) ; C4 CPY d
db opcode_clocks(2, 0, 1, 0, 1) ; C5 CMP d
db opcode_clocks(2, 1, 2, 0, 1) ; C6 DEC d
db opcode_clocks(2, 0, 3, 1, 1) ; C7 CMP [d]
								
db opcode_clocks(1, 1, 0, 0, 1) ; C8 INY
db opcode_clocks(2, 0, 0, 0, 1) ; C9 CMP i
db opcode_clocks(1, 1, 0, 0, 1) ; CA DEX
db opcode_clocks(1, 2, 0, 0, 1) ; CB WAI
db opcode_clocks(3, 0, 0, 1, 1) ; CC CPY a
db opcode_clocks(3, 0, 0, 1, 1) ; CD CMP a
db opcode_clocks(3, 1, 0, 2, 1) ; CE DEC a
db opcode_clocks(4, 0, 0, 1, 1) ; CF CMP al
								
db opcode_clocks(2, 0, 0, 0, 1) ; D0 BNE r
db opcode_clocks(2, 0, 2, 1, 1) ; D1 CMP (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; D2 CMP (d)
db opcode_clocks(2, 2, 2, 1, 1) ; D3 CMP (d,s),y
db opcode_clocks(2, 0, 4, 0, 1) ; D4 PEI
db opcode_clocks(2, 1, 1, 0, 1) ; D5 CMP d,x
db opcode_clocks(2, 2, 2, 0, 1) ; D6 DEC d,x
db opcode_clocks(2, 0, 3, 1, 1) ; D7 CMP [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; D8 CLD
db opcode_clocks(3, 0, 0, 1, 1) ; D9 CMP a,y
db opcode_clocks(1, 1, 1, 0, 1) ; DA PHX
db opcode_clocks(1, 2, 0, 0, 1) ; DB STP *
db opcode_clocks(3, 0, 3, 0, 1) ; DC JML (a)
db opcode_clocks(3, 0, 0, 1, 1) ; DD CMP a,x
db opcode_clocks(3, 2, 0, 2, 1) ; DE DEC a,x
db opcode_clocks(4, 0, 0, 1, 1) ; DF CMP al,x
								
db opcode_clocks(2, 0, 0, 0, 1) ; E0 CPX i
db opcode_clocks(2, 1, 2, 1, 1) ; E1 SBC (d,x)
db opcode_clocks(2, 1, 0, 0, 1) ; E2 SEP i
db opcode_clocks(2, 1, 1, 0, 1) ; E3 SBC d,s
db opcode_clocks(2, 0, 1, 0, 1) ; E4 CPX d
db opcode_clocks(2, 0, 1, 0, 1) ; E5 SBC d
db opcode_clocks(2, 1, 2, 0, 1) ; E6 INC d
db opcode_clocks(2, 0, 3, 1, 1) ; E7 SBC [d]
								
db opcode_clocks(1, 1, 0, 0, 1) ; E8 INX
db opcode_clocks(2, 0, 0, 0, 1) ; E9 SBC i
db opcode_clocks(1, 1, 0, 0, 1) ; EA NOP
db opcode_clocks(1, 2, 0, 0, 1) ; EB XBA
db opcode_clocks(3, 0, 0, 1, 1) ; EC CPX a
db opcode_clocks(3, 0, 0, 1, 1) ; ED SBC a
db opcode_clocks(3, 1, 0, 2, 1) ; EE INC a
db opcode_clocks(4, 0, 0, 1, 1) ; EF SBC al
								
db opcode_clocks(2, 0, 0, 0, 1) ; F0 BEQ r
db opcode_clocks(2, 0, 2, 1, 1) ; F1 SBC (d),y
db opcode_clocks(2, 0, 2, 1, 1) ; F2 SBC (d)
db opcode_clocks(2, 2, 2, 1, 1) ; F3 SBC (d,s),y
db opcode_clocks(3, 0, 2, 0, 1) ; F4 PEA
db opcode_clocks(2, 1, 1, 0, 1) ; F5 SBC d,x
db opcode_clocks(2, 2, 2, 0, 1) ; F6 INC d,x
db opcode_clocks(2, 0, 3, 1, 1) ; F7 SBC [d],y
								
db opcode_clocks(1, 1, 0, 0, 1) ; F8 SED
db opcode_clocks(3, 0, 0, 1, 1) ; F9 SBC a,y
db opcode_clocks(1, 2, 1, 0, 1) ; FA PLX
db opcode_clocks(1, 1, 0, 0, 1) ; FB XCE
db opcode_clocks(3, 1, 2, 2, 1) ; FC JSR (a,x) - bus access in PB
db opcode_clocks(3, 0, 0, 1, 1) ; FD SBC a,x
db opcode_clocks(3, 2, 0, 2, 1) ; FE INC a,x
db opcode_clocks(4, 0, 0, 1, 1) ; FF SBC al,x

ALIGND
CPU_OpTables:
dd OpTableE0
dd OpTablePm
dd OpTablePx
dd OpTableMX

%ifdef Abort_at_op_num
MaxOps:dd Abort_at_op_num
%endif
%ifdef SINGLE_STEP
_waitcount:dd 256*256*1024  ;14100
_debug:db 0
%endif

section .text
%macro OPCODE_EPILOG 0
%if 0
%ifndef ADD_CYCLES_FIRST
 pop ebx
;mov edx,B_EventTrip
 add R_Cycles,ebx   ; Update cycle counter
%else
;mov edx,B_EventTrip
%endif
 xor eax,eax        ; Zero for table offset

;cmp R_Cycles,edx
;jb near C_LABEL(CPU_START_NEXT)
;jmp near HANDLE_EVENT
 test R_Cycles,R_Cycles
 jl near C_LABEL(CPU_START_NEXT)
 jmp near HANDLE_EVENT

%else
;mov cl,0
 jmp near C_LABEL(CPU_RETURN)
%endif
%endmacro

;%1 = flag, %2 = wheretogo, %3 = distance
%macro JUMP_FLAG 2-3 short
%if %1 == SNES_FLAG_E
 mov ch,B_E_flag
 test ch,ch
 jnz %3 %2
%elif %1 == SNES_FLAG_N
 mov ch,B_N_flag
 test ch,ch
 js %3 %2
%elif %1 == SNES_FLAG_V
 mov ch,B_V_flag
 test ch,ch
 jnz %3 %2
%elif %1 == SNES_FLAG_M
 mov ch,B_M1_flag
 test ch,ch
 jnz %3 %2
%elif %1 == SNES_FLAG_X
 mov ch,B_XB_flag
 test ch,ch
 jnz %3 %2
%elif %1 == SNES_FLAG_D
 mov ch,B_D_flag
 test ch,ch
 jnz %3 %2
%elif %1 == SNES_FLAG_I
 mov ch,B_I_flag
 test ch,ch
 jnz %3 %2
%elif %1 == SNES_FLAG_Z
 mov ch,B_Z_flag
 test ch,ch
 jz %3 %2
%elif %1 == SNES_FLAG_C
 mov ch,B_C_flag
 test ch,ch
 jnz %3 %2
%else
%error Unhandled flag in JUMP_FLAG
%endif
%endmacro

;%1 = flag, %2 = wheretogo, %3 = distance
%macro JUMP_NOT_FLAG 2-3 short
%if %1 == SNES_FLAG_E
 mov ch,B_E_flag
 test ch,ch
 jz %3 %2
%elif %1 == SNES_FLAG_N
 mov ch,B_N_flag
 test ch,ch
 jns %3 %2
%elif %1 == SNES_FLAG_V
 mov ch,B_V_flag
 test ch,ch
 jz %3 %2
%elif %1 == SNES_FLAG_M
 mov ch,B_M1_flag
 test ch,ch
 jz %3 %2
%elif %1 == SNES_FLAG_X
 mov ch,B_XB_flag
 test ch,ch
 jz %3 %2
%elif %1 == SNES_FLAG_D
 mov ch,B_D_flag
 test ch,ch
 jz %3 %2
%elif %1 == SNES_FLAG_I
 mov ch,B_I_flag
 test ch,ch
 jz %3 %2
%elif %1 == SNES_FLAG_Z
 mov ch,B_Z_flag
 test ch,ch
 jnz %3 %2
%elif %1 == SNES_FLAG_C
 mov ch,B_C_flag
 test ch,ch
 jz %3 %2
%else
%error Unhandled flag in JUMP_NOT_FLAG
%endif
%endmacro

%macro STORE_FLAGS_E 1
 mov byte B_E_flag,%1
%endmacro

%macro STORE_FLAGS_N 1
 mov byte B_N_flag,%1
%endmacro

%macro STORE_FLAGS_V 1
 mov byte B_V_flag,%1
%endmacro

%macro STORE_FLAGS_M 1
 mov byte B_M1_flag,%1
%endmacro

%macro STORE_FLAGS_1 1
 mov byte B_M1_flag,%1
%endmacro

%macro STORE_FLAGS_X 1
 mov byte B_XB_flag,%1
%endmacro

%macro STORE_FLAGS_B 1
 mov byte B_XB_flag,%1
%endmacro

%macro STORE_FLAGS_D 1
 mov byte B_D_flag,%1
%endmacro

%macro STORE_FLAGS_I 1
 mov byte B_I_flag,%1
%endmacro

%macro STORE_FLAGS_Z 1
 mov byte B_Z_flag,%1
%endmacro

%macro STORE_FLAGS_C 1
 mov byte B_C_flag,%1
%endmacro

%macro STORE_FLAGS_NZ 1
 STORE_FLAGS_N %1
 STORE_FLAGS_Z %1
%endmacro

%macro STORE_FLAGS_NZC 2
 STORE_FLAGS_N %1
 STORE_FLAGS_Z %1
 STORE_FLAGS_C %2
%endmacro

; Load cycle counter to register R_Cycles
%macro LOAD_CYCLES 0
 mov eax,[C_LABEL(EventTrip)]
 mov dword R_Cycles,[C_LABEL(SNES_Cycles)]
 sub dword R_Cycles,eax
%endmacro

; Get cycle counter to register argument
%macro GET_CYCLES 1
 mov dword %1,[C_LABEL(EventTrip)]
 add dword %1,R_Cycles
%endmacro

; Save register R_Cycles to cycle counter
%macro SAVE_CYCLES 0
 GET_CYCLES eax
 mov [C_LABEL(SNES_Cycles)],eax
%endmacro

; Load base pointer to CPU register set
%macro LOAD_BASE 0
 mov dword R_Base,CPU_Register_Base
%endmacro

; Load register R_NativePC with pointer to code at PB:PC
%macro LOAD_PC 0
 mov dword R_NativePC,[C_LABEL(PBOffset)]
 add dword R_NativePC,[CPU_LABEL(PC)]
%endmacro

; Get PC from register R_NativePC
;%1 = with
%macro GET_PC 1
%ifnidn %1,R_NativePC
 mov dword %1,R_NativePC
%endif
 sub dword %1,[C_LABEL(PBOffset)]
%endmacro

; Save PC from register R_NativePC
;%1 = with
%macro SAVE_PC 1
 GET_PC %1
 mov dword [CPU_LABEL(PC)],%1
%endmacro

; Set up the flags from PC flag format to 65816 flag format
; Corrupts arg 1, returns value in arg 2 (default to cl, al)
;|E|N|V|M|X|D|I|Z|C|
;%1 = scratchpad, %2 = output
%macro E0_SETUPFLAGS 0-2 cl,al
;%macro Flags_Native_to_65c816_E0 0-2 cl,al
%ifdef WATCH_FLAG_BREAKS
 inc dword [C_LABEL(BreaksLast)]
%endif

 mov byte %2,B_N_flag
 shr byte %2,7

 mov byte %1,B_V_flag
 add byte %1,-1
 adc byte %2,%2

 mov byte %1,B_M1_flag
 add byte %1,-1
 adc byte %2,%2

 mov byte %1,B_XB_flag
 add byte %1,-1
 adc byte %2,%2

 mov byte %1,B_D_flag
 add byte %1,-1
 adc byte %2,%2

 mov byte %1,B_I_flag
 add byte %1,-1
 adc byte %2,%2

 mov byte %1,B_Z_flag
 cmp byte %1,1
 adc byte %2,%2

 mov byte %1,B_C_flag
 add byte %1,-1
 adc byte %2,%2
%endmacro

; Set up the flags from PC flag format to 65816 flag format
; Corrupts arg 2, returns value in arg 3 (default to cl, al)
;|E|N|V|1|B|D|I|Z|C|
;%1 = break flag, %2 = scratchpad, %3 = output
%macro E1_SETUPFLAGS 0-3 1,cl,al
;%macro Flags_Native_to_65c816_E0 0-3 1,cl,al
%ifdef WATCH_FLAG_BREAKS
 inc dword [C_LABEL(BreaksLast)]
%endif

 mov byte %3,B_N_flag
 shr byte %3,7

 mov byte %2,B_V_flag
 add byte %2,-1
 adc byte %3,%3

 mov byte %2,B_D_flag
 shl byte %3,byte 2
%if %1
 or byte %3,3
%else
 or byte %3,2
%endif

 add byte %2,-1
 adc byte %3,%3

 mov byte %2,B_I_flag
 add byte %2,-1
 adc byte %3,%3

 mov byte %2,B_Z_flag
 cmp byte %2,1
 adc byte %3,%3

 mov byte %2,B_C_flag
 add byte %2,-1
 adc byte %3,%3
%endmacro


;%macro Flags_65c816_to_Native_E0 0-1 R_P_B
; Restore the flags from 65c816 flag format to PC format
; Corrupts arg 1, uses value in arg 2 (default to cl, al)
;%1 = scratchpad, %2 = input
%macro E0_RESTOREFLAGS 0-2 cl,al
;%macro Flags_65c816_to_Native 0-2 cl,al
%ifdef WATCH_FLAG_BREAKS
 inc dword [C_LABEL(BreaksLast)]
%endif
 mov byte B_N_flag,%2   ;negative
 shl byte %2,2  ;start next (overflow)

 sbb byte %1,%1
 add byte %2,%2 ;start next (memory/accumulator size)
 mov byte B_V_flag,%1

 sbb byte %1,%1
 add byte %2,%2 ;start next (index size)
 mov byte B_M1_flag,%1

 sbb byte %1,%1
 add byte %2,%2 ;start next (decimal mode)
 mov byte B_XB_flag,%1

 sbb byte %1,%1
 add byte %2,%2 ;start next (interrupt disable)
 mov byte B_D_flag,%1

 sbb byte %1,%1
 add byte %2,%2 ;start next (zero)
 mov byte B_I_flag,%1

 sbb byte %1,%1
 xor byte %1,0xFF
 add byte %2,%2 ;start next (carry)
 mov byte B_Z_flag,%1

 sbb byte %1,%1
 mov byte B_C_flag,%1
%endmacro


;%macro Flags_65c816_to_Native_E1 0-1 R_P_B
; Restore the flags from 65c816 flag format to PC format
; Corrupts arg 1, uses value in arg 2 (default to cl, al)
;%1 = scratchpad, %2 = input
%macro E1_RESTOREFLAGS 0-2 cl,al
;%macro Flags_65c816_to_Native 0-2 cl,al
%ifdef WATCH_FLAG_BREAKS
 inc dword [C_LABEL(BreaksLast)]
%endif
 mov byte B_N_flag,%2   ;negative
 shl byte %2,2  ;start next (overflow)

 sbb byte %1,%1
 shl byte %2,3  ;start next (decimal mode)
 mov byte B_V_flag,%1

;mov byte B_M1_flag,1
;mov byte B_XB_flag,1

 sbb byte %1,%1
 add byte %2,%2 ;start next (interrupt disable)
 mov byte B_D_flag,%1

 sbb byte %1,%1
 add byte %2,%2 ;start next (zero)
 mov byte B_I_flag,%1

 sbb byte %1,%1
 xor byte %1,0xFF
 add byte %2,%2 ;start next (carry)
 mov byte B_Z_flag,%1

 sbb byte %1,%1
 mov byte B_C_flag,%1
%endmacro

; Set the current opcode execution and timing table pointers based
; on the M and X bits of flag register. This returns control to the
; execution loop, so it must be the last instruction
; Corrupts eax,ecx
%macro SET_TABLE_MX 0
 mov al,B_XB_flag
 mov cl,B_M1_flag
 add al,255
 sbb eax,eax
 add cl,255
 adc eax,eax
 and eax,byte 3
 JUMP_NOT_FLAG SNES_FLAG_X,%%index_16
 mov [CPU_LABEL(XH)],ah ; Clear XH/YH if X flag set
 mov [CPU_LABEL(YH)],ah
%%index_16:
 mov eax,[CPU_OpTables+eax*4]
 mov [OpTable],eax
 OPCODE_EPILOG
%endmacro

; Push/Pull macros assume eax contains value - corrupt ebx

%macro FAST_SET_BYTE_STACK_NATIVE_MODE 1
 cmp bh,0x20
 jnb %%not_within_wram
 mov byte [C_LABEL(WRAM)+ebx],%1
%%not_within_wram:
%endmacro

%macro FAST_GET_BYTE_STACK_NATIVE_MODE 1
 cmp bh,0x20
 jnb %%not_within_wram
 mov %1,byte [C_LABEL(WRAM)+ebx]
%%not_within_wram:
%endmacro

%macro FAST_SET_BYTE_STACK_EMULATION_MODE 1
 mov byte [C_LABEL(WRAM)+ebx],%1
%endmacro

%macro FAST_GET_BYTE_STACK_EMULATION_MODE 1
 mov %1,byte [C_LABEL(WRAM)+ebx]
%endmacro

; Native mode - push byte (S--)
%macro E0_PUSH_B 0
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
%ifdef FAST_STACK_ACCESS_NATIVE_MODE
 FAST_SET_BYTE_STACK_NATIVE_MODE al
%else
 SET_BYTE
%endif
 dec ebx        ; Postdecrement S
 mov [CPU_LABEL(S)],bx  ; Set stack pointer
%endmacro

; Emulation mode - push byte (SL--)
%macro E1_PUSH_B 0
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
 dec byte [CPU_LABEL(S)]    ; Postdecrement SL
%ifdef FAST_STACK_ACCESS_EMULATION_MODE
 FAST_SET_BYTE_STACK_EMULATION_MODE al
%else
 SET_BYTE
%endif
%endmacro

; Native mode - pull byte (++S)
%macro E0_PULL_B 0
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
 inc bx         ; Preincrement S
 mov [CPU_LABEL(S)],ebx ; Set stack pointer
%ifdef FAST_STACK_ACCESS_NATIVE_MODE
 FAST_GET_BYTE_STACK_NATIVE_MODE al
%else
 GET_BYTE
%endif
%endmacro

; Emulation mode - pull byte (++SL)
%macro E1_PULL_B 0
 inc byte [CPU_LABEL(S)]    ; Preincrement SL
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
%ifdef FAST_STACK_ACCESS_EMULATION_MODE
 FAST_GET_BYTE_STACK_EMULATION_MODE al
%else
 GET_BYTE
%endif
%endmacro

; Native mode - push word (S--)
%macro E0_PUSH_W 0
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
%ifdef FAST_STACK_ACCESS_NATIVE_MODE
 cmp bh,0x20
 jnb %%not_within_wram_hi
 mov byte [C_LABEL(WRAM)+ebx],ah
%%not_within_wram_hi:
%else
 push eax
 mov al,ah
 SET_BYTE
%endif
 dec bx         ; Postdecrement S
%ifdef FAST_STACK_ACCESS_NATIVE_MODE
 cmp bh,0x20
 jnb %%not_within_wram_lo
 mov byte [C_LABEL(WRAM)+ebx],al
%%not_within_wram_lo:
%else
 pop eax
 SET_BYTE
%endif
 dec bx         ; Postdecrement S
 mov [CPU_LABEL(S)],ebx ; Set stack pointer
%endmacro

;Emulation mode - push word (SL--)
; pass argument of 'New' for opcodes new to 16-bit 65xx
; (temporary address is 16-bit, but SH not changed after opcode)
%macro E1_PUSH_W 0-1 0
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
%ifdef FAST_STACK_ACCESS_EMULATION_MODE
 FAST_SET_BYTE_STACK_EMULATION_MODE ah
%else
 push eax
 mov al,ah
 SET_BYTE
%endif
%ifnidni %1,New
 dec bl         ; Postdecrement SL
%else
 dec bx         ; Postdecrement S
%endif
%ifdef FAST_STACK_ACCESS_EMULATION_MODE
 FAST_SET_BYTE_STACK_EMULATION_MODE al
%else
 pop eax
 SET_BYTE
%endif
 dec bl         ; Postdecrement SL
 mov [CPU_LABEL(S)],bl  ; Set stack pointer
%endmacro

; Native mode - pull word (++S)
%macro E0_PULL_W 0
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
 inc bx         ; Preincrement S
%ifdef FAST_STACK_ACCESS_NATIVE_MODE
 cmp bh,0x20
 jnb %%not_within_wram_lo
 mov al,byte [C_LABEL(WRAM)+ebx]
%%not_within_wram_lo:
%else
 GET_BYTE
 mov ah,al
%endif
 inc bx         ; Preincrement S
%ifdef FAST_STACK_ACCESS_NATIVE_MODE
 cmp bh,0x20
 jnb %%not_within_wram_hi
 mov ah,byte [C_LABEL(WRAM)+ebx]
%%not_within_wram_hi:
%else
 GET_BYTE
 ror ax,8
%endif
 mov [CPU_LABEL(S)],ebx ; Set stack pointer
%endmacro

;Emulation mode - pull word (++SL)
; pass argument of 'New' for opcodes new to 16-bit 65xx
; (temporary address is 16-bit, but SH not changed after opcode)
%macro E1_PULL_W 0-1 0
%ifnidni %1,New
 inc byte [CPU_LABEL(S)]    ; Preincrement SL
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
%else
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
 inc bx                 ; Preincrement S
%endif
%ifdef FAST_STACK_ACCESS_EMULATION_MODE
 FAST_GET_BYTE_STACK_EMULATION_MODE al
%else
 GET_BYTE
 mov ah,al
%endif
%ifnidni %1,New
 inc byte [CPU_LABEL(S)]    ; Preincrement SL
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
%else
 inc bx                 ; Preincrement S
 mov [CPU_LABEL(S)],bl  ; Update SL
%endif
%ifdef FAST_STACK_ACCESS_EMULATION_MODE
 FAST_GET_BYTE_STACK_EMULATION_MODE ah
%else
 GET_BYTE
 ror ax,8
%endif
%endmacro

; Requires current scanline to be in %eax
%macro CheckVIRQ 0
 mov bl,[C_LABEL(NMITIMEN)]
 mov edx,[FixedTrip]

 test bl,0x30       ; IRQ enabled?
 jz %%no_irq

 test bl,0x20       ; V-IRQ enabled?
 jz %%no_virq

 ; V-IRQ is enabled, are we on the right scanline?
;mov eax,[C_LABEL(Current_Line_Timing)]
 cmp [C_LABEL(VTIMEL)],eax
 jne %%no_irq

%%no_virq:
 ; If V-IRQ is enabled, we're on the correct scanline
 ; If it isn't enabled, H-IRQ must be enabled for us to be here

 ; If H-IRQ is disabled, H-position is start of scanline (0)
 xor edi,edi

 test bl,0x10       ; H-IRQ enabled?
 mov ebx,VIRQ_Event
 jz %%no_hirq

 mov edi,[HTimer]
 mov ebx,HIRQ_Event

%%no_hirq:
 cmp edx,edi
 jnb %%irq_before_next_event

%%no_irq:
 mov edi,edx
 mov ebx,[Fixed_Event]
%%irq_before_next_event:
 mov [C_LABEL(EventTrip)],edi
 mov [Event_Handler],ebx
%endmacro


ALIGNC
EXPORT_C Reset_CPU
 pusha

 call Reset_DMA

 ; Reset timing registers
 xor eax,eax
 mov [Latched_H],eax
 mov [Latched_V],eax
 mov [OPHCT],al
 mov [OPVCT],al
 mov byte [RDNMI],VERSION_NUMBER_5A22
 mov [MEMSEL],al
 mov [HVBJOY],al
 mov [C_LABEL(NMITIMEN)],al
 mov [C_LABEL(HTIMEL)],eax
 mov [C_LABEL(VTIMEL)],eax

 ; Reset bus speed
%ifndef NO_FASTROM
 mov byte [C_LABEL(CycleTable)],4
%endif

 ; Reset other registers
 mov byte [C_LABEL(WRIO)],0xFF
 mov byte [C_LABEL(RDIO)],0xFF
 mov [WRMPYA],al
 mov [WRDIVL],al
 mov [WRDIVH],al
 mov [RDDIVL],al
 mov [RDDIVH],al
 mov [RDMPYL],al
 mov [RDMPYH],al

 mov [JOYC1],al
 mov byte [C_LABEL(Controller1_Pos)],16
 mov byte [C_LABEL(Controller23_Pos)],16
 mov byte [C_LABEL(Controller45_Pos)],16
 mov dword [C_LABEL(JOY1L)],(1<<31)
 mov dword [C_LABEL(JOY2L)],(1<<31)
 mov dword [C_LABEL(JOY3L)],(1<<31)
 mov dword [C_LABEL(JOY4L)],(1<<31)

 ; Reset hardware ports
 call Reset_Ports

 ; Reset SPC timing
 xor eax,eax
 mov [SPC_last_cycles],eax
 mov [SPC_CPU_cycles],eax
 mov [SPC_cycles_left],eax
 mov [SPC_CPU_cycles_mul],eax

 ; Reset CPU
 mov [In_CPU],al
 mov [CPU_Execution_Mode],al ;CEM_Normal_Execution == 0
 mov dword [OpTable],OpTableE1  ; Set current opcode emulation table
;mov [C_LABEL(SNES_Cycles)SNES_Cycles],eax  ; Clear cycle counts
;mov R_Cycles,eax       ; Needed for IRQNewFrame later
 mov dword [C_LABEL(SNES_Cycles)],52    ; Clear cycle counts
 mov [CPU_LABEL(A)],eax ; Clear A, D, X, Y
 mov [CPU_LABEL(D)],eax
 mov [CPU_LABEL(X)],eax
 mov [CPU_LABEL(Y)],eax
 mov [CPU_LABEL(DB_Shifted)],eax    ; Clear bank registers
 mov [CPU_LABEL(PB_Shifted)],eax
 mov [C_LABEL(OLD_PB)],al

%ifdef DEBUG
 mov [C_LABEL(Frames)],eax
;mov [C_LABEL(Timer_Counter_FPS)],eax
%endif
 ; Initialize flags
 LOAD_BASE
;FLAGS_TO (SNES_FLAG_B1+SNES_FLAG_E+SNES_FLAG_I)
 STORE_FLAGS_E 1
 STORE_FLAGS_N 0
 STORE_FLAGS_V 0
 STORE_FLAGS_1 1
 STORE_FLAGS_B 1
 STORE_FLAGS_D 0
 STORE_FLAGS_I 1
 STORE_FLAGS_Z 1
 STORE_FLAGS_C 0
 mov dword [CPU_LABEL(S)],0x01FF

;%1 = vector; %2 = label prefix;
;%3 = register with relative address of ROM at 00:E000-FFFF
%macro cache_interrupt_vector 3
 movzx eax,word [%1+%3]     ; Get interrupt vector
 mov [C_LABEL(%2vector)],eax    ; Cache vector

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jnz %%read_direct

 mov eax,C_LABEL(Blank) ;we should really trap this...
%%read_direct:

 mov [C_LABEL(%2offset)],eax    ; Cache memory map offset
%endmacro

 ; Get all interrupt vectors
 mov ebx,[C_LABEL(Read_Bank8Offset)+(0xE000 >> 13) * 4] ; Get address of ROM

 cache_interrupt_vector 0xFFFC,RES_E,ebx    ; Reset: Emulation mode
 cache_interrupt_vector 0xFFEA,NMI_N,ebx    ; NMI: Native mode
 cache_interrupt_vector 0xFFFA,NMI_E,ebx    ; NMI: Emulation mode
 cache_interrupt_vector 0xFFEE,IRQ_N,ebx    ; IRQ: Native mode
 cache_interrupt_vector 0xFFFE,IRQ_E,ebx    ; IRQ: Emulation mode
 cache_interrupt_vector 0xFFE6,BRK_N,ebx    ; BRK: Native mode
 cache_interrupt_vector 0xFFE4,COP_N,ebx    ; COP: Native mode
 cache_interrupt_vector 0xFFF4,COP_E,ebx    ; COP: Emulation mode

 mov eax,[C_LABEL(RES_Evector)] ; Get Reset vector
 mov edx,[C_LABEL(RES_Eoffset)]
 mov [CPU_LABEL(PC)],eax    ; Setup PC
 mov [C_LABEL(PBOffset)],edx
 mov [C_LABEL(OLD_PC)],eax

 call IRQNewFrameReset

 popa
 ret

ALIGNC
EXPORT_C Do_CPU
 pusha
 mov byte [C_LABEL(PaletteChanged)],1   ; Make sure we get our palette
 mov dword [C_LABEL(Last_Frame_Line)],239
%ifdef SINGLE_STEP
EXTERN_C set_gfx_mode
 push byte 0
 push byte 0
 push byte 0
 push byte 0
 push byte -1
 call _set_gfx_mode
 add esp,20
%endif

 call CPU_START
 popa
 ret

; Start of actual CPU execution core

; New for 0.25 - one CPU execution loop, also used for SPC
ALIGNC
EXPORT CPU_START_IRQ
 CheckVIRQ  ; Check for Vertical IRQ
CPU_START:
 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jge .no_event_wait
 mov al,[CPU_Execution_Mode]
 test al,al
 jz .normal_execution
%if 1
 cmp al,CEM_Instruction_After_IRQ_Enable
 je .instruction_after_irq_enable
%endif
 xor R_Cycles,R_Cycles
;SAVE_CYCLES
 mov edx,[C_LABEL(EventTrip)]
 mov [C_LABEL(SNES_Cycles)],edx
.no_event_wait:
 jmp dword [Event_Handler]

ALIGNC
%if 1
.instruction_after_irq_enable:
;set up an event for immediately the next instruction
 mov eax,IRQ_Enabled_Event
 xor edx,edx
 mov [Event_Handler],eax
 mov [C_LABEL(EventTrip)],edx
%endif
.normal_execution:
 LOAD_PC
 LOAD_CYCLES
 LOAD_BASE
 xor eax,eax        ; Zero for table offset
 mov byte [In_CPU],-1

 jmp short C_LABEL(CPU_START_NEXT)

ALIGNC
EXPORT_C CPU_RETURN
%ifdef Abort_at_op_num
 dec dword [MaxOps]
 jz ALL_STP
%endif

%ifndef ADD_CYCLES_FIRST
 pop ebx
 xor eax,eax        ; Zero for table offset
 add R_Cycles,ebx   ; Update cycle counter
%else
 xor eax,eax        ; Zero for table offset
 test R_Cycles,R_Cycles
%endif

 jge HANDLE_EVENT

EXPORT_C CPU_START_NEXT
; This code is for a CPU-tracker dump... #define TRACKERS to make a dump
; of the CPU state before each instruction - uncomment the ret to
; force emulation core to break when buffer fills. TRACKERS must be
; defined to the size of the buffer to be used - which must be a power
; of two, and the variables required by this and the write in Wangle()
; (main.cc) exist only if DEBUG and TRACKERS are also defined in main.cc
; and romload.cc.
%ifdef TRACKERS
%if TRACKERS >= 16
 mov edx,[_LastIns]     ;
 add edx,[_InsAddress]  ;
 mov al,[CPU_LABEL(PB)] ;
 mov [edx],al           ;
 SAVE_CYCLES            ;
 SAVE_PC eax            ;
 mov [1+edx],ah         ;
 mov [2+edx],al         ;
 mov al,[CPU_LABEL(B)]  ;
 mov [3+edx],al         ;
 mov al,[CPU_LABEL(A)]  ;
 mov [4+edx],al         ;
 mov al,[CPU_LABEL(XH)] ;
 mov [5+edx],al         ;
 mov al,[CPU_LABEL(X)]  ;
 mov [6+edx],al         ;
 mov al,[CPU_LABEL(YH)] ;
 mov [7+edx],al         ;
 mov al,[CPU_LABEL(Y)]  ;
 mov [8+edx],al         ;
 mov al,[CPU_LABEL(SH)] ;
 mov [9+edx],al         ;
 mov al,[CPU_LABEL(SL)] ;
 mov [10+edx],al        ;
 mov al,[CPU_LABEL(DB)] ;
 mov [11+edx],al        ;
 mov al,[CPU_LABEL(DH)] ;
 mov [12+edx],al        ;
 mov al,[CPU_LABEL(DL)] ;
 mov [13+edx],al        ;
 mov al,[_E_flag]       ;
 mov [15+edx],al        ;
 test al,al             ;
 jnz .track_e1_flags    ;
 E0_SETUPFLAGS          ;
 jmp short .track_e0_flags  ;
.track_e1_flags:        ;
 E1_SETUPFLAGS          ;
.track_e0_flags:        ;
 mov [14+edx],al        ;
 mov edx,[_LastIns]     ;
 add edx,byte 16        ;
 and edx,(TRACKERS-1)   ;
 mov [_LastIns],edx     ;
 test edx,edx           ;
 jnz .buffer_not_full   ;
 ret                    ;
.buffer_not_full:       ;
 xor eax,eax            ;
%endif
%endif

%ifdef SINGLE_STEP
 cmp byte [_debug],0
 jnz .on
 dec dword [_waitcount]
 setz [_debug]
 jnz near .off
.on:
 pusha
 GET_PC edx
 mov al,B_PB
 mov [C_LABEL(OLD_PC)],edx
 mov [C_LABEL(OLD_PB)],al
 mov eax,[esi]
 bswap eax
 mov [C_LABEL(Map_Byte)],eax
 E0_SETUPFLAGS
 mov [_P],al
EXTERN_C DisplayStatus,readkey,keypressed
 call _DisplayStatus
.wait:
 call _keypressed
 test eax,eax
 jz .wait
 call _readkey
 popa
.off:
%endif
 mov al,[R_NativePC]    ; Get opcode
 mov edx,B_OpTable
 xor ebx,ebx

 ; Bus speed selected by modifying code
 mov bl,[0x400+edx+eax] ; SlowROM, timing * 8, FastROM, timing * 6
EXPORT_EQU_C CycleTable,$-3 ; Address of '04'

%ifndef ADD_CYCLES_FIRST
 push ebx
%else
 add R_Cycles,ebx   ; Update cycle counter
%endif

 jmp dword [edx+eax*4]  ; Call opcode handler

ALIGNC
HANDLE_EVENT:
 SAVE_PC R_NativePC

 mov byte [In_CPU],0

 SAVE_CYCLES
 jmp dword [Event_Handler]

EXPORT E1_IRQ
 ; Emulation mode IRQ
 mov eax,[CPU_LABEL(PC)]
 E1_PUSH_W
;CLR_FLAG SNES_FLAG_B   ; Clear break bit on stack
 E1_SETUPFLAGS 0        ; put flags into SNES packed flag format
;SET_FLAG SNES_FLAG_B
 E1_PUSH_B

 mov eax,[C_LABEL(IRQ_Evector)] ; Get Emulation mode IRQ vector
 mov ebx,[C_LABEL(IRQ_Eoffset)]

;7.12.2 In the Emulation mode, the PBR and DBR registers are cleared to 00
;when a hardware interrupt, BRK or COP is executed. In this case, previous
;contents of the PBR are not automatically saved.
 mov byte [CPU_LABEL(DB)],0

 jmp IRQ_completion

ALIGNC
EXPORT E0_IRQ
 ; Native mode IRQ
 mov al,[CPU_LABEL(PB)]
 E0_PUSH_B
 mov eax,[CPU_LABEL(PC)]
 E0_PUSH_W
 E0_SETUPFLAGS          ; put flags into SNES packed flag format
 E0_PUSH_B

 mov eax,[C_LABEL(IRQ_Nvector)] ; Get Native mode IRQ vector
 mov ebx,[C_LABEL(IRQ_Noffset)]
IRQ_completion:
 mov [CPU_LABEL(PC)],eax    ; Setup PC vector
 mov [C_LABEL(PBOffset)],ebx
 mov byte [CPU_LABEL(PB)],0 ; Setup bank
;SET_FLAG SNES_FLAG_I   ; Disable IRQs
 STORE_FLAGS_I 1
%ifndef NO_FASTROM
 mov byte [C_LABEL(CycleTable)],4   ; SlowROM bank
%endif
;CLR_FLAG SNES_FLAG_D   ; Disable decimal mode
 STORE_FLAGS_D 0
 ret

%include "cpu/cpuaddr.inc"  ; Addressing modes ([d], a,x, etc.)
%include "cpu/cpumacro.inc" ; Instructions (LDA,ADC,SBC,etc.)

EXPORT_C cpu_ops_start

ALIGNC
EXPORT_C ALL_INVALID
 GET_PC ebx
 mov [C_LABEL(Map_Address)],ebx
 mov bl,[CPU_LABEL(PB)]
 mov [C_LABEL(Map_Address) + 3],bl
 mov [C_LABEL(Map_Byte)],al
 jmp C_LABEL(InvalidOpcode) ; This exits...

%include "cpu/cpuops.inc"   ; Opcode handlers

%include "cpu/timing.inc"

section .text
ALIGNC
EXPORT_C CPU_text_end
section .data
ALIGND
EXPORT_C CPU_data_end
section .bss
ALIGNB
EXPORT_C CPU_bss_end
