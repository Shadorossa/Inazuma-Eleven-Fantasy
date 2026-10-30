-- ===== VRFW item_xform BEGIN ===== (research/grafts/vrfw_item_xform)
-- Equipment list (equip_menu_list): a transformation item ([[VRFW.ItemTransform]] of a mod) chosen for a player it
-- cannot transform is refused with the error sound and the reason the declaring mod wrote (VR-Framework
-- CMND_VRFW_ITEM_XFORM_CAN -> ok, reason (1 incompatible, 2 locked), textId). Taking the item off is never refused.
-- Items nobody declared, an older framework (pcall fails) or no reason text: the retail decide runs / only the sound.
-- Nothing runs at load time except these definitions; no new main-chunk locals (everything lives in VRFW_ItemXform).
do
  VRFW_ItemXform = VRFW_ItemXform or {}
  VRFW_ItemXform.CAN = @crc:CMND_VRFW_ITEM_XFORM_CAN@
  VRFW_ItemXform.LOG = @crc:CMND_EVT_LOG@
  VRFW_ItemXform.ITEM_OF_INV = 1730783731       -- (invHdl, 0) -> item id (retail CheckEnableEquip)
  VRFW_ItemXform.ITEM_NAME = @crc:CMND_GET_ITEM_PARAM@         -- (itemId, 0) -> item name (retail UpdateItemEquipLine)
  VRFW_ItemXform.TEXT_GET = @crc:CMND_TEXT_GET@          -- (textId) -> text
  VRFW_ItemXform.SE = @crc:CMND_SND_PLAY_SE@
  VRFW_ItemXform.SE_NG = 2086672038             -- sy0003
  VRFW_ItemXform.DECIDE = 4067673008            -- OnFunction "equip"
  VRFW_ItemXform.hdl = 0
  VRFW_ItemXform.inv = 0

  function VRFW_ItemXform.Log(...)
    pcall(funcLuaCommand, VRFW_ItemXform.LOG, "item_xform", ...)
  end

  -- the declaring mod's text for the refusal, {item} = the item's name; nil = no text
  function VRFW_ItemXform.Text(textId, item)
    if type(textId) ~= "number" or textId == 0 then
      return nil
    end
    local ok, s = pcall(funcLuaCommand, VRFW_ItemXform.TEXT_GET, textId)
    if not ok or type(s) ~= "string" or s == "" then
      return nil
    end
    local okn, name = pcall(funcLuaCommand, VRFW_ItemXform.ITEM_NAME, item, 0)
    if not okn or type(name) ~= "string" then
      name = ""
    end
    return (string.gsub(s, "{item}", (string.gsub(name, "%%", "%%%%"))))
  end

  -- true = refused (sound + reason shown); false = let the retail decide run
  function VRFW_ItemXform.Refused()
    local h, inv = VRFW_ItemXform.hdl, VRFW_ItemXform.inv
    if type(h) ~= "number" or h == 0 or type(inv) ~= "number" or inv == 0 then
      return false
    end
    local oki, item = pcall(funcLuaCommand, VRFW_ItemXform.ITEM_OF_INV, inv, 0)
    if not oki or type(item) ~= "number" or item == 0 then
      return false
    end
    local okc, ok, why, textId = pcall(funcLuaCommand, VRFW_ItemXform.CAN, h, item)
    if not okc or ok ~= false or type(why) ~= "number" or why <= 0 then
      return false
    end
    pcall(funcLuaCommand, VRFW_ItemXform.SE, VRFW_ItemXform.SE_NG)
    VRFW_ItemXform.Log("refused", string.format("%08X", h), string.format("%08X", item), why)
    local s = VRFW_ItemXform.Text(textId, item)
    if s ~= nil then
      OpenGeneralWindow(s, true)
    end
    return true
  end

  if VRFW_ItemXform.PrevSetStartMenu == nil then
    VRFW_ItemXform.PrevSetStartMenu = SetStartMenu
    VRFW_ItemXform.PrevUpdateItemEquipMenu = UpdateItemEquipMenu
    VRFW_ItemXform.PrevOnFunction = OnFunction
  end

  -- the player whose equipment is shown (retail n = a1)
  function SetStartMenu(a1, a2)
    VRFW_ItemXform.hdl = a1 or 0
    VRFW_ItemXform.inv = 0
    return VRFW_ItemXform.PrevSetStartMenu(a1, a2)
  end

  -- the focused inventory entry (retail n3 = a1)
  function UpdateItemEquipMenu(a1)
    VRFW_ItemXform.inv = a1 or 0
    return VRFW_ItemXform.PrevUpdateItemEquipMenu(a1)
  end

  function OnFunction(a1, a2)
    if a1 == VRFW_ItemXform.DECIDE and VRFW_ItemXform.Refused() then
      return
    end
    return VRFW_ItemXform.PrevOnFunction(a1, a2)
  end
end
-- ===== VRFW item_xform END =====
