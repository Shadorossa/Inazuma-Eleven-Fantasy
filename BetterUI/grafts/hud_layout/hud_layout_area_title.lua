-- EVT hud_layout, soccer_area_title_menu (docs/game/ui-redesign.md §11.1z5): the big orange state banner under the
-- TENSION block (layer soccer00_14_area_title, sprite _mode_title01 456x76: «FOCO» / «DISPUTA» / «ÁREA»; SetupAreaTitle
-- (type) picks title_focus01 / title_scramble01 / title_zone01, all drawn on the same grid).
-- * FOCO (1) / DISPUTA (2): drawn at the size of the small «ZONA DE ÁREA» banner of soccer_inplay_menu
--   (soccer00_15_zone_area_title, 268x52): same text height, bar thickness, text left edge and bar bottom. Measured on
--   the es sprites (rows of the 456x76 / 268x52 images):
--     FOCO: text rows 21..68 (48 high), bar rows 50..73 (24 thick), text from column 86; mesh top-left (-31, -143)
--     ZONA DE ÁREA: text rows 19..47 (29 high), bar rows 36..50 (15 thick), text from column 30; mesh top-left (-1, -146)
--   The layer is scaled around its origin (both layers anchor top-left, layout y up) and moved so that FOCO's text
--   left edge (x 55) and bar bottom (y -217) land on ZONA DE ÁREA's (29, -197). «BAJA VELOCIDAD» scales with it.
-- * Zone (3, the shot zone): ui_clean_hud (area_title.lua, flag zone_hud) hides the big «ÁREA». Nacho wants the
--   «ZONA DE ÁREA» banner there instead: the sprite becomes title_zonearea01 of soccer00_15's atlas and the layer is
--   scaled (268/456, 52/76) and moved so the mesh lands exactly on soccer00_15's mesh. ui_clean's zone_hud hide is
--   switched off in THIS menu's VM only (EVT_UI_FLAGS is per menu) while EVT_HL_ZONE_TITLE is on.
-- Engine calls only from OnSetupLayer / OnOpenLayer / SetupAreaTitle.

