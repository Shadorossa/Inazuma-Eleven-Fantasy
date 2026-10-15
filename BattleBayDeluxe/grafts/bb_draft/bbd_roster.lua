-- bb_chronicle_teams bb_draft, the «Plantilla» viewer of the Campaña grid (enjoy_team_select_menu_campaign; Battle Bay
-- Deluxe 1.5.73, owner 2026-10-15; docs/game/modes/estadio-bb.md §14.18). Runs after bbd_campaign.lua in the same
-- script and reuses the Draft's layers and helpers (BBCR_DRAFT_*). Laid out like the match's «Formación» screen:
--   * Y on a tile of the grid (the grid layer's retail CMD_FUNC3 row, function 756653130: no retail handler in the
--     campaign script) replaces the picker on screen: every picker layer is hidden (crest grid, locks, the page /
--     category strip, the Campaña / Torneo selector, the team panel, its pitch, cards and tactics) and the in-match
--     formation screen's own objects are opened on the grid's menu (content\menus\bb_draft.toml): its background
--     (soccer11_01_formation_bg), its pitch frame with the bench and coach slots (soccer11_02_formation_frame) and its
--     formation bar (soccer11_12_formation_button, «team · formation»). The players on the Draft's cards
--     (evt_bb_draft_slot) at their formation placement (CMND_BBD_FORMATION_PLACE, scripts\draft.lua), the substitutes
--     in the bench column (empty bench places as grey cards), the coach (slot 19) as the retail coach card
--     («ENTRENADOR», evt_bb_draft_card 0) at the bottom left. The RIGHT half is the retail player page
--     (personal_plate_menu) of the focused player, opened once with the players-universe parameters (param id,
--     level, rarity) as the retail pack list does (chara_pack_probability_list_menu) and switched with 1101551215
--     (SetPersonalPlateCharaParam) whenever the cursor moves. The page keeps its own menu inactive in that mode, so
--     this screen keeps the input on the Draft's anchor (evt_bb_draft_anchor): arrows / a click move the cursor,
--     Q / E (LT / RT) turn the page's pages (567813453 / 2019940505 + 3297841487), Back / Y close. Read-only.
--   * The page's 3D model and the picker's own character (the team panel vs01_44_p1's model component) share the menu
--     camera: the team panel is closed while the viewer is up (1.5.73; hidden only, its model kept driving the camera
--     and the page's model stood far down) and opened again on the way out; the MenuCamera offset is kept at the
--     opening and put back after the page is gone (again 30 and 90 frames later: the model's release is late).
--     Log lines «roster layout probe» (the frame's nodes) and «roster model probe» (camera offset / position, the
--     page's model layer) once per opening.
--   * Layout (1.5.73, from the probed frame nodes): the frame's origin at FRAME_X / FRAME_Y puts its pitch, bench
--     places and coach place where the in-match screen has them; the cards use those places.
--   * Closing is ordered: the page is asked to close again until it is gone (a page still opening is waited for),
--     and only then the grid comes back (the retail OnCloseEndLayer of the difficulty window, then
--     BBCR_DRAFT_Refresh with the focus on the same tile and its panel redrawn). Y acts only after the key was
--     released (CMD_FUNC3 repeats while held). Nothing is accepted while the page opens or closes.
--   * The footer «<Y> Plantilla» (text evt_bbd_roster) after the grid's retail entries (Aceptar, Descripción), declared
--     to the VR-Framework's footer prompts (VRFW_FooterPrompts, attached to UpdateButtonGuide on this menu's guide
--     layer mainmenu01_06_base_button_guide_right; a click on it sends CMD_FUNC3); shown only while the focused tile
--     is a team Y opens (the guide is set again when the focus moves between such tiles and the others).
-- Refused (the retail NG sound): an empty tile, the Draft tile, a team without readable members, while a window,
-- the difficulty window, the Torneo's grid flow, a page turn or another player page is busy. Globals only
-- (BBD_ROSTER*); at chunk load only the footer prompt's declaration (pure Lua).
BBD_ROSTER = {
  FN_GRID_Y = 756653130 --[[the grid's CMD_FUNC3 function (enjoy_team_select_menu_setting)]],
  FN_Y = @crc:evt_bbd_roster_y@,
  FN_PAGE_PREV = @crc:evt_bbd_roster_page_prev@,
  FN_PAGE_NEXT = @crc:evt_bbd_roster_page_next@,
  PLACE = @crc:CMND_BBD_FORMATION_PLACE@,
  TXT_GUIDE = @crc:evt_bbd_roster@,
  TXT_HINT = @crc:evt_bbd_roster_hint@,
  I_FUNC3 = 3794706590 --[[<CMD_FUNC3>]],
  K_FUNC3 = 3421673595 --[[CMD_FUNC3]],
  GUIDE_LAYER = 618184632 --[[mainmenu01_06_base_button_guide_right: this menu's guide]],
  -- the in-match formation screen's objects (content\menus\bb_draft.toml)
  L_BG = @crc:evt_bbd_roster_bg@, L_FRAME = @crc:evt_bbd_roster_frame@, L_TITLE = @crc:evt_bbd_roster_title@,
  T_TITLE = 1158637427 --[[_text_formation_btn01]],
  M_TITLE_OFF = {@crc:_formation_focus01@, @crc:_dmy_formation_btn01@},
  PICKER_BG = 4036570440 --[[vs01_41_enjoy_team_select_background: the looks go just above it]],
  -- the picker's layers hidden while the viewer is up (put back as they were): besides BBCR_DRAFT's grid, locks,
  -- panel cards, tactics, team plate and pitch
  PICKER_HIDE = {2708277675 --[[vs01_45_p1_enjoy_team_select_teamInfo]], 2813867952 --[[vs01_44_..._backbelt]],
                 2785921709 --[[vs01_45_..._backbelt]], 3223710473 --[[vs01_48_..._explanation_plate]]},
  -- the menu camera of the character models
  CAM = 1752770328 --[[MenuCamera]], CAM_GET = 1877348924, CAM_SET = 284729675, CAM_AGAIN = {30, 90},
  CAM_POS = 2225733338 --[[named camera position]],
  -- the player page's model layer (Character Reforged's evt_pp_model on personal_plate_menu) for the log only
  MODEL_LAYER = 598577375, MODEL_NODE = 1517329426, MODEL_PROBE = 60,
  -- the player page and its players-universe parameters (personal_plate_menu OnInit)
  PLATE = 1427722143 --[[personal_plate_menu]],
  PLATE_PAGE = 878737202 --[[team11_01_personal_plate]],
  P_PARAM = 3928123478, P_LEVEL = 3894267099, P_RARITY = 571278276,
  PLATE_SET = 1101551215 --[[(param, level, rarity, false): the page's player]],
  PLATE_PAGE_PREV = 567813453, PLATE_PAGE_NEXT = 2019940505, PLATE_PAGE_UPDATE = 3297841487,
  CHARA_INFO = 4060384944 --[[CMND_GET_CHARA_INFO (param, 8) = chara_param rarity]],
  RARITY_DEFAULT = 4, RARITY_MAX = 7,
  FORM_INFO = 2649030357 --[[(7, formation) -> ok, name text id]], TEXT_OF = 297699480,
  CARD_CMD = 2339877830 --[[the retail card draw]],
  SUB_WINDOW = 2941513916 --[[sub_window_group]],
  CLICK = 218912913 --[[CMD_EVT_MOUSE_LEFT]],
  STAFF_SLOT = 19, MAX = 16,
  -- layout, screen px of the 1920 x 1080 menu camera (x from the left, y DOWN; positions are sent as (x, -y)).
  -- The frame (soccer11_02) is drawn around its layer origin; its node poses (1.5.71 «roster layout probe», origin at
  -- 0, 0, y up): pitch corners lu (-252, 278) / rd (346, -381), bench places sub1 (439, 259) .. sub5 (439, -141),
  -- coach place leader (-285, -393). With the origin at FRAME_X, FRAME_Y the pitch spans x 185..783, y 190..849 as
  -- on the in-match «Formación» screen; the bench places and the coach place follow from the same poses.
  FRAME_X = 437, FRAME_Y = 468, BG_X = 0, BG_Y = 0,
  NODE_LU = {-252, 278}, NODE_RD = {346, -381}, NODE_SUB1 = {439, 259}, NODE_SUB5 = {439, -141},
  NODE_LEADER = {-285, -393},
  -- the starters inside the pitch: the formation's own extent (its widest |x|, its first and last rows) mapped to
  -- PITCH_HALF_W around the pitch centre and PITCH_TOP_IN .. PITCH_BOTTOM_IN (px inside the pitch's top / bottom)
  PITCH_HALF_W = 255, PITCH_TOP_IN = 25, PITCH_BOTTOM_IN = 50, CARD_SCALE = 1.05,
  GRID_DX = 150, GRID_DY = 150, -- starters without a placement: rows of 4 over the pitch
  BENCH_PLACES = 5, BENCH_COL_DX = 120, BENCH_SCALE = 0.78,
  COACH_SCALE = 1.1,
  -- the formation bar (its text sits left of the layer origin: the bar ends ~259 px right of it)
  TITLE_X = 434, TITLE_Y = 113,
  PRIO_LOOK = 600, -- the looks' base priority without the picker background's (bg, frame, bar: +0, +1, +2)
  PRIO_CARDS = 712,
  PROBE_FRAMES = 20,
  -- the frame's nodes logged once per opening (the layout check in the log)
  PROBE_NODES = {@crc:_pos_formation01_lu@, @crc:_pos_formation01_rd@, @crc:_pos_sub_atc01@, @crc:_pos_sub_atc05@,
                 @crc:_atc_leader01@},
  -- half sizes on screen for the pointer (half of the card body at its scale)
  HALF_SMALL = {72, 53}, HALF_BENCH = {53, 39}, HALF_COACH = {85, 64},
  PLATE_WAIT = 180, -- frames the page may take to appear
  CLOSE_AGAIN = 30, CLOSE_MAX = 600, -- frames between close requests; frames before the grid comes back anyway
  SE_OPEN = 3848881948 --[[sy0000]], SE_MOVE = 2500047763 --[[sy0005]], SE_BACK = 202039849, SE_NG = 2086672038,
  -- state: nil | "opening" (the page appears) | "view" | "closing" (the page goes)
  state = nil, team = 0, tile = -1, formation = 0, members = {}, empties = {}, sel = 1, shown = nil, plate = nil,
  refresh = nil, back = nil, frame = 0, prev_click = false, guide_on = true, tile_ok = false, ylock = false,
  pending = nil, closing_at = 0, cam = nil, panel_closed = false, model_probe = nil, cam_again = nil, probe = nil, prio = nil, title = nil, opened = false,
}

function BBD_ROSTER_Log(...)
  pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "bb_chronicle_teams roster", ...)
end

local function ng()
  funcLuaCommand(1917805374, BBD_ROSTER.SE_NG)
end

local function param_set(k, v)
  if funcLuaCommand(2947612279 --[[param exists]], k) == true then
    funcLuaCommand(3363400568 --[[param delete]], k)
  end
  funcLuaCommand(3860611758 --[[param set]], k, 0, v, 1)
end

local function params_clear()
  local R = BBD_ROSTER
  for _, k in ipairs({R.P_PARAM, R.P_LEVEL, R.P_RARITY}) do
    if funcLuaCommand(2947612279 --[[param exists]], k) == true then
      funcLuaCommand(3363400568 --[[param delete]], k)
    end
  end
end

local function plate_exists()
  return funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT]], BBD_ROSTER.PLATE) == true
end

local function page_up()
  local R = BBD_ROSTER
  return funcLuaCommand(3693934564 --[[CMND_IS_OPEN_MENU_OBJECT]], R.PLATE, R.PLATE_PAGE) == true
end

local function closing(why)
  local R = BBD_ROSTER
  R.state = "closing"
  R.closing_at = R.frame
  BBD_ROSTER_Log("closing", why)
end

-- the team on a tile of the grid (the last SetupEmblemIcon of the slot, else the VR-Framework's page slot)
function BBD_ROSTER_TeamOf(tile)
  local B = BBCR_DRAFT
  if type(tile) ~= "number" or tile < 0 then
    return 0
  end
  local rec = B.slotArgs[tile]
  local team = rec and rec[1] or nil
  if team == nil then
    local t = funcLuaCommand(B.PAGE_SLOT, tile)
    team = type(t) == "number" and t or 0
  end
  return team
end

-- the focused tile is a team Y opens
function BBD_ROSTER_TileOk()
  local B = BBCR_DRAFT
  local tile = funcLuaMenuCommand(2603265800 --[[focus index]], B.GRID)
  local team = BBD_ROSTER_TeamOf(tile)
  return team ~= 0 and team ~= B.TEAM
end

-- the frame's node at its screen place (FRAME_X / FRAME_Y + the probed pose, y down)
local function node_at(n)
  local R = BBD_ROSTER
  return R.FRAME_X + n[1], R.FRAME_Y - n[2]
end

-- every member's card and place: starters by the formation placement inside the frame's pitch, substitutes on the
-- frame's bench places (sub1 .. sub5), a starter without a placement on a plain grid over the pitch, the coach on the
-- frame's coach place; the bench places left free get a grey card
local function layout()
  local B, R = BBCR_DRAFT, BBD_ROSTER
  local lx, ty = node_at(R.NODE_LU)
  local rx, by = node_at(R.NODE_RD)
  local cx = (lx + rx) / 2
  local top, bottom = ty + R.PITCH_TOP_IN, by - R.PITCH_BOTTOM_IN
  local sx1, sy1 = node_at(R.NODE_SUB1)
  local _, sy5 = node_at(R.NODE_SUB5)
  local sdy = (sy5 - sy1) / math.max(1, R.BENCH_PLACES - 1)
  local qx, qy = node_at(R.NODE_LEADER)
  -- the formation's placements of the starters and their extent
  local xmax, ymin, ymax = 1, nil, nil
  for _, m in ipairs(R.members) do
    if not m.coach and m.slot <= 10 and R.formation ~= 0 then
      local ok, _, x, y = funcLuaCommand(R.PLACE, R.formation, m.slot)
      if ok == true and type(x) == "number" and type(y) == "number" then
        m.fx, m.fy = x, y
        xmax = math.max(xmax, math.abs(x))
        ymin = (ymin == nil or y < ymin) and y or ymin
        ymax = (ymax == nil or y > ymax) and y or ymax
      end
    end
  end
  local yspan = (ymin ~= nil and ymax > ymin) and (ymax - ymin) or 1
  local bench, loose, slot_i = 0, 0, 0
  for _, m in ipairs(R.members) do
    if m.coach then
      m.layer, m.i, m.x, m.y, m.scale, m.half = B.CARD, 0, qx, qy, R.COACH_SCALE, R.HALF_COACH
    else
      m.layer, m.i, m.scale, m.half = B.SLOT, slot_i, R.CARD_SCALE, R.HALF_SMALL
      slot_i = slot_i + 1
      if m.fx ~= nil then
        m.x = cx + B.MIRROR * R.PITCH_HALF_W * m.fx / xmax
        m.y = top + (m.fy - ymin) / yspan * (bottom - top)
      elseif m.slot <= 10 then
        local col, row = loose % 4, math.floor(loose / 4)
        m.x, m.y = cx + (col - 1.5) * R.GRID_DX, top + row * R.GRID_DY
        loose = loose + 1
      else
        local col, row = math.floor(bench / R.BENCH_PLACES), bench % R.BENCH_PLACES
        m.x, m.y = sx1 + col * R.BENCH_COL_DX, sy1 + row * sdy
        m.scale, m.half = R.BENCH_SCALE, R.HALF_BENCH
        bench = bench + 1
      end
    end
  end
  R.empties = {}
  while bench < R.BENCH_PLACES and slot_i < R.MAX do
    R.empties[#R.empties + 1] = {i = slot_i, x = sx1, y = sy1 + bench * sdy}
    slot_i, bench = slot_i + 1, bench + 1
  end
end

-- the team's members in slot order (players: slot < 19, at most MAX; the coach: slot 19); false without a player
function BBD_ROSTER_Load(team)
  local B, R = BBCR_DRAFT, BBD_ROSTER
  local okn, count = funcLuaCommand(2151743654 --[[team info]], team, 8)
  if okn ~= true or type(count) ~= "number" then
    count = 24
  end
  local okf, fm = funcLuaCommand(2151743654 --[[team info]], team, 3)
  R.formation = (okf == true and type(fm) == "number") and fm or 0
  local players, coach = {}, nil
  for i = 0, count - 1 do
    local ok, has, param, slot, level = pcall(GetTeamMemberInfo, team, i)
    if ok and has == true and type(param) == "number" and param ~= 0 and type(slot) == "number"
        and slot <= R.STAFF_SLOT then
      local okr, okc, rar = pcall(funcLuaCommand, R.CHARA_INFO, param, 8)
      if not (okr and okc == true and type(rar) == "number" and rar >= 0 and rar <= R.RARITY_MAX) then
        rar = R.RARITY_DEFAULT
      end
      local m = {param = param, slot = slot, rar = rar,
                 level = (type(level) == "number" and level > 0) and level or B.LEVEL}
      if slot == R.STAFF_SLOT then
        m.coach = true
        coach = coach or m
      else
        players[#players + 1] = m
      end
    end
  end
  table.sort(players, function(a, b)
    return a.slot < b.slot
  end)
  while #players > R.MAX do
    table.remove(players)
  end
  local any = #players > 0
  if coach ~= nil then
    players[#players + 1] = coach
  end
  R.members = players
  layout()
  return any
end

-- the member drawn on (layer, i), nil = none
local function member_on(layer, i)
  for _, m in ipairs(BBD_ROSTER.members) do
    if m.layer == layer and m.i == i then
      return m
    end
  end
  return nil
end

local function empty_on(layer, i)
  if layer ~= BBCR_DRAFT.SLOT then
    return nil
  end
  for _, e in ipairs(BBD_ROSTER.empties) do
    if e.i == i then
      return e
    end
  end
  return nil
end

local function place(layer, i, x, y, scale)
  funcLuaMenuCommand(1491630496 --[[CMND_SET_DRAW_PRIORITY]], layer, i, BBD_ROSTER.PRIO_CARDS, true)
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], layer, x, -y, 0, i)
  funcLuaMenuCommand(3362798188, layer, i, scale, scale)
end

-- the coach as the retail coach card (the large card with the «ENTRENADOR» tab, as the Chronicle's rival formation
-- draws slot 19)
local function coach_card(layer, i, m)
  local B, R = BBCR_DRAFT, BBD_ROSTER
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, i, true)
  for _, mesh in ipairs(B.M_DEF) do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, mesh, false, i)
  end
  for k = 1, #B.M_FACE, 2 do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, B.M_FACE[k], true, i)
  end
  funcLuaMenuCommand(R.CARD_CMD, layer, i, m.param, true, true, 0, 0, m.level, false, false, 4, 0)
  for _, mesh in ipairs(B.M_TAG) do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, mesh, false, i)
  end
  BBCR_DRAFT_CardMeshes(layer, i)
end

-- one card instance: its member, a free bench place, or hidden
function BBD_ROSTER_DrawCard(layer, i)
  local B, R = BBCR_DRAFT, BBD_ROSTER
  if not B.ready[layer .. ":" .. i] then
    return
  end
  local live = R.state ~= nil and R.state ~= "closing"
  local m = live and member_on(layer, i) or nil
  local e = (live and m == nil) and empty_on(layer, i) or nil
  if m ~= nil then
    if m.coach then
      coach_card(layer, i, m)
    else
      BBCR_DRAFT_Filled_Card(layer, i, m.param)
    end
    place(layer, i, m.x, m.y, m.scale)
  elseif e ~= nil then
    BBCR_DRAFT_Empty_Card(layer, i, 0, true)
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, B.M_DEF[BBCR_DRAFT_Sz(layer)], false, i)
    place(layer, i, e.x, e.y, R.BENCH_SCALE)
  else
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, i, false)
  end
end

local function each_instance(fn)
  local B = BBCR_DRAFT
  for _, layer in ipairs({B.SLOT, B.CARD}) do
    local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM]], layer)
    if type(n) ~= "number" or n <= 0 then
      n = layer == B.SLOT and BBD_ROSTER.MAX or 5
    end
    for i = 0, n - 1 do
      fn(layer, i)
    end
  end
