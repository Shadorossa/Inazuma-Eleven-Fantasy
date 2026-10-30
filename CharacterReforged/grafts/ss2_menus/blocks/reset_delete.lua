-- ===== X «Restablecer» / Y «Eliminar» (2026-10-06) =====
-- User: Y ALWAYS deletes (EVT_RestoreCoroutine above: the slot ends empty, never the default). X restores the focused
-- row from the player's basic kit: first the slot's own native board move (what the old «Eliminar» brought back:
-- CMND_CHARACTERREFORGED_BOARD_CLEAR keepOpen 1 takes the placed item off), else his learnset move for that slot (chara_param
-- slots 1-6, the Hiper row slot 9; the source of the native moves, needed after a Y took the native off) once his
-- level reached it; nothing in the kit = the slot ends EMPTY. Button guide on the rows: Aceptar, X «Restablecer»
-- (retail menu_text 108624977, the settings screens' CMD_FUNC4 Reset), Y «Eliminar» (retail 3961481199) when the row
-- has a move. CMD_FUNC4 reaches OnFunction as 1141890006 (the retail eye-check toggle, unused on this screen).

-- learnset move of `row` (Hiper row: a special, rows 1-6: a normal move) when the player's level reached it, else 0
function PL.KitMove(row)
  local ls = PL.Learnset()
  local slot = PL.RowSlot(row)
  local m = ls.skill[slot] or 0
  if m == 0 or EVT_IsSpecial(m) ~= (row == 0) then
    return 0
  end
  local lv = funcLuaCommand(C.CHARA_GET, n, 0) or 0
  if (ls.lv[slot] or 0) > lv then
    return 0
  end
  return m
end

-- the rows' guide: Aceptar, V / Y «Restablecer» (owner 2026-10-19: the only action on that key), then the declared
-- row actions (PL.MxGuideAdd chain: graft skill_table_host's row / X actions)
function PL.RowGuide()
  local t = {1847312674 --[[Aceptar]], PL.TX.BTN_RESET}
  local i = {PL.I_ENTER, PL.I_FUNC3}
  local c = {PL.K_ENTER, PL.K_FUNC3}
  local o = {0, 18}
  pcall(PL.MxGuideAdd, t, i, c, o)
  funcLuaMenuCommand(2209673388, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], t, i, o)
  funcLuaMenuCommand(452337289, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], c)
end

-- the basic-kit move of `row`: Character Reforged's own default for the character (owner 2026-10-19: never the
-- retail board's native item): the Hiper row the aura of his basic set (CMND_CHARACTERREFORGED_DEFAULT_SET), else
-- his learn list slot 9; rows 1-6 his learn list move (PL.KitMove: the merged chara_param, Character Reforged's
-- movesets); never a miximax fusion / mode-change carrier / Crear entry on the Hiper row, never an aura on rows 1-6
function PL.ResetKit(row)
  local m = 0
  if row == 0 and n ~= nil and n ~= 0 then
    local ok, aura = pcall(funcLuaCommand, @crc:CMND_CHARACTERREFORGED_DEFAULT_SET@, n)
    m = (ok and type(aura) == "number") and EVT_U32(aura) or 0
  end
  local special = EVT_IsSpecial(m)
  if row == 0 then
    if not special or m == PL.MX_FUSION or m == PL.MX_CREATE or m == PL.MC_CREATE
      or (PL.McIndex ~= nil and PL.McIndex(m) ~= nil) then
      m = 0
    end
  elseif special then
    m = 0
  end
  if m == 0 then
    m = PL.KitMove(row)
  end
  return m
end

-- Restablecer before the Fantasy slot fallbacks wrap it (EVT_ResetCoroutine below)
function PL.BaseResetCoroutine(row)
  if EVT_IsPrime() then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  local before = EVT_Snapshot()
  local old = EVT_Skill(row)
  local bslot = EVT_BoardSlot(row)
  local want = PL.ResetKit(row)
  if row == 0 and old ~= 0 and old ~= want then
    -- a miximax fusion / a mode change (carrier wmc_evt*) on the Hiper row goes first through Y with its own
    -- questions (fusion: «¿Quitar el miximax…?», No = nothing changes; change: the slot is emptied, then
    -- «¿Borrar también el cambio?»); the default Hiper is put back afterwards
    local mx = old == PL.MX_FUSION
    local mc = PL.McIndex ~= nil and PL.McIndex(EVT_U32(old)) ~= nil
    if mx or mc then
      EVT_RestoreCoroutine(0)
      if EVT_Skill(0) ~= 0 then
        return
      end
    end
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  local r
  if row == 0 then
    if want == 0 then
      r = EVT_Call(C.EVT_CLEAR, n, bslot, 3 --[[keepOpen 3: everything off]])
      EVT_TeamAuraPut(0)
    else
      r = EVT_BoardClear(bslot, true)              -- placed item off: the native Hiper (if still there) is back
      if EVT_BoardSkill(bslot) ~= 0 and EVT_BoardSkill(bslot) ~= want then
        r = EVT_Call(C.EVT_CLEAR, n, bslot, 3 --[[keepOpen 3: the retail native item off too]])
      end
      if EVT_BoardSkill(bslot) == want then
        EVT_TeamAuraPut(want)
      else
        EVT_Equip(0, want)                         -- board slot 8 + the team aura slot
      end
    end
  else
    r = EVT_BoardClear(bslot, true)                -- placed item off: the native move (if any) is back
    if EVT_IsSpecial(EVT_BoardSkill(bslot)) then   -- an aura native item (old save) never returns to a row
      r = EVT_Call(C.EVT_CLEAR, n, bslot, PL.AURA_CLEAR_NATIVE)
    end
    if want == 0 and EVT_BoardSkill(bslot) ~= 0 then
      r = EVT_Call(C.EVT_CLEAR, n, bslot, 3 --[[keepOpen 3: the retail native move off: no default = empty]])
    end
    local pos = EVT_ListPos(row)
    if want ~= 0 then
      EVT_Equip(row, want)                         -- match list (swaps if the move sat on another row) + board
    elseif EVT_ListSkill(pos) ~= 0 then
      funcLuaCommand(C.REMOVE_SKILL, n, pos)       -- empty kit slot: the row ends empty
    end
  end
  local now = EVT_Skill(row)
  funcLuaCommand(C.SE, now ~= old and SE_DECIDE or SE_NG)   -- already the kit move: error sound only
  EVT_Report(string.format("Reset row %d: %s -> %s (kit %s, state %s).\n%s", row, EVT_Name(old), EVT_Name(now),
    EVT_Name(want), tostring(r), EVT_Diff(before, EVT_Snapshot())), row)
  EVT_AfterChange()
  EVT_FocusRow(row)
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end
-- ===== X «Restablecer» / Y «Eliminar» END =====
