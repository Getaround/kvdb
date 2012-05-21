

#Module kvdb_schema#
* [Function Index](#index)
* [Function Details](#functions)






__This module defines the `kvdb_schema` behaviour.__
<br></br>
 Required callback functions: `validate/3`, `validate_attr/3`, `on_update/4`.<a name="index"></a>

##Function Index##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#behaviour_info-1">behaviour_info/1</a></td><td></td></tr><tr><td valign="top"><a href="#on_update-4">on_update/4</a></td><td></td></tr><tr><td valign="top"><a href="#read-1">read/1</a></td><td></td></tr><tr><td valign="top"><a href="#read-2">read/2</a></td><td></td></tr><tr><td valign="top"><a href="#validate-3">validate/3</a></td><td></td></tr><tr><td valign="top"><a href="#validate_attr-3">validate_attr/3</a></td><td></td></tr><tr><td valign="top"><a href="#write-2">write/2</a></td><td></td></tr></table>


<a name="functions"></a>

##Function Details##

<a name="behaviour_info-1"></a>

###behaviour_info/1##




`behaviour_info(X1) -> any()`

<a name="on_update-4"></a>

###on_update/4##




`on_update(Op, Db, Table, Obj) -> any()`

<a name="read-1"></a>

###read/1##




`read(Db) -> any()`

<a name="read-2"></a>

###read/2##




`read(Db, Item) -> any()`

<a name="validate-3"></a>

###validate/3##




`validate(Db, Type, Obj) -> any()`

<a name="validate_attr-3"></a>

###validate_attr/3##




`validate_attr(Db, Type, Attr) -> any()`

<a name="write-2"></a>

###write/2##




`write(Db, Schema) -> any()`
