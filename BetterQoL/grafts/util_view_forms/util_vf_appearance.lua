-- Utilities «Cambiar forma» in the retail «Ver apariencia» (team_dock_formation_menu, the visual check mode of the team
-- dock: setting type 4, retail flag2), docs/game/mechanics/form-viewer.md §8. Moved from Inazuma Fantasy's graft
-- form_view (2026-10-14, owner), where Y (CMD_FUNC3) cycled; now the key is Utilities' action «Cambiar forma»
-- (BetterQoL.ViewForms, assets\lua\_all\utilities_view_forms.lua: CMD_UTIL_VIEW_FORMS, default RS / G, rebindable),
-- which calls BetterQoL.ViewForms.Appearance on a press here (the entry utilities.appearance of the host
-- utilities.view_forms, content\menus\view_forms.toml).
-- The forms are the VR-Framework's form viewer (CMND_VRFW_FORM_LIST / _MODEL / _CLEAR / _DUMP: Normal, Miximax, Armour,
-- Armour miximax, aura armour + miximax; only the ones the player has). The header reads «Ver apariencia · <form>» and
-- the button guide gets «<glyph> Cambiar forma» (3rd, before the camera hint). Normal / Miximax build on the retail
-- chara path (the model request gets the form's model); armour forms put the model id on the menu entry (0x92E95AA6)
-- and set the idle motion again once the model is loaded. Without the form viewer (no mod declares an armour or a
-- miximax: CMND_VRFW_FORM_LIST unanswered) the view stays retail.
-- HOOK file (docs/framework/lua-hosts.md §7): VRFW_Host handlers on the framework's host of team_dock_formation_menu,
-- the retail locals flag2 / n / n3 through VRFW_Host.hosts.team_dock_formation_menu.L (EVT_DEBUG; since VRFW 2.4.11
-- L serves the live copy when a merge-path patch promoted them, e.g. Inazuma Fantasy's merged file, which runs
-- before the host: lua_early). No engine call at load.
-- The forms come from every board slot of the card when no mod names an aura slot (2026-10-14: without Inazuma Fantasy
-- the list was always Normal, so no guide entry).
-- FORM INDICATOR (owner 2026-10-14: «arriba a la derecha del personaje», the look of Inazuma Fantasy's form badges):
-- while the shown player has more than one form, two square tiles side by side at the top right of the 3D character,
-- no text: a dark tile with the shown form's white glyph (FV.FORM_TILES) and a light tile under the action's glyph
-- (<CMD_UTIL_VIEW_FORMS>: the game draws the pad's button on a pad, the key's letter on a keyboard; follows the
-- binding). Layers added to the menu soccer_formation_menu, group team_dock_formation_menu
-- (content\menus\view_forms.toml): util_vf_tile x2 (cmn01_10 quads showing Utilities' own atlas
-- #/menu/102_team/util_view_forms/util_view_forms.g4tx, content\images\menu\view_forms_badge.toml) and util_vf_badge
-- (the retail change-page plate team00_40_change_page_guide, right-anchored at its origin, its grey base
-- _win_guide_base01 hidden: only its text, the glyph). Place / size / draw priority from config.toml [view_forms]
-- (CMND_BETTERQOL_VIEW_FORMS_CFG, scripts\view_forms.lua). The bottom guide entry stays.
-- Log per opened player (once the indicator is decided): "Utilities view_forms appearance", "open", <stem>, <hdl>,
-- "forms <form>=<source>; ...", "viewer yes|no", "guide yes|no", "indicator yes|no (<reason>)".
do
  local STEM = "team_dock_formation_menu"
  local FV = {
    LIST = 2188689660,         -- CMND_VRFW_FORM_LIST(hdl) -> n, form1..formN
    MODEL = 1264240712,        -- CMND_VRFW_FORM_MODEL(hdl, form) -> model id (0 = retail chara path)
    CLEAR = 2038320023,        -- CMND_VRFW_FORM_CLEAR() (viewer closed / left)
    DUMP = 2177911233,         -- CMND_VRFW_FORM_DUMP(hdl, form) (diagnostic: the slot logged once)
    LOG = 3661580131,          -- CMND_EVT_LOG
    SET_CHARA = 59611540,      -- 0x038D9994 (layer, idx, charaId)
    SET_MODEL = 2464766630,    -- 0x92E95AA6 (layer, idx, modelId): armour forms (the chara request ignores ForceKit)
    LAYER = 189137238,         -- team02_01_attach_formation_frame
    READY = 1583438030,        -- model loaded? (layer, idx)
    POSE = 180466856, POSE_ANIM = 2263925137, -- the viewer's idle motion (立ち1L)
    POSE_UPD = 953552931, POSE_UPD_ARG = 3459069566,
    GUIDE = 1138543975,        -- mainmenu01_06_base_button_guide
    BTN_TEXT = 3087075317,     -- menu_text utilities_view_forms_prompt «Cambiar forma»
    BTN_ICON = 508024922,      -- menu_text utilities_view_forms «<CMD_UTIL_VIEW_FORMS>» (the bound button)
    BTN_KEY = 44460916,        -- CMD_UTIL_VIEW_FORMS (the guide entry's click key)
    HEAD_TEXT = 1638840503,    -- «Ver apariencia»
    TEXT_GET = 4074371074,     -- CMND_TEXT_GET
    -- the form names (menu_text utilities_view_forms_form0..4, 9 languages)
    NAMES = {[0] = 2620987062, [1] = 3946718752, [2] = 1916237722, [3] = 87049996, [4] = 2606027439},
    SE = 1917805374, SE_SWITCH = 2629173176, -- sy0009
    ARMOUR_FORMS = {[2] = true, [3] = true, [4] = true},
    WAIT = 120,                -- frames a build may take to be ready (then: log «notready»)
    -- the form indicator: two tiles (layer util_vf_tile, instance 0 the form, 1 the key) + the key's glyph (layer
    -- util_vf_badge: a copy of the retail change-page plate team00_40_change_page_guide, only its text shown)
    TILES = 788105934,         -- util_vf_tile
    FORM_TILE = 0, KEY_TILE = 1,
    BADGE = 2233013648,        -- util_vf_badge
    BADGE_GLYPH_NODE = 950238781, -- _text_btn01 (left empty: the glyph goes in the text, whose centring is measured)
    BADGE_TEXT_NODE = 378156699,  -- _text_guide01
    BADGE_PLATE_MESH = 3491851413, -- _win_guide_base01 (the plate's grey base: hidden)
    -- the plate is right-anchored and sizes itself: a short text's centre sits TEXT_CX px (at scale 1) left of its
    -- origin (VR-Framework bb_pages, measured in game 2026-10-08)
    TEXT_CX = 102,
    ATLAS = "#/menu/102_team/util_view_forms/util_view_forms.g4tx",
    ATLAS_CRC = 2217195174,
    QUAD_NODE = 1909474081,    -- icon_new01 (the cmn01_10 quad's node)
    QUAD_SIZE = 36,            -- its side at scale 1
    -- the dark tile per form id of the VR-Framework's form viewer (0 Normal: the player bust, 1 Miximax, 2 Armour,
    -- 3 the miximax's own armour + Miximax, 4 the aura slot's armour + Miximax: the armour with a small Mix-Max mark)
    FORM_TILES = {[0] = 4269192750 --[[util_vf_tile_normal]], [1] = 3458440357 --[[util_vf_tile_miximax]],
      [2] = 1208954457 --[[util_vf_tile_armour]], [3] = 2369498841 --[[util_vf_tile_armour_miximax]],
      [4] = 2369498841 --[[util_vf_tile_armour_miximax]]},
    KEY_TILE_SPRITE = 2758009355, -- util_vf_tile_key (the light tile)
    LAYER_COUNT = 1175615627, IS_OPEN = 2640875187, OPEN_LAYER = 629267548, VISIBLE = 711242136,
    POSITION = 1389957207, SCALE = 3778714801, SET_TEXT = 1083631230, FIT_PLATE = 1172899594, PRIORITY = 1491630496,
    SPRITE = 558735651, MESH_VISIBLE = 3405944500, LOAD_TEXTURE = 839427544, TEXTURE_LOADING = 1506186496,
    CONFIG = 641711791,       -- CMND_BETTERQOL_VIEW_FORMS_CFG() -> config.toml [view_forms]
    OPEN_WAIT = 30,            -- frames the layers may take to report «open» (then shown all the same)
    TEXTURE_MIN = 10, TEXTURE_MAX = 600, -- frames the atlas takes at least / at most before the sprites are set
    -- defaults when the script does not answer (config.toml [view_forms] has the same values)
    BADGE_DEFAULTS = {badge_x = 1720, badge_y = 230, badge_scale = 1, badge_priority = 690, tile_size = 52,
      tile_gap = 6, key_scale = 0.9, key_dx = 0, key_dy = 0},
    hdl = 0, shown = 0, wait = 0, armour = false, entryModel = false, forms = {0}, idx = 1, dirty = false,
    labelled = false, sources = {"-"}, report = false, answered = false, guideDrawn = false,
    badgeOpenWait = 0, badgePlaced = false, badgeForm = nil, badgeConfig = nil,
    textureAsked = false, textureWait = 0, textureReady = false,
  }

  local function H()
    return VRFW_Host or EVT_Host
  end
  -- a retail local of the screen (nil without the host / EVT_DEBUG)
  local function Local(k)
    local h = type(H()) == "table" and type(H().hosts) == "table" and H().hosts[STEM] or nil
    if h == nil or h.L == nil then
      return nil
    end
    local ok, v = pcall(function()
      return h.L[k]
    end)
    return ok and v or nil
  end
  local function SetLocal(k, v)
    local h = type(H()) == "table" and type(H().hosts) == "table" and H().hosts[STEM] or nil
    if h ~= nil and h.L ~= nil then
      pcall(function()
        h.L[k] = v
      end)
    end
  end
  local function Viewing()
    return Local("flag2") == true
  end
  local function Log(...)
    pcall(funcLuaCommand, FV.LOG, "Utilities view_forms appearance", ...)
  end

  function FV.reset()
    FV.hdl, FV.forms, FV.idx, FV.dirty, FV.sources, FV.report = 0, {0}, 1, false, {"-"}, false
    FV.answered, FV.guideDrawn = false, false
  end

  function FV.load(hdl)
    FV.hdl, FV.idx = hdl, 1
    local V = type(BetterQoL) == "table" and BetterQoL.ViewForms or nil
    local src, answered
    if type(V) == "table" and type(V.Forms) == "function" then
      FV.forms, src, answered = V.Forms(hdl)
    else
      FV.forms = {0}
    end
    FV.sources = type(src) == "table" and src or {}
    FV.answered = answered == true
    FV.report = true   -- one log line once the guide and the indicator are decided (PostStep)
  end

  -- the model id stays in the model script (g_modelCharaModelID) until it is set again: clear it before any other
  -- build, else the next player / Normal keeps the armour
  function FV.dropEntryModel()
    if FV.entryModel then
      FV.entryModel = false
      funcLuaMenuCommand(FV.SET_MODEL, FV.LAYER, 0, 0)
    end
  end

  function FV.current()
    return FV.forms[FV.idx] or 0
  end

  function FV.modelOf(hdl, f)
    local ok, m = pcall(funcLuaCommand, FV.MODEL, hdl, f)
    if not ok or type(m) ~= "number" then
      return 0
    end
    return m
  end

  local function Text(id)
    local ok, t = pcall(funcLuaCommand, FV.TEXT_GET, id)
    return ok and type(t) == "string" and t or ""
  end

  function FV.header()
    local parent = 3902542018 --[[chronicle_mode_top_menu]]
    if g_parentMenuId ~= 0 and g_parentMenuId ~= nil then
      parent = g_parentMenuId
    end
    local text = Text(FV.HEAD_TEXT)
    if #FV.forms > 1 then
      local name = FV.NAMES[FV.current()] and Text(FV.NAMES[FV.current()]) or ""
      if name ~= "" then
        text = text .. " · " .. name
      end
      FV.labelled = true
    else
      FV.labelled = false
    end
    funcLuaCommand(830228314, parent, "SwapSoccerTopCommonHeaderTextByHeaderType", 5, text)
  end

  -- returns whether the «Cambiar forma» entry was drawn
  function FV.guide()
    if #FV.forms <= 1 then
      return false
    end
    -- «Cambiar forma» before the retail camera hint: that hint (icons inline in its text, x offset -36) is measured
    -- short, so an entry after it overlapped «cámara»; as the last entry it lays out as retail
    local texts = {2948285224, 2492731275, FV.BTN_TEXT, 986889694}
    local icons = {3891651141, 3705319142, FV.BTN_ICON, 0}
    local offs = {0, 18, 18, -36}
    local keys = {0, 0, FV.BTN_KEY, 0}
    local ok = pcall(funcLuaMenuCommand, 2209673388, g_parentMenuId, FV.GUIDE, texts, icons, offs)
    pcall(funcLuaMenuCommand, 452337289, g_parentMenuId, FV.GUIDE, keys)
    return ok
  end

  -- the indicator's place and size: config.toml [view_forms] through the script (read once per VM; defaults without an answer)
  function FV.badgeSettings()
    if FV.badgeConfig == nil then
      local c = {}
      for k, v in pairs(FV.BADGE_DEFAULTS) do
        c[k] = v
      end
      local ok, answer = pcall(funcLuaCommand, FV.CONFIG)
      if ok and type(answer) == "table" then
        for k in pairs(FV.BADGE_DEFAULTS) do
          if type(answer[k]) == "number" then
            c[k] = answer[k]
          end
        end
        c.from = "config"
      else
        c.from = "defaults (CMND_BETTERQOL_VIEW_FORMS_CFG unanswered)"
      end
      FV.badgeConfig = c
    end
    return FV.badgeConfig
  end

  -- the indicator's three instances: (layer, instance)
  function FV.badgeParts()
    return {{FV.TILES, FV.FORM_TILE}, {FV.TILES, FV.KEY_TILE}, {FV.BADGE, 0}}
  end

  function FV.hideBadge()
    if FV.badgeForm ~= nil then
      FV.badgeForm = nil
      for _, part in ipairs(FV.badgeParts()) do
        pcall(funcLuaMenuCommand, FV.VISIBLE, part[1], part[2], false)
      end
    end
  end

  -- Utilities' atlas of the tiles: asked once per VM, ready once the game no longer reports it loading (at least
  -- TEXTURE_MIN frames, at most TEXTURE_MAX); no sprite is set before
  function FV.textureLoaded()
    if FV.textureReady then
      return true
    end
    if not FV.textureAsked then
      FV.textureAsked, FV.textureWait = true, 0
      pcall(funcLuaMenuCommand, FV.LOAD_TEXTURE, FV.ATLAS)
    end
    FV.textureWait = FV.textureWait + 1
    local ok, loading = pcall(funcLuaCommand, FV.TEXTURE_LOADING, FV.ATLAS_CRC)
    local busy = ok and loading == true
    if (not busy and FV.textureWait >= FV.TEXTURE_MIN) or FV.textureWait >= FV.TEXTURE_MAX then
      FV.textureReady = true
    end
    return FV.textureReady
  end

  -- the two tiles and the key glyph laid out from the config: right edge badge_x, centre badge_y (screen px, y down)
  function FV.placeBadge(c)
    local scale = c.badge_scale
    local size, gap = c.tile_size * scale, c.tile_gap * scale
    local centreY = c.badge_y
    local keyX = c.badge_x - size / 2
    local formX = keyX - size - gap
    local quad = size / FV.QUAD_SIZE
    for _, tile in ipairs({{FV.FORM_TILE, formX}, {FV.KEY_TILE, keyX}}) do
      pcall(funcLuaMenuCommand, FV.SCALE, FV.TILES, quad, quad, 1, tile[1])
      pcall(funcLuaMenuCommand, FV.POSITION, FV.TILES, tile[2], -centreY, 0, tile[1])
      pcall(funcLuaMenuCommand, FV.PRIORITY, FV.TILES, tile[1], c.badge_priority, true)
    end
    pcall(funcLuaMenuCommand, FV.SPRITE, FV.TILES, FV.ATLAS_CRC, FV.KEY_TILE_SPRITE, FV.QUAD_NODE, 0, FV.KEY_TILE)
    -- the key's glyph: the plate's text centred on the light tile (the plate is right-anchored: its origin TEXT_CX
    -- px, scaled, right of the text's centre), its grey base and button node empty
    local glyph = Text(FV.BTN_ICON)
    if glyph == "" then
      glyph = "<CMD_UTIL_VIEW_FORMS>"
    end
    local k = c.key_scale * scale
    pcall(funcLuaMenuCommand, FV.SCALE, FV.BADGE, k, k, 1, 0)
    pcall(funcLuaMenuCommand, FV.POSITION, FV.BADGE, keyX + c.key_dx * scale + FV.TEXT_CX * k,
      -(centreY + c.key_dy * scale), 0, 0)
    pcall(funcLuaMenuCommand, FV.PRIORITY, FV.BADGE, 0, c.badge_priority + 1, true)
    pcall(funcLuaMenuCommand, FV.SET_TEXT, FV.BADGE, FV.BADGE_GLYPH_NODE, "", 0)
    pcall(funcLuaMenuCommand, FV.SET_TEXT, FV.BADGE, FV.BADGE_TEXT_NODE, glyph, 0)
    pcall(funcLuaMenuCommand, FV.FIT_PLATE, FV.BADGE, 0, FV.BADGE_TEXT_NODE)
    pcall(funcLuaMenuCommand, FV.MESH_VISIBLE, FV.BADGE, FV.BADGE_PLATE_MESH, false, 0)
  end

  -- the form tile + the key tile at the top right of the shown character; -> drawn (bool), why (text), final (false =
  -- still opening / loading)
  function FV.badge()
    if #FV.forms <= 1 then
      FV.hideBadge()
      return false, FV.answered and "only Normal" or "no form viewer (CMND_VRFW_FORM_LIST unanswered)", true
    end
    for _, layer in ipairs({FV.TILES, FV.BADGE}) do
      local okc, count = pcall(funcLuaMenuCommand, FV.LAYER_COUNT, layer)
      if not okc or type(count) ~= "number" or count <= 0 then
        return false, "no layer " .. (layer == FV.TILES and "util_vf_tile" or "util_vf_badge")
          .. " in this menu (content/menus/view_forms.toml not applied)", true
      end
    end
    local closed = {}
    for _, part in ipairs(FV.badgeParts()) do
      local oko, open = pcall(funcLuaMenuCommand, FV.IS_OPEN, part[1], part[2])
      if not (oko and open == true) then
        closed[#closed + 1] = part
      end
    end
    if #closed > 0 then
      if FV.badgeOpenWait == 0 then
        FV.badgePlaced, FV.badgeForm = false, nil   -- (re)opened: placed and filled again
        for _, part in ipairs(closed) do
          pcall(funcLuaMenuCommand, FV.OPEN_LAYER, part[1], part[2])
        end
      end
      FV.badgeOpenWait = FV.badgeOpenWait + 1
      if FV.badgeOpenWait < FV.OPEN_WAIT then
        return false, "opening", false
      end
    else
      FV.badgeOpenWait = 0
    end
    if not FV.textureLoaded() then
      return false, "loading", false
    end
    local c = FV.badgeSettings()
    if not FV.badgePlaced then
      FV.badgePlaced = true
      FV.placeBadge(c)
    end
    local form = FV.current()
    if FV.badgeForm ~= form then
      local sprite = FV.FORM_TILES[form] or FV.FORM_TILES[0]
      pcall(funcLuaMenuCommand, FV.SPRITE, FV.TILES, FV.ATLAS_CRC, sprite, FV.QUAD_NODE, 0, FV.FORM_TILE)
      for _, part in ipairs(FV.badgeParts()) do
        pcall(funcLuaMenuCommand, FV.VISIBLE, part[1], part[2], true)
      end
      FV.badgeForm = form
    end
    return true, "at " .. tostring(c.badge_x) .. "," .. tostring(c.badge_y) .. " from " .. tostring(c.from), true
  end

  -- one line per opened player: the stem, the forms with their sources (board slots), whether the framework's viewer
  -- answered, the guide entry and the indicator drawn or not (and why)
  function FV.logOpen(guideDrawn, badgeDrawn, why)
    local parts = {}
    for i, f in ipairs(FV.forms) do
      parts[#parts + 1] = tostring(f) .. "=" .. tostring(FV.sources[i] or "?")
    end
    Log("open", STEM, FV.hdl, "forms " .. table.concat(parts, "; "), "viewer " .. (FV.answered and "yes" or "no"),
      "guide " .. (guideDrawn and "yes" or "no"), "indicator " .. (badgeDrawn and "yes" or "no") .. " (" .. tostring(why) .. ")")
  end

  local function On(point, phase, fn)
    local h = H()
    if type(h) == "table" and type(h.on) == "function" then
      h.on(STEM, point, {id = "utilities.view_forms_appearance", phase = phase, fn = fn})
    end
  end

  -- the retail builder, always on the retail chara path; the framework swaps the model at the model request for the
  -- form picked by FORM_MODEL. A build that follows a non-Normal build is preceded by the retail EndViewChara3DModel,
  -- so the engine drops the old model and really builds again (a form change keeps the chara id).
  On("UpdateViewChara3DModel", "around", function(nxt, a1, a2, a3)
    if not FV.noLocals and type(Local("n")) ~= "number" then
      FV.noLocals = true   -- once per VM: without the host's locals the view is never detected (no forms, no guide)
      Log("no host locals (VRFW_Host map / EVT_DEBUG): «Ver apariencia» not detected", STEM)
    end
    if not Viewing() or a1 == nil or a1 == 0 then
      FV.dropEntryModel()
      if FV.hdl ~= 0 or FV.shown ~= 0 then
        pcall(funcLuaCommand, FV.CLEAR)
      end
      -- 2026-10-14 (owner: a form look belongs only to the view that chose it): the model last built in a form
      -- (shown now, or left built when the view closed) is ended first, so the retail build is Normal again
      if a1 ~= nil and a1 ~= 0 and (FV.shown ~= 0 or FV.leftFormModel) then
        pcall(EndViewChara3DModel)
        SetLocal("n3", 0)
        Log("form reset", a1, "outside the view")
      end
      FV.leftFormModel = false
      FV.reset()
      FV.shown = 0
      return nxt(a1, a2, a3)
    end
    if a1 ~= FV.hdl then
      FV.load(a1)
    end
    FV.dirty = true
    local f = FV.current()
    local m = FV.modelOf(a1, f)   -- arms (or clears) the framework's pick for this player
    if FV.shown ~= 0 or f ~= 0 or FV.leftFormModel then
      FV.leftFormModel = false
      FV.dropEntryModel()
      EndViewChara3DModel()
      SetLocal("n3", 0)
    end
    FV.shown = f
    FV.wait = FV.WAIT
    FV.armour = false
    if m == 0 or FV.ARMOUR_FORMS[f] ~= true then
      return nxt(a1, a2, a3)
    end
    -- armour forms: the model id goes on the menu entry first (the menu model script keeps it in g_modelCharaModelID),
    -- then the chara id (entry+0x78: the wearer's motion set); CMND_CHARA_MODEL_CHANGE keeps its retail identity
    FV.armour = true
    local real = funcLuaMenuCommand
    local chara = 0
    funcLuaMenuCommand = function(id, layer, idx, v, ...)
      if id == FV.SET_CHARA and layer == FV.LAYER and v ~= 0 then
        chara = v
        real(FV.SET_MODEL, layer, idx, m)
        FV.entryModel = true
      end
      return real(id, layer, idx, v, ...)
    end
    local ok, err = pcall(nxt, a1, a2, a3)
    funcLuaMenuCommand = real
    Log("armour build", chara, m)
    if not ok then
      error(err, 0)
    end
  end)

  -- the press (BetterQoL.ViewForms calls it in this menu): the next form, the builder again
  BetterQoL = type(BetterQoL) == "table" and BetterQoL or {}
  BetterQoL.ViewForms = type(BetterQoL.ViewForms) == "table" and BetterQoL.ViewForms or {}
  function BetterQoL.ViewForms.Appearance()
    if not Viewing() or FV.hdl == 0 or #FV.forms <= 1 then
      return false
    end
    FV.idx = FV.idx % #FV.forms + 1
    funcLuaCommand(FV.SE, FV.SE_SWITCH)
    Log("form", FV.hdl, FV.current())
    local leader = type(IsSelectLeaderCard) == "function" and IsSelectLeaderCard() or false
    UpdateViewChara3DModel(FV.hdl, Local("n") or 0, leader)
    return true
  end

  On("PostStep", "after", function()
    -- once the model is ready: armour forms get the idle motion again; every form: the slot dump (diagnostic)
    local viewing = Viewing()
    if FV.wait > 0 then
      FV.wait = FV.wait - 1
      if not viewing or #FV.forms <= 1 then
        FV.wait = 0
      elseif funcLuaMenuCommand(FV.READY, FV.LAYER, 0) == true then
        FV.wait = 0
        if FV.armour then
          funcLuaMenuCommand(FV.POSE, FV.LAYER, 0, FV.POSE_ANIM, 0, 0)
          funcLuaMenuCommand(FV.POSE_UPD, FV.LAYER, 0, FV.POSE_UPD_ARG)
          Log("pose", FV.hdl, FV.current())
        end
        pcall(funcLuaCommand, FV.DUMP, FV.hdl, FV.current())
      elseif FV.wait == 0 then
        Log("notready", FV.hdl, FV.current())
      end
    end
    if not viewing then
      FV.labelled = false
      FV.hideBadge()
      return
    end
    if FV.dirty then
      FV.dirty = false
      if #FV.forms > 1 or FV.labelled then
        FV.header()
      end
      FV.guideDrawn = FV.guide()
    end
    -- every frame while viewing (cheap once drawn: only a form change rewrites it)
    local badgeDrawn, why, final = FV.badge()
    if FV.report and final then
      FV.report = false
      FV.logOpen(FV.guideDrawn, badgeDrawn, why)
    end
  end)

  On("OnFunction", "around", function(nxt, a1, a2, ...)
    if Viewing() and a1 == 318865860 --[[close]] then
      FV.dropEntryModel()
    end
    local r = table.pack(nxt(a1, a2, ...))
    if not Viewing() then
      FV.dropEntryModel()
      if FV.hdl ~= 0 or FV.shown ~= 0 then
        pcall(funcLuaCommand, FV.CLEAR)
        -- leaving the view: the form look stays only there; a model still built in a form is ended before the next
        -- build (Normal: next visit, or the dock outside the view)
        FV.leftFormModel = FV.leftFormModel or FV.shown ~= 0
        FV.reset()
        FV.shown = 0
        FV.labelled = false
      end
    end
    return table.unpack(r, 1, r.n)
  end)
end
