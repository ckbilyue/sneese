/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

/*  ROM IMAGE LOADING MECHANISM
    Original code by Savoury SnaX & Santeri Saarimaa
    New development by Charles Bilyue'

    Supports (with or without header):
     Single-part non-interleaved ROMs (LoROM and HiROM)
     Single-part interleaved HiROMs
     Multi-part non-interleaved ROMs (LoROM and HiROM, *.1-style)
     Multi-part interleaved HiROMs (*.1-style)

    If a header exists, it is ignored

       Single-part ROM extensions
        SFC = Super FamiCom
        FIG = Pro Fighter
        SMC = Super MagiCom
        SWC = Super WildCard

        BIN = Binary

       Multi-part ROM extensions
        SF*a.058,SF*a.078 = Game Doctor
        *.1 = Other miscellaneous multi-part ROM

    TO DO:
        Interleaved LoROM loading (??? need info)
        Other memory maps
*/

#include "wrapaleg.h"

#include <iostream.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "romload.h"
#include "helper.h"
#include "cpu/cpu.h"
#include "apu/spc.h"
#include "cpu/mem.h"
#include "snes.h"
#include "platform.h"
#include "multiio.h"


char *rom_romfile = 0;
char *rom_romhilo = 0;
char *rom_romtype = 0;
char *rom_romsize = 0;
char *rom_romname = 0;
char *rom_sram = 0;
char *rom_country = 0;
char rom_name[22];

extern "C" unsigned char BlockSpeed[256*8];

unsigned char BlockSpeed[256*8];

unsigned char *RomAddress;      // Address of SNES ROM

// Used to determine size of file for saving/loading, and to restrict writes
//  to non-existant SRAM
unsigned SaveRamLength = 0;

int Allocate_ROM();
int ROM_format;

typedef struct {
 int bank_count;
 unsigned char overflow_mask;
 unsigned char bank_lookup[256];
} ROM_MIRRORING_DATA;

ROM_MIRRORING_DATA rmd_32k, rmd_64k;

void setup_rom_mirroring(ROM_MIRRORING_DATA *rmd)
{
    int copycount, missing, count, next, banks_mirror_size;

    /* Compute a mask used to wrap invalid ROM bank numbers.
     */
    if (((rmd->bank_count * 2 - 1) & (rmd->bank_count - 1)) ==
     (rmd->bank_count - 1))
    /* compute mask for even power of two */
    {
        banks_mirror_size = rmd->bank_count;
    }
    else
    /* compute mask */
    {
        int i;

        /* compute the smallest even power of 2 greater than
           ROM bank count, and use that to compute the mask */
        for (i = 0; (rmd->bank_count >> i) > 0; i++);

        banks_mirror_size = (1 << i);
    }

    rmd -> overflow_mask = banks_mirror_size - 1;


    /* identity-map all the present banks */
    for (copycount = 0; copycount < rmd->bank_count; copycount++)
    {
        rmd -> bank_lookup [copycount] = copycount;
    }


    /* mirror-map all the not-present banks */
    for (next = rmd->bank_count, missing = banks_mirror_size - rmd->bank_count,
        count = 1; missing; count <<= 1, missing >>= 1)
    {
        if (missing & 1)
        {
            for (copycount = count; copycount; copycount--, next++)
            {
                rmd -> bank_lookup[next] =
                    rmd -> bank_lookup[next - count];
            }
        }
    }
}


SNESRomInfoStruct RomInfoLo, RomInfoHi;

int LoadSRAM(char *SRAM_filename)
{
 if (!snes_rom_loaded || !SaveRamLength) return 0;   // No SRAM

 // Return if we can't get SRAM filename
 if (CreateSRAMFilename(ROM_filename)) return 0;

 FILE *Infile = fopen(SRAM_filename, "rb");
 if (!Infile) return 0;         // Can't open file

 fread(SRAM, 1, SaveRamLength, Infile); // Read Save Ram

 /* Apply mirroring for small SRAMs, for reads */
 switch (SaveRamLength)
 {
  case (2 << 10):
   memcpy(SRAM + (2 << 10), SRAM, (2 << 10));
  case (4 << 10):
   memcpy(SRAM + (4 << 10), SRAM, (4 << 10));
 }

 fclose(Infile);
 return -1;
}

int SaveSRAM(char *SRAM_filename)
{
 if (!snes_rom_loaded || !SaveRamLength) return 0;   // No SRAM

 // Return if we can't get SRAM filename
 if (CreateSRAMFilename(ROM_filename)) return 0;

 FILE *Outfile = fopen(SRAM_filename, "wb");
 if (!Outfile) return 0;        // Can't open file

 fwrite(SRAM, 1, SaveRamLength, Outfile);   // Write Save Ram

 fclose(Outfile);
 return -1;
}

char *ROM_filename = 0;
char fn_drive[MAXDRIVE], fn_dir[MAXDIR], fn_file[MAXFILE], fn_ext[MAXEXT];
char SRAM_filename[MAXPATH];
char save_dir[MAXPATH];
char save_extension[MAXEXT];

ROMFileType GetROMFileType(const char *ROM_filename)
{
 fnsplit(ROM_filename, fn_drive, fn_dir, fn_file, fn_ext);
 if (!fn_ext) return ROMFileType_normal;
 if (!strcmp(fn_ext, ".1")) return ROMFileType_split;
/*
 if (fn_file)
 {
  if (!strnicmp(fn_file, "SF", 2)
   && (!strcmp(fn_ext, ".058") || !strcmp(fn_ext, ".078")))
  {
   printf("Game Doctor ROM detected.\n");
   return ROMFileType_gamedoctor;
  }
 }

 if (!stricmp(fn_ext, ".zip"))
 {
  printf("Compressed ROM detected.\n");
  return ROMFileType_compressed;
 }

 if (!stricmp(fn_ext, ".rar"))
 {
  printf("Compressed ROM detected.\n");
  return ROMFileType_compressed;
 }*/
 return ROMFileType_normal;
}

