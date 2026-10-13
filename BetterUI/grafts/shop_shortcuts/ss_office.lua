-- EVT shop_shortcuts, office hub side (Clean HUD feature «Atajos de tienda», the mod shop_shortcuts until 2026-10-08; docs/game/ui/l2r2-cycle.md). Only with Inazuma
-- Fantasy: its office (soccer_vs_cpu_list_menu opened by the Mercado or by «Modos de juego» › Tienda, fm_build's
-- EVT_OFFICE = true). L2 / R2 (keyboard
-- Q / E) = previous / next Mercado entry. The list's setting has no L2 / R2 row, so the keys are polled with
-- CMND_CHECK_INPUT_CMD while the hub is active (the last CMND_MENU_ACTIVE it set on itself; the office switches it off
-- while a team shop is open). The hub stores the direction in CLEAN_HUD_SS_KEY and closes; the Mercado (ss_market.lua) or
-- «Modos de juego» (IF's mh_hub.lua) opens the next entry straight away. The free-match list (EVT_OFFICE not true) and a game without Inazuma Fantasy are
-- untouched. Wrappers only (OnInit, Step, funcLuaMenuCommand from OnInit / Step); nothing runs at chunk load.
CLEAN_HUD_SS_KEY = 3425095194 --[[crc32 evt_shop_cycle_dir: 1 = next, 2 = previous]]
CLEAN_HUD_SS_HOST_KEY = 797210455 --[[crc32 evt_shop_cycle_host: 1 = the Mercado, 2 = «Modos de juego» waits for this office]]
CLEAN_HUD_SS_OHOSTS = {839500579 --[[market_menu]], 811496143 --[[soccer_top_menu]]}
CLEAN_HUD_SS_TXT_KEY = "clean_hud.shop_switch" -- text.toml of Clean HUD (VR-Framework texts)
CLEAN_HUD_SS_TXT_CRC = 3507600210 --[[crc32 clean_hud.shop_switch: the framework text id unless it collides]]
CLEAN_HUD_SS_HUB = 1970579282 --[[soccer_vs_cpu_list_menu]]
CLEAN_HUD_SS_O = {frames = 0, since = 0, active = nil, was_l = true, was_r = true, left = false}


function CLEAN_HUD_SS_OLog(...)
  pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "EVT shop_shortcuts office", ...)
end

function CLEAN_HUD_SS_OTextId()
  if CLEAN_HUD_SS_O.txt == nil then
    local ok, id = pcall(funcLuaCommand, 3096244543 --[[CMND_VRFW_TEXT_ID]], CLEAN_HUD_SS_TXT_KEY)
    CLEAN_HUD_SS_O.txt = (ok and type(id) == "number" and id ~= 0) and id or CLEAN_HUD_SS_TXT_CRC
  end
  return CLEAN_HUD_SS_O.txt
end

function CLEAN_HUD_SS_OKey(k)
  return funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD]], 1332654303 --[[MENU_CTRL]], k) == true
    or funcLuaCommand(4265778440, 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]], k) == true
end

-- the office of Inazuma Fantasy, opened by a host that waits for it: the Mercado (1) or «Modos de juego» › Tienda (2,
-- IF's modes_hub cycles through the Mercado's entries too)
function CLEAN_HUD_SS_OOn()
  if EVT_OFFICE ~= true or CLEAN_HUD_SS_O.left then
    return false
  end
  if funcLuaCommand(2947612279, CLEAN_HUD_SS_HOST_KEY) ~= true then
    return false
  end
  local host = CLEAN_HUD_SS_OHOSTS[funcLuaCommand(3522198769, CLEAN_HUD_SS_HOST_KEY)]
  return host ~= nil and funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], host) == true
end

function CLEAN_HUD_SS_OCan()
  local O = CLEAN_HUD_SS_O
  if O.active == false or not CLEAN_HUD_SS_OOn() then
    return false
  end
  if (O.active == nil and O.frames < 90) or (O.active == true and O.frames - O.since < 12) then
    return false
  end
  if funcLuaCommand(1215256347 --[[CMND_BRIGHT_IS_FADE]]) == true or funcLuaCommand(2736534827) == true then
    return false
  end
  return funcLuaMenuCommand(2231168902, 968210065 --[[sub_window]]) ~= true
    and funcLuaMenuCommand(2231168902, 3170360552 --[[shop_menu]]) ~= true
end

