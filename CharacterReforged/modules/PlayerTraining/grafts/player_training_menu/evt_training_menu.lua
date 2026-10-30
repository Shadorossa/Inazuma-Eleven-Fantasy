-- evt_training_menu (plain Lua 5.2 source, Expanded Victory Tool training_v1 test mod).
-- Classic training (Chrono Stone rules) replacing the beans: one bar per stat, Libertad at the top, radar preview.
-- Opened from the team dock's «Entrenamiento» row (graft player_training_dock) and from Inazuma Fantasy's «Entrenar»
-- button of the Supertécnicas screen (its graft training_btn). Rules, limits and storage are the mod Player Training's
-- (scripts\player_training.lua, CMND_EVT_TRAIN_* = aliases of CMND_PLAYERTRAINING_*); this script only draws and sends
-- the player's input.
-- 2026-09-28 (docs/game/mechanics/stat-training.md): rule «pool» (loader default): raising spends the free pool =
-- Libertad + points freed by lowering ANY stat; a stat stops at 1. Rows, bars, numbers and radar show the BASE stat
-- (base + trained points, no equipment / beans / board / Miximax). Texts: menu_text rows evt_tr_* in the 9 languages
-- (the mod's text\rows\training.toml).
-- Layers come from the bean pop-up (ability_learning_set_beans_menu_setting, lump window group), cloned by
-- research/scripts/tr_build.py:
--   win06_06_beans_lump_use_window  = the window (cloned layout: taller, 9 gauge locators, 10 new text nodes)
--   team13_16_beans_gauge x9        = one row per stat: icon, "value / max", bar
--   cmn03_10_sub_window_button      = "Guardar" (the focused layer: every input arrives here, see the setting)
--   win05_42 / soccer11_06 / soccer11_07 = status radar with the change preview (arrows)
-- Input (setting MENU_CMD_INFO): Enter = save + close, Back = close (asks when there are changes), Up/Down = row,
-- Left/Right = -1/+1 (holding it switches to 10 per step), L1/R1 = previous/next player of the team dock,
-- Function 1 = reset (untrained), Function 2 = toggle 1/10 per step.
-- Docs: docs/game/training-classic.md §6.
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_MENU_DEF")
INCLUDE("LUA_PERSONAL_PLATE_INC")

-- ---- vr-loader commands (docs/game/training-classic.md §4). Loader absent: a single false. -------------------------
local TR = {
  VERSION = @crc:CMND_EVT_LOADER_VERSION@,  -- () -> api, modules (bit 16 = training)
  INFO = 1924442262,         -- (hdl, fresh 0/1) -> ok, status, libTotal, libAvail, level, position, dirty, growth,
                             --   rule (0 pairs / 1 pool; nil = older loader = pairs)
  STAT = 2575656672,         -- (hdl, idx) -> ok, value, base, bonus, delta, committed, min, max, partner1, partner2
  SET = 3176787338,           -- (hdl, idx, newDelta) -> ok, stop (1 no room, 2 cap, 5 floor), reached, libAvail, d0..d8
  COMMIT = 3138149909,     -- (hdl) -> ok, status
  CANCEL = 2748233162,     -- (hdl or 0 = all) -> ok
  RESET = 2267631674,       -- (hdl) -> ok, libAvail
}
local MOD_TRAINING = 16
local MOD_STAMINA = 256          -- per-player PE in matches (module stamina): the header shows the PE max
local ERR_LOCKED = -9            -- TRAIN_* status of a Hero / Diamond / Prime card (training locked)

-- ---- texts: menu_text rows (9 languages, the mod's text\rows\training.toml) ----------------------------------
-- T(key, a, b, c, d) = the row with <VALUE>/<A> = a, <B> = b, <C> = c, <D> = d; "" when the row is missing
local TX = {
  TITLE = @crc:evt_tr_title@, TITLE_NONAME = @crc:evt_tr_title0@, POOL = @crc:evt_tr_pool@, LIBERTAD = @crc:evt_tr_lib@,
  LEVEL = @crc:evt_tr_level@, PE = @crc:evt_tr_pe@, PARTNER = @crc:evt_tr_partner@, HELP = @crc:evt_tr_help@,
  HELP10 = @crc:evt_tr_help10@, EMPTY = @crc:evt_tr_empty@, FLOOR = @crc:evt_tr_floor@, CAP = @crc:evt_tr_cap@,
  SAVE = 2306442081, NO_LOADER = @crc:evt_tr_no_loader@, NO_DATA = @crc:evt_tr_no_data@, LOCKED = @crc:evt_tr_locked@,
  ASK_DISCARD = @crc:evt_tr_ask_discard@, ASK_SAVE_SWITCH = @crc:evt_tr_ask_switch@, ASK_RESET = @crc:evt_tr_ask_reset@,
  SAVE_FAILED = @crc:evt_tr_save_failed@, SAVED_HINT = @crc:evt_tr_saved@,
  POS = {[1] = @crc:evt_tr_pos_1@, [2] = @crc:evt_tr_pos_2@, [3] = @crc:evt_tr_pos_3@, [4] = @crc:evt_tr_pos_4@},
  -- engine order: retail stat names (Potencia ... Agilidad) + ours (Rapidez, Suerte)
  STATS = {493890773, 3206121007, 3492422219, 3740714941, 2851206955, 2895498128, 3773956166, @crc:evt_tr_speed@,
           @crc:evt_tr_luck@},
}

-- ---- tweakables ---------------------------------------------------------------------------------------------------
local HOLD_GAP = 14          -- frames between two Left/Right events that still count as holding
local HOLD_REPEATS = 6       -- after this many repeats a step is 10 points
local WIN_X, WIN_Y = 640, -60        -- window position (retail bean pop-up: 960, -281)
local GRAPH_X, GRAPH_Y = 1500, -470  -- radar position (retail: 1612, -471)
local DIM = 0.55                     -- alpha of the rows that are neither selected nor partners (pairs rule)
local DIM_POOL = 0.8                 -- alpha of the other rows (pool rule: every row can give points)
-- PE max: IF's CMND_EVT_PE_MAX(Físico, hdl), per player since 2026-10-12. Since 2026-10-06 Físico does not change it (Físico slows
-- the PE drain instead, docs/game/mechanics/match-stamina.md §16); PE_FALLBACK = the default, for an older loader
local PE_FALLBACK = 120

-- ---- ids ----------------------------------------------------------------------------------------------------------
local MENU = 1107782452
-- 8 stats since 2026-09-30 (Rapidez retired): visible row k shows stat MAP[k] (rows 0-6 = stats 0-6, row 7 = Suerte,
-- stat 8). The window keeps its 9 locators / text nodes: the 9th stays empty (its gauge is never opened).
local ROWS = 8
local MAP = {[0] = 0, 1, 2, 3, 4, 5, 6, 8}
local function RowOf(i)
  for k = 0, ROWS - 1 do
    if MAP[k] == i then
      return k
    end
  end
  return 0
end
local L_WIN = 3668985814          -- win06_06_beans_lump_use_window
local L_GAUGE = 3356371999        -- team13_16_beans_gauge (9 instances in the layout, 8 used)
local L_BTN = 790585329           -- cmn03_10_sub_window_button
local L_GRAPH_WIN = 1437851054    -- win05_42_parameter_graph_base
local L_GRAPH_BASE = 1572892955   -- soccer11_06_formation_status_graph_base
local L_GRAPH_NUM = 732343773     -- soccer11_06_p1_formation_status_graph_param_num
local L_GRAPH = 3868632847        -- soccer11_07_formation_status_graph
local N_TITLE = 1460905569
local N_HEAD1 = 3457873883
local N_HEAD2 = 3105736525
local N_HELP = 2996469894
local N_ROW = {4066919363, 1801523833, 476455663, 2181216076, 4110780378,
               1812780640, 453764854, 2343893863, 4239641585}
local N_POS_WIN2 = 715239914      -- _pos_win02 (the retail "use N beans" block)
local N_POS_BEANS = 1296624974
local MESH_ICON = 3653430537
local P_NUM_CUR, P_NUM_NEXT, P_NUM_MAX = 3484572139, 1455097937, 1533119290   -- gauge number primitives
local R_GAUGE, R_GAUGE_RED, G_BAR = 1200811757, 2611748497, 1996459178         -- gauge01, gauge01_red, "bar"
local F = {UP = 2899828843, DOWN = 4238056847, LEFT = 2583947996, RIGHT = 1128810052,
           PREV = 1552319969, NEXT = 3830128008, RESET = 2803862557, STEP = 2749232008}
local KEY_HDL = 4161869490        -- retail bean menu key: the character (set by the board)
local KEY_DOCK_OK = 1227131323
local KEY_DOCK_NO = 1465023715
local KEY_DOCK_TYPE = 1490115725
local C = {
  TEXT = @crc:CMND_SET_MENU_TEXT_STRING@,          -- CMND_SET_MENU_TEXT_STRING (layer, node, string, idx)
  TEXT_GET = @crc:CMND_TEXT_GET@,      -- CMND_TEXT_GET (text id) -> string
  TEXT_ALPHA = @crc:CMND_SET_MENU_TEXT_ALPHA@,    -- (layer, idx, node, alpha)
  MODEL_ALPHA = @crc:CMND_SET_LAYER_MODEL_ALPHA@,   -- (layer, idx, 0, alpha)
  NODE_VISIBLE = 2158717427,  -- (layer, node, bool, idx)
  MESH_VISIBLE = @crc:CMND_SET_MESH_VISIBLE@,  -- (layer, mesh, bool, idx)
  SPRITE = 558735651,         -- (layer, textureCrc, spriteCrc, nodeCrc, 0, idx)
  LOCAL_POS = @crc:CMND_SET_LAYER_LOCAL_POS@,     -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z)
  PRIORITY = @crc:CMND_SET_DRAW_PRIORITY@,      -- CMND_SET_DRAW_PRIORITY (layer, idx, prio, bool)
  PRIM_INDEX = @crc:CMND_SEARCH_PRIM_INDEX@,    -- (layer, idx, primName) -> prim
  PRIM_VALUE = 3609943765,    -- (layer, idx, prim, value, true)
  PRIM_VISIBLE = 1233047821,  -- (layer, idx, primName, bool)
  GROUP_INDEX = @crc:CMND_GET_GROUP_INDEX@,    -- (layer, idx, group) -> group index
  RATE_BIND = 541357333,      -- (layer, rate, groupIndex, idx)
  RATE_SET = 1595998683,      -- (layer, rate, 0, ratio, idx, false, group)
  CHARA_GET = 1131797651,     -- 0x4375DC93 (hdl, kind, true, excl90): kinds 14..20 = shown stat 0..6
  CHARA_NAME = @crc:CMND_GET_CHARA_NAME_TEXT@,    -- CMND_GET_CHARA_NAME_TEXT (hdl) -> string
  TEAM_INFO = @crc:CMND_GET_TEAM_SET_INFO@,     -- CMND_GET_TEAM_SET_INFO (dock, type, 0) -> ok, memberCount
  TEAM_MEMBER = 1720957768,   -- (dock, type, i, 0) -> ok, charaStHdl
  SE = @crc:CMND_SND_PLAY_SE@,
  MENU_ACTIVE = 1558704558,   -- (menu, bool)
  CLOSE_MENU = @crc:CMND_CLOSE_MENU_OBJECT@,     -- CMND_CLOSE_MENU_OBJECT
  MSG_OPEN = 2289627655, MSG_KIND = 2351835063, MSG_BUSY = 898725220, MSG_RESULT = 1523741473, MSG_DONE = 682363669,
}
local SE_MOVE, SE_OK, SE_DECIDE, SE_BACK, SE_NG = 541750771, 3848881948, 4235359837, 202039849, 2086672038
local ICON_TEX = 502529699        -- #/menu/200_icon/15_icon_common/<LG>/icon_common.g4tx
local ICON_NODE = 1677943612      -- icon_parameter_dmy01

