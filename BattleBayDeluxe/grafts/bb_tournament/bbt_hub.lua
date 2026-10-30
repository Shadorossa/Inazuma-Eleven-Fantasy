-- BattleBayDeluxe bb_tournament, «Modos de juego» (soccer_top_menu; Inazuma Fantasy's mode hub: graft modes_hub,
-- docs/game/modes/bb-tournament.md §0 1.5.18). Appended after bbt_common.lua + bbt_top.lua: the Torneo runs on THIS
-- screen (BattleBayDeluxe.TournamentHost below), never through the Battle Bay top menu (owner 2026-10-12: «not even for 0.6 s»).
--   * BBT_HubEntry(): the hub's «Torneo» tile (mh_hub.lua calls it in its decide coroutine; the top bar's Battle Bay →
--     Torneo is the title's «Modos de juego» request with the step mh_box.bb_tournament, which presses that tile):
--     no run = the team grid at once (the hub's own BB grid, EVT_MH_OpenBBGrid, with the tournament armed); a run =
--     the bracket with the Torneo window centred over it (bbt_top.lua BBT_EntryFlow).
--   * the bracket's layers are this menu's too (content\menus\bb_tournament.toml, soccer_top_menu patches); while it
--     is up the hub's tiles, group headers, utility boxes and help line are invisible and lose the focus; closing it
--     gives the focus back to the Torneo tile (EVT_MH_HostedBack).
--   * a tournament match started here: the hub's «BB match» mark (EVT_MH_MarkBBMatch) makes the engine reopen this
--     menu after the match; its OnInit syncs the result (bbt_top.lua) and the bracket opens on the round's results.
-- Without Inazuma Fantasy's hub (no EVT_MH_* globals) nothing here runs: the tile does not exist. Globals only;
-- nothing runs at chunk load.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}
BattleBayDeluxe.TournamentHub = {
  KEY = "bb_tournament",                -- the hub tile's key (mh_hub.lua EVT_MH_BOXES)
  MODE = 534469705 --[[evt_mode_box]], DECO = 1293605056 --[[evt_mh_deco]], UTIL = 2237531969 --[[evt_comp_box]],
  NOTICE = @crc:evt_comp_box_notice@, GUIDE = 1611500684 --[[mainmenu90_06_content_guide_line03]],
  GRID_VARIANT = 1455139087 --[[enjoy_team_select_menu_campaign]],
  ART = 1167254348 --[[mainmenu90_00_p1_background]],
}
BattleBayDeluxe.TournamentHost = {
  name = "soccer_top_menu", menu = 811496143,
  -- 1.5.22: the bracket's layers here are opened with the menu's group and shown / hidden by visibility only
  vis_only = true,
  -- 1.5.27: back from a tournament match the screen stays black until the bracket is up (no hub in between)
  cover = true,
  hide = { BattleBayDeluxe.TournamentHub.MODE, BattleBayDeluxe.TournamentHub.DECO, BattleBayDeluxe.TournamentHub.UTIL, BattleBayDeluxe.TournamentHub.GUIDE },
  -- 1.5.19 (owner: only the hub's character art, dimmed, behind the window): the hub's art layer
  -- (mainmenu90_00_p1_background) is closed under the bracket, as the Battle Bay top menu closes its own art
  close = { BattleBayDeluxe.TournamentHub.NOTICE, BattleBayDeluxe.TournamentHub.ART },
  lists = { BattleBayDeluxe.TournamentHub.MODE, BattleBayDeluxe.TournamentHub.UTIL },
  step = nil,
  -- 1.5.19 (owner: «Cuadro final» and a teal box over the top bar): the hub's header stays «Modos de juego» (the BB
  -- header type 30 does not fit this menu); the page title is not shown here
  title = function(_t) end,
  header = function() end,
  refocus = function()
    if type(EVT_MH_HostedBack) == "function" then
      EVT_MH_HostedBack(BattleBayDeluxe.TournamentHub.KEY)
    end
  end,
  ready = function()
    return funcLuaMenuCommand(@crc:CMND_IS_CTRL_FOCUS_ACTIVE@, BattleBayDeluxe.TournamentHub.MODE) == true
      or funcLuaMenuCommand(@crc:CMND_IS_CTRL_FOCUS_ACTIVE@, BattleBayDeluxe.TournamentHub.UTIL) == true
  end,
  open_grid = function()
    if type(EVT_MH_OpenBBGrid) == "function" then
      EVT_MH_OpenBBGrid(BattleBayDeluxe.TournamentHub.KEY, BattleBayDeluxe.TournamentHub.GRID_VARIANT)
    else
      BBT_Log("hub: no EVT_MH_OpenBBGrid (Inazuma Fantasy's hub too old): no grid")
    end
  end,
  before_match = function()
    if type(EVT_MH_MarkBBMatch) == "function" then
      EVT_MH_MarkBBMatch(BattleBayDeluxe.TournamentHub.KEY)
    end
  end,
  -- 1.5.58 (layer budget, docs/game/ui/menu-layer-limits.md §2.3): this menu's pools where they differ from the Battle
  -- Bay top menu's (BattleBayDeluxe.Tournament.N; the counts of content\menus\bb_tournament.toml, soccer_top_menu patches: change both
  -- together): no score-box pool, its boxes drawn on the connector pool at the box's draw priority (share); 64 texts
  -- (1.5.60: the same as the Battle Bay top menu; the group tables are drawn in their own menu, BBT_GroupsShow)
  pools = { box = 0, txt = 64 },
  share = { box = "line" },
}
for k, n in pairs(BattleBayDeluxe.TournamentHost.pools) do
  BattleBayDeluxe.Tournament.N[k] = n
end
BattleBayDeluxe.Tournament.SHARE = BattleBayDeluxe.TournamentHost.share

-- 1.5.22: every bracket layer (opened with this menu's group: content\menus\bb_tournament.toml) hidden and parked at
-- its setup, the anchor without the control focus until the bracket opens
do
  local setup = OnSetupLayer
  function OnSetupLayer(a1, a2, ...)
    local r = table.pack(setup(a1, a2, ...))
    local ours = a1 == BattleBayDeluxe.Tournament.ANCHOR
    for _, l in pairs(BattleBayDeluxe.Tournament.L) do
      if l == a1 then
        ours = true
      end
    end
    if ours then
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, a1, a2 or 0, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, a1, -4000, 4000, 0, a2 or 0)
      -- 1.5.33 (owner 2026-10-13, softlock): back from a tournament match the results bracket opens under the cover
      -- 2 Steps after the hub's focus, BEFORE this menu set up the anchor (log: anchor focus on at f7, off at f8 from
      -- here): the anchor lost its control focus and Aceptar / Esc / the mouse reached nothing. While the bracket is
      -- up the anchor keeps the focus, and a bracket layer set up late is drawn again (Step, bbt_top.lua)
      if BattleBayDeluxe.TournamentState.open then
        if a1 == BattleBayDeluxe.Tournament.ANCHOR then
          funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, a1, true)
          funcLuaMenuCommand(1778826357, a1, 0, true)
          BBT_Log("anchor set up while the bracket is open: focus kept")
        else
          BattleBayDeluxe.TournamentState.redraw = true
        end
      elseif a1 == BattleBayDeluxe.Tournament.ANCHOR then
        funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, a1, false)
      end
    end
    return table.unpack(r, 1, r.n)
  end
end

-- the hub's Torneo tile decided (runs in the hub's decide coroutine)
function BBT_HubEntry()
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
  BBT_Log("hub: Torneo tile")
  BBT_EntryTournament()
end
