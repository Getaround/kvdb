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
-module(kvdb_conf_tests).

-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").
-include("feuerlabs_eunit.hrl").

-define(tab, iolist_to_binary([<<"t_">>, integer_to_list(?LINE)])).
-define(mktab(T, Os), T = ?tab, ok = kvdb_conf:add_table(T, Os)).
-define(my_t(E), ?_t(?dbg(E))).


conf_test_() ->
    {setup,
     fun() ->
	     application:start(gproc),
	     application:start(kvdb),
	     kvdb_conf:open(undefined, [{backend, ets}]),
	     ok
     end,
     fun(_) ->
	     application:stop(kvdb),
	     application:stop(gproc)
     end,
     [?my_t(read_write())
      , ?my_t(prefix_match())
      , ?my_t(conf_tree())
      , ?my_t(write_tree())
      , ?my_t(first_next_child())
      ]}.

read_write() ->
    ?mktab(T, []),
    ok = kvdb_conf:write(T, {<<"a">>, [{a,1}], <<"1">>}),
    {ok, {<<"a">>, [{a,1}], <<"1">>}} = kvdb_conf:read(T, <<"a">>),
    ok = kvdb_conf:delete(T, <<"a">>),
    {error, not_found} = kvdb_conf:read(T, <<"a">>),
    ok = kvdb_conf:delete_table(T).

prefix_match() ->
    ?mktab(T, []),
    ok = kvdb_conf:write(T, {<<"aabbcc">>, [], <<>>}),
    ok = kvdb_conf:write(T, {<<"aabbdd">>, [], <<>>}),
    ok = kvdb_conf:write(T, {<<"aaccdd">>, [], <<>>}),
    {[{<<"aabbcc">>,[],<<>>},{<<"aabbdd">>,[],<<>>}],_} =
	kvdb_conf:prefix_match(T, <<"aabb">>),
    ok = kvdb_conf:delete_table(T).

first_next_tree() ->
    ?mktab(T, []),
    ok = kvdb_conf:write(T, {<<"a*b*a">>, [], <<>>}),
    ok = kvdb_conf:write(T, {<<"a*b*c">>, [], <<>>}),
    ok = kvdb_conf:write(T, {<<"a*c*a">>, [], <<>>}),
    ok = kvdb_conf:write(T, {<<"b*b*a">>, [], <<>>}),
    ok = kvdb_conf:write(T, {<<"b*b*c">>, [], <<>>}),
    {conf_tree, <<"a*b">>, [{<<"a">>, [], <<>>}]} = First =
	kvdb_conf:first_tree(T),
    {conf_tree, <<"b*b">>, [{<<"a">>, [], <<>>}]} =
	kvdb_conf:first_tree(T, First),
    {conf_tree, <<"b*b">>, [{<<"c">>, [], <<>>}]} =
	kvdb_conf:last_tree(T),
    ok = kvdb_conf:delete_table(T).


conf_tree() ->
    ?mktab(T, []),
    ok = kvdb_conf:write(
	   T,
	   {kvdb_conf:join_key(<<"a">>, <<"b">>), [{b,1}],<<"1">>}),
    ok = kvdb_conf:write(
	   T,
	   {kvdb_conf:join_key(<<"a">>, <<"c">>), [{c,1}],<<"2">>}),
    [{<<"a*b">>,[{b,1}],<<"1">>},
     {<<"a*c">>,[{c,1}],<<"2">>}] = kvdb_conf:all(T),
    {conf_tree, <<"a">>, [{<<"b">>, [{b,1}], <<"1">>},
			  {<<"c">>, [{c,1}], <<"2">>}]} =
	kvdb_conf:read_tree(T, <<"a">>),
    ok = kvdb_conf:write(T, {<<"a">>, [], <<>>}),
    %% <<"a">> is a separate object, so must be part of the tree. It cannot
    %% be lifted into the root key.
    {conf_tree, <<>>, [{<<"a">>, [], <<>>,
			[{<<"b">>, [{b,1}], <<"1">>},
			 {<<"c">>, [{c,1}], <<"2">>}]}]} =
	kvdb_conf:first_tree(T),
    ok = kvdb_conf:delete_table(T).

write_tree() ->
    ?mktab(T, []),
    L = [{<<"a*b">>, [], <<"1">>},
	 {<<"a*c">>, [], <<"2">>},
	 {<<"a*c*a[00000001]">>,[],<<"3">>},
	 {<<"a*c*a[00000002]">>,[],<<"4">>}],
    {conf_tree, _, _} = Tree = kvdb_conf:make_tree(L),
    %% To write the whole tree, we must first shift the root into the tree.
    ok = kvdb_conf:write_tree(T, <<>>, kvdb_conf:shift_root(top, Tree)),
    {L,_} = kvdb_conf:prefix_match(T, <<>>),
    ok = kvdb_conf:delete_table(T).

first_next_child() ->
    ?mktab(T, []),
    ok = kvdb_conf:write(T, {<<"a*b">>, [], <<"1">>}),
    ok = kvdb_conf:write(T, {<<"a*c">>, [], <<"2">>}),
    ok = kvdb_conf:write(T, {<<"a*c*1">>, [], <<"3">>}),
    ok = kvdb_conf:write(T, {<<"a*d">>, [], <<"4">>}),
    {ok, <<"a*b">>} = kvdb_conf:first_child(T, <<"a">>),
    {ok, <<"a*d">>} = kvdb_conf:last_child(T, <<"a">>),
    {ok, <<"a*c">>} = kvdb_conf:next_child(T, <<"a*b">>),
    {ok, <<"a*d">>} = kvdb_conf:next_child(T, <<"a*c">>),
    done = kvdb_conf:next_child(T, <<"a*d">>),
    ok = kvdb_conf:delete_table(T).

-endif.
