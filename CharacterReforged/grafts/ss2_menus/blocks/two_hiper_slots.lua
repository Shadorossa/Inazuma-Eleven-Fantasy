-- ===================================================================================================
-- Two Hiper slots (owner redesign 2026-10-12; docs/game/hiper/hiper-two-slots.md). The Hiper row holds BOTH slots of
-- the player: the AURA slot (a keshin or a totem: board slot 8 + the team aura row, as before) and the MIX slot (a
-- Mix-Max or a «Modo cambio»: Inazuma Fantasy's save blob hiper_slots.json through CMND_FANTASY_HIPER_MIX_*). The row
-- reads «<aura>   /   <mix>»; the Hiper picker files the chosen move into its own slot (CMND_FANTASY_HIPER_SLOT_OF:
-- keshin / totem -> aura, Mix-Max / mode change -> mix, an armour alone is refused: it comes from its keshin in the
-- match). R3 switches the panel between the two slots; Y «Eliminar» asks which slot when both are filled. No chain:
-- a Mix-Max no longer brings the partner's keshin (the panel's «Ver aura» view of it is gone). A single-slot leftover
-- on board slot 8 (a Mix-Max / change carrier, an armour alone) is fixed once per shown player. Everything in PL (no
-- new main-chunk locals, one assignment per line at main level).
-- ===================================================================================================
-- 2026-10-14: the mix slot store is Character Reforged's (scripts\mix_slots.lua, imported once from IF's blob)
PL.HS_CMD = {SLOT_OF = @crc:CMND_CHARACTERREFORGED_SLOT_OF@, MIX_GET = @crc:CMND_CHARACTERREFORGED_MIX_GET@,
  MIX_SET = @crc:CMND_CHARACTERREFORGED_MIX_SET@}
PL.HS_TX = {ARMOUR = 2889673449 --[[evt_hs_armour_alone]], VIEW_MIX = 2226997538 --[[evt_hs_view_mix]],
  MIX_FAIL = 1970703341 --[[evt_hs_mix_fail]],
  MX_ASSIGNED = 1026818207 --[[evt_hs_mx_assigned]], ASK_MX = 3109185653 --[[evt_hs_ask_mx]],
  ASK_MC_DELETE = 2595117433 --[[evt_hs_ask_mc_delete]]}
