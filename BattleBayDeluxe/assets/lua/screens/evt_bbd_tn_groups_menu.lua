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
-- Handshake: parameters evt_bbd_tn_groups_page (the view page to draw) and evt_bbd_tn_groups_host (the host menu)
-- set before CMND_OPEN_MENU_OBJECT; the host asks for a redraw with the cross-menu call BBG_Redraw(page). This menu
-- closes itself when its host no longer exists.
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
-- evt_bbd_gt_txt (553) 322 = 642 instances (16 tiny cards: 16 + 49 + 178 + 64 + 322; 8 compact: 8 + 25 + 189 + 32 +
-- 294). Change the counts in both places (N below).
-- Log, once per opening (the first draw): instances requested / set up per pool, groups drawn, pieces not drawn.
-- Rule: no engine call at top level (funcLuaCommand only exists inside callbacks).
INCLUDE("LUA_PROG_BASE")

local MENU = 3003171228            -- crc32("evt_bbd_tn_groups_menu")
local P_PAGE = 3658435887          -- crc32("evt_bbd_tn_groups_page"): parameter in, the view page
local P_HOST = 19065074            -- crc32("evt_bbd_tn_groups_host"): parameter in, the host menu (crc32 of its name)
-- 1.5.64: crc32("evt_bbd_tn_groups_close"): parameter in, set by the host when it no longer shows the group page (the
-- host's CMND_CLOSE_MENU_OBJECT of this menu alone left it open and drawn over the next screens, owner 2026-10-14)
local P_CLOSE = 2205194670
local CMD_VIEW = 2584538108        -- crc32("CMND_BBD_TOURN_VIEW") (the mod's scripts\tournament.lua)
local LOG = 3661580131             -- CMND_EVT_LOG
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
}
local N = { card = 16, band = 50, mark = 190, row = 64, txt = 322 }
local NAMES = { card = "card", band = "band", mark = "mark", row = "row", txt = "txt" }
local KEY_OF = {}
for k, l in pairs(L) do
  KEY_OF[l] = k
end

local C = {
  VISIBLE = 711242136, POS = 1389957207, SCALE = 3778714801, SPRITE = 558735651, PRIM_COLOR = 855211291,
  MESH_VISIBLE = 3405944500, TEXT = 1083631230, TEXT_VISIBLE = 1505208242, TEXT_STYLE = 2333948100,
  TEAM_INFO = 2151743654, ICON_REQ = 3190452549, ICON_RESET = 4176779611, TEXT_GET = 4074371074,
  LAYER_NUM = 1175615627,      -- CMND_GET_CREATE_LAYER_NUM?
  IS_EXIST = 2231168902,       -- CMND_IS_EXIST_MENU_OBJECT?
  CLOSE_MENU = 320421347,      -- CMND_CLOSE_MENU_OBJECT
  MODEL_ALPHA = 4231609516, TEXT_ALPHA = 1126837159,
  P_EXISTS = 2947612279, P_GET = 3522198769, P_CLEAR = 3363400568,
}
-- the team row (evt_bbd_tn_row_l = team06_02): its plate looks, crest, name nodes
local PLATE = { 2022529787, 2334302522, 4215821749, 1697431574 }   -- _list_base_xs01_off / _on / _ok / _ol
local MESH_EMBLEM = 3281704751     -- _icon_emblem_dmy01
local EMBLEM_TEX = 255812047       -- icon_emblem_dmy01
local TXT_ON = 931545948           -- _text_list01_on (white)
local TXT_OFF = 3705682548         -- _text_list01_off (blue)
local OUT_ALPHA = 0.45             -- a team that is out (bbt_top.lua BBT.ADV.OUT_ALPHA)

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
  want = false, used = {}, miss = {}, emb = {}, groups = 0, mode = "", stuck = false, closing = false, close_tries = 0 }

local function Log(...)
  pcall(funcLuaCommand, LOG, "bb_chronicle_teams tournament", ...)
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

local function TeamName(team)
  if team == nil or team == 0 then
    return ""
  end
  local ok, _, name = pcall(funcLuaCommand, C.TEAM_INFO, team, 2)
  if ok and type(name) == "string" then
    return name
  end
  return ""
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
  funcLuaMenuCommand(C.SPRITE, l, ART, spr, NODE_QUAD, 0, i)
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