bool CreateSRAMFilename(char *ROM_filename)
{
 int length, slength;

 SRAM_filename[0] = 0;

 length = 1;    // 1 for the null
 fnsplit(ROM_filename, fn_drive, fn_dir, fn_file, fn_ext);
 if (!fn_file) return TRUE;
 length += strlen(fn_file);

 if (strlen(save_extension))
 {
  length += strlen(save_extension);
  if (save_extension[0] != '.') ++length; // One for leading period
 }

 slength = strlen(save_dir);
 if (slength)
 {
  length += slength;
  if (save_dir[slength - 1] != '/' && save_dir[slength - 1] != '\\')
   ++length;    // One for trailing slash
 } else {
  if (strlen(fn_drive))
  {
   length += strlen(fn_drive);
  }

  slength = strlen(fn_dir);
  if (slength)
  {
   length += slength;
   if (fn_dir[slength - 1] != '/' && fn_dir[slength - 1] != '\\')
    ++length;    // One for trailing slash
  }
 }

 if (length > MAXPATH) return TRUE;

 if (strlen(save_dir))
 {
  strcat(SRAM_filename, save_dir);
  if (save_dir[slength - 1] != '/' && save_dir[slength - 1] != '\\')
   strcat(SRAM_filename, "/");  // Add missing trailing slash
 } else {
  if (strlen(fn_drive))
  {
   strcat(SRAM_filename, fn_drive);
  }

  if (strlen(fn_dir))
  {
   strcat(SRAM_filename, fn_dir);
   if (fn_dir[slength - 1] != '/' && fn_dir[slength - 1] != '\\')
    strcat(SRAM_filename, "/");  // Add missing trailing slash
  }
 }

 strcat(SRAM_filename, fn_file);

 if (strlen(save_extension))
 {
  if (save_extension[0] != '.')
   strcat(SRAM_filename, ".");  // Add missing leading period
  strcat(SRAM_filename, save_extension);
 }

 return FALSE;
}

void DisplayRomStats(SNESRomInfoStruct *RomInfo);

// ROM is now dynamically allocated. This is to add large ROM support
// without raising RAM requirements when using smaller ROMs.
static unsigned char *AllocROMAddress = 0;

void Free_ROM()
{
 if (AllocROMAddress) free(AllocROMAddress);
 AllocROMAddress = (unsigned char *)0;
}

int Allocate_ROM()
{
 // De-allocate any previous memory
 Free_ROM();

 AllocROMAddress =
  (unsigned char *) malloc (rmd_64k.bank_count * (64 << 10) + (12 << 10));
 if (!AllocROMAddress) return rmd_64k.bank_count * (64 << 10) + (12 << 10);

 RomAddress =   // Force 4k alignment/8k misalignment
  (unsigned char *)(((unsigned)
   ((AllocROMAddress + ((8 << 10) - 1))) & ~((8 << 10) - 1)) + (4 << 10));
 memset(RomAddress, 0xFF, rmd_64k.bank_count * (64 << 10));

 return 0;
}

unsigned SRAM_Mask;

inline void set_block_read_handler(int bank, int block, void (*read)(void))
{
 Read_Bank8Mapping [bank * 8 + block] = (void (*)(void)) read;
 Read_Bank8Offset [bank * 8 + block] = (void *) 0;
}

inline void set_block_read_pointer(int bank, int block, void *read)
{
 Read_Bank8Mapping [bank * 8 + block] =
  (void (*)(void)) Read_Direct_Safeguard;
 Read_Bank8Offset [bank * 8 + block] = (void *) read;
}

inline void set_block_write_handler(int bank, int block, void (*write)(void))
{
 Write_Bank8Mapping[bank * 8 + block] = (void (*)(void)) write;
 Write_Bank8Offset[bank * 8 + block] = (void *) 0;
}

inline void set_block_write_pointer(int bank, int block, void *write)
{
 Write_Bank8Mapping[bank * 8 + block] =
  (void (*)(void)) Write_Direct_Safeguard;
 Write_Bank8Offset[bank * 8 + block] = (void *) write;
}

inline void set_block_handlers(int bank, int block, void (*read)(void), void (*write)(void))
{
 set_block_read_handler(bank, block, read);
 set_block_write_handler(bank, block, write);
}

inline void set_block_pointers(int bank, int block, void *read, void *write)
{
 set_block_read_pointer(bank, block, read);
 set_block_write_pointer(bank, block, write);
}

inline void map_wram(int bank, int block)
{
 set_block_pointers(bank, block, (void *) (WRAM - (bank << 16)), (void *) (WRAM - (bank << 16)));
}

inline void map_wram_128k(int bank)
{
 for (int i = 0; i < 8; i++)
 {
  set_block_pointers(bank, i, (void *) (WRAM - (bank << 16)), (void *) (WRAM - (bank << 16)));
  set_block_pointers(bank + 1, i, (void *) (WRAM - (bank << 16)), (void *) (WRAM - (bank << 16)));
 }
}

inline void map_unmapped(int bank, int block)
{
 set_block_handlers(bank, block, &UNSUPPORTED_READ, &UNSUPPORTED_WRITE);
}

inline void map_unmapped_32k(int bank)
{
 for (int i = 4; i < 8; i++) map_unmapped(bank, i);
}

inline void map_unmapped_64k(int bank)
{
 for (int i = 0; i < 8; i++) map_unmapped(bank, i);
}

inline void map_blank(int bank, int block)
{
 set_block_pointers(bank, block, (void *) (Blank - (bank << 16)), (void *) (Dummy - (bank << 16)));
 map_unmapped(bank, block);
}

inline void map_blank_32k(int bank)
{
 for (int i = 4; i < 8; i++) map_blank(bank, i);
}

inline void map_blank_64k(int bank)
{
 for (int i = 0; i < 8; i++) map_blank(bank, i);
}

inline void map_sram(int bank, int block, int sram_block,
 void (*sram_write_handler)(void))
{
 set_block_read_pointer(bank, block,
  SRAM + (sram_block << 13) - (bank << 16) - (block << 13));
// set_block_write_pointer(bank, block,
//  SRAM + (sram_block << 13) - (bank << 16) - (block << 13));
 set_block_write_handler(bank, block, sram_write_handler);
}

inline void map_no_sram(int bank, int block)
{
 map_blank(bank, block);
}

inline void map_sram_2k(int bank, int block)
{
 set_block_read_pointer(bank, block, SRAM - (bank << 16) - (block << 13));
 set_block_write_handler(bank, block, &SRAM_WRITE_2k);
}

inline void map_sram_4k(int bank, int block)
{
 set_block_read_pointer(bank, block, SRAM - (bank << 16) - (block << 13));
 set_block_write_handler(bank, block, &SRAM_WRITE_4k);
}

inline void map_sram_32k(int bank, int sram_block, int mask,
 void (*sram_write_handler)(void))
{
 for (int i = 0; i < 4; i++) map_sram(bank, i, sram_block + (i & mask),
  sram_write_handler);
}

