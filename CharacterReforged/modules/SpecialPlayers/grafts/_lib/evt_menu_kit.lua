-- Shared helpers of the custom evt_* menus (research/grafts/_lib). Not a script of its own: a snippet line
-- `--@lib evt_menu_kit.lua#Call,Int` is replaced by those sections (graft_lib.expand_lib), in place, so every helper
-- still binds the menu's own upvalues defined above it (C, MENU, KEY_RESULT, L_WIN, evt_co, Log). Menus whose
-- helper differs keep their own version; an indented --@lib line indents the sections. StartCo needs vars = { "@MENU_FILE@" = "<menu file stem>" } on the op.
--@section Call
local function Call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end
--@section Int
local function Int(v)
  if type(v) ~= "number" then
    return 0
  end
  return math.floor(v + 0.5)
end
--@section Pct
local function Pct(n, total)
  if total <= 0 then
    return "0"
  end
  return (string.format("%.1f", n * 100 / total):gsub("%.", ","))
end
--@section WinPrim
local function WinPrim(name, value, visible)
  local prim = funcLuaMenuCommand(C.PRIM_INDEX, L_WIN, 0, name)
  if prim ~= nil then
    funcLuaMenuCommand(C.PRIM_VALUE, L_WIN, 0, prim, value)
  end
  funcLuaMenuCommand(C.PRIM_VISIBLE, L_WIN, 0, name, visible)
end
--@section Hide
local function Hide(layer, idx)
  funcLuaMenuCommand(C.LAYER_VISIBLE, layer, idx, false)
  funcLuaMenuCommand(C.POS, layer, -4000, 4000, 0, idx)
end
--@section Ask
local function Ask(text)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  funcLuaCommand(C.MSG_KIND, 2, 0)
  coroutine.yield()
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
--@section Message
local function Message(text)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  funcLuaCommand(C.MSG_KIND, 1, 0)
  coroutine.yield()
  while funcLuaCommand(C.MSG_BUSY) do
    coroutine.yield()
  end
  while not funcLuaCommand(C.MSG_DONE) do
    coroutine.yield()
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
end
--@section ItemGet
-- the retail «item get» window for a game item (multi_mission_result_menu callGetItemDialog: text sysmes_item_get,
-- kind 11 = the item parameter), the same input pairing as Message (this screen's own MENU only)
local function ItemGet(id)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.MSG_OPEN, 3675423478 --[[sysmes_item_get]], 11, 0, id)
  coroutine.yield()
  while funcLuaCommand(C.MSG_BUSY) do
    coroutine.yield()
  end
  while not funcLuaCommand(C.MSG_DONE) do
    coroutine.yield()
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
end
--@section Close
local function Close(result)
  funcLuaCommand(C.P_CLEAR, KEY_RESULT)
  funcLuaCommand(C.P_SET, KEY_RESULT, 0, result, 1)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.CLOSE_MENU, MENU)
end
--@section StartCo
local function StartCo(fn, arg)
  if evt_co ~= nil then
    return
  end
  evt_co = coroutine.create(fn)
  local ok, err = coroutine.resume(evt_co, arg)
  if not ok then
    PRINT("@MENU_FILE@: " .. tostring(err))
    Log("error", tostring(err))
    evt_co = nil
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  elseif coroutine.status(evt_co) == "dead" then
    evt_co = nil
  end
end
--@section Pack
local function Pack(...)
  return {n = select("#", ...), ...}
