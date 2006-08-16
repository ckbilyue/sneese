/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2006, Charles Bilyue'.
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

#include "misc.h"
#include "snes.h"
#include <stdlib.h>

extern unsigned char BGMODE_Allowed_Layer_Mask;

unsigned char WH0, WH1, WH2, WH3;   /* Holds window edge positions */
unsigned char TM, TS;   /* 000odcba  o=OBJ enable,a-d=BG1-4 enable */
unsigned char TMW, TSW; /* as above, but for window mask enable */
unsigned char W12SEL;   /* Holds plane 1/2 window mask settings */
unsigned char W34SEL;   /* Holds plane 3/4 window mask settings */
unsigned char WOBJSEL;  /* Holds colour/object window mask settings */
unsigned char WBGLOG;   /* BG Window mask logic */
unsigned char WOBJLOG;  /* OBJ/Colour Window mask logic */
unsigned char CGWSEL;   /* more color window settings */
unsigned char CGADSUB;  /* color arithmetic settings */

/* Layering vars */
unsigned char Layering_Mode;

/* This is used to force planes to disable! */
unsigned char Layer_Disable_Mask;

/* TM, TS, TMW, TSW taken from here */
unsigned char Used_TM;
unsigned char Used_TS;
unsigned char Used_TMW;
unsigned char Used_TSW;

/* Used_TM | Used_TS */
unsigned char Layers_In_Use;

LAYER_WIN_DATA win_obj[COUNT_BG_WIN], win_color[COUNT_COL_WIN];

WIN_DATA TableWin1, TableWin2;

unsigned TileClip1Left, TileClip1Right;
unsigned TileClip2Left, TileClip2Right;

unsigned char Redo_Layering;

/*
 YXCS 4321
 1-4 update clip window for BG 1-4
 S   update clip window for OBJ (sprites)
 C   update color window
 X   update window 1 area
 Y   update window 2 area */
unsigned char Redo_Windowing;

/* right = right edge + 1, or exclusive right edge */
void Recalc_Single_Window(WIN_DATA *win,
 unsigned char left, unsigned char right)
{
 /* if ((inclusive) right edge < left edge) full range outside window */
 if (!(!right || left < right))
 /* full range outside window (0 inside, 1 outside) */
 {
  /* One band outside window */
  win->Count_Out = 1;
  /* Full range band */
  win->Bands_Out[0][0] = win->Bands_Out[0][1] = 0;

  /* No bands inside window */
  win->Count_In = 0;

  return;
 }

 /* One band inside window (left,right) */
 win->Count_In = 1;

 win->Bands_In[0][0] = left;
 win->Bands_In[0][1] = right;

 if (!left)
 /* window flush left, at most 1 band outside */
 {
  if (!right)
  /* full range inside window, no bands outside */
  {
   win->Count_Out = 0;
   return;
  }

  /* window flush left, 1 outside band flush right */
  /* outside range is (right+1,left-1) */
  win->Count_Out = 1;
  win->Bands_Out[0][0] = right;
  win->Bands_Out[0][1] = left;
  return;
 }

 if (!right)
 /* window flush right, not flush left, 1 band outside */
 {
  /* window flush right, 1 outside band flush left */
  /* outside range is (right+1,left-1) */
  win->Count_Out = 1;
  win->Bands_Out[0][0] = right;
  win->Bands_Out[0][1] = left;
  return;
 }

 /* Window not flush left or right (1 inside, 2 outside) */
 win->Count_Out = 2;

 /* Outside range 1 is (0,left-1) */
 win->Bands_Out[0][0] = 0;
 win->Bands_Out[0][1] = left;

 /* Outside range 2 is (right+1,255) */
 win->Bands_Out[1][0] = right;
 win->Bands_Out[1][1] = 0;
}


int qsort_short(const void *i1, const void *i2)
{
 return *(short *)i1 - *(short *)i2;
}

