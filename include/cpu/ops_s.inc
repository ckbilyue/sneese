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

OPCODE_PROLOG(0x28) ; PLP s
 ADDR_Implied
 PULL_B
 mov bl,B_I_flag
 RESTOREFLAGS

 test bl,bl
%if S_8bit
 jz C_LABEL(CPU_RETURN)
 JUMP_FLAG SNES_FLAG_I,C_LABEL(CPU_RETURN),near
%else
 jz .no_irq_enable
 JUMP_FLAG SNES_FLAG_I,.no_irq_enable
%endif
 mov al,CEM_Instruction_After_IRQ_Enable
 mov [CPU_Execution_Mode],al
 xor edx,edx
 SAVE_CYCLES
 mov [C_LABEL(EventTrip)],edx
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

; Push PB(K) onto stack
OPCODE_PROLOG(0x4B) ; PHK s
 _PHK
OPCODE_EPILOG

OPCODE_PROLOG(0x50) ; BVC r
 _BFC SNES_FLAG_V
OPCODE_EPILOG

OPCODE_PROLOG(0x62) ; PER s
 READ16_Immediate
 GET_PC ebx
 add eax,ebx
 PUSH_W
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
 jz C_LABEL(CPU_RETURN)
 JUMP_FLAG SNES_FLAG_I,C_LABEL(CPU_RETURN),near
%else
 jz .no_irq_enable
 JUMP_FLAG SNES_FLAG_I,.no_irq_enable
%endif
 mov al,CEM_Instruction_After_IRQ_Enable
 mov [CPU_Execution_Mode],al
 xor edx,edx
 SAVE_CYCLES
 mov [C_LABEL(EventTrip)],edx
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
 PUSH_W
OPCODE_EPILOG

OPCODE_PROLOG(0xE2) ; SEP #
 READ8_Immediate

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
 PUSH_W
OPCODE_EPILOG

OPCODE_PROLOG(0xFB) ; XCE i
 ADDR_Implied
%if S_8bit
 JUMP_FLAG SNES_FLAG_C,C_LABEL(CPU_RETURN),near
 STORE_FLAGS_E ah
 mov al,1
 STORE_FLAGS_C al
 STORE_FLAGS_M al
 STORE_FLAGS_X al
 mov dword [OpTable],OpTableMX  ; Set current opcode emulation table
%else
 JUMP_NOT_FLAG SNES_FLAG_C,C_LABEL(CPU_RETURN),near
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

%undef OPCODE_PROLOG
