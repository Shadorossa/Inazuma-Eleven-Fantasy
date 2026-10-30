-- ===== EVT plate_pages dock BEGIN =====
-- Round 11b (Nacho 2026-10-06): a chara bank (chara_bank_menu / _for_search) shows the player page over the dock; the
-- dock's lineup (pitch, frames, cards, blank cards, new / notification badges, formation buttons) stays drawn behind
-- it. This dock menu hides ITS OWN lineup layers while a bank and personal_plate_menu exist and no other screen
-- (Tabla de habilidades, Equipamiento) is open, and shows exactly the instances it hid again as soon as that stops
-- (bank closed, plate closed, a screen opened on top). Layer visibility only; the menu's input / activity untouched.
-- Runs every frame from this menu's PostStep (else Step). No engine call while the chunk loads.
-- 2026-10-06 (round 11b in game: «Tabla de habilidades» empty after Equipamiento, a stuck screen after Plantilla): a
-- dock under another screen stops stepping, so layers it hid stayed hidden. OFF by default now (EVT_PPD_OFF = false
-- turns it on again); when on, everything it hid comes back on any frame Want() is false, in OnCloseLayer /
-- FinalizeMenu of this menu, and loader.log says «EVT_PPD hide n» / «EVT_PPD restore n».
if EVT_PPD_OFF == nil then
  EVT_PPD_OFF = true
end
EVT_PPD = EVT_PPD or {hid = {}, on = false}
do
  local D = EVT_PPD
  D.BANKS = {3358148956, @crc:chara_bank_menu_for_search@}
  D.PLATE_MENU = 1427722143                         -- personal_plate_menu
  D.OVER = {1041963128, 606230082}                  -- evt_skill_slot_menu, equip_menu
  D.LAYERS = {@crc:soccer11_01_formation_bg@, @crc:soccer11_02_formation_frame@, @crc:team02_01_attach_formation_frame@,
    @crc:team00_01_chara_card_for_soccer@, @crc:team00_01_chara_card_for_leader@, @crc:team00_01_p1_chara_card_blank@,
    @crc:team00_01_p1_chara_card_blank_for_leader@, @crc:cmn01_10_new_icon@, @crc:cmn01_10_new_icon_leader@,
    @crc:team00_01_p2_notification_must_to_organize@, @crc:team00_01_p2_notification_must_to_organize_for_leader@,
    @crc:team00_01_p2_notification_must_to_organize_for_move@, @crc:soccer11_12_formation_button@,
    @crc:soccer11_19_formation_team_build_button@, @crc:soccer11_17_tactics_check_button@,
    @crc:soccer11_16_rpg_attack_defense_param@}
  D.MAX_INST = 32

  local function Menu(m)
    local ok, v = pcall(funcLuaCommand, @crc:CMND_IS_EXIST_MENU@, m)              -- CMND_IS_EXIST_MENU
    return ok and v == true
  end

  local function Want()
    if EVT_PLATE_PAGES ~= true or EVT_PPD_OFF == true or not Menu(D.PLATE_MENU) then
      return false
    end
    for _, m in ipairs(D.OVER) do
      if Menu(m) then
        return false
      end
    end
    for _, m in ipairs(D.BANKS) do
      if Menu(m) then
        return true
      end
    end
    return false
  end

  local function L(...)
    local ok, v = pcall(funcLuaMenuCommand, ...)
    return ok and v or nil
  end

  local function Log(...)
    pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, ...)
  end

  function D.Restore(why)
    local n = 0
    for key, rec in pairs(D.hid) do
      if L(@crc:CMND_IS_EXIST_LAYER@, rec[1]) == true and L(@crc:CMND_IS_OPEN_LAYER@, rec[1], rec[2]) == true then
        L(@crc:CMND_SET_LAYER_VISIBLE@, rec[1], rec[2], true)
      end
      D.hid[key] = nil
      n = n + 1
    end
    if n > 0 or D.on then
      Log("EVT_PPD restore", n, tostring(why))
    end
    D.on = false
  end

  function D.Step()
    if not Want() then
      if D.on or next(D.hid) ~= nil then
        D.Restore("step")
      end
      return
    end
    D.on = true
    local n = 0
    for _, l in ipairs(D.LAYERS) do
      if L(@crc:CMND_IS_EXIST_LAYER@, l) == true then                                -- CMND_IS_EXIST_LAYER
        for i = 0, D.MAX_INST - 1 do
          if L(@crc:CMND_IS_OPEN_LAYER@, l, i) ~= true then                        -- IS_OPEN: the instances end here
            break
          end
          if L(@crc:CMND_IS_LAYER_VISIBLE@, l, i) == true then                        -- IS_VISIBLE: hide it and remember it
            L(@crc:CMND_SET_LAYER_VISIBLE@, l, i, false)
            D.hid[l * 64 + i] = {l, i}
            n = n + 1
          end
        end
      end
    end
    if n > 0 then
      Log("EVT_PPD hide", n)
    end
  end

  for _, fname in ipairs({"PostStep", "Step"}) do
    if EVT_PPG_Wrap(fname, function(orig)
      return function(...)
        local r = table.pack(orig(...))
        pcall(D.Step)
        return table.unpack(r, 1, r.n)
      end
    end) then
      break
    end
  end
  for _, fname in ipairs({"FinalizeMenu", "OnCloseLayer"}) do
    EVT_PPG_Wrap(fname, function(orig)
      return function(...)
        local r = table.pack(orig(...))  -- the original first, always; ours after it
        if next(D.hid) ~= nil then
          pcall(D.Restore, fname)
        end
        return table.unpack(r, 1, r.n)
      end
    end)
  end
end
-- ===== EVT plate_pages dock END =====
