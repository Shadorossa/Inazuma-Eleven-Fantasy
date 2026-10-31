-- friendly way back (VR-Framework, match engine friendlies). Any menu that opens asks the match engine whether a played friendly's way back ends here:
--
-- * return = "menus" (VRFW, the match start service VRFW_MATCH): the match ended (the clock, the retail
--   hold-to-leave, CMND_VRFW_MATCH_EXIT) and the soccer state's own way to the menus reopened the hub the friendly was
--   started from, with the in-memory game untouched (no game reset anywhere). CMND_VRFW_FRIENDLY_MENU_BACK(this menu's
--   stem) says go when this is that hub (no match running, the game in the menus): the friendly is closed here with
--   BACK(3) (sink off, VS team back, its rewards).
--   The menus net: the soccer state reopens the scene root only for some games; for the others (e.g. a mode's own
--   slot entered by a straight reset, title row root_menu) it ends in an empty story field instead (c00 trigger, field
--   HUD, map menu). The first VM that opens after the match and is not the way back target VRFW_MATCH recorded (param
--   vrfw_match_way_back_menu, the scene root) sends the game straight back to it: black at once, VRFW_Reset.straight
--   (the same entry as the title row's root_menu: the game kept in memory, no title); the root's OnInit then closes the
--   friendly with MENU_BACK as above. Once per friendly (the target is taken).
-- * return = "title" (the title net): the way back is a game reset right after the match. When the
--   soccer state's own way to the menus took that reset over (a friendly played from the menus), the title never ran
--   and the menus opened on the game the reset wiped. CMND_VRFW_FRIENDLY_TITLE_NET (a played return-to-title friendly,
--   a game reset since its match, no match running, once per friendly) sends the game to the title at once (black,
--   CMND_GAME_RESET, no autosave): the title reads the slot file again and pachanga_title closes the friendly. The net
--   never runs in the title's own scripts. Until 2.2.x it never fired: the match end's reset is the native GameReset,
--   which the plugins' game-reset event does not see; the engine now also compares the native reset count.
--
-- The sink keeps every game write of the slot off its file until the friendly is closed. Hooked on OnInit twice (the
-- global wrapped here, and the VRFW_Host dispatcher for a stem patch that redefines OnInit later, e.g. a menu's
-- fm_build); the check runs once per menu. No engine call at load time.
do
  local NET = VRFW_Cmd.VRFW_FRIENDLY_TITLE_NET          -- crc32("CMND_VRFW_FRIENDLY_TITLE_NET")
  local MENU_BACK = VRFW_Cmd.VRFW_FRIENDLY_MENU_BACK     -- crc32("CMND_VRFW_FRIENDLY_MENU_BACK")
  local BACK = VRFW_Cmd.EVT_PACHANGA_BACK         -- crc32("CMND_EVT_PACHANGA_BACK") (= CMND_VRFW_FRIENDLY_BACK)
  local LOG = VRFW_Cmd.EVT_LOG          -- crc32("CMND_EVT_LOG")
  local GAME_RESET = VRFW_Cmd.GAME_RESET   -- crc32("CMND_GAME_RESET")
  local FADE = 609722083          -- (on, seconds): screen fade to black
  local TITLE = {title_menu_2 = true, title_main = true}
  local STATE = VRFW_Cmd.EVT_PACHANGA_STATE       -- crc32("CMND_EVT_PACHANGA_STATE") -> phase, id, …, return
  local IS_SOCCER = VRFW_Cmd.IS_SOCCER_MODE       -- crc32("CMND_IS_SOCCER_MODE")
  local PARAM_WAY_BACK_MENU = 3244649355          -- crc32("vrfw_match_way_back_menu"), set by 12_match_start.lua
  local PARAM_WAY_BACK_FRIENDLY = 1563930864      -- crc32("vrfw_match_way_back_friendly")
  local PLAYED, RETURN_MENUS = 3, 3               -- STATE: phase Played, return 3 = menus

  local script = type(EVT_PATCH) == "table" and EVT_PATCH.script or "?"
  local stem = type(script) == "string" and (script:gsub("_%d+%.%d+%.%d+[%.%d]*$", "")) or "?"
  local checked = false
  local net_co, has_step = nil, false

  local function log(...)
    pcall(funcLuaCommand, LOG, "VRFW friendly_way_back", tostring(stem), ...)
  end

  local function way_back_clear()
    for _, k in ipairs({PARAM_WAY_BACK_MENU, PARAM_WAY_BACK_FRIENDLY}) do
      if VRFW_Param.Has(k) then VRFW_Param.Clear(k) end
    end
  end

  local function menu_back()
    local ok, go, id, _, mode = pcall(funcLuaCommand, MENU_BACK, stem)
    if not ok or go ~= true then
      return false
    end
    way_back_clear()
    -- the hub's own play mode back (the match may have run in another one, e.g. Competición for the VS team)
    if type(mode) == "number" and mode >= 0 then
      pcall(funcLuaCommand, 3718253404 --[[set play mode]], mode)
    end
    local P = VRFW_PACHANGA
    if type(P) == "table" and type(P.back) == "function" then
      local info = P.back(3)
      log("friendly " .. tostring(id) .. ": back in its hub, closed (no game reset)", tostring(info and info.closed))
      return true
    end
    -- a hub without the friendly executor: BACK + the VS team (no reward table rolled here: logged)
    local okb, closed, _, _, _, team_swapped = pcall(funcLuaCommand, BACK, 3)
    if okb and closed == true and team_swapped == true then
      local okv, had, vs = pcall(funcLuaCommand, VRFW_Cmd.EVT_PACHANGA_VS, 0)
      if okv and had == true and type(vs) == "number" and vs >= 0 then
        pcall(funcLuaCommand, VRFW_Cmd.SET_VS_USE_TEAM_SET, vs)
      end
    end
    log("friendly " .. tostring(id) .. ": back in its hub, closed without VRFW_PACHANGA (no rewards rolled)",
      tostring(okb and closed))
    return true
  end

  local function title_net()
    if TITLE[stem] then
      return
    end
    local ok, go, id, try = pcall(funcLuaCommand, NET)
    if not ok or go ~= true then
      return
    end
    log("friendly " .. tostring(id) ..
      ": its way back to the title was lost after the match; going to the title now (try " .. tostring(try) .. ")")
    pcall(funcLuaCommand, FADE, 1, 0)                 -- black at once: no frame of the wiped menus
    pcall(funcLuaMenuCommand, 3479138216, 0)          -- the same calls as the top bar's reset to the title
    pcall(funcLuaCommand, 937976662, true)
    pcall(funcLuaCommand, 419468738, false)
    pcall(funcLuaCommand, 1507811093, false)
    pcall(funcLuaCommand, GAME_RESET)
  end

  -- the menus net (see the header): true when this VM took the way back over
  local function menus_net(where)
    if TITLE[stem] or stem == "?" or not has_step then
      return false
    end
    local target = VRFW_Id.u32_or(VRFW_Param.Get(PARAM_WAY_BACK_MENU), nil)
    if target == nil or target == 0 or target == VRFW_Crc32(stem) then
      return false
    end
    local oks, phase, id, _, _, _, _, ret = pcall(funcLuaCommand, STATE)
    if not oks or phase ~= PLAYED or ret ~= RETURN_MENUS or type(id) ~= "string" then
      return false
    end
    if VRFW_Id.u32_or(VRFW_Param.Get(PARAM_WAY_BACK_FRIENDLY), nil) ~= VRFW_Crc32(id) then
      return false
    end
    local okm, soccer = pcall(funcLuaCommand, IS_SOCCER)
    if okm and soccer == true then
      return false
    end
    way_back_clear()
    pcall(funcLuaCommand, FADE, 1, 0)                 -- black at once: no frame of the field
    log("friendly " .. id .. ": the match's way back did not reopen its hub " .. tostring(target) ..
      " (this VM opened instead, " .. where .. "): straight reset into it")
    net_co = coroutine.create(function()
      local how = VRFW_Reset.straight({ menu = target, bgm_stop = true, need_carry = true,
        log = function(text) log("menus net: " .. text) end })
      log("friendly " .. id .. ": menus net: " .. tostring(how))
      if how == "refused" then
        log("friendly " .. id .. ": menus net: no kept game, the retail reset to the title instead")
        VRFW_Reset.to_title()
      end
    end)
    return true
  end

  local function check(where)
    if checked then
      return
    end
    checked = true
    if not menu_back() then
      title_net()
      if not menus_net(where) then
        net_co = nil
      end
    end
  end

  local init = OnInit
  if type(init) == "function" then
    OnInit = function(...)
      local r = table.pack(init(...))
      pcall(check, "OnInit")
      return table.unpack(r, 1, r.n)
    end
  end
  -- a VM without OnInit (the field HUD) checks at its first Step; the menus net's reset runs from Step (it waits for
  -- a running save job)
  local step = Step
  if type(step) == "function" then
    has_step = true
    Step = function(...)
      local r = table.pack(step(...))
      if not checked then
        pcall(check, "first Step")
      end
      if net_co ~= nil then
        local okr, err = coroutine.resume(net_co)
        if not okr then
          log("menus net: error " .. tostring(err))
        end
        if not okr or coroutine.status(net_co) == "dead" then
          net_co = nil
        end
      end
      return table.unpack(r, 1, r.n)
    end
  end
  local VH = VRFW_Host
  if stem ~= "?" and type(VH) == "table" and type(VH.on) == "function" then
    pcall(VH.on, stem, "OnInit", {id = "vr_framework.friendly_way_back", phase = "around", fn = function(nxt, ...)
      local r = table.pack(nxt(...))
      pcall(check, "OnInit")
      return table.unpack(r, 1, r.n)
    end})
  end
end
