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

; SNEeSe 65c816 CPU emulation core
; Originally written by Lee Hammerton in AT&T assembly
; Maintained/rewritten/ported to NASM by Charles Bilyue'
;
; Compile under NASM

; To do: move cycle addition into opcode handlers
;        improved bus speed selection

;CPU instruction tracker is broken!
;DO NOT UNCOMMENT THE FOLLOWING LINE!
;%define TRACKERS 1048576

%define VERSION_NUMBER_5A22 2

%define WAI_DELAY

;%define OPCODE_TRACE_LOG

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
%include "cpu/dma.inc"

EXTERN Map_Address,Map_Byte
EXTERN OLD_PB,OLD_PC
EXTERN RomAddress
EXTERN LastIns,InsAddress

EXTERN FRAME_SKIP_MIN,FRAME_SKIP_MAX,Timer_Counter_Throttle
EXTERN PaletteChanged
EXTERN BrightnessLevel
EXTERN Real_SNES_Palette,fixedpalettecheck,SetPalette
EXTERN ShowFPS,ShowBreaks
EXTERN Copy_Screen
EXTERN update_sound, update_sound_block

EXTERN SPC_ENABLED
EXTERN SPC_Cycles
EXTERN TotalCycles
EXTERN Wrap_SPC_Cyclecounter
EXTERN SPC_START

EXTERN SPC_CPU_cycle_divisor
EXTERN SPC_CPU_cycle_multiplicand

EXTERN InvalidOpcode,InvalidJump
EXTERN Invalidate_Tile_Caches
EXTERN Reset_CGRAM

%ifdef DEBUG
EXTERN Frames
;EXTERN Timer_Counter_FPS
%endif

section .text
EXPORT CPU_text_start
section .data
EXPORT CPU_data_start
section .bss
EXPORT CPU_bss_start

%define CPU_LABEL(x) cpu_65c816_ %+ x

%define R_Base      R_65c816_Base   ; Base pointer to register set
%define R_Cycles    R_65c816_Cycles ; Cycle counter
%define R_PBPC      R_65c816_PBPC
%define R_PC        R_65c816_PC

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
%define B_IRQ_Nvector       [R_Base-CPU_Register_Base+IRQ_Nvector]
%define B_NMI_Nvector       [R_Base-CPU_Register_Base+NMI_Nvector]
%define B_BRK_Nvector       [R_Base-CPU_Register_Base+BRK_Nvector]
%define B_COP_Nvector       [R_Base-CPU_Register_Base+COP_Nvector]
%define B_IRQ_Evector       [R_Base-CPU_Register_Base+IRQ_Evector]
%define B_NMI_Evector       [R_Base-CPU_Register_Base+NMI_Evector]
%define B_COP_Evector       [R_Base-CPU_Register_Base+COP_Evector]
%define B_RES_Evector       [R_Base-CPU_Register_Base+RES_Evector]
%define B_PB_Shifted        [R_Base-CPU_Register_Base+CPU_LABEL(PB_Shifted)]
%define B_PB                [R_Base-CPU_Register_Base+CPU_LABEL(PB)]
%define B_PC                [R_Base-CPU_Register_Base+CPU_LABEL(PC)]
%define B_P                 [R_Base-CPU_Register_Base+CPU_LABEL(P)]
%define B_SNES_Cycles       [R_Base-CPU_Register_Base+SNES_Cycles]
%define B_EventTrip         [R_Base-CPU_Register_Base+EventTrip]
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

EXPORT IRQ_Nvector,skipl
EXPORT IRQ_Noffset,skipl
EXPORT NMI_Nvector,skipl
EXPORT NMI_Noffset,skipl
EXPORT BRK_Nvector,skipl
EXPORT BRK_Noffset,skipl
EXPORT COP_Nvector,skipl
EXPORT COP_Noffset,skipl
EXPORT IRQ_Evector,skipl
EXPORT IRQ_Eoffset,skipl
EXPORT NMI_Evector,skipl
EXPORT NMI_Eoffset,skipl
EXPORT COP_Evector,skipl
EXPORT COP_Eoffset,skipl
EXPORT RES_Evector,skipl
EXPORT RES_Eoffset,skipl

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
EXPORT SNES_Cycles  ,skipl  ; Scanline cycle count for CPU (0-EventTrip)
EXPORT EventTrip    ,skipl  ; Cycle of next event on this scanline

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

;CPU is performing DMA transfer
%define CEM_In_DMA 2

;CPU is waiting for an interrupt after executing WAI opcode
%define CEM_Waiting_For_Interrupt 3
;CPU has stopped its clock after executing STP opcode
%define CEM_Clock_Stopped 4

EXPORT IRQ_pin      ,skipb
EXPORT _E_flag,skipb
EXPORT _Z_flag,skipb
EXPORT In_CPU,skipb         ; nonzero if CPU is executing

;NMI not raised
%define NMI_None 0
;NMI raised and acknowledged
%define NMI_Acknowledged 1
;NMI raised and not acknowledged
%define NMI_Raised 2

EXPORT NMI_pin      ,skipb
EXPORT FPS_ENABLED      ,skipb
_V_flag:skipb
EXPORT BREAKS_ENABLED   ,skipb

section .data

