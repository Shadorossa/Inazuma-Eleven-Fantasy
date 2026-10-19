-- BetterMenu: the avatar as a hotspot of the «Modo Historia» shot (docs/game/mods/better-menu.md §104). The avatar sits
-- on the left wing's bench as a scene actor (spot 1). The hotspot «avatar» (content\menu_scenes\clubhouse.toml) gives it
-- the game's white character edge while selected (VRFW edge_actor), and A runs BetterMenu.Avatar.Open (VRFW action
-- call): the avatar stands up and the camera moves in front of it (the scene's «avatar_front» shot). Back sits it down
-- again and brings the «story» shot back. Changing the mode (L2 / R2, the pad) leaves it seated at once.
-- Step B (v1): once it stands, the game's own avatar editor (chara_edit_menu, as the Kizuna avatar menu opens it) opens
-- over the scene; when the editor has closed (it saves the look itself), the avatar actor is made again with the new
-- look, sits down and the story shot comes back. While the editor runs, the actor is hidden.
-- Definitions and hooks only: no engine call at load time.
BetterMenu = type(BetterMenu) == "table" and BetterMenu or {}
BetterMenu.Avatar = BetterMenu.Avatar or {}
do
  local AV = BetterMenu.Avatar
  local S = {
    ID = "better_menu.avatar_stage",
    LOG = 3661580131,            -- CMND_EVT_LOG
    STATE = 2588710643,          -- CMND_VRFW_MENU_SCENE_STATE () -> state, key
    SCENE_SHOT = 2012234360,     -- CMND_VRFW_MENU_SCENE_SHOT (key, tile id | shot name)
    SPOT = 1,                    -- the avatar's spot (who = "avatar")
    FRONT_SHOT = "avatar_front",
    BACK_SHOT = "story",
    STAND_UP = "座り1戻",         -- the base pack's rise from a seat, then its stand
    STAND = "立ち1L",
    SIT_DOWN = "座り1入",         -- the base pack's sitting down, then the NPC pack's seated loop
    SEATED = "NPC座り1L",
    BLEND = 0.2,
    STAND_FRAMES = 50,           -- the rise from the seat, then the editor opens
    EDITOR = 3549406257,         -- chara_edit_menu (the Kizuna avatar menu's «Editar avatar»)
    OPEN_MENU = 433545986,       -- CMND_OPEN_MENU_OBJECT
    MENU_EXISTS = 2231168902,    -- CMND_IS_EXIST_MENU_OBJECT (menu) (menu command)
  }
  local st = { open = false, phase = nil, frames = 0 }

  local function Log(...) pcall(funcLuaCommand, S.LOG, "better_menu", "avatar_stage", ...) end
  local function F(...)
    local r = table.pack(pcall(funcLuaCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end
  local function Crc(s)
    local n = 0xFFFFFFFF
    for i = 1, #s do
      n = bit32.bxor(n, s:byte(i))
      for _ = 1, 8 do n = bit32.bxor(bit32.rshift(n, 1), bit32.band(n, 1) ~= 0 and 0xEDB88320 or 0) end
    end
    return bit32.bxor(n, 0xFFFFFFFF)
  end
  local function SceneKey()
    local state, key = F(S.STATE)
    if state == "up" and type(key) == "string" and key ~= "" then return key end
  end
  local function Motion(clip, next_clip)
    if not (VRFW_MenuScene and VRFW_MenuScene.ActorMotion) then return false end
    return VRFW_MenuScene.ActorMotion(S.SPOT, Crc(clip), next_clip and Crc(next_clip) or 0, S.BLEND)
  end

  -- the hotspot's press: up, and the camera in front
  function AV.Open(name)
    if st.open then return end
    local key = SceneKey()
    if not key then return end
    st.open, st.phase, st.frames = true, "standing", 0
    if VRFW_MenuScene and VRFW_MenuScene.ActorEdge then VRFW_MenuScene.ActorEdge(S.SPOT, false) end
    local moved = Motion(S.STAND_UP, S.STAND)
    F(S.SCENE_SHOT, key, S.FRONT_SHOT)
    Log("open from hotspot", tostring(name), "stand up", tostring(moved))
  end

  -- back to the seat and the story shot (camera = true: also the camera)
  function AV.Close(why, camera)
    if not st.open then return end
    st.open, st.phase = false, nil
    local seated = Motion(S.SIT_DOWN, S.SEATED)
    local key = SceneKey()
    if camera and key then F(S.SCENE_SHOT, key, S.BACK_SHOT) end
    Log("closed:", tostring(why), "sit down", tostring(seated))
  end

  function AV.IsOpen() return st.open end

  -- the editor's steps (only while the avatar is up: the rise, then the editor until it closes)
  local function Step()
    if not st.phase then return end
    st.frames = st.frames + 1
    if st.phase == "standing" and st.frames >= S.STAND_FRAMES then
      st.phase, st.frames = "editing", 0
      if VRFW_MenuScene and VRFW_MenuScene.ActorShow then VRFW_MenuScene.ActorShow(S.SPOT, false) end
      local ok = F(S.OPEN_MENU, S.EDITOR)
      Log("the avatar editor opens:", tostring(ok))
    elseif st.phase == "editing" and st.frames > 30 then
      local ok, here = pcall(funcLuaMenuCommand, S.MENU_EXISTS, S.EDITOR)
      if not (ok and here == true) then
        Log("the avatar editor closed: the avatar is made again with its look")
        if VRFW_MenuScene and VRFW_MenuScene.ActorRebuild then VRFW_MenuScene.ActorRebuild(S.SPOT) end
        AV.Close("the editor closed", true)
      end
    end
  end

  if VRFW_MenuScene and VRFW_MenuScene.On then
    -- another mode focused: the avatar sits again (the camera already goes to that mode's shot)
    VRFW_MenuScene.On("mode_focused", S.ID .. ".mode", function() AV.Close("the mode changed", false) end)
  end

  if VRFW_Host ~= nil then
    VRFW_Host.on("title_menu_2", "OnInit", { id = S.ID .. ".init", phase = "after", fn = function()
      st.open, st.phase = false, nil
    end })
    VRFW_Host.on("title_menu_2", "Step", { id = S.ID .. ".step", phase = "after", fn = function()
      local ok, why = pcall(Step)
      if not ok then Log("error", tostring(why)) end
    end })
    -- Back while the avatar stands: it sits again (the title's own Back is not run)
    VRFW_Host.on("title_menu_2", "OnBack", { id = S.ID .. ".back", phase = "around", priority = -30,
      fn = function(nxt, ...)
        if st.open then
          if st.phase ~= "editing" then AV.Close("back", true) end
          return 1
        end
        return nxt(...)
      end })
  end
end
