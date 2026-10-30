-- VRFW pose rows, game Lua side (every menu VM; script side scripts\pose_row.lua; docs/framework/pose-row.md). Opens the
-- pose row screen vrfw_pose_row_menu on a mod's [[VRFW.PoseRow]] and waits for it, inside the caller's coroutine (as
-- the retail WaitExecOtherMenu): the caller's menu chrome (VRFW_HubYield's layers + `opts.hide`) is hidden while it is up.
--   VRFW_PoseRow.Open(key[, context[, opts]]) -> picked entry (1..n), 0 = closed with Back, -1 = the declaration's
--                                                  Y action (`team`), nil = not opened; second value: the entry
--                                                  focused when the screen closed
--     key      "<mod>.<name>" of the declaration
--     context  a whole number handed to the mod's source command (e.g. its zone)
--     opts     focus = n  the entry focused when the screen opens (default: the source's header `focus`, else 1),
--              hide = { layer crc… } more layers of the caller hidden while the screen is up (each visible
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
    KEY_FOCUS = 2167843046,      -- crc32("vrfw_pose_row_focus"): parameter in / out, the focused entry
    OPEN_MENU = VRFW_Cmd.OPEN_MENU_OBJECT,       -- CMND_OPEN_MENU_OBJECT
    IS_MENU = VRFW_Cmd.IS_EXIST_MENU_OBJECT,        -- CMND_IS_EXIST_MENU_OBJECT (funcLuaMenuCommand)
    VISIBLE_ALL = 2171393651,    -- (layer, on): every instance of a layer
    START_WAIT = 60,             -- frames the screen may take to appear
    LAYER_NUM = VRFW_Cmd.GET_CREATE_LAYER_NUM,      -- (layer) -> instance count
    IS_VISIBLE = VRFW_Cmd.IS_LAYER_VISIBLE,     -- (layer, instance) -> visible
    MODEL_HANDLE = 3895705890,   -- (layer, instance, slot) -> the menu model's handle (0: none)
    MODEL_VISIBLE = 1890282463,  -- (handle, on)
    LAYER_VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE,   -- CMND_SET_LAYER_VISIBLE (layer, instance, on)
  }
  VRFW_PoseRow = R

  function R.Log(...)
    if PRINT ~= nil then pcall(PRINT, "VRFW_POSE_ROW", ...) end
  end

  local function param(key, value)
    VRFW_Param.Clear(key)
    VRFW_Param.Set(key, value)
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

  -- a whole-number parameter out of the screen, read once (0 when absent). The store hands values back as unsigned
  -- 32-bit numbers: the screen's -1 (Y) comes back as 4294967295 and is turned back into -1 here.
  function R.Take(k)
    local v = VRFW_Param.Take(k)
    if v == nil then
      return 0
    end
    v = math.floor(tonumber(v) or 0)
    if v >= 2147483648 then
      v = v - 4294967296
    end
    return v
  end

  function R.Open(key, context, opts)
    opts = opts or {}
    if type(key) ~= "string" or coroutine.running() == nil then
      R.Log("open", tostring(key), "not in a coroutine or no key")
      return nil
    end
    param(R.KEY_ROW, CRC32(key))
    param(R.KEY_CTX, math.floor(tonumber(context) or 0))
    VRFW_Param.Clear(R.KEY_PICK)
    VRFW_Param.Clear(R.KEY_FOCUS)
    if (tonumber(opts.focus) or 0) > 0 then
      param(R.KEY_FOCUS, math.floor(opts.focus))
    end
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
    local pick, focus = R.Take(R.KEY_PICK), R.Take(R.KEY_FOCUS)
    R.Log("open", key, "context", tostring(context), opened and "shown" or "never shown", "pick", pick, "focus", focus)
    if not opened then return nil end
    return pick, focus > 0 and focus or nil
  end
end
