--
-- Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
--
-- SPDX-License-Identifier: GPL-2.0-only
--

-- This module contains the architecture-specific kernel global data for the
-- RISCV 64bit architecture.

-- FIXME AARCH64: This file was copied *VERBATIM* from the RISCV64 version,
-- with minimal text substitution! Remove this comment after updating and
-- checking against C; update copyright as necessary.

-- FIXME AARCH64: added armKSHWASIDTable, leaving rest untouched

module SEL4.Model.StateData.AARCH64 where

import Prelude hiding (Word)
import SEL4.Machine
import SEL4.Machine.Hardware.AARCH64 (PTE(..))
import SEL4.Object.Structures.AARCH64

import Data.Array

-- used in proofs only
data RISCVVSpaceRegionUse
    = RISCVVSpaceUserRegion
    | RISCVVSpaceInvalidRegion
    | RISCVVSpaceKernelWindow
    | RISCVVSpaceKernelELFWindow
    | RISCVVSpaceDeviceWindow

data KernelState = RISCVKernelState {
    armKSASIDTable :: Array ASID (Maybe (PPtr ASIDPool)),
    armKSGlobalPTs :: Int -> [PPtr PTE],
    armKSKernelVSpace :: PPtr Word -> RISCVVSpaceRegionUse,
    armKSHWASIDTable :: Array VMID (Maybe ASID), -- FIXME AARCH64: should be armKSVMIDTable
    armKSNextASID :: VMID -- FIXME AARCH64: naming
}

-- counting from 0 at bottom, i.e. number of levels = maxPTLevel + 1;
-- maxPTLevel = level of top-level root table
maxPTLevel :: Int
maxPTLevel = 2

armKSGlobalPT :: KernelState -> PPtr PTE
armKSGlobalPT s = head (armKSGlobalPTs s maxPTLevel)

newKernelState :: PAddr -> (KernelState, [PAddr])
newKernelState _ = error "No initial state defined for RISC-V"
