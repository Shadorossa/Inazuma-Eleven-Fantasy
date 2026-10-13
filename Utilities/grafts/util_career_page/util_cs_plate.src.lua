-- Career page «TRAYECTORIA» of the mod Utilities (feature career, scripts\career.lua; docs/game/mechanics/
-- player-career-stats.md §4), the plate itself (personal_plate_menu). SOURCE of util_cs_plate.lua (gen_hooks.py puts
-- util_cs_common.src.lua in place of the @COMMON@ line and fills the @crc placeholders; edit the sources, then run the
-- script). Moved from Inazuma Fantasy (graft career_page, table EVT_CS) on 2026-10-08.
-- @COMMON@
-- The page (v5, 2026-10-10: the design Nacho approved on Inazuma Fantasy's player page, rounds 13 / 14 / 14c of
-- 2026-10-06, commits 7f6fb69284, 9bd0baf82e, 61e33e2c5a; v4's 4 x 5 grid of 2026-09-30 is gone):
--   two rows of three columns, each row on a slanted light-blue band (2 instances of the layer util_cs_band, a copy of
--   the retail stamina gauge btl06_13 whose frame shows Utilities' sprite util_cs_band, 780 x 72 px):
--     row 1 = FICHADO | ORIGEN | PARTIDOS          row 2 = V-E-D · % | GOLES | GOLES/PART.
--   numbers from CMND_UTIL_CAREER_EX(chara, 0) (signed, before, source, matches, wins, draws, losses, goals); the ratio
--   with the language's decimal comma, «-» without matches; a player without a save record: «Sin datos».
-- * The page shows as page type 2 (PASIVAS DE EQUIPO) with its 5 retail strips hidden; the six cells are instances of
--   util_cs_cellt (row 1) / util_cs_cell (row 2), mounted by the panel util_cs_panel (attached at the status base's
--   _atc_passive01, screen (1440, 576) on the retail plate) and moved (layer position, y up) onto the bands' columns;
--   the other cells stay hidden. The bands hang from the same locator (attach rows util_cs_band0 / 1 on the retail
--   status base; Utilities' menus\102_team\career.toml).
-- * Retail plate: the bands centred in the passives area under the title (x 1050..1830, y 666..738 / 754..826), the
--   columns 260 px apart. Inazuma Fantasy's paged plate lays the same rows out on its own card (its plate_pages
--   G.Career, own bands evt_pp_csband); there this file only fills the cells (same texts) and leaves the layout alone.
-- * Title: the six-sense title mesh with the sprite util_gtxt_career01 (Utilities' images, 9 languages).
-- * Page change: on the retail plate this file wraps ChangePersonalPlatePageByCharaHdl / ...ByCharaParamId itself; on
--   Inazuma Fantasy's paged plate IF's plate_pages block calls UTIL_CS.PageChange from a wrapper UNDER its own (so its
--   Trayectoria rows see type 6) and this file leaves those two functions alone.
-- Texts: menu_text utilities.cs_* (Utilities' text\rows\career.toml, 9 languages; Spanish fallbacks below). No
-- funcLuaCommand runs while the chunk loads.
UTIL_CS.CMD_EX = @crc:CMND_UTIL_CAREER_EX@
UTIL_CS.PANEL = @crc:util_cs_panel@
UTIL_CS.CELL = @crc:util_cs_cell@     -- cells of rows 2-5 (16 instances; row 2 used)
UTIL_CS.CELLT = @crc:util_cs_cellt@   -- cells of row 1 (4 instances)
UTIL_CS.N_LABEL = @crc:_text_bonus01@
UTIL_CS.N_VALUE = @crc:_text_exp01@
UTIL_CS.ROW_CELLS = {[0] = 4, 4, 4, 4, 4}
UTIL_CS.ROWS = 811691761             -- soccer11_20_formation_team_passive (the retail strips, hidden on our page)
UTIL_CS.L_STATUS = 730911947         -- soccer11_05_formation_status_base
UTIL_CS.TX_S1105 = 1156047165        -- #/menu/00_soccer/soccer11/soccer11_05/<LG>/soccer11_05.g4tx
UTIL_CS.SP_SIXTH = 2885965654        -- gtxt_sixthsense01 (swap node of the title mesh)
UTIL_CS.SP_TITLE = @crc:util_gtxt_career01@
UTIL_CS.M_SIXTH_TITLE = 1621221814   -- _gtxt_sixthsense01
UTIL_CS.M_T_PARAM1 = 254458604       -- _gtxt_parameters01 (ATRIBUTOS, page type 1)
UTIL_CS.M_T_PARAM2 = 2518936406      -- _gtxt_parameters02 (ATRIBUTOS, equipment page, type 0)
UTIL_CS.M_T_TEAMPASS = 301770119     -- _gtxt_teampassives01 (PASIVAS DE EQUIPO, type 2)
UTIL_CS.M_DOT4_ON = 1030719410       -- _page03_on (lit dot of the passives page, child of _pos_page03)
-- the row bands: 2 instances of util_cs_band (btl06_13_stamina_gauge copy) attached at _atc_passive01
UTIL_CS.BAND = @crc:util_cs_band@
UTIL_CS.BAND_TRACE = {[0] = @crc:util_cs_band0@, @crc:util_cs_band1@}
UTIL_CS.SP_BAND = @crc:util_cs_band@
UTIL_CS.TX_BTL0613 = 1191797350      -- #/menu/02_btl/btl06/btl06_13/<LG>/btl06_13.g4tx
UTIL_CS.SP_FRAME = 538967808         -- the gauge frame's sprite slot (_hp_base01)
UTIL_CS.BAND_HIDE = {1257514352 --[[_gtxt_stamina01]], 2609329121 --[[_hp_empty01]], 2043683848 --[[_hp_bar02]]}
UTIL_CS.FRAME = {94, 816, 476, 44}   -- the gauge frame _hp_base01 in its layout: x, -y, w, h
-- retail plate geometry (screen px, y down): the locator, the cells' default centres, the bands and the columns
UTIL_CS.ORG = {1440, 576}            -- _atc_passive01 of soccer11_05_formation_status_base
UTIL_CS.CELL_X0, UTIL_CS.CELL_DX, UTIL_CS.CELL_DY = -290.5, 195, 84   -- cell (r, c) default = ORG + (x0 + dx c, dy r)
UTIL_CS.BAND_RECT = {[0] = {1050, 666, 1830, 738}, [1] = {1050, 754, 1830, 826}}
UTIL_CS.COL_X = {1180, 1440, 1700}
UTIL_CS.C = {LAYER_VISIBLE = 711242136, EXIST_LAYER = 262659071, IS_OPEN_LAYER = 2640875187, OPEN_LAYER = 629267548,
  LOADING = 3057768039, POS = 1389957207, SCALE = 3778714801, TRACE = 1774843228,
  LOC_VISIBLE = 2158717427, MESH_VISIBLE = 3405944500, TEXT = 1083631230, TEXT_VISIBLE = 1505208242,
  SPRITE = 558735651, TEXT_GET = 4074371074, EVT_LOG = 3661580131}
UTIL_CS.DEBUG = false               -- true: lines «util_career_page …» in the loader log (CMND_EVT_LOG)
UTIL_CS.shown = false
UTIL_CS.bandReady = UTIL_CS.bandReady or {}
-- menu_text rows (crc32 of the key) and their Spanish fallback
UTIL_CS.TX = {
  date = {@crc:utilities.cs_date@, "{d}/{m}/{yy}"},
  no_data = {@crc:utilities.cs_no_data@, "Sin datos"},
  none = {@crc:utilities.cs_none@, "-"},
  dec = {@crc:utilities.cs_dec@, ","},
  l_signed = {@crc:utilities.cs_l_signed@, "FICHADO"},
  l_source = {@crc:utilities.cs_l_source@, "ORIGEN"},
  l_matches = {@crc:utilities.cs_l_matches@, "PARTIDOS"},
  l_record = {@crc:utilities.cs_l_record@, "V-E-D"},
  l_goals = {@crc:utilities.cs_l_goals@, "GOLES"},
  l_gpm = {@crc:utilities.cs_l_gpm@, "GOLES/PART."},
  v_record = {@crc:utilities.cs_v_record@, "{1}-{2}-{3}"},
  src1 = {@crc:utilities.cs_src1@, "Fichaje"},
  src2 = {@crc:utilities.cs_src2@, "Historia"},
  src3 = {@crc:utilities.cs_src3@, "Avatar"},
  src4 = {@crc:utilities.cs_src4@, "INAROGUE"},
}

function UTIL_CS.Log(...)
  if UTIL_CS.DEBUG then
    pcall(funcLuaCommand, UTIL_CS.C.EVT_LOG, "util_career_page", ...)
  end
end

function UTIL_CS.Text(key)
  local e = UTIL_CS.TX[key]
  if e == nil then
    return ""
  end
  local ok, s = pcall(funcLuaCommand, UTIL_CS.C.TEXT_GET, e[1])
  if ok and type(s) == "string" and s ~= "" then
    return s
  end
  return e[2]
end

-- "{1}".."{4}" placeholders
function UTIL_CS.Fmt(key, ...)
  local s = UTIL_CS.Text(key)
  local args = {...}
  for i = 1, #args do
    s = string.gsub(s, "{" .. i .. "}", (string.gsub(tostring(args[i]), "%%", "%%%%")))
  end
  return s
end

function UTIL_CS.Date(v)
  if type(v) ~= "number" or v <= 0 then
    return nil
  end
  local y = math.floor(v / 10000)
  local m = math.floor(v / 100) % 100
  local d = v % 100
  local s = UTIL_CS.Text("date")
  s = string.gsub(s, "{yy}", string.format("%02d", y % 100))
  s = string.gsub(s, "{y}", string.format("%04d", y))
  s = string.gsub(s, "{m}", string.format("%02d", m))
  s = string.gsub(s, "{d}", string.format("%02d", d))
  return s
end

-- a / b with one or two decimals ("0,58"), "-" when b is 0
function UTIL_CS.Ratio(a, b, digits)
  if type(a) ~= "number" or type(b) ~= "number" or b <= 0 then
    return UTIL_CS.Text("none")
  end
  local s = string.format("%." .. (digits or 2) .. "f", a / b)
  return (string.gsub(s, "%.", UTIL_CS.Text("dec")))
end

function UTIL_CS.Pct(a, b)
  if type(a) ~= "number" or type(b) ~= "number" or b <= 0 then
    return UTIL_CS.Text("none")
  end
  return tostring(math.floor(100 * a / b + 0.5)) .. "%"
end

function UTIL_CS.Exists(layer)
  return funcLuaMenuCommand(UTIL_CS.C.EXIST_LAYER, layer) == true
end

function UTIL_CS.IsOpen(layer, k)
  return funcLuaMenuCommand(UTIL_CS.C.IS_OPEN_LAYER, layer, k) == true
end

-- CMND_UTIL_CAREER_EX(chara, group) -> values (1-based) or nil
function UTIL_CS.Ex(chara, group)
  if chara == nil or chara == 0 then
    return nil
  end
  local r = {pcall(funcLuaCommand, UTIL_CS.CMD_EX, chara, group)}
  if r[1] ~= true or r[2] ~= true then
    return nil
  end
  local v = {}
  for i = 3, #r do
    v[#v + 1] = type(r[i]) == "number" and r[i] or 0
  end
  return v
end

-- ---- the panel and its cells -----------------------------------------------------------------------------------
function UTIL_CS.Open(L, k)
  if not UTIL_CS.IsOpen(L, k) then
    funcLuaMenuCommand(UTIL_CS.C.OPEN_LAYER, L, k)
  end
end

-- (layer, instance) of cell (row, col)
function UTIL_CS.Cell(row, col)
  if row == 0 then
    return UTIL_CS.CELLT, col
  end
  local k = col
  for r = 1, row - 1 do
    k = k + UTIL_CS.ROW_CELLS[r]
  end
  return UTIL_CS.CELL, k
end

function UTIL_CS.EachCell(fn)
  for r = 0, 4 do
    for c = 0, UTIL_CS.ROW_CELLS[r] - 1 do
      local L, k = UTIL_CS.Cell(r, c)
      fn(L, k, r, c)
    end
  end
end

-- the cells this page uses: rows 0 / 1, columns 0..2
function UTIL_CS.Used(r, c)
  return r <= 1 and c <= 2
end

function UTIL_CS.PanelShow(on)
  local C = UTIL_CS.C
  if not UTIL_CS.Exists(UTIL_CS.PANEL) or not UTIL_CS.Exists(UTIL_CS.CELL) or not UTIL_CS.Exists(UTIL_CS.CELLT) then
    return false
  end
  if on then
    UTIL_CS.Open(UTIL_CS.PANEL, 0)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, UTIL_CS.PANEL, 0, on)
  UTIL_CS.EachCell(function(L, k, r, c)
    local mine = on and UTIL_CS.Used(r, c)
    if mine then
      UTIL_CS.Open(L, k)
    end
    if mine or UTIL_CS.IsOpen(L, k) then
      funcLuaMenuCommand(C.LAYER_VISIBLE, L, k, mine)
    end
  end)
  return true
end

function UTIL_CS.Set(row, col, label, value)
  local L, k = UTIL_CS.Cell(row, col)
  local C = UTIL_CS.C
  funcLuaMenuCommand(C.TEXT, L, UTIL_CS.N_LABEL, label or "", k)
  funcLuaMenuCommand(C.TEXT, L, UTIL_CS.N_VALUE, value or "", k)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L, UTIL_CS.N_LABEL, true, k)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L, UTIL_CS.N_VALUE, true, k)
end

function UTIL_CS.Clear()
  for r = 0, 1 do
    for c = 0, 2 do
      UTIL_CS.Set(r, c, "", "")
    end
  end
end

-- the two rows: FICHADO | ORIGEN | PARTIDOS / V-E-D · % | GOLES | GOLES/PART.
function UTIL_CS.Fill(chara)
  local T = UTIL_CS.Text
  UTIL_CS.Clear()
  local v = UTIL_CS.Ex(chara, 0)
  if v == nil then
    UTIL_CS.Set(0, 0, T("no_data"), T("none"))
    return false
  end
  local signed, before, source = v[1], v[2], v[3]
  local m, w, d, l, g = v[5], v[6], v[7], v[8], v[9]
  local src = type(source) == "number" and source >= 1 and source <= 4 and T("src" .. source) or T("none")
  UTIL_CS.Set(0, 0, T("l_signed"), UTIL_CS.Date(signed) or UTIL_CS.Date(before) or T("none"))
  UTIL_CS.Set(0, 1, T("l_source"), src)
  UTIL_CS.Set(0, 2, T("l_matches"), tostring(m))
  UTIL_CS.Set(1, 0, T("l_record") .. " · %", UTIL_CS.Fmt("v_record", w, d, l) .. " · " .. UTIL_CS.Pct(w, m))
  UTIL_CS.Set(1, 1, T("l_goals"), tostring(g))
  UTIL_CS.Set(1, 2, T("l_gpm"), UTIL_CS.Ratio(g, m, 2))
  return true
end

-- ---- the retail plate's layout: strips hidden, bands, the six cells on the bands' columns ----------------------
function UTIL_CS.Strips(on)
  if not UTIL_CS.Exists(UTIL_CS.ROWS) then
    return
  end
  for k = 0, 4 do
    if UTIL_CS.IsOpen(UTIL_CS.ROWS, k) then
      funcLuaMenuCommand(UTIL_CS.C.LAYER_VISIBLE, UTIL_CS.ROWS, k, on)
    end
  end
end

-- band i shown (opened, its gauge parts hidden, our sprite in the frame, placed on BAND_RECT[i]) or hidden
function UTIL_CS.Band(i, on)
  local L, C = UTIL_CS.BAND, UTIL_CS.C
  if not UTIL_CS.Exists(L) then
    return
  end
  if not on then
    if UTIL_CS.IsOpen(L, i) then
      funcLuaMenuCommand(C.LAYER_VISIBLE, L, i, false)
    end
    return
  end
  if not UTIL_CS.IsOpen(L, i) then
    UTIL_CS.bandReady[i] = false
    funcLuaMenuCommand(C.OPEN_LAYER, L, i)
    return
  end
  if funcLuaMenuCommand(C.LOADING, L) == true then
    return
  end
  if not UTIL_CS.bandReady[i] then
    UTIL_CS.bandReady[i] = true
    pcall(funcLuaMenuCommand, C.TRACE, UTIL_CS.L_STATUS, 0, UTIL_CS.BAND_TRACE[i], true)
    for _, m in ipairs(UTIL_CS.BAND_HIDE) do
      funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, i)
    end
    funcLuaMenuCommand(C.SPRITE, L, UTIL_CS.TX_BTL0613, UTIL_CS.SP_BAND, UTIL_CS.SP_FRAME, 0, i)
    local r, f, o = UTIL_CS.BAND_RECT[i], UTIL_CS.FRAME, UTIL_CS.ORG
    local sx, sy = (r[3] - r[1]) / f[3], (r[4] - r[2]) / f[4]
    funcLuaMenuCommand(C.SCALE, L, sx, sy, 1, i)
    funcLuaMenuCommand(C.POS, L, r[1] - o[1] - f[1] * sx, o[2] - r[2] + f[2] * sy, 0, i)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, i, true)
