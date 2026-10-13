-- ===== VRFW outfit_select BEGIN ===== (docs/framework/outfits.md, research/grafts/vrfw_outfit)
-- «Equipamiento» (equip_menu_select) gets the «Atuendo» row: the game's equip slot 4 (costume), which retail shows
-- only in the story field / RPG dock (flag6). Shown in every other context when the active mods declare at least one
-- outfit ([[VRFW.Outfit]], VR-Framework CMND_VRFW_OUTFIT_COUNT); no outfit declared = the retail four rows.
-- * the row is type 4 of the retail type table (CreateEquipTypeTable), after the four retail rows; its look (blue
--   outfit skin, _pos_list03) and its decide are retail: Aceptar opens the item list on the costume tab (the list
--   gets 363718978 = true from OnEnter here), «Quitar» removes the outfit (slot 4);
-- * an empty row reads «Atuendo» (menu_text vrfw_outfit_slot, half alpha), a worn outfit its item name (retail);
-- * the 3D preview wears the outfit's uniform (SetupCharaModel, patched: VRFW_Outfit.PreviewUniform) and is rebuilt
--   when the outfit changes (CheckEquipmentModelUpdateNeeded).
-- Retail behaviour with flag6 (story) is untouched. Nothing runs at load time except these definitions; no new
-- main-chunk locals (everything lives in VRFW_Outfit).
do
  VRFW_Outfit = VRFW_Outfit or {}
  VRFW_Outfit.COUNT = @crc:CMND_VRFW_OUTFIT_COUNT@
  VRFW_Outfit.OF = @crc:CMND_VRFW_OUTFIT_OF@
  VRFW_Outfit.LOG = @crc:CMND_EVT_LOG@
  VRFW_Outfit.TEXT_SLOT = @crc:vrfw_outfit_slot@     -- menu_text «Atuendo»
  VRFW_Outfit.TEXT_GET = 4074371074                  -- (textId) -> text
  VRFW_Outfit.SET_TEXT = 1083631230                  -- (layer, text name, string, instance)
  VRFW_Outfit.TEXT_ALPHA = 1126837159                -- (layer, instance, text name, alpha)
  VRFW_Outfit.L_ROW = 4251697490                     -- soccer11_08_equip_list_item
  VRFW_Outfit.TYPE = 4                               -- equip slot / row type of the costume
  VRFW_Outfit.P_LIST_TABS = 363718978                -- list param: costume tab (retail flag6)
  VRFW_Outfit.P_HAS = 2947612279
  VRFW_Outfit.P_DEL = 3363400568
  VRFW_Outfit.P_SET = 3860611758
  VRFW_Outfit.on = false                             -- this screen shows the «Atuendo» row
  VRFW_Outfit.shown = 0                              -- outfit item the 3D preview was built with

  function VRFW_Outfit.Log(...)
    pcall(funcLuaCommand, VRFW_Outfit.LOG, "outfit", ...)
  end

  -- declared outfits (0 = none, or a framework without outfits)
  function VRFW_Outfit.Count()
    local ok, c = pcall(funcLuaCommand, VRFW_Outfit.COUNT)
    if ok and type(c) == "number" then
      return c
    end
    return 0
  end

  -- the declared outfit a player wears: item id, uniform (0, 0 = none)
  function VRFW_Outfit.Of(h)
    if type(h) ~= "number" or h == 0 then
      return 0, 0
    end
    local ok, item, u = pcall(funcLuaCommand, VRFW_Outfit.OF, h)
    if not ok or type(item) ~= "number" or type(u) ~= "number" then
      return 0, 0
    end
    return item, u
  end

  -- the uniform of the 3D preview (called from the patched SetupCharaModel): the outfit's when one is worn;
  -- coach (16) / manager (32) looks and the story context (retail costume code) unchanged
  function VRFW_Outfit.PreviewUniform(h, uniform, flags, story)
    VRFW_Outfit.shown = 0
    if story or not VRFW_Outfit.on then
      return uniform
    end
    local item, u = VRFW_Outfit.Of(h)
    VRFW_Outfit.shown = item
    if item == 0 or u == 0 or flags == 16 or flags == 32 then
      return uniform
    end
    return u
  end

  if VRFW_Outfit.PrevCreateEquipTypeTable == nil then
    VRFW_Outfit.PrevCreateEquipTypeTable = CreateEquipTypeTable
    VRFW_Outfit.PrevOnEnter = OnEnter
    VRFW_Outfit.PrevUpdateEquipListItem = UpdateEquipListItem
    VRFW_Outfit.PrevCheckModel = CheckEquipmentModelUpdateNeeded
  end

  -- retail: t = {0, 1, 2, 3} (+ 4 with flag6); here + 4 when outfits exist
  function CreateEquipTypeTable()
    VRFW_Outfit.PrevCreateEquipTypeTable()
    VRFW_Outfit.on = false
    if flag6 then
      return
    end
    local cnt = VRFW_Outfit.Count()
    if cnt <= 0 then
      return
    end
    VRFW_Outfit.on = true
    for i = 1, #t do
      if t[i] == VRFW_Outfit.TYPE then
        return
      end
    end
    t[#t + 1] = VRFW_Outfit.TYPE
    VRFW_Outfit.Log("row", cnt)
  end

  -- the item list opens with the costume tab too (retail passes flag6 = false outside the story)
  function OnEnter(a1, a2)
    local r = VRFW_Outfit.PrevOnEnter(a1, a2)
    if a1 == VRFW_Outfit.L_ROW and VRFW_Outfit.on and not flag6 then
      funcLuaCommand(VRFW_Outfit.P_DEL, VRFW_Outfit.P_LIST_TABS)
      funcLuaCommand(VRFW_Outfit.P_SET, VRFW_Outfit.P_LIST_TABS, 0, true)
    end
    return r
  end

  -- an empty «Atuendo» row says what it is (the retail type-4 row has no category label)
  function UpdateEquipListItem(a1)
    local r = VRFW_Outfit.PrevUpdateEquipListItem(a1)
    if not VRFW_Outfit.on or flag6 or GetEquipType(a1) ~= VRFW_Outfit.TYPE then
      return r
    end
    local info = GetEquipListItemInfo(VRFW_Outfit.TYPE)
    local empty = GetEquipItemIdByLayerIdx(a1) == 0
    if empty then
      local ok, s = pcall(funcLuaCommand, VRFW_Outfit.TEXT_GET, VRFW_Outfit.TEXT_SLOT)
      if ok and type(s) == "string" and s ~= "" then
        funcLuaMenuCommand(VRFW_Outfit.SET_TEXT, VRFW_Outfit.L_ROW, info.itemTextName, s, a1)
      end
    end
    pcall(funcLuaMenuCommand, VRFW_Outfit.TEXT_ALPHA, VRFW_Outfit.L_ROW, a1, info.itemTextName, empty and 0.5 or 1)
    return r
  end

  -- back from the item list / quick remove: rebuild the preview when the worn outfit changed (retail checks only the
  -- shoes outside the story)
  function CheckEquipmentModelUpdateNeeded(a1, a2)
    local r = VRFW_Outfit.PrevCheckModel(a1, a2)
    if r or flag6 or not VRFW_Outfit.on then
      return r
    end
    local item = VRFW_Outfit.Of(n)
    return item ~= VRFW_Outfit.shown
  end
end
-- ===== VRFW outfit_select END =====
