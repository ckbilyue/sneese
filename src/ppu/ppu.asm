%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

;%define FORCE_MOSAIC 2
%define Set_Based_Tile_Cache
;%define Profile_VRAM_Writes
;%define Check_Within_Tile_Set
;%define NO_DMA_WRITE
;%define TRAP_BGHOFS
;%define TRAP_BGVOFS

; PPU.asm - Contains the hardware mapping functions

%define SNEeSe_ppu_ppu_asm

%include "misc.inc"
%include "ppu/ppu.inc"
%include "cpu/dma.inc"
%include "ppu/sprites.inc"
%include "ppu/screen.inc"
%include "ppu/tiles.inc"
%include "cpu/cpumem.inc"
%include "cycles.inc"
%include "cpu/regs.inc"

EXTERN SNES_R2137,SNES_R213C,SNES_R213D

EXTERN SNES_R4016,SNES_R4017
EXTERN SNES_R4200,SNES_R4202,SNES_R4203
EXTERN SNES_R4210,SNES_R4211,SNES_R4212,SNES_R4213
EXTERN SNES_R4214,SNES_R4215,SNES_R4216,SNES_R4217
EXTERN SNES_R4218,SNES_R4219,SNES_R421A,SNES_R421B
EXTERN SNES_R421C,SNES_R421D,SNES_R421E,SNES_R421F

EXTERN SNES_W4016,SNES_W4017
EXTERN SNES_W4200,SNES_W4201,SNES_W4202,SNES_W4203
EXTERN SNES_W4204,SNES_W4205,SNES_W4206,SNES_W4207
EXTERN SNES_W4208,SNES_W4209,SNES_W420A,SNES_W420B
EXTERN SNES_W420D,SNES_W4210
EXTERN HVBJOY

EXTERN_C LastRenderLine
EXTERN_C BrightnessLevel
EXTERN_C NMITIMEN
EXTERN_C Real_SNES_Palette
EXTERN OPHCT,OPVCT
EXTERN_C SNES_COUNTRY
EXTERN Ready_Line_Render
EXTERN_C PaletteChanged
EXTERN_C Offset_Change_Disable
EXTERN_C fixedpalettecheck

EXTERN_C SPC_MASK
EXTERN_C OutputScreen
EXTERN_C MosaicLine

EXTERN_C Map_Address,Map_Byte
EXTERN_C InvalidHWWrite

section .text
EXPORT_C PPU_text_start
section .data
EXPORT_C PPU_data_start
section .bss
EXPORT_C PPU_bss_start

section .data
ALIGND
EXPORT_C Read_Map_20_5F
    ; 2000-20FF: Open Bus A
    DUPLICATE dd,0x100,C_LABEL(CPU_OPEN_BUS_READ)
EXPORT_C Read_Map_21
    ; 2100-2103: Open Bus A
    DUPLICATE dd,4,C_LABEL(CPU_OPEN_BUS_READ)
    ; 2104-2106: Open Bus B (PPU1)
    DUPLICATE dd,3,C_LABEL(UNSUPPORTED_READ)
    ; 2107: Open Bus A
    dd   C_LABEL(CPU_OPEN_BUS_READ)
    ; 2108-210A: Open Bus B (PPU1)
    DUPLICATE dd,3,C_LABEL(UNSUPPORTED_READ)
    ; 210B-2113: Open Bus A
    DUPLICATE dd,9,C_LABEL(CPU_OPEN_BUS_READ)
    ; 2114-2116: Open Bus B (PPU1)
    DUPLICATE dd,3,C_LABEL(UNSUPPORTED_READ)
    ; 2117: Open Bus A
    dd   C_LABEL(CPU_OPEN_BUS_READ)
    ; 2118-211A: Open Bus B (PPU1)
    DUPLICATE dd,3,C_LABEL(UNSUPPORTED_READ)
    ; 211B-2123: Open Bus A
    DUPLICATE dd,9,C_LABEL(CPU_OPEN_BUS_READ)
    ; 2124-2126: Open Bus B (PPU1)
    DUPLICATE dd,3,C_LABEL(UNSUPPORTED_READ)
    ; 2127: Open Bus A
    dd   C_LABEL(CPU_OPEN_BUS_READ)
    ; 2128-212A: Open Bus B (PPU1)
    DUPLICATE dd,3,C_LABEL(UNSUPPORTED_READ)
    ; 212B-2133: Open Bus A
    DUPLICATE dd,9,C_LABEL(CPU_OPEN_BUS_READ)

    dd   SNES_R2134  ; MPYL
    dd   SNES_R2135  ; MPYM
    dd   SNES_R2136  ; MPYH
    dd   SNES_R2137  ; SLHV
    dd   SNES_R2138  ; OAMDATAREAD
    dd   SNES_R2139  ; VMDATALREAD
    dd   SNES_R213A  ; VMDATAHREAD
    dd   SNES_R213B  ; CGDATAREAD     ; v0.14
    dd   SNES_R213C  ; OPHCT          ; v0.14
    dd   SNES_R213D  ; OPVCT
    dd   SNES_R213E  ; STAT77   ; Not supported yet (properly..)
    dd   SNES_R213F  ; STAT78
    DUPLICATE dd,0x40,C_LABEL(UNSUPPORTED_READ) ; APUI00-APUI03
    dd   SNES_R2180  ; WMDATA   ; 2180 WMDATA - read/write to Work RAM

    ; 2181-21FF: Open Bus A
    DUPLICATE dd,0x7F,C_LABEL(CPU_OPEN_BUS_READ)

    ; 2200-3FFF: Open Bus A
    DUPLICATE dd,0x1E00,C_LABEL(CPU_OPEN_BUS_READ)

EXPORT_C Read_Map_40
    ; 4000-4015: Open Bus A - 12 master cycles
    DUPLICATE dd,0x16,C_LABEL(CPU_OPEN_BUS_READ_LEGACY)
    dd   SNES_R4016  ; JOYC1
    dd   SNES_R4017  ; JOYC2
    ; 4018-40FF: Open Bus A - 12 master cycles
    DUPLICATE dd,0xE8,C_LABEL(CPU_OPEN_BUS_READ_LEGACY)
    ; 4100-41FF: Open Bus A - 12 master cycles
    DUPLICATE dd,0x100,C_LABEL(CPU_OPEN_BUS_READ_LEGACY)

EXPORT_C Read_Map_42
    ; 4200-420F: Open Bus A
    DUPLICATE dd,0x10,C_LABEL(CPU_OPEN_BUS_READ)

    dd   SNES_R4210  ; RDNMI
    dd   SNES_R4211  ; TIMEUP
    dd   SNES_R4212  ; HVBJOY
    dd   SNES_R4213  ; RDIO     ; Not yet supported... probably never
    dd   SNES_R4214  ; RDDIVL
    dd   SNES_R4215  ; RDDIVH
    dd   SNES_R4216  ; RDMPYL
    dd   SNES_R4217  ; RDMPYH
    dd   SNES_R4218  ; JOY1L
    dd   SNES_R4219  ; JOY1H
    dd   SNES_R421A  ; JOY2L
    dd   SNES_R421B  ; JOY2H
    dd   SNES_R421C  ; JOY3L    ; Not yet supported
    dd   SNES_R421D  ; JOY3H
    dd   SNES_R421E  ; JOY4L    ; Not yet supported
    dd   SNES_R421F  ; JOY4H

    ; 4220-42FF: Open Bus A
    DUPLICATE dd,0xE0,C_LABEL(CPU_OPEN_BUS_READ)

EXPORT_C Read_Map_43
    MAP_READ_DMA_LIST 0
    MAP_READ_DMA_LIST 1
    MAP_READ_DMA_LIST 2
    MAP_READ_DMA_LIST 3
    MAP_READ_DMA_LIST 4
    MAP_READ_DMA_LIST 5
    MAP_READ_DMA_LIST 6
    MAP_READ_DMA_LIST 7
    ; 4380-43FF: Open Bus A
    DUPLICATE dd,0x80,C_LABEL(CPU_OPEN_BUS_READ)
    ; 4400-5FFF: Open Bus A
    DUPLICATE dd,0x1C00,C_LABEL(CPU_OPEN_BUS_READ)

ALIGND
EXPORT_C Write_Map_20_5F
    ; 2000-20FF: Unmapped
    DUPLICATE dd,0x100,C_LABEL(UNSUPPORTED_WRITE)
EXPORT_C Write_Map_21
    dd   SNES_W2100  ; INIDISP
    dd   SNES_W2101  ; OBSEL
    dd   SNES_W2102  ; OAMADDL
    dd   SNES_W2103  ; OAMADDH
    dd   SNES_W2104  ; OAMDATA
    dd   SNES_W2105  ; BGMODE
    dd   SNES_W2106  ; MOSAIC
    dd   SNES_W2107  ; BG1SC
    dd   SNES_W2108  ; BG2SC
    dd   SNES_W2109  ; BG3SC
    dd   SNES_W210A  ; BG4SC
    dd   SNES_W210B  ; BG12NBA
    dd   SNES_W210C  ; BG34NBA
    dd   SNES_W210D  ; BG1HOFS
    dd   SNES_W210E  ; BG1VOFS
    dd   SNES_W210F  ; BG2HOFS
    dd   SNES_W2110  ; BG2VOFS
    dd   SNES_W2111  ; BG3HOFS
    dd   SNES_W2112  ; BG3VOFS
    dd   SNES_W2113  ; BG4HOFS
    dd   SNES_W2114  ; BG4VOFS
    dd   SNES_W2115  ; VMAIN
    dd   SNES_W2116  ; VMADDL
    dd   SNES_W2117  ; VMADDH
    dd   SNES_W2118_NORM ; VMDATAL
    dd   SNES_W2119_NORM ; VMDATAH
    dd   SNES_W211A  ; M7SEL
    dd   SNES_W211B  ; M7A
    dd   SNES_W211C  ; M7B
    dd   SNES_W211D  ; M7C
    dd   SNES_W211E  ; M7D
    dd   SNES_W211F  ; M7X
    dd   SNES_W2120  ; M7Y
    dd   SNES_W2121  ; CGADD
    dd   SNES_W2122  ; CGDATA
    dd   SNES_W2123  ; W12SEL
    dd   SNES_W2124  ; W34SEL
    dd   SNES_W2125  ; WOBJSEL
    dd   SNES_W2126  ; WH0
    dd   SNES_W2127  ; WH1
    dd   SNES_W2128  ; WH2
    dd   SNES_W2129  ; WH3
    dd   SNES_W212A  ; WBGLOG
    dd   SNES_W212B  ; WOBJLOG
    dd   SNES_W212C  ; TM
    dd   SNES_W212D  ; TS
    dd   SNES_W212E  ; TMW
    dd   SNES_W212F  ; TSW
    dd   SNES_W2130  ; CGWSEL
    dd   SNES_W2131  ; CGADSUB
    dd   SNES_W2132  ; COLDATA
    dd   SNES_W2133  ; SETINI
    DUPLICATE dd,0x0C,C_LABEL(UNSUPPORTED_WRITE)
    DUPLICATE dd,0x40,C_LABEL(UNSUPPORTED_WRITE)    ; APUI00-APUI03
    dd   SNES_W2180  ; WMDATA   ; 2180 WMDATA - read/write to Work RAM
    dd   SNES_W2181  ; WMADDL   ; 2181-3 WMAddress
    dd   SNES_W2182  ; WMADDM
    dd   SNES_W2183  ; WMADDH
    DUPLICATE dd,0x7C,C_LABEL(UNSUPPORTED_WRITE)
    ; 2200-3FFF: Unmapped
    DUPLICATE dd,0x1E00,C_LABEL(UNSUPPORTED_WRITE)
