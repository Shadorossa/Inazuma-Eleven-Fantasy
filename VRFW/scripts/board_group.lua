-- Board groups, script side (board side: graft route_nodes, VRFW_RN_SetHide; docs/framework/route-board.md §9).
-- Declarations: every active mod's content\board_groups\*.toml (`VRFW.board_group/1`, keys content\types\
-- board_group.toml): [[VRFW.BoardGroup]] = Chronicle board nodes a hide switch hides at once (visual only), or that
-- stay hidden while the group's `hidden` conditions hold (a mod option, the declaring mod's config).
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_BOARD_GROUPS | — | { pieceId, … } of every hideable group's nodes |
-- | CMND_VRFW_BOARD_HIDE | — / ("set", 0 \| 1) | the hide switch (kept for the game session) |
-- | CMND_VRFW_BOARD_HIDDEN | — | { pieceId, … } of the groups whose `hidden` conditions hold now (asked when a board opens) |

BoardGroup = BoardGroup or {}

local D = require "lib/declarations"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("board_group")

local crc = VRFW.crc32

local PIECES = nil       -- { pieceId, … }
local RULED = {}         -- { { mod, conds, pieces = { pieceId, … } }, … }: groups with `hidden` conditions
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
    if v.hidden ~= nil then
      local pieces = {}
      for _, node in ipairs(v.nodes or {}) do pieces[#pieces + 1] = crc("evt_rn_piece_" .. node) end
      RULED[#RULED + 1] = { mod = d.mod, conds = v.hidden, pieces = pieces }
    end
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

-- the pieces of the groups whose `hidden` conditions hold now
function BoardGroup.Hidden()
  load_groups()
  local out = {}
  for _, g in ipairs(RULED) do
    if D.holds(g.mod, g.conds) then
      for _, p in ipairs(g.pieces) do out[#out + 1] = p end
    end
  end
  return out
end

function BoardGroup.Hide(op, value)
  if op == "set" then
    HIDDEN = (tonumber(value) or 0) ~= 0
  end
  return HIDDEN
end

pcall(load_groups)