inline void map_no_sram_32k(int bank)
{
 for (int i = 0; i < 4; i++) map_no_sram(bank, i);
}

inline void map_sram_2k_32k(int bank)
{
 for (int i = 0; i < 4; i++) map_sram_2k(bank, i);
}

inline void map_sram_4k_32k(int bank)
{
 for (int i = 0; i < 4; i++) map_sram_4k(bank, i);
}

inline void map_rom_32k_lorom(int bank)
{
 int needed_bank;

 needed_bank = rmd_32k.bank_lookup [(bank & 0x7F) & rmd_32k.overflow_mask];

 for (int i = 4; i < 8; i++)
 {
  set_block_pointers(bank, i, (void *) (RomAddress - ((bank - needed_bank) << 16) - (needed_bank + 1) * 0x8000), (void *) (Dummy - (bank << 16)));
 }
}

inline void map_rom_32k_lorom_40_C0(int bank)
{
 int needed_bank;

 needed_bank = rmd_32k.bank_lookup [(bank & 0x3F) & rmd_32k.overflow_mask];

 for (int i = 0; i < 4; i++)
 {
  set_block_pointers(bank, i, (void *) (RomAddress - ((bank - needed_bank) << 16) - (needed_bank & 0x7F) * 0x8000), (void *) (Dummy - (bank << 16)));
 }

 map_rom_32k_lorom(bank);
}

inline void map_rom_32k_hirom(int bank)
{
 int needed_bank;

 needed_bank = rmd_64k.bank_lookup [(bank & 0x3F) & rmd_64k.overflow_mask];

 for (int i = 4; i < 8; i++)
 {
  set_block_pointers(bank, i, (void *) (RomAddress - ((bank - needed_bank) << 16)), (void *) (Dummy - (bank << 16)));
 }
}

inline void map_rom_64k(int bank)
{
 int needed_bank;

 needed_bank = rmd_64k.bank_lookup [(bank & 0x3F) & rmd_64k.overflow_mask];

 for (int i = 0; i < 8; i++)
 {
  set_block_pointers(bank, i, (void *) (RomAddress - ((bank - needed_bank) << 16)), (void *) (Dummy - (bank << 16)));
 }
}

inline void map_ports(int bank)
{
 map_wram(bank, 0);
 set_block_handlers(bank, 1, &PPU_READ, &PPU_WRITE);
 set_block_handlers(bank, 2, &PPU_READ, &PPU_WRITE);
}

static inline void set_rom_speed(int A23, unsigned char MEMSEL)
{
 int bank, speed;

 speed = (MEMSEL & 1) ? 6 : 8;

 for (bank = (A23 ? 0x80 : 0); bank < (A23 ? 0xC0 : 0x40); bank++)
 {
  BlockSpeed[bank * 8 + 4] = speed;
  BlockSpeed[bank * 8 + 5] = speed;
  BlockSpeed[bank * 8 + 6] = speed;
  BlockSpeed[bank * 8 + 7] = speed;
 }

 for (bank = (A23 ? 0xC0 : 0x40); bank < (A23 ? 0x100 : 0x7E); bank++)
 {
  BlockSpeed[bank * 8 + 0] = speed;
  BlockSpeed[bank * 8 + 1] = speed;
  BlockSpeed[bank * 8 + 2] = speed;
  BlockSpeed[bank * 8 + 3] = speed;
  BlockSpeed[bank * 8 + 4] = speed;
  BlockSpeed[bank * 8 + 5] = speed;
  BlockSpeed[bank * 8 + 6] = speed;
  BlockSpeed[bank * 8 + 7] = speed;
 }
}

static void set_lower_rom_speed(void)
{
 set_rom_speed(0, 0);
}

extern "C" void set_upper_rom_speed(unsigned char MEMSEL)
{
 set_rom_speed(1, MEMSEL);
}

extern "C" void reset_bus_timings(void)
{
 int bank, block;

 /* lower ROM area - 00-3F:8000-FFFF, 40-7D:0000-FFFF; always 8 cycles */
 set_lower_rom_speed();
 /* upper ROM area - 80-BF:8000-FFFF, C0-FF:0000-FFFF; 6/8 cycles select */
 set_upper_rom_speed(0);

 /* access times in master cycles for for non-ROM areas */
 
 /* 8 - RAM, 00-3F/80-BF:6000-7FFF */
 for (bank = 0; bank < 0x40; bank++)
 {
  BlockSpeed[bank * 8] = 8;
  BlockSpeed[bank * 8 + 3] = 8;
  BlockSpeed[(bank + 0x80) * 8] = 8;
  BlockSpeed[(bank + 0x80) * 8 + 3] = 8;
 }
 for (bank = 0x7E; bank < 0x80; bank++)
 {
  for (block = 0; block < 8; block++)
  {
   BlockSpeed[bank * 8 + block] = 8;
  }
 }

 /* 12 - legacy CPU register area (00-3F/80-BF:4000-41FF) */
 /* 6 - all remaining area (00-3F/80-BF:2000-3FFF and 4200-5FFF) */
 for (bank = 0; bank < 0x40; bank++)
 {
  BlockSpeed[bank * 8 + 1] = 6;
  BlockSpeed[bank * 8 + 2] = 6;
  BlockSpeed[(bank + 0x80) * 8 + 1] = 6;
  BlockSpeed[(bank + 0x80) * 8 + 2] = 6;
 }

 FILE *out = fopen("memspeed.dmp", "wb");
 if (out)
 {
  fwrite(BlockSpeed, 1, 256 * 8, out);
  fclose(out);
 }

}

// SRAM is now dynamically allocated. This is to add large SRAM support
// without raising RAM requirements when using smaller SRAMs.
unsigned char *SRAM = 0;

void Free_SRAM()
{
 if (SRAM) free(SRAM);
 SRAM = (unsigned char *)0;
}

// SaveRamLength is bytes
int Allocate_SRAM()
{
 // De-allocate any previous memory
 Free_SRAM();

 if (!SaveRamLength) return 0;

 // We need at least 8k to use direct read
 SRAM=(unsigned char *)malloc(SaveRamLength > (8 << 10) ?
  SaveRamLength : (8 << 10));
 if (!SRAM) return SaveRamLength;

 return 0;
}

// Hack for FF6 world map glitch
// To be removed when timing improved
extern unsigned char FastROM_offset;

