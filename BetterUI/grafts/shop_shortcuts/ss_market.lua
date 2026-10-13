-- EVT shop_shortcuts, Mercado side (Clean HUD feature «Atajos de tienda», the mod shop_shortcuts until 2026-10-08; docs/game/ui/l2r2-cycle.md). The Mercado is the host of its
-- shops: while its own OnDecideFocus waits for the entry it opened (a shop, or Inazuma Fantasy's office), it writes
-- CLEAN_HUD_SS_HOST_KEY = 1 so the shop (ss_buy.lua) / the office hub (ss_office.lua) may leave with L2 / R2.
-- Direct switch (29/09, Nacho's video: the Mercado list showed between two shops): when the retail OnDecideFocus comes
-- back from an entry left with L2 / R2 (the direction is still in CLEAN_HUD_SS_KEY), the lines it runs to bring the list back
-- (show the Mercado, make it active, its button guide, its «Mercado» title in the header) are skipped by a
-- funcLuaMenuCommand wrapper, and this wrapper opens the next / previous entry (wrapping; Mercado list order) through
-- the same OnDecideFocus right away, in the same coroutine: close of the old shop -> open of the next one, nothing of
-- the Mercado in between. Leaving a shop with B runs the retail lines untouched. A shop cannot swap its goods in place:
-- the engine builds the tabs and the list from the shop id when shop_menu opens (SetShopInfo / OnShopInit are called
-- by nie.exe; no Lua command rebuilds them), so the shop menu itself is still closed and opened again.
-- Wrappers only (OnInit, OnDecideFocus, Step, funcLuaMenuCommand from OnInit / Step); nothing runs at chunk load.
CLEAN_HUD_SS_KEY = 3425095194 --[[crc32 evt_shop_cycle_dir: 1 = next, 2 = previous]]
CLEAN_HUD_SS_HOST_KEY = 797210455 --[[crc32 evt_shop_cycle_host: 1 = this Mercado waits for its entry]]
CLEAN_HUD_SS_LIST = 536841765 --[[shop01_21_market_list_item]]
CLEAN_HUD_SS_MARKET = 839500579 --[[market_menu]]
CLEAN_HUD_SS_HEADER = 575058101 --[[mainmenu90_01_header]]
CLEAN_HUD_SS_GUIDE = 9396745 --[[mainmenu01_07_button_guide]]
CLEAN_HUD_SS_GONE = {3170360552 --[[shop_menu]], 713974531 --[[shop_menu_basara_top]], 1970579282 --[[soccer_vs_cpu_list_menu]]}
CLEAN_HUD_SS_MWAIT = 900 -- frames to wait for the old entry to close (a shop inside the office closes after the office)
CLEAN_HUD_SS_M = {depth = 0, wrapped = false, muted = 0}

function CLEAN_HUD_SS_MLog(...)
  pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "EVT shop_shortcuts market", ...)
end

function CLEAN_HUD_SS_MHas(k)
  return funcLuaCommand(2947612279, k) == true
end

function CLEAN_HUD_SS_MTake(k)
  if not CLEAN_HUD_SS_MHas(k) then
    return nil
  end
  local v = funcLuaCommand(3522198769, k)
  funcLuaCommand(3363400568, k)
  return v
end

function CLEAN_HUD_SS_MSet(k, v)
  if CLEAN_HUD_SS_MHas(k) then
    funcLuaCommand(3363400568, k)
  end
  if v ~= nil then
    funcLuaCommand(3860611758, k, 0, v, 1)
  end
end

-- the retail OnDecideFocus is coming back from an entry left with L2 / R2
function CLEAN_HUD_SS_MHold()
  return CLEAN_HUD_SS_M.depth > 0 and CLEAN_HUD_SS_MHas(CLEAN_HUD_SS_KEY)
end

-- the retail lines that bring the Mercado back after an entry (market_menu OnDecideFocus, after its waitFalse)
function CLEAN_HUD_SS_MMuted(c, a, b)
  if a == CLEAN_HUD_SS_MARKET then
    return c == 66378409 --[[show menu]] or (c == 1558704558 --[[menu active]] and b == true)
      or c == 2209673388 or c == 452337289 --[[its button guide]]
  end
  if a == CLEAN_HUD_SS_HEADER then
    return c == 1083631230 --[[title text «Mercado»]] or c == 3405944500 --[[hide the header icon]]
  end
  return c == 2171393651 and a == CLEAN_HUD_SS_GUIDE and b == true
end

function CLEAN_HUD_SS_MInstall()
  local real = funcLuaMenuCommand
  if CLEAN_HUD_SS_M.wrapped or type(real) ~= "function" then
    return
  end
  CLEAN_HUD_SS_M.wrapped = true
  -- 30/09 (frozen Mercado): pass the call on with EXACTLY the arguments it got (real(...)). The first version was
  -- function(c, a, b, ...) -> real(c, a, b, ...), which pads every short call with explicit nils: the engine's
  -- dispatcher hands the handler lua_gettop - 1 arguments, and multi-arity commands read the padding as a real
  -- argument. CMND_GET_CREATE_LAYER_NUM(list) became (list, nil, nil) = "layer count of list in menu object 0" -> 0,
  -- so the Mercado list was set up with 0 focusable entries: cursor stuck on the first bar (drawn at the token-shop
  -- locator, over its label), no up / down, no Aceptar (only Esc, OnFunction, still worked).
  funcLuaMenuCommand = function(...)
    if CLEAN_HUD_SS_M.depth > 0 then
      local c, a, b = ...
      if CLEAN_HUD_SS_MMuted(c, a, b) and CLEAN_HUD_SS_MHold() then
        CLEAN_HUD_SS_M.muted = CLEAN_HUD_SS_M.muted + 1
        return nil
      end
    end
    return real(...)
  end
end

-- list index of the next / previous entry (wrapping), nil when there is no other one
function CLEAN_HUD_SS_MNext(idx, v)
  local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], CLEAN_HUD_SS_LIST)
  if type(n) ~= "number" or n < 2 or type(idx) ~= "number" then
    CLEAN_HUD_SS_MLog("no other entry", tostring(n), tostring(idx))
    return nil
  end
  return (idx + (v == 1 and 1 or -1)) % n
