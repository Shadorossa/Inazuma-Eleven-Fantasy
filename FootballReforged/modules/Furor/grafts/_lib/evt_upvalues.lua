-- EVT upvalue helpers for lua_patch files (docs/game/engine/lua-patches.md "Locales del chunk retail"). A retail
-- chunk is stripped bytecode: its main-chunk locals are reachable only as upvalues of its global functions. The
-- loader gives every VM that runs patch files EVT_DEBUG = the engine's own Lua 5.2 debug library; without it (an old
-- loader, [lua_patch] debug_lib = false, a rebuilt full file) both helpers return nil and the caller skips its change.
--   EVT_UpvalueFind(names, pred): the first table upvalue for which pred(t) is true, searched in the global
--     functions `names` (in order) and, through function upvalues (wrappers of earlier patches), up to 4 levels deep;
--     returns table, owner function, upvalue index.
--   EVT_UpvalueJoin(newf, oldf): binds every upvalue of newf (a function this patch defines from the retail text) to
--     the upvalue of the same index of oldf (the retail closure), so newf shares the retail chunk's locals. The build
--     checks both have the same upvalues in the same order; here a different count is an error (nothing joined).
local EVT_D = EVT_DEBUG

local function EVT_UpvalueFind(names, pred)
  if EVT_D == nil then
    return nil
  end
  local seen = {}
  local function scan(f, depth)
    if type(f) ~= "function" or seen[f] or depth > 4 then
      return nil
    end
    seen[f] = true
    local i = 1
    while true do
      local n, v = EVT_D.getupvalue(f, i)
      if n == nil then
        return nil
      end
      if type(v) == "table" and pred(v) then
        return v, f, i
      end
      if type(v) == "function" then
        local t, o, k = scan(v, depth + 1)
        if t ~= nil then
          return t, o, k
        end
      end
      i = i + 1
    end
  end
  for _, name in ipairs(names) do
    local t, o, k = scan(rawget(_ENV, name), 0)
    if t ~= nil then
      return t, o, k
    end
  end
  return nil
end

local function EVT_UpvalueJoin(newf, oldf)
  if EVT_D == nil or type(newf) ~= "function" or type(oldf) ~= "function" then
    return nil
  end
  local n = 0
  while EVT_D.getupvalue(newf, n + 1) ~= nil do
    n = n + 1
  end
  local m = 0
  while EVT_D.getupvalue(oldf, m + 1) ~= nil do
    m = m + 1
  end
  if n ~= m then
    error(string.format("EVT_UpvalueJoin: %d upvalue(s) against %d in the retail function", n, m), 2)
  end
  for i = 1, n do
    EVT_D.upvaluejoin(newf, i, oldf, i)
  end
  return n
end
