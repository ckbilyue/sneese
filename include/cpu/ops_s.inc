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

%define OPCODE_PROLOG(op) OPCODE_LABEL OpE %+ S_8bit %+ _ %+ op


OPCODE_PROLOG(0x00) ; BRK #
 SoftwareInterrupt 0xFFFE,0xFFE6
OPCODE_EPILOG

OPCODE_PROLOG(0x02) ; COP #
 SoftwareInterrupt 0xFFF4,0xFFE4
OPCODE_EPILOG

OPCODE_PROLOG(0x08) ; PHP s
 ADDR_Implied
 SETUPFLAGS
 PUSH_B
OPCODE_EPILOG

OPCODE_PROLOG(0x0B) ; PHD s
 _PHD
OPCODE_EPILOG

OPCODE_PROLOG(0x10) ; BPL r
 _BFC SNES_FLAG_N
OPCODE_EPILOG

OPCODE_PROLOG(0x1B) ; TCS i
 _TxS B_A
OPCODE_EPILOG

OPCODE_PROLOG(0x20) ; JSR a
 ADDR_Absolute_JSR
 push eax
 GET_PBPC eax        ; last instruction byte PC in ax
 PUSH_W              ; Address of last byte, not next instruction
 pop eax
 mov R_PC,ax
OPCODE_EPILOG

OPCODE_PROLOG(0x22) ; JSL al
 ADDR_Absolute_Long_JSR
 mov R_PBPC,eax
 shr eax,16
 mov B_PB,al
OPCODE_EPILOG

OPCODE_PROLOG(0x28) ; PLP s
 ADDR_Implied
 PULL_B
 mov bl,B_I_flag
 RESTOREFLAGS

 test bl,bl
%if S_8bit
 jz CPU_RETURN
 JUMP_FLAG SNES_FLAG_I,CPU_RETURN
%else
 jz .no_irq_enable
 JUMP_FLAG SNES_FLAG_I,.no_irq_enable
%endif
 xor edx,edx
 SAVE_CYCLES
 mov [EventTrip],edx
 mov edx,Enabling_IRQ_Event
 LOAD_CYCLES
 mov [Event_Handler],edx

%if S_8bit == 0
.no_irq_enable:
 SET_TABLE_MX
%endif
OPCODE_EPILOG

OPCODE_PROLOG(0x2B) ; PLD s
 _PLD
OPCODE_EPILOG

OPCODE_PROLOG(0x30) ; BMI r
 _BFS SNES_FLAG_N
OPCODE_EPILOG

OPCODE_PROLOG(0x40) ; RTI s
 add R_Cycles,_5A22_FAST_CYCLE * 2
 PULL_B
 mov bl,B_I_flag
 push ebx

 RESTOREFLAGS
%if S_8bit
 PULL_W
 mov R_PC,ax
%else
 PULL_L
 mov R_PBPC,eax
 shr eax,16
 mov B_PB,al
%endif

 pop ebx

 test bl,bl
 jz .no_irq_enable
 JUMP_FLAG SNES_FLAG_I,.no_irq_enable
 xor edx,edx
 SAVE_CYCLES
 mov [EventTrip],edx
 mov edx,Enabling_IRQ_Event
 LOAD_CYCLES
 mov [Event_Handler],edx

.no_irq_enable:
%if S_8bit == 0
 SET_TABLE_MX
%endif
OPCODE_EPILOG

; Push PB(K) onto stack
OPCODE_PROLOG(0x4B) ; PHK s
 _PHK
OPCODE_EPILOG

OPCODE_PROLOG(0x50) ; BVC r
 _BFC SNES_FLAG_V
OPCODE_EPILOG

OPCODE_PROLOG(0x60) ; RTS s
 add R_Cycles,_5A22_FAST_CYCLE * 2
 PULL_W
 add R_Cycles,_5A22_FAST_CYCLE
 inc ax
 mov R_PC,ax
OPCODE_EPILOG

OPCODE_PROLOG(0x62) ; PER s
 READ16_Immediate
 add R_Cycles,_5A22_FAST_CYCLE
 GET_PBPC ebx
 add eax,ebx
 PUSH_W New
OPCODE_EPILOG

OPCODE_PROLOG(0x6B) ; RTL s
 add R_Cycles,_5A22_FAST_CYCLE * 2
 E0_PULL_L
 Stack_Fixup
 mov R_PBPC,eax
 shr eax,16
 inc R_PC
 mov B_PB,al
OPCODE_EPILOG

OPCODE_PROLOG(0x70) ; BVS r
 _BFS SNES_FLAG_V
OPCODE_EPILOG

OPCODE_PROLOG(0x80) ; BRA r
 _BRA
OPCODE_EPILOG

; Push DB(B) onto stack
OPCODE_PROLOG(0x8B) ; PHB s
 _PHB
OPCODE_EPILOG

OPCODE_PROLOG(0x90) ; BCC r
 _BFC SNES_FLAG_C
OPCODE_EPILOG

OPCODE_PROLOG(0x9A) ; TXS i
 _TxS B_X
OPCODE_EPILOG

; Pull DB(B) from stack
OPCODE_PROLOG(0xAB) ; PLB s
 _PLB
