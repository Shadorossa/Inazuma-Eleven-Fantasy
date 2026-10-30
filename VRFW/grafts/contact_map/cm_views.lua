-- vrfw_contact_map_menu, part 4 of 7 (graft contact_map appends it to vrfw_contact_map_menu.lua; one chunk):
-- drawing the grid, network and shop views, the title and the button guide (DrawAll).
local function GridPage()
  return math.floor((focus.grid - 1) / (GRID.COLS * GRID.ROWS))
end

local function DrawGrid()
  if MAP.pitch then
    CmPages.DrawPitch()
    if members[focus.grid] ~= nil then
      PlayerCard(members[focus.grid])
    end
    return
  end
  local per = GRID.COLS * GRID.ROWS
  local page = GridPage()
  local left = AREA.CX - (GRID.COLS - 1) * GRID.CELL / 2
  for k = 0, per - 1 do
    local g = page * per + k + 1
    local i = members[g]
    if i ~= nil then
      local x = left + (k % GRID.COLS) * GRID.CELL
      local y = GRID.TOP + math.floor(k / GRID.COLS) * GRID.CELL
      local st = State(i)
      local size = GRID.CELL * GRID.FACE            -- the card = the miniface box
      local bs = size * GRID.CHECK
      local bx, by = x + size / 2 - bs * 0.45, y + size / 2 - bs * 0.45   -- the badges' centre: the card's bottom-right corner
      Plate(k, st, x, y, size)
      DrawFace(L_FACE, k, MAP.nodes[i], x, y, size * NET.FACE_IN)   -- inside the card (hats were cut)
      if st == "done" then
        Quad(L_TAG, k, "icon_check", bx, by, bs, bs)
      elseif ReqsUnmet(MAP.nodes[i]) then        -- a requirement not met: the red badge on the card
        Quad(L_TAG, k, "badge_unmet", bx, by, size * GRID.REQNG, size * GRID.REQNG)
      end
      pos[g] = {x = x, y = y, hw = size / 2, hh = size / 2}
    end
  end
  local pages = math.max(1, math.ceil(#members / per))
  if page > 0 then
    Quad(L_UI, 1, "arrow_left", left - GRID.CELL * 0.75, GRID.TOP + GRID.CELL * 1.5, 56, 56)
  end
  if page < pages - 1 then
    Quad(L_UI, 2, "arrow_right", left + (GRID.COLS - 0.25) * GRID.CELL, GRID.TOP + GRID.CELL * 1.5, 56, 56)
  end
  if members[focus.grid] ~= nil then
    PlayerCard(members[focus.grid])
  end
end

-- the network's world -> screen: x centred on the map's span, y following the camera
local function NetX(n)
  return VIEW.CX + (n.x - NET.cx) * NET.S
end

local function NetY(n)
  return VIEW.CY + (n.y - NET.cy) * NET.S
end

local function NetVisible(n)
  local x, y, h = NetX(n), NetY(n), NET.PLATE / 2
  return x >= VIEW.X0 + h - 2 and x <= VIEW.X1 - h + 2 and y >= VIEW.Y0 + h - 2 and y <= VIEW.Y1 - h + 2
end

-- the camera kept over the network: centred on an axis that fits, else inside the network's span (+ a margin)
local function ClampCamera()
  local hw, hh = (VIEW.X1 - VIEW.X0) / 2 / NET.S, (VIEW.Y1 - VIEW.Y0) / 2 / NET.S
  local pad = (NET.PLATE + 20) / NET.S
  if MAP.maxx - MAP.minx + 2 * pad <= 2 * hw then
    NET.cx = (MAP.minx + MAP.maxx) / 2
  else
    NET.cx = math.max(MAP.minx - pad + hw, math.min(NET.cx, MAP.maxx + pad - hw))
  end
  if MAP.maxy - MAP.miny + 2 * pad <= 2 * hh then
    NET.cy = (MAP.miny + MAP.maxy) / 2
  else
    NET.cy = math.max(MAP.miny - pad + hh, math.min(NET.cy, MAP.maxy + pad - hh))
  end
end

-- the zoom: tiles, faces and links scale with it
local function SetScale(sc)
  NET.S = math.max(NET.FIT, math.min(NET.MAX, sc))
  NET.T = math.max(NET.FIT, math.min(NET.MAX, NET.T or NET.S))
  local r = math.min(1.35, NET.S / NET.S0)
  NET.PLATE, NET.FACE, NET.SMALL, NET.LINE = NET.PLATE0 * r, NET.FACE0 * r, NET.SMALL0 * r, math.max(3, NET.LINE0 * r)
end

-- the cursor's tile always in view: the camera moves when it comes within MARGIN of VIEW's edges
local function FollowCamera()
  local n = MAP.nodes[focus.network]
  local m = VIEW.MARGIN
  local x, y = NetX(n), NetY(n)
  if x < VIEW.X0 + m then
    NET.cx = NET.cx - (VIEW.X0 + m - x) / NET.S
  elseif x > VIEW.X1 - m then
    NET.cx = NET.cx + (x - (VIEW.X1 - m)) / NET.S
  end
  if y < VIEW.Y0 + m then
    NET.cy = NET.cy - (VIEW.Y0 + m - y) / NET.S
  elseif y > VIEW.Y1 - m then
    NET.cy = NET.cy + (y - (VIEW.Y1 - m)) / NET.S
  end
  ClampCamera()
end

-- after a pan / zoom the cursor stays on a tile in view: the nearest one to the view's centre when his went out
local function KeepFocusInView()
  if NetVisible(MAP.nodes[focus.network]) then
    return
  end
  local best, bd = nil, nil
  for i, n in ipairs(MAP.nodes) do
    if NetVisible(n) and n.kind ~= "open" then
      local d = (NetX(n) - VIEW.CX) ^ 2 + (NetY(n) - VIEW.CY) ^ 2
      if bd == nil or d < bd then
        best, bd = i, d
      end
    end
  end
  if best ~= nil then
    focus.network = best
  end
end

-- the network, virtually (one map, no pages): the tiles in VIEW, nearest the view's centre first,
-- up to the tile pool; players' busts on the bust pool (a card keeps the slot it had: a pan never rebuilds a bust;
-- past the pool, the plate alone), gates' faces on the face pool; links between two drawn tiles, up to the line pool
local function DrawNetwork()
  local vis = {}
  for i, n in ipairs(MAP.nodes) do
    if NetVisible(n) then
      vis[#vis + 1] = {i = i, d = (NetX(n) - VIEW.CX) ^ 2 + (NetY(n) - VIEW.CY) ^ 2}
    end
  end
  table.sort(vis, function(a, b) return a.d < b.d end)
  -- links in view (both ends in view): with the tiles, they must fit the pools; else the widest zoom goes up (the
  -- floor FIT, eased to: the next frames draw everything again) and this frame draws the nearest ones
  local inview, nlinks = {}, 0
  for _, v in ipairs(vis) do
    inview[v.i] = true
  end
  for _, v in ipairs(vis) do
    for _, b in ipairs(MAP.nodes[v.i].links) do
      if v.i < b and inview[b] then
        nlinks = nlinks + 1
      end
    end
  end
  -- the faces in view too: the players drawn with a bust and the open gates with a face
  local nplayers, ngates = 0, 0
  for k = 1, math.min(#vis, N.TILE) do
    local n = MAP.nodes[vis[k].i]
    if n.kind == "player" and Int(n.card) ~= 0 and State(vis[k].i) ~= "locked" then
      nplayers = nplayers + 1
    elseif n.kind == "gate" and opened[vis[k].i] then
      ngates = ngates + 1
    end
  end
  if #vis > N.TILE or nlinks > N.LINE or nplayers > N.BUST - N.CARD_BUSTS or ngates > N.FACE then
    NET.FIT = math.min(NET.MAX, NET.S * 1.04)
    NET.T = math.max(NET.T or NET.S, NET.FIT)
  end
  local short = #vis > N.TILE and "tiles" or (nlinks > N.LINE and "links" or nil)
  local drawn, slot_of, li = {}, {}, 0
  for k = 1, math.min(#vis, N.TILE) do
    drawn[k] = vis[k].i
    slot_of[vis[k].i] = k - 1
  end
  -- bust slots: the cards of the drawn players (not locked), nearest first; a card keeps its slot
  local nb = N.BUST - N.CARD_BUSTS
  local keyed = BUST.key[L_BUST] or {}
  local held = {}
  for k = 0, nb - 1 do
    if keyed[k] ~= nil then
      held[keyed[k]] = k
    end
  end
  local want, bslot, used = {}, {}, {}
  for _, i in ipairs(drawn) do
    local n = MAP.nodes[i]
    if n.kind == "player" and Int(n.card) ~= 0 and State(i) ~= "locked" and #want < nb then
      want[#want + 1] = i
      local k = held[n.card]
      if k ~= nil and not used[k] then
        bslot[i], used[k] = k, true
      end
    end
  end
  if #want >= nb and short == nil then
    short = "faces"
  end
  local free = 0
  for _, i in ipairs(want) do
    if bslot[i] == nil then
      while used[free] do
        free = free + 1
      end
      bslot[i], used[free] = free, true
    end
  end
  local gs, tg = 0, 0
  local function Tag(role, x, y, size)   -- a badge while the badge pool lasts
    if tg >= N.TAG then
      return
    end
    Quad(L_TAG, tg, role, x, y, size, size)
    tg = tg + 1
  end
  for _, i in ipairs(drawn) do
    local n = MAP.nodes[i]
    local slot = slot_of[i]
    local x, y = NetX(n), NetY(n)
    if n.kind == "player" then
      local st = State(i)
      Plate(slot, st, x, y, NET.PLATE)
      if st ~= "locked" then
        if bslot[i] ~= nil then
          DrawBust(L_BUST, bslot[i], n.card, x, y, NET.FACE)
        end
        if st == "missing" and ReqsUnmet(n) then
          Tag("badge_unmet", x + NET.PLATE * 0.32, y + NET.PLATE * 0.32, NET.PLATE * 0.4)
        end
      end
    elseif n.kind == "gate" then
      local st = opened[i] and (acquired[i] and "done" or "missing") or "locked"
      Plate(slot, st, x, y, NET.PLATE)
      if st ~= "locked" then
        Tint(L_TILE, slot, acquired[i] and COLOUR.DONE or COLOUR.GATE)
        if gs < N.FACE then
          local tc = (n.face or "") ~= "" and Tex(FACE_DIR .. n.face .. "_l.g4tx") or nil
          if tc then
            QuadTex(L_FACE, gs, tc, CRC32(n.face .. "_1_l00"), x, y, NET.FACE, NET.FACE)
          elseif tc == nil then
            Quad(L_FACE, gs, "icon_unknown", x, y, NET.FACE, NET.FACE)
          end
          gs = gs + 1
        end
        if not acquired[i] then
          Tag("icon_lock", x + NET.PLATE * 0.32, y + NET.PLATE * 0.32, NET.PLATE * 0.42)
        end
      end
    elseif n.kind == "start" then          -- the start bigger than a cell (NET.START)
      Quad(L_TILE, slot, "tile_start", x, y, NET.PLATE * NET.START, NET.PLATE * NET.START)
      Tint(L_TILE, slot, COLOUR.WHITE)
    else
      Quad(L_TILE, slot, opened[i] and "tile_done" or "tile_hidden", x, y, NET.SMALL, NET.SMALL)
      Tint(L_TILE, slot, COLOUR.WHITE)
    end
    local half = (n.kind == "open") and NET.SMALL / 2 or (n.kind == "start" and NET.PLATE * NET.START / 2 or NET.PLATE / 2)
    pos[i] = {x = x, y = y, hw = half, hh = half}
  end
  for _, a in ipairs(drawn) do
    local n = MAP.nodes[a]
    for _, b in ipairs(n.links) do
      if a < b and slot_of[b] ~= nil then
        if li >= N.LINE then
          short = short or "links"
        else
          local ax, ay, bx, by = NetX(n), NetY(n), NetX(MAP.nodes[b]), NetY(MAP.nodes[b])
          local c = (acquired[a] and acquired[b]) and COLOUR.LINK_DONE or ((opened[a] and opened[b]) and COLOUR.LINK_OPEN or COLOUR.LINK_LOCKED)
          local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
          Quad(L_LINE, li, "link", (ax + bx) / 2, (ay + by) / 2, len, NET.LINE)
          funcLuaMenuCommand(C.ROTATE, L_LINE, 0, 0, math.atan2(-(by - ay), bx - ax), li)
          Tint(L_LINE, li, c)
          li = li + 1
        end
      end
    end
  end
  if short ~= nil and not N.full then
    N.full = true
    Log("network pool short", short, "in view", #vis, "links", li)
  end
  TileCard(focus.network)
end

local function ShelfFor()
  -- a zone's shelf: the items its players ask for; elsewhere the map's whole shelf
  local want = nil
  if prev_mode == "grid" then
    want = {}
    for _, i in ipairs(members) do
      for _, r in ipairs(MAP.nodes[i].reqs) do
        if r.kind == "item" then
          want[r.id] = true
        end
      end
    end
  end
  local out = {}
  for _, it in ipairs(MAP.items) do
    if want == nil or want[it.item] then
      out[#out + 1] = it
    end
  end
  return out
end

local function DrawShop()
  local first = math.max(1, focus.shop - LIST.ROWS + 1)
  local left = LIST.CX - LIST.W / 2
  for k = 0, LIST.ROWS - 1 do
    local i = first + k
    local it = shelf[i]
    if it == nil or k >= N.TITLE then
      Hide(L_TITLE, k)
    else
      local y = LIST.TOP + k * LIST.ROW
      Quad(L_TILE, k, "list_row", LIST.CX, y, LIST.W, LIST.H)
      Tint(L_TILE, k, i == focus.shop and COLOUR.ROW_FOCUS or COLOUR.ROW)
      Line(L_TITLE, k, Fmt(T.SHOP_ROW, Text(it.title), it.price, Text(SET.ict), VRFW_Recruit.Items(it.item)), left + 40, y, 0.9)
      pos[i] = {x = LIST.CX, y = y, hw = LIST.W / 2, hh = LIST.H / 2}
    end
  end
  Hide(L_UI, 0)
  if #shelf == 0 then
    Card({Text(T.SHOP_BTN), Text(T.SHOP_EMPTY)}, nil, nil)
  else
    local it = shelf[focus.shop]
    Card({Text(it.title), Fmt(T.REQ_ITEM, Text(SET.ict), it.price, VRFW_Recruit.Items(SET.ic))}, nil, nil)
  end
end

local function UpdateTitle()
  local title = Text(SET and SET.title or 0)
  if mode ~= "list" and MAP ~= nil then
    title = CmPages.MapTitle(MAP)
    if mode == "grid" and MAP.zones[zone] ~= nil then
      title = title .. " · " .. CmPages.ZoneTitle(MAP.zones[zone])
    elseif mode == "shop" then
      title = title .. " · " .. Text(T.SHOP_BTN)
    end
  end
  if VIEW_ALL.on and not CmPages.direct then
    title = title .. "  [" .. Text(T.VIEW_MARK) .. "]"
  end
  funcLuaMenuCommand(C.TEXT, L_HEADER, 1220590795 --[[_text_sub_title02]], title, 0)
end

local function UpdateButtonGuide()
  if false then                     -- no "Items" on the contact map (no hint, no X / Tab)
    funcLuaMenuCommand(C.GUIDE_SET, MENU, L_BTN_GUIDE, {T.SHOP_BTN, G_ACCEPT}, {I_FUNC2, I_ENTER}, {0, 18}, {}, {})
    funcLuaMenuCommand(C.GUIDE_CMD, MENU, L_BTN_GUIDE, {K_FUNC2, K_ENTER})
  else
    local texts, icons, sizes, keys = {G_ACCEPT}, {I_ENTER}, {18}, {K_ENTER}
    for _, g in ipairs(CmPages.GuideExtra()) do
      texts[#texts + 1], icons[#icons + 1], sizes[#sizes + 1], keys[#keys + 1] = g[1], g[2], 18, g[3]
    end
    funcLuaMenuCommand(C.GUIDE_SET, MENU, L_BTN_GUIDE, texts, icons, sizes, {}, {})
    funcLuaMenuCommand(C.GUIDE_CMD, MENU, L_BTN_GUIDE, keys)
  end
  funcLuaMenuCommand(C.GUIDE_OPT, MENU, L_BTN_GUIDE, false)
end

CmPages.Guide = UpdateButtonGuide

local function DrawAll()
  if SET == nil then
    return
  end
  OtNote("draw " .. mode)
  tex_wait = false
  pos = {}
  HideAll()
  RowPlatesOff()
  HideReqs()
  DrawBack()
  DrawZoneArt()
  if mode == "list" then
    DrawList()
  elseif mode == "zones" then
    DrawZones()
  elseif mode == "grid" then
    DrawGrid()
  elseif mode == "network" then
    DrawNetwork()
  elseif mode == "shop" then
    DrawShop()
  end
  if mode ~= "list" and mode ~= "shop" then
    DrawCursor()
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_GUIDE_LINE, 0, false)
end
