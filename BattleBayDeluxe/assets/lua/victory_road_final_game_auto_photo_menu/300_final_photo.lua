-- Battle Bay Deluxe (prefix BattleBayDeluxe): the photo scene after a won competition (the game's Victory Road final
-- photo; docs/game/mods/bbd-tournament-celebration.md §7). The tournament-final end of the game (rule word bit 24, set
-- by scripts\lib\trophy_celebration.lua when the match wins the Torneo, the Liga, the Campaña or the Reto diario)
-- opens it after the champions' celebration. Its online plates have no data offline: the player's online name plate,
-- title and gamer tag are hidden as they open; the tournament plate shows the competition's name. Only while a BBD
-- celebration is on (CMND_BBD_TROPHY_INFO .active); otherwise nothing changes. The same file serves the auto photo and
-- the free photo mode (victory_road_final_game_auto_photo_menu / _manual_photo_menu). Nothing runs at load time.
do
  local PHOTO = {
    TROPHY_INFO = VRFW_Cmd.BBD_TROPHY_INFO,        -- crc32("CMND_BBD_TROPHY_INFO")
    TEXT_GET = VRFW_Cmd.TEXT_GET,            -- CMND_TEXT_GET
    LAYER_VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE,
    SET_TEXT = VRFW_Cmd.SET_MENU_TEXT_STRING,
    LOG = VRFW_Cmd.EVT_LOG,                 -- CMND_EVT_LOG
    TOURNAMENT_PLATE = 718961583,     -- vroad01_52_tournament_plate_big
    TOURNAMENT_TEXT = 1691757743,     -- _text_tournament01
    ONLINE_PLATES = {
      [3546704442] = true,            -- soccer00_40_username_champion_photo
      [2280287248] = true,            -- soccer00_43_user_title
      [3351788064] = true,            -- cmn01_54_user_id_c
    },
    STEMS = { "victory_road_final_game_auto_photo_menu", "victory_road_final_game_manual_photo_menu" },
  }
  local trophy, logged = nil, false

  -- the BBD celebration being shown: { active, competition, name, name_id } (CMND_BBD_TROPHY_INFO), asked once per
  -- photo scene; false = none
  local function bbd_trophy()
    if trophy == nil then
      local ok, info = pcall(funcLuaCommand, PHOTO.TROPHY_INFO)
      trophy = ok and type(info) == "table" and info.active == true and info or false
    end
    return trophy
  end

  local function opened(layer, index)
    local t = bbd_trophy()
    if not t then return end
    index = type(index) == "number" and index or 0
    if PHOTO.ONLINE_PLATES[layer] then
      pcall(funcLuaMenuCommand, PHOTO.LAYER_VISIBLE, layer, index, false)
    elseif layer == PHOTO.TOURNAMENT_PLATE and type(t.name_id) == "number" then
      local ok, name = pcall(funcLuaCommand, PHOTO.TEXT_GET, t.name_id)
      if ok and type(name) == "string" then
        pcall(funcLuaMenuCommand, PHOTO.SET_TEXT, layer, PHOTO.TOURNAMENT_TEXT, name, index)
      end
    end
    if not logged then
      logged = true
      pcall(funcLuaCommand, PHOTO.LOG, "BattleBayDeluxe.trophy",
        "celebration photo: online plates hidden, plate named for " .. tostring(t.competition))
    end
  end

  if VRFW_Host then
    for _, stem in ipairs(PHOTO.STEMS) do
      VRFW_Host.on(stem, "OnInit", { id = "battle_bay_deluxe.final_photo.init", phase = "before", create = true,
        fn = function() trophy, logged = nil, false end })
      VRFW_Host.on(stem, "OnOpenLayer", { id = "battle_bay_deluxe.final_photo.plates", phase = "after", create = true,
        fn = function(layer, index) pcall(opened, layer, index) end })
    end
  end
end
