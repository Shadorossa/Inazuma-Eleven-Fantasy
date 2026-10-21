-- The framework's debug switches for game Lua (docs/framework/debug-flags.md): CMND_VRFW_DEBUG_SWITCH(name) answers
-- config.toml [debug] <name> (true / false). The merged config already holds the values the debug flags force.

DebugSwitch = DebugSwitch or {}

local logged = {}

function DebugSwitch.Get(name)
  if type(name) ~= "string" or not name:find("^[%w_]+$") then
    return false
  end
  local on = VRFW.files.config("debug." .. name) == true
  if on and not logged[name] then
    logged[name] = true
    VRFW.log("debug: [debug] " .. name .. " is on")
  end
  return on
end
