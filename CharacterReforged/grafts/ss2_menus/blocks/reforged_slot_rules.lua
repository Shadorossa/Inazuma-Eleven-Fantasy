-- ===== Character Reforged slot rules (2026-10-14) =====
-- What each slot accepts is Character Reforged's rule (scripts\skill_set.lua, CMND_CHARACTERREFORGED_CAN_PLACE: the
-- data of content\skill_set\*.toml + the place rules other mods register with CharacterReforged.AddPlaceRule, e.g. a
-- «no duplicate move» plugin). Slots: rows 1-6 = 1..6, the Hiper row's aura half = 7, its mix half = 8. The picker
-- (ss2_pick_1 block of ability_list_menu) greys / refuses through the same command (params evt_ss_pick_slot /
-- evt_ss_pick_chara set here around EVT_PickCoroutine); every equip of this screen (pick, player set, import, reset)
-- asks it in EVT_Equip. No answer (Character Reforged's scripts off) = allowed. PL fields only (no main-chunk locals).
PL.CR_CAN_PLACE = @crc:CMND_CHARACTERREFORGED_CAN_PLACE@                    -- crc32("CMND_CHARACTERREFORGED_CAN_PLACE")
PL.CR_KEY_SLOT = 4199810934                  -- crc32("evt_ss_pick_slot")
PL.CR_KEY_CHARA = 3798840340                 -- crc32("evt_ss_pick_chara")
PL.CR_KEY_BOARD = 850416018                  -- crc32("evt_ss_pick_board"): the row's board slot (place rules "board"; -1 none)
function PL.CrSlotOf(row)
  if row == nil then
    return 0
  end
  if row == 0 then
    return PL.hs_half == 1 and 8 or 7
  end
  return row
end
PL.CR_PLACE_RULES = @crc:CMND_CHARACTERREFORGED_PLACE_RULES@               -- crc32("CMND_CHARACTERREFORGED_PLACE_RULES")
-- the place rules other mods declare as data ([CharacterReforged.PlaceRules.<name>]): { {id, board}, … }, read once
function PL.CrRules()
  if PL.cr_rules ~= nil then
    return PL.cr_rules
  end
  local r = {pcall(funcLuaCommand, PL.CR_PLACE_RULES)}
  local out = {}
  if r[1] == true and type(r[2]) == "number" then
    for i = 1, r[2] do
      local id, kind = r[1 + 2 * i], r[2 + 2 * i]
      if type(id) == "number" and id ~= 0 then
        out[#out + 1] = {id = id, board = kind == 1}
      end
    end
  end
  PL.cr_rules = out
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "Character Reforged place rules", #out)
  return out
end
function PL.CrCanPlace(slot, skill)
  if skill == nil or skill == 0 or n == nil or n == 0 then
    return true, ""
  end
  local ok, res, why = pcall(funcLuaCommand, PL.CR_CAN_PLACE, n, slot, skill)
  if ok and res == false then
    return false, why or ""
  end
  for _, r in ipairs(PL.CrRules()) do
    local a = slot
    if r.board then
      a = (slot == 7) and EVT_HIPER_SLOT or ((slot >= 1 and slot <= 6) and EVT_ListPos(slot) or nil)
    end
    if a ~= nil then
      local okr, res2 = pcall(funcLuaCommand, r.id, n, a, skill)
      if okr and res2 == false then
        return false, string.format("rule %08X", EVT_U32(r.id))
      end
    end
  end
  return true, ""
end
PL.CrPrevPick = EVT_PickCoroutine
function EVT_PickCoroutine(row)
  P_Set(PL.CR_KEY_SLOT, PL.CrSlotOf(row))
  P_Set(PL.CR_KEY_CHARA, n or 0)
  local slot = PL.CrSlotOf(row)
  P_Set(PL.CR_KEY_BOARD, slot == 7 and EVT_HIPER_SLOT or ((slot >= 1 and slot <= 6) and EVT_ListPos(slot) or -1))
  local ok, err = pcall(PL.CrPrevPick, row)
  VRFW_Param.Clear(PL.CR_KEY_SLOT)
  VRFW_Param.Clear(PL.CR_KEY_CHARA)
  VRFW_Param.Clear(PL.CR_KEY_BOARD)
  if not ok then
    error(err, 0)
  end
end
PL.CrPrevEquip = EVT_Equip
function EVT_Equip(row, skill, inv_hint, cur)
  local slot = PL.CrSlotOf(row)
  if row == 0 and PL.HsKind ~= nil and skill ~= nil and skill ~= 0 then
    local kind = PL.HsKind(skill)                 -- the half the move goes to (IF's two Hiper slots)
    if kind == 1 then
      slot = 8
    elseif kind == 0 or kind == 2 then
      slot = 7
    end
  end
  local allowed, why = PL.CrCanPlace(slot, skill)
  if not allowed then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "equip refused by Character Reforged", row, slot,
      string.format("%08X", EVT_U32(skill or 0)), tostring(why))
    funcLuaCommand(C.SE, 2086672038 --[[sy0003]])
    return false
  end
  return PL.CrPrevEquip(row, skill, inv_hint, cur)
end
-- ===== Character Reforged slot rules END =====
