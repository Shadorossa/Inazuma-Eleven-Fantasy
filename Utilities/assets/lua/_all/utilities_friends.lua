-- Utilities › friends panel («Lista de amigos», docs/game/ui/friends.md §4). Runs in every menu VM (lua\_all):
--  * every VM reports its menu when it opens (CMND_UTIL_FRIENDS_STATUS(<script stem>): the status friends see);
--  * in the hubs of the top bar (the ones with the layers util_fr_* of content\menus\friends_panel.toml) the top bar
--    entry «Lista de amigos» (action lua Utilities.FriendsPanel) slides a narrow panel in on the right, over the menu:
--    the player's Steam friends in one list (in the game, online, away, offline; then by name), one compact row each
--    (a status dot, the name, the status). A on a friend opens his details on the panel's left: his active team
--    (faces, formation), the career summary and the lines other mods add, then his actions (A runs one). B goes back /
--    closes; the arrows, L1 / R1, the wheel and the mouse move. The data and the actions are Utilities' script
--    (scripts\friends.lua, CMND_UTIL_FRIENDS_*) over the VR-Framework's friends API (Steam through the game's own
--    steam_api64.dll, never EOS).
-- Engine calls only from OnInit / Step / layer callbacks (nothing at chunk load but table definitions).
Utilities = type(Utilities) == "table" and Utilities or {}

if UTIL_FP == nil then
  UTIL_FP = {
    CMD = {
      OPEN = 2960985135, LAYOUT = 832611508, ROW = 2296591079, ACTIONS = 3156590377, DO = 4170892414, POLL = 2427549134,
      DETAILS = 3410707788, DETAILS_POLL = 2315523593, INBOX = 1057064150, STATUS = 1889184330,
    },
    C = {
      LOG = 3661580131, TEXT_GET = 4074371074, LANG = 477234096, SND = 3073642526,
      LAYER_NUM = 1175615627, OPEN_LAYER = 629267548, VISIBLE = 711242136, POS = 1389957207, SCALE = 3778714801,
      SPRITE = 558735651, ALPHA = 4231609516, MESH_VISIBLE = 3405944500, NODE_VISIBLE = 2158717427,
      TEXT_VISIBLE = 2735666188, SET_TEXT = 1083631230, LOAD_TEX = 839427544, TEX_LOADING = 1506186496,
      FACE = 552280324, RESET_FACE = 4176779611, LOADING = 1277042906, CHECK_INPUT = 4265778440,
      POINTER = 558229292, MOVED = 3272825600,
    },
    L = { BACK = 3391176382, PLATE = 3848078112, ICON = 3262895698, FACE = 2734392558, TEXT = 2623821902 },
    QUAD = 1909474081,            -- icon_new01: the cmn01_10 quad's sprite slot
    Q = 36,                       -- the cmn01_10 quad side
    TXT = { NODE = 378327766 --[[_text_cmd_back01]], MESHES = {298211823, 2853207670}, BOX_LEFT = -384, BOX_MID_Y = 144 },
    CARD = {
      MESH = 2828003679 --[[_icon_chr_dmy_l01]], TEX = 21929195 --[[icon_chr_dmy_l01]], NAME = 170976702 --[[_text_chr01]],
      RH = 156, OX = 59, OY = 11,
      HIDE = {"_icon_chr_base_l01", "_icon_chr_gradation_l01", "_seasonal_frame_l01", "_avatar_frame_l01",
        "_icon_chr_focus_l01", "_icon_chr_position_dmy_l01", "_icon_base_l01", "_icon_chr_type_dmy_l01", "_icon_lock01",
        "_icon_captain01", "_icon_ai_role_dmy01", "_gtxt_lv_l01", "_icon_card01", "_icon_chr_def01_l",
        "_icon_chr_grayout01", "_basara_avatar_l01", "_num_chr_dmy_l01", "_num_chr_dmy_l02", "_gauge_exp_base_l01",
        "_gauge_exp_l01", "_icon_synergy_l01", "_icon_synergy_l02", "_leader_base01", "_gtxt_leader01"},
      HIDE_NODES = {"_pos_base02", "_pos_leader01", "_pos_ai_role01", "_num_chr_l01", "_num_chr_l02", "_pos_gauge_exp_l01"},
    },
    CTRLS = {1332654303 --[[MENU_CTRL]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]]},
    KEYS = {up = 1197218715, down = 3259546669, enter = 1981080283, back = 3011112225,
            l1 = 3966226594, r1 = 942075773, rclick = 3473063670,
            click = 218912913 --[[CMD_EVT_MOUSE_LEFT]], wup = 1942756954, wdown = 1623431741,
            left = 2765147006, right = 2075023265},
    SY_OK = 3848881948, SY_MOVE = 2500047763, SY_ERROR = 2086672038,
    REPEAT_FIRST = 18, REPEAT_EVERY = 5, REFRESH = 300, ASK_FRAMES = 600,
    MSG_MAX = 108000,                       -- a message box nobody answers (frames)
    MSG_UNITS = 34,                         -- the message box's line length (Latin characters; a CJK one counts 2)
    msg = nil,                              -- the open message box {lines, buttons, sel}
    here = false,      -- this VM has the panel's layers
    open = false, closing = false, anim = 0, frame = 0, dx = 0,
    mode = "list",     -- "list" | "details"
    rows = {}, sel = nil, scroll = 0, ready = false, err = "",
    -- the panel's art: Utilities' own atlas (research/scripts/friends_art.py), a `res` of the panel's layers in every
    -- hub (content\menus\friends_panel.toml), so it is loaded with the menu; sprites util_friends_<name>
    art = "#/menu/220_img/util_friends/util_friends.g4tx", SPRITE = "util_friends_",
    art_ok = false,    -- the atlas answered «loaded» (nothing of the panel is drawn before: a swap to a texture not
                       -- there yet keeps the quad's base sprite, the red «new» badge of cmn01_10, and was never retried)
    AVATAR_WAIT = 10,  -- frames a served Steam avatar must answer «loaded» before it replaces the placeholder
    det = nil,         -- the open details: { i, state, team, form, faces, stats, acts, asel, asked_at }
    P = { x = 1500, width = 420, top = 72, row_h = 40, head_h = 56, details_w = 560, slide = 10 },
    co = nil, held = {}, sent = {}, used = {}, shown = {}, crcs = {}, texts = {}, loaded = {}, faces = {},
    cap = {}, opened = {},
    idle = 0, HIDE_EVERY = 60,                       -- frames between two checks that the closed panel is hidden
  }
