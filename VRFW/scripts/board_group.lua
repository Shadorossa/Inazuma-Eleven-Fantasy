-- Board groups, script side (board side: graft route_nodes, VRFW_RN_SetHide; docs/framework/route-board.md §9).
-- Declarations: every active mod's content\board_groups\*.toml (`VRFW.board_group/1`, keys content\types\
-- board_group.toml): [[VRFW.BoardGroup]] = Chronicle board nodes a hide switch hides at once (visual only).
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_BOARD_GROUPS | — | { pieceId, … } of every hideable group's nodes |
-- | CMND_VRFW_BOARD_HIDE | — / ("set", 0 \| 1) | the hide switch (kept for the game session) |

BoardGroup = BoardGroup or {}

local D = require "lib/declarations"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("board_group")

local crc = VRFW.crc32

local PIECES = nil       -- { pieceId, … }
local HIDDEN = false     -- the switch: this game session only

local function load_groups()
  if PIECES ~= nil then return PIECES end
  PIECES = {}
  local schema, why = D.schema("board_group")
  if not schema then
    warn(why .. ": no board group")
    return PIECES
  end
  local seen = {}
  for _, d in ipairs(D.load(schema, warn)) do
    local v = d.v
    local n = 0
    if v.hideable then
      for _, node in ipairs(v.nodes or {}) do
        local piece = crc("evt_rn_piece_" .. node)
        if not seen[piece] then
          seen[piece] = true
          PIECES[#PIECES + 1] = piece
          n = n + 1
        end
      end
    end
    info(string.format("%s: %d node(s)%s", d.key, n, v.hideable and ", hideable" or ""))
  end
  return PIECES
end

function BoardGroup.Pieces()
  return load_groups()
end

function BoardGroup.Hide(op, value)
  if op == "set" then
    HIDDEN = (tonumber(value) or 0) ~= 0
  end
  return HIDDEN
end

pcall(load_groups)
