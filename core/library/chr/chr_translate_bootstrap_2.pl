/*  $Id: chr_translate_bootstrap2.chr,v 1.9 2006/03/03 06:42:41 bmd Exp $

    Part of CHR (Constraint Handling Rules)

    Author:        Tom Schrijvers
    E-mail:        Tom.Schrijvers@cs.kuleuven.be
    WWW:           http://www.swi-prolog.org
    Copyright (C): 2003-2004, K.U. Leuven

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

    As a special exception, if you link this library with other files,
    compiled with a Free Software compiler, to produce an executable, this
    library does not by itself cause the resulting executable to be covered
    by the GNU General Public License. This exception does not however
    invalidate any other reasons why the executable file might be covered by
    the GNU General Public License.
*/

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%%   ____ _   _ ____     ____                      _ _
%%  / ___| | | |  _ \   / ___|___  _ __ ___  _ __ (_) | ___ _ __
%% | |   | |_| | |_) | | |   / _ \| '_ ` _ \| '_ \| | |/ _ \ '__|
%% | |___|  _  |  _ <  | |__| (_) | | | | | | |_) | | |  __/ |
%%  \____|_| |_|_| \_\  \____\___/|_| |_| |_| .__/|_|_|\___|_|
%%                                          |_|
%%
%% hProlog CHR compiler:
%%
%%	* by Tom Schrijvers, K.U. Leuven, Tom.Schrijvers@cs.kuleuven.be
%%
%%	* based on the SICStus CHR compilation by Christian Holzbaur
%%
%% First working version: 6 June 2003
%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%% URGENTLY TODO
%%
%% 	* fine-tune automatic selection of constraint stores
%%	
%% To Do
%%
%%	* further specialize runtime predicates for special cases where
%%	  - none of the constraints contain any indexing variables, ...
%%	  - just one constraint requires some runtime predicate
%%	* analysis for attachment delaying (see primes for case)
%%	* internal constraints declaration + analyses?
%%	* Do not store in global variable store if not necessary
%%		NOTE: affects show_store/1
%%	* multi-level store: variable - ground
%%	* Do not maintain/check unnecessary propagation history
%%		for rules that cannot be applied more than once
%%		e.g. due to groundness 
%%	* Strengthen attachment analysis:
%%		reason about bodies of rules only containing constraints
%%
%%	* SICStus compatibility
%%		- rules/1 declaration
%%		- options
%%		- pragmas
%%		- tell guard
%%	* instantiation declarations
%%		POTENTIAL GAIN:
%%			GROUND
%%			- cheaper matching code?
%%			VARIABLE (never bound)
%%			
%%	* make difference between cheap guards		for reordering
%%	                      and non-binding guards	for lock removal
%%	* unqiue -> once/[] transformation for propagation
%%	* cheap guards interleaved with head retrieval + faster
%%	  via-retrieval + non-empty checking for propagation rules
%%	  redo for simpagation_head2 prelude
%%	* intelligent backtracking for simplification/simpagation rule
%%		generator_1(X),'_$savecp'(CP_1),
%%              ... 
%%              if( (
%%			generator_n(Y), 
%%		     	test(X,Y)
%%		    ),
%%		    true,
%%		    ('_$cutto'(CP_1), fail)
%%		),
%%		...
%%
%%	  or recently developped cascading-supported approach 
%%
%%      * intelligent backtracking for propagation rule
%%          use additional boolean argument for each possible smart backtracking
%%          when boolean at end of list true  -> no smart backtracking
%%                                      false -> smart backtracking
%%          only works for rules with at least 3 constraints in the head
%%
%%	* mutually exclusive rules
%%	* (set semantics + functional dependency) declaration + resolution
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%:- module( chr_translate, 
%          	  [ chr_translate/2		% +Decls, -TranslatedDecls
%	  ]).
%% SWI begin
%% Ciao begin
%:- use_module(library(lists),[append/3,member/2,permutation/2,reverse/2]).
:- use_module(library(lists),[length/2,append/3,reverse/2,select/3, delete/3]).
:- use_module(library(format)).
:- use_module(library(write)).
%:- use_module(library(aggregates)).
:- use_module(library(iso_misc), [once/1] ).
%% Ciao end
%% SWI end

%% SICStus begin
%% :- use_module(library(lists),[is_list/1,append/3,member/2,delete/3,
%% 			      memberchk/2,reverse/2,permutation/2]).
%% SICStus end

%% Ciao begin
:- use_module(library(chr/hprolog)).
:- use_module(library(chr/pairlist)).
%:- use_module(library(ordsets)).
:- use_module(library(sets)).
:- push_prolog_flag( multi_arity_warnings , off ).

:- use_module(library(chr/a_star)).
:- use_module(library(chr/clean_code)).
:- use_module(library(chr/builtins)).
:- use_module(library(chr/chr_find)).
:- include(library(chr/chr_op2)).
%% Ciao end


:- chr_option(debug,off).
:- chr_option(optimize,full).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- chr_constraint

	constraint/2,				% constraint(F/A,ConstraintIndex)
	get_constraint/2,

	constraint_count/1,			% constraint_count(MaxConstraintIndex)
	get_constraint_count/1,

	constraint_index/2,			% constraint_index(F/A,DefaultStoreAndAttachedIndex)
	get_constraint_index/2,			

	max_constraint_index/1,			% max_constraint_index(MaxDefaultStoreAndAttachedIndex)
	get_max_constraint_index/1,

	target_module/1,			% target_module(Module)
	get_target_module/1,

	attached/2,				% attached(F/A,yes/no/maybe)
	is_attached/1,

	indexed_argument/2,			% argument instantiation may enable applicability of rule
	is_indexed_argument/2,

	constraint_mode/2,
	get_constraint_mode/2,

	may_trigger/1,
	
	has_nonground_indexed_argument/3,

	store_type/2,
	get_store_type/2,
	update_store_type/2,
	actual_store_types/2,
	assumed_store_type/2,
	validate_store_type_assumption/1,

	rule_count/1,
	inc_rule_count/1,
	get_rule_count/1,

	passive/2,
	is_passive/2,
	any_passive_head/1,

	pragma_unique/3,
	get_pragma_unique/3,

	occurrence/4,
	get_occurrence/4,

	max_occurrence/2,
	get_max_occurrence/2,

	allocation_occurrence/2,
	get_allocation_occurrence/2,
	rule/2,
	get_rule/2
	. 

:- chr_option(mode,constraint(+,+)).
:- chr_option(mode,constraint_count(+)).
:- chr_option(mode,constraint_index(+,+)).
:- chr_option(mode,max_constraint_index(+)).
:- chr_option(mode,target_module(+)).
:- chr_option(mode,attached(+,+)).
:- chr_option(mode,indexed_argument(+,+)).
:- chr_option(mode,constraint_mode(+,+)).
:- chr_option(mode,may_trigger(+)).
:- chr_option(mode,store_type(+,+)).
:- chr_option(mode,actual_store_types(+,+)).
:- chr_option(mode,assumed_store_type(+,+)).
:- chr_option(mode,rule_count(+)).
:- chr_option(mode,passive(+,+)).
:- chr_option(mode,pragma_unique(+,+,?)).
:- chr_option(mode,occurrence(+,+,+,+)).
:- chr_option(mode,max_occurrence(+,+)).
:- chr_option(mode,allocation_occurrence(+,+)).
:- chr_option(mode,rule(+,+)).

constraint(FA,Index)  \ get_constraint(Query,Index)
	<=> Query = FA.
get_constraint(_,_)
	<=> fail.

constraint_count(Index) \ get_constraint_count(Query) 
	<=> Query = Index.
get_constraint_count(Query)
	<=> Query = 0.

target_module(Mod) \ get_target_module(Query)
	<=> Query = Mod .
get_target_module(Query)
	<=> Query = user.

constraint_index(C,Index) \ get_constraint_index(C,Query)
	<=> Query = Index.
get_constraint_index(_,_)
	<=> fail.

max_constraint_index(Index) \ get_max_constraint_index(Query)
	<=> Query = Index.
get_max_constraint_index(Query)
	<=> Query = 0.

attached(Constr,yes) \ attached(Constr,_) <=> true.
attached(Constr,no) \ attached(Constr,_) <=> true.
attached(Constr,maybe) \ attached(Constr,maybe) <=> true.

attached(Constr,Type) \ is_attached(Constr) 
	<=> Type \== no.
is_attached(_) <=> true.

indexed_argument(FA,I) \ indexed_argument(FA,I) <=> true.
indexed_argument(FA,I) \ is_indexed_argument(FA,I) <=> true.
is_indexed_argument(_,_) <=> fail.

constraint_mode(FA,Mode) \ get_constraint_mode(FA,Query)
	<=> Query = Mode.
get_constraint_mode(FA,Query)
	<=> FA = _/A, length(Query,A), set_elems(Query,?). 

may_trigger(FA) <=> 
  is_attached(FA), 
  get_constraint_mode(FA,Mode),
  has_nonground_indexed_argument(FA,1,Mode).

has_nonground_indexed_argument(FA,I,[Mode|Modes])
	<=> 
		true
	|
		( is_indexed_argument(FA,I),
		  Mode \== (+) ->
			true
		;
			J is I + 1,
			has_nonground_indexed_argument(FA,J,Modes)
		).	
has_nonground_indexed_argument(_,_,_) 
	<=> fail.

store_type(FA,atom_hash(Index)) <=> store_type(FA,multi_hash([Index])).
store_type(FA,Store) \ get_store_type(FA,Query)
	<=> Query = Store.
assumed_store_type(FA,Store) \ get_store_type(FA,Query)
	<=> Query = Store.
get_store_type(_,Query) 
	<=> Query = default.

actual_store_types(C,STs) \ update_store_type(C,ST)
	<=> member(ST,STs) | true.
update_store_type(C,ST), actual_store_types(C,STs)
	<=> 
		actual_store_types(C,[ST|STs]).
update_store_type(C,ST)
	<=> 
		actual_store_types(C,[ST]).

% refine store type assumption
validate_store_type_assumption(C), actual_store_types(C,STs), assumed_store_type(C,_) 	% automatic assumption
	<=> 
		store_type(C,multi_store(STs)).
validate_store_type_assumption(C), actual_store_types(C,STs), store_type(C,_) 		% user assumption
	<=> 
		store_type(C,multi_store(STs)).
validate_store_type_assumption(_) 
	<=> true.

rule_count(C), inc_rule_count(NC)
	<=> NC is C + 1, rule_count(NC).
inc_rule_count(NC)
	<=> NC = 1, rule_count(NC).

rule_count(C) \ get_rule_count(Q)
	<=> Q = C.
get_rule_count(Q) 
	<=> Q = 0.

passive(RuleNb,ID) \ is_passive(RuleNb,ID)
	<=> true.
is_passive(_,_)
	<=> fail.
passive(RuleNb,_) \ any_passive_head(RuleNb)
	<=> true.
any_passive_head(_)
	<=> fail.

pragma_unique(RuleNb,ID,Vars) \ get_pragma_unique(RuleNb,ID,Query)
	<=> Query = Vars.
get_pragma_unique(_,_,_)
	<=> true.	

occurrence(C,ON,Rule,ID) \ get_occurrence(C,ON,QRule,QID)
	<=> Rule = QRule, ID = QID.
get_occurrence(_,_,_,_)
	<=> fail.

occurrence(C,ON,_,_) ==> max_occurrence(C,ON).
max_occurrence(C,N) \ max_occurrence(C,M)
	<=> N >= M | true.
max_occurrence(C,MON) \ get_max_occurrence(C,Q)
	<=> Q = MON.
get_max_occurrence(_,Q)
	<=> Q = 0.

	% need not store constraint that is removed
rule(RuleNb,Rule), occurrence(C,O,RuleNb,ID) \ allocation_occurrence(C,O)
	<=> Rule = pragma(_,ids(IDs1,_),_,_,_), member(ID,IDs) 
	| NO is O + 1, allocation_occurrence(C,NO).
	% need not store constraint when body is true
rule(RuleNb,Rule), occurrence(C,O,RuleNb,_) \ allocation_occurrence(C,O)
	<=> Rule = pragma(rule(_,_,_,true),_,_,_,_)
	| NO is O + 1, allocation_occurrence(C,NO).
	% cannot store constraint at passive occurrence
occurrence(C,O,RuleNb,ID), passive(RuleNb,ID) \ allocation_occurrence(C,O)
	<=> NO is O + 1, allocation_occurrence(C,NO). 
allocation_occurrence(C,O) \ get_allocation_occurrence(C,Q)
	<=> Q = O.
get_allocation_occurrence(_,_)
	<=> fail.

rule(RuleNb,Rule) \ get_rule(RuleNb,Q)
	<=> Q = Rule.
get_rule(_,_)
	<=> fail.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%% Translation

chr_translate(Declarations,NewDeclarations) :-
	init_chr_pp_flags,
	partition_clauses(Declarations,Constraints,Rules,OtherClauses),
	( Constraints == [] ->
		insert_declarations(OtherClauses, NewDeclarations)
	;
		% start analysis
		add_rules(Rules),
		check_rules(Rules,Constraints),
		add_occurrences(Rules),
		late_allocation(Constraints),
		unique_analyse_optimise(Rules,NRules),
		check_attachments(Constraints),
		assume_constraint_stores(Constraints),
		set_constraint_indices(Constraints,1),
		% end analysis
		constraints_code(Constraints,NRules,ConstraintClauses),
		validate_store_type_assumptions(Constraints),
		store_management_preds(Constraints,StoreClauses),	% depends on actual code used
	  	insert_declarations(OtherClauses, Clauses0),
%		chr_module_declaration(CHRModuleDeclaration),
		append([Clauses0,
			StoreClauses,
			ConstraintClauses
%			CHRModuleDeclaration
		       ],
		       NewDeclarations)
	).

store_management_preds(Constraints,Clauses) :-
		generate_attach_detach_a_constraint_all(Constraints,AttachAConstraintClauses),
		generate_indexed_variables_clauses(Constraints,IndexedClauses),
		generate_attach_increment(AttachIncrementClauses),
		generate_attr_unify_hook(AttrUnifyHookClauses),
		generate_extra_clauses(Constraints,ExtraClauses),
		generate_insert_delete_constraints(Constraints,DeleteClauses),
		generate_store_code(Constraints,StoreClauses),
		append([AttachAConstraintClauses
		       ,IndexedClauses
		       ,AttachIncrementClauses
		       ,AttrUnifyHookClauses
		       ,ExtraClauses
		       ,DeleteClauses
		       ,StoreClauses]
		      ,Clauses).


%% SWI begin
% specific_declarations([(:- use_module('chr_runtime')),
% 		       (:- use_module('chr_hashtable_store')),
% 		       (:- style_check(-singleton)),
% 		       (:- style_check(-discontiguous))
% 		      |Tail],Tail).
%% SWI end

%% SICStus begin
%% specific_declarations([(:- use_module('chr_runtime')),
%% 		       (:- use_module('chr_hashtable_store')),
%% 		       (:- set_prolog_flag(discontiguous_warnings,off)),
%% 		       (:- set_prolog_flag(single_var_warnings,off))
%% 		      |Tail],Tail).
%% SICStus end

%% Ciao begin
specific_declarations( A, A ).
%% Ciao end



insert_declarations(Clauses0, Clauses) :-
	specific_declarations(Decls,Tail),
	( Clauses0 = [ (:- module(M,E))|FileBody] ->
	    Clauses = [ (:- module(M,E))|Decls],
	    Tail = FileBody
	;
	    Clauses = Decls,
	    Tail = Clauses0
	).


chr_module_declaration(CHRModuleDeclaration) :-
	get_target_module(Mod),
	( Mod \== chr_translate ->
		CHRModuleDeclaration = [
			(:- multifile '$chr_module'/1),
			'$chr_module'(Mod)	
		]
	;
		CHRModuleDeclaration = []
	).	


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%% Partitioning of clauses into constraint declarations, chr rules and other 
%% clauses

partition_clauses([],[],[],[]).
partition_clauses([C|Cs],Ds,Rs,OCs) :-
  (   parse_rule(C,R) ->
      Ds = RDs,
      Rs = [R | RRs], 
      OCs = ROCs
  ;   is_declaration(C,D) ->
      append(D,RDs,Ds),
      Rs = RRs,
      OCs = ROCs
  ;   is_module_declaration(C,Mod) ->
      target_module(Mod),
      Ds = RDs,
      Rs = RRs,
      OCs = [C|ROCs]
  ;   C = (handler _) ->
      format('CHR compiler WARNING: ~w.\n',[C]),
      format('    `-->  SICStus compatibility: ignoring handler/1 declaration.\n',[]),
      Ds = RDs,
      Rs = RRs,
      OCs = ROCs
  ;   C = (rules _) ->
      format('CHR compiler WARNING: ~w.\n',[C]),
      format('    `-->  SICStus compatibility: ignoring rules/1 declaration.\n',[]),
      Ds = RDs,
      Rs = RRs,
      OCs = ROCs
  ;   C = (:- chr_option(OptionName,OptionValue)) ->
      handle_option(OptionName,OptionValue),
      Ds = RDs,
      Rs = RRs,
      OCs = ROCs
  ;   Ds = RDs,
      Rs = RRs,
      OCs = [C|ROCs]
  ),
  partition_clauses(Cs,RDs,RRs,ROCs).

is_declaration(D, Constraints) :-		%% constraint declaration
  D = (:- Decl),
  ( Decl =.. [chr_constraint,Cs] ; Decl =.. [chr_constraint,Cs]),
  conj2list(Cs,Constraints).

%% Data Declaration
%%
%% pragma_rule 
%%	-> pragma(
%%		rule,
%%		ids,
%%		list(pragma),
%%		yesno(string),		:: maybe rule nane
%%		int			:: rule number
%%		)
%%
%% ids	-> ids(
%%		list(int),
%%		list(int)
%%		)
%%		
%% rule -> rule(
%%		list(constraint),	:: constraints to be removed
%%		list(constraint),	:: surviving constraints
%%		goal,			:: guard
%%		goal			:: body
%%	 	)

parse_rule(RI,R) :-				%% name @ rule
	RI = (Name @ RI2), !,
	rule(RI2,yes(Name),R).
parse_rule(RI,R) :-
	rule(RI,no,R).

rule(RI,Name,R) :-
	RI = (RI2 pragma P), !,			%% pragmas
	is_rule(RI2,R1,IDs),
	conj2list(P,Ps),
	inc_rule_count(RuleCount),
	R = pragma(R1,IDs,Ps,Name,RuleCount).