end

function BBD_ROSTER_DrawAll()
  each_instance(BBD_ROSTER_DrawCard)
end

-- the retail cursor on the focused card (as BBCR_DRAFT_Cursor does); show = false takes it away
function BBD_ROSTER_Cursor(show)
  local B, R = BBCR_DRAFT, BBD_ROSTER
  if R.shown ~= nil then
    local l, i = R.shown[1], R.shown[2]
    funcLuaMenuCommand(1774843228 --[[attach locator trace]], l, i, BBCR_DRAFT_CursorLabel(l), false)
    for _, m in ipairs(B.M_FOCUS) do
      funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], l, m, false, i)
    end
    R.shown = nil
  end
  if not show then
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.CURSOR, 0, false)
    return
  end
  local m = R.members[R.sel]
  if m == nil or not B.ready[m.layer .. ":" .. m.i] then
    return
  end
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.CURSOR, 0, true)
  if B.curMoved then
    funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], B.CURSOR, 0, 0, 0, 0)
    B.curMoved = false
  end
  local label = BBCR_DRAFT_CursorLabel(m.layer)
  local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM]], m.layer)
  funcLuaMenuCommand(1774843228 --[[attach locator trace]], m.layer, m.i, label, true)
  funcLuaMenuCommand(381797568 --[[cursor locator]], m.layer, label, m.i, type(n) == "number" and n or 1)
  local sz = BBCR_DRAFT_Sz(m.layer)
  for j = 1, 2 do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], m.layer, B.M_FOCUS[j], j == sz, m.i)
  end
  R.shown = {m.layer, m.i}
