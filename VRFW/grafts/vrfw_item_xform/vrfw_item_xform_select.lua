-- ===== VRFW item_xform_select BEGIN ===== (docs/framework/types/item.md §13, docs/game/mechanics/item-transformations.md §9.8,
-- research/grafts/vrfw_item_xform)
-- Equipment screen (equip_menu_select): when a transformation item ([[VRFW.ItemTransform]] of a mod) is equipped, removed or swapped for
-- another one, the 3D preview and the chara card miniface are rebuilt AT ONCE with the new look. Retail rebuilds the
-- model on the way back from the item list only when the shoes (or the story costume) changed
-- (CheckEquipmentModelUpdateNeeded), and the card only in the story field (flag6). Here the transformation target of
-- the shown player (VR-Framework CMND_VRFW_ITEM_XFORM_STATE, answered live from the worn item) is remembered at every
-- model build / card setup, and compared after the item list closes (OnChangeLayerGroup), after the quick remove and
-- the optimal-equip (UpdateEquipCondition): a different target = SetupCharaModel + UpdateCharaCard, the same retail
-- functions L/R and the outfit toggle use. The plugin that draws the transformation swaps the model and the face.
-- Without the framework's answer STATE fails (pcall) and nothing changes. Nothing runs at load time; no new chunk locals.
do
  VRFW_ItemXform = VRFW_ItemXform or {}
  VRFW_ItemXform.STATE = @crc:CMND_VRFW_ITEM_XFORM_STATE@
  VRFW_ItemXform.LOG = @crc:CMND_EVT_LOG@
  VRFW_ItemXform.L_MODEL = 2917320188               -- soccer11_05_equip_status_base (3D preview)
  VRFW_ItemXform.G_SELECT = 802408180               -- layer group equip_menu_select (back from the item list)
  VRFW_ItemXform.mdl_h, VRFW_ItemXform.mdl_t = 0, -1        -- player / target of the last model build
  VRFW_ItemXform.card_h, VRFW_ItemXform.card_t = 0, -1      -- player / target of the last card setup

  -- transformation target chara id of a card (0 = none), nil = no answer (no loader / module off)
  function VRFW_ItemXform.Target(h)
    if type(h) ~= "number" or h == 0 then
      return nil
    end
    local ok, item, target = pcall(funcLuaCommand, VRFW_ItemXform.STATE, h)
    if not ok or type(target) ~= "number" then
      return nil
    end
    return target
  end

  function VRFW_ItemXform.SLog(...)
    pcall(funcLuaCommand, VRFW_ItemXform.LOG, "item_xform", ...)
  end

  -- rebuild what shows an old look of the current player (n)
  function VRFW_ItemXform.Refresh(why)
    local h = n
    local tg = VRFW_ItemXform.Target(h)
    if tg == nil then
      return
    end
    local model = VRFW_ItemXform.mdl_h ~= h or VRFW_ItemXform.mdl_t ~= tg
    local card = VRFW_ItemXform.card_h ~= h or VRFW_ItemXform.card_t ~= tg
    if not model and not card then
      return
    end
    VRFW_ItemXform.SLog("refresh", why, string.format("%08X", h), string.format("%08X", tg), model and 1 or 0, card and 1 or 0)
    if model then
      SetupCharaModel(VRFW_ItemXform.L_MODEL, 0)
    end
    if card then
      UpdateCharaCard()
    end
  end

  if VRFW_ItemXform.PrevSetupCharaModel == nil then
    VRFW_ItemXform.PrevSetupCharaModel = SetupCharaModel
    VRFW_ItemXform.PrevUpdateCharaCard = UpdateCharaCard
    VRFW_ItemXform.PrevOnChangeLayerGroup = OnChangeLayerGroup
    VRFW_ItemXform.PrevUpdateEquipCondition = UpdateEquipCondition
  end

  function SetupCharaModel(a1, a2)
    local r = VRFW_ItemXform.PrevSetupCharaModel(a1, a2)
    if a1 == VRFW_ItemXform.L_MODEL then
      VRFW_ItemXform.mdl_h, VRFW_ItemXform.mdl_t = n, VRFW_ItemXform.Target(n) or -1
    end
    return r
  end

  function UpdateCharaCard()
    local r = VRFW_ItemXform.PrevUpdateCharaCard()
    VRFW_ItemXform.card_h, VRFW_ItemXform.card_t = n, VRFW_ItemXform.Target(n) or -1
    return r
  end

  -- back from the item list (equip / remove / swap there)
  function OnChangeLayerGroup(a1)
    local r = VRFW_ItemXform.PrevOnChangeLayerGroup(a1)
    if a1 == VRFW_ItemXform.G_SELECT then
      VRFW_ItemXform.Refresh("list")
    end
    return r
  end

  -- quick remove on a row, optimal equip
  function UpdateEquipCondition(a1, a2)
    local r = VRFW_ItemXform.PrevUpdateEquipCondition(a1, a2)
    VRFW_ItemXform.Refresh("cond")
    return r
  end
end
-- ===== VRFW item_xform_select END =====