-- the team's crest on a row (the retail emblem request of the office lists); asked again only when the instance shows
-- another team
local function Emblem(i, team)
  local l = L.row
  if S.emb[i] == team then
    return
  end
  if S.emb[i] ~= nil then
    pcall(funcLuaMenuCommand, C.ICON_RESET, l, i, EMBLEM_TEX)
  end
  S.emb[i] = team
  local ok, r, e = pcall(funcLuaCommand, C.TEAM_INFO, team, 6, 0)
  if ok and r then
    funcLuaMenuCommand(C.ICON_REQ, l, i, MESH_EMBLEM, EMBLEM_TEX, e)
  end
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
  local name = Fit(TeamName(r.team), math.floor(maxpx / (G.NAME_PX * s * G.NAME_CHAR)))
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
  Emblem(i, r.team)
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
    end
  end)
  if not okd then
    Log("groups menu: draw error", tostring(err))
  end
  for k, l in pairs(L) do
    for i = S.used[k] or 0, N[k] - 1 do
      Hide(l, i)
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
    Log(string.format("groups menu open (host 0x%08X, page %s, kind %s): instances requested %d, set up %d/%d after %d "
      .. "frames [%s]%s; groups drawn %d of %d (%s); pieces used [%s]%s", (S.host or 0) % 4294967296, tostring(S.page),
      tostring(v.kind), S.need, S.got, S.need, S.frame, setup, short > 0 and " SHORT" or "", S.groups,
      #(v.groups or {}), S.mode, table.concat(used, ", "),
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
  S.used = {}
end

-- 1.5.64: closing: every piece hidden at once (whatever the engine does with the close, nothing stays drawn), no
-- draw any more, then this menu closes itself (again every 30 Steps while it still exists)
local function BeginClose(why)
  if not S.closing then
    Log("groups menu: closing (" .. tostring(why) .. ")")
  end
  S.closing, S.want, S.drawn = true, false, false
  HideAll()
  S.close_tries = S.close_tries + 1
  pcall(funcLuaCommand, C.CLOSE_MENU, MENU)
end

-- ---- the host's calls (cross-menu call 830228314) --------------------------------------------------------------------
-- the page again (the view changed, or the host drew the group page once more)
function BBG_Redraw(page)
  if page ~= nil then
    S.page = page
  end
  if S.closing then
    -- the host shows the group page again while this menu had not finished closing: it stays and draws
    Log("groups menu: shown again before it closed (tries " .. S.close_tries .. ")")
    S.closing, S.close_tries = false, 0
  end
  S.want = true
end

-- the host left the group page (another page, the overlay closed, another screen): hidden and closed
function BBG_Close(why)
  BeginClose(why or "the host left the group page")
end

-- the host shows the group page again while this menu still exists (closing): it comes back with that host
function BBG_Revive(page, host)
  if host ~= nil then
    S.host = host
  end
  BBG_Redraw(page)
end

-- ---- engine callbacks -----------------------------------------------------------------------------------------------
function OnInit()
  S.page, S.host = nil, nil
  if funcLuaCommand(C.P_EXISTS, P_PAGE) then
    S.page = tonumber(funcLuaCommand(C.P_GET, P_PAGE))
    funcLuaCommand(C.P_CLEAR, P_PAGE)
  end
  if funcLuaCommand(C.P_EXISTS, P_HOST) then
    S.host = tonumber(funcLuaCommand(C.P_GET, P_HOST))
    funcLuaCommand(C.P_CLEAR, P_HOST)
  end
  S.need, S.got, S.per, S.seen, S.frame = 0, 0, {}, {}, 0
  S.drawn, S.logged, S.want, S.stuck, S.emb = false, false, true, false, {}
  S.closing, S.close_tries = false, 0
  -- a close request of an earlier opening is not this one's
  if funcLuaCommand(C.P_EXISTS, P_CLOSE) then
    funcLuaCommand(C.P_CLEAR, P_CLOSE)
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
    S.emb[a2 or 0] = nil
  end
  if S.drawn then
    S.want = true
  end
end

function OnOpenLayer(a1, a2)
end

function Step()
  S.frame = S.frame + 1
  if S.closing then
    if S.frame % 30 == 0 then
      if S.close_tries == 10 then
        Log("groups menu: still open after", S.close_tries, "close requests (hidden meanwhile)")
      end
      BeginClose("again")
    end
    return
  end
  -- 1.5.64: the host's close request (parameter): it no longer shows the group page
  local okc, asked = pcall(funcLuaCommand, C.P_EXISTS, P_CLOSE)
  if okc and asked == true then
    pcall(funcLuaCommand, C.P_CLEAR, P_CLOSE)
    BeginClose("the host's close request")
    return
  end
  -- the host gone (closed without closing this menu): this menu closes too
  if S.host ~= nil and S.frame % 30 == 0 and funcLuaMenuCommand(C.IS_EXIST, S.host) ~= true then
    S.host = nil
    BeginClose("host gone")
    return
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
end
