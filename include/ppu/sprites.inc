%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

%ifndef SNEeSe_ppu_sprites_inc
%define SNEeSe_ppu_sprites_inc

%ifndef SNEeSe_ppu_sprites_asm

EXTERN_C sprites_text_start,sprites_data_start,sprites_bss_start
EXTERN_C OAM_Count_Priority
EXTERN_C OAM
EXTERN SpriteCount,Sprite_Mode
EXTERN_C HiSprite
EXTERN SPRLatch
EXTERN_C OBSEL
EXTERN OAMHigh
EXTERN_C HiSpriteCnt1,HiSpriteCnt2
EXTERN_C OBBASE,OBNAME
EXTERN_C OAMAddress,OAMAddress_VBL
EXTERN_C HiSpriteAddr,HiSpriteBits
;EXTERN NextSprite,Priority_Used
EXTERN Rendered_Sprites,SpriteList
EXTERN Redo_OAM
EXTERN Clear_Sprites

EXTERN Plot_Sprites
EXTERN_C Check_OAM_Recache
EXTERN_C Recache_OAM
EXTERN_C Reset_Sprites
EXTERN SNES_R2138,SNES_W2101,SNES_W2102,SNES_W2103,SNES_W2104
%endif

%macro ALL_SPRITES_PLANE 1
%if 0
 mov eax,[Current_Line_Render]
;mov al,[Priority_Used+eax*4-4+(%1)]
 test al,al
 jz %%no_sprites
 mov cl,((%1) << 4) + 12
 call Plot_Sprites
%%no_sprites:
%endif
%endmacro

%endif ; !defined(SNEeSe_ppu_sprites_inc)
