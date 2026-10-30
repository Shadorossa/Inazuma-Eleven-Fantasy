-- Shared menu model view of the mod's character previews (research/grafts/_lib; docs/game/ui/menu-model-view.md).
-- Not a script of its own: `--@lib evt_model_view.lua#ModelView` puts the section in place (graft_lib.expand_lib).
--
-- ONE framing for every character model the mod shows in a menu: the retail «Ver apariencia» view of the team dock
-- (team_dock_formation_menu visual-check mode, UpdateViewChara3DModel on layer team02_01_attach_formation_frame).
-- Its camera and start place live in the model layer's object (camera 935586083: eye (0, 1.5, 10.5) -> target
-- (0, 1.5, 0), FOV 20; start 1.3 / 0.45 / 1.5, start rot Y -7.5; written by research/scripts/if_plate_row_build.py
-- from the retail objbin). The Lua part is what UpdateViewChara3DModel does after each build: the shared menu camera
-- offset back to (0, 0, 0), the model turned to Y -7.5, stand motion 立ち1L and the dock pose.
-- Callers differ only by their rules table:
--   hide_in_menus = {menu crc, ...}  no model at all while one of these menus exists (log once per change)
--   view_in_menus = {menu crc, ...}  these menus open the retail «Ver apariencia» view for the shown player on request
--                                    (cross-menu call view_func, default "EVT_FVD_Open"; MV.Offer / MV.OpenView)
--   view_key = param-store key       the offer also needs this key set (the host VM that can open the view sets it
--                                    while it runs: a menu object can run another script, e.g. soccer_formation_menu
--                                    runs team_dock_formation_menu's Lua in the team dock, its own in the match)
-- Nothing here names a character or a screen of the mod; the rules do.
--@section ModelView
local MV = {}
MV.CAM, MV.CAM_OFS, MV.CAM_GET = 1752770328, 284729675, 1877348924   -- shared menu model camera offset (set / get)
MV.ROT = 2463117189                    -- (layer, idx, rx, ry, rz): the retail view's turn after a build
MV.MOTION, MV.STAND = 180466856, 2263925137                          -- (layer, idx, motion, 0, 0...): 立ち1L
MV.POSE_UPD, MV.POSE_ARG = @crc:CMND_UPDATE_CHARA_MODEL_POSE@, 3459069566                     -- CMND_UPDATE_CHARA_MODEL_POSE (dock pose)
MV.EXIST_MENU = @crc:CMND_IS_EXIST_MENU@              -- (menu crc)
MV.RETAIL = {cam = {0, 0, 0}, rot_y = -7.5}

local function MVCmd(...)
  if type(funcLuaMenuCommand) ~= "function" then
    return nil
  end
  local r = table.pack(pcall(funcLuaMenuCommand, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

local function MVLc(...)
  if type(funcLuaCommand) ~= "function" then
    return nil
  end
  local r = table.pack(pcall(funcLuaCommand, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

-- the menu (crc) of rules.hide_in_menus that exists now, else nil
function MV.Hidden(rules)
  local t = type(rules) == "table" and rules.hide_in_menus or nil
  if type(t) ~= "table" then
    return nil
  end
  for _, menu in ipairs(t) do
    if MVLc(MV.EXIST_MENU, menu) == true then
      return menu
    end
  end
  return nil
end

-- the menu (crc) of rules.view_in_menus that exists now, else nil
function MV.Offer(rules)
  local t = type(rules) == "table" and rules.view_in_menus or nil
  if type(t) ~= "table" then
    return nil
  end
  local key = rules.view_key
  if key ~= nil and not VRFW_Param.Has(key) then
    return nil
  end
  for _, menu in ipairs(t) do
    if MVLc(MV.EXIST_MENU, menu) == true then
      return menu
    end
  end
  return nil
end

-- ask that menu to open the retail view (it runs its own visual check mode); returns what the cross call answers
MV.CROSS_CALL = 830228314              -- (menu crc, global function name, ...) in that menu's VM
function MV.OpenView(rules, menu)
  local fn = type(rules) == "table" and rules.view_func or "EVT_FVD_Open"
  return MVLc(MV.CROSS_CALL, menu, fn)
end

-- the shared menu camera offset as the retail view leaves it; returns what it was before (has, x, y, z)
function MV.Camera()
  local has, x, y, z = MVLc(MV.CAM_GET, MV.CAM)
  local c = MV.RETAIL.cam
  MVLc(MV.CAM_OFS, MV.CAM, c[1], c[2], c[3])
  return has, x, y, z
end

-- after a build (and again once it is loaded): camera offset, turn, stand motion and pose of the retail view
function MV.Frame(layer, idx)
  MV.Camera()
  MVCmd(MV.ROT, layer, idx or 0, 0, MV.RETAIL.rot_y, 0)
  MVCmd(MV.MOTION, layer, idx or 0, MV.STAND, 0, 0, 0, 0, 0)
  MVCmd(MV.POSE_UPD, layer, idx or 0, MV.POSE_ARG)
end
