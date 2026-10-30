-- ===== unlimited copies BEGIN =====
-- Unlimited copies (VR-Framework VRFW_Copies, docs/framework/unlimited-copies.md): while a rule a mod declares holds for
-- an item, one owned copy serves every player. The equip below hands the move a handle the retail way (one copy added,
-- placed, removed again); when every copy was already in use the removal is refused and the owned count grows. The
-- wrapper notes the owned count of the picked item and of every item on this player's board (a swap or a restore can
-- move them) and brings back any unlimited item whose count grew. Without a holding rule nothing changes. No new chunk
-- local (the chunk is close to the 200-locals limit): the state is in PL.
PL.CopiesPrevEquip = EVT_Equip
function EVT_Equip(row, skill, inv_hint, cur)
  if type(VRFW_Copies) ~= "table" then
    return PL.CopiesPrevEquip(row, skill, inv_hint, cur)
  end
  local okS, before = pcall(function()
    local ids = {EVT_U32(skill)}
    for b = 0, 8 do
      ids[#ids + 1] = (EVT_BoardSkill(b))
    end
    return VRFW_Copies.Snapshot(ids)
  end)
  if not okS or next(before) == nil then
    return PL.CopiesPrevEquip(row, skill, inv_hint, cur)
  end
  PL.CopiesPrevEquip(row, skill, inv_hint, cur)    -- not inside a pcall: it may yield (messages)
  local okR, err = pcall(VRFW_Copies.Restore, before, function(id)
    for b = 0, 8 do
      local s, h = EVT_BoardSkill(b)
      if s == id and h ~= nil and h ~= 0 then
        return h
      end
    end
    return nil
  end)
  if not okR then
    pcall(funcLuaCommand, C.EVT_LOG, "unlimited_copies", "restore error", tostring(err))
  end
end

PL.CopiesPrevOnInit = OnInit
function OnInit(...)
  if type(VRFW_Copies) == "table" then
    pcall(VRFW_Copies.Reset)                       -- a key item won since the last visit counts now
  end
  return PL.CopiesPrevOnInit(...)
end
-- ===== unlimited copies END =====
