-- Utilities › «Configuración de pasivas» (feature passive_config; docs/game/mechanics/pasivas-configurables.md).
--
-- Every player has 5 passive slots. The player picks which passive some of them hold (the team dock's
-- «Configuración de pasivas», research/grafts/passive_config); the choice is stored per player instance in the save
-- engine blob passive_config.json (per save slot, mod utilities: the same JSON utilities.dll wrote) and applied by
-- the two slot readers of the game (content/game/passive_config.toml):
--
--   * GetTeamPassiveId / IsTeamPassiveUnlocked are answered NATIVELY ([[VRFW.Hook.answer]]): this script fills the
--     lookup tables (VRFW.native.table_*), the detours read them on every call (many per frame), no Lua call there:
--       PassiveConfig.Slots    (save slot, saved owner, slot 0-4) -> passive id    the applied choice (and, with slot
--                                                                                   rules a mod declares, the defaults),
--                                                                                   at the version of the player's rarity
--       PassiveConfig.Own      (param, slot)                    -> passive id    own passives (chara_param 61-65)
--       PassiveConfig.OwnKept  (rarity, slot)                   -> 1             build slots of the build rarities
--       PassiveConfig.Unlock   (save slot, owner, slot)         -> 0 / 1         forced locked / open
--       PassiveConfig.AllOpen  (save slot)                      -> 1             [passives] unlock = "all"
--       PassiveConfig.OwnOpen  (param, slot)                    -> 1             [passives] always_unlocked
--       PassiveConfig.OffMode  (current mode id)                -> 0             [[off_mode]]: no passive at all
--   * the retail commands that read the slots themselves (the plate, the inheritance gate / trash, the archetype
--     getters) are filtered here ([[VRFW.CommandFilter]]), and the screen's commands CMND_BETTERQOL_PC_* are functions here.
--
-- Mods add their own passives with declaration files passive_config\*.toml (mod root, or a feature's
-- content\passive_config\; schema utilities.passive_config/1, lib/pc_core.lua add_decl). Saved data of a slot a mode
-- reserved (INAROGUE) is never touched there: its passives are the mode's.

local C = require "lib/pc_core"

BetterQoL.PassiveConfig = BetterQoL.PassiveConfig or {}
local PC = BetterQoL.PassiveConfig

require "VRFW/lib/basics"
local info, warn, err = VRFW.logger("passive_config")

local N = C.N_SLOTS
local FIELD_BUILD, FIELD_PARAM_BUILD = 36, 20
local DIAMOND_RARITY = 8

local CFG, LAYOUT, RULES, UNLOCK = nil, nil, nil, "configured"
-- the rule of the player's archetype (pc_core player_rule): nil = the game's archetype untouched, else
-- { slots, without, origin }: Utilities' own [player_archetype] (content\passive_config\player_archetype.toml) or a
-- mod's typed [slots] archetype = true. Read once, the same rule for every answer (no second derivation anywhere).
local PLAYER = nil
local CAT, DECL, VALUES = nil, nil, {}
local OWN, POS, BASES = {}, {}, {}
local ROLE_OF_ITEM = {}     -- role badge item id -> staff role (pc_core ROLES) whose passives the catalogue offers
local ROLE_OF_BADGE = {}    -- badge inventory handle -> staff role (false = not a role badge)
local ACTIVE = false
local STORE = nil           -- the active save slot's store
local LIST = nil            -- the list the menu pages through { hdl, slot, category, rarity, ids }
local ROW1 = 0              -- the character of the last plate query for slot 1 (CMND_BETTERQOL_PC_SPECIAL)
-- a watermark scan is due: set when the store is loaded and on every slot, mode or match event (archetype mode)
local WATERMARK_DUE, LAST_SEQ = true, -1
local INACTIVE_LOGGED = {}
local LOGGED_ANSWER = {}    -- last logged plate / archetype answer per query key (log on change only)
local BUF

-- ---------------------------------------------------------------------------------------------- arguments

local function arg_u32(v)
  if type(v) ~= "number" then return nil end
  return C.u32(v)
end

local function arg_int(v)
  if type(v) ~= "number" then return nil end
  return v >= 0 and math.floor(v) or math.ceil(v)
end

-- a 0-based slot argument 0..4 → the 1-based slot
local function arg_slot(v)
  local s = arg_int(v)
  if s and s >= 0 and s < N then return s + 1 end
  return nil
end

-- ---------------------------------------------------------------------------------------------- tables