end

-- the formation's name (formation info 7 -> its text id -> the text), "" when unknown
local function formation_name()
  local R = BBD_ROSTER
  if R.formation == 0 then
    return ""
  end
  local ok, has, id = pcall(funcLuaCommand, R.FORM_INFO, 7, R.formation)
  if not (ok and has == true and type(id) == "number") then
    return ""
  end
  local okt, s = pcall(funcLuaCommand, R.TEXT_OF, id)
  return (okt and type(s) == "string") and s or ""
end

-- the bar's text: «team · formation»
local function title_text()
  local R = BBD_ROSTER
  local parts = {}
  local okn, name = funcLuaCommand(2151743654 --[[team info]], R.team, 2)
  if okn == true and type(name) == "string" and name ~= "" then
    parts[#parts + 1] = name
  end
  local fname = formation_name()
  if fname ~= "" then
    parts[#parts + 1] = fname
  end
  return table.concat(parts, "  ·  ")
end

-- one of the in-match objects set up (its priority, place, the bar's text)
function BBD_ROSTER_LookLayer(layer)
  local R = BBD_ROSTER
  local base = R.prio or R.PRIO_LOOK
  if layer == R.L_BG then
    funcLuaMenuCommand(1491630496 --[[CMND_SET_DRAW_PRIORITY]], layer, 0, base, true)
    funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], layer, R.BG_X, -R.BG_Y, 0, 0)
  elseif layer == R.L_FRAME then
    funcLuaMenuCommand(1491630496 --[[CMND_SET_DRAW_PRIORITY]], layer, 0, base + 1, true)
    funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], layer, R.FRAME_X, -R.FRAME_Y, 0, 0)
  elseif layer == R.L_TITLE then
    funcLuaMenuCommand(1491630496 --[[CMND_SET_DRAW_PRIORITY]], layer, 0, base + 2, true)
    funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], layer, R.TITLE_X, -R.TITLE_Y, 0, 0)
    for _, mesh in ipairs(R.M_TITLE_OFF) do
      funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, mesh, false, 0)
    end
    funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING]], layer, R.T_TITLE, R.title or "", 0)
  else
    return
  end
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, 0, R.state ~= nil and R.state ~= "closing")
end

