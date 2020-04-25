(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

(*
  VSpace lookup code.
*)

theory ArchFault_H
imports "../Types_H"
(*  "../KI_Decls_H"
  ArchVSpaceDecls_H *)
begin
context Arch begin global_naming ARM_HYP_H


#INCLUDE_HASKELL SEL4/API/Failures/ARM.lhs CONTEXT ARM_HYP_H decls_only
#INCLUDE_HASKELL SEL4/API/Failures/ARM.lhs CONTEXT ARM_HYP_H bodies_only


end
end