ALIGND
OpTableE0:
dd  OpE0_0x00    ,OpE0M0_0x01     ; 00
dd  OpE0_0x02    ,OpM0_0x03
dd  OpE0M0_0x04  ,OpE0M0_0x05
dd  OpE0M0_0x06  ,OpE0M0_0x07
dd  OpE0_0x08    ,OpM0_0x09
dd  OpM0_0x0A    ,OpE0_0x0B
dd  OpM0_0x0C    ,OpM0_0x0D
dd  OpM0_0x0E    ,OpM0_0x0F
dd  OpE0_0x10    ,OpE0M0X0_0x11   ; 10
dd  OpE0M0_0x12  ,OpM0_0x13
dd  OpE0M0_0x14  ,OpE0M0_0x15
dd  OpE0M0_0x16  ,OpE0M0_0x17
dd  Op_0x18      ,OpM0X0_0x19
dd  OpM0_0x1A    ,OpE0_0x1B
dd  OpM0_0x1C    ,OpM0X0_0x1D
dd  OpM0_0x1E    ,OpM0_0x1F
dd  OpE0_0x20    ,OpE0M0_0x21     ; 20
dd  OpE0_0x22    ,OpM0_0x23
dd  OpE0M0_0x24  ,OpE0M0_0x25
dd  OpE0M0_0x26  ,OpE0M0_0x27
dd  OpE0_0x28    ,OpM0_0x29
dd  OpM0_0x2A    ,OpE0_0x2B
dd  OpM0_0x2C    ,OpM0_0x2D
dd  OpM0_0x2E    ,OpM0_0x2F
dd  OpE0_0x30    ,OpE0M0X0_0x31   ; 30
dd  OpE0M0_0x32  ,OpM0_0x33
dd  OpE0M0_0x34  ,OpE0M0_0x35
dd  OpE0M0_0x36  ,OpE0M0_0x37
dd  Op_0x38      ,OpM0X0_0x39
dd  OpM0_0x3A    ,Op_0x3B
dd  OpM0X0_0x3C  ,OpM0X0_0x3D
dd  OpM0_0x3E    ,OpM0_0x3F
dd  OpE0_0x40    ,OpE0M0_0x41     ; 40
dd  ALL_INVALID  ,OpM0_0x43
dd  OpX0_0x44    ,OpE0M0_0x45
dd  OpE0M0_0x46  ,OpE0M0_0x47
dd  OpE0M0_0x48  ,OpM0_0x49
dd  OpM0_0x4A    ,OpE0_0x4B
dd  Op_0x4C      ,OpM0_0x4D
dd  OpM0_0x4E    ,OpM0_0x4F
dd  OpE0_0x50    ,OpE0M0X0_0x51   ; 50
dd  OpE0M0_0x52  ,OpM0_0x53
dd  OpX0_0x54    ,OpE0M0_0x55
dd  OpE0M0_0x56  ,OpE0M0_0x57
dd  Op_0x58      ,OpM0X0_0x59
dd  OpE0X0_0x5A  ,Op_0x5B
dd  Op_0x5C      ,OpM0X0_0x5D
dd  OpM0_0x5E    ,OpM0_0x5F
dd  OpE0_0x60    ,OpE0M0_0x61     ; 60
dd  OpE0_0x62    ,OpM0_0x63
dd  OpE0M0_0x64  ,OpE0M0_0x65
dd  OpE0M0_0x66  ,OpE0M0_0x67
dd  OpE0M0_0x68  ,OpM0_0x69
dd  OpM0_0x6A    ,OpE0_0x6B
dd  Op_0x6C      ,OpM0_0x6D
dd  OpM0_0x6E    ,OpM0_0x6F
dd  OpE0_0x70    ,OpE0M0X0_0x71   ; 70
dd  OpE0M0_0x72  ,OpM0_0x73
dd  OpE0M0_0x74  ,OpE0M0_0x75
dd  OpE0M0_0x76  ,OpE0M0_0x77
dd  Op_0x78      ,OpM0X0_0x79
dd  OpE0X0_0x7A  ,Op_0x7B
dd  Op_0x7C      ,OpM0X0_0x7D
dd  OpM0_0x7E    ,OpM0_0x7F
dd  OpE0_0x80    ,OpE0M0_0x81     ; 80
dd  Op_0x82      ,OpM0_0x83
dd  OpE0X0_0x84  ,OpE0M0_0x85
dd  OpE0X0_0x86  ,OpE0M0_0x87
dd  OpX0_0x88    ,OpM0_0x89
dd  OpM0_0x8A    ,OpE0_0x8B
dd  OpX0_0x8C    ,OpM0_0x8D
dd  OpX0_0x8E    ,OpM0_0x8F
dd  OpE0_0x90    ,OpE0M0X0_0x91   ; 90
dd  OpE0M0_0x92  ,OpM0_0x93
dd  OpE0X0_0x94  ,OpE0M0_0x95
dd  OpE0X0_0x96  ,OpE0M0_0x97
dd  OpM0_0x98    ,OpM0_0x99
dd  OpE0_0x9A    ,OpX0_0x9B
dd  OpM0_0x9C    ,OpM0_0x9D
dd  OpM0_0x9E    ,OpM0_0x9F
dd  OpX0_0xA0    ,OpE0M0_0xA1     ; A0
dd  OpX0_0xA2    ,OpM0_0xA3
dd  OpE0X0_0xA4  ,OpE0M0_0xA5
dd  OpE0X0_0xA6  ,OpE0M0_0xA7
dd  OpX0_0xA8    ,OpM0_0xA9
dd  OpX0_0xAA    ,OpE0_0xAB
dd  OpX0_0xAC    ,OpM0_0xAD
dd  OpX0_0xAE    ,OpM0_0xAF
dd  OpE0_0xB0    ,OpE0M0X0_0xB1   ; B0
dd  OpE0M0_0xB2  ,OpM0_0xB3
dd  OpE0X0_0xB4  ,OpE0M0_0xB5
dd  OpE0X0_0xB6  ,OpE0M0_0xB7
dd  Op_0xB8      ,OpM0X0_0xB9
dd  OpX0_0xBA    ,OpX0_0xBB
dd  OpX0_0xBC    ,OpM0X0_0xBD
dd  OpX0_0xBE    ,OpM0_0xBF
dd  OpX0_0xC0    ,OpE0M0_0xC1     ; C0
dd  OpE0_0xC2    ,OpM0_0xC3
dd  OpE0X0_0xC4  ,OpE0M0_0xC5
dd  OpE0M0_0xC6  ,OpE0M0_0xC7
dd  OpX0_0xC8    ,OpM0_0xC9
dd  OpX0_0xCA    ,Op_0xCB
dd  OpX0_0xCC    ,OpM0_0xCD
dd  OpM0_0xCE    ,OpM0_0xCF
dd  OpE0_0xD0    ,OpE0M0X0_0xD1   ; D0
dd  OpE0M0_0xD2  ,OpM0_0xD3
dd  OpE0_0xD4    ,OpE0M0_0xD5
dd  OpE0M0_0xD6  ,OpE0M0_0xD7
dd  Op_0xD8      ,OpM0X0_0xD9
dd  OpE0X0_0xDA  ,ALL_INVALID
dd  Op_0xDC      ,OpM0X0_0xDD
dd  OpM0_0xDE    ,OpM0_0xDF
dd  OpX0_0xE0    ,OpE0M0_0xE1     ; E0
dd  OpE0_0xE2    ,OpM0_0xE3
dd  OpE0X0_0xE4  ,OpE0M0_0xE5
dd  OpE0M0_0xE6  ,OpE0M0_0xE7
dd  OpX0_0xE8    ,OpM0_0xE9
dd  Op_0xEA      ,Op_0xEB
dd  OpX0_0xEC    ,OpM0_0xED
dd  OpM0_0xEE    ,OpM0_0xEF
dd  OpE0_0xF0    ,OpE0M0X0_0xF1   ; F0
dd  OpE0M0_0xF2  ,OpM0_0xF3
dd  OpE0_0xF4    ,OpE0M0_0xF5
dd  OpE0M0_0xF6  ,OpE0M0_0xF7
dd  Op_0xF8      ,OpM0X0_0xF9
dd  OpE0X0_0xFA  ,OpE0_0xFB
dd  OpE0_0xFC    ,OpM0X0_0xFD
dd  OpM0_0xFE    ,OpM0_0xFF

