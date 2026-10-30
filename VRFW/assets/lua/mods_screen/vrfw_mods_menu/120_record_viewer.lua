-- mods_menu (VR-Framework): the «Mods» screen, a mod's page (popup, layout A): the window, its buttons, the view tabs'
-- order, «Información» and the full view. Runs after 100_mods_screen.lua in the same VM and takes the names it shares
-- from VRFW_ModsScreen. No engine call at load time.
local Screen = VRFW_ModsScreen
if Screen == nil then
  return
end
local BASE, Badge, C, CE, Call = Screen.BASE, Screen.Badge, Screen.C, Screen.CE, Screen.Call
local ClosePopup, Cut, Draw, Fit, G, Hit = Screen.ClosePopup, Screen.Cut, Screen.Draw, Screen.Fit, Screen.G, Screen.Hit
local INFO, IconOf, Initials, K, KeyOf = Screen.INFO, Screen.IconOf, Screen.Initials, Screen.K, Screen.KeyOf
local M, ModById, Quad, RV, SE_MOVE = Screen.M, Screen.ModById, Screen.Quad, Screen.RV, Screen.SE_MOVE
local SE_NG, SE_OK, SP, Size, StartCo = Screen.SE_NG, Screen.SE_OK, Screen.SP, Screen.Size, Screen.StartCo
local Str, T, Text, Thumb, Toggle, Txt = Screen.Str, Screen.T, Screen.Text, Screen.Thumb, Screen.Toggle, Screen.Txt
local Units, Warnings, Wrap, cnt, mouse = Screen.Units, Screen.Warnings, Screen.Wrap, Screen.cnt, Screen.mouse
local ui = Screen.ui

-- ---- the mod's page (popup, layout A) -----------------------------------------------------------------------------------
-- The window: a header band in the mod's colour (its picture or icon, name and version, «author · updated · size · place», the
-- state pill, «Cerrar»), the row of view tabs (Información · Módulos · Problemas · Conflictos · Ajustes · Novedades),
-- the view's body and one shortcut bar (the view's keys and the main action button) at the bottom. A module's page and
-- a requirement's page open over the page they came from (ui.popup.back): B goes back to it.
-- The VR-Framework report of mod `id` (CMND_VRFW_REPORT_*, the start's report.json): {problems, conflicts, np, nc}.
-- `problems` is what the «Problemas» view lists: the entries grouped by what they mean (why the mod may not load, files left out, rows left out, warnings), each group
-- of one code under a header row in the player's language (text_report.toml `rc_<code>`: what it is and how to fix
-- it); the entries keep the core's English message, by file. `np` = entries (headers not counted). Read once per
-- screen opening. (RV: one table, its caches and sizes are in 100_mods_screen.lua)

-- the body of a mod's page: under the header band and the view tabs, above the shortcut bar
function RV.BodyY()
  return G.WIN_Y + G.BAND_H + G.VTABS_H
end

function RV.FootY()
  return G.WIN_Y + G.WIN_H - G.FOOT_H
end

