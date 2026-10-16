-- menu_scene (VR-Framework): Modo Crónica straight to the Chronicle map after a menu scene's chronicle_map action
-- (docs/framework/menu-scene.md §2.2.2). title_main asked the framework to keep the action pending
-- (CMND_VRFW_MENU_SCENE_PENDING) before the leave's reset; this top menu takes it at its start
-- (CMND_VRFW_MENU_SCENE_TAKE) and, instead of showing itself, runs the retail «Cadena de Crónica» path without the
-- caravan's departure: the decision's tutorial flags cleared, then the retail ChangeVsRouteTownScene (black, the menu
-- closed, the Chronicle map reserved). Its layers stay hidden and the screen black meanwhile (as the retail skip mode,
-- global byte 3152001072 = 2, does).
-- The retail menu instead: the tutorial question not answered yet (global bit 1169930310), a Players Universe event
-- reserved, the retail skip mode, no ChangeVsRouteTownScene; or the menu still open FALLBACK_FRAMES after the skip
-- began (its layers shown again and its own opening run). Wraps OnInit, OnSetupLayer, OnOpenLayer and Step (no host for
-- this script). No engine call at load time.

local CHRONICLE_SKIP = {
  LOG = 3661580131,                    -- CMND_EVT_LOG
  TAKE = 3945440440,                   -- CMND_VRFW_MENU_SCENE_TAKE (action) -> 1 | 0
  GLOBAL_BIT = 941426960,              -- CMND_GET_GLOBAL_BIT_FLAG (bit) -> set
  GLOBAL_BYTE = 2769028935,            -- CMND_GET_GLOBAL_BYTE_FLAG (byte) -> value
  TEMP_BIT = 2283097588,               -- CMND_GET_TEMP_BIT_FLAG (bit) -> set
  TUTORIAL_ANSWERED_BIT = 1169930310,  -- the Chronicle tutorial question was answered (the retail asks it first)
  PLAYERS_UNIVERSE_EVENT_BIT = 774062760, -- a Players Universe event is reserved (the retail opens it)
  PLAYERS_UNIVERSE_BIT = 3914011134,   -- the retail goes to Players Universe at the open
  RETAIL_SKIP_BYTE = 3152001072,       -- = 2: the retail's own skip mode
  RETAIL_SKIP_VALUE = 2,
  TUTORIAL_FOCUS_PARAM = 2565779025,   -- (207055258, 0): the decision's tutorial focus cleared
  TUTORIAL_FOCUS_KEY = 207055258,
  TEMP_BYTE_SET = 667984508,           -- CMND_SET_TEMP_BYTE_FLAG (2502072435, 0)
  TUTORIAL_TEMP_BYTE = 2502072435,
  FADE = 609722083,                    -- (1 to black | 0 in, seconds)
  VISIBLE = 711242136,                 -- CMND_SET_LAYER_VISIBLE (layer, instance, on)
  BACKGROUND = 117665605,              -- vsroute04_03_chronicle_top_bg: its open starts the retail opening
  -- layers the retail itself shows or hides at its setup (left as the retail set them on a fallback)
  RETAIL_VISIBILITY = { [485095068] = true, [594583106] = true, [2279382105] = true },
  FALLBACK_FRAMES = 600,               -- the menu still open this long after the skip began: the retail menu
}

local chronicle_skip = { on = false, started = false, frames = 0, hidden = {} }

local function ChronicleSkipLog(...)
  pcall(funcLuaCommand, CHRONICLE_SKIP.LOG, "menu_scene", "chronicle_mode_top_menu", ...)
end

