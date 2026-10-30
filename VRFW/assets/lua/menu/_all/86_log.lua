-- VRFW_Log: the one logger of the menu scripts (lines go to the loader's log through CMND_EVT_LOG). A screen makes
-- one logger with its tag instead of its own Log function. Definitions only: no engine call at load.
--   local log = VRFW_Log.New(tag)   -- tag: "<mod>.<feature>" or the screen's short name
--   log(...)                        -- one line: the tag, then every argument (as CMND_EVT_LOG joins them)
--   log.once(key, ...)              -> true when written: the line only the first time `key` is used in this VM
--                                      (an error inside Step logs once, not every frame)
--   log.changed(key, value, ...)    -> true when written: the line only when `value` differs from the last value
--                                      given with `key` in this VM (the first call writes)
--   log.tag                         the tag
-- Every write is in pcall: a logger never stops its caller.
if VRFW_Log == nil then
  local LOG = VRFW_Cmd.EVT_LOG
  local NONE = {}                    -- the «no value yet» mark of log.changed

  local L = {}

  function L.New(tag)
    tag = tostring(tag or "log")
    local once_seen = {}
    local last_value = {}
    local logger = { tag = tag }

    local function write(...)
      local f = _ENV.funcLuaCommand
      if type(f) == "function" then
        pcall(f, LOG, tag, ...)
      end
    end

    function logger.once(key, ...)
      if once_seen[key] then
        return false
      end
      once_seen[key] = true
      write(...)
      return true
    end

    function logger.changed(key, value, ...)
      local stored = last_value[key]   -- nil = the key was never given
      local now = value
      if now == nil then
        now = NONE
      end
      if stored ~= nil and stored == now then
        return false
      end
      last_value[key] = now
      write(...)
      return true
    end

    return setmetatable(logger, { __call = function(_, ...) write(...) end })
  end

  VRFW_Log = L
end
