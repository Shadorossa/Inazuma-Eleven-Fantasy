-- Player Training › the training's Suerte deltas (moved from Inazuma Fantasy 2026-10-14; docs/game/mechanics/
-- training-classic.md §3): the save has no 9th prm_growth slot, so the Suerte delta lives in this mod's slot blob
-- training.json. The game saves prm_growth[0..7] itself, but only when the player saves, so each character keeps a short
-- history of (prm_growth[0..7] at commit time, Suerte delta): the delta used is the newest entry whose snapshot equals
-- the character's current prm_growth, else 0. The same JSON as Inazuma Fantasy's blob of the same name (and its older
-- plugin's training::store::SlotFile): [[VRFW.SaveImport]] PlayerTraining.FromInazumaFantasy copies it once per slot.

local J = require "lib/serde_json"

local M = {}

M.BLOB = "training.json"
local FILE_VERSION, HISTORY = 1, 8

local function hex8(v)
  return string.format("%04X%04X", math.floor(v / 65536), v % 65536)
end

require "VRFW/lib/basics"
local function int(v) return VRFW.value.int(v, 0) end

local function same(a, b)
  for i = 1, 8 do
    if a[i] ~= b[i] then return false end
  end
  return true
end

function M.empty() return { version = FILE_VERSION, chars = {} } end

-- the blob of `slot`: nil blob = empty; unreadable / bad JSON = nil + why
function M.load(slot)
  local text, why = VRFW.save.blob(M.BLOB, slot)
  if why then return nil, tostring(why) end
  if not text then return M.empty() end
  local j, bad = VRFW.json.decode(text)
  if type(j) ~= "table" then return nil, "bad JSON: " .. tostring(bad) end
  local f = { version = tonumber(j.version) or FILE_VERSION, chars = {} }
  if type(j.chars) == "table" then
    for k, e in pairs(j.chars) do
      if type(k) == "string" and type(e) == "table" then
        local hist = {}
        if type(e.hist) == "table" then
          for _, s in ipairs(e.hist) do
            if type(s) == "table" and type(s.g) == "table" then
              local g = {}
              for i = 1, 8 do g[i] = int(s.g[i]) end
              hist[#hist + 1] = { g = g, suerte = int(s.suerte) }
            end
          end
        end
        f.chars[k] = { param_id = int(e.param_id), hist = hist }
      end
    end
  end
  return f
end

-- serde_json::to_string_pretty of the plugin's SlotFile (chars in BTreeMap order)
function M.encode(f)
  local keys = {}
  for k in pairs(f.chars) do keys[#keys + 1] = k end
  table.sort(keys)
  local chars = {}
  for _, k in ipairs(keys) do
    local e = f.chars[k]
    local hist = {}
    for i, s in ipairs(e.hist) do
      hist[i] = J.obj({ { "g", J.arr(s.g, 8) }, { "suerte", s.suerte } })
    end
    chars[#chars + 1] = { k, J.obj({ { "param_id", e.param_id }, { "hist", J.arr(hist, #hist) } }) }
  end
  return J.encode(J.obj({ { "version", f.version }, { "chars", J.obj(chars) } }))
end

function M.save(f, slot)
  return VRFW.save.blob_write(M.BLOB, M.encode(f), slot)
end

-- the Suerte delta of character `hdl` (variant `pid`) whose current prm_growth[0..7] is `g` (Lua 1..8)
function M.suerte(f, hdl, pid, g)
  local e = f.chars[hex8(hdl)]
  if not e or e.param_id ~= pid then return 0 end
  for _, s in ipairs(e.hist) do
    if same(s.g, g) then return s.suerte end
  end
  return 0
end

-- record a commit; false when nothing had to be written (no history and Suerte 0)
function M.record(f, hdl, pid, g, suerte)
  local k = hex8(hdl)
  local e = f.chars[k]
  local fresh = not (e and e.param_id == pid)
  if fresh and suerte == 0 then return false end
  if fresh then
    e = { param_id = pid, hist = {} }
    f.chars[k] = e
  end
  local kept = {}
  for _, s in ipairs(e.hist) do
    if not same(s.g, g) then kept[#kept + 1] = s end
  end
  local copy = {}
  for i = 1, 8 do copy[i] = g[i] end
  table.insert(kept, 1, { g = copy, suerte = suerte })
  while #kept > HISTORY do kept[#kept] = nil end
  e.hist = kept
  return true
end

return M