int intersect_bands_with_xor(int count1, const unsigned char (*edges1)[2],
 int count2, const unsigned char (*edges2)[2], unsigned char (*merged_edges)[2])
{
 int i;
 int points = 0, out_count = 0;
 short point_set[12];

 for (i = 0; i < count1; i++, points += 2)
 {
  point_set[points] = edges1[i][0];
  point_set[points + 1] = edges1[i][1] ? edges1[i][1] : 256;
 }

 for (i = 0; i < count2; i++, points += 2)
 {
  point_set[points] = edges2[i][0];
  point_set[points + 1] = edges2[i][1] ? edges2[i][1] : 256;
 }

 
 /* sort points */
 qsort(point_set, points, sizeof(short), qsort_short);

 /* remove duplicates and output bands */
 for (i = 0; i < points - 1; i += 2)
 {
  /* skip duplicates */
  if (point_set[i] == point_set[i + 1]) continue;

  merged_edges[out_count][0] = point_set[i];

  /* check for duplicates while they may still exist */
  while (i + 2 < points)
  {
   /* skip duplicates */
   if (point_set[i + 1] != point_set[i + 2]) break;
   i += 2;
  }
  merged_edges[out_count][1] = point_set[i + 1];
  out_count++;
 }

 return out_count;
}


int intersect_bands_with_and(int count1, const unsigned char (*edges1)[2],
 int count2, const unsigned char (*edges2)[2], unsigned char (*merged_edges)[2])
{
 int work_count2, merged_count;
 const unsigned char (*work_edges2)[2];

 merged_count = 0;

 for (; count1; edges1++, count1--)
 {

  for (work_count2 = count2, work_edges2 = edges2;
   work_count2;
   work_edges2++, work_count2--)
  {
   /* win1left > win2right? */
   if (edges1[0][0] > ((work_edges2[0][1] - 1) & 0xFF))
   /* no intersect of this band 2 */
   {
    edges2++; count2--;
    continue;
   }

   /* win2left > win1right? */
   if (work_edges2[0][0] > ((edges1[0][1] - 1) & 0xFF))
   /* no more intersect of this band 1 */
   {
    break;
   }

   /* take innermost edges of intersecting regions */
   merged_edges[merged_count][0] =
    edges1[0][0] >= work_edges2[0][0] ?
    edges1[0][0] : work_edges2[0][0];

   merged_edges[merged_count++][1] =
    ((edges1[0][1] - 1) & 0xFF) <= ((work_edges2[0][1] - 1) & 0xFF) ?
    edges1[0][1] : work_edges2[0][1];

  }
 }

 /* no more bands */
 return merged_count;
}


int intersect_bands_with_or(int count1, const unsigned char (*edges1)[2],
 int count2, const unsigned char (*edges2)[2], unsigned char (*merged_edges)[2])
{
 int merged_count;

 merged_count = 0;

 for (; count1; edges1++, count1--)
 {
  unsigned char accumulated[2];

  /* no bands left in other window? */
  if (count2 <= 0)
  {
   /* copy remaining bands to result */
   count2 = count1;
   edges2 = edges1;
   break;
  }

  /* start with leftmost window bands */
  if (edges1[0][0] > edges2[0][0])
  {
   int temp_count;
   const unsigned char (*temp_edges)[2];

   temp_count = count1; temp_edges = edges1;
   count1 = count2;     edges1 = edges2;
   count2 = temp_count; edges2 = temp_edges;
  }

  accumulated[0] = edges1[0][0];
  accumulated[1] = edges1[0][1];

  for (; ; edges2++, count2--)
  {
   if (count2 > 0)
   /* more bands in window 2, attempt to merge */
   {
    /*  guaranteed match, no need to merge if right edge of band on right */
    /* edge of display */
    if (!accumulated[1]) continue;
    /* left edge of new band within accumulated band? */
    if (edges2[0][0] <= accumulated[1]) 
    {
     /* extend right edge to absorb new band, if applicable */
     if (((edges2[0][1] - 1) & 0xFF) > ((accumulated[1] - 1) & 0xFF))
      accumulated[1] = edges2[0][1];
     /* check next band */
     continue;
    }
   }

   if (count1 - 1)
   {
    /*  guaranteed match, no need to merge if right edge of band on right */
    /* edge of display */
    if (!accumulated[1])
    {
     /* fix pointers, counters */
     edges1++; count1--;
     edges2--; count2++;
     /* check next band */
     continue;
    }
    /* left edge of new band within accumulated band? */
    if (edges1[1][0] <= accumulated[1]) 
    {
     /* extend right edge to absorb new band, if applicable */
     if (((edges1[1][1] - 1) & 0xFF) > ((accumulated[1] - 1) & 0xFF))
      accumulated[1] = edges1[1][1];
     /* fix pointers, counters */
     edges1++; count1--;
     edges2--; count2++;
     /* check next band */
     continue;
    }
   }
   break;
  }

  merged_edges[merged_count][0] = accumulated[0];
  merged_edges[merged_count++][1] = accumulated[1];
 }

 /*  one window has no bands left, copy remaining bands to result */
 while (count2-- > 0)
 {
  merged_edges[merged_count][0] = edges2[0][0];
  merged_edges[merged_count][1] = edges2[0][1];
  merged_count++; edges2++;
 }

 return merged_count;
}


