local CreateConnect = {
  ["odbc.dba"] = function()
    local dba = require "odbc.dba"
    local cnn, err = dba.connect{
      Driver   = "SQLite3 ODBC Driver";
      Database = ":memory:";
    }
    return cnn, err
  end;

  ["lsql"] = function()
    local dba = require "dba.luasql".load('sqlite3')
    return dba.Connect(":memory:")
  end;

  ["odbc.luasql"] = function()
    local dba = require "dba"
    local luasql = require "odbc.luasql"
    dba = dba.load(luasql.odbc)
    return dba.Connect("SQLite3memory")
  end
}

local CNN_TYPE = 'lsql'
local CNN_ROWS = 10
local function init_db(cnn)
  local fmt = string.format
  assert(cnn:exec"create table Agent(ID INTEGER PRIMARY KEY, Name char(32))")
  for i = 1, CNN_ROWS do
    assert(cnn:exec(fmt("insert into Agent(ID,NAME)values(%d, 'Agent#%d')", i, i)))
  end
end

local function pack_n(...)
  return { n = select("#", ...), ... }
end

local to_n = tonumber

local lunit = require "lunit"

local lunit    = require "lunit"
local IS_LUA52 = _VERSION >= 'Lua 5.2'

TEST_CASE = function (name)
  if not IS_LUA52 then
    module(name, package.seeall, lunit.testcase)
    setfenv(2, _M)
  else
    return lunit.module(name, 'seeall')
  end
end

local _ENV = TEST_CASE'Connection'

local cnn

function setup()
  cnn = assert(CreateConnect[CNN_TYPE]())
  init_db(cnn)
end

function teardown()
  if cnn then cnn:destroy() end
end

function test_interface()
  assert_function(cnn.connect)
  assert_function(cnn.disconnect)
  assert_function(cnn.connected)
  assert_function(cnn.destroy)
  -- assert_function(cnn.destroyed)
  assert_function(cnn.exec)
  assert_function(cnn.each)
  assert_function(cnn.ieach)
  assert_function(cnn.neach)
  assert_function(cnn.teach)
  assert_function(cnn.first_row)
  assert_function(cnn.first_irow)
  assert_function(cnn.first_nrow)
  assert_function(cnn.first_trow)
  assert_function(cnn.first_value)
  assert_function(cnn.fetch_all)
  assert_function(cnn.rows)
  assert_function(cnn.irows)
  assert_function(cnn.nrows)
  assert_function(cnn.trows)
  assert_function(cnn.commit)
  assert_function(cnn.rollback)
  assert_function(cnn.set_autocommit)
  assert_function(cnn.get_autocommit)
  assert_function(cnn.query)
  assert_function(cnn.prepare)
  assert_function(cnn.handle)
  assert_function(cnn.set_config)
  assert_function(cnn.get_config)
  assert_function(cnn.environment)
end

function test_reconnect()
  assert_true(cnn:connected())
  assert_true(cnn:disconnect())
  assert_false(not not cnn:connected())
  assert_true(not not cnn:connect())
end

function test_each()
  local sql = "select ID, Name from Agent order by ID"
  local n = 0
  cnn:each(sql, function(ID, Name) 
    n = n + 1
    assert_equal(n, to_n(ID))
  end)
  assert_equal(CNN_ROWS, n)

  n = 0
  cnn:ieach(sql, function(row) 
    n = n + 1
    assert_equal(n, to_n(row[1]))
  end)
  assert_equal(CNN_ROWS, n)

  n = 0
  cnn:neach(sql, function(row) 
    n = n + 1
    assert_equal(n, to_n(row.ID))
  end)
  assert_equal(CNN_ROWS, n)

  n = 0
  cnn:teach(sql, function(row) 
    n = n + 1
    assert_equal(n, to_n(row.ID))
    assert_equal(n, to_n(row[1]))
  end)
  assert_equal(CNN_ROWS, n)

  n = 0
  local args = pack_n(cnn:each(sql, function(ID, Name) 
    n = n + 1
    return nil, 1, nil, 2
  end))
  assert_equal(1, n)
  assert_equal(4, args.n)
  assert_equal(1, args[2])
  assert_equal(2, args[4])
  assert_nil(args[1])
  assert_nil(args[3])

  n = 0
  sql = "select ID, Name from Agent where ID > :ID order by ID"
  local par = {ID = 1}
  assert_true(cnn:each(sql, par, function(ID)
    n = n + 1
    assert_equal(par.ID + 1, to_n(ID))
    return true
  end))
  assert_equal(1, n)
