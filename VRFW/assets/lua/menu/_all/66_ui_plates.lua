-- VRFW_UI: the shared UI plates of the VR-Framework (docs/framework/ui-plates.md; owner 2026-10-13: ONE player header
-- row and ONE move plate for every screen, so a fix reaches all of them). Definitions only (this file runs in every
-- script VM, lua\_all, after the retail chunk): screens call it from their callbacks; no engine call at load.
-- Layout numbers: VRFW_UI_LAYOUT (65_ui_plates_layout.lua, GENERATED from content\defaults\ui_plates.toml).
--
--   VRFW_UI.HeaderRow   the player header row (a retail status plate, soccer11_04 / _04pp layouts)
--     .AfterFill(layer, inst, hdl, o)       the rules after a status-plate fill: natural position badge, staff role
--                                           glyph in the position slot, supporter mark off (o.natural, o.role: false
--                                           switches a rule off)
--     .Natural(hdl) / .NaturalType(hdl) / .ParamType(param)   the player's OWN position (one rule: header rows,
--                                           position-coloured cards and bands)
--     .Badge(layer, inst, icon)             the position badge's sprite (icon_common2)
--     .Track(layer, mesh, on, inst)         a mesh-visibility call seen (glyph / badge state of every row)
--     .ArchBoxShown(layer, inst)            the archetype box rule: shown ⇔ the glyph is shown at home
--     .ArchBox(tag, layer, inst, hdl, st, o) the archetype glyph's slanted box (sprites / dual check of the caller)
--     .Dual(hdl, cmd)                       a dual archetype (two glyphs), from the caller's pair command
--     .Band(layer, inst, keep)              a status plate stripped to its band (keep.band) / description (keep.explain)
--     .BandFill(band, inst, hdl, o)         fill + position colour + strip: the slanted band under a row
--     .Place(layer, inst, s, x, y) / .PlaceBand(band, inst, s, x, y)   a row / its band at scale s, top-left (x, y)
--     .Level(layer, inst, level)            the «Nv.» digits (a temporary status may leave them off)
--     .PortraitOff(layer, inst)             the plate's portrait off screen (the row shows no miniface)
--   VRFW_UI.MovePlate   the element-coloured move plate (retail soccer11_09 row)
--     .Pos(chara, move) / .Graded(chara, move, inst, f, ...)   the move's OWN evolution grade for a row fill
--     .Fill(row, inst, chara, move, o)      one plate: SetupCharaSkillItem on the caller's row layer, graded
--     .Row(row, inst, chara, move, o)       a list row's plate: empty / locked / fixed / inactive states
--     .Pump(step)                           redo the fills made on an instance that was not ready (Step: step = true)
--     .Look(move, chara)                    the plate's data for a quad-drawn plate (sprites, name, graded power)
--     .Tension(L, inst, cost, o) / .TensionOff(L, inst) / .Steps / .TensionScale   a move's TENSIÓN gauge (a
--                                           team02_02 tension group): squares, cost number, locator, PEG look hook
if VRFW_UI == nil then
  local U = {
    LOG = 3661580131,
    C = {
      EXIST = 262659071, OPEN = 629267548, IS_OPEN = 2640875187, VIS = 711242136, MESH = 3405944500,
      SPRITE = 558735651, NODE_VIS = 2158717427, NODE_POS = 2575768773, NODE_SCALE = 2885415772,
      GET_TRANS = 2491463760, SET_TRANS = 1856671416, TEXT = 1083631230, TEXT_VIS = 1505208242,
      PRIM_VIS = 1233047821, PRIM_INDEX = 1927054058, PRIM_SET = 3609943765, SCALE = 3778714801, POS = 1389957207,
      FONT = 2333948100, ANIME = 3781155141,
      CHARA = 1131797651, SKILL_INFO = 2580586398, SKILL_POS = 26437624, COMMON_SKILL = 800895612,
      NAME_TEXT = 720417636,
    },
  }
  VRFW_UI = U
  local C = U.C

  function U.Log(...)
    pcall(funcLuaCommand, U.LOG, "vrfw.ui", ...)
  end

  function U.Layout(name)
    local t = type(VRFW_UI_LAYOUT) == "table" and VRFW_UI_LAYOUT[name] or nil
    return type(t) == "table" and t or {}
  end

  local function M(...)
    return pcall(funcLuaMenuCommand, ...)
  end

  -- ==== HeaderRow ===================================================================================================
  local HR = {
    POS = 1445889390,              -- _icon_position_status_dmy01 (the position badge)
    ROLE = 260772049,              -- _icon_build_dmy01 (the archetype glyph; a coach / manager's role glyph)
    SUPPORT = 3892654168,          -- _icon_mark_dmy01 (the supporter mark)
    TX_ICON2 = 2058213660,         -- #/menu/200_icon/15_icon_common2/<LG>/icon_common2.g4tx
    SLOT_POS = 255392163,          -- icon_position_status_dmy01 (the badge's texture slot)
    FRAME = 2273809808,            -- _seasonal_frame01
    LV_NUM = 3434305008,           -- num_status_lv01
    PORTRAIT = 2531809341,         -- _icon_chr_status01 (the portrait icon)
    -- the band strip (a soccer11_04 plate showing only its two band sprites and / or its description box)
    BAND = {263290134, 2528652460},                                  -- _status_chr_base_s01 / _s02
    LOCS = {44923504, 1457835367, 2488990471, 606505850, 16246407, 2641657029},   -- _pos_lv01, _pos_rarity01,
    -- _pos_basara_offset01, _pos_title01, _pos_back01, _pos_name01
    MESHES = {3562698908, 2531809341, 1670039012, 260772049, 1445889390, 859963845, 893160232, 2606302476,
      3892654168, 2273809808, 1271316493},   -- portrait base / icon, locks, build, position, element, gender, mark,
    -- seasonal frame, nickname box
    TEXTS = {1704438437, 4238277407, 1006587362, 1768688116},       -- _text_name01 / 02, _text_grade01, _text_title01
    NUMS = {3434305008, 2189811683, 1894841872, 3984446132, 1372193137, 3589359157},   -- its 6 number settings
    OFF = {2531809341, 3562698908, 3892654168},                     -- portrait icon / base, mark: off screen
    EXPLAIN_POS = 3145402165,      -- _pos_explain01
    EXPLAIN_TEXT = 499981750,      -- _text_explain01
    -- the archetype box (a btl06_13 gauge frame copy)
    TX_BTL0613 = 1191797350, SP_FRAME = 538967808,
    BOX_HIDE = {1257514352, 2609329121, 2043683848},   -- _gtxt_stamina01, _hp_empty01, _hp_bar02
    posvis = {},                   -- "layer:inst" -> last visibility of the position badge
    rolevis = {},                  -- "layer:inst" -> last visibility of the archetype / role glyph
    moved = {},                    -- "layer:inst" -> true while the role glyph sits in the position slot
    home = {},                     -- "layer:inst" -> {x, y, z} layout translation of the glyph
  }
  U.HeaderRow = HR

  function HR.Key(layer, inst)
    return tostring(layer) .. ":" .. tostring(inst or 0)
  end

  -- a mesh-visibility call on a row (the menu-command filter of every VM forwards them: ui_clean_rarity_banner)
  function HR.Track(layer, mesh, on, inst)
    if mesh == HR.ROLE then
      HR.rolevis[HR.Key(layer, inst)] = on == true
    elseif mesh == HR.POS then
      HR.posvis[HR.Key(layer, inst)] = on == true
    end
  end

  -- the player's OWN position, ONE rule for every screen (header rows, position-coloured cards / bands): position
  -- icon types 0 GK, 1 DF, 2 MF, 3 FW (GetSoccerCharaPositionIconByPosIconType's argument).
  --   ParamType(param)  the card's main position: CMND_GET_CHARA_INFO(param, 11) (1 GK, 2 FW, 3 MF, 4 DF)
  --   NaturalType(hdl)  type, staff: a status whose CMND_GET_CHARA(hdl, 9) is a number outside 0..3 has no position
  --                     (coach / manager: nil, true); else his card's main position (hdl, 4 -> ParamType); else the
  --                     status' own (hdl, 9) when it is 0..3; else nil (unknown). (hdl, 9) is not a number for a status
  --                     outside the team (bank, lists), and a non-number given to the retail icon function is «0» = GK:
  --                     the card's position comes first (2026-10-13, the position_cards rule and the header's merged).
  --   Natural(hdl)      false, icon (a player and his badge sprite) / true (staff) / nil (unknown)
  HR.POS_TYPE_ICON = {[1] = 0, [2] = 3, [3] = 2, [4] = 1}
  C.CHARA_INFO = 4060384944

  function HR.ParamType(param)
    if type(param) ~= "number" or param == 0 then
      return nil
    end
    local okc, ok, t = pcall(funcLuaCommand, C.CHARA_INFO, param, 11)
    if not okc or ok == false or type(t) ~= "number" then
      return nil
    end
    return HR.POS_TYPE_ICON[t]
  end

  function HR.NaturalType(hdl)
    if type(hdl) ~= "number" or hdl == 0 then
      return nil
    end
    local ok9, t9 = pcall(funcLuaCommand, C.CHARA, hdl, 9)
    if ok9 and type(t9) == "number" and (t9 < 0 or t9 > 3) then
      return nil, true
    end
    local okp, param = pcall(funcLuaCommand, C.CHARA, hdl, 4)
    local t = okp and HR.ParamType(param) or nil
    if t ~= nil then
      return t
    end
    if ok9 and type(t9) == "number" then
      return t9
    end
    return nil
  end

  function HR.Natural(hdl)
    if type(GetSoccerCharaPositionIconByPosIconType) ~= "function" then
      return nil
    end
    local t, staff = HR.NaturalType(hdl)
    if staff then
      return true
    end
    if t == nil then
      return nil
    end
    local oki, icon = pcall(GetSoccerCharaPositionIconByPosIconType, t)
    if oki and type(icon) == "number" and icon ~= 0 then
      return false, icon
    end
    return nil
  end

  function HR.Badge(layer, inst, icon)
    if icon == nil then
      return false
    end
    return M(C.SPRITE, layer, HR.TX_ICON2, icon, HR.SLOT_POS, 0, inst or 0)
  end

  -- the rules after a status-plate fill of `hdl` on (layer, inst): o.natural ~= false: a player's badge shows his OWN
  -- position (team screens pass the SLOT's: «MC» for the striker standing there); o.role ~= false: the supporter mark
  -- off, a staff member's role glyph centred in the position slot when the badge is hidden, a player with a hidden
  -- badge gets his badge shown and his archetype glyph at home. Returns staff, icon.
  function HR.AfterFill(layer, inst, hdl, o)
    o = o or {}
    inst = inst or 0
    local staff, icon = o.staff, o.icon
    if o.staff == nil and o.known ~= true then          -- o.known: staff / icon given (nil = unknown character)
      staff, icon = HR.Natural(hdl)
    end
    local k = HR.Key(layer, inst)
    if o.natural ~= false and staff == false and icon ~= nil and HR.posvis[k] ~= false then
      HR.Badge(layer, inst, icon)
    end
    if o.role == false then
      return staff, icon
    end
    HR.moved[k] = false
    M(C.MESH, layer, HR.SUPPORT, false, inst)
    local home = HR.home[k]
    if home == nil then
      local ok, x, y, z = M(C.GET_TRANS, layer, inst, HR.ROLE)
      if not ok or type(x) ~= "number" or type(y) ~= "number" then
        return staff, icon
      end
      home = {x, y, z or 0}
      HR.home[k] = home
    end
    local L = U.Layout("header_row")
    local pw, ph = (L.pos_badge or {68, 46})[1], (L.pos_badge or {68, 46})[2]
    local rw = L.role_glyph or 40
    if HR.posvis[k] == false and staff == false and icon ~= nil then
      HR.Badge(layer, inst, icon)
      M(C.MESH, layer, HR.POS, true, inst)
      M(C.SET_TRANS, layer, inst, HR.ROLE, home[1], home[2], home[3])
    elseif HR.posvis[k] == false and staff == true then
      HR.moved[k] = true
      local ok, x, y, z = M(C.GET_TRANS, layer, inst, HR.POS)
      if ok and type(x) == "number" and type(y) == "number" then
        M(C.SET_TRANS, layer, inst, HR.ROLE, x + (pw - rw) / 2, y - (ph - rw) / 2, z or home[3])
      end
    else
      M(C.SET_TRANS, layer, inst, HR.ROLE, home[1], home[2], home[3])
    end
    return staff, icon
  end

  -- the archetype box rule: the box is the glyph's backdrop, shown exactly while the row's glyph is shown at home
  -- (a staff role glyph moved into the position slot leaves no box). nil = nothing recorded for the row (no rule).
  function HR.ArchBoxShown(layer, inst)
    local k = HR.Key(layer, inst)
    if HR.moved[k] == true then
      return false
    end
    local v = HR.rolevis[k]
    if v == nil then
      return nil
    end
    return v
  end

  -- a dual archetype: the pair command `cmd` (the caller's: Utilities' CMND_UTIL_PC_INFO) answers got, _, a, b
  function HR.Dual(hdl, cmd)
    if hdl == nil or cmd == nil then
      return false
    end
    local ok, got, _, a, b = pcall(funcLuaCommand, cmd, hdl)
    return ok and got == true and type(a) == "number" and type(b) == "number" and a >= 0 and a <= 5 and b >= 0
      and b <= 5 and a ~= b
  end

  -- the archetype glyph's slanted box on layer `tag` (a btl06_13 gauge copy, already open / set up by the caller),
  -- for the row (layer, inst) of `hdl`. o.sprite / o.sprite_dual = the box sprites (btl06_13 atlas), o.dual_cmd = the
  -- dual archetype pair command. st = the caller's cache table. Returns whether the box shows.
  function HR.ArchBox(tag, layer, inst, hdl, st, o)
    o = o or {}
    if HR.ArchBoxShown(layer, inst) == false then
      M(C.VIS, tag, 0, false)
      return false
    end
    local dual = HR.Dual(hdl, o.dual_cmd)
    if st.dual ~= dual then
      st.dual = dual
      local L = U.Layout("header_row").arch_box or {}
      local b = (dual and L.box_dual or L.box) or {1042, 175, 81, 40}
      local g = L.gauge or {94, 816, 476, 44}
      M(C.SPRITE, tag, HR.TX_BTL0613, dual and o.sprite_dual or o.sprite, HR.SP_FRAME, 0, 0)
      local sx, sy = b[3] / g[3], b[4] / g[4]
      M(C.SCALE, tag, sx, sy, 1, 0)
      M(C.POS, tag, b[1] - g[1] * sx, -b[2] + g[2] * sy, 0, 0)
    end
    M(C.VIS, tag, 0, true)
    return true
  end

  -- the box layer's own setup (once per open): only the frame mesh, the box sprite
  function HR.ArchBoxSetup(tag, o)
    for _, m in ipairs(HR.BOX_HIDE) do
      M(C.MESH, tag, m, false, 0)
    end
    M(C.SPRITE, tag, HR.TX_BTL0613, (o or {}).sprite, HR.SP_FRAME, 0, 0)
  end

  -- a status plate stripped to keep.band (its two band sprites) / keep.explain (the description box and text)
  function HR.Band(layer, inst, keep)
    inst, keep = inst or 0, keep or {}
    for _, n in ipairs(HR.LOCS) do
      M(C.NODE_VIS, layer, n, false, inst)
    end
    for _, m in ipairs(HR.MESHES) do
      M(C.MESH, layer, m, false, inst)
    end
    for _, t in ipairs(HR.TEXTS) do
      M(C.TEXT, layer, t, "", inst)
      M(C.TEXT_VIS, layer, t, false, inst)
      M(C.NODE_VIS, layer, t, false, inst)
    end
    for _, n in ipairs(HR.NUMS) do
      M(C.PRIM_VIS, layer, inst, n, false)
    end
    for _, n in ipairs(HR.OFF) do
      M(C.NODE_POS, layer, inst, n, 0, -5000)
    end
    for _, m in ipairs(HR.BAND) do
      M(C.MESH, layer, m, keep.band == true, inst)
    end
    M(C.NODE_VIS, layer, HR.EXPLAIN_POS, keep.explain == true, inst)
    if keep.explain ~= true then
      M(C.TEXT, layer, HR.EXPLAIN_TEXT, "", inst)
      M(C.NODE_VIS, layer, HR.EXPLAIN_TEXT, false, inst)
    end
    M(C.TEXT_VIS, layer, HR.EXPLAIN_TEXT, keep.explain == true, inst)
  end

  -- the slanted band of a row: the band copy filled with the row's player, in his POSITION colour (o.colour, default
  -- the position colour service a mod provides as EVT_PC_ColorStatusPlate), stripped to the band
  function HR.BandFill(band, inst, hdl, o)
    o = o or {}
    inst = inst or 0
    if hdl == nil or type(UpdateCharaStatusPlateInfoByCharaStHdl) ~= "function" then
      return false
    end
    pcall(UpdateCharaStatusPlateInfoByCharaStHdl, band, inst, hdl)
    local colour = o.colour or rawget(_ENV, "EVT_PC_ColorStatusPlate")
    if type(colour) == "function" then
      pcall(colour, band, inst, hdl)
    end
    HR.Band(band, inst, {band = true})
    return true
  end

  -- a row at scale s with its top-left at screen (x, y) (defaults: its layout place at scale 1)
  local function RowAt(s, x, y)
    local L = U.Layout("header_row")
    local o = L.row_origin or {957, 163}
    s = s or 1
    x, y = x or o[1], y or o[2]
    return s, x - o[1] * s, y - o[2] * s, x, y
  end

  function HR.Place(layer, inst, s, x, y)
    local k, dx, dy = RowAt(s, x, y)
    M(C.SCALE, layer, k, k, 1, inst or 0)
    M(C.POS, layer, dx, -dy, 0, inst or 0)
  end

  function HR.PlaceBand(band, inst, s, x, y)
    local k, dx, _, _, ry = RowAt(s, x, y)
    local B = U.Layout("header_row").band or {}
    local sx, sy = B.sx or 1, B.sy or 1 / 3
    M(C.SCALE, band, k * sx, k * sy, 1, inst or 0)
    M(C.POS, band, dx + (B.dx or 46) * k, -(ry - (B.y0 or 164) * sy * k), 0, inst or 0)
  end

  -- a named placement of [header_row.variants.<name>]: s, x, y
  function HR.Variant(name)
    local v = (U.Layout("header_row").variants or {})[name] or {}
    return v.s, v.x, v.y
  end

  function HR.Level(layer, inst, level)
    if type(level) ~= "number" or level <= 0 then
      return false
    end
    local ok, prim = M(C.PRIM_INDEX, layer, inst or 0, HR.LV_NUM)
    if ok and type(prim) == "number" then
      M(C.PRIM_SET, layer, inst or 0, prim, math.floor(level))
      M(C.PRIM_VIS, layer, inst or 0, HR.LV_NUM, true)
      return true
    end
    return false
  end

  function HR.PortraitOff(layer, inst)
    M(C.NODE_POS, layer, inst or 0, HR.PORTRAIT, 0, -5000)
  end

  -- ==== MovePlate ===================================================================================================
  local MP = {
    TX09 = 868271091,              -- #/menu/00_soccer/soccer11/soccer11_09/<LG>/soccer11_09.g4tx
    GREY = 3456853121,             -- cmd_base_sp06 (the neutral plate)
    SP1 = 1349513506,              -- cmd_base_sp01 (texture slot of _cmd_base_sp01; fallback plate)
    AT = 2395587060, DF = 2796898008,   -- gtxt_cmd_at01 / gtxt_cmd_df01
    FOCUS = 148027488,             -- _sp_list_focus01 (the plate's own focus frame)
    ARMED = 1206374040,            -- _gtxt_cmd_armed01
    AT_DMY = 365666709,            -- _num_at_cmd_dmy01 (the AT number's 24 x 24 placeholder: a white square)
    LOADING = 3057768039,          -- CMND_IS_LOADING_LAYER
    pending = {},                  -- "row:inst" -> {fn, row, inst, chara, move, o}: fills redone once the row is ready
    kept = {},                     -- "row:inst" -> {row, inst, move, armed, said}: plates whose state is held every frame
    IS_MESH_VIS = 2277921386,      -- CMND_IS_MESH_VISIBLE (layer, mesh, inst)
    SUB = 559600405,               -- _icon_sp_sub_dmy01 (the row's property badge slot: long / counter shot, block...)
    POS_BASE1 = 1517329426, POS_BASE2 = 3279539624,   -- _pos_base01 / _pos_base02 (plate / blank plate)
    POS_AT = 4081284803, POS_LOCK = 2244819350,       -- _pos_at01 / _pos_lock01
    PRIM_AT = 2467766246, PRIM_LOCK = 2330185550,
    TEXT = 3359986143,             -- _text_sp01
    FONT_DEFAULT = 368140940,
    AREA = 2164615260,             -- _icon_sp_area_dmy01 (the category icon)
    ICONS = {2164615260, 559600405, 1206374040},      -- category icon, sub icon, armed badge
    LOCK_ANIME = 908051707, ANIME_SET = 753088835,
    SLOT_ARG = 1803124851,         -- SetSkillItemLayerName's 4th argument (every caller's)
  }
  U.MovePlate = MP

  -- the move's place in the chara's match list (0..5), nil = not in it
  function MP.Pos(chara, move)
    if chara == nil or chara == 0 or move == nil or move == 0 then
      return nil
    end
    local ok, pos = pcall(funcLuaCommand, C.SKILL_POS, chara, move)
    if not ok or type(pos) ~= "number" or pos < 0 or pos >= 6 then
      return nil
    end
    return pos
  end

  -- pcall(f, ...) with the retail evolution lookup answering, for (chara, inst), the grade at the move's OWN place.
  -- The retail row fill (personal_plate_inc SetupCharaSkillItem: name glyph, graded font, AT power) reads the grade at
  -- skill_list[inst] = its row INSTANCE; a row drawing any move at any instance needs the move's place instead (not in
  -- the match list = grade 0). The global is restored afterwards.
  function MP.Graded(chara, move, inst, f, ...)
    local prev = GetSkillEvoLevelByCharaStHdl
    if type(prev) ~= "function" or move == nil or move == 0 then
      return pcall(f, ...)
    end
    local pos = MP.Pos(chara, move)
    GetSkillEvoLevelByCharaStHdl = function(h, p)
      if h == chara and p == inst then
        if pos == nil then
          return 0
        end
        return prev(h, pos)
      end
      return prev(h, p)
    end
    local r = table.pack(pcall(f, ...))
    GetSkillEvoLevelByCharaStHdl = prev
    return table.unpack(r, 1, r.n)
  end

  -- point the retail row fill at (row, page, ai) through o.set (default the global SetSkillItemLayerName)
  local function Point(o, row)
    local set = o.set or SetSkillItemLayerName
    local a = o.point                                   -- the screen's own 4th / 5th arguments (a recorded setting)
    set(row, o.page or 0, o.page_inst or 0, a and a[4] or MP.SLOT_ARG, a and a[5] or 0, o.blank or 0, o.ai or 0)
  end

  local function Restore(o)
    local set = o.set or SetSkillItemLayerName
    local r = o.restore or {nil, 0, 0, nil, nil, 0, 0}
    set(r[1], r[2], r[3], r[4], r[5], r[6], r[7])
  end

  -- opens the instance; true when it is not drawable yet (opened by this call, or its layer still loading)
  local function Open(o, row, inst)
    local fresh = funcLuaMenuCommand(C.IS_OPEN, row, inst) ~= true
    if type(o.open) == "function" then
      o.open(row, inst)
    elseif fresh then
      funcLuaMenuCommand(C.OPEN, row, inst)
    end
    return fresh or funcLuaMenuCommand(MP.LOADING, row) == true
  end

  -- 2026-10-13 (owner, Tabla de habilidades: a purple «Armadura» tag and a white square at the right of EVERY row plate):
  -- a layer instance opened in this frame (or still loading) does not keep mesh / number commands: the plate came up
  -- with its layout's defaults (the armed logo and the AT placeholder shown, no AT digits). Such a fill is queued and
  -- done again once the instance is ready: MovePlate.Pump() (the screens call it from their Step) redoes it; a later
  -- fill of the same instance replaces the queued one.
  local function Queue(fn, row, inst, chara, move, o)
    local q = {}
    for k, v in pairs(o) do
      q[k] = v
    end
    q.redo = true
    MP.pending[tostring(row) .. ":" .. tostring(inst)] = {fn = fn, row = row, inst = inst, chara = chara, move = move,
      o = q, frame = MP.frame, tries = 0}
  end

  -- step = true once a frame (the screen's Step): only a fill queued in an EARLIER frame is redone
  MP.frame = 0
  function MP.Pump(step)
    if step == true then
      MP.frame = MP.frame + 1
      if not MP.pumpSaid then
        MP.pumpSaid = true
        U.Log("move plate pump running", tostring(EVT_PATCH and EVT_PATCH.script or "?"))
      end
      pcall(MP.Keep)
    end
    for k, p in pairs(MP.pending) do
      if step == true then
        p.tries = p.tries + 1
      end
      if funcLuaMenuCommand(C.EXIST, p.row) ~= true or p.tries > 120 then
        MP.pending[k] = nil
      elseif p.frame < MP.frame and funcLuaMenuCommand(C.IS_OPEN, p.row, p.inst) == true
          and funcLuaMenuCommand(MP.LOADING, p.row) ~= true then
        MP.pending[k] = nil
        U.Log("move plate refill", p.row, p.inst, string.format("%08X", (p.move or 0) % 4294967296), "after", p.tries)
        pcall(p.fn, p.row, p.inst, p.chara, p.move, p.o)
      end
    end
  end

  -- 2026-10-13 (owner, second report: «Sigue saliendo lo de armadura, el cuadro blanco» with the refill installed): the
  -- row's own animation (the lock / AT clip the retail fill plays on every row) shows the armed logo and the AT
  -- number's placeholder again after any one-off hide (the player page hides that placeholder every frame for the
  -- same reason, plate_pages G.Moves). So the state of every filled plate is HELD: each frame (Pump(true)) the armed
  -- logo is set by its rule and the placeholder hidden while the instance is open. The first time a held mesh is
  -- found shown again it is logged («move plate keep <row> <inst> armed/dmy re-shown»), once per instance and fill.
  function MP.Keep()
    for k, e in pairs(MP.kept) do
      if funcLuaMenuCommand(C.EXIST, e.row) ~= true or funcLuaMenuCommand(C.IS_OPEN, e.row, e.inst) ~= true then
        MP.kept[k] = nil
      else
        local a = funcLuaMenuCommand(MP.IS_MESH_VIS, e.row, MP.ARMED, e.inst)
        local d = funcLuaMenuCommand(MP.IS_MESH_VIS, e.row, MP.AT_DMY, e.inst)
        local b = funcLuaMenuCommand(MP.IS_MESH_VIS, e.row, MP.SUB, e.inst)
        if not e.said and ((a == true) ~= (e.armed == true or MP.SecondBadge(e.row, e.inst)) or d == true
            or (b == true) ~= (e.sub == true)) then
          e.said = true
          U.Log("move plate keep", e.row, e.inst, string.format("%08X", (e.move or 0) % 4294967296),
            "armed shown", tostring(a), "want", tostring(e.armed), "dmy shown", tostring(d), "badge shown", tostring(b),
            "want", tostring(e.sub))
        end
        funcLuaMenuCommand(C.MESH, e.row, MP.ARMED, e.armed == true or MP.SecondBadge(e.row, e.inst), e.inst)
        funcLuaMenuCommand(C.MESH, e.row, MP.AT_DMY, false, e.inst)
        -- 2026-10-13 (owner: «Se ve el cuadrado blanco, si no tiene efecto no debería salir»): the property badge slot
        -- is held as the fill left it (shown only with a badge drawn: retail's / move_icons' first badge); the row's
        -- animation re-showed the empty slot (its white placeholder sprite) on moves without a property
        funcLuaMenuCommand(C.MESH, e.row, MP.SUB, e.sub == true, e.inst)
      end
    end
  end

  -- the graft move_icons draws a row's SECOND badge (a move with two properties: long + counter shot, a move and its
  -- also_as twin) on this same mesh (EVT_MI.armed[layer][inst] set while it does): the mesh stays shown then, else
  -- the held armed rule hid the 2nd badge every frame (owner 2026-10-13: Excálibur showed only «Tiro largo»)
  function MP.SecondBadge(row, inst)
    return EVT_MI ~= nil and type(EVT_MI.Get) == "function" and EVT_MI.armed ~= nil
      and EVT_MI.Get(EVT_MI.armed, row, inst) ~= nil
  end

  -- the «Armadura» logo: only an armed aura skill (retail IsAuraSkillKeshinArmed: SKILL_INFO 13 == 1) of the aura
  -- category (8); a move of any other category never shows it
  function MP.Armed(move)
    if move == nil or move == 0 then
      return false
    end
    return tonumber(MP.Info(move, 9)) == 8 and tonumber(MP.Info(move, 13)) == 1
  end

  -- one move plate on (row, inst): the retail SetupCharaSkillItem of the caller's row layer (a soccer11_09 row object),
  -- `chara`'s view of `move` (his element colour, his evolution grade of that move). Options:
  --   page / page_inst / ai / blank   SetSkillItemLayerName's layers for the fill (defaults 0); point = a recorded
  --            argument list whose 4th / 5th values are used (default 1803124851, 0)
  --   set      the function that points the fill (default SetSkillItemLayerName; a screen that wraps it passes the
  --            function under its wrapper)
  --   restore  the screen's own SetSkillItemLayerName arguments, set again after the fill
  --   grade    false: the retail grade lookup (skill_list[inst]); default the move's own grade (MP.Graded)
  --   focus    true keeps the plate's own focus frame; armed true / false forces the armed badge
  --   show     false leaves the layer's visibility to the caller; open = function(row, inst) opening the instance
  -- Returns ok, err (not ok: the instance hidden).
  function MP.Fill(row, inst, chara, move, o)
    o = o or {}
    inst = inst or 0
    if type(SetupCharaSkillItem) ~= "function" or funcLuaMenuCommand(C.EXIST, row) ~= true then
      return false, "no row"
    end
    local key = tostring(row) .. ":" .. tostring(inst)
    if o.redo ~= true and o.queued ~= true then
      MP.pending[key] = nil
    end
    if Open(o, row, inst) and o.redo ~= true and o.queued ~= true then
      Queue(MP.Fill, row, inst, chara, move, o)
    end
    -- 2026-10-13 (owner: Excálibur's row showed only «Tiro largo», not «contratiro»; loader.log «move_icons row
    -- 3A3634AD 3 2650954806 nil»): the move icons service (graft move_icons, EVT_MI) draws a row's SECOND badge only on
    -- layers whose geometry it knows (EVT_MI.GEOM). Every move plate is a soccer11_09 row: its layer is registered as
    -- such («b») before the fill, so a move with two properties shows both badges (MovePlate.SecondBadge keeps the
    -- mesh shown), one property one, none none. o.badge_geom = false: not registered; a string: that geometry.
    if o.badge_geom ~= false and type(EVT_MI) == "table" and type(EVT_MI.GEOM) == "table" and EVT_MI.GEOM[row] == nil then
      EVT_MI.GEOM[row] = type(o.badge_geom) == "string" and o.badge_geom or "b"
    end
    Point(o, row)
    local ok, err
    if o.grade == false then
      ok, err = pcall(SetupCharaSkillItem, chara, move or 0, inst, false)
    else
      ok, err = MP.Graded(chara, move, inst, SetupCharaSkillItem, chara, move or 0, inst, false)
    end
    Restore(o)
    if not ok then
      funcLuaMenuCommand(C.VIS, row, inst, false)
      return false, err
    end
    if o.focus ~= true then
      funcLuaMenuCommand(C.MESH, row, MP.FOCUS, false, inst)
    end
    local armed = o.armed
    if armed == nil then
      armed = MP.Armed(move)
    end
    funcLuaMenuCommand(C.MESH, row, MP.ARMED, armed == true or MP.SecondBadge(row, inst), inst)
    funcLuaMenuCommand(C.MESH, row, MP.AT_DMY, false, inst)
    -- the badge slot as the fill drew it (retail SetupCommandActionSkillInfoCategoryIcon + move_icons: shown only with a
    -- badge), held by Keep
    -- (with the move icons service, EVT_MI of the graft move_icons, its badge set decides: a common move none)
    local sub = move ~= nil and move ~= 0 and funcLuaMenuCommand(MP.IS_MESH_VIS, row, MP.SUB, inst) == true
    if move ~= nil and move ~= 0 and type(EVT_MI) == "table" and type(EVT_MI.Mask) == "function" then
      local okc, common = pcall(funcLuaCommand, EVT_MI.COMMON, move, chara or 0)
      local okm, mask = pcall(EVT_MI.Mask, move)
      sub = not (okc and common == true) and okm and type(mask) == "number" and mask > 0
    end
    MP.kept[key] = {row = row, inst = inst, move = move, armed = armed == true, sub = sub}
    if o.redo == true or o.log == true then
      U.Log("move plate fill", row, inst, string.format("%08X", (move or 0) % 4294967296), "armed", tostring(armed == true),
        "redo", tostring(o.redo == true), "badge", tostring(sub))
    end
    if o.show ~= false then
      funcLuaMenuCommand(C.VIS, row, inst, true)
    end
    return true
  end

  -- a list row's move plate: MP.Fill (shown by the caller) plus the row states. o (besides MP.Fill's):
  --   empty_text   the text of an empty slot (default «---»): the neutral grey plate, no icons, no AT
  --   locked, need a level-locked row: the grey plate, the name dimmed (o.lock_color markup), the retail move-row lock
  --                with the unlock level
  --   fixed        a fixed row (Prime / Idol learnset): the move's plate with the lock instead of the AT
  --   suffix       text after the name (a move on the board, not in the match list)
  --   name         the move's name (default MP.Name)
  -- Returns ok, err.
  function MP.Row(row, inst, chara, move, o)
    o = o or {}
    move = move or 0
    if type(SetupCharaSkillItem) ~= "function" or funcLuaMenuCommand(C.EXIST, row) ~= true then
      return false, "no row"
    end
    if o.redo ~= true then
      MP.pending[tostring(row) .. ":" .. tostring(inst)] = nil
    end
    if Open(o, row, inst) and o.redo ~= true then
      Queue(MP.Row, row, inst, chara, move, o)
    end
    -- the neutral plate first: the retail fill only sets an element plate for a move with an element
    funcLuaMenuCommand(C.SPRITE, row, MP.TX09, MP.GREY, MP.SP1, 0, inst)
    local f = {}
    for k, v in pairs(o) do
      f[k] = v
    end
    f.show = false
    f.queued = true                                     -- the Row queues itself (not its inner Fill)
    f.redo = o.redo
    local ok, err = MP.Fill(row, inst, chara, move, f)
    if not ok then
      return false, err
    end
    local empty = move == 0
    funcLuaMenuCommand(C.NODE_VIS, row, MP.POS_BASE1, true, inst)
    funcLuaMenuCommand(C.NODE_VIS, row, MP.POS_BASE2, false, inst)
    if empty or o.locked then
      funcLuaMenuCommand(C.SPRITE, row, MP.TX09, MP.GREY, MP.SP1, 0, inst)
    end
    if empty then
      for _, m in ipairs(MP.ICONS) do
        funcLuaMenuCommand(C.MESH, row, m, false, inst)
      end
      local kept = MP.kept[tostring(row) .. ":" .. tostring(inst)]
      if kept ~= nil then
        kept.sub = false
      end
      funcLuaMenuCommand(C.TEXT, row, MP.TEXT, o.empty_text or "---", inst)
      funcLuaMenuCommand(C.FONT, row, inst, MP.TEXT, MP.FONT_DEFAULT)
      funcLuaMenuCommand(C.NODE_VIS, row, MP.POS_AT, false, inst)
      funcLuaMenuCommand(C.PRIM_VIS, row, inst, MP.PRIM_AT, false)
    else
      funcLuaMenuCommand(C.MESH, row, MP.AREA, true, inst)
      local name = o.name or MP.Name(move)
      if o.locked then
        funcLuaMenuCommand(C.TEXT, row, MP.TEXT, (o.lock_color or "") .. name .. (o.lock_color and "[C]" or ""), inst)
      elseif o.suffix ~= nil then
        funcLuaMenuCommand(C.TEXT, row, MP.TEXT, name .. o.suffix, inst)
      end
    end
    local lock = o.locked == true or o.fixed == true
    local lv = o.locked and (tonumber(o.need) or 0) or 0
    if lock then
      funcLuaMenuCommand(C.ANIME, row, inst, MP.LOCK_ANIME, 0, MP.ANIME_SET)
      funcLuaMenuCommand(C.NODE_VIS, row, MP.POS_AT, false, inst)
      funcLuaMenuCommand(C.PRIM_VIS, row, inst, MP.PRIM_AT, false)
    end
    funcLuaMenuCommand(C.NODE_VIS, row, MP.POS_LOCK, lock, inst)
    if lv > 0 then
      local idx = funcLuaMenuCommand(C.PRIM_INDEX, row, inst, MP.PRIM_LOCK)
      if type(idx) == "number" and idx >= 0 then
        funcLuaMenuCommand(C.PRIM_SET, row, inst, idx, math.min(lv, 99))
      end
    end
    funcLuaMenuCommand(C.PRIM_VIS, row, inst, MP.PRIM_LOCK, lock and lv > 0)
    funcLuaMenuCommand(C.MESH, row, MP.FOCUS, false, inst)
    return true
  end

  function MP.Info(move, field, ...)
    local okc, ok, v = pcall(funcLuaCommand, C.SKILL_INFO, move, field, ...)
    if okc and ok then
      return v
    end
    return nil
  end

  function MP.Name(move)
    local id = MP.Info(move, 4)
    if id ~= nil then
      local ok, s = pcall(funcLuaCommand, C.NAME_TEXT, id)
      if ok and type(s) == "string" and s ~= "" then
        return s
      end
    end
    return ""
  end

  -- the plate's element sprite (personal_plate_inc SetupSkillItemBaseTexture's rule for a move: its element 1..6, a
  -- common move = 6, GetSkillCommandElementIcon -> cmd_base_sp0N)
  function MP.PlateSprite(move)
    local el = tonumber(MP.Info(move, 7)) or 0
    local okc, ok, common = pcall(funcLuaCommand, C.COMMON_SKILL, move)
    if el == 5 and okc and ok and common then
      el = 6
    end
    if el < 1 or el > 6 then
      el = 6
    end
    if type(GetSkillCommandElementIcon) == "function" then
      local okg, spr = pcall(GetSkillCommandElementIcon, el)
      if okg and type(spr) == "number" and spr ~= 0 then
        return spr
      end
    end
    return MP.SP1
  end

  -- ---- the TENSIÓN gauge next to a move plate (a team02_02 tension group: 10 squares _tension_on01..10, the cost
  -- number, its 24 x 24 placeholder, the locator _pos_tension01). ONE copy for the Tabla de habilidades' Hiper /
  -- miximax rows, the Ficha's Hiper page (spirit move, fusion rows) and the PEG pool gauges.
  MP.TENS = {
    ON = {3023202814, 758855748, 1513883858, 3294141809, 3009392103, 710343773, 1565641931, 3454980442, 3135889868,
      3660474409},                 -- _tension_on01..10
    LOC = 923022909,               -- _pos_tension01
    PRIM = 3424269865,             -- the cost number's setting
    DMY = 661115862,               -- _num_tension_dmy01 (the number's placeholder: a lighter box under the last digit)
    SCALE = 3413028567,            -- (team info, true) -> ok, the team's tension scale
  }

  -- the retail formula: lit squares = cost / scale x 10 (at least 1, at most 10); no scale = none
  function MP.Steps(cost, scale)
    if type(cost) ~= "number" or type(scale) ~= "number" or scale <= 0 then
      return 0
    end
    return math.min(10, math.max(1, math.floor(cost / scale * 10 + 0.5)))
  end

  -- the first tension scale the given teams answer (a table.pack: nil entries are skipped). Team 255 with the flag set
  -- answers the menus' global scale (handler 0xC2C150, what the retail menus get outside a match)
  function MP.TensionScale(teams)
    teams = teams or {255, n = 1}
    for i = 1, teams.n or #teams do
      local ti = teams[i]
      if ti ~= nil then
        local okc, ok, sc = pcall(funcLuaCommand, MP.TENS.SCALE, ti, true)
        if okc and ok and type(sc) == "number" and sc > 0 then
          return sc
        end
      end
    end
    return nil
  end

  -- the gauge of `cost` on (L, inst): o.scale (a PEG / SP pool) or the first scale of o.teams; o.steps forces the
  -- lit squares; o.look(L, inst) runs after the locator is shown (a PEG / SP tint: showing the locator shows its meshes
  -- again). No cost (not a number): the locator off. Returns steps, scale (nil without a cost).
  function MP.Tension(L, inst, cost, o)
    o = o or {}
    inst = inst or 0
    local T = MP.TENS
    if type(cost) ~= "number" then
      funcLuaMenuCommand(C.NODE_VIS, L, T.LOC, false, inst)
      return nil
    end
    local scale = o.scale or MP.TensionScale(o.teams)
    local steps = o.steps or MP.Steps(cost, scale)
    for i = 1, 10 do
      funcLuaMenuCommand(C.MESH, L, T.ON[i], i <= steps, inst)
    end
    local idx = funcLuaMenuCommand(C.PRIM_INDEX, L, inst, T.PRIM)
    funcLuaMenuCommand(C.PRIM_SET, L, inst, idx, math.floor(cost + 0.5))
    funcLuaMenuCommand(C.PRIM_VIS, L, inst, T.PRIM, true)
    funcLuaMenuCommand(C.NODE_VIS, L, T.LOC, true, inst)
    if type(o.look) == "function" then
      pcall(o.look, L, inst)
    end
    funcLuaMenuCommand(C.MESH, L, T.DMY, false, inst)
    return steps, scale
  end

  -- no gauge at all: squares and number off too (they outlive a hidden locator)
  function MP.TensionOff(L, inst)
    inst = inst or 0
    for i = 1, 10 do
      funcLuaMenuCommand(C.MESH, L, MP.TENS.ON[i], false, inst)
    end
    funcLuaMenuCommand(C.PRIM_VIS, L, inst, MP.TENS.PRIM, false)
    funcLuaMenuCommand(C.NODE_VIS, L, MP.TENS.LOC, false, inst)
  end

  -- the plate's data for a screen that draws it from quads (no retail row fill in its VM): plate / category / label
  -- sprites, the name, the power at `chara`'s grade of the move (retail SetupSkillItemPowerPrim: SKILL_INFO(move, 6,
  -- chara, grade)); label = AT for categories 1 / 2, DF for 3 / 4, none otherwise.
  function MP.Look(move, chara)
    local cat = tonumber(MP.Info(move, 9)) or 0
    local catSprite = nil
    if type(GetSkillCategoryIcon) == "function" then
      local ok, spr = pcall(GetSkillCategoryIcon, cat, move, chara)
      if ok and type(spr) == "number" and spr ~= 0 then
        catSprite = spr
      end
    end
    local grade = 0
    local pos = MP.Pos(chara, move)
    if pos ~= nil and type(GetSkillEvoLevelByCharaStHdl) == "function" then
      local ok, g = pcall(GetSkillEvoLevelByCharaStHdl, chara, pos)
      grade = (ok and type(g) == "number") and g or 0
    end
    local power = nil
    if chara ~= nil and chara ~= 0 then
      power = tonumber(MP.Info(move, 6, chara, grade))
    end
    if power == nil then
      power = tonumber(MP.Info(move, 6))
    end
    local label = nil
    if cat == 1 or cat == 2 then
      label = MP.AT
    elseif cat == 3 or cat == 4 then
      label = MP.DF
    end
    return {plate = MP.PlateSprite(move), category = catSprite, label = label, name = MP.Name(move), power = power,
      grade = grade}
  end
end