PL.hs_view = "aura"
-- 2026-10-12 (owner): the Hiper row is split in two PLATES side by side, the SAME plate twice (the row's retail plate
-- sprite item_list_base01, same shape, size and style) tinted per half: left = the AURA slot, PURPLE; right = the MIX
-- slot (a Mix-Max OR a «Modo cambio»), ORANGE. Left = the row's own base _item_list_base01, right = the row's spare
-- title base _title_list_base01 given the same sprite; both scaled to half the row, the right one moved right; the tint
-- is the mesh colour (CMND_SET_PRIM_COLOR, a multiply: the retail white plate takes any colour; IF's purple sprite
-- could not turn orange). Round 3: no retail Mix-Max band any more (owner: the same plate, orange). Each half shows its move's name (white,
-- outlined) and icon, or «---». Left / Right on the row select the half (the selected name full white with «»», the
-- other dimmed); the panel, R3 and Y (hold) act on the selected half. Round 2 (in game 15:57: the generated split
-- texture's recipe failed - its source sprite has no name in IF's atlas - the row was transparent): no generated
-- texture any more, two real plates from loaded sprites.
-- Round 5 (in game, shots 167-169): the mesh tint never reached the plates (both halves white), the aura icon sat on
-- the boundary of the halves. The plates are now PRE-TINTED sprites of IF's atlas evt_hs_plates (made at boot by the
-- image type from the retail item_list_base01: content\images\menu\00_soccer\soccer11\evt_hs_plates.toml), loaded
-- once (the retail white plate until it is in), and each half's icon sits at the left end of its own plate, its name
-- after it (a few spaces, as the text node itself does not move). The picker opened from a half shows only that
-- half's tabs (the skill tab registry's window: keshin / totem or Mix-Max / «Modo cambio»), from a move row only the move
-- categories (PL.HsPrevPick wrapper below).
-- Round 6 (in game, shots 227-230): (1) the aura half showed the MIX move's icon and the mix half the retail star: the
-- item-icon command's 4th argument is the texture SLOT of the layer instance, not the mesh, and both halves wrote
-- slot icon_item_dmy01 (the mix one last), while _icon_title01 draws slot icon_title01 (the star sprite); the mix icon
-- now goes to slot icon_title01 (as pset_preview's medal). (2) The halves looked unequal: the mix plate was 76 tall
-- (title base) vs 80, 2 units higher; the aura icon stuck 10 units out of its plate; ONE retail focus frame (572) ran
-- round both plates and the mix plate stuck out of it. Now both plates 282 x 80 on the same line, both icons 5 units
-- inside their plate, and the focus frame is per half: _item_list_focus01 (left) or _item_list_focus02 (right, given
-- the plain frame sprite) at half width, only on the selected half; the retail Focus animation still fades it in/out.
-- (3) No «» » mark, no dimmed name: the frame shows the selected half. (4) The text boxes (node scale = box size; the
-- sclw style squeezes a longer name into it) end inside their plate: «Miximax Trans» no longer runs past the edge.
-- (5) Left / Right: read on the press edge (no 10-frame lock) from MENU_CTRL, the analog controller, the separate
-- cross-key controller and, while the list has the control focus, the pad / arrow keys themselves (CMND_VRFW_INPUT_PAD
-- / _KEY): only the controller the game has selected delivers commands (contact-map doc), so a press could get lost
-- after another screen changed it. The input controller is never switched here. Leaving the row puts the aura half back.
PL.hs_half = 0
PL.HS_ROW = {BASE1 = 970690259 --[[_item_list_base01]], BASE2 = 2583835390 --[[_title_list_base01]],
  POS2 = 3571920478 --[[_pos_list02]], FOCUS2 = 2420990283 --[[_item_list_focus02]],
  TEXT1 = 456522680 --[[_text_item01]], TEXT2 = 2185013762 --[[_text_item02]], ICON1 = 303536660 --[[_icon_item_dmy01]],
  ICON2 = 4025646555 --[[_icon_title01]], TRANSLATE = 2575768773 --[[node translation (layer, idx, node, axis, value)]],
  SCALE = 2885415772 --[[node scale (layer, idx, node, sx, sy)]],
  SLOT2 = 1453818910 --[[title_list_base01 (the mesh's sprite slot)]],
  STYLE = 516729530 --[[fs_32_w_lc_2d2_001_nr_sclw: white, outlined, squeezed to its box]],
  -- round 4 (in game 17:10: both plates gone, the «---» over the aura name): a quad's node scale IS its size in layout
  -- units (unit quads, as the HUD's cooldown bar: hiper_btn), so scale 0.5 made the plates 0.5 units wide; and moving
  -- the title text node did not move its text. Now the plates get their half SIZE, and the whole spare title set is
  -- moved by its locator _pos_list02 (+SHIFT2: base, text and icon together; a locator move works, the training bar),
  -- its icon brought back inside the row. Sizes: the retail sprites item_list_base01 568 x 80, title_list_base01 568 x 76.
  BASE1_SIZE = {568, 80}, BASE2_SIZE = {568, 76}, HALF_W = 282, SHIFT2 = 288,
  -- round 5: the icons at the left end of their half (layout units of the icon nodes; the mix icon's locator is
  -- moved +SHIFT2 with its set), the names after them (PAD1 / PAD2 spaces), cut to fit the half
  -- round 6: both icons 5 units inside their plate (plates -283..-1 and 5..287), both plates 80 tall at y 36, the
  -- text boxes ending 8 units before their plate's right edge, the focus frame per half (retail 572 x 88 at -286)
  -- round 8 (owner 2026-10-13: the icons a bit further left and smaller, centred on the plate, the same on both):
  -- icon nodes are left / top anchored (the layout's x = left edge, y = top edge, y up), size = node scale: 54 units
  -- (84 % of the retail 64) at x = plate left + 2, its top at plate centre (BASE1_Y - 40 = -4) + 27
  AURA_ICON_X = -281, ICON1_X = 203, MIX_ICON_X = -281, BASE1_Y = 36, BASE2_Y = 38,
  ICON_SIZE = 54, ICON_Y = 23, ICON_RETAIL_SIZE = 64, ICON_RETAIL_Y = 28,
  -- the aura half's short name on this menu: menu_text row evt_hs_totem_short = "|"-separated name formats of a
  -- totem in the language (<VALUE> = the totem's own name), e.g. "Totem <VALUE>" / "<VALUE> Totem"
  TOTEM_SHORT = 2237215146 --[[crc32(evt_hs_totem_short)]],
  PAD1 = "", PAD2 = "", CUT = 14,
  -- 2026-10-14 (owner: «no deberían aparecer esos iconos cuadrados, deberían aparecer el portrait del aura o
  -- jugador»): no move icon on the plates any more. Each plate shows a PORTRAIT at its right end, over the darker
  -- slanted corner: the aura's character (keshin / totem, SKILL_INFO 17) on the aura plate, the partner (fusion,
  -- retail Mix-Max) or the other form («Modo cambio») on the mix plate; an empty slot shows none. The portrait is the
  -- character's list face icon (552280324, as the bank / dock lists and the retail item cards draw it) on the
  -- row's own icon quads (_icon_item_dmy01 / _icon_title01), so no layer is added. The names start where the icons
  -- were: a text node does not move by itself (round 4), so each plate set is moved left by its locator
  -- (_pos_list01 / _pos_list02) and its plate, focus frame and portrait moved back right by the same amount.
  POS1 = 1307475940 --[[_pos_list01]], TEXT_SHIFT1 = 57, TEXT_SHIFT2 = 38,
  BASE_X = -283, FOCUS_X = -286,
  -- portrait: inside the painted part of the plate sprite (item_list_base01 568 x 80: opaque rows 9..62, columns
  -- 11..554, i.e. 54 of the plate's 80 units tall, centred, and 7 units in from its right end), so nothing sticks out
  -- above or below. A quad cannot be clipped (no UV command; the menu scissor clips whole layer instances), so the
  -- portrait is sized to the band: 54 units square, top at plate centre + 27, 2 units inside the painted right end
  -- (world -10 aura, 278 mix; the sets are shifted by -TEXT_SHIFT1 / SHIFT2 - TEXT_SHIFT2)
  FACE_SIZE = 54, FACE_Y = 27, AURA_FACE_X = -7, MIX_FACE_X = -26,
  TEXT1_SPLIT_W = 188, TEXT2_SPLIT_W = 188,
  RESET_FACE = 4176779611 --[[ResetFaceIcon (layer, idx, texture slot)]],
  ICON_SLOT1 = 1875672568 --[[icon_item_dmy01]], ICON_SLOT2 = 3047759730 --[[icon_title01 (the slot _icon_title01 draws)]],
  TEXT1_BOX = {410, 54}, TEXT2_BOX = {408, 54}, TEXT1_W = 205, TEXT2_W = 224,
  FOCUS1 = 155463921 --[[_item_list_focus01]], FOCUS_SIZE = {572, 88}, FOCUS_HALF_W = 286,
  FOCUS_SPRITE = 3319891473 --[[item_list_focus01: the plain frame]], FOCUS2_SLOT = 1558763435 --[[item_list_focus02]],
  CTRLS = {1332654303 --[[MENU_CTRL]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]],
    3526778166 --[[MENU_CTRL_SEPARATE_CROSS_KEY]]},
  PAD = @crc:CMND_VRFW_INPUT_PAD@, VKEY = @crc:CMND_VRFW_INPUT_KEY@,
  PAD_LEFT = 0x80, PAD_RIGHT = 0x20, VK_LEFT = 0x25, VK_RIGHT = 0x27,
  CTRL_FOCUS = @crc:CMND_IS_CTRL_FOCUS_ACTIVE@ --[[CMND_IS_CTRL_FOCUS_ACTIVE (layer)]],
  -- round 7 (owner: the mouse never selected the orange half): the row's native touch quad _touch_list01 (retail
  -- 544 x 54 at (-272, 27), it ended inside the mix plate) covers both plates (570 x 80 at (-283, 36)), and the pointer
  -- over a plate (local x -283..-1 aura, 5..287 mix, y -44..36, y up) selects that half as Left / Right do
  TOUCH = 688754292 --[[_touch_list01]], TOUCH_RETAIL = {544, 54, -272, 27}, TOUCH_SPLIT = {570, 80, -283, 36},
  PTR_POS = 558229292 --[[pointer (screen px, y down)]], PTR_GPOS = 4002164178 --[[instance global position, y up]],
  PTR_MOVED = 3272825600 --[[mouse moved]], PTR_CLICK = {218912913 --[[CMD_EVT_MOUSE_LEFT]],
    1651523701 --[[CMD_ENTER_CLICK]]},
  HIT_X = {{-283, -1}, {5, 287}}, HIT_Y = {-44, 36},
  PLATE_TEX = "#/menu/00_soccer/soccer11/evt_soccer11_08_hs/evt_hs_plates.g4tx",
  PLATE_TEX_CRC = 4050240674 --[[crc32(PLATE_TEX)]], PLATE_AURA = 2408592914 --[[evt_hs_plate_aura]],
  PLATE_MIX = 4118466748 --[[evt_hs_plate_mix]],
  K_LEFT = 2765147006 --[[CMD_LEFT]], K_RIGHT = 2075023265 --[[CMD_RIGHT]]}

-- one row again (a level-locked Hiper row, never split): sizes, positions, the spare set, the focus frame and the text
-- style back
function PL.HsUnsplitRow()
  local R, L = PL.HS_ROW, L_ROW
  funcLuaMenuCommand(R.SCALE, L, 0, R.BASE1, R.BASE1_SIZE[1], R.BASE1_SIZE[2])
  funcLuaMenuCommand(R.SCALE, L, 0, R.FOCUS1, R.FOCUS_SIZE[1], R.FOCUS_SIZE[2])
  funcLuaMenuCommand(C.MESH_VISIBLE, L, R.FOCUS1, true, 0)
  funcLuaMenuCommand(R.SCALE, L, 0, R.TEXT1, R.TEXT1_BOX[1], R.TEXT1_BOX[2])
  funcLuaMenuCommand(C.TEXT_ALPHA, L, 0, R.TEXT1, 1)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.POS2, 0, 0)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.BASE2, 1, R.BASE2_Y)
  funcLuaMenuCommand(R.SCALE, L, 0, R.BASE2, R.BASE2_SIZE[1], R.BASE2_SIZE[2])
  funcLuaMenuCommand(R.SCALE, L, 0, R.FOCUS2, R.FOCUS_SIZE[1], R.FOCUS_SIZE[2])
  funcLuaMenuCommand(R.SCALE, L, 0, R.TEXT2, R.TEXT2_BOX[1], R.TEXT2_BOX[2])
  funcLuaMenuCommand(EVT_POS_VISIBLE, L, R.POS2, false, 0)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.ICON1, 0, R.ICON1_X)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.ICON1, 1, R.ICON_RETAIL_Y)
  funcLuaMenuCommand(R.SCALE, L, 0, R.ICON1, R.ICON_RETAIL_SIZE, R.ICON_RETAIL_SIZE)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.POS1, 0, 0)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.BASE1, 0, R.BASE_X)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.FOCUS1, 0, R.FOCUS_X)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.BASE2, 0, R.BASE_X)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.FOCUS2, 0, R.FOCUS_X)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.ICON2, 0, R.ICON1_X)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.ICON2, 1, R.ICON_RETAIL_Y)
  funcLuaMenuCommand(R.SCALE, L, 0, R.ICON2, R.ICON_RETAIL_SIZE, R.ICON_RETAIL_SIZE)
  if PL.hs_faces then
    -- the portraits leave the icon slots: the row's own move icon again
    PL.hs_faces = false
    PL.hs_face_key = {}
    funcLuaMenuCommand(R.RESET_FACE, L, 0, R.ICON_SLOT1)
    funcLuaMenuCommand(R.RESET_FACE, L, 0, R.ICON_SLOT2)
    local skill = PL.RowMove(0)
    if skill ~= 0 then
      funcLuaMenuCommand(C.ITEM_ICON, L, 0, R.ICON1, R.ICON_SLOT1, skill)
    end
  end
  PL.HsTouch(R.TOUCH_RETAIL)
  local info = GetEquipListItemInfo(GetEquipType(0))
  if info ~= nil and info.fontStyle ~= nil then
    funcLuaMenuCommand(2333948100 --[[text style]], L, 0, R.TEXT1, info.fontStyle)
  end
