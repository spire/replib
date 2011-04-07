(* generated by Ott 0.20.1, locally-nameless backend, from: Unbound.ott *)

(* Once generated, this file has been heavily modified.*) 

Add LoadPath "metatheory".

Require Import Metatheory.
Require Import CoqEqDec.

(** syntax *)
Definition name := var.
Definition datacon := nat.

Inductive term : Set := 
 | var_b  : nat -> nat -> term
 | var_f  : name -> term
 | bind   : term -> term -> term
 | data   : datacon -> term
 | app    : term -> term -> term
 | rebind : term -> term -> term
 | rec    : term -> term
 | emb    : term -> term
 | shift  : term -> term.


Inductive mode := 
 | Term : mode
 | Pat  : mode.

Definition eq_mode_dec : forall x y: mode, { x = y } + { x <> y }.
decide equality.
Qed.

Print EqDec_eq.

Instance EqDec_mode : EqDec_eq mode := eq_mode_dec.

(** aeq **)
Fixpoint aeq (m:mode) (t1:term) (t2:term) : bool :=
  match t1, t2 with
    | var_b n11 n12, var_b n21 n22 =>
      if (n11 == n21) then beq_nat n12 n22 else false
    | var_f x, var_f y =>  match m with 
                           | Term =>  if x == y then true else false
                           | Pat  => false
                           end
    | bind p1 t1, bind p2 t2 => 
       aeq Pat p1 p2 && aeq Term t1 t2
    | data k1, data k2 => beq_nat k1 k2
    | app t1 t2, app u1 u2 => aeq m t1 u1 && aeq m t2 u2
    | rebind p1 t1, rebind p2 t2 => aeq Pat p1 p2 && aeq Pat p2 t2
    | rec p1, rec p2 => aeq Pat p1 p2
    | emb t1, emb t2 => aeq Term t1 t2
    | shift p1, shift p2 => aeq m p1 p2
    | _ , _ => false
  end.

(** free variables *)
Fixpoint fv (m:mode) (t_5:term) : vars :=
  match t_5 with
  | (var_b n1 n2) => {}
  | (var_f x) => match m with
                  | Term => {{x}}
                  | Pat  => {}
                 end
  | (bind p t) => (fv Pat p) \u (fv m t)
  | (data K) => {}
  | (app t1 t2) => (fv m t1) \u (fv m t2)
  | (rebind p t) => (fv Pat p) \u (fv m t)
  | (rec p) => (fv m p)
  | (emb t) => (fv Term t)
  | (shift p) => (fv m p)
end.


(* Strong pattern equality. Names must match *)
Fixpoint peq (t1:term) (t2:term) : bool :=
  match t1, t2 with
    | var_b n11 n12, var_b n21 n22 =>
      if (n11 == n21) then beq_nat n12 n22 else false
    | var_f x, var_f y =>   if x == y then true else false
    | bind p1 t1, bind p2 t2 => 
       peq p1 p2 && peq t1 t2
    | data k1, data k2 => beq_nat k1 k2
    | app t1 t2, app u1 u2 => peq t1 u1 && peq t2 u2
    | rebind p1 t1, rebind p2 t2 => peq p1 p2 && peq p2 t2
    | rec p1, rec p2 => peq p1 p2
    | emb t1, emb t2 => peq t1 t2
    | shift p1, shift p2 => peq p1 p2
    | _ , _ => false
  end.


(** binders *)
Fixpoint binders (t_5:term) : list var :=
  match t_5 with
  | (var_b n1 n2) => nil
  | (var_f x) => cons x nil
  | (bind p t) => nil
  | (data K) => nil
  | (app t1 t2) => (binders t1) ++ (binders t2)
  | (rebind p t) => (binders p) ++ (binders t)
  | (rec p) => (binders p)
  | (emb t) => nil
  | (shift p) => nil
end.



Inductive FindResult := 
  | index : nat -> FindResult
  | seen  : nat -> FindResult.

Definition FRappend (f1 : FindResult) (f2 : FindResult) :=
  match f1, f2 with 
  | seen i , seen j  => seen (i + j)
  | seen i , index j => index (i + j)
  | index j , _      => index j
  end.

