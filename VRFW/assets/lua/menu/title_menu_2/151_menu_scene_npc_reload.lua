-- menu_scene (VR-Framework, docs/framework/menu-scene.md §2.1): the people of a menu scene after the hand-over.
-- The field's NPC update (lua/menu/rpg_info_window/151_menu_scene_npcs.lua) creates the scene's NPC entries in one
-- frame, before their character models are in memory; on a first entry the room comes up without them. While the
-- scene is up this asks the field's NPC manager to reload its NPCs (CMND_RELOAD_NPC: the manager rebuilds every entry
-- once no object kind is updating) a few times after the menu shows, so people whose models arrived since are made.
-- The same asks run again when the title gets the scene back from a menu opened over it: the title's OnInit (a menu
-- that replaced the title) and VRFW_MenuScenePeopleAgain(why) (a menu a mod opened on top of the title, e.g. a roster
-- whose character models replace the people's). Logged per ask. Only scenes that place people; nothing runs at load time.
-- The people follow the team on events, not by polling: when the title gets the scene back (its OnInit after a menu
-- that replaced it, VRFW_MenuScenePeopleAgain from a menu opened over it, e.g. a roster) the active team is read again
-- (VRFW_MenuSceneTeam, lua/menu/_all/72_menu_scene_team.lua); when its members or kit differ from what was placed, the
-- scene's people are served again (CMND_VRFW_MENU_SCENE_PEOPLE), with the placed list logged. NPC people are then
-- reloaded; scene actors (people_as = "actors") change by themselves, only the ones that changed.
-- People served again while the map is up are read into the map's NPC set first (CMND_VRFW_MENU_SCENE_NPC_READ, every
-- frame until it is done: the game reads a map's npc_setting only when the map loads); then the reloads are asked.
do
  local NpcReload = {
    ID = "vrfw.menu_scene.npc_reload",
    STATE = VRFW_Cmd.VRFW_MENU_SCENE_STATE,         -- CMND_VRFW_MENU_SCENE_STATE () -> state, key, …
    SCENE = VRFW_Cmd.VRFW_MENU_SCENE,         -- CMND_VRFW_MENU_SCENE (key) -> table | ""
    RELOAD_NPC = VRFW_Cmd.RELOAD_NPC,    -- CMND_RELOAD_NPC
    LOG = VRFW_Cmd.EVT_LOG,           -- crc32("CMND_EVT_LOG")
    ASK_AT_FRAMES = { 30, 120, 300 },   -- after the scene is up (60 a second)
    ASK_AGAIN_AT_FRAMES = { 2, 60, 240 },   -- after a menu over the title gave it back
    PEOPLE = VRFW_Cmd.VRFW_MENU_SCENE_PEOPLE,         -- CMND_VRFW_MENU_SCENE_PEOPLE (key, members, uniform, avatar) -> placed, text
    AVATAR = VRFW_Cmd.VRFW_MENU_SCENE_AVATAR,         -- CMND_VRFW_MENU_SCENE_AVATAR () -> chara_base of the save's avatar
    MOTION_SET = VRFW_Cmd.VRFW_CHARA_MOTION_SET,    -- CMND_VRFW_CHARA_MOTION_SET (chara_base) -> motion set
    NPC_READ = VRFW_Cmd.VRFW_MENU_SCENE_NPC_READ,       -- CMND_VRFW_MENU_SCENE_NPC_READ () -> "read" | "busy" | "none" | "failed"
    NPC_ENTRIES = VRFW_Cmd.VRFW_MENU_SCENE_NPC_ENTRIES,     -- CMND_VRFW_MENU_SCENE_NPC_ENTRIES (why) -> text (logged)
  }
  local frames, scene_key, people = 0, nil, false
  local asks, reason = NpcReload.ASK_AT_FRAMES, "up"
  local team_sig, scene_kind, actors = nil, nil, false
  local FollowTeam, AskAgain             -- defined below (Tick calls them)

  local function F(...)
    local r = table.pack(pcall(funcLuaCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end

  -- the NPC manager's live entries (VRFW.map_npcs.entries): how many, with a character, active, with a model
  -- (CMND_VRFW_MENU_SCENE_NPC_ENTRIES, logged by the framework)
  local probe_at = {}
  local function Probe(why)
    F(NpcReload.NPC_ENTRIES, why)
  end

  local function Tick()
    local state, key = F(NpcReload.STATE)
    if state ~= "up" or type(key) ~= "string" or key == "" then
      frames, scene_key = 0, nil
      return
    end
    if key ~= scene_key then
      asks, reason = NpcReload.ASK_AT_FRAMES, "up"
      scene_key, frames = key, 0
      local s = F(NpcReload.SCENE, key)
      people = type(s) == "table" and (tonumber(s.spots) or 0) > 0 and (s.people or "") ~= ""
      scene_kind = type(s) == "table" and s.people or nil
      actors = type(s) == "table" and s.people_as == "actors"
      team_sig = nil
      if people then FollowTeam(key, "the scene is up") end
    end
    if not people or actors then return end
    if F(NpcReload.NPC_READ) == "read" then AskAgain("the people were read again") end
    frames = frames + 1
    for _, at in ipairs(asks) do
      if frames == at then
        local ok = F(NpcReload.RELOAD_NPC)
        F(NpcReload.LOG, "menu_scene", "title_menu_2", "NPC reload asked", frames, "frame(s) after " .. reason .. ":", tostring(ok))
        probe_at[frames + 60] = reason
      end
    end
    if probe_at[frames] then
      Probe(string.format("%d frame(s) after %s", frames, probe_at[frames]))
      probe_at[frames] = nil
    end
  end

  -- the title got the scene back: the team compared now, then (NPC people) the asks again from the next frame on
  AskAgain = function(why)
    asks, reason, frames = NpcReload.ASK_AGAIN_AT_FRAMES, tostring(why or "a menu over the title"), 0
    F(NpcReload.LOG, "menu_scene", "title_menu_2", "people asked again:", reason)
    if scene_key and people then FollowTeam(scene_key, reason) end
  end

  -- the active team against the placed people: served again when it changed
  FollowTeam = function(key, event)
    if scene_kind ~= "active_team" or type(VRFW_MenuSceneTeam) ~= "function" then return end
    local members, uniform, why = VRFW_MenuSceneTeam()
    local sig = tostring(members) .. "|" .. tostring(uniform)
    if team_sig == nil then
      team_sig = sig                    -- the team the scene was entered with
      return
    end
    if sig == team_sig then return end
    team_sig = sig
    local avatar = ""
    local base = F(NpcReload.AVATAR)
    local mset = type(base) == "number" and base ~= 0 and F(NpcReload.MOTION_SET, base) or nil
    if type(mset) == "string" then avatar = string.format("%.0f:%s", base % 4294967296, mset) end
    local placed, text = F(NpcReload.PEOPLE, key, members, string.format("%.0f", uniform), avatar)
    F(NpcReload.LOG, "menu_scene", "title_menu_2", "people: the team changed (" .. tostring(event) .. "):", why, "->",
      tostring(placed), tostring(text), "members", members)
    if tonumber(placed) and not actors then
      asks, reason, frames = NpcReload.ASK_AGAIN_AT_FRAMES, "the team changed", 0
    end
  end
  VRFW_MenuScenePeopleAgain = function(why) pcall(AskAgain, why) end

  if VRFW_Host ~= nil then
    VRFW_Host.on("title_menu_2", "OnInit", {
      id = NpcReload.ID .. ".init", phase = "after",
      fn = function()
        -- a scene already up when the title opens: the title came back from a menu that replaced it
        local state, key = F(NpcReload.STATE)
        if state == "up" and type(key) == "string" and key ~= "" and key == scene_key then
          pcall(AskAgain, "the title opened again")
        end
      end,
    })
    VRFW_Host.on("title_menu_2", "Step", {
      id = NpcReload.ID, phase = "after",
      fn = function()
        local ok, why = pcall(Tick)
        if not ok then F(NpcReload.LOG, "menu_scene", "title_menu_2", "NPC reload error", tostring(why)) end
      end,
    })
  end
end
