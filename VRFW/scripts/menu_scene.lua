-- Menu scenes (content\menu_scenes\*.toml, schema VRFW.menu_scene/1; docs/framework/menu-scene.md): a 3D field map kept
-- loaded under a game menu. Supported menu: title_menu_2 (the main menu). The steps run across the game's Lua
-- (lua/menu/<stem>/150_menu_scene.lua) and one detour of the field state (MenuScene.MoveMainUpdate, content\game\menu_scene.toml);
-- this script holds the declarations, the state of the run and the hand-over from the field to the title.
--
--   idle -> requested   title_menu_2 asked the title for Options (the retail way to load the save)
--        -> options     title_main pressed Options: the save loads, setting_top_menu opens on a black screen
--        -> entering    setting_top_menu: the scene's field mode is entered
--        -> loading     the map jump is reserved; the detour is armed
--        -> switching   the map is up: the field state goes to the title state (25), the map stays loaded
--        -> up          title_menu_2 opened over the map
--        -> leaving     a mode was picked: a reset straight into it, the old rpg scene (and its map) ends
--        -> idle        at the game reset
-- failed: any step that fails or takes longer than the scene's timeout. The scene is off for the rest of the session
-- (CMND_VRFW_MENU_SCENE_FOR answers ""): the retail main menu.

MenuScene = MenuScene or {}

local D = require "lib/declarations"

local function info(...) VRFW.log("menu_scene:", ...) end
local function warn(...) VRFW.warn("menu_scene:", ...) end

local SUPPORTED_MENUS = { title_menu_2 = true }
local HOOK = "MenuScene.MoveMainUpdate"
local ARMED_KEY = "vr_framework.menu_scene.armed"
local RPG_STATE_TITLE = 0x19        -- rpg state 25: TitleMenuState (state factory 0x1412800)
local MAP_JUMP_PENDING = 1          -- map jump reservation status: 0 idle, 1 pending, 3 done
-- The reservation is cleared when the jump is consumed (status 0, map 0): the field state's frames after the scene's
-- own jump are the scene's map. The field state does not run between the reservation and the load (the scene starts
-- from Options, a menu state), so its first entered frame with nothing pending is the new map. A map id still in the
-- reservation that is not the scene's = another map: wait.
local NO_PRESS_START_FIELD = "Route.RpgNoPressStart"

-- the step each reported state must follow
local PREVIOUS = { requested = "idle", options = "requested", entering = "options", loading = "entering", up = "switching", leaving = "up" }

-- People (scene key `people`): the map's npc_setting served from the scene's generated templates
-- (content\menu_scenes\<scene>_people.toml, research/scripts/menu_scene_people_build.py): fixed-size sentinels per spot.
local CHARA_SENTINEL, UNIFORM_SENTINEL, CLIP_SENTINEL = 0xB3E1A000, 0xB3E1B000, 0xB3E1C000
local SKELETON_PLACEHOLDER = "z0000%02d"   -- 7 characters, as a motion set name (c000101)

local scenes, by_key, by_menu = {}, {}, {}
local people_served = 0                    -- serves this session (a fresh key each time)
local redirected = {}                      -- filter -> true while the map's npc_setting is redirected
local live = false                  -- the detour is installed
local run = {
  state = "idle", key = nil, since = 0, requested = 0,
  failed = nil,                     -- why the scene failed this session (nil = not failed)
  settle = 0, last = nil, calls = 0, switches = 0,
  placed = 0,                       -- people served for this run
  covered = nil,                    -- the bright-fade object held black while the field settles
  up_at = 0,                        -- when the map was first up (ms)
}

local function now() return VRFW.now() end

local function scene() return run.key and by_key[run.key] or nil end

local function arm(on)
  pcall(VRFW.state.set, ARMED_KEY, on and 1 or 0)
end

local function set_state(s, why)
  local was, t = run.state, now()
  info(string.format("%s -> %s%s (%d ms in %s, %d ms since the request)", was, s, why and (": " .. why) or "",
    math.floor(t - run.since), was, run.requested > 0 and math.floor(t - run.requested) or 0))
  run.state, run.since = s, t
end

local cover_release_early      -- (defined with the cover)

local function fail(why)
  arm(false)
  if MenuScene.CameraStop then MenuScene.CameraStop("failed") end
  if cover_release_early then cover_release_early("failed") end
  for _, s in ipairs(scenes) do
    local f = s.map .. "_npc_setting"
    if redirected[f] then
      redirected[f] = nil
      pcall(VRFW.files.redirect, f, nil)
    end
  end
  for _, s in ipairs(scenes) do MenuScene.FilesOff(s, "failed") end
  run.failed = string.format("%s at %s", tostring(why), run.state)
  warn(string.format("FAILED at %s: %s -> the retail main menu for the rest of the session", run.state, tostring(why)))
  set_state("idle", "failed")
  run.key = nil
end

-- ---- declarations

-- the actions a hotspot may run (title_menu_2: the story submenu's entries; chronicle_map: Modo Crónica straight into the
-- Chronicle map)
local HOTSPOT_ACTIONS = { story_continue = true, story_new_game = true, story_plus = true, story_extended = true,
  chronicle_map = true }
-- the actions a tile may run ([[VRFW.MenuSceneAction]])
local TILE_ACTIONS = { continue_story = true, chronicle_map = true }

