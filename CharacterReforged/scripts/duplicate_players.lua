-- Character Reforged › the duplicate-players hook (docs/refactor/aura-mods-split.md «Duplicate players hook»; owner
-- request 2026-10-14: «lleva lo de deduplicar jugadores al duplicar una partida en una ranura al CharacterReforged
-- para que haga de enganche a lo que NoMoreRarities quiera»).
--
-- When a save is duplicated into another slot («X: duplicar» of the VR-Framework's slot screen,
-- docs/framework/save-slots.md), the framework hands the copy's bytes to the `slot_copy` handlers before it writes
-- them. This handler runs the pass of lib/duplicate_players/merge_pass.lua with the POLICY other mods declare as data:
-- [CharacterReforged.DuplicateRules.<name>] in their content\duplicate_rules\*.toml (keys: lib/duplicate_players/
-- rules.lua; No More Rarities declares one card per character and the 5★ normal card). No rule declared = nothing is
-- done (the copy is written as the framework copies it).
--
--   slot_copy   the copy's bytes, converted before they are written; a failure refuses the copy (the source slot is
--               untouched). The report (blob duplicate_players.txt of this mod) is written into the target slot at the
--               save engine's «copied» event (the engine resets the target's mod data when the copy is written).
--   slot_load   only when a rule asks for it (apply_on_load = true; No More Rarities does, owner request 2026-10-14: «al
--               entrar en la partida convierta a todos los jugadores a la misma rareza … y elimine los duplicados»): the
--               same pass on a player slot the save engine is about to load (its safe point: before the game reads the
--               file). Before the first rewrite of a save, a durable copy of the slot's file (global blob
--               save-backup-slot<N>-<stamp>-before-duplicate-rules.bin of this mod; never pruned) and the marker blob
--               duplicate_players_backup.txt in the slot (once per save: the engine resets a slot's mod data when another
--               save is copied into it or a new game starts there); then t:commit() (the slot service's own backup too,
--               written, read back). Idempotent: a converted save gives nothing to do and is not written. Report: blob
--               duplicate_players_load.txt. Never: the locked retail slot, reserved slots (a mode's own save), an empty
--               slot, the boot's own load (ev.after_load: the game already holds the save, the slot is not writable;
--               the pass then only counts what the next real load of that slot will do), nor while Inazuma Fantasy's
--               own load repair is on (it follows this same policy with more facts: fusions, team banks, move uses).
-- Exported: CharacterReforged.DuplicatePolicy() -> the merged policy (Inazuma Fantasy's load repair reads it).
-- The pass is a port of Inazuma Fantasy's «Ajustar save al mod» (its rules legend / one_card, which now follow this
-- policy); Inazuma Fantasy's own save rules (its hidden retail cards, beans, Hiper, movesets, Chronicle) run after this
-- handler (load order: the bytes chain through the handlers).

CharacterReforged = CharacterReforged or {}

local Rules = require "lib/duplicate_players/rules"
local CardFacts = require "lib/duplicate_players/card_facts"
local MergePass = require "lib/duplicate_players/merge_pass"
local T = require "lib/duplicate_players/save_tree"

local REPORT_BLOB = "duplicate_players.txt"

local function log(message) VRFW.log("duplicate_players: " .. message) end
local function warn(message) VRFW.warn("duplicate_players: " .. message) end

-- reports of converted copies waiting for their «copied» event: [target slot] = report text
local pending_reports = {}
local events_seen
do
  local ok, sequence = pcall(VRFW.slots.event_seq)
  events_seen = (ok and type(sequence) == "number") and sequence or 0
end

-- the slot events since the last look: a copy that went through gets its report
local function deliver_reports()
  local ok, sequence = pcall(VRFW.slots.event_seq)
  if not ok or type(sequence) ~= "number" then return end
  while events_seen < sequence do
    events_seen = events_seen + 1
    local ok_event, kind, first_slot, second_slot = pcall(VRFW.slots.event, events_seen)
    if ok_event and kind == "copied" and pending_reports[second_slot] then
      local text = pending_reports[second_slot]
      pending_reports[second_slot] = nil
      local ok_write, written, where = pcall(VRFW.save.set_blob, second_slot, REPORT_BLOB, text)
      if ok_write and written then
        log("COPY " .. first_slot .. "->" .. second_slot .. ": report written (blob " .. REPORT_BLOB .. ")")
      else
        warn("slot " .. second_slot .. ": " .. REPORT_BLOB .. " not written (" .. tostring(ok_write and where or written) .. ")")
      end
    elseif ok_event and (kind == "deleted" or kind == "new_game") then
      pending_reports[first_slot] = nil
    end
  end
