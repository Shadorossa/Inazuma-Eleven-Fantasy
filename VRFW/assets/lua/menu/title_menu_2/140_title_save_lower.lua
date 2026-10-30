-- title_save_lower (VR-Framework): the retail «Guardar» button on the title's LOWER row, right before «Mods».
-- The retail button leaves the upper row (menus\title_row.toml, [[hide]] of title item `save`); the mods_menu plugin
-- serves the title files with one more lower button for it (CMND_VRFW_MM_STATE, values 10..13: lower position, label
-- name instance, the upper button above it, the upper buttons whose «down» goes to it). Art, label, players mark and
-- press are the retail ones, read from the retail position of the button through VRFW_TitleRow.retail.
-- Handlers of the framework's title_menu_2 host (VRFW_Host), each one passes on (nxt) for anything that is not its
-- button. No engine call at load time: everything below runs from the game's callbacks.

local function SV_Crc(s)
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

local SV = {
  STATE = SV_Crc("CMND_VRFW_MM_STATE"),
  T = "title_menu_2",
  ID = "title_save.lower",
  UPPER = 2250456639,       -- title00_07_item_button_upper
  L_LOWER = 3873872512,     -- title00_07_item_button_lower
  SAVE = SV_Crc("save"),    -- the retail «Guardar» title item
  IDX = 41,                 -- its item list index on the lower row (the game uses 1..11, «Mods» 40)
  LOG = VRFW_Cmd.EVT_LOG,         -- CMND_EVT_LOG
}

local sv = {
  state = nil,              -- nil = not asked yet; false = no button; table = {pos, name, above, down}
  retail_pos = nil,         -- the button's position in the retail upper row
}

local function SV_Call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

local function SV_State()
  if sv.state == nil then
    sv.state = false
    local title, screen, _, _, _, _, _, _, _, pos, name, above, down = SV_Call(SV.STATE)
    if title == 1 and screen == true and type(pos) == "number" and pos >= 0 and type(name) == "number" and name > 0 then
      local set = {}
      if type(down) == "string" then
        for d in string.gmatch(down, "%d+") do
          set[tonumber(d)] = true
        end
      end
      sv.state = {pos = pos, name = name, above = type(above) == "number" and above or 0, down = set}
    end
  end
  return sv.state or nil
end

-- the lower button exists (the row was served with it and the layer has its instance)
local function SV_Own()
  local s = SV_State()
  return s ~= nil and type(GetItemButtonNum) == "function" and GetItemButtonNum(false) > s.pos
end

local function SV_IsOurs(idx, upper)
  local s = SV_State()
  return s ~= nil and upper ~= true and idx == s.pos and SV_Own()
end

-- runs fn on the title's own tables (the title row's handlers pass on meanwhile)
local function SV_Retail(fn, ...)
  if type(VRFW_TitleRow) == "table" and type(VRFW_TitleRow.retail) == "function" then
    return VRFW_TitleRow.retail(fn, ...)
  end
  return fn(...)
end

-- the position of the button in the retail upper row (nil = not found)
local function SV_RetailPos()
  if sv.retail_pos == nil then
    sv.retail_pos = false
    SV_Retail(function()
      for i = 0, 15 do
        local ok, id = pcall(GetTitleMenuItemId, i, true)
        if not ok or type(id) ~= "number" then
          break
        end
        if id == SV.SAVE then
          sv.retail_pos = i
          break
        end
      end
    end)
    if sv.retail_pos == false then
      pcall(funcLuaCommand, SV.LOG, "title_save", "WARN the retail Guardar button was not found in the title's upper row")
    end
  end
  return sv.retail_pos or nil
end

-- the retail answer of accessor `name` for the button (nil when it cannot be read)
local function SV_Ask(name, ...)
  local pos = SV_RetailPos()
  local f = _ENV[name]
  if pos == nil or type(f) ~= "function" then
    return nil
  end
  local args = table.pack(...)
  for i = 1, args.n do
    if args[i] == "@pos" then
      args[i] = pos
    end
  end
  local ok, r = pcall(SV_Retail, f, table.unpack(args, 1, args.n))
  if ok then
    return r
  end
  return nil
end

local function on(point, fn)
  if type(_ENV[point]) == "function" then
    VRFW_Host.on(SV.T, point, { id = SV.ID, phase = "around", fn = fn })
  end
end

