%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

; DMA.asm - (H)DMA emulation

;%define NO_HDMA
;%define LOG_HDMA_WRITES

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

; DMA_Wr#_x - These hold the write handlers for DMA
; DMA_Rd#_x - These hold the read handlers for DMA
; HDMA_Siz_x - These hold the register size for HDMA
DMA_Wr0_%1: skipl
DMA_Wr1_%1: skipl
DMA_Wr2_%1: skipl
DMA_Wr3_%1: skipl
DMA_Rd0_%1: skipl
DMA_Rd1_%1: skipl
DMA_Rd2_%1: skipl
DMA_Rd3_%1: skipl
DMA_B0_%1:  skipl
DMA_B1_%1:  skipl
DMA_B2_%1:  skipl
DMA_B3_%1:  skipl
HDMA_Siz_%1:skipl
%endmacro

DMA_DATA 0
DMA_DATA 1
DMA_DATA 2
DMA_DATA 3
DMA_DATA 4
DMA_DATA 5
DMA_DATA 6
DMA_DATA 7

EXPORT_C MDMAEN,skipb   ; DMA enable
EXPORT_C HDMAEN,skipb   ; HDMA enable
EXPORT HDMAON,skipb     ; HDMA enabled this refresh
                        ; 00dcccaa | d = in DMA/HDMA, if 0 all should be 0
EXPORT In_DMA,skipb     ; c = channel # 0-7 | a = address # 0-3
%define DMA_IN_PROGRESS 0x40

section .text
ALIGNC
%if 0
  al = data byte
  ebx = A-bus address
  ebp = DAS (byte count)
  esi = Address adjustment
%endif
EXPORT_C Do_DMA_Channel
 mov ebx,[edi+A1T]      ; CPU address in ebx
 and ebx,0x00FFFFFF

 xor ebp,ebp
 mov bp,[edi+DAS]
 dec ebp
 and ebp,0xFFFF
 inc ebp

;mov ecx,ebp
;shl ecx,3
;add [SNES_Cycles],ecx
  
 mov al,[edi+DMAP]
 xor ecx,ecx
 movsx esi,byte [edi+DMA_Inc]   ; Get address adjustment
 test al,al     ; Is the operation CPU->PPU?
 jns near .ppu_write

; PPU->CPU
;mov edi,edx
 and eax,byte 7
 lea eax,[DMA_PPU_Order+eax*4]
 mov cl,[edi+DMA_Vid]       ; PPU address in ecx
 mov edx,ecx                ; PPU address in edx
;add cl,[eax]
 mov ecx,[C_LABEL(Read_Map_21)+ecx*4]
 mov [edi+DMA_Rd0],ecx
 mov ecx,edx                ; PPU address in ecx
 add dl,[eax+1]
 mov edx,[C_LABEL(Read_Map_21)+edx*4]
 mov [edi+DMA_Rd1],edx
 mov edx,ecx                ; PPU address in edx
 add cl,[eax+2]
 mov ecx,[C_LABEL(Read_Map_21)+ecx*4]
 mov [edi+DMA_Rd2],ecx
 add dl,[eax+3]
 mov edx,[C_LABEL(Read_Map_21)+edx*4]
 mov [edi+DMA_Rd3],edx
;mov edx,edi

 cmp ebp,byte 4
 jb near .lpr_less_than_4

.loop_ppu_read:
 call [edi+DMA_Rd0]
 SET_BYTE
.ppu_read_check_0:
 add bx,si

 call [edi+DMA_Rd1]
 SET_BYTE
.ppu_read_check_1:
 add bx,si

 call [edi+DMA_Rd2]
 SET_BYTE
.ppu_read_check_2:
 add bx,si

 call [edi+DMA_Rd3]
 SET_BYTE
.ppu_read_check_3:
 add bx,si
 sub ebp,byte 4
 jz near .ppu_read_done
 cmp ebp,byte 4
 jnb near .loop_ppu_read

.lpr_less_than_4:
 call [edi+DMA_Rd0]
 SET_BYTE
.ppu_read_lt4_check_0:
 add bx,si
 dec ebp
 jz near .ppu_read_done

 call [edi+DMA_Rd1]
 SET_BYTE
.ppu_read_lt4_check_1:
 add bx,si
 dec ebp
 jz near .ppu_read_done
