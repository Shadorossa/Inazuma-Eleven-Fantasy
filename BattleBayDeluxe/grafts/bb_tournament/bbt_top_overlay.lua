-- BattleBayDeluxe bb_tournament, top menu part: the overlay: layers, pages, plates, keys, the group stage's menu.
-- Appended after bbt_top.lua in graft.toml's order: the parts share one chunk and its locals.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}

-- ------------------------------------------------------------------------------------------------ the overlay

-- 1.5.22 (owner log 18:32 on «Modos de juego»: every bracket layer open0=false vis0=false): CMND_OPEN_LAYER does
-- not open them there. On a host with vis_only (the hub: its layers are opened with the menu's group, hidden at
-- setup by bbt_hub.lua) «open» / «close» = visible / invisible.
local function bbt_open_layer(l, i)
  if BattleBayDeluxe.TournamentHost.vis_only then
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, l, i, true)
    return
  end
  funcLuaMenuCommand(@crc:CMND_OPEN_LAYER@, l, i)
end
local function bbt_close_layer(l, i)
  if BattleBayDeluxe.TournamentHost.vis_only then
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, l, i, false)
    return
  end
  funcLuaMenuCommand(@crc:CMND_CLOSE_LAYER@, l, i)
end

-- every instance of the overlay's own layers (name in BattleBayDeluxe.Tournament.L / BattleBayDeluxe.Tournament.N)
function BBT_EachInstance(f)
  for k, n in pairs(BattleBayDeluxe.Tournament.N) do
    for i = 0, n - 1 do
      f(BattleBayDeluxe.Tournament.L[k], i)
    end
  end
end

function BBT_Hide(layer, i)
  local C = BattleBayDeluxe.Tournament.C
  funcLuaMenuCommand(C.VISIBLE, layer, i, false)
  funcLuaMenuCommand(C.POS, layer, -4000, 4000, 0, i)
end

-- the pieces drawn by one BBT_Draw: { [layer] = next free instance }; the rest hidden at the end
function BBT_Begin()
  BattleBayDeluxe.TournamentState.used = {}
  for _, l in pairs(BattleBayDeluxe.Tournament.L) do
    BattleBayDeluxe.TournamentState.used[l] = 0
  end
  BattleBayDeluxe.TournamentState.taken = {}
end

function BBT_Take(layer, fixed)
  local i = fixed
  if i == nil then
    i = BattleBayDeluxe.TournamentState.used[layer]
    while BattleBayDeluxe.TournamentState.taken[tostring(layer) .. ":" .. i] do
      i = i + 1
    end
    BattleBayDeluxe.TournamentState.used[layer] = i + 1
  end
  BattleBayDeluxe.TournamentState.taken[tostring(layer) .. ":" .. i] = true
  return i
end

function BBT_End()
  BBT_EachInstance(function(l, i)
    if not BattleBayDeluxe.TournamentState.taken[tostring(l) .. ":" .. i] then
      BBT_Hide(l, i)
    end
  end)
end