-- ---- state --------------------------------------------------------------------------------------------------------
local loader = false
local players = {}
local cur = 1                     -- index in players
local hdl = 0
local name = ""
local info = {ok = false}
local st = {}                     -- st[i] (i = 0..8): value, base, bonus, delta, committed, min, max, p1, p2
local hint = nil                  -- one-shot help line after a refused step (pool empty / floor / cap)
local sel = 0                     -- selected row (engine index)
local step10 = false
local frame, lastDir, lastFrame, rep = 0, 0, -100, 0
local evt_co = nil
local closing = false
local saved_hint_shown = false
local gauges_ready = {}

-- ---- helpers ------------------------------------------------------------------------------------------------------
--@lib evt_menu_kit.lua#Call

-- errors go to evt_loader\loader.log (CMND_EVT_LOG) and the Lua console
local function Log(msg)
  pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, "evt_training_menu", tostring(msg))
  pcall(print, "evt_training_menu: " .. tostring(msg))
end

--@lib evt_menu_kit.lua#Int

local function Signed(v)
  if v > 0 then
    return "+" .. v
  end
  return tostring(v)
end

-- menu_text row `id` with <VALUE>/<A>..<D> replaced; "" when the row is missing
local function Fill(s, a, b, c, d)
  local map = {VALUE = a, A = a, B = b, C = c, D = d}
  return (string.gsub(s, "<(%u+)>", function(k)
    local v = map[k]
    if v == nil then
      return nil
    end
    return tostring(v)
  end))