enum
{
 WINDOW_ALWAYS_ON  = 0,
 WINDOW_ON_INSIDE  = 1,
 WINDOW_ON_OUTSIDE = 2,
 WINDOW_ALWAYS_OFF = 3
};

void Full_Range_Window(LAYER_WIN_DATA *out)
{
 out->count = 1;
 out->bands[0][0] = out->bands[0][1] = 0;
}

void Empty_Window(LAYER_WIN_DATA *out)
{
 out->count = 0;
}

void Copy_Window(LAYER_WIN_DATA *out, const LAYER_WIN_DATA *in)
{
 int i;

 for (i = 0; i < in->count; i++)
 {
  out->bands[i][0] = in->bands[i][0];
  out->bands[i][1] = in->bands[i][1];
 }
 out->count = in->count;
}

void Invert_Window_Bands(LAYER_WIN_DATA *out, const LAYER_WIN_DATA *in)
{
/* max output bands is 1 more than max input bands; only in case where
 neither outermost band edges are at screen edge */
 unsigned char left, right;
 int i, count = 0;

 if (!in->count)
 {
  /* full range */
  Full_Range_Window(out);

  return;
 }

 right = in->bands[0][0];
 if (right != 0)
 {
  out->bands[count][0] = 0;
  out->bands[count][1] = right;
  count++;
 }

 for (i = 0; i < in->count - 1; i++)
 {
  left = in->bands[i][1];
  right = in->bands[i + 1][0];

  out->bands[count][0] = left;
  out->bands[count][1] = right;
  count++;
 }

 left = in->bands[i][1];
 if (left != 0)
 {
  out->bands[count][0] = left;
  out->bands[count][1] = 0;
  count++;
 }

 out->count = count;

 return;
}

