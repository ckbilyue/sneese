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

; DMA.asm - (H)DMA emulation

;%define NO_HDMA

%define SNEeSe_DMA_asm

%include "misc.inc"
%include "cpu/dma.inc"
%include "cpu/regs.inc"
%include "ppu/ppu.inc"
%include "cpu/cpumem.inc"

extern In_CPU,HVBJOY
EXTERN SNES_Cycles

section .text
EXPORT DMA_text_start
section .data
EXPORT DMA_data_start
section .bss
EXPORT DMA_bss_start

section .data
ALIGND
DMA_Data_Areas:
dd  TableDMA0,TableDMA1,TableDMA2,TableDMA3
dd  TableDMA4,TableDMA5,TableDMA6,TableDMA7

DMA_PPU_Order:
db  0,0,0,0
db  0,1,0,1
db  0,0,0,0
db  0,0,1,1
db  0,1,2,3
db  0,1,0,1
db  0,0,0,0
db  0,0,1,1

HDMA_Size:
db  1,2,2,4
db  4,4,2,4

section .bss
%macro DMA_DATA 1
ALIGNB
EXPORT TableDMA%1
; dh0bcttt d=CPU->PPU,h=addr,b=inc/dec,c=inc/fixed,t=type
EXPORT DMAP_%1,skipb
EXPORT BBAD_%1          ; Low byte of 0x21??
EXPORT DMA_Vid_%1   ,skipb
EXPORT NTRL_%1,skipb
DMA_Inc_%1: skipb
EXPORT A1T_%1       ; Source Address L/H/B
EXPORT A1TL_%1,skipb    ; Source Address L
EXPORT A1TH_%1,skipb    ; Source Address H
EXPORT A1B_%1 ,skipb    ; Source Bank Address
                 skipb
EXPORT DAS_%1       ; Data Size L/H
EXPORT DASL_%1,skipb    ; Data Size L
EXPORT DASH_%1,skipb    ; Data Size H
EXPORT DASB_%1,skipb    ; Data address bank
                 skipb
EXPORT A2T_%1
EXPORT A2L_%1 ,skipb    ; HDMA table address L
EXPORT A2H_%1 ,skipb    ; HDMA table address H
EXPORT A2B_%1 ,skipb    ; HDMA table bank address
                 skipb

; HDMA_Siz_x - These hold the register size for HDMA
HDMA_Siz_%1:skipl

; DMA_By_x - B bus address for access y of 0-3
DMA_B0_%1:  skipb
DMA_B1_%1:  skipb
DMA_B2_%1:  skipb
DMA_B3_%1:  skipb

HDMA_Need_Transfer_%1:skipb
%endmacro

DMA_DATA 0
DMA_DATA 1
DMA_DATA 2
DMA_DATA 3
DMA_DATA 4
DMA_DATA 5
DMA_DATA 6
DMA_DATA 7

DMA_Transfer_Size:skipl ;Size for active DMA transfer

EXPORT MDMAEN,skipb     ; DMA enable
EXPORT HDMAEN,skipb     ; HDMA enable
EXPORT HDMA_Not_Ended,skipb     ; HDMA not yet disabled this frame
                        ; 0000dccc | d = in DMA/HDMA, if 0 all should be 0
EXPORT In_DMA,skipb     ; c = channel # 0-7
EXPORT DMA_Pending_B_Address,skipb  ; address # 0-3, or -1 if n/a
EXPORT DMA_Pending_Data,skipb       ; data for DMA transfer awaiting write

section .text
;macro for getting A bus alias for B bus address for DMA access
%macro GET_B_BUS_ADDRESS 1
 movzx ebx,byte %1
 add ebx,0x2100
%endmacro

;macro for performing DMA B bus accesses
%macro ACCESS_B_BUS 3
 push ebx
 GET_B_BUS_ADDRESS %3
 %1 %2
 pop ebx
%endmacro

;macro for DMA reads from B bus
%macro GET_BYTE_B_BUS 2
 ACCESS_B_BUS GET_BYTE,%2,%1
%endmacro

;macro for DMA writes to B bus
%macro SET_BYTE_B_BUS 2
 ACCESS_B_BUS SET_BYTE,%2,%1
%endmacro

;macro for HDMA transfers in PPU write mode
%macro HDMA_TRANSFER_A_TO_B 1
 GET_BYTE 0
 SET_BYTE_B_BUS %1,0
%endmacro

