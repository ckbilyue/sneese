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

;
;
; Screen mode setup/blitting code
; -Handlers to set up special display modes;
; -Virtual SNES screen -> PC screen copiers.
;
;

%include "misc.inc"
%include "ppu/screen.inc"

section .text
EXPORT scrmode_start

section .text
ALIGNC
EXPORT Set256x239   ; This sets up a 256x239 linear VGA mode
 pusha

 ; 0 -> Display -> Overscan -> Blank -> Retrace -> End Blank -> Overscan

 ; Disable CRTC write protect
 mov edx,0x3D4
 mov al,0x11
 out dx,al
 inc edx
 in  al,dx
 and al,0x7F
 out dx,al

 ; Start dumping regs to VGA
 ; Horizontal Total: 95 (+5) clocks
 ;  Display Enable: 63 (+1) clocks
 ;  Start Blanking: Clock 64   End Blanking: 34
 ;  Start Retrace:  Clock 78   End Retrace:  22
 ;  Display Enable Skew: 0     Retrace Skew: 0
 ; Vertical Total: 525 (+2) clocks
 ;  Display Enable: 477 (+1) rows
 ;  Start Blanking: Row 478    End Blanking: x0D
 ;  Start Retrace:  Row 478    End Retrace:  0010b

 mov edx,0x3C2
 ; - V sync, - H sync, 25.175MHz clock, enable memory, CGA CRTC addressing
 ; 0: CRTC addressing mode (0:MDA 3B4/1:CGA 3D4): CGA 3D4
 ; 1: Display memory access enable: enabled
 ; 2-3: Dot clock frequency select:
 ;  00: 25.175MHz (640 pixel wide modes)
 ;  01: 28.322MHz (720 pixel wide modes)
 ;  10, 11: External clock selects (max 65MHz)
 ; 4: Reserved = 0
 ; 5: Address extension bit: 0
 ; 6,7: Horizontal, Vertical sync polarity selects
 ;  0 = +, 1 = -
 ;  00 = ???   01 = 400   10 = 350    11 = 480
 mov al,0xE3        ; Misc. Output
 out dx,al
 mov edx,0x3D4      ; CRTC
 mov al,0           ; Horizontal Total
 mov ah,0x5F        ; 95 (+5) clocks
 out dx,ax
 mov al,1           ; Horizontal Display Enable
 mov ah,0x3F        ; 63 (+1) clocks
 out dx,ax
 mov al,2           ; Start Horizontal Blanking
 ; Primary centering control - increase number to move left
 mov ah,0x40        ; Clock 64
 out dx,ax
 mov al,3           ; End Horizontal Blanking
 ; 0-4: End Horizontal Blanking = 34 (bits 0-4 of 6)
 ; 5-6: Display Enable Skew = 0 clocks
 ; 7: Reserved/Lightpen (must be set for normal operation)
 mov ah,0x82
 out dx,ax
 mov al,4           ; Start Horizonal Retrace Pulse
 mov ah,0x4E        ; Clock 78
 out dx,ax
 mov al,5           ; End Horizontal Retrace
 ; 0-4: End Horizontal Retrace = 22 (clocks?)
 ; 5-6: Horizontal Retrace Skew = 0 clocks
 ; 7: End Horizontal Blanking = 34 (bit 5 of 6)
 mov ah,0x96
 out dx,ax
 mov al,6           ; Vertical Total (bits 0-7 of 10)
 mov ah,0x0D        ; 525 (+2)
 out dx,ax
 mov al,7           ; Overflow
 ; 0,5: Vertical Total = 525 rows (+2) (bits 8-9 of 10)
 ; 1,6: Vertical Display Enable End = Row 479 (bits 8-9 of 10)
 ; 2,7: Vertical Retrace Start = Row 480 (bits 8-9 of 10)
 ; 3: Start Vertical Blanking = Row 480 (bit 8 of 10)
 ; 4: Line Compare = (bit 8 of 10)
 mov ah,0x3E
 out dx,ax
 mov al,8           ; Preset Row Scan
 ; 0-4: Preset Row Scan = 0
 ; 5-6: Byte Panning Control = 0
 ; 7: Reserved = 0
 mov ah,0
 out dx,ax
 mov al,9           ; Maximum Scan Line
 ; 0-4: Maximum Scan Lines = 1 (+1)
 ; 5: Start Vertical Blanking = Row 480 (bit 9 of 10)
 ; 6: Line Compare = () (bit 9 of 10)
 ; 7: Double Scan Line Display = 0
 mov ah,0x41
 out dx,ax
 mov al,0x10        ; Vertical Retrace Start (bits 0-7 of 10)
 ; Primary centering control - increase number to move up
 mov ah,0xEA        ; Row 490
 out dx,ax
 mov al,0x11        ; Vertical Retrace End
 ; 0-3: Vertical Retrace End = 0010
 ; 4: Clear Vertical Interrupt: state cleared
 ; 5: Vertical Interrupt: disabled
 ; 6: Refresh Bandwidth Select: 3 memory refresh cycles/scan line
 ; 7: CRTC Register Protect: enabled
 mov ah,0xA2
 out dx,ax
 mov al,0x12        ; Vertical Display Enable End (bits 0-7 of 10)
 mov ah,0xDD        ; Row 477
 out dx,ax
 mov al,0x13        ; Offset
 mov ah,0x20        ; 32 * 8 = 256
 out dx,ax
 mov al,0x14        ; Underline Location
 ; 0-4: Underline Location = 0
 ; 5: Display Address Dwell 4 (clocks per address inc): 0 (1)
 ; 6: Display Address Unit 4 (unit size of address inc): 1 (4)
 ; 7: Reserved = 0
 mov ah,0x40
 out dx,ax
 mov al,0x15        ; Start Vertical Blanking (bits 0-7 of 10)
 mov ah,0xDD        ; Row 477
 out dx,ax
 mov al,0x16        ; End Vertical Blanking
 mov ah,0x0D        ; Row x0D
 out dx,ax
 mov al,0x17        ; CRTC Mode Control
 ; 0: Display address bit 13 = Row bit 0: disabled
 ; 1: Display address bit 14 = Row bit 1: disabled
 ; 2: Row counter increment frequency (by line or by 2): by line
 ; 3: Display Address Dwell 2 (clocks per address inc): 0 (1)
 ; 4: Reserved = 0
 ; 5: Display Address Unit Bank Selection (8k/32k): 32k
 ; 6: Display Address Unit 2 (unit size of address inc): 0 (4)
 ; 7: Reset/generate retrace signals: Generate
 mov ah,0xA3
 out dx,ax
 mov edx,0x3C4      ; Sequencer
 mov al,1
 mov ah,1
 out dx,ax
 mov al,4
 mov ah,0x0E
 out dx,ax
 mov edx,0x3CE      ; Graphics controller
 mov al,5
 mov ah,0x40
 out dx,ax
 mov al,6
 mov ah,5
 out dx,ax
 mov edx,0x3DA
 in al,dx
 mov edx,0x3C0
 mov al,0x30
 out dx,al
 mov al,0x41
 out dx,al
 mov edx,0x3DA
 in al,dx
 mov edx,0x3C0
 mov al,0x33
 out dx,al
 mov al,0
 out dx,al
 popa
 ret