OpTablePm:
dd  OpE0_0x00    ,OpE0M1_0x01     ; 00
dd  OpE0_0x02    ,OpM1_0x03
dd  OpE0M1_0x04  ,OpE0M1_0x05
dd  OpE0M1_0x06  ,OpE0M1_0x07
dd  OpE0_0x08    ,OpM1_0x09
dd  OpM1_0x0A    ,OpE0_0x0B
dd  OpM1_0x0C    ,OpM1_0x0D
dd  OpM1_0x0E    ,OpM1_0x0F
dd  OpE0_0x10    ,OpE0M1X0_0x11   ; 10
dd  OpE0M1_0x12  ,OpM1_0x13
dd  OpE0M1_0x14  ,OpE0M1_0x15
dd  OpE0M1_0x16  ,OpE0M1_0x17
dd  Op_0x18      ,OpM1X0_0x19
dd  OpM1_0x1A    ,OpE0_0x1B
dd  OpM1_0x1C    ,OpM1X0_0x1D
dd  OpM1_0x1E    ,OpM1_0x1F
dd  OpE0_0x20    ,OpE0M1_0x21     ; 20
dd  OpE0_0x22    ,OpM1_0x23
dd  OpE0M1_0x24  ,OpE0M1_0x25
dd  OpE0M1_0x26  ,OpE0M1_0x27
dd  OpE0_0x28    ,OpM1_0x29
dd  OpM1_0x2A    ,OpE0_0x2B
dd  OpM1_0x2C    ,OpM1_0x2D
dd  OpM1_0x2E    ,OpM1_0x2F
dd  OpE0_0x30    ,OpE0M1X0_0x31   ; 30
dd  OpE0M1_0x32  ,OpM1_0x33
dd  OpE0M1_0x34  ,OpE0M1_0x35
dd  OpE0M1_0x36  ,OpE0M1_0x37
dd  Op_0x38      ,OpM1X0_0x39
dd  OpM1_0x3A    ,Op_0x3B
dd  OpM1X0_0x3C  ,OpM1X0_0x3D
dd  OpM1_0x3E    ,OpM1_0x3F
dd  OpE0_0x40    ,OpE0M1_0x41     ; 40
dd  ALL_INVALID  ,OpM1_0x43
dd  OpX0_0x44    ,OpE0M1_0x45
dd  OpE0M1_0x46  ,OpE0M1_0x47
dd  OpE0M1_0x48  ,OpM1_0x49
dd  OpM1_0x4A    ,OpE0_0x4B
dd  Op_0x4C      ,OpM1_0x4D
dd  OpM1_0x4E    ,OpM1_0x4F
dd  OpE0_0x50    ,OpE0M1X0_0x51   ; 50
dd  OpE0M1_0x52  ,OpM1_0x53
dd  OpX0_0x54    ,OpE0M1_0x55
dd  OpE0M1_0x56  ,OpE0M1_0x57
dd  Op_0x58      ,OpM1X0_0x59
dd  OpE0X0_0x5A  ,Op_0x5B
dd  Op_0x5C      ,OpM1X0_0x5D
dd  OpM1_0x5E    ,OpM1_0x5F
dd  OpE0_0x60    ,OpE0M1_0x61     ; 60
dd  OpE0_0x62    ,OpM1_0x63
dd  OpE0M1_0x64  ,OpE0M1_0x65
dd  OpE0M1_0x66  ,OpE0M1_0x67
dd  OpE0M1_0x68  ,OpM1_0x69
dd  OpM1_0x6A    ,OpE0_0x6B
dd  Op_0x6C      ,OpM1_0x6D
dd  OpM1_0x6E    ,OpM1_0x6F
dd  OpE0_0x70    ,OpE0M1X0_0x71   ; 70
dd  OpE0M1_0x72  ,OpM1_0x73
dd  OpE0M1_0x74  ,OpE0M1_0x75
dd  OpE0M1_0x76  ,OpE0M1_0x77
dd  Op_0x78      ,OpM1X0_0x79
dd  OpE0X0_0x7A  ,Op_0x7B
dd  Op_0x7C      ,OpM1X0_0x7D
dd  OpM1_0x7E    ,OpM1_0x7F
dd  OpE0_0x80    ,OpE0M1_0x81     ; 80
dd  Op_0x82      ,OpM1_0x83
dd  OpE0X0_0x84  ,OpE0M1_0x85
dd  OpE0X0_0x86  ,OpE0M1_0x87
dd  OpX0_0x88    ,OpM1_0x89
dd  OpM1_0x8A    ,OpE0_0x8B
dd  OpX0_0x8C    ,OpM1_0x8D
dd  OpX0_0x8E    ,OpM1_0x8F
dd  OpE0_0x90    ,OpE0M1X0_0x91   ; 90
dd  OpE0M1_0x92  ,OpM1_0x93
dd  OpE0X0_0x94  ,OpE0M1_0x95
dd  OpE0X0_0x96  ,OpE0M1_0x97
dd  OpM1_0x98    ,OpM1_0x99
dd  OpE0_0x9A    ,OpX0_0x9B
dd  OpM1_0x9C    ,OpM1_0x9D
dd  OpM1_0x9E    ,OpM1_0x9F
dd  OpX0_0xA0    ,OpE0M1_0xA1     ; A0
dd  OpX0_0xA2    ,OpM1_0xA3
dd  OpE0X0_0xA4  ,OpE0M1_0xA5
dd  OpE0X0_0xA6  ,OpE0M1_0xA7
dd  OpX0_0xA8    ,OpM1_0xA9
dd  OpX0_0xAA    ,OpE0_0xAB
dd  OpX0_0xAC    ,OpM1_0xAD
dd  OpX0_0xAE    ,OpM1_0xAF
dd  OpE0_0xB0    ,OpE0M1X0_0xB1   ; B0
dd  OpE0M1_0xB2  ,OpM1_0xB3
dd  OpE0X0_0xB4  ,OpE0M1_0xB5
dd  OpE0X0_0xB6  ,OpE0M1_0xB7
dd  Op_0xB8      ,OpM1X0_0xB9
dd  OpX0_0xBA    ,OpX0_0xBB
dd  OpX0_0xBC    ,OpM1X0_0xBD
dd  OpX0_0xBE    ,OpM1_0xBF
dd  OpX0_0xC0    ,OpE0M1_0xC1     ; C0
dd  OpE0_0xC2    ,OpM1_0xC3
dd  OpE0X0_0xC4  ,OpE0M1_0xC5
dd  OpE0M1_0xC6  ,OpE0M1_0xC7
dd  OpX0_0xC8    ,OpM1_0xC9
dd  OpX0_0xCA    ,Op_0xCB
dd  OpX0_0xCC    ,OpM1_0xCD
dd  OpM1_0xCE    ,OpM1_0xCF
dd  OpE0_0xD0    ,OpE0M1X0_0xD1   ; D0
dd  OpE0M1_0xD2  ,OpM1_0xD3
dd  OpE0_0xD4    ,OpE0M1_0xD5
dd  OpE0M1_0xD6  ,OpE0M1_0xD7
dd  Op_0xD8      ,OpM1X0_0xD9
dd  OpE0X0_0xDA  ,ALL_INVALID
dd  Op_0xDC      ,OpM1X0_0xDD
dd  OpM1_0xDE    ,OpM1_0xDF
dd  OpX0_0xE0    ,OpE0M1_0xE1     ; E0
dd  OpE0_0xE2    ,OpM1_0xE3
dd  OpE0X0_0xE4  ,OpE0M1_0xE5
dd  OpE0M1_0xE6  ,OpE0M1_0xE7
dd  OpX0_0xE8    ,OpM1_0xE9
dd  Op_0xEA      ,Op_0xEB
dd  OpX0_0xEC    ,OpM1_0xED
dd  OpM1_0xEE    ,OpM1_0xEF
dd  OpE0_0xF0    ,OpE0M1X0_0xF1   ; F0
dd  OpE0M1_0xF2  ,OpM1_0xF3
dd  OpE0_0xF4    ,OpE0M1_0xF5
dd  OpE0M1_0xF6  ,OpE0M1_0xF7
dd  Op_0xF8      ,OpM1X0_0xF9
dd  OpE0X0_0xFA  ,OpE0_0xFB
dd  OpE0_0xFC    ,OpM1X0_0xFD
dd  OpM1_0xFE    ,OpM1_0xFF