rule(RI,Name,R) :-
	is_rule(RI,R1,IDs),
	inc_rule_count(RuleCount),
	R = pragma(R1,IDs,[],Name,RuleCount).

is_rule(RI,R,IDs) :-				%% propagation rule
   RI = (H ==> B), !,
   conj2list(H,Head2i),
   get_ids(Head2i,IDs2,Head2),
   IDs = ids([],IDs2),
   (   B = (G | RB) ->
       R = rule([],Head2,G,RB)
   ;
       R = rule([],Head2,true,B)
   ).
is_rule(RI,R,IDs) :-				%% simplification/simpagation rule
   RI = (H <=> B), !,
   (   B = (G | RB) ->
       Guard = G,
       Body  = RB
   ;   Guard = true,
       Body = B
   ),
   (   H = (H1 \ H2) ->
       conj2list(H1,Head2i),
       conj2list(H2,Head1i),
       get_ids(Head2i,IDs2,Head2,0,N),
       get_ids(Head1i,IDs1,Head1,N,_),
       IDs = ids(IDs1,IDs2)
   ;   conj2list(H,Head1i),
       Head2 = [],
       get_ids(Head1i,IDs1,Head1),
       IDs = ids(IDs1,[])
   ),
   R = rule(Head1,Head2,Guard,Body).

get_ids(Cs,IDs,NCs) :-
	get_ids(Cs,IDs,NCs,0,_).

