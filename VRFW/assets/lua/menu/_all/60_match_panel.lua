-- menu_engine: the in-match settings window (docs/framework/match-panel.md). A game-style list window a mod opens over
-- a match (or any menu): a title bar, rows «label      ‹ value ›», a highlighted row, a line of button hints. The
-- framework draws it and reads the input; the mod gives the rows and decides what a row does. Runs in every script VM
-- (lua\_all) but only defines the table VRFW_MatchPanel: nothing happens until a mod's Lua calls
-- VRFW_MatchPanel.open(spec) from a callback of a menu that has the panel's two layers (a mod adds them with [[patch]]
-- add_layer, objects of the framework's content\menus\match_panel.toml), then VRFW_MatchPanel.step() every frame of
-- that menu.
--
-- Look (VRFW 2.2.34, owner 2026-10-12: «in the game's style»): the retail options screen's own sprites
-- (108_option: option01_23 the slanted list cells, their cyan focus frame and the arrow buttons; option01_02 the blue
-- title bar), so the window looks like the game's options list. A mod may pass its own sprites (`style`, below).
-- Values are drawn next to two arrow sprites, never with «<» «>» characters: the game's text markup reads those as a
-- tag and the value vanished (training field, 2026-10-12).
--
-- Layers (added by the host mod, never a retail object swapped):
--   vrfw_mp_plate  cmn01_10_new_icon quads re-skinned with the style's sprites, drawn in instance order: 0, 1 the
--                  window (twice: the retail cell is a 30 % black, too light over a running HUD), 2 .. ROWS_MAX + 1 the
--                  row cells, then the title bar, the hint strip, the focus fill, the focus frame and the two arrows
--                  (PLATES = ROWS_MAX + 8 = 28 instances)
--   vrfw_mp_label  the retail corner button's text node (cmn03_01_cmd_back, its plates hidden): 0 the title, 1 .. 4
--                  the hint segments, then two per row (label, value): LABELS = 5 + 2 x ROWS_MAX = 45 instances
-- Input: no menu controller is active over a paused match, so the window reads the game pad and the keyboard itself
-- (CMND_VRFW_INPUT_PAD / CMND_VRFW_INPUT_KEY): D-pad / arrows UP DOWN = row, LEFT RIGHT = change the value (held:
-- repeat), A / Enter = the row's action (a toggle flips, a list steps right), B / Esc / BACK (Select) = close.
-- Pause: `pause = true` holds the game's own pause while the window is open (CMND_VRFW_GAME_PAUSE), the previous state
-- back at close.
--
-- spec = {
--   id = "<mod>.<name>",                       -- log name
--   title = "text",                            -- shown on the title bar (already in the game's language)
--   hint = "text" | { "text", … },             -- the button hints under the rows (up to 4 segments, spread)
--   rows = function() return { { label = "text", value = "text", disabled = false, cycle = true }, … } end,
--   change = function(i, dir) end,             -- row i (1-based) LEFT (-1) / RIGHT (+1)
--   decide = function(i) end,                  -- row i A / Enter (default: change(i, 1))
--   closed = function(why) end,                -- "back" | "closed" | "error" | the mod's reason
--   style = { <part> = { "#/menu/…g4tx", "<sprite>" }, … },   -- parts: panel, row, title, hint, focus, frame,
--                                              -- arrow_l, arrow_r (a part left out: the retail default below); the
--                                              -- 2.0.106 form { atlas, back, hover } still works (back = row, hover = focus)
--   pause = true,
--   width = 1040, row_h = 46, top = nil,       -- screen px (1920 x 1080); top nil = centred
-- }
-- A row: `cycle ~= false`, not disabled and with a value = the focused row shows the two arrows around its value;
-- `value` nil = a label only (an action). Engine calls only from OnInit / Step / layer callbacks (nothing at chunk load).
if VRFW_MatchPanel == nil then
  local MP = {
    ROWS_MAX = 20, HINTS_MAX = 4, REPEAT_WAIT = 18, REPEAT_EVERY = 5, OPEN_GUARD = 8, TEX_MAX = 300,
    LABEL_LEFT = -384, LABEL_MID_Y = 144,    -- the corner button's text node in its object (px)
    SCALE_ROW = 0.8, SCALE_TITLE = 0.9, SCALE_HINT = 0.7,
    TITLE_H = 64, HINT_H = 46, GAP = 12,
    open_now = false, spec = nil, sel = 1, rows = {}, prev = 0, prev_keys = {}, hold = 0, hold_dir = nil,
    guard = 0, paused_before = nil, tex = {}, tex_ok = false, tex_t = 0, logn = 0, drawn = false,
  }
  VRFW_MatchPanel = MP

  -- the retail options screen's sprites (data\dx11\menu\108_option): the default look
  local ATL_CELL = "#/menu/108_option/option01/option01_23/option01_23.g4tx"
  local ATL_LIST = "#/menu/108_option/option01/option01_02/option01_02.g4tx"
  MP.ATLASES = {ATL_CELL, ATL_LIST}
  MP.DEFAULT_STYLE = {
    panel = {ATL_CELL, "cel_base01_gray01"},       -- black 30 %, slanted: the window behind the rows
    row = {ATL_CELL, "cel_base01_gray01"},         -- a list cell
    title = {ATL_LIST, "option_list_base02_on"},   -- the blue bar of a focused options row
    hint = {ATL_CELL, "cel_base01_gray01"},
    focus = {ATL_CELL, "cel_base01_on"},           -- the cyan-blue fill of the focused cell
    frame = {ATL_CELL, "cel_focus01"},             -- its cyan frame
    arrow_l = {ATL_CELL, "btn_arrow_l01"},
    arrow_r = {ATL_CELL, "btn_arrow_r01"},
  }
  local PARTS = {"panel", "row", "title", "hint", "focus", "frame", "arrow_l", "arrow_r"}

  local L_PLATE = 837372328 --[[vrfw_mp_plate]]
  local L_LABEL = 1322307099 --[[vrfw_mp_label]]
  local NODE_QUAD = 1909474081         -- icon_new01 (the cmn01_10 quad's sprite node)
  local Q = 36                         -- cmn01_10 quad size
  local TEXT_NODE = 378327766          -- _text_cmd_back01
  local TEXT_MESHES = {298211823 --[[_cmd_back_base01]], 2853207670 --[[_cmd_back_base01_add]]}
  -- plate instances (drawn in this order: later ones over earlier ones)
  local P_PANEL = 0                     -- and P_PANEL + 1
  local P_ROW0 = 2                      -- rows 1 .. ROWS_MAX
  local P_TITLE = MP.ROWS_MAX + 2
  local P_HINT = MP.ROWS_MAX + 3
  local P_FOCUS = MP.ROWS_MAX + 4
  local P_FRAME = MP.ROWS_MAX + 5
  local P_ARROW_L = MP.ROWS_MAX + 6
  local P_ARROW_R = MP.ROWS_MAX + 7
  MP.PLATES = MP.ROWS_MAX + 8
  -- label instances
  local T_TITLE = 0
  local T_HINT0 = 1
  local T_ROW0 = 1 + MP.HINTS_MAX       -- row k: label T_ROW0 + 2 (k - 1), value + 1
  MP.LABELS = T_ROW0 + 2 * MP.ROWS_MAX
  local C = {
    LOG = 3661580131, LAYER_NUM = 1175615627, VISIBLE = 711242136, SCALE = 3778714801, POS = 1389957207,
    SPRITE = 558735651, MESH_VISIBLE = 3405944500, TEXT = 1083631230, LOAD_TEX = 839427544, TEX_LOADING = 1506186496,
    PAD = 2864033604 --[[CMND_VRFW_INPUT_PAD]], KEY = 3182184968 --[[CMND_VRFW_INPUT_KEY]],
    PAUSE = 4196529456 --[[CMND_VRFW_GAME_PAUSE]],
    SE = 1917805374, SE_MOVE = 3848881948, SE_GO = 766561556 --[[sy0080]], SE_BACK = 202039849 --[[sy0006]],
    SE_NO = 2086672038 --[[sy0003]],
  }
  -- the game pad (Steam / PS layout masks of vr_sigs::input) and the Windows virtual keys
  local PAD = {BACK = 0x1, UP = 0x10, RIGHT = 0x20, DOWN = 0x40, LEFT = 0x80, B = 0x2000, A = 0x4000}
  local VK = {UP = 0x26, DOWN = 0x28, LEFT = 0x25, RIGHT = 0x27, ENTER = 0x0D, ESC = 0x1B, BACKSPACE = 0x08}

  local function Log(...)
    if MP.logn >= 80 then return end
    MP.logn = MP.logn + 1
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    pcall(funcLuaCommand, C.LOG, "VRFW match_panel " .. tostring(MP.spec and MP.spec.id) .. " " .. table.concat(p, " "))
  end

  local function M(...)
    local r = table.pack(pcall(funcLuaMenuCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end

  local function Se(id) pcall(funcLuaCommand, C.SE, id) end

  local function Count(layer)
    local n = M(C.LAYER_NUM, layer)
    return type(n) == "number" and n or 0
  end

  -- the style of a spec: every part { atlas, sprite } (the retail default for a part the mod left out)
  local function Resolve(st)
    local out = {}
    st = type(st) == "table" and st or {}
    local legacy = {}
    if type(st.atlas) == "string" and st.atlas ~= "" then
      if type(st.back) == "string" then legacy.row = {st.atlas, st.back} end
      if type(st.hover) == "string" then legacy.focus = {st.atlas, st.hover} end
    end
    for _, k in ipairs(PARTS) do
      local v = st[k]
      if type(v) == "table" and type(v[1]) == "string" and type(v[2]) == "string" then
        out[k] = {v[1], v[2]}
      else
        out[k] = legacy[k] or MP.DEFAULT_STYLE[k]
      end
    end
    return out
  end

  local function HideQuad(idx)
    M(C.VISIBLE, L_PLATE, idx, false)
    M(C.POS, L_PLATE, -4000, 4000, 0, idx)
  end

  -- a quad of `part` centred at (x, y), w x h screen px (hidden until the style's atlases are loaded: a quad without
  -- its sprite would show the retail red «new» badge stretched)
  local function Quad(idx, part, x, y, w, h)
    local sp = part and MP.style and MP.style[part]
    if sp == nil or not MP.tex_ok then return HideQuad(idx) end
    M(C.VISIBLE, L_PLATE, idx, true)
    M(C.SCALE, L_PLATE, w / Q, h / Q, 1, idx)
    M(C.SPRITE, L_PLATE, CRC32(sp[1]), CRC32(sp[2]), NODE_QUAD, 0, idx)
    M(C.POS, L_PLATE, x, -y, 0, idx)
  end

  -- a text at (x = its left edge, y = its centre line), or hidden
  local function Text(idx, s, x, y, scale)
    if idx >= Count(L_LABEL) then return end
    if type(s) ~= "string" or s == "" then
      M(C.VISIBLE, L_LABEL, idx, false)
      M(C.POS, L_LABEL, -4000, 4000, 0, idx)
      return
    end
    scale = scale or MP.SCALE_ROW
    for _, m in ipairs(TEXT_MESHES) do M(C.MESH_VISIBLE, L_LABEL, m, false, idx) end
    M(C.TEXT, L_LABEL, TEXT_NODE, s, idx)
    M(C.SCALE, L_LABEL, scale, scale, 1, idx)
    M(C.POS, L_LABEL, x - MP.LABEL_LEFT * scale, -y - MP.LABEL_MID_Y * scale, 0, idx)
    M(C.VISIBLE, L_LABEL, idx, true)
  end

  local function HideAll()
    for i = 0, Count(L_PLATE) - 1 do HideQuad(i) end
    for i = 0, Count(L_LABEL) - 1 do
      M(C.VISIBLE, L_LABEL, i, false)
      M(C.POS, L_LABEL, -4000, 4000, 0, i)
    end
    MP.drawn = false
  end

  local function ReadRows()
    local ok, rows = pcall(MP.spec.rows)
    if not ok or type(rows) ~= "table" then
      Log("rows error", tostring(rows))
      return {}
    end
    local out = {}
    for i = 1, math.min(#rows, MP.ROWS_MAX) do out[i] = rows[i] end
    return out
  end

  local function Hints()
    local h = MP.spec.hint
    if type(h) == "string" then return {h} end
    if type(h) ~= "table" then return {} end
    local out = {}
    for i = 1, math.min(#h, MP.HINTS_MAX) do
      if type(h[i]) == "string" and h[i] ~= "" then out[#out + 1] = h[i] end
    end
    return out
  end

  -- the window's frame: left, top, width, height, row height, the rows' top
  local function Geometry()
    local s = MP.spec
    local n = #MP.rows
    local w, rh = s.width or 1040, s.row_h or 46
    local h = MP.TITLE_H + MP.GAP + rh * n + MP.GAP + MP.HINT_H + 10
    local left = (1920 - w) / 2
    local top = s.top or (1080 - h) / 2
    return left, top, w, h, rh, top + MP.TITLE_H + MP.GAP
  end
  MP.geometry = Geometry

  local function Draw()
    if not MP.open_now then return end
    local left, top, w, h, rh, rtop = Geometry()
    local n = #MP.rows
    local cx = left + w / 2
    local function rowy(k) return rtop + rh * (k - 0.5) end
    -- the window, the cells, the title bar, the hint strip
    Quad(P_PANEL, "panel", cx, top + h / 2, w + 24, h + 20)
    Quad(P_PANEL + 1, "panel", cx, top + h / 2, w + 24, h + 20)
    for k = 1, MP.ROWS_MAX do
      if k <= n then Quad(P_ROW0 + k - 1, "row", cx, rowy(k), w - 32, rh - 6) else HideQuad(P_ROW0 + k - 1) end
    end
    Quad(P_TITLE, "title", cx, top + MP.TITLE_H / 2, w, MP.TITLE_H - 6)
    local hy = rtop + rh * n + MP.GAP + MP.HINT_H / 2
    Quad(P_HINT, "hint", cx, hy, w - 32, MP.HINT_H - 6)
    -- the focused row: fill + frame; its arrows when its value cycles
    local r = MP.rows[MP.sel]
    local vx = left + math.floor(w * 0.56)            -- the value column (the left arrow's centre)
    local rx = left + w - 52                          -- the right arrow's centre
    if r ~= nil then
      Quad(P_FOCUS, "focus", cx, rowy(MP.sel), w - 32, rh - 6)
      Quad(P_FRAME, "frame", cx, rowy(MP.sel), w - 24, rh + 2)
    else
      HideQuad(P_FOCUS)
      HideQuad(P_FRAME)
    end
    local arrows = r ~= nil and r.value ~= nil and r.value ~= "" and not r.disabled and r.cycle ~= false
    if arrows then
      local ah = rh - 12
      Quad(P_ARROW_L, "arrow_l", vx, rowy(MP.sel), ah * 40 / 48, ah)
      Quad(P_ARROW_R, "arrow_r", rx, rowy(MP.sel), ah * 40 / 48, ah)
    else
      HideQuad(P_ARROW_L)
      HideQuad(P_ARROW_R)
    end
    -- the texts
    Text(T_TITLE, MP.spec.title, left + 40, top + MP.TITLE_H / 2, MP.SCALE_TITLE)
    local hs = Hints()
    for i = 1, MP.HINTS_MAX do
      local x = left + 40 + (i - 1) * (w - 80) / math.max(1, #hs)
      Text(T_HINT0 + i - 1, hs[i], x, hy, MP.SCALE_HINT)
    end
    for k = 1, MP.ROWS_MAX do
      local row = MP.rows[k]
      local li = T_ROW0 + 2 * (k - 1)
      if row ~= nil then
        Text(li, tostring(row.label or ""), left + 40, rowy(k))
        -- every value starts where the left arrow ends: the column does not jump with the focus
        local v = row.value
        Text(li + 1, v ~= nil and tostring(v) or nil, vx + 30, rowy(k))
      else
        Text(li, nil)
        Text(li + 1, nil)
      end
    end
    MP.drawn = true
  end

  local function Refresh()
    MP.rows = ReadRows()
    if MP.sel > #MP.rows then MP.sel = math.max(1, #MP.rows) end
    Draw()
  end

  local function Pause(on)
    if not MP.spec.pause then return end
    if on then
      local ok, okc, now = pcall(funcLuaCommand, C.PAUSE)
      MP.paused_before = (ok and okc == true) and (now == 1) or nil
      pcall(funcLuaCommand, C.PAUSE, 1)
    elseif MP.paused_before ~= true then
      pcall(funcLuaCommand, C.PAUSE, 0)
    end
  end

  -- the pad's held mask (-1 = not resolved) and the keys, as one set of «buttons» this frame
  local function Buttons()
    local ok, held = pcall(funcLuaCommand, C.PAD)
    held = (ok and type(held) == "number" and held >= 0) and held or 0
    local b = {}
    local function pad(m) return math.floor(held / m) % 2 == 1 end
    local function key(vk)
      local okk, v = pcall(funcLuaCommand, C.KEY, vk)
      return okk and v == true
    end
    b.up = pad(PAD.UP) or key(VK.UP)
    b.down = pad(PAD.DOWN) or key(VK.DOWN)
    b.left = pad(PAD.LEFT) or key(VK.LEFT)
    b.right = pad(PAD.RIGHT) or key(VK.RIGHT)
    b.ok = pad(PAD.A) or key(VK.ENTER)
    b.back = pad(PAD.B) or pad(PAD.BACK) or key(VK.ESC) or key(VK.BACKSPACE)
    return b
  end

  local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then Log("callback error", tostring(err)) end
  end

  -- public -----------------------------------------------------------------------------------------------------------

  function MP.is_open() return MP.open_now end

  -- the two layers open with their menu's group: the host hides their instances once when the menu opens (the quads
  -- would show the retail «new» icon, the texts the corner button)
  function MP.hide()
    if not MP.open_now then HideAll() end
  end

  -- the host menu has the two layers (a mod's [[patch]] add_layer) with enough instances
  function MP.available()
    return Count(L_PLATE) >= MP.PLATES and Count(L_LABEL) >= MP.LABELS
  end

  function MP.open(spec)
    if MP.open_now then return false end
    if type(spec) ~= "table" or type(spec.rows) ~= "function" then return false end
    MP.spec = spec
    if not MP.available() then
      Log("refused: the host menu needs the layers vrfw_mp_plate x" .. MP.PLATES .. " / vrfw_mp_label x" .. MP.LABELS ..
        " (has " .. Count(L_PLATE) .. " / " .. Count(L_LABEL) .. ")")
      MP.spec = nil
      return false
    end
    MP.open_now, MP.sel, MP.guard, MP.hold, MP.hold_dir = true, 1, MP.OPEN_GUARD, 0, nil
    MP.prev_keys = {up = true, down = true, left = true, right = true, ok = true, back = true}  -- edges after release
    MP.style = Resolve(spec.style)
    MP.tex, MP.tex_ok, MP.tex_t = {}, false, 0
    for _, k in ipairs(PARTS) do
      local a = MP.style[k][1]
      if MP.tex[a] == nil then
        M(C.LOAD_TEX, a)
        MP.tex[a] = CRC32(a)
      end
    end
    Pause(true)
    Refresh()
    Se(C.SE_GO)
    Log("open", #MP.rows, "rows")
    return true
  end

  function MP.close(why)
    if not MP.open_now then return end
    MP.open_now, MP.suspended = false, nil
    HideAll()
    Pause(false)
    Log("close", why or "closed")
    local s = MP.spec
    MP.spec = nil
    if s ~= nil then Call(s.closed, why or "closed") end
  end

  -- another window over this one (a mod's picker, e.g. VRFW_EmblemGrid with input = "pad"): the window is hidden
  -- and its input stops, the pause stays; `title` (optional) stays shown on top. suspend(false) draws it again.
  function MP.suspend(on, title)
    if not MP.open_now then return end
    MP.suspended = on and true or nil
    if on then
      HideAll()
      if type(title) == "string" and title ~= "" then Text(T_TITLE, title, 120, 90, MP.SCALE_TITLE) end
    else
      MP.guard, MP.hold, MP.hold_dir = MP.OPEN_GUARD, 0, nil
      MP.prev_keys = {up = true, down = true, left = true, right = true, ok = true, back = true}
      Refresh()
    end
  end

  -- the rows changed outside (a mod's own state): read and draw them again
  function MP.refresh()
    if MP.open_now then Refresh() end
  end

  function MP.step()
    if not MP.open_now or MP.suspended then return end
    if not MP.tex_ok then
      MP.tex_t = MP.tex_t + 1
      local busy = false
      for _, t in pairs(MP.tex) do
        local ok, b = pcall(funcLuaCommand, C.TEX_LOADING, t)
        if ok and b == true then busy = true end
      end
      if not busy or MP.tex_t >= MP.TEX_MAX then
        MP.tex_ok = true
        Draw()
      end
    end
    local b = Buttons()
    local p = MP.prev_keys
    local function edge(k) return b[k] and not p[k] end
    MP.prev_keys = b
    if MP.guard > 0 then
      MP.guard = MP.guard - 1
      return
    end
    if edge("back") then
      Se(C.SE_BACK)
      return MP.close("back")
    end
    local n = #MP.rows
    if n == 0 then return end
    local moved = false
    if edge("up") then
      MP.sel = MP.sel > 1 and MP.sel - 1 or n
      moved = true
    elseif edge("down") then
      MP.sel = MP.sel < n and MP.sel + 1 or 1
      moved = true
    end
    if moved then
      Se(C.SE_MOVE)
      Draw()
      return
    end
    -- LEFT / RIGHT: a step at the press, then repeat while held
    local dir = (b.left and -1) or (b.right and 1) or nil
    local fire = nil
    if dir ~= nil then
      if dir ~= MP.hold_dir then
        MP.hold_dir, MP.hold, fire = dir, 0, dir
      else
        MP.hold = MP.hold + 1
        if MP.hold >= MP.REPEAT_WAIT and (MP.hold - MP.REPEAT_WAIT) % MP.REPEAT_EVERY == 0 then fire = dir end
      end
    else
      MP.hold_dir, MP.hold = nil, 0
    end
    local r = MP.rows[MP.sel]
    if fire ~= nil then
      if r ~= nil and not r.disabled then
        Call(MP.spec.change, MP.sel, fire)
        Se(C.SE_MOVE)
        if MP.open_now then Refresh() end
      else
        Se(C.SE_NO)
      end
      return
    end
    if edge("ok") then
      if r ~= nil and not r.disabled then
        Se(C.SE_GO)
        if type(MP.spec.decide) == "function" then
          Call(MP.spec.decide, MP.sel)
        else
          Call(MP.spec.change, MP.sel, 1)
        end
        if MP.open_now then Refresh() end
      else
        Se(C.SE_NO)
      end
    end
  end
end
