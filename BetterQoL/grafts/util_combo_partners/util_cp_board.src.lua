-- Combo partners of the mod Utilities (utilities.dll, feature combo_partners; docs/game/mechanics/combo-partners.md §6)
-- on the RETAIL «Tabla de habilidades» (ability_learning_board_menu_7.00.00.00). SOURCE of the hook file
-- util_cp_board.lua (research/grafts/util_combo_partners/gen_hooks.py fills the @crc placeholders and the shared
-- picker util_cp_core.src.lua; edit the sources, then run the script).
--
-- What it adds to the retail screen (no retail function is replaced; every hook wraps the global and calls it):
--   * bottom guide: when the focused node holds a move that needs partners (SKILL_INFO partnerType 2-4, asked to the
--     plugin: CMND_BETTERQOL_COMBO_INFO; no move list here), «X Compañeros» is appended to the retail entries
--     (UpdateFooterButtonGuide wrapped: the retail call's own guide tables get the entry, so the retail texts stay
--     the retail ones; re-run when the focused node changes);
--   * X on such a node (the board's CMD_FUNCTION 0xB83F1EB1 of the node focus ring, OnFunction wrapped): the partner
--     picker (the shared part util_cp_core: one page per free partner slot in Utilities' own list window, layers
--     util_pc_listbg / util_pc_list / util_pc_row of menus\102_team\combo_partners.toml; rows = «Aleatorio (en el
--     partido)» then the team dock's squad in field order; then the confirm popup and CMND_BETTERQOL_COMBO_SET);
--   * a node whose move is «editable» (Nueva posibilidad: the board's own X toggles that move natively) gets no X.
-- The player, his dock and the formation come from the screen's own calls: OnInit (the parameters the team dock
-- leaves, read before the retail OnInit clears them), OnChangeTargetChara (L / R), UpdateAbilityLearningBoardCharaCard.
-- Without the plugin every command answers a single false: no guide entry, X does nothing.
-- Hook file (graft [[hooks]]): the screen has no VR-Framework host, so the globals are wrapped directly, once per VM.
do
@CORE@

  UTIL_CP.MENU = 1810526795 -- ability_learning_board_menu
  UTIL_CP.RING = 2907318182 -- team13_09_effect_grid_focus_ring (the node focus)
  UTIL_CP.CURSOR = 4051667112 -- cmn05_01_cursor_ability_learning
  UTIL_CP.FN_X = 3091144369 -- 0xB83F1EB1: the focus ring's CMD_FUNCTION for CMD_FUNC4 (X) in the screen's setting
  UTIL_CP.PRIO = {BG = 600, LIST = 601, ITEM = 602}
  -- the team dock's parameters the screen's OnInit reads (and clears)
  UTIL_CP.P_CHARA = 4161869490
  UTIL_CP.P_DOCK_NO = 3357163798
  UTIL_CP.P_DOCK_TYPE = 4081600465
  UTIL_CP.P_FORMATION = 813466851
  UTIL_CP.co = nil

  function UTIL_CP.Parent()
    if MENU_DEF ~= nil and type(MENU_DEF.GetParentMenuID) == "function" then
      local ok, m = pcall(MENU_DEF.GetParentMenuID)
      if ok and m ~= nil then
        return m
      end
    end
    return 2645952753 -- main_menu
  end

  -- ---- the screen's state --------------------------------------------------------------------------------------
  -- a parameter of the store without taking it (the retail OnInit clears it after reading)
  function UTIL_CP.Peek(key)
    if not VRFW_Param.Has(key) then
      return nil
    end
    local v = VRFW_Param.Get(key)
    return v or nil
  end

  function UTIL_CP.Seen(h, dock_no, dock_type, formation)
    if type(h) == "number" and h ~= 0 then
      UTIL_CP.h = UTIL_CP.U32(h)
    end
    if type(dock_no) == "number" then
      UTIL_CP.dock_no = dock_no
    end
    if type(dock_type) == "number" then
      UTIL_CP.dock_type = dock_type
    end
    if type(formation) == "number" then
      UTIL_CP.formation = formation
    end
  end

  -- the focused node: {skill, category, editable} (nil = no node focused)
  function UTIL_CP.Focused()
    local okf, idx = pcall(funcLuaMenuCommand, 2603265800, UTIL_CP.RING)
    if not okf or type(idx) ~= "number" or idx < 0 then
      return nil
    end
    local r = {pcall(funcLuaMenuCommand, 4147077179, idx)}
    if not r[1] then
      return nil
    end
    -- layerIdx, posIdx, skillId, selectedSkillId, category, needPoint, canLiberate, isLiberated, isLocked,
    -- lightLayerIdx, overwriteSkillId, isSecret, isEditable (GetEffectPieceInfoFromMenu)
    local skill, selected, category, overwrite, secret, editable = r[4], r[5], r[6], r[12], r[13], r[14]
    local s = 0
    if type(selected) == "number" and selected ~= 0 then
      s = selected
    elseif type(overwrite) == "number" and overwrite ~= 0 then
      s = overwrite
    elseif type(skill) == "number" then
      s = skill
    end
    return {idx = idx, skill = UTIL_CP.U32(s), category = category, editable = editable == true, secret = secret == true}
  end

  -- the focused node's move when X may open the picker on it (a move node, not an «editable» one, 2+ performers)
  function UTIL_CP.FocusedCombo()
    local f = UTIL_CP.Focused()
    if f == nil or (f.category ~= 0 and f.category ~= 1) or f.editable or f.secret or f.skill == 0 then
      return nil
    end
    local info = UTIL_CP.ComboInfo(f.skill)
    if info == nil then
      return nil
    end
    return f, info
  end

  function UTIL_CP.Busy()
    if UTIL_CP.co ~= nil then
      return true
    end
    if type(IsRunningManageCoroutine) == "function" then
      for i = 1, 13 do
        local ok, r = pcall(IsRunningManageCoroutine, i)
        if ok and r == true then
          return true
        end
      end
    end
    return false
  end

  -- ---- the picker on this screen (the SCREEN table of util_cp_core) ----------------------------------------------
  -- the team dock's squad (the dock the screen was opened from); nil = opened without a dock
  function UTIL_CP.BoardMembers()
    local dock_no, dock_type = UTIL_CP.dock_no, UTIL_CP.dock_type
    if type(dock_no) ~= "number" or type(dock_type) ~= "number" then
      return nil
    end
    local out = {formation = UTIL_CP.formation}
    local n = dock_type == 2 and 7 or 20
    local okb, flag = pcall(funcLuaCommand, 941426960 --[[CMND_GET_GLOBAL_BIT_FLAG]], 908681340)
    local okx, excluded = pcall(funcLuaCommand, 2668676119, 0)
    for i = 0, n - 1 do
      local ok, got, h = pcall(funcLuaCommand, 1720957768, dock_no, dock_type, i, 0)
      h = (ok and got) and UTIL_CP.U32(h) or 0
      if okb and flag and okx and h == UTIL_CP.U32(excluded) then
        h = 0
      end
      if h ~= 0 then
        local okp, gotp, posno = pcall(funcLuaCommand, 1720957768, dock_no, dock_type, i, 1)
        out[#out + 1] = {hdl = h, slot = (okp and gotp and type(posno) == "number") and posno or nil, index = i}
      end
    end
    return out
  end

  function UTIL_CP.Restore()
    pcall(UTIL_CP.ListShow, UTIL_CP.Board(), false, {}, 0, 0, 0)
    pcall(funcLuaMenuCommand, 711242136, UTIL_CP.CURSOR, 0, true)
    pcall(funcLuaMenuCommand, 1558704558, UTIL_CP.MENU, true)
    UTIL_CP.last_idx = nil
    if type(UpdateFooterButtonGuide) == "function" then
      pcall(UpdateFooterButtonGuide, UTIL_CP.mode or 0)
    end
  end

  -- while the picker runs the board is off the way its retail sub-windows switch it (menu inactive, cursor hidden)
  function UTIL_CP.Board()
    return {
      player = UTIL_CP.h,
      backdrop = true,
      Members = UTIL_CP.BoardMembers,
      Begin = function()
        funcLuaMenuCommand(1558704558, UTIL_CP.MENU, false)
        pcall(funcLuaMenuCommand, 711242136, UTIL_CP.CURSOR, 0, false)
      end,
      Finish = UTIL_CP.Restore,
      GuideMenu = UTIL_CP.Parent,
    }
  end

  -- ---- the bottom guide ----------------------------------------------------------------------------------------
  -- the retail call's guide tables get «X Compañeros» appended (same texts / glyphs / commands as retail otherwise)
  function UTIL_CP.GuideHook(on)
    if on then
      if UTIL_CP.cmd_orig ~= nil or type(funcLuaMenuCommand) ~= "function" then
        return
      end
      local orig = funcLuaMenuCommand
      UTIL_CP.cmd_orig = orig
      funcLuaMenuCommand = function(cmd, menu, layer, a, b, c, ...)
        if layer == UTIL_CP.GUIDE and cmd == UTIL_CP.GUIDE_TEXTS and type(a) == "table" and type(b) == "table" and type(c) == "table" then
          local t, g, o = {table.unpack(a)}, {table.unpack(b)}, {table.unpack(c)}
          t[#t + 1], g[#g + 1] = UTIL_CP.TX_BTN, UTIL_CP.GL_FUNC4
          o[#o + 1] = (#c > 0 and type(c[#c]) == "number") and (c[#c] + 18) or 18
          return orig(cmd, menu, layer, t, g, o, ...)
        elseif layer == UTIL_CP.GUIDE and cmd == UTIL_CP.GUIDE_KEYS and type(a) == "table" then
          local k = {table.unpack(a)}
          k[#k + 1] = UTIL_CP.K_FUNC4
          return orig(cmd, menu, layer, k, b, c, ...)
        end
        return orig(cmd, menu, layer, a, b, c, ...)
      end
    elseif UTIL_CP.cmd_orig ~= nil then
      funcLuaMenuCommand = UTIL_CP.cmd_orig
      UTIL_CP.cmd_orig = nil
    end
  end

  function UTIL_CP.WrapGlobal(name, make)
    UTIL_CP.wrapped = UTIL_CP.wrapped or {}
    if UTIL_CP.wrapped[name] then
      return
    end
    local cur = _ENV[name]
    if cur == nil then
      return
    end
    _ENV[name] = make(cur)
    UTIL_CP.wrapped[name] = true
  end

  UTIL_CP.WrapGlobal("UpdateFooterButtonGuide", function(prev)
    return function(a1, ...)
      local mode = a1 or 0
      UTIL_CP.mode = mode
      local want = false
      if (mode == 0 or mode == 1) and UTIL_CP.co == nil then
        local okc, f = pcall(UTIL_CP.FocusedCombo)
        want = okc and f ~= nil
        UTIL_CP.guide_idx = (okc and f ~= nil) and f.idx or nil
      end
      UTIL_CP.guide_x = want
      if not want then
        return prev(a1, ...)
      end
      UTIL_CP.GuideHook(true)
      local r = table.pack(pcall(prev, a1, ...))
      UTIL_CP.GuideHook(false)
      if not r[1] then
        error(r[2], 0)
      end
      return table.unpack(r, 2, r.n)
    end
  end)

  UTIL_CP.WrapGlobal("ResetFooterButtonGuide", function(prev)
    return function(...)
      UTIL_CP.mode = nil
      UTIL_CP.guide_x = false
      return prev(...)
    end
  end)

  -- every frame (Step): the guide follows the focused node; the picker runs
  function UTIL_CP.Poll()
    if UTIL_CP.co ~= nil then
      local ok, err = coroutine.resume(UTIL_CP.co)
      if not ok then
        UTIL_CP.Log("picker error", tostring(err))
        pcall(UTIL_CP.Restore)
        UTIL_CP.co = nil
      elseif coroutine.status(UTIL_CP.co) == "dead" then
        UTIL_CP.co = nil
      end
      return
    end
    if (UTIL_CP.mode ~= 0 and UTIL_CP.mode ~= 1) or UTIL_CP.Busy() then
      return
    end
    local okf, idx = pcall(funcLuaMenuCommand, 2603265800, UTIL_CP.RING)
    if not okf or idx == UTIL_CP.last_idx then
      return
    end
    UTIL_CP.last_idx = idx
    local okc, f = pcall(UTIL_CP.FocusedCombo)
    local want = okc and f ~= nil
    if want ~= (UTIL_CP.guide_x == true) and type(UpdateFooterButtonGuide) == "function" then
      pcall(UpdateFooterButtonGuide, UTIL_CP.mode)
    end
  end

  UTIL_CP.WrapGlobal("Step", function(prev)
    return function(...)
      local r = table.pack(prev(...))
      pcall(UTIL_CP.FacesSettle)
      local ok, err = pcall(UTIL_CP.Poll)
      if not ok then
        UTIL_CP.Log("poll failed", tostring(err))
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  UTIL_CP.WrapGlobal("OnInit", function(prev)
    return function(...)
      UTIL_CP.h, UTIL_CP.dock_no, UTIL_CP.dock_type, UTIL_CP.formation = nil, nil, nil, nil
      UTIL_CP.co, UTIL_CP.mode, UTIL_CP.last_idx, UTIL_CP.guide_x = nil, nil, nil, false
      pcall(function()
        UTIL_CP.Seen(UTIL_CP.Peek(UTIL_CP.P_CHARA), UTIL_CP.Peek(UTIL_CP.P_DOCK_NO), UTIL_CP.Peek(UTIL_CP.P_DOCK_TYPE),
          UTIL_CP.Peek(UTIL_CP.P_FORMATION))
      end)
      return prev(...)
    end
  end)

  UTIL_CP.WrapGlobal("OnChangeTargetChara", function(prev)
    return function(a1, ...)
      pcall(UTIL_CP.Seen, a1)
      UTIL_CP.last_idx = nil
      return prev(a1, ...)
    end
  end)

  -- (charaStHdl, showTeamDockNo, teamDockType, formationId, selectCharaIdx, ...)
  UTIL_CP.WrapGlobal("UpdateAbilityLearningBoardCharaCard", function(prev)
    return function(a1, a2, a3, a4, ...)
      pcall(UTIL_CP.Seen, a1, a2, a3, a4)
      return prev(a1, a2, a3, a4, ...)
    end
  end)

  UTIL_CP.WrapGlobal("OnFunction", function(prev)
    return function(a1, a2, ...)
      if a1 == UTIL_CP.FN_X and UTIL_CP.co == nil and (UTIL_CP.mode == 0 or UTIL_CP.mode == 1) and not UTIL_CP.Busy() then
        local okc, f, info = pcall(UTIL_CP.FocusedCombo)
        if okc and f ~= nil then
          UTIL_CP.co = coroutine.create(function()
            UTIL_CP.Open(UTIL_CP.Board(), f.skill, info)
          end)
        end
      end
      return prev(a1, a2, ...)
    end
  end)

  -- ---- the picker's layers --------------------------------------------------------------------------------------
  UTIL_CP.WrapGlobal("OnSetupLayer", function(prev)
    return function(a1, a2, ...)
      if UTIL_CP.Ours(a1) then
        UTIL_CP.SetupLayer(a1, a2, UTIL_CP.PRIO)
        return
      end
      return prev(a1, a2, ...)
    end
  end)

  UTIL_CP.WrapGlobal("OnOpenLayer", function(prev)
    return function(a1, a2, ...)
      if UTIL_CP.Ours(a1) then
        if UTIL_CP.co == nil then
          pcall(funcLuaMenuCommand, 711242136, a1, a2, false)
        end
        return
      end
      return prev(a1, a2, ...)
    end
  end)
end