get_ids([],[],[],N,N).
get_ids([C|Cs],[N|IDs],[NC|NCs],N,NN) :-
	( C = (NC # N) ->
		true
	;
		NC = C
	),
	M is N + 1,
	get_ids(Cs,IDs,NCs, M,NN).

is_module_declaration((:- module(Mod)),Mod).
is_module_declaration((:- module(Mod,_)),Mod).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Add rules
add_rules([]).
add_rules([Rule|Rules]) :-
	Rule = pragma(_,_,_,_,RuleNb),
	rule(RuleNb,Rule),
	add_rules(Rules).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Some input verification:
%%  - all constraints in heads are declared constraints
%%  - all passive pragmas refer to actual head constraints

check_rules([],_).
check_rules([PragmaRule|Rest],Decls) :-
	check_rule(PragmaRule,Decls),
	check_rules(Rest,Decls).

check_rule(PragmaRule,Decls) :-
	check_rule_indexing(PragmaRule),
	PragmaRule = pragma(Rule,_IDs,Pragmas,_Name,_N),
	Rule = rule(H1,H2,_,_),
	append(H1,H2,HeadConstraints),
	check_head_constraints(HeadConstraints,Decls,PragmaRule),
	check_pragmas(Pragmas,PragmaRule).

check_head_constraints([],_,_).
check_head_constraints([Constr|Rest],Decls,PragmaRule) :-
	functor(Constr,F,A),
	( member(F/A,Decls) ->
		check_head_constraints(Rest,Decls,PragmaRule)
	;
		format('CHR compiler ERROR: Undeclared constraint ~w in head of ~@.\n',
		       [F/A,format_rule(PragmaRule)]),
		format('    `--> Constraint should be one of ~w.\n',[Decls]),
		fail
	).

check_pragmas([],_).
check_pragmas([Pragma|Pragmas],PragmaRule) :-
	check_pragma(Pragma,PragmaRule),
	check_pragmas(Pragmas,PragmaRule).

check_pragma(Pragma,PragmaRule) :-
	var(Pragma), !,
	format('CHR compiler ERROR: invalid pragma ~w in ~@.\n',
               [Pragma,format_rule(PragmaRule)]),
	format('    `--> Pragma should not be a variable!\n',[]),
	fail.
check_pragma(passive(ID), PragmaRule) :-
	!,
	PragmaRule = pragma(_,ids(IDs1,IDs2),_,_,RuleNb),
	( memberchk_eq(ID,IDs1) ->
		true
	; memberchk_eq(ID,IDs2) ->
		true
	;
		format('CHR compiler ERROR: invalid identifier ~w in pragma passive in ~@.\n',
                       [ID,format_rule(PragmaRule)]),
		fail
	),
	passive(RuleNb,ID).

check_pragma(Pragma, PragmaRule) :-
	Pragma = unique(ID,Vars),
	!,
	PragmaRule = pragma(_,_,_,_,RuleNb),
	pragma_unique(RuleNb,ID,Vars),
	format('CHR compiler WARNING: undocumented pragma ~w in ~@.\n',[Pragma,format_rule(PragmaRule)]),
	format('    `--> Only use this pragma if you know what you are doing.\n',[]).

check_pragma(Pragma, PragmaRule) :-
	Pragma = already_in_heads,
	!,
	format('CHR compiler WARNING: currently unsupported pragma ~w in ~@.\n',[Pragma,format_rule(PragmaRule)]),
	format('    `--> Pragma is ignored. Termination and correctness may be affected \n',[]).

check_pragma(Pragma, PragmaRule) :-
	Pragma = already_in_head(_),
	!,
	format('CHR compiler WARNING: currently unsupported pragma ~w in ~@.\n',[Pragma,format_rule(PragmaRule)]),
	format('    `--> Pragma is ignored. Termination and correctness may be affected \n',[]).
	
check_pragma(Pragma,PragmaRule) :-
	format('CHR compiler ERROR: invalid pragma ~w in ~@.\n',[Pragma,format_rule(PragmaRule)]),
	format('    `--> Pragma should be one of passive/1!\n',[]),
	fail.

format_rule(PragmaRule) :-
	PragmaRule = pragma(_,_,_,MaybeName,N),
	( MaybeName = yes(Name) ->
		write('rule '), write(Name)
	;
		write('rule number '), write(N)
	).

check_rule_indexing(PragmaRule) :-
	PragmaRule = pragma(Rule,_,_,_,_),
	Rule = rule(H1,H2,G,_),
	term_variables(H1-H2,HeadVars),
	remove_anti_monotonic_guards(G,HeadVars,NG),
	check_indexing(H1,NG-H2),
	check_indexing(H2,NG-H1).

remove_anti_monotonic_guards(G,Vars,NG) :-
	conj2list(G,GL),
	remove_anti_monotonic_guard_list(GL,Vars,NGL),
	list2conj(NGL,NG).

remove_anti_monotonic_guard_list([],_,[]).
remove_anti_monotonic_guard_list([G|Gs],Vars,NGs) :-
	( G = var(X),
          memberchk_eq(X,Vars) ->
		NGs = RGs
	;
		NGs = [G|RGs]
	),
	remove_anti_monotonic_guard_list(Gs,Vars,RGs).

check_indexing([],_).
check_indexing([Head|Heads],Other) :-
	functor(Head,F,A),
	Head =.. [_|Args],
	term_variables(Heads-Other,OtherVars),
	check_indexing(Args,1,F/A,OtherVars),
	check_indexing(Heads,[Head|Other]).	

check_indexing([],_,_,_).
check_indexing([Arg|Args],I,FA,OtherVars) :-
	( is_indexed_argument(FA,I) ->
		true
	; nonvar(Arg) ->
		indexed_argument(FA,I)
	; % var(Arg) ->
		term_variables(Args,ArgsVars),
		append(ArgsVars,OtherVars,RestVars),
		( memberchk_eq(Arg,RestVars) ->
			indexed_argument(FA,I)
		;
			true
		)
	),
	J is I + 1,
	term_variables(Arg,NVars),
	append(NVars,OtherVars,NOtherVars),
	check_indexing(Args,J,FA,NOtherVars).	

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Occurrences

add_occurrences([]).
add_occurrences([Rule|Rules]) :-
	Rule = pragma(rule(H1,H2,_,_),ids(IDs1,IDs2),_,_,Nb),
	add_occurrences(H1,IDs1,Nb),
	add_occurrences(H2,IDs2,Nb),
	add_occurrences(Rules).

add_occurrences([],[],_).
add_occurrences([H|Hs],[ID|IDs],RuleNb) :-
	functor(H,F,A),
	FA = F/A,
	get_max_occurrence(FA,MO),
	O is MO + 1,
	occurrence(FA,O,RuleNb,ID),
	add_occurrences(Hs,IDs,RuleNb).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Late allocation

late_allocation([]).
late_allocation([C|Cs]) :-
	allocation_occurrence(C,1),
	late_allocation(Cs).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Global Options
%

handle_option(Var,Value) :- 
	var(Var), !,
	format('CHR compiler ERROR: ~w.\n',[option(Var,Value)]),
	format('    `--> First argument should be an atom, not a variable.\n',[]),
	fail.

handle_option(Name,Value) :- 
	var(Value), !,
	format('CHR compiler ERROR: ~w.\n',[option(Name,Value)]),
	format('    `--> Second argument should be a nonvariable.\n',[]),
	fail.

handle_option(Name,Value) :-
	option_definition(Name,Value,Flags),
	!,
	set_chr_pp_flags(Flags).

handle_option(Name,Value) :- 
	\+ option_definition(Name,_,_), !,
%	setof(N,_V ^ _F ^ (option_definition(N,_V,_F)),Ns),
	format('CHR compiler WARNING: ~w.\n',[option(Name,Value)]),
	format('    `--> Invalid option name \n',[]). %~w: should be one of ~w.\n',[Name,Ns]).

handle_option(Name,Value) :- 
	findall(V,option_definition(Name,V,_),Vs), 
	format('CHR compiler ERROR: ~w.\n',[option(Name,Value)]),
	format('    `--> Invalid value ~w: should be one of ~w.\n',[Value,Vs]),
	fail.

option_definition(optimize,experimental,Flags) :-
	Flags = [ unique_analyse_optimise  - on,
                  check_unnecessary_active - full,
		  reorder_heads		   - on,
		  set_semantics_rule	   - on,
		  check_attachments	   - on,
		  guard_via_reschedule     - on
		].
option_definition(optimize,full,Flags) :-
	Flags = [ unique_analyse_optimise  - on,
                  check_unnecessary_active - full,
		  reorder_heads		   - on,
		  set_semantics_rule	   - on,
		  check_attachments	   - on,
		  guard_via_reschedule     - on
		].

option_definition(optimize,sicstus,Flags) :-
	Flags = [ unique_analyse_optimise  - off,
                  check_unnecessary_active - simplification,
		  reorder_heads		   - off,
		  set_semantics_rule	   - off,
		  check_attachments	   - off,
		  guard_via_reschedule     - off
		].

option_definition(optimize,off,Flags) :-
	Flags = [ unique_analyse_optimise  - off,
                  check_unnecessary_active - off,
		  reorder_heads		   - off,
		  set_semantics_rule	   - off,
		  check_attachments	   - off,
		  guard_via_reschedule     - off
		].

option_definition(check_guard_bindings,on,Flags) :-
	Flags = [ guard_locks - on ].

option_definition(check_guard_bindings,off,Flags) :-
	Flags = [ guard_locks - off ].

option_definition(reduced_indexing,on,Flags) :-
	Flags = [ reduced_indexing - on ].

option_definition(reduced_indexing,off,Flags) :-
	Flags = [ reduced_indexing - off ].

option_definition(mode,ModeDecl,[]) :-
	(nonvar(ModeDecl) ->
	    functor(ModeDecl,F,A),
	    ModeDecl =.. [_|ArgModes],
	    constraint_mode(F/A,ArgModes)
	;
	    true
	).
option_definition(store,FA-Store,[]) :-
	store_type(FA,Store).

option_definition(debug,on,Flags) :-
	Flags = [ debugable - on ].
option_definition(debug,off,Flags) :-
	Flags = [ debugable - off ].
option_definition(type_definition, _, []). % JW: ignored by bootstrap compiler
option_definition(type_declaration, _, []). % JW: ignored by bootstrap compiler

init_chr_pp_flags :-
	findall(Name-DefaultValue,chr_pp_flag_definition(Name,[DefaultValue|_]),NDs),
	set_chr_pp_flags(NDs).
        %set_chr_pp_flag(Name,DefaultValue),
	%fail.
%init_chr_pp_flags.		

set_chr_pp_flags([]).
set_chr_pp_flags([Name-Value|Flags]) :-
	set_chr_pp_flag(Name,Value),
	set_chr_pp_flags(Flags).

set_chr_pp_flag(Name,Value) :-
	atom_concat('$chr_pp_',Name,GlobalVar),
	nb_setval(GlobalVar,Value).

chr_pp_flag_definition(unique_analyse_optimise,[off,on]).
chr_pp_flag_definition(check_unnecessary_active,[full,simplification,off]).
chr_pp_flag_definition(reorder_heads,[on,off]).
chr_pp_flag_definition(set_semantics_rule,[on,off]).
chr_pp_flag_definition(guard_via_reschedule,[on,off]).
chr_pp_flag_definition(guard_locks,[on,off]).
chr_pp_flag_definition(check_attachments,[on,off]).
chr_pp_flag_definition(debugable,[off,on]).
chr_pp_flag_definition(reduced_indexing,[on,off]).

chr_pp_flag(Name,Value) :-
	atom_concat('$chr_pp_',Name,GlobalVar),
	nb_getval(GlobalVar,V),
	( V == [] ->
		chr_pp_flag_definition(Name,[Value|_])
	;
		V = Value
	).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%% Generated predicates
%%	attach_$CONSTRAINT
%%	attach_increment
%%	detach_$CONSTRAINT
%%	attr_unify_hook

%%	attach_$CONSTRAINT
generate_attach_detach_a_constraint_all([],[]).
generate_attach_detach_a_constraint_all([Constraint|Constraints],Clauses) :-
	( may_trigger(Constraint) ->
		generate_attach_a_constraint(Constraint,Clauses1),
		generate_detach_a_constraint(Constraint,Clauses2)
	;
		Clauses1 = [],
		Clauses2 = []
	),	
	generate_attach_detach_a_constraint_all(Constraints,Clauses3),
	append([Clauses1,Clauses2,Clauses3],Clauses).

generate_attach_a_constraint(Constraint,[Clause1,Clause2]) :-
	generate_attach_a_constraint_empty_list(Constraint,Clause1),
	get_max_constraint_index(N),
	( N == 1 ->
		generate_attach_a_constraint_1_1(Constraint,Clause2)
	;
		generate_attach_a_constraint_t_p(Constraint,Clause2)
	).

generate_attach_a_constraint_skeleton(FA,Args,Body,Clause) :-
	make_name('attach_',FA,Fct),
	Head =.. [Fct | Args],
	Clause = ( Head :- Body).

generate_attach_a_constraint_empty_list(FA,Clause) :-
	generate_attach_a_constraint_skeleton(FA,[[],_],true,Clause).

generate_attach_a_constraint_1_1(FA,Clause) :-
	Args = [[Var|Vars],Susp],
	generate_attach_a_constraint_skeleton(FA,Args,Body,Clause),
	generate_attach_body_1(FA,Var,Susp,AttachBody),
	make_name('attach_',FA,Fct),
	RecursiveCall =.. [Fct,Vars,Susp],
	Body =
	(
		AttachBody,
		RecursiveCall
	).

generate_attach_body_1(FA,Var,Susp,Body) :-
	get_target_module(Mod),
	Body =
	(   get_attr(Var, Mod, Susps) ->
            NewSusps=[Susp|Susps],
            put_attr(Var, Mod, NewSusps)
        ;   
            put_attr(Var, Mod, [Susp])
	).

generate_attach_a_constraint_t_p(FA,Clause) :-
	Args = [[Var|Vars],Susp],
	generate_attach_a_constraint_skeleton(FA,Args,Body,Clause),
	make_name('attach_',FA,Fct),
	RecursiveCall =.. [Fct,Vars,Susp],
	generate_attach_body_n(FA,Var,Susp,AttachBody),
	Body =
	(
		AttachBody,
		RecursiveCall
	).

generate_attach_body_n(F/A,Var,Susp,Body) :-
	get_constraint_index(F/A,Position),
	or_pattern(Position,Pattern),
	get_max_constraint_index(Total),
	make_attr(Total,Mask,SuspsList,Attr),
	nth(Position,SuspsList,Susps),
	substitute(Susps,SuspsList,[Susp|Susps],SuspsList1),
	make_attr(Total,Mask,SuspsList1,NewAttr1),
	substitute(Susps,SuspsList,[Susp],SuspsList2),
	make_attr(Total,NewMask,SuspsList2,NewAttr2),
	copy_term_nat(SuspsList,SuspsList3),
	nth(Position,SuspsList3,[Susp]),
	delete(SuspsList3,[Susp],RestSuspsList),
	set_elems(RestSuspsList,[]),
	make_attr(Total,Pattern,SuspsList3,NewAttr3),
	get_target_module(Mod),
	Body =
	( get_attr(Var,Mod,TAttr) ->
		TAttr = Attr,
		( Mask /\ Pattern =:= Pattern ->
			put_attr(Var, Mod, NewAttr1)
		;
			NewMask is Mask \/ Pattern,
			put_attr(Var, Mod, NewAttr2)
		)
	;
		put_attr(Var,Mod,NewAttr3)
	).

%%	detach_$CONSTRAINT
generate_detach_a_constraint(Constraint,[Clause1,Clause2]) :-
	generate_detach_a_constraint_empty_list(Constraint,Clause1),
	get_max_constraint_index(N),
	( N == 1 ->
		generate_detach_a_constraint_1_1(Constraint,Clause2)
	;
		generate_detach_a_constraint_t_p(Constraint,Clause2)
	).

generate_detach_a_constraint_empty_list(FA,Clause) :-
	make_name('detach_',FA,Fct),
	Args = [[],_],
	Head =.. [Fct | Args],
	Clause = ( Head :- true).

generate_detach_a_constraint_1_1(FA,Clause) :-
	make_name('detach_',FA,Fct),
	Args = [[Var|Vars],Susp],
	Head =.. [Fct | Args],
	RecursiveCall =.. [Fct,Vars,Susp],
	generate_detach_body_1(FA,Var,Susp,DetachBody),
	Body =
	(
		DetachBody,
		RecursiveCall
	),
	Clause = (Head :- Body).

generate_detach_body_1(FA,Var,Susp,Body) :-
	get_target_module(Mod),
	Body =
	( get_attr(Var,Mod,Susps) ->
		'chr sbag_del_element'(Susps,Susp,NewSusps),
		( NewSusps == [] ->
			del_attr(Var,Mod)
		;
			put_attr(Var,Mod,NewSusps)
		)
	;
		true
	).

generate_detach_a_constraint_t_p(FA,Clause) :-
	make_name('detach_',FA,Fct),
	Args = [[Var|Vars],Susp],
	Head =.. [Fct | Args],
	RecursiveCall =.. [Fct,Vars,Susp],
	generate_detach_body_n(FA,Var,Susp,DetachBody),
	Body =
	(
		DetachBody,
		RecursiveCall
	),
	Clause = (Head :- Body).

generate_detach_body_n(F/A,Var,Susp,Body) :-
	get_constraint_index(F/A,Position),
	or_pattern(Position,Pattern),
	and_pattern(Position,DelPattern),
	get_max_constraint_index(Total),
	make_attr(Total,Mask,SuspsList,Attr),
	nth(Position,SuspsList,Susps),
	substitute(Susps,SuspsList,[],SuspsList1),
	make_attr(Total,NewMask,SuspsList1,Attr1),
	substitute(Susps,SuspsList,NewSusps,SuspsList2),
	make_attr(Total,Mask,SuspsList2,Attr2),
	get_target_module(Mod),
	Body =
	( get_attr(Var,Mod,TAttr) ->
		TAttr = Attr,
		( Mask /\ Pattern =:= Pattern ->
			'chr sbag_del_element'(Susps,Susp,NewSusps),
			( NewSusps == [] ->
				NewMask is Mask /\ DelPattern,
				( NewMask == 0 ->
					del_attr(Var,Mod)
				;
					put_attr(Var,Mod,Attr1)
				)
			;
				put_attr(Var,Mod,Attr2)
			)
		;
			true
		)
	;
		true
	).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
generate_indexed_variables_clauses(Constraints,Clauses) :-
	( forsome(C,Constraints,may_trigger(C)) ->
		generate_indexed_variables_clauses_(Constraints,Clauses)
	;
		Clauses = []
	).

generate_indexed_variables_clauses_([],[]).
generate_indexed_variables_clauses_([C|Cs],Clauses) :-
	( ( is_attached(C) ; chr_pp_flag(debugable,on)) ->
		Clauses = [Clause|RestClauses],
		generate_indexed_variables_clause(C,Clause)
	;
		Clauses = RestClauses
	),
	generate_indexed_variables_clauses_(Cs,RestClauses).

generate_indexed_variables_clause(F/A,Clause) :-
	functor(Term,F,A),
	get_constraint_mode(F/A,ArgModes),
	Term =.. [_|Args],
	create_indexed_variables_body(Args,ArgModes,Vars,1,F/A,MaybeBody,N),
	( MaybeBody == empty ->
	
		Body = (Vars = [])
	; N == 0 ->
		Body = term_variables(Susp,Vars)
	; 
		MaybeBody = Body
	),
	Clause = 
		( '$indexed_variables'(Susp,Vars) :-
			Susp = Term,
			Body
		).	

create_indexed_variables_body([],[],_,_,_,empty,0).
create_indexed_variables_body([V|Vs],[Mode|Modes],Vars,I,FA,Body,N) :-
	J is I + 1,
	create_indexed_variables_body(Vs,Modes,Tail,J,FA,RBody,M),
	( Mode \== (+),
          is_indexed_argument(FA,I) ->
		( RBody == empty ->
			Body = term_variables(V,Vars)
		;
			Body = (term_variables(V,Vars,Tail),RBody)
		),
		N = M
	;
		Vars = Tail,
		Body = RBody,
		N is M + 1
	).

generate_extra_clauses(Constraints,[A,B,MetaPredDec,C,D,MetaPredDec2,E]) :-
	( chr_pp_flag(reduced_indexing,on) ->
		global_indexed_variables_clause(Constraints,D)
	;
		D =
		( chr_indexed_variables(Susp,Vars) :-
			'chr chr_indexed_variables'(Susp,Vars)
		)
	),
	generate_remove_clause(A),
	generate_activate_clause(B),
	generate_allocate_clause(C,MetaPredDec),
	generate_insert_constraint_internal(E,MetaPredDec2).

generate_remove_clause(RemoveClause) :-
	RemoveClause = 
	(
		remove_constraint_internal(Susp, Agenda, Delete) :-
			arg( 2, Susp, Mref),
			'chr get_mutable'( State, Mref),
			'chr update_mutable'( removed, Mref),		% mark in any case
			( compound(State) ->			% passive/1
			    Agenda = [],
			    Delete = no
			; State==removed ->
			    Agenda = [],
			    Delete = no
			%; State==triggered ->
			%     Agenda = []
			;
			    Delete = yes,
			    chr_indexed_variables(Susp,Agenda)
			)
	).

generate_activate_clause(ActivateClause) :-
	ActivateClause =	
	(
		activate_constraint(Store, Vars, Susp, Generation) :-
			arg( 2, Susp, Mref),
			'chr get_mutable'( State, Mref), 
			'chr update_mutable'( active, Mref),
			( nonvar(Generation) ->			% aih
			    true
			;
			    arg( 4, Susp, Gref),
			    'chr get_mutable'( Gen, Gref),
			    Generation is Gen+1,
			    'chr update_mutable'( Generation, Gref)
			),
			( compound(State) ->			% passive/1
			    term_variables( State, Vars),
			    'chr none_locked'( Vars),
			    Store = yes
			; State == removed ->			% the price for eager removal ...
			    chr_indexed_variables(Susp,Vars),
			    Store = yes
			;
			    Vars = [],
			    Store = no
			)
	).

generate_allocate_clause(AllocateClause, (:- meta_predicate allocate_constraint( goal, ?, ?, ?))) :-
	AllocateClause =
	(
		allocate_constraint( Closure, Self, F, Args) :-
			Self =.. [suspension,Id,Mref,Closure,Gref,Href,F|Args],
			'chr create_mutable'(0,Gref), % Gref = mutable(0),	
			'chr empty_history'(History),
			'chr create_mutable'(History,Href), % Href = mutable(History),
			chr_indexed_variables(Self,Vars),
			'chr create_mutable'(passive(Vars),Mref), % Mref = mutable(passive(Vars)),
			'chr gen_id'( Id)
	).

generate_insert_constraint_internal(Clause,(:- meta_predicate insert_constraint_internal(?, ?, ?, goal, ?, ?))) :-
	Clause =
	(
		insert_constraint_internal(yes, Vars, Self, Closure, F, Args) :-
			Self =.. [suspension,Id,Mref,Closure,Gref,Href,F|Args],
			chr_indexed_variables(Self,Vars),
			'chr none_locked'(Vars),
			'chr create_mutable'(active,Mref), % Mref = mutable(active),
			'chr create_mutable'(0,Gref), % Gref = mutable(0),
			'chr empty_history'(History),
			'chr create_mutable'(History,Href), % Href = mutable(History),
			'chr gen_id'(Id)
	).

global_indexed_variables_clause(Constraints,Clause) :-
	( forsome(C,Constraints,may_trigger(C)) ->
		Body = (Susp =.. [_,_,_,_,_,_,Term|_], '$indexed_variables'(Term,Vars))
	;
		Body = true,
		Vars = []
	),	
	Clause = ( chr_indexed_variables(Susp,Vars) :- Body ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
generate_attach_increment(Clauses) :-
	get_max_constraint_index(N),
	( N > 0 ->
		Clauses = [Clause1,Clause2],
		generate_attach_increment_empty(Clause1),
		( N == 1 ->
			generate_attach_increment_one(Clause2)
		;
			generate_attach_increment_many(N,Clause2)
		)
	;
		Clauses = []
	).

generate_attach_increment_empty((attach_increment([],_) :- true)).

generate_attach_increment_one(Clause) :-
	Head = attach_increment([Var|Vars],Susps),
	get_target_module(Mod),
	Body =
	(
		'chr not_locked'(Var),
		( get_attr(Var,Mod,VarSusps) ->
			sort(VarSusps,SortedVarSusps),
			merge(Susps,SortedVarSusps,MergedSusps),
			put_attr(Var,Mod,MergedSusps)
		;
			put_attr(Var,Mod,Susps)
		),
		attach_increment(Vars,Susps)
	), 
	Clause = (Head :- Body).

generate_attach_increment_many(N,Clause) :-
	make_attr(N,Mask,SuspsList,Attr),
	make_attr(N,OtherMask,OtherSuspsList,OtherAttr),
	Head = attach_increment([Var|Vars],Attr),
	bagof(G,X ^ Y ^ SY ^ M ^ (member2(SuspsList,OtherSuspsList,X-Y),G = (sort(Y,SY),'chr merge_attributes'(X,SY,M))),Gs),
	list2conj(Gs,SortGoals),
	bagof(MS,A ^ B ^ C ^ member((A,'chr merge_attributes'(B,C,MS)),Gs), MergedSuspsList),
	make_attr(N,MergedMask,MergedSuspsList,NewAttr),
	get_target_module(Mod),
	Body =	
	(
		'chr not_locked'(Var),
		( get_attr(Var,Mod,TOtherAttr) ->
			TOtherAttr = OtherAttr,
			SortGoals,
			MergedMask is Mask \/ OtherMask,
			put_attr(Var,Mod,NewAttr)
		;
			put_attr(Var,Mod,Attr)
		),
		attach_increment(Vars,Attr)
	),
	Clause = (Head :- Body).

%%	attr_unify_hook
generate_attr_unify_hook([Clause]) :-
	get_max_constraint_index(N),
	( N == 0 ->
		get_target_module(Mod),
		Clause =
		( attr_unify_hook(Attr,Var) :-
			write('ERROR: Unexpected triggering of attr_unify_hook/2 in module '),
			writeln(Mod)
		)	
	; N == 1 ->
		generate_attr_unify_hook_one(Clause)
	;
		generate_attr_unify_hook_many(N,Clause)
	).

generate_attr_unify_hook_one(Clause) :-
	Head = attr_unify_hook(Susps,Other),
	get_target_module(Mod),
	make_run_suspensions(NewSusps,WakeNewSusps),
	make_run_suspensions(Susps,WakeSusps),
	Body = 
	(
		sort(Susps, SortedSusps),
		( var(Other) ->
			( get_attr(Other,Mod,OtherSusps) ->
				true
			;
		        	OtherSusps = []
			),
			sort(OtherSusps,SortedOtherSusps),
			'chr merge_attributes'(SortedSusps,SortedOtherSusps,NewSusps),
			put_attr(Other,Mod,NewSusps),
			WakeNewSusps
		;
			( compound(Other) ->
				term_variables(Other,OtherVars),
				attach_increment(OtherVars, SortedSusps)
			;
				true
			),
			WakeSusps
		)
	),
	Clause = (Head :- Body).

generate_attr_unify_hook_many(N,Clause) :-
	make_attr(N,Mask,SuspsList,Attr),
	make_attr(N,OtherMask,OtherSuspsList,OtherAttr),
	bagof(Sort,A ^ B ^ ( member(A,SuspsList) , Sort = sort(A,B) ) , SortGoalList),
	list2conj(SortGoalList,SortGoals),
	bagof(B, A ^ member(sort(A,B),SortGoalList), SortedSuspsList),
	bagof(C, D ^ E ^ F ^ G ^ (member2(SortedSuspsList,OtherSuspsList,D-E),
                                  C = (sort(E,F),
                                       'chr merge_attributes'(D,F,G)) ), 
              SortMergeGoalList),
	bagof(G, D ^ F ^ H ^ member((H,'chr merge_attributes'(D,F,G)),SortMergeGoalList) , MergedSuspsList),
	list2conj(SortMergeGoalList,SortMergeGoals),
	make_attr(N,MergedMask,MergedSuspsList,MergedAttr),
	make_attr(N,Mask,SortedSuspsList,SortedAttr),
	Head = attr_unify_hook(Attr,Other),
	get_target_module(Mod),
	make_run_suspensions_loop(MergedSuspsList,WakeMergedSusps),
	make_run_suspensions_loop(SortedSuspsList,WakeSortedSusps),
	Body =
	(
		SortGoals,
		( var(Other) ->
			( get_attr(Other,Mod,TOtherAttr) ->
				TOtherAttr = OtherAttr,
				SortMergeGoals,
				MergedMask is Mask \/ OtherMask,
				put_attr(Other,Mod,MergedAttr),
				WakeMergedSusps
			;
				put_attr(Other,Mod,SortedAttr),
				WakeSortedSusps
			)
		;
			( compound(Other) ->
				term_variables(Other,OtherVars),
				attach_increment(OtherVars,SortedAttr)
			;
				true
			),
			WakeSortedSusps
		)	
	),	
	Clause = (Head :- Body).

make_run_suspensions(Susps,Goal) :-
	( chr_pp_flag(debugable,on) ->
		Goal = 'chr run_suspensions_d'(Susps)
	;
		Goal = 'chr run_suspensions'(Susps)
	).

make_run_suspensions_loop(SuspsList,Goal) :-
	( chr_pp_flag(debugable,on) ->
		Goal = 'chr run_suspensions_loop_d'(SuspsList)
	;
		Goal = 'chr run_suspensions_loop'(SuspsList)
	).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% $insert_in_store_F/A
% $delete_from_store_F/A

generate_insert_delete_constraints([],[]). 
generate_insert_delete_constraints([FA|Rest],Clauses) :-
	( is_attached(FA) ->
		Clauses = [IClause,DClause|RestClauses],
		generate_insert_delete_constraint(FA,IClause,DClause)
	;
		Clauses = RestClauses
	),
	generate_insert_delete_constraints(Rest,RestClauses).
			
generate_insert_delete_constraint(FA,IClause,DClause) :-
	get_store_type(FA,StoreType),
	generate_insert_constraint(StoreType,FA,IClause),
	generate_delete_constraint(StoreType,FA,DClause).

generate_insert_constraint(StoreType,C,Clause) :-
	make_name('$insert_in_store_',C,ClauseName),
	Head =.. [ClauseName,Susp],
	generate_insert_constraint_body(StoreType,C,Susp,Body),
	Clause = (Head :- Body).	

generate_insert_constraint_body(default,C,Susp,Body) :-
	get_target_module(Mod),
	get_max_constraint_index(Total),
	( Total == 1 ->
		generate_attach_body_1(C,Store,Susp,AttachBody)
	;
		generate_attach_body_n(C,Store,Susp,AttachBody)
	),
	Body =
	(
		'chr default_store'(Store),
		AttachBody
	).
generate_insert_constraint_body(multi_hash(Indexes),C,Susp,Body) :-
	generate_multi_hash_insert_constraint_bodies(Indexes,C,Susp,Body).
generate_insert_constraint_body(global_ground,C,Susp,Body) :-
	global_ground_store_name(C,StoreName),
	make_get_store_goal(StoreName,Store,GetStoreGoal),
	make_update_store_goal(StoreName,[Susp|Store],UpdateStoreGoal),
	Body =
	(
		GetStoreGoal,     % nb_getval(StoreName,Store),
		UpdateStoreGoal   % b_setval(StoreName,[Susp|Store])
	).
generate_insert_constraint_body(multi_store(StoreTypes),C,Susp,Body) :-
	find_with_var_identity(
		B,
		[Susp],
		( 
			member(ST,StoreTypes),
			generate_insert_constraint_body(ST,C,Susp,B)
		),
		Bodies
		),
	list2conj(Bodies,Body).

generate_multi_hash_insert_constraint_bodies([],_,_,true).
generate_multi_hash_insert_constraint_bodies([Index|Indexes],FA,Susp,(Body,Bodies)) :-
	multi_hash_store_name(FA,Index,StoreName),
	multi_hash_key(FA,Index,Susp,KeyBody,Key),
	make_get_store_goal(StoreName,Store,GetStoreGoal),
	Body =
	(
		KeyBody,
	        GetStoreGoal, % nb_getval(StoreName,Store),
		insert_ht(Store,Key,Susp)
	),
	generate_multi_hash_insert_constraint_bodies(Indexes,FA,Susp,Bodies).

generate_delete_constraint(StoreType,FA,Clause) :-
	make_name('$delete_from_store_',FA,ClauseName),
	Head =.. [ClauseName,Susp],
	generate_delete_constraint_body(StoreType,FA,Susp,Body),
	Clause = (Head :- Body).

generate_delete_constraint_body(default,C,Susp,Body) :-
	get_target_module(Mod),
	get_max_constraint_index(Total),
	( Total == 1 ->
		generate_detach_body_1(C,Store,Susp,DetachBody),
		Body =
		(
			'chr default_store'(Store),
			DetachBody
		)
	;
		generate_detach_body_n(C,Store,Susp,DetachBody),
		Body =
		(
			'chr default_store'(Store),
			DetachBody
		)
	).
generate_delete_constraint_body(multi_hash(Indexes),C,Susp,Body) :-
	generate_multi_hash_delete_constraint_bodies(Indexes,C,Susp,Body).
generate_delete_constraint_body(global_ground,C,Susp,Body) :-
	global_ground_store_name(C,StoreName),
	make_get_store_goal(StoreName,Store,GetStoreGoal),
	make_update_store_goal(StoreName,NStore,UpdateStoreGoal),
	Body =
	(
		GetStoreGoal, % nb_getval(StoreName,Store),
		'chr sbag_del_element'(Store,Susp,NStore),
		UpdateStoreGoal % b_setval(StoreName,NStore)
	).
generate_delete_constraint_body(multi_store(StoreTypes),C,Susp,Body) :-
	find_with_var_identity(
		B,
		[Susp],
		(
			member(ST,StoreTypes),
			generate_delete_constraint_body(ST,C,Susp,B)
		),
		Bodies
	),
	list2conj(Bodies,Body).

generate_multi_hash_delete_constraint_bodies([],_,_,true).
generate_multi_hash_delete_constraint_bodies([Index|Indexes],FA,Susp,(Body,Bodies)) :-
	multi_hash_store_name(FA,Index,StoreName),
	multi_hash_key(FA,Index,Susp,KeyBody,Key),
	make_get_store_goal(StoreName,Store,GetStoreGoal),
	Body =
	(
		KeyBody,
		GetStoreGoal, % nb_getval(StoreName,Store),
		delete_ht(Store,Key,Susp)
	),
	generate_multi_hash_delete_constraint_bodies(Indexes,FA,Susp,Bodies).

generate_delete_constraint_call(FA,Susp,Call) :-
	make_name('$delete_from_store_',FA,Functor),
	Call =.. [Functor,Susp]. 

generate_insert_constraint_call(FA,Susp,Call) :-
	make_name('$insert_in_store_',FA,Functor),
	Call =.. [Functor,Susp]. 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

generate_store_code(Constraints,[Enumerate|L]) :-
	enumerate_stores_code(Constraints,Enumerate),
	generate_store_code(Constraints,L,[]).

generate_store_code([],L,L).
generate_store_code([C|Cs],L,T) :-
	get_store_type(C,StoreType),
	generate_store_code(StoreType,C,L,L1),
	generate_store_code(Cs,L1,T). 

generate_store_code(default,_,L,L).
generate_store_code(multi_hash(Indexes),C,L,T) :-
	multi_hash_store_initialisations(Indexes,C,L,L1),
	multi_hash_via_lookups(Indexes,C,L1,T).
generate_store_code(global_ground,C,L,T) :-
	global_ground_store_initialisation(C,L,T).
generate_store_code(multi_store(StoreTypes),C,L,T) :-
	multi_store_generate_store_code(StoreTypes,C,L,T).

multi_store_generate_store_code([],_,L,L).
multi_store_generate_store_code([ST|STs],C,L,T) :-
	generate_store_code(ST,C,L,L1),
	multi_store_generate_store_code(STs,C,L1,T).	

%% Ciao begin
:- multifile initial_gv_value/2.
%% Ciao end

multi_hash_store_initialisations([],_,L,L).
multi_hash_store_initialisations([Index|Indexes],FA,L,T) :-
	multi_hash_store_name(FA,Index,StoreName),
%	make_init_store_goal(StoreName,HT,InitStoreGoal),
%	L = [(:- (new_ht(HT),InitStoreGoal)) | L1],
	L = [(initial_gv_value(StoreName,HT) :- new_ht(HT)) | L1],
	multi_hash_store_initialisations(Indexes,FA,L1,T).

global_ground_store_initialisation(C,L,T) :-
	global_ground_store_name(C,StoreName),
%	make_init_store_goal(StoreName,[],InitStoreGoal),
%	L = [(:- InitStoreGoal)|T].
	L = [(initial_gv_value(StoreName,[]))|T].

multi_hash_via_lookups([],_,L,L).
multi_hash_via_lookups([Index|Indexes],C,L,T) :-
	multi_hash_via_lookup_name(C,Index,PredName),
	Head =.. [PredName,Key,SuspsList],
	multi_hash_store_name(C,Index,StoreName),
	make_get_store_goal(StoreName,HT,GetStoreGoal),
	Body = 
	(
		GetStoreGoal, % nb_getval(StoreName,HT),
		lookup_ht(HT,Key,SuspsList)
	),
	L = [(Head :- Body)|L1],
	multi_hash_via_lookups(Indexes,C,L1,T).

multi_hash_via_lookup_name(F/A,Index,Name) :-
	( integer(Index) ->
		IndexName = Index
	; is_list(Index) ->
		atom_concat_list(Index,IndexName)
	),
	atom_concat_list(['$via1_multi_hash_',F,(/),A,'-',IndexName],Name).

multi_hash_store_name(F/A,Index,Name) :-
	get_target_module(Mod),		
	( integer(Index) ->
		IndexName = Index
	; is_list(Index) ->
		atom_concat_list(Index,IndexName)
	),
	atom_concat_list(['$chr_store_multi_hash_',Mod,(:),F,(/),A,'-',IndexName],Name).

multi_hash_key(F/A,Index,Susp,KeyBody,Key) :-
	( ( integer(Index) ->
		I = Index
	  ; 
		Index = [I]
	  ) ->
		SuspIndex is I + 6,
		KeyBody = arg(SuspIndex,Susp,Key)
	; is_list(Index) ->
		sort(Index,Indexes),
		find_with_var_identity(arg(J,Susp,KeyI)-KeyI,[Susp],(member(I,Indexes),J is I + 6),ArgKeyPairs),
		pairup(Bodies,Keys,ArgKeyPairs),
		Key =.. [k|Keys],
		list2conj(Bodies,KeyBody)
	).

multi_hash_key_args(Index,Head,KeyArgs) :-
	( integer(Index) ->
		arg(Index,Head,Arg),
		KeyArgs = [Arg]
	; is_list(Index) ->
		sort(Index,Indexes),
		term_variables(Head,Vars),
		find_with_var_identity(Arg,Vars,(member(I,Indexes), arg(I,Head,Arg)),KeyArgs)
	).
		
global_ground_store_name(F/A,Name) :-
	get_target_module(Mod),		
	atom_concat_list(['$chr_store_global_ground_',Mod,(:),F,(/),A],Name).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
enumerate_stores_code(Constraints,Clause) :-
	Head = '$enumerate_suspensions'(Susp),
	enumerate_store_bodies(Constraints,Susp,Bodies),
	list2disj(Bodies,Body),
	Clause = (Head :- Body).	

enumerate_store_bodies([],_,[]).
enumerate_store_bodies([C|Cs],Susp,L) :-
	( is_attached(C) ->
		get_store_type(C,StoreType),
		enumerate_store_body(StoreType,C,Susp,B),
		L = [B|T]
	;
		L = T
	),
	enumerate_store_bodies(Cs,Susp,T).

enumerate_store_body(default,C,Susp,Body) :-
	get_constraint_index(C,Index),
	get_target_module(Mod),
	get_max_constraint_index(MaxIndex),
	Body1 = 
	(
		'chr default_store'(GlobalStore),
		get_attr(GlobalStore,Mod,Attr)
	),
	( MaxIndex > 1 ->
		NIndex is Index + 1,
		Body2 =	
		(
			arg(NIndex,Attr,List),
			'chr sbag_member'(Susp,List)	
		)
	;
		Body2 = 'chr sbag_member'(Susp,Attr)
	),
	Body = (Body1,Body2).
enumerate_store_body(multi_hash([Index|_]),C,Susp,Body) :-
	multi_hash_enumerate_store_body(Index,C,Susp,Body).
enumerate_store_body(global_ground,C,Susp,Body) :-
	global_ground_store_name(C,StoreName),
	make_get_store_goal(StoreName,List,GetStoreGoal),
	Body =
	(
		GetStoreGoal, % nb_getval(StoreName,List),
		'chr sbag_member'(Susp,List)
	).
enumerate_store_body(multi_store(STs),C,Susp,Body) :-
	once((
		member(ST,STs),
		enumerate_store_body(ST,C,Susp,Body)
	)).

multi_hash_enumerate_store_body(I,C,Susp,B) :-
	multi_hash_store_name(C,I,StoreName),
	make_get_store_goal(StoreName,HT,GetStoreGoal),
	B =
	(
		GetStoreGoal, % nb_getval(StoreName,HT),
		value_ht(HT,Susp)	
	).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
check_attachments(Constraints) :-
	( chr_pp_flag(check_attachments,on) ->
		check_constraint_attachments(Constraints)
	;
		true
	).

check_constraint_attachments([]).
check_constraint_attachments([C|Cs]) :-
	check_constraint_attachment(C),
	check_constraint_attachments(Cs).

check_constraint_attachment(C) :-
	get_max_occurrence(C,MO),
	check_occurrences_attachment(C,1,MO).

check_occurrences_attachment(C,O,MO) :-
	( O > MO ->
		true
	;
		check_occurrence_attachment(C,O),
		NO is O + 1,
		check_occurrences_attachment(C,NO,MO)
	).

check_occurrence_attachment(C,O) :-
	get_occurrence(C,O,RuleNb,ID),
	get_rule(RuleNb,PragmaRule),
	PragmaRule = pragma(rule(Heads1,Heads2,Guard,Body),ids(IDs1,IDs2),_,_,_),	
	( select2(ID,Head1,IDs1,Heads1,RIDs1,RHeads1) ->
		check_attachment_head1(Head1,ID,RuleNb,Heads1,Heads2,Guard)
	; select2(ID,Head2,IDs2,Heads2,RIDs2,RHeads2) ->
		check_attachment_head2(Head2,ID,RuleNb,Heads1,Body)
	).

check_attachment_head1(C,ID,RuleNb,H1,H2,G) :-
	functor(C,F,A),
	( H1 == [C],
	  H2 == [],
	  G == true, 
	  C =.. [_|L],
	  no_matching(L,[]),
	  \+ is_passive(RuleNb,ID) ->
		attached(F/A,no)
	;
		attached(F/A,maybe)
	).

no_matching([],_).
no_matching([X|Xs],Prev) :-
	var(X),
	\+ memberchk_eq(X,Prev),
	no_matching(Xs,[X|Prev]).

check_attachment_head2(C,ID,RuleNb,H1,B) :-
	functor(C,F,A),
	( is_passive(RuleNb,ID) ->
		attached(F/A,maybe)
	; H1 \== [],
	  B == true ->
		attached(F/A,maybe)
	;
		attached(F/A,yes)
	).

all_attached([]).
all_attached([C|Cs]) :-
	functor(C,F,A),
	is_attached(F/A),
	all_attached(Cs).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

set_constraint_indices([],M) :-
	N is M - 1,
	max_constraint_index(N).
set_constraint_indices([C|Cs],N) :-
	( ( may_trigger(C) ;  is_attached(C), get_store_type(C,default)) ->
		constraint_index(C,N),
		M is N + 1,
		set_constraint_indices(Cs,M)
	;
		set_constraint_indices(Cs,N)
	).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  ____        _         ____                      _ _       _   _
%% |  _ \ _   _| | ___   / ___|___  _ __ ___  _ __ (_) | __ _| |_(_) ___  _ __
%% | |_) | | | | |/ _ \ | |   / _ \| '_ ` _ \| '_ \| | |/ _` | __| |/ _ \| '_ \
%% |  _ <| |_| | |  __/ | |__| (_) | | | | | | |_) | | | (_| | |_| | (_) | | | |
%% |_| \_\\__,_|_|\___|  \____\___/|_| |_| |_| .__/|_|_|\__,_|\__|_|\___/|_| |_|
%%                                           |_|

constraints_code(Constraints,Rules,Clauses) :-
	post_constraints(Constraints,1),
	constraints_code1(1,Rules,L,[]),
	clean_clauses(L,Clauses).

%%	Add global data
post_constraints([],MaxIndex1) :-
	MaxIndex is MaxIndex1 - 1,
	constraint_count(MaxIndex).
post_constraints([F/A|Cs],N) :-
	constraint(F/A,N),
	M is N + 1,
	post_constraints(Cs,M).
constraints_code1(I,Rules,L,T) :-
	get_constraint_count(N),
	( I > N ->
		T = L
	;
		constraint_code(I,Rules,L,T1),
		J is I + 1,
		constraints_code1(J,Rules,T1,T)
	).

%% 	Generate code for a single CHR constraint
constraint_code(I, Rules, L, T) :-
	get_constraint(Constraint,I),
	constraint_prelude(Constraint,Clause),
	L = [Clause | L1],
	Id1 = [0],
	rules_code(Rules,I,Id1,Id2,L1,L2),
	gen_cond_attach_clause(Constraint,Id2,L2,T).

%%	Generate prelude predicate for a constraint.
%%	f(...) :- f/a_0(...,Susp).
constraint_prelude(F/A, Clause) :-
	vars_susp(A,Vars,Susp,VarsSusp),
	Head =.. [ F | Vars],
	build_head(F,A,[0],VarsSusp,Delegate),
	get_target_module(Mod),
	FTerm =.. [F|Vars],
	( chr_pp_flag(debugable,on) ->
		Clause = 
			( Head :-
				allocate_constraint(Delegate, Susp, FTerm, Vars),
			        (   
					'chr debug_event'(call(Susp)),
		   	                Delegate
				;
					'chr debug_event'(fail(Susp)), !,
            				fail
        			),
			        (   
					'chr debug_event'(exit(Susp))
			        ;   
					'chr debug_event'(redo(Susp)),
				        fail
			        )
			)
	;
		Clause = ( Head  :- Delegate )
	). 

gen_cond_attach_clause(F/A,Id,L,T) :-
	( is_attached(F/A) ->
		( Id == [0] ->
			( may_trigger(F/A) ->
				gen_cond_attach_goal(F/A,Body,AllArgs,Args,Susp)
			;
				gen_insert_constraint_internal_goal(F/A,Body,AllArgs,Args,Susp)
			)
		; 	vars_susp(A,Args,Susp,AllArgs),
			gen_uncond_attach_goal(F/A,Susp,Body,_)
		),
		( chr_pp_flag(debugable,on) ->
			Constraint =.. [F|Args],
			DebugEvent = 'chr debug_event'(insert(Constraint#Susp))
		;
			DebugEvent = true
		),
		build_head(F,A,Id,AllArgs,Head),
		Clause = ( Head :- DebugEvent,Body ),
		L = [Clause | T]
	;
		L = T
	).	

gen_cond_attach_goal(F/A,Goal,AllArgs,Args,Susp) :-
	vars_susp(A,Args,Susp,AllArgs),
	build_head(F,A,[0],AllArgs,Closure),
	( may_trigger(F/A) ->
		make_name('attach_',F/A,AttachF),
		Attach =.. [AttachF,Vars,Susp]
	;
		Attach = true
	),
	get_target_module(Mod),
	FTerm =.. [F|Args],
	generate_insert_constraint_call(F/A,Susp,InsertCall),
	Goal =
	(
		( var(Susp) ->
			insert_constraint_internal(Stored,Vars,Susp,Closure,FTerm,Args)
		; 
			activate_constraint(Stored,Vars,Susp,_)
		),
		( Stored == yes ->
			InsertCall,	
			Attach
		;
			true
		)
	).

gen_insert_constraint_internal_goal(F/A,Goal,AllArgs,Args,Susp) :-
	vars_susp(A,Args,Susp,AllArgs),
	build_head(F,A,[0],AllArgs,Closure),
	( may_trigger(F/A) ->
		make_name('attach_',F/A,AttachF),
		Attach =.. [AttachF,Vars,Susp]
	;
		Attach = true
	),
	get_target_module(Mod),
	FTerm =.. [F|Args],
	generate_insert_constraint_call(F/A,Susp,InsertCall),
	Goal =
	(
		insert_constraint_internal(_,Vars,Susp,Closure,FTerm,Args),
		InsertCall,
		Attach
	).

gen_uncond_attach_goal(FA,Susp,AttachGoal,Generation) :-
	( may_trigger(FA) ->
		make_name('attach_',FA,AttachF),
		Attach =.. [AttachF,Vars,Susp]
	;
		Attach = true
	),
	generate_insert_constraint_call(FA,Susp,InsertCall),
	AttachGoal =
	(
		activate_constraint(Stored,Vars, Susp, Generation),
		( Stored == yes ->
			InsertCall,
			Attach	
		;
			true
		)
	).

% occurrences_code(O,MO,C,Id,NId,L,T) :-
% 	( O > MO ->
% 		NId = Id,
% 		L = T
% 	;
% 		occurrence_code(O,C,Id,Id1,L,L1),
% 		NO is O + 1,
% 		occurrences_code(NO,MO,C,Id1,NId,L1,T)
% 	).

% occurrence_code(O,C,Id,NId,L,T) :-
% 	get_occurrence(C,O,RuleNb,ID),
% 	( is_passive(RuleNb,ID) ->
% 		NId = Id,
% 		L = T
% 	;
% 		get_rule(RuleNb,PragmaRule),
% 		PragmaRule = pragma(rule(Heads1,Heads2,_,_),ids(IDs1,IDs2),_,_,_),	
% 		( select2(IDs1,Heads1,ID,Head1,RIDs1,RHeads1) ->
% 			NId = Id,
% 			head1_code(Head1,RHeads1   ,RIDs1   ,PragmaRule,C   ,Id,L,T)
% 		; select2(IDs2,Heads2,ID,Head2,RIDs2,RHeads2) ->
% 			length(RHeads2,RestHeadNb),
% 			head2_code(Head2,RHeads2,RIDs2,PragmaRule,RestHeadNb,C,Id,L,L1),
% 			inc_id(Id,NId),
% 			gen_alloc_inc_clause(C,Id,L1,T)
% 		)
% 	).


%%	Generate all the code for a constraint based on all CHR rules
rules_code([],_,Id,Id,L,L).
rules_code([R |Rs],I,Id1,Id3,L,T) :-
	rule_code(R,I,Id1,Id2,L,T1),
	rules_code(Rs,I,Id2,Id3,T1,T).

%%	Generate code for a constraint based on a single CHR rule
rule_code(PragmaRule,I,Id1,Id2,L,T) :-
	PragmaRule = pragma(Rule,HeadIDs,_Pragmas,_Name,_RuleNb),
	HeadIDs = ids(Head1IDs,Head2IDs),
	Rule = rule(Head1,Head2,_,_),
	heads1_code(Head1,[],Head1IDs,[],PragmaRule,I,Id1,L,L1),
	heads2_code(Head2,[],Head2IDs,[],PragmaRule,I,Id1,Id2,L1,T).

%%	Generate code based on all the removed heads of a CHR rule
heads1_code([],_,_,_,_,_,_,L,L).
heads1_code([Head|Heads],RestHeads,[HeadID|HeadIDs],RestIDs,PragmaRule,I,Id,L,T) :-
	PragmaRule = pragma(Rule,_,_Pragmas,_Name,RuleNb),
	get_constraint(F/A,I),
	( functor(Head,F,A),
	  \+ is_passive(RuleNb,HeadID),
	  \+ check_unnecessary_active(Head,RestHeads,Rule),
	  all_attached(Heads),
	  all_attached(RestHeads),
	  Rule = rule(_,Heads2,_,_),
	  all_attached(Heads2) ->
		append(Heads,RestHeads,OtherHeads),
		append(HeadIDs,RestIDs,OtherIDs),
		head1_code(Head,OtherHeads,OtherIDs,PragmaRule,F/A,I,Id,L,L1)
	;	
		L = L1
	),
	heads1_code(Heads,[Head|RestHeads],HeadIDs,[HeadID|RestIDs],PragmaRule,I,Id,L1,T).

%%	Generate code based on one removed head of a CHR rule
head1_code(Head,OtherHeads,OtherIDs,PragmaRule,FA,I,Id,L,T) :-
	PragmaRule = pragma(Rule,_,_,_Name,RuleNb),
	Rule = rule(_,Head2,_,_),
	( Head2 == [] ->
		reorder_heads(RuleNb,Head,OtherHeads,OtherIDs,NOtherHeads,NOtherIDs),
		simplification_code(Head,NOtherHeads,NOtherIDs,PragmaRule,FA,Id,L,T)
	;
		simpagation_head1_code(Head,OtherHeads,OtherIDs,PragmaRule,FA,Id,L,T)
	).

%% Generate code based on all the persistent heads of a CHR rule
heads2_code([],_,_,_,_,_,Id,Id,L,L).
heads2_code([Head|Heads],RestHeads,[HeadID|HeadIDs],RestIDs,PragmaRule,I,Id1,Id3,L,T) :-
	PragmaRule = pragma(Rule,_,_Pragmas,_Name,RuleNb),
	get_constraint(F/A,I),
	( functor(Head,F,A),
	  \+ is_passive(RuleNb,HeadID),
	  \+ check_unnecessary_active(Head,RestHeads,Rule),
	  \+ set_semantics_rule(PragmaRule),
	  all_attached(Heads),
	  all_attached(RestHeads),
	  Rule = rule(Heads1,_,_,_),
	  all_attached(Heads1) ->
		append(Heads,RestHeads,OtherHeads),
		append(HeadIDs,RestIDs,OtherIDs),
		length(Heads,RestHeadNb),
		head2_code(Head,OtherHeads,OtherIDs,PragmaRule,RestHeadNb,F/A,Id1,L,L0),
		inc_id(Id1,Id2),
		gen_alloc_inc_clause(F/A,Id1,L0,L1)
	;
		L = L1,
		Id2 = Id1
	),
	heads2_code(Heads,[Head|RestHeads],HeadIDs,[HeadID|RestIDs],PragmaRule,I,Id2,Id3,L1,T).

%% Generate code based on one persistent head of a CHR rule
head2_code(Head,OtherHeads,OtherIDs,PragmaRule,RestHeadNb,FA,Id,L,T) :-
	PragmaRule = pragma(Rule,_,_,_Name,RuleNb),
	Rule = rule(Head1,_,_,_),
	( Head1 == [] ->
		reorder_heads(RuleNb,Head,OtherHeads,OtherIDs,NOtherHeads,_),
		propagation_code(Head,NOtherHeads,Rule,RuleNb,RestHeadNb,FA,Id,L,T)
	;
		simpagation_head2_code(Head,OtherHeads,OtherIDs,PragmaRule,FA,Id,L,T) 
	).

gen_alloc_inc_clause(F/A,Id,L,T) :-
	vars_susp(A,Vars,Susp,VarsSusp),
	build_head(F,A,Id,VarsSusp,Head),
	inc_id(Id,IncId),
	build_head(F,A,IncId,VarsSusp,CallHead),
	gen_allocation(Id,Vars,Susp,F/A,VarsSusp,ConditionalAlloc),
	Clause =
	(
		Head :-
			ConditionalAlloc,
			CallHead
	),
	L = [Clause|T].

gen_cond_allocation(Vars,Susp,FA,VarsSusp,ConstraintAllocationGoal) :-
	gen_allocation(Vars,Susp,FA,VarsSusp,UncondConstraintAllocationGoal),
	ConstraintAllocationGoal =
	( var(Susp) ->
	    UncondConstraintAllocationGoal
	;  
	    true
	).
gen_allocation(Vars,Susp,F/A,VarsSusp,ConstraintAllocationGoal) :-
	build_head(F,A,[0],VarsSusp,Term),
	get_target_module(Mod),
	FTerm =.. [F|Vars],
	ConstraintAllocationGoal = allocate_constraint(Term, Susp, FTerm, Vars).

gen_allocation(Id,Vars,Susp,FA,VarsSusp,ConstraintAllocationGoal) :-
	( Id == [0] ->
	    ( is_attached(FA) ->
		( may_trigger(FA) ->
			gen_cond_allocation(Vars,Susp,FA,VarsSusp,ConstraintAllocationGoal)
		;
			gen_allocation(Vars,Susp,FA,VarsSusp,ConstraintAllocationGoal)
		)
	    ;
		ConstraintAllocationGoal = true
	    )
	;
		ConstraintAllocationGoal = true
	).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

guard_via_reschedule(Retrievals,GuardList,Prelude,Goal) :-
	( chr_pp_flag(guard_via_reschedule,on) ->
		guard_via_reschedule_main(Retrievals,GuardList,Prelude,Goal)
	;
		append(Retrievals,GuardList,GoalList),
		list2conj(GoalList,Goal)
	).

guard_via_reschedule_main(Retrievals,GuardList,Prelude,Goal) :-
	initialize_unit_dictionary(Prelude,Dict),
	build_units(Retrievals,GuardList,Dict,Units),
	dependency_reorder(Units,NUnits),
	units2goal(NUnits,Goal).

units2goal([],true).
units2goal([unit(_,Goal,_,_)|Units],(Goal,Goals)) :-
	units2goal(Units,Goals).

dependency_reorder(Units,NUnits) :-
	dependency_reorder(Units,[],NUnits).

dependency_reorder([],Acc,Result) :-
	reverse(Acc,Result).

dependency_reorder([Unit|Units],Acc,Result) :-
	Unit = unit(_GID,_Goal,Type,GIDs),
	( Type == fixed ->
		NAcc = [Unit|Acc]
	;
		dependency_insert(Acc,Unit,GIDs,NAcc)
	),
	dependency_reorder(Units,NAcc,Result).

dependency_insert([],Unit,_,[Unit]).
dependency_insert([X|Xs],Unit,GIDs,L) :-
	X = unit(GID,_,_,_),
	( memberchk(GID,GIDs) ->
		L = [Unit,X|Xs]
	;
		L = [X | T],
		dependency_insert(Xs,Unit,GIDs,T)
	).

build_units(Retrievals,Guard,InitialDict,Units) :-
	build_retrieval_units(Retrievals,1,N,InitialDict,Dict,Units,Tail),
	build_guard_units(Guard,N,Dict,Tail).

build_retrieval_units([],N,N,Dict,Dict,L,L).
build_retrieval_units([U|Us],N,M,Dict,NDict,L,T) :-
	term_variables(U,Vs),
	update_unit_dictionary(Vs,N,Dict,Dict1,[],GIDs),
	L = [unit(N,U,movable,GIDs)|L1],
	N1 is N + 1,
	build_retrieval_units2(Us,N1,M,Dict1,NDict,L1,T).

build_retrieval_units2([],N,N,Dict,Dict,L,L).
build_retrieval_units2([U|Us],N,M,Dict,NDict,L,T) :-
	term_variables(U,Vs),
	update_unit_dictionary(Vs,N,Dict,Dict1,[],GIDs),
	L = [unit(N,U,fixed,GIDs)|L1],
	N1 is N + 1,
	build_retrieval_units(Us,N1,M,Dict1,NDict,L1,T).

initialize_unit_dictionary(Term,Dict) :-
	term_variables(Term,Vars),
	pair_all_with(Vars,0,Dict).	

update_unit_dictionary([],_,Dict,Dict,GIDs,GIDs).
update_unit_dictionary([V|Vs],This,Dict,NDict,GIDs,NGIDs) :-
	( lookup_eq(Dict,V,GID) ->
		( (GID == This ; memberchk(GID,GIDs) ) ->
			GIDs1 = GIDs
		;
			GIDs1 = [GID|GIDs]
		),
		Dict1 = Dict
	;
		Dict1 = [V - This|Dict],
		GIDs1 = GIDs
	),
	update_unit_dictionary(Vs,This,Dict1,NDict,GIDs1,NGIDs).

build_guard_units(Guard,N,Dict,Units) :-
	( Guard = [Goal] ->
		Units = [unit(N,Goal,fixed,[])]
	; Guard = [Goal|Goals] ->
		term_variables(Goal,Vs),
		update_unit_dictionary2(Vs,N,Dict,NDict,[],GIDs),
		Units = [unit(N,Goal,movable,GIDs)|RUnits],
		N1 is N + 1,
		build_guard_units(Goals,N1,NDict,RUnits)
	).

update_unit_dictionary2([],_,Dict,Dict,GIDs,GIDs).
update_unit_dictionary2([V|Vs],This,Dict,NDict,GIDs,NGIDs) :-
	( lookup_eq(Dict,V,GID) ->
		( (GID == This ; memberchk(GID,GIDs) ) ->
			GIDs1 = GIDs
		;
			GIDs1 = [GID|GIDs]
		),
		Dict1 = [V - This|Dict]
	;
		Dict1 = [V - This|Dict],
		GIDs1 = GIDs
	),
	update_unit_dictionary2(Vs,This,Dict1,NDict,GIDs1,NGIDs).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  ____       _     ____                             _   _            
%% / ___|  ___| |_  / ___|  ___ _ __ ___   __ _ _ __ | |_(_) ___ ___ _ 
%% \___ \ / _ \ __| \___ \ / _ \ '_ ` _ \ / _` | '_ \| __| |/ __/ __(_)
%%  ___) |  __/ |_   ___) |  __/ | | | | | (_| | | | | |_| | (__\__ \_ 
%% |____/ \___|\__| |____/ \___|_| |_| |_|\__,_|_| |_|\__|_|\___|___(_)
%%                                                                     
%%  _   _       _                    ___        __                              
%% | | | |_ __ (_) __ _ _   _  ___  |_ _|_ __  / _| ___ _ __ ___ _ __   ___ ___ 
%% | | | | '_ \| |/ _` | | | |/ _ \  | || '_ \| |_ / _ \ '__/ _ \ '_ \ / __/ _ \
%% | |_| | | | | | (_| | |_| |  __/  | || | | |  _|  __/ | |  __/ | | | (_|  __/
%%  \___/|_| |_|_|\__, |\__,_|\___| |___|_| |_|_|  \___|_|  \___|_| |_|\___\___|
%%                   |_|                                                        
unique_analyse_optimise(Rules,NRules) :-
%% Ciao begin -> Introduced the fail!!!
		( chr_pp_flag(unique_analyse_optimise,on) ->
			unique_analyse_optimise_main(Rules,1,[],NRules)
		;
			NRules = Rules
		).

unique_analyse_optimise_main([],_,_,[]).
unique_analyse_optimise_main([PRule|PRules],N,PatternList,[NPRule|NPRules]) :-
	( discover_unique_pattern(PRule,N,Pattern) ->
		NPatternList = [Pattern|PatternList]
	;
		NPatternList = PatternList
	),
	PRule = pragma(Rule,Ids,Pragmas,Name,RuleNb),
	Rule = rule(H1,H2,_,_),
	Ids = ids(Ids1,Ids2),
	apply_unique_patterns_to_constraints(H1,Ids1,NPatternList,MorePragmas1),
	apply_unique_patterns_to_constraints(H2,Ids2,NPatternList,MorePragmas2),
	globalize_unique_pragmas(MorePragmas1,RuleNb),
	globalize_unique_pragmas(MorePragmas2,RuleNb),
	append([MorePragmas1,MorePragmas2,Pragmas],NPragmas),
	NPRule = pragma(Rule,Ids,NPragmas,Name,RuleNb),
	N1 is N + 1,
	unique_analyse_optimise_main(PRules,N1,NPatternList,NPRules).

globalize_unique_pragmas([],_).
globalize_unique_pragmas([unique(ID,Vars)|R],RuleNb) :-
	pragma_unique(RuleNb,ID,Vars),
	globalize_unique_pragmas(R,RuleNb).

apply_unique_patterns_to_constraints([],_,_,[]).
apply_unique_patterns_to_constraints([C|Cs],[Id|Ids],Patterns,Pragmas) :-
	( member(Pattern,Patterns),
	  apply_unique_pattern(C,Id,Pattern,Pragma) ->
		Pragmas = [Pragma | RPragmas]
	;
		Pragmas = RPragmas
	),
	apply_unique_patterns_to_constraints(Cs,Ids,Patterns,RPragmas).

apply_unique_pattern(Constraint,Id,Pattern,Pragma) :-
	Pattern = unique(PatternConstraint,PatternKey),
	subsumes(Constraint,PatternConstraint,Unifier),
%	(
% 	    my_setof(	V,
% 			T^Term^Vs^(
% 				member(T,PatternKey),
% 				lookup_eq(Unifier,T,Term),
% 				term_variables(Term,Vs),
% 				member(V,Vs)
% 			),
% 			Vars) 

	 find_with_var_identity(V,Unifier,
	                       (
				   member(T,PatternKey),
				   lookup_eq(Unifier,T,Term),
				   term_variables(Term,Vs),
				   member(V,Vs)
			       ),
			       Vars0),
	  sort(Vars0,Vars),
% 	->
% 		true
% 	;
% 		Vars = []
% 	),
	Pragma = unique(Id,Vars).

%	subsumes(+Term1, +Term2, -Unifier)
%	
%	If Term1 is a more general term   than  Term2 (e.g. has a larger
%	part instantiated), unify  Unifier  with   a  list  Var-Value of
%	variables from Term2 and their corresponding values in Term1.


my_setof( Pat , Goal , Ans ) :-
	find_with_var_identity(Pat,Goal,Goal,Ans0),
	sort(Ans0,Ans).


subsumes(Term1,Term2,Unifier) :-
	empty_ds(S0),
	subsumes_aux(Term1,Term2,S0,S),
	ds_to_list(S,L),
	build_unifier(L,Unifier).

subsumes_aux(Term1, Term2, S0, S) :-
        (   compound(Term2),
            functor(Term2, F, N)
        ->  compound(Term1), functor(Term1, F, N),
            subsumes_aux(N, Term1, Term2, S0, S)
        ;   Term1 == Term2
	->  S = S0
	;   var(Term2),
	    get_ds(Term1,S0,V)
	->  V == Term2, S = S0
	;   var(Term2),
	    put_ds(Term1, S0, Term2, S)
        ).

subsumes_aux(0, _, _, S, S) :- ! .
subsumes_aux(N, T1, T2, S0, S) :-
        arg(N, T1, T1x),
        arg(N, T2, T2x),
        subsumes_aux(T1x, T2x, S0, S1),
        M is N-1,
        subsumes_aux(M, T1, T2, S1, S).

build_unifier([],[]).
build_unifier([X-V|R],[V - X | T]) :-
	build_unifier(R,T).
	
discover_unique_pattern(PragmaRule,RuleNb,Pattern) :-
	PragmaRule = pragma(Rule,_,_Pragmas,Name,RuleNb),
	Rule = rule(H1,H2,Guard,_),
	( H1 = [C1],
	  H2 = [C2] ->
		true
	; H1 = [C1,C2],
	  H2 == [] ->
		true
	),
	check_unique_constraints(C1,C2,Guard,RuleNb,List),
	term_variables(C1,Vs),
	select_pragma_unique_variables(List,Vs,Key),
	Pattern0 = unique(C1,Key),
	copy_term_nat(Pattern0,Pattern),
	( verbosity_on ->
		format('Found unique pattern ~w in rule ~d~@\n', 
			[Pattern,RuleNb,(Name=yes(N) -> write(": "),write(N) ; true)])
	;
		true
	).
	
select_pragma_unique_variables([],_,[]).
select_pragma_unique_variables([X-Y|R],Vs,L) :-
	( X == Y ->
		L = [X|T]
	;
		once((
			\+ memberchk_eq(X,Vs)
		;
			\+ memberchk_eq(Y,Vs)
		)),
		L = T
	),
	select_pragma_unique_variables(R,Vs,T).

check_unique_constraints(C1,C2,G,RuleNb,List) :-
	\+ any_passive_head(RuleNb),
	variable_replacement(C1-C2,C2-C1,List),
	copy_with_variable_replacement(G,OtherG,List),
	negate_b(G,NotG),
	once(entails_b(NotG,OtherG)).

check_unnecessary_active(Constraint,Previous,Rule) :-
	( chr_pp_flag(check_unnecessary_active,full) ->
		check_unnecessary_active_main(Constraint,Previous,Rule)
	; chr_pp_flag(check_unnecessary_active,simplification),
	  Rule = rule(_,[],_,_) ->
		check_unnecessary_active_main(Constraint,Previous,Rule)
	;
		fail
	).

check_unnecessary_active_main(Constraint,Previous,Rule) :-
   member(Other,Previous),
   variable_replacement(Other,Constraint,List),
   copy_with_variable_replacement(Rule,Rule2,List),
   identical_rules(Rule,Rule2), ! .

set_semantics_rule(PragmaRule) :-
	( chr_pp_flag(set_semantics_rule,on) ->
		set_semantics_rule_main(PragmaRule)
	;
		fail
	).

set_semantics_rule_main(PragmaRule) :-
	PragmaRule = pragma(Rule,IDs,Pragmas,_,RuleNb),
	Rule = rule([C1],[C2],true,_),
	IDs = ids([ID1],[ID2]),
	once(member(unique(ID1,L1),Pragmas)),
	once(member(unique(ID2,L2),Pragmas)),
	L1 == L2, 
	\+ is_passive(RuleNb,ID1).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  ____        _        _____            _            _                     
%% |  _ \ _   _| | ___  | ____|__ _ _   _(_)_   ____ _| | ___ _ __   ___ ___ 
%% | |_) | | | | |/ _ \ |  _| / _` | | | | \ \ / / _` | |/ _ \ '_ \ / __/ _ \
%% |  _ <| |_| | |  __/ | |__| (_| | |_| | |\ V / (_| | |  __/ | | | (_|  __/
%% |_| \_\\__,_|_|\___| |_____\__, |\__,_|_| \_/ \__,_|_|\___|_| |_|\___\___|
%%                               |_|                                         
% have to check for no duplicates in value list

