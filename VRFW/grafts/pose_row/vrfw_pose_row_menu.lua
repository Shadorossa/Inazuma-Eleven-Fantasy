-- vrfw_pose_row_menu (plain Lua 5.2 source): the VR-Framework's POSE ROW screen (graft pose_row, mod vr_framework;
-- declared in the framework's menus\pose_row.toml, served as common/script/lua/menu/vrfw_pose_row_menu.lua.bin;
-- docs/framework/pose-row.md).
-- A list on the left; the selected entry's players stand on the right as 3D models posing in a row (one model slot of
-- the vrfw_pr_model component each), a card under each: name, position badge, «new» / «in the club» tag, a line of
-- text with a check when it is done. What it lists is a mod's [[VRFW.PoseRow]]: the declaration (CMND_VRFW_POSE_ROW)
-- names the mod's source command, asked (context, 0) for the header and (context, i) for entry i.
-- Models: built only for the selected entry, once the selection rests (SETTLE frames); a change releases the old ones,
-- closing releases every slot.
-- Opened by VRFW_PoseRow.Open (assets\lua\menu\_all\76_pose_row.lua): parameters crc32("vrfw_pose_row") = crc32 of the
-- key, crc32("vrfw_pose_row_context") = the context; out crc32("vrfw_pose_row_pick") = the picked entry (0 = Back).
-- Style `node_panel` (a declaration's `style`): the Chronicle board's own node panel look over the board (the retail
-- menu background and header off): a title band, the banner with the mod's retail icon, the rows (each with its level
-- circle and a check when done), the selected entry's lineup under them and the «Y» button of the declaration (`team`,
-- the pick -1); on the right a blue side panel (the retail «Tasa de aparición» look) with the entry's players posing,
-- 5 a page (L1 / R1 turn the pages: every player is shown).
-- Rule: no engine call at top level; funcLuaCommand only exists inside callbacks.
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_SAVEDATA_MANAGEMENT_MENU_INC")   -- header helpers (soccer top inc)

local MENU = 3907790619           -- crc32("vrfw_pose_row_menu")
local KEY_ROW = 970894462         -- crc32("vrfw_pose_row"): parameter in, the declaration's key crc
local KEY_CTX = 734132499         -- crc32("vrfw_pose_row_context"): parameter in, the context
local KEY_RESULT = 203690515      -- crc32("vrfw_pose_row_pick"): parameter out, the picked entry

-- ---- layers ---------------------------------------------------------------------------------------------------------
local L_ROW = 3455690937        -- save01_02_list_item (1 instance: the input anchor, off screen)
local L_HEADER = 575058101      -- mainmenu90_01_header
local L_GUIDE_LINE = 3078308064 -- mainmenu90_05_content_guide_line01
local L_CURSOR = 2296367164     -- cmn05_01_cursor
local L_BTN_GUIDE = 1138543975  -- mainmenu01_06_base_button_guide
local L_BTN = 9396745           -- mainmenu01_07_button_guide
local L_RET = 2005383485        -- mainmenu01_10_return_arrow_button_guide
local L_GROUND = 2627859723     -- vrfw_pr_ground x1  (454, background pass) the panel's ground
local L_PLATE = 1103658107      -- vrfw_pr_plate  x48 (457) list rows, cards, badges, pills
local L_TEXT = 3638521384       -- vrfw_pr_text   x52 (save01_02_list_item) every text line
local L_MODEL = 3888372217      -- vrfw_pr_model  x1  the models (5 slots of one component)
local L_SHADOW = 858725131      -- mainmenu01_08_chara_3d_shadow x5 (one per slot, as the retail shop)
local L_RETAIL_BG = 367379312   -- mainmenu90_00_background (off in the node panel style: the board shows under it)
local L_PITCH = 399054329      -- vrfw_pr_pitch x1 the node panel's formation pitch (the VS screen's, vsroute02_06)
local L_CARD = 4114633020       -- vrfw_pr_card  x5 the game's small player cards on it (team00_01, keep_name)
local N = {PLATE = 64, TEXT = 84, SLOTS = 5}

