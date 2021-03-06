

# Module kvdb_conf #
* [Description](#description)
* [Function Index](#index)
* [Function Details](#functions)



API to store NETCONF-style config data in kvdb.
__Authors:__ Ulf Wiger ([`ulf@feuerlabs.com`](mailto:ulf@feuerlabs.com)).
<a name="description"></a>

## Description ##



The `kvdb_conf` API offers a number of functions geared towards
management of a configuration database. Specifically, `kvdb_conf` is
designed to work well with configuration management à la
[NETCONF (RFC 6241)"](http://tools.ietf.org.md/rfc6241) and
the [YANG data modeling
language (RFC 6020)](http://tools.ietf.org.md/rfc6020). When used in the Feuerlabs Exosense(tm) platform,
`kvdb_conf` ties into the device lifecycle management concepts of the
Feuerlabs ExoDM Device Management Platform.



The database itself is a `kvdb` database, so the `kvdb` API also applies.



Specifically, `kvdb_conf` provides the following functionality on top
of `kvdb`:



* The object structure is `{Key, Attribues, Value}`
* Keys are always `raw`-encoded, and reflect a hierarchy
* A hierarchical key can be constructed using '*' as a join symbol.
* Keys can be constructed/deconstructed with
[`join_key/1`](#join_key-1)/[`split_key/1`](#split_key-1)
* Whole configuration subtrees can be read/written as one operation
* Subtrees can be efficiently skipped during traversal due to key encoding.
identifiers are stored as a structured key (binary)
delimited by:



Netconf identifiers can consist of alphanumerics, '-', '_' or '.'.
The '*' as delimiter is chosen so that a "wildcard" character can be
used that is greater than the delimiter, but smaller than any identifier
character.


For further generality, `kvdb_conf` keys are escaped, using an algorithm
that doesn't upset the sort order, or ability to skip past subtrees during
traversal. Two functions exist for construction/deconstruction of
composite keys: [`join_key/1`](#join_key-1) and [`split_key/1`](#split_key-1). These functions
also escape/unescape keys that are outside the Netconf alphabet. An escaped
key starts with '='. The escaping character is '@', followed by the hex
code of the escaped character. For efficiency, any key (or key part) that
starts with '=' will be considered escaped. Thus, no unescaped key may
begin with '=' (this is not enforced, but will lead to unpredictable
behavior).<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#add_table-1">add_table/1</a></td><td>Equivalent to <a href="#add_table-2"><tt>add_table(T, [])</tt></a>.</td></tr><tr><td valign="top"><a href="#add_table-2">add_table/2</a></td><td>Adds a table to the <code>kvdb_conf</code> database.</td></tr><tr><td valign="top"><a href="#all-0">all/0</a></td><td>Equivalent to <a href="#all-1"><tt>all(&lt;&lt;"data"&gt;&gt;)</tt></a>.</td></tr><tr><td valign="top"><a href="#all-1">all/1</a></td><td>Returns a list of all configuration objects in the given table.</td></tr><tr><td valign="top"><a href="#close-0">close/0</a></td><td>Closes the current <code>kvdb_conf</code> database.</td></tr><tr><td valign="top"><a href="#delete-1">delete/1</a></td><td>Equivalent to <a href="#delete-2"><tt>delete(&lt;&lt;"data"&gt;&gt;, K)</tt></a>.</td></tr><tr><td valign="top"><a href="#delete-2">delete/2</a></td><td>Deletes an object denoted by Key, returns <code>ok</code> even if object not found.</td></tr><tr><td valign="top"><a href="#delete_all-1">delete_all/1</a></td><td>Equivalent to <a href="#delete_all-2"><tt>delete_all(&lt;&lt;"data"&gt;&gt;, Prefix)</tt></a>.</td></tr><tr><td valign="top"><a href="#delete_all-2">delete_all/2</a></td><td>Deletes all objects with a key matching <code>Prefix</code>.</td></tr><tr><td valign="top"><a href="#delete_table-1">delete_table/1</a></td><td>Equivalent to <a href="kvdb.md#delete_table-1"><tt>kvdb:delete_table(T)</tt></a>.</td></tr><tr><td valign="top"><a href="#delete_tree-1">delete_tree/1</a></td><td></td></tr><tr><td valign="top"><a href="#delete_tree-2">delete_tree/2</a></td><td></td></tr><tr><td valign="top"><a href="#escape_key-1">escape_key/1</a></td><td>Escapes a key; leaves it unchanged if already escaped.</td></tr><tr><td valign="top"><a href="#escape_key_part-1">escape_key_part/1</a></td><td>Escapes a key part according to <code>kvdb_conf</code> escaping rules.</td></tr><tr><td valign="top"><a href="#first-0">first/0</a></td><td>Equivalent to <a href="#first-1"><tt>first(&lt;&lt;"data"&gt;&gt;)</tt></a>.</td></tr><tr><td valign="top"><a href="#first-1">first/1</a></td><td>Returns the first object in <code>Tab</code>, if there is one; otherwise <code>done</code>.</td></tr><tr><td valign="top"><a href="#first_child-1">first_child/1</a></td><td>Equivalent to <a href="#first_child-2"><tt>first_child(&lt;&lt;"data"&gt;&gt;, Parent)</tt></a>.</td></tr><tr><td valign="top"><a href="#first_child-2">first_child/2</a></td><td>Returns the first child, if any, of the given <code>Parent</code>.</td></tr><tr><td valign="top"><a href="#first_top_key-0">first_top_key/0</a></td><td>Equivalent to <a href="#first_top_key-1"><tt>first_top_key(&lt;&lt;"data"&gt;&gt;)</tt></a>.</td></tr><tr><td valign="top"><a href="#first_top_key-1">first_top_key/1</a></td><td>Returns the first top-level key in <code>Table</code>, or <code>done</code> if empty.</td></tr><tr><td valign="top"><a href="#first_tree-0">first_tree/0</a></td><td>Equivalent to <a href="#first_tree-1"><tt>first_tree(&lt;&lt;"data"&gt;&gt;)</tt></a>.</td></tr><tr><td valign="top"><a href="#first_tree-1">first_tree/1</a></td><td>Reads the first config tree from <code>Table</code>, returns <code>[]</code> if <code>Table</code> empty.</td></tr><tr><td valign="top"><a href="#flatten_tree-1">flatten_tree/1</a></td><td>Converts a configuration tree into an ordered list of configuration objects.</td></tr><tr><td valign="top"><a href="#fold_children-3">fold_children/3</a></td><td>Equivalent to <a href="#fold_children-4"><tt>fold_children(&lt;&lt;"data"&gt;&gt;, Fun, Acc, K)</tt></a>.</td></tr><tr><td valign="top"><a href="#fold_children-4">fold_children/4</a></td><td>Folds over the immediate children of <code>K</code>, applying <code>Fun(K, Acc)</code>.</td></tr><tr><td valign="top"><a href="#fold_list-3">fold_list/3</a></td><td>Equivalent to <a href="#fold_list-4"><tt>fold_list(&lt;&lt;"data"&gt;&gt;, Fun, Acc, BaseKey)</tt></a>.</td></tr><tr><td valign="top"><a href="#fold_list-4">fold_list/4</a></td><td>Fold through a configuration list set.</td></tr><tr><td valign="top"><a href="#get_root-1">get_root/1</a></td><td>Returns the root key of the given config tree.</td></tr><tr><td valign="top"><a href="#in_transaction-1">in_transaction/1</a></td><td>Equivalent to <a href="kvdb.md#in_transaction-2"><tt>kvdb:in_transaction(kvdb_conf_instance(), Fun)</tt></a>.</td></tr><tr><td valign="top"><a href="#info-1">info/1</a></td><td></td></tr><tr><td valign="top"><a href="#instance-0">instance/0</a></td><td></td></tr><tr><td valign="top"><a href="#join_key-1">join_key/1</a></td><td>Joins a list of key parts into one key, ensuring all parts are escaped.</td></tr><tr><td valign="top"><a href="#join_key-2">join_key/2</a></td><td>Joins two key parts into one key, ensuring both parts are escaped.</td></tr><tr><td valign="top"><a href="#key-1">key/1</a></td><td>Normalizes a key or list of key parts.</td></tr><tr><td valign="top"><a href="#last-0">last/0</a></td><td>Equivalent to <a href="#last-1"><tt>last(&lt;&lt;"data"&gt;&gt;)</tt></a>.</td></tr><tr><td valign="top"><a href="#last-1">last/1</a></td><td>Returns the last object in <code>Tab</code>, if there is one; otherwise
<code>done</code>.</td></tr><tr><td valign="top"><a href="#last_child-1">last_child/1</a></td><td>Equivalent to <a href="#last_child-2"><tt>last_child(&lt;&lt;"data"&gt;&gt;, K)</tt></a>.</td></tr><tr><td valign="top"><a href="#last_child-2">last_child/2</a></td><td>Returns the last child, if any, of the given <code>Parent</code>; otherwise <code>done</code>.</td></tr><tr><td valign="top"><a href="#last_list_pos-1">last_list_pos/1</a></td><td></td></tr><tr><td valign="top"><a href="#last_list_pos-2">last_list_pos/2</a></td><td></td></tr><tr><td valign="top"><a href="#last_tree-0">last_tree/0</a></td><td>Equivalent to <a href="#last_tree-1"><tt>last_tree(&lt;&lt;"data"&gt;&gt;)</tt></a>.</td></tr><tr><td valign="top"><a href="#last_tree-1">last_tree/1</a></td><td>Returns the last config tree from <code>Table</code>, or <code>[]</code> if <code>Table</code> empty.</td></tr><tr><td valign="top"><a href="#list_key-2">list_key/2</a></td><td>Creates a "list key" part from a base (binary) and an index (integer).</td></tr><tr><td valign="top"><a href="#make_tree-1">make_tree/1</a></td><td>Converts an ordered list of configuration objects into a configuration tree.</td></tr><tr><td valign="top"><a href="#next-1">next/1</a></td><td>Equivalent to <a href="#next-2"><tt>next(&lt;&lt;"data"&gt;&gt;, K)</tt></a>.</td></tr><tr><td valign="top"><a href="#next-2">next/2</a></td><td>Returns the next object in <code>Tab</code> following the key <code>K</code>,
if there is one; otherwise <code>done</code>.</td></tr><tr><td valign="top"><a href="#next_at_level-1">next_at_level/1</a></td><td>Equivalent to <a href="#next_at_level-2"><tt>next_at_level(&lt;&lt;"data"&gt;&gt;, K)</tt></a>.</td></tr><tr><td valign="top"><a href="#next_at_level-2">next_at_level/2</a></td><td>Skips to the next sibling at the same level in the subtree.</td></tr><tr><td valign="top"><a href="#next_child-1">next_child/1</a></td><td>Equivalent to <a href="#next_child-2"><tt>next_child(&lt;&lt;"data"&gt;&gt;, Prev)</tt></a>.</td></tr><tr><td valign="top"><a href="#next_child-2">next_child/2</a></td><td>Returns the next child at the same level as <code>PrevChild</code>.</td></tr><tr><td valign="top"><a href="#next_tree-1">next_tree/1</a></td><td>Equivalent to <a href="#next_tree-2"><tt>next_tree(&lt;&lt;"data"&gt;&gt;, K)</tt></a>.</td></tr><tr><td valign="top"><a href="#next_tree-2">next_tree/2</a></td><td>Returns the next config tree in <code>Table</code> after <code>K</code>, or <code>[]</code> if not found.</td></tr><tr><td valign="top"><a href="#open-1">open/1</a></td><td>Equivalent to <a href="#open-2"><tt>open(File, [])</tt></a>.</td></tr><tr><td valign="top"><a href="#open-2">open/2</a></td><td>Opens a kvdb_conf-compliant kvdb database.</td></tr><tr><td valign="top"><a href="#prefix_match-1">prefix_match/1</a></td><td>Equivalent to <a href="#prefix_matc-2"><tt>prefix_matc(&lt;&lt;"data"&gt;&gt;, Prefix)</tt></a>.</td></tr><tr><td valign="top"><a href="#prefix_match-2">prefix_match/2</a></td><td>Performs a prefix match, returning all matching objects.</td></tr><tr><td valign="top"><a href="#prefix_match-3">prefix_match/3</a></td><td></td></tr><tr><td valign="top"><a href="#prev-1">prev/1</a></td><td>Equivalent to <a href="#prev-2"><tt>prev(&lt;&lt;"data"&gt;&gt;, K)</tt></a>.</td></tr><tr><td valign="top"><a href="#prev-2">prev/2</a></td><td>Returns the previous object in <code>Tab</code> before the key <code>K</code>,
if there is one; otherwise <code>done</code>.</td></tr><tr><td valign="top"><a href="#prev_at_level-1">prev_at_level/1</a></td><td>Equivalent to <a href="#prev_at_level-2"><tt>prev_at_level(&lt;&lt;"data"&gt;&gt;, K)</tt></a>.</td></tr><tr><td valign="top"><a href="#prev_at_level-2">prev_at_level/2</a></td><td>Skips to the prev sibling at the same level in the subtree.</td></tr><tr><td valign="top"><a href="#raw_join_key-1">raw_join_key/1</a></td><td>Joins key parts without escaping them.</td></tr><tr><td valign="top"><a href="#raw_join_key-2">raw_join_key/2</a></td><td></td></tr><tr><td valign="top"><a href="#raw_prev-2">raw_prev/2</a></td><td></td></tr><tr><td valign="top"><a href="#raw_split_key-1">raw_split_key/1</a></td><td></td></tr><tr><td valign="top"><a href="#read-1">read/1</a></td><td>Equivalent to <a href="#read-2"><tt>read(&lt;&lt;"data"&gt;&gt;, Key)</tt></a>.</td></tr><tr><td valign="top"><a href="#read-2">read/2</a></td><td>Reads a configuration object from the database.</td></tr><tr><td valign="top"><a href="#read_tree-1">read_tree/1</a></td><td>Equivalent to <a href="#read_tree-2"><tt>read_tree(&lt;&lt;"data"&gt;&gt;, Prefix)</tt></a>.</td></tr><tr><td valign="top"><a href="#read_tree-2">read_tree/2</a></td><td>Read a configuration (sub-)tree corresponding to the given parent Key.</td></tr><tr><td valign="top"><a href="#set_root-2">set_root/2</a></td><td>Inserts a new root into a <code>#conf_tree{}</code> record.</td></tr><tr><td valign="top"><a href="#shift_root-2">shift_root/2</a></td><td>Shifts the config tree root upwards or downwards if possible.</td></tr><tr><td valign="top"><a href="#split_key-1">split_key/1</a></td><td>Splits a <code>kvdb_conf</code> key into a list of (unescaped) key parts.</td></tr><tr><td valign="top"><a href="#transaction-1">transaction/1</a></td><td>Equivalent to <a href="kvdb.md#transaction-2"><tt>kvdb:transaction(kvdb_conf_instance(), Fun)</tt></a>.</td></tr><tr><td valign="top"><a href="#unescape_key-1">unescape_key/1</a></td><td>Unescapes a key.</td></tr><tr><td valign="top"><a href="#unescape_key_part-1">unescape_key_part/1</a></td><td>Unescapes a key part; leaving it untouched if already escaped.</td></tr><tr><td valign="top"><a href="#update_counter-2">update_counter/2</a></td><td>Equivalent to <a href="#update_counter-3"><tt>update_counter(&lt;&lt;"data"&gt;&gt;, Key, Incr)</tt></a>.</td></tr><tr><td valign="top"><a href="#update_counter-3">update_counter/3</a></td><td>Updates a counter with the given increment.</td></tr><tr><td valign="top"><a href="#write-1">write/1</a></td><td>Equivalent to <a href="#write-2"><tt>write(&lt;&lt;"data"&gt;&gt;, Obj)</tt></a>.</td></tr><tr><td valign="top"><a href="#write-2">write/2</a></td><td>Writes a configuration object into the database.</td></tr><tr><td valign="top"><a href="#write_tree-2">write_tree/2</a></td><td>Equivalent to <a href="#write_tree-3"><tt>write_tree(&lt;&lt;"data"&gt;&gt;, Parent, T)</tt></a>.</td></tr><tr><td valign="top"><a href="#write_tree-3">write_tree/3</a></td><td>Writes a configuration tree under the given parent.</td></tr><tr><td valign="top"><a href="#xpath-1">xpath/1</a></td><td></td></tr><tr><td valign="top"><a href="#xpath-2">xpath/2</a></td><td></td></tr><tr><td valign="top"><a href="#xpath-3">xpath/3</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="add_table-1"></a>

### add_table/1 ###


<pre><code>
add_table(T::<a href="kvdb.md#type-table">kvdb:table()</a>) -&gt; ok
</code></pre>

<br></br>


Equivalent to [`add_table(T, [])`](#add_table-2).
<a name="add_table-2"></a>

### add_table/2 ###


<pre><code>
add_table(T::<a href="kvdb.md#type-table">kvdb:table()</a>, Opts::<a href="kvdb.md#type-options">kvdb:options()</a>) -&gt; ok
</code></pre>

<br></br>



Adds a table to the `kvdb_conf` database. By default, `kvdb_conf`
uses a table called `data`, which is created when the database is first
created. Additional tables can opt for different types of indexing, or
encoding of the `Value` part. The `Key` part must always be `raw`, since
the `kvdb_conf` API requires the keys to be of type `binary()`, and the
object structure must be `{Key, Attributes, Value}`. The default encoding
is `{raw, term, raw}`.



(While it is of course possible to store binary keys with any type of
encoding, enforcing `raw` encoding ensures that this restriction is not
subverted through the normal `kvdb` API).


All other table options supported by [`kvdb:add_table/3`](kvdb.md#add_table-3) are also
supported here.
<a name="all-0"></a>

### all/0 ###


<pre><code>
all() -&gt; [<a href="#type-conf_obj">conf_obj()</a>]
</code></pre>

<br></br>


Equivalent to [`all(<<"data">>)`](#all-1).
<a name="all-1"></a>

### all/1 ###


<pre><code>
all(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>) -&gt; [<a href="#type-conf_obj">conf_obj()</a>]
</code></pre>

<br></br>



Returns a list of all configuration objects in the given table.


Note: this function returns _all_ objects in one sweep. It doesn't
return a subset together with a continuation. Thus, this function is more
suited to debugging (given that the data set is small!). For safer
semantics, see [`prefix_match/2`](#prefix_match-2) - An equivalent version to this
function would be `prefix_match(Tab, <<>>)`.
<a name="close-0"></a>

### close/0 ###


<pre><code>
close() -&gt; ok
</code></pre>

<br></br>


Closes the current `kvdb_conf` database.
<a name="delete-1"></a>

### delete/1 ###


<pre><code>
delete(K::<a href="kvdb.md#type-key">kvdb:key()</a>) -&gt; ok
</code></pre>

<br></br>


Equivalent to [`delete(<<"data">>, K)`](#delete-2).
<a name="delete-2"></a>

### delete/2 ###


<pre><code>
delete(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, K::<a href="kvdb.md#type-key">kvdb:key()</a>) -&gt; ok
</code></pre>

<br></br>


Deletes an object denoted by Key, returns `ok` even if object not found.
<a name="delete_all-1"></a>

### delete_all/1 ###


<pre><code>
delete_all(Prefix::<a href="kvdb.md#type-prefix">kvdb:prefix()</a>) -&gt; ok
</code></pre>

<br></br>


Equivalent to [`delete_all(<<"data">>, Prefix)`](#delete_all-2).
<a name="delete_all-2"></a>

### delete_all/2 ###


<pre><code>
delete_all(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, Prefix::<a href="kvdb.md#type-prefix">kvdb:prefix()</a>) -&gt; ok
</code></pre>

<br></br>


Deletes all objects with a key matching `Prefix`. Always returns `ok`.
<a name="delete_table-1"></a>

### delete_table/1 ###


<pre><code>
delete_table(T::<a href="kvdb.md#type-table">kvdb:table()</a>) -&gt; ok
</code></pre>

<br></br>


Equivalent to [`kvdb:delete_table(T)`](kvdb.md#delete_table-1).
<a name="delete_tree-1"></a>

### delete_tree/1 ###

`delete_tree(K) -> any()`


<a name="delete_tree-2"></a>

### delete_tree/2 ###

`delete_tree(Tab, K) -> any()`


<a name="escape_key-1"></a>

### escape_key/1 ###


<pre><code>
escape_key(K::<a href="#type-key">key()</a>) -&gt; <a href="#type-key">key()</a>
</code></pre>

<br></br>



Escapes a key; leaves it unchanged if already escaped.



Any key starting with "=" is assumed to be escaped already.


NOTE: This function does not escape '*', '[' and ']', as they are key
delimiters. If they are intended to be escaped as well, use
[`escape_key_part/1`](#escape_key_part-1) instead.
<a name="escape_key_part-1"></a>

### escape_key_part/1 ###


<pre><code>
escape_key_part(Esc::<a href="#type-key_part">key_part()</a>) -&gt; <a href="#type-key_part">key_part()</a>
</code></pre>

<br></br>



Escapes a key part according to `kvdb_conf` escaping rules.



Encoding users @ as an escape character followed by the escaped char
hex-coded (e.g. "@" -> "@40", "/" -> "@2F"). In order to know that the
id has been encoded - so we don't encode it twice - we prepend a '='
to the encoded key part. Since '=' lies between ASCII numbers and letters
(just as '@' does), it won't upset the kvdb sort order.



As a consequence, no unescaped key part string may begin with '='.


NOTE: This function also escapes the key delimiters '*', '[' and ']'.
<a name="first-0"></a>

### first/0 ###


<pre><code>
first() -&gt; {ok, <a href="#type-conf_obj">conf_obj()</a>} | done
</code></pre>

<br></br>


Equivalent to [`first(<<"data">>)`](#first-1).
<a name="first-1"></a>

### first/1 ###


<pre><code>
first(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>) -&gt; {ok, <a href="#type-conf_obj">conf_obj()</a>} | done
</code></pre>

<br></br>


Returns the first object in `Tab`, if there is one; otherwise `done`.
<a name="first_child-1"></a>

### first_child/1 ###


<pre><code>
first_child(Parent::<a href="#type-key">key()</a>) -&gt; {ok, <a href="#type-key">key()</a>} | done
</code></pre>

<br></br>


Equivalent to [`first_child(<<"data">>, Parent)`](#first_child-2).
<a name="first_child-2"></a>

### first_child/2 ###


<pre><code>
first_child(Table::<a href="kvdb.md#type-table">kvdb:table()</a>, Parent::<a href="#type-key">key()</a>) -&gt; {ok, <a href="#type-key">key()</a>} | done
</code></pre>

<br></br>


Returns the first child, if any, of the given `Parent`.
<a name="first_top_key-0"></a>

### first_top_key/0 ###


<pre><code>
first_top_key() -&gt; {ok, <a href="#type-key">key()</a>} | done
</code></pre>

<br></br>


Equivalent to [`first_top_key(<<"data">>)`](#first_top_key-1).
<a name="first_top_key-1"></a>

### first_top_key/1 ###


<pre><code>
first_top_key(Table::<a href="kvdb.md#type-table">kvdb:table()</a>) -&gt; {ok, <a href="#type-key">key()</a>} | done
</code></pre>

<br></br>


Returns the first top-level key in `Table`, or `done` if empty.
<a name="first_tree-0"></a>

### first_tree/0 ###


<pre><code>
first_tree() -&gt; #conf_tree{} | []
</code></pre>

<br></br>


Equivalent to [`first_tree(<<"data">>)`](#first_tree-1).
<a name="first_tree-1"></a>

### first_tree/1 ###


<pre><code>
first_tree(Table::<a href="kvdb.md#type-table">kvdb:table()</a>) -&gt; #conf_tree{} | []
</code></pre>

<br></br>



Reads the first config tree from `Table`, returns `[]` if `Table` empty.


This function returns a `#conf_tree{}` record which, among other things,
can be passed to [`write_tree/3`](#write_tree-3) or [`flatten_tree/1`](#flatten_tree-1).
<a name="flatten_tree-1"></a>

### flatten_tree/1 ###


<pre><code>
flatten_tree(Conf_tree::#conf_tree{} | <a href="#type-conf_data">conf_data()</a>) -&gt; [<a href="#type-conf_obj">conf_obj()</a>]
</code></pre>

<br></br>


Converts a configuration tree into an ordered list of configuration objects.
<a name="fold_children-3"></a>

### fold_children/3 ###


<pre><code>
fold_children(Fun::fun((<a href="#type-key">key()</a>, Acc) -&gt; Acc), Acc, K::<a href="#type-key">key()</a>) -&gt; Acc
</code></pre>

<br></br>


Equivalent to [`fold_children(<<"data">>, Fun, Acc, K)`](#fold_children-4).
<a name="fold_children-4"></a>

### fold_children/4 ###


<pre><code>
fold_children(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, Fun::fun((<a href="#type-key">key()</a>, Acc) -&gt; Acc), Acc, K::<a href="#type-key">key()</a>) -&gt; Acc
</code></pre>

<br></br>


Folds over the immediate children of `K`, applying `Fun(K, Acc)`.
<a name="fold_list-3"></a>

### fold_list/3 ###


<pre><code>
fold_list(Fun::fun((integer(), <a href="#type-key">key()</a>, Acc) -&gt; Acc), Acc, BaseKey::<a href="#type-key">key()</a>) -&gt; Acc
</code></pre>

<br></br>


Equivalent to [`fold_list(<<"data">>, Fun, Acc, BaseKey)`](#fold_list-4).
<a name="fold_list-4"></a>

### fold_list/4 ###


<pre><code>
fold_list(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, Fun::fun((integer(), <a href="#type-key">key()</a>, Acc) -&gt; Acc), Acc, BaseKey::<a href="#type-key">key()</a>) -&gt; Acc
</code></pre>

<br></br>



Fold through a configuration list set.


This function assumes that `BaseKey` is a prefix to a set of list keys,
e.g. `<<"a*b*c">>` would be a base key for `<<"a*b*c[00000001]">>`,
`<<"a*b*c[00000002]">>`, etc. This function folds through all matching
keys, applying `Fun(PosIndex, Key, Acc)` and accumulating the result.
`PosIndex` is the numerical index value of the list key. `Key` is the
entire key.
<a name="get_root-1"></a>

### get_root/1 ###


<pre><code>
get_root(Conf_tree::#conf_tree{}) -&gt; <a href="#type-key">key()</a>
</code></pre>

<br></br>


Returns the root key of the given config tree.
<a name="in_transaction-1"></a>

### in_transaction/1 ###


<pre><code>
in_transaction(Fun::fun((<a href="kvdb.md#type-db_ref">kvdb:db_ref()</a>) -&gt; T)) -&gt; T
</code></pre>

<br></br>


Equivalent to [`kvdb:in_transaction(kvdb_conf_instance(), Fun)`](kvdb.md#in_transaction-2).
<a name="info-1"></a>

### info/1 ###

`info(I) -> any()`


<a name="instance-0"></a>

### instance/0 ###

`instance() -> any()`


<a name="join_key-1"></a>

### join_key/1 ###


<pre><code>
join_key(T::[<a href="#type-key_part">key_part()</a>]) -&gt; <a href="#type-key">key()</a>
</code></pre>

<br></br>



Joins a list of key parts into one key, ensuring all parts are escaped.



A key part can either be a `binary()` or a `{binary(), integer()}` tuple.
The tuple construct corresponds to a "list key", where the first element
is the base key, and the second, a list index.
For example, `{<<"port">>, 1}` is expanded to `<<"port[00000001]">>` and
then escaped.


NOTE: This function does not automatically escape '*', '[' and ']', as
they are key delimiters. If they are meant to be escaped, escape the parts
explicitly with [`escape_key_part/1`](#escape_key_part-1) and then use
[`raw_join_key/1`](#raw_join_key-1).
<a name="join_key-2"></a>

### join_key/2 ###


<pre><code>
join_key(K::<a href="#type-key_part">key_part()</a>, K2::<a href="#type-key_part">key_part()</a>) -&gt; <a href="#type-key">key()</a>
</code></pre>

<br></br>


Joins two key parts into one key, ensuring both parts are escaped.
See [`join_key/1`](#join_key-1).
<a name="key-1"></a>

### key/1 ###


<pre><code>
key(Parts::<a href="#type-key">key()</a> | [<a href="#type-key_part">key_part()</a>]) -&gt; <a href="#type-key">key()</a>
</code></pre>

<br></br>



Normalizes a key or list of key parts.


This function tries to ensure that a key is properly escaped, including
properly encoded array indices.
<a name="last-0"></a>

### last/0 ###


<pre><code>
last() -&gt; {ok, <a href="#type-conf_obj">conf_obj()</a>} | done
</code></pre>

<br></br>


Equivalent to [`last(<<"data">>)`](#last-1).
<a name="last-1"></a>

### last/1 ###


<pre><code>
last(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>) -&gt; {ok, <a href="#type-conf_obj">conf_obj()</a>} | done
</code></pre>

<br></br>


Returns the last object in `Tab`, if there is one; otherwise
`done`.
<a name="last_child-1"></a>

### last_child/1 ###


<pre><code>
last_child(K::<a href="#type-key">key()</a>) -&gt; {ok, <a href="#type-key">key()</a>} | done
</code></pre>

<br></br>


Equivalent to [`last_child(<<"data">>, K)`](#last_child-2).
<a name="last_child-2"></a>

### last_child/2 ###


<pre><code>
last_child(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, Parent0::<a href="#type-key">key()</a>) -&gt; {ok, <a href="#type-key">key()</a>} | done
</code></pre>

<br></br>


Returns the last child, if any, of the given `Parent`; otherwise `done`.
<a name="last_list_pos-1"></a>

### last_list_pos/1 ###

`last_list_pos(Prefix) -> any()`


<a name="last_list_pos-2"></a>

### last_list_pos/2 ###

`last_list_pos(Table, Prefix0) -> any()`


<a name="last_tree-0"></a>

### last_tree/0 ###


<pre><code>
last_tree() -&gt; #conf_tree{} | []
</code></pre>

<br></br>


Equivalent to [`last_tree(<<"data">>)`](#last_tree-1).
<a name="last_tree-1"></a>

### last_tree/1 ###


<pre><code>
last_tree(Table::<a href="kvdb.md#type-table">kvdb:table()</a>) -&gt; #conf_tree{} | []
</code></pre>

<br></br>



Returns the last config tree from `Table`, or `[]` if `Table` empty.


This function returns a `#conf_tree{}` record which, among other things,
can be passed to [`next_tree/2`](#next_tree-2), [`write_tree/3`](#write_tree-3) or
[`flatten_tree/1`](#flatten_tree-1).
<a name="list_key-2"></a>

### list_key/2 ###


<pre><code>
list_key(Name::binary(), Pos::integer()) -&gt; binary()
</code></pre>

<br></br>



Creates a "list key" part from a base (binary) and an index (integer).



List keys are useful for representing list-like data sets. To preserve
sort order, they are encoded as `<<"Base[nnnnnnnn]">>`, where Base is the
name of the list, and nnnnnnnn is a zero-padded 8-digit hex number.


Example: `list_key(<<"port">>, 28) -> <<"=port[0000001C]">>`
<a name="make_tree-1"></a>

### make_tree/1 ###


<pre><code>
make_tree(Objs::[<a href="#type-conf_obj">conf_obj()</a>]) -&gt; #conf_tree{}
</code></pre>

<br></br>


Converts an ordered list of configuration objects into a configuration tree.
<a name="next-1"></a>

### next/1 ###


<pre><code>
next(K::<a href="kvdb.md#type-key">kvdb:key()</a>) -&gt; {ok, <a href="#type-conf_obj">conf_obj()</a>} | done
</code></pre>

<br></br>


Equivalent to [`next(<<"data">>, K)`](#next-2).
<a name="next-2"></a>

### next/2 ###


<pre><code>
next(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, K::<a href="kvdb.md#type-key">kvdb:key()</a>) -&gt; {ok, <a href="#type-conf_obj">conf_obj()</a>} | done
</code></pre>

<br></br>


Returns the next object in `Tab` following the key `K`,
if there is one; otherwise `done`.
<a name="next_at_level-1"></a>

### next_at_level/1 ###


<pre><code>
next_at_level(K::<a href="kvdb.md#type-key">kvdb:key()</a>) -&gt; {ok, <a href="kvdb.md#type-key">kvdb:key()</a>} | done
</code></pre>

<br></br>


Equivalent to [`next_at_level(<<"data">>, K)`](#next_at_level-2).
<a name="next_at_level-2"></a>

### next_at_level/2 ###


<pre><code>
next_at_level(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, K0::<a href="kvdb.md#type-key">kvdb:key()</a>) -&gt; {ok, <a href="kvdb.md#type-key">kvdb:key()</a>} | done
</code></pre>

<br></br>


Skips to the next sibling at the same level in the subtree.
<a name="next_child-1"></a>

### next_child/1 ###


<pre><code>
next_child(Prev::<a href="#type-key">key()</a>) -&gt; {ok, <a href="#type-key">key()</a>} | done
</code></pre>

<br></br>


Equivalent to [`next_child(<<"data">>, Prev)`](#next_child-2).
<a name="next_child-2"></a>

### next_child/2 ###


<pre><code>
next_child(Table::<a href="kvdb.md#type-table">kvdb:table()</a>, PrevChild::<a href="#type-key">key()</a>) -&gt; {ok, <a href="#type-key">key()</a>} | done
</code></pre>

<br></br>


Returns the next child at the same level as `PrevChild`.

<a name="next_tree-1"></a>

### next_tree/1 ###


<pre><code>
next_tree(K::<a href="kvdb.md#type-key">kvdb:key()</a>) -&gt; #conf_tree{} | []
</code></pre>

<br></br>


Equivalent to [`next_tree(<<"data">>, K)`](#next_tree-2).
<a name="next_tree-2"></a>

### next_tree/2 ###


<pre><code>
next_tree(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, Conf_tree::<a href="kvdb.md#type-key">kvdb:key()</a> | #conf_tree{}) -&gt; #conf_tree{} | []
</code></pre>

<br></br>



Returns the next config tree in `Table` after `K`, or `[]` if not found.


This function returns a `#conf_tree{}` record which, among other things,
can be passed to [`write_tree/3`](#write_tree-3) or [`flatten_tree/1`](#flatten_tree-1).

<a name="open-1"></a>

### open/1 ###

`open(File) -> any()`

Equivalent to [`open(File, [])`](#open-2).
<a name="open-2"></a>

### open/2 ###


<pre><code>
open(_Filename::undefined | string(), Options::<a href="kvdb.md#type-options">kvdb:options()</a>) -&gt; {ok, pid()} | {error, any()}
</code></pre>

<br></br>



Opens a kvdb_conf-compliant kvdb database.



The kvdb_conf API offers a number of functions geared towards management of
a configuration database. The database itself is a `kvdb` database, so the
`kvdb` API also applies. Specifically, `kvdb_conf` provides the following
functionality on top of `kvdb`:



The default options provided by `kvdb_conf` may be overridden, except for
the key encoding, which must always be `raw`, and the object structure,
which must always include attributes.



If `File == undefined`, either a filename will be picked by the chosen
`kvdb` backend, or - e.g. in case of the `ets` backend - no file will be
used at all. Please refer to the documentation of each backend for
information about their respective strengths and weaknesses.



By default, `kvdb_conf` specifies one table: `<<"data">>`. This table is
mandatory, and used unless another table is specified. Other tables can
be created e.g. in order to use a different value encoding or indexes,
or to separate different data sets.


If a `name` option is given, the database instance can be called something
other than `kvdb_conf`. This is primarily intended for e.g. device
simulators. The database name is handled transparently in the `kvdb_conf`
API, and no facility exists to explicitly choose between different
`kvdb_conf` instances. The name of the current instance is stored in the
process dictionary of the current process, and automatically fetched by
the `kvdb_conf` functions.
<a name="prefix_match-1"></a>

### prefix_match/1 ###


<pre><code>
prefix_match(Prefix::<a href="kvdb.md#type-prefix">kvdb:prefix()</a>) -&gt; {[<a href="#type-conf_obj">conf_obj()</a>], <a href="kvdb.md#type-cont">kvdb:cont()</a>}
</code></pre>

<br></br>


Equivalent to [`prefix_matc(<<"data">>, Prefix)`](#prefix_matc-2).
<a name="prefix_match-2"></a>

### prefix_match/2 ###


<pre><code>
prefix_match(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, Prefix::<a href="kvdb.md#type-prefix">kvdb:prefix()</a>) -&gt; {[<a href="#type-conf_obj">conf_obj()</a>], <a href="kvdb.md#type-cont">kvdb:cont()</a>}
</code></pre>

<br></br>



Performs a prefix match, returning all matching objects.


The difference between this function and [`kvdb:prefix_match/3`](kvdb.md#prefix_match-3) is that
this function automatically ensures that the prefix is escaped using the
`kvdb_conf` escaping rules.
<a name="prefix_match-3"></a>

### prefix_match/3 ###

`prefix_match(Tab, Prefix, Limit) -> any()`


<a name="prev-1"></a>

### prev/1 ###


<pre><code>
prev(K::<a href="kvdb.md#type-key">kvdb:key()</a>) -&gt; {ok, <a href="#type-conf_obj">conf_obj()</a>} | done
</code></pre>

<br></br>


Equivalent to [`prev(<<"data">>, K)`](#prev-2).
<a name="prev-2"></a>

### prev/2 ###


<pre><code>
prev(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, K::<a href="kvdb.md#type-key">kvdb:key()</a>) -&gt; {ok, <a href="#type-conf_obj">conf_obj()</a>} | done
</code></pre>

<br></br>


Returns the previous object in `Tab` before the key `K`,
if there is one; otherwise `done`.
<a name="prev_at_level-1"></a>

### prev_at_level/1 ###


<pre><code>
prev_at_level(K::<a href="kvdb.md#type-key">kvdb:key()</a>) -&gt; {ok, <a href="kvdb.md#type-key">kvdb:key()</a>} | done
</code></pre>

<br></br>


Equivalent to [`prev_at_level(<<"data">>, K)`](#prev_at_level-2).
<a name="prev_at_level-2"></a>

### prev_at_level/2 ###


<pre><code>
prev_at_level(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, K0::<a href="kvdb.md#type-key">kvdb:key()</a>) -&gt; {ok, <a href="kvdb.md#type-key">kvdb:key()</a>} | done
</code></pre>

<br></br>


Skips to the prev sibling at the same level in the subtree.
<a name="raw_join_key-1"></a>

### raw_join_key/1 ###


<pre><code>
raw_join_key(T::[<a href="#type-key_part">key_part()</a>]) -&gt; <a href="#type-key">key()</a>
</code></pre>

<br></br>


Joins key parts without escaping them.
Use this function when you either don't care about escaping/unescaping,
or know it has already been done (e.g. with [`escape_key_part/1`](#escape_key_part-1)).
<a name="raw_join_key-2"></a>

### raw_join_key/2 ###

`raw_join_key(K, B) -> any()`


<a name="raw_prev-2"></a>

### raw_prev/2 ###

`raw_prev(Tab, K) -> any()`


<a name="raw_split_key-1"></a>

### raw_split_key/1 ###

`raw_split_key(K) -> any()`


<a name="read-1"></a>

### read/1 ###


<pre><code>
read(Key::<a href="#type-key">key()</a>) -&gt; {ok, <a href="#type-conf_obj">conf_obj()</a>} | {error, any()}
</code></pre>

<br></br>


Equivalent to [`read(<<"data">>, Key)`](#read-2).
<a name="read-2"></a>

### read/2 ###

`read(Tab, Key) -> any()`


Reads a configuration object from the database


The returned item is always the single node. See read_tree(Prefix) on how to read an
entire tree structure.
<a name="read_tree-1"></a>

### read_tree/1 ###


<pre><code>
read_tree(Prefix::binary()) -&gt; #conf_tree{} | []
</code></pre>

<br></br>


Equivalent to [`read_tree(<<"data">>, Prefix)`](#read_tree-2).
<a name="read_tree-2"></a>

### read_tree/2 ###


<pre><code>
read_tree(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, Node::binary()) -&gt; #conf_tree{} | []
</code></pre>

<br></br>



Read a configuration (sub-)tree corresponding to the given parent Key.


This function reads all objects under the given node, and builds
a tree from the result. The empty binary will result in the whole table
being built as a tree. The returned tree is `[]` if nothing was found, or
a `#conf_tree{}` record, which can be passed to e.g. [`write_tree/3`](#write_tree-3),
[`flatten_tree/1`](#flatten_tree-1), etc.
<a name="set_root-2"></a>

### set_root/2 ###


<pre><code>
set_root(R::<a href="#type-key">key()</a>, Conf_tree::#conf_tree{}) -&gt; #conf_tree{}
</code></pre>

<br></br>


Inserts a new root into a `#conf_tree{}` record.
<a name="shift_root-2"></a>

### shift_root/2 ###


<pre><code>
shift_root(Dirs::<a href="#type-shift_op">shift_op()</a> | [<a href="#type-shift_op">shift_op()</a>], Conf_tree::#conf_tree{}) -&gt; #conf_tree{} | error
</code></pre>

<br></br>



Shifts the config tree root upwards or downwards if possible.


This function allows the root of a config tree to be made longer or shorter,
shifting key parts of the root in or out of the actual tree. For
`shift_root(top, Tree)`, the root will be shifted into the tree until the
remaining root is `<<>>`. For `shift_root(bottom, Tree)`, the root will be
shifted out of the tree, until it is the longest common prefix for all
child nodes in the tree. If the root cannot be shifted any more in a given
direction, `error` is returned.
<a name="split_key-1"></a>

### split_key/1 ###


<pre><code>
split_key(K::<a href="#type-key">key()</a>) -&gt; [<a href="#type-key_part">key_part()</a>]
</code></pre>

<br></br>



Splits a `kvdb_conf` key into a list of (unescaped) key parts.


Examples:
`split_key(<<"=a*=b*=c">>) -> [<<"a">>,<<"b">>,<<"c">>].`
`split_key(<<"=a*=b[00000001]*=c">>) -> [<<"a">>,{<<"b">>,1},<<"c">>]`
<a name="transaction-1"></a>

### transaction/1 ###


<pre><code>
transaction(Fun::fun((<a href="kvdb.md#type-db_ref">kvdb:db_ref()</a>) -&gt; T)) -&gt; T
</code></pre>

<br></br>


Equivalent to [`kvdb:transaction(kvdb_conf_instance(), Fun)`](kvdb.md#transaction-2).
<a name="unescape_key-1"></a>

### unescape_key/1 ###


<pre><code>
unescape_key(K::<a href="#type-key">key()</a>) -&gt; <a href="#type-key">key()</a>
</code></pre>

<br></br>


Unescapes a key.

<a name="unescape_key_part-1"></a>

### unescape_key_part/1 ###


<pre><code>
unescape_key_part(Bin::<a href="#type-key_part">key_part()</a>) -&gt; <a href="#type-key_part">key_part()</a>
</code></pre>

<br></br>



Unescapes a key part; leaving it untouched if already escaped.


See [`escape_key_part/1`](#escape_key_part-1).
<a name="update_counter-2"></a>

### update_counter/2 ###


<pre><code>
update_counter(K::<a href="kvdb.md#type-key">kvdb:key()</a>, Incr::integer()) -&gt; integer() | binary()
</code></pre>

<br></br>


Equivalent to [`update_counter(<<"data">>, Key, Incr)`](#update_counter-3).
<a name="update_counter-3"></a>

### update_counter/3 ###


<pre><code>
update_counter(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, K::<a href="kvdb.md#type-key">kvdb:key()</a>, Incr::integer()) -&gt; integer() | binary()
</code></pre>

<br></br>



Updates a counter with the given increment.



This function can be used to update a counter object (the value part is
assumed to contain the counter value). The counter value can be either
a byte- or bitstring representation of an integer, or a regular integer.
The return value will be the new counter value, of the same type as the
counter itself.


In the case of a byte- or bitstring-encoded counter, the size of the
value is preserved. No overflow check is currently performed.
<a name="write-1"></a>

### write/1 ###


<pre><code>
write(Obj::<a href="#type-conf_obj">conf_obj()</a>) -&gt; ok
</code></pre>

<br></br>


Equivalent to [`write(<<"data">>, Obj)`](#write-2).
<a name="write-2"></a>

### write/2 ###


<pre><code>
write(Tab::<a href="kvdb.md#type-table">kvdb:table()</a>, Obj0::<a href="#type-conf_obj">conf_obj()</a>) -&gt; ok
</code></pre>

<br></br>



Writes a configuration object into the database.



Each node or leaf in the tree is stored as a separate object, so updating
or inserting a node or leaf in the tree is a very cheap operation.


Note that the `kvdb_conf` API only accepts keys of type `binary()`,
even though it allows kvdb_conf tables to select a different key encoding.
<a name="write_tree-2"></a>

### write_tree/2 ###


<pre><code>
write_tree(_Parent::<a href="#type-key">key()</a>, Conf_tree::#conf_tree{}) -&gt; ok
</code></pre>

<br></br>


Equivalent to [`write_tree(<<"data">>, Parent, T)`](#write_tree-3).
<a name="write_tree-3"></a>

### write_tree/3 ###


<pre><code>
write_tree(Table::<a href="kvdb.md#type-table">kvdb:table()</a>, Parent::<a href="#type-key">key()</a>, Conf_tree::#conf_tree{}) -&gt; ok
</code></pre>

<br></br>



Writes a configuration tree under the given parent.


This function inserts a config tree, such as is returned from e.g.
[`read_tree/3`](#read_tree-3). The root to insert it under must be made explicit,
but could of course be the same root as in the original tree
(can be retrieved using [`get_root/1`](#get_root-1)).
<a name="xpath-1"></a>

### xpath/1 ###

`xpath(Expr) -> any()`


<a name="xpath-2"></a>

### xpath/2 ###

`xpath(Tab, Expr) -> any()`


<a name="xpath-3"></a>

### xpath/3 ###

`xpath(Tab, Expr, Limit) -> any()`