;jz .ppu_read_done ;*set_byte

 call [edi+DMA_Rd2]
 SET_BYTE
.ppu_read_lt4_check_2:
 add bx,si
 dec ebp
 jz .ppu_read_done

 call [edi+DMA_Rd3]
 SET_BYTE
.ppu_read_lt4_check_3:
 add bx,si
 dec ebp
 jnz near .loop_ppu_read

.ppu_read_done:
 mov [edi+A1T],bx       ; v0.15 forgot to update DMA pointers!
 mov word [edi+DAS],bp
 ret

ALIGNC
; CPU->PPU
.ppu_write:
;mov edi,edx
 and eax,byte 7
 lea eax,[DMA_PPU_Order+eax*4]
 mov cl,[DMA_Vid+edi]       ; PPU address in ecx
 mov edx,ecx                ; PPU address in edx
;add cl,[eax]
 mov ecx,[C_LABEL(Write_Map_21)+ecx*4]
 mov [edi+DMA_Wr0],ecx
 mov ecx,edx                ; PPU address in ecx
 add dl,[eax+1]
 mov edx,[C_LABEL(Write_Map_21)+edx*4]
 mov [edi+DMA_Wr1],edx
 mov edx,ecx                ; PPU address in edx
 add cl,[eax+2]
 mov ecx,[C_LABEL(Write_Map_21)+ecx*4]
 mov [edi+DMA_Wr2],ecx
 add dl,[eax+3]
 mov edx,[C_LABEL(Write_Map_21)+edx*4]
 mov [edi+DMA_Wr3],edx
;mov edx,edi

 cmp ebp,byte 4
 jb near .lpw_less_than_4

.loop_ppu_write:
 GET_BYTE
 call [edi+DMA_Wr0]
.ppu_write_check_0:
 add bx,si

 GET_BYTE
 call [edi+DMA_Wr1]
.ppu_write_check_1:
 add bx,si

 GET_BYTE
 call [edi+DMA_Wr2]
.ppu_write_check_2:
 add bx,si

 GET_BYTE
 call [edi+DMA_Wr3]
.ppu_write_check_3:
 add bx,si

 sub ebp,byte 4
 jz near .ppu_write_done
 cmp ebp,byte 4
 jnb near .loop_ppu_write

.lpw_less_than_4:
 GET_BYTE
 call [edi+DMA_Wr0]
.ppu_write_lt4_check_0:
 add bx,si
 dec ebp
 jz near .ppu_write_done

 GET_BYTE
 call [edi+DMA_Wr1]
.ppu_write_lt4_check_1:
 add bx,si
 dec ebp
 jz .ppu_write_done

 GET_BYTE
 call [edi+DMA_Wr2]
.ppu_write_lt4_check_2:
 add bx,si
 dec ebp
 jz .ppu_write_done

 GET_BYTE
 call [edi+DMA_Wr3]
.ppu_write_lt4_check_3:
 add bx,si
 dec ebp
 jnz near .loop_ppu_write

.ppu_write_done:
 mov [edi+A1T],bx       ; v0.15 forgot to update DMA pointers!
 mov word [edi+DAS],bp
.abort_channel:
 ret

ALIGNC
EXPORT_C Do_HDMA_Channel
 mov ebx,[edi+A2T]      ; Get table address
 and ebx,0x00FFFFFF
 mov al,[edi+DMAP]      ; Get HDMA control byte
 test al,0x40           ; Check for indirect addressing
 mov ecx,[edi+HDMA_Siz] ; Get HDMA transfer size
 jnz near Do_HDMA_Indirect

Do_HDMA_Absolute:
 mov ah,[edi+NTRL]      ; Get number of lines to transfer
 test ah,0x7F           ; Need new set?
 jz .Next_Set
 test ah,ah
 js .Next_Transfer
 jmp .Continue

.Next_Set:
 GET_BYTE
 inc bx                 ; Adjust table address
 test al,al             ; Check for zero-length set
 mov [edi+NTRL],al      ; Save length of set
 jz near HDMA_End_Channel
 mov [edi+A2T],ebx      ; Save new table address

.Next_Transfer:
 GET_BYTE
%ifdef LOG_HDMA_WRITES
 pusha
 mov bl,[edi+DMA_Vid]
 push eax
 push ebx
extern C_LABEL(hdma_write__FUcUc)
 call C_LABEL(hdma_write__FUcUc)
 add esp,8
 popa
