%%%---- BEGIN COPYRIGHT -------------------------------------------------------
%%%
%%% Copyright (C) 2012 Feuerlabs, Inc. All rights reserved.
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at http://mozilla.org/MPL/2.0/.
%%%
%%%---- END COPYRIGHT ---------------------------------------------------------
%%% @author Ulf Wiger <ulf@feuerlabs.com>
-module(kvdb_trans_tests).

-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").

-define(_t(E), {timeout,60000,
		[?_test(try E catch error:_R_ ->
				      error({_R_, erlang:get_stacktrace()})
			      end)]}).

-define(tab, iolist_to_binary([<<"t_">>, integer_to_list(?LINE)])).

-define(dbg(E),
	(fun() ->
		 try (E) of
		     __V ->
			 ?debugFmt(<<"~s = ~P">>, [(??E), __V, 15]),
			 __V
		 catch
		     error:__Err ->
			 io:fwrite(user,
				   "FAIL: test = ~s~n"
				   "Error = ~p~n"
				   "Trace = ~p~n", [(??E), __Err,
						    erlang:get_stacktrace()]),
			 error(__Err)
		 end
	  end)()).


-define(trace(Mods, Expr), begin dbg:tracer(),
				 lists:foreach(
				   fun(_M_) when is_atom(_M_) ->
					   dbg:tpl(_M_,x);
				      ({_M_,_F_}) ->
					   dbg:tpl(_M_,_F_,x)
				   end, Mods),
				 dbg:p(all,[c]),
				 try Expr
				 after
				     lists:foreach(
				       fun(_M_) when is_atom(_M_) ->
					       dbg:ctpl(_M_);
					  ({_M_,_F_}) ->
					       dbg:ctpl(_M_,_F_)
				       end, Mods),
				     dbg:stop()
				 end
			   end).
fill_test_() ->
    {setup,
     fun() ->
	     ?debugVal(application:start(gproc)),
	     ?debugVal(application:start(kvdb)),
	     ok
     end,
     fun(_) ->
	     ?debugVal(application:stop(kvdb)),
	     ?debugVal(application:stop(gproc))
     end,
     {foreachx,
      fun({N,Opts,D}) ->
	      delete_files(Opts),
	      open_db(N, Opts, D)
      end,
      [{{N,Opts,D}, fun(_, Db) ->
			    [?_t(?dbg(fill_db(N, Db, Opts, D)))
			     , ?_t(?dbg(add_tab_index_get(N)))
			     , ?_t(?dbg(write_del_write(N)))
			     , ?_t(?dbg(update_counter(N)))
			     , ?_t(?dbg(first_next(N)))
			     , ?_t(?dbg(get_attrs(N)))
			     , ?_t(?dbg(q(N)))
			     , ?_t(?dbg(q_push_pop(N)))
			     , ?_t(?dbg(q_push_prel_pop(N)))
			     , ?_t(?dbg(q_extract(N)))
			     , ?_t(?dbg(q_mark_blocking(N)))
			     , ?_t(?dbg(q_mark_inactive(N)))
			     , ?_t(?dbg(index_get(N)))
			     , ?_t(?dbg(index_keys(N)))
			     , ?_t(?dbg(prefix_match(N)))
			     , ?_t(?dbg(prefix_match_rel(N)))
			     , ?_t(?dbg(no_lingering_monitors(N)))
			    ]
		    end} ||
	  {N,Opts,D} <- [new_opts(foo_10, 10)]]
      }}.


delete_files(_Opts) -> ok.
    %% {_, Dir} = lists:keyfind(log_dir, 1, Opts),
    %% {_, File} = lists:keyfind(file, 1, Opts),
    %% ?debugVal({os:cmd("rm -r " ++ Dir),
    %% 	       file:delete(File)}).

open_db(N, Opts, D) ->
    {ok, Db} = kvdb:open(N, [{log_dir, filename:join(D, "kvdb.log")},
			     {file, filename:join(D, "kvdb.tab")}
			     | Opts]),
    Db.

new_opts(Name, N) ->
    {Name, [{backend, ets},
	    {log_threshold, [{writes,N}]}], dirname(Name)}.

dirname(Name) ->
    {_,S,U} = erlang:now(),
    filename:join("/tmp", atom_to_list(Name)
		  ++ "." ++ integer_to_list(S) ++ "." ++ integer_to_list(U)).