end

function test_rows()
  local sql = "select ID, Name from Agent order by ID"
  local n = 0
  for ID, Name in cnn:rows(sql) do
    n = n + 1
    assert_equal(n, to_n(ID))
  end
  assert_equal(CNN_ROWS, n)

  n = 0
  for row in cnn:irows(sql) do
    n = n + 1
    assert_equal(n, to_n(row[1]))
  end
  assert_equal(CNN_ROWS, n)

  n = 0
  for row in cnn:nrows(sql) do
    n = n + 1
    assert_equal(n, to_n(row.ID))
  end
  assert_equal(CNN_ROWS, n)

  n = 0
  for row in cnn:trows(sql) do
    n = n + 1
    assert_equal(n, to_n(row.ID))
    assert_equal(n, to_n(row[1]))
  end
  assert_equal(CNN_ROWS, n)

  n = 0
  sql = "select ID, Name from Agent where ID > :ID order by ID"
  local par = {ID = 1}
  for ID in cnn:rows(sql, par) do
    n = n + 1
    assert_equal(par.ID + 1, to_n(ID))
    break
  end
  assert_equal(1, n)
end

function test_first()
  local sql = "select ID, Name from Agent order by ID"
  local ID, Name = cnn:first_row(sql)
  assert_equal(1, to_n(ID))
  assert_equal("Agent#1", Name)

  local row
  row = cnn:first_nrow(sql)
  assert_equal(1, to_n(row.ID))
  assert_equal("Agent#1", row.Name)

  row = cnn:first_irow(sql)
  assert_equal(1, to_n(row[1]))
  assert_equal("Agent#1", row[2])

  row = cnn:first_trow(sql)
  assert_equal(1, to_n(row[1]))
  assert_equal(1, to_n(row.ID))
  assert_equal("Agent#1", row[2])
  assert_equal("Agent#1", row.Name)

  assert_equal(CNN_ROWS, to_n(cnn:first_value("select count(*) from Agent")))
  assert_equal(CNN_ROWS, to_n(cnn:first_value("select ID from Agent where ID=:ID",{ID=CNN_ROWS})))
end

function test_txn()
  assert_equal(CNN_ROWS, to_n(cnn:first_value("select count(*) from Agent")))
  cnn:set_autocommit(false)
  assert_number(cnn:exec("delete from Agent"))
  assert_equal(0, to_n(cnn:first_value("select count(*) from Agent")))
  cnn:rollback()
  assert_equal(CNN_ROWS, to_n(cnn:first_value("select count(*) from Agent")))
end

function test_rowsaffected()
  assert_equal(CNN_ROWS, to_n(cnn:first_value("select count(*) from Agent")))
end

function test_exec()
  assert_nil(cnn:exec("select ID, Name from Agent order by ID"))
  assert_number(cnn:exec("update Agent set ID=ID"))
end