-- a tinted quad of the mod's drawings: centre (x, y), w x h px; prio = the draw priority of a connector-pool
-- instance (1.5.58: a score box on a host without a box pool, BattleBayDeluxe.Tournament.SHARE; nil = the connectors' own); atlas = another
-- loaded atlas than the mod's drawings (crc32 of its path; the final stadium's thumbnail)
function BBT_Quad(layer, spr, x, y, w, h, col, prio, atlas)
  local C, G = BattleBayDeluxe.Tournament.C, BattleBayDeluxe.Tournament.G
  local nk = "icon"
  for k, l in pairs(BattleBayDeluxe.Tournament.L) do
    if l == layer and BattleBayDeluxe.Tournament.N[k] then
      nk = k
    end
  end
  -- 1.5.58: a pool shared with another one (BattleBayDeluxe.Tournament.SHARE) on the menu that has none of its own
  local to = BattleBayDeluxe.Tournament.N[nk] <= 0 and BattleBayDeluxe.Tournament.SHARE[nk] or nil
  if to ~= nil and BattleBayDeluxe.Tournament.L[to] ~= nil and BattleBayDeluxe.Tournament.N[to] then
    layer, nk, prio = BattleBayDeluxe.Tournament.L[to], to, prio or BattleBayDeluxe.Tournament.PRIO[nk]
  end
  local i = BBT_Take(layer)
  if i >= BattleBayDeluxe.Tournament.N[nk] then
    return
  end
  -- the connector and box pools carry quads at several depths: each instance's priority set when it changes
  if layer == BattleBayDeluxe.Tournament.L.line or layer == BattleBayDeluxe.Tournament.L.box then
    local want = prio or BattleBayDeluxe.Tournament.PRIO[nk] or BattleBayDeluxe.Tournament.PRIO.line
    local key = tostring(layer) .. ":" .. i
    BattleBayDeluxe.TournamentState.prio = BattleBayDeluxe.TournamentState.prio or {}
    if BattleBayDeluxe.TournamentState.prio[key] ~= want then
      BattleBayDeluxe.TournamentState.prio[key] = want
      funcLuaMenuCommand(@crc:CMND_SET_DRAW_PRIORITY@, layer, i, want, true)
    end
  end
  funcLuaMenuCommand(C.VISIBLE, layer, i, true)
  funcLuaMenuCommand(C.SCALE, layer, w / G.Q, h / G.Q, 1, i)
  funcLuaMenuCommand(C.SPRITE, layer, atlas or BattleBayDeluxe.Tournament.ART, spr, BattleBayDeluxe.Tournament.NODE_QUAD, 0, i)
  funcLuaMenuCommand(C.POS, layer, x, -y, 0, i)
  funcLuaMenuCommand(C.PRIM_COLOR, layer, i, BattleBayDeluxe.Tournament.MESH_QUAD, col[1], col[2], col[3])
  return i
end

