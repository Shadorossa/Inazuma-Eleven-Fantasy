-- Utilities › «Modo Comandante automático» (feature auto_commander; docs/game/ui/comandante-guia.md §7). With the row
-- utilities.auto_commander on (Nacho 2026-10-13):
-- * Battle Bay matches (config.toml [auto_commander] always_games: the match rows every BB match plays, loose match,
--   campaign, Battle Bay Deluxe's draft and tournament) always start in Commander mode and the game's gate is open for
--   them (Manual <-> Commander against an unbeaten rival too);
-- * free matches and Heroic battles (the match difficulties of [auto_commander] beaten_only_contexts /
--   beaten_only_difficulties, resolved by name from the active mods' defaults\match_difficulty.toml) start in
--   Commander mode only when the game itself would allow it (the rival already beaten); else Manual and the game's
--   gate as it is;
-- * every other match (story, office…): the game's rules. Row off: the game's rules everywhere.
-- Declarations: content\game\auto_commander.toml.
--
-- The match scene's two inits ask RequestCoachMode(mode, req) for the first mode (Manual in the retail build): the
-- hooks Utilities.CoachModeInit / Utilities.CoachModeInit2 read the row live (a change in Settings applies from the
-- next match), classify the match from the match info (game id +4, difficulty +0x15) and, when it qualifies, ask for
-- Commander (1) with the flags the player's own toggle uses. The tables Utilities.AutoCommander /
-- Utilities.AutoCommanderWhy make the game's gate (CoachModeBlocked) answer "allowed" for a BB match; every init
-- empties them first. Left as the game has it: online (RequestCoachMode forces Manual there itself), the matches the
-- game already starts and keeps in Commander mode (match info flag 0x200000), a first mode other than Manual.

local OPTION = "auto_commander"
local HOOK_GATE = "Utilities.CoachModeGate"
local T_GATE = "Utilities.AutoCommander"
local T_WHY = "Utilities.AutoCommanderWhy"
local FORCED_FLAG = 0x200000      -- match info +0: the game starts and keeps this match in Commander mode
local MI_GAME = 0x4               -- match info: the match row's id (soccer_game_config key hash)
local MI_DIFF = 0x15              -- match info: the difficulty
local MODE_COMMANDER = 1
local SET_FLAGS = 2                -- the player's toggle into Commander: flags set 2, cleared 0xC00 (0x15995B0)
local CLEAR_FLAGS = 0xC00

local cfg = (VRFW.files and VRFW.files.config and VRFW.files.config("auto_commander")) or {}

local function list(v, default)
  return type(v) == "table" and v or default
end

-- match rows (game keys or numbers) whose matches always start in Commander mode, gate open
local ALWAYS = {}
for _, g in ipairs(list(cfg.always_games, { "fbtl_bb_stadium_00" })) do
  local id = type(g) == "number" and g or (type(g) == "string" and VRFW.crc32(g)) or nil
  if id then
    ALWAYS[bit32.band(id, 0xFFFFFFFF)] = true
  else
    VRFW.warn("config.toml [auto_commander] always_games: " .. tostring(g) .. " is no game key: ignored")
  end
end

-- game modes (current-mode keys) where the beaten-only rule never applies
local NEVER_MODES = list(cfg.never_modes, { "story" })

-- difficulties under the beaten-only rule: built once from the active mods' match difficulties
local BEATEN = nil
local function beaten_set()
  if BEATEN then
    return BEATEN
  end
  local ctxs, names = {}, {}
  for _, c in ipairs(list(cfg.beaten_only_contexts, { "free_match" })) do
    ctxs[c] = true
  end
  for _, n in ipairs(list(cfg.beaten_only_difficulties, { "Heroica", "HeroicaPlus" })) do
    names[n] = true
  end
  local merged = {}
  local ok, files = pcall(VRFW.files.declarations, { "defaults/match_difficulty.toml", "content/defaults/match_difficulty.toml" })
  for _, f in ipairs(ok and files or {}) do
    local md = type(f.data) == "table" and f.data.MatchDifficulty or nil
    if type(md) == "table" then
      for name, row in pairs(md) do
        if type(row) == "table" then
          local m = merged[name] or {}
          for k, v in pairs(row) do
            m[k] = v
          end
          merged[name] = m
        end
      end
    end
  end
  local set, shown = {}, {}
  for name, row in pairs(merged) do
    local d = tonumber(row.Difficulty)
    local hit = names[name] == true
    for _, c in ipairs(type(row.Contexts) == "table" and row.Contexts or {}) do
      hit = hit or ctxs[c] == true
    end
    if d and hit then
      set[d] = true
      shown[#shown + 1] = name .. "=" .. d
    end
  end
  table.sort(shown)
  if #shown == 0 then
    VRFW.warn("auto commander: no match difficulty found for the beaten-only rule (defaults\\match_difficulty.toml)")
  else
    VRFW.log("auto commander: beaten-only difficulties " .. table.concat(shown, ", "))
  end
  BEATEN = set
  return set
end

local function option_on()
  return (tonumber(VRFW.option(OPTION)) or 0) ~= 0
end

-- the running match: flags, game id, difficulty (nil = unknown)
local function match_info()
  local mi = VRFW.game.util_match_info()
  if mi == nil then
    return nil
  end
  local ok1, flags = pcall(VRFW.mem.read, "u32", mi)
  local ok2, game = pcall(VRFW.mem.read, "u32", mi + MI_GAME)
  local ok3, diff = pcall(VRFW.mem.read, "u8", mi + MI_DIFF)
  if not (ok1 and ok2 and ok3) then
    return nil
  end
  return { flags = flags, game = game, diff = diff }
end

local function gate(open)
  if open then
    VRFW.native.table_set(T_WHY, 0, 1)
    VRFW.native.table_set(T_GATE, 0, 0)
  else
    VRFW.native.table_clear(T_WHY)
    VRFW.native.table_clear(T_GATE)
  end
end

-- the game's own answer: may the player enter Commander mode in this match (the rival beaten…)
local function game_allows()
  if not VRFW.is_on(HOOK_GATE) then
    return false
  end
  local ok, blocked = pcall(VRFW.hook.original, HOOK_GATE, 0)
  return ok and (blocked == false or blocked == 0)
end

local function in_mode(keys)
  for _, k in ipairs(keys) do
    if VRFW.mode_is(k) then
      return true
    end
  end
  return false
end

-- "always" / "beaten" / nil (the game's rules), and why
local function classify(m)
  if ALWAYS[m.game] then
    return "always", "Battle Bay row"
  end
  if not beaten_set()[m.diff] then
    return nil, "difficulty " .. tostring(m.diff) .. " not under the rule"
  end
  if in_mode(NEVER_MODES) then
    return nil, "mode " .. tostring(VRFW.mode())
  end
  if game_allows() then
    return "beaten", "difficulty " .. m.diff .. ", rival beaten"
  end
  return nil, "difficulty " .. m.diff .. ", rival not beaten: Manual"
end

local function on_init(ev)
  gate(false)
  if not option_on() then
    return nil
  end
  local m = match_info()
  if m == nil then
    VRFW.log("auto commander: " .. ev.hook .. ": no match info: the game's rules")
    return nil
  end
  local kind, why = classify(m)
  if kind == nil then
    VRFW.log(string.format("auto commander: %s: game 0x%08X: %s: the game's rules", ev.hook, m.game, why))
    return nil
  end
  local forced = bit32.band(m.flags, FORCED_FLAG) ~= 0
  if kind == "always" and not forced then
    gate(true)
  end
  local mode, req = ev.args[1], ev.args[2]
  if mode ~= 0 or req == nil or req == 0 then
    VRFW.log(string.format("auto commander: %s asks mode %s: left as it is", ev.hook, tostring(mode)))
    return nil
  end
  local ok = pcall(VRFW.mem.write, "u32", req, SET_FLAGS) and pcall(VRFW.mem.write, "u32", req + 4, CLEAR_FLAGS)
  if not ok then
    VRFW.warn("auto commander: the request's flags could not be written: Commander mode without them")
  end
  VRFW.log(string.format("auto commander: %s: game 0x%08X (%s): match starts in Commander mode (gate open: %s)",
    ev.hook, m.game, why, tostring(kind == "always" and not forced)))
  return { args = { [1] = MODE_COMMANDER } }
end

VRFW.on("hook:Utilities.CoachModeInit", on_init)
VRFW.on("hook:Utilities.CoachModeInit2", on_init)
