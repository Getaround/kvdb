%% @author Ulf Wiger <ulf@feuerlabs.com>
%% @author Tony Rogvall <tony@rogvall.se>
%% @copyright 2011-2012, Feuerlabs Inc
%% @doc
%% Key-value database frontend
%%
%% Kvdb is a key-value database library, supporting different backends
%% (currently: sqlite3 and leveldb), and a number of different table types.
%%
%% Feature overview:
%%
%% - Multiple logical tables per database
%%
%% - Persistent ordered-set semantics
%%
%% - `{Key, Value}' or `{Key, Attributes, Value}' structure (per-table)
%%
%% - Table types: set (normal) or queue (FIFO, LIFO or keyed FIFO or LIFO)
%%
%% - Attributes can be indexed
%%
%% - Schema-based validation (per-database) with update triggers
%%
%% - Prefix matching
%%
%% - ETS-style select() operations
%%
%% - Configurable encoding schemes (raw, sext or term_to_binary)
%%
%% @end
%% Created : 29 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(kvdb).

-behaviour(gen_server).

-export([test/0]).

-export([start/0, open_db/2, info/2]).
-export([open/2, close/1, db/1, start_session/2]).
-export([add_table/2, add_table/3, delete_table/2, list_tables/1]).
-export([put/3, put_attr/5, put_attrs/4, get/3, index_get/4,
	 push/3, push/4, pop/2, pop/3, prel_pop/2, prel_pop/3,
	 extract/3, list_queue/3, list_queue/6, is_queue_empty/3,
	 first_queue/2, next_queue/3,
	 get_attr/4, get_attrs/3, delete/3]).
-export([first/2, last/2, next/3, prev/3]).
-export([prefix_match/3, prefix_match/4]).
-export([select/3, select/4]).
-export([dump_tables/1]).

%% direct API towards an active kvdb instance
-export([do_put/3,
	 do_push/3,
	 do_push/4,
	 do_get/3,
	 do_index_get/4,
	 do_pop/2,
	 do_pop/3,
	 do_prel_pop/2,
	 do_prel_pop/3,
	 do_extract/3,
	 do_list_queue/3,
	 do_list_queue/6,
	 do_is_queue_empty/3,
	 do_first_queue/2,
	 do_next_queue/3,
	 do_get_attr/4,
	 do_get_attrs/3,
	 do_put_attr/5,
	 do_put_attrs/4,
	 do_delete/3,
	 do_add_table/3,
	 do_delete_table/2,
	 do_first/2,
	 do_next/3,
	 do_prev/3,
	 do_last/2,
	 do_prefix_match/4,
	 do_select/4,
	 do_info/2,
	 do_dump_tables/1]).

-export([behaviour_info/1]).

-export([start_link/2,
	 init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 terminate/2,
	 code_change/3]).

%% -import(kvdb_schema, [validate/3, validate_attr/3, on_update/4]).
-import(kvdb_lib, [table_name/1]).

-include("kvdb.hrl").

-export_type([db/0, table/0, int_table_name/0, queue_name/0,
	      db_ref/0, key/0, value/0, attr_name/0, attr_value/0, attrs/0,
	      object/0, options/0]).

-record(st, {name, db, is_owner = false}).

-define(KVDB_CATCH(Expr, Args),
	try Expr
	catch
	    throw:{kvdb_throw, __E} ->
		%% error(__E, Args)
		error(__E, erlang:get_stacktrace())
	end).

-define(KVDB_THROW(E), throw({kvdb_throw, E})).

%% @private
test() ->
    dbg:tracer(),
    [dbg:tpl(M, x) || M <- [kvdb, kvdb_sup, kvdb_sqlite3]],
    [dbg:tp(M, x) || M <- [gproc]],
    dbg:p(all, [c]),
    application:start(gproc),
    application:start(kvdb).

%% @private
%% The plugin behaviour
behaviour_info(callbacks) ->
    [
     {info, 2},
     {dump_tables, 1},
     {get_schema_mod, 2},
     {open,2},
     {close,1},
     {add_table,3},
     {delete_table,2},
     {put,3},
     {get,3},
     {index_get, 4},
     {push,4},
     {pop,3},
     {extract,3},
     {list_queue, 3},
     {is_queue_empty, 3},
     {first_queue, 2},
     {next_queue, 3},
     {pop,3},
     {delete,3},
     %% {iterator,2},          % may remove
     %% {iterator_close,2},    % may remove
     {first,2},
     {last,2},
     {next,3},
     {prev,3}
    ];
behaviour_info(_Other) ->
    undefined.

%% @private
start() ->
    application:start(gproc),
    application:start(kvdb).

-spec open_db(db_name(), options()) -> {ok, pid()} | {error, any()}.

%% @spec open_db(Name, Options) -> {ok, Pid} | {error, Reason}
%% @doc Opens a kvdb database instance.
%%
%% TODO: make sure that the database instance is able to remember relevant
%% options and verify that given options are compatible.
%% @end
%%
open_db(Name, Options) ->
    case gproc:where({n,l,{kvdb, Name}}) of
	undefined ->
	    Child = kvdb_sup:childspec({Name, Options}),
	    supervisor:start_child(kvdb_sup, Child);
	_ ->
	    {error, already_loaded}
    end.

