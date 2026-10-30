-- ===================================================================================================
-- Chrono Stone MIXIMAX scene (docs/game/media/miximax-cutscene-cs.md §8): after «Crear miximax» saved and
-- assigned the fusion, the menu reserves story event ev99_97010 in the Inazuma Caravan map (evtgx_tm_i) with the
-- base and the partner (the loader fills them in: CMND_EVT_MX_SCENE). Pattern of the retail scene archive
-- (scene_archive_menu.PlayEventCoroutine): fade out, BGM stop, CMND_RESERVE_MAP_JUMP, close the menu,
-- CMND_RESERVE_EVENT. Only from the menu-scene team dock (soccer_team_dock_menu open: reached from the title or
-- the main menu; the RPG / Chronicle docks run inside the field scene). A skips the scene (graft mx_scene on
-- event_menu). PL.MX_SCENE_ON = false: no scene (the fusion alone). The loader's «scene pending» state is cleared
-- when the reserve fails, when this menu opens again and after 90 s (CMND_EVT_MX_SCENE_END / loader timeout).
-- ===================================================================================================
PL.MX_SCENE_ON = true
PL.MX_CMD.SCENE = @crc:CMND_EVT_MX_SCENE@             -- (base) -> ok, event, map | false, reason
PL.MX_CMD.SCENE_END = @crc:CMND_EVT_MX_SCENE_END@        -- (why)
PL.MX_CMD.SCENE_STATE = @crc:CMND_EVT_MX_SCENE_STATE@      -- () -> pending, base handle, seconds
PL.MX_CMD.SCENE_RUN = @crc:CMND_EVT_MX_SCENE_RUN@        -- () -> true, slot | false, why
PL.MX_CMD.SCENE_TICK = @crc:CMND_EVT_MX_SCENE_TICK@       -- () -> "starting" | "running" | "done" | "idle"
-- 2026-10-12 (Nacho's video: no effect ever showed, the final shot far too close and without the miximax look, the top
-- bar and «A Aceptar» drawn over the scene): the scene plays through the VR-Framework's live player (the one the Mods
-- screen plays moves with over the menus, docs/game/media/visor-en-vivo.md §11): the same push of SceneEvent as IF's
-- own player, plus what that player learnt (the event camera kept current every frame, the menu models' own view
-- cleared while it plays, the sounds / photo button handled). One mechanism for both. Its end hold is switched off
-- (the scene plays to its end). PL.MX_SCENE_LIVE = false: IF's own player (CMND_EVT_MX_SCENE_RUN / _TICK) as before.
PL.MX_SCENE_LIVE = true
PL.MX_CMD.LIVE_RUN = @crc:CMND_VRFW_ANIM_LIVE_RUN@         -- (reservation, event) -> true, slot | false, why
PL.MX_CMD.LIVE_TICK = @crc:CMND_VRFW_ANIM_LIVE_TICK@        -- () -> phase, frame, total, ...
PL.MX_CMD.LIVE_CTL = @crc:CMND_VRFW_ANIM_LIVE_CTL@          -- (op, n): "hold" 0 = play into the end
PL.MX_CMD.LIVE_WINDOW = @crc:CMND_VRFW_ANIM_LIVE_WINDOW@      -- (x, y, w, h, muted): w 0 = full screen
PL.MX_CMD.LIVE_VIEW = @crc:CMND_VRFW_ANIM_LIVE_VIEW@        -- (zoom, pan x, pan y): 1, 0, 0 = the event's framing
PL.mx_scene_live = false
PL.mx_scene_busy = false                -- the scene is on: this screen takes no input (our own flag, below)

-- the live player answers (a VR-Framework without it: IF's own player)
function PL.MxSceneLiveOn()
  if not PL.MX_SCENE_LIVE then
    return false
  end
  local ok, ph = pcall(funcLuaCommand, PL.MX_CMD.LIVE_TICK)
  return ok and type(ph) == "string"
end

-- run the reserved event `ev` -> pcall results (ok, true, slot | ok, false, why)
function PL.MxSceneRun(reserved, ev)
  if PL.mx_scene_live then
    pcall(funcLuaCommand, PL.MX_CMD.LIVE_WINDOW, 0, 0, 0, 0, 0)
    pcall(funcLuaCommand, PL.MX_CMD.LIVE_VIEW, 1, 0, 0)
    local ok, run, info = pcall(funcLuaCommand, PL.MX_CMD.LIVE_RUN, reserved, ev)
    if ok and run == true then
      pcall(funcLuaCommand, PL.MX_CMD.LIVE_CTL, "hold", 0)
    end
    return ok, run, info
  end
  return pcall(funcLuaCommand, PL.MX_CMD.SCENE_RUN, reserved)
end

-- one frame of the playing event -> ok, "starting" | "running" | "done" | "idle", seconds since the event start
function PL.MxSceneTick()
  if PL.mx_scene_live then
    local ok, ph, frame, total = pcall(funcLuaCommand, PL.MX_CMD.LIVE_TICK)
    return ok, ph, (type(frame) == "number" and frame / 60 or nil), (type(total) == "number" and total / 60 or nil)
  end
  return pcall(funcLuaCommand, PL.MX_CMD.SCENE_TICK)
end

-- the VR-Framework's top bar (the shortcut row of the hub's header): away while the scene plays (its param
-- vrfw_top_bar_hidden, VRFW_TopBarHide of the framework's lua _all 10_top_bar.lua; set directly when that global is
-- not in this VM)
function PL.MxSceneTopBar(hide)
  if type(VRFW_TopBarHide) == "function" then
    pcall(VRFW_TopBarHide, hide)
  elseif hide then
    pcall(funcLuaCommand, C.P_SET, 1455983968 --[[vrfw_top_bar_hidden]], 0, 1, 1)
  elseif funcLuaCommand(C.P_HAS, 1455983968) == true then
    pcall(funcLuaCommand, C.P_CLEAR, 1455983968)
  end
end
PL.MX_SCENE_DOCK = 937147172            -- soccer_team_dock_menu
PL.MX_SCENE_TOP = 811496143             -- soccer_top_menu (hub; dock opened by graft comp_menu)
PL.MX_SCENE_DOCK_TOP = 91676902         -- team_dock_common_top_menu: the dock opened it = the dock is the scene root
PL.MX_SCENE_CHRONICLE = 3902542018      -- chronicle_mode_top_menu (its dock: no scene)
-- 01/10/2026, 4th version (docs/game/media/miximax-cutscene-cs.md §9.4, static RE of nie.exe): a reserved event only
-- plays in scenes that run the event dispatcher every frame (CSceneRpg / CSceneSoccer) and have an event state that
-- pushes SceneEvent (game::EventState, menuvsroute::EventState: Chronicle / Players Universe). The team dock's
-- CSceneMenu has neither, so closing menus (versions 2-3) only left a black screen. Now the loader plays it the way
-- menuvsroute::EventState does (CMND_EVT_MX_SCENE_RUN / _TICK, transform/miximax/event_play.rs): SceneEvent is pushed
-- on top of the menu scene, NOTHING is closed, and this coroutine waits for it and comes back to this same screen.
-- The menus are suspended while it plays (as soccer_top_menu does while its dock is open).
PL.MX_SCENE_HIDE = {EVT_MENU, 1981996040 --[[chara_bank_menu_for_search]], 968210065 --[[sub_window]],
  1427722143 --[[personal_plate_menu]], 935586083 --[[team_dock_formation_menu]], 2049316981 --[[soccer_formation_menu]],
  937147172 --[[soccer_team_dock_menu]], 91676902 --[[team_dock_common_top_menu]], 811496143 --[[soccer_top_menu]]}
