-- menu_engine: the team dock's kit icon (soccer_team_dock_menu, SetupUniformIcom). The retail icon comes from the
-- dock's kit item (its inventory handle) and, only when there is no handle, from the kit id. A dock whose handle gives
-- no icon (a kit the save does not hold as an item, e.g. a team the framework put in the dock) gets the kit id's icon
-- (the uniform's item icon, CMND 1018497889, as the retail fallback asks it). Runs on each SetupUniformIcom call (the
-- dock's open and every kit change); no engine call at load time.
if VRFW_Host ~= nil then
  local STEM = "soccer_team_dock_menu"
  local K = {
    ICON_OF_ITEM = 2662166687,       -- (inventory handle, 0) -> icon id (retail SetupUniformIcom)
    ICON_OF_KIT = 1018497889,        -- (uniform id) -> icon id
    NODE_VISIBLE = 3405944500,       -- (layer, node, on, index)
    NODE_SPRITE = 3508889864,        -- (layer, index, node, sprite slot, icon id)
    BASE = 2424767532, ICON = 177988645, SHADOW = 2475865503,   -- the kit layer's nodes the retail shows with an icon
    ICON_SLOT = 2858263531, SHADOW_SLOT = 861205073,
    LOG = VRFW_Cmd.EVT_LOG,
  }
  local logged = false

  VRFW_Host.on(STEM, "SetupUniformIcom", {
    id = "menu_engine.kit_icon_from_kit_id", phase = "after",
    fn = function(_, layer, index)
      if type(GetTeamDockUniformInvHdl) ~= "function" or type(GetTeamDockUniformId) ~= "function" then
        return
      end
      local okh, handle = pcall(GetTeamDockUniformInvHdl)
      if not okh or (tonumber(handle) or 0) == 0 then
        return                         -- no handle: the retail already asked the kit id
      end
      local oki, icon = pcall(funcLuaCommand, K.ICON_OF_ITEM, handle, 0)
      if oki and icon ~= nil and icon ~= 0 then
        return                         -- the item has its icon
      end
      local oku, kit = pcall(GetTeamDockUniformId)
      if not oku or (tonumber(kit) or 0) == 0 then
        return
      end
      local okk, from_kit = pcall(funcLuaCommand, K.ICON_OF_KIT, kit)
      if not okk or from_kit == nil or from_kit == 0 then
        return
      end
      for _, node in ipairs({ K.BASE, K.ICON, K.SHADOW }) do
        pcall(funcLuaMenuCommand, K.NODE_VISIBLE, layer, node, true, index)
      end
      pcall(funcLuaMenuCommand, K.NODE_SPRITE, layer, index, K.ICON, K.ICON_SLOT, from_kit)
      pcall(funcLuaMenuCommand, K.NODE_SPRITE, layer, index, K.SHADOW, K.SHADOW_SLOT, from_kit)
      if not logged then
        logged = true
        pcall(funcLuaCommand, K.LOG, "VRFW team dock",
          string.format("kit icon from the kit id 0x%08X (its item handle gives none)", kit))
      end
    end,
  })
end