-- the picker hidden and the in-match objects opened (show), or closed (not show; the picker comes back with
-- BBCR_DRAFT_Unstash / the grid's retail restore)
function BBD_ROSTER_Look(show)
  local B, R = BBCR_DRAFT, BBD_ROSTER
  local looks = {R.L_BG, R.L_FRAME, R.L_TITLE}
  if not show then
    if R.opened then
      for _, layer in ipairs(looks) do
        pcall(funcLuaMenuCommand, 1273612389 --[[CMND_CLOSE_LAYER]], layer)
      end
      R.opened = false
    end
    return
  end
  if #B.stash == 0 then
    for _, layer in ipairs({B.GRID, B.ATTACH, B.LOCK, B.LEFT, B.TACTICS_BASE, B.TACTICS_CMD, B.FRAME}) do
      BBCR_DRAFT_Stash(layer)
    end
    for _, layer in ipairs(R.PICKER_HIDE) do
      BBCR_DRAFT_Stash(layer)
    end
  end
  if VRFW_BBP_Hide ~= nil then
    pcall(VRFW_BBP_Hide) -- the page / category / season strip
  end
  -- the team panel (vs01_44_p1) holds the picker's own 3D character: closed (not only hidden) so its model component
  -- does not drive the shared menu camera under the player page's model; opened again by BBD_ROSTER_Finish
  if not R.panel_closed and funcLuaMenuCommand(2640875187 --[[CMND_IS_OPEN_LAYER]], B.TEAMINFO, 0) == true then
    funcLuaMenuCommand(1273612389 --[[CMND_CLOSE_LAYER]], B.TEAMINFO)
    R.panel_closed = true
  end
  if R.prio == nil then
    local p = funcLuaMenuCommand(1018283794 --[[draw priority]], R.PICKER_BG, 0)
    R.prio = (type(p) == "number" and p + 1 < R.PRIO_CARDS - 3) and (p + 1) or R.PRIO_LOOK
  end
  R.title = title_text()
  if not R.opened then
    for _, layer in ipairs(looks) do
      funcLuaMenuCommand(629267548 --[[CMND_OPEN_LAYER]], layer)
    end
    R.opened = true
  end
  for _, layer in ipairs(looks) do
    BBD_ROSTER_LookLayer(layer)
  end
end

-- the frame's node poses and the bar's place in the log, once per opening (the layout check)
function BBD_ROSTER_Probe()
  local R = BBD_ROSTER
  local parts = {}
  for _, node in ipairs(R.PROBE_NODES) do
    local x, y, z, ok = funcLuaMenuCommand(2373227714 --[[CMND_GET_MESH_POSE]], R.L_FRAME, 0, node)
    parts[#parts + 1] = string.format("%s(%s,%s)", tostring(ok), tostring(x), tostring(y))
  end
  local tx, ty = funcLuaMenuCommand(4002164178 --[[global position]], R.L_TITLE, 0)
  local cx, cy = funcLuaMenuCommand(4002164178 --[[global position]], BBCR_DRAFT.SLOT, 0)
  BBD_ROSTER_Log("layout probe: frame lu/rd/sub1/sub5/leader " .. table.concat(parts, " ") .. " title at "
    .. tostring(tx) .. "," .. tostring(ty) .. " card 0 at " .. tostring(cx) .. "," .. tostring(cy))
end

-- the player page's model and the menu camera in the log, once per opening (MODEL_PROBE frames after the page is up)
function BBD_ROSTER_ModelProbe()
  local R = BBD_ROSTER
  local okc, has, ox, oy, oz = pcall(funcLuaCommand, R.CAM_GET, R.CAM)
  local okp, hp, px, py, pz = pcall(funcLuaCommand, R.CAM_POS, R.CAM)
  local okm, mx, my, mz = pcall(funcLuaMenuCommand, 499270986 --[[mesh global position]], R.MODEL_LAYER, 0,
    R.MODEL_NODE, R.PLATE)
  BBD_ROSTER_Log("model probe: camera offset " .. tostring(has) .. " " .. tostring(ox) .. "," .. tostring(oy) .. ","
    .. tostring(oz) .. " camera position " .. tostring(hp) .. " " .. tostring(px) .. "," .. tostring(py) .. ","
    .. tostring(pz) .. " model layer " .. tostring(okm) .. " " .. tostring(mx) .. "," .. tostring(my) .. ","
    .. tostring(mz) .. " team panel closed " .. tostring(R.panel_closed))
end

-- the guide while the viewer is up: no entries (Esc stays), the hint line
function BBD_ROSTER_Guide()
  local B, R = BBCR_DRAFT, BBD_ROSTER
  funcLuaMenuCommand(2209673388 --[[guide entries]], B.MENU, R.GUIDE_LAYER, {}, {}, {}, {}, {})
  funcLuaMenuCommand(452337289 --[[guide commands]], B.MENU, R.GUIDE_LAYER, {})
  BBCR_DRAFT_Guide(BBCR_DRAFT_Text(R.TXT_HINT))
end

function BBD_ROSTER_Busy()
  local B, R = BBCR_DRAFT, BBD_ROSTER
  return B.mode ~= nil or B.pk ~= nil or B.quitCo ~= nil or B.refresh ~= nil or R.refresh ~= nil
    or (type(BBT_G) == "table" and BBT_G.co ~= nil)
    or (type(VRFW_BBP) == "table" and VRFW_BBP.pend ~= nil)
    or funcLuaMenuCommand(2640875187 --[[CMND_IS_OPEN_LAYER]], B.DIFFWIN) == true
    or funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT]], R.SUB_WINDOW) == true
    or plate_exists()
