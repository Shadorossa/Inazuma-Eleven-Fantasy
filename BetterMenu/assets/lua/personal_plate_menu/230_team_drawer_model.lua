-- BetterMenu (mod better_menu, prefix BetterMenu): the player page's 3D model (personal_plate_menu, layer evt_pp_model)
-- while the main menu's team drawer shows the roster over the clubhouse (docs/game/mods/better-menu.md §44, §58, §61).
-- The model stands on its menu stage, framed by the menu camera's own pose (the formation screen's camera config).
-- Over the room that camera takes the scene's shot (CMND_VRFW_MENU_SCENE_FOLLOW_CAMERA), so the stage is out of view.
-- While param better_menu_team_over_scene is set, every Step moves the model to where the shot shows it at the same
-- screen place and size (CMND_VRFW_MENU_SCENE_REFRAME), pulled toward the room's eye to NEAR of that depth (in front
-- of the room's walls) and scaled by NEAR on its model object (the layer's own scale command only acts while the model
-- builds), and turns it by the same angle. The place and scale the page gives the model are read back whenever they
-- are not ours: a rebuild, a refit or the page's own height fit starts from them again. Over the room the model is drawn
-- in the 3D view, under the drawer's band (docs/game/mods/better-menu.md §76). Opened any other way nothing changes. No
-- engine call at load time.
do
  local Reframe = {
    ID = "better_menu.team_drawer_model",
    OVER_SCENE = 3752859857,      -- crc32("better_menu_team_over_scene")
    PARAM_HAS = 2947612279,
    MODEL_LAYER = 598577375,      -- crc32("evt_pp_model"): the player page's model layer
    MENU_CAMERA = "MenuCamera",   -- the camera the page's model is drawn with
    REFRAME = 3673848177,         -- crc32("CMND_VRFW_MENU_SCENE_REFRAME")
    GET_POS = 3136332215,         -- CMND_GET_CHARA_MODEL_POS (layer, index, slot) -> ok, x, y, z
    SET_POS = 1088067423,         -- CMND_SET_CHARA_MODEL_POS (layer, index, x, y, z, slot)
    SET_TURN = 2463117189,        -- (layer, index, x, y, z degrees)
    PAGE_TURN = -7.5,             -- the page's own turn of the model (the retail model view, menu-model-view.md §1)
    GET_MODEL = 3895705890,       -- (layer, index, slot) -> the model object's handle (menu command)
    GET_SCALE = 2211946652,       -- CMND_GET_SCALE_OBJECT (handle) -> sx, sy, sz
    SET_SCALE = 2982269573,       -- (handle, sx, sy, sz): the model object's scale
    -- the model pulled toward the room's eye to this part of its depth, and scaled by it (the same place and size on
    -- screen): at the full depth (about 2.75 m) it stood inside the fireplace / the corner post of the home shot and the
    -- room's geometry hid it (owner 2026-10-18: an empty right panel)
    NEAR = 0.45,
    MODEL_METRES = 1.7,           -- a player's height at scale 1, for the logged box only
    SAME_PLACE_METRES = 0.001,
    SAME_SCALE = 0.0005,
    LOG = 3661580131,             -- crc32("CMND_EVT_LOG")
  }
  local base, placed, logged = nil, nil, {}
  local scale_base, scale_ours, scale_handle = nil, nil, nil

  local function F(...)
    local r = table.pack(pcall(funcLuaCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end
  local function M(...)
    local r = table.pack(pcall(funcLuaMenuCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end
  local function LogOnce(step, ...)
    if logged[step] then return end
    logged[step] = true
    F(Reframe.LOG, "better_menu", "team_drawer", "page model:", step, ...)
  end
  local function Near(a, b)
    return b ~= nil and math.abs(a[1] - b[1]) < Reframe.SAME_PLACE_METRES and math.abs(a[2] - b[2]) < Reframe.SAME_PLACE_METRES
      and math.abs(a[3] - b[3]) < Reframe.SAME_PLACE_METRES
  end
  local function SameScale(a, b)
    return b ~= nil and math.abs(a[1] - b[1]) < Reframe.SAME_SCALE and math.abs(a[2] - b[2]) < Reframe.SAME_SCALE
      and math.abs(a[3] - b[3]) < Reframe.SAME_SCALE
  end

  -- the model object's scale times NEAR, from the scale the page gave it (its base x its height fit)
  local function ScaleModel()
    local handle = M(Reframe.GET_MODEL, Reframe.MODEL_LAYER, 0, 0)
    if type(handle) ~= "number" or handle == 0 then return nil end
    local sx, sy, sz = F(Reframe.GET_SCALE, handle)
    if type(sx) ~= "number" or sx <= 0 then return nil end
    sy = type(sy) == "number" and sy > 0 and sy or sx
    sz = type(sz) == "number" and sz > 0 and sz or sx
    local now = { sx, sy, sz }
    if handle ~= scale_handle or not SameScale(now, scale_ours) then
      scale_handle, scale_base = handle, now
      logged.scaled = nil
    end
    local want = { scale_base[1] * Reframe.NEAR, scale_base[2] * Reframe.NEAR, scale_base[3] * Reframe.NEAR }
    if not SameScale(now, want) then F(Reframe.SET_SCALE, handle, want[1], want[2], want[3]) end
    scale_ours = want
    LogOnce("scaled", string.format("model 0x%08X scale %.3f -> %.3f (x %.2f)", handle, scale_base[2], want[2], Reframe.NEAR))
    return want[2]
  end

  local function Tick()
    if F(Reframe.PARAM_HAS, Reframe.OVER_SCENE) ~= true then
      base, placed, scale_base, scale_ours, scale_handle = nil, nil, nil, nil, nil
      return
    end
    local ok, x, y, z = M(Reframe.GET_POS, Reframe.MODEL_LAYER, 0, 0)
    if not ok or type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
      return
    end
    local now = { x, y, z }
    if not Near(now, placed) then
      base = now
      logged.moved = nil
    end
    local px, py, pz, turn, sx, sy, metres, distance = F(Reframe.REFRAME, Reframe.MENU_CAMERA, base[1], base[2], base[3], Reframe.NEAR)
    if type(px) ~= "number" then
      LogOnce("waiting", "no own pose of the menu camera yet: the model stays on its stage")
      return
    end
    M(Reframe.SET_POS, Reframe.MODEL_LAYER, 0, px, py, pz, 0)
    M(Reframe.SET_TURN, Reframe.MODEL_LAYER, 0, 0, Reframe.PAGE_TURN + turn, 0)
    local scale = ScaleModel()
    placed = { px, py, pz }
    local height = type(metres) == "number" and metres > 0 and Reframe.MODEL_METRES * (scale and scale / Reframe.NEAR or 1) / metres * 1080 or 0
    LogOnce("moved", string.format("stage (%.2f, %.2f, %.2f) -> room (%.2f, %.2f, %.2f), %.2f m from the eye, turn %.1f; feet on screen (%.0f, %.0f), "
      .. "a %.1f m player about %.0f px tall (box y %.0f .. %.0f)", base[1], base[2], base[3], px, py, pz, tonumber(distance) or 0, turn,
      tonumber(sx) or 0, tonumber(sy) or 0, Reframe.MODEL_METRES, height, (tonumber(sy) or 0) - height, tonumber(sy) or 0))
  end

  if VRFW_Host ~= nil then
    VRFW_Host.on("personal_plate_menu", "Step", {
      id = Reframe.ID .. ".step", phase = "after", create = true,
      fn = function()
        local ok, why = pcall(Tick)
        if not ok then LogOnce("error", tostring(why)) end
      end,
    })
  end
end
