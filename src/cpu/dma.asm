%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

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
EXTERN_C SNES_Cycles

section .text
EXPORT_C DMA_text_start
section .data
EXPORT_C DMA_data_start
section .bss
EXPORT_C DMA_bss_start

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
TableDMA%1:
; dh0bcttt d=CPU->PPU,h=addr,b=inc/dec,c=inc/fixed,t=type
EXPORT_C DMAP_%1    ,skipb
EXPORT_C BBAD_%1    ; Low byte of 0x21??
EXPORT DMA_Vid_%1   ,skipb
EXPORT NTRL_%1,skipb
DMA_Inc_%1: skipb
EXPORT A1T_%1       ; Source Address L/H/B
EXPORT_C A1TL_%1,skipb  ; Source Address L
EXPORT_C A1TH_%1,skipb  ; Source Address H
EXPORT_C A1B_%1 ,skipb  ; Source Bank Address
                 skipb
EXPORT DAS_%1       ; Data Size L/H
EXPORT_C DASL_%1,skipb  ; Data Size L
EXPORT_C DASH_%1,skipb  ; Data Size H
EXPORT_C DASB_%1,skipb  ; Data address bank
                 skipb
EXPORT A2T_%1
EXPORT_C A2L_%1 ,skipb  ; HDMA table address L
EXPORT_C A2H_%1 ,skipb  ; HDMA table address H
EXPORT_C A2B_%1 ,skipb  ; HDMA table bank address
                 skipb

; HDMA_Siz_x - These hold the register size for HDMA
HDMA_Siz_%1:skipl

; DMA_By_x - B bus address for access y of 0-3
DMA_B0_%1:  skipb
DMA_B1_%1:  skipb
DMA_B2_%1:  skipb
DMA_B3_%1:  skipb
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

EXPORT_C MDMAEN,skipb   ; DMA enable
EXPORT_C HDMAEN,skipb   ; HDMA enable
EXPORT HDMAON,skipb     ; HDMA enabled this refresh
                        ; 00dcccaa | d = in DMA/HDMA, if 0 all should be 0
EXPORT In_DMA,skipb     ; c = channel # 0-7 | a = address # 0-3
%define DMA_IN_PROGRESS 0x40

section .text
;macro for getting A bus alias for B bus address for DMA access
%macro GET_B_BUS_ADDRESS 1
 movzx ebx,byte %1
 add ebx,0x2100
%endmacro

;macro for reading a byte without affecting timing - for parallel/fixed
; speed accesses (DMA)
%macro GET_BYTE_NO_UPDATE_CYCLES 0
 push R_65c816_Cycles
 GET_BYTE
 pop R_65c816_Cycles
%endmacro

;macro for writing a byte without affecting timing - for parallel/fixed
; speed accesses (DMA)
%macro SET_BYTE_NO_UPDATE_CYCLES 0
 push R_65c816_Cycles
 SET_BYTE
 pop R_65c816_Cycles
%endmacro

;macro for performing DMA B bus accesses
%macro ACCESS_B_BUS 2
 push ebx
 GET_B_BUS_ADDRESS %2
 %1
 pop ebx
%endmacro

;macro for DMA reads from B bus
%macro GET_BYTE_B_BUS 1
 ACCESS_B_BUS GET_BYTE_NO_UPDATE_CYCLES,%1
%endmacro

;macro for DMA writes to B bus
%macro SET_BYTE_B_BUS 1
 ACCESS_B_BUS SET_BYTE_NO_UPDATE_CYCLES,%1
%endmacro

;macro for HDMA transfers, and DMA transfers in PPU write mode
%macro TRANSFER_A_TO_B 1
 GET_BYTE_NO_UPDATE_CYCLES
 SET_BYTE_B_BUS %1
%endmacro

;macro for DMA transfers in PPU read mode
%macro TRANSFER_B_TO_A 1
 GET_BYTE_B_BUS %1
 SET_BYTE_NO_UPDATE_CYCLES
%endmacro


ALIGNC
%if 0
  al = data byte
  ebx = A-bus address
  [DMA_Transfer_Size] = DAS (byte count)
  esi = Address adjustment
%endif
EXPORT_C Do_DMA_Channel
 mov ebx,[edi+A1T]      ; CPU address in ebx
 and ebx,(1 << 24) - 1

 movzx ecx,word [edi+DAS]
 dec ecx
 and ecx,(1 << 16) - 1
 inc ecx
 mov [DMA_Transfer_Size],ecx