ALIGNC
EXPORT Set256x224   ; This sets up a 256x224 linear VGA mode
 pusha

 ; 0 -> Display -> Overscan -> Blank -> Retrace -> End Blank -> Overscan

 ; Disable CRTC write protect
 mov edx,0x3D4
 mov al,0x11
 out dx,al
 inc edx
 in  al,dx
 and al,0x7F
 out dx,al

 ; Start dumping regs to VGA
 mov edx,0x3C2
 ; - V sync, - H sync, 25.175MHz clock, enable memory, CGA CRTC addressing
 mov al,0xE3        ; Misc. Output
 out dx,al
 mov edx,0x3D4      ; CRTC
 mov al,0           ; Horizontal Total
 mov ah,0x5F        ; 95 (+5) clocks
 out dx,ax
 mov al,1           ; Horizontal Display Enable
 mov ah,0x3F        ; 63 (+1) clocks
 out dx,ax
 mov al,2           ; Start Horizontal Blanking
 ; Primary centering control - increase number to move left
 mov ah,0x40        ; Clock 64
 out dx,ax
 mov al,3           ; End Horizontal Blanking
 ; 0-4: End Horizontal Blanking = 34 (bits 0-4 of 6)
 ; 5-6: Display Enable Skew = 0 clocks
 ; 7: Reserved/Lightpen (must be set for normal operation)
 mov ah,0x82
 out dx,ax
 mov al,4           ; Start Horizonal Retrace Pulse
 mov ah,0x4E        ; Clock 78
 out dx,ax
 mov al,5           ; End Horizontal Retrace
 ; 0-4: End Horizontal Retrace = 22 (clocks?)
 ; 5-6: Horizontal Retrace Skew = 0 clocks
 ; 7: End Horizontal Blanking = 34 (bit 5 of 6)
 mov ah,0x96
 out dx,ax
 mov al,6           ; Vertical Total (bits 0-7 of 10)
 mov ah,0x0D        ; 525 (+2)
 out dx,ax
 mov al,7           ; Overflow
 ; 0,5: Vertical Total = 525 rows (+2) (bits 8-9 of 10)
 ; 1,6: Vertical Display Enable End = Row 479 (bits 8-9 of 10)
 ; 2,7: Vertical Retrace Start = Row 480 (bits 8-9 of 10)
 ; 3: Start Vertical Blanking = Row 480 (bit 8 of 10)
 ; 4: Line Compare = (bit 8 of 10)
 mov ah,0x3E
 out dx,ax
 mov al,8           ; Preset Row Scan
 ; 0-4: Preset Row Scan = 0
 ; 5-6: Byte Panning Control = 0
 ; 7: Reserved = 0
 mov ah,0
 out dx,ax
 mov al,9           ; Maximum Scan Line
 ; 0-4: Maximum Scan Lines = 1 (+1)
 ; 5: Start Vertical Blanking = Row 480 (bit 9 of 10)
 ; 6: Line Compare = () (bit 9 of 10)
 ; 7: Double Scan Line Display = 0
 mov ah,0x41
 out dx,ax
 mov al,0x10        ; Vertical Retrace Start (bits 0-7 of 10)
 ; Primary centering control - increase number to move up
 mov ah,0xE0        ; Row 480
 out dx,ax
 mov al,0x11        ; Vertical Retrace End
 ; 0-3: Vertical Retrace End = 0010
 ; 4: Clear Vertical Interrupt: state cleared
 ; 5: Vertical Interrupt: disabled
 ; 6: Refresh Bandwidth Select: 3 memory refresh cycles/scan line
 ; 7: CRTC Register Protect: enabled
 mov ah,0xA2
 out dx,ax
 mov al,0x12        ; Vertical Display Enable End (bits 0-7 of 10)
 mov ah,0xBF        ; Row 447
 out dx,ax
 mov al,0x13        ; Offset
 mov ah,0x20        ; 32 * 8 = 256
 out dx,ax
 mov al,0x14        ; Underline Location
 ; 0-4: Underline Location = 0
 ; 5: Display Address Dwell 4 (clocks per address inc): 0 (1)
 ; 6: Display Address Unit 4 (unit size of address inc): 1 (4)
 ; 7: Reserved = 0
 mov ah,0x40
 out dx,ax
 mov al,0x15        ; Start Vertical Blanking (bits 0-7 of 10)
 mov ah,0xBD        ; Row 445
 out dx,ax
 mov al,0x16        ; End Vertical Blanking
 mov ah,0x0D        ; Row x0D
 out dx,ax
 mov al,0x17        ; CRTC Mode Control
 ; 0: Display address bit 13 = Row bit 0: disabled
 ; 1: Display address bit 14 = Row bit 1: disabled
 ; 2: Row counter increment frequency (by line or by 2): by line
 ; 3: Display Address Dwell 2 (clocks per address inc): 0 (1)
 ; 4: Reserved = 0
 ; 5: Display Address Unit Bank Selection (8k/32k): 32k
 ; 6: Display Address Unit 2 (unit size of address inc): 0 (4)
 ; 7: Reset/generate retrace signals: Generate
 mov ah,0xA3
 out dx,ax
 mov edx,0x3C4      ; Sequencer
 mov al,1
 mov ah,1
 out dx,ax
 mov al,4
 mov ah,0x0E
 out dx,ax
 mov edx,0x3CE      ; Graphics controller
 mov al,5
 mov ah,0x40
 out dx,ax
 mov al,6
 mov ah,5
 out dx,ax
 mov edx,0x3DA
 in  al,dx
 mov edx,0x3C0
 mov al,0x30
 out dx,al
 mov al,0x41
 out dx,al
 mov edx,0x3DA
 in  al,dx
 mov edx,0x3C0
 mov al,0x33
 out dx,al
 mov al,0
 out dx,al
 popa
 ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
