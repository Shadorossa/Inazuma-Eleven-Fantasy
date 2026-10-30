-- BattleBayDeluxe bb_draft, the «Plantilla» viewer of the Campaña grid (enjoy_team_select_menu_campaign; Battle Bay
-- Deluxe 1.5.83; docs/game/modes/estadio-bb.md §14.18 and §14.21). Runs after bbd_campaign.lua in the same script and
-- uses the Draft's anchor, cursor and card helpers (BBCR_DRAFT_*). Laid out like the team dock's «Formación»:
--   * Y on a tile of the grid (the grid layer's retail CMD_FUNC3 row, function 756653130: no retail handler in the
--     campaign script) replaces the picker on screen: every picker layer is hidden (crest grid, locks, the page /
--     category strip, the Campaña / Torneo selector, the team panel, its pitch, cards and tactics) and the formation
--     screen's objects are opened on the grid's menu (content\menus\bb_draft.toml): the background
--     (evt_bbd_roster_background: soccer11_01_formation_bg drawn in the background pass, under the 3D model), the
--     dock's pitch frame with the bench, manager and coach places (BetterUI's soccer11_02_formation_frame_evt_fc) and
--     the formation bar (soccer11_12_formation_button: the formation's name only, no team name).
--   * The cards (evt_bbd_roster_card, BetterUI's formation card, instance = member slot as in the retail dock):
--     starters at the retail placement of the frame's pitch (CalcFormationIconPosition of soccer_common over the
--     frame's _pos_formation01_cc / lu / ru / ld / rd, the dock's units; the goalkeeper lifted as the dock does),
--     substitutes on the frame's bench places (_pos_sub_atc01..05), managers on its manager places
--     (_pos_support_atc01..03), the coach (slot 19) as the large coach card on _atc_leader01. A free bench, manager or
--     coach place shows the retail empty slot (evt_bbd_roster_blank, BetterUI's blank card: _chr_blank_s01, the
--     manager / coach mark). Places are read from the frame at run time (CMND_GET_MESH_POSE); the frame's bind pose
--     is the fallback. With BetterUI the cards show no level (BetterUI.CardHideLevel after each card draw).
--   * The RIGHT half is the retail player page (personal_plate_menu) of the focused player, opened once with the
--     players-universe parameters (param id, level, rarity) as the retail pack list does
--     (chara_pack_probability_list_menu) and switched with 1101551215 (SetPersonalPlateCharaParam) whenever the cursor
--     moves. The page keeps its own menu inactive in that mode, so this screen keeps the input on the Draft's anchor
--     (evt_bb_draft_anchor): arrows / a click move the cursor, L2 / R2 turn the page's pages (567813453 / 2019940505 +
--     3297841487), Back / Y close. Read-only. While the page is up the game's parameter store holds
--     BattleBayDeluxe.lineup (LINEUP_FLAG): other mods' plate code reads it to change that page on this screen only
--     (Utilities: no team passives / TRAYECTORIA pages; BetterUI: no level in the header). It also holds the shown
--     player's team and member slot (VRFW.plate_team / VRFW.plate_slot, the VR-Framework's VRFW_PlateMember): the page
--     shows the items of his row of the team (boots, ...) and its 3D model wears his team's kit.
--   * The page's 3D model (Character Reforged's evt_pp_model) is drawn in the 3D pass: only background-pass layers
--     (m_drawType 1) are under it, so the background is a background-pass copy. The model and the picker's own
--     character (the team panel vs01_44_p1's model component) share the menu camera: the team panel is closed while
--     the viewer is up and opened again on the way out; the MenuCamera offset is kept at the opening and put back after
--     the page is gone (again 30 and 90 frames later: the model's release is late).
--     Log lines «roster layout probe» (the frame's nodes) and «roster model probe» (camera offset / position, the
--     page's model layer) once per opening.
--   * Closing is ordered: the page is asked to close again until it is gone (a page still opening is waited for),
--     and only then the grid comes back (the retail OnCloseEndLayer of the difficulty window, then
--     BBCR_DRAFT_Refresh with the focus on the same tile and its panel redrawn; the grid's crests kept, not reloaded:
--     VRFW_BBP_KeepCrests). Y acts only after the key was
--     released (CMD_FUNC3 repeats while held). Nothing is accepted while the page opens or closes.
--   * The footer «<Y> Plantilla» (text evt_bbd_roster) after the grid's retail entries (Aceptar, Descripción), declared
--     to the VR-Framework's footer prompts (VRFW_FooterPrompts, attached to UpdateButtonGuide on this menu's guide
--     layer mainmenu01_06_base_button_guide_right; a click on it sends CMD_FUNC3); shown only while the focused tile
--     is a team Y opens (the guide is set again when the focus moves between such tiles and the others).
-- Refused (the retail NG sound): an empty tile, the Draft tile, a team without readable members, while a window,
-- the difficulty window, the Torneo's grid flow, a page turn or another player page is busy. Globals only
-- (BBD_ROSTER*); at chunk load only the footer prompt's declaration (pure Lua).
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}
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
  -- the formation screen's objects (content\menus\bb_draft.toml)
  L_BG = @crc:evt_bbd_roster_bg@, L_FRAME = @crc:evt_bbd_roster_frame@, L_TITLE = @crc:evt_bbd_roster_title@,
  -- the squad's cards (instance = member slot) and the empty bench / manager / coach places
  L_CARD = @crc:evt_bbd_roster_card@, L_BLANK = @crc:evt_bbd_roster_blank@,
  T_TITLE = 1158637427 --[[_text_formation_btn01]],
  M_TITLE_OFF = {@crc:_formation_focus01@, @crc:_dmy_formation_btn01@},
  TITLE_CURSOR = 3528595086 --[[the bar's cursor label: the retail dock unhooks it when the bar opens]],
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
  LINEUP_FLAG = @crc:BattleBayDeluxe.lineup@ --[[parameter set while this screen shows the page]],
  -- the VR-Framework's plate member (VRFW_PlateMember): the shown player's team and member slot, so the page shows his
  -- row's equipment and his team's kit
  MEMBER_TEAM = @crc:VRFW.plate_team@, MEMBER_SLOT = @crc:VRFW.plate_slot@,
  PLATE_PAGE_PREV = 567813453, PLATE_PAGE_NEXT = 2019940505, PLATE_PAGE_UPDATE = 3297841487,
  CHARA_INFO = @crc:CMND_GET_CHARA_INFO@ --[[CMND_GET_CHARA_INFO (param, 8) = chara_param rarity]],
  RARITY_DEFAULT = 4, RARITY_MAX = 7,
  FORM_INFO = @crc:CMND_GET_SOCCER_FORMATION_INFO@ --[[CMND_GET_SOCCER_FORMATION_INFO: (7, formation) -> ok, name text id]], TEXT_OF = 297699480,
  CARD_CMD = 2339877830 --[[the retail card draw]],
  SUB_WINDOW = 2941513916 --[[sub_window_group]],
  CLICK = 218912913 --[[CMD_EVT_MOUSE_LEFT]],
  -- member slots as the retail dock numbers them (soccer_formation_menu_inc IsMainMember / IsSubMember / IsManager)
  STARTERS = 11, BENCH_END = 16, MANAGERS_END = 19, STAFF_SLOT = 19, CARD_COUNT = 20,
  -- layout, screen px of the 1920 x 1080 menu camera (x from the left, y DOWN; positions are sent as (x, -y)). The
  -- frame is drawn around its layer origin, put at FRAME_X / FRAME_Y (its pitch where the in-match «Formación» has it).
  FRAME_X = 437, FRAME_Y = 468, BG_X = 0, BG_Y = 0,
  -- the frame's nodes (soccer11_02 layout); the pitch is a trapezoid around _pos_formation01_cc
  NODE_CC = @crc:_pos_formation01_cc@, NODE_LU = @crc:_pos_formation01_lu@, NODE_RU = @crc:_pos_formation01_ru@,
  NODE_LD = @crc:_pos_formation01_ld@, NODE_RD = @crc:_pos_formation01_rd@,
  NODE_BENCH = {@crc:_pos_sub_atc01@, @crc:_pos_sub_atc02@, @crc:_pos_sub_atc03@, @crc:_pos_sub_atc04@,
                @crc:_pos_sub_atc05@},
  NODE_MANAGERS = {@crc:_pos_support_atc01@, @crc:_pos_support_atc02@, @crc:_pos_support_atc03@},
  NODE_LEADER = @crc:_atc_leader01@,
  -- the frame's bind pose (soccer11_02_evt_fc), used only when the pose command gives no number
  BIND_POSE = {
    [@crc:_pos_formation01_cc@] = {0, 0}, [@crc:_pos_formation01_lu@] = {-252, 278},
    [@crc:_pos_formation01_ru@] = {252, 278}, [@crc:_pos_formation01_ld@] = {-346, -381},
    [@crc:_pos_formation01_rd@] = {346, -381},
    [@crc:_pos_sub_atc01@] = {439, 259}, [@crc:_pos_sub_atc02@] = {439, 157}, [@crc:_pos_sub_atc03@] = {439, 55},
    [@crc:_pos_sub_atc04@] = {439, -47}, [@crc:_pos_sub_atc05@] = {439, -149},
    [@crc:_pos_support_atc01@] = {373, -312}, [@crc:_pos_support_atc02@] = {317, -412},
    [@crc:_pos_support_atc03@] = {429, -412}, [@crc:_atc_leader01@] = {-285, -393},
  },
  -- the dock's formation rule (soccer_formation_menu_inc SetupFormationIconPosition): width / depth units of the
  -- formation data, its base position set, the goalkeeper's lift
  FORMATION_WIDTH_UNITS = 60, FORMATION_DEPTH_UNITS = 94, FORMATION_BASE_SET = 2, KEEPER_LIFT = 20,
  -- the starters without a retail placement: their formation placement (CMND_BBD_FORMATION_PLACE) scaled into the
  -- pitch (widest |x| to PITCH_HALF_W around the centre, first / last rows PITCH_TOP_IN / PITCH_BOTTOM_IN inside it)
  PITCH_HALF_W = 255, PITCH_TOP_IN = 25, PITCH_BOTTOM_IN = 50,
  GRID_DX = 150, GRID_DY = 150, -- starters without any placement: rows of 4 over the pitch
  CARD_SCALE = 1.05, BENCH_SCALE = 1, COACH_SCALE = 1,
  -- the blank card's meshes (team00_01_p1 layout, as SetBlankMeshByCardType switches them)
  M_BLANK_LARGE = 3133268926 --[[_chr_blank01]], M_BLANK_SMALL = 2623475960 --[[_chr_blank_s01]],
  M_BLANK_OFF = {3083628236 --[[_chr_change_blank01]], 308279580 --[[_chr_change_blank_s01]],
                 2933978864 --[[_chr_change01]], 2675475129 --[[_chr_change_s01]]},
  M_BLANK_MARK = 263310765 --[[_icon_blank_mark01]], M_BLANK_MARK_SMALL = 560392661 --[[_icon_blank_mark_s01]],
  M_BLANK_CHARA = 1378790588 --[[_icon_blank_chr01]], M_BLANK_CHARA_SMALL = 1208665748 --[[_icon_blank_chr_s01]],
  TEX_BLANK = 551387117 --[[#/menu/102_team/team00/team00_01_p1/<LG>/team00_01_p1.g4tx]],
  SPR_MARK_COACH = 3272899405 --[[icon_blank_mark01]], SPR_MARK_MANAGER_SMALL = 3289616799 --[[icon_blank_mark_s02]],
  MAT_MARK = 3272899405 --[[icon_blank_mark01]], MAT_MARK_SMALL = 1562034213 --[[icon_blank_mark_s01]],
  -- the formation bar (its text sits left of the layer origin: the bar ends ~259 px right of it)
  TITLE_X = 434, TITLE_Y = 113,
  PRIO_LOOK = 600, -- the looks' base priority without the picker background's (bg, frame, bar: +0, +1, +2)
  PRIO_BLANK = 711, PRIO_CARDS = 712,
  PROBE_FRAMES = 20,
  -- half sizes on screen for the pointer (half of the card body at its scale)
  HALF_SMALL = {72, 53}, HALF_BENCH = {68, 50}, HALF_COACH = {78, 58},
  PLATE_WAIT = 180, -- frames the page may take to appear
  CLOSE_AGAIN = 30, CLOSE_MAX = 600, -- frames between close requests; frames before the grid comes back anyway
  SE_OPEN = 3848881948 --[[sy0000]], SE_MOVE = 2500047763 --[[sy0005]], SE_BACK = 202039849, SE_NG = 2086672038,
  -- state: nil | "opening" (the page appears) | "view" | "closing" (the page goes)
  state = nil, team = 0, tile = -1, formation = 0, members = {}, empties = {}, sel = 1, shown = nil, plate = nil,
  refresh = nil, back = nil, frame = 0, prev_click = false, guide_on = true, tile_ok = false, ylock = false,
  pending = nil, closing_at = 0, cam = nil, panel_closed = false, model_probe = nil, cam_again = nil, probe = nil,
  prio = nil, title = nil, opened = false, cards_open = false, ready = {},
}

-- the logger (VRFW_Log), made at the first line: the framework's menu files load after the graft blocks
function BBD_ROSTER_Log(...)
  BBD_ROSTER.logger = BBD_ROSTER.logger or VRFW_Log.New("BattleBayDeluxe.roster")
  BBD_ROSTER.logger(...)
end

local function ng()
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, BBD_ROSTER.SE_NG)
end

local function param_set(k, v)
  if VRFW_Param.Has(k) then
    VRFW_Param.Clear(k)
  end
  VRFW_Param.Set(k, v)
end

local function params_clear()
  local R = BBD_ROSTER
  for _, k in ipairs({R.P_PARAM, R.P_LEVEL, R.P_RARITY}) do
    if VRFW_Param.Has(k) then
      VRFW_Param.Clear(k)
    end
  end
end

local function param_clear(k)
  if VRFW_Param.Has(k) then
    VRFW_Param.Clear(k)
  end
end

local function plate_exists()
  return funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, BBD_ROSTER.PLATE) == true
end

local function page_up()
  local R = BBD_ROSTER
  return funcLuaCommand(@crc:CMND_IS_OPEN_MENU_OBJECT@, R.PLATE, R.PLATE_PAGE) == true
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

-- a frame node's pose in the frame's own space (x right, y up): the live pose, else the layout's bind pose
local function frame_pose(node)
  local R = BBD_ROSTER
  local x, y, _, ok = funcLuaMenuCommand(@crc:CMND_GET_MESH_POSE@, R.L_FRAME, 0, node)
  if ok ~= false and type(x) == "number" and type(y) == "number" then
    return x, y
  end
  local p = R.BIND_POSE[node]
  if p ~= nil then
    return p[1], p[2]
  end
  return nil, nil
end

-- a point of the frame's space on screen (x from the left, y down)
local function to_screen(x, y)
  local R = BBD_ROSTER
  if type(x) ~= "number" or type(y) ~= "number" then
    return nil, nil
  end
  return R.FRAME_X + x, R.FRAME_Y - y
end

-- a starter's place by the dock's rule (CalcFormationIconPosition over the frame's pitch nodes, the goalkeeper lifted
-- as SetupFormationIconPosition does); nil when the rule gives nothing
local function retail_pitch_place(slot)
  local R = BBD_ROSTER
  if R.formation == 0 or type(CalcFormationIconPosition) ~= "function" then
    return nil
  end
  local ok, x, y = pcall(CalcFormationIconPosition, slot, R.formation, R.FORMATION_BASE_SET, R.L_FRAME, R.NODE_CC,
    R.NODE_LU, R.NODE_RU, R.NODE_LD, R.NODE_RD, R.FORMATION_WIDTH_UNITS, R.FORMATION_DEPTH_UNITS, true, 1, true)
  if not ok or type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then
    return nil
  end
  local okk, has, kind = pcall(funcLuaCommand, R.FORM_INFO, 5, R.formation, slot)
  if okk and has == true and kind == 0 then
    y = y + R.KEEPER_LIFT
  end
  return to_screen(x, y)
end

-- the starters the dock's rule did not place: their formation placement scaled into the pitch, else a plain grid
local function fallback_pitch_places(list)
  local R = BBD_ROSTER
  local cx, cy = to_screen(frame_pose(R.NODE_CC))
  local _, ty = to_screen(frame_pose(R.NODE_LU))
  local _, by = to_screen(frame_pose(R.NODE_LD))
  cx, ty, by = cx or R.FRAME_X, ty or (R.FRAME_Y - 278), by or (R.FRAME_Y + 381)
  local top, bottom = ty + R.PITCH_TOP_IN, by - R.PITCH_BOTTOM_IN
  local xmax, ymin, ymax = 1, nil, nil
  for _, m in ipairs(list) do
    if R.formation ~= 0 then
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
  local loose = 0
  for _, m in ipairs(list) do
    if m.fx ~= nil then
      m.x = cx + BBCR_DRAFT.MIRROR * R.PITCH_HALF_W * m.fx / xmax
      m.y = top + (m.fy - ymin) / yspan * (bottom - top)
    else
      local col, row = loose % 4, math.floor(loose / 4)
      m.x, m.y = cx + (col - 1.5) * R.GRID_DX, top + row * R.GRID_DY
      loose = loose + 1
    end
  end
end

-- the frame node of a bench, manager or coach slot
local function staff_node(slot)
  local R = BBD_ROSTER
  if slot == R.STAFF_SLOT then
    return R.NODE_LEADER
  elseif slot >= R.BENCH_END then
    return R.NODE_MANAGERS[slot - R.BENCH_END + 1]
  end
  return R.NODE_BENCH[slot - R.STARTERS + 1]
end

-- every member's card place (starters on the pitch, the others on their frame place) and the free bench / manager /
-- coach places (the retail empty slot)
function BBD_ROSTER_Layout()
  local R = BBD_ROSTER
  local loose, taken = {}, {}
  for _, m in ipairs(R.members) do
    taken[m.slot] = true
    m.layer, m.i = R.L_CARD, m.slot
    if m.slot < R.STARTERS then
      m.big, m.scale, m.half = false, R.CARD_SCALE, R.HALF_SMALL
      local x, y = retail_pitch_place(m.slot)
      if x ~= nil then
        m.x, m.y = x, y
      else
        loose[#loose + 1] = m
      end
    else
      m.big = m.slot == R.STAFF_SLOT
      m.scale = m.big and R.COACH_SCALE or R.BENCH_SCALE
      m.half = m.big and R.HALF_COACH or R.HALF_BENCH
      m.x, m.y = to_screen(frame_pose(staff_node(m.slot)))
    end
  end
  if #loose > 0 then
    fallback_pitch_places(loose)
  end
  R.empties = {}
  for slot = R.STARTERS, R.STAFF_SLOT do
    if not taken[slot] then
      local x, y = to_screen(frame_pose(staff_node(slot)))
      if x ~= nil then
        R.empties[#R.empties + 1] = {slot = slot, x = x, y = y}
      end
    end
  end
end

-- the team's members by slot (players 0..15, managers 16..18, the coach 19; the first row of a slot wins); false
-- without a player
function BBD_ROSTER_Load(team)
  local B, R = BBCR_DRAFT, BBD_ROSTER
  local okn, count = funcLuaCommand(2151743654 --[[team info]], team, 8)
  if okn ~= true or type(count) ~= "number" then
    count = 24
  end
  local okf, fm = funcLuaCommand(2151743654 --[[team info]], team, 3)
  R.formation = (okf == true and type(fm) == "number") and fm or 0
  local members, seen, any = {}, {}, false
  for i = 0, count - 1 do
    local ok, has, param, slot, level = pcall(GetTeamMemberInfo, team, i)
    if ok and has == true and type(param) == "number" and param ~= 0 and type(slot) == "number"
        and slot >= 0 and slot <= R.STAFF_SLOT and not seen[slot] then
      seen[slot] = true
      local okr, okc, rar = pcall(funcLuaCommand, R.CHARA_INFO, param, 8)
      if not (okr and okc == true and type(rar) == "number" and rar >= 0 and rar <= R.RARITY_MAX) then
        rar = R.RARITY_DEFAULT
      end
      local m = {param = param, slot = slot, rar = rar,
                 level = (type(level) == "number" and level > 0) and level or B.LEVEL}
      m.coach = slot == R.STAFF_SLOT
      if slot < R.STARTERS and R.formation ~= 0 then
        local okk, hk, kind = pcall(funcLuaCommand, R.FORM_INFO, 6, R.formation, slot)
        m.kind = (okk and hk == true and type(kind) == "number") and kind or 0
      end
      members[#members + 1] = m
      any = any or slot < R.BENCH_END
    end
  end
  table.sort(members, function(a, b)
    return a.slot < b.slot
  end)
  R.members = members
  return any
end

-- the member drawn on (layer, i), nil = none
local function member_on(layer, i)
  if layer ~= BBD_ROSTER.L_CARD then
    return nil
  end
  for _, m in ipairs(BBD_ROSTER.members) do
    if m.i == i then
      return m
    end
  end
  return nil
end

local function empty_on(layer, i)
  if layer ~= BBD_ROSTER.L_BLANK then
    return nil
  end
  for _, e in ipairs(BBD_ROSTER.empties) do
    if e.slot == i then
      return e
    end
  end
  return nil
end

local function place(layer, i, x, y, scale, prio)
  funcLuaMenuCommand(@crc:CMND_SET_DRAW_PRIORITY@, layer, i, prio, true)
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, layer, x, -y, 0, i)
  funcLuaMenuCommand(3362798188, layer, i, scale, scale)
end

-- a member's card: the formation card (small; the coach the large card with the «ENTRENADOR» tab, as the Chronicle's
-- rival formation draws slot 19), its season tag / lock hidden, the focus frame off (only the focused card shows it)
local function member_card(layer, i, m)
  local B, R = BBCR_DRAFT, BBD_ROSTER
  local sz = m.big and 1 or 2
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, layer, i, true)
  for _, mesh in ipairs(B.M_DEF) do
    funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, mesh, false, i)
  end
  for k = sz, #B.M_FACE, 2 do
    funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, B.M_FACE[k], true, i)
  end
  funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, B.M_BASE[sz], true, i)
  funcLuaMenuCommand(R.CARD_CMD, layer, i, m.param, m.big == true, m.coach == true, m.kind or 0, 0, m.level, false,
                     false, 4, 0)
  if type(BetterUI) == "table" and type(BetterUI.CardHideLevel) == "function" then
    pcall(BetterUI.CardHideLevel, layer, i)
  end
  -- BetterUI's compact cards carry no name (the coach's large card showed it)
  if type(BetterUI) == "table" and type(BetterUI.CardHideName) == "function" then
    pcall(BetterUI.CardHideName, funcLuaMenuCommand, layer, i)
  end
  for _, mesh in ipairs(B.M_TAG) do
    funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, mesh, false, i)
  end
  for _, mesh in ipairs(B.M_FOCUS) do
    funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, mesh, false, i)
  end
  local other = 3 - sz
  funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, B.M_BASE[other], false, i)
  -- a card draw may hook the cursor labels again: only the focused card keeps the cursor
  local shown = R.shown
  if shown == nil or shown[1] ~= layer or shown[2] ~= i then
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@ --[[attach locator trace]], layer, i, B.CARD_CURSOR, false)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@ --[[attach locator trace]], layer, i, B.CARD_CURSOR2, false)
  end
