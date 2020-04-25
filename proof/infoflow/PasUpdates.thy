(*
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)


text \<open>
  Lemmas about updating the external flags of a PAS.
  These flags are: pasSubject, pasMayEditReadyQueues and pasMayActivate.
\<close>

theory PasUpdates
imports
    "Arch_IF"
    "FinalCaps"
    "AInvs.EmptyFail_AI"
begin

context begin interpretation Arch . (*FIXME: arch_split*)

section \<open>Separation lemmas for the idle thread and domain fields\<close>

abbreviation (input) domain_fields
where
  "domain_fields P s \<equiv> P (domain_time s) (domain_index s) (domain_list s)"

lemma preemption_point_domain_fields[wp]:
  "\<lbrace>domain_fields P\<rbrace> preemption_point \<lbrace>\<lambda>_. domain_fields P\<rbrace>"
  by (simp add: preemption_point_def
      | wp OR_choiceE_weak_wp modify_wp
      | wpc
      | simp add: reset_work_units_def update_work_units_def)+

crunch domain_fields[wp]: retype_region_ext,create_cap_ext,cap_insert_ext,ethread_set,
                          cap_move_ext,empty_slot_ext,cap_swap_ext,set_thread_state_ext,
                          tcb_sched_action,reschedule_required,cap_swap_for_delete,
                          finalise_cap,cap_move,cap_swap,cap_delete,cancel_badged_sends,
                          cap_insert
                          "domain_fields P"
  (    wp: syscall_valid select_wp crunch_wps rec_del_preservation cap_revoke_preservation modify_wp
     simp: crunch_simps check_cap_at_def filterM_mapM unless_def
   ignore: without_preemption filterM rec_del check_cap_at cap_revoke
   ignore_del: retype_region_ext create_cap_ext cap_insert_ext ethread_set cap_move_ext
               empty_slot_ext cap_swap_ext set_thread_state_ext tcb_sched_action reschedule_required)

lemma cap_revoke_domain_fields[wp]:"\<lbrace>domain_fields P\<rbrace> cap_revoke a \<lbrace>\<lambda>_. domain_fields P\<rbrace>"
  by (rule cap_revoke_preservation2; wp)

lemma invoke_cnode_domain_fields[wp]: "\<lbrace>domain_fields P\<rbrace> invoke_cnode a \<lbrace>\<lambda>_. domain_fields P\<rbrace>"
  unfolding invoke_cnode_def
  by (wpsimp wp: get_cap_wp hoare_vcg_all_lift hoare_vcg_imp_lift
      | rule conjI)+

crunch domain_fields[wp]:
  set_domain,possible_switch_to,set_priority,set_extra_badge,
  handle_send,handle_recv,handle_reply
  "domain_fields P"
  (wp: syscall_valid crunch_wps mapME_x_inv_wp
   simp: crunch_simps check_cap_at_def detype_def detype_ext_def mapM_x_defsym
   ignore: check_cap_at syscall
   ignore_del: set_domain set_priority possible_switch_to
   rule: transfer_caps_loop_pres)

section \<open>PAS wellformedness property for non-interference\<close>

definition pas_wellformed_noninterference where
  "pas_wellformed_noninterference aag \<equiv>
    (\<forall>l\<in>range (pasObjectAbs aag) \<union> \<Union>(range (pasDomainAbs aag)) - {SilcLabel}.
         pas_wellformed (aag\<lparr> pasSubject := l \<rparr>)) \<and>
    (\<forall>d. SilcLabel \<notin> pasDomainAbs aag d) \<and>
    pas_domains_distinct aag"

lemma pas_wellformed_noninterference_domains_distinct:
  "pas_wellformed_noninterference aag \<Longrightarrow> pas_domains_distinct aag"
  by (simp add: pas_wellformed_noninterference_def)

lemma pas_wellformed_noninterference_silc[intro!]:
  "pas_wellformed_noninterference aag \<Longrightarrow> SilcLabel \<notin> pasDomainAbs aag d"
  apply (fastforce simp: pas_wellformed_noninterference_def)
  done

