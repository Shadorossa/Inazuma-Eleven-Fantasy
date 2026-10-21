-- BetterUI (mod clean_hud, prefix BetterUI), main menu (title_menu_2): the lower row without the «Información» tile
-- (content\menus\title_lower_row.toml removes its instance; the X key at the top left, retail OnFunction 695801987, still
-- opens the notices screen). Two handlers of the framework's title_menu_2 host, both event-driven:
--   * @edit (once per VM, first callback): the title's lower item list t4 = {6, 5, 8} (Guía, Opciones, Información, by
--     position) loses 8, but only when the framework served the row with its «Guardar» button on the freed place (state
--     CMND_VRFW_MM_STATE: lower position 2); a row served otherwise keeps the retail list, so the tile is never half removed.
--   * after OnOpenLayer of the new-notices «!» (cmn01_13_new_icon_middle instance 2, which the retail OnSetupLayer opens on
--     lower instance 2 = Información): hidden, it would sit on «Guardar» now.
-- No engine call at load time.
if VRFW_Host ~= nil then
  local function Crc(s)
    local crc = 0xFFFFFFFF
    for i = 1, #s do
      crc = bit32.bxor(crc, string.byte(s, i))
      for _ = 1, 8 do
        if bit32.band(crc, 1) ~= 0 then
          crc = bit32.bxor(bit32.rshift(crc, 1), 0xEDB88320)
        else
          crc = bit32.rshift(crc, 1)
        end
      end
    end
    return bit32.bxor(crc, 0xFFFFFFFF)
  end

  local Tile = {
    STATE = Crc("CMND_VRFW_MM_STATE"),
    LOG = 3661580131,                 -- CMND_EVT_LOG
    VISIBLE = 711242136,              -- CMND_SET_LAYER_VISIBLE
    NEW_ICON = 1538377437,            -- cmn01_13_new_icon_middle
    INFO_ITEM = 8,                    -- the retail list index of Información in t4
    INFO_INSTANCE = 2,                -- its lower instance, where the retail code opens the «!»
    SAVE_POSITION = 2,                -- the lower position the framework gives «Guardar» on a row of 2 + 2
    removed = false,
  }

  -- the framework served the lower row with «Guardar» on the instance Información had
  local function Served()
    local ok, title, screen, _, _, _, _, _, _, _, pos = pcall(funcLuaCommand, Tile.STATE)
    return ok and title == 1 and screen == true and pos == Tile.SAVE_POSITION
  end

  VRFW_Host.on("title_menu_2", "@edit", {
    id = "clean_hud.info_tile",
    fn = function(L)
      local t4 = L.t4
      if type(t4) ~= "table" or not Served() then
        pcall(funcLuaCommand, Tile.LOG, "clean_hud info_tile", "lower row kept as served (no Guardar on the freed place or no EVT_DEBUG)")
        return
      end
      for i = #t4, 1, -1 do
        if t4[i] == Tile.INFO_ITEM then
          table.remove(t4, i)
          Tile.removed = true
        end
      end
      pcall(funcLuaCommand, Tile.LOG, "clean_hud info_tile", "Información out of the lower row,", #t4, "retail tiles left")
    end,
  })

  VRFW_Host.on("title_menu_2", "OnOpenLayer", {
    id = "clean_hud.info_tile.new_icon",
    phase = "after",
    fn = function(r, a1, a2)
      if Tile.removed and a1 == Tile.NEW_ICON and a2 == Tile.INFO_INSTANCE then
        pcall(funcLuaMenuCommand, Tile.VISIBLE, a1, a2, false)
      end
    end,
  })
end