OpTablePx:
dd  OpE0_0x00    ,OpE0M0_0x01     ; 00
dd  OpE0_0x02    ,OpM0_0x03
dd  OpE0M0_0x04  ,OpE0M0_0x05
dd  OpE0M0_0x06  ,OpE0M0_0x07
dd  OpE0_0x08    ,OpM0_0x09
dd  OpM0_0x0A    ,OpE0_0x0B
dd  OpM0_0x0C    ,OpM0_0x0D
dd  OpM0_0x0E    ,OpM0_0x0F
dd  OpE0_0x10    ,OpE0M0X1_0x11   ; 10
dd  OpE0M0_0x12  ,OpM0_0x13
dd  OpE0M0_0x14  ,OpE0M0_0x15
dd  OpE0M0_0x16  ,OpE0M0_0x17
dd  Op_0x18      ,OpM0X1_0x19
dd  OpM0_0x1A    ,OpE0_0x1B
dd  OpM0_0x1C    ,OpM0X1_0x1D
dd  OpM0_0x1E    ,OpM0_0x1F
dd  OpE0_0x20    ,OpE0M0_0x21     ; 20
dd  OpE0_0x22    ,OpM0_0x23
dd  OpE0M0_0x24  ,OpE0M0_0x25
dd  OpE0M0_0x26  ,OpE0M0_0x27
dd  OpE0_0x28    ,OpM0_0x29
dd  OpM0_0x2A    ,OpE0_0x2B
dd  OpM0_0x2C    ,OpM0_0x2D
dd  OpM0_0x2E    ,OpM0_0x2F
dd  OpE0_0x30    ,OpE0M0X1_0x31   ; 30
dd  OpE0M0_0x32  ,OpM0_0x33
dd  OpE0M0_0x34  ,OpE0M0_0x35
dd  OpE0M0_0x36  ,OpE0M0_0x37
dd  Op_0x38      ,OpM0X1_0x39
dd  OpM0_0x3A    ,Op_0x3B
dd  OpM0X1_0x3C  ,OpM0X1_0x3D
dd  OpM0_0x3E    ,OpM0_0x3F
dd  OpE0_0x40    ,OpE0M0_0x41     ; 40
dd  ALL_INVALID  ,OpM0_0x43
dd  OpX1_0x44    ,OpE0M0_0x45
dd  OpE0M0_0x46  ,OpE0M0_0x47
dd  OpE0M0_0x48  ,OpM0_0x49
dd  OpM0_0x4A    ,OpE0_0x4B
dd  Op_0x4C      ,OpM0_0x4D
dd  OpM0_0x4E    ,OpM0_0x4F
dd  OpE0_0x50    ,OpE0M0X1_0x51   ; 50
dd  OpE0M0_0x52  ,OpM0_0x53
dd  OpX1_0x54    ,OpE0M0_0x55
dd  OpE0M0_0x56  ,OpE0M0_0x57
dd  Op_0x58      ,OpM0X1_0x59
dd  OpE0X1_0x5A  ,Op_0x5B
dd  Op_0x5C      ,OpM0X1_0x5D
dd  OpM0_0x5E    ,OpM0_0x5F
dd  OpE0_0x60    ,OpE0M0_0x61     ; 60
dd  OpE0_0x62    ,OpM0_0x63
dd  OpE0M0_0x64  ,OpE0M0_0x65
dd  OpE0M0_0x66  ,OpE0M0_0x67
dd  OpE0M0_0x68  ,OpM0_0x69
dd  OpM0_0x6A    ,OpE0_0x6B
dd  Op_0x6C      ,OpM0_0x6D
dd  OpM0_0x6E    ,OpM0_0x6F
dd  OpE0_0x70    ,OpE0M0X1_0x71   ; 70
dd  OpE0M0_0x72  ,OpM0_0x73
dd  OpE0M0_0x74  ,OpE0M0_0x75
dd  OpE0M0_0x76  ,OpE0M0_0x77
dd  Op_0x78      ,OpM0X1_0x79
dd  OpE0X1_0x7A  ,Op_0x7B
dd  Op_0x7C      ,OpM0X1_0x7D
dd  OpM0_0x7E    ,OpM0_0x7F
dd  OpE0_0x80    ,OpE0M0_0x81     ; 80
dd  Op_0x82      ,OpM0_0x83
dd  OpE0X1_0x84  ,OpE0M0_0x85
dd  OpE0X1_0x86  ,OpE0M0_0x87
dd  OpX1_0x88    ,OpM0_0x89
dd  OpM0_0x8A    ,OpE0_0x8B
dd  OpX1_0x8C    ,OpM0_0x8D
dd  OpX1_0x8E    ,OpM0_0x8F
dd  OpE0_0x90    ,OpE0M0X1_0x91   ; 90
dd  OpE0M0_0x92  ,OpM0_0x93
dd  OpE0X1_0x94  ,OpE0M0_0x95
dd  OpE0X1_0x96  ,OpE0M0_0x97
dd  OpM0_0x98    ,OpM0_0x99
dd  OpE0_0x9A    ,OpX1_0x9B
dd  OpM0_0x9C    ,OpM0_0x9D
dd  OpM0_0x9E    ,OpM0_0x9F
dd  OpX1_0xA0    ,OpE0M0_0xA1     ; A0
dd  OpX1_0xA2    ,OpM0_0xA3
dd  OpE0X1_0xA4  ,OpE0M0_0xA5
dd  OpE0X1_0xA6  ,OpE0M0_0xA7
dd  OpX1_0xA8    ,OpM0_0xA9
dd  OpX1_0xAA    ,OpE0_0xAB
dd  OpX1_0xAC    ,OpM0_0xAD
dd  OpX1_0xAE    ,OpM0_0xAF
dd  OpE0_0xB0    ,OpE0M0X1_0xB1   ; B0
dd  OpE0M0_0xB2  ,OpM0_0xB3
dd  OpE0X1_0xB4  ,OpE0M0_0xB5
dd  OpE0X1_0xB6  ,OpE0M0_0xB7
dd  Op_0xB8      ,OpM0X1_0xB9
dd  OpX1_0xBA    ,OpX1_0xBB
dd  OpX1_0xBC    ,OpM0X1_0xBD
dd  OpX1_0xBE    ,OpM0_0xBF
dd  OpX1_0xC0    ,OpE0M0_0xC1    ; C0
dd  OpE0_0xC2    ,OpM0_0xC3
dd  OpE0X1_0xC4  ,OpE0M0_0xC5
dd  OpE0M0_0xC6  ,OpE0M0_0xC7
dd  OpX1_0xC8    ,OpM0_0xC9
dd  OpX1_0xCA    ,Op_0xCB
dd  OpX1_0xCC    ,OpM0_0xCD
dd  OpM0_0xCE    ,OpM0_0xCF
dd  OpE0_0xD0    ,OpE0M0X1_0xD1   ; D0
dd  OpE0M0_0xD2  ,OpM0_0xD3
dd  OpE0_0xD4    ,OpE0M0_0xD5
dd  OpE0M0_0xD6  ,OpE0M0_0xD7
dd  Op_0xD8      ,OpM0X1_0xD9
dd  OpE0X1_0xDA  ,ALL_INVALID
dd  Op_0xDC      ,OpM0X1_0xDD
dd  OpM0_0xDE    ,OpM0_0xDF
dd  OpX1_0xE0    ,OpE0M0_0xE1     ; E0
dd  OpE0_0xE2    ,OpM0_0xE3
dd  OpE0X1_0xE4  ,OpE0M0_0xE5
dd  OpE0M0_0xE6  ,OpE0M0_0xE7
dd  OpX1_0xE8    ,OpM0_0xE9
dd  Op_0xEA      ,Op_0xEB
dd  OpX1_0xEC    ,OpM0_0xED
dd  OpM0_0xEE    ,OpM0_0xEF
dd  OpE0_0xF0    ,OpE0M0X1_0xF1   ; F0
dd  OpE0M0_0xF2  ,OpM0_0xF3
dd  OpE0_0xF4    ,OpE0M0_0xF5
dd  OpE0M0_0xF6  ,OpE0M0_0xF7
dd  Op_0xF8      ,OpM0X1_0xF9
dd  OpE0X1_0xFA  ,OpE0_0xFB
dd  OpE0_0xFC    ,OpM0X1_0xFD
dd  OpM0_0xFE    ,OpM0_0xFF

