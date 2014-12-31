/*

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

*/

/* Mode 7 matrix rendering / hardware port emulation.*/

#ifndef M7_Generate_Handlers

#include "misc.h"
/*
%include "ppu/sprites.inc"
%include "ppu/screen.inc"
%include "ppu/ppu.inc"
*/

extern unsigned Ready_Line_Render;
extern unsigned char Tile_priority_bit;
extern unsigned char Layer_Disable_Mask;
extern unsigned char SETINI;

extern void (*_M7_Handler_Table[4])(
 unsigned output_surface_offset, unsigned lines,
 int first_pixel, int pixel_count);

#define TEXTERN extern

TEXTERN unsigned Mode7_AHX;     /* M7A * (M7H - M7X) + (M7X << 8) */
TEXTERN unsigned Mode7_VY;      /* M7V - M7Y */
TEXTERN unsigned Mode7_CHXY;    /* M7C * (M7H - M7X) + (M7Y << 8) */
/* M7A * (M7H - M7X) + (M7X << 8) + M7B * (line + M7V - M7Y) */
TEXTERN unsigned Mode7_Line_X;
/* M7C * (M7H - M7X) + (M7Y << 8) + M7D * (line + M7V - M7Y) */
TEXTERN unsigned Mode7_Line_Y;

TEXTERN unsigned M7A;
TEXTERN unsigned M7B;
TEXTERN unsigned M7C;
TEXTERN unsigned M7D;
TEXTERN unsigned M7X_13;
TEXTERN unsigned M7Y_13;
TEXTERN unsigned M7H_13;
TEXTERN unsigned M7V_13;
TEXTERN unsigned M7X;
TEXTERN unsigned M7Y;
TEXTERN unsigned M7H;
TEXTERN unsigned M7V;

/* M7A, M7C are taken from here to help handle X-flip */
TEXTERN unsigned M7A_X, M7C_X;

/* M7A, M7C are taken from here to help handle X-flip and mosaic */
TEXTERN unsigned M7A_XM, M7C_XM;

TEXTERN unsigned MPY;   /* Mode 7 multiplication result */
#define MPYL (MPY & 0xFF)         /* low byte */
#define MPYM ((MPY >> 8) & 0xFF)  /* middle byte */
#define MPYH ((MPY >> 16) & 0xFF) /* high byte */

void (*_M7_Handler)(unsigned output_surface_offset, unsigned lines,
 int first_pixel, int pixel_count);

TEXTERN unsigned char EXTBG_Mask;   /* mask applied to BG enable for EXTBG */
TEXTERN unsigned char M7SEL;    /* ab0000yx  ab=overflow control,y=flip v,x=flip h */
TEXTERN unsigned char Redo_M7;  /* vhyxdcba */
TEXTERN unsigned char M7_Last_Write;
TEXTERN unsigned char M7_Used;
TEXTERN unsigned char M7_Unused;
TEXTERN unsigned char Redo_16x8;

#if 0
/* BG1 area |  BG2 area = displayed mode 7 background
   BG2 area = EXTBG, high priority */

/* BG1 area + BG2 area on main screen; both screens in 8-bit rendering */
MERGED_WIN_DATA Mode7_Main,4
/* BG1 area + BG2 area on sub screen (currently unused) */
MERGED_WIN_DATA Mode7_Sub,4

/* !BG1 area on main screen; both screens in 8-bit rendering */
MERGED_WIN_DATA BG1_Main_Off,3
/* !BG1 area on sub screen (currently unused) */
MERGED_WIN_DATA BG1_Sub_Off,3

/* !BG2 area on main screen; both screens in 8-bit rendering */
MERGED_WIN_DATA BG2_Main_Off,3
/* !BG2 area on sub screen (currently unused) */
MERGED_WIN_DATA BG2_Sub_Off,3

/* !BG1 area &  BG2 area = EXTBG, low priority
   main screen; both in 8-bit */
