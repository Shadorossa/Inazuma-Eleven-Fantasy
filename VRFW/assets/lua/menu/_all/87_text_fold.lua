-- VRFW_Text: accent and case folding of a UTF-8 text, for search keys and name grouping. The script side has the same
-- table (scripts\lib\text_fold.lua). Definitions only: no engine call at load.
--   VRFW_Text.Fold(s)      -> s with every accented Latin letter as its plain letter, everything lower case
--                             («Ángel Ñandú» -> "angel nandu"); other characters as they are (ASCII lower-cased)
--   VRFW_Text.FoldUpper(s) -> the same, upper case («Ángel» -> "ANGEL")
--   VRFW_Text.Chars(s)     -> the UTF-8 characters of s, one string each
if VRFW_Text == nil then
  local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"

  -- plain letter -> its accented forms (upper and lower case)
  local GROUPS = {
    A = "ÀÁÂÃÄÅàáâãäå", C = "Çç", E = "ÈÉÊËèéêë", I = "ÌÍÎÏìíîï", N = "Ññ", O = "ÒÓÔÕÖØòóôõöø",
    U = "ÙÚÛÜùúûü", Y = "Ýýÿ",
  }

  local T = {}

  function T.Chars(s)
    local out = {}
    for ch in tostring(s or ""):gmatch(UTF8_CHAR) do
      out[#out + 1] = ch
    end
    return out
  end

  local PLAIN = {}
  for plain, list in pairs(GROUPS) do
    for _, ch in ipairs(T.Chars(list)) do
      PLAIN[ch] = plain
    end
  end

  local function lower_char(ch)
    local p = PLAIN[ch]
    if p ~= nil then
      return string.lower(p)
    end
    return string.lower(ch)
  end

  local function upper_char(ch)
    return PLAIN[ch] or string.upper(ch)
  end

  function T.Fold(s)
    return (string.gsub(tostring(s or ""), UTF8_CHAR, lower_char))
  end

  function T.FoldUpper(s)
    return (string.gsub(tostring(s or ""), UTF8_CHAR, upper_char))
  end

  VRFW_Text = T
end
