-- Play the Chronicle / Grand Finale movie on the Battle Bay clubhouse projector.
-- The generated atlas is a 10 fps flipbook; the screen layer is fitted to the projector by
-- VRFW.MenuSceneScreen and the camera shot is focused on the tactical board.
BetterMenu = type(BetterMenu) == "table" and BetterMenu or {}
if BetterMenu.BBOpening == nil then
  local function Crc(s)
    local crc = 0xFFFFFFFF
    for i = 1, #s do
      crc = bit32.bxor(crc, string.byte(s, i))
      for _ = 1, 8 do
        if bit32.band(crc, 1) ~= 0 then
          crc = bit32.bxor(bit32.rshift(crc, 1), 0xEDB88320)
        else
          crc = bit32.rshift(crc, 1)
        end
      end
    end
    return bit32.bxor(crc, 0xFFFFFFFF)
  end

  local Opening = {
    ID = "better_menu.bb_opening",
    LOG = Crc("CMND_EVT_LOG"),
    LAYER = Crc("better_menu_bb_projection"),
    ATLAS = Crc("#/menu/20_cmn/cmn01/better_menu_bb_projection/better_menu_bb_projection.g4tx"),
    SLOT = Crc("icon_new01"),
    FRAME_PREFIX = "better_menu_bb_opening_",
    FRAMES = 823, -- the Chronicle / Grand Finale opening at 7.5 fps (one 4096 x 4096 atlas of 192 x 96 frames), looped
    FRAME_STEPS = 8,                -- game frames per flipbook frame (60 / 7.5)
    SCREEN = "battle_bay_projection",
    SPRITE = 558735651,
    LAYER_NUM = 1175615627,
    SCREENS = Crc("CMND_VRFW_MENU_SCENE_SCREENS"),
    SCENE_FOR = Crc("CMND_VRFW_MENU_SCENE_FOR"),
    PARAM_HAS = 2947612279,
  }
  local state = { has_layer = nil, key = nil, steps = 0, frame = -1, playing = false, sprites = nil }

  local function Log(...)
    pcall(funcLuaCommand, Opening.LOG, "better_menu", "bb_opening", ...)
  end

  local function M(...)
    local r = table.pack(pcall(funcLuaMenuCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end

  local function F(...)
    local r = table.pack(pcall(funcLuaCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end

  local function HasLayer()
    if state.has_layer == nil then
      local n = M(Opening.LAYER_NUM, Opening.LAYER)
      state.has_layer = type(n) == "number" and n > 0
      if not state.has_layer then Log("no layer better_menu_bb_projection in this menu") end
    end
    return state.has_layer
  end

  local function ScreenActive()
    if state.key == nil then
      local k = F(Opening.SCENE_FOR, "title_menu_2")
      state.key = type(k) == "string" and k or ""
    end
    if state.key == "" then return false end
    local r = F(Opening.SCREENS, state.key)
    if type(r) ~= "table" then return false end
    for i = 1, tonumber(r.n) or 0 do
      local e = r[i]
      if type(e) == "table" and e.name == Opening.SCREEN then
        if e.on == 1 then state.off_steps = 0 return true end
        state.off_steps = (state.off_steps or 0) + Opening.FRAME_STEPS
        return state.off_steps * 1000 / 60 <= (tonumber(e.fade_ms) or 0)
      end
    end
    return false
  end

  local function Step()
    if not (type(VRFW_MenuSceneIsUp) == "function" and VRFW_MenuSceneIsUp()) or not HasLayer() then return end
    state.steps = state.steps + 1
    if state.steps % Opening.FRAME_STEPS ~= 0 then return end
    local active = ScreenActive()
    if active ~= state.playing then
      state.playing = active
      Log(active and "playing" or "stopped", "frame", state.frame)
    end
    if not active then return end
    if state.sprites == nil then
      state.sprites = {}
      for i = 0, Opening.FRAMES - 1 do
        state.sprites[i] = Crc(string.format("%s%03d", Opening.FRAME_PREFIX, i))
      end
    end
    state.frame = (state.frame + 1) % Opening.FRAMES
    M(Opening.SPRITE, Opening.LAYER, Opening.ATLAS, state.sprites[state.frame], Opening.SLOT, 0, 0)
  end

  BetterMenu.BBOpening = { Step = Step }

  if VRFW_Host ~= nil then
    VRFW_Host.on("title_menu_2", "OnInit", {
      id = Opening.ID .. ".init",
      phase = "before",
      fn = function()
        state.has_layer, state.key, state.steps, state.frame, state.playing, state.off_steps = nil, nil, 0, -1, false, 0
      end,
    })
    VRFW_Host.on("title_menu_2", "Step", {
      id = Opening.ID .. ".step",
      phase = "after",
      priority = 10,
      fn = function()
        local ok, err = pcall(Step)
        if not ok then Log("error", tostring(err)) end
      end,
    })
  end
end
