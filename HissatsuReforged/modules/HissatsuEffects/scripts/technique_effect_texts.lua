-- The sentences of the behaviour rules that describe a move, for the move card: every active mod's rule files
-- ([[rule]] with `text` and `when.technique`, or `when.rival.technique` for a rule about the move's opponent), the text in the game's language. Read by the graft skill_card (page 2).
-- CMND_HISSATSUEFFECTS_MOVE_RULE_TEXTS(move) -> { count = n, [1..n] = sentence } (count = 0: no rule describes it).

HissatsuEffects = HissatsuEffects or {}
HissatsuEffects.RuleTexts = HissatsuEffects.RuleTexts or {}
local RuleTexts = HissatsuEffects.RuleTexts

local FOLDERS = { "rules", "content/rules", "features/*/content/rules" }

local cache = nil

local u32 = require("VRFW/lib/ids").u32

local function as_list(v)
  if type(v) == "table" then
    return v
  end
  if v ~= nil then
    return { v }
  end
  return {}
end

-- a move named in a rule (internal key, <mod>.<name> or id) -> its id, nil = unknown
local function move_id(ref)
  if type(ref) == "number" then
    return u32(ref)
  end
  if type(ref) ~= "string" or ref == "" then
    return nil
  end
  local ok, id = pcall(VRFW.technique, ref)
  if ok and id ~= nil and u32(id) ~= 0 then
    return u32(id)
  end
  return nil
end

-- the text of a key in the game's language; a key written with the mod's prefix is also tried with the mod's
-- internal id (the text engine registers keys under the internal id); "" = none
local function text_of(key, mod)
  local ok, v = pcall(VRFW.text, key)
  if ok and type(v) == "string" and v ~= "" then
    return v
  end
  local rest = string.match(key, "^[^%.]+%.(.+)$")
  if rest ~= nil and mod ~= nil then
    local ok2, v2 = pcall(VRFW.text, tostring(mod) .. "." .. rest)
    if ok2 and type(v2) == "string" and v2 ~= "" then
      return v2
    end
  end
  return ""
end

-- move id -> list of { key, mod } (load order, each key once)
local function load_all()
  if cache ~= nil then
    return cache
  end
  cache = {}
  local ok, files = pcall(VRFW.files.declarations, FOLDERS)
  if not ok or type(files) ~= "table" then
    VRFW.warn("technique effect texts: the rule files could not be read: " .. tostring(files))
    return cache
  end
  for _, f in ipairs(files) do
    local rules = type(f.data) == "table" and f.data.rule or nil
    for _, r in ipairs(type(rules) == "table" and rules or {}) do
      local key = type(r) == "table" and type(r.text) == "string" and r.text or ""
      local when = type(r) == "table" and type(r.when) == "table" and r.when or {}
      if key ~= "" and r.enabled ~= false then
        if not string.find(key, ".", 1, true) then
          key = tostring(f.mod) .. "." .. key
        end
        -- a rule about the opponent of a move (`when.rival.technique`, no `when.technique`) describes that move
        local refs = as_list(when.technique)
        if #refs == 0 and type(when.rival) == "table" then
          refs = as_list(when.rival.technique)
        end
        for _, ref in ipairs(refs) do
          local id = move_id(ref)
          if id ~= nil then
            local list = cache[id] or {}
            local seen = false
            for _, e in ipairs(list) do
              if e.key == key then
                seen = true
              end
            end
            if not seen then
              list[#list + 1] = { key = key, mod = f.mod }
            end
            cache[id] = list
          end
        end
      end
    end
  end
  return cache
end

-- CMND_HISSATSUEFFECTS_MOVE_RULE_TEXTS(move)
function RuleTexts.OfMove(move)
  local out = { count = 0 }
  for _, e in ipairs(load_all()[u32(move)] or {}) do
    local s = text_of(e.key, e.mod)
    if s ~= "" then
      out.count = out.count + 1
      out[out.count] = s
    end
  end
  return out
end