void Set_SNES_Map()
{

 if (!strcmp(rom_name, "FINAL FANTASY 3      ") ||
  !strcmp(rom_name, "FINAL FANTASY 6      "))
 {
  FastROM_offset = 4;
 }
 else
 {
  FastROM_offset = 5;
 }


 int b;

 for (b = 0; b <= 0x3F; b++)
 {
  map_ports(b);
  map_ports(b + 0x80);
 }

 map_wram_128k(0x7E);
}

bool Set_LoROM_Map()
{

 int b;

 for (b = 0; b <= 0xFF; b++)
 {
  map_unmapped_64k(b);
 }

 for (b = 0; b <= 0x3F; b++)
 {
  map_rom_32k_lorom(b);
  map_rom_32k_lorom(b + 0x80);
  map_rom_32k_lorom_40_C0(b + 0x40);
  map_rom_32k_lorom_40_C0(b + 0xC0);
 }

 // Limit to 4Mbit/512kB SRAM
 if (SaveRamLength > (512 << 10))
 {
    SaveRamLength = (512 << 10);
 }

 SRAM_Mask = SaveRamLength - 1;

 if (Allocate_SRAM()) return FALSE;

 /* SRAM located in banks 70 to (?) 7D, mirrored at F0 to (?) FF */
 /* Complete banks mapped */
 for (b = 0x70; b <= 0x7F; b++)
 {
  switch (SaveRamLength)
  {
   case 0: // No SRAM
    map_no_sram_32k(b);
    map_no_sram_32k(b + 0x80);
    break;
   case 0x800:  // 16kbit/2kB SRAM
    map_sram_2k_32k(b);
    map_sram_2k_32k(b + 0x80);
    break;
   case 0x1000: // 32kbit/4kB SRAM
    map_sram_4k_32k(b);
    map_sram_4k_32k(b + 0x80);
    break;
   case 0x2000: // 64kbit/8kB SRAM
    map_sram_32k(b       , 0, 0, SRAM_WRITE);
    map_sram_32k(b + 0x80, 0, 0, SRAM_WRITE);
    break;
   case 0x4000: // 128kbit/16kB SRAM
    map_sram_32k(b       , 0, 1, SRAM_WRITE);
    map_sram_32k(b + 0x80, 0, 1, SRAM_WRITE);
    break;
   case 0x8000: // 256kbit/32kB SRAM
    map_sram_32k(b       , 0, 3, SRAM_WRITE);
    map_sram_32k(b + 0x80, 0, 3, SRAM_WRITE);
    break;
   case 0x10000: // 512kbit/64kB SRAM
    map_sram_32k(b       , (b & 1) * 4, 3, SRAM_WRITE_ALT);
    map_sram_32k(b + 0x80, (b & 1) * 4, 3, SRAM_WRITE_ALT);
    break;
   case 0x20000: // 1Mbit/128kB SRAM
    map_sram_32k(b       , (b & 3) * 4, 3, SRAM_WRITE_ALT);
    map_sram_32k(b + 0x80, (b & 3) * 4, 3, SRAM_WRITE_ALT);
    break;
   case 0x40000: // 2Mbit/256kB SRAM
    map_sram_32k(b       , (b & 7) * 4, 3, SRAM_WRITE_ALT);
    map_sram_32k(b + 0x80, (b & 7) * 4, 3, SRAM_WRITE_ALT);
    break;
   case 0x80000: // 4Mbit/512kB SRAM
    map_sram_32k(b       , (b & 15) * 4, 3, SRAM_WRITE_ALT);
    map_sram_32k(b + 0x80, (b & 15) * 4, 3, SRAM_WRITE_ALT);
    break;
  }
 }

 Set_SNES_Map();

 return TRUE;
}

bool Set_HiROM_Map()
{
 int b;

 for (b = 0; b <= 0xFF; b++)
 {
  map_unmapped_64k(b);
 }

 for (b = 0; b <= 0x3F; b++)
 {
  map_rom_32k_hirom(b);
  map_rom_32k_hirom(b + 0x80);
  map_rom_64k(b + 0x40);
  map_rom_64k(b + 0xC0);
 }

 // Limit to 1Mbit/128kB SRAM
 if (SaveRamLength > (128 << 10))
 {
    SaveRamLength = (128 << 10);
 }

 SRAM_Mask = SaveRamLength - 1;

 if (Allocate_SRAM()) return FALSE;

 /* SRAM located in banks 30 to (?) 3F, mirrored at B0 to (?) BF */
 /* Addresses 6000-7FFF only */
 for (b = 0x30; b <= 0x3F; b++)
 {
  switch (SaveRamLength) // Setup mapper for rest of 32k ROM banks + SRAM
  {
   case 0:       // No SRAM
    map_no_sram(b       , 3);
    map_no_sram(b + 0x80, 3);
    break;
   case 0x800:   // 16kbit/2kB SRAM
    map_sram_2k(b       , 3);
    map_sram_2k(b + 0x80, 3);
    break;
   case 0x1000:  // 32kbit/4kB SRAM
    map_sram_4k(b       , 3);
    map_sram_4k(b + 0x80, 3);
    break;
   case 0x2000:  // 64kbit/8kB SRAM
    map_sram(b       , 3, 0, SRAM_WRITE_HIROM);
    map_sram(b + 0x80, 3, 0, SRAM_WRITE_HIROM);
    break;
   case 0x4000:  // 128kbit/16kB SRAM
    map_sram(b       , 3, b & 1, SRAM_WRITE_HIROM);
    map_sram(b + 0x80, 3, b & 1, SRAM_WRITE_HIROM);
    break;
   case 0x8000:  // 256kbit/32kB SRAM
    map_sram(b       , 3, b & 3, SRAM_WRITE_HIROM);
    map_sram(b + 0x80, 3, b & 3, SRAM_WRITE_HIROM);
    break;
   case 0x10000: // 512kbit/64kB SRAM
    map_sram(b       , 3, b & 7, SRAM_WRITE_HIROM);
    map_sram(b + 0x80, 3, b & 7, SRAM_WRITE_HIROM);
    break;
   case 0x20000: // 1Mbit/128kB SRAM
    map_sram(b       , 3, b & 15, SRAM_WRITE_HIROM);
    map_sram(b + 0x80, 3, b & 15, SRAM_WRITE_HIROM);
    break;
  }
 }

 Set_SNES_Map();

 return TRUE;
}

int ROM_has_header = Undetected;
/* Off = LoROM, On = HiROM, Undetected = autodetect */
int ROM_memory_map = Undetected;
int ROM_interleaved = Undetected;
int ROM_video_standard = Undetected;

