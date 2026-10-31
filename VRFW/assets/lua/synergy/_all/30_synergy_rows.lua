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
--   * the shop's panel (no team): one row per requirement. Slots of one pool are one row («N of these», the repeats
--     taken off as whole row instances); a slot of named players: the first one's face as the game draws it, the
--     others as minifaces, one player alone with his name; a team pool's slot: its first crest in the face square, the
--     hint, the other crests at the right; no check boxes, no grey texts, the title at full alpha.
-- Extra pieces (row clones, crests, minifaces, icons) stay hidden until their pictures have loaded, then the panel's
-- extras show together (at most REVEAL_FRAMES frames later: a piece whose state cannot be read shows anyway). The
-- game's rows are never hidden as whole instances (the engine then redraws the panel every frame); an empty slot's face
-- is hidden as a mesh and held hidden until its picture has loaded.
-- Every row is put back to the game's look first (tints, alpha, check box), also for an undeclared synergy: the rows
-- are reused by every synergy's panel; extras the new panel does not use are hidden. The extra pieces are placed from the rows'
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
local TXT_ANY_OF = 621365040               -- VRFW.SynergyAnyOf («{n} of these»: a slot any of several players fill)
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
local REVEAL_FRAMES = 30                   -- an extra piece not ready after this is shown anyway (never an empty panel)
-- the panel's own mesh the row places are measured from (_synergy_icon_base01: the title icon's base, in both the synergy
-- screen's detail and the shop's), and the command that tells the framework a layout's row places are known
local ANCHOR_MESH = 3541433305
local CMD_LAYOUT_KNOWN = VRFW_Cmd.VRFW_SYNERGY_LAYOUT_KNOWN
local MENU = 3086271496                    -- equip_synergy_menu: the row builder's menu id (crc32 of the menu name)
local IS_VISIBLE = VRFW_Cmd.IS_LAYER_VISIBLE             -- (layer, instance) -> true when shown
local CLONE_ROW = 200                      -- frame keys of a clone drawn in place of the game's row: 200 + its row index
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