end

-- the entry that was left is gone and no fade is running
function CLEAN_HUD_SS_MReady()
  for _, m in ipairs(CLEAN_HUD_SS_GONE) do
    if funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], m) == true then
      return false
    end
  end
  return funcLuaCommand(1215256347 --[[CMND_BRIGHT_IS_FADE]]) ~= true and funcLuaCommand(316436678) ~= true
end

-- a switch that cannot go on: the Mercado back on screen (the retail lines CLEAN_HUD_SS_MMuted skipped)
function CLEAN_HUD_SS_MRestore()
  local text_get = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 605995789)
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], CLEAN_HUD_SS_HEADER, 1220590795 --[[_text_sub_title02]], text_get, 0)
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], CLEAN_HUD_SS_HEADER, 1152304044 --[[_icon_header_main_dmy01]], false, 0)
  funcLuaMenuCommand(2171393651, CLEAN_HUD_SS_GUIDE, true)
  funcLuaMenuCommand(1558704558, CLEAN_HUD_SS_MARKET, true)
  funcLuaMenuCommand(66378409, CLEAN_HUD_SS_MARKET)
  if type(UpdateButtonGuide) == "function" then
    pcall(UpdateButtonGuide)
  end
end

do
  local init = OnInit
  function OnInit(...)
    local ok, err = pcall(function()
      CLEAN_HUD_SS_MInstall()
      -- keys left by a Mercado that closed while it waited (the office's trial match) mean nothing to this one
      CLEAN_HUD_SS_MTake(CLEAN_HUD_SS_KEY)
      CLEAN_HUD_SS_MTake(CLEAN_HUD_SS_HOST_KEY)
    end)
    if not ok then
      CLEAN_HUD_SS_MLog("error", tostring(err))
    end
    CLEAN_HUD_SS_M.depth = 0
    return init(...)
  end
  local decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    -- not the list, or the switch below calling OnDecideFocus again: the retail path as it is
    if a1 ~= CLEAN_HUD_SS_LIST or CLEAN_HUD_SS_M.depth > 0 then
      return decide(a1, a2, ...)
    end
    pcall(CLEAN_HUD_SS_MInstall)
    CLEAN_HUD_SS_M.depth = 1
    pcall(CLEAN_HUD_SS_MSet, CLEAN_HUD_SS_HOST_KEY, 1)
    local idx = a2
    local r = table.pack(pcall(decide, a1, a2, ...))
    while r[1] do
      local okv, v = pcall(CLEAN_HUD_SS_MHas, CLEAN_HUD_SS_KEY)
      if okv and v then
        v = funcLuaCommand(3522198769, CLEAN_HUD_SS_KEY)
      else
        v = nil
      end
      if v ~= 1 and v ~= 2 then
        break -- left with B (or the office's trial match): the retail lines already ran
      end
      local nxt = CLEAN_HUD_SS_MNext(idx, v)
      local f = 0
      while f < CLEAN_HUD_SS_MWAIT and not CLEAN_HUD_SS_MReady() do
        f = f + 1
        coroutine.yield()
      end
      CLEAN_HUD_SS_MTake(CLEAN_HUD_SS_KEY)
      if nxt == nil or f >= CLEAN_HUD_SS_MWAIT then
        CLEAN_HUD_SS_MLog("switch cancelled", tostring(idx), tostring(nxt), f)
        CLEAN_HUD_SS_MRestore()
        break
      end
      CLEAN_HUD_SS_MLog("switch", idx, "->", nxt, "muted", CLEAN_HUD_SS_M.muted, "waited", f)
      CLEAN_HUD_SS_M.muted = 0
      idx = nxt
      -- through the wrappers above this one (this one passes it straight on: depth > 0)
      r = table.pack(pcall(OnDecideFocus, a1, nxt))
    end
    CLEAN_HUD_SS_M.depth = 0
    pcall(CLEAN_HUD_SS_MSet, CLEAN_HUD_SS_HOST_KEY, nil)
    if not r[1] then
      error(r[2], 0)
    end
    return table.unpack(r, 2, r.n)
  end
  local step = Step
  function Step(...)
    pcall(CLEAN_HUD_SS_MInstall)
    return step(...)
  end
end