end

-- a free bench, manager or coach place as the retail empty slot (SetBlankMeshByCardType): the blank card, with the
-- manager mark on a manager place and the coach mark on the coach place
local function blank_card(layer, i, slot)
  local R = BBD_ROSTER
  local big = slot == R.STAFF_SLOT
  local manager = slot >= R.BENCH_END and not big
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, layer, i, true)
  funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, R.M_BLANK_LARGE, big, i)
  funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, R.M_BLANK_SMALL, not big, i)
  for _, mesh in ipairs(R.M_BLANK_OFF) do
    funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, mesh, false, i)
  end
  funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, R.M_BLANK_MARK, big, i)
  funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, R.M_BLANK_MARK_SMALL, manager, i)
  funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, R.M_BLANK_CHARA, big, i)
  funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, R.M_BLANK_CHARA_SMALL, false, i)
  if big then
    funcLuaMenuCommand(558735651, layer, R.TEX_BLANK, R.SPR_MARK_COACH, R.MAT_MARK, 0, i)
  elseif manager then
    funcLuaMenuCommand(558735651, layer, R.TEX_BLANK, R.SPR_MARK_MANAGER_SMALL, R.MAT_MARK_SMALL, 0, i)
  end
end

-- one instance: its member, a free place, or hidden
function BBD_ROSTER_DrawCard(layer, i)
  local R = BBD_ROSTER
  if not R.ready[layer .. ":" .. i] then
    return
  end
  local live = R.state ~= nil and R.state ~= "closing"
  local m = live and member_on(layer, i) or nil
  local e = (live and m == nil) and empty_on(layer, i) or nil
  if m ~= nil and m.x ~= nil then
    member_card(layer, i, m)
    place(layer, i, m.x, m.y, m.scale, R.PRIO_CARDS)
  elseif e ~= nil then
    blank_card(layer, i, e.slot)
    place(layer, i, e.x, e.y, e.slot == R.STAFF_SLOT and R.COACH_SCALE or R.BENCH_SCALE, R.PRIO_BLANK)
  else
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, layer, i, false)
  end
