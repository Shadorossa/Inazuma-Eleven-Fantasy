-- VRFW route_board BEGIN
-- VR-Framework: the hook points of the Chronicle board's command menu, vs_route_town_command_select_menu.
-- The framework owns the one patch of the script (route_nodes + this graft) and makes
-- it a VRFW_Host host (the host call at the end of this graft's file); a mod hooks the points below, or the script's
-- retail globals (OnInit, OnFunction, ...), from its own hook file ([[hooks]] stem = "vs_route_town_command_select_menu").
--   VRFW_RBC_Rows(rows, kind, slot) -> rows   the piece's rows (difficulties) of the menu (OnInit; kind 0 normal piece,
--                                             1 gate piece; slot = the piece's save slot). Default: route_nodes' node
--                                             filter (a [[route_node]] lists only its shown difficulties). A mod's
--                                             "around" handler filters first and passes its rows on with nxt(...)
--   VRFW_RBC_Guide(item, icons, texts, cmds)  the button guide of a focused row (SetupButtonGuide; item = the row,
--                                             {} when none): append entries to the three lists
--   VRFW_RBC_ListLayer(layer, kind, rows)     the battle-kind list panel (layer 14202445 normal / 1695882381 gate) is
--                                             placed and about to open with `rows` rows
--   VRFW_RBC_PanelExtra(layer, kind, rows, extra)  the panel must reach `extra` px further down under its last row (the
--                                             bands below; 0 = fitted to the rows again): a mod that sizes the panel
--                                             re-sizes it ("after" handler)
-- Bands under the last row (stacked by order, lowest first; their sum is the panel's extra):
--   VRFW_RBC_PanelBand(id, height, order)     asks for band `id` of `height` px (0 / nil = gone); calls
--                                             VRFW_RBC_PanelExtra with the new sum when it changed
--   VRFW_RBC_PanelBandReserve(id, height, order)  keeps band `id` at least `height` px while the panel stays placed,
--                                             shown or not (a row-dependent band reserves its place so the panel
--                                             keeps one height and nothing moves when the focus changes)
--   VRFW_RBC_PanelBandTop(id) -> y            the screen y (1920 x 1080, y down) of the band's top edge (the panel as
--                                             placed; a caller adds the panel's shift while it moves)
--   VRFW_RBC_PanelShift() -> dx, dy           how far the panel's layer moved since it was placed (its open / close
--                                             slide; layer axes, y up)
-- The match challenge line is band "match_challenge" (order 10, reserved on a piece with a challenge on any row).
-- Bands and reserves are cleared when the panel is placed: a module asks again from an "after" handler of
-- VRFW_RBC_ListLayer.
-- VRFW_RBC.panel = {layer, kind, rows, extra, x, y, bands}: the list panel as placed (x, y = its layer's local position
-- then, CMND_GET_LAYER_LOCAL_POS), extra = the sum of the bands (reset to 0 when the panel is placed).
-- VRFW_RBC.GEOMETRY: the battle-kind list of both piece kinds as placed (screen px): the first row's centre line, the
-- rows' spacing (layouts vsroute01_15c / 15d `_atc_listNN`, 70 px apart), half a row's height, the panel's centre line.
-- The script's locals a handler may read / write: VRFW_RBC.L.<name> (decompile names; one line in VRFW_RBC_LOCALS
-- when a mod needs another one).
VRFW_RBC = VRFW_RBC or {}
VRFW_RBC.STEM = "vs_route_town_command_select_menu"
VRFW_RBC_LOCALS = {
  n2 = {function() return n2 end, function(v) n2 = v end},         -- the piece's save slot (statusFlagIndex)
  n4 = {function() return n4 end, function(v) n4 = v end},         -- the piece's game id
  t3 = {function() return t3 end, function(v) t3 = v end},         -- the menu's rows ({difficultyType, ...}, OnInit)
  flag = {function() return flag end, function(v) flag = v end},   -- the menu is closing (a row was decided)
  flag2 = {function() return flag2 end, function(v) flag2 = v end} -- the drop-rate window is open
}
VRFW_RBC.L = setmetatable({}, {
  __index = function(_, k)
    local a = VRFW_RBC_LOCALS[k]
    if a == nil then
      error("VRFW_RBC.L: the command menu serves no local " .. tostring(k), 2)
    end
    return a[1]()
  end,
  __newindex = function(_, k, v)
    local a = VRFW_RBC_LOCALS[k]
    if a == nil then
      error("VRFW_RBC.L: the command menu serves no local " .. tostring(k), 2)
    end
    a[2](v)
  end
})

function VRFW_RBC_Rows(rows, kind, slot)
  if VRFW_Gacha ~= nil and VRFW_Gacha.RowsFor ~= nil then
    local g = VRFW_Gacha.RowsFor(slot, rows) -- a gacha node: the pool's one command row
    if g ~= nil then
      return g
    end
  end
  if VRFW_RN_Rows ~= nil then
    return VRFW_RN_Rows(rows, slot)
  end
  return rows
