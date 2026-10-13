-- Utilities › keshin armour slot without the item (config.toml [skill_board] armour_without_item, default true;
-- content\game\skill_board.toml, docs/game/mods/all-keshin-armed.md §2).
-- When the ability board's armour slot beside a keshin piece is set, the game looks for the player's copy of the armour
-- item (ArmedItemHandle) and does nothing without one. After that look-up, when it found none: the armour the game's
-- change_aura_skill_config names for (keshin, card) gets one copy (Item.Add) and the look-up runs again, so the
-- game's own decide goes on with the new copy. No id is named here.

local cfg = (VRFW.files and VRFW.files.config and VRFW.files.config("skill_board")) or {}
local on = cfg.armour_without_item ~= false

local function hex(v)
  v = (tonumber(v) or 0) % 4294967296
  return string.format("0x%04X%04X", math.floor(v / 65536), v % 65536)
end

local BUF_ARMED, BUF_ADD

local function u32_at(p)
  if not p or p == 0 then
    return 0
  end
  local ok, v = pcall(VRFW.mem.read, "u32", p)
  return ok and v or 0
end

VRFW.on("hook:Utilities.ArmedSlotItem:post", function(ev)
  if not on then
    return nil
  end
  local out, keshin_p, card_p, flag = ev.args[1], ev.args[2], ev.args[3], ev.args[4]
  if u32_at(out) ~= 0 then
    return nil -- the player owns a copy: the game's rule
  end
  BUF_ARMED = BUF_ARMED or VRFW.mem.buffer("utilities_armed_of_card", 16)
  BUF_ADD = BUF_ADD or VRFW.mem.buffer("utilities_item_add", 64)
  pcall(VRFW.mem.write, "u32", BUF_ARMED, 0)
  if not pcall(VRFW.call, "Utilities.AuraChangeOfCard", BUF_ARMED, keshin_p, card_p) then
    return nil
  end
  local armed = u32_at(BUF_ARMED)
  if armed == 0 then
    return nil -- no armour for this keshin and card: the game's rule
  end
  local ok, err = pcall(VRFW.call, "Utilities.ItemAdd", BUF_ADD, armed, 1, 0)
  if not ok then
    VRFW.warn("skill_board: armour item " .. hex(armed) .. " not added: " .. tostring(err))
    return nil
  end
  pcall(VRFW.call, "Utilities.ArmedItemHandle", out, keshin_p, card_p, flag or 1)
  VRFW.log(string.format("skill_board: armour slot of keshin %s (card %s): no copy of armour %s owned, one added -> handle %s",
    hex(u32_at(keshin_p)), hex(u32_at(card_p)), hex(armed), hex(u32_at(out))))
  return nil
end)

function Utilities.ArmourWithoutItemOn()
  return on and VRFW.is_on("Utilities.ArmedSlotItem")
end
