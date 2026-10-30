-- vrfw_contact_map_menu, part 3 of 7 (graft contact_map appends it to vrfw_contact_map_menu.lua; one chunk):
-- the team pages of a map ([VRFW.ContactMap.Teams], functions of CmPages).
-- ---- team pages ([VRFW.ContactMap.Teams]): the pitch, the price per player, «signed once», «!», trials, «Dimitir»
-- (functions of the global CmPages: the main chunk is at its 200 locals)
CmPages.PITCH = {X0 = 120, X1 = 960, Y0 = 190, Y1 = 960, BENCH_X = 1110, BENCH_Y0 = 200, BENCH_DY = 84, PLATE = 96,
                 MAX = 30, GHOST = {0.55, 0.57, 0.62}, GHOST_ALPHA = 0.45}
-- the team dock's lineup layers (content/menus/contact_map.toml): the pitch lines, the formation frame, the cards
CmPages.FORM = {BASE = 3518110933 --[[mainmenu04_10_formation_base]], FRAME = 3321884270 --[[soccer11_02_formation_frame]],
                CARD = 1973487846 --[[team00_01_chara_card_for_soccer]], LEADER = 1658289671 --[[..._for_leader]],
                BLANK = 3571911991 --[[team00_01_p1_chara_card_blank]], BLANK_L = 2290394976 --[[..._blank_for_leader]],
                filled = nil, shown = false}
CmPages.FORM_LAYER = {[3518110933] = true, [3321884270] = true, [1973487846] = true, [1658289671] = true,
                      [3571911991] = true, [2290394976] = true}
CmPages.CARD = {HW = 104, HH = 80,      -- half the size of a lineup card on the screen (the hit box)
                -- the state border: the card's own focus frame mesh (_icon_chr_focus_l01, one plain texture on the
                -- card's outer edge) with the plain white frame as its sprite, tinted; the selected card gets the
                -- retail cyan sprite back (team00_01 icon_chr_focus_l01). The seasonal frame (a masked shimmer
                -- material: a sprite there stays blue) is kept off
                BORDER_MESH = 3345942320, BORDER_SLOT = 1739145470 --[[icon_chr_focus_l01]],
                -- a small card (the bench, the managers: the team dock draws them small) has its own focus frame
                SMALL_MESH = 3491095421 --[[_icon_chr_focus_s01]], SMALL_SLOT = 1892918451 --[[icon_chr_focus_s01]],
                SMALL_HW = 68, SMALL_HH = 50,     -- half the size of a small card on the screen (the arrow, the hit box)
                FOCUS_TEX = 4225297828 --[[team00_01.g4tx]], SEASONAL_MESH = 960763094 --[[_seasonal_frame_l01]],
                ARROW_GAP = 6,                    -- the cursor arrow's tip this far left of the card's left edge
                NEW_TAG = 40}                     -- the «!» badges use the tag pool from this index (the borders below it)
-- the retail card selection (soccer_formation_menu_inc): the card's own «Focus» animation (its cyan frame) and the
-- cursor arrow (cmn05_01_cursor) at the card's left; cur = {layer, idx, priority} of the focused card
CmPages.FOCUS = {ANIM = 2734777837 --[[Focus]], TYPE = 973515837, PLAY = @crc:CMND_PLAY_ANIME_TYPE@,
                 cur = nil,
                 -- the leader card's number primitives' dummies (_num_chr_dmy_l01 / l02 / s01 / s02): never drawn here
                 NUMBERS = {1451641049, 3482261859, 1107078292, 3639999790}}
-- the frame's locators that bound the lineup (the cards hang on the frame): its top and bottom formation spots and
-- the lowest bench spot (team slots 16-18)
CmPages.FORM_SPAN = {TOP = 3984567298 --[[_pos_formation01_lu]], BOTTOM = 2278526192 --[[_pos_formation01_ld]],
                     BENCH = 2517135446 --[[_pos_support_atc02]]}

-- a locator of a lineup layer (layer-local, y up): x, y; nil when the layer does not have it
function CmPages.FormPose(layer, joint)
  local ok, x, y, _, found = pcall(funcLuaMenuCommand, @crc:CMND_GET_MESH_POSE@, layer, 0, joint)
  if ok and found ~= false and type(x) == "number" and type(y) == "number" then
    return x, y
  end
  return nil
