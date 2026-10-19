-- The Competition list's three players on the clubhouse pitch (docs/game/mods/better-menu.md §45, §66, §84): field NPCs
-- of the menu scene, on its three who = "guest" spots (content\menu_scenes\clubhouse.toml: the pitch in front of the
-- Competition shot, arms crossed). A team focused in the list gives the scene its three players as guests in their
-- own kit (CMND_VRFW_MENU_SCENE_GUESTS: the scene's people served again with them) and the field reloads its NPCs
-- (CMND_RELOAD_NPC, asked again a few times while the models arrive): the three change together with the rest of the
-- NPCs, and the menu camera is never used (it brought its own light and day sky over the clubhouse's sunset).
-- Only the last team is served: a team must stay focused SETTLE_FRAMES and a serve waits MIN_GAP_FRAMES after the last
-- (fast browsing mixed two teams' models); the Competition shot is framed to the three (scripts/competition.lua
-- «frame»: the tallest whole) and set at run time (CMND_VRFW_MENU_SCENE_SHOT_POSE).
-- Definitions and hooks only; engine calls only from the list's Step.
BetterMenu.CompetitionPlayers = BetterMenu.CompetitionPlayers or {}
do
  local C = BetterMenu.Competition
  local P = BetterMenu.CompetitionPlayers
  local Guests = {
    COUNT = 3,                     -- players on the pitch
    GUESTS = C.Hash("CMND_VRFW_MENU_SCENE_GUESTS"),   -- (scene key, guests) -> placed, text
    SCENE_FOR = C.Hash("CMND_VRFW_MENU_SCENE_FOR"),   -- (menu) -> scene key
    RELOAD_NPC = 1438169648,       -- CMND_RELOAD_NPC (NPC guests only; scene actors need none)
    SCENE = 1465766639,            -- CMND_VRFW_MENU_SCENE (key) -> table | ""
    RELOAD_AT_FRAMES = { 1, 45, 150 },   -- after a team change (60 a second): the models arrive over a few frames
    SHOT_POSE = C.Hash("CMND_VRFW_MENU_SCENE_SHOT_POSE"),
    SHOT = "competition",
    SETTLE_FRAMES = 12,            -- a team focused this long is served (browsing passes the others)
    MIN_GAP_FRAMES = 30,           -- frames between two serves
  }
  local wanted, served, frames, scene_key, logged, as_actors = nil, nil, 0, nil, 0, false
  local wanted_members, wanted_at, clock = "", 0, 0
  local wanted_game = nil
  local framed = false             -- the shot is posed once per list opening (a fixed camera: no move on a team change)

  local function Log(...)
    if logged < 80 then
      logged = logged + 1
      C.Log("players", ...)
    end
  end

  -- members: "keeper|player:<chara base id>:<motion set>,…" in the picker's order (captain, goalkeeper, third)
  function P.Want(members, uniform, game)
    wanted_game = game
    local parts = {}
    for role, base, mset in tostring(members or ""):gmatch("(%a+):(%d+):(%w+)") do
      if #parts < Guests.COUNT then
        -- the shown team's kit on every player, the goalkeeper in its keeper version (the framework's actor uniform
        -- and uniform kind)
        parts[#parts + 1] = string.format("guest:%s:%s:%.0f:%s", base, mset, tonumber(uniform) or 0, role == "keeper" and "keeper" or "field")
      end
    end
    -- the places fitted to the bodies (scripts/competition.lua «places»): "x,z,turn;…" in the same order
    local placed = C.State("places", tostring(members or ""))
    if type(placed) == "string" and placed ~= "" then
      local i = 0
      for place in placed:gmatch("[^;]+") do
        i = i + 1
        if parts[i] then parts[i] = parts[i] .. "@" .. place end
      end
    end
    local list = table.concat(parts, ",")
    if list ~= wanted then
      wanted, wanted_members, wanted_at = list, tostring(members or ""), clock
      Log("wanted", list)
    end
  end

  -- the Competition shot framed to the three
  local function Frame()
    local r = table.pack(C.State("frame", wanted_members))
    if type(r[1]) ~= "number" then return end
    local ok = C.F(Guests.SHOT_POSE, scene_key, Guests.SHOT, r[1], r[2], r[3], r[4], r[5], r[6], r[7])
    Log("shot framed for the tallest", tostring(r[8]), "m:", tostring(ok))
  end

  local function Step()
    clock = clock + 1
    C.ContraluzStep()
    if wanted and wanted ~= served and clock - wanted_at >= Guests.SETTLE_FRAMES
        and (served == nil or frames >= Guests.MIN_GAP_FRAMES) then
      if scene_key == nil then
        local k = C.F(Guests.SCENE_FOR, "title_menu_2")
        scene_key = type(k) == "string" and k or ""
      end
      if scene_key == "" then return end
      local sc = C.F(Guests.SCENE, scene_key)
      as_actors = type(sc) == "table" and sc.guests_as == "actors"
      local placed, text = C.F(Guests.GUESTS, scene_key, wanted)
      if placed == nil then return end    -- the framework answers on a later frame
      served, frames = wanted, 0
      Log("guests served:", tostring(placed), tostring(text))
      if not framed then
        framed = true
        Frame()
      end
      -- a team not beaten in any class stands in contre-jour (VRFW_FM.Best: its highest class won, 0 = none)
      if type(wanted_game) == "number" and VRFW_FM and type(VRFW_FM.Best) == "function" then
        local okb, best = pcall(VRFW_FM.Best, wanted_game)
        -- the contre-jour light push is off (0.7.12): it tinted the map and stayed in the engine's light stack (also into
        -- matches) while the characters kept their light; only its removal still runs
        if okb and type(best) == "number" and best ~= 0 then C.Contraluz(false) end
      end
    end
    if served then
      frames = frames + 1      -- also the gap before the next serve (MIN_GAP_FRAMES)
    end
    if served and not as_actors then
      for _, at in ipairs(Guests.RELOAD_AT_FRAMES) do
        if frames == at then
          local ok = C.F(Guests.RELOAD_NPC)
          Log("NPC reload asked", frames, "frame(s) after the team change:", tostring(ok))
        end
      end
    end
  end

  local function Reset()
    framed = false
    wanted, served, frames, scene_key, logged, as_actors = nil, nil, 0, nil, 0, false
    wanted_members, wanted_at, clock = "", 0, 0
  end

  if VRFW_Host then
    VRFW_Host.on("soccer_vs_cpu_list_menu", "OnInit", { id = "better_menu.competition.players_init", phase = "after",
      fn = Reset })
    VRFW_Host.on("soccer_vs_cpu_list_menu", "PostStep", { id = "better_menu.competition.players_step", phase = "after",
      create = true, fn = function()
        local s = C.State()
        if type(s) ~= "table" or s.open ~= true or s.launch then return end
        local ok, why = pcall(Step)
        if not ok then Log("error", tostring(why)) end
      end })
  end
end