end

-- the focused member on the open page (or once it is open)
function BBD_ROSTER_Show()
  local R = BBD_ROSTER
  local m = R.members[R.sel]
  if m == nil then
    return
  end
  if R.state ~= "view" or not page_up() then
    R.pending = m
    return
  end
  R.pending = nil
  if R.plate ~= nil and R.plate.param == m.param then
    return
  end
  funcLuaMenuCommand(R.PLATE_SET, m.param, m.level, m.rar, false)
  if R.plate ~= nil then
    R.plate.param = m.param
  end
end

-- the menu camera's offset kept (open) / put back (close)
local function camera_keep()
  local R = BBD_ROSTER
  local ok, has, x, y, z = pcall(funcLuaCommand, R.CAM_GET, R.CAM)
  R.cam = (ok and has == true and type(x) == "number") and {x, y or 0, z or 0} or nil
end

local function camera_back()
  local R = BBD_ROSTER
  if R.cam ~= nil then
    pcall(funcLuaCommand, R.CAM_SET, R.CAM, R.cam[1], R.cam[2], R.cam[3])
  end
end

-- Y on the grid
function BBD_ROSTER_Open()
  local B, R = BBCR_DRAFT, BBD_ROSTER
  if R.state ~= nil then
    return
  end
  if BBD_ROSTER_Busy() then
    ng()
    return
  end
  local tile = funcLuaMenuCommand(2603265800 --[[focus index]], B.GRID)
  local team = BBD_ROSTER_TeamOf(tile)
  if team == 0 or team == B.TEAM then
    ng()
    BBD_ROSTER_Log("refused: tile", tostring(tile), "team", tostring(team))
    return
  end
  if not BBD_ROSTER_Load(team) then
    ng()
    BBD_ROSTER_Log("refused: no members, team", tostring(team))
    return
  end
  local m = R.members[1]
  R.state, R.team, R.tile, R.sel, R.shown, R.pending = "opening", team, tile, 1, nil, nil
  R.ylock = true -- the Y that opened it must be released before Y closes
  R.plate = {at = R.frame, seen = false, param = m.param, asked = nil}
  R.cam_again, R.probe = nil, R.PROBE_FRAMES
  camera_keep()
  funcLuaCommand(1917805374, R.SE_OPEN)
  funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS]], B.GRID, false)
  BBD_ROSTER_Look(true)
  BBCR_DRAFT_Open()
  BBD_ROSTER_DrawAll()
  BBD_ROSTER_Cursor(true)
  BBD_ROSTER_Guide()
  -- the player page of the first player (the right half)
  param_set(R.P_PARAM, m.param)
  param_set(R.P_LEVEL, m.level)
  param_set(R.P_RARITY, m.rar)
  funcLuaCommand(433545986 --[[CMND_OPEN_MENU_OBJECT]], R.PLATE)
  BBD_ROSTER_Log("open: tile", tile, "team", team, "members", #R.members, "formation", R.formation)
end

-- Back / Y: the page is closed first, the grid comes back once it is gone (BBD_ROSTER_ClosingStep)
function BBD_ROSTER_Close()
  local R = BBD_ROSTER
  if R.state == nil or R.state == "closing" then
    return
  end
  funcLuaCommand(1917805374, R.SE_BACK)
  closing("asked")
  BBD_ROSTER_Cursor(false)
end

-- the grid back as after the Draft screen (the page is gone)
function BBD_ROSTER_Finish(why)
  local B, R = BBCR_DRAFT, BBD_ROSTER
  params_clear()
  R.state, R.plate, R.pending, R.probe = nil, nil, nil, nil
  BBD_ROSTER_Cursor(false)
  each_instance(function(layer, i)
    pcall(funcLuaMenuCommand, 1491630496 --[[CMND_SET_DRAW_PRIORITY]], layer, i, B.PRIO, true)
  end)
  BBD_ROSTER_Look(false)
  BBCR_DRAFT_CloseLayers() -- the Draft's layers closed, the page line back
  BBCR_DRAFT_Unstash()
  if R.panel_closed then
    funcLuaMenuCommand(629267548 --[[CMND_OPEN_LAYER]], B.TEAMINFO) -- the picker's team panel and its character
    R.panel_closed = false
  end
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.CURSOR, 0, true)
  -- the grid back as after the difficulty window (the Draft's own refresh request of that wrapper undone: the
  -- refresh below is this screen's)
  local keep = B.refresh
  local ok, err = pcall(OnCloseEndLayer, B.DIFFWIN, 0)
  B.refresh = keep
  if not ok then
    BBD_ROSTER_Log("grid back error", tostring(err))
  end
  camera_back()
  R.cam_again = {at = R.frame, k = 1}
  R.back = {tile = R.tile, team = R.team}
  R.refresh = B.REFRESH_FRAMES
  BBD_ROSTER_Log("closed", why)
end

-- the page asked to close again until it is gone; a page still opening is waited for (then closed)
function BBD_ROSTER_ClosingStep()
  local R = BBD_ROSTER
  local P = R.plate or {at = R.closing_at, seen = false}
  R.plate = P
  if plate_exists() then
    P.seen = true
    if P.asked == nil or R.frame - P.asked >= R.CLOSE_AGAIN then
      funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], R.PLATE)
      P.asked = R.frame
    end
  elseif P.seen or R.frame - P.at > R.PLATE_WAIT then
    BBD_ROSTER_Finish(P.seen and "page gone" or "no page")
    return
  end
  if R.frame - R.closing_at > R.CLOSE_MAX then
    BBD_ROSTER_Finish("page still there after " .. R.CLOSE_MAX .. " frames")
  end