void Load_32k(FILE *infile)
{
 // Read in as 32k blocks and (de)interleave
 for (int cnt = 0; cnt < rmd_64k.bank_count; cnt++) // Read first half
  fread2(RomAddress + cnt * 65536 + 32768, 1, 32768, infile);

 for (int cnt = 0; cnt < rmd_64k.bank_count; cnt++) // Read second half
  fread2(RomAddress + cnt * 65536, 1, 32768, infile);
}

void Load_64k(FILE *infile)
{
 for (int cnt = 0; cnt < rmd_64k.bank_count; cnt++) // Read in ROM
 {
  fread2(RomAddress + cnt * 65536, 1, 65536, infile);
 }
}

unsigned check_for_header(FILE *fp, int filesize)
{
 unsigned ROM_start;

 // Easiest way to detect ROM header
  // Improvement suggested by Gridle (implemented 22/4/99)
  // check against even multiple of 1k instead of 32k
 // If ROM filesize is even multiple of 1k, assume no header
 // If ROM filesize is even multiple of 1k, +512, assume header
 if ((((filesize % 1024) == 0) || (ROM_has_header == Off)) &&
  (ROM_has_header != On)) ROM_start = 0;
 else if (((filesize % 1024) == ROM_Header_Size) || (ROM_has_header == On))
  ROM_start = ROM_Header_Size;
 else { // Basic header detection failure
/* Gridle 04/03/1998 (dmy)

ROM header in SMC files at 0x100 - 0x1FF usually is zero. I couldn't find
any other reliable way to check if the ROM is really SMC or BIN.

Originally I checked everything from 0x10 - 0x1FF, but one of my ROMs
(Brainies) had some stupid pirate group stuff just before 0x100, so I
changed this to search from 0x100 - 0x1FF.

This is now changed to 0x100 - 0x1F9 because of the king arthur ROM.

Charles Bilyue' 06/01/1999 (dmy)

(Check was later changed to 0x110 - 0x1F9 for some reason?)

LoROM checksums at 7FDC/7FDE, 81DC/81DE with header
HiROM checksums at FFDC/FFDE, 101DC/101DE with header

*/
  ROM_Header Header;     // For checking if the ROM has a header

  fseek2(fp,0,SEEK_SET);
  fread2(&Header,ROM_Header_Size,1,fp);

  ROM_start=ROM_Header_Size;

  for (unsigned cnt = 0x110 - 11; cnt < 0x1FA - 11; cnt++)
   if (Header.RestOfHeader[cnt] != 0){ ROM_start = 0; break; }
 }
/*
 if (ROM_start == ROM_Header_Size)
  printf("Header detected and ignored.\n");
 else
  printf("No header detected.\n");
 */
 return ROM_start;
}

static bool open_rom_normal(const char *Filename)
{
 FILE *infile = fopen2(Filename, "rb");
 if (!infile) return FALSE; // File aint there m8

 unsigned ROM_start;        // This is where the ROM code itself starts.

 fseek2(infile, 0, SEEK_END);
 int infilesize = ftell2(infile);
 ROM_start = check_for_header(infile, infilesize);

 if (ROM_start == ROM_Header_Size)
  printf("Header detected and ignored.\n");
 else
  printf("No header detected.\n");

 ROM_format = Undetected;

 fseek2(infile, 0x7FC0 + ROM_start, SEEK_SET);
 fread2(&RomInfoLo, sizeof(SNESRomInfoStruct), 1, infile);
 fseek2(infile, 0xFFC0 + ROM_start, SEEK_SET);
 fread2(&RomInfoHi, sizeof(SNESRomInfoStruct), 1, infile);

 if ((RomInfoLo.Checksum ^ RomInfoLo.Complement) == 0xFFFF)
 {
  if ((RomInfoLo.ROM_makeup & 0x0F) == 1)
  {
   strcpy(rom_romhilo, "Interleaved HiROM detected");
   ROM_format = HiROM_Interleaved;
  } else {
   strcpy(rom_romhilo, "LoROM detected");
   ROM_format = LoROM;
  }
 } else {
  if (((RomInfoHi.Checksum ^ RomInfoHi.Complement) == 0xFFFF))
  {
   strcpy(rom_romhilo, "HiROM detected");
   ROM_format = HiROM;
  } else {
   strcpy(rom_romhilo, "Detection failed, using LoROM");
   ROM_format = LoROM;
  }
 }

 /* *** To do: add proper type/size detection for this ROM */
 /* SNES ROM header is at 01:FFC0 */
 if (!strcmp(rom_name, "BATMAN--REVENGE JOKER"))
 {
  ROM_format = LoROM;
 }

 switch (ROM_memory_map)
 {
  case HiROM:
   if (ROM_format & HiROM) break;
   ROM_format = HiROM;
   strcpy(rom_romhilo, "HiROM forced"); break;
  case LoROM:
   if (!(ROM_format & HiROM)) break;
   ROM_format = LoROM;
   strcpy(rom_romhilo, "LoROM forced"); break;
 }

 switch (ROM_interleaved)
 {
  case On: ROM_format |= Interleaved; break;
  case Off: ROM_format &= ~Interleaved; break;
 }

 rmd_64k.bank_count = (((infilesize - ROM_start) + (64 << 10) - 1)
  / (64 << 10));
 rmd_32k.bank_count = (((infilesize - ROM_start) + (32 << 10) - 1)
  / (32 << 10));

 // Maximum 32Mbit ROM size for LoROM
 if (rmd_64k.bank_count > 64)
 {
  rmd_64k.bank_count = 64;
  rmd_32k.bank_count = 128;
 }

 if (Allocate_ROM())   // Dynamic allocation of ROM
 {
  fclose2(infile);
  return FALSE;        // return false if no memory left
 }

 setup_rom_mirroring(&rmd_32k);
 setup_rom_mirroring(&rmd_64k);

 fseek2(infile, ROM_start, SEEK_SET);

 switch(ROM_format)
 {
  case HiROM:
   DisplayRomStats(&RomInfoHi);

   if (!Set_HiROM_Map())
   {
    Free_ROM();
    fclose2(infile);

    return FALSE;        // return false if no memory left
   }

   Load_64k(infile);

   break;

  case HiROM_Interleaved:
   DisplayRomStats(&RomInfoLo);

   if (!Set_HiROM_Map())
   {
    Free_ROM();
    fclose2(infile);

    return FALSE;        // return false if no memory left
   }

   Load_32k(infile);

   break;

  case LoROM_Interleaved:
   printf("Interleaved LoROM not supported - basic LoROM loader used\n");
  case LoROM:
  default:
   DisplayRomStats(&RomInfoLo);

   if (!Set_LoROM_Map())
   {
    Free_ROM();
    fclose2(infile);

    return FALSE;        // return false if no memory left
   }

   Load_64k(infile);

   break;
 }

 fclose2(infile);
 return TRUE;
}

