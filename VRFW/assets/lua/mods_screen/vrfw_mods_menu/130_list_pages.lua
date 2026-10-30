-- mods_menu (VR-Framework): the «Mods» screen, the list pages in the content area («¿Quién lo toca?») and the page
-- helpers of CE. Runs after 100_mods_screen.lua in the same VM and takes the names it shares from VRFW_ModsScreen. No
-- engine call at load time.
local Screen = VRFW_ModsScreen
if Screen == nil then
  return
end
local C, CE, Call, Cut, Draw, DrawPanel = Screen.C, Screen.CE, Screen.Call, Screen.Cut, Screen.Draw, Screen.DrawPanel
local DrawScrollbar, Fit, G, Hit, Int = Screen.DrawScrollbar, Screen.Fit, Screen.G, Screen.Hit, Screen.Int
local Keyboard, M, ModById, Quad, RT_SEARCH = Screen.Keyboard, Screen.M, Screen.ModById, Screen.Quad, Screen.RT_SEARCH
local RV, SE_NG, SP, Str, T, Txt = Screen.RV, Screen.SE_NG, Screen.SP, Screen.Str, Screen.T, Screen.Txt
local mouse, ui = Screen.mouse, Screen.ui

-- ---- list pages -----------------------------------------------------------------------------------------------------------
-- A page is drawn in the content area and waits for the player: the flow runs as the screen's coroutine and waits for
-- `ui.page.pick` / `ui.page.back` / `ui.page.act`.
local function WaitPage(p)
  p.pick, p.back, p.act = nil, false, nil
  ui.page = p
  Draw()
  while p.pick == nil and not p.back and p.act == nil do
    coroutine.yield()
  end
  return p.pick, p.back, p.act
end

-- a list page: `items` = {{label, sub, off, head}}; opt.search = a function(query) that refills the list (nil = none),
-- opt.preview(item) = the panel's lines for the selected item, opt.info = lines under them. Returns the picked row and
-- its item, or nil (B)
local function ListPage(title, help, items, opt)
  opt = opt or {}
  local p = {kind = "list", title = title, help = help, items = items, sel = opt.sel or 1, top = 1, search = opt.search,
             query = opt.query or "", total = opt.total, preview = opt.preview, zone = "list", info = opt.info}
  opt.p = p
  while true do
    local pick, back, act = WaitPage(p)
    if back then
      return nil
    end
    if act == "search" and p.search ~= nil then
      local q = Keyboard(p.query, "kb_search", RT_SEARCH, 24)
      if q ~= nil then
        p.query = q
        p.items, p.total = p.search(q)
        p.sel, p.top = 1, 1
      end
    elseif pick ~= nil then
      local it = p.items[pick]
      if it ~= nil and not it.off then
        return pick, it
      end
      funcLuaCommand(C.SE, SE_NG)
    end
  end
end

