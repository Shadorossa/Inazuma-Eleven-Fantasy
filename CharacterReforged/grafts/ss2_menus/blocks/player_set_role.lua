-- ===================================================================================================
-- 2026-09-24: the original board screen is gone (docs/game/skill-board-original.md §8). Its button is now "Set de
-- jugador" (per-player builds: moves + Hiper + Equipamiento items + custom passive); Alt (CMD_FUNC1) does nothing.
-- A 4th square button = the ROLE badge; its picker shows the board's three badge slots in a row (none / coach /
-- manager). The custom-passive button opens the retail six-sense equip menu. All state lives in PL fields (main chunk
-- at the 200-locals limit).
-- ===================================================================================================
PL.L_BTN_ROLE = 2356951558
PL.L_ROLE_OPT = 3990407289       -- 3 badge tiles (layer with no focus; input read here)
PL.ROW_ICON_ROLE = 11
PL.ROLE_ITEM = {[1] = 2607368153, [2] = 3966662479}   -- coach / manager badge items
-- 2026-09-28: every string of the role picker and of «Set de jugador» is a menu_text row in the 9 languages
-- (research/scripts/ss2_popup_text_build.py; `--lua` prints this table, a dry run checks it against the graft).
-- Retail rows: BTN_SAVE «Guardar», BTN_BACK «Volver», BTN_SELECT «Elegir», PASSIVE «Pasiva personalizada».
-- (built in a function: 88 more constants in the main chunk pushed the key of PL.SS_ITEMS past RK 255, and the
-- assembler's decompile round trip no longer recognised that table constructor)
function PL.TxTable()
  return {
  ASK_DEL = 23924234, -- evt_pl_ask_del
  ASK_NAME = 2124515251, -- evt_pl_ask_name
  ASK_OVER = 2491308780, -- evt_pl_ask_over
  BTN_BACK = 430212020, -- retail
  BTN_DELETE = 2692191470, -- evt_pl_btn_delete
  BTN_LOAD = 509719926, -- evt_pl_btn_load
  BTN_REMOVE = 3961481199, -- retail
  BTN_RENAME = 1140374567, -- evt_pl_btn_rename
  BTN_RESET = 108624977, -- retail
  BTN_SAVE = 2306442081, -- retail
  BTN_SELECT = 2563379934, -- retail
  EXPORT_DESC = 10942846, -- evt_pl_export_desc
  EXPORT_DONE = 457094529, -- evt_pl_export_done
  EXPORT_EMPTY = 3010979655, -- evt_pl_export_empty
  EXPORT_FAIL = 2369027683, -- evt_pl_export_fail
  IMPORT_BAD = 3066746244, -- evt_pl_import_bad
  IMPORT_DESC = 3409649941, -- evt_pl_import_desc
  IMPORT_DONE = 3500371434, -- evt_pl_import_done
  IMPORT_GUIDE = 3414505662, -- evt_pl_import_guide
  IMPORT_NONE = 3206450574, -- evt_pl_import_none
  IMPORT_OTHER = 3628321451, -- evt_pl_import_other
  IMPORT_SKIP = 955832380, -- evt_pl_import_skip
  IMPORT_SUM = 4233917234, -- evt_pl_import_sum
  KB_FAIL = 510371056, -- evt_pl_kb_fail
  KB_TITLE = 2568175564, -- evt_pl_kb_title
  LOADED_SKIP = 170151676, -- evt_pl_loaded_skip
  LOADER = 2110802885, -- evt_pl_loader
  PASSIVE = 498819128, -- retail
  PV_SLOT = 3386648423, -- evt_pl_pv_slot
  PV_TITLE = 726903404, -- evt_pl_pv_title
  ROLE_0 = 182412289, -- evt_pl_role_0
  ROLE_1 = 2111329431, -- evt_pl_role_1
  ROLE_2 = 3838903597, -- evt_pl_role_2
  ROLE_DESC_0 = 3708853662, -- evt_pl_role_desc_0
  ROLE_DESC_1 = 2853678344, -- evt_pl_role_desc_1
  ROLE_DESC_2 = 857668786, -- evt_pl_role_desc_2
  ROLE_EFF_0 = 2303575434, -- evt_pl_role_eff_0
  ROLE_EFF_1 = 4266325276, -- evt_pl_role_eff_1
  ROLE_EFF_2 = 1732486310, -- evt_pl_role_eff_2
  ROLE_FAIL = 3191266877, -- evt_pl_role_fail
  ROLE_GUIDE = 2647548901, -- evt_pl_role_guide
  ROLE_NOREC = 1332833930, -- evt_pl_role_norec
  ROLE_NOW = 1480268909, -- evt_pl_role_now
  ROLE_STORY = 3154551016, -- evt_pl_role_story
  ROLE_TITLE = 2087115963, -- evt_pl_role_title
  SET_BTN = 2135514294, -- evt_pl_set_btn
  SET_BTN_GUIDE = 3362243025, -- evt_pl_set_btn_guide
  SET_EMPTY = 2056799810, -- evt_pl_set_empty
  SET_EXPORT_ROW = 1908066842, -- evt_pl_set_export_row
  SET_GUIDE = 3636575411, -- evt_pl_set_guide
  SET_HINT_1 = 561136091, -- evt_pl_set_hint_1
  SET_HINT_2 = 3095072865, -- evt_pl_set_hint_2
  SET_IMPORT_ROW = 2379296170, -- evt_pl_set_import_row
  SET_N = 3829380039, -- evt_pl_set_n
  SET_OLD = 358596258, -- evt_pl_set_old
  SKIP_FAIL = 740587531, -- evt_pl_skip_fail
  SKIP_IDOL = 618007856, -- evt_pl_skip_idol
  SKIP_INUSE = 2054247591, -- evt_pl_skip_inuse
  SKIP_LOCKED = 3674165083, -- evt_pl_skip_locked
  SKIP_NOTOWN = 3318853735, -- evt_pl_skip_notown
  SKIP_PRIME = 3425905848, -- evt_pl_skip_prime
  SKIP_ROW = 2368727989, -- evt_pl_skip_row
  SIG_GUIDE = 3646435247, -- evt_pl_sig_guide
  SIG_NONE = 3588279511, -- evt_pl_sig_none
  SS_BTN_EQUIPPED = 3181239823, -- evt_pl_ss_btn_equipped
  SS_BTN_GUIDE = 2616371171, -- evt_pl_ss_btn_guide
  SS_GUIDE = 374095222, -- evt_pl_ss_guide
  SS_NONE = 2070383841, -- evt_pl_ss_none
  SS_QUIT = 1197300667, -- evt_pl_ss_quit
  SUM_EQUIP = 1859211264, -- evt_pl_sum_equip
  SUM_HIPER = 1201407754, -- evt_pl_sum_hiper
  SUM_MIX = 294335918, -- evt_pl_sum_mix
  SUM_MOVES = 3650984834, -- evt_pl_sum_moves
  SUM_PASSIVE = 4213968171, -- evt_pl_sum_passive
  }
end
PL.TX = PL.TxTable()
PL.ROLE_TX = {[0] = PL.TX.ROLE_0, [1] = PL.TX.ROLE_1, [2] = PL.TX.ROLE_2}
PL.ROLE_DESC_TX = {[0] = PL.TX.ROLE_DESC_0, [1] = PL.TX.ROLE_DESC_1, [2] = PL.TX.ROLE_DESC_2}
PL.ROLE_EFF_TX = {[0] = PL.TX.ROLE_EFF_0, [1] = PL.TX.ROLE_EFF_1, [2] = PL.TX.ROLE_EFF_2}

-- menu_text row (CMND_TEXT_GET) with <VALUE> replaced; "" when the row is missing (text files not installed)
function PL.Txt(id, value)
  local ok, s = pcall(funcLuaCommand, @crc:CMND_TEXT_GET@, id)
  if not ok or type(s) ~= "string" then
    s = ""
  end
  if type(value) == "table" then
    for tag, v in pairs(value) do
      local text = tostring(v)
      s = string.gsub(s, "<" .. tag .. ">", function()
        return text
      end)
    end
  elseif value ~= nil then
    local v = tostring(value)
    s = string.gsub(s, "<VALUE>", function()
      return v
    end)
  end
  return s
end

function PL.RoleName(r)
  return PL.Txt(PL.ROLE_TX[r] or PL.TX.ROLE_0)
end
PL.TEX_BADGE = 1461205148                       -- #/menu/102_team/team13/team13_05c/team13_05c.g4tx (board badge slot)
PL.BADGE_SPR = {[0] = 1212007845, [1] = 2386695893, [2] = 2633480507}
PL.BTN_SLOTS = {0x68DA0494, 0x060694A0}         -- cmn03_07 base quads (off / on + add): texture-slot hashes
PL.ICON_NODE = 3165767436       -- mesh of the row-layer icon
PL.ICON_TEX = 3234721532                        -- icon_teambuff_dmy01 (texture slot of that mesh)
PL.SUBWIN_TEXT = 2315959435                     -- 0x8A0ABC8B (row 0.., string)
PL.SUBWIN_POS = 63483614
PL.ADD_ITEM = @crc:CMND_ADD_ITEM_ONLY@                        -- (item, count, flag)
PL.DEL_ITEM = @crc:CMND_DELETE_ITEM@                         -- (item, count)
PL.ITEM_NUM = @crc:CMND_GET_ITEM_NUM@                        -- (item)
PL.EQUIPPED_NUM = 556568075                     -- (invHdl) -> copies equipped (retail equip list)
PL.REMOVE_EQUIP = @crc:CMND_REMOVE_EQUIP@                     -- (chara, type)
PL.EQUIP_ITEM = @crc:CMND_EQUIP_ITEM@                       -- (chara, invHdl, type)
PL.SIX_MENU = 3858305496        -- retail "Pasiva personalizada" equip menu (menu registry row)
PL.SETS = 5
PL.role_frames = 0
PL.role_shown = nil
PL.role_open = false

-- CMND_CHARACTERREFORGED_GET_ROLE -> role (0 none, 1 coach, 2 manager, 3 unresolved badge, -5 not a saved player; -1 = no loader),
-- native (creation-time staff bit: 1 coach / 2 manager, e.g. the story protagonist Destin Billows), lock (1 = story copy)
function PL.Role()
  local ok, r, _, _, native, lock = pcall(funcLuaCommand, @crc:CMND_CHARACTERREFORGED_GET_ROLE@, n)
  if not ok or type(r) ~= "number" then
    return -1, 0, 0
  end
  return r, type(native) == "number" and native or 0, type(lock) == "number" and lock or 0
end

-- 2026-09-30 (Destin Billows): the picker never refuses silently. Every refusal names its reason: no loader, not a
-- saved player, a story-mode copy (its role belongs to the story), or the loader status of a failed change.
function PL.RoleWhy(r, lock)
  if r == -1 then
    return PL.Txt(PL.TX.LOADER)
  elseif lock == 1 then
    return PL.Txt(PL.TX.ROLE_STORY)
  elseif r < 0 then
    return PL.Txt(PL.TX.ROLE_NOREC)
  end
  return nil
end

-- badge icon on the role button: the board's badge slot sprite for the current role
function PL.RoleIcon()
  local k = PL.ROW_ICON_ROLE
  local r = PL.Role()
  -- v3: slot plate on _teambuff_base01 + the badge item's medal on the icon node (as the board's badge piece)
  EVT_ButtonIcon(k, PL.TEX_ITEM01, PL.ROLE_ITEM[r] or PL.ROLE_ITEM[1])
  funcLuaMenuCommand(C.MESH_VISIBLE, L_PV_ROW, 3877027080, true, k)
  funcLuaMenuCommand(C.SPRITE, L_PV_ROW, PL.TEX_BADGE, PL.BADGE_SPR[r] or PL.BADGE_SPR[0], PL.PLATE_SLOT, 0, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_PV_ROW, PL.ICON_NODE, PL.ROLE_ITEM[r] ~= nil, k)
  funcLuaMenuCommand(C.TEXT, PL.L_BTN_ROLE, 950238781 --[[_text_btn01]], "", 0)
  funcLuaMenuCommand(C.TEXT, PL.L_BTN_ROLE, 625330766 --[[_text_cmd01]], "", 0)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_PV_ROW, k, not evt_pv_open and not PL.role_open)
  return r
