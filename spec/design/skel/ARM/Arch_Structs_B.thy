(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

(* Architecture-specific data types shared by spec and abstract. *)

chapter "Common, Architecture-Specific Data Types"

theory Arch_Structs_B
imports Main "../../../spec/machine/Setup_Locale"
begin
context Arch begin global_naming ARM_H

#INCLUDE_HASKELL SEL4/Model/StateData/ARM.lhs CONTEXT ARM_H ONLY ArmVSpaceRegionUse

end
end
