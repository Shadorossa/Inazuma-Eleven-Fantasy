-- BetterUI (mod clean_hud, prefix BetterUI), player plate («Ficha», personal_plate_menu): on Battle Bay Deluxe's
-- lineup screen (the «Plantilla» viewer of the Battle Bay grid, the player page on its right half) the page's header
-- shows no level: the «Nv.» label, the level lock, the level digits and the experience gauge under them stay hidden.
-- That screen is recognised by the parameter BattleBayDeluxe.lineup of the game's parameter store (set by Battle Bay
-- Deluxe while its player page is up) inside the framework context battle_bay. Every player change fills the header
-- again, so the parts are hidden after each header fill and once a frame. Elsewhere nothing changes.
-- No engine call at load time.
BetterUI = type(BetterUI) == "table" and BetterUI or {}
if BetterUI.LineupLevel == nil then
  local L = {
    FLAG = 2100506454,                   -- crc32 of BattleBayDeluxe.lineup (Battle Bay Deluxe's parameter)
    CONTEXT = "battle_bay",              -- the framework context of the Battle Bay's menus
    HEADERS = {1844915256, 607716004},   -- soccer11_04_formation_chara_status, soccer11_04_chara_status
    MESHES = {1034363700 --[[_gtxt_status_lv01]], 4071435007 --[[_icon_lock_lv01]]},
    NODES = {2976428572 --[[_num_status_lv01]], 1469422130 --[[_pos_exp01]]},
    DIGITS = 3434305008,                 -- num_status_lv01, the level digits' number setting
    C = {
      PARAM_EXISTS = 2947612279, MODE_IS = 624411898 --[[CMND_VRFW_MODE_IS]],
      LAYER_COUNT = 1175615627 --[[CMND_GET_CREATE_LAYER_NUM]], IS_OPEN = 2640875187 --[[CMND_IS_OPEN_LAYER]],
      MESH = 3405944500 --[[CMND_SET_MESH_VISIBLE]], NODE = 2158717427, PRIM = 1233047821,
    },
    ASK_EVERY = 10,                      -- frames between two looks at the parameter
    frames = nil,
    on = false,
  }
  BetterUI.LineupLevel = L

  local function Cmd(...)
    local ok, v = pcall(funcLuaMenuCommand, ...)
    if ok then
      return v
    end
    return nil
  end

  -- the lineup screen shows this page
  function L.Lineup()
    local ok, has = pcall(funcLuaCommand, L.C.PARAM_EXISTS, L.FLAG)
    if not (ok and has == true) then
      return false
    end
    local okm, inside = pcall(funcLuaCommand, L.C.MODE_IS, L.CONTEXT)
    return okm and inside == true
  end

  -- the level parts off on every open header plate of this menu
  function L.Hide()
    for _, layer in ipairs(L.HEADERS) do
      local count = Cmd(L.C.LAYER_COUNT, layer)
      count = type(count) == "number" and count or 1
      for k = 0, count - 1 do
        if Cmd(L.C.IS_OPEN, layer, k) == true then
          for _, mesh in ipairs(L.MESHES) do
            Cmd(L.C.MESH, layer, mesh, false, k)
          end
          for _, node in ipairs(L.NODES) do
            Cmd(L.C.NODE, layer, node, false, k)
          end
          Cmd(L.C.PRIM, layer, k, L.DIGITS, false)
        end
      end
    end
  end

  function L.Frame()
    L.frames = (L.frames or L.ASK_EVERY) + 1
    if L.frames >= L.ASK_EVERY then
      L.frames = 0
      L.on = L.Lineup()
    end
    if L.on then
      L.Hide()
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
      pcall(L.Frame)
      return table.unpack(r, 1, r.n)
    end
  end)

  -- a header fill (a player change) shows the level again: hidden right after it
  Wrap("UpdateCharaStatusPlateInfoByCharaStHdl", function(orig)
    return function(...)
      local r = table.pack(orig(...))
      if L.on then
        pcall(L.Hide)
      end
      return table.unpack(r, 1, r.n)
    end
  end)
end
