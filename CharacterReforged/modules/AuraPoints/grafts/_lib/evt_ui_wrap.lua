local function UiOn(flag)
  return EVT_UI_PRESET ~= "off" and EVT_UI_FLAGS[flag] == true
end

local function Pack(...)
  return { n = select("#", ...), ... }
end

-- Probe: evt_loader\loader.log through the loader's CMND_EVT_LOG (3661580131); max 30 lines per menu.
local EVT_UI_LOG_N = 0
local function UiLog(...)
  if EVT_UI_LOG_N >= 30 then
    return
  end
  EVT_UI_LOG_N = EVT_UI_LOG_N + 1
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring((select(i, ...)))
  end
  if type(funcLuaCommand) == "function" then
    pcall(funcLuaCommand, 3661580131, "EVT_UI @TAG@ " .. table.concat(parts, " "))
  end
end

-- funcLuaMenuCommand wrapper. The engine registers funcLuaMenuCommand only after the menu chunk (and this graft)
-- ran, so the wrapper is installed from a __newindex hook on the globals (any earlier __newindex hook of another
-- graft or mod is kept and called: the hooks chain).
-- UiMenuFilter(orig, id, ...) is defined by the menu part; it returns nil (not handled) or a Pack of results.
-- one registry per graft tag: two ui_clean blocks in the same menu (different tags) both wrap, a graft that runs
-- several times (an INCLUDE loaded again) wraps only once
EVT_UI_WRAPPERS_BY = EVT_UI_WRAPPERS_BY or {}
EVT_UI_WRAPPERS_BY["@TAG@"] = EVT_UI_WRAPPERS_BY["@TAG@"] or {}
local EVT_UI_WRAPPERS = EVT_UI_WRAPPERS_BY["@TAG@"]
local function UiInstallMenuWrap(f, filter)
  if type(f) ~= "function" or EVT_UI_WRAPPERS[f] then
    return f
  end
  local w = function(id, ...)
    if EVT_UI_PRESET ~= "off" then
      local r = filter(f, id, ...)
      if r ~= nil then
        return table.unpack(r, 1, r.n)
      end
    end
    return f(id, ...)
  end
  EVT_UI_WRAPPERS[w] = true
  return w
end

local function UiHookMenuCommand(filter)
  if type(rawget(_ENV, "funcLuaMenuCommand")) == "function" then
    rawset(_ENV, "funcLuaMenuCommand", UiInstallMenuWrap(rawget(_ENV, "funcLuaMenuCommand"), filter))
    return
  end
  local mt = getmetatable(_ENV)
  if mt == nil then
    mt = {}
    setmetatable(_ENV, mt)
  end
  local prev = mt.__newindex
  mt.__newindex = function(t, k, v)
    if k == "funcLuaMenuCommand" then
      v = UiInstallMenuWrap(v, filter)
    end
    if prev == nil then
      rawset(t, k, v)
    elseif type(prev) == "function" then
      prev(t, k, v)
    else
      prev[k] = v
    end
  end
end

-- Wrap a menu callback (OnSetupLayer, OnOpenLayer, ...) that the chunk already defined: retail first, then `after`.
local function UiWrapCallback(name, after)
  local orig = rawget(_ENV, name)
  if type(orig) ~= "function" then
    return false
  end
  rawset(_ENV, name, function(...)
    local r = Pack(orig(...))
    local ok, err = pcall(after, ...)
    if not ok then
      UiLog("error", name, err)
    end
    return table.unpack(r, 1, r.n)
  end)
  return true
end
