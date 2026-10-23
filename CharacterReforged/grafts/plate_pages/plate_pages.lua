-- ===== EVT plate_pages plate BEGIN =====
-- ONE block for every host of the player page (2026-10-13, owner: no more copies): personal_plate_menu (host_plate.lua,
-- pages = true: the whole paged player page) and the hosts with their own copy of the plate, Equipamiento
-- (equip_menu_select, host_equip.lua) and Tabla de habilidades (evt_skill_slot_menu, host_skill.lua), pages = false:
-- the header row (shared VRFW_UI.HeaderRow), the white card and the bar chart on the hosts' OWN added layers
-- (Character Reforged content/menus/player_page_layout.toml «host look»: evt_pp_graph_host / _hostx /
-- evt_pp_num_host), the hosts' page layer
-- retail. The hosts' fork plate_host_look.lua (2026-10-06..13) is merged back here: its host-only parts run where
-- G.H.pages is false, everything else is the same code.
-- the host table and the common part in their own function: a host with a big main chunk (evt_skill_slot_menu: ~194
-- top-level locals) keeps its registers (the assembler's decompile round trip)
;(function()
@HOST@
@COMMON@
end)()
-- The mod Utilities' career page «TRAYECTORIA» (page type 6; Utilities' graft util_career_page since 2026-10-08, its
-- Lua table UTIL_CS): its page change runs HERE, under this block's wrappers (they see type 6 and lay out the page's two
-- rows, G.Career) and over the Hiper page's: UTIL_CS.PageChange draws the passives layout (type 2) with the career panel
-- over it. UTIL_CS is looked up at run time; without it type 6 goes on unchanged. When Utilities' plate file runs after
-- this one it sees EVT_PPG_CS_WRAPPED and leaves these two functions alone; when it ran first (both mods lua_early, IF
-- requires Utilities) its own wrapper sits under these and hides its panel on the other pages (harmless twice).
;(function()   -- in a function: no main-chunk registers (a host with ~194 top-level locals: evt_skill_slot_menu)
  if EVT_PPG_CS_WRAPPED == nil then
    EVT_PPG_CS_WRAPPED = {}
  end
  for _, fname in ipairs((EVT_PPG_HOST == nil or EVT_PPG_HOST.pages ~= false)
      and {"ChangePersonalPlatePageByCharaHdl", "ChangePersonalPlatePageByCharaParamId"} or {}) do
    local cur = _ENV[fname]
    if type(cur) == "function" and not EVT_PPG_CS_WRAPPED[cur] then
      local w = function(a1, a2, ...)
        local S = UTIL_CS
        if type(S) == "table" and type(S.PageChange) == "function" then
          return S.PageChange(fname, cur, a1, a2, ...)
        end
        return cur(a1, a2, ...)
      end
      EVT_PPG_CS_WRAPPED[w] = true
      _ENV[fname] = w
    end
  end
end)()
-- The pages themselves (personal_plate_menu). Layout data: Character Reforged content/menus/player_page_layout.toml
-- (research/scripts/if_plate_row_build.py). Every page is drawn by the retail ChangePersonalPlatePageByCharaHdl with a
-- retail type, then adjusted here:
--   PERFIL (type 8)        = type 1 with the moves and the radar hidden; the description (pp _text_explain01 and the
--                            band copy's _flavor_plate01) shown; title evt_gtxt_profile01; the 3D model allowed
--                            (EVT_PPM_PAGE_OK, research/grafts/plate_model)
--   ATRIBUTOS (type 9)     = type 1 with the moves hidden: the radar's labels / numbers are laid out as rows (layout)
--                            and 8 bars (evt_pp_stat_bar, attached to the radar base) drawn from the same values
--   SUPERTÉCNICAS (type 1) = the moves with the radar hidden; title evt_gtxt_psmoves01 (Character Reforged's images)
--   the other types        = as before (the radar of the equipment pages is the bar chart too).
-- The description is hidden on every other page. The radar polygon (soccer11_07 meshes) and the page's radar plates
-- are hidden everywhere: the chart replaces them.
-- Round 3 (second test): the drawType-1 page draws NOTHING in game (neither band nor body), so
--   evt_pp_band  (a normal 2D copy of the page, attached to it at _pos_base01) draws the page BODY and, on PERFIL,
--                the description box; on PERFIL its body sprite is swapped for evt_pp_page_win (the same picture with
--                a transparent window at x 1505..1905, y 381..773) so the 3D model (drawn before every 2D layer) shows
--                through it;
--   evt_pp_slant (a copy of the office's status plate object, soccer11_04 layout) draws the header band SLANTED like
--                the office's name plate: filled with the same player by UpdateCharaStatusPlateInfoByCharaStHdl (its
--                rarity colours), everything but the two plate sprites hidden, squashed to the row y 163..227;
--   evt_pp_dots  (2 copies of the retail status base) = page dots 7 and 8; slots 1-6 are the dot meshes of
--                plate_hiper / career re-spaced by the layout: 8 pages, 8 dots.
-- Round 4 (third test, Nacho): the model is the BACKDROP of every page (behind all the content; the page copy's body
-- is see-through on its right half: evt_pp_page_win on every page), the data back at its retail height, no page
-- titles at all (arrows and dots stay), the stats as 8 VERTICAL bars in one row (the fill mesh of the gauge only,
-- scaled to the value; the rate set the radar's way on every instance: before only instance 0 got its fill), the
-- move-slot badges 1 / 2 / 3 only on SUPERTÉCNICAS, the radar only on ATRIBUTOS (not on the equipment pages).
-- Round 5 (fourth test, Nacho): NO page body at all (the copy shows only the description box, at the bottom of the
-- PERFIL page); the slant copy's own texts, numbers and portrait hidden (they ghosted under / beside the row); the bars'
-- rate set up per instance with the gauge's own group (the round-4 lookup failed: thin lines); columns inside the page;
-- Equipamiento = 2 x 2 items at 80 %, its title row hidden; the Hiper page's L3 toggles the keshin a miximax gives.
-- Round 6 (fifth test): the bars = the gauge FRAME mesh with a plain bar sprite swapped in (evt_pp_bar01, the PE digits'
-- technique; no rate at all: rates never filled), scaled to the value; a content band (the page body texture cropped
-- to y 580..965, sprite evt_pp_band_bg in the page copy) behind ATRIBUTOS, Hiper, Equipamiento, Pasivas, Sexto
-- sentido and Trayectoria; the ‹ › arrows hidden; a slanted box (the office plate's nickname box of the slant copy)
-- behind the archetype icon.
-- Round 7 (sixth test): each page's content band only as tall as its content (5 cropped sprites); 3D bars (front /
-- side / top faces = the gauge's frame / empty / label meshes, each with its own sprite, laid out by node); the
-- archetype icon on a slanted box (layer evt_pp_tag); SUPERTÉCNICAS as 2 | 2 | 2 (three slot groups across the page,
-- only the moves' icons; the focused move opens its full plate under them); the «Configuración habitual» guide
-- (mainmenu01_19, Tab ⇆ ?) hidden; over the transfer office (shop_menu open) no description / model of ours.
-- Round 8 (seventh test): ONE fixed content band (x 985..1920, y 655..965, left corners rounded) on every page, every
-- page's content inside it; 3D columns = a body sprite (front + darker side) and a cap sprite (top face + the side's
-- top) on two meshes, at most 120 px; SUPERTÉCNICAS rebuilt (groups 1 | 2 | 3 in the band, the retail rpg badges
-- hidden, collapsed rows' AT numbers / IA marks / blanks off); the archetype box with the band's exact slant, in front
-- of the band; the PERFIL hint «R3 Cambiar forma» (plate_model cycles the forms).
-- Round 10 (ninth test): segmented ATRIBUTOS bars (one sprite per colour and segment count, evt_pp_seg_<colour>_<n>,
-- coloured by the stat's position tag); SUPERTÉCNICAS in one row of three slot groups; Pasivas tiles on their own
-- slanted layer (evt_pp_ptile); the dots inside the card; Trayectoria as 2 x 2 cells; the archetype box covers a dual
-- archetype's second icon; nothing of the page while no player is focused (empty slot).
-- Engine calls only inside callbacks; wrappers forward their arguments.
EVT_PPG = EVT_PPG or {}
;(function()
  local G = EVT_PPG
  G.PAGE = 878737202                     -- team11_01_personal_plate (drawType 1 in this screen)
  G.BAND = @crc:evt_pp_band@
  G.BAR = @crc:evt_pp_stat_bar@
  -- round 11: the host's own layer names (host_plate.lua / host_equip.lua): one block for every host of the page
  G.H = EVT_PPG_HOST or {plate = 1844915256, status = 730911947, graph = 1572892955, radar = 3868632847, pages = true}
  G.PLATE = G.H.plate                    -- the header plate (soccer11_04_formation_chara_status / soccer11_04_chara_status)
  G.STATUS = G.H.status                  -- the status base
  G.GRAPH = G.H.graph                    -- the radar base (the 8-axis copy: object redirected on every host)
  G.RADAR = G.H.radar                    -- the radar polygon layer
  G.EXTRA = 3201974232                   -- evt_soccer11_06_9x_formation_status_graph_extra (Suerte)
  G.NUM = 732343773                      -- soccer11_06_p1_formation_status_graph_param_num
  if G.H.pages == false then
    -- 2026-10-06 (hosts: added layers only): the chart is OUR added layer evt_pp_graph_host (unattached, placed by
    -- G.HostChart); the retail radar base / numbers (G.H.graph, 732343773) are hidden there
    G.GRAPH = @crc:evt_pp_graph_host@
    G.RETAIL_GRAPH = G.H.graph
    G.EXTRA = @crc:evt_pp_graph_hostx@    -- Suerte's label layer (host copy)
    G.NUM = @crc:evt_pp_num_host@         -- our 8 numbers (the retail param_num 732343773 stays, hidden)
    G.RETAIL_NUM = 732343773
    G.CHART_AT = {1452, 746}              -- the chart's centre on the card (screen; our layers are unattached)
  end
  G.N_ATC_NUM = {@crc:_atc_num01@, @crc:_atc_num02@, @crc:_atc_num03@, @crc:_atc_num04@, @crc:_atc_num05@,
    @crc:_atc_num06@, @crc:_atc_num07@, @crc:_atc_num07@}       -- group g's value locator (g 8 on the extra layer)
  G.N_EXPLAIN = 499981750                -- _text_explain01 (pp)
  G.M_PAGE = 2757749471                  -- _personal_plate01
  G.M_PORTRAIT = 3562698908              -- _icon_chr_status_base01
  G.M_BAND = 2233169001                  -- _status_chr_plate01
  G.M_FLAVOR = 698230623                 -- _flavor_plate01
  G.M_PARAM = {62066836, 2595897646}     -- _param_plate01 / 02
  G.M_POLY = {3874402962, 2948969189}    -- soccer11_07: _graph01, _parameter_base_icon01
  G.M_T_PARAM = {254458604, 2518936406}  -- _gtxt_parameters01 / 02 (ATRIBUTOS)
  G.M_T_SIXTH = 1621221814               -- _gtxt_sixthsense01 (the title mesh the plate_hiper / career pages reuse)
  G.TX_S1105 = 1156047165                -- #/menu/00_soccer/soccer11/soccer11_05/<LG>/soccer11_05.g4tx
  G.SP_SIXTH = 2885965654                -- gtxt_sixthsense01 (swap node of the title mesh)
  G.SP_MOVES = 2733230183                -- evt_gtxt_psmoves01 (Character Reforged images soccer11_05.toml)
  G.SLANT = @crc:evt_pp_slant@
  -- the slant copy's own rarity banner (soccer11_04 _player_rarity01): the row shows the rarity once, left of «Nv.»
  -- (Character Reforged's header layout); the copy's retail banner sat under the row, left of the level. The retail
  -- fill shows it and a special card's «hero» animation switches it back on, so it is kept off every frame.
  G.SLANT_RARITY = 1052197874            -- _player_rarity01
  -- 2026-10-14 (owner: the big ribbon still showed on Ídolo cards, and for a moment on every card): the banner is also
  -- put out of reach of whatever switches its visibility back on: its parent node _pos_rarity01 (it holds only the
  -- banner) hidden and the banner mesh shrunk to the layouts' hide size (its transform has no animation track in
  -- soccer11_04's G4RA, so nothing scales it back); and the copy is hidden whenever an instance (re)opens, until its
  -- first fill (G.Slant), so its retail default (green band + banner) is never drawn.
  G.SLANT_RARITY_NODE = 1457835367       -- _pos_rarity01
  G.HIDDEN_SCALE = 0.01                  -- the layouts' «hidden» size (0 would make the bind matrix singular)
  G.DOTS = @crc:evt_pp_dots@
  G.DOT_TRACE = {[0] = @crc:evt_pp_dots0@, @crc:evt_pp_dots1@, @crc:evt_pp_dots2@, @crc:evt_pp_dots3@,
    @crc:evt_pp_dots4@, @crc:evt_pp_dots5@}
  -- round 14 (Nacho): the Pasivas sub-page indicator right of the «Q • • • E» row, on its line: the R3 key glyph
  -- (instance 5: the copy's _text_btn_r01 moved onto its dot position, text <CMD_FUNC6>) then one dot per sub-page
  -- (instances 2.., the page dots' look: the current one lit); only on the Pasivas page. Screen x of each (dot-slot convention)
  G.PSUB_DOT_X = {[2] = 1622, [3] = 1650, [4] = 1678}
  G.PSUB_KEY_X = 1584
  G.N_BTN_R = 59628764                   -- _text_btn_r01 (its parent is the dot meshes' parent _pos_offset01)
  -- the slanted band (evt_pp_slant: a soccer11_04 plate showing only its band sprites) and its strip / place are
  -- the framework's shared header row (VRFW_UI.HeaderRow.BandFill / PlaceBand, content\defaults\ui_plates.toml
  -- [header_row.band]; docs/framework/ui-plates.md), the same on every screen with a header row
  -- dots: (off, on) mesh per slot 1-6 on the status base; slots 7-8 = evt_pp_dots instances 0 / 1
  G.DOT_OFF = {3784855471, 2788701567, 2606243023, 695779551, 1007698216, 2986517796}
  G.DOT_ON = {2540064569, 2996782795, 2245255383, 1030719410, 2696462091, 4121092084}
  G.DOTS_MAX = 8                         -- dot slots of the layout (6 status-base meshes + 2 evt_pp_dots copies)
  G.DOT_X = {1489, 1517}                 -- slots 7 / 8 (layout: x0 1321, pitch 28)
  G.DOT_PITCH = G.DOT_X[2] - G.DOT_X[1]
  -- the Q / E glyphs' joints (_text_btn_l01 / _text_btn_r01) and their layout x (player_page_layout.toml), status base
  G.KEY_NODES = {355816102, 59628764}
  G.KEY_X = {-77, 195}
  G.DOTS_LOCS = {3407216458, 1377611504, 622567014, 3145665477, 1753514051, 790952595, 442049775, 1056264686,
    2946906320, 1437140403}              -- every _pos_page* / _pos_equip* / arrow locator of the copies
  G.M_DOT_OFF1, G.M_DOT_ON1 = 3784855471, 2540064569           -- _page01_off / _page01_on
  G.DOTS_HIDE = {2788701567, 2606243023, 695779551}            -- _page02..04_off
  G.hdl = G.hdl or nil
  G.rateInit = {}
  -- Equipamiento (type 0): the 4 items at 80 % (2 x 2 by the layout), the 5th (title) row hidden
  G.EQUIP = 2994084190                   -- soccer11_08_formation_chara_equip_item
  -- round 6: the content band (page copy body, sprite swapped), the bars' sprite, the arrows
  G.TX_T1101, G.SP_BODY = 3044635609, 228499307
  -- round 8: one fixed band (layout: x 985..1920, y 655..965) on these page types
  G.SP_BAND = @crc:evt_pp_band_fixed@
  G.BAND_ON = {[9] = true, [5] = true, [0] = true, [1] = true, [2] = true, [3] = true, [6] = true}
  -- round 7: 3D bars (faces: frame mesh = front, empty mesh = side, label mesh = top) and their sprites / slots
  -- 2026-10-13 (owner: «los colores sean dependiendo de las posiciones»): group g's gauge fill = its position tags'
  -- colours, two tags = two stripes (sprite evt_pp_gfill_<tags>: if_plate_row_build.py STAT_TAGS / gauge_fill_png;
  -- its --check verifies this table)
  G.STAT_FILL = {"fw", "fw_mf", "df_mf", "gk", "gk_df", "gk_df", "fw_mf", "all"}
  G.N_FRONT, G.N_SIDE, G.N_TOP = 1837325853, 2609329121, 1257514352   -- btl06_13 gauge copies: _hp_base01,
  -- _hp_empty01, _gtxt_stamina01
  -- round 7: the archetype icon's slanted box (evt_pp_tag: the gauge frame with evt_pp_slantbox), screen box
  G.TAG = @crc:evt_pp_tag@
  G.SP_SLANTBOX = @crc:evt_pp_slantbox@
  -- its box rect (single / dual archetype) and the box rule are the shared header row's (VRFW_UI.HeaderRow.ArchBox,
  -- [header_row.arch_box]); the sprites are this mod's: evt_pp_slantbox / _wide (round 12: a dual archetype shows its
  -- own wide sprite)
  G.SP_SLANTBOX2 = @crc:evt_pp_slantbox_wide@
  -- round 7: the «Configuración habitual» guide of the plate (retail build-type guide, IF retired the build types)
  G.BUILD_GUIDE = 634073741              -- mainmenu01_19_show_common_drop_chara_build_type_guide
  -- round 7: over the transfer office (its own model and description) none of ours
  G.SHOP_MENU = 3170360552               -- shop_menu
  -- round 7: SUPERTÉCNICAS 2 | 2 | 2
  G.SKILL, G.SKILL_BLANK = 1580043721, 3216046680                  -- soccer11_09 (+ _p1 blank) x 6
  G.SLOT_NODES = {1833019645, 4098423111, 2203044305}              -- _pos_slot01..03 (status base)
  G.SLOT_RETAIL = {{-18, -79}, {-18, -203}, {-18, -327}}
  G.SK_HIDE_MESH = {4282364172, 559600405, 1206374040, 148027488}   -- _cmd_base_sp01, _icon_sp_sub_dmy01,
  -- _gtxt_cmd_armed01, _sp_list_focus01
  G.SK_SHOW_MESH = {4282364172, 559600405, 148027488}
  G.SK_HIDE_NODE = {4081284803, 2244819350}                         -- _pos_at01, _pos_lock01
  G.SK_TEXT = 3359986143                 -- _text_sp01
  G.FOCUS_ACTIVE, G.FOCUS_IDX = 102308320, 2603265800
  G.TX_BTL0613, G.SP_FRAME, G.SP_BAR = 1191797350, 538967808, @crc:evt_pp_bar01@
  G.M_ARROWS = {1811606789, 2448805990}   -- _arrow01_l / _r
  G.EQUIP_SCALE = 0.72                   -- round 9: 409 px wide (inside the white card)
  -- Hiper page L3: the aura slot / the mix slot (EVT_PH_MX_VIEW of plate_hiper; was the keshin a miximax gave)
  G.L3 = {CHECK = 4265778440, CTRL = 1332654303, CTRL_AN = 2748927068, CMD = 579943758}
  G.frame, G.l3last = 0, -100
  -- every page title mesh of the status base (all hidden: Nacho, round 4)
  G.M_TITLES = {254458604, 2518936406, 301770119, 1621221814}   -- _gtxt_parameters01 / 02, _gtxt_teampassives01,
  -- _gtxt_sixthsense01 (also the Hiper / career title)
  -- the move-slot badges 1 / 2 / 3 (+ the rpg plate's): SUPERTÉCNICAS only
  G.M_SLOTS = {@crc:_cmd_slot01@, @crc:_cmd_slot02@, @crc:_cmd_slot03@, @crc:_cmd_slot01_rpg@, @crc:_cmd_slot02_rpg@,
    @crc:_cmd_slot03_rpg@}
  -- label group -> row (the layout's GROUP_ROW) and group -> stat (plate_hiper EVT_R9.STAT)
  G.GROUP_ROW = {0, 1, 3, 5, 6, 4, 2, 7}
  G.STAT = {0, 2, 5, 6, 4, 3, 1, 8}
  -- 2026-10-15: the position tags of a stat idx's row (G.STAT_FILL of its group: "fw", "mf", "df", "gk"; Suerte's
  -- "all" = the four), for other screens that name the positions a stat serves (the training view's header)
  function G.StatTags(stat)
    local tags = {}
    for g = 1, 8 do
      if G.STAT[g] == stat then
        for tag in string.gmatch(G.STAT_FILL[g], "[^_]+") do
          if tag == "all" then
            return {"gk", "df", "mf", "fw"}
          end
          tags[#tags + 1] = tag
        end
      end
    end
    return tags
  end
  local C = {EXIST = 262659071, OPEN = 629267548, IS_OPEN = 2640875187, LOADING = 3057768039, VIS = 711242136,
    IS_VIS = 1262717583, POS = 1389957207, SCALE = 3778714801, MESH = 3405944500, TRACE = 1774843228,
    RATE_INIT = 541357333, RATE = 1595998683, SPRITE = 558735651, TEXT_VIS = 1505208242, NODE_VIS = 2158717427,
    SET_TEXT = 1083631230, PRIM_VIS = 1233047821, NODE_POS = 2575768773, NODE_SCALE = 2885415772,
    CHARA = 1131797651,
    LOG = 3661580131}
  local G_X, G_Y, G_W, G_H = 94, -816, 476, 44          -- btl06_13 gauge frame _hp_base01
  local RATE_BAR, RATE_RED = 3060237847, 2546116024
  local MESH_LABEL, MESH_EMPTY = 1257514352, 2609329121
  local MESH_FRAME, MESH_FILL = 1837325853, 2043683848          -- _hp_base01, _hp_bar02
  G.ptype = G.ptype or nil
  G.vals = G.vals or nil
  G.ready = G.ready or {}
  G.busy = false

  --@lib evt_menu_kit.lua#Pack,Cmd

  local function On()
    return EVT_PLATE_PAGES == true
  end

  local function Exists(l)
    return Cmd(C.EXIST, l) == true
  end

  -- a layer this block opens: true once loaded
  local function Ready(l, k)
    if G.hostShut then
      return false                         -- 2026-10-06: the host menu is closing, nothing of ours (re)opened
    end
    if Cmd(C.IS_OPEN, l, k) ~= true then
      G.ready[l * 16 + k] = false
      Cmd(C.OPEN, l, k)
      return false
    end
    return Cmd(C.LOADING, l) ~= true
  end

  -- ---- the band copy -------------------------------------------------------------------------------------------
  local function BandSetup()
    Cmd(C.MESH, G.BAND, G.M_PAGE, false, 0)  -- round 5: no page body
    Cmd(C.MESH, G.BAND, G.M_PORTRAIT, false, 0)
    for _, m in ipairs(G.M_PARAM) do
      Cmd(C.MESH, G.BAND, m, false, 0)
    end
    Cmd(C.MESH, G.BAND, G.M_BAND, false, 0)  -- the band is evt_pp_slant's
  end

  function G.Band()
    if not Exists(G.BAND) or not Exists(G.PAGE) then
      return
    end
    local up = Cmd(C.IS_VIS, G.PAGE, 0) == true and Cmd(C.IS_OPEN, G.PAGE, 0) == true
    if not up then
      if Cmd(C.IS_OPEN, G.BAND, 0) == true then
        Cmd(C.VIS, G.BAND, 0, false)
      end
      return
    end
    -- 2026-10-06 (Nacho, shots 356 / 358 / 357: a stale white hex card under the description on PERFIL, «the floor»
    -- under the model, and an empty custom-passive page): since the page object moved to IF's layout copy with its
    -- own Texture row (766def893 / 1a711d006) the drawType-1 page draws its body _personal_plate01 (the retail white
    -- card) at the content band's rect on every page. The body is the band copy's alone (round 5: no page body):
    -- the page's own is hidden every frame.
    if EVT_PPG_PAGE_BODY ~= true then
      Cmd(C.MESH, G.PAGE, G.M_PAGE, false, 0)
    end
    if not Ready(G.BAND, 0) then
      return
    end
    if not G.ready[G.BAND * 16] then
      G.ready[G.BAND * 16] = true
      G.bandkey = nil
      Cmd(C.TRACE, G.PAGE, 0, G.BAND, true)
      BandSetup()
    end
    -- a host's own card rect (G.H.card = {x0, y0, x1, y1}, screen, y down): the band copy's body node placed and
    -- sized as the layout does (if_plate_row_build.py BAND_FIXED: pos (x0 - 1435, 560 - y0), scale (w, h));
    -- without it the copy keeps the layout's card (x 985..1920, y 705..955, the Plantilla page's)
    local cr = G.H.card
    if type(cr) == "table" then
      Cmd(C.NODE_POS, G.BAND, 0, G.M_PAGE, 0, cr[1] - 1435)
      Cmd(C.NODE_POS, G.BAND, 0, G.M_PAGE, 1, 560 - cr[2])
      Cmd(C.NODE_SCALE, G.BAND, 0, G.M_PAGE, cr[3] - cr[1], cr[4] - cr[2])
    end
    local desc = On() and G.ptype == EVT_PPG_DESC_TYPE
    -- round 7: the body only as the content band of the page (its own height), on the pages that use it
    local b = On() and G.ptype ~= nil and G.BAND_ON[G.ptype] == true and not G.InOffice()
    if G.bandkey ~= 1 then
      G.bandkey = 1
      Cmd(C.SPRITE, G.BAND, G.TX_T1101, G.SP_BAND, G.SP_BODY, 0, 0)
    end
    Cmd(C.MESH, G.BAND, G.M_PAGE, b, 0)
    Cmd(C.MESH, G.BAND, G.M_FLAVOR, desc or not On(), 0)
    Cmd(C.VIS, G.BAND, 0, true)
    -- 2026-10-12 (owner, «set de habilidades»: a translucent white rounded square under the archetype box): the
    -- retail portrait frame _icon_chr_status_base01 of the page (and of the header plate) is the miniface's backdrop;
    -- the row shows no miniface, so the frame goes too, every frame (the retail fill shows it again)
    Cmd(C.MESH, G.PAGE, G.M_PORTRAIT, false, 0)
    if Exists(G.PLATE) and Cmd(C.IS_OPEN, G.PLATE, 0) == true then
      Cmd(C.MESH, G.PLATE, G.M_PORTRAIT, false, 0)
    end
    -- the page's own band / box (not drawn in the drawType-1 pass anyway) and its radar plates stay off
    Cmd(C.MESH, G.PAGE, G.M_BAND, false, 0)
    Cmd(C.MESH, G.PAGE, G.M_FLAVOR, false, 0)
    for _, m in ipairs(G.M_PARAM) do
      Cmd(C.MESH, G.PAGE, m, false, 0)
    end
  end

  -- ---- the slanted band ---------------------------------------------------------------------------------------
  local function SlantRarityOff(inst)
    inst = inst or 0
    Cmd(C.MESH, G.SLANT, G.SLANT_RARITY, false, inst)
    Cmd(C.NODE_VIS, G.SLANT, G.SLANT_RARITY_NODE, false, inst)
    Cmd(C.NODE_SCALE, G.SLANT, inst, G.SLANT_RARITY, G.HIDDEN_SCALE, G.HIDDEN_SCALE)
  end

  -- an instance of the slant copy (re)opens: banner off and the copy hidden until G.Slant has filled it again
  function G.SlantOpened(inst)
    SlantRarityOff(inst)
    Cmd(C.VIS, G.SLANT, inst or 0, false)
    G.ready[G.SLANT * 16] = nil
  end

  local function SlantHide()
    VRFW_UI.HeaderRow.Band(G.SLANT, 0, {band = true})   -- round 7: its name box off (the slanted box is evt_pp_tag)
    SlantRarityOff()
    -- the header plate's own portrait too (its layout shrinks it to 1 %; the face icon may come back at its size)
    VRFW_UI.HeaderRow.PortraitOff(G.PLATE, 0)
    -- 2026-10-07 (Nacho, skill table: a translucent white square under the name banner): the host's own extra header
    -- nodes off screen too (G.H.plate_off, e.g. the empty portrait base / mark of the header plate)
    for _, nd in ipairs(G.H.plate_off or {}) do
      Cmd(C.NODE_POS, G.PLATE, 0, nd, 0, -5000)
    end
  end

  -- the player of the header plate on the slant copy (its rarity / position colours come with it)
  function G.SlantFill()
    if G.hdl == nil or not Exists(G.SLANT) or Cmd(C.IS_OPEN, G.SLANT, 0) ~= true
        or type(UpdateCharaStatusPlateInfoByCharaStHdl) ~= "function" or type(VRFW_UI) ~= "table" then
      return
    end
    -- round 9: the band's colour (the shared header row's band: fill, colour, strip). 2026-10-14 (owner): the
    -- retail rarity look; the position colour only from a mod that declares it (No More Rarities, host
    -- character_reforged.header_band): Character Reforged's CharacterReforged.Header.BandColour. Never the library's
    -- default colour service (it would paint the position colour without No More Rarities).
    local header = type(CharacterReforged) == "table" and CharacterReforged.Header or nil
    local colour = type(header) == "table" and header.BandColour or function() end
    G.busy = true
    VRFW_UI.HeaderRow.BandFill(G.SLANT, 0, G.hdl, {colour = colour})
    G.busy = false
    SlantHide()
  end

  function G.Slant()
    if not Exists(G.SLANT) or not Exists(G.PAGE) or type(VRFW_UI) ~= "table" then
      return
    end
    local up = Cmd(C.IS_VIS, G.PAGE, 0) == true and Cmd(C.IS_OPEN, G.PAGE, 0) == true
    if not up then
      if Cmd(C.IS_OPEN, G.SLANT, 0) == true then
        Cmd(C.VIS, G.SLANT, 0, false)
      end
      return
    end
    if not Ready(G.SLANT, 0) then
      return
    end
    if not G.ready[G.SLANT * 16] then
      G.ready[G.SLANT * 16] = true
      Cmd(C.TRACE, G.PAGE, 0, G.SLANT, true)
      VRFW_UI.HeaderRow.PlaceBand(G.SLANT, 0)               -- under the row at its layout place (scale 1)
      G.SlantFill()
      SlantHide()
    end
    SlantRarityOff()
    if G.hdl ~= nil then                     -- shown once it holds a player (never its retail default)
      Cmd(C.VIS, G.SLANT, 0, true)
    end
  end

  -- ---- 8 dots ---------------------------------------------------------------------------------------------------
  -- G.SlotPages() = {[dot slot] = page index} of the shown pages and G.Slot(type) = the slot of a page type, from the
  -- VR-Framework's player page registry (VRFW_PlayerPages, docs/framework/player-pages.md): slot = the page's place in
  -- the resolved order. A page that is not shown (its Enabled says no: the Hiper page while the option «Tabla de habilidades» is not on the new set) keeps its slot
  -- with the dot hidden and no click; a page that does not exist (Utilities' TRAYECTORIA without Utilities) has no
  -- slot. Slots past the layout's G.DOTS_MAX get no dot.
  function G.SlotPages()
    local P = VRFW_PlayerPages
    return P ~= nil and P.Slots() or {}
  end
  function G.Slot(ptype)
    local P = VRFW_PlayerPages
    return P ~= nil and P.SlotOfType(ptype) or nil
  end
  function G.Dots()
    if not On() or G.ptype == nil or not Exists(G.STATUS) then
      return
    end
    local lit = G.Slot(G.ptype)
    local pages = G.SlotPages()
    for i = 1, 6 do
      local on = pages[i] ~= nil
      Cmd(C.MESH, G.STATUS, G.DOT_OFF[i], on, 0)
      Cmd(C.MESH, G.STATUS, G.DOT_ON[i], on and lit == i, 0)
    end
    -- the row centred on the slots this page has: the layout spaces G.DOTS_MAX slots between the Q / E glyphs; with
    -- fewer (a screen that leaves pages out) the dots move right and both glyphs close in by half the unused width
    local used = 1
    for s in pairs(pages) do
      if type(s) == "number" and s > used then
        used = s
      end
    end
    local shift = (G.DOTS_MAX - math.min(used, G.DOTS_MAX)) * G.DOT_PITCH / 2
    local up = Cmd(C.IS_VIS, G.STATUS, 0) == true
    if not up then
      G.dotShift = nil                     -- a status base shown again starts from its layout
    elseif G.dotShift ~= shift then
      G.dotShift = shift
      for i = 1, 6 do
        local x = G.DOT_X[1] - (7 - i) * G.DOT_PITCH - 1358 + shift
        Cmd(C.NODE_POS, G.STATUS, 0, G.DOT_OFF[i], 0, x)
        Cmd(C.NODE_POS, G.STATUS, 0, G.DOT_ON[i], 0, x)
      end
      Cmd(C.NODE_POS, G.STATUS, 0, G.KEY_NODES[1], 0, G.KEY_X[1] + shift)
      Cmd(C.NODE_POS, G.STATUS, 0, G.KEY_NODES[2], 0, G.KEY_X[2] - shift)
      for k = 0, 1 do
        if Exists(G.DOTS) and G.ready[G.DOTS * 16 + k] and Cmd(C.IS_OPEN, G.DOTS, k) == true then
          Cmd(C.POS, G.DOTS, G.DOT_X[k + 1] + shift - 1362 - 1358, 540 + 34, 0, k)
        end
      end
    end
    if not Exists(G.DOTS) then
      return
    end
    local psub = up and G.ptype == 2 and not G.InOffice()
    for k = 2, 5 do
      if not psub then
        if Cmd(C.IS_OPEN, G.DOTS, k) == true then
          Cmd(C.VIS, G.DOTS, k, false)
        end
      elseif Ready(G.DOTS, k) then
        if not G.ready[G.DOTS * 16 + k] then
          G.ready[G.DOTS * 16 + k] = true
          Cmd(C.TRACE, G.STATUS, 0, G.DOT_TRACE[k], true)
          for _, n in ipairs(G.DOTS_LOCS) do
            Cmd(C.NODE_VIS, G.DOTS, n, false, k)
          end
          for _, m in ipairs(G.DOTS_HIDE) do
            Cmd(C.MESH, G.DOTS, m, false, k)
          end
          Cmd(C.TEXT_VIS, G.DOTS, 355816102, false, k)   -- _text_btn_l01
          local x = k == 5 and G.PSUB_KEY_X or G.PSUB_DOT_X[k]
          Cmd(C.POS, G.DOTS, x - 1362 - 1358, 540 + 34, 0, k)
          Cmd(C.TEXT_VIS, G.DOTS, G.N_BTN_R, false, k)   -- round 14b: the glyph is G.Hint's text node now
        end
        local dot = k ~= 5 and k - 2 < G.PSUB_N
        Cmd(C.MESH, G.DOTS, G.M_DOT_OFF1, dot, k)
        Cmd(C.MESH, G.DOTS, G.M_DOT_ON1, dot and (G.psub or 0) == k - 2, k)
        Cmd(C.VIS, G.DOTS, k, dot)
      end
    end
    for k = 0, 1 do
      if not up then
        if Cmd(C.IS_OPEN, G.DOTS, k) == true then
          Cmd(C.VIS, G.DOTS, k, false)
        end
      elseif Ready(G.DOTS, k) then
        if not G.ready[G.DOTS * 16 + k] then
          G.ready[G.DOTS * 16 + k] = true
          Cmd(C.TRACE, G.STATUS, 0, G.DOT_TRACE[k], true)
          for _, n in ipairs(G.DOTS_LOCS) do
            Cmd(C.NODE_VIS, G.DOTS, n, false, k)
          end
          for _, m in ipairs(G.DOTS_HIDE) do
            Cmd(C.MESH, G.DOTS, m, false, k)
          end
          Cmd(C.TEXT_VIS, G.DOTS, 355816102, false, k)   -- _text_btn_l01
          Cmd(C.TEXT_VIS, G.DOTS, 59628764, false, k)    -- _text_btn_r01
          -- copy's _page01_off at copy-local (1362, -949) from the status base root: onto slot 7 / 8 (y -949)
          Cmd(C.POS, G.DOTS, G.DOT_X[k + 1] + shift - 1362 - 1358, 540 + 34, 0, k)   -- round 12: y 915 (10 px up)
        end
        Cmd(C.MESH, G.DOTS, G.M_DOT_OFF1, true, k)
        Cmd(C.MESH, G.DOTS, G.M_DOT_ON1, lit == k + 7, k)
        Cmd(C.VIS, G.DOTS, k, pages[k + 7] ~= nil)
      end
    end
  end

  -- 2026-10-06 (Nacho: the office's «Ficha» showed only the header over the shop): the office opens THIS screen
  -- for a candidate in universe mode (a temp chara from the row's param / level / rarity, office_look
  -- EVT_OGridPlateOpen), and hides its own layers while it is up: that page is the full player page (pages,
  -- description, model, band). Only another plate over the shop (not universe mode) keeps the shop's look.
  function G.ViewMode()
    local ok, v = pcall(IsUniverseCharaMode)
    return ok and v == true
  end
  function G.InOffice()
    if type(funcLuaCommand) ~= "function" or G.ViewMode() then
      return false
    end
    local ok, v = pcall(funcLuaCommand, 264888438, G.SHOP_MENU)   -- CMND_IS_EXIST_MENU
    return ok and v == true
  end

  -- the archetype icon's slanted box
  function G.Tag()
    if not Exists(G.TAG) or not Exists(G.PAGE) or type(VRFW_UI) ~= "table" then
      return
    end
    local up = Cmd(C.IS_VIS, G.PAGE, 0) == true and Cmd(C.IS_OPEN, G.PAGE, 0) == true
    if not up then
      if Cmd(C.IS_OPEN, G.TAG, 0) == true then
        Cmd(C.VIS, G.TAG, 0, false)
      end
      return
    end
    if not Ready(G.TAG, 0) then
      return
    end
    if not G.ready[G.TAG * 16] then
      G.ready[G.TAG * 16] = true
      G.tagSt = {}
      Cmd(C.TRACE, G.PAGE, 0, G.TAG, true)
      VRFW_UI.HeaderRow.ArchBoxSetup(G.TAG, {sprite = G.SP_SLANTBOX})
    end
    -- 2026-10-12 / 13 (owner): the slanted box is the archetype glyph's backdrop: shown exactly while the header's
    -- glyph is shown at home (the shared header row's rule, VRFW_UI.HeaderRow.ArchBoxShown: the glyph visibility the
    -- fills last set, whoever drew it; a staff role glyph moved into the position slot leaves no box). Round 10: a dual
    -- archetype (passive_config draws the second glyph on _icon_lock_status01) gets the wide box.
    VRFW_UI.HeaderRow.ArchBox(G.TAG, G.PLATE, 0, G.hdl, G.tagSt or {}, {sprite = G.SP_SLANTBOX,
      sprite_dual = G.SP_SLANTBOX2, dual_cmd = type(UTIL_PCI) == "table" and UTIL_PCI.CMD_INFO or nil})
  end

  -- ---- SUPERTÉCNICAS: 2 | 2 | 2, icons only, the focused move's plate under the groups ----------------------------
  -- round 9 (Nacho): two columns of slot groups, every move plate visible (name, AT / DF, icons), compact:
  --   1 | move A      2 | move C
  --     | move B        | move D
  --   3 | move E
  --     | move F
  -- group k top-left (screen) GROUP_AT[k]; badge (status base _cmd_slot0k on its node _pos_slot0k) 60 x 80; the two
  -- move rows (soccer11_09, attached at _atc_slot0k_sp01 / 02 = _pos_slot0k + (302, +-31)) at MOVE_K scale, stacked
  -- right of the badge. Retail positions back on every other page.
  -- round 10 (Nacho): ONE row of three groups (badge + its two plates stacked) inside the card; plates at 48 %
  -- (253 x 36: the names get small, the trade-off Nacho accepted to try)
  -- round 16 (Nacho, 2026-10-15: «los de 1 en una fila, los de 2 en la siguiente...»): THREE ROWS, one per slot pair:
  --   [1] move A  move B
  --   [2] move C  move D
  --   [3] move E  move F
  -- badge at the row's left, the pair's two plates side by side (PLATE_DX2 apart) at 68 % (358 x 51); IA tag and AT
  -- number scale with the plate (same row scale)
  G.GROUP_AT = {{995, 732}, {995, 789}, {995, 846}}
  G.MOVE_K = 0.68
  -- round 17 (Nacho: badges 10-15 px low, bracket lines running into the next row, too close to the panel edge): the
  -- badge is 36 x 46 (its bracket lines now end inside the 51 px bar row), its node sits BADGE_CY below the row top
  -- (mesh centre = node, measured: it sat 10 px low at the old y 6 + 29) and its left edge at BADGE_X (8 px before the bars)
  G.BADGE = {36, 46}
  G.BADGE_X, G.BADGE_CY = 1004, 25
  G.PLATE_DX, G.PLATE_DX2 = 52, 385
  G.M_BADGE = {4182803106, 1616499480, 392094606}               -- _cmd_slot01..03
  G.SK_AT_DMY = 365666709                -- _num_at_cmd_dmy01 (the AT number's placeholder quad: the white square)
  G.GRAPH_NUM = 732343773                -- soccer11_06_p1_formation_status_graph_param_num
  function G.Moves()
    if not Exists(G.SKILL) or not Exists(G.STATUS) then
      return
    end
    local mine = On() and G.ptype == 1
    if not mine then
      if G.movesOn then
        G.movesOn = false
        for k = 1, 3 do
          Cmd(C.NODE_POS, G.STATUS, 0, G.SLOT_NODES[k], 0, G.SLOT_RETAIL[k][1])
          Cmd(C.NODE_POS, G.STATUS, 0, G.SLOT_NODES[k], 1, G.SLOT_RETAIL[k][2])
          Cmd(C.NODE_SCALE, G.STATUS, 0, G.M_BADGE[k], 64, 84)
          Cmd(C.NODE_POS, G.STATUS, 0, G.M_BADGE[k], 1, 42)
        end
        for i = 0, 5 do
          for _, l in ipairs({G.SKILL, G.SKILL_BLANK}) do
            if Exists(l) and Cmd(C.IS_OPEN, l, i) == true then
              Cmd(C.POS, l, 0, 0, 0, i)
              Cmd(C.SCALE, l, 1, 1, 1, i)
            end
          end
        end
      end
      return
    end
    if not G.movesOn then                  -- round 8 / earlier states undone once
      for i = 0, 5 do
        if Cmd(C.IS_OPEN, G.SKILL, i) == true then
          Cmd(C.NODE_POS, G.SKILL, i, G.SK_HIDE_NODE[1], 0, 0)
          Cmd(C.NODE_POS, G.SKILL, i, G.SK_HIDE_NODE[2], 0, 203)
          Cmd(C.TEXT_VIS, G.SKILL, G.SK_TEXT, true, i)
          Cmd(C.MESH, G.SKILL, G.SK_HIDE_MESH[1], true, i)
        end
      end
    end
    G.movesOn = true
    local s = G.MOVE_K
    for k = 1, 3 do
      local gx, gy = G.GROUP_AT[k][1], G.GROUP_AT[k][2]
      -- badge: node at (X0, Y0) world, the mesh's top-left at node + (0, 40) after its scale (60 x 80)
      local X0, Y0 = G.BADGE_X, -(gy + G.BADGE_CY)
      Cmd(C.NODE_POS, G.STATUS, 0, G.SLOT_NODES[k], 0, X0 - 1358)
      Cmd(C.NODE_POS, G.STATUS, 0, G.SLOT_NODES[k], 1, Y0 + 540)
      Cmd(C.NODE_SCALE, G.STATUS, 0, G.M_BADGE[k], G.BADGE[1], G.BADGE[2])
      Cmd(C.NODE_POS, G.STATUS, 0, G.M_BADGE[k], 1, G.BADGE[2] / 2)
      for j = 0, 1 do
        local i = (k - 1) * 2 + j
        local Ax, Ay = X0 + 302, Y0 + (j == 0 and 31 or -31)        -- the row's attach locator (world, y up)
        local tx, ty = gx + G.PLATE_DX + G.PLATE_DX2 * j, -(gy + 2)   -- the plate's top-left (world, y up)
        local px, py = tx - Ax - s * (-267), ty - Ay - s * 34
        for _, l in ipairs({G.SKILL, G.SKILL_BLANK}) do
          if Exists(l) and Cmd(C.IS_OPEN, l, i) == true then
            Cmd(C.SCALE, l, s, s, 1, i)
            Cmd(C.POS, l, px, py, 0, i)
          end
        end
        if Cmd(C.IS_OPEN, G.SKILL, i) == true then
          Cmd(C.MESH, G.SKILL, G.SK_AT_DMY, false, i)
        end
      end
    end
    -- the move-detail mode (N) re-shows the radar layers: off again on this page
    if Cmd(C.IS_VIS, G.GRAPH, 0) == true then
      pcall(SetVisibleGraphLayer, false)
      if type(EVT_R9) == "table" and type(EVT_R9.Visible) == "function" then
        pcall(EVT_R9.Visible, false)
      end
    end
    if type(G.BarsVisible) == "function" then
      G.BarsVisible(false)
    end
  end

  -- ---- SUPERTÉCNICAS «Confirmación de supertécnica» navigation (2026-10-15, owner: the D-pad follows the 3-row page) --
  -- The engine's focus links of the move layer follow the retail column (up / down inside a pair, left / right between
  -- pairs). On this page (rows = pairs: instance 2r = left plate, 2r + 1 = right plate) a D-pad / arrow / stick step
  -- goes where the page shows it: LEFT / RIGHT = the other plate of the same row, UP / DOWN = the row above / below in
  -- the same column (the other column when that plate is empty, empty rows skipped). Stops at the edges (no wrap).
  -- Empty plates are never focused by a key (Aceptar / X do nothing on them, retail OnEnterCommon). The engine's own
  -- step is redirected inside OnChangeFocus (before that frame is drawn); a step the engine does not make (an edge of
  -- the old links) is made from the frame hook on the next frame. The pointer is the engine's: its zones follow the
  -- moved plates (instance transform); with the Fantasy rows a zone is on only where the row shows a move.
  -- The engine calls OnChangeFocus(layer, direction token) after a key step (retail soccer_formation_menu_inc
  -- GetFocusDirType: the token is the direction, the new instance is the layer's focused index), so the step's
  -- direction is read from that token; the input state is only a fallback for a call without a known token.
  G.NAV = {CHECK_INPUT = 4265778440, MENU_CTRL = 1332654303, MENU_CTRL_ANALOG = 2748927068,
    UP = 1197218715, DOWN = 3259546669, LEFT = 2765147006, RIGHT = 2075023265,
    FOCUS_MARK = 1778826357, FOCUS_SET = 3466097042, PLAY_ANIME = 3781155141, FOCUS_ANIME = 2734777837,
    ANIME_KIND = 973515837, ZONE = 855005857, GET_SKILL = 903078840, SOUND = 1917805374, CURSOR_SOUND = 2500047763,
    GHOST_FRAMES = 3, COLUMNS = 2, ROWS = 3,
    -- OnChangeFocus direction tokens (retail GetFocusDirType / rpg_team_dock_menu_inc GetForcusDir: 1 up, 2 down,
    -- 3 left, 4 right; the second token of each pair is the analog stick's)
    DIRECTION_TOKENS = {[3483715641] = "up", [906909014] = "up", [49409691] = "down", [2207386753] = "down",
      [1684642248] = "left", [3842669522] = "left", [1644353666] = "right", [2682339866] = "right"}}
  G.nav = {index = nil, pending = nil, handled = false, busy = false, echo = false, lastDir = nil, ghost = nil,
    expect = nil}

  -- the move layer holds the control focus on SUPERTÉCNICAS of the player page (the confirmation mode)
  function G.NavActive()
    return G.H.pages and On() and G.ptype == 1 and Exists(G.SKILL) and Cmd(G.FOCUS_ACTIVE, G.SKILL) == true
  end

  -- the direction stepped this frame: "up", "down", "left", "right" or nil
  function G.NavDirection()
    local N = G.NAV
    for _, d in ipairs({{"up", N.UP}, {"down", N.DOWN}, {"left", N.LEFT}, {"right", N.RIGHT}}) do
      for _, control in ipairs({N.MENU_CTRL, N.MENU_CTRL_ANALOG}) do
        local ok, on = pcall(funcLuaCommand, N.CHECK_INPUT, control, d[2])
        if ok and on == true then
          return d[1]
        end
      end
    end
    return nil
  end

  -- instance i shows a move (the Fantasy row's own move when the rows were filled from the skill table)
  function G.NavFilled(i)
    if i < 0 or i >= G.NAV.COLUMNS * G.NAV.ROWS or Cmd(C.IS_OPEN, G.SKILL, i) ~= true then
      return false
    end
    local F = EVT_PPG_FANTASY_MOVES
    if type(F) == "table" and type(F.On) == "function" and type(F.shown) == "table" and F.shown[i] ~= nil and F.On() then
      return F.shown[i].move ~= 0
    end
    if type(GetPersonalPlateSelectCharaStHdlAuto) ~= "function" then
      return true
    end
    local okH, hdl = pcall(GetPersonalPlateSelectCharaStHdlAuto)
    if not okH or type(hdl) ~= "number" or hdl == 0 then
      return true
    end
    local okS, move = pcall(funcLuaCommand, G.NAV.GET_SKILL, hdl, i)
    return okS and move ~= nil and move ~= 0
  end

  -- the instance a step `dir` from instance `from` lands on (from itself at an edge)
  -- (grid of NAV.ROWS x NAV.COLUMNS, instance = row * COLUMNS + column: G.Moves' placement). LEFT / RIGHT: the
  -- nearest filled plate of the same row in that direction; UP / DOWN: the nearest row in that direction with a filled
  -- plate, the same column first, else the filled plate of that row closest to the column (the left one on a tie)
  function G.NavTarget(from, dir)
    local columns, rows = G.NAV.COLUMNS, G.NAV.ROWS
    local row, column = math.floor(from / columns), from % columns
    if dir == "left" or dir == "right" then
      local step = dir == "left" and -1 or 1
      local c = column + step
      while c >= 0 and c < columns do
        if G.NavFilled(row * columns + c) then
          return row * columns + c
        end
        c = c + step
      end
      return from
    end
    local step = dir == "up" and -1 or 1
    local r = row + step
    while r >= 0 and r < rows do
      for distance = 0, columns - 1 do
        for _, c in ipairs({column - distance, column + distance}) do
          if c >= 0 and c < columns and G.NavFilled(r * columns + c) then
            return r * columns + c
          end
        end
      end
      r = r + step
    end
    return from
  end

  -- the focus frame off on an instance that no longer holds the focus
  function G.NavUnfocus(i)
    local N = G.NAV
    Cmd(N.PLAY_ANIME, G.SKILL, i, N.FOCUS_ANIME, 2, N.ANIME_KIND)
  end

  -- the focus to instance `to` (left: the instance the engine had put it on): the retail mark, the engine's index,
  -- then the screen's OnChangeFocus (by the engine's echo, else here) for the detail window, cursor and guide
  function G.NavSetFocus(to, left)
    local N, S = G.NAV, G.nav
    S.busy, S.echo = true, false
    Cmd(N.FOCUS_MARK, G.SKILL, to, true)
    if Cmd(G.FOCUS_IDX, G.SKILL) ~= to then
      Cmd(N.FOCUS_SET, G.SKILL, to)
    end
    if not S.echo and type(OnChangeFocus) == "function" then
      pcall(OnChangeFocus, G.SKILL, to)
    end
    S.busy = false
    if left ~= nil and left ~= to then
      G.NavUnfocus(left)
      S.ghost = {left, N.GHOST_FRAMES}
    end
    S.index = to
  end

  -- OnChangeFocus of the move layer: a key step of the engine is redirected to this page's target; true = handled
  function G.NavOnChange(layer, token)
    local S = G.nav
    if S.busy then
      S.echo = true
      return false
    end
    if layer ~= G.SKILL or not G.NavActive() then
      return false
    end
    local index = Cmd(G.FOCUS_IDX, G.SKILL)       -- the instance the engine moved the focus to
    local dir = G.NAV.DIRECTION_TOKENS[token]
    if dir == nil then
      dir = G.NavDirection()
    end
    if dir == nil or S.index == nil or type(index) ~= "number" then
      S.index = type(index) == "number" and index or nil   -- the pointer or the screen moved it
      S.pending, S.expect = nil, nil
      return false
    end
    local target = G.NavTarget(S.index, dir)
    S.pending, S.handled = nil, true
    if target == index then
      S.index, S.expect = index, nil
      return false
    end
    G.NavSetFocus(target, index)
    S.expect = target
    return true
  end

  -- per frame: a step the engine did not make (pending since the last frame) is made here; new steps are noted
  function G.MovesNav()
    local S = G.nav
    if S.ghost ~= nil then
      local g = S.ghost
      g[2] = g[2] - 1
      if g[2] <= 0 then
        S.ghost = nil
      end
      if Cmd(G.FOCUS_IDX, G.SKILL) ~= g[1] then
        G.NavUnfocus(g[1])
      else
        S.ghost = nil
      end
    end
    if not G.NavActive() then
      S.index, S.pending, S.handled, S.lastDir, S.expect = nil, nil, false, nil, nil
      return
    end
    local current = Cmd(G.FOCUS_IDX, G.SKILL)
    if type(current) ~= "number" then
      return
    end
    local dir = G.NavDirection()
    local lastDir = S.lastDir
    S.lastDir = dir
    if S.handled then
      -- a redirected step the engine put back on its own target after OnChangeFocus: set once more
      local expect = S.expect
      S.handled, S.pending, S.expect = false, nil, nil
      if expect ~= nil and current ~= expect then
        G.NavSetFocus(expect, current)
        current = expect
      end
      S.index = current
      return
    end
    local p = S.pending
    S.pending = nil
    if p ~= nil and current == p.from then
      local target = G.NavTarget(p.from, p.dir)
      if target ~= current then
        G.NavSetFocus(target, current)
        pcall(funcLuaCommand, G.NAV.SOUND, G.NAV.CURSOR_SOUND)
        current = target
      end
    end
    S.index = current
    if dir ~= nil and dir ~= lastDir then
      S.pending = {from = current, dir = dir}
    end
  end

  -- the pointer zones of the move plates on the Fantasy rows: on where the row shows a move (the retail code reads
  -- the list position of the same index)
  function G.NavZones()
    local F = EVT_PPG_FANTASY_MOVES
    if not G.H.pages or not On() or G.ptype ~= 1 or not Exists(G.SKILL) or type(F) ~= "table"
        or type(F.On) ~= "function" or type(F.shown) ~= "table" or not F.On() then
      return
    end
    for i = 0, 5 do
      local shown = F.shown[i]
      if shown ~= nil and Cmd(C.IS_OPEN, G.SKILL, i) == true then
        Cmd(G.NAV.ZONE, G.SKILL, i, shown.move ~= 0)
      end
    end
  end

  -- ---- Pasivas (round 9): a row of 5 icon tiles (layout: icons at x 1172..1732, y 880); each strip collapsed to its
  -- icon on its own plate (orange special / blue, passive_config's tint) squashed into a slanted tile; R3 = cursor
  -- mode (left / right, R3 or B leaves): the focused passive opens as its whole strip ABOVE the row (y 770)
  G.PR = 811691761                       -- soccer11_20_formation_team_passive
  G.PR_PLATE, G.PR_OL = 3143733656, {2061463723, 3822461201}   -- _passive_base01, _ol01 / _ol02
  G.PR_TEXT = 1868134834                 -- _text_passive01
  G.PR_NODES = {3453619769, 2497436533}            -- _pos_type01, _pos_position01 (round 10: _pos_build01 never:
  -- its two retail build icons are the white boxes)
  G.PR_BUILD, G.PR_ICONBASE = 3448691050, 3877027080                -- _pos_build01, _teambuff_base01
  G.PT = @crc:evt_pp_ptile@
  G.PT_TRACE = {[0] = @crc:evt_pp_ptile0@, @crc:evt_pp_ptile1@, @crc:evt_pp_ptile2@, @crc:evt_pp_ptile3@, @crc:evt_pp_ptile4@}
  G.PT_SPRITE = {[0] = @crc:evt_pp_tile_orange@, @crc:evt_pp_tile_grey@, @crc:evt_pp_tile_grey@, @crc:evt_pp_tile_blue@,
    @crc:evt_pp_tile_blue@}                  -- special orange, general grey, archetype blue
  G.PT_W, G.PT_H = 90, 54               -- round 12: small tiles (if_plate_row_build.py TILE_TOP 48 + slant 42, 54 high)
  G.PT_SPRITE_HL = {[0] = @crc:evt_pp_tile_orange_hl@, @crc:evt_pp_tile_grey_hl@, @crc:evt_pp_tile_grey_hl@,
    @crc:evt_pp_tile_blue_hl@, @crc:evt_pp_tile_blue_hl@}    -- the focused passive's tile (white rim)
  G.ptHl = {}
  G.PR_EF = @crc:_build_ef01@                 -- _build_ef01 (a build effect quad over the icon)
  G.PR_INHERIT = 27565530
  G.PR_TILE = {-371, 40, 96, 80}         -- collapsed plate node (x, y top, w, h; layer units, icon centre -323, 0)
  G.PR_FULL = {-414, 46, 828, 92}
  G.PR_TEXT_BOX = {622, 72}              -- the text node's retail box (width, height; left edge -243)
  G.PR_TAB_Y = 770
  G.pcur = G.pcur or nil                 -- focused passive (cursor mode) or nil
  G.pexit = 0
  G.PARENTS = {935586083, 2049316981, 937147172}   -- team_dock_formation_menu, soccer_formation_menu, soccer_team_dock
  function G.ParentCursor(on)
    for _, m in ipairs(G.PARENTS) do
      pcall(funcLuaCommand, 830228314, m, "EVT_PPG_SetCursor", on)
    end
  end

  -- the slanted tile behind passive i's icon (screen: centred on the icon at (1172 + 140 i, 880))
  function G.Tile(i, on, hl)
    if not Exists(G.PT) then
      return
    end
    if not on then
      if Cmd(C.IS_OPEN, G.PT, i) == true then
        Cmd(C.VIS, G.PT, i, false)
      end
      return
    end
    if not Ready(G.PT, i) then
      return
    end
    if not G.ready[G.PT * 16 + i] then
      G.ready[G.PT * 16 + i] = true
      Cmd(C.TRACE, G.PAGE, 0, G.PT_TRACE[i], true)
      for _, m in ipairs({G.N_TOP, G.N_SIDE, 2043683848}) do
        Cmd(C.MESH, G.PT, m, false, i)
      end
      G.ptHl[i] = false
      Cmd(C.SPRITE, G.PT, G.TX_BTL0613, G.PT_SPRITE[i], G.SP_FRAME, 0, i)
      local sx, sy = G.PT_W / 476, G.PT_H / 44
      local x, y = 1172 + 140 * i - G.PT_W / 2, 880 - G.PT_H / 2
      Cmd(C.SCALE, G.PT, sx, sy, 1, i)
      Cmd(C.POS, G.PT, x - 94 * sx, -y + 816 * sy, 0, i)
    end
    if G.ptHl[i] ~= (hl == true) then
      G.ptHl[i] = hl == true
      Cmd(C.SPRITE, G.PT, G.TX_BTL0613, hl and G.PT_SPRITE_HL[i] or G.PT_SPRITE[i], G.SP_FRAME, 0, i)
    end
    Cmd(C.VIS, G.PT, i, true)
  end

  -- ---- Pasivas in 2 sub-pages, R3 (CMD_FUNC6) = next sub-page (1 -> 2 -> 1):
  --   1 = the first three passives (slots 0, 1, 2), 2 = the two archetype ones (slots 3, 4).
  -- Each sub-page shows its passives as WHOLE strips (icon, name, description = the detail) centred in the card, one
  -- under the other; the other strips hidden. Three strips are drawn smaller (G.PSUB_SCALE, around each strip's
  -- centre) so they fit the card. Kept: the passive's own icon always, no white boxes (_pos_type01 /
  -- _pos_position01 / _pos_build01 / _build_ef01 hidden).
  G.PSUB = {[0] = {0, 1, 2}, {3, 4}}
  G.PSUB_N = 2                                       -- sub-page count (dots, R3 / click cycle)
  G.PSUB_Y = {[1] = {815}, [2] = {770, 862}, [3] = {742, 808, 874}}   -- strip centre rows (screen y) per strip count
  G.PSUB_SCALE = {[3] = 0.7}                         -- strip scale per strip count (default 1)
  G.PSUB_WIDE = {[3] = 790}                          -- strip screen width per strip count (default: the plate's own
                                                     -- width x scale): three strips are wide so each text fits one line
  G.PSUB_X = 1452                                    -- strip centre (screen x)
  G.PSUB_KEYS = {[0] = @crc:evt_pp_psub_2@, @crc:evt_pp_psub_3@}
  G.PSUB_TXT = {[0] = "Generales", "Arquetipo"}
  G.SP_TILE_EMPTY = @crc:evt_pp_tile_empty@
  G.EMPTY_BOX = {600, 66}                            -- the empty special's box (screen px)
  G.psub = G.psub or 0
  if G.psub >= G.PSUB_N then
    G.psub = 0
  end
  G.noSpecial = false
  -- round 13 (Nacho): the special passive's title («Limitador activo», CMND_BETTERQOL_PC_SPECIAL's text key) on a pill
  -- (layer evt_pp_ptitle, object evt_ph_peg_pill) centred over the special's strip on sub-page 1, tinted the special
  -- orange; no special (the empty box) = no title. Page frame: local (x, -y) = screen (x, y) (pill centred on origin).
  G.PTITLE = @crc:evt_pp_ptitle@
  -- round 14 (Nacho: a title with a line under it, not a pill): the pill mesh hidden, the text in the special's
  -- dark orange, its box's left edge on the strip's left edge (G.PTITLE_X), a thin orange rule (gauge copy
  -- evt_pp_ptrule) the strip's width under it; the text from menu_text evt_pp_<title key> (per language: the loader's
  -- own text command answered English), the loader's text as the fallback
  G.PTITLE_K, G.PTITLE_DY = 0.8, 66          -- text scale; its centre this far above the strip's centre
  G.PTITLE_X = 1038                          -- the strip's left edge (screen x); the text box (330 x 0.8) starts here
  G.PTITLE_BOX = 330 * 0.8
  G.PTITLE_RGB = {0.80, 0.30, 0.04}
  G.PTRULE, G.SP_PTRULE = @crc:evt_pp_ptrule@, @crc:evt_pp_ptrule@
  G.PTRULE_R = {1038, 772, 1866, 775}        -- the rule's screen rect (3 px, over the strip's top)
  G.CMD_SPECIAL, G.CMD_TEXT = @crc:CMND_BETTERQOL_PC_SPECIAL@, @crc:CMND_VRFW_TEXT_GET@

  -- how far the slot-0 strip's top sits below a lone strip's top on sub-page 1 (title and rule move with it)
  function G.PTitleDy()
    local n = #G.PSUB[0]
    local k = G.PSUB_SCALE[n] or 1
    return (G.PSUB_Y[n][1] - 46 * k) - (G.PSUB_Y[1][1] - 46)
  end

  function G.PTitle(on)
    local T = G.PTITLE
    if not Exists(T) then
      return
    end
    local text = ""
    if on and G.hdl ~= nil then
      local ok, yes, key = pcall(funcLuaCommand, G.CMD_SPECIAL, G.hdl)
      if ok and yes == true and type(key) == "string" and key ~= "" then
        local id = "evt_pp_" .. string.gsub(key, "^inazuma_fantasy%.", "")
        local okm, tm = pcall(funcLuaCommand, 4074371074 --[[CMND_TEXT_GET]], CALC_CRC(id))
        if okm and type(tm) == "string" and tm ~= "" then
          text = tm
        else
          local okt, t = pcall(funcLuaCommand, G.CMD_TEXT, key)
          text = (okt and type(t) == "string") and t or ""
        end
      end
    end
    if text == "" then
      if Cmd(C.IS_OPEN, T, 0) == true then
        Cmd(C.VIS, T, 0, false)
      end
      if Exists(G.PTRULE) and Cmd(C.IS_OPEN, G.PTRULE, 0) == true then
        Cmd(C.VIS, G.PTRULE, 0, false)
      end
      G.ptitleText = nil
      return
    end
    if Exists(G.PTRULE) and Ready(G.PTRULE, 0) then
      local l = G.PTRULE
      if not G.ready[l * 16] then
        G.ready[l * 16] = true
        Cmd(C.TRACE, G.PAGE, 0, l, true)
        for _, m in ipairs({G.N_TOP, G.N_SIDE, 2043683848}) do
          Cmd(C.MESH, l, m, false, 0)
        end
        Cmd(C.SPRITE, l, G.TX_BTL0613, G.SP_PTRULE, G.SP_FRAME, 0, 0)
      end
      local r, dy = G.PTRULE_R, G.PTitleDy()
      local sx, sy = (r[3] - r[1]) / 476, (r[4] - r[2]) / 44
      Cmd(C.SCALE, l, sx, sy, 1, 0)
      Cmd(C.POS, l, r[1] - 94 * sx, -(r[2] + dy) + 816 * sy, 0, 0)
      Cmd(C.VIS, l, 0, true)
    end
    if not Ready(T, 0) then
      return
    end
    if not G.ready[T * 16] then
      G.ready[T * 16] = true
      Cmd(C.TRACE, G.PAGE, 0, T, true)
      Cmd(C.SCALE, T, G.PTITLE_K, G.PTITLE_K, 1, 0)
      Cmd(C.MESH, T, 3516146179 --[[_area_base01: the pill]], false, 0)
      pcall(funcLuaMenuCommand, 855211291 --[[CMND_SET_PRIM_COLOR]], T, 0, 1899787537 --[[_text_area01]],
        G.PTITLE_RGB[1], G.PTITLE_RGB[2], G.PTITLE_RGB[3])
    end
    Cmd(C.POS, T, G.PTITLE_X + G.PTITLE_BOX / 2, -(G.PSUB_Y[1][1] + G.PTitleDy() - G.PTITLE_DY), 0, 0)
    if G.ptitleText ~= text then
      G.ptitleText = text
      -- round 14g (in game: white on the card): red through the game's own text markup [CR] … [C]
      -- (font_color.cfg.bin colour «R»: the colour of the descriptions' negative values)
      Cmd(C.SET_TEXT, T, 1899787537 --[[_text_area01]], "[CR]" .. text .. "[C]", 0)
      Cmd(2735666188 --[[text visible]], T, 1899787537, true, 0)
    end
    Cmd(C.VIS, T, 0, true)
  end

  function G.PsubLabel()
    local okt, t = pcall(funcLuaCommand, 4074371074 --[[CMND_TEXT_GET]], G.PSUB_KEYS[G.psub])
    if not okt or type(t) ~= "string" or t == "" then
      t = G.PSUB_TXT[G.psub]
    end
    return string.format("<CMD_FUNC6> %s  %d/%d", t, G.psub + 1, G.PSUB_N)
  end

  -- the empty special passive's box (tile layer instance 0, light orange), centred where its strip would be
  function G.EmptyBox(on)
    if not Exists(G.PT) then
      return
    end
    if not on then
      if G.emptyOn then
        G.emptyOn = false
        if Cmd(C.IS_OPEN, G.PT, 0) == true then
          Cmd(C.VIS, G.PT, 0, false)
        end
      end
      return
    end
    if not Ready(G.PT, 0) then
      return
    end
    if not G.emptyOn then
      G.emptyOn = true
      Cmd(C.TRACE, G.PAGE, 0, G.PT_TRACE[0], true)
      for _, m in ipairs({G.N_TOP, G.N_SIDE, 2043683848}) do
        Cmd(C.MESH, G.PT, m, false, 0)
      end
      Cmd(C.SPRITE, G.PT, G.TX_BTL0613, G.SP_TILE_EMPTY, G.SP_FRAME, 0, 0)
      local w, h = G.EMPTY_BOX[1], G.EMPTY_BOX[2]
      local sx, sy = w / 476, h / 44
      local x, y = G.PSUB_X - w / 2, G.PSUB_Y[1][1] - h / 2
      Cmd(C.SCALE, G.PT, sx, sy, 1, 0)
      Cmd(C.POS, G.PT, x - 94 * sx, -y + 816 * sy, 0, 0)
    end
    Cmd(C.VIS, G.PT, 0, true)
  end

  -- the strips' slanted plate (_passive_base01) pre-coloured by kind: the archetype passives (slots 3 / 4) light blue,
  -- every other one the retail white.
  -- CMND_SET_PRIM_COLOR never tints this quad, so the colour is in the pixels: sprite evt_pp_card_blue of the
  -- retail atlas soccer11_20, made at boot from the retail passive_base01 (content/images/menu/00_soccer/soccer11/
  -- evt_passive_plates.toml, no Level-5 pixel ships), swapped into the plate's texture slot (the sprite the retail row
  -- drawer put there) of each open instance every frame the page shows the rows; the retail sprite back when it leaves.
  G.CARD_TEX, G.CARD_SLOT = 4021797290 --[[soccer11_20.g4tx]], 1729678359 --[[passive_base01]]
  G.CARD_SPR = {[3] = @crc:evt_pp_card_blue@, [4] = @crc:evt_pp_card_blue@}
  G.cardOn = G.cardOn or {}
  function G.CardTint(L, i, on)
    local spr = on and G.CARD_SPR[i] or nil
    if spr ~= nil then
      G.cardOn[i] = true
      pcall(funcLuaMenuCommand, C.SPRITE, L, G.CARD_TEX, spr, G.CARD_SLOT, 0, i)
    elseif G.cardOn[i] then
      G.cardOn[i] = nil
      pcall(funcLuaMenuCommand, C.SPRITE, L, G.CARD_TEX, G.CARD_SLOT, G.CARD_SLOT, 0, i)
    end
  end

  function G.PassiveRows()
    local L = G.PR
    if not Exists(L) then
      return
    end
    local mine = On() and G.ptype == 2 and not G.InOffice()
    if not mine then
      if G.pcur ~= nil then
        G.pcur = nil
        G.ParentCursor(false)
      end
      G.EmptyBox(false)
      pcall(G.PTitle, false)
      if G.prOn then
        G.prOn = false
        for i = 0, 4 do
          if Cmd(C.IS_OPEN, L, i) == true then
            G.CardTint(L, i, false)
            local f = G.PR_FULL
            Cmd(C.NODE_POS, L, i, G.PR_PLATE, 0, f[1])
            Cmd(C.NODE_POS, L, i, G.PR_PLATE, 1, f[2])
            Cmd(C.NODE_SCALE, L, i, G.PR_PLATE, f[3], f[4])
            Cmd(C.NODE_SCALE, L, i, G.PR_TEXT, G.PR_TEXT_BOX[1], G.PR_TEXT_BOX[2])
            Cmd(C.MESH, L, G.PR_PLATE, true, i)
            Cmd(C.SCALE, L, 1, 1, 1, i)
            Cmd(C.POS, L, 0, 0, 0, i)
            Cmd(C.NODE_VIS, L, G.PR_TEXT, true, i)
            Cmd(C.TEXT_VIS, L, G.PR_TEXT, true, i)
            for _, n in ipairs(G.PR_NODES) do
              Cmd(C.NODE_VIS, L, n, true, i)
            end
          end
        end
      end
      return
    end
    G.prOn = true
    -- 2026-10-12 (owner, Utilities' passive configurator on this page: no blue frame on the selected passive, and the
    -- selected one could be on a hidden sub-page): while its session runs (UTIL_PPC.co, the focused row UTIL_PPC.slot)
    -- the sub-page is the one holding the focused row (the session's up / down walk all 5 rows; the sub-page follows,
    -- R3 does not change it), and the row's focus frame (_passive_base01_ol01, drawn by UTIL_PPC.Mark) is never hidden
    -- here: it is shown on that row every frame. Outside a session nothing changes.
    local sess = nil
    if type(UTIL_PPC) == "table" and UTIL_PPC.co ~= nil and type(UTIL_PPC.slot) == "number" and UTIL_PPC.slot >= 0 then
      sess = UTIL_PPC.slot
      local want = sess <= 2 and 0 or 1
      if G.psub ~= want then
        G.psub = want
      end
    end
    local shown = {}
    for _, i in ipairs(G.PSUB[G.psub]) do
      shown[#shown + 1] = i
    end
    local rows = G.PSUB_Y[math.max(1, #shown)]
    local scale = G.PSUB_SCALE[#shown] or 1
    local row = {}
    for n, i in ipairs(shown) do
      row[i] = rows[n]
    end
    for i = 0, 4 do
      if Cmd(C.IS_OPEN, L, i) == true then
        G.CardTint(L, i, true)
        local y = row[i]
        if y == nil then
          Cmd(C.VIS, L, i, false)
          if i == 0 then                   -- round 14: nothing of the special's strip under the empty box (a thin
            Cmd(C.MESH, L, G.PR_PLATE, false, i)   -- grey line showed at its bottom-left)
            Cmd(C.MESH, L, G.PR_ICONBASE, false, i)
            Cmd(C.MESH, L, G.PR_INHERIT, false, i)
            for _, m in ipairs(G.PR_OL) do
              Cmd(C.MESH, L, m, false, i)
            end
          end
        else
          local f = G.PR_FULL
          Cmd(C.NODE_POS, L, i, G.PR_PLATE, 0, f[1])
          Cmd(C.NODE_POS, L, i, G.PR_PLATE, 1, f[2])
          local wide = G.PSUB_WIDE[#shown]                -- widened strip: the plate and the text box grow to the
          local plateW = wide and wide / scale or f[3]    -- right of the icon (layout units), the layer shifts to re-centre
          Cmd(C.NODE_SCALE, L, i, G.PR_PLATE, plateW, f[4])
          Cmd(C.NODE_SCALE, L, i, G.PR_TEXT, G.PR_TEXT_BOX[1] + plateW - f[3], G.PR_TEXT_BOX[2])
          Cmd(C.MESH, L, G.PR_PLATE, true, i)
          Cmd(C.MESH, L, G.PR_ICONBASE, true, i)      -- round 12: the icon always
          Cmd(C.MESH, L, G.PR_EF, false, i)
          Cmd(C.NODE_VIS, L, G.PR_BUILD, false, i)
          for _, m in ipairs(G.PR_OL) do
            Cmd(C.MESH, L, m, i == sess and m == G.PR_OL[1], i)
          end
          Cmd(C.MESH, L, G.PR_INHERIT, false, i)
          Cmd(C.NODE_VIS, L, G.PR_TEXT, true, i)
          Cmd(C.TEXT_VIS, L, G.PR_TEXT, true, i)
          for _, n in ipairs(G.PR_NODES) do
            Cmd(C.NODE_VIS, L, n, false, i)              -- round 12: the white boxes
          end
          local ax = 1172 + 140 * i + 323                -- the strip's attach x (layout PASSIVE_X)
          Cmd(C.SCALE, L, scale, scale, 1, i)            -- around the attach point = the strip's centre
          local shiftX = (plateW - f[3]) / 2 * scale     -- the strip grows to the right: move it back to the centre
          Cmd(C.POS, L, G.PSUB_X - ax - shiftX, 880 - y, 0, i)
          Cmd(C.VIS, L, i, true)
        end
      end
    end
    G.EmptyBox(false)
    if G.noSpecial and Cmd(C.IS_OPEN, L, 0) == true then        -- the unfilled slot: no text on it
      Cmd(C.TEXT_VIS, L, G.PR_TEXT, false, 0)
    end
    pcall(G.PTitle, G.psub == 0 and not G.noSpecial)
    -- R3: the next sub-page
    local key = function(cmd)
      local ok1, a = pcall(funcLuaCommand, 4265778440, 1332654303, cmd)
      local ok2, b = pcall(funcLuaCommand, 4265778440, 2748927068, cmd)
      return (ok1 and a == true) or (ok2 and b == true)
    end
    G.ptick = (G.ptick or 0) + 1
    if G.ptick - (G.plast or -100) < 6 then
      return
    end
    if sess == nil and key(3147328756) then   -- CMD_FUNC6 (R3); in a session the selection picks the sub-page
      G.psub = (G.psub + 1) % G.PSUB_N
      G.plast = G.ptick
      pcall(funcLuaCommand, 1917805374, 2500047763)
    end
  end

  -- ---- the custom-passive page (six-sense panel, type 3) inside the white card --------------------------------
  -- round 12: the panel's own frame / focus / blank meshes hidden. Round 13 (Nacho: title white on white, the bar not
  -- drawn, the retail hexagon art over the card, the 2nd line into the dots): the status base's _sixth_base01 (the
  -- 700 x 464 decoration) hidden; the panel lifted SX_DY so icon + title sit on a slanted blue band and the
  -- description on a light slanted plate, both attached to the page (gauge copies evt_pp_sxbar / evt_pp_sxplate,
  -- page frame: local = (screen x, -screen y)) at the screen rects of if_plate_row_build.py SX_BAND / SX_PLATE
  G.SX = 3764752959                      -- team00_28_six_sense_detail_info
  G.SX_HIDE = {@crc:_sixth_win_base01@, @crc:_sixth_win_focus01@, @crc:_sixth_win_blank01@}
  G.SX_DECO = @crc:_sixth_base01@        -- status base: the six-sense page's decoration
  G.SXBAR, G.SP_SXBAR = @crc:evt_pp_sxbar@, @crc:evt_pp_sxbar@
  G.SXPLATE, G.SP_SXPLATE = @crc:evt_pp_sxplate@, @crc:evt_pp_sxplate@
  G.SX_DY = 70                           -- the panel this much higher (its title 718..782, text 806..876 on screen)
  G.SX_BAND = {1000, 718, 1860, 780}
  G.SX_PLATE = {1030, 790, 1890, 896}
  G.SX_PRIO = 322                        -- the panel over the band (321) and the plate (320)

  local function SxPiece(l, sp, r, prio)
    if not Exists(l) or not Ready(l, 0) then
      return
    end
    if not G.ready[l * 16] then
      G.ready[l * 16] = true
      Cmd(C.TRACE, G.PAGE, 0, l, true)
      for _, m in ipairs({G.N_TOP, G.N_SIDE, 2043683848}) do
        Cmd(C.MESH, l, m, false, 0)
      end
      Cmd(C.SPRITE, l, G.TX_BTL0613, sp, G.SP_FRAME, 0, 0)
      local sx, sy = (r[3] - r[1]) / 476, (r[4] - r[2]) / 44
      Cmd(C.SCALE, l, sx, sy, 1, 0)
      Cmd(C.POS, l, r[1] - 94 * sx, -r[2] + 816 * sy, 0, 0)
      pcall(funcLuaMenuCommand, 1491630496 --[[CMND_SET_DRAW_PRIORITY]], l, 0, prio, true)
    end
    Cmd(C.VIS, l, 0, true)
  end

  function G.Sixth()
    local mine = On() and G.ptype == 3 and not G.InOffice() and Exists(G.SX) and Cmd(C.IS_OPEN, G.SX, 0) == true
      and Cmd(C.IS_VIS, G.SX, 0) == true
    if not mine then
      if G.sxOn then
        G.sxOn = false
        G.sxLogged = false
        if Exists(G.SX) and Cmd(C.IS_OPEN, G.SX, 0) == true then
          for _, m in ipairs(G.SX_HIDE) do
            Cmd(C.MESH, G.SX, m, true, 0)
          end
          Cmd(C.POS, G.SX, 0, 0, 0, 0)
        end
      end
      for _, l in ipairs({G.SXBAR, G.SXPLATE}) do
        if Exists(l) and Cmd(C.IS_OPEN, l, 0) == true then
          Cmd(C.VIS, l, 0, false)
        end
      end
      return
    end
    if not G.sxOn then
      G.sxOn = true
      pcall(funcLuaMenuCommand, 1491630496, G.SX, 0, G.SX_PRIO, true)
      pcall(funcLuaCommand, C.LOG, "EVT_PPG sixth panel on")
    end
    for _, m in ipairs(G.SX_HIDE) do
      Cmd(C.MESH, G.SX, m, false, 0)
    end
    Cmd(C.MESH, G.STATUS, G.SX_DECO, false, 0)
    Cmd(C.POS, G.SX, 0, G.SX_DY, 0, 0)
    SxPiece(G.SXPLATE, G.SP_SXPLATE, G.SX_PLATE, G.SX_PRIO - 2)
    SxPiece(G.SXBAR, G.SP_SXBAR, G.SX_BAND, G.SX_PRIO - 1)
    -- 2026-10-06 (shot 357: the page empty): the state of every piece once per visit, «EVT_PPG sixth state»
    if not G.sxLogged then
      G.sxLogged = true
      local function St(l)
        return string.format("%s/%s/%s", tostring(Exists(l)), tostring(Cmd(C.IS_OPEN, l, 0)), tostring(Cmd(C.IS_VIS, l, 0)))
      end
      pcall(funcLuaCommand, C.LOG, "EVT_PPG sixth state", "panel " .. St(G.SX), "bar " .. St(G.SXBAR),
        "plate " .. St(G.SXPLATE), "band " .. St(G.BAND), "page " .. St(G.PAGE))
    end
  end

  -- ---- Pasivas: the special slot's strip (orange, empty) hidden when the player has no special passive ------------
  function G.Passives()
    local L = 811691761                    -- soccer11_20_formation_team_passive
    if not On() or G.ptype ~= 2 or G.hdl == nil or not Exists(L) or Cmd(C.IS_OPEN, L, 0) ~= true then
      return
    end
    local ok, has, pid = pcall(funcLuaCommand, 4081597673, G.hdl, 0, 0, false, false)   -- team passive info (slot 0)
    -- round 14 (Nacho): no special = the retail empty special strip itself (an unfilled slot: its plate, the empty
    -- icon square, no text), shown by PassiveRows like a filled one; no light-orange box
    G.noSpecial = ok and (has ~= true or type(pid) ~= "number" or pid == 0)
  end

  -- ---- Trayectoria (round 13, Nacho): 2 rows, each on a slanted band (gauge copies evt_pp_csband 0 / 1 attached to
  -- the page, the header / archetype box slant):
  --   row 1 = FICHADO | ORIGEN | PARTIDOS          row 2 = V-E-D · % | GOLES | GOLES/PART.
  --   (round 14, Nacho: 3 columns in both rows, goals only: no assists)
  -- Numbers from the career record CMND_BETTERQOL_CAREER_EX(chara, 0) (the mod Utilities') (goals v[9], assists v[10]: already tracked); the
  -- ratio is UTIL_CS.Ratio (decimal comma per language, «-» without matches). The career panel hangs from
  -- _atc_passive01 (screen (1495, 880)); its cell (r, c) default centre = (1204.5 + 195 c, 880 + 84 r): each kept cell
  -- moved (layer local pos, y up) to its centre CS_AT[r][c]; every other cell and the strips hidden.
  -- round 14c (Nacho): the bands 70 px in from each side and 18 px taller (72), the 3 columns centred in them
  G.CS_AT = {[0] = {{1190, 768}, {1450, 768}, {1710, 768}}, [1] = {{1190, 856}, {1450, 856}, {1710, 856}}}
  G.CS_BAND = {[0] = {1060, 732, 1840, 804}, [1] = {1060, 820, 1840, 892}}   -- the bands' screen rects
  G.CSB = @crc:evt_pp_csband@
  G.CSB_TRACE = {[0] = @crc:evt_pp_csband0@, @crc:evt_pp_csband1@}
  G.SP_CSB = @crc:evt_pp_csband@

  local function CsBand(i, on)
    local l = G.CSB
    if not Exists(l) then
      return
    end
    if not on then
      if Cmd(C.IS_OPEN, l, i) == true then
        Cmd(C.VIS, l, i, false)
      end
      return
    end
    if not Ready(l, i) then
      return
    end
    if not G.ready[l * 16 + i] then
      G.ready[l * 16 + i] = true
      Cmd(C.TRACE, G.PAGE, 0, G.CSB_TRACE[i], true)
      for _, m in ipairs({G.N_TOP, G.N_SIDE, 2043683848}) do
        Cmd(C.MESH, l, m, false, i)
      end
      Cmd(C.SPRITE, l, G.TX_BTL0613, G.SP_CSB, G.SP_FRAME, 0, i)
      local r = G.CS_BAND[i]
      local sx, sy = (r[3] - r[1]) / 476, (r[4] - r[2]) / 44
      Cmd(C.SCALE, l, sx, sy, 1, i)
      Cmd(C.POS, l, r[1] - 94 * sx, -r[2] + 816 * sy, 0, i)
    end
    Cmd(C.VIS, l, i, true)
  end

  -- Utilities' career page v6 (timeline + card-back table) lays itself out: this plate only gives its geometry (the
  -- status base's _atc_passive01 on screen, the page centre, top and height); the two rows below stay for an older
  -- Utilities
  G.CS_GEO = {origin = {1495, 880}, center = 1450, top = 704, height = 214}

  function G.Career()
    if type(UTIL_CS) ~= "table" or type(UTIL_CS.Cell) ~= "function" then
      return
    end
    local mine = On() and G.ptype == 6
    if type(UTIL_CS.OwnLayout) == "function" then
      CsBand(0, false)
      CsBand(1, false)
      UTIL_CS.OwnLayout(mine, G.CS_GEO)
      return
    end
    if not mine then
      CsBand(0, false)
      CsBand(1, false)
      if G.csOn then
        G.csOn = false
        for r = 0, 1 do
          for c = 0, 3 do
            local L, k = UTIL_CS.Cell(r, c)
            if Exists(L) and Cmd(C.IS_OPEN, L, k) == true then
              Cmd(C.POS, L, 0, 0, 0, k)
            end
          end
        end
      end
      return
    end
    G.csOn = true
    for i = 0, 4 do
      if Exists(811691761) and Cmd(C.IS_OPEN, 811691761, i) == true then
        Cmd(C.VIS, 811691761, i, false)
      end
    end
    CsBand(0, true)
    CsBand(1, true)
    for r = 0, 4 do
      for c = 0, (UTIL_CS.ROW_CELLS[r] or 4) - 1 do
        local L, k = UTIL_CS.Cell(r, c)
        if Exists(L) and Cmd(C.IS_OPEN, L, k) == true then
          local at = G.CS_AT[r] and G.CS_AT[r][c + 1]
          Cmd(C.VIS, L, k, at ~= nil)
          if at ~= nil then
            Cmd(C.POS, L, at[1] - (1204.5 + 195 * c), (880 + 84 * r) - at[2], 0, k)
          end
        end
      end
    end
    if G.csFor ~= G.hdl then
      G.csFor = G.hdl
      pcall(G.CareerFill)
    end
  end

  function G.CareerFill()
    local chara = UTIL_CS.SelectedChara(nil)
    local v = UTIL_CS.Ex(chara, 0)
    local T = UTIL_CS.Text
    for r = 0, 1 do
      for c = 0, 3 do
        UTIL_CS.Set(r, c, "", "")
      end
    end
    if v == nil then
      UTIL_CS.Set(0, 0, T("no_data"), T("none"))
      return
    end
    local signed, before, source = v[1], v[2], v[3]
    local m, w, d, l, g, a = v[5], v[6], v[7], v[8], v[9], v[10]
    local src = type(source) == "number" and source >= 1 and source <= 4 and T("src" .. source) or T("none")
    UTIL_CS.Set(0, 0, T("l_signed"), UTIL_CS.Date(signed) or UTIL_CS.Date(before) or T("none"))
    UTIL_CS.Set(0, 1, T("l_source"), src)
    UTIL_CS.Set(0, 2, T("l_matches"), tostring(m))
    UTIL_CS.Set(1, 0, T("l_record") .. " · %", UTIL_CS.Fmt("v_record", w, d, l) .. " · " .. UTIL_CS.Pct(w, m))
    UTIL_CS.Set(1, 1, T("l_goals"), tostring(g))
    UTIL_CS.Set(1, 2, T("l_gpm"), UTIL_CS.Ratio(g, m, 2))
    local _ = a
  end

  -- round 11b: the dock lineup behind a bank's plate is hidden by the dock menus themselves (plate_dock_hide.lua);
  -- round 11's menu command 1558704558 here was MENU_ACTIVE (input), not visibility, and broke the dock

  -- a host without pages: the 8th value (Suerte, CMND_EVT_CHARA_STAT 8) on number instance 7 (the retail graph
  -- writes 7; plate_hiper's EVT_R9 writes all 8 only in personal_plate_menu)
  -- 2026-10-06 (hosts: added layers only) the chart = our layers placed on the card (G.CHART_AT), the retail radar
  -- pieces off; (Nacho: the skill table's card shows only the selected technique's plate) G.H.chart = false = no
  -- chart on that host: our chart layers are never opened there (only hidden if open), the bars follow
  function G.HostChart()
    local x, y = G.CHART_AT[1], -G.CHART_AT[2]
    if G.H.chart == false then
      for _, l in ipairs({G.GRAPH, G.EXTRA, G.NUM}) do
        if Exists(l) then
          for k = 0, 7 do
            if Cmd(C.IS_OPEN, l, k) == true then
              Cmd(C.VIS, l, k, false)
            end
          end
        end
      end
    else
      local up = G.vals ~= nil
      for _, l in ipairs({G.GRAPH, G.EXTRA}) do
        if Exists(l) and Ready(l, 0) then
          Cmd(C.POS, l, x, y, 0, 0)
          Cmd(C.VIS, l, 0, up)
        end
      end
      if Exists(G.NUM) then
        for k = 0, 7 do
          if Ready(G.NUM, k) then
            Cmd(C.VIS, G.NUM, k, up)
          end
        end
      end
    end
    if G.KeepRadar() then
      return                                -- a panel of the host draws on the retail radar now: left to it
    end
    for _, l in ipairs({G.RETAIL_GRAPH, G.RETAIL_NUM, G.RADAR}) do        -- the retail radar pieces off
      if Exists(l) then
        for k = 0, 7 do
          if Cmd(C.IS_OPEN, l, k) == true then
            Cmd(C.VIS, l, k, false)
          end
        end
      end
    end
  end

  -- 2026-10-14: a host whose own panels draw on the retail radar (the skill table's set preview and training view)
  -- answers G.H.keep_radar() = true while they show it; the page then leaves the radar (and its polygon) alone
  function G.KeepRadar()
    if G.H.pages or type(G.H.keep_radar) ~= "function" then
      return false
    end
    local ok, keep = pcall(G.H.keep_radar)
    return ok and keep == true
  end

  G.HOST_CHART = true                    -- the chart on the hosts' card (attach rows in player_page_layout.toml)
  function G.HostNumbers()
    if G.HOST_CHART then
      pcall(G.HostChart)
    end
    if G.vals == nil or not Exists(G.NUM) or Cmd(C.IS_OPEN, G.NUM, 7) ~= true then
      return
    end
    local style = 2612831244
    local prim = Cmd(1927054058, G.NUM, 7, style)
    Cmd(3609943765, G.NUM, 7, prim, G.vals[8] or 0)
    Cmd(1233047821, G.NUM, 7, style, true)
    if Exists(G.EXTRA) and Cmd(C.IS_OPEN, G.EXTRA, 0) == true then
      Cmd(C.VIS, G.EXTRA, 0, Cmd(C.IS_VIS, G.GRAPH, 0) == true)
    end
  end

  -- ---- no player focused (empty slot): nothing of the page, back when a player is focused ---------------------
  function G.Empty()
    if not On() then
      return
    end
    local h = 0
    if type(GetPersonalPlateSelectCharaStHdlAuto) == "function" then
      local ok, v = pcall(GetPersonalPlateSelectCharaStHdlAuto)
      h = ok and type(v) == "number" and v or 0
    end
    local empty = h == 0
    if not empty and type(IsInvalidSoccerCharaHdl) == "function" then
      local ok, bad = pcall(IsInvalidSoccerCharaHdl, h)
      empty = ok and bad == true
    end
    if empty and not G.emptyHidden then
      G.emptyHidden = true
      for _, l in ipairs({G.PAGE, G.PLATE, G.STATUS, G.BAND, G.SLANT, G.TAG}) do
        if Exists(l) and Cmd(C.IS_OPEN, l, 0) == true then
          Cmd(C.VIS, l, 0, false)
        end
      end
      if type(G.BarsVisible) == "function" then
        G.BarsVisible(false)
      end
      for i = 0, 4 do
        G.Tile(i, false)
      end
      if type(EVT_PH_Hide) == "function" then
        pcall(EVT_PH_Hide)
      end
      if type(UTIL_CS) == "table" and type(UTIL_CS.Hide) == "function" then
        pcall(UTIL_CS.Hide)
      end
      if type(SetVisiblePersonalPlateLayerAll) == "function" then
        pcall(SetVisiblePersonalPlateLayerAll, false)
      end
    elseif empty then
      -- 2026-10-07 (Nacho: «Sin hipertécnica» on an empty bench slot): while no player is focused the Hiper panel
      -- stays hidden every frame (a pending redraw or a later UpdatePageInfo must not bring it back; cheap: the hide
      -- only acts on a visible layer)
      if type(EVT_PHI) == "table" and type(EVT_PHI.HideLayer) == "function" then
        EVT_PH_PENDING = nil
        pcall(EVT_PHI.HideLayer)
      end
    elseif not empty and G.emptyHidden then
      G.emptyHidden = false
      G.csFor = nil
      for _, l in ipairs({G.PAGE, G.PLATE, G.STATUS}) do
        if Exists(l) and Cmd(C.IS_OPEN, l, 0) == true then
          Cmd(C.VIS, l, 0, true)
        end
      end
      if type(UpdatePersonalPlatePage) == "function" then
        pcall(UpdatePersonalPlatePage)
      end
    end
  end

  -- ---- Equipamiento: 2 x 2, no title row ------------------------------------------------------------------------
  function G.Equip()
    if not Exists(G.EQUIP) then
      return
    end
    local mine = On() and G.ptype == 0
    for k = 0, 4 do
      if Cmd(C.IS_OPEN, G.EQUIP, k) == true then
        if k <= 3 then
          local sc = mine and G.EQUIP_SCALE or 1
          Cmd(C.SCALE, G.EQUIP, sc, sc, 1, k)
        elseif mine then
          Cmd(C.VIS, G.EQUIP, k, false)
        end
      end
    end
  end

  -- ---- Hiper page: L3 = the keshin a miximax gives, and back ------------------------------------------------------
  function G.HiperL3()
    G.frame = G.frame + 1
    if not On() or EVT_PH_PAGE == nil or GetNowPageIdx == nil or GetNowPageIdx() ~= EVT_PH_PAGE
        or type(EVT_PH_MxAura) ~= "function" or type(EVT_PH_Show) ~= "function" or type(funcLuaCommand) ~= "function" then
      return
    end
    local L = G.L3
    local okp, p1 = pcall(funcLuaCommand, L.CHECK, L.CTRL, L.CMD)
    local okq, p2 = pcall(funcLuaCommand, L.CHECK, L.CTRL_AN, L.CMD)
    if not ((okp and p1 == true) or (okq and p2 == true)) or G.frame - G.l3last < 8 then
      return
    end
    G.l3last = G.frame
    local chara = 0
    if type(GetPersonalPlateSelectCharaStHdlAuto) == "function" then
      local ok, v = pcall(GetPersonalPlateSelectCharaStHdlAuto)
      chara = ok and type(v) == "number" and v or 0
    end
    if chara == 0 then
      return
    end
    if type(EVT_PH_CanSwitch) == "function" then
      -- 2026-10-12 (two Hiper slots, docs/game/hiper/hiper-two-slots.md): L3 switches the aura slot / the mix slot
      local okc, can = pcall(EVT_PH_CanSwitch, chara)
      if not okc or can ~= true then
        return
      end
    else
      if type(EVT_PH_Skill) == "function" and EVT_PH_Skill(chara) ~= EVT_PH_MX_CARRIER then
        return
      end
      local oka, aura = pcall(EVT_PH_MxAura, chara)
      if not oka or aura == nil then
        return
      end
    end
    EVT_PH_MX_VIEW = not EVT_PH_MX_VIEW
    pcall(funcLuaCommand, 1917805374, 2500047763)      -- the plate's cursor sound
    pcall(EVT_PH_Show, chara)
  end

  -- ---- the stat rows ------------------------------------------------------------------------------------------
  -- 2026-10-12 (owner): ATRIBUTOS = TWO COLUMNS x 4 ROWS, each row  NAME | gauge | VALUE | position pills (the 8 vertical
  -- 3D bars and the line chart retired). The gauge is the retail per-player training gauge (team13_16_beans_gauge, the
  -- «Entrenar» screen's bar: grey track + fill by its rate gauge01), cloned as layer evt_pp_stat_bar (Character
  -- Reforged content/menus/player_page_layout.toml), one instance per row, attached to the graph base; its icon and
  -- «value / max» numbers hidden. The bar is drawn by the gauge's plain textured quads, no rate: the retail fill
  -- _beans_bar01 is a masked material moved by the rate gauge01, which does not advance while a match is paused (an
  -- empty bar in the match pause's Formación). Meshes draw in their order (navy plate, slash, track, fill):
  --   navy plate _beans_param_base01 = the track (sprite beans_bar_base01, the track's rect);
  --   slash _beans_bar_slash01      = the miximax gain (evt_pp_gfill_gain), from the fill's left to value + gain;
  --   track _beans_bar_base01       = the fill (evt_pp_gfill_<tags>, btl06_13 atlas), the fill's rect cut to the value.
  -- Mesh node translation = the quad's top-left, node scale = its size (gauge units).
  -- Fill = the shown value / the stat's max for this player (a training mod's «value / max» max: base + max of the
  -- page slot character_reforged.page_stat_max, CharacterReforged.Page.StatTop); without an answer, one common scale (the training screen's: the largest value
  -- + 15 %, rounded up to 50, at least 100). Names, values and pills are the graph base's own nodes, placed by the layout
  -- (research/scripts/if_plate_row_build.py ROWS_X0 / ROWS_Y / ROW_GAUGE: keep G.ROW_X0 / G.ROW_Y / G.GAUGE equal).
  -- Graph units: origin = the chart locator (screen 1435, 746), y up.
  G.ROW_X0 = {[0] = 993 - 1435, 1445 - 1435}                       -- column left edges
  G.ROW_Y = {[0] = 746 - 740, 746 - 785, 746 - 830, 746 - 875}     -- row centres
  G.GAUGE = {X = 124, W = 180, H = 28}                             -- track: x from the column's left, width, height
  -- team13_16 layout: _pos_bar01 holds the track _beans_bar_base01 (176 x 16 at -64, -13) and the fill _beans_bar01
  -- (166 x 16 at -59, -13)
  G.GG = {NODE = 3407907417 --[[_pos_bar01]], TRACK_X = -64, TRACK_Y = -13, TRACK_W = 176, TRACK_H = 16,
    FILL_X = -59, FILL_W = 166,
    HIDE = {3653430537 --[[_icon_parameter_dmy01]], 156590433 --[[_num_param_dmy01]], 2421960923 --[[_num_param_dmy02]],
      501779097 --[[_beans_bar01: the masked fill]]},
    PRIMS = {3484572139, 1455097937, 1533119290},                  -- its number prims: value, next, max
    TRACK_QUAD = 3904782638 --[[_beans_param_base01]], GAIN_QUAD = 3341153111 --[[_beans_bar_slash01]],
    FILL_QUAD = 720708095 --[[_beans_bar_base01]],
    -- sprite slots of those three meshes and the retail track sprite (team13_16 atlas)
    SLOT_TRACK_QUAD = 1215825632 --[[beans_param_base01]], SLOT_GAIN_QUAD = 192955831 --[[beans_bar_slash01]],
    SLOT_FILL_QUAD = 2201244747 --[[beans_bar_base01]], SP_TRACK = 2201244747 --[[beans_bar_base01]],
    TX_GAUGE = 995892987 --[[#/menu/102_team/team13/team13_16/team13_16.g4tx]],
    MIN_W = 0.5,                                                   -- narrower quads are hidden (gauge units)
    PRIM_VIS = 1233047821}

  local function BarsVisible(on)
    if not Exists(G.BAR) then
      return
    end
    for k = 0, 7 do
      if Cmd(C.IS_OPEN, G.BAR, k) == true then
        Cmd(C.VIS, G.BAR, k, on)
      end
    end
  end
  G.BarsVisible = BarsVisible

  -- 2026-10-13: the miximax gain of group g's stat while the Miximax view is on (G.gains: CMND_EVT_MX_GAINS order,
  -- stat i at i + 1), else 0
  G.SP_GAIN = @crc:evt_pp_gfill_gain@
  function G.Gain(g)
    local t = G.gains
    return t ~= nil and (tonumber(t[G.STAT[g] + 1]) or 0) or 0
  end

  -- the max of each group's stat for chara status handle hdl (G.tops[g]), from a training mod's answer (the page slot
  -- character_reforged.page_stat_max); nil = none
  function G.Tops(hdl)
    G.tops = nil
    local page = type(CharacterReforged) == "table" and CharacterReforged.Page or nil
    if type(hdl) ~= "number" or type(page) ~= "table" or type(page.StatTop) ~= "function" then
      return
    end
    local t = {}
    for g = 1, 8 do
      local top = page.StatTop(hdl, G.STAT[g])
      if top == nil then
        return
      end
      t[g] = top
    end
    G.tops = t
  end

  -- instance k's three quads (see «the stat rows»): the track over the whole track rect (the layer's origin = its
  -- top-left), the gain from the fill's left to r2, the fill from the fill's left to r (r, r2 = 0..1). Set every frame:
  -- the gauge's open animation may move them.
  function G.BarQuads(k, r, r2, sx, sy)
    local GG = G.GG
    for _, m in ipairs(GG.HIDE) do
      Cmd(C.MESH, G.BAR, m, false, k)
    end
    Cmd(C.NODE_POS, G.BAR, k, GG.TRACK_QUAD, 0, 0)
    Cmd(C.NODE_POS, G.BAR, k, GG.TRACK_QUAD, 1, 0)
    Cmd(C.NODE_SCALE, G.BAR, k, GG.TRACK_QUAD, GG.TRACK_W * sx, GG.TRACK_H * sy)
    Cmd(C.MESH, G.BAR, GG.TRACK_QUAD, true, k)
    -- the gain quad lies in the layer's space (as the track quad), the fill quad inside _pos_bar01 (as the retail fill)
    local gain_w = GG.FILL_W * r2 * sx
    Cmd(C.NODE_POS, G.BAR, k, GG.GAIN_QUAD, 0, (GG.FILL_X - GG.TRACK_X) * sx)
    Cmd(C.NODE_POS, G.BAR, k, GG.GAIN_QUAD, 1, 0)
    Cmd(C.NODE_SCALE, G.BAR, k, GG.GAIN_QUAD, math.max(gain_w, GG.MIN_W), GG.TRACK_H * sy)
    Cmd(C.MESH, G.BAR, GG.GAIN_QUAD, r2 > r and gain_w >= GG.MIN_W, k)
    local fill_w = GG.FILL_W * r
    Cmd(C.NODE_POS, G.BAR, k, GG.FILL_QUAD, 0, GG.FILL_X)
    Cmd(C.NODE_POS, G.BAR, k, GG.FILL_QUAD, 1, GG.TRACK_Y)
    Cmd(C.NODE_SCALE, G.BAR, k, GG.FILL_QUAD, math.max(fill_w, GG.MIN_W), GG.TRACK_H)
    Cmd(C.MESH, G.BAR, GG.FILL_QUAD, fill_w * sx >= GG.MIN_W, k)
  end

  function G.Bars()
    if not On() or not Exists(G.BAR) or not Exists(G.GRAPH) then
      return
    end
    local up = G.vals ~= nil and G.ptype == EVT_PPG_STATS_TYPE and Cmd(C.IS_VIS, G.GRAPH, 0) == true
    if not up then
      BarsVisible(false)
      return
    end
    local all = true
    for k = 0, 7 do
      if not Ready(G.BAR, k) then
        all = false
      end
    end
    if not all then
      return
    end
    -- no training data: one scale for the 8 rows (the training screen's)
    local scale = 0
    for g = 1, 8 do
      scale = math.max(scale, (G.vals[g] or 0) + G.Gain(g))
    end
    scale = math.max(100, math.ceil(scale * 1.15 / 50) * 50)
    local GG, Q = G.GG, G.GAUGE
    local sx, sy = Q.W / GG.TRACK_W, Q.H / GG.TRACK_H
    for g = 1, 8 do
      local k = G.GROUP_ROW[g]
      if not G.ready[G.BAR * 16 + k] then
        G.ready[G.BAR * 16 + k] = true
        Cmd(C.TRACE, G.GRAPH, 0, G.TRACE[k], true)
        for _, m in ipairs(GG.HIDE) do
          Cmd(C.MESH, G.BAR, m, false, k)
        end
        for _, p in ipairs(GG.PRIMS) do
          Cmd(GG.PRIM_VIS, G.BAR, k, p, false)
        end
        Cmd(C.SPRITE, G.BAR, GG.TX_GAUGE, GG.SP_TRACK, GG.SLOT_TRACK_QUAD, 0, k)
        Cmd(C.SPRITE, G.BAR, G.TX_BTL0613, CALC_CRC("evt_pp_gfill_" .. G.STAT_FILL[g]), GG.SLOT_FILL_QUAD, 0, k)
        Cmd(C.SPRITE, G.BAR, G.TX_BTL0613, G.SP_GAIN, GG.SLOT_GAIN_QUAD, 0, k)
        Cmd(C.SCALE, G.BAR, 1, 1, 1, k)
        -- the bar node scaled to the row's track size, the track's top-left on the layer's origin
        Cmd(C.NODE_POS, G.BAR, k, GG.NODE, 0, -GG.TRACK_X * sx)
        Cmd(C.NODE_POS, G.BAR, k, GG.NODE, 1, -GG.TRACK_Y * sy)
        Cmd(C.NODE_SCALE, G.BAR, k, GG.NODE, sx, sy)
      end
      local col, row = math.floor(k / 4), k % 4
      Cmd(C.POS, G.BAR, G.ROW_X0[col] + Q.X, G.ROW_Y[row] + Q.H / 2, 0, k)
      -- 2026-10-13: in the Miximax view (G.gains) the max grows by the gain and the gain is drawn past the fill in the
      -- gain colour
      local gain = G.Gain(g)
      local top = (G.tops ~= nil and G.tops[g] or scale) + gain
      local v = G.vals[g] or 0
      local r = math.max(0, math.min(1, v / top))
      local r2 = math.max(0, math.min(1, (v + gain) / top))
      G.BarQuads(k, r, r2, sx, sy)
      Cmd(C.VIS, G.BAR, k, true)
    end
  end

  G.TRACE = {}
  for k = 0, 7 do
    G.TRACE[k] = nil
  end
  G.TRACE[0], G.TRACE[1], G.TRACE[2], G.TRACE[3] = @crc:evt_pp_stat_bar0@, @crc:evt_pp_stat_bar1@,
    @crc:evt_pp_stat_bar2@, @crc:evt_pp_stat_bar3@
  G.TRACE[4], G.TRACE[5], G.TRACE[6], G.TRACE[7] = @crc:evt_pp_stat_bar4@, @crc:evt_pp_stat_bar5@,
    @crc:evt_pp_stat_bar6@, @crc:evt_pp_stat_bar7@

  -- the 8 values of chara status handle hdl (the radar's: 7 retail stats + Suerte)
  function G.Values(hdl, l5)
    if type(EVT_R9) == "table" and type(EVT_R9.Values) == "function" then
      local ok, v = pcall(EVT_R9.Values, hdl, l5)
      if ok and type(v) == "table" then
        return v
      end
    end
    local v = {}
    for g = 1, 8 do
      local si = G.STAT[g]
      local val = 0
      if si <= 6 and type(funcLuaCommand) == "function" then
        local ok, x = pcall(funcLuaCommand, C.CHARA, hdl, 14 + si, true, l5)
        val = ok and type(x) == "number" and x or 0
      end
      v[g] = val
    end
    local page = type(CharacterReforged) == "table" and CharacterReforged.Page or nil
    if type(page) == "table" and type(page.Stat) == "function" then
      v[8] = page.Stat(hdl, 8) or 0     -- Suerte: the page slot character_reforged.page_stat, else Character Reforged's
    end
    return v
  end

  -- ---- page content -------------------------------------------------------------------------------------------
  local function HidePoly()
    if not Exists(G.RADAR) then
      return
    end
    for k = 0, 1 do
      for _, m in ipairs(G.M_POLY) do
        Cmd(C.MESH, G.RADAR, m, false, k)
      end
    end
  end

  -- no page titles; the move-slot badges only on SUPERTÉCNICAS
  local function Decor(ptype)
    for _, m in ipairs(G.M_TITLES) do
      Cmd(C.MESH, G.STATUS, m, false, 0)
    end
    for _, m in ipairs(G.M_ARROWS) do
      Cmd(C.MESH, G.STATUS, m, false, 0)
    end
    for i, m in ipairs(G.M_SLOTS) do
      Cmd(C.MESH, G.STATUS, m, ptype == 1 and i <= 3, 0)   -- round 8: never the rpg copies (they stacked mid-page)
    end
  end

  -- round 8: the PERFIL hint «R3 Cambiar forma» (header plate's grade text node, placed by the layout) while the
  -- player has more than one form (plate_model's EVT_PPM.forms)
  G.N_GRADE = 1006587362
  -- round 15 (2026-10-07, Nacho: «la N debería estar a la derecha de los 3 puntos»; loader.log showed the node at
  -- the wanted place while the glyph stayed at the old layout box): a text node is placed by the text system at
  -- setup only, runtime node moves (rounds 14b-14g) never move the text. The LAYOUT now puts the box where the
  -- Pasivas R3 glyph belongs (if_plate_row_build.py: box 1713..2123 x 908..938, left-aligned: the glyph centred at
  -- (1730, 923), right of the 3 sub-page dots on the Q / E glyph row); PERFIL's «R3 Cambiar forma» starts there too.
  -- This function only sets the text and its visibility.
  -- 2026-10-09 (Nacho: «RS Formas»): the hint reads «<CMD_FUNC6> Formas» (text Fantasy.PlayerFormsPrompt, IF
  -- text\rows\player_forms.toml, 9 languages; <CMD_FUNC6> = R3 on a pad, its bound key on a keyboard) and shows only
  -- while the forms plate_model loaded are the shown player's (EVT_PPM.fhdl == EVT_PPM.want: no stale prompt of the
  -- previous player while the next one builds). 2026-10-12 (owner): the forms hint left the dots row: the RS key sits
  -- on the form badge (G.FormBadge below); the dots row keeps «Ver apariencia» and the Pasivas R3.
  -- the forms of the shown player (plate_model's list, once it is his): their count, else 0
  function G.FormCount()
    local M = EVT_PPM
    if type(M) ~= "table" or type(M.forms) ~= "table" or M.fhdl == nil or M.fhdl ~= M.want then
      return 0
    end
    return #M.forms
  end
  -- 2026-10-07: where a menu offers the retail «Ver apariencia» for this page (plate_model EVT_PPM.appearance, rule
  -- view_in_menus: Formación) the same hint reads «<CMD_FUNC6> Ver apariencia» (retail menu_text 1638840503, every
  -- language) and R3 / a click opens that view (plate_model M.OpenView -> research/grafts/form_appearance)
  G.VIEW_TEXT = 1638840503
  -- 2026-10-14 (owner: the RS button of the character view is Utilities' now; docs/game/mechanics/form-viewer.md §8):
  -- the form key of PERFIL (plate_model), ATRIBUTOS (G.MxToggle) and the Hiper page (G.HiperToggle) is Utilities'
  -- action «Cambiar forma» (CMD_UTIL_VIEW_FORMS, default RS, rebindable) where this menu is declared for it (Character
  -- Reforged content\menus\player_page_view_forms.toml, only with Utilities); its glyph follows the binding. Without that declaration: R3 (CMD_FUNC6) as before.
  function G.FormKeyDecl()
    local V = type(BetterQoL) == "table" and BetterQoL.ViewForms or nil
    return type(V) == "table" and type(V.Declared) == "function" and V.Declared("personal_plate_menu") == true and V or nil
  end
  function G.FormKeyDown()
    local V = G.FormKeyDecl()
    if V ~= nil then
      return V.Pressed() == true
    end
    local ok1, a = pcall(funcLuaCommand, 4265778440, 1332654303, 3147328756)   -- CMD_FUNC6 (R3)
    local ok2, b = pcall(funcLuaCommand, 4265778440, 2748927068, 3147328756)
    return (ok1 and a == true) or (ok2 and b == true)
  end
  function G.FormGlyph()
    local V = G.FormKeyDecl()
    return V ~= nil and type(V.GLYPH) == "string" and V.GLYPH or "<CMD_FUNC6>"
  end
  function G.ViewOffered()
    return type(EVT_PPM) == "table" and EVT_PPM.appearance ~= nil and type(EVT_PPM.OpenView) == "function"
  end
  function G.ViewHint()
    if G.viewHint == nil then
      local ok, t = pcall(funcLuaCommand, 4074371074 --[[CMND_TEXT_GET]], G.VIEW_TEXT)
      if ok and type(t) == "string" and t ~= "" then
        G.viewHint = G.FormGlyph() .. " " .. t
      else
        return G.FormGlyph()
      end
    end
    return G.viewHint
  end
  function G.Hint()
    local view = On() and G.ptype == EVT_PPG_DESC_TYPE and G.ViewOffered() and not G.InOffice()
    local on = false
    local psub = On() and G.ptype == 2 and not G.InOffice()
    if view then
      Cmd(C.SET_TEXT, G.PLATE, G.N_GRADE, G.ViewHint(), 0)
      on = true
    elseif psub then
      Cmd(C.SET_TEXT, G.PLATE, G.N_GRADE, "<CMD_FUNC6>", 0)
      on = true
    end
    Cmd(C.TEXT_VIS, G.PLATE, G.N_GRADE, on, 0)
  end

  -- 2026-10-13 (owner): ATRIBUTOS toggles Normal / Miximax with the form key (R3 / the RS key, a click on the badge),
  -- only for a player with a miximax (the page slot character_reforged.page_stat_gain answers: a mod's gains of his
  -- mix slot's form, e.g. the miximax confirmation's). The view is plate_hiper's EVT_R9.mx (its
  -- L3 still toggles it too): the numbers are the totals in the retail «goes up» style (EVT_R9.Draw), the gauges
  -- show the gain past the fill in the gain colour (G.Bars, G.gains), the form badge shows the Normal / Mix-Max glyph,
  -- and the 3D model follows: the form viewer's Miximax form (1; 3, its armour form, only when 1 is not listed),
  -- Normal (0) otherwise (plate_model M.ShowForm). Armour forms are never picked here. Entering ATRIBUTOS starts
  -- Normal (since 2026-10-14 a page change resets the model's form: G.Apply); another player starts Normal.
  G.MX_FORMS = {1, 3}
  G.MX_SOUND = 2629173176                -- sy0009, the form viewer's switch sound (as R3 on PERFIL)
  function G.MxHdl()
    local a = type(EVT_R9) == "table" and EVT_R9.args or nil
    return type(a) == "table" and a[3] or nil
  end
  function G.MxAvail()
    local h = G.MxHdl()
    if h == nil or type(EVT_R9.Gains) ~= "function" then
      return false
    end
    if G.mxAvailFor ~= h then
      G.mxAvailFor = h
      local ok, g = pcall(EVT_R9.Gains, h)
      G.mxAvail = ok and type(g) == "table"
      pcall(funcLuaCommand, C.LOG, "EVT_PPG mx avail", tostring(h), tostring(G.mxAvail))
    end
    return G.mxAvail == true
  end
  -- the miximax form among the shown player's forms (plate_model's list, once it is his); nil = none
  -- the first form of `list` the shown player has (plate_model's list, once it is his); nil = none
  function G.FirstForm(list)
    local M = EVT_PPM
    if type(list) ~= "table" or type(M) ~= "table" or type(M.forms) ~= "table" or M.fhdl == nil or M.fhdl ~= M.want then
      return nil
    end
    for _, f in ipairs(list) do
      for _, x in ipairs(M.forms) do
        if x == f then
          return f
        end
      end
    end
    return nil
  end
  function G.MxForm()
    return G.FirstForm(G.MX_FORMS)
  end
  function G.CurForm()
    local M = EVT_PPM
    if type(M) ~= "table" or type(M.forms) ~= "table" then
      return 0
    end
    return M.forms[M.fidx or 1] or 0
  end
  -- the gains of the Miximax view (with every graph refresh, after G.vals)
  function G.MxGains(hdl)
    G.gains = nil
    if type(EVT_R9) == "table" and EVT_R9.mx == true and type(EVT_R9.Gains) == "function" then
      local ok, g = pcall(EVT_R9.Gains, hdl)
      if ok and type(g) == "table" then
        G.gains = g
      end
    end
  end
  -- the radar's last call again (numbers, values, gains), as plate_hiper's L3 does
  function G.MxRedraw()
    local a = type(EVT_R9) == "table" and EVT_R9.args or nil
    if type(a) == "table" and type(UpdateCharaParameterGraphByCharaStHdl) == "function" then
      pcall(UpdateCharaParameterGraphByCharaStHdl, a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8])
    end
  end
  function G.MxSet(on, why)
    if (EVT_R9.mx == true) == on then
      return
    end
    EVT_R9.mx = on
    pcall(funcLuaCommand, C.LOG, "EVT_PPG mx view", tostring(why), tostring(on))
    G.MxRedraw()
  end
  function G.MxToggle(why)
    if not On() or G.ptype ~= EVT_PPG_STATS_TYPE or not G.MxAvail() then
      return
    end
    G.mlast = G.mtick or 0
    pcall(funcLuaCommand, 1917805374, G.MX_SOUND)
    G.MxSet(EVT_R9.mx ~= true, why)
  end
  function G.MxStep()
    if not On() or not G.H.pages or type(EVT_R9) ~= "table" then
      return
    end
    local h = G.MxHdl()
    if h ~= G.mxHdl then                   -- another player: Normal
      G.mxHdl, G.mxAvailFor = h, nil
      G.MxSet(false, "player")
    end
    local stats = G.ptype == EVT_PPG_STATS_TYPE and not G.InOffice()
    if stats ~= G.mxOnPage then
      G.mxOnPage = stats
      if stats then                        -- entering ATRIBUTOS: the view follows the model's form
        local mf = G.MxForm()
        G.MxSet(G.MxAvail() and mf ~= nil and G.CurForm() == mf, "page")
      end
    end
    if not stats then
      return
    end
    G.mtick = (G.mtick or 0) + 1
    if G.mtick - (G.mlast or -100) >= 8 then
      if G.FormKeyDown() then                -- the form key (Utilities' «Cambiar forma», else R3)
        G.MxToggle("R3")
      end
    end
    -- the 3D model follows the view (plate_model rebuilds it with that form; not where the retail view is offered)
    local M = EVT_PPM
    if type(M) == "table" and type(M.ShowForm) == "function" and M.appearance == nil then
      local f = (EVT_R9.mx == true and G.MxForm()) or 0
      if G.CurForm() ~= f then
        pcall(M.ShowForm, f)
      end
    end
  end


  -- 2026-10-13 (owner: «Adapta lo del RS para ver las formas, no sale para las auras del slot de mix»): the Hiper page
  -- offers the same RS toggle (R3 / the RS key / a click on the badge) between Normal and the form of the aura it
  -- shows, by one rule per slot (G.SLOT_FORMS): the MIX slot's move (plate_hiper EVT_PH_Skill = EVT_PH_MixOf: shown when
  -- the aura slot is empty or in the L3 view) -> the form viewer's miximax forms (G.MX_FORMS), the AURA slot's -> its
  -- armour (2). A slot whose aura has no such form for him («Modo cambio», a totem / keshin without armour) = no badge,
  -- no toggle. The form list already reads the mix slot first (VR-Framework form viewer, transform_engine
  -- form/viewer.rs: `[miximax] mix_table`, then the aura board slot), as CMND_EVT_MX_GAINS does. Entering the page,
  -- another player or the other slot (L3) takes the model's current form; the 3D model follows (plate_model M.ShowForm).
  G.HIPER_TYPE = 5                        -- the Hiper page's type (plate_hiper, page index 4)
  G.SLOT_FORMS = {mix = G.MX_FORMS, aura = {2}}
  function G.HiperChara()
    if type(GetPersonalPlateSelectCharaStHdlAuto) ~= "function" then
      return 0
    end
    local ok, v = pcall(GetPersonalPlateSelectCharaStHdlAuto)
    return ok and type(v) == "number" and v or 0
  end
  -- the form of the aura the page shows (nil = none) and its slot
  function G.HiperTarget(c)
    if c == 0 or type(EVT_PH_Skill) ~= "function" or type(EVT_PH_MixOf) ~= "function" then
      return nil
    end
    local okS, sk = pcall(EVT_PH_Skill, c)
    if not okS or type(sk) ~= "number" or sk == 0 then
      return nil
    end
    local okM, mix = pcall(EVT_PH_MixOf, c)
    local slot = (okM and mix == sk) and "mix" or "aura"
    return G.FirstForm(G.SLOT_FORMS[slot]), slot
  end
  -- 2026-10-13 (owner: a DOUBLE hyper = a MIX slot move AND an AURA slot move, plate_hiper EVT_PH_CanSwitch): RS (R3 /
  -- the RS key / a click on the badge) ALTERNATES the Hiper section between the two slots (EVT_PH_MX_VIEW, the switch
  -- L3 also does: title strip, portrait, move row, AT, tension redrawn by EVT_PH_Show) and the 3D model goes to the
  -- matching form with the same press (mix view -> the slot's G.SLOT_FORMS.mix form, aura view -> .aura; Normal when
  -- the player has no such form). One press, one meaning: on this page RS is the slot switch and the model follows it;
  -- the Normal <-> form toggle stays for a player with only ONE of the two. RS left / right still turns the model
  -- (plate_model M.StickTurn). Entering the page (another player, the forms loaded) with the model already in the mix
  -- slot's form opens the mix view. The badge shows both slots' glyphs, the shown one lit (G.FormBadge).
  function G.HiperDoubleSet(view, c, why)
    if (EVT_PH_MX_VIEW == true) ~= view then
      EVT_PH_MX_VIEW = view
      if type(EVT_PH_Show) == "function" and c ~= 0 then
        pcall(EVT_PH_Show, c)
      end
    end
    G.hiperTgt, G.hiperSlot = G.HiperTarget(c)
    pcall(funcLuaCommand, C.LOG, "EVT_PPG hiper view", tostring(why), view and "mix" or "aura", tostring(G.hiperTgt))
  end
  function G.HiperToggle(why)
    if not On() or G.ptype ~= G.HIPER_TYPE then
      return
    end
    if G.hiperDouble == true then
      G.mlast = G.mtick or 0
      pcall(funcLuaCommand, 1917805374, G.MX_SOUND)
      G.HiperDoubleSet(EVT_PH_MX_VIEW ~= true, G.HiperChara(), why)
      return
    end
    if G.hiperTgt == nil then
      return
    end
    G.mlast = G.mtick or 0
    G.hiperOn = not G.hiperOn
    pcall(funcLuaCommand, 1917805374, G.MX_SOUND)
    pcall(funcLuaCommand, C.LOG, "EVT_PPG hiper form", tostring(why), tostring(G.hiperSlot), tostring(G.hiperTgt),
      tostring(G.hiperOn))
  end
  function G.HiperFormStep()
    if not On() or not G.H.pages or G.ptype ~= G.HIPER_TYPE or G.InOffice() then
      G.hiperKey, G.hiperTgt, G.hiperDouble, G.hiperBase = nil, nil, nil, nil
      return
    end
    local M = EVT_PPM
    local c = G.HiperChara()
    local n = type(M) == "table" and type(M.forms) == "table" and #M.forms or 0
    local base = string.format("%s:%s:%d", tostring(c), tostring(type(M) == "table" and M.fhdl), n)
    local key = base .. ":" .. tostring(EVT_PH_MX_VIEW)
    if key ~= G.hiperKey then                -- entering, another player, the other slot, the forms loaded
      G.hiperKey = key
      local okc, can = false, false
      if type(EVT_PH_CanSwitch) == "function" and c ~= 0 then
        okc, can = pcall(EVT_PH_CanSwitch, c)
      end
      G.hiperDouble = okc and can == true
      G.hiperTgt, G.hiperSlot = G.HiperTarget(c)
      G.hiperOn = G.hiperTgt ~= nil and G.CurForm() == G.hiperTgt
      pcall(funcLuaCommand, C.LOG, "EVT_PPG hiper form", "slot", tostring(G.hiperSlot), tostring(G.hiperTgt),
        tostring(G.hiperOn), G.hiperDouble and "double" or "single")
      if G.hiperDouble and base ~= G.hiperBase and EVT_PH_MX_VIEW ~= true then
        local mf = G.FirstForm(G.SLOT_FORMS.mix)
        if mf ~= nil and mf ~= 0 and G.CurForm() == mf then   -- the model already in the mix slot's form
          G.HiperDoubleSet(true, c, "page")
        end
      end
      G.hiperBase = base
    end
    if G.hiperTgt == nil and G.hiperDouble ~= true then
      return
    end
    G.mtick = (G.mtick or 0) + 1
    if G.mtick - (G.mlast or -100) >= 8 then
      if G.FormKeyDown() then                -- the form key (Utilities' «Cambiar forma», else R3)
        G.HiperToggle("R3")
      end
    end
    if type(M) == "table" and type(M.ShowForm) == "function" and M.appearance == nil then
      local f
      if G.hiperDouble == true then
        f = G.hiperTgt or 0                  -- the shown slot's form, Normal without one
      else
        f = G.hiperOn and G.hiperTgt or 0
      end
      if G.CurForm() ~= f then
        pcall(M.ShowForm, f)
      end
    end
  end

  -- the badge glyph of a Hiper slot's move by its aura type (EVT_HC.AuraType: 0 keshin, 1 armour, 2 miximax, 3 totem,
  -- 6 mode change; any other = the keshin glyph); the _dim sprite = the slot not shown (Character Reforged
  -- content/images/menu/plate_form_badges.toml)
  G.SLOT_GLYPH = {[0] = {@crc:evt_pp_fb_keshin@, @crc:evt_pp_fb_keshin_dim@},
    [1] = {@crc:evt_pp_fb_armour@, @crc:evt_pp_fb_armour_dim@},
    [2] = {@crc:evt_pp_fb_miximax@, @crc:evt_pp_fb_miximax_dim@},
    [3] = {@crc:evt_pp_fb_totem@, @crc:evt_pp_fb_totem_dim@},
    [6] = {@crc:evt_pp_fb_mode@, @crc:evt_pp_fb_mode_dim@}}
  function G.SlotGlyph(skill, lit)
    local t = nil
    if type(EVT_HC) == "table" and type(EVT_HC.AuraType) == "function" and type(skill) == "number" and skill ~= 0 then
      local ok, v = pcall(EVT_HC.AuraType, skill)
      t = ok and v or nil
    end
    local g = (t ~= nil and G.SLOT_GLYPH[t]) or G.SLOT_GLYPH[0]
    return g[lit and 1 or 2], t
  end
  -- a double hyper's badge: {mix slot glyph, aura slot glyph} (the shown one lit) and its layout key
  function G.HiperDoubleGlyphs()
    local c = G.HiperChara()
    if c == 0 or type(EVT_PH_MixOf) ~= "function" or type(EVT_PH_AuraOf) ~= "function" then
      return nil
    end
    local okM, mix = pcall(EVT_PH_MixOf, c)
    local okA, aura = pcall(EVT_PH_AuraOf, c)
    if not (okM and okA) then
      return nil
    end
    local mv = EVT_PH_MX_VIEW == true
    local gm, tm = G.SlotGlyph(mix, mv)
    local ga, ta = G.SlotGlyph(aura, not mv)
    return {gm, ga}, string.format("d%s:%s:%s", mv and "m" or "a", tostring(tm), tostring(ta))
  end

  -- 2026-10-12 (owner: «the form as its black-and-white icon, not the Normal pill»): while the shown player has more
  -- than one form (PERFIL, no retail view offered, not over the office) the form the 3D model shows is a BADGE centred
  -- where the name pill was (G.FB_AT, over the model's top, under the level): the form's glyph tiles (G.FORM_GLYPHS:
  -- form ids of the VR-Framework's form viewer, 0 Normal = the player bust, 1 Miximax = the Mix-Max tab glyph,
  -- 2 Armour = the armour tab glyph, 3 Armour + Miximax = both side by side) then the RS key (<CMD_FUNC6>: R3 on a pad,
  -- its bound key on a keyboard; pressing it cycles the forms, plate_model) on a square plate of the same height.
  -- Tiles and plate = gauge copies (layer evt_pp_fbadge, instances 0 / 1 the tiles, 2 the key's plate:
  -- player_page_layout.toml) showing the sprites of content/images/menu/plate_form_badges.toml (the game's own
  -- monochrome tab glyphs on a near-black square, the key's plate light, made at boot); the key glyph = the text of the evt_pp_flabel pill
  -- (its pill mesh hidden; text box 330 x 40 left-aligned from x -165, scaled by G.FB_KEY_K). It changes on the press,
  -- before the new model is built; the layout is redone only when the shown form changes.
  G.FBADGE = @crc:evt_pp_fbadge@
  G.FB_TRACE = {[0] = @crc:evt_pp_fbadge0@, @crc:evt_pp_fbadge1@, @crc:evt_pp_fbadge2@}
  G.FB_KEY = 2                               -- the RS key's plate instance
  G.FB_PLATE = @crc:evt_pp_fb_key@          -- the key's light plate
  -- 2026-10-12 (two Hiper slots): 3 = the armour the miximax grants (its own glyph: the armour with a small Mix-Max
  -- mark) + the Mix-Max, 4 = the aura slot's armour + the Mix-Max
  G.FORM_GLYPHS = {[0] = {@crc:evt_pp_fb_player@}, {@crc:evt_pp_fb_miximax@}, {@crc:evt_pp_fb_armour@},
    {@crc:evt_pp_fb_mxarmour@, @crc:evt_pp_fb_miximax@}, {@crc:evt_pp_fb_armour@, @crc:evt_pp_fb_miximax@}}
  G.FB_AT = {1700, 262}                      -- the badge row's centre (screen px; the old pill's centre)
  G.FB_S, G.FB_GAP = 40, 6                   -- tile / key plate size, gap between them (screen px)
  G.FB_KEY_K = 0.8                           -- the key text's scale (the old pill text's)
  -- the key glyph's offset in its plate (screen px; DY < 0 = up). The gaiji's drawing is centred in its cell
  -- (gaiji_xinput gaiji_bt12: 48 x 48 cell, drawn box x 4..44, y 8..40), so the remaining offset is where the text box
  -- puts the cell: owner 2026-10-12 (1.29.61 in game) saw the RS glyph low and to the right with DX 7 / no DY
  G.FB_KEY_DX, G.FB_KEY_DY = 3, -4
  G.FLABEL = @crc:evt_pp_flabel@
  G.N_AREA_TEXT = 1899787537                 -- _text_area01 (the pill's text)
  G.N_AREA_BASE = 3516146179                 -- _area_base01 (the pill)
  function G.FbHide()
    G.fbKey, G.fbBox = nil, nil
    for i = 0, 2 do
      if Exists(G.FBADGE) and Cmd(C.IS_OPEN, G.FBADGE, i) == true then
        Cmd(C.VIS, G.FBADGE, i, false)
      end
    end
    if Exists(G.FLABEL) and Cmd(C.IS_OPEN, G.FLABEL, 0) == true then
      Cmd(C.VIS, G.FLABEL, 0, false)
    end
  end
  -- one gauge copy as a tile: its frame quad (476 x 44 at (94, -816) in its units) = left, top, size s (screen px)
  function G.FbPlace(i, sprite, left, top, s)
    local L = G.FBADGE
    if not G.ready[L * 16 + i] then
      G.ready[L * 16 + i] = true
      Cmd(C.TRACE, G.PAGE, 0, G.FB_TRACE[i], true)
      for _, m in ipairs({G.N_TOP, G.N_SIDE, 2043683848}) do
        Cmd(C.MESH, L, m, false, i)
      end
    end
    local sx, sy = s / 476, s / 44
    Cmd(C.SPRITE, L, G.TX_BTL0613, sprite, G.SP_FRAME, 0, i)
    Cmd(C.SCALE, L, sx, sy, 1, i)
    Cmd(C.POS, L, left - 94 * sx, -top + 816 * sy, 0, i)
  end
  function G.FormBadge()
    local glyphs, f = nil, nil
    if On() and G.ptype == EVT_PPG_DESC_TYPE and G.FormCount() > 1 and not G.ViewOffered() and not G.InOffice() then
      local M = EVT_PPM
      f = M.forms[M.fidx or 1] or 0
      glyphs = G.FORM_GLYPHS[f]
    elseif On() and G.ptype == G.HIPER_TYPE and not G.InOffice() and G.hiperDouble == true then
      glyphs, f = G.HiperDoubleGlyphs()      -- 2026-10-13: a double hyper, both slots (the shown one lit)
    elseif On() and G.ptype == G.HIPER_TYPE and not G.InOffice() and G.hiperTgt ~= nil then
      f = G.hiperOn and G.hiperTgt or 0      -- 2026-10-13: the Hiper page, Normal / the shown aura's form
      glyphs = G.FORM_GLYPHS[f]
    elseif On() and G.ptype == EVT_PPG_STATS_TYPE and not G.InOffice() and G.MxAvail() then
      f = EVT_R9.mx == true and 1 or 0       -- 2026-10-13: ATRIBUTOS, Normal / Miximax (G.MxStep)
      glyphs = G.FORM_GLYPHS[f]
    end
    local L, T = G.FBADGE, G.FLABEL
    if glyphs == nil or not Exists(L) or not Exists(T) then
      -- 2026-10-14 (owner: a whole «ENERGÍA» gauge over Plantilla / Formación): hidden even before the badge was ever
      -- placed (G.fbKey nil): an instance Ready() opened for a badge that never finished stays the raw gauge
      G.FbHide()
      return
    end
    local n = #glyphs
    for i = 0, n - 1 do
      if not Ready(L, i) then
        return
      end
    end
    if not Ready(L, G.FB_KEY) or not Ready(T, 0) then
      return
    end
    if not G.ready[T * 16] then
      G.ready[T * 16] = true
      G.fbKey = nil
      Cmd(C.TRACE, G.PAGE, 0, T, true)
      Cmd(C.MESH, T, G.N_AREA_BASE, false, 0)
      Cmd(C.SCALE, T, G.FB_KEY_K, G.FB_KEY_K, 1, 0)
      Cmd(C.SET_TEXT, T, G.N_AREA_TEXT, G.FormGlyph(), 0)
      Cmd(2735666188 --[[text visible]], T, G.N_AREA_TEXT, true, 0)
    end
    for i = 0, n - 1 do
      if not G.ready[L * 16 + i] then
        G.fbKey = nil                          -- an instance (re)opened: place it again
      end
    end
    if not G.ready[L * 16 + G.FB_KEY] then
      G.fbKey = nil
    end
    local key = tostring(f) .. "/" .. n
    if G.fbKey ~= key then
      G.fbKey = key
      local s, gap = G.FB_S, G.FB_GAP
      local w = (n + 1) * s + n * gap
      local left, top = G.FB_AT[1] - w / 2, G.FB_AT[2] - s / 2
      for i = 0, n - 1 do
        G.FbPlace(i, glyphs[i + 1], left + i * (s + gap), top, s)
      end
      for i = n, G.FB_KEY - 1 do               -- a tile the form does not use
        if Cmd(C.IS_OPEN, L, i) == true then
          Cmd(C.VIS, L, i, false)
        end
      end
      local kx = left + n * (s + gap)
      G.FbPlace(G.FB_KEY, G.FB_PLATE, kx, top, s)
      Cmd(C.POS, T, kx + G.FB_KEY_DX + 165 * G.FB_KEY_K, -(G.FB_AT[2] + G.FB_KEY_DY), 0, 0)
      G.fbBox = {left, top, w, s}              -- the pointer zone (click = next form)
      pcall(funcLuaCommand, C.LOG, "EVT_PPG form badge", tostring(f), n, string.format("%.0f", left))
    end
    for i = 0, n - 1 do
      Cmd(C.VIS, L, i, true)
    end
    Cmd(C.VIS, L, G.FB_KEY, true)
    Cmd(C.VIS, T, 0, true)
  end

  -- ---- the gauge copies never drawn raw (2026-10-14, owner: a whole «ENERGÍA» gauge with its empty bar across
  -- Plantilla / Formación, Inazuma Fantasy off) -------------------------------------------------------------------
  -- Every btl06_13 stamina gauge copy of the page (evt_pp_tag, _ptile, _ptrule, _sxbar, _sxplate, _csband, _fbadge)
  -- is the retail gauge («ENERGÍA» title, empty bar) until this block hides its gauge parts and gives it its sprite,
  -- size and place (its G.ready flag; the empty special passive's box: G.emptyOn). An instance open but not set up
  -- (opened by a piece that stopped before placing it, or opened / reopened by the engine) is kept hidden every frame;
  -- a (re)opened instance is set up again by its piece (G.ForgetGaugeCopy from OnOpenLayer).
  function G.GaugeCopyCount(layer)
    if G.gaugeCopyCounts == nil then
      G.gaugeCopyCounts = {[G.TAG] = 1, [G.PT] = 5, [G.PTRULE] = 1, [G.SXBAR] = 1, [G.SXPLATE] = 1, [G.CSB] = 2,
        [G.FBADGE] = 3}
    end
    return G.gaugeCopyCounts[layer]
  end
  function G.IsGaugeCopyPlaced(layer, instance)
    if layer == G.PT and instance == 0 and G.emptyOn then
      return true
    end
    return G.ready[layer * 16 + instance] == true
  end
  function G.HideUnplacedGaugeCopies()
    G.GaugeCopyCount(G.TAG)
    for layer, count in pairs(G.gaugeCopyCounts) do
      if Exists(layer) then
        for instance = 0, count - 1 do
          if not G.IsGaugeCopyPlaced(layer, instance) and Cmd(C.IS_OPEN, layer, instance) == true then
            Cmd(C.VIS, layer, instance, false)
          end
        end
      end
    end
  end
  function G.ForgetGaugeCopy(layer, instance)
    if type(instance) ~= "number" or G.GaugeCopyCount(layer) == nil then
      return
    end
    G.ready[layer * 16 + instance] = false
    if layer == G.PT and instance == 0 then
      G.emptyOn = false
    elseif layer == G.FBADGE then
      G.fbKey = nil
    end
    Cmd(C.VIS, layer, instance, false)
  end

  -- ---- pointer (mouse / VR free cursor; docs/game/ui/mouse-support.md §5, EVT_PointerNew) ----------------------
  -- Our own drawn controls of the page get Lua zones (screen px, y down; the same numbers the layout / this block
  -- place them with): the 8 page dots (slot s: x 1321 + 28 (s - 1) .. + 32, the dots row y 915) and the Q / E glyphs
  -- beside them (if_plate_row_build.py: x 1281 / 1553) = go to that page / one page back / on, through the Q/E path of
  -- the menu that owns the page index (EVT_PPG_PointerPage: banks first, then the team dock / formation parents; with
  -- none, the plate's own step); on Pasivas the sub-page dots (G.PSUB_DOT_X) and the R3 glyph after them (x 1714)
  -- = that sub-page / the next one; on PERFIL the «R3 Cambiar forma» hint (x 1706.., y 893..947) = next form.
  -- No zone while the page is hidden, over a passive_config session (its own picker) or for hidden controls; a click
  -- on no zone does nothing; the dots have no keyboard focus, so hovering them changes nothing.
  --@lib evt_menu_kit.lua#Pointer
  G.PTR_DOT = {x0 = 1321, dx = 28, y = 895, h = 50}
  G.PTR_Q, G.PTR_E = {1258, 893, 62, 54}, {1551, 893, 56, 54}
  G.PTR_R3 = {1708, 893, 44, 54}
  G.PTR_FORM = {1706, 893, 214, 54}     -- round 15: the hint on the dots row from x 1713 (layout)
  G.BANKS = {@crc:chara_bank_menu_for_search@, @crc:chara_bank_menu@}
  function G.PtrGo(target, dir)
    local function Lc(...)
      local ok, v = pcall(funcLuaCommand, ...)
      return ok and v or nil
    end
    if type(target) == "number" then
      G.gotoT = 3                          -- the plate's own step too (a bank in its list view steps the plate)
      if VRFW_PlayerPages ~= nil then
        VRFW_PlayerPages.Goto(target)
      end
    end
    for pass = 1, 2 do
      for _, m in ipairs(pass == 1 and G.BANKS or G.PARENTS) do
        if Lc(264888438 --[[CMND_IS_EXIST_MENU]], m) == true then
          Lc(830228314, m, "EVT_PPG_PointerPage", target, dir, pass == 1)
          Lc(C.LOG, "EVT_PPG pointer page", string.format("%08X", m), tostring(target), dir)
          return
        end
      end
    end
    pcall(dir > 0 and SetPersonalPlateNextPage or SetPersonalPlatePrevPage)
  end
  function G.PtrForm()
    local M = EVT_PPM
    if G.ptype == G.HIPER_TYPE then        -- 2026-10-13: the Hiper page, Normal / the shown aura's form
      G.HiperToggle("click")
      return
    end
    if G.ptype == EVT_PPG_STATS_TYPE then  -- 2026-10-13: ATRIBUTOS, Normal / Miximax
      G.MxToggle("click")
      return
    end
    if G.ViewOffered() then                -- Formación: the hint is «Ver apariencia»
      pcall(M.OpenView, "click")
      return
    end
    if type(M) ~= "table" or M.phase ~= "ready" or EVT_PPM_PAGE_FORMS ~= true or type(M.forms) ~= "table"
        or #M.forms <= 1 or type(M.Fresh) ~= "function" then
      return
    end
    M.last = M.tick or 0
    M.fidx = (M.fidx or 1) % #M.forms + 1
    pcall(funcLuaCommand, 1917805374, 2629173176)   -- sy0009, as R3
    M.Fresh()
  end
  function G.Pointer()
    if G.gotoT ~= nil then
      G.gotoT = G.gotoT - 1
      if G.gotoT <= 0 then
        G.gotoT = nil
        if VRFW_PlayerPages ~= nil then
          VRFW_PlayerPages.Goto(nil)
        end
      end
    end
    local up = On() and G.ptype ~= nil and Exists(G.STATUS) and Cmd(C.IS_VIS, G.STATUS, 0) == true
      and not (type(UTIL_PPC) == "table" and UTIL_PPC.co ~= nil)
    if not up then
      G.ptrUp = false
      return
    end
    G.ptr = G.ptr or EVT_PointerNew()
    local P = G.ptr
    if not G.ptrUp then
      G.ptrUp = true
      P.Reset()
    end
    P.Begin()
    local D = G.PTR_DOT
    local pages = G.SlotPages()
    for s = 1, G.DOTS_MAX do
      if pages[s] ~= nil then
        P.Rect(D.x0 + D.dx * (s - 1) + 2, D.y, D.dx, D.h, s)
      end
    end
    P.Rect(G.PTR_Q[1], G.PTR_Q[2], G.PTR_Q[3], G.PTR_Q[4], "q")
    P.Rect(G.PTR_E[1], G.PTR_E[2], G.PTR_E[3], G.PTR_E[4], "e")
    local psub = G.ptype == 2 and not G.InOffice()
    if psub then
      for k = 2, 1 + G.PSUB_N do
        P.Rect(G.PSUB_DOT_X[k] + 2, D.y, D.dx, D.h, "p" .. (k - 2))
      end
      P.Rect(G.PTR_R3[1], G.PTR_R3[2], G.PTR_R3[3], G.PTR_R3[4], "r3")
    end
    local forms = type(EVT_PPM) == "table" and type(EVT_PPM.forms) == "table" and #EVT_PPM.forms or 0
    if G.ptype == EVT_PPG_DESC_TYPE and not G.InOffice() then
      local b = G.fbBox
      if G.ViewOffered() then
        P.Rect(G.PTR_FORM[1], G.PTR_FORM[2], G.PTR_FORM[3], G.PTR_FORM[4], "form")
      elseif forms > 1 and b ~= nil then
        P.Rect(b[1], b[2], b[3], b[4], "form")   -- 2026-10-12: the form badge (tiles + RS key)
      end
    elseif G.ptype == G.HIPER_TYPE and not G.InOffice() and G.fbBox ~= nil
        and (G.hiperTgt ~= nil or G.hiperDouble == true) then
      local b = G.fbBox
      P.Rect(b[1], b[2], b[3], b[4], "form")     -- 2026-10-13: the Hiper page's form badge
    elseif G.ptype == EVT_PPG_STATS_TYPE and not G.InOffice() and G.fbBox ~= nil and G.MxAvail() then
      local b = G.fbBox
      P.Rect(b[1], b[2], b[3], b[4], "form")     -- 2026-10-13: ATRIBUTOS' Normal / Miximax badge
    end
    local ev = P.Poll()
    local c = ev.click
    if c == nil then
      return
    end
    if type(c) == "number" then
      local cur = G.Slot(G.ptype)
      local target = pages[c]
      if cur ~= nil and c ~= cur and target ~= nil then
        G.PtrGo(target, c > cur and 1 or -1)
      end
    elseif c == "q" or c == "e" then
      G.PtrGo(nil, c == "e" and 1 or -1)
    elseif c == "r3" or string.sub(c, 1, 1) == "p" then
      local n = c == "r3" and (G.psub + 1) % G.PSUB_N or tonumber(string.sub(c, 2))
      if n ~= nil and n ~= G.psub then
        G.psub = n
        G.plast = G.ptick or 0
        pcall(funcLuaCommand, 1917805374, 2500047763)
      end
    elseif c == "form" then
      G.PtrForm()
    end
  end

  local function Description(on)
    on = on and not G.InOffice()           -- over the transfer office: its own description only
    Cmd(C.NODE_VIS, G.PLATE, G.N_EXPLAIN, on, 0)
    Cmd(C.TEXT_VIS, G.PLATE, G.N_EXPLAIN, on, 0)
    if Cmd(C.IS_OPEN, G.BAND, 0) == true then
      Cmd(C.MESH, G.BAND, G.M_FLAVOR, on, 0)
    end
  end

  function G.Apply(ptype)
    -- 2026-10-14 (owner: the armour / miximax look chosen on the Hiper page, ATRIBUTOS or PERFIL stayed on the next
    -- page): a form look belongs only to the page that chose it. Another page = the model back to Normal, hidden at
    -- once and rebuilt before the new page draws (plate_model M.ResetForm); the same page again (a player change, a
    -- refresh) keeps it. Entering ATRIBUTOS / the Hiper page then starts Normal (G.MxStep / G.HiperFormStep read
    -- the model's form).
    if G.ptype ~= nil and ptype ~= G.ptype and type(EVT_PPM) == "table" and type(EVT_PPM.ResetForm) == "function" then
      pcall(EVT_PPM.ResetForm, "page " .. tostring(G.ptype) .. " -> " .. tostring(ptype), true)
    end
    G.ptype = ptype
    EVT_PPM_PAGE_OK = true                -- round 4: the model on every page, behind the content
    EVT_PPM_PAGE_FORMS = (ptype == EVT_PPG_DESC_TYPE)   -- round 8: R3 cycles the forms on PERFIL
    local desc, stats, moves = ptype == EVT_PPG_DESC_TYPE, ptype == EVT_PPG_STATS_TYPE, ptype == 1
    if desc or stats then
      pcall(SetVisibleSkillItemLayer, false)
    end
    if not stats then                      -- the chart only on ATRIBUTOS (the equipment pages showed the radar)
      pcall(SetVisibleGraphLayer, false)
      if type(EVT_R9) == "table" and type(EVT_R9.Visible) == "function" then
        pcall(EVT_R9.Visible, false)
      end
      BarsVisible(false)
    end
    for _, m in ipairs(G.M_PARAM) do
      Cmd(C.MESH, G.PAGE, m, false, 0)
    end
    HidePoly()
    Decor(ptype)
    Description(desc)
    if ptype ~= 5 then
      EVT_PH_MX_VIEW = false
    end
    G.Equip()
    G.Bars()
    G.Dots()
    -- 2026-10-12 (owner: Q / E between SUPERTÉCNICAS and ATRIBUTOS showed the 6 move plates for one frame in the
    -- retail vertical column): the 2 | 2 | 2 arrangement was only applied from PostStep, a frame after the retail page
    -- change had shown the plates at their retail place (and the retail place came back a frame late the other way).
    -- Now it is applied in the same call as the page change, and again whenever a move plate instance opens
    -- (OnOpenLayer below), before anything is drawn.
    pcall(G.Moves)
  end

  -- page types 8 / 9 = type 1 adjusted; every page goes through Apply
  EVT_PPG_Wrap("ChangePersonalPlatePageByCharaHdl", function(orig)
    return function(a1, a2, ...)
      if not On() or not G.H.pages then
        return orig(a1, a2, ...)
      end
      local base = (a2 == EVT_PPG_DESC_TYPE or a2 == EVT_PPG_STATS_TYPE) and 1 or a2
      local r = Pack(orig(a1, base, ...))
      local ok, err = pcall(G.Apply, a2)
      if not ok then
        pcall(funcLuaCommand, C.LOG, "plate_pages apply error", tostring(err))
      end
      return table.unpack(r, 1, r.n)
    end
  end)
  EVT_PPG_Wrap("ChangePersonalPlatePageByCharaParamId", function(orig)
    return function(a1, a2, ...)
      if not On() or not G.H.pages then
        return orig(a1, a2, ...)
      end
      local base = (a2 == EVT_PPG_DESC_TYPE or a2 == EVT_PPG_STATS_TYPE) and 1 or a2
      local r = Pack(orig(a1, base, ...))
      pcall(G.Apply, a2)
      return table.unpack(r, 1, r.n)
    end
  end)

  -- the radar's values -> the bars (whichever page shows the radar)
  EVT_PPG_Wrap("UpdateCharaParameterGraphByCharaStHdl", function(orig)
    return function(a1, a2, a3, ...)
      local r = Pack(orig(a1, a2, a3, ...))
      if On() and a1 == G.RADAR and not G.hostShut then
        -- hosts: the same retail fill on OUR chart (tags, the 7 numbers on evt_pp_num_host)
        if not G.H.pages and G.H.chart ~= false and Exists(G.GRAPH) and Exists(G.NUM) and not G.filling then
          G.filling = true
          pcall(orig, a1, G.NUM, a3, G.GRAPH)
          G.filling = false
        end
        local rest = Pack(...)
        local okv, v = pcall(G.Values, a3, rest[5])
        if okv then
          G.vals = v
          pcall(G.Tops, a3)
          pcall(G.MxGains, a3)
        end
        pcall(HidePoly)
        pcall(G.Bars)
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  -- every refresh of the header plate: the same player on the slant copy
  EVT_PPG_Wrap("UpdateCharaStatusPlateInfoByCharaStHdl", function(orig)
    return function(a1, a2, a3, ...)
      local r = Pack(orig(a1, a2, a3, ...))
      if not G.busy and a1 == G.PLATE and (a2 == nil or a2 == 0) then
        G.hdl = a3
        pcall(G.SlantFill)
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  -- every frame: the band copy, the bars and the description follow the page
  -- 2026-10-06 (in game: leaving Equipamiento opened the retail general_window and nothing more, the game stuck): on a
  -- host without pages (equip_menu, evt_skill_slot_menu) this block does NOTHING while a dialog / another screen is
  -- up (general_window, ability_list_menu, a closing menu) and hides its own layers once; transitions logged
  -- («EVT_PPG host idle <why>» / «EVT_PPG host active»). EVT_PPG_HOST_OFF = true turns the block off on these hosts.
  G.IDLE_MENUS = {449578137 --[[general_window]], 1810526795 --[[ability_learning_board_menu]],
    @crc:ability_list_menu@, @crc:chara_bank_menu_for_search@}
  function G.HostIdle()
    if EVT_PPG_HOST_OFF == true then
      return "off"
    end
    for _, m in ipairs(G.IDLE_MENUS) do
      local ok, v = pcall(funcLuaCommand, 264888438 --[[CMND_IS_EXIST_MENU]], m)
      if ok and v == true then
        return string.format("menu %08X", m)
      end
    end
    return nil
  end
  -- 2026-10-06 (in game: Esc on the skill table closed every retail layer, the bar chart stayed drawn and the menu
  -- never finished closing): every added layer closed (the chart's too), and nothing reopened while the host menu is
  -- closing / closed (G.hostShut, PostStep below)
  G.HOST_LAYERS = {G.BAND, G.SLANT, G.TAG, G.BAR, G.EXTRA, G.GRAPH, G.NUM}
  local CMD_IS_CLOSING_MENU, CMD_IS_CLOSED_MENU = 1193349555, 1521844538   -- CMND_IS_CLOSING / CLOSE_MENU_OBJECT
  function G.HostClosing()
    local m = G.H.menu
    if m == nil then
      return false
    end
    local ok1, c1 = pcall(funcLuaCommand, CMD_IS_CLOSING_MENU, m)
    local ok2, c2 = pcall(funcLuaCommand, CMD_IS_CLOSED_MENU, m)
    return (ok1 and c1 == true) or (ok2 and c2 == true)
  end
  function G.HostCloseOurs(why)
    local n = 0
    for _, l in ipairs(G.HOST_LAYERS) do
      if Exists(l) then
        local open = false
        for k = 0, 15 do
          if Cmd(C.IS_OPEN, l, k) == true then
            Cmd(C.VIS, l, k, false)
            open = true
          end
        end
        if open then
          Cmd(1273612389 --[[CMND_CLOSE_LAYER, once per layer]], l)
          n = n + 1
        end
      end
    end
    G.ready = {}
    G.rateInit = {}
    pcall(funcLuaCommand, C.LOG, "EVT_PPG host closed ours", tostring(why), n)
  end
  -- the host menu closing: our layers shut once and kept shut (nothing of ours for the menu's close to wait on)
  -- (CMND_CLOSE_LAYER once per layer: closed on the first frame only, then simply never reopened)
  function G.HostShut(why)
    if G.hostShut then
      return
    end
    G.hostShut = true
    pcall(funcLuaCommand, C.LOG, "EVT_PPG host shut", tostring(why))
    pcall(G.HostCloseOurs, why)
  end
  function G.HostHide()
    for _, l in ipairs({G.BAND, G.SLANT, G.TAG}) do
      if Exists(l) and Cmd(C.IS_OPEN, l, 0) == true then
        Cmd(C.VIS, l, 0, false)
      end
    end
    BarsVisible(false)
  end

  -- the per-frame body: after the screen's PostStep; a host whose screen has none (evt_skill_slot_menu, a copy of
  -- equip_menu_select: no PostStep, so this body never ran there and the retail page body / description box / radar
  -- stayed on its right page) names the function it runs after in its host table (frame_hook = "Step"; 2026-10-14)
  function G.FrameWrap(orig)
    return function(...)
      local r = Pack(orig(...))
      if not G.H.pages and EVT_PPG_HOST_OFF == true then
        return table.unpack(r, 1, r.n)          -- the block off on this host: the screen exactly as retail
      end
      if not G.H.pages then
        local okC, closing = pcall(G.HostClosing)
        if okC and closing then
          pcall(G.HostShut, "closing")          -- never Ready() / reopen anything while the host menu closes
          return table.unpack(r, 1, r.n)
        elseif G.hostShut then
          G.hostShut = false                    -- the close did not happen (a back swallowed): drawn again
          pcall(funcLuaCommand, C.LOG, "EVT_PPG host reopened")
        end
        local okI, why = pcall(G.HostIdle)
        why = okI and why or nil
        if why ~= G.hostIdle then
          G.hostIdle = why
          pcall(funcLuaCommand, C.LOG, why and ("EVT_PPG host idle " .. why) or "EVT_PPG host active")
          -- 2026-10-07 (Nacho: a yes / no window over the skill table's training view made the name banner, the white
          -- card and the band vanish): a dialog (general_window) only pauses this block, our layers stay drawn under
          -- its dimmer; another screen on top (picker, bank, board) still hides them
          if why and why ~= string.format("menu %08X", 449578137 --[[general_window]]) then
            pcall(G.HostHide)
          end
        end
        if why then
          return table.unpack(r, 1, r.n)
        end
      end
      if G.H.pages then
        pcall(G.Empty)
        -- round 14b (Nacho: the hexagon / circuit art showed on Trayectoria): the six-sense page decoration
        -- _sixth_base01 off on every page (only that retail page used it, and it is ours now)
        if On() and Exists(G.STATUS) and Cmd(C.IS_OPEN, G.STATUS, 0) == true then
          Cmd(C.MESH, G.STATUS, @crc:_sixth_base01@, false, 0)
        end
      else
        if G.ptype == nil then
          G.ptype = G.H.fixed              -- a host without pages: the chart page's look
        end
        -- 2026-10-06 (shots 365 / 366: the hexagon / circuit art over the right half): the same decoration off on
        -- the hosts' status base, as on the player page
        if On() and Exists(G.STATUS) and Cmd(C.IS_OPEN, G.STATUS, 0) == true then
          Cmd(C.MESH, G.STATUS, @crc:_sixth_base01@, false, 0)
        end
      end
      pcall(G.Band)
      pcall(G.Slant)
      pcall(G.Tag)
      pcall(G.HideUnplacedGaugeCopies)
      if On() and Exists(G.BUILD_GUIDE) and Cmd(C.IS_OPEN, G.BUILD_GUIDE, 0) == true then
        Cmd(C.VIS, G.BUILD_GUIDE, 0, false)        -- «Configuración habitual» (Tab ⇆ ?): retired
      end
      if On() then
        if G.ptype ~= nil and G.H.pages then
          pcall(Decor, G.ptype)
        end
        pcall(G.Bars)
        if G.H.pages then
          pcall(G.Dots)
          pcall(G.MxStep)
          pcall(G.HiperFormStep)
          pcall(G.Equip)
          pcall(G.HiperL3)
          pcall(G.Moves)
          pcall(G.MovesNav)
          pcall(G.Hint)
          pcall(G.FormBadge)
          pcall(G.Passives)
          pcall(G.PassiveRows)
          pcall(G.Career)
          pcall(G.Sixth)
          local okP, errP = pcall(G.Pointer)
          if not okP and not G.ptrErr then
            G.ptrErr = true
            pcall(funcLuaCommand, C.LOG, "EVT_PPG pointer error", tostring(errP))
          end
        else
          pcall(G.HostNumbers)       -- a host without pages: Suerte's number (the description stays hidden below)
        end
        if not G.KeepRadar() then
          pcall(HidePoly)
        end
        if G.ptype ~= nil then
          pcall(Description, G.ptype == EVT_PPG_DESC_TYPE)
        end
      end
      return table.unpack(r, 1, r.n)
    end
  end
  G.FRAME_HOOK = "PostStep"
  if not G.H.pages and type(G.H.frame_hook) == "string" and type(rawget(_ENV, "PostStep")) ~= "function" then
    G.FRAME_HOOK = G.H.frame_hook
  end
  EVT_PPG_Wrap(G.FRAME_HOOK, G.FrameWrap)
  if not G.H.pages then
    for _, fname in ipairs({"OnBack", "FuncOnBack"}) do
      EVT_PPG_Wrap(fname, function(orig)
        return function(...)
          local r = Pack(orig(...))             -- the original first
          pcall(funcLuaCommand, C.LOG, "EVT_PPG host " .. fname, tostring((...)))
          -- round 14e: our layers closed at the exit (nothing of ours left for the menu's close to wait on);
          -- 2026-10-06: every added layer (chart included), and kept shut by PostStep while the menu closes. A back
          -- that does not close the menu (a dialog, an action running) leaves ours alone
          local okC, closing = pcall(G.HostClosing)
          if G.H.menu == nil or (okC and closing) then
            pcall(G.HostShut, fname)
          end
          return table.unpack(r, 1, r.n)
        end
      end)
    end
  end

  -- 2026-10-12: a move plate (or its blank) opened while SUPERTÉCNICAS is up is put in its 2 | 2 | 2 place at once.
  -- 2026-10-14: on every host, a gauge copy instance that (re)opens is hidden and set up again by its piece
  EVT_PPG_Wrap("OnOpenLayer", function(orig)
    return function(a1, a2, ...)
      if a1 == G.SLANT then
        pcall(G.SlantOpened, a2)             -- before anything of it is drawn
      end
      local r = Pack(orig(a1, a2, ...))       -- the original first
      if G.H.pages and (a1 == G.SKILL or a1 == G.SKILL_BLANK) and On() and G.ptype == 1 then
        pcall(G.Moves)
      end
      pcall(G.ForgetGaugeCopy, a1, a2)
      return table.unpack(r, 1, r.n)
    end
  end)

  -- SUPERTÉCNICAS: the confirmation mode's key steps follow the 3-row page (G.NavOnChange)
  if G.H.pages then
    EVT_PPG_Wrap("OnChangeFocus", function(orig)
      return function(a1, a2, ...)
        local ok, handled = pcall(G.NavOnChange, a1, a2)
        if ok and handled then
          return
        end
        return orig(a1, a2, ...)
      end
    end)
    for _, name in ipairs({"SetSkillCollisionEnable", "UpdateSkillItemHitCollision"}) do
      EVT_PPG_Wrap(name, function(orig)
        return function(a1, ...)
          local r = Pack(orig(a1, ...))         -- the original first
          if name ~= "SetSkillCollisionEnable" or a1 == true then
            pcall(G.NavZones)
          end
          return table.unpack(r, 1, r.n)
        end
      end)
    end
  end

  EVT_PPG_Wrap("OnCloseLayer", function(orig)
    return function(a1, ...)
      local r = Pack(orig(a1, ...))
      if a1 == G.PAGE then
        G.ready = {}
        G.rateInit = {}
        G.vals = nil
        EVT_PH_MX_VIEW = false
        BarsVisible(false)
        G.movesOn = true                    -- next page: the slot nodes back to retail
        pcall(G.FbHide)
        for _, l in ipairs({G.BAND, G.SLANT, G.TAG, G.FLABEL}) do
          if Cmd(C.IS_OPEN, l, 0) == true then
            Cmd(C.VIS, l, 0, false)
          end
        end
      end

      return table.unpack(r, 1, r.n)
    end
  end)

  -- 2026-10-12 (owner, shot of the match / half-time «Formación»: the header row and the description card ~31 px
  -- higher than on Plantilla, the name row at the top of the green band): in a match the page runs as plate type 1
  -- (soccer_formation_menu_inc OnInitFormationCommon -> SetPersonalPlateType(1) when GetSoccerTeamInfo answers), and
  -- personal_plate_inc OnSetupPersonalPlateLayer then plays the page's offset01 anim in state 0 (the retail match
  -- placement) instead of state 2 (rest, every other screen). Every layer attached to the page (header plate, band
  -- copy, status base) moves with it; the slanted band (evt_pp_slant, screen-placed) does not, and the page's whole layout
  -- (player_page_layout.toml) is measured for state 2. So on the plate type 1 the page gets the state-2 offset
  -- right after the retail setup, exactly the retail sequence for the other types: the match page = the Plantilla
  -- page. EVT_PPG_MATCH_OFFSET = false keeps the retail match placement. loader.log «EVT_PPG match offset <idx>».
  -- (2026-10-13: this block sat inside the OnCloseLayer wrapper's body, so the two wraps were installed only at the
  -- first layer close, after OnInit's SetPersonalPlateType(1): G.plateType was never 1 and the offset never ran.)
  if G.H.pages then
    function G.DockOffset(l, i)
      local OFS, DEF = 902337421, 753088835       -- offset01, Default
      local id = Cmd(1352645570, l, OFS, i)
      if Cmd(1914009721, l, id, DEF, 0, i) ~= true then   -- CMND_IS_END_ANIME of the state-0 clip
        Cmd(1380315136, l, i, OFS, 0, DEF)
        Cmd(335638325, l, id, DEF, i)                      -- CMND_STOP_ANIME
      end
      Cmd(3781155141, l, i, OFS, 2, DEF)                   -- CMND_PLAY_ANIME_TYPE offset01 state 2
      pcall(funcLuaCommand, C.LOG, "EVT_PPG match offset", tostring(i))
    end
    EVT_PPG_Wrap("SetPersonalPlateType", function(orig)
      return function(a1, ...)
        G.plateType = a1
        return orig(a1, ...)
      end
    end)
    EVT_PPG_Wrap("OnSetupPersonalPlateLayer", function(orig)
      return function(a1, a2, ...)
        local r = Pack(orig(a1, a2, ...))      -- the original first
        if a1 == G.PAGE and G.plateType == 1 and EVT_PPG_MATCH_OFFSET ~= false then
          pcall(G.DockOffset, a1, a2 or 0)
        end
        return table.unpack(r, 1, r.n)
      end
    end)
  end
end)()
-- ===== EVT plate_pages plate END =====