local function load_tables()
  local d = C.new_decl()
  local files = VRFW.files.declarations({ "passive_config", "content/passive_config", "features/*/content/passive_config" })
  for _, f in ipairs(files) do
    local w, why = C.add_decl(d, f.mod, f.data)
    if w then
      info("declarations: mod " .. f.mod .. ": " .. f.file)
      for _, x in ipairs(w) do info("declarations: " .. f.mod .. "/" .. f.file .. ": " .. x) end
    else
      info("declarations: " .. f.mod .. "/" .. f.file .. ": " .. why .. " (file ignored)")
    end
  end
  -- the mods' declared archetypes (VRFW.archetype/1): their numbers and passives (docs/framework/archetype.md §7)
  local archetype_of, n_custom = {}, 0
  local oka, afiles = pcall(VRFW.files.declarations, "content/archetypes")
  for _, f in ipairs(oka and type(afiles) == "table" and afiles or {}) do
    local arr = (type(f.data) == "table" and type(f.data.VRFW) == "table" and f.data.VRFW.Archetype) or {}
    for _, a in ipairs(arr) do
      local n = tonumber(a.number)
      if n and n == math.floor(n) and type(a.name) == "string" and C.register_archetype(n, tostring(f.mod) .. "." .. a.name) then
        n_custom = n_custom + 1
        for _, p in ipairs(type(a.passives) == "table" and a.passives or {}) do
          local id = C.id_of(p)
          if id then archetype_of[id] = n end
        end
      end
    end
  end
  if n_custom > 0 then
    local names = {}
    for n in pairs(C.CUSTOM) do names[#names + 1] = n .. " " .. C.ARCH_NAMES[n] end
    table.sort(names)
    info("declared archetype(s): " .. table.concat(names, ", "))
  end
  -- chara_param: cols 0 (id), 1 (chara_base), 3 (main position), 61-65 (own passives)
  local ck = "data/common/gamedata/character/chara_param_*.cfg.bin"
  local rows = VRFW.table.raw(ck, "CHARA_PARAM_INFO", { 1, 2, 4, 62, 63, 64, 65, 66 })
  local own, pos, bases, n_rows, n_own, own_ids = {}, {}, {}, 0, 0, {}
  for _, r in ipairs(rows) do
    n_rows = n_rows + 1
    if type(r[1]) == "number" then
      local id = C.u32(r[1])
      if type(r[4]) == "number" then pos[id] = r[4] end
      if type(r[2]) == "number" then bases[id] = C.u32(r[2]) end
      if r[62] ~= nil and own[id] == nil then
        local s, any = {}, false
        for k = 1, N do
          s[k] = type(r[61 + k]) == "number" and C.u32(r[61 + k]) or 0
          any = any or s[k] ~= 0
        end
        if any then
          own[id] = s
          n_own = n_own + 1
          for k = 1, N do
            if s[k] ~= 0 then own_ids[s[k]] = true end
          end
        end
      end
    end
  end
  rows = nil
  -- passive_skill_config (entries in file order: an INFO row is followed by its REF_EFFECT slice)
  local pk = "data/common/gamedata/skill/passive_skill_config_*.cfg.bin"
  local ents = VRFW.table.entries(pk, { "PASSIVE_SKILL_EFFECT", "PASSIVE_SKILL_INFO", "PASSIVE_SKILL_INFO_REF_EFFECT" }, false)
  local effects, raws = {}, {}
  for _, e in ipairs(ents) do
    if e.name == "PASSIVE_SKILL_EFFECT" then
      effects[#effects + 1] = { C.u32(tonumber(e[1]) or 0), tonumber(e[2]) or 0 }
    end
  end
  for i, e in ipairs(ents) do
    if e.name == "PASSIVE_SKILL_INFO" and type(e[1]) == "number" then
      local r = { id = C.u32(e[1]), kind = tonumber(e[5]) or 0, key = type(e[7]) == "string" and e[7] or "", defs = {}, value = 0 }
      for j = i + 1, math.min(i + 2, #ents) do
        local x = ents[j]
        if x.name == "PASSIVE_SKILL_INFO_REF_EFFECT" then
          local off, cnt = tonumber(x[1]) or 0, tonumber(x[2]) or 0
          for k = 0, cnt - 1 do
            local ef = effects[off + k + 1]
            if ef then
              if k == 0 then r.value = ef[2] end
              r.defs[#r.defs + 1] = ef[1]
            end
          end
          break
        end
      end
      raws[#raws + 1] = r
    end
  end
  ents = nil
  if #raws == 0 then error("passive_skill_config: no PASSIVE_SKILL_INFO rows") end
  -- passive_skill_effect_config: definition → category, archetype icons, basic effects
  local ek = "data/common/gamedata/soccer/passive_skill_effect_config_*.cfg.bin"
  local defs, cur, n_defs = {}, nil, 0
  local dents = VRFW.table.entries(ek, { "PASSIVE_SKILL_EFFECT_INFO", "PASSIVE_SKILL_EFFECT_INFO_EFFECT_DATA", "PASSIVE_SKILL_EFFECT_INFO_GRAND_TOTAL_INFO_BUILD_TYPE_ICON_DATA", "PASSIVE_SKILL_EFFECT_INFO_LIST_END" })
  for _, e in ipairs(dents) do
    if e.name == "PASSIVE_SKILL_EFFECT_INFO" then
      local id = C.u32(tonumber(e[1]) or 0)
      defs[id] = { category = math.min(math.max(tonumber(e[2]) or 0, 0), 255), builds = {}, effects = {} }
      n_defs = n_defs + 1
      cur = id
    elseif e.name == "PASSIVE_SKILL_EFFECT_INFO_EFFECT_DATA" then
      if cur and type(e[1]) == "number" then table.insert(defs[cur].effects, C.u32(e[1])) end
    elseif e.name == "PASSIVE_SKILL_EFFECT_INFO_GRAND_TOTAL_INFO_BUILD_TYPE_ICON_DATA" then
      if cur and type(e[1]) == "number" and e[1] >= 0 and e[1] < C.N_ARCHETYPES then table.insert(defs[cur].builds, e[1]) end
    elseif e.name == "PASSIVE_SKILL_EFFECT_INFO_LIST_END" then
      cur = nil
    end
  end
  dents = nil
  if n_defs == 0 then error("passive_skill_effect_config: no PASSIVE_SKILL_EFFECT_INFO rows") end
  -- «Recompensas»: basic effect ids of the reward handlers (soccer_basic_effect_config, else the declared ids)
  local rewards, basic_from = nil, "not readable: the declared reward effect ids"
  local bk = "data/common/gamedata/soccer/soccer_basic_effect_config_*.cfg.bin"
  local ok, list = pcall(VRFW.table.raw, bk, "m_soccerBasicEffectInfoList")
  if ok and type(list) == "table" then
    local function first(v)
      if type(v) == "table" then v = v[1] end
      return type(v) == "number" and C.u32(v) or nil
    end
    local set, n = {}, 0
    for _, r in ipairs(list) do
      local b, f = first(r[1]), first(r[2])
      if b and f and d.reward_funcs[f] then set[b] = true; n = n + 1 end
    end
    if n > 0 then
      rewards = set
      basic_from = "soccer_basic_effect_config (" .. n .. " reward effect(s))"
    end
  end
  rewards = rewards or d.reward_effects
  local offer = { mods = {}, exclusive = C.exclusive(d, own_ids), rewards = rewards, archetype_of = archetype_of }
  for id in pairs(d.passives) do offer.mods[id] = true end
  local cat = C.build_catalog(raws, defs, offer)
  for _, id in ipairs(C.set_shared_specials(cat, d.shared_specials)) do
    warn(string.format("declared shared special 0x%08X is not a passive of passive_skill_config (ignored)", id))
  end
  for _, id in ipairs(C.set_restricted_specials(cat, d.restricted_specials)) do
    warn(string.format("declared special 0x%08X is not a passive of passive_skill_config (ignored)", id))
  end
  -- the staff roles' passives: the passives of the items their role equips (item_config ITEM_SPECIAL_SKILL_INFO:
  -- col 0 id, col 6 item kind, col 16 the passive)
  local role_of_kind, staff_ids, role_of_item = {}, {}, {}
  for role, r in pairs(C.ROLES) do
    role_of_kind[r.item_kind] = role
    staff_ids[role] = {}
  end
  local oki, items = pcall(VRFW.table.raw, "data/common/gamedata/item/item_config_*.cfg.bin", "ITEM_SPECIAL_SKILL_INFO", { 1, 7, 17 })
  if oki and type(items) == "table" then
    for _, r in ipairs(items) do
      local role = type(r[7]) == "number" and role_of_kind[r[7]] or nil
      if role and type(r[17]) == "number" and r[17] ~= 0 then table.insert(staff_ids[role], C.u32(r[17])) end
    end
  else
    warn("item_config not readable: coaches and managers keep their equipped passives (" .. tostring(items) .. ")")
  end
  -- rarity versions of the passives (m_passiveSkillRarityTableList idList[0..5], keyed by idList[0]): the grade a
  -- staff card gets from his rarity
  local versions = {}
  local okv, vrows = pcall(VRFW.table.raw, "data/common/gamedata/skill/passive_skill_rarity_table_config_*.cfg.bin", "m_passiveSkillRarityTableList")
  if okv and type(vrows) == "table" then
    for _, r in ipairs(vrows) do
      local l = r.idList or r[1]
      if type(l) == "table" and type(l[1]) == "number" and l[1] ~= 0 then
        local row = {}
        for i = 1, 6 do row[i] = type(l[i]) == "number" and C.u32(l[i]) or 0 end
        if versions[row[1]] == nil then versions[row[1]] = row end
      end
    end
  else
    warn("passive_skill_rarity_table not readable (" .. tostring(vrows) .. "): staff passives at their base value")
  end
  C.set_versions(cat, versions)
  local staff_log = {}
  for role, r in pairs(C.ROLES) do
    local unknown = C.set_staff(cat, role, staff_ids[role])
    if #unknown > 0 then warn(string.format("%d %s passive(s) of item_config are not match passives (not offered)", #unknown, r.name)) end
    if C.staff_count(cat, role) > 0 then role_of_item[C.id_of(r.badge)] = role end
    staff_log[#staff_log + 1] = string.format("%s %d at rarity 4, %d at Diamante (of %d items)", r.name, #(C.staff_list(cat, role, 4)),
      #(C.staff_list(cat, role, C.BASARA_RARITY)), #staff_ids[role])
  end
  ROLE_OF_ITEM, ROLE_OF_BADGE = role_of_item, {}
  info("staff passives: " .. table.concat(staff_log, ", "))
  local values = {}
  for _, r in ipairs(raws) do
    if #r.defs > 0 then values[r.id] = r.value end
  end
  local missing = {}
  for id in pairs(d.passives) do
    if not cat.by_id[id] then missing[#missing + 1] = string.format("0x%08X", id) end
  end
  if #missing > 0 then
    table.sort(missing)
    warn("declared passives not in passive_skill_config: " .. table.concat(missing, ", ") .. " (not offered; is the mod that adds them installed whole?)")
  end
  local rules = d.slots or C.default_rules()
  local unlock = rules.unlock
  if (CFG.unlock or "") ~= "" then
    unlock = C.parse_unlock(CFG.unlock)
    if not unlock then
      warn(string.format("[passives] unlock = %q unknown (all | configured): using %s", tostring(CFG.unlock), rules.unlock))
      unlock = rules.unlock
    end
  end
  CAT, DECL, VALUES, OWN, POS, BASES, RULES, UNLOCK = cat, d, values, own, pos, bases, rules, unlock
  PLAYER = C.player_rule(rules, d.player_archetype)
  LAYOUT = C.with_order(LAYOUT, rules.order)
  info("slot rules: " .. C.describe(rules))
  info("player archetype: " .. C.describe_player_rule(PLAYER))
  local general, n_by_id, rewards_n = 0, 0, 0
  for _ in pairs(cat.by_id) do n_by_id = n_by_id + 1 end
  for _, id in ipairs(cat.list) do
    if cat.by_id[id].archetype == nil then general = general + 1 end
    if cat.by_id[id].category == C.CAT_REWARD then rewards_n = rewards_n + 1 end
  end
  local per = {}
  for a = 0, C.N_ARCHETYPES - 1 do per[#per + 1] = C.ARCH_NAMES[a] .. " " .. #C.archetype_defaults(cat, a) end
  local n_ex = 0
  for _ in pairs(cat.exclusive) do n_ex = n_ex + 1 end
  local sp = {}
  for _, x in ipairs(cat.specials) do sp[#sp + 1] = string.format("%08X", x) end
  info(string.format("tables: chara_param (%d rows, %d with own passives), passive_skill_config, passive_skill_effect_config, soccer_basic_effect_config %s",
    n_rows, n_own, basic_from))
  info(string.format("%d match passives, %d offered (%d general of which %d «Recompensas», %d archetype: %s), %d mod passive(s) declared, %d exclusive not offered, shared specials [%s], restricted %d; unlock %s; max %d slot(s); store blob %s per save slot",
    n_by_id, #cat.list, general, rewards_n, #cat.list - general, table.concat(per, ", "), d.n_passives, n_ex, table.concat(sp, ", "), #cat.restricted, unlock, LAYOUT.max, C.BLOB))
end

-- ---------------------------------------------------------------------------------------------- characters

local function mode_slot()
  local s = VRFW.slots.active()
  return VRFW.slots.reserved(s) == true
end

-- the saved character behind a handle: itself (kinds 0 and 7) or the owner of a match copy
local function owner_of(hdl)
  if hdl == nil or hdl == 0 or C.list_index(hdl) then return nil end
  local k = C.kind_of_handle(hdl)
  if k == 0 or k == 7 then return hdl end
  if k >= 0xD or k == 6 then return nil end
  return VRFW.chara.owner(hdl)
end

local function record(hdl)
  local ok, r = pcall(VRFW.chara.record, hdl)
  if ok then return r end
  return nil
end

local function extra(rec)
  local ok, x = pcall(VRFW.mem.struct, "PassiveCharaRecord", rec.addr)
  if not ok then return 0, 0, 0 end
  local okb, badge = pcall(function() return x.badge end)
  local okr, b1 = pcall(function() return x.build end)
  local okd, b2 = pcall(function() return x.diamond_build end)
  return okb and badge or 0, okr and b1 or 6, okd and b2 or 6
end

-- the staff role of a badge (its inventory handle -> the item it holds), nil = no role whose passives are offered
local function role_of_badge(badge)
  if badge == 0 or next(ROLE_OF_ITEM) == nil then return nil end
  local known = ROLE_OF_BADGE[badge]
  if known ~= nil then return known or nil end
  if not VRFW.is_on("Board.InvRecord") then return nil end
  local ok, p = pcall(function()
    local items = VRFW.game.utilities_inventory()
    if not items or items < 0x10000 then return nil end
    return VRFW.call("Board.InvRecord", items, badge)
  end)
  if not ok or not p or p < 0x10000 then return nil end
  local okr, item = pcall(VRFW.mem.read, "u32", p + 4)
  if not okr or not item then return nil end
  local role = ROLE_OF_ITEM[item] or false
  ROLE_OF_BADGE[badge] = role
  return role or nil
end

-- own passive of (handle, slot 1-5): id, param — or nil
local function own_for(hdl, k)
  if next(OWN) == nil or k < 1 or k > N then return nil end
  local rec = record(hdl)
  if not rec then return nil end
  local own = OWN[rec.param]
  if not own then return nil end
  local badge = extra(rec)
  local id = C.slot_override(CFG, own, k, rec.rarity or 0, badge)
  if id then return id, rec.param end
  return nil
end

local function rarity_of(hdl)
  local rec = record(hdl)
  return rec and rec.rarity or 0
end

-- the engine's slot (the hook's original: never our answer)
local function engine_slot(hdl, k, copy)
  VRFW.mem.write("u32", BUF, 0)
  if not pcall(VRFW.hook.original, "GetTeamPassiveId", BUF, hdl, k - 1, copy or 0) then return 0 end
  return VRFW.mem.read("u32", BUF)
end

-- the five slots before the configurator: the own passive of a slot or the engine's id
local function base_slots(hdl, copy)
  local out = {}
  for k = 1, N do
    out[k] = own_for(hdl, k) or engine_slot(hdl, k, copy)
  end
  return out
end

local function resolve_version(id, rarity)
  if id == 0 or not VRFW.is_on("Passive.RarityVersion") then return id end
  local out, idb = VRFW.mem.buffer("pc_rv_out", 8), VRFW.mem.buffer("pc_rv_id", 4)
  VRFW.mem.write("ptr", out, 0)
  VRFW.mem.write("u32", idb, id)
  if not pcall(VRFW.call, "Passive.RarityVersion", out, idb, rarity) then return id end
  local p = VRFW.mem.read("ptr", out)
  if p and p >= 0x10000 then
    local ok, v = pcall(VRFW.mem.read, "u32", p)
    if ok and v and v ~= 0 then return v end
  end
  return id
end

-- the version of a passive the player's rarity gets, as the game's own slots hold it (teamPassiveInfo keeps the
-- rarity version, so readers that do not resolve it again see the right grade); per (id, rarity), the game's resolver
local VERSION_AT = {}
local function applied_version(id, rarity)
  if id == 0 then return 0 end
  local key = id * 256 + (rarity or 0)
  local v = VERSION_AT[key]
  if v == nil then
    v = resolve_version(id, rarity or 0)
    VERSION_AT[key] = v
  end
  return v
end

local function value_of(id)
  return VALUES[id] or 0
end

local function unlocked_retail(hdl, k)
  local ok, v = pcall(VRFW.hook.original, "IsTeamPassiveUnlocked", hdl, k - 1, 0)
  if not ok then return true end
  return v ~= 0
end

-- ---------------------------------------------------------------------------------------------- store

local function save_store()
  if not STORE then return end
  if STORE.unread then
    -- the blob could not be read (the save engine not ready?): never replace it with an empty store
    err(string.format("slot %d: %s was not readable: the change is not written (retried at the next read)", STORE.slot, C.BLOB))
    return false, "not readable"
  end
  local ok, where = VRFW.save.blob_write(C.BLOB, VRFW.json.encode(C.store_doc(STORE), true), STORE.slot)
  if not ok then err("cannot write the store: " .. tostring(where)) end
  return ok, where
end

local function load_store(slot)
  local text, why = VRFW.save.blob(C.BLOB, slot)
  local st
  if text == nil and why == nil then
    st = C.new_store(slot)
  elseif text == nil then
    -- a read error (not a bad file): nothing is set aside; read again next time, never written over
    err(string.format("slot %d %s: %s (read again later)", slot, C.BLOB, tostring(why)))
    st = C.new_store(slot)
    st.unread = VRFW.now()
    return st
  else
    local doc, e = nil, why
    if text then doc, e = VRFW.json.decode(text) end
    if doc then st, e = C.store_from(doc, slot) end
    if not st then
      local kept = VRFW.save.blob_aside(C.BLOB, slot)
      err(string.format("slot %d %s: %s; kept as %s; starting empty", slot, C.BLOB, tostring(e), tostring(kept)))
      return C.new_store(slot)
    end
  end
  local renamed = C.remap(st, DECL and DECL.aliases or {})
  if renamed > 0 then
    STORE = st
    local ok, where = save_store()
    if ok then
      info(string.format("slot %d: %d saved choice(s) of renamed passives moved to their current ids (%s)", slot, renamed, tostring(where)))
    end
  end
  local inactive, players = 0, 0
  local all_open = { true, true, true, true, true }
  for _, e in pairs(st.players) do
    players = players + 1
    inactive = inactive + #C.inactive(LAYOUT, e.slots, all_open)
  end
  info(string.format("slot %d: %d configured players, watermark %s%s", slot, players, st.watermark and ("get_order " .. st.watermark) or "not set yet",
    inactive > 0 and string.format("; %d configured passive(s) beyond [passives] max_slots = %d kept stored but INACTIVE (raise max_slots to use them again)", inactive, LAYOUT.max) or ""))
  return st
end

-- the store of the active save slot (reloaded when the slot changed), the watermark set once (archetype mode)
local function ensure_store()
  local slot = VRFW.slots.active()
  if not STORE or STORE.slot ~= slot or (STORE.unread and VRFW.now() - STORE.unread > 2000) then
    STORE = load_store(slot)
    WATERMARK_DUE = true
  end
  if not WATERMARK_DUE or STORE.watermark ~= nil or mode_slot() or not C.archetype_mode(RULES) then return end
  WATERMARK_DUE = false
  local v = VRFW.chara.saved()
  if #v == 0 then return end
  local max = 0
  for _, r in ipairs(v) do max = math.max(max, r.get_order or 0) end
  STORE.watermark = max
  local ok, where = save_store()
  if ok then
    info(string.format("slot %d: watermark get_order %d (%d saved characters): they keep their old archetype as 2 archetype passives; players obtained later start without archetype (%s)", slot, max, #v, tostring(where)))
  end
end

-- ---------------------------------------------------------------------------------------------- player view

local function probe(hdl)
  local owner = owner_of(hdl)
  if not owner then return nil end
  local rec = record(owner)
  if not rec then return nil end
  local badge, b1, b2 = extra(rec)
  local rarity = rec.rarity or 0
  local rolled = (rarity == DIAMOND_RARITY) and b2 or b1
  if rolled >= C.N_ARCHETYPES then rolled = nil end
  local role = role_of_badge(badge)
  local card = mode_slot() and C.BLOCKED or C.card_of(rarity, badge, role)
  local special = own_for(owner, 1) or 0
  return { owner = owner, param = rec.param, rarity = rarity, card = card, role = role, rolled = rolled, get_order = rec.get_order or 0,
    main_position = POS[rec.param] or 0, special = special, who = { rec.param, BASES[rec.param] or 0 } }
end

local function subject(pr, base, old)
  return { card = pr.card, role = pr.role, rarity = pr.rarity, base = base, rolled = pr.rolled, old = old, main_position = pr.main_position, special = pr.special, who = pr.who }
end

local function open_of(pr)
  return C.open_slots(RULES, pr.card, pr.rarity)
end

local function active_of(pr, cfgd)
  if not cfgd then return {} end
  return C.active(LAYOUT, cfgd, open_of(pr))
end

local function note_inactive(pr, cfgd)
  local off = C.inactive(LAYOUT, cfgd, open_of(pr))
  if #off == 0 then return end
  local key = STORE.slot .. ":" .. pr.owner
  if INACTIVE_LOGGED[key] then return end
  INACTIVE_LOGGED[key] = true
  info(string.format("chara 0x%08X: slot(s) %s configured but inactive ([passives] max_slots = %d): kept stored, their defaults are used", pr.owner, table.concat(off, ", "), LAYOUT.max))
end

-- (probe, current slots, configured slots as stored, defaults) of a character
local function view_full(hdl, copy)
  if not ACTIVE then return nil end
  local pr = probe(hdl)
  if not pr then return nil end
  local base = base_slots(hdl, copy)
  if pr.card == C.BLOCKED then return pr, base, nil, base end
  ensure_store()
  local cfgd = C.store_get(STORE, pr.owner, pr.param)
  local s = subject(pr, base, C.is_old(STORE, pr.get_order))
  local def = C.default_slots(CAT, s, RULES)
  if cfgd then note_inactive(pr, cfgd) end
  return pr, C.effective(CAT, s, cfgd, LAYOUT, RULES), cfgd, def
end

local function view(hdl, copy)
  local pr, eff, cfgd = view_full(hdl, copy)
  return pr, eff, cfgd
end

-- ---------------------------------------------------------------------------------------------- native tables

local T_SLOTS, T_OWN, T_KEPT, T_UNLOCK, T_ALL, T_OWN_OPEN =
  "PassiveConfig.Slots", "PassiveConfig.Own", "PassiveConfig.OwnKept", "PassiveConfig.Unlock", "PassiveConfig.AllOpen", "PassiveConfig.OwnOpen"

-- ---------------------------------------------------------------------------------------------- modes without passives
-- [[off_mode]] mode = "<key>" in any mod's declaration file: while that mode is the current mode, every slot of every
-- player reads «no passive» (the slot readers' first answers, keyed by the current mode id) and the plate rows hide.
-- Nothing in the store changes: outside the mode the configuration applies as before.

local T_OFF = "PassiveConfig.OffMode"
local OFF_KEYS = {}         -- mode key -> declaring mod
local OFF_IDS = {}          -- mode id (this session) -> mode key
local OFF_FILLED = 0        -- how many keys have an id in T_OFF
local OFF_SIGNATURE = nil   -- the ids last written to T_OFF

local function load_off_modes()
  local files = VRFW.files.declarations({ "passive_config", "content/passive_config", "features/*/content/passive_config" })
  for _, f in ipairs(files) do
    local keys, w = C.off_modes(f.data)
    for _, x in ipairs(w) do warn("declarations: " .. f.mod .. "/" .. f.file .. ": " .. x) end
    for _, k in ipairs(keys) do
      if OFF_KEYS[k] == nil then OFF_KEYS[k] = f.mod end
    end
  end
end

-- the ids of the off modes (known once the mode service registered the keys; retried on every mode change)
local function fill_off_modes()
  local entries, ids, n, total, sig = {}, {}, 0, 0, {}
  for k in pairs(OFF_KEYS) do
    total = total + 1
    local id = tonumber(VRFW.state.get("mode.id." .. k))
    if id and id ~= 0 then
      ids[id] = k
      entries[#entries + 1] = { { id }, 0 }
      sig[#sig + 1] = k .. "=" .. id
      n = n + 1
    end
  end
  table.sort(sig)
  local signature = table.concat(sig, ",")
  if signature == OFF_SIGNATURE then return end
  OFF_SIGNATURE = signature
  VRFW.native.table_replace(T_OFF, nil, entries)
  OFF_IDS, OFF_FILLED = ids, n
  if total > 0 then
    local names = {}
    for id, k in pairs(ids) do names[#names + 1] = string.format("%s (%s, id %d)", k, OFF_KEYS[k], id) end
    table.sort(names)
    info(string.format("player passives off in %d of %d declared mode(s): %s", n, total, n > 0 and table.concat(names, ", ") or "none known yet"))
  end
end

-- a declared off mode is the current mode: the game_state key BetterQoL.passives_off (content/game/passive_config.toml),
-- the one test every reader uses
local function passives_off()
  if OFF_FILLED == 0 then return false end
  local ok, v = pcall(VRFW.state.get, "BetterQoL.passives_off")
  return ok and tonumber(v) == 1
end

-- a framework signature-only mode runs (vrfw.passive.slots_off): the 5 slots are empty, the custom passive slot stays
local function slots_off()
  local ok, v = pcall(VRFW.state.get, "vrfw.passive.slots_off")
  return ok and tonumber(v) == 1
end

-- the slot rules need every saved player's slots in the tables (a special slot holds his own special, the archetype
-- mode derives defaults), not only the configured ones
local function rules_touch_everyone()
  return C.special_slot(RULES) ~= nil or C.archetype_mode(RULES)
end

-- the static tables: own passives (by param), the build slots they leave alone
local function fill_static()
  local own, kept, open = {}, {}, {}
  for param, s in pairs(OWN) do
    for k = 1, N do
      if s[k] ~= 0 then
        own[#own + 1] = { { param, k - 1 }, s[k] }
        if CFG.always_unlocked then open[#open + 1] = { { param, k - 1 }, 1 } end
      end
    end
  end
  for _, r in ipairs(CFG.build_rarities) do
    for _, k in ipairs(CFG.build_slots) do
      if k >= 1 and k <= N then kept[#kept + 1] = { { r, k - 1 }, 1 } end
    end
  end
  -- OwnKept first: the own answer's condition reads it
  VRFW.native.table_replace(T_KEPT, nil, kept)
  VRFW.native.table_replace(T_OWN, nil, own)
  VRFW.native.table_replace(T_OWN_OPEN, nil, open)
  info(string.format("native tables: %d own passive slot(s) of %d card(s), %d kept build slot(s)%s", #own, (function() local n = 0 for _ in pairs(OWN) do n = n + 1 end return n end)(), #kept,
    CFG.always_unlocked and ", own slots always unlocked" or ""))
end

-- the entries of one saved player (slot entries + unlock entries) into `slots` / `unlock`
-- false = the character's record cannot be read now (nothing computed); true = `slots` / `unlock` hold his entries
local function player_entries(S, hdl, slots, unlock)
  local pr, eff, cfgd = view(hdl, 0)
  if not pr then return false end
  if pr.card == C.BLOCKED or pr.owner ~= hdl then return true end
  local act = active_of(pr, cfgd)
  -- a coach / manager keeps his equipped passives in the slots he did not configure
  local everyone = rules_touch_everyone() and pr.card ~= C.STAFF
  for k = 1, N do
    local applied = cfgd and act[k] and C.kind_accepts(CAT, subject(pr, eff, false), RULES, k, cfgd[k])
    if everyone or applied then
      slots[#slots + 1] = { { S, hdl, k - 1 }, applied_version(eff[k], pr.rarity) }
    end
    if C.kind(RULES, k) == C.SPECIAL and not C.slot_open(RULES, pr.card, pr.rarity, k) and eff[k] == 0 then
      unlock[#unlock + 1] = { { S, hdl, k - 1 }, 0 }
    elseif (UNLOCK == "all" and eff[k] ~= 0 and (applied or everyone)) or (UNLOCK == "configured" and act[k]) then
      unlock[#unlock + 1] = { { S, hdl, k - 1 }, 1 }
    end
  end
  return true
end

-- The tables of the active save slot are kept INCREMENTALLY (2026-10-11: a full rebuild on every mode_enter /
-- mode_leave computed the view of every saved player, used up the 5M-instruction budget and held the scripts lock
-- ~275 ms). Per save slot a cache keeps each player's signature: his record (param, rarity, level, get_order), his
-- badge / builds and the engine's five slots. A scan (cheap: no view) queues only the players whose signature changed
-- (new, changed or not seen yet) and drops the entries of players gone; the queue is worked off in time slices: up to
-- SLICE_MS per mode / match trigger, up to SLICE_GAME_MS at most every PUMP_EVERY_MS from the commands on the game
-- thread. A changed choice (set / reset / clear) rewrites that player at once. The cache restarts when the slot's
-- store is read again or its watermark is set (both change every player's defaults).
-- A player whose record cannot be read at that moment (the game reading / writing the save around a match) keeps the
-- entries he had: they are rewritten only from a readable record, and he is scanned again (RETRY_EVERY_MS from the
-- commands, every mode / match trigger). Every trigger scans (match_end too: a Chronicle match changes no mode).
local SLICE_MS, SLICE_GAME_MS, PUMP_EVERY_MS, RETRY_EVERY_MS = 40, 3, 100, 1000
local RETRY = false         -- a player could not be written: scan again
local LAST_RETRY = 0
local UNREADABLE_LOGGED = 0
local CACHE = {}            -- [save slot] = { store, wm, sig = {hdl -> signature}, todo = {}, head, tail, queued = {}, done, why }
local LAST_PUMP = -PUMP_EVERY_MS
local PUMPING = false       -- a game-thread command nested in a parked mode handler leaves the queue to it

local function clear_player(S, hdl)
  for k = 0, N - 1 do
    VRFW.native.table_set(T_SLOTS, { S, hdl, k }, nil)
    VRFW.native.table_set(T_UNLOCK, { S, hdl, k }, nil)
  end
end

-- what a player's entries depend on besides the store and the static tables
local function signature(hdl)
  local rec = record(hdl)
  if not rec then return nil end
  local badge, b1, b2 = extra(rec)
  local s = { rec.param or 0, rec.rarity or 0, rec.level or 0, rec.get_order or 0, badge, b1, b2 }
  for k = 1, N do s[#s + 1] = engine_slot(hdl, k, 0) end
  return table.concat(s, ":")
end

local function cache_of(S)
  local c = CACHE[S]
  if c == nil then
    -- first fill of this save slot in this VM: nothing in the tables is ours to keep
    VRFW.native.table_clear(T_SLOTS, S)
    VRFW.native.table_clear(T_UNLOCK, S)
    c = { sig = {}, todo = {}, head = 1, tail = 0, queued = {}, done = 0 }
    CACHE[S] = c
  end
  if c.store ~= STORE or c.wm ~= STORE.watermark then
    c.store, c.wm, c.sig = STORE, STORE.watermark, {}   -- every player again (his entries are rewritten in place)
  end
  return c
end

-- one player's entries again (after a change of his choices, or a changed signature)
-- false only when the saved list is readable and does not hold the handle (the player left the save)
local function still_saved(hdl)
  local ok, all = pcall(VRFW.chara.saved)
  if not ok or type(all) ~= "table" or #all == 0 then return true end
  for _, r in ipairs(all) do
    if r.handle == hdl then return true end
  end
  return false
end

local function write_player(S, hdl, c, why)
  local slots, unlock = {}, {}
  if not player_entries(S, hdl, slots, unlock) then
    if c then c.sig[hdl] = nil end
    if not still_saved(hdl) then
      clear_player(S, hdl)
      return false
    end
    -- unreadable now: his entries stay as they are (never cleared from a failed read), scanned again later
    RETRY = true
    UNREADABLE_LOGGED = UNREADABLE_LOGGED + 1
    if UNREADABLE_LOGGED <= 12 then
      info(string.format("chara 0x%08X: record not readable (%s): his native entries are kept, written again at the next scan", hdl, tostring(why)))
    end
    return false
  end
  clear_player(S, hdl)
  for _, x in ipairs(slots) do VRFW.native.table_set(T_SLOTS, x[1], x[2]) end
  for _, x in ipairs(unlock) do VRFW.native.table_set(T_UNLOCK, x[1], x[2]) end
  if c then c.sig[hdl] = signature(hdl) end
  return true
end

local function refresh_player(hdl)
  local S = VRFW.slots.active()
  local c = CACHE[S]
  write_player(S, hdl, c ~= nil and c.store == STORE and c or nil, "choice changed")
end

-- work off the queue for up to `ms` milliseconds
local function pump(S, ms)
  local c = CACHE[S]
  if c == nil or c.head > c.tail or PUMPING then return end
  PUMPING = true
  local t0 = VRFW.now()
  local ok, e = pcall(function()
    while c.head <= c.tail do
      local hdl = c.todo[c.head]
      c.todo[c.head] = nil
      c.head = c.head + 1
      c.queued[hdl] = nil
      if write_player(S, hdl, c, c.why) then c.done = c.done + 1 end
      if VRFW.now() - t0 >= ms then break end
    end
  end)
  PUMPING = false
  if not ok then err("refresh (" .. tostring(c.why) .. "): " .. tostring(e)) end
  if c.head > c.tail then
    c.todo, c.head, c.tail = {}, 1, 0
    if c.done > 0 then
      info(string.format("native tables of slot %d (%s): %d player(s) updated", S, tostring(c.why), c.done))
    end
    c.done = 0
  end
end

-- the players of the active save slot whose entries must be (re)computed: every configured player (with declared slot
-- rules: every saved player); queued, then a first slice
local function refresh(why, ms)
  if not ACTIVE then return end
  RETRY = false
  LAST_RETRY = VRFW.now()
  local S = VRFW.slots.active()
  local ok, e = pcall(function()
    if mode_slot() then
      -- a mode's reserved slot: its passives are the mode's
      VRFW.native.table_clear(T_SLOTS, S)
      VRFW.native.table_clear(T_UNLOCK, S)
      VRFW.native.table_set(T_ALL, S, nil)
      CACHE[S] = nil
      return
    end
    ensure_store()
    local c = cache_of(S)
    local present, queued, changed = {}, 0, {}
    local function consider(hdl)
      if present[hdl] then return end
      present[hdl] = true
      if c.queued[hdl] then return end
      local old = c.sig[hdl]
      local now = old ~= nil and signature(hdl) or nil
      if old == nil or old ~= now then
        if old ~= nil and #changed < 3 then
          changed[#changed + 1] = string.format("0x%08X %s -> %s", hdl, old, tostring(now))
        end
        c.queued[hdl] = true
        c.tail = c.tail + 1
        c.todo[c.tail] = hdl
        queued = queued + 1
      end
    end
    for key, _ in pairs(STORE.players) do
      local hdl = tonumber(key, 16)
      if hdl then consider(hdl) end
    end
    local saved_read = true
    if rules_touch_everyone() then
      local all = VRFW.chara.saved()
      -- no saved character readable (the save being read): nobody is «gone» now
      if #all == 0 then saved_read = false; RETRY = true end
      for _, r in ipairs(all) do consider(r.handle) end
    end
    local gone = 0
    if saved_read then
      for hdl, _ in pairs(c.sig) do
        if not present[hdl] then
          clear_player(S, hdl)
          c.sig[hdl] = nil
          gone = gone + 1
        end
      end
    end
    VRFW.native.table_set(T_ALL, S, UNLOCK == "all" and 1 or nil)
    if queued > 0 or gone > 0 then
      c.why = why
      info(string.format("native tables of slot %d (%s): %d player(s) to update, %d gone%s%s", S, why, queued, gone,
        UNLOCK == "all" and ", every non-empty slot of a configurable player unlocked" or "",
        #changed > 0 and ("; changed (param:rarity:level:get_order:badge:build:diamond_build:engine slots 1-5) " .. table.concat(changed, "; ")) or ""))
    end
  end)
  if not ok then err("refresh (" .. why .. "): " .. tostring(e)) end
  pump(S, ms or SLICE_MS)
end

-- a slot event (load / switch / new game) since the last call: the tables of the new slot; else a short slice of the
-- queue now and then (the commands run on the game thread)
local function follow_slots()
  local seq = VRFW.slots.event_seq()
  if seq ~= LAST_SEQ then
    LAST_SEQ = seq
    WATERMARK_DUE = true
    refresh("slot event", SLICE_GAME_MS)
  elseif STORE and STORE.slot ~= VRFW.slots.active() then
    refresh("slot changed", SLICE_GAME_MS)
  elseif RETRY and VRFW.now() - LAST_RETRY >= RETRY_EVERY_MS then
    refresh("retry", SLICE_GAME_MS)
  else
    local now = VRFW.now()
    if now - LAST_PUMP >= PUMP_EVERY_MS then
      LAST_PUMP = now
      pump(VRFW.slots.active(), SLICE_GAME_MS)
    end
  end
end

-- ---------------------------------------------------------------------------------------------- live check
-- What the two slot readers really answer (their hooked entry points, these native answers included) against the
-- entries the tables should hold. After every mode / match trigger: the saved configured players (a difference is
-- logged and the player written again). At match start / end also the match copies of the configured players (the
-- match builder reads the copies): the log says whether the configuration is what the match reads.

-- the match teams of the party block (Party.MatchTeams: a pointer to two [struct.PartyMatchTeam], members
-- [struct.PartyMatchMember]) and the user's match team (MatchInfo.UserTeam): offsets from the game profile
local LIVE_LAYOUT_NAMES = {
  match_teams = "Party.MatchTeams", team_size = "PartyMatchTeam", team_members = "PartyMatchTeam.Members",
  member_size = "PartyMatchMember", member_handle = "PartyMatchMember.Handle", member_count = "Party.MatchTeamMemberCount",
  user_team = "MatchInfo.UserTeam",
}
local LIVE_LAYOUT, LIVE_LAYOUT_DONE = nil, false
local LIVE_BUF, LIVE_ON = nil, nil

local function live_ready()
  if LIVE_ON == nil then
    LIVE_ON = VRFW.is_on("Passive.TeamPassiveId") and VRFW.is_on("Passive.TeamPassiveUnlocked")
    if LIVE_ON then LIVE_BUF = VRFW.mem.buffer("pc_live_out", 8) end
  end
  return LIVE_ON
end

local function truthy(v)
  return v == true or (type(v) == "number" and v ~= 0)
end

-- the readers' answer for (handle, slot 1-5): id, unlocked; nil when a call failed
local function live_slot(hdl, k, copy)
  local oku, u = pcall(VRFW.call, "Passive.TeamPassiveUnlocked", hdl, k - 1, copy)
  VRFW.mem.write("u32", LIVE_BUF, 0)
  local oki = pcall(VRFW.call, "Passive.TeamPassiveId", LIVE_BUF, hdl, k - 1, copy)
  if not (oku and oki) then return nil end
  return VRFW.mem.read("u32", LIVE_BUF), truthy(u)
end

-- the entries `owner` should have: id by slot, unlocked by slot (nil = no entry); nil when his record is unreadable
local function expected_of(S, owner)
  local slots, unlock = {}, {}
  if not player_entries(S, owner, slots, unlock) then return nil end
  local id, open = {}, {}
  for _, x in ipairs(slots) do id[x[1][3] + 1] = x[2] end
  for _, x in ipairs(unlock) do open[x[1][3] + 1] = x[2] == 1 end
  return id, open
end

-- the readers through `hdl` (the saved player or his match copy) against `owner`'s entries: slots checked, differing
local function compare(S, hdl, owner, copy, details)
  local id, open = expected_of(S, owner)
  if not id then return 0, 0 end
  local checked, bad = 0, 0
  for k = 1, N do
    if id[k] ~= nil or open[k] ~= nil then
      local got, unlocked = live_slot(hdl, k, copy)
      if got ~= nil then
        checked = checked + 1
        if (id[k] ~= nil and got ~= id[k]) or (open[k] ~= nil and unlocked ~= open[k]) then
          bad = bad + 1
          if #details < 6 then
            local okt, entry = pcall(VRFW.native.table_get, T_SLOTS, { S, owner, k - 1 })
            entry = okt and tonumber(entry) or nil
            details[#details + 1] = string.format("0x%08X%s slot %d: the reader answers 0x%08X %s, expected 0x%08X %s (table entry %s)",
              hdl, hdl ~= owner and string.format(" (copy of 0x%08X)", owner) or "", k, got, unlocked and "unlocked" or "locked",
              id[k] or got, open[k] == false and "locked" or "unlocked", entry and string.format("0x%08X", entry) or "none")
          end
        end
      end
    end
  end
  return checked, bad
end

-- the profile's numbers of the live check (nil when one is missing: warned once)
local function live_layout()
  if not LIVE_LAYOUT_DONE then
    LIVE_LAYOUT_DONE = true
    local out = {}
    for key, name in pairs(LIVE_LAYOUT_NAMES) do
      local ok, v = pcall(VRFW.game.field, name)
      if not ok or type(v) ~= "number" then
        warn("live check: the game profile has no " .. name .. ": match teams not checked")
        return nil
      end
      out[key] = v
    end
    LIVE_LAYOUT = out
  end
  return LIVE_LAYOUT
end

local function team_members(team)
  local L = live_layout()
  if not L then return nil end
  local okg, sets = pcall(VRFW.game.utilities_team_sets)
  if not okg or not sets or sets < 0x10000 then return nil end
  local okb, base = pcall(VRFW.mem.read, "ptr", sets + L.match_teams)
  if not okb or not base or base < 0x10000 then return nil end
  base = base + team * L.team_size
  local out = {}
  for j = 0, L.member_count - 1 do
    local okm, h = pcall(VRFW.mem.read, "u32", base + L.team_members + j * L.member_size + L.member_handle)
    if okm and h and h ~= 0 then out[#out + 1] = h end
  end
  return out
end

local function user_team()
  local L = live_layout()
  if not L then return nil end
  local okg, mi = pcall(VRFW.game.utilities_match_info)
  if not okg or not mi or mi < 0x10000 then return nil end
  local ok, t = pcall(VRFW.mem.read, "u8", mi + L.user_team)
  if ok and t and t <= 1 then return t end
  return nil
end

-- the match copies of the configured players: is what the match reads their configuration?
local function match_check(why, S, configured)
  local details, copies, checked, bad, unowned, seen = {}, 0, 0, 0, 0, 0
  for team = 0, 1 do
    for _, m in ipairs(team_members(team) or {}) do
      seen = seen + 1
      local kind = C.kind_of_handle(m)
      local okc, owner = pcall(VRFW.chara.owner, m)
      owner = okc and owner or nil
      if owner and configured[owner] then
        copies = copies + 1
        local c1, b1 = compare(S, m, owner, (kind == 0 or kind == 7) and 0 or 1, details)
        checked, bad = checked + c1, bad + b1
      elseif not owner then
        local okw, weak = pcall(VRFW.chara.owner_weak, m)
        if okw and weak and configured[weak] then
          unowned = unowned + 1
          if #details < 6 then
            details[#details + 1] = string.format("0x%08X (team %d): only a card match with the configured 0x%08X, no owner: the readers answer the game's own passives for it", m, team, weak)
          end
        end
      end
    end
  end
  if seen == 0 then
    info(string.format("match check (%s): no match team yet", why))
    return
  end
  local ut = user_team()
  info(string.format("match check (%s): %d member(s), user team %s: %d copy(ies) of configured players, %d slot(s) checked, %s%s%s",
    why, seen, ut and tostring(ut) or "?", copies, checked,
    bad == 0 and "all answer the configuration" or string.format("%d differ", bad),
    unowned > 0 and string.format(", %d configured player(s) without an owner match", unowned) or "",
    #details > 0 and (": " .. table.concat(details, "; ")) or ""))
end

local function live_check(why, in_match)
  if not ACTIVE or not STORE or passives_off() or mode_slot() or not live_ready() then return end
  local S = VRFW.slots.active()
  if STORE.slot ~= S then return end
  local configured = {}
  for key, _ in pairs(STORE.players) do
    local hdl = tonumber(key, 16)
    if hdl then configured[hdl] = true end
  end
  if next(configured) == nil then return end
  local details, checked, bad, rewrite = {}, 0, 0, {}
  for hdl in pairs(configured) do
    local c1, b1 = compare(S, hdl, hdl, 0, details)
    checked, bad = checked + c1, bad + b1
    if b1 > 0 then rewrite[#rewrite + 1] = hdl end
  end
  if bad > 0 then
    warn(string.format("live check (%s): %d of %d configured slot(s) answer something else: %s; written again", why, bad, checked, table.concat(details, "; ")))
    local c = CACHE[S]
    for _, hdl in ipairs(rewrite) do
      write_player(S, hdl, c ~= nil and c.store == STORE and c or nil, "live check")
    end
  end
  if in_match then match_check(why, S, configured) end
end

-- ---------------------------------------------------------------------------------------------- views of one slot

local function default_for(hdl, k)
  if not ACTIVE or k < 1 or k > N then return nil end
  local pr, _, cfgd, def = view_full(hdl, 0)
  if not pr or pr.card == C.BLOCKED or not active_of(pr, cfgd)[k] then return nil end
  return def[k]
end

-- ---------------------------------------------------------------------------------------------- the plate (retail filter)

-- logs an answer only when it differs from the last one logged for the same query key
local function log_on_change(key, value, fmt, ...)
  if LOGGED_ANSWER[key] == value then return end
  LOGGED_ANSWER[key] = value
  info(string.format(fmt, ...))
end

local function plate_value(field, id, ver, unlocked)
  if field == 0 then return ver end
  if field == 1 then
    local v = value_of(ver)
    if v == 0 then v = value_of(id) end
    return v
  end
  return unlocked
end

-- CMND_GET_CHARA_TEAM_PASSIVE_INFO(hdl, slot, field, useCopy, preview)
function PC.PlateInfo(h, slot, field, _copy, preview)
  h, slot, field = arg_u32(h), arg_u32(slot), arg_u32(field)
  if not (h and slot and field) or field > 2 then return false end
  local li = C.list_index(h)
  if not li and slot < N and (passives_off() or slots_off()) then
    if field == 2 then return true, true, false end
    return true, true, 0
  end
  if not ACTIVE then return false end
  follow_slots()
  if li then
    local id = LIST and LIST.ids[li + 1] or 0
    local ver = id == 0 and 0 or resolve_version(id, LIST and LIST.rarity or 0)
    return true, true, plate_value(field, id, ver, true)
  end
  if slot >= N then return false end
  local k = slot + 1
  preview = preview == true
  if slot == 0 and field == 0 and not preview then ROW1 = h end
  if preview then
    local id = default_for(h, k)
    if id == nil then return false end
    local ver = id == 0 and 0 or resolve_version(id, rarity_of(h))
    return true, true, plate_value(field, id, ver, true)
  end
  local own = own_for(h, k)
  local pr, eff, cfgd = view(h, 0)
  local conf = (pr and pr.card ~= C.BLOCKED) and eff[k] or nil
  local forced = false
  if pr and pr.card == C.STAFF then
    forced = cfgd ~= nil and active_of(pr, cfgd)[k] == true and C.kind_accepts(CAT, subject(pr, eff, false), RULES, k, cfgd[k])
  elseif pr and pr.card ~= C.BLOCKED then
    if UNLOCK == "all" then forced = eff[k] ~= 0 else forced = active_of(pr, cfgd)[k] == true end
  end
  local id, what
  if conf then id, what = conf, "configured" elseif own then id, what = own, "own" else return false end
  -- a configured slot equal to the engine's own id and not force-unlocked: the retail answer is the same
  if conf and not own and not forced then
    if engine_slot(h, k, 0) == applied_version(id, rarity_of(h)) then return false end
  end
  local ver = id == 0 and 0 or resolve_version(id, rarity_of(h))
  local unlocked = true
  if field == 2 then
    local locked = pr ~= nil and pr.card ~= C.BLOCKED and C.kind(RULES, k) == C.SPECIAL and not C.slot_open(RULES, pr.card, pr.rarity, k) and eff[k] == 0
    unlocked = not locked and (forced or (own ~= nil and conf == nil and CFG.always_unlocked) or unlocked_retail(h, k))
  end
  log_on_change(h * 64 + k * 8 + field, what .. ver, "plate chara 0x%08X slot %d field %d -> %s 0x%08X", h, k, field, what, ver)
  return true, true, plate_value(field, id, ver, unlocked)
end

-- ---------------------------------------------------------------------------------------------- commands

-- CMND_BETTERQOL_PC_OFF() → true while a declared off mode or a framework signature-only mode runs (the plate hides its passive rows)
function PC.Off()
  return passives_off() or slots_off()
end

-- CMND_BETTERQOL_PC_INFO(hdl) → ok, mode, archetype 1, archetype 2, max slots, inactive count
function PC.Info(h)
  h = arg_u32(h)
  follow_slots()
  local pr, eff, cfgd
  if h and ACTIVE then pr, eff, cfgd = view(h, 0) end
  local max = LAYOUT and LAYOUT.max or 3
  if not pr then return false, 0, C.NO_ARCHETYPE, C.NO_ARCHETYPE, max, 0 end
  local a, b = C.NO_ARCHETYPE, C.NO_ARCHETYPE
  if PLAYER then a, b = C.derive(CAT, eff, PLAYER.slots) end
  local mode = 0
  for k = 1, N do
    if C.slot_open_in(RULES, pr.card, pr.rarity, k, LAYOUT) then mode = 1 end
  end
  return true, mode, a, b, max, cfgd and #C.inactive(LAYOUT, cfgd, open_of(pr)) or 0
end

-- CMND_BETTERQOL_PC_SLOT(hdl, slot) → id, configured, locked, inactive stored id, kind code, lock reason (0 open, 1 the
-- card / slot rules: Ídolo, Prime, an unresolved staff badge..., 2 only the configurable-slot limit [passives] max_slots keeps it closed)
function PC.Slot(h, slot)
  h, slot = arg_u32(h), arg_slot(slot)
  if not (h and slot) then return 0, false, true, 0, 0, 1 end
  local pr, eff, cfgd = view(h, 0)
  if not pr then return 0, false, true, 0, 0, 1 end
  local stored = cfgd and cfgd[slot] or 0
  local kind = C.slot_kind(RULES, pr.card, slot)
  local fits
  if pr.card == C.STAFF then
    fits = stored == 0 or C.staff_allowed(CAT, pr.role, pr.rarity, stored)
  else
    fits = stored == 0 or kind == C.SPECIAL or (kind == C.GENERAL and not C.is_archetype(CAT, stored)) or (kind == C.ARCHETYPE and C.is_archetype(CAT, stored)) or kind == C.ANY
  end
  local on = active_of(pr, cfgd)[slot] == true and fits
  local reason = 0
  if not C.slot_open(RULES, pr.card, pr.rarity, slot) then
    reason = 1
  elseif not C.allows(LAYOUT, slot) then
    reason = 2
  end
  return eff[slot], stored ~= 0 and on, reason ~= 0, on and 0 or stored, C.KIND_CODE[kind] or 0, reason
end

-- CMND_BETTERQOL_PC_LIST(hdl, slot, category) → count, category used, index of the slot's current passive (-1)
function PC.List(h, slot, cat)
  h, slot = arg_u32(h), arg_slot(slot)
  if not (h and slot) then return 0, 0 end
  local want = math.min(math.max(arg_int(cat) or 0, 0), 255)
  local pr, eff = view(h, 0)
  if not pr then return 0, 0 end
  local kind = C.slot_kind(RULES, pr.card, slot)
  local ex = C.other_defs(CAT, eff, slot, CFG.allow_duplicates)
  local staff = pr.card == C.STAFF
  local cats = staff and C.staff_categories(CAT, pr.role, pr.rarity, ex) or C.kind_categories(CAT, kind, ex)
  local category = C.CAT_ALL
  for _, c in ipairs(cats) do
    if c == want then category = want end
  end
  local ids
  if staff then
    ids = C.staff_pick(CAT, pr.role, pr.rarity, category, ex)
  elseif kind == C.SPECIAL then
    ids = C.special_list(CAT, pr.special, pr.who, ex)
  else
    ids = C.pick(CAT, kind, category, ex)
  end
  local cur = C.current_index(CAT, ids, eff[slot])
  LIST = { hdl = h, slot = slot, category = category, rarity = pr.rarity, ids = ids }
  return #ids, category, cur and (cur - 1) or -1
end

-- CMND_BETTERQOL_PC_LIST_ID(index) → id of the current list (0 past its end)
function PC.ListId(i)
  i = arg_int(i) or -1
  if i < 0 or not LIST then return 0 end
  return LIST.ids[i + 1] or 0
end

-- CMND_BETTERQOL_PC_CAT_NEXT(hdl, slot, category, dir) → the next / previous category of the slot's class
function PC.CatNext(h, slot, cur, dir)
  h, slot = arg_u32(h), arg_slot(slot)
  if not (h and slot) then return 0 end
  cur = math.min(math.max(arg_int(cur) or 0, 0), 255)
  dir = arg_int(dir) or 1
  local pr, eff = view(h, 0)
  if not pr then return 0 end
  local ex = C.other_defs(CAT, eff, slot, CFG.allow_duplicates)
  local cats = pr.card == C.STAFF and C.staff_categories(CAT, pr.role, pr.rarity, ex) or C.kind_categories(CAT, C.kind(RULES, slot), ex)
  local i = 0
  for j, c in ipairs(cats) do
    if c == cur then i = j - 1; break end
  end
  local n = #cats
  local j = ((i + (dir < 0 and -1 or 1)) % n + n) % n
  return cats[j + 1]
end

-- CMND_BETTERQOL_PC_SET(hdl, slot, id) → ok, code (0 ok, 1-7 the set error)
function PC.Set(h, slot, id)
  h = arg_u32(h)
  if not h then return false, C.E_NOT_ALLOWED end
  local s = arg_int(slot)
  if not s or s < 0 or s >= N then return false, C.E_BAD_SLOT end
  local k = s + 1
  id = arg_u32(id) or 0
  if not ACTIVE then return false, C.E_NOT_ALLOWED end
  follow_slots()
  local pr, eff, cfgd = view(h, 0)
  if not pr or pr.owner ~= h then return false, C.E_NOT_ALLOWED end -- only the saved character itself, never a match copy
  local code = C.check_set(CAT, subject(pr, eff, false), eff, cfgd, k, id, LAYOUT, RULES, CFG.allow_duplicates)
  if code then return false, code end
  if C.store_set(STORE, pr.owner, pr.param, k, id) then save_store() end
  local _, after = view(h, 0)
  local slots = {}
  for j = 1, N do slots[j] = string.format("0x%08X", after and after[j] or 0) end
  local arch = ""
  if PLAYER and after then
    local _, _, name, found = C.derive(CAT, after, PLAYER.slots)
    arch = "; archetype " .. ((found or PLAYER.without == "none") and name or "the game's own")
  end
  info(string.format("chara 0x%08X (param 0x%08X) slot %d -> %s (was 0x%08X); slots %s%s", h, pr.param, k, id == 0 and "default" or string.format("0x%08X", id), eff[k], table.concat(slots, " "), arch))
  refresh_player(h)
  return true, 0
end

-- CMND_BETTERQOL_PC_RESET(hdl) → ok (the player had a configuration and it was removed)
function PC.Reset(h)
  h = arg_u32(h)
  if not h or not ACTIVE then return false end
  follow_slots()
  local pr = view(h, 0)
  if not pr or pr.card == C.BLOCKED or pr.owner ~= h then return false end
  local changed = C.store_reset(STORE, h)
  if changed then
    save_store()
    info(string.format("chara 0x%08X (param 0x%08X): configuration removed (default passives)", h, pr.param))
    refresh_player(h)
  end
  return changed
end

-- CMND_BETTERQOL_PC_SPECIAL([hdl]) → has special, title text key, special tile sprite, special slot (0-4, -1 = none)
function PC.Special(h)
  h = arg_u32(h)
  if not h or h == 0 then h = ROW1 end
  local sp = RULES and C.special_slot(RULES)
  local id
  if sp and ACTIVE and h ~= 0 then
    local pr, eff = view(h, 0)
    if pr and pr.card ~= C.BLOCKED and pr.card ~= C.STAFF and eff[sp] ~= 0 then id = eff[sp] end
  end
  local title = id and DECL and DECL.titles[id] or ""
  return id ~= nil, title, RULES and RULES.special_tile or 0, sp and (sp - 1) or -1
end

-- CMND_BETTERQOL_PC_EFF_ICON(effect) → the sprite the declarations give that effect definition (0 = the retail icon)
function PC.EffIcon(e)
  e = arg_u32(e)
  return (e and DECL and DECL.effect_icons[e]) or 0
end

-- ---------------------------------------------------------------------------------------------- retail filters

-- 0x40A079E0(hdl): the per-player window offers «Configuración de pasivas» to every player the configurator handles
function PC.CanInherit(h)
  if not ACTIVE then return false end
  h = arg_u32(h)
  if not h then return false end
  local pr = probe(h)
  if not pr then return false end
  return true, pr.card ~= C.BLOCKED
end

-- 0xE1611D0F(hdl, slot) → ok, the configured id of the slot (0 = default; an inactive one reads 0)
function PC.InheritId(h, slot)
  if not ACTIVE then return false end
  h, slot = arg_u32(h), arg_int(slot)
  if not (h and slot) then return false end
  if C.list_index(h) then return true, true, 0 end
  if slot < 0 or slot >= N then return false end
  local pr, _, cfgd = view(h, 0)
  if not pr or pr.card == C.BLOCKED then return false end
  local on = active_of(pr, cfgd)[slot + 1]
  return true, true, (on and cfgd) and cfgd[slot + 1] or 0
end

-- 0xB5948BCF(hdl, slot): the retail clear menu clears the configured slot (back to its default)
function PC.InheritClear(h, slot)
  if not ACTIVE then return false end
  h, slot = arg_u32(h), arg_int(slot)
  if not (h and slot) or slot < 0 or slot >= N then return false end
  local pr, _, cfgd = view(h, 0)
  if not pr or pr.card == C.BLOCKED or pr.owner ~= h then return false end
  local was = cfgd and cfgd[slot + 1] or 0
  if was ~= 0 and C.store_set(STORE, h, pr.param, slot + 1, 0) then
    save_store()
    info(string.format("chara 0x%08X (param 0x%08X) slot %d: configured 0x%08X removed (clear menu)", h, pr.param, slot + 1, was))
    refresh_player(h)
  end
  return true, was ~= 0
end

-- the player's archetype for the build getters: (archetype, name) or nil = the game's own answer (no rule, not a
-- saved player, or no archetype passive in the archetype slots with [player_archetype] without = "game")
local function archetype_of(h)
  if not PLAYER then return nil end
  local pr, eff = view(h, 0)
  if not pr then return nil end
  local a, _, name, found = C.derive(CAT, eff, PLAYER.slots)
  if not found and PLAYER.without == "game" then return nil end
  return a, name
end

-- 0x4375DC93(hdl, 36): the player's archetype icon = his derived archetype; the list's pseudo handles get 0
function PC.CharaStatus(h, field)
  if not ACTIVE then return false end
  h, field = arg_u32(h), arg_u32(field)
  if not (h and field) then return false end
  if C.list_index(h) then return true, 0 end
  if field ~= FIELD_BUILD or not PLAYER then return false end
  local a, name = archetype_of(h)
  if not a then return false end
  log_on_change(-h - 1, a, "chara 0x%08X archetype icon -> %d (%s)", h, a, name)
  return true, a
end

-- 0x2B16FA30(hdl, …) → ok, build type: the same answer as field 36
function PC.CharaBuild(h)
  if not ACTIVE or not PLAYER then return false end
  h = arg_u32(h)
  if not h then return false end
  local a = archetype_of(h)
  if not a then return false end
  return true, true, a
end

-- CMND_GET_PASSIVE_EFFECT_INFO(def, 3) → ok, 1 / (def, 4, i) → ok, archetype: the passive definition of an archetype a
-- mod declares (VRFW.archetype/1) has no build icon in the game's data (docs/framework/archetype.md §1); its rows
-- (the picker, the plate) show its archetype badge as the game's archetype passives do
function PC.EffBuild(def, field, _i)
  if not CAT or not CAT.custom_defs then return false end
  local a = CAT.custom_defs[arg_u32(def) or 0]
  if not a then return false end
  field = arg_u32(field)
  if field == 3 then return true, true, 1 end
  if field == 4 then return true, true, a end
  return false
end

-- CMND_GET_CHARA_INFO(param, 20) → ok, 6 (archetype mode: a chara_param row has no archetype any more)
function PC.ParamBuild(_param, field)
  if not ACTIVE or not C.archetype_mode(RULES) or arg_u32(field) ~= FIELD_PARAM_BUILD then return false end
  return true, true, C.NO_ARCHETYPE
end

-- ---------------------------------------------------------------------------------------------- start

-- the off modes need only the slot reader hooks, not the configurator ([passives] enabled = false keeps them)
local function start_off_modes()
  if not (VRFW.is_on("GetTeamPassiveId") and VRFW.is_on("IsTeamPassiveUnlocked")) then return end
  local ok, e = pcall(load_off_modes)
  if not ok then
    err("off modes: " .. tostring(e) .. " (player passives apply in every mode)")
    OFF_KEYS = {}
    return
  end
  fill_off_modes()
end

local function start()
  local raw = VRFW.files.config("passives")
  local w
  CFG, w = C.config(raw)
  if w then warn(w) end
  if not CFG.enabled then
    info("[passives] enabled = false: retail passives (the commands answer «not configurable», the filters let the game answer)")
    return
  end
  local lw
  LAYOUT, lw = C.layout(CFG.max_slots, nil)
  if lw then warn(lw) end
  if not (VRFW.is_on("GetTeamPassiveId") and VRFW.is_on("IsTeamPassiveUnlocked")) then
    err("the slot reader hooks are off (see «Problemas» / console native): «Configuración de pasivas» off (retail passives)")
    return
  end
  BUF = VRFW.mem.buffer("pc_slot_out", 8)
  local ok, e = pcall(load_tables)
  if not ok then
    err(tostring(e) .. ": «Configuración de pasivas» off (retail passives)")
    return
  end
  fill_static()
  ACTIVE = true
  info(string.format("active (max %d configurable slot(s)); the slot readers answer from the native tables", LAYOUT.max))
  refresh("start")
end

start()
start_off_modes()

-- the active save slot's tables follow the game: a mode change (title, menus, a match), a match start and end (a
-- Chronicle match changes no mode); each trigger scans (a scan + one slice; what is left goes on at the next trigger /
-- command), then checks what the readers answer
for _, trig in ipairs({ "mode_enter", "mode_leave", "match_start", "match_end" }) do
  VRFW.on(trig, function()
    if next(OFF_KEYS) ~= nil then fill_off_modes() end
    if not ACTIVE then return end
    LAST_SEQ = VRFW.slots.event_seq()
    WATERMARK_DUE = true
    refresh(trig)
    local ok, e = pcall(live_check, trig, trig == "match_start" or trig == "match_end")
    if not ok then err("live check (" .. trig .. "): " .. tostring(e)) end
  end)
end
