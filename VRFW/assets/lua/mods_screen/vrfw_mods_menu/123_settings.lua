-- mods_menu (VR-Framework): the «Mods» screen, a mod's page, «Ajustes» (the mod's own settings), and the page's drawing
-- (DrawDetails). Runs after 100_mods_screen.lua in the same VM and takes the names it shares from VRFW_ModsScreen. No
-- engine call at load time.
local Screen = VRFW_ModsScreen
if Screen == nil then
  return
end
local C, CE, Call, Crc, Cut, Draw, FN = Screen.C, Screen.CE, Screen.Call, Screen.Crc, Screen.Cut, Screen.Draw, Screen.FN
local Fit, G, Hit, IconOf, Initials, Int = Screen.Fit, Screen.G, Screen.Hit, Screen.IconOf, Screen.Initials, Screen.Int
local Log, ModById, PopupButtons, PopupWindow = Screen.Log, Screen.ModById, Screen.PopupButtons, Screen.PopupWindow
local Quad, RV, SE_MOVE, SE_NG, SP, Str = Screen.Quad, Screen.RV, Screen.SE_MOVE, Screen.SE_NG, Screen.SP, Screen.Str
local T, TextIdKey, Txt, Units, Wrap, ui = Screen.T, Screen.TextIdKey, Screen.Txt, Screen.Units, Screen.Wrap, Screen.ui