%endif
 call [edi+DMA_Wr0]
 add dword [C_LABEL(SNES_Cycles)],byte 8   ; HDMA transfer
 cmp cl,2
 inc bx                 ; Adjust temporary table pointer
;jb .End_Transfer
 jb near .End_Transfer

 GET_BYTE
%ifdef LOG_HDMA_WRITES
 pusha
 push eax
 mov al,[edi+DMAP]
 mov bl,[edi+DMA_Vid]
 and eax,byte 7
 add bl,[DMA_PPU_Order+eax*4+1]
 push ebx
 call C_LABEL(hdma_write__FUcUc)
 add esp,8
 popa
%endif
 call [edi+DMA_Wr1]
 add dword [C_LABEL(SNES_Cycles)],byte 8   ; HDMA transfer
 cmp cl,4
 inc bx                 ; Adjust temporary table pointer
;jb .End_Transfer
 jb near .End_Transfer

 GET_BYTE
%ifdef LOG_HDMA_WRITES
 pusha
 push eax
 mov al,[edi+DMAP]
 mov bl,[edi+DMA_Vid]
 and eax,byte 7
 add bl,[DMA_PPU_Order+eax*4+2]
 push ebx
 call C_LABEL(hdma_write__FUcUc)
 add esp,8
 popa
%endif
 call [edi+DMA_Wr2]
 add dword [C_LABEL(SNES_Cycles)],byte 8   ; HDMA transfer
 inc bx

 GET_BYTE
%ifdef LOG_HDMA_WRITES
 pusha
 push eax
 mov al,[edi+DMAP]
 mov bl,[edi+DMA_Vid]
 and eax,byte 7
 add bl,[DMA_PPU_Order+eax*4+3]
 push ebx
 call C_LABEL(hdma_write__FUcUc)
 add esp,8
 popa
%endif
 call [edi+DMA_Wr3]
 add dword [C_LABEL(SNES_Cycles)],byte 8   ; HDMA transfer

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
 js near .Next_Transfer
 jmp .Continue

.Next_Set:
 GET_BYTE
 inc bx
 mov [edi+NTRL],al
 test al,al
 jz HDMA_End_Channel

 mov ah,al
 GET_BYTE
 add dword [C_LABEL(SNES_Cycles)],byte 8   ; Address load low
 inc bx
 mov [edi+DASL],al
 GET_BYTE
 add dword [C_LABEL(SNES_Cycles)],byte 8   ; Address load high
 inc bx
 mov [edi+DASH],al
 mov [edi+A2T],ebx
.Next_Transfer:
 mov ebx,[edi+DAS]
 and ebx,0x00FFFFFF

 GET_BYTE
%ifdef LOG_HDMA_WRITES
 pusha
 mov bl,[edi+DMA_Vid]
 push eax
 push ebx
 call C_LABEL(hdma_write__FUcUc)
 add esp,8
 popa
%endif
 call [edi+DMA_Wr0]
 add dword [C_LABEL(SNES_Cycles)],byte 8   ; HDMA transfer
 cmp cl,2
 inc bx                 ; Adjust temporary table pointer
;jb .End_Transfer
 jb near .End_Transfer

 GET_BYTE
%ifdef LOG_HDMA_WRITES
 pusha
 push eax
 mov al,[edi+DMAP]
 mov bl,[edi+DMA_Vid]
 and eax,byte 7
 add bl,[DMA_PPU_Order+eax*4+1]
 push ebx
 call C_LABEL(hdma_write__FUcUc)
 add esp,8
 popa
%endif
 call [edi+DMA_Wr1]
 add dword [C_LABEL(SNES_Cycles)],byte 8   ; HDMA transfer
 cmp cl,4
 inc bx                 ; Adjust temporary table pointer
;jb .End_Transfer
 jb near .End_Transfer

 GET_BYTE
%ifdef LOG_HDMA_WRITES
 pusha
 push eax
 mov al,[edi+DMAP]
 mov bl,[edi+DMA_Vid]
 and eax,byte 7
 add bl,[DMA_PPU_Order+eax*4+2]
 push ebx
 call C_LABEL(hdma_write__FUcUc)
 add esp,8
 popa
%endif
 call [edi+DMA_Wr2]
 add dword [C_LABEL(SNES_Cycles)],byte 8   ; HDMA transfer
 inc bx

 GET_BYTE
