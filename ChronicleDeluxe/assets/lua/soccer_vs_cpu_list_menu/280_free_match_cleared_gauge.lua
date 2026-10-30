-- Chronicle Deluxe: the «team cleared» gauge of the Competition list (docs/game/mods/chronicle-deluxe-free-match.md §7).
-- While BetterMenu shows the free-match list as its crest strip, the selected team's crest gets the list row's own
-- clear gauge under it, above the team name: the single-orb pill with the orb of the HIGHEST class won against that
-- team (INAZUMA / ZONA LETAL / BATALLA LEGENDARIA; the framework's VRFW_FM.Best on the retail clear bits), the empty
-- pill when no class is won. The gauge is this mod's own instance of the retail layer object (content\menus\
-- free_match_cleared_gauge.toml); BetterMenu moves the name down by the band this file reserves
-- (BetterMenu.Competition.ReserveUnderCrest). Drawn when BetterMenu's strip is ready after each list open (so after a
-- match too; BetterMenu.Competition.strip_listeners) and on every later focus change; no per-frame work.
-- Never during the list's OnInit / row setup: the focused-game command 1666448199 reads the list menu object, which
-- does not exist yet there (null read in nie.exe+0xCB6910, the 1.10.0 crash). No engine call at load time.
ChronicleDeluxe = type(ChronicleDeluxe) == "table" and ChronicleDeluxe or {}
ChronicleDeluxe.ClearedGauge = ChronicleDeluxe.ClearedGauge or {}
do
  local G = ChronicleDeluxe.ClearedGauge
  local ID = "ChronicleDeluxe.ClearedGauge"
  local LAYER = 2077193753          -- crc32("chronicle_deluxe_cleared_gauge"), the layer this mod adds to the menu
  local ITEM = 1074924810           -- mainmenu90_19_vs_cpu_list_item: the list rows' focus layer
  local PILL, CAPSULE, PILL_ORB = 3279539624, 1517329426, 1736224650   -- _pos_base02, _pos_base01, _pos_clear05
  -- One orb: the pill's own orb (_pos_clear05, mesh _clear_icon05) shows the class's colour by a sprite swap on this
  -- instance; the capsule with the four class orbs (_pos_base01) stays hidden. (1.11.x showed the capsule's class-9
  -- orb and swapped the sprite slot clear_icon04, which is not the one that orb draws: it stayed red / orange.)
  -- The orb mesh's slot is one of the orb sprites of the layout's slot table; both candidates are swapped.
  local PILL_ORB_MESH = 975366913   -- _clear_icon05
  local PILL_ORB_GLOWS = {718623365, 3017540415}   -- _clear_icon05_add01, _add02 (additive copies: hidden)
  local ORB_SLOTS = {394180926, 1618577832}   -- clear_icon04, clear_icon05
  local ORB_ATLAS = 2855820778      -- crc32("#/menu/30_vsroute/vsroute01/vsroute01_06b/vsroute01_06b.g4tx")
  -- the colours (owner 2026-10-19): INAZUMA blue, ZONA LETAL purple (retail orb sprites), BATALLA LEGENDARIA green-cyan
  -- (chronicle_deluxe_legendary_orb, content/images/menu/30_vsroute/vsroute01/vsroute01_06b.toml)
  local ORB_SPRITE = {[6] = 1729383857, [7] = 4263320587, [8] = 2290219986, [9] = 2290219986}   -- clear_icon01, clear_icon02, legendary
  local CLASSES = {6, 7, 8, 9}
  local CLEAR = VRFW_Cmd.GET_SOCCER_GAME_CLEAR_FLAG           -- (game, class)
  local LOG = VRFW_Cmd.EVT_LOG
  -- the pill + orb in the layout once [VRFW.FreeMatch] Orb = "best" put the class orbs on the single slot: centred on
  -- the capsule's top orb _pos_clear04 (27, -33) of vsroute01_06b.g4pkm; its height is the pill's (_clear_base02,
  -- 48 x 32 px; the orbs are 32 px too). Spacing (owner 2026-10-19: centred between the crest and the name): with
  -- BetterMenu's on-screen crest bottom and name glyph top (CREST_BOTTOM, NAME_GLYPH_TOP), the name moves down by half
  -- the gauge's height and the gauge sits midway between the crest's bottom and the name's glyphs.
  local CENTRE_X, CENTRE_Y, HEIGHT = 27, -33, 32
  G.logged = nil               -- the game whose gauge was last logged (one line per team focus)
  local SCALE, PRIORITY = 1.0, 575
  G.opened = false
  G.ready = false              -- true once the list menu exists (BetterMenu's strip ready or a row focus change)

  local function M(...) local r = table.pack(pcall(funcLuaMenuCommand, ...)) if r[1] then return table.unpack(r, 2, r.n) end end
  local function competition()
    local C = BetterMenu and BetterMenu.Competition
    if type(C) ~= "table" or type(C.ReserveUnderCrest) ~= "function" or type(C.Active) ~= "function" then return nil end
    if C.Active() ~= true then return nil end
    return C
  end

  -- the layer's instance exists (the menu patch applied): every layer command below is guarded by it
  local function has_layer()
    local n = M(VRFW_Cmd.GET_CREATE_LAYER_NUM, LAYER)            -- created instances of the layer
    return type(n) == "number" and n >= 1
  end

  local function hide()
    local C = BetterMenu and BetterMenu.Competition
    if type(C) == "table" and type(C.ReserveUnderCrest) == "function" then C.ReserveUnderCrest(ID, 0) end
    if has_layer() then M(VRFW_Cmd.SET_LAYER_VISIBLE, LAYER, 0, false) end
  end

  -- the gauge of the focused team: its highest class won, or the empty pill
  function G.Refresh()
    if not G.ready or not has_layer() then return end
    local C = competition()
    if not C or not VRFW_FM or type(VRFW_FM.Best) ~= "function" then return hide() end
    local ok, game = M(1666448199, 0)
    if not ok or type(game) ~= "number" or game == 0 then return hide() end
    local okb, best = pcall(VRFW_FM.Best, game)
    if not okb or type(best) ~= "number" then return hide() end
    if ORB_SPRITE[best] == nil then best = 0 end  -- nothing won: the empty pill, no orb (owner 2026-10-19)
    local band = HEIGHT / 2
    local top, x, crest_bottom, glyph = C.ReserveUnderCrest(ID, band)
    if type(glyph) ~= "number" then glyph = 0 end
    if type(crest_bottom) ~= "number" then crest_bottom = top + glyph end
    local name_top = top + band + glyph
    local centre = (crest_bottom + name_top) / 2
    if not G.opened then
      M(VRFW_Cmd.OPEN_LAYER, LAYER, 0)
      M(3849595087, LAYER, 2, 0)                -- as the retail list opens its clear-icon instances
      G.opened = true
    end
    M(2158717427, LAYER, CAPSULE, false, 0)
    M(2158717427, LAYER, PILL, true, 0)
    local sprite = ORB_SPRITE[best]
    M(2158717427, LAYER, PILL_ORB, sprite ~= nil, 0)
    M(VRFW_Cmd.SET_MESH_VISIBLE, LAYER, PILL_ORB_MESH, sprite ~= nil, 0)
    for _, mesh in ipairs(PILL_ORB_GLOWS) do M(VRFW_Cmd.SET_MESH_VISIBLE, LAYER, mesh, false, 0) end
    local swapped = {}
    if sprite ~= nil then
      for k, slot in ipairs(ORB_SLOTS) do swapped[k] = tostring(M(558735651, LAYER, ORB_ATLAS, sprite, slot, 0, 0)) end
    end
    if G.logged ~= game then
      G.logged = game
      local won = {}
      for _, d in ipairs(CLASSES) do won[#won + 1] = d .. "=" .. tostring(funcLuaCommand(CLEAR, game, d)) end
      pcall(funcLuaCommand, LOG, string.format("ChronicleDeluxe cleared gauge: game %s best %s won [%s] orb sprite swap [%s] at y %s",
        tostring(game), tostring(best), table.concat(won, " "), table.concat(swapped, " "), tostring(centre)))
    end    M(VRFW_Cmd.SET_LAYER_LOCAL_SCALE, LAYER, SCALE, SCALE, 1, 0)
    M(VRFW_Cmd.SET_LAYER_LOCAL_POS, LAYER, x - CENTRE_X * SCALE, -centre - CENTRE_Y * SCALE, 0, 0)
    M(VRFW_Cmd.SET_DRAW_PRIORITY, LAYER, 0, PRIORITY, true)
    M(VRFW_Cmd.SET_LAYER_VISIBLE, LAYER, 0, true)
  end

  -- BetterMenu's strip turned on (its overlay set): draw the gauge of the team already focused (BetterMenu calls
  -- every BetterMenu.Competition.strip_listeners entry; the table is created here when this file loads first)
  BetterMenu = type(BetterMenu) == "table" and BetterMenu or {}
  BetterMenu.Competition = BetterMenu.Competition or {}
  BetterMenu.Competition.strip_listeners = BetterMenu.Competition.strip_listeners or {}
  BetterMenu.Competition.strip_listeners[ID] = function() G.ready = true G.Refresh() end
  if VRFW_Host then
    -- a new list: nothing is drawn until the menu exists (no engine call here)
    VRFW_Host.on("soccer_vs_cpu_list_menu", "OnInit", { id = "chronicle_deluxe.cleared_gauge.open", phase = "before",
      fn = function() G.opened, G.ready = false, false end })
    VRFW_Host.on("soccer_vs_cpu_list_menu", "OnChangeFocus", { id = "chronicle_deluxe.cleared_gauge.focus", phase = "after",
      fn = function(r, a1) if a1 == ITEM and G.ready then G.Refresh() end end })
  end
end
