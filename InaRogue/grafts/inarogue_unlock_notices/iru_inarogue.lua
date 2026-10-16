-- EVT rogue_unlocks (docs/game/modes/inarogue-unlocks.md): INAROGUE's notice when a card for the office unlocks.
-- Appended at the END of evt_inarogue_menu (graft inarogue_unlock_notices, after inarogue / rogue_shop), so the menu's
-- top-level locals (Message, Log) are in scope. The loader evaluates the unlock conditions itself (a won node, a run
-- end); here the unlocks not announced yet (CMND_EVT_RU_NEWS 0, marked announced by the loader) are shown, one retail
-- message each, before the route map opens again and after a match (a lost run never reopens the map). The script
-- reports news only while Inazuma Fantasy's office INAROGUE page is there (state fantasy.office.inarogue_page). Only inside
-- the menu's coroutine (Message yields). Nothing here calls the engine at load time.
do
  local RU = {
    NEWS = 2363800727,   -- CMND_EVT_RU_NEWS (0 = INAROGUE) -> n, name1 .. nameN
    TEXT = "¡Desbloqueado: %s!\nYa puedes ficharlo en la Oficina de fichajes del modo normal (página «INAROGUE»).",
  }
  local function in_coroutine()
    local co, main = coroutine.running()
    return co ~= nil and not main
  end
  -- every unlock INAROGUE has not announced yet: one message each (the retail system window)
  function EVT_RU_Announce(why)
    if not in_coroutine() or type(Message) ~= "function" then
      return 0
    end
    local r = table.pack(pcall(funcLuaCommand, RU.NEWS, 0))
    if not r[1] or type(r[2]) ~= "number" or r[2] <= 0 then
      return 0
    end
    local n = 0
    for i = 1, r[2] do
      local name = r[2 + i]
      if type(name) == "string" and name ~= "" then
        if type(Log) == "function" then
          Log("unlock notice", why, name)
        end
        Message(string.format(RU.TEXT, name))
        n = n + 1
      end
    end
    return n
  end
  if type(IRM_OpenMap) == "function" then
    local prev = IRM_OpenMap
    function IRM_OpenMap(...)
      EVT_RU_Announce("map")
      return prev(...)
    end
  end
  if type(IRM_AfterMatch) == "function" then
    local prev = IRM_AfterMatch
    function IRM_AfterMatch(...)
      local r = table.pack(prev(...))
      EVT_RU_Announce("after match")
      return table.unpack(r, 1, r.n)
    end
  end
end