;mov ecx,ebp
;shl ecx,3
;add [SNES_Cycles],ecx
  
 mov al,[edi+DMAP]
 xor ecx,ecx
 movsx esi,byte [edi+DMA_Inc]   ; Get address adjustment
 test al,al     ; Is the operation CPU->PPU?
 jns .ppu_write

; PPU->CPU
 cmp dword [DMA_Transfer_Size],byte 4
 jb .lpr_less_than_4

.loop_ppu_read:
 TRANSFER_B_TO_A [edi+DMA_B0]
 add bx,si

 TRANSFER_B_TO_A [edi+DMA_B1]
 add bx,si

 TRANSFER_B_TO_A [edi+DMA_B2]
 add bx,si

 TRANSFER_B_TO_A [edi+DMA_B3]
 add bx,si
 sub dword [DMA_Transfer_Size],byte 4
 jz .ppu_read_done
 cmp dword [DMA_Transfer_Size],byte 4
 jnb .loop_ppu_read

.lpr_less_than_4:
 TRANSFER_B_TO_A [edi+DMA_B0]
 add bx,si
 dec dword [DMA_Transfer_Size]
 jz .ppu_read_done

 TRANSFER_B_TO_A [edi+DMA_B1]
 add bx,si
 dec dword [DMA_Transfer_Size]
 jz .ppu_read_done

 TRANSFER_B_TO_A [edi+DMA_B2]
 add bx,si
 dec dword [DMA_Transfer_Size]
 jz .ppu_read_done

 TRANSFER_B_TO_A [edi+DMA_B3]
 add bx,si
 dec dword [DMA_Transfer_Size]
 jnz .loop_ppu_read

.ppu_read_done:
 mov eax,[DMA_Transfer_Size]
 mov [edi+A1T],bx       ; v0.15 forgot to update DMA pointers!
 mov word [edi+DAS],ax
 ret

ALIGNC
; CPU->PPU
.ppu_write:
 cmp dword [DMA_Transfer_Size],byte 4
 jb .lpw_less_than_4

.loop_ppu_write:
 TRANSFER_A_TO_B [edi+DMA_B0]
 add bx,si

 TRANSFER_A_TO_B [edi+DMA_B1]
 add bx,si

 TRANSFER_A_TO_B [edi+DMA_B2]
 add bx,si

 TRANSFER_A_TO_B [edi+DMA_B3]
 add bx,si

 sub dword [DMA_Transfer_Size],byte 4
 jz .ppu_write_done
 cmp dword [DMA_Transfer_Size],byte 4
 jnb .loop_ppu_write

.lpw_less_than_4:
 TRANSFER_A_TO_B [edi+DMA_B0]
 add bx,si
 dec dword [DMA_Transfer_Size]
 jz .ppu_write_done

 TRANSFER_A_TO_B [edi+DMA_B1]
 add bx,si
 dec dword [DMA_Transfer_Size]
 jz .ppu_write_done

 TRANSFER_A_TO_B [edi+DMA_B2]
 add bx,si
 dec dword [DMA_Transfer_Size]
 jz .ppu_write_done

 TRANSFER_A_TO_B [edi+DMA_B3]
 add bx,si
 dec dword [DMA_Transfer_Size]
 jnz .loop_ppu_write

.ppu_write_done:
 mov eax,[DMA_Transfer_Size]
 mov [edi+A1T],bx       ; v0.15 forgot to update DMA pointers!
 mov word [edi+DAS],ax
.abort_channel:
 ret

ALIGNC
EXPORT_C Do_HDMA_Channel
 mov ebx,[edi+A2T]      ; Get table address
 and ebx,(1 << 24) - 1
 mov al,[edi+DMAP]      ; Get HDMA control byte
 test al,0x40           ; Check for indirect addressing
 mov ecx,[edi+HDMA_Siz] ; Get HDMA transfer size
 jnz Do_HDMA_Indirect

Do_HDMA_Absolute:
 mov ah,[edi+NTRL]      ; Get number of lines to transfer
 test ah,0x7F           ; Need new set?
 jz .Next_Set
 test ah,ah
 js .Next_Transfer
 jmp .Continue

.Next_Set:
 GET_BYTE_NO_UPDATE_CYCLES
 inc bx                 ; Adjust table address
 test al,al             ; Check for zero-length set
 mov [edi+NTRL],al      ; Save length of set
 jz HDMA_End_Channel
 mov [edi+A2T],ebx      ; Save new table address

