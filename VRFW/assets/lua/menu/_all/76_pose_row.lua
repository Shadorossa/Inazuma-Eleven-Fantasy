-- VRFW pose rows, game Lua side (every menu VM; script side scripts\pose_row.lua; docs/framework/pose-row.md). Opens the
-- pose row screen vrfw_pose_row_menu on a mod's [[VRFW.PoseRow]] and waits for it, inside the caller's coroutine (as
-- the retail WaitExecOtherMenu): the caller's menu chrome (VRFW_HubYield's layers + `opts.hide`) is hidden while it is up.
--   VRFW_PoseRow.Open(key[, context[, opts]]) -> picked entry (1..n), 0 = closed with Back, -1 = the declaration's
--                                                  Y action (`team`), nil = not opened
--     key      "<mod>.<name>" of the declaration
--     context  a whole number handed to the mod's source command (e.g. its zone)
--     opts     { hide = { layer crc… } } more layers of the caller hidden while the screen is up (each visible
--              instance, shown again when it closes; a hidden one stays hidden),
--              models = { {layer crc, slot}, … } the caller's own 3D models (instance 0 of the layer): hidden
--              meanwhile through their model handle (the layer itself stays visible: it may hold the caller's
--              backgrounds), and put back where they were when the screen closes (the caller's step may place them
--              through the screen's model camera while it is up: the Chronicle board's caravan, drawn huge)
-- No engine call at load time.
if VRFW_PoseRow == nil then
  local R = {
    MENU = 3907790619,           -- crc32("vrfw_pose_row_menu")
    KEY_ROW = 970894462,         -- crc32("vrfw_pose_row"): parameter in, crc32 of the key
    KEY_CTX = 734132499,         -- crc32("vrfw_pose_row_context"): parameter in, the context
    KEY_PICK = 203690515,        -- crc32("vrfw_pose_row_pick"): parameter out, the picked entry
    P_SET = 3860611758, P_CLEAR = 3363400568, P_EXISTS = 2947612279, P_GET = 3522198769,
    OPEN_MENU = 433545986,       -- CMND_OPEN_MENU_OBJECT
    IS_MENU = 2231168902,        -- CMND_IS_EXIST_MENU_OBJECT (funcLuaMenuCommand)
    VISIBLE_ALL = 2171393651,    -- (layer, on): every instance of a layer
    START_WAIT = 60,             -- frames the screen may take to appear
    LAYER_NUM = 1175615627,      -- (layer) -> instance count
    IS_VISIBLE = 1262717583,     -- (layer, instance) -> visible
    MODEL_POS = 3136332215,      -- CMND_GET_CHARA_MODEL_POS (layer, instance, slot) -> found, x, y, z
    MODEL_SET_POS = 1088067423,  -- CMND_SET_CHARA_MODEL_POS (layer, instance, x, y, z, slot)
    MODEL_HANDLE = 3895705890,   -- (layer, instance, slot) -> the menu model's handle (0: none)
    MODEL_VISIBLE = 1890282463,  -- (handle, on)
  }
  VRFW_PoseRow = R

  function R.Log(...)
    if PRINT ~= nil then pcall(PRINT, "VRFW_POSE_ROW", ...) end
  end

  local function param(key, value)
    pcall(funcLuaCommand, R.P_CLEAR, key)
    pcall(funcLuaCommand, R.P_SET, key, 0, value, 1)
  end

  local function up()
    local ok, r = pcall(funcLuaMenuCommand, R.IS_MENU, R.MENU)
    return ok and r == true
  end

  -- the caller's models: hidden (on = false: each one's handle kept), shown again (on = true)
  function R.ModelShow(list, on, kept)
    kept = kept or {}
    for k, m in ipairs(list or {}) do
      local h = kept[k]
      if not on then
        local ok, v = pcall(funcLuaMenuCommand, R.MODEL_HANDLE, m[1], 0, m[2] or 0)
        h = ok and type(v) == "number" and v ~= 0 and v or nil
        kept[k] = h or false
      end
      if h then
        pcall(funcLuaCommand, R.MODEL_VISIBLE, h, on)
      end
    end
    return kept
  end

  -- the caller's models' place: kept before the screen; after it, a place that moved is put back (one log line)
  function R.ModelPlace(list, when)
    R.places = R.places or {}
    for k, m in ipairs(list or {}) do
      local r = table.pack(pcall(funcLuaMenuCommand, R.MODEL_POS, m[1], 0, m[2] or 0))
      local x, y, z = r[3], r[4], r[5]
      if when == "before" then
        R.places[k] = (r[1] and r[2] == true and type(x) == "number") and {x, y, z} or false
      elseif R.places[k] and type(x) == "number" and (math.abs(x - R.places[k][1]) > 0.001
          or math.abs(y - R.places[k][2]) > 0.001 or math.abs(z - R.places[k][3]) > 0.001) then
        local p = R.places[k]
        pcall(funcLuaMenuCommand, R.MODEL_SET_POS, m[1], 0, p[1], p[2], p[3], m[2] or 0)
        R.Log("caller model", m[1], m[2] or 0, "moved to", x, y, z, "put back to", p[1], p[2], p[3])
      end
    end
  end

  function R.Open(key, context, opts)
    opts = opts or {}
    if type(key) ~= "string" or coroutine.running() == nil then
      R.Log("open", tostring(key), "not in a coroutine or no key")
      return nil
    end
    param(R.KEY_ROW, CRC32(key))
    param(R.KEY_CTX, math.floor(tonumber(context) or 0))
    pcall(funcLuaCommand, R.P_CLEAR, R.KEY_PICK)
    local yielded = VRFW_HubYield ~= nil and pcall(VRFW_HubYield, true, R.MENU)
    local hidden = {}
    for _, l in ipairs(opts.hide or {}) do
      local okn, n = pcall(funcLuaMenuCommand, R.LAYER_NUM, l)
      for i = 0, (okn and type(n) == "number" and n or 0) - 1 do
        local okv, v = pcall(funcLuaMenuCommand, R.IS_VISIBLE, l, i)
        if okv and v == true then
          pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], l, i, false)
          hidden[#hidden + 1] = {l, i}
        end
      end
    end
    R.ModelPlace(opts.models, "before")
    local kept = R.ModelShow(opts.models, false)
    pcall(funcLuaCommand, R.OPEN_MENU, R.MENU)
    local t = 0
    while not up() and t < R.START_WAIT do
      t = t + 1
      coroutine.yield()
    end
    local opened = up()
    while up() do
      coroutine.yield()
    end
    for _, h in ipairs(hidden) do
      pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], h[1], h[2], true)
    end
    R.ModelPlace(opts.models, "after")
    R.ModelShow(opts.models, true, kept)
    if yielded then pcall(VRFW_HubYield, false, R.MENU) end
    local pick = 0
    local okx, exists = pcall(funcLuaCommand, R.P_EXISTS, R.KEY_PICK)
    if okx and exists == true then
      local ok, v = pcall(funcLuaCommand, R.P_GET, R.KEY_PICK)
      pick = ok and math.floor(tonumber(v) or 0) or 0
      pcall(funcLuaCommand, R.P_CLEAR, R.KEY_PICK)
    end
    R.Log("open", key, "context", tostring(context), opened and "shown" or "never shown", "pick", pick)
    if not opened then return nil end
    return pick
  end
end
