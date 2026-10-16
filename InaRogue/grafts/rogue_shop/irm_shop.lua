-- EVT rogue_shop (docs/game/modes/inarogue-avatars.md): the INAROGUE menu's «Tienda» tile and the hand-over of the
-- Rogue points the run earned. Appended at the END of evt_inarogue_menu (graft rogue_shop, after inarogue), so the
-- menu's top-level locals (OpenChild, RequestSave, SL) are in scope. Nothing here calls the engine at load time.
-- Hook (the menu's «Tienda» tile, ItemText / Dispatch): EVT_IR_EXTRA.shop = {text = fn() -> label, open = fn()}.
do
  local SH = {
    MENU = 2441995583,            -- evt_rogue_shop_menu (research/grafts/rogue_shop/evt_rogue_shop_menu.lua)
    TEXT = "Tienda",
    MISSING = "Falta la pantalla de la tienda (evt_rogue_shop_menu). Reinstala Inazuma Fantasy.",
    POINTS = 622568634,           -- CMND_EVT_RL_POINTS () -> pending, earned, given, spent, itemKey, itemIdGuess, enabled, active
    GIVEN = 3018215530,           -- CMND_EVT_RL_POINTS_GIVEN (n) -> code, pendingLeft
    REG_FIND = 2175579023,        -- CMND_VRFW_REG_FIND ("item", key) -> id
    ITEM_NUM = 2011560392,        -- CMND_GET_ITEM_NUM (item, false)
    ADD_ITEM = 1897915498,        -- CMND_ADD_ITEM_ONLY (item, n, window)
    LOG = 3661580131,
  }
  local function cmd(...)
    local r = table.pack(pcall(funcLuaCommand, ...))
    if not r[1] then
      return nil
    end
    return table.unpack(r, 2, r.n)
  end
  -- the Rogue points the loader holds as «pending» go into the INAROGUE save's bag (slot 4 only); returns the points
  function EVT_RP_Flush(why)
    local pending, _, _, _, key, guess, _, active = cmd(SH.POINTS)
    if type(pending) ~= "number" or pending <= 0 or active ~= true then
      return 0
    end
    local id = cmd(SH.REG_FIND, "item", key)
    if type(id) ~= "number" or id <= 0 then
      id = guess
    end
    if type(id) ~= "number" or id <= 0 then
      return 0
    end
    local before = tonumber(cmd(SH.ITEM_NUM, id, false)) or 0
    cmd(SH.ADD_ITEM, id, pending, false)
    local added = math.max(0, (tonumber(cmd(SH.ITEM_NUM, id, false)) or 0) - before)
    if added > 0 then
      cmd(SH.GIVEN, added)
      if type(RequestSave) == "function" then
        RequestSave("rogue points")
      end
    end
    cmd(SH.LOG, "inarogue", "rogue points", why, "pending", pending, "added", added)
    return added
  end

  EVT_IR_EXTRA = EVT_IR_EXTRA or {}
  EVT_IR_EXTRA.shop = {
    text = function() return SH.TEXT end,
    open = function()
      if type(SL) == "table" and not SL.rogue and type(IRM_EnterRogue) == "function" then
        IRM_EnterRogue()          -- like every other entry: outside slot 4 it enters the INAROGUE save first
        return
      end
      EVT_RP_Flush("shop")
      if type(OpenChild) == "function" then
        OpenChild(SH.MENU, SH.MISSING)
      else
        funcLuaCommand(433545986 --[[CMND_OPEN_MENU_OBJECT]], SH.MENU)
      end
    end,
  }

  -- the points a won / lost match earned reach the bag before the map opens again / when the run is over
  if type(IRM_OpenMap) == "function" then
    local prev = IRM_OpenMap
    function IRM_OpenMap(...)
      EVT_RP_Flush("map")
      return prev(...)
    end
  end
  if type(IRM_AfterMatch) == "function" then
    local prev = IRM_AfterMatch
    function IRM_AfterMatch(...)
      local r = table.pack(prev(...))
      EVT_RP_Flush("after match")
      return table.unpack(r, 1, r.n)
    end
  end
end