EXPORT_C Write_Map_40
    DUPLICATE dd,0x16,C_LABEL(UNSUPPORTED_WRITE)
    dd   SNES_W4016  ; JOYC1
    dd   SNES_W4017  ; JOYC2
    DUPLICATE dd,0xE8,C_LABEL(UNSUPPORTED_WRITE)
    ; 4100-41FF: Unmapped
    DUPLICATE dd,0x100,C_LABEL(UNSUPPORTED_WRITE)
EXPORT_C Write_Map_42
    dd   SNES_W4200  ; NMITIMEN
    dd   SNES_W4201  ; WRIO
    dd   SNES_W4202  ; WRMPYA
    dd   SNES_W4203  ; WRMPYB
    dd   SNES_W4204  ; WRDIVL
    dd   SNES_W4205  ; WRDIVH
    dd   SNES_W4206  ; WRDIVB
    dd   SNES_W4207  ; HTIMEL
    dd   SNES_W4208  ; HTIMEH
    dd   SNES_W4209  ; VTIMEL
    dd   SNES_W420A  ; VTIMEH
%ifdef NO_DMA_WRITE
    DUPLICATE dd,2,C_LABEL(UNSUPPORTED_WRITE)
%else
    dd   SNES_W420B  ; MDMAEN
    dd   SNES_W420C  ; HDMAEN
%endif
    dd   SNES_W420D  ; MEMSEL
    DUPLICATE dd,2,C_LABEL(UNSUPPORTED_WRITE)
    dd   C_LABEL(IGNORE_WRITE)  ; RDNMI
    dd   C_LABEL(IGNORE_WRITE)  ; TIMEUP
    dd   C_LABEL(IGNORE_WRITE)  ; HVBJOY
    dd   C_LABEL(IGNORE_WRITE)  ; RDIO
    dd   C_LABEL(IGNORE_WRITE)  ; RDDIVL
    dd   C_LABEL(IGNORE_WRITE)  ; RDDIVH
    dd   C_LABEL(IGNORE_WRITE)  ; RDMPYL
    dd   C_LABEL(IGNORE_WRITE)  ; RDMPYH
    dd   C_LABEL(IGNORE_WRITE)  ; JOY1L
    dd   C_LABEL(IGNORE_WRITE)  ; JOY1H
    dd   C_LABEL(IGNORE_WRITE)  ; JOY2L
    dd   C_LABEL(IGNORE_WRITE)  ; JOY2H
    dd   C_LABEL(IGNORE_WRITE)  ; JOY3L
    dd   C_LABEL(IGNORE_WRITE)  ; JOY3H
    dd   C_LABEL(IGNORE_WRITE)  ; JOY4L
    dd   C_LABEL(IGNORE_WRITE)  ; JOY4H
    DUPLICATE dd,0xE0,C_LABEL(UNSUPPORTED_WRITE)

EXPORT_C Write_Map_43
%ifdef NO_DMA_WRITE
    DUPLICATE dd,0x80,C_LABEL(UNSUPPORTED_WRITE)
%else
    MAP_WRITE_DMA_LIST 0
    MAP_WRITE_DMA_LIST 1
    MAP_WRITE_DMA_LIST 2
    MAP_WRITE_DMA_LIST 3
    MAP_WRITE_DMA_LIST 4
    MAP_WRITE_DMA_LIST 5
    MAP_WRITE_DMA_LIST 6
    MAP_WRITE_DMA_LIST 7
%endif
    DUPLICATE dd,0x80,C_LABEL(UNSUPPORTED_WRITE)
    ; 4400-5FFF: Unmapped
    DUPLICATE dd,0x1C00,C_LABEL(UNSUPPORTED_WRITE)

ALIGND
; BG12NBA/BG34NBA to tileset-in-cache address tables
BGNBA_Table_2:
dd 0<<12,1<<12,2<<12,3<<12,4<<12,5<<12,6<<12,7<<12
BGNBA_Table_4:
dd 0<<11,1<<11,2<<11,3<<11,4<<11,5<<11,6<<11,7<<11
BGNBA_Table_8:
dd 0<<10,1<<10,2<<10,3<<10,4<<10,5<<10,6<<10,7<<10
; BGMODE layer depth tables
; Standard
;  1 = 2-bit   2 = 4-bit   3=8-bit
; Offset Change
;  5 = 2-bit   6 = 4-bit   7=8-bit
; Special
;  4 = mode-7  9 = 2-bit mode-0        0 = no more layers
; 4 layers, 8 bytes per layer ([4][8] array)
BGMODE_Depth_Table:
db 9,2,6,3,7,2,6,4
db 9,2,6,2,5,1,0,0
db 9,1,0,0,0,0,0,0
db 9,0,0,0,0,0,0,0

; These layers are allowed ***
BGMODE_Allowed_Layer_Mask_Table:
db 0x1F,0x17,0x13,0x13,0x13,0x13,0x11,0x13

; These layers require tileset recaching before rendering
BGMODE_Tile_Layer_Mask_Table:
db 0x1F,0x17,0x13,0x13,0x13,0x13,0x11,0x10

; These layers allow per-tile offset change
BGMODE_Allowed_Offset_Change_Table:
db 0,0,0xFF,0,0xFF,0,0xFF,0

ALIGND
LineRenderSmall:
dd 0,C_LABEL(Render_8x8_C2)
dd C_LABEL(Render_8x8_C4),C_LABEL(Render_8x8_C8)
dd C_LABEL(SCREEN_MODE_7),C_LABEL(Render_Offset_8x8_C2)
dd C_LABEL(Render_Offset_8x8_C4),C_LABEL(Render_Offset_8x8_C8)
dd 0,C_LABEL(Render_8x8_C2)

LineRenderLarge:
dd 0,C_LABEL(Render_16x16_C2)
dd C_LABEL(Render_16x16_C4),C_LABEL(Render_16x16_C8)
dd C_LABEL(SCREEN_MODE_7),C_LABEL(Render_Offset_16x16_C2)
dd C_LABEL(Render_Offset_16x16_C4),C_LABEL(Render_Offset_16x16_C8)
dd 0,C_LABEL(Render_16x16_C2)

LineRenderEvenSmall:
dd 0,C_LABEL(Render_16x8_Even_C2)
dd C_LABEL(Render_16x8_Even_C4),0
dd C_LABEL(SCREEN_MODE_7),C_LABEL(Render_16x8_Even_C2)
;dd C_LABEL(Render_16x8_Even_C4),0
dd C_LABEL(Render_Offset_16x8_Even_C4),0

LineRenderEvenLarge:
dd 0,C_LABEL(Render_16x16_Even_C2)
dd C_LABEL(Render_16x16_Even_C4),0
dd C_LABEL(SCREEN_MODE_7),C_LABEL(Render_16x16_Even_C2)
;dd C_LABEL(Render_16x16_Even_C4),0
dd C_LABEL(Render_Offset_16x16_Even_C4),0

Depth_NBA_Table:
%ifdef USE_8BPL_CACHE_FOR_4BPL
dd 0,BGNBA_Table_2,BGNBA_Table_8,BGNBA_Table_8  ;*
%else
dd 0,BGNBA_Table_2,BGNBA_Table_4,BGNBA_Table_8
%endif

section .bss
ALIGNB
EXPORT_C WRAM   ,skipk 128  ; Buffer for Work RAM
EXPORT_C VRAM   ,skipk 64   ; Buffer for Video RAM
EXPORT_C SPCRAM ,skipk 64   ; Buffer for SPC RAM/ROM
EXPORT_C Blank  ,skipk 64   ; Blank ROM buffer
_PortRAM:skipk 24           ; Ports 0x2000-0x5FFF

VRAMAddress:    skipl   ; VRAM address in PPU
SCINC:          skipl   ; Used in updating VRAM address

EXPORT Tile_Recache_Set_Begin,skipl
EXPORT Tile_Recache_Set_End  ,skipl

EXPORT Mosaic_Size,skipl    ; 000xxxxx  xxxxx=2-16 pixel size
EXPORT Mosaic_Size_Select,skipl ;Table selector
EXPORT MOSAIC     ,skipb    ; xxxxabcd  xxxx=0-F pixel size,a-d = affect BG4-1
EXPORT_C INIDISP  ,skipb    ; x000bbbb x=screen on/off,bbbb=Brightness
EXPORT_C BGMODE   ,skipb    ; abcdefff a-d=tile size bg4-1 (8/16),e=priority bg3,fff=mode
EXPORT_C Base_BGMODE,skipb  ; 00000fff fff=mode

EXPORT_C BG12NBA,skipb  ; aaaabbbb  aaaa=base address 2, bbbb=base address 1
EXPORT_C BG34NBA,skipb  ; aaaabbbb  aaaa=base address 4, bbbb=base address 3

EXPORT_C VMAIN,skipb    ; i000abcd  i=inc type,ab=full graphic,cd=SC increment

ALIGNB
EXPORT_C COLDATA,skipl  ; Actual data from COLDATA
CGAddress:  skipl   ; Palette position for writes to CGRAM

WMADDL:     skipb   ; Work RAM Address Lo Byte
WMADDM:     skipb   ; Work RAM Address Mid Byte
WMADDH:     skipb   ; Work RAM Address Hi Byte - Just bit 0 used!
            skipb
VMDATAREAD_buffer:skipl
VMDATAREAD_update:skipl ;funcptr
CGHigh:     skipb   ; Holds whether writing to first or second byte
CGReadHigh: skipb   ; Whether reading lo or high byte

BGOFS_Last_Write:skipb

EXPORT_C Current_Line_Timing,skipl

EXPORT_C SETINI,skipb
EXPORT STAT78,skipb     ; Enable support for field register

