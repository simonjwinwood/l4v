(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

theory Cache (* FIXME: broken *)
imports Main
begin

text \<open>Enable the proof cache, both skipping from it
        and recording to it.\<close>
ML \<open>DupSkip.record_proofs := true\<close>
ML \<open>proofs := 1\<close>

ML \<open>DupSkip.skip_dup_proofs := true\<close>

text \<open>If executed in reverse order, save the cache\<close>
ML \<open>val cache_thy_save_cache = ref false;\<close>
ML \<open>
if (! cache_thy_save_cache)
then File.open_output (XML_Syntax.output_forest
           (XML_Syntax.xml_forest_of_cache (! DupSkip.the_cache)))
       (Path.basic "proof_cache.xml")
else ()\<close>
ML \<open>cache_thy_save_cache := true\<close>
ML \<open>cache_thy_save_cache := false\<close>

text \<open>Load the proof cache
           - can take up to a minute\<close>

ML \<open>
DupSkip.the_cache := XML_Syntax.cache_of_xml_forest (
    File.open_input (XML_Syntax.input_forest)
           (Path.basic "proof_cache.xml"))\<close>

end
