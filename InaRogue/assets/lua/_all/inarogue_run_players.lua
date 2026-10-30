-- InaRogue: the one way the INAROGUE screens create a run player in the INAROGUE save (the main menu's team builder
-- and the route map's signings). CMND_ADD_PARTY at the run level into no team set (argument 10 = 16: the club roster
-- of the retail Banco), then the INAROGUE player tag and «Sin rol» (no creation-time coach / manager role). Its own
-- arguments rather than VRFW_Recruit.Sign: a run player is a rarity 0 copy, the same card may be in the club more than
-- once, and nothing is autosaved or cleared after the add. Definitions only: no engine call at load.
--   InaRogue_RunPlayers.Create(param) -> handle, or 0 + the command's answer when the game refused
InaRogue_RunPlayers = type(InaRogue_RunPlayers) == "table" and InaRogue_RunPlayers or {}
do
  local R = InaRogue_RunPlayers
  R.ADD_PARTY = 1885323816      -- CMND_ADD_PARTY (AddPartyCore defaults)
  R.SET_ATTRIBUTE = 1525180681  -- (handle, mask, on): sets / clears attribute bits
  R.NO_ROLE = 3766629437        -- CMND_EVT_RL_NO_ROLE (handle): the creation-time coach / manager role cleared
  R.TAG = 268435456             -- 0x10000000: the INAROGUE player attribute
  R.LEVEL = 5                   -- the run level
  R.TEAM_SET_NONE = 16          -- CMND_ADD_PARTY argument 10: no team set

  local function call(cmd, ...)
    local r = table.pack(pcall(funcLuaCommand, cmd, ...))
    if not r[1] then
      return nil
    end
    return table.unpack(r, 2, r.n)
  end

  function R.Create(param)
    local handle = call(R.ADD_PARTY, param, R.LEVEL, false, false, 0, 0, false, false, false, R.TEAM_SET_NONE, 255, 255,
      0, false, false, false, 0, false, false)
    if type(handle) ~= "number" or handle == 0 then
      return 0, handle
    end
    call(R.SET_ATTRIBUTE, handle, R.TAG, true)
    call(R.NO_ROLE, handle)
    return handle
  end
end