EXPORT Redo_Offset_Change,skipb
EXPORT Redo_Offset_Change_VOffsets,skipb

EXPORT BGMODE_Allowed_Layer_Mask,skipb
EXPORT BGMODE_Tile_Layer_Mask,skipb
EXPORT BGMODE_Allowed_Offset_Change,skipb

%macro BG_WIN_DATA 2
EXPORT_C TableWin%2BG%1
EXPORT_C WinBG%1_%2_Count,skipb
EXPORT_C WinBG%1_%2_Bands,skipb 2*3
%endmacro

; MapAddress - base address of tilemap
; VMapAddress - address of tilemap vertically adjusted for current scanline
; WSEL - window area enable/invert bits from W12SEL/W34SEL
; WLOG - dual-window logic bits from WBGLOG
; VL/VR are vertically adjusted for current scanline
; VL/VR will be same if tilemap only 32 tiles wide!
; SetAddress - address of tileset in cache

%macro BG_DATA 1
ALIGNB
EXPORT_C TableBG%1
EXPORT WSELBG%1,skipb
EXPORT WLOGBG%1,skipb
EXPORT_C BGSC%1,skipb   ; xxxxxxab  xxxxxx=base address, ab=SC Size
EXPORT DepthBG%1,skipb
TileHeightBG%1: skipb
TileWidthBG%1:  skipb
EXPORT MosaicBG%1,skipb
EXPORT NBABG%1,skipb        ; Unused in BG3/4

EXPORT VScroll_%1,skipl
EXPORT HScroll_%1,skipl
EXPORT VLMapAddressBG%1,skipl
EXPORT VRMapAddressBG%1,skipl

LineRenderBG%1: skipl
EXPORT SetAddressBG%1,skipl ; Address of BG tileset
EXPORT VMapAddressBG%1,skipl

EXPORT MapAddressBG%1       ; Screen address of BG
EXPORT TLMapAddressBG%1,skipl
EXPORT TRMapAddressBG%1,skipl
EXPORT BLMapAddressBG%1,skipl
EXPORT BRMapAddressBG%1,skipl

NBATableBG%1:   skipl       ; Unused in BG3/4
EXPORT LineCounter_BG%1,skipl
EXPORT M0_Color_BG%1,skipl
EXPORT BG_Flag_BG%1,skipb
EXPORT OC_Flag_BG%1,skipb   ; Unused in BG3/4

; Unclipped display area: main screen
BG_WIN_DATA %1,Main
; Unclipped display area: sub screen
BG_WIN_DATA %1,Sub

; Used in layering; first screen area (second screen removed in 16-bit)
BG_WIN_DATA %1,Low
; Used in layering; second screen area (first screen removed)
BG_WIN_DATA %1,High
; Used in layering; area to draw for both screens (16-bit only)
BG_WIN_DATA %1,Both

EXPORT Priority_Used_BG%1,skipb
EXPORT Priority_Unused_BG%1,skipb
skipb 239*2

%endmacro

BG_DATA 1
BG_DATA 2
BG_DATA 3
BG_DATA 4

EXPORT_EQU_C BG1SC,C_LABEL(BGSC1)
EXPORT_EQU_C BG2SC,C_LABEL(BGSC2)
EXPORT_EQU_C BG3SC,C_LABEL(BGSC3)
EXPORT_EQU_C BG4SC,C_LABEL(BGSC4)

EXPORT_EQU_C BG1HOFS,HScroll_1
EXPORT_EQU_C BG1VOFS,VScroll_1
EXPORT_EQU_C BG2HOFS,HScroll_2
EXPORT_EQU_C BG2VOFS,VScroll_2
EXPORT_EQU_C BG3HOFS,HScroll_3
EXPORT_EQU_C BG3VOFS,VScroll_3
EXPORT_EQU_C BG4HOFS,HScroll_4
EXPORT_EQU_C BG4VOFS,VScroll_4

PaletteData:    skipw

section .text
ALIGNC
EXPORT Reset_Ports
 pusha

 call C_LABEL(Reset_Sprites)
 call C_LABEL(Reset_Mode_7)
 call Invalidate_Tile_Caches

 ; Reset renderer
 mov byte [C_LABEL(Layer_Disable_Mask)],0xFF

 mov al,[BGMODE_Allowed_Layer_Mask_Table]
 mov [BGMODE_Allowed_Layer_Mask],al
 mov al,[BGMODE_Tile_Layer_Mask_Table]
 mov [BGMODE_Tile_Layer_Mask],al
 mov al,[BGMODE_Allowed_Offset_Change_Table]
 mov [BGMODE_Allowed_Offset_Change],al

 ; Set eax to 0, as we're setting most everything to 0...
 xor eax,eax

 mov dword [Render_Select],C_LABEL(Render_Layering_Option_0)
 mov byte [C_LABEL(Layering_Mode)],0

 mov dword [C_LABEL(LastRenderLine)],224

 mov [Display_Needs_Update],al

 mov byte [Redo_Windowing],-1
 mov byte [Redo_Layering],-1
 mov dword [Window_Offset_First],BG_Win_Main
 mov dword [Window_Offset_Second],BG_Win_Sub
 mov [Layers_Low],al
 mov [Layers_High],al

 mov [WMADDL],eax

 mov [VRAMAddress],eax
 mov dword [SCINC],1
 mov [MOSAIC],al
 mov [MosaicBG1],al
 mov [MosaicBG2],al
 mov [MosaicBG3],al
 mov [MosaicBG4],al
 mov dword [Mosaic_Size],1
 mov dword [Mosaic_Size_Select],0

%ifdef FORCE_MOSAIC
 ;***
 mov byte [MOSAIC],0x0F + (FORCE_MOSAIC << 4)
 mov byte [MosaicBG1],0x10
 mov byte [MosaicBG2],0x20
 mov byte [MosaicBG3],0x40
 mov byte [MosaicBG4],0x80
 mov dword [Mosaic_Size],FORCE_MOSAIC+1
 mov dword [Mosaic_Size_Select],256*FORCE_MOSAIC
%endif

 mov byte [STAT78],3

 mov [CGAddress],eax
 mov [CGHigh],al
 mov [CGReadHigh],al

 mov [BGOFS_Last_Write],al

 mov [C_LABEL(BGSC1)],al
 mov [C_LABEL(BGSC2)],al
 mov [C_LABEL(BGSC3)],al
 mov [C_LABEL(BGSC4)],al

 mov byte [Redo_Offset_Change],0
 mov byte [Redo_Offset_Change_VOffsets],0xFF

 mov [C_LABEL(BGMODE)],al
 mov [C_LABEL(Base_BGMODE)],al
 mov [C_LABEL(BG12NBA)],al
 mov [C_LABEL(BG34NBA)],al
 mov [NBABG1],al
 mov [NBABG2],al
 mov [NBABG3],al
 mov [NBABG4],al

 mov [C_LABEL(WH0)],al
 mov [C_LABEL(WH2)],al
 inc eax
 mov [C_LABEL(WH1)],al
 mov [C_LABEL(WH3)],al
 dec eax

 mov [C_LABEL(WBGLOG)],al
 mov [C_LABEL(WOBJLOG)],al
 mov [C_LABEL(WLOGBG1)],al
 mov [C_LABEL(WLOGBG2)],al
 mov [C_LABEL(WLOGBG3)],al
 mov [C_LABEL(WLOGBG4)],al

 mov [C_LABEL(W12SEL)],al
 mov [C_LABEL(W34SEL)],al
 mov [C_LABEL(WOBJSEL)],al

 mov [C_LABEL(WSELBG1)],al
 mov [C_LABEL(WSELBG2)],al
 mov [C_LABEL(WSELBG3)],al
 mov [C_LABEL(WSELBG4)],al

 mov [C_LABEL(TM)],al
 mov [C_LABEL(TS)],al
 mov [C_LABEL(TMW)],al
 mov [C_LABEL(TSW)],al
 mov [C_LABEL(SETINI)],al
 mov byte [C_LABEL(EXTBG_Mask)],~2

 mov [C_LABEL(COLDATA)],eax
 mov [C_LABEL(CGWSEL)],al
 mov [C_LABEL(CGADSUB)],al

 mov [C_LABEL(BrightnessLevel)],al
 mov byte [C_LABEL(INIDISP)],0x80
 mov [C_LABEL(BG1HOFS)],eax
 mov [C_LABEL(BG1VOFS)],eax
 mov [C_LABEL(BG2HOFS)],eax
 mov [C_LABEL(BG2VOFS)],eax
 mov [C_LABEL(BG3HOFS)],eax
 mov [C_LABEL(BG3VOFS)],eax
 mov [C_LABEL(BG4HOFS)],eax
 mov [C_LABEL(BG4VOFS)],eax

 mov [SetAddressBG1],eax
 mov [SetAddressBG2],eax
 mov [SetAddressBG3],eax
 mov [SetAddressBG4],eax

 mov dword [M0_Color_BG1],0x03030303
 mov dword [M0_Color_BG2],0x23232323
 mov dword [M0_Color_BG3],0x43434343
 mov dword [M0_Color_BG4],0x63636363

 mov byte [BG_Flag_BG1],(1 << 0)
 mov byte [BG_Flag_BG2],(1 << 1)
 mov byte [BG_Flag_BG3],(1 << 2)
 mov byte [BG_Flag_BG4],(1 << 3)

 mov byte [OC_Flag_BG1],0x20
 mov byte [OC_Flag_BG2],0x40

 mov dword [NBATableBG1],BGNBA_Table_2
 mov dword [NBATableBG2],BGNBA_Table_2
 mov dword [NBATableBG3],BGNBA_Table_2
 mov dword [NBATableBG4],BGNBA_Table_2

 mov dword [LineRenderBG1],C_LABEL(Render_8x8_C2)
 mov dword [LineRenderBG2],C_LABEL(Render_8x8_C2)
 mov dword [LineRenderBG3],C_LABEL(Render_8x8_C2)
 mov dword [LineRenderBG4],C_LABEL(Render_8x8_C2)

 mov byte [TileHeightBG1],1
 mov byte [TileHeightBG2],1
 mov byte [TileHeightBG3],1
 mov byte [TileHeightBG4],1
 mov byte [TileWidthBG1],1
 mov byte [TileWidthBG2],1
 mov byte [TileWidthBG3],1
 mov byte [TileWidthBG4],1
 mov byte [DepthBG1],1
 mov byte [DepthBG2],1
 mov byte [DepthBG3],1
 mov byte [DepthBG4],1

 mov eax,C_LABEL(VRAM)
 mov [TLMapAddressBG1],eax  ;MapAddressBG1
 mov [TLMapAddressBG2],eax  ;MapAddressBG2
 mov [TLMapAddressBG3],eax  ;MapAddressBG3
 mov [TLMapAddressBG4],eax  ;MapAddressBG4
 mov [TRMapAddressBG1],eax
 mov [TRMapAddressBG2],eax
 mov [TRMapAddressBG3],eax
 mov [TRMapAddressBG4],eax
 mov [BLMapAddressBG1],eax
 mov [BLMapAddressBG2],eax
 mov [BLMapAddressBG3],eax
 mov [BLMapAddressBG4],eax
 mov [BRMapAddressBG1],eax
 mov [BRMapAddressBG2],eax
 mov [BRMapAddressBG3],eax
 mov [BRMapAddressBG4],eax

 mov dword [OffsetChangeMap_VOffset],0
 mov dword [OffsetChangeVMap_VOffset],0

 mov [C_LABEL(VMAIN)],al
 mov dword [VMDATAREAD_update],VMDATAREAD_update_NORM
 Set_21_Write 0x18,SNES_W2118_NORM
 Set_21_Write 0x19,SNES_W2119_NORM
 mov [VMDATAREAD_buffer],eax

 mov eax,[Screen_Mode]
 mov [Render_Mode],eax

 popa
 ret

