(*
 * Copyright 2019, Data61, CSIRO
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(DATA61_GPL)
 *)

theory Corres
imports StateRelation "CorresK.CorresK_Lemmas"
begin

text \<open>Instantiating the corres framework to this particular state relation.\<close>
abbreviation
 "corres \<equiv> corres_underlying state_relation False True"

end
