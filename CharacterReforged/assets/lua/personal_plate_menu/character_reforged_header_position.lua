-- Character Reforged: the player page's header (personal_plate_menu: the «Ficha» of the team dock and the data file)
-- shows the player's OWN position on its position badge, not the position of the formation slot he stands in. The
-- retail header fill draws the slot's badge; right after each fill of a header plate the badge is set again to the
-- player's own position (VRFW_UI.HeaderRow.Natural: the card's main position). Coaches / managers and unknown
-- characters keep the retail badge. Only this script: the other screens with the header keep the slot's position.
-- Wraps UpdateCharaStatusPlateInfoByCharaStHdl; no engine call at load time.
CharacterReforged = type(CharacterReforged) == "table" and CharacterReforged or {}
if CharacterReforged.HeaderPosition == nil and type(rawget(_ENV, "UpdateCharaStatusPlateInfoByCharaStHdl")) == "function" then
  local P = {
    -- soccer11_04_formation_chara_status, soccer11_04_chara_status (the header plates)
    LAYERS = {[1844915256] = true, [607716004] = true},
  }
  CharacterReforged.HeaderPosition = P

  -- the badge of the header plate (layer, inst) filled with the status handle hdl: the player's own position
  function P.AfterFill(layer, inst, hdl)
    if not P.LAYERS[layer] then
      return
    end
    local rows = type(VRFW_UI) == "table" and VRFW_UI.HeaderRow or nil
    if rows == nil then
      return
    end
    local staff, icon = rows.Natural(hdl)
    if staff == false and icon ~= nil then
      rows.Badge(layer, inst or 0, icon)
    end
  end

  P.previousFill = UpdateCharaStatusPlateInfoByCharaStHdl
  function UpdateCharaStatusPlateInfoByCharaStHdl(layer, inst, hdl, ...)
    local result = table.pack(P.previousFill(layer, inst, hdl, ...))
    pcall(P.AfterFill, layer, inst, hdl)
    return table.unpack(result, 1, result.n)
  end
end