fill_db(Name, _Db, Opts, D) ->
    %% Numbers are set pretty low right now to speed things up.
    %% The risks are: (1) sleep is set too low so that log switch doesn't
    %% occur within the batch, and (2) the number of writes is too low - really
    %% at *least* 2-3 log switches should take place before we end the test.
    ?assertMatch(ok, kvdb:add_table(Name, t, [{encoding,sext}])),
    Objs = [{N,a} || N <- lists:seq(1,30)],
    lists:foreach(
      fun(Obj) ->
	      timer:sleep(30),
	      kvdb:put(Name, t, Obj)
      end, Objs),
    ?debugFmt("closing ~p...~n", [Name]),
    kvdb:close(Name),
    ?debugFmt("DB closed. Trying to reopen...~n", []),
    timer:sleep(500),
    open_db(Name, Opts, D),
    Found = kvdb:prefix_match(Name, t, '_', infinity),
    %% io:fwrite(user, "Objs = ~p~n", [Objs]),
    ?assertMatch({Objs, _}, Found).

add_tab_index_get(Name) ->
    T1 = ?tab,
    kvdb:in_transaction(
      Name,
      fun(_) ->
	      ok = kvdb:add_table(Name, T1, [{type,set},
					     {encoding, {sext,term,term}},
					     {index, [a]}]),
	      [] = kvdb:index_get(Name, T1, a, v1),
	      [] = kvdb:index_keys(Name, T1, a, v1),
	      ok = kvdb:put(Name, T1, {a, [{a, v1}], 1}),
	      ok = kvdb:put(Name, T1, {b, [{a, v1}], 2}),
	      [{a,[{a,v1}],1},{b,[{a,v1}],2}] = kvdb:index_get(Name, T1, a, v1),
	      [a, b] = kvdb:index_keys(Name, T1, a, v1),
	      ok
      end).

write_del_write(Name) ->
    T1 = ?tab,
    write_del_write(Name, T1).

write_del_write(Name, T1) ->
    ok = kvdb:add_table(Name, T1, [{type,set},
				   {encoding, {sext,term,sext}}]),
    ok = kvdb:put(Name, T1, {x, [], 1}),
    kvdb:in_transaction(
      Name,
      fun(_) ->
	      ok = kvdb:delete(Name, T1, x),
	      ok = kvdb:put(Name, T1, {x,[],1}),
	      {ok, {x,[],1}} = kvdb:get(Name, T1, x)
      end),
    {ok, {x,[],1}} = kvdb:get(Name, T1,x),
    ok.

update_counter(Name) ->
    T1 = ?tab,
    T2 = ?tab,
    ok = kvdb:add_table(Name, T1, [{type, set},
				  {encoding, sext}]),
    ok = kvdb:add_table(Name, T2, [{type, set},
				  {encoding, raw}]),
    ok = kvdb:put(Name, T1, {c, 1}),
    ok = kvdb:put(Name, T2, {<<"c">>, <<1>>}),
    Res1 = kvdb_trans:run(
	     Name,
	     fun(_) ->
		     R1 = kvdb:update_counter(Name, T1, c, 1),
		     R2 = kvdb:update_counter(Name, T1, c, 1),
		     R3 = kvdb:update_counter(Name, T2, <<"c">>, 1),
		     R4 = kvdb:update_counter(Name, T2, <<"c">>, 1),
		     [R1,R2,R3,R4]
	     end),
    ?assertMatch([2,3,<<2>>,<<3>>], Res1),
    ok = kvdb:delete_table(Name, T1),
    ok = kvdb:delete_table(Name, T2).

first_next(Name) ->
    T1 = ?tab,
    T2 = ?tab,
    T3 = ?tab,
    [ok,ok,ok] =
	[kvdb:add_table(Name, T, [{type,set},{encoding,sext}]) ||
	    T <- [T1,T2,T3]],
    [kvdb:put(Name, T, Obj) || {T, Obj} <- [{T1, {t11,a}},
					    {T2, {t21,a}},
					    {T2, {t22,a}},
					    {T3, {t31,a}}]],
    Res = kvdb_trans:run(
	    Name,
	    fun(_) ->
		    {ok,{t21,a}} = kvdb:first(Name, T2),
		    {ok,{t22,a}} = kvdb:next(Name, T2, t21),
		    {ok,{t21,a}} = kvdb:prev(Name, T2, t22),
		    {ok,{t22,a}} = kvdb:last(Name, T2),
		    done = kvdb:next(Name, T2, t22),
		    done = kvdb:prev(Name, T2, t21)
	    end),
    [ok,ok,ok] =
	[kvdb:delete_table(Name, T) || T <- [T1,T2,T3]],
    ok.