bool Load_32k_split(FILE *infile, const char *Filename, int parts, long total_size)
{
 char tempname[MAXPATH];
 long bytes_read = 0;
 int part = 1;
 int infilesize;
 unsigned ROM_start;

 fnsplit(Filename, fn_drive, fn_dir, fn_file, fn_ext);

 // Read in as 32k blocks and interleave
 for (int cnt = 0;
      cnt < rmd_64k.bank_count && part <= parts; cnt++) // Read first half
 {
  infilesize = fread2(RomAddress + cnt * 65536 + 32768, 1, 32768, infile);
  if (infilesize != EOF) bytes_read += infilesize;

  while ((bytes_read % 32768) || (infilesize < 1))
  {
  // partial bank read, must complete (or nothing read, go to next file)

   // next file
   fclose2(infile);
   if (++part > parts)
   {
    if (bytes_read != total_size) return FALSE;
    else break;
   }

   sprintf(fn_ext, ".%d", part);
   fnmerge(tempname, fn_drive, fn_dir, fn_file, fn_ext);

   FILE *infile=fopen2(tempname,"rb");
   if (!infile) return FALSE;

   fseek2(infile, 0, SEEK_END);
   infilesize = ftell2(infile);
   ROM_start = check_for_header(infile, infilesize);
   total_size -= ROM_start;
   fseek2(infile,ROM_start,SEEK_SET);

   infilesize =
    fread2(RomAddress + cnt * 65536 + 32768 + (bytes_read % 32768), 1,
    32768 - (bytes_read % 32768), infile);

   if (infilesize != EOF) bytes_read += infilesize;
  }
 }

 for (int cnt = 0;
      cnt < rmd_64k.bank_count && part <= parts; cnt++) // Read second half
 {
  infilesize = fread2(RomAddress + cnt * 65536, 1, 32768, infile);
  if (infilesize != EOF) bytes_read += infilesize;

  while ((bytes_read % 32768) || (infilesize < 1))
  {
  // partial bank read, must complete (or nothing read, go to next file)

   // next file
   if (++part > parts)
   {
    if (bytes_read != total_size) return FALSE;
    else break;
   }
   fclose2(infile);

   sprintf(fn_ext, ".%d", part);
   fnmerge(tempname, fn_drive, fn_dir, fn_file, fn_ext);

   FILE *infile=fopen2(tempname,"rb");
   if (!infile) return FALSE;

   fseek2(infile, 0, SEEK_END);
   infilesize = ftell2(infile);
   ROM_start = check_for_header(infile, infilesize);
   total_size -= ROM_start;
   fseek2(infile,ROM_start,SEEK_SET);

   infilesize =
    fread2(RomAddress + cnt * 65536 + (bytes_read % 32768), 1,
    32768 - (bytes_read % 32768), infile);

   if (infilesize != EOF) bytes_read += infilesize;
  }
 }

 fclose2(infile);
 return TRUE;
}

