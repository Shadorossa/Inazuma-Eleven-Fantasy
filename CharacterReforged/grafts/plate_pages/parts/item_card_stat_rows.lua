-- Player page block (plate_pages.lua): the stats panel's rows the focused item raises / lowers
    -- ---- the stats panel's rows the focused item raises / lowers: outline + number colour (CMND_GET_EQUIP_PARAM) ----
    -- an item's stat si for the shown player: its change and its affinity bonus (Better Equipment's page answer)
    G.icAffinityOf = {}
    local function ItemStat(it, si, effect)
      if it == nil or it == 0 then
        return 0
      end
      local ok, has, v = pcall(funcLuaCommand, @crc:CMND_GET_EQUIP_PARAM@, it, si)
      v = ok and has ~= false and tonumber(v) or 0
      local eff = effect
      if eff == nil then
        local key = tostring(it) .. "/" .. tostring(G.hdl)
        eff = G.icAffinityOf[key]
        if eff == nil then
          eff = Command(IC.page_command, it, type(G.hdl) == "number" and G.hdl or 0) or false
          G.icAffinityOf[key] = eff
        end
      end
      local A = type(eff) == "table" and eff.affinity or nil
      local extra = (type(A) == "table" and type(A.bonus) == "table") and tonumber(A.bonus[si + 1]) or 0
      return v + extra
    end

    -- the stats panel's rows: the change of wearing `item` instead of `base` (nil = the item's own change; the
    -- equipment screen), affinity included; the bar's segment, the label and the outline show the same value
    function G.ItemCardRows(item, base)
      local frame, delta, label = nil, nil, nil
      if item ~= nil and item ~= 0 and G.ItemCardOn() and IC.rows ~= false then
        for si = 0, 7 do
          local d = ItemStat(item, si, G.icEffect) - ItemStat(base, si)
          if d ~= 0 then
            for g = 1, 8 do
              if G.STAT[g] == si then
                frame = frame or {}
                frame[g] = d > 0 and "raise" or "lower"
                label = label or {}
                label[g] = d
                delta = delta or {}
                delta[g] = d
              end
            end
          end
        end
      end
      G.rowFrame, G.rowDelta = frame, delta
      G.Try("ItemCardDeltaLabels", label)
      local R = IC.row_mark
      G.numBase = G.numBase or {}
      for g = 1, 8 do
        local now = frame ~= nil and frame[g] or nil
        local k = G.GROUP_ROW[g]
        if Exists(G.BAR) and Cmd(C.IS_OPEN, G.BAR, k) == true and G.ready[G.BAR * 16 + k] then
          local gs, ga = G.GainSprite(k)
          Cmd(C.SPRITE, G.BAR, ga, gs, G.GG.SLOT_GAIN_QUAD, 0, k)
        end
        if Exists(G.NUM) and Cmd(C.IS_OPEN, G.NUM, g - 1) == true then
          -- the number's own colour (CMND get prim colour, as the retail SetPrimitiveGrayout reads it), read once
          -- while it is untinted; every row without a change gets it back on each focus
          if G.numBase[g] == nil then
            local ok, r, gg, b = pcall(funcLuaMenuCommand, 3648327470 --[[get prim colour]], G.NUM, g - 1, R.number_style)
            if ok and type(r) == "number" and type(gg) == "number" and type(b) == "number" then
              G.numBase[g] = {r, gg, b}
            end
          end
          local c = now ~= nil and R.colour[now] or G.numBase[g]
          if c ~= nil then
            pcall(funcLuaMenuCommand, @crc:CMND_SET_PRIM_COLOR@, G.NUM, g - 1, R.number_style, c[1], c[2], c[3])
          end
        end
      end
      G.Try("ItemCardLuckRow")
    end

    -- the delta segments (G.Bars hands their screen rects {x, y, w, h, raise} every frame): drawn on the icon layer's
    -- instances after the labels only when they change; the fill's visible band of the bar (IC.row_mark.delta.band)
    function G.DeltaSegment(segs)
      local R, S = IC.row_mark, IC.set_icons
      local parts = {}
      for _, sg in ipairs(segs or {}) do
        parts[#parts + 1] = string.format("%.0f %.0f %.0f %s", sg[1], sg[2], sg[3], tostring(sg[5]))
      end
      local key = table.concat(parts, "|")
      if key == G.segKey then
        return
      end
      local L = G.EQ_ICON
      if not Exists(L) then
        return
      end
      local B = R.delta.band
      local k, done = R.delta.first, true
      for _, sg in ipairs(segs or {}) do
        if sg[3] >= 1 and k < S.instances then
          local sp = {IC.effect.atlas, CALC_CRC(sg[5] and R.delta.raise or R.delta.lower), sg[3], sg[4] * B[2]}
          done = IconSlot(k, sg[1], sg[2] + sg[4] * B[1], "sprite", sp) and done
          k = k + 1
        end
      end
      for i = k, R.delta.first + R.delta.count - 1 do
        if Cmd(C.IS_OPEN, L, i) == true then
          Cmd(C.VIS, L, i, false)
        end
      end
      G.segKey = done and key or nil
    end

    -- the delta labels over the changed numbers («+41» green, «-10» red; the item's change and, on a raise, its affinity
    -- bonus for the shown player): the icon layer's last instances, as small texts
    function G.ItemCardDeltaLabels(label)
      local L, S, R = G.EQ_ICON, IC.set_icons, IC.row_mark
      if not Exists(L) then
        return
      end
      local k = S.page_instances or S.instances
      local last = (IC.row_mark.delta.first or S.instances) - 1
      for g = 1, 8 do
        local v = label ~= nil and label[g] or nil
        if v ~= nil and k <= last then
          local row = G.GROUP_ROW[g]
          local col, r = math.floor(row / 4), row % 4
          -- the bars' origin (the chart base at G.CHART_AT), as the delta segments
          local x = G.CHART_AT[1] + G.ROW_X0[col] + R.label.dx
          local y = G.CHART_AT[2] - G.ROW_Y[r] + R.label.dy
          local text = (v > 0 and (R.label.plus .. "+") or (R.label.minus .. "-")) .. tostring(math.abs(v)) .. "[C]"
          IconSlot(k, x, y, "text", {text = text, style = "white", scale = R.label.scale})
          k = k + 1
        end
      end
      for i = k, last do
        if Cmd(C.IS_OPEN, L, i) == true then
          Cmd(C.VIS, L, i, false)
        end
      end
    end

    -- Suerte (no equipment changes it): its number copy's comparison arrows off (the retail graph only sets them for
    -- the 7 stats, so they showed as crossed arrows) and its label given the labels' colour the way the retail graph
    -- does (its layer's label colour group; nothing set it on this screen, so it kept the white of its sprite)
    function G.ItemCardLuckRow()
      local R = IC.row_mark
      if Exists(G.NUM) and Cmd(C.IS_OPEN, G.NUM, R.luck_number) == true then
        for _, m in ipairs(R.luck_arrows) do
          Cmd(C.MESH, G.NUM, m, false, R.luck_number)
        end
      end
      if Exists(G.EXTRA) and Cmd(C.IS_OPEN, G.EXTRA, 0) == true then
        local c = R.label_colour
        pcall(funcLuaMenuCommand, 801406373 --[[material colour of a group]], G.EXTRA, 0, R.label_group, c[1], c[2], c[3])
      end
    end
