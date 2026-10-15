-- True Hissatsu › the move-rank items on Character Reforged's «Fantasy» skill table (evt_skill_slot_menu; docs/game/
-- mechanics/move-rank-items.md). SOURCE of the hook file rank_items_skill_table.lua (gen_hooks.py fills the @crc
-- placeholders and the shared part rank_items_core.src.lua; edit the sources, run the script).
-- The screen is Character Reforged's; this mod adds a ROW ACTION as data (content\menus\skill_table_rank_items.toml:
-- [[entry]] host = "character_reforged.skill_table.row_action", action = { lua = "TrueHissatsu.SkillTableRankItem" })
-- and the screen's host (graft skill_table_host) calls TrueHissatsu.SkillTableRankItem(phase, ctx) on the focused row:
--   "available" -> a move row (1-6) with a move while True Hissatsu's script answers: the CMD_FUNC1 key (Start, as in
--                  Inazuma Fantasy's table) is this action;
--   "guide"     -> the guide entry «<Start> Subir nivel» on every such row (owner 2026-10-14: the guide teaches the key;
--                  without a book or a manual the press says why, with the retail «cannot» sound);
--   "press"     -> the item that applies to the move's grade (book below the second-to-last level, manual from the
--                  second-to-last to the last), the Sí / No window «¿Usar X con Y? old → new (tienes N)», then the rules
--                  apply it and one copy leaves the bag; a refusal says why. One log line per use / refusal.
-- Definitions only at chunk load.
do
@CORE@

  function TrueHissatsu.SkillTableRankItem(phase, ctx)
    local SkillTable = type(CharacterReforged) == "table" and CharacterReforged.SkillTable or nil
    if SkillTable == nil or type(ctx) ~= "table" then
      return nil
    end
    if phase == "available" then
      return type(ctx.row) == "number" and ctx.row >= 1 and (ctx.move or 0) ~= 0 and RankItems.Active()
    elseif phase == "guide" then
      return RankItems.Active()
    elseif phase ~= "press" then
      return nil
    end
    local plan = RankItems.Plan(ctx.chara, ctx.move, SkillTable.MoveName(ctx.move))
    if plan.refusal ~= nil then
      RankItems.LogRefused("skill_table", plan)
      SkillTable.Sound("refused")
      SkillTable.Message(RankItems.RefusalText(plan))
      return
    end
    SkillTable.Sound("decide")
    if not SkillTable.Confirm(RankItems.ConfirmText(plan)) then
      RankItems.Log("skill_table", "cancelled", "chara", tostring(ctx.chara), "move", RankItems.Hex(ctx.move))
      return
    end
    local used, text = RankItems.Use("skill_table", plan)
    if not used then
      SkillTable.Sound("refused")
      SkillTable.Message(text)
      return
    end
    SkillTable.Refresh()
    SkillTable.Sound("decide")
    SkillTable.Message(text)
  end
end
