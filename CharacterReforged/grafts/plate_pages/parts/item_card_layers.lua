-- Player page block (plate_pages.lua): the item detail card's own layers, page icons and pager
    -- ---- the card's own layers: its body (a copy of the stats panel's body, no drop shadow) and the set icons ------
    G.EQ_BODY, G.EQ_ICON = @crc:evt_eq_card_body@, @crc:evt_eq_set_icon@
    table.insert(G.HOST_LAYERS, G.EQ_BODY)
    table.insert(G.HOST_LAYERS, G.EQ_ICON)
    G.icReady = {}

    -- the body: the band object's page mesh only, given the stats panel's sprite, placed at the card's rect (the band
    -- layout's formula: node (x0 - 1435, 560 - y0)); false = not open yet
    function G.ItemCardBody(rect, show)
      local B = G.EQ_BODY
      if not Exists(B) then
        return true
      end
      if not show then
        if Cmd(C.IS_OPEN, B, 0) == true then
          Cmd(C.VIS, B, 0, false)
        end
        return true
      end
      if not Ready(B, 0) then
        G.icReady[B] = nil
        return false
      end
      if not G.icReady[B] then
        G.icReady[B] = true
        for _, m in ipairs({G.M_PORTRAIT, G.M_BAND, G.M_FLAVOR, G.M_PARAM[1], G.M_PARAM[2]}) do
          Cmd(C.MESH, B, m, false, 0)
        end
        Cmd(C.TEXT_VIS, B, G.N_EXPLAIN, false, 0)
        Cmd(C.SPRITE, B, G.TX_T1101, G.SP_BAND, G.SP_BODY, 0, 0)
      end
      -- the layer where the stats panel's body layer (G.BAND, the same object) is, so the band layout's node formula
      -- places it the same way (CMND layer global position; written once to loader.log)
      if Exists(G.BAND) and Cmd(C.IS_OPEN, G.BAND, 0) == true then
        local ok, x, y, z = pcall(funcLuaMenuCommand, 4002164178 --[[a layer instance's global position]], G.BAND, 0)
        if ok and type(x) == "number" and type(y) == "number" then
          Cmd(C.POS, B, x, y, tonumber(z) or 0, 0)
        end
        if not G.icBodyLogged then
          G.icBodyLogged = true
          pcall(funcLuaCommand, C.LOG, "EVT_PPG item card body at", tostring(ok and x), tostring(ok and y))
        end
      end
      Cmd(C.NODE_POS, B, 0, G.M_PAGE, 0, rect[1] - 1435)
      Cmd(C.NODE_POS, B, 0, G.M_PAGE, 1, 560 - rect[2])
      Cmd(C.NODE_SCALE, B, 0, G.M_PAGE, rect[3] - rect[1], rect[4] - rect[2])
      Cmd(C.MESH, B, G.M_PAGE, true, 0)
      Cmd(C.VIS, B, 0, true)
      return true
    end

    -- the page icons (layer evt_eq_set_icon: copies of the item card object, one icon each, no list cursor locator):
    -- instance k shows a sprite on _win_item_base01 (a slot icon: the list's grey sprite, or its green copy where one
    -- of the set is worn; a position badge) or an item icon on _icon_item_dmy01; placed at screen (x, y) top-left
    G.EQ_ICON_MESHES = {@crc:_win_item01@, @crc:_win_item_base01@, @crc:_icon_item_dmy01@, @crc:_icon_item_dmy02@,
      @crc:_icon_position_dmy01@, @crc:_icon_position_dmy02@, @crc:_base_equip01@, @crc:_gtxt_equip01@,
      @crc:_num_equip_dmy01@, @crc:_base_have01@, @crc:_icon_have01@, @crc:_num_have_dmy01@, @crc:_item_chr_base01@,
      @crc:_item_chr_dmy01@}
    G.EQ_ICON_TEXTS = {@crc:_text_item01@, @crc:_text_parameter01@}
    G.EQ_ICON_PRIMS = {3974820126, 3334923667}           -- the card's E / stock numbers
    local M_SLOT, M_ITEM = @crc:_win_item_base01@, @crc:_icon_item_dmy01@

    local function IconSlot(k, x, y, kind, value, worn, scale)
      scale = scale or 1
      local L, S = G.EQ_ICON, IC.set_icons
      if not Ready(L, k) then
        G.icReady[L * 16 + k] = nil
        return false
      end
      if not G.icReady[L * 16 + k] then
        G.icReady[L * 16 + k] = true
        for _, m in ipairs(G.EQ_ICON_MESHES) do
          Cmd(C.MESH, L, m, false, k)
        end
        for _, t in ipairs(G.EQ_ICON_TEXTS) do
          Cmd(C.TEXT_VIS, L, t, false, k)
        end
        for _, p in ipairs(G.EQ_ICON_PRIMS) do
          Cmd(C.PRIM_VIS, L, k, p, false)
        end
        Cmd(C.NODE_POS, L, k, IC.base, 0, 0)
        Cmd(C.NODE_POS, L, k, IC.base, 1, 0)
      end
      Cmd(C.MESH, L, M_SLOT, false, k)
      Cmd(C.MESH, L, M_ITEM, false, k)
      for _, t in ipairs(G.EQ_ICON_TEXTS) do
        Cmd(C.TEXT_VIS, L, t, false, k)
      end
      local E = IC.effect
      local under, over = E.prio_under, E.prio_over
      if G.icPrioBase ~= nil then
        under, over = G.icPrioBase + 2, G.icPrioBase + 4
      end
      Cmd(@crc:CMND_SET_DRAW_PRIORITY@, L, k, (type(value) == "table" and value.under) and under or over, true)
      if kind == "text" then
        -- value = {text, style ("white" = the name's text node, "ink" = the bonus's), scale}; (x, y) = its left edge and
        -- vertical centre: the texts draw at their layout offsets from the base (top-left: name -221, 15 / bonus
        -- -229, -59, y up; box 50 tall), scaled with the instance
        local st = E.styles[value.style] or E.styles.white
        local sc = value.scale or 1
        Cmd(C.SCALE, L, sc, sc, 1, k)
        local top = y - st.box_h * sc / 2 + (st.dy or 0) * sc
        Cmd(C.POS, L, x - st.at[1] * sc, -top - st.at[2] * sc, 0, k)
        Cmd(C.SET_TEXT, L, st.node, value.text, k)
        Cmd(C.TEXT_VIS, L, st.node, true, k)
        Cmd(C.VIS, L, k, true)
        return true
      end
      Cmd(C.SCALE, L, 1, 1, 1, k)
      Cmd(C.POS, L, x, -y, 0, k)
      if kind == "sprite" then
        -- value = {atlas, sprite, w, h}
        Cmd(C.SPRITE, L, value[1], value[2], S.slot_swap, 0, k)
        Cmd(C.NODE_POS, L, k, M_SLOT, 0, 0)
        Cmd(C.NODE_POS, L, k, M_SLOT, 1, 0)
        Cmd(C.NODE_SCALE, L, k, M_SLOT, value[3], value[4])
        Cmd(C.MESH, L, M_SLOT, true, k)
        Cmd(C.VIS, L, k, true)
        return true
      end
      if kind == "badge" or kind == "slot" then
        local atlas, sprite, w, h
        if kind == "badge" then
          local B = IC.badges
          atlas, sprite, w, h = B.atlas, value, B.size[1], B.size[2]
        elseif worn then
          atlas, sprite, w, h = S.worn_atlas, S.slot_worn_sprites[value], S.slot_size[1] * scale, S.slot_size[2] * scale
        else
          atlas, sprite, w, h = S.slot_atlas, S.slot_sprites[value], S.slot_size[1] * scale, S.slot_size[2] * scale
        end
        Cmd(C.SPRITE, L, atlas, sprite, S.slot_swap, 0, k)
        Cmd(C.NODE_POS, L, k, M_SLOT, 0, 0)
        Cmd(C.NODE_POS, L, k, M_SLOT, 1, 0)
        Cmd(C.NODE_SCALE, L, k, M_SLOT, w, h)
        Cmd(C.MESH, L, M_SLOT, true, k)
      else
        local n = S.size * scale
        funcLuaMenuCommand(3508889864 --[[the item icon]], L, k, M_ITEM, 1875672568 --[[icon_item_dmy01]], value)
        Cmd(C.NODE_POS, L, k, M_ITEM, 0, 0)
        Cmd(C.NODE_POS, L, k, M_ITEM, 1, 0)
        Cmd(C.NODE_SCALE, L, k, M_ITEM, n, n)
        Cmd(C.MESH, L, M_ITEM, true, k)
      end
      Cmd(C.VIS, L, k, true)
      return true
    end

    -- the shown page's icons (the set grid with its slot icons, the affinity badge), else none; false = an instance is still opening (the
    -- frame tries again)
    -- the pager: the framework's page row (VRFW_Pager: L2 / R2 glyphs and the page dots, the technique card's) on the
    -- layer evt_eq_dots, centred at IC.pager.at (screen px); its instances may open again while the host is not closing
    G.EQ_DOTS = @crc:evt_eq_dots@
    table.insert(G.HOST_LAYERS, G.EQ_DOTS)
    G.EQ_YPAGE = @crc:evt_eq_ypage@          -- the «Y <next page>» pill (a pager of style ycycle only)
    if IC.pager ~= nil and IC.pager.style == "ycycle" then
      table.insert(G.HOST_LAYERS, G.EQ_YPAGE)
    end
    -- on a screen without a player the card's added layers open with the screen (their group rows): each instance is
    -- hidden while the screen sets it up, before its first frame, as the game hides its own detail layers; the
    -- pieces show the instances they use
    if G.H.item_only then
      EVT_PPG_Wrap("OnSetupLayer", function(orig)
        return function(a1, a2, ...)
          local r = Pack(orig(a1, a2, ...))
          if a1 == G.EQ_ICON or a1 == G.EQ_DOTS or a1 == G.EQ_YPAGE then
            Cmd(C.VIS, a1, a2 or 0, false)
          end
          return table.unpack(r, 1, r.n)
        end
      end)
    end
    function G.ItemCardPager(n)
      if G.icPager == nil and type(VRFW_Pager) == "table" and type(VRFW_Pager.New) == "function" then
        G.icPager = VRFW_Pager.New({layer = G.EQ_DOTS, name = "item card", style = IC.pager.style, guide = G.EQ_YPAGE,
          prio = G.icPrioBase ~= nil and G.icPrioBase + 6 or nil, reopen = function()
            return not G.hostShut
          end})
      end
      local R = G.icPager
      if R == nil then
        return true
      end
      if n == nil or n < 2 then
        R:Hide()
        return true
      end
      local nextPage = G.icPage % n + 1
      return R:Show(n, G.icPage, IC.pager.at[1], -IC.pager.at[2], G.icPageNames ~= nil and G.icPageNames[nextPage] or nil)
    end

    function G.ItemCardPageIcons()
      local L, S = G.EQ_ICON, IC.set_icons
      if not Exists(L) then
        return true
      end
      local used, done = 0, true
      local shown = G.ItemCardOn() and #G.icPages > 0 and Exists(IC.layer) and Cmd(C.IS_VIS, IC.layer, 0) == true
      local on = shown and G.icSetPage ~= nil and G.icPage == G.icSetPage and type(G.icSet) == "table"
      if shown and IC.text_on_icons then
        local okT, items = pcall(G.ItemCardTextItems, G.ItemCardRect())
        for _, it in ipairs(okT and items or {}) do
          if used < (S.page_instances or S.instances) then
            done = IconSlot(used, it.x, it.y, it.kind, it.value) and done
            used = used + 1
          end
        end
      end
      if shown and G.icEffect ~= nil and G.icEffectPage ~= nil and G.icPage == G.icEffectPage then
        local okI, items = pcall(G.ItemCardEffectItems, G.ItemCardRect())
        for _, it in ipairs(okI and items or {}) do
          if used < (S.page_instances or S.instances) then
            done = IconSlot(used, it.x, it.y, it.kind, it.value) and done
            used = used + 1
          end
        end
      end
      if on then
        -- the groups of the slots the set has, left to right: [slot icon] pieces; `gap` inside a group, `group_gap`
        -- between groups; the whole row scaled down (never up) to the card's width less `margin` on each side and
        -- centred in the card's width and in the body between the title row and the pager row
        local rect = G.ItemCardRect()
        local groups, width = {}, 0
        for slot = 1, #S.slot_sprites do
          local pieces = G.icSet.rows[slot]
          if pieces ~= nil and #pieces > 0 then
            groups[#groups + 1] = {slot = slot, pieces = pieces}
            width = width + S.slot_size[1] + #pieces * (S.gap + S.size)
          end
        end
        width = width + math.max(0, #groups - 1) * S.group_gap
        local room = (rect[3] - rect[1]) - 2 * S.margin
        local f = width > 0 and math.min(1, room / width) or 1
        local x = rect[1] + ((rect[3] - rect[1]) - width * f) / 2
        local P = IC.paged
        local cy = rect[2] + (S.row_cy or ((P.first_row + (P.first_row + (P.max_rows - 1) * P.row_pitch)) / 2))
        local top = cy - S.size * f / 2
        for _, grp in ipairs(groups) do
          if used < (S.page_instances or S.instances) then
            done = IconSlot(used, x, top, "slot", grp.slot, G.icSet.worn[grp.slot] == true, f) and done
            used = used + 1
          end
          x = x + S.slot_size[1] * f
          for _, it in ipairs(grp.pieces) do
            x = x + S.gap * f
            if used < (S.page_instances or S.instances) then
              done = IconSlot(used, x, top, "item", it[1], it[2], f) and done
              used = used + 1
            end
            x = x + S.size * f
          end
          x = x + S.group_gap * f
        end
      end
      for k = used, (S.page_instances or S.instances) - 1 do
        if Cmd(C.IS_OPEN, L, k) == true then
          Cmd(C.VIS, L, k, false)
        end
      end
      if not G.ItemCardPager(shown and #G.icPages or nil) then
        done = false
      end
      if not done then
        G.itemCardPending = true
      end
      return done
    end

    -- the width in px of `text` in the card's bonus box (CMND_GET_MENU_TEXT_RECT_SIZE), nil = no answer
    local function TextWidth(text)
      local ok, w = pcall(funcLuaMenuCommand, @crc:CMND_GET_MENU_TEXT_RECT_SIZE@, IC.layer, 0,
        3138144965 --[[_text_parameter01]], text)
      w = ok and tonumber(w) or nil
      return (w ~= nil and w > 0) and w or nil
    end
