-- Aura Points (mod aura_points): the PEG / SP bars of the match buff row (docs/game/mechanics/aura-costs.md §12.8;
-- docs/refactor/aura-mods-split.md «Aura Points»). Ported on 2026-10-14 from Inazuma Fantasy's graft mx_popup
-- (EVT_AURA_PEG, 2026-10-04 user design) after the owner's report: with Aura Points the armour's entry of this row
-- showed the retail stopwatch (its time in %) instead of the purple PEG bar IF had.
-- * soccer_team_buff_icon_list_menu: the bottom row of team passives and active auras. Each aura user has an entry
--   (portrait soccer00_53_aura_buff_chara_icon + circular time gauge soccer00_54_aura_recast_gauge, instance k = his
--   place among the team's aura users, as the retail UpdateAuraBuffCharaIcon builds it).
-- * For a keshin / armour entry (aura attr 0x01 / 0x02) the purple PEG bar of his pool, for a totem (0x08) the blue SP
--   bar: pool left / max of CMND_AURAPOINTS_PEG(hdl) (scripts\aura_points.lua). The entry's stopwatch is hidden while
--   the bar shows. No pool for him (a team the pools do not apply to, a miximax / mode change entry): nothing changes.
-- * Layer aura_points_buff_bar (11 instances, the mod's content\menus\buff_bar.toml: object aura_points_peg_bar, hung
--   on the portrait's locator by copies of its attach rows), placed every frame on the portrait's local position.
-- * Inazuma Fantasy's mx_popup draws the same bars (and its PE / mode change ones) when it is in this script: then this
--   block draws nothing (IF's global EVT_AP with EVT_AURA_PEG on), so no bar is drawn twice.
-- Engine calls only inside the wrapped callbacks (UpdateAuraBuffCharaIcon, Step); nothing at chunk load. Every engine
-- call goes through pcall.
AuraPoints_BuffBar = AuraPoints_BuffBar or {entries = {}, ready = {}, fill = {}, rates = {}, owners = {}, shown = {}}
local B = AuraPoints_BuffBar
B.ON = true                            -- false: no bar (the retail stopwatch everywhere)
B.BAR_W, B.BAR_H = 60, 12              -- bar frame size (layout units; retail frame 476 x 44)
B.DX, B.DY = 0, 0                      -- extra offset from the portrait's position (layout units)
B.MAX = 11                             -- layer instances (content\menus\buff_bar.toml count)
B.LOGS = B.LOGS or 0                   -- first placements logged (loader.log «aura_points buff bar»)

local CMD_PEG = @crc:CMND_AURAPOINTS_PEG@
local CMD_LOG = @crc:CMND_EVT_LOG@ --[[the loader's log line]]
local LAYER = @crc:aura_points_buff_bar@
local PORTRAIT = 1535165083 --[[soccer00_53_aura_buff_chara_icon]]
local GAUGE = 698939060 --[[soccer00_54_aura_recast_gauge]]
local ATLAS = 1191797350 --[[#/menu/02_btl/btl06/btl06_13/<LG>/btl06_13.g4tx]]
local FILL_SLOT = 1460691304 --[[hp_bar02]]
local FILL_PEG = 351956081 --[[evt_peg_fill01]]
local FILL_SP = 2515711484 --[[evt_sp_fill01]]
local RATE_BAR = 3060237847 --[[hp_bar]]
local RATE_RED = 2546116024 --[[hp_bar_red]]
local MESH_LABEL = 1257514352 --[[_gtxt_stamina01]]
local MESH_EMPTY = 2609329121 --[[_hp_empty01]]
local FRAME_CX, FRAME_CY, FRAME_W, FRAME_H = 332, -838, 476, 44
local CMND_VISIBLE = 711242136 --[[CMND_SET_LAYER_VISIBLE]]
local CMND_IS_VISIBLE = 1262717583 --[[CMND_IS_LAYER_VISIBLE]]
local CMND_OPEN = 629267548 --[[CMND_OPEN_LAYER]]
local CMND_IS_OPEN = 2640875187 --[[CMND_IS_OPEN_LAYER]]
local CMND_IS_LOADING = 3057768039 --[[CMND_IS_LOADING_LAYER]]
local CMND_LOCAL_POS = 2834507455 --[[CMND_GET_LAYER_LOCAL_POS]]
local CMND_SET_POS = 1389957207 --[[CMND_SET_LAYER_LOCAL_POS]]
local CMND_SET_SCALE = 3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]]
local CMND_RATE_INIT = 541357333
local CMND_RATE = 1595998683
local CMND_MESH_VISIBLE = 3405944500 --[[CMND_SET_MESH_VISIBLE]]
local CMND_SWAP_TEX = 558735651 --[[swap a mesh texture: (layer, atlas, new sprite, old sprite, 0, instance)]]
local CMND_MEMBER = 66484325 --[[(team, member, true) -> ok, soccer handle]]
local ATTR_KESHIN, ATTR_ARMOUR, ATTR_TOTEM = 1, 2, 8

local function Menu(...)
  local ok, a, b, c, d = pcall(funcLuaMenuCommand, ...)
  if ok then
    return a, b, c, d
  end
  return nil
end

local function Log(...)
  pcall(funcLuaCommand, CMD_LOG, "aura_points buff bar", ...)
end

-- Inazuma Fantasy's mx_popup draws these bars itself in this script
local function IfDraws()
  return type(rawget(_ENV, "EVT_AP")) == "table" and rawget(_ENV, "EVT_AURA_PEG") == true
end

-- the aura entries the retail row just built: k = 0.. in member order, one per aura user of the team
function B.Collect()
  local out = {}
  local ok0, okt, team = pcall(GetSoccerTeamInfo, 0)
  if not ok0 or not okt or team == nil then
    return out
  end
  local k = 0
  for i = 0, 28 do
    local ok, ok2, hdl = pcall(funcLuaCommand, CMND_MEMBER, team, i, true)
    if ok and ok2 and hdl ~= nil and hdl ~= 0 then
      local oka, has, attr = pcall(GetSoccerCharaInfo, hdl, 26)
      if oka and has and type(attr) == "number" and attr ~= 0 then
        out[#out + 1] = {k = k, hdl = hdl, attr = attr}
        k = k + 1
        if k >= B.MAX then
          break
        end
      end
    end
  end
  return out
end

-- pool left / max of the player's keshin / armour (PEG) or totem (SP); nil = no pool for him now
function B.Rate(hdl, attr)
  if bit32.band(attr or 0, ATTR_KESHIN + ATTR_ARMOUR + ATTR_TOTEM) == 0 then
    return nil
  end
  local ok, has, cur, max, _, _, _, _, soul = pcall(funcLuaCommand, CMD_PEG, hdl or 0)
  if not ok or has ~= true or type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then
    return nil
  end
  return math.max(0, math.min(1, cur / max)), soul == 1 and "sp" or "peg"
end

function B.Hide(k)
  B.shown[k] = false
  B.rates[k] = nil
  if Menu(CMND_IS_OPEN, LAYER, k) == true then
    Menu(CMND_VISIBLE, LAYER, k, false)
  end
end

function B.Draw(e)
  if Menu(CMND_IS_VISIBLE, PORTRAIT, e.k) ~= true then
    B.Hide(e.k)
    return false
  end
  local rate, soul = B.Rate(e.hdl, e.attr)
  if rate == nil then
    B.Hide(e.k)
    return false
  end
  if Menu(CMND_IS_OPEN, LAYER, e.k) ~= true then
    Menu(CMND_OPEN, LAYER, e.k)
    B.ready[e.k] = nil
    B.shown[e.k] = false
    B.rates[e.k] = nil
    return false
  end
  if Menu(CMND_IS_LOADING, LAYER, e.k) == true then
    return false
  end
  if B.owners[e.k] ~= e.hdl then
    B.owners[e.k] = e.hdl
    B.ready[e.k] = nil
  end
  if not B.ready[e.k] then
    B.ready[e.k] = true
    B.fill[e.k] = nil
    B.rates[e.k] = nil
    Menu(CMND_RATE_INIT, LAYER, RATE_BAR, 0, e.k)
    Menu(CMND_RATE_INIT, LAYER, RATE_RED, 0, e.k)
    Menu(CMND_MESH_VISIBLE, LAYER, MESH_LABEL, false, e.k)
    Menu(CMND_MESH_VISIBLE, LAYER, MESH_EMPTY, false, e.k)
  end
  if B.fill[e.k] ~= soul then
    B.fill[e.k] = soul
    Menu(CMND_SWAP_TEX, LAYER, ATLAS, soul == "sp" and FILL_SP or FILL_PEG, FILL_SLOT, 0, e.k)
  end
  -- the entry's stopwatch off, the bar on its place
  Menu(CMND_VISIBLE, GAUGE, e.k, false)
  -- the bar hangs on the portrait's locator (attach rows copied by buff_bar.toml): the portrait's own local position
  local gx, gy = Menu(CMND_LOCAL_POS, PORTRAIT, e.k)
  if type(gx) ~= "number" or type(gy) ~= "number" then
    gx, gy = 0, 0
  end
  -- Better UI (clean_hud) draws the row's icons at 0.85
  local flags = rawget(_ENV, "EVT_UI_FLAGS")
  local scale = (rawget(_ENV, "EVT_UI_PRESET") ~= "off" and type(flags) == "table" and flags.buff_icons == true) and 0.85 or 1
  local sx, sy = B.BAR_W * scale / FRAME_W, B.BAR_H * scale / FRAME_H
  gy = gy - (36 + 2 + 28 * B.BAR_H / FRAME_H / 2) * scale
  local px = gx + B.DX - FRAME_CX * sx
  local py = gy + B.DY - FRAME_CY * sy
  Menu(CMND_SET_SCALE, LAYER, sx, sy, 1, e.k)
  Menu(CMND_SET_POS, LAYER, px, py, 0, e.k)
  if not B.shown[e.k] then
    Menu(CMND_VISIBLE, LAYER, e.k, true)
    B.shown[e.k] = true
    B.rates[e.k] = nil
  end
  -- the rate animation only when the value changed (restarting it every frame leaves a new bar empty)
  if B.rates[e.k] == nil or math.abs(B.rates[e.k] - rate) > 0.0005 then
    B.rates[e.k] = rate
    Menu(CMND_RATE, LAYER, RATE_BAR, 0, rate, e.k, true)
    Menu(CMND_RATE, LAYER, RATE_RED, 0, rate, e.k, true)
  end
  if B.LOGS < 6 then
    B.LOGS = B.LOGS + 1
    Log("entry", e.k, "hdl", string.format("0x%X", e.hdl), "attr", e.attr, soul, string.format("%.2f", rate), "portrait", tostring(gx), tostring(gy), "bar", px, py)
  end
  return true
end

-- every frame: the bars follow the live portraits (cut-ins / a hidden row hide them)
function B.Frame()
  if not B.ON then
    return
  end
  if IfDraws() then
    if not B.yielded then
      B.yielded = true
      for k = 0, B.MAX - 1 do
        B.Hide(k)
      end
      Log("Inazuma Fantasy's mx_popup draws the bars in this script: nothing drawn here")
    end
    return
  end
  local used = {}
  for _, e in ipairs(B.entries) do
    if B.Draw(e) then
      used[e.k] = true
    end
  end
  for k = 0, B.MAX - 1 do
    if not used[k] and B.shown[k] ~= nil then
      B.Hide(k)
    end
  end
end

if B.origUpdate == nil and type(UpdateAuraBuffCharaIcon) == "function" then
  B.origUpdate = UpdateAuraBuffCharaIcon
  function UpdateAuraBuffCharaIcon(...)
    local r = table.pack(B.origUpdate(...))
    if B.ON then
      local ok, ents = pcall(B.Collect)
      B.entries = ok and ents or {}
      pcall(B.Frame)
    end
    return table.unpack(r, 1, r.n)
  end
end
if B.origStep == nil and type(Step) == "function" then
  B.origStep = Step
  function Step(...)
    local r = table.pack(B.origStep(...))
    pcall(B.Frame)
    return table.unpack(r, 1, r.n)
  end
end
