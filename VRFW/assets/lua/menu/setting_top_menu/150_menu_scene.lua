-- menu_scene (VR-Framework): setting_top_menu's side of a 3D field map under the main menu (docs/framework/menu-scene.md).
-- Handlers of the framework's setting_top_menu host (VRFW_Host); the run is held by scripts\menu_scene.lua.
--
-- Opened by the title for a scene (param vrfw_menu_scene_options, set by title_main's 150_menu_scene.lua): the save is
-- loaded and the screen is still black. The menu is never shown: its fade-in is skipped (OnOpenEndLayer of its
-- background) and a coroutine resumed by Step
--   1. enters the scene's field mode (CMND_VRFW_FIELD_ENTER: walker, autosaves blocked, the mode context its camera
--      drive holds),
--   2. reports «loading» (the framework arms the field state's hand-over) and reserves the map jump to the scene's entry
--      point (CMND_RESERVE_MAP_JUMP, overwrite),
--   3. closes the menu and starts the field (the Kizuna dock list's way), the reservation repeated after the start.
-- A step that fails: field mode left, the scene marked failed, the retail fade-in: Options is shown (B = the title).
-- No engine call at load time.

local MO = {
  LOG = 3661580131,          -- CMND_EVT_LOG
  STATE = 2588710643,        -- CMND_VRFW_MENU_SCENE_STATE () -> state, key, …
  SCENE = 1465766639,        -- CMND_VRFW_MENU_SCENE (key) -> table | ""
  SET = 3352504786,          -- CMND_VRFW_MENU_SCENE_SET (state, arg) -> 1 | 0, state
  PEOPLE = 496639384,        -- CMND_VRFW_MENU_SCENE_PEOPLE (key, members, uniform, avatar) -> placed, text
  AVATAR = 603653521,        -- CMND_VRFW_MENU_SCENE_AVATAR () -> chara_base, card, handle of the save's avatar
  MOTION_SET = 1229214512,   -- CMND_VRFW_CHARA_MOTION_SET (chara_base) -> motion set (c000101 …)
  FIELD_ENTER = 3839029809,  -- CMND_VRFW_FIELD_ENTER (key, walker, map) -> ok, code
  FIELD_LEAVE = 3323114127,  -- CMND_VRFW_FIELD_LEAVE ()
  MAP_JUMP = 664962748,      -- CMND_RESERVE_MAP_JUMP (map, x, y, z, rot, event, overwrite, …, force reload)
  CLOSE = 320421347,         -- CMND_CLOSE_MENU_OBJECT (menu, now)
  FIELD_START = 769636339,   -- (seconds) the field start of the Kizuna dock list
  CURSOR_RPG = 419086457,    -- CMND_START_ARRAY_CURSOR_RPG (on)
  PARAM_HAS = 2947612279, PARAM_CLEAR = 3363400568,
  OPTIONS = 1432246941,      -- param vrfw_menu_scene_options
  HUD_OFF = 3499142076,      -- param vrfw_menu_scene_hud_off: the field HUD menus hide their layers (lua/menu/<hud>/150_menu_scene.lua)
  NPCS = 1730437307,         -- param vrfw_menu_scene_npcs: the field HUD's menu runs the NPC update (rpg_info_window 151_menu_scene_npcs.lua)
  PARAM_SET = 3860611758,
  FADE = 609722083,          -- (1 to black | 0 in, seconds)
  FADE_DONE = 2259183189,
  MENU = 1936716961,         -- setting_top_menu
  BG = 1630405233,           -- option03_00_p1_bg: the retail fade-in starts when it has opened
  ID = "vr_framework.menu_scene",
}

local mo = { ours = false, co = nil, bg_ready = false, bg_idx = 0, open_end = nil, entered = false }

local function MO_Log(...)
  pcall(funcLuaCommand, MO.LOG, "menu_scene", "setting_top_menu", ...)
end

local function MO_Call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then return nil end
  return table.unpack(r, 2, r.n)
end

-- a param cleared only when it is set (the retail way)
local function MO_Clear(k)
  if MO_Call(MO.PARAM_HAS, k) == true then
    MO_Call(MO.PARAM_CLEAR, k)
  end
end

-- a framework command that may answer nothing while its scripts run on another thread: asked up to 30 frames
local function MO_Ask(cmd, ...)
  for _ = 1, 30 do
    local r = table.pack(MO_Call(cmd, ...))
    if r.n > 0 and r[1] ~= nil then
      return table.unpack(r, 1, r.n)
    end
    coroutine.yield()
  end
  return nil
end

local function MO_Fail(why)
  MO_Log("FAILED:", why, "-> Options is shown (retail)")
  if mo.entered then
    MO_Call(MO.FIELD_LEAVE)
    mo.entered = false
  end
  MO_Call(MO.SET, "failed", "setting_top_menu: " .. tostring(why))
  MO_Clear(MO.HUD_OFF)
  mo.ours = false
  if mo.open_end ~= nil then
    pcall(mo.open_end, MO.BG, mo.bg_idx)   -- the retail fade-in; the retail Step then gives the menu its input
  else
    MO_Call(MO.FADE, 0, 0.3)
  end
end

-- the active team's players and staff, captain first then by position: "role:chara_base:motion set,…", kit, log text
-- (lua/menu/_all/72_menu_scene_team.lua, shared with the title's people refresh)
local function MO_Team()
  if type(VRFW_MenuSceneTeam) ~= "function" then return "", 0, "no team reader" end
  return VRFW_MenuSceneTeam()
end

-- the map jump: to a layout point of the map (the short form: map, point, event, overwrite: the walker arrives as through
-- a door), else to the coordinates (the long form: map, x, y, z, rot, event, overwrite, …, force reload)
local function MO_Jump(sc)
  local ok, r
  if type(sc.entry_point) == "number" and sc.entry_point ~= 0 then
    ok, r = pcall(funcLuaCommand, MO.MAP_JUMP, sc.map_id, sc.entry_point, false, true)
  else
    ok, r = pcall(funcLuaCommand, MO.MAP_JUMP, sc.map_id, sc.x, sc.y, sc.z, sc.rot, false, true, false, false, false, true)
  end
  return ok and r ~= false
end

local function MO_Enter()
  local k = 0
  while not mo.bg_ready and k < 180 do
    k = k + 1
    coroutine.yield()
  end
  local state, key = MO_Ask(MO.STATE)
  if state ~= "options" and state ~= "entering" then
    MO_Fail("the scene is at " .. tostring(state) .. ", not at options")
    return
  end
  if MO_Ask(MO.SET, "entering", "setting_top_menu opened for the scene (black, never shown)") ~= 1 then
    MO_Fail("the framework refused the step entering")
    return
  end
  local sc = MO_Ask(MO.SCENE, key)
  if type(sc) ~= "table" or type(sc.map_id) ~= "number" or type(sc.field_mode) ~= "string" then
    MO_Fail("no scene data for " .. tostring(key))
    return
  end
  -- the people of the map, before it loads (the map's own NPCs are removed either way)
  local members, uniform, why = "", 0, "people none"
  if sc.people == "active_team" then
    members, uniform, why = MO_Team()
  elseif sc.people == "provided" then
    members, uniform, why = sc.provided_members or "", sc.provided_uniform or 0, "scene-provided people"
  end
  local avatar = ""
  if sc.people == "active_team" then
    local base = MO_Ask(MO.AVATAR)
    local mset = type(base) == "number" and base ~= 0 and MO_Call(MO.MOTION_SET, base) or nil
    if type(mset) == "string" then
      avatar = string.format("%.0f:%s", base % 4294967296, mset)
    end
  end
  local placed, text = MO_Ask(MO.PEOPLE, key, members, string.format("%.0f", uniform), avatar)
  MO_Log("people:", why, "avatar", avatar ~= "" and avatar or "none", "->", tostring(placed), tostring(text))
  local ok, code = MO_Call(MO.FIELD_ENTER, sc.field_mode, 0, sc.map_id)
  if ok ~= true then
    MO_Fail("field mode " .. sc.field_mode .. " not entered (code " .. tostring(code) .. ")")
    return
  end
  mo.entered = true
  MO_Log("field mode", sc.field_mode, "on; map", sc.map, string.format("0x%08X", sc.map_id), "entry",
    (type(sc.entry_point) == "number" and sc.entry_point ~= 0) and string.format("layout point 0x%08X", sc.entry_point) or
    string.format("(%s, %s, %s) rot %s", tostring(sc.x), tostring(sc.y), tostring(sc.z), tostring(sc.rot)))
  MO_Call(MO.FADE, 1, 0)                 -- already black (the title's fade): no wait
  MO_Call(MO.PARAM_SET, MO.HUD_OFF, 0, 1, 1)
  if tonumber(placed) and tonumber(placed) > 0 then
    MO_Call(MO.PARAM_SET, MO.NPCS, 0, 1, 1)
  else
    MO_Clear(MO.NPCS)
  end
  if MO_Ask(MO.SET, "loading", "map " .. tostring(sc.map) .. " jump reserved") ~= 1 then
    MO_Fail("the framework refused the step loading")
    return
  end
  local r1 = MO_Jump(sc)
  if not r1 then
    MO_Fail("the map jump to " .. tostring(sc.map) .. " was refused")
    return
  end
  mo.ours = false
  MO_Call(MO.CLOSE, MO.MENU, true)
  MO_Call(MO.FIELD_START, 0) -- the scene's load/readiness gates replace the retail field entrance transition
  MO_Call(MO.CURSOR_RPG, true)
  local r2 = MO_Jump(sc)
  MO_Log("map jump reserved (", tostring(r1), tostring(r2), "), Options closed, field started: the map", sc.map, "loads")
end

if VRFW_Host ~= nil then
  VRFW_Host.on("setting_top_menu", "OnInit", {
    id = MO.ID .. ".init",
    phase = "after",
    fn = function()
      mo.ours, mo.co, mo.bg_ready, mo.bg_idx, mo.open_end, mo.entered = false, nil, false, 0, nil, false
      local marked = MO_Call(MO.PARAM_HAS, MO.OPTIONS) == true
      local status = MO_Call(MO.STATE)
      if marked or status == "options" or status == nil then
        MO_Clear(MO.OPTIONS)
        mo.ours = true
        mo.co = coroutine.create(function()
          if not marked and status == nil then
            status = MO_Ask(MO.STATE)
            if status ~= "options" then
              mo.ours = false
              if mo.open_end ~= nil then pcall(mo.open_end, MO.BG, mo.bg_idx) end
              return
            end
          end
          MO_Enter()
        end)
        MO_Log("opened for a menu scene: kept black, the field mode and the map follow")
      end
    end,
  })
  VRFW_Host.on("setting_top_menu", "OnOpenEndLayer", {
    id = MO.ID .. ".no_fade_in",
    phase = "around",
    fn = function(nxt, a1, a2, ...)
      if mo.ours and a1 == MO.BG then
        mo.bg_ready, mo.bg_idx, mo.open_end = true, a2 or 0, nxt
        return
      end
      return nxt(a1, a2, ...)
    end,
  })
  VRFW_Host.on("setting_top_menu", "Step", {
    id = MO.ID .. ".step",
    phase = "after",
    fn = function()
      if mo.co == nil then
        return
      end
      local ok, err = coroutine.resume(mo.co)
      if not ok then
        mo.co = nil
        MO_Fail("error " .. tostring(err))
      elseif coroutine.status(mo.co) == "dead" then
        mo.co = nil
      end
    end,
  })
end