-- 02/10/2026 (Nacho): the header bar («Equipamiento», team plate, rank), the guide line and the button guide were
-- still drawn over the scene (the blue speed-line background stays, as wanted). They are layers of the dock's common
-- top menu / the hub (team_dock_common_top_menu OnSetupLayer: mainmenu90_01_header, mainmenu90_31_doc_item; soccer_top
-- also mainmenu90_03_header_rank) and of the screen's parent (button guide, mainmenu01_06_base_button_guide). Hidden with
-- the retail per-menu layer visibility command 3579981806(menu, layer, 0 | 1) (soccer_top_menu_inc
-- SetButtonGuideVisibleFromTopMenu) and given back with 1 in reverse order.
PL.MX_SCENE_BAR_MENUS = {91676902 --[[team_dock_common_top_menu]], 811496143 --[[soccer_top_menu]],
  937147172 --[[soccer_team_dock_menu]]}
PL.MX_SCENE_BARS = {575058101 --[[mainmenu90_01_header]], 2750436121 --[[mainmenu90_03_header_rank]],
  2279382105 --[[mainmenu90_31_doc_item]], 3078308064 --[[mainmenu90_05_content_guide_line01]],
  1138543975 --[[mainmenu01_06_base_button_guide]]}
PL.MX_CMD.MENU_LAYER_VISIBLE = 3579981806
-- -> list of {menu, layer} hidden
-- 02/10 12:10 (Nacho's video): the button guide went, the header and the guide line stayed (3579981806 does not
-- reach them). Graft mx_scene_bars puts EVT_MxSceneBars(hide) in team_dock_common_top_menu and soccer_top_menu; it is
-- called there with the retail cross-menu call 830228314 (as SwapSoccerTopCommonHeaderByHeaderType).
PL.MX_SCENE_BAR_OWNERS = {91676902 --[[team_dock_common_top_menu]], 811496143 --[[soccer_top_menu]]}
function PL.MxSceneBarOwners(hide)
  for _, m in ipairs(PL.MX_SCENE_BAR_OWNERS) do
    if funcLuaMenuCommand(C.EXIST_MENU, m) == true then
      local ok, r = pcall(funcLuaCommand, 830228314, m, "EVT_MxSceneBars", hide)
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene bars", string.format("%08X", m), tostring(hide),
        tostring(ok), tostring(r))
    end
  end
