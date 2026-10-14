-- Character Reforged's declaration for Utilities' «Banco» COMANDOS popup (research/grafts/cr_bank_skill_table,
-- docs/game/ui/bank-commands.md §4). Utilities reads Utilities.BankCommands.SkillTable at call time; this file answers
-- it through a metatable field, so the option row character_reforged.skill_set_view is read only then: the new set view
-- on = the skill table (evt_skill_slot_menu) with the formation's equip parameters (the stale «open the original
-- board» request key evt_ss_open_board is deleted before and after); off = nil (Utilities' default: the retail board).
-- No engine call at load.
Utilities = Utilities or {}
Utilities.BankCommands = Utilities.BankCommands or {}
CharacterReforged = CharacterReforged or {}
CharacterReforged.BANK_SKILL_TABLE = {Menu = 1041963128 --[[evt_skill_slot_menu]], Params = "equip",
  Clear = {1881233917 --[[evt_ss_open_board]]}}
-- Utilities asks when «Tabla de habilidades» is chosen in the popup: the option is read then, with one log line
-- (CharacterReforged.EntryOpensSkillTable, assets\lua\_all\character_reforged_skill_table_entry.lua)
function CharacterReforged.BankSkillSetOn()
  if CharacterReforged.EntryOpensSkillTable == nil then
    return false
  end
  return CharacterReforged.EntryOpensSkillTable("bank (Utilities' Banco popup)")
end
do
  local U = Utilities.BankCommands
  if rawget(U, "SkillTable") == nil then
    local mt = getmetatable(U) or {}
    local prev = mt.__index
    mt.__index = function(t, k)
      if k == "SkillTable" then
        return CharacterReforged.BankSkillSetOn() and CharacterReforged.BANK_SKILL_TABLE or nil
      end
      if type(prev) == "function" then
        return prev(t, k)
      elseif type(prev) == "table" then
        return prev[k]
      end
      return nil
    end
    setmetatable(U, mt)
  end
end