end

function VRFW_RBC_Guide(item, icons, texts, cmds)
end

-- true while the open command menu belongs to a piece whose rows are a framework service's own (a gacha node: its one
-- command row): a mod's match panel (team lineup, team level, the panel fitted to the battle rows) stays off there
function VRFW_RBC_ServicePiece()
  if VRFW_Gacha == nil or VRFW_Gacha.OfSlot == nil or VRFW_RBC == nil or VRFW_RBC.L == nil then
    return false
  end
  local ok, slot = pcall(function() return VRFW_RBC.L.n2 end)
  return ok and type(slot) == "number" and VRFW_Gacha.OfSlot(slot) > 0
end

VRFW_RBC.panel = VRFW_RBC.panel or {extra = 0, bands = {}}
VRFW_RBC.GEOMETRY = {FIRST_ROW_MID_Y = 442, ROW_STEP = 70, ROW_HALF_HEIGHT = 30, PANEL_MID_X = 436}

function VRFW_RBC_ListLayer(layer, kind, rows)
  local p = VRFW_RBC.panel
  p.layer, p.kind, p.rows, p.extra, p.bands, p.reserved = layer, kind, rows, 0, {}, {}
  local ok, x, y = pcall(funcLuaMenuCommand, @crc:CMND_GET_LAYER_LOCAL_POS@, layer, 0)
  p.x = ok and type(x) == "number" and x or nil
  p.y = ok and type(y) == "number" and y or nil
end

function VRFW_RBC_PanelExtra(layer, kind, rows, extra)
  VRFW_RBC.panel.extra = extra
end

-- a band's height as laid out: asked, or its reserve when larger
function VRFW_RBC.BandHeight(p, id)
  local band = (p.bands or {})[id]
  local reserve = (p.reserved or {})[id]
  local h = band ~= nil and band.height or 0
  if reserve ~= nil and reserve.height > h then
    h = reserve.height
  end
  return h
end

function VRFW_RBC.BandOrder(p, id)
  local band = (p.bands or {})[id] or (p.reserved or {})[id]
  return band ~= nil and band.order or 0
end

function VRFW_RBC.BandsChanged(p)
  local total, seen = 0, {}
  for _, list in ipairs({p.bands or {}, p.reserved or {}}) do
    for id in pairs(list) do
      if not seen[id] then
        seen[id] = true
        total = total + VRFW_RBC.BandHeight(p, id)
      end
    end
  end
  if total == p.extra then
    return
  end
  if p.layer ~= nil then
    VRFW_RBC_PanelExtra(p.layer, p.kind, p.rows, total)
  else
    p.extra = total
  end
end

function VRFW_RBC_PanelBand(id, height, order)
  local p = VRFW_RBC.panel
  p.bands = p.bands or {}
  local old = p.bands[id]
  height = height or 0
  order = order or 0
  if height <= 0 then
    if old == nil then
      return
    end
    p.bands[id] = nil
  elseif old ~= nil and old.height == height and old.order == order then
    return
  else
    p.bands[id] = {height = height, order = order}
  end
  VRFW_RBC.BandsChanged(p)
end

function VRFW_RBC_PanelBandReserve(id, height, order)
  local p = VRFW_RBC.panel
  p.reserved = p.reserved or {}
  if (height or 0) <= 0 then
    p.reserved[id] = nil
  else
    p.reserved[id] = {height = height, order = order or 0}
  end
  VRFW_RBC.BandsChanged(p)
end

function VRFW_RBC_PanelBandTop(id)
  local p = VRFW_RBC.panel
  local g = VRFW_RBC.GEOMETRY
  local y = g.FIRST_ROW_MID_Y + g.ROW_STEP * (math.max(p.rows or 1, 1) - 1) + g.ROW_HALF_HEIGHT
  local own = VRFW_RBC.BandOrder(p, id)
  local seen = {[id] = true}
  for _, list in ipairs({p.bands or {}, p.reserved or {}}) do
    for other in pairs(list) do
      if not seen[other] then
        seen[other] = true
        local o = VRFW_RBC.BandOrder(p, other)
        if o < own or (o == own and other < id) then
          y = y + VRFW_RBC.BandHeight(p, other)
        end
      end
    end
  end
  return y
end

function VRFW_RBC_PanelShift()
  local p = VRFW_RBC.panel
  if p.layer == nil or p.x == nil or p.y == nil then
    return 0, 0
  end
  local ok, x, y = pcall(funcLuaMenuCommand, @crc:CMND_GET_LAYER_LOCAL_POS@, p.layer, 0)
  if not ok or type(x) ~= "number" or type(y) ~= "number" then
    return 0, 0
  end
  return x - p.x, y - p.y
end
-- VRFW route_board END