MERGED_WIN_DATA Mode7_Main_EXTBG_Low,3
/* sub screen */
MERGED_WIN_DATA Mode7_Sub_EXTBG_Low,3

/* BG1 area &  BG2 area = EXTBG, normal priority
   main screen; both in 8-bit */
MERGED_WIN_DATA Mode7_Main_EXTBG_Normal,3
/* sub screen */
MERGED_WIN_DATA Mode7_Sub_EXTBG_Normal,3

/* BG1 area & !BG2 area = no EXTBG
   main screen; both in 8-bit */
MERGED_WIN_DATA Mode7_Main_EXTBG_Off,3
/* sub screen */
MERGED_WIN_DATA Mode7_Sub_EXTBG_Off,3
#endif


#define SIGN_EXTEND(val,bits) \
 ((((val) & BITMASK(0, (bits) - 1)) ^ BIT((bits) - 1)) - BIT((bits) - 1))

#define SIGN_EXTEND_ALT(val,bits,signbit) \
 ((((val) & BITMASK(0, (bits) - 1)) - BIT(bits)) + \
 (((val & BIT(signbit)) ^ BIT(signbit)) >> (signbit - bits)))

#define REDO_M7_A BIT(0)
#define REDO_M7_B BIT(1)
#define REDO_M7_C BIT(2)
#define REDO_M7_D BIT(3)
#define REDO_M7_X BIT(4)
#define REDO_M7_Y BIT(5)
#define REDO_M7_H BIT(6)
#define REDO_M7_V BIT(7)

void Recalc_Mode7(void)
{
 _M7_Handler = _M7_Handler_Table[M7SEL >> 6];

 if (Redo_M7 & (REDO_M7_A | REDO_M7_C))
 {
  /* setup helper vars for horizontal flip */
  M7A_X = !(M7SEL & 1) ? M7A : -M7A;
  M7C_X = !(M7SEL & 1) ? M7C : -M7C;

  if (bg_table_1.mosaic)
  {
   M7A_XM = M7A_X * Mosaic_Size;
   M7C_XM = M7C_X * Mosaic_Size;
  }
 }

 if (Redo_M7 & (REDO_M7_A | REDO_M7_C |
  REDO_M7_X | REDO_M7_Y | REDO_M7_H | REDO_M7_V))
 {
  if (Redo_M7 & (REDO_M7_Y | REDO_M7_V))
  {
   int V_13, VY;
   
   V_13 = SIGN_EXTEND(M7V, 13);
   M7Y_13 = SIGN_EXTEND(M7Y, 13);
   VY = V_13 - M7Y_13;

   /* there are only 11 significant result bits - a hidden sign bit (13) and
     the low 10 result bits */
   Mode7_VY = SIGN_EXTEND_ALT(VY, 10, 13);
  }

  if (Redo_M7 & (REDO_M7_A | REDO_M7_C |
   REDO_M7_X | REDO_M7_Y | REDO_M7_H))
  {
   int H_13, X_13, HX;
   
   H_13 = SIGN_EXTEND(M7H, 13);
   X_13 = SIGN_EXTEND(M7X, 13);
   HX = H_13 - X_13;

   /* there are only 11 significant result bits - a hidden sign bit (13) and
     the low 10 result bits */
   HX = SIGN_EXTEND_ALT(HX, 10, 13);

   if (Redo_M7 & (REDO_M7_A | REDO_M7_X | REDO_M7_H))
   {
    Mode7_AHX = ((HX * M7A) & ~BITMASK(0,5)) + (X_13 << 8);
   }

   if (Redo_M7 & (REDO_M7_C | REDO_M7_X | REDO_M7_Y | REDO_M7_H))
   {
    Mode7_CHXY = ((HX * M7C) & ~BITMASK(0,5)) + (M7Y_13 << 8);
   }
  }

 }

 Redo_M7 = 0;
}


static unsigned char mode7_buffer[MAX_LINES_IN_SET * 256];