end

local function RowText0(id)
  local ok, s = pcall(funcLuaCommand, C.TEXT_GET, id)
  if ok and type(s) == "string" and s ~= "" then
    return s
  end
  return ""
end

local function T(key, a, b, c, d)
  return Fill(RowText0(TX[key]), a, b, c, d)
end

local function StatName(i)
  return RowText0(TX.STATS[i + 1])
end

local function PosName(p)
  if TX.POS[p] == nil then
    return ""
  end
  return RowText0(TX.POS[p])
end

local function Param(key)
  if VRFW_Param.Has(key) then
    local v = VRFW_Param.Get(key)
    VRFW_Param.Clear(key)
    return v
  end
  return nil
end

local pe_on = false               -- module stamina reported by the loader

local function LoaderReady()
  local api, mods = Call(TR.VERSION)
  pe_on = type(mods) == "number" and math.floor(mods / MOD_STAMINA) % 2 == 1
  return type(api) == "number" and type(mods) == "number" and math.floor(mods / MOD_TRAINING) % 2 == 1
end

local function PeMax(fisico)
  -- the max PE is per player (IF content\match_resources\pe_max.toml): the character's handle names his card
  local ok, max = Call(@crc:CMND_EVT_PE_MAX@, fisico, hdl)
  if ok == true and type(max) == "number" and max > 0 then
    return math.floor(max + 0.5)
  end
  return PE_FALLBACK
