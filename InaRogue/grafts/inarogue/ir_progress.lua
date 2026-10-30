-- ---- story completed + Chronicle unlocked in the INAROGUE save (docs/game/save/story-chronicle-flags.md, inarogue.md §25) --
-- Slot 4 always behaves like a save with the story COMPLETED and the whole Chronicle UNLOCKED, whatever slot 1 holds,
-- so story / Chronicle-gated characters, items and data conditions never lock or break in the roguelite. Only
-- variables are written (retail setters; no players, items, trophies, scenes, help pages or «nuevo» notices): bit /
-- byte flags, story matches won, the Chronicle clear / lock bytes, and the story phase 9/80 (loader, slot 4 only).
-- Runs on every INAROGUE open in slot 4 and only writes what is not set yet (reads first: idempotent, cheap once set).
-- Replaces the old read-only copy of slot 1's progress (§13.11): slot 1 is no longer read at all.
local PG = {
  PHASE = @crc:CMND_EVT_S1P_PHASE@,     -- (chapter, sub): raise slot 4's current / next / checked-free phase
  SET_BIT = @crc:CMND_SET_GLOBAL_BIT_FLAG@, GET_BIT = @crc:CMND_GET_GLOBAL_BIT_FLAG@, SET_BYTE = @crc:CMND_SET_GLOBAL_BYTE_FLAG@, GET_BYTE = @crc:CMND_GET_GLOBAL_BYTE_FLAG@,
  SET_GAME_CLEAR = @crc:CMND_SET_SOCCER_GAME_CLEAR_BIT_FLAG@,           -- CMND_SET_SOCCER_GAME_CLEAR_BIT_FLAG (game, difficulty, true)
  GET_GAME_CLEAR = @crc:CMND_GET_SOCCER_GAME_CLEAR_FLAG@,           -- CMND_GET_SOCCER_GAME_CLEAR_FLAG (game, difficulty)
  SET_CLEAR = @crc:CMND_SET_CHRONICLE_CLEAR_STATUS@, GET_CLEAR = @crc:CMND_GET_CHRONICLE_CLEAR_STATUS@,   -- CMND_{SET,GET}_CHRONICLE_CLEAR_STATUS (sfi[, bool], diff)
  SET_LOCK = @crc:CMND_SET_CHRONICLE_LOCK_STATUS@, GET_LOCK = @crc:CMND_GET_CHRONICLE_LOCK_STATUS@,     -- CMND_{SET,GET}_CHRONICLE_LOCK_STATUS (sfi[, bool], diff)
  DIFFS = {1, 2, 3, 4, 10, 11},         -- bits 1..6 of a Chronicle status byte
}

-- The data: the finished story is the framework's (VRFW_Story: the story-complete start's flags, byte flags, story
-- matches and phase); INAROGUE's own rules (the extra story flags, the Chronicle, the help pages) are
-- content\rogue\progress_unlock.toml, served by CMND_INAROGUE_RL_PROGRESS_DATA. Either may answer nothing while its
-- script is busy: asked again for a few frames (this runs in the entry coroutine).
local PROGRESS_DATA = @crc:CMND_INAROGUE_RL_PROGRESS_DATA@   -- () -> STORY_EXTRA, CHRON_BITS, CHRON_BYTES, CHRON, HELP
local PROGRESS_TRIES = 30
local progress_data = nil

local function ProgressData()
  for _ = 1, PROGRESS_TRIES do
    if progress_data == nil then
      local d = Call(PROGRESS_DATA)
      if type(d) == "table" then
        progress_data = d
      end
    end
    local story = VRFW_Story ~= nil and VRFW_Story.Data() or nil
    if story ~= nil and progress_data ~= nil then
      return story, progress_data
    end
    coroutine.yield()
  end
  Log("progress unlock: no data (story", VRFW_Story ~= nil and VRFW_Story.Data() ~= nil, "own", progress_data ~= nil, ")")
  return nil
end

