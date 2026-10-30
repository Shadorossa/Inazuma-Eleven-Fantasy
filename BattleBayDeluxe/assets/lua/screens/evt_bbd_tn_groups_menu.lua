-- evt_bbd_tn_groups_menu (plain Lua 5.2 source): Battle Bay Deluxe's Torneo GROUP STAGE screen (docs/game/modes/
-- bb-tournament.md §0 1.5.60). Declared in content\menus\bb_tournament.toml ([[screen]], served as
-- common/script/lua/menu/evt_bbd_tn_groups_menu.lua.bin).
-- 1.5.60 (owner 2026-10-14: «que la fase de grupos no se divida nunca en páginas, siempre 1 sola página»): EVERY group on
-- one page (1, 2, 4, 8 or 16 groups). The tables need more layer instances than the Battle Bay top menu can still hold
-- (the engine sets up ~844 per open menu, docs/game/ui/menu-layer-limits.md §2.1-2.3; that menu is at ~780 with
-- Utilities' 269), so they live in this menu of their own: a display-only child menu (registry priority 0: it never
-- takes the pad; no input layer, no focus group) that the overlay (graft bb_tournament, bbt_top.lua BBT_GroupsShow)
-- opens over its host (bb_stadium_top_menu or Inazuma Fantasy's soccer_top_menu) while the group page is shown and
-- closes when another page is shown or the overlay closes. The host keeps the keys (L1 / R1, Enter, Back), its header
-- title («Fase de grupos · Jornada N de 3») and the bracket's background; this menu only draws the cards + legend.
-- Handshake: VRFW_ChildMenu (VRFW menu\_all\89_child_menu.lua; parameters evt_bbd_tn_groups_page, the view page to
-- draw, and evt_bbd_tn_groups_host_hi / _lo, the host menu; the host's redraw and close; this menu closes with its host).
-- The look is 1.5.54's approved sketch (research/scripts/bbd_groups_sketch.py): a card per group (white slanted plate
-- with baked shadow, navy header band «GRUPO A» + two slanted strokes), one row per team: position, crest + name (the
-- team row object evt_bbd_tn_row_l, its plate hidden; names cut with «…»), the numbers, the points in a darker cell;
-- top 2 = the qualification zone (green bar + tinted row), the player's row blue with white texts; the form dots;
-- a legend under the cards. Grid by group count:
--   1 group   wide     1 x 1 (at most WIDE_MAX px wide, centred), PJ G E P GF GC DG Pts + «Forma» column
--   2 groups  wide     2 x 1, the same columns
--   4 groups  wide     2 x 2, the same columns
--   8 groups  compact  4 x 2, PJ G E P DG Pts, the form dots under the name
--   16 groups tiny     4 x 4 (a 64-team group stage), PJ DG Pts (labels in the header band), no form dots, rows ~39 px
-- Layers (content\menus\bb_tournament.toml [[screen]]; every colour a pre-coloured sprite of bbd_tn.g4tx, drawn
-- white): evt_bbd_gt_card (546) 16, evt_bbd_gt_band (547: header bands, row tints) 50, evt_bbd_gt_mark (548: qual
-- bars, separators, points cells, header strokes, form dots) 190, evt_bbd_gt_row (551, the team row object) 64,
-- evt_bbd_gt_txt (553) 322, evt_bbd_gt_face (552: the top scorers' minifaces, VRFW_FaceIcon; one a row of the
-- scorers page) 12 = 654 instances
-- (16 tiny cards: 16 + 49 + 178 + 64 + 322; 8 compact: 8 + 25 + 189 + 32 + 294). Change the counts in both places
-- (N below).
-- 1.45.0: the league's standings pages (view kind "league", DrawLeague) in this same menu: one card of up to
-- [league] rows_per_page teams on the bracket's plates (the player's in the gold frame); a 12-row page uses card 1,
-- band 1, mark ~84, row 12, txt ~125.
-- Log, once per opening (the first draw): instances requested / set up per pool, groups drawn, pieces not drawn.
-- Rule: no engine call at top level (funcLuaCommand only exists inside callbacks).
INCLUDE("LUA_PROG_BASE")

