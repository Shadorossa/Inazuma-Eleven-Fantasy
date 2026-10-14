-- EVT move icons (docs/framework/technique.md §4c; sprites research/scripts/move_icons_build.py): the badges of a
-- special move's row in every move list, ONE shared row function (EVT_MoveIconsRow) for all of them.
--
-- Retail (SetupCommandActionSkillInfoCategoryIcon, this file) draws one badge in the row's slot _icon_sp_sub_dmy01:
-- shot + skillEffectBitFlag 8 (chain) none, else 4 (long shot) icon_sp_sub01, else 16 (counter shot) icon_sp_sub03;
-- block + 16 icon_sp_sub02; keepers none. The icon SET of a move comes from the technique engine
-- (CMND_VRFW_MOVE_ICONS skill -> known, mask: 1 long shot, 2 counter, 4 shot block, 8 keeper clear / punch; derived
-- from skillEffectBitFlag + category only, never declared on their own); without it (older framework, no build) the same
-- mask is derived here from the game's own flag query. Every badge of the set is drawn, side by side:
--   1st badge: the row's slot (retail sprites; the clear badge «P» only when a mod registers it, see EVT_MI.SPRITE)
--   2nd badge: the row's spare mesh _gtxt_cmd_armed01 (the «Armadura» logo of armed aura rows, which never carry
--              badges) with a 240 x 96 sprite holding the badge right after the first one (evt_icon_sp_sub2_<i>_<g>),
--              for the layouts whose geometry is known (EVT_MI.GEOM[layer] = "a" soccer08_10 / "b" soccer11_09; other
--              grafts may register their own layers). The «Armadura» sprite is put back when the row changes.
--
-- Child of the retail soccer_common bytecode: runs each time a menu VM INCLUDEs LUA_SOCCER_COMMON, after every
-- soccer_common global exists. Only defines / wraps Lua globals (no engine call at load). The wrapper calls retail
-- first and returns its results; it only adds to what retail drew.

EVT_MI = EVT_MI or {}
EVT_MI.prev = EVT_MI.prev or {}
EVT_MI.cache = EVT_MI.cache or {}       -- skill -> mask (per VM)
EVT_MI.armed = EVT_MI.armed or {}       -- [layer][inst] = geometry key while the 2nd badge is on the armed mesh
EVT_MI.logged = EVT_MI.logged or {}
EVT_MI.GEOM = EVT_MI.GEOM or {}
EVT_MI.GEOM[1557009688] = EVT_MI.GEOM[1557009688] or "a"   -- soccer08_10_cmd_act_skill_cmd (match command rows)
EVT_MI.GEOM[1760473337] = EVT_MI.GEOM[1760473337] or "a"   -- soccer08_10_cmd_act_skill_cmd_override
EVT_MI.GEOM[1580043721] = EVT_MI.GEOM[1580043721] or "b"   -- soccer11_09_formation_chara_skill (player page, chara edit)

EVT_MI.CMD = @crc:CMND_VRFW_MOVE_ICONS@
EVT_MI.LOG = @crc:CMND_EVT_LOG@
EVT_MI.SKILL_INFO = 2580586398          -- CMND_GET_SOCCER_SKILL_INFO(skill, 9) -> ok, category
EVT_MI.SKILL_FLAG = 3029125066          -- (skill, bit) -> ok, has (skillEffectBitFlag)
EVT_MI.COMMON = 1875260309              -- (skill, chara) -> the «icon_sp_area00» case of GetSkillCategoryIcon
EVT_MI.SPRITE_CMD = 558735651
EVT_MI.MESH_VIS = 3405944500            -- CMND_SET_MESH_VISIBLE
EVT_MI.ICON_TEX = 502529699             -- #/menu/200_icon/15_icon_common/<LG>/icon_common.g4tx (as the retail row)
EVT_MI.SUB_MESH, EVT_MI.SUB_PH = 559600405, 3992937973      -- _icon_sp_sub_dmy01 / icon_sp_sub_dmy01
EVT_MI.ARMED_MESH, EVT_MI.ARMED_PH = 1206374040, @crc:gtxt_cmd_armed01@
EVT_MI.ARMED_TEX = {a = 2804251149,     -- #/menu/00_soccer/soccer08/soccer08_10/<LG>/soccer08_10.g4tx
  b = 868271091}                        -- #/menu/00_soccer/soccer11/soccer11_09/<LG>/soccer11_09.g4tx
