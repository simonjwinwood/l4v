(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

theory Invocations_H
imports
  Structures_H
  "./$L4V_ARCH/ArchRetypeDecls_H"
  "./$L4V_ARCH/ArchLabelFuns_H"
begin
requalify_types (in Arch)
  copy_register_sets irqcontrol_invocation
  invocation

#INCLUDE_HASKELL SEL4/API/Invocation.lhs Arch=Arch NOT GenInvocationLabels InvocationLabel
#INCLUDE_HASKELL SEL4/API/InvocationLabels.lhs ONLY invocationType genInvocationType

context Arch begin
context begin global_naming global
requalify_types
  Invocations_H.invocation
end
end

end