end

local function each_instance(fn)
  local R = BBD_ROSTER
  for _, layer in ipairs({R.L_CARD, R.L_BLANK}) do
    local n = funcLuaMenuCommand(@crc:CMND_GET_CREATE_LAYER_NUM@, layer)
    if type(n) ~= "number" or n <= 0 then
      n = R.CARD_COUNT
    end
    for i = 0, n - 1 do
      fn(layer, i)
    end
  end
end

function BBD_ROSTER_DrawAll()
  each_instance(BBD_ROSTER_DrawCard)
end

-- the squad's layers opened (once per viewer) / closed
local function cards_open(show)
  local R = BBD_ROSTER
  if show and not R.cards_open then
    funcLuaMenuCommand(@crc:CMND_OPEN_LAYER_ARRAY@, R.L_CARD)
    funcLuaMenuCommand(@crc:CMND_OPEN_LAYER_ARRAY@, R.L_BLANK)
    R.cards_open = true
  elseif not show and R.cards_open then
    pcall(funcLuaMenuCommand, @crc:CMND_CLOSE_LAYER_ARRAY@, R.L_CARD)
    pcall(funcLuaMenuCommand, @crc:CMND_CLOSE_LAYER_ARRAY@, R.L_BLANK)
    R.cards_open = false
    R.ready = {}
  end