Definition FRempty : FindResult := seen 0.

Fixpoint find (x : atom) (p : term) : FindResult :=
  match p with 
  | var_b x y => FRempty
  | var_f y => if x == y then index 0 else FRempty
  | data k => FRempty
  | app a1 a2 => FRappend (find x a1) (find x a2)
  | rebind p1 p2 => FRappend (find x p1) (find x p2)
  | emb t => FRempty
  | rec p => find x p
  | bind p t => FRempty
  | shift t => FRempty
  end.

Fixpoint close_term_wrt_term_rec (n1 : nat) (p : term) (t1 : term) {struct t1} 
: term :=
  match t1 with
    | var_f x2 => match find x2 p with 
                  | index j => var_b n1 j
                  | seen k => var_f x2
                  end
    | var_b n2 n3 => if (lt_ge_dec n2 n1) then (var_b n2 n3) else 
                     (var_b (S n2) n3) 
    | bind p1 t2 => bind (close_term_wrt_term_rec n1 p p1) 
                         (close_term_wrt_term_rec (S n1) p t2)
    | data K1 => data K1
    | app t2 t3 => app (close_term_wrt_term_rec n1 p t2) (close_term_wrt_term_rec n1 p t3)
    | rebind p1 t2 => rebind (close_term_wrt_term_rec n1 p p1) (close_term_wrt_term_rec (S n1) p t2)
    | rec p1 => rec (close_term_wrt_term_rec (S n1) p p1)
    | emb t2 => emb (close_term_wrt_term_rec n1 p t2)
    | shift p1 => shift (close_term_wrt_term_rec n1 p p1)
  end.

Definition close_term_wrt_term p t1 := close_term_wrt_term_rec 0 p t1.

Inductive NthResult : Set :=
  | found : var -> NthResult
  | cur_index : nat -> NthResult
.

Definition NRappend (f1 : NthResult) (f2 : NthResult) :=
  match f1, f2 with 
  | found x , _  => found x
  | _ , found x => found x
  | cur_index i , cur_index j => cur_index (i + j)
  end.

Definition NRempty : NthResult := cur_index 0.

Fixpoint nth (i : nat) (p : term) : NthResult :=
  match p with 
  | var_b x y => NRempty
  | var_f y => if i == 0 then found y else NRempty
  | data k => NRempty
  | app a1 a2 => NRappend (nth i a1) (nth i a2)
  | rebind p1 p2 => NRappend (nth i p1) (nth i p2)
  | emb t => NRempty
  | rec p => nth i p
  | bind p t => NRempty
  | shift t => NRempty
  end.


(** opening up abstractions *)
Fixpoint open_term_wrt_term_rec (k:nat) (p:term) (t__6:term) {struct t__6}: term :=
  match t__6 with
  | (var_b n1 n2) => 
    if (k === n1) then 
      match (nth n2 p) with
      | found x => var_f x
      | _       => var_b n1 n2
      end
    else (var_b n1 n2)
  | (var_f x) => var_f x
  | (bind p t) => bind (open_term_wrt_term_rec k p p) (open_term_wrt_term_rec (S k) p t)
  | (data K) => data K
  | (app t1 t2) => app (open_term_wrt_term_rec k p t1) (open_term_wrt_term_rec k p t2)
  | (rebind p t) => rebind (open_term_wrt_term_rec k p p) (open_term_wrt_term_rec (S k) p t)
  | (rec p) => rec (open_term_wrt_term_rec (S k) p p)
  | (emb t) => emb (open_term_wrt_term_rec k p t)
  | (shift p) => shift (open_term_wrt_term_rec (pred k) p p)
end.

Definition open_term_wrt_term p t__6 := open_term_wrt_term_rec 0 t__6 p.