end

-- "   PE 120": the match PE max (the same for every Físico since 2026-10-06, so no "(+n)" any more; kept for a
-- [stamina] that would make it vary again)
local function PeText()
  local f = st[4]
  if not pe_on or f == nil or f.value <= 0 then
    return ""
  end
  local now = PeMax(f.value)
  local saved = PeMax(f.value - (f.delta - f.committed))
  local t = "   " .. T("PE", now)
  if now ~= saved then
    t = t .. " (" .. Signed(now - saved) .. ")"
  end
  return t
end

local function Text(node, s)
  funcLuaMenuCommand(C.TEXT, L_WIN, node, s, 0)
end

-- ---- data -----------------------------------------------------------------------------------------------------------
local function ReadInfo()
  local ok, status, total, avail, level, pos, dirty, _, rule = Call(TR.INFO, hdl, 0)
  info = {ok = ok == true, status = Int(status), total = Int(total), avail = Int(avail), level = Int(level),
          pos = Int(pos), dirty = dirty == true, pool = Int(rule) == 1}
end

local function ReadStats()
  for i = 0, 8 do                  -- every stat slot (7 = retired Rapidez: never shown)
    local ok, v, b, bo, d, cd, mn, mx, p1, p2 = Call(TR.STAT, hdl, i)
    if ok == true then
      st[i] = {value = Int(v), base = Int(b), bonus = Int(bo), delta = Int(d), committed = Int(cd), min = Int(mn),
               max = Int(mx), p1 = Int(p1), p2 = Int(p2)}
    else
      st[i] = {value = 0, base = 0, bonus = 0, delta = 0, committed = 0, min = 0, max = 0, p1 = -1, p2 = -1}
    end
  end
end

-- the value this menu shows and edits: the BASE stat with the working training (no equipment / beans / board)
local function Ev(s)
  return s.base + s.delta