void Render_Mode7_Background(
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, unsigned layers1, unsigned layers2,
 int extbg, BG_TABLE *bg_table,
 unsigned char depth_low, unsigned char depth_high,
 unsigned lines)
{
 unsigned current_line = 0;

 if ((bg_table->bg_flag == BIT(0)) && (CGWSEL & BIT(0)))
 /* BG1, direct color enabled */
 {
  depth_low |= Z_DIRECT_COLOR_USED;
  depth_high |= Z_DIRECT_COLOR_USED;
 }

 for (; lines > 0; current_line ++, lines--)
 {
  unsigned line_surface_offset;

  int first_window, num_windows;
  int window;

  const LAYER_WIN_DATA *bg_win;

  int runs_left;
  const unsigned char (*bands)[2]; /* RunListPtr */

  line_surface_offset = output_surface_offset;

  output_surface_offset += 256;

  num_windows = setup_windows_for_layer(&first_window);


  for (window = 0; window < num_windows; window++)
  {
   unsigned char (*screen1)[2], (*screen2)[2];
   unsigned char arithmetic_used;

   arithmetic_used = setup_screens_for_layer(&screen1, &screen2,
    window, main_buf, sub_buf);

   bg_win = &bg_table->bg_win[first_window + window];

   runs_left = bg_win->count;
   bands = bg_win->bands;

   for (; runs_left--; bands++)
   {
    unsigned next_pixel;
    int pixel_count;

    unsigned char color_mask = !extbg ? BITMASK(0,7) : BITMASK(0,6);
    unsigned char priority_mask = !extbg ? 0 : BIT(7);

    /* (right edge + 1) - left edge */
    next_pixel = bands[0][0];
    pixel_count = (bands[0][1] ? bands[0][1] : 256) - bands[0][0];

    if (!bg_table->mosaic)
    {
     for ( ; pixel_count; next_pixel++, pixel_count--)
     {
      unsigned char pixel;
      unsigned char depth;

      pixel = mode7_buffer[current_line * 256 + next_pixel];
      if (!(pixel & color_mask)) continue;

      depth = arithmetic_used |
       (!(pixel & priority_mask) ? depth_low : depth_high);

      pixel &= color_mask;

      if (screen1[line_surface_offset + next_pixel][1] <=
       (depth | Z_NON_DEPTH_BITS))
      {
       screen1[line_surface_offset + next_pixel][0] = pixel;
       screen1[line_surface_offset + next_pixel][1] = depth;
      }

      if (screen2)
      {
       if (screen2[line_surface_offset + next_pixel][1] <=
        (depth | Z_NON_DEPTH_BITS))
       {
        screen2[line_surface_offset + next_pixel][0] = pixel;
        screen2[line_surface_offset + next_pixel][1] = depth;
       }
      }

     }
    }
    else /* bg_table->mosaic */
    {
     int run_pixel_count = MosaicCount[Mosaic_Size - 1][next_pixel];
     unsigned next_input;

	 run_pixel_count = pixel_count <= run_pixel_count ?
      pixel_count : run_pixel_count;

     for (next_input = MosaicLine[Mosaic_Size - 1][next_pixel];
      pixel_count;
      next_input += Mosaic_Size,
      next_pixel += run_pixel_count,
      pixel_count -= run_pixel_count,
      run_pixel_count = pixel_count <= Mosaic_Size ? pixel_count : Mosaic_Size)
     {
      int temp_count = run_pixel_count;

      unsigned char pixel;
      unsigned char depth;

      unsigned tmp_next_pixel = next_pixel;


      pixel = mode7_buffer[current_line * 256 + next_input];
      if (!(pixel & color_mask)) continue;

      depth = arithmetic_used |
       (!(pixel & priority_mask) ? depth_low : depth_high);

      pixel &= color_mask;

      do
      {
       if (screen1[line_surface_offset + tmp_next_pixel][1] <=
        (depth | Z_NON_DEPTH_BITS))
       {
        screen1[line_surface_offset + tmp_next_pixel][0] = pixel;
        screen1[line_surface_offset + tmp_next_pixel][1] = depth;
       }

       if (screen2)
       {
        if (screen2[line_surface_offset + tmp_next_pixel][1] <=
         (depth | Z_NON_DEPTH_BITS))
        {
         screen2[line_surface_offset + tmp_next_pixel][0] = pixel;
         screen2[line_surface_offset + tmp_next_pixel][1] = depth;
        }
       }

      } while (tmp_next_pixel++, --temp_count);
     }

    }

   }

  }

 }

}

