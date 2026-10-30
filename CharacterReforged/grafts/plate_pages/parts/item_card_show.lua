-- Player page block (plate_pages.lua): the item detail card's text box, page input, show / hide and host wrappers
    -- the text box of a paged card: the shown page's rows
    function G.ItemCardText()
      if #G.icPages == 0 or not Exists(IC.layer) or Cmd(C.IS_OPEN, IC.layer, 0) ~= true then
        return
      end
      if IC.text_on_icons then
        Cmd(C.TEXT_VIS, IC.layer, 3138144965 --[[_text_parameter01]], false, 0)
        G.Try("ItemCardPageIcons")
        return
      end
      local body = G.icPages[G.icPage] or G.icBonus
      Cmd(C.SET_TEXT, IC.layer, 3138144965 --[[_text_parameter01]], body, 0)
      -- the text node only on a page that writes in it (the game's bonus lines never show under the Efecto page)
      Cmd(C.TEXT_VIS, IC.layer, 3138144965 --[[_text_parameter01]], body ~= "", 0)
      G.Try("ItemCardPageIcons")
    end

    G.IC_CTRLS = {1332654303 --[[MENU_CTRL]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]]}
    local function Pressed(k)
      for _, ctrl in ipairs(G.IC_CTRLS) do
        local ok, hit = pcall(funcLuaCommand, @crc:CMND_CHECK_INPUT_CMD@, ctrl, k)
        if ok and hit == true then
          return true
        end
      end
      return false
    end

    -- the frame's input read while a paged card shows: CMD_FUNCL2 back, CMD_FUNCR2 forward (both wrap)
    function G.ItemCardInput()
      if not G.ItemCardPaged() or not G.ItemCardOn() or not Exists(IC.layer)
          or Cmd(C.IS_OPEN, IC.layer, 0) ~= true or Cmd(C.IS_VIS, IC.layer, 0) ~= true then
        return
      end
      local dir
      if IC.pager ~= nil and IC.pager.style == "ycycle" then
        dir = Pressed(3421673595 --[[CMD_FUNC3]]) and 1 or 0
      else
        dir = (Pressed(1970176280 --[[CMD_FUNCL2]]) and -1) or (Pressed(2704260807 --[[CMD_FUNCR2]]) and 1) or 0
      end
      if dir == 0 then
        return
      end
      G.icPage = (G.icPage - 1 + dir) % #G.icPages + 1
      pcall(funcLuaCommand, @crc:CMND_SND_PLAY_SE@, 1228648509)      -- the retail page switch sound (sy0027)
      G.ItemCard()
      G.ItemCardText()
    end

    -- the layer's texts and item icons are drawn where their nodes are when the retail fill sets them, so a layout
    -- found pending (layer opened after the fill) fills the card again over the moved nodes
    function G.ItemCardPending()
      if G.itemCardPending and G.ItemCardOn() then
        G.ItemCard()
        G.ItemCardPageIcons()
        if not G.itemCardPending and not IC.no_player and G.itemCardLast ~= nil
            and type(SetupEquipInfoWindow) == "function" then
          pcall(SetupEquipInfoWindow, G.itemCardLast)
        end
      end
    end

    if not IC.no_player then
      EVT_PPG_Wrap("GetEquipParamTextOneLine", function(orig)
        return function(item, idx, ...)
          local ok, s = orig(item, idx, ...)
          if ok == true and type(s) == "string" then
            local okS, signed = pcall(G.SignedBonus, s)
            if okS and type(signed) == "string" then
              s = signed
            end
          end
          return ok, s
        end
      end)
      EVT_PPG_Wrap("GetEquipParamText", function(orig)
        return function(item, ...)
          if not G.ItemCardOn() or type(GetEquipParamTextOneLine) ~= "function" then
            return orig(item, ...)
          end
          local parts = {}
          for k = 0, 7 do
            local ok, s = GetEquipParamTextOneLine(item, k)
            if ok == true and type(s) == "string" and s ~= "" then
              parts[#parts + 1] = s
            end
          end
          G.icBonus = table.concat(parts, IC.bonus_gap)
          return G.icBonus
        end
      end)
      EVT_PPG_Wrap("SetVisibleEquipInfoWindow", function(orig)
        return function(on, ...)
          G.Try("ItemCardSubscribe")
          local r = Pack(orig(on, ...))
          if on ~= true then
            G.ItemCardHide()                    -- nothing focused: the rows' own look, no card
          end
          return table.unpack(r, 1, r.n)
        end
      end)
    end

    -- the card of `item` after the game filled the card layer (name, icon, chips): its pages, layout, texts and the
    -- stats panel's rows, compared with `base` (nil = the equipment screen: the item's own change; the picker: the
    -- slot's item, the set worn as if `item` replaced it). Every screen's card goes through here.
    function G.ItemCardShow(item, base)
      if item ~= G.icShown then
        G.icPage = 1                          -- another item: its first page
      end
      G.icShown = item
      G.icWornSwap = base ~= nil and {from = base ~= 0 and base or nil, to = item} or nil
      if IC.prio_above_card and Exists(IC.layer) then
        local okP, p = pcall(funcLuaMenuCommand, @crc:CMND_GET_DRAW_PRIORITY@, IC.layer, 0)
        G.icPrioBase = okP and tonumber(p) or G.icPrioBase
      end
      if G.ItemCardOn() then
        G.Try("ItemCardPages", item)          -- after the fill: G.icBonus is the item's bonus row
        G.Try("ItemCard")
        G.Try("ItemCardText")
      end
      if IC.rows ~= false then
        G.Try("ItemCardRows", item, base)
      end
    end

    -- the card hidden (nothing focused / hovered): rows, body, page icons and pager
    function G.ItemCardHide()
      G.icPages, G.icShown, G.icWornSwap = {}, nil, nil
      if IC.text_on_icons and Exists(IC.layer) and Cmd(C.IS_OPEN, IC.layer, 0) == true then
        Cmd(C.TEXT_VIS, IC.layer, 3138144965 --[[_text_parameter01]], true, 0)   -- another item: the game's own line
      end
      if IC.rows ~= false then
        G.Try("ItemCardRows", nil)
      end
      G.Try("ItemCardBody", nil, false)
      G.Try("ItemCardPageIcons")
    end

    if not IC.no_player then
      -- the item picker (equip_menu_list, its own script: graft plate_pages item_card_list.lua) sends the hovered item
      -- as the menu event IC.picker_event (VRFW_MenuEvent): the hovered item's card compared with the slot's item (the one
      -- this screen shows), 0 = nothing hovered, -1 = the picker gone (the slot's own item again). Subscribed once this
      -- script runs (its first card call or OnInit); the subscription ends with this menu.
      function G.ItemCardSubscribe()
        if G.icSubscribed or type(VRFW_MenuEvent) ~= "table" then
          return
        end
        G.icSubscribed = VRFW_MenuEvent.On(IC.picker_event, IC.menu, IC.picker_owner, function(item)
          item = tonumber(item)
          if item == nil then
            return
          end
          if item < 0 then
            EVT_PPG_ItemCardPreviewEnd()
          else
            EVT_PPG_ItemCardPreview(item)
          end
        end)
      end
      EVT_PPG_Wrap("OnInit", function(orig)
        return function(...)
          local r = Pack(orig(...))
          G.Try("ItemCardSubscribe")
          return table.unpack(r, 1, r.n)
        end
      end)

      function EVT_PPG_ItemCardPreview(item)
        if item == nil or item == 0 then
          G.ItemCardHide()
          return true
        end
        G.Try("ItemCard")
        G.ItemCardShow(item, G.itemCardLast or 0)
        local parts = {}
        for g = 1, 8 do
          local d = G.rowDelta ~= nil and G.rowDelta[g] or nil
          if d ~= nil then
            parts[#parts + 1] = string.format("%s%+d", tostring(G.STAT[g]), d)
          end
        end
        pcall(funcLuaCommand, C.LOG, "picker hover", tostring(item), "vs", tostring(G.itemCardLast), "delta",
          table.concat(parts, " "))
        return true
      end
      function EVT_PPG_ItemCardPreviewEnd()
        if G.itemCardLast ~= nil and G.itemCardLast ~= 0 then
          G.Try("ItemCard")
          G.ItemCardShow(G.itemCardLast, nil)
        else
          G.ItemCardHide()
        end
        return true
      end

      EVT_PPG_Wrap("SetupEquipInfoWindow", function(orig)
        return function(item, ...)
          G.Try("ItemCardSubscribe")
          G.itemCardLast = item
          if G.ItemCardOn() then
            G.Try("ItemCard")                   -- nodes first: the fill draws the texts / icons where the nodes are
          end
          local r = Pack(orig(item, ...))
          G.ItemCardShow(item, nil)
          return table.unpack(r, 1, r.n)
        end
      end)
    else
      -- a screen without a player (inventory, shop): the game marks an equipment item's card with its position icons
      -- (SetupItemPositionIcon, include/menu/equip_menu_inc) right after filling it, and clears them for any other
      -- item: the card's pages follow those two calls; the card layer's visibility (CMND_SET_LAYER_VISIBLE on it)
      -- takes ours along
      function G.ItemCardWatch()
        if G.icWatched or type(funcLuaMenuCommand) ~= "function" then
          return
        end
        G.icWatched = true
        local raw = funcLuaMenuCommand
        -- every call goes on with exactly the arguments it got (raw(...)): a call padded with nils reaches the engine
        -- with more arguments and multi-arity commands read the padding as a real one (a one-argument call such as
        -- the shop's FinalizeMenu command arrived with two)
        funcLuaMenuCommand = function(...)
          local cmd, layer = ...
          if cmd == C.VIS and IC.layers_set[layer] then
            local r = Pack(raw(...))
            if layer == IC.layer and G.icShown ~= nil then
              G.Try("ItemCardPageIcons")
            end
            return table.unpack(r, 1, r.n)
          end
          return raw(...)
        end
      end
      EVT_PPG_Wrap("SetupItemPositionIcon", function(orig)
        return function(layer, k, item, ...)
          local r = Pack(orig(layer, k, item, ...))
          if IC.layers_set[layer] and type(item) == "number" and item ~= 0 then
            G.Try("ItemCardWatch")
            IC.layer = layer
            G.ItemCardLayer = layer
            G.ItemCardShow(item, nil)
          end
          return table.unpack(r, 1, r.n)
        end
      end)
      EVT_PPG_Wrap("ClearItemPositionIcon", function(orig)
        return function(layer, ...)
          local r = Pack(orig(layer, ...))
          if IC.layers_set[layer] and layer == IC.layer and G.icShown ~= nil then
            G.ItemCardHide()
          end
          return table.unpack(r, 1, r.n)
        end
      end)
    end
