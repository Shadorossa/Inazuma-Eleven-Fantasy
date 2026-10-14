-- Football Reforged › the module switches (docs/game/mods/football-reforged.md §2). Every module of the mod is a
-- declaration file content\modules\<module>.toml ([FootballReforged.Module]: id, option, default, name / description
-- text keys); its on / off switch is a row of «Opciones de mods» (options.toml: one child row per module under the
-- group row «Football Reforged»). A module's script asks one function before it does anything:
--
--   local Modules = require "lib/modules"
--   if Modules.on("goalkeeper_barrier") then ... end      -- also FootballReforged.ModuleOn("goalkeeper_barrier")
--
-- The answer follows the option row live (cached for REREAD_MS, so a change in the options screen applies within a
-- second, no restart): the row's value when the option service answers (0 while the group row «Football Reforged» is
-- Desactivado), else the module's `default`. A module id without a declaration file is off.
-- Each entry script runs in its own VM: every module script requires this library (it is loaded once per VM).

FootballReforged = FootballReforged or {}
local M = {}

local MOD = "football_reforged"
local REREAD_MS = 1000

local DECL = nil          -- module id -> { id, option, default, name, description, file }
local CACHE = {}          -- module id -> { at = ms, on = bool }

local function warn(...) VRFW.warn("modules:", ...) end

local function truthy(v)
  if v == nil then return nil end
  if type(v) == "boolean" then return v end
  local n = tonumber(v)
  if n ~= nil then return n ~= 0 end
  return nil
end

-- every content\modules\*.toml of this mod (other mods may not add modules here: a module is code of this mod)
function M.declarations()
  if DECL then return DECL end
  DECL = {}
  local ok, files = pcall(VRFW.files.declarations, "content/modules")
  for _, f in ipairs(ok and type(files) == "table" and files or {}) do
    local d = type(f) == "table" and f.mod == MOD and type(f.data) == "table" and f.data or nil
    local t = d and type(d.FootballReforged) == "table" and d.FootballReforged.Module or nil
    if type(t) == "table" and type(t.id) == "string" and t.id ~= "" then
      if DECL[t.id] then
        warn("module", t.id, "declared twice (", f.file, "): the first one is kept")
      else
        DECL[t.id] = {
          id = t.id,
          option = type(t.option) == "string" and t.option or t.id,
          default = truthy(t.default) ~= false,
          name = t.name,
          description = t.description,
          file = f.file,
        }
      end
    elseif type(f) == "table" and f.mod == MOD then
      warn(f.file, ": no [FootballReforged.Module] with an `id`: skipped")
    end
  end
  return DECL
end

-- is the module on now?
function M.on(id)
  local now = VRFW.now()
  local c = CACHE[id]
  if c and now - c.at < REREAD_MS then return c.on end
  local d = M.declarations()[id]
  local on = false
  if d then
    local ok, v = pcall(VRFW.option, d.option)
    local t = ok and truthy(v) or nil
    if t == nil then on = d.default else on = t end
  end
  CACHE[id] = { at = now, on = on }
  return on
end

FootballReforged.ModuleOn = M.on

return M
