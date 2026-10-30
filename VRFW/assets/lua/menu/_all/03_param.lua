-- VRFW_Param: the engine's parameter store (values handed from one menu to another). A key is a number (a crc32) or a
-- name text (its crc32 is used). Numbers and booleans only: a string is stored as a pointer into the caller's VM.
-- Every call is in pcall: a failed command answers nil / false. Definitions only: no engine call at load.
--   VRFW_Param.Has(key)                 -> true when the key is set
--   VRFW_Param.Get(key)                 -> the value; nil when the key is not set
--   VRFW_Param.Set(key, value, kind)    sets the value. kind nil = whole number kept as unsigned 32-bit (ids, handles);
--                                       "plain" = no kind argument (the engine's default: booleans, small numbers)
--   VRFW_Param.Replace(key, value, kind) Clear, then Set
--   VRFW_Param.Clear(key)               removes the key
--   VRFW_Param.Take(key)                -> the value, and the key removed; nil when the key is not set
--   VRFW_Param.SetU32(name, n)          a 32-bit id as two 16-bit values under name_hi / name_lo (each Replace)
--   VRFW_Param.GetU32(name)             -> the id written by SetU32; nil when either half is not set
if VRFW_Param == nil then
  local names = {}

  local function key_of(key)
    if type(key) ~= "string" then
      return key
    end
    local id = names[key]
    if id == nil then
      id = VRFW_Crc32(key)
      names[key] = id
    end
    return id
  end

  local function command(...)
    local f = _ENV.funcLuaCommand
    if type(f) ~= "function" then
      return false, nil
    end
    return pcall(f, ...)
  end

  local P = {}

  function P.Has(key)
    local ok, has = command(VRFW_Cmd.PARAM_HAS, key_of(key))
    return ok and has == true
  end

  local function read(id)
    local ok, value = command(VRFW_Cmd.PARAM_GET, id)
    if ok then
      return value
    end
    return nil
  end

  function P.Get(key)
    local id = key_of(key)
    if not P.Has(id) then
      return nil
    end
    return read(id)
  end

  function P.Set(key, value, kind)
    if kind == "plain" then
      command(VRFW_Cmd.PARAM_SET, key_of(key), 0, value)
    else
      command(VRFW_Cmd.PARAM_SET, key_of(key), 0, value, 1)
    end
  end

  function P.Clear(key)
    command(VRFW_Cmd.PARAM_DELETE, key_of(key))
  end

  function P.Replace(key, value, kind)
    local id = key_of(key)
    P.Clear(id)
    P.Set(id, value, kind)
  end

  function P.Take(key)
    local id = key_of(key)
    if not P.Has(id) then
      return nil
    end
    local value = read(id)
    P.Clear(id)
    return value
  end

  function P.SetU32(name, n)
    n = math.floor(tonumber(n) or 0) % 4294967296
    P.Replace(name .. "_hi", math.floor(n / 65536))
    P.Replace(name .. "_lo", n % 65536)
  end

  function P.GetU32(name)
    local hi, lo = tonumber(P.Get(name .. "_hi")), tonumber(P.Get(name .. "_lo"))
    if hi == nil or lo == nil then
      return nil
    end
    return (hi % 65536) * 65536 + lo % 65536
  end

  VRFW_Param = P
end