end

-- the page appeared (opening -> view); it never came: back to the grid
function BBD_ROSTER_OpeningStep()
  local R = BBD_ROSTER
  local P = R.plate
  if plate_exists() then
    P.seen = true
    if page_up() then
      R.state = "view"
      params_clear()
      R.model_probe = R.MODEL_PROBE
      BBD_ROSTER_Log("page up")
      if R.pending ~= nil then
        BBD_ROSTER_Show()
      end
    end
  elseif P.seen or R.frame - P.at > R.PLATE_WAIT then
    closing("the page did not open")
  end
end

-- the page gone by itself while viewing: back to the grid
function BBD_ROSTER_ViewStep()
  local R = BBD_ROSTER
  if not plate_exists() then
    closing("the page is gone")
    return
  end
  if R.pending ~= nil then
    BBD_ROSTER_Show()
  end
end

-- nearest card in the direction (dx, dy) (dy > 0 = up), as the Draft's pitch moves
function BBD_ROSTER_Move(dx, dy)
  local R = BBD_ROSTER
  local from = R.members[R.sel]
  if from == nil then
    return
  end
  local best, bestScore = nil, nil
  for pass = 1, 2 do
    for k, m in ipairs(R.members) do
      if k ~= R.sel then
        local vx, vy = m.x - from.x, from.y - m.y -- y up
        local along = vx * dx + vy * dy
        local across = math.abs(vx * dy - vy * dx)
        if along > 0 and (pass == 2 or across <= along * 1.2) then
          local score = along + 0.5 * across
          if bestScore == nil or score < bestScore then
            best, bestScore = k, score
          end
        end
      end
    end
    if best ~= nil then
      break
    end
  end
  if best ~= nil then
    R.sel = best
    BBD_ROSTER_Cursor(true)
    BBD_ROSTER_Show()
    funcLuaCommand(1917805374, R.SE_MOVE)
  end