end
function PL.MxSceneBars(hide, list)
  if not hide then
    PL.MxSceneBarOwners(false)
    funcLuaMenuCommand(C.LAYER_VISIBLE, 3078308064 --[[mainmenu90_05_content_guide_line01]], 0, true)
    for i = #list, 1, -1 do
      pcall(funcLuaMenuCommand, PL.MX_CMD.MENU_LAYER_VISIBLE, list[i][1], list[i][2], 1)
    end
    return list
  end
  PL.MxSceneBarOwners(true)
  -- 02/10 round 2: «Reparte los puntos de Libertad…» is this screen's own guide line (graft training_btn), drawn even
  -- with the menu hidden
  funcLuaMenuCommand(C.LAYER_VISIBLE, 3078308064 --[[mainmenu90_05_content_guide_line01]], 0, false)
  local out, seen = {}, {}
  local menus = {}
  for _, m in ipairs(PL.MX_SCENE_BAR_MENUS) do menus[#menus + 1] = m end
  if n12 ~= nil and n12 ~= 0 then menus[#menus + 1] = n12 end
  for _, m in ipairs(menus) do
    if not seen[m] and funcLuaMenuCommand(C.EXIST_MENU, m) == true then
      seen[m] = true
      for _, L in ipairs(PL.MX_SCENE_BARS) do
        if pcall(funcLuaMenuCommand, PL.MX_CMD.MENU_LAYER_VISIBLE, m, L, 0) then
          out[#out + 1] = {m, L}
        end
      end
    end
  end
  return out
end
PL.MX_SCENE_MAX_FRAMES = 60 * 180      -- give the menus back after 3 min whatever the loader says
-- 02/10 12:10 (Nacho's video): the partner never showed, the base did. A scene played over the menu scene only shows
-- character models already loaded by a menu (the base: this screen's 3D model and the formation frame); the partner is
-- in no team, so nothing has loaded him. Round 2 loaded him in this screen's model (it evicted the base); now he goes to
-- chara_model_only_view_menu (PL.MxScenePreload below). PL.MX_SCENE_PRELOAD = false: off.
PL.MX_SCENE_PRELOAD = true
PL.MX_SCENE_MODEL_LAYER = 2917320188   -- soccer11_05_equip_status_base
PL.MX_SCENE_PRELOAD_MAX = 240          -- coroutine steps waiting for the model
-- «Miximax con X asignado.» INSIDE the scene (Nacho, 02/10): from the end of the animation to the white flash, timed
-- with CMND_EVT_MX_SCENE_TICK's seconds since the event started (recipe research/recipes/mx_scene/mx_scene.toml:
-- animation 0-220, hold_frames 84 -> white at frame 304; 60 fps). Not shown again afterwards.
PL.MX_SCENE_MSG = false               -- round 4 (Nacho): no «Miximax con X asignado.» with the scene
PL.MX_SCENE_MSG_AT = 3.75
PL.MX_SCENE_MSG_END = 5.05
PL.MX_SCENE_MSG_MENU = 449578137       -- general_window

-- this screen's 3D model shows card h (the retail SetupCharaModel reads the screen's card n)
function PL.MxSceneModel(h)
  local keep = n
  n = h
  local ok, err = pcall(SetupCharaModel, PL.MX_SCENE_MODEL_LAYER, 0)
  n = keep
  return ok, err
end

-- 02/10 12:42 (round 2): loading the partner in this screen's model evicted the base (the formation frame did not keep
-- it): only the partner showed. Now the base stays in this screen's model and the partner goes to the retail one-model
-- view menu chara_model_only_view_menu (opened, never shown; graft mx_scene_model): this screen's SetupCharaModel runs
-- for the partner with funcLuaMenuCommand recorded (nothing executed here) and its model commands are replayed on that
-- menu's layer through the retail cross-menu call 830228314. That menu's Step reports «ready» in the parameter store.
PL.MX_SCENE_MV = 275734212             -- chara_model_only_view_menu
PL.MX_SCENE_MV_READY = 2277088171      -- crc32 "evt_mx_scene_model_ready" (graft mx_scene_model)
PL.MX_SCENE_MV_SKIP = {[@crc:CMND_SET_CHARA_MODEL_SHADOW@] = true --[[shadow]], [@crc:CMND_OPEN_LAYER@] = true --[[open layer]]}
PL.mx_scene_mv_opened = false

-- the model commands this screen's SetupCharaModel sends for card h (recorded, not executed)
function PL.MxSceneModelCmds(h)
  local rec = {}
  local real = funcLuaMenuCommand
  funcLuaMenuCommand = function(...)
    rec[#rec + 1] = table.pack(...)
    return nil
  end
  local keep = n
  n = h
  local ok, err = pcall(SetupCharaModel, PL.MX_SCENE_MODEL_LAYER, 0)
  n = keep
  funcLuaMenuCommand = real
  return ok, err, rec
end

function PL.MxSceneMv(name, ...)
  return pcall(funcLuaCommand, 830228314, PL.MX_SCENE_MV, name, ...)
end

-- -> true when the partner's model is loaded in chara_model_only_view_menu (the base stays in this screen's model)
function PL.MxScenePreload(h)
  if not PL.MX_SCENE_PRELOAD or type(h) ~= "number" or h == 0 then
    return false
  end
  local ok, err, rec = PL.MxSceneModelCmds(h)
  if not ok or #rec == 0 then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene preload", "no model commands", tostring(err))
    return false
  end
  if funcLuaMenuCommand(C.EXIST_MENU, PL.MX_SCENE_MV) ~= true then
    funcLuaCommand(@crc:CMND_OPEN_MENU_OBJECT@, PL.MX_SCENE_MV)
    PL.mx_scene_mv_opened = true
  end
  local steps = 0
  while steps < PL.MX_SCENE_PRELOAD_MAX do
    coroutine.yield()
    steps = steps + 1
    local okl, loading = pcall(funcLuaCommand, 667479479, PL.MX_SCENE_MV)
    if funcLuaMenuCommand(C.EXIST_MENU, PL.MX_SCENE_MV) == true and not (okl and loading == true) then
      break
    end
  end
  coroutine.yield()
  PL.MxSceneMv("EVT_MxSceneModelBegin")
  local sent = 0
  for _, r in ipairs(rec) do
    local cmd = r[1]
    if r[2] == PL.MX_SCENE_MODEL_LAYER and not PL.MX_SCENE_MV_SKIP[cmd] then
      if cmd == @crc:CMND_CHARA_MODEL_CHANGE@ then
        PL.MxSceneMv("EVT_MxSceneModelCmd", 180466856 --[[motion]], 2263925137 --[[立ち1L]], 0, 0)
        PL.MxSceneMv("EVT_MxSceneModelCmd", cmd, 0, 9)
      else
        PL.MxSceneMv("EVT_MxSceneModelCmd", cmd, table.unpack(r, 4, r.n))
      end
      sent = sent + 1
    end
  end
  PL.MxSceneMv("EVT_MxSceneModelWatch")
  local ready, wait = nil, 0
  while wait < PL.MX_SCENE_PRELOAD_MAX * 2 do
    coroutine.yield()
    wait = wait + 1
    if funcLuaCommand(C.P_HAS, PL.MX_SCENE_MV_READY) then
      ready = funcLuaCommand(C.P_GET, PL.MX_SCENE_MV_READY)
      funcLuaCommand(C.P_CLEAR, PL.MX_SCENE_MV_READY)
      break
    end
  end
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene preload", string.format("%08X", EVT_U32(h)),
    "model view", tostring(PL.mx_scene_mv_opened), "commands", sent, "ready", tostring(ready), "steps", steps, wait)
  return ready == 1
end

-- Round 4 (Nacho): the base with the miximax look, like the form viewer shows it. The form viewer's pick
-- (CMND_EVT_FORM_MODEL(card, 1) = Miximax: module form_view maps every model request of that character to the look
-- record menu_look(base, partner), pair texture included) is set before this screen's model is rebuilt, so the model
-- the menus keep loaded (and the scene's base actor, created while the pick holds) is the fused one; cleared after the
-- scene. The whole scene shows the fused base (one look per character per load). PL.MX_SCENE_FUSED = false: off.
-- Round 5: only used with PL.MX_SCENE_SWAP = false (the swap below puts the look on at the white flash instead).
PL.MX_SCENE_FUSED = true
PL.MX_CMD.FORM_MODEL = @crc:CMND_EVT_FORM_MODEL@      -- (hdl, form) -> look model id (0 = none)
PL.MX_CMD.FORM_CLEAR = @crc:CMND_EVT_FORM_CLEAR@      -- ()
PL.MX_SCENE_SHADOW_LAYER = 858725131   -- mainmenu01_08_chara_3d_shadow

-- wait (coroutine) until this screen's model is built, at most n steps
function PL.MxSceneModelWait(steps_max)
  local steps = 0
  while steps < steps_max do
    coroutine.yield()
    steps = steps + 1
    local okr, r = pcall(funcLuaMenuCommand, 1583438030, PL.MX_SCENE_MODEL_LAYER, 0, 0)
    if okr and r == true and steps >= 4 then
      return true, steps
    end
  end
  return false, steps
end

-- -> look model id when the fused look is on
function PL.MxSceneFusedLook()
  if not PL.MX_SCENE_FUSED then
    return 0
  end
  local ok, id = pcall(funcLuaCommand, PL.MX_CMD.FORM_MODEL, n, 1)
  id = (ok and type(id) == "number") and id or 0
  if id ~= 0 then
    PL.MxSceneModel(n)                   -- rebuilt: the request now maps to the look
    local ready, steps = PL.MxSceneModelWait(PL.MX_SCENE_PRELOAD_MAX)
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene fused look", string.format("%08X", EVT_U32(id)),
      "ready", tostring(ready), "steps", steps)
  else
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene fused look", "none", tostring(ok))
  end
  return id
end

-- Round 5 (Nacho, 02/10 13:30): the base wore the miximax look from the first frame. He keeps his own look until the
-- white flash and takes the miximax look under it. The scene's characters are NOT new models: LOAD_ACTOR_CHARA
-- binds each actor to the character object a menu already holds with that chara id (round 4 log: the event made no
-- model request for its two players; round 3: the table's model came back moved by the event). So the base actor IS
-- this screen's model object, and the look is swapped on it mid-scene: at PL.MX_SCENE_SWAP_AT seconds after the
-- event runs (inside the full white the recipe holds: research/recipes/mx_scene/mx_scene.toml white_hold_frames;
-- mx_scene_build.py check reads this value), the form viewer's Miximax pick is set and this screen's model commands
-- for the card are sent again (recorded from SetupCharaModel, without the layer / shadow / pose ones, so the event
-- keeps its placement and motion). The event hides the base at the full white and shows / re-attaches him at the
-- final shot. PL.MX_SCENE_SWAP = false: round 4 (fused look for the whole scene, if PL.MX_SCENE_FUSED).
-- Round 6: off (in Nacho's round-5 test the fused player never showed after the mid-scene swap). PL.MX_SCENE_FINAL
-- replaces it (below).
PL.MX_SCENE_SWAP = false
PL.MX_SCENE_SWAP_AT = 4.75             -- seconds since running (event frame 285; full white 280..320)
PL.MX_SCENE_SWAP_MAX = 30              -- coroutine steps waiting for the fused model (the white still holds 35)
PL.MX_SCENE_SWAP_SKIP = {[@crc:CMND_SET_CHARA_MODEL_SHADOW@] = true --[[shadow]], [@crc:CMND_OPEN_LAYER@] = true --[[open layer]],
  [@crc:CMND_UPDATE_CHARA_MODEL_POSE@] = true --[[pose]]}

-- the swap: Miximax pick + this screen's model commands for the card -> look id (0 = no look), commands sent
function PL.MxSceneSwapBegin()
  local ok, id = pcall(funcLuaCommand, PL.MX_CMD.FORM_MODEL, n, 1)
  id = (ok and type(id) == "number") and id or 0
  if id == 0 then
    return 0, 0
  end
  local okc, _err, rec = PL.MxSceneModelCmds(n)
  local sent = 0
  if okc then
    for _, r in ipairs(rec) do
      if r[2] == PL.MX_SCENE_MODEL_LAYER and not PL.MX_SCENE_SWAP_SKIP[r[1]] then
        pcall(funcLuaMenuCommand, table.unpack(r, 1, r.n))
        sent = sent + 1
      end
    end
  end
  return id, sent
end

-- Round 6 (docs/game/media/miximax-cutscene-cs.md §9.13): the finishing shot is a SECOND event (the loader's
-- CMND_EVT_MX_SCENE gives its name, ev99_97020). An event actor binds, when the event starts, to the character object
-- a menu holds; round 4 showed the fused look when it was on the base's model BEFORE the event, round 5 changed it
-- inside the event and the base never came back. So: the main event ends in its white flash -> the white is held
-- (retail white fade 4011714927) -> this screen (resumed for it, still hidden) puts the Miximax look on its model
-- (round 4's PL.MxSceneFusedLook) and its shadow layer stays hidden -> the final event (the base alone, from white,
-- in the stand) is reserved and played -> the caller restores everything as before. PL.MX_SCENE_FINAL = false: the
-- main event alone (it then ends in white without the base fused).
PL.MX_SCENE_FINAL = true
PL.MX_CMD.WHITE_FADE = 4011714927       -- retail white fade (1 out / 0 in, seconds): the title's SwitchCaseTitleFade
PL.MX_SCENE_END_BLACK = 0.25            -- seconds before the final event's end: the fade to black starts
PL.MX_SCENE_END_FADE = 0.15             -- its length (black before the last frame)

-- -> {look = id (0 none), ready, steps, st = TICK state at the end / why not played}
function PL.MxSceneFinal(ev2)
  local r = {look = 0, ready = false, steps = 0, st = "not run", bars = {}}
  pcall(funcLuaCommand, PL.MX_CMD.WHITE_FADE, 1, 0)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final", ev2, "white held")
  pcall(funcLuaMenuCommand, 66378409 --[[resume]], EVT_MENU)
  local okf, id = pcall(PL.MxSceneFusedLook)
  r.look = (okf and type(id) == "number") and id or 0
  if r.look ~= 0 then
    -- PL.MxSceneFusedLook waited for the model; read the state once more for the log
    local okr, ready = pcall(funcLuaMenuCommand, 1583438030, PL.MX_SCENE_MODEL_LAYER, 0, 0)
    r.ready = okr and ready == true
  end
  pcall(funcLuaMenuCommand, C.LAYER_VISIBLE, PL.MX_SCENE_SHADOW_LAYER, 0, false)
  pcall(funcLuaMenuCommand, 369172623 --[[suspend]], EVT_MENU)
  -- 2026-10-12 (Nacho's video): resumed for the look, the screen drew its button guide again («A Aceptar» behind the
  -- final shot): the bars are hidden once more (given back with the others)
  r.bars = PL.MxSceneBars(true)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final look", string.format("%08X", EVT_U32(r.look)),
    "ready", tostring(r.ready))
  local okr, a, b = pcall(funcLuaCommand, @crc:CMND_RESERVE_EVENT@, CALC_CRC(ev2))
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final reserved", ev2, tostring(okr), tostring(a), tostring(b))
  if not okr then
    r.st = "reserve failed"
    return r
  end
  local okp, run, info = PL.MxSceneRun(a, ev2)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final run", tostring(okp), tostring(run), tostring(info),
    PL.mx_scene_live and "live player" or "IF player")
  if not okp or run ~= true then
    r.st = "run refused"
    return r
  end
  -- 2026-10-13 (owner's video, bug 3: as the fused player came back, for an instant another player stood on his left):
  -- the final event ended on a visible frame and, until this screen restored its models, the menu scene drew its
  -- own models (the partner in the one-model view menu, this screen's model) for a frame. The screen now fades to
  -- black PL.MX_SCENE_END_BLACK seconds before the final event's end (black at once when the end comes first), the
  -- menus are restored under it and PL.MxScenePlay's fade back shows the page.
  local frames, st, black = 0, "starting", false
  while frames < PL.MX_SCENE_MAX_FRAMES do
    coroutine.yield()
    frames = frames + 1
    local okt, s, secs, total = PL.MxSceneTick()
    st = okt and s or "error"
    if st ~= "starting" and st ~= "running" then
      break
    end
    if not black and st == "running" and type(secs) == "number" and type(total) == "number" and total > 0
        and secs >= total - PL.MX_SCENE_END_BLACK then
      black = true
      funcLuaCommand(609722083 --[[fade]], 1, PL.MX_SCENE_END_FADE)
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final", "black before the end", secs, total)
    end
  end
  if not black then
    funcLuaCommand(609722083 --[[fade]], 1, 0)
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final", "black at the end", frames)
  end
  r.st = st
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final back", st, frames)
  return r
end

-- round 4: after the scene the table's model was tiny and far (left at the scene's / model view's placement): the
-- model layer and its shadow are closed and opened again, so the retail OnOpenLayer builds them as when the screen
-- opened (placement, camera, scale, pose), with the pick cleared (his own look)
function PL.MxSceneModelRestore(fused)
  if fused ~= 0 then
    pcall(funcLuaCommand, PL.MX_CMD.FORM_CLEAR)
  end
  pcall(funcLuaMenuCommand, @crc:CMND_CLOSE_LAYER@, PL.MX_SCENE_MODEL_LAYER, 0)
  pcall(funcLuaMenuCommand, @crc:CMND_CLOSE_LAYER@, PL.MX_SCENE_SHADOW_LAYER, 0)
  coroutine.yield()
  pcall(funcLuaMenuCommand, @crc:CMND_OPEN_LAYER@, PL.MX_SCENE_MODEL_LAYER, 0)
  pcall(funcLuaMenuCommand, @crc:CMND_OPEN_LAYER@, PL.MX_SCENE_SHADOW_LAYER, 0)
  local ready, steps = PL.MxSceneModelWait(PL.MX_SCENE_PRELOAD_MAX)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene model restored", "ready", tostring(ready), "steps", steps)
end

-- after the scene: the one-model view menu closed (only when this screen opened it)
function PL.MxScenePreloadEnd()
  if PL.mx_scene_mv_opened then
    pcall(funcLuaCommand, @crc:CMND_CLOSE_MENU_OBJECT@, PL.MX_SCENE_MV)
    PL.mx_scene_mv_opened = false
  end
end
-- routes that play it (false = only «Miximax con X asignado.»)
PL.MX_SCENE_ROUTES = {root = true, hub = true}
-- "root", "hub" or nil, reason
function PL.MxSceneContext()
  local function has(m)
    return funcLuaMenuCommand(C.EXIST_MENU, m) == true
  end
  if not has(PL.MX_SCENE_DOCK) then
    return nil, "not the menu-scene team dock"
  end
  if has(PL.MX_SCENE_CHRONICLE) then
    return nil, "Chronicle dock"
  end
  local ctx
  if has(PL.MX_SCENE_TOP) then
    ctx = "hub"
  elseif has(PL.MX_SCENE_DOCK_TOP) then
    ctx = "root"
  else
    return nil, "dock neither the scene root nor under soccer_top_menu"
  end
  if PL.MX_SCENE_ROUTES[ctx] ~= true then
    return nil, ctx .. " route off (PL.MX_SCENE_ROUTES)"
  end
  return ctx
end

-- true = the scene played and the screen is back (the caller then shows «Miximax con X asignado.»)
function PL.MxScenePlay()
  if not PL.MX_SCENE_ON or PL.MxStub() or n == nil or n == 0 then
    return false
  end
  local ctx, why = PL.MxSceneContext()
  if ctx == nil then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene", "skipped: " .. why)
    PL.MxUnblack()
    return false
  end
  -- the loader's player must be there BEFORE anything is reserved (an older inazuma_fantasy.dll has no _TICK: a
  -- reservation nobody plays would wait for the next story field)
  PL.mx_scene_live = PL.MxSceneLiveOn()
  local okt0, t0 = PL.MxSceneTick()
  if not okt0 or type(t0) ~= "string" then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene", "skipped: the loader has no scene player")
    PL.MxUnblack()
    return false
  end
  local ok, go, ev, map, phdl, ev2, fxn = pcall(funcLuaCommand, PL.MX_CMD.SCENE, n)
  if not ok or go ~= true or type(ev) ~= "string" then
    PL.MxUnblack()
  end
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene", ctx, tostring(ok), tostring(go), tostring(ev), tostring(map),
    tostring(phdl), "final", tostring(ev2), "effects installed", tostring(fxn))
  -- round 6 (docs §9.13): the finishing shot is a second event the loader prepared (ev2 ~= ""): the base's
  -- miximax look goes on his model between the two events, so the second event's actor binds to the fused model
  local two = PL.MX_SCENE_FINAL and ok and type(ev2) == "string" and ev2 ~= ""
  PL.mx_scene_msg_shown = false
  if not ok or go ~= true or type(ev) ~= "string" then
    return false
  end
  -- 2026-10-12: nothing of this screen reacts while the scene plays (own flag: its callbacks and Step polls return at
  -- once, see the guard at the end of the file; the menu's input state / controller is never touched)
  PL.mx_scene_busy = true
  PL.MxSceneTopBar(true)
  funcLuaCommand(@crc:CMND_BGM_STOP@, 0.5)
  funcLuaCommand(609722083 --[[fade]], 1, 0.5)
  while funcLuaCommand(@crc:CMND_BRIGHT_IS_FADE@) do
    coroutine.yield()
  end
  -- under the black: this screen's 3D model loads the partner (see PL.MX_SCENE_PRELOAD)
  if type(phdl) ~= "number" or phdl == 0 then
    phdl = PL.mx_done_partner
  end
  -- round 6: two events = the look goes on between them (PL.MxSceneFinal); round 5: mid-scene (PL.MX_SCENE_SWAP, it
  -- never showed); round 4: before the scene (the base fused from the first frame)
  local fused = (two or PL.MX_SCENE_SWAP) and 0 or PL.MxSceneFusedLook()
  local summary = {main = "not run", final = two and ev2 or "-", look = 0, ready = "-", final_run = "-"}
  local preloaded = PL.MxScenePreload(phdl)
  local okr, a, b = pcall(funcLuaCommand, @crc:CMND_RESERVE_EVENT@, CALC_CRC(ev))
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene reserved", ev, tostring(okr), tostring(a), tostring(b))
  local played = false
  local hidden = {}
  local bars = {}
  if okr then
    -- 01/10 23:30 (Nacho): the scene showed BEHIND the skill table: suspending the layer groups does not stop the
    -- drawing. Hide every menu of the stack the way the retail hides them for a full-screen movie
    -- (scene_archive_menu.PlayMovieCoroutine / soccer_top_menu: 1670867360(1, menu) ... 3257327861(menu)), and put the
    -- menu scene's blue backdrop (craft object bg10000, as soccer_top_menu does after its movie) behind the players.
    for _, m in ipairs(PL.MX_SCENE_HIDE) do
      if funcLuaMenuCommand(C.EXIST_MENU, m) == true then
        funcLuaMenuCommand(369172623 --[[suspend]], m)
        funcLuaMenuCommand(1670867360 --[[hide (movie)]], 1, m)
        hidden[#hidden + 1] = m
      end
    end
    bars = PL.MxSceneBars(true)
    funcLuaCommand(@crc:CMND_EXEC_CRAFT_OBJ_ID@, 623523592 --[[bg10000]])
    local okp, run, info = PL.MxSceneRun(a, ev)   -- a = the reservation id
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene run", tostring(okp), tostring(run), tostring(info),
      PL.mx_scene_live and "live player" or "IF player")
    if okp and run == true then
      local frames, st = 0, "starting"
      local msg = 0                      -- 0 not yet, 1 open, 2 closed
      local swap, swap_steps = 0, 0      -- 0 not yet, 1 waiting for the fused model, 2 done
      while frames < PL.MX_SCENE_MAX_FRAMES do
        coroutine.yield()
        frames = frames + 1
        local okt, s, secs = PL.MxSceneTick()
        st = okt and s or "error"
        if st ~= "starting" and st ~= "running" then
          break
        end
        -- round 5: the miximax look under the white flash (a DLL without the seconds: no swap, his own look)
        if PL.MX_SCENE_SWAP and swap == 0 and st == "running" and type(secs) == "number" and secs >= PL.MX_SCENE_SWAP_AT then
          local id, sent = PL.MxSceneSwapBegin()
          fused = id
          swap = id ~= 0 and 1 or 2
          pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene swap", string.format("%08X", EVT_U32(id)),
            "commands", sent, "at", secs)
        elseif swap == 1 then
          swap_steps = swap_steps + 1
          local okr, r = pcall(funcLuaMenuCommand, 1583438030, PL.MX_SCENE_MODEL_LAYER, 0, 0)
          if (okr and r == true and swap_steps >= 4) or swap_steps >= PL.MX_SCENE_SWAP_MAX then
            swap = 2
            pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene swap ready", tostring(okr and r == true), "steps",
              swap_steps, "at", secs)
          end
        end
        -- «Miximax con X asignado.» between the end of the animation and the white flash (a DLL without the seconds
        -- returns none: the text comes after the scene as before)
        if PL.MX_SCENE_MSG and st == "running" and type(secs) == "number" then
          if msg == 0 and secs >= PL.MX_SCENE_MSG_AT then
            msg = 1
            PL.mx_scene_msg_shown = true
            pcall(funcLuaCommand, C.MSG_OPEN, PL.Txt(PL.MX_TX.ASSIGNED, PL.mx_done_name or ""), 0, 0, 0,
              0, 0, false)
            pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene message", "open", secs)
          elseif msg == 1 and secs >= PL.MX_SCENE_MSG_END then
            msg = 2
            pcall(funcLuaCommand, @crc:CMND_CLOSE_MENU_OBJECT@, PL.MX_SCENE_MSG_MENU)
            pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene message", "closed", secs)
          end
        end
      end
      if msg == 1 then
        pcall(funcLuaCommand, @crc:CMND_CLOSE_MENU_OBJECT@, PL.MX_SCENE_MSG_MENU)
      end
      played = st == "done"
      summary.main = st
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene back", st, frames)
      if played and two then
        local r = PL.MxSceneFinal(ev2)
        fused = r.look
        summary.look, summary.ready, summary.final_run = r.look, tostring(r.ready), r.st
        for _, b in ipairs(r.bars or {}) do
          bars[#bars + 1] = b
        end
      end
    else
      summary.main = "run refused"
    end
  end
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene summary", "actors base + partner (partner model ready",
    tostring(preloaded) .. ")", "main", summary.main, "final", summary.final, "look", string.format("%08X", EVT_U32(summary.look)),
    "look ready", summary.ready, "final run", summary.final_run, "effects installed", tostring(fxn),
    "(drawn: see mods: trace lines)")
  PL.MxSceneBars(false, bars)
  for i = #hidden, 1, -1 do
    funcLuaMenuCommand(3257327861 --[[show again]], hidden[i])
    funcLuaMenuCommand(66378409 --[[resume]], hidden[i])
  end
  PL.MxScenePreloadEnd()
  PL.MxSceneModelRestore(fused)
  pcall(funcLuaCommand, PL.MX_CMD.SCENE_END, played and "played over the menus" or "not played")
  PL.MxSceneTopBar(false)
  PL.mx_scene_busy = false
  PL.mx_preblack = false                         -- the fade back below gives the screen back
  funcLuaCommand(@crc:CMND_BGM_RESUME@)
  funcLuaCommand(609722083 --[[fade]], 0, 0.3)
  while funcLuaCommand(@crc:CMND_BRIGHT_IS_FADE@) do
    coroutine.yield()
  end
  return played
end

-- this menu open again (back from the scene, or any later visit): the scene is over. Opened for the card of a scene
-- that was still pending (the dock's way back, graft mx_scene_back): «Miximax con X asignado.» once the screen is up.
PL.MxScenePrevInit = OnInit
function OnInit()
  local okS, on, base = pcall(funcLuaCommand, PL.MX_CMD.SCENE_STATE)
  pcall(funcLuaCommand, PL.MX_CMD.SCENE_END, "skill slot menu opened")
  local r = PL.MxScenePrevInit()
  if okS and on == true and type(base) == "number" and n ~= nil and EVT_U32(base) == EVT_U32(n) then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene: back on the card", string.format("%08X", EVT_U32(n)))
    PL.deferred[#PL.deferred + 1] = coroutine.create(PL.MxSceneBackMessage)
  end
  return r
end

function PL.MxSceneBackMessage()
  for _ = 1, 20 do                     -- the screen's open animation / first rows
    coroutine.yield()
  end
  while funcLuaCommand(@crc:CMND_BRIGHT_IS_FADE@) do
    coroutine.yield()
  end
  local f = PL.MxGet()
  local name = f ~= nil and PL.MxCharaName(f.chara) or ""
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  EVT_Message(PL.Txt(PL.MX_TX.ASSIGNED, name))
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- yes/no "¿Quitar el miximax con X?": Sí = MX_CLEAR + the Hiper slot emptied; true when removed
function PL.MxAskRemove()
  local f = PL.MxGet()
  if f == nil then
    return false
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  local yes = PL.MxAsk(PL.Txt(PL.MX_TX.ASK_REMOVE, PL.MxCharaName(f.chara)))
  if yes then
    PL.mx_removing = true
    pcall(PL.MxPrevRestore, 0)                    -- the Hiper slot emptied (native Eliminar path)
    PL.mx_removing = false
    PL.MxClear()
  else
    funcLuaCommand(C.SE, SE_BACK)
  end
  EVT_RefreshRows()
  UpdateEquipItemInfo()
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
  return yes
end

PL.MxPrevPick = EVT_PickCoroutine
function EVT_PickCoroutine(row)
  if row == 0 and EVT_Skill(0) == PL.MX_FUSION and PL.MxGet() ~= nil then
    PL.MxAskRemove()                               -- 2026-09-25 rule: no picker while a fusion is the Hiper
    return
  end
  if row == 0 then
    funcLuaCommand(C.P_CLEAR, PL.MX_KEY_DEL)
    funcLuaCommand(C.P_CLEAR, PL.MX_KEY_PRIME)
    funcLuaCommand(C.P_CLEAR, PL.MX_KEY_FUSED)
    for _, k in ipairs({PL.MX_KEY_PCHARA, PL.MX_KEY_M1, PL.MX_KEY_M2, 3808658029}) do
      funcLuaCommand(C.P_CLEAR, k)
    end
    P_Set(PL.MX_KEY_BASE, n)                     -- the picker checks the retail miximaxes against this player
    if EVT_IsPrime() then
      P_Set(PL.MX_KEY_PRIME, 1)
    elseif not PL.MxStub() then
      local okc, can = false, false
      if n ~= nil and n ~= 0 then
        okc, can = pcall(funcLuaCommand, PL.MX_CMD.CAN_BASE, n)
      end
      local okg, gr = false, "not asked"
      if okc and can then
        okg, gr = pcall(PL.MxGrant, 1)             -- "Crear miximax" in the MIXIMAX tab
      end
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax picker", "hdl", tostring(n), "can_base", tostring(okc),
        tostring(can), "grant", tostring(okg), tostring(gr))
      local okf, f = pcall(PL.MxGet)
      if okf and f ~= nil then
        P_Set(PL.MX_KEY_FUSED, 1)                  -- the fusion aura is choosable only with a fusion
        P_Set(PL.MX_KEY_PCHARA, f.chara or 0)      -- the picker draws the fusion as the partner + the 2 moves
        P_Set(3808658029, f.face or f.chara or 0)   -- the partner's face key (portrait)
        P_Set(PL.MX_KEY_M1, f.move or 0)
        P_Set(PL.MX_KEY_M2, f.move2 or 0)
      end
    end
    -- «Crear nuevo cambio» + the player's changes in the «Modo cambio» tab (2026-10-04: it was never called, the tab
    -- stayed empty); Prime cards get no pseudo-items, as «Crear miximax»
    if not EVT_IsPrime() then
      local okc, errc = pcall(PL.McPrepare)
      if not okc then
        pcall(EVT_Call, C.EVT_LOG, "skill_slots", "mode change picker", "error", tostring(errc))
      end
    end
  end
  -- 2026-09-25: the loader drops "Crear miximax" and the fusion carrier from every Habilidades list; the Hiper
  -- picker keeps "Crear miximax" only while this flag is 1 (docs/game/ui/miximax-partner-bank.md §6)
  local flag = row == 0 and not EVT_IsPrime()
  pcall(funcLuaCommand, @crc:CMND_EVT_UI_FLAG_SET@, 2656223599, flag and 1 or 0)
  local ok, err = pcall(PL.MxPrevPick, row)
  pcall(funcLuaCommand, @crc:CMND_EVT_UI_FLAG_SET@, 2656223599, 0)
  if not ok then
    error(err, 0)
  end
end

-- the two items are not in the save by default (§12.5): "Crear miximax" is granted when the Hiper picker opens for a
-- base that can fuse, the fusion aura when the first fusion is made; never a second copy. which: 1 create, 2 fusion
function PL.MxGrant(which, force)
  local ok, create, fusion = pcall(funcLuaCommand, PL.MX_ITEMS_CMD)
  if not ok or type(create) ~= "number" then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax items", tostring(ok), tostring(create))
    return false
  end
  create, fusion = EVT_U32(create), EVT_U32(fusion or 0)
  PL.MX_CREATE, PL.MX_FUSION = create, fusion
  local id = which == 1 and create or fusion
  if id == 0 then
    return false
  end
  local have = funcLuaCommand(PL.ITEM_NUM, id)
  if type(have) == "number" and have > 0 and not force then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax grant", string.format("%08X", id), "already owned", have)
    return "owned"
  end
  local h = funcLuaCommand(PL.ADD_ITEM, id, 1, false)
  local after = funcLuaCommand(PL.ITEM_NUM, id)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax grant", string.format("%08X", id), "hdl", tostring(h),
    "count", tostring(after))
  return "granted"