static bool open_rom_split(const char *Filename)
{
 char tempname[MAXPATH];
 int parts;
 long total_size = 0;

 fnsplit(Filename, fn_drive, fn_dir, fn_file, fn_ext);
 for (parts = 1; parts < 1000; parts++)
 {
  sprintf(fn_ext, ".%d", parts + 1);
  fnmerge(tempname, fn_drive, fn_dir, fn_file, fn_ext);
  FILE *infile=fopen2(tempname,"rb");
  if (!infile) break;
  fseek2(infile, 0, SEEK_END);
  total_size += ftell2(infile);
  fclose2(infile);
 }
 if (parts == 1) return open_rom_normal(Filename);
 printf("Split ROM image detected - %d parts found.\n", parts);

 FILE *infile=fopen2(Filename,"rb");
 if (!infile) return FALSE;  // File aint there m8

 unsigned ROM_start;        // This is where the ROM code itself starts.

 fseek2(infile, 0, SEEK_END);
 int infilesize = ftell2(infile);
 ROM_start = check_for_header(infile, infilesize);
 total_size += infilesize - ROM_start;

 ROM_format = Undetected;

 unsigned RomInfoHi_Read;

 fseek2(infile,0x7FC0+ROM_start,SEEK_SET);
 if (fread2(&RomInfoLo,sizeof(SNESRomInfoStruct),1,infile) != 1)
 {
  fclose2(infile);
  return FALSE;
 }
 fseek2(infile,0xFFC0+ROM_start,SEEK_SET);
 RomInfoHi_Read = fread2(&RomInfoHi,sizeof(SNESRomInfoStruct),1,infile);

 // if checksum and complement match, or HiROM info block couldn't be read
 if ((RomInfoLo.Checksum^RomInfoLo.Complement) == 0xFFFF ||
     RomInfoHi_Read != 1)
 {
  if ((RomInfoLo.ROM_makeup&0x0F)==1)
  {
   strcpy(rom_romhilo,"Interleaved HiROM detected");
   ROM_format = HiROM_Interleaved;
  } else {
   strcpy(rom_romhilo,"LoROM detected");
   ROM_format = LoROM;
  }
 } else {
  if (((RomInfoHi.Checksum^RomInfoHi.Complement) == 0xFFFF))
  {
   strcpy(rom_romhilo,"HiROM detected");
   ROM_format = HiROM;
  } else {
   strcpy(rom_romhilo,"Detection failed, using LoROM");
   ROM_format = LoROM;
  }
 }

 if (!strcmp(rom_name, "BATMAN--REVENGE JOKER"))
 {
  ROM_format = LoROM;
 }

 switch (ROM_memory_map)
 {
  case HiROM:
   if (ROM_format & HiROM) break;
   ROM_format = HiROM;
   strcpy(rom_romhilo, "HiROM forced"); break;
  case LoROM:
   if (!(ROM_format & HiROM)) break;
   ROM_format = LoROM;
   strcpy(rom_romhilo, "LoROM forced"); break;
 }

 switch (ROM_interleaved)
 {
  case On: ROM_format |= Interleaved; break;
  case Off: ROM_format &= ~Interleaved; break;
 }

 rmd_64k.bank_count = ((total_size + (64 << 10) - 1) / (64 << 10));
 rmd_32k.bank_count = ((total_size + (32 << 10) - 1) / (32 << 10));

 // Maximum 32Mbit ROM size for LoROM
 if (rmd_64k.bank_count > 64)
 {
  rmd_64k.bank_count = 64;
  rmd_32k.bank_count = 128;
 }

 if (Allocate_ROM())   // Dynamic allocation of ROM
 {
  fclose2(infile);
  return FALSE;        // return false if no memory left
 }

 setup_rom_mirroring(&rmd_32k);
 setup_rom_mirroring(&rmd_64k);

 fseek2(infile,ROM_start,SEEK_SET);

 switch(ROM_format)
 {
  long bytes_read;

  case HiROM:

   DisplayRomStats(&RomInfoHi);

   if (!Set_HiROM_Map())
   {
    Free_ROM();
    fclose2(infile);

    return FALSE;        // return false if no memory left
   }

   bytes_read = fread2(RomAddress,1,total_size,infile);
   fclose2(infile);

   fnsplit(Filename, fn_drive, fn_dir, fn_file, fn_ext);
   for (int part = 2; part <= parts; part++)
   {
    sprintf(fn_ext, ".%d", part);
    fnmerge(tempname, fn_drive, fn_dir, fn_file, fn_ext);

    FILE *infile=fopen2(tempname,"rb");
    if (!infile) break;

    fseek2(infile, 0, SEEK_END);
    infilesize = ftell2(infile);
    ROM_start = check_for_header(infile, infilesize);
    total_size -= ROM_start;
    fseek2(infile,ROM_start,SEEK_SET);

    infilesize =
     fread2(RomAddress + bytes_read, 1, total_size - bytes_read, infile);
    fclose2(infile);
    if (infilesize == EOF) break;
    if (total_size == bytes_read) break;
    bytes_read += infilesize;
   }
   if (infilesize == EOF) return FALSE;
   if (!infile) return FALSE;
   break;
  case HiROM_Interleaved:
   DisplayRomStats(&RomInfoLo);

   if (!Set_HiROM_Map())
   {
    Free_ROM();
    fclose2(infile);

    return FALSE;        // return false if no memory left
   }

   return Load_32k_split(infile, Filename, parts, total_size);

   break;
  case LoROM_Interleaved:
   printf("Split interleaved LoROM not supported - split basic LoROM loader used\n");
  case LoROM:
  default:
   DisplayRomStats(&RomInfoLo);

   if (!Set_LoROM_Map())
   {
    Free_ROM();
    fclose2(infile);

    return FALSE;        // return false if no memory left
   }

   bytes_read = fread2(RomAddress,1,total_size,infile);
   fclose2(infile);

   fnsplit(Filename, fn_drive, fn_dir, fn_file, fn_ext);
   for (int part = 2; part <= parts; part++)
   {
    sprintf(fn_ext, ".%d", part);
    fnmerge(tempname, fn_drive, fn_dir, fn_file, fn_ext);

    FILE *infile=fopen2(tempname,"rb");
    if (!infile) break;

    fseek2(infile, 0, SEEK_END);
    infilesize = ftell2(infile);
    ROM_start = check_for_header(infile, infilesize);
    total_size -= ROM_start;
    fseek2(infile,ROM_start,SEEK_SET);

    infilesize =
     fread2(RomAddress + bytes_read, 1, total_size - bytes_read, infile);
    fclose2(infile);
    if (infilesize == EOF) break;
    if (total_size == bytes_read) break;
    bytes_read += infilesize;
   }
   if (infilesize == EOF) return FALSE;
   if (!infile) return FALSE;

   break;
 }

 return TRUE;
}

/* Filename must contain a full path */
int open_rom(const char *Filename)
{
 ROMFileType filetype;

 SaveSRAM(SRAM_filename);   // Ensures SRAM saved before loading new ROM
 snes_rom_loaded = FALSE;
 SaveRamLength = 0;

 filetype = GetROMFileType(Filename);

 if (!ROM_filename) ROM_filename = (char *) malloc(MAXPATH);
 if (!rom_romfile) rom_romfile   = (char *) malloc(MAXPATH);
 if (!rom_romhilo) rom_romhilo   = (char *) malloc(100);
 if (!rom_romtype) rom_romtype   = (char *) malloc(50);
 if (!rom_romsize) rom_romsize   = (char *) malloc(50);
 if (!rom_romname) rom_romname   = (char *) malloc(50);
 if (!rom_sram)    rom_sram      = (char *) malloc(50);
 if (!rom_country) rom_country   = (char *) malloc(50);
 if (!ROM_filename || !rom_romfile || !rom_romhilo
  || !rom_romtype || !rom_romsize || !rom_romname
  || !rom_sram || !rom_country)
  return FALSE;

 strcpy(ROM_filename, Filename);
 strcpy(rom_romfile, Filename);

 switch (filetype)
 {
  case ROMFileType_split: snes_rom_loaded = open_rom_split(Filename); break;
  case ROMFileType_normal:
  default: snes_rom_loaded = open_rom_normal(Filename);
 }

 if (snes_rom_loaded == FALSE) return FALSE;

 Reset_Memory();
 Reset_SRAM();
 snes_reset();

 LoadSRAM(SRAM_filename);     // This loads in the Save RAM

 printf("RES: %04X\n"
        "NMI N,E: %04X,%04X\n"
        "IRQ N,E: %04X,%04X\n"
        "BRK N,E: %04X,%04X\n"
        "COP N,E: %04X,%04X\n",
  cpu_65c816_PC,
  NMI_Nvector, NMI_Evector,
  IRQ_Nvector, IRQ_Evector,
  BRK_Nvector, IRQ_Evector,
  COP_Nvector, COP_Evector);

 FILE *memmap_dmp = fopen("memmap.dmp", "wb");
 if (memmap_dmp)
 {
  fwrite(Read_Bank8Offset, sizeof(Read_Bank8Offset), 1, memmap_dmp);
  fwrite(Write_Bank8Offset, sizeof(Write_Bank8Offset), 1, memmap_dmp);
  fwrite(Read_Bank8Mapping, sizeof(Read_Bank8Mapping), 1, memmap_dmp);
  fwrite(Write_Bank8Mapping, sizeof(Write_Bank8Mapping), 1, memmap_dmp);
  fwrite(&SRAM, sizeof(SRAM), 1, memmap_dmp);
  fclose(memmap_dmp);
 }

 return TRUE;
}

