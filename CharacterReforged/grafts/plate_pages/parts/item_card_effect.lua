-- Player page block (plate_pages.lua): the item detail card's «Efecto» page
    -- the «Efecto» page from Better Equipment's answer: its rows, then the affinity row «<label>  [badge]  [element]
    -- <value>» (the badge = the position's sprite, drawn by G.ItemCardPageIcons in the room left by spaces after the
    -- label). A text answer (older Better Equipment) is used as it is.
    -- ---- the «Efecto» page (host table item_card.effect): two rows of icons, chips and short texts ---------------------
    -- Row 1: [bond icon] | chip «Supertécnica [element] +N %» (the item's passive)   [emblem icon] | [position badge]
    -- [✓] + [element] [✓]   chip «[raised stats] x one % / both %» (blue; green when both match the wearer).
    -- Row 2: [boot icon] | the set's slot icons (green where worn) «a/b»   the tier chips to the right edge, each its
    -- reward over N bars (filled by the pieces worn; green when reached). Every value from Better Equipment's answer
    -- (CMND_BETTEREQUIPMENT_ITEM_PAGE with the shown player) and the set page's data; sprites from the card's own atlas
    -- evt_eq_fx (copies of retail icons, loaded by the icon layer's object).
    local function EffWidth(text, style)
      local E = IC.effect
      local st = E.styles[style] or E.styles.white
      local ok, w = pcall(funcLuaMenuCommand, @crc:CMND_GET_MENU_TEXT_RECT_SIZE@, IC.layer, 0, st.node, text)
      w = ok and tonumber(w) or nil
      if w == nil or w <= 0 then
        w = #text * st.char_px
      end
      return w
    end

    local function Spr(name)
      return {IC.effect.atlas, CALC_CRC(name)}
    end

    -- a chip's content: {text = s} or {sprite = name} pieces of one effect (a passive or a tier reward)
    local function EffPieces(part, on)
      local E = IC.effect
      local p = {}
      if part.stat ~= nil then
        local n = E.stat_icons[part.stat]
        if n ~= nil then
          p[#p + 1] = {sprite = string.format(E.sprites.stat, n)}
        end
        local name = G.ItemCardStatName(part.stat_index) or part.stat_name or part.stat
        p[#p + 1] = {text = tostring(name)}
        p[#p + 1] = {text = tostring(part.value)}
        return p
      end
      if part.label ~= nil and (part.element ~= nil or part.family ~= nil) then
        p[#p + 1] = {text = tostring(part.label)}
        local el = part.element ~= nil and E.elements[part.element] or nil
        local ext = type(part.element_icon) == "table" and part.element_icon or nil
        if el ~= nil then
          p[#p + 1] = {sprite = string.format(on and E.sprites.element or E.sprites.element_off, el)}
        elseif ext ~= nil then
          p[#p + 1] = {atlas = ext.atlas, sprite_id = ext.sprite}
        elseif part.family ~= nil then
          p[#p + 1] = {text = tostring(part.family)}
        elseif part.element ~= nil then
          p[#p + 1] = {text = tostring(G.ItemCardElementName(part.element) or part.element_name or part.element)}
        end
        p[#p + 1] = {text = tostring(part.value)}
        return p
      end
      p[#p + 1] = {text = tostring(part.text or "")}
      return p
    end

    -- the game's own name of stat si (0..6): its equipment bonus text «<stat> +<VALUE>» (include/menu/equip_menu_inc,
    -- the texts the stats' bonus lines use) without the value; nil = no answer
    G.statNames = G.statNames or {}
    function G.ItemCardStatName(si)
      si = tonumber(si)
      local id = si ~= nil and IC.effect.stat_texts[si + 1] or nil
      if id == nil then
        return nil
      end
      if G.statNames[si] == nil then
        local ok, t = pcall(funcLuaCommand, @crc:CMND_TEXT_GET@ --[[the text of a text id]], id)
        local name = ok and type(t) == "string" and string.match(t, "^(.-)%s*%+") or nil
        G.statNames[si] = (name ~= nil and name ~= "") and name or false
      end
      return G.statNames[si] or nil
    end

    -- the game's own name of an element (host table effect.element_texts: menu_text ids), nil = none
    G.elementNames = G.elementNames or {}
    function G.ItemCardElementName(element)
      local id = element ~= nil and IC.effect.element_texts[element] or nil
      if id == nil then
        return nil
      end
      if G.elementNames[element] == nil then
        local ok, t = pcall(funcLuaCommand, @crc:CMND_TEXT_GET@ --[[the text of a text id]], id)
        G.elementNames[element] = (ok and type(t) == "string" and t ~= "") and t or false
      end
      return G.elementNames[element] or nil
    end

    local function PiecesWidth(pieces, style, sc)
      local E = IC.effect
      sc = sc or E.text_scale
      local w = 0
      for i, pc in ipairs(pieces) do
        if i > 1 then
          w = w + E.gap
        end
        if pc.sprite ~= nil or pc.sprite_id ~= nil then
          w = w + E.icon
        else
          w = w + EffWidth(pc.text, style) * sc
        end
      end
      return w
    end

    -- the pieces drawn from x at centre y (text colour tag `tag`)
    local function DrawPieces(out, pieces, x, y, tag, style, sc)
      local E = IC.effect
      sc = sc or E.text_scale
      for i, pc in ipairs(pieces) do
        if i > 1 then
          x = x + E.gap
        end
        if pc.sprite ~= nil or pc.sprite_id ~= nil then
          local sp = pc.sprite_id ~= nil and {pc.atlas, pc.sprite_id} or Spr(pc.sprite)
          out[#out + 1] = {kind = "sprite", x = x, y = y - E.icon / 2, value = {sp[1], sp[2], E.icon, E.icon}}
          x = x + E.icon
        else
          local t = pc.tag or tag
          out[#out + 1] = {kind = "text", x = x, y = y, value = {text = t .. pc.text .. (t ~= "" and "[C]" or ""),
            style = style, scale = sc}}
          x = x + EffWidth(pc.text, style) * sc
        end
      end
      return x
    end

    local function Section(out, x, y, sprite)
      local E = IC.effect
      local sp = Spr(sprite)
      out[#out + 1] = {kind = "sprite", x = x, y = y - E.section / 2, value = {sp[1], sp[2], E.section, E.section}}
      x = x + E.section + E.sep_gap
      local sv = Spr(E.sprites.sep)
      out[#out + 1] = {kind = "sprite", x = x, y = y - E.sep[2] / 2, value = {sv[1], sv[2], E.sep[1], E.sep[2]}}
      return x + E.sep[1] + E.sep_gap
    end

    local function Chip(out, x, y, w, sprite, h)
      local E = IC.effect
      local sp = Spr(sprite)
      h = h or E.chip_h
      out[#out + 1] = {kind = "sprite", x = x, y = y - h / 2, value = {sp[1], sp[2], w, h, under = true}}
    end

    function G.ItemCardEffectItems(rect)
      local E, F = IC.effect, G.icEffect
      local out = {}
      local x0, y0 = rect[1], rect[2]
      local r1, r2 = y0 + E.row1, y0 + E.row2
      local check = Spr(E.sprites.check)
      -- row 1, left: the passive
      local x = Section(out, x0 + E.left, r1, E.sprites.bond)
      if type(F.passive) == "table" then
        local pieces = EffPieces(F.passive, true)
        local pw = PiecesWidth(pieces, "white")
        local w = math.max(pw + 2 * E.chip_pad, E.passive_w)
        Chip(out, x, r1, w, E.sprites.chip_on)
        DrawPieces(out, pieces, x + (w - pw) / 2, r1, "", "white")
      end
      -- row 1, right: the affinity
      local A = F.affinity
      if type(A) == "table" then
        x = Section(out, x0 + E.split, r1, E.sprites.emblem)
        local pos = A.position ~= nil and E.positions[A.position] or nil
        if pos ~= nil then
          -- a position whose game badge has no plate of its own (GK: dark letters on white) uses the card's own badge
          local own = type(E.position_own) == "table" and E.position_own[A.position] or nil
          local sp = (A.pos_ok or IC.no_player)
            and (own ~= nil and Spr(own) or {IC.badges.atlas, CALC_CRC(string.format(E.sprites.position, pos))})
            or Spr(string.format(E.sprites.position_off, pos))
          out[#out + 1] = {kind = "sprite", x = x, y = r1 - E.badge[2] / 2, value = {sp[1], sp[2], E.badge[1], E.badge[2]}}
          if A.pos_ok then
            out[#out + 1] = {kind = "sprite", x = x + E.badge[1] - E.check / 2, y = r1 - E.badge[2] / 2 - E.check / 2,
              value = {check[1], check[2], E.check, E.check}}
          end
          x = x + E.badge[1] + E.gap
        end
        local el = A.element ~= nil and E.elements[A.element] or nil
        local ext = type(A.element_icon) == "table" and A.element_icon or nil
        if el == nil and ext == nil and A.element ~= nil then
          if pos ~= nil then
            x = DrawPieces(out, {{text = E.plus}}, x, r1, "", "ink") + E.gap
          end
          x = DrawPieces(out, {{text = G.ItemCardElementName(A.element) or A.element}}, x, r1, "", "ink") + E.gap
        end
        if el ~= nil or ext ~= nil then
          if pos ~= nil then
            x = DrawPieces(out, {{text = E.plus}}, x, r1, "", "ink") + E.gap
          end
          local sp = el ~= nil and Spr(string.format((A.el_ok or IC.no_player) and E.sprites.element or E.sprites.element_off, el))
            or {ext.atlas, ext.sprite}
          out[#out + 1] = {kind = "sprite", x = x, y = r1 - E.icon / 2, value = {sp[1], sp[2], E.icon, E.icon}}
          if A.el_ok then
            out[#out + 1] = {kind = "sprite", x = x + E.icon - E.check / 2, y = r1 - E.icon / 2 - E.check / 2,
              value = {check[1], check[2], E.check, E.check}}
          end
          x = x + E.icon + E.gap
        end
        local pieces = {}
        for _, st in ipairs(type(A.stats) == "table" and A.stats or {}) do
          local n = E.stat_icons[st]
          if n ~= nil then
            pieces[#pieces + 1] = {sprite = string.format(E.sprites.stat, n)}
          end
        end
        pieces[#pieces + 1] = {text = tostring(A.text or "")}
        local rate = A.rate or ((A.pos_ok and A.el_ok) and "both" or (A.pos_ok and "one" or "none"))
        if IC.no_player then
          rate = "one"                         -- the requirement and both rates: the neutral (blue) chip
        end
        local chip = rate == "both" and E.sprites.chip_on or (rate == "one" and E.sprites.chip_blue or E.sprites.chip_off)
        local pw = PiecesWidth(pieces, "white")
        local w = math.max(pw + 2 * E.chip_pad, E.affinity_w)
        local cx = math.max(x + E.gap, x0 + E.right - w)
        Chip(out, cx, r1, w, chip)
        DrawPieces(out, pieces, cx + (w - pw) / 2, r1, rate == "none" and E.off_tag or "", "white")
      end
      -- row 2: the set
      local S = G.icSet
      if type(F.tiers) == "table" and #F.tiers > 0 and type(S) == "table" then
        x = Section(out, x0 + E.left, r2, E.sprites.equip)
        local SI = IC.set_icons
        for slot = 1, #SI.slot_sprites do
          if S.rows[slot] ~= nil then
            local worn = S.worn[slot] == true
            local sp = worn and {SI.worn_atlas, SI.slot_worn_sprites[slot]} or {SI.slot_atlas, SI.slot_sprites[slot]}
            out[#out + 1] = {kind = "sprite", x = x, y = r2 - E.slot[2] / 2, value = {sp[1], sp[2], E.slot[1], E.slot[2]}}
            x = x + E.slot[1] + E.gap
          end
        end
        if not IC.no_player then
          x = DrawPieces(out, {{text = string.format("%d/%d", S.nworn or 0, S.nslots or 0)}}, x, r2, "", "ink")
        end
        x = x + E.tier_gap
        -- the tier chips to the right edge, the room split by their natural widths
        local nat, total = {}, 0
        for i, t in ipairs(F.tiers) do
          local on = not IC.no_player and (S.nworn or 0) >= (tonumber(t.pieces) or 99)
          local pieces = EffPieces(t.reward or {}, on)
          local w = math.max(PiecesWidth(pieces, "white", E.tier_scale), E.tier_min) + 2 * E.chip_pad
          nat[i] = {pieces = pieces, w = w, on = on, need = tonumber(t.pieces) or 2}
          total = total + w
        end
        local room = (x0 + E.right) - x - (#nat - 1) * E.tier_gap
        for _, t in ipairs(nat) do
          local w = total > 0 and math.max(t.w, room * t.w / total) or t.w
          Chip(out, x, r2, w, t.on and E.sprites.chip_on or (IC.no_player and E.sprites.chip_blue or E.sprites.chip_off),
            E.tier_h)
          -- the reward centred, its text shrunk to fit the chip (down to tier_scale_min)
          local sc = E.tier_scale
          local pw = PiecesWidth(t.pieces, "white", sc)
          if pw > w - 2 * E.chip_pad then
            sc = math.max(E.tier_scale_min, sc * (w - 2 * E.chip_pad) / pw)
            pw = PiecesWidth(t.pieces, "white", sc)
          end
          DrawPieces(out, t.pieces, x + (w - pw) / 2, r2 + E.reward_dy, (t.on or IC.no_player) and "" or E.off_tag, "white", sc)
          local bx0, bx1 = x + E.bar_pad, x + w - E.bar_pad
          local bw = (bx1 - bx0 - E.bar_gap * (t.need - 1)) / t.need
          for i = 1, t.need do
            local name = i <= (S.nworn or 0) and (t.on and E.sprites.bar_white or E.sprites.bar_on) or E.sprites.bar_off
            local sp = Spr(name)
            out[#out + 1] = {kind = "sprite", x = bx0 + (i - 1) * (bw + E.bar_gap), y = r2 + E.bar_dy,
              value = {sp[1], sp[2], bw, E.bar_h}}
          end
          x = x + w + E.tier_gap
        end
      end
      return out
    end

    -- a row centred on the card: spaces before it for half of the room it leaves in the text box (its width measured)
    function G.ItemCardCentred(text)
      local B = IC.badges
      local w = TextWidth(text)
      local sw = TextWidth(string.rep(".", 10))
      local dot = TextWidth(string.rep(".", 10) .. string.rep(" ", 10))
      sw = (sw ~= nil and dot ~= nil and dot > sw) and (dot - sw) / 10 or B.space_px
      if w == nil then
        return text
      end
      local pad = ((IC.rect[3] - IC.rect[1]) / 2 - IC.text_x) - w / 2
      return string.rep(" ", math.max(0, math.floor(pad / sw + 0.5))) .. text
    end

    -- the stat page (a card without a player): the item's every stat change, [icon] game name +N (green) / -N (red)
    function G.ItemCardStatParts(item)
      local E, parts = IC.effect, {}
      for si = 0, 7 do
        local ok, has, v = pcall(funcLuaCommand, @crc:CMND_GET_EQUIP_PARAM@, item, si)
        v = ok and has ~= false and tonumber(v) or 0
        local name = v ~= 0 and G.ItemCardStatName(si) or nil
        if name ~= nil then
          local key = IC.stat_by_index ~= nil and IC.stat_by_index[si + 1] or nil
          local icon = key ~= nil and E.stat_icons[key] or nil
          parts[#parts + 1] = {icon = icon ~= nil and string.format(E.sprites.stat, icon) or nil, name = name, value = v}
        end
      end
      return parts
    end

    -- the shown page's texts drawn on the icon layer: the stat row (centred, shrunk to the body's width) or the set's
    -- title row (centred)
    function G.ItemCardTextItems(rect)
      local E, out = IC.effect, {}
      local width = rect[3] - rect[1] - 2 * (IC.set_icons.margin or 0)
      if G.icStatPage ~= nil and G.icPage == G.icStatPage then
        local sc, groups = E.stat_scale, {}
        for _, p in ipairs(G.icStats or {}) do
          local pieces = {}
          if p.icon ~= nil then
            pieces[#pieces + 1] = {sprite = p.icon}
          end
          pieces[#pieces + 1] = {text = p.name}
          pieces[#pieces + 1] = {text = (p.value > 0 and "+" or "-") .. tostring(math.abs(p.value)),
            tag = p.value > 0 and IC.plus_colour or IC.minus_colour}
          groups[#groups + 1] = pieces
        end
        local function Total(scale)
          local t = 0
          for _, g in ipairs(groups) do
            t = t + PiecesWidth(g, "ink", scale)
          end
          return t + math.max(0, #groups - 1) * E.stat_gap
        end
        local total = Total(sc)
        if total > width and total > 0 then
          sc = sc * width / total
          total = Total(sc)
        end
        local x = rect[1] + ((rect[3] - rect[1]) - total) / 2
        for _, g in ipairs(groups) do
          DrawPieces(out, g, x, rect[2] + E.stat_row, "", "ink", sc)
          x = x + PiecesWidth(g, "ink", sc) + E.stat_gap
        end
      elseif G.icSetPage ~= nil and G.icPage == G.icSetPage and type(G.icSetTitle) == "string" then
        local sc = E.title_scale
        local w = EffWidth(G.icSetTitle, "ink") * sc
        if w > width and w > 0 then
          sc = sc * width / w
          w = width
        end
        DrawPieces(out, {{text = G.icSetTitle}}, rect[1] + ((rect[3] - rect[1]) - w) / 2, rect[2] + E.title_y, "",
          "ink", sc)
      end
      return out
    end

    function G.ItemCardEffectPage(effect)
      if type(effect) == "string" then
        return effect
      end
      if type(effect) ~= "table" then
        return nil
      end
      local lines = {}
      for _, l in ipairs(type(effect.lines) == "table" and effect.lines or {}) do
        lines[#lines + 1] = tostring(l)
      end
      local a = effect.affinity
      if type(a) == "table" then
        local B = IC.badges
        local label = tostring(a.label or "")
        local row = label
        local sprite = a.position ~= nil and B.sprites[a.position] or nil
        if sprite ~= nil then
          local lw = label ~= "" and TextWidth(label) or 0
          local dots = TextWidth(string.rep(".", 10))
          local both = TextWidth(string.rep(".", 10) .. string.rep(" ", 10))
          local sw = (dots ~= nil and both ~= nil and both > dots) and (both - dots) / 10 or B.space_px
          local spaces = math.ceil((B.size[1] + 2 * B.gap) / sw)
          row = label .. string.rep(" ", spaces)
          -- the badge in the middle of the spaces' room: the same gap before and after it
          local start = lw or #label * B.char_px
          G.icAffinity = {row = #lines + 1, sprite = sprite, x = start + (spaces * sw - B.size[1]) / 2}
        end
        if a.element ~= nil then
          row = row .. tostring(a.element) .. " "
        end
        lines[#lines + 1] = row .. tostring(a.text or "")
      end
      return table.concat(lines, "\n")
    end

    function G.ItemCardPages(item)
      G.icPages, G.icSetPage, G.icStatPage, G.icPageNames, G.icSetTitle = {}, nil, nil, {}, nil
      if item == nil or item == 0 or not G.ItemCardOn() then
        return
      end
      G.icAffinity, G.icEffectPage, G.icEffect, G.icSet = nil, nil, nil, nil
      local hdl = (not IC.no_player and type(G.hdl) == "number") and G.hdl or 0
      local ok, set = pcall(G.ItemCardSetPage, item)      -- first: the «Efecto» page uses the set's slots too
      local effect = Command(IC.page_command, item, hdl)
      local names = type(effect) == "table" and type(effect.page_names) == "table" and effect.page_names or {}
      if IC.stat_page then
        G.icStats = G.ItemCardStatParts(item)
        if #G.icStats > 0 then
          G.icPages[#G.icPages + 1] = ""
          G.icStatPage = #G.icPages
          G.icPageNames[#G.icPages] = names.stats
        end
      end
      if type(effect) == "table" and (type(effect.passive) == "table" or type(effect.affinity) == "table"
          or (type(effect.tiers) == "table" and #effect.tiers > 0)) then
        G.icEffect = effect
        G.icPages[#G.icPages + 1] = ""                    -- drawn by G.ItemCardEffectItems, no text
        G.icEffectPage = #G.icPages
        G.icPageNames[#G.icPages] = names.effect
      else
        local body = G.ItemCardEffectPage(effect)
        if body ~= nil and body ~= "" then
          G.icPages[#G.icPages + 1] = body
          G.icEffectPage = #G.icPages
        end
      end
      if ok and type(set) == "string" and set ~= "" then
        G.icPages[#G.icPages + 1] = IC.text_on_icons and "" or set
        G.icSetPage = #G.icPages
        G.icPageNames[#G.icPages] = names.set
      end
      if #G.icPages == 0 and IC.bonus_page_fallback ~= false and not IC.text_on_icons then
        G.icPages[1] = G.icBonus                          -- an item with neither page: its bonus row, as the game shows it
      end
      if G.icPage > #G.icPages then
        G.icPage = 1
      end
    end

    function G.ItemCard()
      local L, i = IC.layer, 0
      if not Exists(L) or Cmd(C.IS_OPEN, L, i) ~= true then
        G.itemCardPending = true
        return
      end
      G.itemCardPending = false
      if IC.relayout == false then
        return
      end
      local rect = G.ItemCardRect()
      local h = rect[4] - rect[2]
      -- the base sits at the card's `anchor`: the name / bonus texts keep their layout offsets from it (their own node
      -- moves are not drawn), every other node is placed from the card's top-left
      local ax, ay = IC.anchor[1], IC.anchor[2]
      local x0, y0 = rect[1], rect[2]
      Cmd(C.NODE_POS, L, i, IC.base, 0, x0 + ax - IC.root[1])
      Cmd(C.NODE_POS, L, i, IC.base, 1, IC.root[2] - (y0 + ay))
      for _, n in ipairs(IC.nodes) do
        local x, y, w, hh = n[2], n[3], n[4], n[5]
        if n.body then
          hh = h
        end
        Cmd(C.NODE_POS, L, i, n[1], 0, x - ax)
        Cmd(C.NODE_POS, L, i, n[1], 1, ay - y)
        if w ~= nil then
          Cmd(C.NODE_SCALE, L, i, n[1], w, hh)
        end
      end
      -- the retail body mesh off (its drop shadow); the white body is the stats panel's own (the host's card rect runs
      -- up under the item card: one panel), else a body layer of our own (IC.body_bottom)
      Cmd(C.MESH, L, IC.body_mesh, false, i)
      if IC.body_bottom == nil then
        G.Try("ItemCardBody", nil, false)
      else
        local body = {rect[1], rect[2], rect[3], math.max(rect[4], IC.body_bottom)}
        if not G.ItemCardBody(body, true) then
          G.itemCardPending = true
        end
      end
      if not G.icDumped then
        G.icDumped = true
        G.Try("ItemCardDump")
      end
    end

    -- once: where the card's nodes are drawn (CMND_GET_MESH_GLOBAL_POSITION), to loader.log
    function G.ItemCardDump()
      for _, n in ipairs(IC.dump or {}) do
        local ok, x, y = pcall(funcLuaMenuCommand, @crc:CMND_GET_MESH_GLOBAL_POSITION@, IC.layer, 0, n[1])
        pcall(funcLuaCommand, C.LOG, "EVT_PPG item card node", n[2], tostring(ok and x), tostring(ok and y))
      end
    end