local MENU = 3003171228            -- crc32("evt_bbd_tn_groups_menu")
local CMD_VIEW = 2584538108        -- crc32("CMND_BBD_TOURN_VIEW") (the mod's scripts\tournament.lua)
local ART = 2658588602             -- crc32("#/menu/220_img/bbd_tn/bbd_tn.g4tx"): the mod's drawings
local NODE_QUAD = 1909474081       -- icon_new01 (the quad node of cmn01_10)
local MESH_QUAD = 312193881        -- _icon_new01
local Q = 36                       -- the quad's own size (px at scale 1)

-- the layers and their instance counts (the [[screen]] rows: change both together)
local L = {
  card = 2214017804,   -- evt_bbd_gt_card (546)
  band = 3711697204,   -- evt_bbd_gt_band (547)
  mark = 4086780334,   -- evt_bbd_gt_mark (548)
  row = 3638143763,    -- evt_bbd_gt_row (551, evt_bbd_tn_row_l)
  txt = 1088291469,    -- evt_bbd_gt_txt (553, evt_bbd_tn_txt)
  face = 2432161976,   -- evt_bbd_gt_face (552, evt_bbd_tn_face: the list character card, portrait only)
}
local N = { card = 16, band = 50, mark = 190, row = 64, txt = 322, face = 12 }
local NAMES = { card = "card", band = "band", mark = "mark", row = "row", txt = "txt", face = "face" }
local KEY_OF = {}
for k, l in pairs(L) do
  KEY_OF[l] = k
end

local C = {
  VISIBLE = 711242136, POS = 1389957207, SCALE = 3778714801, SPRITE = 558735651, PRIM_COLOR = 855211291,
  MESH_VISIBLE = 3405944500, TEXT = 1083631230, TEXT_VISIBLE = 1505208242, TEXT_STYLE = 2333948100,
  TEXT_GET = 4074371074,
  LAYER_NUM = 1175615627,      -- CMND_GET_CREATE_LAYER_NUM?
  MODEL_ALPHA = 4231609516, TEXT_ALPHA = 1126837159,
  CROSS_CALL = 830228314,      -- (menu, function name, ...): a function of another menu's Lua
}
-- the team row (evt_bbd_tn_row_l = team06_02): its plate looks, crest, name nodes
local PLATE = { 2022529787, 2334302522, 4215821749, 1697431574 }   -- _list_base_xs01_off / _on / _ok / _ol
local MESH_EMBLEM = 3281704751     -- _icon_emblem_dmy01 (its crest: VRFW_Team.Emblem)
local TXT_ON = 931545948           -- _text_list01_on (white)
local TXT_OFF = 3705682548         -- _text_list01_off (blue)
local OUT_ALPHA = 0.45             -- a team that is out (bbt_top.lua BattleBayDeluxe.Tournament.ADV.OUT_ALPHA)

-- the sprites of bbd_tn.g4tx (research/scripts/bbd_bracket_art.py)
local SP = {
  card = 2624519773, head = 763990034, qual = 308650821, qual_tint = 2315879333, me = 2434295730, pts = 910184237,
  pts_me = 1149433725, sep = 4275471326, stroke = 144416928, stroke2 = 3423307333,
  W = 1675980812, D = 3881513426, L = 3917527520, none = 2704804066,
}

-- the geometry (screen px, y down, 1920 x 1080; the constants of 1.5.54's sketch, bbd_groups_sketch.py --game)
local G = {
  W = 1920, Y0 = 124, Y1 = 984, MX = 40, GAP_X = 20, GAP_Y = 16, LEGEND_Y = 1014, LEGEND_X = 56,
  WIDE_MAX = 900,   -- one group alone: its card at most this wide, centred
  -- the card sprite (256 x 256): the plate's box inside it and its slant (bbd_bracket_art.py CARD_BOX)
  CARD = { W = 256, H = 256, L = 6, T = 6, R = 14, B = 18, SK = 8 },
  -- the team row: crest 22 px, name 98 px from its left edge, 72 px high; the name's font (px at scale 1) and its
  -- mean glyph width (of the px) for the cut with «…»
  PLATE_H = 72, CREST_IN = 22, NAME_L = 98, NAME_PX = 32, NAME_CHAR = 0.48,
  FILL = 0.84, PAD = 6, SEP = 2, QBAR = 6, TXT_HALF = 304,
  ST = {
    num = 3847724198,       -- fs_28_b_cc_2d0_001 (blue, centred, no outline)
    num_dim = 2029954615,   -- fs_28_k_cc_2d0_001 (W D L GF GC)
    num_me = 1911293514,    -- fs_28_w_cc_2d0_001 (white, the player's row)
    pts = 2392563157,       -- fs_32_b_cc_2d0_001
    pts_me = 438306617,     -- fs_32_w_cc_2d0_001
    label = 543999875,      -- fs_22_k_cc_2d0_001_nr_sclw (column labels)
    label_l = 3591594987,   -- fs_22_k_lc_2d0_001_nr_sclw («Equipo»)
    label_pts = 2001536506, -- fs_22_b_cc_2d0_001_sclw («Pts»)
    label_head = 1829976141, -- fs_22_w_cc_2d0_001_nr (labels in the header band, tiny)
    title = 3945487540,     -- fs_32_w_lc_2d0_001 («GRUPO A»)
    title_c = 438306617,    -- fs_32_w_cc_2d0_001 (a card's title centred on its band, CardTitle)
    legend = 834427687,     -- fs_26_w_lc_2d2_001 (outlined white, on the background)
  },
  MODES = {
    wide = { head = 50, labels = 30, pitch_max = 84, s_max = 0.8, cw = 42, ptsw = 58, pos_w = 44, pad_r = 16,
      cols = { "pj", "g", "e", "p", "gf", "gc", "dg", "pts" }, form = "col", dot = 22, dot_pitch = 28,
      name_dy = 0, num_s = 0.95, pts_s = 0.95, title_s = 1.0, label_s = 0.95 },
    compact = { head = 46, labels = 28, pitch_max = 84, s_max = 0.66, cw = 28, ptsw = 42, pos_w = 30, pad_r = 14,
      cols = { "pj", "g", "e", "p", "dg", "pts" }, form = "under", dot = 12, dot_pitch = 16, dot_dy = 21,
      name_dy = -8, num_s = 0.8, pts_s = 0.82, title_s = 0.85, label_s = 0.85 },
    tiny = { head = 34, labels = 0, pitch_max = 48, s_max = 0.5, cw = 38, ptsw = 44, pos_w = 30, pad_r = 12,
      cols = { "pj", "dg", "pts" }, form = false, name_dy = 0, num_s = 0.6, pts_s = 0.62, title_s = 0.62,
      label_s = 0.7 },
  },
  DIM = { g = true, e = true, p = true, gf = true, gc = true },
}

-- state of this opening
local S = { page = nil, host = nil, need = 0, got = 0, per = {}, seen = {}, frame = 0, drawn = false, logged = false,
  want = false, used = {}, miss = {}, emb = {}, strip = {}, groups = 0, mode = "", stuck = false }
local Handshake   -- the child side of VRFW_ChildMenu (VRFW_ChildMenu.Child), made in OnInit

-- the logger (VRFW_Log), made at the first line
local logger
local function Log(...)
  logger = logger or VRFW_Log.New("BattleBayDeluxe.tournament_groups")
  logger(...)
end

-- ---- helpers (the overlay's own, bbt_common.lua / bbt_top.lua: this menu has its own VM) ---------------------------
local CRC_T = nil
local function Crc(s)
  if CRC_T == nil then
    CRC_T = {}
    for i = 0, 255 do
      local c = i
      for _ = 1, 8 do
        if c % 2 == 1 then
          c = bit32.bxor(bit32.rshift(c, 1), 0xEDB88320)
        else
          c = bit32.rshift(c, 1)
        end
      end
      CRC_T[i] = c
    end
  end
  local c = 0xFFFFFFFF
  for i = 1, #s do
    c = bit32.bxor(CRC_T[bit32.band(bit32.bxor(c, string.byte(s, i)), 0xFF)], bit32.rshift(c, 8))
  end
  return bit32.bxor(c, 0xFFFFFFFF)
end

-- a text of the mod: evt_bbd_tn_<key> (text\rows\menu_text.toml)
local function Text(key)
  local ok, t = pcall(funcLuaCommand, C.TEXT_GET, Crc("evt_bbd_tn_" .. key))
  return ok and type(t) == "string" and t or ""
end

-- a sprite of a sheet on a quad's texture node; true once applied (CMND_SET_SPRITE's answer)
local function SetSprite(l, atlas, spr, node, i)
  local ok, done = pcall(funcLuaMenuCommand, C.SPRITE, l, atlas, spr, node, 0, i)
  return ok and done == true
end

local function Hide(layer, i)
  funcLuaMenuCommand(C.VISIBLE, layer, i, false)
  funcLuaMenuCommand(C.POS, layer, -4000, 4000, 0, i)
end

-- the next free instance of a pool (nil when it is full: counted as not drawn)
local function Take(k)
  local i = S.used[k] or 0
  if i >= N[k] then
    S.miss[k] = (S.miss[k] or 0) + 1
    return nil
  end
  S.used[k] = i + 1
  return i
end

-- a quad of the mod's drawings on pool k: centre (x, y), w x h px
local function Quad(k, spr, x, y, w, h)
  local i = Take(k)
  if i == nil then
    return
  end
  local l = L[k]
  funcLuaMenuCommand(C.VISIBLE, l, i, true)
  funcLuaMenuCommand(C.SCALE, l, w / Q, h / Q, 1, i)
  SetSprite(l, ART, spr, NODE_QUAD, i)
  funcLuaMenuCommand(C.POS, l, x, -y, 0, i)
  funcLuaMenuCommand(C.PRIM_COLOR, l, i, MESH_QUAD, 1, 1, 1)
end

-- a flat quad from (x0, y0) to (x1, y1)
local function Rect(k, spr, x0, y0, x1, y1)
  if x1 <= x0 or y1 <= y0 then
    return
  end
  Quad(k, spr, (x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0)
end

-- a free text centred on (x, y) at `scale` in a retail font style
local function Txt(s, x, y, scale, style)
  if s == nil or s == "" then
    return
  end
  local i = Take("txt")
  if i == nil then
    return
  end
  local l = L.txt
  funcLuaMenuCommand(C.VISIBLE, l, i, true)
  funcLuaMenuCommand(C.POS, l, x, -y, 0, i)
  funcLuaMenuCommand(C.SCALE, l, scale, scale, 1, i)
  funcLuaMenuCommand(C.TEXT_STYLE, l, i, TXT_ON, style)
  funcLuaMenuCommand(C.TEXT, l, TXT_ON, s, i)
  funcLuaMenuCommand(C.TEXT, l, TXT_OFF, "", i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, l, TXT_ON, true, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, l, TXT_OFF, false, i)
end

-- a text left-aligned at x (the text box is 608 px wide, centred on the instance's origin)
local function TxtL(s, x, y, scale, style)
  Txt(s, x + G.TXT_HALF * scale, y, scale, style)
end

-- a string's width in glyph units (CJK = 2) and its cut to `units` with «…»
local function Units(s)
  local u = 0
  for ch in tostring(s or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    u = u + (ch:byte(1) >= 0xE3 and 2 or 1)
  end
  return u
end

local function Fit(s, units)
  s = tostring(s or "")
  if units <= 0 or Units(s) <= units then
    return s
  end
  local out, u = {}, 0
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    local w = ch:byte(1) >= 0xE3 and 2 or 1
    if u + w > units - 1 then
      break
    end
    out[#out + 1] = ch
    u = u + w
  end
  return (table.concat(out):gsub("%s+$", "")) .. "…"
end

-- a team row: crest + name (the team row object, its plate hidden); (x, y) = its left edge / vertical centre
local function Row(r, x, y, s, maxpx)
  local i = Take("row")
  if i == nil then
    return
  end
  local l = L.row
  funcLuaMenuCommand(C.VISIBLE, l, i, true)
  funcLuaMenuCommand(C.SCALE, l, s, s, 1, i)
  funcLuaMenuCommand(C.POS, l, x, -y, 0, i)
  for _, m in ipairs(PLATE) do
    funcLuaMenuCommand(C.MESH_VISIBLE, l, m, false, i)
  end
  local name = Fit(VRFW_Team.Name(r.team), math.floor(maxpx / (G.NAME_PX * s * G.NAME_CHAR)))
  local white = r.me == true
  funcLuaMenuCommand(C.TEXT, l, TXT_ON, white and name or "", i)
  funcLuaMenuCommand(C.TEXT, l, TXT_OFF, white and "" or name, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, l, TXT_ON, white, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, l, TXT_OFF, not white, i)
  funcLuaMenuCommand(C.PRIM_COLOR, l, i, MESH_EMBLEM, 1, 1, 1)
  local a = r.out and OUT_ALPHA or 1
  pcall(funcLuaMenuCommand, C.MODEL_ALPHA, l, i, 0, a)
  pcall(funcLuaMenuCommand, C.TEXT_ALPHA, l, i, TXT_ON, a)
  pcall(funcLuaMenuCommand, C.TEXT_ALPHA, l, i, TXT_OFF, a)
  VRFW_Team.Emblem(L.row, i, r.team, S.emb)
end

-- a goal difference: «+2», «0», «-1»
local function Dg(n)
  n = n or 0
  return n > 0 and ("+" .. n) or tostring(n)
end

-- one group's card at (x, y), w x h
local function Card(grp, M, x, y, w, h, pitch)
  local K = G.CARD
  local sx, sy = w / (K.W - K.L - K.R), h / (K.H - K.T - K.B)
  Quad("card", SP.card, x - K.L * sx + K.W * sx / 2, y - K.T * sy + K.H * sy / 2, K.W * sx, K.H * sy)
  local sk = K.SK * sx
  local function lx(yy)
    return x + sk * (1 - (yy - y) / h)
  end
  local function rx(yy)
    return x + w - sk * (yy - y) / h
  end
  -- the columns (constant over the card: inside its slanted edges at every height)
  local xr = x + w - sk - 3
  local ptsx = xr - M.pad_r - M.ptsw / 2
  local xs = {}
  local nc = #M.cols
  xs[nc] = ptsx
  for c = nc - 1, 1, -1 do
    xs[c] = ptsx - M.ptsw / 2 - M.cw * (nc - c - 0.5)
  end
  local num_left = ptsx - M.ptsw / 2 - M.cw * (nc - 1)
  local form_right = num_left - 10
  local limit = M.form == "col" and (form_right - 3 * M.dot_pitch - 6) or (num_left - 8)
  -- the header band, its strokes and title
  local hb = y + M.head
  local bx0, bx1 = lx(y + M.head / 2), rx(y + M.head / 2)
  Rect("band", SP.head, bx0, y, bx1, hb)
  local stx = M.labels > 0 and (bx1 - M.head * 2.4) or (num_left - M.head * 1.4)
  Quad("mark", SP.stroke, stx, y + M.head / 2, M.head * 0.5, M.head)
  Quad("mark", SP.stroke2, stx + M.head * 0.55, y + M.head / 2, M.head * 0.3, M.head)
  TxtL(string.upper(Text("group_" .. tostring(grp.n or 0))), lx(y) + 18, y + M.head / 2, M.title_s, G.ST.title)
  -- the row's left part: the position, then the crest
  local xl = lx(y) + 3
  local pos_x = xl + G.QBAR + M.pos_w / 2
  local s = math.min(M.s_max, pitch * G.FILL / G.PLATE_H)
  local ox = xl + G.QBAR + M.pos_w - G.CREST_IN * s
  local name_x = ox + G.NAME_L * s
  -- the column labels: under the band, or in it (tiny)
  if M.labels > 0 then
    local ly = hb + M.labels / 2
    TxtL(Text("col_team"), name_x, ly, M.label_s, G.ST.label_l)
    if M.form == "col" then
      Txt(Text("col_form"), form_right - 1.5 * M.dot_pitch, ly, M.label_s, G.ST.label)
    end
  end
  for c, k in ipairs(M.cols) do
    local st = M.labels == 0 and G.ST.label_head or (k == "pts" and G.ST.label_pts or G.ST.label)
    Txt(Text("col_" .. k), xs[c], M.labels > 0 and (hb + M.labels / 2) or (y + M.head / 2), M.label_s, st)
  end
  -- the rows
  local top = hb + M.labels + G.PAD
  for k = 1, 4 do
    local r = grp.rows and grp.rows[k]
    if r and (r.team or 0) ~= 0 then
      local ry = top + (k - 1) * pitch
      local yc = ry + pitch / 2
      local rl, rr = lx(ry) + 3, rx(ry + pitch) - 3
      local qual = (r.pos or k) <= 2
      if r.me then
        Rect("band", SP.me, rl, ry + 1, rr, ry + pitch - 1)
      elseif qual then
        Rect("band", SP.qual_tint, rl, ry + 1, rr, ry + pitch - 1)
      end
      if qual then
        Rect("mark", SP.qual, rl, ry + 1, rl + G.QBAR, ry + pitch - 1)
      end
      if k < 4 then
        Rect("mark", SP.sep, rl + G.QBAR + 4, ry + pitch - G.SEP / 2, rr, ry + pitch + G.SEP / 2)
      end
      Rect("mark", r.me and SP.pts_me or SP.pts, ptsx - M.ptsw / 2, ry + 2, ptsx + M.ptsw / 2, ry + pitch - 2)
      local st_num = r.me and G.ST.num_me or G.ST.num
      Txt(tostring(r.pos or k), pos_x, yc, M.num_s, st_num)
      Row(r, ox, yc + M.name_dy, s, limit - name_x)
      for c, key in ipairs(M.cols) do
        local val = key == "dg" and Dg(r.dg) or tostring(r[key] or 0)
        if key == "pts" then
          Txt(val, xs[c], yc, M.pts_s, r.me and G.ST.pts_me or G.ST.pts)
        else
          Txt(val, xs[c], yc, M.num_s, (G.DIM[key] and not r.me) and G.ST.num_dim or st_num)
        end
      end
      -- the form: dots under the name (compact) or in their column (wide; the matchdays not played yet as rings)
      local form = tostring(r.form or "")
      if M.form == "under" then
        for f = 1, #form do
          local spr = SP[form:sub(f, f)]
          if spr then
            Quad("mark", spr, name_x + M.dot / 2 + (f - 1) * M.dot_pitch, yc + M.dot_dy, M.dot, M.dot)
          end
        end
      elseif M.form == "col" then
        for f = 1, 3 do
          local spr = SP[form:sub(f, f)] or SP.none
          Quad("mark", spr, form_right - (3 - f + 0.5) * M.dot_pitch, yc, M.dot, M.dot)
        end
      end
    end
  end
end

-- the legend under the cards: the qualification zone, the player's team, the form dots
local function Legend(v, M)
  local y, x = G.LEGEND_Y, G.LEGEND_X
  local ls = 0.9
  local function item(txt)
    TxtL(txt, x, y, ls, G.ST.legend)
    x = x + Units(txt) * 26 * ls * 0.45 + 44
  end
  Rect("mark", SP.qual, x, y - 13, x + 10, y + 13)
  x = x + 20
  item(Text("legend_qualify_" .. tostring(v.qualify or 0)))
  Rect("mark", SP.me, x, y - 13, x + 10, y + 13)
  x = x + 20
  item(Text("legend_you"))
  if M.form then
    for _, f in ipairs({ "W", "D", "L" }) do
      Quad("mark", SP[f], x + 9, y, 18, 18)
      x = x + 24
      local t = Text("form_" .. f:lower())
      TxtL(t, x, y, ls, G.ST.legend)
      x = x + Units(t) * 26 * ls * 0.45 + 18
    end
    item(Text("legend_form"))
  end
end

-- the grid of n groups: mode, columns, rows (every group on this one page)
local function Grid(n)
  if n <= 2 then
    return "wide", math.max(1, n), 1
  elseif n <= 4 then
    return "wide", 2, 2
  elseif n <= 8 then
    return "compact", 4, 2
  end
  return "tiny", 4, math.ceil(n / 4)
end

local function DrawGroups(v)
  local groups = v.groups or {}
  local n = #groups
  S.groups, S.mode = 0, ""
  if n == 0 then
    return
  end
  local mode, cols, rows = Grid(n)
  local M = G.MODES[mode]
  local cw = (G.W - 2 * G.MX - (cols - 1) * G.GAP_X) / cols
  if cols == 1 then
    cw = math.min(cw, G.WIDE_MAX)
  end
  local x0 = (G.W - (cols * cw + (cols - 1) * G.GAP_X)) / 2
  local ch_max = (G.Y1 - G.Y0 - (rows - 1) * G.GAP_Y) / rows
  local pitch = math.min(M.pitch_max, (ch_max - M.head - M.labels - 2 * G.PAD) / 4)
  local ch = M.head + M.labels + 2 * G.PAD + 4 * pitch
  local top = (G.Y0 + G.Y1) / 2 - (rows * ch + (rows - 1) * G.GAP_Y) / 2
  for gi, grp in ipairs(groups) do
    local c, r = (gi - 1) % cols, math.floor((gi - 1) / cols)
    if r < rows then
      Card(grp, M, x0 + c * (cw + G.GAP_X), top + r * (ch + G.GAP_Y), cw, ch, pitch)
      S.groups = S.groups + 1
    end
  end
  Legend(v, M)
  S.mode = string.format("%s %dx%d", mode, cols, rows)
end

-- ---- the league's standings (Battle Bay Deluxe 1.45.0, CMND_BBD_TOURN_VIEW kind "league") -------------------------
-- One card of the group tables' look, the teams of this standings page (v.standings, at most v.page_rows): position,
-- the team on the bracket's plate (its team strip, crest and name: the overlay's BBT_Plate), the player's plate in the
-- bracket's gold frame (bbd_tn_frame_l, BBT_Focus), PJ G E P GF GC DG Pts, the last V.FORM results as dots; the first
-- place's green bar (the champion's place). The page among the pages is the host's title («(k/n)»).
local LG = {
  W_MAX = 1320, head = 50, labels = 32, pitch_max = 66, s_max = 392 / 520, pos_w = 56, cw = 64, ptsw = 76, pad_r = 18,
  cols = { "pj", "g", "e", "p", "gf", "gc", "dg", "pts" }, dot = 22, dot_pitch = 28, form = 5, form_gap = 24,
  plate_gap = 20, name_pad = 24, num_s = 0.95, pts_s = 0.95, title_s = 1.0, label_s = 0.95,
  -- the bracket's plate (team06_02 list plate: 520 x 72 at scale 1) and its gold frame (the strip grown 8 px a side)
  PLATE_W = 520, FRAME_W = 408 / 392, FRAME_H = 88 / 72,
  -- the team strips in the order of scripts/lib/plate_colors.lua M.names (a row's .strip = its 1-based index)
  STRIPS = { "red", "orange", "yellow", "green", "cyan", "blue", "purple", "pink", "black", "silver" },
  PLATE_ATLAS = 143680280,   -- crc32("#/menu/102_team/team06/team06_02/team06_02.g4tx"): the plate's own sprite
  PLATE_ATLAS_PATH = "#/menu/102_team/team06/team06_02/team06_02.g4tx",
}
local LG_SPR = nil

-- the sprite crcs of the league's pieces (once)
local function LeagueSprites()
  if LG_SPR == nil then
    LG_SPR = { strip = {}, frame = Crc("bbd_tn_frame_l"), plate = Crc("list_base_xs01_off"),
      neutral = Crc("bbd_tn_strip_black"), focus = Crc("bbd_tn_line_me") }
    for i, n in ipairs(LG.STRIPS) do
      LG_SPR.strip[i] = Crc("bbd_tn_strip_" .. n)
    end
  end
  return LG_SPR
end

-- a team on the bracket's plate: (x, y) = its left edge / vertical centre, scale s; the name cut to maxpx.
-- 1.58.0 (owner 2026-10-29: in game only 2 of 12 standings rows showed their plate, the others a white name on the
-- white card): the plate is its team strip drawn as a quad of the band pool (under the row pool) at the list plate's
-- size, the row object on top with its own plate meshes hidden (its crest and a white name). The strip is the team's
-- colour (scripts/lib/plate_colors.lua: from its emblem); a team without one gets the dark neutral strip. Before,
-- the strip was swapped into the row object's own plate texture node, which kept showing nothing on most instances.
local function Plate(r, x, y, s, maxpx)
  local sp = LeagueSprites()
  local spr = sp.strip[tonumber(r.strip) or 0] or sp.neutral
  Quad("band", spr, x + LG.PLATE_W * s / 2, y, LG.PLATE_W * s, G.PLATE_H * s)
  local i = Take("row")
  if i == nil then
    return
  end
  local l = L.row
  funcLuaMenuCommand(C.VISIBLE, l, i, true)
  funcLuaMenuCommand(C.SCALE, l, s, s, 1, i)
  funcLuaMenuCommand(C.POS, l, x, -y, 0, i)
  for _, m in ipairs(PLATE) do
    funcLuaMenuCommand(C.MESH_VISIBLE, l, m, false, i)
  end
  local name = Fit(VRFW_Team.Name(r.team), math.floor(maxpx / (G.NAME_PX * s * G.NAME_CHAR)))
  local white = true
  funcLuaMenuCommand(C.TEXT, l, TXT_ON, white and name or "", i)
  funcLuaMenuCommand(C.TEXT, l, TXT_OFF, white and "" or name, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, l, TXT_ON, white, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, l, TXT_OFF, not white, i)
  funcLuaMenuCommand(C.PRIM_COLOR, l, i, MESH_EMBLEM, 1, 1, 1)
  pcall(funcLuaMenuCommand, C.MODEL_ALPHA, l, i, 0, 1)
  pcall(funcLuaMenuCommand, C.TEXT_ALPHA, l, i, TXT_ON, 1)
  pcall(funcLuaMenuCommand, C.TEXT_ALPHA, l, i, TXT_OFF, 1)
  VRFW_Team.Emblem(L.row, i, r.team, S.emb)
end

-- 1.51.0 (owner 2026-10-28: «bordes en mala calidad»): the League cards drawn 1:1 from their own art at the size the
-- screen shows them (research/scripts/bbd_league_art.py, atlas bbd_lg: the white slanted card, its baked shadow, the
-- navy header band and its strokes), never a small sprite stretched; the plates at the team strip's own width
-- (392 px = the list plate's 520 at scale 392 / 520). Keep LG_ART in sync with the script's CARDS / margins / SLANT.
-- 1.52.0: the hub dashboard's cards (bbd_lg_hero / _stand / _panel / _cal; the side menu, header band, fixture
-- cards, buttons, badge and bar are drawn by name with Art / QuadA).
local LG_ART = {
  ATLAS = "#/menu/220_img/bbd_lg/bbd_lg.g4tx", L = 6, T = 6, R = 14, B = 18, SK = 18,
  -- head: the art's header band height; STROKES: the band's two slanted strokes start STROKES x head from its right end
  -- (bbd_league_art.py card(): hx = x1 - head * 2.4)
  STROKES = 2.4,
  table = { spr = "bbd_lg_table", w = 1320, h = 860, head = 50 },
  hero = { spr = "bbd_lg_hero", w = 766, h = 354 }, stand = { spr = "bbd_lg_stand", w = 776, h = 354 },
  panel = { spr = "bbd_lg_panel", w = 508, h = 220 }, cal = { spr = "bbd_lg_cal", w = 1558, h = 214 },
}

-- a card's title centred on the visible part of its navy header band: from the band's slanted left edge (at the
-- title's height) to the start of the two strokes at its right end; the card at (x, y), w x h (as BigCard), head = the
-- band height the caller lays out with
local function CardTitle(kind, x, y, w, h, head, title, scale)
  local A = LG_ART
  local c = A[kind]
  local yc = y + head / 2
  local x0 = x + A.SK * (w / c.w) * (1 - (yc - y) / h)
  local x1 = x + w - A.STROKES * c.head * (w / c.w)
  Txt(title, (x0 + x1) / 2, yc, scale, G.ST.title_c)
end

-- a card of the League art at (x, y) (its box), w x h: its native sprite (scaled only when the box is not its size)
local function BigCard(kind, x, y, w, h)
  local A = LG_ART
  local c = A[kind]
  if A.atlas == nil then
    A.atlas = Crc(A.ATLAS)
  end
  c.crc = c.crc or Crc(c.spr)
  local sx, sy = w / c.w, h / c.h
  local i = Take("card")
  if i == nil then
    return A.SK
  end
  local l = L.card
  local fw, fh = (c.w + A.L + A.R) * sx, (c.h + A.T + A.B) * sy
  funcLuaMenuCommand(C.VISIBLE, l, i, true)
  funcLuaMenuCommand(C.SCALE, l, fw / Q, fh / Q, 1, i)
  SetSprite(l, A.atlas, c.crc, NODE_QUAD, i)
  funcLuaMenuCommand(C.POS, l, x - A.L * sx + fw / 2, -(y - A.T * sy + fh / 2), 0, i)
  funcLuaMenuCommand(C.PRIM_COLOR, l, i, MESH_QUAD, 1, 1, 1)
  return A.SK * sx
end

local function DrawLeague(v)
  local rows = v.standings or {}
  S.groups, S.mode = 0, ""
  local R = math.max(#rows, tonumber(v.page_rows) or #rows, 1)
  local w = math.min(LG.W_MAX, G.W - 2 * G.MX)
  local x = (G.W - w) / 2
  local pitch = math.min(LG.pitch_max, (G.Y1 - G.Y0 - LG.head - LG.labels - 2 * G.PAD) / R)
  local h = LG.head + LG.labels + 2 * G.PAD + R * pitch
  local y = (G.Y0 + G.Y1) / 2 - h / 2
  -- the card and its slanted edges (1.51.0: the card art 1:1, its header band and strokes baked in)
  local sk = BigCard("table", x, y, w, h)
  local function lx(yy)
    return x + sk * (1 - (yy - y) / h)
  end
  local function rx(yy)
    return x + w - sk * (yy - y) / h
  end
  -- the columns: the numbers from the right edge, the form left of them, the plate after the position
  local xr = x + w - sk - 3
  local ptsx = xr - LG.pad_r - LG.ptsw / 2
  local xs, nc = {}, #LG.cols
  xs[nc] = ptsx
  for c = nc - 1, 1, -1 do
    xs[c] = ptsx - LG.ptsw / 2 - LG.cw * (nc - c - 0.5)
  end
  local num_left = ptsx - LG.ptsw / 2 - LG.cw * (nc - 1)
  local form_right = num_left - LG.form_gap
  local form_left = form_right - LG.form * LG.dot_pitch
  -- the title on the card's header band
  local hb = y + LG.head
  CardTitle("table", x, y, w, h, LG.head, Text("league_title"), LG.title_s)
  -- the row's left part: the position, then the plate
  local xl = lx(y) + 3
  local pos_x = xl + G.QBAR + LG.pos_w / 2
  local s = math.min(LG.s_max, pitch * G.FILL / G.PLATE_H)
  local ox = xl + G.QBAR + LG.pos_w
  local name_x = ox + G.NAME_L * s
  local name_px = math.min((LG.PLATE_W - G.NAME_L - LG.name_pad) * s, form_left - LG.plate_gap - name_x)
  -- the column labels under the band
  local ly = hb + LG.labels / 2
  TxtL(Text("col_team"), name_x, ly, LG.label_s, G.ST.label_l)
  Txt(Text("col_form"), (form_left + form_right) / 2, ly, LG.label_s, G.ST.label)
  for c, k in ipairs(LG.cols) do
    Txt(Text("col_" .. k), xs[c], ly, LG.label_s, k == "pts" and G.ST.label_pts or G.ST.label)
  end
  local top = hb + LG.labels + G.PAD
  local sp = LeagueSprites()
  for k, r in ipairs(rows) do
    if (r.team or 0) ~= 0 then
      local ry = top + (k - 1) * pitch
      local yc = ry + pitch / 2
      local rl, rr = lx(ry) + 3, rx(ry + pitch) - 3
      if (r.pos or k) == 1 then
        Rect("mark", SP.qual, rl, ry + 1, rl + G.QBAR, ry + pitch - 1)
      end
      if k < #rows then
        Rect("mark", SP.sep, rl + G.QBAR + 4, ry + pitch - G.SEP / 2, rr, ry + pitch + G.SEP / 2)
      end
      Rect("mark", r.me and SP.pts_me or SP.pts, ptsx - LG.ptsw / 2, ry + 2, ptsx + LG.ptsw / 2, ry + pitch - 2)
      Txt(tostring(r.pos or k), pos_x, yc, LG.num_s, G.ST.num)
      -- the player's plate: the bracket's gold frame around it (under the plate, the frame's ring shows)
      if r.me then
        local pw = LG.PLATE_W * s
        Quad("mark", sp.frame, ox + pw / 2, yc, pw * LG.FRAME_W, G.PLATE_H * s * LG.FRAME_H)
      end
      Plate(r, ox, yc, s, name_px)
      for c, key in ipairs(LG.cols) do
        local val = key == "dg" and Dg(r.dg) or tostring(r[key] or 0)
        if key == "pts" then
          Txt(val, xs[c], yc, LG.pts_s, r.me and G.ST.pts_me or G.ST.pts)
        else
          Txt(val, xs[c], yc, LG.num_s, G.DIM[key] and G.ST.num_dim or G.ST.num)
        end
      end
      -- the last results, oldest first (the slots not played yet as rings)
      local form = tostring(r.form or "")
      for f = 1, LG.form do
        local spr = SP[form:sub(f, f)] or SP.none
        Quad("mark", spr, form_left + (f - 0.5) * LG.dot_pitch, yc, LG.dot, LG.dot)
      end
      S.groups = S.groups + 1
    end
  end
  -- owner 2026-10-28: no legend under the standings (it covered the button guide)
  S.mode = string.format("league page %d/%d, %d rows", v.page_n or 1, v.page_count or 1, #rows)
end

-- ---- the league's career hub and top scorers (Battle Bay Deluxe 1.48.0 / 1.52.0, view kinds "hub" / "scorers") --------
-- 1.52.0 (owner 2026-10-28, mock-up C): the hub is a career dashboard drawn here whole, the host (bbt_top.lua
-- BBT_LeagueHub) keeps the keys and tells the side menu's cursor through the parameter evt_bbd_lg_nav (0 Home,
-- 1 Calendar, 2 Competition, 3 Squad). Left: the blue side menu (the player's crest, team and level; the four
-- sections, the focused one on the list plate; «New league» and «Exit» buttons). Right: the league's header band (title,
-- matchday N of M, teams, the matchday progress bar, «N pts», the place badge, the Battle Bay logo), the next match
-- (crests, VS, the bracket's plates, place and points of both, «Play»), the standings (top HUB_TOP + the player),
-- three panels (top scorers, last results with the form, squad), the calendar (the next fixtures). Every number,
-- team and crest comes from the run (scripts/lib/tourney_view.lua hub_view). scorers: one card of the standings' look,
-- rank, the player's name, his team on the bracket's plate, his goals.
local HUB = {
  NAV = { X = 24, Y = 84, W = 294, H = 908, CREST = 112, CREST_Y = 162, NAME_Y = 244, LEVEL_Y = 278, SEP_Y = 306,
    ITEM_X = 40, ITEM_W = 262, ITEM_H = 66, ITEM_Y = 330, ITEM_PITCH = 80, ICON = 34, ICON_X = 74, LABEL_X = 112,
    PILL_Y = { 858, 924 }, PILL_W = 262, PILL_H = 56 },
  HEAD = { X = 338, Y = 84, W = 1558, H = 78, BAR_X0 = 790, BAR_X1 = 1370, BAR_Y = 112, BAR_H = 18, LABEL_Y = 146 },
  HERO = { X = 338, Y = 176, W = 766, H = 354, head = 50, CREST = 124, CREST_DX = 190, CREST_Y = 288, PLATE_S = 330 / 520,
    PLATE_Y = 382, INFO_Y = 422, BTN_W = 280, BTN_H = 52, BTN_Y = 454 },
  STAND = { X = 1120, Y = 176, W = 776, H = 354, head = 50, LABEL_Y = 240, TOP = 256, PITCH = 40, GAP = 16, CREST = 30 },
  PANEL = { Y = 544, W = 508, H = 220, head = 44, XS = { 338, 862, 1386 } },
  CAL = { X = 338, Y = 778, W = 1558, H = 214, head = 44, FIX_W = 292, FIX_H = 146, FIX_BAND = 30, GAP = 14, PAD = 18 },
  title_s = 1.0, band_title_s = 0.9, icon_h = 30,
}
-- the atlases of the retail sprites the hub shows (loaded by this screen's res, content\menus\bb_tournament.toml)
local HUB_ATLAS = {
  icons = "#/menu/200_icon/16_icon_list_tab/icon_list_tab.g4tx",   -- icon_list_tab_* (white)
  button = "#/menu/20_cmn/cmn03/cmn03_02/cmn03_02.g4tx",            -- cmd_btn_base01_on / _off
}
-- the side menu's sections: text key, icon (icon_list_tab_<name>); the host's order (bbt_top.lua BattleBayDeluxe.Tournament.HUB.NAV)
local HUB_NAV = {
  { key = "hub_nav_home", icon = "town01" },
  { key = "hub_calendar", icon = "history01" },
  { key = "hub_competition", icon = "vroad01" },
  { key = "hub_roster", icon = "uniform01" },
}
local P_NAV = 1776742798           -- crc32("evt_bbd_lg_nav"): parameter in, the side menu's cursor (the host's)
-- 1.58.0: crc32("evt_bbd_lg_focus"): parameter in, the dashboard panel the host's focus is on (0 = the side menu); the
-- order of bbt_top.lua BattleBayDeluxe.Tournament.HUB.PANELS: 1 next match, 2 standings, 3 top scorers, 4 last results, 5 squad, 6 calendar
local P_FOCUS = 2137390090
-- 1.70.0: crc32("evt_bbd_lg_cal_md"): parameter in, the matchday the host's focus is on in the calendar grid
local P_CAL_MD = 779224387
local SC = { name_w = 460, gap = 24, name_s = 1.25, name_px = 22 }
local CHARA_OF_CARD = 347353059    -- (card) -> chara id
local CHARA_NAME = 523676951       -- (chara id) -> name

-- a text of the mod with <VALUE> / <VALUE2> filled (the retail text value command)
local function TextValue2(key, a, b)
  local t = Text(key)
  local ok, r = pcall(funcLuaCommand, 910683996, t, "VALUE", a or 0, 0, 0, true)
  t = ok and r or t
  if b ~= nil then
    local ok2, r2 = pcall(funcLuaCommand, 910683996, t, "VALUE2", b, 0, 0, true)
    t = ok2 and r2 or t
  end
  return t
end

local function CharaName(card)
  local ok, id = pcall(funcLuaCommand, CHARA_OF_CARD, card)
  if not ok or type(id) ~= "number" or id == 0 then
    return ""
  end
  local okn, name = pcall(funcLuaCommand, CHARA_NAME, id)
  return okn and type(name) == "string" and name or ""
end

-- a sprite of another atlas on pool k: centre (x, y), w x h
local function QuadA(k, atlas, spr, x, y, w, h)
  local i = Take(k)
  if i == nil then
    return
  end
  local l = L[k]
  funcLuaMenuCommand(C.VISIBLE, l, i, true)
  funcLuaMenuCommand(C.SCALE, l, w / Q, h / Q, 1, i)
  SetSprite(l, Crc(atlas), Crc(spr), NODE_QUAD, i)
  funcLuaMenuCommand(C.POS, l, x, -y, 0, i)
  funcLuaMenuCommand(C.PRIM_COLOR, l, i, MESH_QUAD, 1, 1, 1)
end

-- a sprite of the League art (bbd_lg) at its own size, its box's top left at (x, y) (the cards' margins around it)
local function Art(k, spr, x, y, w, h)
  local A = LG_ART
  QuadA(k, A.ATLAS, spr, x - A.L + (w + A.L + A.R) / 2, y - A.T + (h + A.T + A.B) / 2, w + A.L + A.R, h + A.T + A.B)
end

-- a list-tab icon (white, 144 x 96) of height h centred on (x, y)
local function Icon(name, x, y, h)
  QuadA("mark", HUB_ATLAS.icons, "icon_list_tab_" .. name, x, y, h * 1.5, h)
end

-- a team's crest alone (the team row object, plate and name hidden) centred on (x, y), px tall
local function Crest(team, x, y, px)
  if (team or 0) == 0 then
    return
  end
  local s = px / 68
  local i = Take("row")
  if i == nil then
    return
  end
  local l = L.row
  funcLuaMenuCommand(C.VISIBLE, l, i, true)
  funcLuaMenuCommand(C.SCALE, l, s, s, 1, i)
  funcLuaMenuCommand(C.POS, l, x - 56 * s, -y, 0, i)
  for _, m in ipairs(PLATE) do
    funcLuaMenuCommand(C.MESH_VISIBLE, l, m, false, i)
  end
  funcLuaMenuCommand(C.TEXT, l, TXT_ON, "", i)
  funcLuaMenuCommand(C.TEXT, l, TXT_OFF, "", i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, l, TXT_ON, false, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, l, TXT_OFF, false, i)
  funcLuaMenuCommand(C.PRIM_COLOR, l, i, MESH_EMBLEM, 1, 1, 1)
  pcall(funcLuaMenuCommand, C.MODEL_ALPHA, l, i, 0, 1)
  VRFW_Team.Emblem(L.row, i, team, S.emb)
end

-- a card's header title with its list-tab icon on the navy band
local function BandTitle(x, y, head, icon, title)
  Icon(icon, x + 34, y + head / 2, HUB.icon_h)
  TxtL(title, x + 64, y + head / 2, HUB.band_title_s, G.ST.title)
end

-- a right-side caption on a card's band: centred at the band's right part
local function BandRight(x1, y, head, s)
  if s and s ~= "" then
    Txt(s, x1 - 150 - Units(s) * 6, y + head / 2, 0.9, G.ST.label_head)
  end
end

-- an integer parameter the host sets (0 when it is not set)
local function ParamInt(p)
  if VRFW_Param.Has(p) then
    local n = VRFW_Param.Get(p)
    if type(n) == "number" then
      return math.floor(n)
    end
  end
  return 0
end

local function NavCursor()
  return ParamInt(P_NAV)
end

local function FocusPanel()
  return ParamInt(P_FOCUS)
end

-- the focused panel's frame: four flat light-cyan bars (the player's path colour of the bracket) around its box
local function FocusFrame(x0, y0, x1, y1)
  local f, t = LeagueSprites().focus, 5
  Rect("mark", f, x0 - t - 2, y0 - t - 2, x1 + t + 2, y0 - 2)
  Rect("mark", f, x0 - t - 2, y1 + 2, x1 + t + 2, y1 + t + 2)
  Rect("mark", f, x0 - t - 2, y0 - 2, x0 - 2, y1 + 2)
  Rect("mark", f, x1 + 2, y0 - 2, x1 + t + 2, y1 + 2)
end

-- a pointer zone of the hub (screen px, y down) around a quad just drawn: kind "n" = side menu row n (bbt_top.lua
-- BattleBayDeluxe.Tournament.HUB.NAV, 0-based), "p" = dashboard panel n (BattleBayDeluxe.Tournament.HUB.PANELS); sent to the host after the drawing (SendZones)
local function Zone(kind, n, x0, y0, x1, y1)
  S.zones[#S.zones + 1] = string.format("%s,%d,%d,%d,%d,%d", kind, n, math.floor(x0), math.floor(y0), math.ceil(x1),
    math.ceil(y1))
end

-- the hub's zones to the host's pointer (bbt_top.lua BBT_HubZones, cross-menu call)
local function SendZones()
  if S.host ~= nil then
    pcall(funcLuaCommand, C.CROSS_CALL, S.host, "BBT_HubZones", table.concat(S.zones, ";"))
  end
end

-- the side menu
local function DrawNav(v, cur)
  local N = HUB.NAV
  Art("card", "bbd_lg_nav", N.X, N.Y, N.W, N.H)
  local cx = N.X + N.W / 2
  Crest(v.team, cx, N.CREST_Y, N.CREST)
  Txt(Fit(VRFW_Team.Name(v.team), 16), cx, N.NAME_Y, 0.85, G.ST.pts_me)
  if v.level then
    Txt(TextValue2("hub_level", v.level), cx, N.LEVEL_Y, 1.0, G.ST.label_head)
  end
  Rect("mark", SP.sep, N.X + 20, N.SEP_Y - 1, N.X + N.W - 20, N.SEP_Y + 1)
  for k, it in ipairs(HUB_NAV) do
    local y = N.ITEM_Y + (k - 1) * N.ITEM_PITCH
    local yc = y + N.ITEM_H / 2
    local on = cur == k - 1
    if on then
      -- 1.56.0 (owner 2026-10-29: the selected row lost its icon): the lit plate on the band pool (layer 547), under
      -- the mark pool (548) that draws the icon; two quads of one pool have no fixed order
      QuadA("band", LG.PLATE_ATLAS_PATH, "list_base_xs01_on", N.ITEM_X + N.ITEM_W / 2, yc, N.ITEM_W, N.ITEM_H)
      QuadA("band", LG.PLATE_ATLAS_PATH, "list_base_xs01_ol", N.ITEM_X + N.ITEM_W / 2, yc, N.ITEM_W, N.ITEM_H)
    end
    Icon(it.icon, N.ICON_X, yc, N.ICON)
    TxtL(Text(it.key), N.LABEL_X, yc, on and 0.9 or 0.85, G.ST.title)
    Zone("n", k - 1, N.ITEM_X, y, N.ITEM_X + N.ITEM_W, y + N.ITEM_H)
  end
  -- 1.58.0 (owner 2026-10-29): «Nueva liga» / «Salir» are side menu rows (cursor 4 / 5): their slanted plate (card
  -- pool, under the band pool's lit plate), lit like the other rows when the cursor is on them
  for k, key in ipairs({ "new_league", "hub_exit" }) do
    local y = N.PILL_Y[k]
    local yc = y + N.PILL_H / 2
    QuadA("card", LG_ART.ATLAS, "bbd_lg_pill", cx, yc, N.PILL_W + 4, N.PILL_H + 4)
    local on = cur == #HUB_NAV + k - 1
    if on then
      QuadA("band", LG.PLATE_ATLAS_PATH, "list_base_xs01_on", cx, yc, N.PILL_W, N.PILL_H)
      QuadA("band", LG.PLATE_ATLAS_PATH, "list_base_xs01_ol", cx, yc, N.PILL_W, N.PILL_H)
    end
    Txt(Text(key), cx, yc, on and 0.85 or 0.8, G.ST.pts_me)
    Zone("n", #HUB_NAV + k - 1, cx - N.PILL_W / 2, y, cx + N.PILL_W / 2, y + N.PILL_H)
  end
end

-- the header band: league, matchday, progress, points, place, logo
local function DrawHeader(v)
  local H = HUB.HEAD
  Art("card", "bbd_lg_head", H.X, H.Y, H.W, H.H)
  TxtL(Text("hub_title"), H.X + 30, H.Y + 26, 1.0, G.ST.title)
  local md = v.fixture and v.fixture.md or v.mds
  TxtL(TextValue2("league_md_of", md or 0, v.mds or 0) .. "  ·  " .. TextValue2("hub_teams", v.size or 0),
    H.X + 30, H.Y + 58, 0.8, G.ST.legend)
  -- the progress bar: one notch per matchday, the played ones lit
  local mds = math.max(1, v.mds or 1)
  local played = math.max(0, math.min(mds, v.played or 0))
  QuadA("band", LG_ART.ATLAS, "bbd_lg_bar_base", (H.BAR_X0 + H.BAR_X1) / 2, H.BAR_Y + H.BAR_H / 2, H.BAR_X1 - H.BAR_X0 + 8,
    H.BAR_H + 8)
  local inner = H.BAR_X1 - H.BAR_X0
  if played > 0 then
    local w = inner * played / mds
    QuadA("band", LG_ART.ATLAS, "bbd_lg_bar_fill", H.BAR_X0 + w / 2, H.BAR_Y + H.BAR_H / 2, w, H.BAR_H)
  end
  if mds <= 40 then
    for k = 1, mds - 1 do
      local x = H.BAR_X0 + inner * k / mds
      Rect("mark", SP.sep, x - 1, H.BAR_Y, x + 1, H.BAR_Y + H.BAR_H)
    end
  end
  Txt(TextValue2("hub_played", played), H.BAR_X0 + 70, H.LABEL_Y, 0.85, G.ST.label_head)
  Txt(TextValue2("hub_left", mds - played), H.BAR_X1 - 70, H.LABEL_Y, 0.85, G.ST.label_head)
  -- 1.58.0 (owner 2026-10-29): no points / place badge / Battle Bay logo here (the standings card shows them)
end

-- the next match
local function DrawHero(v, focus)
  local P = HUB.HERO
  local x0, y0, x1 = P.X, P.Y, P.X + P.W
  BigCard("hero", x0, y0, P.W, P.H)
  BandTitle(x0 + 8, y0, P.head, "quest01", Text("hub_next"))
  local f = v.fixture
  local cx = (x0 + x1) / 2
  if not f then
    Txt(Text("league_over"), cx, y0 + P.H / 2 + 20, 1.0, G.ST.num)
    return
  end
  BandRight(x1, y0, P.head, TextValue2("hub_md_short", f.md) .. "  ·  " .. Text(f.home.me and "hub_home" or "hub_away"))
  local s = P.PLATE_S
  local pw = LG.PLATE_W * s
  local sp = LeagueSprites()
  for side, r in ipairs({ f.home, f.away }) do
    local ccx = side == 1 and (x0 + P.CREST_DX) or (x1 - P.CREST_DX)
    Crest(r.team, ccx, P.CREST_Y, P.CREST)
    local px = side == 1 and (x0 + 30) or (x1 - 30 - pw)
    if r.me then
      Quad("mark", sp.frame, px + pw / 2, P.PLATE_Y, pw * LG.FRAME_W, G.PLATE_H * s * LG.FRAME_H)
    end
    Plate(r, px, P.PLATE_Y, s, (LG.PLATE_W - G.NAME_L - LG.name_pad) * s)
    if (r.pos or 0) > 0 then
      Txt(TextValue2("hub_place", r.pos, r.pts or 0), px + pw / 2, P.INFO_Y, 0.85, G.ST.num)
    end
  end
  Txt(Text("hub_vs"), cx, P.CREST_Y, 1.6, G.ST.pts)
  -- «Play»: the retail command button, lit while the dashboard's focus is on this card (Enter plays it)
  local by = P.BTN_Y + P.BTN_H / 2
  QuadA("mark", HUB_ATLAS.button, focus == 1 and "cmd_btn_base01_on" or "cmd_btn_base01_off", cx, by, P.BTN_W, P.BTN_H)
  Txt(Text("hub_play"), cx, by, 0.95, G.ST.pts_me)
  S.play_zone = { cx - P.BTN_W / 2, P.BTN_Y, cx + P.BTN_W / 2, P.BTN_Y + P.BTN_H }
end

-- the standings: the first rows and the player's
local function DrawStandings(v)
  local P = HUB.STAND
  local x0, y0, x1 = P.X, P.Y, P.X + P.W
  BigCard("stand", x0, y0, P.W, P.H)
  BandTitle(x0 + 8, y0, P.head, "vroad01", Text("hub_standings"))
  local cols = { { "pj", x1 - 196 }, { "dg", x1 - 124 }, { "pts", x1 - 56 } }
  TxtL(Text("col_team"), x0 + 116, P.LABEL_Y, 0.9, G.ST.label_l)
  for _, c in ipairs(cols) do
    Txt(Text("col_" .. c[1]), c[2], P.LABEL_Y, 0.9, c[1] == "pts" and G.ST.label_pts or G.ST.label)
  end
  local y = P.TOP
  for _, r in ipairs(v.top or {}) do
    if r.gap then
      Txt("…", (x0 + x1) / 2, y + P.GAP / 2, 0.9, G.ST.num_dim)
      y = y + P.GAP
    end
    local yc = y + P.PITCH / 2
    if r.me then
      Rect("mark", SP.me, x0 + 22, y + 2, x1 - 30, y + P.PITCH - 2)
    else
      Rect("mark", SP.sep, x0 + 30, y + P.PITCH - 1, x1 - 30, y + P.PITCH + 1)
    end
    if r.pos == 1 then
      Rect("mark", SP.qual, x0 + 22, y + 2, x0 + 22 + G.QBAR, y + P.PITCH - 2)
    end
    Txt(tostring(r.pos or 0), x0 + 48, yc, 0.9, r.me and G.ST.num_me or G.ST.num)
    Crest(r.team, x0 + 92, yc, P.CREST)
    local name = Fit(VRFW_Team.Name(r.team), 26)
    if r.me then
      TxtL(name, x0 + 116, yc, 0.72, G.ST.title)
    else
      TxtL(name, x0 + 116, yc, 1.05, G.ST.label_l)
    end
    local vals = { pj = tostring(r.pj or 0), dg = Dg(r.dg), pts = tostring(r.pts or 0) }
    for _, c in ipairs(cols) do
      local st = r.me and G.ST.num_me or (c[1] == "pts" and G.ST.num or G.ST.num_dim)
      Txt(vals[c[1]], c[2], yc, c[1] == "pts" and 0.95 or 0.85, st)
    end
    y = y + P.PITCH
  end
end

-- a player's miniface (VRFW_FaceIcon: the list character card, portrait only) centred on (x, y), px tall; nothing
-- drawn while it loads or when it cannot be drawn
local function Face(card, x, y, px)
  if (card or 0) == 0 or VRFW_FaceIcon == nil then
    return
  end
  local i = Take("face")
  if i == nil then
    return
  end
  funcLuaMenuCommand(C.VISIBLE, L.face, i, true)
  VRFW_FaceIcon.Card(L.face, i, { card = card }, x, y, px, { use_args = true })
end

-- top scorers: rank, miniface, crest, name, goals
local function DrawScorersPanel(v, x0)
  local P = HUB.PANEL
  local y0, x1 = P.Y, x0 + P.W
  BigCard("panel", x0, y0, P.W, P.H)
  BandTitle(x0 + 8, y0, P.head, "help01", Text("scorers_title"))
  local rows = v.scorers or {}
  if #rows == 0 then
    Txt(Text("scorers_none"), (x0 + x1) / 2, y0 + P.head + (P.H - P.head) / 2, 0.85, G.ST.num_dim)
    return
  end
  local pitch = (P.H - P.head - 12) / 3
  for k, r in ipairs(rows) do
    local y = y0 + P.head + 6 + (k - 1) * pitch
    local yc = y + pitch / 2
    Txt(tostring(r.pos or k), x0 + 40, yc, 0.95, G.ST.num)
    -- 1.61.0: the player's miniface, the team's crest to its right, the name on one line after them
    local fp, cp = pitch * 0.9, pitch * 0.6
    Face(r.card, x0 + 66 + fp / 2, yc, fp)
    local cx = x0 + 66 + fp + 8 + cp / 2
    Crest(r.team, cx, yc, cp)
    TxtL(Fit(CharaName(r.card), 20), cx + cp / 2 + 12, yc, 1.1, G.ST.label_l)
    Rect("mark", r.me and SP.pts_me or SP.pts, x1 - 96, y + 6, x1 - 40, y + pitch - 6)
    Txt(tostring(r.goals or 0), x1 - 68, yc, 0.95, r.me and G.ST.pts_me or G.ST.pts)
    if k < #rows then
      Rect("mark", SP.sep, x0 + 30, y + pitch - 1, x1 - 30, y + pitch + 1)
    end
  end
end

-- last results: the form dots, then the latest matches (newest first)
local function DrawResultsPanel(v, x0)
  local P = HUB.PANEL
  local y0, x1 = P.Y, x0 + P.W
  BigCard("panel", x0, y0, P.W, P.H)
  BandTitle(x0 + 8, y0, P.head, "history01", Text("hub_results"))
  local res = v.results or {}
  local fy = y0 + P.head + 26
  TxtL(Text("col_form"), x0 + 34, fy, 0.9, G.ST.label_l)
  local form = tostring(v.form or "")
  for f = 1, LG.form do
    local spr = SP[form:sub(f, f)] or SP.none
    Quad("mark", spr, x0 + 150 + (f - 1) * 38, fy, 28, 28)
  end
  if #res == 0 then
    Txt(Text("hub_no_results"), (x0 + x1) / 2, fy + 70, 0.85, G.ST.num_dim)
    return
  end
  local pitch = 40
  local y = fy + 22
  for k = #res, math.max(1, #res - 2), -1 do
    local r = res[k]
    local yc = y + pitch / 2
    Txt(TextValue2("hub_md_short", r.md or 0), x0 + 46, yc, 0.8, G.ST.num_dim)
    Txt(Text(r.home and "hub_home_short" or "hub_away_short"), x0 + 92, yc, 0.8, G.ST.num_dim)
    Crest(r.team, x0 + 134, yc, 30)
    TxtL(Fit(VRFW_Team.Name(r.team), 18), x0 + 158, yc, 1.0, G.ST.label_l)
    Rect("mark", SP.pts_me, x1 - 150, y + 6, x1 - 76, y + pitch - 6)
    Txt(string.format("%d - %d", r.gf or 0, r.ga or 0), x1 - 113, yc, 0.85, G.ST.num_me)
    Quad("mark", SP[r.r] or SP.none, x1 - 50, yc, 24, 24)
    y = y + pitch
  end
end

-- the squad: crest, team, level, the team's own top scorer
local function DrawSquadPanel(v, x0)
  local P = HUB.PANEL
  local y0, x1 = P.Y, x0 + P.W
  BigCard("panel", x0, y0, P.W, P.H)
  BandTitle(x0 + 8, y0, P.head, "uniform01", Text("hub_roster"))
  local by = y0 + P.head
  Crest(v.team, x0 + 92, by + (P.H - P.head) / 2, 112)
  local tx = x0 + 172
  TxtL(Fit(VRFW_Team.Name(v.team), 22), tx, by + 34, 1.2, G.ST.label_l)
  if v.level then
    TxtL(TextValue2("hub_level", v.level), tx, by + 72, 1.0, G.ST.label_l)
  end
  if v.my_scorer then
    TxtL(Text("hub_team_scorer"), tx, by + 108, 0.85, G.ST.label_l)
    TxtL(Fit(CharaName(v.my_scorer.card), 20) .. "  ·  " .. TextValue2("hub_goals", v.my_scorer.goals or 0), tx,
      by + 136, 1.0, G.ST.label_l)
  end
end

-- a matchday card of the player's match (the hub's calendar and the calendar section's grid) at (x, y), the card art's
-- size: «Jornada N», home / away, both crests with VS and the rival's name; the next match on the lit art; a match
-- played: its score between the crests and the result dot (W / D / L, as «Últimos resultados»); team = his team
local function FixtureCard(team, r, x, y)
  local P = HUB.CAL
  Art("band", r.next and "bbd_lg_fix_next" or "bbd_lg_fix", x, y, P.FIX_W, P.FIX_H)
  local by = y + P.FIX_BAND / 2
  TxtL(TextValue2("calendar_md_short", r.md or 0), x + 18, by, 0.62, G.ST.title)
  if r.none then
    return
  end
  Txt(Text(r.home and "hub_home" or "hub_away"), x + P.FIX_W - 112, by, 0.8, G.ST.label_head)
  local cx, cy = x + P.FIX_W / 2, y + P.FIX_BAND + 42
  local left, right = r.home and team or r.team, r.home and r.team or team
  local dx = r.done and 86 or 62
  Crest(left, cx - dx, cy, 54)
  Crest(right, cx + dx, cy, 54)
  if r.done then
    local gf, ga = r.gf or 0, r.ga or 0
    local hs, as = r.home and gf or ga, r.home and ga or gf
    Rect("mark", SP.pts_me, cx - 40, cy - 16, cx + 40, cy + 16)
    Txt(string.format("%d - %d", hs, as), cx, cy, 0.85, G.ST.num_me)
    Quad("mark", SP[r.r] or SP.none, x + P.FIX_W - 22, by, 20, 20)
  else
    Txt(Text("hub_vs"), cx, cy, 0.9, G.ST.pts)
  end
  Txt(Fit(VRFW_Team.Name(r.team), 22), cx, y + P.FIX_H - 22, 0.95, G.ST.label)
end

-- the calendar: the player's next fixtures
local function DrawCalendar(v)
  local P = HUB.CAL
  local x0, y0, x1 = P.X, P.Y, P.X + P.W
  BigCard("cal", x0, y0, P.W, P.H)
  BandTitle(x0 + 8, y0, P.head, "history01", Text("hub_calendar"))
  local fx = v.fixtures or {}
  if #fx == 0 then
    Txt(Text("league_over"), (x0 + x1) / 2, y0 + P.head + (P.H - P.head) / 2, 1.0, G.ST.num)
    return
  end
  local fy = y0 + P.head + 12
  for k, r in ipairs(fx) do
    local x = x0 + P.PAD + (k - 1) * (P.FIX_W + P.GAP)
    FixtureCard(v.team, r, x, fy)
    S.cal_zones[#S.cal_zones + 1] = { x, fy, x + P.FIX_W, fy + P.FIX_H }
  end
end

-- 1.70.0 (owner 2026-10-29: «El calendario tienen que ser todas las jornadas que hay»): the calendar section's grid
-- (view kind "fixtures", scripts/lib/tourney_view.lua fixtures_view): every matchday of the page as the hub's cards,
-- v.cols columns, centred on the page; the card of the host's focus (parameter evt_bbd_lg_cal_md, a matchday) framed;
-- one pointer zone a card (kind "c" = its matchday) sent to the host
local function DrawFixtures(v)
  S.groups, S.mode = 0, ""
  S.zones = {}
  local P = HUB.CAL
  local cards = v.cards or {}
  local cols = math.max(1, math.min(v.cols or #cards, #cards))
  local rows = math.ceil(#cards / cols)
  local gw = cols * P.FIX_W + (cols - 1) * P.GAP
  local gh = rows * P.FIX_H + (rows - 1) * P.GAP
  local x0, y0 = (G.W - gw) / 2, (G.Y0 + G.Y1) / 2 - gh / 2
  local focus = ParamInt(P_CAL_MD)
  for k, r in ipairs(cards) do
    local x = x0 + ((k - 1) % cols) * (P.FIX_W + P.GAP)
    local y = y0 + math.floor((k - 1) / cols) * (P.FIX_H + P.GAP)
    FixtureCard(v.team, r, x, y)
    if r.md == focus then
      FocusFrame(x, y, x + P.FIX_W, y + P.FIX_H)
    end
    Zone("c", r.md, x, y, x + P.FIX_W, y + P.FIX_H)
  end
  SendZones()
  S.groups = #cards
  S.mode = string.format("matchday grid: %d cards, page %d of %d, focus %d", #cards, v.page_n or 1, v.page_count or 1,
    focus)
end

local function DrawHub(v)
  S.groups, S.mode = 0, ""
  S.zones, S.play_zone, S.cal_zones = {}, nil, {}
  local cur = NavCursor()
  local focus = FocusPanel()
  DrawNav(v, cur)
  DrawHeader(v)
  DrawHero(v, focus)
  DrawStandings(v)
  DrawScorersPanel(v, HUB.PANEL.XS[1])
  DrawResultsPanel(v, HUB.PANEL.XS[2])
  DrawSquadPanel(v, HUB.PANEL.XS[3])
  DrawCalendar(v)
  local boxes = {
    { HUB.HERO.X, HUB.HERO.Y, HUB.HERO.X + HUB.HERO.W, HUB.HERO.Y + HUB.HERO.H },
    { HUB.STAND.X, HUB.STAND.Y, HUB.STAND.X + HUB.STAND.W, HUB.STAND.Y + HUB.STAND.H },
  }
  for k = 1, 3 do
    local x = HUB.PANEL.XS[k]
    boxes[#boxes + 1] = { x, HUB.PANEL.Y, x + HUB.PANEL.W, HUB.PANEL.Y + HUB.PANEL.H }
  end
  boxes[#boxes + 1] = { HUB.CAL.X, HUB.CAL.Y, HUB.CAL.X + HUB.CAL.W, HUB.CAL.Y + HUB.CAL.H }
  local b = boxes[focus]
  if b then
    FocusFrame(b[1], b[2], b[3], b[4])
  end
  -- the pointer: each panel's box, then the pieces drawn on them (the «Play» button, the calendar's matchday cards:
  -- the same action as their panel)
  for k, box in ipairs(boxes) do
    Zone("p", k, box[1], box[2], box[3], box[4])
  end
  if S.play_zone then
    local z = S.play_zone
    Zone("p", 1, z[1], z[2], z[3], z[4])
  end
  for _, c in ipairs(S.cal_zones) do
    Zone("p", #boxes, c[1], c[2], c[3], c[4])
  end
  SendZones()
  S.groups = #(v.top or {})
  S.mode = string.format("hub dashboard: matchday %s of %d, side menu %d, panel %d",
    tostring(v.fixture and v.fixture.md or "-"), v.mds or 0, cur, focus)
end

local function DrawScorers(v)
  local rows = v.rows or {}
  S.groups, S.mode = 0, ""
  local R = math.max(#rows, tonumber(v.page_rows) or #rows, 1)
  local w = math.min(LG.W_MAX, G.W - 2 * G.MX)
  local x = (G.W - w) / 2
  local pitch = math.min(LG.pitch_max, (G.Y1 - G.Y0 - LG.head - LG.labels - 2 * G.PAD) / R)
  local h = LG.head + LG.labels + 2 * G.PAD + R * pitch
  local y = (G.Y0 + G.Y1) / 2 - h / 2
  local sk = BigCard("table", x, y, w, h)
  CardTitle("table", x, y, w, h, LG.head, Text("scorers_title"), HUB.title_s)
  local xl = x + sk + 3
  local xr = x + w - sk - 3
  local ptsx = xr - LG.pad_r - LG.ptsw / 2
  local pos_x = xl + G.QBAR + LG.pos_w / 2
  local name_x = xl + G.QBAR + LG.pos_w + 10
  local s = math.min(LG.s_max, pitch * G.FILL / G.PLATE_H)
  local plate_x = name_x + SC.name_w + SC.gap
  local hb = y + LG.head
  local ly = hb + LG.labels / 2
  TxtL(Text("col_player"), name_x, ly, LG.label_s, G.ST.label_l)
  TxtL(Text("col_team"), plate_x + G.NAME_L * s, ly, LG.label_s, G.ST.label_l)
  Txt(Text("col_goals"), ptsx, ly, LG.label_s, G.ST.label_pts)
  if #rows == 0 then
    Txt(Text("scorers_none"), x + w / 2, hb + LG.labels + G.PAD + pitch, LG.num_s, G.ST.num)
  end
  local top = hb + LG.labels + G.PAD
  local sp = LeagueSprites()
  local name_px = math.min((LG.PLATE_W - G.NAME_L - LG.name_pad) * s, ptsx - LG.ptsw / 2 - 20 - plate_x - G.NAME_L * s)
  for k, r in ipairs(rows) do
    local ry = top + (k - 1) * pitch
    local yc = ry + pitch / 2
    if k < #rows then
      Rect("mark", SP.sep, xl + G.QBAR + 4, ry + pitch - G.SEP / 2, xr, ry + pitch + G.SEP / 2)
    end
    if (r.pos or k) == 1 then
      Rect("mark", SP.qual, xl, ry + 1, xl + G.QBAR, ry + pitch - 1)
    end
    Rect("mark", r.me and SP.pts_me or SP.pts, ptsx - LG.ptsw / 2, ry + 2, ptsx + LG.ptsw / 2, ry + pitch - 2)
    Txt(tostring(r.pos or k), pos_x, yc, LG.num_s, G.ST.num)
    -- the player's miniface left of his name, sized as the hub panel's (DrawScorersPanel); the name after it, cut to
    -- the room left before the team plate
    local fp = pitch * 0.9
    Face(r.card, name_x + fp / 2, yc, fp)
    local nx = name_x + fp + 8
    TxtL(Fit(CharaName(r.card), math.floor((SC.name_w - fp - 8) / (SC.name_px * SC.name_s * G.NAME_CHAR))), nx, yc,
      SC.name_s, G.ST.label_l)
    if r.me then
      local pw = LG.PLATE_W * s
      Quad("mark", sp.frame, plate_x + pw / 2, yc, pw * LG.FRAME_W, G.PLATE_H * s * LG.FRAME_H)
    end
    Plate(r, plate_x, yc, s, name_px)
    Txt(tostring(r.goals or 0), ptsx, yc, LG.pts_s, r.me and G.ST.pts_me or G.ST.pts)
    S.groups = S.groups + 1
  end
  S.mode = string.format("scorers, %d rows", #rows)
end

-- ---- the league team's squad (Battle Bay Deluxe 1.53.0, view kind "squad") ------------------------------------------
-- The hub's «Plantilla»: the team the player chose for this league (the run's team, as the hub's side menu shows it),
-- its roster as the league plays it (scripts\tournament.lua: the team's member rows): the starters (slots 0-10) on
-- the left, the substitutes on the right, each with his number, position and name; the crest, name and level on the
-- card's band. One card of the standings' look.
local SQ = { W = 1320, H = 800, head = 50, PAD = 24, PITCH = 52, CREST = 34, COL_GAP = 40 }
local POS_TEXT = { [1] = 329038701, [2] = 2325080791, [3] = 4254259777, [4] = 1677086690 }   -- evt_bbd_pos_1..4

local function RawText(id)
  local ok, t = pcall(funcLuaCommand, C.TEXT_GET, id)
  return ok and type(t) == "string" and t or ""
end

local function DrawSquad(v)
  S.groups, S.mode = 0, ""
  local x = (G.W - SQ.W) / 2
  local y = (G.Y0 + G.Y1) / 2 - SQ.H / 2
  local sk = BigCard("table", x, y, SQ.W, SQ.H)
  Crest(v.team, x + sk + 46, y + SQ.head / 2, SQ.CREST)
  local head = Fit(VRFW_Team.Name(v.team), 30)
  if v.level then
    head = head .. "  ·  " .. TextValue2("hub_level", v.level)
  end
  TxtL(head, x + sk + 76, y + SQ.head / 2, HUB.title_s, G.ST.title)
  local rows = v.rows or {}
  if #rows == 0 then
    Txt(Text("squad_none"), x + SQ.W / 2, y + SQ.H / 2, 1.0, G.ST.num)
    S.mode = "squad: no members"
    return
  end
  local colw = (SQ.W - 2 * sk - 2 * SQ.PAD - SQ.COL_GAP) / 2
  local top = y + SQ.head + 16
  local cols = { { key = "squad_starters", x = x + sk + SQ.PAD, n = 0 },
                 { key = "squad_subs", x = x + sk + SQ.PAD + colw + SQ.COL_GAP, n = 0 } }
  for _, c in ipairs(cols) do
    TxtL(Text(c.key), c.x + 8, top + 14, 0.95, G.ST.label_l)
  end
  for _, r in ipairs(rows) do
    local c = cols[(r.slot or 0) < 11 and 1 or 2]
    local ry = top + 34 + c.n * SQ.PITCH
    local yc = ry + SQ.PITCH / 2
    if ry + SQ.PITCH <= y + SQ.H - 10 then
      Rect("mark", SP.sep, c.x, ry + SQ.PITCH - 1, c.x + colw, ry + SQ.PITCH + 1)
      Rect("mark", SP.pts, c.x, ry + 6, c.x + 52, ry + SQ.PITCH - 6)
      Txt(tostring((r.slot or 0) + 1), c.x + 26, yc, 0.9, G.ST.num)
      local pos = POS_TEXT[r.pos or 0]
      if pos then
        Txt(RawText(pos), c.x + 150, yc, 0.9, G.ST.num_dim)
      end
      TxtL(Fit(CharaName(r.card), 26), c.x + 250, yc, 1.1, G.ST.label_l)
      S.groups = S.groups + 1
    end
    c.n = c.n + 1
  end
  S.mode = string.format("squad: %d members", #rows)
end

-- the instances set up per pool against the counts: "card 16/16, …", short pools
local function SetupText()
  local parts, short = {}, 0
  for k, n in pairs(N) do
    local got = funcLuaMenuCommand(C.LAYER_NUM, L[k])
    got = type(got) == "number" and got or -1
    if got < n then
      short = short + 1
    end
    parts[#parts + 1] = string.format("%s %d/%d (set up %d)", NAMES[k], got, n, S.per[L[k]] or 0)
  end
  table.sort(parts)
  return table.concat(parts, ", "), short
end

-- the page drawn: every piece shown, the rest of each pool hidden; one log line per opening
local function Draw()
  local ok, v = pcall(funcLuaCommand, CMD_VIEW, S.page or -1)
  if not ok or type(v) ~= "table" then
    return false   -- the mod's scripts busy on another thread: again on the next Step
  end
  S.used, S.miss = {}, {}
  local okd, err = pcall(function()
    if v.kind == "groups" then
      DrawGroups(v)
    elseif v.kind == "league" then
      DrawLeague(v)
    elseif v.kind == "hub" then
      DrawHub(v)
    elseif v.kind == "scorers" then
      DrawScorers(v)
    elseif v.kind == "squad" then
      DrawSquad(v)
    elseif v.kind == "fixtures" then
      DrawFixtures(v)
    end
  end)
  if not okd then
    Log("groups menu: draw error", tostring(err))
  end
  for k, l in pairs(L) do
    for i = S.used[k] or 0, N[k] - 1 do
      Hide(l, i)
      if l == L.face and VRFW_FaceIcon ~= nil then
        VRFW_FaceIcon.Forget(l, i)
      end
    end
  end
  S.drawn = true
  if not S.logged then
    S.logged = true
    local setup, short = SetupText()
    local used, miss = {}, {}
    for k, _ in pairs(N) do
      used[#used + 1] = string.format("%s %d", NAMES[k], S.used[k] or 0)
      if (S.miss[k] or 0) > 0 then
        miss[#miss + 1] = string.format("%s %d", NAMES[k], S.miss[k])
      end
    end
    table.sort(used)
    table.sort(miss)
    Log(string.format("groups menu open (host %s, page %s, kind %s): instances requested %d, set up %d/%d after %d "
      .. "frames [%s]%s; groups drawn %d of %d (%s); pieces used [%s]%s", VRFW_Id.hex(S.host), tostring(S.page),
      tostring(v.kind), S.need, S.got, S.need, S.frame, setup, short > 0 and " SHORT" or "", S.groups,
      #(v.groups or v.standings or v.rows or {}), S.mode, table.concat(used, ", "),
      #miss > 0 and ("; NOT DRAWN (pool full): " .. table.concat(miss, ", ")) or ""))
  end
  return true
end

-- every instance of every pool hidden (nothing of the tables left on screen)
local function HideAll()
  for k, l in pairs(L) do
    for i = 0, N[k] - 1 do
      pcall(Hide, l, i)
    end
  end
  if VRFW_FaceIcon ~= nil then
    VRFW_FaceIcon.Forget(L.face)
  end
  S.used = {}
end

-- 1.5.64: closing (the host's close): every piece hidden at once (whatever the engine does with the close, nothing
-- stays drawn), no draw any more; VRFW_ChildMenu closes this menu
local function OnClose()
  S.want, S.drawn = false, false
  HideAll()
end

-- the host's redraw (VRFW_ChildMenu): the view changed, or the host drew the group page once more
local function OnRedraw(page)
  S.page = page
  S.host = Handshake.Host()
  S.want = true
end

-- ---- engine callbacks -----------------------------------------------------------------------------------------------
function OnInit()
  Handshake = VRFW_ChildMenu.Child(MENU, { prefix = "evt_bbd_tn_groups_", on_redraw = OnRedraw, on_close = OnClose,
    log = function(...) Log("groups menu:", ...) end })
  S.page, S.host = Handshake.Init()
  S.need, S.got, S.per, S.seen, S.frame = 0, 0, {}, {}, 0
  S.drawn, S.logged, S.want, S.stuck, S.emb, S.strip = false, false, true, false, {}, {}
  if VRFW_FaceIcon ~= nil then
    VRFW_FaceIcon.Forget(L.face)
  end
  for _, n in pairs(N) do
    S.need = S.need + n
  end
end

-- every instance hidden and parked as the engine sets it up (opened with the menu's group); one set up after the page
-- was drawn: the page again
function OnSetupLayer(a1, a2)
  if KEY_OF[a1] == nil then
    return
  end
  Hide(a1, a2 or 0)
  local k = tostring(a1) .. ":" .. tostring(a2)
  if not S.seen[k] then
    S.seen[k] = true
    S.got = S.got + 1
    S.per[a1] = (S.per[a1] or 0) + 1
  end
  if a1 == L.row then
    VRFW_Team.EmblemForget(a1, a2 or 0, S.emb)
    S.strip[a2 or 0] = nil
  end
  if a1 == L.face and VRFW_FaceIcon ~= nil then
    VRFW_FaceIcon.Forget(a1, a2 or 0)
  end
  if S.drawn then
    S.want = true
  end
end

function OnOpenLayer(a1, a2)
end

function Step()
  S.frame = S.frame + 1
  if Handshake.Step() then
    return   -- closing
  end
  -- draw once every instance is set up (or after STUCK_FRAMES with what there is)
  if S.want and (S.got >= S.need or S.frame >= 120) then
    if S.got < S.need and not S.stuck then
      S.stuck = true
      Log("groups menu: STUCK? only", S.got, "of", S.need, "instances set up after", S.frame, "frames: drawn anyway")
    end
    if Draw() then
      S.want = false
    end
  end
  -- the minifaces still loading: each one shown once its face is in
  if VRFW_FaceIcon ~= nil and VRFW_FaceIcon.Pending() then
    VRFW_FaceIcon.Settle()
  end
end

function FinalizeMenu()
  if Handshake then
    Handshake.Finalize()
  end
end