(** substitutions *)
Fixpoint subst_term (t_5:term) (x5:name) (t__6:term) {struct t__6} : term :=
  match t__6 with
  | (var_b n1 n2) => var_b n1 n2
  | (var_f x) => (if eq_var x x5 then t_5 else (var_f x))
  | (bind p t) => bind (subst_term t_5 x5 p) (subst_term t_5 x5 t)
  | (data K) => data K
  | (app t1 t2) => app (subst_term t_5 x5 t1) (subst_term t_5 x5 t2)
  | (rebind p t) => rebind (subst_term t_5 x5 p) (subst_term t_5 x5 t)
  | (rec p) => rec (subst_term t_5 x5 p)
  | (emb t) => emb (subst_term t_5 x5 t)
  | (shift p) => shift (subst_term t_5 x5 p)
end.




(* *********************************************************************** *)
(** * Size *)

Fixpoint size_term (t1 : term) {struct t1} : nat :=
  match t1 with
    | var_f x1 => 1
    | var_b n1 n2 => 1
    | bind p1 t2 => 1 + (size_term p1) + (size_term t2)
    | data K1 => 1
    | app t2 t3 => 1 + (size_term t2) + (size_term t3)
    | rebind p1 t2 => 1 + (size_term p1) + (size_term t2)
    | rec p1 => 1 + (size_term p1)
    | emb t2 => 1 + (size_term t2)
    | shift p1 => 1 + (size_term p1)
  end.

Scheme term_ind' := Induction for term Sort Prop.

Definition term_mutind :=
  fun H1 H2 H3 H4 H5 H6 H7 H8 H9 =>
  term_ind' H1 H2 H3 H4 H5 H6 H7 H8 H9.


(* *********************************************************************** *)
(** * Degree *)

(** These define only an upper bound, not a strict upper bound. *)

Inductive degree_term_wrt_term : list nat -> term -> Prop :=
  | degree_wrt_term_var_f : forall n1 x1,
    degree_term_wrt_term n1 (var_f x1)
  | degree_wrt_term_var_b : forall n1 n2 n3 n4,
    List.nth_error n1 n2 = Some n4 ->
    lt n3 n4 ->
    degree_term_wrt_term n1 (var_b n2 n3)
  | degree_wrt_term_bind : forall n n1 p1 t1,
    degree_term_wrt_term n1 p1 ->
(*    length (binders p1) <= n -> *)
    degree_term_wrt_term (n :: n1) t1 ->
    degree_term_wrt_term n1 (bind p1 t1)
  | degree_wrt_term_data : forall n1 K1,
    degree_term_wrt_term n1 (data K1)
  | degree_wrt_term_app : forall n1 t1 t2,
    degree_term_wrt_term n1 t1 ->
    degree_term_wrt_term n1 t2 ->
    degree_term_wrt_term n1 (app t1 t2)
  | degree_wrt_term_rebind : forall n n1 p1 t1,
    degree_term_wrt_term n1 p1 ->
    degree_term_wrt_term (n :: n1) t1 ->
    degree_term_wrt_term n1 (rebind p1 t1)
  | degree_wrt_term_rec : forall n n1 p1,
    degree_term_wrt_term (n :: n1) p1 ->
    degree_term_wrt_term n1 (rec p1)
  | degree_wrt_term_emb : forall n1 t1,
    degree_term_wrt_term n1 t1 ->
    degree_term_wrt_term n1 (emb t1)
  | degree_wrt_term_shift : forall n1 p1,
    degree_term_wrt_term n1 p1 ->
    degree_term_wrt_term n1 (shift p1).

Scheme degree_term_wrt_term_ind' := Induction for degree_term_wrt_term Sort Prop.

Definition degree_term_wrt_term_mutind :=
  fun H1 H2 H3 H4 H5 H6 H7 H8 H9 H10 =>
  degree_term_wrt_term_ind' H1 H2 H3 H4 H5 H6 H7 H8 H9 H10.

Hint Constructors degree_term_wrt_term : core lngen.



(* *********************************************************************** *)
(** * Local closure (version in [Set], induction principles) *)

(* Here the local closure is a little weird. We need to be able 
   to rename the pattern variables to get a strong induction 
   principle here. *)

