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
%ifdef TRAP_INVALID_JUMP
 mov [C_LABEL(Map_Byte)],eax
%endif
 ADDR_Absolute_JSR

 push eax
 GET_PC eax          ; last instruction byte PC in ax
 PUSH_W              ; Address of last byte, not next instruction
 pop eax

 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 add eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x20
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp short .read_direct
%endif
OPCODE_EPILOG

OPCODE_PROLOG(0x22) ; JSL al
%ifdef TRAP_INVALID_JUMP
 mov [C_LABEL(Map_Byte)],eax
%endif
 ADDR_Absolute_Long_JSR

 mov ebx,eax
 shr ebx,16
 and eax,(1 << 16) - 1

 mov B_PB,bl
 mov R_NativePC,eax
 test [MEMSEL],bl       ; Check bus speed against PB
 mov al,[C_LABEL(FastROM_offset)]
 jnz .fastrom
 mov al,4
.fastrom:
%ifndef NO_FASTROM
 mov [C_LABEL(CycleTable)],al   ; Update bus speed
%endif
 mov edx,R_NativePC
 shl ebx,16
 add edx,ebx

 shr edx,13
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jz .read_non_linear

 add edx,ebx
.read_direct:

 add R_NativePC,edx
 mov B_PBOffset,edx

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x22
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov edx,C_LABEL(Blank)
 jmp short .read_direct
%endif
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

OPCODE_PROLOG(0x40) ; RTI s
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 PULL_B
 mov bl,B_I_flag
 push ebx
 RESTOREFLAGS
%if S_8bit
 PULL_W
 mov R_NativePC,eax
 add eax,B_PB_Shifted
%else
 PULL_L
 mov ebx,eax
 shr ebx,16

 mov R_NativePC,(1 << 16) -1
 and R_NativePC,eax

 mov B_PB,bl
 test [MEMSEL],bl   ; Check bus speed against PB
 mov bl,[C_LABEL(FastROM_offset)]
 jnz .fastrom
 mov bl,4
.fastrom:
%ifndef NO_FASTROM
 mov [C_LABEL(CycleTable)],bl   ; Update bus speed
%endif
%endif

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,B_PB_Shifted
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 pop ebx

 test bl,bl
 jz .no_irq_enable
 JUMP_FLAG SNES_FLAG_I,.no_irq_enable
 mov al,CEM_Instruction_After_IRQ_Enable
 mov [CPU_Execution_Mode],al
 xor edx,edx
 SAVE_CYCLES
 mov [C_LABEL(EventTrip)],edx
 mov edx,Enabling_IRQ_Event
 LOAD_CYCLES
 mov [Event_Handler],edx

.no_irq_enable:
%if S_8bit
 OPCODE_EPILOG
%else
 SET_TABLE_MX
%endif

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 add esp,byte 4
 mov byte [C_LABEL(Map_Byte)+3],0x40
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp .read_direct ;*
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
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 PULL_W
 inc ax     ; This is a MAD processor!

 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 or eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x60
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp short .read_direct
%endif
OPCODE_EPILOG

OPCODE_PROLOG(0x62) ; PER s
 READ16_Immediate
 GET_PC ebx
 add eax,ebx
 PUSH_W
OPCODE_EPILOG

OPCODE_PROLOG(0x6B) ; RTL s
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 E0_PULL_L
 mov ebx,eax
 inc ax
 shr ebx,16

 mov R_NativePC,(1 << 16) - 1
 mov B_PB,bl
 and R_NativePC,eax

 test [MEMSEL],bl   ; Check bus speed against PB
 mov bl,[C_LABEL(FastROM_offset)]
 jnz .fastrom
 mov bl,4
.fastrom:
%ifndef NO_FASTROM
 mov [C_LABEL(CycleTable)],bl   ; Update bus speed
%endif

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,B_PB_Shifted
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x6B
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov edx,C_LABEL(Blank)
 jmp short .read_direct
%endif
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

OPCODE_PROLOG(0xFC) ; JSR (a,x)
%ifdef TRAP_INVALID_JUMP
 mov [C_LABEL(Map_Byte)],eax
%endif
 ADDR_Absolute_Indexed_Indirect JSR

 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 add eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0xFC
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp short .read_direct
%endif
OPCODE_EPILOG

%undef OPCODE_PROLOG
