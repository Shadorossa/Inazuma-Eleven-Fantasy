-- ===== EVT plate_pages plate BEGIN =====
-- ONE block for every host of the player page (2026-10-13, owner: no more copies): personal_plate_menu (host_plate.lua,
-- pages = true: the whole paged player page) and the hosts with their own copy of the plate, Equipamiento
-- (equip_menu_select, host_equip.lua) and Tabla de habilidades (evt_skill_slot_menu, host_skill.lua), pages = false:
-- the header row (shared VRFW_UI.HeaderRow), the white card and the bar chart on the hosts' OWN added layers
-- (Character Reforged content/menus/player_page_layout.toml «host look»: evt_pp_graph_host / _hostx /
-- evt_pp_num_host), the hosts' page layer
-- retail. The hosts' fork plate_host_look.lua (2026-10-06..13) is merged back here: its host-only parts run where
-- G.H.pages is false, everything else is the same code.
-- The pieces of each page kind are in parts\*.lua, placed at their placeholder lines by graft.toml (include order).
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
  -- a screen with only the item card (inventory, shop: G.H.item_only): only the item card's wrappers and the frame;
  -- the player page's wrappers never touch that screen's own functions
  local EVT_PPG_Wrap = EVT_PPG_Wrap
  if G.H.item_only then
    local wrap = EVT_PPG_Wrap
    local only = {SetupItemPositionIcon = true, ClearItemPositionIcon = true, OnSetupLayer = true, OnOpenLayer = true,
      OnBack = true, FuncOnBack = true, PostStep = true, [G.H.frame_hook or "Step"] = true}
    EVT_PPG_Wrap = function(name, make)
      if only[name] then
        return wrap(name, make)
      end
      return false
    end
  end
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
    G.CHART_AT = G.H.chart_at or {1452, 746}  -- the chart's centre on the card (screen; our layers are unattached)
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
  G.FOCUS_ACTIVE, G.FOCUS_IDX = @crc:CMND_IS_CTRL_FOCUS_ACTIVE@, 2603265800
  G.TX_BTL0613, G.SP_FRAME, G.SP_BAR = 1191797350, 538967808, @crc:evt_pp_bar01@
  -- Character Reforged's own atlas evt_cr_page (#/menu/102_team/team11/evt_cr_page/evt_cr_page.g4tx): every evt_pp_* sprite the page swaps in
  G.TX_OWN = 387834804
  G.M_ARROWS = {1811606789, 2448805990}   -- _arrow01_l / _r
  G.EQUIP_SCALE = 0.72                   -- round 9: 409 px wide (inside the white card)
  -- Hiper page L3: the aura slot / the mix slot (EVT_PH_MX_VIEW of plate_hiper; was the keshin a miximax gave)
  G.L3 = {CHECK = @crc:CMND_CHECK_INPUT_CMD@, CTRL = 1332654303, CTRL_AN = 2748927068, CMD = 579943758}
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
  local C = {EXIST = @crc:CMND_IS_EXIST_LAYER@, OPEN = @crc:CMND_OPEN_LAYER@, IS_OPEN = @crc:CMND_IS_OPEN_LAYER@, LOADING = @crc:CMND_IS_LOADING_LAYER@, VIS = @crc:CMND_SET_LAYER_VISIBLE@,
    IS_VIS = @crc:CMND_IS_LAYER_VISIBLE@, POS = @crc:CMND_SET_LAYER_LOCAL_POS@, SCALE = @crc:CMND_SET_LAYER_LOCAL_SCALE@, MESH = @crc:CMND_SET_MESH_VISIBLE@, TRACE = @crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@,
    RATE_INIT = 541357333, RATE = 1595998683, SPRITE = 558735651, TEXT_VIS = @crc:CMND_SET_MENU_TEXT_VISIBLE@, NODE_VIS = 2158717427,
    SET_TEXT = @crc:CMND_SET_MENU_TEXT_STRING@, PRIM_VIS = 1233047821, NODE_POS = 2575768773, NODE_SCALE = 2885415772,
    CHARA = 1131797651,
    LOG = @crc:CMND_EVT_LOG@}
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

  -- a per-frame / event piece called by name: a missing function or an error is written to loader.log once per name
  -- («EVT_PPG call <name> ...»); a piece of the item card (name ItemCard*) that fails is not called again this session
  G.tryLogged, G.tryOff = G.tryLogged or {}, G.tryOff or {}
  function G.Try(name, ...)
    if G.tryOff[name] then
      return nil
    end
    local f = G[name]
    if type(f) ~= "function" then
      if not G.tryLogged[name] then
        G.tryLogged[name] = true
        pcall(funcLuaCommand, C.LOG, "EVT_PPG call " .. name .. ": no such function")
      end
      return nil
    end
    local ok, a, b = pcall(f, ...)
    if not ok then
      if not G.tryLogged[name] then
        G.tryLogged[name] = true
        pcall(funcLuaCommand, C.LOG, "EVT_PPG call " .. name .. " failed: " .. tostring(a))
      end
      if string.sub(name, 1, 8) == "ItemCard" then
        G.tryOff[name] = true
      end
      return nil
    end
    return a, b
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

@PP_BAND@

