-- «Configuración de pasivas» of the mod Utilities (utilities.dll, feature passive_config;
-- docs/game/mechanics/pasivas-configurables.md), team dock part (team_dock_formation_menu). SOURCE of the hook file
-- util_pc_dock.lua (research/grafts/passive_config/gen_hooks.py fills the @crc / @ICONS@ placeholders; edit this
-- file, then run the script).
-- 2026-10-08 back to the ORIGINAL design (Inazuma Fantasy 2026-09-28, ff3bb93934): setting type 9 («Pasivas
-- heredadas», renamed «Configuración de pasivas») is offered to every player the plugin configures and hidden for
-- coaches, managers and players of a mode's reserved slot; type 10 (the inheritance trash button) is gone. Choosing
-- type 9 never opens the inherit menu: a Handle rule of the VR-Framework's list rows (docs/framework/list-rows.md,
-- since Utilities 1.15.10; until then one line inserted into the retail OnDecideFocus by the graft
-- passive_config_dispatch, which redefined that whole function) runs UTIL_PCD.Plate in the dock's own per-player
-- coroutine right after the popup closed (Inazuma Fantasy's merged file carries the same call in its graft
-- prime_dock): it turns the plate to «PASIVAS DE EQUIPO», hands a session to personal_plate_menu (util_pc_plate.lua)
-- through the parameter store, waits in the dock's coroutine until it ends and restores the dock exactly as the
-- original did; the dock then goes on as after any setting (the framework cancels the retail pick). (The 2026-10-08 replacement, which let the retail branch run and faked the inherit menu's
-- open / exists answers, left the dock waiting for a restore the retail code never did: stuck after Atrás.)
-- Without the plugin (CMND_UTIL_PC_INFO unanswered) nothing changes.
-- Hook file (graft [[hooks]]): GetSelectSettingTypeOrderList is wrapped with an EVT_Host handler of the
-- VR-Framework's host of team_dock_formation_menu; without EVT_Host the global is wrapped directly.
do
  UTIL_PCD = UTIL_PCD or {}
  UTIL_PCD.STEM = "team_dock_formation_menu"
  UTIL_PCD.CMD_INFO = @crc:CMND_UTIL_PC_INFO@
  UTIL_PCD.KEY_REQ = @crc:util_pc_edit_req@
  UTIL_PCD.KEY_PARENT = @crc:util_pc_edit_parent@
  UTIL_PCD.KEY_DONE = @crc:util_pc_edit_done@
  UTIL_PCD.WAIT_TAKE = 90 -- frames the plate has to take the request (no plate patch -> give up)

  -- wrap global `name` of this script: make(orig) returns the wrapper (an EVT_Host around handler when the host is
  -- there, else the global itself, once)
  UTIL_PCD.wrapped = UTIL_PCD.wrapped or {}
  function UTIL_PCD.Wrap(name, make)
    if type(EVT_Host) == "table" and type(EVT_Host.on) == "function" then
      EVT_Host.on(UTIL_PCD.STEM, name, {id = "utilities.passive_config." .. name, phase = "around", fn = function(nxt, ...)
        return make(nxt)(...)
      end})
      return true
    end
    local cur = _ENV[name]
    if type(cur) ~= "function" or UTIL_PCD.wrapped[cur] then
      return false
    end
    local w = make(cur)
    UTIL_PCD.wrapped[w] = true
    _ENV[name] = w
    return true
  end

  -- plugin answer for a player: on (bool), mode (0 none, 1 all slots, 2 Ídolo: slots 4-5)
  function UTIL_PCD.Info(h)
    if h == nil or h == 0 then
      return false, 0
    end
    local ok, got, mode = pcall(funcLuaCommand, UTIL_PCD.CMD_INFO, h)
    if not ok or type(mode) ~= "number" then
      return false, 0
    end
    return got == true, mode
  end

  function UTIL_PCD.P(key)
    funcLuaCommand(3363400568, key)
  end

  -- 2026-10-13 (owner, install89: the formation field - pitch cards, bench, coach card, formation name - drawn over
  -- the picker list). Since Utilities 1.14.23 the session no longer suspends the dock's group (camera, see Plate),
  -- so the dock's layers stayed up under / over the plate's list window on the left half. Instead of suspending the
  -- group, the session hides the dock's own layer instances that are visible (every instance this menu set up, seen
  -- in OnSetupLayer: retail and mods' added layers alike, no list of names), keeps them hidden every frame (the dock's
  -- and mods' Steps may show a card again) and shows again exactly the ones it hid when the session ends. The group
  -- and its camera stay as they are, so the player page's model keeps its framing.
  UTIL_PCD.layers = UTIL_PCD.layers or {} -- {layer crc, instance} in setup order
  UTIL_PCD.seen = UTIL_PCD.seen or {}     -- layer crc * 4096 + instance -> true
  UTIL_PCD.hidden = nil                   -- session: key -> {layer, instance} hidden by it

  function UTIL_PCD.Note(a1, a2)
    if type(a1) ~= "number" or type(a2) ~= "number" then
      return
    end
    local k = a1 * 4096 + a2
    if not UTIL_PCD.seen[k] then
      UTIL_PCD.seen[k] = true
      UTIL_PCD.layers[#UTIL_PCD.layers + 1] = {a1, a2}
    end
  end

  -- hide every visible instance of the dock's layers (again each frame of the session)
  function UTIL_PCD.HideField()
    local hid = UTIL_PCD.hidden
    if hid == nil then
      hid = {}
      UTIL_PCD.hidden = hid
    end
    for i = 1, #UTIL_PCD.layers do
      local e = UTIL_PCD.layers[i]
      local ok, vis = pcall(funcLuaMenuCommand, 1262717583 --[[CMND_IS_LAYER_VISIBLE]], e[1], e[2])
      if ok and vis == true then
        pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], e[1], e[2], false)
        hid[e[1] * 4096 + e[2]] = e
      end
    end
  end

  function UTIL_PCD.ShowField()
    local hid = UTIL_PCD.hidden
    UTIL_PCD.hidden = nil
    if hid == nil then
      return
    end
    for _, e in pairs(hid) do
      pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], e[1], e[2], true)
    end
  end

  -- dispatch of type 9 inside the team dock's per-player coroutine: true = handled here (the original's steps)
  function UTIL_PCD.Plate(h)
    local on, mode = UTIL_PCD.Info(h)
    if not on or mode <= 0 then
      return false
    end
    if type(ChangePageInfo) == "function" then
      pcall(ChangePageInfo, 2)
    end
    UTIL_PCD.P(UTIL_PCD.KEY_DONE)
    UTIL_PCD.P(UTIL_PCD.KEY_PARENT)
    funcLuaCommand(3860611758, UTIL_PCD.KEY_PARENT, 0, g_parentMenuId or 0, 1)
    UTIL_PCD.P(UTIL_PCD.KEY_REQ)
    funcLuaCommand(3860611758, UTIL_PCD.KEY_REQ, 0, h, 1)
    -- no team-dock input while the plate runs the session (restored below / by the retail path after the branch).
    -- 2026-10-13 (owner: «en las pasivas configurables el jugador se ve alejado»): the dock's layer group
    -- team_dock_formation_menu (935586083) is NOT suspended any more. Its name is also the menu model camera's
    -- (external_camera_config row 25), and the player page's 3D model (Inazuma Fantasy's plate_model, layer
    -- evt_pp_model) is framed by that camera: with the group suspended the model drew tiny at the left edge. The
    -- retail dock never suspends that group while a 3D model is up (its visual check, type 6, skips the suspend);
    -- the state kept here is the one of the ordinary player page over the dock (the dock's menu object inactive);
    -- the dock's field is hidden layer by layer instead (UTIL_PCD.HideField, shown again after the session).
    pcall(funcLuaMenuCommand, 1558704558, 2049316981, false)
    if g_parentMenuId ~= nil and g_parentMenuId ~= 0 then
      pcall(funcLuaMenuCommand, 1558704558, g_parentMenuId, false)
    end
    UTIL_PCD.HideField()
    local wait = 0
    while true do
      coroutine.yield()
      UTIL_PCD.HideField()
      if funcLuaCommand(2947612279, UTIL_PCD.KEY_DONE) then
        UTIL_PCD.P(UTIL_PCD.KEY_DONE)
        break
      end
      if funcLuaCommand(2947612279, UTIL_PCD.KEY_REQ) then
        wait = wait + 1
        if wait > UTIL_PCD.WAIT_TAKE then
          UTIL_PCD.P(UTIL_PCD.KEY_REQ)
          UTIL_PCD.P(UTIL_PCD.KEY_PARENT)
          pcall(funcLuaCommand, 1917805374, 2086672038)
          break
        end
      end
    end
    coroutine.yield()
    UTIL_PCD.ShowField()
    if g_parentMenuId ~= nil and g_parentMenuId ~= 0 then
      pcall(funcLuaMenuCommand, 1558704558, g_parentMenuId, true)
    end
    if type(SetupDefaultFormationButtonGuide) == "function" then
      pcall(SetupDefaultFormationButtonGuide)
    end
    return true
  end

  -- every layer instance this menu sets up (the field UTIL_PCD.HideField hides during a session)
  UTIL_PCD.Wrap("OnSetupLayer", function(orig)
    return function(a1, a2, ...)
      UTIL_PCD.Note(a1, a2)
      return orig(a1, a2, ...)
    end
  end)

  UTIL_PCD.Wrap("GetSelectSettingTypeOrderList", function(orig)
    return function(...)
      local src = orig(...)
      if type(src) ~= "table" then
        return src
      end
      if type(IsSelectLeaderCard) == "function" and IsSelectLeaderCard() then
        return src
      end
      if type(GetFormationSelectCharaStHdl) ~= "function" then
        return src
      end
      local h = GetFormationSelectCharaStHdl()
      local on, mode = UTIL_PCD.Info(h)
      if not on then
        return src
      end
      local out = {}
      local has9 = false
      for i = 1, #src do
        local t = src[i]
        if t == 9 then
          has9 = true
        end
        if t ~= 10 and (mode > 0 or t ~= 9) then
          out[#out + 1] = t
        end
      end
      if mode > 0 then
        if not has9 then
          out[#out + 1] = 9
        end
        EVT_PRIME_NO_INHERIT = false -- Inazuma Fantasy's Prime refusal belongs to the retired inheritance
        if type(RemoveToGrayoutList) == "function" then
          RemoveToGrayoutList(9)
        end
      end
      return out
    end
  end)
  -- «Configuración de pasivas» (setting type 9) of the player popup: the session above instead of the inherit menu,
  -- for the players the plugin configures (the same test UTIL_PCD.Plate makes)
  if VRFW_ListRows ~= nil then
    VRFW_ListRows.Handle(VRFW_ListRows.PLAYER_COMMANDS, {id = "utilities.passive_config",
      row = VRFW_ListRows.PLAYER_COMMAND.INHERITED_PASSIVES,
      when = function(context)
        local on, mode = UTIL_PCD.Info(context.handle)
        return on and mode > 0
      end,
      run = function(context)
        UTIL_PCD.Plate(context.handle)
      end})
  end
@ICONS@
  UTIL_PCI.Install(UTIL_PCD.Wrap)
end
