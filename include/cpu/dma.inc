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

%include "cpu/cpumem.inc"
%include "cycles.inc"

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
EXTERN DMA_Pending_B_Address,DMA_Pending_Data
EXTERN_C Do_DMA_Channel,Do_HDMA_Channel
EXTERN SNES_W420C
EXTERN init_HDMA,do_HDMA
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

                         ; 0000dccc | d = in DMA/HDMA, if 0 all should be 0
;EXPORT In_DMA           ; c = channel # 0-7
%define DMA_IN_PROGRESS (1 << 3)
%define DMA_CHANNEL_MASK ((1 << 3) - 1)


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
 dd C_LABEL(UNSUPPORTED_READ)
 ; 43xC-43xE: Open Bus A
 DUPLICATE dd,3,C_LABEL(CPU_OPEN_BUS_READ)
 dd C_LABEL(UNSUPPORTED_READ)
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

;%1 = num, 2 = branch target for early-exit
%macro DMAOPERATION 2
 mov al,[C_LABEL(MDMAEN)]
 test al,1 << (%1)
 jz %%no_dma

 mov byte [In_DMA],(%1) | DMA_IN_PROGRESS
 LOAD_DMA_TABLE %1

 call C_LABEL(Do_DMA_Channel)

 cmp byte [In_DMA],0
 jnz %2

 and byte [C_LABEL(MDMAEN)],~(1 << (%1))

%%no_dma:
%endmacro

%endif ; !defined(SNEeSe_dma_inc)