OPCODE_EPILOG

OPCODE_PROLOG(0xB0) ; BCS r
 _BFS SNES_FLAG_C
OPCODE_EPILOG

OPCODE_PROLOG(0xC2) ; REP #
 READ8_Immediate
 add R_Cycles,_5A22_FAST_CYCLE

 mov bl,B_I_flag

 test al,REAL_SNES_FLAG_C
 jz .no_change_carry
 STORE_FLAGS_C ah
.no_change_carry:

 test al,REAL_SNES_FLAG_Z
 jz .no_change_zero
 STORE_FLAGS_Z al
.no_change_zero:

 test al,REAL_SNES_FLAG_I
 jz .no_change_interrupt_disable
 STORE_FLAGS_I ah
.no_change_interrupt_disable:

 test al,REAL_SNES_FLAG_D
 jz .no_change_decimal_mode
 STORE_FLAGS_D ah
.no_change_decimal_mode:

%if S_8bit == 0
 test al,REAL_SNES_FLAG_X
 jz .no_change_index_size
 STORE_FLAGS_X ah
.no_change_index_size:

 test al,REAL_SNES_FLAG_M
 jz .no_change_memory_size
 STORE_FLAGS_M ah
.no_change_memory_size:
%endif

 test al,REAL_SNES_FLAG_V
 jz .no_change_overflow
 STORE_FLAGS_V ah
.no_change_overflow:

 test al,REAL_SNES_FLAG_N
 jz .no_change_negative
 STORE_FLAGS_N ah
.no_change_negative:

 test bl,bl
%if S_8bit
 jz CPU_RETURN
 JUMP_FLAG SNES_FLAG_I,CPU_RETURN
%else
 jz .no_irq_enable
 JUMP_FLAG SNES_FLAG_I,.no_irq_enable
%endif
 xor edx,edx
 SAVE_CYCLES
 mov [EventTrip],edx
 mov edx,Enabling_IRQ_Event
 LOAD_CYCLES
 mov [Event_Handler],edx

%if S_8bit == 0
.no_irq_enable:
 SET_TABLE_MX
%endif
OPCODE_EPILOG

OPCODE_PROLOG(0xD0) ; BNE r
 _BFC SNES_FLAG_Z
OPCODE_EPILOG

OPCODE_PROLOG(0xD4) ; PEI s
 READ16_Direct
 PUSH_W New
OPCODE_EPILOG

OPCODE_PROLOG(0xE2) ; SEP #
 READ8_Immediate
 add R_Cycles,_5A22_FAST_CYCLE

 test al,REAL_SNES_FLAG_C
 jz .no_change_carry
 STORE_FLAGS_C al
.no_change_carry:

 test al,REAL_SNES_FLAG_Z
 jz .no_change_zero
 STORE_FLAGS_Z ah
.no_change_zero:

 test al,REAL_SNES_FLAG_I
 jz .no_change_interrupt_disable
 STORE_FLAGS_I al
.no_change_interrupt_disable:

 test al,REAL_SNES_FLAG_D
 jz .no_change_decimal_mode
 STORE_FLAGS_D al
.no_change_decimal_mode:

%if S_8bit == 0
 test al,REAL_SNES_FLAG_X
 jz .no_change_index_size
 STORE_FLAGS_X al
.no_change_index_size:

 test al,REAL_SNES_FLAG_M
 jz .no_change_memory_size
 STORE_FLAGS_M al
.no_change_memory_size:
%endif

 test al,REAL_SNES_FLAG_V
 jz .no_change_overflow
 STORE_FLAGS_V al
.no_change_overflow:

 test al,REAL_SNES_FLAG_N
 jz .no_change_negative
 STORE_FLAGS_N al
.no_change_negative:

%if S_8bit == 0
 SET_TABLE_MX
%endif
OPCODE_EPILOG

OPCODE_PROLOG(0xF0) ; BEQ r
 _BFS SNES_FLAG_Z
OPCODE_EPILOG

OPCODE_PROLOG(0xF4) ; PEA s
 READ16_Immediate
 PUSH_W New
OPCODE_EPILOG

OPCODE_PROLOG(0xFB) ; XCE i
 ADDR_Implied
%if S_8bit
 JUMP_FLAG SNES_FLAG_C,CPU_RETURN
 STORE_FLAGS_E ah
 mov al,1
 STORE_FLAGS_C al
 STORE_FLAGS_M al
 STORE_FLAGS_X al
 mov dword [OpTable],OpTableMX  ; Set current opcode emulation table
%else
 JUMP_NOT_FLAG SNES_FLAG_C,CPU_RETURN
 mov B_XH,ah
 mov B_YH,ah
 STORE_FLAGS_C ah
 mov al,1
 STORE_FLAGS_E al
 STORE_FLAGS_B al
 STORE_FLAGS_1 al
 mov B_SH,al
 mov dword [OpTable],OpTableE1  ; Set current opcode emulation table
%endif
OPCODE_EPILOG

OPCODE_PROLOG(0xFC) ; JSR (a,x)
 ADDR_Absolute_Indexed_Indirect JSR
 mov R_PC,ax
OPCODE_EPILOG

%undef OPCODE_PROLOG
