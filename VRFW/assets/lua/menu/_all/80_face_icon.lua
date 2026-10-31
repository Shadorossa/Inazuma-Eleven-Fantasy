-- VRFW_FaceIcon: a character's miniface drawn into the face mesh of a menu layer instance with the game's chara icon
-- command (552280324, the face + kit icon of the bank and team lists). Shared by every screen that shows minifaces
-- instead of calling the command themselves. Definitions only: this file runs in every menu VM (lua\_all), no engine
-- call at load.
--   VRFW_FaceIcon.Face(layer, idx, who, mesh, slot[, opts]) -> "drawn" | "loading" | false
--     who    a chara key (number), { chara = id } or { card = chara_param id } (turned into its chara id)
--     mesh   the face mesh of the instance (e.g. _icon_chr_dmy01), slot its texture slot (e.g. icon_chr_dmy01)
--     opts   { kit = 0, keeper = false, use_args = false, face_only = false }: the command's later arguments
--     The face is asked again only when the instance shows another character. The mesh stays hidden while the face
--     loads and when it cannot be drawn: never a blank face. One log line per failure (instance + character).
--   VRFW_FaceIcon.Card(layer, idx, who, x, y, size[, opts]) -> the same answer: an instance of a copy of the retail
--     list character card (team00_01_chara_card_for_list) shown as its portrait only (every other part hidden),
--     centred on (x, y) screen px (y down), `size` px high. The caller shows the instance itself. opts.portrait = true
--     keeps the card's portrait background and its gradient (the full portrait look of the player pages) instead of
--     the bare face.
--   VRFW_FaceIcon.Request(layer, idx, who, mesh, slot[, opts]) -> true | false: one request of the face (slot reset,
--     then the command), nothing remembered and no mesh shown or hidden: for a screen that shows the mesh itself
--     (its own fade-in or its own art on the same mesh). false = no character or the command refused.
--   VRFW_FaceIcon.Pending() -> true while a face asked by this VM is still loading (its mesh hidden)
--   VRFW_FaceIcon.Settle()  the loaded faces shown; a face still loading after WAIT calls is given up (hidden, logged).
--                           Called from the screen's Step only while Pending() is true.
--   VRFW_FaceIcon.Forget(layer[, idx]) an instance (or every instance of a layer) drawn again from scratch next time:
--                           call it when the instance was hidden for good or set up again by the engine.
if VRFW_FaceIcon == nil then
  local F = {
    FACE = 552280324,            -- (layer, idx, face only, mesh, slot, 0, 0, key[, kit, keeper, use args]) -> false = not drawn
    RESET = 4176779611,          -- (layer, idx, slot): the slot's texture back to the object's own
    LOADING = 1277042906,        -- (layer, idx) -> true while the instance's face texture loads
    MESH_VISIBLE = VRFW_Cmd.SET_MESH_VISIBLE,   -- (layer, mesh, on, idx)
    NODE_VISIBLE = 2158717427,   -- (layer, node, on, idx)
    TEXT_VISIBLE = 2735666188,   -- (layer, text node, on, idx)
    SCALE = VRFW_Cmd.SET_LAYER_LOCAL_SCALE,          -- (layer, sx, sy, sz, idx)
    POS = VRFW_Cmd.SET_LAYER_LOCAL_POS,            -- (layer, x, y, z, idx)
    CHARA_OF_CARD = 347353059,   -- (chara_param id) -> chara id
    LOG = VRFW_Cmd.EVT_LOG,            -- CMND_EVT_LOG
    WAIT = 300,                  -- Settle calls a face may take to load before it is given up
    -- the list character card's portrait: its face mesh and slot, its height and the offset of its centre from the
    -- layer origin (px at scale 1), the name text and the parts hidden around the portrait
    CARD = {
      MESH = 2828003679 --[[_icon_chr_dmy_l01]], SLOT = 21929195 --[[icon_chr_dmy_l01]], NAME = 170976702 --[[_text_chr01]],
      RH = 156, OX = 59, OY = 11,
      -- the portrait's background and gradient: hidden unless opts.portrait
      FRAME = {2907077971 --[[_icon_chr_base_l01]], 2211886546 --[[_icon_chr_gradation_l01]]},
      HIDE = {
        960763094 --[[_seasonal_frame_l01]], 2508362790 --[[_avatar_frame_l01]], 3345942320 --[[_icon_chr_focus_l01]],
        1721769611 --[[_icon_chr_position_dmy_l01]], 3895971012 --[[_icon_base_l01]],
        32585899 --[[_icon_chr_type_dmy_l01]], 814224422 --[[_icon_lock01]], 2815608092 --[[_icon_captain01]],
        3203992661 --[[_icon_ai_role_dmy01]], 1343488901 --[[_gtxt_lv_l01]], 2635558741 --[[_icon_card01]],
        1458727926 --[[_icon_chr_def01_l]], 2942116298 --[[_icon_chr_grayout01]], 338392935 --[[_basara_avatar_l01]],
        1451641049 --[[_num_chr_dmy_l01]], 3482261859 --[[_num_chr_dmy_l02]], 4280102433 --[[_gauge_exp_base_l01]],
        3724093868 --[[_gauge_exp_l01]], 897168128 --[[_icon_synergy_l01]], 2893079226 --[[_icon_synergy_l02]],
        3098974311 --[[_leader_base01]], 3330617040 --[[_gtxt_leader01]],
      },
      HIDE_NODES = {
        3279539624 --[[_pos_base02]], 1387831794 --[[_pos_leader01]], 3524586656 --[[_pos_ai_role01]],
        2265056496 --[[_num_chr_l01]], 504059210 --[[_num_chr_l02]], 3442901805 --[[_pos_gauge_exp_l01]],
      },
    },
    shown = {},                  -- "layer:idx" -> { key, mesh, state = "drawn" | "loading" | "failed" }
    waiting = {},                -- "layer:idx" -> { layer, idx, mesh, key, left }
    card_key = {},               -- "layer:idx" -> the key whose card parts were hidden
  }
  VRFW_FaceIcon = F

  local function log(...)
    pcall(funcLuaCommand, F.LOG, "vrfw.FaceIcon", ...)
  end

  local function menu(cmd, ...)
    local ok, a = pcall(funcLuaMenuCommand, cmd, ...)
    if ok then
      return a
    end
    return nil
  end

  -- the chara key of `who` (nil, reason when there is none)
  local function key_of(who)
    if type(who) == "number" then
      return who ~= 0 and who or nil, "no character"
    end
    if type(who) ~= "table" then
      return nil, "no character"
    end
    if type(who.chara) == "number" and who.chara ~= 0 then
      return who.chara
    end
    if type(who.card) == "number" and who.card ~= 0 then
      local ok, id = pcall(funcLuaCommand, F.CHARA_OF_CARD, who.card)
      if ok and type(id) == "number" and id ~= 0 then
        return id
      end
      return nil, string.format("card %d has no character", who.card)
    end
    return nil, "no character"
  end

  local function fail(k, layer, idx, mesh, key, why)
    menu(F.MESH_VISIBLE, layer, mesh, false, idx)
    F.waiting[k] = nil
    local s = F.shown[k]
    if s ~= nil and s.state == "failed" and s.key == key then
      return false
    end
    F.shown[k] = { key = key, mesh = mesh, state = "failed" }
    log("face not drawn", layer, idx, tostring(key), why)
    return false
  end

  -- the face command on (layer, idx) after its slot was reset: true = asked, false = refused (ok, why)
  local function request(layer, idx, key, mesh, slot, opts)
    opts = opts or {}
    menu(F.RESET, layer, idx, slot)
    if type(SetDisableForceCharaInvalidUseTarget) == "function" then
      pcall(SetDisableForceCharaInvalidUseTarget)
    end
    local ok, r
    if opts.use_args or opts.kit ~= nil or opts.keeper ~= nil then
      ok, r = pcall(funcLuaMenuCommand, F.FACE, layer, idx, opts.face_only == true, mesh, slot, 0, 0, key,
        opts.kit or 0, opts.keeper == true, opts.use_args == true)
    else
      ok, r = pcall(funcLuaMenuCommand, F.FACE, layer, idx, opts.face_only == true, mesh, slot, 0, 0, key)
    end
    if type(SetEnableForceCharaInvalidUseTarget) == "function" then
      pcall(SetEnableForceCharaInvalidUseTarget)
    end
    if not ok or r == false then
      return false, ok and "refused" or tostring(r)
    end
    return true
  end

  function F.Request(layer, idx, who, mesh, slot, opts)
    local key = key_of(who)
    if key == nil then
      menu(F.RESET, layer, idx, slot)
      return false
    end
    return (request(layer, idx, key, mesh, slot, opts))
  end

  function F.Face(layer, idx, who, mesh, slot, opts)
    local k = layer .. ":" .. idx
    local key, why = key_of(who)
    if key == nil then
      menu(F.MESH_VISIBLE, layer, mesh, false, idx)
      F.waiting[k] = nil
      if why ~= "no character" then
        return fail(k, layer, idx, mesh, 0, why)
      end
      F.shown[k] = nil
      return false
    end
    local s = F.shown[k]
    if s ~= nil and s.key == key and s.mesh == mesh then
      if s.state == "failed" then
        return false
      end
      if s.state == "drawn" then
        return "drawn"
      end
    else
      local asked, why = request(layer, idx, key, mesh, slot, opts)
      if not asked then
        return fail(k, layer, idx, mesh, key, why)
      end
      F.shown[k] = { key = key, mesh = mesh, state = "loading" }
      F.waiting[k] = { layer = layer, idx = idx, mesh = mesh, key = key, left = F.WAIT }
    end
    if menu(F.LOADING, layer, idx) == true then
      menu(F.MESH_VISIBLE, layer, mesh, false, idx)
      return "loading"
    end
    F.shown[k].state = "drawn"
    F.waiting[k] = nil
    menu(F.MESH_VISIBLE, layer, mesh, true, idx)
    return "drawn"
  end

  function F.Card(layer, idx, who, x, y, size, opts)
    local C = F.CARD
    local s = size / C.RH
    menu(F.SCALE, layer, s, s, 1, idx)
    menu(F.POS, layer, x - C.OX * s, -y - C.OY * s, 0, idx)
    local k = layer .. ":" .. idx
    local mode = (opts and opts.portrait) and "portrait" or "face"
    if F.card_key[k] == nil then
      for _, m in ipairs(C.HIDE) do
        menu(F.MESH_VISIBLE, layer, m, false, idx)
      end
      for _, n in ipairs(C.HIDE_NODES) do
        menu(F.NODE_VISIBLE, layer, n, false, idx)
      end
      menu(F.TEXT_VISIBLE, layer, C.NAME, false, idx)
    end
    if F.card_key[k] ~= mode then
      for _, m in ipairs(C.FRAME) do
        menu(F.MESH_VISIBLE, layer, m, mode == "portrait", idx)
      end
      if F.card_key[k] ~= nil or mode == "portrait" then
        log("card", k, "now", mode)
      end
      F.card_key[k] = mode
    end
    return F.Face(layer, idx, who, C.MESH, C.SLOT, opts)
  end

  function F.Pending()
    return next(F.waiting) ~= nil
  end

  function F.Settle()
    for k, w in pairs(F.waiting) do
      if menu(F.LOADING, w.layer, w.idx) ~= true then
        F.waiting[k] = nil
        local s = F.shown[k]
        if s ~= nil then
          s.state = "drawn"
        end
        menu(F.MESH_VISIBLE, w.layer, w.mesh, true, w.idx)
      else
        w.left = w.left - 1
        if w.left <= 0 then
          fail(k, w.layer, w.idx, w.mesh, w.key, "still loading after " .. F.WAIT .. " checks")
        end
      end
    end
  end

  function F.Forget(layer, idx)
    if idx ~= nil then
      local k = layer .. ":" .. idx
      F.shown[k], F.waiting[k], F.card_key[k] = nil, nil, nil
      return
    end
    local pre = layer .. ":"
    for _, t in ipairs({ F.shown, F.waiting, F.card_key }) do
      for k in pairs(t) do
        if k:sub(1, #pre) == pre then
          t[k] = nil
        end
      end
    end
  end
end
