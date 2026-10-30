-- menu_scene (VR-Framework): Modo Crónica straight to the Chronicle map after a menu scene's chronicle_map action
-- (docs/framework/menu-scene.md §2.2.2). title_main asked the framework to keep the action pending
-- (CMND_VRFW_MENU_SCENE_PENDING) before the leave's reset; this top menu takes it at its start
-- (CMND_VRFW_MENU_SCENE_TAKE) and, instead of showing itself, runs the retail «Cadena de Crónica» path without the
-- caravan's departure: the decision's tutorial flags cleared, then the retail ChangeVsRouteTownScene (black, the menu
-- closed, the Chronicle map reserved). Its layers stay hidden and the screen black meanwhile (as the retail skip mode,
-- global byte 3152001072 = 2, does).
-- The retail menu instead: the tutorial question not answered yet (global bit 1169930310), a Players Universe event
-- reserved, the retail skip mode, no ChangeVsRouteTownScene; or the menu still open FALLBACK_FRAMES after the skip
-- began (its layers shown again and its own opening run).
-- Back from the map: when the action's declaration says `return = "title"`, the framework answers this menu's next
-- opening with "title" (CMND_VRFW_MENU_SCENE_RETURN): its layers stay hidden, the screen black, and instead of its
-- opening the retail Back runs (its OnFunction of the back key: BackToTitle) in a coroutine resumed every Step; the
-- retail menu when that Back is not there or the menu is still open FALLBACK_FRAMES later.
-- Wraps OnInit, OnSetupLayer, OnOpenLayer and Step (no host for this script). No engine call at load time.

local CHRONICLE_SKIP = {
  LOG = VRFW_Cmd.EVT_LOG,                    -- CMND_EVT_LOG
  TAKE = VRFW_Cmd.VRFW_MENU_SCENE_TAKE,                   -- CMND_VRFW_MENU_SCENE_TAKE (action) -> 1 | 0
  RETURN = VRFW_Cmd.VRFW_MENU_SCENE_RETURN,                 -- CMND_VRFW_MENU_SCENE_RETURN (menu) -> "title" | ""
  MENU = "chronicle_mode_top_menu",
  BACK_FUNCTION = 1842266423,          -- the retail OnFunction id of the back key (BackToTitle)
  GLOBAL_BIT = VRFW_Cmd.GET_GLOBAL_BIT_FLAG,              -- CMND_GET_GLOBAL_BIT_FLAG (bit) -> set
  GLOBAL_BYTE = VRFW_Cmd.GET_GLOBAL_BYTE_FLAG,            -- CMND_GET_GLOBAL_BYTE_FLAG (byte) -> value
  TEMP_BIT = VRFW_Cmd.GET_TEMP_BIT_FLAG,               -- CMND_GET_TEMP_BIT_FLAG (bit) -> set
  TUTORIAL_ANSWERED_BIT = 1169930310,  -- the Chronicle tutorial question was answered (the retail asks it first)
  PLAYERS_UNIVERSE_EVENT_BIT = 774062760, -- a Players Universe event is reserved (the retail opens it)
  PLAYERS_UNIVERSE_BIT = 3914011134,   -- the retail goes to Players Universe at the open
  RETAIL_SKIP_BYTE = 3152001072,       -- = 2: the retail's own skip mode
  RETAIL_SKIP_VALUE = 2,
  TUTORIAL_FOCUS_PARAM = 2565779025,   -- (207055258, 0): the decision's tutorial focus cleared
  TUTORIAL_FOCUS_KEY = 207055258,
  TEMP_BYTE_SET = VRFW_Cmd.SET_TEMP_BYTE_FLAG,           -- CMND_SET_TEMP_BYTE_FLAG (2502072435, 0)
  TUTORIAL_TEMP_BYTE = 2502072435,
  FADE = 609722083,                    -- (1 to black | 0 in, seconds)
  VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE,                 -- CMND_SET_LAYER_VISIBLE (layer, instance, on)
  BACKGROUND = 117665605,              -- vsroute04_03_chronicle_top_bg: its open starts the retail opening
  -- layers the retail itself shows or hides at its setup (left as the retail set them on a fallback)
  RETAIL_VISIBILITY = { [485095068] = true, [594583106] = true, [2279382105] = true },
  FALLBACK_FRAMES = 600,               -- the menu still open this long after the skip began: the retail menu
}

local chronicle_skip = { on = false, started = false, frames = 0, hidden = {}, back = false, co = nil }

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
  chronicle_skip.back, chronicle_skip.co = false, nil
  if ChronicleSkipCall(CHRONICLE_SKIP.TAKE, "chronicle_map") ~= 1 then
    -- opening again after the map: Back straight to the title when the action asked for it
    if ChronicleSkipCall(CHRONICLE_SKIP.RETURN, CHRONICLE_SKIP.MENU) == "title" then
      if type(OnFunction) ~= "function" then
        ChronicleSkipLog("chronicle map: back to the title asked, no OnFunction: the top menu is shown")
        return
      end
      chronicle_skip.on, chronicle_skip.back = true, true
      ChronicleSkipLog("chronicle map: back from the map, straight to the title")
    end
    return
  end
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

-- the background's open, back from the map: the retail Back (BackToTitle yields: a coroutine resumed every Step)
local function ChronicleBackStart()
  chronicle_skip.started = true
  ChronicleSkipCall(CHRONICLE_SKIP.FADE, 1, 0)
  chronicle_skip.co = coroutine.create(function() OnFunction(CHRONICLE_SKIP.BACK_FUNCTION, 0) end)
  ChronicleSkipLog("chronicle map: the retail Back to the title started")
  return true
end

local function ChronicleBackStep()
  local co = chronicle_skip.co
  if not co or coroutine.status(co) == "dead" then return end
  local ok, err = coroutine.resume(co)
  if not ok then
    chronicle_skip.co = nil
    ChronicleSkipLog("chronicle map: Back to the title error:", tostring(err))
  end
end

-- the background's open: instead of the retail opening (caravan, fade-in, input), the «Cadena de Crónica» path
local function ChronicleSkipStart()
  if chronicle_skip.back then return ChronicleBackStart() end
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
    chronicle_skip.on, chronicle_skip.back, chronicle_skip.co = false, false, nil
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
        if chronicle_skip.back then
          local ok, err = pcall(ChronicleBackStep)
          if not ok then ChronicleSkipLog("chronicle map: Back step error:", tostring(err)) end
        end
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
