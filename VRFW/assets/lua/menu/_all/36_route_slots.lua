-- menu_engine: EXTENDED route node slots (VR-Framework base feature; docs/framework/route-board.md §5, 2026-10-11).
-- Definitions only (this file runs in every script VM, lua\_all); no engine call happens while a chunk loads.
--
-- The Chronicle board keeps a piece's clear / lock state in three 300-byte save arrays (one byte per statusFlagIndex,
-- bit n = difficulty {1, 2, 3, 4, 10, 11}[n]); the retail pieces use 1-270, so a mod's [[VRFW.RouteNode]] had only the
-- free bytes 271-299. A node may now take an EXTENDED slot (300 and up, defaults\team.toml [route_nodes]
-- ext_slot_limit): its piece row holds the shared proxy byte (proxy_slot) and its real state lives here, in the save
-- service (owner "vr_framework", key "route_slot.<slot>" = "<clear mask>,<lock mask>", the retail bit order; absent =
-- nothing cleared, nothing locked: a fresh retail byte). The board scripts never see the proxy: in their VMs the board's
-- own reads go through VRFW_RouteSlots' funcLuaCommand wrapper:
--   * funcLuaCommand(126049514, pieceIndex, 6) (the piece's statusFlagIndex) of an extended node's piece answers its
--     extended slot (the team type's CMND_VRFW_TEAM_ROUTE_NODE_GET);
--   * CMND_GET / SET_CHRONICLE_CLEAR_STATUS and _LOCK_STATUS on a slot >= 300 read / write the save service.
-- So the retail board code, the framework's route_nodes / route_chains / route_board grafts and every mod's hooks work
-- on extended slots unchanged. The game's native code only ever sees the proxy byte (nobody else uses it).
--
--   VRFW_RouteSlots.Watch()     -- from a patch file of a board script's folder (lua\menu\<stem>\): the wrapper goes in
--                               -- at the script's OnInit (the engine's first callback), once per VM
--   VRFW_RouteSlots.Install()   -- the same, now (idempotent; only from a callback)
--   VRFW_RouteSlots.Get(kind, slot, difficulty) / Set(kind, slot, on, difficulty)   kind "clear" / "lock"
if VRFW_RouteSlots == nil then
  local M = {
    BASE = 300,               -- the game's status arrays (m_globalChronicle*StatusFlag): statusFlagIndex 0-299
    PIECE = 126049514,        -- piece info (pieceIndex, field): field 6 = statusFlagIndex
    CLEAR_GET = 4034518619,   -- CMND_GET_CHRONICLE_CLEAR_STATUS (slot, difficulty)
    CLEAR_SET = 1891570685,   -- CMND_SET_CHRONICLE_CLEAR_STATUS (slot, on, difficulty)
    LOCK_GET = 3394595467,    -- CMND_GET_CHRONICLE_LOCK_STATUS (slot, difficulty)
    LOCK_SET = 1778321182,    -- CMND_SET_CHRONICLE_LOCK_STATUS (slot, locked, difficulty)
    PIECE_IDX = 1064555639,   -- pieceId -> ok, piece index
    NODE_COUNT = {1208701503, 3004181703},   -- CMND_VRFW_TEAM_ROUTE_NODE_COUNT (legacy part name second)
    NODE_GET = {3986876567, 1705651873},     -- CMND_VRFW_TEAM_ROUTE_NODE_GET (i) -> pieceId, slot, ...
    SAVE_GET = 2187277743,    -- CMND_VRFW_SAVE_GET (owner, key, default)
    SAVE_SET = 2574269955,    -- CMND_VRFW_SAVE_SET (owner, key, value, commit)
    OWNER = "vr_framework",
    -- the retail bit of each difficulty (bit n = difficulty {1, 2, 3, 4, 10, 11}[n]): 2^(n-1)
    BIT = {[1] = 1, [2] = 2, [3] = 4, [4] = 8, [10] = 16, [11] = 32},
    byIdx = nil,              -- piece index -> extended slot (per VM, built on first use)
    installed = false,
  }
  VRFW_RouteSlots = M

  local function log(...)
    if PRINT ~= nil then
      pcall(PRINT, "VRFW_RS", ...)
    end
  end

  -- the team type's command, else the legacy part's (with the real funcLuaCommand)
  local function call(real, cmd, ...)
    for k = 1, 2 do
      local r = table.pack(pcall(real, cmd[k], ...))
      if r[1] and r[2] ~= nil then
        return table.unpack(r, 2, r.n)
      end
    end
    return nil
  end

  -- piece index -> extended slot of every route node with a slot >= BASE
  local function load(real)
    if M.byIdx ~= nil then
      return M.byIdx
    end
    M.byIdx = {}
    local n = call(real, M.NODE_COUNT)
    if type(n) ~= "number" then
      return M.byIdx
    end
    for i = 0, n - 1 do
      local piece, slot = call(real, M.NODE_GET, i)
      if type(piece) == "number" and type(slot) == "number" and slot >= M.BASE then
        local ok, okI, idx = pcall(real, M.PIECE_IDX, piece)
        if ok and okI and type(idx) == "number" then
          M.byIdx[idx] = slot
          log("extended slot", slot, "piece", piece, "idx", idx)
        end
      end
    end
    return M.byIdx
  end

  local function read(real, slot)
    local ok, s = pcall(real, M.SAVE_GET, M.OWNER, "route_slot." .. tostring(slot), "")
    local c, l = 0, 0
    if ok and type(s) == "string" then
      local a, b = string.match(s, "^(%d+),(%d+)$")
      c, l = tonumber(a) or 0, tonumber(b) or 0
    end
    return c, l
  end

  local function has(mask, bit)
    return math.floor(mask / bit) % 2 == 1
  end

  local function with(mask, bit, on)
    if has(mask, bit) == (on == true) then
      return mask
    end
    return on and mask + bit or mask - bit
  end

  -- an extended slot's bit: kind "clear" / "lock"
  local function get(real, kind, slot, d)
    local bit = M.BIT[d]
    if bit == nil then
      return false
    end
    local c, l = read(real, slot)
    return has(kind == "clear" and c or l, bit)
  end

  local function set(real, kind, slot, on, d)
    local bit = M.BIT[d]
    if bit == nil then
      return
    end
    local c, l = read(real, slot)
    if kind == "clear" then
      c = with(c, bit, on)
    else
      l = with(l, bit, on)
    end
    pcall(real, M.SAVE_SET, M.OWNER, "route_slot." .. tostring(slot), c .. "," .. l, 1)
  end

  function M.Get(kind, slot, d)
    return get(M.real or funcLuaCommand, kind, slot, d)
  end

  function M.Set(kind, slot, on, d)
    set(M.real or funcLuaCommand, kind, slot, on, d)
  end

  -- the VM's funcLuaCommand with the extended slots (once per VM; only from a callback)
  function M.Install()
    if M.installed then
      return false
    end
    local real = funcLuaCommand
    if type(real) ~= "function" then
      return false
    end
    M.real = real
    -- the argument count is passed on unchanged (a C command may check it)
    local function wrapped(...)
      local cmd, a, b, c = ...
      if cmd == M.PIECE and b == 6 and type(a) == "number" then
        local slot = load(real)[a]
        if slot ~= nil then
          return true, slot
        end
      elseif type(a) == "number" and a >= M.BASE then
        if cmd == M.CLEAR_GET then
          return get(real, "clear", a, b)
        elseif cmd == M.LOCK_GET then
          return get(real, "lock", a, b)
        elseif cmd == M.CLEAR_SET then
          set(real, "clear", a, b, c)
          return
        elseif cmd == M.LOCK_SET then
          set(real, "lock", a, b, c)
          return
        end
      end
      return real(...)
    end
    M.wrapper = wrapped
    funcLuaCommand = wrapped
    M.installed = true
    return true
  end

  -- watch the board script of this VM: the wrapper goes in at its OnInit (chaining)
  function M.Watch()
    local prev = OnInit
    OnInit = function(...)
      M.Install()
      if prev ~= nil then
        return prev(...)
      end
    end
    return true
  end
end
