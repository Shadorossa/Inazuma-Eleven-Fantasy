-- BattleBayDeluxe bb_draft, free-match grid (enjoy_team_select_menu_offline; docs/game/modes/estadio-bb.md §14).
-- 1.5.42 (owner: «el Draft no funciona en el 1 vs 1»): the Draft is played here as in the Campaña. This block only
-- names the host; the screen is the same block as the Campaña's (bbd_campaign.lua, appended after this one), which
-- reads BBCR_DRAFT_HOST for the free match's differences (the side being chosen, the hidden panels put back, the
-- tile's retail decide when the 16 are drafted) and keeps the placeholder players off the panel. scripts\campaign.lua
-- routes the Draft tile's decide to it (config.toml [draft] modes). Until 1.5.41 this file only drew the tile as open
-- and the decide was refused. Globals only; nothing runs at chunk load.
BBCR_DRAFT_HOST = "free_match"
