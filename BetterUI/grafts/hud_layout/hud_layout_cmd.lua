-- EVT hud_layout (docs/game/ui-redesign.md §11.1z5): layout of the command-action HUD (bottom right of a match).
-- Layout units = pixels of a 1920x1080 screen. soccer08_07 (the Y/X/B/A cluster), soccer08_14 (LB ring),
-- soccer08_19b and soccer08_13 are anchored at the bottom-right corner: x <= 0 from the right edge, y up from the
-- bottom. The action guides (soccer08_17*) hang from locators of soccer08_07; CMND_SET_LAYER_LOCAL_POS on them is
-- relative to that locator. Display only: no input / no engine state is changed. Every engine call is inside a
-- callback (OnSetupLayer, PostStep, the guide status functions the engine calls by name every frame).

EVT_HL_ON = true                  -- false: retail layout (every wrapper passes through)
EVT_HL_HIDE_DASH = true           -- hide «RT Esprintar» and «RT + B Esprint agresivo» (the sprint still works)
EVT_HL_HIDE_FOCUS_FIELD = true    -- hide «LT + B Campo de foco» (soccer08_17_catch_bomb_guide; the focus field still works)
-- «¡Subid!» guide (soccer08_17_go_ahead_guide; retail centre = locator _atc_btn10_l at -1139, 136; text sprite untouched)
EVT_HL_GOAHEAD_X = -342           -- new centre x: under «Pase» (the Y/X/B/A cross is centred at x -342)
EVT_HL_GOAHEAD_Y = 90             -- new centre y («Pase» plate bottom ~123; guide row at 136)
EVT_HL_GOAHEAD_SCALE = 0.85
EVT_HL_GOAHEAD_SQUARE = true      -- square plate of «Chute» / «Pase alto» (soccer08_08 cmd_base01) instead of the pill
-- «RB + LB diana» (soccer08_19b_aura_slot_guide, content x -218..-50, y 270..330): centre height kept
EVT_HL_AURA_SLOT_SCALE = 0.7
EVT_HL_AURA_SLOT_RIGHT = -135     -- right edge of the retail plate mesh (retail -50) at that scale: above the right end
                                  -- of «Esquivar» (-142), clear of «Pase alto» (-270)
