-- Utilities › «Cámara del partido» (feature camera). The side camera is the preset utilities.side of the mod's
-- cameras\side.toml on the VR-Framework's match camera service (docs/framework/camera.md), requested by the Lua of
-- graft research/grafts/camera_side while the option row utilities.camera (storage = "mod_options") says «Lateral».
--
-- This script only takes over the old setting once: before 2026-10-08 the row's value lived in Utilities' global blob
-- camera.json ({ "side_view": true/false, … }). When mod_options\utilities.json has no `camera` value yet, the old
-- side_view becomes it (1 = Lateral, 0 = Original); the old blob is left where it is.

local OPTION = "camera"
local BLOB = "camera.json"

local function take_over()
  if VRFW.options.values()[OPTION] ~= nil then
    return
  end
  local bytes = VRFW.save.blob(BLOB, "global")
  if bytes == nil then
    return
  end
  local s = VRFW.json.decode(bytes)
  local side = type(s) == "table" and s.side_view == true
  local ok, why = VRFW.options.store({ [OPTION] = side and 1 or 0 })
  if ok then
    VRFW.log("«Cámara del partido» = " .. (side and 1 or 0) .. " taken over from Utilities' camera.json blob (kept there too)")
  else
    VRFW.warn("cannot take over the old camera setting (" .. tostring(why) .. "): «Cámara del partido» starts at Original")
  end
end

local ok, err = pcall(take_over)
if not ok then
  VRFW.warn("camera setting take-over: " .. tostring(err))
end
