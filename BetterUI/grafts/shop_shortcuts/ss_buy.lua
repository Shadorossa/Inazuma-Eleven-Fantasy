-- EVT shop_shortcuts, shop side (Clean HUD feature «Atajos de tienda», the mod shop_shortcuts until 2026-10-08; docs/game/ui/l2r2-cycle.md). In a shop opened by a menu that
-- can open the next one (the «host»: the Mercado, ss_market.lua),
-- L2 / R2 (keyboard Q / E) = previous / next shop. retail shop_menu_setting already routes CMD_FUNCL2 / CMD_FUNCR2 of
-- the item list layer to OnFunction 3762100098 / 1492160491 (the personal plate page turn of kizuna_town_avatar_menu;
-- nothing in shop_menu_buy handles them), so the engine only delivers them while the shop is active with the item list
-- focused: no polling. The shop stores the direction in the param store (CLEAN_HUD_SS_KEY: 1 next, 2 previous), closes the
-- office hub first when it is inside the office (as the «Prueba» hand-off) and then itself; the host sees the key when
-- the shop is gone and opens the next entry straight away, without showing its own list in between.
-- Host handshake: the host writes CLEAN_HUD_SS_HOST_KEY (1 = Mercado, 2 = «Modos de juego») while it waits for its shop;
-- without it (a shop opened from the Crónica, the Estación Kizuna, the retail Competición menu...) L2 / R2 stay retail.
-- Button guide: «<L2><R2> Cambiar de tienda» (text clean_hud.shop_switch, text.toml of Clean HUD),
-- appended to the item list guide by a funcLuaMenuCommand wrapper installed on the first OnInit / Step (the engine
-- registers funcLuaMenuCommand after the chunk and its patches ran). L1 / R1 (Z / C, the tabs) are untouched.
-- Wrappers only (OnFunction, Step, OnInit, UpdateButtonGuide, funcLuaMenuCommand); nothing runs at chunk load.
CLEAN_HUD_SS_KEY = 3425095194 --[[crc32 evt_shop_cycle_dir: 1 = next shop, 2 = previous (read by the host menu)]]
CLEAN_HUD_SS_HOST_KEY = 797210455 --[[crc32 evt_shop_cycle_host: 1 = Mercado (market_menu), 2 = «Modos de juego» (soccer_top_menu)]]
CLEAN_HUD_SS_HOSTS = {839500579 --[[market_menu]], 811496143 --[[soccer_top_menu]]}
CLEAN_HUD_SS_FN_PREV = 3762100098 -- shop_menu_setting: list layer, CMD_FUNCL2 -> CMD_FUNCTION 0xE03D1C82
CLEAN_HUD_SS_FN_NEXT = 1492160491 -- shop_menu_setting: list layer, CMD_FUNCR2 -> CMD_FUNCTION 0x58F05DEB
CLEAN_HUD_SS_TXT_KEY = "clean_hud.shop_switch" -- text.toml of Clean HUD (VR-Framework texts)
CLEAN_HUD_SS_TXT_CRC = 3507600210 --[[crc32 clean_hud.shop_switch: the framework text id unless it collides]]
CLEAN_HUD_SS_SHOP = 3170360552 --[[shop_menu (this script: shop_menu_buy)]]
CLEAN_HUD_SS_OFFICE = 1970579282 --[[soccer_vs_cpu_list_menu: the office hub of Inazuma Fantasy]]
CLEAN_HUD_SS_BASARA = 713974531 --[[shop_menu_basara_top: its shops belong to it, not to the Mercado]]
CLEAN_HUD_SS_OFI_PARAM = 735723015 -- param: 1 = soccer_vs_cpu_list_menu opened as IF's office (EVT_OFI_PARAM, fichajes)
CLEAN_HUD_SS_WAIT = 600 -- watchdog frames (a closed menu is never resumed again: still running = it did not close)
CLEAN_HUD_SS_CO = nil
CLEAN_HUD_SS_B = {wrapped = false, guide = false, txt = nil}


function CLEAN_HUD_SS_Log(...)
  pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, "EVT shop_shortcuts", ...)
end

function CLEAN_HUD_SS_Exists(m)
  return funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, m) == true
end

function CLEAN_HUD_SS_Param(k)
  if not VRFW_Param.Has(k) then
    return nil
  end
  return VRFW_Param.Get(k)
end