.Next_Transfer:
 TRANSFER_A_TO_B [edi+DMA_B0]

 add R_65c816_Cycles,byte 8     ; HDMA transfer
 cmp cl,2
 inc bx                 ; Adjust temporary table pointer
 jb .End_Transfer

 TRANSFER_A_TO_B [edi+DMA_B1]

 add R_65c816_Cycles,byte 8     ; HDMA transfer
 cmp cl,4
 inc bx                 ; Adjust temporary table pointer
 jb .End_Transfer

 TRANSFER_A_TO_B [edi+DMA_B2]

 add R_65c816_Cycles,byte 8     ; HDMA transfer
 inc bx

 TRANSFER_A_TO_B [edi+DMA_B3]

 add R_65c816_Cycles,byte 8     ; HDMA transfer

.End_Transfer:
 add [edi+A2T],cx
.Continue:
 dec byte [edi+NTRL]
 stc
 ret

HDMA_End_Channel:
 mov [edi+A2T],ebx
 clc
 ret

Do_HDMA_Indirect:
 mov ah,[edi+NTRL]      ; Get number of lines to transfer
 test ah,0x7F
 jz  .Next_Set
 test ah,ah
 js .Next_Transfer
 jmp .Continue

.Next_Set:
 GET_BYTE_NO_UPDATE_CYCLES
 inc bx
 mov [edi+NTRL],al
 test al,al
 jz HDMA_End_Channel

 mov ah,al
 GET_BYTE_NO_UPDATE_CYCLES
 add R_65c816_Cycles,byte 8     ; Address load low
 inc bx
 mov [edi+DASL],al
 GET_BYTE_NO_UPDATE_CYCLES
 add R_65c816_Cycles,byte 8     ; Address load high
 inc bx
 mov [edi+DASH],al
 mov [edi+A2T],ebx
.Next_Transfer:
 mov ebx,[edi+DAS]
 and ebx,(1 << 24) - 1

 TRANSFER_A_TO_B [edi+DMA_B0]

 add R_65c816_Cycles,byte 8     ; HDMA transfer
 cmp cl,2
 inc bx                 ; Adjust temporary table pointer
 jb .End_Transfer

 TRANSFER_A_TO_B [edi+DMA_B1]

 add R_65c816_Cycles,byte 8     ; HDMA transfer
 cmp cl,4
 inc bx                 ; Adjust temporary table pointer
 jb .End_Transfer

 TRANSFER_A_TO_B [edi+DMA_B2]

 add R_65c816_Cycles,byte 8     ; HDMA transfer
 inc bx

 TRANSFER_A_TO_B [edi+DMA_B3]

 add R_65c816_Cycles,byte 8     ; HDMA transfer

.End_Transfer:
 add [edi+DAS],cx
.Continue:
 dec byte [edi+NTRL]
 stc
 ret

;%1 = num
%macro DMAOPERATION 1
 mov al,[C_LABEL(MDMAEN)]
 test al,1 << (%1)
 jz %%no_dma

 mov byte [In_DMA],((%1) << 2) | DMA_IN_PROGRESS
 LOAD_DMA_TABLE %1
 call C_LABEL(Do_DMA_Channel)
%%no_dma:
%endmacro

ALIGNC
EXPORT SNES_R420B ; MDMAEN
 mov al,0
 ret

ALIGNC
EXPORT SNES_R420C ; HDMAEN
 mov al,[HDMAON]
 ret

ALIGNC
EXPORT SNES_W420B ; MDMAEN
%if 0
 push eax
 push ecx
;push edx
 or eax,~0xFF
 push eax
extern C_LABEL(Dump_DMA)
 call C_LABEL(Dump_DMA)
 add esp,byte 4
;pop edx
 pop ecx
 pop eax
%endif
 mov [C_LABEL(MDMAEN)],al
%ifdef NO_DMA
 ret
%endif
;mov [SNES_Cycles],R_65c816_Cycles  ;
 push eax
 push ebx
 push ecx
 push edi
;push ebp   ;R_65c816_Cycles
 push esi

 mov al,[In_CPU]
 push eax
; Need to save/restore CPU core register set here if in use
 mov byte [In_CPU],0

 DMAOPERATION 0
 DMAOPERATION 1
 DMAOPERATION 2
 DMAOPERATION 3
 DMAOPERATION 4
 DMAOPERATION 5
 DMAOPERATION 6
 DMAOPERATION 7
 mov byte [In_DMA],0

 pop eax
 mov [In_CPU],al

 pop esi
;pop ebp    ;R_65c816_Cycles
 pop edi
 pop ecx
 pop ebx
 pop eax

;mov R_65c816_Cycles,[SNES_Cycles] ;
 ret