get_attrs(Name) ->
    T1 = ?tab,
    T2 = ?tab,
    ok = kvdb:add_table(Name, T1, [{encoding,{raw,sext,term}}]),
    ok = kvdb:add_table(Name, T2, [{encoding,{sext,sext,term}}]),
    As = [{a,1}, {b,2}, {c,3}],
    ok = kvdb:put(Name, T1,{<<"a">>,As,1}),
    ok = kvdb:put(Name, T2,{a,As,1}),
    kvdb:transaction(
      Name,
      fun(_) ->
	      {ok, [{a,1},{b,2}]} = kvdb:get_attrs(Name,T1,<<"a">>,[a,b]),
	      {ok, [{a,1},{b,2}]} = kvdb:get_attrs(Name,T2,a,[a,b]),
	      {ok, [{a,1},{b,2},{c,3}]} =
		  kvdb:get_attrs(Name,T1,<<"a">>,all),
	      {ok, [{a,1},{b,2},{c,3}]} =
		  kvdb:get_attrs(Name,T2,a,all),
	      ok = kvdb:put(Name, T1, {<<"a">>,[{a,10}],1}),
	      ok = kvdb:put(Name, T2, {a,[{a,10}],1}),
	      {ok, [{a,10}]} = kvdb:get_attrs(Name,T1,<<"a">>,[a,b]),
	      {ok, [{a,10}]} = kvdb:get_attrs(Name,T2,a,[a,b])
      end),
    ok = kvdb:delete_table(Name, T1),
    ok = kvdb:delete_table(Name, T2).


q(Name) ->
    T = ?tab,
    ok = kvdb:add_table(Name, T, [{type, fifo}, {encoding, sext}]),
    kvdb:push(Name, T, <<>>, {1,a}),
    kvdb:push(Name, T, <<>>, {2,b}),
    Res1 = kvdb_trans:run(
	     Name, fun(_) ->
			   kvdb:list_queue(Name, T, <<>>)
		   end),
    ?assertMatch({[{1,a},{2,b}], _}, Res1),
    kvdb_trans:run(
      Name, fun(_) ->
		    kvdb:push(Name, T, <<>>, {3,c}),
		    kvdb:push(Name, T, <<>>, {4,d})
	    end),
    Res2 = kvdb_trans:run(
	     Name, fun(_) ->
			   kvdb:list_queue(Name, T, <<>>)
		   end),
    ?assertMatch({[{1,a},{2,b},{3,c},{4,d}], _}, Res2),
    ok = kvdb:delete_table(Name, T).

q_push_pop(Name) ->
    T = ?tab,
    ok = kvdb:add_table(Name, T, [{type, fifo}, {encoding, sext}]),
    kvdb:push(Name, T, q, {1,a}),
    kvdb:push(Name, T, q, {2,b}),
    Res1 = kvdb_trans:run(
	     Name, fun(_) ->
			   kvdb:pop(Name, T, q)
		   end),
    ?assertMatch({ok, {1,a}}, Res1),
    ok = kvdb:delete_table(Name, T).

q_push_prel_pop(Name) ->
    T = ?tab,
    ok = kvdb:add_table(Name, T, [{type, fifo}, {encoding, sext}]),
    {ok, QKey1} = kvdb:push(Name, T, q, {1,a}),
    kvdb:push(Name, T, q, {2,b}),
    Res1 = kvdb_trans:run(
	     Name, fun(_) ->
			   ?assertMatch({ok,{1,a},QKey1},
					kvdb:prel_pop(Name, T, q)),
			   kvdb:pop(Name, T, q)
		   end),
    ?assertMatch(blocked, Res1),
    ok = kvdb:delete_table(Name, T).

q_extract(Name) ->
    T = ?tab,
    ok = kvdb:add_table(Name, T, [{type, fifo}, {encoding, sext}]),
    {ok, QKey} = kvdb:push(Name, T, q, {1,a}),
    kvdb:push(Name, T, q, {2,b}),
    Res1 = kvdb_trans:run(
	     Name, fun(_) ->
			   ?assertMatch({ok, {1,a}},
					kvdb:extract(Name, T, QKey)),
			   kvdb:pop(Name, T, q)
		   end),
    ?assertMatch({ok, {2,b}}, Res1),
    ok = kvdb:delete_table(Name, T).