EVT_MI.BITS = {1, 2, 4, 8}              -- drawing order
-- The badges this graft (mod Hissatsu Reforged) ships: long shot, counter shot, shot block. A bit without a sprite here
-- is not drawn (Mask drops it): the keeper clear «P» (bit 8) is registered by another mod's graft (Inazuma Fantasy's
-- move_icons_clear: EVT_MI.SPRITE[8], EVT_MI.SECOND.a/b[8], EVT_MI.TAG[8]). Tables are filled, never replaced, so the
-- grafts' children may run in any order.
EVT_MI.SPRITE = EVT_MI.SPRITE or {}
EVT_MI.SPRITE[1] = 1812000538           -- icon_sp_sub01
EVT_MI.SPRITE[2] = 2181991990           -- icon_sp_sub03
EVT_MI.SPRITE[4] = 4111056544           -- icon_sp_sub02
EVT_MI.SECOND = EVT_MI.SECOND or {}
EVT_MI.SECOND.a = EVT_MI.SECOND.a or {}
EVT_MI.SECOND.b = EVT_MI.SECOND.b or {}
EVT_MI.SECOND.a[1], EVT_MI.SECOND.a[2], EVT_MI.SECOND.a[4] =
  @crc:evt_icon_sp_sub2_long_a@, @crc:evt_icon_sp_sub2_counter_a@, @crc:evt_icon_sp_sub2_block_a@
EVT_MI.SECOND.b[1], EVT_MI.SECOND.b[2], EVT_MI.SECOND.b[4] =
  @crc:evt_icon_sp_sub2_long_b@, @crc:evt_icon_sp_sub2_counter_b@, @crc:evt_icon_sp_sub2_block_b@

function EVT_MI.Flag(skill, bit)
  local ok, r, has = pcall(funcLuaCommand, EVT_MI.SKILL_FLAG, skill, bit)
  return ok and r == true and has == true
end

function EVT_MI.Category(skill)
  local ok, r, cat = pcall(funcLuaCommand, EVT_MI.SKILL_INFO, skill, 9)
  if ok and r then
    return cat
  end
  return nil
end

-- the mask from the game's own flags (no technique engine answer): each property its own badge
function EVT_MI.Derive(skill)
  local cat = EVT_MI.Category(skill)
  local m = 0
  if cat == 1 then
    if EVT_MI.Flag(skill, 4) then
      m = m + 1
    end
    if EVT_MI.Flag(skill, 16) then
      m = m + 2
    end
  elseif cat == 3 then
    if EVT_MI.Flag(skill, 16) then
      m = 4
    end
  elseif cat == 4 then
    if EVT_MI.Flag(skill, 2) then
      m = 8
    end
  end
  return m
end

