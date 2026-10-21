-- plate member (VR-Framework base feature, docs/framework/player-pages.md «Plate member»): a screen that shows a team's
-- member on the player plate as a temporary character (players-universe mode, e.g. a line-up viewer) names him with the
-- game parameters VRFW.plate_team (team id) and VRFW.plate_slot (member slot) while its page is up, and clears them
-- after. Then:
-- * the plate's equipment rows show the items of that member's row of the team (CMND_VRFW_TEAM_MEMBER_GEAR: boots,
--   bracelet, pendant, special as the team build wrote them; the match equips the same items itself);
-- * VRFW_PlateMember.Kit() gives his team's kit (the page's 3D model wears it).
-- Without the parameters nothing changes. No engine call at load time.
VRFW_PlateMember = type(VRFW_PlateMember) == "table" and VRFW_PlateMember or {}
if VRFW_PlateMember.Gear == nil then
  local M = VRFW_PlateMember
  M.P_TEAM = 1930590710                 -- crc32 of VRFW.plate_team
  M.P_SLOT = 469565326                  -- crc32 of VRFW.plate_slot
  M.C = {
    PARAM_EXISTS = 2947612279, PARAM_GET = 3522198769,
    GEAR = 2361688718,                  -- CMND_VRFW_TEAM_MEMBER_GEAR(team, slot) -> found, kit, 4 items
    INV_OF_SLOT = 128658370,            -- (charaStHdl, equip slot) -> the inventory handle worn there
    ITEM_OF_INV = 2662166687,           -- (inventory handle, 0) -> its item id
  }
  M.ITEM_SLOTS = 4                      -- equip slots 0-3 (boots, bracelet, pendant, special); 4 (costume) is not in a row

  local function Param(k)
    local ok, has = pcall(funcLuaCommand, M.C.PARAM_EXISTS, k)
    if not (ok and has == true) then
      return nil
    end
    local okv, v = pcall(funcLuaCommand, M.C.PARAM_GET, k)
    return (okv and type(v) == "number") and v or nil
  end

  -- the named member: team id, slot; nil = none
  function M.Member()
    local team, slot = Param(M.P_TEAM), Param(M.P_SLOT)
    if team == nil or slot == nil or team == 0 then
      return nil
    end
    return team, slot
  end

  -- the named member's team kit and his items (indexed by equip slot 0-3); nil = no member / unknown team
  function M.Gear()
    local team, slot = M.Member()
    if team == nil then
      return nil
    end
    local ok, found, kit, a, b, c, d = pcall(funcLuaCommand, M.C.GEAR, team, slot)
    if not (ok and found == true) then
      return nil
    end
    return kit, {[0] = a or 0, b or 0, c or 0, d or 0}
  end

  function M.Kit()
    local kit = M.Gear()
    return (type(kit) == "number" and kit ~= 0) and kit or nil
  end

  -- the retail row drawer (personal_plate_inc): while a member is named, its two equipment reads answer from his row
  -- (the temporary character wears nothing); every other call is the game's
  local function Wrap(name, make)
    local cur = _ENV[name]
    if type(cur) ~= "function" or M.wrapped == cur then
      return
    end
    M.wrapped = make(cur)
    _ENV[name] = M.wrapped
  end
  Wrap("SetupPersonalPlateEquipItem", function(orig)
    return function(i, hdl, ...)
      local kit, items = M.Gear()
      if items == nil then
        return orig(i, hdl, ...)
      end
      local real = funcLuaCommand
      local tokens = {}
      funcLuaCommand = function(cmd, a, b, ...)
        if cmd == M.C.INV_OF_SLOT and a == hdl and type(b) == "number" then
          local it = b >= 0 and b < M.ITEM_SLOTS and items[b] or 0
          if it == 0 then
            return 0
          end
          local token = -1000 - b
          tokens[token] = it
          return token
        end
        if cmd == M.C.ITEM_OF_INV and tokens[a] ~= nil then
          return tokens[a]
        end
        return real(cmd, a, b, ...)
      end
      local ok, r = pcall(orig, i, hdl, ...)
      funcLuaCommand = real
      if not ok then
        error(r, 0)
      end
      return r
    end
  end)
end
