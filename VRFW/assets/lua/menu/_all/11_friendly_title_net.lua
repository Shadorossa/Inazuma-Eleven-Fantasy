-- friendly way back (VR-Framework, match engine friendlies; docs/framework/match-start.md, docs/game/modes/pachangas-
-- sistema.md §3). Any menu that opens asks the match engine whether a played friendly's way back ends here:
--
-- * return = "menus" (VRFW 2.2.x, the match start service VRFW_MATCH): the match ended (the clock, the retail
--   hold-to-leave, CMND_VRFW_MATCH_EXIT) and the soccer state's own way to the menus reopened the hub the friendly was
--   started from, with the in-memory game untouched (no game reset anywhere). CMND_VRFW_FRIENDLY_MENU_BACK(this menu's
--   stem) says go when this is that hub (no match running, the game in the menus): the friendly is closed here with
--   BACK(3) (sink off, VS team back, its rewards).
-- * return = "title" (the title net, 2.1.2; fixed 2.2.x): the way back is a game reset right after the match. When the
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
  local NET = 3706164102          -- crc32("CMND_VRFW_FRIENDLY_TITLE_NET")
  local MENU_BACK = 879824671     -- crc32("CMND_VRFW_FRIENDLY_MENU_BACK")
  local BACK = 3133514456         -- crc32("CMND_EVT_PACHANGA_BACK") (= CMND_VRFW_FRIENDLY_BACK)
  local LOG = 3661580131          -- crc32("CMND_EVT_LOG")
  local GAME_RESET = 3897105282   -- crc32("CMND_GAME_RESET")
  local FADE = 609722083          -- (on, seconds): screen fade to black
  local TITLE = {title_menu_2 = true, title_main = true}

  local script = type(EVT_PATCH) == "table" and EVT_PATCH.script or "?"
  local stem = type(script) == "string" and (script:gsub("_%d+%.%d+%.%d+[%.%d]*$", "")) or "?"
  local checked = false

  local function log(...)
    pcall(funcLuaCommand, LOG, "VRFW friendly_way_back", tostring(stem), ...)
  end

  local function menu_back()
    local ok, go, id, _, mode = pcall(funcLuaCommand, MENU_BACK, stem)
    if not ok or go ~= true then
      return false
    end
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
      local okv, had, vs = pcall(funcLuaCommand, 4127470188 --[[CMND_EVT_PACHANGA_VS]], 0)
      if okv and had == true and type(vs) == "number" and vs >= 0 then
        pcall(funcLuaCommand, 662075964 --[[CMND_SET_VS_USE_TEAM_SET]], vs)
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

  local function check()
    if checked then
      return
    end
    checked = true
    if not menu_back() then
      title_net()
    end
  end

  local init = OnInit
  if type(init) == "function" then
    OnInit = function(...)
      local r = table.pack(init(...))
      pcall(check)
      return table.unpack(r, 1, r.n)
    end
  end
  local VH = VRFW_Host
  if stem ~= "?" and type(VH) == "table" and type(VH.on) == "function" then
    pcall(VH.on, stem, "OnInit", {id = "vr_framework.friendly_way_back", phase = "around", fn = function(nxt, ...)
      local r = table.pack(nxt(...))
      pcall(check)
      return table.unpack(r, 1, r.n)
    end})
  end
end
