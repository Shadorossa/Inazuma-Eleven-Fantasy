-- ===== EVT skill_card BEGIN =====
-- Mod Hissatsu Effects (hissatsu_effects; moved out of Inazuma Fantasy 2026-10-14 with the move effects it shows).
-- EVT skill_card (Nacho 2026-10-06): the «Habilidades» move list (ability_list_menu), right-hand move card
-- (team02_02_skill_detail_info). Q / E (pad LT / RT, CMD_FUNCL2 / CMD_FUNCR2) turn the card body between the move's
-- DESCRIPTION and its ball MINI-EFFECT (technique type, `[technique.ball]` / `[edit.ball]`: docs/framework/technique.md
-- §4b), read at run time from the framework with CMND_VRFW_TECHNIQUE_BALL_EFFECT(move) -> present, metres, degrees,
-- direction, distance word, launch word (crates/vr-core/src/types/technique/ball_effect.rs), so any mod's rules show.
-- The mini-effect page is the title «Efecto especial» over ONE plain sentence («Despeja el balón muy lejos hacia
-- delante.»), both centred: template evt_skc_sentence filled with a distance / height / direction piece chosen from
-- the numbers (no metres, degrees or symbols). The move's shot / keeper mini-effects (distance_falloff,
-- on_win_lock_opponent_move, pe_sacrifice, power_per_participant, on_win_steal_tension, trajectory:
-- docs/framework/technique.md §4e) come from CMND_VRFW_TECHNIQUE_MINI_FX(move) -> present, mask (1 distance, 2 lock,
-- 4 PE, 8 power per performer, 16 tension steal, 32 dive), slope, cap, fraction, power_mult, key, element, pct,
-- steal_pct, dive_height, dive_unblockable: one sentence each (evt_skc_fx_*; the element word of «power per performer» is the row
-- evt_skc_elem_1..4, void / any use the sentence without an element), after the ball sentence when a move has
-- both.
-- A move with a mini-effect shows the player page's «Q • • E» row at the bottom of the card (layer evt_skc_dots: four
-- copies of the retail status base, Hissatsu Effects content/menus/skill_card_dots.toml; Q glyph, dot 1, dot 2, E glyph, the
-- current page's dot lit) and the bottom guide gets «Q E Efecto» (on the effect page «Q E Descripción»; the game
-- draws the keys of the device in use). A move without one shows no row and does not turn. A new move always opens on
-- its description. Texts: menu_text evt_skc_* (9 languages, research/mods/HissatsuEffects/text/rows/skill_card.toml);
-- the Spanish fallback only shows without those rows. The row's instances are attached to the card's _pos_base01
-- (card copy evt_skc_card, traces evt_skc_dots0..3) and drawn above it (priority 580). EVT_SKC_DOTS_XY = {x, y}
-- moves the row: its centre in card px from the card's centre (x right, y up; default 0, -150 = 20 px above the
-- white area's bottom edge).
-- The card's drop shadow is gone in the atlas (images/menu/102_team/team02/team02_02/card_flat.toml), not here.
-- No chunk local of the retail script is read (2026-10-14): a block that reads one makes the build re-declare the
-- script's locals and REDEFINE every retail function using them (OnInit, OnBack, UpdateButtonGuide, ...), which threw
-- away the wrappers of the mods patched before this one (Character Reforged's skill table picker, graft ss2_menus: its
-- pick mode never started, so a chosen move was never equipped). The move the card shows (the retail n2) is followed
-- here instead (SKC.focus): set by UpdateSkillDetailWindow, cleared by an empty tab and a new filter, as the retail
-- does. Nothing calls the engine at chunk load; the wrappers forward every argument and return every result.
do
  local SKC = {
    CMD = @crc:CMND_VRFW_TECHNIQUE_BALL_EFFECT@,
    MINI_CMD = @crc:CMND_VRFW_TECHNIQUE_MINI_FX@,
    TEXT_GET = 4074371074,
    SE = 1917805374,
    SE_PAGE = 1228648509,             -- sy0027 (the retail detail page switch)
    CHECK = 4265778440,               -- CMND_CHECK_INPUT_CMD (ctrl, key)
    CTRLS = {1332654303 --[[MENU_CTRL]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]]},
    K_L2 = 1970176280,                -- CMD_FUNCL2
    K_R2 = 2704260807,                -- CMD_FUNCR2
    I_L2 = 619948187,                 -- <CMD_FUNCL2> glyph
    I_R2 = 3487556099,                -- <CMD_FUNCR2> glyph
    GUIDE = 1138543975,               -- mainmenu01_06_base_button_guide
    GUIDE_SET = 2209673388,           -- (menu, layer, texts, icons, offsets, t, t)
    GUIDE_KEYS = 452337289,           -- (menu, layer, keys)
    CARD = 2628045944,                -- team02_02_skill_detail_info
    FLAVOR = 691026122,               -- _text_flavor01 (the card body)
    SET_TEXT = 1083631230,            -- CMND_SET_MENU_TEXT_STRING (layer, node, text, instance)
    CURSOR = 2296367164,              -- cmn05_01_cursor (hidden while the sort / filter windows are open)
    VISIBLE = 1262717583,             -- CMND_IS_LAYER_VISIBLE
    T = {
      guide_effect = @crc:evt_skc_guide_effect@,
      guide_desc = @crc:evt_skc_guide_desc@,
      sentence = @crc:evt_skc_sentence@,
      dist_short = @crc:evt_skc_dist_short@,
      dist_mid = @crc:evt_skc_dist_mid@,
      dist_long = @crc:evt_skc_dist_long@,
      height_high = @crc:evt_skc_height_high@,
      height_low = @crc:evt_skc_height_low@,
      dir_forward = @crc:evt_skc_dir_forward@,
      generic = @crc:evt_skc_generic@,
      title = @crc:evt_skc_title@,
      fx_distance = @crc:evt_skc_fx_distance@,
      fx_lock = @crc:evt_skc_fx_lock@,
      fx_pe = @crc:evt_skc_fx_pe@,
      fx_participants = @crc:evt_skc_fx_participants@,
      fx_participants_any = @crc:evt_skc_fx_participants_any@,
      fx_steal = @crc:evt_skc_fx_steal@,
      fx_dive = @crc:evt_skc_fx_dive@,
      fx_dive_plain = @crc:evt_skc_fx_dive_plain@,
      el_wind = @crc:evt_skc_elem_1@,
      el_forest = @crc:evt_skc_elem_2@,
      el_fire = @crc:evt_skc_elem_3@,
      el_mountain = @crc:evt_skc_elem_4@,
    },
    FALLBACK = {
      guide_effect = "Efecto",
      guide_desc = "Descripción",
      sentence = "Despeja el balón{dist}{height}{dir}.",
      dist_short = " a poca distancia",
      dist_mid = " a media distancia",
      dist_long = " muy lejos",
      height_high = " por alto",
      height_low = " a ras de suelo",
      dir_forward = " hacia delante",
      generic = "Cambia la trayectoria del balón al despejar.",
      title = "Efecto especial",
      fx_distance = "Cuanto más lejos, más potente.",
      fx_lock = "Bloquea la supertécnica del rival hasta que vuelvas a usarla.",
      fx_pe = "Gasta un {pct} % de PE para aumentar su potencia.",
      fx_participants = "+{pct} % de potencia por cada compañero de elemento {element} que la realiza.",
      fx_participants_any = "+{pct} % de potencia por cada compañero que la realiza.",
      fx_steal = "Si para el tiro, gana un {pct} % de la tensión que gastó el rival.",
      fx_dive = "El balón sube y cae en picado sobre la portería; en un tiro lejano, los bloqueos no pueden pararlo.",
      fx_dive_plain = "El balón sube y cae en picado sobre la portería.",
      el_wind = "Viento",
      el_forest = "Bosque",
      el_fire = "Fuego",
      el_mountain = "Montaña",
    },
    -- page 2's body: the title «Efecto especial» (colour tag TITLE_TAG, EVT_SKC_TITLE_TAG overrides; "" = none) over the
    -- sentence, both CENTRED: the body node's retail style fs_32_k_lu_2d0_001 swapped for its centred twin
    -- fs_32_k_cu_2d0_001 (same size / grey) while page 2 shows, the retail one back on page 1
    STYLE_CMD = 2333948100,           -- (layer, instance, node, style crc)
    STYLE_LEFT = 1038337842,          -- fs_32_k_lu_2d0_001 (retail _text_flavor01)
    STYLE_CENTRE = 3437796543,        -- fs_32_k_cu_2d0_001
    TITLE_TAG = "[CB]",
    centred = false,
    -- the «Q • • E» row: layer evt_skc_dots, instances 0 = Q glyph, 1 / 2 = the page dots, 3 = E glyph
    DOTS = @crc:evt_skc_dots@,
    EXIST = 262659071,                -- CMND_IS_EXIST_LAYER
    OPEN = 629267548,                 -- CMND_OPEN_LAYER
    IS_OPEN = 2640875187,             -- CMND_IS_OPEN_LAYER
    LOADING = 3057768039,
    LVIS = 711242136,                 -- CMND_SET_LAYER_VISIBLE
    POS = 1389957207,                 -- layer local position (layer, x, y, z, instance)
    MESH = 3405944500,                -- CMND_SET_MESH_VISIBLE
    NODE_VIS = 2158717427,
    TEXT_VIS = 1505208242,
    M_OFF = 3784855471,               -- _page01_off
    M_ON = 2540064569,                -- _page01_on
    M_HIDE = {2788701567, 2606243023, 695779551},               -- _page02..04_off
    LOCS = {3407216458, 1377611504, 622567014, 3145665477, 1753514051, 790952595, 442049775, 1056264686,
      2946906320, 1437140403},        -- every _pos_page* / _pos_equip* / arrow locator of the copy
    N_BTN_L = 355816102,              -- _text_btn_l01
    N_BTN_R = 59628764,               -- _text_btn_r01
    -- layout places (soccer11_05, x right / y up, top-left of each part): dot (1362, -949), glyphs (1039 / 1811, -496)
    AT_DOT = {1362, -949},
    AT_L = 1039,
    AT_R = 1811,
    AT_GY = -496,
    CENTRE = {0, -150},               -- row centre in card px (card 920 x 380 centred on _pos_base01, white to y -170)
    TRACE = 1774843228,               -- (host layer, host instance, trace name, on)
    TRACES = {[0] = @crc:evt_skc_dots0@, @crc:evt_skc_dots1@, @crc:evt_skc_dots2@, @crc:evt_skc_dots3@},
    PRIO_CMD = 1491630496,            -- CMND_SET_DRAW_PRIORITY (layer, instance, priority, children)
    PRIO = 580,                       -- the card object draws at 570, the status base copy at 301
    GLYPHS = {[0] = "<CMD_FUNCL2>", [3] = "<CMD_FUNCR2>"},
    SET_STR = 1083631230,
    PITCH = 28,                       -- the player page's dot pitch (32 px sprites)
    dots = {},                        -- instance -> set up
    opened = {},                      -- instance -> we asked the engine to open it (once)
    gone = false,                     -- the engine closed an instance: the row is off for this menu's life
    LOG = 3661580131,                 -- CMND_EVT_LOG
    shown = nil,                      -- last row state ("" hidden, else the page)
    skill = nil,       -- the move of the last UpdateSkillDetailWindow
    args = nil,        -- its arguments (to refill the description)
    page = 0,          -- 0 description, 1 mini-effect
    cache = {},        -- move -> effect table or false (the framework's answer does not change while the menu lives)
    focus = 0,         -- the move the card shows (0 = none): the retail's n2, followed by the wrappers below
    SKILL_INFO = 2580586398,          -- CMND_GET_SOCCER_SKILL_INFO (move, 9) -> ok, category
    LIST = 571205469,                 -- team05_03_ability_list
    TAB = 4044286600,                 -- cmn06_20_list_tab_item
    LIST_COUNT = 2389020234,          -- the list layer's item count
  }

  -- the card shows a move and it is the one of the last fill
  function SKC.Focused()
    return SKC.focus ~= 0 and SKC.focus == SKC.skill
  end

  local function Text(key, subs)
    local s = nil
    local ok, r = pcall(funcLuaCommand, SKC.TEXT_GET, SKC.T[key])
    if ok and type(r) == "string" and r ~= "" then
      s = r
    end
    s = s or SKC.FALLBACK[key] or ""
    for k, v in pairs(subs or {}) do
      s = string.gsub(s, "{" .. k .. "}", (string.gsub(tostring(v), "%%", "%%%%")))
    end
    return s
  end

  -- the move's mini-effect, or false
  local function Effect(skill)
    if type(skill) ~= "number" or skill == 0 then
      return false
    end
    local e = SKC.cache[skill]
    if e ~= nil then
      return e
    end
    e = false
    local ok, present, dist, launch, dir, dword, lword = pcall(funcLuaCommand, SKC.CMD, skill)
    if ok and present == true then
      e = {ball = true, dist = tonumber(dist) or 0, launch = tonumber(launch) or 0, dir = tostring(dir or "keep"),
           dword = tostring(dword or ""), lword = tostring(lword or "")}
    end
    -- the shot / keeper mini-effects (a framework without the verb: pcall fails, nothing added)
    local mok, mpresent, mask, _, _, frac, _, _, pel, ppct, spct, _, dunb = pcall(funcLuaCommand, SKC.MINI_CMD, skill)
    if mok and mpresent == true and (tonumber(mask) or 0) > 0 then
      e = e or {}
      e.mini = tonumber(mask) or 0
      e.frac = tonumber(frac) or 0
      e.pel = tostring(pel or "")
      e.ppct = tonumber(ppct) or 0
      e.spct = tonumber(spct) or 0
      e.dunb = tonumber(dunb) or 0
    end
    SKC.cache[skill] = e
    return e
  end

  -- one plain sentence: «Despeja el balón muy lejos hacia delante.»
  local function BallText(e)
    local dist, height, dir = "", "", ""
    local d = (e.dword == "low" and 15) or (e.dword == "mid" and 25) or (e.dword == "high" and 40) or e.dist
    if d > 0 then
      dist = Text(d <= 18 and "dist_short" or (d <= 30 and "dist_mid" or "dist_long"))
    end
    local a = (e.lword == "flat" and 10) or (e.lword == "low" and 25) or (e.lword == "lob" and 45)
      or (e.lword == "high" and 60) or e.launch
    if a >= 40 then
      height = Text("height_high")
    elseif a > 0 and a <= 15 then
      height = Text("height_low")
    end
    if e.dir == "forward" then
      dir = Text("dir_forward")
    end
    if dist == "" and height == "" and dir == "" then
      return Text("generic")
    end
    return Text("sentence", {dist = dist, height = height, dir = dir})
  end

  -- the ball sentence, then one sentence per mini-effect (mask bits 1 distance, 2 lock, 4 PE, 8 per performer,
  -- 16 tension steal, 32 dive)
  local function EffectText(e)
    local parts = {}
    if e.ball then
      parts[#parts + 1] = BallText(e)
    end
    local m = e.mini or 0
    local function Bit(b)
      return math.floor(m / b) % 2 == 1
    end
    if Bit(1) then
      parts[#parts + 1] = Text("fx_distance")
    end
    if Bit(2) then
      parts[#parts + 1] = Text("fx_lock")
    end
    if Bit(4) then
      parts[#parts + 1] = Text("fx_pe", {pct = math.floor((e.frac or 0) * 100 + 0.5)})
    end
    if Bit(8) then
      local pct = math.floor((e.ppct or 0) + 0.5)
      if SKC.T["el_" .. (e.pel or "")] ~= nil then
        parts[#parts + 1] = Text("fx_participants", {pct = pct, element = Text("el_" .. e.pel)})
      else
        parts[#parts + 1] = Text("fx_participants_any", {pct = pct})
      end
    end
    if Bit(16) then
      parts[#parts + 1] = Text("fx_steal", {pct = math.floor((e.spct or 0) + 0.5)})
    end
    if Bit(32) then
      parts[#parts + 1] = Text(e.dunb == 1 and "fx_dive" or "fx_dive_plain")
    end
    return table.concat(parts, " ")
  end

  local function SetStyle(centre)
    if SKC.centred ~= centre then
      SKC.centred = centre
      pcall(funcLuaMenuCommand, SKC.STYLE_CMD, SKC.CARD, 0, SKC.FLAVOR, centre and SKC.STYLE_CENTRE or SKC.STYLE_LEFT)
    end
  end

  local function ShowEffect(e)
    local tag = (type(EVT_SKC_TITLE_TAG) == "string") and EVT_SKC_TITLE_TAG or SKC.TITLE_TAG
    local title = Text("title")
    if tag ~= "" then
      title = tag .. title .. "[C]"
    end
    SetStyle(true)
    funcLuaMenuCommand(SKC.SET_TEXT, SKC.CARD, SKC.FLAVOR, title .. "\n" .. EffectText(e), 0)
  end

  -- a tab whose list is empty shows no move (retail OnChangeFocus); a new filter neither (OnAfterReceiveFilterParam)
  local SKC_RetailOnChangeFocus = OnChangeFocus
  function OnChangeFocus(a1, ...)
    local r = table.pack(SKC_RetailOnChangeFocus(a1, ...))
    if a1 == SKC.TAB then
      local count = funcLuaMenuCommand(SKC.LIST_COUNT, SKC.LIST)
      if type(count) ~= "number" or count <= 0 then
        SKC.focus = 0
      end
    end
    return table.unpack(r, 1, r.n)
  end

  local SKC_RetailOnAfterReceiveFilterParam = OnAfterReceiveFilterParam
  function OnAfterReceiveFilterParam(...)
    SKC.focus = 0
    SKC.page = 0
    return SKC_RetailOnAfterReceiveFilterParam(...)
  end

  local SKC_RetailUpdateSkillDetailWindow = UpdateSkillDetailWindow
  function UpdateSkillDetailWindow(...)
    local skill = ...
    if skill ~= SKC.skill then
      SKC.page = 0
    end
    SKC.skill, SKC.args = skill, table.pack(...)
    -- the move the card shows (the retail's own focus: a move with skill info, else none)
    local okInfo = type(skill) == "number" and funcLuaCommand(SKC.SKILL_INFO, skill, 9)
    SKC.focus = okInfo and skill or 0
    -- (the aura windows' page guide reset of 2026-10-07 stays in Inazuma Fantasy: graft aura_guide_reset)
    local r = table.pack(SKC_RetailUpdateSkillDetailWindow(...))
    if SKC.page ~= 1 then
      pcall(SetStyle, false)
    end
    if SKC.page == 1 then
      local e = Effect(skill)
      if e then
        pcall(ShowEffect, e)
      else
        SKC.page = 0
      end
    end
    -- a move with one page only (no mini-effect): back to page 1 and the «Q • • E» row hidden at once, not one frame later
    if not (SKC.focus ~= 0 and Effect(SKC.focus)) then
      SKC.page = 0
      if SKC.HideRowNow then
        pcall(SKC.HideRowNow)
      end
    end
    return table.unpack(r, 1, r.n)
  end

  -- the guide: «Q E Efecto / Descripción» (the device's own key glyphs, pad LT / RT) added to whatever the retail (or
  -- an earlier wrapper) shows, by catching its two guide calls while it runs (funcLuaMenuCommand is restored after)
  local SKC_RetailUpdateButtonGuide = UpdateButtonGuide
  function UpdateButtonGuide(...)
    local e = SKC.Focused() and Effect(SKC.focus)
    local real = funcLuaMenuCommand
    if not e or type(real) ~= "function" then
      return SKC_RetailUpdateButtonGuide(...)
    end
    local label = (SKC.page == 1) and SKC.T.guide_desc or SKC.T.guide_effect
    local n = 0
    funcLuaMenuCommand = function(...)
      local c, m, layer, a4, a5, a6, a7, a8 = ...
      if layer == SKC.GUIDE and c == SKC.GUIDE_SET and type(a4) == "table" and type(a5) == "table" then
        n = #a4
        local args = table.pack(...)
        for k = 4, 8 do
          if type(args[k]) == "table" then
            local t = {}
            for i = 1, n do
              t[i] = args[k][i] or 0
            end
            args[k] = t
          end
        end
        for _, add in ipairs({{0, SKC.I_L2}, {label, SKC.I_R2}}) do
          args[4][#args[4] + 1] = add[1]
          args[5][#args[5] + 1] = add[2]
          if type(args[6]) == "table" then args[6][#args[6] + 1] = 18 end
          if type(args[7]) == "table" then args[7][#args[7] + 1] = 0 end
          if type(args[8]) == "table" then args[8][#args[8] + 1] = 0 end
        end
        return real(table.unpack(args, 1, args.n))
      elseif layer == SKC.GUIDE and c == SKC.GUIDE_KEYS and type(a4) == "table" then
        local t = {}
        for i = 1, n do
          t[i] = a4[i] or 0
        end
        t[#t + 1] = SKC.K_L2
        t[#t + 1] = SKC.K_R2
        local args = table.pack(...)
        args[4] = t
        return real(table.unpack(args, 1, args.n))
      end
      return real(...)
    end
    local r = table.pack(pcall(SKC_RetailUpdateButtonGuide, ...))
    funcLuaMenuCommand = real
    if not r[1] then
      error(r[2], 0)
    end
    return table.unpack(r, 2, r.n)
  end

  local function Pressed(k)
    for _, ctrl in ipairs(SKC.CTRLS) do
      local ok, hit = pcall(funcLuaCommand, SKC.CHECK, ctrl, k)
      if ok and hit == true then
        return true
      end
    end
    return false
  end

  local function Cmd(...)
    local r = table.pack(pcall(funcLuaMenuCommand, ...))
    if not r[1] then
      return nil
    end
    return table.unpack(r, 2, r.n)
  end

  local function Log(...)
    pcall(funcLuaCommand, SKC.LOG, "EVT skill_card", ...)
  end

  -- an instance of the row layer: true once open and loaded. Opened ONCE, only when the row is wanted; an instance the
  -- engine closed (the menu leaving, a sub-menu) is never opened again (hang 2026-10-06: Step re-opened the instances
  -- the exit had closed, so the menu's close waited forever)
  local function Ready(k, want)
    if Cmd(SKC.IS_OPEN, SKC.DOTS, k) == true then
      return Cmd(SKC.LOADING, SKC.DOTS) ~= true
    end
    if SKC.opened[k] then
      if not SKC.gone then
        SKC.gone = true
        Log("row layer closed by the menu: not reopened", k)
      end
      return false
    end
    if want and not SKC.gone then
      SKC.opened[k] = true
      Cmd(SKC.OPEN, SKC.DOTS, k)
      Log("row layer opened", k)
    end
    return false
  end

  -- instance k shows one part only (the player page's dots copy set-up, research/grafts/plate_pages G.Dots) and sits
  -- on its place of the row
  local function RowSetup(k)
    Cmd(SKC.TRACE, SKC.CARD, 0, SKC.TRACES[k], true)  -- attached to the card's _pos_base01
    for _, n in ipairs(SKC.LOCS) do
      Cmd(SKC.NODE_VIS, SKC.DOTS, n, false, k)
    end
    for _, m in ipairs(SKC.M_HIDE) do
      Cmd(SKC.MESH, SKC.DOTS, m, false, k)
    end
    Cmd(SKC.TEXT_VIS, SKC.DOTS, SKC.N_BTN_L, k == 0, k)
    Cmd(SKC.TEXT_VIS, SKC.DOTS, SKC.N_BTN_R, k == 3, k)
    if k == 0 then
      Cmd(SKC.SET_STR, SKC.DOTS, SKC.N_BTN_L, SKC.GLYPHS[0], k)
    elseif k == 3 then
      Cmd(SKC.SET_STR, SKC.DOTS, SKC.N_BTN_R, SKC.GLYPHS[3], k)
    end
    -- world = card _pos_base01 + local position + the part's layout place, so local = target - layout place;
    -- targets (top-left, card px, y up) as the player page's row: dots 28 px apart, Q 40 px left of dot 1, E 36 px
    -- right of dot 2, the glyphs 8 px higher
    local c = (type(EVT_SKC_DOTS_XY) == "table") and EVT_SKC_DOTS_XY or SKC.CENTRE
    local cx, cy = tonumber(c[1]) or SKC.CENTRE[1], tonumber(c[2]) or SKC.CENTRE[2]
    local x1 = cx - SKC.PITCH / 2 - 16
    local top = cy + 16
    local x, y
    if k == 0 then
      x, y = x1 - 40 - SKC.AT_L, top + 8 - SKC.AT_GY
    elseif k == 3 then
      x, y = x1 + SKC.PITCH + 36 - SKC.AT_R, top + 8 - SKC.AT_GY
    else
      x, y = x1 + (k - 1) * SKC.PITCH - SKC.AT_DOT[1], top - SKC.AT_DOT[2]
    end
    Cmd(SKC.POS, SKC.DOTS, x, y, 0, k)
    Cmd(SKC.PRIO_CMD, SKC.DOTS, k, SKC.PRIO, true)
    Log("row part set up", k, x, y)
  end

  -- the «Q • • E» row: shown for a move with a mini-effect while the card is up, the current page's dot lit
  -- hides every instance of the row that is still open (a move with one page only, the menu leaving)
  -- (the dots' meshes go too, so the row cannot stay lit if the engine re-shows the layer on its own)
  local function HideRow()
    for k in pairs(SKC.opened) do
      if Cmd(SKC.IS_OPEN, SKC.DOTS, k) == true then
        Cmd(SKC.LVIS, SKC.DOTS, k, false)
        if k == 1 or k == 2 then
          Cmd(SKC.MESH, SKC.DOTS, SKC.M_OFF, false, k)
          Cmd(SKC.MESH, SKC.DOTS, SKC.M_ON, false, k)
        end
      end
    end
    SKC.shown = ""
  end

  -- the move on the card has a second page (a mini-effect) and the card is up
  SKC.HideRowNow = HideRow

  local function WantRow()
    return (SKC.Focused() and Effect(SKC.focus)
      and Cmd(SKC.VISIBLE, SKC.CARD, 0) ~= false and Cmd(SKC.VISIBLE, SKC.CURSOR, 0) ~= false) and true or false
  end

  local function Row()
    local want = WantRow()
    if SKC.gone then
      -- the engine closed an instance: the row is never shown again, but the instances still open must not stay lit
      if not want and SKC.shown ~= "" then
        HideRow()
      end
      return
    end
    if Cmd(SKC.EXIST, SKC.DOTS) ~= true then
      return
    end
    if not want and next(SKC.opened) == nil then
      return                                      -- never opened: nothing to hide
    end
    if not want and SKC.shown == "" then
      -- hidden already: keep it so every frame (a row the engine lit again is hidden again)
      for k in pairs(SKC.opened) do
        if Cmd(SKC.IS_OPEN, SKC.DOTS, k) == true and Cmd(SKC.VISIBLE, SKC.DOTS, k) ~= false then
          HideRow()
          break
        end
      end
      return
    end
    local state = want and tostring(SKC.page) or ""
    for k = 0, 3 do
      if not Ready(k, want) then
        SKC.shown = nil
      elseif not SKC.dots[k] then
        SKC.dots[k] = true
        SKC.shown = nil
        RowSetup(k)
      end
    end
    if SKC.gone or state == SKC.shown then
      return
    end
    SKC.shown = state
    for k = 0, 3 do
      if SKC.dots[k] then
        local dot = k == 1 or k == 2
        Cmd(SKC.MESH, SKC.DOTS, SKC.M_OFF, dot, k)
        Cmd(SKC.MESH, SKC.DOTS, SKC.M_ON, dot and SKC.page == k - 1, k)
        Cmd(SKC.LVIS, SKC.DOTS, k, state ~= "")
      end
    end
    Log("row", state == "" and "hidden" or ("page " .. state), "visible", Cmd(SKC.VISIBLE, SKC.DOTS, 1))
  end

  -- leaving / filter / sort: logged (original first, its results returned); the row hidden on back
  local SKC_RetailOnBack = OnBack
  function OnBack(...)
    local r = table.pack(SKC_RetailOnBack(...))
    Log("back")
    pcall(function()
      for k in pairs(SKC.opened) do
        if Cmd(SKC.IS_OPEN, SKC.DOTS, k) == true then
          Cmd(SKC.LVIS, SKC.DOTS, k, false)
        end
      end
      SKC.shown = ""
    end)
    return table.unpack(r, 1, r.n)
  end

  local SKC_RetailOnFunction = OnFunction
  function OnFunction(...)
    local r = table.pack(SKC_RetailOnFunction(...))
    Log("function", (...))
    return table.unpack(r, 1, r.n)
  end

  local function Poll()
    if not SKC.Focused() then
      return
    end
    local e = Effect(SKC.focus)
    if not e then
      return
    end
    if funcLuaMenuCommand(SKC.VISIBLE, SKC.CURSOR, 0) == false then
      return                                      -- the sort / filter window is open
    end
    if not (Pressed(SKC.K_L2) or Pressed(SKC.K_R2)) then
      return
    end
    funcLuaCommand(SKC.SE, SKC.SE_PAGE)
    if SKC.page == 0 then
      SKC.page = 1
      ShowEffect(e)
      UpdateButtonGuide()
    else
      SKC.page = 0
      local a = SKC.args
      UpdateSkillDetailWindow(table.unpack(a, 1, a.n))   -- the retail fill (and its UpdateButtonGuide)
    end
  end

  local SKC_RetailStep = Step
  function Step(...)
    local r = nil
    if SKC_RetailStep ~= nil then
      r = table.pack(SKC_RetailStep(...))
    end
    pcall(Poll)
    pcall(Row)
    if r ~= nil then
      return table.unpack(r, 1, r.n)
    end
  end
end
-- ===== EVT skill_card END =====
