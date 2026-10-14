-- ===== EVT hiper_card BEGIN ===== (shared Hiper card component; docs/game/hiper/plate-hiper-page.md «Shared card»)
-- 2026-10-04 (user: «dentro de la tabla de habilidades tiene que verse igual ... un componente común para que si se
-- edita en una, se edite en otra»): the rules of a Hiper card that both screens draw live HERE, once:
--   * the personal plate's Hiper page (plate_hiper_plate, evt_plate_hiper_graft.lua: EVT_PHI.*),
--   * the techniques screen's Hiper panel (ss2_menus, evt_skill_slot_menu.lua: PL.Hiper*).
-- Included by both files (graft include «@HIPER_CARD@»); edit this file, not copies. Each screen keeps only its own
-- layers (which layer holds the band / portrait / gauge); what a card shows and how is decided by EVT_HC.
-- No main-chunk locals (both menus are near the 200-local limit): everything lives in the global EVT_HC.
EVT_HC = EVT_HC or {}
EVT_HC.SKILL_INFO = 2580586398       -- CMND_GET_SOCCER_SKILL_INFO (skill, 13 aura type | 16 change skill | 11 cost)
EVT_HC.MC_TYPE = 6                   -- aura type «Modo cambio»
EVT_HC.TEAM02 = 3964676290           -- #/menu/102_team/team02/team02_02/<LG>/team02_02.g4tx
EVT_HC.SP_RGB = {0.32, 0.72, 1.0}
EVT_HC.TENS_RGB = {0.99, 0.51, 0.0}   -- round 12: the retail TENSIÓN orange (number back to it on a tension card)
EVT_HC.PEG_RGB = {0.72, 0.42, 1.0}   -- the PEG gauge / label / number tint (the match HUD's PEG purple)

function EVT_HC.Log(...)
  pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "hiper_card", ...)
end

function EVT_HC.AuraType(skill)
  local ok, t = funcLuaCommand(EVT_HC.SKILL_INFO, skill or 0, 13)
  if ok and type(t) == "number" then
    return t
  end
  return nil
end

function EVT_HC.IsModeChange(skill)
  return EVT_HC.AuraType(skill) == EVT_HC.MC_TYPE
end

-- ---- header: band, aura-type icon, name (the retail team00_30 aura window meshes) --------------------------------
-- The band is the game's own background of the aura type (team00_30.g4tx header sprites, chosen as retail
-- UpdateKeshinDetailInfo & co. do: family by aura type SKILL_INFO 13, 01..05 by element SKILL_INFO 7);
-- docs/game/skill-slots.md "Aura type backgrounds".
-- [aura type] = {base01 .. base05}; index = element 1 wind, 2 forest, 3 fire, 4 mountain, 5 void (else 01, as retail)
EVT_HC.BANDS = {
  [0] = {1716659057, 4284183243, 2287747677, 372824062, 1631577960},   -- fs_base     keshin
  [1] = {1742805750, 4276636492, 2314173402, 395046521, 1619844847},   -- fsa_base    keshin armed
  [2] = {3558327990, 1293850380, 974759834, 2759668281, 3547988655},   -- mixi_base   miximax
  [3] = {2619781135, 87024053, 1915277603, 3964421248, 2605413398},    -- soul_base   soul (tótem)
  [4] = {1514509020, 3276587878, 3024876528, 707749459, 1562924741},   -- kizuna_base kizuna trans
  [5] = {4250578944, 1683218874, 324325676, 2368750735, 4197938201},   -- power_base  awakening power
  [6] = {3293713115, 1566262113, 710702071, 3023627860, 3275740866},   -- mode_base   mode change
}
-- the aura-type icon of the band's left slot (icon_common.g4tx onto icon_fs_area_dmy01): keshin icon_sp_area05,
-- armed 06, miximax 07, soul 08, kizuna 09, awakening power 10, mode change 11
EVT_HC.TYPE_ICON = {[0] = 1815339204, 4114264446, 2185069032, 310549625, 1703259375, 88220938, 1917130140}
EVT_HC.TEX_T30 = 2815298114         -- #/menu/102_team/team00/team00_30/<LG>/team00_30.g4tx

