-- menu_engine: daily renewal (VR-Framework base service `VRFW.Daily`; docs/framework/daily.md). Definitions only (this
-- file runs in every script VM, lua\_all; no engine call at load time). Mechanism only: no content, no UI. Every
-- number comes from the framework's DLL (CMND_VRFW_DAILY_*, the same Rust code as the Rust API), so a draw is the same
-- on every PC and in Rust and Lua.
--
--   VRFW_Daily.Period(kind [, id])          -> id, secondsUntilNext, label   (kind "day" | "week" | "month")
--   VRFW_Daily.Rng(key [, spec])            -> a generator; spec = { Period = "day", Version = 1, Id = <period id> }
--     g:Int(lo, hi)                         -> integer in lo..hi
--     g:Pick(items [, key])                 -> item, index
--     g:Sample(items, n [, key])            -> { items } (n distinct, draw order), { indices }
--     g:Shuffle(items [, key])              -> { items } (all, random order), { indices }
--     g:Weighted(items, weight [, key])     -> item, index   (weight = field name or function(item) -> integer >= 0)
--       key = field name or function(item) -> number / string (default: the item itself). The items are put in the
--       order of their keys first (numbers when every key is an integer, else bytes), so the caller's list order never
--       matters; two items with the same key = an error (nil + logged once).
--   VRFW_Daily.Seed(key [, spec])           -> seed (hex text), id
--   VRFW_Daily.Seen(key [, kind])           -> isNew, previous (-1 = never), current   (records the current period)
--   VRFW_Daily.MarkDone(key [, kind])       -> ok, streak, newlyDone
--   VRFW_Daily.IsDone(key [, kind])         -> done
--   VRFW_Daily.Streak(key [, kind])         -> streak, best, total
--   VRFW_Daily.Status(key [, kind])         -> { done, streak, best, total, lastDone, current, secondsUntilNext }
--   VRFW_Daily.On(kind, fn [, id])          -> registers fn(newId, oldId, kind) for a renewal seen by Poll in this VM
--   VRFW_Daily.Poll()                       -> calls the On handlers of every kind whose id changed since this VM's
--                                              last Poll (the first Poll of a VM only takes the baseline)
--   VRFW_Daily.Watch(stem)                  -> polls from that script's Step (VRFW_Host after-handler, ~every 30 frames)
-- The records (Seen / MarkDone / ...) belong to the game in memory's save slot. Without the DLL every call answers
-- "nothing" (nil / false / 0) and nothing is drawn.
if VRFW_Daily == nil then
  local D = {
    CMD = {
      PERIOD = 2921688063,    -- CMND_VRFW_DAILY_PERIOD (kind [, id]) -> id, secs, label
      SEED = 3647260915,      -- CMND_VRFW_DAILY_SEED (key, kind, version [, id]) -> hex, id, generator
      INT = 621641748,        -- CMND_VRFW_DAILY_INT (key, kind, version, id, cursor, lo, hi) -> value, cursor
      PICK = 70132846,        -- CMND_VRFW_DAILY_PICK (key, kind, version, id, cursor, keys) -> index, cursor
      SAMPLE = 2593522674,    -- CMND_VRFW_DAILY_SAMPLE (..., keys, k) -> "i,j,...", cursor
      SHUFFLE = 1495655670,   -- CMND_VRFW_DAILY_SHUFFLE (..., keys) -> "i,j,...", cursor
      WEIGHTED = 2838960472,  -- CMND_VRFW_DAILY_WEIGHTED (..., keys, weights) -> index, cursor
      SEEN = 967909869,       -- CMND_VRFW_DAILY_SEEN (key, kind) -> isNew, previous, current
      MARK_DONE = 1806895942, -- CMND_VRFW_DAILY_MARK_DONE (key, kind) -> ok, streak, newlyDone
      IS_DONE = 784620553,    -- CMND_VRFW_DAILY_IS_DONE (key, kind) -> done
      STREAK = 1914138136,    -- CMND_VRFW_DAILY_STREAK (key, kind) -> streak, best, total
      STATUS = 278728749,     -- CMND_VRFW_DAILY_STATUS (key, kind) -> done, streak, best, total, lastDone, current, secs
    },
    LOG = 3661580131,         -- CMND_EVT_LOG
    KINDS = { day = true, week = true, month = true },
    handlers = {},            -- handlers[kind] = { { id, fn }, ... }
    last = {},                -- last[kind] = id seen by the last Poll of this VM
    logged = {},
    watched = {},
    frames = 0,
  }
  VRFW_Daily = D

  local function call(cmd, ...)
    local r = table.pack(pcall(funcLuaCommand, cmd, ...))
    if r[1] then
      return table.unpack(r, 2, r.n)
    end
    return nil
  end

  function D.Log(text)
    if not D.logged[text] then
      D.logged[text] = true
      pcall(funcLuaCommand, D.LOG, "VRFW daily " .. text)
    end
  end

  local function kind_of(k)
    if k == nil then
      return "day"
    end
    k = string.lower(tostring(k))
    if D.KINDS[k] then
      return k
    end
    return nil
  end

  function D.Period(kind, id)
    local k = kind_of(kind)
    if k == nil then
      return nil
    end
    local i, secs, label = call(D.CMD.PERIOD, k, id)
    if type(i) ~= "number" or i < 0 and label == "" then
      return nil
    end
    return i, secs, label
  end

  -- ------------------------------------------------------------ generator

  local G = {}
  G.__index = G

  function D.Rng(key, spec)
    spec = spec or {}
    local k = kind_of(spec.Period)
    if type(key) ~= "string" or k == nil then
      D.Log("Rng: a key text and Period day / week / month expected")
      return nil
    end
    local id = spec.Id
    if id == nil then
      id = D.Period(k)   -- pinned: a generator never changes period in the middle of a sequence
    end
    if id == nil then
      return nil
    end
    return setmetatable({ key = key, period = k, version = spec.Version or 1, id = id, cursor = 0 }, G)
  end

  function D.Seed(key, spec)
    spec = spec or {}
    local k = kind_of(spec.Period)
    if k == nil then
      return nil
    end
    local hex, id = call(D.CMD.SEED, key, k, spec.Version or 1, spec.Id)
    if hex == nil or hex == "" then
      return nil
    end
    return hex, id
  end

  -- the result of a draw command: value, new cursor (-1 = error, third value = why)
  local function advance(g, what, v, cursor, err)
    if type(cursor) ~= "number" or cursor < 0 then
      D.Log(what .. " " .. g.key .. ": " .. tostring(err or "no answer (framework DLL missing?)"))
      return nil
    end
    g.cursor = cursor
    return v
  end

  function G:Int(lo, hi)
    local v, c, e = call(D.CMD.INT, self.key, self.period, self.version, self.id, self.cursor, lo, hi)
    return advance(self, "Int", v, c, e)
  end

  local function key_text(item, key)
    local v = item
    if type(key) == "function" then
      v = key(item)
    elseif key ~= nil then
      v = type(item) == "table" and item[key] or nil
    end
    if type(v) == "number" then
      if v ~= math.floor(v) then
        return nil
      end
      return string.format("%.0f", v) -- not "%d": a 32-bit `long` on Windows, ids >= 2^31 raised an error
    elseif type(v) == "string" and not string.find(v, "\n", 1, true) then
      return v
    end
    return nil
  end

  local function keys_of(items, key, what)
    if type(items) ~= "table" then
      D.Log(what .. ": an item list expected")
      return nil
    end
    local t = {}
    for i = 1, #items do
      local s = key_text(items[i], key)
      if s == nil then
        D.Log(what .. ": item " .. i .. " has no integer / text key")
        return nil
      end
      t[i] = s
    end
    return table.concat(t, "\n")
  end

  local function indices(list)
    local t = {}
    for s in string.gmatch(list or "", "%d+") do
      t[#t + 1] = tonumber(s)
    end
    return t
  end

  function G:Pick(items, key)
    local keys = keys_of(items, key, "Pick")
    if keys == nil then
      return nil
    end
    local i, c, e = call(D.CMD.PICK, self.key, self.period, self.version, self.id, self.cursor, keys)
    i = advance(self, "Pick", i, c, e)
    if i == nil or i < 1 then
      return nil
    end
    return items[i], i
  end

  local function many(self, cmd, what, items, keys, ...)
    local list, c, e = call(cmd, self.key, self.period, self.version, self.id, self.cursor, keys, ...)
    list = advance(self, what, list, c, e)
    if list == nil then
      return nil
    end
    local idx = indices(list)
    local out = {}
    for n = 1, #idx do
      out[n] = items[idx[n]]
    end
    return out, idx
  end

  function G:Sample(items, n, key)
    local keys = keys_of(items, key, "Sample")
    if keys == nil then
      return nil
    end
    return many(self, D.CMD.SAMPLE, "Sample", items, keys, n)
  end

  function G:Shuffle(items, key)
    local keys = keys_of(items, key, "Shuffle")
    if keys == nil then
      return nil
    end
    return many(self, D.CMD.SHUFFLE, "Shuffle", items, keys)
  end

  function G:Weighted(items, weight, key)
    local keys = keys_of(items, key, "Weighted")
    if keys == nil then
      return nil
    end
    local w = {}
    for i = 1, #items do
      local x = items[i]
      local v
      if type(weight) == "function" then
        v = weight(x)
      elseif type(x) == "table" then
        v = x[weight]
      end
      if type(v) ~= "number" or v < 0 or v ~= math.floor(v) then
        D.Log("Weighted: item " .. i .. " has no integer weight >= 0")
        return nil
      end
      w[i] = string.format("%.0f", v)
    end
    local i, c, e = call(D.CMD.WEIGHTED, self.key, self.period, self.version, self.id, self.cursor, keys, table.concat(w, "\n"))
    i = advance(self, "Weighted", i, c, e)
    if i == nil or i < 1 then
      return nil
    end
    return items[i], i
  end

  -- ------------------------------------------------------------ per-slot records

  function D.Seen(key, kind)
    local isNew, prev, cur = call(D.CMD.SEEN, key, kind_of(kind) or "")
    return isNew == true, prev or -1, cur or -1
  end

  function D.MarkDone(key, kind)
    local ok, streak, newly = call(D.CMD.MARK_DONE, key, kind_of(kind) or "")
    return ok == true, streak or 0, newly == true
  end

  function D.IsDone(key, kind)
    return call(D.CMD.IS_DONE, key, kind_of(kind) or "") == true
  end

  function D.Streak(key, kind)
    local s, b, t = call(D.CMD.STREAK, key, kind_of(kind) or "")
    return s or 0, b or 0, t or 0
  end

  function D.Status(key, kind)
    local done, s, b, t, last, cur, secs = call(D.CMD.STATUS, key, kind_of(kind) or "")
    return {
      done = done == true, streak = s or 0, best = b or 0, total = t or 0, lastDone = last or -1, current = cur or -1,
      secondsUntilNext = secs or 0,
    }
  end

  -- ------------------------------------------------------------ renewal callbacks

  function D.On(kind, fn, id)
    local k = kind_of(kind)
    if k == nil or type(fn) ~= "function" then
      return false
    end
    local list = D.handlers[k] or {}
    D.handlers[k] = list
    if id ~= nil then
      for i = 1, #list do
        if list[i].id == id then
          list[i].fn = fn
          return true
        end
      end
    end
    list[#list + 1] = { id = id, fn = fn }
    return true
  end

  function D.Poll()
    for _, k in ipairs({ "day", "week", "month" }) do
      local list = D.handlers[k]
      if list ~= nil and #list > 0 then
        local id = D.Period(k)
        local old = D.last[k]
        if id ~= nil then
          D.last[k] = id
          if old ~= nil and old ~= id then
            for i = 1, #list do
              local ok, err = pcall(list[i].fn, id, old, k)
              if not ok then
                D.Log("On " .. k .. " handler " .. tostring(list[i].id or i) .. " failed: " .. tostring(err))
              end
            end
          end
        end
      end
    end
  end

  function D.Watch(stem)
    if D.watched[stem] or type(VRFW_Host) ~= "table" or type(VRFW_Host.on) ~= "function" then
      return false
    end
    D.watched[stem] = true
    VRFW_Host.on(stem, "Step", {
      id = "vrfw.daily_poll", phase = "after",
      fn = function()
        D.frames = D.frames + 1
        if D.frames >= 30 then
          D.frames = 0
          D.Poll()
        end
      end,
    })
    return true
  end
end