end

function PL.Guide(t)
  funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], t, 0)
end

function PL.RoleGuide()
  local r, _, lock = PL.Role()
  PL.Guide(PL.RoleWhy(r, lock) or PL.Txt(PL.TX.ROLE_NOW, PL.RoleName(r)))
end

function PL.Pick(rows, init)
  return PL.List("", rows, init)
end

-- ---- our own list window (v3) ----------------------------------------------------------------------------------------
-- The retail sub window could not be used from this menu: in game it opened clipped off the left edge whatever
-- position was sent, and its row texts landed on our move rows. Our list = the "Pasivas de la rama" panel (own layers
-- evt_passive_panel + the passive row clone, 9 rows, centred, dim background): header = title, rows = strings, the
-- selected row marked "▶" and fully opaque, up/down scroll through longer lists, Aceptar = choose, back = -1.
PL.LIST_ROWS = 9
function PL.ListShow(show, title, rows, first, sel)
  for k = 0, EVT_BG_COUNT - 1 do
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_BLACKBG, k, show)
    if show then
      funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, L_BLACKBG, k, 3371859161, 0, 753088835 --[[Default]])
    end
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_PV_PANEL, 0, show)
  for k = 0, PL.LIST_ROWS - 1 do
    local i = first + k
    local t = show and rows[i + 1] or nil
    if t ~= nil then
      local L = L_PV_ROW
      EVT_Row_Reset(k)
      funcLuaMenuCommand(C.SPRITE, L, EVT_TEX_SOCCER11_20, 1729678359 --[[passive_base01]], 1729678359, 0, k)
      funcLuaMenuCommand(C.TEXT, L, 1868134834 --[[_text_passive01]], (i == sel and "▶  " or "     ") .. t, k)
      pcall(funcLuaMenuCommand, C.TEXT_ALPHA, L, k, 1868134834, i == sel and 1 or 0.55)
    end
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_PV_ROW, k, t ~= nil)
  end
  if show then
    local more = #rows > PL.LIST_ROWS and "   " .. PL.Txt(2544447647 --[[skill_table_list_range]],
      {FIRST = first + 1, LAST = math.min(#rows, first + PL.LIST_ROWS), TOTAL = #rows}) or ""
    funcLuaMenuCommand(C.TEXT, L_PV_PANEL, 760999068 --[[_text_page01]], title .. more, 0)
  end
end

function PL.List(title, rows, init)
  local sel = math.max(0, math.min(#rows - 1, init or 0))
  local first = math.max(0, math.min(sel, #rows - PL.LIST_ROWS))
  evt_pv_open = true
  PL.ListShow(true, title, rows, first, sel)
  coroutine.yield()
  local function key(k)
    return funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, EVT_MENU_CTRL, k)
      or funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]], k)
  end
  local result = -1
  local P = PL.PtrStart()
  while true do
    coroutine.yield()
    local pact, pfirst, psel, owns = PL.PtrStep(P, L_PV_ROW, PL.LIST_ROWS, PL.PTR_PV, first, sel, #rows)
    if key(EVT_CMD_BACK) then
      funcLuaCommand(C.SE, SE_BACK)
      break
    elseif pact == "pick" or (not owns and (key(EVT_CMD_ENTER) or key(1651523701 --[[CMD_ENTER_CLICK]]))) then
      funcLuaCommand(C.SE, SE_DECIDE)
      result = pact == "pick" and psel or sel
      break
    elseif key(EVT_CMD_DOWN) and sel < #rows - 1 then
      sel = sel + 1
      if sel >= first + PL.LIST_ROWS then
        first = first + 1
      end
      funcLuaCommand(C.SE, 2500047763 --[[sy0005 cursor]])
      PL.ListShow(true, title, rows, first, sel)
    elseif key(EVT_CMD_UP) and sel > 0 then
      sel = sel - 1
      if sel < first then
        first = first - 1
      end
      funcLuaCommand(C.SE, 2500047763)
      PL.ListShow(true, title, rows, first, sel)
    elseif pact == "moved" then
      first, sel = pfirst, psel
      funcLuaCommand(C.SE, 2500047763)
      PL.ListShow(true, title, rows, first, sel)
    end
  end
  PL.ListShow(false, title, rows, first, sel)
  evt_pv_open = false
  coroutine.yield()                              -- the closing input must not reach our menu
  EVT_RefreshRows()
  evt_icon_frames = math.max(evt_icon_frames, 3)
  PL.role_frames = math.max(PL.role_frames, 3)
  return result
end

-- ---- role picker (v5, 2026-09-28): the retail list window ---------------------------------------------------------
-- User: the floating badge tiles and the debug-like guide line looked out of place. The picker is now the same retail
-- window as the custom-passive picker (board picker list frame team08_01 = layer evt_ss_list, rows
-- team08_02_ability_list_item, the blue backdrop over the left column): 3 rows «Sin rol / Entrenador / Gerente», each
-- with the board's badge piece (slot plate on _icon_sp_area_dmy01, the badge item's medal on _icon_sixth_dmy01) and the
-- retail check mark on the current role. The focused role is shown in the integrated panel on the right (band, the
-- medal as the big icon, name, one-line description + what the role does: coach / manager slot). Guide line = one
-- sentence; the retail button guide shows <CMD_ENTER> Elegir and <CMD_BACK> Volver. Texts: PL.TX (menu_text, 9
-- languages). The old tile layers (evt_role_badge, evt_cmn03_07_role_opt) stay in the setting, always hidden.
PL.L_BADGE = 3849871607
PL.TEX_ITEM01 = 2868599811                      -- #/menu/200_icon/02_icon_item/icon_item01.g4tx
PL.PLATE_SLOT = 2597149412                      -- teambuff_base01 (texture slot of _teambuff_base01)
PL.SLOT_AREA = 566439826                        -- icon_sp_area_dmy01 (texture slot; list row 50 px, panel 170 px)
PL.SLOT_SIXTH = 669321680                       -- icon_sixth_dmy01 (texture slot; list row 38 px, inside the 50 px one)
PL.MESH_AREA = 2164615260                       -- _icon_sp_area_dmy01
PL.MESH_SIXTH = 2384755812                      -- _icon_sixth_dmy01
PL.BAND_ROLE = {[0] = 6, [1] = 5, [2] = 5}               -- PL.BAND index: grey for none, purple (no element motif) for staff
-- retail button guide (equip_menu_inc UpdateEquipButtonGuide: texts, icons, offsets; then the commands)
-- (one assignment per line: a multiple assignment at main level broke the assembler's decompile round trip)
PL.K_ENTER = 1981080283
PL.K_BACK = 3011112225
PL.K_FUNC1 = 637335895
PL.K_FUNC3 = 3421673595
PL.K_FUNC4 = 1435897304
PL.I_ENTER = 2750714971                         -- <CMD_ENTER>
PL.I_BACK = 1582778933                          -- <CMD_BACK>
PL.I_FUNC1 = 203473330                          -- <CMD_FUNC1>
PL.I_FUNC3 = 3794706590                         -- <CMD_FUNC3>
PL.I_FUNC4 = 2085238077                         -- <CMD_FUNC4>

function PL.GuideKeys(keys)
  local t, i, o, c = {}, {}, {}, {}
  for k, e in ipairs(keys) do
    t[k], i[k], o[k], c[k] = e.text, e.icon, k == 1 and 0 or 18, e.cmd
  end
  funcLuaMenuCommand(2209673388, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], t, i, o)
  funcLuaMenuCommand(452337289, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], c)
end

function PL.Key(k)
  return funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, EVT_MENU_CTRL, k)
    or funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]], k)
end

