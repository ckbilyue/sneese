%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

%ifndef SNEeSe_dma_inc
%define SNEeSe_dma_inc

; (H)DMA macros
;
; Thanks to zsKnight for all the information which helped get this
; working right! (I hope!)

%ifndef SNEeSe_DMA_asm

EXTERN_C DMA_text_start,DMA_data_start,DMA_bss_start

%macro EXTERN_DMA_DATA 1
EXTERN TableDMA%1
; dh0bcttt d=CPU->PPU,h=addr,b=inc/dec,c=inc/fixed,t=type
EXTERN_C DMAP_%1
EXTERN_C BBAD_%1    ; Low byte of 0x21??
EXTERN DMA_Vid_%1
EXTERN NTRL_%1
EXTERN A1T_%1       ; Source Address L/H/B
EXTERN_C A1TL_%1    ; Source Address L
EXTERN_C A1TH_%1    ; Source Address H
EXTERN_C A1B_%1     ; Source Bank Address
EXTERN DAS_%1       ; Data Size L/H
EXTERN_C DASL_%1    ; Data Size L
EXTERN_C DASH_%1    ; Data Size H
EXTERN_C DASB_%1    ; Data address bank
EXTERN A2T_%1
EXTERN_C A2L_%1     ; HDMA table address L
EXTERN_C A2H_%1     ; HDMA table address H
EXTERN_C A2B_%1     ; HDMA table bank address

; HDMA_Siz_x - These hold the register size for HDMA
EXTERN HDMA_Siz_%1
%endmacro

EXTERN_DMA_DATA 0
EXTERN_DMA_DATA 1
EXTERN_DMA_DATA 2
EXTERN_DMA_DATA 3
EXTERN_DMA_DATA 4
EXTERN_DMA_DATA 5
EXTERN_DMA_DATA 6
EXTERN_DMA_DATA 7

EXTERN_C MDMAEN,HDMAEN
EXTERN HDMAON,In_DMA
EXTERN_C Do_DMA_Channel,Do_HDMA_Channel
EXTERN SNES_R420B,SNES_R420C,SNES_W420B,SNES_W420C
EXTERN do_HDMA
EXTERN Reset_DMA

%macro EXTERN_MAP_READ_DMA 1
EXTERN MAP_READ_DMAP%1
EXTERN MAP_READ_BBAD%1
EXTERN MAP_READ_A1TL%1
EXTERN MAP_READ_A1TH%1
EXTERN MAP_READ_A1B%1
EXTERN MAP_READ_DASL%1
EXTERN MAP_READ_DASH%1
EXTERN MAP_READ_DASB%1
EXTERN MAP_READ_A2L%1
EXTERN MAP_READ_A2H%1
EXTERN MAP_READ_NTRL%1
%endmacro

EXTERN_MAP_READ_DMA 0
EXTERN_MAP_READ_DMA 1
EXTERN_MAP_READ_DMA 2
EXTERN_MAP_READ_DMA 3
EXTERN_MAP_READ_DMA 4
EXTERN_MAP_READ_DMA 5
EXTERN_MAP_READ_DMA 6
EXTERN_MAP_READ_DMA 7

%macro EXTERN_MAP_WRITE_DMA 1
EXTERN MAP_WRITE_DMAP%1
EXTERN MAP_WRITE_BBAD%1
EXTERN MAP_WRITE_A1TL%1
EXTERN MAP_WRITE_A1TH%1
EXTERN MAP_WRITE_A1B%1
EXTERN MAP_WRITE_DASL%1
EXTERN MAP_WRITE_DASH%1
EXTERN MAP_WRITE_DASB%1
EXTERN MAP_WRITE_A2L%1
EXTERN MAP_WRITE_A2H%1
EXTERN MAP_WRITE_NTRL%1
%endmacro

EXTERN_MAP_WRITE_DMA 0
EXTERN_MAP_WRITE_DMA 1
EXTERN_MAP_WRITE_DMA 2
EXTERN_MAP_WRITE_DMA 3
EXTERN_MAP_WRITE_DMA 4
EXTERN_MAP_WRITE_DMA 5
EXTERN_MAP_WRITE_DMA 6
EXTERN_MAP_WRITE_DMA 7
%endif

