(*
 * Copyright 2022, Proofcraft Pty Ltd
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

theory ArchFinalise_AI
imports Finalise_AI
begin

context Arch begin

named_theorems Finalise_AI_asms

global_naming AARCH64

lemma valid_global_refs_asid_table_udapte [iff]:
  "valid_global_refs (s\<lparr>arch_state := arm_asid_table_update f (arch_state s)\<rparr>) =
  valid_global_refs s"
  by (simp add: valid_global_refs_def global_refs_def)

lemma nat_to_cref_unat_of_bl':
  "\<lbrakk> length xs < 64; n = length xs \<rbrakk> \<Longrightarrow>
   nat_to_cref n (unat (of_bl xs :: machine_word)) = xs"
  apply (simp add: nat_to_cref_def word_bits_def)
  apply (rule nth_equalityI)
   apply simp
  apply clarsimp
  apply (subst to_bl_nth)
   apply (simp add: word_size)
  apply (simp add: word_size)
  apply (simp add: test_bit_of_bl rev_nth)
  apply fastforce
  done

lemmas nat_to_cref_unat_of_bl = nat_to_cref_unat_of_bl' [OF _ refl]

lemma global_pt_asid_table_update[simp]:
  "arm_us_global_vspace (arch_state s\<lparr>arm_asid_table := atable\<rparr>) = global_pt s"
  by simp

lemma equal_kernel_mappings_asid_table_unmap:
  "equal_kernel_mappings s
   \<Longrightarrow> equal_kernel_mappings (s\<lparr>arch_state := arch_state s
                                \<lparr>arm_asid_table := (asid_table s)(i := None)\<rparr>\<rparr>)"
  unfolding equal_kernel_mappings_def by simp

lemma invs_arm_asid_table_unmap:
  "invs s
   \<and> is_aligned base asid_low_bits
   \<and> (\<forall>asid_low. vmid_for_asid s (asid_of (asid_high_bits_of base) asid_low) = None)
   \<and> tab = asid_table s
     \<longrightarrow> invs (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table := tab(asid_high_bits_of base := None)\<rparr>\<rparr>)"
  apply (clarsimp simp: invs_def valid_state_def valid_arch_caps_def)
  apply (strengthen valid_asid_map_unmap valid_vspace_objs_unmap_strg
                    valid_vs_lookup_unmap_strg valid_arch_state_unmap_strg)
  apply (simp add: valid_irq_node_def valid_kernel_mappings_def)
  apply (simp add: valid_table_caps_def valid_machine_state_def valid_global_objs_def
                   valid_asid_pool_caps_def equal_kernel_mappings_asid_table_unmap)
  done

lemma asid_low_bits_of_add:
  "\<lbrakk> is_aligned base asid_low_bits; offset \<le> mask asid_low_bits \<rbrakk> \<Longrightarrow>
   asid_low_bits_of (base + offset) = ucast offset"
  unfolding asid_low_bits_of_def
  by (metis and_mask_eq_iff_le_mask asid_bits_of_defs(2) asid_high_bits_shl asid_low_bits_of_mask_eq
            constructed_asid_low_bits_of word_and_or_mask_aligned)

lemma invalidate_asid_entry_vmid_for_asid:
  "\<lbrace>\<lambda>s. asid' \<noteq> asid \<longrightarrow> vmid_for_asid s asid' = None\<rbrace>
   invalidate_asid_entry asid
   \<lbrace>\<lambda>_ s. vmid_for_asid s asid' = None\<rbrace>"
  unfolding invalidate_asid_entry_def
  by (wpsimp wp: hoare_vcg_const_imp_lift)

lemma invalidate_asid_entry_vmid_for_asid_low:
  "\<lbrace>\<lambda>s. asid_low_bits_of asid \<noteq> asid_low \<longrightarrow>
          vmid_for_asid s (asid_of (asid_high_bits_of asid) asid_low) = None\<rbrace>
   invalidate_asid_entry asid
   \<lbrace>\<lambda>_ s. vmid_for_asid s (asid_of (asid_high_bits_of asid) asid_low) = None\<rbrace>"
  by (wpsimp wp: invalidate_asid_entry_vmid_for_asid)

lemma invalidate_asid_entry_vmid_for_asid_add:
  "\<lbrace>\<lambda>s. is_aligned base asid_low_bits \<and> offset \<le> mask asid_low_bits \<and> offset' \<le> mask asid_low_bits \<and>
        (offset \<noteq> offset' \<longrightarrow>
           vmid_for_asid s (asid_of (asid_high_bits_of base) (ucast offset')) = None) \<rbrace>
   invalidate_asid_entry (base + offset)
   \<lbrace>\<lambda>_ s. vmid_for_asid s (asid_of (asid_high_bits_of base) (ucast offset')) = None\<rbrace>"
  apply (rule hoare_assume_pre)
  apply (rule hoare_chain, rule invalidate_asid_entry_vmid_for_asid_low[where asid_low="ucast offset'"])
   apply (clarsimp simp: asid_low_bits_of_add asid_high_bits_of_add mask_def)
  apply (clarsimp simp: asid_high_bits_of_add mask_def)
  done

crunches invalidate_tlb_by_asid
  for vmid_for_asid[wp]: "\<lambda>s. P (vmid_for_asid s)"
  and asid_pools_of[wp]: "\<lambda>s. P (asid_pools_of s)"
  and pool_for_asid[wp]: "\<lambda>s. P (pool_for_asid asid s)"

lemma invalidate_asid_entry_asid_pools_of:
  "\<lbrace>\<lambda>s. asid_table s (asid_high_bits_of asid) = Some pptr \<and>
        (\<forall>ap entry. asid_pools_of s pptr = Some ap \<longrightarrow>
                    ap (asid_low_bits_of asid) = Some entry \<longrightarrow>
                    P (Some (ap(asid_low_bits_of asid \<mapsto> ASIDPoolVSpace None (ap_vspace entry)))))\<rbrace>
   invalidate_asid_entry asid
   \<lbrace>\<lambda>rv s. P (asid_pools_of s pptr)\<rbrace>"
  unfolding invalidate_asid_entry_def invalidate_asid_def invalidate_vmid_entry_def
  by (wpsimp simp: pool_for_asid_def)

lemma delete_asid_pool_invs[wp]:
  "delete_asid_pool base pptr \<lbrace>invs\<rbrace>"
  unfolding delete_asid_pool_def
  supply fun_upd_apply[simp del]
  apply wpsimp
      apply (strengthen invs_arm_asid_table_unmap)
      apply (rename_tac table pool)
      apply (rule_tac Q="\<lambda>_ s. (invs s \<and> is_aligned base asid_low_bits \<and> table = asid_table s \<and>
                                 (\<exists>ap. asid_pools_of s pptr = Some ap \<and>
                                   (\<forall>asid_low. ap asid_low \<noteq> None \<longrightarrow> pool asid_low \<noteq> None))) \<and>
                               (\<forall>x \<in> set [0 .e. mask asid_low_bits].
                                  vmid_for_asid s (asid_of (asid_high_bits_of base) (ucast x)) = None)"
                      in hoare_strengthen_post)
       apply (rule mapM_set_inv)
         apply (wpsimp wp: invalidate_asid_entry_vmid_for_asid)
           apply (wp invalidate_asid_entry_asid_pools_of)
          apply (wp invalidate_tlb_by_asid_invs hoare_vcg_all_lift)
         apply (clarsimp simp: vmid_for_asid_def asid_low_bits_of_add fun_upd_apply
                               asid_high_bits_of_add mask_def)
        apply (wpsimp wp: invalidate_asid_entry_vmid_for_asid_add hoare_vcg_const_imp_lift)
        apply (fastforce simp: vmid_for_asid_def entry_for_pool_def obind_def opt_map_def
                         split: option.splits)
       apply (wpsimp wp: invalidate_asid_entry_vmid_for_asid_add invalidate_asid_entry_asid_pools_of)
      apply (clarsimp simp: vmid_for_asid_def entry_for_pool_def obind_def opt_map_def
                            split: option.splits)
      apply (metis asid_low_bits_of_and_mask asid_low_bits_of_def asid_low_bits_of_mask_eq
                   asid_pool_entry.exhaust asid_pool_entry.sel(1) word_and_le1 word_ao_absorbs(8))
     apply wp+
  apply (clarsimp simp: asid_low_bits_of_def ucast_zero_is_aligned asid_low_bits_def)
  done

lemma get_vm_id_pool_for_asid[wp]:
  "get_vmid asid' \<lbrace>\<lambda>s. P (pool_for_asid asid s)\<rbrace>"
  by (wp pool_for_asid_lift)

crunches set_vm_root
  for pool_for_asid[wp]: "\<lambda>s. P (pool_for_asid asid s)"
  and vspace_for_asid[wp]: "\<lambda>s. P (vspace_for_asid asid s)"
  (simp: crunch_simps)

lemma delete_asid_invs[wp]:
  "\<lbrace> invs and valid_asid_table and pspace_aligned \<rbrace> delete_asid asid pd \<lbrace>\<lambda>_. invs\<rbrace>"
  apply (simp add: delete_asid_def cong: option.case_cong)
  apply (wpsimp wp: set_asid_pool_invs_unmap invalidate_asid_entry_asid_pools_of hoare_vcg_ex_lift
                    invalidate_asid_entry_vmid_for_asid invalidate_tlb_by_asid_invs
                    hoare_vcg_imp_lift'
                simp: pool_for_asid_def)
  apply blast
  done

lemma delete_asid_pool_unmapped[wp]:
  "\<lbrace>\<lambda>s. True \<rbrace>
     delete_asid_pool asid poolptr
   \<lbrace>\<lambda>_ s. pool_for_asid asid s \<noteq> Some poolptr \<rbrace>"
  unfolding delete_asid_pool_def
  by (wpsimp simp: pool_for_asid_def)

lemma set_asid_pool_unmap:
  "\<lbrace>\<lambda>s. pool_for_asid asid s = Some poolptr \<rbrace>
   set_asid_pool poolptr (pool(asid_low_bits_of asid := None))
   \<lbrace>\<lambda>rv s. vspace_for_asid asid s = None \<rbrace>"
  unfolding set_asid_pool_def
  apply (wp set_object_wp)
  by (simp add: pool_for_asid_def entry_for_asid_def entry_for_pool_def vspace_for_asid_def
                vspace_for_pool_def obind_def in_omonad
         split: option.splits)

crunches invalidate_asid_entry
  for pool_for_asid[wp]: "\<lambda>s. P (pool_for_asid asid s)"
  (simp: pool_for_asid_def)

lemma delete_asid_unmapped:
  "\<lbrace>\<lambda>s. vspace_for_asid asid s = Some pt\<rbrace>
   delete_asid asid pt
   \<lbrace>\<lambda>_ s. vspace_for_asid asid s = None\<rbrace>"
  unfolding delete_asid_def
  apply (simp cong: option.case_cong)
  apply (wpsimp wp: set_asid_pool_unmap | wp (once) hoare_drop_imps)+
  apply (clarsimp simp: vspace_for_asid_def pool_for_asid_def vspace_for_pool_def
                        obind_def in_omonad entry_for_asid_def entry_for_pool_def
                 split: option.splits)
  by (meson asid_pool_entry.exhaust_sel)

lemma set_pt_tcb_at:
  "\<lbrace>\<lambda>s. P (ko_at (TCB tcb) t s)\<rbrace> set_pt a b \<lbrace>\<lambda>_ s. P (ko_at (TCB tcb) t s)\<rbrace>"
  by (wpsimp simp: set_pt_def obj_at_def wp: set_object_wp)

lemma set_vcpu_tcb_at_arch: (* generalise? this holds except when the ko is a vcpu *)
  "set_vcpu p v \<lbrace>\<lambda>s. P (ko_at (TCB tcb) t s)\<rbrace>"
  by (wp set_vcpu_nonvcpu_at; auto)

crunch tcb_at_arch: vcpu_switch "\<lambda>s. P (ko_at (TCB tcb) t s)"
    (simp: crunch_simps when_def
       wp: crunch_wps set_vcpu_tcb_at_arch)

crunch tcb_at_arch: unmap_page "\<lambda>s. P (ko_at (TCB tcb) t s)"
    (simp: crunch_simps wp: crunch_wps set_pt_tcb_at ignore: set_object)

lemmas unmap_page_tcb_at = unmap_page_tcb_at_arch

lemma unmap_page_tcb_cap_valid:
  "unmap_page sz asid vaddr pptr \<lbrace>\<lambda>s. tcb_cap_valid cap r s\<rbrace>"
  apply (rule tcb_cap_valid_typ_st)
    apply wp
   apply (simp add: pred_tcb_at_def2)
  apply (wp unmap_page_tcb_at hoare_vcg_ex_lift hoare_vcg_all_lift)+
  done


global_naming Arch

lemma (* replaceable_cdt_update *)[simp,Finalise_AI_asms]:
  "replaceable (cdt_update f s) = replaceable s"
  by (fastforce simp: replaceable_def tcb_cap_valid_def
                      reachable_frame_cap_def reachable_target_def)

lemma (* replaceable_revokable_update *)[simp,Finalise_AI_asms]:
  "replaceable (is_original_cap_update f s) = replaceable s"
  by (fastforce simp: replaceable_def is_final_cap'_def2 tcb_cap_valid_def
                      reachable_frame_cap_def reachable_target_def)

lemma (* replaceable_more_update *) [simp,Finalise_AI_asms]:
  "replaceable (trans_state f s) sl cap cap' = replaceable s sl cap cap'"
  by (simp add: replaceable_def reachable_frame_cap_def reachable_target_def)

lemma reachable_target_trans_state[simp]:
  "reachable_target ref p (trans_state f s) = reachable_target ref p s"
  by (clarsimp simp: reachable_target_def split_def)

lemma reachable_frame_cap_trans_state[simp]:
  "reachable_frame_cap cap (trans_state f s) = reachable_frame_cap cap s"
  by (simp add: reachable_frame_cap_def)

lemmas [Finalise_AI_asms] = obj_refs_obj_ref_of (* used under name obj_ref_ofI *)

lemma (* empty_slot_invs *) [Finalise_AI_asms]:
  "\<lbrace>\<lambda>s. invs s \<and> cte_wp_at (replaceable s sl cap.NullCap) sl s \<and>
        emptyable sl s \<and>
        (info \<noteq> NullCap \<longrightarrow> post_cap_delete_pre info ((caps_of_state s) (sl \<mapsto> NullCap)))\<rbrace>
     empty_slot sl info
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: empty_slot_def set_cdt_def bind_assoc cong: if_cong)
  apply (wp post_cap_deletion_invs)
        apply (simp add: invs_def valid_state_def valid_mdb_def2)
        apply (wp replace_cap_valid_pspace set_cap_caps_of_state2
                  replace_cap_ifunsafe get_cap_wp
                  set_cap_idle valid_irq_node_typ set_cap_typ_at
                  set_cap_irq_handlers set_cap_valid_arch_caps
                  set_cap_cap_refs_respects_device_region_NullCap
               | simp add: trans_state_update[symmetric]
                      del: trans_state_update fun_upd_apply
                      split del: if_split)+
  apply (clarsimp simp: is_final_cap'_def2 simp del: fun_upd_apply)
  apply (clarsimp simp: conj_comms invs_def valid_state_def valid_mdb_def2)
  apply (subgoal_tac "mdb_empty_abs s")
   prefer 2
   apply (rule mdb_empty_abs.intro)
   apply (rule vmdb_abs.intro)
   apply (simp add: valid_mdb_def swp_def cte_wp_at_caps_of_state conj_comms)
  apply (clarsimp simp: untyped_mdb_def mdb_empty_abs.descendants mdb_empty_abs.no_mloop_n
                        valid_pspace_def cap_range_def)
  apply (clarsimp simp: untyped_inc_def mdb_empty_abs.descendants mdb_empty_abs.no_mloop_n)
  apply (simp add: ut_revocable_def cur_tcb_def valid_irq_node_def
                   no_cap_to_obj_with_diff_ref_Null)
  apply (rule conjI)
   apply (clarsimp simp: cte_wp_at_cte_at)
  apply (rule conjI)
   apply (clarsimp simp: valid_arch_mdb_def)
  apply (rule conjI)
   apply (clarsimp simp: irq_revocable_def)
  apply (rule conjI)
   apply (clarsimp simp: reply_master_revocable_def)
  apply (thin_tac "info \<noteq> NullCap \<longrightarrow> P info" for P)
  apply (rule conjI)
   apply (clarsimp simp: valid_machine_state_def)
  apply (rule conjI)
   apply (clarsimp simp:descendants_inc_def mdb_empty_abs.descendants)
  apply (rule conjI)
   apply (clarsimp simp: reply_mdb_def)
   apply (rule conjI)
    apply (unfold reply_caps_mdb_def)[1]
    apply (rule allEI, assumption)
    apply (fold reply_caps_mdb_def)[1]
    apply (case_tac "sl = ptr", simp)
    apply (simp add: fun_upd_def split del: if_split del: split_paired_Ex)
    apply (erule allEI, rule impI, erule(1) impE)
    apply (erule exEI)
    apply (simp, rule ccontr)
    apply (erule(5) emptyable_no_reply_cap)
    apply simp
   apply (unfold reply_masters_mdb_def)[1]
   apply (elim allEI)
   apply (clarsimp simp: mdb_empty_abs.descendants)
  apply (rule conjI)
   apply (simp add: valid_ioc_def)
  apply (rule conjI)
   apply (clarsimp simp: tcb_cap_valid_def
                  dest!: emptyable_valid_NullCapD)
  apply (rule conjI)
   apply (clarsimp simp: mdb_cte_at_def cte_wp_at_caps_of_state)
   apply (cases sl)
   apply (rule conjI, clarsimp)
    apply (subgoal_tac "cdt s \<Turnstile> (ab,bb) \<rightarrow> (ab,bb)")
     apply (simp add: no_mloop_def)
    apply (rule r_into_trancl)
    apply (simp add: cdt_parent_of_def)
   apply fastforce
  apply (clarsimp simp: cte_wp_at_caps_of_state replaceable_def
                        reachable_frame_cap_def reachable_target_def
                   del: allI)
  apply (case_tac "is_final_cap' cap s")
   apply auto[1]
  apply (simp add: is_final_cap'_def2 cte_wp_at_caps_of_state)
  by fastforce

lemma dom_tcb_cap_cases_lt_ARCH [Finalise_AI_asms]:
  "dom tcb_cap_cases = {xs. length xs = 3 \<and> unat (of_bl xs :: machine_word) < 5}"
  apply (rule set_eqI, rule iffI)
   apply clarsimp
   apply (simp add: tcb_cap_cases_def tcb_cnode_index_def to_bl_1 split: if_split_asm)
  apply clarsimp
  apply (frule tcb_cap_cases_lt)
  apply (clarsimp simp: nat_to_cref_unat_of_bl')
  done

lemma (* unbind_notification_final *) [wp,Finalise_AI_asms]:
  "\<lbrace>is_final_cap' cap\<rbrace> unbind_notification t \<lbrace> \<lambda>rv. is_final_cap' cap\<rbrace>"
  unfolding unbind_notification_def
  apply (wp final_cap_lift thread_set_caps_of_state_trivial hoare_drop_imps
       | wpc | simp add: tcb_cap_cases_def)+
  done

lemma arch_thread_set_caps_of_state[wp]:
  "arch_thread_set v t \<lbrace>\<lambda>s. P (caps_of_state s) \<rbrace>"
  apply (wpsimp simp: arch_thread_set_def wp: set_object_wp)
  apply (clarsimp simp: fun_upd_def)
  apply (frule get_tcb_ko_atD)
  apply (auto simp: caps_of_state_after_update obj_at_def tcb_cap_cases_def)
  done

lemma arch_thread_set_final_cap[wp]:
  "\<lbrace>is_final_cap' cap\<rbrace> arch_thread_set v t \<lbrace>\<lambda>rv. is_final_cap' cap\<rbrace>"
  by (wpsimp simp: is_final_cap'_def2 cte_wp_at_caps_of_state)

lemma arch_thread_get_final_cap[wp]:
  "\<lbrace>is_final_cap' cap\<rbrace> arch_thread_get v t \<lbrace>\<lambda>rv. is_final_cap' cap\<rbrace>"
  apply (simp add: arch_thread_get_def is_final_cap'_def2 cte_wp_at_caps_of_state, wp)
  apply auto
  done

crunches prepare_thread_delete
  for caps_of_state[wp]: "\<lambda>s. P (caps_of_state s)"
  (wp: crunch_wps ignore: do_machine_op)

declare prepare_thread_delete_caps_of_state [Finalise_AI_asms]

lemma dissociate_vcpu_tcb_final_cap[wp]:
  "\<lbrace>is_final_cap' cap\<rbrace> dissociate_vcpu_tcb v t \<lbrace>\<lambda>rv. is_final_cap' cap\<rbrace>"
  by (wpsimp simp: is_final_cap'_def2 cte_wp_at_caps_of_state)

lemma prepare_thread_delete_final[wp]:
  "\<lbrace>is_final_cap' cap\<rbrace> prepare_thread_delete t \<lbrace> \<lambda>rv. is_final_cap' cap\<rbrace>"
  unfolding prepare_thread_delete_def fpu_thread_delete_def by wpsimp

lemma length_and_unat_of_bl_length:
  "(length xs = x \<and> unat (of_bl xs :: 'a::len word) < 2 ^ x) = (length xs = x)"
  by (auto simp: unat_of_bl_length)

lemma (* finalise_cap_cases1 *)[Finalise_AI_asms]:
  "\<lbrace>\<lambda>s. final \<longrightarrow> is_final_cap' cap s
         \<and> cte_wp_at ((=) cap) slot s\<rbrace>
     finalise_cap cap final
   \<lbrace>\<lambda>rv s. fst rv = cap.NullCap
         \<and> snd rv = (if final then cap_cleanup_opt cap else NullCap)
         \<and> (snd rv \<noteq> NullCap \<longrightarrow> is_final_cap' cap s)
     \<or>
       is_zombie (fst rv) \<and> is_final_cap' cap s
        \<and> snd rv = NullCap
        \<and> appropriate_cte_cap (fst rv) = appropriate_cte_cap cap
        \<and> cte_refs (fst rv) = cte_refs cap
        \<and> gen_obj_refs (fst rv) = gen_obj_refs cap
        \<and> obj_size (fst rv) = obj_size cap
        \<and> fst_cte_ptrs (fst rv) = fst_cte_ptrs cap
        \<and> vs_cap_ref cap = None\<rbrace>"
  apply (cases cap, simp_all split del: if_split cong: if_cong)
            apply ((wp suspend_final_cap[where sl=slot]
                      deleting_irq_handler_final[where slot=slot]
                      | simp add: o_def is_cap_simps fst_cte_ptrs_def
                                  dom_tcb_cap_cases_lt_ARCH tcb_cnode_index_def
                                  can_fast_finalise_def length_and_unat_of_bl_length
                                  appropriate_cte_cap_def gen_obj_refs_def
                                  vs_cap_ref_def cap_cleanup_opt_def
                      | intro impI TrueI ext conjI)+)[11]
  apply (simp add: arch_finalise_cap_def split del: if_split)
  apply (wpsimp simp: cap_cleanup_opt_def arch_cap_cleanup_opt_def)
  done

crunch typ_at_arch [wp]: arch_thread_set "\<lambda>s. P (typ_at T p s)"
  (wp: crunch_wps set_object_typ_at)

crunch typ_at[wp]: dissociate_vcpu_tcb "\<lambda>s. P (typ_at T p s)"
  (wp: crunch_wps simp: crunch_simps unless_def assertE_def
        ignore: do_machine_op set_object)

crunch typ_at[wp,Finalise_AI_asms]: arch_finalise_cap "\<lambda>s. P (typ_at T p s)"
  (wp: crunch_wps simp: crunch_simps unless_def assertE_def
        ignore: maskInterrupt set_object)

crunch typ_at[wp,Finalise_AI_asms]: prepare_thread_delete "\<lambda>s. P (typ_at T p s)"

crunch tcb_at[wp]: arch_thread_set "\<lambda>s. tcb_at p s"
  (ignore: set_object)

crunch tcb_at[wp]: arch_thread_get "\<lambda>s. tcb_at p s"

lemma vcpu_set_tcb_at[wp]: "\<lbrace>\<lambda>s. tcb_at p s\<rbrace> set_vcpu t vcpu \<lbrace>\<lambda>_ s. tcb_at p s\<rbrace>"
  by (wpsimp simp: tcb_at_typ)

crunch tcb_at[wp]: dissociate_vcpu_tcb "\<lambda>s. tcb_at p s"
  (wp: crunch_wps)

crunch tcb_at[wp]: prepare_thread_delete "\<lambda>s. tcb_at p s"

lemma (* finalise_cap_new_valid_cap *)[wp,Finalise_AI_asms]:
  "\<lbrace>valid_cap cap\<rbrace> finalise_cap cap x \<lbrace>\<lambda>rv. valid_cap (fst rv)\<rbrace>"
  apply (cases cap; simp)
            apply (wp suspend_valid_cap prepare_thread_delete_typ_at
                     | simp add: o_def valid_cap_def cap_aligned_def
                                 valid_cap_Null_ext
                           split del: if_split
                     | clarsimp | rule conjI)+
  (* ArchObjectCap *)
  apply (wpsimp wp: o_def valid_cap_def cap_aligned_def
                 split_del: if_split
         | clarsimp simp: arch_finalise_cap_def)+
  done

crunch inv[wp]: arch_thread_get "P"

lemma hoare_split: "\<lbrakk>\<lbrace>P\<rbrace> f \<lbrace>Q\<rbrace>; \<lbrace>P\<rbrace> f \<lbrace>Q'\<rbrace>\<rbrakk> \<Longrightarrow> \<lbrace>P\<rbrace> f \<lbrace>\<lambda>r. Q r and Q' r\<rbrace>"
  by (auto simp: valid_def)

sublocale
  arch_thread_set: non_aobj_non_cap_non_mem_op "arch_thread_set f v"
  by (unfold_locales;
        ((wpsimp)?;
        wpsimp wp: set_object_non_arch simp: non_arch_objs arch_thread_set_def)?)

(* arch_thread_set invariants *)
lemma arch_thread_set_cur_tcb[wp]: "\<lbrace>cur_tcb\<rbrace> arch_thread_set p v \<lbrace>\<lambda>_. cur_tcb\<rbrace>"
  unfolding cur_tcb_def[abs_def]
  apply (rule hoare_lift_Pf [where f=cur_thread])
   apply (simp add: tcb_at_typ)
   apply wp
  apply (simp add: arch_thread_set_def)
  apply (wp hoare_drop_imp)
  apply simp
  done

lemma cte_wp_at_update_some_tcb:
  "\<lbrakk>kheap s v = Some (TCB tcb) ; tcb_cnode_map tcb = tcb_cnode_map (f tcb)\<rbrakk>
  \<Longrightarrow> cte_wp_at P p (s\<lparr>kheap := (kheap s)(v \<mapsto> TCB (f tcb))\<rparr>) = cte_wp_at P p s"
  apply (clarsimp simp: cte_wp_at_cases2 dest!: get_tcb_SomeD)
  done

lemma arch_thread_set_cap_refs_respects_device_region[wp]:
  "\<lbrace>cap_refs_respects_device_region\<rbrace>
     arch_thread_set p v
   \<lbrace>\<lambda>s. cap_refs_respects_device_region\<rbrace>"
  apply (simp add: arch_thread_set_def set_object_def get_object_def)
  apply wp
  apply (clarsimp dest!: get_tcb_SomeD simp del: fun_upd_apply)
  apply (subst get_tcb_rev, assumption, subst option.sel)+
  apply (subst cap_refs_respects_region_cong)
    prefer 3
    apply assumption
   apply (rule cte_wp_caps_of_lift)
   apply (subst arch_tcb_update_aux3)
   apply (rule_tac cte_wp_at_update_some_tcb, assumption)
   apply (simp add: tcb_cnode_map_def)+
  done

lemma arch_thread_set_pspace_respects_device_region[wp]:
  "\<lbrace>pspace_respects_device_region\<rbrace>
     arch_thread_set p v
   \<lbrace>\<lambda>s. pspace_respects_device_region\<rbrace>"
  apply (simp add: arch_thread_set_def)
  apply (wp get_object_wp set_object_pspace_respects_device_region)
  apply clarsimp
  done

lemma arch_thread_set_cap_refs_in_kernel_window[wp]:
  "\<lbrace>cap_refs_in_kernel_window\<rbrace> arch_thread_set p v \<lbrace>\<lambda>_. cap_refs_in_kernel_window\<rbrace>"
  unfolding cap_refs_in_kernel_window_def[abs_def]
  apply (rule hoare_lift_Pf [where f="\<lambda>s. not_kernel_window s"])
  apply (rule valid_refs_cte_lift)
  apply wp+
  done

crunch valid_irq_states[wp]: arch_thread_set valid_irq_states
  (wp: crunch_wps simp: crunch_simps)

crunch interrupt_state[wp]: arch_thread_set "\<lambda>s. P (interrupt_states s)"
  (wp: crunch_wps simp: crunch_simps)

lemmas arch_thread_set_valid_irq_handlers[wp] = valid_irq_handlers_lift[OF arch_thread_set.caps arch_thread_set_interrupt_state]

crunch interrupt_irq_node[wp]: arch_thread_set "\<lambda>s. P (interrupt_irq_node s)"
  (wp: crunch_wps simp: crunch_simps)

lemmas arch_thread_set_valid_irq_node[wp] = valid_irq_node_typ[OF arch_thread_set_typ_at_arch arch_thread_set_interrupt_irq_node]

crunch idle_thread[wp]: arch_thread_set "\<lambda>s. P (idle_thread s)"
  (wp: crunch_wps simp: crunch_simps)

lemma arch_thread_set_valid_global_refs[wp]:
  "\<lbrace>valid_global_refs\<rbrace> arch_thread_set p v \<lbrace>\<lambda>rv. valid_global_refs\<rbrace>"
  by (rule valid_global_refs_cte_lift) wp+

lemma arch_thread_set_valid_reply_masters[wp]:
  "\<lbrace>valid_reply_masters\<rbrace> arch_thread_set p v \<lbrace>\<lambda>rv. valid_reply_masters\<rbrace>"
  by (rule valid_reply_masters_cte_lift) wp

lemma arch_thread_set_pred_tcb_at[wp_unsafe]:
  "\<lbrace>pred_tcb_at proj P t and K (proj_not_field proj tcb_arch_update)\<rbrace>
     arch_thread_set p v
   \<lbrace>\<lambda>rv. pred_tcb_at proj P t\<rbrace>"
  apply (simp add: arch_thread_set_def set_object_def get_object_def)
  apply wp
  apply (clarsimp simp: pred_tcb_at_def obj_at_def get_tcb_rev
                  dest!: get_tcb_SomeD)
  done

lemma arch_thread_set_valid_reply_caps[wp]:
  "\<lbrace>valid_reply_caps\<rbrace> arch_thread_set p v \<lbrace>\<lambda>rv. valid_reply_caps\<rbrace>"
  by (rule valid_reply_caps_st_cte_lift)
     (wpsimp wp: arch_thread_set_pred_tcb_at)+

lemma arch_thread_set_if_unsafe_then_cap[wp]:
  "\<lbrace>if_unsafe_then_cap\<rbrace> arch_thread_set p v \<lbrace>\<lambda>rv. if_unsafe_then_cap\<rbrace>"
  apply (simp add: arch_thread_set_def)
  apply (wp get_object_wp set_object_ifunsafe)
  apply (clarsimp split: kernel_object.splits arch_kernel_obj.splits
                  dest!: get_tcb_SomeD)
  apply (subst get_tcb_rev)
  apply assumption
  apply simp
  apply (subst get_tcb_rev, assumption, simp)+
  apply (clarsimp simp: obj_at_def tcb_cap_cases_def)
  done

lemma arch_thread_set_only_idle[wp]:
  "\<lbrace>only_idle\<rbrace> arch_thread_set p v \<lbrace>\<lambda>rv. only_idle\<rbrace>"
  by (wpsimp wp: only_idle_lift set_asid_pool_typ_at
                 arch_thread_set_pred_tcb_at)

lemma arch_thread_set_valid_idle[wp]:
  "\<lbrace>valid_idle and (\<lambda> s. t \<noteq> idle_thread s \<or> (\<forall>atcb. tcb_vcpu atcb = None \<longrightarrow> tcb_vcpu (f atcb) = None))\<rbrace>
    arch_thread_set f t
   \<lbrace>\<lambda>rv. valid_idle\<rbrace>"
  by (wpsimp simp: arch_thread_set_def set_object_def get_object_def valid_idle_def
                   valid_arch_idle_def get_tcb_def pred_tcb_at_def obj_at_def pred_neg_def)

lemma arch_thread_set_valid_ioc[wp]:
  "\<lbrace>valid_ioc\<rbrace> arch_thread_set p v \<lbrace>\<lambda>rv. valid_ioc\<rbrace>"
  apply (simp add: arch_thread_set_def set_object_def get_object_def)
  apply (wp set_object_valid_ioc_caps)
  apply (clarsimp simp add: valid_ioc_def
                  simp del: fun_upd_apply
                  split: kernel_object.splits arch_kernel_obj.splits
                  dest!: get_tcb_SomeD)
  apply (subst get_tcb_rev, assumption, subst option.sel)+
  apply (subst arch_tcb_update_aux3)
  apply (subst cte_wp_at_update_some_tcb,assumption)
   apply (clarsimp simp: tcb_cnode_map_def)+
  done

lemma arch_thread_set_valid_mdb[wp]: "\<lbrace>valid_mdb\<rbrace> arch_thread_set p v \<lbrace>\<lambda>rv. valid_mdb\<rbrace>"
  by (wpsimp wp: valid_mdb_lift get_object_wp simp: arch_thread_set_def set_object_def)

lemma arch_thread_set_zombies_final[wp]: "\<lbrace>zombies_final\<rbrace> arch_thread_set p v \<lbrace>\<lambda>rv. zombies_final\<rbrace>"
  apply (simp add: arch_thread_set_def)
  apply (wp get_object_wp set_object_zombies)
  apply (clarsimp split: kernel_object.splits arch_kernel_obj.splits
                  dest!: get_tcb_SomeD)
  apply (subst get_tcb_rev)
  apply assumption
  apply simp
  apply (subst get_tcb_rev, assumption, simp)+
  apply (clarsimp simp: obj_at_def tcb_cap_cases_def)
  done

lemma arch_thread_set_if_live_then_nonz_cap_Some[wp]:
  "\<lbrace> (ex_nonz_cap_to t or obj_at live t) and if_live_then_nonz_cap\<rbrace>
      arch_thread_set (tcb_vcpu_update (\<lambda>_. Some vcp)) t \<lbrace>\<lambda>rv. if_live_then_nonz_cap\<rbrace>"
  apply (simp add: arch_thread_set_def)
  apply (wp set_object_iflive)
  apply (clarsimp simp: ex_nonz_cap_to_def if_live_then_nonz_cap_def
                  dest!: get_tcb_SomeD)
  apply (subst get_tcb_rev, assumption, subst option.sel)+
  apply (clarsimp simp: obj_at_def tcb_cap_cases_def)
  done

lemma arch_thread_set_pspace_in_kernel_window[wp]:
  "\<lbrace>pspace_in_kernel_window\<rbrace> arch_thread_set f v \<lbrace>\<lambda>_.pspace_in_kernel_window\<rbrace>"
  by (rule pspace_in_kernel_window_atyp_lift, wp+)

lemma arch_thread_set_pspace_distinct[wp]: "\<lbrace>pspace_distinct\<rbrace>arch_thread_set f v\<lbrace>\<lambda>_. pspace_distinct\<rbrace>"
  apply (simp add: arch_thread_set_def)
  apply (wp set_object_distinct)
  apply (clarsimp simp: get_object_def obj_at_def
                  dest!: get_tcb_SomeD)
  done

lemma arch_thread_set_pspace_aligned[wp]:
  "\<lbrace>pspace_aligned\<rbrace> arch_thread_set f v \<lbrace>\<lambda>_. pspace_aligned\<rbrace>"
  apply (simp add: arch_thread_set_def)
  apply (wp set_object_aligned)
  apply (clarsimp simp: obj_at_def get_object_def
                  dest!: get_tcb_SomeD)
  done

lemma arch_thread_set_valid_objs_context[wp]:
  "arch_thread_set (tcb_context_update f) v \<lbrace>valid_objs\<rbrace>"
  apply (simp add: arch_thread_set_def)
  apply (wp set_object_valid_objs)
  apply (clarsimp simp: Ball_def obj_at_def valid_objs_def dest!: get_tcb_SomeD)
  apply (erule_tac x=v in allE)
  apply (clarsimp simp: dom_def)
  apply (subst get_tcb_rev, assumption, subst option.sel)+
  apply (clarsimp simp:valid_obj_def valid_tcb_def tcb_cap_cases_def)
  done

lemma arch_thread_set_valid_objs_vcpu_None[wp]:
  "arch_thread_set (tcb_vcpu_update Map.empty) v \<lbrace>valid_objs\<rbrace>"
  apply (simp add: arch_thread_set_def)
  apply (wp set_object_valid_objs)
  apply (clarsimp simp: Ball_def obj_at_def valid_objs_def dest!: get_tcb_SomeD)
  apply (erule_tac x=v in allE)
  apply (clarsimp simp: dom_def)
  apply (subst get_tcb_rev, assumption, subst option.sel)+
  apply (clarsimp simp:valid_obj_def valid_tcb_def tcb_cap_cases_def valid_arch_tcb_def)
  done

lemma arch_thread_set_valid_objs_vcpu_Some[wp]:
  "\<lbrace>valid_objs and vcpu_at vcpu\<rbrace> arch_thread_set (tcb_vcpu_update (\<lambda>_. Some vcpu)) v \<lbrace>\<lambda>_. valid_objs\<rbrace>"
  apply (simp add: arch_thread_set_def)
  apply (wpsimp wp: set_object_valid_objs)
  apply (clarsimp simp: Ball_def obj_at_def valid_objs_def dest!: get_tcb_SomeD)
  apply (erule_tac x=v in allE)
  apply (clarsimp simp: dom_def)
  apply (clarsimp simp:valid_obj_def valid_tcb_def tcb_cap_cases_def valid_arch_tcb_def obj_at_def)
  done

lemma sym_refs_update_some_tcb:
  "\<lbrakk>kheap s v = Some (TCB tcb) ; refs_of (TCB tcb) = refs_of (TCB (f tcb))\<rbrakk>
  \<Longrightarrow> sym_refs (state_refs_of (s\<lparr>kheap := (kheap s)(v \<mapsto> TCB (f tcb))\<rparr>)) = sym_refs (state_refs_of s)"
  apply (rule_tac f=sym_refs in arg_cong)
  apply (rule all_ext)
  apply (clarsimp simp: sym_refs_def state_refs_of_def)
  done

lemma arch_thread_sym_refs[wp]:
  "\<lbrace>\<lambda>s. sym_refs (state_refs_of s)\<rbrace> arch_thread_set f p \<lbrace>\<lambda>rv s. sym_refs (state_refs_of s)\<rbrace>"
  apply (simp add: arch_thread_set_def set_object_def get_object_def)
  apply wp
  apply (clarsimp simp del: fun_upd_apply dest!: get_tcb_SomeD)
  apply (subst get_tcb_rev, assumption, subst option.sel)+
  apply (subst arch_tcb_update_aux3)
  apply (subst sym_refs_update_some_tcb[where f="tcb_arch_update f"])
    apply assumption
   apply (clarsimp simp: refs_of_def)
  apply assumption
  done

lemma arch_thread_get_tcb:
  "\<lbrace> \<top> \<rbrace> arch_thread_get tcb_vcpu p \<lbrace>\<lambda>rv s. \<exists>t. obj_at (\<lambda>tcb. tcb = (TCB t) \<and> rv = tcb_vcpu (tcb_arch t)) p s\<rbrace>"
  apply (simp add: arch_thread_get_def)
  apply wp
  apply (clarsimp simp: obj_at_def dest!: get_tcb_SomeD)
  apply (subst get_tcb_rev, assumption, subst option.sel)+
  apply simp
  done

lemma get_vcpu_ko: "\<lbrace>Q\<rbrace> get_vcpu p \<lbrace>\<lambda>rv s. ko_at (ArchObj (VCPU rv)) p s \<and> Q s\<rbrace>"
  unfolding get_vcpu_def
  by wpsimp
     (simp add: obj_at_def in_omonad)

lemma vcpu_invalidate_tcbs_inv[wp]:
  "\<lbrace>obj_at (\<lambda>tcb. \<exists>t'. tcb = TCB t' \<and> P t') t\<rbrace>
    vcpu_invalidate_active \<lbrace>\<lambda>rv. obj_at (\<lambda>tcb. \<exists>t'. tcb = TCB t' \<and> P t') t\<rbrace>"
  unfolding vcpu_invalidate_active_def vcpu_disable_def by wpsimp

lemma sym_refs_vcpu_None:
  assumes sym_refs: "sym_refs (state_hyp_refs_of s)"
  assumes tcb: "ko_at (TCB tcb) t s" "tcb_vcpu (tcb_arch tcb) = Some vr"
  shows "sym_refs (state_hyp_refs_of (s\<lparr>kheap := (kheap s)(t \<mapsto> TCB (tcb\<lparr>tcb_arch := tcb_vcpu_update Map.empty (tcb_arch tcb)\<rparr>),
                                       vr \<mapsto> ArchObj (VCPU (vcpu_tcb_update Map.empty v)))\<rparr>))"
    (is "sym_refs (state_hyp_refs_of ?s')")
proof -
  from tcb
  have t: "state_hyp_refs_of s t = {(vr,TCBHypRef)}"
    by (simp add: state_hyp_refs_of_def obj_at_def)
  moreover
  from t
  have "(t,HypTCBRef) \<in> state_hyp_refs_of s vr"
    using sym_refsD [of vr _ _ t, OF _ sym_refs] by auto
  hence vr: "state_hyp_refs_of s vr = {(t,HypTCBRef)}"
    by (auto simp: state_hyp_refs_of_def hyp_refs_of_def tcb_vcpu_refs_def vcpu_tcb_refs_def
                   refs_of_def refs_of_ao_def
            split: option.splits kernel_object.splits arch_kernel_obj.splits)
  moreover
  from sym_refs vr
  have "\<And>x r rt. \<lbrakk> (r, rt) \<in> state_hyp_refs_of s x; x \<noteq> t \<rbrakk> \<Longrightarrow> r \<noteq> vr"
    by (auto dest: sym_refsD)
  moreover
  from sym_refs t
  have "\<And>x r rt. \<lbrakk> (r, rt) \<in> state_hyp_refs_of s x; x \<noteq> vr \<rbrakk> \<Longrightarrow> r \<noteq> t"
    by (auto dest: sym_refsD)
  ultimately
  have "sym_refs ((state_hyp_refs_of s) (vr := {}, t := {}))"
    using sym_refs unfolding sym_refs_def by (clarsimp simp: split_def)
  moreover
  have "state_hyp_refs_of ?s' = (state_hyp_refs_of s) (vr := {}, t := {})"
    unfolding state_hyp_refs_of_def by (rule ext) (simp add: vcpu_tcb_refs_def)
  ultimately
  show ?thesis by simp
qed

lemma arch_thread_set_wp:
  "\<lbrace>\<lambda>s. get_tcb p s \<noteq> None \<longrightarrow> Q (s\<lparr>kheap := (kheap s)(p \<mapsto> TCB (the (get_tcb p s)\<lparr>tcb_arch := f (tcb_arch (the (get_tcb p s)))\<rparr>))\<rparr>) \<rbrace>
    arch_thread_set f p
   \<lbrace>\<lambda>_. Q\<rbrace>"
  apply (simp add: arch_thread_set_def)
  apply (wp set_object_wp)
  apply simp
  done

lemma arch_thread_get_wp:
  "\<lbrace>\<lambda>s. \<forall>tcb. ko_at (TCB tcb) t s \<longrightarrow> Q (f (tcb_arch tcb)) s\<rbrace> arch_thread_get f t \<lbrace>Q\<rbrace>"
  apply (wpsimp simp: arch_thread_get_def)
  apply (auto dest!: get_tcb_ko_atD)
  done

(* FIXME: move *)
lemma get_tcb_None_tcb_at:
  "(get_tcb p s = None) = (\<not>tcb_at p s)"
  by (auto simp: get_tcb_def obj_at_def is_tcb_def split: kernel_object.splits option.splits)

(* FIXME: move *)
lemma get_tcb_Some_ko_at:
  "(get_tcb p s = Some t) = ko_at (TCB t) p s"
  by (auto simp: get_tcb_def obj_at_def is_tcb_def split: kernel_object.splits option.splits)

lemma dissociate_vcpu_tcb_sym_refs_hyp[wp]:
  "\<lbrace>\<lambda>s. sym_refs (state_hyp_refs_of s)\<rbrace> dissociate_vcpu_tcb vr t \<lbrace>\<lambda>rv s. sym_refs (state_hyp_refs_of s)\<rbrace>"
  apply (simp add: dissociate_vcpu_tcb_def arch_get_sanitise_register_info_def)
  apply (wp arch_thread_set_wp set_vcpu_wp)
       apply (rule_tac Q="\<lambda>_ s. obj_at (\<lambda>ko. \<exists>tcb. ko = TCB tcb \<and> tcb_vcpu (tcb_arch tcb) = Some vr) t s
                             \<and> sym_refs (state_hyp_refs_of s)" in hoare_post_imp)
        apply clarsimp
        apply (clarsimp simp: get_tcb_Some_ko_at obj_at_def sym_refs_vcpu_None split: if_splits)
       apply (wp get_vcpu_wp arch_thread_get_wp)+
  apply clarsimp
  apply (rule conjI, clarsimp simp: obj_at_def)
  apply clarsimp
  apply (clarsimp simp: get_tcb_Some_ko_at obj_at_def sym_refs_vcpu_None split: if_splits)
  done

crunch valid_objs[wp]: dissociate_vcpu_tcb "valid_objs"
  (wp: crunch_wps simp: crunch_simps valid_obj_def valid_vcpu_def ignore: arch_thread_set)

lemma set_vcpu_unlive_hyp[wp]:
 "\<lbrace>\<lambda>s. vr \<noteq> t \<longrightarrow> obj_at (Not \<circ> hyp_live) t s\<rbrace>
  set_vcpu vr (vcpu_tcb_update Map.empty v) \<lbrace>\<lambda>rv. obj_at (Not \<circ> hyp_live) t\<rbrace>"
  apply (wpsimp wp: set_vcpu_wp)
  apply (clarsimp simp: obj_at_def hyp_live_def arch_live_def)
  done

lemma arch_thread_set_unlive_hyp[wp]:
  "\<lbrace>\<lambda>s. vr \<noteq> t \<longrightarrow> obj_at (Not \<circ> hyp_live) vr s\<rbrace>
  arch_thread_set (tcb_vcpu_update Map.empty) t \<lbrace>\<lambda>_. obj_at (Not \<circ> hyp_live) vr\<rbrace>"
  apply (wpsimp simp: arch_thread_set_def wp: set_object_wp)
  apply (clarsimp simp: obj_at_def hyp_live_def)
  done

lemma as_user_unlive_hyp[wp]:
  "\<lbrace>obj_at (Not \<circ> hyp_live) vr\<rbrace> as_user t f \<lbrace>\<lambda>_. obj_at (Not \<circ> hyp_live) vr\<rbrace>"
  unfolding as_user_def
  by (wpsimp wp: set_object_wp)
     (clarsimp simp: obj_at_def hyp_live_def get_tcb_Some_ko_at arch_tcb_context_set_def)

lemma dissociate_vcpu_tcb_unlive_hyp_vr[wp]:
  "\<lbrace>\<top>\<rbrace> dissociate_vcpu_tcb vr t \<lbrace> \<lambda>_. obj_at (Not \<circ> hyp_live) vr\<rbrace>"
  unfolding dissociate_vcpu_tcb_def arch_get_sanitise_register_info_def
  by (wpsimp wp: get_vcpu_wp hoare_vcg_const_imp_lift hoare_drop_imps)

lemma dissociate_vcpu_tcb_unlive_hyp_t[wp]:
  "\<lbrace>\<top>\<rbrace> dissociate_vcpu_tcb vr t \<lbrace> \<lambda>_. obj_at (Not \<circ> hyp_live) t\<rbrace>"
  unfolding dissociate_vcpu_tcb_def arch_get_sanitise_register_info_def
  by (wpsimp wp: hoare_vcg_const_imp_lift hoare_drop_imps get_vcpu_wp)

lemma arch_thread_set_unlive0[wp]:
  "\<lbrace>obj_at (Not \<circ> live0) vr\<rbrace> arch_thread_set (tcb_vcpu_update Map.empty) t \<lbrace>\<lambda>_. obj_at (Not \<circ> live0) vr\<rbrace>"
  apply (wpsimp simp: arch_thread_set_def wp: set_object_wp)
  apply (clarsimp simp: obj_at_def get_tcb_def split: kernel_object.splits)
  done

lemma set_vcpu_unlive0[wp]:
 "\<lbrace>obj_at (Not \<circ> live0) t\<rbrace> set_vcpu vr v \<lbrace>\<lambda>rv. obj_at (Not \<circ> live0) t\<rbrace>"
  by (wpsimp wp: set_vcpu_wp simp: obj_at_def)

lemma as_user_unlive0[wp]:
  "\<lbrace>obj_at (Not \<circ> live0) vr\<rbrace> as_user t f \<lbrace>\<lambda>_. obj_at (Not \<circ> live0) vr\<rbrace>"
  unfolding as_user_def
  apply (wpsimp wp: set_object_wp)
  by (clarsimp simp: obj_at_def arch_tcb_context_set_def dest!: get_tcb_SomeD)

lemma o_def_not: "obj_at (\<lambda>a. \<not> P a) t s =  obj_at (Not o P) t s"
  by (simp add: obj_at_def)

crunch unlive0: dissociate_vcpu_tcb "obj_at (Not \<circ> live0) t"
  (wp: crunch_wps simp: o_def_not ignore: arch_thread_set)

lemma arch_thread_set_if_live_then_nonz_cap':
  "\<forall>y. hyp_live (TCB (y\<lparr>tcb_arch := p (tcb_arch y)\<rparr>)) \<longrightarrow> hyp_live (TCB y) \<Longrightarrow>
   \<lbrace>if_live_then_nonz_cap\<rbrace> arch_thread_set p v \<lbrace>\<lambda>rv. if_live_then_nonz_cap\<rbrace>"
  apply (simp add: arch_thread_set_def)
  apply (wp set_object_iflive)
  apply (clarsimp simp: ex_nonz_cap_to_def if_live_then_nonz_cap_def
                  dest!: get_tcb_SomeD)
  apply (subst get_tcb_rev, assumption, subst option.sel)+
  apply (clarsimp simp: obj_at_def tcb_cap_cases_def)
  apply (erule_tac x=v in allE, drule mp; assumption?)
  apply (clarsimp simp: live_def)
  done

lemma arch_thread_set_if_live_then_nonz_cap_None[wp]:
  "\<lbrace>if_live_then_nonz_cap\<rbrace> arch_thread_set (tcb_vcpu_update Map.empty) t \<lbrace>\<lambda>rv. if_live_then_nonz_cap\<rbrace>"
  apply (wp arch_thread_set_if_live_then_nonz_cap')
   apply (clarsimp simp: hyp_live_def)
  apply assumption
  done

lemma set_vcpu_if_live_then_nonz_cap_same_refs:
  "\<lbrace>if_live_then_nonz_cap and obj_at (\<lambda>ko'. hyp_refs_of ko' = hyp_refs_of (ArchObj (VCPU v))) p\<rbrace>
     set_vcpu p v \<lbrace>\<lambda>rv. if_live_then_nonz_cap\<rbrace>"
  apply (simp add: set_vcpu_def)
  including unfold_objects
  apply (wpsimp wp: set_object_iflive[THEN hoare_set_object_weaken_pre]
              simp: a_type_def live_def hyp_live_def arch_live_def)
  apply (rule if_live_then_nonz_capD; simp)
  apply (clarsimp simp: live_def hyp_live_def arch_live_def,
         clarsimp simp: vcpu_tcb_refs_def split: option.splits)
  done

lemma vgic_update_if_live_then_nonz_cap[wp]:
  "\<lbrace>if_live_then_nonz_cap\<rbrace> vgic_update vcpuptr f \<lbrace>\<lambda>_. if_live_then_nonz_cap\<rbrace>"
  unfolding vgic_update_def vcpu_update_def
  apply (wp set_vcpu_if_live_then_nonz_cap_same_refs get_vcpu_wp)
  apply (clarsimp simp: obj_at_def in_omonad)
  done

lemma vcpu_save_reg_if_live_then_nonz_cap[wp]:
  "\<lbrace>if_live_then_nonz_cap\<rbrace> vcpu_save_reg vcpuptr r \<lbrace>\<lambda>_. if_live_then_nonz_cap\<rbrace>"
  unfolding vcpu_save_reg_def vcpu_update_def
  apply (wpsimp wp: set_vcpu_if_live_then_nonz_cap_same_refs get_vcpu_wp
                    hoare_vcg_imp_lift hoare_vcg_all_lift)
  apply (simp add: obj_at_def in_omonad)
  done

lemma vcpu_update_regs_if_live_then_nonz_cap[wp]:
  "vcpu_update vcpu_ptr (vcpu_regs_update f) \<lbrace>if_live_then_nonz_cap\<rbrace>"
  unfolding vcpu_update_def
  by (wpsimp wp: set_vcpu_if_live_then_nonz_cap_same_refs get_vcpu_wp)
     (simp add: obj_at_def in_omonad)

lemma vcpu_write_if_live_then_nonz_cap[wp]:
  "vcpu_write_reg vcpu_ptr reg val \<lbrace>if_live_then_nonz_cap\<rbrace>"
  unfolding vcpu_write_reg_def by (wpsimp cong: vcpu.fold_congs)

lemma vcpu_update_vtimer_if_live_then_nonz_cap[wp]:
  "vcpu_update vcpu_ptr (vcpu_vtimer_update f) \<lbrace>if_live_then_nonz_cap\<rbrace>"
  unfolding vcpu_update_def
  by (wpsimp wp: set_vcpu_if_live_then_nonz_cap_same_refs get_vcpu_wp)
     (simp add: obj_at_def in_omonad)

crunches vcpu_disable, vcpu_invalidate_active
  for if_live_then_nonz_cap[wp]: if_live_then_nonz_cap
  (ignore: vcpu_update)

lemma dissociate_vcpu_tcb_if_live_then_nonz_cap[wp]:
  "\<lbrace>if_live_then_nonz_cap\<rbrace> dissociate_vcpu_tcb vr t \<lbrace>\<lambda>rv. if_live_then_nonz_cap\<rbrace>"
  unfolding dissociate_vcpu_tcb_def arch_get_sanitise_register_info_def
  by (wpsimp wp: get_vcpu_wp arch_thread_get_wp hoare_drop_imps)

lemma vcpu_invalidate_active_ivs[wp]: "\<lbrace>invs\<rbrace> vcpu_invalidate_active \<lbrace>\<lambda>_. invs\<rbrace>"
  unfolding vcpu_invalidate_active_def
  by (wpsimp simp: cur_vcpu_at_def | strengthen invs_current_vcpu_update')+

crunch cur_tcb[wp]: dissociate_vcpu_tcb "cur_tcb"
  (wp: crunch_wps)

crunches dissociate_vcpu_tcb
  for cur_thread[wp]: "\<lambda>s. P (cur_thread s)"
  (wp: crunch_wps)

lemma same_caps_tcb_arch_update[simp]:
  "same_caps (TCB (tcb_arch_update f tcb)) = same_caps (TCB tcb)"
  by (rule ext) (clarsimp simp: tcb_cap_cases_def)

crunches dissociate_vcpu_tcb
  for cap_refs_respects_device_region[wp]: "cap_refs_respects_device_region"
  (wp: crunch_wps cap_refs_respects_device_region_dmo
   simp: crunch_simps read_cntpct_def maskInterrupt_def
   ignore: do_machine_op)

crunch pspace_respects_device_region[wp]: dissociate_vcpu_tcb "pspace_respects_device_region"
  (wp: crunch_wps)

crunch cap_refs_in_kernel_window[wp]: dissociate_vcpu_tcb "cap_refs_in_kernel_window"
  (wp: crunch_wps simp: crunch_simps)

crunch pspace_in_kernel_window[wp]: dissociate_vcpu_tcb "pspace_in_kernel_window"
  (wp: crunch_wps)

lemma valid_asid_map_arm_current_vcpu_update[simp]:
  "valid_asid_map (s\<lparr>arch_state := arm_current_vcpu_update f (arch_state s)\<rparr>) = valid_asid_map s"
  by (simp add: valid_asid_map_def vspace_at_asid_def)

crunch valid_asid_map[wp]: dissociate_vcpu_tcb "valid_asid_map"
  (wp: crunch_wps)

crunch valid_kernel_mappings[wp]: dissociate_vcpu_tcb "valid_kernel_mappings"
  (wp: crunch_wps)

crunch valid_arch_caps[wp]: dissociate_vcpu_tcb "valid_arch_caps"
  (wp: crunch_wps)

crunch valid_vspace_objs[wp]: dissociate_vcpu_tcb "valid_vspace_objs"
  (wp: crunch_wps)

crunch valid_irq_handlers[wp]: dissociate_vcpu_tcb "valid_irq_handlers"
  (wp: crunch_wps ignore: do_machine_op)

lemma as_user_valid_irq_node[wp]:
  "\<lbrace>valid_irq_node\<rbrace> as_user t f \<lbrace>\<lambda>_. valid_irq_node\<rbrace>"
  unfolding as_user_def
  apply (wpsimp wp: set_object_wp)
  apply (clarsimp simp: valid_irq_node_def obj_at_def is_cap_table dest!: get_tcb_SomeD)
  by (metis kernel_object.distinct(1) option.inject)

crunch valid_irq_node[wp]: dissociate_vcpu_tcb "valid_irq_node"
  (wp: crunch_wps)

lemma dmo_maskInterrupt_True_valid_irq_states[wp]:
  "do_machine_op (maskInterrupt True irq) \<lbrace>valid_irq_states\<rbrace>"
  unfolding valid_irq_states_def do_machine_op_def maskInterrupt_def
  apply wpsimp
  apply (erule use_valid)
   apply (wpsimp simp: valid_irq_masks_def)+
  done

crunches vcpu_save_reg, vgic_update, vcpu_disable
  for valid_irq_states[wp]: valid_irq_states
  and in_user_frame[wp]: "in_user_frame p"
  (wp: dmo_maskInterrupt_True_valid_irq_states dmo_valid_irq_states
   simp: isb_def setHCR_def setSCTLR_def set_gic_vcpu_ctrl_hcr_def getSCTLR_def
         get_gic_vcpu_ctrl_hcr_def dsb_def readVCPUHardwareReg_def writeVCPUHardwareReg_def
         read_cntpct_def maskInterrupt_def check_export_arch_timer_def)

lemma dmo_writeVCPUHardwareReg_valid_machine_state[wp]:
  "do_machine_op (writeVCPUHardwareReg r v) \<lbrace>valid_machine_state\<rbrace>"
  unfolding valid_machine_state_def
  by (wpsimp wp: hoare_vcg_all_lift hoare_vcg_disj_lift dmo_machine_state_lift)

crunches vgic_update, vcpu_update, vcpu_write_reg, vcpu_save_reg, save_virt_timer
  for in_user_frame[wp]: "in_user_frame p"
  and valid_machine_state[wp]: valid_machine_state
  and underlying_memory[wp]: "\<lambda>s. P (underlying_memory (machine_state s))"
  (simp: readVCPUHardwareReg_def read_cntpct_def
   wp: writeVCPUHardwareReg_underlying_memory_inv dmo_machine_state_lift
   ignore: do_machine_op)

lemma vcpu_disable_valid_machine_state[wp]:
  "\<lbrace>valid_machine_state\<rbrace> vcpu_disable vcpu_opt \<lbrace>\<lambda>_. valid_machine_state\<rbrace>"
  unfolding vcpu_disable_def valid_machine_state_def
  by (wpsimp wp: dmo_machine_state_lift hoare_vcg_all_lift hoare_vcg_disj_lift
             simp: isb_def setHCR_def setSCTLR_def set_gic_vcpu_ctrl_hcr_def getSCTLR_def
                   get_gic_vcpu_ctrl_hcr_def dsb_def writeVCPUHardwareReg_def maskInterrupt_def)

lemma valid_arch_state_vcpu_update_str:
  "valid_arch_state s \<Longrightarrow> valid_arch_state (s\<lparr>arch_state := arm_current_vcpu_update Map.empty (arch_state s)\<rparr>)"
  unfolding valid_arch_state_def
  by (clarsimp simp: cur_vcpu_def valid_global_arch_objs_def)

lemma valid_global_refs_vcpu_update_str:
  "valid_global_refs s \<Longrightarrow> valid_global_refs (s\<lparr>arch_state := arm_current_vcpu_update f (arch_state s)\<rparr>)"
  by (simp add: valid_global_refs_def global_refs_def)

lemma set_vcpu_None_valid_arch[wp]:
  "\<lbrace>valid_arch_state and (\<lambda>s. \<forall>a. arm_current_vcpu (arch_state s) \<noteq> Some (vr, a))\<rbrace>
  set_vcpu vr (vcpu_tcb_update Map.empty v) \<lbrace>\<lambda>_. valid_arch_state\<rbrace>"
  supply fun_upd_apply[simp del]
  apply (wpsimp wp: set_vcpu_wp)
  apply (clarsimp simp: valid_arch_state_def valid_global_arch_objs_def pts_of_vcpu_None_upd_idem
                        asid_pools_of_vcpu_None_upd_idem vmid_inv_def pt_at_eq_set_vcpu)
  apply (clarsimp simp add: cur_vcpu_def fun_upd_apply in_opt_pred split: option.splits)
  done

lemma dissociate_vcpu_valid_arch[wp]:
  "\<lbrace>valid_arch_state\<rbrace> dissociate_vcpu_tcb vr t \<lbrace>\<lambda>_. valid_arch_state\<rbrace>"
  unfolding dissociate_vcpu_tcb_def vcpu_invalidate_active_def arch_get_sanitise_register_info_def
  by (wpsimp wp: get_vcpu_wp arch_thread_get_wp
       | strengthen valid_arch_state_vcpu_update_str | wp (once) hoare_drop_imps)+

lemma as_user_valid_irq_states[wp]:
  "\<lbrace>valid_irq_states\<rbrace> as_user t f \<lbrace>\<lambda>rv. valid_irq_states\<rbrace>"
  unfolding as_user_def
  by (wpsimp wp: set_object_wp simp: obj_at_def valid_irq_states_def)

lemma as_user_ioc[wp]:
  "\<lbrace>\<lambda>s. P (is_original_cap s)\<rbrace> as_user t f \<lbrace>\<lambda>rv s. P (is_original_cap s)\<rbrace>"
  unfolding as_user_def by (wpsimp wp: set_object_wp)

lemma as_user_valid_ioc[wp]:
  "\<lbrace>valid_ioc\<rbrace> as_user t f \<lbrace>\<lambda>rv. valid_ioc\<rbrace>"
  unfolding valid_ioc_def by (wpsimp wp: hoare_vcg_imp_lift hoare_vcg_all_lift)

lemma dissociate_vcpu_tcb_invs[wp]: "\<lbrace>invs\<rbrace> dissociate_vcpu_tcb vr t \<lbrace>\<lambda>_. invs\<rbrace>"
  apply (simp add: invs_def valid_state_def valid_pspace_def)
  apply (simp add: pred_conj_def)
  apply (rule hoare_vcg_conj_lift[rotated])+
  apply (wpsimp wp: weak_if_wp get_vcpu_wp arch_thread_get_wp as_user_only_idle arch_thread_set_valid_idle
         | simp add: dissociate_vcpu_tcb_def vcpu_invalidate_active_def arch_get_sanitise_register_info_def
         | strengthen valid_arch_state_vcpu_update_str valid_global_refs_vcpu_update_str
         | simp add: vcpu_disable_def valid_global_vspace_mappings_def valid_global_objs_def
         | wp (once) hoare_drop_imps)+
  done

crunch invs[wp]: vcpu_finalise invs
  (ignore: dissociate_vcpu_tcb)

lemma arch_finalise_cap_invs' [wp,Finalise_AI_asms]:
  "\<lbrace>invs and valid_cap (ArchObjectCap cap)\<rbrace>
     arch_finalise_cap cap final
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: arch_finalise_cap_def)
  apply (rule hoare_pre)
   apply (wp unmap_page_invs | wpc)+
  apply (clarsimp simp: valid_cap_def cap_aligned_def)
  apply (auto simp: mask_def vmsz_aligned_def wellformed_mapdata_def)
  done

lemma arch_thread_set_unlive_other:
  "\<lbrace>\<lambda>s. vr \<noteq> t \<and> obj_at (Not \<circ> live) vr s\<rbrace> arch_thread_set (tcb_vcpu_update Map.empty) t \<lbrace>\<lambda>_. obj_at (Not \<circ> live) vr\<rbrace>"
  apply (wpsimp simp: arch_thread_set_def wp: set_object_wp)
  apply (clarsimp simp: obj_at_def)
  done

lemma set_vcpu_unlive[wp]:
  "\<lbrace>\<top>\<rbrace> set_vcpu vr (vcpu_tcb_update Map.empty v) \<lbrace>\<lambda>rv. obj_at (Not \<circ> live) vr\<rbrace>"
  apply (wp set_vcpu_wp)
  apply (clarsimp simp: obj_at_def live_def hyp_live_def arch_live_def)
  done

lemma as_user_unlive[wp]:
  "\<lbrace>obj_at (Not \<circ> live) vr\<rbrace> as_user t f \<lbrace>\<lambda>_. obj_at (Not \<circ> live) vr\<rbrace>"
  unfolding as_user_def
  apply (wpsimp wp: set_object_wp)
  by (clarsimp simp: obj_at_def live_def hyp_live_def arch_tcb_context_set_def dest!: get_tcb_SomeD)

lemma dissociate_vcpu_tcb_unlive_v:
  "\<lbrace>\<top>\<rbrace> dissociate_vcpu_tcb vr t \<lbrace> \<lambda>_. obj_at (Not \<circ> live) vr\<rbrace>"
  unfolding dissociate_vcpu_tcb_def
  by (wpsimp wp: arch_thread_set_unlive_other get_vcpu_wp arch_thread_get_wp hoare_drop_imps
           simp:  bind_assoc)

lemma vcpu_finalise_unlive:
  "\<lbrace>\<top>\<rbrace> vcpu_finalise r \<lbrace> \<lambda>_. obj_at (Not \<circ> live) r \<rbrace>"
  apply (wpsimp simp: vcpu_finalise_def wp: dissociate_vcpu_tcb_unlive_v get_vcpu_wp)
  apply (auto simp: obj_at_def in_omonad live_def hyp_live_def arch_live_def)
  done

lemma arch_finalise_cap_vcpu:
  notes strg = tcb_cap_valid_imp_NullCap
               vcpu_finalise_unlive[simplified o_def]
  notes simps = replaceable_def
                is_cap_simps vs_cap_ref_def
                no_cap_to_obj_with_diff_ref_Null o_def
  notes wps = hoare_drop_imp[where R="%_. is_final_cap' cap" for cap]
              valid_cap_typ
  shows
  "cap = VCPUCap r \<Longrightarrow> \<lbrace>\<lambda>s. s \<turnstile> cap.ArchObjectCap cap \<and>
          x = is_final_cap' (cap.ArchObjectCap cap) s \<and>
          pspace_aligned s \<and> valid_vspace_objs s \<and> valid_objs s \<and>
          valid_asid_table s\<rbrace>
     arch_finalise_cap cap x
   \<lbrace>\<lambda>rv s. replaceable s sl (fst rv) (cap.ArchObjectCap cap)\<rbrace>"
  apply (simp add: arch_finalise_cap_def)
  apply (wpsimp wp: wps simp: simps reachable_frame_cap_def | strengthen strg)+
  done

lemma obj_at_not_live_valid_arch_cap_strg [Finalise_AI_asms]:
  "(s \<turnstile> ArchObjectCap cap \<and> aobj_ref cap = Some r \<and> \<not> typ_at (AArch AVCPU) r s)
        \<longrightarrow> obj_at (\<lambda>ko. \<not> live ko) r s"
  by (clarsimp simp: live_def valid_cap_def valid_arch_cap_ref_def obj_at_def a_type_arch_live
                     valid_cap_simps hyp_live_def arch_live_def
              split: arch_cap.split_asm if_splits)

lemma obj_at_not_live_valid_arch_cap_strg' [Finalise_AI_asms]:
  "(s \<turnstile> ArchObjectCap cap \<and> aobj_ref cap = Some r \<and> cap \<noteq> VCPUCap r)
        \<longrightarrow> obj_at (\<lambda>ko. \<not> live ko) r s"
  by (clarsimp simp: live_def valid_cap_def valid_arch_cap_ref_def obj_at_def
                     hyp_live_def arch_live_def
              split: arch_cap.split_asm if_splits)

crunches set_vm_root
  for ptes_of[wp]: "\<lambda>s. P (ptes_of s)"
  and asid_table[wp]: "\<lambda>s. P (asid_table s)"
  (simp: crunch_simps)

lemma vs_lookup_table_lift_strong:
  assumes "\<And>P. f \<lbrace>\<lambda>s. P (ptes_of s)\<rbrace>"
  assumes "\<And>P ap_ptr. f \<lbrace>\<lambda>s. P (vspace_for_pool ap_ptr asid (asid_pools_of s))\<rbrace>"
  assumes "\<And>P. f \<lbrace>\<lambda>s. P (asid_table s)\<rbrace>"
  shows "f \<lbrace>\<lambda>s. P (vs_lookup_table level asid vref s)\<rbrace>"
  apply (simp add: vs_lookup_table_def obind_def split: option.splits)
  apply (wpsimp wp: hoare_vcg_all_lift hoare_vcg_ex_lift hoare_vcg_imp_lift' pool_for_asid_lift assms
                simp: not_le)
  done

lemma vs_lookup_slot_lift_strong:
  assumes "\<And>P. f \<lbrace>\<lambda>s. P (ptes_of s)\<rbrace>"
  assumes "\<And>P ap_ptr. f \<lbrace>\<lambda>s. P (vspace_for_pool ap_ptr asid (asid_pools_of s))\<rbrace>"
  assumes "\<And>P. f \<lbrace>\<lambda>s. P (asid_table s)\<rbrace>"
  shows "f \<lbrace>\<lambda>s. P (vs_lookup_slot level asid vref s)\<rbrace>"
  apply (simp add: vs_lookup_slot_def obind_def split: option.splits)
  apply (wpsimp wp: assms hoare_vcg_all_lift hoare_vcg_ex_lift hoare_vcg_imp_lift' pool_for_asid_lift
                    vs_lookup_table_lift_strong
                simp: not_le)
  done

lemma vs_lookup_target_lift_strong:
  assumes "\<And>P. f \<lbrace>\<lambda>s. P (ptes_of s)\<rbrace>"
  assumes "\<And>P ap_ptr. f \<lbrace>\<lambda>s. P (vspace_for_pool ap_ptr asid (asid_pools_of s))\<rbrace>"
  assumes "\<And>P. f \<lbrace>\<lambda>s. P (asid_table s)\<rbrace>"
  shows "f \<lbrace>\<lambda>s. P (vs_lookup_target level asid vref s)\<rbrace>"
  apply (simp add: vs_lookup_target_def obind_def split: option.splits)
  apply (wpsimp wp: assms hoare_vcg_all_lift hoare_vcg_ex_lift hoare_vcg_imp_lift' pool_for_asid_lift
                    vs_lookup_slot_lift_strong
                simp: not_le)
  done

lemma update_asid_pool_entry_vspace_for_pool:
  "\<lbrace>\<lambda>s. (\<forall>entry. f entry \<noteq> None \<and> ap_vspace (the (f entry)) = ap_vspace entry) \<and>
        P (vspace_for_pool ap_ptr asid (asid_pools_of s))\<rbrace>
   update_asid_pool_entry f asid'
   \<lbrace>\<lambda>_ s. P (vspace_for_pool ap_ptr asid (asid_pools_of s)) \<rbrace>"
  unfolding update_asid_pool_entry_def
  apply (wpsimp simp_del: fun_upd_apply)
  apply (erule rsubst[where P=P])
  apply (simp add: vspace_for_pool_def entry_for_pool_def obind_def split: option.splits)
  by (metis if_option_None_eq(2) option.sel)

crunches get_vmid, set_vm_root
  for vspace_for_pool[wp]: "\<lambda>s. P (vspace_for_pool ap_ptr asid (asid_pools_of s))"
  (simp: crunch_simps
   wp: update_asid_pool_entry_vspace_for_pool
   wp_del: update_asid_pool_entry_asid_pools
   ignore: update_asid_pool_entry)

lemma set_vm_root_vs_lookup_target[wp]:
  "set_vm_root tcb \<lbrace>\<lambda>s. P (vs_lookup_target level asid vref s)\<rbrace>"
  by (wp vs_lookup_target_lift_strong)

lemma vs_lookup_target_no_asid_pool:
  "\<lbrakk>asid_pool_at ptr s; valid_vspace_objs s; valid_asid_table s; pspace_aligned s;
    vs_lookup_target level asid 0 s = Some (level, ptr)\<rbrakk>
   \<Longrightarrow> False"
  apply (clarsimp simp: vs_lookup_target_def split: if_split_asm)
   apply (clarsimp simp: vs_lookup_slot_def vs_lookup_table_def obj_at_def)
   apply (frule (1) pool_for_asid_validD, clarsimp)
   apply (subst (asm) pool_for_asid_vs_lookup[symmetric, where vref=0 and level=asid_pool_level, simplified])
   apply (drule (1) valid_vspace_objsD; simp add: in_omonad)
   apply (fastforce simp: vspace_for_pool_def in_omonad obj_at_def ran_def entry_for_pool_def)
  apply (rename_tac pt_ptr)
  apply (clarsimp simp: vs_lookup_slot_def obj_at_def split: if_split_asm)
  apply (clarsimp simp: in_omonad)
  apply (frule (1) vs_lookup_table_is_aligned; clarsimp?)
  apply (clarsimp simp: ptes_of_def)
  apply (rename_tac pt)
  apply (drule (1) valid_vspace_objsD; simp add: in_omonad)
  apply (simp add: is_aligned_mask pt_range_def)
  apply (erule_tac x=0 in allE)
  apply (clarsimp simp: pte_ref_def data_at_def obj_at_def split: pte.splits)
  apply (simp add: pptr_from_pte_def)
  done

lemma vs_lookup_target_clear_asid_strg:
  "table = asid_table s \<Longrightarrow>
   vs_lookup_target level asid 0
                    (s\<lparr>arch_state := (arch_state s) \<lparr>arm_asid_table :=
                                                      table (asid_high_bits_of asid := None)\<rparr>\<rparr>)
   = None"
  by (clarsimp simp: vs_lookup_target_def vs_lookup_slot_def vs_lookup_table_def pool_for_asid_def
                     obind_def)

lemma delete_asid_pool_not_target[wp]:
  "\<lbrace>asid_pool_at ptr and valid_vspace_objs and valid_asid_table and pspace_aligned\<rbrace>
   delete_asid_pool asid ptr
   \<lbrace>\<lambda>rv s. vs_lookup_target level asid 0 s \<noteq> Some (level, ptr)\<rbrace>"
  unfolding delete_asid_pool_def
  supply fun_upd_apply[simp del]
  apply (wpsimp)
      apply (strengthen vs_lookup_target_clear_asid_strg[THEN None_Some_strg])
      apply (wpsimp wp: mapM_wp' get_asid_pool_wp)+
  apply (erule (4) vs_lookup_target_no_asid_pool)
  done

lemma delete_asid_pool_not_reachable[wp]:
  "\<lbrace>asid_pool_at ptr and valid_vspace_objs and valid_asid_table and pspace_aligned\<rbrace>
   delete_asid_pool asid ptr
   \<lbrace>\<lambda>rv s. \<not> reachable_target (asid, 0) ptr s\<rbrace>"
  unfolding reachable_target_def by (wpsimp wp: hoare_vcg_all_lift)

lemmas reachable_frame_cap_simps =
  reachable_frame_cap_def[unfolded is_frame_cap_def arch_cap_fun_lift_def, split_simps cap.split]

lemma unmap_page_table_pool_for_asid[wp]:
  "unmap_page_table asid vref pt \<lbrace>\<lambda>s. P (pool_for_asid asid s)\<rbrace>"
  unfolding unmap_page_table_def by (wpsimp simp: pool_for_asid_def)

lemma unmap_page_table_unreachable:
  "\<lbrace> normal_pt_at pt
     and valid_asid_table and valid_vspace_objs and pspace_aligned and pspace_distinct
     and unique_table_refs and valid_vs_lookup and (\<lambda>s. valid_caps (caps_of_state s) s)
     and K (0 < asid \<and> vref \<in> user_region) \<rbrace>
   unmap_page_table asid vref pt
   \<lbrace>\<lambda>_ s. \<not> reachable_target (asid, vref) pt s\<rbrace>"
  unfolding reachable_target_def
  apply (wpsimp wp: hoare_vcg_all_lift unmap_page_table_not_target)
  apply (drule (1) pool_for_asid_validD)
  apply (clarsimp simp: obj_at_def in_omonad)
  done

lemma unmap_page_unreachable:
  "\<lbrace> data_at pgsz pptr and valid_asid_table and valid_vspace_objs
     and pspace_aligned and pspace_distinct
     and unique_table_refs and valid_vs_lookup and (\<lambda>s. valid_caps (caps_of_state s) s)
     and K (0 < asid \<and> vref \<in> user_region) \<rbrace>
   unmap_page pgsz asid vref pptr
   \<lbrace>\<lambda>rv s. \<not> reachable_target (asid, vref) pptr s\<rbrace>"
  unfolding reachable_target_def
  apply (wpsimp wp: hoare_vcg_all_lift unmap_page_not_target)
  apply (drule (1) pool_for_asid_validD)
  apply (clarsimp simp: obj_at_def data_at_def in_omonad)
  done

lemma set_asid_pool_pool_for_asid[wp]:
  "set_asid_pool ptr pool \<lbrace>\<lambda>s. P (pool_for_asid asid' s)\<rbrace>"
  unfolding pool_for_asid_def by wpsimp

lemma delete_asid_pool_for_asid[wp]:
  "delete_asid asid pt \<lbrace>\<lambda>s. P (pool_for_asid asid' s)\<rbrace>"
  unfolding delete_asid_def by (wpsimp wp: hoare_drop_imps)

lemma delete_asid_no_vs_lookup_target_vspace:
  "\<lbrace>\<lambda>s. vspace_for_asid asid s = Some pt \<rbrace>
   delete_asid asid pt
   \<lbrace>\<lambda>rv s. vs_lookup_target level asid vref s \<noteq> Some (level, pt)\<rbrace>"
  apply (rule hoare_assume_pre)
  apply (prop_tac "0 < asid")
   apply (clarsimp simp: vspace_for_asid_def entry_for_asid_def)
  apply (rule hoare_strengthen_post, rule delete_asid_unmapped)
  apply (clarsimp simp: vs_lookup_target_def vs_lookup_slot_def vs_lookup_table_def
                        vspace_for_asid_def vspace_for_pool_def entry_for_asid_def obind_None_eq
                  split: if_split_asm)
  done

lemma delete_asid_no_vs_lookup_target_no_vspace:
  "\<lbrace>\<lambda>s. vspace_for_asid asid s \<noteq> Some pt \<and> 0 < asid \<and> vref \<in> user_region \<and> vspace_pt_at pt s \<and>
        valid_vspace_objs s \<and> valid_asid_table s \<and> pspace_aligned s \<rbrace>
   delete_asid asid pt
   \<lbrace>\<lambda>rv s. vs_lookup_target level asid vref s \<noteq> Some (level, pt)\<rbrace>"
  unfolding delete_asid_def
  (* We know we are in the case where delete_asid does not do anything *)
  apply (wpsimp wp: when_wp[where Q="\<lambda>_. False", simplified])
  apply (rule conjI, fastforce simp: vs_lookup_target_def vs_lookup_slot_def vs_lookup_table_def)
  (* pool_for_asid asid s \<noteq> None *)
  apply clarsimp
  apply (rename_tac ap pool)
  apply (rule conjI; clarsimp)
   apply (clarsimp simp: vspace_for_asid_def entry_for_asid_def entry_for_pool_def obind_def
                   split: option.splits if_split_asm)
  apply (clarsimp simp: vs_lookup_target_def vs_lookup_slot_pool_for_asid split: if_split_asm)
   (* asid_pool_level *)
   apply (fastforce simp: vspace_for_asid_def entry_for_asid_def vspace_for_pool_def obind_def
                    split: option.splits)
  apply (drule (5) valid_vspace_objs_strong_slotD)
  apply (clarsimp simp: in_omonad)
  apply (rename_tac pte)
  apply (case_tac pte; clarsimp simp: obj_at_def data_at_def)
  apply (simp add: pptr_from_pte_def)
  done

lemma delete_asid_no_vs_lookup_target:
  "\<lbrace>\<lambda>s. 0 < asid \<and> vref \<in> user_region \<and> vspace_pt_at pt s \<and> valid_vspace_objs s \<and>
        valid_asid_table s \<and> pspace_aligned s \<rbrace>
   delete_asid asid pt
   \<lbrace>\<lambda>rv s. vs_lookup_target level asid vref s \<noteq> Some (level, pt)\<rbrace>"
  by (rule hoare_pre_cases[where P="\<lambda>_.True", simplified,
                           OF delete_asid_no_vs_lookup_target_vspace
                              delete_asid_no_vs_lookup_target_no_vspace])

lemma delete_asid_unreachable:
  "\<lbrace>\<lambda>s. 0 < asid \<and> vref \<in> user_region \<and> vspace_pt_at pt s \<and> valid_vspace_objs s \<and>
        valid_asid_table s \<and> pspace_aligned s \<rbrace>
   delete_asid asid pt
   \<lbrace>\<lambda>_ s. \<not> reachable_target (asid, vref) pt s\<rbrace>"
  unfolding reachable_target_def
  apply (wpsimp wp: hoare_vcg_all_lift delete_asid_no_vs_lookup_target)
  apply (drule (1) pool_for_asid_validD)
  apply (clarsimp simp: obj_at_def in_omonad)
  done

lemma arch_finalise_cap_replaceable:
  notes strg = tcb_cap_valid_imp_NullCap
               obj_at_not_live_valid_arch_cap_strg[where cap=cap]
  notes simps = replaceable_def and_not_not_or_imp
                is_cap_simps vs_cap_ref_def
                no_cap_to_obj_with_diff_ref_Null o_def
                reachable_frame_cap_simps
  notes wps = hoare_drop_imp[where R="%_. is_final_cap' cap" for cap]
              valid_cap_typ
              unmap_page_unreachable unmap_page_table_unreachable
              delete_asid_unreachable vcpu_finalise_unlive[simplified o_def]
  shows
    "\<lbrace>\<lambda>s. s \<turnstile> ArchObjectCap cap \<and>
          x = is_final_cap' (ArchObjectCap cap) s \<and>
          pspace_aligned s \<and> pspace_distinct s \<and>
          valid_vspace_objs s \<and> valid_objs s \<and> valid_asid_table s \<and> valid_arch_caps s\<rbrace>
     arch_finalise_cap cap x
     \<lbrace>\<lambda>rv s. replaceable s sl (fst rv) (ArchObjectCap cap)\<rbrace>"
  apply (simp add: arch_finalise_cap_def valid_arch_caps_def)
  apply (wpsimp simp: simps valid_objs_caps wp: wps | strengthen strg)+
  apply (rule conjI, clarsimp)
   apply (in_case "ASIDPoolCap ?p ?asid")
   apply (clarsimp simp: valid_cap_def obj_at_def)
  apply (rule conjI, clarsimp)
   apply (in_case "FrameCap ?p ?R ?sz ?dev ?m")
   apply (fastforce simp: valid_cap_def wellformed_mapdata_def data_at_def obj_at_def
                    split: if_split_asm)
  apply clarsimp
  apply (in_case "PageTableCap ?p ?T ?m")
  apply (rule conjI; clarsimp)
   apply (in_case "PageTableCap ?p VSRootPT_T ?m")
   apply (rule conjI; clarsimp simp: valid_cap_def wellformed_mapdata_def data_at_def obj_at_def
                               split: if_split_asm)
  apply (in_case "PageTableCap ?p NormalPT_T ?m")
  apply (rule conjI; clarsimp)
   apply (clarsimp simp: valid_cap_def obj_at_def)
  apply (clarsimp simp: valid_cap_def wellformed_mapdata_def cap_aligned_def obj_at_def)
  done

global_naming Arch
lemma (* deleting_irq_handler_slot_not_irq_node *)[Finalise_AI_asms]:
  "\<lbrace>if_unsafe_then_cap and valid_global_refs
           and cte_wp_at (\<lambda>cp. cap_irqs cp \<noteq> {}) sl\<rbrace>
     deleting_irq_handler irq
   \<lbrace>\<lambda>rv s. (interrupt_irq_node s irq, []) \<noteq> sl\<rbrace>"
  apply (simp add: deleting_irq_handler_def)
  apply wp
  apply clarsimp
  apply (drule(1) if_unsafe_then_capD)
   apply clarsimp
  apply (clarsimp simp: ex_cte_cap_wp_to_def cte_wp_at_caps_of_state)
  apply (drule cte_refs_obj_refs_elem)
  apply (erule disjE)
   apply simp
   apply (drule(1) valid_global_refsD[OF _ caps_of_state_cteD])
    prefer 2
    apply (erule notE, simp add: cap_range_def, erule disjI2)
   apply (simp add: global_refs_def)
  apply (clarsimp simp: appropriate_cte_cap_def split: cap.split_asm)
  done

lemma no_cap_to_obj_with_diff_ref_finalI_ARCH[Finalise_AI_asms]:
  "\<lbrakk> cte_wp_at ((=) cap) p s; is_final_cap' cap s;
            obj_refs cap' = obj_refs cap \<rbrakk>
      \<Longrightarrow> no_cap_to_obj_with_diff_ref cap' {p} s"
  apply (case_tac "obj_refs cap = {}")
   apply (case_tac "cap_irqs cap = {}")
    apply (case_tac "arch_gen_refs cap = {}")
     apply (simp add: is_final_cap'_def)
     apply (case_tac cap, simp_all add: gen_obj_refs_def)
    apply ((clarsimp simp add: no_cap_to_obj_with_diff_ref_def
                              cte_wp_at_caps_of_state
                              vs_cap_ref_def
                       dest!: obj_ref_none_no_asid[rule_format])+)[2]
  apply (clarsimp simp: no_cap_to_obj_with_diff_ref_def
                        is_final_cap'_def2
              simp del: split_paired_All)
  apply (frule_tac x=p in spec)
  apply (drule_tac x="(a, b)" in spec)
  apply (clarsimp simp: cte_wp_at_caps_of_state
                        gen_obj_refs_Int)
  done

lemma (* suspend_no_cap_to_obj_ref *)[wp,Finalise_AI_asms]:
  "\<lbrace>no_cap_to_obj_with_diff_ref cap S\<rbrace>
     suspend t
   \<lbrace>\<lambda>rv. no_cap_to_obj_with_diff_ref cap S\<rbrace>"
  apply (simp add: no_cap_to_obj_with_diff_ref_def
                   cte_wp_at_caps_of_state)
  apply (wp suspend_caps_of_state)
  apply (clarsimp dest!: obj_ref_none_no_asid[rule_format])
  done

lemma dissociate_vcpu_tcb_no_cap_to_obj_ref[wp]:
  "\<lbrace>no_cap_to_obj_with_diff_ref cap S\<rbrace>
     dissociate_vcpu_tcb v t
   \<lbrace>\<lambda>rv. no_cap_to_obj_with_diff_ref cap S\<rbrace>"
  by (wpsimp simp: no_cap_to_obj_with_diff_ref_def cte_wp_at_caps_of_state)

lemma prepare_thread_delete_no_cap_to_obj_ref[wp]:
  "\<lbrace>no_cap_to_obj_with_diff_ref cap S\<rbrace>
     prepare_thread_delete t
   \<lbrace>\<lambda>rv. no_cap_to_obj_with_diff_ref cap S\<rbrace>"
  unfolding prepare_thread_delete_def
  by (wpsimp simp: no_cap_to_obj_with_diff_ref_def cte_wp_at_caps_of_state)

lemma prepare_thread_delete_unlive_hyp:
  "\<lbrace>obj_at \<top> ptr\<rbrace> prepare_thread_delete ptr \<lbrace>\<lambda>rv. obj_at (Not \<circ> hyp_live) ptr\<rbrace>"
  apply (simp add: prepare_thread_delete_def fpu_thread_delete_def)
  apply (wpsimp wp: hoare_vcg_imp_lift' hoare_vcg_all_lift arch_thread_get_wp)
  apply (clarsimp simp: obj_at_def is_tcb_def hyp_live_def)
  done

lemma prepare_thread_delete_unlive0:
  "\<lbrace>obj_at (Not \<circ> live0) ptr\<rbrace> prepare_thread_delete ptr \<lbrace>\<lambda>rv. obj_at (Not \<circ> live0) ptr\<rbrace>"
  apply (simp add: prepare_thread_delete_def set_thread_state_def set_object_def fpu_thread_delete_def)
  apply (wpsimp wp: dissociate_vcpu_tcb_unlive0 simp: obj_at_exst_update comp_def)
  done

lemma prepare_thread_delete_unlive[wp]:
  "\<lbrace>obj_at (Not \<circ> live0) ptr\<rbrace> prepare_thread_delete ptr \<lbrace>\<lambda>rv. obj_at (Not \<circ> live) ptr\<rbrace>"
  apply (rule_tac Q="\<lambda>rv. obj_at (Not \<circ> live0) ptr and obj_at (Not \<circ> hyp_live) ptr" in hoare_strengthen_post)
  apply (wpsimp wp: hoare_vcg_conj_lift prepare_thread_delete_unlive_hyp prepare_thread_delete_unlive0)
   apply (clarsimp simp: obj_at_def)
  apply (clarsimp simp: obj_at_def, case_tac ko, simp_all add: is_tcb_def live_def)
  done

lemma finalise_cap_replaceable [Finalise_AI_asms]:
  "\<lbrace>\<lambda>s. s \<turnstile> cap \<and> x = is_final_cap' cap s \<and> valid_mdb s
        \<and> cte_wp_at ((=) cap) sl s \<and> valid_objs s \<and> sym_refs (state_refs_of s)
        \<and> (cap_irqs cap \<noteq> {} \<longrightarrow> if_unsafe_then_cap s \<and> valid_global_refs s)
        \<and> (is_arch_cap cap \<longrightarrow> pspace_aligned s \<and>
                               pspace_distinct s \<and>
                               valid_vspace_objs s \<and>
                               valid_arch_state s \<and>
                               valid_arch_caps s)\<rbrace>
     finalise_cap cap x
   \<lbrace>\<lambda>rv s. replaceable s sl (fst rv) cap\<rbrace>"
  apply (cases "is_arch_cap cap")
   apply (clarsimp simp: is_cap_simps)
   apply (wp arch_finalise_cap_replaceable)
   apply (clarsimp simp: replaceable_def reachable_frame_cap_def
                         o_def cap_range_def valid_arch_state_def
                         ran_tcb_cap_cases is_cap_simps
                         gen_obj_refs_subset vs_cap_ref_def
                         all_bool_eq)
  apply (cases cap;
           simp add: replaceable_def reachable_frame_cap_def is_arch_cap_def
                split del: if_split;
           ((wp suspend_unlive[unfolded o_def]
                suspend_final_cap[where sl=sl]
                prepare_thread_delete_unlive[unfolded o_def]
                unbind_maybe_notification_not_bound
                get_simple_ko_ko_at unbind_notification_valid_objs
             | clarsimp simp: o_def dom_tcb_cap_cases_lt_ARCH
                              ran_tcb_cap_cases is_cap_simps
                              cap_range_def unat_of_bl_length
                              can_fast_finalise_def
                              gen_obj_refs_subset
                              vs_cap_ref_def
                              valid_ipc_buffer_cap_def
                        dest!: tcb_cap_valid_NullCapD
                        split: Structures_A.thread_state.split_asm
             | simp cong: conj_cong
             | simp cong: rev_conj_cong add: no_cap_to_obj_with_diff_ref_Null
             | (strengthen tcb_cap_valid_imp_NullCap tcb_cap_valid_imp', wp)
             | rule conjI
             | erule cte_wp_at_weakenE tcb_cap_valid_imp'[rule_format, rotated -1]
             | erule(1) no_cap_to_obj_with_diff_ref_finalI_ARCH
             | (wp (once) hoare_drop_imps,
                        wp (once) cancel_all_ipc_unlive[unfolded o_def]
                       cancel_all_signals_unlive[unfolded o_def])
             | ((wp (once) hoare_drop_imps)?,
                (wp (once) hoare_drop_imps)?,
                wp (once) deleting_irq_handler_empty)
             | wpc
             | simp add: valid_cap_simps is_nondevice_page_cap_simps)+))
  done

lemma (* deleting_irq_handler_cte_preserved *)[Finalise_AI_asms]:
  assumes x: "\<And>cap. P cap \<Longrightarrow> \<not> can_fast_finalise cap"
  shows "\<lbrace>cte_wp_at P p\<rbrace> deleting_irq_handler irq \<lbrace>\<lambda>rv. cte_wp_at P p\<rbrace>"
  apply (simp add: deleting_irq_handler_def)
  apply (wp cap_delete_one_cte_wp_at_preserved | simp add: x)+
  done

lemma arch_thread_set_cte_wp_at[wp]:
  "\<lbrace>\<lambda>s. P (cte_wp_at P' p s)\<rbrace> arch_thread_set f t \<lbrace> \<lambda>_ s. P (cte_wp_at P' p s)\<rbrace>"
  apply (simp add: arch_thread_set_def)
  apply (wp set_object_wp)
  apply (clarsimp dest!: get_tcb_SomeD simp del: fun_upd_apply)
  apply (subst get_tcb_rev, assumption, subst option.sel)+
  apply (subst arch_tcb_update_aux3)
  apply (subst cte_wp_at_update_some_tcb[where f="tcb_arch_update f"])
    apply (clarsimp simp: tcb_cnode_map_def)+
  done

crunch cte_wp_at[wp,Finalise_AI_asms]: dissociate_vcpu_tcb "\<lambda>s. P (cte_wp_at P' p s)"
  (simp: crunch_simps assertE_def wp: crunch_wps set_object_cte_at ignore: arch_thread_set)

crunch cte_wp_at[wp,Finalise_AI_asms]: prepare_thread_delete "\<lambda>s. P (cte_wp_at P' p s)"
  (simp: crunch_simps assertE_def wp: crunch_wps set_object_cte_at ignore: arch_thread_set)

crunch cte_wp_at[wp,Finalise_AI_asms]: arch_finalise_cap "\<lambda>s. P (cte_wp_at P' p s)"
  (simp: crunch_simps assertE_def wp: crunch_wps set_object_cte_at ignore: arch_thread_set)

end

interpretation Finalise_AI_1?: Finalise_AI_1
  proof goal_cases
  interpret Arch .
  case 1 show ?case
    by (intro_locales; (unfold_locales; fact Finalise_AI_asms)?)
  qed

context Arch begin global_naming AARCH64

lemma fast_finalise_replaceable[wp]:
  "\<lbrace>\<lambda>s. s \<turnstile> cap \<and> x = is_final_cap' cap s
     \<and> cte_wp_at ((=) cap) sl s \<and> valid_asid_table s
     \<and> valid_mdb s \<and> valid_objs s \<and> sym_refs (state_refs_of s)\<rbrace>
     fast_finalise cap x
   \<lbrace>\<lambda>rv s. cte_wp_at (replaceable s sl cap.NullCap) sl s\<rbrace>"
  apply (cases "cap_irqs cap = {}")
   apply (simp add: fast_finalise_def2)
   apply wp
    apply (rule hoare_strengthen_post)
     apply (rule hoare_vcg_conj_lift)
      apply (rule finalise_cap_replaceable[where sl=sl])
     apply (rule finalise_cap_equal_cap[where sl=sl])
    apply (clarsimp simp: cte_wp_at_caps_of_state)
   apply wp
   apply (clarsimp simp: is_cap_simps can_fast_finalise_def)
  apply (clarsimp simp: cap_irqs_def cap_irq_opt_def split: cap.split_asm)
  done

global_naming Arch
lemma (* cap_delete_one_invs *) [Finalise_AI_asms,wp]:
  "\<lbrace>invs and emptyable ptr\<rbrace> cap_delete_one ptr \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: cap_delete_one_def unless_def is_final_cap_def)
  apply (rule hoare_pre)
  apply (wp empty_slot_invs get_cap_wp)
  apply clarsimp
  apply (drule cte_wp_at_valid_objs_valid_cap, fastforce+)
  done

end

interpretation Finalise_AI_2?: Finalise_AI_2
  proof goal_cases
  interpret Arch .
  case 1 show ?case by (intro_locales; (unfold_locales; fact Finalise_AI_asms)?)
  qed

context Arch begin global_naming AARCH64

crunches
  vcpu_update, vgic_update, vcpu_disable, vcpu_restore, vcpu_save_reg_range, vgic_update_lr,
  vcpu_save, vcpu_switch
  for irq_node[wp]: "\<lambda>s. P (interrupt_irq_node s)"
  (wp: crunch_wps subset_refl)

crunch irq_node[Finalise_AI_asms,wp]: prepare_thread_delete "\<lambda>s. P (interrupt_irq_node s)"
  (wp: crunch_wps simp: crunch_simps)

crunch irq_node[wp]: arch_finalise_cap "\<lambda>s. P (interrupt_irq_node s)"
  (simp: crunch_simps wp: crunch_wps)

crunch pred_tcb_at[wp]:
  delete_asid_pool, delete_asid, unmap_page_table, unmap_page, vcpu_invalidate_active
  "pred_tcb_at proj P t"
  (simp: crunch_simps wp: crunch_wps test)

crunch pred_tcb_at[wp_unsafe]: arch_finalise_cap "pred_tcb_at proj P t"
  (simp: crunch_simps wp: crunch_wps)

lemma set_vcpu_empty[wp]:
  "\<lbrace>\<lambda>s. P (obj_at (empty_table {}) word s)\<rbrace> set_vcpu p v \<lbrace>\<lambda>_ s. P (obj_at (empty_table {}) word s)\<rbrace>"
  apply (rule set_vcpu.vsobj_at)
  apply (clarsimp simp: vspace_obj_pred_def empty_table_def
                 split: kernel_object.splits arch_kernel_obj.splits)
  done

crunches
  vcpu_update, vgic_update, vcpu_disable, vcpu_restore, vcpu_save_reg_range, vgic_update_lr,
  vcpu_save, vcpu_switch
  for empty[wp]: "\<lambda>s. P (obj_at (empty_table {}) word s)"
  (wp: crunch_wps subset_refl)

definition
  replaceable_or_arch_update :: "'z::state_ext state \<Rightarrow> cslot_ptr \<Rightarrow> cap \<Rightarrow> cap \<Rightarrow> bool" where
  "replaceable_or_arch_update \<equiv> \<lambda>s slot cap cap'.
   if is_frame_cap cap
   then is_arch_update cap cap' \<and>
        (\<forall>asid vref. vs_cap_ref cap' = Some (asid,vref) \<longrightarrow>
           vs_cap_ref cap = Some (asid,vref) \<and>
           obj_refs cap = obj_refs cap' \<or>
           (\<forall>oref\<in>obj_refs cap'. \<forall>level. vs_lookup_target level asid vref s \<noteq> Some (level, oref)))
   else replaceable s slot cap cap'"

lemma is_final_cap_pt_asid_eq:
  "is_final_cap' (ArchObjectCap (PageTableCap p pt_t y)) s \<Longrightarrow>
   is_final_cap' (ArchObjectCap (PageTableCap p pt_t x)) s"
  apply (clarsimp simp: is_final_cap'_def gen_obj_refs_def)
  done

lemma is_final_cap_pd_asid_eq:
  "is_final_cap' (ArchObjectCap (PageTableCap p pt_t y)) s \<Longrightarrow>
   is_final_cap' (ArchObjectCap (PageTableCap p pt_t x)) s"
  by (rule is_final_cap_pt_asid_eq)

lemma cte_wp_at_obj_refs_singleton_page_table:
  "\<lbrakk>cte_wp_at
      (\<lambda>cap'. obj_refs cap' = {p}
            \<and> (\<exists>p pt_t asid. cap' = ArchObjectCap (PageTableCap p pt_t asid)))
      (a, b) s\<rbrakk> \<Longrightarrow>
   \<exists>asid pt_t. cte_wp_at ((=) (ArchObjectCap (PageTableCap p pt_t asid))) (a,b) s"
  apply (clarsimp simp: cte_wp_at_def)
  done

lemma final_cap_pt_slot_eq:
  "\<lbrakk>is_final_cap' (ArchObjectCap (PageTableCap p pt_t asid)) s;
    cte_wp_at ((=) (ArchObjectCap (PageTableCap p pt_t asid'))) slot s;
    cte_wp_at ((=) (ArchObjectCap (PageTableCap p pt_t asid''))) slot' s\<rbrakk> \<Longrightarrow>
   slot' = slot"
  apply (clarsimp simp:is_final_cap'_def2)
  apply (case_tac "(a,b) = slot'")
   apply (case_tac "(a,b) = slot")
    apply simp
   apply (erule_tac x="fst slot" in allE)
   apply (erule_tac x="snd slot" in allE)
   apply (clarsimp simp: gen_obj_refs_def cap_irqs_def cte_wp_at_def)
  apply (erule_tac x="fst slot'" in allE)
  apply (erule_tac x="snd slot'" in allE)
  apply (clarsimp simp: gen_obj_refs_def cap_irqs_def cte_wp_at_def)
  done

lemma is_arch_update_reset_page:
  "is_arch_update
     (ArchObjectCap (FrameCap p r sz dev m))
     (ArchObjectCap (FrameCap p r' sz dev m'))"
  apply (simp add: is_arch_update_def is_arch_cap_def cap_master_cap_def)
  done

crunches vcpu_finalise, arch_finalise_cap
  for caps_of_state [wp]: "\<lambda>s. P (caps_of_state s)"
  (wp: crunch_wps simp: crunch_simps)

lemma set_asid_pool_empty[wp]:
  "set_asid_pool p ap \<lbrace>\<lambda>s. P (obj_at (empty_table S) p' s)\<rbrace>"
  unfolding set_asid_pool_def
  apply (wpsimp wp: set_object_wp)
  apply (erule rsubst[where P=P])
  apply (clarsimp simp: obj_at_def in_omonad empty_table_def)
  done

crunches set_global_user_vspace, arm_context_switch
  for empty[wp]: "\<lambda>s. P (obj_at (empty_table S) p s)"

lemma set_vm_root_empty[wp]:
  "set_vm_root v \<lbrace>\<lambda>s. P (obj_at (empty_table S) p s) \<rbrace>"
  unfolding set_vm_root_def
  by (wpsimp wp: get_cap_wp)

lemma ucast_less_shiftl_helper3:
  "\<lbrakk> len_of TYPE('b) + 3 < len_of TYPE('a); 2 ^ (len_of TYPE('b) + 3) \<le> n\<rbrakk>
    \<Longrightarrow> (ucast (x :: 'b::len word) << 3) < (n :: 'a::len word)"
  by (rule ucast_less_shiftl_helper')

lemma caps_of_state_aligned_page_table:
  "\<lbrakk>caps_of_state s slot = Some (ArchObjectCap (PageTableCap word pt_t option)); invs s\<rbrakk>
  \<Longrightarrow> is_aligned word (pt_bits pt_t)"
  apply (frule caps_of_state_valid)
  apply (frule invs_valid_objs, assumption)
  apply (frule valid_cap_aligned)
  apply (simp add: cap_aligned_def pt_bits_def pageBits_def)
  done

end

lemma invs_valid_arch_capsI:
  "invs s \<Longrightarrow> valid_arch_caps s"
  by (simp add: invs_def valid_state_def)

context Arch begin global_naming AARCH64 (*FIXME: arch_split*)

lemma do_machine_op_reachable_pg_cap[wp]:
  "\<lbrace>\<lambda>s. P (reachable_frame_cap cap s)\<rbrace>
   do_machine_op mo
   \<lbrace>\<lambda>rv s. P (reachable_frame_cap cap s)\<rbrace>"
  apply (simp add:reachable_frame_cap_def reachable_target_def)
  apply (wp_pre, wps dmo.vs_lookup_pages, wpsimp)
  apply simp
  done

lemma replaceable_or_arch_update_pg:
  " (case (vs_cap_ref (ArchObjectCap (FrameCap word fun vm_pgsz dev y))) of None \<Rightarrow> True | Some (asid,vref) \<Rightarrow>
     \<forall>level. vs_lookup_target level asid vref s \<noteq> Some (level, word))
  \<longrightarrow> replaceable_or_arch_update s slot (ArchObjectCap (FrameCap word fun vm_pgsz dev None))
                (ArchObjectCap (FrameCap word fun vm_pgsz dev y))"
  unfolding replaceable_or_arch_update_def
  apply (auto simp: is_cap_simps is_arch_update_def cap_master_cap_simps)
  done


global_naming Arch

crunch invs[wp]: prepare_thread_delete invs
  (ignore: set_object do_machine_op wp: dmo_invs_lift)

lemma (* finalise_cap_invs *)[Finalise_AI_asms]:
  shows "\<lbrace>invs and cte_wp_at ((=) cap) slot\<rbrace> finalise_cap cap x \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (cases cap, simp_all split del: if_split)
         apply (wp cancel_all_ipc_invs cancel_all_signals_invs unbind_notification_invs
                   unbind_maybe_notification_invs
                  | simp add: o_def split del: if_split cong: if_cong
                  | wpc )+
      apply clarsimp (* thread *)
      apply (frule cte_wp_at_valid_objs_valid_cap, clarsimp)
      apply (clarsimp simp: valid_cap_def)
      apply (frule(1) valid_global_refsD[OF invs_valid_global_refs])
       apply (simp add: global_refs_def, rule disjI1, rule refl)
      apply (simp add: cap_range_def)
     apply (wp deleting_irq_handler_invs  | simp | intro conjI impI)+
  apply (auto dest: cte_wp_at_valid_objs_valid_cap)
  done

lemma (* finalise_cap_irq_node *)[Finalise_AI_asms]:
"\<lbrace>\<lambda>s. P (interrupt_irq_node s)\<rbrace> finalise_cap a b \<lbrace>\<lambda>_ s. P (interrupt_irq_node s)\<rbrace>"
  by (case_tac a, wpsimp+)

lemmas (*arch_finalise_cte_irq_node *) [wp,Finalise_AI_asms]
    = hoare_use_eq_irq_node [OF arch_finalise_cap_irq_node arch_finalise_cap_cte_wp_at]

lemma (* deleting_irq_handler_st_tcb_at *) [Finalise_AI_asms]:
  "\<lbrace>st_tcb_at P t and K (\<forall>st. simple st \<longrightarrow> P st)\<rbrace>
     deleting_irq_handler irq
   \<lbrace>\<lambda>rv. st_tcb_at P t\<rbrace>"
  apply (simp add: deleting_irq_handler_def)
  apply (wp cap_delete_one_st_tcb_at)
  apply simp
  done

lemma irq_node_global_refs_ARCH [Finalise_AI_asms]:
  "interrupt_irq_node s irq \<in> global_refs s"
  by (simp add: global_refs_def)

lemma (* get_irq_slot_fast_finalisable *)[wp,Finalise_AI_asms]:
  "\<lbrace>invs\<rbrace> get_irq_slot irq \<lbrace>cte_wp_at can_fast_finalise\<rbrace>"
  apply (simp add: get_irq_slot_def)
  apply wp
  apply (clarsimp simp: invs_def valid_state_def valid_irq_node_def)
  apply (drule spec[where x=irq], drule cap_table_at_cte_at[where offset="[]"])
   apply simp
  apply (clarsimp simp: cte_wp_at_caps_of_state)
  apply (case_tac "cap = cap.NullCap")
   apply (simp add: can_fast_finalise_def)
  apply (frule(1) if_unsafe_then_capD [OF caps_of_state_cteD])
   apply simp
  apply (clarsimp simp: ex_cte_cap_wp_to_def)
  apply (drule cte_wp_at_norm, clarsimp)
  apply (drule(1) valid_global_refsD [OF _ _ irq_node_global_refs_ARCH[where irq=irq]])
  apply (case_tac c, simp_all)
     apply (clarsimp simp: cap_range_def)
    apply (clarsimp simp: cap_range_def)
   apply (clarsimp simp: appropriate_cte_cap_def can_fast_finalise_def split: cap.split_asm)
  apply (clarsimp simp: cap_range_def)
  done

lemma (* replaceable_or_arch_update_same *) [Finalise_AI_asms]:
  "replaceable_or_arch_update s slot cap cap"
  by (clarsimp simp: replaceable_or_arch_update_def
                replaceable_def is_arch_update_def is_cap_simps)

lemma (* replace_cap_invs_arch_update *)[Finalise_AI_asms]:
  "\<lbrace>\<lambda>s. cte_wp_at (replaceable_or_arch_update s p cap) p s
        \<and> invs s
        \<and> cap \<noteq> cap.NullCap
        \<and> ex_cte_cap_wp_to (appropriate_cte_cap cap) p s
        \<and> s \<turnstile> cap\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv s. invs s\<rbrace>"
  apply (simp add:replaceable_or_arch_update_def)
  apply (cases "is_frame_cap cap")
   apply (wp hoare_pre_disj[OF arch_update_cap_invs_unmap_page arch_update_cap_invs_map])
   apply (simp add:replaceable_or_arch_update_def replaceable_def cte_wp_at_caps_of_state)
   apply (clarsimp simp: cte_wp_at_caps_of_state is_cap_simps gen_obj_refs_def
                         cap_master_cap_simps is_arch_update_def)
  apply (wp replace_cap_invs)
  apply simp
  done

lemma dmo_pred_tcb_at[wp]:
  "do_machine_op mop \<lbrace>\<lambda>s. P (pred_tcb_at f Q t s)\<rbrace>"
  apply (simp add: do_machine_op_def split_def)
  apply wp
  apply (clarsimp simp: pred_tcb_at_def obj_at_def)
  done

lemma dmo_tcb_cap_valid_ARCH [Finalise_AI_asms]:
  "do_machine_op mop \<lbrace>\<lambda>s. P (tcb_cap_valid cap ptr s)\<rbrace>"
  apply (simp add: tcb_cap_valid_def no_cap_to_obj_with_diff_ref_def)
  apply (wp_pre, wps, rule hoare_vcg_prop)
  apply simp
  done

lemma dmo_vs_lookup_target[wp]:
  "do_machine_op mop \<lbrace>\<lambda>s. P (vs_lookup_target level asid vref s)\<rbrace>"
  by (rule dmo.vs_lookup_pages)

lemma dmo_reachable_target[wp]:
  "do_machine_op mop \<lbrace>\<lambda>s. P (reachable_target ref p s)\<rbrace>"
  apply (simp add: reachable_target_def split_def)
  apply (wp_pre, wps, wp)
  apply simp
  done

lemma (* dmo_replaceable_or_arch_update *) [Finalise_AI_asms,wp]:
  "\<lbrace>\<lambda>s. replaceable_or_arch_update s slot cap cap'\<rbrace>
    do_machine_op mo
  \<lbrace>\<lambda>r s. replaceable_or_arch_update s slot cap cap'\<rbrace>"
  unfolding replaceable_or_arch_update_def replaceable_def no_cap_to_obj_with_diff_ref_def
            replaceable_final_arch_cap_def replaceable_non_final_arch_cap_def
  apply (wp_pre, wps dmo_tcb_cap_valid_ARCH do_machine_op_reachable_pg_cap)
   apply (rule hoare_vcg_prop)
  apply simp
  done

end

context begin interpretation Arch .
requalify_consts replaceable_or_arch_update
end

interpretation Finalise_AI_3?: Finalise_AI_3
  where replaceable_or_arch_update = replaceable_or_arch_update
  proof goal_cases
  interpret Arch .
  case 1 show ?case
    by (intro_locales; (unfold_locales; fact Finalise_AI_asms)?)
  qed

context Arch begin global_naming AARCH64

lemma typ_at_data_at_wp:
  assumes typ_wp: "\<And>a.\<lbrace>typ_at a p \<rbrace> g \<lbrace>\<lambda>s. typ_at a p\<rbrace>"
  shows "\<lbrace>data_at b p\<rbrace> g \<lbrace>\<lambda>s. data_at b p\<rbrace>"
  apply (simp add: data_at_def)
  apply (wp typ_wp hoare_vcg_disj_lift)
  done

end

interpretation Finalise_AI_4?: Finalise_AI_4
  where replaceable_or_arch_update = replaceable_or_arch_update
  proof goal_cases
  interpret Arch .
  case 1 show ?case by (intro_locales; (unfold_locales; fact Finalise_AI_asms)?)
  qed

context Arch begin global_naming AARCH64

lemma set_asid_pool_obj_at_ptr:
  "\<lbrace>\<lambda>s. P (ArchObj (arch_kernel_obj.ASIDPool mp))\<rbrace>
     set_asid_pool ptr mp
   \<lbrace>\<lambda>rv s. obj_at P ptr s\<rbrace>"
  apply (simp add: set_asid_pool_def set_object_def)
  apply (wp get_object_wp)
  apply (clarsimp simp: obj_at_def)
  done

locale_abbrev
  "asid_table_update asid ap s \<equiv>
     s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table := (asid_table s)(asid \<mapsto> ap)\<rparr>\<rparr>"

lemma valid_table_caps_table [simp]:
  "valid_table_caps (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table := table'\<rparr>\<rparr>) = valid_table_caps s"
  by (simp add: valid_table_caps_def)

lemma valid_kernel_mappings [iff]:
  "valid_kernel_mappings (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table := table'\<rparr>\<rparr>) = valid_kernel_mappings s"
  by (simp add: valid_kernel_mappings_def)

crunches unmap_page_table, store_pte, delete_asid_pool
  for valid_cap[wp]: "valid_cap c"
  (wp: mapM_wp_inv mapM_x_wp' simp: crunch_simps)

lemmas vcpu_finalise_typ_ats [wp] = abs_typ_at_lifts [OF vcpu_finalise_typ_at]
lemmas delete_asid_typ_ats[wp] = abs_typ_at_lifts [OF delete_asid_typ_at]

lemma arch_finalise_cap_valid_cap[wp]:
  "arch_finalise_cap cap b \<lbrace>valid_cap c\<rbrace>"
  unfolding arch_finalise_cap_def
  by (wpsimp split: arch_cap.split option.split bool.split)

global_naming Arch

lemmas clearMemory_invs[wp,Finalise_AI_asms] = clearMemory_invs

lemma valid_idle_has_null_cap_ARCH[Finalise_AI_asms]:
  "\<lbrakk> if_unsafe_then_cap s; valid_global_refs s; valid_idle s; valid_irq_node s;
    caps_of_state s (idle_thread s, v) = Some cap \<rbrakk>
   \<Longrightarrow> cap = NullCap"
  apply (rule ccontr)
  apply (drule(1) if_unsafe_then_capD[OF caps_of_state_cteD])
   apply clarsimp
  apply (clarsimp simp: ex_cte_cap_wp_to_def cte_wp_at_caps_of_state)
  apply (frule(1) valid_global_refsD2)
  apply (case_tac capa, simp_all add: cap_range_def global_refs_def)[1]
  apply (clarsimp simp: valid_irq_node_def valid_idle_def pred_tcb_at_def
                        obj_at_def is_cap_table_def)
  apply (rename_tac word tcb)
  apply (drule_tac x=word in spec, simp)
  done

lemma (* zombie_cap_two_nonidles *)[Finalise_AI_asms]:
  "\<lbrakk> caps_of_state s ptr = Some (Zombie ptr' zbits n); invs s \<rbrakk>
       \<Longrightarrow> fst ptr \<noteq> idle_thread s \<and> ptr' \<noteq> idle_thread s"
  apply (frule valid_global_refsD2, clarsimp+)
  apply (simp add: cap_range_def global_refs_def)
  apply (cases ptr, auto dest: valid_idle_has_null_cap_ARCH[rotated -1])[1]
  done

crunches empty_slot, finalise_cap, send_ipc, receive_ipc
  for ioports[wp]: valid_ioports
  (wp: crunch_wps valid_ioports_lift simp: crunch_simps ignore: set_object)

lemma arch_derive_cap_notzombie[wp]:
  "\<lbrace>\<top>\<rbrace> arch_derive_cap acap \<lbrace>\<lambda>rv s. \<not> is_zombie rv\<rbrace>, -"
  by (cases acap; wpsimp simp: arch_derive_cap_def is_zombie_def o_def)

lemma arch_derive_cap_notIRQ[wp]:
  "\<lbrace>\<top>\<rbrace> arch_derive_cap cap \<lbrace>\<lambda>rv s. rv \<noteq> cap.IRQControlCap\<rbrace>,-"
  by (cases cap; wpsimp simp: arch_derive_cap_def o_def)

end

interpretation Finalise_AI_5?: Finalise_AI_5
  where replaceable_or_arch_update = replaceable_or_arch_update
  proof goal_cases
  interpret Arch .
  case 1 show ?case by (intro_locales; (unfold_locales; fact Finalise_AI_asms)?)
  qed

end
