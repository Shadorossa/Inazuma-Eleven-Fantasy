  -- shared part of the INAROGUE formation lock (docs/game/modes/inarogue.md §18). In the INAROGUE save (slot 4) the
  -- 54 loot formations not won yet are greyed in the formation picker (retail disabled row: _list_base01_gray + grey
  -- texts, the look of sub_window_group UpdateBtnGray), their panel says how to get them and Aceptar refuses them.
  -- Ownership is the loader's (CMND_EVT_RL_FORM_OWNED, rogue_formations_slot4.json). The list is soccer_formation_menu_inc's
  -- local t6 (not reachable from here): the formId of each row is read while the retail code draws it (its call
  -- 2649030357(7, formId) for the name). Normal slots, no loader, or [rogue.formations] enabled = false: retail.
  local RF = {
    SLOT = @crc:CMND_EVT_SLOT_ROGUE@,         -- () -> rogueSlot, active, returnSlot, rogueHasGame
    OWNED = @crc:CMND_EVT_RL_FORM_OWNED@,     -- (formId) -> locked, owned, rarity, ownedCount, total
    LOG = 3661580131,                   -- CMND_EVT_LOG
    FORM_INFO = 2649030357,             -- (7, formId) -> ok, nounId (the row's name); (8, formId) -> ok, descId
    LIST = 3873858080,                  -- win05_01_general_sub_list_formation (focus layer of the list)
    ITEM = 1027507646,                  -- win05_02_general_sub_list_item (one instance per visible row)
    LIST_IDX = 1335605971,              -- () -> focused data index
    T_ON = 808187266, T_OFF = 3180095505, -- _text_list_base01_on / _off
    GRAY_BASE = 1409068817,             -- _list_base01_gray (retail grey row base)
    TEXT_GRAY = 2484004035,             -- (layer, inst, textNode, amount 0 normal .. 0.5 grey)
    MESH = 3405944500,                  -- CMND_SET_MESH_VISIBLE (layer, mesh, visible, inst)
    TEXT = 1083631230,                  -- CMND_SET_MENU_TEXT_STRING (layer, node, text, inst)
    INFO = 2021684813, INFO_DESC = 3237700098, -- the formation panel and its description text
    SE = 1917805374, SE_NG = 2086672038,
    GET_VS = 3713813716,                -- CMND_GET_VS_USE_TEAM_SET
    GET_SET = 1033065575,               -- CMND_GET_TEAM_SET_INFO (set, team, 4) -> ok, formId
    SET_SET = 1506470613,               -- CMND_SET_TEAM_SET_INFO (set, team, 3, formId)
    DEFAULT = 2484170522,               -- 4-4-2 Diamante (retail, always owned)
    LOCKED_DESC = "Formación bloqueada (rareza %d de 4).\nSe gana en INAROGUE: partidos, Élite y jefes (las mejores).\nTienes %d de %d formaciones.",
    on = nil, idx = {}, tint = {}, focus = nil, logs = 0,
  }

  function RF.log(...)
    if RF.logs < 40 then
      RF.logs = RF.logs + 1
      pcall(funcLuaCommand, RF.LOG, "rogue formations", ...)
    end
  end

  -- INAROGUE mode = slot 4 is the loaded game (checked once per menu VM)
  function RF.check()
    if RF.on == nil then
      local ok, rs, act = pcall(funcLuaCommand, RF.SLOT)
      RF.on = ok and type(rs) == "number" and rs == act
      if RF.on then
        RF.log("INAROGUE mode: loot formations lock")
      end
    end
    return RF.on
  end

  -- locked, rarity, ownedCount, total (no loader / old loader: never locked)
  function RF.locked(id)
    if type(id) ~= "number" then
      return false
    end
    local ok, locked, _, rar, n, tot = pcall(funcLuaCommand, RF.OWNED, id)
    if ok and locked == true then
      return true, rar, n, tot
    end
    return false
  end

  function RF.wrap(name, make)
    local cur = _ENV[name]
    if type(cur) ~= "function" then
      return false
    end
    _ENV[name] = make(cur)
    return true
  end

  -- run fn(...) and return the first formId the retail code asked the name of (2649030357 op 7), plus fn's results
  function RF.spy(fn, ...)
    local real = funcLuaCommand
    local seen = nil
    funcLuaCommand = function(cmd, op, id, ...)
      if seen == nil and cmd == RF.FORM_INFO and op == 7 then
        seen = id
      end
      return real(cmd, op, id, ...)
    end
    local r = table.pack(pcall(fn, ...))
    funcLuaCommand = real
    if not r[1] then
      error(r[2], 0)
    end
    return seen, r
  end

  -- grey / normal look of one row instance (instances are recycled while scrolling)
  function RF.paint(inst, id)
    if type(inst) ~= "number" then
      return
    end
    local lk = id ~= nil and RF.locked(id)
    if lk then
      pcall(funcLuaMenuCommand, RF.TEXT_GRAY, RF.ITEM, inst, RF.T_ON, 0.5)
      pcall(funcLuaMenuCommand, RF.TEXT_GRAY, RF.ITEM, inst, RF.T_OFF, 0.5)
      pcall(funcLuaMenuCommand, RF.MESH, RF.ITEM, RF.GRAY_BASE, true, inst)
      RF.tint[inst] = true
    elseif RF.tint[inst] then
      pcall(funcLuaMenuCommand, RF.TEXT_GRAY, RF.ITEM, inst, RF.T_ON, 0)
      pcall(funcLuaMenuCommand, RF.TEXT_GRAY, RF.ITEM, inst, RF.T_OFF, 0)
      pcall(funcLuaMenuCommand, RF.MESH, RF.ITEM, RF.GRAY_BASE, false, inst)
      RF.tint[inst] = nil
    end
  end

  -- the list: every drawn row records its formId and gets the grey look when locked
  RF.wrap("UpdateListItem", function(orig)
    return function(a0, a1, ...)
      if not RF.check() then
        return orig(a0, a1, ...)
      end
      local id, r = RF.spy(orig, a0, a1, ...)
      RF.idx[a0] = id
      RF.paint(a1, id)
      return table.unpack(r, 2, r.n)
    end
  end)

  -- moving the cursor previews the formation (retail); a locked one gets our text in the description box
  RF.wrap("OnMoveListItem", function(orig)
    return function(...)
      if not RF.check() then
        return orig(...)
      end
      local id, r = RF.spy(orig, ...)
      if id ~= nil then
        RF.focus = id
        local lk, rar, n, tot = RF.locked(id)
        if lk then
          local s = string.format(RF.LOCKED_DESC, tonumber(rar) or 0, tonumber(n) or 0, tonumber(tot) or 0)
          pcall(funcLuaMenuCommand, RF.TEXT, RF.INFO, RF.INFO_DESC, s, 0)
        end
      end
      return table.unpack(r, 2, r.n)
    end
  end)

  -- Aceptar on a locked row: NG sound, the list stays open and nothing is applied
  RF.wrap("OnDecideFocusCommon", function(orig)
    return function(a0, a1, ...)
      if a0 == RF.LIST and RF.check() then
        local ok, i = pcall(funcLuaMenuCommand, RF.LIST_IDX)
        local id = ok and RF.idx[i] or nil
        if id == nil then
          id = RF.focus
        end
        if id ~= nil and RF.locked(id) then
          pcall(funcLuaCommand, RF.SE, RF.SE_NG)
          RF.log("refused: formation", id, "is locked")
          return
        end
      end
      return orig(a0, a1, ...)
    end
  end)

  -- the VS team's saved formation is a locked one (older INAROGUE save, unlock_all switched off): back to 4-4-2 Diamante
  function RF.fix()
    local okv, set = pcall(funcLuaCommand, RF.GET_VS)
    if not okv or type(set) ~= "number" then
      return
    end
    local ok, got, fid = pcall(funcLuaCommand, RF.GET_SET, set, 0, 4)
    if ok and got == true and RF.locked(fid) then
      pcall(funcLuaCommand, RF.SET_SET, set, 0, 3, RF.DEFAULT)
      RF.log("team set", set, "used locked formation", fid, "-> 4-4-2 Diamante")
    end
  end