function test_config()
  local env = assert(cnn:environment())
  local p1 = assert_boolean(env:get_config("FORCE_REPLACE_PARAMS"))
  local p2 = assert_boolean(env:get_config("IGNORE_NAMED_PARAMS") )

  assert_equal(p1, cnn:get_config("FORCE_REPLACE_PARAMS"))
  assert_equal(p2, cnn:get_config("IGNORE_NAMED_PARAMS"))

  env:set_config("FORCE_REPLACE_PARAMS", not p1)
  cnn:set_config("IGNORE_NAMED_PARAMS",  not p2)

  assert_equal( not p1, env:get_config("FORCE_REPLACE_PARAMS") )
  assert_equal(     p2, env:get_config("IGNORE_NAMED_PARAMS")  )
  assert_equal( not p1, cnn:get_config("FORCE_REPLACE_PARAMS") )
  assert_equal( not p2, cnn:get_config("IGNORE_NAMED_PARAMS")  )
  
  cnn:set_config("IGNORE_NAMED_PARAMS", nil)
  assert_equal( p2, cnn:get_config("IGNORE_NAMED_PARAMS")  )
end

local _ENV = TEST_CASE'Query'

local cnn, qry

function setup()
  cnn = assert(CreateConnect[CNN_TYPE]())
  init_db(cnn)
end

function teardown()
  if qry then qry:destroy() end
  if cnn then cnn:destroy() end
end

function test_interface()
  qry = cnn:query()
  assert_function(qry.open)
  assert_function(qry.close)
  assert_function(qry.closed)
  assert_function(qry.opened)
  assert_function(qry.destroy)
  assert_function(qry.destroyed)
  assert_function(qry.exec)
  assert_function(qry.each)
  assert_function(qry.ieach)
  assert_function(qry.neach)
  assert_function(qry.teach)
  assert_function(qry.first_row)
  assert_function(qry.first_irow)
  assert_function(qry.first_nrow)
  assert_function(qry.first_trow)
  assert_function(qry.first_value)
  assert_function(qry.fetch_all)
  assert_function(qry.rows)
  assert_function(qry.irows)
  assert_function(qry.nrows)
  assert_function(qry.trows)
  assert_function(qry.set_autoclose)
  assert_function(qry.get_autoclose)
  assert_function(qry.prepare)
  assert_function(qry.prepared)
  assert_function(qry.unprepare)
  assert_function(qry.supports_prepare)
  assert_function(qry.set_sql)
  assert_function(qry.bind)
  assert_function(qry.handle)
  assert_function(qry.set_config)
  assert_function(qry.get_config)
  assert_function(qry.connection)
end

function test_create()
  local sql = "select ID, Name from Agent order by ID"
  local n
  local function do_test(ID, Name) 
    n = n + 1
    assert_equal(n, to_n(ID))
  end

  n = 0
  qry = assert(cnn:query())
  qry:each(sql, do_test)
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:query(sql))
  qry:each(do_test)
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  sql = "select ID, Name from Agent where 555=cast(:ID as INTEGER) order by ID"
  local par = {ID = 555}

  n = 0
  qry = assert(cnn:query())
  qry:each(sql, par, do_test)
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:query(sql))
  qry:each(par, do_test)
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:query(sql))
  assert_true(qry:bind(par))
  qry:each(do_test)
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  --------------------------------------------------------
  sql = "select ID, Name from Agent order by ID"
  local function do_test(row) 
    n = n + 1
    assert_equal(n, to_n(row.ID))
  end

  n = 0
  qry = assert(cnn:query())
  qry:neach(sql, do_test)
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:query(sql))
  qry:neach(do_test)
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  sql = "select ID, Name from Agent where 555=cast(:ID as INTEGER) order by ID"
  local par = {ID = 555}

  n = 0
  qry = assert(cnn:query())
  qry:neach(sql, par, do_test)
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:query(sql))
  qry:neach(par, do_test)
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:query(sql))
  assert_true(qry:bind(par))
  qry:neach(do_test)
  assert_equal(CNN_ROWS, n)
  qry:destroy()

end

function test_each()
  local sql = "select ID, Name from Agent order by ID"
  local n
  n = 0
  qry = assert(cnn:query())
  qry:each(sql, function(ID)
    n = n + 1 assert_equal(n, to_n(ID))
  end)
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:query())
  assert(qry:open(sql))
  assert_nil(
    qry:each(sql, function(ID)
      n = n + 1 assert_equal(n, to_n(ID))
    end)
  )
  assert_equal(0, n)
  qry:each(function(ID)
    n = n + 1 assert_equal(n, to_n(ID))
  end)
  assert_equal(CNN_ROWS, n)
  qry:destroy()
