-- menu_engine: CHRONICLE COMPLETION (VR-Framework base feature).
-- Definitions only (this file runs in every script VM, lua\_all); no engine call happens while a chunk loads.
--
-- «Every Chronicle completed» in the save in use, from the data only (nothing here names a piece, a chain or a mod):
--   1. every board piece of the Chronicle routes (the script command CMND_VRFW_CHRONICLE_PIECES: the pieces inside a
--      route slice of chronicle_vs_route_config with eventType 0 match / 5 gate, the mods' route nodes included) has
--      the clear bit of difficulty `d` (the caller's rule; the route-open battle / the gate battle is 2). A mod's
--      [[VRFW.RouteNode]] counts with ITS first declared difficulty on ITS save slot (an extended slot >= 300 is read
--      from the save service, VRFW_RouteSlots); a node that opens a chain board / a chain hub is left to rule 2;
--   2. every [[VRFW.Chain]] board of the active mods is complete (VRFW_Chain.Complete: every match tile won).
--
--   VRFW_Chronicle.Complete(d)  -> done (bool), cleared, total, first missing ("piece 0x… slot n" / "chain <key>")
--                                  (nil list from the script = not done: never true by accident)
--   VRFW_Chronicle.Reset()      -- forget the cached answer (a screen asks again at its OnInit)
if VRFW_Chronicle == nil then
  local M = {
    PIECES = VRFW_Cmd.VRFW_CHRONICLE_PIECES,       -- CMND_VRFW_CHRONICLE_PIECES () -> {{pieceId, statusFlagIndex, eventType}, ...}
    CLEAR_GET = VRFW_Cmd.GET_CHRONICLE_CLEAR_STATUS,    -- CMND_GET_CHRONICLE_CLEAR_STATUS (slot, difficulty)
    NODE = {COUNT = {VRFW_Cmd.VRFW_TEAM_ROUTE_NODE_COUNT, 3004181703}, GET = {VRFW_Cmd.VRFW_TEAM_ROUTE_NODE_GET, 1705651873}},   -- CMND_VRFW_TEAM_ROUTE_NODE_*
    CHAIN_COUNT = {VRFW_Cmd.VRFW_TEAM_CHAIN_COUNT, 3844893564},   -- CMND_VRFW_TEAM_CHAIN_COUNT
    OF_PIECE = {VRFW_Cmd.VRFW_TEAM_CHAIN_OF_PIECE, 2747770341},       -- CMND_VRFW_TEAM_CHAIN_OF_PIECE (pieceId) -> chain i, node slot
    LOG = VRFW_Cmd.EVT_LOG,          -- CMND_EVT_LOG
    list = nil,                -- {{piece, slot, difficulty or nil (= the caller's)}} (per VM)
    cache = {},                -- d -> {done, cleared, total, missing}
  }
  VRFW_Chronicle = M

  local function call(cmd, ...)
    for k = 1, 2 do
      local r = table.pack(pcall(funcLuaCommand, cmd[k], ...))
      if r[1] and r[2] ~= nil then
        return table.unpack(r, 2, r.n)
      end
    end
    return nil
  end

  local function u32(v) return VRFW_Id.u32(v) end

  function M.Log(...)
    pcall(funcLuaCommand, M.LOG, "chronicle", ...)
  end

  -- the pieces that count: the script's list with the route nodes' own slot / difficulty, the chain nodes left out
  local function pieces()
    if M.list ~= nil then
      return M.list
    end
    local ok, got = pcall(funcLuaCommand, M.PIECES)
    if not ok or type(got) ~= "table" or #got == 0 then
      M.Log("no board piece listed (the script command did not answer)")
      return nil                                   -- asked again next time
    end
    local nodes = {}
    local n = call(M.NODE.COUNT)
    for i = 0, (type(n) == "number" and n or 0) - 1 do
      local piece, slot, _, diffs, _, _, _, _, _, _, hub = call(M.NODE.GET, i)
      if type(piece) == "number" and piece ~= 0 then
        local chain = (type(hub) == "string" and hub ~= "") or ((call(M.OF_PIECE, piece) or -1) >= 0)
        local d = tonumber(string.match(type(diffs) == "string" and diffs or "", "^%s*(%d+)"))
        nodes[u32(piece)] = {slot = slot, d = d, chain = chain}
      end
    end
    local list = {}
    for _, p in ipairs(got) do
      local id, sfi = u32(p[1]), tonumber(p[2]) or 0
      local nd = nodes[id]
      if nd == nil then
        list[#list + 1] = {id, sfi, nil}
      elseif not nd.chain then
        list[#list + 1] = {id, tonumber(nd.slot) or sfi, nd.d}
      end
    end
    M.list = list
    M.Log("pieces", #list, "of", #got, "(route nodes", n or 0, ")")
    return list
  end

  local function cleared(slot, d)
    if slot >= 300 then
      return VRFW_RouteSlots ~= nil and VRFW_RouteSlots.Get("clear", slot, d) == true
    end
    local ok, v = pcall(funcLuaCommand, M.CLEAR_GET, slot, d)
    return ok and v == true
  end

  function M.Reset()
    M.cache = {}
  end

  function M.Complete(d)
    d = tonumber(d) or 2
    local c = M.cache[d]
    if c ~= nil then
      return c[1], c[2], c[3], c[4]
    end
    local list = pieces()
    if list == nil then
      return false, 0, 0, "no piece list"
    end
    local have, total, missing = 0, 0, nil
    for _, p in ipairs(list) do
      total = total + 1
      if cleared(p[2], p[3] or d) then
        have = have + 1
      elseif missing == nil then
        missing = string.format("piece 0x%08X slot %d difficulty %d", p[1], p[2], p[3] or d)
      end
    end
    local nc = call(M.CHAIN_COUNT)
    for i = 0, (type(nc) == "number" and nc or 0) - 1 do
      local b = VRFW_Chain ~= nil and VRFW_Chain.Board(i) or nil
      if b ~= nil then
        total = total + 1
        if VRFW_Chain.Complete(b) then
          have = have + 1
        elseif missing == nil then
          missing = "chain " .. b.key
        end
      end
    end
    local done = total > 0 and have == total
    M.cache[d] = {done, have, total, missing}
    M.Log("complete", tostring(done), have, "/", total, "difficulty", d, "first missing", missing or "-")
    return done, have, total, missing
  end
end
