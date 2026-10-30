-- vrfw_bracket_menu: the knockout bracket screen (its [[screen]] in content\menus\bracket.toml).
-- A draw-only child menu (registry priority 0: it never takes the pad), opened over its host by VRFW_Bracket
-- (assets\lua\menu\_all\90_bracket.lua). The host keeps the keys, its header and its background; this menu draws the
-- view its host's view command answers, of kind "tree" (scripts\lib\competition.lua bracket_view: rounds = R,
-- leaves[1 .. 2^R] = { team, me, out, won, strip }, matches[r][m] = { w, score = false | { ga, gb, pa, pb, et } },
-- champion; optional fmt, outcome, place, next, final_stadium = { map, id }):
--   * a knockout of exactly 16 teams on the Victory Road «決勝トーナメント» art (the retail vroad04_* objects with
--     their retail layer names: the tree base attaches the 16 gold path strips, the trophy, the per-round scores and
--     the schedule panel to its nodes; each strip attaches the star of its slot): the team plates at the base's name
--     nodes, each strip's «move» rate 0.25 a round won (DrawRetail);
--   * every other size on the generic lines (DrawTree): plates of a side share the height, the joints of round r at
--     xe + (CX - xe) * r / R, rounded stubs, the winners' crests standing big on the joints, the scores stacked past
--     them, the retail trophy over the final, the champion's plate above it; a bye (a first-round match with one
--     team and an empty leaf) draws no line and no empty row: its team's plate stands at the first-round joint from
--     the start, pre-advanced into the next round's slot;
--   * the stadium of the final in the round panel's box at the bottom (the view's final_stadium);
--   * the advance (animate): the round just played walks (crests along the lines / strips growing), eased and
--     staggered; the host's Enter skips it (parameter vrfw_bracket_skip or VRFW_Bracket_Skip).
-- Handshake: VRFW_ChildMenu (menu\_all\89_child_menu.lua: page, host, redraw, close); parameters (crc32 of
-- vrfw_bracket_<name>) view_hi / view_lo (the view command), top (the first screen row the bracket may use; 0 = the
-- default layout), lift (draw priority added to the retail art), busy (set by the host for an advance, cleared here
-- when it ends), skip. Cross-menu call: VRFW_Bracket_Skip.
-- Rule: no engine call at top level (funcLuaCommand only exists inside callbacks).
INCLUDE("LUA_PROG_BASE")

-- ---- crc32 (names are kept readable; each crc built once) -----------------------------------------------------------
local CRC_T, CRCS = nil, {}
local function Crc(s)
  local hit = CRCS[s]
  if hit then
    return hit
  end
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
  c = bit32.bxor(c, 0xFFFFFFFF)
  CRCS[s] = c
  return c
end

local MENU_NAME = "vrfw_bracket_menu"

-- engine commands by name (crc32 at first use); the unnamed ones are the retail Lua's numbers
local CMD = {
  VISIBLE = "CMND_SET_LAYER_VISIBLE", POS = "CMND_SET_LAYER_LOCAL_POS", SCALE = "CMND_SET_LAYER_LOCAL_SCALE",
  PRIM_COLOR = "CMND_SET_PRIM_COLOR", MESH_VISIBLE = "CMND_SET_MESH_VISIBLE", TEXT = "CMND_SET_MENU_TEXT_STRING",
  TEXT_VISIBLE = "CMND_SET_MENU_TEXT_VISIBLE", MODEL_ALPHA = "CMND_SET_LAYER_MODEL_ALPHA",
  TEXT_ALPHA = "CMND_SET_MENU_TEXT_ALPHA", PRIORITY = "CMND_SET_DRAW_PRIORITY", LAYER_NUM = "CMND_GET_CREATE_LAYER_NUM",
  GROUP_INDEX = "CMND_GET_GROUP_INDEX", PRIM_INDEX = "CMND_SEARCH_PRIM_INDEX", TEXT_GET = "CMND_TEXT_GET",
  MAP_NAME = "CMND_GET_MAP_NAME", LOAD_TEX = "CMND_LOAD_MENU_RES_TEXTURE",
}
local N_CMD = {
  SPRITE = 558735651,
  TEXT_VALUE = 910683996,      -- (text, tag, n, …): the text with <tag> filled
  FRAME_TIME = 1549797111,     -- the frame's time step (s)
  TEX_LOADING = 1506186496,    -- texture still loading?
  GLOBAL_POS = 4002164178,
  RATE_BIND = 541357333, RATE_SET = 1595998683,           -- a MenuRateSetting bound to an animation group / set
  NUM_SHOW = 1233047821, NUM_SET = 3609943765,           -- a number setting shown / its value
}
local function K(name)
  return Crc(CMD[name])
end
local function M(name, ...)
  return funcLuaMenuCommand(K(name), ...)
end

