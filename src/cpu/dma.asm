%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2005, Charles Bilyue'.
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
EXPORT TableDMA%1
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

;macro for HDMA transfers
%macro HDMA_TRANSFER_A_TO_B 1
 GET_BYTE 0
 SET_BYTE_B_BUS %1,0
%endmacro


;macro for DMA transfers in PPU write mode
%macro DMA_TRANSFER_A_TO_B 3
 GET_BYTE 0
 mov [DMA_Pending_Data],al
 mov byte [DMA_Pending_B_Address],%1

 test R_65c816_Cycles,R_65c816_Cycles
 jge %3
%2:

 SET_BYTE_B_BUS [edi+DMA_B%1],_5A22_SLOW_CYCLE
%endmacro

;macro for DMA transfers in PPU read mode
%macro DMA_TRANSFER_B_TO_A 3
 GET_BYTE_B_BUS [edi+DMA_B%1],0
 mov [DMA_Pending_Data],al
 mov byte [DMA_Pending_B_Address],%1

 test R_65c816_Cycles,R_65c816_Cycles
 jge %3
%2:

 SET_BYTE _5A22_SLOW_CYCLE
%endmacro


;macro for processing a channel during HDMA transfer
%macro HDMAOPERATION 1
  mov al,[HDMAON]
  test al,(1<<%1)
  jz %%no_hdma

  add dword R_65c816_Cycles,byte 8  ; HDMA processing

  mov byte [In_DMA],(%1) | DMA_IN_PROGRESS
  LOAD_DMA_TABLE %1
  call C_LABEL(Do_HDMA_Channel) ; CF clear if channel disabled

  jc %%no_hdma
  and byte [HDMAON],~(1<<%1)    ; Disable this channel
%%no_hdma:
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
 DMA_TRANSFER_B_TO_A 0,.lpr_access0,.early_out
 add bx,si
 dec dword [DMA_Transfer_Size]
 jz .ppu_read_done

 DMA_TRANSFER_B_TO_A 1,.lpr_access1,.early_out
 add bx,si
 dec dword [DMA_Transfer_Size]
 jz .ppu_read_done

 DMA_TRANSFER_B_TO_A 2,.lpr_access2,.early_out
 add bx,si
 dec dword [DMA_Transfer_Size]
 jz .ppu_read_done

 DMA_TRANSFER_B_TO_A 3,.lpr_access3,.early_out
 add bx,si
 dec dword [DMA_Transfer_Size]
 jnz .loop_ppu_read

.ppu_read_done:
.ppu_write_done:
 mov byte [In_DMA],0
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
 DMA_TRANSFER_A_TO_B 0,.lpw_access0,.early_out
 add bx,si
 dec dword [DMA_Transfer_Size]
 jz .ppu_write_done

 DMA_TRANSFER_A_TO_B 1,.lpw_access1,.early_out
 add bx,si
 dec dword [DMA_Transfer_Size]
 jz .ppu_write_done

 DMA_TRANSFER_A_TO_B 2,.lpw_access2,.early_out
 add bx,si
 dec dword [DMA_Transfer_Size]
 jz .ppu_write_done

 DMA_TRANSFER_A_TO_B 3,.lpw_access3,.early_out
 add bx,si
 dec dword [DMA_Transfer_Size]
 jnz .loop_ppu_write
 jmp .ppu_write_done


ALIGNC
EXPORT_C Do_HDMA_Channel
 ; Overhead, also used for loading next NTRLx ($43xA)
 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE

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
 GET_BYTE 0
 inc bx                 ; Adjust table address
 test al,al             ; Check for zero-length set
 mov [edi+NTRL],al      ; Save length of set
 jz HDMA_End_Channel
 mov [edi+A2T],ebx      ; Save new table address

.Next_Transfer:
 HDMA_TRANSFER_A_TO_B [edi+DMA_B0]

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 cmp cl,2
 inc bx                 ; Adjust temporary table pointer
 jb .End_Transfer

 HDMA_TRANSFER_A_TO_B [edi+DMA_B1]

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 cmp cl,4
 inc bx                 ; Adjust temporary table pointer
 jb .End_Transfer

 HDMA_TRANSFER_A_TO_B [edi+DMA_B2]

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 inc bx

 HDMA_TRANSFER_A_TO_B [edi+DMA_B3]

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer

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
 GET_BYTE 0
 inc bx
 mov [edi+NTRL],al
 test al,al
 jz HDMA_End_Channel

 mov ah,al
 GET_BYTE _5A22_SLOW_CYCLE      ; Address load low
 inc bx
 mov [edi+DASL],al
 GET_BYTE _5A22_SLOW_CYCLE      ; Address load high
 inc bx
 mov [edi+DASH],al
 mov [edi+A2T],ebx
.Next_Transfer:
 mov ebx,[edi+DAS]
 and ebx,(1 << 24) - 1

 HDMA_TRANSFER_A_TO_B [edi+DMA_B0]

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 cmp cl,2
 inc bx                 ; Adjust temporary table pointer
 jb .End_Transfer

 HDMA_TRANSFER_A_TO_B [edi+DMA_B1]

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 cmp cl,4
 inc bx                 ; Adjust temporary table pointer
 jb .End_Transfer

 HDMA_TRANSFER_A_TO_B [edi+DMA_B2]

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer
 inc bx

 HDMA_TRANSFER_A_TO_B [edi+DMA_B3]

 add R_65c816_Cycles,byte _5A22_SLOW_CYCLE      ; HDMA transfer

.End_Transfer:
 add [edi+DAS],cx
.Continue:
 dec byte [edi+NTRL]
 stc
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

;macro for processing a channel during HDMA init
%macro RELATCH_HDMA_CHANNEL 1
 test byte [C_LABEL(HDMAEN)],(1<<%1)
 jz %%no_relatch

 mov eax,[A1T_%1]        ; Src Address in ebx
 mov [A2T_%1],eax

 mov byte [NTRL_%1],0

%%no_relatch:
%endmacro

ALIGNC
EXPORT init_HDMA
 mov al,[C_LABEL(HDMAEN)]
 mov [HDMAON],al
 test al,al
 jz .no_hdma

 mov al,[In_DMA]
 push eax

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
 mov al,[HDMAON]
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
 mov byte [DMA_Pending_B_Address],-1

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