end

-- the aura half's name without the totem's wording ("Tótem águila calva" -> "Águila calva"; "Bald Eagle Totem" ->
-- "Bald Eagle"): the menu_text row evt_hs_totem_short lists the language's totem name formats; any other name stays
function PL.HsFirstUpper(t)
  local b1, b2 = string.byte(t, 1, 2)
  if b1 ~= nil and b1 >= 97 and b1 <= 122 then
    return string.char(b1 - 32) .. string.sub(t, 2)
  end
  if b1 == 195 and b2 ~= nil and b2 >= 160 and b2 <= 190 and b2 ~= 183 then
    return string.char(195, b2 - 32) .. string.sub(t, 3)
  end
  return t
end

function PL.HsShortName(name)
  if type(name) ~= "string" or name == "" then
    return name
  end
  local fmts = PL.Txt(PL.HS_ROW.TOTEM_SHORT)
  for fmt in string.gmatch(fmts, "[^|]+") do
    local i, j = string.find(fmt, "<VALUE>", 1, true)
    if i ~= nil then
      local pre, post = string.sub(fmt, 1, i - 1), string.sub(fmt, j + 1)
      local n_name = #name
      if n_name > #pre + #post and string.sub(name, 1, #pre) == pre
          and (#post == 0 or string.sub(name, n_name - #post + 1) == post) then
        return PL.HsFirstUpper(string.sub(name, #pre + 1, n_name - #post))
      end
    end
  end
  return name
end

-- the split Hiper row (instance 0): both plates the same size in every state (focused or not, filled or empty), each
-- half's own icon and name, the focus frame on the selected half only
function PL.HsSplitRow()
  local R, L = PL.HS_ROW, L_ROW
  local aura, mix = PL.CrShownSlots()
  local mix_partner = mix ~= 0 and PL.HsMixPartner(mix) or nil
  local function label(id, half)
    if id == 0 then
      return ""                                    -- an empty slot: the plate alone (owner: no «---»)
    end
    local t = half == 1 and PL.HsMixName(id, mix_partner) or PL.HsShortName(EVT_Name(id))
    return (half == 1 and R.PAD2 or R.PAD1) .. EVT_Cut(t, R.CUT)
  end
  local tinted = PL.HsPlatesReady()
  PL.hs_plates_wait = not tinted
  -- left set (the aura slot): moved left by its locator so the name starts near the plate's left edge; its plate,
  -- focus frame and portrait moved back right
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.POS1, 0, -R.TEXT_SHIFT1)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.BASE1, 0, R.BASE_X + R.TEXT_SHIFT1)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.FOCUS1, 0, R.FOCUS_X + R.TEXT_SHIFT1)
  -- left plate: IF's purple plate (the retail white one until it is loaded), half the row
  if tinted then
    funcLuaMenuCommand(C.SPRITE, L, R.PLATE_TEX_CRC, R.PLATE_AURA, EVT_ROW_BASE, 0, 0)
  else
    funcLuaMenuCommand(C.SPRITE, L, EVT_ROW_TEX, EVT_ROW_BASE, EVT_ROW_BASE, 0, 0)
  end
  funcLuaMenuCommand(R.SCALE, L, 0, R.BASE1, R.HALF_W, R.BASE1_SIZE[2])
  funcLuaMenuCommand(R.SCALE, L, 0, R.FOCUS1, R.FOCUS_HALF_W, R.FOCUS_SIZE[2])
  funcLuaMenuCommand(C.MESH_VISIBLE, L, R.FOCUS1, PL.hs_half == 0, 0)
  funcLuaMenuCommand(2333948100 --[[text style]], L, 0, R.TEXT1, R.STYLE)
  funcLuaMenuCommand(R.SCALE, L, 0, R.TEXT1, R.TEXT1_SPLIT_W, R.TEXT1_BOX[2])
  funcLuaMenuCommand(C.TEXT, L, R.TEXT1, label(aura, 0), 0)
  funcLuaMenuCommand(C.TEXT_ALPHA, L, 0, R.TEXT1, 1)
  PL.HsFace(R.ICON1, R.ICON_SLOT1, R.AURA_FACE_X, aura ~= 0 and function(L1, m, s)
    return PL.AuraPortrait(L1, 0, m, s, aura)
  end or nil, string.format("%s:%08X", tostring(n), EVT_U32(aura)))
  -- right plate: the spare title set, its base = the same plate in orange (the mix slot: Mix-Max or «Modo cambio»),
  -- half the row, on the right, as tall as the left one and on its line
  funcLuaMenuCommand(EVT_POS_VISIBLE, L, R.POS2, true, 0)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.POS2, 0, R.SHIFT2 - R.TEXT_SHIFT2)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.BASE2, 0, R.BASE_X + R.TEXT_SHIFT2)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.FOCUS2, 0, R.FOCUS_X + R.TEXT_SHIFT2)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, R.BASE2, true, 0)
  if tinted then
    funcLuaMenuCommand(C.SPRITE, L, R.PLATE_TEX_CRC, R.PLATE_MIX, R.SLOT2, 0, 0)
  else
    funcLuaMenuCommand(C.SPRITE, L, EVT_ROW_TEX, EVT_ROW_BASE, R.SLOT2, 0, 0)
  end
  funcLuaMenuCommand(R.SCALE, L, 0, R.BASE2, R.HALF_W, R.BASE1_SIZE[2])
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.BASE2, 1, R.BASE1_Y)
  PL.HsTouch(R.TOUCH_SPLIT)
  funcLuaMenuCommand(C.SPRITE, L, EVT_ROW_TEX, R.FOCUS_SPRITE, R.FOCUS2_SLOT, 0, 0)
  funcLuaMenuCommand(R.SCALE, L, 0, R.FOCUS2, R.FOCUS_HALF_W, R.FOCUS_SIZE[2])
  funcLuaMenuCommand(C.MESH_VISIBLE, L, R.FOCUS2, PL.hs_half == 1, 0)
  funcLuaMenuCommand(2333948100 --[[text style]], L, 0, R.TEXT2, R.STYLE)
  funcLuaMenuCommand(R.SCALE, L, 0, R.TEXT2, R.TEXT2_SPLIT_W, R.TEXT2_BOX[2])
  funcLuaMenuCommand(C.TEXT, L, R.TEXT2, label(mix, 1), 0)
  funcLuaMenuCommand(C.TEXT_ALPHA, L, 0, R.TEXT2, 1)
  PL.HsFace(R.ICON2, R.ICON_SLOT2, R.MIX_FACE_X, mix ~= 0 and function(L1, m, s)
    if mix_partner == nil then
      return false
    end
    if mix_partner.skill ~= nil then
      return PL.AuraPortrait(L1, 0, m, s, mix_partner.skill)
    end
    return PL.ListFace(L1, 0, m, s, mix_partner.face)
  end or nil, string.format("%s:%08X:%s:%s", tostring(n), EVT_U32(mix), mix_partner and tostring(mix_partner.skill) or "-",
    mix_partner and tostring(mix_partner.face) or "-"))