ALIGNC
EXPORT SNES_W420C ; HDMAEN      ; Actually handled within screen core!
%ifdef NO_HDMA
 ret
%endif
 mov [C_LABEL(HDMAEN)],al
;ret

 mov [HDMAON],al
 ret

ALIGNC
EXPORT do_HDMA
 mov al,[HDMAON]
 test al,al
 jz .no_hdma
 push eax
 push ebx
 push ecx
 push edx
;push ebp   ;R_65c816_Cycles
 push esi
 push edi
 mov al,[In_DMA]
 push eax
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

; Requires %eax to be (1 << 24) - 1!
;%1 = num
%macro Reset_DMA_Channel 1
 mov [C_LABEL(DMAP_%1)],al
 mov [C_LABEL(BBAD_%1)],al
 mov [NTRL_%1],al
 mov [A1T_%1],eax
 mov [DAS_%1],eax
 mov [A2T_%1],eax

 push ebx
 push ecx
 mov ebx,C_LABEL(UNSUPPORTED_READ)
 mov ecx,C_LABEL(UNSUPPORTED_WRITE)
 pop ecx
 pop ebx

 mov byte [DMA_Inc_%1],0

 mov edx,%1 * 4
 call DMA_Fix_B_Addresses

%endmacro

EXPORT Reset_DMA
 ; Set eax to 0...
 xor eax,eax
 mov [C_LABEL(MDMAEN)],al
 mov [C_LABEL(HDMAEN)],al
 mov [HDMAON],al
 mov [In_DMA],al

 ; Now (1 << 24) - 1...
 mov eax,(1 << 24) - 1
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
 mov al,[C_LABEL(DMAP_%1)]
 ret

ALIGNC
EXPORT MAP_READ_BBAD%1
 mov al,[C_LABEL(BBAD_%1)]
 ret

ALIGNC
EXPORT MAP_READ_A1TL%1
 mov al,[C_LABEL(A1TL_%1)]
 ret

ALIGNC
EXPORT MAP_READ_A1TH%1
 mov al,[C_LABEL(A1TH_%1)]
 ret

ALIGNC
EXPORT MAP_READ_A1B%1
 mov al,[C_LABEL(A1B_%1)]
 ret

ALIGNC
EXPORT MAP_READ_DASL%1
 mov al,[C_LABEL(DASL_%1)]
 ret

ALIGNC
EXPORT MAP_READ_DASH%1
 mov al,[C_LABEL(DASH_%1)]
 ret

ALIGNC
EXPORT MAP_READ_DASB%1
 mov al,[C_LABEL(DASB_%1)]
 ret

ALIGNC
EXPORT MAP_READ_A2L%1
 mov al,[C_LABEL(A2L_%1)]
 ret

ALIGNC
EXPORT MAP_READ_A2H%1
 mov al,[C_LABEL(A2H_%1)]
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
 cmp [C_LABEL(DMAP_%1)],al
 je .no_change

 mov edx,ebx
 mov [C_LABEL(DMAP_%1)],al

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
 cmp [C_LABEL(BBAD_%1)],al
 je .no_change
 mov [C_LABEL(BBAD_%1)],al

 mov edx,ebx
 shr edx,2
 and edx,byte 7*4
 jmp DMA_Fix_B_Addresses    ; It'll return for us

.no_change:
 ret

ALIGNC
EXPORT MAP_WRITE_A1TL%1
 mov [C_LABEL(A1TL_%1)],al
 ret

ALIGNC
EXPORT MAP_WRITE_A1TH%1
 mov [C_LABEL(A1TH_%1)],al
 ret

ALIGNC
EXPORT MAP_WRITE_A1B%1
 cmp [C_LABEL(A1B_%1)],al
 je .no_change

 mov [C_LABEL(A1B_%1)],al
 mov [C_LABEL(A2B_%1)],al
.no_change:
 ret

ALIGNC
EXPORT MAP_WRITE_DASL%1
 mov [C_LABEL(DASL_%1)],al
 ret

ALIGNC
EXPORT MAP_WRITE_DASH%1
 mov [C_LABEL(DASH_%1)],al
 ret

ALIGNC
EXPORT MAP_WRITE_DASB%1
 cmp [C_LABEL(DASB_%1)],al
 je .no_change

 mov [C_LABEL(DASB_%1)],al
.no_change:
 ret

ALIGNC
EXPORT MAP_WRITE_A2L%1
 mov [C_LABEL(A2L_%1)],al
 ret

ALIGNC
EXPORT MAP_WRITE_A2H%1
 mov [C_LABEL(A2H_%1)],al
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
