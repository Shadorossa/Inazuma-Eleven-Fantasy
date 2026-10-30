-- ===== EVT plate_pages bank BEGIN =====
-- Bank stats view (Nacho 2026-10-06): Banco -> «Mostrar estadísticas» shows the player page over the bank, and the
-- lineup on the right (formation frame, the 19 cards, blanks, the formation name bar «3-5-2 ...», the team-dock
-- change guide «02», new / synergy badges) stayed visible behind the page and around the 3D model. Those are THE
-- BANK'S OWN layers (chara_bank_menu's setting lists them), so the bank hides them itself while personal_plate_menu
-- exists, records every instance it hid and shows exactly those again as soon as the plate is gone. Nothing of
-- another menu is touched; the bank steps while the plate is over it, and when the bank closes its layers go with it.
-- Layer visibility only. EVT_PPB_OFF = true turns it off. loader.log «EVT_PPB hide n» / «EVT_PPB restore n».
-- No engine call while the chunk loads.
EVT_PPB = EVT_PPB or {hid = {}, on = false}
do
  local B = EVT_PPB
  B.PLATE_MENU = 1427722143                         -- personal_plate_menu
  B.PAGE = 878737202                                -- team11_01_personal_plate (in personal_plate_menu)
  B.LAYERS = {@crc:team14_03_formation_frame@, @crc:team00_01_chara_card_for_soccer@,
    @crc:team00_01_chara_card_for_leader@, @crc:team00_01_chara_card_for_move@, @crc:team00_01_p1_chara_card_blank@,
    @crc:team00_01_p1_chara_card_blank_for_leader@, @crc:soccer11_12_formation_button@,
    @crc:soccer11_19_formation_team_build_button@, @crc:team14_04_team_dock_change_guide@,
    @crc:team14_06_active_ui_change_guide@, @crc:cmn01_10_new_icon@, @crc:cmn01_10_new_icon_leader@,
    @crc:cmn01_10_new_icon_move@, @crc:soccer11_40_synergy_attachment_button_pillar@,
    @crc:soccer11_40_synergy_attachment_button_flag@, @crc:vroad02_03_seasonal_cap_plate_small@,
    @crc:vroad01_51_tournament_team_icon@}
  B.MAX_INST = 32

  local function L(...)
    local ok, v = pcall(funcLuaMenuCommand, ...)
    return ok and v or nil
  end

  local function Log(...)
    pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, ...)
  end

  local function Want()
    if EVT_PPB_OFF == true then
      return false
    end
    local ok, v = pcall(funcLuaCommand, @crc:CMND_IS_EXIST_MENU@, B.PLATE_MENU)
    if not (ok and v == true) then
      return false, "no plate menu"
    end
    -- 2026-10-06 (in game: the lineup gone with the stats view CLOSED - the bank keeps the plate menu alive): only
    -- while the plate's page is SHOWN (the retail bank's own test: CMND_IS_LAYER_VISIBLE with the menu as 4th
    -- argument, chara_bank_menu_for_search)
    local okv, vis = pcall(funcLuaMenuCommand, @crc:CMND_IS_LAYER_VISIBLE@, B.PAGE, 0, B.PLATE_MENU)
    if not (okv and vis == true) then
      return false, "stats hidden"
    end
    return true, "stats shown"
  end

  function B.Restore(why)
    local n = 0
    for key, rec in pairs(B.hid) do
      if L(@crc:CMND_IS_EXIST_LAYER@, rec[1]) == true and L(@crc:CMND_IS_OPEN_LAYER@, rec[1], rec[2]) == true then
        L(@crc:CMND_SET_LAYER_VISIBLE@, rec[1], rec[2], true)
        L(855005857, rec[1], rec[2], true)                     -- its mouse zone back (pointer, see B.Step)
      end
      B.hid[key] = nil
      n = n + 1
    end
    if n > 0 or B.on then
      Log("EVT_PPB restore", n, tostring(why))
    end
    B.on = false
  end

  function B.Step()
    -- 2026-10-12: the formation-side rule first (B.UiSync below: the retail resumes the plate on its own paths too)
    if B.UiSync ~= nil then
      pcall(B.UiSync)
    end
    local want, why = Want()
    if not want then
      if B.on or next(B.hid) ~= nil then
        B.Restore(why)
      end
      return
    end
    B.on = true
    local n = 0
    for _, l in ipairs(B.LAYERS) do
      if L(@crc:CMND_IS_EXIST_LAYER@, l) == true then                                -- CMND_IS_EXIST_LAYER
        for i = 0, B.MAX_INST - 1 do
          if L(@crc:CMND_IS_OPEN_LAYER@, l, i) ~= true then                        -- IS_OPEN: the instances end here
            break
          end
          if L(@crc:CMND_IS_LAYER_VISIBLE@, l, i) == true then                        -- IS_VISIBLE: hide it and remember it
            L(@crc:CMND_SET_LAYER_VISIBLE@, l, i, false)
            -- 2026-10-06 pointer (docs/game/ui/mouse-support.md §2): a hidden card keeps its mouse zone and
            -- would take the engine focus on hover (another player on the page): zone off while hidden
            L(855005857, l, i, false)
            B.hid[l * 64 + i] = {l, i}
            n = n + 1
          end
        end
      end
    end
    if n > 0 then
      Log("EVT_PPB hide", n, why)
    end
  end


  -- 2026-10-12 (owner, bank with «Mostrar estadísticas» on). Two retail moves of the bank leave the stats view in a
  -- state IF's page was never laid out for:
  -- (1) X «Buscar por nombre»: SetNameSearchInputEnabled(true) SUSPENDS personal_plate_menu (1129326309) while the
  --     name is typed and resumes it after (ResumeOpenedPersonalPlate). A suspended plate is not visible, so Want()
  --     turned false, B.Restore showed the lineup and it was hidden again on the resume: the lineup flashed for the
  --     time of the input. Now the plate stays drawn: right after the retail suspend it is resumed again (the bank's
  --     own resume command 1453710531); the input stays the bank's.
  -- (2) «Añadir al equipo» / any move of the cursor onto the lineup (ChangeActiveUI(1): the formation side active):
  --     the retail keeps the plate up and slides it to the LEFT (2535514686(false); OpenPersonalPlate there plays
  --     offset03 state 0 with left alignment) to show the player under the formation cursor. IF's one-row page is
  --     laid out for the right side only (header over the tabs, empty band top-right, moves bottom-left), and B.Step
  --     kept the lineup hidden while the page was shown, so the player could not be placed. Now while the formation
  --     side is active the plate menu is suspended (the retail ClosePersonalPlate command): the page is no longer
  --     visible, B.Restore brings the lineup back and it is usable. Back on the list (ChangeActiveUI(0)) the plate is
  --     resumed if the stats view is still on (OpenPersonalPlate / ClosePersonalPlate tracked in B.open), with the
  --     bank's right-side offset (PlayOffsetAnimCharaBankPersonalPlate(true), the retail list-side call).
  -- EVT_PPB_KEEP_ON_SEARCH = false / EVT_PPB_FORMATION_HIDE = false give the retail behaviour back. loader.log
  -- «EVT_PPB ui <n>», «EVT_PPB formation suspend» / «EVT_PPB formation resume», «EVT_PPB search keep».
  B.ui = 0                -- the retail n13 (0 list, 1 lineup) and flag (stats view on) start again with the chunk
  B.open = false
  B.late = false
  B.formSusp = false
  B.leftOpen = false

  local function PageShown()
    return L(@crc:CMND_IS_LAYER_VISIBLE@, B.PAGE, 0, B.PLATE_MENU) == true        -- CMND_IS_LAYER_VISIBLE in personal_plate_menu
  end

  function B.UiSync()
    if EVT_PPB_FORMATION_HIDE == false then
      return
    end
    if B.ui == 1 then
      if B.open and PageShown() then
        L(1129326309, B.PLATE_MENU)                                -- suspend (the retail ClosePersonalPlate command)
        if not B.formSusp then
          Log("EVT_PPB formation suspend")
        end
        B.formSusp = true
      end
    elseif B.formSusp then
      B.formSusp = false
      local ok, ex = pcall(funcLuaCommand, @crc:CMND_IS_EXIST_MENU@, B.PLATE_MENU)   -- CMND_IS_EXIST_MENU
      if B.open and ok and ex == true then
        L(1453710531, B.PLATE_MENU)                                -- resume (the retail OpenPersonalPlate command)
        if B.leftOpen then
          -- opened while the formation side was active: the retail placed it on the LEFT (offset03 state 0, left
          -- alignment); ChangeActiveUI(0)'s own side change (2535514686) did not run for it: the list-side call
          pcall(funcLuaCommand, 830228314, B.PLATE_MENU, "PlayOffsetAnimCharaBankPersonalPlate", true)
          B.leftOpen = false
        end
        Log("EVT_PPB formation resume")
      end
    end
  end


  -- 2026-10-15 (owner: the lineup showed behind the stats view again). Every wrapper of this block is set in
  -- B.Install: once while the chunk loads and once more at the bank's first engine command, when every patch of
  -- every mod has run. A later patch that defines the bank's functions again (a promoted copy of the retail script,
  -- e.g. InaRogue's rogue_dock, loads after this mod) replaced Step / ChangeActiveUI / OpenPersonalPlate ... and
  -- none of the rules below ran; the second pass wraps those fresh definitions (EVT_PPG_Wrap: one wrapper per
  -- definition, a function already wrapped is left alone). loader.log «EVT_PPB install late».
  function B.Install()
    for _, fname in ipairs({"PostStep", "Step"}) do
      if type(_ENV[fname]) == "function" then
        EVT_PPG_Wrap(fname, function(orig)
          return function(...)
            B.inStep = true
            local r = table.pack(orig(...))        -- the original first; ours after it
            B.inStep = false
            pcall(B.Step)
            return table.unpack(r, 1, r.n)
          end
        end)
        break
      end
    end
    for _, fname in ipairs({"FinalizeMenu", "OnCloseLayer"}) do
      EVT_PPG_Wrap(fname, function(orig)
        return function(...)
          local r = table.pack(orig(...))
          -- OnCloseLayer runs for every layer of the bank (e.g. the command popup's explanation window on each
          -- option focus): the lineup comes back only when the player page is no longer shown
          if next(B.hid) ~= nil and (fname == "FinalizeMenu" or not Want()) then
            pcall(B.Restore, fname)
          end
          return table.unpack(r, 1, r.n)
        end
      end)
    end
    EVT_PPG_Wrap("ChangeActiveUI", function(orig)
      return function(a1, ...)
        local r = table.pack(orig(a1, ...))     -- the original first
        if type(a1) == "number" and a1 ~= B.ui then
          B.ui = a1
          Log("EVT_PPB ui", a1)
        end
        pcall(B.UiSync)
        return table.unpack(r, 1, r.n)
      end
    end)
    EVT_PPG_Wrap("OpenPersonalPlate", function(orig)
      return function(...)
        local r = table.pack(orig(...))
        B.open = true
        B.leftOpen = B.ui == 1
        pcall(B.UiSync)
        return table.unpack(r, 1, r.n)
      end
    end)
    EVT_PPG_Wrap("ClosePersonalPlate", function(orig)
      return function(...)
        B.open = false
        B.formSusp = false
        B.leftOpen = false
        return orig(...)
      end
    end)
    EVT_PPG_Wrap("SetNameSearchInputEnabled", function(orig)
      return function(a1, ...)
        local keep = a1 == true and EVT_PPB_KEEP_ON_SEARCH ~= false and B.ui ~= 1 and PageShown()
        local r = table.pack(orig(a1, ...))
        if keep then
          L(1453710531, B.PLATE_MENU)                                -- the retail suspend undone: the page stays
          Log("EVT_PPB search keep")
        end
        return table.unpack(r, 1, r.n)
      end
    end)
  end

  -- The bank's engine command entry (funcLuaMenuCommand) is set by the engine after the chunk and every patch ran:
  -- its first call installs the wrappers again over the final definitions. The same entry answers «not moved» to
  -- the retail «pointer moved» test (3272825600; 879171363 since v7.2.1) inside Step while the stats view is shown on the list side and the
  -- pointer is on the right half: the retail Step moves the bank to the lineup side whenever the pointer crosses
  -- the middle of the screen, i.e. as soon as it goes over the player page, which suspended the page (B.UiSync).
  -- The lineup side stays reachable with the pad (right off the list), «Añadir al equipo» and with the pointer once
  -- the stats view is hidden (V).
  -- EVT_PPB_POINTER_KEEP = false gives the retail pointer rule back.
  B.POINTER_MOVED = { [3272825600] = true, [879171363] = true }   -- v7.1.2 id, v7.2.1 id
  B.cmdWrapped = B.cmdWrapped or {}
  local function WrapMenuCommand(f)
    if type(f) ~= "function" or B.cmdWrapped[f] then
      return f
    end
    local w = function(id, ...)
      if not B.late then
        B.late = true
        local ok, err = pcall(B.Install)
        Log("EVT_PPB install late", tostring(ok), tostring(err))
      end
      if B.POINTER_MOVED[id] and B.inStep and B.ui == 0 and EVT_PPB_POINTER_KEEP ~= false then
        local moved = f(id, ...)
        if moved and Want() then
          -- the retail test that follows: pointer x (558229292, flags 2 | 8) against half the screen width
          local okx, x = pcall(f, 558229292, 10)
          local okw, w = pcall(funcLuaCommand, 4207852906, 2)
          if okx and okw and type(x) == "number" and type(w) == "number" and x - w / 2 >= 0 then
            return false                                             -- right half: no switch to the lineup
          end
        end
        return moved
      end
      return f(id, ...)
    end
    B.cmdWrapped[w] = true
    return w
  end
  local cur = rawget(_ENV, "funcLuaMenuCommand")
  if type(cur) == "function" then
    rawset(_ENV, "funcLuaMenuCommand", WrapMenuCommand(cur))
  else
    local mt = getmetatable(_ENV)
    if mt == nil then
      mt = {}
      setmetatable(_ENV, mt)
    end
    local prev = mt.__newindex
    mt.__newindex = function(t, k, v)
      if k == "funcLuaMenuCommand" then
        v = WrapMenuCommand(v)
      end
      if prev == nil then
        rawset(t, k, v)
      elseif type(prev) == "function" then
        prev(t, k, v)
      else
        prev[k] = v
      end
    end
  end
  B.Install()
end
-- ===== EVT plate_pages bank END =====
