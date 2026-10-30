-- mods_menu (VR-Framework): the «Mods» screen, the list rows and the info panel (the mod info block INFO, CE.ListRow,
-- CE.InfoPanel, the «Orden de carga» tab). Runs after 100_mods_screen.lua in the same VM and takes the names it shares
-- from VRFW_ModsScreen. No engine call at load time.
local Screen = VRFW_ModsScreen
if Screen == nil then
  return
end
local BASE, Badge, C, CE, Call, Cut = Screen.BASE, Screen.Badge, Screen.C, Screen.CE, Screen.Call, Screen.Cut
local DrawScrollbar, Fit, G, Hit, INFO = Screen.DrawScrollbar, Screen.Fit, Screen.G, Screen.Hit, Screen.INFO
local IconOf, Initials, K, KeyOf, M = Screen.IconOf, Screen.Initials, Screen.K, Screen.KeyOf, Screen.M
local ModById, NameOf, OpenDetails, OrderRows = Screen.ModById, Screen.NameOf, Screen.OpenDetails, Screen.OrderRows
local Quad, SP, SelectMod, Size, StartCo = Screen.Quad, Screen.SP, Screen.SelectMod, Screen.Size, Screen.StartCo
local Str, T, Text, TextIdKey, TileOf = Screen.Str, Screen.T, Screen.Text, Screen.TextIdKey, Screen.TileOf
local Toggle, Txt, Warnings, Wrap, cnt = Screen.Toggle, Screen.Txt, Screen.Warnings, Screen.Wrap, Screen.cnt
local mouse, ui = Screen.mouse, Screen.ui

-- ---- the mod info block: labelled fields, shared by the «Orden de carga» panel and a mod's page --------
-- (INFO: its layers and sizes are in 100_mods_screen.lua)

-- the state in two words and its colour
function INFO.State(m)
  if m.pending then
    return T(m.enabled and "st_pend_on" or "st_pend_off"), "[CY]"
  end
  if m.enabled and m.state == 1 then
    return T("st_skip"), "[CR]"
  end
  return T(m.enabled and "st_on" or "st_off"), m.enabled and "[CB]" or "[CWG]"
end

function INFO.Provides(m)
  if m.provides_text == nil then
    m.provides_text = Str(Call(M.PROVIDES, m.id))
  end
  return m.provides_text
end

function INFO.Value(s)
  return (s ~= nil and s ~= "") and s or INFO.DASH
end

