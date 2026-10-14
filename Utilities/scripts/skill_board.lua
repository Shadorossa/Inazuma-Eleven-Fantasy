-- Utilities › the old [skill_board] armour_without_item setting (until 1.15.8): the skill board's armour slot without
-- the armour item moved to Character Reforged on 2026-10-14 (owner decision), off unless All Keshin Armed is active
-- (Character Reforged's scripts\armour_slot.lua; docs/game/mods/all-keshin-armed.md §2.2). A config that still has the
-- key is ignored with one log line.

local ok, cfg = pcall(function()
  return VRFW.files and VRFW.files.config and VRFW.files.config("skill_board")
end)
if ok and type(cfg) == "table" and cfg.armour_without_item ~= nil then
  VRFW.log("skill_board: [skill_board] armour_without_item = " .. tostring(cfg.armour_without_item)
    .. " is ignored: the armour slot without the item is Character Reforged's now, on only with All Keshin Armed")
end
