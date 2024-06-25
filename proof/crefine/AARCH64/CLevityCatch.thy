(*
 * Copyright 2023, Proofcraft Pty Ltd
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

theory CLevityCatch
imports
  "CBaseRefine.Include_C"
  ArchMove_C
  "CParser.LemmaBucket_C"
  "Lib.LemmaBucket"
  Boolean_C
begin

(* FIXME AARCH64: holding area for things to move to CParser/TypHeapLib or higher.
                  Check other architectures for use. *)

lemma lift_t_Some_iff:
  "lift_t g hrs p = Some v \<longleftrightarrow> hrs_htd hrs, g \<Turnstile>\<^sub>t p \<and> h_val (hrs_mem hrs) p = v"
  unfolding hrs_htd_def hrs_mem_def by (cases hrs) (auto simp: lift_t_if)

context
  fixes p :: "'a::mem_type ptr"
  fixes q :: "'b::c_type ptr"
  fixes d g\<^sub>p g\<^sub>q
  assumes val_p: "d,g\<^sub>p \<Turnstile>\<^sub>t p"
  assumes val_q: "d,g\<^sub>q \<Turnstile>\<^sub>t q"
  assumes disj: "typ_uinfo_t TYPE('a) \<bottom>\<^sub>t typ_uinfo_t TYPE('b)"
begin

lemma h_val_heap_same_typ_disj:
  "h_val (heap_update p v h) q = h_val h q"
  using disj by (auto intro: h_val_heap_same[OF val_p val_q]
                       simp: tag_disj_def sub_typ_proper_def field_of_t_def typ_tag_lt_def
                             field_of_def typ_tag_le_def)

lemma h_val_heap_same_hrs_mem_update_typ_disj:
  "h_val (hrs_mem (hrs_mem_update (heap_update p v) s)) q = h_val (hrs_mem s) q"
  by (simp add: hrs_mem_update h_val_heap_same_typ_disj)

end

lemmas h_t_valid_nested_fields =
  h_t_valid_field[OF h_t_valid_field[OF h_t_valid_field]]
  h_t_valid_field[OF h_t_valid_field]
  h_t_valid_field

lemmas h_t_valid_fields_clift =
  h_t_valid_nested_fields[OF h_t_valid_clift]
  h_t_valid_clift

lemma aligned_intvl_0:
  "\<lbrakk> is_aligned p n; n < LENGTH('a) \<rbrakk> \<Longrightarrow>  (0 \<in> {p..+2^n}) = (p = 0)" for p::"'a::len word"
  apply (rule iffI; clarsimp simp: intvl_def)
   apply (drule_tac d="of_nat k" in is_aligned_add_or)
    apply (simp add: word_less_nat_alt unat_of_nat order_le_less_trans[rotated])
   apply word_eqI_solve
  apply (rule_tac x=0 in exI)
  apply simp
  done

lemma heap_list_h_eq_better: (* FIXME AARCH64: replace heap_list_h_eq *)
  "\<And>p. \<lbrakk> x \<in> {p..+q}; heap_list h q p = heap_list h' q p \<rbrakk>
      \<Longrightarrow> h x = h' x"
proof (induct q)
  case 0 thus ?case by simp
next
  case (Suc n) thus ?case by (force dest: intvl_neq_start)
qed

(* end holding area *)


context begin interpretation Arch . (*FIXME: arch_split*)

(* Short-hand for  unfolding cumbersome machine constants *)
(* FIXME MOVE these should be in refine, and the _eq forms should NOT be declared [simp]! *)

declare word_neq_0_conv [simp del]

(* Rule previously in the simpset, now not. *)
declare ptr_add_def' [simp]

(* works much better *)
lemmas typ_heap_simps' = typ_heap_simps c_guard_clift

lemmas asUser_return = submonad.return [OF submonad_asUser]

lemmas asUser_bind_distrib =
  submonad_bind [OF submonad_asUser submonad_asUser submonad_asUser]

declare ef_dmo'[intro!, simp]

(* FIXME: move to Kernel_C *)
(* adapted from include/arch/arm/arch/64/mode/machine/registerset.h *)
lemmas C_register_defs =
  Kernel_C.X0_def
  Kernel_C.capRegister_def
  Kernel_C.badgeRegister_def
  Kernel_C.X1_def
  Kernel_C.msgInfoRegister_def
  Kernel_C.X2_def
  Kernel_C.X3_def
  Kernel_C.X4_def
  Kernel_C.X5_def
  Kernel_C.X6_def
  Kernel_C.X7_def
  Kernel_C.X8_def
  Kernel_C.X9_def
  Kernel_C.X10_def
  Kernel_C.X11_def
  Kernel_C.X12_def
  Kernel_C.X13_def
  Kernel_C.X14_def
  Kernel_C.X15_def
  Kernel_C.X16_def
  Kernel_C.X17_def
  Kernel_C.X18_def
  Kernel_C.X19_def
  Kernel_C.X20_def
  Kernel_C.X21_def
  Kernel_C.X22_def
  Kernel_C.X23_def
  Kernel_C.X24_def
  Kernel_C.X25_def
  Kernel_C.X26_def
  Kernel_C.X27_def
  Kernel_C.X28_def
  Kernel_C.X29_def
  Kernel_C.X30_def
  Kernel_C.LR_def
  Kernel_C.SP_EL0_def
  Kernel_C.ELR_EL1_def
  Kernel_C.NextIP_def
  Kernel_C.SPSR_EL1_def
  Kernel_C.FaultIP_def
  Kernel_C.TPIDR_EL0_def
  Kernel_C.TLS_BASE_def
  Kernel_C.TPIDRRO_EL0_def


(*
  Kernel_C.ra_def Kernel_C.LR_def
  Kernel_C.sp_def Kernel_C.SP_def
  Kernel_C.gp_def Kernel_C.GP_def
  Kernel_C.tp_def Kernel_C.TP_def
  Kernel_C.TLS_BASE_def
  Kernel_C.t0_def Kernel_C.t1_def Kernel_C.t2_def
  Kernel_C.t3_def Kernel_C.t4_def Kernel_C.t5_def Kernel_C.t6_def
  Kernel_C.s0_def Kernel_C.s1_def Kernel_C.s2_def Kernel_C.s3_def Kernel_C.s4_def
  Kernel_C.s5_def Kernel_C.s6_def Kernel_C.s7_def Kernel_C.s8_def Kernel_C.s9_def
  Kernel_C.s10_def Kernel_C.s11_def
  Kernel_C.a0_def Kernel_C.a1_def Kernel_C.a2_def Kernel_C.a3_def Kernel_C.a4_def
  Kernel_C.a5_def Kernel_C.a6_def Kernel_C.a7_def
  Kernel_C.capRegister_def Kernel_C.badgeRegister_def Kernel_C.msgInfoRegister_def
  Kernel_C.SCAUSE_def Kernel_C.SSTATUS_def Kernel_C.FaultIP_def Kernel_C.NextIP_def
*)

(* Levity: moved from Retype_C (20090419 09:44:41) *)
lemma no_overlap_new_cap_addrs_disjoint:
  "\<lbrakk> range_cover ptr sz (objBitsKO ko) n;
     pspace_aligned' s;
     pspace_no_overlap' ptr sz s \<rbrakk> \<Longrightarrow>
   set (new_cap_addrs n ptr ko) \<inter> dom (ksPSpace s) = {}"
  apply (erule disjoint_subset [OF new_cap_addrs_subset, where sz1=sz])
  apply (clarsimp simp: More_Word_Operations.ptr_add_def field_simps)
  apply (rule pspace_no_overlap_disjoint')
  apply auto
  done

lemma empty_fail_getExtraCPtrs [intro!, simp]:
  "empty_fail (getExtraCPtrs sendBuffer info)"
  apply (simp add: getExtraCPtrs_def)
  apply (cases info, simp)
  apply (cases sendBuffer; fastforce)
  done

lemma empty_fail_loadCapTransfer [intro!, simp]:
  "empty_fail (loadCapTransfer a)"
  by (fastforce simp: loadCapTransfer_def capTransferFromWords_def)

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
   \<lbrace>\<lambda>rv s. obj_at' (\<lambda>tcb. map ((user_regs o atcbContextGet o tcbArch) tcb) xs = rv) target s\<rbrace>"
  apply (induct xs)
   apply (simp add: mapM_empty asUser_return)
   apply wp
   apply simp
  apply (simp add: mapM_Cons asUser_bind_distrib asUser_return empty_fail_cond)
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

lemma option_to_ptr_NULL_eq:
  "\<lbrakk> option_to_ptr p = p' \<rbrakk> \<Longrightarrow> (p' = NULL) = (p = None \<or> p = Some 0)"
  unfolding option_to_ptr_def option_to_0_def
  by (clarsimp split: option.splits)

lemma option_to_ptr_not_0:
  "\<lbrakk> p \<noteq> 0 ; option_to_ptr v = Ptr p \<rbrakk> \<Longrightarrow> v = Some p"
  by (clarsimp simp: option_to_ptr_def option_to_0_def split: option.splits)

schematic_goal sz8_helper:
  "((-1) << 8 :: addr) = ?v"
  by (simp add: shiftl_t2n)

lemmas reset_name_seq_bound_helper2
    = reset_name_seq_bound_helper[where sz=8 and v="v :: addr" for v,
          simplified sz8_helper word_bits_def[symmetric],
          THEN name_seq_bound_helper]

end