-- «Requiere» in words: a requirement on a part of the framework (any name VR-Framework provides:
-- mod_options, technique_engine, telop_engine…) is a requirement on the framework itself, shown once as «VR-Framework
-- (x.y+)»; another mod by its name (a minimum version as «(1.0+)»: the game font has no «≥»). The ModLoader resolves those names through the framework's `provides` (old
-- manifests keep working).
function INFO.Requires(m)
  local raw = Text(m, 2)
  if raw == "" then
    return ""
  end
  local base, parts = ModById(BASE), {}
  if base ~= nil then
    for item in string.gmatch(INFO.Provides(base), "[^,%s]+") do
      local n = string.match(item, "^([%w_]+)")
      if n ~= nil then
        parts[n] = true
      end
    end
  end
  local function need(op, ver)
    if ver == "" then
      return ""
    end
    if op == "" or op == ">=" then
      return " (" .. ver .. "+)"
    end
    return " (" .. op .. " " .. ver .. ")"
  end
  local fw, fwv, out, seen = false, "", {}, {}
  for req in string.gmatch(raw, "[^,\n]+") do
    local name, op, ver = string.match(req, "^%s*([%w_%.%-]+)%s*([<>=!~]*)%s*([^%s]*)%s*$")
    if name ~= nil then
      local key = KeyOf(name)
      if key == BASE or parts[name] then
        fw = true
        if key == BASE and ver ~= "" then
          fwv = need(op, ver)
        end
      elseif not seen[key] then
        seen[key] = true
        out[#out + 1] = NameOf(name) .. need(op, ver)
      end
    end
  end
  if fw then
    table.insert(out, 1, ((base ~= nil and base.name ~= "") and base.name or "VR-Framework") .. fwv)
  end
  return table.concat(out, ", ")
end

-- The colour of a mod's page header: the tile of its first tag.
INFO.TAG_TILE = {framework = 0, interface = 1, interfaz = 1, gameplay = 2, jugabilidad = 2, story = 3, historia = 3,
                 audio = 4, graphics = 5, ["gráficos"] = 5, tools = 6, herramientas = 6}
-- the mod's colour: the tile of its first tag, else one picked by its id
function INFO.Tile(m)
  local tag = string.match(Text(m, 8), "^([^\n]+)") or ""
  return INFO.TAG_TILE[string.lower(tag)] or TileOf(m.id)
end

-- the mod's native permissions (mod.toml `permissions`: memory, call, patch, command, state, hook), "" = none; asked once per mod
INFO.PERMS = {}
function INFO.Perms(m)
  local p = INFO.PERMS[m.id]
  if p == nil then
    p = Str(Call(M.PERMS, m.id))
    INFO.PERMS[m.id] = p
  end
  return p
end

-- The description a player reads: the mod's own text in the screen's language (key `<mod>.mod_description` of its
-- text.toml, 9 languages), else the manifest's `description`; only its first paragraph (long technical notes belong in
-- the mod's README.md). Returns the text, whether more was left out and the whole text.
function INFO.Description(m)
  local id = TextIdKey(m.id .. ".mod_description")
  local s = id ~= nil and Str(Call(C.TEXT_GET, id)) or ""
  if s == "" then
    s = Text(m, 0)
  end
  s = string.gsub(s, "\r", "")
  local first, rest = string.match(s, "^(.-)\n%s*\n(.*)$")
  if first ~= nil and string.find(rest, "%S") ~= nil then
    return first, true, s
  end
  return s, false, s
end

-- ---- the list and the info panel (both tabs) -----------------------------------------------------------------------------
-- A box with rounded corners from stretched flat quads: the body in three strips, a disc at each corner (all of one
-- opaque colour, so their order on the layer does not show)
function CE.RoundBox(layer, flat, disc, x, y, w, h, r)
  Quad(layer, SP(flat), x + r, y, w - 2 * r, h)
  Quad(layer, SP(flat), x, y + r, r, h - 2 * r)
  Quad(layer, SP(flat), x + w - r, y + r, r, h - 2 * r)
  for _, c in ipairs({{x, y}, {x + w - 2 * r, y}, {x, y + h - 2 * r}, {x + w - 2 * r, y + h - 2 * r}}) do
    Quad(layer, SP(disc), c[1], c[2], 2 * r, 2 * r)
  end
end

-- the navy box of the list (it ends above the button guide)
function CE.ListBox()
  CE.RoundBox("Q0", "navy", "disc_navy", G.BOX_X, G.BOX_Y, G.BOX_W, G.BOX_BOTTOM - G.BOX_Y, G.BOX_R)
end

-- a mod's icon: its mod.toml `icon`, else its initials in the neutral frame; s = side (36 a row, 96 the panel)
function CE.Icon(m, x, y, s)
  local big = s >= 60
  local a = (m.enabled or big) and 1 or 0.75
  local ic = IconOf(m)
  if ic ~= nil then
    Quad("Q1", ic[2], x, y, s, s, a, ic[1])
    return
  end
  Quad("Q1", SP(big and "iconbox_l" or "iconbox"), x, y, s, s, a)
  Txt("TC", "[CWG]" .. Initials(m) .. "[C]", x + s / 2, y + s / 2 - (big and 3 or 1), big and 1.45 or 0.5)
end

-- a group title of the «Orden de carga» list (on / off), its note at the right
function CE.HeadRow(k, text, note)
  local y = G.LIST_Y + k * G.ROW_STEP
  Quad("Q2", SP("row_head"), G.LIST_X, y, G.ROW_W - 12, G.ROW_H)
  Txt("TL", Cut(text, Fit(G.ROW_W / 2, 0.8)), G.LIST_X + 24, y + G.ROW_H / 2, 0.8)
  if note ~= nil then
    Txt("TR", Cut(note, Fit(G.ROW_W / 2 - 60, 0.62)), G.LIST_X + G.ROW_W - 40, y + G.ROW_H / 2, 0.62)
  end
end

-- One mod of the list (visible row k): its plate (dimmed when off; the cyan frame and the green arrow when focused),
-- the load number in its square (none when off), the icon, the name, «version · size · author», the warning / restart
-- marks and the state tag at the right. A click on the row = `open`; a click on the tag switches the mod.
-- `family` = show a module mod as «Parent › Module» («Orden de carga» lists them all).
function CE.ListRow(k, m, focused, row_id, tag_id, open, family)
  local x, y, w, h = G.LIST_X, G.LIST_Y + k * G.ROW_STEP, G.ROW_W, G.ROW_H
  local cy = y + h / 2
  local off = not m.enabled
  Quad("Q2", SP((off and "lplate_off" or "lplate") .. (focused and "_sel" or "")), x, y, w, h)
  if focused then
    Quad("Q1", SP("arrow_g"), x - 20, cy - 14, 18, 28)
  end
  if m.enabled and m.pos > 0 then
    Quad("Q1", SP("numbox"), x + 18, cy - 17, 34, 34)
    Txt("TC", "[CN]" .. m.pos .. "[C]", x + 35, cy, m.pos >= 100 and 0.5 or (m.pos >= 10 and 0.66 or 0.76))
  else
    Quad("Q1", SP("numbox_off"), x + 18, cy - 17, 34, 34)
  end
  CE.Icon(m, x + 70, cy - 17, 34)
  local nm = m.name ~= "" and m.name or m.id
  if family and m.family ~= nil then
    nm = m.family.name .. " › " .. (m.mname or nm)
  end
  local tx, mx = x + w - 150, x + 440
  Txt("TL", (off and "[CWG]" or "[CB]") .. Cut(nm, Fit(mx - x - 134, 0.9)) .. "[C]", x + 122, cy, 0.9)
  -- warnings and the pending restart: small marks left of the tag
  local ix = tx - 34
  if m.level >= 2 or (m.enabled and m.state == 1) then
    Quad("Q1", SP("warn_r"), ix, cy - 14, 28, 28)
    ix = ix - 32
  elseif m.level == 1 or m.nwarn > 0 then
    Quad("Q1", SP("warn_a"), ix, cy - 14, 28, 28)
    ix = ix - 32
  end
  if m.pending then
    Quad("Q1", SP("pend"), ix, cy - 14, 28, 28)
    ix = ix - 32
  end
  local meta = {}
  if m.version ~= "" then meta[#meta + 1] = "v" .. Cut(m.version, 10) end
  local sz = Size(m.size)
  if sz ~= "" then meta[#meta + 1] = sz end
  if m.author ~= "" then meta[#meta + 1] = m.author end
  Txt("TL", "[CWG]" .. Cut(table.concat(meta, "  ·  "), Fit(ix + 20 - mx, 0.62)) .. "[C]", mx, cy + 1, 0.62)
  -- the state tag: green «Activado» / grey «Desactivado»; the other states (restart, not loaded, update) in words
  local bs, bt = Badge(m)
  if bs == "pill_green" or bs == "pill_grey" then
    bt = T(m.enabled and "card_on" or "card_off")
  end
  Quad("Q1", SP(bs), tx, cy - 13, 122, 26, off and 0.9 or 1)
  Txt("TC", Cut(bt, Fit(114, 0.6)), tx + 61, cy, 0.6)
  if mouse.on and mouse.hot == tag_id then
    CE.Focus("Q1", tx, cy - 13, 122, 26, 2)
  end
  Hit(x, y, w, h, row_id, open)
  Hit(tx - 4, cy - 17, 130, 34, tag_id, function() SelectMod(m.id) StartCo(Toggle) end)
end

-- the info panel's frame: the header bar (diagonal stripes, the blue bar to the screen's edge) and the white body
function CE.PanelFrame()
  local x, y, hh = G.PANEL_X, G.PANEL_Y, G.PANEL_HEAD
  Quad("Q0", SP("hstripes"), x, y, 64, hh)
  Quad("Q0", SP("hbar_l"), x + 44, y, 40, hh)
  Quad("Q0", SP("hbar"), x + 84, y, 1920 - (x + 84), hh)
  CE.RoundBox("Q0", "white", "disc_white", x, G.PANEL_BODY_Y, G.PANEL_W, G.PANEL_BODY_H, G.PANEL_R)
end

-- the framework's parts (the names its mod.toml `provides`): a requirement on one is a requirement on the framework
function INFO.BaseParts()
  local parts = {}
  local base_mod = Screen.BaseMod()
  if base_mod ~= nil then
    for item in string.gmatch(INFO.Provides(base_mod), "[^,%s]+") do
      local n = string.match(item, "^([%w_%.%-]+)")
      if n ~= nil then
        parts[n] = true
      end
    end
  end
  return parts
end

-- the installed mod that answers requirement `name`: the mod of that id, else one whose `provides` names it
function INFO.Provider(name)
  local d = ModById(name)
  if d ~= nil then
    return d
  end
  for _, o in ipairs(Screen.Mods()) do
    for item in string.gmatch(INFO.Provides(o), "[^,%s]+") do
      local n = string.match(item, "^([%w_%.%-]+)")
      if n ~= nil and string.lower(n) == string.lower(name) then
        return o
      end
    end
  end
  return nil
end

-- «Necesita»: one row a requirement {label, state, colour; key, mod, name, ok, reason}; a framework part is the
-- framework, once and first; a minimum version as «(1.0+)»; the state: on, off or not installed; `ok` = installed,
-- on and not too old (the ModLoader's «version» warnings), else `reason` says why. Read once per mod (the list is read
-- again after every change).
function INFO.Needs(m)
  if m.needs ~= nil then
    return m.needs
  end
  local old = {}
  for line in string.gmatch(Text(m, 7), "[^\n]+") do
    local kind, other = string.match(line, "^(%a+)|([^|]*)|")
    if kind == "version" and other ~= nil then
      old[other] = true
    end
  end
  local out, seen, parts = {}, {}, INFO.BaseParts()
  for req in string.gmatch(Text(m, 2), "[^,\n]+") do
    local name, op, ver = string.match(req, "^%s*([%w_%.%-]+)%s*([<>=!~]*)%s*([^%s]*)%s*$")
    if name ~= nil then
      local own = KeyOf(name)
      local key = (own == BASE or parts[name]) and BASE or own
      if not seen[key] then
        seen[key] = true
        local d = key == BASE and Screen.BaseMod() or INFO.Provider(name)
        local short = (d ~= nil and d.name ~= "") and d.name or (key == BASE and "VR-Framework" or name)
        local label = short
        if key == own and ver ~= "" then
          label = label .. ((op == "" or op == ">=") and (" (" .. ver .. "+)") or (" (" .. op .. " " .. ver .. ")"))
        end
        local row
        if d == nil then
          row = {label, T("dep_missing"), "[CR]"}
        else
          row = {label, T(d.enabled and "st_on" or "st_off"), d.enabled and "[CG]" or "[CWG]"}
        end
        local too_old = old[name] or old[key] or old[own] or (d ~= nil and old[d.id])
        row.key, row.mod, row.name = key, d, short
        row.ok = d ~= nil and d.enabled and not too_old
        row.reason = (d == nil and T("dep_missing")) or (too_old and T("dep_old")) or ((not d.enabled) and T("st_off")) or ""
        if key == BASE then
          table.insert(out, 1, row)
        else
          out[#out + 1] = row
        end
      end
    end
  end
  m.needs = out
  return out
end

-- «Lo necesitan»: the names of the installed mods whose `requires` names this mod (its id or a name it provides)
function INFO.NeededBy(m)
  if m.needed_by ~= nil then
    return m.needed_by
  end
  local mine = {[m.id] = true}
  for item in string.gmatch(INFO.Provides(m), "[^,%s]+") do
    local n = string.match(item, "^([%w_%.%-]+)")
    if n ~= nil then
      mine[n] = true
    end
  end
  local out = {}
  for _, o in ipairs(Screen.Mods()) do
    if o ~= m then
      for req in string.gmatch(Text(o, 2), "[^,\n]+") do
        local name = string.match(req, "^%s*([%w_%.%-]+)")
        if name ~= nil and (mine[name] or mine[KeyOf(name)]) then
          out[#out + 1] = o.name ~= "" and o.name or o.id
          break
        end
      end
    end
  end
  m.needed_by = out
  return out
end

-- The info panel of mod `m` (nil = the frame alone): the header (initials, name, version), the icon and the sheet
-- (version, size, author, place in the load order, state), the description, «Necesita» (each requirement and its
-- state), «Lo necesitan» (the mods that require it), one warning line when there is one, and the hint of the mod's
-- page («Detalles», a click opens it too).
function CE.InfoPanel(m)
  CE.PanelFrame()
  if m == nil then
    return
  end
  local x, w = G.PANEL_X, G.PANEL_W
  local hc = G.PANEL_Y + G.PANEL_HEAD / 2
  local name = m.name ~= "" and m.name or m.id
  Quad("Q1", SP("night"), x + 92, hc - 17, 46, 34)
  Txt("TC", Initials(m), x + 115, hc, 0.6)
  Txt("TL", Cut(name, Fit(w - 330, 1.12)), x + 152, hc, 1.12)
  if m.version ~= "" then
    Txt("TR", "v" .. Cut(m.version, 12), x + w - 30, hc, 0.78)
  end
  local bx, by, iw = x + 30, G.PANEL_BODY_Y, w - 60
  CE.Icon(m, bx, by + 26, 96)
  local st, sc = INFO.State(m)
  if sc == "[CB]" then
    sc = "[CG]"
  end
  local sheet = {
    {T("f_version"), INFO.Value(m.version ~= "" and ("v" .. m.version) or "")},
    {T("f_size"), INFO.Value(Size(m.size))},
    {T("f_author"), m.author ~= "" and m.author or T("no_author_short")},
    {T("f_load_order"), (m.enabled and m.pos > 0) and T("pos_of", {n = m.pos, t = cnt.active}) or INFO.DASH},
    {T("f_state"), st, sc},
  }
  for i, r in ipairs(sheet) do
    local ry = by + 38 + (i - 1) * 21
    Txt("TL", "[CWG]" .. Cut(r[1], Fit(170, 0.6)) .. "[C]", bx + 120, ry, 0.6)
    Txt("TL", (r[3] or "[CB]") .. Cut(r[2], Fit(iw - 310, 0.62)) .. "[C]", bx + 300, ry, 0.62)
  end
  local y = by + 147
  Quad("Q2", SP("line"), bx, y, iw, 2)
  -- the description (its first paragraph, four lines at most)
  y = y + 23
  Txt("TL", "[CN]" .. T("f_description") .. "[C]", bx, y, 0.66)
  local desc = INFO.Description(m)
  Quad("Q2", SP("paper"), bx, y + 18, iw, 130)
  for i, l in ipairs(Wrap(desc ~= "" and desc or T("no_desc"), Fit(iw - 40, 0.7), 4)) do
    Txt("TL", (desc ~= "" and "[CB]" or "[CWG]") .. l .. "[C]", bx + 18, y + 45 + (i - 1) * 29, 0.7)
  end
  -- «Necesita»: a row a requirement and its state (three rows; more: the last says how many are left)
  y = y + 176
  Txt("TL", "[CN]" .. T("f_needs") .. "[C]", bx, y, 0.66)
  y = y + 20
  local needs = INFO.Needs(m)
  if #needs == 0 then
    Txt("TL", "[CWG]" .. T("needs_none") .. "[C]", bx + 2, y + 16, 0.68)
    y = y + 36
  end
  local MAXN = 3
  for i = 1, math.min(#needs, MAXN) do
    local d = needs[i]
    Quad("Q2", SP("paper2"), bx, y, iw, 32)
    if i == MAXN and #needs > MAXN then
      Txt("TL", "[CWG]" .. T("more_mods", {n = #needs - MAXN + 1}) .. "[C]", bx + 16, y + 16, 0.68)
    else
      Txt("TL", "[CB]" .. Cut(d[1], Fit(iw - 230, 0.7)) .. "[C]", bx + 16, y + 16, 0.7)
      Txt("TR", d[3] .. Cut(d[2], Fit(190, 0.6)) .. "[C]", bx + iw - 12, y + 16, 0.6)
    end
    y = y + 36
  end
  -- «Lo necesitan»: one line with the names
  y = y + 14
  Txt("TL", "[CN]" .. T("f_needed_by") .. "[C]", bx, y, 0.66)
  local users = INFO.NeededBy(m)
  if #users == 0 then
    Txt("TL", "[CWG]" .. T("needed_by_none") .. "[C]", bx, y + 35, 0.7)
  else
    Txt("TL", "[CB]" .. Cut(table.concat(users, "  ·  "), Fit(iw, 0.7)) .. "[C]", bx, y + 35, 0.7)
  end
  -- one warning (not loaded, incompatible, versions, shared files) above the hint, when there is one
  local hint_y = by + G.PANEL_BODY_H - 30
  local warn = nil
  if m.enabled and m.state == 1 then
    warn = {true, T("state_skip", {r = Text(m, 1)})}
  else
    warn = Warnings(m)[1]
  end
  if warn ~= nil and y + 70 < hint_y then
    Quad("Q1", SP(warn[1] and "warn_r" or "warn_a"), bx, y + 70 - 13, 26, 26)
    Txt("TL", (warn[1] and "[CR]" or "[CY]") .. Cut(warn[2], Fit(iw - 40, 0.62)) .. "[C]", bx + 36, y + 70, 0.62)
  end
  -- the mod's page (information, problems, conflicts, settings): Start / Alt, or a click on the hint
  Txt("TR", "[CWG]" .. K.START .. " " .. Cut(T("panel_details"), Fit(300, 0.62)) .. "[C]", x + w - 30, hint_y, 0.62)
  Hit(x + w - 380, hint_y - 18, 360, 36, "pdetails", function()
    if ui.tab == 1 then
      ui.zone = "grid"
    end
    OpenDetails()
  end)
end

local function DrawOrder()
  local rows = OrderRows()
  ui.osel = math.max(1, math.min(ui.osel, #rows))
  if rows[ui.osel].head then
    ui.osel = ui.osel < #rows and ui.osel + 1 or ui.osel - 1
    ui.osel = math.max(1, ui.osel)
  end
  if ui.osel < ui.otop then
    ui.otop = ui.osel
  elseif ui.osel >= ui.otop + G.LIST_ROWS then
    ui.otop = ui.osel - G.LIST_ROWS + 1
  end
  ui.otop = math.max(1, math.min(ui.otop, math.max(1, #rows - G.LIST_ROWS + 1)))
  CE.ListBox()
  for k = 0, G.LIST_ROWS - 1 do
    local n = ui.otop + k
    local r = rows[n]
    if r ~= nil then
      if r.head then
        CE.HeadRow(k, r.text, r.first and T("order_sub") or nil)
      else
        local m = r.m
        CE.ListRow(k, m, n == ui.osel and ui.popup == nil, "orow" .. n, "otag" .. n,
                   function() ui.osel = n SelectMod(m.id) OpenDetails() end, true)
      end
    end
  end
  DrawScrollbar(#rows, ui.otop - 1, G.LIST_ROWS, G.SB_X, G.LIST_Y, G.LIST_ROWS * G.ROW_STEP - (G.ROW_STEP - G.ROW_H), function(f)
    ui.otop = f + 1
    ui.osel = math.max(ui.otop, math.min(ui.osel, ui.otop + G.LIST_ROWS - 1))
  end)
  -- the panel: the selected mod
  local r = rows[ui.osel]
  CE.InfoPanel(r ~= nil and r.m or nil)
end

-- for 100_mods_screen.lua and the files after this one
Screen.DrawOrder = DrawOrder
