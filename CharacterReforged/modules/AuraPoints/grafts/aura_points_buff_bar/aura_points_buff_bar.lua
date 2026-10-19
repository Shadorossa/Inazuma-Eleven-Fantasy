-- Aura Points (mod aura_points): the PEG / SP bars of the match buff row (docs/game/mechanics/aura-costs.md §12.8;
-- docs/refactor/aura-mods-split.md «Aura Points»). Ported on 2026-10-14 from Inazuma Fantasy's graft mx_popup
-- (EVT_AURA_PEG, 2026-10-04 user design) after the owner's report: with Aura Points the armour's entry of this row
-- showed the retail stopwatch (its time in %) instead of the purple PEG bar IF had.
-- * soccer_team_buff_icon_list_menu: the bottom row of team passives and active auras. Each aura user has an entry
--   (portrait soccer00_53_aura_buff_chara_icon + circular time gauge soccer00_54_aura_recast_gauge, instance k = his
--   place among the team's aura users, as the retail UpdateAuraBuffCharaIcon builds it).
-- * For a keshin / armour entry (aura attr 0x01 / 0x02) the purple PEG bar of his pool, for a totem (0x08) the blue SP
--   bar: pool left / max of CMND_AURAPOINTS_PEG(hdl) (scripts\aura_points.lua). For a miximax entry (0x04) the PE bar
--   of the mod's PE part (CMND_AURAPOINTS_STAMINA(hdl), the retail fill), as Inazuma Fantasy drew it. A mode change
--   of the mod All Changed (its swap running: CMND_ALLCHANGED_SWAP_GAUGE(hdl) -> active, recovered 0..1) shows an
--   orange recharge bar that fills over the swap's cooldown (real time, its slot's cooldown_s): full = he may swap
--   again. A player with two auras at once gets both bars, the second one under the first. The entry's stopwatch is
--   hidden while a bar shows. No pool for him (a team the pools do not apply to, no PE / All Changed): nothing
--   changes. While the mod's options «peg» and «sp» are both off (AuraPoints_BuffRow.PoolsOn() of
--   aura_points_buff_row.lua) nothing is drawn: the retail row.
-- * Layer aura_points_buff_bar (2 instances per entry: k for the first bar of entry k, k + rows for its second, rows =
--   the row's entries now, AuraPoints_BuffRow.Rows() of aura_points_buff_row.lua; the mod's content\menus\buff_bar.toml:
--   object aura_points_peg_bar, hung on the portrait's locator by copies of its attach rows), placed every frame under
--   the portrait's local position.
-- * Inazuma Fantasy's mx_popup draws the same bars (and its PE / mode change ones) when it is in this script: then this
--   block draws nothing (IF's global EVT_AP with EVT_AURA_PEG on), so no bar is drawn twice.
-- * Under every bar the pool as a number «current / max» (whole numbers, the row's own «55 %» font: the white digits with a
--   dark outline; layer aura_points_buff_digit, 7 glyph slots per bar instance = 3 digits, a slash, 3 digits, the
--   mod's content\menus\buff_digits.toml, sprites content\images\...\btl06_13\aura_points_buff_num.toml), centred under
--   the bar; the PE bar gets it too, an entry with two bars shows both (the second one a bar + number
--   block lower). The mode change's recharge bar has no number. A glyph is swapped only when it changes, a slot is moved
--   only when the portrait moved.
-- * A totem's entry (aura attr 0x08) also shows its level on the tile's top edge, «Lv.3» / «Nv.3» (layer
--   aura_points_buff_level, one instance per entry: the retail AI-camera telop's text; the text is Souls Rework's text key
--   reel_level through its command CMND_SOULSREWORK_TOTEM_LEVEL, so without Souls Rework nothing is drawn).
-- Engine calls only inside the wrapped callbacks (UpdateAuraBuffCharaIcon, Step); nothing at chunk load. Every engine
-- call goes through pcall.
AuraPoints_BuffBar = AuraPoints_BuffBar or {entries = {}, ready = {}, fill = {}, rates = {}, owners = {}, shown = {}}
local B = AuraPoints_BuffBar
B.opened = B.opened or {}              -- bar instances opened in this menu (k -> true)
B.digits = B.digits or {opened = {}, ready = {}, glyph = {}, pos = {}, shown = {}, text = {}}
B.lvl = B.lvl or {opened = {}, ready = {}, shown = {}, text = {}, pos = {}, logged = {}}
B.lvl.logged = B.lvl.logged or {}
B.ON = true                            -- false: no bar (the retail stopwatch everywhere)
B.BAR_W, B.BAR_H = 60, 12              -- bar frame size (layout units; retail frame 476 x 44)
B.DX, B.DY = 0, 0                      -- extra offset from the portrait's position (layout units)
B.GAP = 2                              -- gap between an entry's two bars (layout units)
B.PITCH = 21                           -- distance between an entry's two bar + number blocks (layout units)
B.NUM_H = 9                            -- height of a number glyph cell (layout units); the cell is 44 x 36
B.NUM_W = 9 * 44 / 36                 -- its width
B.NUM_ADV, B.SLASH_ADV, B.ONE_ADV = 7.8, 4.5, 4.8     -- advance of a digit / of the slash / of the narrow «1» (tight: two tiles' numbers never touch)
B.NUM_GAP = 0.5                        -- gap between the bar and its number
B.LEVEL_SCALE = 0.28                   -- the level label's text scale (the telop's text box is 334 x 70)
B.LEVEL_DY = 1                         -- the level label's middle this far below the tile's top edge (layout units)
B.LOGS = B.LOGS or 0                   -- first placements logged (loader.log «aura_points buff bar»)

local CMD_PEG = @crc:CMND_AURAPOINTS_PEG@
local CMD_PE = @crc:CMND_AURAPOINTS_STAMINA@ --[[the mod's PE of a match player]]
local CMD_CHANGE = @crc:CMND_ALLCHANGED_SWAP_GAUGE@ --[[the mod All Changed's swap: active, recovered 0..1]]
local CMD_LOG = @crc:CMND_EVT_LOG@ --[[the loader's log line]]
local LAYER = @crc:aura_points_buff_bar@
local PORTRAIT = 1535165083 --[[soccer00_53_aura_buff_chara_icon]]
local GAUGE = 698939060 --[[soccer00_54_aura_recast_gauge]]
local ATLAS = 1191797350 --[[#/menu/02_btl/btl06/btl06_13/<LG>/btl06_13.g4tx]]
local FILL_SLOT = 1460691304 --[[hp_bar02]]
local FILL_PEG = 351956081 --[[evt_peg_fill01]]
local FILL_SP = 2515711484 --[[evt_sp_fill01]]
local FILL_CHANGE = @crc:aura_points_change_fill01@
local RATE_BAR = 3060237847 --[[hp_bar]]
local RATE_RED = 2546116024 --[[hp_bar_red]]
local MESH_LABEL = 1257514352 --[[_gtxt_stamina01]]
local MESH_EMPTY = 2609329121 --[[_hp_empty01]]
local FRAME_CX, FRAME_CY, FRAME_W, FRAME_H = 332, -838, 476, 44
local K = {} --[[this block's own constants (one local: the menu's main chunk is near the local limit)]]
K.CMD_LEVEL = @crc:CMND_SOULSREWORK_TOTEM_LEVEL@ --[[the mod Souls Rework's totem level of a match player: ok, level, text]]
K.DIGIT_LAYER = @crc:aura_points_buff_digit@
K.LEVEL_LAYER = @crc:aura_points_buff_level@
K.SLOTS = 7 --[[glyph slots per bar: 3 digits, slash, 3 digits]]
K.FRAME_SPRITE = 538967808 --[[hp_base01: the gauge frame's sprite the glyphs replace]]
K.MESH_FILL = 2043683848 --[[_hp_bar02]]
K.ATLAS_GLYPHS = {[0] = @crc:aura_points_buff_num0@, @crc:aura_points_buff_num1@, @crc:aura_points_buff_num2@,
  @crc:aura_points_buff_num3@, @crc:aura_points_buff_num4@, @crc:aura_points_buff_num5@, @crc:aura_points_buff_num6@,
  @crc:aura_points_buff_num7@, @crc:aura_points_buff_num8@, @crc:aura_points_buff_num9@}
K.GLYPH_SLASH = @crc:aura_points_buff_num_slash@
K.LEVEL_QUAD = @crc:_camera_telop01@ --[[the telop's quad (hidden: the label is the text only)]]
K.LEVEL_TEXT = @crc:_text_telop01@
K.LEVEL_TEXT_W = 334 --[[the text node's box at scale 1]]
K.LEVEL_TEXT_H = 70
K.CMND_GLOBAL_POS = 499270986 --[[CMND_GET_MESH_GLOBAL_POSITION]]
K.CMND_LAYER_GLOBAL_POS = 4002164178 --[[a layer instance's global position (layer, instance)]]
K.PROBE_TRIES = 6 --[[level label probe: measurements before it gives up on steady units]]
K.CMND_SET_TEXT = 1083631230 --[[CMND_SET_MENU_TEXT_STRING]]
local CMND_VISIBLE = 711242136 --[[CMND_SET_LAYER_VISIBLE]]
local CMND_IS_VISIBLE = 1262717583 --[[CMND_IS_LAYER_VISIBLE]]
local CMND_OPEN = 629267548 --[[CMND_OPEN_LAYER]]
local CMND_IS_OPEN = 2640875187 --[[CMND_IS_OPEN_LAYER]]
local CMND_IS_LOADING = 3057768039 --[[CMND_IS_LOADING_LAYER]]
local CMND_LOCAL_POS = 2834507455 --[[CMND_GET_LAYER_LOCAL_POS]]
local CMND_SET_POS = 1389957207 --[[CMND_SET_LAYER_LOCAL_POS]]
local CMND_SET_SCALE = 3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]]
local CMND_RATE_INIT = 541357333
local CMND_RATE = 1595998683
local CMND_MESH_VISIBLE = 3405944500 --[[CMND_SET_MESH_VISIBLE]]
local CMND_SWAP_TEX = 558735651 --[[swap a mesh texture: (layer, atlas, new sprite, old sprite, 0, instance)]]
local CMND_MEMBER = 66484325 --[[(team, member, true) -> ok, soccer handle]]
local ATTR_KESHIN, ATTR_ARMOUR, ATTR_MIXIMAX, ATTR_TOTEM = 1, 2, 4, 8
local CHANGE = -1 --[[an entry's mode change bar (no aura bit: the swap gauge decides)]]

-- the mode change's recharge 0..1 while his swap runs; nil = none
local function ChangeRate(hdl)
  local ok, active, rate = pcall(funcLuaCommand, CMD_CHANGE, hdl or 0)
  if ok and active == true and type(rate) == "number" then
    return math.max(0, math.min(1, rate))
  end
  return nil
end

-- the row's entries now (the widened row of aura_points_buff_row.lua); nil = unknown
local function Rows()
  local row = rawget(_ENV, "AuraPoints_BuffRow")
  if type(row) == "table" and type(row.Rows) == "function" then
    local ok, n = pcall(row.Rows)
    if ok and type(n) == "number" and n > 0 then
      return n
    end
  end
  return nil
end

local function Menu(...)
  local ok, a, b, c, d = pcall(funcLuaMenuCommand, ...)
  if ok then
    return a, b, c, d
  end
  return nil
end

local function Log(...)
  pcall(funcLuaCommand, CMD_LOG, "aura_points buff bar", ...)
end

-- the mod's PEG or SP part is on (aura_points_buff_row.lua asks it; without that block: on)
local function PoolsOn()
  local row = rawget(_ENV, "AuraPoints_BuffRow")
  if type(row) == "table" and type(row.PoolsOn) == "function" then
    local ok, on = pcall(row.PoolsOn)
    return ok and on == true
  end
  return true
end

-- Inazuma Fantasy's mx_popup draws these bars itself in this script
local function IfDraws()
  return type(rawget(_ENV, "EVT_AP")) == "table" and rawget(_ENV, "EVT_AURA_PEG") == true
end

-- the aura entries the row just built: k = the portrait instance of the player, one per aura user of the team
function B.Collect()
  local out = {}
  local ok0, okt, team = pcall(GetSoccerTeamInfo, 0)
  if not ok0 or not okt or team == nil then
    return out
  end
  -- the players as the row drew them: portrait instance i shows the player of its drawn state (matched by player
  -- handle, so a bar or label never lands on another player's portrait); without that state, the team's aura users
  -- in member order (the row's own order)
  local cap = Rows()
  local users = {}
  local row = rawget(_ENV, "AuraPoints_BuffRow")
  local drawn = type(row) == "table" and type(row.drawn) == "table" and row.drawn or nil
  for i = 1, drawn ~= nil and #drawn or 0 do
    local d = drawn[i]
    if type(d) == "table" and type(d.auraCharaHdl) == "number" and d.auraCharaHdl ~= 0 and d.auraAttr ~= 0
      and (cap == nil or i <= cap) then
      users[#users + 1] = {hdl = d.auraCharaHdl, attr = d.auraAttr, face = i - 1}
    end
  end
  for i = 0, drawn ~= nil and -1 or 28 do
    local ok, ok2, hdl = pcall(funcLuaCommand, CMND_MEMBER, team, i, true)
    if ok and ok2 and hdl ~= nil and hdl ~= 0 then
      local oka, has, attr = pcall(GetSoccerCharaInfo, hdl, 26)
      if oka and has and type(attr) == "number" and attr ~= 0 then
        users[#users + 1] = {hdl = hdl, attr = attr}
        if cap ~= nil and #users >= cap then
          break
        end
      end
    end
  end
  -- second bars from instance `rows` on
  local rows = cap or (drawn ~= nil and #drawn) or #users
  -- the portrait of each player, logged when it changes
  local map = {}
  for _, u in ipairs(users) do
    map[#map + 1] = string.format("%s:0x%X", tostring(u.face), u.hdl)
  end
  map = table.concat(map, " ")
  if map ~= B.map then
    B.map = map
    Log("portraits", drawn ~= nil and "drawn state" or "member order", map)
  end
  for k0, u in ipairs(users) do
    local k = u.face or (k0 - 1)
    -- the miximax's PE or the mode change's recharge first, then the keshin / armour / totem pool
    local track = 0
    if ChangeRate(u.hdl) ~= nil then
      out[#out + 1] = {k = k, face = k, track = track, hdl = u.hdl, attr = CHANGE}
      track = track + 1
    elseif bit32.band(u.attr, ATTR_MIXIMAX) ~= 0 then
      out[#out + 1] = {k = k, face = k, track = track, hdl = u.hdl, attr = ATTR_MIXIMAX}
      track = track + 1
    end
    local spirit = bit32.band(u.attr, ATTR_KESHIN + ATTR_ARMOUR + ATTR_TOTEM)
    if spirit ~= 0 then
      out[#out + 1] = {k = k + track * rows, face = k, track = track, hdl = u.hdl, attr = spirit}
    end
  end
  return out
end

-- pool left / max of the player's miximax (PE), keshin / armour (PEG) or totem (SP); nil = no pool for him now.
-- Also the pool in whole numbers (cur, max); none for the mode change's recharge
function B.Rate(hdl, attr)
  if attr == CHANGE then
    local rate = ChangeRate(hdl)
    return rate, rate ~= nil and "change" or nil
  end
  if attr == ATTR_MIXIMAX then
    local ok, has, cur, max, _, on = pcall(funcLuaCommand, CMD_PE, hdl or 0)
    if not ok or has ~= true or on ~= 1 or type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then
      return nil
    end
    return math.max(0, math.min(1, cur / max)), "pe", math.max(0, math.floor(cur + 0.5)), math.floor(max + 0.5)
  end
  if bit32.band(attr or 0, ATTR_KESHIN + ATTR_ARMOUR + ATTR_TOTEM) == 0 then
    return nil
  end
  -- only the pool of the aura running now (source 1): an entry whose aura has no pool (awakening, bond
  -- transformation, ...) keeps the stopwatch, never his last / move-slot keshin's pool
  local ok, has, cur, max, active, _, _, source, soul = pcall(funcLuaCommand, CMD_PEG, hdl or 0)
  if not ok or has ~= true or type(cur) ~= "number" or type(max) ~= "number" or max <= 0 or active ~= 1 or source ~= 1 then
    return nil
  end
  return math.max(0, math.min(1, cur / max)), soul == 1 and "sp" or "peg", math.max(0, math.floor(cur + 0.5)), math.floor(max + 0.5)
end

-- the number under bar k: hide its glyph slots
function B.HideNumber(k)
  local D = B.digits
  D.text[k] = nil
  for slot = 0, K.SLOTS - 1 do
    local inst = k * K.SLOTS + slot
    if D.shown[inst] then
      D.shown[inst] = false
      if Menu(CMND_IS_OPEN, K.DIGIT_LAYER, inst) == true then
        Menu(CMND_VISIBLE, K.DIGIT_LAYER, inst, false)
      end
    end
  end
end

function B.Hide(k)
  B.shown[k] = false
  B.rates[k] = nil
  if Menu(CMND_IS_OPEN, LAYER, k) == true then
    Menu(CMND_VISIBLE, LAYER, k, false)
  end
  B.HideNumber(k)
end

-- the glyph sequence of «cur / max»: digits as numbers 0..9, the slash as "/" (each value at most 3 digits)
local function Glyphs(cur, max)
  local out = {}
  for d in string.format("%d", math.min(999, cur)):gmatch("%d") do
    out[#out + 1] = tonumber(d)
  end
  out[#out + 1] = "/"
  for d in string.format("%d", math.min(999, max)):gmatch("%d") do
    out[#out + 1] = tonumber(d)
  end
  return out
end

-- the number «cur / max» centred at (cx, cy) (the layer's local position space, layout units; the row's scale `scale`) on
-- the bar instance k. false = its glyph layers are still loading
function B.DrawNumber(k, cur, max, cx, cy, scale)
  local D = B.digits
  local glyphs = Glyphs(cur, max)
  -- the slots of this bar open and set up before anything is shown
  local waiting = false
  for slot = 0, #glyphs - 1 do
    local inst = k * K.SLOTS + slot
    if Menu(CMND_IS_OPEN, K.DIGIT_LAYER, inst) ~= true then
      Menu(CMND_OPEN, K.DIGIT_LAYER, inst)
      D.opened[inst] = true
      D.ready[inst], D.glyph[inst], D.pos[inst], D.shown[inst] = nil, nil, nil, false
      Menu(CMND_VISIBLE, K.DIGIT_LAYER, inst, false)
      waiting = true
    elseif Menu(CMND_IS_LOADING, K.DIGIT_LAYER, inst) == true then
      waiting = true
    end
  end
  if waiting then
    return false
  end
  local width = 0
  for _, g in ipairs(glyphs) do
    width = width + (g == "/" and B.SLASH_ADV or (g == 1 and B.ONE_ADV or B.NUM_ADV))
  end
  local w, h = B.NUM_W * scale, B.NUM_H * scale
  local sx, sy = w / FRAME_W, h / FRAME_H
  local x = cx - width * scale / 2
  for i, g in ipairs(glyphs) do
    local inst = k * K.SLOTS + i - 1
    local adv = (g == "/" and B.SLASH_ADV or (g == 1 and B.ONE_ADV or B.NUM_ADV)) * scale
    if not D.ready[inst] then
      D.ready[inst] = true
      D.glyph[inst] = nil
      -- the gauge's frame only
      Menu(CMND_MESH_VISIBLE, K.DIGIT_LAYER, MESH_LABEL, false, inst)
      Menu(CMND_MESH_VISIBLE, K.DIGIT_LAYER, MESH_EMPTY, false, inst)
      Menu(CMND_MESH_VISIBLE, K.DIGIT_LAYER, K.MESH_FILL, false, inst)
    end
    if D.glyph[inst] ~= g then
      D.glyph[inst] = g
      Menu(CMND_SWAP_TEX, K.DIGIT_LAYER, ATLAS, g == "/" and K.GLYPH_SLASH or K.ATLAS_GLYPHS[g], K.FRAME_SPRITE, 0, inst)
    end
    -- the cell is centred on its advance
    local px = x + adv / 2 - FRAME_CX * sx
    local py = cy - FRAME_CY * sy
    local old = D.pos[inst]
    if old == nil or math.abs(old[1] - px) > 0.01 or math.abs(old[2] - py) > 0.01 or math.abs(old[3] - sx) > 1e-6 then
      D.pos[inst] = {px, py, sx}
      Menu(CMND_SET_SCALE, K.DIGIT_LAYER, sx, sy, 1, inst)
      Menu(CMND_SET_POS, K.DIGIT_LAYER, px, py, 0, inst)
    end
    if not D.shown[inst] then
      D.shown[inst] = true
      Menu(CMND_VISIBLE, K.DIGIT_LAYER, inst, true)
    end
    x = x + adv
  end
  -- the slots a shorter number no longer needs
  for slot = #glyphs, K.SLOTS - 1 do
    local inst = k * K.SLOTS + slot
    if D.shown[inst] then
      D.shown[inst] = false
      Menu(CMND_VISIBLE, K.DIGIT_LAYER, inst, false)
    end
  end
  return true
end

function B.Draw(e)
  if Menu(CMND_IS_VISIBLE, PORTRAIT, e.face) ~= true then
    B.Hide(e.k)
    return false
  end
  local rate, soul, cur, max = B.Rate(e.hdl, e.attr)
  if rate == nil then
    B.Hide(e.k)
    return false
  end
  if Menu(CMND_IS_OPEN, LAYER, e.k) ~= true then
    Menu(CMND_OPEN, LAYER, e.k)
    B.opened[e.k] = true
    B.ready[e.k] = nil
    B.shown[e.k] = false
    B.rates[e.k] = nil
    return false
  end
  if Menu(CMND_IS_LOADING, LAYER, e.k) == true then
    return false
  end
  if B.owners[e.k] ~= e.hdl then
    B.owners[e.k] = e.hdl
    B.ready[e.k] = nil
  end
  if not B.ready[e.k] then
    B.ready[e.k] = true
    B.fill[e.k] = nil
    B.rates[e.k] = nil
    Menu(CMND_RATE_INIT, LAYER, RATE_BAR, 0, e.k)
    Menu(CMND_RATE_INIT, LAYER, RATE_RED, 0, e.k)
    Menu(CMND_MESH_VISIBLE, LAYER, MESH_LABEL, false, e.k)
    Menu(CMND_MESH_VISIBLE, LAYER, MESH_EMPTY, false, e.k)
  end
  if B.fill[e.k] ~= soul then
    B.fill[e.k] = soul
    Menu(CMND_SWAP_TEX, LAYER, ATLAS, soul == "pe" and FILL_SLOT or (soul == "change" and FILL_CHANGE or (soul == "sp" and FILL_SP or FILL_PEG)), FILL_SLOT, 0, e.k)
  end
  -- the entry's stopwatch off, the bar on its place
  Menu(CMND_VISIBLE, GAUGE, e.face, false)
  -- the bar hangs on the portrait's locator (attach rows copied by buff_bar.toml): the portrait's own local position
  local gx, gy = Menu(CMND_LOCAL_POS, PORTRAIT, e.face)
  if type(gx) ~= "number" or type(gy) ~= "number" then
    gx, gy = 0, 0
  end
  -- Better UI (clean_hud) draws the row's icons at 0.85
  local flags = rawget(_ENV, "EVT_UI_FLAGS")
  local scale = (rawget(_ENV, "EVT_UI_PRESET") ~= "off" and type(flags) == "table" and flags.buff_icons == true) and 0.85 or 1
  local sx, sy = B.BAR_W * scale / FRAME_W, B.BAR_H * scale / FRAME_H
  local block = (e.track or 0) * B.PITCH                      -- the entry's second bar + number block lies lower
  local bar_half = 28 * B.BAR_H / FRAME_H / 2                  -- half the bar's visible height
  local bar_y = gy - (36 + 2 + bar_half + block) * scale
  gy = bar_y
  local px = gx + B.DX - FRAME_CX * sx
  local py = gy + B.DY - FRAME_CY * sy
  Menu(CMND_SET_SCALE, LAYER, sx, sy, 1, e.k)
  Menu(CMND_SET_POS, LAYER, px, py, 0, e.k)
  if not B.shown[e.k] then
    Menu(CMND_VISIBLE, LAYER, e.k, true)
    B.shown[e.k] = true
    B.rates[e.k] = nil
  end
  -- the rate animation only when the value changed (restarting it every frame leaves a new bar empty)
  if B.rates[e.k] == nil or math.abs(B.rates[e.k] - rate) > 0.0005 then
    B.rates[e.k] = rate
    Menu(CMND_RATE, LAYER, RATE_BAR, 0, rate, e.k, true)
    Menu(CMND_RATE, LAYER, RATE_RED, 0, rate, e.k, true)
  end
  -- the pool as «cur / max» under the bar (none for the mode change's recharge)
  if cur ~= nil and max ~= nil then
    local ny = bar_y - (bar_half + B.NUM_GAP + B.NUM_H / 2) * scale
    B.DrawNumber(e.k, cur, max, gx + B.DX, ny, scale)
  else
    B.HideNumber(e.k)
  end
  if B.LOGS < 6 then
    B.LOGS = B.LOGS + 1
    Log("entry", e.k, "hdl", string.format("0x%X", e.hdl), "attr", e.attr, soul, string.format("%.2f", rate), "portrait", tostring(gx), tostring(gy), "bar", px, py)
  end
  return true
end

-- ---- the totem's level on the tile's top edge ------------------------------------------------------------------

local function Command(...)
  local r = table.pack(pcall(funcLuaCommand, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

-- the text node's offset from the layer position (position units at scale 1), measured once on instance 0 as the
-- level-up pop of Souls Rework does: global = origin + unit * position + scale * node. nil = still measuring / unknown
function B.LevelNode()
  local L = B.lvl
  if L.node ~= nil then
    return L.node ~= false and L.node or nil
  end
  if Menu(CMND_IS_OPEN, K.LEVEL_LAYER, 0) ~= true then
    Menu(CMND_OPEN, K.LEVEL_LAYER, 0)
    L.opened[0] = true
    L.probe = nil
    return nil
  end
  if Menu(CMND_IS_LOADING, K.LEVEL_LAYER, 0) == true then
    return nil
  end
  local p = L.probe
  if p == nil then
    L.probe = {stage = 0, wait = 2, tries = (L.tries or 0) + 1}
    L.tries = L.probe.tries
    Menu(CMND_VISIBLE, K.LEVEL_LAYER, 0, false)
    Menu(CMND_SET_SCALE, K.LEVEL_LAYER, 1, 1, 1, 0)
    Menu(CMND_SET_POS, K.LEVEL_LAYER, 0, 0, 0, 0)
    return nil
  end
  if p.wait > 0 then
    p.wait = p.wait - 1
    return nil
  end
  local x, y = Menu(K.CMND_GLOBAL_POS, K.LEVEL_LAYER, 0, K.LEVEL_TEXT)
  if type(x) ~= "number" or type(y) ~= "number" then
    L.node = false
    Log("level label: no global position for its text node: off")
    return nil
  end
  local step = 100
  -- stage 0: the node at rest (two readings a few frames apart agree), so its open animation is over
  if p.stage == 0 then
    if p.rx ~= nil and math.abs(p.rx - x) < 0.5 and math.abs(p.ry - y) < 0.5 then
      p.stage = 1
    else
      p.rx, p.ry, p.wait = x, y, 2
      return nil
    end
  end
  if p.stage == 1 then
    p.x1, p.y1, p.stage, p.wait = x, y, 2, 2
    Menu(CMND_SET_POS, K.LEVEL_LAYER, step, step, 0, 0)
    return nil
  end
  if p.stage == 2 then
    p.x2, p.y2, p.stage, p.wait = x, y, 3, 2
    Menu(CMND_SET_POS, K.LEVEL_LAYER, 0, 0, 0, 0)
    Menu(CMND_SET_SCALE, K.LEVEL_LAYER, 2, 2, 1, 0)
    return nil
  end
  local ux, uy = (p.x2 - p.x1) / step, (p.y2 - p.y1) / step
  Menu(CMND_SET_SCALE, K.LEVEL_LAYER, 1, 1, 1, 0)
  local skew = math.abs(math.abs(ux) - math.abs(uy)) / math.max(math.abs(ux), math.abs(uy), 0.01)
  if skew > 0.02 and L.tries < K.PROBE_TRIES then
    Log("level label: probe", L.tries, string.format("units differ (%.3f %.3f): measuring again", ux, uy))
    L.probe = nil
    return nil
  end
  if math.abs(ux) < 0.01 or math.abs(uy) < 0.01 then
    L.node = false
    Log("level label: its position does not move its text node: off")
    return nil
  end
  L.node = {x = (x - p.x1) / ux, y = (y - p.y1) / uy}
  Log("level label: text node offset", string.format("%.1f %.1f", L.node.x, L.node.y), "units",
    string.format("%.3f %.3f", ux, uy), "probe", L.tries)
  return L.node
end

function B.HideLevel(k)
  local L = B.lvl
  L.shown[k] = false
  L.text[k] = nil
  if Menu(CMND_IS_OPEN, K.LEVEL_LAYER, k) == true then
    Menu(CMND_VISIBLE, K.LEVEL_LAYER, k, false)
  end
end

-- the label «Lv.3» on the top edge of the totem tile of entry e; false = nothing to show (or still loading)
function B.DrawLevel(e)
  local L = B.lvl
  if Menu(CMND_IS_VISIBLE, PORTRAIT, e.face) ~= true then
    B.HideLevel(e.face)
    return false
  end
  local has, level, text = Command(K.CMD_LEVEL, e.hdl or 0)
  if has ~= true or type(level) ~= "number" or type(text) ~= "string" or text == "" then
    B.HideLevel(e.face)
    return false
  end
  local node = B.LevelNode()
  if node == nil then
    return false
  end
  local k = e.face
  if Menu(CMND_IS_OPEN, K.LEVEL_LAYER, k) ~= true then
    Menu(CMND_OPEN, K.LEVEL_LAYER, k)
    L.opened[k] = true
    L.ready[k], L.shown[k], L.text[k], L.pos[k] = nil, false, nil, nil
    Menu(CMND_VISIBLE, K.LEVEL_LAYER, k, false)
    return false
  end
  if Menu(CMND_IS_LOADING, K.LEVEL_LAYER, k) == true then
    return false
  end
  if not L.ready[k] then
    L.ready[k] = true
    Menu(CMND_VISIBLE, K.LEVEL_LAYER, k, false)
    Menu(CMND_MESH_VISIBLE, K.LEVEL_LAYER, K.LEVEL_QUAD, false, k)
  end
  if L.text[k] ~= text then
    L.text[k] = text
    Menu(K.CMND_SET_TEXT, K.LEVEL_LAYER, K.LEVEL_TEXT, text, k)
  end
  local gx, gy = Menu(CMND_LOCAL_POS, PORTRAIT, k)
  if type(gx) ~= "number" or type(gy) ~= "number" then
    gx, gy = 0, 0
  end
  local flags = rawget(_ENV, "EVT_UI_FLAGS")
  local scale = (rawget(_ENV, "EVT_UI_PRESET") ~= "off" and type(flags) == "table" and flags.buff_icons == true) and 0.85 or 1
  local ts = B.LEVEL_SCALE * scale
  local w, h = K.LEVEL_TEXT_W * ts, K.LEVEL_TEXT_H * ts
  local cx, cy = gx, gy + (36 - B.LEVEL_DY) * scale
  local px, py = cx - w / 2 - ts * node.x, cy + h / 2 - ts * node.y
  local old = L.pos[k]
  if old == nil or math.abs(old[1] - px) > 0.01 or math.abs(old[2] - py) > 0.01 or math.abs(old[3] - ts) > 1e-6 then
    L.pos[k] = {px, py, ts}
    L.logged[k] = nil
    Menu(CMND_SET_SCALE, K.LEVEL_LAYER, ts, ts, 1, k)
    Menu(CMND_SET_POS, K.LEVEL_LAYER, px, py, 0, k)
  end
  if not L.shown[k] then
    L.shown[k] = true
    Menu(CMND_VISIBLE, K.LEVEL_LAYER, k, true)
  elseif not L.logged[k] then
    -- the frame after a placement: the owner, the instance and the real global x of his portrait and of the label
    L.logged[k] = true
    local portrait_x = Menu(K.CMND_LAYER_GLOBAL_POS, PORTRAIT, k)
    local text_x = Menu(K.CMND_GLOBAL_POS, K.LEVEL_LAYER, k, K.LEVEL_TEXT)
    Log("level label", text, "hdl", string.format("0x%X", e.hdl or 0), "instance", k, "portrait local x", tostring(gx),
      "portrait global x", tostring(portrait_x), "label local x", string.format("%.1f", px), "text node global x",
      tostring(text_x))
  end
  return true
end

-- every frame: the totem entries' level labels; the others' hidden
function B.LevelFrame()
  local L = B.lvl
  local used = {}
  for _, e in ipairs(B.entries) do
    if e.attr == ATTR_TOTEM and B.DrawLevel(e) then
      used[e.face] = true
    end
  end
  for k, on in pairs(L.shown) do
    if on and not used[k] then
      B.HideLevel(k)
    end
  end
  -- an opened instance no totem entry drew this frame stays hidden even when the layer showed itself again
  for k in pairs(L.opened) do
    if not used[k] and k ~= 0 and Menu(CMND_IS_VISIBLE, K.LEVEL_LAYER, k) == true then
      B.HideLevel(k)
    elseif not used[k] and k == 0 and L.node ~= nil and Menu(CMND_IS_VISIBLE, K.LEVEL_LAYER, 0) == true then
      B.HideLevel(0)
    end
  end
end

-- every frame: the bars follow the live portraits (cut-ins / a hidden row hide them)
function B.Frame()
  if not B.ON or not PoolsOn() then
    return
  end
  if IfDraws() then
    if not B.yielded then
      B.yielded = true
      for k, on in pairs(B.shown) do
        if on then
          B.Hide(k)
        end
      end
      Log("Inazuma Fantasy's mx_popup draws the bars in this script: nothing drawn here")
    end
    return
  end
  local used = {}
  for _, e in ipairs(B.entries) do
    if B.Draw(e) then
      used[e.k] = true
    end
  end
  for k, on in pairs(B.shown) do
    if on and not used[k] then
      B.Hide(k)
    end
  end
  -- an opened instance no entry drew this frame stays hidden even when the layer showed itself again
  for k in pairs(B.opened) do
    if not used[k] and Menu(CMND_IS_VISIBLE, LAYER, k) == true then
      B.Hide(k)
    end
  end
  -- the glyph slots of the bars no entry drew
  for inst in pairs(B.digits.opened) do
    local k = math.floor(inst / K.SLOTS)
    if not used[k] and Menu(CMND_IS_VISIBLE, K.DIGIT_LAYER, inst) == true then
      B.HideNumber(k)
      Menu(CMND_VISIBLE, K.DIGIT_LAYER, inst, false)
    end
  end
  B.LevelFrame()
end

if B.origUpdate == nil and type(UpdateAuraBuffCharaIcon) == "function" then
  B.origUpdate = UpdateAuraBuffCharaIcon
  function UpdateAuraBuffCharaIcon(...)
    local r = table.pack(B.origUpdate(...))
    if B.ON then
      local ok, ents = pcall(B.Collect)
      B.entries = ok and ents or {}
      pcall(B.Frame)
    end
    return table.unpack(r, 1, r.n)
  end
end
if B.origStep == nil and type(Step) == "function" then
  B.origStep = Step
  function Step(...)
    local r = table.pack(B.origStep(...))
    pcall(B.Frame)
    return table.unpack(r, 1, r.n)
  end
end
