-- menu_scene (VR-Framework, docs/framework/menu-scene.md «Scene actors»): a scene's people as scene characters.
-- A scene with people_as = "actors" (all its people) or guests = "actors" (its guests only) gets no NPCs for them: this
-- service reads the scene's actor list (CMND_VRFW_MENU_SCENE_ACTORS) and, when its signature changes, keeps one scene
-- character per entry on its spot, made with the engine's own create (the menus' character model create 0xBED1C353
-- with the person's kit; without a kit CMND_CREATE_SCN_CHARA 0x419E0673, the party-join event's call). Each one gets
-- its chara's NPC pack (the NPC clips and faces), is built, plays its spot's pose once and is shown only then.
-- The first set of a scene is shown all together, and the scene's reveal (VRFW_MenuSceneCanReveal) waits for it: a
-- create or build that fails is made again (RETRIES), and one summary line is logged («actors shown: 19/19»). A later
-- change (a team edit, other guests) keeps every actor whose entry stayed, makes only the new ones, and swaps each one
-- on its spot when the new one is posed. Field objects of the map: its light, no npc_setting, no NPC manager.
-- Nothing runs at load time.
do
  local A = {
    ID = "vrfw.menu_scene.actors",
    STATE = 2588710643,          -- CMND_VRFW_MENU_SCENE_STATE () -> state, key
    ACTORS = 3936847707,         -- CMND_VRFW_MENU_SCENE_ACTORS (key) -> "" | { sig, n, people, [i] = actor }
    LOG = 3661580131,            -- CMND_EVT_LOG
    CREATE = 1100875379,         -- CMND_CREATE_SCN_CHARA (id, 1, x, y, z, rx, ry, rz, 9, true, false, 0, false, 0, 6) -> handle
    KIT_CREATE = 3201418067,     -- the menus' character model create (menu_chara_model_comp ChangeCharaModel): the
                                 -- CMND_CREATE_SCN_CHARA arguments, the name's identity (14), ..., the uniform (18)
    LOOK_ID = 347353059,         -- (id, false) -> the values the party event gives CMND_CREATE_SCN_CHARA (its first)
    BUILDING = 72150831,         -- (handle) -> true while the character is still being built
    FADE = 2558183053,           -- (handle, from, to, true): the party event's fade (0, 0 hidden; 1, 1 shown)
    SHOW = 1890282463,           -- (handle, true)
    MOTION = 3429940381,         -- (handle, clip, next clip, blend, flag, int, start): handler 0xC89990; its 7th
                                 -- argument (default -1) goes into the play request beside the blend: tried as the
                                 -- start time, so a pose starts past its first face keys (the open mouth on reveal)
    FACE_HOLD = 719584893,       -- CMND_VRFW_SCN_CHARA_FACE_HOLD (handle, on): the body clip's face channel off / on
    EDGE = 2124849688,           -- CMND_VRFW_SCN_CHARA_EDGE (handle, on, r, g, b, a, pixel) -> text | nil, why
    EDGE_PIXEL = 4.0,            -- the selected actor's edge width (pixels)
    UNIFORM_KINDS = { field = 0, keeper = 10 }, -- an actor's uniform_kind -> argument 20 of the kit create
    POSE_START = 0.5,            -- seconds into the pose clip the loop starts (the 7th argument; -1 = the game's)
    DELETE = 2054212170,         -- (handle)
    MOTION_PACK = 3566349311,    -- CMND_VRFW_SCN_CHARA_MOTION_PACK (handle, motion set): the set's NPC pack
    FACIAL = 556344657,          -- CMND_VRFW_SCN_CHARA_FACIAL_DEFAULT (handle): the facial component's default face
                                 -- again (CMND_SET_MOTION_FACIAL(chara, 0) by handle)
    FACE_PROBE = 1557528115,     -- CMND_VRFW_SCN_CHARA_FACE_PROBE (handle, why): a read-only probe of the face, logged
    PROBE_DELAY = 90,            -- frames after a shot change (or the reveal) before the face probe (the camera settled)
    PROBE_MAX = 6,               -- face probes per title opening
    HANDLES = 3587749369,        -- CMND_VRFW_MENU_SCENE_ACTOR_HANDLES (key, text | nil) -> text: the live actors kept by
                                 -- the framework («handle=id|…») for a title that opens again over the same run
    IS_PLAYING = 1198973151,     -- CMND_GET_IS_PLAY_MOTION (object, clip) -> playing
    OBJECT_OF = 117654406,       -- (scene character handle) -> ok, object: the handle CMND_GET_IS_PLAY_MOTION takes (the
                                 -- retail reads it this way: prog_common, soccer_summon_menu)
    BUILD_FRAMES = 600,          -- an actor not built after these frames is made again
    RETRIES = 3,                 -- makes again of an actor whose create or build failed
    RETRY_GAP = 30,              -- frames before a failed actor is made again
    -- the pose: the spot's first clip at frame 1 after the build, checked at the CHECK_AT frames on the character's
    -- object; played again once at most while it is not playing (a replay of a playing clip drops the face). The pose is
    -- never replaced by another clip (2.4.241 fell back to the plain stand on a check that read the wrong handle: every
    -- actor stood, faces blank)
    CHECK_AT = { 5, 20, 60 },
    SHOW_AFTER = 10,             -- frames after a pose is confirmed playing before the actor is shown (its face set)
    UNVEIL_FRAMES = 3,           -- a shown actor stays transparent this many frames, its default face set again, before
                                 -- it fades in: a hidden character's face is not updated, so its first visible frame
                                 -- showed the clip's open mouth (owner 2026-10-19)
    STAGGER = 37,                -- the pose starts 1 + (index x 13 mod STAGGER) frames after the build: the loops of
                                 -- people standing together do not move in sync
    GATE_FRAMES = 240,           -- the scene's reveal waits at most these frames for the first set
  }
  local st = { key = nil, sig = nil, actors = {}, order = {}, leaving = {}, batch = {}, revealed = false, frames = 0, logged = 0,
    people = false, actor_type = 1, probe_in = nil, probe_why = nil, probes = 0 }

  local function F(...)
    local r = table.pack(pcall(funcLuaCommand, ...))
    if not r[1] then return nil, r[2] end
    return table.unpack(r, 2, r.n)
  end
  local function Log(...)
    if st.logged < 300 then
      st.logged = st.logged + 1
      pcall(funcLuaCommand, A.LOG, "menu_scene", "title_menu_2", "actors", ...)
    end
  end
  local function Hex(v) return string.format("0x%08X", (tonumber(v) or 0) % 4294967296) end

  -- the live actors to the framework (one owner across title openings)
  local function Keep()
    if not st.key then return end
    local parts = {}
    for _, a in pairs(st.actors) do
      if a.handle then parts[#parts + 1] = string.format("%.0f=%s", a.handle, a.id) end
    end
    for _, a in pairs(st.leaving) do
      if a.handle then parts[#parts + 1] = string.format("%.0f=%s", a.handle, a.id) end
    end
    F(A.HANDLES, st.key, table.concat(parts, "|"))
  end

  -- a title opened again over the same run: the actors the last one made are taken over (shown ones stay shown)
  local function Adopt(r)
    local text = F(A.HANDLES, st.key)
    if type(text) ~= "string" or text == "" then return end
    local entries = {}
    for i = 1, tonumber(r.n) or 0 do
      local g = r[i]
      if g.id then entries[g.id] = { g = g, index = i } end
    end
    local adopted, dropped = 0, 0
    for h, id in text:gmatch("(%d+)=([^|]+)") do
      local e = entries[id]
      if e and not st.actors[id] then
        st.actors[id] = { id = id, g = e.g, index = e.index, tries = 1, handle = tonumber(h), phase = "shown", age = 0 }
        adopted = adopted + 1
      else
        F(A.DELETE, tonumber(h))
        dropped = dropped + 1
      end
    end
    if adopted > 0 then st.revealed = true end
    Log("taken over from the last title:", adopted, "actor(s),", dropped, "deleted")
  end

  local function Delete(a, why)
    if a.handle and a.handle ~= 0 then
      F(A.DELETE, a.handle)
      Log("deleted", a.handle, a.id, "(" .. why .. ")")
    end
    a.handle = nil
  end

  local function DeleteAll(why)
    for _, a in pairs(st.actors) do Delete(a, why) end
    for _, a in pairs(st.leaving) do Delete(a, why) end
    st.actors, st.order, st.leaving, st.sig, st.dirty, st.batch = {}, {}, {}, nil, true, {}
  end

  -- one scene character for entry g, hidden, with its NPC pack; returns the handle and how it was made
  local function Create(g, index)
    -- the spot's facing is in degrees; the create takes radians
    local rot = math.rad(tonumber(g.rot) or 0)
    local kit = tonumber(g.uniform) or 0
    local h, how
    -- the kit create when the actor list gives the actor a uniform (and its kind); without one the actor is made from
    -- its own chara (CMND_CREATE_SCN_CHARA)
    if tonumber(g.uniform) ~= nil then
      local identity = tonumber(g.slot) or index
      -- arguments 19 / 20: the uniform's number (0xFFFF = the chara's own) and its kind, as the menus' uniform setter
      -- (menu command 0xC4232044 -> SetUniformID) passes them: 10 = the goalkeeper's version of the kit (the retail
      -- result screen's keeper), 0 = the outfield one
      local kind = A.UNIFORM_KINDS[tostring(g.uniform_kind)] or A.UNIFORM_KINDS.field
      h = F(A.KIT_CREATE, g.base, st.actor_type, g.x, g.y, g.z, 0, rot, 0, 9, true, false, 0, false, identity, 6, false, 255, kit,
        0xFFFF, kind, false, 0, 0, false, false, true, false)
      how = "kit " .. Hex(kit)
    end
    if type(h) ~= "number" or h == 0 then
      local tries = { { "chara_base", g.base } }
      local look = F(A.LOOK_ID, g.base, false)
      if look ~= nil and look ~= g.base then tries[#tries + 1] = { "look id", look } end
      for _, t in ipairs(tries) do
        h = F(A.CREATE, t[2], st.actor_type, g.x, g.y, g.z, 0, rot, 0, 9, true, false, 0, false, 0, 6)
        how = t[1] .. (kit ~= 0 and " (the kit create gave nothing)" or "")
        if type(h) == "number" and h ~= 0 then break end
      end
    end
    if type(h) ~= "number" or h == 0 then return nil, how end
    F(A.FADE, h, 0, 0, true)
    local okp, why = F(A.MOTION_PACK, h, g.set)
    if okp ~= true then Log("motion pack", h, tostring(g.set), "not attached:", tostring(why)) end
    return h, how
  end

  local function Make(a)
    a.tries, st.dirty = a.tries + 1, true
    a.handle, a.how = Create(a.g, a.index)
    a.phase, a.age, a.built_at, a.posed, a.check, a.settled_at = "building", 0, nil, false, nil, nil
    a.object, a.replayed = nil, false
    Log("create", a.id, "try", a.tries, "->", tostring(a.handle), a.how or "")
    if not a.handle then a.phase, a.wait = "retry", A.RETRY_GAP end
    if not a.handle and a.tries > A.RETRIES then a.phase = "failed" end
  end

  local function Retry(a, why)
    Delete(a, why)
    if a.tries > A.RETRIES then
      a.phase = "failed"
      Log("gave up", a.id, "after", a.tries, "tries:", why)
    else
      a.phase, a.wait = "retry", A.RETRY_GAP
    end
  end

  -- the list changed: keep what stayed, make what is new; a shown actor whose spot gets a new one stays until that one
  -- is posed
  -- a change after the first set: the actors it makes are shown together, in one frame, once each is ready; the
  -- actors they replace stay shown until then (never a partial set of new people)
  local function Sync(r)
    local want, order = {}, {}
    for i = 1, tonumber(r.n) or 0 do
      local g = r[i]
      local id = g.id or string.format("%d:%.0f:%.0f", i, tonumber(g.base) or 0, tonumber(g.kit) or 0)
      want[id] = { g = g, index = i }
      order[#order + 1] = id
    end
    local kept, made, gone = 0, 0, 0
    for id, a in pairs(st.actors) do
      if not want[id] then
        gone = gone + 1
        st.actors[id] = nil
        if a.phase == "shown" and a.g.slot ~= nil then
          local old = st.leaving[a.g.slot]
          if old then Delete(old, "replaced twice") end
          st.leaving[a.g.slot] = a
        else
          Delete(a, "no longer in the list")
        end
      end
    end
    for _, id in ipairs(order) do
      if st.actors[id] then
        kept = kept + 1
      else
        local w = want[id]
        local a = { id = id, g = w.g, index = w.index, tries = 0 }
        st.actors[id] = a
        Make(a)
        made = made + 1
        st.batch[#st.batch + 1] = id
      end
    end
    -- a spot left with nobody new: its old actor goes now
    local slots = {}
    for _, a in pairs(st.actors) do
      if a.g.slot ~= nil then slots[a.g.slot] = true end
    end
    for slot, a in pairs(st.leaving) do
      if not slots[slot] then
        Delete(a, "its spot is empty now")
        st.leaving[slot] = nil
      end
    end
    st.order, st.sig = order, r.sig
    Log("list:", #order, "actor(s):", kept, "kept,", made, "made,", gone, "gone")
  end

  -- one actor's steps: build, pose once, check, ready
  local function Advance(a)
    if a.phase == "retry" then
      a.wait = (a.wait or 0) - 1
      if a.wait <= 0 then Make(a) end
      return
    end
    if not a.handle or a.phase == "failed" then return end
    a.age = a.age + 1
    if a.phase == "building" then
      if F(A.BUILDING, a.handle) == true then
        if a.age >= A.BUILD_FRAMES then Retry(a, "not built after " .. a.age .. " frames") end
        return
      end
      a.phase, a.built_at = "posing", a.age
      return
    end
    if a.phase ~= "posing" then return end
    local since = a.age - a.built_at - (a.index * 13) % A.STAGGER
    local list = type(a.g.clip_list) == "table" and a.g.clip_list or { a.g.clip }
    local pose = list[1] or a.g.clip
    if not a.posed and since >= 1 then
      a.posed, a.check = true, 1
      F(A.MOTION, a.handle, pose, 0, 0, 0, 0, A.POSE_START)
    end
    local at = A.CHECK_AT[a.check or 1]
    if a.posed and not a.settled_at and at and since >= at then
      a.check = (a.check or 1) + 1
      if a.object == nil then
        local ok, object = F(A.OBJECT_OF, a.handle)
        a.object = (ok == true and type(object) == "number" and object ~= 0) and object or false
      end
      local playing = a.object and F(A.IS_PLAYING, a.object, pose) == true
      if playing then
        a.settled_at = a.age
        -- the actor's face options (the scene's actor_face / actor_hold_face): the facial component's default face
        -- again once the pose plays, and the clip's face channel switched off so the expression stays
        if a.g.face == "default" or a.g.hold_face == true then
          local lip, why, held, hwhy = nil, "not asked", nil, "not asked"
          if a.g.face == "default" then lip, why = F(A.FACIAL, a.handle) end
          if a.g.hold_face == true then held, hwhy = F(A.FACE_HOLD, a.handle, true) end
          Log("face", a.id, a.handle, "default ->", type(lip) == "number" and Hex(lip) or ("not set: " .. tostring(why)),
            held and "held" or ("not held: " .. tostring(hwhy)))
        end
      elseif not a.replayed then
        a.replayed = true
        F(A.MOTION, a.handle, pose, 0, 0, 0, 0, A.POSE_START)
        Log("pose", a.id, Hex(pose), "not playing at frame", since, "(object", tostring(a.object), "): played once more")
      elseif not A.CHECK_AT[a.check] then
        a.settled_at = a.age
        Log("pose", a.id, Hex(pose), "not confirmed after", since, "frames (object", tostring(a.object), "): kept")
      end
    end
    if a.settled_at and a.age - a.settled_at >= A.SHOW_AFTER then a.phase = "ready" end
  end

  -- shown in two steps: drawn but transparent, its default face set again (the face of a hidden character is not
  -- updated), then faded in UNVEIL_FRAMES later; the actors shown together fade in together
  local function Show(a)
    F(A.SHOW, a.handle, true)
    if a.g.face == "default" then F(A.FACIAL, a.handle) end
    a.phase, a.unveil_at = "unveiling", st.frames
  end

  local function Unveil()
    for _, id in ipairs(st.order) do
      local a = st.actors[id]
      if a and a.phase == "unveiling" and st.frames - a.unveil_at >= A.UNVEIL_FRAMES then
        F(A.FADE, a.handle, 1, 1, true)
        a.phase, st.dirty = "shown", true
        local old = a.g.slot ~= nil and st.leaving[a.g.slot]
        if old then
          Delete(old, "replaced by " .. a.id)
          st.leaving[a.g.slot] = nil
        end
      end
    end
  end

  local function Unveiling()
    for _, a in pairs(st.actors) do
      if a.phase == "unveiling" then return true end
    end
    return false
  end

  -- the face probe: one kit-created actor and one other, logged by the framework (shot changes and the reveal)
  local function Probe()
    local kit, other
    for _, id in ipairs(st.order) do
      local a = st.actors[id]
      if a and a.phase == "shown" and a.handle then
        if a.g.uniform ~= nil then kit = kit or a else other = other or a end
      end
    end
    for _, a in ipairs({ kit or false, other or false }) do
      if a then
        local text, why = F(A.FACE_PROBE, a.handle, st.probe_why)
        Log("face probe", st.probe_why, a.id, type(text) == "string" and "logged" or ("failed: " .. tostring(why)))
      end
    end
  end

  local function ArmProbe(why)
    if st.probes >= A.PROBE_MAX or not st.revealed then return end
    st.probes, st.probe_in, st.probe_why = st.probes + 1, A.PROBE_DELAY, why
  end

  local function Tick()
    local state, key = F(A.STATE)
    local live = (state == "up" or state == "switching") and type(key) == "string" and key ~= ""
    if not live or key ~= st.key then
      if next(st.actors) or next(st.leaving) then DeleteAll(live and "another scene" or "the scene is not up") end
      st.key, st.sig, st.revealed, st.frames, st.people = live and key or nil, nil, false, 0, false
      if not live then return end
    end
    local r = F(A.ACTORS, key)
    if type(r) ~= "table" then
      if next(st.actors) or next(st.leaving) then DeleteAll("no actor list") end
      st.people = false
      return
    end
    st.people = r.people == 1
    st.actor_type = r.actor_type == 2 and 2 or 1
    if r.sig ~= st.sig then
      if st.sig == nil and not next(st.actors) then Adopt(r) end
      Sync(r)
      st.dirty = true
    end
    st.frames = st.frames + 1
    if st.probe_in then
      st.probe_in = st.probe_in - 1
      if st.probe_in <= 0 then
        st.probe_in = nil
        Probe()
      end
    end
    for _, id in ipairs(st.order) do Advance(st.actors[id]) end
    Unveil()
    if st.revealed then
      if #st.batch == 0 then return end
      local ready, failed = {}, {}
      for _, id in ipairs(st.batch) do
        local a = st.actors[id]
        if a then
          if a.phase == "ready" then
            ready[#ready + 1] = a
          elseif a.phase == "failed" then
            failed[#failed + 1] = id
          else
            return                       -- one still building, posing or waiting for its retry: none is shown yet
          end
        end
      end
      for _, a in ipairs(ready) do Show(a) end
      Log(string.format("change shown together: %d/%d", #ready, #st.batch),
        #failed > 0 and ("failed: " .. table.concat(failed, " ")) or "")
      st.batch = {}
      return
    end
    -- the first set: all together, once each is ready or given up (or the gate's time is over)
    local ready, failed, waiting = 0, {}, 0
    for _, id in ipairs(st.order) do
      local a = st.actors[id]
      if a.phase == "ready" then
        ready = ready + 1
      elseif a.phase == "failed" then
        failed[#failed + 1] = a.id
      else
        waiting = waiting + 1
      end
    end
    if waiting > 0 and st.frames <= A.GATE_FRAMES then return end
    for _, id in ipairs(st.order) do
      local a = st.actors[id]
      if a.phase == "ready" then Show(a) end
    end
    st.revealed, st.batch = true, {}
    ArmProbe("reveal")
    Log(string.format("shown: %d/%d after %d frames", ready, #st.order, st.frames),
      #failed > 0 and ("failed: " .. table.concat(failed, " ")) or "",
      waiting > 0 and (waiting .. " still loading (each shown when ready)") or "")
  end

  -- an actor by its spot slot, for the title's hotspots and the mods: the handle (nil = none shown), its edge, a clip
  local function ActorOf(slot)
    for _, a in pairs(st.actors) do
      if a.g and a.g.slot == slot and a.handle and a.phase == "shown" then return a end
    end
  end
  VRFW_MenuScene = VRFW_MenuScene or {}
  function VRFW_MenuScene.ActorHandle(slot)
    local a = ActorOf(slot)
    return a and a.handle or nil
  end
  -- the actor's white edge on (the game's character outline: its CCharaEdgeProperty) or back to its own
  function VRFW_MenuScene.ActorEdge(slot, on)
    local a = ActorOf(slot)
    if not a then return false end
    local text, why = F(A.EDGE, a.handle, on == true, 1, 1, 1, 1, A.EDGE_PIXEL)
    Log("edge", a.id, on and "on" or "off", tostring(text or why))
    return text ~= nil
  end
  -- a clip on the actor (handle, clip, next clip, blend: the motion command's)
  -- the actor made again (e.g. its look changed: an edited avatar), shown when posed as a change of the list
  function VRFW_MenuScene.ActorRebuild(slot)
    local a = ActorOf(slot)
    if not a then return false end
    Delete(a, "rebuilt")
    st.actors[a.id] = nil
    st.sig = nil                                             -- the next step makes it again from the same list
    return true
  end
  -- the actor hidden (on = false) or shown again
  function VRFW_MenuScene.ActorShow(slot, on)
    local a = ActorOf(slot)
    if not a then return false end
    F(A.FADE, a.handle, on and 1 or 0, on and 1 or 0, true)
    return true
  end
  function VRFW_MenuScene.ActorMotion(slot, clip, next_clip, blend)
    local a = ActorOf(slot)
    if not a then return false end
    F(A.MOTION, a.handle, clip, next_clip or 0, blend or 0.2)
    return true
  end

  -- the scene's reveal waits for the first set of people actors (at most GATE_FRAMES)
  local can_reveal_before = VRFW_MenuSceneCanReveal
  VRFW_MenuSceneCanReveal = function(key)
    if type(can_reveal_before) == "function" and can_reveal_before(key) ~= true then return false end
    if st.people and st.key == key and (not st.revealed or Unveiling()) and st.frames <= A.GATE_FRAMES then return false end
    return true
  end

  -- a shot change (the framework's mode focus event) arms the face probe
  if VRFW_MenuScene and VRFW_MenuScene.On then
    VRFW_MenuScene.On("mode_focused", A.ID .. ".probe", function(index) ArmProbe("shot " .. tostring(index)) end)
  end

  if VRFW_Host ~= nil then
    VRFW_Host.on("title_menu_2", "OnInit", { id = A.ID .. ".init", phase = "after", fn = function() st.logged, st.probes = 0, 0 end })
    VRFW_Host.on("title_menu_2", "Step", { id = A.ID, phase = "after", fn = function()
      local ok, why = pcall(Tick)
      if not ok then pcall(funcLuaCommand, A.LOG, "menu_scene", "title_menu_2", "actors error", tostring(why)) end
      if st.dirty then
        st.dirty = false
        pcall(Keep)
      end
    end })
  end
end