-- a host is waiting for this shop (its menu exists), and this shop is its own (not one of the «Mercado de fichas»
-- menu; in «Modos de juego» not one of the free-match list, which shares the office hub's menu: there the list must
-- be IF's office, opened by the host in office mode, CLEAN_HUD_SS_OFI_PARAM = 1, as the Mercado does)
function CLEAN_HUD_SS_Can()
  if CLEAN_HUD_SS_CO ~= nil then
    return false
  end
  local h = CLEAN_HUD_SS_Param(CLEAN_HUD_SS_HOST_KEY)
  local host = type(h) == "number" and CLEAN_HUD_SS_HOSTS[h] or nil
  if host == nil or not CLEAN_HUD_SS_Exists(host) or CLEAN_HUD_SS_Exists(CLEAN_HUD_SS_BASARA) then
    return false
  end
  return h == 1 or not CLEAN_HUD_SS_Exists(CLEAN_HUD_SS_OFFICE) or CLEAN_HUD_SS_Param(CLEAN_HUD_SS_OFI_PARAM) == 1 or CLEAN_HUD_SS_OfficeMode()
end

-- 2026-10-02: the office list takes CLEAN_HUD_SS_OFI_PARAM in its OnInit (fichajes EVT_OfficeInit), so a team shop opened
-- inside the office never sees it; the office byte flag (EVT_OFI_MODE, set by the host's office begin, cleared by its
-- end and by a free-match list) stays up while the office is open
CLEAN_HUD_SS_OFI_MODE = 2606981058 -- global byte flag EVT_OFI_MODE_FLAG of Inazuma Fantasy (fichajes / modes_hub)
function CLEAN_HUD_SS_OfficeMode()
  local ok, v = pcall(funcLuaCommand, @crc:CMND_GET_GLOBAL_BYTE_FLAG@, CLEAN_HUD_SS_OFI_MODE)
  return ok and v == 1
end

function CLEAN_HUD_SS_Key(v)
  if VRFW_Param.Has(CLEAN_HUD_SS_KEY) then
    VRFW_Param.Clear(CLEAN_HUD_SS_KEY)
  end
  if v ~= nil then
    VRFW_Param.Set(CLEAN_HUD_SS_KEY, v)
  end
end

function CLEAN_HUD_SS_Leave(dir)
  CLEAN_HUD_SS_Key(dir)
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2500047763 --[[sy0005]])
  funcLuaMenuCommand(1558704558, CLEAN_HUD_SS_SHOP, false)
  local office = CLEAN_HUD_SS_Exists(CLEAN_HUD_SS_OFFICE)
  CLEAN_HUD_SS_Log("leave", dir, office and "office" or "shop")
  if office then
    -- inside the office: the Mercado waits for the office hub, so it closes first (the Prueba hand-off order)
    funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, CLEAN_HUD_SS_OFFICE)
    local n = 0
    while n < CLEAN_HUD_SS_WAIT and CLEAN_HUD_SS_Exists(CLEAN_HUD_SS_OFFICE) do
      n = n + 1
      coroutine.yield()
    end
  end
  funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, CLEAN_HUD_SS_SHOP)
  for _ = 1, CLEAN_HUD_SS_WAIT do
    coroutine.yield()
  end
  if VRFW_Param.Has(CLEAN_HUD_SS_KEY) then
    CLEAN_HUD_SS_Key(nil)
    CLEAN_HUD_SS_Log("watchdog: the shop is still open; key cleared, shop active again")
    funcLuaMenuCommand(1558704558, CLEAN_HUD_SS_SHOP, true)
  end
end

function CLEAN_HUD_SS_Resume()
  local ok, err = coroutine.resume(CLEAN_HUD_SS_CO)
  if not ok then
    CLEAN_HUD_SS_Log("error", tostring(err))
    CLEAN_HUD_SS_Key(nil)
    funcLuaMenuCommand(1558704558, CLEAN_HUD_SS_SHOP, true)
  end
  if not ok or coroutine.status(CLEAN_HUD_SS_CO) == "dead" then
    CLEAN_HUD_SS_CO = nil
  end
end

