-- VRFW › team synergies declared by mods: the rows of a synergy detail panel (rows
-- team16_03_synergy_chara_condition_list), shared by every menu that shows one: the synergy list
-- (equip_synergy_menu_list/300_synergy.lua) and the shop (shop_menu_buy/310_synergy_shop.lua). This file defines the
-- functions only (VRFW_Synergy.ApplyPanel / Tick / Built / HideExtras); each menu's file calls them from its own events. The engine
-- draws the declared rows itself (the framework's hook on its row builder: the nexus, the members that fill the slots, a
-- pool character for an empty slot); after the game's code VRFW_Synergy.ApplyPanel, for a declared synergy only:
--   * the nexus row: drawn as any member row (the game's face of the nexus, his name, the retail check box), only the
--     row line orange; a missing nexus (team known): his face grey and translucent, and for a several-person nexus the
--     minifaces of the other allowed nexus characters right after it (layer vrfw_syn_face); without that layer:
--     «(missing)». (the orange status square and the orange plate of the one-person nexus showed
--     as broken placeholders, an orange square and an orange square in a pink hexagon; both removed, as is the NEXUS
--     sprite on the face mesh)
--   * an empty slot: no face, no plate, no series icons, no label; the crests of the pool's teams in a row on the right
--     (layer vrfw_syn_crest: the plain emblem, none of the tile's plates / frames, at the size of the row's series
--     icons); a pool that names no team (or no crest layer): the slot's hint text on the grey plate;
--   * a synergy declared with `slot_members`: every slot row drawn as the nexus row: its pool's team crest in the big
--     square (layer vrfw_syn_crest), the filler's name when filled, else the pool's members' minifaces after the crest;
--   * a filled row: the filler's name only (no «+N»); with team crests: the crests at the right end, the row's series
--     icons redrawn just left of them (layer vrfw_syn_icon);
--   * an empty staff slot (a pool with a role, no team): the role's icon in the face square, the required series' icons
--     right-aligned (layer vrfw_syn_icon: CMND_VRFW_ROLE_ICON / CMND_VRFW_SERIES_ICON drawn with the sprite command), the
--     role's short name in grey;
--   * a present nexus of a several-person declaration: his face and name at the left, the other persons' faces at the far right;
--   * an inactive synergy: the other rows' names grey, the title and effect texts at half alpha.
-- Every row is put back to the game's look first (tints, alpha, meshes), also for an undeclared synergy: the rows are
-- reused by every synergy's panel; the extra layers' instances are hidden. The extra pieces are placed from the rows'
-- own screen positions (CMND_GET_MESH_GLOBAL_POSITION) and placed again each frame while shown (open animations).
-- An extra instance's look (which tile / row meshes it hides) is set again once it is built (OnOpenLayer).
-- The crest tile's node is shown FIRST, then its plates hidden: CMND_SET_NODE_VISIBLE sets the flag on every mesh under
-- the node (the retail SetupEmblemIcon hides _pos_enjoy_list01, the parent of the emblem quad, then shows the quad and
-- the outline one by one). Showing _pos_enjoy_list01 after the hides re-showed every plate under it: the red / pink
-- team-colour hexagons and the cyan cursor outline around each crest (twice).
-- No engine call at load time; every call guarded.

VRFW_Synergy = VRFW_Synergy or {}
local S = VRFW_Synergy
if S.ApplyPanel ~= nil then return end     -- defined once per menu VM
S.CMD_PANEL = S.CMD_PANEL or VRFW_Cmd.VRFW_SYNERGY_PANEL
local CMD_TEXT_GET = VRFW_Cmd.TEXT_GET
local CMD_LANGUAGE = VRFW_Cmd.GET_LANGUAGE_CODE
local CMD_ITEM_OF_INV = 2662166687         -- (inventory handle, 0) -> the item id (the retail script's own call)
local SET_TEXT = VRFW_Cmd.SET_MENU_TEXT_STRING                -- (layer, node, text, instance)
local SET_TEXT_ALPHA = VRFW_Cmd.SET_MENU_TEXT_ALPHA          -- (layer, instance, node, alpha)
local SET_MESH_VISIBLE = VRFW_Cmd.SET_MESH_VISIBLE        -- (layer, mesh, visible, instance)
local PRIM_COLOR = VRFW_Cmd.SET_PRIM_COLOR               -- (layer, instance, mesh, r, g, b) (multiplier 0..1)
local PRIM_ALPHA = VRFW_Cmd.SET_PRIM_ALPHA              -- (layer, instance, mesh, alpha)
local C = {
  IS_EXIST_LAYER = VRFW_Cmd.IS_EXIST_LAYER,              -- (layer) -> true when the menu has it
  OPEN_LAYER = VRFW_Cmd.OPEN_LAYER,                  -- (layer, instance)
  LAYER_VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE,               -- (layer, instance, visible)
  LOCAL_POS = VRFW_Cmd.SET_LAYER_LOCAL_POS,                  -- (layer, x, y, z, instance): screen px from the top left, y up
  LOCAL_SCALE = VRFW_Cmd.SET_LAYER_LOCAL_SCALE,                -- (layer, sx, sy, sz, instance)
  NODE_VISIBLE = 2158717427,               -- (layer, node, visible, instance)
  TEXT_VISIBLE = VRFW_Cmd.SET_MENU_TEXT_VISIBLE,               -- (layer, text node, visible, instance)
  GPOS = VRFW_Cmd.GET_MESH_GLOBAL_POSITION,                        -- CMND_GET_MESH_GLOBAL_POSITION (layer, instance, mesh) -> x, y, z
  EMBLEM = 3190452549,                     -- (layer, instance, mesh, texture slot, item_emblem id, 0)
  LOADING = 1277042906,                    -- (layer, instance) -> true while its icon is loading
  RESET_FACE = 4176779611,                 -- (layer, instance, texture slot)
}

local DETAIL = 1473585342                  -- team16_02_synergy_item_detail (the shop: its own detail layer, S.detail)
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
local TXT_ROLE = { manager = 172090118, coach = 3665956829 }   -- VRFW.SynergyRoleManager / VRFW.SynergyRoleCoach
local CMD_SERIES_ICON = VRFW_Cmd.VRFW_SERIES_ICON          -- (series) -> ok, sheet, sprite
local CMD_ROLE_ICON = VRFW_Cmd.VRFW_ROLE_ICON           -- (role) -> ok, sheet, sprite
local SPRITE = 558735651                   -- sprite command (layer, sheet, sprite, texture node, 0, instance) -> true once applied
local GREY_ALPHA = 0.5
local ORANGE = { 1.0, 0.55, 0.12 }         -- the nexus row's tint (the name: [CMODE03] = 247 107 0)
local GHOST = { 0.62, 0.62, 0.62 }         -- a missing nexus's face / an empty slot's plate: grey ...
local GHOST_ALPHA = 0.45                   -- ... and translucent
local WHITE = { 1, 1, 1 }
local KIND_NEXUS, KIND_NEXUS_MISSING, KIND_FILLED, KIND_EMPTY = 1, 2, 3, 4

-- the extra layers (content\menus\synergy_panel.toml) and the row geometry they are placed by (team16_03, row-local
-- units, y up: check box centred on the origin, the face plate 64 at x 31..95, the series icons x 592..764)
local L_CREST, N_CREST = 527765702, 18     -- vrfw_syn_crest (vrfw_emblem_tile)
local L_FACE, N_FACE = 734603085, 30       -- vrfw_syn_face (team16_03 itself): 30 minifaces
local L_ICON, N_ICON = 1263105521, 24      -- vrfw_syn_icon (team16_03 itself): one series / role icon per instance
local L_ROW, N_CELLS = 3982581158, 4        -- vrfw_syn_row (team16_03 itself): a whole row, the cells of a 4-slot synergy's 2 x 2 grid
local GRID_SCALE, GRID_PITCH, GRID_COLS = 1.0, 1.0, 0.5   -- a cell's scale (as a normal row), the cell rows' distance (as the rows' own) and a column's share of the row width
local ROW_WIDTH = 800                      -- a row's width in its own units (check box to the series icons' end)
local LOG_CMD = VRFW_Cmd.EVT_LOG                 -- CMND log (loader.log lines «lua log: …»)
local ROW_RIGHT = 764                      -- the right edge of the series icons: the extras end there
local ANCHOR_A, ANCHOR_AX, ANCHOR_AY = 4051829508, -16, 16   -- _icon_check_box01 at (-16, 16)
local ANCHOR_B, ANCHOR_BX, ANCHOR_BY = 3231997250, 706, 14   -- _icon_series_dmy01 at (706, 14)
local CREST_PX, CREST_STEP = 52, 56        -- crest size / pitch, row units: the series icons' size, 4 apart
local SERIES_LEFT = 592                    -- the left edge of the series icons' three slots
local SERIES_CREST_PX, SERIES_CREST_STEP, SERIES_CREST_GAP = 40, 42, 8   -- crests beside the series icons: size, pitch, gap
local BIG_CREST_PX = 60                    -- a slot_members row's crest, in the big square (the face plate x 31..95)
local EMBLEM_PX = 84                       -- the tile's emblem quad
local TILE_MESH, TILE_SLOT = 1926542734, 618311715   -- _enjoy_list_icon_dmy01 / enjoy_list_icon_dmy01
-- every plate / frame / cursor / check part of the retail tile (the emblem grid hides the same: 58_emblem_grid.lua): only
-- the emblem quad stays, so a crest is the plain picture. Before, only three were hidden: the team-colour hexagon
-- frames (p1 / p2 plates) and their add / ok quads showed as frames with white rectangles around the crest.
local TILE_HIDE = { 2668225226, 1751802610, 3159751709, 155260060, 688408036, 2291119251, 1323396684, 294053161,
                    2968134629, 100709232, 1763834249 }
-- the plates' nodes (under _pos_enjoy_list01: _p1 / _p2 hold the two team-colour hexagon sets) and the player tags
local TILE_HIDE_NODES = { 3808539401, 2047402675, 1061671357, 2790162439 }   -- _pos_enjoy_list01_p1 / _p2, _pos_1p01 / 02
local TILE_NODE = 3933090681               -- _pos_enjoy_list01 (parent of the plates, the outline and the emblem quad)
local FACE_SCALE, FACE_STEP = 0.6, 44      -- a candidate's plate (64) and face at 0.6, pitch in row units
local FACE_X0, FACE_X1 = 31, 95            -- the plate's x extent in the row object
local LOAD_FRAMES = 120                    -- an icon still loading after this is shown anyway
-- an icon instance shows only its first series quad (_icon_series_dmy01: top left 706, 14, 58 x 38 in the row object;
-- the series quads' pitch 57) with the asked sprite on its texture node icon_series_dmy01
local ICON_MESH, ICON_SLOT = 3231997250, 201452450
local ICON_W, ICON_PITCH = 58, 57
local ICON_CX, ICON_CY = 706 + 58 / 2, 14 - 38 / 2   -- the quad's centre in the row object
local SERIES_ROW_Y = ICON_CY               -- the row's own series icons' centre line
local ROLE_SCALE = 1.25                    -- the role icon in the face square (plate 64 x 64 at x 31..95, centre y 0)
local MAX_STRIP = 6                        -- series icons of one row (room between the name and the row's end)
local CREST_GAP = 8                        -- between a filled row's series icons and its crests
local MEMBER_FACES = 8                     -- an empty slot_members row: its team's minifaces, right-aligned

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
  for _, n in ipairs(DETAIL_TEXTS) do pcall(funcLuaMenuCommand, SET_TEXT_ALPHA, S.detail or DETAIL, 0, n, a) end
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

-- instance k's look: on a crest only the emblem quad (every plate / frame / cursor / check of the tile hidden), on a
-- miniface only its plate (tinted) and face. Sent when shown and again once the instance is built (lost before)
local function dress(layer, k)
  local w = ex(layer).want[k]
  if not w then return end
  if layer == L_ICON then
    for _, m in ipairs({ CHECK_BOX, CHECK, LINE, FACE_BASE, FACE, SERIES[2], SERIES[3] }) do M(SET_MESH_VISIBLE, layer, m, false, k) end
    M(C.TEXT_VISIBLE, layer, TEXT_NAME, false, k)
    tint(layer, k, ICON_MESH, WHITE)
    M(PRIM_ALPHA, layer, k, ICON_MESH, 1)
    M(SET_MESH_VISIBLE, layer, ICON_MESH, w.done == true, k)
  elseif layer == L_ROW then
    -- a whole row: every part shown in the game's look (the row's branch below tints / hides what it needs)
    for _, m in ipairs({ CHECK_BOX, LINE, FACE_BASE, FACE }) do M(SET_MESH_VISIBLE, layer, m, true, k) end
    for _, m in ipairs(SERIES) do M(SET_MESH_VISIBLE, layer, m, false, k) end
    M(SET_MESH_VISIBLE, layer, CHECK, false, k)
    for _, m in ipairs({ FACE, FACE_BASE, LINE }) do tint(layer, k, m, WHITE) end
    M(PRIM_ALPHA, layer, k, FACE, 1)
    M(PRIM_ALPHA, layer, k, FACE_BASE, 1)
    M(C.TEXT_VISIBLE, layer, TEXT_NAME, true, k)
  elseif layer == L_CREST then
    -- order matters: a node's visibility is set on every mesh under it, so the parent first, the hides after
    M(C.NODE_VISIBLE, layer, TILE_NODE, true, k)
    for _, n in ipairs(TILE_HIDE_NODES) do M(C.NODE_VISIBLE, layer, n, false, k) end
    for _, m in ipairs(TILE_HIDE) do M(SET_MESH_VISIBLE, layer, m, false, k) end
    -- the emblem quad (shown again by the parent node above): only once its emblem is asked for and loaded
    M(SET_MESH_VISIBLE, layer, TILE_MESH, w.asked == true and ex(layer).wait[k] == nil, k)
  else
    tint(layer, k, FACE, w.grey and GHOST or WHITE)
    M(PRIM_ALPHA, layer, k, FACE, w.grey and GHOST_ALPHA or 1)
    for _, m in ipairs({ CHECK_BOX, CHECK, LINE, SERIES[1], SERIES[2], SERIES[3] }) do M(SET_MESH_VISIBLE, layer, m, false, k) end
    M(C.TEXT_VISIBLE, layer, TEXT_NAME, false, k)
    M(SET_MESH_VISIBLE, layer, FACE_BASE, w.plate ~= false, k)
    if w.plate ~= false then tint(layer, k, FACE_BASE, w.plate or ORANGE) end
  end
end

-- the icon of instance k: asked for once the instance is built; hidden until it has loaded (when Step runs)
local function ask(layer, k)
  local e = ex(layer)
  local w = e.want[k]
  if not w or not e.built[k] or w.asked then return end
  if layer == L_ICON then
    -- the sprite command answers false (and draws nothing) while the sheet or the instance's model is not ready: asked
    -- again each frame from Tick, at most LOAD_FRAMES times, the quad hidden until it answers true
    w.done = M(SPRITE, layer, w.sheet, w.sprite, ICON_SLOT, 0, k) == true
    w.tries = (w.tries or 0) + 1
    w.asked = w.done or w.tries >= LOAD_FRAMES
    M(SET_MESH_VISIBLE, layer, ICON_MESH, w.done, k)
    return
  end
  w.asked = true
  if layer == L_CREST then
    M(C.EMBLEM, layer, k, TILE_MESH, TILE_SLOT, w.id, 0)
    M(SET_MESH_VISIBLE, layer, TILE_MESH, not S.stepped, k)
  else
    VRFW_FaceIcon.Request(layer, k, w.id, FACE, FACE_SLOT)
    M(SET_MESH_VISIBLE, layer, FACE, not S.stepped, k)
  end
  if S.stepped then e.wait[k] = LOAD_FRAMES end
end

-- instance k of `layer` shows icon `id` at row `row` (row-local centre lx, size px), or nothing (id nil); a miniface's
-- plate is tinted `plate` (default orange: a nexus's; false = no plate)
local function show(layer, k, id, row, lx, px, plate, grey)
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
  if not w or w.id ~= id then
    w = { id = id }
    e.want[k] = w
  end
  w.row, w.lx, w.px, w.plate, w.grey = row, lx, px, plate, grey
  M(C.LAYER_VISIBLE, layer, k, true)
  dress(layer, k)
  ask(layer, k)
end

-- icon instance k shows sprite (sheet, sprite) centred on row `row`'s (lx, ly) at `scale` x the row's own series icon
-- (sheet nil: nothing)
local function show_icon(k, sheet, sprite, row, lx, ly, scale)
  local e = ex(L_ICON)
  if not sheet then
    if e.opened[k] then M(C.LAYER_VISIBLE, L_ICON, k, false) end
    e.want[k] = nil
    return
  end
  if not e.opened[k] then
    M(C.OPEN_LAYER, L_ICON, k)
    e.opened[k] = true
  end
  local w = e.want[k]
  if not w or w.sheet ~= sheet or w.sprite ~= sprite then
    w = { sheet = sheet, sprite = sprite }
    e.want[k] = w
  end
  w.row, w.lx, w.ly, w.k = row, lx, ly, scale
  M(C.LAYER_VISIBLE, L_ICON, k, true)
  dress(L_ICON, k)
  ask(L_ICON, k)
end

-- a series' / role's icon: sheet, sprite (nil when the framework has none)
local function icon_of(cmd, v)
  local ok, has, sheet, sprite = pcall(funcLuaCommand, cmd, v)
  if ok and has == true and type(sheet) == "number" and type(sprite) == "number" then return sheet, sprite end
  return nil
end

-- the series icons `list` (series numbers, at most MAX_STRIP: the last ones) in a row, the last one's right edge at row
-- x `right`; returns the next free icon instance
local function series_strip(ii, inst, list, right)
  local n = math.min(#list, MAX_STRIP)
  for j = 1, n do
    local sheet, sprite = icon_of(CMD_SERIES_ICON, list[#list - n + j])
    if sheet and ii < N_ICON then
      show_icon(ii, sheet, sprite, inst, right - ICON_W / 2 - (n - j) * ICON_PITCH, SERIES_ROW_Y, 1)
      ii = ii + 1
    end
  end
  return ii
end

-- every shown instance at its row's current place
local function place_all()
  local frames = {}
  for _, layer in ipairs({ L_ROW, L_CREST, L_FACE, L_ICON }) do
    local e = ex(layer)
    for k, w in pairs(e.want) do
      local f = frames[w.row]
      if f == nil then
        local cf = S.cell_frames and S.cell_frames[w.row]
        if cf then
          f = cf
        else
          local ox, oy, s = row_frame(w.row)
          f = ox and { ox, oy, s } or false
        end
        frames[w.row] = f
      end
      if f then
        local ox, oy, s = f[1], f[2], f[3]
        if layer == L_ROW then
          -- a grid cell: the row object itself at the cell's origin and scale
          M(C.LOCAL_SCALE, layer, s, s, 1, k)
          M(C.LOCAL_POS, layer, ox, oy, 0, k)
        elseif layer == L_ICON then
          -- the instance's origin so that its series quad is centred on (lx, ly)
          local sc = w.k * s
          M(C.LOCAL_SCALE, layer, sc, sc, 1, k)
          M(C.LOCAL_POS, layer, ox + w.lx * s - ICON_CX * sc, oy + w.ly * s - ICON_CY * sc, 0, k)
        elseif layer == L_CREST then
          local sc = w.px / EMBLEM_PX * s
          M(C.LOCAL_SCALE, layer, sc, sc, 1, k)
          M(C.LOCAL_POS, layer, ox + w.lx * s, oy, 0, k)      -- the tile's origin = its centre
        else
          local sc = FACE_SCALE * s
          -- the row object's origin so that its plate is centred on lx, y 0
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
  for _, layer in ipairs({ L_ROW, L_CREST, L_FACE, L_ICON }) do
    local e = ex(layer)
    for k in pairs(e.opened) do M(C.LAYER_VISIBLE, layer, k, false) end
    e.want, e.wait = {}, {}
  end
  S.held = {}
  S.extras = nil
end

-- ------------------------------------------------------------------------------------------------ the rows

-- a row's face or its plate off: hidden and fully transparent. The face picture the game asked for loads after the panel
-- is drawn and the engine shows the mesh again once it has loaded (a player's face behind a crest, a face on an empty
-- slot, the game's rows under a 2 x 2 grid); a face that is not cached yet (the shop) came back opaque. So each hidden
-- part is kept in S.held until its row's picture has loaded (C.LOADING false after it was true, or LOAD_FRAMES frames):
-- Tick hides it again at that moment, the same wait the crests' emblems use. reset_row makes both opaque again
S.held = S.held or {}
local function hide_part(inst, mesh, layer)
  layer = layer or ROW
  pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, layer, mesh, false, inst)
  pcall(funcLuaMenuCommand, PRIM_ALPHA, layer, inst, mesh, 0)
  local key = layer .. ":" .. inst
  local h = S.held[key]
  if not h then
    h = { layer = layer, inst = inst, meshes = {}, left = LOAD_FRAMES, seen = false }
    S.held[key] = h
  end
  h.meshes[mesh] = true
  S.extras = true
end

-- the parts kept hidden: hidden again while the row's picture loads and once it has loaded, then released
local function hold_hidden()
  for key, h in pairs(S.held) do
    local loading = M(C.LOADING, h.layer, h.inst) == true
    if loading then h.seen = true end
    for mesh in pairs(h.meshes) do
      M(SET_MESH_VISIBLE, h.layer, mesh, false, h.inst)
      M(PRIM_ALPHA, h.layer, h.inst, mesh, 0)
    end
    h.left = h.left - 1
    if (h.seen and not loading) or h.left <= 0 then S.held[key] = nil end
  end
end

-- a row back to the game's look (it may have been a nexus / empty row of another synergy's panel)
local function reset_row(inst)
  S.held[ROW .. ":" .. inst] = nil
  pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE, true, inst)
  pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE_BASE, true, inst)
  pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, CHECK_BOX, true, inst)
  pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, LINE, true, inst)
  M(C.TEXT_VISIBLE, ROW, TEXT_NAME, true, inst)
  if S.sprite_rows and S.sprite_rows[inst] then
    M(C.RESET_FACE, ROW, inst, FACE_SLOT)      -- an older version's nexus icon off the face mesh
    S.sprite_rows[inst] = nil
  end
  -- the series icons are left to the game: its row draw (just before this patch runs) shows a character's series and
  -- hides the unused slots (a row is reused by characters of 1-3 series). Forcing all three on here showed the unused
  -- slot as a white quad left of the saga icons on member rows
  tint(ROW, inst, FACE, WHITE)
  tint(ROW, inst, FACE_BASE, WHITE)
  tint(ROW, inst, LINE, WHITE)
  pcall(funcLuaMenuCommand, PRIM_ALPHA, ROW, inst, FACE, 1)
  pcall(funcLuaMenuCommand, PRIM_ALPHA, ROW, inst, FACE_BASE, 1)
end

local function reset_all()
  S.held = {}
  if S.touched then
    for inst = 0, N_ROWS - 1 do reset_row(inst) end
    S.touched = nil
    detail_alpha(1)
  end
  if S.extras then hide_extras() end
end

-- grid cells (a synergy with exactly 4 slot rows): the origin and scale of each cell (S.cell_frames[100 + i]) from the native
-- rows' own frames: columns half a row apart, the second cell row a fraction of the rows' distance below the first. Each
-- cell's final place is written once to loader.log
local function grid_frames()
  local ax, ay, as = row_frame(0)
  local bx, by = row_frame(1)
  if not ax or not bx then return false end
  local sc = as * GRID_SCALE
  local dx = ROW_WIDTH * GRID_COLS * as
  local dy = (by - ay) * GRID_PITCH
  S.cell_frames = {}
  for i = 1, N_CELLS do
    local col, rw = (i - 1) % 2, math.floor((i - 1) / 2)
    S.cell_frames[100 + i] = { ax + col * dx, ay + rw * dy, sc }
    if not (S.grid_logged and S.grid_logged[i]) then
      S.grid_logged = S.grid_logged or {}
      S.grid_logged[i] = true
      pcall(funcLuaCommand, LOG_CMD, "VRFW synergy grid cell", i, "at", ax + col * dx, ay + rw * dy, "scale", sc)
    end
  end
  return true
end

-- cell k of the grid: the row clone shown (its face drawn for chara `id`), its frame id 100 + k + 1
local function open_cell(k, id)
  local e = ex(L_ROW)
  if not e.opened[k] then
    M(C.OPEN_LAYER, L_ROW, k)
    e.opened[k] = true
  end
  local w = e.want[k]
  if not w or w.id ~= id then
    w = { id = id }
    e.want[k] = w
  end
  w.row = 100 + k + 1
  M(C.LAYER_VISIBLE, L_ROW, k, true)
  dress(L_ROW, k)
  if id and id ~= 0 then ask(L_ROW, k) else M(SET_MESH_VISIBLE, L_ROW, FACE, false, k) end
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
  local crest_ok, face_ok, icon_ok = has_layer(L_CREST), has_layer(L_FACE), has_layer(L_ICON)
  local ci, fi, ii = 0, 0, 0
  -- exactly 4 slot rows: a 2 x 2 grid of row clones in place of the game's 3 rows (when the row layer exists)
  local grid = #p.rows == N_CELLS and has_layer(L_ROW) and grid_frames()
  local ROWR = grid and (ROW_WIDTH * GRID_COLS - 24) or ROW_RIGHT      -- the right edge of a row / grid cell, row units
  if grid then
    -- the game's 3 rows off under the grid cells; their faces and plates kept off once their pictures load
    for i = 0, N_ROWS - 1 do
      hide_part(i, FACE)
      hide_part(i, FACE_BASE)
      for _, m in ipairs({ CHECK_BOX, CHECK, LINE, SERIES[1], SERIES[2], SERIES[3] }) do
        pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, m, false, i)
      end
      pcall(funcLuaMenuCommand, SET_TEXT, ROW, TEXT_NAME, "", i)
    end
    S.extras = true
  end
  for r, row in ipairs(p.rows) do
    if not grid and r > N_ROWS then break end
    local RL, inst, fr = ROW, r - 1, r - 1        -- the row layer, its instance, the frame the extras are placed by
    if grid then
      RL, fr = L_ROW, 100 + r
      open_cell(inst, tonumber(row.base) or 0)
    end
    local name = type(row.name) == "string" and row.name or ""
    local s
    local big = crest_ok and tonumber(row.crest) or 0
    if big ~= 0 and (row.kind == KIND_EMPTY or row.kind == KIND_FILLED) then
      -- slot_members: the pool's team crest in the big square (as the nexus icon); filled: the filler's name (the
      -- row's check is the game's); empty: the pool's members' minifaces right after the crest, no text
      hide_part(inst, FACE, RL)
      hide_part(inst, FACE_BASE, RL)
      if ci < N_CREST then
        show(L_CREST, ci, big, fr, (FACE_X0 + FACE_X1) / 2, BIG_CREST_PX)
        ci = ci + 1
      end
      S.extras = true
      if row.kind == KIND_FILLED then
        s = active and name or ("[CGRAYOUT]" .. name .. "[C]")
      else
        -- empty: the team's name in grey after the crest, its players' minifaces right-aligned at the row's end (at
        -- most MEMBER_FACES, so the name keeps its room)
        for _, m in ipairs(SERIES) do pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, RL, m, false, inst) end
        local tn = type(row.team_name) == "string" and row.team_name or ""
        s = tn ~= "" and ("[CGRAYOUT]" .. tn .. "[C]") or ""
        local ids = face_ok and split_ids(row.faces) or {}
        local n = math.min(#ids, MEMBER_FACES)
        for j = 1, n do
          if fi < N_FACE then
            local lx = ROWR - (FACE_X1 - FACE_X0) * FACE_SCALE / 2 - (n - j) * FACE_STEP
            show(L_FACE, fi, ids[j], fr, lx, 0, WHITE)
            fi = fi + 1
          end
        end
      end
    elseif row.kind == KIND_EMPTY and face_ok and type(row.have) == "string" and row.have ~= "" and row.faces ~= "" then
      -- an empty row of a person pool, drawn as the nexus row: the first candidate's big face (grey, as nobody fills it yet)
      -- with its name, the other candidates as minifaces at the right end (in colour when already in the team, else grey)
      for _, m in ipairs(SERIES) do pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, RL, m, false, inst) end
      local have = {}
      for v in row.have:gmatch("[^,]+") do have[#have + 1] = (v == "1") end
      local ids = split_ids(row.faces)
      -- nobody fills the slot (the first candidate is not in the team): the empty slot, as retail draws an unfilled row (no face,
      -- plate or name); every candidate is then a miniface at the right
      local vacant = not have[1]
      if vacant then
        hide_part(inst, FACE, RL)
        hide_part(inst, FACE_BASE, RL)
        s = ""
      else
        tint(RL, inst, FACE_BASE, GHOST)
        pcall(funcLuaMenuCommand, PRIM_ALPHA, RL, inst, FACE_BASE, GHOST_ALPHA)
        s = name
      end
      -- a pool that also names a team: the team's crests at the far right, the minifaces left of them
      local crests = crest_ok and split_ids(row.crests) or {}
      local right = ROWR
      for j, id in ipairs(crests) do
        if ci < N_CREST then
          local lx = ROWR - CREST_PX / 2 - (#crests - j) * CREST_STEP
          show(L_CREST, ci, id, fr, lx, CREST_PX)
          ci = ci + 1
        end
      end
      if #crests > 0 then right = ROWR - #crests * CREST_STEP - 6 end
      for j = vacant and 1 or 2, #ids do
        if fi < N_FACE then
          local lx = right - (FACE_X1 - FACE_X0) * FACE_SCALE / 2 - (#ids - j) * FACE_STEP
          show(L_FACE, fi, ids[j], fr, lx, 0, WHITE, have[j] ~= true)
          fi = fi + 1
        end
      end
      S.extras = true
    elseif row.kind == KIND_EMPTY then
      hide_part(inst, FACE, RL)
      for _, m in ipairs(SERIES) do pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, RL, m, false, inst) end
      local crests = crest_ok and split_ids(row.crests) or {}
      local role = type(row.role) == "string" and row.role or ""
      local rsheet, rsprite = nil, nil
      if role ~= "" and icon_ok and #crests == 0 then rsheet, rsprite = icon_of(CMD_ROLE_ICON, role) end
      if rsheet then
        -- a staff slot: the role's icon in place of the grey square, the required series' icons right-aligned, the
        -- role's short name
        hide_part(inst, FACE_BASE, RL)
        if ii < N_ICON then
          show_icon(ii, rsheet, rsprite, fr, (FACE_X0 + FACE_X1) / 2, 0, ROLE_SCALE)
          ii = ii + 1
        end
        ii = series_strip(ii, fr, split_ids(row.series), ROWR)
        local label = TXT_ROLE[role] and text(TXT_ROLE[role]) or ""
        s = label ~= "" and ("[CGRAYOUT]" .. label .. "[C]") or ""
        S.extras = true
      elseif #crests > 0 then
        -- no plate: the slot's hint in grey (the pool's, else the synergy's; «{team}» = the pool's team) and the
        -- allowed teams' crests right-aligned on the series icons' place
        hide_part(inst, FACE_BASE, RL)
        local tn = type(row.team_name) == "string" and row.team_name or ""
        local h = string.gsub(text(row.hint), "{team}", function() return tn end)
        s = h ~= "" and ("[CGRAYOUT]" .. h .. "[C]") or ""
        for j, id in ipairs(crests) do
          if ci < N_CREST then
            local lx = ROWR - CREST_PX / 2 - (#crests - j) * CREST_STEP
            show(L_CREST, ci, id, fr, lx, CREST_PX)
            ci = ci + 1
          end
        end
        S.extras = true
      else
        tint(RL, inst, FACE_BASE, GHOST)
        pcall(funcLuaMenuCommand, PRIM_ALPHA, RL, inst, FACE_BASE, GHOST_ALPHA)
        -- the hint's «{team}»: the slot's team name (a declaration with one pool per slot)
        local tn = type(row.team_name) == "string" and row.team_name or ""
        local h = string.gsub(text(row.hint), "{team}", function() return tn end)
        s = "[CGRAYOUT]" .. h .. "[C]"
      end
    elseif row.kind == KIND_NEXUS or row.kind == KIND_NEXUS_MISSING then
      -- the game's own row (the nexus's face, the retail check box), only the line orange; no extra pieces on it
      tint(RL, inst, LINE, ORANGE)
      tint(RL, inst, FACE_BASE, ORANGE)
      s = active and name or ("[CGRAYOUT]" .. name .. "[C]")
      if row.kind == KIND_NEXUS and face_ok then
        -- a present nexus of a several-person declaration: his face and name stay at the left, the other allowed persons'
        -- faces go to the far right of the card
        local shown = tonumber(row.base) or 0
        local others = {}
        for _, id in ipairs(split_ids(row.faces)) do
          if id ~= shown then others[#others + 1] = id end
        end
        if #others > 0 then
          for _, m in ipairs(SERIES) do pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, RL, m, false, inst) end
          for j, id in ipairs(others) do
            if fi < N_FACE then
              local lx = ROWR - (FACE_X1 - FACE_X0) * FACE_SCALE / 2 - (#others - j) * FACE_STEP
              show(L_FACE, fi, id, fr, lx, 0)
              fi = fi + 1
            end
          end
          S.extras = true
        end
      end
      if row.kind == KIND_NEXUS_MISSING and has_team then
        -- missing: his face grey and translucent; several persons: the others right after it, no text
        tint(RL, inst, FACE, GHOST)
        pcall(funcLuaMenuCommand, PRIM_ALPHA, RL, inst, FACE, GHOST_ALPHA)
        local shown = tonumber(row.base) or 0
        local others = {}
        if face_ok then
          for _, id in ipairs(split_ids(row.faces)) do
            if id ~= shown then others[#others + 1] = id end
          end
        end
        if #others > 0 then
          for _, m in ipairs(SERIES) do pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, RL, m, false, inst) end
          s = ""
          for j, id in ipairs(others) do
            if fi < N_FACE then
              local lx = FACE_X1 + 10 + (FACE_X1 - FACE_X0) * FACE_SCALE / 2 + (j - 1) * FACE_STEP
              show(L_FACE, fi, id, fr, lx, 0)
              fi = fi + 1
            end
          end
          S.extras = true
        elseif not (row.single == 1 or row.single == true) then
          s = s .. "  [CGRAYOUT](" .. text(TXT_MISSING) .. ")[C]"
        end
      end
    else
      s = active and name or ("[CGRAYOUT]" .. name .. "[C]")
      if row.kind == KIND_FILLED then
        -- the series' team crests right-aligned at the row's end, the row's series icons redrawn just left of them
        -- (vrfw_syn_icon; the game's own quads sit at the row's end); without the icon layer or the row's series: the
        -- game's icons stay and the crests sit left of them
        local crests = crest_ok and split_ids(row.crests) or {}
        local own = icon_ok and split_ids(row.series) or {}
        if #crests > 0 and #own > 0 then
          for _, m in ipairs(SERIES) do pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, RL, m, false, inst) end
          for j, id in ipairs(crests) do
            if ci < N_CREST then
              local lx = ROWR - SERIES_CREST_PX / 2 - (#crests - j) * SERIES_CREST_STEP
              show(L_CREST, ci, id, fr, lx, SERIES_CREST_PX)
              ci = ci + 1
            end
          end
          local left = ROWR - SERIES_CREST_PX - (#crests - 1) * SERIES_CREST_STEP
          ii = series_strip(ii, fr, own, left - CREST_GAP)
          S.extras = true
        elseif #crests > 0 then
          for j, id in ipairs(crests) do
            if ci < N_CREST then
              local lx = SERIES_LEFT - SERIES_CREST_GAP - SERIES_CREST_PX / 2 - (#crests - j) * SERIES_CREST_STEP
              show(L_CREST, ci, id, fr, lx, SERIES_CREST_PX)
              ci = ci + 1
            end
          end
          S.extras = true
        end
      end
    end
    if name ~= "" or row.kind == KIND_EMPTY or row.kind == KIND_NEXUS_MISSING then
      pcall(funcLuaMenuCommand, SET_TEXT, RL, TEXT_NAME, s, inst)
    end
    if grid then
      -- the check mark of a satisfied row (the game's row builder draws it on its own rows)
      pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, L_ROW, CHECK, row.kind == KIND_FILLED or (row.kind == KIND_NEXUS and has_team), inst)
    end
  end
  -- the instances this panel does not use
  for k = ci, N_CREST - 1 do show(L_CREST, k, nil) end
  for k = fi, N_FACE - 1 do show(L_FACE, k, nil) end
  for k = ii, N_ICON - 1 do show_icon(k, nil) end
  if not grid then
    for k = 0, N_CELLS - 1 do show(L_ROW, k, nil) end
    S.cell_frames = nil
  end
  if S.extras then place_all() end
  detail_alpha(active and 1 or GREY_ALPHA)
end

-- per frame while extras show: placed again (the panel's open animation moves the rows), loaded icons shown
function S.Tick()
  S.stepped = true
  if not S.extras then return end
  place_all()
  hold_hidden()
  -- icons whose sprite was not applied yet: asked again
  for k, w in pairs(ex(L_ICON).want) do
    if not w.asked then ask(L_ICON, k) end
  end
  for _, layer in ipairs({ L_CREST, L_FACE, L_ROW }) do
    local e = ex(layer)
    local mesh = layer == L_CREST and TILE_MESH or FACE
    for k, left in pairs(e.wait) do
      if M(C.LOADING, layer, k) ~= true or left <= 0 then
        e.wait[k] = nil
        if layer == L_CREST then dress(layer, k) end      -- the plates hidden again with the loaded emblem shown
        M(SET_MESH_VISIBLE, layer, mesh, true, k)
      else
        e.wait[k] = left - 1
      end
    end
  end
end

-- an extra layer's instance is built: its icon can be asked for now
function S.Built(layer, inst)
  if (layer == L_CREST or layer == L_FACE or layer == L_ICON or layer == L_ROW) and type(inst) == "number" then
    ex(layer).built[inst] = true
    dress(layer, inst)
    ask(layer, inst)
  end
end

-- every extra piece (crests, minifaces, icons) off, the rows left as drawn: a page of the panel without the condition
-- rows (the shop's effects page) or a detail that is not a synergy. The next ApplyPanel shows them again
function S.HideExtras()
  hide_extras()
end

-- the rows' layer and check parts, for the menus' own files
S.ROW, S.CHECK, S.CHECK_BOX = ROW, CHECK, CHECK_BOX