end
--@section Cmd
local function Cmd(...)
  if type(funcLuaMenuCommand) ~= "function" then
    return nil
  end
  local r = Pack(pcall(funcLuaMenuCommand, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end
--@section call
local function call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end
--@section EVT_U32
local function EVT_U32(id)
  id = tonumber(id) or 0
  if id < 0 then
    id = id + 4294967296
  end
  return id
end
--@section EvtLog
-- the loader's log command (evt_loader\loader.log) and a pcall'd logger for new code
local CMND_EVT_LOG = 3661580131
local function EvtLog(...)
  pcall(funcLuaCommand, CMND_EVT_LOG, ...)
end
--@section TextGet
-- a menu_text row in the game's language (nil when the command fails or the row is empty)
local CMND_TEXT_GET = 4074371074
local function TextGet(id)
  local ok, s = pcall(funcLuaCommand, CMND_TEXT_GET, id)
  if ok and type(s) == "string" and s ~= "" then
    return s
  end
  return nil
end
--@section EVT_Wrap
-- EVT_Wrap(name, fn): the global function `name` becomes function(...) return fn(prev, ...) end, prev being its value
-- before (one link of a wrapper chain; replaces the `Prev = X; function X(...)` pattern and its extra global)
EVT_Wrap = EVT_Wrap or function(name, fn)
  local prev = _ENV[name]
  _ENV[name] = function(...)
    return fn(prev, ...)
  end
end
--@section Pointer
-- EVT_PointerNew(): a pointer helper for menus that draw their own selectable items (docs/game/ui/mouse-support.md §5).
-- Mouse and VR's free cursor (the stick-driven «virtual mouse», CMND_SET_ENABLE_FREE_CURSOR_FOR_VIRTUAL_MOUSE) are
-- the same pointer: the engine's pointer position (558229292, screen px, y down) is read every frame and any change
-- (or the engine's «mouse moved», 3272825600) puts the menu in pointer mode; a menu arrow (CMD_UP/DOWN/LEFT/RIGHT)
-- ends it. The menu declares its zones each time it draws, from the same positions it draws with:
--   P.Begin()                              forget the zones of the last drawing
--   P.Rect(x, y, w, h, id[, edge])         top-left + size, screen px (y down)
--   P.Box(cx, cy, hw, hh, id[, edge])      centre + half sizes, screen px (y down)
--   P.Inst(layer, idx, hw, hh, id[, edge]) around a layer instance's global position (read at hit-test time)
--   (edge = -1 / 1: a scroll band; hovering it scrolls every P.REPEAT frames: ev.edge)
-- The last zone declared wins (popups / buttons drawn over cards). Per frame (Step): local ev = P.Poll() with
--   ev.moved   the pointer moved (pointer mode on)          ev.hot / ev.changed  zone id under the pointer / it changed
--   ev.click   id clicked (mouse left button, or Accept / the free cursor's A in pointer mode) on a zone
--   ev.miss    a mouse click on no zone (do nothing; Enter / A there = the menu's key Accept, pointer mode off)
--   ev.wheel   -1 up / 1 down (CMD_EVT_WHEEL_*)
--   ev.edge    -1 / 1 from a scroll band                     ev.keys   a menu arrow was pressed (pointer mode off)
--   ev.hover   the zone under the pointer, only on a frame the pointer MOVED (or was clicked): hover by movement only,
--              so a redraw / scroll / camera move under a resting pointer never re-selects (retail behaviour)
-- P.KeyStep(): the menu moved its selection itself (its own key callbacks, a polled stick / D-pad the arrows above do
-- not see): pointer mode off and the resting position taken as the baseline, so the pad owns the selection until the
-- pointer really moves again or clicks (a resting mouse would otherwise pin the selection under it).
-- Hover = move the selection to ev.hot with the keyboard highlight; ev.click = select it and decide. The menu's own
-- Accept callbacks (OnEnter / OnDecideFocus / a polled CMD_ENTER) return early while P.Owns(): in pointer mode the
-- click belongs to the pointer, so an item not under it is never activated. Zones are only declared for pickable,
-- shown items (never hidden ones). P.Forget() after a redraw under a still pointer re-focuses the zone beneath it.
EVT_PointerNew = EVT_PointerNew or function()
  local P = {zones = {}, on = false, x = nil, y = nil, hot = nil, prev = {}, edge_t = 0, REPEAT = 10}
  local MOVED, POS, GPOS, CHECK, CTRL = 3272825600, 558229292, 4002164178, 4265778440, 1332654303
  local LEFT, CLICK = 218912913 --[[CMD_EVT_MOUSE_LEFT]], 1651523701 --[[CMD_ENTER_CLICK]]
  local W_UP, W_DOWN = 1942756954 --[[CMD_EVT_WHEEL_UP]], 1623431741 --[[CMD_EVT_WHEEL_DOWN]]
  local NAV = {1197218715, 3259546669, 2765147006, 2075023265} -- CMD_UP / DOWN / LEFT / RIGHT
  local CTRLS = {CTRL, 2748927068 --[[analog-move control: the stick's menu moves]]}
  local function M(cmd, ...)
    local ok, a, b = pcall(funcLuaMenuCommand, cmd, ...)
    if ok then return a, b end
    return nil
  end
  local function In(cmd, ctrl)
    local ok, r = pcall(funcLuaCommand, CHECK, ctrl or CTRL, cmd)
    return ok and r == true
  end
  local function Edge(cmd, ctrl)
    local key = ctrl and (tostring(ctrl) .. ":" .. tostring(cmd)) or cmd
    local now = In(cmd, ctrl)
    local was = P.prev[key]
    P.prev[key] = now
    return now and not was
  end
  function P.Begin()
    P.zones = {}
  end
  function P.Rect(x, y, w, h, id, edge)
    P.zones[#P.zones + 1] = {x, y, x + w, y + h, id = id, edge = edge}
  end
  function P.Box(cx, cy, hw, hh, id, edge)
    P.zones[#P.zones + 1] = {cx - hw, cy - hh, cx + hw, cy + hh, id = id, edge = edge}
  end
  function P.Inst(layer, idx, hw, hh, id, edge)
    P.zones[#P.zones + 1] = {layer = layer, idx = idx, hw = hw, hh = hh, id = id, edge = edge}
  end
  function P.Pos()
    local x, y = M(POS)
    if type(x) == "number" and type(y) == "number" then return x, y end
    return nil
  end
  function P.At(x, y)
    if x == nil then x, y = P.x, P.y end
    if x == nil then return nil end
    for i = #P.zones, 1, -1 do
      local z = P.zones[i]
      if z.layer ~= nil then
        local gx, gy = M(GPOS, z.layer, z.idx)
        if type(gx) == "number" and type(gy) == "number" and math.abs(x - gx) <= z.hw and math.abs(-y - gy) <= z.hh then
          return z
        end
      elseif x >= z[1] and x < z[3] and y >= z[2] and y < z[4] then
        return z
      end
    end
    return nil
  end
  -- the Accept being pressed now is a pointer click: the mouse button, or Accept / A in pointer mode ON an item
  -- (Enter / A with the pointer resting on empty space is a key Accept on the current selection)
  function P.Owns()
    return In(LEFT) or (P.on and In(CLICK) and P.At() ~= nil)
  end
  -- forget the hovered zone: the next Poll reports the zone under a still pointer as changed (after a redraw)
  function P.Forget()
    P.hot = nil
  end
  function P.KeyStep()
    P.on, P.hot = false, nil
    local x, y = P.Pos()
    if x ~= nil then P.x, P.y = x, y end
  end
  function P.Reset()
    P.zones, P.on, P.hot, P.prev, P.edge_t = {}, false, nil, {}, 0
    P.x, P.y = P.Pos()
    -- a press / wheel / arrow held from the screen before is no click, no scroll, no key
    for _, c in ipairs({LEFT, CLICK, W_UP, W_DOWN}) do Edge(c) end
    for _, ctrl in ipairs(CTRLS) do
      for _, c in ipairs(NAV) do Edge(c, ctrl) end
    end
  end
  function P.Poll()
    local ev = {}
    local x, y = P.Pos()
    if x ~= nil then
      local moved = M(MOVED) == true
      if not moved and P.x ~= nil and (math.abs(x - P.x) > 1 or math.abs(y - P.y) > 1) then
        moved = true    -- the free cursor (stick) moves the pointer without the mouse's «moved» flag
      end
      P.x, P.y = x, y
      if moved then
        P.on, ev.moved = true, true
      end
    end
    for _, ctrl in ipairs(CTRLS) do
      for _, c in ipairs(NAV) do
        if Edge(c, ctrl) then
          ev.keys = true
        end
      end
    end
    if ev.keys and not ev.moved then
      P.on = false
    end
    local left, click = Edge(LEFT), Edge(CLICK)
    if left then
      P.on = true
    end
    local z = P.on and P.At() or nil
    local id = z and z.id or nil
    ev.changed = id ~= P.hot
    P.hot, ev.hot = id, id
    if z ~= nil and (ev.moved or left) then
      ev.hover = id
    end
    if left then
      if z ~= nil then
        ev.click = id
      else
        ev.miss = true                 -- a mouse click on empty space: nothing
      end
    elseif click and P.on then
      if z ~= nil then
        ev.click = id
      else
        P.on, P.hot = false, nil       -- Enter / A on empty space: the menu's key Accept takes it (selection kept)
      end
    end
    if In(W_DOWN) then
      ev.wheel = 1
    elseif In(W_UP) then
      ev.wheel = -1
    end
    if z ~= nil and z.edge ~= nil then
      P.edge_t = P.edge_t - 1
      if P.edge_t <= 0 then
        ev.edge, P.edge_t = z.edge, P.REPEAT
      end
    else
      P.edge_t = 0
    end
    return ev
  end
  return P
end
--@section CharaModel
-- EVT_CharaModelNew(layer[, opts]): a player's 3D model in a menu, the retail shop's way (docs/framework/contact-map.md
-- §8; the Oficina de fichajes, office_look ofl_buy_1.lua B/F/G, does the same on shop01_01_list_base). `layer` = a layer
-- whose object carries a CMenuCharaModelComponent (retail shop01_01_list_base, or an object derived from it); model
-- slot 0. Flicker-free and never in T-pose: one build per player, a new build only once the last one is complete, the
-- model hidden until the component says it is complete (1583438030) for `settle` frames.
--   M.Show(pid)   the model of chara_param `pid` (built once; the same player again = just shown)
--   M.Hide()      hidden (a build under way stays hidden when it completes)
--   M.Step()      every frame (Step)
--   M.Release()   the model released (a list that changes its players frees the old ones)
--   M.Ok()        false when the layer has no model component (nothing was ever built): draw something else
-- opts: shadow = the 3D shadow layer (retail mainmenu01_08_chara_3d_shadow), pose (retail shop 2328706751), uniform (0 =
-- his own), look (look flags, 0), settle (2), min (6), max (120), log = function(...) for the first lines,
-- kit = function(pid) -> uniform, flags: the kit of that player (uniform 0 = `uniform`; flags 2 = the keeper shirt),
-- asked once per build (the contact map: his own team's kit, CMND_VRFW_CONTACT_KIT),
-- slot = the component's model slot (0; a component with m_useObjectNum > 1 holds one model per slot, as the retail
-- shop's 4 and the Victory Road top's 11), key = that slot's model key (the slot number, as retail),
-- bodies = {[body type] = true} the body types the pose has (menu_chara_model_pose_config; the framework's
-- CMND_VRFW_MODEL_POSE_BODIES). CRASH GUARD (nie.exe+0x1114F94 reads 0x4C): the pose command
-- (2450020144) looks the pose up for the chara's body type (CMND_GET_CHARA_INFO(chara, 3)) and dereferences the result
-- unchecked: a body type the pose does not list kills the game. Such a player gets no model (log «skip body»); with no
-- `bodies` the pose command is never sent.
EVT_CharaModelNew = EVT_CharaModelNew or function(layer, opts)
  opts = opts or {}
  local M = {pid = nil, chara = nil, pend = nil, build = nil, hide_build = false, logs = 0, failed = false,
    SHADOW = opts.shadow or 858725131 --[[mainmenu01_08_chara_3d_shadow]], POSE = opts.pose or 2328706751,
    SETTLE = opts.settle or 2, MIN = opts.min or 6, MAX = opts.max or 120, SLOT = opts.slot or 0}
  M.KEY = opts.key or M.SLOT
  local function MC(cmd, ...)
    local ok, a, b = pcall(funcLuaMenuCommand, cmd, ...)
    if ok then return a, b end
    return nil
  end
  local function Log(...)
    if opts.log ~= nil and M.logs < 12 then
      M.logs = M.logs + 1
      pcall(opts.log, "model", ...)
    end
  end
  local function Visible(on)
    local h = MC(3895705890, layer, 0, M.SLOT)
    if type(h) == "number" and h ~= 0 then
      pcall(funcLuaCommand, 1890282463, h, on)
    end
  end
  local function Ready()
    return MC(1583438030, layer, 0, M.SLOT) == true
  end
  local function Loading(chara)
    local ok, l = pcall(funcLuaCommand, 2475005551, chara)
    return ok and l == true
  end
  local function BuildDone()
    return M.build == nil or M.build.done
  end
  -- retail shop_menu_buy SetupCharaModel(0, chara, uniform, motion, look, pose, 0, false)
  -- the chara's body type (retail SetupCharaModel: CMND_GET_CHARA_INFO(chara, 3)); 0 when the game has none
  local function BodyType(chara)
    local ok, has, v = pcall(funcLuaCommand, 4060384944 --[[CMND_GET_CHARA_INFO]], chara, 3, 0)
    if ok and has == true and type(v) == "number" then
      return v
    end
    return 0
  end
  local function Setup(chara, pid, motion, n, uniform, flags)
    MC(59611540, layer, 0, chara, M.SLOT)
    MC(186863317 --[[CMND_SET_SCN_CHARA_REGIST_TYPE]], layer, 0, 4, M.SLOT)
    MC(3290636356, layer, 0, uniform, motion, flags, M.SLOT)
    MC(4219344099 --[[CMND_SET_CHARA_MODEL_SHADOW?]], layer, 0, M.SHADOW, M.SLOT, M.SLOT)
    MC(2232914067 --[[CMND_CHARA_MODEL_CHANGE]], layer, 0, 0, 9, M.SLOT, M.KEY)
    if opts.bodies ~= nil and opts.bodies[n] then   -- only a body type the pose lists (see CRASH GUARD above)
      MC(2450020144, layer, 0, M.POSE, n, M.SLOT)
    end
  end
  local function BuildStep()
    local B = M.build
    if B == nil or B.done then
      return
    end
    B.n = B.n + 1
    if not Ready() then
      B.seen, B.ok = true, 0
    elseif B.seen or B.n >= M.MIN then
      B.ok = B.ok + 1
    end
    if B.ok >= M.SETTLE or B.n >= M.MAX then
      B.done = true
      if not B.seen and B.ok < M.SETTLE then
        M.failed = true
      end
      Log("ready", B.n, tostring(B.seen), tostring(B.ok >= M.SETTLE))
    end
  end
  local function PendStep()
    local P = M.pend
    if P == nil then
      if M.hide_build then
        Visible(false)
        M.hide_build = not BuildDone()
      end
      return
    end
    M.hide_build = false
    P.n = P.n + 1
    if not P.built then
      if P.n < M.MAX and (not BuildDone() or Loading(P.chara)) then
        Visible(false)
        return
      end
      local ok, err = pcall(Setup, P.chara, P.pid, P.motion, P.body, P.uniform, P.flags)
      Visible(false)
      P.built, P.n = true, 0
      M.build = {n = 0, seen = false, ok = 0, done = false}
      M.pid, M.chara = P.pid, P.chara
      Log("build", P.pid, P.chara, P.motion, string.format("uniform 0x%08X flags %d", P.uniform, P.flags), tostring(ok),
        tostring(err))
      return
    end
    if not BuildDone() then
      Visible(false)
      return
    end
    Visible(true)
    M.pend = nil
    Log("shown", P.pid, P.n)
  end
  function M.Ok()
    return not M.failed
  end
  function M.Hide()
    M.pend = nil
    M.hide_build = not BuildDone()
    if M.pid ~= nil then
      Visible(false)
    end
  end
  -- the slot's model released (retail shop ResetCharaModel): nothing shown, its resources freed
  function M.Release()
    M.pend, M.hide_build = nil, false
    if M.pid ~= nil then
      Visible(false)
      MC(59611540, layer, 0, 0, M.SLOT)
      MC(2232914067 --[[CMND_CHARA_MODEL_CHANGE]], layer, 0, 0, 9, M.SLOT)
    end
    M.pid, M.chara, M.build = nil, nil, nil
  end
  function M.Show(pid)
    local P = M.pend
    if P ~= nil and P.pid == pid then
      return
    end
    if P == nil and M.pid == pid then
      if BuildDone() then
        Visible(true)
      else
        M.pend = {pid = pid, chara = M.chara, n = 0, built = true}
      end
      return
    end
    local ok, chara = pcall(funcLuaCommand, 347353059 --[[chara of chara_param]], pid)
    if not ok or type(chara) ~= "number" or chara == 0 then
      Log("none", pid)
      M.Hide()
      return
    end
    local motion = 1
    local ok2, has, v = pcall(funcLuaCommand, 4060384944 --[[CMND_GET_CHARA_INFO]], pid, 21)
    if ok2 and has == true and type(v) == "number" and v ~= 0 then
      motion = v
    end
    local body = BodyType(chara)
    if opts.bodies == nil or not opts.bodies[body] then
      Log("skip body", pid, chara, body, tostring(opts.bodies ~= nil))
      M.Hide()
      return
    end
    -- the kit: the caller's per player (opts.kit), else opts.uniform / opts.look
    local uniform, flags = opts.uniform or 0, opts.look or 0
    if opts.kit ~= nil then
      local okk, u, f = pcall(opts.kit, pid)
      if okk and type(u) == "number" and u ~= 0 then
        uniform = u
      end
      -- the look bits the caller asks (2 the keeper shirt, 16 a coach's, 32 a manager's own clothes; as the retail
      -- team dock's model flags) added to the screen's own
      if okk and type(f) == "number" then
        for _, bit in ipairs({2, 16, 32}) do
          if math.floor(f / bit) % 2 == 1 and math.floor(flags / bit) % 2 == 0 then
            flags = flags + bit
          end
        end
      end
    end
    Visible(false)
    M.pend = {pid = pid, chara = chara, motion = motion, body = body, uniform = uniform, flags = flags, n = 0,
      built = false}
    PendStep()
  end
  function M.Step()
    BuildStep()
    PendStep()
  end
  return M
end