;macro for HDMA transfers in PPU read mode
%macro HDMA_TRANSFER_B_TO_A 1
 GET_BYTE_B_BUS %1,0
 SET_BYTE 0
%endmacro


;macro for DMA transfers in PPU write mode
%macro DMA_TRANSFER_A_TO_B 4-5 0
 mov byte [DMA_Pending_B_Address],%1
 test R_65c816_Cycles,R_65c816_Cycles
 jge %3
%2:

 GET_BYTE _5A22_SLOW_CYCLE
 mov [DMA_Pending_Data],al

 SET_BYTE_B_BUS [edi+DMA_B%1],0

 add bx,si
 dec dword [DMA_Transfer_Size]
%if %5
 jnz %4
%else
 jz %4
%endif
%endmacro

;macro for DMA transfers in PPU read mode
%macro DMA_TRANSFER_B_TO_A 4-5 0
 mov byte [DMA_Pending_B_Address],%1
 test R_65c816_Cycles,R_65c816_Cycles
 jge %3
%2:

 GET_BYTE_B_BUS [edi+DMA_B%1],_5A22_SLOW_CYCLE
 mov [DMA_Pending_Data],al

 SET_BYTE 0

 add bx,si
 dec dword [DMA_Transfer_Size]
%if %5
 jnz %4
%else
 jz %4
%endif
%endmacro


;macro for processing a channel during HDMA transfer
%macro HDMAOPERATION 1
  mov al,[HDMAEN]
  and al,[HDMA_Not_Ended]
  test al,BIT(%1)
  jz %%no_hdma

  add dword R_65c816_Cycles,byte 8  ; HDMA processing

  mov byte [In_DMA],(%1) | DMA_IN_PROGRESS
  LOAD_DMA_TABLE %1
  call Do_HDMA_Channel ; CF set if channel disabled
  jnc %%no_disable

  and byte [HDMA_Not_Ended],~BIT(%1)    ; Disable this channel
%%no_disable:
%%no_hdma:
%endmacro


ALIGNC
%if 0
  al = data byte
  ebx = A-bus address
  [DMA_Transfer_Size] = DAS (byte count)
  esi = Address adjustment
%endif
EXPORT Do_DMA_Channel
 mov ebx,[edi+A1T]      ; CPU address in ebx
 and ebx,BITMASK(0,23)

 movzx ecx,word [edi+DAS]
 dec ecx
 and ecx,BITMASK(0,15)
 inc ecx
 mov [DMA_Transfer_Size],ecx

 mov al,[edi+DMAP]
 movsx esi,byte [edi+DMA_Inc]   ; Get address adjustment
 test al,al     ; Is the operation CPU->PPU?
 jns .ppu_write

; PPU->CPU
 movsx edx,byte [DMA_Pending_B_Address]
 test edx,edx
 js .loop_ppu_read

 mov al,[DMA_Pending_Data]
 jmp [.ppu_read_resume_table+edx*4]

section .data
.ppu_read_resume_table:
dd  .lpr_access0,.lpr_access1,.lpr_access2,.lpr_access3

section .text
.loop_ppu_read:
 DMA_TRANSFER_B_TO_A 0,.lpr_access0,.early_out,.ppu_read_done

 DMA_TRANSFER_B_TO_A 1,.lpr_access1,.early_out,.ppu_read_done

 DMA_TRANSFER_B_TO_A 2,.lpr_access2,.early_out,.ppu_read_done

 DMA_TRANSFER_B_TO_A 3,.lpr_access3,.early_out,.loop_ppu_read,1

.ppu_read_done:
.ppu_write_done:
 mov byte [DMA_Pending_B_Address],-1

.early_out:
 mov eax,[DMA_Transfer_Size]
 mov [edi+A1T],bx       ; v0.15 forgot to update DMA pointers!
 mov word [edi+DAS],ax
 ret


ALIGNC
; CPU->PPU
.ppu_write:
 movsx edx,byte [DMA_Pending_B_Address]
 test edx,edx
 js .loop_ppu_write

 mov al,[DMA_Pending_Data]
 jmp [.ppu_write_resume_table+edx*4]

section .data
.ppu_write_resume_table:
dd  .lpw_access0,.lpw_access1,.lpw_access2,.lpw_access3

section .text

