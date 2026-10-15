-- player page dots (VR-Framework base feature): the page dots of the player plate
-- (personal_plate_menu) built from the registry's actual page list, so a page any mod declares
-- gets its own dot and the lit dot follows it.
--
-- * Retail order (the four retail pages only): nothing changes, the status base draws its own four dots.
-- * Any other order: the status base's four dots are hidden and the row is drawn by the layer vrfw_pp_dots (copies of
--   the retail status base soccer11_05_formation_status_base, content\menus\player_page_dots.toml), each copy showing
--   its own four dot meshes (_page01..04_off, the lit one _page0N_on) and nothing else. Two copies = up to 8 dots.
--   The copies hang from the status base's _pos_base01 (attach rows vrfw_pp_dots0 / 1), so they follow its animation.
--   The row keeps the retail centre (x 1420) and pitch (28 px) whatever the page count.
-- * A mod that draws its own dots on its own plate sets VRFW_PlayerPages.DotsOwner = "<ModPrefix>" (any time, plain
--   field): the framework then leaves the dots alone. A paged plate that defines EVT_PH_Decor is
--   treated the same way until it sets the field.
-- * VRFW_PlayerPages.DotRow() gives the row as drawn (for the mods that place things next to it, e.g. Q / E
--   glyphs); VRFW_PlayerPages.StatusCopy(...) is the shared set-up of a status base copy (open once, attach, every
--   part hidden but the ones kept).
-- No engine call at load time.
if VRFW_PlayerPages ~= nil and VRFW_PlayerPages.Row == nil then
  local P = VRFW_PlayerPages

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

  local function Names(list)
    local out = {}
    for i, n in ipairs(list) do
      out[i] = Crc(n)
    end
    return out
  end

  local R = {
    C = {EXIST = 262659071, OPEN = 629267548, IS_OPEN = 2640875187, LOADING = 3057768039, VIS = 711242136,
      IS_VIS = 1262717583, POS = 1389957207, MESH = 3405944500, TRACE = 1774843228, TEXT_VIS = 1505208242,
      NODE_VIS = 2158717427},
    L_STATUS = Crc("soccer11_05_formation_status_base"),
    LAYER = Crc("vrfw_pp_dots"),
    TRACES = {[0] = Crc("vrfw_pp_dots0"), Crc("vrfw_pp_dots1")},
    COPIES = 2,
    PER_COPY = 4,
    -- soccer11_05.g4pkm (screen px, y down): the retail dots' top-left x 1362 + 28 k, y 949, 32 x 32; the layout's
    -- _pos_base01 at (1358, 540) = where the copies hang (a copy's part lands at its layout place + the layer position
    -- + (1358, -540))
    DOT_X1 = 1362, DOT_Y = 949, PITCH = 28, SIZE = 32, RETAIL = 4, BASE_X = 1358, BASE_Y = 540,
    -- the status base's parts (soccer11_05.g4pkm joints)
    OFF = Names({"_page01_off", "_page02_off", "_page03_off", "_page04_off"}),
    ON = Names({"_page01_on", "_page02_on", "_page03_on", "_page04_on"}),
    ON_RPG = Names({"_page01_on_rpg", "_page02_on_rpg"}),
    PAGE_LOCS = Names({"_pos_page01", "_pos_page02", "_pos_page03", "_pos_page04"}),
    OTHER_LOCS = Names({"_pos_page01_rpg", "_pos_page02_rpg", "_pos_equip01", "_pos_equip01_rpg", "_pos_arrow01_l",
      "_pos_arrow01_r"}),
    MESHES = {"_arrow01_l", "_arrow01_r", "_page01_off", "_page02_off", "_page03_off", "_page04_off", "_page01_on",
      "_page02_on", "_page03_on", "_page04_on", "_page01_on_rpg", "_page02_on_rpg", "_gtxt_parameters01",
      "_gtxt_parameters02", "_gtxt_teampassives01", "_gtxt_sixthsense01", "_gtxt_parameters01_rpg",
      "_gtxt_parameters02_rpg", "_cmd_slot01", "_cmd_slot02", "_cmd_slot03", "_cmd_slot01_rpg", "_cmd_slot02_rpg",
      "_cmd_slot03_rpg", "_sixth_base01"},
    TEXTS = {"_text_btn_l01", "_text_btn_r01"},
    copies = {},                 -- [layer * 16 + k] = {asked = opened by us, ready = set up}
    drawn = nil,                 -- the row state last drawn ("" = hidden)
    active = false,              -- the framework draws the row (the retail dots hidden)
  }
  P.Row = R
  R.MESH_IDS = {}
  for _, n in ipairs(R.MESHES) do
    R.MESH_IDS[n] = Crc(n)
  end
  R.TEXT_IDS = {}
  for _, n in ipairs(R.TEXTS) do
    R.TEXT_IDS[n] = Crc(n)
  end

  local function Cmd(...)
    local ok, v = pcall(funcLuaMenuCommand, ...)
    if ok then
      return v
    end
    return nil
  end

  -- the four retail pages in retail order, nothing else shown
  local function RetailOrder(o)
    if #o ~= R.RETAIL then
      return false
    end
    for i, v in ipairs(o) do
      if v ~= i - 1 then
        return false
      end
    end
    return true
  end

  local function Owned()
    return P.DotsOwner ~= nil or type(EVT_PH_Decor) == "function"
  end

  local function StatusShown()
    if Cmd(R.C.EXIST, R.L_STATUS) ~= true or Cmd(R.C.IS_OPEN, R.L_STATUS, 0) ~= true then
      return false
    end
    return Cmd(R.C.IS_VIS, R.L_STATUS, 0) ~= false
  end

  -- One instance of a copy of the retail status base, ready to show: opened ONCE per opening of the status base (an
  -- instance the menu closed is not opened again until the status base itself closes: a re-open during the menu's
  -- exit would hang it), attached to the status base's _pos_base01 (`trace` = its attach row) and every part hidden
  -- but `keep` = {"<mesh or text node name>" = true}. Returns ready (loaded and set up), fresh (set up just now, hidden:
  -- the caller places and shows it again).
  function P.StatusCopy(layer, k, trace, keep)
    if Cmd(R.C.EXIST, layer) ~= true then
      return false
    end
    local key = layer * 16 + k
    local s = R.copies[key]
    if s == nil then
      s = {}
      R.copies[key] = s
    end
    if Cmd(R.C.IS_OPEN, layer, k) ~= true then
      s.ready = false
      if not s.asked and StatusShown() then
        s.asked = true
        Cmd(R.C.OPEN, layer, k)
      end
      return false
    end
    if Cmd(R.C.LOADING, layer) == true then
      return false
    end
    if not s.ready then
      s.ready = true
      keep = keep or {}
      Cmd(R.C.VIS, layer, k, false)
      Cmd(R.C.TRACE, R.L_STATUS, 0, trace, true)
      for _, n in ipairs(R.OTHER_LOCS) do
        Cmd(R.C.NODE_VIS, layer, n, false, k)
      end
      for _, n in ipairs(R.PAGE_LOCS) do
        Cmd(R.C.NODE_VIS, layer, n, true, k)
      end
      for _, n in ipairs(R.MESHES) do
        if not keep[n] then
          Cmd(R.C.MESH, layer, R.MESH_IDS[n], false, k)
        end
      end
      for _, n in ipairs(R.TEXTS) do
        Cmd(R.C.TEXT_VIS, layer, R.TEXT_IDS[n], keep[n] == true, k)
      end
      return true, true
    end
    return true, false
  end

  -- the row as drawn on this plate: {count, x0 (left of the first dot), y (top), pitch, size, lit (slot or nil),
  -- framework = the framework draws it, keys = the header's Q / E glyphs and arrows are shown (the retail
  -- SetStatusBaseArrowAndTextVisible: off while a detail window is up or on a one-page view)}; nil = no row of ours
  -- (another mod owns the dots, or the plate is not shown)
  function P.DotRow()
    if Owned() or not StatusShown() then
      return nil
    end
    local o = P.Order()
    local n = #o
    if RetailOrder(o) then
      n = R.RETAIL
    end
    if n < 1 then
      return nil
    end
    n = math.min(n, R.COPIES * R.PER_COPY)
    local cx = R.DOT_X1 + ((R.RETAIL - 1) * R.PITCH + R.SIZE) / 2
    local lit = nil
    local cur = type(GetNowPageIdx) == "function" and GetNowPageIdx() or nil
    for i, v in ipairs(o) do
      if v == cur and i <= n then
        lit = i
      end
    end
    return {count = n, x0 = cx - ((n - 1) * R.PITCH + R.SIZE) / 2, y = R.DOT_Y, pitch = R.PITCH, size = R.SIZE,
      lit = lit, framework = not RetailOrder(o), keys = R.arrows ~= false}
  end

  -- the status base's own dots: hidden while the framework draws the row, back when it stops
  local function RetailDots(on)
    for i = 1, R.RETAIL do
      Cmd(R.C.MESH, R.L_STATUS, R.OFF[i], on, 0)
      Cmd(R.C.MESH, R.L_STATUS, R.ON[i], on, 0)
    end
    for _, m in ipairs(R.ON_RPG) do
      Cmd(R.C.MESH, R.L_STATUS, m, on, 0)
    end
  end

  local function HideCopies()
    for k = 0, R.COPIES - 1 do
      if Cmd(R.C.IS_OPEN, R.LAYER, k) == true then
        Cmd(R.C.VIS, R.LAYER, k, false)
      end
    end
  end

  -- every frame: the row from the registry (cheap when nothing changed)
  function R.Frame()
    local row = P.DotRow()
    if row == nil or not row.framework then
      -- (row nil = plate not shown / dots owned elsewhere: the retail dots stay as they are until the row is back)
      if row ~= nil and R.active then
        R.active = false
        RetailDots(true)
      end
      if R.drawn ~= "" then
        R.drawn = ""
        HideCopies()
      end
      return
    end
    R.active = true
    RetailDots(false)
    local state = row.count .. ":" .. tostring(row.lit) .. ":" .. row.x0
    local all = true
    for k = 0, R.COPIES - 1 do
      local first = k * R.PER_COPY + 1
      if first <= row.count then
        local ready, fresh = P.StatusCopy(R.LAYER, k, R.TRACES[k], {})
        if not ready then
          all = false
        elseif fresh then
          R.drawn = nil
        end
      end
    end
    if not all then
      R.drawn = nil
      return
    end
    if state == R.drawn then
      return
    end
    R.drawn = state
    for k = 0, R.COPIES - 1 do
      local first = k * R.PER_COPY + 1
      if first <= row.count then
        local dx = row.x0 + (first - 1) * R.PITCH - R.DOT_X1
        Cmd(R.C.POS, R.LAYER, dx - R.BASE_X, R.BASE_Y, 0, k)
        for j = 1, R.PER_COPY do
          local slot = first + j - 1
          Cmd(R.C.MESH, R.LAYER, R.OFF[j], slot <= row.count, k)
          Cmd(R.C.MESH, R.LAYER, R.ON[j], slot == row.lit, k)
        end
        Cmd(R.C.VIS, R.LAYER, k, true)
      elseif Cmd(R.C.IS_OPEN, R.LAYER, k) == true then
        Cmd(R.C.VIS, R.LAYER, k, false)
      end
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
      pcall(R.Frame)
      return table.unpack(r, 1, r.n)
    end
  end)

  -- the header's arrows / glyphs on or off (retail personal_plate_inc), for DotRow().keys
  Wrap("SetStatusBaseArrowAndTextVisible", function(orig)
    return function(a1, ...)
      R.arrows = a1 ~= false
      return orig(a1, ...)
    end
  end)

  -- a copy the engine (re)opens is set up again (hidden until then)
  Wrap("OnOpenLayer", function(orig)
    return function(a1, a2, ...)
      local r = table.pack(orig(a1, a2, ...))
      local s = type(a1) == "number" and type(a2) == "number" and R.copies[a1 * 16 + a2] or nil
      if s ~= nil then
        s.ready = false
        Cmd(R.C.VIS, a1, a2, false)
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  -- the status base closing: every copy may be opened again next time
  Wrap("OnCloseLayer", function(orig)
    return function(a1, a2, ...)
      local r = table.pack(orig(a1, a2, ...))
      if a1 == R.L_STATUS then
        R.copies = {}
        R.drawn = nil
      end
      return table.unpack(r, 1, r.n)
    end
  end)
end