-- the band sprite of an aura skill; element 5 of a common skill (800895612) counts as 6 and, like any other value
-- without a band, falls back to 01 (retail Update*DetailInfo)
function EVT_HC.Band(skill)
  local t = EVT_HC.AuraType(skill)
  local fam = t ~= nil and EVT_HC.BANDS[t] or nil
  if fam == nil then
    return nil
  end
  local ok, e = funcLuaCommand(EVT_HC.SKILL_INFO, skill, 7)
  if ok and e == 5 then
    local okc, common = funcLuaCommand(800895612, skill)
    if okc and common then
      e = 6
    end
  end
  local band = ok and type(e) == "number" and fam[e] or nil
  return band or fam[1]
end

-- band + type icon + name on a team00_30 aura window (or its clone) instance; returns the icon (nil = none)
function EVT_HC.Header(A, skill, name, inst)
  inst = inst or 0
  local band = EVT_HC.Band(skill)
  if band ~= nil then
    funcLuaMenuCommand(558735651, A, EVT_HC.TEX_T30, band, 1716659057 --[[fs_base01]], 0, inst)
  end
  funcLuaMenuCommand(3405944500, A, 734954092 --[[_fs_base01]], true, inst)
  local t = EVT_HC.AuraType(skill)
  local icon = t ~= nil and EVT_HC.TYPE_ICON[t] or nil
  if icon ~= nil then
    funcLuaMenuCommand(558735651, A, 2320109963 --[[icon_common.g4tx]], icon, 4285917355 --[[icon_fs_area_dmy01]], 0, inst)
  end
  funcLuaMenuCommand(3405944500, A, 1605611365 --[[_icon_fs_area_dmy01]], icon ~= nil, inst)
  if type(name) == "string" then
    funcLuaMenuCommand(1083631230, A, 2915321899 --[[_text_fs01]], name, inst)
    funcLuaMenuCommand(2735666188, A, 2915321899, true, inst)
  end
  return icon
end

-- the skill's description (as the retail SetupPersonalPlateSkillDetailInfo: SKILL_INFO 5 -> text), "" = none
function EVT_HC.Desc(skill)
  local ok, id = funcLuaCommand(EVT_HC.SKILL_INFO, skill, 5)
  if not ok or id == nil then
    return ""
  end
  local okt, s = pcall(funcLuaCommand, 4113915188, id)
  return (okt and type(s) == "string") and s or ""
end

-- ---- «Modo cambio»: the equipped change of the player (vr-loader CMND_EVT_MC_GET; a copy asks its owner) ----------
-- nil or {face = face key, name = partner name, chara = partner chara id}
function EVT_HC.McGet(chara, skill)
  if chara == nil or chara == 0 or not EVT_HC.IsModeChange(skill) then
    return nil
  end
  local cmd = CALC_CRC("CMND_EVT_MC_GET")
  local ok, exists, pparam, pchara = pcall(funcLuaCommand, cmd, chara)
  if not ok or not exists then
    local oko, owner = pcall(funcLuaCommand, CALC_CRC("CMND_EVT_CHARA_OWNER"), chara)
    if oko and type(owner) == "number" and owner ~= 0 and owner ~= chara then
      ok, exists, pparam, pchara = pcall(funcLuaCommand, cmd, owner)
    end
  end
  if not ok or not exists or type(pparam) ~= "number" or pparam == 0 then
    return nil
  end
  local m = {chara = pchara or 0}
  local okk, face = pcall(funcLuaCommand, 347353059, pparam)
  m.face = (okk and type(face) == "number" and face ~= 0) and face or m.chara
  local okn, a, b = pcall(funcLuaCommand, 4060384944 --[[CMND_GET_CHARA_INFO]], m.chara, 10)
  m.name = (okn and type(b) == "string" and b) or (okn and type(a) == "string" and a) or nil
  return m
end