.loop_ppu_write:
 DMA_TRANSFER_A_TO_B 0,.lpw_access0,.early_out,.ppu_write_done

 DMA_TRANSFER_A_TO_B 1,.lpw_access1,.early_out,.ppu_write_done

 DMA_TRANSFER_A_TO_B 2,.lpw_access2,.early_out,.ppu_write_done

 DMA_TRANSFER_A_TO_B 3,.lpw_access3,.early_out,.loop_ppu_write,1
 jmp .ppu_write_done


EXPORT Relatch_HDMA_Channel
 mov ebx,[edi+A1T]      ; Src Address in ebx
 and ebx,BITMASK(0,23)

 mov al,[edi+DMAP]      ; Get HDMA control byte
 test al,0x40           ; Check for indirect addressing

 jnz HDMA_Indirect_Common.New_Set

 jmp HDMA_Absolute_Common.New_Set


HDMA_Absolute_Common:
.End_Transfer:
 mov [edi+A2T],ebx

.Continue:
 dec ah

 mov cl,0x80
 and cl,ah
 mov [edi+HDMA_Need_Transfer],cl

 mov [edi+NTRL],ah      ; Update number of lines to transfer
 test ah,0x7F
 jnz ..@HDMA_Channel_Exit

.New_Set:
 ; Need new set
 GET_BYTE 0

 inc bx                 ; Adjust table address
 mov [edi+NTRL],al      ; Save length of set
 mov [edi+A2T],ebx      ; Save new table address
 mov [edi+HDMA_Need_Transfer],al
 ; set carry flag if channel terminating
 cmp al,1
 ret

HDMA_Indirect_Common:
.End_Transfer:
 mov [edi+DAS],ebx

.Continue:
 dec ah

 mov cl,0x80
 and cl,ah
 mov [edi+HDMA_Need_Transfer],cl

 mov [edi+NTRL],ah      ; Update number of lines to transfer
 test ah,0x7F
 jnz ..@HDMA_Channel_Exit

 mov ebx,[edi+A2T]      ; Get table address
 and ebx,BITMASK(0,23)

.New_Set:
 ; Need new set
 GET_BYTE 0
 inc bx                 ; Adjust table address
 mov [edi+NTRL],al      ; Save length of set
 mov [edi+HDMA_Need_Transfer],al

 mov cl,al      ; save byte to check later

 GET_BYTE _5A22_SLOW_CYCLE      ; Address load low
 inc bx

 test cl,cl
 jz .End_Channel

 mov [edi+DASL],al
 GET_BYTE _5A22_SLOW_CYCLE      ; Address load high

 inc bx
 mov [edi+DASH],al
 mov [edi+A2T],ebx      ; Save new table address
..@HDMA_Channel_Exit:
 ; clear carry flag, channel not terminating
 clc

 ret

.End_Channel:
 shl eax,8
 mov [edi+A2T],ebx      ; Save new table address
 mov [edi+DAS],ax       ; Save broken indirect address

 ; set carry flag, channel terminating
 stc

 ret

%macro Generate_Do_HDMA_Channel 1
%ifidni %1,Read
%define _DHC_Transfer HDMA_TRANSFER_B_TO_A
%elifidni %1,Write
%define _DHC_Transfer HDMA_TRANSFER_A_TO_B
%else
%error Invalid argument to Generate_Do_HDMA_Channel
%endif

 test al,0x40           ; Check for indirect addressing
 jnz Do_HDMA_Indirect_%1

Do_HDMA_Absolute_%1:
 mov ebx,[edi+A2T]      ; Get table address
 and ebx,BITMASK(0,23)

 mov al,[edi+HDMA_Need_Transfer]
 test al,al             ; Need new transfer?
 jz HDMA_Absolute_Common.Continue

.Next_Transfer:
 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 _DHC_Transfer [edi+DMA_B0]

 cmp cl,2
 inc bx                 ; Adjust temporary table pointer
 jb HDMA_Absolute_Common.End_Transfer

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 _DHC_Transfer [edi+DMA_B1]

 cmp cl,4
 inc bx                 ; Adjust temporary table pointer
 jb HDMA_Absolute_Common.End_Transfer

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 _DHC_Transfer [edi+DMA_B2]

 inc bx

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 _DHC_Transfer [edi+DMA_B3]

 inc bx

 jmp HDMA_Absolute_Common.End_Transfer


Do_HDMA_Indirect_%1:
 mov al,[edi+HDMA_Need_Transfer]
 test al,al             ; Need new transfer?
 jz HDMA_Indirect_Common.Continue

