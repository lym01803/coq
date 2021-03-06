(************************************************************************)
(*         *   The Coq Proof Assistant / The Coq Development Team       *)
(*  v      *   INRIA, CNRS and contributors - Copyright 1999-2019       *)
(* <O___,, *       (see CREDITS file for the list of authors)           *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

open Util
open Pp
open CErrors
open Notation
open Notation_gram

(*s Pretty-print. *)

type ppbox =
  | PpHB of int
  | PpHOVB of int
  | PpHVB of int
  | PpVB of int

type ppcut =
  | PpBrk of int * int
  | PpFnl

let ppcmd_of_box = function
  | PpHB n -> h n
  | PpHOVB n -> hov n
  | PpHVB n -> hv n
  | PpVB n -> v n

let ppcmd_of_cut = function
  | PpFnl -> fnl ()
  | PpBrk(n1,n2) -> brk(n1,n2)

type unparsing =
  | UnpMetaVar of int * parenRelation
  | UnpBinderMetaVar of int * parenRelation
  | UnpListMetaVar of int * parenRelation * unparsing list
  | UnpBinderListMetaVar of int * bool * unparsing list
  | UnpTerminal of string
  | UnpBox of ppbox * unparsing Loc.located list
  | UnpCut of ppcut

type unparsing_rule = unparsing list * precedence
type extra_unparsing_rules = (string * string) list

let rec unparsing_eq unp1 unp2 = match (unp1,unp2) with
  | UnpMetaVar (n1,p1), UnpMetaVar (n2,p2) -> n1 = n2 && p1 = p2
  | UnpBinderMetaVar (n1,p1), UnpBinderMetaVar (n2,p2) -> n1 = n2 && p1 = p2
  | UnpListMetaVar (n1,p1,l1), UnpListMetaVar (n2,p2,l2) -> n1 = n2 && p1 = p2 && List.for_all2eq unparsing_eq l1 l2
  | UnpBinderListMetaVar (n1,b1,l1), UnpBinderListMetaVar (n2,b2,l2) -> n1 = n2 && b1 = b2 && List.for_all2eq unparsing_eq l1 l2
  | UnpTerminal s1, UnpTerminal s2 -> String.equal s1 s2
  | UnpBox (b1,l1), UnpBox (b2,l2) -> b1 = b2 && List.for_all2eq unparsing_eq (List.map snd l1) (List.map snd l2)
  | UnpCut p1, UnpCut p2 -> p1 = p2
  | (UnpMetaVar _ | UnpBinderMetaVar _ | UnpListMetaVar _ |
     UnpBinderListMetaVar _ | UnpTerminal _ | UnpBox _ | UnpCut _), _ -> false

(* Concrete syntax for symbolic-extension table *)
let generic_notation_printing_rules =
  Summary.ref ~name:"generic-notation-printing-rules" (NotationMap.empty : (unparsing_rule * bool * extra_unparsing_rules) NotationMap.t)

let specific_notation_printing_rules =
  Summary.ref ~name:"specific-notation-printing-rules" (SpecificNotationMap.empty : (unparsing_rule * extra_unparsing_rules) SpecificNotationMap.t)

let declare_generic_notation_printing_rules ntn ~reserved ~extra unpl =
  generic_notation_printing_rules := NotationMap.add ntn (unpl,reserved,extra) !generic_notation_printing_rules
let declare_specific_notation_printing_rules specific_ntn ~extra unpl =
  specific_notation_printing_rules := SpecificNotationMap.add specific_ntn (unpl,extra) !specific_notation_printing_rules

let has_generic_notation_printing_rule ntn =
  NotationMap.mem ntn !generic_notation_printing_rules

let find_generic_notation_printing_rule ntn =
  NotationMap.find ntn !generic_notation_printing_rules

let find_specific_notation_printing_rule specific_ntn =
  SpecificNotationMap.find specific_ntn !specific_notation_printing_rules

let find_notation_printing_rule which ntn =
  try match which with
  | None -> raise Not_found (* Normally not the case *)
  | Some which -> fst (find_specific_notation_printing_rule (which,ntn))
  with Not_found -> pi1 (find_generic_notation_printing_rule ntn)

let find_notation_extra_printing_rules which ntn =
  try match which with
  | None -> raise Not_found
  | Some which -> snd (find_specific_notation_printing_rule (which,ntn))
  with Not_found -> pi3 (find_generic_notation_printing_rule ntn)

let add_notation_extra_printing_rule ntn k v =
  try
    generic_notation_printing_rules :=
      let p, b, pp = NotationMap.find ntn !generic_notation_printing_rules in
      NotationMap.add ntn (p, b, (k,v) :: pp) !generic_notation_printing_rules
  with Not_found ->
    user_err ~hdr:"add_notation_extra_printing_rule"
      (str "No such Notation.")