end

-- ... and with the saved training
local function EvSaved(s)
  return s.base + s.committed
end

-- bar scale: common to the 8 rows, only grows while a player is shown
local scale = 100
local function UpdateScale(reset)
  local m = 0
  for i = 0, 8 do
    local s = st[i]
    if s then
      m = math.max(m, Ev(s), EvSaved(s))
    end
  end
  local want = math.max(100, math.ceil(m * 1.15 / 50) * 50)
  if reset or want > scale then
    scale = want
  end
end

-- ---- drawing --------------------------------------------------------------------------------------------------------
local function IsPartner(i)
  if info.pool then
    return false                  -- pool rule: no pairs
  end
  local s = st[sel]
  return s ~= nil and (s.p1 == i or s.p2 == i)
end

local function RowAlpha(i)
  if i == sel or IsPartner(i) then
    return 1.0
  end
  return info.pool and DIM_POOL or DIM
end

-- "> Potencia   +12  (+3)": trained points (saved + pending) and the pending change
local function RowText(i)
  local s = st[i]
  local t = (i == sel and "> " or "   ") .. StatName(i)
  if s.delta ~= 0 then
    t = t .. "   " .. Signed(s.delta)
  end
  if s.delta ~= s.committed then
    t = t .. "  (" .. Signed(s.delta - s.committed) .. ")"
  end
  if i ~= sel and IsPartner(i) then
    t = t .. "  " .. T("PARTNER")
  end
  return t
end

local function SetPrim(i, prim, value, visible)
  local p = funcLuaMenuCommand(C.PRIM_INDEX, L_GAUGE, i, prim)
  if p ~= nil then
    funcLuaMenuCommand(C.PRIM_VALUE, L_GAUGE, i, p, value, true)
  end
  funcLuaMenuCommand(C.PRIM_VISIBLE, L_GAUGE, i, prim, visible)
end

local function DrawGauge(k)       -- k = visible row = gauge instance
  if not gauges_ready[k] then
    return
  end
  local i = MAP[k] or k
  local s = st[i]
  if s == nil then
    return
  end
  local v = Ev(s)                                  -- base stat with the working training
  local old = EvSaved(s)                           -- ... with the saved training
  local top = s.base + s.max                       -- highest base value reachable from here
  SetPrim(k, P_NUM_CUR, math.max(0, v), v <= old)
  SetPrim(k, P_NUM_NEXT, math.max(0, v), v > old)
  SetPrim(k, P_NUM_MAX, math.max(0, top), true)
  local r = math.max(0, math.min(1, v / scale))
  local r_old = math.max(0, math.min(1, old / scale))
  funcLuaMenuCommand(C.RATE_SET, L_GAUGE, R_GAUGE, 0, r, k, false, G_BAR)
  funcLuaMenuCommand(C.RATE_SET, L_GAUGE, R_GAUGE_RED, 0, math.max(r, r_old), k, false, G_BAR)
  funcLuaMenuCommand(C.MODEL_ALPHA, L_GAUGE, k, 0, RowAlpha(i))
end

local function Title()
  if name ~= "" then
    return T("TITLE", name)
  end
  return T("TITLE_NONAME")
end

-- pool header: "Puntos libres: 35   (Libertad 120 · subido 100 · bajado 15)"; pairs: "Libertad libre: 35 / 120"
local function Head1()
  if not info.pool then
    return T("LIBERTAD", info.avail, info.total)
  end
  local up, down = 0, 0
  for i = 0, 8 do
    local s = st[i]
    if s ~= nil then
      if s.delta > 0 then
        up = up + s.delta
      else
        down = down - s.delta
      end
    end
  end
  return T("POOL", info.avail, info.total, up, down)
end

local function Head2()
  local t = T("LEVEL", info.level)
  if not info.pool then
    t = t .. " - " .. PosName(info.pos)  -- the pairs depend on the position
  end
  return t .. PeText()
end