end

-- Eliminar on the Hiper row while it holds the fusion: the fusion is undone too
PL.MxPrevRestore = EVT_RestoreCoroutine
function EVT_RestoreCoroutine(row)
  if row == 0 and EVT_Skill(0) == PL.MX_FUSION and not PL.mx_removing then
    PL.MxAskRemove()                               -- Eliminar on the row: the same confirm
    return
  end
  PL.MxPrevRestore(row)
end

-- the Hiper row with a fusion: "Miximax: <partner>"
PL.MxPrevRow = UpdateEquipListItem
function UpdateEquipListItem(a1)
  PL.MxPrevRow(a1)
  if a1 ~= 0 then
    return
  end
  local okf, f = pcall(PL.MxGet)
  if okf and f ~= nil and EVT_Skill(0) == PL.MX_FUSION then
    local info = GetEquipListItemInfo(GetEquipType(0))
    local text = EVT_Name(PL.MX_FUSION)             -- 2026-10-12 (owner): the move's name only, never the player's
    if EVT_SPECIAL_LABEL ~= "" then
      text = EVT_SPECIAL_LABEL .. "   " .. text
    end
    funcLuaMenuCommand(C.TEXT, L_ROW, info.itemTextName, text, 0)
  end
end

-- the aura that comes with the miximax (loader CMND_EVT_MX_AURA(chara) -> auraId, kind: 1 the partner's keshin /
-- totem, 2 the base's own armour; 0, 0 none) as a second full-size retail aura header under the move row, filled as
-- the retail headers are: band by type + element, type icon, name, masked portrait (layer evt_ss_aura2)
PL.L_AURA2 = 2525671790
PL.AURA_FACE_TYPE = {[0] = 8, 8, 12, 14}          -- retail SwapLayerFaceIconTex type per aura type

function PL.MxDetail(f, team_info)
  local A = PL.MX_LAYER
  if not funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, A) then
    return false
  end
  PL.DetailHideAll()
  PL.mx_f, PL.mx_ti, PL.mx_view = f, team_info, "mx"     -- every focus starts on the miximax view
  PL.Open(A)
  PL.Open(PL.L_HIPER)
  local el = PL.mx_elem[f.partner]
  if el == nil or el < 1 or el > 5 then
    local _, me = funcLuaCommand(C.SKILL_INFO, f.move, 7)
    el = (type(me) == "number" and me >= 1 and me <= 5) and me or 1
  end
  local bands = {3558327990, 1293850380, 974759834, 2759668281, 3547988655}   -- mixi_base01..05 (team00_30)
  funcLuaMenuCommand(C.SPRITE, A, 2815298114 --[[team00_30 <LG>]], bands[el], 1716659057 --[[fs_base01]], 0, 0)
  funcLuaMenuCommand(C.SPRITE, A, 2320109963 --[[icon_common]], 2185069032 --[[icon_sp_area07]], 4285917355 --[[icon_fs_area_dmy01]], 0, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, A, 2449339029 --[[_icon_fs_dmy01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, A, 1605611365, true, 0)
  PL.AuraClean(A)                                   -- "Hiperenergía", the red pill, the move-page band, page dots

  local pname = PL.MxCharaName(f.chara)
  -- 2026-10-12 (owner): the card's title is the move's name only («Miximax Trans»), never the player's
  funcLuaMenuCommand(C.TEXT, A, 2915321899 --[[_text_fs01]], EVT_Name(PL.MX_FUSION), 0)
  -- one gained move (rule 2026-09-25): its row + TENSIÓN, then the description (page 3)
  funcLuaMenuCommand(2158717427, A, 622567014 --[[_pos_page03]], true, 0)
  -- 2026-09-25 (user rule, hiper-match-slot.md §16.28 / §16.31): no text under a miximax (the gains live in the
  -- plate's Atributos L3 view) and no empty quote bar; that space holds the second aura header (PL.MxAura2)
  funcLuaMenuCommand(C.TEXT, A, 2956552560 --[[_text_flavor02]], "", 0)
  funcLuaMenuCommand(2735666188, A, 2956552560, false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, A, 728354709, false, 0)
  -- the partner's icon through the retail mask (retail miximax rule: _icon_chr_dmy01, icon type 12)
  local face = f.face or f.chara
  if face ~= nil and face ~= 0 then
    pcall(PL.FaceReset, A)
    funcLuaMenuCommand(C.MESH_VISIBLE, A, 478320441 --[[_icon_chr_dmy01]], true, 0)
    -- retail UpdateMixiMaxDetailInfo: the type-12 face icon when it exists (2208175668), else the chara icon
    -- (552280324, the icon the bank / dock lists draw), both on _icon_chr_dmy01 under the retail band mask
    pcall(funcLuaCommand, @crc:CMND_EVT_APPEARANCE@, "skill_panel", face)   -- the partner on purpose (module appearance)
    local has = funcLuaMenuCommand(2208175668, face)
    local r
    VRFW_FaceIcon.Forget(A, 0)                     -- drawn again on every fill: the retail fill may change the mesh
    if has then
      r = funcLuaMenuCommand(346643487 --[[SwapLayerFaceIconTex]], A, 0, 478320441, 3237726902 --[[icon_chr_dmy01]],
        face, 0, 12, true, true, true, 5)
    else
      r = VRFW_FaceIcon.Face(A, 0, face, 478320441 --[[_icon_chr_dmy01]], 3237726902 --[[icon_chr_dmy01]])
    end
    r = tostring(has) .. "/" .. tostring(r)
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax portrait", "chara", tostring(f.chara), "face key", tostring(face),
      "param", string.format("%08X", f.partner or 0), tostring(r))
  else
    funcLuaMenuCommand(C.MESH_VISIBLE, A, 478320441, false, 0)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, A, 0, true)
  -- the gained move as an ATRIBUTOS row + its TENSIÓN, the type line "Miximax"
  local L = PL.L_HIPER
  for _, m in ipairs(PL.HIPER_HIDE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, 0)
  end
  for _, p in ipairs(PL.HIPER_HIDE_POS) do
    funcLuaMenuCommand(2158717427, L, p, false, 0)
  end
  for _, x in ipairs(PL.HIPER_HIDE_TEXT) do
    funcLuaMenuCommand(2735666188, L, x, false, 0)
  end
  funcLuaMenuCommand(1233047821, L, 0, 2223127589, false)
  funcLuaMenuCommand(2158717427, L, 2313134961 --[[_pos_area01]], f.best == true, 0)
  funcLuaMenuCommand(C.TEXT, L, 1899787537 --[[_text_area01]], f.best and "Best Match" or "", 0)
  funcLuaMenuCommand(2735666188, L, 1899787537, f.best == true, 0)
  PL.MoveRow(L, f.move, team_info, 0, false, f.phdl)   -- the partner owns the move: coloured, not greyed
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax move row", string.format("%08X", EVT_U32(f.move or 0)),
    "owner", tostring(f.phdl), "shown", tostring(funcLuaMenuCommand(@crc:CMND_IS_LAYER_VISIBLE@, PL.L_HROW, 0)))
  funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_HROW, 1, false)
  -- owner 2026-10-19: the miximax tab shows the miximax only (no attached keshin / totem header under it)
  PL.mx_aura = nil
  funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_AURA2, 0, false)
  pcall(PL.MxApplyView)                          -- the miximax view (PL.mx_view = "mx")
  -- (in game: a small red blob under the name) the power cube and the tag pills of both layers, off once more
  for _, m in ipairs({4122450641, 3516146179 --[[_area_base01]]}) do
    funcLuaMenuCommand(C.MESH_VISIBLE, A, m, false, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, 0)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, true)
  evt_detail_on = true
  PL.hiper_wide = true
  pcall(EVT_DetailGraphSync)
  pcall(PL.SetDetailLayout, "mx")                -- 2026-10-07: as an aura; R3 shows the attached aura instead
  return true
