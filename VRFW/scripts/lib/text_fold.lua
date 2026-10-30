-- Accent and case folding of a UTF-8 text, for search keys and name grouping. The menu side has the same table
-- (assets\lua\menu\_all\87_text_fold.lua, VRFW_Text.Fold / FoldUpper).
--   local Fold = require "VRFW/lib/text_fold"   -- any mod's scripts (the framework's own: require "lib/text_fold")
--   Fold.fold(s)       -> s with every accented Latin letter as its plain letter, everything lower case
--                         («Ángel Ñandú» -> "angel nandu"); other characters as they are (ASCII lower-cased)
--   Fold.fold_upper(s) -> the same, upper case («Ángel» -> "ANGEL")
--   Fold.chars(s)      -> the UTF-8 characters of s, one string each
-- Requiring it also sets VRFW.text_fold to the same table in that script's VM.
local M = {}

local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"

-- plain letter -> its accented forms (upper and lower case)
local GROUPS = {
  A = "ÀÁÂÃÄÅàáâãäå", C = "Çç", E = "ÈÉÊËèéêë", I = "ÌÍÎÏìíîï", N = "Ññ", O = "ÒÓÔÕÖØòóôõöø",
  U = "ÙÚÛÜùúûü", Y = "Ýýÿ",
}

function M.chars(s)
  local out = {}
  for ch in tostring(s or ""):gmatch(UTF8_CHAR) do
    out[#out + 1] = ch
  end
  return out
end

local PLAIN = {}
for plain, list in pairs(GROUPS) do
  for _, ch in ipairs(M.chars(list)) do
    PLAIN[ch] = plain
  end
end

local function lower_char(ch)
  local p = PLAIN[ch]
  if p ~= nil then
    return p:lower()
  end
  return ch:lower()
end

local function upper_char(ch)
  return PLAIN[ch] or ch:upper()
end

function M.fold(s)
  return (tostring(s or ""):gsub(UTF8_CHAR, lower_char))
end

function M.fold_upper(s)
  return (tostring(s or ""):gsub(UTF8_CHAR, upper_char))
end

if type(VRFW) == "table" and rawget(VRFW, "text_fold") == nil then
  pcall(rawset, VRFW, "text_fold", M)
end

return M