-- per layer: opened instances, what each shows (want: the instance's content and look; used = in the panel drawn last),
-- built (OnOpenLayer seen), still loading (wait: frames left), shown (the instance's visibility as last set)
S.ex = S.ex or {}
local function ex(layer)
  local e = S.ex[layer]
  if not e then
    e = { opened = {}, want = {}, built = {}, wait = {}, shown = {} }
    S.ex[layer] = e
  end
  return e
end

local function has_layer(layer)
  local ok, r = pcall(funcLuaMenuCommand, C.IS_EXIST_LAYER, layer)
  return ok and r == true
end

-- an extra instance on or off (a call only when it changes)
local function set_shown(layer, k, on)
  local e = ex(layer)
  if e.shown[k] ~= on then
    M(C.LAYER_VISIBLE, layer, k, on)
    e.shown[k] = on
  end
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

-- a game row's face or plate off. The game's rows are never hidden as whole instances: the engine draws the panel again
-- when one of its row instances is hidden, every frame (the panel stayed empty and the synergy check ran 600 times a
-- second). A face hidden here comes back when its picture loads, so it is kept in S.held until the row's picture has
-- loaded (C.LOADING true, then false; at most LOAD_FRAMES frames) and hidden again by Tick. reset_row shows it again
S.held = S.held or {}
S.face_hidden = S.face_hidden or {}
S.row_frames = S.row_frames or {}
local function hide_part(inst, mesh, layer)
  layer = layer or ROW
  M(SET_MESH_VISIBLE, layer, mesh, false, inst)
  M(PRIM_ALPHA, layer, inst, mesh, 0)
  if layer == ROW and mesh == FACE then S.face_hidden[inst] = true end
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

-- a game row emptied (a shop slot that repeats the row above it, the game's rows under a 2 x 2 grid): every part off
local function strip_row(inst)
  hide_part(inst, FACE)
  hide_part(inst, FACE_BASE)
  for _, m in ipairs({ CHECK_BOX, CHECK, LINE, SERIES[1], SERIES[2], SERIES[3] }) do M(SET_MESH_VISIBLE, ROW, m, false, inst) end
  M(SET_TEXT, ROW, TEXT_NAME, "", inst)
end

-- instance k's look: on a crest only the emblem quad (every plate / frame / cursor / check of the tile hidden), on a
-- miniface only its plate (tinted) and face, on a row clone the look its row asks for (w.id face, w.plate, w.line,
-- w.box, w.check, w.text). Sent when the content is set, when the instance is built (lost before) and when it is shown
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
    -- a row clone: a face only when one was asked for (no request, no picture that loads and shows later)
    M(SET_MESH_VISIBLE, layer, LINE, true, k)
    M(SET_MESH_VISIBLE, layer, CHECK_BOX, w.box ~= false, k)
    M(SET_MESH_VISIBLE, layer, CHECK, w.check == true, k)
    for _, m in ipairs(SERIES) do M(SET_MESH_VISIBLE, layer, m, false, k) end
    M(SET_MESH_VISIBLE, layer, FACE, w.id ~= 0, k)
    M(SET_MESH_VISIBLE, layer, FACE_BASE, w.plate ~= false, k)
    tint(layer, k, FACE, w.face_tint or WHITE)
    M(PRIM_ALPHA, layer, k, FACE, w.face_alpha or 1)
    tint(layer, k, FACE_BASE, type(w.plate) == "table" and w.plate or WHITE)
    M(PRIM_ALPHA, layer, k, FACE_BASE, w.plate_alpha or 1)
    tint(layer, k, LINE, w.line or WHITE)
    M(C.TEXT_VISIBLE, layer, TEXT_NAME, true, k)
    M(SET_TEXT, layer, TEXT_NAME, w.text or "", k)
  elseif layer == L_CREST then
    -- order matters: a node's visibility is set on every mesh under it, so the parent first, the hides after
    M(C.NODE_VISIBLE, layer, TILE_NODE, true, k)
    for _, n in ipairs(TILE_HIDE_NODES) do M(C.NODE_VISIBLE, layer, n, false, k) end
    for _, m in ipairs(TILE_HIDE) do M(SET_MESH_VISIBLE, layer, m, false, k) end
    M(SET_MESH_VISIBLE, layer, TILE_MESH, w.asked == true, k)
  else
    tint(layer, k, FACE, w.grey and GHOST or WHITE)
    M(PRIM_ALPHA, layer, k, FACE, w.grey and GHOST_ALPHA or 1)
    for _, m in ipairs({ CHECK_BOX, CHECK, LINE, SERIES[1], SERIES[2], SERIES[3] }) do M(SET_MESH_VISIBLE, layer, m, false, k) end
    M(C.TEXT_VISIBLE, layer, TEXT_NAME, false, k)
    M(SET_MESH_VISIBLE, layer, FACE, true, k)
    M(SET_MESH_VISIBLE, layer, FACE_BASE, w.plate ~= false, k)
    if w.plate ~= false then tint(layer, k, FACE_BASE, w.plate or ORANGE) end
  end
end

-- the picture of instance k asked for once the instance is built. The instance stays hidden until the picture has
-- loaded (settle): never an empty plate, a white quad or a picture that changes after it shows
local function ask(layer, k)
  local e = ex(layer)
  local w = e.want[k]
  if not w or not e.built[k] or w.asked then return end
  if layer == L_ICON then
    -- the sprite command answers false (and draws nothing) while the sheet or the instance's model is not ready: asked
    -- again from settle, at most LOAD_FRAMES times
    w.done = M(SPRITE, layer, w.sheet, w.sprite, ICON_SLOT, 0, k) == true
    w.tries = (w.tries or 0) + 1
    w.asked = w.done or w.tries >= LOAD_FRAMES
    if w.asked then w.ready = true end
    return
  end
  w.asked = true
  if layer == L_CREST then
    M(C.EMBLEM, layer, k, TILE_MESH, TILE_SLOT, w.id, 0)
  elseif w.id ~= 0 then
    VRFW_FaceIcon.Request(layer, k, w.id, FACE, FACE_SLOT)
  else
    w.ready = true                         -- a row clone without a face: nothing to load
    return
  end
  e.wait[k] = LOAD_FRAMES
end

-- the panel's extra instances shown together, in one frame, once none of them is still loading (each ready one:
-- dressed, then shown). `stepped`: called from a frame's Step (the loading flags are read and the waits counted down).
-- Returns true while some are still loading
local function settle(stepped)
  local loading = false
  for _, layer in ipairs({ L_ROW, L_CREST, L_FACE, L_ICON }) do
    local e = ex(layer)
    for k, w in pairs(e.want) do
      if w.used and not w.ready then
        if not w.asked then ask(layer, k) end
        local left = e.wait[k]
        if left ~= nil and stepped then
          -- at least one frame after the request: its loading flag is set by then
          if (left < LOAD_FRAMES and M(C.LOADING, layer, k) ~= true) or left <= 0 then
            e.wait[k] = nil
            w.ready = true
          else
            e.wait[k] = left - 1
          end
        end
        if stepped and not w.ready then
          w.left = (w.left or REVEAL_FRAMES) - 1
          if w.left <= 0 then w.ready = true end   -- never built / never loaded: shown as it is
        end
        if not w.ready then loading = true end
      end
    end
  end
  S.loading = loading
  if loading then return true end
  for _, layer in ipairs({ L_ROW, L_CREST, L_FACE, L_ICON }) do
    local e = ex(layer)
    for k, w in pairs(e.want) do
      if w.used and e.shown[k] ~= true then
        dress(layer, k)
        set_shown(layer, k, true)
      end
    end
  end
  return false
end

-- an extra instance opened once (hidden until its content is ready)
local function open_instance(layer, k)
  local e = ex(layer)
  if not e.opened[k] then
    M(C.OPEN_LAYER, layer, k)
    e.opened[k] = true
    e.shown[k] = nil
    set_shown(layer, k, false)
  end
end

-- instance k of `layer` shows icon `id` at row `row` (row-local centre lx, size px), or nothing (id nil); a miniface's
-- plate is tinted `plate` (default orange: a nexus's; false = no plate). The same icon again keeps its loaded picture
local function show(layer, k, id, row, lx, px, plate, grey)
  local e = ex(layer)
  if not id then
    if e.opened[k] then set_shown(layer, k, false) end
    e.want[k] = nil
    e.wait[k] = nil
    return
  end
  open_instance(layer, k)
  local w = e.want[k]
  if not w or w.id ~= id then
    set_shown(layer, k, false)
    w = { id = id }
    e.want[k] = w
    e.wait[k] = nil
  end
  w.used = true
  w.row, w.lx, w.px, w.plate, w.grey = row, lx, px, plate, grey
  if w.ready then dress(layer, k) else ask(layer, k) end
  S.extras = true
end

-- icon instance k shows sprite (sheet, sprite) centred on row `row`'s (lx, ly) at `scale` x the row's own series icon
-- (sheet nil: nothing)
local function show_icon(k, sheet, sprite, row, lx, ly, scale)
  local e = ex(L_ICON)
  if not sheet then
    if e.opened[k] then set_shown(L_ICON, k, false) end
    e.want[k] = nil
    return
  end
  open_instance(L_ICON, k)
  local w = e.want[k]
  if not w or w.sheet ~= sheet or w.sprite ~= sprite then
    set_shown(L_ICON, k, false)
    w = { sheet = sheet, sprite = sprite }
    e.want[k] = w
  end
  w.used = true
  w.row, w.lx, w.ly, w.k = row, lx, ly, scale
  if w.ready then dress(L_ICON, k) else ask(L_ICON, k) end
  S.extras = true
end

-- row clone k (layer vrfw_syn_row: the row object itself) in place of a game row: placed by frame `row` (a game row's
-- instance, or a grid cell's 100 + k + 1), its face drawn for chara `id` (0: no face, nothing requested). Its look:
-- the fields of `look` (plate, line, box, check, face_tint, face_alpha, plate_alpha), its text set by set_row_text
local function open_clone(k, id, row, look)
  local e = ex(L_ROW)
  open_instance(L_ROW, k)
  id = id or 0
  local w = e.want[k]
  if not w or w.id ~= id then
    set_shown(L_ROW, k, false)
    w = { id = id }
    e.want[k] = w
    e.wait[k] = nil
  end
  w.used = true
  w.row = row
  w.plate, w.line, w.box, w.check = nil, nil, nil, nil
  w.face_tint, w.face_alpha, w.plate_alpha = nil, nil, nil
  for key, v in pairs(look or {}) do w[key] = v end
  if w.ready then dress(L_ROW, k) else ask(L_ROW, k) end
  S.extras = true
  return w
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

local EXTRA_LAYERS = { L_ROW, L_CREST, L_FACE, L_ICON }

-- every extra instance of the panel at its row's current place (a hidden game row: the frame kept from before it was
-- hidden)
-- the panel's anchor on screen (x, y), or nil
local function anchor()
  local x, y = M(C.GPOS, S.detail or DETAIL, 0, ANCHOR_MESH)
  if type(x) == "number" and type(y) == "number" then return x, y end
  return nil
end

-- the row places of the panel's layouts (2 or 3 rows), measured on rows the game drew: S.layouts[layout][row index] =
-- { dx, dy, scale } from the anchor. Once a layout has all its rows, the framework is told once
-- (CMND_VRFW_SYNERGY_LAYOUT_KNOWN): it then writes the rows the menu draws itself as 0 (the game draws nothing there)
-- The framework keys them by the menu (the row builder's menu id: S.menu, set by the shop's file, else MENU) and keeps
-- them, handing them back with each panel drawn by clones (a menu opened again has a new script VM and no places)
S.layouts = S.layouts or { [2] = {}, [3] = {} }
S.layout_sent = S.layout_sent or {}
local function learn(layout, drawn)
  local ax, ay = anchor()
  local lay = S.layouts[layout]
  if not ax or not lay then return end
  for _, inst in ipairs(drawn) do
    local ox, oy, sc = row_frame(inst)
    if ox then lay[inst] = { ox - ax, oy - ay, sc } end
  end
  if not S.layout_sent[layout] then
    local parts = {}
    for i = 0, layout - 1 do
      local p = lay[i]
      if not p then return end
      parts[#parts + 1] = string.format("%.3f,%.3f,%.5f", p[1], p[2], p[3])
    end
    S.layout_sent[layout] = true
    pcall(funcLuaCommand, CMD_LAYOUT_KNOWN, layout, S.menu or MENU, table.concat(parts, ";"))
    pcall(funcLuaCommand, LOG_CMD, "VRFW synergy rows: layout", layout, "measured")
  end
end

-- the row places the framework handed back with a panel ("dx,dy,scale;..."), for a layout this VM has not measured
local function adopt_places(layout, places)
  local lay = S.layouts[layout]
  if not lay or type(places) ~= "string" or places == "" or lay[layout - 1] then return end
  local i = 0
  for part in places:gmatch("[^;]+") do
    local dx, dy, sc = part:match("^([^,]+),([^,]+),([^,]+)$")
    dx, dy, sc = tonumber(dx), tonumber(dy), tonumber(sc)
    if dx and dy and sc and lay[i] == nil then lay[i] = { dx, dy, sc } end
    i = i + 1
  end
end

-- a 3-row panel the game drew no row of: its 3-row frame meshes back on the detail layer (the builder showed the 2-row
-- ones); frame = { off = "mesh ids", on = "mesh ids" } from the framework
local function frame_3_rows(frame)
  if type(frame) ~= "table" then return end
  local layer = S.detail or DETAIL
  for _, m in ipairs(split_ids(frame.off)) do M(SET_MESH_VISIBLE, layer, m, false, 0) end
  for _, m in ipairs(split_ids(frame.on)) do M(SET_MESH_VISIBLE, layer, m, true, 0) end
end

local function place_all()
  local frames = {}
  local ax, ay = anchor()
  for _, layer in ipairs(EXTRA_LAYERS) do
    local e = ex(layer)
    for k, w in pairs(e.want) do
      if w.used then
        local f = frames[w.row]
        if f == nil then
          local cf = S.cell_frames and S.cell_frames[w.row]
          local rel = nil
          if w.row >= CLONE_ROW then
            local lay = S.layouts[S.layout or 3]
            rel = lay and lay[w.row - CLONE_ROW]
          elseif S.cell_rel then
            rel = S.cell_rel[w.row]
          end
          if rel then
            f = ax and { ax + rel[1], ay + rel[2], rel[3] } or false
          elseif w.row >= CLONE_ROW then
            f = false
          elseif cf then
            f = cf
          else
            local ox, oy, s = row_frame(w.row)
            if ox then S.row_frames[w.row] = { ox, oy, s } end
            f = S.row_frames[w.row] or false
          end
          frames[w.row] = f
        end
        if f then
          local ox, oy, s = f[1], f[2], f[3]
          if layer == L_ROW then
            -- a row clone: the row object itself at its row's (or grid cell's) origin and scale
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
          set_shown(layer, k, false)
        end
      end
    end
  end
end

-- every extra instance off; what each one shows is kept (the same picture shows again at once when a later panel asks
-- for it)
local function hide_extras()
  for _, layer in ipairs(EXTRA_LAYERS) do
    local e = ex(layer)
    for k in pairs(e.opened) do set_shown(layer, k, false) end
    for _, w in pairs(e.want) do w.used = false end
  end
  S.extras = nil
  S.loading = nil
end

-- ------------------------------------------------------------------------------------------------ the rows

-- a game row back to the game's look (it may have been a nexus / empty row of another synergy's panel). Its face is
-- shown again only when this patch hid it and its picture is not loading: forcing it on showed a face still loading or
-- the last panel's picture for a frame
local function reset_row(inst)
  S.held[ROW .. ":" .. inst] = nil
  -- a face this patch hid: shown again unless its picture is loading (the engine shows it once loaded)
  if S.face_hidden[inst] then
    S.face_hidden[inst] = nil
    if M(C.LOADING, ROW, inst) ~= true then pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, FACE, true, inst) end
  end
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
  for _, layer in ipairs(EXTRA_LAYERS) do
    for _, w in pairs(ex(layer).want) do w.used = false end
  end
end

-- grid cells (a synergy with exactly 4 slot rows): the origin and scale of each cell (S.cell_frames[100 + i]) from the native
-- rows' own frames: columns half a row apart, the second cell row a fraction of the rows' distance below the first. Each
-- cell's final place is written once to loader.log
-- the same cells relative to the panel's anchor, from the measured 3-row layout (the game draws no row under the grid)
local function grid_rel()
  local lay = S.layouts[3]
  local a, b = lay[0], lay[1]
  if not a or not b then return false end
  S.cell_rel = {}
  for i = 1, N_CELLS do
    local col, rw = (i - 1) % 2, math.floor((i - 1) / 2)
    S.cell_rel[100 + i] = { a[1] + col * ROW_WIDTH * GRID_COLS * a[3], a[2] + rw * (b[2] - a[2]) * GRID_PITCH,
      a[3] * GRID_SCALE }
  end
  return true
end

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

-- the rows of the declared synergy `item` just drawn (nothing but the reset for any other synergy). A row whose face
-- must not show (an empty slot drawn with crests, a role icon or minifaces; a slot_members row) is drawn by a row clone
-- that never asks for a face, the game's row hidden as an instance; the clones and the other extra pieces show
-- together once their pictures have loaded (settle)
function S.ApplyPanel(item)
  reset_all()
  if type(item) ~= "number" or item == 0 then hide_extras() return end
  local okc, code = pcall(funcLuaCommand, CMD_LANGUAGE)
  local ok, p = pcall(funcLuaCommand, S.CMD_PANEL, item, okc and code or -1)
  if not ok or type(p) ~= "table" or type(p.rows) ~= "table" then
    -- a game synergy: its rows are the game's; their places measured (the 3-row layout when the third row shows)
    hide_extras()
    local drawn = {}
    for i = 0, N_ROWS - 1 do
      if M(IS_VISIBLE, ROW, i) == true then drawn[#drawn + 1] = i end
    end
    if #drawn > 0 then learn(#drawn == 3 and 3 or 2, drawn) end
    return
  end
  -- rows the game drew (clone = 0) measured; rows it did not draw (clone = 1) are drawn by clones at the layout's places
  local layout = tonumber(p.layout) or 2
  local zeroed = false
  local drawn = {}
  for r, row in ipairs(p.rows) do
    if r <= N_ROWS then
      if row.clone == 1 then zeroed = true else drawn[#drawn + 1] = r - 1 end
    end
  end
  if #drawn > 0 then learn(layout, drawn) end
  -- the game's rows' frames as drawn, before any part of them is hidden (place_all falls back on them)
  for _, inst in ipairs(drawn) do
    local ox, oy, sc = row_frame(inst)
    if ox then S.row_frames[inst] = { ox, oy, sc } end
  end
  if zeroed then
    adopt_places(layout, p.places)
    if layout == 3 then frame_3_rows(p.frame) end
  end
  S.layout = layout
  S.touched = true
  local active = p.active == 1 or p.active == true
  local has_team = p.team == 1 or p.team == true
  local crest_ok, face_ok, icon_ok = has_layer(L_CREST), has_layer(L_FACE), has_layer(L_ICON)
  local clone_ok = has_layer(L_ROW)
  local ci, fi, ii = 0, 0, 0
  -- the shop's panel (no team): what each slot asks for, not who fills it. Rows of one pool are one requirement: its first
  -- row shows it with the number of players asked for, the repeats are taken off; no check boxes (nobody is checked
  -- against a team); texts in the normal colour
  local shop = not has_team
  local share, repeat_of = {}, {}
  if shop then
    local count, first = {}, {}
    local function pool_key(row)
      if row.kind ~= KIND_EMPTY or (tonumber(row.crest) or 0) ~= 0 then return nil end
      return type(row.pool) == "string" and row.pool ~= "" and row.pool or nil
    end
    for r, row in ipairs(p.rows) do
      local k = pool_key(row)
      if k then
        count[k] = (count[k] or 0) + 1
        if not first[k] then first[k] = r end
      end
    end
    for r, row in ipairs(p.rows) do
      local k = pool_key(row)
      share[r] = k and count[k] or 1
      repeat_of[r] = k ~= nil and first[k] ~= r
    end
  end
  local function any_of(n)
    return (string.gsub(text(TXT_ANY_OF), "{n}", function() return tostring(n) end))
  end
  -- exactly 4 slot rows (none repeating another): a 2 x 2 grid of row clones in place of the game's 3 rows
  local repeats = false
  for _, v in pairs(repeat_of) do repeats = repeats or v end
  S.cell_rel = nil
  local grid = false
  if #p.rows == N_CELLS and not repeats and clone_ok then
    if zeroed then grid = grid_rel() else grid = grid_frames() end
  end
  local ROWR = grid and (ROW_WIDTH * GRID_COLS - 24) or ROW_RIGHT      -- the right edge of a row / grid cell, row units
  if grid and not zeroed then
    for i = 0, N_ROWS - 1 do strip_row(i) end
  end
  for r, row in ipairs(p.rows) do
    if not grid and r > N_ROWS then break end
    local inst = r - 1
    local name = type(row.name) == "string" and row.name or ""
    local s
    local big = crest_ok and tonumber(row.crest) or 0
    local role = type(row.role) == "string" and row.role or ""
    local faces = type(row.faces) == "string" and row.faces or ""
    local have_list = type(row.have) == "string" and row.have or ""
    -- which look the row takes (the branches below, in this order)
    local branch
    if repeat_of[r] then
      branch = "repeat"
    elseif shop and row.kind == KIND_EMPTY and big == 0 and faces ~= "" then
      branch = "shop_players"
    elseif shop and row.kind == KIND_EMPTY and big == 0 and crest_ok and role == "" and type(row.crests) == "string"
        and row.crests ~= "" then
      branch = "shop_team"
    elseif big ~= 0 and (row.kind == KIND_EMPTY or row.kind == KIND_FILLED) then
      branch = "members"
    elseif row.kind == KIND_EMPTY and face_ok and have_list ~= "" and faces ~= "" then
      branch = "candidates"
    elseif row.kind == KIND_EMPTY then
      branch = "empty"
    elseif row.kind == KIND_NEXUS or row.kind == KIND_NEXUS_MISSING then
      branch = "nexus"
    else
      branch = "filled"
    end
    local vacant = branch == "candidates" and have_list:match("^1") == nil
    local faceless = branch == "shop_team" or branch == "members" or branch == "empty" or vacant
    -- the row layer drawn on: the game's row, or a clone (cw) in its place
    local RL, fr, cw = ROW, inst, nil
    local clone = row.clone == 1 or (zeroed and r > N_ROWS)
    if clone and branch == "repeat" then
      -- the game drew nothing there: nothing to draw
      fr = CLONE_ROW + inst
    elseif clone and clone_ok and not grid then
      RL, fr = L_ROW, CLONE_ROW + inst
      cw = open_clone(inst, faceless and 0 or (tonumber(row.base) or 0), fr)
    elseif branch == "repeat" then
      strip_row(inst)
    elseif grid then
      RL, fr = L_ROW, 100 + r
      cw = open_clone(inst, faceless and 0 or (tonumber(row.base) or 0), fr)
    elseif faceless then
      hide_part(inst, FACE)
    end
    -- the row's parts, on the clone (kept in its look) or on the game's row (no face / plate hidden there)
    local function plate(c, a)
      if cw then
        cw.plate, cw.plate_alpha = c, a
      elseif c == false then
        hide_part(inst, FACE_BASE)
      else
        tint(ROW, inst, FACE_BASE, c)
        pcall(funcLuaMenuCommand, PRIM_ALPHA, ROW, inst, FACE_BASE, a or 1)
      end
    end
    local series_hidden = false
    local function series_off()
      series_hidden = true
      if not cw then
        for _, m in ipairs(SERIES) do pcall(funcLuaMenuCommand, SET_MESH_VISIBLE, ROW, m, false, inst) end
      end
    end
    if branch == "repeat" then
      -- the shop: one more slot of the pool of a row above (that row says how many): the row taken off
      s = ""
    elseif branch == "shop_players" then
      -- the shop: a slot of named players. The first one's face as the game's row draws it (a grid cell: its own face),
      -- the others' minifaces at the row's end, left of the pool's team crests; one player: his name, else «N of these»
      local ids = split_ids(faces)
      local n = share[r] or 1
      local crests = crest_ok and split_ids(row.crests) or {}
      local others = {}
      if face_ok then
        for j = 2, #ids do others[#others + 1] = ids[j] end
      end
      if #crests > 0 or #others > 0 then series_off() end
      for j, id in ipairs(crests) do
        if ci < N_CREST then
          show(L_CREST, ci, id, fr, ROWR - CREST_PX / 2 - (#crests - j) * CREST_STEP, CREST_PX)
          ci = ci + 1
        end
      end
      local right = #crests > 0 and (ROWR - #crests * CREST_STEP - 6) or ROWR
      for j, id in ipairs(others) do
        if fi < N_FACE then
          show(L_FACE, fi, id, fr, right - (FACE_X1 - FACE_X0) * FACE_SCALE / 2 - (#others - j) * FACE_STEP, 0, WHITE)
          fi = fi + 1
        end
      end
      s = (#ids == 1 and n == 1) and name or any_of(n)
    elseif branch == "shop_team" then
      -- the shop: a slot of a team pool, drawn as a slot_members row: the first crest in the face square, the slot's hint
      -- (several slots: «N of these»), the other crests at the row's end
      local crests = split_ids(row.crests)
      plate(false)
      series_off()
      for j, id in ipairs(crests) do
        if ci < N_CREST then
          if j == 1 then
            show(L_CREST, ci, id, fr, (FACE_X0 + FACE_X1) / 2, BIG_CREST_PX)
          else
            show(L_CREST, ci, id, fr, ROWR - CREST_PX / 2 - (#crests - j) * CREST_STEP, CREST_PX)
          end
          ci = ci + 1
        end
      end
      if (share[r] or 1) > 1 then
        s = any_of(share[r])
      else
        local tn = type(row.team_name) == "string" and row.team_name or ""
        s = (string.gsub(text(row.hint), "{team}", function() return tn end))
      end
    elseif branch == "members" then
      -- slot_members: the pool's team crest in the big square (as the nexus icon); filled: the filler's name and the
      -- check; empty: the team's name, its players' minifaces right-aligned at the row's end
      plate(false)
      if ci < N_CREST then
        show(L_CREST, ci, big, fr, (FACE_X0 + FACE_X1) / 2, BIG_CREST_PX)
        ci = ci + 1
      end
      if row.kind == KIND_FILLED then
        if cw then cw.check = true end
        s = active and name or ("[CGRAYOUT]" .. name .. "[C]")
      else
        series_off()
        local tn = type(row.team_name) == "string" and row.team_name or ""
        s = tn ~= "" and ("[CGRAYOUT]" .. tn .. "[C]") or ""
        local ids = face_ok and split_ids(faces) or {}
        local n = math.min(#ids, MEMBER_FACES)
        for j = 1, n do
          if fi < N_FACE then
            local lx = ROWR - (FACE_X1 - FACE_X0) * FACE_SCALE / 2 - (n - j) * FACE_STEP
            show(L_FACE, fi, ids[j], fr, lx, 0, WHITE)
            fi = fi + 1
          end
        end
      end
    elseif branch == "candidates" then
      -- an empty row of a person pool, drawn as the nexus row: the first candidate's big face (grey plate, as nobody
      -- fills it yet) with its name, the other candidates as minifaces at the right end (in colour when already in the
      -- team, else grey). Nobody fills the slot (the first candidate is not in the team): the empty slot, as retail
      -- draws an unfilled row (no face, plate or name); every candidate is then a miniface at the right
      series_off()
      local have = {}
      for v in have_list:gmatch("[^,]+") do have[#have + 1] = (v == "1") end
      local ids = split_ids(faces)
      if vacant then
        plate(false)
        s = ""
      else
        plate(GHOST, GHOST_ALPHA)
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
    elseif branch == "empty" then
      series_off()
      local crests = crest_ok and split_ids(row.crests) or {}
      local rsheet, rsprite = nil, nil
      if role ~= "" and icon_ok and #crests == 0 then rsheet, rsprite = icon_of(CMD_ROLE_ICON, role) end
      if rsheet then
        -- a staff slot: the role's icon in place of the grey square, the required series' icons right-aligned, the
        -- role's short name
        plate(false)
        if ii < N_ICON then
          show_icon(ii, rsheet, rsprite, fr, (FACE_X0 + FACE_X1) / 2, 0, ROLE_SCALE)
          ii = ii + 1
        end
        ii = series_strip(ii, fr, split_ids(row.series), ROWR)
        local label = TXT_ROLE[role] and text(TXT_ROLE[role]) or ""
        s = label ~= "" and ("[CGRAYOUT]" .. label .. "[C]") or ""
        if (share[r] or 1) > 1 then s = any_of(share[r]) end     -- the shop: several slots of this pool
      elseif #crests > 0 then
        -- no plate: the slot's hint in grey (the pool's, else the synergy's; «{team}» = the pool's team) and the
        -- allowed teams' crests right-aligned on the series icons' place
        plate(false)
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
      else
        -- the grey plate and the hint («{team}»: the slot's team name, a declaration with one pool per slot)
        plate(GHOST, GHOST_ALPHA)
        local tn = type(row.team_name) == "string" and row.team_name or ""
        local h = string.gsub(text(row.hint), "{team}", function() return tn end)
        s = "[CGRAYOUT]" .. h .. "[C]"
        if (share[r] or 1) > 1 then s = any_of(share[r]) end     -- the shop: several slots of this pool
      end
    elseif branch == "nexus" then
      -- the game's own row (the nexus's face, the retail check box), only the line orange
      if cw then
        cw.line = ORANGE
      else
        tint(ROW, inst, LINE, ORANGE)
      end
      plate(ORANGE)
      s = active and name or ("[CGRAYOUT]" .. name .. "[C]")
      if row.kind == KIND_NEXUS and face_ok then
        -- a present nexus of a several-person declaration: his face and name stay at the left, the other allowed persons'
        -- faces go to the far right of the card
        local shown = tonumber(row.base) or 0
        local others = {}
        for _, id in ipairs(split_ids(faces)) do
          if id ~= shown then others[#others + 1] = id end
        end
        if #others > 0 then
          series_off()
          for j, id in ipairs(others) do
            if fi < N_FACE then
              local lx = ROWR - (FACE_X1 - FACE_X0) * FACE_SCALE / 2 - (#others - j) * FACE_STEP
              show(L_FACE, fi, id, fr, lx, 0)
              fi = fi + 1
            end
          end
        end
      end
      if row.kind == KIND_NEXUS_MISSING and has_team then
        -- missing: his face grey and translucent; several persons: the others right after it, no text
        if cw then
          cw.face_tint, cw.face_alpha = GHOST, GHOST_ALPHA
        else
          tint(ROW, inst, FACE, GHOST)
          pcall(funcLuaMenuCommand, PRIM_ALPHA, ROW, inst, FACE, GHOST_ALPHA)
        end
        local shown = tonumber(row.base) or 0
        local others = {}
        if face_ok then
          for _, id in ipairs(split_ids(faces)) do
            if id ~= shown then others[#others + 1] = id end
          end
        end
        if #others > 0 then
          series_off()
          s = ""
          for j, id in ipairs(others) do
            if fi < N_FACE then
              local lx = FACE_X1 + 10 + (FACE_X1 - FACE_X0) * FACE_SCALE / 2 + (j - 1) * FACE_STEP
              show(L_FACE, fi, id, fr, lx, 0)
              fi = fi + 1
            end
          end
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
        if #crests > 0 and (#own > 0 or cw) then
          series_off()
          for j, id in ipairs(crests) do
            if ci < N_CREST then
              local lx = ROWR - SERIES_CREST_PX / 2 - (#crests - j) * SERIES_CREST_STEP
              show(L_CREST, ci, id, fr, lx, SERIES_CREST_PX)
              ci = ci + 1
            end
          end
          local left = ROWR - SERIES_CREST_PX - (#crests - 1) * SERIES_CREST_STEP
          ii = series_strip(ii, fr, own, left - CREST_GAP)
        elseif #crests > 0 then
          for j, id in ipairs(crests) do
            if ci < N_CREST then
              local lx = SERIES_LEFT - SERIES_CREST_GAP - SERIES_CREST_PX / 2 - (#crests - j) * SERIES_CREST_STEP
              show(L_CREST, ci, id, fr, lx, SERIES_CREST_PX)
              ci = ci + 1
            end
          end
        end
      end
    end
    if shop and type(s) == "string" then
      -- the shop: every text in the normal colour (nothing is greyed against a team)
      s = string.gsub(string.gsub(s, "%[CGRAYOUT%]", ""), "%[C%]", "")
    end
    if cw then
      -- a clone: its text, check box and check in its look (sent when it is built and when it shows)
      cw.text = s or ""
      if shop then
        cw.box, cw.check = false, false
      elseif branch ~= "members" then
        cw.check = row.kind == KIND_FILLED or (row.kind == KIND_NEXUS and has_team)
      end
      -- a clone of a player's row: that player's series icons at the row's end, as the game's row draws them
      if not series_hidden and icon_ok and type(row.series) == "string" and row.series ~= "" then
        ii = series_strip(ii, fr, split_ids(row.series), ROWR)
      end
      if cw.ready then dress(L_ROW, inst) end
    elseif branch ~= "repeat" then
      if name ~= "" or row.kind == KIND_EMPTY or row.kind == KIND_NEXUS_MISSING then
        pcall(funcLuaMenuCommand, SET_TEXT, ROW, TEXT_NAME, s or "", inst)
      end
      if shop then
        -- no check boxes in the shop: a box means «in your team», and the shop's panel checks no team
        M(SET_MESH_VISIBLE, ROW, CHECK_BOX, false, inst)
        M(SET_MESH_VISIBLE, ROW, CHECK, false, inst)
      end
    end
  end
  -- the instances this panel does not use
  for k = ci, N_CREST - 1 do show(L_CREST, k, nil) end
  for k = fi, N_FACE - 1 do show(L_FACE, k, nil) end
  for k = ii, N_ICON - 1 do show_icon(k, nil) end
  for k = 0, N_CELLS - 1 do
    local w = ex(L_ROW).want[k]
    if w and not w.used then show(L_ROW, k, nil) end
  end
  if not grid then S.cell_frames = nil end
  if S.extras then
    place_all()
    settle(false)
  end
  -- an inactive synergy's title and effects at half alpha; the shop's panel (no team) at full: its title stays readable
  detail_alpha((active or shop) and 1 or GREY_ALPHA)
end

-- per frame while extras show: placed again (the panel's open animation moves the rows); while some picture is still
-- loading, the loading flags read (at most LOAD_FRAMES frames) and the panel's extras shown together once all are ready
function S.Tick()
  if not S.extras then return end
  place_all()
  if next(S.held) ~= nil then hold_hidden() end
  if S.loading ~= false then settle(true) end
end

-- an extra layer's instance is built: its look sent again and its picture asked for (it shows with the others)
function S.Built(layer, inst)
  if (layer == L_CREST or layer == L_FACE or layer == L_ICON or layer == L_ROW) and type(inst) == "number" then
    ex(layer).built[inst] = true
    dress(layer, inst)
    ask(layer, inst)
  end
end

-- every extra piece (crests, minifaces, icons, row clones) off, the rows left as drawn: a page of the panel without the
-- condition rows (the shop's effects page) or a detail that is not a synergy. The next ApplyPanel shows them again
function S.HideExtras()
  hide_extras()
end

-- the rows' layer and check parts, for the menus' own files
S.ROW, S.CHECK, S.CHECK_BOX = ROW, CHECK, CHECK_BOX
