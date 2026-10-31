-- mods_menu (VR-Framework): the «Mods» screen, a mod's page, «Novedades», «Problemas» / «Conflictos» (the VR-Framework
-- report), the view tabs and the «¿Quién lo toca?» opener. Runs after 100_mods_screen.lua in the same VM and takes the
-- names it shares from VRFW_ModsScreen. No engine call at load time.
local Screen = VRFW_ModsScreen
if Screen == nil then
  return
end
local C, Call, Cut, Fit, G, Hit, Int = Screen.C, Screen.Call, Screen.Cut, Screen.Fit, Screen.G, Screen.Hit, Screen.Int
local K, M, Quad, RV, SE_OK, SP = Screen.K, Screen.M, Screen.Quad, Screen.RV, Screen.SE_OK, Screen.SP
local StartCo, Str, T, Txt, Wrap, mouse = Screen.StartCo, Screen.Str, Screen.T, Screen.Txt, Screen.Wrap, Screen.mouse
local ui = Screen.ui

-- ---- «Novedades»: the mod's changelog summary (its title and every point), scrolled with up / down
function RV.NewsLines(m)
  local out = {}
  for _, n in ipairs(RV.Notes(m).notes) do
    for i, l in ipairs(Wrap(n, Fit(G.WIN_W - 120, 0.74), 8)) do
      out[#out + 1] = {first = i == 1, text = l}
    end
  end
  return out
end

function RV.DrawNews(m)
  local p = ui.popup
  local r = RV.Notes(m)
  local x, w = G.WIN_X + 40, G.WIN_W - 80
  local y = RV.BodyY() + 34
  Txt("PL", "[CN]" .. Cut(r.title ~= "" and r.title or T("btn_news"), Fit(w - 200, 0.86)) .. "[C]", x, y, 0.86)
  local lines = RV.NewsLines(m)
  if #lines == 0 then
    Txt("PL", "[CWG]" .. T("news_none") .. "[C]", x, y + 50, 0.78)
    return
  end
  p.top = math.max(0, math.min(p.top or 0, #lines - RV.NEWS_ROWS))
  for i = 1, math.min(RV.NEWS_ROWS, #lines - p.top) do
    local l = lines[p.top + i]
    local ly = y + 46 + (i - 1) * 32
    if l.first then
      Txt("PL", "[CN]›[C]", x, ly, 0.74)
    end
    Txt("PL", "[CB]" .. l.text .. "[C]", x + 26, ly, 0.74)
  end
  if #lines > RV.NEWS_ROWS then
    Txt("PR", "[CWG]" .. T("report_rows", {n = p.top + 1, c = math.min(p.top + RV.NEWS_ROWS, #lines), t = #lines}) .. "[C]",
        G.WIN_X + G.WIN_W - 40, y, 0.62)
  end
end

-- the mod has report entries `native_update` (a code site not found on an unknown game build)
function M.NeedsUpdate(id)
  for _, e in ipairs(RV.Of(id).problems) do
    if e.code == "native_update" then
      return true
    end
  end
  return false
end

-- the group of an entry: the core's category (6th extra return of REPORT_ROW), else from the severity (an older core)
function RV.Cat(e)
  if e.cat ~= "" then
    return e.cat
  end
  if e.code == "conflict" then
    return "conflict"
  end
  return e.sev == "error" and "error" or (e.sev == "warn" and "warning" or "info")
end

-- the schema line(s) an entry's message asks for (the core writes "must start with `schema = ...`"), else nil
function RV.Wanted(e)
  local w = string.match(e.msg, "must start with `(.+)`")
  if w == nil then
    return nil
  end
  return (string.gsub(w, "` or `", " / "))
end

-- the header of a code's group: its row in the player's language, else the core's English hint, else the code.
-- `{s}` = the schema line(s) the group's files need (`wanted`), else the generic form
function RV.Head(e, wanted)
  local k = "rc_" .. e.code
  local s = T(k)
  if s ~= k then
    local w = wanted or 'schema = "VRFW.<type>/<version>"'
    return (string.gsub(s, "{s}", function() return w end))
  end
  return e.hint ~= "" and (e.code .. ": " .. e.hint) or e.code
end

-- the distinct schema lines the entries of one group (category + code) ask for, joined with " / "; nil when none
function RV.GroupWanted(items, cat, code)
  local seen, list = {}, {}
  for _, x in ipairs(items) do
    if x.cat == cat and x.code == code then
      local w = RV.Wanted(x)
      if w ~= nil and not seen[w] then
        seen[w] = true
        list[#list + 1] = w
      end
    end
  end
  return #list > 0 and table.concat(list, " / ") or nil
end

function RV.Of(id)
  local r = RV.cache[id]
  if r ~= nil then
    return r
  end
  r = {problems = {}, conflicts = {}, np = 0}
  local items = {}
  local n = math.min(Int(Call(M.REPORT_COUNT, id)), RV.MAX)
  for i = 0, n - 1 do
    local sev, ty, code, loc, msg, _, key, eid, win, others, cat, hint = Call(M.REPORT_ROW, i, id)
    local e = {sev = Str(sev), ty = Str(ty), code = Str(code), loc = Str(loc), msg = Str(msg), key = Str(key), id = Str(eid),
               win = Str(win), others = Str(others), cat = Str(cat), hint = Str(hint)}
    e.cat = RV.Cat(e)
    if e.cat == "conflict" then
      r.conflicts[#r.conflicts + 1] = e
    elseif RV.ORDER[e.cat] ~= nil then
      items[#items + 1] = e
    end
  end
  table.sort(items, function(a, b)
    if a.cat ~= b.cat then
      return RV.ORDER[a.cat] < RV.ORDER[b.cat]
    end
    if a.code ~= b.code then
      return a.code < b.code
    end
    if a.loc ~= b.loc then
      return a.loc < b.loc
    end
    return a.msg < b.msg
  end)
  local last = nil
  for _, e in ipairs(items) do
    if e.cat .. "/" .. e.code ~= last then
      last = e.cat .. "/" .. e.code
      r.problems[#r.problems + 1] = {hdr = true, cat = e.cat, sev = e.sev, text = RV.Head(e, RV.GroupWanted(items, e.cat, e.code))}
    end
    r.problems[#r.problems + 1] = e
  end
  r.np = #items
  table.sort(r.conflicts, function(a, b)
    if a.id ~= b.id then
      return a.id < b.id
    end
    return a.loc < b.loc
  end)
  RV.cache[id] = r
  return r
end

-- «Cambios en caliente: telop en vivo · table al reiniciar» (CMND_VRFW_REPORT_RELOAD, the reload mode of each type
-- the mod has content of); "" when the core gives none
function RV.Reload(id)
  local ck = "reload:" .. id
  if RV.cache[ck] == nil then
    local parts = {}
    for ty, mode in string.gmatch(Str(Call(M.REPORT_RELOAD, id)), "([%w_]+)=([%w_]+)") do
      parts[#parts + 1] = ty .. " " .. T("rl_" .. mode)
    end
    RV.cache[ck] = #parts > 0 and T("rp_reload", {r = table.concat(parts, " · ")}) or ""
  end
  return RV.cache[ck]
end

-- the label of view `v` in the page's tab row: its name and count («Módulos 6/8», «Problemas 3» with the count in red
-- when there are problems)
function RV.Label(m, v, sel, units)
  local name, n, red = "", nil, false
  if v == "info" then
    name = T("page_info")
  elseif v == "modules" then
    name, n = T("tab_modules"), RV.ModulesOn(m) .. "/" .. #RV.ModuleRows(m)
  elseif v == "problems" then
    name, n = T("tab_problems"), RV.Of(m.id).np
    red = n > 0
  elseif v == "conflicts" then
    name, n = T("tab_conflicts"), #RV.Of(m.id).conflicts
  elseif v == "settings" then
    name, n = T("tab_settings"), #RV.SetRows(m)
  else
    name = T("btn_news")
  end
  local base = sel and "" or "[CWG]"
  local out = base .. Cut(name, units - (n ~= nil and 6 or 0)) .. (sel and "" or "[C]")
  if n ~= nil then
    out = out .. " " .. (red and "[CR]" or base) .. tostring(n) .. ((red or not sel) and "[C]" or "")
  end
  return out
end

-- the row of view tabs under the header band (L2 / R2 like the screen's tabs, or a click)
function RV.Tabs(m)
  local views = RV.Views(m)
  local nv = #views
  local y, h = G.WIN_Y + G.BAND_H, G.VTABS_H
  Quad("P0", SP("tabbar"), G.WIN_X, y, G.WIN_W, h)
  local gx = 60
  local step = math.floor((G.WIN_W - 2 * gx) / nv)
  local w = math.min(260, step - 8)
  local cur = RV.View()
  for k, v in ipairs(views) do
    local x = G.WIN_X + gx + (k - 1) * step + (step - w) / 2
    local sel = v == cur
    local hot = mouse.on and mouse.hot == "view" .. k and not sel
    if sel or hot then
      Quad("P1", SP(sel and "tab_sel" or "tab_hot"), x, y + 6, w, h - 12)
    end
    Txt("PC", RV.Label(m, v, sel, Fit(w - 16, 0.7)), x + w / 2, y + h / 2, 0.7)
    Hit(x, y, w, h, "view" .. k, function()
      if RV.View() ~= v then
        RV.Go(v)
      end
    end)
  end
  Txt("PL", K.L2, G.WIN_X + 14, y + h / 2, 0.9)
  Txt("PR", K.R2, G.WIN_X + G.WIN_W - 14, y + h / 2, 0.9)
end

-- «Problemas» / «Conflictos»: one row per entry (file:line, then the message), a header row per kind of problem in
-- the player's language (what it is, how to fix it); a conflict says who wins and the other mods; never an empty page
function RV.Draw(m, which)
  local r = RV.Of(m.id)
  local list = which == 2 and r.problems or r.conflicts
  local px, py = G.WIN_X + 36, RV.BodyY() + 34
  local foot = py + RV.ROWS * 36
  local rl = which == 2 and RV.Reload(m.id) or ""
  if #list == 0 then
    Txt("PL", "[CN]" .. T(which == 2 and "report_no_problems" or "report_no_conflicts") .. "[C]", px, py, 0.8)
    if which == 3 then
      Txt("PL", "[CWG]" .. K.R3 .. " " .. Cut(T("who_hint"), Fit(G.WIN_W - 120, 0.62)) .. "[C]", px, foot, 0.62)
    end
    if rl ~= "" then
      Txt("PL", "[CWG]" .. Cut(rl, Fit(G.WIN_W - 80, 0.62)) .. "[C]", px, foot, 0.62)
    end
    return
  end
  local top = math.max(0, math.min(ui.popup.top or 0, #list - RV.ROWS))
  ui.popup.top = top
  local last = ""
  for i = 1, math.min(RV.ROWS, #list - top) do
    local e = list[top + i]
    local y = py + (i - 1) * 36
    if e.hdr then
      -- the kind of problem, in the player's language
      last = ""
      Txt("PL", (e.sev == "error" and "[CR]" or "[CY]") .. Cut(e.text, Fit(G.WIN_W - 80, 0.66)) .. "[C]", px, y, 0.66)
    else
      local file = string.match(e.loc, "^(.-):%d+$") or e.loc
      local where = file == last and ("   " .. string.sub(e.loc, #file + 1)) or e.loc
      last = file
      local msg = e.msg
      if which == 3 then
        -- who overrode what: the winner and the other mods' claims
        local who = e.win ~= "" and T("rp_winner", {w = e.win}) or ""
        if e.others ~= "" then
          who = who .. (who ~= "" and " · " or "") .. T("rp_others", {o = e.others})
        end
        if who ~= "" then
          msg = msg .. "  (" .. who .. ")"
        end
      end
      if which == 3 and RV.WhoId(e) ~= "" then
        -- a click on a conflict: who touches its id («¿Quién lo toca?», the same explorer as `vrfw who`)
        Hit(px, y - 18, G.WIN_W - 72, 36, "who" .. (top + i), function() RV.OpenWho(RV.WhoId(e)) end)
        if mouse.on and mouse.hot == "who" .. (top + i) then
          Quad("P1", SP("row_sel"), px - 8, y - 18, G.WIN_W - 72, 36, 0.35)
        end
      end
      Quad("P1", SP(e.sev == "error" and "warn_r" or "warn_a"), px, y - 16, 32, 32)
      Txt("PL", "[CN]" .. Cut(where, Fit(520, 0.66)) .. "[C]", px + 44, y, 0.66)
      Txt("PL", (e.sev == "error" and "[CR]" or "[CB]") .. Cut("[" .. e.ty .. "] " .. msg, Fit(G.WIN_W - 680, 0.66)) .. "[C]", px + 580, y, 0.66)
    end
  end
  if #list > RV.ROWS then
    Txt("PR", "[CWG]" .. T("report_rows", {n = top + 1, c = math.min(top + RV.ROWS, #list), t = #list}) .. "[C]", G.WIN_X + G.WIN_W - 40, foot, 0.62)
  end
  if #list >= RV.MAX then
    Txt("PL", "[CWG]" .. T("report_more") .. "[C]", px, foot, 0.62)
  elseif which == 3 then
    Txt("PL", "[CWG]" .. K.R3 .. " " .. Cut(T("who_hint"), Fit(G.WIN_W - 480, 0.62)) .. "[C]", px, foot, 0.62)
  elseif rl ~= "" then
    Txt("PL", "[CWG]" .. Cut(rl, Fit(G.WIN_W - 400, 0.62)) .. "[C]", px, foot, 0.62)
  end
end

-- ---- «¿Quién lo toca?»: the conflict explorer of `vrfw who` in the panel ------------------------------------
-- From «Conflictos»: R3 (the first conflict on the page, else an empty search) or a click on a conflict opens a list
-- page with the id in its search box (the top row, like the other tabs): every mod that touches the id, in load
-- order, one header per mod (its load position; «gana» on the winner), its lines under it (file:line on the right;
-- a line that only refers to the id is grey), then the report's entries about it. The search box takes another id.
-- One function behind it and `vrfw who`: vr_core::diagnose::who_in (CMND_VRFW_REPORT_WHO / _ROW).

-- the id a conflict entry is about ("" = none)
function RV.WhoId(e)
  if e.id ~= nil and e.id ~= "" then
    return e.id
  end
  return e.key or ""
end

function RV.OpenWho(id)
  funcLuaCommand(C.SE, SE_OK)
  StartCo(function() RV.WhoFlow(id) end)
end