-- the integrated panel without the move parts (the look of the custom passive's fallback): band, name, description,
-- optionally the big icon (170 px, _icon_sp_area_dmy01) drawn by `icon(L)`. opts.banner: the compact card (mode
-- "plain"): the band as the card's banner with the icon 64 px and the name on it, the description under it.
function PL.PanelPlain(band, name, desc, icon, opts)
  if not funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L_DETAIL) then
    return
  end
  PL.DetailHideAll()
  for _, pos in ipairs(PL.DETAIL_MOVE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL, pos, false, 0)
  end
  for _, mesh in ipairs(PL.DETAIL_MOVE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, mesh, false, 0)
  end
  for _, t in ipairs(PL.DETAIL_MOVE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, t, false, 0)
  end
  for _, pr in ipairs(PL.DETAIL_MOVE_PRIM) do
    funcLuaMenuCommand(1233047821 --[[number visible]], L_DETAIL, 0, pr, false)
  end
  for i = 1, 10 do
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, CALC_CRC(string.format("_tension_on%02d", i)), false, 0)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 1125548721 --[[_sp_base01]], true, 0)
  funcLuaMenuCommand(C.SPRITE, L_DETAIL, PL.PARTS_TEX, PL.BAND[band] or PL.BAND[5], 243934124 --[[sp_base01]], 0, 0)
  funcLuaMenuCommand(C.TEXT, L_DETAIL, 1704438437 --[[_text_name01]], name, 0)
  funcLuaMenuCommand(C.TEXT, L_DETAIL, 691026122 --[[_text_flavor01]], desc, 0)
  if icon ~= nil and pcall(icon, L_DETAIL) then
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, PL.MESH_AREA, true, 0)
  end
  if opts ~= nil and opts.banner then
    funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, 1704438437 --[[_text_name01]], true, 0)
    funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, 691026122 --[[_text_flavor01]], desc ~= "", 0)
    pcall(PL.SetDetailLayout, "plain")
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_DETAIL, 0, true)
  evt_detail_on = true
end

-- A list in the retail window with guide keys: mode = {row = fn(k, e, sel), focus = fn(e), guide = text,
-- keys = fn(e) -> {{text, icon, cmd, act}, ...}, act = fn(act, e, i) -> "close" | "stay" (may yield: messages),
-- refresh = fn() -> new list (after "stay")}. Returns the index (0-based) and the act that closed it, or -1.
-- 2026-10-13: a mode may bring its own frame / rows (PL.ListLayers): list_layer, row_layer, rows (visible rows),
-- ptr (pointer rect {x, w, h} of a row); default = the shared evt_ss_list / team08_02 rows (PL.SSROWS, PL.PTR_SS).
function PL.ListLayers(mode)
  mode = mode or {}
  return mode.list_layer or PL.L_SSLIST, mode.row_layer or PL.L_SSROW, mode.rows or PL.SSROWS, mode.ptr or PL.PTR_SS
end

-- the row Up / Down goes to (nil = none): mode.vert(list, sel, dir) may answer an index or false (stay), nil = the
-- next / previous row (2026-10-13: two entries drawn side by side on one row, «Exportar set | Importar set»)
function PL.ListVert(mode, list, sel, dir)
  if mode ~= nil and mode.vert ~= nil then
    local to = mode.vert(list, sel, dir)
    if to == false then
      return nil
    elseif type(to) == "number" then
      return to
    end
  end
  local to = sel + dir
  if to < 0 or to > #list - 1 then
    return nil
  end
  return to
end

