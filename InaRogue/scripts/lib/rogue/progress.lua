-- InaRogue › what an INAROGUE save gets on top of the finished story (content\rogue\progress_unlock.toml): the extra
-- story flags, the Chronicle flags / byte flags / clear status and the retail help pages marked seen. The finished
-- story itself is the framework's (VRFW_Story). Served to evt_inarogue_menu by CMND_INAROGUE_RL_PROGRESS_DATA:
--   () -> { STORY_EXTRA = {flag, ...}, CHRON_BITS = {flag, ...}, CHRON_BYTES = {{flag, value}, ...},
--           CHRON = {index, mask, index, mask, ...}, HELP = {help id, ...} }, nil when the file is not readable

local U = require "lib/rogue/util"
local _, warn = U.logger("rogue")

local P = {}

local DATA = nil

local function list(t)
  local out = {}
  for i, v in ipairs(type(t) == "table" and t or {}) do
    out[i] = v % U.TWO32
  end
  return out
end

function P.Data()
  if DATA then return DATA end
  local ok, t = pcall(VRFW.files.toml, "content/rogue/progress_unlock.toml")
  if not ok or type(t) ~= "table" then
    warn("content/rogue/progress_unlock.toml not readable (" .. tostring(t) .. "): no progress unlock")
    return nil
  end
  local d = { STORY_EXTRA = list(t.story_extra_flags), CHRON_BITS = list(t.chronicle_flags), CHRON_BYTES = {}, CHRON = {},
              HELP = list(t.help_pages) }
  for _, b in ipairs(type(t.chronicle_byte_flags) == "table" and t.chronicle_byte_flags or {}) do
    d.CHRON_BYTES[#d.CHRON_BYTES + 1] = { b.flag % U.TWO32, b.value }
  end
  for _, s in ipairs(type(t.chronicle_status) == "table" and t.chronicle_status or {}) do
    d.CHRON[#d.CHRON + 1] = s[1]
    d.CHRON[#d.CHRON + 1] = s[2]
  end
  DATA = d
  return DATA
end

return P
