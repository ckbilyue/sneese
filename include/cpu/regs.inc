%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

%ifndef SNEeSe_cpu_regs_inc
%define SNEeSe_cpu_regs_inc

%define R_65c816_MemMap_Data        al
%define R_65c816_MemMap_DataHigh    ah
%define R_65c816_MemMap_Addx        ebx
%define R_65c816_P                  ecx
%define R_65c816_P_W                R_65c816_P
%define R_65c816_P_B                cl
%define R_65c816_Base               edi
%define R_65c816_Cycles             ebp
%define R_65c816_NativePC           esi
%define R_65c816_MemMap_Trash       edx

%endif ; !defined(SNEeSe_cpu_regs_inc)