% check wether two rules are identical

identical_rules(rule(H11,H21,G1,B1),rule(H12,H22,G2,B2)) :-
   G1 == G2,
   identical_bodies(B1,B2),
   permutation(H11,P1),
   P1 == H12,
   permutation(H21,P2),
   P2 == H22.

identical_bodies(B1,B2) :-
   ( B1 = (X1 = Y1),
     B2 = (X2 = Y2) ->
     ( X1 == X2,
       Y1 == Y2
     ; X1 == Y2,
       X2 == Y1
     ),
     !
   ; B1 == B2
   ).
 
% replace variables in list
   
copy_with_variable_replacement(X,Y,L) :-
   ( var(X) ->
     ( lookup_eq(L,X,Y) ->
       true
     ; X = Y
     )
   ; functor(X,F,A),
     functor(Y,F,A),
     X =.. [_|XArgs],
     Y =.. [_|YArgs],
     copy_with_variable_replacement_l(XArgs,YArgs,L)
   ).

copy_with_variable_replacement_l([],[],_).
copy_with_variable_replacement_l([X|Xs],[Y|Ys],L) :-
   copy_with_variable_replacement(X,Y,L),
   copy_with_variable_replacement_l(Xs,Ys,L).
   
%% build variable replacement list

variable_replacement(X,Y,L) :-
   variable_replacement(X,Y,[],L).
   
