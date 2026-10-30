-- ===== EVT plate_pages item card list BEGIN =====
-- Character Reforged (graft plate_pages): the item picker (equip_menu_list, a layer group of the equipment menu with its
-- own script) hands the hovered item to the equipment screen's script (equip_menu_select, plate_pages G.ItemCardShow,
-- which draws the card and the stats panel's rows): after the game fills the card for the hovered item
-- (SetupEquipInfoWindow) it sends the item as the menu event CharacterReforged.ItemCardHover (VRFW_MenuEvent; 0 =
-- nothing hovered: the card hidden; -1 = the picker left: the slot's own item again), which the equipment screen's
-- script handles at once. (A cross-menu call reaches a menu, not one of its scripts.)
-- Wrappers only; nothing runs at load time. loader.log «picker hover <item>» once per hovered item.
EVT_ICL = EVT_ICL or {EVENT = "CharacterReforged.ItemCardHover", LOG = @crc:CMND_EVT_LOG@}

function EVT_ICL.Tell(item)
  if type(VRFW_MenuEvent) == "table" then
    VRFW_MenuEvent.Emit(EVT_ICL.EVENT, item)
  end
  if item ~= EVT_ICL.last then
    EVT_ICL.last = item
    pcall(funcLuaCommand, EVT_ICL.LOG, "picker hover", tostring(item))
  end
end

if not EVT_ICL.wrapped then
  EVT_ICL.wrapped = true
  if type(SetupEquipInfoWindow) == "function" then
    local EVT_ICL_Setup = SetupEquipInfoWindow
    function SetupEquipInfoWindow(item, ...)
      local r = table.pack(EVT_ICL_Setup(item, ...))
      EVT_ICL.Tell(type(item) == "number" and item or 0)
      return table.unpack(r, 1, r.n)
    end
  end
  if type(SetVisibleEquipInfoWindow) == "function" then
    local EVT_ICL_Visible = SetVisibleEquipInfoWindow
    function SetVisibleEquipInfoWindow(on, ...)
      local r = table.pack(EVT_ICL_Visible(on, ...))
      if on ~= true then
        EVT_ICL.Tell(0)
      end
      return table.unpack(r, 1, r.n)
    end
  end
  if type(OnBack) == "function" then
    local EVT_ICL_Back = OnBack
    function OnBack(...)
      local r = table.pack(EVT_ICL_Back(...))
      EVT_ICL.Tell(-1)
      EVT_ICL.last = nil
      return table.unpack(r, 1, r.n)
    end
  end
end
-- ===== EVT plate_pages item card list END =====
