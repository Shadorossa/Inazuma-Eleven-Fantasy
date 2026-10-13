-- VR-Framework › Chronicle completion, script side (docs/framework/chronicle-complete.md). The game Lua side is
-- assets\lua\menu\_all\37_chronicle.lua (VRFW_Chronicle); this script answers what game Lua cannot read itself:
--
--   CMND_VRFW_CHRONICLE_PIECES() -> { { pieceId, statusFlagIndex, eventType }, ... }: every board piece of the
--       Chronicle routes as the game loads them (chronicle_vs_route_config, the mods' route nodes included: the team
--       type serves the table): the pieces inside a route's `pieceInfo` slice (m_chronicleVsRouteInfoList) whose
--       eventType is 0 (a match) or 5 (a gate battle), each piece once, statusFlagIndex > 0. The hidden legend pieces
--       (outside every slice) and the story / warp / start pieces are not in it. Nothing is named here: the list is the
--       data's.
--
-- Read once per start (the table does not change while the game runs).

Chronicle = Chronicle or {}

local function u32(v)
  v = tonumber(v) or 0
  if v ~= v then return 0 end
  return math.floor(v) % 4294967296
end

local PIECES = nil

local function slice(v)
  if type(v) ~= "table" then return nil end
  local s, n = tonumber(v.start or v[1]), tonumber(v.count or v[2])
  if s == nil or n == nil then return nil end
  return s, n
end

-- `quiet` (the script-load read): an unreadable table only leaves the read to the first ask, no warning
local function load(quiet)
  if PIECES ~= nil then return PIECES end
  local okR, routes = pcall(VRFW.table.rows, "vsroute/vs_route")
  local okP, pieces = pcall(VRFW.table.rows, "vsroute/vs_route_piece")
  if not okR or not okP or type(routes) ~= "table" or type(pieces) ~= "table" then
    if quiet then return nil end
    VRFW.warn("chronicle: the board's tables are not readable (" .. tostring(okR and pieces or routes) .. "): no piece listed")
    return nil
  end
  local out, seen, nroute = {}, {}, 0
  for _, r in ipairs(routes) do
    local s, n = slice(r.pieceInfo or r[3])
    if s ~= nil then
      nroute = nroute + 1
      for i = s, s + n - 1 do
        local p = pieces[i + 1]
        if type(p) == "table" then
          local ev = tonumber(p.eventType or p[3]) or -1
          local sfi = tonumber(p.statusFlagIndex or p[4]) or 0
          local id = u32(p.pieceId or p[2])
          if (ev == 0 or ev == 5) and sfi > 0 and id ~= 0 and not seen[id] then
            seen[id] = true
            out[#out + 1] = { id, sfi, ev }
          end
        end
      end
    end
  end
  PIECES = out
  VRFW.log(string.format("chronicle: %d board piece(s) (match / gate) in %d route(s)", #out, nroute))
  return PIECES
end

function Chronicle.Pieces()
  return load() or {}
end

-- read at script load (the boot thread) instead of the first menu that asks (2026-10-13: «Chronicle.Pieces took
-- 96.7 ms» when the move picker of «Crear miximax» opened, then 134.2 ms: the save engine's slot_load only runs on a
-- slot switch, never for the boot's own load): the same tables, once per start; still unreadable: the save load, else
-- the first ask
pcall(load, true)
VRFW.on("slot_load", function() pcall(load, true) end)