section \<open>PAS subject update\<close>

lemma pasObjectAbs_pasSubject_update:
  "pasObjectAbs (aag\<lparr> pasSubject := x \<rparr>) = pasObjectAbs aag"
  apply simp
  done

lemma pasASIDAbs_pasSubject_update:
  "pasASIDAbs (aag\<lparr> pasSubject := x \<rparr>) = pasASIDAbs aag"
  apply simp
  done

lemma pasIRQAbs_pasSubject_update:
  "pasIRQAbs (aag\<lparr> pasSubject := x \<rparr>) = pasIRQAbs aag"
  apply simp
  done

lemma state_asids_to_policy_pasSubject_update:
  "state_asids_to_policy_aux (aag\<lparr> pasSubject := x \<rparr>) caps asid vrefs =
   state_asids_to_policy_aux aag caps asid vrefs"
  apply(rule equalityI)
   apply(clarify)
   apply(erule state_asids_to_policy_aux.cases
        |simp
        |fastforce intro: state_asids_to_policy_aux.intros)+
  apply(clarify)
  apply(erule state_asids_to_policy_aux.cases)
   apply(simp,
         subst pasObjectAbs_pasSubject_update[symmetric],
         subst pasASIDAbs_pasSubject_update[symmetric],
         rule state_asids_to_policy_aux.intros, assumption+)+
  done

lemma state_irqs_to_policy_pasSubject_update:
  "state_irqs_to_policy_aux (aag\<lparr> pasSubject := x \<rparr>) caps =
   state_irqs_to_policy_aux aag caps"
  apply(rule equalityI)
   apply(clarify)
   apply(erule state_irqs_to_policy_aux.cases, simp,
         blast intro: state_irqs_to_policy_aux.intros)
  apply(clarify)
  apply(erule state_irqs_to_policy_aux.cases)
  apply(simp)
  apply(subst pasObjectAbs_pasSubject_update[symmetric])
  apply(subst pasIRQAbs_pasSubject_update[symmetric])
  apply(rule state_irqs_to_policy_aux.intros)
   apply assumption+
  done


lemma irq_map_wellformed_pasSubject_update:
  "irq_map_wellformed_aux (aag\<lparr> pasSubject := x \<rparr>) irqn =
   irq_map_wellformed_aux aag irqn"
  by (clarsimp simp: irq_map_wellformed_aux_def)

lemma tcb_domain_map_wellformed_pasSubject_update:
  "tcb_domain_map_wellformed_aux (aag\<lparr> pasSubject := x \<rparr>) irqn =
   tcb_domain_map_wellformed_aux aag irqn"
  by (clarsimp simp: tcb_domain_map_wellformed_aux_def)

lemma pas_refined_pasSubject_update':
   "\<lbrakk>pas_refined aag s; pas_wellformed (aag\<lparr> pasSubject := x \<rparr>)\<rbrakk> \<Longrightarrow>
   pas_refined (aag\<lparr> pasSubject := x \<rparr>) s"
  apply(subst pas_refined_def)
  apply(safe del: subsetI)
      apply (simp add: irq_map_wellformed_pasSubject_update pas_refined_def)
     apply (simp add: tcb_domain_map_wellformed_pasSubject_update pas_refined_def)
    apply (clarsimp simp: pas_refined_def)
   apply(fastforce intro: pas_refined_asid_mem simp: state_asids_to_policy_pasSubject_update)
  apply(fastforce simp: pas_refined_def state_irqs_to_policy_pasSubject_update)
  done

lemma pas_wellformed_pasSubject_update:
  "\<lbrakk>pas_wellformed_noninterference aag; l \<in> pasDomainAbs aag d\<rbrakk> \<Longrightarrow>
   pas_wellformed (aag\<lparr>pasSubject := l\<rparr>)"
  by (auto simp: pas_wellformed_noninterference_def)

lemmas pas_refined_pasSubject_update =
                   pas_refined_pasSubject_update'[OF _ pas_wellformed_pasSubject_update]

