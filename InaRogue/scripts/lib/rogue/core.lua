-- InaRogue › INAROGUE: the shared state of the rogue scripts (one VM: scripts\rogue.lua requires every part).
-- Holds the settings and the caches of the active slot's files, and drops them after a slot event that may have
-- archived / copied / reset a slot (what the DLL's forget_slot did).

local U = require "lib/rogue/util"
local cfg = require "lib/rogue/cfg"

local Core = {}

Core.ENABLED = U.module_on()

-- the [rogue] settings (read once)
function Core.cfg() return cfg.get() end

-- forget hooks of the parts (fn(slot) for one slot, fn(nil) for all)
local forgets = {}
function Core.on_forget(fn) forgets[#forgets + 1] = fn end

-- every part drops its caches (a return to the title)
function Core.forget_all()
  for _, f in ipairs(forgets) do f(nil) end
end

-- run listeners (fn(run) with the run loaded / saved, fn(nil) when there is none): the parts that follow the run
local run_listeners = {}
function Core.on_run(fn) run_listeners[#run_listeners + 1] = fn end

function Core.run_changed(r)
  for _, f in ipairs(run_listeners) do
    local ok, e = pcall(f, r)
    if not ok then VRFW.warn("rogue: run listener: " .. tostring(e)) end
  end
end

-- every command calls this first: slot events since the last call drop the caches of the slots they touched
function Core.sync()
  local hit, all = U.slot_events()
  if not hit and not all then return end
  if all then
    for _, f in ipairs(forgets) do f(nil) end
    return
  end
  for s in pairs(hit) do
    for _, f in ipairs(forgets) do f(s) end
  end
end

return Core