-- ---- the pools (the [[screen]] rows: change both together) ------------------------------------------------------------
local POOL_NAME = {
  line = "vrfw_bracket_line",       -- connector pieces, score digits (quads of vrfw_bracket / vrfw_bracket_num)
  row_l = "vrfw_bracket_row_l",     -- a team plate, crest left of the name (left side; the champion's)
  row_r = "vrfw_bracket_row_r",     -- the mirrored plate (right side)
  box = "vrfw_bracket_box",         -- the player's frame, the stars at the joints, the final stadium's picture
  crest = "vrfw_bracket_crest",     -- a crest alone (the left plate, plate and name hidden): the winners at the joints
  icon = "vrfw_bracket_icon",       -- the champion's crown (a tree without the retail trophy)
  stadium_panel = "vrfw_bracket_stadium",   -- the final stadium's panel (a two-line copy of the round panel)
}
local N = { line = 330, row_l = 33, row_r = 32, box = 36, crest = 32, icon = 1, stadium_panel = 1 }
local ROW_CHAMP = 32              -- row_l instance of the champion's plate

-- the retail art's layers (retail layer names: the base attaches them by name) and their retail draw priorities
local RETAIL_NAME = {
  base = "vroad04_01_tournament_base", trophy = "vroad04_02_trophy", star = "vroad04_04_light_on_line",
  sched = "vroad04_09_schedule_for_spectator",
  score = { "vroad04_07_tounament_score_round01", "vroad04_07_tounament_score_round02",
    "vroad04_07_tounament_score_round03", "vroad04_07b_tounament_score_final" },
}
local RETAIL_PRIO = { base = 197, line = 201, star = 201, score = 202, trophy = 203, sched = 201, stadium_panel = 201 }

local RETAIL = {
  ROUNDS = 4, STARS = 16, SCORES = { 8, 4, 2, 1 },
  RATE_MOVE = 4013832056,          -- the strips' MenuRateSetting «move»
  ANIM_LINE = "line",              -- its animation group
  NUM_A = 2710162575, NUM_B = 947952949,   -- the score objects' two number settings (upper / lower entrant)
  FLAG = { left = { "_icon_flag_l01", "_icon_flag_l02" }, right = { "_icon_flag_r01", "_icon_flag_r02" } },
  FLAG_FINAL = { "_icon_flag_l01", "_icon_flag_r01" },
  FLAG_ALL = { "_icon_flag_l01", "_icon_flag_l02", "_icon_flag_r01", "_icon_flag_r02" },
  TXT_ROUND = "_text_time01_01", TXT_PLAYED = "_text_time01_02", TXT_NEXT = "_text_now01", TXT_SPARE = "_text_time02",
  -- the base's layout in screen px (placed at the origin): name nodes x 363 / 1557, y 288 + 72 a slot; a strip
  -- starts 137 px inside its node
  NAME_X_L = 363, NAME_X_R = 1557, NAME_Y0 = 288, NAME_STEP = 72, STRIP_IN = 137,
  PLATE_S = 0.6, PLATE_GAP = 6,
  MESH_TREE = "_tournament01",     -- the base's unlit 16-team bracket mesh
  TROPHY_NODE_Y = 381,             -- the base's _atc_trophy01, screen px
  CHAMP_Y = 206,                   -- the champion's plate, above the trophy
}

local ART = 3201721854             -- crc32("#/menu/220_img/vrfw_bracket/vrfw_bracket.g4tx"): the bracket's drawings
local ART_NUM = 4021109445         -- crc32("#/menu/220_img/vrfw_bracket_num/vrfw_bracket_num.g4tx"): the score digits
local PLATE_ATLAS = 143680280      -- crc32("#/menu/102_team/team06/team06_02/team06_02.g4tx")
local NODE_QUAD, MESH_QUAD = "icon_new01", "_icon_new01"
local WHITE = { 1, 1, 1 }

-- the geometry, screen px (y down) of the 1920 x 1080 menu camera
local G = {
  W = 1920, TOP = 136, BOTTOM = 1004, MARGIN = 34, CX = 960, PLATE_W = 520, PLATE_H = 72, FILL = 0.84,
  SCALE_MAX = 1.0, GAP = 16, Q = 36, LINE = 6, LINE_LIT = 10, CHAMP_Y = 176, CHAMP_S = 0.85, CROWN_W = 72,
  CROWN_H = 54, DIM = 0.5,
  TROPHY_Y = 300, STAR = 1.8, STAR_MIN = 32, STAR_MAX = 64,
  TURN_R = 8, TURN_LEN = 120, TROPHY_CUP_BOTTOM = 89, PRIO_BACK = 546,
}
-- the score digits (vrfw_bracket_num): a played match's pair stacked past its joint, a shoot-out's kicks beside it, the
-- final's goals below the centre
local NUM = { W = 22, H = 29, GAP = 32, PAIR_H = 90, HEIGHT = 0.55, H_MIN = 13, H_MAX = 26, SPACE = 4, ADV = 0.78,
  PEN_S = 0.75, FINAL_S = 1.3, PRIO = 548 }
-- the advance and the crests at the joints
local ADV = {
  DUR = 0.65, STAGGER = 0.06, STAGGER_ALL = 0.4,
  CREST_W = 68, CREST_X = 56, CREST_X_R = 464, OUT_ALPHA = 0.45,
  BIG_OF = 0.5, BIG_GAP = 8, BIG_MIN = 24, BIG_MAX = 72, CREST_PRIO = 550,
}
local LINE_PRIO, BOX_PRIO = 549, 552   -- the connector pool's own priority; a box-pool quad without its own
-- the final stadium's panel
local STADIUM = { Y = 958, PANEL_W = 394, THUMB_W = 128, THUMB_H = 72, PAD = 8, LOAD_MIN = 10, LOAD_MAX = 600,
  PICTURE_DIR = "#/menu/220_img/stadium/img_room_" }

-- the team plate (vrfw_bracket_row_l = team06_02): its looks, crest, name nodes
local PLATE = { off = "_list_base_xs01_off", on = "_list_base_xs01_on", ok = "_list_base_xs01_ok", ol = "_list_base_xs01_ol" }
local PLATE_SPRITE = "list_base_xs01_off"
local MESH_EMBLEM = "_icon_emblem_dmy01"   -- the plate's crest quad (its crest: VRFW_Team.Emblem)
local TXT_ON, TXT_OFF = "_text_list01_on", "_text_list01_off"
-- the bracket's sprites (content\images\menu\220_img\vrfw_bracket.toml)
local SPR = {
  plain = "vrfw_bracket_line_plain", lit = "vrfw_bracket_line_lit", me = "vrfw_bracket_line_me", out = "vrfw_bracket_line_out",
  out_me = "vrfw_bracket_line_out_me", star = "vrfw_bracket_star", crown = "vrfw_bracket_crown", frame = "vrfw_bracket_frame_l",
  line = "vrfw_bracket_line",
}
local SPR_HALO = { lit = { h = "vrfw_bracket_lit_h", v = "vrfw_bracket_lit_v" }, me = { h = "vrfw_bracket_me_h", v = "vrfw_bracket_me_v" } }
local SPR_STRIP = { "vrfw_bracket_strip_red", "vrfw_bracket_strip_orange", "vrfw_bracket_strip_yellow", "vrfw_bracket_strip_green",
  "vrfw_bracket_strip_cyan", "vrfw_bracket_strip_blue", "vrfw_bracket_strip_purple", "vrfw_bracket_strip_pink", "vrfw_bracket_strip_black",
  "vrfw_bracket_strip_silver" }
local FRAME_GROW = { w = 408 / 392, h = 88 / 72 }

-- ---- state of this opening ---------------------------------------------------------------------------------------------
local S = {
  page = -1, host = nil, view_cmd = nil, top = 0, lift = 0, need = 0, got = 0, seen = {}, frame = 0, drawn = false,
  want = false, animate = false, used = {}, taken = {}, emb = {}, strip = {}, prio = {}, crest_prio = {}, lifted = {},
  view = nil, anim = nil, crests = {}, retail = nil, trophy = false, pics = {},
  pic_load = nil, logged = {}, stuck = false,
}
local L, KEY_OF, RL = {}, {}, nil
local C   -- the child side of the handshake (VRFW_ChildMenu.Child), made in OnInit

local logger
local function Log(...)
  logger = logger or VRFW_Log.New("VRFW.bracket")
  logger(...)
end

-- the layers' crc32 and what each one is (built at the opening)
local function Layers()
  if RL ~= nil then
    return
  end
  for k, name in pairs(POOL_NAME) do
    L[k] = Crc(name)
    KEY_OF[L[k]] = k
  end
  RL = { base = Crc(RETAIL_NAME.base), trophy = Crc(RETAIL_NAME.trophy), star = Crc(RETAIL_NAME.star),
    sched = Crc(RETAIL_NAME.sched), lines = {}, score = {} }
  for _, side in ipairs({ "l", "r" }) do
    for k = 1, 8 do
      RL.lines[#RL.lines + 1] = Crc(string.format("vroad04_03_%s%02d_tournament_line", side, k))
    end
  end
  for r, name in ipairs(RETAIL_NAME.score) do
    RL.score[r] = Crc(name)
  end
  RL.prio = { [RL.base] = RETAIL_PRIO.base, [RL.trophy] = RETAIL_PRIO.trophy, [RL.star] = RETAIL_PRIO.star,
    [RL.sched] = RETAIL_PRIO.sched }
  for _, l in ipairs(RL.lines) do
    RL.prio[l] = RETAIL_PRIO.line
  end
  for _, l in ipairs(RL.score) do
    RL.prio[l] = RETAIL_PRIO.score
  end
end

-- every instance of the retail layers: f(layer, instance)
local function RetailEach(f)
  f(RL.base, 0)
  f(RL.trophy, 0)
  f(RL.sched, 0)
  for k = 1, #RL.lines do
    f(RL.lines[k], 0)
  end
  for i = 0, RETAIL.STARS - 1 do
    f(RL.star, i)
  end
  for r = 1, #RL.score do
    for i = 0, RETAIL.SCORES[r] - 1 do
      f(RL.score[r], i)
    end
  end
end

-- ---- helpers --------------------------------------------------------------------------------------------------------------
local function Text(key)
  local ok, t = pcall(funcLuaCommand, K("TEXT_GET"), Crc("vrfw_bracket_" .. key))
  return ok and type(t) == "string" and t or ""
end

local function TextValue(key, a)
  local t = Text(key)
  local ok, r = pcall(funcLuaCommand, N_CMD.TEXT_VALUE, t, "VALUE", a or 0, 0, 0, true)
  return ok and r or t
end

local function TextValue2(key, a, b)
  local t = TextValue(key, a)
  local ok, r = pcall(funcLuaCommand, N_CMD.TEXT_VALUE, t, "VALUE2", b or 0, 0, 0, true)
  return ok and r or t
end

local function Hide(layer, i)
  M("VISIBLE", layer, i, false)
  M("POS", layer, -4000, 4000, 0, i)
end

-- the pieces of one draw: { [layer] = next free instance }; the rest hidden at the end
local function Begin()
  S.used, S.taken, S.crests = {}, {}, {}
  for _, l in pairs(L) do
    S.used[l] = 0
  end
end

local function Take(layer, fixed)
  local i = fixed
  if i == nil then
    i = S.used[layer] or 0
    while S.taken[tostring(layer) .. ":" .. i] do
      i = i + 1
    end
    S.used[layer] = i + 1
  end
  S.taken[tostring(layer) .. ":" .. i] = true
  return i
end

local function End()
  for k, l in pairs(L) do
    for i = 0, N[k] - 1 do
      if not S.taken[tostring(l) .. ":" .. i] then
        Hide(l, i)
      end
    end
  end
end

-- a tinted quad of the bracket's drawings: centre (x, y), w x h px; prio = the instance's draw priority (connector and
-- box pools, set when it changes); atlas = another loaded atlas (crc32 of its path)
local function Quad(k, spr, x, y, w, h, col, prio, atlas)
  local layer = L[k]
  local i = Take(layer)
  if i >= N[k] then
    return nil
  end
  if k == "line" or k == "box" then
    local want = prio or (k == "box" and BOX_PRIO or LINE_PRIO)
    local key = tostring(layer) .. ":" .. i
    if S.prio[key] ~= want then
      S.prio[key] = want
      M("PRIORITY", layer, i, want, true)
    end
  end
  M("VISIBLE", layer, i, true)
  M("SCALE", layer, w / G.Q, h / G.Q, 1, i)
  funcLuaMenuCommand(N_CMD.SPRITE, layer, atlas or ART, type(spr) == "string" and Crc(spr) or spr, Crc(NODE_QUAD), 0, i)
  M("POS", layer, x, -y, 0, i)
  M("PRIM_COLOR", layer, i, Crc(MESH_QUAD), col[1], col[2], col[3])
  return i
end

-- a stub from xs to its joint xj on line y turning on a rounded corner towards the joint (sprite
-- vrfw_bracket_turn_<look>_<toward>_<side> stretched so that the corner's vertical end stands on the joint)
local function RoundedTurn(xs, xj, y, toward, right, t, look)
  local half = t / 2
  local sprite_w = math.floor(G.TURN_LEN + half)
  local sprite_h = math.floor(half + G.TURN_R)
  local w = math.abs(xj - xs) * sprite_w / (sprite_w - half)
  local cx = right and (xs - w / 2) or (xs + w / 2)
  local cy = toward == "down" and (y - half + sprite_h / 2) or (y + half - sprite_h / 2)
  Quad("line", string.format("vrfw_bracket_turn_%s_%s_%s", look, toward, right and "right" or "left"), cx, cy, w, sprite_h,
    WHITE)
end

-- an axis-aligned connector piece from (x0, y0) to (x1, y1); lit = thicker; st = its state (plain / lit / me / out /
-- out_me); a lit / me piece is its direction's halo sprite; shape = { toward, right }: a stub with its rounded turn;
-- shape = { trim = "start" / "end" }: a vertical piece stopping exactly at that end
local function Seg(x0, y0, x1, y1, lit, st, shape)
  local t = lit and G.LINE_LIT or G.LINE
  local look = st or (lit and "lit" or "plain")
  if shape and shape.toward then
    return RoundedTurn(x0, x1, y0, shape.toward, shape.right, t, look)
  end
  local w, h, cy = 0, 0, (y0 + y1) / 2
  if y0 == y1 then
    w, h = math.abs(x1 - x0) + t, t
  else
    local dir = y1 > y0 and 1 or -1
    local a = y0 - (shape and shape.trim == "start" and 0 or t / 2) * dir
    local b = y1 + (shape and shape.trim == "end" and 0 or t / 2) * dir
    w, h, cy = t, math.abs(b - a), (a + b) / 2
  end
  local halo = SPR_HALO[look]
  local spr = halo and halo[y0 == y1 and "h" or "v"] or SPR[look] or SPR.line
  Quad("line", spr, (x0 + x1) / 2, cy, w, h, WHITE)
end

-- an instance's model + name alpha (reset on every plate / crest drawn: instances are reused)
local function Alpha(l, i, a)
  pcall(M, "MODEL_ALPHA", l, i, 0, a)
  pcall(M, "TEXT_ALPHA", l, i, Crc(TXT_ON), a)
  pcall(M, "TEXT_ALPHA", l, i, Crc(TXT_OFF), a)
end

-- the plate's own sprite swapped for a team strip of the bracket's atlas, or back to the list plate (spr nil)
local function PlateStrip(l, i, spr)
  local k = tostring(l) .. ":" .. i
  local want = spr or false
  if S.strip[k] == want then
    return
  end
  S.strip[k] = want
  if spr then
    pcall(funcLuaMenuCommand, N_CMD.SPRITE, l, ART, Crc(spr), Crc(PLATE_SPRITE), 0, i)
  else
    pcall(funcLuaMenuCommand, N_CMD.SPRITE, l, PLATE_ATLAS, Crc(PLATE_SPRITE), Crc(PLATE_SPRITE), 0, i)
  end
end

-- a team plate: p = { team, me, out, strip }, (x, y) = its left edge / vertical centre, scale s; right = mirrored;
-- champ = the champion's look; fixed = the instance to use (the champion's)
local function Plate(p, x, y, s, right, champ, fixed)
  local k = right and "row_r" or "row_l"
  local l = L[k]
  local i = Take(l, fixed)
  if i >= N[k] then
    return
  end
  local look = champ and "ok" or (p.me and "on" or "off")
  local strip = not champ and SPR_STRIP[tonumber(p.strip) or 0] or nil
  if strip then
    look = "off"
  end
  PlateStrip(l, i, look == "off" and strip or nil)
  local white = look ~= "off" or strip ~= nil
  M("VISIBLE", l, i, true)
  M("SCALE", l, s, s, 1, i)
  M("POS", l, x, -y, 0, i)
  for name, mesh in pairs(PLATE) do
    M("MESH_VISIBLE", l, Crc(mesh), name == look, i)
  end
  local name = VRFW_Team.Name(p.team)
  M("TEXT", l, Crc(TXT_ON), white and name or "", i)
  M("TEXT", l, Crc(TXT_OFF), white and "" or name, i)
  M("TEXT_VISIBLE", l, Crc(TXT_ON), white, i)
  M("TEXT_VISIBLE", l, Crc(TXT_OFF), not white, i)
  local c = (p.out and not champ) and G.DIM or 1
  M("PRIM_COLOR", l, i, Crc(PLATE[look]), c, c, c)
  M("PRIM_COLOR", l, i, Crc(MESH_EMBLEM), c, c, c)
  Alpha(l, i, (p.out and not champ) and ADV.OUT_ALPHA or 1)
  VRFW_Team.Emblem(l, i, p.team, S.emb)
end

-- the player's gold frame behind his plate (left edge x, centre y, scale s)
local function Focus(x, y, s)
  local w, h = G.PLATE_W * s, G.PLATE_H * s
  Quad("box", SPR.frame, x + w / 2, y, w * FRAME_GROW.w, h * FRAME_GROW.h, WHITE, G.PRIO_BACK)
end

-- a row of digit sprites centred on (x, y): parts = { { sprite name, height }, ... }; returns its width
local function Glyphs(parts, x, y, prio)
  local total, ws = 0, {}
  for k, p in ipairs(parts) do
    ws[k] = NUM.W * p[2] / NUM.H
    total = total + ws[k] * (k < #parts and NUM.ADV or 1)
  end
  local cx = x - total / 2
  for k, p in ipairs(parts) do
    Quad("line", p[1], cx + ws[k] / 2, y, ws[k], p[2], WHITE, prio or NUM.PRIO, ART_NUM)
    cx = cx + ws[k] * NUM.ADV
  end
  return total
end

-- the parts of number n (style gold / blue / white) at height h appended to parts; wrap = in brackets
local function NumParts(parts, n, style, h, wrap)
  if wrap then
    parts[#parts + 1] = { "vrfw_bracket_d_lp", h }
  end
  for c in tostring(math.max(0, math.floor(tonumber(n) or 0))):gmatch("%d") do
    parts[#parts + 1] = { "vrfw_bracket_d_" .. style .. "_" .. c, h }
  end
  if wrap then
    parts[#parts + 1] = { "vrfw_bracket_d_rp", h }
  end
  return parts
end

local function RowW(k, h)
  return NUM.W * h / NUM.H * (1 + NUM.ADV * (k - 1))
end

-- a played match's result at its joint (xj, ym) of the left side (right = mirrored): the pair just past the joint
-- (lead px further: the big crest on the joint), a shoot-out's kicks after it
local function TreeScore(m, xj, ym, right, pitch, lead)
  local sc = m and (m.w or 0) ~= 0 and m.score or nil
  if not sc then
    return 0
  end
  local h = math.max(NUM.H_MIN, math.min(NUM.H_MAX, pitch * NUM.HEIGHT))
  local dy = (h + h * NUM.GAP / NUM.H) / 2
  local function x_of(off, w)
    local c = xj + off + w / 2
    return right and (2 * G.CX - c) or c
  end
  local space = NUM.SPACE * h / NUM.H
  local used = (lead or 0) + space
  local ga, gb = sc.ga or 0, sc.gb or 0
  local sa, sb = m.w == 1 and "gold" or "blue", m.w == 2 and "gold" or "blue"
  local w
  if ga <= 9 and gb <= 9 then
    w = NUM.W * h / NUM.H
    Quad("line", string.format("vrfw_bracket_pr_%d_%d_%d", ga, gb, m.w), x_of(used, w), ym, w, h * NUM.PAIR_H / NUM.H, WHITE,
      NUM.PRIO, ART_NUM)
  else
    local pa, pb = NumParts({}, ga, sa, h), NumParts({}, gb, sb, h)
    w = RowW(math.max(#pa, #pb), h)
    Glyphs(pa, x_of(used, w), ym - dy)
    Glyphs(pb, x_of(used, w), ym + dy)
  end
  used = used + w
  if (sc.pa or 0) + (sc.pb or 0) > 0 then
    local hp = h * NUM.PEN_S
    local pa, pb = NumParts({}, sc.pa or 0, sa, hp), NumParts({}, sc.pb or 0, sb, hp)
    local wp = RowW(math.max(#pa, #pb), hp)
    used = used + space / 2
    Glyphs(pa, x_of(used, wp), ym - dy)
    Glyphs(pb, x_of(used, wp), ym + dy)
    used = used + wp
  end
  return used + space
end

-- the final's result below the centre: the left finalist's goals left of it, the right one's right of it (a
-- shoot-out: the kicks in brackets below each)
local function FinalScore(m, ymid, pitch)
  local sc = m and (m.w or 0) ~= 0 and m.score or nil
  if not sc then
    return
  end
  local h = math.max(NUM.H_MIN, math.min(NUM.H_MAX, pitch * NUM.HEIGHT)) * NUM.FINAL_S
  local y = ymid + G.LINE_LIT + h / 2
  local off = NUM.W * h / NUM.H
  local sa, sb = m.w == 1 and "gold" or "blue", m.w == 2 and "gold" or "blue"
  Glyphs(NumParts({}, sc.ga or 0, sa, h), G.CX - off, y)
  Glyphs(NumParts({}, sc.gb or 0, sb, h), G.CX + off, y)
  if (sc.pa or 0) + (sc.pb or 0) > 0 then
    local hp = h * NUM.PEN_S
    local yp = y + h / 2 + hp * 0.7
    Glyphs(NumParts({}, sc.pa or 0, sa, hp, true), G.CX - off, yp)
    Glyphs(NumParts({}, sc.pb or 0, sb, hp, true), G.CX + off, yp)
  end
end

-- the size (px) of the crest standing on a joint of round r
local function BigCrest(r, pitch, stub)
  return math.max(ADV.BIG_MIN, math.min(ADV.BIG_MAX, stub * ADV.BIG_OF, 2 ^ r * pitch - ADV.BIG_GAP))
end

-- a crest alone centred on (x, y) at scale sc; returns the instance (nil: none left)
local function Crest(c, x, y, sc)
  local l = L.crest
  local i = Take(l)
  if i >= N.crest then
    return nil
  end
  if not S.crest_prio[i] then
    S.crest_prio[i] = true
    pcall(M, "PRIORITY", l, i, ADV.CREST_PRIO, true)
  end
  M("VISIBLE", l, i, true)
  for _, mesh in pairs(PLATE) do
    M("MESH_VISIBLE", l, Crc(mesh), false, i)
  end
  M("TEXT_VISIBLE", l, Crc(TXT_ON), false, i)
  M("TEXT_VISIBLE", l, Crc(TXT_OFF), false, i)
  M("PRIM_COLOR", l, i, Crc(MESH_EMBLEM), 1, 1, 1)
  Alpha(l, i, 1)
  M("SCALE", l, sc, sc, 1, i)
  M("POS", l, x - ADV.CREST_X * sc, -y, 0, i)
  local lf = (S.view and S.view.leaves or {})[c.leaf] or {}
  VRFW_Team.Emblem(l, i, lf.team or 0, S.emb)
  return i
end

-- the run's end in the panel: champion / out (a view without them: nothing)
local function Outcome(v)
  local league = v.fmt == "league"
  if v.outcome == "champion" then
    return Text(league and "champion_league" or "champion")
  end
  if v.outcome == "out" and v.place and v.place.stage == "league" then
    return TextValue("out_league", v.place.pos or 0)
  end
  if v.outcome == "out" and v.place then
    if v.place.stage == "groups" then
      return Text("out_groups")
    end
    return Text("out_ko_" .. tostring(v.place.from_end or 1))
  end
  return ""
end

-- ---- the generic tree (every size but the 16-team art) ----------------------------------------------------------------
-- the top row (S.top) moves the whole tree down by dy; the bottom row stays
local function DrawTree(v)
  local R = tonumber(v.rounds) or 0
  if R < 1 and type(v.leaves) == "table" then
    local n = 0
    for _ in pairs(v.leaves) do
      n = n + 1
    end
    while 2 ^ (R + 1) <= n do
      R = R + 1
    end
  end
  if R < 1 or type(v.leaves) ~= "table" or type(v.matches) ~= "table" then
    return
  end
  local top = S.top > 0 and S.top or G.TOP
  local dy = top - G.TOP
  local champ_y = G.CHAMP_Y + dy
  local leaves = v.leaves
  local NL = 2 ^ R
  local half = NL / 2
  local pitch = (G.BOTTOM - top) / half
  local s = math.min(G.SCALE_MAX, pitch * G.FILL / G.PLATE_H)
  local edge = G.MARGIN + G.PLATE_W * s
  local xe = edge + G.GAP
  local function jx(r)
    return xe + (G.CX - xe) * r / R
  end
  local function mx(x, right)
    return right and (2 * G.CX - x) or x
  end
  -- the byes: first-round matches with exactly one team (bye[match] = the leaf of that team)
  local bye = {}
  for t = 1, NL / 2 do
    local a, b = (leaves[2 * t - 1] or {}).team or 0, (leaves[2 * t] or {}).team or 0
    if (a == 0) ~= (b == 0) then
      bye[t] = a ~= 0 and 2 * t - 1 or 2 * t
    end
  end
  local ys, own, at = {}, {}, {}
  for t = 1, NL do
    local right = t > half
    local k = (t - 1) % half
    local y = top + pitch * (k + 0.5)
    ys[t] = y
    own[t] = t
    local p = leaves[t]
    local x = right and (G.W - G.MARGIN - G.PLATE_W * s) or G.MARGIN
    at[t] = { x + (right and ADV.CREST_X_R or ADV.CREST_X) * s, y }
    if p and (p.team or 0) ~= 0 and not bye[math.floor((t + 1) / 2)] then
      if p.me then
        Focus(x, y, s)
      end
      Plate(p, x, y, s, right, false)
    end
  end
  -- a piece walked by leaf `l`: plain before its match is played, lit while that team is still in, dark once out
  local segs = {}
  local function seg(x0, y0, x1, y1, l, played, won, shape)
    local p = leaves[l] or {}
    local st = "plain"
    if played and (p.team or 0) ~= 0 then
      st = (won and not p.out) and "lit" or "out"
    end
    segs[#segs + 1] = { x0, y0, x1, y1, st, p.me == true, shape }
  end
  local crests = {}
  local ymid = (top + G.BOTTOM) / 2
  local cpw = G.PLATE_W * G.CHAMP_S
  for r = 1, R do
    local row = v.matches[r] or {}
    local cnt = NL / 2 ^ r
    local nx, nown, nat = {}, {}, {}
    for t = 1, cnt do
      local m = row[t] or { w = 0 }
      local w = m.w or 0
      local played = w ~= 0
      local ya, yb = ys[2 * t - 1], ys[2 * t]
      local la, lb = own[2 * t - 1], own[2 * t]
      local ym = (ya + yb) / 2
      nx[t] = ym
      local win = w == 1 and la or (w == 2 and lb or 0)
      nown[t] = win
      local from = w == 1 and at[2 * t - 1] or at[2 * t]
      local yw = w == 1 and ya or yb
      local xc = r == 1 and edge or jx(r - 1)
      local by = r == 1 and bye[t] or nil
      if by and r < R then
        -- a bye: the team's plate ends at the first-round joint, where the next round's line starts
        local right = t > cnt / 2
        local xj = jx(r)
        local x = right and mx(xj, true) or (xj - G.PLATE_W * s)
        local p = leaves[by]
        if p.me then
          Focus(x, ym, s)
        end
        Plate(p, x, ym, s, right, false)
        nown[t] = by
        nat[t] = { x + (right and ADV.CREST_X_R or ADV.CREST_X) * s, ym }
      elseif r < R then
        local right = t > cnt / 2
        local xj = jx(r)
        seg(mx(xc, right), ya, mx(xj, right), ya, la, played, w == 1, { toward = "down", right = right })
        seg(mx(xc, right), yb, mx(xj, right), yb, lb, played, w == 2, { toward = "up", right = right })
        seg(mx(xj, right), ya + G.TURN_R, mx(xj, right), ym, la, played, w == 1, { trim = "start" })
        seg(mx(xj, right), ym, mx(xj, right), yb - G.TURN_R, lb, played, w == 2, { trim = "end" })
        local nxt = (v.matches[r + 1] or {})[math.floor((t + 1) / 2)] or {}
        local stays = win ~= 0 and (nxt.w or 0) == 0
        local big = BigCrest(r, pitch, (G.CX - xe) / R)
        TreeScore(m, xj, ym, right, pitch, big / 2)
        if win ~= 0 and from then
          local rest = { mx(xj, right), ym }
          nat[t] = rest
          crests[#crests + 1] = { leaf = win, round = r, rest = rest, s = big / ADV.CREST_W, stays = stays,
            joint = { mx(xj, right), ym }, path = { from, { mx(xj, right), yw }, { mx(xj, right), ym }, rest } }
        end
      else
        seg(xc, ya, G.CX, ya, la, played, w == 1)
        seg(mx(xc, true), yb, G.CX, yb, lb, played, w == 2)
        -- with the retail trophy the stem stops at the cup's lower edge; without it, at the champion's plate
        local stem_top = S.trophy and (G.TROPHY_Y + dy + G.TROPHY_CUP_BOTTOM) or (champ_y + G.PLATE_H * G.CHAMP_S / 2)
        seg(G.CX, stem_top, G.CX, ymid, win, played, true)
        FinalScore(m, ymid, pitch)
        if win ~= 0 and from then
          local rest = { G.CX - cpw / 2 + ADV.CREST_X * G.CHAMP_S, champ_y }
          local fs = BigCrest(R, pitch, (G.CX - xe) / R) / ADV.CREST_W
          crests[#crests + 1] = { leaf = win, round = r, rest = rest, s = fs, s1 = G.CHAMP_S, final = true,
            stays = false, path = { from, { G.CX, yw }, { G.CX, champ_y }, rest } }
        end
      end
    end
    ys, own, at = nx, nown, nat
  end
  -- the plain pieces first, then the dark ones, the lit path over them
  for _, st in ipairs({ "plain", "out", "lit" }) do
    for _, g in ipairs(segs) do
      if g[5] == st then
        local look = st
        if g[6] and st == "lit" then
          look = "me"
        elseif g[6] and st == "out" then
          look = "out_me"
        end
        Seg(g[1], g[2], g[3], g[4], st == "lit", look, g[7])
      end
    end
  end
  S.crests = crests
  -- the star glow at the joint each waiting crest stands at (shown when its crest gets there)
  local star = math.max(G.STAR_MIN, math.min(G.STAR_MAX, pitch * G.STAR))
  for _, c in ipairs(crests) do
    if c.stays then
      c.star = Quad("box", SPR.star, c.joint[1], c.joint[2], star, star, WHITE, G.PRIO_BACK)
      c.i = Crest(c, c.rest[1], c.rest[2], c.s)
    end
  end
  -- the champion: a cyan plate above the final with the crown over it (a tree without the retail trophy)
  local champ = (v.champion or 0) ~= 0
  local cy = champ_y - G.PLATE_H * G.CHAMP_S / 2 - G.CROWN_H / 2 + 6
  local cc = champ and 1 or G.DIM
  if not S.trophy then
    Quad("icon", SPR.crown, G.CX, cy, G.CROWN_W, G.CROWN_H, { cc, cc, cc })
  end
  if champ then
    Plate({ team = v.champion }, G.CX - G.PLATE_W * G.CHAMP_S / 2, champ_y, G.CHAMP_S, false, true, ROW_CHAMP)
  end
end

-- ---- the retail 16-team art ---------------------------------------------------------------------------------------------
local function RetailReady()
  if S.retail_ok ~= nil then
    return S.retail_ok
  end
  local ok = true
  for _, l in ipairs({ RL.base, RL.trophy, RL.sched, RL.star, RL.lines[1], RL.lines[16], RL.score[1], RL.score[4] }) do
    local n = M("LAYER_NUM", l)
    if type(n) ~= "number" or n < 1 then
      ok = false
    end
  end
  S.retail_ok = ok
  Log("retail bracket layers: " .. (ok and "present" or "missing (every bracket on the generic lines)"))
  return ok
end

-- the retail layers shown (the 16-team page) or hidden; the stars and scores are shown one by one
local function RetailShow(on)
  RetailEach(function(l, i)
    local piece = l == RL.star or l == RL.score[1] or l == RL.score[2] or l == RL.score[3] or l == RL.score[4]
    M("VISIBLE", l, i, on and not piece)
  end)
end

-- the base's glow meshes, one per slot of the retail tree (_line_l01 .. _line_r08)
local function GlowMeshes()
  if S.glow == nil then
    S.glow = {}
    for _, side in ipairs({ "l", "r" }) do
      for k = 1, 2 ^ RETAIL.ROUNDS / 2 do
        S.glow[#S.glow + 1] = Crc(string.format("_line_%s%02d", side, k))
      end
    end
  end
  return S.glow
end

-- every other tree shows the retail trophy in place of the crown: the base without its 16-team mesh (and its glow
-- meshes), moved so its trophy node stands at TROPHY_Y (+ the top's shift); alone = false: the base back for the art
local function TrophyPlace(alone, dy)
  M("MESH_VISIBLE", RL.base, Crc(RETAIL.MESH_TREE), not alone, 0)
  for _, mesh in ipairs(GlowMeshes()) do
    M("MESH_VISIBLE", RL.base, mesh, not alone, 0)
  end
  M("POS", RL.base, 0, alone and (RETAIL.TROPHY_NODE_Y - (G.TROPHY_Y + dy)) or -dy, 0, 0)
  if alone then
    M("VISIBLE", RL.base, 0, true)
    M("VISIBLE", RL.trophy, 0, true)
  end
end

-- a strip's lit length: rate 0 (unlit) .. 1 (to the centre); the star at its head shown while the rate is above 0
local function RetailRate(k, rate)
  local l = RL.lines[k]
  local g = M("GROUP_INDEX", l, 0, Crc(RETAIL.ANIM_LINE))
  funcLuaMenuCommand(N_CMD.RATE_BIND, l, RETAIL.RATE_MOVE, g or 0, 0)
  funcLuaMenuCommand(N_CMD.RATE_SET, l, RETAIL.RATE_MOVE, 0, rate, 0, true, Crc(RETAIL.ANIM_LINE))
  M("VISIBLE", RL.star, k - 1, rate > 0)
end

-- one score object: the two entrants' goals, the shoot-out's winner flagged; not played = hidden
local function RetailScore(r, t, m)
  local l, i = RL.score[r], t - 1
  local sc = m and (m.w or 0) ~= 0 and m.score or nil
  M("VISIBLE", l, i, sc ~= nil)
  if not sc then
    return
  end
  for _, prim in ipairs({ RETAIL.NUM_A, RETAIL.NUM_B }) do
    funcLuaMenuCommand(N_CMD.NUM_SHOW, l, i, prim, true)
    local pi = M("PRIM_INDEX", l, i, prim)
    funcLuaMenuCommand(N_CMD.NUM_SET, l, i, pi, prim == RETAIL.NUM_A and (sc.ga or 0) or (sc.gb or 0))
  end
  for _, f in ipairs(RETAIL.FLAG_ALL) do
    M("MESH_VISIBLE", l, Crc(f), false, i)
  end
  if (sc.pa or 0) + (sc.pb or 0) > 0 then
    local flags = r == #RL.score and RETAIL.FLAG_FINAL or (t > RETAIL.SCORES[r] / 2 and RETAIL.FLAG.right or RETAIL.FLAG.left)
    M("MESH_VISIBLE", l, Crc(flags[m.w] or flags[1]), true, i)
  end
end

-- the schedule panel: the round being played, its matches played, the player's next match (or the run's end)
local function RetailPanel(v)
  local cur, played, total = nil, 0, 0
  for r = 1, RETAIL.ROUNDS do
    local n, done = 0, 0
    for _, m in pairs(v.matches[r] or {}) do
      n = n + 1
      if (m.w or 0) ~= 0 then
        done = done + 1
      end
    end
    if cur == nil and done < n then
      cur, played, total = r, done, n
    end
  end
  local round_txt, played_txt, next_txt
  if cur == nil then
    round_txt, played_txt = Text("sched_over"), ""
  else
    round_txt = Text("round_" .. tostring(RETAIL.ROUNDS - cur + 1))
    played_txt = TextValue2("sched_played", played, total)
  end
  local tail = Outcome(v)
  if tail ~= "" then
    next_txt = tail
  elseif cur ~= nil then
    local rival = (v.next or 0) ~= 0 and VRFW_Team.Name(v.next) or Text("sched_rival_tbd")
    next_txt = Text("sched_next") .. "  ·  " .. rival
  else
    next_txt = ""
  end
  for node, s in pairs({ [RETAIL.TXT_ROUND] = round_txt, [RETAIL.TXT_PLAYED] = played_txt, [RETAIL.TXT_NEXT] = next_txt,
    [RETAIL.TXT_SPARE] = "" }) do
    M("TEXT", RL.sched, Crc(node), s, 0)
    M("TEXT_VISIBLE", RL.sched, Crc(node), s ~= "", 0)
  end
  return cur
end

-- the 16-team tree on the retail art; S.retail keeps each slot's rate and its rate before the last round played
local function DrawRetail(v)
  local leaves = v.leaves
  local dy = S.top > 0 and (S.top - G.TOP) or 0
  local s = RETAIL.PLATE_S
  local pw = G.PLATE_W * s
  local last = 0
  for r = 1, RETAIL.ROUNDS do
    for _, m in pairs(v.matches[r] or {}) do
      if (m.w or 0) ~= 0 then
        last = r
      end
    end
  end
  local rates, prev = {}, {}
  for k = 1, #RL.lines do
    local p = leaves[k] or {}
    local right = k > 8
    local y = RETAIL.NAME_Y0 + dy + RETAIL.NAME_STEP * ((k - 1) % 8)
    local x = right and (RETAIL.NAME_X_R - RETAIL.STRIP_IN + RETAIL.PLATE_GAP)
      or (RETAIL.NAME_X_L + RETAIL.STRIP_IN - RETAIL.PLATE_GAP - pw)
    if (p.team or 0) ~= 0 then
      if p.me then
        Focus(x, y, s)
      end
      Plate(p, x, y, s, right, false)
    end
    local won = tonumber(p.won) or 0
    local rate = (not p.out and (p.team or 0) ~= 0) and math.min(1, won / RETAIL.ROUNDS) or 0
    rates[k] = rate
    -- before the last round: one round less for its winner; its loser was lit by the rounds it had won
    local before = rate
    local t = math.floor((k - 1) / 2 ^ last) + 1
    local m = (v.matches[last] or {})[t]
    if last > 0 and m and (m.w or 0) ~= 0 then
      local upper = ((k - 1) % 2 ^ last) < 2 ^ (last - 1)
      local winner = (m.w == 1) == upper
      if winner then
        before = math.max(0, rate - 1 / RETAIL.ROUNDS)
      elseif (p.team or 0) ~= 0 then
        before = math.min(1, (last - 1) / RETAIL.ROUNDS)
      end
    end
    prev[k] = before
    RetailRate(k, rate)
  end
  for r = 1, RETAIL.ROUNDS do
    local row = v.matches[r] or {}
    for t = 1, RETAIL.SCORES[r] do
      RetailScore(r, t, row[t])
    end
  end
  local cur = RetailPanel(v)
  if (v.champion or 0) ~= 0 then
    Plate({ team = v.champion }, G.CX - G.PLATE_W * G.CHAMP_S / 2, RETAIL.CHAMP_Y + dy, G.CHAMP_S, false, true, ROW_CHAMP)
  end
  S.crests = {}
  S.retail = { rates = rates, prev = prev, last = last }
  local lit = 0
  for k = 1, #rates do
    if rates[k] > 0 then
      lit = lit + 1
    end
  end
  local okb, bx, by = pcall(funcLuaMenuCommand, N_CMD.GLOBAL_POS, RL.base, 0)
  local okl, lx, ly = pcall(funcLuaMenuCommand, N_CMD.GLOBAL_POS, RL.lines[1], 0)
  return string.format("retail bracket: %d path(s) lit, last round played %d, panel round %s; base at %s,%s, l01 strip at %s,%s",
    lit, last, tostring(cur), tostring(okb and bx), tostring(okb and by), tostring(okl and lx), tostring(okl and ly))
end

-- ---- the final stadium ---------------------------------------------------------------------------------------------------
-- the picture of a map: { path, tex, sprite, st = 0 not asked / 1 loading / 2 in / -1 none }
local function StadiumPicture(map)
  local pic = S.pics[map]
  if pic == nil then
    local path = STADIUM.PICTURE_DIR .. map .. ".g4tx"
    pic = { path = path, tex = Crc(path), sprite = Crc("img_room_" .. map .. "_01"), st = 0, t = 0 }
    S.pics[map] = pic
  end
  if pic.st == 0 then
    local ok = pcall(M, "LOAD_TEX", pic.path)
    pic.st, pic.t = ok and 1 or -1, 0
    S.pic_load = ok and map or nil
    Log("final stadium picture: " .. pic.path .. (ok and " asked" or " not loadable (name only)"))
  end
  return pic
end

-- from Step while a picture loads: once it is in, the page again
local function StadiumLoadStep()
  local pic = S.pic_load and S.pics[S.pic_load]
  if not pic or pic.st ~= 1 then
    S.pic_load = nil
    return
  end
  pic.t = pic.t + 1
  local ok, busy = pcall(funcLuaCommand, N_CMD.TEX_LOADING, pic.tex)
  if not ok or pic.t > STADIUM.LOAD_MAX then
    pic.st, S.pic_load = -1, nil
    Log("final stadium picture: never loaded (name only)", pic.path)
    return
  end
  if busy ~= true and pic.t >= STADIUM.LOAD_MIN then
    pic.st, S.pic_load = 2, nil
    Log("final stadium picture: in after " .. pic.t .. " frames")
    S.want = true
  end
end

-- the stadium of the final on the round panel's object: «Estadio de la final», the stadium's name, the picture left
-- of the panel; nothing when the view has no final_stadium
local function DrawStadium(v)
  local fs = v.final_stadium
  if type(fs) ~= "table" or type(fs.map) ~= "string" or fs.map == "" then
    return
  end
  local id = type(fs.id) == "number" and fs.id or Crc(fs.map)
  local okn, name = pcall(funcLuaCommand, K("MAP_NAME"), id)
  if not okn or type(name) ~= "string" then
    name = ""
  end
  local l = L.stadium_panel
  local i = Take(l)
  M("VISIBLE", l, i, true)
  M("SCALE", l, 1, 1, 1, i)
  M("POS", l, G.CX, -STADIUM.Y, 0, i)
  for node, s in pairs({ [RETAIL.TXT_ROUND] = Text("final_stadium"), [RETAIL.TXT_NEXT] = name, [RETAIL.TXT_PLAYED] = "",
    [RETAIL.TXT_SPARE] = "" }) do
    M("TEXT", l, Crc(node), s, i)
    M("TEXT_VISIBLE", l, Crc(node), s ~= "", i)
  end
  local pic = StadiumPicture(fs.map)
  if pic.st == 2 then
    Quad("box", pic.sprite, G.CX - STADIUM.PANEL_W / 2 - STADIUM.PAD - STADIUM.THUMB_W / 2, STADIUM.Y, STADIUM.THUMB_W,
      STADIUM.THUMB_H, WHITE, nil, pic.tex)
  end
  local key = fs.map .. ":" .. pic.st
  if S.stadium_logged ~= key then
    S.stadium_logged = key
    Log(string.format("final stadium panel: %s «%s» (picture %s)", fs.map, name,
      pic.st == 2 and "shown" or (pic.st == 1 and "loading" or "none")))
  end
end

-- ---- the advance ---------------------------------------------------------------------------------------------------------
-- the point at fraction f (0..1) of a polyline's length
local function Along(path, f)
  local total, lens = 0, {}
  for k = 2, #path do
    local d = math.abs(path[k][1] - path[k - 1][1]) + math.abs(path[k][2] - path[k - 1][2])
    lens[k] = d
    total = total + d
  end
  if total <= 0 then
    return path[#path][1], path[#path][2]
  end
  local want = total * f
  for k = 2, #path do
    if want <= lens[k] or k == #path then
      local u = lens[k] > 0 and math.min(1, want / lens[k]) or 1
      local a, b = path[k - 1], path[k]
      return a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u
    end
    want = want - lens[k]
  end
  return path[#path][1], path[#path][2]
end

local function Ease(p)
  if p < 0.5 then
    return 4 * p * p * p
  end
  return 1 - (-2 * p + 2) ^ 3 / 2
end

local function ChampionVisible(show)
  if S.view and (S.view.champion or 0) ~= 0 then
    M("VISIBLE", L.row_l, ROW_CHAMP, show)
  end
end

-- place every walking crest / strip at the animation's time
local function AnimApply()
  local an = S.anim
  if not an then
    return
  end
  if an.retail then
    local busy = false
    for _, it in ipairs(an.items) do
      local p = math.max(0, math.min(1, (an.t - it.delay) / ADV.DUR))
      if p < 1 then
        busy = true
      end
      RetailRate(it.slot, it.from + (it.to - it.from) * Ease(p))
    end
    if an.final then
      ChampionVisible(not busy)
    end
    return
  end
  local champ_wait = false
  for _, c in ipairs(an.items) do
    local p = math.max(0, math.min(1, (an.t - c.delay) / ADV.DUR))
    local e = Ease(p)
    local x, y = Along(c.path, e)
    local sc = c.s + ((c.s1 or c.s) - c.s) * e
    M("VISIBLE", L.crest, c.i, not (c.final and p >= 1))
    M("SCALE", L.crest, sc, sc, 1, c.i)
    M("POS", L.crest, x - ADV.CREST_X * sc, -y, 0, c.i)
    if c.star then
      M("VISIBLE", L.box, c.star, p >= 1)
    end
    if c.final and p < 1 then
      champ_wait = true
    end
  end
  ChampionVisible(not champ_wait)
end

local function Param(name)
  return Crc("vrfw_bracket_" .. name)
end

local function AnimFinish(why)
  VRFW_Param.Clear(Param("busy"))
  local an = S.anim
  if not an then
    return
  end
  an.t = an.done_at + 1
  AnimApply()
  S.anim = nil
  Log("bracket advance:", why)
end

-- the round just played (the last one with a result) walks; nothing when the tree has no result yet
local function AnimStart(v)
  S.anim = nil
  local A = ADV
  local items, an = {}, nil
  if S.retail then
    local rt = S.retail
    if rt.last > 0 then
      for k = 1, #rt.rates do
        if rt.prev[k] ~= rt.rates[k] then
          items[#items + 1] = { slot = k, from = rt.prev[k], to = rt.rates[k] }
        end
      end
      an = { t = 0, page = v.page, retail = true, items = items, round = rt.last, final = rt.last == RETAIL.ROUNDS }
    end
  else
    local last = 0
    for _, c in ipairs(S.crests) do
      last = math.max(last, c.round)
    end
    for _, c in ipairs(S.crests) do
      if last > 0 and c.round == last then
        if c.i == nil then
          c.i = Crest(c, c.path[1][1], c.path[1][2], c.s)   -- the final's winner: a crest of its own for the walk
        end
        if c.i ~= nil then
          items[#items + 1] = c
        end
      end
    end
    an = { t = 0, page = v.page, items = items, round = last }
  end
  if an == nil or #items == 0 then
    AnimFinish("nothing to advance")
    return
  end
  local gap = math.min(A.STAGGER, A.STAGGER_ALL / #items)
  for k, it in ipairs(items) do
    it.delay = (k - 1) * gap
  end
  an.done_at = (#items - 1) * gap + A.DUR
  S.anim = an
  AnimApply()
  Log(string.format("bracket advance: round %d, %d %s", an.round, #items, an.retail and "path(s) on the retail art"
    or "crest(s) walk"))
end

local function AnimStep()
  local an = S.anim
  if not an then
    return
  end
  local ok, dt = pcall(funcLuaCommand, N_CMD.FRAME_TIME)
  if not ok or type(dt) ~= "number" or dt <= 0 or dt > 0.5 then
    dt = 1 / 60
  end
  an.t = an.t + dt
  if an.t >= an.done_at then
    AnimFinish("done")
    return
  end
  AnimApply()
end

-- ---- the page --------------------------------------------------------------------------------------------------------------
local function ParamInt(name)
  return tonumber(VRFW_Param.Get(Param(name)))
end

local function ParamU32(name)
  return VRFW_Param.GetU32("vrfw_bracket_" .. name)
end

-- the host's handshake parameters (at the opening and at every redraw request)
local function ReadParams()
  S.page = C.Page() or S.page or -1
  S.host = C.Host() or S.host
  S.view_cmd = ParamU32("view") or S.view_cmd
  S.top = ParamInt("top") or 0
  S.lift = ParamInt("lift") or 0
end

-- the retail art over a host's background: each retail layer's own priority + lift (once per instance and value)
local function Lift()
  if S.lift == 0 and next(S.lifted) == nil then
    return
  end
  RetailEach(function(l, i)
    local key = tostring(l) .. ":" .. i
    local want = RL.prio[l] + S.lift
    if S.lifted[key] ~= want then
      S.lifted[key] = want
      pcall(M, "PRIORITY", l, i, want, true)
    end
  end)
  if S.lifted.panel ~= S.lift then
    S.lifted.panel = S.lift
    pcall(M, "PRIORITY", L.stadium_panel, 0, RETAIL_PRIO.stadium_panel + S.lift, true)
  end
end

-- the page drawn: every piece shown, the rest of each pool hidden; false = the view not answered yet
local function Draw()
  if (S.view_cmd or 0) == 0 then
    Log("bracket menu: no view command from the host; nothing drawn")
    return true
  end
  local ok, v = pcall(funcLuaCommand, S.view_cmd, S.page or -1)
  if not ok or type(v) ~= "table" then
    return false
  end
  Lift()
  S.view = v
  Begin()
  local tree = v.kind == "tree" and type(v.leaves) == "table" and type(v.matches) == "table"
  local retail = tree and tonumber(v.rounds) == RETAIL.ROUNDS and RetailReady()
  S.retail = nil
  if RetailReady() then
    RetailShow(retail)
  end
  S.trophy = tree and not retail and RetailReady()
  if RetailReady() then
    pcall(TrophyPlace, S.trophy, S.top > 0 and (S.top - G.TOP) or 0)
  end
  local note = ""
  local okd, err = pcall(function()
    if retail then
      note = DrawRetail(v)
    elseif tree then
      DrawTree(v)
    end
    if tree then
      DrawStadium(v)
    end
  end)
  if not okd then
    Log("bracket menu: draw error", tostring(err))
  end
  End()
  local skip = ParamInt("skip") ~= nil
  if skip then
    VRFW_Param.Clear(Param("skip"))
  end
  if S.animate and not skip then
    local oka, erra = pcall(AnimStart, v)
    if not oka then
      S.anim = nil
      AnimFinish("advance error " .. tostring(erra))
    end
  elseif S.anim and S.anim.page == v.page then
    pcall(AnimApply)
    if skip then
      AnimFinish("skipped")
    end
  else
    S.anim = nil
    AnimFinish(skip and "skipped" or "no advance")
  end
  S.animate = false
  S.drawn = true
  local u = S.used
  local line = string.format("bracket drawn on %s (kind %s, rounds %s, top %d, lift %d; plates %d+%d, lines %d, crests %d) %s",
    VRFW_Id.hex(S.host or 0), tostring(v.kind), tostring(v.rounds), S.top, S.lift, u[L.row_l] or 0, u[L.row_r] or 0,
    u[L.line] or 0, u[L.crest] or 0, note)
  if S.logged.last ~= line then
    S.logged.last = line
    Log(line .. (S.got < S.need and string.format(" (instances set up %d of %d)", S.got, S.need) or ""))
  end
  return true
end

-- every instance hidden (nothing of the bracket left on screen)
local function HideAll()
  for k, l in pairs(L) do
    for i = 0, N[k] - 1 do
      pcall(Hide, l, i)
    end
  end
  if RL then
    RetailEach(function(l, i)
      pcall(M, "VISIBLE", l, i, false)
    end)
  end
end

-- closing (the host's close): every piece hidden at once, no draw any more; VRFW_ChildMenu closes this menu
local function OnClose()
  S.want, S.drawn, S.anim = false, false, nil
  VRFW_Param.Clear(Param("busy"))
  HideAll()
end

-- the host's redraw (VRFW_ChildMenu): the page again, an advance when asked
local function OnRedraw(page, animate)
  ReadParams()
  S.page = page or S.page
  S.animate = S.animate or animate == true
  S.want = true
end

-- ---- the host's calls (cross-menu call) -----------------------------------------------------------------------------------
function VRFW_Bracket_Skip()
  VRFW_Param.Clear(Param("skip"))
  AnimFinish("skipped")
end

-- ---- engine callbacks -----------------------------------------------------------------------------------------------------
function OnInit()
  Layers()
  C = VRFW_ChildMenu.Child(MENU_NAME, { prefix = "vrfw_bracket_", on_redraw = OnRedraw, on_close = OnClose,
    log = function(...) Log("bracket menu:", ...) end })
  C.Init()
  S.page, S.host, S.view_cmd = -1, nil, nil
  ReadParams()
  S.need, S.got, S.seen, S.frame = 0, 0, {}, 0
  S.drawn, S.want, S.stuck, S.emb, S.strip, S.prio, S.crest_prio, S.lifted = false, true, false, {}, {}, {}, {}, {}
  S.anim, S.logged, S.retail_ok = nil, {}, nil
  S.animate = ParamInt("busy") ~= nil
  for _, n in pairs(N) do
    S.need = S.need + n
  end
  S.need = S.need + 1 + 1 + 1 + #RL.lines + RETAIL.STARS + 8 + 4 + 2 + 1
end

-- every instance hidden as the engine sets it up (opened with the menu's group); one set up after the page was drawn:
-- the page again
function OnSetupLayer(a1, a2)
  Layers()
  local pool = KEY_OF[a1]
  if pool == nil and RL.prio[a1] == nil then
    return
  end
  local i = a2 or 0
  if pool then
    Hide(a1, i)
  else
    M("VISIBLE", a1, i, false)
  end
  local k = tostring(a1) .. ":" .. tostring(i)
  if not S.seen[k] then
    S.seen[k] = true
    S.got = S.got + 1
  end
  S.emb[k], S.strip[k], S.prio[k], S.lifted[k] = nil, nil, nil, nil
  if a1 == L.crest then
    S.crest_prio[i] = nil
  end
  if S.drawn then
    S.want = true
  end
end

function OnOpenLayer(a1, a2)
end

function Step()
  S.frame = S.frame + 1
  if C.Step() then
    return   -- closing
  end
  if S.want and (S.got >= S.need or S.frame >= 120) then
    if S.got < S.need and not S.stuck then
      S.stuck = true
      Log("bracket menu: STUCK? only", S.got, "of", S.need, "instances set up after", S.frame, "frames: drawn anyway")
    end
    if Draw() then
      S.want = false
    end
  end
  if S.pic_load ~= nil then
    local okp, errp = pcall(StadiumLoadStep)
    if not okp then
      S.pic_load = nil
      Log("final stadium picture error", tostring(errp))
    end
  end
  if S.anim then
    local oka, erra = pcall(AnimStep)
    if not oka then
      S.anim = nil
      AnimFinish("advance error " .. tostring(erra))
    end
  end
end

function FinalizeMenu()
  if C then
    C.Finalize()
  end
end