-- the card's title: a Mix-Max = the move's name only («Miximax Trans»: owner 2026-10-12, never the player's),
-- «Modo cambio: <partner>», else the skill's own name
function EVT_HC.Title(name, fusion, mc)
  if fusion ~= nil then
    return name or "Miximax Trans"
  end
  if mc ~= nil and mc.name ~= nil then
    return (name or "Modo cambio") .. ": " .. mc.name
  end
  return name
end

-- the whole card name: the title, plus the pool of a PEG / SP spirit (not for a fusion / mode change)
function EVT_HC.CardName(skill, name, fusion, mc)
  local t = EVT_HC.Title(name, fusion, mc)
  if fusion == nil and mc == nil then
    t = EVT_HC.PoolName(t, EVT_HC.PegInfo(skill))
  end
  return t
end

-- ---- portrait: a partner drawn as retail draws a miximax partner (UpdateMixiMaxDetailInfo) -----------------------
-- A = a team00_30 aura window (or a clone with its meshes): _icon_chr_dmy01 (200 px, mask icon_chr_win_msk01), face
-- type 12; no type-12 face for the key -> the plain chara icon the bank / dock lists draw. Both portrait slots cleared
-- first (a plain-icon fallback leaks into the next draw otherwise). ctx = the appearance context that lets the
-- partner be drawn on purpose (module appearance: «plate_page», «skill_panel»).
EVT_HC.CHR_MESH, EVT_HC.CHR_SLOT = 478320441, 3237726902   -- _icon_chr_dmy01 / icon_chr_dmy01
EVT_HC.FS_MESH, EVT_HC.FS_SLOT = 2449339029, 1051570875     -- _icon_fs_dmy01 / icon_fs_dmy01
function EVT_HC.Partner(A, face, ctx, inst)
  inst = inst or 0   -- layer instance (2026-10-06: the match HUD's RB plates draw 2 cards; the pages use 0)
  funcLuaMenuCommand(4176779611 --[[clear face icon]], A, inst, EVT_HC.FS_SLOT)
  funcLuaMenuCommand(4176779611 --[[clear face icon]], A, inst, EVT_HC.CHR_SLOT)
  funcLuaMenuCommand(3405944500 --[[MESH_VISIBLE]], A, EVT_HC.FS_MESH, false, inst)
  if face == nil or face == 0 then
    funcLuaMenuCommand(3405944500, A, EVT_HC.CHR_MESH, false, inst)
    return false
  end
  funcLuaMenuCommand(3405944500, A, EVT_HC.CHR_MESH, true, inst)
  pcall(funcLuaCommand, 3148141229 --[[CMND_EVT_APPEARANCE]], ctx or "plate_page", face)
  local has = funcLuaMenuCommand(2208175668 --[[has a miximax face icon]], face)
  if has then
    funcLuaMenuCommand(346643487 --[[SwapLayerFaceIconTex]], A, inst, EVT_HC.CHR_MESH, EVT_HC.CHR_SLOT, face, 0, 12, true,
      true, true, 5)
  else
    local force = IsEnableForceCharaInvalidUseTarget ~= nil and IsEnableForceCharaInvalidUseTarget()
    if force then
      SetDisableForceCharaInvalidUseTarget()
    end
    funcLuaMenuCommand(552280324, A, inst, false, EVT_HC.CHR_MESH, EVT_HC.CHR_SLOT, 0, 0, face)
    if force then
      SetEnableForceCharaInvalidUseTarget()
    end
  end
  EVT_HC.Log("partner", tostring(A), tostring(face), tostring(has))
  return true
end

-- ---- the card's portrait: ONE rule for the player page's Hiper card and the skill table's aura card ----------------
-- (2026-10-06, round 14: the skill table showed a white block where the partner face goes). A = a team00_30 aura
-- window or its clone. A miximax / mode change partner (fusion.face / mc.face) through EVT_HC.Partner; otherwise the
-- aura's own character (SKILL_INFO 17) on the slot its type uses (keshin / armed / soul: _icon_fs_dmy01 type 8 / 14,
-- miximax: _icon_chr_dmy01 type 12), as retail. Both slots cleared first.
EVT_HC.FACE_BY_TYPE = {[0] = {2449339029, 1051570875, 8}, [1] = {2449339029, 1051570875, 8},
  [2] = {478320441, 3237726902, 12}, [3] = {2449339029, 1051570875, 14}}
function EVT_HC.Portrait(A, skill, fusion, mc, ctx, inst)
  inst = inst or 0
  funcLuaMenuCommand(3405944500, A, EVT_HC.FS_MESH, false, inst)
  funcLuaMenuCommand(3405944500, A, EVT_HC.CHR_MESH, false, inst)
  funcLuaMenuCommand(4176779611 --[[clear face icon]], A, inst, EVT_HC.FS_SLOT)
  funcLuaMenuCommand(4176779611 --[[clear face icon]], A, inst, EVT_HC.CHR_SLOT)
  local partner = (fusion ~= nil and fusion.face) or (mc ~= nil and mc.face) or nil
  if fusion ~= nil or mc ~= nil then
    EVT_HC.Partner(A, partner, ctx, inst)
    return partner
  end
  local t = EVT_HC.AuraType(skill)
  local face = t ~= nil and EVT_HC.FACE_BY_TYPE[t] or nil
  local okc, cid = funcLuaCommand(EVT_HC.SKILL_INFO, skill, 17)
  if okc and cid ~= nil and cid ~= 0 and face ~= nil then
    funcLuaMenuCommand(3405944500, A, face[1], true, inst)
    funcLuaMenuCommand(346643487 --[[SwapLayerFaceIconTex]], A, inst, face[1], face[2], cid, 0, face[3], true, true, true, 5)
    return cid
  end
  return nil
end

-- ---- the spirit's move ---------------------------------------------------------------------------------------------
-- the supertécnica a Hiper card shows under its band: the game's change skill (SKILL_INFO 16), else the loader's
-- (armed forms: their keshin's). A mode change has none (its change skill is the command itself) and no TENSIÓN.
function EVT_HC.AuraMove(skill)
  if EVT_HC.IsModeChange(skill) then
    return false, 0
  end
  local ok, move = funcLuaCommand(EVT_HC.SKILL_INFO, skill, 16)
  if ok and type(move) == "number" and move ~= 0 then
    return true, move
  end
  local okl, m, keshin = pcall(funcLuaCommand, CALC_CRC("CMND_EVT_AURA_MOVE"), skill)
  if okl and type(m) == "number" and m ~= 0 then
    return true, m
  end
  if okl and type(keshin) == "number" and keshin ~= 0 then
    local okk, km = funcLuaCommand(EVT_HC.SKILL_INFO, keshin, 16)
    if okk and type(km) == "number" and km ~= 0 then
      return true, km
    end
  end
  return false, 0
end

-- ---- PEG (keshin / armour) or SP (totem) ---------------------------------------------------------------------------
-- nil or {kind = 1 PEG | 2 SP, pool, cost = the move's cost in it}
function EVT_HC.PegInfo(aura)
  local ok, has, kind, pool, cost = pcall(funcLuaCommand, CALC_CRC("CMND_EVT_PEG_INFO"), aura or 0)
  if ok and has == true and type(pool) == "number" and pool > 0 then
    return {kind = kind, pool = pool, cost = cost or 0}
  end
  return nil
end

-- the TENSIÓN group of a team02_02 layer in the PEG look (2026-10-04, in game): CMND_SET_PRIM_COLOR tints the number
-- primitive only and the label slot took the PEG sprite badly, so the look is made of sprites
-- (research/scripts/plate_peg_build.py, team02_02): the lit squares -> evt_tension_on_peg (purple), the «T» after the
-- number -> evt_gtxt_peg_t («PEG», user: «el PEG debería sustituir la T»), the «TENSIÓN» label and the track hidden,
-- the number purple. on = false = the retail look back. CALL IT AFTER the group's locator _pos_tension01 is shown:
-- showing a locator shows all its meshes again.
function EVT_HC.PegLook(L, inst, on, kind)
  local sp = on and kind == 2
  -- round 12 (Nacho: «100» white on the white card): off = the retail TENSIÓN orange (team02_02 gtxt_t01 / gtxt_tension01
  -- pixels 252, 130, 0), not white: SET_PRIM_COLOR replaces the number's tint
  local c = on and (sp and EVT_HC.SP_RGB or EVT_HC.PEG_RGB) or EVT_HC.TENS_RGB
  local ok1, r1 = pcall(funcLuaMenuCommand, 558735651, L, EVT_HC.TEAM02, on and CALC_CRC(sp and "evt_tension_on_sp" or "evt_tension_on_peg") or CALC_CRC("tension_on01"),
    CALC_CRC("tension_on01"), 0, inst)
  local ok2, r2 = pcall(funcLuaMenuCommand, 558735651, L, EVT_HC.TEAM02, on and CALC_CRC(sp and "evt_gtxt_sp_t" or "evt_gtxt_peg_t") or CALC_CRC("gtxt_t01"),
    CALC_CRC("gtxt_t01"), 0, inst)
  -- 2026-10-05 (in game: a white square with a small «TENSIÓN» where the «PEG» after the number should be, while the
  -- squares swap right): what the swaps answered, for the first calls (loader.log «hiper_card peg look»);
  -- research/scripts/find_sprite.py says in which atlas / texture page each retail sprite lives.
  -- 2026-10-06: the _gtxt_t01 quad keeps its texture PAGE on a swap and only takes the new sprite's UVs, so a picture
  -- packed in another page drew a piece of team02_02 (its white panel + «TENSIÓN» cut = «TENSK»); the T pictures
  -- and the squares now live in team02_02's own page (plate_peg_build.py grows it). The log is one string (the lua
  -- log line kept only its first 8 values: the T answer was cut off)
  EVT_HC.PEG_LOGS = (EVT_HC.PEG_LOGS or 0) + 1
  if on and EVT_HC.PEG_LOGS <= 8 then
    EVT_HC.Log("peg look", string.format("layer %s inst %s kind %s squares %s/%s T %s/%s", tostring(L), tostring(inst),
      tostring(kind), tostring(ok1), tostring(r1), tostring(ok2), tostring(r2)))
  end
  pcall(funcLuaMenuCommand, 558735651, L, EVT_HC.TEAM02, CALC_CRC("gtxt_tension01"), CALC_CRC("gtxt_tension01"), 0, inst)
  funcLuaMenuCommand(3405944500, L, CALC_CRC("_gtxt_tension01"), not on, inst)
  funcLuaMenuCommand(3405944500, L, CALC_CRC("_tension_off01"), not on, inst)
  funcLuaMenuCommand(3405944500, L, CALC_CRC("_gtxt_t01"), true, inst)
  -- Keep the obsolete label transparent even if a parent show restores mesh visibility.
  pcall(funcLuaMenuCommand, 2219773080, L, inst, CALC_CRC("_gtxt_tension01"), on and 0 or 1)
  pcall(funcLuaMenuCommand, 2219773080, L, inst, CALC_CRC("_tension_off01"), on and 0 or 1)
  pcall(funcLuaMenuCommand, 855211291 --[[CMND_SET_PRIM_COLOR]], L, inst, 3424269865 --[[number prim]], c[1], c[2], c[3])
  -- 2026-10-07 (Nacho: «80T» with a white patch behind the last digit and the «T»): the number field's 24 x 24
  -- placeholder _num_tension_dmy01 (under the last digit) came back when the caller showed _pos_tension01 (a shown
  -- locator shows all its meshes); off here, after every show
  funcLuaMenuCommand(3405944500, L, CALC_CRC("_num_tension_dmy01"), false, inst)
end

-- the pool (keshin / armour PEG, totem SP) goes into the card's name, as the extra bands do («Sirena  ·  PEG 170»;
-- 2026-10-04, user: the big «PEG 170» on the AT slot was out of place)
function EVT_HC.PoolName(name, peg)
  if name == nil or peg == nil then
    return name
  end
  return string.format("%s  ·  %s %d", name, peg.kind == 2 and "SP" or "PEG", math.floor(peg.pool + 0.5))
end

-- the AT slot of a team02_02 layer back to the retail «AT» label (the pool is no longer drawn there)
function EVT_HC.PegPool(L, peg)
  pcall(funcLuaMenuCommand, 558735651, L, EVT_HC.TEAM02, CALC_CRC("gtxt_cmd_at01"), CALC_CRC("gtxt_cmd_at01"), 0, 0)
  pcall(funcLuaMenuCommand, 855211291, L, 0, 2223127589, 1, 1, 1)
end

-- the gauge's lit squares: cost / scale × 10 (retail), at least 1 when the scale is known; PEG mode: scale = the pool (2026-10-04: pool / 10 lit every square)
function EVT_HC.Steps(cost, scale)
  if type(cost) ~= "number" or scale == nil or scale <= 0 then
    return 0
  end
  return math.min(10, math.max(1, math.floor(cost / scale * 10 + 0.5)))
end
-- ===== EVT hiper_card END =====
