-- menu_scene (VR-Framework): a 3D field map under the main menu (docs/framework/menu-scene.md). Handlers of the framework's
-- title_menu_2 host (VRFW_Host); the scene is a mod's declaration (content\menu_scenes\, VRFW.menu_scene/1) and the run
-- is held by scripts\menu_scene.lua (CMND_VRFW_MENU_SCENE_*).
--
--   * No scene up, a scene declared for this menu and a save: once the menu is ready (its opening coroutine done, no
--     sheet or message over it) the screen goes black and the title is asked for Options (param vrfw_menu_scene_go,
--     read by title_main's 150_menu_scene.lua): the retail Options request loads the save and opens setting_top_menu,
--     which enters the scene's field mode and loads the map; the field state then hands over to the title over it.
--   * Scene up (this menu opened over the loaded map): the scene's layers stay hidden; param vrfw_menu_scene_up tells
--     title_main that picking a mode leaves through a reset that unloads the map.
--   * Any failure or timeout: the screen fades in on the retail menu; the framework answers no scene for the rest of
--     the session.
--   * A scene with shots_select_modes: the shots are the mode selection. The mode row stays the title's focus (its A
--     and X are the game's) but is not drawn (its layers are in the scene's hide_layers, the cursor is hidden on it);
--     the shot keys move its focus to the previous / next mode, up from the lower row comes back to the mode last
--     shown, a move into a hidden layer (the banners over the row) is refused, and the mode's name is drawn on the
--     layer vrfw_ms_label (the match panel's text object, added to the menu by the mod).
--   * Hotspots ([[VRFW.MenuSceneHotspot]]): once the camera has arrived on a shot with hotspots and the mode row has the
--     focus, each one's text is drawn where the camera sees its rectangle (vrfw_ms_label 1.., the selected one light
--     blue and larger); left / right move between them (the row's own move is undone), A runs the selected
--     one's first available action: story_continue / story_new_game straight into the story after its push-in
--     (title_main, params vrfw_menu_scene_story_continue / _kind), story_plus / story_extended through the story
--     submenu, which picks that entry itself (story_mode_top_menu, param vrfw_menu_scene_story_pick). A hotspot with
--     open_door opens that map door (CMND_DOOR_OPEN) open_door_after_seconds after A; light_flood_seconds lets a warm
--     light grow from the rectangle over the screen before the fade (also when the door cannot open). leave_fade =
--     "white" (a hotspot or a tile action) sets param vrfw_menu_scene_leave_white: title_main's fade when it leaves is
--     the white one (a shot that ends in a white space hands over in white, no black frame).
--   * A hotspot with outline_tag: instead of the rectangle outline, that map tag is on while the hotspot is selected
--     (the mode row has the focus, the camera has arrived, it is seen) and off otherwise (a mod's own outline model
--     of the object); the tag switch rides on the map tags below, sent when its state changes.
--   * A home entry (scene key home_shot, with shots_select_modes): a place of the mode cycle without a tile, on its own
--     shot. The menu always opens on it; the previous / next mode keys and left / right on the hidden row go from it to
--     the first / last mode and from the first / last mode back to it. While it is shown the row keeps its hidden
--     focus on a tile, but A on the row does nothing, no hotspot and no mode name is drawn, the framework keeps the
--     home shot for tile focus reports (CMND_VRFW_MENU_SCENE_HOME) and the game param vrfw_menu_scene_home is set (a
--     mod's mode header hides its mode line).
--   * chronicle_map (a tile action or a hotspot on the «Modo Crónica» tile's shot): the push-in, then the title's own
--     press; title_main ends the title after the push-in (param vrfw_menu_scene_chronicle_wait) and the Chronicle top
--     menu that opens after the leave goes straight to the map (lua/menu/chronicle_mode_top_menu/150_menu_scene.lua).
-- No engine call at load time.

local MS = {
  LOG = VRFW_Cmd.EVT_LOG,          -- CMND_EVT_LOG
  FOR = VRFW_Cmd.VRFW_MENU_SCENE_FOR,          -- CMND_VRFW_MENU_SCENE_FOR (menu) -> key | ""
  SCENE = VRFW_Cmd.VRFW_MENU_SCENE,        -- CMND_VRFW_MENU_SCENE (key) -> table | ""
  STATE = VRFW_Cmd.VRFW_MENU_SCENE_STATE,        -- CMND_VRFW_MENU_SCENE_STATE () -> state, key, ms in state, ms since the request, failed
  SET = VRFW_Cmd.VRFW_MENU_SCENE_SET,          -- CMND_VRFW_MENU_SCENE_SET (state, arg) -> 1 | 0, state
  HAS_SAVE = 8577266,        -- (1) -> a save exists (the title's own test)
  FADE = 609722083,          -- (1 to black | 0 in, seconds)
  VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE,       -- CMND_SET_LAYER_VISIBLE (layer, index, on)
  LAYER_EXISTS = VRFW_Cmd.IS_EXIST_LAYER,  -- CMND_IS_EXIST_LAYER (layer, index)
  MENU_EXISTS = VRFW_Cmd.IS_EXIST_MENU_OBJECT,  -- (menu) -> the menu object exists
  IS_MENU_OPEN = VRFW_Cmd.IS_EXIST_MENU,  -- CMND_IS_EXIST_MENU (menu) -> the menu is open
  CLOSE = VRFW_Cmd.CLOSE_MENU_OBJECT,         -- CMND_CLOSE_MENU_OBJECT (menu)
  MINIMAP = 1868910795,      -- (on) the field's minimap shown / hidden (0x6F6550CB)
  IS_MENU = VRFW_Cmd.IS_EXIST_MENU,       -- CMND_IS_EXIST_MENU (menu)
  MSG_BUSY = 898725220,      -- a message window is open
  SHEET = 3492314538,        -- title_tutorial_menu (the welcome / «Novedades de mods» sheets)
  GO = 2860602156,           -- param vrfw_menu_scene_go: title_main presses Options
  OPTIONS = 1432246941,      -- param vrfw_menu_scene_options: an opening of setting_top_menu for the scene
  HUD_OFF = 3499142076,      -- param vrfw_menu_scene_hud_off: the field HUD hidden (kept while the scene is up)
  TITLE_READY = 358816896,   -- param vrfw_menu_scene_title_ready: title_main reads requests (the menu fully open)
  CAMERA_POS = VRFW_Cmd.VRFW_FIELD_CAMERA_POS,   -- CMND_VRFW_FIELD_CAMERA_POS () -> ok, x, y, z: the field camera's anchor (the walker)
  SHOT = VRFW_Cmd.VRFW_MENU_SCENE_SHOT,         -- CMND_VRFW_MENU_SCENE_SHOT (key, tile id) -> the shot now running
  SHOT_STEP = VRFW_Cmd.VRFW_MENU_SCENE_SHOT_STEP,      -- CMND_VRFW_MENU_SCENE_SHOT_STEP (key, -1 | 1) -> the shot now running
  STORY_GO = 4275168888,     -- param vrfw_menu_scene_story_continue (value = ms of the push-in): title_main skips the story submenu
  STORY_INFO = 3984017190,   -- () -> ok, story saves (> 0 = «Continuar» exists), … (the title's own test after the story submenu)
  SHOT_PREV = 2155540576,    -- CMD_FUNCTION arg crc32 vrfw_menu_scene_shot_prev (a mod binds a key to it: content\menus\)
  SHOT_NEXT = 951543817,     -- CMD_FUNCTION arg crc32 vrfw_menu_scene_shot_next
  UPPER = 2250456639,        -- title00_07_item_button_upper: the mode row (its tiles call the shots)
  FOCUS_ACTIVE = VRFW_Cmd.IS_CTRL_FOCUS_ACTIVE,  -- (layer) -> the layer holds the control focus
  FOCUS_INDEX = 2603265800,  -- (layer) -> its focused instance
  LOWER = 3873872512,        -- title00_07_item_button_lower: the lower row
  CURSOR = 24113234,         -- cmn05_01_coursor: the focus cursor
  FOCUS_MOVE = 2649971789,   -- the title's up / down function (arg up 1133833840, low 2458417313)
  DIR_UP = 1133833840,
  DIR_LOW = 2458417313,
  KEY_HELD = 2620918304,     -- (key) -> the key is repeating (the title ignores held up / down)
  KEY_UP = 1197218715,       -- CMD_UP
  CTRL_FOCUS = VRFW_Cmd.SET_ENABLE_CTRL_FOCUS,   -- (layer, on): the layer takes the control focus
  FOCUS_MARK = 1778826357,   -- (layer, instance, true): the focus moves there (OnChangeFocus follows)
  TRACE = VRFW_Cmd.SET_LAYER_ATTACH_LOCATOR_TRACE,        -- (layer, instance, locator, on): the cursor follows that instance
  CURSOR_LOCATOR = 282284405, -- _pos_atc_cur01
  SOUND = VRFW_Cmd.SND_PLAY_SE,
  SOUND_MOVE = 3284053048,   -- sy0082: the title's focus move sound
  -- the mode's name: layer vrfw_ms_label (object vrfw_mp_label: the corner button's text node, its plates hidden)
  LABEL = 2134430854,        -- vrfw_ms_label
  LABEL_NODE = 378327766,    -- _text_cmd_back01
  LABEL_MESHES = { 298211823, 2853207670 },   -- _cmd_back_base01, _cmd_back_base01_add
  LABEL_LEFT = -384,         -- the text node's left edge in its object (px)
  LABEL_MID_Y = 144,         -- its centre line
  OPEN_LAYER = VRFW_Cmd.OPEN_LAYER,    -- (layer, instance)
  LAYER_NUM = VRFW_Cmd.GET_CREATE_LAYER_NUM,    -- (layer) -> instances
  POS = VRFW_Cmd.SET_LAYER_LOCAL_POS,          -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z, instance): y up
  SCALE = VRFW_Cmd.SET_LAYER_LOCAL_SCALE,        -- CMND_SET_LAYER_LOCAL_SCALE (layer, sx, sy, sz, instance)
  TEXT = VRFW_Cmd.SET_MENU_TEXT_STRING,         -- CMND_SET_MENU_TEXT_STRING (layer, node, text, instance)
  TEXT_ALPHA = VRFW_Cmd.SET_MENU_TEXT_ALPHA,   -- CMND_SET_MENU_TEXT_ALPHA (layer, instance, node, alpha)
  MESH_VISIBLE = VRFW_Cmd.SET_MESH_VISIBLE, -- (layer, mesh, on, instance)
  HOTSPOTS = VRFW_Cmd.VRFW_MENU_SCENE_HOTSPOTS,     -- CMND_VRFW_MENU_SCENE_HOTSPOTS (key) -> "" | { shot, settled, n, [i] = { … } }
  SCREENS = VRFW_Cmd.VRFW_MENU_SCENE_SCREENS,       -- CMND_VRFW_MENU_SCENE_SCREENS (key) -> "" | { n, [i] = { name, on, fade_ms, seen, x0, y0, x1, y1, layers, design } }
  SHOT_TAGS = VRFW_Cmd.VRFW_MENU_SCENE_SHOT_TAGS,     -- CMND_VRFW_MENU_SCENE_SHOT_TAGS (key) -> "" | { shot, on = { tag ids }, off = { tag ids } }
  LAYER_ALPHA = VRFW_Cmd.SET_LAYER_MODEL_ALPHA,  -- CMND_SET_LAYER_MODEL_ALPHA (layer, instance, 0, alpha)
  STORY_KIND = 3368022765,   -- param vrfw_menu_scene_story_kind: 1 continue, 2 new game (with STORY_GO)
  STORY_PICK = 1790329263,   -- param vrfw_menu_scene_story_pick: the story submenu's entry + 1 it picks itself
  STORY_WAIT = 2392182225,   -- param vrfw_menu_scene_story_wait: ms title_main waits before the story submenu opens
  BIT = VRFW_Cmd.GET_GLOBAL_BIT_FLAG,           -- (global bit) -> set
  STORY_MODES_BIT = 750283301, -- Historia+ / Historia extendida are open (the submenu's IsEnableListItem)
  TEXT_GET = VRFW_Cmd.TEXT_GET,     -- CMND_TEXT_GET (id) -> text
  TEXT_GET_KEY = VRFW_Cmd.VRFW_TEXT_GET,  -- CMND_VRFW_TEXT_GET (key) -> text
  TEXT_SIZE = VRFW_Cmd.GET_MENU_TEXT_RECT_SIZE,    -- CMND_GET_MENU_TEXT_RECT_SIZE (layer, instance, node) -> width, height
  NODE_SCALE = 2885415772,   -- (layer, instance, node, width, height): the text node's box
  BUZZER = 2086672038,       -- sy0003
  SELECTED_GROW = 1.15,      -- the selected hotspot's text, larger
  UNSELECTED_ALPHA = 0.8,    -- the other hotspots' texts (also all of them while another row has the focus)
  -- the selected hotspot's outline: four thin quads along its rectangle's edges on screen (layer vrfw_ms_frame, the
  -- 36 px quad cmn01_10 re-skinned with the framework's white square of vrfw_plain and tinted light blue)
  FRAME = 3295131811,        -- vrfw_ms_frame
  FRAME_QUAD = 36,           -- the quad's own size (px)
  FRAME_SPRITE_NODE = 1909474081,   -- icon_new01: the quad's sprite
  FRAME_MESH = 312193881,    -- _icon_new01: the quad's mesh (its colour)
  FRAME_ATLAS = 528860506,   -- #/menu/220_img/vrfw_plain/vrfw_plain.g4tx
  FRAME_SQUARE = 1334397707, -- vrfw_plain_square (white)
  FRAME_COLOUR = { 0.32, 0.72, 1.0 },   -- the game's light blue
  FRAME_THICKNESS = 6,       -- px
  FLOOD_INSTANCE = 4,        -- vrfw_ms_frame 4: the light flood of a hotspot's A (light_flood_seconds)
  FLOOD_COLOUR = { 1.0, 0.96, 0.86 },   -- warm daylight
  SPRITE = 558735651,        -- (layer, texture, sprite, old sprite, 0, instance)
  ROTATE = 3476640154,       -- (layer, x, y, z radians, instance)
  PRIM_COLOR = VRFW_Cmd.SET_PRIM_COLOR,    -- (layer, instance, mesh, r, g, b)
  MAP_TAG = VRFW_Cmd.SET_MAP_TAG,      -- CMND_SET_MAP_TAG (tag, on): the map's meshes of that tag shown / hidden (the map is up)
  DOOR_OPEN = VRFW_Cmd.DOOR_OPEN,    -- CMND_DOOR_OPEN (door id, play the clip, reverse clips): a registered map door opens
  DOOR_TYPE = VRFW_Cmd.GET_DOOR_TYPE,     -- CMND_GET_DOOR_TYPE (door id) -> registered, door type, a float of the door
  CHRONICLE_WAIT = 53570903, -- param vrfw_menu_scene_chronicle_wait (value = ms of the push-in): title_main ends the title
                             -- after it and the Chronicle top menu goes straight to the map (action chronicle_map)
  PENDING = VRFW_Cmd.VRFW_MENU_SCENE_PENDING,      -- CMND_VRFW_MENU_SCENE_PENDING (action | "")
  LEAVE_WHITE = 2048703318,  -- param vrfw_menu_scene_leave_white: title_main leaves with the white fade (leave_fade)
  PICK_LAYER = 2283875177, -- param vrfw_menu_scene_pick_layer: the next menu holding this layer presses an entry of it
  PICK_INDEX = 3968429426, -- param vrfw_menu_scene_pick_index: that entry + 1
  PICK_OPTION = 2481379900, -- param vrfw_menu_scene_pick_option: the option of the entry's own choice + 1 (pick_option)
  BB_CAMPAIGN_SAVE = VRFW_Cmd.GET_BB_STADIUM_CAMPAIGN_INFO, -- (0) -> a Battle Bay campaign save exists (the BB top menu's own check)
  PICK_WAIT = 2171674033,  -- param vrfw_menu_scene_pick_wait: ms title_main waits (the push-in) before it ends
  HOME = VRFW_Cmd.VRFW_MENU_SCENE_HOME,         -- CMND_VRFW_MENU_SCENE_HOME (key[, on]) -> 1 on the home entry
  COME_BACK = VRFW_Cmd.VRFW_MENU_SCENE_COME_BACK,    -- CMND_VRFW_MENU_SCENE_COME_BACK (key[, mode]) -> mode: the mode a return to the title opens on
  PICK_RETURN = 1862198659,  -- param vrfw_menu_scene_pick_return: the picked entry's menu goes back to the title (return)
  FOCUS_WAIT_FRAMES = 10,    -- after a move out of the home entry: frames the old tile's focus is not reported
  MENU = "title_menu_2",
  ID = "vr_framework.menu_scene",
  ASK_FRAMES = 60,           -- frames the framework may stay silent before the retail menu is kept
  READY_FRAMES = 1800,       -- frames to wait for the menu to be ready (sheets, windows) before giving up
}

-- per menu visit: phase ask | wait_ready | requested | handed | going_up | up | off
local ms = { phase = "off", frames = 0, asks = 0, key = nil, timeout = 600, hide = {}, hidden = {}, close = {}, closed = 0, up_frames = 0,
  counts = {}, hidden_set = {}, modes = false, mode_idx = nil, cursor_hidden = false, label = nil,
  home_shot = nil, home = false, home_restore = nil, home_leave = false, focus_wait = nil }

local function MS_Log(...)
  pcall(funcLuaCommand, MS.LOG, "menu_scene", "title_menu_2", ...)
end

-- the title's scene state for its mods (this VM is the one owner; no game param): up over the scene's map, and on its
-- home entry
function VRFW_MenuSceneIsUp() return ms.phase == "up" end
function VRFW_MenuSceneIsHome() return ms.phase == "up" and ms.home == true end

-- the title's scene events for mods: VRFW_MenuScene.On(event, id, fn) registers fn (one per id: registering an id again
-- replaces it). Events: "mode_focused" (index; -1 = the home entry) after the framework moved the mode row's focus
-- (mode keys, a restore, the scene's up; the pad's own moves reach the title's OnChangeFocus), "home_changed" (on, why)
-- when the home entry comes or goes. Registering runs no engine call (allowed at load time).
VRFW_MenuScene = VRFW_MenuScene or {}
local ms_listeners = { mode_focused = {}, home_changed = {} }
function VRFW_MenuScene.On(event, id, fn)
  local list = ms_listeners[event]
  if list == nil or type(id) ~= "string" or type(fn) ~= "function" then return false end
  for i, l in ipairs(list) do
    if l.id == id then
      list[i].fn = fn
      return true
    end
  end
  list[#list + 1] = { id = id, fn = fn }
  return true
end
local function MS_Emit(event, ...)
  for _, l in ipairs(ms_listeners[event]) do
    local ok, why = pcall(l.fn, ...)
    if not ok then pcall(funcLuaCommand, MS.LOG, "menu_scene", "title_menu_2", "listener", l.id, event, "error:", tostring(why)) end
  end
end

local function MS_Call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then return nil end
  return table.unpack(r, 2, r.n)
end

-- a param cleared only when it is set (the retail way)
local function MS_Clear(k)
  if VRFW_Param.Has(k) then
    VRFW_Param.Clear(k)
  end
end

local function MS_Fail(why)
  MS_Log("FAILED:", why, "-> the retail main menu")
  MS_Clear(MS.HUD_OFF)
  ms.home = false
  MS_Call(MS.SET, "failed", "title_menu_2: " .. tostring(why))
  MS_Clear(MS.GO)
  MS_Call(MS.FADE, 0, 0.3)
  ms.phase = "off"
end

-- the menu's opening coroutine is done and nothing is open over it
local function MS_Ready()
  if MS_Call(MS.MSG_BUSY) == true or MS_Call(MS.IS_MENU, MS.SHEET) == true then
    return false
  end
  local h = type(VRFW_Host) == "table" and VRFW_Host.hosts and VRFW_Host.hosts.title_menu_2
  local L = h and h.L
  if L ~= nil then
    -- the opening coroutine done, or past its sheets and its first activation (t12[4]: the menu takes input; its last
    -- wait, up to 120 frames for a row button, is not needed)
    local ok, co, t12 = pcall(function() return L.l5, L.t12 end)
    if ok then
      return co == nil or (type(t12) == "table" and t12[4] == true)
    end
  end
  return ms.frames >= 90       -- no locals: the opening coroutine's usual length
end

-- the scene's hidden layers, every instance (counted again on `recount`: a row may grow)
local function MS_Hide(recount)
  for _, id in ipairs(ms.hide) do
    local n = ms.counts[id]
    if n == nil or recount then
      n = 1
      for k = 1, 15 do
        local ok, has = pcall(funcLuaMenuCommand, MS.LAYER_EXISTS, id, k)
        if not ok or has ~= true then break end
        n = k + 1
      end
      ms.counts[id] = n
    end
    for k = 0, n - 1 do
      pcall(funcLuaMenuCommand, MS.VISIBLE, id, k, false)
    end
    if not ms.hidden[id] then
      ms.hidden[id] = true
      MS_Log("layer", id, "hidden (the map shows through)")
    end
  end
end

-- the field's HUD menus (gauges, button guide, date, pop-ups) closed and its minimap hidden: only the map stays
local function MS_CloseField()
  ms.seen = ms.seen or {}
  for _, m in ipairs(ms.close) do
    local a, b = MS_Call(MS.MENU_EXISTS, m), MS_Call(MS.IS_MENU_OPEN, m)
    if not ms.seen[m] then
      ms.seen[m] = true
      MS_Log("field menu", m, "exists:", tostring(a), "open:", tostring(b))
    end
    if a == true or b == true then
      MS_Call(MS.CLOSE, m)
      ms.closed = ms.closed + 1
      if ms.closed <= 8 then
        MS_Log("field menu", m, "closed (the field HUD off under the main menu)")
      end
    end
  end
  if #ms.close > 0 then
    MS_Call(MS.MINIMAP, false)
  end
end

-- the mode row's focused tile -> the scene's shot (the lower row and the banners keep the shot as it is)
-- (polled every frame while up, from the title's own selection: GetSelectItemLayerName / GetSelectItemIdx; a change of
-- the mode row's tile is reported once)
local function MS_ReportFocus()
  if ms.phase ~= "up" or type(GetSelectItemLayerName) ~= "function" or type(GetTitleMenuItemId) ~= "function" then
    return
  end
  if ms.home then
    ms.focus = nil              -- the home entry: its shot stays, the tile under the hidden focus is not reported
    return
  end
  local okl, layer = pcall(GetSelectItemLayerName)
  if not okl or layer ~= MS.UPPER then
    ms.focus = nil              -- off the mode row: the shot stays
    return
  end
  local oki, idx = pcall(GetSelectItemIdx)
  if not oki or type(idx) ~= "number" then return end
  local wait = ms.focus_wait
  if wait then
    -- just out of the home entry: the title's selection may still be the tile it sat on
    if idx ~= wait.idx and ms.up_frames <= wait.last then return end
    ms.focus_wait = nil
  end
  local okt, item = pcall(GetTitleMenuItemId, idx, true)
  if not okt or type(item) ~= "number" then return end
  item = item % 4294967296
  if item == ms.focus then return end
  ms.focus = item
  local shot = MS_Call(MS.SHOT, ms.key, string.format("%.0f", item))
  MS_Log("focus: mode row tile", idx, string.format("%.0f", item), "-> shot", tostring(shot))
end

-- the home entry on / off: the framework's camera (the home shot, kept for tile reports), the game param for mods
-- the "mode_focused" event (VRFW_MenuScene.On): the framework moved the mode row's focus; index -1 = the home entry
local function MS_ModeFocused(index)
  MS_Emit("mode_focused", index)
end

local function MS_SetHome(on, why)
  if not ms.home_shot then return end
  ms.home, ms.focus, ms.label = on, nil, nil
  local r = MS_Call(MS.HOME, ms.key, on and 1 or 0)
  MS_Log("home entry", on and "on" or "off", "(", tostring(why), "): framework", tostring(r))
  MS_Emit("home_changed", on, why)            -- the "home_changed" event (VRFW_MenuScene.On)
end

-- ---- the shots as the mode selection (scene key shots_select_modes)

local function MS_M(...)
  local r = table.pack(pcall(funcLuaMenuCommand, ...))
  if not r[1] then return nil end
  return table.unpack(r, 2, r.n)
end

-- the title's own selection: layer, instance
local function MS_Selected()
  if type(GetSelectItemLayerName) ~= "function" or type(GetSelectItemIdx) ~= "function" then return nil, nil end
  local okl, layer = pcall(GetSelectItemLayerName)
  local oki, idx = pcall(GetSelectItemIdx)
  return okl and layer or nil, oki and idx or nil
end

-- the instances of vrfw_ms_label (0 = the menu has no such layer: the mod's menus TOML is not installed)
local function MS_LabelCount()
  if ms.label_count == nil then
    local n = MS_M(MS.LAYER_NUM, MS.LABEL)
    ms.label_count = type(n) == "number" and n or 0
    ms.label_open = {}
    if ms.label_count == 0 then MS_Log("no layer vrfw_ms_label in this menu: no mode name, no hotspot texts") end
  end
  return ms.label_count
end

-- a text on vrfw_ms_label instance k: left edge x, centre line y (menu px from the top), scale sx / sy, alpha;
-- an empty text hides it
local function MS_Text(k, text, x, y, sx, sy, alpha)
  if k >= MS_LabelCount() then return false end
  if type(text) ~= "string" or text == "" then
    if ms.label_open[k] then
      MS_M(MS.VISIBLE, MS.LABEL, k, false)
      MS_M(MS.POS, MS.LABEL, -4000, 4000, 0, k)
    end
    return true
  end
  if not ms.label_open[k] then
    ms.label_open[k] = true
    MS_M(MS.OPEN_LAYER, MS.LABEL, k)
    MS_M(MS.NODE_SCALE, MS.LABEL, k, MS.LABEL_NODE, 1600, 76)   -- a box wider than any line: never squeezed
  end
  for _, m in ipairs(MS.LABEL_MESHES) do MS_M(MS.MESH_VISIBLE, MS.LABEL, m, false, k) end
  MS_M(MS.TEXT, MS.LABEL, MS.LABEL_NODE, text, k)
  MS_M(MS.SCALE, MS.LABEL, sx, sy, 1, k)
  MS_M(MS.POS, MS.LABEL, x - MS.LABEL_LEFT * sx, -y - MS.LABEL_MID_Y * sy, 0, k)
  MS_M(MS.TEXT_ALPHA, MS.LABEL, k, MS.LABEL_NODE, alpha or 1)
  MS_M(MS.VISIBLE, MS.LABEL, k, true)
  return true
end

-- every frame: the cursor hidden on the mode row; the name of the mode on screen (the row's focused tile, or the one
-- last focused while the lower row has the focus), drawn again only when it changes
local function MS_ModeFrame()
  local layer, idx = MS_Selected()
  if layer == MS.UPPER and type(idx) == "number" then
    ms.mode_idx = idx
    if not ms.cursor_hidden or ms.up_frames % 10 == 0 then
      MS_M(MS.VISIBLE, MS.CURSOR, 0, false)
      ms.cursor_hidden = true
    end
  elseif ms.cursor_hidden then
    ms.cursor_hidden = false
    MS_M(MS.VISIBLE, MS.CURSOR, 0, true)
  end
  if ms.mode_idx == nil then return end
  local on_row = layer == MS.UPPER
  local want = string.format("%d:%s:%s", ms.mode_idx, tostring(on_row), tostring(ms.home))
  if want == ms.label then return end
  ms.label = want
  local name = ""
  if ms.home then
    if ms.label_on then MS_Text(0, "") end
    MS_Log("mode: the home entry", on_row and "(focused)" or "(the lower row has the focus)")
    return
  end
  if type(GetTextItemName) == "function" then
    local ok, t = pcall(GetTextItemName, ms.mode_idx, true)
    if ok and type(t) == "string" then name = t end
  end
  if ms.label_on then
    MS_Text(0, name, ms.label_x, ms.label_y, ms.label_scale, ms.label_scale, on_row and 1 or 0.6)
  end
  MS_Log("mode:", ms.mode_idx, name, on_row and "(focused)" or "(the lower row has the focus)")
end

-- the previous (-1) / next (+1) mode: the mode row's focus moves there (from the lower row too)
local function MS_ModeStep(dir)
  local n = type(GetItemButtonNum) == "function" and GetItemButtonNum(true) or 0
  if type(n) ~= "number" or n < 1 then return end
  local layer, idx = MS_Selected()
  local from = (layer == MS.UPPER and idx) or ms.mode_idx or 0
  local to = (from + dir) % n
  -- with a home entry: true = into it (past the first / last mode; the hidden focus stays), false = out of it
  local home = nil
  if ms.home_shot then
    if ms.home then
      to, home = (dir > 0 and 0 or n - 1), false
    elseif (dir > 0 and from == n - 1) or (dir < 0 and from == 0) then
      to, home = from, true
    end
  end
  if layer ~= MS.UPPER and layer ~= nil then
    MS_M(MS.TRACE, layer, idx or 0, MS.CURSOR_LOCATOR, false)
    MS_M(MS.CTRL_FOCUS, layer, false)
    MS_M(MS.CTRL_FOCUS, MS.UPPER, true)
  end
  local was_home = ms.home
  if home ~= nil then MS_SetHome(home, dir < 0 and "previous mode key" or "next mode key") end
  if home == false then ms.focus_wait = { idx = to, last = ms.up_frames + MS.FOCUS_WAIT_FRAMES } end
  if not (layer == MS.UPPER and idx == to) then
    ms.own_move = ms.up_frames
    MS_M(MS.FOCUS_MARK, MS.UPPER, to, true)
  end
  pcall(funcLuaCommand, MS.SOUND, MS.SOUND_MOVE)
  MS_Log("mode key", dir < 0 and "previous" or "next", ":", was_home and "home" or from, "->", home == true and "home" or to)
  MS_ModeFocused(home == true and -1 or to)
end

-- A scene-reload host restores the mode through the same home/focus state used by
-- navigation. Changing only the camera's Home command leaves this VM on home.
function VRFW_MenuSceneFocusMode(index)
  if ms.phase ~= "up" then return false end
  index = tonumber(index)
  local n = type(GetItemButtonNum) == "function" and GetItemButtonNum(true) or 0
  if not index or index ~= math.floor(index) or index < -1 or index >= n then return false end
  if index < 0 then
    if not ms.home_shot then return false end
    MS_SetHome(true, "restored after a scene reload")
    MS_ModeFocused(-1)
    return true
  end
  MS_SetHome(false, "restored after a scene reload")
  ms.home_restore, ms.home_leave, ms.focus = nil, false, nil
  ms.mode_idx = index
  ms.focus_wait = { idx = index, last = ms.up_frames + MS.FOCUS_WAIT_FRAMES }
  ms.own_move = ms.up_frames
  MS_M(MS.CTRL_FOCUS, MS.UPPER, true)
  MS_M(MS.FOCUS_MARK, MS.UPPER, index, true)
  MS_ModeFocused(index)
  return true
end

-- left / right on the hidden row with a home entry: from it into the first / last mode, from the first / last mode's
-- wrap-around into it. true = handled (the row's own move is undone next frame), false = the title's move goes on
local function MS_HomeMove(old, new)
  local n = type(GetItemButtonNum) == "function" and GetItemButtonNum(true) or 0
  if type(n) ~= "number" or n < 1 then return false end
  local dir = ((new - old) % n) == 1 and 1 or -1
  if ms.home then
    local to = dir > 0 and 0 or n - 1
    if new == to then
      MS_SetHome(false, "left / right")
      return false
    end
    ms.home_restore, ms.home_leave = to, true
  elseif (dir > 0 and old == n - 1) or (dir < 0 and old == 0) then
    MS_SetHome(true, "left / right")
    ms.home_restore, ms.home_leave = old, false
  else
    return false
  end
  pcall(funcLuaCommand, MS.SOUND, MS.SOUND_MOVE)
  MS_Log("left / right:", old, "->", new, ms.home_leave and ("out of the home entry to " .. tostring(ms.home_restore))
    or "into the home entry")
  return true
end

-- up / down with the mode row hidden: true = handled here (the title's own move does not run)
local function MS_ModeUpDown(dir)
  local layer, idx = MS_Selected()
  -- a shot whose hotspots stand one above the other (hotspot_keys = "up_down"): up / down move the selection; past the
  -- first / last one the title's own up / down
  local h = ms.hot
  if h and h.active and h.keys == "up_down" and layer == MS.UPPER and h.n > 1 then
    local to = h.sel + ((dir == MS.DIR_UP) and -1 or 1)
    if to >= 1 and to <= h.n then
      h.sel = to
      pcall(funcLuaCommand, MS.SOUND, MS.SOUND_MOVE)
      MS_Log("hotspot", h.sel, h.list[h.sel] and h.list[h.sel].name, "(up / down)")
      return true
    end
  end
  if dir == MS.DIR_UP and layer == MS.LOWER and ms.mode_idx ~= nil then
    if MS_M(MS.KEY_HELD, MS.KEY_UP) then return true end
    -- back to the mode on screen, not to the tile above
    MS_M(MS.TRACE, layer, idx or 0, MS.CURSOR_LOCATOR, false)
    MS_M(MS.CTRL_FOCUS, layer, false)
    MS_M(MS.CTRL_FOCUS, MS.UPPER, true)
    ms.own_move = ms.up_frames
    MS_M(MS.FOCUS_MARK, MS.UPPER, ms.mode_idx, true)
    pcall(funcLuaCommand, MS.SOUND, MS.SOUND_MOVE)
    return true
  end
  if (dir == MS.DIR_UP and layer == MS.UPPER) or (dir == MS.DIR_LOW and layer == MS.LOWER) then
    -- the title's target (a banner): refused when the scene hides it
    local target
    if type(GetNextFocusBannerLayerName) == "function" then
      local ok, t = pcall(GetNextFocusBannerLayerName, layer, idx or 0)
      target = ok and t or nil
    end
    if target ~= nil and ms.hidden_set[target] then return true end
  end
  return false
end

-- ---- hotspots (scene key shots_select_modes + [[VRFW.MenuSceneHotspot]])

-- the story submenu's entries (story_mode_top_menu): row, text, available now; chronicle_map: the Chronicle top menu's
-- «Cadena de Crónica»
local STORY_ROW = { story_new_game = 0, story_continue = 1, story_plus = 2, story_extended = 3 }
local ACTION_TEXT = { story_new_game = 1851993283, story_continue = 2856747853, story_plus = 1003539027, story_extended = 89409320,
  chronicle_map = 365874030 }

local function MS_StorySaves()
  local ok, _, saves = pcall(funcLuaCommand, MS.STORY_INFO)
  return ok and tonumber(saves) or 0
end

-- the conditions a hotspot's open_group_if may name
local GROUP_CONDITIONS = {
  bb_campaign_save = function() return MS_M(MS.BB_CAMPAIGN_SAVE, 0) == true end,
}

local function MS_ActionAvailable(a, saves, e)
  if a == "open_group" then
    if not e or (e.open_group or "") == "" then return false end
    local cond = e.open_group_if or ""
    if cond == "" then return true end
    local f = GROUP_CONDITIONS[cond]
    local ok, yes = pcall(f or function() return false end)
    return ok and yes == true
  end
  if a == "story_continue" then return saves > 0 end
  if a == "story_new_game" then return saves <= 0 end
  if a == "story_plus" or a == "story_extended" then return MS_Call(MS.BIT, MS.STORY_MODES_BIT) == true end
  if a == "chronicle_map" then return true end   -- the title's own press decides (a locked mode is refused there)
  if a == "menu_pick" then return true end       -- the tile's own press decides; the next menu presses the entry
  if a == "call" then return e ~= nil and (e.call or "") ~= "" end
  return false
end

local function MS_TextOf(t, action)
  if type(t) == "string" and t ~= "" then
    local id = tonumber(t)
    if id then
      local ok, s = pcall(funcLuaCommand, MS.TEXT_GET, id)
      if ok and type(s) == "string" and s ~= "" then return s end
    end
    local ok, s = pcall(funcLuaCommand, MS.TEXT_GET_KEY, t)
    if ok and type(s) == "string" and s ~= "" then return s end
  end
  local ok, s = pcall(funcLuaCommand, MS.TEXT_GET, ACTION_TEXT[action] or 0)
  return ok and type(s) == "string" and s or ""
end

-- everything of the hotspots hidden
-- the outline layer's instances (0 = the mod's menus TOML adds no vrfw_ms_frame: no outline)
local function MS_FrameCount()
  if ms.frame_count == nil then
    local n = MS_M(MS.LAYER_NUM, MS.FRAME)
    ms.frame_count = type(n) == "number" and n or 0
    ms.frame_open = {}
    if ms.frame_count < 4 then MS_Log("no layer vrfw_ms_frame (4 instances) in this menu: no hotspot outline") end
  end
  return ms.frame_count
end

-- the outline's instances shown last frame (hidden again when not drawn)
local function MS_FrameHide(from)
  if not ms.frame_shown then return end
  for k, on in pairs(ms.frame_shown) do
    if on and (from == nil or not from[k]) then
      MS_M(MS.VISIBLE, MS.FRAME, k, false)
      ms.frame_shown[k] = nil
    end
  end
  if from == nil then ms.frame_shown = false end
end

-- the parts of the segment a -> b (0..1 along it) outside the boxes { x0, y0, x1, y1, … } grown by `pad` (menu px)
local function MS_SegmentOutside(ax, ay, bx, by, boxes, pad)
  local keep = { { 0, 1 } }
  for b = 1, #boxes - 3, 4 do
    local x0, y0, x1, y1 = boxes[b] - pad, boxes[b + 1] - pad, boxes[b + 2] + pad, boxes[b + 3] + pad
    -- the segment's part inside the box (Liang-Barsky)
    local t0, t1, inside = 0, 1, true
    for _, edge in ipairs({ { -(bx - ax), ax - x0 }, { bx - ax, x1 - ax }, { -(by - ay), ay - y0 }, { by - ay, y1 - ay } }) do
      local p, q = edge[1], edge[2]
      if p == 0 then
        if q < 0 then inside = false end
      else
        local r = q / p
        if p < 0 then t0 = math.max(t0, r) else t1 = math.min(t1, r) end
      end
    end
    if inside and t0 < t1 then
      local cut = {}
      for _, piece in ipairs(keep) do
        if piece[2] <= t0 or piece[1] >= t1 then
          cut[#cut + 1] = piece
        else
          if piece[1] < t0 then cut[#cut + 1] = { piece[1], t0 } end
          if piece[2] > t1 then cut[#cut + 1] = { t1, piece[2] } end
        end
      end
      keep = cut
    end
  end
  return keep
end

-- the selected hotspot's outline: an edge quad from each corner on screen to the next (outline = x1, y1, … x4, y4;
-- menu px, y down), without the parts behind a scene person nearer to the camera (hidden = their boxes, x0, y0, x1, y1
-- each); each part one instance of vrfw_ms_frame (not the light flood's), parts beyond the layer's count left out
local function MS_FrameDraw(outline, hidden)
  if MS_FrameCount() < 4 or type(outline) ~= "table" or #outline < 8 then return MS_FrameHide() end
  local t = MS.FRAME_THICKNESS
  local boxes = type(hidden) == "table" and hidden or {}
  local pieces = {}
  for k = 0, 3 do
    local ax, ay = outline[k * 2 + 1], outline[k * 2 + 2]
    local n = (k + 1) % 4
    local bx, by = outline[n * 2 + 1], outline[n * 2 + 2]
    -- a little longer at both ends: the corners close
    local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    if len > 0 then
      local ux, uy = (bx - ax) / len, (by - ay) / len
      ax, ay, bx, by = ax - ux * t / 2, ay - uy * t / 2, bx + ux * t / 2, by + uy * t / 2
      for _, part in ipairs(MS_SegmentOutside(ax, ay, bx, by, boxes, t / 2)) do
        local px, py = ax + (bx - ax) * part[1], ay + (by - ay) * part[1]
        local qx, qy = ax + (bx - ax) * part[2], ay + (by - ay) * part[2]
        if (qx - px) ^ 2 + (qy - py) ^ 2 >= 4 then pieces[#pieces + 1] = { px, py, qx, qy } end
      end
    end
  end
  local drawn, k, count = {}, 0, 0
  for _, piece in ipairs(pieces) do
    if k == MS.FLOOD_INSTANCE then k = k + 1 end
    if k >= MS_FrameCount() then break end
    local ax, ay, bx, by = piece[1], piece[2], piece[3], piece[4]
    if not ms.frame_open[k] then
      ms.frame_open[k] = true
      MS_M(MS.OPEN_LAYER, MS.FRAME, k)
      MS_M(MS.SPRITE, MS.FRAME, MS.FRAME_ATLAS, MS.FRAME_SQUARE, MS.FRAME_SPRITE_NODE, 0, k)
      MS_M(MS.PRIM_COLOR, MS.FRAME, k, MS.FRAME_MESH, MS.FRAME_COLOUR[1], MS.FRAME_COLOUR[2], MS.FRAME_COLOUR[3])
    end
    MS_M(MS.SCALE, MS.FRAME, math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) / MS.FRAME_QUAD, t / MS.FRAME_QUAD, 1, k)
    MS_M(MS.ROTATE, MS.FRAME, 0, 0, math.atan2(-(by - ay), bx - ax), k)
    MS_M(MS.POS, MS.FRAME, (ax + bx) / 2, -(ay + by) / 2, 0, k)
    MS_M(MS.VISIBLE, MS.FRAME, k, true)
    drawn[k] = true
    k, count = k + 1, count + 1
  end
  if count < #pieces and not ms.frame_short_logged then
    ms.frame_short_logged = true
    MS_Log("outline:", #pieces, "parts, vrfw_ms_frame draws", count, "(more instances needed)")
  end
  if type(ms.frame_shown) == "table" then MS_FrameHide(drawn) end
  ms.frame_shown = drawn
end

-- the selected hotspot's actor edge (edge_actor): set on the actor that is selected now, its own on the one before
local function MS_EdgeTo(slot)
  local h = ms.hot
  if (h.edge_shown or 0) == (slot or 0) then return end
  if VRFW_MenuScene and VRFW_MenuScene.ActorEdge then
    if (h.edge_shown or 0) ~= 0 then VRFW_MenuScene.ActorEdge(h.edge_shown, false) end
    if (slot or 0) ~= 0 then VRFW_MenuScene.ActorEdge(slot, true) end
  end
  h.edge_shown = slot or 0
end

local function MS_HotHide()
  local h = ms.hot
  h.outline_on = nil
  MS_EdgeTo(0)
  MS_FrameHide()
  if not h.drawn then return end
  h.drawn = false
  for i = 1, h.n or 0 do
    MS_Text(i, "")
  end
end

-- the hotspots of a shot that just came: each one's action (the first available), its text, the one selected
local function MS_HotLoad(r)
  local h = ms.hot
  if r.shot ~= h.group_shot then h.group, h.group_shot = "", r.shot end   -- a new shot opens on its first group
  h.group = h.group or ""
  h.shot, h.list, h.sel = r.shot, {}, 1
  h.keys = r.keys or "left_right"
  local saves = MS_StorySaves()
  local max = MS_LabelCount() - 1
  local src = {}
  for i = 1, tonumber(r.n) or 0 do
    if type(r[i]) == "table" and (r[i].group or "") == h.group and #src < max then src[#src + 1] = i end
  end
  h.n = #src
  for j, si in ipairs(src) do
    local i, e = j, r[si]
    local pick, ok = nil, false
    for _, a in ipairs(type(e.actions) == "table" and e.actions or {}) do
      if MS_ActionAvailable(a, saves, e) then pick, ok = a, true break end
    end
    pick = pick or (type(e.actions) == "table" and e.actions[1]) or ""
    h.list[i] = { name = e.name, action = pick, available = ok, text = MS_TextOf(e.text, pick), push_shot = e.push_shot,
      ms = tonumber(e.ms) or 800, flood_ms = tonumber(e.flood_ms) or 0, width = nil,
      door = type(e.door) == "string" and e.door or "", door_id = tonumber(e.door_id) or 0,
      door_ms = tonumber(e.door_ms) or 0, door_reverse = e.door_reverse == 1, leave_white = e.leave_white == 1,
      pick_layer = tonumber(e.pick_layer) or 0, pick_index = tonumber(e.pick_index) or 0, draw = e.draw ~= 0,
      pick_option = tonumber(e.pick_option) or -1, open_group = e.open_group or "", back_to = e.back_to or "", src = si,
      outline_tag = tonumber(e.outline_tag) or 0, edge_actor = tonumber(e.edge_actor) or 0, call = e.call or "" }
    if e.start == 1 then h.sel = i end
    MS_Log("hotspot", i, e.name, "->", pick, ok and "available" or "not available", h.list[i].text)
    if h.list[i].door_id ~= 0 then
      local okc, registered, kind = pcall(funcLuaCommand, MS.DOOR_TYPE, h.list[i].door_id)
      MS_Log("hotspot", e.name, "door", h.list[i].door, string.format("0x%08X", h.list[i].door_id), "registered:",
        okc and tostring(registered) or "call failed", okc and kind and string.format("type 0x%08X", kind % 4294967296) or "")
    end
  end
  if #src >= max and h.n < (tonumber(r.n) or 0) then MS_Log("vrfw_ms_label has", MS_LabelCount(), "instance(s): only", h.n, "hotspot(s) drawn") end
end

-- the text's width at scale 1 (the game's measure, else 13 px per character)
local function MS_TextWidth(k, text)
  MS_M(MS.NODE_SCALE, MS.LABEL, k, MS.LABEL_NODE, 1600, 76)
  MS_M(MS.SCALE, MS.LABEL, 1, 1, 1, k)
  MS_M(MS.TEXT, MS.LABEL, MS.LABEL_NODE, text, k)
  local w = MS_M(MS.TEXT_SIZE, MS.LABEL, k, MS.LABEL_NODE)
  if type(w) ~= "number" or w <= 0 then w = 13 * #text end
  return w
end

-- every frame while up: the hotspots of the shot now running, where the camera sees them. Their texts show whatever row
-- has the focus (white); the selection (an outline along the selected one's rectangle, its text a little larger)
-- and the keys only while the mode row has it.
local function MS_HotFrame()
  local h = ms.hot
  local layer = MS_Selected()
  if ms.home then
    h.active, h.shot = false, nil   -- the home entry: no hotspots (A does nothing there)
    return MS_HotHide()
  end
  local r = MS_Call(MS.HOTSPOTS, ms.key)
  if type(r) ~= "table" or r.settled ~= 1 or MS_LabelCount() < 2 then
    h.active = false
    if type(r) ~= "table" then h.shot = nil end
    return MS_HotHide()
  end
  if r.shot ~= h.shot then MS_HotLoad(r) end
  h.active = h.n > 0 and layer == MS.UPPER
  local outline, hidden = nil, nil
  h.outline_on = nil
  local edge = 0
  for i = 1, h.n do
    local d = h.list[i]
    local e = r[d.src or i]
    if e.seen ~= 1 or not d.draw then
      MS_Text(i, "")                 -- not seen, or drawn by the mod (draw = false)
    else
      d.width = d.width or MS_TextWidth(i, d.text)
      -- the text's size from the rectangle's size on screen; a floor rectangle flattens it (no skew command exists:
      -- the perspective is approximated by position and a non-uniform scale)
      local sc = math.max(0.5, math.min(1.0, e.w * 0.9 / d.width, e.h * 0.8 / 40))
      local sy = sc
      if e.w > 0 and e.h < e.w * 0.45 then sy = sc * math.max(0.6, e.h / (e.w * 0.45)) end
      -- the selected one (only while the mode row has the focus): full white, a little larger, outlined; not
      -- available: faint
      local selected = h.active and i == h.sel
      local alpha = not d.available and 0.4 or (selected and 1 or MS.UNSELECTED_ALPHA)
      local grow = selected and MS.SELECTED_GROW or 1
      MS_Text(i, d.text, e.x - d.width * sc * grow / 2, e.y, sc * grow, sy * grow, alpha)
      if selected then
        if d.edge_actor ~= 0 then
          edge = d.edge_actor            -- the actor's own edge, no rectangle
        elseif d.outline_tag ~= 0 then
          h.outline_on = d.outline_tag   -- the mod's outline of the object (map tag), no rectangle
        else
          outline, hidden = e.outline, e.hidden
        end
      end
    end
  end
  if outline then MS_FrameDraw(outline, hidden) else MS_FrameHide() end
  MS_EdgeTo(edge)
  h.drawn = true
end

-- the running shot's hotspots for a mod's own drawing (draw = false): shot name, the selected one (1-based; 0 while the
-- mode row does not have the focus or no hotspot shows), its name, the count
function VRFW_MenuSceneHotspot()
  local h = ms.hot
  if not h or not h.shot or (h.n or 0) == 0 then return "", 0, "", 0 end
  local d = h.list[h.sel]
  return h.shot, h.active and h.sel or 0, d and d.name or "", h.n
end

-- the scene's screens ([[VRFW.MenuSceneScreen]]): every frame while up, the layers of each screen placed and scaled so
-- that their design area covers the screen's rectangle where this frame's camera sees it (instance 0 of each); faded
-- in while its shot is on (the camera arrived), out when the camera leaves it, hidden at 0
local function MS_ScreenHide()
  for name, st in pairs(ms.screens or {}) do
    if st.shown then
      for _, layer in ipairs(st.layers or {}) do MS_M(MS.VISIBLE, layer, 0, false) end
      st.shown, st.alpha = false, 0
      MS_Log("screen", name, "hidden")
    end
  end
end

-- the map tags: the scene's own (map_tags_on / map_tags_off) with the running shot's over them (a shot's own
-- map_tags_on / map_tags_off, CMND_VRFW_MENU_SCENE_SHOT_TAGS); a tag is sent when its state changes, and every tag again
-- with `all` (every 30 frames, in case the map's own requests set one back)
local function MS_TagFrame(all)
  local want, order = {}, {}
  for _, t in ipairs(ms.tags or {}) do
    if want[t[1]] == nil then order[#order + 1] = t[1] end
    want[t[1]] = t[2]
  end
  local r = MS_Call(MS.SHOT_TAGS, ms.key)
  local shot = type(r) == "table" and r.shot or ""
  if type(r) == "table" then
    for _, pair in ipairs({ { r.on, true }, { r.off, false } }) do
      for _, id in ipairs(type(pair[1]) == "table" and pair[1] or {}) do
        if want[id] == nil then order[#order + 1] = id end
        want[id] = pair[2]
      end
    end
  end
  -- the hotspots' outline tags: only the selected hotspot's is on
  local selected = ms.hot and ms.hot.outline_on
  for _, id in ipairs(ms.outline_tags or {}) do
    if want[id] == nil then order[#order + 1] = id end
    want[id] = id == selected
  end
  ms.tag_state = ms.tag_state or {}
  for _, id in ipairs(order) do
    if all or ms.tag_state[id] ~= want[id] then
      local ok = pcall(funcLuaCommand, MS.MAP_TAG, id, want[id])
      if ms.tag_state[id] ~= want[id] then
        MS_Log(string.format("map tag 0x%08X %s for shot %s (%s)", id % 4294967296, want[id] and "on" or "off", shot, tostring(ok)))
      end
      ms.tag_state[id] = want[id]
    end
  end
end

local function MS_ScreenFrame()
  local r = MS_Call(MS.SCREENS, ms.key)
  if type(r) ~= "table" then return MS_ScreenHide() end
  ms.screens = ms.screens or {}
  for i = 1, tonumber(r.n) or 0 do
    local e = r[i]
    local st = ms.screens[e.name]
    if not st then
      st = { alpha = 0, open = {}, shown = false, layers = e.layers }
      ms.screens[e.name] = st
    end
    local fade = tonumber(e.fade_ms) or 0
    local step = fade > 0 and (1000 / 60) / fade or 1
    local target = (e.on == 1 and e.seen == 1) and 1 or 0
    if st.alpha < target then st.alpha = math.min(target, st.alpha + step)
    elseif st.alpha > target then st.alpha = math.max(target, st.alpha - step) end
    local d = type(e.design) == "table" and e.design or { 0, 0, 1920, 1080 }
    if st.alpha > 0 and e.seen == 1 and d[3] > 0 and d[4] > 0 then
      local sx, sy = (e.x1 - e.x0) / d[3], (e.y1 - e.y0) / d[4]
      for _, layer in ipairs(e.layers) do
        if not st.open[layer] then
          st.open[layer] = true
          MS_M(MS.OPEN_LAYER, layer, 0)
        end
        MS_M(MS.SCALE, layer, sx, sy, 1, 0)
        MS_M(MS.POS, layer, e.x0 - d[1] * sx, -(e.y0 - d[2] * sy), 0, 0)
        MS_M(MS.LAYER_ALPHA, layer, 0, 0, st.alpha)
        MS_M(MS.VISIBLE, layer, 0, true)
      end
      if not st.shown then
        st.shown = true
        MS_Log(string.format("screen %s shown: %d layer(s) on x %.0f .. %.0f, y %.0f .. %.0f (scale %.3f x %.3f)", e.name,
          #e.layers, e.x0, e.x1, e.y0, e.y1, sx, sy))
      end
    elseif st.shown then
      for _, layer in ipairs(e.layers) do MS_M(MS.VISIBLE, layer, 0, false) end
      st.shown = false
      MS_Log("screen", e.name, "hidden")
    end
  end
end

-- after A on a hotspot with light_flood_seconds: a warm white quad grows from the hotspot's rectangle (seen with this
-- frame's camera, the push-in running) over the whole screen during the action's last light_flood_seconds; it stays
-- until the title leaves (its fade to black follows)
local function MS_FloodFrame()
  local f = ms.flood
  if not f or MS_FrameCount() <= MS.FLOOD_INSTANCE then return end
  local elapsed = ms.up_frames - f.start
  local begin = f.total - f.length
  if elapsed < begin then return end
  local k = f.length > 0 and math.min(1, (elapsed - begin) / f.length) or 1
  k = k * k * (3 - 2 * k)
  local cx, cy, w, h = 960, 540, 0, 0
  local r = MS_Call(MS.HOTSPOTS, ms.key, f.shot)
  local e = type(r) == "table" and r[f.index] or nil
  if type(e) == "table" and e.seen == 1 then cx, cy, w, h = e.x, e.y, e.w, e.h end
  -- from the rectangle to a little more than the screen
  local fx, fy, fw, fh = cx + (960 - cx) * k, cy + (540 - cy) * k, w + (2000 - w) * k, h + (1140 - h) * k
  local q = MS.FLOOD_INSTANCE
  if not ms.frame_open[q] then
    ms.frame_open[q] = true
    MS_M(MS.OPEN_LAYER, MS.FRAME, q)
    MS_M(MS.SPRITE, MS.FRAME, MS.FRAME_ATLAS, MS.FRAME_SQUARE, MS.FRAME_SPRITE_NODE, 0, q)
  end
  MS_M(MS.PRIM_COLOR, MS.FRAME, q, MS.FRAME_MESH, MS.FLOOD_COLOUR[1], MS.FLOOD_COLOUR[2], MS.FLOOD_COLOUR[3])
  MS_M(MS.ROTATE, MS.FRAME, 0, 0, 0, q)
  MS_M(MS.SCALE, MS.FRAME, math.max(fw, 1) / MS.FRAME_QUAD, math.max(fh, 1) / MS.FRAME_QUAD, 1, q)
  MS_M(MS.POS, MS.FRAME, fx, -fy, 0, q)
  MS_M(MS.VISIBLE, MS.FRAME, q, true)
  if not f.logged then
    f.logged = true
    MS_Log("light flood from hotspot", f.index, "over", math.floor(f.length * 1000 / 60), "ms")
  end
end

-- after A on a hotspot with open_door: once its delay is over, the map door opens with its own clip (the map's door
-- manager plays start / loop, or start2 / loop2 reversed); not a registered door: logged, the rest of the action as is
local function MS_DoorFrame()
  local d = ms.door
  if not d or d.done or ms.up_frames - d.start < d.wait then return end
  d.done = true
  local okc, registered, kind = pcall(funcLuaCommand, MS.DOOR_TYPE, d.id)
  if not okc or registered ~= true then
    MS_Log("door", d.name, string.format("0x%08X", d.id), "not opened: not a registered door of the map (",
      okc and tostring(registered) or "call failed", "): the light flood alone")
    return
  end
  local oko, res = pcall(funcLuaCommand, MS.DOOR_OPEN, d.id, true, d.reverse)
  MS_Log("door", d.name, string.format("0x%08X", d.id), "opens", d.reverse and "(reverse clips)" or "", "type",
    kind and string.format("0x%08X", kind % 4294967296) or "?", oko and tostring(res) or "call failed")
end

-- left / right on the mode row while hotspots are shown: the selection moves, the row's own move is undone
local function MS_HotMove(old, new)
  local h = ms.hot
  local n = type(GetItemButtonNum) == "function" and GetItemButtonNum(true) or 0
  local d = (n > 0) and ((new - old) % n) or (new - old)
  local dir = d == 1 and 1 or -1
  h.sel = ((h.sel - 1 + dir) % h.n) + 1
  h.restore = old
  pcall(funcLuaCommand, MS.SOUND, MS.SOUND_MOVE)
  MS_Log("hotspot", h.sel, h.list[h.sel] and h.list[h.sel].name)
end

-- A on the mode row while hotspots are shown: true = handled (the title's press then runs or not as returned)
local function MS_HotEnter()
  local h = ms.hot
  local e = h.list[h.sel]
  if not e then return false end
  if not e.available then
    pcall(funcLuaCommand, MS.SOUND, MS.BUZZER)
    MS_Log("hotspot", e.name, ":", e.action, "not available")
    return true, false
  end
  if e.action == "call" then
    -- a function of the title's Lua (a mod's: it does the rest; the title is not left)
    local fn = _G
    for part in tostring(e.call):gmatch("[^%.]+") do fn = type(fn) == "table" and fn[part] or nil end
    if type(fn) ~= "function" then
      MS_Log("hotspot", e.name, ": call", e.call, "is not a function of the title")
      return true, false
    end
    local ok, why = pcall(fn, e.name)
    MS_Log("hotspot", e.name, ": call", e.call, ok and "" or ("error " .. tostring(why)))
    return true, false
  end
  if e.action == "open_group" then
    -- the shot shows the hotspots of the group (Back: its first group again)
    h.group, h.shot = e.open_group, nil
    pcall(funcLuaCommand, MS.SOUND, MS.SOUND_MOVE)
    MS_Log("hotspot", e.name, ": group", e.open_group)
    return true, false
  end
  for _, k in ipairs({ MS.STORY_GO, MS.STORY_KIND, MS.STORY_PICK, MS.STORY_WAIT, MS.CHRONICLE_WAIT, MS.LEAVE_WHITE,
      MS.PICK_LAYER, MS.PICK_INDEX, MS.PICK_WAIT, MS.PICK_OPTION, MS.PICK_RETURN }) do
    MS_Clear(k)
  end
  if e.leave_white then
    VRFW_Param.Set(MS.LEAVE_WHITE, 1)
  end
  -- Back from what the action opens comes to the title: it opens again on this mode
  if e.back_to == "title" and ms.mode_idx ~= nil then MS_Call(MS.COME_BACK, ms.key, ms.mode_idx) end
  if e.action == "chronicle_map" then
    -- the press is the title's «Modo Crónica» (the shot's tile): title_main ends after the push-in, the Chronicle top
    -- menu then goes straight to the map
    VRFW_Param.Set(MS.CHRONICLE_WAIT, e.ms)
  elseif e.action == "menu_pick" then
    -- the press is the tile's own; title_main ends after the push-in, the next menu holding pick_layer presses the entry
    VRFW_Param.Set(MS.PICK_LAYER, e.pick_layer)
    VRFW_Param.Set(MS.PICK_INDEX, e.pick_index + 1)
    if (e.pick_option or -1) >= 0 then VRFW_Param.Set(MS.PICK_OPTION, e.pick_option + 1) end
    if e.back_to == "title" then VRFW_Param.Set(MS.PICK_RETURN, 1) end
    VRFW_Param.Set(MS.PICK_WAIT, e.ms)
  elseif e.action == "story_continue" or e.action == "story_new_game" then
    VRFW_Param.Set(MS.STORY_GO, e.ms)
    VRFW_Param.Set(MS.STORY_KIND, e.action == "story_new_game" and 2 or 1)
  else
    VRFW_Param.Set(MS.STORY_PICK, STORY_ROW[e.action] + 1)
    VRFW_Param.Set(MS.STORY_WAIT, e.ms)
  end
  if type(e.push_shot) == "string" and e.push_shot ~= "" then
    MS_Call(MS.SHOT, ms.key, e.push_shot)
  end
  if e.flood_ms > 0 then
    ms.flood = { shot = h.shot, index = e.src or h.sel, start = ms.up_frames, total = e.ms * 60 / 1000,
      length = math.min(e.flood_ms, e.ms) * 60 / 1000, logged = false }
  end
  if e.door_id ~= 0 then
    ms.door = { id = e.door_id, name = e.door, start = ms.up_frames, wait = e.door_ms * 60 / 1000, reverse = e.door_reverse,
      done = false }
  end
  MS_Log("hotspot", e.name, ":", e.action, "after", e.ms, "ms (push", tostring(e.push_shot), ", light", e.flood_ms, "ms, door",
    e.door_id ~= 0 and (e.door .. " after " .. e.door_ms .. " ms") or "none", ", leave", e.leave_white and "white" or "black", ")")
  return true, true
end

-- Optional host hook: a mod can finish its child interface under the same black
-- cover before the scene and that interface are revealed together.
function VRFW_MenuSceneCanReveal(key) return true end

local function MS_GoUp(key)
  if VRFW_MenuSceneCanReveal(key) ~= true then return false end
  local ok = MS_Call(MS.SET, "up")
  if ok ~= 1 then
    return false
  end
  ms.key, ms.phase, ms.up_frames = key, "up", 0
  MS_Call(MS.FADE, 0, 0.3)      -- the framework released its black cover at «up»: the room and the menu fade in together
  -- the bright-fade layer 1 too: a match left by its prompts fades it to black (the match_exit cover,
  -- lua/menu/_all/14_match_exit.lua) and the title return only ends the hold; the title's own fade-in that would show
  -- it is made instant over a scene, so the room stayed black behind the menu after a match
  MS_Call(MS.FADE, 0, 0.3, 1)
  local sc = MS_Call(MS.SCENE, key)
  ms.hide = type(sc) == "table" and type(sc.hide_layers) == "table" and sc.hide_layers or {}
  ms.close = type(sc) == "table" and type(sc.close_menus) == "table" and sc.close_menus or {}
  ms.hidden_set = {}
  for _, id in ipairs(ms.hide) do ms.hidden_set[id] = true end
  ms.modes = type(sc) == "table" and sc.shots_select_modes == 1
  ms.label_on = not (type(sc) == "table" and sc.mode_label == 0)
  ms.label_x = type(sc) == "table" and tonumber(sc.mode_label_x) or 64
  ms.label_y = type(sc) == "table" and tonumber(sc.mode_label_y) or 880
  ms.label_scale = type(sc) == "table" and tonumber(sc.mode_label_scale) or 0.75
  ms.mode_idx, ms.label, ms.cursor_hidden, ms.label_count = nil, nil, false, nil
  ms.frame_count, ms.frame_open, ms.frame_shown, ms.flood, ms.door = nil, {}, false, nil, nil
  ms.hot = { n = 0, list = {}, sel = 1 }
  ms.screens = {}
  MS_Clear(MS.LEAVE_WHITE)
  for _, k in ipairs({ MS.PICK_LAYER, MS.PICK_INDEX, MS.PICK_WAIT }) do MS_Clear(k) end
  ms.actions = {}
  for _, a in ipairs(type(sc) == "table" and type(sc.actions) == "table" and sc.actions or {}) do
    if type(a) == "table" and type(a.tile) == "number" then ms.actions[a.tile % 4294967296] = a end
  end
  MS_Log("opened over the map of", key, "(scene up):", #ms.hide, "layer(s) to hide,", #ms.close, "field menu(s) to close,",
    ms.modes and "the shots select the modes" or "the mode row as the game's")
  local okp, x, y, z = MS_Call(MS.CAMERA_POS)
  MS_Log("field camera anchor (the walker):", tostring(okp), tostring(x), tostring(y), tostring(z))
  MS_CloseField()
  MS_Hide()
  -- the scene's map tags (e.g. a screen unrolled): the map's tag manager exists once the map is up; set again every
  -- 30 frames (as the minimap), in case the map's own requests set one back
  ms.tags, ms.tag_state = {}, {}
  ms.outline_tags = type(sc) == "table" and type(sc.outline_tags) == "table" and sc.outline_tags or {}
  for _, pair in ipairs({ { type(sc) == "table" and sc.map_tags_on, true }, { type(sc) == "table" and sc.map_tags_off, false } }) do
    for _, tag in ipairs(type(pair[1]) == "table" and pair[1] or {}) do
      ms.tags[#ms.tags + 1] = { tag, pair[2] }
      ms.tag_state = ms.tag_state or {}
      ms.tag_state[tag] = pair[2]
      local okt = pcall(funcLuaCommand, MS.MAP_TAG, tag, pair[2])
      MS_Log(string.format("map tag 0x%08X %s (%s)", tag % 4294967296, pair[2] and "on" or "off", tostring(okt)))
    end
  end
  ms.focus, ms.home, ms.home_restore, ms.home_leave, ms.focus_wait = nil, false, nil, false, nil
  ms.home_shot = ms.modes and type(sc) == "table" and type(sc.home_shot) == "string" and sc.home_shot ~= "" and sc.home_shot or nil
  -- a return to the title after an action that declared it (return = "title") opens on the mode it left from
  local back = tonumber(MS_Call(MS.COME_BACK, key)) or -1
  if back >= 0 and VRFW_MenuSceneFocusMode(back) then
    MS_Log("opened on mode", back, "(the return of the action it left by)")
  elseif ms.home_shot then
    MS_SetHome(true, "the menu opens on it")
  end
  MS_ReportFocus()               -- the tile focused at the open
  local open_layer, open_idx = MS_Selected()
  if ms.home then
    MS_ModeFocused(-1)
  elseif open_layer == MS.UPPER and type(open_idx) == "number" then
    MS_ModeFocused(open_idx)
  end
  return true
end

local function MS_Ask()
  local state, key = MS_Call(MS.STATE)
  if type(state) ~= "string" then
    ms.asks = ms.asks + 1
    if ms.asks > MS.ASK_FRAMES then
      MS_Log("the framework did not answer: the retail main menu")
      ms.phase = "off"
    end
    return
  end
  if state == "switching" or state == "up" then
    ms.phase = "going_up"
    ms.key = key
    -- the scene's hidden layers (the title's white background) go before the menu is ever drawn
    local sc = MS_Call(MS.SCENE, key)
    ms.hide = type(sc) == "table" and type(sc.hide_layers) == "table" and sc.hide_layers or {}
    MS_Hide()
    return
  end
  if state ~= "idle" then
    MS_Fail("the main menu opened while the scene was at " .. state)
    return
  end
  MS_Clear(MS.HUD_OFF)         -- no scene up: the field HUD is the game's again
  local k = MS_Call(MS.FOR, MS.MENU)
  if type(k) ~= "string" then
    ms.asks = ms.asks + 1
    if ms.asks > MS.ASK_FRAMES then ms.phase = "off" end
    return
  end
  if k == "" then
    ms.phase = "off"
    return
  end
  if MS_Call(MS.HAS_SAVE, 1) ~= true then
    MS_Log("scene", k, "skipped: no save data (the scene loads the save first)")
    ms.phase = "off"
    return
  end
  local sc = MS_Call(MS.SCENE, k)
  ms.timeout = type(sc) == "table" and tonumber(sc.timeout_ms) and math.floor(sc.timeout_ms / 1000 * 60) or 600
  ms.key, ms.phase, ms.frames = k, "wait_ready", 0
  MS_Call(MS.FADE, 1, 0)      -- black at once: the menu is not shown before the scene
  MS_Log("scene", k, "declared for this menu: black, waiting for the menu to be ready")
end

local function MS_Step()
  if ms.phase == "off" then
    return
  end
  ms.frames = ms.frames + 1
  if ms.phase == "ask" then
    MS_Ask()
  elseif ms.phase == "wait_ready" then
    MS_Call(MS.FADE, 1, 0)
    if MS_Ready() then
      local ok = MS_Call(MS.SET, "requested", ms.key)
      if ok == 1 then
        MS_Call(MS.FADE, 1, 0)
        VRFW_Param.Set(MS.GO, 1)
        ms.phase, ms.frames = "requested", 0
        MS_Log("black: Options requested from the title (it loads the save, then the map of", ms.key, "loads)")
      elseif ok == 0 then
        MS_Fail("the framework refused the request")
      end
    elseif ms.frames > MS.READY_FRAMES then
      MS_Log("the menu was not ready within", MS.READY_FRAMES, "frames: the retail main menu this time")
      MS_Call(MS.FADE, 0, 0.3)
      ms.phase = "off"
    end
  elseif ms.phase == "requested" then
    MS_Call(MS.FADE, 1, 0)    -- stay black until the title leaves
    if not VRFW_Param.Has(MS.GO) then
      ms.phase = "handed"
      MS_Log("title_main took the request after", ms.frames, "frame(s)")
    elseif ms.frames > ms.timeout then
      MS_Fail("title_main did not take the request within " .. ms.timeout .. " frames")
    end
  elseif ms.phase == "going_up" then
    MS_Hide()
    -- Native title/menu opening animations may request their own fade-in.
    -- Keep the same cover until the child UI's reveal gate has completed.
    MS_Call(MS.FADE, 1, 0)
    -- the room shows with the menu: «up» once the menu's opening is done (its opening coroutine past its first
    -- activation), at most 5 s
    ms.wait_up = (ms.wait_up or 0) + 1
    -- the title reads requests only once its menu is fully open (fade-in, start, input on): the room and the menu then
    -- appear together
    if (not MS_Ready() or not VRFW_Param.Has(MS.TITLE_READY)) and ms.wait_up < 300 then
      return
    end
    if ms.wait_up >= 300 then MS_Log("the title did not report ready within 300 frames: up anyway") end
    if not MS_GoUp(ms.key) and ms.wait_up > 300 + MS.ASK_FRAMES then
      MS_Fail("the framework did not confirm the scene up")
    end
  elseif ms.phase == "up" then
    ms.up_frames = ms.up_frames + 1
    if ms.home_restore ~= nil then
      -- a left / right into or out of the home entry: the row's focus to the tile it keeps
      local to, leave = ms.home_restore, ms.home_leave
      ms.home_restore, ms.home_leave = nil, false
      if leave then
        MS_SetHome(false, "left / right")
        ms.focus_wait = { idx = to, last = ms.up_frames + MS.FOCUS_WAIT_FRAMES }
      end
      ms.own_move = ms.up_frames
      MS_M(MS.FOCUS_MARK, MS.UPPER, to, true)
    end
    MS_ReportFocus()
    if ms.modes then
      MS_Hide(ms.up_frames % 30 == 0)   -- every frame: the game shows the row's parts again on a focus change
      if ms.hot.restore ~= nil then
        -- a left / right between hotspots: the row's focus back on its mode
        ms.own_move = ms.up_frames
        MS_M(MS.FOCUS_MARK, MS.UPPER, ms.hot.restore, true)
        ms.hot.restore = nil
      end
      MS_ModeFrame()
      MS_HotFrame()
      MS_ScreenFrame()
      MS_DoorFrame()
      MS_FloodFrame()
    elseif ms.up_frames % 30 == 0 then
      MS_Hide(true)
    end
    MS_TagFrame(ms.up_frames % 30 == 0)
    if ms.up_frames % 30 == 0 then
      MS_CloseField()
    end
    if ms.up_frames == 60 then
      MS_Log("scene up for", ms.up_frames, "frames (", math.floor(ms.up_frames / 60), "s )")
    end
  end
end

if VRFW_Host ~= nil then
  VRFW_Host.on("title_menu_2", "OnInit", {
    id = MS.ID .. ".init",
    phase = "before",
    fn = function()
      ms.phase, ms.frames, ms.asks, ms.key, ms.hide, ms.hidden, ms.up_frames = "ask", 0, 0, nil, {}, {}, 0
      ms.counts, ms.hidden_set, ms.modes, ms.mode_idx, ms.label, ms.cursor_hidden, ms.label_count = {}, {}, false, nil, nil, false, nil
      ms.hot, ms.own_move, ms.screens = { n = 0, list = {}, sel = 1 }, false, {}
      ms.frame_count, ms.frame_open, ms.frame_shown, ms.flood, ms.door = nil, {}, false, nil, nil
      MS_Clear(MS.STORY_PICK)           -- a submenu pick never outlives the title it came from
      MS_Clear(MS.CHRONICLE_WAIT)       -- nor a Chronicle push-in
      MS_Call(MS.PENDING, "")           -- a title opened: no menu after a leave is waiting
      ms.close, ms.closed, ms.seen, ms.wait_up = {}, 0, {}, 0
      MS_Clear(MS.GO)    -- a request never outlives the title it came from
      MS_Clear(MS.OPTIONS)
      MS_Clear(MS.TITLE_READY)          -- set again by this title's title_main once it reads requests
      ms.home_shot, ms.home, ms.home_restore, ms.home_leave, ms.focus_wait = nil, false, nil, false, nil
    end,
  })
  VRFW_Host.on("title_menu_2", "Step", {
    id = MS.ID .. ".step",
    phase = "after",
    fn = function()
      local ok, err = pcall(MS_Step)
      if not ok then
        MS_Fail("error " .. tostring(err))
      end
    end,
  })
  -- the home entry: A on the hidden row does nothing (no sound, no request)
  VRFW_Host.on("title_menu_2", "OnEnter", {
    id = MS.ID .. ".home_enter",
    phase = "before",
    priority = -100,
    fn = function(a1)
      if ms.phase == "up" and ms.home and a1 == MS.UPPER then
        MS_Log("A on the home entry: nothing")
        return VRFW_Host.HALT
      end
    end,
  })
  -- a tile action of the scene (A on a mode-row tile): continue_story = straight into the story as «Continuar», after
  -- the action's push-in shot; the game's own press runs too (its sound, its request): title_main's 150_menu_scene.lua
  -- then skips the story submenu (param vrfw_menu_scene_story_continue). No story save: the game's submenu.
  -- Back while a shot shows another group of its hotspots (open_group): its first group again
  VRFW_Host.on("title_menu_2", "OnBack", {
    id = MS.ID .. ".hotspot_group_back",
    phase = "around",
    fn = function(nxt, ...)
      local h = ms.hot
      if ms.phase == "up" and h and (h.group or "") ~= "" then
        MS_Log("hotspot group", h.group, "left (Back)")
        h.group, h.shot = "", nil
        pcall(funcLuaCommand, MS.SOUND, MS.SOUND_MOVE)
        return 1
      end
      return nxt(...)
    end,
  })
  VRFW_Host.on("title_menu_2", "OnEnter", {
    id = MS.ID .. ".tile_action",
    phase = "around",
    fn = function(nxt, a1, a2, ...)
      if ms.phase == "up" and a1 == MS.UPPER and ms.hot and ms.hot.active then
        local ok, handled, press = pcall(MS_HotEnter)
        if ok and handled then
          if press then return nxt(a1, a2, ...) end
          return
        end
      end
      if ms.phase == "up" and a1 == MS.UPPER and type(GetTitleMenuItemId) == "function" and ms.actions then
        local ok, item = pcall(GetTitleMenuItemId, a2, true)
        local act = ok and type(item) == "number" and ms.actions[item % 4294967296] or nil
        MS_Clear(MS.LEAVE_WHITE)
        if act and act.leave_white == 1 then
          VRFW_Param.Set(MS.LEAVE_WHITE, 1)
        end
        if act and act.action == "chronicle_map" then
          MS_Clear(MS.CHRONICLE_WAIT)
          VRFW_Param.Set(MS.CHRONICLE_WAIT, tonumber(act.ms) or 800)
          if type(act.shot) == "string" and act.shot ~= "" then
            MS_Call(MS.SHOT, ms.key, act.shot)
          end
          MS_Log("tile action chronicle_map: push-in", tostring(act.shot), tonumber(act.ms), "ms, then the Chronicle map")
        elseif act and act.action == "continue_story" then
          local okc, has, saves = pcall(funcLuaCommand, MS.STORY_INFO)
          if okc and type(saves) == "number" and saves > 0 then
            MS_Clear(MS.STORY_GO)
            VRFW_Param.Set(MS.STORY_GO, tonumber(act.ms) or 800)
            if type(act.shot) == "string" and act.shot ~= "" then
              MS_Call(MS.SHOT, ms.key, act.shot)
            end
            MS_Log("tile action continue_story: push-in", tostring(act.shot), tonumber(act.ms), "ms, then the story («Continuar»)")
          else
            MS_Log("tile action continue_story: no story save (", tostring(saves), "): the game's story submenu")
          end
        end
      end
      return nxt(a1, a2, ...)
    end,
  })

  -- a mod's previous / next shot keys (its content\menus\ binds them: CMD_FUNCTION vrfw_menu_scene_shot_prev / _next):
  -- the previous / next shot, or with shots_select_modes the previous / next mode; up / down with the mode row hidden
  VRFW_Host.on("title_menu_2", "OnFunction", {
    id = MS.ID .. ".shot_keys",
    phase = "around",
    fn = function(nxt, a1, a2, ...)
      if a1 == MS.FOCUS_MOVE and ms.phase == "up" and ms.modes then
        local ok, done = pcall(MS_ModeUpDown, a2)
        if ok and done then return end
        return nxt(a1, a2, ...)
      end
      if a1 ~= MS.SHOT_PREV and a1 ~= MS.SHOT_NEXT then
        return nxt(a1, a2, ...)
      end
      if ms.phase == "up" and ms.modes then
        local ok, err = pcall(MS_ModeStep, a1 == MS.SHOT_PREV and -1 or 1)
        if not ok then MS_Log("mode key error:", tostring(err)) end
      elseif ms.phase == "up" then
        local shot = MS_Call(MS.SHOT_STEP, ms.key, a1 == MS.SHOT_PREV and -1 or 1)
        MS_Log("shot key", a1 == MS.SHOT_PREV and "previous" or "next", "-> shot", tostring(shot))
      end
    end,
  })
  -- the mode row's focus moved: by the framework (passed on), or by left / right while hotspots are shown (the
  -- hotspot selection moves; the title never sees the move, the row's focus goes back next frame)
  VRFW_Host.on("title_menu_2", "OnChangeFocus", {
    id = MS.ID .. ".hotspot_keys",
    phase = "around",
    fn = function(nxt, a1, ...)
      -- (a move made here is reported within a few frames; an older mark is stale)
      if ms.own_move and ms.up_frames - ms.own_move <= 5 then
        ms.own_move = false
        local r = table.pack(nxt(a1, ...))
        if ms.phase == "up" and ms.modes then MS_Hide() end
        return table.unpack(r, 1, r.n)
      end
      if ms.phase == "up" and a1 == MS.UPPER and ms.hot and ms.hot.active and ms.hot.n > 1 then
        local new = MS_M(MS.FOCUS_INDEX, MS.UPPER)
        local _, old = MS_Selected()
        if type(new) == "number" and type(old) == "number" and new ~= old then
          local ok, err = pcall(MS_HotMove, old, new)
          if ok then return end
          MS_Log("hotspot move error:", tostring(err))
        end
      end
      if ms.phase == "up" and ms.modes and ms.home_shot and a1 == MS.UPPER then
        local new = MS_M(MS.FOCUS_INDEX, MS.UPPER)
        local layer, old = MS_Selected()
        if layer == MS.UPPER and type(new) == "number" and type(old) == "number" and new ~= old then
          local ok, handled = pcall(MS_HomeMove, old, new)
          if ok and handled then return end
          if not ok then MS_Log("home move error:", tostring(handled)) end
        end
      end
      local r = table.pack(nxt(a1, ...))
      if ms.phase == "up" and ms.modes then MS_Hide() end
      return table.unpack(r, 1, r.n)
    end,
  })
  VRFW_Host.on("title_menu_2", "OnOpenLayer", {
    id = MS.ID .. ".layers",
    phase = "after",
    fn = function(r, a1, a2)
      if ms.phase ~= "up" and ms.phase ~= "going_up" then
        return
      end
      for _, id in ipairs(ms.hide) do
        if a1 == id then
          pcall(funcLuaMenuCommand, MS.VISIBLE, a1, a2 or 0, false)
        end
      end
    end,
  })
end