-spec info(db_name(), attr_name()) -> undefined | attr_value().
info(Name, Item) ->
    ?KVDB_CATCH(do_info(db(Name), Item), [Name, Item]).

-spec do_info(db_ref(), attr_name()) -> undefined | attr_value().
do_info(#kvdb_ref{mod = DbMod, db = Db}, Item) ->
    DbMod:info(Db, Item).

-spec dump_tables(db_name()) -> list().
%% @doc Returns the contents of the database as a list of objects
%%
%% This function is mainly for debugging, and should not be called on a
%% large database.
%%
%% The exact format of the list may vary from backend to backend.
%% @end
dump_tables(Name) ->
    ?KVDB_CATCH(do_dump_tables(db(Name)), [Name]).

-spec do_dump_tables(db_ref()) -> list().
%% @doc Low-level equivalent to {@link dump_tables/1}
%% @end
do_dump_tables(#kvdb_ref{mod = DbMod, db = Db}) ->
    DbMod:dump_tables(Db).

-spec open(db_name(), Options::[{atom(),term()}]) ->
		  {ok,db_ref()} | {error,term()}.
%% @doc Opens a database
%%
%% Options:
%%
%% - `{backend, Backend}' - select a backend<br/>
%% Supported backends are Sqlite3 (`sqlite' or `sqlite3') and `leveldb',
%% or any module that implements the `kvdb' behaviour.
%%
%% - `{schema, SchemaMod}' - Callback module used for validation and triggers.
%% The module must implement the `kvdb_schema' behaviour.
%%
%% - `{file, File}' - File name or directory name of the database.
%%
%% - `{encoding, Encoding}' - Default encoding for tables.
%%
%% - `{db_opts, DbOpts}' - Backend-specific options.
%% @end
open(Name, Options) ->
    supervisor:start_child(kvdb_sup, kvdb_sup:childspec({Name, Options})).

do_open(Name, Options) when is_list(Options) ->
    DbMod = proplists:get_value(backend, Options, kvdb_sqlite3),
    case DbMod:open(Name,Options) of
	{ok, Db} ->
	    io:fwrite("opened ~p database: ~p~n", [DbMod, Options]),
	    Default = DbMod:get_schema_mod(Db, kvdb_schema),
	    Schema = proplists:get_value(schema, Options, Default),
	    {ok, #kvdb_ref{name = Name, mod = DbMod, db = Db, schema = Schema}};
	Error ->
	    io:fwrite("ERROR opening ~p database: ~p. Opts = ~p~n",
		      [DbMod, Error, Options]),
	    Error
    end.

close(#kvdb_ref{mod = DbMod, db = Db}) ->
    DbMod:close(Db);
close(Name) ->
    ?KVDB_CATCH(call(Name, close), [Name]).

-spec db(db_name() | db_ref()) -> db_ref().
%% @doc Returns a low-level handle for accessing the data via do_* functions.
%%
%% Note that not all functions are safe to use concurrently from different
%% processes. When accessing a database via Name, update functions are
%% serialized so that database corruption won't occur.
%% @end
db(#kvdb_ref{} = Db) ->
    Db;
db(Name) ->
    call(Name, db).

-spec add_table(db_name(), table()) -> ok.
%% @equiv add_table(Name, Table, [{type, set}])
%%
add_table(Name, Table) ->
    add_table(Name, Table, [{type, set}]).

-spec add_table(db_name(), table(), options()) -> ok.
%% @doc Add a table to the database
%%
%% This function assumes that the table doesn't already exist in the database.
%% Valid options are:
%%
%% - `{type, set | fifo | lifo | {keyed, fifo | lifo}'<br/>
%% This defines the type of the table. `set' signifies an ordered-set table.
%% `fifo' and `lifo' are queue table types, accessed using the functions
%% {@link push/3}, {@link pop/2}, {@link prel_pop/2}, {@link extract/3},
%% {@link delete/3}.
%%
%% `{keyed, fifo | lifo}' are also a form of queued table type, where items
%% are sorted by object key first, and then in FIFO or LIFO insertion order.
%% This can be used for e.g. priority- or timer queues.
%%
%% - `{encoding, encoding()}'<br/>
%%   `encoding() :: enc() | {enc(), enc()} | {enc(), enc(), enc()}'<br/>
%%   `enc() :: raw | sext | term'<br/>
%% Specifies how the object, or parts of the object, should be encoded.
%%
%% <ul>
%% <li>`raw' assumes that the data is of type binary; no extra encoding is
%% performed.</li>
%% <li>`term' uses `term_to_binary/1' encoding. This is generally not useful
%% for the key component, as sort order is not preserved, but is a good
%% generic choice for the value component.</li>
%% <li>`sext' uses sext-encoding
%% (<a href="http://github.com/uwiger/sext">github.com/uwiger/sext</a>), which
%% preserves the inherent sort order of erlang terms. Note that `sext'-encoding
%% is a bit more costly than term-encoding, both in time and space.</li>
%% </ul>
%% When the short forms, `sext', `raw' or `term' are used, they imply a
%% `{Key, Value}' structure. For a `{Key, Attrs, Value}' structure, use the
%% 3-tuple form, e.g. `{sext, sext, term}'. (The leveldb backend ignores the
%% encoding instruction for attrs, and encodes each attribute key with `sext'
%% encoding and each attribute value with `term' encoding).
%%
%% - `{index, [index_expr()]}'<br/>
%% `index_expr() :: atom() | {_Name::any(), each|words, _Attr::atom()}'<br/>
%% Attributes can be indexed, by naming the attribute names to include.
%% If only the attribute name is given, the attribute value is used as the index
%% value. If a tuple {IxName, Op, Attr} is given, the attribute value is
%% processed to yield a list of index values. Supported operations are:<br/>
%% <ul>
%% <li>`each' - the attribute value is a list; each list item becomes and index
%% value.</li>
%% <li>`words' - the attribute value is a string (list) or binary; each word
%% in the text becomes an index value.</li>
%% </ul>
%% @end
add_table(Name, Table, Opts) when is_list(Opts) ->
    ?KVDB_CATCH(call(Name, {add_table, Table, Opts}), [Name, Table, Opts]).

-spec do_add_table(Db::db_ref(), Table::table(), Opts::list()) ->
			  ok | {error, any()}.

%% @doc Low-level equivalent to {@link add_table/3}
%% @end
do_add_table(#kvdb_ref{mod = DbMod, db = Db}, Table0, Opts) ->
    Table = kvdb_lib:valid_table_name(Table0),
    DbMod:add_table(Db, Table, Opts).

-spec do_delete_table(Db::db_ref(), Table::table()) ->
			     ok | {error, any()}.
%% @doc low-level equivalent to {@link delete_table/2}
%% @end
do_delete_table(#kvdb_ref{mod = DbMod, db = Db}, Table0) ->
    Table = table_name(Table0),
    DbMod:delete_table(Db, Table).

%% @doc Delete `Table' from the database
%% @end
delete_table(Name, Table) ->
    ?KVDB_CATCH(call(Name, {delete_table, Table}), [Name, Table]).

-spec list_tables(db_name() | db_ref()) -> [binary()].
%% @doc Lists the tables defined in the database
%% @end
list_tables(#kvdb_ref{mod = DbMod, db = Db}) ->
    DbMod:list_tables(Db);
list_tables(Name) ->
    ?KVDB_CATCH(list_tables(db(Name)), [Name]).



-spec do_put(Db::db_ref(), Table::table(), Obj::object()) ->
		    ok | {error, any()}.
%% @doc Low-level equivalent to {@link put/3}
%% @end
do_put(#kvdb_ref{} = DbRef, Table0, {_,_} = Obj) ->
    Table = table_name(Table0),
    do_put_(DbRef, Table, Obj);
do_put(#kvdb_ref{} = DbRef, Table0, {K,As,V}) when is_list(As) ->
    Table = table_name(Table0),
    do_put_(DbRef, Table, {K, fix_attrs(As), V}).

do_put_(#kvdb_ref{mod = DbMod, db = Db, schema = Schema} = DbRef, Table, Obj) ->
    case DbMod:put(Db, Table,
		   Actual = Schema:validate(DbRef, put, Obj)) of
	ok ->
	    Schema:on_update(put, DbRef, Table, Actual),
	    ok;
	Error ->
	    Error
    end.

-spec put(any(), Table::table(), Obj::object()) ->
		 ok | {error, any()}.
%% @doc Inserts an object into Table
%% @end
put(Name, Table, Obj) when is_tuple(Obj) ->
    ?KVDB_CATCH(call(Name, {put, Table, Obj}), [Name, Table, Obj]).


-spec do_put_attr(db_ref(), Table::table(), Key::key(), atom(), any()) ->
			 ok | {error, any()}.
do_put_attr(#kvdb_ref{mod = DbMod, db = Db, schema = Schema} = DbRef,
	    Table0, Key, AttrN, Value)
  when is_atom(AttrN) ->
    Table = table_name(Table0),
    Attr = Schema:validate_attr(DbRef, Key, {AttrN, Value}),
    case DbMod:put_attr(Db, Table, Key, Attr) of
	{ok, Actual} ->
	    Schema:on_update(put_attr, DbRef, Table, {Key, Attr}),
	    {ok, Actual};
	Error ->
	    Error
    end.

-spec put_attr(db_name(), Table::table(), Key::key(), atom(), any()) ->
		      ok | {error, any()}.
put_attr(Name, Table, Key, Attr, Value) when is_atom(Attr) ->
    ?KVDB_CATCH(call(Name, {put_attr, Table, Key, Attr, Value}),
		[Name, Table, Key, Attr, Value]).


do_put_attrs(#kvdb_ref{mod = DbMod, db = Db}, Table0, Key, As) ->
    Table = table_name(Table0),
    DbMod:put_attrs(Db, Table, Key, fix_attrs(As)).

-spec put_attrs(any(), Table::table(), Key::key(), Attrs::attrs()) ->
		       ok | {error, any()}.
put_attrs(Name, Table, Key, As) when is_list(As) ->
    ?KVDB_CATCH(call(Name, {put_attrs, Table, Key, As}),
		[Name, Table, Key, As]).


-spec do_get(Db::db_ref(), Table::table(), Key::binary()) ->
		    {ok, binary()} | {error,any()}.
%% @doc Low-level equivalent of {@link get/3}
%% @end
do_get(#kvdb_ref{mod = DbMod, db = Db}, Table0, Key) ->
    Table = table_name(Table0),
    case DbMod:get(Db, Table, Key) of
	{ok, Obj} ->
	    {ok, Obj};
	{error, _} = Other ->
	    Other
    end.

-spec get(db_name(), Table::table(), Key::binary()) ->
		 {ok, object()} | {error,any()}.
%% @doc Perform a lookup on `Key' in `Table'
%%
%% Returns `{ok, Object}' or `{error, Reason}', e.g. `{error, not_found}'
%% if the object could not be found.
%% @end
get(Name, Table, Key) ->
    #kvdb_ref{} = Ref = call(Name, db),
    ?KVDB_CATCH(do_get(Ref, Table, Key), [Name, Table, Key]).

-spec do_index_get(db_ref(), table(), _IxName::any(), _IxVal::any()) ->
			  [object()] | {error, any()}.
%% @doc Low-level equivalent of {@link index_get/4}
%% @end
do_index_get(#kvdb_ref{mod = DbMod, db = Db}, Table0, IxName, IxVal) ->
    Table = table_name(Table0),
    case DbMod:index_get(Db, Table, IxName, IxVal) of
	Res when is_list(Res) -> Res
    end.

-spec index_get(db_name(), table(), _IxName::any(), _IxVal::any()) ->
		       [object()] | {error, any()}.
%% @doc Perform an index lookup on the named index of Table
%%
%% This function returns a list of objects referenced by the index value, or
%% an `{error, Reason}' tuple, if there is no such index for the Table.
%% @end
index_get(Name, Table, IxName, IxVal) ->
    #kvdb_ref{} = Ref = call(Name, db),
    ?KVDB_CATCH(do_index_get(Ref, Table, IxName, IxVal),
		[Name, Table, IxName, IxVal]).

-spec do_push(Db::db_ref(), Table::table(), Obj::object()) ->
		     {ok, ActualKey::any()} | {error, any()}.
%% @equiv do_push(Db, Table, <<>>, Obj)
%%
do_push(Db, Table, Obj) ->
    do_push(Db, Table, <<>>, Obj).

-spec do_push(Db::db_ref(), Table::table(), Q::any(), Obj::object()) ->
		     {ok, ActualKey::any()} | {error, any()}.
%% @doc Low-level equivalent of {@link push/4}
%% @end
do_push(#kvdb_ref{} = DbRef, Table0, Q, {_,_} = Obj) ->
    Table = table_name(Table0),
    do_push_(DbRef, Table, Q, Obj);
do_push(#kvdb_ref{} = DbRef, Table0, Q, {K,As,V}) when is_list(As) ->
    Table = table_name(Table0),
    do_push_(DbRef, Table, Q, {K, fix_attrs(As), V}).

do_push_(#kvdb_ref{mod = DbMod, db = Db, schema = Schema} = DbRef,
	 Table, Q, Obj) ->
    case DbMod:push(Db, Table, Q,
		    Actual = Schema:validate(DbRef, put, Obj)) of
	{ok, ActualKey} ->
	    Schema:on_update({push,Q}, DbRef, Table, Actual),
	    {ok, ActualKey};
	Error ->
	    Error
    end.

-spec push(db_name(), table(), object()) ->
		 {ok, _ActualKey::any()} | {error, any()}.
%% @equiv push(Name, Table, <<>>, Obj)
%%
push(Name, Table, Obj) when is_tuple(Obj) ->
    push(Name, Table, <<>>, Obj).

-spec push(any(), Table::table(), queue_name(), object()) ->
		 {ok, _ActualKey::any()} | {error, any()}.
%% @doc Push an object onto a persistent queue
%%
%% `Table' must be of one of the queue types (see {@link create_table/3}).
%% The queue identifier `Q' specifies a given queue instance inside the table
%% (there may be a large number of queue instances), and a special key is
%% created to uniquely identify the inserted object. The actual key must be
%% used to delete the object (unless it is automatically removed using the
%% {@link pop/3} function.
%% @end
push(Name, Table, Q, Obj) when is_tuple(Obj) ->
    ?KVDB_CATCH(call(Name, {push, Table, Q, Obj}), [Name, Table, Q, Obj]).


-spec do_pop(db_ref(), table()) ->
		    {ok, object()} | done | {error,any()}.
%% @equiv do_pop(Db, Table, <<>>)
%%
do_pop(Db, Table) ->
    do_pop(Db, Table, <<>>).

-spec do_pop(Db::db_ref(), Table::table(), queue_name()) ->
		    {ok, object()} |
		    done |
		    blocked |
		    {error,any()}.
%% @doc Low-level equivalent of {@link pop/3}
%% @end
do_pop(#kvdb_ref{mod = DbMod, db = Db, schema = Schema} = DbRef, Table0, Q) ->
    Table = table_name(Table0),
    case DbMod:pop(Db, Table, Q) of
	{ok, Obj, IsEmpty} ->
	    Schema:on_update({pop,Q,IsEmpty}, DbRef, Table, Obj),
	    {ok, Obj};
	blocked -> blocked;
	done    -> done
    end.

-spec pop(db_name(), Table::table()) ->
		 {ok, object()} | done | blocked | {error,any()}.
%% @equiv pop(Name, Table, <<>>)
%%
pop(Name, Table) ->
    pop(Name, Table, <<>>).

-spec pop(db_name(), Table::table(), queue_name()) ->
		 {ok, object()} |
		 done |
		 blocked |
		 {error,any()}.
%% @doc Fetches and deletes the 'first' object in the given queue
pop(Name, Table, Q) ->
    ?KVDB_CATCH(call(Name, {pop, Table, Q}), [Name, Table, Q]).

-spec do_prel_pop(Db::db_ref(), Table::table()) ->
			 {ok, object(), binary()} |
			 done |
			 blocked |
			 {error,any()}.

do_prel_pop(Db, Table) ->
    do_prel_pop(Db, Table, <<>>).

-spec do_prel_pop(Db::db_ref(), Table::table(), queue_name()) ->
			 {ok, object(), binary()} |
			 done |
			 blocked |
			 {error,any()}.

do_prel_pop(#kvdb_ref{mod = DbMod, db = Db, schema = Schema} = DbRef,
	    Table0, Q) ->
    Table = table_name(Table0),
    case DbMod:prel_pop(Db, Table, Q) of
	{ok, Obj, RealKey, IsEmpty} ->
	    Schema:on_update({pop,Q,IsEmpty}, DbRef, Table, Obj),
	    {ok, Obj, RealKey};
	blocked -> blocked;
	done    -> done
    end.

-spec prel_pop(db_name(), Table::table()) ->
		      {ok, object(), binary()} | done | {error,any()}.
prel_pop(Name, Table) ->
    prel_pop(Name, Table, <<>>).

-spec prel_pop(db_name(), Table::table(), queue_name()) ->
		      {ok, object(), binary()} | done | {error,any()}.
prel_pop(Name, Table, Q) ->
    ?KVDB_CATCH(call(Name, {prel_pop, Table, Q}), [Name, Table, Q]).

-spec extract(db_name(), Table::table(), Key::binary()) ->
		 {ok, object()} | {error,any()}.

extract(Name, Table, Key) ->
    ?KVDB_CATCH(call(Name, {extract, Table, Key}), [Name, Table, Key]).

-spec do_extract(#kvdb_ref{}, Table::table(), Key::binary()) ->
			{ok, object()} | {error,any()}.
do_extract(#kvdb_ref{mod = DbMod,
		     db = Db,
		     schema = Schema} = DbRef, Table0, Key) ->
    Table = table_name(Table0),
    case DbMod:extract(Db, Table, Key) of
	{ok, Obj, Q, IsEmpty} ->
	    Schema:on_update({pop,Q,IsEmpty}, DbRef, Table, Obj),
	    {ok, Obj};
	Other ->
	    Other
    end.


-spec list_queue(db_name(), Table::table(), Q::queue_name()) ->
			[object()] | {error,any()}.

list_queue(Name, Table, Q) ->
    #kvdb_ref{} = Ref = call(Name, db),
    ?KVDB_CATCH(do_list_queue(Ref, Table, Q), [Name, Table, Q]).

list_queue(Name, Table, Q, Fltr, Inactive, Limit) ->
    #kvdb_ref{} = Ref = call(Name, db),
    ?KVDB_CATCH(do_list_queue(Ref, Table, Q, Fltr, Inactive, Limit),
		[Name, Table, Q, Fltr, Inactive, Limit]).

-spec do_list_queue(#kvdb_ref{}, Table::table(), Q::queue_name()) ->
			   [object()] | {error,any()}.
do_list_queue(#kvdb_ref{mod = DbMod, db = Db}, Table0, Q) ->
    Table = table_name(Table0),
    DbMod:list_queue(Db, Table, Q).

-spec do_list_queue(#kvdb_ref{}, Table::table(), Q::queue_name(),
		    _Fltr :: fun((active|inactive, tuple()) ->
					keep | keep_raw | skip | tuple()),
		    _Inactive :: boolean(), _Limit :: integer() | infinity) ->
			   [object()] | {error,any()}.
do_list_queue(#kvdb_ref{mod = DbMod, db = Db}, Table0, Q,
	      Fltr, Inactive, Limit) ->
    Table = table_name(Table0),
    DbMod:list_queue(Db, Table, Q, Fltr, Inactive, Limit).

-spec is_queue_empty(db_name(), table(), _Q::queue_name()) -> boolean().

is_queue_empty(Name, Table, Q) ->
    #kvdb_ref{} = Ref = call(Name, db),
    ?KVDB_CATCH(do_is_queue_empty(Ref, Table, Q), [Name, Table, Q]).

-spec do_is_queue_empty(#kvdb_ref{}, table(), _Q::queue_name()) -> boolean().
do_is_queue_empty(#kvdb_ref{mod = DbMod, db = Db}, Table0, Q) ->
    DbMod:is_queue_empty(Db, table_name(Table0), Q).

-spec first_queue(db_name(), table()) -> {ok, queue_name()} | done.
first_queue(Name, Table) ->
    #kvdb_ref{} = Ref = call(Name, db),
    ?KVDB_CATCH(do_first_queue(Ref, Table), [Name, Table]).

-spec do_first_queue(#kvdb_ref{}, table()) -> {ok, queue_name()} | done.
do_first_queue(#kvdb_ref{mod = DbMod, db = Db}, Table0) ->
    Table = table_name(Table0),
    DbMod:first_queue(Db, Table).

-spec next_queue(db_name(), table(), _Q::queue_name()) -> {ok, any()} | done.
next_queue(Name, Table, Q) ->
    #kvdb_ref{} = Ref = call(Name, db),
    ?KVDB_CATCH(do_next_queue(Ref, Table, Q), [Name, Table, Q]).

-spec do_next_queue(#kvdb_ref{}, table(), _Q::queue_name()) ->
			   {ok, any()} | done.
do_next_queue(#kvdb_ref{mod = DbMod, db = Db}, Table0, Q) ->
    Table = table_name(Table0),
    DbMod:next_queue(Db, Table, Q).

do_get_attr(#kvdb_ref{mod = DbMod, db = Db}, Table0, Key, Attr)
 when is_atom(Attr) ->
    Table = table_name(Table0),
    DbMod:get_attr(Db, Table, Key, Attr).

get_attr(Name, Table, Key, Attr) when is_atom(Attr) ->
    ?KVDB_CATCH(do_get_attr(db(Name), Table, Key, Attr),
		[Name, Table, Key, Attr]).


do_get_attrs(#kvdb_ref{mod = DbMod, db = Db}, Table0, Key) ->
    Table = table_name(Table0),
    DbMod:get_attrs(Db, Table, Key).

get_attrs(Name, Table, Key) ->
    ?KVDB_CATCH(do_get_attrs(db(Name), Table, Key), [Name, Table, Key]).


-spec do_delete(Db::db_ref(), Table::table(), Key::binary()) ->
		       ok | {error, any()}.

do_delete(#kvdb_ref{mod = DbMod, db = Db}, Table0, Key) ->
    Table = table_name(Table0),
    DbMod:delete(Db, Table, Key).

delete(Name, Table, Key) ->
    ?KVDB_CATCH(call(Name, {delete, Table, Key}), [Name, Table, Key]).

-spec do_first(Db::db_ref(), Table::table()) ->
		      {ok,Key::binary()} |
		      {ok,Key::binary(),Value::binary()} |
		      done |
		      {error,any()}.

do_first(#kvdb_ref{mod = DbMod, db = Db}, Table0) ->
    Table = table_name(Table0),
    DbMod:first(Db, Table).

first(Name, Table) ->
    ?KVDB_CATCH(do_first(db(Name), Table), [Name, Table]).


-spec do_last(Db::db_ref(), Table::table()) ->
		     {ok,Key::binary()} |
		     {ok,Key::binary(),Value::binary()} |
		     done |
		     {error,any()}.

do_last(#kvdb_ref{mod = DbMod, db = Db}, Table0) ->
    Table = table_name(Table0),
    DbMod:last(Db, Table).

last(Name, Table) ->
    ?KVDB_CATCH(do_last(db(Name), Table), [Name, Table]).

-spec do_next(Db::db_ref(), Table::table(), FromKey::binary()) ->
		     {ok,Key::binary()} |
		     {ok,Key::binary(),Value::binary()} |
		     done |
		     {error,any()}.

do_next(#kvdb_ref{mod = DbMod, db = Db}, Table0, Key) ->
    Table = table_name(Table0),
    DbMod:next(Db, Table, Key).

next(Name, Table, Key) ->
    ?KVDB_CATCH(do_next(db(Name), Table, Key), [Name, Table, Key]).


-spec do_prev(Db::db_ref(), Table::table(), FromKey::binary()) ->
		     {ok,Key::binary()} |
		     {ok,Key::binary(),Value::binary()} |
		     done |
		     {error,any()}.

do_prev(#kvdb_ref{mod = DbMod, db = Db}, Table0, Key) ->
    Table = table_name(Table0),
    DbMod:prev(Db, Table, Key).

prev(Name, Table, Key) ->
    ?KVDB_CATCH(do_prev(db(Name), Table, Key), [Name, Table, Key]).


prefix_match(Db, Table, Prefix) ->
    ?KVDB_CATCH(do_prefix_match(db(Db), Table, Prefix, default_limit()),
		[Db, Table, Prefix]).

prefix_match(Db, Table, Prefix, Limit)
  when Limit==infinity orelse (is_integer(Limit) andalso Limit >= 0) ->
    ?KVDB_CATCH(do_prefix_match(db(Db), Table, Prefix, Limit),
		[Db, Table, Prefix, Limit]).

do_prefix_match(#kvdb_ref{mod = DbMod, db = Db}, Table0, Prefix, Limit)
  when Limit==infinity orelse (is_integer(Limit) andalso Limit >= 0) ->
    Table = table_name(Table0),
    DbMod:prefix_match(Db, Table, Prefix, Limit).

default_limit() ->
    100.

%% @spec select(Db, Table, MatchSpec) -> {Objects, Cont} | done
%% @doc Similar to ets:select/3.
%%
%% This function builds on prefix_match/3, and applies a match specification
%% on the results. If keys are using `raw' encoding, a partial key can be
%% given using string syntax, e.g. <code>"abc" ++ '_'</code>. Note that this
%% will necessitate some data conversion back and forth on the found objects.
%% If a prefix cannot be determined for the key, a full traversal of the table
%% will be performed. `sext'-encoded keys can be prefixed in the same way as
%% normal erlang terms in an ets:select().
%% @end
%%
select(Db, Table, MatchSpec) ->
    ?KVDB_CATCH(do_select(db(Db), Table, MatchSpec, default_limit()),
		[Db, Table, MatchSpec]).

select(Db, Table, MatchSpec, Limit) ->
    ?KVDB_CATCH(do_select(db(Db), Table, MatchSpec, Limit),
		[Db, Table, MatchSpec, Limit]).

do_select(#kvdb_ref{mod = DbMod, db = Db}, Table0, MatchSpec, Limit) ->
    Table = table_name(Table0),
    MSC = ets:match_spec_compile(MatchSpec),
    Encoding = DbMod:info(Db, encoding),
    {Prefix, Conv} = ms2pfx(MatchSpec, Encoding),
    do_select_(DbMod:prefix_match(Db,Table,Prefix,Limit),
	       Conv, MSC, [], Limit, Limit).

%% We must create a prefix for the prefix_match().
%% This is a problem if we have raw encoding on the key, since you cannot have
%% a wildcard tail on a binary. You can do this on a list, however, so we allow
%% the caller to provide a string pattern on the key - enabling the declaration
%% of a prefix like "foo" ++ '_'.
%%
%% Unfortunately, this conflicts with match_spec_run(): we must convert the
%% results from prefix_match(), changing from binaries to lists, then revert
%% back to binaries on the objects that match. This is wasteful, but presumably
%% faster than setting the prefix to <<>> (the empty binary), forcing select()
%% to traverse the entire table.
%%
ms2pfx([{HeadPat,_,_}|_], Enc) when is_tuple(HeadPat) ->
    Key = element(1, HeadPat),
    case key_encoding(Enc) of
	sext -> {Key, none};
	raw ->
	    raw_prefix(Key, size(HeadPat))
    end;
ms2pfx(_, _) ->
    {<<>>, none}.

raw_prefix(A, _) when is_atom(A) -> {<<>>, none};
raw_prefix(B, _) when is_binary(B) -> {<<>>, none};
raw_prefix(L, Sz) when is_list(L) ->
    P = list_to_binary(raw_list_prefix(L)),
    case Sz of
	2 -> {P, {fun({K,V}) -> {binary_to_list(K), V} end,
		  fun({K,V}) -> {list_to_binary(K), V} end}};
	3 -> {P, {fun({K,A,V}) -> {binary_to_list(K), A, V} end,
		  fun({K,A,V}) -> {list_to_binary(K), A, V} end}}
    end.

raw_list_prefix([H|T]) when is_atom(T) andalso (0 =< H andalso H =< 255) ->
    %% e.g. [...|'_']
    [H];
raw_list_prefix([H|T]) when 0 =< H, H =< 255 ->
    [H|raw_list_prefix(T)].

convert(none, Objs) ->
    Objs;
convert({F,_}, Objs) ->
    [F(Obj) || Obj <- Objs].

revert(none, Objs) ->
    Objs;
revert({_,F}, Objs) ->
    [F(Obj) || Obj <- Objs].

key_encoding(E) when is_tuple(E) ->
    element(1, E);
key_encoding(E) when is_atom(E) ->
    E.


do_select_(done, _, _, Acc, _, _) ->
    {lists:concat(lists:reverse(Acc)), fun() -> done end};
do_select_({Objs, Cont}, Conv, MSC, Acc, Limit, Limit0) ->
    Matches = revert(Conv, ets:match_spec_run(convert(Conv, Objs), MSC)),
    N = length(Matches),
    NewAcc = [Matches | Acc],
    case decr(Limit, N) of
	NewLimit when NewLimit =< 0 ->
	    %% This can result in (> Limit) objects being returned to the caller
	    {lists:concat(lists:reverse(NewAcc)),
	     fun() ->
		     do_select_(Cont(), Conv, MSC, NewAcc, Limit0, Limit0)
	     end};
	NewLimit when NewLimit > 0 ->
	    do_select_(Cont(), Conv, MSC, NewAcc, NewLimit, Limit0)
    end.

decr(infinity,_) ->
    infinity;
decr(Limit, N) when is_integer(Limit), is_integer(N) ->
    Limit - N.

%% server-related code

call(Name, Req) ->
    Pid = case Name of
	      #kvdb_ref{name = N} ->
		  gproc:where({n, l, {kvdb, N}});
	      P when is_pid(P) ->
		  P;
	      _ ->
		  gproc:where({n,l,{kvdb,Name}})
	  end,
    case gen_server:call(Pid, Req) of
	badarg ->
	    ?KVDB_THROW(badarg);
	{badarg,_} = Err ->
	    ?KVDB_THROW(Err);
	Res ->
	    Res
    end.

start_link(Name, Backend) ->
    io:fwrite("starting ~p, ~p~n", [Name, Backend]),
    gen_server:start_link(?MODULE, {owner, Name, Backend}, []).

start_session(Name, Id) ->
    gen_server:start_link(?MODULE, session(Name, Id), []).

session(Name, Id) ->
    {Name, session, Id}.

%% @private
init(Alias) ->
    try init_(Alias)
    catch
	error:Reason ->
	    Trace = erlang:get_stacktrace(),
	    error_logger:error_report([{error_opening_kvdb_db, Alias},
				       {error, Reason},
				       {stacktrace, Trace}]),
	    error({Reason, Trace}, [Alias])
    end.

init_({Name, session, _Id} = Alias) ->
    Db = db(Name),
    gproc:reg({p, l, {kvdb, session}}, Alias),
    gproc:reg({n, l, {kvdb, Alias}}),
    {ok, #st{db = Db}};
init_({owner, Name, Opts}) ->
    Backend = proplists:get_value(backend, Opts, ets),
    gproc:reg({n, l, {kvdb,Name}}, Backend),
    DbMod = mod(Backend),
    F = name2file(Name),
    File = case proplists:get_value(file, Opts) of
	       undefined ->
		   {ok, CWD} = file:get_cwd(),
		   filename:join(CWD, F);
	       F1 ->
		   F1
	   end,
    ok = filelib:ensure_dir(File),
    NewOpts = lists:keystore(backend, 1,
			     lists:keystore(file, 1, Opts, {file, File}),
			     {backend, DbMod}),
    case do_open(Name, NewOpts) of
	{ok, Db} ->
	    create_tables_(Db, Opts),
	    {ok, #st{name = Name, db = Db, is_owner = true}};
	{error,_} = Error ->
	    io:fwrite("error opening kvdb database ~w:~n"
		      "Error: ~p~n"
		      "Opts = ~p~n", [Name, Error, NewOpts]),
	    Error
    end.

%% @private
handle_call(Req, From, St) ->
    try handle_call_(Req, From, St)
    catch
	error:badarg ->
	    {reply, {badarg, erlang:get_stacktrace()}, St};
	error:E ->
	    {reply, {badarg,[E, erlang:get_stacktrace()]}, St}
    end.

handle_call_({put, Tab, Obj}, _From, #st{db = Db} = St) ->
    {reply, do_put(Db, Tab, Obj), St};
handle_call_({push, Tab, Q, Obj}, _From, #st{db = Db} = St) ->
    {reply, do_push(Db, Tab, Q, Obj), St};
handle_call_({pop, Tab, Q}, _From, #st{db = Db} = St) ->
    {reply, do_pop(Db, Tab, Q), St};
handle_call_({prel_pop, Tab, Q}, _From, #st{db = Db} = St) ->
    {reply, do_prel_pop(Db, Tab, Q), St};
handle_call_({extract, Tab, Key}, _From, #st{db = Db} = St) ->
    {reply, do_extract(Db, Tab, Key), St};
handle_call_({put_attr, Table, Key, Attr, Value}, _From, #st{db = Db} = St) ->
    {reply, do_put_attr(Db, Table, Key, Attr, Value), St};
handle_call_({put_attrs, Tab, Key, As}, _From, #st{db = Db} = St) ->
    {reply, do_put_attrs(Db, Tab, Key, As), St};
handle_call_({delete, Tab, Key}, _From, #st{db = Db} = St) ->
    {reply, do_delete(Db, Tab, Key), St};
handle_call_({add_table, Table, Opts}, _From, #st{db = Db} = St) ->
    io:fwrite("adding table ~p~n", [Table]),
    {reply, do_add_table(Db, Table, Opts), St};
handle_call_({delete_table, Table}, _From, #st{db = Db} = St) ->
    io:fwrite("deleting table ~p~n", [Table]),
    {reply, do_delete_table(Db, Table), St};
handle_call_(close, _From, #st{is_owner = true} = St) ->
    {stop, normal, ok, St};
handle_call_(db, _From, #st{db = Db} = St) ->
    {reply, Db, St}.

%% @private
handle_info(_, St) ->
    {noreply, St}.

%% @private
handle_cast(_, St) ->
    {noreply, St}.

%% @private
terminate(_Reason, #st{db = Db}) ->
    close(Db),
    ok.

%% @private
code_change(_FromVsn, St, _Extra) ->
    {ok, St}.

mod(mnesia) -> kvdb_mnesia;
mod(leveldb) -> kvdb_leveldb;
mod(sqlite3) -> kvdb_sqlite3;
mod(sqlite) -> kvdb_sqlite3;
mod(M) ->
    case is_behaviour(M) of
	true ->
	    M;
	false ->
	    error(illegal_backend_type)
    end.

name2file(X) ->
    kvdb_lib:good_string(X).



%% to_atom(A) when is_atom(A) ->
%%     A;
%% to_atom(S) when is_list(S) ->
%%     list_to_atom(S).


is_behaviour(_M) ->
    %% TODO: check that exported functions match those listed in
    %% behaviour_info(callbacks).
    true.

create_tables_(Db, Opts) ->
    case proplists:get_value(tables, Opts, []) of
	[] ->
	    ok;
	Ts ->
	    Tabs0 = lists:map(fun({T,Os}) ->
				      {table_name(T), Os};
				 (T) -> {table_name(T),[]}
			      end, Ts),
	    %% We don't warn if there are more tables than we've specified,
	    %% and we certainly don't remove them. Ok to do nothing?
	    Tables = internal_tables() ++ Tabs0,
	    Existing = list_tables(Db),
	    New = lists:filter(fun({T,_}) ->
				       not lists:member(T, Existing) end,
			       Tables),
	    [do_add_table(Db, T, Os) || {T, Os} <- New]
    end.

internal_tables() ->
    [].

fix_attrs(As) ->
    %% Treat the list of attributes as a proplist. This means there can be
    %% duplicates. Return an orddict, where values from the head of the list
    %% take priority over values from tail.
    lists:foldr(fun({K,V}, Acc) when is_atom(K) ->
			orddict:store(K, V, Acc)
		end, orddict:new(), As).

