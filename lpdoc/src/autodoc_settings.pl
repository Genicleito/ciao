:- module(autodoc_settings, [], [dcg, assertions, regtypes, fsyntax]). 

:- doc(title, "Current documentation settings").
:- doc(author, "Jose F. Morales").

:- doc(module, "This module defines the predicates to load and access
   documentation configurations.").

:- use_module(library(pathnames), [path_concat/3]).
:- use_module(library(messages), [error_message/2]).

% ---------------------------------------------------------------------------

:- use_module(lpdoc(doccfg_holder)).
:- use_module(library(lists), [append/3]).

:- data name_value/2.

add_name_value(Name, Value) :-
	data_facts:assertz_fact(name_value(Name, Value)).

% read all values
all_values(Name, Values) :-
	all_name_values(Name, Values0),
	(
	    Values0 == [] ->
	    all_pred_values(Name, Values)
	;
	    Values = Values0
	).

all_pred_values(Name, Values) :-
	findall(Value, get_pred_value(Name, Value), Values).

all_name_values(Name, Values) :-
	findall(Value, name_value(Name, Value), Values).

get_value(Name, Value) :-
	name_value(Name, _) ->
	name_value(Name, Value)
    ;
	get_pred_value(Name, Value).

% TODO: throw exception instead
:- pred check_var_exists(Var)
# "Fails printing a message if variable @var{Var} does not exist.".

check_var_exists(Var) :-
	get_value(Var, _),
	!.
check_var_exists(Var) :-
	error_message("Variable ~w not found", [Var]),
	fail.

dyn_load_cfg_module_into_make(ConfigFile) :-
	doccfg_holder:do_use_module(ConfigFile).

% (Get value, given by a predicate definition Name/1)
get_pred_value(Name, Value) :-
	( atom(Name) ->
	    Pred =.. [Name, Value]
	; Name =.. Flat,
	  append(Flat, [Value], PredList),
	  Pred =.. PredList
	),
	doccfg_holder:call_unknown(_:Pred).

% ---------------------------------------------------------------------------
:- doc(section, "Loading Setting").

:- export(settings_file/1).
:- data settings_file/1.

set_settings_file(ConfigFile) :-
	retractall_fact(settings_file(_)),
	assertz_fact(settings_file(ConfigFile)).

% TODO: no unload?
:- export(load_settings/2).
:- pred load_settings(ConfigFile, Opts) # "Load configuration from
   @var{ConfigFile} and @var{Opts}".

load_settings(ConfigFile, Opts) :-
	clean_make_opts,
	load_settings_(ConfigFile),
	set_make_opts(Opts),
	ensure_lpdoclib_defined.

load_settings_(ConfigFile) :-
	( find_pl(ConfigFile, AbsFilePath) ->
	    set_settings_file(AbsFilePath),
	    dyn_load_cfg_module_into_make(AbsFilePath)
	;
	    working_directory(CWD0, CWD0),
	    path_concat(CWD0, '', CWD),
	    % Fill cfg without a configuration file
	    add_name_value(filepath, CWD),
	    add_name_value('$implements', 'doccfg')
	),
	!.
load_settings_(ConfigFile) :-
	throw(autodoc_error("settings file ~w does not exist", [ConfigFile])).

% `Path` is the absolute file name for `F` or `F` with `.pl` extension
find_pl(F, Path) :-
	fixed_absolute_file_name(F, Path0),
	( file_exists(Path0) -> Path = Path0
	; atom_concat(Path0, '.pl', Path1),
	  file_exists(Path1),
	  Path = Path1
	).

% Verify that the configuration module uses the lpdoclib(doccfg) package
:- export(verify_settings/0).
verify_settings :-
	( setting_value('$implements', 'doccfg') ->
	    true
	; throw(autodoc_error("Configuration files must use the lpdoclib(doccfg) package", []))
	).

% Define 'lpdoclib' setting, check that it is valid
ensure_lpdoclib_defined :-
	( LpDocLibDir = ~file_search_path(lpdoclib),
	  file_exists(~path_concat(LpDocLibDir, 'doccfg.pl')) ->
	    add_name_value(lpdoclib, LpDocLibDir)
	; error_message(
% ___________________________________________________________________________
 "No valid file search path for 'lpdoclib' alias.\n"||
 "Please, check this is LPdoc installation.\n", []),
	  fail
	).

%:- dynamic file_search_path/2.
%:- multifile file_search_path/2.

:- use_module(library(system), [file_exists/1]).

:- export(autodoc_option/1).
:- data autodoc_option/1.

% ---------------------------------------------------------------------------

clean_make_opts :-
	retractall_fact(autodoc_option(_)),
	retractall_fact(name_value(_, _)).

set_make_opts([]).
set_make_opts([X|Xs]) :- set_make_opt(X), set_make_opts(Xs).

set_make_opt(autodoc_option(Opt)) :- !,
	assertz_fact(autodoc_option(Opt)).
set_make_opt(name_value(Name, Value)) :- !,
	assertz_fact(name_value(Name, Value)).
set_make_opt(X) :- throw(error(unknown_opt(X), set_make_opt/1)).

% ---------------------------------------------------------------------------
:- doc(section, "Checking or Setting Options").

:- use_module(library(system)).
:- use_module(library(system_extra)).
:- use_module(library(bundle/doc_flags), [docformatdir/2]).

:- export(check_setting/1).
check_setting(Name) :- check_var_exists(Name).

:- use_module(library(bundle/doc_flags), [bibfile/1, docformatdir/2]).

% (With implicit default value)
:- export(setting_value_or_default/2).
:- pred setting_value_or_default(Var, Value)
# "Returns in @var{Value} the value of the variable @var{Var}. In case
  this variable does not exists, it returns a default value. If there
  is no default value for the variable @var{Var} it fails.".

setting_value_or_default(Name, Value) :-
	( get_value(Name, Value0) ->
	    Value = Value0
	; Value = ~default_val(Name)
	).

default_val(startpage) := 1.
default_val(papertype) := afourpaper.
default_val(perms) := perms(rwX, rX, rX).
default_val(owner) := ~get_pwnam.
default_val(group) := G :- ( G = ~get_grnam -> true ; G = 'unknown' ).
default_val(bibfile) := ~bibfile.
default_val(htmldir) := ~docformatdir(html).
default_val(docdir) := ~docformatdir(any).
default_val(infodir) := ~docformatdir(info).
default_val(mandir) := ~docformatdir(manl).

% (With explicit default value)
:- export(setting_value_or_default/3).
setting_value_or_default(Name, DefValue, Value) :-
	( get_value(Name, Value0) ->
	    Value = Value0
	; Value = DefValue
	).

:- export(setting_value/2).
setting_value(Name, Value) :-
	get_value(Name, Value).

:- export(all_setting_values/2).
%all_setting_values(Name) := ~findall(T, ~setting_value(doc_mainopt)).
all_setting_values(X) := ~findall(T, setting_value(X, T)) :-
	( X = doc_mainopts ; X = doc_compopts ), !. % TODO: all_values fail if empty?!
all_setting_values(Name) := ~all_values(Name).

:- use_module(library(aggregates)).

:- export(requested_file_formats/1).
:- pred requested_file_formats(F) # "@var{F} is a requested file format".
requested_file_formats := F :-
	F = ~all_values(docformat).

% ---------------------------------------------------------------------------
:- doc(section, "Paths to files").

:- use_module(lpdoc(autodoc_filesystem), [cleanup_vpath/0, add_vpath/1]).

:- export(load_vpaths/0).
load_vpaths :-
	cleanup_vpath,
	get_lib_opts(Libs, SysLibs),
	( % (failure-driven loop)
	  ( P = '.' % find in the current dir
	  ; member(P, Libs)
	  ; member(P, SysLibs)
	  ),
	    add_vpath(P),
	    fail
	; true
	).

:- export(get_lib_opts/2).
get_lib_opts(Libs, SysLibs) :-
	Libs = ~all_setting_values(filepath),
%	SysLibs = ~all_setting_values(systempath),
	SysLibs = ~findall(P, (file_search_path(_Alias, P), \+ P = '.')).

:- multifile file_search_path/2.
:- dynamic file_search_path/2.

% TODO: prioritize alias paths for the current bundle?
% :- use_module(lpdoc(autodoc_filesystem), [get_parent_bundle/1]).
% :- use_module(engine(internals), ['$bundle_alias_path'/3]).

% ---------------------------------------------------------------------------
:- doc(section, "External Commands").
% TODO: Ideally, each backend should specify this part.

:- doc(subsection, "Visualization of Documents").
% TODO: These commands were originally customizable by the
%       user. Nowadays, configuration files are not easy to find... It
%       is lpdoc task to determine what application to use
%       automatically based on the operating system.

:- use_module(engine(system_info), [get_os/1]).

:- export(generic_viewer/1).
% Generic document viewer
generic_viewer('open') :- get_os('DARWIN'), !.
generic_viewer('cygstart') :- get_os('Win32'), !.
%viewer('start') :- get_os('Win32'), !.
generic_viewer('xdg-open') :- get_os('LINUX'), !.

% TODO: This seems to be done by the emacs mode...
% lpsettings <- [] # "Generates default LPSETTINGS.pl in the current directory"
% 	:-
% 	working_directory(CWD0, CWD0),
%       path_concat(CWD0, '', CWD),
% 	generate_default_lpsettings_file(CWD, '').

%% The command that views dvi files in your system
:- export(xdvi/1).
xdvi := 'xdvi'.

%% The default size at which manuals are viewed This
%% is typically an integer (1-10 usually) and unfortunately changes
%% depending on the version of xdvi used.
:- export(xdvisize/1).
xdvisize := '8'.

:- doc(subsection, "Bibliography Generation").

%% The command that builds .bbl files from .bib bibliography
%% files in your system
:- export(bibtex/1).
bibtex := 'bibtex'.

:- doc(subsection, "Texinfo Related Commands").

%% Define this to be the command that runs tex in your system
:- export(tex/1).
tex := 'tex'.

%% Alternative (sometimes smarter about number of times it needs to run):
%% tex := 'texi2dvi '.
%% (but insists on checking the links, which is a pain...)

%% The command that runs texindex in your system
%% (Not needed if texi2dvi is installed)
:- export(texindex/1).
texindex := 'texindex'.

%% The command that converts dvi to postscript in your system.
:- export(dvips/1).
dvips := 'dvips'.

%% The command that converts postscript to pdf in your system. Make
%% sure it generates postscript fonts, not bitmaps (selecting -Ppdf in
%% dvips often does the trick)
:- export(ps2pdf/1).
ps2pdf := 'ps2pdf'.

%% The command that converts tex to pdf in your system
%% texpdf := 'pdftex'.

%% The command that converts texinfo files into info
%% files in your system. Set also the appropriate flags.
:- export(makeinfo/1).
makeinfo := 'makeinfo'.

:- doc(subsection, "Image Conversions").

%% The command that converts graphics files to other formats
:- export(convertc/1).
convertc := 'convert'.

