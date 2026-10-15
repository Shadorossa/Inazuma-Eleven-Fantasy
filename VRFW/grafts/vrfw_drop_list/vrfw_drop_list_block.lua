-- VR-Framework: the "AURAS" section of the drop-rate list (graft vrfw_drop_list, graft.toml). Layer
-- win05_38_drop_rate_list_item (one instance per visible row); node positions / sizes = the retail layout
-- (win05_38.g4pkm, local to _pos_drop01, y up; node scale = the quad's size in px). Nothing runs at load but the
-- definitions.
VRFW_DropList = VRFW_DropList or {}
do
  local D = VRFW_DropList
  D.ROW = @crc:CMND_VRFW_DROP_ROW@                  -- () -> section (1 header, 2 aura item, 0 other, -1 none), kind, id
  D.TEXT_AURAS = @crc:vrfw_drop_list_auras@          -- menu_text "AURAS"
  D.TEXT_GET = 4074371074                            -- CMND_TEXT_GET (textId) -> text
  D.SET_TEXT = 1083631230                            -- (layer, text node, string, instance)
  D.TEXT_VISIBLE = 1505208242                        -- (layer, text node, on, instance)
  D.TEXT_RECT = 3549540977                           -- CMND_GET_MENU_TEXT_RECT_SIZE (layer, instance, text node, string) -> w, h
  D.MESH_VISIBLE = 3405944500                        -- (layer, mesh, on, instance)
  D.LOC_VISIBLE = 2158717427                         -- (layer, locator, on, instance)
  D.NODE_POS = 1856671416                            -- (layer, instance, node, x, y, z)
  D.NODE_SCALE = 2885415772                          -- (layer, instance, node, w, h)
  D.SET_TEX = 558735651                              -- (layer, atlas path, sprite, texture slot, 0, instance)
  D.LOAD_TEX = 839427544                             -- CMND_LOAD_MENU_RES_TEXTURE (path)
  D.ALPHA = 4231609516                               -- CMND_SET_LAYER_MODEL_ALPHA (layer, instance, 1, alpha, mesh)
  D.FACE = 346643487                                 -- face icon (layer, instance, mesh, slot, charaId, 0, size, ...)
  D.SKILL_INFO = 2580586398                          -- CMND_GET_SOCCER_SKILL_INFO (item, n): 7 element, 13 aura type, 17 aura chara
  D.W38 = 2268931645                                 -- #/menu/10_win/win05/win05_38/<LG>/win05_38.g4tx
  D.T30_PATH = "#/menu/102_team/team00/team00_30/<LG>/team00_30.g4tx"
  D.T30 = 2815298114                                 -- crc of D.T30_PATH (the aura cards' atlas)
  D.HEADER = 3948576367 --[[vrfw_gtxt_auras01]]      -- VRFW image: the "AURAS" label in the "Items" style
  -- nodes and their retail layout {node, x, y, w, h}
  D.N = {
    name = {1704438437 --[[_text_name01]], 131, 27},
    pill = {802624838 --[[_gtxt_spirits01]], 0, 18, 104, 36},
    line = {1428028149 --[[_offer_partition_line01]], 113, 2, 630, 4},
    band = {2913709463 --[[_list_drop_chr_rarity01]], 8, 36, 516, 72},
    art = {3879379975 --[[_list_drop_chr_dmy01]], 10, 64, 128, 128},
    percent = {2780643282 --[[_pos_percent01]], 539, 0},
    icon = {1550177077 --[[_pos_icon_item01]], 69, 0}
  }
  D.BASE = 4248781227 --[[_list_drop_base01]]
  D.BOOST = 4108315022 --[[_pos_boost01]]
  D.RESET_FACE = 4176779611                          -- ResetFaceIcon (layer, instance, texture slot)
  D.HIDE_TABS = @crc:CMND_VRFW_DROP_HIDE_TABS@        -- () -> the tab types never shown ([VRFW.DropList] HideTabs)
  D.TAB_ITEM = 4044286600 --[[cmn06_20_list_tab_item]]
  -- the aura cards' face icon size per aura type (personal_plate_inc: keshin / armed 8, Mix-Max 12, totem 14)
  D.ART_SIZE = {[0] = 8, [1] = 8, [2] = 12, [3] = 14, [4] = 8, [5] = 8, [6] = 12}
  D.PLATE = 837199438 --[[_item_base01]]
  D.CHR = 2336812131 --[[_pos_chr01]]
  D.SLOT_BAND = 94010567 --[[list_drop_chr_rarity01]]
  D.SLOT_ART = 2605092343 --[[list_drop_chr_dmy01]]
  -- the aura banner in the row: the band over the whole row bar (724 px from x 23, the band's own 10.5 : 1), the item
  -- icon on the band's dark square, the aura's art at the band's right end (the row's portrait quad keeps its mask
  -- list_drop_chr_msk01: a slanted 91 x 54 strip, x 19-110 / y 37-91 of the 128 px quad, fading to the right; the quad
  -- moved so the strip ends at the band's right end and sits on its middle), the rate moved left of the art
  D.AURA = {band = {23, 35, 724, 69}, art = {629, 64, 128, 128}, percent = {469, 0}, icon = {57, 0}}
  -- the team00_30 band of each aura type (CMND_GET_SOCCER_SKILL_INFO 13: 0 keshin, 1 armed keshin, 2 Mix-Max, 3 totem,
  -- 4 bond transformation, 5 awakening, 6 mode change), one per element 1-5 (fire / wind / wood / earth / none)
  D.BANDS = {
    [0] = {1716659057, 4284183243, 2287747677, 372824062, 1631577960},   -- fs_base01-05
    [1] = {1742805750, 4276636492, 2314173402, 395046521, 1619844847},   -- fsa_base01-05
    [2] = {3558327990, 1293850380, 974759834, 2759668281, 3547988655},   -- mixi_base01-05
    [3] = {2619781135, 87024053, 1915277603, 3964421248, 2605413398},    -- soul_base01-05
    [4] = {1514509020, 3276587878, 3024876528, 707749459, 1562924741},   -- kizuna_base01-05
    [5] = {4250578944, 1683218874, 324325676, 2368750735, 4197938201},   -- power_base01-05
    [6] = {3293713115, 1566262113, 710702071, 3023627860, 3275740866}    -- mode_base01-05
  }
  D.styled = {}   -- instance -> "aura" / "header" (its nodes moved)
  -- a portrait just (re)requested stays hidden for D.ART_DELAY row calls (the texture loads meanwhile: no white
  -- frame while scrolling; the retail redraw of a row clears the portrait, so it is requested on every redraw)
  D.ART_DELAY = 6
  D.art_t = {}
  D.forced = false

  local function cmd(...)
    return pcall(funcLuaMenuCommand, ...)
  end

  function D.Section()
    local ok, s, kind, id = pcall(funcLuaCommand, D.ROW)
    if not ok or s == nil then
      return -1
    end
    return s, kind, id
  end

  local function pos(L, i, n, x, y)
    cmd(D.NODE_POS, L, i, n[1], x or n[2], y or n[3], 0)
  end

  local function size(L, i, n, w, h)
    cmd(D.NODE_SCALE, L, i, n[1], w or n[4], h or n[5])
  end

  -- the retail layout of an instance a section row changed
  function D.Plain(L, i)
    if D.styled[i] == nil then
      return
    end
    local N = D.N
    pos(L, i, N.name)
    pos(L, i, N.pill)
    size(L, i, N.pill)
    pos(L, i, N.line)
    size(L, i, N.line)
    pos(L, i, N.band)
    size(L, i, N.band)
    pos(L, i, N.art)
    size(L, i, N.art)
    pos(L, i, N.percent)
    pos(L, i, N.icon)
    cmd(D.MESH_VISIBLE, L, D.BASE, true, i)
    cmd(D.MESH_VISIBLE, L, D.PLATE, true, i)
    D.styled[i] = nil
  end

  -- the "AURAS" header = the game's own header row (the "Items" pill, its size and place, the partition line) with
  -- only its label picture changed: vrfw_gtxt_auras01 of win05_38, one per language (VRFW image win05_38_auras.toml,
  -- research/scripts/vrfw_drop_list_header_build.py from menu_text vrfw_drop_list_auras)
  function D.Header(L, i)
    cmd(D.SET_TEX, L, D.W38, D.HEADER, 4088285385 --[[gtxt_spirits01]], 0, i)
  end

  -- the aura's character for its art: the aura chara (CMND_GET_SOCCER_SKILL_INFO 17), else (Mix-Max, mode change) the
  -- partner card of the aura move (19) as a character (347353059), as the game's aura cards do
  local function aura_chara(item)
    local _, ok, c = pcall(funcLuaCommand, D.SKILL_INFO, item, 17)
    if ok and type(c) == "number" and c ~= 0 then
      return c
    end
    local _, ok2, card = pcall(funcLuaCommand, D.SKILL_INFO, item, 19)
    if ok2 and type(card) == "number" and card ~= 0 then
      local ok3, c2 = pcall(funcLuaCommand, 347353059, card)
      if ok3 and type(c2) == "number" and c2 ~= 0 then
        return c2
      end
    end
    return 0
  end

  -- an item of the section: its aura's banner (the aura card's band and art)
  function D.Aura(L, i, item)
    local N, A = D.N, D.AURA
    local _, okt, kind = pcall(funcLuaCommand, D.SKILL_INFO, item, 13)
    local _, oke, elem = pcall(funcLuaCommand, D.SKILL_INFO, item, 7)
    if not okt or type(kind) ~= "number" then
      kind = 0
    end
    local bands = D.BANDS[kind] or D.BANDS[0]
    if not oke or type(elem) ~= "number" or elem < 1 then
      elem = 1
    elseif elem > 5 then
      elem = 5
    end
    D.styled[i] = "aura"
    cmd(D.LOC_VISIBLE, L, D.CHR, true, i)
    -- the spirit rows' "POTENCIADOR" tag lives under the same locator: not for items (their boost = the yellow rate)
    cmd(D.LOC_VISIBLE, L, D.BOOST, false, i)
    cmd(D.MESH_VISIBLE, L, D.BOOST, false, i)
    cmd(D.MESH_VISIBLE, L, D.BASE, false, i)
    cmd(D.MESH_VISIBLE, L, D.PLATE, false, i)
    cmd(D.SET_TEX, L, D.T30, bands[elem], D.SLOT_BAND, 0, i)
    cmd(D.MESH_VISIBLE, L, N.band[1], true, i)
    pos(L, i, N.band, A.band[1], A.band[2])
    size(L, i, N.band, A.band[3], A.band[4])
    pos(L, i, N.percent, A.percent[1], A.percent[2])
    pos(L, i, N.icon, A.icon[1], A.icon[2])
    -- Mix-Max / mode change: the label without the player ("Miximax Trans: X" -> "Miximax Trans"), the art shows who
    if kind == 2 or kind == 6 then
      local okn, name = pcall(funcLuaCommand, 1883585771 --[[CMND_GET_ITEM_PARAM]], item, 0)
      if okn and type(name) == "string" then
        local head = string.match(name, "^(.-)%s*[:：]")
        if head ~= nil and head ~= "" then
          cmd(D.SET_TEXT, L, N.name[1], head, i)
        end
      end
    end
    local chara = aura_chara(item)
    local shown = false
    -- the portrait only when the aura's character has a face icon (else a white square, e.g. an imported aura
    -- character without VR art): no art then, the row keeps its item icon
    if chara ~= 0 then
      local okf, has = pcall(funcLuaMenuCommand, 2208175668 --[[has a face icon]], chara)
      if okf and has then
        if kind == 2 or kind == 6 then
          cmd(D.RESET_FACE, L, i, D.SLOT_ART)
        end
        shown = cmd(D.FACE, L, i, N.art[1], D.SLOT_ART, chara, 0, D.ART_SIZE[kind] or 8, true, true, true, 5)
      end
    end
    if shown then
      D.art_t[i] = D.ART_DELAY
      cmd(D.ALPHA, L, i, 1, 0, N.art[1])
      cmd(D.MESH_VISIBLE, L, N.art[1], true, i)
      pos(L, i, N.art, A.art[1], A.art[2])
      size(L, i, N.art, A.art[3], A.art[4])
    else
      cmd(D.MESH_VISIBLE, L, N.art[1], false, i)
    end
  end
end

local vrfw_dl_init = OnInit
function OnInit(...)
  local r = {vrfw_dl_init(...)}
  pcall(funcLuaMenuCommand, VRFW_DropList.LOAD_TEX, VRFW_DropList.T30_PATH)
  VRFW_DropList.styled = {}
  return table.unpack(r)
end

local vrfw_dl_tab = OnTabChanged
function OnTabChanged(a1, ...)
  VRFW_DropList.forced = true -- the retail flag4: the focused row is redrawn once
  return vrfw_dl_tab(a1, ...)
end

-- the row redrawn now: dirty, or the focused row after a tab change (retail flag4)
local function vrfw_dl_dirty(a3, a4)
  local D = VRFW_DropList
  if D.forced and a4 then
    D.forced = false
    return true
  end
  return a3
end

local vrfw_dl_item = UpdateListItem_DropItem
function UpdateListItem_DropItem(a1, a2, a3, a4, a5, a6, a7)
  local dirty = vrfw_dl_dirty(a3, a4)
  local r = {vrfw_dl_item(a1, a2, a3, a4, a5, a6, a7)}
  local D = VRFW_DropList
  local s = D.Section()
  if s == 2 then
    if dirty then
      pcall(D.Aura, a1, a2, a5)
    end
    -- the retail call hides the portrait mesh of item rows every frame (UpdateListItem_IconMesh)
    local t = D.art_t[a2] or 0
    if t > 0 then
      D.art_t[a2] = t - 1
    end
    pcall(funcLuaMenuCommand, D.ALPHA, a1, a2, 1, t > 0 and 0 or 1, D.N.art[1])
  elseif dirty then
    pcall(D.Plain, a1, a2)
  end
  return table.unpack(r)
end

local vrfw_dl_chara = UpdateListItem_DropChara
function UpdateListItem_DropChara(a1, a2, a3, a4, a5, a6, a7, a8)
  local dirty = vrfw_dl_dirty(a3, a4)
  if dirty then
    pcall(VRFW_DropList.Plain, a1, a2)
  end
  return vrfw_dl_chara(a1, a2, a3, a4, a5, a6, a7, a8)
end

local vrfw_dl_iline = UpdateListItem_ItemLine
function UpdateListItem_ItemLine(a1, a2, a3, ...)
  local r = {vrfw_dl_iline(a1, a2, a3, ...)}
  if a3 then
    local D = VRFW_DropList
    if D.Section() == 1 then
      pcall(D.Header, a1, a2)
    else
      pcall(D.Plain, a1, a2)
    end
  end
  return table.unpack(r)
end

local vrfw_dl_cline = UpdateListItem_CharaLine
function UpdateListItem_CharaLine(a1, a2, a3, ...)
  if a3 then
    pcall(VRFW_DropList.Plain, a1, a2)
  end
  return vrfw_dl_cline(a1, a2, a3, ...)
end

-- [VRFW.DropList] HideTabs: those tab types are left out of the tab list (a mod without player-spirit drops hides the
-- "Grupo A-D" tabs); one tab left = no switcher (its icon row hidden)
local vrfw_dl_tabs = OnUpdateTabData
function OnUpdateTabData(a1, ...)
  local D = VRFW_DropList
  local got = {pcall(funcLuaCommand, D.HIDE_TABS)}
  local hide = {}
  for k = 2, #got do
    if type(got[k]) == "number" then
      hide[got[k]] = true
    end
  end
  local left = 0
  if type(a1) == "table" and next(hide) ~= nil then
    for k = 1, #a1 do
      if hide[k - 1] then
        a1[k] = 0
      end
      if a1[k] == 1 then
        left = left + 1
      end
    end
  end
  local r = {vrfw_dl_tabs(a1, ...)}
  if left == 1 then
    local okn, n = pcall(funcLuaMenuCommand, 1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], D.TAB_ITEM)
    for k = 0, ((okn and type(n) == "number") and n or 1) - 1 do
      pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], D.TAB_ITEM, k, false)
    end
  end
  return table.unpack(r)
end
