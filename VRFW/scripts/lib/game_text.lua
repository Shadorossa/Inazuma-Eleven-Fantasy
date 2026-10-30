-- Rows of the game's text tables (data/common/text/<language>/<table>.cfg.bin) in a script: names of characters,
-- cards and teams in a game language, read once per table and language.
--   require "VRFW/lib/game_text"     -- sets VRFW.game_text in this VM (and returns the library)
--   GT.language(code)              -> the text folder of a game language code (CMND_GET_LANGUAGE_CODE); "en" when unknown
--   GT.no_furigana(s)              -> s with each `[kanji/kana]` furigana markup reduced to the kanji, trimmed
--   GT.texts(table, lang[, ids])   -> { [text id] = text } of variant 0: only `ids` (a list) when given, else the whole
--                                     table (one shared table: read it, do not change it); en is read when the
--                                     language has no such file
--   GT.chara_names(ids, lang[, keep_furigana]) -> { [chara_text id] = name } ("" when the id has no name)
--   GT.card_names(cards, lang[, keep_furigana]) -> { [card] = name } ("" when the card has no name)
--   GT.team_names(ids, lang[, keep_furigana])  -> { [team_text id] = name } ("" when the id has no name)
-- Names are furigana-reduced unless keep_furigana. Reads are cached per VM: an id is read once per table and language.

local GT = {}

local TEXT_DIR = "data/common/text/"
local FALLBACK = "en"

local cache = {}   -- "<table>/<lang>" -> { rows = { [id] = text | false }, all = { [id] = text } once the whole table is read }

function GT.language(code)
  local c = tonumber(code)
  if c and c >= 0 and type(VRFW.files.game_languages) == "function" then
    local ok, t = pcall(VRFW.files.game_languages)
    local l = ok and type(t) == "table" and t[math.floor(c) + 1] or nil
    if type(l) == "string" then return l end
  end
  return FALLBACK
end

function GT.no_furigana(s)
  return (s:gsub("%[([^/%]]*)/[^%]]*%]", "%1"):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function read_file(lang, tbl, ids)
  local path = TEXT_DIR .. lang .. "/" .. tbl .. ".cfg.bin"
  if ids == nil then return pcall(VRFW.files.text_rows, path) end
  return pcall(VRFW.files.text_rows, path, ids)
end

local function read(tbl, lang, ids)
  local ok, rows = read_file(lang, tbl, ids)
  if (not ok or type(rows) ~= "table") and lang ~= FALLBACK then
    ok, rows = read_file(FALLBACK, tbl, ids)
  end
  return ok and type(rows) == "table" and rows or nil
end

local function text_of(row)
  local v = type(row) == "table" and row[0] or nil
  return type(v) == "string" and v or false
end

function GT.texts(tbl, lang, ids)
  local key = tbl .. "/" .. lang
  local c = cache[key]
  if c == nil then
    c = { rows = {}, all = nil }
    cache[key] = c
  end
  if ids == nil then
    if c.all == nil then
      c.all = {}
      for id, row in pairs(read(tbl, lang, nil) or {}) do
        local s = text_of(row)
        if s then c.all[id] = s end
      end
      c.rows = c.all
    end
    return c.all
  end
  local need = {}
  if c.all == nil then
    for _, id in ipairs(ids) do
      if c.rows[id] == nil then need[#need + 1] = id end
    end
  end
  if #need > 0 then
    local rows = read(tbl, lang, need) or {}
    for _, id in ipairs(need) do c.rows[id] = text_of(rows[id]) end
  end
  local out = {}
  for _, id in ipairs(ids) do
    local s = c.rows[id]
    if s then out[id] = s end
  end
  return out
end

local function names(tbl, ids, lang, keep_furigana)
  local texts = GT.texts(tbl, lang, ids)
  local out = {}
  for _, id in ipairs(ids) do
    local s = texts[id]
    if s and s ~= "" and not keep_furigana then s = GT.no_furigana(s) end
    out[id] = s or ""
  end
  return out
end

function GT.chara_names(ids, lang, keep_furigana)
  return names("chara_text", ids, lang, keep_furigana)
end

function GT.team_names(ids, lang, keep_furigana)
  return names("team_text", ids, lang, keep_furigana)
end

function GT.card_names(cards, lang, keep_furigana)
  local text_of_card, ids = {}, {}
  for _, card in ipairs(cards) do
    local okb, base = pcall(VRFW.chara.base_of, card)
    local okc, ch = pcall(VRFW.chara.character, okb and base or 0)
    local id = okc and type(ch) == "table" and math.floor(tonumber(ch.name_text) or 0) % 4294967296 or 0
    if id ~= 0 then
      text_of_card[card] = id
      ids[#ids + 1] = id
    end
  end
  local by_id = GT.chara_names(ids, lang, keep_furigana)
  local out = {}
  for _, card in ipairs(cards) do
    out[card] = by_id[text_of_card[card] or 0] or ""
  end
  return out
end

if type(VRFW) == "table" and rawget(VRFW, "game_text") == nil then
  pcall(rawset, VRFW, "game_text", GT)
end

return GT
