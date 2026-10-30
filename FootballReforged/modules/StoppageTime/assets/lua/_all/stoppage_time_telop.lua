-- Stoppage Time (module of Football Reforged; docs/game/mods/stoppage-time.md): the «+N» telop on the match HUD.
-- When a half's regular time ends, scripts\stoppage_time.lua answers CMND_STOPPAGETIME_TELOP with shown = true and the
-- text (text key telop_added_time, e.g. «Tiempo añadido +3») for config.toml [telop] hold_seconds. This file asks it
-- once per HUD frame (wrapping UpdateScoreboardKeeperHp, called every frame by StepSoccerConstantMenu of both match
-- HUDs, soccer_constant_menu and soccer_battle_constant_menu) and draws it with the layer stoppage_time_telop
-- (content\menus\stoppage_time_telop.toml: the retail AI-camera telop, one quad and one text node):
--   shown, layer closed  -> open it (its own open motion), hidden until loaded
--   shown, layer loaded  -> its text node gets the text, moved by the offset, visible
--   not shown, layer open -> closed
-- Runs in every script VM (lua\_all) and only acts where the HUD defines UpdateScoreboardKeeperHp. No engine call at
-- load; every call through pcall. loader.log: «StoppageTime telop ...» once per change.
if type(rawget(_ENV, "UpdateScoreboardKeeperHp")) == "function" and rawget(_ENV, "StoppageTimeTelop") == nil then
  local T = {
    CMD = VRFW_Cmd.STOPPAGETIME_TELOP,              -- CMND_STOPPAGETIME_TELOP
    LAYER = 87370570,             -- stoppage_time_telop
    TEXT = 1181146041,            -- _text_telop01 (the telop's text node)
    OPEN = VRFW_Cmd.OPEN_LAYER,             -- CMND_OPEN_LAYER
    CLOSE = VRFW_Cmd.CLOSE_LAYER,           -- CMND_CLOSE_LAYER
    IS_OPEN = VRFW_Cmd.IS_OPEN_LAYER,         -- CMND_IS_OPEN_LAYER
    IS_LOADING = VRFW_Cmd.IS_LOADING_LAYER,      -- CMND_IS_LOADING_LAYER
    VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE,          -- CMND_SET_LAYER_VISIBLE
    SET_TEXT = VRFW_Cmd.SET_MENU_TEXT_STRING,        -- CMND_SET_MENU_TEXT_STRING
    SET_POS = VRFW_Cmd.SET_LAYER_LOCAL_POS,         -- CMND_SET_LAYER_LOCAL_POS
    LOG = VRFW_Cmd.EVT_LOG,             -- CMND_EVT_LOG
    state = "closed",             -- closed / opening / shown
    text = nil,
    logs = 0,
  }
  StoppageTimeTelop = T

  local function menu(...)
    if type(funcLuaMenuCommand) ~= "function" then return nil end
    local r = table.pack(pcall(funcLuaMenuCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end

  local function command(...)
    if type(funcLuaCommand) ~= "function" then return nil end
    local r = table.pack(pcall(funcLuaCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end

  local function log(...)
    if T.logs >= 20 then return end
    T.logs = T.logs + 1
    command(T.LOG, "StoppageTime telop", ...)
  end

  local function close()
    if T.state ~= "closed" then
      if menu(T.IS_OPEN, T.LAYER, 0) == true then
        menu(T.CLOSE, T.LAYER, 0)
      end
      T.state, T.text = "closed", nil
      log("closed")
    end
  end

  function T.Step()
    local shown, text, dx, dy = command(T.CMD)
    if shown ~= true then
      close()
      return
    end
    if T.state == "closed" then
      if menu(T.IS_OPEN, T.LAYER, 0) ~= true then
        menu(T.OPEN, T.LAYER, 0)
      end
      menu(T.VISIBLE, T.LAYER, 0, false)
      T.state = "opening"
      return
    end
    if T.state == "opening" then
      if menu(T.IS_OPEN, T.LAYER, 0) ~= true or menu(T.IS_LOADING, T.LAYER) == true then
        return
      end
      dx, dy = tonumber(dx) or 0, tonumber(dy) or 0
      if dx ~= 0 or dy ~= 0 then
        menu(T.SET_POS, T.LAYER, dx, dy, 0, 0)
      end
      T.state = "shown"
      log("shown", tostring(text))
    end
    if T.text ~= text then
      T.text = text
      menu(T.SET_TEXT, T.LAYER, T.TEXT, tostring(text or ""), 0)
      menu(T.VISIBLE, T.LAYER, 0, true)
    end
  end

  local function make(orig)
    return function(...)
      local r = table.pack(orig(...))
      pcall(T.Step)
      return table.unpack(r, 1, r.n)
    end
  end

  local wrapped = false
  if type(VRFW_Host) == "table" and type(VRFW_Host.wrap) == "function" then
    wrapped = VRFW_Host.wrap("UpdateScoreboardKeeperHp", make, { id = "StoppageTime.telop" }) == true
  end
  if not wrapped then
    UpdateScoreboardKeeperHp = make(UpdateScoreboardKeeperHp)
  end
end