/* { mask_enable, WSEL, WLOG } = appropriate bits for layer */
/*  masked/shifted from { TMW or TSW; W*SEL; and W*LOG } */
void Recalc_Window_Area_Layer(LAYER_WIN_DATA *bgwin, int extra,
 unsigned char layer_enable, unsigned char mask_enable,
 unsigned char WSEL, unsigned char WLOG)
{
 int outside1, outside2;

 if (layer_enable &&
  /* (colorwin only) window not always off */
  extra != WINDOW_ALWAYS_OFF &&
  /* (not colorwin) window mask enabled */
  (!mask_enable ||
  /* (colorwin only) window always on */
  extra == WINDOW_ALWAYS_ON ||
  /* both windows off and (colorwin only) window not on inside */
  (!(WSEL & (BIT(1) + BIT(3))) && (extra != WINDOW_ON_INSIDE))))
 {
  /* no clipping, full range visible */
  Full_Range_Window(bgwin);
  return;
 }

 if (!layer_enable ||
  /* (colorwin only) window always off */
  extra == WINDOW_ALWAYS_OFF ||
  /* (colorwin only) both windows off and window on inside */
  (!(WSEL & (BIT(1) + BIT(3))) && (extra == WINDOW_ON_INSIDE)))
 {
  /* no range visible */
  Empty_Window(bgwin);
  return;
 }

 if ((WSEL & (BIT(1) + BIT(3))) != (BIT(1) + BIT(3)))
 {
  /* only 1 window enabled, invert for visible area */
  WIN_DATA *win;
  unsigned char (*edges)[2];
  int count;
  int i;

  win = WSEL & BIT(1) ? &TableWin1 : &TableWin2;
  if (!(WSEL & BIT(1))) WSEL >>= 2;

  /* for color window, area active inside window */
  if (extra == WINDOW_ON_INSIDE) WSEL ^= BIT(0);

  if (!(WSEL & BIT(0)))
  /* no invert, visible area outside window */
  {
   count = win->Count_Out;
   edges = win->Bands_Out;
  }
  else
  /* invert, visible area inside window */
  {
   count = win->Count_In;
   edges = win->Bands_In;
  }

  bgwin->count = count;
  for (i = 0; i < count; i++)
  {
   bgwin->bands[i][0] = edges[i][0];
   bgwin->bands[i][1] = edges[i][1];
  }

  return;
 }

 /* intersect */
 
 /*
  Method of generation depends on logic mode.
   OR logic uses AND on the bands outside the window area to compute
  the areas to be drawn.  No seperate bands can end up adjacent to each
  other, so coalesence is unnecessary.
   AND logic uses OR on the bands outside the window area to compute
  the areas to be drawn, logic code handles coalescence of adjacent
  bands.
   XOR and XNOR logic use a sorted set of window edges, with duplicate
  edges discarded.
  */

 /*
  logic - 00 = or; 01 = and; 10 = xor; 11 = xnor
  we want drawn areas, not window areas, so we need the inverted results...
   or   = and of outside
   and  = or of outside
   xor  = xor of inside 1, outside 2
   xnor = xor of outside both
  */

 outside1 = WSEL & BIT(0);
 outside2 = WSEL & BIT(2);

 if (extra == WINDOW_ON_INSIDE)
 /* color window, area active inside window */
 {
  outside1 = !outside1;
  outside2 = !outside2;
  WLOG ^= 1;
 }

 switch (WLOG)
 {
 case 0:    /* OR */
  bgwin->count = intersect_bands_with_and(
   outside1 ? Win_Count_In(1) : Win_Count_Out(1),
   (const unsigned char (*)[2]) (outside1 ? &Win_Bands_In(1)[0] : &Win_Bands_Out(1)[0]),
   outside2 ? Win_Count_In(2) : Win_Count_Out(2),
   (const unsigned char (*)[2]) (outside2 ? &Win_Bands_In(2)[0] : &Win_Bands_Out(2)[0]),
   &bgwin->bands[0]);
  break;
 case 1:    /* AND */
  bgwin->count = intersect_bands_with_or(
   outside1 ? Win_Count_In(1) : Win_Count_Out(1),
   (const unsigned char (*)[2]) (outside1 ? &Win_Bands_In(1)[0] : &Win_Bands_Out(1)[0]),
   outside2 ? Win_Count_In(2) : Win_Count_Out(2),
   (const unsigned char (*)[2]) (outside2 ? &Win_Bands_In(2)[0] : &Win_Bands_Out(2)[0]),
   &bgwin->bands[0]);
  break;
 case 2:    /* XOR */
  outside1 = !outside1;
 case 3:    /* XNOR */
  bgwin->count = intersect_bands_with_xor(
   outside1 ? Win_Count_In(1) : Win_Count_Out(1),
   (const unsigned char (*)[2]) (outside1 ? &Win_Bands_In(1)[0] : &Win_Bands_Out(1)[0]),
   outside2 ? Win_Count_In(2) : Win_Count_Out(2),
   (const unsigned char (*)[2]) (outside2 ? &Win_Bands_In(2)[0] : &Win_Bands_Out(2)[0]),
   &bgwin->bands[0]);
  break;
 }
}


void merge_layer_win_with_and(LAYER_WIN_DATA *out,
 const LAYER_WIN_DATA *bgwin1, const LAYER_WIN_DATA *bgwin2, int invert2)
{
 LAYER_WIN_DATA temp_bgwin2;
 const LAYER_WIN_DATA *fixed_bgwin2;

 if (!invert2)
 {
  fixed_bgwin2 = bgwin2;
 }
 else
 {
  Invert_Window_Bands(&temp_bgwin2, bgwin2);

  fixed_bgwin2 = &temp_bgwin2;
 }

 out->count = intersect_bands_with_and(
  bgwin1->count, &bgwin1->bands[0],
  fixed_bgwin2->count, &fixed_bgwin2->bands[0],
  &out->bands[0]);
}


#include <stdio.h>
void print_win(char *win_str, LAYER_WIN_DATA *l_win)
{
 sprintf(win_str, " %d (%3d-%3d %3d-%3d %3d-%3d)",
  l_win->count,
  l_win->bands[0][0], l_win->bands[0][1],
  l_win->bands[1][0], l_win->bands[1][1],
  l_win->bands[2][0], l_win->bands[2][1]);
}


