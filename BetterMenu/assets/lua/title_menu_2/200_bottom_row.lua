-- BetterMenu (mod better_menu, prefix BetterMenu): the main menu's DLC row (title_menu_2; docs/game/mods/better-menu.md
-- §10). With content\menus\title_bottom_row.toml on, the small DLC icon layer (title02_23_dlc_logo_simple) has one
-- more instance per big DLC banner (title02_22_dlc_logo) and those banners are hidden: each banner is one more small
-- icon in the same row (its icon sprite better_menu_dlc_icon_<n>, on the locator row of the same name), and hovering
-- it shows the banner itself in the title's DLC balloon, as the game's own four icons do. The title's own tables are
-- extended once per menu (its locals through VRFW_Host): icon <n> = banner <n> of the title's banner table (t17), its
-- big picture for the balloon (t20), no balloon tail (t19). The extra instances come from the menu declaration: with
-- it off the layer keeps the game's count and nothing here acts. With it on, the lower tiles also lose their white
-- halo (the tile layout's _btn_shadow01 quad, hidden per lower instance; the upper row keeps it): the declaration draws a
-- white plate behind the row instead. No engine call at load time.
BetterMenu = type(BetterMenu) == "table" and BetterMenu or {}
if BetterMenu.BottomRow == nil then
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

  local Row = {
    ID = "better_menu.bottom_row",
    LOG = Crc("CMND_EVT_LOG"),
    VISIBLE = Crc("CMND_SET_LAYER_VISIBLE"),
    CREATE_LAYER_NUM = Crc("CMND_GET_CREATE_LAYER_NUM"),   -- the number of instances of a layer
    ICON_LAYER = Crc("title02_23_dlc_logo_simple"),
    BANNER_LAYER = Crc("title02_22_dlc_logo"),
    ICON_NAME = "better_menu_dlc_icon_",                   -- sprite and locator row name of icon <n> (+ n)
    NO_TAIL = Crc("better_menu_no_tail"),                  -- a balloon tail mesh that does not exist: all tails off
    REHIDE_FRAMES = 30,
    LOWER_LAYER = Crc("title00_07_item_button_lower"),
    TILE_HALO = Crc("_btn_shadow01"),                      -- the tile's white halo / drop shadow quad
    MESH_VISIBLE = Crc("CMND_SET_MESH_VISIBLE"),           -- (layer, mesh, on, index)
  }
  -- per menu: extended = the title's tables hold the extra icons; added = their number
  local state = { extended = false, added = 0, checked = false, frames = 0 }

  local function Log(...)
    pcall(funcLuaCommand, Row.LOG, "better_menu", "title_menu_2", ...)
  end

  local function Locals()
    local host = type(VRFW_Host) == "table" and VRFW_Host.hosts and VRFW_Host.hosts.title_menu_2
    local L = host and host.L
    if L == nil then
      return nil
    end
    local ok, banners, icons, tails, pictures = pcall(function() return L.t17, L.t18, L.t19, L.t20 end)
    if not ok or type(banners) ~= "table" or type(icons) ~= "table" or type(tails) ~= "table" or type(pictures) ~= "table" then
      return nil
    end
    return banners, icons, tails, pictures
  end

  -- the extra icon instances the menu declaration gave the icon layer (0 = declaration off or no locals)
  local function Extend()
    if state.checked then
      return
    end
    local ok, count = pcall(funcLuaMenuCommand, Row.CREATE_LAYER_NUM, Row.ICON_LAYER)
    if not ok or type(count) ~= "number" or count <= 0 then
      return
    end
    state.checked = true
    local banners, icons, tails, pictures = Locals()
    if banners == nil then
      Log("bottom row: the title's tables are not reachable (no EVT_DEBUG): any extra DLC icon stays empty")
      return
    end
    -- the icons this file added before (the script's tables outlive a menu when its VM is kept) are not the game's
    local ours = {}
    for n = 1, #banners do
      ours[Crc(Row.ICON_NAME .. n)] = n
    end
    local game_icons = 0
    for _, row in ipairs(icons) do
      if ours[row.textureName] == nil then
        game_icons = game_icons + 1
      end
    end
    local extra = math.min(count - game_icons, #banners)
    if extra <= 0 then
      return
    end
    for n = #icons - game_icons + 1, extra do
      local name = Crc(Row.ICON_NAME .. n)
      table.insert(icons, { textureName = name, locatorName = name })
      table.insert(pictures, { textureName = banners[n].textureName, texturePath = banners[n].texturePath })
      table.insert(tails, Row.NO_TAIL)
    end
    state.extended, state.added = true, extra
    Log("bottom row:", extra, "DLC banner(s) as small icons (", count, "icons ), the big banners hidden")
  end

  local function HideTileHalos()
    local ok, count = pcall(funcLuaMenuCommand, Row.CREATE_LAYER_NUM, Row.LOWER_LAYER)
    if not ok or type(count) ~= "number" then
      return
    end
    for n = 0, count - 1 do
      pcall(funcLuaMenuCommand, Row.MESH_VISIBLE, Row.LOWER_LAYER, Row.TILE_HALO, false, n)
    end
  end

  local function HideBanners()
    for n = 0, state.added - 1 do
      pcall(funcLuaMenuCommand, Row.VISIBLE, Row.BANNER_LAYER, n, false)
    end
  end

  BetterMenu.BottomRow = Row

  if VRFW_Host ~= nil then
    VRFW_Host.on("title_menu_2", "OnInit", {
      id = Row.ID .. ".init",
      phase = "before",
      fn = function()
        state.extended, state.added, state.checked, state.frames = false, 0, false, 0
      end,
    })
    VRFW_Host.on("title_menu_2", "OnOpenLayer", {
      id = Row.ID .. ".open_before",
      phase = "before",
      fn = function(a1, a2)
        if a1 == Row.ICON_LAYER or a1 == Row.BANNER_LAYER or a1 == Row.LOWER_LAYER then
          Extend()
        end
      end,
    })
    VRFW_Host.on("title_menu_2", "OnOpenLayer", {
      id = Row.ID .. ".open_after",
      phase = "after",
      fn = function(r, a1, a2)
        if state.extended and a1 == Row.BANNER_LAYER then
          pcall(funcLuaMenuCommand, Row.VISIBLE, a1, a2 or 0, false)
        elseif state.extended and a1 == Row.LOWER_LAYER then
          pcall(funcLuaMenuCommand, Row.MESH_VISIBLE, a1, Row.TILE_HALO, false, a2 or 0)
        end
      end,
    })
    -- an extra icon focused while the tables could not be extended: the title's balloon code has no row for it; a
    -- lower tile focused: its halo off again (the focus animations may show it)
    VRFW_Host.on("title_menu_2", "OnChangeFocus", {
      id = Row.ID .. ".focus",
      phase = "around",
      fn = function(nxt, a1, ...)
        if a1 ~= Row.ICON_LAYER or state.extended then
          local r = table.pack(nxt(a1, ...))
          if state.extended and a1 == Row.LOWER_LAYER then
            HideTileHalos()
          end
          return table.unpack(r, 1, r.n)
        end
        local r = table.pack(pcall(nxt, a1, ...))
        if not r[1] then
          Log("bottom row: DLC icon focus without its balloon:", tostring(r[2]))
          return
        end
        return table.unpack(r, 2, r.n)
      end,
    })
    VRFW_Host.on("title_menu_2", "Step", {
      id = Row.ID .. ".step",
      phase = "after",
      fn = function()
        if not state.extended then
          return
        end
        state.frames = state.frames + 1
        if state.frames % Row.REHIDE_FRAMES == 0 then
          HideBanners()
          HideTileHalos()
        end
      end,
    })
  end
end
