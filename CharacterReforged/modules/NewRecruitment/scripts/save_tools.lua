-- New Recruitment › its action of the VR-Framework's save adjust (Options › «Ajustar save»,
-- docs/framework/save-adjust.md). Declared in content\save_adjust\new_recruitment.toml; the framework calls the
-- function below by name.
--
--   remove_spirits   every player spirit of the save emptied (normal / Ídolo / Diamante / seasonal entries, the spirit
--                    «new» marks cleared; element and token spirits kept): the same pass as a duplicated save gets
--                    (lib/spirit_purge.lua, scripts\spirit_purge.lua; design docs/game/characters/rarity-removal.md §9.1).
--
-- The rarity of the normal cards and the duplicates are Character Reforged's actions (its pass runs the policy of
-- this module and No More Rarities, content\duplicate_rules\). The locked retail save and the reserved slots (a mode's
-- own save, e.g. INAROGUE: it keeps its spirits) never get here. Log: «save adjust: remove_spirits (slot N): <the purge's summary>».

local SpiritPurge = require "lib/spirit_purge"

NewRecruitment = NewRecruitment or {}
local SaveAdjust = {}
NewRecruitment.SaveAdjust = SaveAdjust

function SaveAdjust.remove_spirits(tree, event)
  local report = SpiritPurge.run(tree)
  local summary = SpiritPurge.summary(report)
  VRFW.log("save adjust: remove_spirits (slot " .. event.slot .. "): " .. summary)
  return { count = report.entries, log = summary }
end