function PL.PopList(list, init, mode)
  local _, RL, NR, PR = PL.ListLayers(mode)
  local sel = math.max(0, math.min(#list - 1, init or 0))
  local first = math.max(0, math.min(sel, #list - NR))
  local keys = {}
  local function show()
    PL.list_mode = mode
    PL.SSListShow(true, list, first, sel)
    keys = mode.keys(list[sel + 1]) or {}
    pcall(PL.GuideKeys, keys)
  end
  show()
  coroutine.yield()
  local result, act = -1, nil
  local P = PL.PtrStart()
  while true do
    coroutine.yield()
    local pact, pfirst, psel, owns = PL.PtrStep(P, RL, NR, PR, first, sel, #list)
    if pact == "pick" and (psel ~= sel or PL.ptr_resync) then
      PL.ptr_resync = nil
      first, sel = pfirst, psel                    -- the clicked row first (its keys / act)
      show()
    end
    if mode.tick ~= nil then
      pcall(mode.tick)                             -- 2026-10-13: per-frame upkeep (the split set row's geometry)
    end
    local hit = nil
    for _, kk in ipairs(keys) do
      local enter = kk.cmd == PL.K_ENTER
      if kk.act ~= nil and ((enter and pact == "pick")
          or (not (enter and owns) and (PL.Key(kk.cmd) or (enter and PL.Key(1651523701 --[[CMD_ENTER_CLICK]]))))) then
        hit = kk
        break
      end
    end
    local side = nil
    if hit == nil and mode.side ~= nil then
      side = mode.side(list, sel)                  -- 2026-10-13: left / right between two entries of one row
    end
    if PL.Key(EVT_CMD_BACK) then
      funcLuaCommand(C.SE, SE_BACK)
      break
    elseif side ~= nil then
      sel = side
      first = math.max(0, math.min(first, sel))
      if sel >= first + NR then
        first = sel - NR + 1
      end
      funcLuaCommand(C.SE, 2500047763 --[[sy0005 cursor]])
      show()
    elseif hit ~= nil then
      local r = mode.act(hit.act, list[sel + 1], sel)
      if r == "close" then
        result, act = sel, hit.act
        break
      end
      if mode.refresh ~= nil then
        list = mode.refresh()
      end
      show()
    elseif mode.step ~= nil and mode.step(list[sel + 1]) then
      -- 2026-09-28: the mode's own keys (graft pset_preview: Q / E page the set preview); it redraws itself
    elseif PL.Key(EVT_CMD_DOWN) and PL.ListVert(mode, list, sel, 1) ~= nil then
      sel = PL.ListVert(mode, list, sel, 1)
      if sel >= first + NR then
        first = sel - NR + 1
      end
      funcLuaCommand(C.SE, 2500047763 --[[sy0005 cursor]])
      show()
    elseif PL.Key(EVT_CMD_UP) and PL.ListVert(mode, list, sel, -1) ~= nil then
      sel = PL.ListVert(mode, list, sel, -1)
      if sel < first then
        first = sel
      end
      funcLuaCommand(C.SE, 2500047763)
      show()
    elseif pact == "moved" then
      first, sel = pfirst, psel
      funcLuaCommand(C.SE, 2500047763)
      show()
    end
  end
  PL.SSListShow(false, list, first, sel)
  PL.list_mode = nil
  coroutine.yield()                              -- the closing input must not reach our menu
  EVT_RefreshRows()
  pcall(UpdateEquipItemInfo)                     -- the screen's own button guide and panel again
  evt_icon_frames = math.max(evt_icon_frames, 3)
  PL.role_frames = math.max(PL.role_frames, 3)
  return result, act
end

function PL.RoleRow(k, e, selected)
  local L = PL.L_SSROW
  PL.MxRowBase(L, k, {name = e.name, check = e.current}, selected)
  -- 2026-10-06: the row's slot icon (_icon_sp_area_dmy01): the plain blue slot plate for «Sin rol», the role's
  -- gold / silver medal IN the slot (same quad, same size) for staff; the small quad (_icon_sixth_dmy01) sat off the
  -- plate's bottom-right corner, so it stays hidden in this list
  -- 2026-10-07: release a miniface another list (combo partner picker, miximax lists) bound to this slot first: a
  -- bound face icon outlives the sprite swap (Nacho saw Mercury / Flora faces instead of the medals)
  pcall(funcLuaMenuCommand, 4176779611 --[[ResetFaceIcon]], L, k, PL.SLOT_AREA)
  local medal = PL.ROLE_ITEM[e.role]
  if medal ~= nil then
    funcLuaMenuCommand(C.SPRITE, L, PL.TEX_ITEM01, medal, PL.SLOT_AREA, 0, k)
  else
    funcLuaMenuCommand(C.SPRITE, L, PL.TEX_BADGE, PL.BADGE_SPR[0], PL.SLOT_AREA, 0, k)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.MESH_AREA, true, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.MESH_SIXTH, false, k)
end

-- text broken into lines of at most `units` width (a letter 1, a CJK / kana glyph 2) at spaces (or anywhere without any)
function PL.WrapText(text, units)
  local out = {}
  for para in (text .. "\n"):gmatch("(.-)\n") do
    local line, width = "", 0
    local function flush()
      if line ~= "" then
        out[#out + 1] = (line:gsub("%s+$", ""))
      end
      line, width = "", 0
    end
    for word, space in para:gmatch("(%S+)(%s*)") do
      local w = 0
      for ch in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        w = w + (#ch >= 3 and 2 or 1)
      end
      if width > 0 and width + w > units then
        flush()
      end
      line, width = line .. word .. space, width + w + (space ~= "" and 1 or 0)
    end
    flush()
  end
  return table.concat(out, "\n")
end

function PL.RoleFocus(e)
  PL.PanelPlain(PL.BAND_ROLE[e.role], e.name,
    PL.WrapText(PL.Txt(PL.ROLE_DESC_TX[e.role]), PL.PLAIN.wrap_units) .. "\n"
      .. PL.WrapText(PL.Txt(PL.ROLE_EFF_TX[e.role]), PL.PLAIN.wrap_units),
    function(L)
      local medal = PL.ROLE_ITEM[e.role]
      if medal ~= nil then
        funcLuaMenuCommand(C.SPRITE, L, PL.TEX_ITEM01, medal, PL.SLOT_AREA, 0, 0)
      else
        funcLuaMenuCommand(C.SPRITE, L, PL.TEX_BADGE, PL.BADGE_SPR[0], PL.SLOT_AREA, 0, 0)
      end
    end, {banner = true})
end

-- the screen's 3D model and its shadow (retail SetCharaModelVisible: the model of soccer11_05_equip_status_base)
function PL.ModelVisible(visible)
  local h = funcLuaMenuCommand(3895705890 --[[model of a layer]], 2917320188 --[[soccer11_05_equip_status_base]], 0, 0)
  if type(h) == "number" and h ~= 0 then
    funcLuaCommand(1890282463 --[[chara model visible]], h, visible)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, 858725131 --[[mainmenu01_08_chara_3d_shadow]], 0, visible)
end

function PL.RoleCoroutine()
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  local cur, native, lock = PL.Role()
  local why = PL.RoleWhy(cur, lock)
  if why ~= nil then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(why)
    funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
    return
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  local list = {}
  for r = 0, 2 do
    list[#list + 1] = {role = r, name = PL.RoleName(r), current = r == cur}
  end
  PL.role_open = true
  -- 2026-10-15 (owner: «arregla la interfaz en el selector de rol»): only «Elegir» in the guide (the corner return guide
  -- mainmenu01_10 already shows Esc: «Volver» twice before), the 3D model hidden under the list, the header titled
  local keys = {{text = PL.TX.BTN_SELECT, icon = PL.I_ENTER, cmd = PL.K_ENTER, act = "pick"}}
  pcall(PL.ModelVisible, false)
  PL.HeaderTitle(PL.Txt(PL.TX.ROLE_TITLE))
  local okp, pick = pcall(PL.PopList, list, math.max(0, math.min(2, cur)), {
    row = PL.RoleRow, focus = PL.RoleFocus, guide = PL.Txt(PL.TX.ROLE_GUIDE),
    keys = function()
      return keys
    end,
    act = function()
      funcLuaCommand(C.SE, SE_DECIDE)
      return "close"
    end})
  PL.role_open = false
  PL.HeaderTitle(nil)
  pcall(PL.ModelVisible, true)
  if not okp then
    error(pick, 0)
  end
  -- «Sin rol» also runs when the badge is already gone but the creation-time staff bit is still on (native ~= 0)
  if pick >= 0 and (pick ~= cur or (pick == 0 and native ~= 0)) then
    if pick ~= 0 then
      funcLuaCommand(PL.ADD_ITEM, PL.ROLE_ITEM[pick], 1, false)   -- a free copy for the equip (retail shares stacks)
    end
    local st, now = EVT_Call(@crc:CMND_CHARACTERREFORGED_SET_ROLE@, n, pick)
    EVT_Log("role", n, cur, "->", pick, "native", native, "status", st, "now", now)
    if st == 1 then
      funcLuaCommand(C.SE, SE_DECIDE)
    else
      funcLuaCommand(C.SE, SE_NG)
      -- 2026-09-30: never a silent refusal (story copy -9, not a saved player -5, else the status code)
      -- 2026-10-08: -10 = below the matches of the mod Utilities' config.toml [role_medal] (default 0: never; now =
      -- how many are missing); its text is Utilities' row util_role_need_matches; the free copy goes back
      if st == -10 and pick ~= 0 then
        funcLuaCommand(PL.DEL_ITEM, PL.ROLE_ITEM[pick], 1)
      end
      local msg = (st == -9 and PL.RoleWhy(0, 1)) or (st == -5 and PL.RoleWhy(-5, 0))
        or (st == -10 and PL.Txt(3953080041 --[[util_role_need_matches]], now)) or PL.Txt(PL.TX.ROLE_FAIL, st)
      EVT_Message(msg)
    end
  end
  PL.RoleIcon()
  PL.RoleGuide()
  UpdateCharaStatus()
  coroutine.yield()                              -- the confirming input must not reach our menu
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- ---- custom passive (v3): our own list of the owned "Pasiva personalizada" items -----------------------------------
-- In game the board's list group listed moves (it reads the open board) and the retail equip_six_sense_menu opened
-- blank (its native list is never set up outside the board / formation flow). Our list: the 37 six-sense items
-- (item kind 177 = ss_ps50001 … ss_ps50037, docs/game/passives.md), those the save owns (CMND_GET_ITEM_NUM > 0),
-- with their names, "(equipada)" / "(sin copia libre)", plus "Quitar"; equip with CMND_CHARACTERREFORGED_SIX_SENSE (slot 9).
PL.SS_ITEMS = {3910925277, 1880271463, 118856433, 2574323538, 4000726980, 2004840062,
  7888616, 2428978041, 3888149487, 2265446922, 4026583708, 1762237222, 504277936,
  2154446355, 4151119493, 1852071743, 425947049, 2312925752, 4275782318, 2888477129,
  3677198687, 1109706981, 891549811, 2873585104, 3695205702, 1162415356, 843988074,
  2733711867, 3589673325, 3039926408, 3258361886, 1530919332, 741919026, 2992397457,
  3311102983, 1548893629, 726994219}

-- ---- Player sets: per-player builds (Character Reforged's store: scripts\player_sets.lua, blob ss_player_sets.json) --
-- Opened by the save-icon button (the screen's bottom button layer L_BTN, square skin, PL.SAVE_BUTTON). A set also
-- keeps the mix slot (PL.HsMix / PL.HsMixPut): saved, compared, loaded and exported with the rest.
-- v4 (2026-09-28, user: plain white bars on a grey box): the retail list window of the custom-passive picker (as the
-- role picker). Rows = "Set N · <name>" / "Set N · Vacío" (greyed), the first move's category + element icons, the
-- retail check mark on the set equal to the player's current build. The focused set is summed up in the integrated
-- panel (moves, Hipertécnica, equipment count, custom passive; the first move's icon as the big icon). Retail button
-- guide: <CMD_ENTER> Cargar (empty set: Guardar), <CMD_FUNC4> Guardar (overwrite, Sí/No), <CMD_FUNC1> Renombrar (the
-- game keyboard, as the save-slot screen), <CMD_FUNC3> Borrar (Sí/No), <CMD_BACK> Volver. Saving, renaming and deleting
-- keep the window open; loading closes it and lists what could not be applied. Texts: PL.TX (menu_text, 9 languages).
function PL.EquipIds()
  local e = {}
  for t = 0, 4 do
    local ok, id = pcall(GetEquipItemid, n, t)
    e[t + 1] = (ok and type(id) == "number") and EVT_U32(id) or 0
  end
  return e
end

function PL.SetGet(i)
  local r = {pcall(funcLuaCommand, @crc:CMND_CHARACTERREFORGED_PLAYER_SET_GET@, n, i)}
  if not r[1] or r[2] ~= true then
    return nil
  end
  local p = {name = r[3] or "", moves = {}, hiper = EVT_U32(r[10] or 0), equip = {}, sixsense = EVT_U32(r[16] or 0)}
  for k = 1, 6 do
    p.moves[k] = EVT_U32(r[3 + k] or 0)
  end
  for k = 1, 5 do
    p.equip[k] = EVT_U32(r[10 + k] or 0)
  end
  return p
end

-- the player's current build in the set format (rows that cannot take a move count as empty)
function PL.SetCurrent()
  local cur = {moves = {}, equip = PL.EquipIds()}
  for r = 0, EVT_ROW_NUM - 1 do
    local s = (r == 0 or not EVT_IsLocked(r)) and EVT_Skill(r) or 0
    if r == 0 then
      cur.hiper = EVT_U32(s or 0)
    else
      cur.moves[r] = EVT_U32(s or 0)
    end
  end
  local _, ss = EVT_SS_Get()
  cur.sixsense = EVT_U32(ss or 0)
  -- 2026-10-13: the kit (uniformId) of the team this screen edits, kept with a saved set for its row's miniface
  local okk, has, kit = pcall(funcLuaCommand, @crc:CMND_GET_TEAM_SET_INFO@, n3, n17, 7)
  cur.kit = (okk and has and type(kit) == "number") and EVT_U32(kit) or 0
  local okm, mix = pcall(PL.HsMix)                  -- the mix slot (0 = empty or no mix store)
  cur.mix = (okm and type(mix) == "number") and mix or 0
  return cur
end

function PL.SetSame(p, cur)
  if p == nil then
    return false
  end
  for k = 1, 6 do
    if (p.moves[k] or 0) ~= (cur.moves[k] or 0) then
      return false
    end
  end
  for k = 1, 5 do
    if (p.equip[k] or 0) ~= (cur.equip[k] or 0) then
      return false
    end
  end
  if (p.mix or 0) ~= 0 and p.mix ~= (cur.mix or 0) then
    return false
  end
  return p.hiper == cur.hiper and p.sixsense == cur.sixsense
end

function PL.ItemName(id)
  local nm = funcLuaCommand(@crc:CMND_GET_ITEM_PARAM@, id, 0)
  return type(nm) == "string" and nm or string.format("%08X", id)
end

function PL.SetList()
  local cur = PL.SetCurrent()
  local list = {}
  for i = 0, PL.SETS - 1 do
    local p = PL.SetGet(i)
    local e = {i = i, p = p, first = 0, current = PL.SetSame(p, cur)}
    local title = PL.Txt(PL.TX.SET_N, i + 1)
    if p == nil then
      e.name = title .. " · " .. PL.Txt(PL.TX.SET_EMPTY)
    else
      for k = 1, 6 do
        if e.first == 0 and p.moves[k] ~= 0 then
          e.first = p.moves[k]
        end
      end
      e.name = p.name ~= "" and (title .. " · " .. p.name) or title
    end
    list[#list + 1] = e
  end
  -- 2026-10-13 (owner: «mueve el icono de exportar abajo de la ranura 5, y haz uno de importar .vrmod»; «… en una
  -- sola fila»): one row under #5, «Exportar | Importar» (PL.VrmRow: two buttons of the layer evt_pset_file_btn); it
  -- acts on the last set row the cursor was on (PL.set_sel)
  list[#list + 1] = {kind = "vrm", name = PL.Txt(PL.TX.SET_EXPORT_ROW),
    names = {PL.Txt(PL.TX.SET_EXPORT_ROW), PL.Txt(PL.TX.SET_IMPORT_ROW)}}
  return list
end

-- 2026-10-13 (owner: «debería salirte la miniface con la equipación que tenías puesto en el equipo que le guardaste el
-- set al jugador, no el icono de tiro»): the player's face icon as the bank / dock lists draw it (552280324, type 9 =
-- face + kit) with the kit stored with the set (0 = an old set: the kit of his current team, resolved by the game)
function PL.SetFace(L, k, kit)
  pcall(funcLuaMenuCommand, 4176779611 --[[ResetFaceIcon]], L, k, PL.SLOT_AREA)
  local param = funcLuaCommand(C.CHARA_GET, n, 4) or 0
  local key = funcLuaCommand(C.CHARA_GET, n, 1) or 0
  local okk, keeper = pcall(MENU_DEF.IsKeeper, param)
  pcall(SetDisableForceCharaInvalidUseTarget)
  funcLuaMenuCommand(552280324, L, k, false, PL.MESH_AREA, PL.SLOT_AREA, n, 255, key, kit or 0, okk and keeper == true)
  pcall(SetEnableForceCharaInvalidUseTarget)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.MESH_AREA, true, k)
end

function PL.SetRowDraw(k, e, selected)
  if e.kind == "vrm" then
    PL.VrmRow(k, e, selected)
    return
  end
  local L = PL.L_SSROW
  PL.MxRowBase(L, k, {name = e.name, grey = e.p == nil, check = e.current}, selected)
  pcall(funcLuaMenuCommand, 4176779611 --[[ResetFaceIcon]], L, k, PL.SLOT_AREA)
  if e.p ~= nil then
    pcall(PL.SetFace, L, k, e.p.kit)
  end
end

function PL.SetSummary(p)
  local mv = {}
  for k = 1, 6 do
    if p.moves[k] ~= 0 then
      mv[#mv + 1] = EVT_Name(p.moves[k])
    end
  end
  local lines = {PL.Txt(PL.TX.SUM_MOVES, #mv > 0 and table.concat(mv, ", ") or "-")}
  if p.hiper ~= 0 then
    lines[#lines + 1] = PL.Txt(PL.TX.SUM_HIPER, EVT_Name(p.hiper))
  end
  if (p.mix or 0) ~= 0 then
    lines[#lines + 1] = PL.Txt(PL.TX.SUM_MIX, EVT_Name(p.mix))
  end
  local eq = 0
  for k = 1, 5 do
    if p.equip[k] ~= 0 then
      eq = eq + 1
    end
  end
  local tail = PL.Txt(PL.TX.SUM_EQUIP, eq)
  if p.sixsense ~= 0 then
    tail = tail .. "  ·  " .. PL.Txt(PL.TX.SUM_PASSIVE, PL.ItemName(p.sixsense))
  end
  lines[#lines + 1] = tail
  return table.concat(lines, "\n")
end

function PL.SetFocus(e)
  if e.kind ~= nil then
    local exp = PL.SetKind(e) == "export"
    PL.PanelPlain(6, e.names[exp and 1 or 2], PL.Txt(exp and PL.TX.EXPORT_DESC or PL.TX.IMPORT_DESC, (PL.set_sel or 0) + 1))
    return
  end
  PL.set_sel = e.i
  if e.p == nil then
    PL.PanelPlain(6, e.name, PL.Txt(PL.TX.SET_BTN_GUIDE))
    return
  end
  PL.PanelPlain(5, e.name, PL.SetSummary(e.p), e.first ~= 0 and function(L)
    SetupCommandActionSkillInfoCategoryIcon(L, 0, e.first)
  end or nil)
end

-- (no «Volver» entry: the screen's corner return guide mainmenu01_10 already shows Esc; 2026-10-15 it showed twice)
function PL.SetKeys(e)
  if e ~= nil and e.kind ~= nil then
    local kind = PL.SetKind(e)
    local tx = kind == "export" and PL.TX.SET_EXPORT_ROW or PL.TX.SET_IMPORT_ROW
    return {{text = tx, icon = PL.I_ENTER, cmd = PL.K_ENTER, act = kind}}
  end
  if e == nil or e.p == nil then
    return {{text = PL.TX.BTN_SAVE, icon = PL.I_ENTER, cmd = PL.K_ENTER, act = "save"}}
  end
  return {{text = PL.TX.BTN_LOAD, icon = PL.I_ENTER, cmd = PL.K_ENTER, act = "load"},
    {text = PL.TX.BTN_SAVE, icon = PL.I_FUNC4, cmd = PL.K_FUNC4, act = "save"},
    {text = PL.TX.BTN_RENAME, icon = PL.I_FUNC1, cmd = PL.K_FUNC1, act = "rename"},
    {text = PL.TX.BTN_DELETE, icon = PL.I_FUNC3, cmd = PL.K_FUNC3, act = "delete"}}
end

-- write set i: p = nil saves the current build (name = its first move), else p with `name`
function PL.SetWrite(i, p, name)
  if p == nil then
    local cur = PL.SetCurrent()
    local first = 0
    for r = 1, 6 do
      if first == 0 and cur.moves[r] ~= 0 then
        first = cur.moves[r]
      end
    end
    p = cur
    name = name or (first ~= 0 and EVT_Name(first) or PL.Txt(PL.TX.SET_N, i + 1))
  end
  local m, e = p.moves, p.equip
  local ok = EVT_Call(@crc:CMND_CHARACTERREFORGED_PLAYER_SET_SAVE@, n, i, EVT_Cut(name or "", 26), m[1], m[2],
    m[3], m[4], m[5], m[6], p.hiper,
    e[1], e[2], e[3], e[4], e[5], p.sixsense or 0)
  EVT_Log("player set save", i, name, ok)
  return ok
end

-- the default name of a new set: its first move, else «#N»
function PL.SetDefaultName(i)
  local cur = PL.SetCurrent()
  for r = 1, 6 do
    if cur.moves[r] ~= 0 then
      return EVT_Name(cur.moves[r])
    end
  end
  return PL.Txt(PL.TX.SET_N, i + 1)
end

-- 2026-10-13 (owner: «al guardar un set te tiene que preguntar por el nombre del set»): the game keyboard (PL.AskName,
-- the save-slot rename's arguments) prefilled with the default; cancel / no keyboard = the default
function PL.SetSave(i)
  local name = PL.SetDefaultName(i)
  local nm = PL.AskName(name)
  if type(nm) == "string" and nm ~= "" then
    name = nm
  end
  local ok = PL.SetWrite(i, nil, name)
  funcLuaCommand(C.SE, ok and SE_DECIDE or SE_NG)
end

-- the game keyboard (arguments of GENERAL_WINDOW.WaitAndSwkbWindowCoroutine, as the save-slot screen's rename):
-- string, nil (cancelled / empty) or false (the keyboard did not open)
PL.KB = {OPEN = 962493425, ACTIVE = 422535539, TEXT = 1487869455, CANCELLED = 1447363287, FORCE_END = 3351189333,
  STR_SPACES = 2431241294, MAX = 20}
function PL.AskName(initial)
  if funcLuaCommand(PL.KB.ACTIVE) then
    funcLuaCommand(PL.KB.FORCE_END, "")
    coroutine.yield()
  end
  local opened = false
  for _ = 1, 2 do
    funcLuaCommand(PL.KB.OPEN, 0, initial or "", PL.TX.KB_TITLE, 0, PL.KB.MAX, 0, 0, 0, 0, 0, 0, true, true, 2,
      PL.Txt(PL.TX.KB_TITLE), 0, false, false)
    for _ = 1, 10 do
      if funcLuaCommand(PL.KB.ACTIVE) == true then
        opened = true
        break
      end
      coroutine.yield()
    end
    if opened then
      break
    end
  end
  if not opened then
    return false
  end
  local live = ""
  while funcLuaCommand(PL.KB.ACTIVE) do
    local t = funcLuaCommand(PL.KB.TEXT)        -- live buffer (the final text / cancel flag are not reliable)
    if type(t) == "string" and t ~= "" then
      live = t
    end
    coroutine.yield()
  end
  local text = funcLuaCommand(PL.KB.TEXT)
  local cancelled = funcLuaCommand(PL.KB.CANCELLED) == true
  EVT_Log("player set keyboard", "cancelled", tostring(cancelled), "text", tostring(text), "live", live)
  if (type(text) ~= "string" or text == "") and live ~= "" then
    return PL.MxAsk(PL.Txt(PL.TX.ASK_NAME, live)) and live or nil
  end
  if cancelled or type(text) ~= "string" or text == "" or funcLuaCommand(PL.KB.STR_SPACES, text) == true then
    return nil
  end
  return text
end

function PL.SetAct(act, e, i)
  if act == "export" then
    PL.SetExport(PL.set_sel or 0)
    return "stay"
  elseif act == "import" then
    PL.SetImport(PL.set_sel or 0)
    return "stay"
  elseif act == "load" then
    funcLuaCommand(C.SE, SE_DECIDE)
    return "close"
  elseif act == "save" then
    if e.p ~= nil and not PL.MxAsk(PL.Txt(PL.TX.ASK_OVER, i + 1)) then
      funcLuaCommand(C.SE, SE_BACK)
      return "stay"
    end
    PL.SetSave(i)
  elseif act == "rename" then
    funcLuaCommand(C.SE, SE_DECIDE)
    local nm = PL.AskName(e.p.name)
    if nm == false then
      funcLuaCommand(C.SE, SE_NG)
      EVT_Message(PL.Txt(PL.TX.KB_FAIL))
    elseif nm ~= nil then
      local ok = PL.SetWrite(i, e.p, nm)
      funcLuaCommand(C.SE, ok and SE_DECIDE or SE_NG)
    end
  elseif act == "delete" then
    if PL.MxAsk(PL.Txt(PL.TX.ASK_DEL, i + 1)) then
      local ok = EVT_Call(@crc:CMND_CHARACTERREFORGED_PLAYER_SET_DELETE@, n, i)
      funcLuaCommand(C.SE, ok and SE_REMOVE or SE_NG)
    else
      funcLuaCommand(C.SE, SE_BACK)
    end
  end
  return "stay"
end

-- invHdl of an owned item with a free copy (moves / equipment / six sense share this): CMND_ADD_ITEM_ONLY returns the
-- item's stack handle (the extra copy is deleted again right away). Third value: the reason as a PL.TX skip row.
function PL.FreeHandle(item)
  local num = funcLuaCommand(PL.ITEM_NUM, item)
  if type(num) ~= "number" or num <= 0 then
    return 0, "not owned", PL.TX.SKIP_NOTOWN
  end
  local h = funcLuaCommand(PL.ADD_ITEM, item, 1, false)
  funcLuaCommand(PL.DEL_ITEM, item, 1)
  if h == nil or h == 0 then
    return 0, "no item", PL.TX.SKIP_FAIL
  end
  local used = funcLuaCommand(PL.EQUIPPED_NUM, h)
  if type(used) == "number" and used >= num then
    return 0, "every copy in use", PL.TX.SKIP_INUSE
  end
  return h, nil, nil
end

-- apply set p: everything valid is applied, the rest is listed
function PL.SetLoad(p)
  local skipped = {}
  local prime = EVT_IsPrime()
  local function skip(tx, what)
    skipped[#skipped + 1] = PL.Txt(tx, what)
  end
  local function has(skill)
    if EVT_Active(skill) then
      return true
    end
    for b = 0, 8 do
      if EVT_BoardSkill(b) == skill then
        return true
      end
    end
    local num = funcLuaCommand(PL.ITEM_NUM, skill)
    return type(num) == "number" and num > 0
  end
  if prime then
    skip(PL.TX.SKIP_PRIME)
  else
    for r = 1, 6 do
      local s = p.moves[r]
      if s ~= 0 and EVT_Skill(r) ~= s then
        if EVT_IsLocked(r) then
          skip(PL.TX.SKIP_ROW, EVT_Name(s))
        elseif PL.IdolFixed(r) then
          skip(PL.TX.SKIP_IDOL, EVT_Name(s))
        elseif not has(s) then
          skip(PL.TX.SKIP_NOTOWN, EVT_Name(s))
        else
          local ok = pcall(EVT_Equip, r, s, 0, nil)
          if not ok then
            skip(PL.TX.SKIP_FAIL, EVT_Name(s))
          end
        end
      end
    end
    if p.hiper ~= 0 and EVT_Skill(0) ~= p.hiper then
      if PL.IdolFixed(0) then
        skip(PL.TX.SKIP_IDOL, EVT_Name(p.hiper))
      elseif has(p.hiper) and EVT_IsSpecial(p.hiper) then
        pcall(EVT_Equip, 0, p.hiper, 0, nil)
      else
        skip(PL.TX.SKIP_NOTOWN, EVT_Name(p.hiper))
      end
    end
    -- the mix slot (a stored empty slot leaves the current one as it is, as every other field)
    local mix = p.mix or 0
    local okm, now = pcall(PL.HsMix)
    if mix ~= 0 and okm and now ~= mix then
      if PL.IdolFixed(0) then
        skip(PL.TX.SKIP_IDOL, EVT_Name(mix))
      elseif not has(mix) then
        skip(PL.TX.SKIP_NOTOWN, EVT_Name(mix))
      elseif not PL.HsMixPut(mix) then
        skip(PL.TX.SKIP_FAIL, EVT_Name(mix))
      end
    end
  end
  -- equipment (Equipamiento items), as the retail equip list commits
  local cur = PL.EquipIds()
  for t = 0, 4 do
    local want = p.equip[t + 1]
    if want ~= 0 and want ~= cur[t + 1] then
      local h, _, why = PL.FreeHandle(want)
      local label = PL.ItemName(want)
      if h ~= 0 then
        if cur[t + 1] ~= 0 then
          funcLuaCommand(PL.REMOVE_EQUIP, n, t)
        end
        funcLuaCommand(PL.EQUIP_ITEM, n, h, t)
        if PL.EquipIds()[t + 1] ~= want then
          skip(PL.TX.SKIP_FAIL, label)
        end
      else
        skip(why, label)
      end
    end
  end
  -- custom passive (six-sense slot)
  local _, ss = EVT_SS_Get()
  if p.sixsense ~= 0 and p.sixsense ~= ss then
    local locked = EVT_SS_Lock()
    local h, _, why = PL.FreeHandle(p.sixsense)
    local label = PL.Txt(PL.TX.PASSIVE)
    if locked then
      skip(PL.TX.SKIP_LOCKED, label)
    elseif h == 0 then
      skip(why, label)
    else
      local st = EVT_Call(@crc:CMND_CHARACTERREFORGED_SIX_SENSE@, n, 1, h, -1)
      if st ~= 1 then
        skip(PL.TX.SKIP_FAIL, label)
      end
    end
  end
  -- 2026-09-28: role + configured passives of the set (graft pset_preview defines PL.SetLoadExtra)
  if PL.SetLoadExtra ~= nil then
    local okx, errx = pcall(PL.SetLoadExtra, p, skip)
    if not okx then
      EVT_Log("player set load extra", tostring(errx))
    end
  end
  EVT_AfterChange()
  EVT_SS_ButtonRefresh()
  UpdateCharaStatus()
  EVT_Log("player set load", p.name, "skipped", #skipped)
  if #skipped > 0 then
    EVT_Message(PL.Txt(PL.TX.LOADED_SKIP, table.concat(skipped, ", ")))
  else
    funcLuaCommand(C.SE, SE_DECIDE)
  end
end

function PL.SetsCoroutine()
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  if not PL.HasService("player_sets") then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.LOADER))
    funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
    return
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  local list = PL.SetList()
  local init = 0
  for k, e in ipairs(list) do
    if e.current then
      init = k - 1
    end
  end
  PL.set_sel = init
  PL.vrm_half = 0
  local pick, act = PL.PopList(list, init, {row = PL.SetRowDraw, focus = PL.SetFocus,
    guide = PL.Txt(PL.TX.SET_GUIDE), keys = PL.SetKeys, act = PL.SetAct, refresh = PL.SetList, side = PL.SetSide,
    vert = PL.SetVert})
  if pick >= 0 and act == "load" then
    local p = PL.SetGet(pick)
    if p ~= nil then
      PL.SetLoad(p)
    end
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- ---- «Exportar set» / «Importar set» (2026-10-13): .vrmod files of one set -----------------------------------------
-- Rows 6-7 of the «Set de jugador» list (PL.SetList), acting on the last set row the cursor was on (PL.set_sel).
-- Files: Character Reforged's scripts\player_sets.lua (CMND_CHARACTERREFORGED_PLAYER_SET_EXPORT / _IMPORT_LIST /
-- _IMPORT_ENTRY / _IMPORT_READ), TOML schema utilities.vrmod/1 kind "character" in
-- <game>\modloader_exports\<config [player_sets] export_area>\.
-- docs/game/ui/vrmod-export.md §2.4. No input switch: messages are the general window (EVT_Message / PL.MxAsk).
-- (built in a function, as PL.TxTable: these numbers stay out of the main chunk's constant table)
function PL.VrmDef()
  return {
  -- the retail header clouds (icon_header_sub_upload01 / download01) cut and centred, white for the selected blue row,
  -- navy for the light rows: Character Reforged content/images/menu/200_icon/15_icon_common/player_set_icons.toml
  TEX = 2320109963,           -- #/menu/200_icon/15_icon_common/icon_common.g4tx
  UP = {[true] = 3273312901 --[[evt_vrm_up_white]], [false] = 1886212399 --[[evt_vrm_up_dark]]},
  DOWN = {[true] = 3165484893 --[[evt_vrm_down_white]], [false] = 2916954723 --[[evt_vrm_down_dark]]},
  EXPORT = @crc:CMND_CHARACTERREFORGED_PLAYER_SET_EXPORT@,        -- CMND_CHARACTERREFORGED_PLAYER_SET_EXPORT
  LIST = @crc:CMND_CHARACTERREFORGED_PLAYER_SET_IMPORT_LIST@,          -- CMND_CHARACTERREFORGED_PLAYER_SET_IMPORT_LIST
  ENTRY = @crc:CMND_CHARACTERREFORGED_PLAYER_SET_IMPORT_ENTRY@,         -- CMND_CHARACTERREFORGED_PLAYER_SET_IMPORT_ENTRY
  READ = @crc:CMND_CHARACTERREFORGED_PLAYER_SET_IMPORT_READ@,           -- CMND_CHARACTERREFORGED_PLAYER_SET_IMPORT_READ
  K_LEFT = 2765147006,        -- CMD_LEFT
  K_RIGHT = 2075023265,       -- CMD_RIGHT
  }
end
PL.VRM = PL.VrmDef()

-- 2026-10-13 (owner: «deberían ser exportar set | importar set en una sola fila»; in game the 7th list row only
-- showed after a scroll): ONE list entry under #5 (kind "vrm"), so the list has 6 rows.
-- 2026-10-15 (owner: «dos placas del mismo estilo lado a lado, cada una con su icono y texto»): the two halves are the
-- two instances of an own layer, evt_pset_file_btn (Character Reforged content/menus/skill_table.toml: object
-- evt_pset_file_btn = the team08_02 row with the half-width layout evt_pset_file_btn.g4pkm, plates 480 x 104 at x -98,
-- icon 46 px at x -49, text at x 22, cursor locator at x -42), attached by evt_pc_list at the row slot of instance 5
-- (_list06, left) and _list06_right (490 right). The list row instance under them is blanked. Why not inside the
-- row instance (CR 1.7.33 .. 1.8.2): the row's own G4RA keeps the _list_base_xs01_ok material hidden (type «OK», loop
-- _sma_hide_mat_01: the plate only flashes on a decide), so the right plate never showed, and a text box does not
-- follow a runtime node move (docs/game/mechanics/combo-partners.md), so both labels stayed at the row's text x.
-- Pointer: the row registers two zones (PL.ptr_split; the right half's id is k + 0.5).
function PL.FileBtnDef()
  return {
  L = 3123481048 --[[evt_pset_file_btn]],
  SLOT = 5,                   -- the list row instance the layer is attached over (evt_pc_list _list06)
  PLATE_X = -98, HALF = 480, GAP = 10,
  }
end
PL.FILE_BTN = PL.FileBtnDef()
PL.row_split = {}
PL.vrm_half = 0
PL.file_btn_shown = false

-- a row instance no longer drawn as the export / import row
function PL.RowFull(L, k)
  if L == PL.L_SSROW then
    PL.row_split[k] = nil
  end
end

-- the two export / import buttons off (the set list closed or another list drawn)
function PL.FileBtnHide()
  if not PL.file_btn_shown then
    return
  end
  PL.file_btn_shown = false
  local F = PL.FILE_BTN
  for h = 0, 1 do
    funcLuaMenuCommand(C.LAYER_VISIBLE, F.L, h, false)
  end
  pcall(funcLuaMenuCommand, C.CURSOR_LOC, F.L, 3313461902 --[[cursor]], 2, 2)
end

-- one button: instance h of evt_pset_file_btn (0 = export, 1 = import), on = it has the focus
function PL.FileBtnDraw(h, text, on)
  local F = PL.FILE_BTN
  PL.Open(F.L, h)
  funcLuaMenuCommand(C.LAYER_VISIBLE, F.L, h, true)
  PL.MxRowBase(F.L, h, {name = text}, on)
  local spr = h == 0 and PL.VRM.UP[on] or PL.VRM.DOWN[on]
  funcLuaMenuCommand(C.SPRITE, F.L, PL.VRM.TEX, spr, PL.SLOT_AREA, 0, h)
  funcLuaMenuCommand(C.MESH_VISIBLE, F.L, PL.MESH_AREA, true, h)
end

-- «Exportar | Importar» for row instance k (selected = the row has the focus; PL.vrm_half = which half)
function PL.VrmRow(k, e, selected)
  local L, F = PL.L_SSROW, PL.FILE_BTN
  if k ~= F.SLOT then
    -- the layer sits over one row slot only; elsewhere (not reached: the list has 6 entries) one plain row
    PL.MxRowBase(L, k, {name = e.names[1] .. "  |  " .. e.names[2]}, selected)
    return
  end
  -- the list row under the buttons stays empty: no plate, text, icon or mark
  PL.MxRowBase(L, k, {name = ""}, false)
  PL.row_split[k] = true
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.SSROW_BASE_ON, false, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.SSROW_BASE_OFF, false, k)
  funcLuaMenuCommand(2735666188 --[[text visible]], L, PL.SSROW_TEXT_ON, false, k)
  funcLuaMenuCommand(2735666188 --[[text visible]], L, PL.SSROW_TEXT_OFF, false, k)
  pcall(funcLuaMenuCommand, 4176779611 --[[ResetFaceIcon]], L, k, PL.SLOT_AREA)
  PL.file_btn_shown = true
  PL.FileBtnDraw(0, e.names[1], selected == true and PL.vrm_half == 0)
  PL.FileBtnDraw(1, e.names[2], selected == true and PL.vrm_half == 1)
end

-- the list cursor on the focused button while the export / import row has the focus (PL.SSListShow)
function PL.FileBtnCursor(RL, NR)
  local F = PL.FILE_BTN
  pcall(funcLuaMenuCommand, C.CURSOR_LOC, RL, 3313461902 --[[cursor]], NR, NR)
  pcall(funcLuaMenuCommand, C.CURSOR_LOC, F.L, 3313461902 --[[cursor]], PL.vrm_half == 1 and 1 or 0, 2)
end

-- the pointer zones of the export / import row: {left rect, right rect} ({x, w, h} from the row instance origin)
function PL.SetPtrSplit(k)
  if PL.row_split[k] then
    local F = PL.FILE_BTN
    return {{F.PLATE_X, F.HALF, PL.PTR_SS[3]}, {F.PLATE_X + F.HALF + F.GAP, F.HALF, PL.PTR_SS[3]}}
  end
  return nil
end
PL.ptr_split = PL.SetPtrSplit

-- the entry's action: the selected half of the split row
function PL.SetKind(e)
  if e ~= nil and e.kind == "vrm" then
    return PL.vrm_half == 1 and "import" or "export"
  end
  return e and e.kind
end

-- Up / Down: Down from #5 lands on «Exportar set» (left half); Down on the split row stays; Up from it goes back to
-- the last set row
function PL.SetVert(list, sel, dir)
  local e = list[sel + 1]
  if e == nil then
    return nil
  end
  if e.kind == nil then
    local nx = list[sel + 2]
    if dir > 0 and nx ~= nil and nx.kind == "vrm" then
      PL.vrm_half = 0
    end
    return nil
  end
  if dir > 0 then
    return false
  end
  for k = sel, 1, -1 do
    if list[k] ~= nil and list[k].kind == nil then
      return k - 1
    end
  end
  return false
end

-- Left / Right on the split row: the other half (same entry, redrawn); nil on a set row (its own left / right page
-- the set preview, graft pset_preview)
function PL.SetSide(list, sel)
  local e = list[sel + 1]
  if e == nil or e.kind ~= "vrm" then
    return nil
  end
  if PL.vrm_half == 0 and PL.Key(PL.VRM.K_RIGHT) then
    PL.vrm_half = 1
    return sel
  elseif PL.vrm_half == 1 and PL.Key(PL.VRM.K_LEFT) then
    PL.vrm_half = 0
    return sel
  end
  return nil
end

function PL.SetExport(i)
  local p = PL.SetGet(i)
  if p == nil then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.EXPORT_EMPTY, i + 1))
    return
  end
  local m, e = p.moves, p.equip
  local pv, cf = p.passives or {}, p.pcfg or {}
  local name = PL.MxCharaName(funcLuaCommand(C.CHARA_GET, n, 4))
  local level = funcLuaCommand(C.CHARA_GET, n, 0) or 0
  local r = {pcall(funcLuaCommand, PL.VRM.EXPORT, n, name, level, m[1] or 0, m[2] or 0, m[3] or 0, m[4] or 0,
    m[5] or 0, m[6] or 0, p.hiper or 0, e[1] or 0, e[2] or 0, e[3] or 0, e[4] or 0, e[5] or 0, p.sixsense or 0,
    p.role or -1, p.name or "", pv[1] or 0, pv[2] or 0, pv[3] or 0, pv[4] or 0, pv[5] or 0,
    cf[1] or 0, cf[2] or 0, cf[3] or 0, cf[4] or 0, cf[5] or 0, p.kit or 0, p.mix or 0)}
  EVT_Log("player set export", i, tostring(r[1]), tostring(r[2]), tostring(r[3]), tostring(r[4]))
  if r[1] and r[2] == true and type(r[3]) == "string" then
    funcLuaCommand(C.SE, SE_DECIDE)
    -- forward slashes: a backslash before a letter could read as a text escape in the game's window
    EVT_Message(PL.Txt(PL.TX.EXPORT_DONE, "modloader_exports/" .. tostring(r[4] or "") .. "/" .. r[3]))
  else
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.EXPORT_FAIL))
  end
end

function PL.ImportRow(k, e, selected)
  local L = PL.L_SSROW
  PL.MxRowBase(L, k, {name = e.name}, selected)
  pcall(funcLuaMenuCommand, 4176779611 --[[ResetFaceIcon]], L, k, PL.SLOT_AREA)
  funcLuaMenuCommand(C.SPRITE, L, PL.VRM.TEX, PL.VRM.DOWN[selected == true], PL.SLOT_AREA, 0, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.MESH_AREA, true, k)
end

-- a move of the file, checked against this install and this player. Returns the id to keep (0 = dropped) and true
-- when the move is valid. The game's rules: the Hiper row takes only special (category 8) moves, the other rows never;
-- the id must be a move of this install. From another player's file (`other`) the Hiper must also be one this player
-- already has (an active / board skill): auras and miximaxes are bound to their characters.
function PL.ImportMove(id, hiper, other)
  if id == 0 then
    return 0, true
  end
  local ok, nameId = funcLuaCommand(C.SKILL_INFO, id, 4)
  if not ok or nameId == nil then
    return 0, false
  end
  if EVT_IsSpecial(id) ~= hiper then
    return 0, false
  end
  if hiper and other then
    local own = EVT_Active(id)
    for b = 0, 8 do
      own = own or EVT_BoardSkill(b) == id
    end
    if not own then
      return 0, false
    end
  end
  return id, true
end

function PL.ImportItem(id)
  if id == 0 then
    return 0, true
  end
  local nm = funcLuaCommand(@crc:CMND_GET_ITEM_PARAM@, id, 0)
  if type(nm) ~= "string" or nm == "" then
    return 0, false
  end
  return id, true
end

function PL.SetImport(i)
  local okc, count, area = pcall(funcLuaCommand, PL.VRM.LIST)
  if not okc or type(count) ~= "number" or count <= 0 then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.IMPORT_NONE, "modloader_exports/" .. tostring(area or "")))
    return
  end
  local files = {}
  for k = 0, count - 1 do
    local oke, file, label = pcall(funcLuaCommand, PL.VRM.ENTRY, k)
    if oke and type(file) == "string" then
      files[#files + 1] = {idx = k, file = file, name = type(label) == "string" and label or file}
    end
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  local pick = PL.PopList(files, 0, {row = PL.ImportRow, guide = PL.Txt(PL.TX.IMPORT_GUIDE),
    focus = function(f)
      PL.PanelPlain(6, f.name, f.file)
    end,
    keys = function()
      return {{text = PL.TX.SET_IMPORT_ROW, icon = PL.I_ENTER, cmd = PL.K_ENTER, act = "pick"}}
    end,
    act = function()
      return "close"
    end})
  if pick < 0 or files[pick + 1] == nil then
    return
  end
  local r = {pcall(funcLuaCommand, PL.VRM.READ, files[pick + 1].idx, n)}
  EVT_Log("player set import read", files[pick + 1].file, tostring(r[1]), tostring(r[2]), tostring(r[3]))
  if not r[1] or r[2] ~= true then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.IMPORT_BAD))
    return
  end
  -- ok, set name, chara_param of the file, checksum ok, missing ids (text), m1..m6, hiper, e1..e5, six sense, role,
  -- p1..p5, c1..c5 (-1 = no passives stored), kit, mix
  local v = {}
  for k = 7, 37 do
    v[k - 6] = tonumber(r[k]) or 0
  end
  local setname, fparam, sumok, missing = r[3], EVT_U32(tonumber(r[4]) or 0), r[5] == true, r[6]
  if not sumok and not PL.MxAsk(PL.Txt(PL.TX.IMPORT_SUM)) then
    funcLuaCommand(C.SE, SE_BACK)
    return
  end
  local mine = EVT_U32(funcLuaCommand(C.CHARA_GET, n, 4) or 0)
  local other = fparam ~= 0 and fparam ~= mine
  local skipped = {}
  if type(missing) == "string" and missing ~= "" then
    skipped[#skipped + 1] = missing
  end
  local p = {name = type(setname) == "string" and setname or "", moves = {}, equip = {}}
  local bad = false
  for k = 1, 6 do
    local id, ok = PL.ImportMove(EVT_U32(v[k]), false, other)
    p.moves[k] = id
    if not ok then
      bad = true
      skipped[#skipped + 1] = EVT_Name(EVT_U32(v[k]))
    end
  end
  local hid, hok = PL.ImportMove(EVT_U32(v[7]), true, other)
  p.hiper = hid
  if not hok then
    bad = true
    skipped[#skipped + 1] = EVT_Name(EVT_U32(v[7]))
  end
  if other and bad then
    -- another player's set: only when every move is valid for this one
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.IMPORT_OTHER))
    return
  end
  for t = 1, 5 do
    local id, ok = PL.ImportItem(EVT_U32(v[7 + t]))
    p.equip[t] = id
    if not ok then
      skipped[#skipped + 1] = string.format("%08X", EVT_U32(v[7 + t]))
    end
  end
  local six, sok = PL.ImportItem(EVT_U32(v[13]))
  p.sixsense = six
  if not sok then
    skipped[#skipped + 1] = PL.Txt(PL.TX.PASSIVE)
  end
  if v[14] >= 0 and v[14] <= 2 then
    p.role = v[14]
  end
  if v[15] >= 0 then
    p.passives, p.pcfg = {}, {}
    for k = 1, 5 do
      p.passives[k] = EVT_U32(v[14 + k])
      p.pcfg[k] = EVT_U32(v[19 + k])
    end
  end
  p.kit = EVT_U32(v[25])                          -- the kit the set was saved in (0 = none: the current team's)
  local mix, mix_ok = PL.ImportMove(EVT_U32(v[26]), true, other)
  p.mix = mix
  if not mix_ok then
    skipped[#skipped + 1] = EVT_Name(EVT_U32(v[26]))
  end
  if PL.SetGet(i) ~= nil and not PL.MxAsk(PL.Txt(PL.TX.ASK_OVER, i + 1)) then
    funcLuaCommand(C.SE, SE_BACK)
    return
  end
  local name = p.name ~= "" and p.name or PL.Txt(PL.TX.SET_N, i + 1)
  local ok = PL.SetWrite(i, p, name)
  EVT_Log("player set import", i, name, "ok", tostring(ok), "other", tostring(other), "skipped", #skipped)
  if not ok then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.IMPORT_BAD))
  elseif #skipped > 0 then
    funcLuaCommand(C.SE, SE_DECIDE)
    EVT_Message(PL.Txt(PL.TX.IMPORT_SKIP, table.concat(skipped, ", ")))
  else
    funcLuaCommand(C.SE, SE_DECIDE)
    EVT_Message(PL.Txt(PL.TX.IMPORT_DONE, i + 1))
  end
end

-- the former "Tabla de habilidades original" button: player sets (the original board is no longer opened)
function EVT_OpenOriginalBoard()
  if evt_co ~= nil then
    return
  end
  evt_co = coroutine.create(function()
    PL.SetsCoroutine()
  end)
end

-- ---- wrappers ---------------------------------------------------------------------------------------------------
PL.PrevInit2 = OnInit
function OnInit()
  if funcLuaCommand(C.P_HAS, 813466851) then       -- formation id (team dock; kept for the six-sense menu)
    PL.formation = funcLuaCommand(C.P_GET, 813466851)
  end
  PL.PrevInit2()
end

function PL.ClearAltGlyph()
  funcLuaMenuCommand(C.TEXT, L_BTN, 950238781 --[[_text_btn01 key glyph]], "", 0)
  funcLuaMenuCommand(C.TEXT, L_BTN, 625330766 --[[_text_cmd01 label: the button is an icon]], "", 0)
end

-- The player-sets button: the screen's bottom button layer (L_BTN) with the square skin of the other icon buttons and a
-- save icon on top: instance PL.SAVE_BUTTON.ICON of the passive-row layer (the slot of the removed passives button's
-- icon), drawn as the six-sense / role icons are (EVT_ButtonIcon). The icon follows the button's visibility (the list
-- covers and the screen modes hide the button). The hint is the guide line (PL.TX.SET_BTN_GUIDE).
-- (built in a function: these numbers stay out of the main chunk's constant table)
function PL.SaveButtonDef()
  return {
  ICON = EVT_ROW_ICON_PV,     -- row-layer instance attached at the button (_pos_btn_ico02)
  TEX = 2320109963,           -- #/menu/200_icon/15_icon_common/icon_common.g4tx
  SPRITE = 4128237245,        -- character_reforged_player_sets_icon (Character Reforged content\images)
  PRIORITY = 560,             -- as the other button icons
  IS_VISIBLE = @crc:CMND_IS_LAYER_VISIBLE@,    -- CMND_IS_LAYER_VISIBLE (layer, idx)
  CURSOR = 3313461902,        -- the button's cursor attach (off, as on the other square buttons)
  }
end
PL.SAVE_BUTTON = PL.SaveButtonDef()

function PL.SaveIcon()
  local B = PL.SAVE_BUTTON
  EVT_ButtonIcon(B.ICON, B.TEX, B.SPRITE)
  B.shown = nil                                    -- PL.SaveIconFollow sets the visibility on the next frame
end

-- the icon shown exactly while the button is (one check per frame; the layer command only on a change)
function PL.SaveIconFollow()
  local B = PL.SAVE_BUTTON
  local ok, visible = pcall(funcLuaMenuCommand, B.IS_VISIBLE, L_BTN, 0)
  local show = ok and visible ~= false and not evt_pv_open
  if show ~= B.shown then
    B.shown = show
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_PV_ROW, B.ICON, show)
  end
end

-- 2026-10-12 (owner): the «Pasivas de la rama» button between «Pasiva personalizada» and «Rol» is gone; «Rol» and its
-- icon move one square button pitch left into its place (the buttons' locators: ss2_build.py BTN_ICON_DX / BTN_ROLE_DX)
PL.ROLE_SHIFT_X = -80
PL.PrevSetupLayer = OnSetupLayer
function OnSetupLayer(a1, a2)
  if a1 == PL.L_BTN_ROLE then
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, a1, PL.ROLE_SHIFT_X, 0, 0, a2)
    funcLuaMenuCommand(C.TEXT, a1, 625330766 --[[_text_cmd01]], "", a2)
    funcLuaMenuCommand(C.TEXT, a1, 950238781 --[[_text_btn01]], "", a2)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 3313461902 --[[cursor]], false)
    return
  elseif a1 == PL.L_BADGE then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 906, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == PL.L_ROLE_OPT then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 895, true)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 3313461902 --[[cursor]], false)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == L_PV_ROW and a2 == PL.ROW_ICON_ROLE then
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, a1, PL.ROLE_SHIFT_X, 0, 0, a2)
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 560, true)
    pcall(PL.RoleIcon)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, true)
    return
  elseif a1 == L_PV_ROW and a2 == PL.SAVE_BUTTON.ICON then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, PL.SAVE_BUTTON.PRIORITY, true)
    pcall(PL.SaveIcon)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, true)
    return
  end
  PL.PrevSetupLayer(a1, a2)
  if a1 == L_BTN then
    PL.ClearAltGlyph()                               -- no key glyph and no label: the button is an icon
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, PL.SAVE_BUTTON.CURSOR, false)
  end
end

PL.PrevOpenLayer = OnOpenLayer
function OnOpenLayer(a1, a2)
  if a1 == PL.L_BTN_ROLE then
    funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, a1, a2, 2734777837 --[[Focus]], 2, 973515837 --[[button]])
    return
  elseif a1 == PL.L_ROLE_OPT then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == PL.L_BADGE then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, PL.role_open)
    return
  elseif a1 == L_PV_ROW and (a2 == PL.ROW_ICON_ROLE or a2 == PL.SAVE_BUTTON.ICON) then
    PL.role_frames = 10                            -- the open restores mesh visibility: re-apply the icons
    return
  end
  PL.PrevOpenLayer(a1, a2)
  if a1 == L_BTN then
    PL.ClearAltGlyph()
  end
end

PL.PrevChangeFocus = OnChangeFocus
function OnChangeFocus(a1, a2)
  if a1 == PL.L_BTN_ROLE then
    n14 = L_BTN
    UpdateEquipItemInfo()
    pcall(PL.RoleGuide)
    return
  end
  PL.PrevChangeFocus(a1, a2)
  if a1 == L_BTN then
    PL.Guide(PL.Txt(PL.TX.SET_BTN_GUIDE))
  end
end

PL.PrevDecide = OnDecideFocus
function OnDecideFocus(a1, a2)
  if a1 == PL.L_BTN_ROLE then
    if evt_co == nil then
      evt_co = coroutine.create(function()
        PL.RoleCoroutine()
      end)
    end
    return
  end
  PL.PrevDecide(a1, a2)
end

PL.PrevFunction = OnFunction
function OnFunction(a1, a2)
  if a1 == 3918588344 then                       -- CMD_FUNC1 (Alt): free (it opened the original board)
    return
  end
  PL.PrevFunction(a1, a2)
end

PL.PrevStep = Step
function Step()
  PL.PrevStep()
  if n ~= nil and n ~= PL.role_shown and evt_co == nil then
    PL.role_shown = n
    PL.role_frames = math.max(PL.role_frames, 3)
  end
  if PL.role_frames > 0 and evt_co == nil and not evt_pv_open then
    PL.role_frames = PL.role_frames - 1
    pcall(PL.RoleIcon)
    pcall(PL.SaveIcon)
    pcall(PL.ClearAltGlyph)
  end
  pcall(PL.SaveIconFollow)
end