local function DrawList(p)
  local LW = G.ROW_W
  local rows = G.LIST_ROWS
  local y0 = G.LIST_Y              -- its search is in the top row (CE.DrawPageRow)
  p.sel = math.max(1, math.min(p.sel, math.max(1, #p.items)))
  if p.sel < p.top then
    p.top = p.sel
  elseif p.sel >= p.top + rows then
    p.top = p.sel - rows + 1
  end
  p.top = math.max(1, math.min(p.top, math.max(1, #p.items - rows + 1)))
  CE.ListBox()
  if #p.items == 0 then
    Quad("Q2", SP("row_off"), G.LIST_X, y0, LW, G.ROW_H)
    Txt("TL", "[CWG]" .. T("list_empty") .. "[C]", G.LIST_X + 28, y0 + G.ROW_H / 2, 0.85)
  end
  for k = 0, rows - 1 do
    local n = p.top + k
    local it = p.items[n]
    if it ~= nil then
      local y = y0 + k * G.ROW_STEP
      local sel = n == p.sel and p.zone == "list"
      if it.head then
        Quad("Q2", SP("row_head"), G.LIST_X, y, LW, G.ROW_H)
        Txt("TL", Cut(it.label, math.min(64, Fit(LW - 56, 0.8))), G.LIST_X + 28, y + G.ROW_H / 2, 0.8)
      else
        Quad("Q2", SP(sel and "row_sel" or (it.off and "row_off" or "row")), G.LIST_X, y, LW, G.ROW_H)
        if sel then
          CE.Focus("Q1", G.LIST_X, y, LW, G.ROW_H, 3)   -- the cursor of every list
        end
        local lx = G.LIST_X + 28
        Txt("TL", (it.off and "[CWG]" or "[CB]") .. Cut(it.label, math.min(it.sub and 44 or 64, Fit(LW - (lx - G.LIST_X) - (it.sub and 230 or 30), 0.84))) .. "[C]", lx, y + G.ROW_H / 2, 0.84)
        if it.sub ~= nil and it.sub ~= "" then
          Txt("TR", "[CWG]" .. Cut(it.sub, 30) .. "[C]", G.LIST_X + LW - 24, y + G.ROW_H / 2, 0.72)
        end
        Hit(G.LIST_X, y, LW, G.ROW_H, "prow" .. n, function() p.sel = n p.zone = "list" p.pick = n end)
      end
    end
  end
  DrawScrollbar(#p.items, p.top - 1, rows, G.SB_X, y0, rows * G.ROW_STEP - (G.ROW_STEP - G.ROW_H), function(f)
    p.top = f + 1
    p.sel = math.max(p.top, math.min(p.sel, p.top + rows - 1))
  end)
  -- the panel: help + preview of the selected entry
  local lines = {{t = p.help or "", c = "[CWG]", max = 4}, {gap = 10}}
  local it = p.items[p.sel]
  if it ~= nil and p.preview ~= nil then
    for _, l in ipairs(p.preview(it)) do
      lines[#lines + 1] = l
    end
  end
  if p.info ~= nil then
    for _, l in ipairs(p.info) do
      lines[#lines + 1] = l
    end
  end
  DrawPanel(p.title, lines)
end

local function DrawPage()
  DrawList(ui.page)
end

-- «¿Quién lo toca?» (RV.OpenWho): the rows of id `id` for a list page -> items, places, winner
function RV.WhoItems(id)
  local items, places = {}, 0
  if id == nil or id == "" then
    return items, 0, ""
  end
  local n, win = Call(M.REPORT_WHO, id)
  n, win = Int(n), Str(win)
  local last, rep = nil, false
  for i = 0, n - 1 do
    local mid, order, ty, place, text, kind, wins = Call(M.REPORT_WHO_ROW, i)
    mid, kind = Str(mid), Str(kind)
    if kind == "report" and not rep then
      rep, last = true, nil
      items[#items + 1] = {head = true, label = T("who_report")}
    end
    if mid ~= last and kind ~= "report" then
      last = mid
      local m = ModById(mid)
      local name = (m ~= nil and m.name ~= nil and m.name ~= "") and m.name or mid
      local pos = Int(order) > 0 and T("who_order", {n = Int(order)}) or T("who_not_loaded")
      items[#items + 1] = {head = true, label = (mid == win and "[CY]" or "") .. name .. "  ·  " .. pos ..
                           (mid == win and ("  ·  " .. T("rp_winner", {w = name})) or "") .. (mid == win and "[C]" or "")}
    end
    places = places + (kind == "report" and 0 or 1)
    items[#items + 1] = {label = "[" .. Str(ty) .. "] " .. Str(text), sub = Str(place), off = kind == "refers",
                         full = Str(text), place = Str(place), mod = mid, kind = kind, win = wins == true}
  end
  return items, places, win
end

-- the explorer's list page; B returns to the mod page on the view it came from
function RV.WhoFlow(id)
  local saved = ui.popup
  ui.popup = nil
  local opt = {query = id or ""}
  local function fill(q)
    local items, places, win = RV.WhoItems(q)
    local info = {{gap = 10}, {t = q == "" and T("who_empty") or (win ~= "" and T("who_winner", {w = win}) or
                  (places > 0 and T("who_no_winner") or T("who_nobody", {i = q}))), c = "[CN]", max = 3}}
    opt.info = info
    if opt.p ~= nil then
      opt.p.info = info
    end
    return items, places
  end
  local items
  items, opt.total = fill(opt.query)
  opt.search = fill
  opt.preview = function(it)
    if it.head then
      return {}
    end
    return {{t = it.place or "", c = "[CWG]", max = 2}, {t = it.full or "", c = "[CB]", max = 5},
            {t = T("who_kind_" .. (it.kind or "defines")), c = "[CWG]", max = 2}}
  end
  while true do
    local k = ListPage(T("who_title"), T("who_help"), items, opt)
    if k == nil then
      break
    end
    -- a row picked: nothing to do on it; the list stays (its search, its cursor)
    items, opt.query, opt.total, opt.sel = opt.p.items, opt.p.query, opt.p.total, opt.p.sel
  end
  ui.page = nil
  ui.popup = saved
  Draw()
end

-- The header adaptation: G is laid out for the retail header; a mod that restyles the header sets the
-- global VRFW_MM_LAYOUT = {top_dy = n} in a Lua patch of this script (e.g. -55). Applied in OnInit from the retail values, so any order of the patches and any
-- number of visits give the same layout. top_dy is clamped to ±160 px.
function CE.ApplyLayout()
  if G.BASE_Y == nil then
    G.BASE_Y = {}
    for _, k in ipairs(G.SHIFT_Y) do
      G.BASE_Y[k] = G[k]
    end
  end
  local dy = type(VRFW_MM_LAYOUT) == "table" and tonumber(VRFW_MM_LAYOUT.top_dy) or 0
  dy = math.max(-160, math.min(160, dy or 0))
  for _, k in ipairs(G.SHIFT_Y) do
    G[k] = G.BASE_Y[k] + dy
  end
  -- the rows that fit between the list's top and the box's bottom (fixed: the button guide does not move)
  G.LIST_ROWS = math.max(4, math.floor((G.BOX_BOTTOM - G.BOX_PAD - G.LIST_Y + (G.ROW_STEP - G.ROW_H)) / G.ROW_STEP))
  G.TOP_DY = dy
  return dy
end

-- the search of a list page for CE.RowSearch, or nil (none)
function CE.PageSearch(p)
  if p.search == nil then
    return nil
  end
  local id = "psearch"
  return {on = true, query = p.query, hint = "search_hint_list", count = T("list_count", {n = #p.items, t = p.total or #p.items}),
          foc = p.zone == "search" or mouse.hot == id, id = id, act = function() p.act = "search" end}
end

-- the page's own part of the top row: its search box (the count inside), in the place of «Instalados»' search
function CE.DrawPageRow(p)
  local s = CE.PageSearch(p)
  if s ~= nil then
    CE.RowSearch(s)
  end
end

-- for 100_mods_screen.lua and the files after this one
Screen.DrawPage = DrawPage
