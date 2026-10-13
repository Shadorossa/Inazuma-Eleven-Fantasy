-- VRFW › team synergies declared by mods (docs/framework/synergy.md §5, §10): the synergy list's detail panel
-- (team16_02_synergy_item_detail, rows team16_03_synergy_chara_condition_list). The engine draws the declared rows
-- itself (the framework's hook on its row builder: the nexus, the members that fill the slots, a pool character for
-- an empty slot); after the game's code this patch, for a declared synergy only:
--   * the nexus row of a one-person nexus: his face in the big square on an orange plate (a vrfw_syn_crest instance
--     with the flat sprite vrfw_syn_box under a vrfw_syn_face miniface at full size), the status square orange;
--   * the nexus row of a several-person nexus: the NEXUS icon in the big square (the row's face mesh with the sprite vrfw_syn_nexus), the small
--     status square orange (an instance of vrfw_syn_face drawing the flat sprite vrfw_syn_box: CMND_SET_PRIM_COLOR does
--     not tint these quads), no tag text; the nexus in the team: his name; a missing nexus (team known): the minifaces
--     of every allowed nexus character right after the icon (layer vrfw_syn_face); without that layer: «(missing)»;
--   * an empty slot: no face, no plate, no series icons, no label; the crests of the pool's teams in a row on the right
--     (layer vrfw_syn_crest: the plain emblem, none of the tile's plates / frames); a pool that names no team (or no
--     crest layer): the slot's hint text on the grey plate;
--   * a synergy declared with `slot_members`: every slot row drawn as the nexus row: its pool's team crest in the big
--     square (layer vrfw_syn_crest), the filler's name when filled, else the pool's members' minifaces after the crest;
--   * the last filled row: «+N» when more pool players are in the team than the slots (rule "min");
--   * an inactive synergy: the other rows' names grey, the title and effect texts at half alpha.
-- Every row is put back to the game's look first (tints, alpha, meshes), also for an undeclared synergy: the rows are
-- reused by every synergy's panel; the extra layers' instances are hidden. The extra pieces are placed from the rows'
-- own screen positions (CMND_GET_MESH_GLOBAL_POSITION) and placed again each frame while shown (open animations).
-- No engine call at load time; every call guarded.

VRFW_Synergy = VRFW_Synergy or {}
local S = VRFW_Synergy
S.CMD_PANEL = S.CMD_PANEL or 737795469     -- CMND_VRFW_SYNERGY_PANEL
local CMD_TEXT_GET = 4074371074            -- CMND_TEXT_GET
local CMD_LANGUAGE = 477234096             -- CMND_GET_LANGUAGE_CODE
local CMD_ITEM_OF_INV = 2662166687         -- (inventory handle, 0) -> the item id (the retail script's own call)
local SET_TEXT = 1083631230                -- CMND_SET_MENU_TEXT_STRING (layer, node, text, instance)
local SET_TEXT_ALPHA = 1126837159          -- CMND_SET_MENU_TEXT_ALPHA (layer, instance, node, alpha)
local SET_MESH_VISIBLE = 3405944500        -- CMND_SET_MESH_VISIBLE (layer, mesh, visible, instance)
local PRIM_COLOR = 855211291               -- CMND_SET_PRIM_COLOR (layer, instance, mesh, r, g, b) (multiplier 0..1)
local PRIM_ALPHA = 2219773080              -- CMND_SET_PRIM_ALPHA (layer, instance, mesh, alpha)
local C = {
  IS_EXIST_LAYER = 262659071,              -- (layer) -> true when the menu has it
  OPEN_LAYER = 629267548,                  -- (layer, instance)
  LAYER_VISIBLE = 711242136,               -- (layer, instance, visible)
  LOCAL_POS = 1389957207,                  -- (layer, x, y, z, instance): screen px from the top left, y up
  LOCAL_SCALE = 3778714801,                -- (layer, sx, sy, sz, instance)
  NODE_VISIBLE = 2158717427,               -- (layer, node, visible, instance)
  TEXT_VISIBLE = 1505208242,               -- (layer, text node, visible, instance)
  GPOS = 499270986,                        -- CMND_GET_MESH_GLOBAL_POSITION (layer, instance, mesh) -> x, y, z
  EMBLEM = 3190452549,                     -- (layer, instance, mesh, texture slot, item_emblem id, 0)
  LOADING = 1277042906,                    -- (layer, instance) -> true while its icon is loading
  FACE = 552280324,                        -- (layer, instance, false, mesh, texture slot, 0, 0, chara_base)
  RESET_FACE = 4176779611,                 -- (layer, instance, texture slot)
}

local DETAIL = 1473585342                  -- team16_02_synergy_item_detail
local ROW = 4041512772                     -- team16_03_synergy_chara_condition_list
local N_ROWS = 3                           -- the panel's largest layout
local TEXT_NAME = 1704438437               -- _text_name01 (row name; the detail's title)
local FACE = 478320441                     -- _icon_chr_dmy01 (the face icon's mesh)
local FACE_SLOT = 3237726902               -- icon_chr_dmy01 (its texture slot)
local FACE_BASE = 1042467758               -- _chr_base01 (the plate behind the face)
local LINE = 2519428701                    -- _chr_line01 (the row's line)
local CHECK_BOX = 4051829508               -- _icon_check_box01
local CHECK = 2309656400                   -- _icon_check01
local SERIES = { 3231997250, 1504513272, 782908526 }   -- _icon_series_dmy01..03
local DETAIL_TEXTS = { 1704438437, 852552077, 2883172407, 3705571489 }   -- _text_name01, _text_win01..03
local TXT_MISSING = 787277494              -- VRFW.SynergyNexusMissing
local TXT_MORE = 446965088                 -- VRFW.SynergyMore («+{n}»)
local LOAD_TEX = 839427544               -- CMND_LOAD_MENU_RES_TEXTURE (path)
local TEX_LOADING = 1506186496             -- (texture crc) -> true while still loading
local SPRITE = 558735651                   -- (layer, texture crc, sprite crc, texture slot crc, 0, instance)
local ART_PATH = "#/menu/220_img/vrfw_syn/vrfw_syn.g4tx"
local ART = 2748818662                     -- crc32(ART_PATH)
local SPR_NEXUS = 4142643543               -- crc32("vrfw_syn_nexus"): 64 x 64, the nexus icon
local SPR_BOX = 1643701063                 -- crc32("vrfw_syn_box"): 32 x 32, the orange status square
local GREY_ALPHA = 0.5
local ORANGE = { 1.0, 0.55, 0.12 }         -- the nexus row's tint (the name: [CMODE03] = 247 107 0)
local GHOST = { 0.62, 0.62, 0.62 }         -- a missing nexus's face / an empty slot's plate: grey ...
local GHOST_ALPHA = 0.45                   -- ... and translucent
local WHITE = { 1, 1, 1 }
local KIND_NEXUS, KIND_NEXUS_MISSING, KIND_FILLED, KIND_EMPTY = 1, 2, 3, 4

-- the extra layers (content\menus\synergy_panel.toml) and the row geometry they are placed by (team16_03, row-local
-- units, y up: check box centred on the origin, the face plate 64 at x 31..95, the series icons x 592..764)
local L_CREST, N_CREST = 527765702, 18     -- vrfw_syn_crest (vrfw_emblem_tile)
local L_FACE, N_FACE = 734603085, 33       -- vrfw_syn_face (team16_03 itself): 30 minifaces + 3 orange boxes
local K_BOX0 = 30                          -- the instances from here draw the orange status squares (one a nexus row)
local BOX_PX = 32                          -- the status square's size, row units, centred on the row origin
local FACE_PX = 64                         -- the row's face mesh (_icon_chr_dmy01), row units
local ROW_RIGHT = 764                      -- the right edge of the series icons: the extras end there
local ANCHOR_A, ANCHOR_AX, ANCHOR_AY = 4051829508, -16, 16   -- _icon_check_box01 at (-16, 16)
local ANCHOR_B, ANCHOR_BX, ANCHOR_BY = 3231997250, 706, 14   -- _icon_series_dmy01 at (706, 14)
local CREST_PX, CREST_STEP = 44, 50        -- crest size / pitch, row units
local BIG_CREST_PX = 60                    -- a slot_members row's crest, in the big square (the face plate x 31..95)
local EMBLEM_PX = 84                       -- the tile's emblem quad
local TILE_MESH, TILE_SLOT = 1926542734, 618311715   -- _enjoy_list_icon_dmy01 / enjoy_list_icon_dmy01
-- every plate / frame / cursor / check part of the retail tile (the emblem grid hides the same: 58_emblem_grid.lua): only
-- the emblem quad stays, so a crest is the plain picture. Before, only three were hidden: the team-colour hexagon
-- frames (p1 / p2 plates) and their add / ok quads showed as frames with white rectangles around the crest.
local TILE_HIDE = { 2668225226, 1751802610, 3159751709, 155260060, 688408036, 2291119251, 1323396684, 294053161,
                    2968134629, 100709232, 1763834249 }
local TILE_HIDE_NODES = { 1061671357, 2790162439, 2047402675 }   -- _pos_1p01, _pos_1p02, _pos_enjoy_list01_p2
local TILE_NODE = 3933090681                                     -- _pos_enjoy_list01 (the emblem's node)
local FACE_SCALE, FACE_STEP = 0.6, 44      -- a candidate's plate (64) and face at 0.6, pitch in row units
local FACE_X0, FACE_X1 = 31, 95            -- the plate's x extent in the row object
local LOAD_FRAMES = 120                    -- an icon still loading after this is shown anyway

local function text(id)
  local ok, s = pcall(funcLuaCommand, CMD_TEXT_GET, id)
  if ok and type(s) == "string" then return s end
  return ""
end

local function M(cmd, ...)
  local ok, a, b, c = pcall(funcLuaMenuCommand, cmd, ...)
  if ok then return a, b, c end
  return nil
end

local function detail_alpha(a)
  for _, n in ipairs(DETAIL_TEXTS) do pcall(funcLuaMenuCommand, SET_TEXT_ALPHA, DETAIL, 0, n, a) end
end

local function tint(layer, inst, mesh, c)
  pcall(funcLuaMenuCommand, PRIM_COLOR, layer, inst, mesh, c[1], c[2], c[3])
end

local function split_ids(s)
  local out = {}
  if type(s) ~= "string" then return out end
  for v in s:gmatch("[^,]+") do
    local n = tonumber(v)
    if n and n ~= 0 then out[#out + 1] = n end
  end
  return out
end

-- ------------------------------------------------------------------------------------------------ the extra layers

-- per layer: opened instances, what each shows, built (OnOpenLayer seen), still loading (frames left)
S.ex = S.ex or {}
local function ex(layer)
  local e = S.ex[layer]
  if not e then
    e = { opened = {}, want = {}, built = {}, wait = {} }
    S.ex[layer] = e
  end
  return e
end

local function has_layer(layer)
  local ok, r = pcall(funcLuaMenuCommand, C.IS_EXIST_LAYER, layer)
  return ok and r == true
end

-- the row's frame on screen: origin and scale (two of its meshes' global positions)
local function row_frame(inst)
  local ax, ay = M(C.GPOS, ROW, inst, ANCHOR_A)
  local bx, by = M(C.GPOS, ROW, inst, ANCHOR_B)
  if type(ax) ~= "number" or type(ay) ~= "number" or type(bx) ~= "number" or type(by) ~= "number" then return nil end
  local s = (bx - ax) / (ANCHOR_BX - ANCHOR_AX)
  if s <= 0.05 or s > 20 then s = 1 end
  return ax - ANCHOR_AX * s, ay - ANCHOR_AY * s, s
end

-- the icon of instance k: asked for once the instance is built; hidden until it has loaded (when Step runs)
local art_loaded
local function ask(layer, k)
  local e = ex(layer)
  local w = e.want[k]
  if not w or not e.built[k] or w.asked then return end
  if w.spr then
    -- a flat sprite of the framework's atlas (loaded with the menu: synergy_panel.toml `res`): bound only once the
    -- texture answers «loaded», hidden until then (Tick asks again), so an untextured white quad never shows
    local mesh = layer == L_CREST and TILE_MESH or FACE
    if not art_loaded() then
      M(SET_MESH_VISIBLE, layer, mesh, false, k)
      return
    end
    w.asked = true
    M(SPRITE, layer, ART, w.spr, layer == L_CREST and TILE_SLOT or FACE_SLOT, 0, k)
    M(SET_MESH_VISIBLE, layer, mesh, true, k)
    return
  end
  w.asked = true
  if layer == L_CREST then
    M(C.EMBLEM, layer, k, TILE_MESH, TILE_SLOT, w.id, 0)
    M(SET_MESH_VISIBLE, layer, TILE_MESH, not S.stepped, k)
  else
    M(C.RESET_FACE, layer, k, FACE_SLOT)
    pcall(SetDisableForceCharaInvalidUseTarget)
    M(C.FACE, layer, k, false, FACE, FACE_SLOT, 0, 0, w.id)
    pcall(SetEnableForceCharaInvalidUseTarget)
    M(SET_MESH_VISIBLE, layer, FACE, not S.stepped, k)
  end
  if S.stepped and not w.spr then e.wait[k] = LOAD_FRAMES end
end

-- instance k of `layer` shows icon `id` at row `row` (row-local centre lx, size px), or nothing (id nil); a miniface's
-- plate is tinted `plate` (default orange: a nexus's; false = no plate); `scale`: a miniface's size (default FACE_SCALE)
local function show(layer, k, id, row, lx, px, spr, plate, scale)
  local e = ex(layer)
  if not id then
    if e.opened[k] then M(C.LAYER_VISIBLE, layer, k, false) end
    e.want[k] = nil
    e.wait[k] = nil
    return
  end
  if not e.opened[k] then
    M(C.OPEN_LAYER, layer, k)
    e.opened[k] = true
  end
  local w = e.want[k]
  if not w or w.id ~= id or w.spr ~= spr then
    w = { id = id, spr = spr }
    e.want[k] = w
  end
  w.row, w.lx, w.px, w.scale = row, lx, px, scale
  M(C.LAYER_VISIBLE, layer, k, true)
  if layer == L_CREST then
    for _, m in ipairs(TILE_HIDE) do M(SET_MESH_VISIBLE, layer, m, false, k) end
    for _, n in ipairs(TILE_HIDE_NODES) do M(C.NODE_VISIBLE, layer, n, false, k) end
    M(C.NODE_VISIBLE, layer, TILE_NODE, true, k)
  else
    if not spr then
      -- a reused instance: back to a plain face (a missing one-person nexus greys it after this)
      tint(layer, k, FACE, WHITE)
      M(PRIM_ALPHA, layer, k, FACE, 1)
    end
    for _, m in ipairs({ CHECK_BOX, CHECK, LINE, SERIES[1], SERIES[2], SERIES[3] }) do M(SET_MESH_VISIBLE, layer, m, false, k) end
    M(C.TEXT_VISIBLE, layer, TEXT_NAME, false, k)
    M(SET_MESH_VISIBLE, layer, FACE_BASE, not spr and plate ~= false, k)   -- a miniface keeps its plate; the status square has none
    if not spr and plate ~= false then tint(layer, k, FACE_BASE, plate or ORANGE) end
  end
  ask(layer, k)
end

-- every shown instance at its row's current place
local function place_all()
  local frames = {}
  for _, layer in ipairs({ L_CREST, L_FACE }) do
    local e = ex(layer)
    for k, w in pairs(e.want) do
      local f = frames[w.row]
      if f == nil then
        local ox, oy, s = row_frame(w.row)
        f = ox and { ox, oy, s } or false
        frames[w.row] = f
      end
      if f then
        local ox, oy, s = f[1], f[2], f[3]
        if layer == L_CREST then
          local sc = w.px / EMBLEM_PX * s
          M(C.LOCAL_SCALE, layer, sc, sc, 1, k)
          M(C.LOCAL_POS, layer, ox + w.lx * s, oy, 0, k)      -- the tile's origin = its centre
        else
          local sc = (w.spr and BOX_PX / FACE_PX or w.scale or FACE_SCALE) * s
          -- the row object's origin so that its plate (the status square: its face mesh) is centred on lx, y 0
          M(C.LOCAL_SCALE, layer, sc, sc, 1, k)
          M(C.LOCAL_POS, layer, ox + w.lx * s - (FACE_X0 + FACE_X1) / 2 * sc, oy, 0, k)
        end
      else
        M(C.LAYER_VISIBLE, layer, k, false)
      end
    end
  end
end

local function hide_extras()
  for _, layer in ipairs({ L_CREST, L_FACE }) do
    local e = ex(layer)
    for k in pairs(e.opened) do M(C.LAYER_VISIBLE, layer, k, false) end
    e.want, e.wait = {}, {}
  end
  S.extras = nil
end

-- ------------------------------------------------------------------------------------------------ the rows

-- a row back to the game's look (it may have been a nexus / empty row of another synergy's panel)
local function reset_row(inst)
  pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE, true, inst)
  pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE_BASE, true, inst)
  pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, CHECK_BOX, true, inst)
  if S.sprite_rows and S.sprite_rows[inst] then
    M(C.RESET_FACE, ROW, inst, FACE_SLOT)      -- the nexus icon off the face mesh
    S.sprite_rows[inst] = nil
  end
  -- the series icons are left to the game: its row draw (just before this patch runs) shows a character's series and
  -- hides the unused slots (a row is reused by characters of 1-3 series). Forcing all three on here showed the unused
  -- slot as a white quad left of the saga icons on member rows (in-game 2026-10-13)
  tint(ROW, inst, FACE, WHITE)
  tint(ROW, inst, FACE_BASE, WHITE)
  tint(ROW, inst, LINE, WHITE)
  pcall(funcLuaMenuCommand, PRIM_ALPHA, ROW, inst, FACE, 1)
  pcall(funcLuaMenuCommand, PRIM_ALPHA, ROW, inst, FACE_BASE, 1)
end

local function reset_all()
  if S.touched then
    for inst = 0, N_ROWS - 1 do reset_row(inst) end
    S.touched = nil
    detail_alpha(1)
  end
  if S.extras then hide_extras() end
end

-- the nexus icon / status square atlas: asked for once; sprites are bound when it has loaded
function S.art_ready()
  if not has_layer(L_FACE) then return false end
  if not S.art_asked then
    S.art_asked = true
    pcall(funcLuaCommand, LOAD_TEX, ART_PATH)
  end
  return true
end

-- the atlas is in the menu's texture cache: only an explicit «not loading» answer counts (2026-10-13: the atlas was
-- never requested, the command answered no «loading» and the sprites were bound to a missing texture: white quads)
art_loaded = function()
  if not S.art_asked then return false end
  local ok, loading = pcall(funcLuaCommand, TEX_LOADING, ART)
  return ok and loading == false
end

-- the nexus icon on the face mesh of every nexus row of this panel, once the atlas has loaded (else Tick retries)
function S.apply_icons()
  if not S.pending or next(S.pending) == nil then return end
  if not art_loaded() then
    -- hidden meanwhile, so the previous face never shows under the icon
    for inst in pairs(S.pending) do pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE, false, inst) end
    return
  end
  for inst in pairs(S.pending) do
    M(SPRITE, ROW, ART, SPR_NEXUS, FACE_SLOT, 0, inst)
    pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE, true, inst)
  end
  S.pending = {}
