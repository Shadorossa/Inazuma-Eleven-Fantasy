-- Which telop each (language, technique) gets (Nacho's rule, 29/09/2026), for every text language:
--   1. the entries written for that language win; between mods, the one that loads later;
--   2. else the language-neutral entries (`lang = "any"`), the one that loads later;
--   3. else the retail telop (nothing is served).
-- A mod's whole-file override of a telop is an entry of its folder's language. Two mods at the same level over the
-- same (language, technique) = a conflict note (an `any` entry losing to a language entry is the rule).
--
-- entries (load order, then file order): { mod, load_index, technique, langs = "any" | { codes }, source, has_layout,
-- origin, from, value } (`value` = the claim's value as text: equal values of two mods are no conflict).

local M = {}

local TIER_LANG = 2
local TIER_ANY = 1

-- picks: { { lang, id, entry, for_lang } } in (language, telop) byte order
function M.resolve(entries)
  local all = VRFW.lang.list()
  local order = {}
  for i = 1, #entries do order[i] = i end
  -- stable: file order kept inside a mod
  table.sort(order, function(a, b)
    local la, lb = entries[a].load_index, entries[b].load_index
    if la ~= lb then return la < lb end
    return a < b
  end)
  local won, conflicts = {}, {}
  for _, i in ipairs(order) do
    local e = entries[i]
    local langs, tier = e.langs, TIER_LANG
    if e.langs == "any" then langs, tier = all, TIER_ANY end
    for _, l in ipairs(langs) do
      local k = l .. "\0" .. e.technique
      local c = { entry = i, tier = tier, li = e.load_index, owner = e.mod, origin = e.origin, value = e.value, lang = l, id = e.technique }
      local old = won[k]
      if old == nil then
        won[k] = c
      else
        local wins = c.tier > old.tier or (c.tier == old.tier and c.li >= old.li)
        -- every claim is at least TIER_ANY (the conflict level)
        if old.owner ~= c.owner and old.value ~= c.value then
          conflicts[#conflicts + 1] = { lang = l, id = e.technique, winner = wins and c or old, loser = wins and old or c }
        end
        if wins then won[k] = c end
      end
    end
  end
  -- equal levels only, once per (technique, loser, winner) with the languages listed
  local seen, skeys = {}, {}
  for _, c in ipairs(conflicts) do
    if c.loser.tier == c.winner.tier then
      local loser = c.loser.owner .. " (" .. c.loser.origin .. ")"
      local winner = c.winner.owner .. " (" .. c.winner.origin .. ")"
      local sk = c.id .. "\0" .. loser .. "\0" .. winner
      local s = seen[sk]
      if s == nil then
        s = { id = c.id, loser = loser, winner = winner, langs = {} }
        seen[sk] = s
        skeys[#skeys + 1] = sk
      end
      s.langs[#s.langs + 1] = c.lang
    end
  end
  VRFW.sort(skeys)
  for _, sk in ipairs(skeys) do
    local s = seen[sk]
    VRFW.log.warn(string.format("conflict: telop %s [%s] set by %s and %s: %s wins (loads later)", s.id, table.concat(s.langs, ", "), s.loser, s.winner, s.winner))
  end
  local keys = {}
  for k in pairs(won) do keys[#keys + 1] = k end
  VRFW.sort(keys)
  local picks = {}
  for _, k in ipairs(keys) do
    local c = won[k]
    picks[#picks + 1] = { lang = c.lang, id = c.id, entry = c.entry, for_lang = c.tier == TIER_LANG }
  end
  return picks
end

-- The values of «Rótulos personalizados» (the declared languages: `[content.languages] telops` of the enabled mods,
-- in the row's value order), and a WARN for a language the mods wrote telops for that no enabled mod declares.
function M.choices(input, picks)
  local declared = {}
  for _, l in ipairs(input.declared) do declared[l] = true end
  local out = {}
  for _, v in ipairs(input.lang_values) do
    if declared[v.lang] then
      out[#out + 1] = { value = v.value, name = input.option .. "_lang_" .. v.lang, text = v.lang }
    end
  end
  -- the languages some mod wrote telops for (an `any` telop is the same in every language: not counted)
  local written, langs = {}, {}
  for _, p in ipairs(picks) do
    if p.for_lang and not written[p.lang] then
      written[p.lang] = true
      langs[#langs + 1] = p.lang
    end
  end
  VRFW.sort(langs)
  local undeclared = {}
  for _, l in ipairs(langs) do
    if not declared[l] then undeclared[#undeclared + 1] = l end
  end
  if #undeclared > 0 then
    VRFW.log.warn(string.format(
      "telops written for %s but no enabled mod declares %s in [content.languages] telops of its mod.toml: not offered in «Rótulos personalizados» (docs/framework/content-languages.md)",
      table.concat(undeclared, ", "), #undeclared == 1 and "it" or "them"))
  end
  return out
end

return M