OpTableMX:
dd  OpE0_0x00    ,OpE0M1_0x01     ; 00
dd  OpE0_0x02    ,OpM1_0x03
dd  OpE0M1_0x04  ,OpE0M1_0x05
dd  OpE0M1_0x06  ,OpE0M1_0x07
dd  OpE0_0x08    ,OpM1_0x09
dd  OpM1_0x0A    ,OpE0_0x0B
dd  OpM1_0x0C    ,OpM1_0x0D
dd  OpM1_0x0E    ,OpM1_0x0F
dd  OpE0_0x10    ,OpE0M1X1_0x11   ; 10
dd  OpE0M1_0x12  ,OpM1_0x13
dd  OpE0M1_0x14  ,OpE0M1_0x15
dd  OpE0M1_0x16  ,OpE0M1_0x17
dd  Op_0x18      ,OpM1X1_0x19
dd  OpM1_0x1A    ,OpE0_0x1B
dd  OpM1_0x1C    ,OpM1X1_0x1D
dd  OpM1_0x1E    ,OpM1_0x1F
dd  OpE0_0x20    ,OpE0M1_0x21     ; 20
dd  OpE0_0x22    ,OpM1_0x23
dd  OpE0M1_0x24  ,OpE0M1_0x25
dd  OpE0M1_0x26  ,OpE0M1_0x27
dd  OpE0_0x28    ,OpM1_0x29
dd  OpM1_0x2A    ,OpE0_0x2B
dd  OpM1_0x2C    ,OpM1_0x2D
dd  OpM1_0x2E    ,OpM1_0x2F
dd  OpE0_0x30    ,OpE0M1X1_0x31   ; 30
dd  OpE0M1_0x32  ,OpM1_0x33
dd  OpE0M1_0x34  ,OpE0M1_0x35
dd  OpE0M1_0x36  ,OpE0M1_0x37
dd  Op_0x38      ,OpM1X1_0x39
dd  OpM1_0x3A    ,Op_0x3B
dd  OpM1X1_0x3C  ,OpM1X1_0x3D
dd  OpM1_0x3E    ,OpM1_0x3F
dd  OpE0_0x40    ,OpE0M1_0x41     ; 40
dd  ALL_INVALID  ,OpM1_0x43
dd  OpX1_0x44    ,OpE0M1_0x45
dd  OpE0M1_0x46  ,OpE0M1_0x47
dd  OpE0M1_0x48  ,OpM1_0x49
dd  OpM1_0x4A    ,OpE0_0x4B
dd  Op_0x4C      ,OpM1_0x4D
dd  OpM1_0x4E    ,OpM1_0x4F
dd  OpE0_0x50    ,OpE0M1X1_0x51   ; 50
dd  OpE0M1_0x52  ,OpM1_0x53
dd  OpX1_0x54    ,OpE0M1_0x55
dd  OpE0M1_0x56  ,OpE0M1_0x57
dd  Op_0x58      ,OpM1X1_0x59
dd  OpE0X1_0x5A  ,Op_0x5B
dd  Op_0x5C      ,OpM1X1_0x5D
dd  OpM1_0x5E    ,OpM1_0x5F
dd  OpE0_0x60    ,OpE0M1_0x61     ; 60
dd  OpE0_0x62    ,OpM1_0x63
dd  OpE0M1_0x64  ,OpE0M1_0x65
dd  OpE0M1_0x66  ,OpE0M1_0x67
dd  OpE0M1_0x68  ,OpM1_0x69
dd  OpM1_0x6A    ,OpE0_0x6B
dd  Op_0x6C      ,OpM1_0x6D
dd  OpM1_0x6E    ,OpM1_0x6F
dd  OpE0_0x70    ,OpE0M1X1_0x71   ; 70
dd  OpE0M1_0x72  ,OpM1_0x73
dd  OpE0M1_0x74  ,OpE0M1_0x75
dd  OpE0M1_0x76  ,OpE0M1_0x77
dd  Op_0x78      ,OpM1X1_0x79
dd  OpE0X1_0x7A  ,Op_0x7B
dd  Op_0x7C      ,OpM1X1_0x7D
dd  OpM1_0x7E    ,OpM1_0x7F
dd  OpE0_0x80    ,OpE0M1_0x81     ; 80
dd  Op_0x82      ,OpM1_0x83
dd  OpE0X1_0x84  ,OpE0M1_0x85
dd  OpE0X1_0x86  ,OpE0M1_0x87
dd  OpX1_0x88    ,OpM1_0x89
dd  OpM1_0x8A    ,OpE0_0x8B
dd  OpX1_0x8C    ,OpM1_0x8D
dd  OpX1_0x8E    ,OpM1_0x8F
dd  OpE0_0x90    ,OpE0M1X1_0x91   ; 90
dd  OpE0M1_0x92  ,OpM1_0x93
dd  OpE0X1_0x94  ,OpE0M1_0x95
dd  OpE0X1_0x96  ,OpE0M1_0x97
dd  OpM1_0x98    ,OpM1_0x99
dd  OpE0_0x9A    ,OpX1_0x9B
dd  OpM1_0x9C    ,OpM1_0x9D
dd  OpM1_0x9E    ,OpM1_0x9F
dd  OpX1_0xA0    ,OpE0M1_0xA1     ; A0
dd  OpX1_0xA2    ,OpM1_0xA3
dd  OpE0X1_0xA4  ,OpE0M1_0xA5
dd  OpE0X1_0xA6  ,OpE0M1_0xA7
dd  OpX1_0xA8    ,OpM1_0xA9
dd  OpX1_0xAA    ,OpE0_0xAB
dd  OpX1_0xAC    ,OpM1_0xAD
dd  OpX1_0xAE    ,OpM1_0xAF
dd  OpE0_0xB0    ,OpE0M1X1_0xB1   ; B0
dd  OpE0M1_0xB2  ,OpM1_0xB3
dd  OpE0X1_0xB4  ,OpE0M1_0xB5
dd  OpE0X1_0xB6  ,OpE0M1_0xB7
dd  Op_0xB8      ,OpM1X1_0xB9
dd  OpX1_0xBA    ,OpX1_0xBB
dd  OpX1_0xBC    ,OpM1X1_0xBD
dd  OpX1_0xBE    ,OpM1_0xBF
dd  OpX1_0xC0    ,OpE0M1_0xC1     ; C0
dd  OpE0_0xC2    ,OpM1_0xC3
dd  OpE0X1_0xC4  ,OpE0M1_0xC5
dd  OpE0M1_0xC6  ,OpE0M1_0xC7
dd  OpX1_0xC8    ,OpM1_0xC9
dd  OpX1_0xCA    ,Op_0xCB
dd  OpX1_0xCC    ,OpM1_0xCD
dd  OpM1_0xCE    ,OpM1_0xCF
dd  OpE0_0xD0    ,OpE0M1X1_0xD1   ; D0
dd  OpE0M1_0xD2  ,OpM1_0xD3
dd  OpE0_0xD4    ,OpE0M1_0xD5
dd  OpE0M1_0xD6  ,OpE0M1_0xD7
dd  Op_0xD8      ,OpM1X1_0xD9
dd  OpE0X1_0xDA  ,ALL_INVALID
dd  Op_0xDC      ,OpM1X1_0xDD
dd  OpM1_0xDE    ,OpM1_0xDF
dd  OpX1_0xE0    ,OpE0M1_0xE1     ; E0
dd  OpE0_0xE2    ,OpM1_0xE3
dd  OpE0X1_0xE4  ,OpE0M1_0xE5
dd  OpE0M1_0xE6  ,OpE0M1_0xE7
dd  OpX1_0xE8    ,OpM1_0xE9
dd  Op_0xEA      ,Op_0xEB
dd  OpX1_0xEC    ,OpM1_0xED
dd  OpM1_0xEE    ,OpM1_0xEF
dd  OpE0_0xF0    ,OpE0M1X1_0xF1   ; F0
dd  OpE0M1_0xF2  ,OpM1_0xF3
dd  OpE0_0xF4    ,OpE0M1_0xF5
dd  OpE0M1_0xF6  ,OpE0M1_0xF7
dd  Op_0xF8      ,OpM1X1_0xF9
dd  OpE0X1_0xFA  ,OpE0_0xFB
dd  OpE0_0xFC    ,OpM1X1_0xFD
dd  OpM1_0xFE    ,OpM1_0xFF

