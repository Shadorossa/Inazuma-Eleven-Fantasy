-- Pose rows, script side (game Lua side: the screen vrfw_pose_row_menu, graft pose_row, and assets\lua\menu\_all\
-- 76_pose_row.lua; docs/framework/pose-row.md). Declarations: every active mod's content\pose_rows\*.toml
-- (`VRFW.pose_row/1`, keys content\types\pose_row.toml): [[VRFW.PoseRow]] = a list screen whose selected entry shows
-- its players as 3D models posing in a row; the entries come from the declaring mod's own command (`source`).
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_POSE_ROW | key crc (crc32 of "<mod>.<name>") | { key, source, pose, models, title, decide, owned, new, label, hint, layout, camera }; nothing = not declared |
-- | CMND_VRFW_POSE_ROW_CARDS | language code, card… | { [i] = { name, position } } of each card (name in that language, position = main_position) |

PoseRow = PoseRow or {}

local D = require "lib/declarations"

require "VRFW/lib/basics"
local GameText = require "VRFW/lib/game_text"
local info, warn = VRFW.logger("pose_row")

local crc = VRFW.crc32

local ROWS = nil         -- key crc -> declaration served
local LAYOUT = nil       -- content\defaults\pose_row.toml

local function text_id(s)
  if type(s) ~= "string" or s == "" then return 0 end
  return crc(s)
end

local function layout()
  if LAYOUT ~= nil then return LAYOUT end
  local t, why = VRFW.files.toml("content/defaults/pose_row.toml")
  if type(t) ~= "table" then
    warn("content/defaults/pose_row.toml: " .. tostring(why))
    t = {}
  end
  LAYOUT = t
  return LAYOUT
end

local function load_rows()
  if ROWS ~= nil then return ROWS end
  ROWS = {}
  local schema, why = D.schema("pose_row")
  if not schema then
    warn(why .. ": no pose row")
    return ROWS
  end
  local L = layout()
  for _, d in ipairs(D.load(schema, warn)) do
    local v = d.v
    local id = crc(d.key)
    ROWS[id] = { key = d.key, source = crc(tostring(v.source)), pose = D.id_of(v.pose) or 0, models = v.models,
                 title = text_id(v.title), decide = text_id(v.decide), owned = text_id(v.owned),
                 new = text_id(v.new), label = text_id(v.label), hint = text_id(v.hint),
                 style = v.style, banner = text_id(v.banner), icon_atlas = v.icon_atlas, icon_sprite = v.icon_sprite,
                 panel_title = text_id(v.panel_title), team = text_id(v.team), page = text_id(v.page), layout = L.layout, camera = L.camera }
    info(string.format("%s: source %s, %d model(s)", d.key, tostring(v.source), v.models))
  end
  return ROWS
end

-- CMND_VRFW_POSE_ROW(key crc) -> the declaration
function PoseRow.Get(key)
  return load_rows()[math.floor(tonumber(key) or 0) % 4294967296]
end

-- CMND_VRFW_POSE_ROW_CARDS(language code, card…) -> { { name, position } … }
function PoseRow.Cards(code, ...)
  local cards, texts, out = { ... }, {}, {}
  for i, c in ipairs(cards) do
    local card = VRFW.chara.card(math.floor(tonumber(c) or 0) % 4294967296)
    local ch = card and VRFW.chara.character(card.base)
    out[i] = { name = "", position = card and card.position or 0, text = ch and ch.name_text or 0 }
    if out[i].text ~= 0 then texts[#texts + 1] = out[i].text end
  end
  local of = GameText.chara_names(texts, GameText.language(code))
  for _, o in ipairs(out) do
    o.name = of[o.text] or ""
    o.text = nil
  end
  return out
end

pcall(load_rows)