.Next_Transfer:
 mov ebx,[edi+DAS]
 and ebx,BITMASK(0,23)

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 _DHC_Transfer [edi+DMA_B0]

 cmp cl,2
 inc bx                 ; Adjust temporary table pointer
 jb HDMA_Indirect_Common.End_Transfer

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 _DHC_Transfer [edi+DMA_B1]

 cmp cl,4
 inc bx                 ; Adjust temporary table pointer
 jb HDMA_Indirect_Common.End_Transfer

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 _DHC_Transfer [edi+DMA_B2]

 inc bx

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 _DHC_Transfer [edi+DMA_B3]

 inc bx

 jmp HDMA_Indirect_Common.End_Transfer

%undef _DHC_Transfer
%endmacro

ALIGNC
EXPORT Do_HDMA_Channel
 ; Overhead, also used for loading next NTRLx ($43xA)
 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE

 mov ah,[edi+NTRL]
 mov ecx,[edi+HDMA_Siz] ; Get HDMA transfer size

 mov al,[edi+DMAP]      ; Get HDMA control byte
 test al,0x80
 jnz Do_HDMA_Channel_Read

Do_HDMA_Channel_Write:
 Generate_Do_HDMA_Channel Write

HDMA_End_Channel:
 mov [edi+A2T],ebx
 clc
 ret

Do_HDMA_Channel_Read:
 Generate_Do_HDMA_Channel Read

ALIGNC
EXPORT SNES_W420C ; HDMAEN      ; Actually handled within screen core!
%ifdef NO_HDMA
 ret
%endif
 mov [HDMAEN],al

;mov [HDMAON],al
 ret

;macro for processing a channel during HDMA init
%macro RELATCH_HDMA_CHANNEL 1
 LOAD_DMA_TABLE %1
 test byte [HDMAEN],BIT(%1)
 mov byte [edi+HDMA_Need_Transfer],0
 jz %%no_relatch

 mov byte [In_DMA],(%1) | DMA_IN_PROGRESS
 call Relatch_HDMA_Channel
 jnc %%no_disable

 ; keep track of terminated channels
 and byte [HDMA_Not_Ended],~BIT(%1)

%%no_disable:
%%no_relatch:
%endmacro

channel_to_bit:db BIT(0),BIT(1),BIT(2),BIT(3),BIT(4),BIT(5),BIT(6),BIT(7)

extern EventTrip
extern cpu_65c816_PB_Shifted,cpu_65c816_PC
extern FixedTrip,Fixed_Event,EventTrip,Event_Handler
extern CPU_Execution_Mode
extern check_op

%macro debug_dma_output 1
%if 0
 pusha

 push dword [FixedTrip]
 push dword [Fixed_Event]
 push dword [EventTrip]
 push dword [Event_Handler]
 movzx eax,byte [CPU_Execution_Mode]
 push eax

 mov dword eax,[EventTrip]
 add dword eax,ebp
;GET_CYCLES eax
 push eax
 mov ebx,[cpu_65c816_PB_Shifted]
 add ebx,[cpu_65c816_PC]
 push ebx
 call check_op
 add esp,4*7

 cmp byte [MDMAEN],0
 jz %%no_dma

 push dword alert_str
 call print_str
 add esp,4

%%no_dma:
 push dword %1
 call print_str

 movzx eax,byte [MDMAEN]
 push byte 2
 push eax
 call print_hexnum

 push comma_str
 call print_str

 movzx eax,byte [HDMAEN]
 push byte 2
 push eax
 call print_hexnum

 push comma_str
 call print_str

 movzx eax,byte [HDMA_Not_Ended]
 push byte 2
 push eax
 call print_hexnum

 push at_str
 call print_str

 mov dword eax,[EventTrip]
 add dword eax,ebp
;GET_CYCLES eax
 push eax
 call print_decnum

 push comma_str
 call print_str

 push dword [Current_Line_Timing]
 call print_decnum

 push nl_str
 call print_str

 add esp,4*14
 popa
%endif
%endmacro

ALIGNC
EXPORT init_HDMA
 mov byte [HDMA_Not_Ended],BITMASK(0,7)

 mov al,[HDMAEN]
;mov [HDMAON],al
 test al,al
 jz .no_hdma

 debug_dma_output hdma_init1_str

 mov al,[In_DMA]
 push eax

 ;HDMA init/transfer on same channel as active general DMA stops general DMA
 test al,DMA_IN_PROGRESS
 jz .no_dma

 and eax,BITMASK(0,2)
 mov cl,[channel_to_bit+eax]
 mov al,[HDMAEN]
 test cl,al
 jz .no_conflict

 mov byte [DMA_Pending_B_Address],-1

