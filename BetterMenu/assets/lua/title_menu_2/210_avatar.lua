-- BetterMenu: the avatar on the main menu (title_menu_2; docs/game/mods/better-menu.md §14). Handlers of the framework's
-- title_menu_2 host (VRFW_Host).
--   * The AVATAR banner is gone (content\menus\title_avatar.toml moves its layout off screen): up / down from the
--     tile rows go to the «Mi equipo» banner instead of it.
--   * While «Modo Historia» is focused, X opens the game's Avatar menu (the banner's own A: its OnEnter), and the
--     tile's balloon names the key (text key better_menu.avatar_prompt). The camera then shows the avatar in the left
--     wing of the clubhouse (the scene's «story» shot). On any other tile X (Alt on a keyboard) does nothing: the
--     title's «Inazuma Post» window is not opened from the main menu. On the menu scene's home entry (game param
--     vrfw_menu_scene_home) X does nothing, whatever tile holds the hidden focus.
-- No engine call at load time.

local BMA = {
  ID = "better_menu.avatar",
  AVATAR_BANNER = 1526508152,   -- title02_11_avatar_banner
  TEAM_BANNER = 4086303486,     -- title02_10_my_team_banner
  UPPER = 2250456639,           -- title00_07_item_button_upper: the mode row
  STORY = 296576821,            -- the title's «Modo Historia» item
  FUNCTION = 3082215840,        -- crc32 better_menu_avatar: CMD_FUNC4 on the mode row (content\menus\title_avatar.toml)
  POST = 1519021197,            -- the title's «Inazuma Post» function (CMD_FUNC1: X on a pad): the Avatar menu on «Modo Historia»
  BALLOON = 715157494,          -- title02_09_flavor_balloon_upper
  TEXT_NODE = 499981750,        -- _text_explain01
  SET_TEXT = 1083631230,        -- CMND_SET_MENU_TEXT_STRING
  TEXT_GET = 4074371074,        -- CMND_TEXT_GET (id)
  TEXT_GET_KEY = 459261927,     -- CMND_VRFW_TEXT_GET (key)
  PROMPT_ID = 1764575574,       -- crc32 better_menu.avatar_prompt
  PROMPT_KEY = "better_menu.avatar_prompt",
  SOUND = 1917805374,
  BUZZER = 2086672038,          -- sy0003
  LOG = 3661580131,
  PARAM_HAS = 2947612279,       -- (key) -> set
}

local function BMA_Log(...)
  pcall(funcLuaCommand, BMA.LOG, "better_menu", "avatar", ...)
end

-- the mode row's focused item, or nil (also on the menu scene's home entry: no mode)
local function BMA_Focused()
  if type(GetSelectItemLayerName) ~= "function" or GetSelectItemLayerName() ~= BMA.UPPER then
    return nil
  end
  if type(VRFW_MenuSceneIsHome) == "function" and VRFW_MenuSceneIsHome() then
    return nil
  end
  local ok, item = pcall(GetTitleMenuItemId, GetSelectItemIdx(), true)
  return ok and item or nil
end

local function BMA_Prompt()
  local ok, t = pcall(funcLuaCommand, BMA.TEXT_GET, BMA.PROMPT_ID)
  if ok and type(t) == "string" and t ~= "" then return t end
  ok, t = pcall(funcLuaCommand, BMA.TEXT_GET_KEY, BMA.PROMPT_KEY)
  if ok and type(t) == "string" and t ~= "" then return t end
  return nil
end

if VRFW_Host ~= nil then
  -- no AVATAR banner to move to: the «Mi equipo» banner instead
  VRFW_Host.on("title_menu_2", "GetNextFocusBannerLayerName", {
    id = BMA.ID .. ".banner",
    phase = "after",
    fn = function(r)
      if r[1] == BMA.AVATAR_BANNER then
        r[1] = BMA.TEAM_BANNER
      end
    end,
  })

  -- X on «Modo Historia»: the Avatar menu, as the banner's A did
  VRFW_Host.on("title_menu_2", "OnFunction", {
    id = BMA.ID .. ".open",
    phase = "around",
    fn = function(nxt, a1, a2, ...)
      if a1 == BMA.POST then
        -- no Inazuma Post window from the main menu (owner): X / Alt only opens the Avatar menu on «Modo Historia»
        if BMA_Focused() == BMA.STORY and type(OnEnter) == "function" then
          BMA_Log("X on «Modo Historia»: the Avatar menu (not Inazuma Post)")
          return OnEnter(BMA.AVATAR_BANNER, 0)
        end
        BMA_Log("X / Alt: Inazuma Post is off on the main menu")
        return
      end
      if a1 ~= BMA.FUNCTION then
        return nxt(a1, a2, ...)
      end
      if type(VRFW_MenuSceneIsHome) == "function" and VRFW_MenuSceneIsHome() then
        BMA_Log("X on the home entry: nothing")
        return
      end
      if BMA_Focused() ~= BMA.STORY or type(OnEnter) ~= "function" then
        pcall(funcLuaCommand, BMA.SOUND, BMA.BUZZER)
        return
      end
      BMA_Log("X on «Modo Historia»: the Avatar menu")
      return OnEnter(BMA.AVATAR_BANNER, 0)
    end,
  })

  -- the «Modo Historia» balloon names the key
  VRFW_Host.on("title_menu_2", "SetFlavorBalloonText", {
    id = BMA.ID .. ".prompt",
    phase = "after",
    fn = function()
      if BMA_Focused() ~= BMA.STORY then
        return
      end
      local h = VRFW_Host.hosts and VRFW_Host.hosts.title_menu_2
      local L = h and h.L
      local ok, id = pcall(function() return L.t9[GetSelectItemIdx() + 1] end)
      local prompt = BMA_Prompt()
      if not ok or type(id) ~= "number" or not prompt then
        return
      end
      local base = funcLuaCommand(BMA.TEXT_GET, id)
      if type(base) ~= "string" then base = "" end
      pcall(funcLuaMenuCommand, BMA.SET_TEXT, BMA.BALLOON, BMA.TEXT_NODE, base .. "\n" .. prompt, 0)
    end,
  })
end
