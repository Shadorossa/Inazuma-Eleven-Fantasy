-- Utilities: the DOUBLE archetype in the player header (owner 2026-10-14: what Inazuma Fantasy showed, now Utilities'
-- own). The player's archetype follows his archetype passives (scripts\passive_config.lua, content\passive_config\
-- player_archetype.toml); a player whose two archetype slots hold passives of two DIFFERENT archetypes has a double
-- archetype: the header shows the first one where the game draws the archetype (_icon_build_dmy01, the game's own
-- getter, answered by Utilities) and the second one right next to it, on the header's _icon_lock_status01 quad (the
-- look Inazuma Fantasy had; Character Reforged's one-row header places that quad right of the archetype box, and its
-- player page widens the box for a double archetype, VRFW_UI.HeaderRow.ArchBox with CMND_BETTERQOL_PC_INFO).
--
-- * How: a piece of Character Reforged's header slot (host character_reforged.header, content\menus\
--   archetype_header.toml, gated if_mod = "character_reforged"). Character Reforged calls BetterQoL.ArchetypeHeader.
--   Piece("fill", ctx) on every refresh of a header plate (every screen with the player header, after the game's own
--   fill); the piece draws on the header's own quad and takes no room in the slot's strip (answers 0).
-- * Without Character Reforged nothing here runs (no host, the entry file is skipped): the archetype still changes,
--   the header shows only the game's one icon (Utilities' team dock / plate grafts keep their own second icon).
-- * Archetypes 0-5 are the game's, 7+ the mods' declared ones (their small icon through the VR-Framework's
--   GeTeamBuffBuildTypeIconTextureName); 6 = none.
-- Defines functions and tables; no engine call at chunk load.
Utilities = type(Utilities) == "table" and Utilities or {}
BetterQoL.ArchetypeHeader = type(BetterQoL.ArchetypeHeader) == "table" and BetterQoL.ArchetypeHeader or {}
do
  local AH = BetterQoL.ArchetypeHeader
  AH.INFO = 3569354349 --[[CMND_BETTERQOL_PC_INFO (hdl) -> ok, mode, archetype 1, archetype 2, max slots, inactive]]
  AH.ICON_TEXTURE = 2320109963 --[[#/menu/200_icon/15_icon_common/icon_common.g4tx]]
  AH.SECOND_MESH = 1670039012 --[[_icon_lock_status01]]
  AH.SECOND_SLOT = 3276571178 --[[icon_lock_status01 (the quad's texture slot)]]
  AH.SWAP_SPRITE = 558735651 --[[the menu sprite swap (layer, texture, sprite, texture slot, 0, inst)]]
  AH.MESH_VISIBLE = 3405944500 --[[CMND_SET_MESH_VISIBLE (layer, mesh, on, inst)]]
  AH.NO_ARCHETYPE = 6
  AH.MAX_ARCHETYPE = 63

  local function is_archetype(n)
    return type(n) == "number" and n >= 0 and n <= AH.MAX_ARCHETYPE and n ~= AH.NO_ARCHETYPE
  end

  -- (first, second) of a double archetype, or nil
  function AH.Double(hdl)
    if type(hdl) ~= "number" or hdl == 0 then
      return nil
    end
    local ok, got, _, a, b = pcall(funcLuaCommand, AH.INFO, hdl)
    if not ok or got ~= true or not is_archetype(a) or not is_archetype(b) or a == b then
      return nil
    end
    return a, b
  end

  -- the second archetype's icon on the header plate (layer, inst) of the player hdl; true = drawn
  function AH.DrawSecond(layer, inst, hdl)
    local shown = rawget(_ENV, "GetBuildTypeIconTextureNameByCharaStHdl")
    if type(shown) == "function" then
      local ok, tex = pcall(shown, hdl)
      if ok and tex == 0 then
        return false -- the header shows no archetype at all (a coach, a manager...)
      end
    end
    local _, b = AH.Double(hdl)
    local icon_of = rawget(_ENV, "GeTeamBuffBuildTypeIconTextureName")
    if b == nil or type(icon_of) ~= "function" then
      return false
    end
    local ok, sprite = pcall(icon_of, b)
    if not ok or type(sprite) ~= "number" or sprite == 0 then
      return false
    end
    pcall(funcLuaMenuCommand, AH.SWAP_SPRITE, layer, AH.ICON_TEXTURE, sprite, AH.SECOND_SLOT, 0, inst or 0)
    pcall(funcLuaMenuCommand, AH.MESH_VISIBLE, layer, AH.SECOND_MESH, true, inst or 0)
    return true
  end

  -- the piece of Character Reforged's header slot: f(phase, ctx) -> the width it takes in the strip (always 0: it
  -- draws on the header's own quad next to the archetype icon)
  function AH.Piece(phase, ctx)
    if phase == "fill" and type(ctx) == "table" then
      AH.DrawSecond(ctx.layer, ctx.inst, ctx.hdl)
    end
    return 0
  end
end