-- «author · updated · size · place in the load order» (a module: «Module of <parent>» first)
function RV.Meta(m)
  local out = {}
  if m.family ~= nil then
    out[#out + 1] = T("module_of", {o = m.family.name})
  end
  out[#out + 1] = m.author ~= "" and m.author or T("no_author_short")
  local d, sz = Text(m, 9), Size(m.size)
  if d ~= "" then
    out[#out + 1] = d
  end
  if sz ~= "" then
    out[#out + 1] = sz
  end
  if m.enabled and m.pos > 0 and m.family == nil then
    out[#out + 1] = T("meta_position", {n = m.pos, t = cnt.active})
  end
  return table.concat(out, "  ·  ")
end

-- The window of mod `m`'s page: the dim, the header band and the white body. Modal: a click outside closes it.
local function PopupWindow(m)
  Hit(0, 0, 1920, 1080, "modal", function()
    local x, y = mouse.x, mouse.y
    if x < G.WIN_X or x >= G.WIN_X + G.WIN_W or y < G.WIN_Y or y >= G.WIN_Y + G.WIN_H then
      ClosePopup()
    end
  end)
  -- the list behind stays visible, dimmed (no opaque cover)
  Quad("PD", SP("dim"), 0, 0, 1920, 1080, G.DIM_ALPHA)
  local x, y, w, h = G.WIN_X, G.WIN_Y, G.WIN_W, G.BAND_H
  -- the window's pieces never overlap on one layer (two quads of one layer have no fixed order): the band, the tab
  -- row (RV.Tabs) and the white body under them down to the window's bottom (the shortcut bar included)
  Quad("P0", SP("tile" .. INFO.Tile(m)), x, y, w, h)
  Quad("P0", SP("white"), x, y + h + G.VTABS_H, w, G.WIN_H - h - G.VTABS_H)
  -- the compact header: the mod's picture (16:9) or its icon (mod.toml `icon`, else its initials), no big cover tile
  local ch = G.COVER_H
  local cx, cy = x + 24, y + (h - ch) / 2
  local t, ic = Thumb(m), IconOf(m)
  local cw = ch
  if t ~= nil then
    cw = G.COVER_W
    Quad("P1", t[3], cx, cy, cw, ch, 1, t[1])
  elseif ic ~= nil then
    Quad("P1", ic[2], cx, cy, cw, ch, 1, ic[1])
  else
    Quad("P1", SP("iconbox_l"), cx, cy, cw, ch)
    Txt("PC", "[CWG]" .. Initials(m) .. "[C]", cx + cw / 2, cy + ch / 2 - 2, 1.2)
  end
  local tx = cx + cw + 24
  local tw = x + w - 300 - tx
  local name = m.name ~= "" and m.name or m.id
  Txt("PL", Cut(name, Fit(tw - 150, 1.2)) .. (m.version ~= "" and ("   v" .. Cut(m.version, 12)) or ""), tx, y + 38, 1.2)
  Txt("PL", Cut(RV.Meta(m), Fit(tw, 0.7)), tx, y + 82, 0.7)
  -- the state pill and «Cerrar» (B, Esc or a click); a page opened over another goes back to it
  local bs, bt = Badge(m)
  local pw = 230
  Quad("P1", SP(bs), x + w - 28 - pw, y + 60, pw, 38)
  Txt("PC", Cut(bt, Fit(pw - 20, 0.64)), x + w - 28 - pw / 2, y + 79, 0.64)
  Txt("PR", K.B .. " " .. T(ui.popup.back ~= nil and "hint_back" or "hint_close"), x + w - 28, y + 28, 0.72)
  Hit(x + w - 240, y, 240, 52, "pclose", function() ClosePopup() end)
end

-- the main action button at the right of the shortcut bar
-- (`glyph`: the key that presses it from anywhere in the view, drawn before the label)
local function PopupButton(label, filled, sel, act, id, glyph)
  local bw, bh = 300, 48
  local bx, by = G.WIN_X + G.WIN_W - 28 - bw, RV.FootY() + (G.FOOT_H - bh) / 2
  Quad("P1", SP((filled and "btn_on" or "btn_off") .. (sel and "_sel" or "")), bx, by, bw, bh)
  local s = (glyph ~= nil and (glyph .. " ") or "") .. Cut(label, Fit(bw - (glyph ~= nil and 56 or 24), 0.78))
  Txt("PC", (filled and "" or "[CN]") .. s .. (filled and "" or "[C]"), bx + bw / 2, by + bh / 2, 0.78)
  Hit(bx, by, bw, bh, id, act)
end

-- the page's main action, the one button of the shortcut bar: switch the mod on / off
local function PopupButtons(m)
  return {{id = "pb1", label = T(m.enabled and "btn_disable" or "btn_enable"), filled = not m.enabled,
           act = function() StartCo(Toggle) end}}
end

-- the views of mod `m`'s page, in tab order: «Módulos» only for a mod with modules, «Novedades» only for a mod with
-- a changelog summary
function RV.Views(m)
  local v = {"info"}
  if RV.HasModules(m) then
    v[#v + 1] = "modules"
  end
  v[#v + 1] = "problems"
  v[#v + 1] = "conflicts"
  v[#v + 1] = "settings"
  if #RV.Notes(m).notes > 0 then
    v[#v + 1] = "news"
  end
  return v
end

function RV.View()
  return ui.popup ~= nil and ui.popup.view or "info"
end

-- the place of the open view among the page's tabs (0 = no page)
function RV.ViewIndex()
  local p = ui.popup
  local m = p and ModById(p.id)
  if m == nil then
    return 0
  end
  for k, v in ipairs(RV.Views(m)) do
    if v == p.view then
      return k
    end
  end
  return 0
end

-- open view `v` of the page (its scroll and focus from the start)
function RV.Go(v)
  local p = ui.popup
  if p == nil then
    return
  end
  funcLuaCommand(C.SE, SE_MOVE)
  p.view, p.top, p.full, p.srow, p.szone, p.stop = v, 0, nil, 1, "rows", 0
  Draw()
end

-- the changelog summary of mod `m` in the game's language: {title, notes} (read once per page opening)
function RV.Notes(m)
  local ck = "notes:" .. m.id
  local r = RV.cache[ck]
  if r == nil then
    if Screen.Lang() == nil then
      Screen.SetLang(Call(C.LANG) or 1)
    end
    local title, notes = Call(M.NOTES, m.id, Screen.Lang())
    r = {title = Str(title), notes = CE.Lines(Str(notes))}
    RV.cache[ck] = r
  end
  return r
end

-- the shortcuts of the open view, one per entry: «<glyphs> <what it does>»
function RV.Keys(m)
  local p, v, out = ui.popup, RV.View(), {}
  local function add(glyphs, key)
    out[#out + 1] = (glyphs ~= "" and (glyphs .. " ") or "") .. T(key)
  end
  if p.full then
    add("", "sc_scroll")
    add(K.B, "hint_back")
    return out
  end
  if v == "info" then
    add(K.A, "sc_select")
    add(K.X, "sc_description")
  elseif v == "modules" then
    add(K.A, "sc_module_toggle")
    add(K.Y, "sc_module_page")
    add(K.R3, "sc_module_settings")
  elseif v == "settings" then
    add(K.A, "sc_change")
  elseif v == "conflicts" then
    add(K.R3, "sc_who")
  end
  add(K.L2 .. K.R2, "sc_tabs")
  if m.enabled and m.family == nil and m.id ~= BASE then
    add(K.L1 .. K.R1, "sc_order")
  end
  add(K.B, p.back ~= nil and "hint_back" or "hint_close")
  return out
end

-- A presses the main action button in this view (lit)
function RV.ActionFocused(m)
  local p, v = ui.popup, RV.View()
  if p.full or v == "modules" then
    return false
  end
  if v == "info" then
    return RV.InfoTarget(m).kind == "action"
  end
  if v == "settings" then
    return p.szone == "buttons" or #RV.SetRows(m) == 0
  end
  return true
end

-- The shortcut bar: the view's keys in one line (the game draws each key as the pad's or the keyboard's glyph; a
-- toast takes the line for a while) and the main action button
function RV.Footer(m)
  local y = RV.FootY()
  -- the bar is the white body's bottom (a dark bar on the body's layer could end up under it): a rule above it and
  -- dark labels, every key glyph followed by what it does
  Quad("P1", SP("line"), G.WIN_X + 24, y, G.WIN_W - 48, 2)
  local s = ui.toast or table.concat(RV.Keys(m), "    ")
  Txt("PL", "[CB]" .. Cut(s, Fit(G.WIN_W - 380, 0.64)) .. "[C]", G.WIN_X + 32, y + G.FOOT_H / 2, 0.64)
  local pb = PopupButtons(m)[1]
  local hot = (mouse.on and mouse.hot == pb.id) or (not mouse.on and RV.ActionFocused(m))
  -- «Módulos»: X presses the button (A switches the focused module there)
  PopupButton(pb.label, pb.filled, hot, pb.act, pb.id, RV.View() == "modules" and not ui.popup.full and K.X or nil)
end

-- One line of chips from x (wrapping into at most `maxrows` rows of width w): {text, sprite, icon, id, act, foc}.
-- The chip on P0, its icon on P1, its text on PL. Returns the y under the last row.
function RV.Chips(items, x, y, w, maxrows)
  local cx, rows = x, 1
  for _, it in ipairs(items) do
    local tw = math.min(w, math.floor(Units(it.text) * G.PX * 0.68) + (it.icon and 64 or 34))
    if cx > x and cx + tw > x + w then
      rows = rows + 1
      if rows > maxrows then
        break
      end
      cx, y = x, y + 50
    end
    Quad("P0", SP(it.sprite), cx, y, tw, 40)
    local t0 = cx + 17
    if it.icon then
      Quad("P1", SP(it.icon), cx + 10, y + 6, 28, 28)
      t0 = cx + 46
    end
    Txt("PL", Cut(it.text, Fit(tw - (t0 - cx) - 10, 0.68)), t0, y + 20, 0.68)
    if it.foc then
      CE.Focus("P1", cx, y, tw, 40, 3)
    end
    if it.act ~= nil then
      Hit(cx, y, tw, 40, it.id, it.act)
    end
    cx = cx + tw + 10
  end
  return y + 50
end

-- «keeper_scenes» -> «Keeper scenes»: the words of an id
function RV.Words(id)
  local s = string.gsub(id, "[_%.%-]+", " ")
  return (string.gsub(s, "^%l", string.upper))
end

-- «Ofrece a otros mods»: what the mod.toml `provides` (the names other mods can require), in words: the text key
-- `<mod>.provides_<name>` of its text rows, else the installed mod of that id, else the name's words
function RV.Offers(m)
  local out = {}
  for item in string.gmatch(INFO.Provides(m), "[^,]+") do
    local name = string.match(item, "^%s*([%w_%.%-]+)")
    if name ~= nil and KeyOf(name) ~= m.id then
      local s = CE.KeyText(m.id .. ".provides_" .. name)
      if s == "" then
        local o = ModById(name)
        s = (o ~= nil and o.name ~= "") and o.name or RV.Words(name)
      end
      out[#out + 1] = s
    end
  end
  return out
end

-- what the pad can focus in «Información», in its order: the chips of the requirements that are installed, «Ver
-- descripción completa», the main action (the first focus)
function RV.InfoTargets(m)
  local out = {}
  for i, d in ipairs(INFO.Needs(m)) do
    if d.mod ~= nil and i <= 5 then
      out[#out + 1] = {kind = "chip", id = d.mod.id}
    end
  end
  out[#out + 1] = {kind = "desc"}
  out[#out + 1] = {kind = "action"}
  return out
end

function RV.InfoTarget(m)
  local t = RV.InfoTargets(m)
  local p = ui.popup
  p.ifoc = math.max(1, math.min(p.ifoc or #t, #t))
  return t[p.ifoc]
end

-- the pad in «Información»: left / up the previous target, right / down the next
function RV.InfoMove(m, d)
  local t = RV.InfoTargets(m)
  local p = ui.popup
  local k = math.max(1, math.min(#t, (p.ifoc or #t) + d))
  funcLuaCommand(C.SE, k ~= p.ifoc and SE_MOVE or SE_NG)
  p.ifoc = k
  Draw()
end

-- «Información»: «Qué hace» (the changelog summary's first points, else the description) at the left with one
-- warning and «Ver descripción completa»; «Necesita» (a chip per requirement: green = met, red = missing / off / too
-- old; A or a click opens that mod's page), «Ofrece a otros mods» and «Etiquetas» at the right
function RV.DrawInfo(m)
  if ui.popup.full then
    RV.DrawFull(m)
    return
  end
  local top, foot = RV.BodyY() + 34, RV.FootY()
  local lx, lw = G.WIN_X + 40, 700
  local rx = G.WIN_X + 800
  local rw = G.WIN_X + G.WIN_W - 40 - rx
  local target = RV.InfoTarget(m)
  local pad = not mouse.on
  Quad("P0", SP("line"), rx - 32, top - 14, 2, foot - top - 10)
  Txt("PL", "[CN]" .. T("what_it_does") .. "[C]", lx, top, 0.86)
  local y, ylim = top + 46, foot - 130
  local notes = RV.Notes(m).notes
  if #notes > 0 then
    for i = 1, math.min(5, #notes) do
      local ls = Wrap(notes[i], Fit(lw - 30, 0.74), 2)
      if y + (#ls - 1) * 30 > ylim then
        break
      end
      for j, l in ipairs(ls) do
        Txt("PL", (j == 1 and "[CN]›[C]  " or "") .. "[CB]" .. l .. "[C]", lx + (j == 1 and 0 or 25), y + (j - 1) * 30, 0.74)
      end
      y = y + #ls * 30 + 10
    end
  else
    local desc = INFO.Description(m)
    for _, l in ipairs(Wrap(desc ~= "" and desc or T("no_desc"), Fit(lw, 0.74), 8)) do
      Txt("PL", (desc ~= "" and "[CB]" or "[CWG]") .. l .. "[C]", lx, y, 0.74)
      y = y + 30
    end
  end
  -- one warning (not loaded, a requirement, shared files) above the button; «Ver descripción completa» lists them all
  local warn = (m.enabled and m.state == 1) and {true, T("state_skip", {r = Text(m, 1)})} or Warnings(m)[1]
  if warn ~= nil then
    local wy = foot - 110
    Quad("P1", SP(warn[1] and "warn_r" or "warn_a"), lx, wy - 14, 28, 28)
    Txt("PL", (warn[1] and "[CR]" or "[CY]") .. Cut(warn[2], Fit(lw - 40, 0.66)) .. "[C]", lx + 38, wy, 0.66)
  end
  local bw, bh, by = 430, 46, foot - 74
  local foc = (mouse.on and mouse.hot == "pfull") or (pad and target.kind == "desc")
  Quad("P1", SP(foc and "btn_off_sel" or "btn_off"), lx, by, bw, bh)
  Txt("PC", "[CN]" .. K.X .. " " .. Cut(T("full_desc"), Fit(bw - 70, 0.72)) .. "[C]", lx + bw / 2, by + bh / 2, 0.72)
  Hit(lx, by, bw, bh, "pfull", function() RV.OpenFull() end)
  -- «Necesita»
  Txt("PL", "[CN]" .. T("f_needs") .. "[C]", rx, top, 0.86)
  y = top + 26
  local needs = INFO.Needs(m)
  if #needs == 0 then
    Txt("PL", "[CWG]" .. T("needs_none") .. "[C]", rx, y + 20, 0.72)
    y = y + 50
  else
    local items = {}
    for i, d in ipairs(needs) do
      if i > 5 then
        break
      end
      local it = {text = d.ok and d[1] or (d[1] .. "  ·  " .. d.reason), sprite = d.ok and "pill_green" or "pill_red",
                  icon = d.ok and "ok" or "no"}
      if d.mod ~= nil then
        local id = d.mod.id
        it.id = "need" .. i
        it.act = function() RV.OpenChild(id) end
        it.foc = (mouse.on and mouse.hot == it.id) or (pad and target.kind == "chip" and target.id == id)
      end
      items[#items + 1] = it
    end
    y = RV.Chips(items, rx, y, rw, 2)
  end
  -- «Ofrece a otros mods»
  y = y + 18
  Txt("PL", "[CN]" .. T("offers") .. "[C]", rx, y, 0.86)
  local offers = RV.Offers(m)
  local ls = Wrap(#offers > 0 and table.concat(offers, "  ·  ") or T("offers_none"), Fit(rw, 0.72), 3)
  for i, l in ipairs(ls) do
    Txt("PL", (#offers > 0 and "[CB]" or "[CWG]") .. l .. "[C]", rx, y + 40 + (i - 1) * 30, 0.72)
  end
  y = y + 40 + #ls * 30 + 10
  -- «Etiquetas»
  Txt("PL", "[CN]" .. T("f_tags") .. "[C]", rx, y, 0.86)
  local tags = {}
  for i, t in ipairs(CE.ModTags(m)) do
    if i > 4 then
      break
    end
    tags[#tags + 1] = {text = t, sprite = "pill_blue"}
  end
  if #tags == 0 then
    Txt("PL", "[CWG]" .. INFO.DASH .. "[C]", rx, y + 40, 0.72)
  else
    RV.Chips(tags, rx, y + 22, rw, 2)
  end
end

-- «Ver descripción completa» (X, or A / a click on the button): the page's body shows the whole description, then the
-- technical details (folder, requirements, incompatibilities, what it provides, native permissions) and every
-- warning; up / down or the wheel scroll (left / right a page), B goes back to «Información»
function RV.OpenFull()
  local p = ui.popup
  if p == nil or p.view ~= "info" then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  funcLuaCommand(C.SE, SE_OK)
  p.full, p.ftop = true, 1
  Draw()
end

-- the mod's folder under the game's mods folder, with «/» (the game's text reads a backslash as an escape: «\n» of
-- «mods\new_animations» was a line break)
function RV.Folder(m)
  local f = Str(Call(M.FOLDER, m.id))
  return "mods/" .. (f ~= "" and f or m.id)
end

-- the lines of the whole description and the technical details (read once per page opening)
function RV.FullLines(m)
  local ck = "full:" .. m.id
  if RV.cache[ck] ~= nil then
    return RV.cache[ck]
  end
  local w = Fit(G.WIN_W - 100, 0.74)
  local out = {}
  local _, _, all = INFO.Description(m)
  for _, l in ipairs(Wrap(all ~= "" and all or T("no_desc"), w, 1000)) do
    out[#out + 1] = l ~= "" and ((all ~= "" and "[CB]" or "[CWG]") .. l .. "[C]") or ""
  end
  out[#out + 1] = ""
  out[#out + 1] = "[CN]" .. T("details_tech") .. "[C]"
  local function field(label, value)
    if value ~= "" then
      for _, l in ipairs(Wrap(label .. ": " .. value, w, 6)) do
        out[#out + 1] = "[CWG]" .. l .. "[C]"
      end
    end
  end
  field(T("f_folder"), RV.Folder(m))
  field(T("f_requires"), INFO.Requires(m))
  field(T("f_conflicts"), (string.gsub(Text(m, 3), "\n", ", ")))
  field(T("f_provides"), INFO.Provides(m))
  field(T("f_permissions"), INFO.Perms(m))
  local ws = {}
  if m.enabled and m.state == 1 then
    ws[#ws + 1] = {true, T("state_skip", {r = Text(m, 1)})}
  end
  for _, x in ipairs(Warnings(m)) do
    ws[#ws + 1] = x
  end
  for l in string.gmatch(Str(Call(M.AU_NOTES, m.id)), "[^\n]+") do
    local wf, tx = string.match(l, "^(%d)|(.*)$")
    if tx ~= nil then
      ws[#ws + 1] = {wf == "1", T("au_note", {t = tx})}
    end
  end
  for _, x in ipairs(ws) do
    for _, l in ipairs(Wrap(x[2], w, 3)) do
      out[#out + 1] = (x[1] and "[CR]" or "[CY]") .. l .. "[C]"
    end
  end
  RV.cache[ck] = out
  return out
end

-- The page control of a paged list, right-aligned at xr on line y: «↑ <left key>  1-9 de 11  <right key> ↓» (the arrow
-- blue when there is a page that way, grey when not; nothing when everything fits). A click on its left half goes a
-- page back, on its right half a page forward (its width estimated: the text layers anchor on the right).
function RV.Pager(xr, y, first, last, total, prev, next)
  if total <= last - first + 1 then
    return
  end
  local back, fwd = first > 1, last < total
  local s = (back and "[CN]↑[C]" or "[CWG]↑[C]") .. " " .. K.LEFT .. "  [CB]" ..
            T("report_rows", {n = first, c = last, t = total}) .. "[C]  " .. K.RIGHT .. " " .. (fwd and "[CN]↓[C]" or "[CWG]↓[C]")
  Txt("PR", s, xr, y, 0.66)
  local w = math.floor(Units(s) * G.PX * 0.66 * 0.82)
  Hit(xr - w, y - 20, w / 2, 40, "pgback", function()
    if back then prev() else funcLuaCommand(C.SE, SE_NG) end
  end)
  Hit(xr - w / 2, y - 20, w / 2, 40, "pgnext", function()
    if fwd then next() else funcLuaCommand(C.SE, SE_NG) end
  end)
end

function RV.DrawFull(m)
  local p = ui.popup
  local lines = RV.FullLines(m)
  local x, top = G.WIN_X + 40, RV.BodyY() + 34
  local y0, vis = top + 50, RV.FULL_ROWS
  p.ftop = math.max(1, math.min(p.ftop or 1, math.max(1, #lines - vis + 1)))
  Txt("PL", "[CN]" .. T("full_desc_title") .. "[C]", x, top, 0.86)
  RV.Pager(G.WIN_X + G.WIN_W - 40, top, p.ftop, math.min(#lines, p.ftop + vis - 1), #lines, function()
    p.ftop = math.max(1, p.ftop - vis)
    funcLuaCommand(C.SE, SE_MOVE)
    Draw()
  end, function()
    p.ftop = p.ftop + vis
    funcLuaCommand(C.SE, SE_MOVE)
    Draw()
  end)
  for i = 0, vis - 1 do
    local l = lines[p.ftop + i]
    if l == nil then
      break
    end
    Txt("PL", l, x, y0 + i * 30, 0.74)
  end
end

-- for 100_mods_screen.lua and the files after this one
Screen.PopupWindow = PopupWindow
Screen.PopupButtons = PopupButtons