end

function BBD_ROSTER_PlatePage(d)
  local R = BBD_ROSTER
  if not page_up() then
    return
  end
  funcLuaMenuCommand(d < 0 and R.PLATE_PAGE_PREV or R.PLATE_PAGE_NEXT)
  funcLuaMenuCommand(R.PLATE_PAGE_UPDATE)
end

-- ---------------------------------------------------------------- the mouse

function BBD_ROSTER_Pointed()
  local R = BBD_ROSTER
  local mx, my = funcLuaMenuCommand(558229292 --[[pointer]])
  if type(mx) ~= "number" or type(my) ~= "number" then
    return nil
  end
  local py = -my
  for k, m in ipairs(R.members) do
    local gx, gy = funcLuaMenuCommand(4002164178 --[[global position]], m.layer, m.i)
    if type(gx) == "number" and type(gy) == "number" and math.abs(mx - gx) <= m.half[1]
        and math.abs(py - gy) <= m.half[2] then
      return k
    end
  end
  return nil
end

function BBD_ROSTER_Mouse()
  local R = BBD_ROSTER
  local click = funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT]], 1332654303 --[[MENU_CTRL]], R.CLICK) == true
  local edge = click and not R.prev_click
  R.prev_click = click
  if not edge or R.state ~= "view" then
    return
  end
  local k = BBD_ROSTER_Pointed()
  if k ~= nil and k ~= R.sel then
    R.sel = k
    BBD_ROSTER_Cursor(true)
    BBD_ROSTER_Show()
    funcLuaCommand(1917805374, R.SE_MOVE)
  end
end

-- the panel of the tile again (team name, formation, tactics)
function BBD_ROSTER_Panel()
  local q = BBD_ROSTER.back
  if q == nil then
    return
  end
  pcall(UpdateTeamNameText, q.team, true)
  pcall(UpdateFormation, q.team, true)
  pcall(UpdateTacticsLayer, q.team, true)
end

function BBD_ROSTER_Step()
  local R = BBD_ROSTER
  R.frame = R.frame + 1
  if R.ylock and funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT]], 1332654303 --[[MENU_CTRL]], R.K_FUNC3) ~= true then
    R.ylock = false
  end
  if R.cam_again ~= nil then
    local q = R.cam_again
    local due = R.CAM_AGAIN[q.k]
    if due == nil then
      R.cam_again = nil
    elseif R.frame - q.at >= due then
      camera_back()
      q.k = q.k + 1
    end
  end
  if R.refresh ~= nil then
    R.refresh = R.refresh - 1
    if R.refresh <= 0 then
      R.refresh = nil
      local q = R.back
      local ok, err = pcall(BBCR_DRAFT_Refresh, q and q.tile or -1, BBD_ROSTER_Panel)
      if not ok then
        BBD_ROSTER_Log("refresh error", tostring(err))
      end
      R.back = nil
    end
  end
  if R.probe ~= nil then
    R.probe = R.probe - 1
    if R.probe <= 0 then
      R.probe = nil
      pcall(BBD_ROSTER_Probe)
    end
  end
  if R.model_probe ~= nil and R.state == "view" then
    R.model_probe = R.model_probe - 1
    if R.model_probe <= 0 then
      R.model_probe = nil
      pcall(BBD_ROSTER_ModelProbe)
    end
  end
  if R.state == "opening" then
    BBD_ROSTER_OpeningStep()
  elseif R.state == "view" then
    BBD_ROSTER_ViewStep()
  end
  if R.state == "closing" then
    BBD_ROSTER_ClosingStep()
  end
  if R.state ~= nil then
    BBD_ROSTER_Mouse()
  else
    R.prev_click = false
  end
end

-- ---------------------------------------------------------------- the footer prompt (declared at chunk load, pure Lua)

if VRFW_FooterPrompts ~= nil then
  VRFW_FooterPrompts.Add({
    Name = "BattleBayDeluxe.Roster",
    Menu = "enjoy_team_select_menu_campaign",
    Text = BBD_ROSTER.TXT_GUIDE,
    Icon = BBD_ROSTER.I_FUNC3,
    Command = BBD_ROSTER.K_FUNC3,
    Order = 100,
    When = function()
      return BBD_ROSTER.guide_on == true and BBD_ROSTER.tile_ok == true
    end,
  })
  -- this menu's guide is the right-hand one (mainmenu01_06_base_button_guide_right), not the framework's default
  VRFW_FooterPrompts.Attach("enjoy_team_select_menu_campaign", "UpdateButtonGuide", BBD_ROSTER.GUIDE_LAYER)
