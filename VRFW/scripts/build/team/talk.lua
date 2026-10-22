-- `[[VRFW.Talk]]`: Chronicle-style talk scenes declared by mods, also usable as the pre-match / post-win talk of a `[[VRFW.RouteNode]]`.
-- One CONFIG row, one BODY row per line, one CHR row per cast member and line, appended to the chapter file `event_bustup_talk_data_config_c<N>`; texts go to `text/<lg>/event/<talk>.cfg.bin` and `text/event/<talk>_map.cfg.bin`.
local T = require "lib/team_util"
local TC = require "team/tc"
local K = {}

local DATA_PREFIX = "data/common/gamedata/event/event_bustup_talk_data_config_c"
local BG_DIR = "ev_chronicle_img/"
local L_CONFIG = "EV_BUSTUP_TALK_DATA_CONFIG"
local L_BODY = "EV_BUSTUP_TALK_DATA_BODY"
local NO_TEXT = "no_text"
local SOUND_PREFIX = "data/common/gamedata/event/event_bustup_talk_sound_data_config_"
local L_SCONFIG = "EV_BUSTUP_TALK_SOUND_DATA_CONFIG"
local L_SBODY = "EV_BUSTUP_TALK_SOUND_DATA_BODY"
-- cast lists of a chapter file (EV_BUSTUP_TALK_DATA_CHR_1..6), pose packs a character loads on its first row
local MAX_CAST, MAX_PACKS = 6, 3