end

-- the cursor label of a card size (the large card's / the small card's)
local function cursor_label(big)
  return big and BBCR_DRAFT.CARD_CURSOR or BBCR_DRAFT.CARD_CURSOR2
end

-- the retail cursor on the focused card (as BBCR_DRAFT_Cursor does); show = false takes it away
function BBD_ROSTER_Cursor(show)
  local B, R = BBCR_DRAFT, BBD_ROSTER
  if R.shown ~= nil then
    local l, i = R.shown[1], R.shown[2]
    -- both labels off (the cursor stayed on a card whose other label was hooked)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@ --[[attach locator trace]], l, i, B.CARD_CURSOR, false)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@ --[[attach locator trace]], l, i, B.CARD_CURSOR2, false)
    for _, m in ipairs(B.M_FOCUS) do
      funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, l, m, false, i)
    end
    R.shown = nil
  end
  if not show then
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, B.CURSOR, 0, false)
    return
  end
  local m = R.members[R.sel]
  if m == nil or not R.ready[m.layer .. ":" .. m.i] then
    return
  end
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, B.CURSOR, 0, true)
  if B.curMoved then
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, B.CURSOR, 0, 0, 0, 0)
    B.curMoved = false
  end
  local label = cursor_label(m.big)
  local n = funcLuaMenuCommand(@crc:CMND_GET_CREATE_LAYER_NUM@, m.layer)
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@ --[[attach locator trace]], m.layer, m.i, label, true)
  funcLuaMenuCommand(@crc:CMND_SET_CURSOR_LOCATOR@ --[[cursor locator]], m.layer, label, m.i, type(n) == "number" and n or 1)
  local sz = m.big and 1 or 2
  for j = 1, 2 do
    funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, m.layer, B.M_FOCUS[j], j == sz, m.i)
  end
  R.shown = {m.layer, m.i, m.big}
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

