(*
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

(*
    Hypervisor code.
*)

theory Hypervisor_H
imports
  CNode_H
  "./$L4V_ARCH/ArchHypervisor_H"
  KernelInitMonad_H
begin

context begin interpretation Arch .
requalify_consts
  handleHypervisorFault
end

end
