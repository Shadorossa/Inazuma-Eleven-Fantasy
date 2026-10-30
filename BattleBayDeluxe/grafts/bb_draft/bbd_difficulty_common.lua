-- BattleBayDeluxe bb_draft, the AI difficulty another mod owns (enjoy_team_select_menu_campaign / _offline).
-- A mod that sets the CPU's AI itself publishes the game's difficulty index as a game_state key (config.toml
-- [difficulty] owner_states); CMND_BBD_DIFFICULTY_OWNED answers it (-1 = none). While a mod owns it, the menu's
-- GetSelectDifficultyIdx (what the game's match start and the Torneo's start read) answers that index, the Campaña /
-- Torneo grid opens no difficulty window (bbd_difficulty_campaign.lua) and the 1 vs 1's match settings hide their
-- difficulty row (bbd_difficulty_free.lua). Asked in OnInit and again at a decide while the scripts did not answer.
-- Globals only; nothing runs at chunk load.
BBD_DIFFICULTY = {
  OWNED = @crc:CMND_BBD_DIFFICULTY_OWNED@,
  START = @crc:CMND_BBD_DIFFICULTY_START@,
  GRID = 106197494 --[[vs01_43_enjoy_team_select_emblem_icon]],
  OPTIONS = 429081730 --[[the 1 vs 1's match settings list: row 0 difficulty, 1 stadium, 2 BGM, 3 commentator]],
  index = nil, -- the owned difficulty index; false = none (the player picks it); nil = not answered yet
}

-- the logger (VRFW_Log), made at the first line: the framework's menu files load after the graft blocks
function BBD_DifficultyLog(...)
  BBD_DIFFICULTY.logger = BBD_DIFFICULTY.logger or VRFW_Log.New("BattleBayDeluxe.difficulty")
  BBD_DIFFICULTY.logger(...)
end

-- the owned difficulty index, nil = the player picks it (or the scripts did not answer yet)
function BBD_DifficultyOwned()
  local D = BBD_DIFFICULTY
  if D.index == nil then
    local ok, v = pcall(funcLuaCommand, D.OWNED)
    if ok and type(v) == "number" then
      if v >= 0 then
        D.index = v
        BBD_DifficultyLog("owned by a mod: index " .. tostring(v) .. ", no difficulty asked")
      else
        D.index = false
      end
    end
  end
  if D.index == false then
    return nil
  end
  return D.index
end

do
  local init = OnInit
  function OnInit(...)
    local r = table.pack(init(...))
    pcall(BBD_DifficultyOwned)
    return table.unpack(r, 1, r.n)
  end

  local getter = GetSelectDifficultyIdx
  function GetSelectDifficultyIdx(...)
    local ok, owned = pcall(BBD_DifficultyOwned)
    if ok and owned ~= nil then
      return owned
    end
    return getter(...)
  end
end