local function DrawTexts()
  if not loader or not info.ok then
    Text(N_TITLE, loader and Title() or T("NO_LOADER"))
    Text(N_HEAD1, loader and (info.status == ERR_LOCKED and T("LOCKED") or T("NO_DATA")) or "")
    Text(N_HEAD2, "")
    Text(N_HELP, "")
    for k = 0, ROWS - 1 do
      Text(N_ROW[k + 1], "   " .. StatName(MAP[k]))
    end
    if N_ROW[ROWS + 1] then
      Text(N_ROW[ROWS + 1], "")
    end
    return
  end
  Text(N_TITLE, Title())
  Text(N_HEAD1, Head1())
  Text(N_HEAD2, Head2())
  Text(N_HELP, hint or (step10 and T("HELP10") or T("HELP")))
  for k = 0, ROWS - 1 do
    Text(N_ROW[k + 1], RowText(MAP[k]))
    funcLuaMenuCommand(C.TEXT_ALPHA, L_WIN, 0, N_ROW[k + 1], RowAlpha(MAP[k]))
  end
  if N_ROW[ROWS + 1] then
    Text(N_ROW[ROWS + 1], "")      -- the layout's 9th row (ex Rapidez)
  end
end

-- radar: BASE stats (base + saved training) + the pending change (engine types 0..7; the radar draws 0..6). The retail
-- function draws "stat without beans" + a4 (+ a5 - a4 as the arrow), so a4 / a5 are offsets from that value to the
-- base stat with the saved / working training: the numbers show exactly the bars' values.
local function DrawGraph()
  if hdl == 0 or not info.ok or UpdateCharaParameterGraphNextBeansByCharaStHdl == nil then
    return
  end
  local a4, a5 = {}, {}
  for t = 0, 7 do
    local s = st[t] or {base = 0, delta = 0, committed = 0}
    if t < 7 then
      local nob = Int(funcLuaCommand(C.CHARA_GET, hdl, 14 + t, true, true))
      a4[t + 1] = EvSaved(s) - nob
      a5[t + 1] = Ev(s) - nob
    else
      a4[t + 1] = 0
      a5[t + 1] = 0
    end
  end
  local ok, err = pcall(UpdateCharaParameterGraphNextBeansByCharaStHdl, L_GRAPH, L_GRAPH_NUM, hdl, a4, a5, L_GRAPH_BASE)
  if not ok then
    Log("evt_training_menu graph: " .. tostring(err))
  end
end

local function Redraw(reset_scale)
  UpdateScale(reset_scale)
  DrawTexts()
  for i = 0, ROWS - 1 do
    DrawGauge(i)
  end
  DrawGraph()
end

local function Refresh(reset_scale)
  ReadInfo()
  if info.ok then
    ReadStats()
  end
  Redraw(reset_scale)
end

local function LoadPlayer(h, fresh)
  hdl = h or 0
  name = ""
  if hdl ~= 0 then
    local n = Call(C.CHARA_NAME, hdl)
    if type(n) == "string" then
      name = n
    end
  end
  if loader and hdl ~= 0 then
    Call(TR.INFO, hdl, fresh and 1 or 0)
  end
  Refresh(true)
end