OpTableE1:
dd  OpE1_0x00    ,OpE1_0x01       ; 00
dd  OpE1_0x02    ,OpM1_0x03
dd  OpE1_0x04    ,OpE1_0x05
dd  OpE1_0x06    ,OpE1_0x07
dd  OpE1_0x08    ,OpM1_0x09
dd  OpM1_0x0A    ,OpE1_0x0B
dd  OpM1_0x0C    ,OpM1_0x0D
dd  OpM1_0x0E    ,OpM1_0x0F
dd  OpE1_0x10    ,OpE1_0x11       ; 10
dd  OpE1_0x12    ,OpM1_0x13
dd  OpE1_0x14    ,OpE1_0x15
dd  OpE1_0x16    ,OpE1_0x17
dd  Op_0x18      ,OpM1X1_0x19
dd  OpM1_0x1A    ,OpE1_0x1B
dd  OpM1_0x1C    ,OpM1X1_0x1D
dd  OpM1_0x1E    ,OpM1_0x1F
dd  OpE1_0x20    ,OpE1_0x21       ; 20
dd  OpE1_0x22    ,OpM1_0x23
dd  OpE1_0x24    ,OpE1_0x25
dd  OpE1_0x26    ,OpE1_0x27
dd  OpE1_0x28    ,OpM1_0x29
dd  OpM1_0x2A    ,OpE1_0x2B
dd  OpM1_0x2C    ,OpM1_0x2D
dd  OpM1_0x2E    ,OpM1_0x2F
dd  OpE1_0x30    ,OpE1_0x31       ; 30
dd  OpE1_0x32    ,OpM1_0x33
dd  OpE1_0x34    ,OpE1_0x35
dd  OpE1_0x36    ,OpE1_0x37
dd  Op_0x38      ,OpM1X1_0x39
dd  OpM1_0x3A    ,Op_0x3B
dd  OpM1X1_0x3C  ,OpM1X1_0x3D
dd  OpM1_0x3E    ,OpM1_0x3F
dd  OpE1_0x40    ,OpE1_0x41       ; 40
dd  ALL_INVALID  ,OpM1_0x43
dd  OpX1_0x44    ,OpE1_0x45
dd  OpE1_0x46    ,OpE1_0x47
dd  OpE1_0x48    ,OpM1_0x49
dd  OpM1_0x4A    ,OpE1_0x4B
dd  Op_0x4C      ,OpM1_0x4D
dd  OpM1_0x4E    ,OpM1_0x4F
dd  OpE1_0x50    ,OpE1_0x51       ; 50
dd  OpE1_0x52    ,OpM1_0x53
dd  OpX1_0x54    ,OpE1_0x55
dd  OpE1_0x56    ,OpE1_0x57
dd  Op_0x58      ,OpM1X1_0x59
dd  OpE1_0x5A    ,Op_0x5B
dd  Op_0x5C      ,OpM1X1_0x5D
dd  OpM1_0x5E    ,OpM1_0x5F
dd  OpE1_0x60    ,OpE1_0x61       ; 60
dd  OpE1_0x62    ,OpM1_0x63
dd  OpE1_0x64    ,OpE1_0x65
dd  OpE1_0x66    ,OpE1_0x67
dd  OpE1_0x68    ,OpM1_0x69
dd  OpM1_0x6A    ,OpE1_0x6B
dd  Op_0x6C      ,OpM1_0x6D
dd  OpM1_0x6E    ,OpM1_0x6F
dd  OpE1_0x70    ,OpE1_0x71       ; 70
dd  OpE1_0x72    ,OpM1_0x73
dd  OpE1_0x74    ,OpE1_0x75
dd  OpE1_0x76    ,OpE1_0x77
dd  Op_0x78      ,OpM1X1_0x79
dd  OpE1_0x7A    ,Op_0x7B
dd  Op_0x7C      ,OpM1X1_0x7D
dd  OpM1_0x7E    ,OpM1_0x7F
dd  OpE1_0x80    ,OpE1_0x81       ; 80
dd  Op_0x82      ,OpM1_0x83
dd  OpE1_0x84    ,OpE1_0x85
dd  OpE1_0x86    ,OpE1_0x87
dd  OpX1_0x88    ,OpM1_0x89
dd  OpM1_0x8A    ,OpE1_0x8B
dd  OpX1_0x8C    ,OpM1_0x8D
dd  OpX1_0x8E    ,OpM1_0x8F
dd  OpE1_0x90    ,OpE1_0x91       ; 90
dd  OpE1_0x92    ,OpM1_0x93
dd  OpE1_0x94    ,OpE1_0x95
dd  OpE1_0x96    ,OpE1_0x97
dd  OpM1_0x98    ,OpM1_0x99
dd  OpE1_0x9A    ,OpX1_0x9B
dd  OpM1_0x9C    ,OpM1_0x9D
dd  OpM1_0x9E    ,OpM1_0x9F
dd  OpX1_0xA0    ,OpE1_0xA1       ; A0
dd  OpX1_0xA2    ,OpM1_0xA3
dd  OpE1_0xA4    ,OpE1_0xA5
dd  OpE1_0xA6    ,OpE1_0xA7
dd  OpX1_0xA8    ,OpM1_0xA9
dd  OpX1_0xAA    ,OpE1_0xAB
dd  OpX1_0xAC    ,OpM1_0xAD
dd  OpX1_0xAE    ,OpM1_0xAF
dd  OpE1_0xB0    ,OpE1_0xB1       ; B0
dd  OpE1_0xB2    ,OpM1_0xB3
dd  OpE1_0xB4    ,OpE1_0xB5
dd  OpE1_0xB6    ,OpE1_0xB7
dd  Op_0xB8      ,OpM1X1_0xB9
dd  OpX1_0xBA    ,OpX1_0xBB
dd  OpX1_0xBC    ,OpM1X1_0xBD
dd  OpX1_0xBE    ,OpM1_0xBF
dd  OpX1_0xC0    ,OpE1_0xC1       ; C0
dd  OpE1_0xC2    ,OpM1_0xC3
dd  OpE1_0xC4    ,OpE1_0xC5
dd  OpE1_0xC6    ,OpE1_0xC7
dd  OpX1_0xC8    ,OpM1_0xC9
dd  OpX1_0xCA    ,Op_0xCB
dd  OpX1_0xCC    ,OpM1_0xCD
dd  OpM1_0xCE    ,OpM1_0xCF
dd  OpE1_0xD0    ,OpE1_0xD1       ; D0
dd  OpE1_0xD2    ,OpM1_0xD3
dd  OpE1_0xD4    ,OpE1_0xD5
dd  OpE1_0xD6    ,OpE1_0xD7
dd  Op_0xD8      ,OpM1X1_0xD9
dd  OpE1_0xDA    ,ALL_INVALID
dd  Op_0xDC      ,OpM1X1_0xDD
dd  OpM1_0xDE    ,OpM1_0xDF
dd  OpX1_0xE0    ,OpE1_0xE1       ; E0
dd  OpE1_0xE2    ,OpM1_0xE3
dd  OpE1_0xE4    ,OpE1_0xE5
dd  OpE1_0xE6    ,OpE1_0xE7
dd  OpX1_0xE8    ,OpM1_0xE9
dd  Op_0xEA      ,Op_0xEB
dd  OpX1_0xEC    ,OpM1_0xED
dd  OpM1_0xEE    ,OpM1_0xEF
dd  OpE1_0xF0    ,OpE1_0xF1       ; F0
dd  OpE1_0xF2    ,OpM1_0xF3
dd  OpE1_0xF4    ,OpE1_0xF5
dd  OpE1_0xF6    ,OpE1_0xF7
dd  Op_0xF8      ,OpM1X1_0xF9
dd  OpE1_0xFA    ,OpE1_0xFB
dd  OpE1_0xFC    ,OpM1X1_0xFD
dd  OpM1_0xFE    ,OpM1_0xFF


ALIGND
CPU_OpTables:
dd OpTableE0
dd OpTablePm
dd OpTablePx
dd OpTableMX

%ifdef Abort_at_op_num
MaxOps:dd Abort_at_op_num
%endif

section .text
%macro OPCODE_EPILOG 0
%if 0
 xor eax,eax        ; Zero for table offset

 test R_Cycles,R_Cycles
 jl CPU_START_NEXT
 jmp HANDLE_EVENT

%else
;mov cl,0
 jmp CPU_RETURN
%endif
%endmacro

;%1 = flag, %2 = wheretogo
%macro JUMP_FLAG 2
%if %1 == SNES_FLAG_E
 mov ch,B_E_flag
 test ch,ch
 jnz %2
%elif %1 == SNES_FLAG_N
 mov ch,B_N_flag
 test ch,ch
 js %2
%elif %1 == SNES_FLAG_V
 mov ch,B_V_flag
 test ch,ch
 jnz %2
%elif %1 == SNES_FLAG_M
 mov ch,B_M1_flag
 test ch,ch
 jnz %2
%elif %1 == SNES_FLAG_X
 mov ch,B_XB_flag
 test ch,ch
 jnz %2
%elif %1 == SNES_FLAG_D
 mov ch,B_D_flag
 test ch,ch
 jnz %2
%elif %1 == SNES_FLAG_I
 mov ch,B_I_flag
 test ch,ch
 jnz %2
%elif %1 == SNES_FLAG_Z
 mov ch,B_Z_flag
 test ch,ch
 jz %2
%elif %1 == SNES_FLAG_C
 mov ch,B_C_flag
 test ch,ch
 jnz %2
%else
%error Unhandled flag in JUMP_FLAG
%endif
%endmacro

;%1 = flag, %2 = wheretogo
%macro JUMP_NOT_FLAG 2
%if %1 == SNES_FLAG_E
 mov ch,B_E_flag
 test ch,ch
 jz %2
%elif %1 == SNES_FLAG_N
 mov ch,B_N_flag
 test ch,ch
 jns %2
%elif %1 == SNES_FLAG_V
 mov ch,B_V_flag
 test ch,ch
 jz %2
%elif %1 == SNES_FLAG_M
 mov ch,B_M1_flag
 test ch,ch
 jz %2
%elif %1 == SNES_FLAG_X
 mov ch,B_XB_flag
 test ch,ch
 jz %2
%elif %1 == SNES_FLAG_D
 mov ch,B_D_flag
 test ch,ch
 jz %2
%elif %1 == SNES_FLAG_I
 mov ch,B_I_flag
 test ch,ch
 jz %2
%elif %1 == SNES_FLAG_Z
 mov ch,B_Z_flag
 test ch,ch
 jnz %2
%elif %1 == SNES_FLAG_C
 mov ch,B_C_flag
 test ch,ch
 jz %2
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
%macro LOAD_CYCLES 0-1 eax
 mov %1,[EventTrip]
 mov dword R_Cycles,[SNES_Cycles]
 sub dword R_Cycles,%1
%endmacro

; Get cycle counter to register argument
%macro GET_CYCLES 1
 mov dword %1,[EventTrip]
 add dword %1,R_Cycles
%endmacro

; Save register R_Cycles to cycle counter
%macro SAVE_CYCLES 0-1 eax
 GET_CYCLES %1
 mov [SNES_Cycles],%1
%endmacro

; Load base pointer to CPU register set
%macro LOAD_BASE 0
 mov dword R_Base,CPU_Register_Base
%endmacro


; Load register R_PBPC with PB:PC
%macro LOAD_PC 0
 mov dword R_PBPC,[CPU_LABEL(PB_Shifted)]
 add dword R_PBPC,[CPU_LABEL(PC)]
%endmacro

; Get PC from register R_PBPC
;%1 = with
%macro GET_PC 1
 movzx dword %1,word R_PC
%endmacro

; Get PB:PC from register R_PBPC
;%1 = with
%macro GET_PBPC 1
%ifnidn %1,R_PBPC
 mov dword %1,R_PBPC
%endif
%endmacro

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
 inc dword [BreaksLast]
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
 inc dword [BreaksLast]
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

%macro SETUPFLAGS 0-3 1,cl,al
%if S_8bit
 E1_SETUPFLAGS %1,%2,%3
%else
 E0_SETUPFLAGS %2,%3
%endif
%endmacro


