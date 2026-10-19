-- VRFW_HomeStadium: the player team's home stadium for the framework's home matches (docs/framework/types/friendly.md
-- «Player's home stadium»). A mod that keeps a home stadium per team registers a provider; the friendly executor
-- (VRFW_PACHANGA, graft pachanga_core) asks it when a friendly's stadium is left open. Every menu VM; this file runs
-- before the _all files of the mods that load after the framework, so they register at load:
--
--   VRFW_HomeStadium.Register("<mod>.<name>", function(team set) return map crc or 0 end)   -- same id replaces
--   VRFW_HomeStadium.Of(team set) -> map crc (0 = none), id of the provider that answered
--
-- Defines functions only: no engine call at load time.
VRFW_HomeStadium = VRFW_HomeStadium or { providers = {} }
do
  local M = VRFW_HomeStadium
  M.providers = type(M.providers) == "table" and M.providers or {}

  function M.Register(id, fn)
    if type(id) ~= "string" or type(fn) ~= "function" then
      return false
    end
    for _, e in ipairs(M.providers) do
      if e.id == id then
        e.fn = fn
        return true
      end
    end
    table.insert(M.providers, { id = id, fn = fn })
    return true
  end

  function M.Of(set)
    if type(set) ~= "number" or set < 0 then
      return 0
    end
    for _, e in ipairs(M.providers) do
      local ok, map = pcall(e.fn, set)
      if ok and type(map) == "number" and map ~= 0 then
        return map % 4294967296, e.id
      end
    end
    return 0
  end
end
