-- VRFW pick cards, game Lua side (every menu VM; script side scripts\pick_cards.lua; docs/framework/pick-cards.md).
-- Opens the «pick 1 of N» screen vrfw_pick_cards_menu on the cards a mod's script set (PickCards.Set) and waits for
-- it, inside the caller's coroutine (as VRFW_PoseRow.Open): the caller's layers named in `opts.hide` are hidden while
-- it is up.
--   VRFW_PickCards.Show([opts]) -> the picked card (1..n), 0 = skipped / Back, nil = not opened (no cards set, or not
--                                  in a coroutine)
--     opts  hide = { layer crc… } layers of the caller hidden meanwhile (each visible instance; shown again after)
-- No engine call at load time.
if VRFW_PickCards == nil then
  local K = {
    MENU = 234125520,            -- crc32("vrfw_pick_cards_menu")
    KEY_PICK = 3913043416,       -- crc32("vrfw_pick_cards_pick"): parameter out, the picked card (0 = skip)
    CARDS = VRFW_Cmd.VRFW_PICK_CARDS,           -- CMND_VRFW_PICK_CARDS (0) -> the set's header
    OPEN_MENU = VRFW_Cmd.OPEN_MENU_OBJECT,       -- CMND_OPEN_MENU_OBJECT
    IS_MENU = VRFW_Cmd.IS_EXIST_MENU_OBJECT,        -- CMND_IS_EXIST_MENU_OBJECT (funcLuaMenuCommand)
    START_WAIT = 60,             -- frames the screen may take to appear
  }
  VRFW_PickCards = K

  function K.Log(...)
    if PRINT ~= nil then pcall(PRINT, "VRFW_PICK_CARDS", ...) end
  end

  local function up()
    local ok, r = pcall(funcLuaMenuCommand, K.IS_MENU, K.MENU)
    return ok and r == true
  end

  local function take()
    local v = VRFW_Param.Take(K.KEY_PICK)
    if v == nil then
      return 0
    end
    v = math.floor(tonumber(v) or 0)
    if v >= 2147483648 then
      v = v - 4294967296
    end
    return math.max(v, 0)
  end

  function K.Show(opts)
    opts = opts or {}
    if coroutine.running() == nil then
      K.Log("show: not in a coroutine")
      return nil
    end
    local okh, head = pcall(funcLuaCommand, K.CARDS, 0)
    if not okh or type(head) ~= "table" or (tonumber(head.count) or 0) <= 0 then
      K.Log("show: no cards set")
      return nil
    end
    VRFW_Param.Clear(K.KEY_PICK)
    local hidden = VRFW_PoseRow ~= nil and VRFW_PoseRow.HideLayers(opts.hide) or {}
    pcall(funcLuaCommand, K.OPEN_MENU, K.MENU)
    local t = 0
    while not up() and t < K.START_WAIT do
      t = t + 1
      coroutine.yield()
    end
    local opened = up()
    while up() do
      coroutine.yield()
    end
    if VRFW_PoseRow ~= nil then VRFW_PoseRow.ShowLayers(hidden) end
    local pick = take()
    K.Log("show", opened and "shown" or "never shown", "cards", tostring(head.count), "pick", pick)
    if not opened then return nil end
    return pick
  end
end
