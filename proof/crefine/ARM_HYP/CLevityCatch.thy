(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

theory CLevityCatch
imports
  "../Include_C"
  ArchMove_C
  "CLib.LemmaBucket_C"
  "Lib.LemmaBucket"
begin

context begin interpretation Arch . (*FIXME: arch_split*)

declare word_neq_0_conv [simp del]

(* Rule previously in the simpset, now not. *)
declare ptr_add_def' [simp]

(* works much better *)
lemmas typ_heap_simps' = typ_heap_simps c_guard_clift

lemmas asUser_return = submonad.return [OF submonad_asUser]

lemmas asUser_bind_distrib =
  submonad_bind [OF submonad_asUser submonad_asUser submonad_asUser]

lemma ntfnQueue_head_mask_4 :
  "ntfnQueue_head_CL (notification_lift ko') && ~~ mask 4 = ntfnQueue_head_CL (notification_lift ko')"
  unfolding notification_lift_def
  by (clarsimp simp: mask_def word_bw_assocs)

(* Levity: moved from Ipc_C (20090419 09:44:31) *) (* and remove from Syscall_C *)
lemma empty_fail_doMachineOp[intro!]:
  "empty_fail m \<Longrightarrow> empty_fail (doMachineOp m)"
  by (rule ef_dmo')

(* Levity: moved from Ipc_C (20090419 09:44:31) *) (* why isn't this in Kernel_C? *)
lemmas C_register_defs =
  Kernel_C.R0_def Kernel_C.R1_def Kernel_C.R2_def Kernel_C.R3_def
  Kernel_C.R4_def Kernel_C.R5_def Kernel_C.R6_def Kernel_C.R7_def
  Kernel_C.R8_def Kernel_C.R9_def Kernel_C.R10_def Kernel_C.R11_def
  Kernel_C.R12_def Kernel_C.SP_def Kernel_C.LR_def Kernel_C.NextIP_def
  Kernel_C.CPSR_def Kernel_C.TLS_BASE_def Kernel_C.TPIDRURW_def
  Kernel_C.FaultIP_def

(* Levity: moved from Retype_C (20090419 09:44:41) *)
lemma no_overlap_new_cap_addrs_disjoint:
  "\<lbrakk> range_cover ptr sz (objBitsKO ko) n;
     pspace_aligned' s;
     pspace_no_overlap' ptr sz s \<rbrakk> \<Longrightarrow>
   set (new_cap_addrs n ptr ko) \<inter> dom (ksPSpace s) = {}"
  apply (erule disjoint_subset [OF new_cap_addrs_subset, where sz1=sz])
  apply (clarsimp simp: Word_Lib.ptr_add_def field_simps)
  apply (rule pspace_no_overlap_disjoint')
  apply auto
  done

declare empty_fail_doMachineOp [simp]

lemma empty_fail_loadWordUser[intro!, simp]:
  "empty_fail (loadWordUser x)"
  by (simp add: loadWordUser_def ef_loadWord)

lemma empty_fail_getMRs[iff]:
  "empty_fail (getMRs t buf mi)"
  by (auto simp add: getMRs_def split: option.split)

lemma empty_fail_getExtraCPtrs [intro!, simp]:
  "empty_fail (getExtraCPtrs sendBuffer info)"
  apply (simp add: getExtraCPtrs_def)
  apply (cases info, simp)
  apply (cases sendBuffer, simp_all)
  done

lemma empty_fail_loadCapTransfer [intro!, simp]:
  "empty_fail (loadCapTransfer a)"
  by (simp add: loadCapTransfer_def capTransferFromWords_def)

lemma empty_fail_emptyOnFailure [intro!, simp]:
  "empty_fail m \<Longrightarrow> empty_fail (emptyOnFailure m)"
  by (auto simp: emptyOnFailure_def catch_def split: sum.splits)

lemma empty_fail_unifyFailure [intro!, simp]:
  "empty_fail m \<Longrightarrow> empty_fail (unifyFailure m)"
  by (auto simp: unifyFailure_def catch_def rethrowFailure_def
                 handleE'_def throwError_def
           split: sum.splits)

lemma asUser_get_registers:
  "\<lbrace>tcb_at' target\<rbrace>
     asUser target (mapM getRegister xs)
   \<lbrace>\<lambda>rv s. obj_at' (\<lambda>tcb. map ((atcbContextGet o tcbArch) tcb) xs = rv) target s\<rbrace>"
  apply (induct xs)
   apply (simp add: mapM_empty asUser_return)
   apply wp
   apply simp
  apply (simp add: mapM_Cons asUser_bind_distrib asUser_return)
  apply wp
   apply simp
   apply (rule hoare_strengthen_post)
    apply (erule hoare_vcg_conj_lift)
    apply (rule asUser_inv)
    apply (simp add: getRegister_def)
    apply (wp mapM_wp')
   apply clarsimp
   apply (erule(1) obj_at_conj')
  apply (wp)
   apply (simp add: asUser_def split_def threadGet_def)
   apply (wp getObject_tcb_wp)
  apply (clarsimp simp: getRegister_def simpler_gets_def
                        obj_at'_def)
  done


lemma projectKO_user_data_device:
  "(projectKO_opt ko = Some (t :: user_data_device)) = (ko = KOUserDataDevice)"
  by (cases ko)
     (auto simp: projectKO_opts_defs split: arch_kernel_object.splits)

lemma empty_fail_getReceiveSlots:
  "empty_fail (getReceiveSlots r rbuf)"
proof -
  note
    empty_fail_assertE[iff]
    empty_fail_resolveAddressBits[iff]
  show ?thesis
  apply (clarsimp simp: getReceiveSlots_def loadCapTransfer_def split_def
                 split: option.split)
  apply (rule empty_fail_bind)
   apply (simp add: capTransferFromWords_def)
  apply (simp add: emptyOnFailure_def unifyFailure_def)
  apply (intro empty_fail_catch empty_fail_bindE empty_fail_rethrowFailure,
         simp_all add: empty_fail_whenEs)
   apply (simp_all add: lookupCap_def split_def lookupCapAndSlot_def
                        lookupSlotForThread_def liftME_def
                        getThreadCSpaceRoot_def locateSlot_conv bindE_assoc
                        lookupSlotForCNodeOp_def lookupErrorOnFailure_def
                  cong: if_cong)
   apply (intro empty_fail_bindE,
          simp_all add: getSlotCap_def)
  apply (intro empty_fail_If empty_fail_bindE empty_fail_rethrowFailure impI,
         simp_all add: empty_fail_whenEs rangeCheck_def)
  done
qed

lemma exec_Basic_Guard_UNIV:
  "Semantic.exec \<Gamma> (Basic f;; Guard F UNIV (Basic g)) x y =
   Semantic.exec \<Gamma> (Basic (g o f)) x y"
  apply (rule iffI)
   apply (elim exec_elim_cases, simp_all, clarsimp)[1]
   apply (simp add: o_def, rule exec.Basic)
  apply (elim exec_elim_cases)
  apply simp_all
  apply (rule exec_Seq' exec.Basic exec.Guard | simp)+
  done

end

definition
  "option_to_ptr \<equiv> Ptr o option_to_0"

lemma option_to_ptr_simps [simp]:
  "option_to_ptr None = NULL"
  "option_to_ptr (Some x) = Ptr x"
  by (auto simp: option_to_ptr_def split: option.split)

(* FIXME MOVE *)
lemma option_to_ptr_NULL_eq:
  "\<lbrakk> option_to_ptr p = p' \<rbrakk> \<Longrightarrow> (p' = NULL) = (p = None \<or> p = Some 0)"
  unfolding option_to_ptr_def option_to_0_def
  by (clarsimp split: option.splits)

lemma option_to_ptr_not_0:
  "\<lbrakk> p \<noteq> 0 ; option_to_ptr v = Ptr p \<rbrakk> \<Longrightarrow> v = Some p"
  by (clarsimp simp: option_to_ptr_def option_to_0_def split: option.splits)

end
