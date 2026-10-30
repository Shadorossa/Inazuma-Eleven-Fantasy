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
-- For other mods' menu Lua: CharacterReforged.Header.SLOT (the strip), .Items() (the declared pieces).
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
-- 2026-10-14 (owner video: «LEYENDA DEL FÚTBOL» for two frames when the focus goes from an Ídolo card to a normal one):
-- the title is drawn by the native request 2881088748 (layer, idx, mesh, slot, rarity[, show_when_loaded,
-- hide_on_redraw]) inside the retail fill. When the sprite changes (Ídolo _07 -> Leyenda _05) the native slot hides
-- the mesh at once and, once the new sprite has LOADED, shows the mesh itself (show_when_loaded, default true) a few
-- frames later, outside Lua: after this fill's hide and between two frame passes, so the title flashed until the next
-- frame pass. Call order now: our wrapper decides ShowsRarity(hdl) BEFORE the retail fill; for a card without title
-- the fill runs with funcLuaMenuCommand filtered (for its duration only) so that its title request on
-- _player_rarity01 goes out with show_when_loaded = false (the sprite still loads, nothing shows the mesh: retail's
-- own way to load a hidden banner, docs/game/ui/ui-redesign.md §4); then the fill's hide (mesh + node) and the frame
-- pass as before. A card with a title (Ídolo / Diamante, or every card without No More Rarities) sends the retail
-- request unchanged: its title shows once its sprite has loaded.
-- Title change between two cards with a title (Ídolo -> another Ídolo rarity, Ídolo <-> Diamante, a card without title
-- -> one with): the request resets the slot's texture node at once (the mesh falls back to its white fill texture) and
-- the new sprite is applied one or more frames later, after the icon component's «loading» flag (1277042906) has
-- already dropped; both the retail fill (SET_MESH_VISIBLE right after the request when «not loading») and the slot's
-- own show_when_loaded could show the mesh in that gap: a white rectangle for a frame or two. Such a fill now sends the
-- request with show_when_loaded = false and drops the retail «visible» call on the title mesh; the frame hook shows
-- the title once the plate has reported «not loading» for TITLE_SETTLE_STEPS consecutive passes (at most
-- TITLE_WAIT_LIMIT passes). A fill whose title sprite does not change sends the retail request unchanged (the slot
-- does not redraw, the title stays as it is).
-- The Diamond plate's wave effect (ega1450a_2, attached to the retail header object at the retail plate's centre,
-- made for the 196 px plate) is not part of the one-row header object (content\menus\player_header.toml
-- remove_block): it drew a big empty frame under the 64 px band. The band keeps the Diamond look (the rarity sprite,
-- the seasonal frame mesh fitted to the band with the basara sprites).
-- Wrappers only (UpdateCharaStatusPlateInfoByCharaStHdl, OnSetupLayer, OnOpenLayer, PostStep, Step; funcLuaMenuCommand
-- filtered only for the duration of a header plate fill); no engine call
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
  H.TITLE_REQUEST = 2881088748           -- the native rarity title request (layer, idx, mesh, slot, rarity, show
  --                                        when loaded, hide on redraw); it shows the mesh by itself once loaded
  H.SHOW_WHEN_LOADED_ARGUMENT = 6        -- its argument «show the mesh when the sprite has loaded» (default true)
  H.HIDE_ON_REDRAW_ARGUMENT = 7          -- its argument «hide the mesh while the new sprite loads» (default true)
  H.TITLE_RARITY_ARGUMENT = 5            -- its argument «rarity» (the sprite is rarity + 1)
  H.LOADING = 1277042906                 -- the plate instance's icon «loading» flag (layer, inst)
  H.TITLE_SETTLE_STEPS = 3               -- «not loading» passes in a row before a changed title is shown
  H.TITLE_WAIT_LIMIT = 90                -- frame-hook passes after which a changed title is shown anyway
  H.titleRarity = {}                     -- "layer:inst" -> the rarity of the last title request of that plate
  H.titlePending = {}                    -- "layer:inst" -> {layer, inst, steps, settled}: a changed title kept hidden

  local function Pack(...)
    return {n = select("#", ...), ...}
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
  local function RarityTitle(layer, inst, shows)
    local key = tostring(layer) .. ":" .. tostring(inst)
    if shows then
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
    local key = tostring(layer) .. ":" .. tostring(inst)
    H.rarityOff[key] = {layer, inst}
    H.titleRarity[key] = nil
    H.titlePending[key] = nil
    TitleOff(layer, inst)
  end

  -- the changed titles kept hidden: shown once their plate has stopped loading for a few passes in a row
  local function ShowSettledTitles()
    for key, plate in pairs(H.titlePending) do
      plate.steps = plate.steps + 1
      local okLoading, loading = pcall(funcLuaMenuCommand, H.LOADING, plate.layer, plate.inst)
      if okLoading and not loading then
        plate.settled = plate.settled + 1
      else
        plate.settled = 0
      end
      if plate.settled >= H.TITLE_SETTLE_STEPS or plate.steps >= H.TITLE_WAIT_LIMIT then
        H.titlePending[key] = nil
        pcall(funcLuaMenuCommand, H.NODE_VISIBLE, plate.layer, H.RARITY_NODE, true, plate.inst)
        pcall(funcLuaMenuCommand, H.MESH_VISIBLE, plate.layer, H.RARITY_MESH, true, plate.inst)
      end
    end
  end

  -- one refresh of a plate (layer, instance, chara status handle; shows = its title decision, nil = ask now)
  function H.Fill(layer, inst, hdl, shows)
    if not H.LAYERS[layer] then
      return
    end
    if shows == nil then
      shows = H.ShowsRarity(hdl)
    end
    RarityTitle(layer, inst or 0, shows)
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
    ShowSettledTitles()
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

  -- the menu command function for the duration of one header fill (layer, inst; shows = the card has a title):
  -- * the title request on the header title mesh: for a card without title, or a title whose sprite changes (or is
  --   unknown since the plate opened), it goes out with show_when_loaded = false (hide_on_redraw kept as given,
  --   default true); a changed title is then kept hidden until its sprite has been applied (frame hook);
  -- * «visible» on the title mesh while its changed title is kept hidden: dropped;
  -- every other call unchanged
  local function HeaderFillCommand(command, layer, inst, shows)
    local key = tostring(layer) .. ":" .. tostring(inst)
    return function(id, ...)
      if id == H.TITLE_REQUEST and select(3, ...) == H.RARITY_MESH then
        local args = Pack(...)
        local rarity = args[H.TITLE_RARITY_ARGUMENT]
        local changed = H.titleRarity[key] == nil or H.titleRarity[key] ~= rarity
        H.titleRarity[key] = rarity
        if not shows then
          H.titlePending[key] = nil
        elseif changed or H.titlePending[key] ~= nil then
          H.titlePending[key] = {layer = layer, inst = inst, steps = 0, settled = 0}
        else
          return command(id, ...)
        end
        if args.n < H.HIDE_ON_REDRAW_ARGUMENT then
          args.n = H.HIDE_ON_REDRAW_ARGUMENT
        end
        if args[H.HIDE_ON_REDRAW_ARGUMENT] == nil then
          args[H.HIDE_ON_REDRAW_ARGUMENT] = true
        end
        args[H.SHOW_WHEN_LOADED_ARGUMENT] = false
        return command(id, table.unpack(args, 1, args.n))
      end
      if id == H.MESH_VISIBLE and select(2, ...) == H.RARITY_MESH and select(3, ...) == true
          and H.titlePending[key] ~= nil then
        return nil
      end
      return command(id, ...)
    end
  end

  -- whether a fill of (layer, hdl) is a header plate showing a card with a title: nil = not a header plate
  local function HeaderTitleDecision(layer, hdl)
    if not H.LAYERS[layer] then
      return nil
    end
    return H.ShowsRarity(hdl)
  end

  H.prevPlate = UpdateCharaStatusPlateInfoByCharaStHdl
  function UpdateCharaStatusPlateInfoByCharaStHdl(a1, a2, a3, ...)
    local okDecision, shows = pcall(HeaderTitleDecision, a1 or 0, a3)
    if not okDecision then
      shows = nil
    end
    -- a header plate: the retail fill's title request and title «visible» call go through the header fill filter
    local command, filtered = nil, nil
    if shows ~= nil and type(rawget(_ENV, "funcLuaMenuCommand")) == "function" then
      command = funcLuaMenuCommand
      filtered = HeaderFillCommand(command, a1 or 0, a2 or 0, shows)
      funcLuaMenuCommand = filtered
    end
    local r = Pack(pcall(H.prevPlate, a1, a2, a3, ...))
    if filtered ~= nil and rawget(_ENV, "funcLuaMenuCommand") == filtered then
      funcLuaMenuCommand = command
    end
    if not r[1] then
      error(r[2], 0)
    end
    pcall(H.Fill, a1 or 0, a2 or 0, a3, shows)
    return table.unpack(r, 2, r.n)
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
