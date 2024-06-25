(*
 * Copyright 2021, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

theory InvariantUpdates_H
imports Invariants_H
begin

(* FIXME: use locales to shorten this work *)

lemma ps_clear_domE[elim?]:
  "\<lbrakk> ps_clear x n s; dom (ksPSpace s) = dom (ksPSpace s') \<rbrakk> \<Longrightarrow> ps_clear x n s'"
  by (simp add: ps_clear_def)

lemma ps_clear_upd:
  "ksPSpace s y = Some v \<Longrightarrow>
    ps_clear x n (ksPSpace_update (\<lambda>a. (ksPSpace s)(y \<mapsto> v')) s') = ps_clear x n s"
  by (rule iffI | clarsimp elim!: ps_clear_domE | fastforce)+

lemmas ps_clear_updE[elim] = iffD2[OF ps_clear_upd, rotated]

lemma ct_not_inQ_ksMachineState_update[simp]:
  "ct_not_inQ (ksMachineState_update f s) = ct_not_inQ s"
  by (simp add: ct_not_inQ_def)

lemma ct_in_current_domain_ksMachineState[simp]:
  "ct_idle_or_in_cur_domain' (ksMachineState_update p s) = ct_idle_or_in_cur_domain' s"
  by (simp add: ct_idle_or_in_cur_domain'_def tcb_in_cur_domain'_def)

lemma invs'_machine:
  assumes mask: "irq_masks (f (ksMachineState s)) =
                 irq_masks (ksMachineState s)"
  assumes vms: "valid_machine_state' (ksMachineState_update f s) =
                valid_machine_state' s"
  shows "invs' (ksMachineState_update f s) = invs' s"
proof -
  show ?thesis
    apply (cases "ksSchedulerAction s")
    apply (simp_all add: invs'_def valid_state'_def cur_tcb'_def ct_in_state'_def
                    ct_idle_or_in_cur_domain'_def tcb_in_cur_domain'_def
                    valid_bitmaps_def bitmapQ_defs
                    vms ct_not_inQ_def
                    state_refs_of'_def ps_clear_def
                    valid_irq_node'_def mask
              cong: option.case_cong)
    done
qed

lemma invs_no_cicd'_machine:
  assumes mask: "irq_masks (f (ksMachineState s)) =
                 irq_masks (ksMachineState s)"
  assumes vms: "valid_machine_state' (ksMachineState_update f s) =
                valid_machine_state' s"
  shows "invs_no_cicd' (ksMachineState_update f s) = invs_no_cicd' s"
proof -
  show ?thesis
    apply (cases "ksSchedulerAction s")
    apply (simp_all add: all_invs_but_ct_idle_or_in_cur_domain'_def valid_state'_def
                         cur_tcb'_def ct_in_state'_def ct_idle_or_in_cur_domain'_def
                         tcb_in_cur_domain'_def valid_bitmaps_def bitmapQ_defs
                         vms ct_not_inQ_def
                         state_refs_of'_def ps_clear_def
                         valid_irq_node'_def mask
                   cong: option.case_cong)
    done
qed

lemma pspace_no_overlap_queues [simp]:
  "pspace_no_overlap' w sz (ksReadyQueues_update f s) = pspace_no_overlap' w sz s"
  by (simp add: pspace_no_overlap'_def)

lemma pspace_no_overlap'_ksSchedulerAction[simp]:
  "pspace_no_overlap' a b (ksSchedulerAction_update f s) =
   pspace_no_overlap' a b s"
  by (simp add: pspace_no_overlap'_def)

lemma ksReadyQueues_update_id[simp]:
  "ksReadyQueues_update id s = s"
  by simp

lemma ct_not_inQ_ksReadyQueues_update[simp]:
  "ct_not_inQ (ksReadyQueues_update f s) = ct_not_inQ s"
  by (simp add: ct_not_inQ_def)

lemma inQ_context[simp]:
  "inQ d p (tcbArch_update f tcb) = inQ d p tcb"
  by (cases tcb, simp add: inQ_def)

lemma valid_tcb'_tcbQueued[simp]:
  "valid_tcb' (tcbQueued_update f tcb) = valid_tcb' tcb"
  by (cases tcb, rule ext, simp add: valid_tcb'_def tcb_cte_cases_def cteSizeBits_def)

lemma valid_tcb'_tcbFault_update[simp]:
  "valid_tcb' tcb s \<Longrightarrow> valid_tcb' (tcbFault_update f tcb) s"
  by (clarsimp simp: valid_tcb'_def  tcb_cte_cases_def cteSizeBits_def)

lemma valid_tcb'_tcbTimeSlice_update[simp]:
  "valid_tcb' (tcbTimeSlice_update f tcb) s = valid_tcb' tcb s"
  by (simp add:valid_tcb'_def tcb_cte_cases_def cteSizeBits_def)

lemma valid_bitmaps_ksSchedulerAction_update[simp]:
   "valid_bitmaps (ksSchedulerAction_update f s) = valid_bitmaps s"
   by (simp add: valid_bitmaps_def bitmapQ_defs)

lemma ex_cte_cap_wp_to'_gsCNodes_update[simp]:
  "ex_cte_cap_wp_to' P p (gsCNodes_update f s') = ex_cte_cap_wp_to' P p s'"
  by (simp add: ex_cte_cap_wp_to'_def)
lemma ex_cte_cap_wp_to'_gsUserPages_update[simp]:
  "ex_cte_cap_wp_to' P p (gsUserPages_update f s') = ex_cte_cap_wp_to' P p s'"
  by (simp add: ex_cte_cap_wp_to'_def)

lemma pspace_no_overlap'_gsCNodes_update[simp]:
  "pspace_no_overlap' p b (gsCNodes_update f s') = pspace_no_overlap' p b s'"
  by (simp add: pspace_no_overlap'_def)

lemma pspace_no_overlap'_gsUserPages_update[simp]:
  "pspace_no_overlap' p b (gsUserPages_update f s') = pspace_no_overlap' p b s'"
  by (simp add: pspace_no_overlap'_def)

lemma pspace_no_overlap'_ksMachineState_update[simp]:
  "pspace_no_overlap' p n (ksMachineState_update f s) =
   pspace_no_overlap' p n s"
  by (simp add: pspace_no_overlap'_def)

lemma pspace_no_overlap_gsUntypedZeroRanges[simp]:
  "pspace_no_overlap' ptr n (gsUntypedZeroRanges_update f s)
    = pspace_no_overlap' ptr n s"
  by (simp add: pspace_no_overlap'_def)

lemma vms'_ct[simp]:
  "valid_machine_state' (ksCurThread_update f s) = valid_machine_state' s"
  by (simp add: valid_machine_state'_def)

lemma tcb_in_cur_domain_ct[simp]:
  "tcb_in_cur_domain' t  (ksCurThread_update f s) = tcb_in_cur_domain' t s"
  by (fastforce simp: tcb_in_cur_domain'_def)

lemma valid_bitmaps_ksCurDomain[simp]:
  "valid_bitmaps (ksCurDomain_update f s) = valid_bitmaps s"
  by (simp add: valid_bitmaps_def bitmapQ_defs)

lemma valid_bitmaps_ksDomScheduleIdx[simp]:
  "valid_bitmaps (ksDomScheduleIdx_update f s) = valid_bitmaps s"
  by (simp add: valid_bitmaps_def bitmapQ_defs)

lemma valid_bitmaps_ksDomSchedule[simp]:
   "valid_bitmaps (ksDomSchedule_update f s) = valid_bitmaps s"
   by (simp add: valid_bitmaps_def bitmapQ_defs)

lemma valid_bitmaps_ksDomainTime[simp]:
  "valid_bitmaps (ksDomainTime_update f s) = valid_bitmaps s"
  by (simp add: valid_bitmaps_def bitmapQ_defs)

lemma valid_bitmaps_ksWorkUnitsCompleted[simp]:
  "valid_bitmaps (ksWorkUnitsCompleted_update f s) = valid_bitmaps s"
  by (simp add: valid_bitmaps_def bitmapQ_defs)

lemma valid_irq_node'_ksCurDomain[simp]:
  "valid_irq_node' w (ksCurDomain_update f s) = valid_irq_node' w s"
  by (simp add: valid_irq_node'_def)

lemma valid_irq_node'_ksDomScheduleIdx[simp]:
  "valid_irq_node' w (ksDomScheduleIdx_update f s) = valid_irq_node' w s"
  by (simp add: valid_irq_node'_def)

lemma valid_irq_node'_ksDomSchedule[simp]:
  "valid_irq_node' w (ksDomSchedule_update f s) = valid_irq_node' w s"
  by (simp add: valid_irq_node'_def)

lemma valid_irq_node'_ksDomainTime[simp]:
  "valid_irq_node' w (ksDomainTime_update f s) = valid_irq_node' w s"
  by (simp add: valid_irq_node'_def)

lemma valid_irq_node'_ksWorkUnitsCompleted[simp]:
  "valid_irq_node' w (ksWorkUnitsCompleted_update f s) = valid_irq_node' w s"
  by (simp add: valid_irq_node'_def)

lemma ex_cte_cap_wp_to_work_units[simp]:
  "ex_cte_cap_wp_to' P slot (ksWorkUnitsCompleted_update f s)
    = ex_cte_cap_wp_to' P slot s"
  by (simp add: ex_cte_cap_wp_to'_def)

add_upd_simps "ct_in_state' P (gsUntypedZeroRanges_update f s)"
declare upd_simps[simp]

lemma ct_not_inQ_ksArchState_update[simp]:
  "ct_not_inQ (ksArchState_update f s) = ct_not_inQ s"
  by (simp add: ct_not_inQ_def)

lemma ct_in_current_domain_ArchState_update[simp]:
  "ct_idle_or_in_cur_domain' (ksArchState_update f s) = ct_idle_or_in_cur_domain' s"
  by (simp add: ct_idle_or_in_cur_domain'_def tcb_in_cur_domain'_def)

lemma pspace_no_overlap_queuesL1 [simp]:
  "pspace_no_overlap' w sz (ksReadyQueuesL1Bitmap_update f s) = pspace_no_overlap' w sz s"
  by (simp add: pspace_no_overlap'_def)

lemma pspace_no_overlap_queuesL2 [simp]:
  "pspace_no_overlap' w sz (ksReadyQueuesL2Bitmap_update f s) = pspace_no_overlap' w sz s"
  by (simp add: pspace_no_overlap'_def)

lemma tcb_in_cur_domain'_ksSchedulerAction_update[simp]:
  "tcb_in_cur_domain' t (ksSchedulerAction_update f s) = tcb_in_cur_domain' t s"
  by (simp add: tcb_in_cur_domain'_def)

lemma ct_idle_or_in_cur_domain'_ksSchedulerAction_update[simp]:
  "b \<noteq> ResumeCurrentThread \<Longrightarrow>
   ct_idle_or_in_cur_domain' (s\<lparr>ksSchedulerAction := b\<rparr>)"
  apply (clarsimp simp add: ct_idle_or_in_cur_domain'_def)
  done

lemma sch_act_simple_wu [simp, intro!]:
  "sch_act_simple (ksWorkUnitsCompleted_update f s) = sch_act_simple s"
  by (simp add: sch_act_simple_def)

lemma sch_act_simple_ksPSpace_update[simp]:
  "sch_act_simple (ksPSpace_update f s) = sch_act_simple s"
  apply (simp add: sch_act_simple_def)
  done

lemma ps_clear_ksReadyQueue[simp]:
  "ps_clear x n (ksReadyQueues_update f s) = ps_clear x n s"
  by (simp add: ps_clear_def)

lemma inQ_tcbIPCBuffer_update_idem[simp]:
  "inQ d p (tcbIPCBuffer_update f ko) = inQ d p ko"
  by (clarsimp simp: inQ_def)

lemma valid_mdb_interrupts'[simp]:
  "valid_mdb' (ksInterruptState_update f s) = valid_mdb' s"
  by (simp add: valid_mdb'_def)

lemma valid_mdb'_ksReadyQueues_update[simp]:
  "valid_mdb' (ksReadyQueues_update f s) = valid_mdb' s"
  by (simp add: valid_mdb'_def)

lemma vms_ksReadyQueues_update[simp]:
  "valid_machine_state' (ksReadyQueues_update f s) = valid_machine_state' s"
  by (simp add: valid_machine_state'_def)

lemma ct_in_state'_ksMachineState_update[simp]:
  "ct_in_state' x (ksMachineState_update f s) = ct_in_state' x s"
  by (simp add: ct_in_state'_def)+

lemma ex_cte_cap_wp_to'_ksMachineState_update[simp]:
  "ex_cte_cap_wp_to' x y (ksMachineState_update f s) = ex_cte_cap_wp_to' x y s"
  by (simp add: ex_cte_cap_wp_to'_def)+

lemma ps_clear_ksMachineState_update[simp]:
  "ps_clear a b (ksMachineState_update f s) = ps_clear a b s"
  by (simp add: ps_clear_def)

lemma ct_in_state_ksSched[simp]:
  "ct_in_state' P (ksSchedulerAction_update f s) = ct_in_state' P s"
  unfolding ct_in_state'_def
  apply auto
  done

lemma invs'_wu [simp]:
  "invs' (ksWorkUnitsCompleted_update f s) = invs' s"
  apply (simp add: invs'_def cur_tcb'_def valid_state'_def valid_bitmaps_def
                   valid_irq_node'_def valid_machine_state'_def
                   ct_not_inQ_def ct_idle_or_in_cur_domain'_def tcb_in_cur_domain'_def
                   bitmapQ_defs)
  done

lemma valid_arch_state'_interrupt[simp]:
  "valid_arch_state' (ksInterruptState_update f s) = valid_arch_state' s"
  by (simp add: valid_arch_state'_def cong: option.case_cong)

lemma valid_bitmapQ_ksSchedulerAction_upd[simp]:
  "valid_bitmapQ (ksSchedulerAction_update f s) = valid_bitmapQ s"
  unfolding bitmapQ_defs by simp

lemma bitmapQ_no_L1_orphans_ksSchedulerAction_upd[simp]:
  "bitmapQ_no_L1_orphans (ksSchedulerAction_update f s) = bitmapQ_no_L1_orphans s"
  unfolding bitmapQ_defs by simp

lemma bitmapQ_no_L2_orphans_ksSchedulerAction_upd[simp]:
  "bitmapQ_no_L2_orphans (ksSchedulerAction_update f s) = bitmapQ_no_L2_orphans s"
  unfolding bitmapQ_defs by simp

lemma cur_tcb'_ksReadyQueuesL1Bitmap_upd[simp]:
  "cur_tcb' (ksReadyQueuesL1Bitmap_update f s) = cur_tcb' s"
  unfolding cur_tcb'_def by simp

lemma cur_tcb'_ksReadyQueuesL2Bitmap_upd[simp]:
  "cur_tcb' (ksReadyQueuesL2Bitmap_update f s) = cur_tcb' s"
  unfolding cur_tcb'_def by simp

lemma ex_cte_cap_wp_to'_ksReadyQueuesL1Bitmap[simp]:
   "ex_cte_cap_wp_to' P p (ksReadyQueuesL1Bitmap_update f s) = ex_cte_cap_wp_to' P p s"
   unfolding ex_cte_cap_wp_to'_def by simp

lemma ex_cte_cap_wp_to'_ksReadyQueuesL2Bitmap[simp]:
   "ex_cte_cap_wp_to' P p (ksReadyQueuesL2Bitmap_update f s) = ex_cte_cap_wp_to' P p s"
   unfolding ex_cte_cap_wp_to'_def by simp

lemma sch_act_simple_readyQueue[simp]:
  "sch_act_simple (ksReadyQueues_update f s) = sch_act_simple s"
  apply (simp add: sch_act_simple_def)
  done

lemma sch_act_simple_ksReadyQueuesL1Bitmap[simp]:
  "sch_act_simple (ksReadyQueuesL1Bitmap_update f s) = sch_act_simple s"
  apply (simp add: sch_act_simple_def)
  done

lemma sch_act_simple_ksReadyQueuesL2Bitmap[simp]:
  "sch_act_simple (ksReadyQueuesL2Bitmap_update f s) = sch_act_simple s"
  apply (simp add: sch_act_simple_def)
  done

lemma ksDomainTime_invs[simp]:
  "invs' (ksDomainTime_update f s) = invs' s"
  by (simp add: invs'_def valid_state'_def cur_tcb'_def ct_not_inQ_def ct_idle_or_in_cur_domain'_def
                tcb_in_cur_domain'_def valid_machine_state'_def bitmapQ_defs)

lemma valid_machine_state'_ksDomainTime[simp]:
  "valid_machine_state' (ksDomainTime_update f s) = valid_machine_state' s"
  by (simp add:valid_machine_state'_def)

lemma cur_tcb'_ksDomainTime[simp]:
  "cur_tcb' (ksDomainTime_update f s) = cur_tcb' s"
  by (simp add:cur_tcb'_def)

lemma ct_idle_or_in_cur_domain'_ksDomainTime[simp]:
  "ct_idle_or_in_cur_domain' (ksDomainTime_update f s) = ct_idle_or_in_cur_domain' s"
  by (simp add:ct_idle_or_in_cur_domain'_def tcb_in_cur_domain'_def)

lemma sch_act_sane_ksMachineState[simp]:
  "sch_act_sane (ksMachineState_update f s) = sch_act_sane s"
  by (simp add: sch_act_sane_def)

lemma ct_not_inQ_update_cnt[simp]:
  "ct_not_inQ (s\<lparr>ksSchedulerAction := ChooseNewThread\<rparr>)"
   by (simp add: ct_not_inQ_def)

lemma ct_not_inQ_update_stt[simp]:
  "ct_not_inQ (s\<lparr>ksSchedulerAction := SwitchToThread t\<rparr>)"
   by (simp add: ct_not_inQ_def)

lemma invs'_update_cnt[elim!]:
  "invs' s \<Longrightarrow> invs' (s\<lparr>ksSchedulerAction := ChooseNewThread\<rparr>)"
   by (clarsimp simp: invs'_def valid_state'_def valid_queues_def valid_irq_node'_def cur_tcb'_def
                      ct_idle_or_in_cur_domain'_def tcb_in_cur_domain'_def bitmapQ_defs)

end