(*
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

chapter "Architecture-specific Invocation Labels"

theory ArchInvocationLabels_H
imports
  "Word_Lib.Enumeration"
  "../../machine/Setup_Locale"
begin
context Arch begin global_naming RISCV64_H

text \<open>
  An enumeration of arch-specific system call labels.
\<close>

#INCLUDE_HASKELL SEL4/API/InvocationLabels/RISCV64.hs CONTEXT RISCV64_H ONLY ArchInvocationLabel

end

context begin interpretation Arch .
requalify_types arch_invocation_label
end

context Arch begin global_naming RISCV64_H

#INCLUDE_HASKELL SEL4/API/InvocationLabels/RISCV64.hs CONTEXT RISCV64_H instanceproofs ONLY ArchInvocationLabel

end
end