void Build_Mode7_Background(unsigned output_surface_offset, unsigned lines)
{
 _M7_Handler(output_surface_offset, lines, 0, 256);
}

static void Process_Mode7_Background(unsigned current_line, unsigned lines)
{
 unsigned output_surface_offset = 0;
 unsigned lines_in_set;

 unsigned countdown = MosaicCountdown;
 unsigned current_line_mosaic = bg_table_1.line_counter;
 int mosaic = bg_table_1.mosaic;


 for (; lines > 0; current_line += lines_in_set, countdown -= lines_in_set,
  current_line_mosaic = !countdown ? current_line : current_line_mosaic,
  lines -= lines_in_set, output_surface_offset += 256 * lines_in_set
 )
 {
  unsigned line = current_line;
  lines_in_set = 1;

  /* Handle vertical mosaic */
  if (mosaic)
  {
   if (!countdown) countdown = Mosaic_Size;
   lines_in_set = lines <= countdown ? lines : countdown;

   line = current_line_mosaic;
  }

  /* handle vertical flip */
  if (M7SEL & 2)
  {
   line = 255 - line;
  }

  Mode7_Line_X = Mode7_AHX +
   ((Mode7_VY * M7B) & ~BITMASK(0,5)) +
   ((line * M7B) & ~BITMASK(0,5));

  Mode7_Line_Y = Mode7_CHXY +
   ((Mode7_VY * M7D) & ~BITMASK(0,5)) +
   ((line * M7D) & ~BITMASK(0,5));

  /* handle horizontal flip */
  if (M7SEL & 1)
  {
   Mode7_Line_X += M7A * 255;
   Mode7_Line_Y += M7C * 255;
  }

  Build_Mode7_Background(output_surface_offset, lines_in_set);
 }
}

static void _Render_SM7(
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned current_line, unsigned lines, unsigned output_surface_offset,
 unsigned layers1, unsigned layers2)
{
 if (LAYER_PRESENT(layers1 | layers2, 2))
 {
  Render_Mode7_Background(main_buf, sub_buf, output_surface_offset,
   layers1, layers2, 1, &bg_table_2,
   Z_M27_BG2_LO,
   Z_M27_BG2_HI,
   lines);
 }

 if (LAYER_PRESENT(layers1 | layers2, 1))
 {
  Render_Mode7_Background(main_buf, sub_buf, output_surface_offset,
   layers1, layers2, 0, &bg_table_1,
   Z_M27_BG1_LO,
   Z_M27_BG1_LO,
   lines);
 }

 if (LAYER_PRESENT(layers1 | layers2, 5))  /* OBJ */
 {
  _Plot_Sprites(main_buf, sub_buf, output_surface_offset, layers1, layers2,
   current_line, lines);
 }
}

static void _SCREEN_MODE_7(
/*
 ebx,[Current_Line_Render]+1
 edi,[BaseDestPtr]
 ebp,lines
 al = screens 1, ah = screens 2
*/
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,

 unsigned current_line,
 unsigned lines,
 unsigned layers1, unsigned layers2
)
{
 clear_scanlines(lines);

 if ((layers1 | layers2) & 3)
 /* handle most of actual mode 7 background(s) here */
 {
  Recalc_Mode7();

  Process_Mode7_Background(current_line, lines);
 }

 _Render_SM7(main_buf, sub_buf, current_line, lines,
  output_surface_offset, layers1, layers2);
}