-- a team plate: p = { team, me, out }, (x, y) = its left edge / vertical centre, scale s; right = the mirrored plate;
-- champ = the champion's look; fixed = the instance to use (the champion's)
function BBT_Plate(p, x, y, s, right, champ, fixed)
  local C, L = BattleBayDeluxe.Tournament.C, BattleBayDeluxe.Tournament.L
  local l = right and L.row_r or L.row_l
  local i = BBT_Take(l, fixed)
  if i >= BattleBayDeluxe.Tournament.N[right and "row_r" or "row_l"] then
    return
  end
  local look = champ and "ok" or (p.me and "on" or "off")
  -- 1.8.0: a team plate (and the player's: his focus band marks him) is the team's strip with the name in white
  local strip = not champ and BattleBayDeluxe.Tournament.SPR_STRIP[tonumber(p.strip) or 0] or nil
  if strip then
    look = "off"
  end
  BBT_PlateStrip(l, i, look == "off" and strip or nil)
  local white = look ~= "off" or strip ~= nil
  funcLuaMenuCommand(C.VISIBLE, l, i, true)
  funcLuaMenuCommand(C.SCALE, l, s, s, 1, i)
  funcLuaMenuCommand(C.POS, l, x, -y, 0, i)
  for k, m in pairs(BattleBayDeluxe.Tournament.PLATE) do
    funcLuaMenuCommand(C.MESH_VISIBLE, l, m, k == look, i)
  end
  local name = VRFW_Team.Name(p.team)
  funcLuaMenuCommand(C.TEXT, l, BattleBayDeluxe.Tournament.TXT_ON, white and name or "", i)
  funcLuaMenuCommand(C.TEXT, l, BattleBayDeluxe.Tournament.TXT_OFF, white and "" or name, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, l, BattleBayDeluxe.Tournament.TXT_ON, white, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, l, BattleBayDeluxe.Tournament.TXT_OFF, not white, i)
  local c = (p.out and not champ) and BattleBayDeluxe.Tournament.G.DIM or 1
  funcLuaMenuCommand(C.PRIM_COLOR, l, i, BattleBayDeluxe.Tournament.PLATE[look], c, c, c)
  funcLuaMenuCommand(C.PRIM_COLOR, l, i, BattleBayDeluxe.Tournament.MESH_EMBLEM, c, c, c)
  -- 1.5.37: the tint did not show in game; a team that is out is drawn faded (the retail locked-dock alpha)
  BBT_Alpha(l, i, (p.out and not champ) and BattleBayDeluxe.Tournament.ADV.OUT_ALPHA or 1)
  VRFW_Team.Emblem(l, i, p.team, BattleBayDeluxe.TournamentState.emb)
end

-- 1.8.0: the plate's own sprite (list_base_xs01_off) swapped for a team strip of the mod's atlas, or back to the
-- list plate (spr nil); once per instance and sprite while the overlay is open (BattleBayDeluxe.TournamentState.strip, reset at every opening)
function BBT_PlateStrip(l, i, spr)
  BattleBayDeluxe.TournamentState.strip = BattleBayDeluxe.TournamentState.strip or {}
  local k = tostring(l) .. ":" .. i
  local want = spr or false
  if BattleBayDeluxe.TournamentState.strip[k] == want then
    return
  end
  BattleBayDeluxe.TournamentState.strip[k] = want
  if spr then
    pcall(funcLuaMenuCommand, BattleBayDeluxe.Tournament.C.SPRITE, l, BattleBayDeluxe.Tournament.ART, spr, BattleBayDeluxe.Tournament.PLATE_SPRITE, 0, i)
  else
    pcall(funcLuaMenuCommand, BattleBayDeluxe.Tournament.C.SPRITE, l, BattleBayDeluxe.Tournament.PLATE_ATLAS, BattleBayDeluxe.Tournament.PLATE_SPRITE, BattleBayDeluxe.Tournament.PLATE_SPRITE, 0, i)
  end
end

-- 1.8.0: the player's focus band behind his plate (left edge x, centre y, scale s), on the box pool
-- 1.42.0: the frame is one sprite, the strip's slanted outline (bbd_tn_frame_l / _r of bbd_bracket_art.py: the strip
-- 392 x 72 grown by 8 px on every side), so it follows the plate's slant on either side
BattleBayDeluxe.Tournament.SPR_FRAME = { l = @crc:bbd_tn_frame_l@, r = @crc:bbd_tn_frame_r@ }
BattleBayDeluxe.Tournament.FRAME_GROW = { w = 408 / 392, h = 88 / 72 }
function BBT_Focus(x, y, s, right)
  local G = BattleBayDeluxe.Tournament.G
  -- 1.39.0 (owner): the player's plate gets a GOLD frame instead of the band
  local w, h = G.PLATE_W * s, G.PLATE_H * s
  -- 1.50.0: the mirrored (right side) plate keeps the same slant as the left one: the left frame on both sides
  BBT_Quad(BattleBayDeluxe.Tournament.L.box, BattleBayDeluxe.Tournament.SPR_FRAME.l, x + w / 2, y, w * BattleBayDeluxe.Tournament.FRAME_GROW.w,
    h * BattleBayDeluxe.Tournament.FRAME_GROW.h, BattleBayDeluxe.Tournament.WHITE, G.PRIO_BACK)
end

-- an instance's model + name alpha (CMND_SET_LAYER_MODEL_ALPHA / CMND_SET_MENU_TEXT_ALPHA, as the retail
-- soccer_team_dock_menu UpdateViewMenuByLock); reset to 1 on every plate / crest drawn (instances are reused)
function BBT_Alpha(l, i, a)
  pcall(funcLuaMenuCommand, @crc:CMND_SET_LAYER_MODEL_ALPHA@, l, i, 0, a)
  pcall(funcLuaMenuCommand, @crc:CMND_SET_MENU_TEXT_ALPHA@, l, i, BattleBayDeluxe.Tournament.TXT_ON, a)
  pcall(funcLuaMenuCommand, @crc:CMND_SET_MENU_TEXT_ALPHA@, l, i, BattleBayDeluxe.Tournament.TXT_OFF, a)
