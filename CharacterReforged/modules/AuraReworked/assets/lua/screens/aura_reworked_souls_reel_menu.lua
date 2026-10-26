-- aura_reworked_souls_reel_menu (plain Lua 5.2 source): Souls Rework's skill carousel (docs/game/mods/
-- souls-rework-design.md §5). Declared in content\menus\reel.toml ([[screen]], served as
-- common/script/lua/menu/aura_reworked_souls_reel_menu.lua.bin). Opened by scripts\souls_rework.lua when the cut-in of a
-- totem's own move starts (or over play when the move has no cut-in); closed by itself after its last frame, or by the
-- script when that cut-in ends first.
-- The totem's 6 skills are small flat cards in a row at the top of the screen: the centre card in front, the cards
-- beside it smaller and dimmer. The row spins through the 6 cards a few times, slows down, runs a little past the
-- result and settles back on it: the card in the centre is the result. Each card: its plate in the totem's element
-- colour (grey for a miss), the skill family's icon, its short name and, under it, «Nv.N» and three level diamonds.
-- Data: CMND_AURAREWORKED_SOULS_REEL once in OnInit (the roll, the layout of config.toml [souls.reel], the cards); the
-- stop is reported with CMND_AURAREWORKED_SOULS_REEL_LANDED. The spin runs as a coroutine resumed from Step, as the
-- game's tactics_roulette_menu does. No input. No engine call at load time.