end

local FP = UTIL_FP

local function Log(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  pcall(funcLuaCommand, FP.C.LOG, "utilities friends " .. table.concat(p, " "))
end

local function Crc(s)
  local c = FP.crcs[s]
  if c == nil and type(CRC32) == "function" then
    c = CRC32(s)
    FP.crcs[s] = c
  end
  return c or 0
end

-- a text of text\rows\friends.toml (id "Utilities.Friends.<name>"), in the game's language
local function Tx(name)
  local t = FP.texts[name]
  if t == nil then
    local ok, s = pcall(funcLuaCommand, FP.C.TEXT_GET, Crc("Utilities.Friends." .. name))
    t = (ok and type(s) == "string" and s ~= "") and s or name
    FP.texts[name] = t
  end
  return t
end

-- a retail menu global that only some menus define (e.g. SetInputEnbaleMenuObject is missing in bb_stadium_top_menu):
-- called only when present, so a hub without it does not raise a LUAERR
local function Opt(f, ...)
  if type(f) == "function" then pcall(f, ...) end
end

local function M(cmd, ...)
  local ok, a, b = pcall(funcLuaMenuCommand, cmd, ...)
  if ok then return a, b end
  return nil
end

-- ------------------------------------------------------------------------------------------------ drawing pools

-- a command sent only when its arguments changed since the last time for that (layer, index, property)
local function Set(layer, idx, prop, cmd, ...)
  local k = layer .. ":" .. idx .. ":" .. prop
  local a = table.pack(...)
  local sig = {}
  for i = 1, a.n do sig[#sig + 1] = tostring(a[i]) end
  sig = table.concat(sig, ",")
  if FP.sent[k] == sig then return end
  FP.sent[k] = sig
  M(cmd, ...)
end

local function Slot(layer)
  local n = FP.used[layer] or 0
  if n >= (FP.cap[layer] or 0) then return nil end
  FP.used[layer] = n + 1
  if not FP.opened[layer .. ":" .. n] then
    M(FP.C.OPEN_LAYER, layer, n)
    FP.opened[layer .. ":" .. n] = true
  end
  return n
end

local function Show(layer, i)
  Set(layer, i, "vis", FP.C.VISIBLE, layer, i, true)
  FP.shown[layer .. ":" .. i] = true
end

-- a quad (top-left x, y; w x h; screen px, y down) with a sprite of `tex` (a menu path)
local function Quad(layer, tex, sprite, x, y, w, h, alpha)
  local i = Slot(layer)
  if i == nil then return nil end
  Show(layer, i)
  Set(layer, i, "sc", FP.C.SCALE, layer, w / FP.Q, h / FP.Q, 1, i)
  Set(layer, i, "sp", FP.C.SPRITE, layer, Crc(tex), Crc(sprite), FP.QUAD, 0, i)
  Set(layer, i, "pos", FP.C.POS, layer, x + w / 2, -(y + h / 2), 0, i)
  Set(layer, i, "a", FP.C.ALPHA, layer, i, 0, alpha or 1)
  return i
end

-- a sprite of the panel's atlas, x shifted by the slide
local function Art(layer, name, x, y, w, h, alpha)
  return Quad(layer, FP.art, FP.SPRITE .. name, x + FP.dx, y, w, h, alpha)
end

-- `tex` (a menu path) is in this VM's texture cache: asked once, then «not loading» for `wait` frames in a row
local function TexReady(tex, wait)
  local st = FP.loaded[tex]
  if st == nil then
    pcall(funcLuaCommand, FP.C.LOAD_TEX, tex)
    st = {asked = FP.frame, ok = 0}
    FP.loaded[tex] = st
  end
  local ok, loading = pcall(funcLuaCommand, FP.C.TEX_LOADING, Crc(tex))
  if ok and loading == false then st.ok = st.ok + 1 else st.ok = 0 end
  return st.ok >= (wait or 1)
end

local ArtReady   -- below, with the hiding of the closed panel

-- a text: left edge x, vertical middle y (screen px), scale
local function Text(s, x, y, sc)
  if s == nil or s == "" then return nil end
  local L, T = FP.L.TEXT, FP.TXT
  local i = Slot(L)
  if i == nil then return nil end
  sc = sc or 1
  Show(L, i)
  for _, m in ipairs(T.MESHES) do Set(L, i, "m" .. m, FP.C.MESH_VISIBLE, L, m, false, i) end
  Set(L, i, "txt", FP.C.SET_TEXT, L, T.NODE, s, i)
  Set(L, i, "sc", FP.C.SCALE, L, sc, sc, 1, i)
  Set(L, i, "pos", FP.C.POS, L, x + FP.dx - T.BOX_LEFT * sc, -y - T.BOX_MID_Y * sc, 0, i)
  return i
end

-- an avatar: the neutral placeholder until the served Steam picture answers «loaded» for AVATAR_WAIT frames (never on
-- a timeout: a swap to a texture that is not there keeps the badge sprite), then the picture; a light frame on top
local function Avatar(tex, sprite, x, y, s)
  if type(tex) == "string" and tex ~= "" and type(sprite) == "string" and sprite ~= "" and TexReady(tex, FP.AVATAR_WAIT) then
    Quad(FP.L.ICON, tex, sprite, x + FP.dx, y, s, s, 1)
  else
    Art(FP.L.ICON, "noavatar", x, y, s, s, 1)
  end
  return Art(FP.L.ICON, "frame", x, y, s, s, 1)
end

-- a face card (the retail character card, portrait only) centred at (cx, cy), `size` px; key = chara_base
local function Face(key, cx, cy, size)
  local L, K = FP.L.FACE, FP.CARD
  local i = Slot(L)
  if i == nil then return end
  local s = size / K.RH
  Show(L, i)
  Set(L, i, "sc", FP.C.SCALE, L, s, s, 1, i)
  Set(L, i, "pos", FP.C.POS, L, cx + FP.dx - K.OX * s, -cy - K.OY * s, 0, i)
  if FP.faces[i] ~= key then
    for _, m in ipairs(K.HIDE) do M(FP.C.MESH_VISIBLE, L, Crc(m), false, i) end
    for _, m in ipairs(K.HIDE_NODES) do M(FP.C.NODE_VISIBLE, L, Crc(m), false, i) end
    M(FP.C.TEXT_VISIBLE, L, K.NAME, false, i)
    M(FP.C.RESET_FACE, L, i, K.TEX)
    Opt(SetDisableForceCharaInvalidUseTarget)
    M(FP.C.FACE, L, i, false, K.MESH, K.TEX, 0, 0, key, 0, false, true)
    Opt(SetEnableForceCharaInvalidUseTarget)
    FP.faces[i] = key
  end
  M(FP.C.MESH_VISIBLE, L, K.MESH, M(FP.C.LOADING, L, i) ~= true, i)
end

local function BeginFrame()
  FP.used = {}
end

-- hide every instance shown before and not drawn this frame
local function EndFrame()
  for k in pairs(FP.shown) do
    local layer, i = k:match("^(%d+):(%d+)$")
    layer, i = tonumber(layer), tonumber(i)
    if layer and i and i >= (FP.used[layer] or 0) then
      Set(layer, i, "vis", FP.C.VISIBLE, layer, i, false)
      FP.shown[k] = nil
      if layer == FP.L.FACE then FP.faces[i] = nil end
    end
  end
end

-- ------------------------------------------------------------------------------------------------ input

local function In(input)
  for _, c in ipairs(FP.CTRLS) do
    local ok, r = pcall(funcLuaCommand, FP.C.CHECK_INPUT, c, input)
    if ok and r == true then return true end
  end
  return false
end

local function KeysReset()
  for name, input in pairs(FP.KEYS) do FP.held[name] = In(input) and 1000 or 0 end
end

local function Pressed(name, repeats)
  local now = In(FP.KEYS[name])
  local h = FP.held[name] or 0
  if not now then
    FP.held[name] = 0
    return false
  end
  FP.held[name] = h + 1
  if h == 0 then return true end
  return repeats and h >= FP.REPEAT_FIRST and (h - FP.REPEAT_FIRST) % FP.REPEAT_EVERY == 0
end

local function Snd(s) pcall(funcLuaCommand, FP.C.SND, s) end

-- The hub and every menu over it ignore the pad / keys while the panel is open (owner 2026-10-12: DOWN moved the list
-- AND the «Modos de juego» cursor; SetInputEnbaleMenuObject alone did not stop it): the framework's top bar input
-- guard (VRFW_TopBarGuard, 10_top_bar.lua in every menu VM) suspends each menu while its heartbeat runs and gives every
-- menu back its own wish when it stops (at once on Beat(false), at the latest 30 frames after the last beat). Beaten
-- every frame while open, never while the game's keyboard is up (that menu needs its input), cleared on close.
local function Guard(on)
  local G = VRFW_TopBarGuard
  if type(G) == "table" and type(G.Beat) == "function" then
    local ok, err = pcall(G.Beat, on)
    if not ok and not FP.guard_err then
      FP.guard_err = true
      Log("input guard error", tostring(err))
    end
  end
end

-- ------------------------------------------------------------------------------------------------ message windows

-- the panel's own message box (Utilities 1.14.13, owner 2026-10-12): the retail message window (general_window) over a
-- hub got no input (its «Sí» did nothing), so every message and question of the panel is a box drawn by the panel
-- itself, over its list (DrawModal), read by the panel's coroutine. kind 1 = OK, 2 = Sí / No. Returns 0 = OK / Sí,
-- 1 = No, -1 = closed (B / Esc / right click). Keys: LEFT / RIGHT / UP / DOWN = the button, A / Enter = it, the mouse
-- over / on a button. MSG_MAX frames without an answer = closed.
local function MsgLines(text)
  local out = {}
  text = tostring(text or ""):gsub(string.char(92) .. "n", "\n")
  for para in (text .. "\n"):gmatch("([^\n]*)\n") do
    local line, units = "", 0
    for word in para:gmatch("%S+") do
      local u = 0
      for ch in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do u = u + ((ch:byte(1) or 0) >= 0xE3 and 2 or 1) end
      if units > 0 and units + 1 + u > FP.MSG_UNITS then
        out[#out + 1] = line
        line, units = word, u
      else
        line = units > 0 and (line .. " " .. word) or word
        units = units + (units > 0 and 1 or 0) + u
      end
    end
    out[#out + 1] = line
  end
  while #out > 1 and out[#out] == "" do out[#out] = nil end
  return out
end

-- the box's geometry (screen px): left, top, width, height, the buttons' top and width
local function MsgBox()
  local P, B = FP.P, FP.msg
  local w = P.width - 32
  local x = P.x + 16
  local h = 40 + #B.lines * 34 + 24 + 50 + 24
  local y = math.floor(P.top + 150 + ((1080 - 56) - (P.top + 150) - h) / 2)
  local bw = #B.buttons == 2 and math.floor((w - 48 - 16) / 2) or (w - 48)
  return x, y, w, h, y + h - 24 - 50, bw
end

local function MsgButtonAt(px, py)
  if FP.msg == nil or type(px) ~= "number" or type(py) ~= "number" then return nil end
  local x, _, _, _, by, bw = MsgBox()
  for k = 1, #FP.msg.buttons do
    local bx = x + 24 + (k - 1) * (bw + 16)
    if px >= bx and px <= bx + bw and py >= by and py <= by + 50 then return k end
  end
  return nil
end

local function DrawModal()
  local B = FP.msg
  if B == nil then return end
  local x, y, w, h, by, bw = MsgBox()
  local dx = FP.dx
  FP.dx = 0
  Art(FP.L.ICON, "details", x, y, w, h, 1)
  Art(FP.L.ICON, "edge", x, y, w, 3, 1)
  for k, line in ipairs(B.lines) do
    Text(line, x + 24, y + 40 + (k - 1) * 34, 0.78)
  end
  for k, label in ipairs(B.buttons) do
    local bx = x + 24 + (k - 1) * (bw + 16)
    Art(FP.L.ICON, k == B.sel and "button_sel" or "button", bx, by, bw, 50, 1)
    Text(label, bx + 24, by + 25, 0.8)
  end
  FP.dx = dx
end

local function Msg(text, kind)
  kind = kind or 1
  local buttons = kind == 2 and {Tx("BtnYes"), Tx("BtnNo")} or {Tx("BtnOk")}
  FP.msg = {lines = MsgLines(text), buttons = buttons, sel = 1}
  Log("message", kind, tostring(text):sub(1, 60))
  KeysReset()
  local n = -1
  for _ = 1, FP.MSG_MAX do
    coroutine.yield()
    local B = FP.msg
    local kb, krc, ok = Pressed("back"), Pressed("rclick"), Pressed("enter")
    local kl, ku, kr, kd, kc = Pressed("left"), Pressed("up"), Pressed("right"), Pressed("down"), Pressed("click")
    local back, prev, nxt = kb or krc, kl or ku, kr or kd
    local px, py = M(FP.C.POINTER)
    local over = MsgButtonAt(px, py)
    if over ~= nil and M(FP.C.MOVED) == true and over ~= B.sel then B.sel = over end
    if kc and over ~= nil then
      B.sel, ok = over, true
    end
    if back then
      n = -1
      Snd(FP.SY_MOVE)
      break
    elseif ok then
      n = B.sel - 1
      Snd(FP.SY_OK)
      break
    elseif (prev or nxt) and #B.buttons > 1 then
      B.sel = B.sel % #B.buttons + 1
      Snd(FP.SY_MOVE)
    end
  end
  FP.msg = nil
  KeysReset()
  Log("message answered", n)
  return n
end

local function Run(fn)
  FP.co = coroutine.create(fn)
end

-- ------------------------------------------------------------------------------------------------ data

local function Load(refresh)
  local okL, lang = pcall(funcLuaCommand, FP.C.LANG)
  local ok, ready, n, inbox, err = pcall(funcLuaCommand, FP.CMD.OPEN, refresh == true, okL and lang or -1)
  if not ok then
    Log("open error", tostring(ready))
    FP.ready, FP.err = false, "noscript"
    return 0
  end
  -- an unanswered command (the friends script switched off by an error) gives no row count: say so in the panel
  if type(n) ~= "number" then
    Log("open: no answer from the friends script (Utilities.Friends.Open)")
    FP.ready, FP.err = false, "noscript"
    return 0
  end
  FP.ready, FP.err = ready == true, tostring(err or "")
  local keep = FP.sel and FP.rows[FP.sel] and FP.rows[FP.sel].id or nil
  local function pick(r) return r.kind == "friend" end
  FP.rows = {}
  for i = 1, tonumber(n) or 0 do
    local okR, kind, group, name, st, dot, badge, room, tex, sprite, id = pcall(funcLuaCommand, FP.CMD.ROW, i)
    if okR and type(kind) == "string" and kind ~= "" then
      FP.rows[#FP.rows + 1] = {kind = kind, group = group, name = name, status = st, dot = dot, badge = badge,
                               room = room == true, tex = tex, sprite = sprite, idx = i,
                               id = kind == "friend" and id or nil}
    end
  end
  -- the selection: the same friend after a refresh, else the first friend
  FP.sel = nil
  for i, r in ipairs(FP.rows) do
    if pick(r) and (keep == nil or r.id == keep) then FP.sel = i break end
  end
  if FP.sel == nil then
    for i, r in ipairs(FP.rows) do
      if pick(r) then FP.sel = i break end
    end
  end
  return tonumber(inbox) or 0
end

local function ShowInbox()
  while true do
    local ok, kind, from, lines, data = pcall(funcLuaCommand, FP.CMD.INBOX)
    if not ok or type(kind) ~= "string" or kind == "" then return end
    if kind == "invite" then
      Msg(string.format(Tx("InviteGot"), tostring(from)))
    else
      Msg(string.format(Tx("CodeGot"), tostring(from)) .. "\n" .. tostring(lines) .. "\n" .. tostring(data))
    end
  end
end

-- ------------------------------------------------------------------------------------------------ layout

local function RowH(_r)
  return FP.P.row_h
end

-- top of row i in list space (0 = the list's first pixel)
local function RowTop(i)
  local y = 0
  for k = 1, i - 1 do y = y + RowH(FP.rows[k]) end
  return y
end

local function ListBox()
  return FP.P.top + FP.P.head_h + 8, 1080 - 56
end

local function KeepVisible()
  if FP.sel == nil then return end
  local y0, y1 = ListBox()
  local t = RowTop(FP.sel)
  local h = RowH(FP.rows[FP.sel])
  if t < FP.scroll then FP.scroll = math.max(0, t) end
  if t + h > FP.scroll + (y1 - y0) then FP.scroll = t + h - (y1 - y0) end
end

local function StatusText(r)
  if r.status == nil or r.status == "" then return "" end
  local k = "St_" .. r.status
  local s = Tx(k)
  if s == k then s = r.status end
  if r.room then s = s .. "  ·  " .. Tx("HasRoom") end
  return s
end

-- ------------------------------------------------------------------------------------------------ drawing

local function DrawList()
  local P = FP.P
  local x, w = P.x, P.width
  local h = 1080 - P.top
  -- a veil over the hub left of the panel (and of the details pane), the panel opaque: nothing of the hub shows through
  local vx = FP.mode == "details" and (x - P.details_w) or x
  Art(FP.L.BACK, "veil", 0, P.top, math.max(0, vx + FP.dx), h, 1)
  Art(FP.L.BACK, "shadow", x - 28, P.top, 28, h, 1)
  Art(FP.L.BACK, "panel", x, P.top, w, h, 1)
  Art(FP.L.PLATE, "edge", x, P.top, 3, h, 1)
  -- header: the title and how many friends
  Art(FP.L.PLATE, "head", x, P.top, w, P.head_h, 1)
  local count = 0
  for _, r in ipairs(FP.rows) do
    if r.kind == "friend" then count = count + 1 end
  end
  Text(Tx("Title") .. string.format("  (%d)", count), x + 20, P.top + P.head_h / 2, 0.95)
  local y0, y1 = ListBox()
  local y = y0 - FP.scroll
  if FP.err == "noscript" then
    Text(Tx("NoScript"), x + 20, y0 + P.row_h / 2, 0.7)
  end
  -- an open message box covers the list: no row under it (the texts' layer draws above the box's layer)
  for i, r in ipairs(FP.msg == nil and FP.rows or {}) do
    local rh = RowH(r)
    if y >= y0 - 2 and y + rh <= y1 + 2 then
      if r.kind == "none" then
        Text(Tx("Nobody"), x + 20, y + rh / 2, 0.7)
      else
        if i == FP.sel then
          Art(FP.L.PLATE, "sel", x + 8, y + 2, w - 16, rh - 4, 1)
        end
        Art(FP.L.ICON, "dot_" .. ((r.dot ~= nil and r.dot ~= "") and r.dot or "off"), x + 18, y + rh / 2 - 6, 12, 12, 1)
        Text(r.name, x + 40, y + rh / 2, 0.78)
        Text(StatusText(r), x + w - 170, y + rh / 2, 0.6)
      end
    end
    y = y + rh
  end
  Art(FP.L.PLATE, "line", x + 16, 1080 - 50, w - 32, 2, 1)
  Text(FP.mode == "details" and Tx("DetailKeys") or Tx("ListKeys"), x + 20, 1080 - 26, 0.7)
end

local function DrawDetails()
  local D = FP.det
  if D == nil then return end
  local P = FP.P
  local dw = P.details_w
  local x = P.x - dw
  local r = FP.rows[D.i] or {}
  Art(FP.L.BACK, "details", x, P.top, dw - 6, 1080 - P.top, 1)
  Art(FP.L.PLATE, "edge", x, P.top, 3, 1080 - P.top, 1)
  Avatar(r.tex, r.sprite, x + 24, P.top + 20, 96)
  Text(r.name, x + 140, P.top + 50, 1.0)
  Text(StatusText(r), x + 140, P.top + 88, 0.75)
  if r.badge == "ok" or r.badge == "warn" then
    Art(FP.L.ICON, r.badge, x + dw - 70, P.top + 30, 40, 40, 1)
  end
  local y = P.top + 140
  if D.state == "wait" then
    Text(Tx("Loading"), x + 24, y + 20, 0.8)
  elseif D.state == "error" then
    Text(Tx("NoAnswer"), x + 24, y + 20, 0.75)
  elseif D.state == "ok" then
    Text(string.format(Tx("Team"), D.team ~= "" and D.team or "—"), x + 24, y + 18, 0.85)
    Text(string.format(Tx("Formation"), D.form ~= "" and D.form or "—"), x + 24, y + 50, 0.75)
    y = y + 76
    local cols, size, pitch = 4, 104, 130
    for k, f in ipairs(D.faces) do
      if k > 11 then break end
      local c, rr = (k - 1) % cols, math.floor((k - 1) / cols)
      local cx, cy = x + 24 + size / 2 + c * pitch, y + size / 2 + rr * (pitch + 14)
      if f.key ~= nil and f.key ~= 0 then Face(f.key, cx, cy, size) end
      Text("Lv " .. tostring(f.level), cx - size / 2, cy + size / 2 + 12, 0.6)
    end
    y = y + math.ceil(math.min(#D.faces, 11) / cols) * (pitch + 14) + 6
    for _, s in ipairs(D.stats) do
      local line
      if s.key == "x" then
        line = s.name .. ": " .. s.value
      else
        line = string.format(Tx("Stat_" .. s.key), s.name, s.value)
      end
      Text(line, x + 24, y + 14, 0.72)
      y = y + 32
    end
  end
  -- the actions, from the bottom up
  local n = #D.acts
  local ay = 1080 - 64 - n * 54
  for k, a in ipairs(D.acts) do
    local sel = k == D.asel
    Art(FP.L.PLATE, sel and "button_sel" or "button", x + 24, ay + (k - 1) * 54, dw - 60, 46, 1)
    Text(Tx("Act_" .. a), x + 44, ay + (k - 1) * 54 + 23, 0.8)
  end
end

local function Draw()
  BeginFrame()
  -- hidden while the game's keyboard is up (the panel draws at 1001-1005, over the keyboard menu)
  if FP.open and FP.art_ok then
    DrawList()
    if FP.mode == "details" then DrawDetails() end
    DrawModal()
  end
  EndFrame()
end

-- ------------------------------------------------------------------------------------------------ actions

local function DetailsOpen(i)
  local r = FP.rows[i]
  if r == nil then return end
  local okA, list = pcall(funcLuaCommand, FP.CMD.ACTIONS, r.idx)
  local acts = {}
  for a in tostring(okA and list or ""):gmatch("[^,]+") do acts[#acts + 1] = a end
  local okD, asked = pcall(funcLuaCommand, FP.CMD.DETAILS, r.idx)
  FP.det = {i = i, idx = r.idx, state = (okD and asked == true) and "wait" or "none", team = "", form = "", faces = {},
            stats = {}, acts = acts, asel = 1, asked_at = FP.frame}
  FP.mode = "details"
  Snd(FP.SY_OK)
end

local function DetailsPoll()
  local D = FP.det
  if D == nil or D.state ~= "wait" or (FP.frame - D.asked_at) % 10 ~= 0 then return end
  local ok, st, team, form, faces, stats = pcall(funcLuaCommand, FP.CMD.DETAILS_POLL, D.idx)
  if not ok then D.state = "error" return end
  if st == "wait" then
    if FP.frame - D.asked_at > FP.ASK_FRAMES then D.state = "error" end
    return
  end
  if st ~= "ok" then D.state = "error" return end
  D.state, D.team, D.form = "ok", tostring(team or ""), tostring(form or "")
  D.faces, D.stats = {}, {}
  for key, lv in tostring(faces or ""):gmatch("(%d+):(%d+):[^|]*") do
    D.faces[#D.faces + 1] = {key = tonumber(key), level = tonumber(lv)}
  end
  for line in tostring(stats or ""):gmatch("[^\n]+") do
    local k, n, v = line:match("^([^\t]*)\t([^\t]*)\t(.*)$")
    if k then D.stats[#D.stats + 1] = {key = k, name = n, value = v} end
  end
end

local function Act(idx, a, name)
  local okd, st, text = pcall(funcLuaCommand, FP.CMD.DO, idx, a)
  if not okd then st, text = "error", "" end
  if st == "wait" then
    Snd(FP.SY_OK)
    for _ = 1, FP.ASK_FRAMES / 10 do
      for _ = 1, 10 do coroutine.yield() end
      local okp, s2, t2 = pcall(funcLuaCommand, FP.CMD.POLL, idx, a)
      if not okp then st = "error" break end
      st, text = s2, t2
      if st ~= "wait" then break end
    end
    if st ~= "ok" then
      Msg(Tx("NoAnswer"))
      return
    end
  end
  if st ~= "ok" then
    Log("action refused", a, tostring(text))
    Snd(FP.SY_ERROR)
    Msg((a == "invite" and tostring(text):find("no open room")) and Tx("NoRoom") or Tx("Failed"))
    return
  end
  if a == "invite" then
    Msg(string.format(Tx("Invited"), tostring(name)))
  elseif a == "join" then
    Msg(string.format(Tx("Joined"), tostring(name)))
  elseif a == "code" then
    Msg(string.format(Tx("CodeSent"), tostring(name)) .. "\n" .. tostring(text))
  elseif a == "mods" then
    Msg((text == nil or text == "") and Tx("ModsSame") or (Tx("ModsDiff") .. "\n" .. tostring(text)))
  end
end

-- ------------------------------------------------------------------------------------------------ open / close

local function Layout()
  local ok, x, w, top, rh, hh, dw, sl = pcall(funcLuaCommand, FP.CMD.LAYOUT)
  if not ok or type(x) ~= "number" then x, w, top, rh, hh, dw, sl = 1500, 420, 72, 40, 56, 560, 10 end
  FP.P = {x = x, width = w, top = top, row_h = rh, head_h = hh, details_w = dw, slide = math.max(1, sl)}
end

local function Caps()
  for _, L in pairs(FP.L) do
    local n = M(FP.C.LAYER_NUM, L)
    FP.cap[L] = type(n) == "number" and n or 0
  end
end

local function Open()
  Layout()
  Caps()
  FP.sent, FP.faces = {}, {}   -- a hub that rebuilt its instances (child menu, group reopened) gets every property again
  ArtReady()
  local inbox = Load(false)
  FP.open, FP.closing, FP.anim, FP.mode, FP.det, FP.scroll = true, false, 0, "list", nil, 0
  KeepVisible()
  Opt(SetInputEnbaleMenuObject, false)
  KeysReset()
  Snd(FP.SY_OK)
  Log("opened", #FP.rows, "rows; ready", tostring(FP.ready), FP.err)
  if inbox > 0 then Run(ShowInbox) end
end

local function Close()
  FP.closing, FP.anim = true, FP.P.slide
  Snd(FP.SY_MOVE)
end

local function Finish()
  Guard(false)
  FP.open, FP.closing, FP.mode, FP.det, FP.co = false, false, "list", nil, nil
  BeginFrame()
  EndFrame()
  Opt(SetInputEnbaleMenuObject, true)
  Log("closed")
end

-- the top bar entry (action lua Utilities.FriendsPanel): open / close
function Utilities.FriendsPanel(_e)
  if not FP.here then
    Log("no panel layers in this menu")
    Snd(FP.SY_ERROR)
    return
  end
  if FP.open and not FP.closing then Close() else Open() end
end

-- ------------------------------------------------------------------------------------------------ art, hiding

-- the art is in this VM's texture cache (the panel's sprites can be drawn); once true it stays true
ArtReady = function()
  if not FP.art_ok and TexReady(FP.art, 1) then
    FP.art_ok = true
    FP.sent = {}   -- every property sent again (nothing was drawn before, but no stale swap may stay cached)
  end
  return FP.art_ok
end

-- every instance of the panel's layers hidden (2026-10-12, Utilities 1.14.2): the layers sit at draw priority
-- 1001-1005 since 1.14.1, above the hub's header. An instance the engine sets up / opens without our OnSetupLayer /
-- OnOpenLayer wrappers seeing it (a hub whose script has no OnOpenLayer, e.g. market_menu; a group opened again after
-- a child menu) kept its retail look at its default place: the face card (team00_01_chara_card_for_list) drew as a
-- dark box at the top-left over the Mercado / Oficina de fichajes title. The closed panel now hides them itself.
local function HideAll()
  for _, L in pairs(FP.L) do
    for i = 0, (FP.cap[L] or 0) - 1 do
      if not FP.shown[L .. ":" .. i] then
        M(FP.C.VISIBLE, L, i, false)
        FP.sent[L .. ":" .. i .. ":vis"] = nil
      end
    end
  end
end

local function StepIdle()
  FP.frame = FP.frame + 1
  FP.idle = FP.idle + 1
  if FP.idle % FP.HIDE_EVERY == 1 then
    ArtReady()
    HideAll()
  end
end

-- ------------------------------------------------------------------------------------------------ per frame

local function Hit(px, py)
  local P = FP.P
  if px < P.x then return nil end
  local y0, y1 = ListBox()
  if py < y0 or py > y1 then return nil end
  local y = y0 - FP.scroll
  for i, r in ipairs(FP.rows) do
    local rh = RowH(r)
    if py >= y and py < y + rh then return r.kind == "friend" and i or nil end
    y = y + rh
  end
  return nil
end

local function MoveSel(dir, steps)
  if FP.sel == nil then return end
  local i, moved = FP.sel, 0
  for _ = 1, #FP.rows do
    if moved >= (steps or 1) then break end
    local j = i + dir
    while FP.rows[j] ~= nil and FP.rows[j].kind ~= "friend" do j = j + dir end
    if FP.rows[j] == nil then break end
    i, moved = j, moved + 1
  end
  if i ~= FP.sel then
    FP.sel = i
    Snd(FP.SY_MOVE)
    KeepVisible()
  end
end

local function StepOpen()
  FP.frame = FP.frame + 1
  Guard(true)
  local P = FP.P
  if FP.closing then
    FP.anim = FP.anim - 1
    if FP.anim <= 0 then Finish() return end
  elseif FP.anim < P.slide then
    FP.anim = FP.anim + 1
  end
  ArtReady()
  local t = FP.anim / P.slide
  FP.dx = math.floor((1 - t) * (1 - t) * (P.width + P.details_w + 40))
  if FP.co ~= nil then
    local ok, err = coroutine.resume(FP.co)
    if not ok then Log("error", tostring(err)) end
    if not ok or coroutine.status(FP.co) == "dead" then
      FP.co = nil
      KeysReset()
    end
    Draw()
    return
  end
  if FP.frame % FP.REFRESH == 0 and FP.mode == "list" then Load(false) end
  DetailsPoll()
  if FP.closing then Draw() return end
  local K = {}
  for _, k in ipairs({"enter", "back", "l1", "r1", "rclick", "click", "wup", "wdown"}) do K[k] = Pressed(k) end
  K.up, K.down = Pressed("up", true), Pressed("down", true)
  local px, py = M(FP.C.POINTER)
  if FP.mode == "details" then
    local D = FP.det
    if K.back or K.rclick then
      FP.mode, FP.det = "list", nil
      Snd(FP.SY_MOVE)
    elseif D ~= nil and #D.acts > 0 and (K.up or K.down) then
      D.asel = (D.asel - 1 + (K.down and 1 or -1)) % #D.acts + 1
      Snd(FP.SY_MOVE)
    elseif D ~= nil and K.enter and D.acts[D.asel] ~= nil then
      local idx, a, name = D.idx, D.acts[D.asel], (FP.rows[D.i] or {}).name
      Run(function() Act(idx, a, name) end)
    end
  else
    if K.back or K.rclick then
      Close()
    elseif K.up then
      MoveSel(-1)
    elseif K.down then
      MoveSel(1)
    elseif K.l1 or K.wup then
      MoveSel(-1, K.l1 and 8 or 3)
    elseif K.r1 or K.wdown then
      MoveSel(1, K.r1 and 8 or 3)
    elseif K.click and type(px) == "number" then
      local i = Hit(px, py)
      if i ~= nil then
        FP.sel = i
        DetailsOpen(i)
      end
    elseif K.enter and FP.sel ~= nil then
      DetailsOpen(FP.sel)
    elseif type(px) == "number" and M(FP.C.MOVED) == true then
      local i = Hit(px, py)
      if i ~= nil and i ~= FP.sel then FP.sel = i end
    end
  end
  Draw()
end

-- ------------------------------------------------------------------------------------------------ hooks

if UTIL_FP_HOOKED == nil then
  UTIL_FP_HOOKED = true
  local stem = type(EVT_PATCH) == "table" and EVT_PATCH.script or nil
  if type(stem) == "string" then stem = stem:gsub("_%d+%.%d+%.%d+[%.%d]*$", "") end
  local function ours(a1)
    return a1 == FP.L.BACK or a1 == FP.L.PLATE or a1 == FP.L.ICON or a1 == FP.L.FACE or a1 == FP.L.TEXT
  end
  -- 2026-10-12 (Utilities 1.14.5; owner: the dark box at the top-left inside every shop page, the hub frozen after it):
  -- the panel's layers exist in the shop page too (content\menusriends_panel.toml patches shop_menu), but at the
  -- page's OnInit they answer 0 instances, so this VM never took them as its own and never hid them; since 1.14.1
  -- they draw over everything (1001-1005). Now Step is wrapped in every VM once Init runs, and a VM without the layers
  -- at OnInit looks again every 15 frames for 10 s: found = laid out, counted and hidden (and polled as usual).
  local function Here()
    local n = M(FP.C.LAYER_NUM, FP.L.BACK)
    if type(n) == "number" and n > 0 and not FP.here then
      FP.here = true
      Layout()
      Caps()
      pcall(HideAll)
    end
    return FP.here
  end
  local function Init()
    -- (the Battle Bay mode context `battle_bay` is the framework's: game_modes.toml enter_menus / leave_menus)
    if type(stem) == "string" then pcall(funcLuaCommand, FP.CMD.STATUS, stem) end
    FP.probe = 0
    Here()
    if not FP.wrapped then
      -- Step wrapped here (after every patch of the script ran: the outermost wrapper)
      FP.wrapped = true
      local step = Step
      Step = function(...)
        if not FP.here then
          FP.probe = (FP.probe or 0) + 1
          if FP.probe <= 600 and FP.probe % 15 == 1 then pcall(Here) end
          if type(step) == "function" then return step(...) end
          return
        end
        if FP.open then
          local ok, err = pcall(StepOpen)
          if not ok then
            Log("step error", tostring(err))
            pcall(Finish)
          end
        else
          local ok, err = pcall(StepIdle)
          if not ok and FP.idle % 600 == 1 then Log("idle error", tostring(err)) end
        end
        if type(step) == "function" then return step(...) end
      end
    end
  end
  local init = OnInit
  if type(init) == "function" then
    OnInit = function(...)
      local r = table.pack(init(...))
      local ok, err = pcall(Init)
      if not ok then Log("init error", tostring(err)) end
      return table.unpack(r, 1, r.n)
    end
  end
  -- our layers: no retail setup / open code sees them (hidden until the panel draws them)
  local setup = OnSetupLayer
  if type(setup) == "function" then
    OnSetupLayer = function(a1, a2, ...)
      if ours(a1) then
        pcall(funcLuaMenuCommand, FP.C.VISIBLE, a1, a2, false)
        return
      end
      return setup(a1, a2, ...)
    end
  end
  local open = OnOpenLayer
  if type(open) == "function" then
    OnOpenLayer = function(a1, a2, ...)
      if ours(a1) then return end
      return open(a1, a2, ...)
    end
  end
  -- The same hooks as VRFW_Host handlers of this script (as the top bar's, VRFW 2.0.x): a stem patch that redefines
  -- OnInit / OnSetupLayer / OnOpenLayer after lua\_all drops the wrappers above; a host keeps these on top. OnOpenLayer
  -- is hooked even where the script has none (create): an opened instance of ours stays hidden until the panel draws it.
  local VH = VRFW_Host
  if type(stem) == "string" and type(VH) == "table" and type(VH.on) == "function" then
    pcall(VH.on, stem, "OnInit", {id = "utilities.friends_init", phase = "after", fn = function(r, ...)
      local ok, err = pcall(Init)
      if not ok then Log("init error", tostring(err)) end
    end})
    pcall(VH.on, stem, "OnSetupLayer", {id = "utilities.friends_setup", phase = "around", fn = function(nxt, a1, a2, ...)
      if ours(a1) then
        pcall(funcLuaMenuCommand, FP.C.VISIBLE, a1, a2, false)
        return
      end
      return nxt(a1, a2, ...)
    end})
    pcall(VH.on, stem, "OnOpenLayer", {id = "utilities.friends_open", phase = "around", create = true,
      fn = function(nxt, a1, a2, ...)
        if ours(a1) then
          if not (FP.open and FP.shown[a1 .. ":" .. tostring(a2)]) then
            pcall(funcLuaMenuCommand, FP.C.VISIBLE, a1, a2, false)
          end
          return
        end
        if nxt ~= nil then return nxt(a1, a2, ...) end
      end})
  end
end