end

function UTIL_CS.Layout()
  local C, o = UTIL_CS.C, UTIL_CS.ORG
  UTIL_CS.Strips(false)
  UTIL_CS.Band(0, true)
  UTIL_CS.Band(1, true)
  for r = 0, 1 do
    local band = UTIL_CS.BAND_RECT[r]
    local cy = (band[2] + band[4]) / 2
    for c = 0, 2 do
      local L, k = UTIL_CS.Cell(r, c)
      if UTIL_CS.IsOpen(L, k) then
        local dx = UTIL_CS.COL_X[c + 1] - (o[1] + UTIL_CS.CELL_X0 + UTIL_CS.CELL_DX * c)
        local dy = (o[2] + UTIL_CS.CELL_DY * r) - cy
        funcLuaMenuCommand(C.POS, L, dx, dy, 0, k)
      end
    end
  end
end

function UTIL_CS.Show(chara)
  if not UTIL_CS.PanelShow(true) then
    UTIL_CS.Log("cell layers missing (Utilities' menus\\102_team\\career.toml: util_cs_panel / util_cs_cell / util_cs_cellt)")
    return
  end
  UTIL_CS.shown = true
  UTIL_CS.Strips(false)
  local ok = UTIL_CS.Fill(chara)
  if not UTIL_CS.IfPlate() then
    UTIL_CS.Layout()
  end
  UTIL_CS.Log("show", chara or 0, ok and "data" or "no data")