-- the badge retail drew for this move (0 = none): hidden when the set is empty (a shot with chain + long bits: retail
-- shows long, the set none of chain; kept consistent with the engine's answer)
function EVT_MI.Retail(skill)
  local cat = EVT_MI.Category(skill)
  if cat == 1 then
    if EVT_MI.Flag(skill, 8) then
      return 0
    elseif EVT_MI.Flag(skill, 4) then
      return 1
    elseif EVT_MI.Flag(skill, 16) then
      return 2
    end
  elseif cat == 3 and EVT_MI.Flag(skill, 16) then
    return 4
  end
  return 0
end

function EVT_MI.Mask(skill)
  if type(skill) ~= "number" or skill == 0 then
    return 0
  end
  local c = EVT_MI.cache[skill]
  if c ~= nil then
    return c
  end
  local ok, known, mask = pcall(funcLuaCommand, EVT_MI.CMD, skill)
  local m
  if ok and known == true and type(mask) == "number" then
    m = mask
  else
    m = EVT_MI.Derive(skill)
  end
  -- only the badges some mod ships a sprite for (the clear «P» needs its registering graft)
  for _, b in ipairs(EVT_MI.BITS) do
    if m % (b * 2) >= b and EVT_MI.SPRITE[b] == nil then
      m = m - b
    end
  end
  EVT_MI.cache[skill] = m
  return m
end

-- the bits of a mask in drawing order
function EVT_MI.List(mask)
  local out = {}
  for _, b in ipairs(EVT_MI.BITS) do
    if mask % (b * 2) >= b then
      out[#out + 1] = b
    end
  end
  return out
end

function EVT_MI.Get(t, L, inst)
  local r = t[L]
  return r ~= nil and r[inst] or nil
end

function EVT_MI.Put(t, L, inst, v)
  local r = t[L]
  if r == nil then
    r = {}
    t[L] = r
  end
  r[inst] = v
end

-- the 2nd badge on the armed mesh (only on layers of known geometry); the «Armadura» sprite back when not needed
-- (its visibility is retail's: every retail row sets it for its own move)
function EVT_MI.Second(L, inst, list)
  local g = EVT_MI.GEOM[L]
  if g == nil then
    return
  end
  local cur = EVT_MI.Get(EVT_MI.armed, L, inst)
  if #list >= 2 and EVT_MI.SECOND[g] ~= nil and EVT_MI.SECOND[g][list[2]] ~= nil then
    funcLuaMenuCommand(EVT_MI.SPRITE_CMD, L, EVT_MI.ICON_TEX, EVT_MI.SECOND[g][list[2]], EVT_MI.ARMED_PH, 0, inst)
    funcLuaMenuCommand(EVT_MI.MESH_VIS, L, EVT_MI.ARMED_MESH, true, inst)
    EVT_MI.Put(EVT_MI.armed, L, inst, g)
  elseif cur ~= nil then
    funcLuaMenuCommand(EVT_MI.SPRITE_CMD, L, EVT_MI.ARMED_TEX[cur], EVT_MI.ARMED_PH, EVT_MI.ARMED_PH, 0, inst)
    EVT_MI.Put(EVT_MI.armed, L, inst, nil)
  end
end

-- after a retail row builder that sets the armed mesh's visibility AFTER the badge pass: show the 2nd badge again
function EVT_MI.Again(L, inst)
  if L ~= nil and EVT_MI.Get(EVT_MI.armed, L, inst) ~= nil then
    funcLuaMenuCommand(EVT_MI.MESH_VIS, L, EVT_MI.ARMED_MESH, true, inst)
  end
end

function EVT_MI.Log(skill, mask, L)
  if EVT_MI.logged[skill] then
    return
  end
  EVT_MI.logged[skill] = true
  pcall(funcLuaCommand, EVT_MI.LOG, "move_icons", "row", string.format("%08X", skill % 4294967296), tostring(mask),
    tostring(L), tostring(EVT_MI.GEOM[L]))
end

-- THE row function: the badges of `skill` on row `inst` of layer `L` (chara = the row's chara handle or 0; sub_mesh /
-- sub_ph = the badge slot mesh and its placeholder sprite when a layout names them differently). Returns the mask.
function EVT_MoveIconsRow(L, inst, skill, chara, sub_mesh, sub_ph)
  L, inst, skill = L or 0, inst or 0, skill or 0
  sub_mesh, sub_ph = sub_mesh or EVT_MI.SUB_MESH, sub_ph or EVT_MI.SUB_PH
  EVT_MI.lastCall = {L, inst}
  local mask = 0
  if type(skill) == "number" and skill ~= 0 then
    local okc, common = pcall(funcLuaCommand, EVT_MI.COMMON, skill, chara or 0)
    if not (okc and common == true) then
      mask = EVT_MI.Mask(skill)
    end
  end
  local list = EVT_MI.List(mask)
  if #list > 0 then
    funcLuaMenuCommand(EVT_MI.SPRITE_CMD, L, EVT_MI.ICON_TEX, EVT_MI.SPRITE[list[1]], sub_ph, 0, inst)
    funcLuaMenuCommand(EVT_MI.MESH_VIS, L, sub_mesh, true, inst)
    if #list >= 2 or list[1] == 8 then
      EVT_MI.Log(skill, mask, L)
    end
  elseif skill ~= 0 and EVT_MI.Retail(skill) ~= 0 then
    funcLuaMenuCommand(EVT_MI.MESH_VIS, L, sub_mesh, false, inst)
  end
  EVT_MI.Second(L, inst, list)
  return mask
end

-- THE detail-card function: the property tag of `skill` on the single-move detail card (team02_02: badge
-- _icon_sp_sub_dmy01 + word picture _gtxt_longshoot01; layer `L`, instance `inst`), after the retail card
-- (SetupPersonalPlateSkillDetailInfo) drew its own. One tag slot: the FIRST property of the set in the retail priority
-- (long shot, then counter shot; shot block; keeper clear «P» + «Despeje» when registered); a long + counter shot gets
-- both words in one picture (evt_gtxt_long_counter01, 2026-10-13). Retail's own tag is left
-- alone; only a tag retail does not draw (the clear) is added.
EVT_MI.CARD_SUB_TEX = 2320109963        -- #/menu/200_icon/15_icon_common/icon_common.g4tx (as the retail card)
EVT_MI.CARD_TEX = 3964676290            -- #/menu/102_team/team02/team02_02/<LG>/team02_02.g4tx
EVT_MI.TAG_MESH, EVT_MI.TAG_PH = 1220252763, 3782926831     -- _gtxt_longshoot01 / gtxt_longshoot01
EVT_MI.TAG = EVT_MI.TAG or {}           -- [8] (the clear's «Despeje») comes with the clear badge's graft
EVT_MI.TAG[1] = 3782926831              -- gtxt_longshoot01
EVT_MI.TAG[2] = 1602753691              -- gtxt_counter01
EVT_MI.TAG[4] = 741900120               -- gtxt_shootblock01
EVT_MI.TAG_LONG_COUNTER = @crc:evt_gtxt_long_counter01@

function EVT_MoveIconsDetail(L, inst, skill)
  if type(skill) ~= "number" or skill == 0 then
    return 0
  end
  local mask = EVT_MI.Mask(skill)
  local list = EVT_MI.List(mask)
  -- a long + counter shot: one picture with both retail words (evt_gtxt_long_counter01, move_tags_combined.py)
  local both = list[1] == 1 and list[2] == 2
  if #list == 0 or (list[1] == EVT_MI.Retail(skill) and not both) then
    return mask
  end
  local b = list[1]
  funcLuaMenuCommand(EVT_MI.SPRITE_CMD, L, EVT_MI.CARD_SUB_TEX, EVT_MI.SPRITE[b], EVT_MI.SUB_PH, 0, inst)
  funcLuaMenuCommand(EVT_MI.SPRITE_CMD, L, EVT_MI.CARD_TEX, both and EVT_MI.TAG_LONG_COUNTER or EVT_MI.TAG[b], EVT_MI.TAG_PH, 0, inst)
  funcLuaMenuCommand(EVT_MI.MESH_VIS, L, EVT_MI.SUB_MESH, true, inst)
  funcLuaMenuCommand(EVT_MI.MESH_VIS, L, EVT_MI.TAG_MESH, true, inst)
  EVT_MI.Log(skill, mask, L)
  return mask
end

if EVT_MI.prev.SetupCommandActionSkillInfoCategoryIcon == nil then
  EVT_MI.prev.SetupCommandActionSkillInfoCategoryIcon = SetupCommandActionSkillInfoCategoryIcon
end
if EVT_MI.prev.SetupCommandActionSkillInfoCategoryIcon ~= nil then
  function SetupCommandActionSkillInfoCategoryIcon(a1, a2, a3, a4, a5, a6, a7, ...)
    local r = table.pack(EVT_MI.prev.SetupCommandActionSkillInfoCategoryIcon(a1, a2, a3, a4, a5, a6, a7, ...))
    pcall(EVT_MoveIconsRow, a1, a2, a3, a7, a6, a5)
    return table.unpack(r, 1, r.n)
  end
end
