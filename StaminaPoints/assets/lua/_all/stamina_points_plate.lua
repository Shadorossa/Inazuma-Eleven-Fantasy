-- Stamina Points: the player's max PE in the player header (docs/game/mechanics/match-stamina.md §15,
-- docs/refactor/aura-mods-split.md «Player header»). A piece of Character Reforged's header slot: the entry «pe» of the
-- host character_reforged.header (content\menus\pe_plate_header.toml) names StaminaPoints.PlatePe, which Character
-- Reforged's header (assets\lua\_all\character_reforged_header.lua) calls on every refresh of a header plate with the
-- slot's x. Outside a match PE is always full, so the bar is full and the number is the player's max PE:
--   «PE»                            108   (the tag stamina_points_pe_tag01 of the match HUD, the number in Chrono
--   [====== full yellow bar ======]         Stone's digits stamina_points_pe_num0..9, both standing on the bar: tag
--                                           at its left end, number at its right end)
-- * Layers (content\menus\pe_plate.toml, added to every screen with the header): stamina_points_plate_bar (the retail
--   stairs-race gauge btl06_13, like the HUD bar), stamina_points_plate_tag (the same gauge, only its frame shown, the
--   frame's sprite swapped for the tag) and the digit layers stamina_points_plate_num (units), _num2 (tens), _num3
--   (hundreds): the same gauge again, frame only, its sprite swapped for the digit (a leading zero's layer hidden).
--   The header objects carry one attach row per layer (trace = the layer's name) at their root locator _pos_base01,
--   so the five follow the plate.
-- * Max PE: CMND_STAMINAPOINTS_PE_MAX(Físico, hdl) -> ok, max, modeOn (scripts\stamina_points.lua): the max PE of the
--   plate's card (content\match_resources\pe_max.toml at his level; Físico is passed as the plate radar reads it,
--   stat 4: funcLuaCommand(1131797651, hdl, 18, true, false)). Nothing is drawn without the command, in mode "log", or
--   on a screen without the layers; then the piece takes no width.
-- * Miximax (Chrono Stone: the miximax also gives the base PE): while Inazuma Fantasy's player page shows the
--   player's miximax (its globals EVT_R9.mx on ATRIBUTOS, or EVT_PPG.MxForm / CurForm on PERFIL; absent = never), the
--   number is his max PE + the miximax's PE gain (Inazuma Fantasy's CMND_EVT_MX_GAINS, 13th value; absent = 0).
-- Was Inazuma Fantasy's graft pe_card until 2026-10-14 (same drawing; the place is now the slot's x).
-- Defines functions only; engine calls only inside the header's callbacks; every call goes through pcall.
if type(rawget(_ENV, "UpdateCharaStatusPlateInfoByCharaStHdl")) == "function" then
  StaminaPoints = type(StaminaPoints) == "table" and StaminaPoints or {}
  if StaminaPoints.Plate == nil then
    local P = {}
    StaminaPoints.Plate = P
    P.ON = true                            -- false: no PE in the header
    P.CMD = 2515553432                     -- CMND_STAMINAPOINTS_PE_MAX
    P.MX_GAINS = 3782039711                -- CMND_EVT_MX_GAINS (Inazuma Fantasy)
    P.BAR = 4273026327                     -- stamina_points_plate_bar
    P.TAG = 2345078334                     -- stamina_points_plate_tag
    P.NUM = 1410143955                     -- stamina_points_plate_num
    P.NUM2 = 89862261                      -- stamina_points_plate_num2
    P.NUM3 = 1918632163                    -- stamina_points_plate_num3
    -- placement in the header layout units (y up, origin = the plate's _pos_base01 = the screen's top-left): the block
    -- starts at the slot's x (ctx.x); the tag 32 x 16 (TAG_DY below the band's top) on the bar's left end, the bar
    -- under it (visible ~198..206 on the band y 163..227), the number (3 digits 11 x 16) on the tag's row at the bar's
    -- right end
    P.TAG_DY, P.TAG_H = 20, 16                                 -- «PE» tag: top below the band's top, height (width 2 x)
    P.BAR_W, P.BAR_H = 112, 12                                 -- bar frame mesh size (retail frame 476 x 44); its
                                                               -- visible top touches the tag's bottom
    P.DIG_W, P.DIG_H = 11, 16             -- one digit cell (CS 8 x 12); the number ends at the bar's right end
    P.NUM_INSET = 6                        -- the number's right edge this far left of the mesh end (over the visible end)
    P.FIS_INDEX = 18                       -- 14 + stat 4 (Físico), as the plate radar reads it
    P.TAG_X, P.TAG_Y, P.BAR_X = 1453, -183, 1453               -- set from the slot at each fill

    -- retail names (crc32)
    local CMD_EXIST = 262659071            -- CMND_IS_EXIST_LAYER (layer)
    local CMD_OPEN = 629267548             -- CMND_OPEN_LAYER
    local CMD_IS_OPEN = 2640875187         -- CMND_IS_OPEN_LAYER
    local CMD_LOADING = 3057768039         -- CMND_IS_LOADING_LAYER
    local CMD_VISIBLE = 711242136          -- CMND_SET_LAYER_VISIBLE (layer, inst, on)
    local CMD_IS_VISIBLE = 1262717583      -- CMND_IS_LAYER_VISIBLE (layer, inst)
    local CMD_POS = 1389957207             -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z, inst)
    local CMD_SCALE = 3778714801           -- CMND_SET_LAYER_LOCAL_SCALE (layer, x, y, z, inst)
    local CMD_MESH = 3405944500            -- CMND_SET_MESH_VISIBLE (layer, mesh, on, inst)
    local CMD_TRACE = 1774843228           -- attach trace on / off (owner layer, inst, trace, on)
    local CMD_RATE_INIT = 541357333        -- (layer, rate setting, inst)
    local CMD_RATE = 1595998683            -- (layer, rate setting, inst, rate, 0, true)
    local CMD_SWAP_TEX = 558735651         -- (layer, atlas, new sprite, old sprite, 0, inst)
    local CMD_CHARA = 1131797651           -- chara status value (hdl, index, ...)
    -- the gauge (btl06_13_stamina_gauge): frame _hp_base01 top-left (94, -816), 476 x 44
    local G_X, G_Y, G_W, G_H = 94, -816, 476, 44
    local RATE_BAR, RATE_RED = 3060237847, 2546116024          -- hp_bar, hp_bar_red
    local MESH_FRAME, MESH_LABEL = 1837325853, 1257514352      -- _hp_base01, _gtxt_stamina01
    local MESH_EMPTY, MESH_FILL = 2609329121, 2043683848       -- _hp_empty01, _hp_bar02
    local ATLAS = 1191797350               -- #/menu/02_btl/btl06/btl06_13/<LG>/btl06_13.g4tx
    local TEX_TAG, TEX_FRAME = 2270199711, 538967808           -- stamina_points_pe_tag01, hp_base01
    local G_VIS_TOP = 2                    -- the frame's visible rows are 2..29 of the 44-row mesh
    -- Chrono Stone's digits stamina_points_pe_num0..9 (btl06_13 atlas, content\images\...\stamina_points_pe_num.toml)
    P.DIGITS = {[0] = 2312268123, 4275395021, 1742473335, 282802401, 2394926402, 4189625812, 1622264942, 397868280,
      2265571689, 4027503103}
    P.digit = {}                           -- per digit layer: the digit its frame shows now (nil = not swapped yet)

    P.want = nil                           -- {plate, inst, max}: what the plate shows now
    P.pending = false                      -- a draw waits for the layers to load
    P.shown = false
    P.ready = {}                           -- per layer: set up since it was opened
    P.ABSENT = false                       -- the loader has no CMND_STAMINAPOINTS_PE_MAX

    local function Pack(...)
      return {n = select("#", ...), ...}
    end

    local function Cmd(...)
      if type(funcLuaMenuCommand) ~= "function" then
        return false
      end
      local r = Pack(pcall(funcLuaMenuCommand, ...))
      if not r[1] then
        return false
      end
      return table.unpack(r, 2, r.n)
    end

    -- max PE of chara status handle hdl, nil = nothing to show (invalid handle, no command, mode "log")
    function P.MaxOf(hdl)
      if P.ABSENT or type(hdl) ~= "number" or hdl == 0 or type(funcLuaCommand) ~= "function" then
        return nil
      end
      if type(IsInvalidSoccerCharaHdl) == "function" then
        local ok, bad = pcall(IsInvalidSoccerCharaHdl, hdl)
        if ok and bad == true then
          return nil
        end
      end
      local okf, fis = pcall(funcLuaCommand, CMD_CHARA, hdl, P.FIS_INDEX, true, false)
      if not okf or type(fis) ~= "number" or fis ~= fis then
        return nil
      end
      local ok, has, max, on = pcall(funcLuaCommand, P.CMD, fis, hdl)
      if not ok or has == nil then
        return nil                         -- no answer this frame (the mod scripts were busy on another thread)
      end
      if has ~= true or on ~= 1 or type(max) ~= "number" or max <= 0 then
        return nil
      end
      return math.floor(max + 0.5)
    end

    -- Inazuma Fantasy's player page shows the miximax now (Miximax view on ATRIBUTOS, the Miximax form on PERFIL)
    function P.MxShown()
      local R = rawget(_ENV, "EVT_R9")
      if type(R) == "table" and R.mx == true then
        return true
      end
      local G = rawget(_ENV, "EVT_PPG")
      if type(G) ~= "table" or type(G.MxForm) ~= "function" or type(G.CurForm) ~= "function" then
        return false
      end
      local okm, mf = pcall(G.MxForm)
      local okc, cf = pcall(G.CurForm)
      return okm and okc and mf ~= nil and cf == mf
    end

    -- the PE the miximax of chara status handle hdl adds (CMND_EVT_MX_GAINS: ok, mask, 9 gains, kind, peGain); 0 = none
    function P.MxGain(hdl)
      local r = Pack(pcall(funcLuaCommand, P.MX_GAINS, hdl))
      if not r[1] or r[2] ~= true then
        return 0
      end
      local g = tonumber(r[14]) or 0
      return g > 0 and math.floor(g) or 0
    end

    -- local position / scale of each layer (attached at the plate's _pos_base01, header layout units)
    function P.BarTop()
      return P.TAG_Y - P.TAG_H + G_VIS_TOP * P.BAR_H / G_H
    end

    function P.BarPos()
      local sx, sy = P.BAR_W / G_W, P.BAR_H / G_H
      return P.BAR_X - G_X * sx, P.BarTop() - G_Y * sy, sx, sy
    end

    function P.TagPos()
      local sx, sy = 2 * P.TAG_H / G_W, P.TAG_H / G_H
      return P.TAG_X - G_X * sx, P.TAG_Y - G_Y * sy, sx, sy
    end

    -- digit layer k (1 = units, 2 = tens, 3 = hundreds): cells right-aligned at the bar's right end, standing on the
    -- bar's visible frame like the tag (their bottom = the tag's bottom)
    function P.NumPos(k)
      local sx, sy = P.DIG_W / G_W, P.DIG_H / G_H
      local x0 = P.BAR_X + P.BAR_W - P.NUM_INSET - k * P.DIG_W
      local top = P.TAG_Y - P.TAG_H + P.DIG_H
      return x0 - G_X * sx, top - G_Y * sy, sx, sy
    end

    local function Digits()
      return {P.NUM, P.NUM2, P.NUM3}
    end

    local function Layers()
      return {P.BAR, P.TAG, P.NUM, P.NUM2, P.NUM3}
    end

    local function HideAll()
      for _, l in ipairs(Layers()) do
        Cmd(CMD_VISIBLE, l, 0, false)
      end
      P.shown = false
    end

    function P.Hide()
      P.want, P.pending = nil, false
      if P.shown then
        HideAll()
      end
    end

    -- open once; true when loaded
    local function Ready(l)
      if Cmd(CMD_IS_OPEN, l) ~= true then
        P.ready[l] = false
        P.digit[l] = nil
        Cmd(CMD_OPEN, l)
        return false
      end
      return Cmd(CMD_LOADING, l) ~= true
    end

    local function Setup(l)
      if l == P.BAR then
        Cmd(CMD_RATE_INIT, l, RATE_BAR, 0)
        Cmd(CMD_RATE_INIT, l, RATE_RED, 0)
        Cmd(CMD_MESH, l, MESH_LABEL, false, 0)
        Cmd(CMD_MESH, l, MESH_EMPTY, false, 0)
      else                                 -- the tag and the digits: the gauge's frame only
        Cmd(CMD_MESH, l, MESH_LABEL, false, 0)
        Cmd(CMD_MESH, l, MESH_EMPTY, false, 0)
        Cmd(CMD_MESH, l, MESH_FILL, false, 0)
        if l == P.TAG then
          Cmd(CMD_SWAP_TEX, l, ATLAS, TEX_TAG, TEX_FRAME, 0, 0)
        else
          P.digit[l] = nil
        end
      end
    end

    -- the digits of n, units first: {units, tens, hundreds}, nil for a leading zero
    function P.DigitsOf(n)
      n = math.max(0, math.min(999, math.floor(n)))
      local d = {n % 10}
      if n >= 10 then
        d[2] = math.floor(n / 10) % 10
      end
      if n >= 100 then
        d[3] = math.floor(n / 100)
      end
      return d
    end

    -- the five layers on the plate of P.want; false = still loading (the step tries again)
    function P.Draw()
      local w = P.want
      if w == nil then
        return true
      end
      local all = true
      for _, l in ipairs(Layers()) do
        if not Ready(l) then
          all = false
        end
      end
      if not all then
        P.pending = true
        return false
      end
      P.pending = false
      for _, l in ipairs(Layers()) do
        if not P.ready[l] then
          P.ready[l] = true
          Setup(l)
        end
        Cmd(CMD_TRACE, w.plate, w.inst, l, true)
      end
      local x, y, sx, sy = P.BarPos()
      Cmd(CMD_SCALE, P.BAR, sx, sy, 1, 0)
      Cmd(CMD_POS, P.BAR, x, y, 0, 0)
      Cmd(CMD_RATE, P.BAR, RATE_BAR, 0, 1, 0, true)            -- outside a match PE is always full
      Cmd(CMD_RATE, P.BAR, RATE_RED, 0, 1, 0, true)
      x, y, sx, sy = P.TagPos()
      Cmd(CMD_SCALE, P.TAG, sx, sy, 1, 0)
      Cmd(CMD_POS, P.TAG, x, y, 0, 0)
      local dig = P.DigitsOf(w.max)
      for k, l in ipairs(Digits()) do
        local d = dig[k]
        if d ~= nil then
          x, y, sx, sy = P.NumPos(k)
          Cmd(CMD_SCALE, l, sx, sy, 1, 0)
          Cmd(CMD_POS, l, x, y, 0, 0)
          if P.digit[l] ~= d then
            P.digit[l] = d
            Cmd(CMD_SWAP_TEX, l, ATLAS, P.DIGITS[d], TEX_FRAME, 0, 0)
          end
        end
      end
      Cmd(CMD_VISIBLE, P.BAR, 0, true)
      Cmd(CMD_VISIBLE, P.TAG, 0, true)
      for k, l in ipairs(Digits()) do
        Cmd(CMD_VISIBLE, l, 0, dig[k] ~= nil)
      end
      P.shown = true
      return true
    end

    -- one header refresh (ctx of Character Reforged's slot): the width the PE block takes (0 = nothing drawn)
    function P.Fill(ctx)
      if not P.ON then
        return 0
      end
      if Cmd(CMD_EXIST, P.BAR) ~= true then
        return 0                           -- a screen without the PE layers
      end
      local max = P.MaxOf(ctx.hdl)
      if max == nil then
        P.Hide()
        return 0
      end
      P.TAG_X, P.BAR_X = ctx.x, ctx.x
      P.TAG_Y = ctx.top - P.TAG_DY
      local mx = P.MxShown()
      P.want = {plate = ctx.layer, inst = ctx.inst or 0, base = max, hdl = ctx.hdl, mx = mx,
                max = max + (mx and P.MxGain(ctx.hdl) or 0)}
      P.Draw()
      return P.BAR_W
    end

    -- every frame: finish a pending draw; follow the plate's visibility and the page's Normal / Miximax view
    function P.Step()
      if P.pending then
        P.Draw()
        return
      end
      local w = P.want
      if w == nil then
        return
      end
      local mx = P.MxShown()
      if mx ~= w.mx then
        w.mx = mx
        w.max = w.base + (mx and P.MxGain(w.hdl) or 0)
        if P.shown then
          P.Draw()
          return
        end
      end
      local vis = Cmd(CMD_IS_VISIBLE, w.plate, w.inst) == true
      if P.shown and not vis then
        HideAll()
      elseif not P.shown and vis then
        P.Draw()
      end
    end

    -- the header slot's piece (CharacterReforged.Header: f(phase, ctx))
    function StaminaPoints.PlatePe(phase, ctx)
      if phase == "fill" then
        return P.Fill(ctx)
      elseif phase == "step" then
        P.Step()
      end
      return 0
    end
  end
end