; Read from 21xx handlers

; SNES_R2134: ; MPYL in mode7.asm
; SNES_R2135: ; MPYM in mode7.asm
; SNES_R2136: ; MPYH in mode7.asm
; SNES_R2137: ; SLHV in timing.inc
; SNES_R2138: ; OAMDATAREAD in sprites.asm

ALIGNC
SNES_R2139: ; VMDATALREAD
 mov al,[C_LABEL(VMAIN)]
 test al,al
 mov al,[VMDATAREAD_buffer]
 jns VMDATAREAD_do_update
 ret

ALIGNC
SNES_R213A: ; VMDATAHREAD
 mov al,[C_LABEL(VMAIN)]
 test al,al
 mov al,[VMDATAREAD_buffer+1]
 js VMDATAREAD_do_update
 ret

ALIGNC
VMDATAREAD_do_update:
 jmp [VMDATAREAD_update]

ALIGNC
VMDATAREAD_update_NORM: ; normal increment
 push ebx
 mov edx,[VRAMAddress]
 mov bx,[C_LABEL(VRAM)+edx*2]
 add edx,[SCINC]
 mov [VMDATAREAD_buffer],bx
 and edx,0x7FFF
 pop ebx
 mov [VRAMAddress],edx
 ret

;bitshift (%1), bitmask (1 << (%1)) - 1, topmask 0x7FFF & ~((1 << ((%1) + 3)) - 1)
%macro GEN_SNES_R2139_213A_FULL 2
VMDATAREAD_update_FULL_%2:  ; full graphic increment
 mov edx,[VRAMAddress]
 push eax
 push edi
 mov edi,edx
 mov eax,edx
 shr edi,(%1)   ;Bitshift
 and eax,byte (1 << (%1)) - 1   ;Bitmask
 and edi,byte 7
 shl eax,3
 and edx,0x7FFF & ~((1 << ((%1) + 3)) - 1)  ;Topmask
 or edx,edi
 or edx,eax
 pop edi

 mov ax,[C_LABEL(VRAM)+edx*2]
 mov edx,[SCINC]
 mov [VMDATAREAD_buffer],ax
 add edx,[VRAMAddress]  ; Always words (since <<1)!
 pop eax
 and edx,0x7FFF
 mov [VRAMAddress],edx
 ret
%endmacro

GEN_SNES_R2139_213A_FULL 5,32
GEN_SNES_R2139_213A_FULL 6,64
GEN_SNES_R2139_213A_FULL 7,128

ALIGNC
SNES_R213B: ; CGDATAREAD
 push ebx
 xor ebx,ebx
;push edx
 mov bl,[CGReadHigh]
 mov edx,[CGAddress]
 mov al,[C_LABEL(Real_SNES_Palette)+ebx+edx*2]
 xor bl,1
 jnz .no_increment
 inc edx
 mov [CGAddress],dl ; Chop address for wrap
.no_increment:
 mov [CGReadHigh],bl
;pop edx
 pop ebx
 ret

; SNES_R213C: ; OPHCT in timing.inc
; SNES_R213D: ; OPVCT in timing.inc

ALIGNC
SNES_R213E: ; STAT77
 mov al,1   ; This is not supported yet!
 ret

ALIGNC
SNES_R213F: ; STAT78
 mov al,0
 mov [OPHCT],al
 mov [OPVCT],al
 mov al,[STAT78]
 or al,[C_LABEL(SNES_COUNTRY)]  ; 0x10 means PAL, not NTSC
 ret

; SNES_R2140_SKIP: ; APUI00 in APUskip.asm
; SNES_R2141_SKIP: ; APUI01 in APUskip.asm
; SNES_R2142_SKIP: ; APUI02 in APUskip.asm
; SNES_R2143_SKIP: ; APUI03 in APUskip.asm

; SNES_R2140_SPC:  ; APUI00 in spc700.asm
; SNES_R2141_SPC:  ; APUI01 in spc700.asm
; SNES_R2142_SPC:  ; APUI02 in spc700.asm
; SNES_R2143_SPC:  ; APUI03 in spc700.asm

ALIGNC
SNES_R2180: ; WMDATA
 mov edx,[WMADDL]
 add R_65c816_Cycles,_5A22_SLOW_CYCLE - _5A22_FAST_CYCLE
 mov al,[C_LABEL(WRAM)+edx]
 inc edx
 and edx,0x01FFFF
 mov [WMADDL],edx
 ret

; Read from 40xx handlers
; SNES_R4016: ; JOYC1 in timing.inc
; SNES_R4017: ; JOYC2 in timing.inc

; Read from 42xx handlers
; SNES_R4200: ; NMITIMEN in timing.inc
; SNES_R4202: ; WRMPYA in timing.inc
; SNES_R4203: ; WRMPYB in timing.inc
; SNES_R4210: ; RDNMI in timing.inc
; SNES_R4211: ; TIMEUP in timing.inc
; SNES_R4212: ; HVBJOY in timing.inc
; SNES_R4213: ; RDIO in timing.inc
; SNES_R4214: ; RDDIVL in timing.inc
; SNES_R4215: ; RDDIVH in timing.inc
; SNES_R4216: ; RDMPYL in timing.inc
; SNES_R4217: ; RDMPYH in timing.inc
; SNES_R4218: ; JOY1L in timing.inc
; SNES_R4219: ; JOY1H in timing.inc
; SNES_R421A: ; JOY2L in timing.inc
; SNES_R421B: ; JOY2H in timing.inc
; SNES_R421C: ; JOY3L in timing.inc
; SNES_R421D: ; JOY3H in timing.inc
; SNES_R421E: ; JOY4L in timing.inc
; SNES_R421F: ; JOY4H in timing.inc

; Read from 43xx handlers
; SNES_R43xx: ; in DMA.asm

;  --------

; Write to 21xx handlers
ALIGNC
SNES_W2100: ; INIDISP
 cmp [C_LABEL(INIDISP)],al
 je .no_change
 UpdateDisplay
 mov [C_LABEL(INIDISP)],al
 and al,0x0F
 cmp [C_LABEL(BrightnessLevel)],al
 ja .no_brightness_change
 mov [C_LABEL(BrightnessLevel)],al  ; Sets the brightness level for SetPalette
 mov byte [C_LABEL(PaletteChanged)],1
.no_brightness_change:
 mov al,[C_LABEL(INIDISP)]
.no_change:
 ret

; SNES_W2101: ; OBSEL in sprites.asm
; SNES_W2102: ; OAMADDL in sprites.asm
; SNES_W2103: ; OAMADDH in sprites.asm
; SNES_W2104: ; OAMDATA in sprites.asm

ALIGNC
EXPORT_C Toggle_Offset_Change
 xor byte [C_LABEL(Offset_Change_Disable)],0xFF
 ret

ALIGNC
SNES_W2105: ; BGMODE
%if 0
 cmp al,0x02
 jne .okay
 mov al,0x06
.okay:
%endif
 ; Note: Render_Mode is declared in screen.asm
 cmp [C_LABEL(BGMODE)],al
 je .no_change

 UpdateDisplay  ;*

 mov [C_LABEL(BGMODE)],al

; int mode = BGMODE & 7;
 push ebx
 mov edx,eax
 push ecx

 mov ebx,eax
 push edi
 and ebx,byte 7
 push esi
 mov [C_LABEL(Base_BGMODE)],bl
 and edx,byte 7
 mov ebx,0x03030303
 mov ecx,0x23232323
 mov edi,0x43434343
 mov esi,0x63636363
 jz .mode_0_palettes

 mov ecx,ebx
 mov edi,ebx
 mov esi,ebx
.mode_0_palettes:
 mov [M0_Color_BG1],ebx
 mov [M0_Color_BG2],ecx
 mov [M0_Color_BG3],edi
 mov [M0_Color_BG4],esi

 pop esi
 pop edi

; BGMODE_Allowed_Layer_Mask = BGMODE_Allowed_Layer_Mask_Table[mode];
; BGMODE_Tile_Layer_Mask = BGMODE_Tile_Layer_Mask_Table[mode];
; Render_Mode = Screen_Mode[mode];
 xor ebx,ebx

 mov cl,[BGMODE_Tile_Layer_Mask_Table+edx]
 mov bl,[BGMODE_Allowed_Layer_Mask_Table+edx]
 mov [BGMODE_Tile_Layer_Mask],cl
 and cl,0x0F
 jnz .not_mode7
 and bl,[C_LABEL(EXTBG_Mask)]
.not_mode7:
 mov [BGMODE_Allowed_Layer_Mask],bl

 mov bl,[BGMODE_Allowed_Offset_Change_Table+edx]
 mov ecx,[Screen_Mode+edx*4]
 lea edx,[BGMODE_Depth_Table+edx]
 mov [BGMODE_Allowed_Offset_Change],bl
 mov [Redo_Offset_Change],bl
 mov [Render_Mode],ecx