(* Rename the binders in the pattern using the list of variables. If 
   there are not enough names given, leaves the rest of the names alone..*)
Parameter rename : list var -> term -> term.


(* right now, lc_term is defined with weak definition. *)
Inductive lc_term : term -> Prop :=    (* defn lc_term *)
 | lc_var_f : forall (x:name),
     (lc_term (var_f x))
 | lc_bind : forall (L:vars) (p t:term),
     (lc_term p) ->
     (lc_term (open_term_wrt_term t p)) ->
     (lc_term (bind p t))
 | lc_data : forall (K:datacon),
     (lc_term (data K))
 | lc_app : forall (t1 t2:term),
     (lc_term t1) ->
     (lc_term t2) ->
     (lc_term (app t1 t2))
 | lc_rebind : forall (L:vars) (p t:term),
     (lc_term p) ->
     (lc_term  (open_term_wrt_term t p))  ->
     (lc_term (rebind p t))
 | lc_rec : forall (L:vars) (p:term),
     (lc_term  (open_term_wrt_term p p))  ->
     (lc_term (rec p))
 | lc_emb : forall (t:term),
     (lc_term t) ->
     (lc_term (emb t))
 | lc_shift : forall (p:term),
     (lc_term p) ->
     (lc_term (shift p)).

(** infrastructure *)
Hint Constructors lc_term.



Inductive lc_set_term : term -> Set :=
  | lc_set_var_f : forall x1,
    lc_set_term (var_f x1)
  | lc_set_bind : forall p1 t1,
    lc_set_term p1 ->
    (forall x1 : list name, forall p2: term, 
      rename x1 p1 = p2 ->
      lc_set_term (open_term_wrt_term t1 p2)) ->
    lc_set_term (bind p1 t1)
  | lc_set_data : forall K1,
    lc_set_term (data K1)
  | lc_set_app : forall t1 t2,
    lc_set_term t1 ->
    lc_set_term t2 ->
    lc_set_term (app t1 t2)
  | lc_set_rebind : forall p1 t1,
    lc_set_term p1 ->
    (forall x1 : list name, forall p2: term, 
      rename x1 p1 = Some p2 -> 
        lc_set_term (open_term_wrt_term t1 p2)) ->
    lc_set_term (rebind p1 t1)
  | lc_set_rec : forall p1,
    (forall x1 : list name, forall p2: term,
      rename x1 p1 = Some p2 -> 
        lc_set_term (open_term_wrt_term p1 p2)) ->
    lc_set_term (rec p1)
  | lc_set_emb : forall t1,
    lc_set_term t1 ->
    lc_set_term (emb t1)
  | lc_set_shift : forall p1,
    lc_set_term p1 ->
    lc_set_term (shift p1).


Scheme lc_term_ind' := Induction for lc_term Sort Prop.

Definition lc_term_mutind :=
  fun H1 H2 H3 H4 H5 H6 H7 H8 H9 =>
  lc_term_ind' H1 H2 H3 H4 H5 H6 H7 H8 H9.

Scheme lc_set_term_ind' := Induction for lc_set_term Sort Prop.

Definition lc_set_term_mutind :=
  fun H1 H2 H3 H4 H5 H6 H7 H8 H9 =>
  lc_set_term_ind' H1 H2 H3 H4 H5 H6 H7 H8 H9.

Scheme lc_set_term_rec' := Induction for lc_set_term Sort Set.

Definition lc_set_term_mutrec :=
  fun H1 H2 H3 H4 H5 H6 H7 H8 H9 =>
  lc_set_term_rec' H1 H2 H3 H4 H5 H6 H7 H8 H9.

Hint Constructors lc_term : core lngen.

Hint Constructors lc_set_term : core lngen.



(* *********************************************************************** *)
(** * Body *)

Definition body_term_wrt_term t1 := forall p, lc_term p -> lc_term (open_term_wrt_term t1 p).

Hint Unfold body_term_wrt_term.



Lemma l1 : forall x (p : term) i, 
   find x p = index i -> In x (binders p).
Admitted.


(** terms are locally-closed pre-terms *)
(** definitions *)