/* layering mode 1 uses OFFSET_BG_WIN_MAIN with TM */
/* layering mode 2 uses OFFSET_BG_WIN_SUB with TS, back color = fixed color */
void Recalc_Window_Areas_Layer(LAYER_WIN_DATA (*layer_win)[COUNT_BG_WIN],
 int recalc_main, unsigned char layer_bit, unsigned char WSEL, unsigned char WLOG)
{
 LAYER_WIN_DATA temp;

 if (recalc_main)
 {
  Recalc_Window_Area_Layer(&layer_win[0][OFFSET_BG_WIN_MAIN],
   WINDOW_ON_OUTSIDE, layer_bit & Used_TM, layer_bit & Used_TMW, WSEL, WLOG);
 }

 Recalc_Window_Area_Layer(&temp,
  WINDOW_ON_OUTSIDE, layer_bit & Used_TS, layer_bit & Used_TSW, WSEL, WLOG);

 /* sub screen arithmetic area */
 merge_layer_win_with_and(&layer_win[0][OFFSET_BG_WIN_SUB],
  &temp,
  &win_color[OFFSET_COL_WIN_SUB], 0);

 if (!Layering_Mode)
 {
  /* main screen, arithmetic */
  if (CGADSUB & layer_bit)
  {
   merge_layer_win_with_and(&temp,
    &layer_win[0][OFFSET_BG_WIN_MAIN],
    &win_color[OFFSET_COL_WIN_SUB], 0);
  }
  else
  {
   Empty_Window(&temp);
  }

  /* main only, arithmetic */
  merge_layer_win_with_and(&layer_win[0][OFFSET_BG_WIN_EX_MAIN],
   &temp,
   &layer_win[0][OFFSET_BG_WIN_SUB], 1);

  /* main+sub, arithmetic */
  merge_layer_win_with_and(&layer_win[0][OFFSET_BG_WIN_BOTH],
   &temp,
   &layer_win[0][OFFSET_BG_WIN_SUB], 0);

  /* main screen, no arithmetic */
  if (CGADSUB & layer_bit)
  {
   merge_layer_win_with_and(&temp,
    &layer_win[0][OFFSET_BG_WIN_MAIN],
    &win_color[OFFSET_COL_WIN_SUB], 1);
  }
  else
  {
   Copy_Window(&temp, &layer_win[0][OFFSET_BG_WIN_MAIN]);
  }


  /* main only, no arithmetic */
  merge_layer_win_with_and(&layer_win[0][OFFSET_BG_WIN_MAIN_NO_COL],
   &temp,
   &layer_win[0][OFFSET_BG_WIN_SUB], 1);

  /* main+sub, arithmetic */
  merge_layer_win_with_and(&layer_win[0][OFFSET_BG_WIN_BOTH_NO_COL],
   &temp,
   &layer_win[0][OFFSET_BG_WIN_SUB], 0);

  /* sub only */
  merge_layer_win_with_and(&layer_win[0][OFFSET_BG_WIN_EX_SUB],
   &layer_win[0][OFFSET_BG_WIN_SUB],
   &layer_win[0][OFFSET_BG_WIN_MAIN], 1);
 }

#if 0
  if (layer_bit & BIT(1))
  {
   extern unsigned Current_Line_Render;
   char l_win[7][40];
   print_win(l_win[0], &layer_win[0][0]);
   print_win(l_win[1], &layer_win[0][1]);
   print_win(l_win[2], &layer_win[0][2]);
   print_win(l_win[3], &layer_win[0][3]);
   print_win(l_win[4], &layer_win[0][4]);
   print_win(l_win[5], &layer_win[0][5]);
   print_win(l_win[6], &layer_win[0][6]);
   printf("BG2 L%3u - W%d -%s\n"
          "BG2 L%3u - W%d -%s\n"
          "BG2 L%3u - W%d -%s\n"
          "BG2 L%3u - W%d -%s\n"
          "BG2 L%3u - W%d -%s\n"
          "BG2 L%3u - W%d -%s\n"
          "BG2 L%3u - W%d -%s\n",
    Current_Line_Render, 0, l_win[0],
    Current_Line_Render, 1, l_win[1],
    Current_Line_Render, 2, l_win[2],
    Current_Line_Render, 3, l_win[3],
    Current_Line_Render, 4, l_win[4],
    Current_Line_Render, 5, l_win[5],
    Current_Line_Render, 6, l_win[6]);
  }
#endif
}


