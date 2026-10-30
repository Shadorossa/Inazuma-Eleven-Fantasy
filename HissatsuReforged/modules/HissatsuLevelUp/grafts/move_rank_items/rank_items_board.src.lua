-- Hissatsu Level Up › the move-rank items on Victory Road's own skill board (ability_learning_board_menu, the «Tabla de
-- habilidades» of the game; docs/game/mechanics/move-rank-items.md «Victory Road's board»). SOURCE of the hook file
-- rank_items_board.lua (gen_hooks.py fills the @crc placeholders and the shared part rank_items_core.src.lua).
-- The key is Start (CMD_FUNC1; keyboard: the game's Start key), as in Inazuma Fantasy's skill table and Character
-- Reforged's «Fantasy» one (owner 2026-10-14). On this native board Start is the retail «Equipar rápido judías»
-- (setting command 0x3CAC9521: the engine calls the screen's OpenBeansSetMenu with the bean pieces): on a MOVE piece
-- that call is withheld (OpenBeansSetMenu wrapped, the bean menu does not open) and Start uses a rank item; on every
-- other piece Start stays the retail quick equip. The key is polled in Step (CMND_CHECK_INPUT_CMD). The board's input
-- is never switched off (no window over it: the native board would take the window's keys), so the confirmation is
-- the board's own telop and a second press:
--   1st press -> the board's telop (team13_18_unlimited_skill_telop, the retail text plate) shows «¿Usar X con Y?
--               old → new (tienes N)» + «Pulsa <Start> otra vez para usarlo», or the refusal with the retail «cannot»
--               sound (max level, no book, a move without levels...);
--   2nd press on the same piece, while that telop is up -> the rules apply the item, one copy leaves the bag, the
--               telop says «¡Y ha subido de nivel! old → new» and the detail card is drawn again.
-- Moving the cursor, L / R, a sub-menu or 5 seconds take the question away. The bottom guide: on a move piece the
-- retail «<Start> Equipar rápido judías» entry becomes «<Start> Subir nivel» (VRFW_FooterPrompts: a declaration with
-- Replaces = the retail Start glyph, attached to UpdateFooterButtonGuide). The player comes from the screen's own
-- calls (OnInit's parameter, OnChangeTargetChara, UpdateAbilityLearningBoardCharaCard). One log line per use /
-- refusal. Hook file: the screen has no VR-Framework host, the globals are wrapped once per VM and chained (each wrap
-- calls what it wrapped); no engine call at chunk load.
do
@CORE@

  RankItems.Board = {
    RING = 2907318182,               -- team13_09_effect_grid_focus_ring (the node focus)
    FOCUS_IDX = 2603265800,          -- (layer) -> focused instance
    PIECE_INFO = 4147077179,         -- (piece) -> layerIdx, posIdx, skillId, selectedSkillId, category, ... (13 values)
    MOVE_PIECE = {[0] = true, [1] = true},   -- piece categories holding a move (0 move, 1 aura / special move)
    CTRL = 1332654303,               -- MENU_CTRL
    CTRL_ANALOG = 2748927068,        -- MENU_CTRL_WITH_ANALOG_MOVE_FOCUS
    CHECK_INPUT = 4265778440,        -- CMND_CHECK_INPUT_CMD (ctrl, command) -> pressed
    KEY = @crc:CMD_FUNC1@,              -- Start (keyboard: the game's Start key)
    RETAIL_START_GLYPH = 3875068402, -- the glyph of the retail guide's Start entry «Equipar rápido judías»
    TELOP = 157759052,               -- team13_18_unlimited_skill_telop
    TELOP_TEXT = 3359986143,         -- _text_sp01
    SET_TEXT = 1083631230,           -- CMND_SET_MENU_TEXT_STRING (layer, node, text)
    TEXT_PLATE = 1172899594,         -- (layer, idx, node): the plate follows the text
    LAYER_VISIBLE = 711242136,
    SOUND = 1917805374, SE_OK = 3848881948, SE_DECIDE = 4235359837, SE_NG = 2086672038,
    PARAM_CHARA = 4161869490,
    SKILL_INFO = 2580586398,         -- (skill, 4) -> ok, name text id
    NAME_TEXT = 720417636,           -- (name text id) -> string
    TELOP_FRAMES = 300,              -- how long a question / an answer stays (frames)
    KEY_COOLDOWN = 12,               -- frames between two presses
    chara = nil, mode = nil, last_idx = nil, guide_on = false, armed = nil, telop_ours = false, telop_frames = 0,
    cooldown = 0, detail = nil, wrapped = {},
  }
  local Board = RankItems.Board

  function Board.Sound(id)
    pcall(funcLuaCommand, Board.SOUND, id)
  end

  function Board.MoveName(skill)
    local ok, found, name_id = pcall(funcLuaCommand, Board.SKILL_INFO, skill, 4)
    if ok and found and type(name_id) == "number" then
      local okn, name = pcall(funcLuaCommand, Board.NAME_TEXT, name_id)
      if okn and type(name) == "string" and name ~= "" then
        return name
      end
    end
    return RankItems.Hex(skill)
  end

  -- the focused piece: {idx, skill, category}; nil = no piece
  function Board.Focused()
    local okf, idx = pcall(funcLuaMenuCommand, Board.FOCUS_IDX, Board.RING)
    if not okf or type(idx) ~= "number" or idx < 0 then
      return nil
    end
    local r = {pcall(funcLuaMenuCommand, Board.PIECE_INFO, idx)}
    if not r[1] then
      return nil
    end
    local skill, selected, category, overwrite, secret = r[4], r[5], r[6], r[12], r[13]
    local move = 0
    if type(selected) == "number" and selected ~= 0 then
      move = selected
    elseif type(overwrite) == "number" and overwrite ~= 0 then
      move = overwrite
    elseif type(skill) == "number" then
      move = skill
    end
    return {idx = idx, skill = RankItems.U32(move), category = category, secret = secret == true}
  end

  function Board.IsMovePiece(piece)
    return piece ~= nil and Board.MOVE_PIECE[piece.category] == true and not piece.secret and piece.skill ~= 0
  end

  -- a retail coroutine of the board (lists, sub-windows, the player change) or Utilities' partner picker runs
  function Board.Busy()
    local partners = rawget(_ENV, "UTIL_CP")
    if type(partners) == "table" and partners.co ~= nil then
      return true
    end
    if type(IsRunningManageCoroutine) == "function" then
      for i = 1, 13 do
        local ok, running = pcall(IsRunningManageCoroutine, i)
        if ok and running == true then
          return true
        end
      end
    end
    return false
  end

  function Board.Pressed()
    local ok, hit = pcall(funcLuaCommand, Board.CHECK_INPUT, Board.CTRL, Board.KEY)
    if ok and hit == true then
      return true
    end
    local ok2, hit2 = pcall(funcLuaCommand, Board.CHECK_INPUT, Board.CTRL_ANALOG, Board.KEY)
    return ok2 and hit2 == true
  end

  -- ---- the telop (the board's retail text plate) -------------------------------------------------------------------
  function Board.Say(text)
    funcLuaMenuCommand(Board.SET_TEXT, Board.TELOP, Board.TELOP_TEXT, text)
    funcLuaMenuCommand(Board.TEXT_PLATE, Board.TELOP, 0, Board.TELOP_TEXT)
    funcLuaMenuCommand(Board.LAYER_VISIBLE, Board.TELOP, 0, true)
    Board.telop_ours, Board.telop_frames = true, Board.TELOP_FRAMES
  end

  function Board.Quiet()
    Board.armed = nil
    if Board.telop_ours then
      Board.telop_ours = false
      pcall(funcLuaMenuCommand, Board.LAYER_VISIBLE, Board.TELOP, 0, false)
    end
  end

  -- ---- the guide entry «<Start> Subir nivel» -----------------------------------------------------------------------
  -- shown on a move piece while Hissatsu Level Up answers (without a book the press says why: the guide teaches the key)
  function Board.GuideWanted()
    if (Board.mode ~= 0 and Board.mode ~= 1) or Board.chara == nil or not Board.IsMovePiece(Board.Focused()) then
      return false
    end
    return RankItems.Active()
  end

  -- Start is ours on a move piece (the retail quick bean equip is withheld there)
  function Board.StartIsOurs()
    return Board.chara ~= nil and Board.IsMovePiece(Board.Focused()) and RankItems.Active()
  end

  -- ---- the key ----------------------------------------------------------------------------------------------------
  function Board.Press()
    local piece = Board.Focused()
    if Board.chara == nil or not Board.IsMovePiece(piece) then
      Board.Sound(Board.SE_NG)
      RankItems.Log("board", "refused", "no_move_piece", "chara", tostring(Board.chara))
      return
    end
    local armed = Board.armed
    if armed ~= nil and armed.idx == piece.idx and armed.skill == piece.skill and armed.chara == Board.chara then
      Board.armed = nil
      local used, text = RankItems.Use("board", armed.plan)
      Board.Sound(used and Board.SE_DECIDE or Board.SE_NG)
      Board.Say(text)
      if used then
        if Board.detail ~= nil and type(UpdateDetailWindow) == "function" then
          pcall(UpdateDetailWindow, table.unpack(Board.detail, 1, Board.detail.n))
        end
        if type(UpdateFooterButtonGuide) == "function" then
          pcall(UpdateFooterButtonGuide, Board.mode)
        end
      end
      return
    end
    local plan = RankItems.Plan(Board.chara, piece.skill, Board.MoveName(piece.skill))
    if plan.refusal ~= nil then
      Board.armed = nil
      RankItems.LogRefused("board", plan)
      Board.Sound(Board.SE_NG)
      Board.Say(RankItems.RefusalText(plan))
      return
    end
    Board.Sound(Board.SE_OK)
    Board.Say(RankItems.ConfirmText(plan) .. "\n" .. RankItems.Text(RankItems.TX.PRESS_AGAIN))
    Board.armed = {idx = piece.idx, skill = piece.skill, chara = Board.chara, plan = plan}
    RankItems.Log("board", "asked", RankItems.Hex(plan.item), "on", RankItems.Hex(plan.skill), "chara",
      tostring(Board.chara), "grade", tostring(plan.old), "->", tostring(plan.new))
  end

  -- every frame (after the screen's Step)
  function Board.Poll()
    if Board.cooldown > 0 then
      Board.cooldown = Board.cooldown - 1
    end
    if Board.telop_ours and Board.telop_frames > 0 then
      Board.telop_frames = Board.telop_frames - 1
      if Board.telop_frames == 0 then
        Board.Quiet()
      end
    end
    if (Board.mode ~= 0 and Board.mode ~= 1) or Board.Busy() then
      return
    end
    local okf, idx = pcall(funcLuaMenuCommand, Board.FOCUS_IDX, Board.RING)
    if okf and idx ~= Board.last_idx then
      Board.last_idx = idx
      Board.Quiet()
      local want = Board.GuideWanted()
      if want ~= Board.guide_on and type(UpdateFooterButtonGuide) == "function" then
        pcall(UpdateFooterButtonGuide, Board.mode)
      end
    end
    if Board.cooldown == 0 and Board.Pressed() and Board.StartIsOurs() then
      Board.cooldown = Board.KEY_COOLDOWN
      Board.Press()
    end
  end

  -- ---- the wraps (once per VM; each calls what it wrapped) ---------------------------------------------------------
  function Board.Wrap(name, make)
    if Board.wrapped[name] then
      return
    end
    local current = rawget(_ENV, name)
    if type(current) ~= "function" then
      return
    end
    _ENV[name] = make(current)
    Board.wrapped[name] = true
  end

  function Board.SetChara(chara)
    if type(chara) == "number" and chara ~= 0 then
      if chara ~= Board.chara then
        Board.Quiet()
      end
      Board.chara = chara
    end
  end

  Board.Wrap("OnInit", function(previous)
    return function(...)
      Board.chara, Board.mode, Board.last_idx, Board.guide_on, Board.detail = nil, nil, nil, false, nil
      Board.armed, Board.telop_ours, Board.telop_frames, Board.cooldown = nil, false, 0, 0
      pcall(function()
        if VRFW_Param.Has(Board.PARAM_CHARA) then
          Board.SetChara(VRFW_Param.Get(Board.PARAM_CHARA))
        end
      end)
      return previous(...)
    end
  end)

  Board.Wrap("OnChangeTargetChara", function(previous)
    return function(chara, ...)
      Board.SetChara(chara)
      Board.last_idx = nil
      return previous(chara, ...)
    end
  end)

  -- (charaStHdl, showTeamDockNo, teamDockType, formationId, selectCharaIdx, ...)
  Board.Wrap("UpdateAbilityLearningBoardCharaCard", function(previous)
    return function(chara, ...)
      Board.SetChara(chara)
      return previous(chara, ...)
    end
  end)

  -- the guide entry through the framework's footer prompts (attached first: the mode wrap below runs before it)
  if VRFW_FooterPrompts ~= nil then
    VRFW_FooterPrompts.Add({
      Name = "HissatsuLevelUp.RankItemUse",
      Menu = "ability_learning_board_menu",
      Text = RankItems.TX.GUIDE,
      Icon = RankItems.TX.KEY,
      Command = Board.KEY,
      Replaces = Board.RETAIL_START_GLYPH,
      Order = 100,
      When = function()
        return Board.guide_on
      end,
    })
    VRFW_FooterPrompts.Attach("ability_learning_board_menu", "UpdateFooterButtonGuide")
  end

  Board.Wrap("UpdateFooterButtonGuide", function(previous)
    return function(mode, ...)
      Board.mode = mode or 0
      local ok, want = pcall(Board.GuideWanted)
      Board.guide_on = ok and want == true
      return previous(mode, ...)
    end
  end)

  -- Start on a move piece: the retail quick bean equip (the engine calls this with the bean pieces) is withheld; the
  -- poll above uses the rank item. A on a bean piece (focus on that piece) and Start elsewhere go on as retail.
  Board.Wrap("OpenBeansSetMenu", function(previous)
    return function(...)
      local ok, ours = pcall(Board.StartIsOurs)
      if ok and ours then
        RankItems.Log("board", "quick bean equip withheld (Start on a move piece)")
        return
      end
      return previous(...)
    end
  end)

  Board.Wrap("ResetFooterButtonGuide", function(previous)
    return function(...)
      Board.mode, Board.guide_on = nil, false
      Board.Quiet()
      return previous(...)
    end
  end)

  -- the detail card's last call: drawn again after a use (the move's new level)
  Board.Wrap("UpdateDetailWindow", function(previous)
    return function(...)
      Board.detail = table.pack(...)
      return previous(...)
    end
  end)

  -- the retail telop took the plate back (an unlimited move's piece): it is not ours to hide any more
  Board.Wrap("UpdateUnlimitedSkillTelop", function(previous)
    return function(...)
      Board.telop_ours, Board.armed = false, nil
      return previous(...)
    end
  end)

  Board.Wrap("Step", function(previous)
    return function(...)
      local r = table.pack(previous(...))
      local ok, err = pcall(Board.Poll)
      if not ok then
        RankItems.Log("board", "poll failed", tostring(err))
      end
      return table.unpack(r, 1, r.n)
    end
  end)
end