.no_conflict:
 xor al,~0
 and [MDMAEN],al

.no_dma:
 debug_dma_output hdma_init2_str

 add R_65c816_Cycles,byte _5A22_FAST_CYCLE * 3  ; HDMA processing
 RELATCH_HDMA_CHANNEL 0
 RELATCH_HDMA_CHANNEL 1
 RELATCH_HDMA_CHANNEL 2
 RELATCH_HDMA_CHANNEL 3
 RELATCH_HDMA_CHANNEL 4
 RELATCH_HDMA_CHANNEL 5
 RELATCH_HDMA_CHANNEL 6
 RELATCH_HDMA_CHANNEL 7

 pop eax
 mov [In_DMA],al
.no_hdma:
 ret

ALIGNC
EXPORT do_HDMA
 mov al,[HDMAEN]
 and al,[HDMA_Not_Ended]
 test al,al
 jz .no_hdma

 add R_65c816_Cycles,byte _5A22_FAST_CYCLE * 3  ; HDMA processing
 push eax
 push ebx
 push ecx
 push edx
;push ebp   ;R_65c816_Cycles
 push esi
 push edi
 mov al,[In_DMA]
 push eax

 debug_dma_output hdma_xfer1_str

 ;HDMA init/transfer on same channel as active general DMA stops general DMA
 test al,DMA_IN_PROGRESS
 jz .no_dma

 and eax,BITMASK(0,2)
 mov cl,[channel_to_bit+eax]

 mov al,[HDMAEN]
 and al,[HDMA_Not_Ended]
 test cl,al
 jz .no_conflict

 mov byte [DMA_Pending_B_Address],-1

.no_conflict:
 xor al,~0
 and [MDMAEN],al

.no_dma:

 debug_dma_output hdma_xfer2_str

 HDMAOPERATION 0
 HDMAOPERATION 1
 HDMAOPERATION 2
 HDMAOPERATION 3
 HDMAOPERATION 4
 HDMAOPERATION 5
 HDMAOPERATION 6
 HDMAOPERATION 7

 pop eax
 mov [In_DMA],al
 pop edi
 pop esi
;pop ebp   ;R_65c816_Cycles
 pop edx
 pop ecx
 pop ebx
 pop eax
.no_hdma:
 ret