void Recalc_Window_Effects(void)
{
 if (Redo_Windowing & Redo_Win(1))
 {
  Recalc_Single_Window(&TableWin1, WH0, WH1);
 }

 if (Redo_Windowing & Redo_Win(2))
 {
  Recalc_Single_Window(&TableWin2, WH2, WH3);
 }

 if (Redo_Windowing & Redo_Win_Color)
 {
  Redo_Windowing &= ~Redo_Win_Color;

  /* main screen color on */
  Recalc_Window_Area_Layer(&win_color[OFFSET_COL_WIN_MAIN],
   CGWSEL >> 6, 1,
   1,
   WOBJSEL >> 4, WOBJLOG >> 2);

  /* color arithmetic on */
  if (CGADSUB & (Used_TM | BIT(5)))
  {
   Recalc_Window_Area_Layer(&win_color[OFFSET_COL_WIN_SUB],
    (CGWSEL >> 4) & 3, 1,
    1,
    WOBJSEL >> 4, WOBJLOG >> 2);
  }
  else
  {
   Empty_Window(&win_color[OFFSET_COL_WIN_SUB]);
  }

  Invert_Window_Bands(&win_color[OFFSET_COL_WIN_NO_MAIN],
   &win_color[OFFSET_COL_WIN_MAIN]);
  Invert_Window_Bands(&win_color[OFFSET_COL_WIN_NO_SUB],
   &win_color[OFFSET_COL_WIN_SUB]);

  /* main screen color off, no arithmetic */
  merge_layer_win_with_and(&win_color[OFFSET_COL_WIN_MAIN_OFF_NO_COL],
   &win_color[OFFSET_COL_WIN_NO_MAIN],
   &win_color[OFFSET_COL_WIN_NO_SUB], 0);

  /* main screen color on, no arithmetic */
  merge_layer_win_with_and(&win_color[OFFSET_COL_WIN_MAIN_ON_NO_COL],
   &win_color[OFFSET_COL_WIN_MAIN],
   &win_color[OFFSET_COL_WIN_NO_SUB], 0);

  /* main screen color off, arithmetic */
  merge_layer_win_with_and(&win_color[OFFSET_COL_WIN_MAIN_OFF],
   &win_color[OFFSET_COL_WIN_NO_MAIN],
   &win_color[OFFSET_COL_WIN_SUB], 0);

  /* main screen color on, arithmetic */
  merge_layer_win_with_and(&win_color[OFFSET_COL_WIN_MAIN_ON],
   &win_color[OFFSET_COL_WIN_MAIN],
   &win_color[OFFSET_COL_WIN_SUB], 0);

#if 0
  {
   extern unsigned Current_Line_Render;
   char col_win[8][40];
   print_win(col_win[0], &win_color[0]);
   print_win(col_win[1], &win_color[1]);
   print_win(col_win[2], &win_color[2]);
   print_win(col_win[3], &win_color[3]);
   print_win(col_win[4], &win_color[4]);
   print_win(col_win[5], &win_color[5]);
   print_win(col_win[6], &win_color[6]);
   print_win(col_win[7], &win_color[7]);
   printf("COL L%3u - W%d -%s\n"
          "COL L%3u - W%d -%s\n"
          "COL L%3u - W%d -%s\n"
          "COL L%3u - W%d -%s\n"
          "COL L%3u - W%d -%s\n"
          "COL L%3u - W%d -%s\n"
          "COL L%3u - W%d -%s\n"
          "COL L%3u - W%d -%s\n",
    Current_Line_Render, 0, col_win[0],
    Current_Line_Render, 1, col_win[1],
    Current_Line_Render, 2, col_win[2],
    Current_Line_Render, 3, col_win[3],
    Current_Line_Render, 4, col_win[4],
    Current_Line_Render, 5, col_win[5],
    Current_Line_Render, 6, col_win[6],
    Current_Line_Render, 7, col_win[7]);
  }
#endif
 }

 /*
  1) generate window ranges present on main screen (MAIN), and ranges
  present on sub screen modified by sub screen color window (SUB)
  2) eliminate drawing to sub screen if screen arithmetic not to be used
  (sub_temp);
  3) separate areas into 3 sets: area to be drawn to both screens
  (MAIN & temp_sub); area to be drawn to main screen only (MAIN & ~temp_sub);
  and area to be drawn to sub screen only (sub_temp & ~MAIN)
 */
 if ((Layers_In_Use & Redo_Win_Layer(1)) &&
  ((Redo_Windowing & Redo_Win_Layer(1)) ||
  (Redo_Windowing & Redo_Win_Color)))
 {
  Recalc_Window_Areas_Layer(&bg_table_1.bg_win,
   Redo_Windowing & Redo_Win_Layer(1),
   /* bg_table_1.bg_flag*/ BIT(0), bg_table_1.WSEL, bg_table_1.WLOG);
 }

 if ((Layers_In_Use & Redo_Win_Layer(2)) &&
  ((Redo_Windowing & Redo_Win_Layer(2)) ||
  (Redo_Windowing & Redo_Win_Color)))
 {
  Recalc_Window_Areas_Layer(&bg_table_2.bg_win,
   Redo_Windowing & Redo_Win_Layer(2),
   /* bg_table_2.bg_flag*/ BIT(1), bg_table_2.WSEL, bg_table_2.WLOG);
 }

 if ((Layers_In_Use & Redo_Win_Layer(3)) &&
  ((Redo_Windowing & Redo_Win_Layer(3)) ||
  (Redo_Windowing & Redo_Win_Color)))
 {
  Recalc_Window_Areas_Layer(&bg_table_3.bg_win,
   Redo_Windowing & Redo_Win_Layer(3),
   /* bg_table_3.bg_flag*/ BIT(2), bg_table_3.WSEL, bg_table_3.WLOG);
 }

 if ((Layers_In_Use & Redo_Win_Layer(4)) &&
  ((Redo_Windowing & Redo_Win_Layer(4)) ||
  (Redo_Windowing & Redo_Win_Color)))
 {
  Recalc_Window_Areas_Layer(&bg_table_4.bg_win,
   Redo_Windowing & Redo_Win_Layer(4),
   /* bg_table_4.bg_flag*/ BIT(3), bg_table_4.WSEL, bg_table_4.WLOG);
 }

 if ((Layers_In_Use & Redo_Win_OBJ) &&
  ((Redo_Windowing & Redo_Win_OBJ) ||
  (Redo_Windowing & Redo_Win_Color)))
 {
  Recalc_Window_Areas_Layer(&win_obj,
   Redo_Windowing & Redo_Win_OBJ,
   BIT(4), WOBJSEL, WOBJLOG);
 }

 Redo_Windowing &= ~(Redo_Win(1) | Redo_Win(2) | Layers_In_Use);
}


