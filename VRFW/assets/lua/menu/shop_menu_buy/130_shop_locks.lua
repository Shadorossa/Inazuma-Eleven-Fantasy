-- VR-Framework › locked shop rows, menu side. Handlers of the framework's shop_menu_buy host (VRFW_Host, 000_host.lua); no engine call at load time.
--
-- A shop row whose progress condition fails is listed when a mod declares its shop ([[VRFW.ShopLock]], scripts\shop_rows.lua).
-- This file draws such a row: greyed card (material preset list_base of shop01_02_list_item at 0.5, as retail greys a locked
-- special move), a padlock instead of every icon of the row, what unlocks it as the row's name, no detail card, no model
-- preview, a button guide with Accept only, and Accept refused with the retail «cannot» sound and a notice.
-- The sentence: CMND_VRFW_SHOP_LOCK_SOURCE names the chapter, match, opponent or flag text; the framework's text rows
-- vrfw_shop_lock_* (text\rows\shop_locks.toml) give it in the game's language.
-- shop01_02_list_item has 8 recycled instances: CMND_VRFW_SHOP_LOCKED(instance) tells which one shows a locked row.
if VRFW_Host ~= nil then
  local STEM = "shop_menu_buy"
  local ID = "vr_framework.shop_locks_"

  local CMD = {
    LOCK_ON = 3539236056,       -- CMND_VRFW_SHOP_LOCK_ON(shop) -> bool
    LOCKED = 3513021981,        -- CMND_VRFW_SHOP_LOCKED(instance) -> locked, row, kind, a, b
    LOCKED_ITEM = 1970439008,   -- CMND_VRFW_SHOP_LOCKED_ITEM(item) -> locked, kind, a, b
    SOURCE = 2385272416,        -- CMND_VRFW_SHOP_LOCK_SOURCE(kind, a, b, language) -> form, name, number, text id
    TEXT_GET = 4074371074,      -- CMND_TEXT_GET(text id) -> text
    LANGUAGE = 477234096,       -- CMND_GET_LANGUAGE_CODE
    LOG = 3661580131,           -- CMND_EVT_LOG
    PLAY_SE = 1917805374,
    FOCUS_INSTANCE = 2603265800,
    MATERIAL_COLOR = 801406373,
    SET_TEXT = 1083631230,
    SET_SPRITE = 558735651,
    LOAD_TEXTURE = 839427544,   -- CMND_LOAD_MENU_RES_TEXTURE
    TEXTURE_LOADING = 1506186496,
    MESH_VISIBLE = 2277921386,  -- CMND_IS_MESH_VISIBLE
    SET_MESH_VISIBLE = 3405944500,
    LAYER_OPEN = 2640875187,    -- CMND_IS_OPEN_LAYER
    LAYER_VISIBLE = 1262717583, -- CMND_IS_LAYER_VISIBLE
    SET_LAYER_VISIBLE = 711242136,
    SET_OBJECT_VISIBLE = 2171393651,
    NODE_VISIBLE = 2158717427,  -- (layer, node, visible, instance): a joint, whatever the engine does to its mesh
    GET_TRANS = 2491463760,     -- (layer, instance, node) -> x, y, z
    SET_TRANS = 1856671416,     -- (layer, instance, node, x, y, z)
    NODE_SIZE = 2885415772,     -- (layer, instance, node, width, height)
    GUIDE_SET = 2209673388,
    GUIDE_KEYS = 452337289,
    MESSAGE = 2289627655,
    MESSAGE_WAIT = 2351835063,
  }
  local SE_CANNOT = 2086672038  -- sy0003
  local LIST = 3747827324       -- shop01_02_list_item
  local LIST_BASE = 2569990914  -- shop01_01_list_base
  local BG = 717014739          -- shop01_00_background: its close = the shop is going
  local GREY = 0.5              -- retail grey of a locked special move
  local MATERIAL = 2239373704   -- list_base: CMenuChangeMaterialColor preset of shop01_02_list_item
  local TEX_PATH = "#/menu/150_shop/vrfw_shop_lock/vrfw_shop_lock.g4tx"
  local TEX = 976744312         -- crc32(TEX_PATH)
  local LOCK = 443981853        -- vrfw_shop_lock_dark
  local LOCK_ALT = 577900967    -- vrfw_shop_lock_light (set first so the sprite always changes)
  local ICON_NODE = 2176982228  -- icon_item_dmy03: the row icon's node
  local ICON_MESH = 303536660   -- _icon_item_dmy01
  local CHARA_MESH = 3879052096 -- _list_chr_dmy01: character / aura icon
  local CHARA_NODE = 994901711  -- list_chr_dmy01
  -- the two icon boxes of shop01_02 (layout units): the item icon 80 x 80 inside the card, the character icon 128 x 128
  -- (it rises over the card's edges by design). A padlock on the character mesh is drawn in the item icon's box.
  local ICON_SIZE = 80
  local CHARA_SIZE = 128
  local SPIRIT_LAYER = 1048618417 -- cmn01_07_sprit_icon
  -- meshes of a row that tell what it sells: hidden on locked rows
  local HIDE_MESHES = {
    530479263,   -- _list_type_dmy01: element
    2496182457,  -- _type_base01
    3044722974,  -- _icon_area_dmy01
    1896097465,  -- _icon_buff_dmy01
    3937907647,  -- _icon_synergy_dmy01
    3541433305,  -- _synergy_icon_base01
    2203859798,  -- _icon_position_dmy01
    441805548,   -- _icon_position_dmy02
  }
  -- the row's name nodes: item rows use _text_list01, character / aura rows _text_coach01
  local NAME_NODES = { 931545948, 3705682548, 1059092884, 1230493388 }
  -- detail card layers (retail UpdateSelectItemInfo / ClearNotUseUpdateSelectInfoLayer)
  local DETAIL_LAYERS = {
    3633022365,  -- team00_21_item_detail
    1510257498,  -- team00_21b_item_detail
    2628045944,  -- team02_02_skill_detail_info
    26273556,    -- team00_30_p1_balloon
    3764752959,  -- team00_28_six_sense_detail_info
    3851505884,  -- team03_01_tactics_info
    812096501,   -- team00_35_chara_title_detail_info
    1921826160,  -- team00_40_change_page_guide
    2237891512,  -- team00_40_synergy_change_page_guide
    1492214428,  -- team16_05_synergy_item_detail_shop
    561386529,   -- soccer11_04_chara_stasus
    2129935798,  -- shop01_08_status_plate_attach
  }
  -- keys of the preview / detail that do nothing on a locked row
  local DEAD_KEYS = {
    [2027013857] = true,  -- details / try on
    [2870443176] = true,  -- rotate characters
    [3887644467] = true,  -- camera zoom
    [3484753847] = true,  -- camera up / down
    [1456809643] = true,  -- description balloon
  }
  local TX = {
    chapter_title = 1791082148,   -- vrfw_shop_lock_chapter_title
    chapter = 1264032831,         -- vrfw_shop_lock_chapter
    match = 859015253,            -- vrfw_shop_lock_match
    beat_chronicle = 1889241075,  -- vrfw_shop_lock_beat_chronicle
    beat = 3572702074,            -- vrfw_shop_lock_beat
    chronicle = 3455767110,       -- vrfw_shop_lock_chronicle
    later = 2775318297,           -- vrfw_shop_lock_later
    notice = 590314619,           -- vrfw_shop_lock_notice
  }
  local KEY_ENTER, GUIDE_ENTER_A, GUIDE_ENTER_B = 1981080283, 1847312674, 2750714971

  local SL = {}
  VRFW_ShopLocks = SL

  local function reset()
    SL.on_by_shop = {}      -- shop id -> rows listed as locked
    SL.phrases = {}         -- "kind:a:b" -> sentence
    SL.focus = -1
    SL.tint = {}            -- instance -> greyed
    SL.rows = {}            -- locked instance -> frames since its fill
    SL.saved = {}           -- instance -> mesh state before it was locked { slot, mesh, icon, chr, spirit }
    SL.detail_hidden = false
    SL.card_visible = {}
    SL.texture = 0          -- 0 not asked, 1 loading, 2 ready
    SL.closing = false
  end
  reset()

  local function Log(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    pcall(funcLuaCommand, CMD.LOG, "vrfw.ShopLocks " .. table.concat(t, " "))
  end

  local function L()
    local h = VRFW_Host.hosts[STEM]
    return h and h.L or {}
  end
  local function local_of(name)
    local ok, v = pcall(function() return L()[name] end)
    if ok then return v end
    return nil
  end

  local function menu(...)
    return pcall(funcLuaMenuCommand, ...)
  end

  -- rows of the open shop are listed as locked
  function SL.On()
    local ok, id = pcall(GetShopId)
    if not ok or type(id) ~= "number" then return false end
    local on = SL.on_by_shop[id]
    if on == nil then
      local okc, r = pcall(funcLuaCommand, CMD.LOCK_ON, id)
      on = okc and r == true
      SL.on_by_shop[id] = on
      if on then Log("shop", id, "lists locked rows") end
    end
    return on
  end

  local function text(id)
    local ok, s = pcall(funcLuaCommand, CMD.TEXT_GET, id)
    if ok and type(s) == "string" and s ~= "" then return s end
    return nil
  end

  local function fill(id, num, name)
    local s = text(id)
    if s == nil then return nil end
    s = s:gsub("<NUM>", tostring(num or ""))
    s = s:gsub("<NAME>", (tostring(name or ""):gsub("%%", "%%%%")))
    return s
  end

  -- what a locked row waits for, as a sentence in the game's language
  function SL.Phrase(kind, a, b)
    local key = tostring(kind) .. ":" .. tostring(a) .. ":" .. tostring(b)
    local s = SL.phrases[key]
    if s ~= nil then return s end
    local okc, code = pcall(funcLuaCommand, CMD.LANGUAGE)
    local ok, form, name, num, tid = pcall(funcLuaCommand, CMD.SOURCE, kind or 0, a or 0, b or 0, okc and code or -1)
    if ok then
      local named = type(name) == "string" and name ~= ""
      if form == "text" then
        s = text(tid)
      elseif form == "chapter" then
        s = named and fill(TX.chapter_title, num, name) or fill(TX.chapter, num)
      elseif (form == "match" or form == "beat_chronicle" or form == "beat") and named then
        s = fill(TX[form], num, name)
      elseif form == "chronicle" then
        s = text(TX.chronicle)
      end
    end
    s = s or text(TX.later) or "???"
    SL.phrases[key] = s
    return s
  end

  -- a list instance: locked, kind, a, b, row (row 0 = the framework knows no row for it)
  function SL.InstanceInfo(inst)
    if type(inst) ~= "number" or inst < 0 or not SL.On() then return false end
    local ok, locked, row, kind, a, b = pcall(funcLuaCommand, CMD.LOCKED, inst)
    if not ok then return false end
    return locked == true, kind, a, b, row
  end

  function SL.ItemInfo(item)
    if type(item) ~= "number" or item == 0 or not SL.On() then return false end
    local ok, locked, kind, a, b = pcall(funcLuaCommand, CMD.LOCKED_ITEM, item)
    if ok and locked == true then return true, kind, a, b end
    return false
  end

  local function focus_instance()
    local ok, inst = menu(CMD.FOCUS_INSTANCE, LIST)
    if ok and type(inst) == "number" and inst >= 0 then return inst end
    return SL.focus
  end

  -- the focused row: locked, kind, a, b (by its instance when the framework knows its row, else by the item)
  function SL.FocusInfo(item)
    if not SL.On() then return false end
    local l, kind, a, b, row = SL.InstanceInfo(focus_instance())
    if type(row) == "number" and row ~= 0 then return l, kind, a, b end
    if type(item) ~= "number" then
      local ok, it = pcall(GetShopListItemInfo, 0)
      item = ok and it or nil
    end
    return SL.ItemInfo(item)
  end

  -- the focused row of the list (not the token / coin pickers) is locked
  function SL.FocusList(item)
    if not SL.On() then return false end
    if local_of("flag") == true or local_of("flag10") == true then return false end
    return (SL.FocusInfo(item)) == true
  end

  local function texture_ready()
    if SL.texture == 0 then
      menu(CMD.LOAD_TEXTURE, TEX_PATH)
      SL.texture = 1
    end
    if SL.texture == 1 then
      local ok, loading = pcall(funcLuaCommand, CMD.TEXTURE_LOADING, TEX)
      if ok and not loading then SL.texture = 2 end
    end
    return SL.texture == 2
  end

  -- the card colour of a row (material preset list_base): grey or back to normal
  function SL.GreyRow(layer, inst, on)
    local f = on and GREY or 1
    menu(CMD.MATERIAL_COLOR, layer, inst, MATERIAL, f, f, f)
    SL.tint[inst] = on or nil
  end

  local function slot_type()
    local ok, s = pcall(GetCurrentSlotType)
    if ok then return s end
    return -1
  end

  local function mesh_visible(layer, mesh, inst)
    local ok, v = menu(CMD.MESH_VISIBLE, layer, mesh, inst)
    return ok and v == true
  end

  local function spirit_open(inst)
    local ok, open = menu(CMD.LAYER_OPEN, SPIRIT_LAYER, inst)
    return ok and open == true
  end

  -- the mesh state the engine gave this instance (once per instance and tab)
  local function save(layer, inst)
    local slot = slot_type()
    local rec = SL.saved[inst]
    if rec ~= nil and rec.slot == slot then return end
    rec = { slot = slot, mesh = {} }
    for _, m in ipairs(HIDE_MESHES) do rec.mesh[m] = mesh_visible(layer, m, inst) end
    rec.icon = mesh_visible(layer, ICON_MESH, inst)
    rec.chr = mesh_visible(layer, CHARA_MESH, inst)
    local old = SL.saved[inst]
    if old ~= nil and old.boxed then
      rec.chara_at, rec.boxed = old.chara_at, true   -- the joint is still in the padlock's box: its own place is the old one
    else
      local okc, cx, cy, cz = menu(CMD.GET_TRANS, layer, inst, CHARA_MESH)
      if okc and type(cx) == "number" and type(cy) == "number" then rec.chara_at = { cx, cy, cz or 0 } end
    end
    if spirit_open(inst) then
      local ok, vis = menu(CMD.LAYER_VISIBLE, SPIRIT_LAYER, inst)
      rec.spirit = ok and vis == true
    end
    SL.saved[inst] = rec
  end

  -- a locked row: only the padlock. The engine redraws the row icon's sprite on its own, so the padlock goes on the mesh the
  -- engine does not use for this row (item rows: the character mesh; character / aura rows: the item icon mesh). The
  -- engine's mesh is hidden at its JOINT (the engine shows the mesh again when its icon texture arrives, a frame after
  -- the fill: the real icon flashed under the padlock); a padlock on the character mesh is moved and sized into the item
  -- icon's box (the character box overflows the card).
  local function apply_row(layer, inst)
    for _, m in ipairs(HIDE_MESHES) do menu(CMD.SET_MESH_VISIBLE, layer, m, false, inst) end
    if spirit_open(inst) then menu(CMD.SET_LAYER_VISIBLE, SPIRIT_LAYER, inst, false) end
    local rec = SL.saved[inst]
    local lock_mesh, lock_node, engine_mesh = CHARA_MESH, CHARA_NODE, ICON_MESH
    if rec ~= nil and rec.chr == true then
      lock_mesh, lock_node, engine_mesh = ICON_MESH, ICON_NODE, CHARA_MESH
    end
    menu(CMD.SET_MESH_VISIBLE, layer, engine_mesh, false, inst)
    menu(CMD.NODE_VISIBLE, layer, engine_mesh, false, inst)
    menu(CMD.NODE_VISIBLE, layer, lock_mesh, true, inst)
    if lock_mesh == CHARA_MESH and (rec == nil or not rec.boxed) then
      local ok, x, y, z = menu(CMD.GET_TRANS, layer, inst, ICON_MESH)
      if ok and type(x) == "number" and type(y) == "number" then
        menu(CMD.SET_TRANS, layer, inst, CHARA_MESH, x, y, z or 0)
        menu(CMD.NODE_SIZE, layer, inst, CHARA_MESH, ICON_SIZE, ICON_SIZE)
        if rec ~= nil then rec.boxed = true end
      end
    end
    if texture_ready() then
      menu(CMD.SET_SPRITE, layer, TEX, LOCK_ALT, lock_node, 0, inst)
      menu(CMD.SET_SPRITE, layer, TEX, LOCK, lock_node, 0, inst)
      menu(CMD.SET_MESH_VISIBLE, layer, lock_mesh, true, inst)
    else
      menu(CMD.SET_MESH_VISIBLE, layer, lock_mesh, false, inst)
    end
  end

  -- a recycled instance that shows a normal row again: its meshes as the engine left them
  local function restore(layer, inst)
    SL.rows[inst] = nil
    local rec = SL.saved[inst]
    SL.saved[inst] = nil
    menu(CMD.NODE_VISIBLE, layer, ICON_MESH, true, inst)
    menu(CMD.NODE_VISIBLE, layer, CHARA_MESH, true, inst)
    if rec ~= nil and rec.boxed and rec.chara_at ~= nil then
      menu(CMD.SET_TRANS, layer, inst, CHARA_MESH, rec.chara_at[1], rec.chara_at[2], rec.chara_at[3])
      menu(CMD.NODE_SIZE, layer, inst, CHARA_MESH, CHARA_SIZE, CHARA_SIZE)
    end
    if rec == nil then
      menu(CMD.SET_MESH_VISIBLE, layer, ICON_MESH, true, inst)
      menu(CMD.SET_MESH_VISIBLE, layer, CHARA_MESH, false, inst)
      return
    end
    local engine_mesh = rec.chr and CHARA_MESH or ICON_MESH
    if not mesh_visible(layer, engine_mesh, inst) then
      menu(CMD.SET_MESH_VISIBLE, layer, ICON_MESH, rec.icon ~= false, inst)
      menu(CMD.SET_MESH_VISIBLE, layer, CHARA_MESH, rec.chr == true, inst)
    end
    if rec.slot ~= slot_type() then return end
    for m, vis in pairs(rec.mesh) do
      if vis and not mesh_visible(layer, m, inst) then menu(CMD.SET_MESH_VISIBLE, layer, m, true, inst) end
    end
    if rec.spirit and spirit_open(inst) then menu(CMD.SET_LAYER_VISIBLE, SPIRIT_LAYER, inst, true) end
  end

  -- the detail card on the right goes while a locked row has the focus
  local function hide_detail()
    local n24, n28 = local_of("n24"), local_of("n28")
    local cards = { 3633022365, 1510257498 }
    if type(n28) == "number" and n28 ~= 0 then table.insert(cards, 1, n28) end
    if not SL.detail_hidden then
      SL.card_visible = {}
      for _, l in ipairs(cards) do
        local ok, vis = menu(CMD.LAYER_VISIBLE, l, 0)
        if ok and vis == true then SL.card_visible[l] = true end
      end
      if type(n24) == "number" and n24 ~= 0 then
        local ok, vis = menu(CMD.LAYER_VISIBLE, n24, 0)
        if ok and vis == true then SL.card_visible[n24] = true end
      end
    end
    SL.detail_hidden = true
    for _, l in ipairs(cards) do menu(CMD.SET_LAYER_VISIBLE, l, 0, false) end
    if type(n24) == "number" and n24 ~= 0 then menu(CMD.SET_LAYER_VISIBLE, n24, 0, false) end
    for _, l in ipairs(DETAIL_LAYERS) do menu(CMD.SET_LAYER_VISIBLE, l, 0, false) end
    pcall(SetVisibleAllAuraDetailInfo, false)
    pcall(SetHideSynergyDetail)
    menu(CMD.SET_OBJECT_VISIBLE, 2394257302 --[[shop01_10_body_type_item]], false)
    menu(CMD.SET_OBJECT_VISIBLE, 858725131 --[[mainmenu01_08_chara_3d_shadow]], false)
    pcall(function() funcLuaMenuCommand(CMD.SET_LAYER_VISIBLE, GetShopHomeAwayLayerName(), 0, false) end)
    for i = 0, 3 do pcall(SetCharaModelVisible, i, false) end
  end

  -- a normal row after a locked one: the generic card retail does not show again by itself (kits 80 / 140, auras, moves:
  -- retail shows theirs)
  local function show_detail(kind_of_item)
    if not SL.detail_hidden then return end
    SL.detail_hidden = false
    if kind_of_item == 80 or kind_of_item == 140 then return end
    local n24 = local_of("n24")
    if type(n24) == "number" and SL.card_visible[n24] then menu(CMD.SET_LAYER_VISIBLE, n24, 0, true) end
  end

  local function closing() return SL.closing == true end

  -- ---------------------------------------------------------------------------------------------- handlers
  local function on(point, phase, fn, create)
    VRFW_Host.on(STEM, point, { id = ID .. point, phase = phase, fn = fn, create = create })
  end

  on("OnShopInit", "before", function(...)
    reset()
    if SL.On() then texture_ready() end
  end)

  on("OnCloseLayer", "before", function(a1, ...)
    if a1 == BG then SL.closing = true end
  end, true)

  on("FinalizeMenu", "before", function(...)
    SL.closing = true
  end, true)

  -- engine fill of each row (end of the list item fill): a locked row is drawn here, a recycled one restored
  on("SetupGrayout", "around", function(nxt, a1, a2, a3)
    if a1 ~= LIST then return nxt(a1, a2, a3) end
    local locked, kind, pa, pb = SL.InstanceInfo(a2)
    if locked then
      nxt(a1, a2, GREY)
      SL.GreyRow(a1, a2, true)
      local s = SL.Phrase(kind, pa, pb)
      for _, node in ipairs(NAME_NODES) do menu(CMD.SET_TEXT, a1, node, s, a2) end
      save(a1, a2)
      SL.rows[a2] = 0
      apply_row(a1, a2)
      return
    end
    if SL.rows[a2] ~= nil or SL.saved[a2] ~= nil then restore(a1, a2) end
    if SL.tint[a2] then SL.GreyRow(a1, a2, false) end
    return nxt(a1, a2, a3)
  end)

  -- every frame: the engine repaints icons when it recycles rows
  on("Step", "after", function(r, ...)
    if next(SL.rows) == nil or closing() then return end
    for inst, k in pairs(SL.rows) do
      SL.rows[inst] = k + 1
      apply_row(LIST, inst)
    end
  end)

  on("OnChangeFocus", "before", function(a1, a2)
    if a1 == LIST then
      local ok, inst = menu(CMD.FOCUS_INSTANCE, a1)
      if ok and type(inst) == "number" then SL.focus = inst end
    end
  end)

  on("UpdateSelectItemInfo", "after", function(r, a1, a2, a3, ...)
    if closing() or not SL.On() then return end
    local was = SL.detail_hidden
    if SL.FocusList(a2) then
      hide_detail()
      pcall(ResetCharaModelAll)
    else
      show_detail(a3)
      if was and (a3 == 80 or a3 == 140) then pcall(ChangeUniformModelView, local_of("flag4"), true) end
    end
    if was ~= SL.detail_hidden then pcall(UpdateButtonGuide, true) end
  end)

  on("OnFunction", "around", function(nxt, a1, a2, ...)
    if DEAD_KEYS[a1] and SL.FocusList() then return end
    local r = table.pack(nxt(a1, a2, ...))
    if SL.detail_hidden and not closing() and SL.FocusList() then hide_detail() end
    return table.unpack(r, 1, r.n)
  end)

  -- Accept on a locked row: the retail «cannot» sound and a notice through the shop's own general window
  on("OnEnter", "around", function(nxt, a1, a2)
    if a1 == LIST_BASE then
      local locked, kind, pa, pb = SL.FocusInfo()
      if locked then
        pcall(funcLuaCommand, CMD.PLAY_SE, SE_CANNOT)
        local phrase = SL.Phrase(kind, pa, pb)
        local msg = text(TX.notice)
        msg = msg and msg:gsub("<TEXT>", (phrase:gsub("%%", "%%%%"))) or phrase
        local okw = type(GENERAL_WINDOW) == "table" and type(GENERAL_WINDOW.ReserveGeneralWindow) == "function"
          and pcall(GENERAL_WINDOW.ReserveGeneralWindow, "", "", "", msg, 0)
        if not okw then
          pcall(funcLuaCommand, CMD.MESSAGE, msg, 0, 0, 0, 0, 0, false)
          pcall(funcLuaCommand, CMD.MESSAGE_WAIT, 1, 0)
        end
        return 1
      end
    end
    return nxt(a1, a2)
  end)

  on("CheckSufficientFunds", "around", function(nxt, a1, ...)
    if SL.On() and (SL.FocusInfo()) == true then return false end
    return nxt(a1, ...)
  end)

  -- no kit preview (4 characters wearing it) for a locked row
  on("ChangeCharaModels", "around", function(nxt, a1, ...)
    if closing() then return end
    if a1 ~= nil and a1 ~= 0 and SL.FocusList(a1) then
      pcall(ResetCharaModelAll)
      return
    end
    return nxt(a1, ...)
  end)

  on("ChangeUniformModelInfoVisible", "around", function(nxt, a1, a2, ...)
    if a1 == true and SL.FocusList() then a1 = false end
    return nxt(a1, a2, ...)
  end)

  -- button guide of a locked row: Accept only
  on("UpdateButtonGuide", "around", function(nxt, a1, a2, ...)
    if a1 and SL.FocusList() then
      local layer, base, line = local_of("n"), 1138543975 --[[mainmenu01_06_base_button_guide]], 9396745 --[[mainmenu01_07_button_guide]]
      if local_of("flag3") == true then
        layer, base, line = 3170360552 --[[shop_menu]], 2062970623 --[[shopmenu01_06_base_button_guide]], 362164101 --[[shopmenu01_07_button_guide]]
      end
      local ok = pcall(function()
        funcLuaMenuCommand(CMD.GUIDE_SET, layer, base, { GUIDE_ENTER_A }, { GUIDE_ENTER_B }, { 0 }, { 0 }, { 0 }, true, false, false, 0, line)
        funcLuaMenuCommand(CMD.GUIDE_KEYS, layer, base, { KEY_ENTER })
      end)
      if ok then return end
    end
    return nxt(a1, a2, ...)
  end)
end
