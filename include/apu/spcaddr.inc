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

; SNEeSe SPC700 CPU emulation core
; Originally written by Savoury SnaX (Not quite sure if I like AT&T)
; Maintained/rewritten by Charles Bilyue'
;
; Compile under NASM
;
; This file contains:
;  SPC700 addressing mode macros
;

; Immediate (read-only)
;  Read 8-bit
;    OR  A-08  AND A-28  EOR A-48  CMP A-68  ADC A-88  MOV Y-8D
;    SBC A-A8  CMP Y-AD  CMP X-C8  MOV X-CD  MOV A-E8
;
%macro ADDR_imm8 0
 GET_PC ebx
 inc R_PC
%endmacro

%macro ADDR_imm16 0
 GET_PC ebx
 add R_PC,2
%endmacro

; Direct Page
;  Read 8-bit
;    OR  A-04  AND A-24  CMP X-3E  EOR A-44  CMP A-64  CMP Y-7E  ADC A-84
;    SBC A-A4  MOV A-E4  MOV Y-EB  MOV X-F8
;  Read 16-bit
;    CMP YA-5A ADD YA-7A SUB YA-9A MOV YA-BA
;  RMW 8-bit
;    ASL-0B  ROL-2B  LSR-4B  ROR-6B  DEC-8B  INC-AB
;  RMW 16-bit
;    DECW-1A INCW-3A
;  Write 8-bit
;    MOV A-C4  MOV Y-CB  MOV X-D8
;  Write 16-bit
;    MOV YA-DA
;
%macro ADDR_dp 0
 GET_PC ebx
 GET_BYTE_SPC
 inc R_PC
 mov ebx,B_SPC_PAGE
 add ebx,eax
%endmacro

; Direct Page index X
;  Read 8-bit
;    OR  A-14  AND A-34  EOR A-54  CMP A-74  ADC A-94  SBC A-B4  MOV A-F4
;    MOV Y-FB
;  RMW 8-bit
;    ASL-1B  ROL-3B  LSR-5B  ROR-7B  DEC-9B  INC-BB
;  Write 8-bit
;    MOV A-D4  MOV Y-DB
;
%macro ADDR_Odp_XO 0
 GET_PC ebx
 GET_BYTE_SPC
 mov cl,B_X
 inc R_PC
 add al,cl
 mov ebx,B_SPC_PAGE
 add ebx,eax
%endmacro

; Direct Page index Y
;  Read 8-bit
;    MOV X-F9
;  Write 8-bit
;    MOV X-D9
;
%macro ADDR_Odp_YO 0
 GET_PC ebx
 GET_BYTE_SPC
 mov cl,B_Y
 inc R_PC
 add al,cl
 mov ebx,B_SPC_PAGE
 add ebx,eax
%endmacro

; Indexed Indirect
;  Read 8-bit
;    OR  A-07  AND A-27  EOR A-47  CMP A-67  ADC A-87  SBC A-A7  MOV A-E7
;  Write 8-bit
;    MOV A-C7
;
%macro ADDR_OOdp_XOO 0
 ADDR_Odp_XO
 GET_WORD_SPC
 mov ebx,eax
%endmacro

; Indirect Indexed
;  Read 8-bit
;    OR  A-17  AND A-37  EOR A-57  CMP A-77  ADC A-97  SBC A-B7  MOV A-F7
;  Write 8-bit
;    MOV A-D7
;
%macro ADDR_OOdpO_YO 0
 ADDR_dp
 GET_WORD_SPC
 xor ebx,ebx
 mov bl,B_Y
 add bx,ax
%endmacro

; Direct Page X
;  Read 8-bit
;    OR  A-06  AND A-26  EOR A-46  CMP A-66  ADC A-86  SBC A-A6  MOV A-E6
;  Write 8-bit
;    MOV A-C6
;
%macro ADDR_OXO 0
 mov ebx,B_SPC_PAGE
 mov bl,B_X
%endmacro