-- the bar's text: the formation's name only (the team is the tile the screen was opened on)
local function title_text()
  return formation_name()
end

-- one of the formation screen's objects set up (its priority, place, the bar's text)
function BBD_ROSTER_LookLayer(layer)
  local R = BBD_ROSTER
  local base = R.prio or R.PRIO_LOOK
  if layer == R.L_BG then
    funcLuaMenuCommand(@crc:CMND_SET_DRAW_PRIORITY@, layer, 0, base, true)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, layer, R.BG_X, -R.BG_Y, 0, 0)
  elseif layer == R.L_FRAME then
    funcLuaMenuCommand(@crc:CMND_SET_DRAW_PRIORITY@, layer, 0, base + 1, true)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, layer, R.FRAME_X, -R.FRAME_Y, 0, 0)
  elseif layer == R.L_TITLE then
    funcLuaMenuCommand(@crc:CMND_SET_DRAW_PRIORITY@, layer, 0, base + 2, true)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, layer, R.TITLE_X, -R.TITLE_Y, 0, 0)
    for _, mesh in ipairs(R.M_TITLE_OFF) do
      funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, layer, mesh, false, 0)
    end
    funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, layer, R.T_TITLE, R.title or "", 0)
    -- the bar never holds the cursor or the focus (the green arrow follows the cards, as on the retail dock)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@ --[[attach locator trace]], layer, 0, R.TITLE_CURSOR, false)
    funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, layer, false)
  else
    return
  end
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, layer, 0, R.state ~= nil and R.state ~= "closing")
end