local function BuildPlayers(first)
  players = {}
  local seen = {}
  local function add(h)
    if type(h) == "number" and h ~= 0 and not seen[h] then
      seen[h] = true
      players[#players + 1] = h
    end
  end
  local dockOk = Param(KEY_DOCK_OK)
  local dockNo = Param(KEY_DOCK_NO)
  local dockType = Param(KEY_DOCK_TYPE)
  if dockOk == 1 and type(dockNo) == "number" and type(dockType) == "number" then
    local ok, count = Call(C.TEAM_INFO, dockNo, dockType, 0)
    if ok == true and type(count) == "number" then
      for i = 0, count - 1 do
        local ok2, h = Call(C.TEAM_MEMBER, dockNo, dockType, i, 0)
        if ok2 == true then
          add(h)
        end
      end
    end
  end
  -- first = 0 (opened from the team dock): the first member of the dock
  if type(first) == "number" and first ~= 0 and not seen[first] then
    table.insert(players, 1, first)
    seen[first] = true
  end
  if #players == 0 then
    players[1] = 0
  end
  cur = 1
  for k, h in ipairs(players) do
    if h == first then
      cur = k
    end
  end
end

-- ---- dialogs (retail general window pattern) --------------------------------------------------------------------------
local function Ask(text)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  funcLuaCommand(C.MSG_KIND, 2, 0)
  coroutine.yield()
  while funcLuaCommand(C.MSG_BUSY) do
    coroutine.yield()
  end
  local r = -1
  while r == nil or r < 0 do
    r = funcLuaCommand(C.MSG_RESULT)
    coroutine.yield()
  end
  while not funcLuaCommand(C.MSG_DONE) do
    coroutine.yield()
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  return r == 0
end

local function Say(text)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  coroutine.yield()
  while funcLuaCommand(C.MSG_BUSY) do
    coroutine.yield()
  end
  while not funcLuaCommand(C.MSG_DONE) do
    coroutine.yield()
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
end

local function Run(f, ...)
  if evt_co ~= nil or closing then
    return
  end
  evt_co = coroutine.create(f)
  local ok, err = coroutine.resume(evt_co, ...)
  if not ok then
    Log("evt_training_menu: " .. tostring(err))
    evt_co = nil
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  elseif coroutine.status(evt_co) == "dead" then
    evt_co = nil
  end
end

-- ---- actions --------------------------------------------------------------------------------------------------------
local function Commit()
  if not info.ok or not info.dirty then
    return true
  end
  local ok, status = Call(TR.COMMIT, hdl)
  if ok ~= true then
    Say(T("SAVE_FAILED", Int(status)))
    return false
  end
  return true
end

local function Close()
  closing = true
  Call(TR.CANCEL, 0)             -- drop every working copy of this menu
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.CLOSE_MENU, MENU)
end

local function DoSave()
  local dirty = info.ok and info.dirty
  if Commit() then
    funcLuaCommand(C.SE, SE_DECIDE)
    if dirty and not saved_hint_shown then
      saved_hint_shown = true
      Say(T("SAVED_HINT"))
    end
    Close()
  end
end

local function DoBack()
  if info.ok and info.dirty then
    funcLuaCommand(C.SE, SE_OK)
    if not Ask(T("ASK_DISCARD")) then
      return
    end
  end
  funcLuaCommand(C.SE, SE_BACK)
  Close()
end

local function DoSwitch(dir)
  if #players < 2 then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  if info.ok and info.dirty then
    if Ask(T("ASK_SAVE_SWITCH", name)) then
      if not Commit() then
        return
      end
    else
      Call(TR.CANCEL, hdl)
    end
  end
  cur = (cur - 1 + dir) % #players + 1
  funcLuaCommand(C.SE, SE_MOVE)
  LoadPlayer(players[cur], true)
end

local function DoReset()
  if not info.ok then
    return
  end
  if Ask(T("ASK_RESET", name)) then
    Call(TR.RESET, hdl)
    funcLuaCommand(C.SE, SE_OK)
    Refresh(false)
  end
end

local function StepRow(dir)
  hint = nil
  sel = MAP[(RowOf(sel) + dir) % ROWS]
  funcLuaCommand(C.SE, SE_MOVE)
  Redraw(false)
end

local function StepValue(dir)
  if not info.ok then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  if dir == lastDir and frame - lastFrame <= HOLD_GAP then
    rep = rep + 1
  else
    rep = 0
  end
  lastDir, lastFrame = dir, frame
  local amount = (step10 or rep >= HOLD_REPEATS) and 10 or 1
  local s = st[sel]
  local ok, stop, reached = Call(TR.SET, hdl, sel, s.delta + dir * amount)
  if type(reached) ~= "number" or Int(reached) == s.delta then
    funcLuaCommand(C.SE, SE_NG)
  else
    funcLuaCommand(C.SE, SE_MOVE)
  end
  -- why it stopped (also after a partial 10-point step): pool empty / floor / cap
  hint = nil
  stop = Int(stop)
  if ok ~= true and stop == 1 and info.pool then
    hint = T("EMPTY")
  elseif ok ~= true and stop == 5 then
    hint = T("FLOOR", StatName(sel), s.base + s.min)
  elseif ok ~= true and stop == 2 then
    hint = T("CAP", StatName(sel), s.base + s.max)
  end
  Refresh(false)
end