end

-- 2026-10-07 round 2 (Nacho): the miximax panel shows ONE view: the miximax (its banner + the gained move's row) or,
-- after R3, the aura that comes with it (its banner on the same line + that aura's own move row, PEG look as the
-- Hiper panel). R3 again goes back; a focus change starts on the miximax (PL.MxDetail).
PL.K_R3 = 3147328756                             -- CMD_FUNC6 (R3; keyboard / mouse as mapped by the game)
PL.I_R3 = 2453951505                             -- its guide glyph (retail chara_edit / datafile guides)
PL.TX_VIEW_AURA = 3799245366                     -- menu_text evt_pl_mx_view_aura «Ver aura»
PL.TX_VIEW_MX = 1316386076                       -- menu_text evt_pl_mx_view_mx «Ver Miximax»
function PL.MxApplyView()
  local f, ti, L = PL.mx_f, PL.mx_ti, PL.L_HIPER
  if f == nil then
    return
  end
  local aura = PL.mx_view == "aura" and PL.mx_aura or nil
  funcLuaMenuCommand(C.LAYER_VISIBLE, PL.MX_LAYER, 0, aura == nil)
  funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_AURA2, 0, aura ~= nil)
  local best = aura == nil and f.best == true
  funcLuaMenuCommand(2158717427, L, 2313134961 --[[_pos_area01]], best, 0)
  funcLuaMenuCommand(2735666188, L, 1899787537 --[[_text_area01]], best, 0)
  if aura == nil then
    PL.MoveRow(L, f.move, ti, 0, false, f.phdl)
  else
    local ok, move = EVT_HC.AuraMove(aura)
    PL.MoveRow(L, ok and move or 0, ti, 0, false, nil, EVT_HC.PegInfo(aura))
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_HROW, 1, false)
  for _, m in ipairs({4122450641, 3516146179 --[[_area_base01]]}) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, 0)
  end
  pcall(PL.SetDetailLayout, "mx")