end

function test_rows()
  local sql = "select ID, Name from Agent order by ID"
  local n

  n = 0
  qry = assert(cnn:query())
  for ID, Name in qry:rows(sql) do
    n = n + 1 assert_equal(n, to_n(ID))
  end
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:query(sql))
  for ID, Name in qry:rows() do
    n = n + 1 assert_equal(n, to_n(ID))
  end
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  sql = "select ID, Name from Agent where 555=cast(:ID as INTEGER) order by ID"
  local par = {ID = 555}

  n = 0
  qry = assert(cnn:query())
  for ID, Name in qry:rows(sql, par) do
    n = n + 1 assert_equal(n, to_n(ID))
  end
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:query(sql))
  for ID, Name in qry:rows(par) do
    n = n + 1 assert_equal(n, to_n(ID))
  end
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:query(sql))
  assert_true(qry:bind(par))
  for ID, Name in qry:rows() do
    n = n + 1 assert_equal(n, to_n(ID))
  end
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  --------------------------------------------------

  sql = "select ID, Name from Agent order by ID"

  n = 0
  qry = assert(cnn:query())
  for row in qry:nrows(sql) do
    n = n + 1 assert_equal(n, to_n(row.ID))
  end
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:query(sql))
  for row in qry:nrows() do
    n = n + 1 assert_equal(n, to_n(row.ID))
  end
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  sql = "select ID, Name from Agent where 555=cast(:ID as INTEGER) order by ID"
  local par = {ID = 555}

  n = 0
  qry = assert(cnn:query())
  for row in qry:nrows(sql, par) do
    n = n + 1 assert_equal(n, to_n(row.ID))
  end
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:query(sql))
  for row in qry:nrows(par) do
    n = n + 1 assert_equal(n, to_n(row.ID))
  end
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:query(sql))
  assert_true(qry:bind(par))
  for row in qry:nrows() do
    n = n + 1 assert_equal(n, to_n(row.ID))
  end
  assert_equal(CNN_ROWS, n)
  qry:destroy()

end

function test_prepare()
  local sql = "select ID, Name from Agent order by ID"
  local n
  local function do_test(ID, Name) 
    n = n + 1
    assert_equal(n, to_n(ID))
  end

  n = 0
  qry = assert(cnn:prepare(sql))
  qry:each(do_test)
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  sql = "select ID, Name from Agent where 555 = cast(:ID as INTEGER) order by ID"
  local par = {ID = 555}

  n = 0
  qry = assert(cnn:prepare(sql))
  qry:each(par, do_test)
  assert_equal(CNN_ROWS, n)
  qry:destroy()

  n = 0
  qry = assert(cnn:prepare(sql))
  assert_true(qry:bind(par))
  qry:each(do_test)
  assert_equal(CNN_ROWS, n)
  qry:destroy()
end

function test_unprepare()
  local sql = "select ID, Name from Agent order by ID"
  qry = assert(cnn:prepare(sql))
  assert_equal(qry:supports_prepare(), qry:prepared())
  assert_true(qry:unprepare())
  assert_false(qry:prepared())
  qry:destroy()
end

function test_destroy()
  qry = assert(cnn:query())
  assert_true(qry:closed())
  assert_false(qry:destroyed())
  qry:open("select ID, Name from Agent order by ID")
  assert_false(qry:closed())
  assert_false(qry:destroyed())
  assert_pass(function() cnn:destroy() end)
  assert_pass(function() qry:closed()  end)
  assert_true(qry:closed())
  assert_true(qry:destroyed())
  assert_pass(function() qry:destroy() end)
end