end

-- the rows of the declared synergy `item` just drawn (nothing but the reset for any other synergy)
function S.ApplyPanel(item)
  reset_all()
  if type(item) ~= "number" or item == 0 then return end
  local okc, code = pcall(funcLuaCommand, CMD_LANGUAGE)
  local ok, p = pcall(funcLuaCommand, S.CMD_PANEL, item, okc and code or -1)
  if not ok or type(p) ~= "table" or type(p.rows) ~= "table" then return end
  S.touched = true
  local active = p.active == 1 or p.active == true
  local has_team = p.team == 1 or p.team == true
  local extra = tonumber(p.extra) or 0
  local crest_ok, face_ok = has_layer(L_CREST), has_layer(L_FACE)
  local last_filled = 0
  for r, row in ipairs(p.rows) do
    if row.kind == KIND_FILLED or row.kind == KIND_NEXUS then last_filled = r end
  end
  local ci, fi, bi = 0, 0, 0
  local art_ok = S.art_ready()
  S.pending = {}
  for r, row in ipairs(p.rows) do
    local inst = r - 1
    local name = type(row.name) == "string" and row.name or ""
    local s
    local big = crest_ok and tonumber(row.crest) or 0
    if big ~= 0 and (row.kind == KIND_EMPTY or row.kind == KIND_FILLED) then
      -- slot_members: the pool's team crest in the big square (as the nexus icon); filled: the filler's name (the
      -- row's check is the game's); empty: the pool's members' minifaces right after the crest, no text
      pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE, false, inst)
      pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE_BASE, false, inst)
      if ci < N_CREST then
        show(L_CREST, ci, big, inst, (FACE_X0 + FACE_X1) / 2, BIG_CREST_PX)
        ci = ci + 1
      end
      S.extras = true
      if row.kind == KIND_FILLED then
        s = active and name or ("[CGRAYOUT]" .. name .. "[C]")
        if r == last_filled and extra > 0 then
          s = s .. "  [CGRAYOUT]" .. string.gsub(text(TXT_MORE), "{n}", tostring(math.floor(extra))) .. "[C]"
        end
      else
        for _, m in ipairs(SERIES) do pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, m, false, inst) end
        s = ""
        for j, id in ipairs(face_ok and split_ids(row.faces) or {}) do
          if fi < K_BOX0 then
            local lx = FACE_X1 + 10 + (FACE_X1 - FACE_X0) * FACE_SCALE / 2 + (j - 1) * FACE_STEP
            show(L_FACE, fi, id, inst, lx, 0, nil, WHITE)
            fi = fi + 1
          end
        end
      end
    elseif row.kind == KIND_EMPTY then
      pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE, false, inst)
      for _, m in ipairs(SERIES) do pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, m, false, inst) end
      local crests = crest_ok and split_ids(row.crests) or {}
      if #crests > 0 then
        -- no label, no plate: only the allowed teams' crests, right-aligned on the series icons' place
        pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE_BASE, false, inst)
        s = ""
        for j, id in ipairs(crests) do
          if ci < N_CREST then
            local lx = ROW_RIGHT - CREST_PX / 2 - (#crests - j) * CREST_STEP
            show(L_CREST, ci, id, inst, lx, CREST_PX)
            ci = ci + 1
          end
        end
        S.extras = true
      else
        tint(ROW, inst, FACE_BASE, GHOST)
        pcall(funcLuaMenuCommand, PRIM_ALPHA, ROW, inst, FACE_BASE, GHOST_ALPHA)
        -- the hint's «{team}»: the slot's team name (a declaration with one pool per slot)
        local tn = type(row.team_name) == "string" and row.team_name or ""
        local h = string.gsub(text(row.hint), "{team}", function() return tn end)
        s = "[CGRAYOUT]" .. h .. "[C]"
      end
    elseif row.kind == KIND_NEXUS or row.kind == KIND_NEXUS_MISSING then
      tint(ROW, inst, LINE, ORANGE)
      s = active and name or ("[CGRAYOUT]" .. name .. "[C]")
      local faces = {}
      if row.kind == KIND_NEXUS_MISSING and has_team and face_ok then faces = split_ids(row.faces) end
      local one = tonumber(row.base) or 0
      if not (row.single == 1 or row.single == true) then one = 0 end
      if one ~= 0 and art_ok and crest_ok and ci < N_CREST and fi < K_BOX0 then
        -- a one-person nexus: his face is the icon, on an orange plate (the flat sprite on a crest instance, the face
        -- on a full-size miniface instance above it: the face layer is added after the crest layer); the row's own
        -- face and white plate hidden; missing (team known): the face grey and translucent, the name grey
        pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE, false, inst)
        pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE_BASE, false, inst)
        pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, CHECK_BOX, false, inst)
        local mid = (FACE_X0 + FACE_X1) / 2
        show(L_CREST, ci, 1, inst, mid, FACE_PX, SPR_BOX)
        ci = ci + 1
        show(L_FACE, fi, one, inst, mid, 0, nil, false, 1)
        if row.kind == KIND_NEXUS_MISSING and has_team then
          tint(L_FACE, fi, FACE, GHOST)
          M(PRIM_ALPHA, L_FACE, fi, FACE, GHOST_ALPHA)
        end
        fi = fi + 1
        if bi < N_FACE - K_BOX0 then
          show(L_FACE, K_BOX0 + bi, 1, inst, 0, BOX_PX, SPR_BOX)
          bi = bi + 1
        end
        S.extras = true
        faces = {}
      elseif art_ok then
        -- the nexus icon in the big square, the small status square orange (a flat sprite instance)
        pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE_BASE, false, inst)
        pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, CHECK_BOX, false, inst)
        S.sprite_rows = S.sprite_rows or {}
        S.sprite_rows[inst] = true
        S.pending[inst] = true
        if bi < N_FACE - K_BOX0 then
          show(L_FACE, K_BOX0 + bi, 1, inst, 0, BOX_PX, SPR_BOX)
          bi = bi + 1
          S.extras = true
        end
      else
        tint(ROW, inst, FACE_BASE, ORANGE)
      end
      if #faces > 0 then
        -- the allowed nexus characters' minifaces right after the icon (plate x 31..95)
        pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE, art_ok, inst)
        for _, m in ipairs(SERIES) do pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, m, false, inst) end
        s = ""
        for j, id in ipairs(faces) do
          if fi < K_BOX0 then
            local lx = FACE_X1 + 10 + (FACE_X1 - FACE_X0) * FACE_SCALE / 2 + (j - 1) * FACE_STEP
            show(L_FACE, fi, id, inst, lx, 0)
            fi = fi + 1
          end
        end
        S.extras = true
      elseif row.kind == KIND_NEXUS_MISSING and has_team and one == 0 then
        if not art_ok then
          tint(ROW, inst, FACE, GHOST)
          pcall(funcLuaMenuCommand, PRIM_ALPHA, ROW, inst, FACE, GHOST_ALPHA)
        end
        s = s .. "  [CGRAYOUT](" .. text(TXT_MISSING) .. ")[C]"
      end
    else
      s = active and name or ("[CGRAYOUT]" .. name .. "[C]")
      if r == last_filled and extra > 0 then
        s = s .. "  [CGRAYOUT]" .. string.gsub(text(TXT_MORE), "{n}", tostring(math.floor(extra))) .. "[C]"
      end
    end
    if name ~= "" or row.kind == KIND_EMPTY or row.kind == KIND_NEXUS_MISSING then
      pcall(funcLuaMenuCommand, SET_TEXT, ROW, TEXT_NAME, s, inst)
    end
  end
  -- the instances this panel does not use
  for k = ci, N_CREST - 1 do show(L_CREST, k, nil) end
  for k = fi, K_BOX0 - 1 do show(L_FACE, k, nil) end
  for k = K_BOX0 + bi, N_FACE - 1 do show(L_FACE, k, nil) end
  S.apply_icons()
  if S.extras then place_all() end
  detail_alpha(active and 1 or GREY_ALPHA)
