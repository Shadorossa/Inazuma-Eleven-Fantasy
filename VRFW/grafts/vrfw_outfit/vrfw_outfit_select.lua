-- ===== VRFW outfit_select BEGIN ===== (research/grafts/vrfw_outfit)
-- "Equipamiento" (equip_menu_select) gets the "Atuendo" row: the game's equip slot 4 (costume), which retail shows
-- only in the story field / RPG dock (flag6). Shown in every other context when the active mods declare at least one
-- outfit ([[VRFW.Outfit]], VR-Framework CMND_VRFW_OUTFIT_COUNT); no outfit declared = the retail four rows.
-- * the row is type 4 of the retail type table (CreateEquipTypeTable), after the four retail rows; its look (blue
--   outfit skin, _pos_list03) and its decide are retail: Accept opens the item list on the costume tab (the list
--   gets 363718978 = true from OnEnter here), "Quitar" removes the outfit (slot 4);
-- * an empty row reads "Atuendo" (menu_text vrfw_outfit_slot, half alpha), a worn outfit its item name (retail);
-- * the 3D preview wears the outfit's uniform (SetupCharaModel, patched: VRFW_Outfit.PreviewUniform) and is rebuilt
--   when the outfit changes (CheckEquipmentModelUpdateNeeded).
-- * a card with a switchable card look ([[VRFW.CardLook]] with switch_bit, CMND_VRFW_CARD_LOOK state 0 / 1): with no
--   outfit declared, row type 4 shows that look's switch ("<label>: Activada / Desactivada", menu_text
--   vrfw_card_look_on / _off); Accept or the eye key (CMD_FUNC4) on the row switches it in place (the record
--   attribute bit the rule names, the retail "hide equipment" command). With outfits declared the row stays "Atuendo"
--   and the eye key on it switches the look. The row appears / disappears with the player on L / R;
-- * Accept on a row never opens the list by itself (VRFW content\menus\equip_rows.toml): OnDecideFocus opens the list
--   group for the item rows and "Atuendo" with the list parameters (OnEnter of the row layer sets them too).
-- Retail behaviour with flag6 (story) is untouched. Nothing runs at load time except these definitions; no new
-- main-chunk locals (everything lives in VRFW_Outfit).
do
  VRFW_Outfit = VRFW_Outfit or {}
  VRFW_Outfit.COUNT = @crc:CMND_VRFW_OUTFIT_COUNT@
  VRFW_Outfit.OF = @crc:CMND_VRFW_OUTFIT_OF@
  VRFW_Outfit.LOG = @crc:CMND_EVT_LOG@
  VRFW_Outfit.TEXT_SLOT = @crc:vrfw_outfit_slot@     -- menu_text "Atuendo"
  VRFW_Outfit.TEXT_GET = @crc:CMND_TEXT_GET@                  -- (textId) -> text
  VRFW_Outfit.SET_TEXT = @crc:CMND_SET_MENU_TEXT_STRING@                  -- (layer, text name, string, instance)
  VRFW_Outfit.TEXT_ALPHA = @crc:CMND_SET_MENU_TEXT_ALPHA@                -- (layer, instance, text name, alpha)
  VRFW_Outfit.L_ROW = 4251697490                     -- soccer11_08_equip_list_item
  VRFW_Outfit.TYPE = 4                               -- equip slot / row type of the costume
  VRFW_Outfit.P_LIST_TABS = 363718978                -- list param: costume tab (retail flag6)
  VRFW_Outfit.CARD_LOOK = @crc:CMND_VRFW_CARD_LOOK@   -- (hdl) -> uniform, state, switch bit, label text id
  VRFW_Outfit.TEXT_LOOK_ON = @crc:vrfw_card_look_on@   -- menu_text "{label}: Activada"
  VRFW_Outfit.TEXT_LOOK_OFF = @crc:vrfw_card_look_off@ -- menu_text "{label}: Desactivada"
  VRFW_Outfit.TEXT_LOOK_NAME = @crc:vrfw_card_look_name@ -- menu_text: the label of a rule without one
  VRFW_Outfit.ATTR_SET = 1525180681                  -- (hdl, attribute bit, set)
  VRFW_Outfit.SOUND = @crc:CMND_SND_PLAY_SE@                     -- (sound)
  VRFW_Outfit.SOUND_ON = 4235359837                  -- sy0010
  VRFW_Outfit.SOUND_OFF = 2339718859                 -- sy0011
  VRFW_Outfit.SOUND_REFUSED = 2086672038             -- sy0003
  VRFW_Outfit.FN_EYE = 1141890006                    -- the eye-toggle key (CMD_FUNC4)
  VRFW_Outfit.FOCUSED = 2603265800                   -- (layer) -> focused instance
  VRFW_Outfit.CHANGE_GROUP = @crc:CMND_ON_CHANGE_LAYER_GROUP@              -- (group)
  VRFW_Outfit.G_LIST = 530161788                     -- layer group equip_menu_list
  VRFW_Outfit.L_STATUS = 2917320188                  -- soccer11_05_equip_status_base (the 3D preview)
  VRFW_Outfit.SET_COUNT = 3252599449                 -- (layer, instance count)
  VRFW_Outfit.SET_VISIBLE = @crc:CMND_SET_LAYER_VISIBLE@                -- (layer, instance, visible)
  VRFW_Outfit.SET_BONE = 2158717427                  -- (layer, bone, visible, instance)
  VRFW_Outfit.SET_FONT = 2333948100                  -- (layer, instance, text name, font style)
  VRFW_Outfit.SET_SKIN = 558735651                   -- (layer, texture file, sprite, slot, 0, instance)
  VRFW_Outfit.SET_MESH = @crc:CMND_SET_MESH_VISIBLE@                  -- (layer, mesh, visible, instance)
  VRFW_Outfit.P_FLAG5 = 2029825652                   -- list param: flag5
  VRFW_Outfit.P_CHARA = 1038144478                   -- the player the opener passes (read by the chara card)
  VRFW_Outfit.ROW_INSTANCES = 5                      -- instances of the row layer
  VRFW_Outfit.on = false                             -- this screen shows the "Atuendo" row
  VRFW_Outfit.lookRow = false                        -- row type 4 shows the player's card look switch
  VRFW_Outfit.want = nil                             -- the player the next type table is built for
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

  -- the card look of a player: uniform, state (-1 none / not eligible, 0 switched off, 1 on), switch bit, label id
  function VRFW_Outfit.Look(h)
    if type(h) ~= "number" or h == 0 then
      return 0, -1, 0, 0
    end
    local ok, u, st, bit, label = pcall(funcLuaCommand, VRFW_Outfit.CARD_LOOK, h)
    if not ok or type(u) ~= "number" or type(st) ~= "number" then
      return 0, -1, 0, 0
    end
    return u, st, type(bit) == "number" and bit or 0, type(label) == "number" and label or 0
  end

  -- the player has a card look he can switch (outside the story)
  function VRFW_Outfit.Switchable(h)
    if flag6 then
      return false
    end
    local u, st, bit = VRFW_Outfit.Look(h)
    return u ~= 0 and bit ~= 0 and (st == 0 or st == 1)
  end

  -- the player the type table is for: the one ChangeChara moves to, else the opener's (OnInit: read, not consumed),
  -- else the shown one
  function VRFW_Outfit.Player()
    if type(VRFW_Outfit.want) == "number" then
      return VRFW_Outfit.want
    end
    if VRFW_Param.Has(VRFW_Outfit.P_CHARA) then
      return VRFW_Param.Get(VRFW_Outfit.P_CHARA) or 0
    end
    return type(n) == "number" and n or 0
  end

  function VRFW_Outfit.Text(id)
    local ok, s = pcall(funcLuaCommand, VRFW_Outfit.TEXT_GET, id)
    if ok and type(s) == "string" then
      return s
    end
    return ""
  end

  -- "<label>: Activada / Desactivada" for the player's card look
  function VRFW_Outfit.LookText(h)
    local _, st, _, label = VRFW_Outfit.Look(h)
    local name = label ~= 0 and VRFW_Outfit.Text(label) or ""
    if name == "" then
      name = VRFW_Outfit.Text(VRFW_Outfit.TEXT_LOOK_NAME)
    end
    local text = VRFW_Outfit.Text(st == 1 and VRFW_Outfit.TEXT_LOOK_ON or VRFW_Outfit.TEXT_LOOK_OFF)
    local a, b = string.find(text, "{label}", 1, true)
    if a then
      text = string.sub(text, 1, a - 1) .. name .. string.sub(text, b + 1)
    end
    return text
  end

  -- the row instance that shows type 4 (-1 = none)
  function VRFW_Outfit.RowIndex()
    for i = 0, GetEquipTypeNum() - 1 do
      if GetEquipType(i) == VRFW_Outfit.TYPE then
        return i
      end
    end
    return -1
  end

  -- switch the shown player's card look; true when it changed
  function VRFW_Outfit.LookToggle()
    local u, st, bit = VRFW_Outfit.Look(n)
    if u == 0 or bit == 0 or (st ~= 0 and st ~= 1) then
      funcLuaCommand(VRFW_Outfit.SOUND, VRFW_Outfit.SOUND_REFUSED)
      VRFW_Outfit.Log("look refused", n, st)
      return false
    end
    local off = st == 1
    funcLuaCommand(VRFW_Outfit.ATTR_SET, n, bit, off)
    funcLuaCommand(VRFW_Outfit.SOUND, off and VRFW_Outfit.SOUND_OFF or VRFW_Outfit.SOUND_ON)
    local _, now = VRFW_Outfit.Look(n)
    VRFW_Outfit.Log("look", n, u, off and "OFF" or "ON", now)
    local row = VRFW_Outfit.RowIndex()
    if row >= 0 then
      UpdateEquipListItem(row)
    end
    SetupCharaModel(VRFW_Outfit.L_STATUS, 0)
    return true
  end

  -- the uniform of the 3D preview (called from the patched SetupCharaModel): the outfit's when one is worn, else the
  -- card look while it is on; coach (16) / manager (32) looks and the story context (retail costume code) unchanged
  function VRFW_Outfit.PreviewUniform(h, uniform, flags, story)
    VRFW_Outfit.shown = 0
    if story then
      return uniform
    end
    if VRFW_Outfit.on then
      local item, u = VRFW_Outfit.Of(h)
      VRFW_Outfit.shown = item
      if item ~= 0 and u ~= 0 and flags ~= 16 and flags ~= 32 then
        return u
      end
    end
    if flags == 16 or flags == 32 then
      return uniform
    end
    local lu, st = VRFW_Outfit.Look(h)
    if st == 1 and lu ~= 0 then
      return lu
    end
    return uniform
  end

  -- the list group's parameters (delete first: a second call never stacks them)
  function VRFW_Outfit.ListParams()
    VRFW_Param.Clear(VRFW_Outfit.P_FLAG5)
    VRFW_Param.Set(VRFW_Outfit.P_FLAG5, flag5, "plain")
    VRFW_Param.Clear(VRFW_Outfit.P_LIST_TABS)
    VRFW_Param.Set(VRFW_Outfit.P_LIST_TABS, flag6 or VRFW_Outfit.on, "plain")
  end

  -- bones of a row instance for the type it shows now
  function VRFW_Outfit.RowBones(i)
    local info = GetEquipListItemInfo(GetEquipType(i))
    for k = 1, #t2 do
      funcLuaMenuCommand(VRFW_Outfit.SET_BONE, VRFW_Outfit.L_ROW, t2[k], t2[k] == info.enableBoneName, i)
    end
  end

  -- a row instance set up as row type 4 (the retail OnSetupLayer look of type 4: blue outfit skin)
  function VRFW_Outfit.RowLook(i)
    local info = GetEquipListItemInfo(VRFW_Outfit.TYPE)
    VRFW_Outfit.RowBones(i)
    funcLuaMenuCommand(VRFW_Outfit.SET_FONT, VRFW_Outfit.L_ROW, i, info.itemTextName, info.fontStyle)
    funcLuaMenuCommand(VRFW_Outfit.SET_SKIN, VRFW_Outfit.L_ROW, 1676671618, 3264784393, 1536293299, 0, i)
    funcLuaMenuCommand(VRFW_Outfit.SET_SKIN, VRFW_Outfit.L_ROW, 1676671618, 1558763435, 3319891473, 0, i)
  end

  if VRFW_Outfit.PrevCreateEquipTypeTable == nil then
    VRFW_Outfit.PrevCreateEquipTypeTable = CreateEquipTypeTable
    VRFW_Outfit.PrevOnEnter = OnEnter
    VRFW_Outfit.PrevUpdateEquipListItem = UpdateEquipListItem
    VRFW_Outfit.PrevCheckModel = CheckEquipmentModelUpdateNeeded
    VRFW_Outfit.PrevChangeChara = ChangeChara
    VRFW_Outfit.PrevOnDecideFocus = OnDecideFocus
    VRFW_Outfit.PrevOnFunction = OnFunction
  end

  -- retail: t = {0, 1, 2, 3} (+ 4 with flag6); here + 4 when outfits exist, or for a player with a switchable card look
  function CreateEquipTypeTable()
    VRFW_Outfit.PrevCreateEquipTypeTable()
    VRFW_Outfit.on = false
    VRFW_Outfit.lookRow = false
    if flag6 then
      return
    end
    local cnt = VRFW_Outfit.Count()
    if cnt > 0 then
      VRFW_Outfit.on = true
    elseif VRFW_Outfit.Switchable(VRFW_Outfit.Player()) then
      VRFW_Outfit.lookRow = true
    else
      return
    end
    for i = 1, #t do
      if t[i] == VRFW_Outfit.TYPE then
        return
      end
    end
    t[#t + 1] = VRFW_Outfit.TYPE
    VRFW_Outfit.Log("row", cnt)
  end

  -- the row layer's list parameters (retail sets the same two there); the item list opens with the costume tab too
  -- when outfits exist (retail passes flag6 = false outside the story)
  function OnEnter(a1, a2)
    if a1 == VRFW_Outfit.L_ROW then
      VRFW_Outfit.ListParams()
      return
    end
    return VRFW_Outfit.PrevOnEnter(a1, a2)
  end

  -- Accept on a row: the card look row switches in place; every other row opens the list group (the menu data no
  -- longer does, content\menus\equip_rows.toml)
  function OnDecideFocus(a1, a2)
    if a1 ~= VRFW_Outfit.L_ROW then
      return VRFW_Outfit.PrevOnDecideFocus(a1, a2)
    end
    if VRFW_Outfit.lookRow and not flag6 and GetEquipType(a2) == VRFW_Outfit.TYPE then
      VRFW_Outfit.LookToggle()
      return
    end
    local r = VRFW_Outfit.PrevOnDecideFocus(a1, a2)
    VRFW_Outfit.ListParams()
    funcLuaMenuCommand(VRFW_Outfit.CHANGE_GROUP, VRFW_Outfit.G_LIST)
    return r
  end

  -- the eye key on row type 4 switches the card look outside the story (retail uses the key only with flag6)
  function OnFunction(a1, a2)
    if a1 == VRFW_Outfit.FN_EYE and not flag6 then
      local row = funcLuaMenuCommand(VRFW_Outfit.FOCUSED, VRFW_Outfit.L_ROW)
      if type(row) == "number" and GetEquipType(row) == VRFW_Outfit.TYPE and VRFW_Outfit.Switchable(n) then
        VRFW_Outfit.LookToggle()
      end
      return
    end
    return VRFW_Outfit.PrevOnFunction(a1, a2)
  end

  -- L / R to another player: the card look row appears / disappears with him (no outfit declared); the instances are
  -- set up again when it does
  function ChangeChara(a1)
    if not flag6 and not VRFW_Outfit.on then
      local was = VRFW_Outfit.lookRow
      VRFW_Outfit.want = t4[a1 + 1] or 0
      CreateEquipTypeTable()
      VRFW_Outfit.want = nil
      if was ~= VRFW_Outfit.lookRow then
        local num = GetEquipTypeNum()
        funcLuaMenuCommand(VRFW_Outfit.SET_COUNT, VRFW_Outfit.L_ROW, num)
        for i = 0, num - 1 do
          if GetEquipType(i) == VRFW_Outfit.TYPE then
            VRFW_Outfit.RowLook(i)
          else
            VRFW_Outfit.RowBones(i)
          end
          funcLuaMenuCommand(VRFW_Outfit.SET_VISIBLE, VRFW_Outfit.L_ROW, i, true)
        end
        for i = num, VRFW_Outfit.ROW_INSTANCES - 1 do
          funcLuaMenuCommand(VRFW_Outfit.SET_VISIBLE, VRFW_Outfit.L_ROW, i, false)
        end
      end
    end
    return VRFW_Outfit.PrevChangeChara(a1)
  end

  -- an empty "Atuendo" row says what it is (the retail type-4 row has no category label); the card look row its state
  function UpdateEquipListItem(a1)
    local r = VRFW_Outfit.PrevUpdateEquipListItem(a1)
    if flag6 or GetEquipType(a1) ~= VRFW_Outfit.TYPE then
      return r
    end
    local info = GetEquipListItemInfo(VRFW_Outfit.TYPE)
    if VRFW_Outfit.lookRow then
      funcLuaMenuCommand(VRFW_Outfit.SET_TEXT, VRFW_Outfit.L_ROW, info.itemTextName, VRFW_Outfit.LookText(n), a1)
      if info.itemIconMeshName ~= nil then
        funcLuaMenuCommand(VRFW_Outfit.SET_MESH, VRFW_Outfit.L_ROW, info.itemIconMeshName, false, a1)
      end
      pcall(funcLuaMenuCommand, VRFW_Outfit.TEXT_ALPHA, VRFW_Outfit.L_ROW, a1, info.itemTextName, 1)
      return r
    end
    if not VRFW_Outfit.on then
      return r
    end
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