function test_first()
  local sql = "select ID, Name from Agent order by ID"
  qry = cnn:query()
  local ID, Name = qry:first_row(sql)
  assert_equal(1, to_n(ID))
  assert_equal("Agent#1", Name)

  local row
  row = qry:first_nrow(sql)
  assert_equal(1, to_n(row.ID))
  assert_equal("Agent#1", row.Name)

  row = qry:first_irow(sql)
  assert_equal(1, to_n(row[1]))
  assert_equal("Agent#1", row[2])

  row = qry:first_trow(sql)
  assert_equal(1, to_n(row[1]))
  assert_equal(1, to_n(row.ID))
  assert_equal("Agent#1", row[2])
  assert_equal("Agent#1", row.Name)

  local v = assert(qry:first_value("select count(*) from Agent"))
  assert_equal(CNN_ROWS, to_n(v))
  local v = assert(qry:first_value("select ID from Agent where ID=:ID",{ID=CNN_ROWS}))
  assert_equal(CNN_ROWS, to_n(v))
  qry:destroy()

  sql = "select ID, Name from Agent where ID=:ID"
  local par = {ID=CNN_ROWS}
  local Agent = "Agent#" .. CNN_ROWS

  qry = cnn:prepare(sql)

  ID, Name = qry:first_row(par)
  assert_equal(CNN_ROWS, to_n(ID))
  assert_equal(Agent, Name)

  row = qry:first_nrow(par)
  assert_equal(CNN_ROWS, to_n(row.ID))
  assert_equal(Agent, row.Name)

  row = qry:first_irow(par)
  assert_equal(CNN_ROWS, to_n(row[1]))
  assert_equal(Agent, row[2])

  row = qry:first_trow(par)
  assert_equal(CNN_ROWS, to_n(row[1]))
  assert_equal(CNN_ROWS, to_n(row.ID))
  assert_equal(Agent, row[2])
  assert_equal(Agent, row.Name)

  qry:destroy()

  qry = cnn:prepare(sql)
  assert_true(qry:bind(par))

  ID, Name = qry:first_row()
  assert_equal(CNN_ROWS, to_n(ID))
  assert_equal(Agent, Name)

  row = qry:first_nrow()
  assert_equal(CNN_ROWS, to_n(row.ID))
  assert_equal(Agent, row.Name)

  row = qry:first_irow()
  assert_equal(CNN_ROWS, to_n(row[1]))
  assert_equal(Agent, row[2])

  row = qry:first_trow()
  assert_equal(CNN_ROWS, to_n(row[1]))
  assert_equal(CNN_ROWS, to_n(row.ID))
  assert_equal(Agent, row[2])
  assert_equal(Agent, row.Name)

end

function test_config()
  qry = cnn:query()
  assert_equal(cnn, qry:connection())

  local p1 = assert_boolean(cnn:get_config("FORCE_REPLACE_PARAMS"))
  local p2 = assert_boolean(cnn:get_config("IGNORE_NAMED_PARAMS") )

  assert_equal(p1, qry:get_config("FORCE_REPLACE_PARAMS"))
  assert_equal(p2, qry:get_config("IGNORE_NAMED_PARAMS"))

  cnn:set_config("FORCE_REPLACE_PARAMS", not p1)
  qry:set_config("IGNORE_NAMED_PARAMS",  not p2)

  assert_equal( not p1, cnn:get_config("FORCE_REPLACE_PARAMS") )
  assert_equal(     p2, cnn:get_config("IGNORE_NAMED_PARAMS")  )
  assert_equal( not p1, qry:get_config("FORCE_REPLACE_PARAMS") )
  assert_equal( not p2, qry:get_config("IGNORE_NAMED_PARAMS")  )
  
  qry:set_config("IGNORE_NAMED_PARAMS", nil)
  assert_equal( p2, qry:get_config("IGNORE_NAMED_PARAMS")  )
end

for _, str in ipairs{
  "odbc.dba",
  -- "lsql",
  -- "odbc.luasql",
} do 
  print()
  print("---------------- TEST " .. str)
  CNN_TYPE = str
  lunit.run()
end