q_mark_blocking(Name) ->
    T = ?tab,
    ok = kvdb:add_table(Name, T, [{type, fifo}, {encoding, sext}]),
    {ok, QK1} = kvdb:push(Name, T, q, {1,a}),
    Res1 =
	kvdb_trans:run(
	  Name, fun(DbT) ->
			kvdb:mark_queue_object(Name, T, QK1, blocking),
			%% io:fwrite(user, "Tstore = ~p~n",
			%% 	  [kvdb_trans:tstore_to_list(DbT)]),
			kvdb:pop(Name, T, q)
		end),
    ?assertMatch(blocked, Res1),
    Res2 = kvdb:pop(Name, T, q),
    ?assertMatch(blocked, Res2),
    ok = kvdb:delete_table(Name, T).

q_mark_inactive(Name) ->
    T = ?tab,
    ok = kvdb:add_table(Name, T, [{type, fifo}, {encoding, sext}]),
    {ok, QK1} = kvdb:push(Name, T, q, {1,a}),
    {ok, _} = kvdb:push(Name, T, q, {2,b}),
    Res1 =
	kvdb_trans:run(
	  Name, fun(DbT) ->
			kvdb:mark_queue_object(Name, T, QK1, inactive),
			kvdb:pop(Name, T, q)
		end),
    ?assertMatch({ok,{2,b}}, Res1),
    Res2 = kvdb:pop(Name, T, q),
    ?assertMatch(done, Res2),
    ok = kvdb:delete_table(Name, T).

index_get(Name) ->
    T = ?tab,
    ok = kvdb:add_table(Name, T, [{type, set},
				  {encoding, {sext,sext,sext}},
				  {index, [a]}]),
    ok = kvdb:put(Name, T, {1, [{a, 1}], a}),
    ok = kvdb:put(Name, T, {2, [{a, 1}], b}),
    Res1 = kvdb_trans:run(
	     Name,
	     fun(_) ->
		     ok = kvdb:put(Name, T, {3, [{a, 1}], c}),
		     ok = kvdb:put(Name, T, {4, [{a, 1}], d}),
		     ok = kvdb:put(Name, T, {5, [], e}),
		     kvdb:index_get(Name, T, a, 1)
	     end),
    ?assertMatch([{1,[{a,1}],a},
		  {2,[{a,1}],b},
		  {3,[{a,1}],c},
		  {4,[{a,1}],d}], Res1),
    ok = kvdb:delete_table(Name, T).

index_keys(Name) ->
    T = ?tab,
    ok = kvdb:add_table(Name, T, [{type, set},
				  {encoding, {sext,sext,sext}},
				  {index, [a]}]),
    ok = kvdb:put(Name, T, {1, [{a, 1}], a}),
    ok = kvdb:put(Name, T, {2, [{a, 1}], b}),
    Res1 = kvdb_trans:run(
	     Name,
	     fun(_) ->
		     ok = kvdb:put(Name, T, {3, [{a, 1}], c}),
		     ok = kvdb:put(Name, T, {4, [{a, 1}], d}),
		     ok = kvdb:put(Name, T, {5, [], e}),
		     kvdb:index_keys(Name, T, a, 1)
	     end),
    ?assertMatch([1,2,3,4], Res1),
    ok = kvdb:delete_table(Name, T).

prefix_match(Name) ->
    T = ?tab,
    ok = kvdb:add_table(Name, T, [{type, set}, {encoding, sext}]),
    [ok,ok] = [kvdb:put(Name, T, Obj) || Obj <- [{2,b}, {3,c}]],
    Res = kvdb:transaction(
	    Name,
	    fun(_) ->
		    {[{2,b},{3,c}], _} =
			kvdb:prefix_match(Name, T, '_', infinity),
		    [ok,ok] =
			[kvdb:put(Name, T, Obj) || Obj <- [{1,a}, {4,d}]],
		    {[{1,a}, {2,b}], C1} =
			kvdb:prefix_match(Name, T, '_', 2),
		    {[{3,c}, {4,d}], C2} = C1(),
		    done = C2()
	    end),
    ok.

prefix_match_rel(_) ->
    ok.

no_lingering_monitors(Name) ->
    {monitored_by, Bef} = process_info(self(), monitored_by),
    io:fwrite(user, "monitored by Bef = ~p~n",
	      [[process_info(P) || P <- Bef]]),
    T = ?tab,
    write_del_write(Name, T),
    {monitored_by, Aft} = process_info(self(), monitored_by),
    io:fwrite(user, "monitored by Aft = ~p~n",
	      [[process_info(P) || P <- Aft]]),
    [] = Aft -- Bef.

-endif.