-- the picker hidden and the formation screen's objects opened (show), or closed (not show; the picker comes back
-- with BBCR_DRAFT_Unstash / the grid's retail restore)
function BBD_ROSTER_Look(show)
  local B, R = BBCR_DRAFT, BBD_ROSTER
  local looks = {R.L_BG, R.L_FRAME, R.L_TITLE}
  if not show then
    if R.opened then
      for _, layer in ipairs(looks) do
        pcall(funcLuaMenuCommand, @crc:CMND_CLOSE_LAYER@, layer)
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
  if not R.panel_closed and funcLuaMenuCommand(@crc:CMND_IS_OPEN_LAYER@, B.TEAMINFO, 0) == true then
    funcLuaMenuCommand(@crc:CMND_CLOSE_LAYER@, B.TEAMINFO)
    R.panel_closed = true
  end
  if R.prio == nil then
    local p = funcLuaMenuCommand(@crc:CMND_GET_DRAW_PRIORITY@ --[[draw priority]], R.PICKER_BG, 0)
    R.prio = (type(p) == "number" and p + 1 < R.PRIO_BLANK - 3) and (p + 1) or R.PRIO_LOOK
  end
  R.title = title_text()
  if not R.opened then
    for _, layer in ipairs(looks) do
      funcLuaMenuCommand(@crc:CMND_OPEN_LAYER@, layer)
    end
    R.opened = true
  end
  for _, layer in ipairs(looks) do
    BBD_ROSTER_LookLayer(layer)
  end
