-- Battle Bay Deluxe (prefix BattleBayDeluxe): the photo scene after the Torneo's final (the game's Victory Road
-- final photo; docs/game/mods/bbd-tournament-celebration.md). The tournament-final end of the game (rule word bit 24,
-- content\rules\bbd_final.toml) opens it after the champions' celebration. Its online plates have no data offline:
-- the player's online name plate, title and gamer tag are hidden as they open; the tournament plate shows the Torneo's
-- name. Only while BBD's tournament is at its final (CMND_BBD_TOURN_INFO .final); otherwise nothing changes. The same
-- file serves the auto photo and the free photo mode (victory_road_final_game_auto_photo_menu / _manual_photo_menu).
-- Nothing runs at load time.
do
  local PHOTO = {
    TOURN_INFO = 2943906085,          -- crc32("CMND_BBD_TOURN_INFO")
    TEXT_GET = 4074371074,            -- CMND_TEXT_GET
    TOURNAMENT_NAME = 600387584,      -- crc32("evt_bbd_tn_mode_tournament")
    LAYER_VISIBLE = 711242136,
    SET_TEXT = 1083631230,
    LOG = 3661580131,                 -- CMND_EVT_LOG
    TOURNAMENT_PLATE = 718961583,     -- vroad01_52_tournament_plate_big
    TOURNAMENT_TEXT = 1691757743,     -- _text_tournament01
    ONLINE_PLATES = {
      [3546704442] = true,            -- soccer00_40_username_champion_photo
      [2280287248] = true,            -- soccer00_43_user_title
      [3351788064] = true,            -- cmn01_54_user_id_c
    },
    STEMS = { "victory_road_final_game_auto_photo_menu", "victory_road_final_game_manual_photo_menu" },
  }
  local final, logged = nil, false

  local function bbd_final()
    if final == nil then
      local ok, info = pcall(funcLuaCommand, PHOTO.TOURN_INFO)
      final = ok and type(info) == "table" and info.active == true and info.final == true
    end
    return final
  end

  local function opened(layer, index)
    if not bbd_final() then return end
    index = type(index) == "number" and index or 0
    if PHOTO.ONLINE_PLATES[layer] then
      pcall(funcLuaMenuCommand, PHOTO.LAYER_VISIBLE, layer, index, false)
    elseif layer == PHOTO.TOURNAMENT_PLATE then
      local ok, name = pcall(funcLuaCommand, PHOTO.TEXT_GET, PHOTO.TOURNAMENT_NAME)
      if ok and type(name) == "string" then
        pcall(funcLuaMenuCommand, PHOTO.SET_TEXT, layer, PHOTO.TOURNAMENT_TEXT, name, index)
      end
    end
    if not logged then
      logged = true
      pcall(funcLuaCommand, PHOTO.LOG, "bb_tournament", "final photo: online plates hidden, tournament plate named")
    end
  end

  if VRFW_Host then
    for _, stem in ipairs(PHOTO.STEMS) do
      VRFW_Host.on(stem, "OnInit", { id = "battle_bay_deluxe.final_photo.init", phase = "before", create = true,
        fn = function() final, logged = nil, false end })
      VRFW_Host.on(stem, "OnOpenLayer", { id = "battle_bay_deluxe.final_photo.plates", phase = "after", create = true,
        fn = function(layer, index) pcall(opened, layer, index) end })
    end
  end
end
