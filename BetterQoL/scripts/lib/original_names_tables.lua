-- Utilities › original names: the merged text tables and the engine's opens.
--
-- Per text language and selection, a chara_text with every name row of a selected character taken from the game's
-- chara_text_roma (the rest the dub table's) and a team_text with the original team names (data file
-- content\original_names\teams.toml, keyed by the Japanese name) are served as new keys
--   data/common/text/<lang>/<table>_util_names_<signature>.cfg.bin
-- (the signature = FNV-1a 64 of the selected text ids, top bit set: the same names utilities.dll served) and the
-- engine's opens of data/common/text/<lang>/chara_text / team_text are redirected to them (VRFW.files.redirect, one
-- filter per language and table). The opens are recorded (VRFW.files.opened): what each language loaded decides
-- whether a saved change needs the game's text reload.
--
-- «loaded» / «wanted» values: "unknown" (no open seen), "dub", "romaji" (the retail chara_text_roma), or a signature
-- (16 hex digits).

local M = {}

local TEXT_DIR = "data/common/text/"
M.CHARA = "chara_text"
M.ROMA = "chara_text_roma"
M.TEAM = "team_text"
M.SERIES_TEXT = "chara_add_info_text"
local SERVED_TAG = "_util_names_"

M.UNKNOWN, M.DUB, M.ROMAJI = "unknown", "dub", "romaji"

function M.text_key(lang, tbl)
  return TEXT_DIR .. lang .. "/" .. tbl .. ".cfg.bin"
end

function M.served_key(lang, tbl, sig)
  return TEXT_DIR .. lang .. "/" .. tbl .. SERVED_TAG .. sig .. ".cfg.bin"
end

-- the redirect filter of the engine's opens of `tbl` in `lang` (paths are matched lowercase with `/`)
function M.filter(lang, tbl)
  return "/text/" .. lang:lower() .. "/" .. tbl .. ".cfg.bin"
end

-- the signature of a served key (nil for anything else)
function M.sig_of_key(key)
  return type(key) == "string" and key:match(SERVED_TAG .. "(%x+)%.cfg%.bin$") or nil
end

-- ------------------------------------------------------------------------------------------- FNV-1a 64

-- h = (h xor b) * 0x100000001B3 mod 2^64, h as two 32-bit halves (every product stays below 2^53: exact in doubles)
local function fnv_byte(hi, lo, b)
  lo = bit32.bxor(lo, b)
  local p = lo * 0x1B3
  local nlo = p % 0x100000000
  local carry = (p - nlo) / 0x100000000
  local nhi = (carry + hi * 0x1B3 + lo * 0x100) % 0x100000000
  return nhi, nlo
end

-- signature of a sorted list of text ids: nil for none, else 16 hex digits of FNV-1a 64 over each id's 4 LE bytes
-- with the top bit set (utilities.dll's ids_sig)
function M.ids_sig(ids)
  if #ids == 0 then
    return nil
  end
  local hi, lo = 0xcbf29ce4, 0x84222325
  for _, id in ipairs(ids) do
    hi, lo = fnv_byte(hi, lo, bit32.extract(id, 0, 8))
    hi, lo = fnv_byte(hi, lo, bit32.extract(id, 8, 8))
    hi, lo = fnv_byte(hi, lo, bit32.extract(id, 16, 8))
    hi, lo = fnv_byte(hi, lo, bit32.extract(id, 24, 8))
  end
  hi = bit32.bor(hi, 0x80000000)
  return string.format("%08x%08x", hi, lo)
end

-- ------------------------------------------------------------------------------------------- overrides

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- `[kanji/kana]` furigana markup reduced to the kanji
function M.strip_furigana(s)
  local out, rest = {}, s
  while true do
    local i = rest:find("[", 1, true)
    if not i then
      break
    end
    out[#out + 1] = rest:sub(1, i - 1)
    local tail = rest:sub(i + 1)
    local sl, en = tail:find("/", 1, true), tail:find("]", 1, true)
    if sl and en and sl < en then
      out[#out + 1] = tail:sub(1, sl - 1)
      rest = tail:sub(en + 1)
    else
      out[#out + 1] = "["
      rest = tail
    end
  end
  out[#out + 1] = rest
  return trim(table.concat(out))
end

-- teams.toml (`[[team]] ja / name`): Japanese name (furigana stripped) -> original name
function M.team_names(doc)
  local out, n = {}, 0
  for _, t in ipairs(type(doc) == "table" and type(doc.team) == "table" and doc.team or {}) do
    if type(t) == "table" and type(t.ja) == "string" and type(t.name) == "string" and trim(t.name) ~= "" then
      out[M.strip_furigana(t.ja)] = trim(t.name)
      n = n + 1
    end
  end
  return out, n
end

-- the character names to change: every row of `roma` whose id is in `ids` and whose text differs from `dub`'s
function M.chara_overrides(dub, roma, ids)
  local over, n = {}, 0
  for _, id in ipairs(ids) do
    local r = roma[id]
    if r then
      local d = dub[id]
      for var, s in pairs(r) do
        if s ~= "" and (d == nil or d[var] ~= s) then
          over[id] = over[id] or {}
          over[id][var] = s
          n = n + 1
        end
      end
    end
  end
  return over, n
end

-- the team names to change in one language: every row of team_text whose Japanese text (`ja_names`: id -> variant
-- -> name, furigana stripped) is the name of a selected team (`ids`: name text ids) with an original name
function M.team_overrides(ja_names, lang_rows, ids, names)
  local marked, any = {}, false
  for _, id in ipairs(ids) do
    local r = ja_names[id]
    if r then
      for _, nm in pairs(r) do
        if names[nm] then
          marked[nm] = true
          any = true
        end
      end
    end
  end
  local over, n = {}, 0
  if not any then
    return over, 0
  end
  for id, r in pairs(ja_names) do
    for var, nm in pairs(r) do
      if marked[nm] then
        local orig = names[nm]
        local cur = lang_rows[id] and lang_rows[id][var]
        if cur ~= nil and cur ~= orig then
          over[id] = over[id] or {}
          over[id][var] = orig
          n = n + 1
        end
      end
    end
  end
  return over, n
end

-- ------------------------------------------------------------------------------------------- the reload rule

function M.chara_wanted(romaji, custom, chara_sig)
  if romaji then
    return M.ROMAJI
  elseif custom then
    return chara_sig or M.DUB
  end
  return M.DUB
end

function M.team_wanted(romaji, custom, team_sig, all_sig)
  if romaji then
    return all_sig or M.DUB
  elseif custom then
    return team_sig or M.DUB
  end
  return M.DUB
end

-- which loaded tables no longer match the wanted ones: characters, teams. With the game's byte at «Originales» the
-- characters are the retail path's, and a table never seen opened never asks for a reload.
function M.reload_needed(romaji_now, chara_want, chara_loaded, team_want, team_loaded)
  local chara = not romaji_now and chara_loaded ~= M.UNKNOWN and chara_loaded ~= chara_want
  local teams = team_loaded ~= M.UNKNOWN and team_loaded ~= team_want
  return chara, teams
end

function M.loaded_name(s)
  if s == M.UNKNOWN then
    return "not loaded yet"
  elseif s == M.DUB then
    return "dub"
  elseif s == M.ROMAJI then
    return "all original (retail Originales)"
  end
  return "selection " .. tostring(s)
end

return M