; DepthBG1 = BGMODE_Depth_Table[0][mode];
; if (DepthBG1 & 3)
; {
;  int tilesize;
;  NBATableBG1 = Depth_NBA_Table[DepthBG1 & 3];
;  SetAddressBG1 = NBATableBG1[NBABG1];
;  tilesize = BGMODE & 0x10 ? 2 : 1;
;  TileHeightBG1 = TileWidthBG1 = tilesize;
;
;  DepthBG2 = BGMODE_Depth_Table[1][mode];
;  if (DepthBG2 & 3)
;  {
;   NBATableBG2 = Depth_NBA_Table[DepthBG2 & 3];
;   SetAddressBG2 = NBATableBG2[NBABG2];
;   tilesize = BGMODE & 0x20 ? 2 : 1;
;   TileHeightBG2 = TileWidthBG2 = tilesize;
;
;   DepthBG3 = BGMODE_Depth_Table[2][mode];
;   DepthBG4 = BGMODE_Depth_Table[3][mode];
;
;   tilesize = BGMODE & 0x40 ? 2 : 1;
;   TileHeightBG3 = TileWidthBG3 = tilesize;
;
;   tilesize = BGMODE & 0x80 ? 2 : 1;
;   TileHeightBG4 = TileWidthBG4 = tilesize;
;  }

 mov cl,[edx]
 mov bl,[NBABG1]
 mov [DepthBG1],cl
 and ecx,byte 3
 jz .no_more_tile_layers

 mov ecx,[Depth_NBA_Table+ecx*4]
 mov [NBATableBG1],ecx
 mov ecx,[ecx+ebx*4]
 mov [SetAddressBG1],ecx

 test al,0x10   ; get (tile height / 8) for BG1
 mov bl,2
 jnz .large_tiles_bg1_1
 mov bl,1
.large_tiles_bg1_1:
 mov [TileHeightBG1],bl
 mov [TileWidthBG1],bl

 mov cl,[edx+8]
 mov bl,[NBABG2]
 mov [DepthBG2],cl
 and ecx,byte 3
 jz .no_more_tile_layers
 mov ecx,[Depth_NBA_Table+ecx*4]
 mov [NBATableBG2],ecx
 mov ecx,[ecx+ebx*4]
 mov [SetAddressBG2],ecx

 test al,0x20   ; get (tile height / 8) for BG2
 mov bl,2
 jnz .large_tiles_bg2_1
 mov bl,1
.large_tiles_bg2_1:
 mov [TileHeightBG2],bl
 mov [TileWidthBG2],bl

 mov bl,[edx+16]
 mov cl,[edx+24]
 mov [DepthBG3],bl
 mov [DepthBG4],cl

 test al,0x40   ; get (tile height / 8) for BG3
 mov bl,2
 jnz .large_tiles_bg3_1
 mov bl,1
.large_tiles_bg3_1:
 mov [TileHeightBG3],bl
 mov [TileWidthBG3],bl

 test al,al     ; get (tile height / 8) for BG4
 mov bl,2
 js .large_tiles_bg4_1
 mov bl,1
.large_tiles_bg4_1:
 mov [TileHeightBG4],bl
 mov [TileWidthBG4],bl


.no_more_tile_layers:
 mov byte [Redo_Layering],-1
 mov al,[C_LABEL(BGMODE)]

 mov edx,eax
 and edx,byte 7
 xor ebx,ebx
 cmp edx,byte 5
 jae .wide_mode

 mov bl,[DepthBG1]
 test al,0x10
 mov edx,[LineRenderLarge+ebx*4]
 jnz .large_tiles_bg1_2
 mov edx,[LineRenderSmall+ebx*4]
.large_tiles_bg1_2:
 mov [LineRenderBG1],edx

 mov bl,[DepthBG2]
 test al,0x20
 mov edx,[LineRenderLarge+ebx*4]
 jnz .large_tiles_bg2_2
 mov edx,[LineRenderSmall+ebx*4]
.large_tiles_bg2_2:
 mov [LineRenderBG2],edx

 mov bl,[DepthBG3]
 test al,0x40
 mov edx,[LineRenderLarge+ebx*4]
 jnz .large_tiles_bg3_2
 mov edx,[LineRenderSmall+ebx*4]
.large_tiles_bg3_2:
 mov [LineRenderBG3],edx

 mov bl,[DepthBG4]
 test al,al
 mov edx,[LineRenderLarge+ebx*4]
 js .large_tiles_bg4_2
 mov edx,[LineRenderSmall+ebx*4]
.large_tiles_bg4_2:
 mov [LineRenderBG4],edx

 pop ecx
 pop ebx
.no_change:
 ret

ALIGNC
; Mode 5/6: uses half-wide tile counts for half-512
.wide_mode:
 mov bl,1
 ; 16-wide tiles with 8-wide addressing on background layers always
 mov [TileWidthBG1],bl
 mov [TileWidthBG2],bl
 mov [TileWidthBG3],bl
 mov [TileWidthBG4],bl

 mov bl,[DepthBG1]
 test al,0x10
 mov edx,[LineRenderEvenLarge+ebx*4]
 jnz .large_tiles_wide_bg1
 mov edx,[LineRenderEvenSmall+ebx*4]
.large_tiles_wide_bg1:
 mov [LineRenderBG1],edx

 mov bl,[DepthBG2]
 test al,0x20
 mov edx,[LineRenderEvenLarge+ebx*4]
 jnz .large_tiles_wide_bg2
 mov edx,[LineRenderEvenSmall+ebx*4]
.large_tiles_wide_bg2:
 mov [LineRenderBG2],edx

 mov bl,[DepthBG3]
 test al,0x40
 mov edx,[LineRenderEvenLarge+ebx*4]
 jnz .large_tiles_wide_bg3
 mov edx,[LineRenderEvenSmall+ebx*4]
.large_tiles_wide_bg3:
 mov [LineRenderBG3],edx

 mov bl,[DepthBG4]
 test al,al
 mov edx,[LineRenderEvenLarge+ebx*4]
 js .large_tiles_wide_bg4
 mov edx,[LineRenderEvenSmall+ebx*4]
.large_tiles_wide_bg4:
 mov [LineRenderBG4],edx

 pop ecx
 pop ebx
 ret

ALIGNC
SNES_W2106: ; MOSAIC
 cmp [MOSAIC],al
 je .no_change
%ifdef FORCE_MOSAIC
 push eax    ;***
%endif
 UpdateDisplay  ;*
%ifdef FORCE_MOSAIC
 mov al,0x0F + (FORCE_MOSAIC << 4) ;***
%endif
 mov [MOSAIC],al
 mov edx,eax
 and al,0x01
 mov [MosaicBG1],al
 mov eax,edx
 and al,0x02
 mov [MosaicBG2],al
 mov eax,edx
 and al,0x04
 mov [MosaicBG3],al
 mov eax,edx
 and al,0x08
 mov [MosaicBG4],al
 mov eax,edx
 shr edx,4
 and edx,byte 15
 inc edx
 mov [Mosaic_Size],edx
 dec edx
 shl edx,8
 mov [Mosaic_Size_Select],edx
%ifdef FORCE_MOSAIC
 pop eax    ;***
%endif
.no_change:
 ret

ALIGNC
SNES_W2107: ; BG1SC
 cmp [C_LABEL(BG1SC)],al
 je Update_BGSC.no_change
 LOAD_BG_TABLE 1
Update_BGSC:
 push edi
 push edx
 UpdateDisplay  ;*
 pop edx
 mov edi,eax
 push esi
 and edi,byte 0x7C
 mov esi,C_LABEL(VRAM)
 shl edi,9
 mov [BGSC+edx],al
 push ebx
 lea ebx,[esi+edi]
 mov [MapAddress+edx],ebx

 test al,3
 jz .one_screen
 lea edi,[edi+32*32*2]
 jpe .four_screen
 and edi,0xFFFF ;enforce VRAM wrap
 test al,1
 jz .tall_screen

.wide_screen:
 add edi,esi
 mov [BLMapAddress+edx],ebx
 mov [TRMapAddress+edx],edi
 mov [BRMapAddress+edx],edi
 jmp .have_screen_addresses

.tall_screen:
 add edi,esi
 mov [TRMapAddress+edx],ebx
 mov [BLMapAddress+edx],edi
 mov [BRMapAddress+edx],edi
 jmp .have_screen_addresses

.one_screen:
 mov [TRMapAddress+edx],ebx
 mov [BLMapAddress+edx],ebx
 mov [BRMapAddress+edx],ebx
 jmp .have_screen_addresses

.four_screen:
 push eax
 lea eax,[edi+32*32*2]
 lea ebx,[edi+32*32*2*2]
 add edi,esi
 and eax,0xFFFF
 and ebx,0xFFFF
 add eax,esi
 add ebx,esi
 mov [TRMapAddress+edx],edi
 mov [BLMapAddress+edx],eax
 mov [BRMapAddress+edx],ebx
 pop eax

.have_screen_addresses:
 pop ebx
 pop esi
 pop edi
.no_change:
 ret

ALIGNC
SNES_W2108: ; BG2SC
 cmp [C_LABEL(BG2SC)],al
 je Update_BGSC.no_change
 LOAD_BG_TABLE 2
 jmp Update_BGSC

ALIGNC
SNES_W2109: ; BG3SC
 cmp [C_LABEL(BG3SC)],al
 je Update_BGSC.no_change
 mov byte [Redo_Offset_Change_VOffsets],0xFF
 mov byte [Redo_Offset_Change],0xFF
 LOAD_BG_TABLE 3
 jmp Update_BGSC

ALIGNC
SNES_W210A: ; BG4SC
 cmp [C_LABEL(BG4SC)],al
 je Update_BGSC.no_change
 LOAD_BG_TABLE 4
 jmp Update_BGSC

ALIGNC
SNES_W210B: ; BG12NBA
 cmp [C_LABEL(BG12NBA)],al
 je .no_change
 UpdateDisplay  ;*
 push ebx
 mov [C_LABEL(BG12NBA)],al
 mov bl,al
 and ebx,byte 7
 mov edx,[NBATableBG1]
 mov [NBABG1],bl
 mov ebx,[edx+ebx*4]
 mov [SetAddressBG1],ebx
 mov bl,al
 shr ebx,4
 and ebx,byte 7
 mov edx,[NBATableBG2]
 mov [NBABG2],bl
 mov ebx,[edx+ebx*4]
 mov [SetAddressBG2],ebx
 pop ebx
.no_change:
 ret

ALIGNC
SNES_W210C: ; BG34NBA
 cmp [C_LABEL(BG34NBA)],al
 je .no_change
 UpdateDisplay  ;*
 push ebx
 mov [C_LABEL(BG34NBA)],al

 mov ebx,eax
 and ebx,byte 7
 shl ebx,12     ; * 8k * 4 (2bpl) / 8
 mov [SetAddressBG3],ebx

 mov ebx,eax
 shr ebx,4
 and ebx,byte 7
 shl ebx,12     ; * 8k * 4 (2bpl) / 8
 mov [SetAddressBG4],ebx

 pop ebx
.no_change:
 ret

ALIGNC
SNES_W210D: ; BG1HOFS
%ifdef TRAP_BGHOFS
 pusha  ;*
 xor ebx,ebx
 mov bl,[C_LABEL(Current_Line_Timing)]
 shl ebx,16
 or ebx,0x210D
 mov [C_LABEL(Map_Address)],ebx ; Set up Map Address so message works!
 mov [C_LABEL(Map_Byte)],al     ; Set up Map Byte so message works
 call C_LABEL(InvalidHWWrite)   ; Unmapped hardware address!
 popa   ;*
%endif

 push ebx
 mov bl,[BGOFS_Last_Write]
 mov bh,al
 mov [BGOFS_Last_Write],al

 cmp [C_LABEL(BG1HOFS)],bx
 je .no_change
 UpdateDisplay  ;*scroll
 mov [C_LABEL(BG1HOFS)],ebx

 mov bl,0x40    ; Recalculate H
 or [Redo_M7],bl

 mov bl,1
.no_change:

 pop ebx
 ret

ALIGNC
SNES_W210E: ; BG1VOFS
%ifdef TRAP_BGVOFS
 pusha  ;*
 xor ebx,ebx
 mov bl,[C_LABEL(Current_Line_Timing)]
 shl ebx,16
 or ebx,0x210E
 mov [C_LABEL(Map_Address)],ebx ; Set up Map Address so message works!
 mov [C_LABEL(Map_Byte)],al     ; Set up Map Byte so message works
 call C_LABEL(InvalidHWWrite)   ; Unmapped hardware address!
 popa   ;*
%endif

 push ebx
 mov bl,[BGOFS_Last_Write]
 mov bh,al
 mov [BGOFS_Last_Write],al

 cmp [C_LABEL(BG1VOFS)],bx
 je .no_change
 UpdateDisplay  ;*scroll
 mov [C_LABEL(BG1VOFS)],ebx

 mov bl,0x80    ; Recalculate V
 or [Redo_M7],bl
.no_change:

 pop ebx
 ret

ALIGNC
SNES_W210F: ; BG2HOFS
%ifdef TRAP_BGHOFS
 pusha  ;*
 xor ebx,ebx
 mov bl,[C_LABEL(Current_Line_Timing)]
 shl ebx,16
 or ebx,0x210F
 mov [C_LABEL(Map_Address)],ebx ; Set up Map Address so message works!
 mov [C_LABEL(Map_Byte)],al     ; Set up Map Byte so message works
 call C_LABEL(InvalidHWWrite)   ; Unmapped hardware address!
 popa   ;*
%endif

 push ebx
 mov bl,[BGOFS_Last_Write]
 mov bh,al
 mov [BGOFS_Last_Write],al

 cmp [C_LABEL(BG2HOFS)],bx
 je .no_change
 UpdateDisplay  ;*scroll
 mov [C_LABEL(BG2HOFS)],ebx

 mov bl,2
.no_change:

 pop ebx
 ret

ALIGNC
SNES_W2110: ; BG2VOFS
%ifdef TRAP_BGVOFS
 pusha  ;*
 xor ebx,ebx
 mov bl,[C_LABEL(Current_Line_Timing)]
 shl ebx,16
 or ebx,0x2110
 mov [C_LABEL(Map_Address)],ebx ; Set up Map Address so message works!
 mov [C_LABEL(Map_Byte)],al     ; Set up Map Byte so message works
 call C_LABEL(InvalidHWWrite)   ; Unmapped hardware address!
 popa   ;*
%endif

 push ebx
 mov bl,[BGOFS_Last_Write]
 mov bh,al
 mov [BGOFS_Last_Write],al

 cmp [C_LABEL(BG2VOFS)],bx
 je .no_change
 UpdateDisplay  ;*scroll
 mov [C_LABEL(BG2VOFS)],ebx
.no_change:

 pop ebx
 ret

ALIGNC
SNES_W2111: ; BG3HOFS
%ifdef TRAP_BGHOFS
 pusha  ;*
 xor ebx,ebx
 mov bl,[C_LABEL(Current_Line_Timing)]
 shl ebx,16
 or ebx,0x2111
 mov [C_LABEL(Map_Address)],ebx ; Set up Map Address so message works!
 mov [C_LABEL(Map_Byte)],al     ; Set up Map Byte so message works
 call C_LABEL(InvalidHWWrite)   ; Unmapped hardware address!
 popa   ;*
%endif

 push ebx
 mov bl,[BGOFS_Last_Write]
 mov bh,al
 mov [BGOFS_Last_Write],al

 cmp [C_LABEL(BG3HOFS)],bx
 je .no_change
 UpdateDisplay  ;*scroll
 mov [C_LABEL(BG3HOFS)],ebx

 mov bl,4
 mov [Redo_Offset_Change],bl
.no_change:

 pop ebx
 ret

ALIGNC
SNES_W2112: ; BG3VOFS
%ifdef TRAP_BGVOFS
 pusha  ;*
 xor ebx,ebx
 mov bl,[C_LABEL(Current_Line_Timing)]
 shl ebx,16
 or ebx,0x2112
 mov [C_LABEL(Map_Address)],ebx ; Set up Map Address so message works!
 mov [C_LABEL(Map_Byte)],al     ; Set up Map Byte so message works
 call C_LABEL(InvalidHWWrite)   ; Unmapped hardware address!
 popa   ;*
%endif

 push ebx
 mov bl,[BGOFS_Last_Write]
 mov bh,al
 mov [BGOFS_Last_Write],al

 cmp [C_LABEL(BG3VOFS)],bx
 je .no_change
 UpdateDisplay  ;*scroll
 mov [C_LABEL(BG3VOFS)],ebx

 mov byte [Redo_Offset_Change_VOffsets],0xFF
 mov byte [Redo_Offset_Change],0xFF
.no_change:

 pop ebx
 ret

ALIGNC
SNES_W2113: ; BG4HOFS
%ifdef TRAP_BGHOFS
 pusha  ;*
 xor ebx,ebx
 mov bl,[C_LABEL(Current_Line_Timing)]
 shl ebx,16
 or ebx,0x2113
 mov [C_LABEL(Map_Address)],ebx ; Set up Map Address so message works!
 mov [C_LABEL(Map_Byte)],al     ; Set up Map Byte so message works
 call C_LABEL(InvalidHWWrite)   ; Unmapped hardware address!
 popa   ;*
%endif

 push ebx
 mov bl,[BGOFS_Last_Write]
 mov bh,al
 mov [BGOFS_Last_Write],al

 cmp [C_LABEL(BG4HOFS)],bx
 je .no_change
 UpdateDisplay  ;*scroll
 mov [C_LABEL(BG4HOFS)],ebx

 mov bl,8
.no_change:

 pop ebx
 ret

ALIGNC
SNES_W2114: ; BG4VOFS
%ifdef TRAP_BGVOFS
 pusha  ;*
 xor ebx,ebx
 mov bl,[C_LABEL(Current_Line_Timing)]
 shl ebx,16
 or ebx,0x2114
 mov [C_LABEL(Map_Address)],ebx ; Set up Map Address so message works!
 mov [C_LABEL(Map_Byte)],al     ; Set up Map Byte so message works
 call C_LABEL(InvalidHWWrite)   ; Unmapped hardware address!
 popa   ;*
%endif

 push ebx
 mov bl,[BGOFS_Last_Write]
 mov bh,al
 mov [BGOFS_Last_Write],al

 cmp [C_LABEL(BG4VOFS)],bx
 je .no_change
 UpdateDisplay  ;*scroll
 mov [C_LABEL(BG4VOFS)],ebx
.no_change:

 pop ebx
 ret

ALIGNC
SNES_W2115: ; VMAIN
 mov [C_LABEL(VMAIN)],al    ; Get our copy of this
 and al,0x0C
 jz .no_full
 cmp al,2*4
 je .full_64
 ja .full_128

.full_32:
 mov dword [VMDATAREAD_update],VMDATAREAD_update_FULL_32
 Set_21_Write 0x18,SNES_W2118_FULL_32
 Set_21_Write 0x19,SNES_W2119_FULL_32
 jmp .full_done

ALIGNC
.full_64:
 mov dword [VMDATAREAD_update],VMDATAREAD_update_FULL_64
 Set_21_Write 0x18,SNES_W2118_FULL_64
 Set_21_Write 0x19,SNES_W2119_FULL_64
 jmp .full_done

ALIGNC
.full_128:
 mov dword [VMDATAREAD_update],VMDATAREAD_update_FULL_128
 Set_21_Write 0x18,SNES_W2118_FULL_128
 Set_21_Write 0x19,SNES_W2119_FULL_128
 jmp .full_done

ALIGNC
.no_full:
 mov dword [VMDATAREAD_update],VMDATAREAD_update_NORM
 Set_21_Write 0x18,SNES_W2118_NORM
 Set_21_Write 0x19,SNES_W2119_NORM
.full_done:
 mov al,[C_LABEL(VMAIN)]
 and al,3
 jnz .not_1

 mov byte [SCINC],1
 mov al,[C_LABEL(VMAIN)]
 ret

ALIGNC
.not_1:
 cmp al,2
 jae .not_32

 mov byte [SCINC],32
 mov al,[C_LABEL(VMAIN)]
 ret

ALIGNC
.not_32:
 ; A bug in SNES makes mode 2 = 128
 mov byte [SCINC],128
 mov al,[C_LABEL(VMAIN)]
 ret

ALIGNC
SNES_W2116: ; VMADDL
 mov edx,[VRAMAddress]
 mov dl,al
 mov [VRAMAddress],al
 mov dx,[C_LABEL(VRAM)+edx*2]
 mov [VMDATAREAD_buffer],dx
 ret

ALIGNC
SNES_W2117: ; VMADDH
 mov edx,[VRAMAddress]
 mov dh,0x7F
 and dh,al
 mov [VRAMAddress+1],dh
 mov dx,[C_LABEL(VRAM)+edx*2]
 mov [VMDATAREAD_buffer],dx
 ret

%macro VRAM_Cache_Check 0
;  Check upper boundary
;  Check within set (?)
%ifdef Set_Based_Tile_Cache
 mov ebx,[Tile_Recache_Set_End]
%endif
;shr edx,3
 shr edx,5
%ifdef Set_Based_Tile_Cache
 sub ebx,edx
 je %%end_of_set    ; Simplest case - tile is end of set
%ifdef Check_Within_Tile_Set
 jg %%check_within_set  ; Tile may be within set?
%else
 jg %%new_set
%endif
 ; Tile may be immediately after set?
 cmp ebx,-1
%ifdef Check_Within_Tile_Set
 jne %%new_set
 jmp %%extend_set_one_tile
%%check_within_set:
 ; Tile may be within set?
 cmp [Tile_Recache_Set_Begin],edx
 jle %%end_of_set
%else
 je %%extend_set_one_tile
%endif
%%new_set:
 ; New set
 push edi
 mov edi,[Tile_Recache_Set_End]
 inc edi
 js %%recache_done  ; No set to recache?
 sub edi,[Tile_Recache_Set_Begin]
 call Recache_Tile_Set
%%recache_done:
 pop edi
 mov [Tile_Recache_Set_Begin],edx
%%extend_set_one_tile:
 mov [Tile_Recache_Set_End],edx
%%end_of_set:
%endif
%endmacro

%macro JUMP_NOT_VBLANK 1+
 cmp byte [HVBJOY], 0
 js %%in_vblank

 cmp byte [C_LABEL(INIDISP)], 0
 jns %1

%%in_vblank:
%endmacro


;bitshift (%1), bitmask (1 << (%1)) - 1, topmask 0x7FFF & ~((1 << ((%1) + 3)) - 1)
%macro GEN_SNES_W2118_2119_FULL 2 0
ALIGNC
; VMDATAL, full graphic increment
SNES_W2118_FULL_%2:
 push ebx

 JUMP_NOT_VBLANK .no_change

 mov edx,[VRAMAddress]
 push edi
 push eax
 mov edi,edx
 mov eax,edx
 shr edi,(%1)   ;Bitshift
 and eax,byte (1 << (%1)) - 1   ;Bitmask
 and edi,byte 7
 shl eax,3
 and edx,0x7FFF & ~((1 << ((%1) + 3)) - 1)  ;Topmask
 or edx,eax
 pop eax
 or edx,edi
 pop edi
 mov ebx,C_LABEL(VRAM)
 cmp [ebx+edx*2],al
 je .no_change
 push edx
 UpdateDisplay  ;*
 pop edx
%ifdef Profile_VRAM_Writes
 inc dword [C_LABEL(VMWriteL_Full)]
%endif
 mov [ebx+edx*2],al
 VRAM_Cache_Check
.no_change:
 mov bl,[C_LABEL(VMAIN)]
 test bl,bl
 js .no_increment
 mov edx,[SCINC]
 add edx,[VRAMAddress]  ; Always words (since <<1)!
 and edx,0x7FFF
 mov [VRAMAddress],edx
.no_increment:
 pop ebx
 ret

ALIGNC
; VMDATAH, full graphic increment
SNES_W2119_FULL_%2:
 push ebx

 JUMP_NOT_VBLANK .no_change

 mov edx,[VRAMAddress]
 push edi
 push eax
 mov edi,edx
 mov eax,edx
 shr edi,(%1)   ;Bitshift
 and eax,byte (1 << (%1)) - 1   ;Bitmask
 and edi,byte 7
 shl eax,3
 and edx,0x7FFF & ~((1 << ((%1) + 3)) - 1)  ;Topmask
 or edx,eax
 pop eax
 or edx,edi
 pop edi
 mov ebx,C_LABEL(VRAM)+1
 cmp [ebx+edx*2],al
 je .no_change
 push edx
 UpdateDisplay  ;*
 pop edx
%ifdef Profile_VRAM_Writes
 inc dword [C_LABEL(VMWriteH_Full)]
%endif
 mov [ebx+edx*2],al
 VRAM_Cache_Check
.no_change:
 mov bl,[C_LABEL(VMAIN)]
 test bl,bl
 jns .no_increment
 mov edx,[SCINC]
 add edx,[VRAMAddress]  ; Always words (since <<1)!
 and edx,0x7FFF
 mov [VRAMAddress],edx
.no_increment:
 pop ebx
 ret
%endmacro

ALIGNC
; VMDATAL, normal increment
SNES_W2118_NORM:
 push ebx

 JUMP_NOT_VBLANK .no_change

 mov ebx,C_LABEL(VRAM)
 mov edx,[VRAMAddress]
 cmp [ebx+edx*2],al
 je .no_change
 push edx
 UpdateDisplay  ;*
 pop edx
%ifdef Profile_VRAM_Writes
 inc dword [C_LABEL(VMWriteL_Norm)]
%endif
 mov [ebx+edx*2],al
 VRAM_Cache_Check
.no_change:
 mov bl,[C_LABEL(VMAIN)]
 test bl,bl
 js .no_increment
 mov edx,[SCINC]
 add edx,[VRAMAddress]  ; Always words (since <<1)!
 and edx,0x7FFF
 mov [VRAMAddress],edx
.no_increment:
 pop ebx
 ret

ALIGNC
; VMDATAH, normal increment
SNES_W2119_NORM:
 push ebx

 JUMP_NOT_VBLANK .no_change

 mov ebx,C_LABEL(VRAM)+1
 mov edx,[VRAMAddress]
 cmp [ebx+edx*2],al
 je .no_change
 push edx
 UpdateDisplay  ;*
 pop edx
%ifdef Profile_VRAM_Writes
 inc [C_LABEL(VMWriteH_Norm)]
%endif
 mov [ebx+edx*2],al
 VRAM_Cache_Check
.no_change:
 mov bl,[C_LABEL(VMAIN)]
 test bl,bl
 jns .no_increment
 mov edx,[SCINC]
 add edx,[VRAMAddress]  ; Always words (since <<1)!
 and edx,0x7FFF
 mov [VRAMAddress],edx
.no_increment:
 pop ebx
 ret

GEN_SNES_W2118_2119_FULL 5,32
GEN_SNES_W2118_2119_FULL 6,64
GEN_SNES_W2118_2119_FULL 7,128

; SNES_W211A: ; M7SEL in mode7.asm
; SNES_W211B: ; M7A in mode7.asm
; SNES_W211C: ; M7B in mode7.asm
; SNES_W211D: ; M7C in mode7.asm
; SNES_W211E: ; M7D in mode7.asm
; SNES_W211F: ; M7X in mode7.asm
; SNES_W2120: ; M7Y in mode7.asm

ALIGNC
SNES_W2121: ; CGADD
 push ebx
 xor ebx,ebx
 mov [CGAddress],al
 mov [CGHigh],bl
 mov [CGReadHigh],bl
 pop ebx
 ret

ALIGNC
SNES_W2122: ; CGDATA
 ; Palette should be set even if just lo byte set!
 ; We now set the palette in CGRAM

;UpdateDisplay  ;*16-bit rendering only
;push edx
 push ebx
 push eax
 xor ebx,ebx
 mov bl,[CGHigh]
 mov edx,[CGAddress]
 test ebx,ebx
 jnz .hi_byte

 cmp al,[C_LABEL(Real_SNES_Palette)+ebx+edx*2]
 jz .no_change
 mov byte [C_LABEL(PaletteChanged)],1
 mov [C_LABEL(Real_SNES_Palette)+ebx+edx*2],al
.no_change:
 mov bl,1
 pop eax
 mov [CGHigh],bl
 pop ebx
;pop edx
 ret

.hi_byte:
 and al,0x7F
 cmp al,[C_LABEL(Real_SNES_Palette)+ebx+edx*2]
 jz .no_change_hi
 mov byte [C_LABEL(PaletteChanged)],1
 mov [C_LABEL(Real_SNES_Palette)+ebx+edx*2],al

.no_change_hi:
 inc edx
 mov bl,0
 pop eax
 mov [CGHigh],bl
 pop ebx
 mov [CGAddress],dl ; Chop address for wrap
;pop edx
 ret

ALIGNC
SNES_W2123: ; W12SEL
 cmp al,[C_LABEL(W12SEL)]
 je .no_change
 UpdateDisplay  ;*windowing only
 or byte [Redo_Windowing],Redo_Win_BG(1) | Redo_Win_BG(2)
 mov [C_LABEL(W12SEL)],al
 mov [WSELBG1],al
 shr al,4
 mov [WSELBG2],al
 mov al,[C_LABEL(W12SEL)]

.no_change:
 ret

ALIGNC
SNES_W2124: ; W34SEL
 cmp al,[C_LABEL(W34SEL)]
 je .no_change
 UpdateDisplay  ;*windowing only
 or byte [Redo_Windowing],Redo_Win_BG(3) | Redo_Win_BG(4)
 mov [C_LABEL(W34SEL)],al
 mov [WSELBG3],al
 shr al,4
 mov [WSELBG4],al
 mov al,[C_LABEL(W34SEL)]

.no_change:
 ret

ALIGNC
SNES_W2125: ; WOBJSEL
 cmp al,[C_LABEL(WOBJSEL)]
 je .no_change
 UpdateDisplay  ;*windowing only
 or byte [Redo_Windowing],Redo_Win_OBJ | Redo_Win_Color
 mov [C_LABEL(WOBJSEL)],al

.no_change:
 ret

ALIGNC
SNES_W2126: ; WH0
 cmp al,[C_LABEL(WH0)]
 je .no_change
 UpdateDisplay  ;*windowing only
 or byte [Redo_Windowing],Redo_Win(1) | \
  Redo_Win_BG(1) | Redo_Win_BG(2) | Redo_Win_BG(3) | Redo_Win_BG(4) | \
  Redo_Win_OBJ | Redo_Win_Color
 mov [C_LABEL(WH0)],al

.no_change:
 ret

ALIGNC
SNES_W2127: ; WH1
 inc eax
 cmp al,[C_LABEL(WH1)]
 je .no_change
 UpdateDisplay  ;*windowing only
 or byte [Redo_Windowing],Redo_Win(1) | \
  Redo_Win_BG(1) | Redo_Win_BG(2) | Redo_Win_BG(3) | Redo_Win_BG(4) | \
  Redo_Win_OBJ | Redo_Win_Color
 mov [C_LABEL(WH1)],al

.no_change:
 dec eax
 ret

ALIGNC
SNES_W2128: ; WH2
 cmp al,[C_LABEL(WH2)]
 je .no_change
 UpdateDisplay  ;*windowing only
 or byte [Redo_Windowing],Redo_Win(2) | \
  Redo_Win_BG(1) | Redo_Win_BG(2) | Redo_Win_BG(3) | Redo_Win_BG(4) | \
  Redo_Win_OBJ | Redo_Win_Color
 mov [C_LABEL(WH2)],al

.no_change:
 ret

ALIGNC
SNES_W2129: ; WH3
 inc eax
 cmp al,[C_LABEL(WH3)]
 je .no_change
 UpdateDisplay  ;*windowing only
 or byte [Redo_Windowing],Redo_Win(2) | \
  Redo_Win_BG(1) | Redo_Win_BG(2) | Redo_Win_BG(3) | Redo_Win_BG(4) | \
  Redo_Win_OBJ | Redo_Win_Color
 mov [C_LABEL(WH3)],al

.no_change:
 dec eax
 ret

ALIGNC
SNES_W212A: ; WBGLOG
 cmp al,[C_LABEL(WBGLOG)]
 je .no_change
 UpdateDisplay  ;*windowing only
 or byte [Redo_Windowing], \
  Redo_Win_BG(1) | Redo_Win_BG(2) | Redo_Win_BG(3) | Redo_Win_BG(4)
 push ebx
 mov ebx,eax
 mov [C_LABEL(WBGLOG)],al
 shr bl,2
 mov [WLOGBG1],al
 shr al,4
 mov [WLOGBG2],bl
 shr bl,4
 mov [WLOGBG3],al
 mov [WLOGBG4],bl
 pop ebx
 mov al,[C_LABEL(WBGLOG)]

.no_change:
 ret

ALIGNC
SNES_W212B: ; WOBJLOG
 cmp al,[C_LABEL(WOBJLOG)]
 je .no_change
;UpdateDisplay  ;*windowing only
;or byte [Redo_Windowing],Redo_Win_OBJ | Redo_Win_Color
 mov [C_LABEL(WOBJLOG)],al

.no_change:
 ret

ALIGNC
EXPORT_C Update_Layering
 pusha

 mov byte [Redo_Layering],0

 or byte [Redo_Windowing], \
  Redo_Win_BG(1) | Redo_Win_BG(2) | Redo_Win_BG(3) | Redo_Win_BG(4) | \
  Redo_Win_OBJ

 mov al,[C_LABEL(TM)]
 mov bl,[C_LABEL(TS)]
 mov cl,[BGMODE_Allowed_Layer_Mask]
 mov dl,[C_LABEL(Layer_Disable_Mask)]
 and al,cl
 and bl,cl
 and al,dl
 and bl,dl
 mov [TM_Allowed],al
 mov [TS_Allowed],bl
 or al,bl
 mov [Layers_In_Use],al

 cmp byte [C_LABEL(Layering_Mode)],1
 je .Update_Layering_1
 ja .Update_Layering_2
.Update_Layering_0:
 mov dword [Render_Select],C_LABEL(Render_Layering_Option_0)
 mov dword [Window_Offset_First],BG_Win_Sub
 mov dword [Window_Offset_Second],BG_Win_Main

 ; layering option 0: main-on-sub
 mov al,[TM_Allowed]
 mov bl,[C_LABEL(TMW)]
 mov [SCR_TM],al
 mov [SCR_TMW],bl
 xor al,0xFF
 mov bl,[C_LABEL(TSW)]
 and al,[TS_Allowed]
 mov [SCR_TSW],bl
 mov [SCR_TS],al
 popa
 ret
ALIGNC
.Update_Layering_1:
 mov dword [Render_Select],C_LABEL(Render_Layering_Option_1)
 mov dword [Window_Offset_First],BG_Win_Main
 mov dword [Window_Offset_Second],BG_Win_Sub

 ; layering option 1: sub-on-main
 mov al,[TS_Allowed]
 mov bl,[C_LABEL(TSW)]
 mov [SCR_TS],al
 mov [SCR_TSW],bl
 xor al,0xFF
 mov bl,[C_LABEL(TMW)]
 and al,[TM_Allowed]
 mov [SCR_TMW],bl
 mov [SCR_TM],al
 popa
 ret
ALIGNC
.Update_Layering_2:
 mov dword [Render_Select],C_LABEL(Render_Layering_Option_2)
 mov dword [Window_Offset_First],BG_Win_Main
 mov dword [Window_Offset_Second],BG_Win_Sub

 ; layering option 2: main-with-sub
 mov al,[TM_Allowed]
 mov bl,[C_LABEL(TMW)]
 mov dl,[TS_Allowed]
 mov cl,[C_LABEL(TSW)]
 and bl,al
 and cl,dl
 or al,dl
 or bl,cl
 mov byte [SCR_TS],0
 mov [SCR_TM],al
 mov [SCR_TMW],bl
 popa
 ret

ALIGNC
SNES_W212C: ; TM
 cmp al,[C_LABEL(TM)]
 je .no_change
 UpdateDisplay  ;*
 mov [C_LABEL(TM)],al
 mov byte [Redo_Layering],-1
 or byte [Redo_Windowing], \
  Redo_Win_BG(1) | Redo_Win_BG(2) | Redo_Win_BG(3) | Redo_Win_BG(4) | \
  Redo_Win_OBJ
 mov al,[C_LABEL(TM)]

.no_change:
 ret

ALIGNC
SNES_W212D: ; TS
 cmp al,[C_LABEL(TS)]
 je .no_change
 UpdateDisplay  ;*
 mov [C_LABEL(TS)],al
 mov byte [Redo_Layering],-1
 or byte [Redo_Windowing], \
  Redo_Win_BG(1) | Redo_Win_BG(2) | Redo_Win_BG(3) | Redo_Win_BG(4) | \
  Redo_Win_OBJ
 mov al,[C_LABEL(TS)]

.no_change:
 ret

ALIGNC
SNES_W212E: ; TMW
 cmp al,[C_LABEL(TMW)]
 je .no_change
 UpdateDisplay  ;*windowing only
 mov [C_LABEL(TMW)],al
 mov byte [Redo_Layering],-1
 or byte [Redo_Windowing], \
  Redo_Win_BG(1) | Redo_Win_BG(2) | Redo_Win_BG(3) | Redo_Win_BG(4) | \
  Redo_Win_OBJ
 mov al,[C_LABEL(TMW)]

.no_change:
 ret

ALIGNC
SNES_W212F: ; TSW
 cmp al,[C_LABEL(TSW)]
 je .no_change
 UpdateDisplay  ;*windowing only
 mov [C_LABEL(TSW)],al
 mov byte [Redo_Layering],-1
 or byte [Redo_Windowing], \
  Redo_Win_BG(1) | Redo_Win_BG(2) | Redo_Win_BG(3) | Redo_Win_BG(4) | \
  Redo_Win_OBJ
 mov al,[C_LABEL(TSW)]

.no_change:
 ret

ALIGNC
SNES_W2130: ; CGWSEL
 cmp al,[C_LABEL(CGWSEL)]
 je .no_change
;UpdateDisplay  ;*windowing only
 or byte [Redo_Windowing],Redo_Win_Color
 mov [C_LABEL(CGWSEL)],al

.no_change:
 ret

ALIGNC
SNES_W2131: ; CGADSUB
 cmp al,[C_LABEL(CGADSUB)]
 je .no_change
;UpdateDisplay  ;*16-bit rendering only
 push eax
 mov [C_LABEL(CGADSUB)],al

 test al,0xA0   ; Hack for back area color addition
 mov ah,0
 jz .no_add_hack
 js .no_add_hack
 mov ah,-1
.no_add_hack:
 mov [C_LABEL(fixedpalettecheck)],ah
 pop eax
.no_change:
 ret

ALIGNC
SNES_W2132: ; COLDATA
;UpdateDisplay  ;*16-bit rendering only
 push ebx
 mov edx,[C_LABEL(COLDATA)]

 test al,0xC0
 jns .no_blue

 mov bl,al
 and ebx,0x1F
 shl ebx,10

 and edx,0x3FF
 or edx,ebx

 test al,0x40
.no_blue:
 jz .no_green

 mov bl,al
 and ebx,0x1F
 shl ebx,5

 and edx,0x7C1F
 or edx,ebx

.no_green:
 test al,0x20
 jz .no_red

 mov bl,al
 and ebx,0x1F

 and edx,0x7FE0
 or edx,ebx

.no_red:
 mov [C_LABEL(COLDATA)],edx
 pop ebx

 ret

ALIGNC
SNES_W2133: ; SETINI
 cmp al,[C_LABEL(SETINI)]
 je .no_change
 UpdateDisplay  ;*interlaced etc. not yet supported
 xor edx,edx
 test al,4
 mov [C_LABEL(SETINI)],al
 mov dl,239
 jnz .tall_screen
 mov dl,224
.tall_screen:
 ; if SETINI:6 (EXTBG enable) is clear, ignore BG2 enable (EXTBG)
 ; we pregenerate a mask for this here
 shr al,7
 mov [C_LABEL(LastRenderLine)],edx

 sbb dl,dl
 mov al,[BGMODE_Tile_Layer_Mask]
 or dl,~2
 and al,0x0F
 mov [C_LABEL(EXTBG_Mask)],dl
 jnz .not_mode7
 mov al,[BGMODE_Allowed_Layer_Mask_Table+7]
 and dl,al
 mov [BGMODE_Allowed_Layer_Mask],dl
.not_mode7:

 mov al,[C_LABEL(SETINI)]
.no_change:
 ret

; SNES_W2140_SKIP: ; APUI00 in APUskip.asm
; SNES_W2141_SKIP: ; APUI01 in APUskip.asm
; SNES_W2142_SKIP: ; APUI02 in APUskip.asm
; SNES_W2143_SKIP: ; APUI03 in APUskip.asm

; SNES_W2140_SPC:  ; APUI00 in spc700.asm
; SNES_W2141_SPC:  ; APUI01 in spc700.asm
; SNES_W2142_SPC:  ; APUI02 in spc700.asm
; SNES_W2143_SPC:  ; APUI03 in spc700.asm

ALIGNC
SNES_W2180: ; WMDATA
 mov edx,[WMADDL]
 add R_65c816_Cycles,_5A22_SLOW_CYCLE - _5A22_FAST_CYCLE
 mov [C_LABEL(WRAM)+edx],al
 inc edx
 and edx,0x01FFFF
 mov [WMADDL],edx
 ret

ALIGNC
SNES_W2181: ; WMADDL
 mov [WMADDL],al
 ret

ALIGNC
SNES_W2182: ; WMADDM
 mov [WMADDM],al
 ret

ALIGNC
SNES_W2183: ; WMADDH
 push eax
 and al,1
 mov [WMADDH],al
 pop eax
 ret

; Write to 40xx handlers
; SNES_W4016: ; JOYC1 in timing.inc
; SNES_W4017: ; JOYC2 in timing.inc

; Write to 42xx handlers
; SNES_W4200: ; NMITIMEN in timing.inc
; SNES_W4201: ; WRIO in timing.inc
; SNES_W4202: ; WRMPYA in timing.inc
; SNES_W4203: ; WRMPYB in timing.inc
; SNES_W4204: ; WRDIVL in timing.inc
; SNES_W4205: ; WRDIVH in timing.inc
; SNES_W4206: ; WRDIVB in timing.inc
; SNES_W4207: ; HTIMEL in timing.inc
; SNES_W4208: ; HTIMEH in timing.inc
; SNES_W4209: ; VTIMEL in timing.inc
; SNES_W420A: ; VTIMEH in timing.inc
; SNES_W420B: ; MDMAEN in DMA.asm
; SNES_W420C: ; HDMAEN in DMA.asm
; SNES_W420D: ; MEMSEL in timing.inc
; SNES_W4210: ; RDNMI in timing.inc
; SNES_W4211: ; TIMEUP in timing.inc

; Write to 43xx handlers
; SNES_W43xx: ; in DMA.asm

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