end

-- 1.9.0: crc32 of a digit sprite's name, kept (the same few names every draw)
function BBT_SprCrc(name)
  BattleBayDeluxe.TournamentState.spr_crc = BattleBayDeluxe.TournamentState.spr_crc or {}
  local c = BattleBayDeluxe.TournamentState.spr_crc[name]
  if c == nil then
    c = BBT_Crc(name)
    BattleBayDeluxe.TournamentState.spr_crc[name] = c
  end
  return c
end

-- a row of digit sprites centred on (x, y): parts = { { sprite name, height }, ... }; prio = the quads' draw
-- priority (default BattleBayDeluxe.Tournament.NUM.PRIO, in front of the connectors); returns its width
function BBT_Glyphs(parts, x, y, prio)
  local N = BattleBayDeluxe.Tournament.NUM
  local total, ws = 0, {}
  for k, p in ipairs(parts) do
    ws[k] = N.W * p[2] / N.H
    total = total + ws[k] * (k < #parts and N.ADV or 1)
  end
  local cx = x - total / 2
  for k, p in ipairs(parts) do
    BBT_Quad(BattleBayDeluxe.Tournament.L.line, BBT_SprCrc(p[1]), cx + ws[k] / 2, y, ws[k], p[2], BattleBayDeluxe.Tournament.WHITE, prio or N.PRIO, BattleBayDeluxe.Tournament.ART_NUM)
    cx = cx + ws[k] * N.ADV
  end
  return total
end

-- the parts of number n (style gold / blue / white) at height h appended to parts; wrap = in brackets
function BBT_NumParts(parts, n, style, h, wrap)
  if wrap then
    parts[#parts + 1] = { "bbd_tn_d_lp", h }
  end
  for c in tostring(math.max(0, math.floor(tonumber(n) or 0))):gmatch("%d") do
    parts[#parts + 1] = { "bbd_tn_d_" .. style .. "_" .. c, h }
  end
  if wrap then
    parts[#parts + 1] = { "bbd_tn_d_rp", h }
  end
  return parts
end

-- a match's score, the upper entrant's goals first: «2-1», «1-1 (4-3)» (the shoot-out in brackets; the results page
-- names extra time and penalties)
function BBT_Score(sc)
  if not sc then
    return ""
  end
  local s = string.format("%d-%d", sc.ga or 0, sc.gb or 0)
  if (sc.pa or 0) + (sc.pb or 0) > 0 then
    s = s .. string.format(" (%d-%d)", sc.pa or 0, sc.pb or 0)
  end
  return s
end

-- the knockout tree (every round in one view, the retail art for 16 teams, the advance) is drawn by the framework's
-- bracket screen vrfw_bracket_menu (VRFW assets\lua\screens\vrfw_bracket_menu.lua), opened over this host by
-- VRFW_Bracket (BBT_TreeShow); the plates of a team that is out fade the same way (ADV.OUT_ALPHA)
BattleBayDeluxe.Tournament.ADV = { OUT_ALPHA = 0.45 }

-- a text with <VALUE> and <VALUE2> filled (the retail text value command, once per tag)
function BBT_TextValue2(key, a, b)
  local t = BBT_Text(key)
  local ok, r = pcall(funcLuaCommand, 910683996, t, "VALUE", a or 0, 0, 0, true)
  t = ok and r or t
  local ok2, r2 = pcall(funcLuaCommand, 910683996, t, "VALUE2", b or 0, 0, 0, true)
  return ok2 and r2 or t
end