;called with edx = (DMA channel # * 4)
ALIGNC
DMA_Fix_B_Addresses:
 push eax
 push edi
 mov edi,[DMA_Data_Areas+edx]
 push ecx

 mov al,[edi+DMAP]
 and eax,byte 7

 mov dl,[HDMA_Size+eax]     ; Transfer size for HDMA
 mov cl,[edi+DMA_Vid]       ; PPU address in cl
 mov [edi+HDMA_Siz],dl
 lea eax,[DMA_PPU_Order+eax*4]
 mov dl,cl                  ; PPU address in dl
 add cl,[eax]
 mov [edi+DMA_B0],cl
 mov cl,dl                  ; PPU address in cl
 add dl,[eax+1]
 mov [edi+DMA_B1],dl
 mov dl,cl                  ; PPU address in dl
 add cl,[eax+2]
 mov [edi+DMA_B2],cl
 add dl,[eax+3]
 mov [edi+DMA_B3],dl

 pop ecx
 pop edi
 pop eax
 ret

; Requires %eax to be BITMASK(0,23)!
;%1 = num
%macro Reset_DMA_Channel 1
 mov [DMAP_%1],al
 mov [BBAD_%1],al
 mov [NTRL_%1],al
 mov [A1T_%1],eax
 mov [DAS_%1],eax
 mov [A2T_%1],eax

 mov byte [DMA_Inc_%1],0

 mov edx,%1 * 4
 call DMA_Fix_B_Addresses

%endmacro

EXPORT Reset_DMA
 ; Set eax to 0...
 xor eax,eax
 mov [MDMAEN],al
 mov [HDMAEN],al
;mov [HDMAON],al
 mov [In_DMA],al
 mov byte [DMA_Pending_B_Address],-1

 ; Now BITMASK(0,23)...
 mov eax,BITMASK(0,23)
 Reset_DMA_Channel 0
 Reset_DMA_Channel 1
 Reset_DMA_Channel 2
 Reset_DMA_Channel 3
 Reset_DMA_Channel 4
 Reset_DMA_Channel 5
 Reset_DMA_Channel 6
 Reset_DMA_Channel 7

 ; Back to 0...
 xor eax,eax
 ret

; Read from 43xx handlers
;%1 = num
%macro MAP_READ_DMA 1
ALIGNC
EXPORT MAP_READ_DMAP%1
 mov al,[DMAP_%1]
 ret

ALIGNC
EXPORT MAP_READ_BBAD%1
 mov al,[BBAD_%1]
 ret

ALIGNC
EXPORT MAP_READ_A1TL%1
 mov al,[A1TL_%1]
 ret

ALIGNC
EXPORT MAP_READ_A1TH%1
 mov al,[A1TH_%1]
 ret

ALIGNC
EXPORT MAP_READ_A1B%1
 mov al,[A1B_%1]
 ret

ALIGNC
EXPORT MAP_READ_DASL%1
 mov al,[DASL_%1]
 ret

ALIGNC
EXPORT MAP_READ_DASH%1
 mov al,[DASH_%1]
 ret

ALIGNC
EXPORT MAP_READ_DASB%1
 mov al,[DASB_%1]
 ret

ALIGNC
EXPORT MAP_READ_A2L%1
 mov al,[A2L_%1]
 ret

ALIGNC
EXPORT MAP_READ_A2H%1
 mov al,[A2H_%1]
 ret

ALIGNC
EXPORT MAP_READ_NTRL%1
 mov al,[NTRL_%1]
 ret
%endmacro

MAP_READ_DMA 0
MAP_READ_DMA 1
MAP_READ_DMA 2
MAP_READ_DMA 3
MAP_READ_DMA 4
MAP_READ_DMA 5
MAP_READ_DMA 6
MAP_READ_DMA 7

; Write to 43xx handlers
;%1 = num
%macro MAP_WRITE_DMA 1
ALIGNC
EXPORT MAP_WRITE_DMAP%1
 cmp [DMAP_%1],al
 je .no_change

 mov edx,ebx
 mov [DMAP_%1],al

 test al,8      ; Does the operation require address adjustment?
 mov bl,0
 jnz .set_adjustment

 dec ebx        ; Set address decrement
 test al,0x10
 jnz .set_adjustment

 add bl,2       ; Set address increment
.set_adjustment:
 mov [DMA_Inc_%1],bl

 mov ebx,edx
 shr edx,2
 and edx,byte 7*4
 jmp DMA_Fix_B_Addresses    ; It'll return for us

.no_change:
 ret

ALIGNC
EXPORT MAP_WRITE_BBAD%1
 cmp [BBAD_%1],al
 je .no_change
 mov [BBAD_%1],al

 mov edx,ebx
 shr edx,2
 and edx,byte 7*4
 jmp DMA_Fix_B_Addresses    ; It'll return for us

.no_change:
 ret

ALIGNC
EXPORT MAP_WRITE_A1TL%1
 mov [A1TL_%1],al
 ret

ALIGNC
EXPORT MAP_WRITE_A1TH%1
 mov [A1TH_%1],al
 ret

ALIGNC
EXPORT MAP_WRITE_A1B%1
 cmp [A1B_%1],al
 je .no_change

 mov [A1B_%1],al
 mov [A2B_%1],al
.no_change:
 ret

ALIGNC
EXPORT MAP_WRITE_DASL%1
 mov [DASL_%1],al
 ret

ALIGNC
EXPORT MAP_WRITE_DASH%1
 mov [DASH_%1],al
 ret

ALIGNC
EXPORT MAP_WRITE_DASB%1
 cmp [DASB_%1],al
 je .no_change

 mov [DASB_%1],al
.no_change:
 ret

ALIGNC
EXPORT MAP_WRITE_A2L%1
 mov [A2L_%1],al
 ret

ALIGNC
EXPORT MAP_WRITE_A2H%1
 mov [A2H_%1],al
 ret

ALIGNC
EXPORT MAP_WRITE_NTRL%1
 mov [NTRL_%1],al
 ret
%endmacro

MAP_WRITE_DMA 0
MAP_WRITE_DMA 1
MAP_WRITE_DMA 2
MAP_WRITE_DMA 3
MAP_WRITE_DMA 4
MAP_WRITE_DMA 5
MAP_WRITE_DMA 6
MAP_WRITE_DMA 7

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
