-- ===== EVT pset_preview BEGIN ===== (research/grafts/pset_preview, docs/game/skill-slots.md "Set preview: plate pages")
-- «Set de jugador» preview v3 (2026-09-28, user after the in-game tests of v1 / v2: the pages must look IDENTICAL
-- to the player plate's pages, screenshots 104 / 105): while the Sets list is open, the focused set is shown as the
-- plate's pages: the retail page base with the retail locators (research/scripts/pset_preview_build.py, evt_psp_base),
-- the plate's title / arrow colour (retail UpdateFormationStatusBaseMatColor), 5 dots as the plate, the Q / E glyphs:
--   page 1 ATRIBUTOS                the plate's ATRIBUTOS page: retail title, radar left WITH THE SET'S STATS (v4) +
--                                   the 6 moves: retail move rows (evt_psp_move, retail SetupCharaSkillItem), the
--                                   1 / 2 / 3 slot badges, the «IA» tags (evt_psp_ai, drawn by the retail fill)
--   page 2 HIPERTÉCNICA             the Hiper the way the plate's Hiper page shows it: the screen's Hiper panel
--                                   (PL.HiperShow, the plate page's recipe); no Hiper = the retail blank move row
--   page 3 EQUIPAMIENTO             radar left + the 6 rpg equipment plates: 5 items + the role on the laurel plate
--   page 4 PASIVAS DE EQUIPO        evt_psp_pv 0..4     the 5 configured passives (soccer11_20 rows)
--   page 5 PASIVAS PERSONALIZADAS   evt_psp_six 0       the custom passive (team00_28 six-sense window)
-- The radar is the screen's own: on pages 1 / 3 its attach moves to our page base (CMND_SET_LAYER_ATTACH_LOCATOR_TRACE,
-- as the retail menus switch attach sets) and back when the page / preview goes; on the other pages it is hidden
-- (PL.hiper_wide, as the wide Hiper panel does).
-- v4 (2026-09-28, Nacho: «donde los sets también tiene que estar la rueda de stats correspondiente a ese set»): on
-- pages 1 / 3 the radar shows the stats the player would have WITH THE SET: shown stat - the current equipment's
-- bonus + the set's equipment bonus (retail CMND_GET_EQUIP_PARAM per item and stat, as the retail equipment preview
-- UpdateCharaParameterGraphNextItemByCharaStHdl does for one item), drawn by the retail
-- UpdateCharaParameterGraphNextBeansByCharaStHdl: the numbers are the set's, the retail arrows mark the change
-- against the current build. Sets do not store stat training yet (board_presets.rs `training`: reserved, never
-- written): the training part is the player's current one. Page 1's title is the retail «ATRIBUTOS» (as the plate).
-- Q / E (L1 / R1) and left / right change the page (PL.PopList mode.step, hook in ss2_menus); the cursor stays on the
-- list and the page is kept while it moves. Empty set: no page frame, two hint lines.
-- The set also stores the configured passives and the role: vr-loader CMND_EVT_PSET_FULL / CMND_EVT_PSET_SET2
-- (board_presets.rs, file v3); an older loader keeps the v2 behaviour (GET / SET, passives and role «not saved»).
-- Loading applies them too (PL.SetLoadExtra, called by PL.SetLoad of ss2_menus before EVT_AfterChange).
-- Without the layers (setting not deployed) PL.SetFocus falls back to the previous summary panel.
-- No new main-chunk locals (184 already): everything lives in EVT_PSP, installed by one function.
do
  EVT_PSP = EVT_PSP or {}
  function EVT_PSP.Install()
    local P = EVT_PSP
    if P.installed or PL == nil then
      return
    end
    P.installed = true
    P.CMD_FULL = @crc:CMND_EVT_PSET_FULL@
    P.CMD_SET2 = @crc:CMND_EVT_PSET_SET2@
    P.CMD_PC_INFO = @crc:CMND_UTIL_PC_INFO@
    P.CMD_PC_SLOT = @crc:CMND_UTIL_PC_SLOT@
    P.CMD_PC_SET = @crc:CMND_UTIL_PC_SET@
    P.CMD_ROLE_SET = 885127448                     -- CMND_EVT role set (charaStHdl, role) -> status, now
    P.L_BASE = @crc:evt_psp_base@
    P.L_MOVE = @crc:evt_psp_move@
    P.L_EQUIP = @crc:evt_psp_equip@
    P.L_PV = @crc:evt_psp_pv@
    P.L_SIX = @crc:evt_psp_six@
    P.L_AI = @crc:evt_psp_ai@
    P.COUNT = {[P.L_MOVE] = 7, [P.L_AI] = 7, [P.L_EQUIP] = 6, [P.L_PV] = 5, [P.L_SIX] = 1}
    P.PAGES = 5
    P.page = 1
    -- page base (soccer11_05 layout): titles, dots, arrows, keys
    P.TX_S1105 = 1156047165                        -- #/menu/00_soccer/soccer11/soccer11_05/<LG>/soccer11_05.g4tx
    P.M_TITLE = @crc:_gtxt_sixthsense01@
    P.S_TITLE = @crc:gtxt_sixthsense01@            -- the title mesh's texture slot (= its retail sprite)
    P.TITLE_SPR = {@crc:gtxt_parameters01@, @crc:evt_gtxt_hiper01@, @crc:evt_gtxt_psequip01@,
      @crc:gtxt_teampassives01@, @crc:gtxt_sixthsense01@}
    P.M_TITLES_OFF = {@crc:_gtxt_parameters01@, @crc:_gtxt_parameters02@, @crc:_gtxt_parameters01_rpg@,
      @crc:_gtxt_parameters02_rpg@, @crc:_gtxt_teampassives01@, @crc:_cmd_slot01_rpg@, @crc:_cmd_slot02_rpg@,
      @crc:_cmd_slot03_rpg@}
    P.M_SLOTS = {@crc:_cmd_slot01@, @crc:_cmd_slot02@, @crc:_cmd_slot03@}     -- the 1 / 2 / 3 badges (page 1)
    -- 5 dots as the plate (our layout: _page02_on_rpg drawn with the "off" material is the 5th off dot)
    P.M_DOTS_OFF = {@crc:_page01_off@, @crc:_page02_off@, @crc:_page03_off@, @crc:_page04_off@, @crc:_page02_on_rpg@}
    P.M_DOTS_ON = {@crc:_page01_on@, @crc:_page01_on_rpg@, @crc:_page02_on@, @crc:_page03_on@, @crc:_page04_on@}
    -- the plate's title / arrow colour (retail UpdateFormationStatusBaseMatColor)
    P.MAT_COLOR = 635730757
    P.MATS = {@crc:arrow01_r_mat_01@, @crc:arrow01_l_mat_01@, @crc:gtxt_sixthsense01_mat_01@}
    P.RGB = {0.38823529411764707, 0.49019607843137253, 0.615686274509804}
    -- the screen's radar: attach names on the screen's status base (active set by flag6, as its OnSetupLayer) / ours
    P.L_STATUS = 2917320188                        -- soccer11_05_equip_status_base
    P.RADAR_SCREEN_A = {162250999, 2091397827}
    P.RADAR_SCREEN_B = {2810680323, 1707903547}
    P.RADAR_MINE = {@crc:evt_psp_graph_base@, @crc:evt_psp_graph@}
    P.ATTACH = 1774843228                          -- CMND_SET_LAYER_ATTACH_LOCATOR_TRACE (layer, idx, name, on)
    P.radar_mine = false
    P.M_ARROWS = {@crc:_arrow01_l@, @crc:_arrow01_r@}
    P.T_KEYS = {@crc:_text_btn_l01@, @crc:_text_btn_r01@}
    P.M_SIXTH_BASE = @crc:_sixth_base01@
    P.K_L1 = 3966226594                            -- CMD_FUNCL1 (Q)
    P.K_R1 = 942075773                             -- CMD_FUNCR1 (E)
    P.K_LEFT = 2765147006                          -- CMD_LEFT
    P.K_RIGHT = 2075023265                         -- CMD_RIGHT
    -- the set's stats on the radar (v4): the screen's radar layers (soccer11_07 radar, its numbers, soccer11_06 base)
    P.GRAPH = {2334590304, 732343773, 32151736}
    P.EQUIP_PARAM = 2207870782                     -- CMND_GET_EQUIP_PARAM (item, stat type 0..6) -> ok, value
    -- equipment plates (soccer11_08): retail personal_plate_inc table t5
    P.TX_S1108 = 1676671618                        -- #/menu/00_soccer/soccer11/soccer11_08/<LG>/soccer11_08.g4tx
    P.S_EQ_CAT = 2346103015                        -- icon_equip01 (slot)
    P.S_EQ_GTXT = 1537316010                       -- gtxt_shoes01 (slot)
    P.M_EQ_CAT = @crc:_icon_equip01@
    P.M_EQ_GTXT = @crc:_gtxt_item01@
    P.M_EQ_FOCUS = {@crc:_item_list_focus01@, @crc:_item_list_focus02@, @crc:_item_list_focus03@, @crc:_icon_title01@}
    P.EQ_POS = {1307475940 --[[_pos_list01]], 3571920478 --[[_pos_list02]], 2749374152 --[[_pos_list03]]}
    P.EQ = {
      [0] = {pos = 1307475940, style = 1254616204, text = 456522680, mesh = 303536660, cat = 2346103015, gtxt = 1537316010},
      [1] = {pos = 1307475940, style = 1254616204, text = 456522680, mesh = 303536660, cat = 316662109, gtxt = 1570380768},
      [2] = {pos = 1307475940, style = 1254616204, text = 456522680, mesh = 303536660, cat = 1708708299, gtxt = 3838541556},
      [3] = {pos = 1307475940, style = 1254616204, text = 456522680, mesh = 303536660, cat = 4223419496, gtxt = 2352590947},
      [4] = {pos = 2749374152, style = 1281522442, text = 4114324116, mesh = 2334051246},
      [5] = {pos = 3571920478, style = 263147399, text = 2185013762, mesh = 4025646555,       -- role: laurel plate, medal on _icon_title01
        base = 1453818910 --[[title_list_base01]], slot = 3047759730 --[[icon_title01]]},
    }
    -- passive rows (soccer11_20) and the six-sense window (team00_28)
    P.T_PASSIVE = @crc:_text_passive01@
    P.POS_ICON = @crc:_pos_icon01@
    P.POS_ICON2 = 397052763                        -- second icon locator (two-icon effects)
    P.POS_BUILD = @crc:_pos_build01@
    P.POS_TYPE = @crc:_pos_type01@
    P.POS_POSITION = @crc:_pos_position01@
    P.POS_LOCK = @crc:_pos_icon02@
    P.M_INHERIT = @crc:_icon_inheritance01@
    P.M_SIX_FOCUS = @crc:_sixth_win_focus01@
    P.T_SIXTH = @crc:_text_sixth01@
    P.T_FLAVOR = @crc:_text_flavor01@
    P.GREY_ON, P.GREY_OFF = "[CGRAYOUT04]", "[C]"
    P.shown = false
    P.full = nil                                    -- nil = not probed, true = FULL/SET2 answered, false = old loader

    function P.Log(...)
      pcall(EVT_Log, "pset_preview", ...)
    end

    function P.Exists()
      local ok, e = pcall(funcLuaMenuCommand, 262659071 --[[CMND_IS_EXIST_LAYER]], P.L_BASE)
      return ok and e == true
    end

    -- ---- loader: FULL / SET2 ------------------------------------------------------------------------------
    function P.Probe()
      if P.full ~= nil then
        return P.full
      end
      local r = {pcall(funcLuaCommand, P.CMD_FULL, n, 0)}
      P.full = r[1] == true and type(r[3]) == "string"   -- unknown hash (old loader): a single false
      P.Log("loader FULL/SET2", tostring(P.full))
      return P.full
    end

    function P.Ids(t, count)
      local out = {}
      for k = 1, count do
        out[k] = EVT_U32(type(t) == "table" and t[k] or 0)
      end
      return out
    end

    P.prevGet = PL.SetGet
    function PL.SetGet(i)
      if P.Probe() then
        local r = {pcall(funcLuaCommand, P.CMD_FULL, n, i)}
        if r[1] and r[2] == false and r[3] == "" then
          return nil
        end
        if r[1] and r[2] == true and type(r[4]) == "table" then
          local p = {name = r[3] or "", moves = P.Ids(r[4], 6), hiper = EVT_U32(r[5] or 0), equip = P.Ids(r[6], 5),
            sixsense = EVT_U32(r[7] or 0)}
          if type(r[8]) == "table" then
            p.passives = P.Ids(r[8], 5)
            p.pcfg = P.Ids(r[9], 5)
          end
          if type(r[10]) == "number" and r[10] >= 0 then
            p.role = r[10]
          end
          p.kit = type(r[11]) == "number" and EVT_U32(r[11]) or 0   -- 2026-10-13: the team kit at save time
          return p
        end
      end
      return P.prevGet(i)                           -- old loader / no table functions: v2 fields
    end

    -- the player's 5 passives: current ids + configured ids (0 = the slot's default); nil when unknown
    function P.ReadPassives()
      local ok, got = pcall(funcLuaCommand, P.CMD_PC_INFO, n)
      if not ok or got ~= true then
        return nil, nil
      end
      local pv, cf = {}, {}
      for s = 0, 4 do
        local okS, id, conf = pcall(funcLuaCommand, P.CMD_PC_SLOT, n, s)
        id = (okS and type(id) == "number") and EVT_U32(id) or 0
        pv[s + 1] = id
        cf[s + 1] = (okS and conf == true) and id or 0
      end
      return pv, cf
    end

    P.prevCurrent = PL.SetCurrent
    function PL.SetCurrent()
      local cur = P.prevCurrent()
      local okp, pv, cf = pcall(P.ReadPassives)
      if okp then
        cur.passives, cur.pcfg = pv, cf
      end
      local okr, r = pcall(PL.Role)
      if okr and type(r) == "number" and r >= 0 then
        cur.role = r
      end
      return cur
    end

    P.prevSame = PL.SetSame
    function PL.SetSame(p, cur)
      if not P.prevSame(p, cur) then
        return false
      end
      if p.pcfg ~= nil and cur.pcfg ~= nil then
        for k = 1, 5 do
          if (p.pcfg[k] or 0) ~= (cur.pcfg[k] or 0) then
            return false
          end
        end
      end
      return p.role == nil or cur.role == nil or p.role == cur.role
    end

    P.prevWrite = PL.SetWrite
    function PL.SetWrite(i, p, name)
      if not P.Probe() then
        return P.prevWrite(i, p, name)
      end
      if p == nil then
        local cur = PL.SetCurrent()
        local first = 0
        for r = 1, 6 do
          if first == 0 and cur.moves[r] ~= 0 then
            first = cur.moves[r]
          end
        end
        p = cur
        name = name or (first ~= 0 and EVT_Name(first) or PL.Txt(PL.TX.SET_N, i + 1))
      end
      local m, e, pv, cf = p.moves, p.equip, p.passives, p.pcfg
      local function at(t, k)
        if t == nil then
          return nil                                 -- nil = not stored (loader: not a number)
        end
        return t[k] or 0
      end
      local ok = EVT_Call(P.CMD_SET2, n, i, EVT_Cut(name or "", 26), m[1], m[2], m[3], m[4], m[5], m[6], p.hiper,
        e[1], e[2], e[3], e[4], e[5], p.sixsense or 0,
        at(pv, 1), at(pv, 2), at(pv, 3), at(pv, 4), at(pv, 5),
        at(pv and (cf or {}) or nil, 1), at(pv and (cf or {}) or nil, 2), at(pv and (cf or {}) or nil, 3),
        at(pv and (cf or {}) or nil, 4), at(pv and (cf or {}) or nil, 5),
        p.role or -1, p.kit or 0)
      P.Log("save", i, name, ok, "kit", tostring(p.kit), "passives", tostring(pv ~= nil), "role", tostring(p.role))
      return ok
    end

    -- ---- load: role + configured passives (PL.SetLoad of ss2_menus calls this with its skip list) ---------------
    function PL.SetLoadExtra(p, skip)
      if p.role ~= nil and p.role >= 0 then
        local cur = PL.Role()
        if cur >= 0 and cur ~= p.role then
          if p.role ~= 0 and PL.ROLE_ITEM[p.role] ~= nil then
            funcLuaCommand(PL.ADD_ITEM, PL.ROLE_ITEM[p.role], 1, false)   -- a free copy (as the role picker)
          end
          local st, now = EVT_Call(P.CMD_ROLE_SET, n, p.role)
          P.Log("load role", cur, "->", p.role, "status", st, "now", now)
          if st ~= 1 then
            skip(PL.TX.SKIP_FAIL, PL.RoleName(p.role))
          end
        end
      end
      if p.pcfg == nil then
        return
      end
      local okI, got, mode = pcall(funcLuaCommand, P.CMD_PC_INFO, n)
      if not okI or got ~= true or mode == 0 then
        for s = 1, 5 do
          if (p.pcfg[s] or 0) ~= 0 then
            skip(PL.TX.SKIP_LOCKED, PL.Txt(PL.TX.PV_SLOT, s))
          end
        end
        return
      end
      local function slot(s)
        local okS, id, conf, locked = pcall(funcLuaCommand, P.CMD_PC_SLOT, n, s)
        if not okS then
          return 0, false, true
        end
        return EVT_U32(id or 0), conf == true, locked == true
      end
      -- pass 1: clear the configured slots that change (frees their effects for swaps between slots)
      for s = 0, 4 do
        local id, conf, locked = slot(s)
        if conf and not locked and id ~= (p.pcfg[s + 1] or 0) then
          pcall(funcLuaCommand, P.CMD_PC_SET, n, s, 0)
        end
      end
      -- pass 2: the stored choices
      for s = 0, 4 do
        local want = p.pcfg[s + 1] or 0
        if want ~= 0 then
          local id, conf, locked = slot(s)
          if not (conf and id == want) then
            local label = PL.Txt(PL.TX.PV_SLOT, s + 1)
            if locked then
              skip(mode == 2 and PL.TX.SKIP_IDOL or PL.TX.SKIP_LOCKED, label)
            else
              local okC, done, code = pcall(funcLuaCommand, P.CMD_PC_SET, n, s, want)
              P.Log("load passive", s, want, "ok", tostring(okC and done), "code", tostring(code))
              if not (okC and done == true) then
                skip(PL.TX.SKIP_FAIL, label)
              end
            end
          end
        end
      end
    end

    -- ---- the preview: plate pages (v3) ---------------------------------------------------------------------------
    -- Page base evt_psp_base (our clone of the retail soccer11_05 page base, retail locators): one title mesh
    -- (_gtxt_sixthsense01) with the page's sprite in the plate's colour, the 5 dots, the < > arrows (plate colour),
    -- the Q / E glyphs by the dots, the 1 / 2 / 3 slot badges on page 1. Every mesh is set explicitly on each draw
    -- (CMND_SET_MESH_VISIBLE wins over the page locators, as on the plate).

    -- the screen's radar on our page (true) or back on the screen's status base (false)
    function P.Radar(mine)
      local screen = flag6 and P.RADAR_SCREEN_B or P.RADAR_SCREEN_A
      if mine then
        for _, a in ipairs(screen) do
          funcLuaMenuCommand(P.ATTACH, P.L_STATUS, 0, a, false)
        end
        for _, a in ipairs(P.RADAR_MINE) do
          funcLuaMenuCommand(P.ATTACH, P.L_BASE, 0, a, true)
        end
      else
        for _, a in ipairs(P.RADAR_MINE) do
          funcLuaMenuCommand(P.ATTACH, P.L_BASE, 0, a, false)
        end
        for _, a in ipairs(screen) do
          funcLuaMenuCommand(P.ATTACH, P.L_STATUS, 0, a, true)
        end
      end
      P.radar_mine = mine
    end

    -- radar visible on our page (pages 1 / 3) or hidden (the other pages)
    function P.RadarPage(show)
      if show then
        P.Radar(true)
        PL.hiper_wide = false
        pcall(EVT_DetailGraphSync)
        funcLuaMenuCommand(C.MESH_VISIBLE, P.L_STATUS, 2682382918 --[[_sixth_base01]], false, 0)
        PL.sixth_hidden = true
      else
        PL.hiper_wide = true
        pcall(EVT_DetailGraphSync)
      end
    end

    function P.Hide()
      for L, cnt in pairs(P.COUNT) do
        for k = 0, cnt - 1 do
          funcLuaMenuCommand(C.LAYER_VISIBLE, L, k, false)
        end
      end
      funcLuaMenuCommand(C.LAYER_VISIBLE, P.L_BASE, 0, false)
      if P.radar_mine then
        P.Radar(false)
      end
      P.shown = false
    end

    function P.Frame(show_title)
      local L = P.L_BASE
      PL.Open(L, 0)
      for _, m in ipairs(P.M_TITLES_OFF) do
        funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, 0)
      end
      for _, m in ipairs(P.M_SLOTS) do
        funcLuaMenuCommand(C.MESH_VISIBLE, L, m, show_title and P.page == 1, 0)
      end
      for _, m in ipairs(P.M_DOTS_OFF) do
        funcLuaMenuCommand(C.MESH_VISIBLE, L, m, show_title, 0)
      end
      for pg, m in ipairs(P.M_DOTS_ON) do
        funcLuaMenuCommand(C.MESH_VISIBLE, L, m, show_title and pg == P.page, 0)
      end
      for _, m in ipairs(P.M_ARROWS) do
        funcLuaMenuCommand(C.MESH_VISIBLE, L, m, show_title, 0)
      end
      for _, t in ipairs(P.T_KEYS) do
        funcLuaMenuCommand(2735666188 --[[text visible]], L, t, show_title, 0)
      end
      funcLuaMenuCommand(C.SPRITE, L, P.TX_S1105, P.TITLE_SPR[P.page], P.S_TITLE, 0, 0)
      funcLuaMenuCommand(C.MESH_VISIBLE, L, P.M_TITLE, show_title, 0)
      funcLuaMenuCommand(C.MESH_VISIBLE, L, P.M_SIXTH_BASE, show_title and P.page == 5, 0)
      funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, true)
      for _, mat in ipairs(P.MATS) do                 -- the plate's colour (retail UpdateFormationStatusBaseMatColor)
        pcall(funcLuaMenuCommand, P.MAT_COLOR, L, 0, mat, P.RGB[1], P.RGB[2], P.RGB[3])
      end
    end

    -- hide every row layer except those in `keep` (set of layers)
    function P.Only(keep)
      for L, cnt in pairs(P.COUNT) do
        if not keep[L] then
          for k = 0, cnt - 1 do
            funcLuaMenuCommand(C.LAYER_VISIBLE, L, k, false)
          end
        end
      end
    end

    -- a retail move row (the plate's own fill, SetupCharaSkillItem; skill 0 = the retail blank row) with its «IA» mark
    -- layer (evt_psp_ai, attached to the row; the retail fill enables / disables its drawing)
    function P.MoveRow(k, skill)
      local R = P.L_MOVE
      PL.Open(R, k)
      PL.Open(P.L_AI, k)
      funcLuaMenuCommand(C.LAYER_VISIBLE, P.L_AI, k, (skill or 0) ~= 0)
      -- the shared move plate (VRFW_UI.MovePlate.Fill: the move's own evolution grade, not skill_list[k]'s; its «IA»
      -- mark on P.L_AI), back to this screen's own setting
      local ok, err = VRFW_UI.MovePlate.Fill(R, k, n, skill or 0, {page = P.L_BASE, ai = P.L_AI, open = PL.Open,
        restore = {nil, L_DETAIL, 0, nil, nil}})
      if not ok then
        P.Log("move row", k, tostring(err))
      end
    end

    -- page 3: a retail equipment plate (personal_plate_inc SetupPersonalPlateEquipItem with a given item);
    -- kind 0..4 = equipment type, 5 = the role row (badge medal as the item)
    function P.EquipRow(k, kind, item, text)
      local L = P.L_EQUIP
      local d = P.EQ[kind] or P.EQ[5]
      PL.Open(L, k)
      for _, pos in ipairs(P.EQ_POS) do
        funcLuaMenuCommand(EVT_POS_VISIBLE, L, pos, pos == d.pos, k)
      end
      if d.base ~= nil then
        funcLuaMenuCommand(C.SPRITE, L, P.TX_S1108, d.base, d.base, 0, k)   -- the laurel «title» plate
      end
      local cat = d.cat ~= nil
      if cat then
        funcLuaMenuCommand(C.SPRITE, L, P.TX_S1108, d.cat, P.S_EQ_CAT, 0, k)
        funcLuaMenuCommand(C.SPRITE, L, P.TX_S1108, d.gtxt, P.S_EQ_GTXT, 0, k)
      end
      funcLuaMenuCommand(C.MESH_VISIBLE, L, P.M_EQ_CAT, cat, k)
      funcLuaMenuCommand(C.MESH_VISIBLE, L, P.M_EQ_GTXT, cat, k)
      for _, m in ipairs(P.M_EQ_FOCUS) do
        if m ~= d.mesh then
          funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, k)
        end
      end
      funcLuaMenuCommand(2333948100 --[[text style]], L, k, d.text, d.style)
      if item ~= nil and item ~= 0 then
        funcLuaMenuCommand(C.ITEM_ICON, L, k, d.mesh, d.slot or 1875672568 --[[icon_item_dmy01]], item)
        funcLuaMenuCommand(C.MESH_VISIBLE, L, d.mesh, true, k)
      else
        funcLuaMenuCommand(C.MESH_VISIBLE, L, d.mesh, false, k)
      end
      funcLuaMenuCommand(C.TEXT, L, d.text, text or "", k)
      funcLuaMenuCommand(C.LAYER_VISIBLE, L, k, true)
    end

    -- page 4: a retail passive row (UpdatePassiveSkillLayerInfo with a given passive id); id nil = a text-only row
    function P.PassiveRow(k, id, text, grey)
      local L = P.L_PV
      PL.Open(L, k)
      for _, pos in ipairs({P.POS_ICON, P.POS_ICON2, P.POS_BUILD, P.POS_TYPE, P.POS_POSITION, P.POS_LOCK}) do
        funcLuaMenuCommand(EVT_POS_VISIBLE, L, pos, false, k)
      end
      funcLuaMenuCommand(C.MESH_VISIBLE, L, P.M_INHERIT, false, k)
      funcLuaMenuCommand(1233047821 --[[number visible]], L, k, 2330185550, false)
      local t = text or ""
      if id ~= nil and id ~= 0 then
        local eff = EVT_PV_Call(EVT_PV.PASSIVE, 0, id)
        if type(eff) ~= "number" or eff == 0 then
          local ok, has, e2 = pcall(funcLuaCommand, 4054311845, id)
          eff = (ok and has and type(e2) == "number") and e2 or 0
        end
        local okt, s = pcall(EVT_PV_TeamText, id, eff, 1)
        t = okt and s or string.format("%08X", EVT_U32(id))
        pcall(SwapPassiveSkillEffectIcon, L, k, eff)         -- retail icon + archetype icon(s)
      end
      if grey then
        t = P.GREY_ON .. t .. P.GREY_OFF
      end
      funcLuaMenuCommand(C.TEXT, L, P.T_PASSIVE, t, k)
      funcLuaMenuCommand(1505208242 --[[text visible]], L, P.T_PASSIVE, true, k)
      funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], L, k, 2274335502 --[[lock]], 0)
      funcLuaMenuCommand(C.LAYER_VISIBLE, L, k, true)
    end

    -- page 5: the retail six-sense window (UpdateSixSenseLayerInfo with a given item; none = its blank look)
    function P.SixRow(item)
      local L = P.L_SIX
      PL.Open(L, 0)
      local has = item ~= nil and item ~= 0
      funcLuaMenuCommand(EVT_POS_VISIBLE, L, 1517329426 --[[_pos_base01]], has, 0)
      funcLuaMenuCommand(EVT_POS_VISIBLE, L, 2020757070 --[[_pos_blank01]], not has, 0)
      funcLuaMenuCommand(C.MESH_VISIBLE, L, P.M_SIX_FOCUS, false, 0)
      if has then
        pcall(UpdateSixSenseLayerInfoForItemId, L, 0, item, true)
      else
        funcLuaMenuCommand(C.TEXT, L, P.T_SIXTH, "", 0)
        funcLuaMenuCommand(C.TEXT, L, P.T_FLAVOR, "", 0)
      end
      funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, true)
    end

    -- the stats the player would have with set p (v4): per stat type t (0..6, chara kind 14 + t) the shown value minus
    -- the current equipment's bonus plus the set's; the retail NextBeans radar draws "stat without beans" + a4 with
    -- the arrow to + a5, so a4 = current - without beans, a5 = with the set - without beans
    function P.SetStats(p)
      local cur = PL.EquipIds()
      local out = {}
      for t = 0, 6 do
        local shown = funcLuaCommand(C.CHARA_GET, n, 14 + t, true)
        shown = type(shown) == "number" and shown or 0
        local bonus = 0
        for k = 1, 5 do
          for sign, id in pairs({[-1] = cur[k] or 0, [1] = (p.equip or {})[k] or 0}) do
            if id ~= 0 then
              local ok, has, v = pcall(funcLuaCommand, P.EQUIP_PARAM, id, t)
              if ok and has and type(v) == "number" then
                bonus = bonus + sign * v
              end
            end
          end
        end
        out[t] = {shown = shown, set = math.max(0, shown + bonus)}
      end
      return out
    end

    function P.SetGraph(p)
      if UpdateCharaParameterGraphNextBeansByCharaStHdl == nil then
        return
      end
      local stats = P.SetStats(p)
      local a4, a5 = {}, {}
      for t = 0, 7 do
        if t < 7 then
          local nob = funcLuaCommand(C.CHARA_GET, n, 14 + t, true, true)
          nob = type(nob) == "number" and nob or 0
          a4[t + 1] = stats[t].shown - nob
          a5[t + 1] = stats[t].set - nob
        else
          a4[t + 1] = 0
          a5[t + 1] = 0
        end
      end
      local ok, err = pcall(UpdateCharaParameterGraphNextBeansByCharaStHdl, P.GRAPH[1], P.GRAPH[2], n, a4, a5,
        P.GRAPH[3])
      if not ok then
        P.Log("set radar", tostring(err))
      end
    end

    function P.DrawPage(p)
      local old = PL.Txt(PL.TX.SET_OLD)
      if P.page == 1 then
        P.Only({[P.L_MOVE] = true, [P.L_AI] = true})
        for k = 0, 5 do
          P.MoveRow(k, p.moves[k + 1] or 0)
        end
        funcLuaMenuCommand(C.LAYER_VISIBLE, P.L_MOVE, 6, false)
        funcLuaMenuCommand(C.LAYER_VISIBLE, P.L_AI, 6, false)
        P.RadarPage(true)
        P.SetGraph(p)
      elseif P.page == 2 then
        P.Only({})
        P.RadarPage(false)
        local h, shown = p.hiper or 0, false
        if h ~= 0 then
          local _, ti = GetSoccerTeamInfo(0)
          local okh, r = pcall(PL.HiperShow, h, ti)   -- the plate Hiper page's recipe
          shown = okh and r == true
          if not okh then
            P.Log("hiper page", tostring(r))
          end
        end
        if not shown then
          P.MoveRow(6, 0)                             -- no Hiper: the retail blank row
        end
      elseif P.page == 3 then
        P.Only({[P.L_EQUIP] = true})
        for k = 1, 5 do
          local it = p.equip[k] or 0
          P.EquipRow(k - 1, k - 1, it, it ~= 0 and PL.ItemName(it) or "")
        end
        if p.role ~= nil then
          P.EquipRow(5, 5, PL.ROLE_ITEM[p.role], PL.Txt(PL.TX.ROLE_NOW, PL.RoleName(p.role)))
        else
          P.EquipRow(5, 5, 0, P.GREY_ON .. PL.Txt(PL.TX.ROLE_NOW, old) .. P.GREY_OFF)
        end
        P.RadarPage(true)
        P.SetGraph(p)
      elseif P.page == 4 then
        P.Only({[P.L_PV] = true})
        P.RadarPage(false)
        if p.passives == nil then
          P.PassiveRow(0, nil, PL.Txt(PL.TX.PV_TITLE, old), true)
          for k = 1, 4 do
            funcLuaMenuCommand(C.LAYER_VISIBLE, P.L_PV, k, false)
          end
        else
          for k = 1, 5 do
            local id = p.passives[k] or 0
            P.PassiveRow(k - 1, id, "---", id == 0)
          end
        end
      else
        P.Only({[P.L_SIX] = true})
        P.RadarPage(false)
        P.SixRow(p.sixsense or 0)
      end
    end

    function P.Draw(e)
      PL.DetailHideAll()                            -- the other panels (and ours, reset)
      P.focus = e
      if e.p == nil then
        -- empty set: no page frame, the two hint lines on passive rows
        P.Frame(false)
        P.Only({[P.L_PV] = true})
        P.RadarPage(false)
        P.PassiveRow(1, nil, PL.Txt(PL.TX.SET_HINT_1))
        P.PassiveRow(2, nil, PL.Txt(PL.TX.SET_HINT_2))
        for _, k in ipairs({0, 3, 4}) do
          funcLuaMenuCommand(C.LAYER_VISIBLE, P.L_PV, k, false)
        end
      else
        P.Frame(true)
        P.DrawPage(e.p)
      end
      P.shown = true
      return true
    end

    -- Q / E (L1 / R1) and left / right: page of the preview; the cursor stays on the set list
    function P.Step(e)
      if e == nil or e.p == nil then
        return false
      end
      local dir = 0
      if PL.Key(P.K_L1) or PL.Key(P.K_LEFT) then
        dir = -1
      elseif PL.Key(P.K_R1) or PL.Key(P.K_RIGHT) then
        dir = 1
      end
      if dir == 0 then
        return false
      end
      P.page = (P.page - 1 + dir) % P.PAGES + 1
      funcLuaCommand(C.SE, 2500047763 --[[sy0005 cursor]])
      local ok, err = pcall(P.Draw, e)
      if not ok then
        P.Log("page draw error", tostring(err))
      end
      return true
    end

    P.prevPopList = PL.PopList
    function PL.PopList(list, init, mode)
      if mode ~= nil and mode.focus == PL.SetFocus and mode.step == nil and P.Exists() then
        mode.step = P.Step
      end
      return P.prevPopList(list, init, mode)
    end

    P.prevFocus = PL.SetFocus
    function PL.SetFocus(e)
      if P.Exists() and e.kind == nil then         -- 2026-10-13: «Exportar set» / «Importar set» rows keep their panel
        local ok, err = pcall(P.Draw, e)
        if ok then
          return
        end
        P.Log("draw error", tostring(err))
        pcall(P.Hide)
      end
      return P.prevFocus(e)
    end

    -- every other panel starts with PL.DetailHideAll: ours goes with it
    P.prevHideAll = PL.DetailHideAll
    function PL.DetailHideAll(...)
      if P.shown then
        pcall(P.Hide)
      end
      return P.prevHideAll(...)
    end

    -- the list closed without another panel being drawn: hide ours and give the radar back
    P.prevSets = PL.SetsCoroutine
    function PL.SetsCoroutine(...)
      P.page = 1
      local r = P.prevSets(...)
      if P.shown then
        pcall(P.Hide)
        PL.hiper_wide = false
        pcall(EVT_DetailGraphSync)
        pcall(UpdateEquipItemInfo)
      end
      return r
    end

    -- our layers stay hidden until the list draws them; over the player page like the other detail panels
    P.prevSetup = OnSetupLayer
    OnSetupLayer = function(a1, a2, ...)
      if a1 == P.L_BASE or P.COUNT[a1] ~= nil then
        if a1 == P.L_BASE then
          for _, a in ipairs(P.RADAR_MINE) do           -- the radar stays on the screen's status base until a page
            funcLuaMenuCommand(P.ATTACH, a1, a2, a, false)
          end
        end
        funcLuaMenuCommand(EVT_PRIORITY, a1, a2, a1 == P.L_BASE and 656 or (a1 == P.L_AI and 659 or 658), true)
        funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
        return
      end
      return P.prevSetup(a1, a2, ...)
    end
  end
  EVT_PSP.Install()
end
-- ===== EVT pset_preview END =====
