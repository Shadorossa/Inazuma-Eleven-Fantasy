-- VRFW: the menus that open, for the current-mode service. Every menu VM reports its
-- script stem once its OnInit ran (CMND_VRFW_MODE_CURRENT_MENU); the service enters / leaves the contexts whose
-- `enter_menus` / `leave_menus` (game_modes.toml, any mod's) name that menu, e.g. the Battle Bay context `battle_bay`.
-- Nothing here names a menu or a context: the rules are data. Hooked on OnInit twice (the global wrapped here, and the
-- VRFW_Host dispatcher for a stem patch that redefines OnInit later); a second report of the same open changes
-- nothing. No engine call at load time.
do
  local MENU = 3259281399         -- crc32("CMND_VRFW_MODE_CURRENT_MENU")

  local script = type(EVT_PATCH) == "table" and EVT_PATCH.script or nil
  local stem = type(script) == "string" and (script:gsub("_%d+%.%d+%.%d+[%.%d]*$", "")) or nil

  local function report()
    if stem ~= nil then pcall(funcLuaCommand, MENU, stem) end
  end

  if stem ~= nil then
    local init = OnInit
    if type(init) == "function" then
      OnInit = function(...)
        local r = table.pack(init(...))
        report()
        return table.unpack(r, 1, r.n)
      end
    end
    local VH = VRFW_Host
    if type(VH) == "table" and type(VH.on) == "function" then
      pcall(VH.on, stem, "OnInit", {id = "vr_framework.mode_menus", phase = "after", fn = function(r, ...)
        report()
      end})
    end
  end
end