end

-- the merged policy of every mod's duplicate rules (a fresh read: a mod switched on or off counts at once)
function CharacterReforged.DuplicatePolicy()
  return Rules.load()
end

VRFW.on("slot_copy", function(event)
  deliver_reports()
  local from, to = event.from, event.to
  local policy = Rules.load()
  if #policy.names == 0 then
    event.bytes = nil
    return nil
  end
  local tree, why = T.open_bytes(event.bytes)
  event.bytes = nil -- the save string is big: let it go
  if not tree then
    warn("COPY " .. from .. "->" .. to .. ": the save could not be read (" .. tostring(why) .. "): copy refused, slot " .. from .. " untouched")
    return { refuse = "Character Reforged: the save could not be read" }
  end
  local ok, report, outcome = pcall(function()
    return MergePass.run(tree, CardFacts.load(policy), policy)
  end)
  if not ok then
    warn("COPY " .. from .. "->" .. to .. ": the duplicate rules could not be applied (" .. tostring(report) .. "): copy refused, slot " .. from .. " untouched")
    return { refuse = "Character Reforged: the duplicate rules could not be applied" }
  end
  local merges = {}
  for _, merge in ipairs(outcome.merges) do
    merges[#merges + 1] = string.format("merge 0x%08X (card 0x%08X) -> kept 0x%08X (card 0x%08X)", merge.duplicate, merge.duplicate_card, merge.kept, merge.kept_card)
  end
  pending_reports[to] = string.format("slot %d -> slot %d\n%s\n\n%s\n\n== merges ==\n%s\n\n== players ==\n%s\n",
    from, to, Rules.describe(policy), MergePass.summary(report), table.concat(merges, "\n"), table.concat(report.lines, "\n"))
  log("COPY " .. from .. "->" .. to .. ": " .. Rules.describe(policy) .. "; " .. report.duplicates_merged .. " duplicates merged, "
    .. report.hidden_released .. " hidden cards released, " .. report.to_normal_rarity .. " normal cards to the normal rarity")
  if not tree:changed() then return nil end
  return { bytes = tree:commit() }
end)

-- ------------------------------------------------------------------------------------------------ on load

local LOAD_REPORT_BLOB = "duplicate_players_load.txt"
local BACKUP_MARKER_BLOB = "duplicate_players_backup.txt"
-- Inazuma Fantasy's own load repair («Reparar duplicados», its config [save_slots] repair_on_load) follows this policy
local INAZUMA_FANTASY = "inazuma_fantasy"
local INAZUMA_FANTASY_LOAD_REPAIR = "save_slots.repair_on_load"

local function inazuma_fantasy_repairs_on_load()
  local ok, value = pcall(VRFW.files.config, INAZUMA_FANTASY_LOAD_REPAIR, INAZUMA_FANTASY)
  return ok and value ~= nil and value ~= false
end

-- a player slot this pass may rewrite: not the locked retail save, not a mode's reserved slot
local function is_player_slot(slot)
  local ok_locked, locked = pcall(VRFW.slots.locked)
  if ok_locked and locked == slot then return false end
  local ok_reserved, reserved = pcall(VRFW.slots.reserved, slot)
  if ok_reserved and reserved then return false end
  return true
end

-- The durable copy of the slot's file, once per save: { done = true, where = text[, earlier = true] } or
-- { done = false, why = text }. A save that already has its marker is not copied again.
local function backup_once(slot)
  local ok_marker, marker = pcall(VRFW.save.get_blob, slot, BACKUP_MARKER_BLOB)
  if ok_marker and type(marker) == "string" and marker ~= "" then
    return { done = true, where = marker:match("^backup: ([^\n]+)") or "(see the marker)", earlier = true }
  end
  if type(VRFW.slots.read_file) ~= "function" then
    return { done = false, why = "this VR-Framework cannot read a slot's file (VRFW.slots.read_file)" }
  end
  local ok_read, bytes, why = pcall(VRFW.slots.read_file, slot)
  if not ok_read or type(bytes) ~= "string" or #bytes == 0 then
    return { done = false, why = "slot " .. slot .. " not read (" .. tostring(ok_read and why or bytes) .. ")" }
  end
  local ok_stamp, stamp = pcall(VRFW.time.file_stamp)
  if ok_stamp and type(stamp) == "string" then
    stamp = stamp:lower():gsub("[^%w%-]", "-")
  else
    stamp = tostring(VRFW.now())
  end
  local name = string.format("save-backup-slot%d-%s-before-duplicate-rules.bin", slot, stamp)
  local size = #bytes
  local ok_write, written, where = pcall(VRFW.save.blob_write, name, bytes, "global")
  bytes = nil
  collectgarbage()
  if not ok_write or not written then
    return { done = false, why = "the copy " .. name .. " was not written (" .. tostring(ok_write and where or written) .. ")" }
  end
  local text = string.format("backup: %s\nslot %d, %d bytes, before the first load pass of the duplicate rules (%s)\n",
    tostring(where), slot, size, stamp)
  pcall(VRFW.save.set_blob, slot, BACKUP_MARKER_BLOB, text)
  return { done = true, where = tostring(where) }
end

VRFW.on("slot_load", function(event)
  deliver_reports()
  local slot = event.slot
  if not event.has_data or not is_player_slot(slot) then return nil end
  local policy = Rules.load()
  if #policy.names == 0 or not policy.apply_on_load then return nil end
  if inazuma_fantasy_repairs_on_load() then
    log("LOAD slot " .. slot .. ": left to Inazuma Fantasy's load repair (it follows the same rules: " .. Rules.describe(policy) .. ")")
    return nil
  end
  local tree, why = T.open_slot(slot)
  if not tree then
    warn("LOAD slot " .. slot .. ": the save could not be read (" .. tostring(why) .. "): the slot loads as it is")
    return nil
  end
  local ok, report, outcome = pcall(function()
    return MergePass.run(tree, CardFacts.load(policy), policy)
  end)
  if not ok then
    warn("LOAD slot " .. slot .. ": the duplicate rules could not be applied (" .. tostring(report) .. "): the slot loads as it is")
    return nil
  end
  if not tree:changed() then
    log("LOAD slot " .. slot .. ": nothing to change (" .. report.players .. " players; " .. Rules.describe(policy) .. ")")
    return nil
  end
  local counts = report.to_normal_rarity .. " normal cards to rarity " .. tostring(policy.normal_card_rarity) .. ", "
    .. report.duplicates_merged .. " duplicates merged, " .. report.hidden_released .. " hidden cards released"
  if event.after_load then
    -- the boot's own load: the game already holds this save and the slot is not writable
    log("LOAD slot " .. slot .. " (the save read at boot, not writable): waiting for the next load of this slot: " .. counts)
    return nil
  end
  local backup = backup_once(slot)
  if backup.done and not backup.earlier then
    log("LOAD slot " .. slot .. ": backup of the save before the duplicate rules -> " .. backup.where)
  elseif not backup.done then
    warn("LOAD slot " .. slot .. ": no durable backup (" .. backup.why .. "); the slot service's own backup (backups\\slot"
      .. slot .. ") holds the original")
  end
  local ok_commit, written = pcall(function() return tree:commit() end)
  if not ok_commit or not written then
    warn("LOAD slot " .. slot .. ": the save was not written (" .. tostring(ok_commit and "nothing written" or written)
      .. "): the slot loads as it is")
    return nil
  end
  log("LOAD slot " .. slot .. ": " .. Rules.describe(policy) .. "; " .. counts .. " (" .. report.players .. " players, "
    .. report.bytes_patched .. " bytes patched)")
  for _, line in ipairs(report.lines) do log("LOAD slot " .. slot .. ": " .. line) end
  local merges = {}
  for _, merge in ipairs(outcome.merges) do
    local line = string.format("duplicate removed: character 0x%08X kept 0x%08X (card 0x%08X) removed 0x%08X (card 0x%08X)",
      merge.character or 0, merge.kept, merge.kept_card, merge.duplicate, merge.duplicate_card)
    log("LOAD slot " .. slot .. ": " .. line)
    merges[#merges + 1] = line
  end
  local text = string.format("LOAD slot %d (backup: %s)\n%s\n\n%s\n\n== duplicates removed ==\n%s\n\n== players ==\n%s\n",
    slot, backup.done and backup.where or ("none: " .. backup.why), Rules.describe(policy), MergePass.summary(report),
    table.concat(merges, "\n"), table.concat(report.lines, "\n"))
  local ok_blob, blob_written, where = pcall(VRFW.save.set_blob, slot, LOAD_REPORT_BLOB, text)
  if not ok_blob or not blob_written then
    warn("slot " .. slot .. ": " .. LOAD_REPORT_BLOB .. " not written (" .. tostring(ok_blob and where or blob_written) .. ")")
  end
  return nil
end)