-- chapter numbers N of the chapter files (`<DATA_PREFIX><N>_<version>.cfg.bin`), sorted
function K.chapter_numbers()
  local set = {}
  for _, k in ipairs(VRFW.team.keys_prefix(DATA_PREFIX)) do
    local rest = k:sub(#DATA_PREFIX + 1)
    if T.ends(rest, ".cfg.bin") then
      rest = rest:sub(1, -9)
      local n = rest:match("^(%d+)_")
      if n then set[tonumber(n)] = true end
    end
  end
  return T.keys(set)
end

-- a motion that is no alias: a `0x…` id, or a retail name (its pose pack by the name's prefix)
local function motion_raw(s)
  local t = T.trim(s)
  if t:sub(1, 2) == "0x" or t:sub(1, 2) == "0X" then return VRFW.ids.parse(t), "" end
  local pack = ""
  if T.starts(t, "戦1") then pack = "p020"
  elseif T.starts(t, "Bイベ") then pack = "p250"
  elseif T.starts(t, "Tイベ") then pack = "p200"
  elseif T.starts(t, "NPC") then pack = "p060" end
  return VRFW.crc32(t), pack
end

local function bg_of(s)
  local t = T.trim(s)
  local path = T.ends(t, ".g4tx") and t or (BG_DIR .. t .. ".g4tx")
  local name = T.last_part(path, "/")
  while T.ends(name, ".g4tx") and #name >= 5 do name = name:sub(1, -6) end
  return { path, name }
end

-- a float cell (0 = int 0, as the retail rows write it)
local function f32v(x)
  -- a value that is 0 as an f32 counts as the int 0
  if x == 0 or math.abs(x) < 7.006492321624085e-46 then return 0 end
  return { float = x }
end

function K.install(X)
  -- the aliases a mod may name motions and expressions by (defaults\talk.toml)
  local function env_of(al)
    local E = { motion = al.motion or {}, face = al.face or {} }
    local mkeys, fkeys = T.keys(E.motion), T.keys(E.face)
    function E.motion_of(s)
      local t = T.trim(s):lower()
      for _, k in ipairs(mkeys) do
        if k:lower() == t then
          local a = E.motion[k]
          return VRFW.crc32(a.name), a.pack or ""
        end
      end
      return motion_raw(s)
    end
    function E.face_of(s)
      local t = T.trim(s)
      local tl = t:lower()
      for _, k in ipairs(fkeys) do
        if k:lower() == tl then return VRFW.crc32(E.face[k]) end
      end
      return VRFW.ids.parse(t)
    end
    return E
  end

  local function chapter_key(ch)
    return X.table_key(DATA_PREFIX .. ch .. "_")
  end

  -- the chapter table `ch` (read once per build)
  function X.talk_chapter(ch, chapters)
    if chapters[ch] then return chapters[ch] end
    local k, e = chapter_key(ch)
    if not k then return nil, e end
    local t, e2 = VRFW.rows.open(k)
    if not t then return nil, e2 end
    chapters[ch] = t
    return t
  end

  -- the chapter of a retail talk and its first BODY row (and the plain line after it)
  function X.talk_scene(scene, chapters)
    local id = VRFW.crc32(T.trim(scene))
    local all = K.chapter_numbers()
    local order = {}
    local n = T.trim(scene):match("^ev([^_]*)")
    n = n and n:find("^%d+$") and tonumber(n) or nil
    if n then
      for _, c in ipairs(all) do
        if c == n or T.starts(T.d(c), T.d(n)) then order[#order + 1] = c end
      end
    end
    local inorder = {}
    for _, c in ipairs(order) do inorder[c] = true end
    for _, c in ipairs(all) do if not inorder[c] then order[#order + 1] = c end end
    for _, ch in ipairs(order) do
      local t, e = X.talk_chapter(ch, chapters)
      if not t then return nil, e end
      local ci = t:find(L_CONFIG, 0, id)
      if ci then
        if ci + 1 >= t:len() then return nil, "CONFIG row without REF_BODY" end
        local first = t:int(ci + 1, 0) or 0
        if first < 0 then first = 0 end
        local bodies = t:rows(L_BODY)
        if bodies[first + 1] == nil then return nil, "scene body gone" end
        local b0 = t:entry(bodies[first + 1])
        local b1 = bodies[first + 2] and t:entry(bodies[first + 2]) or t:entry(bodies[first + 1])
        return { ch, b0, b1 }
      end
    end
    return nil, "scene `" .. scene .. "` is in no chapter file of the boot index"
  end

  -- chara id → model (chara_base col 6); model → body (chara_model col 4); body → pack dir
  function X.talk_bodies()
    local kb, e = X.table_key("data/common/gamedata/character/chara_base_")
    if not kb then return nil, e end
    local km, e2 = X.table_key("data/common/gamedata/character/chara_model_")
    if not km then return nil, e2 end
    local b, e3 = VRFW.rows.open(kb)
    if not b then return nil, e3 end
    local m, e4 = VRFW.rows.open(km)
    if not m then return nil, e4 end
    local model, body, dir = {}, {}, {}
    for _, i in ipairs(b:rows("CHARA_BASE_INFO")) do
      local c, md = b:uint(i, 0), b:uint(i, 6)
      if c and md then model[c] = md end
    end
    for _, i in ipairs(m:rows("CHARA_MODEL_INFO")) do
      local md, bd = m:uint(i, 0), m:uint(i, 4)
      if md and bd and body[md] == nil then body[md] = bd end
    end
    for _, i in ipairs(m:rows("CHARA_BODY_INFO")) do
      local bd = m:uint(i, 0)
      if bd then
        local p = m:str(i, 1)
        local from_path = p and T.starts(p, "_common/") and p:sub(9):match("^([^/]*)") or nil
        local nm = m:str(i, 3)
        local from_name = (nm and nm:sub(1, 1) == "c" and #nm == 7) and nm or nil
        local d = from_path or from_name
        if d then dir[bd] = d end
      end
    end
    return { model = model, body = body, dir = dir }
  end

  function X.talk_chara(r)
    if type(r) == "string" then
      return X.ch.by_name[T.trim(r)] or VRFW.ids.parse(r)
    end
    return T.id(r)
  end

  -- every mod's `[[VRFW.Talk]]` (load order), appended to their chapter files; texts served as new files
  function X.talks(files)
    local out = {}
    local any = false
    for _, f in ipairs(files) do if #(f.value.vrfw.Talk or {}) > 0 then any = true break end end
    if not any then return out end
    local chapters, changed = {}, {}
    if X.D.talk == nil then
      VRFW.log.error("talks: " .. tostring(X.D.talk_err) .. ": no talk is built")
      return out
    end
    local env = env_of(X.D.talk)
    env.rig = VRFW.team.body_rigs()[1]
    local bodies, be = X.talk_bodies()
    if not bodies then
      VRFW.log.warn("talks: character bodies not read (" .. be .. "): every cast member uses the " .. (env.rig or "default rig's") .. " pose packs")
    end
    local used = {}
    X.talk_texts_out = X.talk_texts_out or {}
    -- new talks first, then the ones that take over a talk (a game's, or a mod talk built in the first pass)
    local passes = {}
    for _, f in ipairs(files) do
      for _, d in ipairs(f.value.vrfw.Talk or {}) do
        if d.replace == nil then passes[#passes + 1] = { f, d } end
      end
    end
    for _, f in ipairs(files) do
      for _, d in ipairs(f.value.vrfw.Talk or {}) do
        if d.replace ~= nil then passes[#passes + 1] = { f, d } end
      end
    end
    for _, p in ipairs(passes) do
      local f, d = p[1], p[2]
      local key, e = VRFW.ids.own(f.mod, d.name)
      if not key then
        VRFW.log.error(f.file .. ": talk `" .. d.name .. "`: " .. e .. " (skipped)")
      else
        local what = f.file .. ": talk " .. key
        local target, skip = nil, false
        if d.replace ~= nil then
          local r = T.trim(d.replace)
          if r:find(".", 1, true) then
            local b
            for _, x in ipairs(out) do if x.key == r then b = x break end end
            if b then
              target = { b.id, b.chapter }
            else
              VRFW.log.error(what .. ": replace `" .. r .. "`: no such talk was built (see its errors) (skipped)")
              skip = true
            end
          else
            target = { r, nil }
          end
        end
        if not skip then
          local b, err = X.talk(key, d, chapters, used, bodies, env, target)
          if b then
            VRFW.log.info(string.format("%s: %s in chapter c%d (%d lines)", what, b.id, b.chapter, b.lines))
            changed[b.chapter] = true
            local cue = d.bgm and T.trim(d.bgm) or ""
            if cue ~= "" then
              local ok, be2 = X.talk_bgm(b, cue)
              if ok then
                VRFW.log.info(what .. ": BGM " .. cue .. " from its first line")
              else
                VRFW.log.error(what .. ": bgm `" .. cue .. "`: " .. be2 .. " (the talk plays without it)")
              end
            end
            out[#out + 1] = b
          else
            VRFW.log.error(what .. ": " .. err .. " (skipped)")
          end
        end
      end
    end
    -- a chapter file is served when one of its talks was built (a failed talk's rows only with a built one)
    for ch, t in pairs(chapters) do VRFW.team.rows_serve(t, changed[ch] == true) end
    return out
  end

  function X.talk(key, d, chapters, used, bodies, env, target)
    local motion_of = env.motion_of
    local face_of = env.face_of
    local sc, se = X.talk_scene(d.scene, chapters)
    if not sc then return nil, se end
    local scene_ch, scene_b0, scene_b1 = sc[1], sc[2], sc[3]
    -- `replace`: the talk taken over keeps its name and its chapter file
    if target ~= nil and target[2] == nil then
      local x, xe = X.talk_scene(target[1], chapters)
      if not x then return nil, "replace `" .. target[1] .. "`: " .. xe end
      target = { target[1], x[1] }
    end
    local ch = target and target[2] or (d.chapter or scene_ch)
    local all = K.chapter_numbers()
    if not T.contains(all, ch) then
      return nil, "chapter " .. ch .. " is not one the game indexes at boot (" .. T.dbg_list(all) .. ")"
    end
    if #(d.line or {}) == 0 then return nil, "no [[vrfw.Talk.Line]]" end
    -- the game name
    local t0, te0 = X.talk_chapter(ch, chapters)
    if not t0 then return nil, te0 end
    local existing = {}
    for _, i in ipairs(t0:rows(L_CONFIG)) do
      local x = t0:uint(i, 0)
      if x then existing[x] = true end
    end
    local function taken(n)
      return existing[VRFW.crc32(n)] or used[n] or VRFW.team.key_any(nil, "/event/" .. n .. ".cfg.bin") or VRFW.team.key_any(nil, "/event/" .. n .. "_map.cfg.bin")
    end
    local id
    if target ~= nil then
      id = target[1]
    elseif d.id ~= nil then
      local s = T.trim(d.id)
      if s == "" or #s > 24 or not s:find("^[a-z0-9_]+$") then return nil, "id `" .. s .. "`: a-z 0-9 _, at most 24 characters" end
      if taken(s) then return nil, "id `" .. s .. "` is already a talk of the game or of another mod" end
      id = s
    else
      local n = VRFW.crc32(key) % 10000
      while true do
        local s = "ev" .. ch .. "_9" .. T.pad(n, 4)
        if not taken(s) then id = s break end
        n = (n + 1) % 10000
      end
    end
    used[id] = true
    -- cast
    local members = {}
    local cast = d.cast or {}
    local cast_keys = {}
    for _, c in ipairs(cast) do cast_keys[c.key] = true end
    local voices = {}
    for _, v in ipairs(d.voice or {}) do voices[v.key] = v end
    for _, v in ipairs(d.voice or {}) do
      if v.chara == nil and T.is_empty(v.name) then
        return nil, "voice `" .. v.key .. "`: give `name` (written in front of its lines) or `chara` (the name panel)"
      end
      if v.chara ~= nil then
        local cid = X.talk_chara(v.chara)
        if not X.ch.base[cid] then
          VRFW.log.warn(string.format("talk %s: voice `%s`: %s (%s) is not in chara_base: its name panel may stay empty", key, v.key, T.idref_text(v.chara), T.hex(cid)))
        end
      end
    end
    local function outfit_of(c)
      local o = c.outfit or d.outfit
      o = o and T.trim(o) or "match"
      if o == "offpitch" then return true end
      if o == "match" then return false end
      return nil, "cast `" .. c.key .. "`: outfit `" .. o .. "`: offpitch / match"
    end
    for _, c in ipairs(cast) do
      if voices[c.key] then return nil, "`" .. c.key .. "` is both a cast member and a voice" end
      local cid = X.talk_chara(c.chara)
      if not X.ch.base[cid] then
        VRFW.log.warn(string.format("talk %s: cast `%s`: %s (%s) is not in chara_base: it may not show", key, c.key, T.idref_text(c.chara), T.hex(cid)))
      end
      members[#members + 1] = { key = c.key, slot = c.slot, visible = not c.hidden }
    end
    -- lines → beats
    local beats = {}
    local function idle_of(k)
      local c
      for _, x in ipairs(cast) do if x.key == k then c = x break end end
      local mname = c and (c.idle or c.motion) or "stand"
      return (motion_of(mname))
    end
    local revert = {}
    local function cell(b, k)
      local c = b.cells[k]
      if not c then c = {} b.cells[k] = c end
      return c
    end
    local function settle(b)
      for _, k in ipairs(revert) do
        local c = cell(b, k)
        if c.motion == nil then
          c.motion = idle_of(k)
          c.blend = 0.3
        end
      end
      revert = {}
    end
    local function new_beat(o)
      local b = { speaker = nil, text = {}, wait = 0, fade = 0, fade_time = 0, shake = 0, window = 0, cells = {} }
      for k, v in pairs(o or {}) do b[k] = v end
      return b
    end
    for li, l in ipairs(d.line) do
      local function at(e) return "line " .. li .. ": " .. e end
      local done = false
      if l.action ~= nil then
        local a = T.trim(l.action)
        if a ~= "tackle" then return nil, at("action `" .. a .. "`: known actions: tackle") end
        if l.from == nil then return nil, at("tackle needs `from`") end
        if l.to == nil then return nil, at("tackle needs `to`") end
        local from, to = l.from, l.to
        if not cast_keys[from] then return nil, at("`" .. from .. "` is not a cast member") end
        if not cast_keys[to] then return nil, at("`" .. to .. "` is not a cast member") end
        local to_slot = 0
        for _, mm in ipairs(members) do if mm.key == to then to_slot = mm.slot break end end
        local land = l.to_slot
        if land == nil then
          -- the free back slot on `to`'s side of a 7-slot preset (left 0 / 2 / 5, right 1 / 3 / 6)
          local left = to_slot == 0 or to_slot == 2 or to_slot == 5
          local side = left and { 2, 5, 0 } or { 3, 6, 1 }
          land = to_slot
          for _, s in ipairs(side) do
            local busy = false
            for _, mm in ipairs(members) do if mm.slot == s and mm.visible then busy = true break end end
            if s ~= to_slot and not busy then land = s break end
          end
        end
        -- 1. the run-up
        local b = new_beat { wait = l.wait or 0.4, fade = -1 }
        b.cells[from] = { motion = (motion_of("dash")), blend = 0.1, face = face_of("angry") }
        settle(b)
        beats[#beats + 1] = b
        -- 2. the white flash (retail impact cut)
        beats[#beats + 1] = new_beat { wait = 0.15, fade = 3, fade_time = 0.15 }
        -- 3. the impact: back from white, shake, attacker in the victim's place, victim down
        b = new_beat { wait = 0.9, fade = 0, fade_time = 0.2, shake = l.shake or 0.4 }
        b.cells[from] = { motion = (motion_of("block")), slot = to_slot, face = face_of("angry") }
        b.cells[to] = { motion = (motion_of("knocked_down")), blend = 0.2, slot = land, face = face_of("pain") }
        for _, mm in ipairs(members) do
          if mm.key == from then mm.slot = to_slot elseif mm.key == to then mm.slot = land end
        end
        beats[#beats + 1] = b
        done = true
      end
      if not done then
        local fade
        if l.fade == nil then fade = -1
        else
          local fx = T.trim(l.fade)
          if fx == "in" then fade = 0
          elseif fx == "black_out" then fade = 1
          elseif fx == "white_out" then fade = 3
          else return nil, at("fade `" .. fx .. "`: in / black_out / white_out") end
        end
        local label
        if l.label ~= nil then
          local x = T.trim(l.label)
          if x ~= "" and #x <= 40 and x:find("^[a-z0-9_]+$") then label = x
          else return nil, at("label `" .. x .. "`: a-z 0-9 _, at most 40 characters") end
        end
        local b = new_beat {
          wait = l.speaker ~= nil and 0 or (l.wait or 0.5),
          fade = fade,
          fade_time = l.fade ~= nil and (l.fade_time or 0.2) or 0,
          shake = l.shake or 0,
          window = l.window ~= nil and T.id(l.window) or 0,
          background = l.background ~= nil and bg_of(l.background) or nil,
          camera = l.camera ~= nil and T.id(l.camera) or nil,
          label = label,
        }
        if l.speaker ~= nil then
          local s = l.speaker
          if not cast_keys[s] and not voices[s] then return nil, at("speaker `" .. s .. "` is not a cast member or a voice") end
          if T.is_empty(l.text) then return nil, at("a speaker line needs `text`") end
          b.speaker = s
          b.text = T.copy(l.text)
          if l.motion ~= nil or l.expression ~= nil then
            if not cast_keys[s] then return nil, at("`" .. s .. "` is a voice: no motion / expression") end
            b.cells[s] = { motion = l.motion ~= nil and (motion_of(l.motion)) or nil, face = l.expression ~= nil and face_of(l.expression) or nil }
          end
          -- a hidden member comes on stage with its first line
          for _, mm in ipairs(members) do
            if mm.key == s and not mm.visible then
              mm.visible = true
              cell(b, s).show = true
              break
            end
          end
        elseif not T.is_empty(l.text) then
          return nil, at("text without a speaker")
        end
        for _, k in ipairs(T.keys(l.pose or {})) do
          local p = l.pose[k]
          if not cast_keys[k] then return nil, at("`" .. k .. "` is not a cast member") end
          if p.show == false and l.speaker == k then
            return nil, at("pose." .. k .. ".show = false on its own line: a speaker stays on stage while it speaks")
          end
          local c = cell(b, k)
          if p.motion ~= nil then c.motion = (motion_of(p.motion)) end
          if p.expression ~= nil then c.face = face_of(p.expression) end
          if p.slot ~= nil then c.slot = p.slot end
          if p.blend ~= nil then c.blend = p.blend end
          if p.show ~= nil then c.show = p.show end
          for _, mm in ipairs(members) do
            if mm.key == k then
              if p.slot ~= nil then mm.slot = p.slot end
              if p.show ~= nil then mm.visible = p.show end
              break
            end
          end
        end
        settle(b)
        if l.speaker ~= nil and l.motion ~= nil and not l.hold then revert[#revert + 1] = l.speaker end
        beats[#beats + 1] = b
      end
    end
    -- pose packs per member: the ones its motions need (+ p250, loaded by nearly every retail first row)
    local motions_of = {}
    for _, c in ipairs(cast) do
      local v = {}
      if c.motion ~= nil then v[#v + 1] = c.motion end
      if c.idle ~= nil then v[#v + 1] = c.idle end
      for _, l in ipairs(d.line) do
        if l.speaker == c.key and l.motion ~= nil then v[#v + 1] = l.motion end
      end
      for _, l in ipairs(d.line) do
        local p = l.pose and l.pose[c.key]
        if p and p.motion ~= nil then v[#v + 1] = p.motion end
      end
      for _, l in ipairs(d.line) do
        if l.action == "tackle" and (l.from == c.key or l.to == c.key) then
          v[#v + 1] = "dash"
          v[#v + 1] = "block"
          v[#v + 1] = "knocked_down"
          break
        end
      end
      motions_of[c.key] = v
    end
    -- template rows of the chapter: first placed row of a character (kit, cells 2..6)
    local t = t0
    local CH = X.talk_cols(t)
    local proto_full, proto_keep
    local retail_first = {}
    for k = 1, MAX_CAST do
      for _, i in ipairs(t:rows("EV_BUSTUP_TALK_DATA_CHR_" .. k)) do
        local e = t:entry(i)
        local v = e.values
        local sl = TC.int(v, CH.C_SLOT)
        local placed = sl ~= nil and sl >= 0 and type(v[CH.C_PACK + 1]) == "string"
        if placed then
          if proto_full == nil then proto_full = e end
          local c = TC.uint(v, CH.C_CHARA)
          if c and retail_first[c] == nil then retail_first[c] = e end
        elseif proto_keep == nil and sl == -1 and (TC.uint(v, CH.C_CHARA) or 0) ~= 0 then
          proto_keep = e
        end
      end
    end
    if proto_full == nil then return nil, "the chapter file has no cast row to copy" end
    proto_keep = proto_keep or proto_full
    local n_lists = 0
    for k = 1, MAX_CAST do
      if t:list("EV_BUSTUP_TALK_DATA_CHR_" .. k) then n_lists = n_lists + 1 end
    end
    if #cast <= MAX_CAST and #cast > n_lists then
      return nil, string.format("chapter c%d has %d cast lists, the talk %d cast members", ch, n_lists, #cast)
    end
    local function copy_entry(e)
      return { name = e.name, hash = e.hash, values = TC.copy_row(e.values) }
    end
    -- first rows of the cast
    local first_rows = {}
    local keys_have_chr = VRFW.team.key_any("data/common/chr/", nil)
    for _, c in ipairs(cast) do
      local chara = X.talk_chara(c.chara)
      local tpl = retail_first[chara]
      local body_dir
      if bodies then
        local md = bodies.model[chara]
        local bd = md and bodies.body[md]
        body_dir = bd and bodies.dir[bd]
      end
      body_dir = body_dir or env.rig
      if body_dir == nil then return nil, "no body rig in the game's files (data/common/chr/c000N01/c000N01.g4sk)" end
      local packs = {}
      if #(c.packs or {}) == 0 then
        packs[1] = "p250"
        for _, mname in ipairs(motions_of[c.key] or {}) do
          local _, p = motion_of(mname)
          if p ~= "" and not T.contains(packs, p) then packs[#packs + 1] = p end
        end
      else
        packs = T.acopy(c.packs)
      end
      if #packs > MAX_PACKS then
        return nil, string.format("cast `%s`: its motions need %d pose packs (%s), at most %d: set `packs`", c.key, #packs, table.concat(packs, ", "), MAX_PACKS)
      end
      local paths = {}
      for k, p in ipairs(packs) do
        if p:find("/", 1, true) then paths[k] = T.trim(p)
        else paths[k] = "common/chr/" .. body_dir .. "/" .. body_dir .. "_" .. p .. ".g4pk" end
      end
      for _, p in ipairs(paths) do
        if keys_have_chr and not VRFW.team.key_exists_ci("data/" .. p) then
          VRFW.log.warn(string.format("talk %s: cast `%s`: pose pack %s is not in the game: its motions from it may not play", key, c.key, p))
        end
      end
      local e = copy_entry(tpl or proto_full)
      local v = e.values
      if tpl == nil then
        for _, cv in ipairs { { 2, -1 }, { 3, -1 }, { 4, -1 }, { 5, 0 }, { 6, 0 } } do TC.set(v, cv[1], cv[2]) end
      end
      -- the template row's own extras (attached objects, exits): reset
      for col = 11, 18 do TC.set(v, col, 0) end
      for col = 22, 24 do TC.set(v, col, 0) end
      TC.set(v, CH.C_CHARA, T.i32(chara))
      local offpitch
      local isoff, oe = outfit_of(c)
      if isoff == nil then return nil, oe end
      if isoff then
        offpitch = X.ch.offpitch[chara]
        if offpitch == nil and c.outfit ~= nil then
          VRFW.log.warn(string.format("talk %s: cast `%s`: outfit = offpitch but %s has no off-pitch kit (chara_param evt_offpitch_kit): its usual kit", key, c.key, T.idref_text(c.chara)))
        end
        if offpitch ~= nil and c.kit == nil then
          VRFW.log.info(string.format("talk %s: cast `%s` in its off-pitch kit %s", key, c.key, T.hex(offpitch)))
        end
      end
      local kit = c.kit ~= nil and T.id(c.kit) or offpitch or (tpl and TC.uint(tpl.values, CH.C_KIT)) or 0
      TC.set(v, CH.C_KIT, T.i32(kit))
      for k = 0, MAX_PACKS - 1 do
        TC.set(v, CH.C_PACK + k, paths[k + 1] or 0)
      end
      TC.set(v, CH.C_SLOT, c.slot)
      TC.set(v, CH.C_SPEED, 1)
      TC.set(v, CH.C_MOTION, T.i32((motion_of(c.motion or "stand"))))
      TC.set(v, CH.C_BLEND, -1)
      TC.set(v, CH.C_FACE, T.i32(face_of(c.expression or "serious")))
      -- cells after the face (second face layer, effects) are the template character's own: reset
      for col = CH.C_FACE + 1, #v - 1 do TC.set(v, col, 0) end
      first_rows[#first_rows + 1] = e
    end
    -- entries
    local n_chr = {}
    for k = 1, MAX_CAST do n_chr[k] = #t:rows("EV_BUSTUP_TALK_DATA_CHR_" .. k) end
    local body_rows = t:rows(L_BODY)
    local n_body = #body_rows
    local body_i = body_rows[1]
    if body_i == nil then return nil, "the chapter file has no BODY row" end
    local ref_protos = {}
    do
      local j = body_i + 1
      while j < t:len() do
        local nm = t:name(j)
        if not (nm and T.starts(nm, "EV_BUSTUP_TALK_DATA_BODY_REF_")) then break end
        ref_protos[#ref_protos + 1] = t:entry(j)
        j = j + 1
      end
    end
    local config_i = t:rows(L_CONFIG)[1]
    if config_i == nil then return nil, "the chapter file has no CONFIG row" end
    local config_proto, config_ref = t:entry(config_i), t:entry(config_i + 1)
    local new_chr = {}
    for k = 1, MAX_CAST do new_chr[k] = {} end
    local new_body = {}
    local text_rows, lip_rows = {}, {}
    local label_n = 0
    local on_stage, placed = {}, {}
    local cur = {}
    for mi, c in ipairs(cast) do
      on_stage[mi], placed[mi] = false, false
      cur[mi] = { c.slot, (motion_of(c.motion or "stand")), face_of(c.expression or "serious") }
    end
    local function apply_cell(v, cc)
      if cc.motion ~= nil then
        TC.set(v, CH.C_MOTION, T.i32(cc.motion))
        TC.set(v, CH.C_BLEND, cc.blend ~= nil and { float = cc.blend } or -1)
      end
      if cc.face ~= nil then TC.set(v, CH.C_FACE, T.i32(cc.face)) end
      if cc.slot ~= nil then TC.set(v, CH.C_SLOT, cc.slot) end
    end
    for bi, b in ipairs(beats) do
      local e = copy_entry(bi == 1 and scene_b0 or scene_b1)
      local v = e.values
      for col = 0, #v - 1 do
        if col ~= CH.B_LABEL then TC.set(v, col, 0) end
      end
      TC.set(v, 12, -1)
      TC.set(v, 23, -1)
      if bi == 1 then
        local bg_path, bg_name
        if d.background ~= nil then
          local x = bg_of(d.background)
          bg_path, bg_name = x[1], x[2]
        else
          bg_path = TC.text(scene_b0.values, CH.B_BG_PATH) or ""
          bg_name = TC.text(scene_b0.values, CH.B_BG_NAME) or ""
        end
        if bg_path == "" then return nil, "scene `" .. d.scene .. "` starts with no background: give `background`" end
        TC.set(v, CH.B_PRESET, T.i32(d.camera ~= nil and T.id(d.camera) or (TC.uint(scene_b0.values, CH.B_PRESET) or 0)))
        TC.set(v, CH.B_BG_PATH, bg_path)
        TC.set(v, CH.B_BG_NAME, bg_name)
        TC.set(v, CH.B_LIGHT, TC.int(scene_b0.values, CH.B_LIGHT) or 0)
      end
      if b.camera ~= nil then TC.set(v, CH.B_PRESET, T.i32(b.camera)) end
      if b.background ~= nil then
        TC.set(v, CH.B_BG_PATH, b.background[1])
        TC.set(v, CH.B_BG_NAME, b.background[2])
      end
      local label
      if b.speaker ~= nil then
        label_n = label_n + 1
        label = b.label or (id .. "_010_" .. T.pad(label_n * 10, 3))
      else
        label = NO_TEXT
      end
      TC.set(v, CH.B_TEXT, T.i32(VRFW.crc32(label)))
      TC.set(v, CH.B_LABEL, label)
      TC.set(v, CH.B_WINDOW, T.i32(b.window))
      TC.set(v, CH.B_FADE, b.fade)
      TC.set(v, CH.B_FADE_TIME, f32v(b.fade_time))
      TC.set(v, CH.B_WAIT, f32v(b.wait))
      TC.set(v, CH.B_SHAKE, f32v(b.shake))
      new_body[#new_body + 1] = e
      -- the rows of this line, per cast member (nil = not on stage on this line)
      local member_rows = {}
      for mi, c in ipairs(cast) do
        local cc = b.cells[c.key]
        if cc then
          local s = cur[mi]
          if cc.slot ~= nil then s[1] = cc.slot end
          if cc.motion ~= nil then s[2] = cc.motion end
          if cc.face ~= nil then s[3] = cc.face end
        end
        if cc and cc.show == false then
          -- leaving: no row from this line on
          on_stage[mi] = false
        else
          local enters = not on_stage[mi] and ((bi == 1 and not c.hidden) or (cc ~= nil and cc.show == true))
          if on_stage[mi] or enters then
            local row
            if enters and not placed[mi] then
              on_stage[mi], placed[mi] = true, true
              row = copy_entry(first_rows[mi])
              if cc then apply_cell(row.values, cc) end
            elseif enters then
              -- back on stage: re-placed at its slot in its last motion / expression
              on_stage[mi] = true
              local slot, motion, face = cur[mi][1], cur[mi][2], cur[mi][3]
              row = copy_entry(proto_keep)
              local rv = row.values
              for col = 1, #rv - 1 do TC.set(rv, col, 0) end
              for _, col in ipairs { 2, 3, 4 } do TC.set(rv, col, -1) end
              TC.set(rv, CH.C_CHARA, T.i32(X.talk_chara(c.chara)))
              TC.set(rv, CH.C_SPEED, 1)
              apply_cell(rv, { motion = motion, blend = cc and cc.blend or nil, face = face, slot = slot })
            else
              row = copy_entry(proto_keep)
              local rv = row.values
              for col = 1, #rv - 1 do TC.set(rv, col, 0) end
              for _, col in ipairs { 2, 3, 4 } do TC.set(rv, col, -1) end
              TC.set(rv, CH.C_CHARA, T.i32(X.talk_chara(c.chara)))
              TC.set(rv, CH.C_SLOT, -1)
              TC.set(rv, CH.C_BLEND, -1)
              TC.set(rv, CH.C_SPEED, 1)
              if cc then apply_cell(rv, cc) end
            end
            member_rows[mi] = row
          end
        end
      end
      -- cast lists of this line: a cast of at most 6 keeps member k on list k; a larger cast puts the members on stage on lists 1.. in cast order
      local by_list = {}
      if #cast <= MAX_CAST then
        for mi = 1, #cast do by_list[mi] = member_rows[mi] end
      else
        local on = {}
        for mi = 1, #cast do if member_rows[mi] then on[#on + 1] = member_rows[mi] end end
        if #on > n_lists then
          return nil, string.format("line %d: %d cast members on stage, the chapter has %d cast lists", bi, #on, n_lists)
        end
        for k, r in ipairs(on) do by_list[k] = r end
      end
      -- refs: every list its row of the line, the effects none
      for _, rp in ipairs(ref_protos) do
        local r = copy_entry(rp)
        local nm = r.name or ""
        local k = tonumber(nm:match("^EV_BUSTUP_TALK_DATA_BODY_REF_CHR_(%d+)$") or "")
        if k and k >= 1 and k <= MAX_CAST and by_list[k] then
          local row = by_list[k]
          by_list[k] = nil
          r.values = { n_chr[k] + #new_chr[k], 1 }
          table.insert(new_chr[k], row)
        else
          r.values = { 0, 0 }
        end
        new_body[#new_body + 1] = r
      end
      if b.speaker ~= nil then
        local s = b.speaker
        local sp
        for _, c in ipairs(cast) do if c.key == s then sp = X.talk_chara(c.chara) break end end
        local text = T.copy(b.text)
        -- the line's voice: its own (`none` / `<bank>/<cue>`), else a taken-over talk keeps its game cue
        local voice = b.voice
        if voice == nil and target ~= nil then voice = id .. "/" .. label end
        if sp ~= nil or b.voice ~= nil then lip_rows[#lip_rows + 1] = { label = label, speaker = sp, texts = T.copy(text), voice = voice } end
        local sp_panel = sp
        if sp == nil then
          local vv = voices[s]
          if vv then
            if vv.chara ~= nil then
              -- the name panel names the character; nobody on stage, no mouth to move
              sp_panel = X.talk_chara(vv.chara)
            else
              for _, lg in ipairs(T.keys(text)) do
                local nm = VRFW.lang.pick(vv.name or {}, VRFW.lang.norm(lg) or "en") or s
                text[lg] = nm .. ": " .. text[lg]
              end
            end
          end
        end
        text_rows[#text_rows + 1] = { label = label, speaker = sp_panel, texts = text }
      end
    end
    local n_beats = #beats
    -- splice into the chapter file
    for k = 1, MAX_CAST do
      if #new_chr[k] > 0 then
        local l = "EV_BUSTUP_TALK_DATA_CHR_" .. k
        -- the rows were shaped from rows of any cast list: they take this list's row name
        local h = VRFW.crc32(l)
        local rows = {}
        for j, e in ipairs(new_chr[k]) do rows[j] = { name = l, values = e.values } end
        local n = #rows
        local ok, ae = pcall(t.append_rows, t, l, { l }, rows, n)
        if not ok then return nil, tostring(ae) end
        local _ = h
      end
    end
    local body_names = { L_BODY }
    for _, rp in ipairs(ref_protos) do if rp.name then body_names[#body_names + 1] = rp.name end end
    local ok, ae = pcall(t.append_rows, t, L_BODY, body_names, new_body, n_beats)
    if not ok then return nil, tostring(ae) end
    local ci = target and t:find(L_CONFIG, 0, VRFW.crc32(id)) or nil
    if ci ~= nil then
      -- `replace`: the talk's own CONFIG row points at the new lines (its old lines stay, unreferenced)
      local nm = t:name(ci + 1)
      if not (nm and T.starts(nm, L_CONFIG)) then return nil, "the talk's CONFIG row has no REF_BODY" end
      local r = t:entry(ci + 1)
      r.values = { n_body, n_beats }
      t:splice(ci + 1, ci + 2, { r })
    elseif target ~= nil then
      return nil, "replace: `" .. id .. "` has no CONFIG row in chapter c" .. ch
    else
      local cfg = copy_entry(config_proto)
      TC.set(cfg.values, 0, T.i32(VRFW.crc32(id)))
      local cref = copy_entry(config_ref)
      cref.values = { n_body, n_beats }
      local cref_name = cref.name or ""
      ok, ae = pcall(t.append_rows, t, L_CONFIG, { L_CONFIG, cref_name }, { cfg, cref }, 1)
      if not ok then return nil, tostring(ae) end
    end
    t:touch()
    -- texts (a talk taken over: the files served for it before are replaced)
    if target ~= nil then
      local tails = { "/event/" .. id .. ".cfg.bin", "/event/" .. id .. "_map.cfg.bin" }
      for _, x in ipairs(X.talk_texts_out) do
        if not x.gone and (T.ends(x.key, tails[1]) or T.ends(x.key, tails[2])) then
          VRFW.team.rows_discard(x.t)
          x.gone = true
        end
      end
      VRFW.team.files_drop(nil, tails[1])
      VRFW.team.files_drop(nil, tails[2])
    end
    local tok, tre = X.talk_texts(d.scene, id, text_rows)
    if not tok then return nil, tre end
    local lip = d.lip_sync
    if lip == nil then lip = target == nil end
    -- a line with a voice of its own needs the talk's bank even without lip sync
    local own_voice = false
    for _, l in ipairs(d.line or {}) do if l.voice ~= nil then own_voice = true end end
    if lip or own_voice then
      local vok, ve = VRFW.team.talk_voice(d.scene, id, lip_rows)
      if not vok then VRFW.log.warn("talk " .. key .. ": no lip sync (" .. ve .. "): the mouths stay still") end
    end
    local first_label
    if beats[1].speaker ~= nil then first_label = beats[1].label or (id .. "_010_010") else first_label = NO_TEXT end
    return { key = key, id = id, chapter = ch, lines = n_beats, first_label = first_label }
  end

  -- columns of a chapter file (schemas/event/event_bustup_talk_data_*; fallback numbers when a schema lacks the name)
  function X.talk_cols(t)
    local function c(row, name, n)
      local ok, x = pcall(t.col, t, row, name)
      if ok and x then return x end
      return n
    end
    local B, R = L_BODY, "EV_BUSTUP_TALK_DATA_CHR_1"
    return {
      B_PRESET = c(B, "camera_preset", 0), B_BG_PATH = c(B, "background_path", 1), B_BG_NAME = c(B, "background_name", 2),
      B_TEXT = c(B, "text", 3), B_LABEL = c(B, "label", 4), B_WINDOW = c(B, "window_effect", 6), B_FADE = c(B, "fade", 13),
      B_FADE_TIME = c(B, "fade_time", 14), B_WAIT = c(B, "wait", 19), B_SHAKE = c(B, "shake", 20), B_LIGHT = c(B, "light", 22),
      C_CHARA = c(R, "chara", 0), C_KIT = c(R, "uniform", 1), C_PACK = c(R, "pose_pack_1", 7), C_SLOT = c(R, "preset_slot", 10),
      C_SPEED = c(R, "motion_speed", 19), C_MOTION = c(R, "motion", 20), C_BLEND = c(R, "motion_blend", 21), C_FACE = c(R, "expression", 25),
    }
  end

  -- replace every `row` entry of a `<row>_BEGIN … <row>_END` text table by `rows` (the BEGIN count follows)
  local function replace_rows(t, row, rows)
    local hb = VRFW.crc32(row .. "_BEGIN")
    local bi
    for i = 0, t:len() - 1 do
      if t:hash(i) == hb then bi = i break end
    end
    if bi == nil then return nil, t:key() .. ": no " .. row .. "_BEGIN" end
    local h = VRFW.crc32(row)
    -- drop every `row` entry (last first: the positions before stay)
    for i = t:len() - 1, 0, -1 do
      if t:hash(i) == h then t:splice(i, i + 1, {}) end
    end
    t:splice(bi + 1, bi + 1, rows)
    if (t:width(bi) or 0) > 0 then t:set(bi, 0, #rows) end
    t:touch()
    return true
  end

  -- `text/<lg>/event/<id>.cfg.bin` ×9 and `text/event/<id>_map.cfg.bin`, shaped like the scene's
  function X.talk_texts(scene, id, rows)
    scene = T.trim(scene)
    -- speakers
    local mk = "data/common/text/event/" .. scene .. "_map.cfg.bin"
    local dst = "data/common/text/event/" .. id .. "_map.cfg.bin"
    local m, me = VRFW.team.rows_copy(mk, dst)
    if not m then return nil, me end
    local pm = m:rows("TEXT_WASHA_MAP")[1]
    if pm == nil then VRFW.team.rows_discard(m) return nil, mk .. ": no TEXT_WASHA_MAP row" end
    local proto = m:entry(pm)
    local ents = {}
    for _, r in ipairs(rows) do
      local e = { name = proto.name, hash = proto.hash, values = TC.copy_row(proto.values) }
      TC.set(e.values, 0, T.i32(VRFW.crc32(r.label)))
      TC.set(e.values, 2, T.i32(r.speaker or 0))
      TC.set(e.values, 3, -1)
      TC.set(e.values, 4, 0)
      TC.set(e.values, 5, VRFW.null)
      TC.set(e.values, 15, r.label)
      ents[#ents + 1] = e
    end
    local ok, re = replace_rows(m, "TEXT_WASHA_MAP", ents)
    if not ok then VRFW.team.rows_discard(m) return nil, re end
    X.talk_texts_out[#X.talk_texts_out + 1] = { key = dst, t = m }
    -- lines
    for _, lg in ipairs(VRFW.lang.list()) do
      local k = "data/common/text/" .. lg .. "/event/" .. scene .. ".cfg.bin"
      local out_k = "data/common/text/" .. lg .. "/event/" .. id .. ".cfg.bin"
      local t = VRFW.team.rows_copy(k, out_k)
      if not t then
        local t2, e2 = VRFW.team.rows_copy("data/common/text/" .. X.lang.source .. "/event/" .. scene .. ".cfg.bin", out_k)
        if not t2 then return nil, e2 end
        t = t2
      end
      local pi = t:rows("TEXT_INFO")[1]
      if pi == nil then VRFW.team.rows_discard(t) return nil, k .. ": no TEXT_INFO row" end
      local pr = t:entry(pi)
      local tents = {}
      for _, r in ipairs(rows) do
        local s = VRFW.lang.pick(r.texts, lg) or ""
        s = T.replace(T.replace(s, "\r", ""), "\n", "\\n")
        local e = { name = pr.name, hash = pr.hash, values = TC.copy_row(pr.values) }
        TC.set(e.values, 0, T.i32(VRFW.crc32(r.label)))
        TC.set(e.values, 1, 0)
        TC.set(e.values, 2, s)
        TC.set(e.values, 3, 0)
        tents[#tents + 1] = e
      end
      local ok2, re2 = replace_rows(t, "TEXT_INFO", tents)
      if not ok2 then VRFW.team.rows_discard(t) return nil, re2 end
      X.talk_texts_out[#X.talk_texts_out + 1] = { key = out_k, t = t }
    end
    return true
  end

  -- `[[VRFW.Talk]] bgm`: an event_bustup_talk_sound_data_config CONFIG row (crc32(talk)) plus one BODY row on its first line with the BGM cue (c1)
  function X.talk_bgm(b, cue)
    if not cue:find("^[A-Za-z0-9_]+$") or #cue > 60 then return nil, "a BGM cue name: A-Z a-z 0-9 _" end
    if not X.talk_sound then
      local k, e = X.table_key(SOUND_PREFIX)
      if not k then return nil, e end
      local t, e2 = VRFW.rows.open(k)
      if not t then return nil, e2 end
      -- served whenever it was read
      t:touch()
      X.talk_sound = t
    end
    local t = X.talk_sound
    local tid = VRFW.crc32(b.id)
    if t:find(L_SCONFIG, 0, tid) then return nil, b.id .. " already has sound rows" end
    local bodies = t:rows(L_SBODY)
    -- shapes: a retail row that starts a BGM (c1 a string) and a CONFIG row with its ref
    local proto
    for _, i in ipairs(bodies) do
      if t:str(i, 1) then proto = t:entry(i) break end
    end
    if not proto then return nil, "no retail BGM row to copy" end
    local ci = t:rows(L_SCONFIG)[1]
    if ci == nil then return nil, "no CONFIG row" end
    local cfg, cref = t:entry(ci), t:entry(ci + 1)
    local row = proto
    for col = 0, #row.values - 1 do TC.set(row.values, col, 0) end
    TC.set(row.values, 0, T.i32(VRFW.crc32(b.first_label)))
    TC.set(row.values, 1, cue)
    for col = 1, #cfg.values - 1 do TC.set(cfg.values, col, 0) end
    TC.set(cfg.values, 0, T.i32(tid))
    cref.values = { #bodies, 1 }
    local cref_name = cref.name or ""
    local ok, e = pcall(t.append_rows, t, L_SBODY, { L_SBODY }, { row }, 1)
    if not ok then return nil, tostring(e) end
    ok, e = pcall(t.append_rows, t, L_SCONFIG, { L_SCONFIG, cref_name }, { cfg, cref }, 1)
    if not ok then return nil, tostring(e) end
    t:touch()
    return true
  end

  -- `[VRFW.RouteNode.Cronica] talk` / `talk_after` → the node piece's event row (bustupEventPreSoccer / …PostWinSoccer)
  function X.node_talks(files, nodes, talks)
    for _, f in ipairs(files) do
      for _, d in ipairs(f.value.vrfw.RouteNode or {}) do
        local c = d.cronica
        if c ~= nil and (c.talk ~= nil or c.talk_after ~= nil) then
          local key = VRFW.ids.own(f.mod, d.name)
          if key then
            local what = f.file .. ": route_node " .. key
            local n
            for _, x in ipairs(nodes) do if x.key == key then n = x break end end
            if n then
              if not T.contains(n.difficulties, 1) then
                VRFW.log.warn(what .. ": its talks play only before / after a Crónica (difficulty 1) match, which it does not show")
              end
              for _, pair in ipairs { { "bustupEventPreSoccer", c.talk }, { "bustupEventPostWinSoccer", c.talk_after } } do
                local col, tk0 = pair[1], pair[2]
                if tk0 ~= nil then
                  local tk = tk0:find(".", 1, true) and T.trim(tk0) or (f.mod .. "." .. T.trim(tk0))
                  local b
                  for _, x in ipairs(talks) do if x.key == tk then b = x break end end
                  if not b then
                    VRFW.log.error(what .. ": talk `" .. tk0 .. "` was not built (see its errors): no " .. col)
                  else
                    local ok, e = X.set_piece_talk(n.piece, n.game, col, b.id)
                    if ok then VRFW.log.info(what .. ": " .. col .. " = " .. b.id .. " (" .. tk .. ")")
                    else VRFW.log.error(what .. ": " .. col .. ": " .. e) end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  function X.set_piece_talk(piece, game, col, id)
    local r, pl, el = X.route_lists()
    if not r then return nil, pl end
    local fid, e1 = r:field(pl, "pieceId")
    if not fid then return nil, e1 end
    local fref, e2 = r:field(pl, "eventInfoRef")
    if not fref then return nil, e2 end
    local fg, e3 = r:field(el, "paramCrc1")
    if not fg then return nil, e3 end
    local fc, e4 = r:field(el, col)
    if not fc then return nil, e4 end
    local p = X.piece_row(r, pl, fid, piece)
    if p == nil then return nil, "piece gone" end
    local a, b = r:tuple(pl, p, fref)
    if a == nil then a, b = 0, 0 end
    local j
    for x = a, a + b - 1 do
      if r:u32(el, x, fg) == game then j = x break end
    end
    if j == nil then return nil, "the piece has no event row for its game" end
    r:set_str(el, j, fc, id)
    r:touch()
    X.touched.route = true
    return true
  end
end

return K