;%macro Flags_65c816_to_Native_E0 0-1 R_P_B
; Restore the flags from 65c816 flag format to PC format
; Corrupts arg 1, uses value in arg 2 (default to cl, al)
;%1 = scratchpad, %2 = input
%macro E0_RESTOREFLAGS 0-2 cl,al
;%macro Flags_65c816_to_Native 0-2 cl,al
%ifdef WATCH_FLAG_BREAKS
 inc dword [BreaksLast]
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
 inc dword [BreaksLast]
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

%macro RESTOREFLAGS 0-2 cl,al
%if S_8bit
 E1_RESTOREFLAGS %1,%2
%else
 E0_RESTOREFLAGS %1,%2
%endif
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
 mov byte [WRAM+ebx],%1
%%not_within_wram:
 add R_Cycles,_5A22_SLOW_CYCLE
%endmacro

%macro FAST_GET_BYTE_STACK_NATIVE_MODE 1
 cmp bh,0x20
 jnb %%not_within_wram
 mov %1,byte [WRAM+ebx]
%%not_within_wram:
 add R_Cycles,_5A22_SLOW_CYCLE
%endmacro

%macro FAST_SET_BYTE_STACK_EMULATION_MODE 1
 mov byte [WRAM+ebx],%1
 add R_Cycles,_5A22_SLOW_CYCLE
%endmacro

%macro FAST_GET_BYTE_STACK_EMULATION_MODE 1
 mov %1,byte [WRAM+ebx]
 add R_Cycles,_5A22_SLOW_CYCLE
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

%macro PUSH_B 0
%if S_8bit
 E1_PUSH_B
%else
 E0_PUSH_B
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

%macro PULL_B 0
%if S_8bit
 E1_PULL_B
%else
 E0_PULL_B
%endif
%endmacro


; Native mode - push word (S--)
%macro E0_PUSH_W 0
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
%ifdef FAST_STACK_ACCESS_NATIVE_MODE
 cmp bh,0x20
 jnb %%not_within_wram_hi
 mov byte [WRAM+ebx],ah
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
 mov byte [WRAM+ebx],al
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

%macro PUSH_W 0-1 0
%if S_8bit
 E1_PUSH_W %1
%else
 E0_PUSH_W
%endif
%endmacro


;Native mode - push word (S--)
%macro E0_PULL_W 0
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
 inc bx         ; Preincrement S
%ifdef FAST_STACK_ACCESS_NATIVE_MODE
 cmp bh,0x20
 jnb %%not_within_wram_lo
 mov al,byte [WRAM+ebx]
%%not_within_wram_lo:
%else
 GET_BYTE
 mov ah,al
%endif
 inc bx         ; Preincrement S
%ifdef FAST_STACK_ACCESS_NATIVE_MODE
 cmp bh,0x20
 jnb %%not_within_wram_hi
 mov ah,byte [WRAM+ebx]
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

%macro PULL_W 0-1 0
%if S_8bit
 E1_PULL_W %1
%else
 E0_PULL_W
%endif
%endmacro


; Native mode - push long (S--)
%macro E0_PUSH_L 0
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
 ror eax,16     ; bank byte
 SET_BYTE
 dec bx         ; Postdecrement S
 rol eax,8      ; high byte
 SET_BYTE
 dec bx         ; Postdecrement S
 rol eax,8      ; low byte
 SET_BYTE
 dec bx         ; Postdecrement S
 mov [CPU_LABEL(S)],ebx ; Set stack pointer
%endmacro

; Emulation mode - push long (SL--*)
%macro E1_PUSH_L_New 0
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
 ror eax,16     ; bank byte
 SET_BYTE
 dec bx         ; Postdecrement S
 rol eax,8      ; high byte
 SET_BYTE
 dec bx         ; Postdecrement S
 rol eax,8      ; low byte
 SET_BYTE
 dec bx         ; Postdecrement S
 mov [CPU_LABEL(S)],bl  ; Set stack pointer
%endmacro

%macro PUSH_L 0
%if S_8bit
 E1_PUSH_L_New
%else
 E0_PUSH_L
%endif
%endmacro


; Native mode - pull long (++S)
%macro E0_PULL_L 0
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
 inc bx         ; Preincrement S
 GET_BYTE
 inc bx         ; Preincrement S
 ror eax,8      ; low byte
 GET_BYTE
 inc bx         ; Preincrement S
 ror eax,8      ; high byte
 GET_BYTE
 ror eax,16     ; bank byte
 mov [CPU_LABEL(S)],ebx ; Set stack pointer
%endmacro

; Emulation mode - pull long (++SL*)
%macro E1_PULL_L_New 0
 mov ebx,[CPU_LABEL(S)] ; S only - bank always 0!
 inc bx         ; Preincrement S
 GET_BYTE
 inc bx         ; Preincrement S
 ror eax,8      ; low byte
 GET_BYTE
 inc bx         ; Preincrement S
 ror eax,8      ; high byte
 GET_BYTE
 ror eax,16     ; bank byte
 mov [CPU_LABEL(S)],bl  ; Set stack pointer
%endmacro

%macro PULL_L 0
%if S_8bit
 E1_PULL_L_New
%else
 E0_PULL_L
%endif
%endmacro


%macro Stack_Fixup 0
%if S_8bit
 mov byte B_SH,1
%endif
%endmacro


ALIGNC
EXPORT Reset_CPU
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
 mov [NMITIMEN],al
 mov [HTIMEL],eax
 mov [VTIMEL],eax
 mov [HTimer],eax
 mov [HTimer_Set],eax

 mov dword [Access_Speed_Mask],-1

 ; Reset other registers
 mov byte [WRIO],0xFF
 mov byte [RDIO],0xFF
 mov [WRMPYA],al
 mov [WRDIVL],al
 mov [WRDIVH],al
 mov [RDDIVL],al
 mov [RDDIVH],al
 mov [RDMPYL],al
 mov [RDMPYH],al

 mov [JOYC1],al
 mov byte [Controller1_Pos],16
 mov byte [Controller23_Pos],16
 mov byte [Controller45_Pos],16
 mov dword [JOY1L],BIT(31)
 mov dword [JOY2L],BIT(31)
 mov dword [JOY3L],BIT(31)
 mov dword [JOY4L],BIT(31)

 ; Reset hardware ports
 call Reset_Ports

 ; Reset SPC timing
 xor eax,eax
 mov [SPC_last_cycles],eax
 mov [SPC_CPU_cycles],eax
 mov [SPC_cycles_left],eax
 mov [SPC_CPU_cycles_mul],eax

 ; Clear interrupt inputs
 mov [IRQ_pin],al
 mov [NMI_pin],al

 ; Reset CPU

 mov [In_CPU],al
 mov [CPU_Execution_Mode],al ;CEM_Normal_Execution == 0
 mov dword [OpTable],OpTableE1  ; Set current opcode emulation table

 ; Clear cycle counts
 mov dword [SNES_Cycles],0x80  ;32 dots before reset (?)
 mov [EventTrip],eax

 LOAD_BASE
 LOAD_CYCLES edx

 mov dword [CPU_LABEL(S)],0x01FF
 mov [CPU_LABEL(A)],eax ; Clear A, D, X, Y
 mov [CPU_LABEL(D)],eax
 mov [CPU_LABEL(X)],eax
 mov [CPU_LABEL(Y)],eax

 LOAD_PC

 GET_PBPC ebx
 GET_BYTE               ; Get opcode

 call E1_RESET
 SAVE_CYCLES

 mov al,[CPU_LABEL(PB)]
 mov [OLD_PB],al

%ifdef DEBUG
 mov [Frames],eax
;mov [Timer_Counter_FPS],eax
%endif
 ; Initialize flags
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

;%1 = vector; %2 = label prefix;
;%3 = register with relative address of ROM at 00:E000-FFFF
%macro cache_interrupt_vector 3
 movzx eax,word [%1+%3]     ; Get interrupt vector
 mov [%2vector],eax    ; Cache vector
%endmacro

 ; Get all interrupt vectors
 mov ebx,[Read_Bank8Offset+(0xE000 >> 13) * 4] ; Get address of ROM

 cache_interrupt_vector 0xFFFC,RES_E,ebx    ; Reset: Emulation mode
 cache_interrupt_vector 0xFFEA,NMI_N,ebx    ; NMI: Native mode
 cache_interrupt_vector 0xFFFA,NMI_E,ebx    ; NMI: Emulation mode
 cache_interrupt_vector 0xFFEE,IRQ_N,ebx    ; IRQ: Native mode
 cache_interrupt_vector 0xFFFE,IRQ_E,ebx    ; IRQ: Emulation mode
 cache_interrupt_vector 0xFFE6,BRK_N,ebx    ; BRK: Native mode
 cache_interrupt_vector 0xFFE4,COP_N,ebx    ; COP: Native mode
 cache_interrupt_vector 0xFFF4,COP_E,ebx    ; COP: Emulation mode

 mov eax,[RES_Evector] ; Get Reset vector
 mov [CPU_LABEL(PC)],eax    ; Setup PC
 mov [OLD_PC],eax

 call IRQNewFrameReset

 popa
 ret

