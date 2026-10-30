-- evt_rogue_coach_menu (plain Lua 5.2 source, Inazuma Fantasy, INAROGUE coach selector): docs/game/modes/inarogue.md
-- «Entrenadores». Opened by evt_inarogue_menu as a child before a NEW run starts (graft rogue_coaches, irm_coach.lua);
-- the coach picked is the run's «class» (loader module rogue: CMND_EVT_RL_COACH_*; catalogue rogue\coaches.toml).
-- One row of cards (more coaches = more rows): the coach's retail bust (face icon over his kit-bust icon) on a card, the name plate under it; a locked coach
-- = dark card, darkened face, lock; its unlock rule (with progress) in the guide line. The tagline goes to the guide
-- line only when the data has one. Keys / pad: arrows move, Aceptar picks (a locked coach: the rule in a window),
-- Atrás = no new run. Mouse and the free cursor: the shared pointer helper (evt_menu_kit.lua#Pointer): hover focuses,
-- click picks. Result (parameter KEY_RESULT): 1 = picked (the loader holds the pick for the run starting now), 0 = back.
-- Art: evt_rogue_coach.g4tx (research/scripts/rogue_coaches_build.py; G = its GEOM) + the route map's backdrop.
-- Screen (menus\rogue_coaches.toml): the «Guardar» frame + the route map's quad objects as pools.
-- Rule (position-cards.md §4b): no engine call at top level; funcLuaCommand only exists inside callbacks.
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_SAVEDATA_MANAGEMENT_MENU_INC")   -- header helpers (soccer top inc) + general window inc

-- texts: InaRogue text\rows\rogue_screens.toml (read with Text); GUIDE / GUIDE_TAG are the same in every language
local TXT = {
  TITLE = {3709542452 --[[InaRogue.coach.title]]},
  GUIDE = "%s",
  GUIDE_TAG = "%s   ·   %s",
  LOCKED = {300984748 --[[InaRogue.coach.locked]]},
  LOCKED_MSG = {2331592520 --[[InaRogue.coach.locked_msg]]},
  ERROR = {2884690990 --[[InaRogue.coach.error]]},
}

local MENU = 3869270721           -- crc32("evt_rogue_coach_menu")
local KEY_RESULT = 123230196      -- crc32("evt_rogue_coach"): 1 picked, 0 back

local RL = {
  LOG = @crc:CMND_EVT_LOG@,          -- CMND_EVT_LOG
  LIST = @crc:CMND_EVT_RL_COACH_LIST@,         -- CMND_EVT_RL_COACH_LIST (-1) -> count, runIndex, pickIndex, enabled
                             --   (i) -> ok, id, name, tagline, face, unlocked, hint, param
  PICK = @crc:CMND_EVT_RL_COACH_PICK@,          -- CMND_EVT_RL_COACH_PICK (i) -> code
}

-- ---- layers ---------------------------------------------------------------------------------------------------------
-- Pools (menus\rogue_coaches.toml; counts written by rogue_coaches_build.py from GEOM: MAX_CARDS cards)
local L_ROW = 3455690937        -- save01_02_list_item (1 instance: the input anchor, off screen)
local L_HEADER = 575058101      -- mainmenu90_01_header
local L_GUIDE_LINE = 3078308064 -- mainmenu90_05_content_guide_line01
local L_CURSOR = 2296367164     -- cmn05_01_cursor (hidden: the card ring is the cursor)
local L_BTN_GUIDE = 1138543975  -- mainmenu01_06_base_button_guide
local L_BTN = 9396745           -- mainmenu01_07_button_guide
local L_RET = 2005383485        -- mainmenu01_10_return_arrow_button_guide
local L_BG = 16936625           -- evt_rogue_map_bg     x1           (draw priority 451) backdrop
local L_CARD = 3418775405       -- evt_rogue_map_plat   x MAX_CARDS  (455) card plates
local L_FACE = 846827650        -- evt_rogue_map_emb    x MAX_CARDS  (457) faces
local L_TAG = 4081246790        -- evt_rogue_map_tag    x 2 per card (458) name plate, lock
local L_UI = 3745054265         -- evt_rogue_map_hint   x 2          (459) 0 cursor ring
local N_PER_CARD = 2

local C = {
  TEXT = @crc:CMND_SET_MENU_TEXT_STRING@, MESH_VISIBLE = @crc:CMND_SET_MESH_VISIBLE@, LAYER_VISIBLE = @crc:CMND_SET_LAYER_VISIBLE@,
  SPRITE = 558735651,         -- (layer, textureCrc, spriteCrc, nodeCrc, 0, idx)
  LOAD_TEX = @crc:CMND_LOAD_MENU_RES_TEXTURE@,
  SCALE = @crc:CMND_SET_LAYER_LOCAL_SCALE@,
  POS = @crc:CMND_SET_LAYER_LOCAL_POS@,
  ATTACH_TRACE = @crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@,
  OPEN_LAYER = @crc:CMND_OPEN_LAYER@,
  FOCUS_ENABLE = @crc:CMND_SET_ENABLE_CTRL_FOCUS@, FOCUS_SET = 3466097042, LIST_NUM = 3252599449,
  GUIDE_SET = 2209673388, GUIDE_CMD = 452337289, GUIDE_OPT = 1432240275,
  SE = @crc:CMND_SND_PLAY_SE@, MENU_ACTIVE = 1558704558, CLOSE_MENU = @crc:CMND_CLOSE_MENU_OBJECT@,
  FADE = 609722083, FADE_DONE = 2259183189,
  MSG_OPEN = 2289627655, MSG_KIND = 2351835063, MSG_RESULT = 1523741473, MSG_DONE = 682363669, MSG_BUSY = 898725220,
  TEXT_VISIBLE = @crc:CMND_SET_MENU_TEXT_VISIBLE@,
  PRIM_COLOR = @crc:CMND_SET_PRIM_COLOR@,     -- CMND_SET_PRIM_COLOR (layer, idx, meshCrc, r, g, b)
}
local MESH_QUAD = 312193881     -- the cmn01_10 quad's mesh
local NODE_QUAD = 1909474081    -- icon_new01 (the cmn01_10 quad's sprite node)
local CUR = 3313461902          -- crc32("cursor")
local FN = {UP = 2270326752, DOWN = 4144065873, LEFT = 2442729986, RIGHT = 424018863}
local G_ACCEPT = 1847312674 --[[Aceptar]]
local I_ENTER = 2750714971 --[[<CMD_ENTER>]]
local K_ENTER = 1981080283
local SE_OK, SE_DECIDE, SE_BACK = 3848881948, 4235359837, 202039849
local SE_NG = SE_BACK
local ROW_MESHES = {3025401186, 486732393, 376662541, 3232607807, 1516082254, 3292070381, 1712955010}
local MODE_ICON_NODE = 3293713115

local TEX_UI = "#/menu/220_img/evt_rogue/evt_rogue_coach.g4tx"
local TEX_MAP = "#/menu/220_img/evt_rogue/evt_rogue_map.g4tx"
-- rogue_coaches_build.py GEOM (screen px, y down)
local G = {Q = 36, CARD_W = 256, CARD_H = 352, DX = 284, DY = 392, COLS = 6, MAX_CARDS = 12, AREA_Y = 250,
           AREA_H = 800, FACE = 240, FACE_Y = -16, NAME_W = 236, NAME_H = 44, NAME_Y = 128, LOCK_W = 64,
           LOCK_H = 78, RING_W = 284, RING_H = 380}
local DARK = {0.18, 0.18, 0.24}
local LIGHT = {1, 1, 1}

-- ---- state ----------------------------------------------------------------------------------------------------------
local list = {}        -- [1..n] = {i, id, name, tagline, face, open, hint}
local pos = {}         -- [1..n] = {x, y} card centres
local focus = 1
local ready = false
-- the input that opened this screen (Accept / click on the INAROGUE menu) must not reach it: Back, decide and clicks
-- are swallowed until the screen is live and 20 frames more (Nacho 07/10: a child screen closed itself on its
-- first open)
local open_guard = 20           -- frames (reset to 20 in OnInit)
local evt_co = nil

local function Log(...)
  pcall(funcLuaCommand, RL.LOG, "rogue_coach", ...)
end

--@lib evt_menu_kit.lua#Call,Int,Hide

-- a text row in the game's language with {1}.. filled ("" when missing)
local function Text(key, ...)
  local s = Call(@crc:CMND_TEXT_GET@, key[1])
  if type(s) ~= "string" then
    return ""
  end
  local a = table.pack(...)
  return (s:gsub("{(%d)}", function(k)
    local v = a[tonumber(k)]
    return v == nil and "" or tostring(v)
  end))
end

-- pointer (mouse / free cursor): hover = the keys' selection, click = pick
--@lib evt_menu_kit.lua#Pointer
local Ptr = EVT_PointerNew()

local function Place(layer, idx, x, y)
  funcLuaMenuCommand(C.POS, layer, x, -y, 0, idx)
end

local function UI(layer, idx, sprite, x, y, w, h)
  funcLuaMenuCommand(C.LAYER_VISIBLE, layer, idx, true)
  funcLuaMenuCommand(C.SCALE, layer, w / G.Q, h / G.Q, 1, idx)
  funcLuaMenuCommand(C.SPRITE, layer, CRC32(TEX_UI), CRC32(sprite), NODE_QUAD, 0, idx)
  Place(layer, idx, x, y)
end

local function Tint(layer, idx, c)
  funcLuaMenuCommand(C.PRIM_COLOR, layer, idx, MESH_QUAD, c[1], c[2], c[3])
end

-- ---- data / layout (rogue_coaches_build.py layout) -------------------------------------------------------------------
local function Layout()
  pos = {}
  local n = math.min(#list, G.MAX_CARDS)
  local rows = math.max(1, math.ceil(n / G.COLS))
  local y0 = G.AREA_Y + (G.AREA_H - ((rows - 1) * G.DY + G.CARD_H)) / 2 + G.CARD_H / 2
  for i = 1, n do
    local r = math.floor((i - 1) / G.COLS)
    local in_row = math.min(G.COLS, n - r * G.COLS)
    local k = (i - 1) % G.COLS
    pos[i] = {960 + (k - (in_row - 1) / 2) * G.DX, y0 + r * G.DY}
  end
end

local function ReadList()
  list = {}
  local n, _, pick = Call(RL.LIST, -1)
  for i = 0, Int(n) - 1 do
    local ok, id, name, tagline, face, open, hint = Call(RL.LIST, i)
    if ok == true then
      list[#list + 1] = {i = i, id = id, name = name or "?", tagline = tagline or "", face = face or "",
                         open = open == true, hint = hint or ""}
    end
  end
  focus = math.max(1, math.min(#list, Int(pick) + 1))
  Layout()
end

-- ---- drawing --------------------------------------------------------------------------------------------------------
local function DrawCard(i)
  local a, p = list[i], pos[i]
  local s = i - 1
  local x, y = p[1], p[2]
  UI(L_CARD, s, a.open and "co_card_lit" or "co_card_dark", x, y, G.CARD_W, G.CARD_H)
  UI(L_FACE, s, "co_face_" .. a.face, x, y + G.FACE_Y, G.FACE, G.FACE)   -- the bust (face over kit)
  Tint(L_FACE, s, a.open and LIGHT or DARK)
  UI(L_TAG, s * N_PER_CARD, "co_name_" .. a.id, x, y + G.NAME_Y, G.NAME_W, G.NAME_H)
  if a.open then
    Hide(L_TAG, s * N_PER_CARD + 1)
  else
    UI(L_TAG, s * N_PER_CARD + 1, "co_lock", x, y + G.FACE_Y, G.LOCK_W, G.LOCK_H)
  end
end

local function DrawCursor()
  local p = pos[focus]
  if p == nil then
    Hide(L_UI, 0)
    return
  end
  UI(L_UI, 0, "co_ring", p[1], p[2], G.RING_W, G.RING_H)
end

local function UpdateGuideLine()
  local a = list[focus]
  local s = ""
  if a ~= nil then
    if not a.open then
      s = Text(TXT.LOCKED, a.name, a.hint)
    elseif a.tagline ~= "" then
      s = string.format(TXT.GUIDE_TAG, a.name, a.tagline)
    else
      s = string.format(TXT.GUIDE, a.name)
    end
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_GUIDE_LINE, 0, true)
  funcLuaMenuCommand(C.TEXT, L_GUIDE_LINE, 378156699 --[[_text_guide01]], s, 0)
end

local function UpdateTitle()
  funcLuaMenuCommand(C.TEXT, L_HEADER, 1220590795 --[[_text_sub_title02]], Text(TXT.TITLE), 0)
  funcLuaMenuCommand(C.SPRITE, L_HEADER, 3139293835 --[[#/menu/220_img/evt_rogue/evt_rogue_mode.g4tx]], 2610480106 --[[evt_rogue_mode_plate: INAROGUE's phoenix plate]], MODE_ICON_NODE, 0, 0)
end

local function UpdateButtonGuide()
  funcLuaMenuCommand(C.GUIDE_SET, MENU, L_BTN_GUIDE, {G_ACCEPT}, {I_ENTER}, {0}, {}, {})
  funcLuaMenuCommand(C.GUIDE_CMD, MENU, L_BTN_GUIDE, {K_ENTER})
  funcLuaMenuCommand(C.GUIDE_OPT, MENU, L_BTN_GUIDE, false)
end

local function DrawAll()
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_BG, 0, true)
  funcLuaMenuCommand(C.SCALE, L_BG, 1920 / G.Q, 1080 / G.Q, 1, 0)
  funcLuaMenuCommand(C.SPRITE, L_BG, CRC32(TEX_MAP), CRC32("evt_map_bg"), NODE_QUAD, 0, 0)
  Place(L_BG, 0, 960, 540)
  for s = 0, G.MAX_CARDS - 1 do
    if list[s + 1] ~= nil and pos[s + 1] ~= nil then
      DrawCard(s + 1)
    else
      Hide(L_CARD, s)
      Hide(L_FACE, s)
      Hide(L_TAG, s * N_PER_CARD)
      Hide(L_TAG, s * N_PER_CARD + 1)
    end
  end
  DrawCursor()
  UpdateGuideLine()
end

-- ---- actions --------------------------------------------------------------------------------------------------------
--@lib evt_menu_kit.lua#Message,Close

local function Decide()
  local a = list[focus]
  if a == nil then
    return
  end
  if not a.open then
    funcLuaCommand(C.SE, SE_NG)
    Message(Text(TXT.LOCKED_MSG, a.name, a.hint))
    return
  end
  local code = Int(Call(RL.PICK, a.i))
  Log("pick", a.id, "code", code)
  if code ~= 0 then
    funcLuaCommand(C.SE, SE_NG)
    Message(Text(TXT.ERROR, code))
    return
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  Close(1)
end

local function SetFocus(i, sound)
  if i == nil or i < 1 or i > #list or i == focus or pos[i] == nil then
    return
  end
  focus = i
  if sound then
    funcLuaCommand(C.SE, SE_OK)
  end
  DrawCursor()
  UpdateGuideLine()
end

-- left / right inside the row (no wrap), up / down = the card of the row above / below at the nearest x
local function MoveFocus(dx, dy)
  if #pos == 0 then
    return
  end
  local x, y = pos[focus][1], pos[focus][2]
  local best, bd = nil, nil
  for j = 1, #pos do
    local jx, jy = pos[j][1], pos[j][2]
    local ok
    if dx ~= 0 then
      ok = math.abs(jy - y) < 1 and (jx - x) * dx > 0
    else
      ok = (jy - y) * dy > 1
    end
    if ok then
      local d = math.abs(jx - x) + math.abs(jy - y)
      if bd == nil or d < bd then
        best, bd = j, d
      end
    end
  end
  SetFocus(best, true)
end

--@lib evt_menu_kit.lua#StartCo

local function PollPointer()
  Ptr.Begin()
  for i = 1, #pos do
    Ptr.Box(pos[i][1], pos[i][2], G.CARD_W / 2, G.CARD_H / 2, i)
  end
  local ev = Ptr.Poll()
  if evt_co ~= nil or not ready or open_guard > 0 then
    return
  end
  if type(ev.hover) == "number" and ev.hover ~= focus then   -- hover by movement only (mouse-support.md §5)
    SetFocus(ev.hover, true)
  end
  if type(ev.click) == "number" then
    SetFocus(ev.click, false)
    StartCo(Decide)
  end
end

-- ---- engine callbacks -----------------------------------------------------------------------------------------------
function OnInit()
  VRFW_Param.Clear(KEY_RESULT)
  funcLuaMenuCommand(C.LOAD_TEX, TEX_UI)
  funcLuaMenuCommand(C.LOAD_TEX, TEX_MAP)
  ready = false
  open_guard = 20
  ReadList()
  Log("open", #list, "coaches, focus", focus)
end

local function OpenOwnLayers()
  funcLuaMenuCommand(C.OPEN_LAYER, L_BG, 0)
  for i = 0, 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_UI, i)
  end
  for s = 0, G.MAX_CARDS - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_CARD, s)
    funcLuaMenuCommand(C.OPEN_LAYER, L_FACE, s)
  end
  for i = 0, G.MAX_CARDS * N_PER_CARD - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_TAG, i)
  end
end

function OnSetupLayer(a1, a2)
  if a1 == L_HEADER then
    SetupSoccerTopCommonHeaderLayerInfo(a1, 4153539961, 253801632, 3969848060, 1144161661, 3293713115, 253801632, 1152304044, 305955024, 3007971317)
    SwapSoccerTopCommonHeaderMenuModeIconTexture(1566262113 --[[mode_base02, as the INAROGUE menu]])
    UpdateHeader(3586861540)
    UpdateTitle()
    OpenOwnLayers()
  elseif a1 == L_ROW then
    funcLuaMenuCommand(C.TEXT, a1, 931545948 --[[_text_list01_on]], "", a2)
    funcLuaMenuCommand(C.TEXT, a1, 3705682548 --[[_text_list01_off]], "", a2)
    funcLuaMenuCommand(C.TEXT_VISIBLE, a1, 931545948, false, a2)
    funcLuaMenuCommand(C.TEXT_VISIBLE, a1, 3705682548, false, a2)
    for _, m in ipairs(ROW_MESHES) do
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, m, false, a2)
    end
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, CUR, false)
  elseif a1 == L_CARD or a1 == L_FACE or a1 == L_TAG or a1 == L_UI then
    Hide(a1, a2)                -- DrawAll draws what is used when the anchor opens
  elseif a1 == L_GUIDE_LINE then
    UpdateGuideLine()
  elseif a1 == L_BTN_GUIDE then
    UpdateButtonGuide()
  end
end

function OnOpenLayer(a1, a2)
  if a1 == L_ROW and a2 == 0 then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, false)
    funcLuaMenuCommand(C.FOCUS_ENABLE, a1, true)
    funcLuaMenuCommand(C.LIST_NUM, a1, 1)
    funcLuaMenuCommand(C.FOCUS_SET, a1, 0)
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, 0, CUR, false)
    funcLuaMenuCommand(C.POS, a1, -4000, 4000, 0, 0)
    DrawAll()
    UpdateButtonGuide()
    Ptr.Reset()
    ready = true
    if funcLuaCommand(C.FADE_DONE) then
      funcLuaCommand(C.FADE, 0, 0.3)
    end
  elseif a1 == L_GUIDE_LINE then
    UpdateGuideLine()
  end