-- id of «Cambiar de tienda»: the text_engine's (CMND_VRFW_TEXT_ID), else crc32 of the key (the id it gives when free)
function CLEAN_HUD_SS_TextId()
  if CLEAN_HUD_SS_B.txt == nil then
    local ok, id = pcall(funcLuaCommand, @crc:CMND_VRFW_TEXT_ID@, CLEAN_HUD_SS_TXT_KEY)
    CLEAN_HUD_SS_B.txt = (ok and type(id) == "number" and id ~= 0) and id or CLEAN_HUD_SS_TXT_CRC
  end
  return CLEAN_HUD_SS_B.txt
end

-- funcLuaMenuCommand wrapper: while UpdateButtonGuide builds the item list guide of a shop that can switch, the two
-- entries go at the end of it (texts / icons / offsets / 2 zero columns, then the commands). Installed once, from the
-- first OnInit / Step: at chunk load the engine has not registered funcLuaMenuCommand yet.
function CLEAN_HUD_SS_BInstall()
  local real = funcLuaMenuCommand
  if CLEAN_HUD_SS_B.wrapped or type(real) ~= "function" then
    return
  end
  CLEAN_HUD_SS_B.wrapped = true
  funcLuaMenuCommand = function(c, ...)
    if CLEAN_HUD_SS_B.guide and (c == 2209673388 or c == 452337289) then
      local args = table.pack(c, ...)
      if (args[3] == 1138543975 --[[mainmenu01_06_base_button_guide]] or args[3] == 2062970623 --[[shopmenu01_06_base_button_guide]])
          and type(args[4]) == "table" then
        if c == 2209673388 then
          local add = {{0, 619948187 --[[<CMD_FUNCL2>]]}, {CLEAN_HUD_SS_TextId(), 3487556099 --[[<CMD_FUNCR2>]]}}
          for _, e in ipairs(add) do
            args[4][#args[4] + 1] = e[1]
            if type(args[5]) == "table" then args[5][#args[5] + 1] = e[2] end
            if type(args[6]) == "table" then args[6][#args[6] + 1] = 18 end
            if type(args[7]) == "table" then args[7][#args[7] + 1] = 0 end
            if type(args[8]) == "table" then args[8][#args[8] + 1] = 0 end
          end
        else
          args[4][#args[4] + 1] = 1970176280 --[[CMD_FUNCL2]]
          args[4][#args[4] + 1] = 2704260807 --[[CMD_FUNCR2]]
          CLEAN_HUD_SS_B.guide = false
        end
        return real(table.unpack(args, 1, args.n))
      end
    end
    return real(c, ...)
  end
end

do
  local fn = OnFunction
  function OnFunction(a1, a2, ...)
    if a1 == CLEAN_HUD_SS_FN_PREV or a1 == CLEAN_HUD_SS_FN_NEXT then
      local okc, can = pcall(CLEAN_HUD_SS_Can)
      if okc and can then
        CLEAN_HUD_SS_CO = coroutine.create(CLEAN_HUD_SS_Leave)
        local ok, err = coroutine.resume(CLEAN_HUD_SS_CO, a1 == CLEAN_HUD_SS_FN_NEXT and 1 or 2)
        if not ok then
          CLEAN_HUD_SS_Log("error", tostring(err))
          CLEAN_HUD_SS_CO = nil
        elseif coroutine.status(CLEAN_HUD_SS_CO) == "dead" then
          CLEAN_HUD_SS_CO = nil
        end
        return
      end
    end
    return fn(a1, a2, ...)
  end
  local init = OnInit
  if type(init) == "function" then
    function OnInit(...)
      pcall(CLEAN_HUD_SS_BInstall)
      return init(...)
    end
  end
  local step = Step
  function Step(...)
    pcall(CLEAN_HUD_SS_BInstall)
    local r = table.pack(step(...))
    if CLEAN_HUD_SS_CO ~= nil then
      CLEAN_HUD_SS_Resume()
    end
    return table.unpack(r, 1, r.n)
  end
  -- list mode (a1) of a shop that can switch: the wrapper above adds the two entries to this guide
  local guide = UpdateButtonGuide
  if type(guide) == "function" then
    function UpdateButtonGuide(a1, ...)
      pcall(CLEAN_HUD_SS_BInstall)
      local ok, can = pcall(CLEAN_HUD_SS_Can)
      CLEAN_HUD_SS_B.guide = a1 and ok and can or false
      local r = table.pack(guide(a1, ...))
      CLEAN_HUD_SS_B.guide = false
      return table.unpack(r, 1, r.n)
    end
  end
end
