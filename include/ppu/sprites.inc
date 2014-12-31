%if 0

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

%endif

%ifndef SNEeSe_ppu_sprites_inc
%define SNEeSe_ppu_sprites_inc

%ifndef SNEeSe_ppu_sprites_asm

EXTERN sprites_text_start,sprites_data_start,sprites_bss_start
EXTERN OAM_Count_Priority
EXTERN OAM
EXTERN SpriteCount,Sprite_Mode
EXTERN HiSprite
EXTERN SPRLatch
EXTERN OBSEL
EXTERN OAMHigh
EXTERN HiSpriteCnt1,HiSpriteCnt2
EXTERN OBBASE,OBNAME
EXTERN OAMAddress,OAMAddress_VBL
EXTERN HiSpriteAddr,HiSpriteBits
;EXTERN NextSprite,Priority_Used
EXTERN Rendered_Sprites,SpriteList
EXTERN Redo_OAM
EXTERN Clear_Sprites

EXTERN Plot_Sprites
EXTERN Check_OAM_Recache
EXTERN Recache_OAM
EXTERN Reset_Sprites_asm
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
