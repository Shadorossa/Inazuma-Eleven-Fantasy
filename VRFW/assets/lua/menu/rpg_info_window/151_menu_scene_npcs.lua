-- menu_scene (VR-Framework, docs/framework/menu-scene.md §2.1): the people of a menu scene are NPCs of its map; the
-- field makes them through its NPC update, which the retail scripts run as NPCUpdate (prog_common: request the update
-- of the NPC objects, wait while they update, then the load step). A menu scene starts its field from a menu and hands
-- it to the title a moment later, so nothing runs it: the people of a first entry never showed. While the game param
-- vrfw_menu_scene_npcs is set (setting_top_menu's 150_menu_scene.lua, when people were served) this field HUD menu
-- runs that update once, from its PostStep, and reports «asked» / «ready» to the framework (CMND_VRFW_MENU_SCENE_NPCS),
-- which hands the field over then (at most the scene's people_seconds). Retail NPCUpdate waits with waitFalse on both
-- steps: while the objects update, then while the load step is busy (3451717529 true = still loading). Wraps the
-- menu's own PostStep (no host); nothing runs at load time.
do
  local KEY = 1730437307 --[[crc32 vrfw_menu_scene_npcs]]
  local NPC = 3492492454 --[[crc32 NPC: the object kind of the field's NPCs]]
  local UPDATE = 183670132 --[[(kind) request the update of a kind of field object]]
  local UPDATING = 4179060571 --[[(kind) -> the objects of that kind are updating]]
  local LOAD = 2983896291 --[[the field's load step after an NPC update (NPCUpdate)]]
  local LOADING = 3451717529 --[[-> true while that load step is busy]]
  local REPORT = 4117226845 --[[CMND_VRFW_MENU_SCENE_NPCS (step, info)]]
  local STATE = 2588710643 --[[CMND_VRFW_MENU_SCENE_STATE () -> …, 6th: 1 = the scene's map is up]]
  local co = nil
  local function call(...)
    local r = table.pack(pcall(funcLuaCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end
  local function run()
    call(UPDATE, NPC)
    call(REPORT, "asked", "NPC update requested")
    local f = 0
    while call(UPDATING, NPC) == true and f < 600 do
      f = f + 1
      coroutine.yield()
    end
    local g = 0
    call(LOAD)
    while call(LOADING) == true and g < 600 do
      g = g + 1
      coroutine.yield()
    end
    call(REPORT, "ready", string.format("%d frame(s) updating, %d frame(s) loading%s", f, g, (f >= 600 or g >= 600) and ", gave up" or ""))
  end
  local post = PostStep
  if type(post) == "function" then
    function PostStep(...)
      local r = table.pack(post(...))
      if co == nil then
        local ok, set = pcall(funcLuaCommand, 2947612279, KEY)
        if ok and set == true then
          -- only on the scene's own map, once the framework saw it up (this menu also lives before the jump)
          local r = table.pack(pcall(funcLuaCommand, STATE))
          if r[1] and r[7] == 1 then
            pcall(funcLuaCommand, 3363400568, KEY)
            co = coroutine.create(run)
          end
        end
      end
      if co ~= nil and coroutine.status(co) ~= "dead" then
        local ok, err = coroutine.resume(co)
        if not ok then
          pcall(funcLuaCommand, 3661580131, "menu_scene", "rpg_info_window", "NPC update error", tostring(err))
          call(REPORT, "ready", "error " .. tostring(err))
        end
      end
      return table.unpack(r, 1, r.n)
    end
  end
end
