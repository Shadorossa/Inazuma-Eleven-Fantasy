-- anim_engine (VR-Framework), celebrations: the goal-celebration picker («Ajustes de celebración de gol»,
-- soccer_performance_change_menu) hides a mod's EXCLUSIVE celebration from the players that may not use it
-- (docs/app/anim-engine.md «Celebraciones», docs/game/mechanics/celebraciones.md §2.3).
--
-- Own code: wrappers of two retail globals, each one calls the original.
-- * UpdateListItem: remembers the player of the focused row (the same handle the retail list keeps in `l1`).
-- * InitPerformanceInfoArray (builds the picker list from soccer_performance_config): while it runs, the validity
--   answer of a row (funcLuaCommand(3399635787, i, 3)) is AND-ed with CMND_EVT_ANIM_CELEBR_VISIBLE(player, its
--   performanceId); the global is restored right after (the function does not yield).
-- Without the part (old framework, part off) the command fails and every row stays as the game says. No engine call
-- at load time.

local function CEL_Crc(s)
  local crc = 0xFFFFFFFF
  for i = 1, #s do
    crc = bit32.bxor(crc, string.byte(s, i))
    for _ = 1, 8 do
      if bit32.band(crc, 1) ~= 0 then
        crc = bit32.bxor(bit32.rshift(crc, 1), 0xEDB88320)
      else
        crc = bit32.rshift(crc, 1)
      end
    end
  end
  return bit32.bxor(crc, 0xFFFFFFFF)
end

local CEL = {
  VISIBLE = CEL_Crc("CMND_EVT_ANIM_CELEBR_VISIBLE"),  -- (handle, performanceId) -> bool
  INFO = 3399635787,                                  -- (index, field): 3 = valid, 4 = performanceId
  ITEM = 1076657304,                                  -- win05_36_performance_chara_list_item
  hdl = nil,
}

local CEL_UpdateListItem = UpdateListItem
function UpdateListItem(a1, a2, a3, a4)
  if a1 == CEL.ITEM and a4 and a3 ~= nil then
    CEL.hdl = a3
  end
  return CEL_UpdateListItem(a1, a2, a3, a4)
end

local CEL_InitPerformanceInfoArray = InitPerformanceInfoArray
function InitPerformanceInfoArray()
  local hdl = CEL.hdl
  local real = funcLuaCommand
  if hdl == nil or real == nil then
    return CEL_InitPerformanceInfoArray()
  end
  funcLuaCommand = function(cmd, a, b, ...)
    if cmd == CEL.INFO and b == 3 then
      local ok, valid = real(cmd, a, b, ...)
      if ok ~= false and valid ~= false then
        local okid, pid = real(CEL.INFO, a, 4)
        if okid ~= false and pid ~= nil and pid ~= 0 then
          local okv, vis = pcall(real, CEL.VISIBLE, hdl, pid)
          if okv and vis == false then
            return ok, false
          end
        end
      end
      return ok, valid
    end
    return real(cmd, a, b, ...)
  end
  local okc, err = pcall(CEL_InitPerformanceInfoArray)
  funcLuaCommand = real
  if not okc then
    error(err)
  end
end
