-- VRFW pose rows, game Lua side (every menu VM; script side scripts\pose_row.lua; docs/framework/pose-row.md). Opens the
-- pose row screen vrfw_pose_row_menu on a mod's [[VRFW.PoseRow]] and waits for it, inside the caller's coroutine (as
-- the retail WaitExecOtherMenu): the caller's menu chrome (VRFW_HubYield's layers + `opts.hide`) is hidden while it is up.
--   VRFW_PoseRow.Open(key[, context[, opts]]) -> picked entry (1..n), 0 = closed with Back, -1 = the declaration's
--                                                  Y action (`team`), nil = not opened
--     key      "<mod>.<name>" of the declaration
--     context  a whole number handed to the mod's source command (e.g. its zone)
--     opts     { hide = { layer crc… } } more layers of the caller hidden while the screen is up (each visible
--              instance, shown again when it closes; a hidden one stays hidden),
--              models = { {layer crc, slot}, … } the caller's own 3D models (instance 0 of the layer), hidden
--              meanwhile and given back after (R.CallerModels): a caller menu that has the retail SetCharaEnable (the
--              Chronicle board: its caravan) does it itself, which also puts its own model camera back (the board
--              places the caravan every frame through the current camera: after the screen's camera it came back
--              huge); any other caller: the models' handles (retail SetCharaModelVisible). Nothing is moved.
--   VRFW_PoseRow.HideLayers(layers) -> hidden    the visible instances of those layers hidden (a staging helper)
--   VRFW_PoseRow.ShowLayers(hidden)              them shown again
--   VRFW_PoseRow.CallerModels(models, on[, kept]) the `models` above hidden (-> what to give back) / given back
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
    MODEL_HANDLE = 3895705890,   -- (layer, instance, slot) -> the menu model's handle (0: none)
    MODEL_VISIBLE = 1890282463,  -- (handle, on)
    LAYER_VISIBLE = 711242136,   -- CMND_SET_LAYER_VISIBLE (layer, instance, on)
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

  -- the visible instances of `layers` hidden -> the list of what was hidden (R.ShowLayers puts it back); a hidden
  -- instance stays hidden.
  function R.HideLayers(layers)
    local hidden = {}
    for _, l in ipairs(layers or {}) do
      local okn, n = pcall(funcLuaMenuCommand, R.LAYER_NUM, l)
      for i = 0, (okn and type(n) == "number" and n or 0) - 1 do
        local okv, v = pcall(funcLuaMenuCommand, R.IS_VISIBLE, l, i)
        if okv and v == true then
          pcall(funcLuaMenuCommand, R.LAYER_VISIBLE, l, i, false)
          hidden[#hidden + 1] = {l, i}
        end
      end
    end
    return hidden
  end

  function R.ShowLayers(hidden)
    for _, h in ipairs(hidden or {}) do
      pcall(funcLuaMenuCommand, R.LAYER_VISIBLE, h[1], h[2], true)
    end
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
      if not on then
        R.Log("caller model", m[1], m[2] or 0, h and "hidden by its handle" or "has no model")
      end
    end
    return kept
  end

  -- the caller's models hidden (on = false) / given back (on = true, with what the hide returned). The caller menu's
  -- own retail SetCharaEnable when it has one (the Chronicle board: its caravan enabled / disabled and, on true, the
  -- board's model camera current again, so its every-frame placement is right at once); else the models' handles.
  function R.CallerModels(list, on, kept)
    if list == nil or #list == 0 then
      return nil
    end
    if type(SetCharaEnable) == "function" then
      local ok, err = pcall(SetCharaEnable, on)
      R.Log("caller models", on and "given back" or "hidden", "by the menu's SetCharaEnable", ok and "" or tostring(err))
      if ok then
        return "menu"
      end
    end
    if kept == "menu" then
      kept = nil
    end
    return R.ModelShow(list, on, kept)
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
    local hidden = R.HideLayers(opts.hide)
    local kept = R.CallerModels(opts.models, false)
    pcall(funcLuaCommand, R.OPEN_MENU, R.MENU)
    R.Log("open", key, "context", tostring(context), "requested")
    local t = 0
    while not up() and t < R.START_WAIT do
      t = t + 1
      coroutine.yield()
    end
    local opened = up()
    R.Log("open", key, opened and "up after" or "not up after", t, "frames")
    while up() do
      coroutine.yield()
    end
    R.ShowLayers(hidden)
    R.CallerModels(opts.models, true, kept)
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
