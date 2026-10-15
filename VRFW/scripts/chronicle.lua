-- Chronicle completion, script side (game Lua side: assets\lua\menu\_all\37_chronicle.lua).
-- CMND_VRFW_CHRONICLE_PIECES() -> { { pieceId, statusFlagIndex, eventType }, ... }: board pieces of the Chronicle routes with eventType 0 (match) or 5 (gate battle) and statusFlagIndex > 0, each once.

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

-- `quiet`: an unreadable table leaves the read to the first ask, without a warning
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

-- read at script load instead of the first ask; if still unreadable, retried on save load, then on the first ask
pcall(load, true)
VRFW.on("slot_load", function() pcall(load, true) end)