end

-- the declared row actions' guide entries are added by graft skill_table_host over this (no R3 view switch)
function PL.MxGuideAdd(t, i, c, o)
end

-- R3 does nothing on this screen (owner 2026-10-19): the Hiper panel shows the half under the cursor only
function PL.MxPollR3()
end

PL.MxPrevItemInfo = UpdateEquipItemInfo
function UpdateEquipItemInfo()
  PL.MxPrevItemInfo()
  if n14 == L_BTN then
    return
  end
  local row = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
  if row ~= 0 then
    return
  end
  local okf, f = pcall(PL.MxGet)
  if okf and f ~= nil and EVT_Skill(0) == PL.MX_FUSION then
    local _, team_info = GetSoccerTeamInfo(0)
    local ok, shown = pcall(PL.MxDetail, f, team_info)
    if ok and shown then
      SetVisibleEquipInfoWindow(false)
    else
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax panel", tostring(ok), tostring(shown))
    end
  end
end

-- The retail OnOpenLayer of soccer11_05_equip_status_base waits (waitTrue) for the layer before the 3D model is set.
-- When the screen resumes after the bank the engine calls it outside any coroutine (in-game 2026-09-25: LUAERR
-- "attempt to yield from outside a coroutine", the model not set up). There it now runs in its own coroutine,
-- resumed from Step until it ends; inside a coroutine nothing changes.
PL.deferred = {}
PL.MxPrevOpenLayer2 = OnOpenLayer
function OnOpenLayer(a1, a2)
  local _, main = coroutine.running()
  if a1 == 2917320188 --[[soccer11_05_equip_status_base]] and main then
    local co = coroutine.create(function() PL.MxPrevOpenLayer2(a1, a2) end)
    local ok, err = coroutine.resume(co)
    if not ok then
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "deferred open layer error", tostring(err))
    elseif coroutine.status(co) ~= "dead" then
      PL.deferred[#PL.deferred + 1] = co
    end
    return
  end
  return PL.MxPrevOpenLayer2(a1, a2)
end
PL.MxPrevStep = Step
function Step(...)
  local r = PL.MxPrevStep ~= nil and PL.MxPrevStep(...) or nil
  if PL.hiper_wide then
    -- 2026-10-04 (in game: the grey page base _sixth_base01 showed under a mode change card): kept hidden every frame
    -- while the full-width Hiper panel shows (the retail menu shows it again on its own refreshes)
    funcLuaMenuCommand(C.MESH_VISIBLE, 2917320188 --[[soccer11_05_equip_status_base]], 2682382918 --[[_sixth_base01]],
      false, 0)
  end
  for i = #PL.deferred, 1, -1 do
    local co = PL.deferred[i]
    local ok, err = coroutine.resume(co)
    if not ok then
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "deferred open layer error", tostring(err))
    end
    if not ok or coroutine.status(co) == "dead" then
      table.remove(PL.deferred, i)
    end
  end
  return r
end

-- ===== Miximax END =====