char *TypeTable[]={
 "ROM",
 "ROM+RAM",
 "ROM+SRAM",
 "ROM+DSP1",
 "ROM+RAM+DSP1",
 "ROM+SRAM+DSP1",
 "Unknown",
 "Unknown FX chip",
 "FX-V1",
 "FX(Argonaut)",
 "FX-V2",
 "FX(SA-1)",
 "FX(?KSS?)",
 "FX(Capcom)",
 "FX(S-DD1)",
 "FX(PLGS)",
 "FX(Gameboy)",
 "FX(BS-X)",
 "FX(Capcom C4)",
 "FX(SETA) (DSP2?)",
 "FX(OBC1)"
};

char *CountryTable[]={
 "Japan",
 "USA",
 "Europe, Oceania, Asia",     // Australia is part of Oceania
 "Sweden",
 "Finland",
 "Denmark",
 "France",
 "Holland",
 "Spain",
 "Germany, Austria, Switzerland",
 "Italy",
 "Hong Kong, China",
 "Indonesia",
 "South Korea"
};

void DisplayRomStats(SNESRomInfoStruct *RomInfo)
{
 // ROM Type

 switch(RomInfo->ROM_type)
 {
  case 0:   // ROM
  case 1:   // ROM/RAM
  case 2:   // ROM/SRAM
  case 3:   // ROM/DSP1
  case 4:   // ROM/RAM/DSP1
  case 5:   // ROM/SRAM/DSP1
   strcpy(rom_romtype, TypeTable[RomInfo->ROM_type]); break;
  case 0x10 ... 0x12:   case 0x16:
  case 0x20 ... 0x24:   case 0x26:
  case 0x30 ... 0x34:
  case 0x40 ... 0x42:   case 0x44:  case 0x46:
  case 0x50 ... 0x54:   case 0x56:
  case 0x60 ... 0x66:   case 0x70 ... 0x76:
  case 0x80 ... 0x86:   case 0x90 ... 0x96:
  case 0xA0 ... 0xA6:   case 0xB0 ... 0xB6:
  case 0xC0 ... 0xC6:   case 0xD0 ... 0xD6:
  case 0xE0 ... 0xE2:   case 0xE4:  case 0xE6:
  case 0xF0 ... 0xF2:   case 0xF4 ... 0xF5:
            // Unknown FX chip
   strcpy(rom_romtype, TypeTable[7]);
  case 0x13:    // FX-V1
   strcpy(rom_romtype, TypeTable[8]); break;
  case 0x14:    // FX(Argonaut)
   strcpy(rom_romtype, TypeTable[9]); break;
  case 0x15:    // FX-V2
   strcpy(rom_romtype, TypeTable[10]); break;
  case 0x35:    // FX(SA-1)
   strcpy(rom_romtype, TypeTable[11]); break;
  case 0x36:    // FX(?KSS?)
   strcpy(rom_romtype, TypeTable[12]); break;
  case 0x43:    // FX(Capcom)
   strcpy(rom_romtype, TypeTable[13]); break;
  case 0x45:    // FX(S-DD1)
   strcpy(rom_romtype, TypeTable[14]); break;
  case 0x55:    // FX(PLGS)
   strcpy(rom_romtype, TypeTable[15]); break;
  case 0xE3:    // FX(Gameboy)
   strcpy(rom_romtype, TypeTable[16]); break;
  case 0xE5:    // FX(BS-X)
   strcpy(rom_romtype, TypeTable[17]); break;
  case 0xF3:    // FX(Capcom C4)
   strcpy(rom_romtype, TypeTable[18]); break;
  case 0xF6:    // FX(SETA) (DSP2?)
   strcpy(rom_romtype, TypeTable[19]); break;
  case 0x25:    // OBC1, used by Metal Combat
   strcpy(rom_romtype, TypeTable[20]); break;
  default:      // Unknown
   strcpy(rom_romtype, TypeTable[6]);
 }

 // ROM Size

 sprintf(rom_romsize, "%dMbits", 1 << ((RomInfo->ROM_size) - 7));

 // ROM SRAM size

 SaveRamLength = RomInfo->SRAM_size;
 if (((RomInfo->ROM_type) == 2) || ((RomInfo->ROM_type) >= 5) &&
  SaveRamLength)
 {
  SaveRamLength = 1024 << SaveRamLength;

  sprintf(rom_sram, "%dKbits", SaveRamLength * 8 / 1024);
 } else {
  SaveRamLength = 0;
  strcpy(rom_sram,"No SRAM");
 }

 // ROM Country

 if (RomInfo->Country_code <= 13)
 {
  strcpy(rom_country, CountryTable[ RomInfo->Country_code ]);
  /* Japan, USA, Korea == NTSC */
  if ((((RomInfo->Country_code < 2) || (RomInfo->Country_code == 13)
  ) && (ROM_video_standard != PAL_video))
   || (ROM_video_standard == NTSC_video))
  {
   strcat(rom_country,
    (ROM_video_standard != NTSC_video) ? " (NTSC)" : " (NTSC forced)");

   set_snes_ntsc();
  }
  else if (((RomInfo->Country_code < 14) && (ROM_video_standard != NTSC_video))
   || (ROM_video_standard == PAL_video))
  {
   strcat(rom_country,
    (ROM_video_standard != PAL_video) ? " (PAL)" : " (PAL forced)");

   set_snes_pal();
  }
 } else {
  switch (ROM_video_standard)
  {
   case PAL_video:
    strcpy(rom_country, "Unknown (PAL forced)");

    set_snes_pal();
    break;

   case NTSC_video:
    strcpy(rom_country, "Unknown (NTSC forced)");

    set_snes_ntsc();
    break;

   default:
    strcpy(rom_country, "Unknown (Using NTSC)");

    set_snes_ntsc();
  }
 }

 // ROM Name

 for (int i = 0; i < 21; i++)
  rom_name[i] = RomInfo->ROM_Title[i];

 rom_name[21] = 0;

 strcpy(rom_romname,rom_name);

 // Print information

 printf("\nROM title: %s\n", rom_romname);
 printf("ROM type: %s\n",rom_romtype);
 if ((RomInfo->ROM_type) > 2)
  printf("Some extra hardware used by this ROM is not yet supported!\n");
 printf("%s\n",rom_romhilo);
 printf("ROM size: %s\n",rom_romsize);
 printf("SRAM size: %s\n",rom_sram);
 printf("Country: %s\n",rom_country);

}
