-- Character Reforged › the «Fantasy» skill table's role medal slot and its button row (graft skill_table_role_slot).
-- HOOK file of evt_skill_slot_menu (shipped as is: command ids written as numbers, their names in the comments): it
-- wraps the screen's globals and calls them; no retail or Character Reforged function is replaced.
--   * The bottom row is [ player sets ][ Entrenar ]: the custom passive button (evt_cmn03_07_btn_ss) and the role
--     button (evt_cmn03_07_btn_role) stay hidden with their icons (instances of the passive row layer) and out of the
--     focus chain (content\menus\skill_table.toml).
--   * The coach / manager medal is the skill board's own slot (layer team13_05c_effect_grid_director_manager_slot of
--     ability_learning_board_menu) shown above the player card: drawn as the board draws it (empty plate, gold coach
--     or silver manager medal) at 62 % size, fully above the player card; focused with Up from the first move row or
--     by the mouse pointer (object evt_role_medal_slot: the retail object + a click zone on _touch_sp01), Aceptar or a
--     click opens the role picker of the screen (PL.RoleCoroutine: «Sin rol» / Entrenador / Gerente), which sets it with
--     CMND_CHARACTERREFORGED_SET_ROLE.
-- The shown player = the chunk's local `n`, read through the skill table's extension point
-- (CharacterReforged.SkillTable.L, graft skill_table_host). Definitions and wraps only at chunk load (no engine call);
-- the screen's active / input state is never touched here (the role picker keeps its own).
do
  CharacterReforged_RoleSlot = CharacterReforged_RoleSlot or {}
  local Slot = CharacterReforged_RoleSlot
  Slot.LAYER = 3924714337                           -- team13_05c_effect_grid_director_manager_slot
  Slot.CARD = 1774956026                            -- team00_01_chara_card (the shown player's card)
  Slot.BUTTON_SS = 605517988                        -- evt_cmn03_07_btn_ss (custom passive button, hidden)
  Slot.BUTTON_ROLE = 2356951558                     -- evt_cmn03_07_btn_role (role button, hidden)
  Slot.BUTTON_PASSIVES = 3196164535                 -- evt_cmn03_07_btn_icon (removed branch passives button, hidden)
  Slot.GET_ROLE = 1327558109                        -- CMND_CHARACTERREFORGED_GET_ROLE (charaStHdl) -> role, badge, plays, native, lock
  Slot.LAYER_VISIBLE = 711242136                    -- CMND_SET_LAYER_VISIBLE (layer, idx, visible)
  Slot.LAYER_POS = 4002164178                       -- (layer) -> x, y of the layer
  Slot.LOCAL_POS = 1389957207                       -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z, idx)
  Slot.PRIORITY = 1491630496                        -- CMND_SET_DRAW_PRIORITY (layer, idx, priority, children)
  Slot.SPRITE = 558735651                           -- sprite swap (layer, texture, sprite, target, 0, idx)
  Slot.MESH_VISIBLE = 3405944500                    -- CMND_SET_MESH_VISIBLE (layer, mesh, visible, idx)
  Slot.LOCATOR_VISIBLE = 2158717427                 -- (layer, locator, visible, idx)
  Slot.TEXT_VISIBLE = 1505208242                    -- CMND_SET_MENU_TEXT_VISIBLE (layer, node, visible, idx)
  Slot.TEX_PLATE = 1461205148                       -- #/menu/102_team/team13/team13_05c/team13_05c.g4tx
  Slot.TEX_ITEM = 2868599811                        -- #/menu/200_icon/02_icon_item/icon_item01.g4tx
  Slot.PLATE_TARGET = 1212007845                    -- set_icon_badge01_off (the plate quad)
  Slot.PLATE = {[0] = 4264092250, [1] = 2386695893, [2] = 2633480507}   -- set_icon_badge01_ok / 01_on / 02_on
  Slot.MEDAL_TARGET = 2187179074                    -- icon_badge_dmy01
  Slot.MEDAL_MESH = 731693558                       -- _icon_badge_dmy01
  Slot.MEDAL = {[1] = 2607368153, [2] = 3966662479} -- abl_000002 coach / abl_000003 manager
  Slot.DRAW_PRIORITY = 660                          -- over the player card (652)
  Slot.LOCAL_SCALE = 3778714801                     -- CMND_SET_LAYER_LOCAL_SCALE (layer, x, y, z, idx)
  Slot.MESH_POS = 499270986                         -- CMND_GET_MESH_GLOBAL_POSITION (layer, idx, node) -> x, y, z
  -- the medal at 62 % of the board's size (plate 136 layout units -> 84), fully above the player card with a gap: its
  -- centre = the card's x, the card frame's top + GAP + half the scaled plate (top-left nodes _icon_chr_focus_l01 /
  -- _s01 of the card; the higher one counts). The fixed offsets are used when the card's frame is unknown.
  Slot.SCALE = 0.62
  Slot.PLATE_HALF = 68                              -- _set_icon_badge01: 136 x 136 centred on the layer root
  Slot.GAP = 12
  Slot.CARD_FRAME_NODES = {3345942320 --[[_icon_chr_focus_l01]], 3491095421 --[[_icon_chr_focus_s01]]}
  Slot.ABOVE_CARD_DX, Slot.ABOVE_CARD_DY = 0, 66 + 12 + 42
  Slot.FALLBACK_X, Slot.FALLBACK_Y = 326, -96
  Slot.shown_chara = nil
  Slot.placed_at = nil

  function Slot.Table()
    local api = type(CharacterReforged) == "table" and CharacterReforged.SkillTable or nil
    return type(api) == "table" and api.L or nil
  end

  function Slot.Role(hdl)
    if type(hdl) ~= "number" or hdl == 0 then
      return 0
    end
    local ok, role = pcall(funcLuaCommand, Slot.GET_ROLE, hdl)
    if ok and (role == 1 or role == 2) then
      return role
    end
    return 0
  end

  -- the player card's position and the top of its frame: x, y, top (nil = unknown); (0, 0) = a missing node
  function Slot.CardFrame()
    local ok, x, y = pcall(funcLuaMenuCommand, Slot.LAYER_POS, Slot.CARD, 0)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then
      return nil
    end
    local top = nil
    for _, node in ipairs(Slot.CARD_FRAME_NODES) do
      local okn, nx, ny = pcall(funcLuaMenuCommand, Slot.MESH_POS, Slot.CARD, 0, node)
      if okn and type(nx) == "number" and type(ny) == "number" and (nx ~= 0 or ny ~= 0) and ny > y then
        top = (top == nil or ny > top) and ny or top
      end
    end
    return x, y, top
  end

  -- smaller and above the card, never over it; placed again only when the card moved
  function Slot.Place()
    local x, y, top = Slot.CardFrame()
    local px, py
    if x == nil then
      px, py = Slot.FALLBACK_X, Slot.FALLBACK_Y
    elseif top ~= nil then
      px, py = x, top + Slot.GAP + Slot.PLATE_HALF * Slot.SCALE
    else
      px, py = x + Slot.ABOVE_CARD_DX, y + Slot.ABOVE_CARD_DY
    end
    local key = string.format("%.1f,%.1f", px, py)
    if Slot.placed_at == key then
      return
    end
    funcLuaMenuCommand(Slot.LOCAL_SCALE, Slot.LAYER, Slot.SCALE, Slot.SCALE, 1, 0)
    funcLuaMenuCommand(Slot.LOCAL_POS, Slot.LAYER, px, py, 0, 0)
    Slot.placed_at = key
    pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "skill_table_role_slot", "medal placed", tostring(x),
      tostring(y), "frame top", tostring(top), "at", px, py, "scale", Slot.SCALE)
  end

  -- the slot as the board draws its coach / manager piece (UpdateEffectPieceIcon, director slot branch)
  function Slot.Draw()
    local L = Slot.Table()
    local hdl = L and L.n or nil
    local role = Slot.Role(hdl)
    local layer = Slot.LAYER
    Slot.shown_chara = hdl
    funcLuaMenuCommand(Slot.LOCATOR_VISIBLE, layer, 2861675684 --[[_pos_buff01]], false, 0)
    funcLuaMenuCommand(Slot.LOCATOR_VISIBLE, layer, 3453619769 --[[_pos_type01]], false, 0)
    funcLuaMenuCommand(Slot.TEXT_VISIBLE, layer, 389802871 --[[_text_wlv01]], false, 0)
    funcLuaMenuCommand(Slot.SPRITE, layer, Slot.TEX_PLATE, Slot.PLATE[role], Slot.PLATE_TARGET, 0, 0)
    local medal = Slot.MEDAL[role]
    funcLuaMenuCommand(Slot.SPRITE, layer, Slot.TEX_ITEM, medal or Slot.MEDAL_TARGET, Slot.MEDAL_TARGET, 0, 0)
    funcLuaMenuCommand(Slot.MESH_VISIBLE, layer, Slot.MEDAL_MESH, medal ~= nil, 0)
    funcLuaMenuCommand(Slot.LOCATOR_VISIBLE, layer, 2536941674 --[[_pos_orb_base01]], true, 0)
    funcLuaMenuCommand(Slot.LOCATOR_VISIBLE, layer, 239073744 --[[_pos_orb_base02]], false, 0)
  end

  -- the removed buttons and their icons: hidden whatever showed them again (list covers, icon refreshes)
  function Slot.HideRemoved()
    local L = Slot.Table()
    for _, layer in ipairs({Slot.BUTTON_SS, Slot.BUTTON_ROLE, Slot.BUTTON_PASSIVES}) do
      funcLuaMenuCommand(Slot.LAYER_VISIBLE, layer, 0, false)
    end
    if L ~= nil and L.L_PV_ROW ~= nil then
      local PL = L.PL
      for _, k in ipairs({L.EVT_ROW_ICON_SS, PL and PL.ROW_ICON_ROLE or nil}) do
        if type(k) == "number" then
          funcLuaMenuCommand(Slot.LAYER_VISIBLE, L.L_PV_ROW, k, false)
        end
      end
    end
  end

  function Slot.Show(visible)
    funcLuaMenuCommand(Slot.LAYER_VISIBLE, Slot.LAYER, 0, visible)
  end

  -- ---- the wraps (once per VM; each calls what it wrapped) -----------------------------------------------------
  function Slot.WrapGlobal(name, make)
    Slot.wrappers = Slot.wrappers or {}
    local current = _ENV[name]
    if current == nil or Slot.wrappers[name] == current then
      return
    end
    local wrapper = make(current)
    Slot.wrappers[name] = wrapper
    _ENV[name] = wrapper
  end

  Slot.WrapGlobal("OnSetupLayer", function(previous)
    return function(a1, a2, ...)
      local result = table.pack(previous(a1, a2, ...))
      if a1 == Slot.LAYER then
        funcLuaMenuCommand(Slot.PRIORITY, a1, a2, Slot.DRAW_PRIORITY, true)
        Slot.placed_at = nil
        pcall(Slot.Place)
        pcall(Slot.Draw)
      elseif a1 == Slot.BUTTON_SS or a1 == Slot.BUTTON_ROLE or a1 == Slot.BUTTON_PASSIVES then
        funcLuaMenuCommand(Slot.LAYER_VISIBLE, a1, a2, false)
      end
      return table.unpack(result, 1, result.n)
    end
  end)

  Slot.WrapGlobal("OnOpenLayer", function(previous)
    return function(a1, a2, ...)
      local result = table.pack(previous(a1, a2, ...))
      if a1 == Slot.LAYER then
        Slot.placed_at = nil
        pcall(Slot.Place)
        pcall(Slot.Draw)
      elseif a1 == Slot.BUTTON_SS or a1 == Slot.BUTTON_ROLE or a1 == Slot.BUTTON_PASSIVES then
        funcLuaMenuCommand(Slot.LAYER_VISIBLE, a1, a2, false)
      end
      return table.unpack(result, 1, result.n)
    end
  end)

  -- the slot has the focus: the screen treats it like a bottom button (no row info), the guide line names the role
  Slot.WrapGlobal("OnChangeFocus", function(previous)
    return function(a1, a2, ...)
      local L = Slot.Table()
      if a1 == Slot.LAYER and L ~= nil then
        L.evt_focus_layer = a1
        L.n14 = L.L_BTN
        pcall(UpdateEquipItemInfo)
        if L.PL ~= nil and L.PL.RoleGuide ~= nil then
          pcall(L.PL.RoleGuide)
        end
        return
      end
      return previous(a1, a2, ...)
    end
  end)

  -- Aceptar on the slot: the screen's role picker
  Slot.WrapGlobal("OnDecideFocus", function(previous)
    return function(a1, a2, ...)
      local L = Slot.Table()
      if a1 == Slot.LAYER and L ~= nil then
        local PL = L.PL
        if L.evt_co == nil and PL ~= nil and PL.RoleCoroutine ~= nil then
          L.evt_co = coroutine.create(function()
            PL.RoleCoroutine()
          end)
        end
        return
      end
      return previous(a1, a2, ...)
    end
  end)

  -- every frame: the removed buttons stay hidden; the slot follows the card; another player shown -> it is redrawn
  Slot.WrapGlobal("Step", function(previous)
    return function(...)
      local result = table.pack(previous(...))
      pcall(Slot.HideRemoved)
      pcall(Slot.Place)
      local L = Slot.Table()
      if L ~= nil and L.n ~= Slot.shown_chara and L.evt_co == nil then
        pcall(Slot.Draw)
      end
      return table.unpack(result, 1, result.n)
    end
  end)

  -- the role picker refreshes the role icon when it closes: the slot is redrawn with it; a list cover hides the slot
  -- with the player card
  do
    local L = Slot.Table()
    local PL = L and L.PL or nil
    if PL ~= nil and PL.RoleIcon ~= nil and Slot.wrapped_role_icon ~= PL.RoleIcon then
      local previous = PL.RoleIcon
      PL.RoleIcon = function(...)
        local result = table.pack(previous(...))
        pcall(Slot.Draw)
        return table.unpack(result, 1, result.n)
      end
      Slot.wrapped_role_icon = PL.RoleIcon
    end
    if PL ~= nil and PL.ListCover ~= nil and Slot.wrapped_list_cover ~= PL.ListCover then
      local previous = PL.ListCover
      PL.ListCover = function(show, ...)
        local result = table.pack(previous(show, ...))
        pcall(Slot.Show, not show)
        return table.unpack(result, 1, result.n)
      end
      Slot.wrapped_list_cover = PL.ListCover
    end
  end
end
