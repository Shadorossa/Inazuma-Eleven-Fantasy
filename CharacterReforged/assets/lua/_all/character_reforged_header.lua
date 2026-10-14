-- Character Reforged: the player header's SLOT (docs/refactor/aura-mods-split.md «Player header»). The one-row player
-- header (content\menus\player_header.toml: Inazuma Fantasy's header, the base's since 2026-10-14) leaves a free strip
-- between the gender icon and the rarity banner; the mods that declare an [[entry]] of the host
-- character_reforged.header (content\menus\player_header_host.toml) draw their pieces there, left to right in the
-- entries' order. This file is that slot's run time, in every menu VM that has the retail plate functions
-- (soccer_common / personal_plate_inc: UpdateCharaStatusPlateInfoByCharaStHdl):
-- * every refresh of a header plate (the layers soccer11_04_formation_chara_status / soccer11_04_chara_status, the
--   ones content\menus\player_header.toml gives the one-row object) calls each entry's function f("fill", ctx) with
--   ctx.x = the piece's left edge; its answer (a width, 0 / nil = nothing) moves the next piece;
-- * once or twice a frame (after the screen's PostStep / Step) f("step", ctx) with the ctx of the last fill.
-- ctx = {key, layer, inst, hdl, x, top, height, room}: header layout units (the plate's _pos_base01 = the screen's
-- top-left, y up), the same units as the attach rows of the pieces' layers.
-- For other mods' menu Lua: CharacterReforged.Header.SLOT (the strip), .Items() (the declared pieces), .IsHeader(layer).
-- The header BAND's colour (the slanted band under the row on the player page, VRFW_UI.HeaderRow.BandFill):
-- .BandColour(layer, inst, hdl) asks the pieces of the host character_reforged.header_band in order (f(layer, inst,
-- hdl) -> true = it painted the band; No More Rarities' position colour is one); none painted = .RarityBand: the
-- retail rarity look (the card's own rarity sprite, as the retail office plate shows it).
-- The header's rarity title (the row's banner _player_rarity01, left of «Nv.»): .ShowsRarity(hdl) asks the pieces of
-- the host character_reforged.header_rarity (f(hdl) -> false = no title for that card; No More Rarities removes the
-- titles of the rarities it removes); none says no = the retail title. A plate whose title is off is kept off every
-- frame (a special card's «hero» animation can switch the banner back on). 2026-10-14 (owner: both titles showed for a
-- moment on a normal card): a header plate's title starts OFF when its instance is set up / opened (before the
-- screen's own OnSetupLayer / OnOpenLayer, which may fill it at once), so the layout's default banner is never drawn;
-- the first fill decides. Off = the banner mesh and its parent node _pos_rarity01 (it holds only the banner).
-- The Diamond plate's wave effect (ega1450a_2, attached to the retail header object at the retail plate's centre,
-- made for the 196 px plate) is not part of the one-row header object (content\menus\player_header.toml
-- remove_block): it drew a big empty frame under the 64 px band. The band keeps the Diamond look (the rarity sprite,
-- the seasonal frame mesh fitted to the band with the basara sprites).
-- Wrappers only (UpdateCharaStatusPlateInfoByCharaStHdl, OnSetupLayer, OnOpenLayer, PostStep, Step); no engine call
-- at chunk load; every call to a piece goes through pcall.
CharacterReforged = type(CharacterReforged) == "table" and CharacterReforged or {}
if type(rawget(_ENV, "UpdateCharaStatusPlateInfoByCharaStHdl")) == "function" and CharacterReforged.Header == nil then
  local H = {}
  CharacterReforged.Header = H
  H.HOST = "character_reforged.header"
  -- the header layers (crc32 of soccer11_04_formation_chara_status, soccer11_04_chara_status): the layers whose object
  -- content\menus\player_header.toml swaps for the one-row header evt_soccer11_04pp_pp
  H.LAYERS = {[1844915256] = true, [607716004] = true}
  -- the strip: x 1453..1599 (gender icon ends 1445, rarity banner starts 1607), the band y 163..227 (screen px, y
  -- down) = research/scripts/if_plate_row_build.py (BAND, the row's pieces)
  H.SLOT = {x = 1453, x_end = 1599, top = -163, height = 64}
  H.GAP = 8                              -- between two pieces
  H.items = nil                          -- the declared pieces {key, path}, read at the first header fill
  H.BAND_HOST = "character_reforged.header_band"
  H.bandItems = nil                      -- the declared band colours {key, path}, read at the first band fill
  -- the band's rarity sprite: the retail office plate's rule (soccer_common UpdateCharaStatusPlateInfoByCharaStHdl
  -- with a plate type other than 0): sprite "status_chr_base01_s<rarity + 1>" (Diamante 8 -> 10) on the texture slot
  -- status_chr_base01_s01 of the band mesh _status_chr_base_s01. The band copy is filled with plate type 0, which swaps
  -- another slot (status_chr_base01_01, a mesh the soccer11_04 layout does not have): without this the band shows the
  -- slot's default sprite (the green rarity-0 plate) for every player.
  H.STATUS_TEXTURE = 348706892           -- #/menu/00_soccer/soccer11/soccer11_04/<LG>/soccer11_04.g4tx
  H.STATUS_BAND_SLOT = 1621728801        -- status_chr_base01_s01
  H.CHARA = 1131797651                   -- CMND_GET_CHARA (hdl, 12) = the card's rarity
  H.SWAP_SPRITE = 558735651              -- (layer, texture, sprite, slot, 0, inst)
  H.ctx = {}                             -- per piece key: the ctx of its last fill
  H.RARITY_HOST = "character_reforged.header_rarity"
  H.rarityItems = nil                    -- the declared rarity title rules {key, path}, read at the first header fill
  H.RARITY_MESH = 1052197874             -- _player_rarity01 (the row's rarity title)
  H.MESH_VISIBLE = 3405944500            -- CMND_SET_MESH_VISIBLE (layer, mesh, on, inst)
  H.RARITY_NODE = 1457835367             -- _pos_rarity01 (the banner's parent: only the banner hangs there)
  H.NODE_VISIBLE = 2158717427            -- the node visibility command (layer, node, on, inst)
  H.rarityOff = {}                       -- "layer:inst" -> {layer, inst} of the header plates whose title is off

  local function Pack(...)
    return {n = select("#", ...), ...}
  end

  function H.IsHeader(layer)
    return H.LAYERS[layer] == true
  end

  -- the [[entry]] functions of a host, in its order (VRFW_Menu.entries: order, load order, file order; only the
  -- active mods' entries are there)
  local function HostItems(host)
    local out = {}
    local M = rawget(_ENV, "VRFW_Menu")
    if type(M) == "table" and type(M.entries) == "function" then
      local ok, list = pcall(M.entries, host)
      if ok and type(list) == "table" then
        for _, e in ipairs(list) do
          if e.kind == "lua" and type(e.value) == "string" and e.value ~= "" then
            out[#out + 1] = {key = e.key or e.value, path = e.value}
          end
        end
      end
    end
    return out
  end

  -- the declared pieces, in the host's order
  function H.Items()
    if H.items == nil then
      H.items = HostItems(H.HOST)
    end
    return H.items
  end

  -- the declared band colours, in the host's order
  function H.BandItems()
    if H.bandItems == nil then
      H.bandItems = HostItems(H.BAND_HOST)
    end
    return H.bandItems
  end

  -- the declared rarity title rules, in the host's order
  function H.RarityItems()
    if H.rarityItems == nil then
      H.rarityItems = HostItems(H.RARITY_HOST)
    end
    return H.rarityItems
  end

  -- a global function by its path "A.B.C"
  local function Resolve(path)
    local v = _ENV
    for part in string.gmatch(path, "[^%.]+") do
      if type(v) ~= "table" then
        return nil
      end
      v = rawget(v, part)
    end
    return type(v) == "function" and v or nil
  end

  -- the card's rarity (the retail GetCharaStatusRarity when the VM has it)
  local function CardRarity(hdl)
    local f = rawget(_ENV, "GetCharaStatusRarity")
    if type(f) == "function" then
      local ok, r = pcall(f, hdl)
      if ok and type(r) == "number" then
        return r
      end
    end
    local ok, r = pcall(funcLuaCommand, H.CHARA, hdl, 12)
    return ok and type(r) == "number" and r or nil
  end

  -- the retail rarity look on a band (a soccer11_04 status plate copy filled with hdl)
  function H.RarityBand(layer, inst, hdl)
    local crc = rawget(_ENV, "CRC32")
    local rarity = type(hdl) == "number" and hdl ~= 0 and CardRarity(hdl) or nil
    if type(crc) ~= "function" or rarity == nil or rarity < 0 then
      return false
    end
    local number = rarity == 8 and 10 or rarity + 1
    local sprite = crc(string.format("status_chr_base01_s%02u", number))
    return (pcall(funcLuaMenuCommand, H.SWAP_SPRITE, layer, H.STATUS_TEXTURE, sprite, H.STATUS_BAND_SLOT, 0, inst or 0))
  end

  -- the band's colour: the first declared band colour that paints it, else the retail rarity look
  function H.BandColour(layer, inst, hdl)
    for _, it in ipairs(H.BandItems()) do
      local f = Resolve(it.path)
      if f ~= nil then
        local ok, painted = pcall(f, layer, inst or 0, hdl)
        if ok and painted then
          return true
        end
      end
    end
    return H.RarityBand(layer, inst, hdl)
  end

  -- whether the header shows the card's rarity title: false when a declared rule says no
  function H.ShowsRarity(hdl)
    for _, it in ipairs(H.RarityItems()) do
      local f = Resolve(it.path)
      if f ~= nil then
        local ok, shows = pcall(f, hdl)
        if ok and shows == false then
          return false
        end
      end
    end
    return true
  end

  local function TitleOff(layer, inst)
    pcall(funcLuaMenuCommand, H.MESH_VISIBLE, layer, H.RARITY_MESH, false, inst)
    pcall(funcLuaMenuCommand, H.NODE_VISIBLE, layer, H.RARITY_NODE, false, inst)
  end

  -- the rarity title of a header plate after its fill: off (and remembered, kept off every frame) or the retail one
  -- (the retail fill has just shown the banner mesh; its node back on)
  local function RarityTitle(layer, inst, hdl)
    local key = tostring(layer) .. ":" .. tostring(inst)
    if H.ShowsRarity(hdl) then
      H.rarityOff[key] = nil
      pcall(funcLuaMenuCommand, H.NODE_VISIBLE, layer, H.RARITY_NODE, true, inst)
      return
    end
    H.rarityOff[key] = {layer, inst}
    TitleOff(layer, inst)
  end

  -- a header plate instance set up / (re)opened: its title off until its first fill decides
  function H.Opened(layer, inst)
    if not H.LAYERS[layer] then
      return
    end
    inst = inst or 0
    H.rarityOff[tostring(layer) .. ":" .. tostring(inst)] = {layer, inst}
    TitleOff(layer, inst)
  end

  -- one refresh of a plate (layer, instance, chara status handle)
  function H.Fill(layer, inst, hdl)
    if not H.LAYERS[layer] then
      return
    end
    RarityTitle(layer, inst or 0, hdl)
    local x = H.SLOT.x
    for _, it in ipairs(H.Items()) do
      local f = Resolve(it.path)
      if f ~= nil then
        local c = H.ctx[it.key] or {}
        H.ctx[it.key] = c
        c.key, c.layer, c.inst, c.hdl = it.key, layer, inst or 0, hdl
        c.x, c.top, c.height, c.room = x, H.SLOT.top, H.SLOT.height, H.SLOT.x_end - x
        local ok, w = pcall(f, "fill", c)
        if ok and type(w) == "number" and w > 0 then
          x = x + w + H.GAP
        end
      end
    end
  end

  function H.Step()
    for _, plate in pairs(H.rarityOff) do
      TitleOff(plate[1], plate[2])
    end
    if H.items == nil then
      return
    end
    for _, it in ipairs(H.items) do
      local c = H.ctx[it.key]
      if c ~= nil then
        local f = Resolve(it.path)
        if f ~= nil then
          pcall(f, "step", c)
        end
      end
    end
  end

  H.prevPlate = UpdateCharaStatusPlateInfoByCharaStHdl
  function UpdateCharaStatusPlateInfoByCharaStHdl(a1, a2, a3, ...)
    local r = Pack(H.prevPlate(a1, a2, a3, ...))
    pcall(H.Fill, a1 or 0, a2 or 0, a3)
    return table.unpack(r, 1, r.n)
  end
  -- a header plate's set-up / open: the title off BEFORE the screen's handler (which may fill the plate at once).
  -- The script's own functions wrapped here, and the same entry as VR-Framework host handlers (a merged file that
  -- redefines them after lua\_all keeps the host's dispatcher)
  for _, point in ipairs({"OnSetupLayer", "OnOpenLayer"}) do
    local original = rawget(_ENV, point)
    if type(original) == "function" then
      _ENV[point] = function(layer, inst, ...)
        pcall(H.Opened, layer, inst)
        return original(layer, inst, ...)
      end
    end
  end
  local host = rawget(_ENV, "VRFW_Host")
  local patch = rawget(_ENV, "EVT_PATCH")
  local script = type(patch) == "table" and patch.script or nil
  local stem = type(script) == "string" and script:gsub("_%d+%.%d+%.%d+[%.%d]*$", "") or nil
  if type(stem) == "string" and type(host) == "table" and type(host.on) == "function" then
    for _, point in ipairs({"OnSetupLayer", "OnOpenLayer"}) do
      pcall(host.on, stem, point, {id = "character_reforged.header_title_" .. point, phase = "before",
        fn = function(layer, inst)
          pcall(H.Opened, layer, inst)
        end})
    end
  end

  -- the frame hook: the screen's PostStep and / or Step; a VM with neither gets a PostStep
  local hasStep = type(rawget(_ENV, "Step")) == "function"
  H.prevPostStep = rawget(_ENV, "PostStep") or false
  if type(H.prevPostStep) == "function" or not hasStep then
    function PostStep(...)
      local r = {n = 0}
      if type(H.prevPostStep) == "function" then
        r = Pack(H.prevPostStep(...))
      end
      pcall(H.Step)
      return table.unpack(r, 1, r.n)
    end
  end
  if hasStep then
    H.prevStep = Step
    function Step(...)
      local r = Pack(H.prevStep(...))
      pcall(H.Step)
      return table.unpack(r, 1, r.n)
    end
  end
end