end

-- a plate's portrait on the row's icon quad `mesh` (texture slot `slot`) at the plate's right end. `draw(L, mesh,
-- slot)` draws it and returns true; when it draws nothing the player's own face is shown instead, so a filled plate
-- never shows the bare quad (a white square). draw nil = hidden. The slot is reset first (a previous portrait or move
-- icon never shows through). `key` names what is drawn (player + move): while it is unchanged the portrait already on
-- the slot is kept, as a redraw reloads the texture and shows the bare quad (a white flash) on every row refresh.
PL.hs_faces = false
PL.hs_face_key = {}                            -- texture slot -> key of the portrait drawn on it
function PL.HsFace(mesh, slot, x, draw, key)
  local R, L = PL.HS_ROW, L_ROW
  funcLuaMenuCommand(R.TRANSLATE, L, 0, mesh, 0, x)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, mesh, 1, R.FACE_Y)
  funcLuaMenuCommand(R.SCALE, L, 0, mesh, R.FACE_SIZE, R.FACE_SIZE)
  if draw ~= nil and key ~= nil and PL.hs_faces and PL.hs_face_key[slot] == key then
    funcLuaMenuCommand(C.MESH_VISIBLE, L, mesh, true, 0)   -- the row refresh hid the icon mesh: the same portrait again
    return
  end
  PL.hs_face_key[slot] = nil
  funcLuaMenuCommand(R.RESET_FACE, L, 0, slot)
  if draw == nil then
    funcLuaMenuCommand(C.MESH_VISIBLE, L, mesh, false, 0)
    return
  end
  PL.hs_faces = true
  local okd, drawn = pcall(draw, L, mesh, slot)
  if not (okd and drawn == true) then
    funcLuaMenuCommand(R.RESET_FACE, L, 0, slot)
    okd, drawn = pcall(PL.OwnerFace, L, 0, mesh, slot)
  end
  local shown = okd and drawn == true
  funcLuaMenuCommand(C.MESH_VISIBLE, L, mesh, shown, 0)
  if shown then
    PL.hs_face_key[slot] = key
  end
end

-- a character's list face icon (VRFW_FaceIcon, as the bank / dock lists draw it) on (mesh, slot); the caller shows the
-- mesh; false = not drawn
function PL.ListFace(L, idx, mesh, slot, key)
  if type(key) ~= "number" or key == 0 then
    return false
  end
  return VRFW_FaceIcon.Request(L, idx, key, mesh, slot)
end

-- the shown player's own face icon on (mesh, slot): the fallback portrait; false = not drawn
function PL.OwnerFace(L, idx, mesh, slot)
  local key = funcLuaCommand(C.CHARA_GET, n, 1) or 0
  if key == 0 then
    return false
  end
  local param = funcLuaCommand(C.CHARA_GET, n, 4) or 0
  local okk, keeper = pcall(MENU_DEF.IsKeeper, param)
  pcall(SetDisableForceCharaInvalidUseTarget)
  local ok, r = pcall(funcLuaMenuCommand, 552280324 --[[chara face icon]], L, idx, false, mesh, slot, n, 255, key, 0,
    okk and keeper == true)
  pcall(SetEnableForceCharaInvalidUseTarget)
  return ok and r ~= false
end

-- an aura skill's portrait on (mesh, slot) by the retail aura windows' rule: the aura character (SKILL_INFO 17) drawn
-- as aura art of the aura type (SwapLayerFaceIconTex type PL.AURA_FACE_TYPE: keshin / armour 8, totem 14, Mix-Max 12
-- when that art exists). Keshin / armour / totem characters (k* / a* keys) have no list face icon, so 552280324 only
-- draws the other characters (a Mix-Max partner without Mix-Max art). False = not drawn.
function PL.AuraPortrait(L, idx, mesh, slot, skill)
  local ok, cid = funcLuaCommand(C.SKILL_INFO, skill, 17)
  if not ok or type(cid) ~= "number" or cid == 0 then
    return false
  end
  local _, t = funcLuaCommand(C.SKILL_INFO, skill, 13)
  local art = PL.AURA_FACE_TYPE[t]
  if art == 12 and funcLuaMenuCommand(2208175668 --[[has Mix-Max face art]], cid) ~= true then
    art = nil
  end
  if art == nil then
    return PL.ListFace(L, idx, mesh, slot, cid)
  end
  local okr, r = pcall(funcLuaMenuCommand, 346643487 --[[SwapLayerFaceIconTex]], L, idx, mesh, slot, cid, 0, art, true,
    true, true, 5)
  return okr and r ~= false
end

-- the mix slot's other character: {face = face key / chara id, name} or nil. A created fusion: its partner (All
-- Miximaxed / Inazuma Fantasy store, PL.MxGet); a «Modo cambio»: the other form (EVT_HC.McGet, else the change list);
-- a retail Mix-Max: its partner character (SKILL_INFO 17).
function PL.HsMixPartner(mix)
  if mix == PL.MX_FUSION then
    local okf, f = pcall(PL.MxGet)
    if okf and f ~= nil and ((f.face or 0) ~= 0 or (f.chara or 0) ~= 0) then
      local face = (f.face ~= nil and f.face ~= 0) and f.face or f.chara
      return {face = face, name = (f.chara or 0) ~= 0 and PL.MxCharaName(f.chara) or nil}
    end
  end
  if type(EVT_HC) == "table" and type(EVT_HC.McGet) == "function" then
    local okm, m = pcall(EVT_HC.McGet, n, mix)
    if okm and m ~= nil and (m.face or 0) ~= 0 then
      return {face = m.face, name = m.name}
    end
  end
  local k = PL.McIndex ~= nil and PL.McIndex(mix) or nil
  if k ~= nil then
    for _, c in ipairs(PL.McList()) do
      if c.idx == k and (c.chara or 0) ~= 0 then
        return {face = c.chara, name = PL.MxCharaName(c.chara)}
      end
    end
  end
  local ok, cid = funcLuaCommand(C.SKILL_INFO, mix, 17)
  if ok and type(cid) == "number" and cid ~= 0 then
    return {face = cid, name = PL.MxCharaName(cid), skill = mix}
  end
  return nil
end

-- IF's pre-tinted plates (atlas evt_hs_plates): requested once; true when they can be drawn
PL.hs_plates = 0
function PL.HsPlatesReady()
  local R = PL.HS_ROW
  if PL.hs_plates == 0 then
    funcLuaMenuCommand(C.LOAD_TEX, R.PLATE_TEX)
    PL.hs_plates = 1
  end
  if PL.hs_plates == 1 and not funcLuaCommand(C.TEX_LOADING, R.PLATE_TEX_CRC) then
    PL.hs_plates = 2
  end
  return PL.hs_plates == 2
end

-- the picker's tabs follow the slot that opens it (owner 2026-10-12): a move row only the move categories, the Hiper
-- row's aura half keshin / totem, its mix half Mix-Max / «Modo cambio»; the whole
-- table again when the picker closes (also after an error, so the team dock's list is never left narrowed)
-- 2026-10-14 (owner: «en el selector de aura solo Keshin y Tótem, en el de mix solo miximax y modo cambio, en el de
-- supertécnicas solo tiro, regate, defensa y portero»): without Inazuma Fantasy the tab row is the VR-Framework's skill
-- tab registry (docs/framework/card-types.md §3): the picker asks CMND_VRFW_SKILL_TAB_WINDOW(group) for the group of
-- its slot; which categories each group holds is Character Reforged's data (content\skill_tabs\picker_groups.toml;
-- All Changed's «Modo cambio» tab joins «mix»). The other tabs are not built at all (the native list, the Z / C cycle,
-- the icons, the filters and the mouse zones follow the window); the cursor starts on the group's first tab. No
-- registered tab (the registry answers 0): the game's whole tab row.
PL.TAB_GROUP = {[1] = "moves", [2] = "aura", [3] = "mix"}   -- picker kind -> group name (0 / other: the whole list)
PL.VRFW_SKILL_TABS = @crc:CMND_VRFW_SKILL_TABS@                  -- crc32("CMND_VRFW_SKILL_TABS") () -> n, categories (0 = off)
PL.VRFW_SKILL_TAB_WINDOW = @crc:CMND_VRFW_SKILL_TAB_WINDOW@            -- crc32("CMND_VRFW_SKILL_TAB_WINDOW") (group) -> start, count
function PL.TabWindow(kind)
  local okt, tabs = pcall(funcLuaCommand, PL.VRFW_SKILL_TABS)
  if okt and type(tabs) == "number" and tabs > 0 then
    local okw, start, count = pcall(funcLuaCommand, PL.VRFW_SKILL_TAB_WINDOW, PL.TAB_GROUP[kind] or "")
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "picker tab window", PL.TAB_GROUP[kind] or "all",
      okw and tostring(start) or "?", okw and tostring(count) or tostring(start))
  end
end

PL.HsPrevPick = EVT_PickCoroutine
function EVT_PickCoroutine(row)
  if row == 0 then
    pcall(PL.HsPointerPick)                        -- a click on a plate acts on that plate's half
  end
  local kind = 1
  if row == 0 then
    kind = 0
    if not EVT_IsLocked(0) then
      kind = PL.hs_half == 1 and 3 or 2
    end
  end
  PL.TabWindow(kind)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "picker tabs", row, kind)
  local ok, err = pcall(PL.HsPrevPick, row)
  PL.TabWindow(0)
  if not ok then
    error(err, 0)
  end
end

-- the selected half (Left / Right on the Hiper row, R3): the panel follows it
function PL.HsSetHalf(half)
  if half == PL.hs_half then
    return
  end
  PL.hs_half = half
  PL.hs_view = half == 1 and "mix" or "aura"
  funcLuaCommand(C.SE, 2500047763 --[[sy0005 cursor]])
  pcall(PL.HsSplitRow)
  local ok, err = pcall(UpdateEquipItemInfo)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper half", half == 1 and "mix" or "aura", ok and "" or tostring(err))
end

-- the slot of a Hiper move: 0 aura, 1 mix, 2 an armour (its keshin second), -1 none; nil = no answer (module off:
-- the single-slot Hiper as before)
function PL.HsKind(id)
  if id == nil or id == 0 then
    return nil, 0
  end
  local ok, kind, k = pcall(funcLuaCommand, PL.HS_CMD.SLOT_OF, id)
  if not ok or type(kind) ~= "number" then
    return nil, 0
  end
  return kind, EVT_U32(k or 0)
end

-- the ids of «Crear miximax» and of the fusion carrier (CMND_EVT_MX_ITEMS; PL.MxGrant set them only when the Hiper
-- picker opened, so the panel drew a fusion as the bare carrier: «Miximax Trans» + its template move, no partner face)
function PL.MxIds()
  if PL.MX_FUSION ~= nil and PL.MX_FUSION ~= 0 then
    return
  end
  local ok, create, fusion = pcall(funcLuaCommand, PL.MX_ITEMS_CMD)
  if ok and type(create) == "number" and type(fusion) == "number" then
    PL.MX_CREATE = EVT_U32(create)
    PL.MX_FUSION = EVT_U32(fusion)
  end
end

-- the Hiper panel of the fusion carrier is the miximax panel (partner face, the partner's move)
PL.HsPrevHiperShow = PL.HiperShow
function PL.HiperShow(skill, team_info)
  pcall(PL.MxIds)
  return PL.HsPrevHiperShow(skill, team_info)
end

-- the shown player's mix-slot move (0 = empty)
function PL.HsMix()
  pcall(PL.MxIds)
  if n == nil or n == 0 then
    return 0
  end
  local ok, id = pcall(funcLuaCommand, PL.HS_CMD.MIX_GET, n)
  return (ok and type(id) == "number") and EVT_U32(id) or 0
end

function PL.HsMixPut(id)
  if PL.readonly or n == nil or n == 0 then
    return false
  end
  local ok, done, code = pcall(funcLuaCommand, PL.HS_CMD.MIX_SET, n, id or 0)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper mix slot", string.format("%08X", EVT_U32(n)),
    string.format("%08X", EVT_U32(id or 0)), tostring(ok), tostring(done), tostring(code))
  return ok and done == true
end

-- a Mix-Max fusion: the move's name only (owner 2026-10-12: never the player's); a created change:
-- «<carrier name>: <partner>»; else the move's own name
function PL.HsMixName(mix, partner)
  if mix == nil or mix == 0 then
    return ""
  end
  if partner == nil then
    partner = PL.HsMixPartner(mix)
  end
  if partner ~= nil and type(partner.name) == "string" and partner.name ~= "" then
    return partner.name
  end
  return EVT_Name(mix)
end

-- the base equip of the Hiper row (under the miximax / mode change wrappers, which call PL.MxPrevEquip): a mix move
-- goes to the mix slot (never board slot 8), an armour alone is refused
PL.HsBaseEquip = PL.MxPrevEquip
function PL.MxPrevEquip(row, skill, inv_hint, cur)
  if row == 0 then
    local kind = PL.HsKind(skill)
    if kind == 1 then
      if not PL.HsMixPut(skill) then
        funcLuaCommand(C.SE, SE_NG)
        EVT_Message(PL.Txt(PL.HS_TX.MIX_FAIL))
      end
      return
    elseif kind == 2 then
      funcLuaCommand(C.SE, SE_NG)
      EVT_Message(PL.Txt(PL.HS_TX.ARMOUR))
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper armour alone refused", string.format("%08X", EVT_U32(skill)))
      return
    end
  end
  return PL.HsBaseEquip(row, skill, inv_hint, cur)
end

-- a created change becomes his mix slot (the store's equipped change + its carrier in the mix slot)
function PL.McEquip(idx, cur)
  local id = PL.MC_CAR[idx + 1]
  if id == nil then
    return false
  end
  pcall(funcLuaCommand, PL.MC_CMD.EQUIP, n, idx)
  return PL.HsMixPut(id)
end

-- «Crear miximax» and Eliminar on the fusion entry: the fusion lives in the mix slot
PL.HsPrevEquip = EVT_Equip
function EVT_Equip(row, skill, inv_hint, cur)
  if row == 0 then
    if skill == PL.MX_FUSION and funcLuaCommand(C.P_HAS, PL.MX_KEY_DEL) then
      funcLuaCommand(C.P_CLEAR, PL.MX_KEY_DEL)
      PL.MxClear()
      if PL.HsMix() == PL.MX_FUSION then
        PL.HsMixPut(0)
      end
      return
    end
    if skill == PL.MX_CREATE then
      funcLuaCommand(C.P_CLEAR, PL.MX_KEY_DEL)
      funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
      PL.MxFlow()
      if PL.mx_done == true then
        if PL.HsMixPut(PL.MX_FUSION) then
          funcLuaCommand(C.SE, SE_DECIDE)
          local played = PL.MxScenePlay()
          if not played and not PL.mx_scene_msg_shown then
            EVT_Message(PL.Txt(PL.HS_TX.MX_ASSIGNED, PL.mx_done_name or ""))
          end
          PL.mx_scene_msg_shown = false
        else
          funcLuaCommand(C.SE, SE_NG)
          EVT_Message(PL.Txt(PL.HS_TX.MIX_FAIL))
        end
      end
      return
    end
  end
  return PL.HsPrevEquip(row, skill, inv_hint, cur)
end

-- the mix slot emptied: a fusion asks first and is undone, a created change is emptied and «delete the change too?»
function PL.HsRemoveMix(mix)
  local mk = PL.McIndex ~= nil and PL.McIndex(mix) or nil
  if mix == PL.MX_FUSION then
    local f = PL.MxGet()
    if f ~= nil then
      funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
      if not PL.MxAsk(PL.Txt(PL.HS_TX.ASK_MX, PL.MxCharaName(f.chara))) then
        funcLuaCommand(C.SE, SE_BACK)
        return
      end
      PL.MxClear()
    end
    PL.HsMixPut(0)
    funcLuaCommand(C.SE, SE_REMOVE)
  elseif mk ~= nil then
    local chara = 0
    for _, c in ipairs(PL.McList()) do
      if c.idx == mk then
        chara = c.chara
      end
    end
    PL.HsMixPut(0)
    funcLuaCommand(C.SE, SE_REMOVE)
    if chara ~= 0 then
      funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
      if PL.MxAsk(PL.Txt(PL.HS_TX.ASK_MC_DELETE, PL.MxCharaName(chara))) then
        pcall(funcLuaCommand, PL.MC_CMD.DELETE, n, mk)
        funcLuaCommand(C.SE, SE_REMOVE)
      else
        pcall(funcLuaCommand, PL.MC_CMD.EQUIP, n, -1)
        funcLuaCommand(C.SE, SE_BACK)
      end
    end
  else
    PL.HsMixPut(0)
    funcLuaCommand(C.SE, SE_REMOVE)
  end
  PL.hs_view = "aura"
end

-- Y «Eliminar» on the Hiper row: with both slots filled, the retail list window asks which one
PL.HsPrevRestore = EVT_RestoreCoroutine
function EVT_RestoreCoroutine(row)
  if row ~= 0 or PL.mx_removing then
    return PL.HsPrevRestore(row)
  end
  local mix = PL.HsMix()
  if mix == 0 then
    return PL.HsPrevRestore(0)
  end
  local aura = EVT_Skill(0)
  if aura ~= 0 and PL.hs_half == 0 then
    return PL.HsPrevRestore(0)                     -- the aura half selected: its slot
  end
  PL.HsRemoveMix(mix)
  EVT_RefreshRows()
  UpdateEquipItemInfo()
  EVT_FocusRow(0)
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- X «Restablecer» on the Hiper row restores the aura slot only (a kit Mix-Max / mode change is not an aura)
PL.HsPrevResetKit = PL.ResetKit
function PL.ResetKit(row)
  local m = PL.HsPrevResetKit(row)
  if row == 0 and m ~= 0 then
    local kind = PL.HsKind(m)
    if kind ~= nil and kind ~= 0 then
      return 0
    end
  end
  return m
end

-- the Hiper row: «<aura>   /   <mix>». Character Reforged 1.7.10 (owner 2026-10-14: no save edits by viewing): the
-- halves show the projection (PL.CrShownSlots).
PL.HsPrevRow = UpdateEquipListItem
function UpdateEquipListItem(a1)
  PL.HsPrevRow(a1)
  if a1 ~= 0 then
    return
  end
  if EVT_IsLocked(0) then                          -- a level-locked Hiper row: one row as before
    pcall(PL.HsUnsplitRow)
    return
  end
  local ok, err = pcall(PL.HsSplitRow)
  if not ok then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper split row error", tostring(err))
  end
end

-- no chain: the miximax panel has no «aura that comes with it» view any more
function PL.MxAura2()
  PL.mx_aura = nil
  funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_AURA2, 0, false)
end

-- the panel of the Hiper row: the aura slot, R3 = the mix slot (a mix-only row shows the mix slot)
function PL.HsShowMix(mix)
  local _, team_info = GetSoccerTeamInfo(0)
  local ok, shown = false, false
  if mix == PL.MX_FUSION then
    local okf, f = pcall(PL.MxGet)
    if okf and f ~= nil then
      ok, shown = pcall(PL.MxDetail, f, team_info)
    end
  else
    ok, shown = pcall(PL.HiperShow, mix, team_info)
  end
  if ok and shown then
    SetVisibleEquipInfoWindow(false)
  end
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper panel: mix slot", string.format("%08X", EVT_U32(mix)), tostring(ok),
    tostring(shown))
end

PL.HsPrevItemInfo = UpdateEquipItemInfo
function UpdateEquipItemInfo()
  local row = (n14 ~= L_BTN) and funcLuaMenuCommand(C.FOCUS_IDX, L_ROW) or -1
  local mix = row == 0 and PL.HsMix() or 0
  local aura = mix ~= 0 and PL.RowMove(0) or 0
  PL.hs_both = mix ~= 0 and aura ~= 0              -- before the guide is drawn (PL.MxGuideAdd)
  PL.hs_view = PL.hs_half == 1 and "mix" or "aura"
  if mix == 0 then
    PL.hs_view = "aura"
  end
  PL.HsPrevItemInfo()
  if mix == 0 then
    return
  end
  if aura ~= 0 and PL.hs_view ~= "mix" then
    return                                       -- the aura slot's panel, as drawn
  end
  PL.HsShowMix(mix)
  if PL.guide_redo ~= nil then
    pcall(PL.guide_redo)                         -- a mix-only row is removable (Y)
  end
end

-- Y on a mix-only Hiper row: «Restablecer» (the retail path only sees the empty aura slot)
PL.HsPrevFunction = OnFunction
function OnFunction(a1, a2)
  if evt_co == nil and a1 == 4109882573 and n14 ~= L_BTN
      and funcLuaMenuCommand(C.FOCUS_IDX, L_ROW) == 0 and (EVT_Skill(0) == 0 or PL.hs_half == 1) and PL.HsMix() ~= 0
      and not EVT_IsPrime() and not PL.IdolFixed(0) then
    evt_co = coroutine.create(function()
      EVT_ResetCoroutine(0)
    end)
    return
  end
  return PL.HsPrevFunction(a1, a2)
end

-- Left / Right on the Hiper row select the half (round 6: on the press edge, no lock; every menu controller the game
-- may have selected, then the pad / arrow keys while the list has the control focus; never a controller switch)
function PL.HsLR()
  local R = PL.HS_ROW
  local left, right = false, false
  for _, c in ipairs(R.CTRLS) do
    left = left or funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, c, R.K_LEFT) == true
    right = right or funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, c, R.K_RIGHT) == true
  end
  if not left and not right and funcLuaMenuCommand(R.CTRL_FOCUS, L_ROW) == true then
    local ok, held = pcall(funcLuaCommand, R.PAD)
    if ok and type(held) == "number" and held > 0 then
      left = math.floor(held / R.PAD_LEFT) % 2 == 1
      right = math.floor(held / R.PAD_RIGHT) % 2 == 1
    end
    local okl, kl = pcall(funcLuaCommand, R.VKEY, R.VK_LEFT)
    local okr, kr = pcall(funcLuaCommand, R.VKEY, R.VK_RIGHT)
    left = left or (okl and kl == true)
    right = right or (okr and kr == true)
  end
  if left == right then
    return 0
  end
  return left and -1 or 1
end

-- the row's native touch quad (instance 0): {w, h, x, y}
function PL.HsTouch(b)
  local R = PL.HS_ROW
  funcLuaMenuCommand(R.SCALE, L_ROW, 0, R.TOUCH, b[1], b[2])
  funcLuaMenuCommand(R.TRANSLATE, L_ROW, 0, R.TOUCH, 0, b[3])
  funcLuaMenuCommand(R.TRANSLATE, L_ROW, 0, R.TOUCH, 1, b[4])
end

-- the half under the pointer (0 aura, 1 mix), nil = not over a plate of the Hiper row
function PL.HsPointerHalf()
  local R = PL.HS_ROW
  local x, y = funcLuaMenuCommand(R.PTR_POS)
  local gx, gy = funcLuaMenuCommand(R.PTR_GPOS, L_ROW, 0)
  if type(x) ~= "number" or type(y) ~= "number" or type(gx) ~= "number" or type(gy) ~= "number" then
    return nil
  end
  local lx, ly = x - gx, -y - gy
  if ly < R.HIT_Y[1] or ly > R.HIT_Y[2] then
    return nil
  end
  for h = 0, 1 do
    if lx >= R.HIT_X[h + 1][1] and lx <= R.HIT_X[h + 1][2] then
      return h
    end
  end
  return nil
end

-- hover: the pointer moved over a plate of the focused Hiper row -> that half (a pointer at rest never overrides
-- Left / Right)
function PL.HsPollPointer()
  local R = PL.HS_ROW
  local x, y = funcLuaMenuCommand(R.PTR_POS)
  if type(x) ~= "number" or type(y) ~= "number" then
    return
  end
  local moved = funcLuaMenuCommand(R.PTR_MOVED) == true
  if PL.hs_ptr ~= nil and (math.abs(x - PL.hs_ptr[1]) > 1 or math.abs(y - PL.hs_ptr[2]) > 1) then
    moved = true
  end
  PL.hs_ptr = {x, y}
  if not moved or EVT_IsLocked(0) then
    return
  end
  local h = PL.HsPointerHalf()
  if h ~= nil then
    PL.HsSetHalf(h)
  end
end

-- a click (mouse button / Accept on the pointer) that opens the Hiper picker: the half under the pointer first
function PL.HsPointerPick()
  local R = PL.HS_ROW
  local clicked = false
  for _, k in ipairs(R.PTR_CLICK) do
    clicked = clicked or funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, 1332654303 --[[MENU_CTRL]], k) == true
  end
  if not clicked or EVT_IsLocked(0) then
    return
  end
  local h = PL.HsPointerHalf()
  if h ~= nil and h ~= PL.hs_half then
    PL.hs_half = h
    PL.hs_view = h == 1 and "mix" or "aura"
    pcall(PL.HsSplitRow)
  end
end

-- the selected half follows Left / Right (R3 does nothing here, owner 2026-10-19)
function PL.HsPollR3()
  PL.hs_r3_wait = math.max(0, (PL.hs_r3_wait or 0) - 1)
  if evt_co ~= nil then
    PL.hs_lr_prev = 2                              -- a key still held when a coroutine ends is not a new press
    return
  end
  if n14 == L_BTN or funcLuaMenuCommand(C.FOCUS_IDX, L_ROW) ~= 0 then
    PL.hs_lr_prev = 2
    if PL.hs_half ~= 0 then                        -- off the row: the aura half again, quietly
      PL.hs_half = 0
      PL.hs_view = "aura"
      if not EVT_IsLocked(0) then
        pcall(PL.HsSplitRow)
      end
    end
    return
  end
  pcall(PL.HsPollPointer)
  local dir = PL.HsLR()
  local prev = PL.hs_lr_prev
  PL.hs_lr_prev = dir
  if dir ~= 0 and dir ~= prev then
    if prev ~= 2 then
      PL.HsSetHalf(dir > 0 and 1 or 0)
    end
    return
  end
end

PL.HsPrevStep = Step
function Step(...)
  local r = PL.HsPrevStep ~= nil and PL.HsPrevStep(...) or nil
  pcall(PL.HsPollR3)
  if PL.hs_plates_wait and PL.HsPlatesReady() then   -- the tinted plates came in: redraw the split row
    PL.hs_plates_wait = false
    if not EVT_IsLocked(0) then
      pcall(PL.HsSplitRow)
    end
  end
  return r
end
-- ===== Two Hiper slots END =====