end

-- per frame while extras show: placed again (the panel's open animation moves the rows), loaded icons shown
function S.Tick()
  S.stepped = true
  if S.pending and next(S.pending) ~= nil then pcall(S.apply_icons) end
  if not S.extras then return end
  for _, layer in ipairs({ L_CREST, L_FACE }) do
    local e = ex(layer)
    for k, w in pairs(e.want) do
      if w.spr and not w.asked then ask(layer, k) end
    end
  end
  place_all()
  for _, layer in ipairs({ L_CREST, L_FACE }) do
    local e = ex(layer)
    local mesh = layer == L_CREST and TILE_MESH or FACE
    for k, left in pairs(e.wait) do
      if M(C.LOADING, layer, k) ~= true or left <= 0 then
        M(SET_MESH_VISIBLE, layer, mesh, true, k)
        e.wait[k] = nil
      else
        e.wait[k] = left - 1
      end
    end
  end
end

-- an extra layer's instance is built: its icon can be asked for now
function S.Built(layer, inst)
  if (layer == L_CREST or layer == L_FACE) and type(inst) == "number" then
    ex(layer).built[inst] = true
    ask(layer, inst)
  end
end

local function item_of(inv)
  if type(inv) ~= "number" or inv == 0 then return 0 end
  local ok, it = pcall(funcLuaCommand, CMD_ITEM_OF_INV, inv, 0)
  if ok and type(it) == "number" then return it end
  return 0
end

S.list = S.list or {}
local W = S.list

-- UpdateItemEquipMenu(inv): the focused synergy's detail (the game draws it in the same call)
if type(UpdateItemEquipMenu) == "function" and UpdateItemEquipMenu ~= W.UpdateItemEquipMenu then
  local orig = UpdateItemEquipMenu
  W.UpdateItemEquipMenu = function(a1, ...)
    local r = orig(a1, ...)
    local ok, e = pcall(S.ApplyPanel, item_of(a1))
    if not ok and S.err == nil then S.err = tostring(e) end
    return r
  end
  UpdateItemEquipMenu = W.UpdateItemEquipMenu
end

-- OnOpenLayer: the extra layers' instances (the retail one runs first)
if OnOpenLayer ~= W.OnOpenLayer then
  local orig = OnOpenLayer
  W.OnOpenLayer = function(a1, a2, ...)
    local r
    if type(orig) == "function" then r = orig(a1, a2, ...) end
    pcall(S.Built, a1, a2)
    return r
  end
  OnOpenLayer = W.OnOpenLayer
end

-- Step (looked up by name each frame; the retail script has none of its own, an include's is kept)
if Step ~= W.Step then
  local orig = Step
  W.Step = function(...)
    local r
    if type(orig) == "function" then r = orig(...) end
    pcall(S.Tick)
    return r
  end
  Step = W.Step
end