function CLEAN_HUD_SS_OTick()
  local O = CLEAN_HUD_SS_O
  O.frames = O.frames + 1
  if EVT_OFFICE ~= true then
    return
  end
  local l2, r2 = CLEAN_HUD_SS_OKey(1970176280 --[[CMD_FUNCL2]]), CLEAN_HUD_SS_OKey(2704260807 --[[CMD_FUNCR2]])
  local d = nil
  if l2 and not O.was_l then
    d = 2
  elseif r2 and not O.was_r then
    d = 1
  end
  O.was_l, O.was_r = l2, r2
  if d == nil or not CLEAN_HUD_SS_OCan() then
    return
  end
  O.left = true
  if funcLuaCommand(2947612279, CLEAN_HUD_SS_KEY) then
    funcLuaCommand(3363400568, CLEAN_HUD_SS_KEY)
  end
  funcLuaCommand(3860611758, CLEAN_HUD_SS_KEY, 0, d, 1)
  CLEAN_HUD_SS_OLog("leave", d)
  funcLuaCommand(1917805374, 2500047763 --[[sy0005]])
  funcLuaMenuCommand(1558704558, CLEAN_HUD_SS_HUB, false)
  funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], CLEAN_HUD_SS_HUB)
end

-- funcLuaMenuCommand wrapper (the hub's CMND_MENU_ACTIVE on itself + the two guide entries). The engine registers
-- funcLuaMenuCommand only after the chunk and its patches ran, and that registration replaces any global set at chunk
-- load. Installed on the first OnInit / Step instead, once.
function CLEAN_HUD_SS_OInstall()
  local real = funcLuaMenuCommand
  if CLEAN_HUD_SS_O.wrapped or type(real) ~= "function" then
    return
  end
  CLEAN_HUD_SS_O.wrapped = true
  funcLuaMenuCommand = function(...)
    local c, a, b, texts, icons = ...
    if c == 1558704558 and a == CLEAN_HUD_SS_HUB and type(b) == "boolean" then
      if b and CLEAN_HUD_SS_O.active ~= true then
        CLEAN_HUD_SS_O.since = CLEAN_HUD_SS_O.frames
      end
      CLEAN_HUD_SS_O.active = b
    elseif (c == 2209673388 or c == 452337289) and b == 1138543975 --[[mainmenu01_06_base_button_guide]]
        and type(texts) == "table" and EVT_OFFICE == true and CLEAN_HUD_SS_OOn() then
      local args = table.pack(...)
      if c == 2209673388 then
        CLEAN_HUD_SS_O.g_n = 0
        if #texts > 0 and type(icons) == "table" then
          CLEAN_HUD_SS_O.g_n = #texts
          for k = 4, 8 do
            if type(args[k]) == "table" then
              local t = {}
              for i = 1, CLEAN_HUD_SS_O.g_n do
                t[i] = args[k][i] or 0
              end
              args[k] = t
            end
          end
          local add = {{0, 619948187 --[[<CMD_FUNCL2>]]}, {CLEAN_HUD_SS_OTextId(), 3487556099 --[[<CMD_FUNCR2>]]}}
          for _, e in ipairs(add) do
            args[4][#args[4] + 1] = e[1]
            args[5][#args[5] + 1] = e[2]
            if type(args[6]) == "table" then args[6][#args[6] + 1] = 18 end
            if type(args[7]) == "table" then args[7][#args[7] + 1] = 0 end
            if type(args[8]) == "table" then args[8][#args[8] + 1] = 0 end
          end
        end
      elseif (CLEAN_HUD_SS_O.g_n or 0) > 0 then
        local t = {}
        for i = 1, CLEAN_HUD_SS_O.g_n do
          t[i] = texts[i] or 0
        end
        t[#t + 1] = 1970176280 --[[CMD_FUNCL2]]
        t[#t + 1] = 2704260807 --[[CMD_FUNCR2]]
        args[4] = t
        CLEAN_HUD_SS_O.g_n = 0
      end
      return real(table.unpack(args, 1, args.n))
    end
    return real(...)
  end
end

do
  local init = OnInit
  if type(init) == "function" then
    function OnInit(...)
      pcall(CLEAN_HUD_SS_OInstall)
      return init(...)
    end
  end
  local step = Step
  function Step(...)
    pcall(CLEAN_HUD_SS_OInstall)
    local r = table.pack(step(...))
    local ok, err = pcall(CLEAN_HUD_SS_OTick)
    if not ok then
      CLEAN_HUD_SS_OLog("error", tostring(err))
    end
    return table.unpack(r, 1, r.n)
  end
end