%macro debug_dma_output 1
%if 0
 pusha
 push byte 2
 movzx eax,byte [MDMAEN]
 push eax
 push dword %1
 call print_str

 add esp,4
 call print_hexnum

 push nl_str
 call print_str
 add esp,4*3
 popa
%endif
%endmacro


ALIGNC
EXPORT do_DMA
 debug_dma_output dma_xfer1_str

 LOAD_CYCLES

 cmp byte [MDMAEN],0
 jz .dma_done

 cmp byte [In_DMA],0
 jnz .dma_started

.sync:
 ;first bus cycle doesn't overlap
 add R_65c816_Cycles,_5A22_SLOW_CYCLE
.dma_started:

 DMAOPERATION 0,.early_out
 DMAOPERATION 1,.early_out
 DMAOPERATION 2,.early_out
 DMAOPERATION 3,.early_out
 DMAOPERATION 4,.early_out
 DMAOPERATION 5,.early_out
 DMAOPERATION 6,.early_out
 DMAOPERATION 7,.early_out

.dma_done:
 mov byte [In_DMA],0

 debug_dma_output dma_xfer3_str

 mov byte [CPU_Execution_Mode],CEM_Normal_Execution
 SAVE_CYCLES

 cmp byte [NMI_pin],NMI_Raised
 jne .no_nmi

 ;setup NMI to execute after one opcode

 mov edx,[FixedTrip]
 mov [NMI_Next_Trip],edx
 mov edx,[Fixed_Event]
 mov [NMI_Next_Event],edx

 mov edx,NMI_Event
 mov [Fixed_Event],edx
 mov [Event_Handler],edx
 mov eax,[SNES_Cycles]
 inc eax
 mov [FixedTrip],eax
 mov [EventTrip],eax

 jmp CPU_START

.no_nmi:
 mov byte [CPU_Execution_Mode],CEM_Instruction_After_IRQ_Enable
 jmp CPU_START

.early_out:
 debug_dma_output dma_xfer2_str

 SAVE_CYCLES
 jmp dword [Event_Handler]


ALIGNC
EXPORT Do_CPU
 pusha
 mov byte [PaletteChanged],1   ; Make sure we get our palette
 mov dword [Last_Frame_Line],239

 call CPU_START
 popa
 ret

; Start of actual CPU execution core

; New for 0.25 - one CPU execution loop, also used for SPC
ALIGNC
EXPORT CPU_START_IRQ
 call IRQ_Check_Newline
CPU_START:
 LOAD_CYCLES
 test R_Cycles,R_Cycles
 jge .no_event_wait
.execute_opcode:
 mov al,[CPU_Execution_Mode]
 test al,al
 jz .normal_execution

 cmp al,CEM_In_DMA
 je do_DMA

 cmp al,CEM_Instruction_After_IRQ_Enable
 je .instruction_after_irq_enable
 xor R_Cycles,R_Cycles
;SAVE_CYCLES
 mov edx,[EventTrip]
 mov [SNES_Cycles],edx
.no_event_wait:
 jmp dword [Event_Handler]



ALIGNC
.instruction_after_irq_enable:
;set up an event for immediately the next instruction
 mov eax,IRQ_Enabled_Event
 xor edx,edx
 mov [Event_Handler],eax
 mov [EventTrip],edx
.normal_execution:
 LOAD_PC
 LOAD_CYCLES
 LOAD_BASE
 xor eax,eax        ; Zero for table offset
 mov byte [In_CPU],-1

 jmp CPU_START_NEXT

ALIGNC
EXPORT CPU_RETURN
%ifdef Abort_at_op_num
 dec dword [MaxOps]
 jz Op_0xDB     ;STP
%endif

 xor eax,eax        ; Zero for table offset
 test R_Cycles,R_Cycles

 jge HANDLE_EVENT

EXPORT CPU_START_NEXT
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
 jmp .track_e0_flags    ;
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

 GET_PBPC ebx

%if 0
 pusha
 push dword [FixedTrip]
 push dword [Fixed_Event]
 push dword [EventTrip]
 push dword [Event_Handler]
 movzx eax,byte [CPU_Execution_Mode]
 push eax
 GET_CYCLES eax
 push eax
 push ebx
extern check_op
 call check_op
 add esp,4*7
 popa
%endif

 GET_BYTE               ; Get opcode

%ifdef OPCODE_TRACE_LOG
 pusha
 movzx eax,al
 push eax
 SAVE_PC eax
 E0_SETUPFLAGS
 cmp byte B_E_flag,0
 setnz ah
 mov B_P,ax
EXTERN opcode_trace_5A22
 call opcode_trace_5A22
 pop eax
 popa
%endif
 mov edx,B_OpTable
 xor ebx,ebx

 jmp dword [edx+eax*4]  ; Call opcode handler

ALIGNC
HANDLE_EVENT:
 SAVE_PC R_PBPC

 mov byte [In_CPU],0

 SAVE_CYCLES
 jmp dword [Event_Handler]

ALIGNC
EXPORT E1_RESET
 ; RESET (Emulation mode)
 add R_Cycles,_5A22_FAST_CYCLE   ; hwint processing: 1 IO
 mov ebx,B_S
 GET_BYTE       ;dummy stack access
 dec bl
 GET_BYTE       ;dummy stack access
 dec bl
 GET_BYTE       ;dummy stack access
 mov B_S,ebx

;7.12.2 In the Emulation mode, the PBR and DBR registers are cleared to 00
;when a hardware interrupt, BRK or COP is executed. In this case, previous
;contents of the PBR are not automatically saved.

;NOTE - DB is ONLY cleared on RESET!
 mov byte [CPU_LABEL(DB)],0

 mov ebx,0xFFFC         ; Get Emulation mode IRQ vector

 xor eax,eax
 GET_WORD
 mov [CPU_LABEL(PC)],eax    ; Setup PC vector
 mov byte [CPU_LABEL(PB)],0 ; Setup bank
;SET_FLAG SNES_FLAG_I   ; Disable IRQs
 STORE_FLAGS_I 1
;CLR_FLAG SNES_FLAG_D   ; Disable decimal mode
 STORE_FLAGS_D 0
 ret

ALIGNC
EXPORT E1_IRQ
 ; Emulation mode IRQ
 mov eax,[CPU_LABEL(PC)]
 E1_PUSH_W
;CLR_FLAG SNES_FLAG_B   ; Clear break bit on stack
 E1_SETUPFLAGS 0        ; put flags into SNES packed flag format
;SET_FLAG SNES_FLAG_B
 E1_PUSH_B

 mov ebx,0xFFFE         ; Get Emulation mode IRQ vector

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

 mov ebx,0xFFEE         ; Get Native mode IRQ vector
IRQ_completion:
 xor eax,eax
 GET_WORD
 mov [CPU_LABEL(PC)],eax    ; Setup PC vector
 mov byte [CPU_LABEL(PB)],0 ; Setup bank
;SET_FLAG SNES_FLAG_I   ; Disable IRQs
 STORE_FLAGS_I 1
;CLR_FLAG SNES_FLAG_D   ; Disable decimal mode
 STORE_FLAGS_D 0
 ret

%include "cpu/cpuaddr.inc"  ; Addressing modes ([d], a,x, etc.)
%include "cpu/cpumacro.inc" ; Instructions (LDA,ADC,SBC,etc.)

EXPORT cpu_ops_start

ALIGNC
EXPORT ALL_INVALID
 GET_PC ebx
 mov [Map_Address],ebx
 mov bl,[CPU_LABEL(PB)]
 mov [Map_Address + 3],bl
 mov [Map_Byte],al
 jmp InvalidOpcode ; This exits...

%include "cpu/cpuops.inc"   ; Opcode handlers

%include "cpu/timing.inc"

section .text
ALIGNC
EXPORT CPU_text_end
section .data
ALIGND
EXPORT CPU_data_end
section .bss
ALIGNB
EXPORT CPU_bss_end