variable_replacement(X,Y,L1,L2) :-
   ( var(X) ->
     var(Y),
     ( lookup_eq(L1,X,Z) ->
       Z == Y,
       L2 = L1
     ; L2 = [X-Y|L1]
     )
   ; X =.. [F|XArgs],
     nonvar(Y),
     Y =.. [F|YArgs],
     variable_replacement_l(XArgs,YArgs,L1,L2)
   ).

variable_replacement_l([],[],L,L).
variable_replacement_l([X|Xs],[Y|Ys],L1,L3) :-
   variable_replacement(X,Y,L1,L2),
   variable_replacement_l(Xs,Ys,L2,L3).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  ____  _                 _ _  __ _           _   _
%% / ___|(_)_ __ ___  _ __ | (_)/ _(_) ___ __ _| |_(_) ___  _ __
%% \___ \| | '_ ` _ \| '_ \| | | |_| |/ __/ _` | __| |/ _ \| '_ \
%%  ___) | | | | | | | |_) | | |  _| | (_| (_| | |_| | (_) | | | |
%% |____/|_|_| |_| |_| .__/|_|_|_| |_|\___\__,_|\__|_|\___/|_| |_|
%%                   |_| 

simplification_code(Head,RestHeads,RestIDs,PragmaRule,F/A,Id,L,T) :-
	PragmaRule = pragma(Rule,_,Pragmas,_,_RuleNb),
	head_info(Head,A,_Vars,Susp,HeadVars,HeadPairs),
	build_head(F,A,Id,HeadVars,ClauseHead),
	head_arg_matches(HeadPairs,[],FirstMatching,VarDict1),
	
	(   RestHeads == [] ->
	    Susps = [],
	    VarDict = VarDict1,
	    GetRestHeads = []
	;   
	    rest_heads_retrieval_and_matching(RestHeads,RestIDs,Pragmas,Head,GetRestHeads,Susps,VarDict1,VarDict)
	),
	
	guard_body_copies2(Rule,VarDict,GuardCopyList,BodyCopy),
	guard_via_reschedule(GetRestHeads,GuardCopyList,ClauseHead-FirstMatching,RescheduledTest),
	
	gen_uncond_susps_detachments(Susps,RestHeads,SuspsDetachments),
	gen_cond_susp_detachment(Id,Susp,F/A,SuspDetachment),

	( chr_pp_flag(debugable,on) ->
		Rule = rule(_,_,Guard,Body),
		my_term_copy(Guard - Body, VarDict, _, DebugGuard - DebugBody),		
		DebugTry   = 'chr debug_event'(  try([Susp|RestSusps],[],DebugGuard,DebugBody)),
		DebugApply = 'chr debug_event'(apply([Susp|RestSusps],[],DebugGuard,DebugBody))
	;
		DebugTry = true,
		DebugApply = true
	),
	
	Clause = ( ClauseHead :-
	     	FirstMatching, 
		     RescheduledTest,
		     DebugTry,
	             !,
		     DebugApply,
	             SuspsDetachments,
	             SuspDetachment,
	             BodyCopy
	         ),
	L = [Clause | T].

head_arg_matches(Pairs,VarDict,Goal,NVarDict) :-
	head_arg_matches_(Pairs,VarDict,GoalList,NVarDict),
	list2conj(GoalList,Goal).
 
head_arg_matches_([],VarDict,[],VarDict).
head_arg_matches_([Arg-Var| Rest],VarDict,GoalList,NVarDict) :-
   (   var(Arg) ->
       (   lookup_eq(VarDict,Arg,OtherVar) ->
           GoalList = [Var == OtherVar | RestGoalList],
           VarDict1 = VarDict
       ;   VarDict1 = [Arg-Var | VarDict],
           GoalList = RestGoalList
       ),
       Pairs = Rest
   ;   atomic(Arg) ->
       GoalList = [ Var == Arg | RestGoalList],
       VarDict = VarDict1,
       Pairs = Rest
   ;   Arg =.. [_|Args],
       functor(Arg,Fct,N),
       functor(Term,Fct,N),
       Term =.. [_|Vars],
       GoalList =[ nonvar(Var), Var = Term | RestGoalList ], 
       pairup(Args,Vars,NewPairs),
       append(NewPairs,Rest,Pairs),
       VarDict1 = VarDict
   ),
   head_arg_matches_(Pairs,VarDict1,RestGoalList,NVarDict).

rest_heads_retrieval_and_matching(Heads,IDs,Pragmas,ActiveHead,GoalList,Susps,VarDict,NVarDict):-
	rest_heads_retrieval_and_matching(Heads,IDs,Pragmas,ActiveHead,GoalList,Susps,VarDict,NVarDict,[],[],[]).
	
rest_heads_retrieval_and_matching(Heads,IDs,Pragmas,ActiveHead,GoalList,Susps,VarDict,NVarDict,PrevHs,PrevSusps,AttrDict) :-
	( Heads = [_|_] ->
		rest_heads_retrieval_and_matching_n(Heads,IDs,Pragmas,PrevHs,PrevSusps,ActiveHead,GoalList,Susps,VarDict,NVarDict,AttrDict)	
	;
		GoalList = [],
		Susps = [],
		VarDict = NVarDict
	).

rest_heads_retrieval_and_matching_n([],_,_,_,_,_,[],[],VarDict,VarDict,AttrDict) :-
	instantiate_pattern_goals(AttrDict).
rest_heads_retrieval_and_matching_n([H|Hs],[ID|IDs],Pragmas,PrevHs,PrevSusps,ActiveHead,[ViaGoal,Goal|Goals],[Susp|Susps],VarDict,NVarDict,AttrDict) :-
	functor(H,F,A),
	get_store_type(F/A,StoreType),
	( StoreType == default ->
		passive_head_via(H,[ActiveHead|PrevHs],AttrDict,VarDict,ViaGoal,Attr,NewAttrDict),
		get_max_constraint_index(N),
		( N == 1 ->
			VarSusps = Attr
		;
			get_constraint_index(F/A,Pos),
			make_attr(N,_Mask,SuspsList,Attr),
			nth(Pos,SuspsList,VarSusps)
		)
	;
		lookup_passive_head(StoreType,H,[ActiveHead|PrevHs],VarDict,ViaGoal,VarSusps),
		NewAttrDict = AttrDict
	),
	head_info(H,A,Vars,_,_,Pairs),
	head_arg_matches(Pairs,VarDict,MatchingGoal,VarDict1),
	Suspension =.. [suspension,_,State,_,_,_,_|Vars],
	different_from_other_susps(H,Susp,PrevHs,PrevSusps,DiffSuspGoals),
	create_get_mutable_ref(active,State,GetMutable),
	Goal1 = 
	(
		'chr sbag_member'(Susp,VarSusps),
		Susp = Suspension,
		GetMutable,
		DiffSuspGoals,
		MatchingGoal
	),
	( member(unique(ID,UniqueKeus),Pragmas),
	  check_unique_keys(UniqueKeus,VarDict) ->
		Goal = (Goal1 -> true)
	;
		Goal = Goal1
	),
	rest_heads_retrieval_and_matching_n(Hs,IDs,Pragmas,[H|PrevHs],[Susp|PrevSusps],ActiveHead,Goals,Susps,VarDict1,NVarDict,NewAttrDict).

instantiate_pattern_goals([]).
instantiate_pattern_goals([_-attr(Attr,Bits,Goal)|Rest]) :-
	get_max_constraint_index(N),
	( N == 1 ->
		Goal = true
	;
		make_attr(N,Mask,_,Attr),
		or_list(Bits,Pattern), !,
		Goal = (Mask /\ Pattern =:= Pattern)
	),
	instantiate_pattern_goals(Rest).


check_unique_keys([],_).
check_unique_keys([V|Vs],Dict) :-
	lookup_eq(Dict,V,_),
	check_unique_keys(Vs,Dict).

% Generates tests to ensure the found constraint differs from previously found constraints
%	TODO: detect more cases where constraints need be different
different_from_other_susps(Head,Susp,Heads,Susps,DiffSuspGoals) :-
	( bagof(DiffSuspGoal, Pos ^ ( nth(Pos,Heads,PreHead), \+ Head \= PreHead, nth(Pos,Susps,PreSusp), DiffSuspGoal = (Susp \== PreSusp) ),DiffSuspGoalList) ->
	     list2conj(DiffSuspGoalList,DiffSuspGoals)
	;
	     DiffSuspGoals = true
	).

passive_head_via(Head,PrevHeads,AttrDict,VarDict,Goal,Attr,NewAttrDict) :-
	functor(Head,F,A),
	get_constraint_index(F/A,Pos),
	common_variables(Head,PrevHeads,CommonVars),
	translate(CommonVars,VarDict,Vars),
	or_pattern(Pos,Bit),
	( permutation(Vars,PermutedVars),
	  lookup_eq(AttrDict,PermutedVars,attr(Attr,Positions,_)) ->
		member(Bit,Positions), !,
		NewAttrDict = AttrDict,
		Goal = true
	; 
		Goal = (Goal1, PatternGoal),
		gen_get_mod_constraints(Vars,Goal1,Attr),
		NewAttrDict = [Vars - attr(Attr,[Bit|_],PatternGoal) | AttrDict]
	).
 
common_variables(T,Ts,Vs) :-
	term_variables(T,V1),
	term_variables(Ts,V2),
	intersect_eq(V1,V2,Vs).

gen_get_mod_constraints(L,Goal,Susps) :-
   get_target_module(Mod),
   (   L == [] ->
       Goal = 
       (   'chr default_store'(Global),
           get_attr(Global,Mod,TSusps),
	   TSusps = Susps
       )
   ; 
       (    L = [A] ->
            VIA =  'chr via_1'(A,V)
       ;    (   L = [A,B] ->
                VIA = 'chr via_2'(A,B,V)
            ;   VIA = 'chr via'(L,V)
            )
       ),
       Goal =
       (   VIA,
           get_attr(V,Mod,TSusps),
	   TSusps = Susps
       )
   ).

guard_body_copies(Rule,VarDict,GuardCopy,BodyCopy) :-
	guard_body_copies2(Rule,VarDict,GuardCopyList,BodyCopy),
	list2conj(GuardCopyList,GuardCopy).

guard_body_copies2(Rule,VarDict,GuardCopyList,BodyCopy) :-
	Rule = rule(_,_,Guard,Body),
	conj2list(Guard,GuardList),
	split_off_simple_guard(GuardList,VarDict,GuardPrefix,RestGuardList),
	my_term_copy(GuardPrefix-RestGuardList,VarDict,VarDict2,GuardPrefixCopy-RestGuardListCopyCore),

	append(GuardPrefixCopy,[RestGuardCopy],GuardCopyList),
	term_variables(RestGuardList,GuardVars),
	term_variables(RestGuardListCopyCore,GuardCopyVars),
	( chr_pp_flag(guard_locks,on),
%           bagof(('chr lock'(Y)) - ('chr unlock'(Y)),
%                 X ^ (member(X,GuardVars),		% X is a variable appearing in the original guard
%                      lookup_eq(VarDict,X,Y),            % translate X into new variable
%                      memberchk_eq(Y,GuardCopyVars)      % redundant check? or multiple entries for X possible?
%                     ),
%                 LocksUnlocks) 
	  Goal =  (member(X,GuardVars),		% X is a variable appearing in the original guard
                   lookup_eq(VarDict,X,Y),            % translate X into new variable
                   memberchk_eq(Y,GuardCopyVars)      % redundant check? or multiple entries for X possible?
                  ),
	  find_with_var_identity('chr lock'(Y)-'chr unlock'(Y), VarDict, Goal, LocksUnlocks )
          ->
		once(pairup(Locks,Unlocks,LocksUnlocks))
	;
		Locks = [],
		Unlocks = []
	),
	list2conj(Locks,LockPhase),
	list2conj(Unlocks,UnlockPhase),
	list2conj(RestGuardListCopyCore,RestGuardCopyCore),
	RestGuardCopy = (LockPhase,(RestGuardCopyCore,UnlockPhase)),
	my_term_copy(Body,VarDict2,BodyCopy).


split_off_simple_guard([],_,[],[]).
split_off_simple_guard([G|Gs],VarDict,S,C) :-
	( simple_guard(G,VarDict) ->
		S = [G|Ss],
		split_off_simple_guard(Gs,VarDict,Ss,C)
	;
		S = [],
		C = [G|Gs]
	).

% simple guard: cheap and benign (does not bind variables)
simple_guard(G,VarDict) :-
	binds_b(G,Vars),
	\+ (( member(V,Vars), 
	     lookup_eq(VarDict,V,_)
	   )).

my_term_copy(X,Dict,Y) :-
   my_term_copy(X,Dict,_,Y).

my_term_copy(X,Dict1,Dict2,Y) :-
   (   var(X) ->
       (   lookup_eq(Dict1,X,Y) ->
           Dict2 = Dict1
       ;   Dict2 = [X-Y|Dict1]
       )
   ;   functor(X,XF,XA),
       functor(Y,XF,XA),
       X =.. [_|XArgs],
       Y =.. [_|YArgs],
       my_term_copy_list(XArgs,Dict1,Dict2,YArgs)
   ).

my_term_copy_list([],Dict,Dict,[]).
my_term_copy_list([X|Xs],Dict1,Dict3,[Y|Ys]) :-
   my_term_copy(X,Dict1,Dict2,Y),
   my_term_copy_list(Xs,Dict2,Dict3,Ys).

gen_cond_susp_detachment(Id,Susp,FA,SuspDetachment) :-
	( is_attached(FA) ->
		( Id == [0], \+ may_trigger(FA) ->
			SuspDetachment = true
		;
			gen_uncond_susp_detachment(Susp,FA,UnCondSuspDetachment),
			SuspDetachment = 
			(   var(Susp) ->
			    true
			;   UnCondSuspDetachment
			)
		)
	;
	        SuspDetachment = true
	).

gen_uncond_susp_detachment(Susp,FA,SuspDetachment) :-
   ( is_attached(FA) ->
	( may_trigger(FA) ->
		make_name('detach_',FA,Fct),
		Detach =.. [Fct,Vars,Susp]
	;
		Detach = true
	),
	( chr_pp_flag(debugable,on) ->
		DebugEvent = 'chr debug_event'(remove(Susp))
	;
		DebugEvent = true
	),
	generate_delete_constraint_call(FA,Susp,DeleteCall),
	SuspDetachment = 
	(
		DebugEvent,
		remove_constraint_internal(Susp, Vars, Delete),
		( Delete == yes ->
			DeleteCall,
			Detach
		;
			true
		)
	)
   ;
	SuspDetachment = true
   ).

gen_uncond_susps_detachments([],[],true).
gen_uncond_susps_detachments([Susp|Susps],[Term|Terms],(SuspDetachment,SuspsDetachments)) :-
   functor(Term,F,A),
   gen_uncond_susp_detachment(Susp,F/A,SuspDetachment),
   gen_uncond_susps_detachments(Susps,Terms,SuspsDetachments).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  ____  _                                   _   _               _
%% / ___|(_)_ __ ___  _ __   __ _  __ _  __ _| |_(_) ___  _ __   / |
%% \___ \| | '_ ` _ \| '_ \ / _` |/ _` |/ _` | __| |/ _ \| '_ \  | |
%%  ___) | | | | | | | |_) | (_| | (_| | (_| | |_| | (_) | | | | | |
%% |____/|_|_| |_| |_| .__/ \__,_|\__, |\__,_|\__|_|\___/|_| |_| |_|
%%                   |_|          |___/

simpagation_head1_code(Head,RestHeads,OtherIDs,PragmaRule,F/A,Id,L,T) :-
   PragmaRule = pragma(Rule,ids(_,Heads2IDs),Pragmas,_Name,RuleNb),
   Rule = rule(_Heads,Heads2,Guard,Body),

   head_info(Head,A,_Vars,Susp,HeadVars,HeadPairs),
   head_arg_matches(HeadPairs,[],FirstMatching,VarDict1),

   build_head(F,A,Id,HeadVars,ClauseHead),

   append(RestHeads,Heads2,Heads),
   append(OtherIDs,Heads2IDs,IDs),
   reorder_heads(RuleNb,Head,Heads,IDs,NHeads,NIDs),
   rest_heads_retrieval_and_matching(NHeads,NIDs,Pragmas,Head,GetRestHeads,Susps,VarDict1,VarDict),
   split_by_ids(NIDs,Susps,OtherIDs,Susps1,Susps2), 

   guard_body_copies2(Rule,VarDict,GuardCopyList,BodyCopy),
   guard_via_reschedule(GetRestHeads,GuardCopyList,ClauseHead-FirstMatching,RescheduledTest),

   gen_uncond_susps_detachments(Susps1,RestHeads,SuspsDetachments),
   gen_cond_susp_detachment(Id,Susp,F/A,SuspDetachment),
   
	( chr_pp_flag(debugable,on) ->
		my_term_copy(Guard - Body, VarDict, _, DebugGuard - DebugBody),		
		DebugTry   = 'chr debug_event'(  try([Susp|Susps1],Susps2,DebugGuard,DebugBody)),
		DebugApply = 'chr debug_event'(apply([Susp|Susps1],Susps2,DebugGuard,DebugBody))
	;
		DebugTry = true,
		DebugApply = true
	),

   Clause = ( ClauseHead :-
		FirstMatching, 
		RescheduledTest,
		DebugTry,
                !,
		DebugApply,
                SuspsDetachments,
                SuspDetachment,
                BodyCopy
            ),
   L = [Clause | T].

split_by_ids([],[],_,[],[]).
split_by_ids([I|Is],[S|Ss],I1s,S1s,S2s) :-
	( memberchk_eq(I,I1s) ->
		S1s = [S | R1s],
		S2s = R2s
	;
		S1s = R1s,
		S2s = [S | R2s]
	),
	split_by_ids(Is,Ss,I1s,R1s,R2s).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  ____  _                                   _   _               ____
%% / ___|(_)_ __ ___  _ __   __ _  __ _  __ _| |_(_) ___  _ __   |___ \
%% \___ \| | '_ ` _ \| '_ \ / _` |/ _` |/ _` | __| |/ _ \| '_ \    __) |
%%  ___) | | | | | | | |_) | (_| | (_| | (_| | |_| | (_) | | | |  / __/
%% |____/|_|_| |_| |_| .__/ \__,_|\__, |\__,_|\__|_|\___/|_| |_| |_____|
%%                   |_|          |___/

%% Genereate prelude + worker predicate
%% prelude calls worker
%% worker iterates over one type of removed constraints
simpagation_head2_code(Head2,RestHeads2,RestIDs,PragmaRule,FA,Id,L,T) :-
   PragmaRule = pragma(Rule,ids(IDs1,_),Pragmas,_Name,RuleNb),
   Rule = rule(Heads1,_,Guard,Body),
   reorder_heads(RuleNb,Head2,Heads1,IDs1,[Head1|RestHeads1],[ID1|RestIDs1]),   	% Heads1 = [Head1|RestHeads1],
										% IDs1 = [ID1|RestIDs1],
   simpagation_head2_prelude(Head2,Head1,[RestHeads2,Heads1,Guard,Body],FA,Id,L,L1),
   extend_id(Id,Id2), 
   simpagation_head2_worker(Head2,Head1,ID1,RestHeads1,RestIDs1,RestHeads2,RestIDs,PragmaRule,FA,Id2,L1,T).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
simpagation_head2_prelude(Head,Head1,Rest,F/A,Id1,L,T) :-
	head_info(Head,A,Vars,Susp,VarsSusp,HeadPairs),
	build_head(F,A,Id1,VarsSusp,ClauseHead),
	head_arg_matches(HeadPairs,[],FirstMatching,VarDict),

	lookup_passive_head(Head1,[Head],VarDict,ModConstraintsGoal,AllSusps),

	gen_allocation(Id1,Vars,Susp,F/A,VarsSusp,ConstraintAllocationGoal),

	extend_id(Id1,DelegateId),
	extra_active_delegate_variables(Head,Rest,VarDict,ExtraVars),
	append([AllSusps|VarsSusp],ExtraVars,DelegateCallVars),
	build_head(F,A,DelegateId,DelegateCallVars,Delegate),

	PreludeClause = 
	   ( ClauseHead :-
	          FirstMatching,
	          ModConstraintsGoal,
	          !,
	          ConstraintAllocationGoal,
	          Delegate
	   ),
	L = [PreludeClause|T].

extra_active_delegate_variables(Term,Terms,VarDict,Vars) :-
	Term =.. [_|Args],
	delegate_variables(Term,Terms,VarDict,Args,Vars).

passive_delegate_variables(Term,PrevTerms,NextTerms,VarDict,Vars) :-
	term_variables(PrevTerms,PrevVars),
	delegate_variables(Term,NextTerms,VarDict,PrevVars,Vars).

delegate_variables(Term,Terms,VarDict,PrevVars,Vars) :-
	term_variables(Term,V1),
	term_variables(Terms,V2),
	intersect_eq(V1,V2,V3),
	list_difference_eq(V3,PrevVars,V4),
	translate(V4,VarDict,Vars).
	
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
simpagation_head2_worker(Head2,Head1,ID1,RestHeads1,IDs1,RestHeads2,IDs2,PragmaRule,FA,Id,L,T) :-
   PragmaRule = pragma(Rule,_,_,_,_),
   Rule = rule(_,_,Guard,Body),
   simpagation_head2_worker_end(Head2,[Head1,RestHeads1,RestHeads2,Guard,Body],FA,Id,L,L1),
   simpagation_head2_worker_body(Head2,Head1,ID1,RestHeads1,IDs1,RestHeads2,IDs2,PragmaRule,FA,Id,L1,T).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
simpagation_head2_worker_body(Head2,Head1,ID1,RestHeads1,IDs1,RestHeads2,IDs2,PragmaRule,F/A,Id,L,T) :-
   gen_var(OtherSusp),
   gen_var(OtherSusps),

   head_info(Head2,A,_Vars,Susp,VarsSusp,Head2Pairs),
   head_arg_matches(Head2Pairs,[],_,VarDict1),

   PragmaRule = pragma(Rule,_,Pragmas,_,RuleNb), 
   Rule = rule(_,_,Guard,Body),
   extra_active_delegate_variables(Head2,[Head1,RestHeads1,RestHeads2,Guard,Body],VarDict1,ExtraVars),
   append([[OtherSusp|OtherSusps]|VarsSusp],ExtraVars,HeadVars),
   build_head(F,A,Id,HeadVars,ClauseHead),

   functor(Head1,_OtherF,OtherA),
   head_info(Head1,OtherA,OtherVars,_,_,Head1Pairs),
   head_arg_matches(Head1Pairs,VarDict1,FirstMatching,VarDict2),

   OtherSuspension =.. [suspension,_,OtherState,_,_,_,_|OtherVars],
   create_get_mutable_ref(active,OtherState,GetMutable),
   IteratorSuspTest =
      (   OtherSusp = OtherSuspension,
          GetMutable
      ),

   (   (RestHeads1 \== [] ; RestHeads2 \== []) ->
		append(RestHeads1,RestHeads2,RestHeads),
		append(IDs1,IDs2,IDs),
		reorder_heads(RuleNb,Head1-Head2,RestHeads,IDs,NRestHeads,NIDs),
		rest_heads_retrieval_and_matching(NRestHeads,NIDs,Pragmas,[Head1,Head2],RestSuspsRetrieval,Susps,VarDict2,VarDict,[Head1],[OtherSusp],[]),
   		split_by_ids(NIDs,Susps,IDs1,Susps1,Susps2) 
   ;   RestSuspsRetrieval = [],
       Susps1 = [],
       Susps2 = [],
       VarDict = VarDict2
   ),

   gen_uncond_susps_detachments([OtherSusp | Susps1],[Head1|RestHeads1],Susps1Detachments),

   append([OtherSusps|VarsSusp],ExtraVars,RecursiveVars),
   build_head(F,A,Id,RecursiveVars,RecursiveCall),
   append([[]|VarsSusp],ExtraVars,RecursiveVars2),
   build_head(F,A,Id,RecursiveVars2,RecursiveCall2),

   guard_body_copies2(Rule,VarDict,GuardCopyList,BodyCopy),
   guard_via_reschedule(RestSuspsRetrieval,GuardCopyList,v(ClauseHead,IteratorSuspTest,FirstMatching),RescheduledTest),
   (   BodyCopy \== true ->
       gen_uncond_attach_goal(F/A,Susp,Attachment,Generation),
       gen_state_cond_call(Susp,A,RecursiveCall,Generation,ConditionalRecursiveCall),
       gen_state_cond_call(Susp,A,RecursiveCall2,Generation,ConditionalRecursiveCall2)
   ;   Attachment = true,
       ConditionalRecursiveCall = RecursiveCall,
       ConditionalRecursiveCall2 = RecursiveCall2
   ),

	( chr_pp_flag(debugable,on) ->
		my_term_copy(Guard - Body, VarDict, _, DebugGuard - DebugBody),		
		DebugTry   = 'chr debug_event'(  try([OtherSusp|Susps1],[Susp|Susps2],DebugGuard,DebugBody)),
		DebugApply = 'chr debug_event'(apply([OtherSusp|Susps1],[Susp|Susps2],DebugGuard,DebugBody))
	;
		DebugTry = true,
		DebugApply = true
	),

   ( member(unique(ID1,UniqueKeys), Pragmas),
     check_unique_keys(UniqueKeys,VarDict1) ->
	Clause =
		( ClauseHead :-
			( IteratorSuspTest,
			  FirstMatching ->
				( RescheduledTest,
				  DebugTry ->
					DebugApply,
					Susps1Detachments,
					Attachment,
					BodyCopy,
					ConditionalRecursiveCall2
				;
					RecursiveCall2
				)
			;
				RecursiveCall
			)
		)
    ;
	Clause =
      		( ClauseHead :-
             		( IteratorSuspTest,
			  FirstMatching,
			  RescheduledTest,
			  DebugTry ->
				DebugApply,
				Susps1Detachments,
				Attachment,
				BodyCopy,
				ConditionalRecursiveCall
			;
				RecursiveCall
			)
		)
   ),
   L = [Clause | T].

gen_state_cond_call(Susp,N,Call,Generation,ConditionalCall) :-
   length(Args,N),
   Suspension =.. [suspension,_,State,_,NewGeneration,_,_|Args],
   create_get_mutable_ref(active,State,GetState),
   create_get_mutable_ref(Generation,NewGeneration,GetGeneration),
   ConditionalCall =
      (   Susp = Suspension,
	  GetState,
          GetGeneration ->
		  'chr update_mutable'(inactive,State),
	          Call
	      ;   true
      ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
simpagation_head2_worker_end(Head,Rest,F/A,Id,L,T) :-
   head_info(Head,A,_Vars,_Susp,VarsSusp,Pairs),
   head_arg_matches(Pairs,[],_,VarDict),
   extra_active_delegate_variables(Head,Rest,VarDict,ExtraVars),
   append([[]|VarsSusp],ExtraVars,HeadVars),
   build_head(F,A,Id,HeadVars,ClauseHead),
   next_id(Id,ContinuationId),
   build_head(F,A,ContinuationId,VarsSusp,ContinuationHead),
   Clause = ( ClauseHead :- ContinuationHead ),
   L = [Clause | T].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  ____                                    _   _             
%% |  _ \ _ __ ___  _ __   __ _  __ _  __ _| |_(_) ___  _ __  
%% | |_) | '__/ _ \| '_ \ / _` |/ _` |/ _` | __| |/ _ \| '_ \ 
%% |  __/| | | (_) | |_) | (_| | (_| | (_| | |_| | (_) | | | |
%% |_|   |_|  \___/| .__/ \__,_|\__, |\__,_|\__|_|\___/|_| |_|
%%                 |_|          |___/                         

propagation_code(Head,RestHeads,Rule,RuleNb,RestHeadNb,FA,Id,L,T) :-
	( RestHeads == [] ->
		propagation_single_headed(Head,Rule,RuleNb,FA,Id,L,T)
	;   
		propagation_multi_headed(Head,RestHeads,Rule,RuleNb,RestHeadNb,FA,Id,L,T)
	).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Single headed propagation
%% everything in a single clause
propagation_single_headed(Head,Rule,RuleNb,F/A,Id,L,T) :-
   head_info(Head,A,Vars,Susp,VarsSusp,HeadPairs),
   build_head(F,A,Id,VarsSusp,ClauseHead),

   inc_id(Id,NextId),
   build_head(F,A,NextId,VarsSusp,NextHead),

   NextCall = NextHead,

   head_arg_matches(HeadPairs,[],HeadMatching,VarDict),
   guard_body_copies(Rule,VarDict,GuardCopy,BodyCopy),
   gen_allocation(Id,Vars,Susp,F/A,VarsSusp,Allocation),
   gen_uncond_attach_goal(F/A,Susp,Attachment,Generation), 

   gen_state_cond_call(Susp,A,NextCall,Generation,ConditionalNextCall),

	( chr_pp_flag(debugable,on) ->
		Rule = rule(_,_,Guard,Body),
		my_term_copy(Guard - Body, VarDict, _, DebugGuard - DebugBody),		
		DebugTry   = 'chr debug_event'(  try([],[Susp],DebugGuard,DebugBody)),
		DebugApply = 'chr debug_event'(apply([],[Susp],DebugGuard,DebugBody))
	;
		DebugTry = true,
		DebugApply = true
	),

   Clause = (
        ClauseHead :-
		HeadMatching,
		Allocation,
		'chr novel_production'(Susp,RuleNb),	% optimisation of t(RuleNb,Susp)
		GuardCopy,
		DebugTry,
		!,
		DebugApply,
		'chr extend_history'(Susp,RuleNb),
		Attachment,
		BodyCopy,
		ConditionalNextCall
   ),  
   L = [Clause | T].
   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% multi headed propagation
%% prelude + predicates to accumulate the necessary combinations of suspended
%% constraints + predicate to execute the body
propagation_multi_headed(Head,RestHeads,Rule,RuleNb,RestHeadNb,FA,Id,L,T) :-
   RestHeads = [First|Rest],
   propagation_prelude(Head,RestHeads,Rule,FA,Id,L,L1),
   extend_id(Id,ExtendedId),
   propagation_nested_code(Rest,[First,Head],Rule,RuleNb,RestHeadNb,FA,ExtendedId,L1,T).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
propagation_prelude(Head,[First|Rest],Rule,F/A,Id,L,T) :-
   head_info(Head,A,Vars,Susp,VarsSusp,HeadPairs),
   build_head(F,A,Id,VarsSusp,PreludeHead),
   head_arg_matches(HeadPairs,[],FirstMatching,VarDict),
   Rule = rule(_,_,Guard,Body),
   extra_active_delegate_variables(Head,[First,Rest,Guard,Body],VarDict,ExtraVars),

   lookup_passive_head(First,[Head],VarDict,FirstSuspGoal,Susps),

   gen_allocation(Id,Vars,Susp,F/A,VarsSusp,CondAllocation),

   extend_id(Id,NestedId),
   append([Susps|VarsSusp],ExtraVars,NestedVars), 
   build_head(F,A,NestedId,NestedVars,NestedHead),
   NestedCall = NestedHead,

   Prelude = (
      PreludeHead :-
	  FirstMatching,
	  FirstSuspGoal,
          !,
          CondAllocation,
          NestedCall
   ),
   L = [Prelude|T].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
propagation_nested_code([],[CurrentHead|PreHeads],Rule,RuleNb,RestHeadNb,FA,Id,L,T) :-
   propagation_end([CurrentHead|PreHeads],[],Rule,FA,Id,L,L1),
   propagation_body(CurrentHead,PreHeads,Rule,RuleNb,RestHeadNb,FA,Id,L1,T).

propagation_nested_code([Head|RestHeads],PreHeads,Rule,RuleNb,RestHeadNb,FA,Id,L,T) :-
   propagation_end(PreHeads,[Head|RestHeads],Rule,FA,Id,L,L1),
   propagation_accumulator([Head|RestHeads],PreHeads,Rule,FA,Id,L1,L2),
   inc_id(Id,IncId),
   propagation_nested_code(RestHeads,[Head|PreHeads],Rule,RuleNb,RestHeadNb,FA,IncId,L2,T).

propagation_body(CurrentHead,PreHeads,Rule,RuleNb,RestHeadNb,F/A,Id,L,T) :-
   Rule = rule(_,_,Guard,Body),
   get_prop_inner_loop_vars(PreHeads,[CurrentHead,Guard,Body],PreVarsAndSusps,VarDict1,Susp,RestSusps),
   gen_var(OtherSusp),
   gen_var(OtherSusps),
   functor(CurrentHead,_OtherF,OtherA),
   gen_vars(OtherA,OtherVars),
   Suspension =.. [suspension,_,State,_,_,_,_|OtherVars],
   create_get_mutable_ref(active,State,GetMutable),
   CurrentSuspTest = (
      OtherSusp = Suspension,
      GetMutable
   ),
   ClauseVars = [[OtherSusp|OtherSusps]|PreVarsAndSusps],
   build_head(F,A,Id,ClauseVars,ClauseHead),
   RecursiveVars = [OtherSusps|PreVarsAndSusps],
   build_head(F,A,Id,RecursiveVars,RecursiveHead),
   RecursiveCall = RecursiveHead,
   CurrentHead =.. [_|OtherArgs],
   pairup(OtherArgs,OtherVars,OtherPairs),
   head_arg_matches(OtherPairs,VarDict1,Matching,VarDict),
 
   different_from_other_susps(CurrentHead,OtherSusp,PreHeads,RestSusps,DiffSuspGoals), 

   guard_body_copies(Rule,VarDict,GuardCopy,BodyCopy),
   gen_uncond_attach_goal(F/A,Susp,Attach,Generation),
   gen_state_cond_call(Susp,A,RecursiveCall,Generation,ConditionalRecursiveCall),

   history_susps(RestHeadNb,[OtherSusp|RestSusps],Susp,[],HistorySusps),
   bagof('chr novel_production'(X,Y),( member(X,HistorySusps), Y = TupleVar) ,NovelProductionsList),
   list2conj(NovelProductionsList,NovelProductions),
   Tuple =.. [t,RuleNb|HistorySusps],

	( chr_pp_flag(debugable,on) ->
		Rule = rule(_,_,Guard,Body),
		my_term_copy(Guard - Body, VarDict, _, DebugGuard - DebugBody),		
		DebugTry   = 'chr debug_event'(  try([],[Susp,OtherSusp|RestSusps],DebugGuard,DebugBody)),
		DebugApply = 'chr debug_event'(apply([],[Susp,OtherSusp|RestSusps],DebugGuard,DebugBody))
	;
		DebugTry = true,
		DebugApply = true
	),

   Clause = (
      ClauseHead :-
         (   CurrentSuspTest,
	     DiffSuspGoals,
             Matching,
	     TupleVar = Tuple,
	     NovelProductions,
             GuardCopy,
	     DebugTry ->
	     DebugApply,
	     'chr extend_history'(Susp,TupleVar),
             Attach,
             BodyCopy,
             ConditionalRecursiveCall
         ;   RecursiveCall
         )
   ),
   L = [Clause|T].

history_susps(Count,OtherSusps,Susp,Acc,HistorySusps) :-
	( Count == 0 ->
		reverse(OtherSusps,ReversedSusps),
		append(ReversedSusps,[Susp|Acc],HistorySusps)
	;
		OtherSusps = [OtherSusp|RestOtherSusps],
		NCount is Count - 1,
		history_susps(NCount,RestOtherSusps,Susp,[OtherSusp|Acc],HistorySusps)
	).

get_prop_inner_loop_vars([Head],Terms,HeadVars,VarDict,Susp,[]) :-
	!,
	functor(Head,_F,A),
	head_info(Head,A,_Vars,Susp,VarsSusp,Pairs),
	head_arg_matches(Pairs,[],_,VarDict),
	extra_active_delegate_variables(Head,Terms,VarDict,ExtraVars),
	append(VarsSusp,ExtraVars,HeadVars).
get_prop_inner_loop_vars([Head|Heads],Terms,VarsSusps,NVarDict,MainSusp,[Susp|RestSusps]) :-
	get_prop_inner_loop_vars(Heads,[Head|Terms],RestVarsSusp,VarDict,MainSusp,RestSusps),
	functor(Head,_F,A),
	gen_var(Susps),
	head_info(Head,A,_Vars,Susp,_VarsSusp,Pairs),
	head_arg_matches(Pairs,VarDict,_,NVarDict),
	passive_delegate_variables(Head,Heads,Terms,NVarDict,HeadVars),
	append(HeadVars,[Susp,Susps|RestVarsSusp],VarsSusps).

propagation_end([CurrentHead|PrevHeads],NextHeads,Rule,F/A,Id,L,T) :-
   Rule = rule(_,_,Guard,Body),
   gen_var_susp_list_for(PrevHeads,[CurrentHead,NextHeads,Guard,Body],_,VarsAndSusps,AllButFirst,FirstSusp),

   Vars = [ [] | VarsAndSusps],

   build_head(F,A,Id,Vars,Head),

   (   Id = [0|_] ->
       next_id(Id,PrevId),
       PrevVarsAndSusps = AllButFirst
   ;
       dec_id(Id,PrevId),
       PrevVarsAndSusps = [FirstSusp|AllButFirst]
   ),
  
   build_head(F,A,PrevId,PrevVarsAndSusps,PrevHead),
   PredecessorCall = PrevHead,
 
   Clause = (
      Head :-
         PredecessorCall
   ),
   L = [Clause | T].

gen_var_susp_list_for([Head],Terms,VarDict,HeadVars,VarsSusp,Susp) :-
   !,
   functor(Head,_F,A),
   head_info(Head,A,_Vars,Susp,VarsSusp,HeadPairs),
   head_arg_matches(HeadPairs,[],_,VarDict),
   extra_active_delegate_variables(Head,Terms,VarDict,ExtraVars),
   append(VarsSusp,ExtraVars,HeadVars).
gen_var_susp_list_for([Head|Heads],Terms,NVarDict,VarsSusps,Rest,Susps) :-
	gen_var_susp_list_for(Heads,[Head|Terms],VarDict,Rest,_,_),
	functor(Head,_F,A),
	gen_var(Susps),
	head_info(Head,A,_Vars,Susp,_VarsSusp,HeadPairs),
	head_arg_matches(HeadPairs,VarDict,_,NVarDict),
	passive_delegate_variables(Head,Heads,Terms,NVarDict,HeadVars),
	append(HeadVars,[Susp,Susps|Rest],VarsSusps).

propagation_accumulator([NextHead|RestHeads],[CurrentHead|PreHeads],Rule,F/A,Id,L,T) :-
	Rule = rule(_,_,Guard,Body),
	pre_vars_and_susps(PreHeads,[CurrentHead,NextHead,RestHeads,Guard,Body],PreVarsAndSusps,VarDict,PreSusps),
	gen_var(OtherSusps),
	functor(CurrentHead,_OtherF,OtherA),
	gen_vars(OtherA,OtherVars),
	head_info(CurrentHead,OtherA,OtherVars,OtherSusp,_VarsSusp,HeadPairs),
	head_arg_matches(HeadPairs,VarDict,FirstMatching,VarDict1),
	
	OtherSuspension =.. [suspension,_,State,_,_,_,_|OtherVars],

	different_from_other_susps(CurrentHead,OtherSusp,PreHeads,PreSusps,DiffSuspGoals),
	create_get_mutable_ref(active,State,GetMutable),
	CurrentSuspTest = (
	   OtherSusp = OtherSuspension,
	   GetMutable,
	   DiffSuspGoals,
	   FirstMatching
	),
        lookup_passive_head(NextHead,[CurrentHead|PreHeads],VarDict1,NextSuspGoal,NextSusps),
	inc_id(Id,NestedId),
	ClauseVars = [[OtherSusp|OtherSusps]|PreVarsAndSusps],
	build_head(F,A,Id,ClauseVars,ClauseHead),
	passive_delegate_variables(CurrentHead,PreHeads,[NextHead,RestHeads,Guard,Body],VarDict1,CurrentHeadVars),
	append([NextSusps|CurrentHeadVars],[OtherSusp,OtherSusps|PreVarsAndSusps],NestedVars),
	build_head(F,A,NestedId,NestedVars,NestedHead),
	
	RecursiveVars = [OtherSusps|PreVarsAndSusps],
	build_head(F,A,Id,RecursiveVars,RecursiveHead),
	Clause = (
	   ClauseHead :-
	   (   CurrentSuspTest,
	       NextSuspGoal
	       ->
	       NestedHead
	   ;   RecursiveHead
	   )
	),   
	L = [Clause|T].

pre_vars_and_susps([Head],Terms,HeadVars,VarDict,[]) :-
	!,
	functor(Head,_F,A),
	head_info(Head,A,_Vars,_Susp,VarsSusp,HeadPairs),
	head_arg_matches(HeadPairs,[],_,VarDict),
	extra_active_delegate_variables(Head,Terms,VarDict,ExtraVars),
	append(VarsSusp,ExtraVars,HeadVars).
pre_vars_and_susps([Head|Heads],Terms,NVSs,NVarDict,[Susp|Susps]) :-
	pre_vars_and_susps(Heads,[Head|Terms],VSs,VarDict,Susps),
	functor(Head,_F,A),
	gen_var(NextSusps),
	head_info(Head,A,_Vars,Susp,_VarsSusp,HeadPairs),
	head_arg_matches(HeadPairs,VarDict,_,NVarDict),
	passive_delegate_variables(Head,Heads,Terms,NVarDict,HeadVars),
	append(HeadVars,[Susp,NextSusps|VSs],NVSs).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  ____               _             _   _                _ 
%% |  _ \ __ _ ___ ___(_)_   _____  | | | | ___  __ _  __| |
%% | |_) / _` / __/ __| \ \ / / _ \ | |_| |/ _ \/ _` |/ _` |
%% |  __/ (_| \__ \__ \ |\ V /  __/ |  _  |  __/ (_| | (_| |
%% |_|   \__,_|___/___/_| \_/ \___| |_| |_|\___|\__,_|\__,_|
%%                                                          
%%  ____      _        _                 _ 
%% |  _ \ ___| |_ _ __(_) _____   ____ _| |
%% | |_) / _ \ __| '__| |/ _ \ \ / / _` | |
%% |  _ <  __/ |_| |  | |  __/\ V / (_| | |
%% |_| \_\___|\__|_|  |_|\___| \_/ \__,_|_|
%%                                         
%%  ____                    _           _             
%% |  _ \ ___  ___  _ __ __| | ___ _ __(_)_ __   __ _ 
%% | |_) / _ \/ _ \| '__/ _` |/ _ \ '__| | '_ \ / _` |
%% |  _ <  __/ (_) | | | (_| |  __/ |  | | | | | (_| |
%% |_| \_\___|\___/|_|  \__,_|\___|_|  |_|_| |_|\__, |
%%                                              |___/ 

reorder_heads(RuleNb,Head,RestHeads,RestIDs,NRestHeads,NRestIDs) :-
	( chr_pp_flag(reorder_heads,on) ->
		reorder_heads_main(RuleNb,Head,RestHeads,RestIDs,NRestHeads,NRestIDs)
	;
		NRestHeads = RestHeads,
		NRestIDs = RestIDs
	).

reorder_heads_main(RuleNb,Head,RestHeads,RestIDs,NRestHeads,NRestIDs) :-
	term_variables(Head,Vars),
	InitialData = entry([],[],Vars,RestHeads,RestIDs,RuleNb),
%% Ciao begin
	a_star(InitialData,FD,final_data(FD),N^EN^C,expand_data(N,EN,C),FinalData),
%% Ciao end
	FinalData   = entry(RNRestHeads,RNRestIDs,_,_,_,_),
	reverse(RNRestHeads,NRestHeads),
	reverse(RNRestIDs,NRestIDs).

final_data(Entry) :-
	Entry = entry(_,_,_,_,[],_).	

expand_data(Entry,NEntry,Cost) :-
	Entry = entry(Heads,IDs,Vars,NHeads,NIDs,RuleNb),
	term_variables(Entry,EVars),
	NEntry = entry([Head1|Heads],[ID1|IDs],Vars1,NHeads1,NIDs1,RuleNb),
	select2(Head1,ID1,NHeads,NIDs,NHeads1,NIDs1),
	order_score(Head1,ID1,Vars,NHeads1,RuleNb,Cost),
	term_variables([Head1|Vars],Vars1).

order_score(Head,ID,KnownVars,RestHeads,RuleNb,Score) :-
	functor(Head,F,A),
	get_store_type(F/A,StoreType),
	order_score(StoreType,Head,ID,KnownVars,RestHeads,RuleNb,Score).

order_score(default,Head,_ID,KnownVars,RestHeads,RuleNb,Score) :-
	term_variables(Head,HeadVars),
	term_variables(RestHeads,RestVars),
	order_score_vars(HeadVars,KnownVars,RestHeads,0,Score).
order_score(multi_hash(Indexes),Head,_ID,KnownVars,RestHeads,RuleNb,Score) :-
	order_score_indexes(Indexes,Head,KnownVars,0,Score).
order_score(global_ground,Head,ID,_KnownVars,_RestHeads,RuleNb,Score) :-
	functor(Head,F,A),
	( get_pragma_unique(RuleNb,ID,Vars), 
          Vars == [] ->
		Score = 1		% guaranteed O(1)
	; A == 0 ->			% flag constraint
		Score = 10		% O(1)? [CHECK: no deleted/triggered/... constraints in store?]
	; A > 0 ->
		Score = 100
	).
			
order_score(multi_store(StoreTypes),Head,ID,KnownVars,RestHeads,RuleNb,Score) :-
	find_with_var_identity(
		S,
		t(Head,KnownVars,RestHeads),
		( member(ST,StoreTypes), order_score(ST,Head,ID,KnownVars,RestHeads,RuleNb,S) ),
		Scores
	),
	min_list(Scores,Score).
		

order_score_indexes([],_,_,Score,Score) :-
	Score > 0.
order_score_indexes([I|Is],Head,KnownVars,Score,NScore) :-
	multi_hash_key_args(I,Head,Args),
	( forall(Arg,Args,hprolog:memberchk_eq(Arg,KnownVars)) ->
		Score1 is Score + 10 	
	;
		Score1 = Score
	),
	order_score_indexes(Is,Head,KnownVars,Score1,NScore).

order_score_vars([],_,_,Score,NScore) :-
	( Score == 0 ->
		NScore = 0
	;
		NScore = Score
	).
order_score_vars([V|Vs],KnownVars,RestVars,Score,NScore) :-
	( memberchk_eq(V,KnownVars) ->
		TScore is Score + 10
	; memberchk_eq(V,RestVars) ->
		TScore is Score + 100
	;
		TScore = Score
	),
	order_score_vars(Vs,KnownVars,RestVars,TScore,NScore).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  ___       _ _       _             
%% |_ _|_ __ | (_)_ __ (_)_ __   __ _ 
%%  | || '_ \| | | '_ \| | '_ \ / _` |
%%  | || | | | | | | | | | | | | (_| |
%% |___|_| |_|_|_|_| |_|_|_| |_|\__, |
%%                              |___/ 

%% SWI begin
create_get_mutable_ref(V,M,GM) :- GM = (M = mutable(V)).
%% SWI end

%% SICStus begin
%% create_get_mutable_ref(V,M,GM) :- GM = get_mutable(V,M).
%% SICStus end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  _   _ _   _ _ _ _
%% | | | | |_(_) (_) |_ _   _
%% | | | | __| | | | __| | | |
%% | |_| | |_| | | | |_| |_| |
%%  \___/ \__|_|_|_|\__|\__, |
%%                      |___/

gen_var(_).
gen_vars(N,Xs) :-
   length(Xs,N). 

head_info(Head,A,Vars,Susp,VarsSusp,HeadPairs) :-
   vars_susp(A,Vars,Susp,VarsSusp),
   Head =.. [_|Args],
   pairup(Args,Vars,HeadPairs).
 
inc_id([N|Ns],[O|Ns]) :-
   O is N + 1.
dec_id([N|Ns],[M|Ns]) :-
   M is N - 1.

extend_id(Id,[0|Id]).

next_id([_,N|Ns],[O|Ns]) :-
   O is N + 1.

build_head(F,A,Id,Args,Head) :-
   buildName(F,A,Id,Name),
   Head =.. [Name|Args].

buildName(Fct,Aty,List,Result) :-
   atom_concat(Fct, (/) ,FctSlash),
   atomic_concat(FctSlash,Aty,FctSlashAty),
   buildName_(List,FctSlashAty,Result).

buildName_([],Name,Name).
buildName_([N|Ns],Name,Result) :-
  buildName_(Ns,Name,Name1),
  atom_concat(Name1,'__',NameDash),    % '_' is a char :-(
  atomic_concat(NameDash,N,Result).

vars_susp(A,Vars,Susp,VarsSusp) :-
   length(Vars,A),
   append(Vars,[Susp],VarsSusp).

make_attr(N,Mask,SuspsList,Attr) :-
	length(SuspsList,N),
	Attr =.. [v,Mask|SuspsList].

or_pattern(Pos,Pat) :-
	Pow is Pos - 1,
	Pat is 1 << Pow.      % was 2 ** X

and_pattern(Pos,Pat) :-
	X is Pos - 1,
	Y is 1 << X,          % was 2 ** X
	Pat is (-1)*(Y + 1).	% because fx (-) is redefined

conj2list(Conj,L) :-				%% transform conjunctions to list
  conj2list(Conj,L,[]).

conj2list(Conj,L,T) :-
  Conj = (G1,G2), !,
  conj2list(G1,L,T1),
  conj2list(G2,T1,T).
conj2list(G,[G | T],T).

list2conj([],true).
list2conj([G],X) :- !, X = G.
list2conj([G|Gs],C) :-
	( G == true ->				%% remove some redundant trues
		list2conj(Gs,C)
	;
		C = (G,R),
		list2conj(Gs,R)
	).

list2disj([],fail).
list2disj([G],X) :- !, X = G.
list2disj([G|Gs],C) :-
	( G == fail ->				%% remove some redundant fails
		list2disj(Gs,C)
	;
		C = (G;R),
		list2disj(Gs,R)
	).

atom_concat_list([X],X) :- ! .
atom_concat_list([X|Xs],A) :-
	atom_concat_list(Xs,B),
	atomic_concat(X,B,A).

atomic_concat(A,B,C) :-
	make_atom(A,AA),
	make_atom(B,BB),
	atom_concat(AA,BB,C).

make_atom(A,AA) :-
	(
	  atom(A) ->
	  AA = A
	;
	  number(A) ->
	  number_codes(A,AL),
	  atom_codes(AA,AL)
	).


make_name(Prefix,F/A,Name) :-
	atom_concat_list([Prefix,F,(/),A],Name).

set_elems([],_).
set_elems([X|Xs],X) :-
	set_elems(Xs,X).

member2([X|_],[Y|_],X-Y).
member2([_|Xs],[_|Ys],P) :-
	member2(Xs,Ys,P).

select2(X, Y, [X|Xs], [Y|Ys], Xs, Ys).
select2(X, Y, [X1|Xs], [Y1|Ys], [X1|NXs], [Y1|NYs]) :-
	select2(X, Y, Xs, Ys, NXs, NYs).

pair_all_with([],_,[]).
pair_all_with([X|Xs],Y,[X-Y|Rest]) :-
	pair_all_with(Xs,Y,Rest).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

lookup_passive_head(Head,PreJoin,VarDict,Goal,AllSusps) :-
	functor(Head,F,A),
	get_store_type(F/A,StoreType),
	lookup_passive_head(StoreType,Head,PreJoin,VarDict,Goal,AllSusps).

lookup_passive_head(default,Head,PreJoin,VarDict,Goal,AllSusps) :-
	passive_head_via(Head,PreJoin,[],VarDict,Goal,Attr,AttrDict),   
	instantiate_pattern_goals(AttrDict),
	get_max_constraint_index(N),
	( N == 1 ->
		AllSusps = Attr
	;
		functor(Head,F,A),
		get_constraint_index(F/A,Pos),
		make_attr(N,_,SuspsList,Attr),
		nth(Pos,SuspsList,AllSusps)
	).
lookup_passive_head(multi_hash(Indexes),Head,_PreJoin,VarDict,Goal,AllSusps) :-
	once((
		member(Index,Indexes),
		multi_hash_key_args(Index,Head,KeyArgs),	
		translate(KeyArgs,VarDict,KeyArgCopies)
	)),
	( KeyArgCopies = [KeyCopy] ->
		true
	;
		KeyCopy =.. [k|KeyArgCopies]
	),
	functor(Head,F,A),
	multi_hash_via_lookup_name(F/A,Index,ViaName),
	Goal =.. [ViaName,KeyCopy,AllSusps],
	update_store_type(F/A,multi_hash([Index])).
lookup_passive_head(global_ground,Head,PreJoin,_VarDict,Goal,AllSusps) :-
	functor(Head,F,A),
	global_ground_store_name(F/A,StoreName),
	make_get_store_goal(StoreName,AllSusps,Goal), % Goal = nb_getval(StoreName,AllSusps),
	update_store_type(F/A,global_ground).
lookup_passive_head(multi_store(StoreTypes),Head,PreJoin,VarDict,Goal,AllSusps) :-
	once((
		member(ST,StoreTypes),
		lookup_passive_head(ST,Head,PreJoin,VarDict,Goal,AllSusps)
	)).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
assume_constraint_stores([]).
assume_constraint_stores([C|Cs]) :-
	( \+ may_trigger(C),
	  is_attached(C),
	  get_store_type(C,default) ->
		get_indexed_arguments(C,IndexedArgs),
		findall(Index,(sublist(Index,IndexedArgs), Index \== []),Indexes),
		assumed_store_type(C,multi_store([multi_hash(Indexes),global_ground]))	
	;
		true
	),
	assume_constraint_stores(Cs).

get_indexed_arguments(C,IndexedArgs) :-
	C = F/A,
	get_indexed_arguments(1,A,C,IndexedArgs).

get_indexed_arguments(I,N,C,L) :-
	( I > N ->
		L = []
	; 	( is_indexed_argument(C,I) ->
			L = [I|T]
		;
			L = T
		),
		J is I + 1,
		get_indexed_arguments(J,N,C,T)
	).
	
validate_store_type_assumptions([]).
validate_store_type_assumptions([C|Cs]) :-
	validate_store_type_assumption(C),
	validate_store_type_assumptions(Cs).	

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Ciao begin
:- pop_prolog_flag( multi_arity_warnings ).

verbosity_on :- current_prolog_flag(verbose,yes).
%% Ciao end

%% SWI begin
% verbosity_on :- prolog_flag(verbose,V), V == yes.
%% SWI end

%% SICStus begin
%% verbosity_on.  % at the moment
%% SICStus end