-- §24: no retail tutorial / first-time help page in the INAROGUE save. Every menu help of the game is a row of
-- help_list_config (HELP_LIST_INFO, 269 ids = crc32("hlp_NNNN")); the retail menus open it the first time only when
-- 745587751(id) («seen?») is false, then mark it with 1732256399(id) (kizuna_town_avatar_menu, help_menu). On every
-- INAROGUE open in slot 4 every id not seen yet is marked seen, so no «Comandos de hipertécnicas 1/2» & co. ever
-- opens there (new saves and existing ones). -> how many were marked
function IRM_MarkHelpsSeen()
  local _, own = ProgressData()
  if own == nil then
    return 0
  end
  local HELP_IDS = own.HELP
  local n = 0
  for i, id in ipairs(HELP_IDS) do
    if Call(745587751, id) == false then
      Call(1732256399, id)
      n = n + 1
    end
    if i % 60 == 0 then
      coroutine.yield()
    end
  end
  if n > 0 then
    Log("retail help pages marked seen", n, "of", #HELP_IDS)
  end
  return n
end

function IRM_UnlockProgress()
  local S, D = ProgressData()
  if S == nil then
    return 0
  end
  local on, off = VRFW_Story.CompleteFlags()
  local n = {story = 0, chron = 0, status = 0}
  local function bits(list, key)
    for i, h in ipairs(list) do
      if Call(PG.GET_BIT, h) ~= true then
        Call(PG.SET_BIT, h, true)
        n[key] = n[key] + 1
      end
      if i % 200 == 0 then
        coroutine.yield()
      end
    end
  end
  local function bytes(list, key)
    for _, b in ipairs(list) do
      if Int(Call(PG.GET_BYTE, b[1])) < b[2] then
        Call(PG.SET_BYTE, b[1], b[2])
        n[key] = n[key] + 1
      end
    end
  end
  -- the story: flags then INAROGUE's extra ones (b0:1 story clear last), the ending's own flag off, byte flags, story
  -- matches won
  local last = on[#on]
  local story = {}
  for i = 1, #on - 1 do
    story[i] = on[i]
  end
  for _, h in ipairs(D.STORY_EXTRA) do
    story[#story + 1] = h
  end
  bits(story, "story")
  for _, h in ipairs(off) do
    if Call(PG.GET_BIT, h) == true then
      Call(PG.SET_BIT, h, false)
      n.story = n.story + 1
    end
  end
  bytes(S.BYTES, "story")
  for _, g in ipairs(S.GAMES) do
    if Call(PG.GET_GAME_CLEAR, g, 1) ~= true then
      Call(PG.SET_GAME_CLEAR, g, 1, true)
      n.story = n.story + 1
    end
  end
  -- the Chronicle: flags, byte flags, every piece cleared at all its difficulties and nothing locked
  bits(D.CHRON_BITS, "chron")
  bytes(D.CHRON_BYTES, "chron")
  coroutine.yield()
  for k = 1, #D.CHRON, 2 do
    local sfi, m = D.CHRON[k], D.CHRON[k + 1]
    for bit = 1, 6 do
      local diff = PG.DIFFS[bit]
      if math.floor(m / 2 ^ bit) % 2 == 1 and Call(PG.GET_CLEAR, sfi, diff) ~= true then
        Call(PG.SET_CLEAR, sfi, true, diff)
        n.status = n.status + 1
      end
      if sfi > 0 and Call(PG.GET_LOCK, sfi, diff) == true then
        Call(PG.SET_LOCK, sfi, false, diff)
        n.status = n.status + 1
      end
    end
    if k % 100 == 99 then
      coroutine.yield()
    end
  end
  -- the story phase 9/80 (loader, slot 4 only, never lowered), then the story-clear flag
  local old, new = Call(PG.PHASE, S.PHASE[1], S.PHASE[2])
  if Call(PG.GET_BIT, last) ~= true then
    Call(PG.SET_BIT, last, true)
    n.story = n.story + 1
  end
  local raised = Int(new) > Int(old)
  local total = n.story + n.chron + n.status + (raised and 1 or 0)
  Log("story complete / Chronicle unlocked (data v" .. tostring(S.VERSION) .. "): written story", n.story, "chronicle flags",
      n.chron, "chronicle status bits", n.status, "phase", Int(old), "->", Int(new), total == 0 and "(all already set)" or "")
  return total
end