local MENU = "aura_reworked_souls_reel_menu"
local CMD = { REEL = "CMND_AURAREWORKED_SOULS_REEL", LANDED = "CMND_AURAREWORKED_SOULS_REEL_LANDED" }
local C = {
  LOG = 3661580131 --[[CMND_EVT_LOG]], FRAME_SECONDS = 1549797111 --[[seconds since the last frame]],
  CLOSE_MENU = 320421347 --[[CMND_CLOSE_MENU_OBJECT]], IS_OPEN = 2640875187 --[[CMND_IS_OPEN_LAYER]],
  LAYER_NUM = 1175615627 --[[CMND_GET_CREATE_LAYER_NUM]], VISIBLE = 711242136 --[[CMND_SET_LAYER_VISIBLE]],
  POS = 1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], SCALE = 3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]],
  SPRITE = 558735651 --[[swap a mesh texture for an atlas sprite]], ALPHA = 4231609516 --[[CMND_SET_LAYER_MODEL_ALPHA]],
  MESH_VISIBLE = 3405944500 --[[CMND_SET_MESH_VISIBLE]], SET_TEXT = 1083631230 --[[CMND_SET_MENU_TEXT_STRING]],
  TEXT_STYLE = 2333948100 --[[the text node's font style]], TEXT_ALPHA = 1126837159 --[[CMND_SET_MENU_TEXT_ALPHA]],
  TEXT_SIZE = 3549540977 --[[CMND_GET_MENU_TEXT_RECT_SIZE]], TINT = 855211291 --[[CMND_SET_PRIM_COLOR]],
  SET_PRIO = 1491630496 --[[CMND_SET_DRAW_PRIORITY]], LOAD_TEX = 839427544 --[[CMND_LOAD_MENU_RES_TEXTURE]],
  TEX_LOADING = 1506186496 --[[the texture is still loading]],
}
-- the screen's layers (content\menus\reel.toml) and their pieces
local LAYER_NAME = { QUAD = "souls_rework_reel_quad", TEXT = "souls_rework_reel_text" }
local QUAD = { SLOT = "icon_new01", MESH = "_icon_new01", SIDE = 36 }   -- cmn01_10: the quad's sprite slot, mesh, side
local TXT = { NODE = "_text_cmd_back01", PLATE_MESHES = { "_cmd_back_base01", "_cmd_back_base01_add" },
  BOX_LEFT = -384, BOX_MID_Y = 144, STYLE = "fs2_26_w_lc_2d2_001_nr", STYLE_PX = 26 }
local ATLAS = "#/menu/02_btl/souls_rework_reel/souls_rework_reel.g4tx"
local SPRITE = { PLATE = "souls_rework_reel_plate", LEVEL_ON = "souls_rework_reel_level_on",
  LEVEL_OFF = "souls_rework_reel_level_off" }
local PRIO = { PLATE = 318, FRONT = 319 }
local CARDS_DRAWN = 5                  -- the 3 shown and the 2 entering / leaving
local QUADS_PER_CARD = 5               -- plate, icon, 3 diamonds
local TEXTS_PER_CARD = 2               -- name, level
local WAIT_LOAD_S = 3                  -- layers / textures not ready after this long: closed
local CARD_PAD = 8                     -- room kept free at each end of a card (px)

local S = { sent = {}, widths = {}, co = nil, roll = nil, crc = {} }

-- ---- helpers (this screen has its own VM) ----------------------------------------------------------------------

local CRC_T = nil
local function Crc(s)
  local c = S.crc[s]
  if c ~= nil then return c end
  if CRC_T == nil then
    CRC_T = {}
    for i = 0, 255 do
      local v = i
      for _ = 1, 8 do
        if v % 2 == 1 then v = bit32.bxor(bit32.rshift(v, 1), 0xEDB88320) else v = bit32.rshift(v, 1) end
      end
      CRC_T[i] = v
    end
  end
  c = 0xFFFFFFFF
  for i = 1, #s do
    c = bit32.bxor(bit32.rshift(c, 8), CRC_T[bit32.band(bit32.bxor(c, s:byte(i)), 0xFF)])
  end
  c = bit32.bxor(c, 0xFFFFFFFF)
  S.crc[s] = c
  return c
end

-- the layers by their crc (menu commands take the crc)
local LAYER = { QUAD = Crc(LAYER_NAME.QUAD), TEXT = Crc(LAYER_NAME.TEXT) }

local function Log(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  pcall(funcLuaCommand, C.LOG, "aura_reworked souls carousel " .. table.concat(p, " "))
end

local function M(cmd, ...)
  local ok, a, b = pcall(funcLuaMenuCommand, cmd, ...)
  if ok then return a, b end
  return nil
end

-- a menu command sent only when its values changed since the last frame
local function Set(layer, idx, prop, cmd, ...)
  local k = layer .. ":" .. idx .. ":" .. prop
  local a = table.pack(...)
  local sig = {}
  for i = 1, a.n do sig[#sig + 1] = tostring(a[i]) end
  sig = table.concat(sig, ",")
  if S.sent[k] == sig then return end
  S.sent[k] = sig
  M(cmd, ...)
end

local function Round(v) return math.floor(v * 100 + 0.5) / 100 end

local function Hide(layer, i) Set(layer, i, "vis", C.VISIBLE, layer, i, false) end

local function TexReady(tex)
  if S.asked == nil then S.asked = {} end
  if not S.asked[tex] then
    S.asked[tex] = true
    M(C.LOAD_TEX, tex)
  end
  local ok, loading = pcall(funcLuaCommand, C.TEX_LOADING, Crc(tex))
  return ok and loading == false
end

-- ---- the roll ----------------------------------------------------------------------------------------------------

local function ParseLayout(s)
  local t = {}
  for k, v in tostring(s or ""):gmatch("([%w_]+)=([^;]*)") do t[k] = tonumber(v) or v end
  return t
end

local function ParseCards(s)
  local cards = {}
  for line in (tostring(s or "") .. "\n"):gmatch("([^\n]*)\n") do
    if line ~= "" then
      local f = {}
      for part in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = part end
      cards[#cards + 1] = { icon = f[1] or "", level = tonumber(f[2]) or 0, miss = f[3] == "1", name = f[4] or "",
        level_text = f[5] or "" }
    end
  end
  return cards
end

local function AskRoll()
  local ok, seq, slot, look, cards = pcall(funcLuaCommand, Crc(CMD.REEL))
  if not ok or type(seq) ~= "number" or seq == 0 then return nil end
  local roll = { seq = seq, slot = tonumber(slot) or 1, look = ParseLayout(look), cards = ParseCards(cards) }
  if #roll.cards == 0 then return nil end
  return roll
end

-- ---- drawing -----------------------------------------------------------------------------------------------------

-- a text's width in screen px at height `px` (measured by the game; estimated when it does not answer)
local function TextWidth(i, s, px)
  local w = S.widths[s]
  if w == nil then
    -- measured on the instance at scale 1 in the cards' style (the next Text() of it sets its own scale again)
    M(C.TEXT_STYLE, LAYER.TEXT, i, Crc(TXT.NODE), Crc(TXT.STYLE))
    M(C.SCALE, LAYER.TEXT, 1, 1, 1, i)
    S.sent[LAYER.TEXT .. ":" .. i .. ":sc"] = nil
    w = M(C.TEXT_SIZE, LAYER.TEXT, i, Crc(TXT.NODE), s)
    if type(w) ~= "number" or w <= 1 or w > 4000 then
      w = 0
      for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do w = w + (((ch:byte(1) or 0) >= 0xE3) and 1 or 0.55) end
      w = w * TXT.STYLE_PX
    end
    S.widths[s] = w
  end
  return w * px / TXT.STYLE_PX
end

local function Quad(i, tex, sprite, cx, cy, w, h, alpha, prio, tint)
  local L = LAYER.QUAD
  Set(L, i, "sp", C.SPRITE, L, Crc(tex), Crc(sprite), Crc(QUAD.SLOT), 0, i)
  Set(L, i, "sc", C.SCALE, L, Round(w / QUAD.SIDE), Round(h / QUAD.SIDE), 1, i)
  Set(L, i, "pos", C.POS, L, Round(cx), Round(-cy), 0, i)
  Set(L, i, "prio", C.SET_PRIO, L, i, prio, true)
  local t = tint or { 1, 1, 1 }
  Set(L, i, "tint", C.TINT, L, i, Crc(QUAD.MESH), t[1], t[2], t[3])
  Set(L, i, "a", C.ALPHA, L, i, 0, Round(alpha))
  Set(L, i, "vis", C.VISIBLE, L, i, true)
end

-- a text: left edge x, vertical middle y, height px
local function Text(i, s, x, y, px, alpha)
  local L = LAYER.TEXT
  local sc = px / TXT.STYLE_PX
  for _, m in ipairs(TXT.PLATE_MESHES) do Set(L, i, "m" .. m, C.MESH_VISIBLE, L, Crc(m), false, i) end
  Set(L, i, "st", C.TEXT_STYLE, L, i, Crc(TXT.NODE), Crc(TXT.STYLE))
  Set(L, i, "txt", C.SET_TEXT, L, Crc(TXT.NODE), s, i)
  Set(L, i, "sc", C.SCALE, L, Round(sc), Round(sc), 1, i)
  Set(L, i, "pos", C.POS, L, Round(x - TXT.BOX_LEFT * sc), Round(-y - TXT.BOX_MID_Y * sc), 0, i)
  Set(L, i, "a", C.ALPHA, L, i, 0, Round(alpha))
  Set(L, i, "ta", C.TEXT_ALPHA, L, i, Crc(TXT.NODE), Round(alpha))
  Set(L, i, "vis", C.VISIBLE, L, i, true)
end

local function HideCard(n)
  for k = 0, QUADS_PER_CARD - 1 do Hide(LAYER.QUAD, n * QUADS_PER_CARD + k) end
  for k = 0, TEXTS_PER_CARD - 1 do Hide(LAYER.TEXT, n * TEXTS_PER_CARD + k) end
end

-- card `card` drawn with the pieces of drawn card `n`, centred on (x, y) at scale s and opacity a
local function DrawCard(n, card, x, y, s, a)
  local L = S.roll.look
  local q, t = n * QUADS_PER_CARD, n * TEXTS_PER_CARD
  local plate = card.miss and { L.mr or 0.36, L.mg or 0.38, L.mb or 0.44 } or { L.r or 0.5, L.g or 0.5, L.b or 0.5 }
  Quad(q, ATLAS, SPRITE.PLATE, x, y, L.w * s, L.h * s, a, PRIO.PLATE, plate)
  -- the icon and the text block as one group centred on the card, made smaller when it is wider than the card
  local name_w = TextWidth(t, card.name, L.name_px)
  local level_text_w = card.level > 0 and TextWidth(t + 1, card.level_text, L.level_px) or 0
  local level_w = card.level > 0 and (level_text_w + 8 + L.dia_gap * 2 + L.dia) or 0
  local block_w = math.max(name_w, level_w)
  local has_icon = card.icon ~= "" and type(L.atlas) == "string" and L.atlas ~= ""
  local icon_w = has_icon and (L.icon + L.icon_gap) or 0
  local room = L.w - 2 * CARD_PAD
  local g = s * math.min(1, room / math.max(icon_w + block_w, 1))
  local left = x - (icon_w + block_w) * g / 2
  if has_icon then
    Quad(q + 1, L.atlas, card.icon, left + L.icon * g / 2, y, L.icon * g, L.icon * g, a, PRIO.FRONT)
  else
    Hide(LAYER.QUAD, q + 1)
  end
  local tx = left + icon_w * g
  if card.level > 0 then
    local top = y - (L.name_px + L.line_gap + L.level_px) * g / 2
    Text(t, card.name, tx + (block_w - name_w) * g / 2, top + L.name_px * g / 2, L.name_px * g, a)
    local lx = tx + (block_w - level_w) * g / 2
    local ly = top + (L.name_px + L.line_gap + L.level_px / 2) * g
    Text(t + 1, card.level_text, lx, ly, L.level_px * g, a)
    local dx = lx + (level_text_w + 8 + L.dia / 2) * g
    for k = 0, 2 do
      Quad(q + 2 + k, ATLAS, k < card.level and SPRITE.LEVEL_ON or SPRITE.LEVEL_OFF, dx + k * L.dia_gap * g, ly,
        L.dia * g, L.dia * g, a, PRIO.FRONT)
    end
  else
    Text(t, card.name, tx + (block_w - name_w) * g / 2, y, L.name_px * g, a)
    Hide(LAYER.TEXT, t + 1)
    for k = 0, 2 do Hide(LAYER.QUAD, q + 2 + k) end
  end
end

-- the row at position p (card index at the centre, 0-based, fractional while it moves), global opacity ga
local function Draw(p, ga)
  local L = S.roll.look
  local cards = S.roll.cards
  local base = math.floor(p + 0.5)
  for j = -2, 2 do
    local n = j + 2
    local k = base + j
    local d = k - p
    local ad = math.abs(d)
    if ad > 1.5 or ga <= 0 then
      HideCard(n)
    else
      local near = math.min(ad, 1)
      local s = 1 - (1 - L.side_scale) * near
      local a = (1 - (1 - L.side_alpha) * near) * ga
      if ad > 1 then a = a * (1.5 - ad) / 0.5 end
      DrawCard(n, cards[k % #cards + 1], L.cx + d * L.gap, L.cy, s, a)
    end
  end
end

-- ---- the spin ----------------------------------------------------------------------------------------------------

local function Dt()
  local ok, dt = pcall(funcLuaCommand, C.FRAME_SECONDS)
  if not ok or type(dt) ~= "number" or dt <= 0 or dt > 0.5 then return 1 / 60 end
  return dt
end

local function Close()
  for n = 0, CARDS_DRAWN - 1 do HideCard(n) end
  pcall(funcLuaCommand, C.CLOSE_MENU, Crc(MENU))
end

local function Run()
  -- the layers open with the screen; the atlases are in its res list
  local waited = 0
  while true do
    local open = M(C.IS_OPEN, LAYER.QUAD) == true and M(C.IS_OPEN, LAYER.TEXT) == true
    local icons = S.roll.look.atlas
    if open and TexReady(ATLAS) and (type(icons) ~= "string" or icons == "" or TexReady(icons)) then break end
    waited = waited + Dt()
    if waited > WAIT_LOAD_S then
      Log("not ready after", WAIT_LOAD_S, "s: closed")
      Close()
      return
    end
    coroutine.yield()
  end
  local L = S.roll.look
  local n = #S.roll.cards
  local target = (S.roll.slot - 1) + n * (L.loops or 3)
  local start = S.roll.slot - 1
  local over = L.settle or 0
  local t_spin, t_land = L.open, L.open + L.spin + L.settle_s
  local t_close = t_land + L.hold
  local t_end = t_close + L.close
  local t, landed = 0, false
  Log("roll", S.roll.seq, "slot", S.roll.slot, "of", n)
  while t < t_end do
    local p
    if t < t_spin then
      p = start
    elseif t < t_spin + L.spin then
      local u = (t - t_spin) / L.spin
      p = start + (target + over - start) * (1 - (1 - u) ^ 3)
    elseif t < t_land then
      local u = (t - t_spin - L.spin) / math.max(L.settle_s, 0.01)
      p = target + over * (1 - u * u * (3 - 2 * u))
    else
      p = target
      if not landed then
        landed = true
        pcall(funcLuaCommand, Crc(CMD.LANDED), S.roll.seq)
      end
    end
    local ga = 1
    if t < L.open then ga = t / math.max(L.open, 0.01) elseif t > t_close then ga = 1 - (t - t_close) / math.max(L.close, 0.01) end
    Draw(p, math.max(0, math.min(1, ga)))
    coroutine.yield()
    t = t + Dt()
  end
  Close()
end

-- ---- the screen --------------------------------------------------------------------------------------------------

function OnInit()
  S.sent, S.widths, S.asked, S.co = {}, {}, {}, nil
  S.roll = AskRoll()
  if S.roll == nil then
    Log("no roll to show: closed")
    S.close_now = true
    return
  end
  S.close_now = false
  S.co = coroutine.create(Run)
end

function OnSetupLayer(a1, a2)
  if a1 == LAYER.QUAD or a1 == LAYER.TEXT then
    M(C.VISIBLE, a1, a2, false)
    local prefix = a1 .. ":" .. a2 .. ":"
    for k in pairs(S.sent) do
      if string.sub(k, 1, #prefix) == prefix then S.sent[k] = nil end
    end
  end
end

function OnOpenLayer(a1, a2)
end

function Step()
  if S.close_now then
    S.close_now = false
    Close()
    return
  end
  if S.co == nil then return end
  local ok, err = coroutine.resume(S.co)
  if not ok then
    Log("error", tostring(err))
    S.co = nil
    Close()
  elseif coroutine.status(S.co) == "dead" then
    S.co = nil
  end
end

function FinalizeMenu()
end