; Direct Page to Direct Page
;  RMW 8-bit
;    OR -09  AND-29  EOR-49  CMP-69  ADC-89  SBC-A9  MOV-FA
;
;%1 = reg
%macro ADDR2_dp_dp 0-1 al   ; al or reg contains src byte
                            ; bx dest address
 GET_PC ebx
 GET_BYTE_SPC           ; get src dp
 inc bx
 mov cl,al
 GET_BYTE_SPC           ; get dest dp
 add R_PC,2
 mov ebx,B_SPC_PAGE
 mov bl,cl
 mov cl,al
 GET_BYTE_SPC
 mov bl,cl
%ifnidni %1,al
 mov %1,al
%endif
%endmacro

; Immediate to Direct Page
;  RMW 8-bit
;    OR -18  AND-38  EOR-58  CMP-78  MOV-8F  ADC-98  SBC-B8
;
;%1 = reg
%macro ADDR2_dp_IM 0-1 al   ; al or reg contains src byte
                            ; bx dest address
 GET_PC ebx
 GET_BYTE_SPC           ; get src byte
 inc bx
 mov cl,al
 GET_BYTE_SPC           ; get dest dp
 add R_PC,2
 mov ebx,B_SPC_PAGE
 mov bl,al

%ifnidni %1,cl
 mov %1,cl
%endif
%endmacro

; Direct Page Y to Direct Page X
;  RMW 8-bit
;    OR -19  AND-39  EOR-59  CMP-79  ADC-99  SBC-B9
;
;%1 = reg
%macro ADDR2_OXO_OYO 0-1 al ; al or reg contains src byte (Y)
                            ; bx dest address
 mov ebx,B_SPC_PAGE
 mov bl,B_Y
 GET_BYTE_SPC           ; get src byte
 mov bl,B_X

%ifnidni %1,al
 mov %1,al
%endif
%endmacro

; Direct Page X autoincrement
;  Read 8-bit
;    MOV A-BF
;  Write 8-bit
;    MOV A-AF
;
%macro ADDR_OXOInc 0
 mov ebx,B_SPC_PAGE
 mov al,B_X
 mov bl,al
 inc al
 mov B_X,al
%endmacro

; Absolute
;  Read 8-bit
;    OR  A-05  CMP X-1E  AND A-25  EOR A-45  CMP Y-5E  CMP A-65  ADC A-85
;    SBC A-A5  MOV A-E5  MOV X-E9  MOV Y-EC
;  Read 16-bit
;    CALL -3F  JMP  -5F
;  RMW 8-bit
;    ASL  -0C  TSET1-0E  ROL  -2C  LSR  -4C  TCLR1-4E  ROR  -6C  DEC  -8C
;    INC  -AC
;  Write 8-bit
;    MOV A-C5  MOV X-C9  MOV Y-CC
;
%macro ADDR_abs 0
 GET_PC ebx
 GET_WORD_SPC
 mov ebx,eax
 add R_PC,2
%endmacro

; Absolute index X
;  Read 8-bit
;    OR  A-15  AND A-35  EOR A-55  CMP A-75  ADC A-95  SBC A-B5  MOV A-F5
;  Write 8-bit
;    MOV A-D5
;
%macro ADDR_Oabs_XO 0
 GET_PC ebx
 GET_WORD_SPC
 xor ebx,ebx
 mov bl,B_X
 add R_PC,2
 add ebx,eax
 and ebx,0xFFFF
%endmacro

; Absolute index Y
;  Read 8-bit
;    OR  A-16  AND A-36  EOR A-56  CMP A-76  ADC A-96  SBC A-B6  MOV A-F6
;  Write 8-bit
;    MOV A-D6
;
%macro ADDR_Oabs_YO 0
 GET_PC ebx
 GET_WORD_SPC
 xor ebx,ebx
 mov bl,B_Y
 add R_PC,2
 add ebx,eax
 and ebx,0xFFFF
%endmacro

; mem.bit
;  Read 8-bit
;    OR1  C -0A  OR1  C/-2A  AND1 C -4A  AND1 C/-6A  EOR1 C -8A
;    MOV1 C -AA
;  Write 8-bit
;    MOV1  C-CA
;  RMW 8-bit
;    NOT1   -EA
;
%macro ADDR_membit 0    ; This is a weird addressing mode!
 GET_PC ebx
 GET_WORD_SPC
 xor ecx,ecx
 add R_PC,2
 mov cl,ah
 mov ebx,0x1FFF
 shr ecx,5      ; Get bit number
 and ebx,eax    ; Get address
%endmacro
