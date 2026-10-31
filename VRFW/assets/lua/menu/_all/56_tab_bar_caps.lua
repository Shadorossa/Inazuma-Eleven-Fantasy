-- menu_engine: tab bar end-cap prompts, VRFW_TabBarCaps (VR-Framework base feature).
-- A series tab bar (blue band, dark-grey cap at each end) can show a key prompt in each cap: the left one (L2, LB, ...)
-- in the left cap, the right one in the right cap, each centred in its cap. Definitions only (this file runs in every
-- script VM, lua\_all). No engine call at load time.
--
-- The prompts are two instances of a change-page plate layer the screen's menu patch adds (retail object
-- team00_40_change_page_guide, count = 2, instance 0 = left, 1 = right): the plate's grey base is hidden and only its
-- key glyph shows (the engine draws the button of the device in use). Use:
--
--   local caps = VRFW_TabBarCaps.New()                       -- one state per screen open (reset it in OnInit)
--   local spec = {
--     Layer = <hash of the 2-instance plate layer>,
--     Slots = {Layer = <tab item layer hash>, First = 0, Last = <index of the last tab shown>},  -- the bar's tab slots
--     -- or Measure = function() return centre_x_of_first_tab, centre_x_of_last_tab, centre_y end  (screen px)
--     LeftText = "<CMD_FUNCL2>", RightText = "<CMD_FUNCR2>",   -- optional (these are the defaults)
--     CapOffset = 430.5, CapWidth = 139,                       -- optional: the bar sprite's cap centre from the bar's
--                                                              -- centre, and the cap's width (retail 10-tab bar)
--     EdgeInset = 4,                                           -- optional: px between the cap's outer edge and the
--                                                              -- glyph's outer edge (prompts hug the bar's ends);
--                                                              -- absent = glyph centred in its cap
--     ScreenLeft = 0,                                          -- optional: screen x of the visible left edge; the left
--                                                              -- glyph is kept inside it (bar's left cap cut there)
--     Symmetric = true,                                        -- optional: the right glyph mirrors the left one about
--                                                              -- the bar's centre (after the ScreenLeft clamp)
--     Priority = 700,                                          -- optional draw priority
--   }
--   VRFW_TabBarCaps.Open(caps, spec)    -- when the prompts are wanted (e.g. more than one page): opens the instances
--   VRFW_TabBarCaps.Step(caps, spec)    -- from the screen's Step while caps.pending: places them once the layer is up,
--                                       -- again until the bar stops moving after it opens; pending ends by itself
--   VRFW_TabBarCaps.Hide(caps, spec)    -- hides both (the state stays opened)
--
-- Geometry: the bar is centred between the first and last tab's centre (read with CMND_GET_MESH_GLOBAL_POSITION of the
-- tab item's _pos_base01, its centre; the left edge of its _icon_base01 + (46, -26) if that fails), the caps at
-- centre -/+ CapOffset. The change-page plate is right-anchored, so its origin is the glyph's centre + 102 * scale. A
-- cap narrower than the 48 px glyph scales the glyph down to fit (Scale = min(1, (CapWidth + 6) / 48)).
-- The bar sprites (cap centre / width in px from the bar's centre, measured on the sprites): retail list_tab_base01
-- 430.5 / 139 (the default); BetterMenu's competition bar 485 / 30.
if VRFW_TabBarCaps == nil then
  local T = {
    EXIST = VRFW_Cmd.IS_EXIST_LAYER,
    OPEN = VRFW_Cmd.OPEN_LAYER,
    IS_OPEN = VRFW_Cmd.IS_OPEN_LAYER,
    LOADING = VRFW_Cmd.IS_LOADING_LAYER,
    LAYER_VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE,
    MESH_VISIBLE = VRFW_Cmd.SET_MESH_VISIBLE,
    SET_TEXT = VRFW_Cmd.SET_MENU_TEXT_STRING,
    TEXT_PLATE = VRFW_Cmd.UPDATE_TEXT_PLATE,       -- (layer, instance, text node)
    PRIORITY = VRFW_Cmd.SET_DRAW_PRIORITY,         -- (layer, instance, priority, children)
    LOCAL_POS = VRFW_Cmd.SET_LAYER_LOCAL_POS,      -- (layer, x, y, z, instance)
    LOCAL_SCALE = VRFW_Cmd.SET_LAYER_LOCAL_SCALE,  -- (layer, sx, sy, sz, instance)
    MESH_POS = VRFW_Cmd.GET_MESH_GLOBAL_POSITION,  -- (layer, instance, mesh) -> x, y (screen px, y up)
    LOG = VRFW_Cmd.EVT_LOG,
    TEXT_NODE = 378156699,        -- _text_guide01
    BUTTON_NODE = 950238781,      -- _text_btn01
    PLATE_BASE = 3491851413,      -- _win_guide_base01
    SLOT_CENTRE = 1517329426,     -- _pos_base01 (the tab item's centre)
    SLOT_CORNER = 4013273506,     -- _icon_base01 (the tab plate's top-left corner)
    CORNER_DX = 46, CORNER_DY = -26,   -- the plate's centre from that corner (92 x 52 plate, y up)
    TEXT_CX = 102,                -- the plate's origin to its glyph's centre, at scale 1
    GLYPH_W = 48,
    DEFAULT_LEFT = "<CMD_FUNCL2>", DEFAULT_RIGHT = "<CMD_FUNCR2>",
    DEFAULT_OFFSET = 430.5, DEFAULT_WIDTH = 139,
    DEFAULT_PRIORITY = 700,
    TRIES = 300,                  -- Step calls the placement waits for the layer at most
    logs = 0,
  }
  VRFW_TabBarCaps = T

  local function log(...)
    if T.logs >= 10 then
      return
    end
    T.logs = T.logs + 1
    local parts = {}
    for i = 1, select("#", ...) do
      parts[#parts + 1] = tostring((select(i, ...)))
    end
    pcall(funcLuaCommand, T.LOG, "VRFW tab_bar_caps " .. table.concat(parts, " "))
  end

  local function mesh(...)
    local ok, x, y = pcall(funcLuaMenuCommand, T.MESH_POS, ...)
    if ok and type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then
      return x, y
    end
    return nil
  end

  -- the centre of one tab slot on screen
  local function slot_centre(layer, slot)
    local x, y = mesh(layer, slot, T.SLOT_CENTRE)
    if x ~= nil then
      return x, y
    end
    x, y = mesh(layer, slot, T.SLOT_CORNER)
    if x ~= nil then
      return x + T.CORNER_DX, y + T.CORNER_DY
    end
    return nil
  end

  -- first tab centre x, last tab centre x, centre y; nil while the bar is not measurable yet
  local function measure(spec)
    if type(spec.Measure) == "function" then
      local ok, a, b, c = pcall(spec.Measure)
      if ok and type(a) == "number" and type(b) == "number" and type(c) == "number" then
        return a, b, c
      end
      return nil
    end
    local s = spec.Slots
    if type(s) ~= "table" then
      return nil
    end
    local xf, y = slot_centre(s.Layer, s.First or 0)
    local xl = slot_centre(s.Layer, s.Last)
    if xf == nil or xl == nil then
      return nil
    end
    return xf, xl, y
  end

  function T.New()
    return {opened = false, pending = false, tries = 0, set = false}
  end

  function T.Open(state, spec)
    if state.opened then
      return
    end
    state.opened = true
    local ok, exist = pcall(funcLuaMenuCommand, T.EXIST, spec.Layer)
    if not ok or exist ~= true then
      log("no cap prompt layer")
      return
    end
    for i = 0, 1 do
      pcall(funcLuaMenuCommand, T.OPEN, spec.Layer, i)
    end
    state.pending, state.tries = true, 0
  end

  function T.Hide(state, spec)
    state.pending = false
    if state.set then
      for i = 0, 1 do
        pcall(funcLuaMenuCommand, T.LAYER_VISIBLE, spec.Layer, i, false)
      end
      state.set, state.at = false, nil
    end
  end

  function T.Step(state, spec)
    if not state.pending then
      return
    end
    state.tries = state.tries + 1
    if state.tries > T.TRIES then
      state.pending = false
      log("cap prompts not placed")
      return
    end
    for i = 0, 1 do
      local ok, open = pcall(funcLuaMenuCommand, T.IS_OPEN, spec.Layer, i)
      if not ok or open ~= true then
        return
      end
    end
    local okl, loading = pcall(funcLuaMenuCommand, T.LOADING, spec.Layer)
    if okl and loading == true then
      return
    end
    local xf, xl, y = measure(spec)
    if xf == nil then
      return
    end
    local offset = tonumber(spec.CapOffset) or T.DEFAULT_OFFSET
    local width = tonumber(spec.CapWidth) or T.DEFAULT_WIDTH
    local scale = math.min(1, (width + 6) / T.GLYPH_W)
    local centre = (xf + xl) / 2
    local at = {centre - offset, centre + offset}
    local inset = tonumber(spec.EdgeInset)
    if inset ~= nil then
      -- glyph centre = the cap's outer edge pulled in by the inset and half the (scaled) glyph
      local pull = width / 2 - inset - T.GLYPH_W * scale / 2
      at = {centre - offset - pull, centre + offset + pull}
    end
    local screen_left = tonumber(spec.ScreenLeft)
    if screen_left ~= nil then
      -- a bar that starts left of the screen edge (the free-match bar's left cap is cut there): the left glyph keeps
      -- its outer edge the same inset inside the visible edge, so it stays on screen
      local least = screen_left + (inset or 0) + T.GLYPH_W * scale / 2
      if at[1] < least then
        at[1] = least
      end
    end
    if spec.Symmetric == true then
      at[2] = 2 * centre - at[1]
    end
    if state.at ~= nil and math.abs(state.at[1] - at[1]) < 0.5 and math.abs(state.at[2] - at[2]) < 0.5
        and math.abs(state.y - y) < 0.5 then
      state.pending = false      -- the bar stopped moving (its open animation is over)
      return
    end
    state.at, state.y = at, y
    local texts = {spec.LeftText or T.DEFAULT_LEFT, spec.RightText or T.DEFAULT_RIGHT}
    for i = 0, 1 do
      if not state.set then
        funcLuaMenuCommand(T.LAYER_VISIBLE, spec.Layer, i, true)
        funcLuaMenuCommand(T.MESH_VISIBLE, spec.Layer, T.PLATE_BASE, false, i)
        funcLuaMenuCommand(T.SET_TEXT, spec.Layer, T.BUTTON_NODE, "", i)
        funcLuaMenuCommand(T.SET_TEXT, spec.Layer, T.TEXT_NODE, texts[i + 1], i)
        funcLuaMenuCommand(T.TEXT_PLATE, spec.Layer, i, T.TEXT_NODE)
        funcLuaMenuCommand(T.PRIORITY, spec.Layer, i, tonumber(spec.Priority) or T.DEFAULT_PRIORITY, true)
        funcLuaMenuCommand(T.LOCAL_SCALE, spec.Layer, scale, scale, 1, i)
      end
      -- the plate is right-anchored: its origin sits TEXT_CX (scaled) right of the glyph's centre
      funcLuaMenuCommand(T.LOCAL_POS, spec.Layer, at[i + 1] + T.TEXT_CX * scale, y, 0, i)
    end
    if not state.set then
      state.set = true
      log("cap prompts at", math.floor(at[1]), math.floor(at[2]), math.floor(y), "scale", scale)
    end
  end
end
