-- BetterUI (mod clean_hud, prefix BetterUI), player plate («Ficha», personal_plate_menu): the Q / E key glyphs beside
-- the page dots at the bottom of the plate (README.md «Player plate page keys»; content\menus\page_keys.toml).
-- Layer clean_hud_pp_keys = two copies of the retail status base: instance 0 shows only _text_btn_l01, instance 1 only
-- _text_btn_r01, the plate header's own glyph texts (retail «<CMD_FUNCL2|6>» / «<CMD_FUNCR2|6>»: the key on a keyboard,
-- the pad's button on a pad, swapped by the game with the input device like the header). Each frame the glyphs sit at
-- the ends of the dot row the VR-Framework reports (VRFW_PlayerPages.DotRow, docs/framework/player-pages.md §7): each
-- glyph's centre 40 px from the first / last dot's centre, 8 px higher than the dots (Inazuma Fantasy's paged plate
-- spacing, made symmetric), so the whole «Q • • • E» row stays centred whatever the page count. No row (plate hidden, or a mod that draws
-- its own dots and glyphs: Inazuma Fantasy's plate) or the header's glyphs off (a detail window, a one-page view) = no
-- glyphs. No engine call at load time.
BetterUI = type(BetterUI) == "table" and BetterUI or {}
if BetterUI.PageKeys == nil then
  local function Crc(s)
    local crc = 0xFFFFFFFF
    for i = 1, #s do
      crc = bit32.bxor(crc, string.byte(s, i))
      for _ = 1, 8 do
        if bit32.band(crc, 1) ~= 0 then
          crc = bit32.bxor(bit32.rshift(crc, 1), 0xEDB88320)
        else
          crc = bit32.rshift(crc, 1)
        end
      end
    end
    return bit32.bxor(crc, 0xFFFFFFFF)
  end

  local K = {
    LAYER = Crc("clean_hud_pp_keys"),
    TRACES = {[0] = Crc("clean_hud_pp_keys0"), Crc("clean_hud_pp_keys1")},
    TEXTS = {[0] = "_text_btn_l01", "_text_btn_r01"},
    -- soccer11_05.g4pkm: the glyph texts' layout top-left (x; y down), 32 x 32
    AT_X = {[0] = 1039, 1811},
    AT_Y = 496,
    GAP_L = 40,                  -- Q: its left edge this far left of the first dot's
    GAP_R = 40,                  -- E: its left edge this far right of the last dot's (symmetric: the row stays centred)
    RAISE = 8,                   -- the glyphs this much higher than the dots
    C = {IS_OPEN = VRFW_Cmd.IS_OPEN_LAYER, VIS = VRFW_Cmd.SET_LAYER_VISIBLE, POS = VRFW_Cmd.SET_LAYER_LOCAL_POS},
    drawn = nil,
  }
  BetterUI.PageKeys = K

  local function Cmd(...)
    local ok, v = pcall(funcLuaMenuCommand, ...)
    if ok then
      return v
    end
    return nil
  end

  local function Hide()
    for k = 0, 1 do
      if Cmd(K.C.IS_OPEN, K.LAYER, k) == true then
        Cmd(K.C.VIS, K.LAYER, k, false)
      end
    end
  end

  function K.Frame()
    local P = VRFW_PlayerPages
    if P == nil or type(P.DotRow) ~= "function" or type(P.StatusCopy) ~= "function" or P.Row == nil then
      return
    end
    local row = P.DotRow()
    if row == nil or row.keys == false then
      if K.drawn ~= "" then
        K.drawn = ""
        Hide()
      end
      return
    end
    local all = true
    for k = 0, 1 do
      local ready, fresh = P.StatusCopy(K.LAYER, k, K.TRACES[k], {[K.TEXTS[k]] = true})
      if not ready then
        all = false
      elseif fresh then
        K.drawn = nil
      end
    end
    if not all then
      return
    end
    local state = row.count .. ":" .. row.x0 .. ":" .. row.y
    if state == K.drawn then
      return
    end
    K.drawn = state
    local x = {[0] = row.x0 - K.GAP_L, row.x0 + (row.count - 1) * row.pitch + K.GAP_R}
    local y = row.y - K.RAISE
    for k = 0, 1 do
      -- a copy's part lands at its layout place + the layer position + the status base's _pos_base01 (x right, y up)
      Cmd(K.C.POS, K.LAYER, x[k] - K.AT_X[k] - P.Row.BASE_X, P.Row.BASE_Y + K.AT_Y - y, 0, k)
      Cmd(K.C.VIS, K.LAYER, k, true)
    end
  end

  local wrapped = {}
  local function Wrap(name, make)
    local cur = _ENV[name]
    if type(cur) ~= "function" or wrapped[cur] then
      return
    end
    local w = make(cur)
    wrapped[w] = true
    _ENV[name] = w
  end

  Wrap("PostStep", function(orig)
    return function(...)
      local r = table.pack(orig(...))
      pcall(K.Frame)
      return table.unpack(r, 1, r.n)
    end
  end)

  -- the status base closing: the copies are set up again when they come back
  Wrap("OnCloseLayer", function(orig)
    return function(a1, a2, ...)
      local r = table.pack(orig(a1, a2, ...))
      if VRFW_PlayerPages ~= nil and VRFW_PlayerPages.Row ~= nil and a1 == VRFW_PlayerPages.Row.L_STATUS then
        K.drawn = nil
      end
      return table.unpack(r, 1, r.n)
    end
  end)
end
