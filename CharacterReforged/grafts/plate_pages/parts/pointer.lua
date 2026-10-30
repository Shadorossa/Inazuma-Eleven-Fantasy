-- Player page block (plate_pages.lua): the mouse / free cursor zones
  -- ---- pointer (mouse / VR free cursor; docs/game/ui/mouse-support.md §5, EVT_PointerNew) ----------------------
  -- Our own drawn controls of the page get Lua zones (screen px, y down; the same numbers the layout / this block
  -- place them with): the 8 page dots (slot s: x 1321 + 28 (s - 1) .. + 32, the dots row y 915) and the Q / E glyphs
  -- beside them (if_plate_row_build.py: x 1281 / 1553) = go to that page / one page back / on, through the Q/E path of
  -- the menu that owns the page index (EVT_PPG_PointerPage: banks first, then the team dock / formation parents; with
  -- none, the plate's own step); on Pasivas the sub-page dots (G.PSUB_DOT_X) and the R3 glyph after them (x 1714)
  -- = that sub-page / the next one; on PERFIL the «R3 Cambiar forma» hint (x 1706.., y 893..947) = next form.
  -- No zone while the page is hidden, over a passive_config session (its own picker) or for hidden controls; a click
  -- on no zone does nothing; the dots have no keyboard focus, so hovering them changes nothing.
  --@lib evt_menu_kit.lua#Pointer
  G.PTR_DOT = {x0 = 1321, dx = 28, y = 895, h = 50}
  G.PTR_Q, G.PTR_E = {1258, 893, 62, 54}, {1551, 893, 56, 54}
  G.PTR_R3 = {1708, 893, 44, 54}
  G.PTR_FORM = {1706, 893, 214, 54}     -- round 15: the hint on the dots row from x 1713 (layout)
  G.BANKS = {@crc:chara_bank_menu_for_search@, @crc:chara_bank_menu@}
  function G.PtrGo(target, dir)
    local function Lc(...)
      local ok, v = pcall(funcLuaCommand, ...)
      return ok and v or nil
    end
    if type(target) == "number" then
      G.gotoT = 3                          -- the plate's own step too (a bank in its list view steps the plate)
      if VRFW_PlayerPages ~= nil then
        VRFW_PlayerPages.Goto(target)
      end
    end
    for pass = 1, 2 do
      for _, m in ipairs(pass == 1 and G.BANKS or G.PARENTS) do
        if Lc(@crc:CMND_IS_EXIST_MENU@, m) == true then
          Lc(830228314, m, "EVT_PPG_PointerPage", target, dir, pass == 1)
          Lc(C.LOG, "EVT_PPG pointer page", string.format("%08X", m), tostring(target), dir)
          return
        end
      end
    end
    pcall(dir > 0 and SetPersonalPlateNextPage or SetPersonalPlatePrevPage)
  end
  function G.PtrForm()
    local M = EVT_PPM
    if G.ptype == G.HIPER_TYPE then        -- 2026-10-13: the Hiper page, Normal / the shown aura's form
      G.HiperToggle("click")
      return
    end
    if G.ptype == EVT_PPG_STATS_TYPE then  -- 2026-10-13: ATRIBUTOS, Normal / Miximax
      G.MxToggle("click")
      return
    end
    if G.ViewOffered() then                -- Formación: the hint is «Ver apariencia»
      pcall(M.OpenView, "click")
      return
    end
    if type(M) ~= "table" or M.phase ~= "ready" or EVT_PPM_PAGE_FORMS ~= true or type(M.forms) ~= "table"
        or #M.forms <= 1 or type(M.Fresh) ~= "function" then
      return
    end
    M.last = M.tick or 0
    M.fidx = (M.fidx or 1) % #M.forms + 1
    pcall(funcLuaCommand, @crc:CMND_SND_PLAY_SE@, 2629173176)   -- sy0009, as R3
    M.Fresh()
  end
  function G.Pointer()
    if G.gotoT ~= nil then
      G.gotoT = G.gotoT - 1
      if G.gotoT <= 0 then
        G.gotoT = nil
        if VRFW_PlayerPages ~= nil then
          VRFW_PlayerPages.Goto(nil)
        end
      end
    end
    local up = On() and G.ptype ~= nil and Exists(G.STATUS) and Cmd(C.IS_VIS, G.STATUS, 0) == true
      and not (type(UTIL_PPC) == "table" and UTIL_PPC.co ~= nil)
    if not up then
      G.ptrUp = false
      return
    end
    G.ptr = G.ptr or EVT_PointerNew()
    local P = G.ptr
    if not G.ptrUp then
      G.ptrUp = true
      P.Reset()
    end
    P.Begin()
    local D = G.PTR_DOT
    local pages = G.SlotPages()
    for s = 1, G.DOTS_MAX do
      if pages[s] ~= nil then
        P.Rect(D.x0 + D.dx * (s - 1) + 2, D.y, D.dx, D.h, s)
      end
    end
    P.Rect(G.PTR_Q[1], G.PTR_Q[2], G.PTR_Q[3], G.PTR_Q[4], "q")
    P.Rect(G.PTR_E[1], G.PTR_E[2], G.PTR_E[3], G.PTR_E[4], "e")
    local psub = G.ptype == 2 and not G.InOffice()
    if psub then
      for k = 2, 1 + G.PSUB_N do
        P.Rect(G.PSUB_DOT_X[k] + 2, D.y, D.dx, D.h, "p" .. (k - 2))
      end
      P.Rect(G.PTR_R3[1], G.PTR_R3[2], G.PTR_R3[3], G.PTR_R3[4], "r3")
    end
    local forms = type(EVT_PPM) == "table" and type(EVT_PPM.forms) == "table" and #EVT_PPM.forms or 0
    if G.ptype == EVT_PPG_DESC_TYPE and not G.InOffice() then
      local b = G.fbBox
      if G.ViewOffered() then
        P.Rect(G.PTR_FORM[1], G.PTR_FORM[2], G.PTR_FORM[3], G.PTR_FORM[4], "form")
      elseif forms > 1 and b ~= nil then
        P.Rect(b[1], b[2], b[3], b[4], "form")   -- 2026-10-12: the form badge (tiles + RS key)
      end
    elseif G.ptype == G.HIPER_TYPE and not G.InOffice() and G.fbBox ~= nil
        and (G.hiperTgt ~= nil or G.hiperDouble == true) then
      local b = G.fbBox
      P.Rect(b[1], b[2], b[3], b[4], "form")     -- 2026-10-13: the Hiper page's form badge
    elseif G.ptype == EVT_PPG_STATS_TYPE and not G.InOffice() and G.fbBox ~= nil and G.MxAvail() then
      local b = G.fbBox
      P.Rect(b[1], b[2], b[3], b[4], "form")     -- 2026-10-13: ATRIBUTOS' Normal / Miximax badge
    end
    local ev = P.Poll()
    local c = ev.click
    if c == nil then
      return
    end
    if type(c) == "number" then
      local cur = G.Slot(G.ptype)
      local target = pages[c]
      if cur ~= nil and c ~= cur and target ~= nil then
        G.PtrGo(target, c > cur and 1 or -1)
      end
    elseif c == "q" or c == "e" then
      G.PtrGo(nil, c == "e" and 1 or -1)
    elseif c == "r3" or string.sub(c, 1, 1) == "p" then
      local n = c == "r3" and (G.psub + 1) % G.PSUB_N or tonumber(string.sub(c, 2))
      if n ~= nil and n ~= G.psub then
        G.psub = n
        G.plast = G.ptick or 0
        pcall(funcLuaCommand, @crc:CMND_SND_PLAY_SE@, 2500047763)
      end
    elseif c == "form" then
      G.PtrForm()
    end
  end