local C = {
  TEXT = 1083631230, MESH_VISIBLE = 3405944500, LAYER_VISIBLE = 711242136,
  SPRITE = 558735651, LOAD_TEX = 839427544, TEX_LOADING = 1506186496, SCALE = 3778714801, POS = 1389957207,
  ATTACH_TRACE = 1774843228, OPEN_LAYER = 629267548,
  FOCUS_ENABLE = 3518307824, FOCUS_SET = 3466097042, LIST_NUM = 3252599449,
  GUIDE_SET = 2209673388, GUIDE_CMD = 452337289, GUIDE_OPT = 1432240275,
  SE = 1917805374, CLOSE_MENU = 320421347, FADE = 609722083, FADE_DONE = 2259183189,
  P_SET = 3860611758, P_CLEAR = 3363400568, P_EXISTS = 2947612279, P_GET = 3522198769,
  TEXT_VISIBLE = 1505208242, TEXT_GET = 4074371074, PRIM_COLOR = 855211291, LOG = 3661580131,
  LANG = 477234096,           -- CMND_GET_LANGUAGE_CODE
  ROW_DECL = 1965621257,      -- CMND_VRFW_POSE_ROW (key crc)
  ROW_CARDS = 3517017366,     -- CMND_VRFW_POSE_ROW_CARDS (language, card…)
  POSE_BODIES = 2091146409,   -- CMND_VRFW_MODEL_POSE_BODIES (pose)
  TEAM_KIT = 4158248751,      -- CMND_VRFW_TEAM_KIT (team) -> its kit (uniform id; 0 = none)
  MODEL_POS = 1088067423,     -- CMND_SET_CHARA_MODEL_POS (layer, inst, x, y, z, slot)
  MODEL_TURN = 1195674914,    -- the model control (layer, inst, on): the right stick turns the model
  MODEL_MOTION = 2358506188,  -- a model's motion (layer, inst, clip, 0, 0, 0, 16, -1, slot): the retail summon performance's call
  MSG_BUSY = 898725220,
  CHECK_INPUT = 4265778440,   -- CMND_CHECK_INPUT_CMD (ctrl, input)
  FREE_CURSOR = 879521569,
}
local T = {POS = {1453968399, 3483409845, 3097996579, 650328192}}   -- vrfw_pr_pos_1..4 (GK FW MF DF)
local MARK_ON = "[$gaiji_check01_on] "  -- the game's check mark
local MESH_QUAD = 312193881     -- the cmn01_10 quad's mesh
local NODE_QUAD = 1909474081    -- icon_new01 (the cmn01_10 quad's sprite node)
local CUR = 3313461902          -- crc32("cursor")
local FN = {UP = 1498584731, DOWN = 4289419732, LEFT = 2570268295, RIGHT = 2224873012,   -- vrfw_pr_up / _down / …
            PREV = 2214675278, NEXT = 1020058407, EXTRA = 2104075845}   -- vrfw_pr_page_prev / _page_next / _extra
local G_ACCEPT = 1847312674 --[[Accept]]
local I_ENTER, K_ENTER = 2750714971 --[[<CMD_ENTER>]], 1981080283
local I_FUNC3, K_FUNC3 = 3794706590 --[[<CMD_FUNC3>]], 3421673595 --[[CMD_FUNC3]]
local SE_OK, SE_DECIDE, SE_BACK, SE_NG = 3848881948, 4235359837, 202039849, 2086672038
local ROW_MESHES = {3025401186, 486732393, 376662541, 3232607807, 1516082254, 3292070381, 1712955010}
local TEXT_ON, TEXT_OFF = 931545948 --[[_text_list01_on: light]], 3705682548 --[[_text_list01_off: dark]]
local TEXT_DX = 226             -- the list item's text node starts this far right of its origin
local CHAR_W = 15               -- the width of one letter at scale 1 (placing a line)
local WRAP_W = 21               -- the widest letter at scale 1 (a wrapped line never runs past its column)
local Q = 36                    -- the cmn01_10 quad's own size
local SETTLE = 12               -- frames the selection rests before its models are built

-- the screen's pictures by ROLE: a mod's sprite (content\screen_art\*.toml, Screen = "pose_row"), else a shape of the
-- framework's neutral atlas vrfw_plain tinted with the role's colour
local ART_SCREEN = "pose_row"
local FALLBACK = {
  panel_ground = {"square", {0.03, 0.08, 0.18}},
  list_row = {"square", {0.93, 0.95, 0.98}},
  list_row_focus = {"square", {1, 0.84, 0.25}},
  list_badge = {"square", {0.12, 0.27, 0.55}},
  card = {"square", {0.91, 0.93, 0.97}},
  tag_owned = {"square", {0.20, 0.62, 0.33}},
  tag_new = {"square", {0.80, 0.83, 0.89}},
  position_1 = {"square", {0.91, 0.70, 0.16}},   -- the game's position colours: GK, FW, MF, DF
  position_2 = {"square", {0.86, 0.24, 0.24}},
  position_3 = {"square", {0.24, 0.69, 0.35}},
  position_4 = {"square", {0.24, 0.47, 0.90}},
  title_band = {"square", {0.08, 0.20, 0.63}},          -- the node panel style
  banner = {"square", {0.12, 0.43, 0.78}},
  row = {"square", {0.08, 0.24, 0.55}},
  row_focus = {"square", {0, 0.59, 1}},
  level_circle = {"circle", {1, 1, 1}},
  lineup_ground = {"square", {0.12, 0.43, 0.24}},
  dot_1 = {"circle", {0.91, 0.70, 0.16}},
  dot_2 = {"circle", {0.86, 0.24, 0.24}},
  dot_3 = {"circle", {0.24, 0.69, 0.35}},
  dot_4 = {"circle", {0.24, 0.47, 0.90}},
  side_panel = {"square", {0.10, 0.27, 0.78}},
  check = {"circle", {1, 0.55, 0.1}},
  label_plate = {"square", {0.08, 0.13, 0.25}},
}
local FALLBACK_ANY = {"square", {1, 1, 1}}
local art, plain_tint = {}, {}

-- ---- state ----------------------------------------------------------------------------------------------------------
local DECL = nil        -- the declaration (CMND_VRFW_POSE_ROW): key, source, pose, models, texts, layout, camera
local CTX = 0           -- the opener's context
local HEAD = nil        -- the source's header (context, 0)
local rows = {}         -- entry i -> the source's answer (asked when first drawn)
local cards = {}        -- card -> {name, position}
local focus, count, lang = 1, 0, 0
local pos = {}          -- entry -> {x, y, hw, hh} (hit areas)
local used = {plate = 0, text = 0, plate_was = 0, text_was = 0}
local tex_asked, tex_frames, tex_wait = {}, {}, false
local ready, open_guard, evt_co = false, 20, nil
local models = {}       -- slot -> EVT_CharaModelNew
local shown = {}        -- slot -> card wanted there
local settle = nil      -- frames left before the selection's models are built
local placed = {}       -- slot -> the build placed
local NP = {page = 1}   -- the node panel style: the side panel's page

local function Log(...)
  pcall(funcLuaCommand, C.LOG, "pose_row", ...)
end

--@lib evt_menu_kit.lua#Call,Int,Hide

--@lib evt_menu_kit.lua#Pointer
local Ptr = EVT_PointerNew()

--@lib evt_menu_kit.lua#CharaModel

local function StartCo(fn, arg)
  if evt_co ~= nil then
    return
  end
  evt_co = coroutine.create(fn)
  local ok, err = coroutine.resume(evt_co, arg)
  if not ok then
    Log("error", tostring(err))
    evt_co = nil
  elseif coroutine.status(evt_co) == "dead" then
    evt_co = nil
  end
end

local function Text(id)
  local ok, s = pcall(funcLuaCommand, C.TEXT_GET, id)
  if ok and type(s) == "string" then
    return s
  end
  return ""
end

-- a source value as text: a string, a menu_text id, or {id = text id, args = {…} (string.format), vars = {k = v}
-- ({k} replaced)}
local function Str(v)
  if type(v) == "string" then
    return v
  elseif type(v) == "number" then
    return v ~= 0 and Text(v) or ""
  elseif type(v) == "table" then
    local s = type(v.id) == "number" and Text(v.id) or tostring(v.text or "")
    if type(v.args) == "table" and #v.args > 0 then
      local ok, f = pcall(string.format, s, table.unpack(v.args))
      if ok then s = f end
    end
    if type(v.vars) == "table" then
      for k, x in pairs(v.vars) do
        s = s:gsub("{" .. tostring(k) .. "}", (tostring(x):gsub("%%", "%%%%")))
      end
    end
    return s
  end
  return ""
end

local function Place(layer, idx, x, y)
  funcLuaMenuCommand(C.POS, layer, x, -y, 0, idx)
end

local function SetColour(layer, idx, c)
  funcLuaMenuCommand(C.PRIM_COLOR, layer, idx, MESH_QUAD, c[1], c[2], c[3])
end

local function QuadTex(layer, idx, texCrc, spriteCrc, x, y, w, h)
  funcLuaMenuCommand(C.LAYER_VISIBLE, layer, idx, true)
  funcLuaMenuCommand(C.SCALE, layer, w / Q, h / Q, 1, idx)
  local ok = funcLuaMenuCommand(C.SPRITE, layer, texCrc, spriteCrc, NODE_QUAD, 0, idx)
  Place(layer, idx, x, y)
  local pt = plain_tint[layer]
  if pt ~= nil and pt[idx] ~= nil then
    pt[idx] = nil
    SetColour(layer, idx, {1, 1, 1})
  end
  return ok
end

local function Tex(path)
  if path == nil or path == "" or tex_frames[path] == -1 then
    return nil
  end
  if not tex_asked[path] then
    tex_asked[path] = true
    tex_frames[path] = 0
    funcLuaMenuCommand(C.LOAD_TEX, path)
  end
  if funcLuaCommand(C.TEX_LOADING, CRC32(path)) == true then
    tex_wait = true
    return false
  end
  return CRC32(path)
end

-- the sprite of art role `role` (a mod's), else its plain shape tinted; centre (x, y), size w x h
local function Quad(layer, idx, role, x, y, w, h)
  local a = art[role]
  if a ~= nil and a.res then          -- an atlas of the screen's res (loaded with it): its sprite straight away
    if QuadTex(layer, idx, CRC32(a.atlas), a.crc, x, y, w, h) ~= false then
      return
    end
    a = nil
  end
  if a ~= nil then
    local tc = Tex(a.atlas)
    if tc == false then
      Hide(layer, idx)
      return
    end
    if tc ~= nil and QuadTex(layer, idx, tc, a.crc, x, y, w, h) ~= false then
      return
    end
  end
  local f = FALLBACK[role] or FALLBACK_ANY
  local tc, sc = VRFW_ScreenArt.Plain(f[1])
  QuadTex(layer, idx, tc, sc, x, y, w, h)
  plain_tint[layer] = plain_tint[layer] or {}
  plain_tint[layer][idx] = f[2]
  SetColour(layer, idx, f[2])
end

-- the next plate of the pool: role, top-left (x, y), size
local function Plate(role, x, y, w, h)
  if used.plate >= N.PLATE then
    return
  end
  Quad(L_PLATE, used.plate, role, x + w / 2, y + h / 2, w, h)
  used.plate = used.plate + 1
end

-- the next text line of the pool: its left edge x, its middle y; dark = the list item's dark text, else its light one
local function Line(s, x, y, scale, dark)
  if s == nil or s == "" or used.text >= N.TEXT then
    return
  end
  local idx = used.text
  used.text = used.text + 1
  local node, other = dark and TEXT_OFF or TEXT_ON, dark and TEXT_ON or TEXT_OFF
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_TEXT, idx, true)
  funcLuaMenuCommand(C.SCALE, L_TEXT, scale, scale, 1, idx)
  funcLuaMenuCommand(C.TEXT, L_TEXT, node, s, idx)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L_TEXT, node, true, idx)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L_TEXT, other, false, idx)
  Place(L_TEXT, idx, x - TEXT_DX * scale, y)