end

-- the team dock hangs the pitch lines and the formation frame on a locator of its own layer, which this screen does
-- not have: they stood at the layout origin (the screen's top-left corner) with the cards attached to them. Both are
-- moved together so the lineup (from the frame's top spots to its lowest bench spot) is centred on the page's pitch
-- area (PITCH); the cards follow their attach and the formation spots stay frame-relative, as in the team dock.
function CmPages.PlaceFormLayers()
  local F, P, S, H = CmPages.FORM, CmPages.PITCH, CmPages.FORM_SPAN, CmPages.CARD.HH
  local _, top = CmPages.FormPose(F.FRAME, S.TOP)
  local _, bottom = CmPages.FormPose(F.FRAME, S.BOTTOM)
  local _, bench = CmPages.FormPose(F.FRAME, S.BENCH)
  if top == nil or bottom == nil then
    Log("lineup place: no formation spots on the frame")
    return false
  end
  local low = (bench ~= nil and bench < bottom) and bench or bottom
  local mid = ((top + H) + (low - H)) / 2                  -- the lineup's centre, layer-local (y up)
  local tx, ty = (P.X0 + P.X1) / 2, -((P.Y0 + P.Y1) / 2)    -- the pitch area's centre, global (y up)
  for _, l in ipairs({F.BASE, F.FRAME}) do
    local ok, gx, gy = pcall(funcLuaMenuCommand, 4002164178 --[[the instance's global position]], l, 0)
    gx = (ok and type(gx) == "number") and gx or 0
    gy = (ok and type(gy) == "number") and gy or 0
    pcall(funcLuaMenuCommand, C.POS, l, tx - gx, ty - mid - gy, 0, 0)
  end
  Log("lineup placed at", tostring(tx), tostring(ty - mid), "span", tostring(top), tostring(low))
  return true
end

-- a lineup layer's setup, as the free-match list does it for the same layers (soccer_formation_menu_inc)
function CmPages.SetupFormLayer(a1, a2)
  local F = CmPages.FORM
  if a1 == F.FRAME and type(SetFormationLayer) == "function" then
    pcall(SetFormationLayer, a1)
    -- the team banner shows no team level («Nv.» and its digits)
    local HR = type(VRFW_UI) == "table" and VRFW_UI.HeaderRow or nil
    if HR ~= nil then
      pcall(HR.LevelOff, a1, a2)
      pcall(funcLuaMenuCommand, C.NODE_VISIBLE, a1, HR.LEVEL_GROUP, false, a2 or 0)
    end
  elseif a1 == F.CARD or a1 == F.LEADER then
    pcall(funcLuaMenuCommand, 4233535095, a1, a2, false)
    pcall(funcLuaMenuCommand, 2628464193, a1, a2, 550)
    -- no seasonal shimmer frame; the focus frame mesh is the state border, shown by DrawPitch
    pcall(funcLuaMenuCommand, C.MESH_VISIBLE, a1, CmPages.CARD.SEASONAL_MESH, false, a2)
    pcall(funcLuaMenuCommand, C.MESH_VISIBLE, a1, CmPages.CARD.BORDER_MESH, false, a2)
    pcall(funcLuaMenuCommand, C.MESH_VISIBLE, a1, CmPages.CARD.SMALL_MESH, false, a2)
    if a1 == F.LEADER then
      for _, m in ipairs(CmPages.FOCUS.NUMBERS) do
        pcall(funcLuaMenuCommand, C.MESH_VISIBLE, a1, m, false, a2)
      end
    end
  end
  if type(OnSetupLayerFormationCommon) == "function" then
    pcall(OnSetupLayerFormationCommon, a1, a2)
  end
end

function CmPages.FormCount(layer)
  local ok, n = pcall(funcLuaMenuCommand, C.LAYER_NUM or @crc:CMND_GET_CREATE_LAYER_NUM@, layer)
  return (ok and type(n) == "number") and n or 0
end

-- the lineup layers are opened with the screen's own (a layer is drawn only once opened), hidden until a team page
function CmPages.OpenFormLayers()
  local F = CmPages.FORM
  local n = 0
  for _, l in ipairs({F.BASE, F.FRAME, F.BLANK, F.BLANK_L, F.CARD, F.LEADER}) do
    for i = 0, CmPages.FormCount(l) - 1 do
      pcall(funcLuaMenuCommand, C.OPEN_LAYER, l, i)
      pcall(funcLuaMenuCommand, C.LAYER_VISIBLE, l, i, false)
      n = n + 1
    end
  end
  F.shown, F.filled, F.opened = false, nil, n > 0
  Log("lineup layers opened", n)
  if n > 0 then
    CmPages.PlaceFormLayers()
  end
end

function CmPages.HideLineup()
  local F = CmPages.FORM
  CmPages.Unfocus()
  if not F.shown then
    return
  end
  F.shown = false
  for _, l in ipairs({F.BASE, F.FRAME, F.CARD, F.LEADER, F.BLANK, F.BLANK_L}) do
    for i = 0, CmPages.FormCount(l) - 1 do
      pcall(funcLuaMenuCommand, C.LAYER_VISIBLE, l, i, false)
    end
  end
end

-- the page's team on the game's lineup: the cards filled as the free-match list fills its preview (the team's
-- formation, kit, members by slot; each card by its chara_param, the level he joins at here); false = no lineup layers
function CmPages.Lineup(z)
  local F = CmPages.FORM
  if type(UpdateMemberCharaIconInfoByChrParamId) ~= "function" or type(UpdateMainMemberIcomFormationPos) ~= "function" then
    return false
  end
  local ncard = CmPages.FormCount(F.CARD)
  local zz = MAP and MAP.zones[z]
  local team = zz and Int(zz.team) or 0
  if ncard == 0 or team == 0 then
    return false
  end
  if not F.opened then
    CmPages.OpenFormLayers()           -- not opened with the screen (set up after its first layers): now
  end
  if F.filled ~= team then
    F.filled = team
    local lv, sold = {}, {}
    for _, n in ipairs(MAP.nodes) do
      if n.zone == z and Int(n.level or 0) > 0 then
        lv[Int(n.card)] = Int(n.level)
      end
      if n.zone == z and n.kind == "player" then
        sold[Int(n.card)] = true
      end
    end
    -- no blank «empty slot» boxes: a team page shows only the team's members
    for i = 0, ncard - 1 do
      pcall(funcLuaMenuCommand, C.LAYER_VISIBLE, F.BLANK, i, false)
      pcall(funcLuaMenuCommand, C.LAYER_VISIBLE, F.CARD, i, false)
    end
    local _, form = funcLuaCommand(2151743654, team, 3)
    pcall(UpdateMainMemberIcomFormationPos, form or 0, true)
    local _, uni = funcLuaCommand(2151743654, team, 4)
    local kit = funcLuaMenuCommand(1187793486, uni or 0)
    local okc, cnt = funcLuaCommand(2151743654, team, 8)
    if type(SetDisableForceCharaInvalidUseTarget) == "function" then
      pcall(SetDisableForceCharaInvalidUseTarget)
    end
    F.coach = false
    for m = 0, ((okc and type(cnt) == "number") and cnt or 0) - 1 do
      local okp, param = funcLuaCommand(34355761, team, m, 0)
      local oks, slot = funcLuaCommand(34355761, team, m, 7)
      if okp and oks and slot == 19 and CmPages.FormCount(F.LEADER) > 0
          and type(UpdateLeaderCharaByCharaParamId) == "function" then
        -- the coach: the team dock's leader card (bottom left of the frame), as the team screens fill it
        pcall(UpdateLeaderCharaByCharaParamId, param, F.LEADER, 0, lv[Int(param)] or 1)
        for _, mesh in ipairs(CmPages.FOCUS.NUMBERS) do
          pcall(funcLuaMenuCommand, C.MESH_VISIBLE, F.LEADER, mesh, false, 0)
        end
        pcall(funcLuaMenuCommand, @crc:CMND_SET_LAYER_MODEL_ALPHA@, F.LEADER, 0, 0,
          sold[Int(param)] and 1 or CmPages.PITCH.GHOST_ALPHA)
        F.coach = true
      elseif okp and oks and type(slot) == "number" and slot < 19 and slot < ncard then
        local _, num = funcLuaCommand(34355761, team, m, 9)
        pcall(UpdateMemberCharaIconInfoByChrParamId, param, slot, form, kit, lv[Int(param)] or 1, num, uni, 4)
        pcall(funcLuaMenuCommand, C.LAYER_VISIBLE, F.CARD, slot, true)
        -- a member sold on another page (or not at all) stays on the lineup, translucent
        pcall(funcLuaMenuCommand, @crc:CMND_SET_LAYER_MODEL_ALPHA@, F.CARD, slot, 0,
          sold[Int(param)] and 1 or CmPages.PITCH.GHOST_ALPHA)
      end
    end
    if type(SetEnableForceCharaInvalidUseTarget) == "function" then
      pcall(SetEnableForceCharaInvalidUseTarget)
    end
    local x0, y0 = CmPages.CardAt(0)
    Log("lineup", team, "formation " .. tostring(form) .. " members " .. tostring(cnt) .. " cards " .. tostring(ncard)
      .. " card 0 at " .. tostring(x0) .. ", " .. tostring(y0))
  end
  if not F.shown then
    F.shown = true
    pcall(funcLuaMenuCommand, C.LAYER_VISIBLE, F.BASE, 0, true)
    pcall(funcLuaMenuCommand, C.LAYER_VISIBLE, F.FRAME, 0, true)
  end
  -- the leader card only for a team with a coach (no empty leader box)
  for _, l in ipairs({F.LEADER, F.BLANK_L}) do
    for i = 0, CmPages.FormCount(l) - 1 do
      pcall(funcLuaMenuCommand, C.LAYER_VISIBLE, l, i, l == F.LEADER and i == 0 and F.coach == true)
    end
  end
  return true
end

-- the screen place of the lineup card of slot (the layer instance's position, y down); nil when it cannot be read
function CmPages.CardAt(slot)
  local layer, idx = CmPages.CardOf(slot)
  local ok, gx, gy = pcall(funcLuaMenuCommand, 4002164178 --[[the instance's position]], layer, idx)
  -- a card that is not placed (no position yet: 0, 0) is not used: the framework's plate stands there instead
  if ok and type(gx) == "number" and type(gy) == "number" and (math.abs(gx) > 1 or math.abs(gy) > 1) then
    return gx, -gy
  end
  return nil
end
CmPages.seen = {}
CmPages.seen_key = nil

-- the card of team slot `slot`: slots 0-18 the card layer's instance of that slot, the coach (slot 19) the leader card
function CmPages.CardOf(slot)
  if slot == 19 then
    return CmPages.FORM.LEADER, 0
  end
  return CmPages.FORM.CARD, slot
end

-- a lineup card's state border (role card_border_signed / _ready / _unmet: its colour; nil = none): the card's own
-- frame mesh on its outer edge, its sprite the plain white frame, tinted; false while the plain atlas loads
-- whether a lineup card is drawn large (the team dock's rule, IsCharaCardBigtype of soccer_formation_menu_inc; else the
-- starters and the coach large, the bench and the managers small)
function CmPages.IsBigCard(layer, idx)
  if type(IsCharaCardBigtype) == "function" then
    local ok, big = pcall(IsCharaCardBigtype, idx, layer)
    if ok and type(big) == "boolean" then
      return big
    end
  end
  return layer == CmPages.FORM.LEADER or idx <= 10
end

function CmPages.CardBorder(layer, idx, role, focused)
  local B = CmPages.CARD
  local big = CmPages.IsBigCard(layer, idx)
  local mesh, slot = big and B.BORDER_MESH or B.SMALL_MESH, big and B.BORDER_SLOT or B.SMALL_SLOT
  pcall(funcLuaMenuCommand, C.MESH_VISIBLE, layer, B.SEASONAL_MESH, false, idx)
  pcall(funcLuaMenuCommand, C.MESH_VISIBLE, layer, big and B.SMALL_MESH or B.BORDER_MESH, false, idx)
  if focused then                   -- the selected card: the retail cyan frame, its own colours
    pcall(funcLuaMenuCommand, C.SPRITE, layer, B.FOCUS_TEX, slot, slot, 0, idx)
    pcall(funcLuaMenuCommand, C.PRIM_COLOR, layer, idx, mesh, 1, 1, 1)
    pcall(funcLuaMenuCommand, C.MESH_VISIBLE, layer, mesh, true, idx)
    return true
  end
  local f = role ~= nil and FALLBACK[role] or nil
  local tc = f ~= nil and Tex(VRFW_ScreenArt.PLAIN) or nil
  if not tc then
    pcall(funcLuaMenuCommand, C.MESH_VISIBLE, layer, mesh, false, idx)
    return tc
  end
  local _, sc = VRFW_ScreenArt.Plain(f[1])
  pcall(funcLuaMenuCommand, C.SPRITE, layer, tc, sc, slot, 0, idx)
  pcall(funcLuaMenuCommand, C.PRIM_COLOR, layer, idx, mesh, f[2][1], f[2][2], f[2][3])
  pcall(funcLuaMenuCommand, C.MESH_VISIBLE, layer, mesh, true, idx)
  return true
end

-- the retail selection on a lineup card: its focus frame in and the cursor arrow at its left, vertically centred (x, y:
-- the card's centre on screen); the previous card's frame out; nil = no card focused (the frame out, the arrow off)
function CmPages.FocusCard(layer, idx, x, y, hw)
  local Fo = CmPages.FOCUS
  local cur = Fo.cur
  if cur ~= nil and (cur[1] ~= layer or cur[2] ~= idx) then
    -- the card left keeps its frame mesh (DrawPitch draws it as that card's state border): no «out» animation
    pcall(funcLuaMenuCommand, @crc:CMND_SET_DRAW_PRIORITY@ --[[draw priority]], cur[1], cur[2], cur[3], true)
    Fo.cur = nil
  end
  if layer == nil then
    if cur ~= nil then
      funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, false)
    end
    return
  end
  if Fo.cur == nil then
    local okp, prio = pcall(funcLuaMenuCommand, @crc:CMND_GET_DRAW_PRIORITY@ --[[the instance's draw priority]], layer, idx)
    Fo.cur = {layer, idx, (okp and type(prio) == "number") and prio or 652}
    -- no «Focus» animation: it keeps the retail white frame on every card the cursor has left; the frame is the sprite and colour CardBorder sets
    pcall(funcLuaMenuCommand, @crc:CMND_SET_DRAW_PRIORITY@ --[[draw priority]], layer, idx, Fo.cur[3] + 30, true)
  end
  -- the arrow: placed on the screen as the list rows place it (no attach: the input anchor re-attaches the cursor)
  funcLuaMenuCommand(C.POS, L_CURSOR, x - (hw or CmPages.CARD.HW) - CmPages.CARD.ARROW_GAP, -y, 0, 0)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, true)
end

function CmPages.Unfocus()
  CmPages.FocusCard(nil)
end

-- the price of a node: its spirit (the classic «fichas») or the set's item
function CmPages.PriceOf(n)
  if n ~= nil and (n.spirit or 0) ~= 0 then
    return {spirit = n.spirit, count = n.price or 0}
  end
  return {item = SET and SET.rc or 0, count = n and n.price or 0}
end

-- one price spirit's name (the set's ElementCurrencyUnit), else the currency's name
function CmPages.PayUnit(n)
  if n ~= nil and (n.pay_unit or 0) ~= 0 then
    local t = Text(n.pay_unit)
    if t ~= "" then
      return t
    end
  end
  return CmPages.PayName(n)
end

-- the width in px of `s` on a text instance at scale 1: the game's measure (CMND_GET_MENU_TEXT_RECT_SIZE, as the
-- retail SetupLockIconPos), else a per-character estimate
function CmPages.TextWidth(layer, idx, s)
  local ok, w = pcall(funcLuaMenuCommand, @crc:CMND_GET_MENU_TEXT_RECT_SIZE@, layer, idx, TEXT_ON, s)
  if ok and type(w) == "number" and w > 0 then
    return w
  end
  local n = 0
  for _ in string.gmatch(s or "", "[^\128-\191]") do
    n = n + 1
  end
  return n * INFO.CHAR_W
end

function CmPages.PayName(n)
  if n ~= nil and (n.pay_title or 0) ~= 0 then
    local t = Text(n.pay_title)       -- the set's name of that element's spirit (ElementCurrencyTitle)
    if t ~= "" then
      return t
    end
  end
  if n ~= nil and (n.spirit or 0) ~= 0 and (n.pay_name or "") ~= "" then
    return n.pay_name
  end
  return CmPages.CurrencyName()
end

-- a trial's line: «Prueba k/n: …» by the objective (kind * 100000 + seconds * 100 + count)
function CmPages.TrialText(r)
  local obj = r.objective or 0
  local kind = math.floor(obj / 100000)
  local secs = math.floor((obj % 100000) / 100)
  local count = obj % 100
  local id = T.TRIAL[kind] or T.TRIAL[1]
  if kind == 1 then
    return Fmt(id, r.part or 1, r.of or 1, secs)
  elseif kind == 2 then
    return Fmt(id, r.part or 1, r.of or 1, count, secs)
  end
  return Fmt(id, r.part or 1, r.of or 1, count)
end

-- «signed once»: a card recorded on this map keeps only the page's own unlock (a match against his team won); his
-- players / items / levels / trials are never asked again
function CmPages.WaiveSigned()
  if MAP == nil or not MAP.pitch then
    return
  end
  for i, n in ipairs(MAP.nodes) do
    if signed[i] == true and n.all_reqs == nil then
      n.all_reqs = n.reqs
      local keep = {}
      for _, r in ipairs(n.reqs or {}) do
        if r.kind == "cleared" or r.kind == "unlock" then
          keep[#keep + 1] = r
        end
      end
      n.reqs = keep
    end
  end
end

-- «!»: the players who can be signed and were not looked at yet (per save and map: key contact.seen.<map>)
function CmPages.LoadSeen()
  CmPages.seen = {}
  CmPages.seen_key = nil
  if MAP == nil or not MAP.pitch then
    return
  end
  CmPages.seen_key = "contact.seen." .. MAP.key
  local v = Call(C.SAVE_GET, OWNER, CmPages.seen_key, "")
  for x in string.gmatch(type(v) == "string" and v or "", "%d+") do
    CmPages.seen[tonumber(x)] = true
  end
end

function CmPages.MarkSeen(n)
  if CmPages.seen_key == nil or n == nil or CmPages.seen[Int(n.card)] then
    return
  end
  CmPages.seen[Int(n.card)] = true
  local t = {}
  for c in pairs(CmPages.seen) do
    t[#t + 1] = c
  end
  table.sort(t)
  Call(C.SAVE_SET, OWNER, CmPages.seen_key, table.concat(t, ","), 1)
end

-- a team page's members: its players, then its ghosts (the starters sold on another page)
function CmPages.Members(z)
  local out = {}
  for _, kind in ipairs({"player", "ghost"}) do
    for i, n in ipairs(MAP.nodes) do
      if n.kind == kind and n.zone == z then
        out[#out + 1] = i
      end
    end
  end
  return out
end

-- where member g stands: a starter at his place on the pitch, the others down the bench column
function CmPages.Spot(g)
  local P = CmPages.PITCH
  local n = MAP.nodes[members[g]]
  if (n.px or -1) >= 0 and (n.py or -1) >= 0 then
    return P.X0 + n.px * (P.X1 - P.X0), P.Y0 + n.py * (P.Y1 - P.Y0)
  end
  local k = 0
  for h = 1, g - 1 do
    local m = MAP.nodes[members[h]]
    if not ((m.px or -1) >= 0 and (m.py or -1) >= 0) then
      k = k + 1
    end
  end
  return P.BENCH_X, P.BENCH_Y0 + k * P.BENCH_DY
end

function CmPages.DrawPitch()
  local P = CmPages.PITCH
  local cards = CmPages.Lineup(zone)
  CmPages.at = {}
  for g, i in ipairs(members) do
    local k = g - 1
    if k >= P.MAX then
      break
    end
    local n = MAP.nodes[i]
    local x, y = CmPages.Spot(g)
    local size = (n.px or -1) >= 0 and P.PLATE or P.PLATE * 0.8
    local cx, cy = nil, nil
    if cards and n.main and Int(n.slot or 99) <= 19 then
      cx, cy = CmPages.CardAt(Int(n.slot))
    end
    if cx ~= nil then
      -- the game's card at its lineup place: the state border, the «!» badge and the hit box are the screen's; the
      -- selection is the card's own (CmPages.FocusCard)
      CmPages.at[g] = {cx, cy}
      local B = CmPages.CARD
      local hw, hh = B.HW, B.HH
      local layer, idx = CmPages.CardOf(Int(n.slot))
      if not CmPages.IsBigCard(layer, idx) then
        hw, hh = B.SMALL_HW, B.SMALL_HH
      end
      pcall(funcLuaMenuCommand, @crc:CMND_SET_LAYER_MODEL_ALPHA@, layer, idx, 0,
        n.kind == "ghost" and P.GHOST_ALPHA or 1)
      Hide(L_TILE, k)
      Hide(L_FACE, k)
      Hide(L_TILE, 100 + k)
      pos[g] = {x = cx, y = cy, hw = hw, hh = hh, layer = layer, idx = idx}
      Hide(L_TAG, k)
      if n.kind == "ghost" then
        CmPages.CardBorder(layer, idx, nil, g == focus.grid)
        Hide(L_TAG, B.NEW_TAG + k)
      else
        -- the border by state: in the club (green), signable now (blue), requirements / price not met (red); the
        -- selected card shows the retail cyan selection instead
        local st = State(i)
        local role = st == "done" and "card_border_signed" or (st == "ready" and "card_border_ready" or "card_border_unmet")
        if CmPages.CardBorder(layer, idx, role, g == focus.grid) == false then
          tex_wait = true                 -- the plain atlas is loading: Step redraws
        end
        local bs = 44
        if st == "ready" and not CmPages.seen[Int(n.card)] and B.NEW_TAG + k < N.TAG then
          Quad(L_TAG, B.NEW_TAG + k, "badge_new", cx - hw + bs * 0.4, cy - hh + bs * 0.4, bs, bs)
          pcall(funcLuaMenuCommand, @crc:CMND_SET_DRAW_PRIORITY@ --[[draw priority]], L_TAG, B.NEW_TAG + k, 801, true)
        else
          Hide(L_TAG, B.NEW_TAG + k)
        end
        if g == focus.grid and st == "ready" then
          CmPages.MarkSeen(n)
        end
      end
    elseif n.kind == "ghost" then
      Plate(k, "locked", x, y, size)
      DrawFace(L_FACE, k, n, x, y, size * NET.FACE_IN)
      pcall(Tint, L_FACE, k, P.GHOST)
      Hide(L_TAG, k)
      pos[g] = {x = x, y = y, hw = size / 2, hh = size / 2}
    else
      local st = State(i)
      local bs = size * GRID.CHECK
      local bx, by = x + size / 2 - bs * 0.45, y + size / 2 - bs * 0.45
      Plate(k, st, x, y, size)
      DrawFace(L_FACE, k, n, x, y, size * NET.FACE_IN)
      -- (no lineup cards: the framework's plate) the game's element icon on its top-right corner
      local e = Int(n.element or 0)
      local tc = ELEM_ICON[e] ~= nil and Tex(COMMON_TEX) or nil
      if tc then
        local es = size * 0.34
        QuadTex(L_TILE, 100 + k, tc, CRC32(ELEM_ICON[e]), x + size / 2 - es * 0.45, y - size / 2 + es * 0.45, es, es)
      else
        Hide(L_TILE, 100 + k)
      end
      if st == "done" then
        Quad(L_TAG, k, "icon_check", bx, by, bs, bs)
      elseif st == "ready" and not CmPages.seen[Int(n.card)] then
        Quad(L_TAG, k, "badge_new", x - size / 2 + bs * 0.45, y - size / 2 + bs * 0.45, bs, bs)
      elseif ReqsUnmet(n) then
        Quad(L_TAG, k, "badge_unmet", bx, by, size * GRID.REQNG, size * GRID.REQNG)
      else
        Hide(L_TAG, k)
      end
      pos[g] = {x = x, y = y, hw = size / 2, hh = size / 2}
      if g == focus.grid and st == "ready" then
        CmPages.MarkSeen(n)
      end
    end
  end
  local p = pos[focus.grid]
  if p ~= nil and p.layer ~= nil then
    CmPages.FocusCard(p.layer, p.idx, p.x, p.y, p.hw)
  else
    CmPages.Unfocus()
  end
  if CmPages.Guide ~= nil then
    CmPages.Guide()
  end
end

-- the D-pad on the pitch: the nearest player in that direction (a ghost too: his card says where he is signed)
-- where member g stands now: his card's place (the lineup), else the framework's spot
function CmPages.Where(g)
  local a = CmPages.at and CmPages.at[g]
  if a ~= nil then
    return a[1], a[2]
  end
  return CmPages.Spot(g)
end

function CmPages.PitchMove(dx, dy)
  local cx, cy = CmPages.Where(focus.grid)
  local best, bd = nil, nil
  for g, i in ipairs(members) do
    if g ~= focus.grid and g <= CmPages.PITCH.MAX then
      local x, y = CmPages.Where(g)
      local ax, ay = x - cx, y - cy
      local along = ax * dx + ay * dy
      if along > 4 then
        local side = math.abs(ax * dy) + math.abs(ay * dx)
        local d = along + side * 2.5
        if bd == nil or d < bd then
          best, bd = g, d
        end
      end
    end
  end
  return best
end

function CmPages.Focused()
  if MAP == nil or not MAP.pitch or mode ~= "grid" then
    return nil
  end
  local i = members[focus.grid]
  local n = i and MAP.nodes[i] or nil
  if n == nil or n.kind ~= "player" then
    return nil
  end
  return n, i
end

-- the focused player's first trial not passed yet (a requirement, or an optional trial when the set asks none)
function CmPages.OpenTrial(n)
  for _, list in ipairs({n and n.reqs or {}, n and n.trials or {}}) do
    for _, r in ipairs(list) do
      if r.kind == "trial" and VRFW_Recruit.Have(r) < 1 then
        return r
      end
    end
  end
  return nil
end

-- the button guide's extra entries: {text, icon, key}
function CmPages.GuideExtra()
  local out = {}
  local n, i = CmPages.Focused()
  if n == nil then
    return out
  end
  if CmPages.OpenTrial(n) ~= nil then
    out[#out + 1] = {T.TRIAL_BTN, 2735202045 --[[<CMD_FUNC3>]], 3421673595 --[[CMD_FUNC3]]}
  end
  if IsSigned(i) then
    out[#out + 1] = {T.RELEASE_BTN, 950905002 --[[<CMD_FUNC4>]], 1435897304 --[[CMD_FUNC4]]}
  end
  return out
end

-- Y: the focused player's trial: a friendly against his rival page's team, started from the hub under this screen
-- (VRFW_RecruitTrial in the hub's VM: the match start service), then this screen closes
function CmPages.Trial()
  local n = CmPages.Focused()
  local r = CmPages.OpenTrial(n)
  if r == nil then
    return
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  if not Ask(Fmt(T.TRIAL_ASK, CmPages.TrialText(r))) then
    return
  end
  local ok, started = pcall(funcLuaCommand, C.MENU_CALL, HUB.menu or 0, "VRFW_RecruitTrial", r.friendly, r.game,
    r.difficulty or 1, r.tag or 0, r.sub or 0, r.objective or 0, r.friendly_team or "")
  Log("trial", tostring(r.friendly), r.game, r.tag, r.sub, tostring(ok), tostring(started))
  if not ok or started == false then
    funcLuaCommand(C.SE, SE_NG)
    Message(Text(T.TRIAL_FAIL))
    return
  end
  CmPages.Leave(0)
end

-- X: «Dimitir» the focused player (the bank's own retire); the set's refund of his price's spirit given back
function CmPages.Release()
  local n, i = CmPages.Focused()
  if n == nil or not IsSigned(i) then
    return
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  if not Ask(Fmt(T.RELEASE_Q, n.name)) then
    return
  end
  local refund = nil
  if (n.spirit or 0) ~= 0 and (SET.refund or 0) > 0 then
    refund = {spirit = n.spirit, count = SET.refund}
  end
  local ok, why = VRFW_Recruit.Release(n.cards or {n.card}, refund)
  Log("release", MAP.key, i, n.card, tostring(ok), tostring(why))
  CmPages.own = {}
  if not ok then
    funcLuaCommand(C.SE, SE_NG)
    Message(Text(why == "busy" and T.RELEASE_BUSY or T.RELEASE_FAIL))
    return
  end
  funcLuaCommand(C.SE, SE_OK)
  CmPages.Recruited()
  Message(Fmt(T.RELEASE_DONE, n.name))
end