-- ---- engine callbacks -----------------------------------------------------------------------------------------------
function OnInit()
  SetGraphLayerNameAndIdx(L_GRAPH_BASE, 0, L_GRAPH, 0, L_GRAPH_NUM)
  loader = LoaderReady()
  local h = Param(KEY_HDL)
  BuildPlayers(type(h) == "number" and h or 0)
  if loader and players[cur] ~= 0 then
    LoadPlayer(players[cur], true)
  else
    hdl = players[cur] or 0
    info = {ok = false}
  end
end

function OnSetupLayer(a1, a2)
  if a1 == L_WIN then
    funcLuaMenuCommand(C.LOCAL_POS, a1, WIN_X, WIN_Y, 0)
    funcLuaMenuCommand(C.NODE_VISIBLE, a1, N_POS_WIN2, false, a2)
    funcLuaMenuCommand(C.NODE_VISIBLE, a1, N_POS_BEANS, false, a2)
    DrawTexts()
  elseif a1 == L_BTN then
    funcLuaMenuCommand(C.TEXT, a1, 2921358143 --[[_text_cmd_btn01]], funcLuaCommand(C.TEXT_GET, 2750714971), 0)
    funcLuaMenuCommand(C.TEXT, a1, 950238781 --[[_text_btn01]], T("SAVE"), 0)
  elseif a1 == L_GRAPH_BASE then
    funcLuaMenuCommand(C.PRIORITY, a1, a2, 846, true)
  elseif a1 == L_GRAPH_NUM or a1 == L_GRAPH then
    funcLuaMenuCommand(C.PRIORITY, a1, a2, 847, true)
  end
end

function OnOpenLayer(a1, a2)
  if a1 == L_GRAPH_WIN then
    funcLuaMenuCommand(C.LOCAL_POS, a1, GRAPH_X, GRAPH_Y, 0)
  elseif a1 == L_GAUGE then
    if a2 == nil or a2 < 0 or a2 >= ROWS then
      if a2 ~= nil and a2 >= ROWS then
        funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, a1, a2, false)   -- the 9th gauge (ex Rapidez)
      end
      return
    end
    local icon = a2 < 7 and MENU_DEF.GetStatusParamIconName(a2) or 0
    if icon ~= 0 then
      funcLuaMenuCommand(C.SPRITE, a1, ICON_TEX, icon, ICON_NODE, 0, a2)
    else
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, MESH_ICON, false, a2)   -- row 7 = Suerte: no retail icon
    end
    local g = funcLuaMenuCommand(C.GROUP_INDEX, a1, a2, G_BAR)
    funcLuaMenuCommand(C.RATE_BIND, a1, R_GAUGE, g, a2)
    funcLuaMenuCommand(C.RATE_BIND, a1, R_GAUGE_RED, g, a2)
    gauges_ready[a2] = true
    DrawGauge(a2)
  elseif a1 == L_GRAPH then
    DrawGraph()
  elseif a1 == L_WIN then
    DrawTexts()
  end
end

function OnDecideFocus(a1, a2)
  if a1 == L_BTN then
    Run(DoSave)
  end
end

function OnEnter(a1, a2)
  if a1 == L_BTN then
    Run(DoSave)
    return 1
  end
end

function OnBack(a1)
  Run(DoBack)
  return 1
end

function OnFunction(a1, a2)
  if evt_co ~= nil or closing then
    return
  end
  if a1 == F.UP then
    StepRow(-1)
  elseif a1 == F.DOWN then
    StepRow(1)
  elseif a1 == F.LEFT then
    StepValue(-1)
  elseif a1 == F.RIGHT then
    StepValue(1)
  elseif a1 == F.PREV then
    Run(DoSwitch, -1)
  elseif a1 == F.NEXT then
    Run(DoSwitch, 1)
  elseif a1 == F.RESET then
    Run(DoReset)
  elseif a1 == F.STEP then
    hint = nil
    step10 = not step10
    funcLuaCommand(C.SE, SE_OK)
    DrawTexts()
  end
end

function Step()
  frame = frame + 1
  if evt_co ~= nil then
    if coroutine.status(evt_co) == "dead" then
      evt_co = nil
    else
      local ok, err = coroutine.resume(evt_co)
      if not ok then
        Log("evt_training_menu: " .. tostring(err))
        evt_co = nil
        funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
      elseif coroutine.status(evt_co) == "dead" then
        evt_co = nil
      end
    end
  end
end
