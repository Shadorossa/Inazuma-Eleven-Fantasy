-- VRFW_Story: the story-complete start's data (content\story_start\*.toml of the active mods), read through
-- CMND_VRFW_STORY_START_DATA (scripts\story_start.lua). One list of the story flags for every caller (the slot's
-- story-complete start, a mode that starts with the story finished). Definitions only: no engine call at load; call
-- these from OnInit / Step.
--   VRFW_Story.Data()          -> the data table (scripts\story_start.lua lists its keys), nil when the command gives
--                                 nothing (no declaration, or the script was busy: ask again later). Cached per VM once
--                                 it answered.
--   VRFW_Story.CompleteFlags() -> on, off: the global bit flags a finished story sets (the story-clear flag 750283301
--                                 LAST) and the ones it clears; nil when Data() is nil. Fresh lists each call.
if VRFW_Story == nil then
  local DATA_COMMAND = VRFW_Cmd.VRFW_STORY_START_DATA
  local cached = nil

  local S = {}

  function S.Data()
    if cached ~= nil then
      return cached
    end
    local f = _ENV.funcLuaCommand
    if type(f) ~= "function" then
      return nil
    end
    local ok, d = pcall(f, DATA_COMMAND)
    if ok and type(d) == "table" and type(d.BITS) == "table" and #d.BITS > 0 then
      cached = d
    end
    return cached
  end

  function S.CompleteFlags()
    local d = S.Data()
    if d == nil then
      return nil
    end
    local on, off = {}, {}
    for i, v in ipairs(d.BITS) do
      on[i] = v
    end
    for i, v in ipairs(d.BITS_OFF or {}) do
      off[i] = v
    end
    return on, off
  end

  VRFW_Story = S
end