EVT_HL_AREA_TITLE_ON = true
EVT_HL_AREA_TITLE_SCALE = 0.61    -- ZONA / FOCO: text 29 / 48 = 0.60, bar 15 / 24 = 0.63
EVT_HL_AREA_TITLE_DX = 0          -- fine tuning after the alignment (layout units, + = right)
EVT_HL_AREA_TITLE_DY = 0          -- (+ = up)
EVT_HL_ZONE_TITLE = true          -- zone: show «ZONA DE ÁREA» (false: ui_clean's behaviour, nothing)

local HLA_LAYER = 2169865486 --[[soccer00_14_area_title]]
local HLA_FOCO_TEXT_LEFT, HLA_FOCO_BAR_BOTTOM = -31 + 86, -143 - 74
local HLA_ZONE_TEXT_LEFT, HLA_ZONE_BAR_BOTTOM = -1 + 30, -146 - 51
local HLA_MESH_X, HLA_MESH_Y, HLA_MESH_W, HLA_MESH_H = -31, -143, 456, 76    -- _mode_title01
local HLA_ZMESH_X, HLA_ZMESH_Y, HLA_ZMESH_W, HLA_ZMESH_H = -1, -146, 268, 52 -- soccer00_15 _zonearea_title01
local HLA_ZONE_TYPE = 3
local HLA_CMND_POS = 1389957207 --[[CMND_SET_LAYER_LOCAL_POS]]
local HLA_CMND_SCALE = 3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]]
local HLA_CMND_SWAP = 558735651
local HLA_ATLAS_15 = 1215532632 --[[#/menu/00_soccer/soccer00/soccer00_15/<LG>/soccer00_15.g4tx]]
local HLA_ZONE_SPRITE = 437059094 --[[title_zonearea01]]
local HLA_SLOT = 2491981732 --[[title_focus01: slot of _mode_title01]]
local hla_type = 0
local hla_sx, hla_sy = 1, 1       -- layer scale applied by HLA_Apply (1 = retail)

if EVT_HL_ZONE_TITLE and type(rawget(_ENV, "EVT_UI_FLAGS")) == "table" then
  EVT_UI_FLAGS.zone_hud = false
end

local function HLA_Pack(...)
  return {n = select("#", ...), ...}
end

local function HLA_Apply()
  if not EVT_HL_AREA_TITLE_ON or type(funcLuaMenuCommand) ~= "function" then
    return
  end
  local sx, sy, x, y
  if hla_type == HLA_ZONE_TYPE and EVT_HL_ZONE_TITLE then
    sx, sy = HLA_ZMESH_W / HLA_MESH_W, HLA_ZMESH_H / HLA_MESH_H
    x = HLA_ZMESH_X - sx * HLA_MESH_X
    y = HLA_ZMESH_Y - sy * HLA_MESH_Y
    pcall(funcLuaMenuCommand, HLA_CMND_SWAP, HLA_LAYER, HLA_ATLAS_15, HLA_ZONE_SPRITE, HLA_SLOT, 0, 0)
  else
    sx = EVT_HL_AREA_TITLE_SCALE
    sy = sx
    x = HLA_ZONE_TEXT_LEFT - sx * HLA_FOCO_TEXT_LEFT + EVT_HL_AREA_TITLE_DX
    y = HLA_ZONE_BAR_BOTTOM - sy * HLA_FOCO_BAR_BOTTOM + EVT_HL_AREA_TITLE_DY
  end
  pcall(funcLuaMenuCommand, HLA_CMND_SCALE, HLA_LAYER, sx, sy, 1, 0)
  pcall(funcLuaMenuCommand, HLA_CMND_POS, HLA_LAYER, x, y, 0, 0)
  hla_sx, hla_sy = sx, sy
end

local function HLA_Wrap(name, onlyLayer, setsType)
  local prev = rawget(_ENV, name)
  if type(prev) ~= "function" then
    return
  end
  rawset(_ENV, name, function(a1, ...)
    if setsType then
      hla_type = type(a1) == "number" and a1 or 0
    end
    local r = HLA_Pack(prev(a1, ...))
    if not onlyLayer or a1 == HLA_LAYER then
      pcall(HLA_Apply)
    end
    return table.unpack(r, 1, r.n)
  end)
end

HLA_Wrap("OnSetupLayer", true, false)
HLA_Wrap("OnOpenLayer", true, false)
HLA_Wrap("SetupAreaTitle", false, true)

-- * Time line (clean_hud 1.8.0): a thin line right under the banner's bar that shrinks from right to left as
--   the state's time runs out (the stopwatch's meaning as a bar). Same left edge and width as the banner's bar, drawn
--   on the banner's spare quad `_speed01` («BAJA VELOCIDAD», always hidden by SetupAreaTitle) of this same layer, so
--   it hides, fades and slides with the banner. Node scale = quad size, node translation = its top-left (parent
--   _pos_title, at y -14).
--   2026-10-07: blue with the banner bar's horizontal gradient (light left, deep right), a slanted right end like the
--   bar's hatch, 5 units thick, 1 unit under the bar. Sprite evt_hl_timeline01 of clean_hud's own atlas
--   evt_hl_timeline.g4tx (research/scripts/clean_hud_zone_timeline_build.py; 264 x 8 units, opaque rows 3..12 of 16,
--   the slanted end's top corner at x 262; gradient over the last 167 = 0.65 x 257 units), loaded here (CMND_LOAD_MENU_RES_TEXTURE) and swapped into _speed01's slot
--   gtxt_speed_low01. The quad keeps that size (a stretched quad would flatten the slant as it drains) and SLIDES
--   left: its slanted end sits on bar left + width * rate and the rest runs off the screen's left edge (every banner's
--   bar starts at x <= 0, so the screen edge clips it). (Before: retail gauge_recast_aura01 of soccer00_54, orange,
--   stretched to the remaining width.) The rate comes from the menu that owns the timer, through
--   the parameter store (numbers only between menus): per-mille 0..1000, -1 = none yet (then no line):
--     zone 3     soccer_zone_menu, wrapper of UpdateZoneLimitTimer(rate) (hud_layout_zone.lua)
--     focus 1    soccer_focus_battle_menu, the rate UpdateFocusCountDownTimer / UpdateSkillDecideCountDownTimer give
--                the retail stopwatch soccer08_23 (hud_layout_focus.lua)
--     scramble 2 soccer_scramble_menu, the shrinking rings of the scramble gauges (hud_layout_scramble.lua)
--   Measured bars (es sprites; other languages differ by a few px): FOCO 297 / DISPUTA 385 of 456 (bar rows 50..73),
--   ÁREA 296 of 456, ZONA DE ÁREA 257 of 268 (bar rows 36..50). Engine calls only from PostStep / SetupAreaTitle.
EVT_HL_TIMELINE_ON = true
EVT_HL_TIMELINE_H = 5             -- line thickness, screen layout units (2026-10-07: 5; 1.9.1: 7)
EVT_HL_TIMELINE_LEN = 0.65        -- full-time length / the banner bar's width (2026-10-07: shorter, was 1)
EVT_HL_TIMELINE_GAP = 1           -- gap between the banner's bar and the line (2026-10-07: 1; was 3)
EVT_HL_TIMELINE_DX = 0            -- fine tuning (+ = right; keep <= 0: the quad's hidden part must stay off screen)
EVT_HL_TIMELINE_DY = 0            -- (+ = up)

local HLT_KEY = {[1] = 1435113398 --[[evt_hl_timeline_focus]], [2] = 2540211860 --[[evt_hl_timeline_scramble]],
  [3] = 848130028 --[[evt_hl_timeline_zone]]}
-- displayed sprite: size, bottom of its bar (rows from the top), bar width (from x 0, hatch included)
local HLT_SPR = {[1] = {456, 76, 74, 297}, [2] = {456, 76, 74, 385}, [3] = {456, 76, 74, 296}}
local HLT_SPR_ZONEAREA = {268, 52, 51, 257}
local HLT_TEX_PATH = "#/menu/00_soccer/evt_clean_hud/evt_hl_timeline.g4tx"
local HLT_TEX = 3405321035 --[[crc32 of HLT_TEX_PATH]]
local HLT_SPRITE = 3228168228 --[[evt_hl_timeline01: 528 x 16 px, opaque rows 3..12]]
local HLT_SLOT = 876725243 --[[gtxt_speed_low01: slot of _speed01]]
local HLT_MESH = 2750042957 --[[_speed01]]
local HLT_PARENT_Y = -14          -- _pos_title (under _pos_base01)
local HLT_ROWS, HLT_ROW0, HLT_OPAQUE = 16, 3, 10
local HLT_QUAD_W, HLT_QUAD_END = 264, 262   -- sprite width / its slanted end's top corner, screen layout units
local HLT_CMND_IS_OPEN = 2640875187
local HLT_CMND_MESH_VIS = 3405944500
local HLT_CMND_NODE_POS = 2575768773 --[[(layer, idx, node, axis 0 x / 1 y, value)]]
local HLT_CMND_NODE_SIZE = 2885415772 --[[(layer, idx, node, sx, sy): a mesh's size]]
local HLT_CMND_LOAD_TEX = 839427544
local HLT_CMND_TEX_BUSY = 1506186496
-- (2026-10-06, clean_hud 1.9.1: the parameter store does not overwrite an existing key, as retail RegisterPropValue
-- shows: it deletes the key (3363400568) first. Without that only the first value of a key ever landed, and the
-- -1 written by the banner's SetupAreaTitle kept the line hidden for good.)
local HLT_P_SET, HLT_P_GET, HLT_P_HAS, HLT_P_DEL = 3860611758, 3522198769, 2947612279, 3363400568
local hlt = {tex = 0, t = 0, swapped = false, shown = nil, geo = nil, logs = 0}

local function HLT_Log(...)
  if hlt.logs < 20 and type(funcLuaCommand) == "function" then
    hlt.logs = hlt.logs + 1
    pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "EVT hud_layout timeline", ...)
  end
end

-- texture: 0 not asked, 1 loading, 2 ready, -1 failed (no line, one log line)
local function HLT_TexReady()
  if hlt.tex == 2 then
    return true
  elseif hlt.tex == -1 then
    return false
  elseif hlt.tex == 0 then
    local ok = pcall(funcLuaMenuCommand, HLT_CMND_LOAD_TEX, HLT_TEX_PATH)
    hlt.tex, hlt.t = ok and 1 or -1, 0
    if not ok then
      HLT_Log("texture load FAILED (no line)")
    end
    return false
  end
  hlt.t = hlt.t + 1
  local ok, busy = pcall(funcLuaCommand, HLT_CMND_TEX_BUSY, HLT_TEX)
  if not ok or hlt.t > 600 then
    hlt.tex = -1
    HLT_Log("texture never loaded (no line)")
    return false
  end
  if busy ~= true and hlt.t >= 10 then
    hlt.tex = 2
    HLT_Log("texture in after", hlt.t, "frames")
    return true
  end
  return false
end

local function HLT_Show(on)
  if hlt.shown ~= on then
    funcLuaMenuCommand(HLT_CMND_MESH_VIS, HLA_LAYER, HLT_MESH, on, 0)
    hlt.shown = on
  end
end

local function HLT_Sprite()
  if hla_type == HLA_ZONE_TYPE and EVT_HL_ZONE_TITLE and EVT_HL_AREA_TITLE_ON then
    return HLT_SPR_ZONEAREA
  end
  return HLT_SPR[hla_type]
end

local function HLT_Step()
  if not EVT_HL_TIMELINE_ON or type(funcLuaMenuCommand) ~= "function" or type(funcLuaCommand) ~= "function" then
    return
  end
  local key, spr = HLT_KEY[hla_type], HLT_Sprite()
  if key == nil or spr == nil then
    return
  end
  if funcLuaMenuCommand(HLT_CMND_IS_OPEN, HLA_LAYER) ~= true then
    hlt.swapped, hlt.shown, hlt.geo = false, nil, nil
    return
  end
  if not HLT_TexReady() then
    return
  end
  local v
  if funcLuaCommand(HLT_P_HAS, key) == true then
    v = funcLuaCommand(HLT_P_GET, key)
  end
  hlt.nf = (hlt.seen == hla_type and (hlt.nf or 0) or 0) + 1
  if hlt.seen ~= hla_type then
    hlt.seen, hlt.logged = hla_type, false
  end
  if not hlt.logged and ((type(v) == "number" and v >= 0) or hlt.nf == 60) then
    hlt.logged = true
    HLT_Log("banner", hla_type, "rate", tostring(v), "after", hlt.nf, "frames")
  end
  if type(v) ~= "number" or v < 0 or v ~= v then
    HLT_Show(false)
    return
  end
  if not hlt.swapped then
    funcLuaMenuCommand(HLA_CMND_SWAP, HLA_LAYER, HLT_TEX, HLT_SPRITE, HLT_SLOT, 0, 0)
    hlt.swapped, hlt.geo = true, nil
  end
  local rate = math.max(0, math.min(1, v / 1000))
  local sx, sy = hla_sx, hla_sy
  local quad_h = EVT_HL_TIMELINE_H / sy * HLT_ROWS / HLT_OPAQUE
  local bar_bottom = HLA_MESH_Y - HLA_MESH_H / spr[2] * spr[3]
  local line_top = bar_bottom - (EVT_HL_TIMELINE_GAP - EVT_HL_TIMELINE_DY) / sy
  local top = line_top + quad_h * HLT_ROW0 / HLT_ROWS
  local bar_left = HLA_MESH_X + EVT_HL_TIMELINE_DX / sx
  local w = HLA_MESH_W / spr[1] * spr[4] * EVT_HL_TIMELINE_LEN * rate   -- remaining width, layer units
  if w * sx < 0.5 then
    HLT_Show(false)
    return
  end
  local quad_w = HLT_QUAD_W / sx                      -- fixed size: the slant keeps its angle
  local left = bar_left + w - HLT_QUAD_END / sx       -- slanted end on the remaining width, the rest off screen
  local g = hlt.geo
  if g == nil or math.abs(g[1] - left) > 0.01 or g[2] ~= top or g[3] ~= quad_w or g[4] ~= quad_h then
    funcLuaMenuCommand(HLT_CMND_NODE_SIZE, HLA_LAYER, 0, HLT_MESH, quad_w, quad_h)
    funcLuaMenuCommand(HLT_CMND_NODE_POS, HLA_LAYER, 0, HLT_MESH, 0, left)
    funcLuaMenuCommand(HLT_CMND_NODE_POS, HLA_LAYER, 0, HLT_MESH, 1, top - HLT_PARENT_Y)
    hlt.geo = {left, top, quad_w, quad_h}
  end
  HLT_Show(true)
end

-- a new banner (SetupAreaTitle hides _speed01, a set-up layer has its retail sprite back): start clean, and forget the
-- previous state's rate (the owner menu writes it again every frame)
local function HLT_Reset(clearKeys)
  hlt.swapped, hlt.shown, hlt.geo, hlt.seen = false, nil, nil, nil
  if clearKeys and type(funcLuaCommand) == "function" then
    for _, k in pairs(HLT_KEY) do
      pcall(funcLuaCommand, HLT_P_DEL, k)
      pcall(funcLuaCommand, HLT_P_SET, k, 0, -1)
    end
  end
end

local function HLT_Wrap(name, onlyLayer, clearKeys)
  local prev = rawget(_ENV, name)
  rawset(_ENV, name, function(...)
    local r = HLA_Pack()
    if type(prev) == "function" then
      r = HLA_Pack(prev(...))
    end
    local a1 = ...
    if not onlyLayer or a1 == HLA_LAYER then
      HLT_Reset(clearKeys and EVT_HL_TIMELINE_ON)
    end
    if name == "PostStep" then
      local ok, err = pcall(HLT_Step)
      if not ok then
        HLT_Log("error", tostring(err))
      end
    end
    return table.unpack(r, 1, r.n)
  end)
end

if type(rawget(_ENV, "SetupAreaTitle")) == "function" then
  HLT_Wrap("SetupAreaTitle", false, true)
  HLT_Wrap("OnSetupLayer", true, false)
  HLT_Wrap("OnOpenLayer", true, false)
  HLT_Wrap("PostStep", true, false)   -- the retail script has none (callbacks are looked up by name every frame)
end
