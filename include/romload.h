/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

#ifndef SNEeSe_romload_h
#define SNEeSe_romload_h

#include "misc.h"
#include "platform.h"

/*
 ROM Copier Header
*/
typedef struct {
 unsigned short NumPages;
 unsigned char ImageInformation;
 char Reserved_1[5];
 unsigned char SWC_Ident1;
 unsigned char SWC_Ident2;
 unsigned char SWC_Ident3;
 char RestOfHeader[501];
} ROM_Header;

typedef enum {
 ROMFileType_normal, ROMFileType_split,
 ROMFileType_gamedoctor, ROMFileType_compressed
} ROMFileType;

const int
 Undetected = -1, Off = 0, On = 1,
 LoROM = 0, HiROM = 1,
 Non_Interleaved = 0,Interleaved = 2,
 LoROM_Interleaved = 0 | 2, /* LoROM | Interleaved, */
 HiROM_Interleaved = 1 | 2, /* HiROM | Interleaved, */
 NTSC_video = 0, PAL_video = 1;

#define ROM_Header_Size (sizeof(ROM_Header))

/*
 ROM Info Block
*/
typedef struct {
 char ROM_Title[21];           /* FFC0 */
 unsigned char ROM_makeup;     /* FFD5 */
 unsigned char ROM_type;       /* FFD6 */
 unsigned char ROM_size;       /* FFD7 */
 unsigned char SRAM_size;      /* FFD8 */
 unsigned char Country_code;   /* FFD9 */
 unsigned char License;        /* FFDA */
 unsigned char ROM_version;    /* FFDB */
 unsigned short int Complement;/* FFDC */
 unsigned short int Checksum;  /* FFDE */
} SNESRomInfoStruct;

#ifndef TRUE
#define TRUE (-1)
#endif
#ifndef FALSE
#define FALSE (0)
#endif

extern char *rom_romfile;
extern char *rom_romhilo;
extern char *rom_romname;
extern char *rom_romtype;
extern char *rom_romsize;
extern char *rom_sram;
extern char *rom_country;

extern unsigned char *RomAddress;       /* Address of SNES ROM */

/* Used to determine size of file for saving/loading, and to restrict writes
 *  to non-existant SRAM
 */
extern unsigned SaveRamLength;

extern int rom_bank_count;
extern int rom_bank_count_mask, rom_bank_count_premask;
extern int ROM_format;

extern SNESRomInfoStruct RomInfoLo,RomInfoHi;

extern char *ROM_filename;
extern char fn_drive[MAXDRIVE], fn_dir[MAXDIR], fn_file[MAXFILE], fn_ext[MAXEXT];
extern char SRAM_filename[MAXPATH];
extern char save_dir[MAXPATH];
extern char save_extension[MAXEXT];

extern int ROM_has_header;
/* Off = LoROM, On = HiROM, Undetected = autodetect */
extern int ROM_memory_map;
extern int ROM_interleaved;
extern int ROM_video_standard;

extern char *TypeTable[];
extern char *CountryTable[];

#if (defined(__cplusplus)||defined(c_plusplus))

extern int Allocate_Rom(void);

int SaveSRAM(char *SRAM_filename);
int LoadSRAM(char *SRAM_filename);
bool CreateSRAMFilename(char *ROM_filename);

int Allocate_ROM(void);

int open_rom(const char *FileName);
void DisplayRomStats(SNESRomInfoStruct *RomInfo);

#endif /* defined(__cplusplus)||defined(c_plusplus) */

#endif /* !defined(SNEeSe_romload_h) */