end

function UTIL_CS.Hide()
  UTIL_CS.shown = false
  UTIL_CS.PanelShow(false)
  UTIL_CS.Band(0, false)
  UTIL_CS.Band(1, false)
end

function UTIL_CS.Mine(ptype)
  return ptype == UTIL_CS.TYPE
end

-- Inazuma Fantasy's plate (its EVT_PH_Decor: the dots / titles of its layout copy) or the retail one
function UTIL_CS.IfPlate()
  return type(EVT_PH_Decor) == "function"
end

function UTIL_CS.Current()
  return GetNowPageIdx ~= nil and GetNowPageIdx() == UTIL_CS.PAGE
end

-- the panel, the cells and the bands stay hidden unless our page is the current page (after every layer setup / open
-- and each frame; a cell opened by the engine with the group would otherwise show over another page)
function UTIL_CS.Guard()
  if GetNowPageIdx == nil or UTIL_CS.Current() then
    return
  end
  UTIL_CS.shown = false
  local C = UTIL_CS.C
  local n = {[UTIL_CS.PANEL] = 1, [UTIL_CS.CELLT] = UTIL_CS.ROW_CELLS[0], [UTIL_CS.CELL] = 0, [UTIL_CS.BAND] = 2}
  for r = 1, 4 do
    n[UTIL_CS.CELL] = n[UTIL_CS.CELL] + UTIL_CS.ROW_CELLS[r]
  end
  for _, L in ipairs({UTIL_CS.PANEL, UTIL_CS.CELL, UTIL_CS.CELLT, UTIL_CS.BAND}) do
    if UTIL_CS.Exists(L) then
      for k = 0, n[L] - 1 do
        if UTIL_CS.IsOpen(L, k) then
          funcLuaMenuCommand(C.LAYER_VISIBLE, L, k, false)
        end
      end
    end
  end
