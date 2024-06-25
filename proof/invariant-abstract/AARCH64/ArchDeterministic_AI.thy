(*
 * Copyright 2022, Proofcraft Pty Ltd
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

theory ArchDeterministic_AI
imports Deterministic_AI ArchVCPU_AI
begin

declare dxo_wp_weak[wp del]

context Arch begin global_naming AARCH64

named_theorems Deterministic_AI_assms

crunch valid_list[wp, Deterministic_AI_assms]:
 vcpu_save, vcpu_enable, vcpu_disable, vcpu_restore, arch_get_sanitise_register_info, arch_post_modify_registers valid_list
  (wp: crunch_wps simp: unless_def crunch_simps)

lemma vcpu_switch_valid_list[wp, Deterministic_AI_assms]:
  "vcpu_switch v \<lbrace>valid_list\<rbrace>"
  unfolding vcpu_switch_def
  by wpsimp

crunch valid_list[wp, Deterministic_AI_assms]:
  cap_swap_for_delete,set_cap,finalise_cap,arch_get_sanitise_register_info,
  arch_post_modify_registers valid_list
  (wp: crunch_wps simp: unless_def crunch_simps)
declare get_cap_inv[Deterministic_AI_assms]

end

global_interpretation Deterministic_AI_1?: Deterministic_AI_1
proof goal_cases
  interpret Arch .
  case 1 show ?case by (unfold_locales; (fact Deterministic_AI_assms)?)
qed

context Arch begin global_naming AARCH64

crunch valid_list[wp,Deterministic_AI_assms]: arch_invoke_irq_handler valid_list

crunch valid_list[wp]: invoke_untyped valid_list
  (wp: crunch_wps preemption_point_inv' unless_wp mapME_x_wp'
   simp: mapM_x_def_bak crunch_simps)

crunches invoke_irq_control, perform_flush
  for valid_list[wp]: valid_list

lemma perform_page_table_invocation_valid_list[wp]:
  "perform_page_table_invocation a \<lbrace>valid_list\<rbrace>"
  unfolding perform_page_table_invocation_def
  by (wpsimp wp: mapM_x_wp' simp: perform_pt_inv_map_def perform_pt_inv_unmap_def)

lemma perform_page_invocation_valid_list[wp]:
  "perform_page_invocation a \<lbrace>valid_list\<rbrace>"
  apply (simp add: perform_page_invocation_def)
  apply (cases a, simp_all add: perform_pg_inv_map_def perform_pg_inv_unmap_def
                                perform_pg_inv_get_addr_def split_def)
    apply (wp mapM_x_wp' mapM_wp' crunch_wps | intro impI conjI allI | wpc
           | simp add: set_message_info_def set_mrs_def split: cap.splits arch_cap.splits)+
  done

crunch valid_list[wp]: perform_invocation valid_list
  (wp: crunch_wps simp: crunch_simps ignore: without_preemption as_user)

crunch valid_list[wp, Deterministic_AI_assms]: handle_invocation valid_list
  (wp: crunch_wps syscall_valid simp: crunch_simps
   ignore: without_preemption syscall)

crunch valid_list[wp, Deterministic_AI_assms]: handle_recv, handle_yield, handle_call valid_list
  (wp: crunch_wps simp: crunch_simps)

lemma handle_vm_fault_valid_list[wp, Deterministic_AI_assms]:
  "handle_vm_fault thread fault \<lbrace>valid_list\<rbrace>"
  unfolding handle_vm_fault_def by (cases fault; wpsimp)

crunches vgic_maintenance, vppi_event
  for valid_list[wp]: valid_list
  (wp: hoare_drop_imps)

lemma handle_interrupt_valid_list[wp, Deterministic_AI_assms]:
  "\<lbrace>valid_list\<rbrace> handle_interrupt irq \<lbrace>\<lambda>_.valid_list\<rbrace>"
  unfolding handle_interrupt_def ackInterrupt_def
  apply (rule hoare_pre)
   by (wp get_cap_wp  do_machine_op_valid_list
       | wpc | simp add: get_irq_slot_def handle_reserved_irq_def arch_mask_irq_signal_def
       | wp (once) hoare_drop_imps)+

crunch valid_list[wp, Deterministic_AI_assms]: handle_send,handle_reply valid_list

crunch valid_list[wp, Deterministic_AI_assms]: handle_hypervisor_fault valid_list
  (simp: isFpuEnable_def)

end

global_interpretation Deterministic_AI_2?: Deterministic_AI_2
proof goal_cases
  interpret Arch .
  case 1 show ?case by (unfold_locales; (fact Deterministic_AI_assms)?)
qed

end