end

do
  -- the grid's guide (a3 = the difficulty window's guide): «Plantilla» only on the grid itself, on a team Y opens
  local guide = UpdateButtonGuide
  function UpdateButtonGuide(a1, a2, a3, ...)
    local R = BBD_ROSTER
    R.guide_on = a3 ~= true and R.state == nil and BBCR_DRAFT.mode == nil
    local ok, can = pcall(BBD_ROSTER_TileOk)
    R.tile_ok = ok and can == true
    return guide(a1, a2, a3, ...)
  end

  -- the focus moved between a team Y opens and another tile: the grid's guide set again
  local change = OnChangeFocus
  if change ~= nil then
    function OnChangeFocus(a1, a2, ...)
      local r = table.pack(change(a1, a2, ...))
      local B, R = BBCR_DRAFT, BBD_ROSTER
      if a1 == B.GRID and R.state == nil and B.mode == nil then
        pcall(function()
          local can = BBD_ROSTER_TileOk()
          if can ~= R.tile_ok and funcLuaMenuCommand(2640875187 --[[CMND_IS_OPEN_LAYER]], B.DIFFWIN) ~= true then
            UpdateButtonGuide(B.MENU, R.GUIDE_LAYER, false)
          end
        end)
      end
      return table.unpack(r, 1, r.n)
    end
  end

  local step = Step
  function Step(...)
    local r = table.pack(step(...))
    local R = BBD_ROSTER
    local ok, err = pcall(BBD_ROSTER_Step)
    if not ok then
      BBD_ROSTER_Log("step error", tostring(err))
      if R.state == "closing" then
        pcall(BBD_ROSTER_Finish, "step error")
      elseif R.state ~= nil then
        R.state, R.closing_at = "closing", R.frame
      end
    end
    return table.unpack(r, 1, r.n)
  end

  local open = OnOpenLayer
  function OnOpenLayer(a1, a2, ...)
    local r = table.pack(open(a1, a2, ...))
    local B, R = BBCR_DRAFT, BBD_ROSTER
    if R.state ~= nil and R.state ~= "closing" and type(a2) == "number" then
      local ok, err = pcall(function()
        if a1 == B.SLOT or a1 == B.CARD then
          BBD_ROSTER_DrawCard(a1, a2)
          local m = R.members[R.sel]
          if m ~= nil and m.layer == a1 and m.i == a2 then
            BBD_ROSTER_Cursor(true)
          end
        elseif a1 == R.L_BG or a1 == R.L_FRAME or a1 == R.L_TITLE then
          BBD_ROSTER_LookLayer(a1)
        end
      end)
      if not ok then
        BBD_ROSTER_Log("layer open error", tostring(err))
      end
    end
    return table.unpack(r, 1, r.n)
  end

  -- Enter does nothing on the squad (the page follows the cursor); the formation bar's own collision neither
  local decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    if BBD_ROSTER.state ~= nil and (a1 == BBCR_DRAFT.ANCHOR or a1 == BBD_ROSTER.L_TITLE) then
      return
    end
    return decide(a1, a2, ...)
  end

  local fn = OnFunction
  function OnFunction(a1, a2, ...)
    local B, R = BBCR_DRAFT, BBD_ROSTER
    if R.state ~= nil then
      local ok, err = true, nil
      if R.state ~= "view" then
        -- the page is opening or closing: nothing is taken
      elseif a1 == B.FN_UP or a1 == B.FN_DOWN or a1 == B.FN_LEFT or a1 == B.FN_RIGHT then
        local dx = (a1 == B.FN_RIGHT and 1) or (a1 == B.FN_LEFT and -1) or 0
        local dy = (a1 == B.FN_UP and 1) or (a1 == B.FN_DOWN and -1) or 0
        ok, err = pcall(BBD_ROSTER_Move, dx, dy)
      elseif a1 == R.FN_Y then
        if not R.ylock then
          ok, err = pcall(BBD_ROSTER_Close)
        end
      elseif a1 == R.FN_PAGE_PREV or a1 == R.FN_PAGE_NEXT then
        ok, err = pcall(BBD_ROSTER_PlatePage, a1 == R.FN_PAGE_PREV and -1 or 1)
      elseif a1 ~= R.FN_GRID_Y then
        return fn(a1, a2, ...)
      end
      if not ok then
        BBD_ROSTER_Log("function error", tostring(err))
      end
      return 1
    end
    if a1 == R.FN_GRID_Y then
      local ok, err = pcall(BBD_ROSTER_Open)
      if not ok then
        BBD_ROSTER_Log("open error", tostring(err))
        if R.state ~= nil then
          R.state, R.closing_at = "closing", R.frame -- the page (if asked) closed, then the grid back
        end
      end
      return 1
    end
    return fn(a1, a2, ...)
  end

  local back = OnBack
  function OnBack(a1, a2, ...)
    local R = BBD_ROSTER
    if R.state ~= nil and a1 == BBCR_DRAFT.ANCHOR then
      if R.state == "view" then
        local ok, err = pcall(BBD_ROSTER_Close)
        if not ok then
          BBD_ROSTER_Log("back error", tostring(err))
        end
      end
      return 1
    end
    return back(a1, a2, ...)
  end

  -- the grid panel is held while the viewer is up (a native refresh would put its pitch and cards back)
  local formation = UpdateFormation
  function UpdateFormation(a1, a2, ...)
    if BBD_ROSTER.state ~= nil and a2 ~= false then
      return
    end
    return formation(a1, a2, ...)
  end

  local tactics = UpdateTacticsLayer
  if tactics ~= nil then
    function UpdateTacticsLayer(a1, a2, ...)
      if BBD_ROSTER.state ~= nil and a2 ~= false then
        return
      end
      return tactics(a1, a2, ...)
    end
  end
end