end

-- `s` cut into lines of at most `w` px at `scale` (by words)
local function Wrap(s, w, scale)
  local max = math.max(4, math.floor(w / (WRAP_W * scale)))
  local out, cur = {}, ""
  for word in string.gmatch(s, "%S+") do
    local next = cur == "" and word or (cur .. " " .. word)
    if #next > max and cur ~= "" then
      out[#out + 1] = cur
      cur = word
    else
      cur = next
    end
  end
  if cur ~= "" then
    out[#out + 1] = cur
  end
  return out
end

-- ---- data -----------------------------------------------------------------------------------------------------------
local function Row(i)
  if rows[i] == nil then
    local r = Call(DECL.source, CTX, i)
    rows[i] = type(r) == "table" and r or false
  end
  return rows[i] or nil
end

local function ModelsOf(r)
  local out = {}
  for _, m in ipairs(type(r) == "table" and type(r.models) == "table" and r.models or {}) do
    if type(m) == "table" and type(m.card) == "number" and m.card ~= 0 then
      out[#out + 1] = m
    end
  end
  return out
end

-- the models of the page shown (DECL.models a page) and the page count
function NP.Page(r)
  local all = ModelsOf(r)
  local per = DECL.models
  local pages = math.max(1, math.ceil(#all / per))
  NP.page = math.max(1, math.min(NP.page, pages))
  local out = {}
  for k = (NP.page - 1) * per + 1, math.min(#all, NP.page * per) do
    out[#out + 1] = all[k]
  end
  return out, pages
end

-- the layout of the declaration's style (content\defaults\pose_row.toml [layout] / [layout.<style>])
function NP.Layout()
  local L = DECL and DECL.layout or {}
  if DECL and DECL.style == "node_panel" and type(L.node_panel) == "table" then
    return L.node_panel
  end
  return L
end

-- name and position of the entry's cards (asked once per card)
local function CardsOf(list)
  local need = {}
  for _, m in ipairs(list) do
    if cards[m.card] == nil then
      need[#need + 1] = m.card
    end
  end
  if #need > 0 then
    local r = Call(C.ROW_CARDS, lang, table.unpack(need))
    for k, c in ipairs(need) do
      local v = type(r) == "table" and r[k] or nil
      cards[c] = type(v) == "table" and v or {name = "", position = 0}
    end
  end
end

local function Owned(card)
  return VRFW_Recruit ~= nil and VRFW_Recruit.Owned(card) > 0
end

-- ---- models ---------------------------------------------------------------------------------------------------------
-- a slot's screen centre x: the declaration's `centered` = the models centred in the panel, else the layout's slot_x
local function SlotX(Lo, k)
  if DECL ~= nil and DECL.centered then
    local P = Lo.panel or {}
    return (P.x or 650) + (P.w or 1220) / 2 + (k - (DECL.models + 1) / 2) * (Lo.centered_step or 240)
  end
  return (Lo.slot_x or {})[k] or 960
end

-- the declaration's motion of a shown model (0 = none): 1 = the retail summon performance's (soccer_summon_menu t8, by
-- the player's main position 1 GK 2 FW 3 MF 4 DF, the big and small body types' own FW / MF clips), else that clip
local SUMMON_MOTION = {[1] = 4211840059, [2] = 2504473885, [3] = 2717938668, [4] = 2232361508,
  big = {[2] = 2474107858, [3] = 4267164290}, small = {[2] = 1458406759, [3] = 1003332663}}
local function MotionOf(M)
  local m = Int(DECL.motion)
  if m ~= 1 then
    return m
  end
  if cards[M.pid] == nil then
    CardsOf({{card = M.pid}})
  end
  local pos = Int((cards[M.pid] or {}).position)
  local ok, has, body = pcall(funcLuaCommand, 4060384944 --[[CMND_GET_CHARA_INFO]], M.chara or 0, 3, 0)
  body = (ok and has == true) and Int(body) or 0
  local by = (body == 5 and SUMMON_MOTION.big) or ((body == 3 or body == 11) and SUMMON_MOTION.small) or {}
  return by[pos] or SUMMON_MOTION[pos] or SUMMON_MOTION[2]
end
-- a slot's world place from the layout: its screen centre x, the feet line (the shop camera's perspective)
local function SlotWorld(k)
  local Lo, Ca = NP.Layout(), DECL.camera or {}
  local mz = Lo.model_z or Ca.model_z or -2.35
  local d = (Ca.eye_z or 12.5) - mz
  local ppm = (Ca.px_per_m_at_1m or 3060) / d
  local sx = SlotX(Lo, k)
  local look = (Ca.look_y or 1.6) + ((Ca.eye_y or 2.25) - (Ca.look_y or 1.6)) * mz / (Ca.eye_z or 12.5)
  return (sx - 960) / ppm, look - ((Lo.feet_y or 668) - 540) / ppm, mz
end

-- the selected entry's players into the slots (a slot whose player changes is released first; no player: released)
local function ApplyModels()
  local list = NP.Page(Row(focus))
  for k = 1, DECL.models do
    local M = models[k]
    local m = list[k]
    local card = m and m.card or nil
    if M ~= nil and shown[k] ~= card then
      if shown[k] ~= nil then
        M.Release()
      end
      placed[k] = nil
      shown[k] = card
      if card ~= nil then
        M.Show(card)
      end
    end
  end
end

-- every slot shown: once per build, the slot moved to its place in the row and its turning control off
local function ModelStep()
  for k, M in pairs(models) do
    M.Step()
    local B = M.build
    if B ~= nil and B.done and M.pend == nil and M.pid ~= nil and placed[k] ~= B then
      placed[k] = B
      local x, y, z = SlotWorld(k)
      pcall(funcLuaMenuCommand, C.MODEL_POS, L_MODEL, 0, x, y, z, k - 1)
      pcall(funcLuaMenuCommand, C.MODEL_TURN, L_MODEL, 0, false)
      local motion = MotionOf(M)
      if motion ~= 0 then
        pcall(funcLuaMenuCommand, C.MODEL_MOTION, L_MODEL, 0, motion, 0, 0, 0, 16, -1, k - 1)
      end
      Log("slot", k, "card", M.pid, "at", string.format("%.2f %.2f %.2f", x, y, z), "motion", motion)
    end
  end
end

local function ReleaseModels()
  for k, M in pairs(models) do
    M.Release()
    shown[k], placed[k] = nil, nil
  end
end

-- ---- drawing --------------------------------------------------------------------------------------------------------
local function UpdateTitle()
  local title = Text(DECL and DECL.title or 0)
  local sub = HEAD and Str(HEAD.title) or ""
  if sub ~= "" then
    title = title ~= "" and (title .. " · " .. sub) or sub
  end
  funcLuaMenuCommand(C.TEXT, L_HEADER, 1220590795 --[[_text_sub_title02]], title, 0)
end

local function UpdateButtonGuide()
  local accept = (DECL ~= nil and DECL.decide ~= 0) and DECL.decide or G_ACCEPT
  local texts, icons, offs, keys = {accept}, {I_ENTER}, {18}, {K_ENTER}
  if DECL ~= nil and DECL.team ~= 0 then
    texts[2], icons[2], offs[2], keys[2] = DECL.team, I_FUNC3, 36, K_FUNC3
  end
  funcLuaMenuCommand(C.GUIDE_SET, MENU, L_BTN_GUIDE, texts, icons, offs, {}, {})
  funcLuaMenuCommand(C.GUIDE_CMD, MENU, L_BTN_GUIDE, keys)
  funcLuaMenuCommand(C.GUIDE_OPT, MENU, L_BTN_GUIDE, false)
end

local function DrawList(Lo)
  local L = Lo.list or {}
  local per = Lo.rows or 10
  local first = math.max(1, math.min(focus - math.floor(per / 2), count - per + 1))
  for k = 0, per - 1 do
    local i = first + k
    local r = i <= count and Row(i) or nil
    if r ~= nil then
      local x, y, w, h = L.x or 60, (L.y or 160) + k * ((L.h or 74) + (L.gap or 8)), L.w or 560, L.h or 74
      local on = i == focus
      Plate(on and "list_row_focus" or "list_row", x, y, w, h)
      local badge = Str(r.tag)
      if badge ~= "" then
        Plate("list_badge", x + 10, y + 12, 50, h - 24)
        Line(badge, x + 16, y + h / 2, 0.55, false)
      end
      Line(Str(r.label), x + 78, y + h * 0.36, 0.95, true)
      Line(Str(r.sub), x + 78, y + h * 0.72, 0.62, true)
      pos[i] = {x = x + w / 2, y = y + h / 2, hw = w / 2, hh = h / 2}
    end
  end
end

-- the entry's panel: its title, info line, the cards under the models and the hint
local function DrawPanel(Lo)
  local P = Lo.panel or {}
  Quad(L_GROUND, 0, "panel_ground", (P.x or 650) + (P.w or 1220) / 2, (P.y or 160) + (P.h or 800) / 2, P.w or 1220,
    P.h or 800)
  local r = Row(focus)
  if r == nil then
    return
  end
  local ti, inf, hi = Lo.title or {}, Lo.info or {}, Lo.hint or {}
  Line(Str(r.title or r.label), ti.x or 686, ti.y or 196, ti.scale or 1.25, false)
  Line(Str(r.info), inf.x or 686, inf.y or 246, inf.scale or 0.8, false)
  Line(Text(DECL.hint), hi.x or 686, hi.y or 928, hi.scale or 0.75, false)
  NP.Cards(Lo, (NP.Page(r)))
end

-- a card under each model of the page shown
function NP.Cards(Lo, list)
  CardsOf(list)
  local K = Lo.card or {}
  local cw, ch, cy, bar = K.w or 230, K.h or 196, K.y or 700, K.bar or 6
  for k, m in ipairs(list) do
    local cx = SlotX(Lo, k)
    local x = cx - cw / 2
    local c = cards[m.card] or {}
    local p = Int(c.position)
    Plate("card", x, cy, cw, ch)
    Plate("position_" .. (p >= 1 and p <= 4 and p or 1), x, cy, cw, bar)
    Line(c.name or "", x + 12, cy + 26, 0.68, true)
    Plate("position_" .. (p >= 1 and p <= 4 and p or 1), x + 10, cy + 46, 46, 26)
    Line(Text(T.POS[p] or 0), x + 16, cy + 59, 0.5, false)
    local owned = Owned(m.card)
    Plate(owned and "tag_owned" or "tag_new", x + 62, cy + 46, cw - 72, 26)
    Line(owned and (MARK_ON .. Text(DECL.owned)) or Text(DECL.new), x + 72, cy + 59, 0.5, not owned)
    local text = Str(m.text)
    if m.done == true and text ~= "" then
      text = MARK_ON .. text
    end
    local label = text ~= "" and Text(DECL.label or 0) or ""
    local top = cy + 96
    if label ~= "" then
      Line(label, x + 12, top, 0.55, true)
      top = top + 26
    end
    local lines = Wrap(text, cw - 24, 0.55)
    for n = 1, math.min(label ~= "" and 3 or 4, #lines) do
      Line(lines[n], x + 12, top + (n - 1) * 26, 0.55, true)
    end
  end
end

-- the node panel style (the Chronicle board's node panel look; see the header)
function NP.Draw(Lo)
  local function box(t, d) return t or d end
  local r = Row(focus)
  local Ti = box(Lo.title, {})
  Plate("title_band", Ti.x or 40, Ti.y or 42, Ti.w or 890, Ti.h or 70)
  local title = Text(DECL.title)
  local sub = HEAD and Str(HEAD.title) or ""
  if sub ~= "" then title = title ~= "" and (title .. " · " .. sub) or sub end
  Line(title, (Ti.x or 40) + 50, (Ti.y or 42) + (Ti.h or 70) / 2, Ti.scale or 1.15, false)
  local Bn = box(Lo.banner, {})
  Plate("banner", Bn.x or 90, Bn.y or 190, Bn.w or 530, Bn.h or 160)
  Line(Text(DECL.banner), (Bn.x or 90) + 30, (Bn.y or 190) + (Bn.h or 160) - 40, Bn.scale or 1, false)
  if DECL.icon_atlas ~= "" and used.plate < N.PLATE then
    local Ic = box(Bn.icon, {})
    QuadTex(L_PLATE, used.plate, CRC32(DECL.icon_atlas), CRC32(DECL.icon_sprite), Ic.x or 515, Ic.y or 265, Ic.size or 150,
      Ic.size or 150)
    used.plate = used.plate + 1
  end
  -- the rows: the selection kept in view
  local Rw = box(Lo.rows, {})
  local shown, step = Rw.shown or 5, Rw.step or 70
  local first = NP.first or 1
  if focus < first then first = focus end
  if focus > first + shown - 1 then first = focus - shown + 1 end
  first = math.max(1, math.min(first, math.max(1, count - shown + 1)))
  NP.first = first
  for k = 0, shown - 1 do
    local i = first + k
    local e = i <= count and Row(i) or nil
    if e ~= nil then
      local x, y, w, h = Rw.x or 90, (Rw.y or 380) + k * step, Rw.w or 540, Rw.h or 52
      Plate(i == focus and "row_focus" or "row", x, y, w, h)
      Plate("level_circle", x + 12, y + 4, h - 8, h - 8)
      local lv = tostring(Int(e.level))
      Line(lv, x + 12 + (h - 8) / 2 - #lv * CHAR_W * 0.55 / 2, y + h / 2, 0.55, true)
      Line(Str(e.label), x + h + 24, y + h / 2, Rw.scale or 0.85, i ~= focus)
      if e.done == true then
        if art.check ~= nil then
          Plate("check", x + w - 64, y + (h - 44) / 2, 44, 44)
        else
          Line(MARK_ON, x + w - 60, y + h / 2, 0.8, i ~= focus)
        end
      end
      pos[i] = {x = x + w / 2, y = y + h / 2, hw = w / 2, hh = h / 2}
    end
  end
  local Mo = box(Lo.more, {})
  local more_text = HEAD and Str(HEAD.info) or ""
  if more_text ~= "" then
    Plate("label_plate", (Mo.x or 300) - 20, (Mo.y or 745) - 20, #more_text * CHAR_W * (Mo.scale or 0.6) + 40, 40)
    Line(more_text, Mo.x or 300, Mo.y or 745, Mo.scale or 0.6, false)
  end
  if r == nil then
    return
  end
  -- the lineup of the selected entry: the retail formation view (NP.Lineup)
  NP.Lineup(Lo, r)
  if DECL.team ~= 0 then
    local Tm = box(Lo.team, {})
    local tt = Text(DECL.team)
    local tw = #tt * CHAR_W * (Tm.scale or 0.7)
    Plate("button_plate", (Tm.x or 360) - tw / 2 - 30, (Tm.y or 976) - 22, tw + 60, 44)
    Line(tt, (Tm.x or 360) - tw / 2, Tm.y or 976, Tm.scale or 0.7, false)
  end
  -- the side panel: its title, the entry's line, the page, the models' cards
  local P = box(Lo.panel, {})
  Quad(L_GROUND, 0, "side_panel", (P.x or 700) + (P.w or 1130) / 2, (P.y or 165) + (P.h or 770) / 2, P.w or 1130, P.h or 770)
  local Pt, Pi, Pg = box(Lo.panel_title, {}), box(Lo.panel_info, {}), box(Lo.page, {})
  Line(Text(DECL.panel_title), Pt.x or 710, Pt.y or 130, Pt.scale or 1.1, false)
  local info = Str(r.title or r.label)
  local more = Str(r.info)
  Line(more ~= "" and (info .. "   ·   " .. more) or info, Pi.x or 730, Pi.y or 205, Pi.scale or 0.8, false)
  local list, pages = NP.Page(r)
  if pages > 1 then
    local ok, ptxt = pcall(string.format, Text(DECL.page), NP.page, pages)
    Line(ok and ptxt or (NP.page .. " / " .. pages), Pg.x or 1650, Pg.y or 205, Pg.scale or 0.7, false)
  end
  NP.PlayerRows(Lo, list)
end

-- one row per player of the page under the models: the game's check box (ticked when the club has him or his
-- challenge was met), his name, his challenge; a player the club has: a disabled (grey) row
function NP.PlayerRows(Lo, list)
  CardsOf(list)
  local R = Lo.player_rows or {}
  local x, y0, w, h, step = R.x or 740, R.y or 648, R.w or 1050, R.h or 46, R.step or 54
  local ns, ts, tx = R.name_scale or 0.62, R.text_scale or 0.55, R.text_x or 340
  for k, m in ipairs(list) do
    local y = y0 + (k - 1) * step
    local owned = Owned(m.card)
    Plate(owned and "player_row_off" or "player_row", x, y, w, h)
    Plate("check_box", x + 14, y + (h - 32) / 2, 32, 32)
    if owned or m.done == true then
      Plate("check_mark", x + 10, y + (h - 40) / 2 - 4, 40, 40)
    end
    local c = cards[m.card] or {}
    Line(c.name or "", x + 64, y + h / 2, ns, not owned)
    local text = Str(m.text)
    local max = math.max(4, math.floor((w - tx - 20) / (WRAP_W * ts)))
    if #text > max then
      text = string.sub(text, 1, max - 3) .. "..."
    end
    Line(text, x + tx, y + h / 2, ts, not owned)
  end
end

-- ---- the node panel's lineup: the entry's team in its formation, as the board's command menu shows a team (the VS
-- screen's pitch vsroute02_06 and the game's small player cards, filled by the game, placed by the retail rule of
-- CalcFormationIconPosition; the pitch geometry of layout vsroute02_06)
NP.LU = {
  PITCH = {CENTRE_X = 1394, CENTRE_Y = -533, TOP_Y = -296, BOTTOM_Y = -856, TOP_WIDTH = 428, BOTTOM_WIDTH = 588,
    FIELD_TOP_Y = -294, FIELD_HEIGHT = 564},
  FORM = {WIDTH_UNITS = 60, DEPTH_UNITS = 90, BASE_SET = 2, OFFSET_SET = 10, OFFSET_SCALE = 0.85, KEEPER_LIFT = 20},
  FORMATION_INFO = 2649030357, TEAM_PARAM = 2151743654, TEXT_OF_ID = 297699480, FILL = 2339877830,
  DRAW_PRIORITY = 1491630496, NODE_VISIBLE = 2158717427, FACE = 552280324, RESET_FACE = 4176779611,
  CHARA_OF_PARAM = 347353059, SPRITE = 558735651,
  PRIORITY_PITCH = 458, PRIORITY_CARD = 459,
  -- the card's pieces never shown here: card / lock icons, the focus frames
  HIDE = {2635558741, 69091055, 814224422, 2843821468, 3345942320, 3491095421},
  -- a card drawn from its own sprites when the game's fill refuses it: the small plate in the position colour, the face
  SPRITE_CARD = {TEXTURE = 4225297828, PLATE = 3124533534, PLATE_SLOT = 627420056, FACE = 3220507922,
    FACE_SLOT = 372537510, PLATES = {{16, 570978177}, {32, 3161258530}, {64, 627420056}, {128, 3137420859}}},
  named = {},
}
-- the soccer card's name setting (the game's card fills find the card's parts by these tags: retail
-- NameSetting_CharaCardForSoccer of soccer_formation_menu_inc)
NP.LU.NAMES = {
  {"text_charaname", "_text_chr01"}, {"locator_base_pos_L", "_pos_base01"}, {"locator_base_pos_S", "_pos_base02"},
  {"numprim_level_L", "num_chr_l01"}, {"numprim_level_S", "num_chr_s01"},
  {"numprim_level_q_L", "num_chr_l01_q"}, {"numprim_level_q_S", "num_chr_s01_q"},
  {"numprim_level_gray_L", "num_chr_l01_gray"}, {"numprim_level_gray_S", "num_chr_s01_gray"},
  {"numprim_level_cap_L", "num_chr_l01_cup"}, {"numprim_level_cap_S", "num_chr_s01_cup"},
  {"numprim_level_basara_L", "num_chr_l01_basara"}, {"numprim_level_basara_S", "num_chr_s01_basara"},
  {"rate_anim_exp", "exp_gauge01"}, {"rate_group_exp", "bar"},
  {"locator_gp_gauge_L", "_pos_gauge_gp_l01"}, {"locator_gp_gauge_S", "_pos_gauge_gp_s01"},
  {"rate_anim_gp", "gp_gauge01"}, {"rate_group_gp", "bar"},
  {"locator_kp_gauge_L", "_pos_gauge_kp_l01"}, {"locator_kp_gauge_S", "_pos_gauge_kp_s01"},
  {"rate_anim_kp", "kp_gauge01"}, {"rate_group_kp", "bar"},
  {"tex_chara_face_L", "icon_chr_dmy_l01"}, {"tex_chara_face_S", "icon_chr_dmy_s01"},
  {"mesh_chara_face_L", "_icon_chr_dmy_l01"}, {"mesh_chara_face_S", "_icon_chr_dmy_s01"},
  {"mesh_icon_element_L", "_icon_chr_type_dmy_l01"}, {"mesh_icon_element_S", "_icon_chr_type_dmy_s01"},
  {"mesh_base_element_L", "_icon_base_l01"}, {"mesh_base_element_S", "_icon_base_s01"},
  {"tex_element_L", "icon_chr_type_dmy_l01"}, {"tex_element_S", "icon_chr_type_dmy_s01"},
  {"tex_file_element", "#/menu/200_icon/15_icon_common/icon_common.g4tx"},
  {"mesh_icon_position_L", "_icon_chr_position_dmy_l01"}, {"mesh_icon_position_S", "_icon_chr_position_dmy_s01"},
  {"tex_position_L", "icon_chr_position_dmy_l01"}, {"tex_position_S", "icon_chr_position_dmy_s01"},
  {"tex_file_position", "#/menu/200_icon/15_icon_common2/<LG>/icon_common2.g4tx"},
  {"tex_file_rarity", "#/menu/102_team/team00/team00_01/<LG>/team00_01.g4tx"},
  {"mesh_base_rarity_L", "_icon_chr_base_l01"}, {"mesh_base_rarity_S", "_icon_chr_base_s01"},
  {"tex_base_rarity_L", "icon_chr_base01_l01"}, {"tex_base_rarity_S", "icon_chr_base01_s01"},
  {"mesh_color_rarity_L", "_icon_chr_dmy_l01"}, {"mesh_color_rarity_S", "_icon_chr_dmy_s01"},
  {"tex_color_rarity_L", "icon_chr_color01_l01"}, {"tex_color_rarity_S", "icon_chr_color01_s01"},
  {"tex_gradation_rarity_L", "icon_chr_gradation_l01"}, {"tex_gradation_rarity_S", "icon_chr_gradation_s01"},
  {"mesh_captain_L", "_icon_captain01"}, {"mesh_captain_S", "_icon_captain02"},
  {"mesh_seasonal_flame_L", "_seasonal_frame_l01"}, {"mesh_seasonal_flame_S", "_seasonal_frame_s01"},
  {"mesh_ai_role_setting_icon_L", "_icon_ai_role_dmy01"}, {"mesh_ai_role_setting_icon_S", "_icon_ai_role_dmy02"},
  {"tex_ai_role_setting_icon_L", "icon_ai_role_dmy01"}, {"tex_ai_role_setting_icon_S", "icon_ai_role_dmy01"},
  {"tex_file_ai_role", "#/menu/200_icon/15_icon_common/<LG>/icon_common.g4tx"},
  {"pos_leader_L", "_pos_leader01"}, {"pos_leader_S", "_pos_leader02"},
  {"pos_gauge_exp_L", "_pos_gauge_exp_l01"}, {"pos_gauge_exp_S", "_pos_gauge_exp_s01"},
  {"hidden_exp_gauge", "true"}, {"material_rarity_color", "rarity_color"},
}

function NP.NameCard(slot)
  local U = NP.LU
  if U.named[slot] or MENU_DEF == nil or MENU_DEF.NameSettingBegin == nil then
    return
  end
  U.named[slot] = true
  pcall(function()
    MENU_DEF.NameSettingBegin(L_CARD, slot)
    for _, e in ipairs(U.NAMES) do
      MENU_DEF.AddName(e[1], e[2])
    end
    MENU_DEF.NameSettingEnd()
  end)
end

-- a formation slot's place from the pitch's centre (pitch px, y up): the retail CalcFormationIconPosition rule
function NP.SlotOffset(formation, slot)
  local U = NP.LU
  local G, R = U.PITCH, U.FORM
  local ok, x, _, y = Call(U.FORMATION_INFO, 4, formation, slot, R.BASE_SET)
  if ok ~= true then x, y = 0, 0 end
  x, y = x or 0, y or 0
  local total, above, below = math.abs(G.TOP_Y - G.BOTTOM_Y), math.abs(G.CENTRE_Y - G.TOP_Y), math.abs(G.CENTRE_Y - G.BOTTOM_Y)
  local depth = y / R.DEPTH_UNITS
  local height_here = -y * (total / R.DEPTH_UNITS) + total * 0.5
  local width_here = (G.TOP_WIDTH - G.BOTTOM_WIDTH) * (height_here / total) + G.BOTTOM_WIDTH
  local px, py = x * (width_here / R.WIDTH_UNITS), below - y * (G.BOTTOM_WIDTH / R.WIDTH_UNITS)
  if depth < 0 then
    py = py + total * depth * above / below
  elseif depth > 0 then
    py = py + above * depth * below / (total * 0.5)
  end
  local okO, dx, dy = Call(U.FORMATION_INFO, 4, formation, slot, R.OFFSET_SET)
  if okO == true then
    px, py = px + (dx or 0) * R.OFFSET_SCALE, py + (dy or 0) * R.OFFSET_SCALE
  end
  py = py - below
  local okK, kind = Call(U.FORMATION_INFO, 5, formation, slot)
  if okK == true and kind == 0 then
    py = py + R.KEEPER_LIFT
  end
  return px, py
end

-- a card from its own sprites (the game's fill refused it): its position colour plate and the face
function NP.SpriteCard(slot, card, position)
  local S = NP.LU.SPRITE_CARD
  local plate = S.PLATE_SLOT
  for _, e in ipairs(S.PLATES) do
    if math.floor((position or 0) / e[1]) % 2 == 1 then
      plate = e[2]
      break
    end
  end
  funcLuaMenuCommand(NP.LU.SPRITE, L_CARD, S.TEXTURE, plate, S.PLATE_SLOT, 0, slot)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_CARD, S.PLATE, true, slot)
  funcLuaMenuCommand(NP.LU.RESET_FACE, L_CARD, slot, S.FACE_SLOT)
  local chara = Call(NP.LU.CHARA_OF_PARAM, card)
  funcLuaMenuCommand(NP.LU.FACE, L_CARD, slot, false, S.FACE, S.FACE_SLOT, 0, 0, Int(chara) ~= 0 and chara or card, 0,
    false, true)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_CARD, S.FACE, true, slot)
end

function NP.HideLineup()
  Hide(L_PITCH, 0)
  for slot = 0, N.SLOTS - 1 do
    Hide(L_CARD, slot)
  end
end

-- the panel, the formation's name, the pitch and the lineup's cards (its first `lineup` players: the next match's)
function NP.Lineup(Lo, r)
  local U, Lb = NP.LU, Lo.lineup or {}
  local lx, ly, lw, lh = Lb.x or 90, Lb.y or 740, Lb.w or 540, Lb.h or 210
  Plate("lineup_panel", lx, ly, lw, lh)
  local team = Int(r.team)
  local okF, formation = Call(U.TEAM_PARAM, team, 3)
  if team == 0 or okF ~= true or Int(formation) == 0 then
    NP.HideLineup()
    return
  end
  local okN, name_id = Call(U.FORMATION_INFO, 7, formation)
  local name = okN == true and Call(U.TEXT_OF_ID, name_id) or ""
  name = type(name) == "string" and name or ""
  local ns = Lb.name_scale or 0.7
  local cx = lx + lw / 2
  Line(name, cx - #name * CHAR_W * ns / 2, ly + (Lb.name_y or 20), ns, false)
  -- the pitch: its centre locator at (cx, cy)
  local G, sx, sy = U.PITCH, Lb.pitch_scale_x or 0.62, Lb.pitch_scale_y or 0.3
  local pitch_top = ly + (Lb.pitch_top or 42)
  local cy = pitch_top + (G.FIELD_TOP_Y - G.CENTRE_Y) * sy
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_PITCH, 0, true)
  funcLuaMenuCommand(C.SCALE, L_PITCH, sx, sy, 1, 0)
  pcall(funcLuaMenuCommand, U.DRAW_PRIORITY, L_PITCH, 0, U.PRIORITY_PITCH, true)
  Place(L_PITCH, 0, cx - G.CENTRE_X * sx, cy + G.CENTRE_Y * sy)
  local all = ModelsOf(r)
  local n = math.min(#all, N.SLOTS, Int(r.lineup) > 0 and Int(r.lineup) or DECL.models)
  local cs = Lb.card_scale or 0.36
  local kit = NP.kits and NP.kits[team] or Int(Call(C.TEAM_KIT, team))
  for slot = 0, N.SLOTS - 1 do
    local m = all[slot + 1]
    if slot < n and m ~= nil then
      local okP, position = Call(U.FORMATION_INFO, 6, formation, slot)
      position = okP == true and Int(position) or 0
      NP.NameCard(slot)
      funcLuaMenuCommand(C.LAYER_VISIBLE, L_CARD, slot, true)
      pcall(SetDisableForceCharaInvalidUseTarget)
      local filled = Call(U.FILL, L_CARD, slot, m.card, true, false, position, 0, Int(r.level), false, false, 0, kit)
      if filled == false then
        NP.SpriteCard(slot, m.card, position)
      end
      pcall(SetEnableForceCharaInvalidUseTarget)
      for _, mesh in ipairs(U.HIDE) do
        funcLuaMenuCommand(C.MESH_VISIBLE, L_CARD, mesh, false, slot)
      end
      local rx, ry = NP.SlotOffset(formation, slot)
      funcLuaMenuCommand(C.SCALE, L_CARD, cs, cs, 1, slot)
      pcall(funcLuaMenuCommand, U.DRAW_PRIORITY, L_CARD, slot, U.PRIORITY_CARD, true)
      Place(L_CARD, slot, cx + rx * sx, cy - ry * sy)
    else
      Hide(L_CARD, slot)
    end
  end
end

-- L1 / R1: the side panel's page
function NP.Turn(d)
  local _, pages = NP.Page(Row(focus))
  local p = NP.page + d
  if p < 1 or p > pages then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  NP.page = p
  funcLuaCommand(C.SE, SE_OK)
  settle = SETTLE
  NP.DrawAll()                    -- the cards, the page line and the models of that page together
end

local function HideRest()
  for i = used.plate, used.plate_was - 1 do
    Hide(L_PLATE, i)
  end
  for i = used.text, used.text_was - 1 do
    Hide(L_TEXT, i)
  end
  used.plate_was, used.text_was = math.max(used.plate, 0), math.max(used.text, 0)
end

local function DrawAll()
  if DECL == nil then
    return
  end
  if DECL.style ~= "node_panel" then
    NP.HideLineup()
  end
  tex_wait = false
  pos = {}
  used.plate, used.text = 0, 0
  local Lo = NP.Layout()
  if DECL.style == "node_panel" then
    NP.Draw(Lo)
  else
    DrawList(Lo)
    DrawPanel(Lo)
    local cnt = HEAD and Str(HEAD.info) or ""
    local P = Lo.panel or {}
    Line(cnt, (P.x or 650) + (P.w or 1220) - #cnt * CHAR_W * 0.7, 50, 0.7, false)   -- the header's right end
  end
  HideRest()
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, false)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_GUIDE_LINE, 0, false)
end

NP.DrawAll = DrawAll

-- ---- navigation -----------------------------------------------------------------------------------------------------
local function Select(i)
  if i < 1 or i > count or i == focus then
    return false
  end
  focus = i
  NP.page = 1
  funcLuaCommand(C.SE, SE_OK)
  settle = SETTLE
  DrawAll()
  return true
end

local function Leave(result)
  ReleaseModels()
  pcall(funcLuaMenuCommand, C.FREE_CURSOR, true, false, true)
  funcLuaCommand(C.P_CLEAR, KEY_RESULT)
  funcLuaCommand(C.P_SET, KEY_RESULT, 0, result, 1)
  funcLuaCommand(C.CLOSE_MENU, MENU)
  ready = false
end

local function Decide()
  local r = Row(focus)
  if r == nil or r.locked == true then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  Log("pick", DECL.key, focus)
  Leave(focus)
end

local function Back()
  funcLuaCommand(C.SE, SE_BACK)
  Log("back", DECL and DECL.key or "")
  Leave(0)
end

-- the polled pad, for a press no callback reported (as the contact map): acts 2 frames after the press
local KEYS = {NAV = {UP = 1197218715, DOWN = 3259546669, ENTER = 1981080283, BACK = 3011112225},
              held = {}, press = {}, cb = {}, frame = 0, next_rep = {}, REPEAT_FIRST = 18, REPEAT = 6}
local function KeyOn(k)
  for _, ctrl in ipairs({1332654303 --[[MENU_CTRL]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]]}) do
    local ok, r = pcall(funcLuaCommand, C.CHECK_INPUT, ctrl, k)
    if ok and r == true then
      return true
    end
  end
  return false
end

local function Act(name)
  if name == "UP" then
    Ptr.KeyStep()
    Select(focus - 1)
  elseif name == "DOWN" then
    Ptr.KeyStep()
    Select(focus + 1)
  elseif name == "ENTER" then
    Decide()
  elseif name == "BACK" then
    Back()
  end
end

local function PollKeys(free)
  for name, cmd in pairs(KEYS.NAV) do
    local on = KeyOn(cmd)
    if on and not KEYS.held[name] then
      KEYS.press[name] = KEYS.frame
    elseif not on then
      KEYS.press[name] = nil
    end
    KEYS.held[name] = on
    local p = KEYS.press[name]
    if p ~= nil and free then
      if KEYS.frame - p == 2 and (KEYS.cb[name] or -100) < p - 2 then
        KEYS.next_rep[name] = KEYS.frame + KEYS.REPEAT_FIRST
        Act(name)
      elseif (name == "UP" or name == "DOWN") and KEYS.next_rep[name] ~= nil and KEYS.frame >= KEYS.next_rep[name]
          and KEYS.frame - p > 2 then
        KEYS.next_rep[name] = KEYS.frame + KEYS.REPEAT
        Act(name)
      end
    end
  end
end

local function PollPointer()
  Ptr.Begin()
  for i, p in pairs(pos) do
    Ptr.Box(p.x, p.y, p.hw, p.hh, i)
  end
  local ev = Ptr.Poll()
  if evt_co ~= nil or not ready or open_guard > 0 then
    return
  end
  if type(ev.hover) == "number" and ev.hover ~= focus then
    Select(ev.hover)
  end
  if type(ev.click) == "number" then
    KEYS.cb.ENTER = KEYS.frame
    Select(ev.click)
    Decide()
  elseif type(ev.wheel) == "number" then
    Select(focus + ev.wheel)
  end
end

-- ---- callbacks ------------------------------------------------------------------------------------------------------
function OnInit()
  funcLuaCommand(C.P_CLEAR, KEY_RESULT)
  art, plain_tint = VRFW_ScreenArt.Get(ART_SCREEN), {}
  for _, path in ipairs(VRFW_ScreenArt.Atlases(ART_SCREEN)) do
    Tex(path)
  end
  ready, open_guard, DECL, HEAD, rows, cards, focus, count = false, 20, nil, nil, {}, {}, 1, 0
  NP.first, NP.kits, NP.LU.named = nil, {}, {}
  used = {plate = 0, text = 0, plate_was = N.PLATE, text_was = N.TEXT}
  models, shown, placed, settle = {}, {}, {}, nil
  local key = 0
  if funcLuaCommand(C.P_EXISTS, KEY_ROW) then
    key = Int(funcLuaCommand(C.P_GET, KEY_ROW))
    funcLuaCommand(C.P_CLEAR, KEY_ROW)
  end
  CTX = 0
  if funcLuaCommand(C.P_EXISTS, KEY_CTX) then
    CTX = Int(funcLuaCommand(C.P_GET, KEY_CTX))
    funcLuaCommand(C.P_CLEAR, KEY_CTX)
  end
  local d = Call(C.ROW_DECL, key)
  if type(d) ~= "table" or type(d.source) ~= "number" then
    Log("open", "pose row", key, "not declared: closing")
    return
  end
  DECL = d
  DECL.models = math.max(1, math.min(N.SLOTS, Int(DECL.models)))
  DECL.team, DECL.icon_atlas, DECL.icon_sprite = Int(DECL.team), DECL.icon_atlas or "", DECL.icon_sprite or ""
  NP.page = 1
  -- the style's own retail art for the roles no mod declares (the Chronicle board's node panel and rate panel atlases)
  for role, a in pairs(NP.Layout().art or {}) do
    if art[role] == nil and type(a) == "table" and type(a[1]) == "string" and type(a[2]) == "string" then
      local h = string.match(a[2], "^0[xX](%x+)$")
      art[role] = {atlas = a[1], crc = h and tonumber(h, 16) or CRC32(a[2]), res = true}
    end
  end
  if DECL.icon_atlas ~= "" then
    Tex(DECL.icon_atlas)
  end
  lang = Int(Call(C.LANG))
  HEAD = Call(DECL.source, CTX, 0)
  count = type(HEAD) == "table" and Int(HEAD.count) or 0
  if count == 0 then
    Log("open", DECL.key, "context", CTX, "no entry: closing")
    DECL = nil
    return
  end
  focus = math.max(1, math.min(count, Int(HEAD.focus) > 0 and Int(HEAD.focus) or 1))
  -- the body types the pose has: a player of another body type gets no model (evt_menu_kit.lua#CharaModel)
  local bodies = nil
  local list = Call(C.POSE_BODIES, DECL.pose)
  if type(list) == "table" and #list > 0 then
    bodies = {}
    for _, b in ipairs(list) do
      bodies[b] = true
    end
  end
  -- each slot its own model key (crc32("vrfw_pose_row_slot<n>")): the shop's keys 0.. are the ones the menu under the
  -- screen uses too (the Chronicle board's caravan: slot 0, key 0), and a shared key gave the caravan this screen's
  -- model transform (drawn huge on the board after the list). The kit: the row's team (`team`, CMND_VRFW_TEAM_KIT)
  local function kit(pid)
    local r = Row(focus)
    local team = type(r) == "table" and Int(r.team) or 0
    if team == 0 then
      return 0, 0
    end
    NP.kits = NP.kits or {}
    if NP.kits[team] == nil then
      NP.kits[team] = Int(Call(C.TEAM_KIT, team))
    end
    if cards[pid] == nil then
      CardsOf({{card = pid}})
    end
    return NP.kits[team], Int((cards[pid] or {}).position) == 1 and 2 or 0
  end
  for k = 1, DECL.models do
    models[k] = EVT_CharaModelNew(L_MODEL, {slot = k - 1, key = CRC32("vrfw_pose_row_slot" .. (k - 1)),
      shadow = L_SHADOW, pose = DECL.pose, bodies = bodies, kit = kit, log = k == 1 and Log or nil})
  end
  settle = 1
  Log("open", DECL.key, "context", CTX, "entries", count, "models", DECL.models, "pose bodies",
    type(list) == "table" and #list or -1)
end

local function OpenOwnLayers()
  funcLuaMenuCommand(C.OPEN_LAYER, L_GROUND, 0)
  for i = 0, N.PLATE - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_PLATE, i)
  end
  for i = 0, N.TEXT - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_TEXT, i)
  end
  funcLuaMenuCommand(C.OPEN_LAYER, L_MODEL, 0)
  for i = 0, N.SLOTS - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_SHADOW, i)
    funcLuaMenuCommand(C.OPEN_LAYER, L_CARD, i)
  end
  funcLuaMenuCommand(C.OPEN_LAYER, L_PITCH, 0)
end

function OnSetupLayer(a1, a2)
  if a1 == L_HEADER then
    SetupSoccerTopCommonHeaderLayerInfo(a1, 4153539961, 253801632, 3969848060, 1144161661, 3293713115, 253801632, 1152304044, 305955024, 3007971317)
    if DECL ~= nil then
      UpdateTitle()
    end
    OpenOwnLayers()
  elseif a1 == L_ROW or a1 == L_TEXT then
    funcLuaMenuCommand(C.TEXT, a1, TEXT_ON, "", a2)
    funcLuaMenuCommand(C.TEXT, a1, TEXT_OFF, "", a2)
    funcLuaMenuCommand(C.TEXT_VISIBLE, a1, TEXT_ON, false, a2)
    funcLuaMenuCommand(C.TEXT_VISIBLE, a1, TEXT_OFF, false, a2)
    for _, m in ipairs(ROW_MESHES) do
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, m, false, a2)
    end
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, CUR, false)
    if a1 ~= L_ROW then
      Hide(a1, a2)
    end
  elseif a1 == L_GROUND or a1 == L_PLATE or a1 == L_PITCH then
    Hide(a1, a2)
  elseif a1 == L_CARD then
    NP.NameCard(a2)
    Hide(a1, a2)
  elseif a1 == L_MODEL then
    for _, m in ipairs({"_scr_line01", "_scr_obj01", "_dmy01"}) do   -- shop01_01's scroll bar / dummy: not used here
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, CRC32(m), false, a2)
    end
  elseif a1 == L_GUIDE_LINE then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, 0, false)
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
    if DECL == nil then
      Leave(0)
      return
    end
    UpdateTitle()
    UpdateButtonGuide()
    if DECL.style == "node_panel" then     -- over the board: no menu background, no header
      funcLuaMenuCommand(C.LAYER_VISIBLE, L_RETAIL_BG, 0, false)
      funcLuaMenuCommand(C.LAYER_VISIBLE, L_HEADER, 0, false)
    end
    DrawAll()
    Ptr.Reset()
    pcall(funcLuaMenuCommand, C.FREE_CURSOR, true, false, true)
    ready = true
    if funcLuaCommand(C.FADE_DONE) then
      funcLuaCommand(C.FADE, 0, 0.3)
    end
  elseif a1 == L_GUIDE_LINE then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, 0, false)
  end
end

function OnDecideFocus(a1, a2)
  KEYS.cb.ENTER = KEYS.frame
  if evt_co ~= nil or not ready or open_guard > 0 or Ptr.Owns() then
    return
  end
  Decide()
end

function OnEnter(a1, a2)
  KEYS.cb.ENTER = KEYS.frame
  if a1 == L_BTN or a1 == L_RET then
    return 1
  end
  OnDecideFocus(a1, a2)
end

function OnFunction(a1, a2)
  local id = a1
  if a1 ~= FN.UP and a1 ~= FN.DOWN and a1 ~= FN.LEFT and a1 ~= FN.RIGHT and a1 ~= FN.PREV and a1 ~= FN.NEXT
      and a1 ~= FN.EXTRA then
    id = a2
  end
  if id == FN.PREV or id == FN.NEXT or id == FN.EXTRA then
    if evt_co ~= nil or not ready or open_guard > 0 or DECL == nil then
      return 1
    end
    if id == FN.EXTRA then
      if DECL.team ~= 0 then
        funcLuaCommand(C.SE, SE_DECIDE)
        Log("extra", DECL.key)
        Leave(-1)                  -- the declaration's «Y» action: the opener runs it and opens the screen again
      end
    else
      NP.Turn(id == FN.PREV and -1 or 1)
    end
    return 1
  end
  if id == FN.UP or id == FN.LEFT then
    KEYS.cb.UP = KEYS.frame
  elseif id == FN.DOWN or id == FN.RIGHT then
    KEYS.cb.DOWN = KEYS.frame
  else
    return
  end
  if evt_co ~= nil or not ready then
    return 1
  end
  Ptr.KeyStep()
  Select(focus + ((id == FN.UP or id == FN.LEFT) and -1 or 1))
  return 1
end

function OnBack(a1)
  KEYS.cb.BACK = KEYS.frame
  if evt_co ~= nil or not ready or open_guard > 0 then
    return 1
  end
  Back()
  return 1
end

function Step()
  if evt_co ~= nil then
    if coroutine.status(evt_co) == "dead" then
      evt_co = nil
    else
      local ok, err = coroutine.resume(evt_co)
      if not ok then
        Log("error", tostring(err))
        evt_co = nil
      end
    end
  end
  if not ready then
    return
  end
  if open_guard > 0 then
    open_guard = open_guard - 1
  end
  -- a declared atlas still loading: redraw when it is in (600 frames at most)
  if tex_wait then
    local still = false
    for path, f in pairs(tex_frames) do
      if f >= 0 then
        if funcLuaCommand(C.TEX_LOADING, CRC32(path)) == true then
          tex_frames[path] = f + 1 > 600 and -1 or f + 1
          still = still or f + 1 <= 600
        else
          tex_frames[path] = -2
        end
      end
    end
    if not still then
      DrawAll()
    end
  end
  if settle ~= nil then
    settle = settle - 1
    if settle <= 0 then
      settle = nil
      ApplyModels()
    end
  end
  ModelStep()
  PollPointer()
  KEYS.frame = KEYS.frame + 1
  local free = evt_co == nil and open_guard <= 0 and funcLuaCommand(C.MSG_BUSY) ~= true
  PollKeys(free)
end