end

-- the frame's node poses and the first card's place in the log, once per opening (the layout check)
function BBD_ROSTER_Probe()
  local R = BBD_ROSTER
  local parts = {}
  for _, node in ipairs({R.NODE_CC, R.NODE_LU, R.NODE_RU, R.NODE_LD, R.NODE_RD, R.NODE_BENCH[1], R.NODE_BENCH[5],
                         R.NODE_MANAGERS[1], R.NODE_LEADER}) do
    local x, y, z, ok = funcLuaMenuCommand(@crc:CMND_GET_MESH_POSE@, R.L_FRAME, 0, node)
    parts[#parts + 1] = string.format("%s(%s,%s)", tostring(ok), tostring(x), tostring(y))
  end
  local tx, ty = funcLuaMenuCommand(4002164178 --[[global position]], R.L_TITLE, 0)
  local cx, cy = funcLuaMenuCommand(4002164178 --[[global position]], R.L_CARD, 0)
  BBD_ROSTER_Log("layout probe: frame cc/lu/ru/ld/rd/sub1/sub5/support1/leader " .. table.concat(parts, " ")
    .. " title at " .. tostring(tx) .. "," .. tostring(ty) .. " card 0 at " .. tostring(cx) .. "," .. tostring(cy)
    .. " formation " .. VRFW_Id.hex(R.formation) .. " free places " .. #R.empties)
end

-- the player page's model and the menu camera in the log, once per opening (MODEL_PROBE frames after the page is up)
function BBD_ROSTER_ModelProbe()
  local R = BBD_ROSTER
  local okc, has, ox, oy, oz = pcall(funcLuaCommand, R.CAM_GET, R.CAM)
  local okp, hp, px, py, pz = pcall(funcLuaCommand, R.CAM_POS, R.CAM)
  local okm, mx, my, mz = pcall(funcLuaMenuCommand, @crc:CMND_GET_MESH_GLOBAL_POSITION@ --[[mesh global position]], R.MODEL_LAYER, 0,
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
    or (type(BattleBayDeluxe.TournamentGrid) == "table" and BattleBayDeluxe.TournamentGrid.co ~= nil)
    or (type(VRFW_BBP) == "table" and VRFW_BBP.pend ~= nil)
    or funcLuaMenuCommand(@crc:CMND_IS_OPEN_LAYER@, B.DIFFWIN) == true
    or funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, R.SUB_WINDOW) == true
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
  param_set(R.MEMBER_SLOT, m.slot)
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

-- the first member to focus: the first starter, else the first member
local function first_member()
  local R = BBD_ROSTER
  for k, m in ipairs(R.members) do
    if m.slot < R.STARTERS then
      return k
    end
  end
  return 1
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
  local sel = first_member()
  local m = R.members[sel]
  R.state, R.team, R.tile, R.sel, R.shown, R.pending = "opening", team, tile, sel, nil, nil
  R.ylock = true -- the Y that opened it must be released before Y closes
  R.plate = {at = R.frame, seen = false, param = m.param, asked = nil}
  R.cam_again, R.probe = nil, R.PROBE_FRAMES
  camera_keep()
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, R.SE_OPEN)
  funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, B.GRID, false)
  BBD_ROSTER_Look(true)
  BBD_ROSTER_Layout()
  BBCR_DRAFT_Open() -- the Draft's anchor takes the input (its own cards stay hidden outside the Draft)
  cards_open(true)
  BBD_ROSTER_DrawAll()
  BBD_ROSTER_Cursor(true)
  BBD_ROSTER_Guide()
  -- the player page of the first player (the right half)
  param_set(R.P_PARAM, m.param)
  param_set(R.P_LEVEL, m.level)
  param_set(R.P_RARITY, m.rar)
  param_set(R.LINEUP_FLAG, 1)
  param_set(R.MEMBER_TEAM, team >= 2147483648 and team - 4294967296 or team) -- the store keeps signed 32-bit numbers
  param_set(R.MEMBER_SLOT, m.slot)
  funcLuaCommand(@crc:CMND_OPEN_MENU_OBJECT@, R.PLATE)
  BBD_ROSTER_Log("open: tile", tile, "team", team, "members", #R.members, "free places", #R.empties)
end

-- Back / Y: the page is closed first, the grid comes back once it is gone (BBD_ROSTER_ClosingStep)
function BBD_ROSTER_Close()
  local R = BBD_ROSTER
  if R.state == nil or R.state == "closing" then
    return
  end
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, R.SE_BACK)
  closing("asked")
  BBD_ROSTER_Cursor(false)