; Offsets from TableDMA#
%define DMAP 0
%define BBAD 1
%define DMA_Vid BBAD
%define NTRL 2
%define DMA_Inc 3
%define A1T 4
%define A1TL A1T
%define A1TH (A1T+1)
%define A1B (A1T+2)
%define DAS 8
%define DASL DAS
%define DASH (DAS+1)
%define DASB (DAS+2)
%define A2T 0x0C
%define A2L A2T
%define A2H (A2T+1)
%define A2B (A2T+2)
%define HDMA_Siz 0x10
%define DMA_B0 0x14
%define DMA_B1 0x15
%define DMA_B2 0x16
%define DMA_B3 0x17
%define DMATableSize 0x18

%macro MAP_READ_DMA_LIST 1
 dd MAP_READ_DMAP%1
 dd MAP_READ_BBAD%1
 dd MAP_READ_A1TL%1
 dd MAP_READ_A1TH%1
 dd MAP_READ_A1B%1
 dd MAP_READ_DASL%1
 dd MAP_READ_DASH%1
 dd MAP_READ_DASB%1
 dd MAP_READ_A2L%1
 dd MAP_READ_A2H%1
 dd MAP_READ_NTRL%1
 DUPLICATE dd,5,C_LABEL(UNSUPPORTED_READ)
%endmacro

%macro MAP_WRITE_DMA_LIST 1
 dd MAP_WRITE_DMAP%1
 dd MAP_WRITE_BBAD%1
 dd MAP_WRITE_A1TL%1
 dd MAP_WRITE_A1TH%1
 dd MAP_WRITE_A1B%1
 dd MAP_WRITE_DASL%1
 dd MAP_WRITE_DASH%1
 dd MAP_WRITE_DASB%1
 dd MAP_WRITE_A2L%1
 dd MAP_WRITE_A2H%1
 dd MAP_WRITE_NTRL%1
 DUPLICATE dd,5,C_LABEL(UNSUPPORTED_WRITE)
%endmacro

%macro LOAD_DMA_TABLE 1
 mov edi,TableDMA%1
%endmacro

%macro HDMAOPERATION 1
  mov al,[HDMAON]
  test al,(1<<%1)
  jz %%no_hdma

  add dword [C_LABEL(SNES_Cycles)],byte 8   ; HDMA processing

  mov byte [In_DMA],((%1) << 2) | DMA_IN_PROGRESS
  LOAD_DMA_TABLE %1
  call C_LABEL(Do_HDMA_Channel) ; CF clear if channel disabled

  jc %%no_hdma
  mov al,[HDMAON]
  and al,~(1<<%1)
  mov [HDMAON],al       ; Disable this channel
%%no_hdma:
%endmacro

%macro RELATCH_HDMA_CHANNEL 1
 test byte [C_LABEL(HDMAEN)],(1<<%1)
 jz %%no_relatch

 mov byte [NTRL_%1],0

 mov eax,[A1T_%1]        ; Src Address in ebx
 mov [A2T_%1],eax


%%no_relatch:
%endmacro

%macro RELATCH_HDMA_IN_FRAME 1
%if 0
 mov al,[HDMAON]
 not al
 and al,[esp]
 test al,(1<<%1)
 jz %%no_relatch

 mov byte [NTRL_%1],0
%%no_relatch:
%endif
%endmacro

%macro RELATCH_HDMA 0
 mov al,[C_LABEL(HDMAEN)]
 mov [HDMAON],al
 test al,al
 jz near %%no_hdma
 RELATCH_HDMA_CHANNEL 0
 RELATCH_HDMA_CHANNEL 1
 RELATCH_HDMA_CHANNEL 2
 RELATCH_HDMA_CHANNEL 3
 RELATCH_HDMA_CHANNEL 4
 RELATCH_HDMA_CHANNEL 5
 RELATCH_HDMA_CHANNEL 6
 RELATCH_HDMA_CHANNEL 7
%%no_hdma:
%endmacro

%endif ; !defined(SNEeSe_dma_inc)
