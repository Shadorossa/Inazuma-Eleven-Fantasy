-- menu_engine: UNLIMITED COPIES (VR-Framework base feature; docs/framework/unlimited-copies.md).
-- Definitions only (this file runs in every script VM, lua\_all); no engine call happens while a chunk loads.
--
-- Mods declare which items have unlimited copies and when ([[VRFW.UnlimitedCopies]], content\unlimited_copies\*.toml;
-- script side scripts\unlimited_copies.lua). While one of an item's rules holds in the save in use, one owned copy serves
-- every player: a picker lets the item through even when every copy is equipped, and an equip keeps the owned count.
-- Never in a reserved save slot. A rule holds when its ownership holds (one of its key items owned, or one of its
-- Chronicle pieces cleared; neither declared = always) and, when it asks, every Chronicle is completed (VRFW_Chronicle).
--
--   VRFW_Copies.Unlimited(item)           -> true while a rule of the item holds (cached until Reset)
--   VRFW_Copies.Owned(keyItem)            -> true while the ownership of a rule naming that key item holds (slot and
--                                            Chronicle completion not asked: a notice «you got the key item»)
--   VRFW_Copies.SlotOk()                  -> true in a normal save slot
--   VRFW_Copies.Reset()                   -- forget the cached answers (a screen asks again at its OnInit)
--   VRFW_Copies.HideCounters(layer, inst) -- a move list row's two copy counters (equipped / owned) hidden, with
--                                            their stock boxes (the frames and icons a focused row shows)
--   VRFW_Copies.ListRow(layer, inst, item)-> true (counters hidden) when the item is unlimited; otherwise the row's
--                                            counters are shown (list instances are reused)
--   VRFW_Copies.Snapshot(items)           -> {item = owned count} of the unlimited items owned at least once
--   VRFW_Copies.Restore(before, handleOf) -- after an equip: every item whose owned count grew is brought back
--                                            (handleOf(item) = its handle on the player's board, or nil)
if VRFW_Copies == nil then
  local M = {
    RULES = 2374283232,        -- CMND_VRFW_UNLIMITED_COPIES_RULES ([item]) -> { flat rule, … }
    SLOT = 1763633601,         -- CMND_VRFW_UNLIMITED_COPIES_SLOT () -> 1 / -1 / -2
    CAP = 868327209,           -- CMND_VRFW_UNLIMITED_COPIES_CAP (invHdl, item, num, target) -> status, before, after
    ITEM_NUM = 2011560392,     -- CMND_GET_ITEM_NUM (item) = the stock
    CLEAR_GET = 4034518619,    -- CMND_GET_CHRONICLE_CLEAR_STATUS (statusFlagIndex, difficulty)
    ADD = 1897915498,          -- CMND_ADD_ITEM_ONLY (item, count, window) -> the stack's handle
    DEL = 425598937,           -- CMND_DELETE_ITEM (item, count)
    LOG = 3661580131,          -- CMND_EVT_LOG
    rules = {},                -- item -> its rules (static per VM)
    all = nil,                 -- every declared rule (static per VM)
    state = {},                -- item -> unlimited now (until Reset)
    slot = nil,                -- slot answer (until Reset)
  }
  VRFW_Copies = M

  local function u32(v)
    v = tonumber(v) or 0
    return math.floor(v) % 4294967296
  end

  function M.Log(...)
    pcall(funcLuaCommand, M.LOG, "unlimited_copies", ...)
  end

  -- a flat rule { chroniclesDifficulty, nKeys, key…, nClears, statusFlagIndex, difficulty, … } -> a table
  local function parse(flat)
    if type(flat) ~= "table" then
      return nil
    end
    local r = {chronicles = tonumber(flat[1]) or 0, keys = {}, clears = {}}
    local i, nk = 3, tonumber(flat[2]) or 0
    for _ = 1, nk do
      r.keys[#r.keys + 1] = u32(flat[i])
      i = i + 1
    end
    local nc = tonumber(flat[i]) or 0
    i = i + 1
    for _ = 1, nc do
      r.clears[#r.clears + 1] = {tonumber(flat[i]) or 0, tonumber(flat[i + 1]) or 2}
      i = i + 2
    end
    return r
  end

  local function parse_list(got)
    local out = {}
    if type(got) == "table" then
      for _, flat in ipairs(got) do
        local r = parse(flat)
        if r ~= nil then
          out[#out + 1] = r
        end
      end
    end
    return out
  end

  local function rules_of(item)
    local r = M.rules[item]
    if r == nil then
      local ok, got = pcall(funcLuaCommand, M.RULES, item)
      if not ok or type(got) ~= "table" then
        return {}                                  -- no answer: asked again next time
      end
      r = parse_list(got)
      M.rules[item] = r
    end
    return r
  end

  local function owned(r)
    if #r.keys == 0 and #r.clears == 0 then
      return true
    end
    for _, k in ipairs(r.keys) do
      local ok, n = pcall(funcLuaCommand, M.ITEM_NUM, k)
      if ok and (tonumber(n) or 0) > 0 then
        return true
      end
    end
    for _, c in ipairs(r.clears) do
      local ok, v = pcall(funcLuaCommand, M.CLEAR_GET, c[1], c[2])
      if ok and v == true then
        return true
      end
    end
    return false
  end

  local function holds(r)
    if not owned(r) then
      return false
    end
    if r.chronicles > 0 then
      if VRFW_Chronicle == nil then
        return false                               -- no completion service: never by accident
      end
      local ok, done = pcall(VRFW_Chronicle.Complete, r.chronicles)
      return ok and done == true
    end
    return true
  end

  function M.Reset()
    M.state, M.slot, M.hidden = {}, nil, nil
    if VRFW_Chronicle ~= nil then
      pcall(VRFW_Chronicle.Reset)
    end
  end

  function M.SlotOk()
    if M.slot == nil then
      local ok, st = pcall(funcLuaCommand, M.SLOT)
      if not ok or type(st) ~= "number" then
        return false                               -- no answer: asked again next time
      end
      M.slot = st
    end
    return M.slot == 1
  end

  function M.Unlimited(item)
    item = u32(item)
    if item == 0 then
      return false
    end
    local s = M.state[item]
    if s ~= nil then
      return s
    end
    s = false
    local list = (M.AnyRule() and M.SlotOk()) and rules_of(item) or {}
    if #list > 0 then
      for _, r in ipairs(list) do
        if holds(r) then
          s = true
          break
        end
      end
    end
    M.state[item] = s
    return s
  end

  -- some active mod declares a rule (no answer = no, asked again next time)
  function M.AnyRule()
    if M.all == nil then
      local ok, got = pcall(funcLuaCommand, M.RULES)
      if not ok or type(got) ~= "table" then
        return false
      end
      M.all = parse_list(got)
    end
    return #M.all > 0
  end

  function M.Owned(key)
    key = u32(key)
    if not M.AnyRule() then
      return false
    end
    for _, r in ipairs(M.all) do
      for _, k in ipairs(r.keys) do
        if k == key and owned(r) then
          return true
        end
      end
    end
    return false
  end

  -- the stock box meshes of a list row (equipped: frame, label, icon; owned: frame, icon, label), as the retail
  -- SetVisibleEquipmentNum / SetVisibleStockNum of equip_menu_inc toggle them
  M.STOCK_MESHES = {1202991162 --[[_base_equip01]], 1139638886 --[[_gtxt_equip01]], 1087832946,
    1228576956 --[[_base_have01]], 2037408502 --[[_icon_have01]], 132349475}

  function M.HideCounters(layer, inst)
    funcLuaMenuCommand(2158717427, layer, 442049775 --[[_pos_equip01]], false, inst)
    funcLuaMenuCommand(2158717427, layer, 3426045766 --[[_pos_have01]], false, inst)
    for _, m in ipairs(M.STOCK_MESHES) do
      pcall(funcLuaMenuCommand, 3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, m, false, inst)
    end
    funcLuaMenuCommand(1233047821 --[[number visible]], layer, inst, 3974820126 --[[num_equip01]], false)
    funcLuaMenuCommand(1233047821 --[[number visible]], layer, inst, 3334923667 --[[num_have01]], false)
  end

  function M.ShowCounters(layer, inst)
    funcLuaMenuCommand(2158717427, layer, 442049775 --[[_pos_equip01]], true, inst)
    funcLuaMenuCommand(2158717427, layer, 3426045766 --[[_pos_have01]], true, inst)
    funcLuaMenuCommand(1233047821 --[[number visible]], layer, inst, 3974820126 --[[num_equip01]], true)
    funcLuaMenuCommand(1233047821 --[[number visible]], layer, inst, 3334923667 --[[num_have01]], true)
  end

  function M.ListRow(layer, inst, item)
    if not M.Unlimited(item) then
      if M.hidden ~= nil and M.hidden[layer .. ":" .. inst] then
        M.hidden[layer .. ":" .. inst] = nil
        M.ShowCounters(layer, inst)               -- a reused instance that held an unlimited row
      end
      return false
    end
    M.hidden = M.hidden or {}
    M.hidden[layer .. ":" .. inst] = true
    M.HideCounters(layer, inst)
    return true
  end

  local function num(item)
    local ok, n = pcall(funcLuaCommand, M.ITEM_NUM, item)
    return ok and (tonumber(n) or 0) or 0
  end

  function M.Snapshot(items)
    local t = {}
    for _, id in ipairs(items) do
      id = u32(id)
      if id ~= 0 and t[id] == nil and M.Unlimited(id) then
        local c = num(id)
        if c >= 1 then
          t[id] = c                                -- only owned items: an item is never created or emptied
        end
      end
    end
    return t
  end

  function M.Restore(before, handleOf)
    for id, s0 in pairs(before) do
      local now = num(id)
      if now > s0 then
        local h, extra = handleOf ~= nil and handleOf(id) or nil, false
        if h == nil or h == 0 then                 -- not on this board: the stack's handle the retail way
          h = funcLuaCommand(M.ADD, id, 1, false) or 0
          extra = true
          now = num(id)
        end
        local okC, st, e0, e1 = pcall(funcLuaCommand, M.CAP, h, id, now, s0)
        if okC and st == 1 then
          funcLuaCommand(M.DEL, id, now - s0)
        elseif extra then
          funcLuaCommand(M.DEL, id, 1)             -- at least undo the own copy
        end
        local after = num(id)
        M.Log("equip keeps the owned count", string.format("%08X", id), "owned", s0, "after equip", now,
          "equipped", tostring(e0), "->", tostring(e1), "status", tostring(st), "now", after,
          after == s0 and "OK" or "NOT RESTORED")
      end
    end
  end
end