/*
Do_16x8_Multiply:
 push ebx
 movsx ebx,byte [M7B+1]
 mov byte [Redo_16x8],0
 imul ebx,[M7A]    ; I think signed is used makes most sense!
 mov [MPY],ebx
 mov al,[edx]
 pop ebx
 ret

ALIGNC
EXPORT SNES_R2134 ; MPYL
 mov edx,MPYL
 cmp byte [Redo_16x8],0
 jnz Do_16x8_Multiply
 mov al,[edx]
 mov [Last_Bus_Value_PPU1],al
 ret

ALIGNC
EXPORT SNES_R2135 ; MPYM
 mov edx,MPYM
 cmp byte [Redo_16x8],0
 jnz Do_16x8_Multiply
 mov al,[edx]
 mov [Last_Bus_Value_PPU1],al
 ret

ALIGNC
EXPORT SNES_R2136 ; MPYH
 mov edx,MPYH
 cmp byte [Redo_16x8],0
 jnz Do_16x8_Multiply
 mov al,[edx]
 mov [Last_Bus_Value_PPU1],al
 ret

ALIGNC
EXPORT SNES_W_M7H ; 210D - handle mode 7 register update
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7H],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [M7H],ebx
 mov dl,0x40    ; Recalculate H
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W_M7V ; 210E - handle mode 7 register update
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7V],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [M7V],ebx
 mov dl,0x80    ; Recalculate V
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211A ; M7SEL   ; New for 0.12
 cmp al,[M7SEL]
 je .no_change
 UpdateDisplay  ;*
 push ebx
 push eax
 mov [M7SEL],al

 shl al,8
 mov ebx,[M7A]
 mov eax,[M7C]
 sbb edx,edx
 xor ebx,edx
 xor eax,edx
 and edx,byte 1
 add ebx,edx
 add eax,edx
 mov dl,[M7SEL]
 mov [M7A_X],ebx

 shr edx,6
 mov [M7C_X],eax

 and edx,3
 mov eax,[M7_Handler_Table+edx*4]
 mov [M7_Handler],eax
 mov ebx,[M7_Handler_Table+edx*4+16]
 pop eax
 mov [M7_Handler_EXTBG],ebx
 pop ebx

.no_change:
 ret

ALIGNC
EXPORT SNES_W211B ; M7A
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7A],ebx
 je .no_change

 UpdateDisplay  ;*M7
 ; Used for matrix render and 16-bit M7A * 8-bit = 24-bit multiply
 mov [M7A],ebx
 mov dl,0x01    ; Recalculate A
 or [Redo_M7],dl
 mov byte [Redo_16x8],-1
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211C ; M7B
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7B],ebx
 je .no_change

 UpdateDisplay  ;*M7
 ; Used for matrix render and 16-bit * 8-bit M7B high byte = 24-bit multiply
 mov [M7B],ebx
 mov dl,0x02    ; Recalculate B
 or [Redo_M7],dl
 mov byte [Redo_16x8],-1
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211D ; M7C
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7C],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [M7C],ebx
 mov dl,0x04    ; Recalculate C
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211E ; M7D
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7D],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [M7D],ebx
 mov dl,0x08    ; Recalculate D
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W211F ; M7X
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7X],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [M7X],ebx
 mov dl,0x10    ; Recalculate X
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret

ALIGNC
EXPORT SNES_W2120 ; M7Y
 push ebx
 mov bl,[M7_Last_Write]
 mov bh,al
 mov [M7_Last_Write],al

 movsx ebx,bx
 cmp [M7Y],ebx
 je .no_change

 UpdateDisplay  ;*M7
 mov [M7Y],ebx
 mov dl,0x20    ; Recalculate Y
 or [Redo_M7],dl
.no_change:
 pop ebx
 ret
*/