end

-- every frame on our page (retail plate): the bands finish loading, the strips stay hidden, the cells stay placed
function UTIL_CS.Frame()
  if not UTIL_CS.shown or UTIL_CS.IfPlate() or not UTIL_CS.Current() then
    return
  end
  UTIL_CS.Layout()
end

-- titles and dots of every page type (on IF's plate after EVT_PH_Decor; IF draws its page dots from the framework's
-- player page registry; on the retail plate the six-sense title gets its own sprite back on the other pages)
function UTIL_CS.Decor(ptype)
  if not UTIL_CS.Exists(UTIL_CS.L_STATUS) then
    return
  end
  local L, C = UTIL_CS.L_STATUS, UTIL_CS.C
  local mine = UTIL_CS.Mine(ptype)
  local ifp = UTIL_CS.IfPlate()
  funcLuaMenuCommand(C.MESH_VISIBLE, L, UTIL_CS.M_T_PARAM1, ptype == 1, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, UTIL_CS.M_T_PARAM2, ptype == 0, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, UTIL_CS.M_T_TEAMPASS, ptype == 2, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, UTIL_CS.M_DOT4_ON, ptype == 2, 0)
  if mine then
    funcLuaMenuCommand(C.SPRITE, L, UTIL_CS.TX_S1105, UTIL_CS.SP_TITLE, UTIL_CS.SP_SIXTH, 0, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L, UTIL_CS.M_SIXTH_TITLE, true, 0)
  elseif not ifp then
    funcLuaMenuCommand(C.SPRITE, L, UTIL_CS.TX_S1105, UTIL_CS.SP_SIXTH, UTIL_CS.SP_SIXTH, 0, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L, UTIL_CS.M_SIXTH_TITLE, ptype == 3, 0)
  end