EVT_HL_AURA_SLOT_SQUARE = true    -- blue square plate of «Pase alto» (cmd_base01) instead of the pill (guide_pw_base01)
-- 2026-10-02 (Nacho): only the plate behind «RB + LB» bigger, around its own centre; the glyphs and the target icon
-- keep their size and place (node size of _pw_guide01, this layer's instance only: the layout is untouched)
EVT_HL_AURA_SLOT_PLATE_GROW = 1.18
-- «RB + rayo» (soccer08_17b_aura_release_button_guide: RB glyph, aura icon, «Desactivar»; hangs from _atc_btn04_l of
-- soccer08_07). 2026-10-02 (Nacho): the plate of «RB + LB» (the same cmd_base01 rectangle instead of the round pill),
-- as tall as it, the glyphs as big as those of «RB + LB», further left by the Y/X/B/A cross.
EVT_HL_AURA_RELEASE_SCALE = 0.525 -- layer scale: its RB glyph (48 units) as big as the RB glyph of «RB + LB» (36 x 0.7)
EVT_HL_AURA_RELEASE_SQUARE = true -- false: the retail pill on its locator (layer scale only)
EVT_HL_AURA_RELEASE_PAD = 9       -- plate margin left / right of the content (layer units: ~4.7 px, as «RB + LB»)
EVT_HL_AURA_RELEASE_LEFT = 94     -- visible plate's left edge, layout units right of the cross centre: the left edge of
                                  -- the «RB + LB» plate (-248 with the retail cross at -342), 14 right of «Pase alto»
EVT_HL_AURA_RELEASE_DY = 0        -- height: the locator's row (88 below the cross, level with «Pase alto»)
-- «RB + rayo» move-list guide (soccer08_19_skill_open_guide: RB glyph + lightning icon on a round blue pill, right of
-- the Y/X/B/A cross; anchored at the bottom-right corner, no Lua drives it). 2026-10-06 (Nacho): a rectangle with the
-- rounding of the other HUD plates («Pase», «Esquivar»: soccer08_08 cmd_base01 instead of the pill), a bit smaller
-- and a bit further left. Layer scaled around the corner, then moved so the plate's centre lands at the retail centre
-- + (DX, DY).
EVT_HL_SKILL_OPEN_ON = true
EVT_HL_SKILL_OPEN_SCALE = 0.85    -- layer scale (glyph, icon and plate)
EVT_HL_SKILL_OPEN_DX = -40        -- centre shift, layout units (- = left)
EVT_HL_SKILL_OPEN_DY = 0          -- (+ = up)
EVT_HL_SKILL_OPEN_PAD = 8         -- plate margin left / right of the content (layer units)
EVT_HL_SKILL_OPEN_H = 56          -- visible plate height (layer units; the retail pill is 62)
-- 2026-10-14 (Nacho): the action plates of the Y/X/B/A cross that carry «Pase», «Esquivar» and «Disparar»
-- (soccer08_08_cmd_act_base_cmd instances; the plate shows whichever action the engine gave its slot, so the plates are
-- picked by action, not by position) and the «Cancelar» guide plate with the B glyph (soccer08_17_cancel_guide, shown
-- while the move list is open) 20 % smaller around their own centre, so they keep their place on the cross / guide row.
-- «Chute» and «Pase alto» keep the retail size.
EVT_HL_ACTION_PLATE_SCALE = 0.8
-- LB tactics ring (soccer08_14_tactics_screen_guide, retail centre x -130, y 429), moved to the left edge at the height
-- of the cross of the tactics menu (the ring hides while that menu is up)
EVT_HL_TACTICS_LEFT = true
EVT_HL_TACTICS_RING_X = 130       -- centre, layout units from the LEFT edge
EVT_HL_TACTICS_RING_Y = 224       -- centre height (the Y/X/B/A cross of the opened tactics menu is at y 224)
EVT_HL_TACTICS_FLIP = false       -- true: also x scale -1 (icons swap sides; the LB / Tab glyph may be drawn mirrored)
-- the tactics menu LB opens (plates around the Y/X/B/A cross + coach bust) on the left while it is up
EVT_HL_TACTICS_MENU_LEFT = true
EVT_HL_TACTICS_MENU_CROSS_X = 420 -- cross centre, layout units from the LEFT edge (the left plate, narrowed below and
                                  -- pulled in towards the cross, starts at ~30)
-- the four tactics plates (soccer08_12_cmd_act_tactics_cmd, 480 wide) narrower: scaled around their centre and the side
-- plates pulled in so their inner end stays where it was (name text scales with them)
EVT_HL_TACTICS_PLATE_SCALE = 0.75
-- shot zone (ZoneState): the engine asks for «RT Acelerar cursor» (SetCursorSpeedUpButtonGuideStatus) only while the
-- shot cursor is up, i.e. in the zone. That request (kept for EVT_HL_ZONE_HOLD frames) is the zone signal of this menu.
EVT_HL_HIDE_CURSOR_GUIDE = true   -- never draw «RT Acelerar cursor» (RT keeps speeding the cursor up)
EVT_HL_AURA_SLOT_HIDE_IN_ZONE = true  -- no «RB + LB diana» in the zone
EVT_HL_ZONE_HOLD = 20
EVT_HL_SCREEN_W = 1920            -- layout width of a 16:9 screen
-- move list open (docs/game/ui-redesign.md §11.1z7): the engine opens / closes the list of special moves by name with
-- UpdateAnimeMoveOffsetCmdBase(open, instant) (retail local flag3). Retail then plays type «offset» of set «vs» of
-- soccer08_07: _pos_vs01 (the Y/X/B/A cross with its arrows, page dots and the move cards on _cmd03_03 / _cmd03_04)
-- slides 330 left (and _pos_btn01 236), so the open menu sits re-centred. With EVT_HL_LIST_ANCHOR that slide is
-- skipped to its rest pose (the retail helper PlayAnimeMoveOffsetCmdBase(offset, 2, true), as SetupButtonCmdBase does
-- at setup): the cross stays where the closed menu has it and the cards unfold on its left (card 0 on _cmd03_03, 284
-- left of the cross; arrows at -617 / +258 and page dots at -238 around the cross, retail spacing). flag3 itself is
-- untouched (SetupSkillCmdInfo still sees the list open). The other slides (vs offset02, btl) are not touched.
EVT_HL_LIST_ANCHOR = true

local HL_GOAHEAD = 4104611069 --[[soccer08_17_go_ahead_guide]]
local HL_AURA_REL = 3063505148 --[[soccer08_17b_aura_release_button_guide]]
local HL_AURA_SLOT = 964036938 --[[soccer08_19b_aura_slot_guide]]
local HL_RING = 96012645 --[[soccer08_14_tactics_screen_guide]]
local HL_BASE = 1927855329 --[[soccer08_07_cmd_act_btn_cmd_base]]
local HL_COACH = 31978744 --[[soccer08_13_tactics_director_icon]]
local HL_GOAHEAD_ATC_X, HL_GOAHEAD_ATC_Y = -1139, 136 --[[_atc_btn10_l of soccer08_07]]
local HL_RING_X, HL_RING_Y = -130, 429
local HL_SLOT_RIGHT, HL_SLOT_CY = -50, 300 --[[retail right edge / centre height of soccer08_19b]]
local HL_CMND_POS = 1389957207 --[[CMND_SET_LAYER_LOCAL_POS]]
local HL_CMND_SCALE = 3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]]
local HL_CMND_SWAP = 558735651 --[[swap texture (layer, atlas, new sprite, slot sprite, 0, idx)]]
local HL_CMND_GPOS = 499270986 --[[CMND_GET_MESH_GLOBAL_POSITION(layer, idx, node) -> x, y, z]]
local HL_CMND_TACTICS_MODE = 1350751656 --[[CMND_IS_SPECIAL_TACTICS_CMD_MODE]]
local HL_ATLAS_0808 = 1822283221 --[[#/menu/00_soccer/soccer08/soccer08_08/<LG>/soccer08_08.g4tx]]
local HL_NODE_GAIJI = 708999887 --[[_pos_gaiji01: centre of the Y/X/B/A cross]]
local HL_NODE_OUT = 2812881813 --[[soccer08_07_output: layer root]]
local HL_NODE_CMD0101 = 1816929598 --[[_cmd01_01: 128 units right of _pos_gaiji01]]
local HL_SWAPS = {
  {2905228853 --[[cmd_base01]], 106736699 --[[btn_action_base02: plate slot of soccer08_17]]},
  {4119466887 --[[cmd_base_grayout01]], 3926314756 --[[btn_action_grayout01: grey-out slot]]},
}
local HL_SLOT_PLATE = 1883633302 --[[guide_pw_base01: plate slot of soccer08_19b]]
local HL_CMND_NODE_POS = 2575768773 --[[(layer, idx, node, axis 0 x / 1 y, value): node local translation]]
local HL_CMND_NODE_SIZE = 2885415772 --[[(layer, idx, node, sx, sy): node local scale = a mesh's size]]
local HL_SLOT_MESH = 2605774483 --[[_pw_guide01: plate mesh of soccer08_19b, top-left (-82, 26), 168 x 56 under _pos_base01]]
local HL_SLOT_MESH_X, HL_SLOT_MESH_Y, HL_SLOT_MESH_W, HL_SLOT_MESH_H = -82, 26, 168, 56
local HL_REL_MESH = 1408256865 --[[_btn_action_base01: plate mesh of soccer08_17b, 232 x 52 centred on the locator]]
local HL_REL_SLOT = 106736699 --[[btn_action_base02: its sprite slot (the same slot as soccer08_17's plate)]]
-- content of soccer08_17b (layer units, centred in y on 0): RB glyph box _text_btn01 x -108..-60, aura icon -62..-18,
-- «Desactivar» _gtxt_cancel01 -16..104
local HL_REL_CONTENT_L, HL_REL_CONTENT_R = -108, 104
-- cmd_base01 (soccer08_08 atlas, 188 x 92) draws its plate inside a shadow margin: x 20..174, y 20..78
local HL_PLATE_VX0, HL_PLATE_VX1, HL_PLATE_VY0, HL_PLATE_VY1 = 20 / 188, 174 / 188, 20 / 92, 78 / 92
-- _atc_btn04_l (17b's locator) from the cross _pos_gaiji01 (both under _pos_vs01: no slide changes it): layout
-- (117, 66) - (-342, 154). Measured at run time when the engine answers (fallback these).
local HL_REL_ATC_DX, HL_REL_ATC_DY = 459, -88
local HL_NODE_ATC04 = 3000774961 --[[_atc_btn04_l]]
local HL_NODE_CMD0104 = 472306097 --[[_cmd01_04: 76 units above _pos_gaiji01]]
local HL_SKILL_OPEN = 2083118578 --[[soccer08_19_skill_open_guide]]
local HL_SO_MESH = 2201026017 --[[_tech_guide01: the pill mesh, 136 x 72 at (-68, 36) under _pos_base01]]
local HL_SO_SLOT = 3647709000 --[[its sprite slot (the pill)]]
local HL_SO_BASE_X, HL_SO_BASE_Y = -156, 136 --[[_pos_base01 from the corner]]
-- content under _pos_base01 (layer units, centred in y on 0): RB glyph box _text_btn01 x -51..-7, lightning icon
-- _icon_tech_guide01 (-6..54, drawn part 7..44)
local HL_SO_CONTENT_L, HL_SO_CONTENT_R = -51, 44
local HL_TAC_PLATE = 3392405315 --[[soccer08_12_cmd_act_tactics_cmd x4: 0 below, 1 left, 2 above, 3 right of the cross]]
local HL_TAC_HALF_W = 240
local HL_CANCEL_GUIDE = 2027749905 --[[soccer08_17_cancel_guide]]
local HL_BASE_CMD = 556446027 --[[soccer08_08_cmd_act_base_cmd: the 4 action plates of the cross, instances 0..3]]
local HL_BASE_CMD_COUNT = 4
-- action ids the engine gives SetupBaseCmdInfo (index into the retail texture list gtxt_cmd01..): the plates to shrink
local HL_ACTION_PASS = 9 --[[gtxt_cmd09 «Pase»]]
local HL_ACTION_SHOOT_IN_ZONE = 10 --[[gtxt_cmd10 «Disparar»]]
local HL_ACTION_DODGE = 21 --[[gtxt_cmd21 «Esquivar»]]
local HL_SMALL_PLATE_ACTIONS = {
  [HL_ACTION_PASS] = true,
  [HL_ACTION_SHOOT_IN_ZONE] = true,
  [HL_ACTION_DODGE] = true,
}
local hl_plate_action = {}        -- instance index (0..3) -> action id of its last SetupBaseCmdInfo
local hl_plate_ready = {}         -- instance index -> its layer instance has been set up
local hl_plate_scale_sent = {}    -- instance index -> last layer scale sent (nil: none yet)
local hl_zone = 0                 -- frames left of the zone signal
local HL_TYPE_OFFSET = 1493879504 --[[offset: type of set vs, _pos_vs01 0 -> -330 while the move list is open]]
local hl_list_open = false        -- last UpdateAnimeMoveOffsetCmdBase answer (= retail flag3)
local hl_anchor = false           -- the list slide is held at its rest pose

local hl_swapped = false
local hl_menu_dx = 0
local hl_menu_dx_applied = 0
local hl_coach_hidden = false

local function HL_Pack(...)
  return {n = select("#", ...), ...}
end

local function HL_Cmd(...)
  if type(funcLuaMenuCommand) == "function" then
    return pcall(funcLuaMenuCommand, ...)
  end
  return false
end

local function HL_Log(msg)
  if type(funcLuaCommand) == "function" then
    pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "EVT hud_layout " .. msg)
  end
end

local function HL_SwapGoAhead()
  if not EVT_HL_GOAHEAD_SQUARE then
    return
  end
  for i = 1, #HL_SWAPS do
    HL_Cmd(HL_CMND_SWAP, HL_GOAHEAD, HL_ATLAS_0808, HL_SWAPS[i][1], HL_SWAPS[i][2], 0, 0)
  end
  hl_swapped = true
end

local hl_slot_swapped = false
local function HL_SwapAuraSlot()
  hl_slot_swapped = true
  if EVT_HL_AURA_SLOT_SQUARE then
    HL_Cmd(HL_CMND_SWAP, HL_AURA_SLOT, HL_ATLAS_0808, HL_SWAPS[1][1], HL_SLOT_PLATE, 0, 0)
  end
end

-- «RB + rayo»: its pill sprite -> cmd_base01 (retail only swaps the aura icon of this layer, never the plate)
local hl_rel_swapped = false
local function HL_SwapAuraRelease()
  hl_rel_swapped = true
  if EVT_HL_AURA_RELEASE_SQUARE then
    HL_Cmd(HL_CMND_SWAP, HL_AURA_REL, HL_ATLAS_0808, HL_SWAPS[1][1], HL_REL_SLOT, 0, 0)
  end
end

-- «RB + rayo» (skill open guide): its pill sprite -> cmd_base01
local hl_so_swapped = false
local function HL_SwapSkillOpen()
  hl_so_swapped = true
  if EVT_HL_SKILL_OPEN_ON then
    HL_Cmd(HL_CMND_SWAP, HL_SKILL_OPEN, HL_ATLAS_0808, HL_SWAPS[1][1], HL_SO_SLOT, 0, 0)
  end
end

-- the «RB + rayo» plate mesh (cmd_base01) whose visible rectangle wraps the content with EVT_HL_SKILL_OPEN_PAD,
-- EVT_HL_SKILL_OPEN_H tall, centred in y on the content: (x, y, w, h) under _pos_base01, x / y = top-left corner
function EVT_HL_SkillOpenPlateRect()
  local vis_l = HL_SO_CONTENT_L - EVT_HL_SKILL_OPEN_PAD
  local vis_w = HL_SO_CONTENT_R - HL_SO_CONTENT_L + 2 * EVT_HL_SKILL_OPEN_PAD
  local vis_h = EVT_HL_SKILL_OPEN_H
  local w = vis_w / (HL_PLATE_VX1 - HL_PLATE_VX0)
  local h = vis_h / (HL_PLATE_VY1 - HL_PLATE_VY0)
  return vis_l - w * HL_PLATE_VX0, vis_h / 2 + h * HL_PLATE_VY0, w, h
end

-- the «RB + LB» plate mesh grown by EVT_HL_AURA_SLOT_PLATE_GROW around its centre: (x, y, w, h), layer units
function EVT_HL_SlotPlateRect()
  local g = EVT_HL_AURA_SLOT_PLATE_GROW or 1
  local w, h = HL_SLOT_MESH_W * g, HL_SLOT_MESH_H * g
  return HL_SLOT_MESH_X + (HL_SLOT_MESH_W - w) / 2, HL_SLOT_MESH_Y + (h - HL_SLOT_MESH_H) / 2, w, h
end

-- the «RB + rayo» plate mesh (cmd_base01) whose visible rectangle wraps the content with EVT_HL_AURA_RELEASE_PAD and is
-- as tall on screen as the visible «RB + LB» plate: (x, y, w, h) in 17b layer units, x / y = top-left corner
function EVT_HL_ReleasePlateRect()
  local s = EVT_HL_AURA_RELEASE_SCALE
  local _, _, _, sh = EVT_HL_SlotPlateRect()
  local vis_h = sh * (HL_PLATE_VY1 - HL_PLATE_VY0) * EVT_HL_AURA_SLOT_SCALE / s
  local vis_l = HL_REL_CONTENT_L - EVT_HL_AURA_RELEASE_PAD
  local vis_w = HL_REL_CONTENT_R - HL_REL_CONTENT_L + 2 * EVT_HL_AURA_RELEASE_PAD
  local w = vis_w / (HL_PLATE_VX1 - HL_PLATE_VX0)
  local h = vis_h / (HL_PLATE_VY1 - HL_PLATE_VY0)
  return vis_l - w * HL_PLATE_VX0, vis_h / 2 + h * HL_PLATE_VY0, w, h
end

-- _atc_btn04_l from the cross in layout units, measured (x scale from _cmd01_01, 128 right; y scale and sign from
-- _cmd01_04, 76 up); the layout values when the engine gives nothing usable
local function HL_ReleaseAtc()
  local ok1, gx, gy = HL_Cmd(HL_CMND_GPOS, HL_BASE, 0, HL_NODE_GAIJI)
  local ok2, ax, ay = HL_Cmd(HL_CMND_GPOS, HL_BASE, 0, HL_NODE_ATC04)
  local ok3, cx = HL_Cmd(HL_CMND_GPOS, HL_BASE, 0, HL_NODE_CMD0101)
  local ok4, _, uy = HL_Cmd(HL_CMND_GPOS, HL_BASE, 0, HL_NODE_CMD0104)
  if not (ok1 and ok2 and ok3 and ok4) or type(gx) ~= "number" or type(gy) ~= "number" or type(ax) ~= "number"
    or type(ay) ~= "number" or type(cx) ~= "number" or type(uy) ~= "number" then
    return HL_REL_ATC_DX, HL_REL_ATC_DY
  end
  local kx, ky = (cx - gx) / 128, (uy - gy) / 76
  if kx < 0.25 or kx > 4 or math.abs(ky) < 0.25 or math.abs(ky) > 4 then
    return HL_REL_ATC_DX, HL_REL_ATC_DY
  end
  local dx, dy = (ax - gx) / kx, (ay - gy) / ky
  if math.abs(dx) > 1920 or math.abs(dy) > 1080 then
    return HL_REL_ATC_DX, HL_REL_ATC_DY
  end
  return dx, dy
end

-- x offset of the command cluster so that the Y/X/B/A cross sits at EVT_HL_TACTICS_MENU_CROSS_X from the left:
-- measured every frame (the tactics page slides the cross with an animation; retail settles at -672), relative to the
-- layer root so the current offset cancels out
local function HL_MenuDx()
  if not EVT_HL_TACTICS_MENU_LEFT or type(funcLuaCommand) ~= "function" then
    return 0
  end
  local ok, mode = pcall(funcLuaCommand, HL_CMND_TACTICS_MODE)
  local on = ok and mode == true
  if not on and hl_menu_dx ~= 0 and type(IsPlayCommandSelectAnime) == "function" then
    local ok2, busy = pcall(IsPlayCommandSelectAnime)
    on = ok2 and busy == true   -- keep it left until the «decide» animation of the chosen tactic ends
  end
  if not on then
    return 0
  end
  local ok3, gx = HL_Cmd(HL_CMND_GPOS, HL_BASE, 0, HL_NODE_GAIJI)
  local ok4, ox = HL_Cmd(HL_CMND_GPOS, HL_BASE, 0, HL_NODE_OUT)
  local ok5, cx = HL_Cmd(HL_CMND_GPOS, HL_BASE, 0, HL_NODE_CMD0101)
  if not ok3 or not ok4 or type(gx) ~= "number" or type(ox) ~= "number" then
    return hl_menu_dx
  end
  -- global units per layout unit: _cmd01_01 is 128 layout units right of _pos_gaiji01
  local k = 1
  if ok5 and type(cx) == "number" and (cx - gx) / 128 > 0.25 and (cx - gx) / 128 < 4 then
    k = (cx - gx) / 128
  end
  local rel = (gx - ox) / k   -- cross centre from the right edge (retail -342), independent of our own offset
  if rel >= 0 or rel <= -EVT_HL_SCREEN_W then
    return hl_menu_dx
  end
  return -EVT_HL_SCREEN_W + EVT_HL_TACTICS_MENU_CROSS_X - rel
end

local function HL_Place(layer)
  if layer == HL_GOAHEAD then
    local s = EVT_HL_GOAHEAD_SCALE
    HL_Cmd(HL_CMND_SCALE, HL_GOAHEAD, s, s, 1, 0)
    HL_Cmd(HL_CMND_POS, HL_GOAHEAD, EVT_HL_GOAHEAD_X - HL_GOAHEAD_ATC_X, EVT_HL_GOAHEAD_Y - HL_GOAHEAD_ATC_Y, 0, 0)
  elseif layer == HL_AURA_REL then
    local s = EVT_HL_AURA_RELEASE_SCALE
    HL_Cmd(HL_CMND_SCALE, HL_AURA_REL, s, s, 1, 0)
    if EVT_HL_AURA_RELEASE_SQUARE then
      local x, y, w, h = EVT_HL_ReleasePlateRect()
      HL_Cmd(HL_CMND_NODE_POS, HL_AURA_REL, 0, HL_REL_MESH, 0, x)
      HL_Cmd(HL_CMND_NODE_POS, HL_AURA_REL, 0, HL_REL_MESH, 1, y)
      HL_Cmd(HL_CMND_NODE_SIZE, HL_AURA_REL, 0, HL_REL_MESH, w, h)
      -- the visible plate's left edge EVT_HL_AURA_RELEASE_LEFT right of the cross (LOCAL_POS: from the locator, after
      -- the layer scale)
      local ax = HL_ReleaseAtc()
      local vis_l = x + w * HL_PLATE_VX0
      HL_Cmd(HL_CMND_POS, HL_AURA_REL, EVT_HL_AURA_RELEASE_LEFT - ax - s * vis_l, EVT_HL_AURA_RELEASE_DY, 0, 0)
    end
  elseif layer == HL_AURA_SLOT then
    local s = EVT_HL_AURA_SLOT_SCALE
    HL_Cmd(HL_CMND_SCALE, HL_AURA_SLOT, s, s, 1, 0)
    HL_Cmd(HL_CMND_POS, HL_AURA_SLOT, EVT_HL_AURA_SLOT_RIGHT - s * HL_SLOT_RIGHT, HL_SLOT_CY * (1 - s), 0, 0)
    local x, y, w, h = EVT_HL_SlotPlateRect()
    HL_Cmd(HL_CMND_NODE_POS, HL_AURA_SLOT, 0, HL_SLOT_MESH, 0, x)
    HL_Cmd(HL_CMND_NODE_POS, HL_AURA_SLOT, 0, HL_SLOT_MESH, 1, y)
    HL_Cmd(HL_CMND_NODE_SIZE, HL_AURA_SLOT, 0, HL_SLOT_MESH, w, h)
  elseif layer == HL_SKILL_OPEN then
    if not EVT_HL_SKILL_OPEN_ON then
      return
    end
    local s = EVT_HL_SKILL_OPEN_SCALE
    local x, y, w, h = EVT_HL_SkillOpenPlateRect()
    HL_Cmd(HL_CMND_NODE_POS, HL_SKILL_OPEN, 0, HL_SO_MESH, 0, x)
    HL_Cmd(HL_CMND_NODE_POS, HL_SKILL_OPEN, 0, HL_SO_MESH, 1, y)
    HL_Cmd(HL_CMND_NODE_SIZE, HL_SKILL_OPEN, 0, HL_SO_MESH, w, h)
    HL_Cmd(HL_CMND_SCALE, HL_SKILL_OPEN, s, s, 1, 0)
    -- plate centre (layout units from the corner) before / after the scale around the corner
    local cx = HL_SO_BASE_X + x + w * (HL_PLATE_VX0 + HL_PLATE_VX1) / 2
    local cy = HL_SO_BASE_Y
    HL_Cmd(HL_CMND_POS, HL_SKILL_OPEN, cx + EVT_HL_SKILL_OPEN_DX - s * cx, cy + EVT_HL_SKILL_OPEN_DY - s * cy, 0, 0)
  elseif layer == HL_CANCEL_GUIDE then
    local s = EVT_HL_ACTION_PLATE_SCALE
    HL_Cmd(HL_CMND_SCALE, HL_CANCEL_GUIDE, s, s, 1, 0)
  elseif layer == HL_RING then
    if not EVT_HL_TACTICS_LEFT then
      return
    end
    local x = -EVT_HL_SCREEN_W + EVT_HL_TACTICS_RING_X
    local dy = EVT_HL_TACTICS_RING_Y - HL_RING_Y
    if EVT_HL_TACTICS_FLIP then
      HL_Cmd(HL_CMND_SCALE, HL_RING, -1, 1, 1, 0)
      HL_Cmd(HL_CMND_POS, HL_RING, x + HL_RING_X, dy, 0, 0)
    else
      HL_Cmd(HL_CMND_POS, HL_RING, x - HL_RING_X, dy, 0, 0)
    end
  elseif layer == HL_BASE or layer == HL_COACH then
    HL_Cmd(HL_CMND_POS, layer, hl_menu_dx, 0, 0, 0)
  elseif layer == HL_TAC_PLATE then
    local s = EVT_HL_TACTICS_PLATE_SCALE
    local pull = (1 - s) * HL_TAC_HALF_W
    for i = 0, 3 do
      local dx = (i == 1 and pull) or (i == 3 and -pull) or 0
      HL_Cmd(HL_CMND_SCALE, HL_TAC_PLATE, s, s, 1, i)
      HL_Cmd(HL_CMND_POS, HL_TAC_PLATE, dx, 0, 0, i)
    end
  end
end

-- layer scale of the 4 action plates of the cross: EVT_HL_ACTION_PLATE_SCALE for «Pase» / «Disparar» / «Esquivar»,
-- 1 for any other action; only sent when it changes
local function HL_PlaceActionPlates()
  for i = 0, HL_BASE_CMD_COUNT - 1 do
    if hl_plate_ready[i] then
      local s = HL_SMALL_PLATE_ACTIONS[hl_plate_action[i]] and EVT_HL_ACTION_PLATE_SCALE or 1
      if hl_plate_scale_sent[i] ~= s then
        HL_Cmd(HL_CMND_SCALE, HL_BASE_CMD, s, s, 1, i)
        hl_plate_scale_sent[i] = s
      end
    end
  end
end

local function HL_PlaceAll()
  HL_Place(HL_GOAHEAD)
  HL_Place(HL_AURA_REL)
  HL_Place(HL_AURA_SLOT)
  HL_Place(HL_SKILL_OPEN)
  HL_Place(HL_RING)
  HL_Place(HL_TAC_PLATE)
  HL_Place(HL_CANCEL_GUIDE)
  HL_PlaceActionPlates()
end

local function HL_Wrap(name, after)
  local prev = rawget(_ENV, name)
  if type(prev) ~= "function" then
    return
  end
  rawset(_ENV, name, function(...)
    local r = HL_Pack(prev(...))
    if EVT_HL_ON then
      local ok, err = pcall(after, ...)
      if not ok then
        HL_Log(name .. " error " .. tostring(err))
      end
    end
    return table.unpack(r, 1, r.n)
  end)
end

-- the engine calls these by name every frame: the guide is never switched on (display only)
local function HL_WrapDash(name)
  local prev = rawget(_ENV, name)
  if type(prev) ~= "function" then
    return
  end
  rawset(_ENV, name, function(a1, ...)
    if EVT_HL_ON and EVT_HL_HIDE_DASH then
      return prev(false, ...)
    end
    return prev(a1, ...)
  end)
end

HL_WrapDash("SetDashButtonGuideStatus")
HL_WrapDash("SetDashAttackButtonGuideStatus")

-- «LT + B Campo de foco» (2026-09-30, Nacho): soccer08_17_catch_bomb_guide never shown, whoever switches it on (the
-- engine through SetCatchBombButtonGuideStatus, or any other caller of SetAttachButtonGuideStatus); the focus field
-- itself, the «Bloquear» guide (catch_bomb_guard) and every other guide are untouched. Pad and keyboard glyphs alike
-- (it is the layer that stays hidden).
local HL_FOCUS_FIELD = 2211469663 --[[soccer08_17_catch_bomb_guide]]
local hl_prevAttach = rawget(_ENV, "SetAttachButtonGuideStatus")
if type(hl_prevAttach) == "function" then
  rawset(_ENV, "SetAttachButtonGuideStatus", function(a1, a2, a3, ...)
    if EVT_HL_ON and EVT_HL_HIDE_FOCUS_FIELD and a1 == HL_FOCUS_FIELD then
      return hl_prevAttach(a1, a2, false, ...)
    end
    return hl_prevAttach(a1, a2, a3, ...)
  end)
end

-- «RT Acelerar cursor»: the request is the zone signal; the guide itself is never switched on (display only)
local hl_prevCursor = rawget(_ENV, "SetCursorSpeedUpButtonGuideStatus")
if type(hl_prevCursor) == "function" then
  rawset(_ENV, "SetCursorSpeedUpButtonGuideStatus", function(a1, ...)
    if a1 == true then
      hl_zone = EVT_HL_ZONE_HOLD
    end
    if EVT_HL_ON and EVT_HL_HIDE_CURSOR_GUIDE then
      return hl_prevCursor(false, ...)
    end
    return hl_prevCursor(a1, ...)
  end)
end

-- «RB + LB diana» (engine, by name, every frame): off while the zone signal is up
local hl_prevSlotGuide = rawget(_ENV, "SetRunAuraSlotButtonGuideStatus")
if type(hl_prevSlotGuide) == "function" then
  rawset(_ENV, "SetRunAuraSlotButtonGuideStatus", function(a1, ...)
    if EVT_HL_ON and EVT_HL_AURA_SLOT_HIDE_IN_ZONE and hl_zone > 0 then
      return hl_prevSlotGuide(false, ...)
    end
    return hl_prevSlotGuide(a1, ...)
  end)
end

-- move list open: hold the list slide at rest (the cross keeps the closed anchor). Not held while the LB tactics menu
-- is up and hud_layout does not move that menu itself (EVT_HL_TACTICS_MENU_LEFT = false): its plates need the slide.
local function HL_TacticsMode()
  if type(funcLuaCommand) ~= "function" then
    return false
  end
  local ok, on = pcall(funcLuaCommand, HL_CMND_TACTICS_MODE)
  return ok and on == true
end

local function HL_ListAnchorSync(changed)
  local play = rawget(_ENV, "PlayAnimeMoveOffsetCmdBase")
  if type(play) ~= "function" then
    return
  end
  local want = EVT_HL_ON and EVT_HL_LIST_ANCHOR and hl_list_open
    and not (HL_TacticsMode() and not EVT_HL_TACTICS_MENU_LEFT)
  if want then
    if changed or not hl_anchor then
      play(HL_TYPE_OFFSET, 2, true)       -- end of «out» = rest pose (no slide)
    end
  elseif hl_anchor then
    if hl_list_open then
      play(HL_TYPE_OFFSET, 0, true)       -- hand the open slide back to retail (end of «in»)
    else
      play(HL_TYPE_OFFSET, 2, true)       -- closed while held: no «out» slide from -330
    end
  end
  if want ~= hl_anchor then
    HL_Log("move list " .. (want and "held at the closed anchor" or "slide released"))
  end
  hl_anchor = want
end

-- the engine calls it by name when the move list opens / closes (and the LB tactics menu)
local hl_prevOffset = rawget(_ENV, "UpdateAnimeMoveOffsetCmdBase")
if type(hl_prevOffset) == "function" then
  rawset(_ENV, "UpdateAnimeMoveOffsetCmdBase", function(a1, ...)
    local r = HL_Pack(hl_prevOffset(a1, ...))
    local open = a1 == true
    local changed = open ~= hl_list_open
    hl_list_open = open
    local ok, err = pcall(HL_ListAnchorSync, changed)
    if not ok then
      HL_Log("UpdateAnimeMoveOffsetCmdBase error " .. tostring(err))
    end
    return table.unpack(r, 1, r.n)
  end)
end

-- the answering side's move choice (the keeper's save choice after a shot): the engine calls
-- OnStartOpponentSkillSelect by name and retail slides the whole command group (type «offset02» of set «vs»,
-- _pos_base01 0 -> -288) to the left. Held at its rest pose like the move list slide: the selector stays where the
-- other choices have it.
local HL_TYPE_VS_OFFSET = 2898379319 --[[offset02: type of set vs, _pos_base01 0 -> -288 in the answering choice]]
HL_Wrap("OnStartOpponentSkillSelect", function()
  local play = rawget(_ENV, "PlayAnimeMoveOffsetCmdBase")
  if EVT_HL_LIST_ANCHOR and type(play) == "function" then
    play(HL_TYPE_VS_OFFSET, 2, true)      -- end of «out» = rest pose (no slide)
    HL_Log("answering choice held at the closed anchor")
  end
end)

-- the engine calls these by name when it gives a plate of the cross its action (SetupBaseCmdInfo(index, action, ...))
HL_Wrap("SetupBaseCmdInfo", function(index, action)
  if type(index) == "number" and index >= 0 and index < HL_BASE_CMD_COUNT then
    hl_plate_action[index] = action or 0
    HL_PlaceActionPlates()
  end
end)
HL_Wrap("ResetBaseCmdInfo", function()
  hl_plate_action = {}
  HL_PlaceActionPlates()
end)

-- retail OnInit resets flag3 (list closed); SetupButtonCmdBase then skips the slides to rest
HL_Wrap("OnInit", function()
  hl_list_open = false
  hl_anchor = false
end)

HL_Wrap("OnSetupLayer", function(a1, a2)
  if a1 == HL_GOAHEAD then
    HL_SwapGoAhead()
  elseif a1 == HL_AURA_SLOT then
    HL_SwapAuraSlot()
  elseif a1 == HL_AURA_REL then
    HL_SwapAuraRelease()
  elseif a1 == HL_SKILL_OPEN then
    HL_SwapSkillOpen()
  elseif a1 == HL_BASE_CMD and type(a2) == "number" then
    hl_plate_ready[a2] = true
    hl_plate_scale_sent[a2] = nil   -- the retail setup may have reset the layer scale
  end
  HL_Place(a1)
end)

local hl_logged = false
HL_Wrap("PostStep", function()
  if not hl_swapped then
    HL_SwapGoAhead()
  end
  if not hl_slot_swapped then
    HL_SwapAuraSlot()
  end
  if not hl_rel_swapped then
    HL_SwapAuraRelease()
  end
  if not hl_so_swapped then
    HL_SwapSkillOpen()
  end
  HL_PlaceAll()
  HL_ListAnchorSync(false)
  if hl_zone > 0 then
    hl_zone = hl_zone - 1
  end
  local dx = HL_MenuDx()
  if (dx == 0) ~= (hl_menu_dx == 0) then
    HL_Log("tactics menu dx " .. tostring(dx))
  end
  hl_menu_dx = dx
  if dx ~= 0 or hl_menu_dx_applied ~= 0 then
    HL_Place(HL_BASE)
    HL_Place(HL_COACH)
  end
  -- BetterUI: the coach bust (Byron Love) drawn behind the plates of the tactics menu is hidden while the menu is up
  -- (every frame: the engine turns it visible again); shown again once the menu closes (retail state)
  if dx ~= 0 then
    HL_Cmd(711242136 --[[CMND_SET_LAYER_VISIBLE]], HL_COACH, 0, false)
    hl_coach_hidden = true
  elseif hl_coach_hidden then
    hl_coach_hidden = false
    HL_Cmd(711242136 --[[CMND_SET_LAYER_VISIBLE]], HL_COACH, 0, true)
  end
  hl_menu_dx_applied = dx
  if not hl_logged then
    hl_logged = true
    HL_Log("placed (goahead " .. EVT_HL_GOAHEAD_X .. "," .. EVT_HL_GOAHEAD_Y .. " x" .. EVT_HL_GOAHEAD_SCALE .. ")")
  end
end)