end

-- the grid back as after the Draft screen (the page is gone)
function BBD_ROSTER_Finish(why)
  local B, R = BBCR_DRAFT, BBD_ROSTER
  params_clear()
  param_clear(R.LINEUP_FLAG)
  param_clear(R.MEMBER_TEAM)
  param_clear(R.MEMBER_SLOT)
  R.state, R.plate, R.pending, R.probe = nil, nil, nil, nil
  BBD_ROSTER_Cursor(false)
  cards_open(false)
  BBD_ROSTER_Look(false)
  BBCR_DRAFT_CloseLayers() -- the Draft's layers closed, the page line back
  BBCR_DRAFT_Unstash()
  if R.panel_closed then
    funcLuaMenuCommand(@crc:CMND_OPEN_LAYER@, B.TEAMINFO) -- the picker's team panel and its character
    R.panel_closed = false
  end
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, B.CURSOR, 0, true)
  -- the grid back as after the difficulty window (the Draft's own refresh request of that wrapper undone: the
  -- refresh below is this screen's)
  -- the grid's layers were only hidden: its crests stay loaded and are kept by the redraws of the way back (no white
  -- squares while they would reload); BBD_ROSTER_Step ends it after the refresh
  if VRFW_BBP_KeepCrests ~= nil then
    pcall(VRFW_BBP_KeepCrests, true)
  end
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
      funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, R.PLATE)
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
  if from == nil or from.x == nil then
    return
  end
  local best, bestScore = nil, nil
  for pass = 1, 2 do
    for k, m in ipairs(R.members) do
      if k ~= R.sel and m.x ~= nil then
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
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, R.SE_MOVE)
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
  local click = funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, 1332654303 --[[MENU_CTRL]], R.CLICK) == true
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
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, R.SE_MOVE)
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
  if R.ylock and funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, 1332654303 --[[MENU_CTRL]], R.K_FUNC3) ~= true then
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
      local ok, err = pcall(BBCR_DRAFT_Refresh, q and q.tile or -1, BBD_ROSTER_Panel, true)
      if not ok then
        BBD_ROSTER_Log("refresh error", tostring(err))
      end
      if VRFW_BBP_KeepCrests ~= nil then
        pcall(VRFW_BBP_KeepCrests, false)
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
          if can ~= R.tile_ok and funcLuaMenuCommand(@crc:CMND_IS_OPEN_LAYER@, B.DIFFWIN) ~= true then
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

  -- the squad's cards: their name table once (as the retail menu does for its own cards in OnSetupLayer), the cursor
  -- labels off (the viewer moves the cursor itself), the draw priority
  local setup = OnSetupLayer
  function OnSetupLayer(a1, a2, ...)
    local r = table.pack(setup(a1, a2, ...))
    local R = BBD_ROSTER
    if (a1 == R.L_CARD or a1 == R.L_BLANK) and type(a2) == "number" then
      local ok, err = pcall(function()
        if a1 == R.L_CARD then
          BBCR_DRAFT_Name(a1, a2)
          funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@ --[[attach locator trace]], a1, a2, BBCR_DRAFT.CARD_CURSOR, false)
          funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@ --[[attach locator trace]], a1, a2, BBCR_DRAFT.CARD_CURSOR2, false)
        end
        funcLuaMenuCommand(@crc:CMND_SET_DRAW_PRIORITY@, a1, a2,
                           a1 == R.L_CARD and R.PRIO_CARDS or R.PRIO_BLANK, true)
      end)
      if not ok then
        BBD_ROSTER_Log("card setup error", tostring(err))
      end
    end
    return table.unpack(r, 1, r.n)
  end

  local open = OnOpenLayer
  function OnOpenLayer(a1, a2, ...)
    local r = table.pack(open(a1, a2, ...))
    local R = BBD_ROSTER
    if R.state ~= nil and R.state ~= "closing" and type(a2) == "number" then
      local ok, err = pcall(function()
        if a1 == R.L_CARD or a1 == R.L_BLANK then
          if a1 == R.L_CARD then
            BBCR_DRAFT_Name(a1, a2) -- only if the setup did not (never twice)
          end
          R.ready[a1 .. ":" .. a2] = true
          BBD_ROSTER_DrawCard(a1, a2)
          local m = R.members[R.sel]
          if m ~= nil and m.layer == a1 and m.i == a2 then
            BBD_ROSTER_Cursor(true)
          end
        elseif a1 == R.L_FRAME then
          -- the frame's places are read from the open frame: the cards laid out again on them
          BBD_ROSTER_LookLayer(a1)
          BBD_ROSTER_Layout()
          BBD_ROSTER_DrawAll()
          BBD_ROSTER_Cursor(true)
        elseif a1 == R.L_BG then
          BBD_ROSTER_LookLayer(a1)
        elseif a1 == R.L_TITLE then
          BBD_ROSTER_LookLayer(a1)
          BBD_ROSTER_Cursor(true) -- the cursor back on the focused card once the bar is up
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