local function ChronicleSkipCall(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then return nil end
  return table.unpack(r, 2, r.n)
end

-- at OnInit: the pending action taken, and whether the skip may run
local function ChronicleSkipDecide()
  chronicle_skip.on, chronicle_skip.started, chronicle_skip.frames, chronicle_skip.hidden = false, false, 0, {}
  if ChronicleSkipCall(CHRONICLE_SKIP.TAKE, "chronicle_map") ~= 1 then return end
  local why = nil
  if type(ChangeVsRouteTownScene) ~= "function" then
    why = "no ChangeVsRouteTownScene"
  elseif ChronicleSkipCall(CHRONICLE_SKIP.GLOBAL_BYTE, CHRONICLE_SKIP.RETAIL_SKIP_BYTE) == CHRONICLE_SKIP.RETAIL_SKIP_VALUE then
    why = "the retail skip mode runs"
  elseif ChronicleSkipCall(CHRONICLE_SKIP.GLOBAL_BIT, CHRONICLE_SKIP.TUTORIAL_ANSWERED_BIT) ~= true then
    why = "the tutorial question is not answered yet"
  elseif ChronicleSkipCall(CHRONICLE_SKIP.TEMP_BIT, CHRONICLE_SKIP.PLAYERS_UNIVERSE_EVENT_BIT) == true
      or ChronicleSkipCall(CHRONICLE_SKIP.TEMP_BIT, CHRONICLE_SKIP.PLAYERS_UNIVERSE_BIT) == true then
    why = "Players Universe is reserved"
  end
  if why then
    ChronicleSkipLog("chronicle map: the top menu is shown (", why, ")")
    return
  end
  chronicle_skip.on = true
  ChronicleSkipLog("chronicle map: the top menu is skipped")
end

-- the background's open: instead of the retail opening (caravan, fade-in, input), the «Cadena de Crónica» path
local function ChronicleSkipStart()
  chronicle_skip.started = true
  ChronicleSkipCall(CHRONICLE_SKIP.FADE, 1, 0)
  ChronicleSkipCall(CHRONICLE_SKIP.TUTORIAL_FOCUS_PARAM, CHRONICLE_SKIP.TUTORIAL_FOCUS_KEY, 0)
  ChronicleSkipCall(CHRONICLE_SKIP.TEMP_BYTE_SET, CHRONICLE_SKIP.TUTORIAL_TEMP_BYTE, 0)
  local ok, err = pcall(ChangeVsRouteTownScene)
  ChronicleSkipLog("chronicle map: «Cadena de Crónica» path started (", tostring(ok), ok and "" or tostring(err), ")")
  return ok
end

if type(OnInit) == "function" and type(OnOpenLayer) == "function" then
  local on_init_before = OnInit
  OnInit = function(...)
    local r = table.pack(on_init_before(...))
    local ok, err = pcall(ChronicleSkipDecide)
    if not ok then
      chronicle_skip.on = false
      ChronicleSkipLog("chronicle map error:", tostring(err), ": the top menu is shown")
    end
    return table.unpack(r, 1, r.n)
  end

  local open_layer_before = OnOpenLayer
  local fallback                       -- (defined below)
  OnOpenLayer = function(a1, a2, ...)
    if chronicle_skip.on and not chronicle_skip.started and a1 == CHRONICLE_SKIP.BACKGROUND then
      local ok, started = pcall(ChronicleSkipStart)
      if ok and started then return end
      fallback("the «Cadena de Crónica» path did not start")
      return
    end
    return open_layer_before(a1, a2, ...)
  end

  -- the retail menu after all: its layers shown again, its own opening (caravan, fade-in, input)
  fallback = function(why)
    chronicle_skip.on = false
    ChronicleSkipLog("chronicle map:", why, ": the top menu is shown")
    for _, layer in ipairs(chronicle_skip.hidden) do
      pcall(funcLuaMenuCommand, CHRONICLE_SKIP.VISIBLE, layer[1], layer[2], true)
    end
    chronicle_skip.hidden = {}
    local ok, err = pcall(open_layer_before, CHRONICLE_SKIP.BACKGROUND, 0)
    if not ok then ChronicleSkipLog("chronicle map: retail opening error:", tostring(err)) end
  end

  if type(OnSetupLayer) == "function" then
    local setup_layer_before = OnSetupLayer
    OnSetupLayer = function(a1, a2, ...)
      local r = table.pack(setup_layer_before(a1, a2, ...))
      if chronicle_skip.on and r[1] == nil and not CHRONICLE_SKIP.RETAIL_VISIBILITY[a1] then
        pcall(funcLuaMenuCommand, CHRONICLE_SKIP.VISIBLE, a1, a2 or 0, false)
        chronicle_skip.hidden[#chronicle_skip.hidden + 1] = { a1, a2 or 0 }
      end
      return table.unpack(r, 1, r.n)
    end
  end

  if type(Step) == "function" then
    local step_before = Step
    Step = function(...)
      local r = table.pack(step_before(...))
      if chronicle_skip.on and chronicle_skip.started then
        chronicle_skip.frames = chronicle_skip.frames + 1
        if chronicle_skip.frames > CHRONICLE_SKIP.FALLBACK_FRAMES then
          local ok, err = pcall(fallback, "still open " .. CHRONICLE_SKIP.FALLBACK_FRAMES .. " frames after the skip began")
          if not ok then ChronicleSkipLog("chronicle map fallback error:", tostring(err)) end
        end
      end
      return table.unpack(r, 1, r.n)
    end
  end
end