%ifdef LOG_HDMA_WRITES
 pusha
 push eax
 mov al,[edi+DMAP]
 mov bl,[edi+DMA_Vid]
 and eax,byte 7
 add bl,[DMA_PPU_Order+eax*4+3]
 push ebx
 call C_LABEL(hdma_write__FUcUc)
 add esp,8
 popa
%endif
 call [edi+DMA_Wr3]
 add dword [C_LABEL(SNES_Cycles)],byte 8   ; HDMA transfer

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
 push ebp
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
 pop ebp
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
 jz near .no_hdma
 push eax
 push ebx
 push ecx
 push edx
 push ebp
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
 pop ebp
 pop edx
 pop ecx
 pop ebx
 pop eax
.no_hdma:
 ret

; Requires %eax to be 0x00FFFFFF!
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
 mov [DMA_Rd0_%1],ebx
 mov [DMA_Wr0_%1],ecx
 mov [DMA_Rd1_%1],ebx
 mov [DMA_Wr1_%1],ecx
 mov [DMA_Rd2_%1],ebx
 mov [DMA_Wr2_%1],ecx
 mov [DMA_Rd3_%1],ebx
 mov [DMA_Wr3_%1],ecx
 pop ecx
 pop ebx

 mov byte [DMA_Inc_%1],0
%endmacro

EXPORT Reset_DMA
 ; Set eax to 0...
 xor eax,eax
 mov [C_LABEL(MDMAEN)],al
 mov [C_LABEL(HDMAEN)],al
 mov [HDMAON],al
 mov [In_DMA],al

 ; Now 0x00FFFFFF...
 mov eax,0x00FFFFFF
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

ALIGNC
EXPORT_C Update_DMA_PPU_Handlers
 cmp byte [In_DMA],0
 jz near Update_DMA_PPU_Handlers_Specific.not_in_dma
 movzx edx,byte [In_DMA]
 and edx,(7 << 2)
Update_DMA_PPU_Handlers_Specific:
 push eax
 push ebx
 push ecx
 push edi
 mov edi,[DMA_Data_Areas+edx]
 xor ecx,ecx
 mov al,[edi+DMAP]
 and eax,byte 7
 mov cl,[edi+DMA_Vid]   ; PPU address in ecx
 mov dl,[HDMA_Size+eax]
 lea eax,[DMA_PPU_Order+eax*4]
 mov [edi+HDMA_Siz],dl
 mov edx,ecx            ; PPU address in edx
;add cl,[eax]
 mov ebx,[C_LABEL(Read_Map_21)+ecx*4]
 mov ecx,[C_LABEL(Write_Map_21)+ecx*4]
 mov [edi+DMA_Rd0],ebx
 mov [edi+DMA_Wr0],ecx
 mov ecx,edx            ; PPU address in ecx
 add dl,[eax+1]
 mov ebx,[C_LABEL(Read_Map_21)+edx*4]
 mov edx,[C_LABEL(Write_Map_21)+edx*4]
 mov [edi+DMA_Rd1],ebx
 mov [edi+DMA_Wr1],edx
 mov edx,ecx            ; PPU address in edx
 add cl,[eax+2]
 mov ebx,[C_LABEL(Read_Map_21)+ecx*4]
 mov ecx,[C_LABEL(Write_Map_21)+ecx*4]
 mov [edi+DMA_Rd2],ebx
 mov [edi+DMA_Wr2],ecx
 add dl,[eax+3]
 mov ebx,[C_LABEL(Read_Map_21)+edx*4]
 mov edx,[C_LABEL(Write_Map_21)+edx*4]
 mov [edi+DMA_Rd3],ebx
 mov [edi+DMA_Wr3],edx
 pop edi
 pop ecx
 pop ebx
 pop eax
.not_in_dma:
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

 push ebx
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

 pop ebx
 shr edx,2
 and edx,byte 7*4
 jmp Update_DMA_PPU_Handlers_Specific   ; It'll return for us

.no_change:
 ret

ALIGNC
EXPORT MAP_WRITE_BBAD%1
 cmp [C_LABEL(BBAD_%1)],al
 je .no_change
 mov [C_LABEL(BBAD_%1)],al
 shr edx,2
 and edx,byte 7*4
 jmp Update_DMA_PPU_Handlers_Specific   ; It'll return for us

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
