(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

theory ArchSchedule_AI
imports Schedule_AI
begin

context Arch begin global_naming ARM_HYP

named_theorems Schedule_AI_asms

lemma dmo_mapM_storeWord_0_invs[wp,Schedule_AI_asms]:
  "valid invs (do_machine_op (mapM (\<lambda>p. storeWord p 0) S)) (\<lambda>_. invs)"
  apply (simp add: dom_mapM ef_storeWord)
  apply (rule mapM_UNIV_wp)
  apply (simp add: do_machine_op_def split_def)
  apply wp
  apply (clarsimp simp: invs_def valid_state_def cur_tcb_def
                        valid_machine_state_def)
  apply (rule conjI)
   apply(erule use_valid[OF _ storeWord_valid_irq_states], simp)
  apply (erule use_valid)
   apply (simp add: storeWord_def word_rsplit_0)
   apply wp
  apply (clarsimp simp: word_bits_conv)
  done

crunch device_state_inv[wp]: clearExMonitor "\<lambda>ms. P (device_state ms)"


lemma clearExMonitor_invs [wp]:
  "\<lbrace>invs\<rbrace> do_machine_op clearExMonitor \<lbrace>\<lambda>_. invs\<rbrace>"
  apply (wp dmo_invs)
  apply (clarsimp simp: clearExMonitor_def machine_op_lift_def
                        machine_rest_lift_def in_monad select_f_def)
  done

global_naming Arch

lemma arch_stt_invs [wp,Schedule_AI_asms]:
  "\<lbrace>invs\<rbrace> arch_switch_to_thread t' \<lbrace>\<lambda>_. invs\<rbrace>"
  apply (wpsimp simp: arch_switch_to_thread_def)
  by (rule sym_refs_VCPU_hyp_live; fastforce)


lemma arch_stt_tcb [wp,Schedule_AI_asms]:
  "\<lbrace>tcb_at t'\<rbrace> arch_switch_to_thread t' \<lbrace>\<lambda>_. tcb_at t'\<rbrace>"
  by (wpsimp simp: arch_switch_to_thread_def wp: tcb_at_typ_at)

lemma arch_stt_runnable[Schedule_AI_asms]:
  "\<lbrace>st_tcb_at runnable t\<rbrace> arch_switch_to_thread t \<lbrace>\<lambda>r. st_tcb_at runnable t\<rbrace>"
  by (wpsimp simp: arch_switch_to_thread_def)

lemma idle_strg:
  "thread = idle_thread s \<and> invs s \<Longrightarrow> invs (s\<lparr>cur_thread := thread\<rparr>)"
  by (clarsimp simp: invs_def valid_state_def valid_idle_def cur_tcb_def
                     pred_tcb_at_def valid_machine_state_def obj_at_def is_tcb_def)

lemma set_vcpu_ct[wp]:
  "\<lbrace>\<lambda>s. P (cur_thread s)\<rbrace> set_vcpu v v' \<lbrace>\<lambda>_ s. P (cur_thread s)\<rbrace>"
  by (wpsimp simp: set_vcpu_def wp: get_object_wp)

crunches
  vcpu_update, vgic_update, vgic_update_lr, vcpu_restore_reg_range, vcpu_save_reg_range,
  vcpu_enable, vcpu_disable, vcpu_save, vcpu_restore, vcpu_switch, vcpu_save
  for it[wp]: "\<lambda>s. P (idle_thread s)"
  and ct[wp]: "\<lambda>s. P (cur_thread s)"
  (wp: mapM_x_wp mapM_wp subset_refl)

lemma arch_stit_invs[wp, Schedule_AI_asms]:
  "\<lbrace>invs\<rbrace> arch_switch_to_idle_thread \<lbrace>\<lambda>r. invs\<rbrace>"
  by (wpsimp wp: svr_invs simp: arch_switch_to_idle_thread_def)

lemma arch_stit_tcb_at[wp]:
  "\<lbrace>tcb_at t\<rbrace> arch_switch_to_idle_thread \<lbrace>\<lambda>r. tcb_at t\<rbrace>"
  apply (simp add: arch_switch_to_idle_thread_def )
  apply (wp tcb_at_typ_at)
  done

crunches set_vm_root
  for ct[wp]: "\<lambda>s. P (cur_thread s)"
  and it[wp]: "\<lambda>s. P (idle_thread s)"
  (simp: crunch_simps wp: hoare_drop_imps)

lemma arch_stit_activatable[wp, Schedule_AI_asms]:
  "\<lbrace>ct_in_state activatable\<rbrace> arch_switch_to_idle_thread \<lbrace>\<lambda>rv . ct_in_state activatable\<rbrace>"
  apply (clarsimp simp: arch_switch_to_idle_thread_def)
  apply (wpsimp simp: ct_in_state_def wp: ct_in_state_thread_state_lift)
  done

lemma stit_invs [wp,Schedule_AI_asms]:
  "\<lbrace>invs\<rbrace> switch_to_idle_thread \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: switch_to_idle_thread_def arch_switch_to_idle_thread_def)
  apply (wpsimp|strengthen idle_strg)+
  done

lemma stit_activatable[Schedule_AI_asms]:
  "\<lbrace>invs\<rbrace> switch_to_idle_thread \<lbrace>\<lambda>rv . ct_in_state activatable\<rbrace>"
  apply (simp add: switch_to_idle_thread_def arch_switch_to_idle_thread_def)
  apply (wp | simp add: ct_in_state_def)+
  apply (clarsimp simp: invs_def valid_state_def cur_tcb_def valid_idle_def
                 elim!: pred_tcb_weaken_strongerE)
  done

lemma stt_invs [wp,Schedule_AI_asms]:
  "\<lbrace>invs\<rbrace> switch_to_thread t' \<lbrace>\<lambda>_. invs\<rbrace>"
  apply (simp add: switch_to_thread_def)
  apply wp
     apply (simp add: trans_state_update[symmetric] del: trans_state_update)
    apply (rule_tac Q="\<lambda>_. invs and tcb_at t'" in hoare_strengthen_post, wp)
    apply (clarsimp simp: invs_def valid_state_def valid_idle_def
                          valid_irq_node_def valid_machine_state_def)
    apply (fastforce simp: cur_tcb_def obj_at_def
                     elim: valid_pspace_eqI ifunsafe_pspaceI)
   apply wp+
  apply clarsimp
  apply (simp add: is_tcb_def)
  done
end

interpretation Schedule_AI_U?: Schedule_AI_U
  proof goal_cases
  interpret Arch .
  case 1 show ?case
  by (intro_locales; (unfold_locales; fact Schedule_AI_asms)?)
  qed

interpretation Schedule_AI?: Schedule_AI
  proof goal_cases
  interpret Arch .
  case 1 show ?case
  by (intro_locales; (unfold_locales; fact Schedule_AI_asms)?)
  qed

end
