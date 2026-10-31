-- Skill board locks: every active mod's content/skill_board_lock/*.toml (`VRFW.skill_board_lock/1`). A
-- [[VRFW.SkillBoardLock]] names a game_state key; while it is 1 no player's moves, auras or mix can be changed on the
-- skill board screens (content/game/skill_board_lock.toml):
--   CMND_VRFW_SKILL_BOARD_LOCK   () -> locked, text id (crc32 of the lock's text row), dock only
-- The menus ask it once per screen open (lua\menu\_all\92_skill_board_lock.lua).

SkillBoardLock = SkillBoardLock or {}

local D = require "lib/declarations"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("skill_board_lock")

local LOCKS = {}               -- { key, state, text_id, dock_only }

local function load()
  local schema, why = D.schema("skill_board_lock")
  if not schema then
    warn(tostring(why))
    return
  end
  for _, d in ipairs(D.load(schema, warn)) do
    if d.entry == "SkillBoardLock" and type(d.v.state) == "string" and d.v.state ~= "" then
      local text = type(d.v.text) == "string" and d.v.text ~= "" and d.v.text or "vrfw_skill_board_locked"
      LOCKS[#LOCKS + 1] = { key = d.key, state = d.v.state, text_id = VRFW.crc32(text), dock_only = d.v.dock_only == true }
    end
  end
  if #LOCKS > 0 then
    local names = {}
    for _, l in ipairs(LOCKS) do names[#names + 1] = l.key .. " (" .. l.state .. ")" end
    info("locks: " .. table.concat(names, ", "))
  end
end

-- the first declared lock whose state key is 1 now: locked, its text id, dock only
function SkillBoardLock.Cmd()
  for _, l in ipairs(LOCKS) do
    local ok, v = pcall(VRFW.state.get, l.state)
    if ok and tonumber(v) == 1 then
      return true, l.text_id, l.dock_only
    end
  end
  return false, 0, false
end

do
  local ok, e = pcall(load)
  if not ok then warn("declarations: " .. tostring(e)) end
end
