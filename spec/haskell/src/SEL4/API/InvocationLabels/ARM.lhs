%
% Copyright 2014, General Dynamics C4 Systems
%
% This software may be distributed and modified according to the terms of
% the GNU General Public License version 2. Note that NO WARRANTY is provided.
% See "LICENSE_GPLv2.txt" for details.
%
% @TAG(GD_GPL)
%

This module defines the machine-specific invocations for the ARM.

\begin{impdetails}

This module makes use of the GHC extension allowing data types with no constructors.

> {-# LANGUAGE CPP, EmptyDataDecls #-}

\end{impdetails}

> module SEL4.API.InvocationLabels.ARM where

\subsection{ARM-Specific Invocation Labels}

FIXME ARMHYP ARMPageMapIO is an inconsistant name (but coined by kernel team)

> data ArchInvocationLabel
>         = ARMPDClean_Data
>         | ARMPDInvalidate_Data
>         | ARMPDCleanInvalidate_Data
>         | ARMPDUnify_Instruction
>         | ARMPageTableMap
>         | ARMPageTableUnmap
#ifdef CONFIG_ARM_SMMU
>         | ARMIOPageTableMap
>         | ARMIOPageTableUnmap
#endif
>         | ARMPageMap
>         | ARMPageUnmap
#ifdef CONFIG_ARM_SMMU
>         | ARMPageMapIO
#endif
>         | ARMPageClean_Data
>         | ARMPageInvalidate_Data
>         | ARMPageCleanInvalidate_Data
>         | ARMPageUnify_Instruction
>         | ARMPageGetAddress
>         | ARMASIDControlMakePool
>         | ARMASIDPoolAssign
#ifdef CONFIG_ARM_HYPERVISOR_SUPPORT
>         | ARMVCPUSetTCB
>         | ARMVCPUInjectIRQ
>         | ARMVCPUReadReg
>         | ARMVCPUWriteReg
#endif
>         | ARMIRQIssueIRQHandler
>         deriving (Eq, Enum, Bounded, Show)