end

function UTIL_CS.SelectedChara(fallback)
  local ch = 0
  if GetPersonalPlateSelectCharaStHdlAuto ~= nil then
    local ok, v = pcall(GetPersonalPlateSelectCharaStHdlAuto)
    if ok and type(v) == "number" then
      ch = v
    end
  end
  if ch == 0 and type(fallback) == "number" then
    ch = fallback
  end
  return ch
end

-- the other dots / titles first (IF's plate_hiper), then ours
function UTIL_CS.DecorAll(ptype)
  if UTIL_CS.IfPlate() then
    pcall(EVT_PH_Decor, ptype)
  else
    pcall(UTIL_CS.Decor, ptype)
  end
end

-- One page change (ChangePersonalPlatePageByCharaHdl / ...ByCharaParamId = `fname`, `orig` = what is under the
-- caller): page type 6 = the passives page layout with our rows over it; any other type: ours hidden.
-- Players without a save record (universe / opponent previews, ...ByCharaParamId): "Sin datos".
function UTIL_CS.PageChange(fname, orig, a1, a2, ...)
  if UTIL_CS.Mine(a2) then
    local r = orig(a1, 2, ...)
    UTIL_CS.DecorAll(a2)
    if fname == "ChangePersonalPlatePageByCharaParamId" then
      pcall(UTIL_CS.Show, 0)
      return r
    end
    local ch = UTIL_CS.SelectedChara(a1)
    if ch == 0 then
      pcall(UTIL_CS.Hide)                -- no player focused (empty slot): nothing of the page
      return r
    end
    local ok, err = pcall(UTIL_CS.Show, ch)
    if not ok then
      UTIL_CS.Log("show error", tostring(err))
    end
    return r
  end
  local r = orig(a1, a2, ...)
  pcall(UTIL_CS.Hide)
  if not UTIL_CS.IfPlate() then
    pcall(UTIL_CS.Decor, a2)
  end
  return r
end

UTIL_CS.Wrap("EVT_PH_Decor", function(orig)
  return function(ptype, ...)
    local r = orig(ptype, ...)
    pcall(UTIL_CS.Decor, ptype)
    return r
  end
end)

for _, fname in ipairs({"OnSetupLayer", "OnOpenLayer", "OnOpenEndLayer"}) do
  UTIL_CS.Wrap(fname, function(orig)
    return function(...)
      local r = orig(...)
      pcall(UTIL_CS.Guard)
      return r
    end
  end)
end

UTIL_CS.Wrap("PostStep", function(orig)
  return function(...)
    local r = orig(...)
    pcall(UTIL_CS.Guard)
    pcall(UTIL_CS.Frame)
    return r
  end
end)

-- the page changes: on Inazuma Fantasy's paged plate its plate_pages block calls UTIL_CS.PageChange from under its own
-- wrappers (EVT_PPG_CS_WRAPPED); anywhere else (the retail plate) here
if EVT_PPG_CS_WRAPPED == nil then
  for _, fname in ipairs({"ChangePersonalPlatePageByCharaHdl", "ChangePersonalPlatePageByCharaParamId"}) do
    UTIL_CS.Wrap(fname, function(orig)
      return function(a1, a2, ...)
        return UTIL_CS.PageChange(fname, orig, a1, a2, ...)
      end
    end)
  end
end

UTIL_CS.Wrap("UpdatePageInfo", function(orig)
  return function(...)
    local r = orig(...)
    if UTIL_CS.Current() then
      -- an empty slot (the formation / dock menus hide the plate, then call UpdatePageInfo) = nothing of the page; the
      -- page index stays and the next focused player redraws it
      local ch = UTIL_CS.SelectedChara(nil)
      if ch == 0 then
        pcall(UTIL_CS.Hide)
        return r
      end
      local ok, err = pcall(UTIL_CS.Show, ch)
      if not ok then
        UTIL_CS.Log("show error", tostring(err))
      end
    end
    return r
  end
end)

-- the plate's own next / previous page: the VR-Framework's player page registry steps them (VRFW_PlayerPages.Attach)
