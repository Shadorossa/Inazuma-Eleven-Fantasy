-- All Keshin Armed › the «Armadura» tag of Character Reforged's player page: the hyper card (the keshin card of the
-- «Hiper» page) gets the game's armed badge on its bottom edge when this player can wear that keshin's armour.
-- Moved from Inazuma Fantasy's scripts\transform.lua (Fantasy.Mx.HiperArmour, command CMND_FANTASY_HIPER_ARMOUR) on
-- 2026-10-14; declared in content\game\armour_tag.toml. Character Reforged's page (graft plate_hiper_plate,
-- EVT_PHI.HiperArmourTag) asks the page slot CMND_EVT_HIPER_ARMOUR (docs/game/mods/all-keshin-armed.md §6): without
-- this mod nobody answers it and no tag is drawn.
--
-- The rule is this mod's own armour rule, read from the data through the framework (no id named here):
--   * the keshin's armour = the declared keshin -> armour pairs (content\transforms\armours.toml, the retail
--     armoured keshin plus this mod's), for this player's card: VRFW.form.armour_for(keshin, card);
--   * who may wear it = [rules] armour_wearers of content\transforms\rules.toml ("anyone": owner and non-owner
--     wearers), with the body-group mesh rules (armour_mesh_fallback / armour_no_mesh_groups) - inside armour_for;
--   * no armour item needed: content\skill_board\armour_slot.toml switches Character Reforged's armour_without_item on.
-- Nothing runs at load: the handler only runs when the page asks.

AuraReworked = AuraReworked or {}
AuraReworked.KeshinArmed = AuraReworked.KeshinArmed or {}
-- the part's switch (Mods options › All Keshin Armed, applied after a restart): off = nothing of this part runs
if VRFW.option("all_keshin_armed") == 0 then return end

local function u32(v)
  if type(v) == "boolean" then return v and 1 or 0 end
  v = tonumber(v) or 0
  if v < 0 then v = v + 4294967296 end
  return math.floor(v) % 4294967296
end

-- the chara_param of a character handle (0 = unknown)
local function card_of(handle)
  if handle == 0 then return 0 end
  local ok, record = pcall(VRFW.chara.record, handle)
  if ok and type(record) == "table" and record.param then return u32(record.param) end
  return 0
end

-- the saved owner of a match copy (nil = none / itself)
local function owner_of(handle)
  if handle == 0 then return nil end
  local ok, owner = pcall(VRFW.chara.owner_weak, handle)
  owner = ok and owner and u32(owner) or 0
  if owner == 0 or owner == handle then return nil end
  return owner
end

-- CMND_AURAREWORKED_KESHIN_HIPER_ARMOUR (alias CMND_EVT_HIPER_ARMOUR)(chara, keshin) -> armour, card: the armour this player
-- can wear with `keshin` (0 = none: not a keshin, or no armour for his body) and his chara_param (0 = handle unknown)
function AuraReworked.KeshinArmed.HiperArmour(chara_arg, keshin_arg)
  local chara, keshin = u32(chara_arg), u32(keshin_arg)
  if chara == 0 or keshin == 0 then return 0, 0 end
  local card = card_of(chara)
  if card == 0 then
    local owner = owner_of(chara)
    card = owner and card_of(owner) or 0
  end
  if card == 0 then return 0, 0 end
  -- an armour on the card is not a keshin: no tag (its keshin's card shows it)
  local okspirit, spirit = pcall(VRFW.form.spirit_of, keshin)
  if okspirit and u32(spirit) ~= 0 then return 0, card end
  local okarmour, armour = pcall(VRFW.form.armour_for, keshin, card)
  armour = okarmour and u32(armour) or 0
  if armour == keshin then armour = 0 end
  return armour, card
end