void Update_Layering(void)
{
 /*
  TODO: Reimplement multiple layering modes, as follows:
   1) normal output;
   2) main screen only (no arithmetic, as ((CGWSEL & 0x30) == 0x30));
   3) sub screen only (no arithmetic, as if sub screen were main screen)
  */
 Redo_Layering = 0;

 Redo_Windowing |=
  Redo_Win_BG(1) | Redo_Win_BG(2) | Redo_Win_BG(3) | Redo_Win_BG(4) |
  Redo_Win_OBJ | Redo_Win_Color;

 switch (Layering_Mode)
 {
 case 1:
 /* main screen only (no arithmetic, as ((CGWSEL & 0x30) == 0x30)) */
  Used_TM = TM & BGMODE_Allowed_Layer_Mask & Layer_Disable_Mask;
  Used_TMW = TMW & Used_TM;

  Used_TS = Used_TSW = 0;
  break;

 case 2:
 /* sub screen only (no arithmetic, as if sub screen were main screen) */
  Used_TS = TS & BGMODE_Allowed_Layer_Mask & Layer_Disable_Mask;
  Used_TSW = TSW & Used_TS;

  Used_TM = Used_TMW = 0;
  break;

 case 0:
 default:
 /* normal output */
  Used_TM = TM & BGMODE_Allowed_Layer_Mask & Layer_Disable_Mask;
  Used_TMW = TMW & Used_TM;

  if (
   /* color arithmetic not disabled globally */
   ((CGWSEL & 0x30) != 0x30) &&
   /* screen arithmetic enabled */
   (CGWSEL & 2) &&
   /* arithmetic enabled for at least one layer on main screen */
   (CGADSUB & (Used_TM | BIT(5))))
  {
   Used_TS = TS & BGMODE_Allowed_Layer_Mask & Layer_Disable_Mask;
   Used_TSW = TSW & Used_TS;
  }
  else
  {
   Used_TS = 0;
  }
 }

 Layers_In_Use = Used_TM | Used_TS;
}