-- ---- «Ajustes»: the mod's own settings ---------------------------------------------------
-- The rows a mod declares in its options.toml (mod_options, CMND_EVT_OPT_*), the ones whose key starts with "<mod>.":
-- the same rows, values and storage as Opciones › «Opciones de mods» (one store: <data dir>\mod_options\<mod>.json, or
-- the owner's get / set commands). Only the mods active at this start have rows (the registry is built at boot).
-- (functions of RV: the main chunk is at Lua's limit of 200 locals)
RV.OPT = {ROWS = Crc("CMND_VRFW_OPTION_ROWS"), ROW = Crc("CMND_VRFW_OPTION_ROW"), GET = Crc("CMND_VRFW_OPTION_GET"),
          SET = Crc("CMND_VRFW_OPTION_SET"), STEP = Crc("CMND_VRFW_OPTION_STEP"), TEXT = Crc("CMND_VRFW_OPTION_TEXT")}

-- the settings of mod `id`, read once per page opening (RV.cache is emptied by OpenDetails)
function RV.Settings(id)
  local ck = "settings:" .. id
  local r = RV.cache[ck]
  if r ~= nil then
    return r
  end
  local opts = {}
  local pre = id .. "."
  for i = 1, Int(Call(RV.OPT.ROWS)) do
    local k, kind, storage, label, fallback, get, set, _gated, _fixed, _parent, help, help_fb = Call(RV.OPT.ROW, i)
    if type(k) == "string" and string.sub(k, 1, #pre) == pre then
      opts[#opts + 1] = {key = k, kind = Str(kind), storage = Str(storage), label = Int(label), fallback = Str(fallback),
                         get = Int(get), set = Int(set), help = Int(help), help_fb = Str(help_fb)}
    end
  end
  -- the «Modules» first: the module mods of its family (on / off = the mod switched
  -- on / off), then its internal modules (option rows named in [modules] options), then the other settings
  r = {}
  local m = ModById(id)
  if m ~= nil then
    for _, mm in ipairs(m.modules or {}) do
      r[#r + 1] = {module = mm, key = mm.id}
    end
    for _, key in ipairs(m.internal or {}) do
      for k, o in ipairs(opts) do
        if o.key == key then
          o.imodule = true
          r[#r + 1] = table.remove(opts, k)
          break
        end
      end
    end
  end
  for _, o in ipairs(opts) do
    r[#r + 1] = o
  end
  RV.cache[ck] = r
  return r
end

-- the mod has a «Modules» list (module mods of its family or internal modules)
function RV.HasModules(m)
  return #(m.modules or {}) > 0 or #(m.internal or {}) > 0
end

-- a menu_text row in the game's language, else the fallback
function RV.TextOf(id, fallback)
  if id ~= nil and id ~= 0 then
    local s = Call(C.TEXT_GET, id)
    if type(s) == "string" and s ~= "" then
      return s
    end
  end
  return fallback
end

-- (value, changeable): nil for a row with its own Lua behaviour or a value nobody answers
function RV.Value(r)
  if r.module ~= nil then
    return r.module.enabled and 1 or 0, true      -- a module mod: on = switched on
  end
  if r.kind == "lua" or r.storage == "lua" then
    return nil, false
  end
  if r.storage == "command" then
    local v, extra = Call(r.get)
    if type(v) == "number" then
      return v, true
    end
    if type(v) == "boolean" and (v or extra ~= nil) then
      return v and 1 or 0, true
    end
    return nil, false
  end
  local v, dv = Call(RV.OPT.GET, r.key, true)  -- the real value (a child row of a «llave» whose parent is off: greyed)
  if type(v) == "number" then
    return v, true
  end
  if v == false and type(dv) == "number" then
    return dv, false          -- enabled_if not met / parent off: shown greyed, no changes
  end
  return nil, false
end

function RV.Fmt(r, v)
  if r.module ~= nil then
    local k = v == 1 and "module_on" or "module_off"
    return T(r.module.pending and (k .. "_next") or k)
  end
  local id, fb = Call(RV.OPT.TEXT, r.key, v)
  if type(id) ~= "number" then
    return tostring(v)
  end
  local s = RV.TextOf(id, Str(fb))
  return s ~= "" and s or tostring(v)
end

-- the selected row's (or `row`'s) value one step in direction `dir` (±1), stored where the row keeps it
function RV.Change(m, dir, row)
  local r = row or RV.SetRows(m)[ui.popup.srow or 1]
  if r ~= nil and r.module ~= nil then
    return RV.ToggleModule(r.module)
  end
  local v, live = nil, false
  if r ~= nil then
    v, live = RV.Value(r)
  end
  local ok, n = false, nil
  if v ~= nil and live then
    n = Call(RV.OPT.STEP, r.key, v, dir)
    if type(n) == "number" and n ~= v then
      if r.storage == "command" then
        ok = Call(r.set, n) == true
      else
        ok = Call(RV.OPT.SET, r.key, n) == true
      end
    end
  end
  funcLuaCommand(C.SE, ok and SE_MOVE or SE_NG)
  if ok then
    Log("setting", r.key, tostring(n))
  end
  Draw()
end

-- The «Ajustes» view: the mod's own settings, then those of each active module under a slim bar with the module's
-- badge and name; one compact row a setting (its «[Prefix]» as a small chip, its label, a small ‹ value › box next to
-- it) and, at the right, the focused setting's sheet (its full label, its module and its help text). The page scrolls
-- by lines, at most RV.SET_ROWS rows a page (the popup layers' instance limits).
-- RV.Layout(m) -> lines {kind = "head" | "row", h = height, items = {row numbers}, group = module mod}
RV.HEAD_H, RV.ROW_H, RV.SET_ROWS, RV.SET_CHIPS = 34, 38, 12, 4

function RV.Layout(m)
  local lines, group = {}, nil
  for n, r in ipairs(RV.SetRows(m)) do
    if r.group ~= nil and r.group ~= group then
      group = r.group
      lines[#lines + 1] = {kind = "head", h = RV.HEAD_H, group = group}
    end
    lines[#lines + 1] = {kind = "row", h = RV.ROW_H, items = {n}}
  end
  return lines
end

-- the line of row number n in `lines`
function RV.Where(lines, n)
  for li, l in ipairs(lines) do
    if l.items ~= nil and l.items[1] == n then
      return li
    end
  end
  return nil
end

-- the next line with a row from line `li` in direction d (±1), or nil
function RV.NextLine(lines, li, d)
  local k = li + d
  while lines[k] ~= nil and lines[k].kind == "head" do
    k = k + d
  end
  return lines[k] ~= nil and k or nil
end

-- A / a click on row n: the setting moves one step
function RV.Activate(m, n)
  local r = RV.SetRows(m)[n]
  if r == nil then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  ui.popup.srow, ui.popup.szone = n, "rows"
  RV.Change(m, 1)
end

-- The pad in the «Ajustes» view. Rows zone: up / down move between rows (down from the last row goes to the footer
-- button), left / right change the focused setting's value. Buttons zone: up goes back to the last row. false = no
-- rows (the keys keep walking the buttons as in the other views).
function RV.SettingsKey(id)
  local m = ModById(ui.popup.id)
  local rows = m and RV.SetRows(m) or {}
  if #rows == 0 then
    return false
  end
  local p = ui.popup
  local lines = RV.Layout(m)
  local function moved(ok)
    funcLuaCommand(C.SE, ok and SE_MOVE or SE_NG)
    Draw()
  end
  if p.szone == "buttons" then
    if id == FN.UP then
      local li = RV.NextLine(lines, #lines + 1, -1)
      p.szone, p.srow = "rows", li and lines[li].items[1] or 1
      moved(true)
    elseif id == FN.LEFT or id == FN.RIGHT then
      local n = #PopupButtons(m)
      local b = math.max(1, math.min(n, (p.btn or 1) + (id == FN.LEFT and -1 or 1)))
      local ok = b ~= p.btn
      p.btn = b
      moved(ok)
    else
      moved(false)
    end
    return true
  end
  local sel = math.max(1, math.min(p.srow or 1, #rows))
  local li = RV.Where(lines, sel) or RV.NextLine(lines, 0, 1)
  if id == FN.UP or id == FN.DOWN then
    local k = RV.NextLine(lines, li, id == FN.UP and -1 or 1)
    if k == nil then
      if id == FN.DOWN and #PopupButtons(m) > 0 then
        p.szone = "buttons"
        p.btn = math.max(1, math.min(#PopupButtons(m), p.btn or 1))
        moved(true)
      else
        moved(false)
      end
      return true
    end
    p.srow = lines[k].items[1]
    moved(true)
  else
    p.srow = sel
    RV.Change(m, id == FN.LEFT and -1 or 1)
  end
  return true
end

-- a setting's label split into its «[Prefix]» (the chip) and the rest; the module group's name
function RV.SetLabel(r)
  local label = RV.TextOf(r.label, r.fallback ~= "" and r.fallback or r.key)
  local chip, rest = string.match(label, "^%[([^%]]+)%]%s*(.+)$")
  return rest or label, chip
end

function RV.GroupName(mm)
  local title = RV.Notes(mm).title
  return title ~= "" and title or (mm.mname or (mm.name ~= "" and mm.name or mm.id))
end

-- the help text of a setting: its row's `help` (CMND_VRFW_OPTION_ROW), else the text key «<row key>_help» of its mod's
-- text rows ("" = none)
function RV.SetHelp(r)
  local s = RV.TextOf(r.help, r.help_fb)
  if s ~= "" then
    return s
  end
  local id = TextIdKey(r.key .. "_help")
  return id ~= nil and Str(Call(C.TEXT_GET, id)) or ""
end

-- a module's slim section bar: its badge (icon or two letters) and its name
function RV.DrawGroupBar(mm, x, y, w)
  local h = RV.HEAD_H - 6
  Quad("P1", SP("row_head"), x, y, w, h)
  local name = RV.GroupName(mm)
  local ic = IconOf(mm)
  if ic ~= nil then
    Quad("P1", ic[2], x + 8, y + 3, h - 6, h - 6, 1, ic[1])
  else
    Txt("PC", Initials({name = name, id = name}), x + 8 + (h - 6) / 2, y + h / 2, 0.5)
  end
  Txt("PL", Cut(name, Fit(w - 80, 0.66)), x + h + 14, y + h / 2, 0.66)
end

-- One compact setting row: the chip of its «[Prefix]» (inline text when the page's chips are used up), its label and
-- the small ‹ value › box at a fixed column next to it (greyed when it cannot change now). The focused row gets the
-- cyan edges. `chips` counts the page's chip quads.
function RV.DrawRow(m, n, r, x, y, w, focused, chips)
  local h = RV.ROW_H - 4
  local cy = y + h / 2
  if focused then
    CE.Focus("P1", x, y, w, h, 3)
  end
  local label, chip = RV.SetLabel(r)
  local tx = x + 12
  if chip ~= nil and chips.n < RV.SET_CHIPS then
    chips.n = chips.n + 1
    local cw = math.min(140, math.floor(Units(chip) * G.PX * 0.52) + 22)
    Quad("P1", SP("pill_blue"), tx, cy - 12, cw, 24)
    Txt("PC", Cut(chip, Fit(cw - 10, 0.52)), tx + cw / 2, cy, 0.52)
    tx = tx + cw + 10
  elseif chip ~= nil then
    label = chip .. " · " .. label
  end
  local bx, bw = x + w - G.SET_VAL_W - 8, G.SET_VAL_W
  Txt("PL", "[CB]" .. Cut(label, Fit(bx - tx - 16, 0.66)) .. "[C]", tx, cy, 0.66)
  local v, live = RV.Value(r)
  if r.kind == "lua" or r.storage == "lua" then
    Txt("PC", "[CWG]" .. Cut(T("set_lua"), Fit(bw, 0.5)) .. "[C]", bx + bw / 2, cy, 0.5)
  elseif v == nil then
    Txt("PC", "[CWG]" .. T("set_unknown") .. "[C]", bx + bw / 2, cy, 0.6)
  else
    Quad("P1", SP((focused and live) and "val_sel" or "val"), bx, cy - 15, bw, 30)
    Txt("PC", (live and "[CB]" or "[CWG]") .. Cut(RV.Fmt(r, v), Fit(bw - 60, 0.62)) .. "[C]", bx + bw / 2, cy, 0.62)
  end
  Hit(x, y, w, h, "set" .. n, function() RV.Activate(m, n) end)
end

-- the focused setting's sheet at the right: a blue bar with its label, its module and chip, its help text
function RV.DrawSetPane(r)
  local x, w, y = G.MOD_PANE_X, G.MOD_PANE_W, RV.BodyY() + 14
  local hh = G.MOD_PANE_HEAD
  Quad("P1", SP("hbar"), x, y, w, hh)
  local label, chip = RV.SetLabel(r)
  Txt("PL", Cut(label, Fit(w - 40, 0.74)), x + 20, y + hh / 2, 0.74)
  local from = {}
  if r.group ~= nil then
    from[#from + 1] = RV.GroupName(r.group)
  end
  if chip ~= nil then
    from[#from + 1] = chip
  end
  local ty = y + hh + 26
  if #from > 0 then
    Txt("PL", "[CN]" .. Cut(table.concat(from, "  ·  "), Fit(w - 40, 0.64)) .. "[C]", x + 20, ty, 0.64)
    ty = ty + 34
  end
  local help = RV.SetHelp(r)
  for k, l in ipairs(Wrap(help ~= "" and help or T("set_no_help"), Fit(w - 40, 0.64), G.SET_HELP_LINES)) do
    Txt("PL", (help ~= "" and "[CB]" or "[CWG]") .. l .. "[C]", x + 20, ty + (k - 1) * 30, 0.64)
  end
end

function RV.DrawSettings(m)
  local rows = RV.SetRows(m)
  local px, py = G.WIN_X + 32, RV.BodyY() + 14
  local w = G.MOD_LIST_W
  if #rows == 0 then
    local why = (m.enabled and m.state == 0 and not m.pending) and "set_none" or "set_inactive"
    for i, l in ipairs(Wrap(T(why), Fit(G.WIN_W - 80, 0.8), 3)) do
      Txt("PL", "[CN]" .. l .. "[C]", px, py + 26 + (i - 1) * 34, 0.8)
    end
    return
  end
  local p = ui.popup
  local sel = math.max(1, math.min(p.srow or 1, #rows))
  p.srow = sel
  local lines = RV.Layout(m)
  local bottom = RV.FootY() - 40     -- above the page line and the shortcut bar
  local avail = bottom - py
  -- scroll: the selected line on the page (with its section bar when it is right above)
  local sl = RV.Where(lines, sel) or 1
  local top = math.max(1, math.min(p.stop or 1, #lines))
  if sl < top then
    top = sl
  end
  if top > 1 and lines[top - 1].kind == "head" and top - 1 <= sl then
    top = top - 1
  end
  local function fits(a, b)
    local hsum, nrows = 0, 0
    for k = a, b do
      hsum = hsum + lines[k].h
      nrows = nrows + (lines[k].kind == "row" and 1 or 0)
    end
    return hsum <= avail and nrows <= RV.SET_ROWS
  end
  while top < sl and not fits(top, sl) do
    top = top + 1
  end
  p.stop = top
  local y, first, last, drawn, chips = py, nil, nil, 0, {n = 0}
  for k = top, #lines do
    local l = lines[k]
    local need = l.h + ((l.kind == "head" and lines[k + 1] ~= nil) and lines[k + 1].h or 0)   -- a bar only with its first row
    if y + need > bottom or (l.kind == "row" and drawn >= RV.SET_ROWS) then
      break
    end
    if l.kind == "head" then
      RV.DrawGroupBar(l.group, px, y + 4, w)
    else
      local n = l.items[1]
      first, last, drawn = first or n, n, drawn + 1
      RV.DrawRow(m, n, rows[n], px, y, w, p.szone ~= "buttons" and n == sel, chips)   -- hover moves p.srow too (Hover)
    end
    y = y + l.h
  end
  -- where the page is, and the short note on where these values live
  local note = T("set_note")
  if first ~= nil and (first > 1 or last < #rows) then
    note = T("report_rows", {n = first, c = last, t = #rows}) .. "   ·   " .. note
  end
  Txt("PL", "[CWG]" .. Cut(note, Fit(w, 0.58)) .. "[C]", px, bottom + 20, 0.58)
  RV.DrawSetPane(rows[sel])
end

-- the own settings of mod `id`: its rows without the modules (those are the «Módulos» view)
function RV.OwnSettings(id)
  local r = {}
  for _, o in ipairs(RV.Settings(id)) do
    if o.module == nil and not o.imodule then
      r[#r + 1] = o
    end
  end
  return r
end

-- the «Ajustes» rows of mod `m`: its own settings, then those of each module mod of its family that is on (the same
-- rows, keys and storage as on the module's own page; `group` = the module, for its section title)
function RV.SetRows(m)
  local ck = "setrows:" .. m.id
  local r = RV.cache[ck]
  if r == nil then
    r = RV.OwnSettings(m.id)
    for _, mm in ipairs(m.modules or {}) do
      if mm.enabled then
        for _, o in ipairs(RV.OwnSettings(mm.id)) do
          local row = {group = mm}
          for k, v in pairs(o) do
            row[k] = v
          end
          r[#r + 1] = row
        end
      end
    end
    RV.cache[ck] = r
  end
  return r
end

local function DrawDetails()
  local m = ModById(ui.popup.id)
  while m == nil and ui.popup ~= nil do
    -- the mod is gone from the list (a rescan): the page under it, else none
    ui.popup = ui.popup.back
    m = ui.popup and ModById(ui.popup.id)
  end
  if m == nil then
    return
  end
  local known = false
  for _, v in ipairs(RV.Views(m)) do
    known = known or v == ui.popup.view
  end
  if not known then
    ui.popup.view = "info"
  end
  PopupWindow(m)
  RV.Tabs(m)
  local v = ui.popup.view
  if v == "info" then
    RV.DrawInfo(m)
  elseif v == "modules" then
    RV.DrawModules(m)
  elseif v == "settings" then
    RV.DrawSettings(m)
  elseif v == "news" then
    RV.DrawNews(m)
  else
    RV.Draw(m, v == "problems" and 2 or 3)
  end
  RV.Footer(m)
end

-- for 100_mods_screen.lua and the files after this one
Screen.DrawDetails = DrawDetails