end

function OnDecideFocus(a1, a2)
  if evt_co ~= nil or not ready or open_guard > 0 or Ptr.Owns() then
    return                      -- a pointer click is the pointer's (PollPointer)
  end
  StartCo(Decide)
end

function OnFunction(a1, a2)
  if evt_co ~= nil then
    return 1
  end
  local id = a1
  if a1 ~= FN.UP and a1 ~= FN.DOWN and a1 ~= FN.LEFT and a1 ~= FN.RIGHT then
    id = a2
  end
  if id == FN.UP then
    MoveFocus(0, -1)
  elseif id == FN.DOWN then
    MoveFocus(0, 1)
  elseif id == FN.LEFT then
    MoveFocus(-1, 0)
  elseif id == FN.RIGHT then
    MoveFocus(1, 0)
  else
    return
  end
  return 1
end

function OnEnter(a1, a2)
  if a1 == L_BTN or a1 == L_RET then
    return 1
  end
  OnDecideFocus(a1, a2)
end

function OnBack(a1)
  if evt_co ~= nil or not ready or open_guard > 0 then
    return 1
  end
  funcLuaCommand(C.SE, SE_BACK)
  Close(0)
  return 1
end

function Step()
  if evt_co ~= nil then
    if coroutine.status(evt_co) == "dead" then
      evt_co = nil
    else
      local ok, err = coroutine.resume(evt_co)
      if not ok then
        PRINT("evt_rogue_coach_menu: " .. tostring(err))
        Log("error", tostring(err))
        evt_co = nil
        funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
      elseif coroutine.status(evt_co) == "dead" then
        evt_co = nil
      end
    end
  end
  if ready and open_guard > 0 then
    open_guard = open_guard - 1
  end
  if ready then
    PollPointer()
  end
end