local function start()
  local schema, why = D.schema("menu_scene")
  if not schema then
    warn(why .. ": no menu scenes")
    return
  end
  local decls, skipped = D.load(schema, warn)
  for _, d in ipairs(decls) do
    local v = d.v
    if d.entry ~= "MenuScene" then
      -- spots and people templates: read below, once the scenes are known
    elseif not SUPPORTED_MENUS[v.menu] then
      warn(string.format("%s: menu = %q is not supported (title_menu_2): left out", d.where, v.menu))
    else
      local hide = {}
      for i, l in ipairs(v.hide_layers or {}) do
        local id = D.id_of(l)
        if id then hide[#hide + 1] = id else warn(string.format("%s: hide_layers item %d: not a name or an id", d.where, i)) end
      end
      local tags_on, tags_off = {}, {}
      for _, pair in ipairs({ { v.map_tags_on, tags_on, "map_tags_on" }, { v.map_tags_off, tags_off, "map_tags_off" } }) do
        for i, t in ipairs(pair[1] or {}) do
          local id = D.id_of(t)
          if id then pair[2][#pair[2] + 1] = id else warn(string.format("%s: %s item %d: not a tag or an id", d.where, pair[3], i)) end
        end
      end
      local close = {}
      for i, l in ipairs(v.close_menus or {}) do
        local id = D.id_of(l)
        if id then close[#close + 1] = id else warn(string.format("%s: close_menus item %d: not a name or an id", d.where, i)) end
      end
      local s = {
        key = d.key, mod = d.mod, menu = v.menu, map = v.map, map_id = D.id_of(v.map),
        field_mode = d.mod .. "." .. v.field_mode,
        x = v.entry_x, y = v.entry_y, z = v.entry_z, rot = v.entry_rot,
        entry_point = (v.entry_point ~= "" and D.id_of(v.entry_point)) or 0,
        hide_layers = hide, close_menus = close, map_tags_on = tags_on, map_tags_off = tags_off, title_play_mode = v.title_play_mode,
        settle_frames = v.settle_frames, timeout_ms = math.floor(v.timeout_seconds * 1000),
        people = v.people, people_kit = v.people_kit, people_seconds = v.people_seconds, people_min_seconds = v.people_min_seconds, people_quiet_seconds = v.people_quiet_seconds, spots = {}, templates = {}, clip_sets = {}, files = {},
        camera = v.camera, camera_crc = v.camera ~= "" and D.id_of(v.camera) or 0, default_shot = v.default_shot,
        shot_seconds = v.shot_seconds, shot_ease = v.shot_ease, drift_metres = v.drift_metres, drift_seconds = v.drift_seconds,
        shots = {}, tile_shot = {}, shot_list = {}, actions = {},
        shots_select_modes = v.shots_select_modes, mode_label = v.mode_label ~= false, mode_label_x = v.mode_label_x, mode_label_y = v.mode_label_y,
        mode_label_scale = v.mode_label_scale,
        home_shot = v.home_shot or "",  -- with shots_select_modes: the shot of the home entry (no tile; the menu opens on it)
        hotspots = {},                  -- shot name -> its hotspots, by order
        screens = {},                   -- [[VRFW.MenuSceneScreen]], in declaration order
      }
      if by_menu[v.menu] then
        info(string.format("%s replaces %s on %s (later mod wins)", s.key, by_menu[v.menu], v.menu))
      end
      scenes[#scenes + 1] = s
      by_key[s.key], by_menu[v.menu] = s, s.key
      info(string.format("scene %s (%s): menu %s, map %s (0x%08X), field mode %s, entry (%.2f, %.2f, %.2f) rot %.1f, %d layer(s) hidden, %d menu(s) closed, title play mode %d, settle %d frames, timeout %d ms",
        s.key, d.file, s.menu, s.map, s.map_id, s.field_mode, s.x, s.y, s.z, s.rot, #hide, #close, s.title_play_mode, s.settle_frames, s.timeout_ms))
    end
  end
  -- spots and people templates of the declared scenes
  for _, d in ipairs(decls) do
    local s = by_key[d.mod .. "." .. tostring(d.v.scene)]
    if d.entry == "MenuSceneSpot" and s then
      local hashes = {}
      for _, c in ipairs(d.v.clips) do hashes[#hashes + 1] = D.id_of(c) end
      s.spots[d.v.slot] = { slot = d.v.slot, pose = d.v.pose, who = d.v.who, clips = hashes, names = d.v.clips,
        position = { d.v.x, d.v.y or 0, d.v.z } }
    elseif d.entry == "MenuSceneAction" and s then
      local id = D.id_of(d.v.tile)
      if not TILE_ACTIONS[d.v.action] then
        warn(string.format("%s: action %q is not known (continue_story, chronicle_map): left out", d.where, d.v.action))
      elseif id then
        s.actions[#s.actions + 1] = { tile = id, action = d.v.action, shot = d.v.shot, seconds = d.v.seconds,
          leave_white = d.v.leave_fade == "white" }
      end
    elseif d.entry == "MenuSceneShot" and s then
      local sh = { name = d.v.name, eye = { d.v.eye_x, d.v.eye_y, d.v.eye_z }, target = { d.v.target_x, d.v.target_y, d.v.target_z }, fov = d.v.fov,
        move_seconds = d.v.move_seconds, ease = d.v.ease, then_shot = d.v.then_shot or "",
        then_after_seconds = d.v.then_after_seconds or 0 }
      sh.order, sh.decl = d.v.order, #s.shot_list + 1
      s.shots[d.v.name] = sh
      s.shot_list[#s.shot_list + 1] = sh
      for _, t in ipairs(d.v.tiles or {}) do s.tile_shot[t] = d.v.name end
    elseif d.entry == "MenuSceneHotspot" and s then
      local v = d.v
      local known = true
      for _, a in ipairs(v.actions) do
        if not HOTSPOT_ACTIONS[a] then known = false end
      end
      if not known or #v.actions == 0 then
        warn(string.format("%s: hotspot %s: actions must be some of story_continue, story_new_game, story_plus, story_extended, chronicle_map: left out", d.where, v.name))
      elseif v.surface ~= "wall" and v.surface ~= "floor" then
        warn(string.format("%s: hotspot %s: surface %q is not wall or floor: left out", d.where, v.name, v.surface))
      else
        local list = s.hotspots[v.shot] or {}
        s.hotspots[v.shot] = list
        list[#list + 1] = { name = v.name, order = v.order, decl = #list + 1, centre = { v.x, v.y, v.z },
          width = v.width, height = v.height, surface = v.surface, rot = v.rot, actions = v.actions, text = v.text,
          push_shot = v.push_shot, seconds = v.seconds, start = v.start, light_flood_seconds = v.light_flood_seconds,
          open_door = v.open_door, open_door_id = v.open_door ~= "" and D.id_of(v.open_door) or 0,
          open_door_after_seconds = v.open_door_after_seconds, open_door_reverse = v.open_door_reverse,
          leave_white = v.leave_fade == "white" }
      end
    elseif d.entry == "MenuSceneScreen" and s then
      local v = d.v
      local ids = {}
      for i, l in ipairs(v.layers) do
        local id = D.id_of(l)
        if id then ids[#ids + 1] = id else warn(string.format("%s: screen %s: layers item %d: not a name or an id", d.where, v.name, i)) end
      end
      if #ids == 0 then
        warn(string.format("%s: screen %s: no layers: left out", d.where, v.name))
      else
        s.screens[#s.screens + 1] = { name = v.name, shot = v.shot, centre = { v.x, v.y, v.z }, width = v.width,
          height = v.height, surface = "wall", rot = v.rot, layers = ids, keep = {},
          design = { v.design_x, v.design_y, v.design_width, v.design_height }, fade_ms = math.floor(v.fade_seconds * 1000) }
        for _, k in ipairs(v.keep_shots or {}) do s.screens[#s.screens].keep[k] = true end
      end
    elseif d.entry == "MenuSceneFile" and s then
      if d.v.filter == "" or d.v.key == "" or string.find(string.lower(d.v.key), string.lower(d.v.filter), 1, true) then
        warn(string.format("%s: file %q -> %q: empty, or the key contains the filter (it would redirect itself): left out", d.where, d.v.filter, d.v.key))
      else
        s.files[#s.files + 1] = { filter = d.v.filter, key = d.v.key }
      end
    elseif d.entry == "MenuScenePeople" and s then
      s.templates[d.v.count] = d.v.template
      for _, line in ipairs(d.v.clip_sets or {}) do
        local set, list = line:match("^(%w+):(.*)$")
        if set then
          local have = {}
          for h in list:gmatch("[^,]+") do have[D.id_of(h)] = true end
          s.clip_sets[set] = have
        end
      end
    end                          -- (a spot / template of a scene left out by its `when`: unused)
  end
  for _, s in ipairs(scenes) do
    local n = 0
    for _ in pairs(s.templates) do n = n + 1 end
    local nshots, ntiles = 0, 0
    for _ in pairs(s.shots) do nshots = nshots + 1 end
    table.sort(s.shot_list, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.decl < b.decl end)
    for _ in pairs(s.tile_shot) do ntiles = ntiles + 1 end
    for name, sh in pairs(s.shots) do
      if sh.then_shot ~= "" and not s.shots[sh.then_shot] then
        warn(string.format("scene %s: shot %s: then_shot %q is not declared: it stays", s.key, name, sh.then_shot))
        sh.then_shot = ""
      end
    end
    for shot, list in pairs(s.hotspots) do
      table.sort(list, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.decl < b.decl end)
      if not s.shots[shot] then warn(string.format("scene %s: hotspots on shot %q, which is not declared", s.key, shot)) end
      info(string.format("scene %s: %d hotspot(s) on shot %s", s.key, #list, shot))
    end
    for _, sc in ipairs(s.screens) do
      if not s.shots[sc.shot] then warn(string.format("scene %s: screen %s on shot %q, which is not declared", s.key, sc.name, sc.shot)) end
      info(string.format("scene %s: screen %s on shot %s, %d layer(s)", s.key, sc.name, sc.shot, #sc.layers))
    end
    if s.home_shot ~= "" and (not s.shots_select_modes or not s.shots[s.home_shot]) then
      warn(string.format("scene %s: home_shot %q left out (%s)", s.key, s.home_shot,
        s.shots_select_modes and "not a declared shot" or "needs shots_select_modes"))
      s.home_shot = ""
    end
    if s.home_shot ~= "" then info(string.format("scene %s: home entry on shot %s (the menu opens on it)", s.key, s.home_shot)) end
    if s.camera_crc ~= 0 and not s.shots[s.default_shot] then
      warn(string.format("scene %s: default_shot %q is not declared: no shots", s.key, s.default_shot))
      s.camera_crc = 0
    end
    info(string.format("scene %s: camera %s, %d shot(s) for %d tile(s), default %s, %.2f s %s, drift %.2f m / %.0f s", s.key,
      s.camera_crc ~= 0 and s.camera or "none (no shots)", nshots, ntiles, s.default_shot, s.shot_seconds, s.shot_ease,
      s.drift_metres, s.drift_seconds))
    info(string.format("scene %s: people %s (kit %s), %d spot(s), %d template(s), %d motion set(s)", s.key, s.people,
      s.people_kit, #s.spots, n, (function() local k = 0 for _ in pairs(s.clip_sets) do k = k + 1 end return k end)()))
  end
  -- a redirect left by an earlier session (redirects are kept across starts): the game's npc_setting again, for the map
  -- of every scene declaration, also one left out by its `when` this time
  local okf, files = pcall(VRFW.files.declarations, schema.folder)
  local cleared = {}
  for _, f in ipairs(okf and type(files) == "table" and files or {}) do
    local list = type(f.data) == "table" and type(f.data.VRFW) == "table" and f.data.VRFW.MenuScene or {}
    for _, e in ipairs(type(list) == "table" and list or {}) do
      local m = type(e) == "table" and e.map
      if type(m) == "string" and m ~= "" and not cleared[m] then
        cleared[m] = true
        pcall(VRFW.files.redirect, m .. "_npc_setting", nil)
      end
    end
    local served = type(f.data) == "table" and type(f.data.VRFW) == "table" and f.data.VRFW.MenuSceneFile or {}
    for _, e in ipairs(type(served) == "table" and served or {}) do
      if type(e) == "table" and type(e.filter) == "string" and e.filter ~= "" then
        pcall(VRFW.files.redirect, e.filter, nil)
      end
    end
  end
  if next(by_menu) == nil then
    info(string.format("off: no menu scene declared (%d left out by `when`): the retail menus", skipped or 0))
    return
  end
  local ok, done, e = pcall(VRFW.hook.apply, HOOK)
  live = ok and done == true
  arm(false)
  if not live then
    warn(string.format("detour %s not installed (%s): the menu scenes stay off", HOOK, tostring(ok and e or done)))
    by_menu = {}
    return
  end
  info(string.format("on: %d scene(s) (%d left out by `when`), detour %s installed", #scenes, skipped or 0, HOOK))
end

-- ---- memory

local function global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

local function struct(name, ptr)
  if type(ptr) ~= "number" or ptr < 0x10000 then return nil end
  local ok, s = pcall(VRFW.mem.struct, name, ptr)
  if ok then return s end
  return nil
end

local function field(s, f)
  if not s then return nil end
  local ok, v = pcall(function() return s[f] end)
  if ok then return v end
  return nil
end

local function write(s, f, v)
  if not s then return false end
  return (pcall(function() s[f] = v end))
end

-- the play-mode byte -> old value, written?
local function write_play_mode(v)
  local pd = struct("MenuScene.PlayData", global("menu_scene_play_data"))
  local old = field(pd, "play_mode")
  if v < 0 or old == nil then return old, false end
  return old, write(pd, "play_mode", v)
end

-- the «no press-start screen» flag of the rpg root (the next title opens the main menu straight away)
local function write_no_press_start()
  local rpg = global("menu_scene_rpg")
  local okf, off = pcall(VRFW.game.field, NO_PRESS_START_FIELD)
  if not rpg or not okf or type(off) ~= "number" or off <= 0 then return false end
  local ok, cur = pcall(VRFW.mem.read, "u8", rpg + off)
  if not ok or type(cur) ~= "number" or cur > 1 then return false end
  return (pcall(VRFW.mem.write, "u8", rpg + off, 1))
end

-- ---- the black cover while the field settles: the flow service's exit cover detour (content\game\flow.toml,
-- Flow.ExitCover on FadeLayerTo) keeps layer 1 of the bright-fade object opaque black while that object is a key of its
-- table; the field's own fade-in then stays black until the title fades in over the map

local COVER_HOOK, COVER_TABLE = "Flow.ExitCover", "VRFW.Flow.ExitCover"


local function cover_hold()
  local okg, obj = pcall(VRFW.game.flow_bright_fade)
  if not okg or type(obj) ~= "number" or obj < 0x10000 then return false, "no bright-fade object" end
  local oka, done, why = pcall(VRFW.hook.apply, COVER_HOOK)
  if not oka or done ~= true then return false, "detour " .. COVER_HOOK .. ": " .. tostring(oka and why or done) end
  pcall(VRFW.native.table_set, COVER_TABLE, obj, 1)
  run.covered = obj
  return true
end

local function cover_release(why)
  if run.covered then
    pcall(VRFW.native.table_clear, COVER_TABLE)
    run.covered = nil
    info("black cover released (" .. tostring(why) .. ")")
  end
end

-- what the last engine open of the map's npc_setting got: the served key, "game" (its own file) or "not opened"
local function npc_open(s)
  local ok, key, n = pcall(VRFW.files.opened, s.map .. "_npc_setting")
  if not ok then return "unknown" end
  if key == nil then return "not opened" end
  return string.format("%s (%s open(s))", key == "" and "game file" or key, tostring(n))
end

-- ---- the fail-safe of the loading step: the retail title (GameReset; the title rereads the save)

local function back_to_title(why)
  local nps = write_no_press_start()
  fail(why)
  info(string.format("back to the retail title: GameReset (no press-start %s)", tostring(nps)))
  local ok, err = pcall(VRFW.call, "MenuScene.GameReset")
  if not ok then warn("GameReset failed: " .. tostring(err)) end
end

-- ---- the detour: the field state's frame while the scene's map loads

local function on_field_frame(ev)
  if run.state ~= "loading" then
    arm(false)
    return nil
  end
  local s = scene()
  if not s then
    arm(false)
    return nil
  end
  run.calls = run.calls + 1
  local this, machine = ev.args[1], ev.args[2]
  local age = now() - run.since
  local mgr = struct("MenuScene.ReserveManager", global("menu_scene_reserve_manager"))
  local status, map = field(mgr, "map_jump_status"), field(mgr, "map_jump_map")
  local entered = field(struct("MenuScene.MoveMainState", this), "entered")
  local seen = string.format("map jump status %s, map 0x%08X, field entered %s", tostring(status), tonumber(map) or 0, tostring(entered))
  if seen ~= run.last then
    run.last = seen
    info(string.format("field state frame %d (%d ms after loading): %s", run.calls, math.floor(age), seen))
  end
  local other_map = type(map) == "number" and map ~= 0 and map ~= s.map_id
  if status == nil or status == MAP_JUMP_PENDING or other_map or entered ~= 1 then
    run.settle = 0
    if age > s.timeout_ms then
      back_to_title(string.format("the map %s was not up within %d ms (%s)", s.map, s.timeout_ms, seen))
    end
    return nil
  end
  run.settle = run.settle + 1
  -- the wait is timed (the field state's Update may run more than once per frame): settle_frames at 60 per second, at
  -- least people_seconds with people
  -- with people: the field's NPC update (the retail NPCUpdate, run by the field HUD's menu: lua/menu/rpg_info_window/
  -- 151_menu_scene_npcs.lua) reports «ready» (CMND_VRFW_MENU_SCENE_NPCS); then people_quiet_seconds more; at least
  -- people_min_seconds, at most people_seconds
  local t = now()
  local settle_ms = s.settle_frames * 1000 / 60
  local people = run.placed > 0 or s.people == "map"
  if run.settle == 1 then
    run.up_at = t
    -- the scene's camera from now on: what the settling field may show is the room, never the walker
    MenuScene.CameraStart(s)
    info(string.format("map %s up (frame %d, %d ms after loading): %s (%d people); npc_setting read: %s",
      s.map, run.calls, math.floor(age), people and string.format("settle %d..%d ms: until the field's NPC update is done + %d ms",
        math.floor(s.people_min_seconds * 1000), math.floor(s.people_seconds * 1000), math.floor(s.people_quiet_seconds * 1000))
        or string.format("settle %d ms", math.floor(settle_ms)), run.placed, npc_open(s)))
  end
  local up = t - run.up_at
  if not people then
    if up < settle_ms then return nil end
  else
    local min_ms = math.max(settle_ms, s.people_min_seconds * 1000)
    local ready = run.npcs_ready_at and t - run.npcs_ready_at >= s.people_quiet_seconds * 1000
    if up < s.people_seconds * 1000 and (up < min_ms or not ready) then return nil end
  end
  local m = struct("MenuScene.RpgMachine", machine)
  local before = field(m, "next_state")
  if not write(m, "next_state", RPG_STATE_TITLE) then
    back_to_title("the rpg state machine is not writable")
    return nil
  end
  local mode, wrote = write_play_mode(s.title_play_mode)
  local nps = write_no_press_start()
  arm(false)
  run.switches = run.switches + 1
  info(string.format("hand-over after %d ms and %d field update(s) with the map up: NPC update %s%s; npc_setting read: %s",
    math.floor(now() - run.up_at), run.settle,
    run.npcs_ready_at and string.format("done %d ms after the map was up (%s)", math.floor(run.npcs_ready_at - run.up_at), tostring(run.npcs_info))
      or (run.npcs_asked_at and "asked, not done" or "not asked"),
    (now() - run.up_at >= s.people_seconds * 1000 and people) and " (the people_seconds limit)" or "", npc_open(s)))
  set_state("switching", string.format("field state -> title state %d (next state was %s), map kept; play mode %s -> %s, no press-start %s [%d]",
    RPG_STATE_TITLE, tostring(before), tostring(mode), wrote and tostring(s.title_play_mode) or "kept", tostring(nps), run.switches))
  return { skip = true, ret = 1 }
end

-- ---- people: the map's npc_setting with the team

local function u32le(v)
  v = math.floor(v) % 4294967296
  return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)
end

-- every plain occurrence of `from` replaced by `to` (same length): text, count
local function replace_all(s, from, to)
  local parts, i, n = {}, 1, 0
  while true do
    local a, b = s:find(from, i, true)
    if not a then break end
    parts[#parts + 1] = s:sub(i, a - 1)
    parts[#parts + 1] = to
    i, n = b + 1, n + 1
  end
  parts[#parts + 1] = s:sub(i)
  return table.concat(parts), n
end

local function unhex(h)
  return (h:gsub("%x%x", function(x) return string.char(tonumber(x, 16)) end))
end

local function clear_redirect(s)
  local f = s.map .. "_npc_setting"
  if redirected[f] then
    redirected[f] = nil
    local ok, why = pcall(VRFW.files.redirect, f, nil)
    info(string.format("people: %s: the game's npc_setting again (%s)", s.map, tostring(ok and why == nil or why)))
  end
end

-- the scene's served map files ([[VRFW.MenuSceneFile]]): on at the request, before the map loads; off at the reset
-- that leaves the scene (and on failure; a redirect left by an earlier session is cleared at the start)
function MenuScene.FilesOn(s)
  if not s then return end
  for _, f in ipairs(s.files) do
    local ok, done, why = pcall(VRFW.files.redirect, f.filter, f.key)
    f.on = ok and done ~= false
    info(string.format("file %s -> %s (%s)", f.filter, f.key, tostring(ok and (done ~= false or why) or done)))
  end
end

function MenuScene.FilesOff(s, why)
  if not s then return end
  for _, f in ipairs(s.files) do
    if f.on then
      f.on = false
      pcall(VRFW.files.redirect, f.filter, nil)
      info(string.format("file %s: the game's again (%s)", f.filter, tostring(why)))
    end
  end
end

-- members = "chara_base:motion set,…" in spot order, uniform = the team's kit (0 = none) -> placed, text
local function serve_people(s, members, uniform, avatar)
  local placed, notes = {}, {}
  local team = {}
  for item in tostring(members or ""):gmatch("[^,]+") do team[#team + 1] = item end
  local avatar_item = tostring(avatar or "")
  local nextTeam = 1
  while true do
    local spot = s.spots[#placed + 1]
    if not spot then break end
    -- an avatar spot takes the avatar; without one, or a team spot, the next starter
    local item
    if spot.who == "avatar" and avatar_item ~= "" then
      item, avatar_item = avatar_item, ""
    else
      item = team[nextTeam]
      nextTeam = nextTeam + 1
      if spot.who == "avatar" and item then notes[#notes + 1] = string.format("slot %d: no avatar, a starter instead", spot.slot) end
    end
    if not item then break end
    local base, set = item:match("^(%d+):(%w+)$")
    base = tonumber(base)
    local have = set and s.clip_sets[set]
    local clip
    for _, c in ipairs(spot.clips) do
      if have and have[c] then clip = c break end
    end
    if not base or base == 0 or not have or not clip then
      notes[#notes + 1] = string.format("%s skipped (%s)", item, not have and ("motion set " .. tostring(set) .. " has no NPC pack") or "no clip of the spot")
    else
      placed[#placed + 1] = { base = base, set = set, clip = clip, spot = spot, kit = spot.who ~= "avatar" }
    end
  end
  local tpl = s.templates[#placed]
  if not tpl then
    return 0, string.format("no template for %d people (rebuild %s_people.toml)", #placed, s.key)
  end
  local bytes = unhex(tpl)
  local kit = s.people_kit == "team" and (tonumber(uniform) or 0) or 0
  for i, p in ipairs(placed) do
    local k = i - 1
    local n1, n2, n3, n4
    bytes, n1 = replace_all(bytes, u32le(CHARA_SENTINEL + k), u32le(p.base))
    bytes, n2 = replace_all(bytes, u32le(UNIFORM_SENTINEL + k), u32le(p.kit and kit or 0))
    bytes, n3 = replace_all(bytes, u32le(CLIP_SENTINEL + k), u32le(p.clip))
    bytes, n4 = replace_all(bytes, string.format(SKELETON_PLACEHOLDER, k), p.set)
    if n1 ~= 1 or n2 ~= 1 or n3 < 1 or n4 ~= 2 then
      return 0, string.format("template of %d people: spot %d sentinels %d/%d/%d/%d (rebuild it)", #placed, i, n1, n2, n3, n4)
    end
    notes[#notes + 1] = string.format("slot %d %s %s: 0x%08X set %s clip 0x%08X", p.spot.slot, p.spot.who, p.spot.pose, p.base, p.set, p.clip)
  end
  people_served = people_served + 1
  local key = string.format("data/common/gamedata/map/%s/vrfw_menu_scene_people_%d.cfg.bin", s.map, people_served)
  local ok, why = VRFW.files.serve(key, bytes)
  if not ok then return 0, "serve refused: " .. tostring(why) end
  local f = s.map .. "_npc_setting"
  local okr, whyr = VRFW.files.redirect(f, key)
  if not okr then return 0, "redirect refused: " .. tostring(whyr) end
  redirected[f] = true
  info(string.format("people: %s: %d placed (kit 0x%08X), %d bytes served as %s; %s", s.key, #placed, kit, #bytes, key,
    table.concat(notes, "; ")))
  run.placed = #placed
  return #placed, string.format("%d placed", #placed)
end

-- CMND_VRFW_MENU_SCENE_PEOPLE(key, members, uniform) -> placed, text. members = "chara_base:motion set,…" (team order);
-- "" = nobody (the map's own NPCs are removed either way).
function MenuScene.People(key, members, uniform, avatar)
  local s = by_key[tostring(key or "")]
  if not s then return 0, "unknown scene" end
  if s.people == "map" then
    run.placed = 0
    info(string.format("people: %s: the map's own npc_setting (people = \"map\", a control test): nothing served", s.key))
    return 0, "the map's own NPCs"
  end
  if s.people ~= "active_team" then members = "" end
  if s.people ~= "active_team" then avatar = "" end
  local ok, n, why = pcall(serve_people, s, members, uniform, avatar)
  if not ok then
    warn("people: " .. tostring(n))
    return 0, tostring(n)
  end
  if n == 0 and why ~= "0 placed" then warn("people: " .. tostring(why)) end
  return n, why
end

-- a title return: the old rpg scene (and any map under the menu) has ended
VRFW.on("game_reset", function(ev)
  MenuScene.CameraStop("game reset")
  for _, s in ipairs(scenes) do clear_redirect(s) MenuScene.FilesOff(s, "game reset") end
  cover_release("game reset")
  run.placed = 0
  arm(false)
  if run.state ~= "idle" then
    set_state("idle", "game reset")
  end
  run.key, run.settle, run.last, run.calls = nil, 0, nil, 0
end)

-- ---- shots: the scene's camera, moved by the menu's focus

local CAMERA_KEY, CAMERA_TABLE = "vr_framework.menu_scene.camera", "VRFW.MenuScene.Cameras"
local CAMERA_NAME_AT = 0x70         -- a camera object's name crc
local following = {}                -- name crc -> name: other cameras that take the shots' pose (FollowCamera)
local CAM_HOOK = "MenuScene.CameraView"
local cam = { on = false, scene = nil, from = nil, to = nil, at = 0, name = nil, writes = 0, hook = false, seconds = 0, ease = "smooth",
  home = false }                    -- on the scene's home entry (home_shot): a tile's focus report keeps the home shot

local function pose_of(sh)
  return { eye = { sh.eye[1], sh.eye[2], sh.eye[3] }, target = { sh.target[1], sh.target[2], sh.target[3] }, fov = sh.fov }
end

local function mix(a, b, t)
  return a + (b - a) * t
end

-- 0..1 of a move -> 0..1 eased: smooth (ease in and out), smoother (softer start and stop), linear
local function eased(k, ease)
  if ease == "linear" then return k end
  if ease == "smoother" then return k * k * k * (k * (k * 6 - 15) + 10) end
  return k * k * (3 - 2 * k)
end

-- a shot with then_shot: once its move is done and its hold (then_after_seconds) is over, the camera moves on to that
-- shot by itself (one step per call; the drift goes on over it)
local function follow_on(s, t)
  local sh = cam.name and s.shots[cam.name]
  if not sh or not cam.to or (sh.then_shot or "") == "" then return end
  local nxt = s.shots[sh.then_shot]
  if not nxt or nxt.name == sh.name then return end
  if t - cam.at < (cam.seconds + (sh.then_after_seconds or 0)) * 1000 then return end
  cam.from, cam.to, cam.at, cam.name = cam.to, pose_of(nxt), t, nxt.name
  cam.seconds = (nxt.move_seconds and nxt.move_seconds >= 0) and nxt.move_seconds or s.shot_seconds
  cam.ease = (nxt.ease and nxt.ease ~= "") and nxt.ease or s.shot_ease
  info(string.format("shot %s (then_shot of %s): eye (%.2f, %.2f, %.2f) -> target (%.2f, %.2f, %.2f), fov %.0f, move %.2f s %s",
    nxt.name, sh.name, nxt.eye[1], nxt.eye[2], nxt.eye[3], nxt.target[1], nxt.target[2], nxt.target[3], nxt.fov,
    cam.seconds, cam.ease))
end

-- the pose now: the move from `from` to `to` (eased), plus the idle drift of the eye
local function pose_now(s, t)
  follow_on(s, t)
  local p = cam.to
  local d = cam.seconds * 1000
  if cam.from and d > 0 and t - cam.at < d then
    local k = eased((t - cam.at) / d, cam.ease)
    p = {
      eye = { mix(cam.from.eye[1], cam.to.eye[1], k), mix(cam.from.eye[2], cam.to.eye[2], k), mix(cam.from.eye[3], cam.to.eye[3], k) },
      target = { mix(cam.from.target[1], cam.to.target[1], k), mix(cam.from.target[2], cam.to.target[2], k), mix(cam.from.target[3], cam.to.target[3], k) },
      fov = mix(cam.from.fov, cam.to.fov, k),
    }
  end
  if s.drift_metres > 0 then
    local w = 2 * math.pi * t / (s.drift_seconds * 1000)
    local m = s.drift_metres
    return { eye = { p.eye[1] + m * math.sin(w), p.eye[2] + m * 0.5 * math.sin(2 * w), p.eye[3] + m * 0.5 * math.cos(w) },
      target = p.target, fov = p.fov }
  end
  return p
end

local function set_shot(s, name, why)
  local sh = s.shots[name] or s.shots[s.default_shot]
  if not sh then return nil end
  if cam.name == sh.name then return sh.name end
  local t = now()
  cam.from = cam.to and pose_now(s, t) or nil
  cam.to, cam.at, cam.name = pose_of(sh), t, sh.name
  -- the move into a shot: its own time and ease, else the scene's
  cam.seconds = (sh.move_seconds and sh.move_seconds >= 0) and sh.move_seconds or s.shot_seconds
  cam.ease = (sh.ease and sh.ease ~= "") and sh.ease or s.shot_ease
  info(string.format("shot %s (%s): eye (%.2f, %.2f, %.2f) -> target (%.2f, %.2f, %.2f), fov %.0f, move %.2f s %s", sh.name, why,
    sh.eye[1], sh.eye[2], sh.eye[3], sh.target[1], sh.target[2], sh.target[3], sh.fov, cam.seconds, cam.ease))
  return sh.name
end

function MenuScene.CameraStart(s)
  if s.camera_crc == 0 or not cam.hook then return end
  cam.on, cam.scene, cam.name, cam.to, cam.from, cam.writes, cam.object, cam.view_logged = true, s, nil, nil, nil, 0, nil, {}
  cam.home = s.home_shot ~= ""
  set_shot(s, cam.home and s.home_shot or s.default_shot, cam.home and "the scene's home entry" or "the scene's default")
  pcall(VRFW.native.table_set, CAMERA_TABLE, s.camera_crc, 1)
  pcall(VRFW.state.set, CAMERA_KEY, 1)
  info(string.format("shots on: camera %s (0x%08X)", s.camera, s.camera_crc))
end

function MenuScene.CameraStop(why)
  if not cam.on then return end
  cam.on, cam.object, cam.home = false, nil, false
  pcall(VRFW.state.set, CAMERA_KEY, 0)
  pcall(VRFW.native.table_clear, CAMERA_TABLE)
  following = {}
  info(string.format("shots off (%s) after %d camera write(s)", tostring(why), cam.writes))
end

-- the camera's view, before the engine takes it: this frame's pose
local function on_camera_view(ev)
  if not cam.on or not cam.to then return nil end
  local s = cam.scene
  local c = struct("MenuScene.Camera", ev.args[1])
  if not c then return nil end
  -- the scene's own camera is the one the hotspots are projected with; a following camera only takes the pose
  local okn, name = pcall(VRFW.mem.read, "u32", ev.args[1] + CAMERA_NAME_AT)
  if not okn or name == s.camera_crc then cam.object = c end
  local p = pose_now(s, now())
  local ok = write(c, "pos_x", p.eye[1]) and write(c, "pos_y", p.eye[2]) and write(c, "pos_z", p.eye[3])
    and write(c, "target_x", p.target[1]) and write(c, "target_y", p.target[2]) and write(c, "target_z", p.target[3])
  local fov = p.fov * math.pi / 180
  local cur = field(c, "fov")
  if type(cur) == "number" and math.abs(cur - fov) > 1e-5 then
    ok = write(c, "fov", fov) and write(c, "proj_dirty", 1) and ok
  end
  -- world and view versions made stale: the engine rebuilds the matrices from position + look-at
  local pv = field(c, "parent_ver")
  local okp, parent = false, 0
  if type(pv) == "number" and pv >= 0x10000 then okp, parent = pcall(VRFW.mem.read, "u32", pv) end
  parent = (okp and type(parent) == "number") and parent or 0
  for _, f in ipairs({ "world_ver", "view_ver" }) do
    local v = field(c, f)
    if type(v) == "number" then
      local mine = v - bit32.band(v, 0x10000)
      ok = write(c, f, mine + bit32.band(bit32.bnot(parent), 0x10000)) and ok
    end
  end
  cam.writes = cam.writes + 1
  if cam.writes == 1 then info(string.format("first camera write (%s)", tostring(ok))) end
  return nil
end

-- ---- hotspots: 3D rectangles of a shot drawn as menu buttons where the camera sees them

local function sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
local function cross(a, b) return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] } end
local function unit(a)
  local l = math.sqrt(dot(a, a))
  if l < 1e-9 then return { 0, 0, 1 } end
  return { a[1] / l, a[2] / l, a[3] / l }
end

-- the hotspot's four corners (metres): a wall rectangle stands up, facing `rot` (0 = +z); a floor one lies flat, its
-- width across `rot`
local function corners(h)
  local a = math.rad(h.rot)
  local across = { math.cos(a), 0, -math.sin(a) }
  local second = h.surface == "floor" and { math.sin(a), 0, math.cos(a) } or { 0, 1, 0 }
  local c, hw, hh = h.centre, h.width / 2, h.height / 2
  local out = {}
  for _, k in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
    out[#out + 1] = { c[1] + across[1] * hw * k[1] + second[1] * hh * k[2], c[2] + across[2] * hw * k[1] + second[2] * hh * k[2],
      c[3] + across[3] * hw * k[1] + second[3] * hh * k[2] }
  end
  return out
end

-- the view the hotspots are projected with: eye, forward, right, up, vertical fov (degrees)
local function view_of(eye, f, up, fov)
  local r = unit(cross(f, up))
  return { eye = eye, f = f, r = r, u = cross(r, f), fov = fov }
end

-- the declared pose's view (eye, target, vertical fov; the world's up)
local function pose_view(p)
  return view_of(p.eye, unit(sub(p.target, p.eye)), { 0, 1, 0 }, p.fov)
end

local function finite(v) return type(v) == "number" and v == v and v > -1e6 and v < 1e6 end

-- the engine's own view of the scene's camera, from its last view update (world eye, the world matrix's z axis and
-- up, the FOV): what the screen shows, whatever moved the camera after the shot's write (a parent node, the follow
-- camera). nil when it cannot be read or is far from the declared pose (more than 1 m or 10 degrees: not this shot)
local function engine_view(p)
  local c = cam.object
  if not c then return nil end
  local v = {}
  for _, f in ipairs({ "view_eye_x", "view_eye_y", "view_eye_z", "view_axis_x", "view_axis_y", "view_axis_z",
      "view_up_x", "view_up_y", "view_up_z", "fov" }) do
    v[f] = field(c, f)
    if not finite(v[f]) then return nil end
  end
  local eye = { v.view_eye_x, v.view_eye_y, v.view_eye_z }
  local axis = sub({ v.view_axis_x, v.view_axis_y, v.view_axis_z }, eye)
  local up = { v.view_up_x, v.view_up_y, v.view_up_z }
  if dot(axis, axis) < 1e-6 or dot(up, up) < 1e-6 or v.fov <= 0.01 or v.fov >= 3.0 then return nil end
  local declared = pose_view(p)
  local f = unit(axis)
  -- the z axis points along the view or against it, depending on the engine's convention: the one near the pose
  if dot(f, declared.f) < 0 then f = { -f[1], -f[2], -f[3] } end
  local d = sub(eye, declared.eye)
  if dot(d, d) > 1.0 or dot(f, declared.f) < math.cos(math.rad(10)) then return nil end
  return view_of(eye, f, unit(up), v.fov * 180 / math.pi)
end

-- this frame's view: the engine's when it can be read, else the declared pose's
local function view_now(s, t)
  local p = pose_now(s, t)
  return engine_view(p) or pose_view(p), p
end

-- menu px (1920 x 1080, y down) of a point seen with view `v`, nil behind the eye
local MENU_W, MENU_H = 1920, 1080
local function project(v, pt)
  local d = sub(pt, v.eye)
  local z = dot(d, v.f)
  if z < 0.05 then return nil end
  local scale = (MENU_H / 2) / math.tan(math.rad(v.fov) / 2)
  return MENU_W / 2 + scale * dot(d, v.r) / z, MENU_H / 2 - scale * dot(d, v.u) / z
end

-- a scene person's box for the outline (a standing person; a seated one is lower, the box still covers it)
local PERSON_HEIGHT, PERSON_WIDTH = 1.6, 0.5   -- metres

-- the people on the spots (the run's placed ones fill spots 1..N): { depth, x0, y0, x1, y1 } on screen for this camera
local function people_boxes(s, v)
  local out = {}
  if run.key ~= s.key or (run.placed or 0) < 1 then return out end
  local right = unit(cross(v.f, { 0, 1, 0 }))
  for i = 1, run.placed do
    local spot = s.spots[i]
    local at = spot and spot.position
    if at then
      local depth = dot(sub(at, v.eye), v.f)
      local x0, y0, x1, y1, seen = math.huge, math.huge, -math.huge, -math.huge, true
      for _, k in ipairs({ { -1, 0 }, { 1, 0 }, { -1, PERSON_HEIGHT }, { 1, PERSON_HEIGHT } }) do
        local x, y = project(v, { at[1] + right[1] * PERSON_WIDTH / 2 * k[1], at[2] + k[2], at[3] + right[3] * PERSON_WIDTH / 2 * k[1] })
        if not x then seen = false break end
        x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
      end
      if seen then out[#out + 1] = { depth, x0, y0, x1, y1 } end
    end
  end
  return out
end

-- CMND_VRFW_MENU_SCENE_HOTSPOTS(key[, shot]) -> "" (no hotspots on the shot now running, or on `shot`) or { shot, settled (1 = the camera
-- has arrived), n, [i] = { name, actions = { … }, text, push_shot, ms, flood_ms, door (a node name, "" = none), door_id,
-- door_ms, door_reverse (0 / 1), leave_white (0 / 1), start (0 / 1), x, y (centre), w, h (the
-- rectangle's box on screen, menu px), seen (0 / 1: all corners in front of the eye), outline = { x1, y1, … x4, y4 }
-- (the four corners on screen, in order around the rectangle), hidden = { x0, y0, x1, y1, … } (the screen boxes of
-- the scene's people nearer to the camera than the hotspot's centre: the outline is not drawn over them) } }, for this
-- frame's camera
function MenuScene.Hotspots(key, of_shot)
  local s = by_key[tostring(key or "")]
  if not s or not cam.on or cam.scene ~= s or not cam.name then return "" end
  local shot = (type(of_shot) == "string" and of_shot ~= "") and of_shot or cam.name
  local list = s.hotspots[shot]
  if not list or #list == 0 then return "" end
  local t = now()
  local v, p = view_now(s, t)
  local out = { shot = shot, settled = (t - cam.at >= cam.seconds * 1000) and 1 or 0, n = #list }
  local people = people_boxes(s, v)
  for i, h in ipairs(list) do
    local hidden = {}
    local depth = dot(sub(h.centre, v.eye), v.f)
    for _, b in ipairs(people) do
      if b[1] < depth then
        for k = 2, 5 do hidden[#hidden + 1] = b[k] end
      end
    end
    local x0, y0, x1, y1, seen = math.huge, math.huge, -math.huge, -math.huge, 1
    local outline = {}
    for _, c in ipairs(corners(h)) do
      local x, y = project(v, c)
      if not x then
        seen = 0
      else
        x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
        outline[#outline + 1] = x
        outline[#outline + 1] = y
      end
    end
    local actions = {}
    for k, a in ipairs(h.actions) do actions[k] = a end
    out[i] = { name = h.name, actions = actions, text = h.text, push_shot = h.push_shot, ms = math.floor(h.seconds * 1000),
      flood_ms = math.floor((h.light_flood_seconds or 0) * 1000),
      door = h.open_door or "", door_id = h.open_door_id or 0, door_ms = math.floor((h.open_door_after_seconds or 0) * 1000),
      door_reverse = h.open_door_reverse and 1 or 0, leave_white = h.leave_white and 1 or 0,
      start = h.start and 1 or 0, seen = seen,
      x = seen == 1 and (x0 + x1) / 2 or 0, y = seen == 1 and (y0 + y1) / 2 or 0,
      w = seen == 1 and x1 - x0 or 0, h = seen == 1 and y1 - y0 or 0,
      outline = seen == 1 and outline or {}, hidden = hidden }
  end
  if out.settled == 1 and cam.view_logged and not cam.view_logged[shot] then
    cam.view_logged[shot] = true
    local first = out[1]
    info(string.format("hotspots of %s: view eye (%.2f, %.2f, %.2f) forward (%.3f, %.3f, %.3f) fov %.1f (%s; declared eye "
      .. "(%.2f, %.2f, %.2f) -> (%.2f, %.2f, %.2f) fov %.1f); %s at x %.0f .. %.0f, y %.0f .. %.0f", shot, v.eye[1], v.eye[2],
      v.eye[3], v.f[1], v.f[2], v.f[3], v.fov, engine_view(p) and "the engine's" or "the declared pose", p.eye[1], p.eye[2],
      p.eye[3], p.target[1], p.target[2], p.target[3], p.fov, first.name, first.x - first.w / 2, first.x + first.w / 2,
      first.y - first.h / 2, first.y + first.h / 2))
  end
  return out
end

-- CMND_VRFW_MENU_SCENE_SCREENS(key) -> "" (no screens, or the shots are off) or { n, [i] = { name, on (1 = its shot
-- is the one running and the camera has arrived, or one of its keep_shots is running), fade_ms, seen (0 / 1), x0, y0, x1, y1 (the rectangle's box on screen
-- with this frame's camera, menu px, y down), layers = { ids }, design = { x, y, w, h } } } for every screen of the
-- scene: a screen whose shot just left still has its box, so its layers can fade out where they were
function MenuScene.Screens(key)
  local s = by_key[tostring(key or "")]
  if not s or not cam.on or cam.scene ~= s or not cam.name or #s.screens == 0 then return "" end
  local t = now()
  local v = view_now(s, t)
  local settled = t - cam.at >= cam.seconds * 1000
  local out = { n = #s.screens }
  for i, sc in ipairs(s.screens) do
    local x0, y0, x1, y1, seen = math.huge, math.huge, -math.huge, -math.huge, 1
    for _, c in ipairs(corners(sc)) do
      local x, y = project(v, c)
      if not x then
        seen = 0
      else
        x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
      end
    end
    local layers = {}
    for k, id in ipairs(sc.layers) do layers[k] = id end
    local on = (settled and cam.name == sc.shot) or sc.keep[cam.name] == true
    out[i] = { name = sc.name, on = on and 1 or 0, fade_ms = sc.fade_ms, seen = seen,
      x0 = seen == 1 and x0 or 0, y0 = seen == 1 and y0 or 0, x1 = seen == 1 and x1 or 0, y1 = seen == 1 and y1 or 0,
      layers = layers, design = { sc.design[1], sc.design[2], sc.design[3], sc.design[4] } }
  end
  return out
end

-- ---- commands

-- CMND_VRFW_MENU_SCENE_SHOT(key, tile) -> the shot now running
function MenuScene.Shot(key, tile)
  local s = by_key[tostring(key or "")]
  local id = D.id_of(tile) or 0
  if not s or not cam.on or cam.scene ~= s then
    info(string.format("focus report: tile 0x%08X of %s ignored (shots %s)", id, tostring(key), cam.on and "on another scene" or "off"))
    return ""
  end
  -- a shot named directly (a tile action's push-in) wins over a tile id
  if type(tile) == "string" and s.shots[tile] then
    local direct = set_shot(s, tile, "asked by name") or ""
    info(string.format("shot asked by name: %s", direct))
    return direct
  end
  if cam.home and s.home_shot ~= "" then
    local home = set_shot(s, s.home_shot, "home entry") or ""
    info(string.format("focus report: tile 0x%08X while on the home entry -> shot %s", id, home))
    return home
  end
  local name = s.tile_shot[id]
  local now_name = set_shot(s, name or s.default_shot, name and string.format("tile 0x%08X", id) or string.format("tile 0x%08X: no shot of its own", id)) or ""
  info(string.format("focus report: tile 0x%08X -> shot %s", id, now_name))
  return now_name
end

-- CMND_VRFW_MENU_SCENE_HOME(key[, on]) -> 1 on the home entry, 0 off it (or no home entry): on = 1 moves the camera to
-- the scene's home_shot and keeps it there for tile focus reports, on = 0 leaves it (the menu then reports its tile);
-- without `on` only the answer
function MenuScene.Home(key, on)
  local s = by_key[tostring(key or "")]
  if not s or s.home_shot == "" or not cam.on or cam.scene ~= s then return 0 end
  if on ~= nil then
    local want = on == true or on == 1
    if want ~= cam.home then
      cam.home = want
      info(want and "home entry: on" or "home entry: off (a mode is shown)")
    end
    if want then set_shot(s, s.home_shot, "home entry") end
  end
  return cam.home and 1 or 0
end

-- CMND_VRFW_MENU_SCENE_SHOT_STEP(key, step) -> the shot now running: the previous (-1) / next (+1) shot of the scene's
-- list (order, then declaration), cycling
function MenuScene.ShotStep(key, step)
  local s = by_key[tostring(key or "")]
  if not s or not cam.on or cam.scene ~= s or #s.shot_list == 0 then return "" end
  local i = 0
  for k, sh in ipairs(s.shot_list) do
    if sh.name == cam.name then i = k end
  end
  local n = #s.shot_list
  local d = (tonumber(step) or 1) < 0 and -1 or 1
  local j = ((i - 1 + d) % n) + 1
  return set_shot(s, s.shot_list[j].name, d < 0 and "previous shot key" or "next shot key") or ""
end

-- CMND_VRFW_MENU_SCENE_NPCS(step, info) -> 1: the field's NPC update of a scene's map, reported by the field HUD's
-- menu ("asked" = NPCUpdate requested, "ready" = no NPC updating and the load step done)
function MenuScene.Npcs(step, extra)
  step = tostring(step or "")
  if (run.state == "switching" or run.state == "up") and step == "ready" and run.npcs_asked_at and not run.npcs_ready_at then
    -- the hand-over did not wait for it (people_seconds): the people show when their update is done
    run.npcs_ready_at, run.npcs_info = now(), tostring(extra)
    info(string.format("NPC update done after the hand-over, at %s (%s), %d ms after it was asked, %d ms after the map was up",
      run.state, tostring(extra), math.floor(now() - run.npcs_asked_at), math.floor(now() - (run.up_at or now()))))
    return 1
  end
  if run.state ~= "loading" then return 0 end
  if step == "asked" then
    run.npcs_asked_at = now()
    info(string.format("NPC update asked by the field (%s)", tostring(extra)))
  elseif step == "ready" and (run.settle or 0) < 1 then
    info(string.format("NPC update reported ready before the map was up (%s): ignored", tostring(extra)))
  elseif step == "ready" then
    run.npcs_ready_at, run.npcs_info = now(), tostring(extra)
    info(string.format("NPC update done (%s), %d ms after it was asked", tostring(extra),
      math.floor(now() - (run.npcs_asked_at or now()))))
  end
  return 1
end

-- CMND_VRFW_MENU_SCENE_FOLLOW_CAMERA(name, on) -> 1 | 0: another engine camera (e.g. "MenuCamera", the one a menu's
-- 3D model makes the 3D view) takes the running shot's pose too while on (cleared when the shots stop)
function MenuScene.FollowCamera(name, on)
  if not cam.on then return 0 end
  local crc = D.id_of(name)
  if not crc or crc == 0 or crc == cam.scene.camera_crc then return 0 end
  local follow = on == true or on == 1
  if (following[crc] ~= nil) == follow then return 1 end
  local ok = pcall(VRFW.native.table_set, CAMERA_TABLE, crc, follow and 1 or nil)
  following[crc] = follow and tostring(name) or nil
  info(string.format("camera %s %s the shots (%s)", tostring(name), follow and "follows" or "no longer follows", tostring(ok)))
  return ok and 1 or 0
end

-- CMND_VRFW_MENU_SCENE_AVATAR() -> chara_base, card, handle of the save's avatar (0 = unknown)
function MenuScene.Avatar()
  local kz = struct("MenuScene.Kizuna", global("menu_scene_kizuna"))
  local hdl = field(kz, "avatar")
  if type(hdl) ~= "number" or hdl == 0 then return 0, 0, 0 end
  local okr, rec = pcall(VRFW.chara.record, hdl)
  local card = okr and type(rec) == "table" and tonumber(rec.param) or 0
  local okb, base = pcall(VRFW.chara.base_of, card)
  base = okb and tonumber(base) or 0
  info(string.format("avatar: handle 0x%08X, card 0x%08X, chara_base 0x%08X", hdl, card, base))
  return base, card, hdl
end

-- ---- an action that ends in a menu after the leave's reset (chronicle_map: the Chronicle top menu goes straight to the
-- map). The script outlives the game reset; the game's params are not relied on across it.

local PENDING_MS = 30000            -- a pending action older than this is dropped
local pending = nil                 -- { action, at }

-- CMND_VRFW_MENU_SCENE_PENDING(action) -> 1: the action waits for the menu it ends in ("" = none)
function MenuScene.Pending(action)
  action = tostring(action or "")
  if action == "" then
    if pending then info(string.format("pending action %s dropped", pending.action)) end
    pending = nil
    return 1
  end
  pending = { action = action, at = now() }
  info(string.format("pending action %s: for the menu after the leave", action))
  return 1
end

-- CMND_VRFW_MENU_SCENE_TAKE(action) -> 1 when that action was pending (taken: answered once), else 0
function MenuScene.Take(action)
  action = tostring(action or "")
  if not pending or pending.action ~= action then return 0 end
  local age = now() - pending.at
  pending = nil
  if age > PENDING_MS then
    info(string.format("pending action %s too old (%d ms): dropped", action, math.floor(age)))
    return 0
  end
  info(string.format("pending action %s taken after %d ms", action, math.floor(age)))
  return 1
end

-- CMND_VRFW_MENU_SCENE_FOR(menu) -> key | ""
function MenuScene.For(menu)
  if run.failed then return "" end
  return by_menu[tostring(menu or "")] or ""
end

-- CMND_VRFW_MENU_SCENE(key) -> table | ""
function MenuScene.Get(key)
  local s = by_key[tostring(key or "")]
  if not s then return "" end
  local hide, close = {}, {}
  for i, id in ipairs(s.hide_layers) do hide[i] = id end
  for i, id in ipairs(s.close_menus) do close[i] = id end
  local tags_on, tags_off = {}, {}
  for i, id in ipairs(s.map_tags_on) do tags_on[i] = id end
  for i, id in ipairs(s.map_tags_off) do tags_off[i] = id end
  return { key = s.key, map = s.map, map_id = s.map_id, field_mode = s.field_mode, x = s.x, y = s.y, z = s.z, rot = s.rot,
    entry_point = s.entry_point,
    shots_select_modes = s.shots_select_modes and 1 or 0, mode_label = s.mode_label and 1 or 0, mode_label_x = s.mode_label_x, mode_label_y = s.mode_label_y,
    mode_label_scale = s.mode_label_scale, home_shot = s.home_shot,
    hide_layers = hide, close_menus = close, map_tags_on = tags_on, map_tags_off = tags_off, timeout_ms = s.timeout_ms, people = s.people, spots = #s.spots,
    actions = (function()
      local a = {}
      for i, x in ipairs(s.actions) do
        a[i] = { tile = x.tile, action = x.action, shot = x.shot, ms = math.floor(x.seconds * 1000),
          leave_white = x.leave_white and 1 or 0 }
      end
      return a
    end)() }
end

-- CMND_VRFW_MENU_SCENE_STATE() -> state, key, ms in this state, ms since the request, failed (0 / 1)
function MenuScene.State()
  local t = now()
  -- the cover never outlives a title start that does not reach the main menu
  if run.covered and run.state == "switching" and t - run.since > 6000 then
    cover_release("the main menu did not open within 6 s of the hand-over")
  end
  return run.state, run.key or "", math.floor(t - run.since), run.requested > 0 and math.floor(t - run.requested) or 0,
    run.failed and 1 or 0, (run.state == "loading" and (run.settle or 0) >= 1) and 1 or 0
end

-- CMND_VRFW_MENU_SCENE_SET(state, arg) -> 1 | 0, state
function MenuScene.Set(s, arg)
  s = tostring(s or "")
  if s == "failed" then
    fail(arg or "reported by the game's Lua")
    return 1, run.state
  end
  if s == run.state then return 1, run.state end
  local prev = PREVIOUS[s]
  if prev == nil then
    warn(string.format("unknown step %q (arg %s): refused", s, tostring(arg)))
    return 0, run.state
  end
  if run.state ~= prev then
    warn(string.format("step %s refused: the run is at %s (expected %s)", s, run.state, prev))
    return 0, run.state
  end
  if s == "requested" then
    local key = tostring(arg or "")
    if run.failed or not by_key[key] then
      warn(string.format("request for %q refused (%s)", key, run.failed and ("failed this session: " .. run.failed) or "unknown scene"))
      return 0, run.state
    end
    run.key, run.requested, run.settle, run.last, run.calls = key, now(), 0, nil, 0
    MenuScene.FilesOn(by_key[key])
    run.npcs_asked_at, run.npcs_ready_at, run.npcs_info = nil, nil, nil
  end
  set_state(s, arg ~= nil and tostring(arg) or nil)
  if s == "up" then
    -- the room appears with the menu: the cover held through the title's start, released when title_menu_2 is open
    -- (its handler fades the screen in right after)
    cover_release("the main menu is up")
  end
  if s == "loading" then
    arm(true)
    local okc, why = cover_hold()
    info(okc and "black cover held while the field settles" or ("no black cover (" .. tostring(why) .. "): the field may show before the menu"))
  end
  return 1, run.state
end

cover_release_early = cover_release

start()

-- the field's frames are heard only while the detour is installed (a scene is declared)
if live then
  VRFW.on("hook:" .. HOOK, on_field_frame)
  -- the camera detour only when a scene declares shots
  local shots = false
  for _, s in ipairs(scenes) do
    if s.camera_crc ~= 0 then shots = true end
  end
  if shots then
    local ok, done, why = pcall(VRFW.hook.apply, CAM_HOOK)
    cam.hook = ok and done == true
    if cam.hook then
      VRFW.on("hook:" .. CAM_HOOK, on_camera_view)
    else
      warn(string.format("detour %s not installed (%s): no shots", CAM_HOOK, tostring(ok and why or done)))
    end
  end
end