#define M7_Generate_Handlers

#define M7_OVERFLOW_REPEAT
#define M7_OVERFLOW_MODE REPEAT
#include "mode7.h"
#undef M7_OVERFLOW_MODE
#undef M7_OVERFLOW_REPEAT

#define M7_OVERFLOW_MODE CHAR0
#include "mode7.h"
#undef M7_OVERFLOW_MODE

#define M7_OVERFLOW_CLIP
#define M7_OVERFLOW_MODE CLIP
#include "mode7.h"
#undef M7_OVERFLOW_MODE
#undef M7_OVERFLOW_CLIP

#undef M7_Generate_Handlers


void (*_M7_Handler_Table[4])(
 unsigned output_surface_offset, unsigned lines,
 int first_pixel, int pixel_count) =
{
 M7_REPEAT , M7_CLIP , M7_CLIP , M7_CHAR0
};

void _Reset_Mode_7(void)
{
 M7SEL = 0;
 M7_Last_Write = 0;
 _M7_Handler = M7_REPEAT;

 Redo_16x8 = 0;
 MPY = 0;

 M7A = 0;
 M7B = 0;
 M7C = 0;
 M7D = 0;
 M7X_13 = 0;
 M7Y_13 = 0;
 M7H_13 = 0;
 M7V_13 = 0;
 M7X = 0;
 M7Y = 0;
 M7H = 0;
 M7V = 0;

 Redo_M7 = (0 - 1);
}

#undef TEXTERN

#else   /* defined(M7_Generate_Handlers) */

#ifndef M7_Handler_Code

#define M7_Handler_Code
void CONCAT_NAME(M7_, M7_OVERFLOW_MODE)(
 unsigned output_surface_offset, unsigned lines,
 int first_pixel, int pixel_count
 )
{
 int X, Y;
 unsigned char *dest_ptr = mode7_buffer + output_surface_offset + first_pixel;

 X = Mode7_Line_X + (M7A_X * first_pixel);
 Y = Mode7_Line_Y + (M7C_X * first_pixel);

 if (!bg_table_1.mosaic)
 {
#include "mode7.h"
 }
 else
 {
#define M7_MOSAIC
#include "mode7.h"
#undef M7_MOSAIC
 }
}
#undef M7_Handler_Code

#else   /* defined(M7_Handler_Code) */

 for ( ; pixel_count;
  X += M7A_X, Y += M7C_X, pixel_count--,
  dest_ptr++)
 {
  int tile_x, tile_y;
  unsigned char tile, pixel;
  int cX = X;
  int cY = Y;

#if defined(M7_OVERFLOW_CLIP)
  if (cX & ~0x3FFFF || cY & ~0x3FFFF)
  {
   pixel = 0;
  }
  else
#elif defined(M7_OVERFLOW_REPEAT)
  cX &= 0x3FFFF;
  cY &= 0x3FFFF;
#endif  /* defined(M7_OVERFLOW_REPEAT) */
  {
   if (cX & ~0x3FFFF || cY & ~0x3FFFF) tile = 0;
   else tile = VRAM[((((cY >> 8) / 8) * 128) + ((cX >> 8) / 8)) * 2];

   tile_x = (X >> 8) & 7;
   tile_y = (Y >> 8) & 7;

   pixel = VRAM[((tile * 8 + tile_y) * 8 + tile_x) * 2 + 1];
  }
#ifndef M7_MOSAIC
  *dest_ptr = pixel;
#else   /* defined(M7_MOSAIC) */
  {
   int line_count = lines;
   unsigned char *line_dest_ptr = dest_ptr;

   do
   {
    *line_dest_ptr = pixel;
   } while (line_dest_ptr += 256, --line_count);
  }
#endif  /* defined(M7_MOSAIC) */
 }

#endif  /* defined(M7_Handler_Code) */

#endif  /* defined(M7_Generate_Handlers) */
