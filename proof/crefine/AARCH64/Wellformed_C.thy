(*
 * Copyright 2023, Proofcraft Pty Ltd
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 * Copyright 2014, General Dynamics C4 Systems
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

(* Wellformedness of caps, kernel objects, states on the C level *)

theory Wellformed_C
imports
  "CLib.CTranslationNICTA"
  CLevityCatch
  "CSpec.Substitute"
begin

context begin interpretation Arch . (*FIXME: arch_split*)

(* Takes an address and ensures it can be given to a function expecting a canonical address.
   Canonical addresses on 64-bit machines aren't really 64-bit, due to bus sizes. Hence, structures
   used by the bitfield generator will use packed addresses, resulting in this mask in the C code
   on AARCH64 (which would be a cast plus sign-extension on X64 and RISCV64).
   For our spec rules, it's better to wrap the magic numbers if possible.

   Dependency-wise this could also go into Invariants_H, but we want to limit its use to CRefine. *)
definition make_canonical :: "machine_word \<Rightarrow> machine_word" where
  "make_canonical p \<equiv> p && mask (Suc canonical_bit)"

lemma make_canonical_0[simp]:
  "make_canonical 0 = 0"
  by (simp add: make_canonical_def)

lemma canonical_make_canonical_idem:
  "canonical_address p \<Longrightarrow> make_canonical p = p"
  unfolding make_canonical_def
  by (simp add: canonical_address_mask_eq)

lemma make_canonical_is_canonical:
  "canonical_address (make_canonical p)"
  unfolding make_canonical_def
  by (simp add: canonical_address_mask_eq)

(* This is [simp] because if we see this pattern, it's very likely that we want to use the
   other make_canonical rules *)
lemma make_canonical_and_fold[simp]:
  "p && mask (Suc canonical_bit) && n = make_canonical p && n" for p :: machine_word
  by (simp flip: make_canonical_def word_bw_assocs)

lemmas make_canonical_fold = make_canonical_def[symmetric, unfolded canonical_bit_def, simplified]

schematic_goal Suc_canonical_bit_fold:
  "numeral ?n = Suc canonical_bit"
  by (simp add: canonical_bit_def)

lemma make_canonical_aligned:
  "is_aligned p n \<Longrightarrow> is_aligned (make_canonical p) n"
  by (simp add: is_aligned_mask make_canonical_def) word_eqI_solve

abbreviation
  cte_Ptr :: "addr \<Rightarrow> cte_C ptr" where "cte_Ptr == Ptr"
abbreviation
  mdb_Ptr :: "addr \<Rightarrow> mdb_node_C ptr" where "mdb_Ptr == Ptr"
abbreviation
  cap_Ptr :: "addr \<Rightarrow> cap_C ptr" where "cap_Ptr == Ptr"
abbreviation
  tcb_Ptr :: "addr \<Rightarrow> tcb_C ptr" where "tcb_Ptr == Ptr"
abbreviation
  atcb_Ptr :: "addr \<Rightarrow> arch_tcb_C ptr" where "atcb_Ptr == Ptr"
abbreviation
  vcpu_Ptr :: "addr \<Rightarrow> vcpu_C ptr" where "vcpu_Ptr == Ptr"
abbreviation
  ep_Ptr :: "addr \<Rightarrow> endpoint_C ptr" where "ep_Ptr == Ptr"
abbreviation
  ntfn_Ptr :: "addr \<Rightarrow> notification_C ptr" where "ntfn_Ptr == Ptr"
abbreviation
  ap_Ptr :: "addr \<Rightarrow> asid_pool_C ptr" where "ap_Ptr == Ptr"

type_synonym pt_ptr = "(pte_C[pt_array_len]) ptr"
type_synonym vs_ptr = "(pte_C[vs_array_len]) ptr"

abbreviation
  pte_Ptr :: "addr \<Rightarrow> pte_C ptr" where "pte_Ptr == Ptr"
abbreviation
  pt_Ptr :: "machine_word \<Rightarrow> pt_ptr" where "pt_Ptr == Ptr"
abbreviation
  vs_Ptr :: "machine_word \<Rightarrow> vs_ptr" where "vs_Ptr == Ptr"

abbreviation
  vgic_lr_C_Ptr :: "addr \<Rightarrow> (virq_C[64]) ptr" where "vgic_lr_C_Ptr \<equiv> Ptr"
abbreviation
  vgic_C_Ptr :: "addr \<Rightarrow> gicVCpuIface_C ptr" where "vgic_C_Ptr \<equiv> Ptr"
abbreviation
  vcpu_vppi_masked_C_Ptr :: "addr \<Rightarrow> (machine_word[1]) ptr" where "vcpu_vppi_masked_C_Ptr \<equiv> Ptr"

declare seL4_VCPUReg_Num_def[code]
value_type num_vcpu_regs = "unat seL4_VCPUReg_Num"

abbreviation
  vcpuregs_C_Ptr :: "addr \<Rightarrow> (machine_word[num_vcpu_regs]) ptr" where "vcpuregs_C_Ptr \<equiv> Ptr"

type_synonym tcb_cnode_array = "cte_C[5]"
type_synonym registers_count = 37 (* length enum_register *)
type_synonym registers_array = "machine_word[registers_count]"

(* typedef word_t register_t; *)
type_synonym register_idx_len = machine_word_len
type_synonym register_idx = "register_idx_len word"

(* representation of C int literals, the default for any unadorned numeral *)
type_synonym int_literal_len = "32 signed"
type_synonym int_word = "int_literal_len word"

abbreviation "user_context_Ptr \<equiv> Ptr :: addr \<Rightarrow> user_context_C ptr"
abbreviation "machine_word_Ptr \<equiv> Ptr :: addr \<Rightarrow> machine_word ptr"
abbreviation "tcb_cnode_Ptr \<equiv> Ptr :: addr \<Rightarrow> tcb_cnode_array ptr"
abbreviation "registers_Ptr \<equiv> Ptr :: addr \<Rightarrow> registers_array ptr"

lemma halt_spec:
  "Gamma \<turnstile> {} Call halt_'proc {}"
  apply (rule hoare_complete)
  apply (simp add: HoarePartialDef.valid_def)
  done

definition
  isUntypedCap_C :: "cap_CL \<Rightarrow> bool" where
  "isUntypedCap_C c \<equiv>
   case c of
   Cap_untyped_cap q \<Rightarrow> True
   | _ \<Rightarrow> False"

definition
  isNullCap_C :: "cap_CL \<Rightarrow> bool" where
  "isNullCap_C c \<equiv>
  case c of
   Cap_null_cap \<Rightarrow> True
   | _ \<Rightarrow> False"

definition
  isEndpointCap_C :: "cap_CL \<Rightarrow> bool" where
 "isEndpointCap_C v \<equiv> case v of
  Cap_endpoint_cap ec \<Rightarrow> True
  | _ \<Rightarrow> False"

definition
  isCNodeCap_C :: "cap_CL \<Rightarrow> bool" where
  "isCNodeCap_C c \<equiv> case c of
   Cap_cnode_cap a \<Rightarrow> True
   | _ \<Rightarrow> False"

definition
  isThreadCap_C :: "cap_CL \<Rightarrow> bool" where
  "isThreadCap_C c \<equiv> case c of
   Cap_thread_cap a \<Rightarrow> True
   | _ \<Rightarrow> False"

definition
  isIRQControlCap_C :: "cap_CL \<Rightarrow> bool" where
  "isIRQControlCap_C c \<equiv> case c of
   Cap_irq_control_cap \<Rightarrow> True
   | _ \<Rightarrow> False"

definition
  isIRQHandlerCap_C :: "cap_CL \<Rightarrow> bool" where
  "isIRQHandlerCap_C c \<equiv> case c of
   Cap_irq_handler_cap a \<Rightarrow> True
   | _ \<Rightarrow> False"

definition
  isNotificationCap_C :: "cap_CL \<Rightarrow> bool" where
 "isNotificationCap_C v \<equiv> case v of
  Cap_notification_cap aec \<Rightarrow> True
  | _ \<Rightarrow> False"

definition
  ep_at_C' :: "word64 \<Rightarrow> heap_raw_state \<Rightarrow> bool"
where
  "ep_at_C' p h \<equiv> Ptr p \<in> dom (clift h :: endpoint_C typ_heap)" \<comment> \<open>endpoint_lift is total\<close>

definition
  ntfn_at_C' :: "word64 \<Rightarrow> heap_raw_state \<Rightarrow> bool"
  where \<comment> \<open>notification_lift is total\<close>
  "ntfn_at_C' p h \<equiv> Ptr p \<in> dom (clift h :: notification_C typ_heap)"

definition
  tcb_at_C' :: "word64 \<Rightarrow> heap_raw_state \<Rightarrow> bool"
  where
  "tcb_at_C' p h \<equiv> Ptr p \<in> dom (clift h :: tcb_C typ_heap)"

definition
  cte_at_C' :: "word64 \<Rightarrow> heap_raw_state \<Rightarrow> bool"
  where
  "cte_at_C' p h \<equiv> Ptr p \<in> dom (clift h :: cte_C typ_heap)"

definition
  ctcb_ptr_to_tcb_ptr :: "tcb_C ptr \<Rightarrow> word64"
  where
  "ctcb_ptr_to_tcb_ptr p \<equiv> ptr_val p - ctcb_offset"

definition
  tcb_ptr_to_ctcb_ptr :: "word64 \<Rightarrow> tcb_C ptr"
  where
  "tcb_ptr_to_ctcb_ptr p \<equiv> Ptr (p + ctcb_offset)"

primrec
  tcb_queue_relation :: "(tcb_C \<Rightarrow> tcb_C ptr) \<Rightarrow> (tcb_C \<Rightarrow> tcb_C ptr) \<Rightarrow>
                         (tcb_C ptr \<Rightarrow> tcb_C option) \<Rightarrow> word64 list \<Rightarrow>
                         tcb_C ptr \<Rightarrow> tcb_C ptr \<Rightarrow> bool"
where
  "tcb_queue_relation getNext getPrev hp [] qprev qhead = (qhead = NULL)"
| "tcb_queue_relation getNext getPrev hp (x#xs) qprev qhead =
     (qhead = tcb_ptr_to_ctcb_ptr x \<and>
      (\<exists>tcb. (hp qhead = Some tcb \<and> getPrev tcb = qprev \<and> tcb_queue_relation getNext getPrev hp xs qhead (getNext tcb))))"

abbreviation
  "ep_queue_relation \<equiv> tcb_queue_relation tcbEPNext_C tcbEPPrev_C"

definition
capUntypedPtr_C :: "cap_CL \<Rightarrow> word64" where
  "capUntypedPtr_C cap \<equiv> case cap of
 (Cap_untyped_cap uc) \<Rightarrow> capBlockSize_CL uc
 |  Cap_endpoint_cap ep \<Rightarrow> capEPPtr_CL ep
 |  Cap_notification_cap ntfn \<Rightarrow> capNtfnPtr_CL ntfn
 |  Cap_cnode_cap ccap \<Rightarrow> capCNodePtr_CL ccap
 |  Cap_reply_cap rc \<Rightarrow> cap_reply_cap_CL.capTCBPtr_CL rc
 |  Cap_thread_cap tc \<Rightarrow> cap_thread_cap_CL.capTCBPtr_CL tc
 |  Cap_frame_cap fc \<Rightarrow> cap_frame_cap_CL.capFBasePtr_CL fc
 |  Cap_vspace_cap vsc \<Rightarrow> cap_vspace_cap_CL.capVSBasePtr_CL vsc
 |  Cap_page_table_cap ptc \<Rightarrow> cap_page_table_cap_CL.capPTBasePtr_CL ptc
 |  Cap_vcpu_cap tc \<Rightarrow> cap_vcpu_cap_CL.capVCPUPtr_CL tc
 | _ \<Rightarrow> error []"

definition ZombieTCB_C_def:
"ZombieTCB_C \<equiv> bit 6" (*wordRadix*)

definition
  isZombieTCB_C :: "word64 \<Rightarrow> bool" where
 "isZombieTCB_C v \<equiv> v = ZombieTCB_C"

(* FIXME AARCH64 vmrights_to_H should be renamed vm_rights_to_H on all platforms, as there is no
   "vmrights" anywhere, and follow that up with renaming "vmrights" lemmas *)

definition
vmrights_to_H :: "word64 \<Rightarrow> vmrights" where
"vmrights_to_H c \<equiv>
  if c = scast Kernel_C.VMReadWrite then VMReadWrite
  else if c = scast Kernel_C.VMReadOnly then VMReadOnly
  else VMKernelOnly"

definition vm_attributes_to_H :: "vm_attributes_C \<Rightarrow> vmattributes" where
  "vm_attributes_to_H attrs_raw \<equiv>
    let attrs = vm_attributes_lift attrs_raw in
    VMAttributes (to_bool (armExecuteNever_CL attrs))
                 (to_bool (armPageCacheable_CL attrs))"

definition attridx_from_vmattributes :: "vmattributes \<Rightarrow> machine_word" where
  "attridx_from_vmattributes attrs \<equiv>
     if armPageCacheable attrs
     then ucast Kernel_C.S2_NORMAL
     else ucast Kernel_C.S2_DEVICE_nGnRnE"

definition uxn_from_vmattributes :: "vmattributes \<Rightarrow> machine_word" where
  "uxn_from_vmattributes attrs \<equiv> from_bool (armExecuteNever attrs)"

(* Force clarity over name collisions *)
abbreviation
  ARMSmallPage :: "vmpage_size" where
 "ARMSmallPage == AARCH64.ARMSmallPage"
abbreviation
  ARMLargePage :: "vmpage_size" where
 "ARMLargePage == AARCH64.ARMLargePage"
abbreviation
  ARMHugePage :: "vmpage_size" where
 "ARMHugePage == AARCH64.ARMHugePage"

definition framesize_to_H :: "machine_word \<Rightarrow> vmpage_size" where
  "framesize_to_H c \<equiv>
    if c = scast Kernel_C.ARMSmallPage then ARMSmallPage
    else if c = scast Kernel_C.ARMLargePage then ARMLargePage
    else ARMHugePage"

definition
  framesize_from_H :: "vmpage_size \<Rightarrow> machine_word"
where
  "framesize_from_H sz \<equiv>
    case sz of
         ARMSmallPage \<Rightarrow> scast Kernel_C.ARMSmallPage
       | ARMLargePage \<Rightarrow> scast Kernel_C.ARMLargePage
       | ARMHugePage \<Rightarrow> scast Kernel_C.ARMHugePage"

lemmas framesize_defs = Kernel_C.ARMSmallPage_def Kernel_C.ARMLargePage_def
                        Kernel_C.ARMHugePage_def

lemma framesize_from_to_H:
  "framesize_to_H (framesize_from_H sz) = sz"
  by (simp add: framesize_to_H_def framesize_from_H_def framesize_defs
           split: if_split vmpage_size.splits)

lemma framesize_from_H_eq:
  "(framesize_from_H sz = framesize_from_H sz') = (sz = sz')"
  by (cases sz; cases sz';
      simp add: framesize_from_H_def framesize_defs)

end

record cte_CL =
  cap_CL :: cap_CL
  cteMDBNode_CL :: mdb_node_CL

context begin interpretation Arch . (*FIXME: arch_split*)

definition
  cte_lift :: "cte_C \<rightharpoonup> cte_CL"
  where
  "cte_lift c \<equiv> case cap_lift (cte_C.cap_C c) of
                     None \<Rightarrow> None
                   | Some cap \<Rightarrow> Some \<lparr> cap_CL = cap,
                                       cteMDBNode_CL = mdb_node_lift (cteMDBNode_C c) \<rparr>"

definition
  mdb_node_to_H :: "mdb_node_CL \<Rightarrow> mdbnode"
  where
  "mdb_node_to_H n \<equiv> MDB (mdbNext_CL n)
                         (mdbPrev_CL n)
                         (to_bool (mdbRevocable_CL n))
                         (to_bool (mdbFirstBadged_CL n))"

definition
cap_to_H :: "cap_CL \<Rightarrow> capability"
where
"cap_to_H c \<equiv>  case c of
 Cap_null_cap \<Rightarrow> NullCap
 | Cap_zombie_cap zc \<Rightarrow>  (if isZombieTCB_C(capZombieType_CL zc)
                         then
                               (Zombie ((capZombieID_CL zc) && ~~(mask(5)))
                                       (ZombieTCB)
                                       (unat ((capZombieID_CL zc) && mask(5))))
                         else let radix = unat (capZombieType_CL zc) in
                               (Zombie ((capZombieID_CL zc) && ~~(mask (radix+1)))
                                       (ZombieCNode radix)
                                       (unat ((capZombieID_CL zc) && mask(radix+1)))))
 | Cap_cnode_cap ccap \<Rightarrow>
    CNodeCap (capCNodePtr_CL ccap) (unat (capCNodeRadix_CL ccap))
             (capCNodeGuard_CL ccap)
             (unat (capCNodeGuardSize_CL ccap))
 | Cap_untyped_cap uc \<Rightarrow> UntypedCap (to_bool(capIsDevice_CL uc)) (capPtr_CL uc) (unat (capBlockSize_CL uc)) (unat (capFreeIndex_CL uc << 4))
 | Cap_endpoint_cap ec \<Rightarrow>
    EndpointCap (capEPPtr_CL ec) (capEPBadge_CL ec) (to_bool(capCanSend_CL ec)) (to_bool(capCanReceive_CL ec))
                (to_bool(capCanGrant_CL ec)) (to_bool(capCanGrantReply_CL ec))
 | Cap_notification_cap ntfn \<Rightarrow>
    NotificationCap (capNtfnPtr_CL ntfn)(capNtfnBadge_CL ntfn)(to_bool(capNtfnCanSend_CL ntfn))
                     (to_bool(capNtfnCanReceive_CL ntfn))
 | Cap_reply_cap rc \<Rightarrow> ReplyCap (ctcb_ptr_to_tcb_ptr (Ptr (cap_reply_cap_CL.capTCBPtr_CL rc)))
                               (to_bool (capReplyMaster_CL rc)) (to_bool (capReplyCanGrant_CL rc))
 | Cap_thread_cap tc \<Rightarrow>  ThreadCap(ctcb_ptr_to_tcb_ptr (Ptr (cap_thread_cap_CL.capTCBPtr_CL tc)))
 | Cap_irq_handler_cap ihc \<Rightarrow> IRQHandlerCap (ucast(capIRQ_CL ihc))
 | Cap_irq_control_cap \<Rightarrow> IRQControlCap
 | Cap_asid_control_cap \<Rightarrow> ArchObjectCap ASIDControlCap
 | Cap_asid_pool_cap apc \<Rightarrow> ArchObjectCap (ASIDPoolCap (capASIDPool_CL apc) (capASIDBase_CL apc))
 | Cap_frame_cap fc \<Rightarrow> ArchObjectCap (FrameCap (capFBasePtr_CL fc)
                                            (vmrights_to_H(capFVMRights_CL fc))
                                            (framesize_to_H(capFSize_CL fc))
                                            (to_bool(capFIsDevice_CL fc))
                                            (if capFMappedASID_CL fc = 0
                                             then None else
                                             Some(capFMappedASID_CL fc, capFMappedAddress_CL fc)))
 | Cap_vspace_cap vsc \<Rightarrow> ArchObjectCap
                              (PageTableCap (capVSBasePtr_CL vsc) VSRootPT_T
                                            (if to_bool (capVSIsMapped_CL vsc)
                                             then Some (capVSMappedASID_CL vsc, 0)
                                             else None))
   \<comment> \<open>cap_vspace_cap_CL does not have a mapped address field, and the vaddr for mapped VSRoot_T caps
      is always 0 due to alignment constraint\<close>
 | Cap_page_table_cap ptc \<Rightarrow> ArchObjectCap
                              (PageTableCap (cap_page_table_cap_CL.capPTBasePtr_CL ptc) NormalPT_T
                                            (if to_bool (capPTIsMapped_CL ptc)
                                             then Some (capPTMappedASID_CL ptc, capPTMappedAddress_CL ptc)
                                             else None))
 | Cap_domain_cap \<Rightarrow> DomainCap
 | Cap_vcpu_cap vcpu \<Rightarrow> ArchObjectCap (VCPUCap (capVCPUPtr_CL vcpu))"

lemmas cap_to_H_simps = cap_to_H_def[split_simps cap_CL.split]

definition
  cte_to_H :: "cte_CL \<Rightarrow> cte"
  where
  "cte_to_H cte \<equiv> CTE (cap_to_H (cap_CL cte)) (mdb_node_to_H (cteMDBNode_CL cte))"

(* FIXME AARCH64 the "9" here is irq size, do we have a better abbreviation for irq bits? *)
definition
cl_valid_cap :: "cap_CL \<Rightarrow> bool"
where
"cl_valid_cap c \<equiv>
   case c of
     Cap_irq_handler_cap fc \<Rightarrow> ((capIRQ_CL fc) && mask 9 = capIRQ_CL fc)
   | Cap_frame_cap fc \<Rightarrow> capFSize_CL fc < 3 \<and> capFVMRights_CL fc < 4 \<and> capFVMRights_CL fc \<noteq> 2
   | x \<Rightarrow> True"

definition
c_valid_cap :: "cap_C \<Rightarrow> bool"
where
"c_valid_cap c \<equiv> case_option True cl_valid_cap (cap_lift c)"

definition
cl_valid_cte :: "cte_CL \<Rightarrow> bool"
where
"cl_valid_cte c \<equiv>  cl_valid_cap (cap_CL c)"

definition
c_valid_cte :: "cte_C \<Rightarrow> bool"
where
"c_valid_cte c \<equiv>  c_valid_cap (cte_C.cap_C c)"

(* all uninteresting cases can be deduced from the cap tag *)
lemma  c_valid_cap_simps [simp]:
  "cap_get_tag c = scast cap_thread_cap \<Longrightarrow> c_valid_cap c"
  "cap_get_tag c = scast cap_notification_cap \<Longrightarrow> c_valid_cap c"
  "cap_get_tag c = scast cap_endpoint_cap \<Longrightarrow> c_valid_cap c"
  "cap_get_tag c = scast cap_cnode_cap \<Longrightarrow> c_valid_cap c"
  "cap_get_tag c = scast cap_asid_control_cap \<Longrightarrow> c_valid_cap c"
  "cap_get_tag c = scast cap_irq_control_cap \<Longrightarrow> c_valid_cap c"
  "cap_get_tag c = scast cap_vspace_cap \<Longrightarrow> c_valid_cap c"
  "cap_get_tag c = scast cap_page_table_cap \<Longrightarrow> c_valid_cap c"
  "cap_get_tag c = scast cap_asid_pool_cap \<Longrightarrow> c_valid_cap c"
  "cap_get_tag c = scast cap_untyped_cap \<Longrightarrow> c_valid_cap c"
  "cap_get_tag c = scast cap_zombie_cap \<Longrightarrow> c_valid_cap c"
  "cap_get_tag c = scast cap_reply_cap \<Longrightarrow> c_valid_cap c"
  "cap_get_tag c = scast cap_vcpu_cap \<Longrightarrow> c_valid_cap c"
  "cap_get_tag c = scast cap_null_cap \<Longrightarrow> c_valid_cap c"
  unfolding c_valid_cap_def  cap_lift_def cap_tag_defs
  by (simp add: cl_valid_cap_def)+

lemma ptr_val_tcb_ptr_mask2:
  "is_aligned thread tcbBlockSizeBits
      \<Longrightarrow> ptr_val (tcb_ptr_to_ctcb_ptr thread) && (~~ mask tcbBlockSizeBits)
                  = thread"
  apply (clarsimp simp: tcb_ptr_to_ctcb_ptr_def)
  apply (simp add: is_aligned_add_helper ctcb_offset_defs objBits_simps')
  done

section \<open>Domains\<close>

text \<open>
  seL4's build system allows configuration of the number of domains. This means the proofs have to
  work for any number of domains provided it fits into the hard limit of a 8-bit word.

  In the C code, we have the enumerated constant numDomains, one greater than maxDom. In the
  abstract specs, we have the corresponding Platform_Config.numDomains and maxDomain.

  To keep the proofs as general as possible, we avoid unfolding definitions of:
  maxDom, maxDomain, numDomains except in this theory where we need to establish basic properties.

  Unfortunately, array bounds checks coming from the C code use numerical values, meaning we might
  get 0x10 instead of the number of domains, or 0x1000 for numDomains * numPriorities. To solve
  these, the "explicit" lemmas expose direct numbers. They are more risky to deploy, as one could
  prove that 0x5 is less than the number of domains when that's the case, and then the proof will
  break upon reconfiguration.
\<close>

text \<open>The @{text num_domains} enumerated type and constant represent the number of domains.\<close>

value_type num_domains = "numDomains"

context includes no_less_1_simps begin

(* The proofs expect the minimum priority and minimum domain to be zero.
   Note that minDom is unused in the C code. *)
lemma min_prio_dom_sanity:
  "seL4_MinPrio = 0"
  "Kernel_C.minDom = 0"
  by (auto simp: seL4_MinPrio_def minDom_def)

lemma less_numDomains_is_domain[simplified word_size, simplified]:
  "x < numDomains \<Longrightarrow> x < 2 ^ size (y::domain)"
  unfolding Kernel_Config.numDomains_def
  by (simp add: word_size)

lemma sint_numDomains_to_H:
  "sint Kernel_C.numDomains = int Kernel_Config.numDomains"
  by (clarsimp simp: Kernel_C.numDomains_def Kernel_Config.numDomains_def)

lemma unat_numDomains_to_H:
  "unat Kernel_C.numDomains = Kernel_Config.numDomains"
  by (clarsimp simp: Kernel_C.numDomains_def Kernel_Config.numDomains_def)

lemma maxDom_to_H:
  "ucast maxDom = maxDomain"
  by (simp add: maxDomain_def Kernel_C.maxDom_def Kernel_Config.numDomains_def)

lemma maxDom_sgt_0_maxDomain:
  "0 <s maxDom \<longleftrightarrow> 0 < maxDomain"
  unfolding Kernel_C.maxDom_def maxDomain_def Kernel_Config.numDomains_def
  by clarsimp

lemma num_domains_calculation:
  "num_domains = numDomains"
  unfolding num_domains_val by eval

private lemma num_domains_card_explicit:
  "num_domains = CARD(num_domains)"
  by (simp add: num_domains_val)

lemmas num_domains_index_updates =
  index_update[where 'b=num_domains, folded num_domains_card_explicit num_domains_val,
               simplified num_domains_calculation]
  index_update2[where 'b=num_domains, folded num_domains_card_explicit num_domains_val,
                simplified num_domains_calculation]

(* C ArrayGuards will throw these at us and there is no way to avoid a proof of being less than a
   specific number expressed as a word, so we must introduce these. However, being explicit means
   lack of discipline can lead to a violation. *)
lemma numDomains_less_numeric_explicit[simplified num_domains_val One_nat_def]:
  "x < Kernel_Config.numDomains \<Longrightarrow> x < num_domains"
  by (simp add: num_domains_calculation)

lemma numDomains_less_unat_ucast_explicit[simplified num_domains_val]:
  "unat x < Kernel_Config.numDomains \<Longrightarrow> (ucast (x::domain) :: machine_word) < of_nat num_domains"
  apply (rule word_less_nat_alt[THEN iffD2])
  apply transfer
  apply simp
  apply (drule numDomains_less_numeric_explicit, simp add: num_domains_val)
  done

lemmas maxDomain_le_unat_ucast_explicit =
  numDomains_less_unat_ucast_explicit[simplified le_maxDomain_eq_less_numDomains(2)[symmetric],
                                      simplified]

end (* numDomain abstraction definitions and lemmas *)


text \<open>Priorities - not expected to be configurable\<close>

lemma maxPrio_to_H:
  "ucast seL4_MaxPrio = maxPriority"
  by (simp add: maxPriority_def seL4_MaxPrio_def numPriorities_def)


text \<open>TCB scheduling queues\<close>

(* establish and sanity-check relationship between the calculation of the number of TCB queues and
   the size of the array in C *)
value_type num_tcb_queues = "numDomains * numPriorities"

lemma num_tcb_queues_calculation:
  "num_tcb_queues = numDomains * numPriorities"
  unfolding num_tcb_queues_val by eval


(* Input abbreviations for API object types *)
(* disambiguates names *)

abbreviation(input)
  NotificationObject :: sword32
where
  "NotificationObject == seL4_NotificationObject"

abbreviation(input)
  CapTableObject :: sword32
where
  "CapTableObject == seL4_CapTableObject"

abbreviation(input)
  EndpointObject :: sword32
where
  "EndpointObject == seL4_EndpointObject"

abbreviation(input)
  VSpaceObject :: sword32
where
  "VSpaceObject == seL4_ARM_VSpaceObject"

abbreviation(input)
  PageTableObject :: sword32
where
  "PageTableObject == seL4_ARM_PageTableObject"

abbreviation(input)
  SmallPageObject :: sword32
where
  "SmallPageObject == seL4_ARM_SmallPageObject"

abbreviation(input)
  LargePageObject :: sword32
where
  "LargePageObject == seL4_ARM_LargePageObject"

abbreviation(input)
  HugePageObject :: sword32
where
  "HugePageObject == seL4_ARM_HugePageObject"

abbreviation(input)
  VCPUObject :: sword32
where
  "VCPUObject == seL4_ARM_VCPUObject"

abbreviation(input)
  TCBObject :: sword32
where
  "TCBObject == seL4_TCBObject"

abbreviation(input)
  UntypedObject :: sword32
where
  "UntypedObject == seL4_UntypedObject"

abbreviation(input)
  maxPrio :: sword32
where
  "maxPrio == seL4_MaxPrio"

abbreviation(input)
  minPrio :: sword32
where
  "minPrio == seL4_MinPrio"

abbreviation(input)
  nAPIObjects :: sword32
where
  "nAPIObjects == seL4_NonArchObjectTypeCount"

abbreviation(input)
  nObjects :: sword32
where
  "nObjects == seL4_ObjectTypeCount"

abbreviation(input)
  prioInvalid :: sword32
where
  "prioInvalid == seL4_InvalidPrio"

(* caches *)

definition cacheLineSize :: nat where
  "cacheLineSize \<equiv> 6"

lemma addrFromPPtr_mask_cacheLineSize:
  "addrFromPPtr ptr && mask cacheLineSize = ptr && mask cacheLineSize"
  apply (simp add: addrFromPPtr_def AARCH64.pptrBase_def pptrBaseOffset_def canonical_bit_def
                   paddrBase_def cacheLineSize_def mask_def)
  apply word_bitwise
  done

lemma pptrBaseOffset_cacheLineSize_aligned[simp]:
  "pptrBaseOffset && mask cacheLineSize = 0"
  by (simp add: pptrBaseOffset_def paddrBase_def pptrBase_def cacheLineSize_def mask_def)

lemma ptrFromPAddr_mask_cacheLineSize[simp]:
  "ptrFromPAddr v && mask cacheLineSize = v && mask cacheLineSize"
  by (simp add: ptrFromPAddr_def add_mask_ignore)

(* The magic 4 comes out of the bitfield generator -- this applies to all versions of the kernel. *)
lemma ThreadState_Restart_mask[simp]:
  "(scast ThreadState_Restart::machine_word) && mask 4 = scast ThreadState_Restart"
  by (simp add: ThreadState_Restart_def mask_def)

lemma aligned_tcb_ctcb_not_NULL:
  assumes "is_aligned p tcbBlockSizeBits"
  shows "tcb_ptr_to_ctcb_ptr p \<noteq> NULL"
proof
  assume "tcb_ptr_to_ctcb_ptr p = NULL"
  hence "p + ctcb_offset = 0"
     by (simp add: tcb_ptr_to_ctcb_ptr_def)
  moreover
  from `is_aligned p tcbBlockSizeBits`
  have "p + ctcb_offset = p || ctcb_offset"
    by (rule word_and_or_mask_aligned) (simp add: ctcb_offset_defs objBits_defs mask_def)
  moreover
  have "ctcb_offset !! ctcb_size_bits"
    by (simp add: ctcb_offset_defs objBits_defs)
  ultimately
  show False
    by (simp add: bang_eq)
qed

lemma tcb_at_not_NULL:
  "tcb_at' t s \<Longrightarrow> tcb_ptr_to_ctcb_ptr t \<noteq> NULL"
  by (rule aligned_tcb_ctcb_not_NULL) (rule tcb_aligned')

(* generic lemmas with arch-specific consequences *)

schematic_goal size_gpRegisters:
  "size AARCH64.gpRegisters = numeral ?x"
  supply Suc_eq_numeral[simp del] One_nat_def[simp del]
  by (simp add: upto_enum_def fromEnum_def enum_register
                AARCH64.gpRegisters_def)
     (simp add: Suc_eq_plus1)

schematic_goal size_frameRegisters:
  "size AARCH64.frameRegisters = numeral ?x"
  supply Suc_eq_numeral[simp del] One_nat_def[simp del]
  by (simp add: upto_enum_def fromEnum_def enum_register
                AARCH64.frameRegisters_def)
     (simp add: Suc_eq_plus1)

(* Could live in Refine, but we want to make sure this is only used in CRefine. Before CRefine
   the numeral value should never be stated explicitly. *)
schematic_goal maxPTLevel_val:
  "maxPTLevel = numeral ?n"
  by (simp add: maxPTLevel_def Kernel_Config.config_ARM_PA_SIZE_BITS_40_def)

end

end
