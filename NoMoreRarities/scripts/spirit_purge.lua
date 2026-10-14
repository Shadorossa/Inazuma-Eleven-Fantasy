-- No More Rarities › a duplicated save loses its player spirits (owner decision 2026-10-14; design
-- docs/game/characters/rarity-removal.md §9.1).
--
-- With No More Rarities on, the spirit screens and their entries are gone (assets\lua\_all\no_more_rarities_spirits.lua)
-- and a new spirit drop is recruited as the player, so the spirits a save already holds are hidden and unused. When the
-- player duplicates a save through the VR-Framework's slot screen («Duplicar», docs/framework/save-slots.md), the
-- framework hands the copy's bytes to the `slot_duplicate` handlers (every duplicate of a player slot, the locked
-- retail save included) before it writes them: this handler empties every player spirit of the NEW copy
-- (lib/spirit_purge.lua). The source save is never touched; the target slot gets the slot service's own backup before the
-- write (backups\slot<N>\, as every copy) and is read back by it.
--
-- Never a reserved slot (a mode's own save, e.g. INAROGUE: the slot service refuses copies from / into one anyway).
-- No More Rarities off = this script does not run = copies are written as the framework makes them. A copy whose save
-- cannot be read or purged is refused (the source untouched, the target not written), as Character Reforged's
-- duplicate-players hook does. Runs after Character Reforged's `slot_copy` pass (load order: the bytes chain).
-- Log: one line per copy «NoMoreRarities spirit purge: COPY a->b: N spirit entries (C cards) removed …».

local SpiritPurge = require "lib/spirit_purge"

local function log(message) VRFW.log("NoMoreRarities spirit purge: " .. message) end
local function warn(message) VRFW.warn("NoMoreRarities spirit purge: " .. message) end

local function is_reserved(slot)
  local ok, reserved = pcall(VRFW.slots.reserved, slot)
  return ok and reserved and true or false
end

VRFW.on("slot_duplicate", function(event)
  local from, to = event.from, event.to
  local copy = "COPY " .. tostring(from) .. "->" .. tostring(to)
  if is_reserved(from) or is_reserved(to) then
    event.bytes = nil
    log(copy .. ": a reserved slot (a mode's own save): spirits left as they are")
    return nil
  end
  local tree, why = VRFW.savetree.open_bytes(event.bytes)
  event.bytes = nil -- the save string is big: let it go
  if not tree then
    warn(copy .. ": the save could not be read (" .. tostring(why) .. "): copy refused, slot " .. tostring(from) .. " untouched")
    return { refuse = "No More Rarities: the save could not be read" }
  end
  local ok, report = pcall(SpiritPurge.run, tree)
  if not ok then
    warn(copy .. ": the spirits could not be removed (" .. tostring(report) .. "): copy refused, slot " .. tostring(from) .. " untouched")
    return { refuse = "No More Rarities: the spirits could not be removed" }
  end
  local source = event.from_locked and " (the locked retail save)" or ""
  log(copy .. source .. ": " .. SpiritPurge.summary(report))
  if not tree:changed() then return nil end
  return { bytes = tree:commit() }
end)