if VRFW_Host ~= nil and type(GetItemListIdx) == "function" and type(OnEnter) == "function" then
  on("OnInit", function(nxt, ...)
    sv.state, sv.retail_pos = nil, nil
    return nxt(...)
  end)

  on("GetItemListIdx", function(nxt, a1, a2)
    if SV_IsOurs(a1, a2) then
      return SV.IDX
    end
    return nxt(a1, a2)
  end)

  on("IsEnableMenuItemButton", function(nxt, a1, a2)
    if SV_IsOurs(a1, a2) then
      return true
    end
    return nxt(a1, a2)
  end)

  on("GetTextureNameItemButton", function(nxt, a1, a2, a3)
    if SV_IsOurs(a1, a3) then
      return SV_Ask("GetTextureNameItemButton", "@pos", a2, true) or 0
    end
    return nxt(a1, a2, a3)
  end)

  -- a1 = name instance (upper 0..n-1, then the lower ones), a2 = upper
  on("GetTextItemName", function(nxt, a1, a2)
    local s = SV_State()
    if s ~= nil and a2 ~= true and a1 == s.name and SV_Own() then
      return SV_Ask("GetTextItemName", "@pos", true) or "Guardar"
    end
    return nxt(a1, a2)
  end)

  on("GetTextNameItemName", function(nxt, a1, a2)
    if SV_IsOurs(a1, a2) then
      return 0
    end
    return nxt(a1, a2)
  end)

  on("GetPlayableModeGaiji", function(nxt, a1, a2)
    if SV_IsOurs(a1, a2) then
      return SV_Ask("GetPlayableModeGaiji", "@pos", true) or 0
    end
    return nxt(a1, a2)
  end)

  on("GetTitleMenuItemId", function(nxt, a1, a2)
    if SV_IsOurs(a1, a2) then
      return SV.SAVE
    end
    return nxt(a1, a2)
  end)

  -- no slide animation for this button (the lower row's new locators have none)
  on("GetOffsetAnimeItemAttachLocator", function(nxt, a1, a2)
    if SV_IsOurs(a1, a2) then
      return 0
    end
    return nxt(a1, a2)
  end)

  on("GetLayerNameFromItemListIdx", function(nxt, a1)
    if a1 == SV.IDX and SV_Own() then
      return SV.L_LOWER
    end
    return nxt(a1)
  end)

  on("GetLayerIndexFromItemListIdx", function(nxt, a1)
    if a1 == SV.IDX and SV_Own() then
      return SV_State().pos
    end
    return nxt(a1)
  end)

  -- up from the button -> the upper button above it; down from the uppers between it and «Mods» -> the button
  on("GetItemButtonNextFocusIdx", function(nxt, a1, a2)
    local s = SV_State()
    if s ~= nil and SV_Own() then
      if a2 == true and a1 == s.pos then
        local nu = GetItemButtonNum(true)
        return math.max(0, math.min(s.above, nu - 1))
      elseif a2 ~= true and s.down[a1] then
        return s.pos
      end
    end
    return nxt(a1, a2)
  end)

  -- the retail balloon of the button, read at its retail position
  on("SetFlavorBalloonText", function(nxt, ...)
    local s = SV_State()
    if s ~= nil and SV_Own() and type(GetSelectItemLayerName) == "function" and GetSelectItemLayerName() == SV.L_LOWER and GetSelectItemIdx() == s.pos then
      local pos = SV_RetailPos()
      if pos ~= nil and type(SetSelectItemLayerInfo) == "function" then
        SV_Retail(function(...)
          SetSelectItemLayerInfo(SV.UPPER, pos)
          local res = table.pack(pcall(nxt, ...))
          SetSelectItemLayerInfo(SV.L_LOWER, s.pos)
          if not res[1] then
            error(res[2], 0)
          end
        end, ...)
      end
      return
    end
    return nxt(...)
  end)

  -- the press: the retail press of the button at its retail position (it opens the save data screen by its own coroutine)
  on("OnEnter", function(nxt, a1, a2)
    if a1 == SV.L_LOWER and SV_IsOurs(a2, false) then
      local pos = SV_RetailPos()
      if pos == nil then
        funcLuaCommand(VRFW_Cmd.SND_PLAY_SE, 2086672038)     -- sy0003: buzzer
        return 1
      end
      return SV_Retail(nxt, SV.UPPER, pos)
    end
    return nxt(a1, a2)
  end)
end
