-- Board node menus, script side (game Lua side: assets\lua\menu\_all\75_node_menu.lua; docs/framework/node-menu.md).
-- Declarations: every active mod's content\node_menus\*.toml (`VRFW.node_menu/1`, keys content\types\node_menu.toml):
-- [[VRFW.NodeMenu]] = the Chronicle board nodes ([[VRFW.RouteNode]] Names) whose piece calls a mod's game Lua handler
-- instead of opening the command menu.
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_NODE_MENU_OF_PIECE | pieceId | handler name, node name, menu key; nothing = the piece opens no mod menu |

NodeMenu = NodeMenu or {}

local D = require "lib/declarations"

local function info(...) VRFW.log("node_menu:", ...) end
local function warn(...) VRFW.warn("node_menu:", ...) end

local BY_PIECE = nil     -- pieceId -> { handler, node, key }

local function crc(s)
  local f = VRFW.crc32 or (VRFW.ui and VRFW.ui.crc32)
  return f(s) % 4294967296
end

local function load_menus()
  if BY_PIECE ~= nil then return BY_PIECE end
  BY_PIECE = {}
  local schema, why = D.schema("node_menu")
  if not schema then
    warn(why .. ": no node menu")
    return BY_PIECE
  end
  for _, d in ipairs(D.load(schema, warn)) do
    local v = d.v
    local where = string.format("mods/%s/%s", tostring(d.mod), tostring(d.file))
    if not tostring(v.handler):match("^[%a_][%w_]*$") and not tostring(v.handler):match("^[%a_][%w_]*%.[%a_][%w_]*$") then
      warn(where .. ": " .. d.key .. ": handler `" .. tostring(v.handler) .. "` is not a Lua name (`Name` or `Table.Name`): left out")
    else
      local n = 0
      for _, node in ipairs(v.nodes or {}) do
        local piece = crc("evt_rn_piece_" .. node)
        local old = BY_PIECE[piece]
        if old ~= nil and old.key ~= d.key then
          warn(string.format("%s: node %s is %s's already: %s wins", where, node, old.key, d.key))
        end
        BY_PIECE[piece] = { handler = v.handler, node = node, key = d.key }
        n = n + 1
      end
      info(string.format("%s: %d node(s), handler %s", d.key, n, v.handler))
    end
  end
  return BY_PIECE
end

-- CMND_VRFW_NODE_MENU_OF_PIECE(pieceId) -> handler, node, key
function NodeMenu.OfPiece(piece)
  local m = load_menus()[math.floor(tonumber(piece) or 0) % 4294967296]
  if m == nil then return nil end
  return m.handler, m.node, m.key
end

pcall(load_menus)