lemma guarded_pas_domain_pasSubject_update[simp]:
  "guarded_pas_domain (aag\<lparr>pasSubject := x\<rparr>) s = guarded_pas_domain aag s"
  by (simp add: guarded_pas_domain_def)


lemma silc_inv_pasSubject_update':
  "\<lbrakk>silc_inv aag st s; x \<noteq> SilcLabel\<rbrakk> \<Longrightarrow> silc_inv (aag\<lparr>pasSubject := x\<rparr>) st s"
  by (auto simp: silc_inv_def silc_dom_equiv_def intra_label_cap_def cap_points_to_label_def)

lemma silc_inv_pasSubject_update:
  "\<lbrakk>silc_inv aag st s; pas_wellformed_noninterference aag; l \<in> pasDomainAbs aag d\<rbrakk>
   \<Longrightarrow> silc_inv (aag\<lparr>pasSubject := l\<rparr>) st s"
  apply (fastforce intro: silc_inv_pasSubject_update' dest: pas_wellformed_noninterference_silc)
  done

section \<open>PAS MayActivate update\<close>

lemma prop_of_pasMayActivate_update_idemp:
  "\<lbrakk>P aag; pasMayActivate aag = v\<rbrakk> \<Longrightarrow> P (aag\<lparr> pasMayActivate := v \<rparr>)"
  by (hypsubst, auto)

lemma pasObjectAbs_pasMayActivate_update:
  "pasObjectAbs (aag\<lparr> pasMayActivate := x \<rparr>) = pasObjectAbs aag"
  by simp

lemma pasASIDAbs_pasMayActivate_update:
  "pasASIDAbs (aag\<lparr> pasMayActivate := x \<rparr>) = pasASIDAbs aag"
  by simp

lemma pasIRQAbs_pasMayActivate_update:
  "pasIRQAbs (aag\<lparr> pasMayActivate := x \<rparr>) = pasIRQAbs aag"
  by simp

lemma state_asids_to_policy_pasMayActivate_update:
  "state_asids_to_policy (aag\<lparr> pasMayActivate := x \<rparr>) s =
   state_asids_to_policy aag s"
  apply(rule equalityI)
   apply(clarify)
   apply(erule state_asids_to_policy_aux.cases
        |simp
        |fastforce intro: state_asids_to_policy_aux.intros)+
  apply(clarify)
  apply(erule state_asids_to_policy_aux.cases)
   apply(simp,
         subst pasObjectAbs_pasMayActivate_update[symmetric],
         subst pasASIDAbs_pasMayActivate_update[symmetric],
         rule state_asids_to_policy_aux.intros, assumption+)+
  done

lemma state_irqs_to_policy_pasMayActivate_update:
  "state_irqs_to_policy (aag\<lparr> pasMayActivate := x \<rparr>) s =
   state_irqs_to_policy aag s"
  apply(rule equalityI)
   apply(clarify)
   apply(erule state_irqs_to_policy_aux.cases
        |simp
        |fastforce intro: state_irqs_to_policy_aux.intros)+
  apply(clarify)
  apply(erule state_irqs_to_policy_aux.cases)
   apply(simp,
         subst pasObjectAbs_pasMayActivate_update[symmetric],
         subst pasIRQAbs_pasMayActivate_update[symmetric],
         rule state_irqs_to_policy_aux.intros, assumption+)+
  done

lemma pas_refined_pasMayActivate_update:
  "pas_refined aag s \<Longrightarrow>
   pas_refined (aag\<lparr> pasMayActivate := x \<rparr>) s"
  apply(simp add: pas_refined_def)
  apply(clarsimp simp: irq_map_wellformed_aux_def state_asids_to_policy_pasMayActivate_update
                       state_irqs_to_policy_pasMayActivate_update tcb_domain_map_wellformed_aux_def)
  done

lemma guarded_pas_domainMayActivate_update[simp]:
  "guarded_pas_domain (aag\<lparr>pasMayActivate := False\<rparr>) = guarded_pas_domain aag"
  by (simp add: guarded_pas_domain_def)

lemma cdt_change_allowedMayActivate_update[simp]:
  "cdt_change_allowed (aag\<lparr>pasMayActivate := x\<rparr>) =
   cdt_change_allowed aag "
  by (simp add: cdt_change_allowed_def[abs_def] cdt_direct_change_allowed.simps direct_call_def)

section \<open>PAS MayEditReadyQueue update\<close>

lemma prop_of_pasMayEditReadyQueues_update_idemp:
  "\<lbrakk>P aag; pasMayEditReadyQueues aag = v\<rbrakk> \<Longrightarrow> P (aag\<lparr> pasMayEditReadyQueues := v \<rparr>)"
  by clarsimp

lemma pasObjectAbs_pasMayEditReadyQueues_update:
  "pasObjectAbs (aag\<lparr> pasMayEditReadyQueues := x \<rparr>) = pasObjectAbs aag"
  by simp

lemma pasASIDAbs_pasMayEditReadyQueues_update:
  "pasASIDAbs (aag\<lparr> pasMayEditReadyQueues := x \<rparr>) = pasASIDAbs aag"
  by simp

lemma pasIRQAbs_pasMayEditReadyQueues_update:
  "pasIRQAbs (aag\<lparr> pasMayEditReadyQueues := x \<rparr>) = pasIRQAbs aag"
  by simp

lemma state_asids_to_policy_pasMayEditReadyQueues_update:
  "state_asids_to_policy (aag\<lparr> pasMayEditReadyQueues := x \<rparr>) s =
   state_asids_to_policy aag s"
  apply(rule equalityI)
   apply(clarify)
   apply(erule state_asids_to_policy_aux.cases
        |simp
        |fastforce intro: state_asids_to_policy_aux.intros)+
  apply(clarify)
  apply(erule state_asids_to_policy_aux.cases)
   apply(simp,
         subst pasObjectAbs_pasMayEditReadyQueues_update[symmetric],
         subst pasASIDAbs_pasMayEditReadyQueues_update[symmetric],
         rule state_asids_to_policy_aux.intros, assumption+)+
  done

lemma state_irqs_to_policy_pasMayEditReadyQueues_update:
  "state_irqs_to_policy (aag\<lparr> pasMayEditReadyQueues := x \<rparr>) s =
   state_irqs_to_policy aag s"
  apply(rule equalityI)
   apply(clarify)
   apply(erule state_irqs_to_policy_aux.cases
        |simp
        |fastforce intro: state_irqs_to_policy_aux.intros)+
  apply(clarify)
  apply(erule state_irqs_to_policy_aux.cases)
   apply(simp,
         subst pasObjectAbs_pasMayEditReadyQueues_update[symmetric],
         subst pasIRQAbs_pasMayEditReadyQueues_update[symmetric],
         rule state_irqs_to_policy_aux.intros, assumption+)+
  done

lemma pas_refined_pasMayEditReadyQueues_update:
  "pas_refined aag s \<Longrightarrow>
   pas_refined (aag\<lparr> pasMayEditReadyQueues := x \<rparr>) s"
  apply(simp add: pas_refined_def)
  apply(clarsimp simp: irq_map_wellformed_aux_def
                       state_asids_to_policy_pasMayEditReadyQueues_update
                       state_irqs_to_policy_pasMayEditReadyQueues_update
                       tcb_domain_map_wellformed_aux_def)
  done

lemma guarded_pas_domainMayEditReadyQueues_update[simp]:
  "guarded_pas_domain (aag\<lparr>pasMayEditReadyQueues := False\<rparr>) = guarded_pas_domain aag"
  by (simp add: guarded_pas_domain_def)

lemma cdt_change_allowedMayEditReadyQueues_update[simp]:
  "cdt_change_allowed (aag\<lparr>pasMayEditReadyQueues := x\<rparr>) =
   cdt_change_allowed aag"
  by (simp add: cdt_change_allowed_def[abs_def] cdt_direct_change_allowed.simps direct_call_def)

end

end