@PP_DOTS@

@PP_MOVES@

@PP_PASSIVES@

@PP_CAREER@

@PP_HOST_CHART@

@PP_EMPTY_EQUIPMENT_HIPER@

@PP_STAT_ROWS@

@PP_FORMS@

@PP_GAUGE_COPIES@

@PP_POINTER@

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
      local ok, v = pcall(funcLuaCommand, @crc:CMND_IS_EXIST_MENU@, m)
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
  local CMD_IS_CLOSING_MENU, CMD_IS_CLOSED_MENU = @crc:CMND_IS_CLOSING_MENU_OBJECT@, @crc:CMND_IS_CLOSE_MENU_OBJECT@   -- CMND_IS_CLOSING / CLOSE_MENU_OBJECT
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
        for k = 0, 63 do
          if Cmd(C.IS_OPEN, l, k) == true then
            Cmd(C.VIS, l, k, false)
            open = true
          end
        end
        if open then
          Cmd(@crc:CMND_CLOSE_LAYER@ --[[CMND_CLOSE_LAYER, once per layer]], l)
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
          G.Try("HostShut", "closing")          -- never Ready() / reopen anything while the host menu closes
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
            G.Try("HostHide")
          end
        end
        if why then
          return table.unpack(r, 1, r.n)
        end
      end
      if G.H.item_only then
        -- a screen with only the item card (inventory, shop): its layout when its layer opened, and Y
        if G.itemCardPending then
          G.Try("ItemCardPending")
        end
        G.Try("ItemCardInput")
        return table.unpack(r, 1, r.n)
      end
      if G.H.pages then
        G.Try("Empty")
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
      G.Try("Band")
      G.Try("Slant")
      G.Try("Tag")
      G.Try("HideUnplacedGaugeCopies")
      if On() and Exists(G.BUILD_GUIDE) and Cmd(C.IS_OPEN, G.BUILD_GUIDE, 0) == true then
        Cmd(C.VIS, G.BUILD_GUIDE, 0, false)        -- «Configuración habitual» (Tab ⇆ ?): retired
      end
      if On() then
        if G.ptype ~= nil and G.H.pages then
          pcall(Decor, G.ptype)
        end
        G.Try("Bars")
        if G.H.pages then
          G.Try("Dots")
          G.Try("MxStep")
          G.Try("HiperFormStep")
          G.Try("Equip")
          G.Try("HiperL3")
          G.Try("Moves")
          G.Try("MovesNav")
          G.Try("Hint")
          G.Try("FormBadge")
          G.Try("Passives")
          G.Try("PassiveRows")
          G.Try("Career")
          G.Try("Sixth")
          local okP, errP = pcall(G.Pointer)
          if not okP and not G.ptrErr then
            G.ptrErr = true
            pcall(funcLuaCommand, C.LOG, "EVT_PPG pointer error", tostring(errP))
          end
        else
          G.Try("HostNumbers")       -- a host without pages: Suerte's number (the description stays hidden below)
          if G.itemCardPending then
            G.Try("ItemCardPending") -- the item card's layout when its layer opened after the last fill
          end
          G.Try("ItemCardInput")     -- L2 / R2 on a paged item card
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
      if G.ItemCardLayer ~= nil and a1 == G.ItemCardLayer then
        G.itemCardPending = true             -- laid out by the next frame (the layer is open by then)
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  -- ---- a host's item detail card (host table item_card: Equipamiento) --------------------------------------------
  -- The retail card team05_02_equip_info_easy laid out around every SetupEquipInfoWindow: its nodes moved / sized
  -- from the host table, its body given the stats panel's sprite. Its bonus lines are signed («-10», never «+-10»),
  -- coloured (raise / lowering) and joined in one row. Pages turned with L2 / R2 («L2 · · R2» row at the card's
  -- bottom): the bonuses, then Better Equipment's «Efecto» page (CMND_BETTEREQUIPMENT_ITEM_PAGE: passive, set,
  -- affinity) and «Conjunto» page (CMND_BETTEREQUIPMENT_ITEM_SET: the set's pieces worn / owned / missing and its
  -- tiers), each only when the item has it. The stats panel's rows the focused item raises / lowers get a green / red
  -- outline and number. Nothing changes while the block is off.
  local IC = not G.H.pages and type(G.H.item_card) == "table" and G.H.item_card or nil
  if IC ~= nil then
@PP_ITEM_CARD@

@PP_ITEM_CARD_LAYERS@

@PP_ITEM_CARD_EFFECT@

@PP_ITEM_CARD_STAT_ROWS@

@PP_ITEM_CARD_SHOW@
  end

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
      if Cmd(@crc:CMND_IS_END_ANIME@, l, id, DEF, 0, i) ~= true then   -- CMND_IS_END_ANIME of the state-0 clip
        Cmd(1380315136, l, i, OFS, 0, DEF)
        Cmd(@crc:CMND_STOP_ANIME@, l, id, DEF, i)                      -- CMND_STOP_ANIME
      end
      Cmd(@crc:CMND_PLAY_ANIME_TYPE@, l, i, OFS, 2, DEF)                   -- CMND_PLAY_ANIME_TYPE offset01 state 2
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
