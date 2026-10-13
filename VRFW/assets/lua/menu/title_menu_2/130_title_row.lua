-- title_row (VR-Framework, menu engine): the title's mode row (the upper buttons of title_menu_2) holds the buttons the
-- mods DECLARE, at the place their `order` gives them among the game's own buttons. docs/framework/title-row.md;
-- handlers of the framework's title_menu_2 host (VRFW_Host, docs/framework/lua-hosts.md). No engine call at load time.
--
-- A mod declares a button in its menus\*.toml (menu type, host "title_menu_2.upper"):
--   [[entry]] host = "title_menu_2.upper"  id  text (label key)  icon ("<atlas>:<sprite>")  order / after  action
--   [entry.title] plate = [on, off]  flavor (balloon key)  players  item  locked  locked_text  gate
-- and takes a game button out with [[hide]] target = "title_menu_2.upper/<title item>" (`vs_mode`, a number...). The
-- framework served the title files with as many upper instances as the row has (mods_screen: the game's buttons the
-- mods keep + the declared ones); here every retail accessor of the row is answered for the declared buttons and
-- re-pointed for the game's own (they keep their art, label, balloon and request from the title's own tables, whatever
-- the mods made of them). Nothing here names a mod, a mode or a list index: the game's buttons are ordered by their
-- place in the retail row (100 x place: Historia 100 ... Guardar 800), the declared ones by their `order`.
--
-- Press (A, or another title code pressing a title item id through OnEnter, e.g. a top-bar hand-off):
--   locked   (`locked` Lua says so, or the `mode` is off / locked) -> retail buzzer + `locked_text` window; nothing else
--   gate     `gate` Lua returns true to go on (false: it gave its own feedback)
--   open_menu  the menu opens as a child of the title, the title waits and takes input back when it closes
--   lua        the global function runs (key, position); its return value is OnEnter's
--   command    funcLuaCommand(crc32(name), key)
--   title      the button presses that retail title item (its request; e.g. "option" = the save load of Opciones);
--              the title focuses the button again when it comes back
--   mode       VRFW_Mode.start(mode key, "title_row", position)
-- Public: VRFW_TitleRow.stays(id) = a declared button that runs inside the title; .item(key) = its title item id;
-- .position(key) = its place in the row.

local function TR_Crc(s)
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

local TR = {
  HOST = "title_menu_2.upper",
  UPPER = 2250456639,       -- title00_07_item_button_upper
  NAME = 3180406576,        -- title02_03_item_name_2 (the labels: upper instances first, then the lower ones)
  MENU = 3874253475,        -- title_menu_2
  CURSOR = 24113234,        -- cmn05_01_coursor
  COUNT = 1063911870,       -- CMND_VRFW_MENU_ENTRY_COUNT (host)
  ENTRY = 2768609349,       -- CMND_VRFW_MENU_ENTRY (host, i)
  HIDDEN = TR_Crc("CMND_VRFW_MENU_HIDDEN_LIST"),
  TEXT_KEY = 459261927,     -- CMND_VRFW_TEXT_GET (key)
  TEXT_ID = 4074371074,     -- CMND_TEXT_GET (id)
  SET_TEXT = 1083631230,    -- CMND_SET_MENU_TEXT_STRING (layer, node, text, index)
  EXPLAIN = 499981750,      -- _text_explain01 of the flavour balloon
  LOG = 3661580131,         -- CMND_EVT_LOG
  SOUND = 1917805374,
  BUZZER = 2086672038,      -- sy0003
  DECIDE = 766561556,       -- sy0080
  OPEN_MENU = 433545986,    -- CMND_OPEN_MENU_OBJECT
  IS_MENU = 2231168902,     -- CMND_IS_EXIST_MENU_OBJECT (funcLuaMenuCommand)
  CHILD = 2039986631,       -- the title's own switch while a child menu runs (as the retail Guardar flow)
  INPUT = 1558704558,       -- menu input on / off
  VISIBLE = 711242136,      -- CMND_SET_LAYER_VISIBLE
  MSG = 2289627655, MSG_BUSY = 898725220, MSG_DONE = 682363669,   -- the system message window
  PARAM_SET = 3860611758, PARAM_GET = 3522198769, PARAM_HAS = 2947612279, PARAM_CLEAR = 3363400568,
  FOCUS_KEY = TR_Crc("vrfw_title_row_focus"),
  -- the players mark after a label (retail gaiji texts: «1», «1-2», «1-3» players)
  GAIJI = {[1] = 3337686268, [2] = 3561086357, [3] = 433723010},
  IDX0 = 64,                -- list indexes of the declared buttons (the game uses 1..11, the «Mods» button 40)
  EMPTY = 63,               -- list index of an instance the row has no button for
  ID = "menu_engine.title_row",
  T = "title_menu_2",
}

local tr = {
  ready = false,            -- SetupItemButtonNum ran in this title (the row is laid out on its instances)
  row = nil,                -- nil = not built; false = nothing declared or hidden (every handler passes on)
  raw = false,              -- the handlers pass on (the game's own code asks with its own positions)
  co = nil,                 -- the open_menu wait / the locked message
  press = nil,              -- {pos, id}: a «title» press in flight: that position answers that title item
  restore = nil,            -- {item}: the title came back from a «title» press of this button
  logged = {},
}

local function TR_Log(...)
  pcall(funcLuaCommand, TR.LOG, "title_row", ...)
end

local function TR_Once(k, ...)
  if not tr.logged[k] then
    tr.logged[k] = true
    TR_Log(...)
  end
end

local function TR_Call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

-- a title item: a number as written, or crc32 of the name
local function TR_Id(s)
  if type(s) == "number" then
    return s
  end
  if type(s) ~= "string" or s == "" then
    return 0
  end
  return tonumber(s) or TR_Crc(s)
end

local function TR_Text(key)
  if type(key) ~= "string" or key == "" then
    return ""
  end
  local s = TR_Call(TR.TEXT_KEY, key)
  if type(s) ~= "string" or s == "" then
    s = TR_Call(TR.TEXT_ID, TR_Crc(key))
  end
  return type(s) == "string" and s or ""
end

-- the declared buttons, in the menu engine's order
local function TR_Entries()
  local out = {}
  local n = TR_Call(TR.COUNT, TR.HOST)
  if type(n) ~= "number" then
    return out
  end
  for i = 1, n do
    local r = table.pack(pcall(funcLuaCommand, TR.ENTRY, TR.HOST, i))
    if r[1] and type(r[2]) == "string" then
      -- key, text, icon, kind, value, owner, valueId, menus, path, group, aspect, order, plateOn, plateOff, flavor,
      -- players, item, locked, lockedText, gate
      local e = {key = r[2], text = r[3], kind = r[5], value = tostring(r[6] or ""), order = tonumber(r[13]) or 1000,
                 flavor = r[16], players = tonumber(r[17]) or 1, locked_fn = r[19], locked_text = r[20], gate = r[21]}
      local spr = tostring(r[4] or ""):match("([^:]+)$")
      e.plate = {(r[14] and r[14] ~= "") and TR_Crc(r[14]) or 0, (r[15] and r[15] ~= "") and TR_Crc(r[15]) or 0,
                 spr and TR_Crc(spr) or 0}
      e.item = (type(r[18]) == "string" and r[18] ~= "") and TR_Id(r[18]) or TR_Crc(e.key)
      e.as = e.kind == "title" and TR_Id(e.value) or nil
      e.idx = TR.IDX0 + #out
      if e.plate[1] == 0 then
        TR_Once("plate " .. e.key, "button " .. e.key .. " has no [entry.title] plate: its instance keeps the art it had")
      end
      out[#out + 1] = e
    end
  end
  return out
end

-- the game's buttons the mods take out: their title items
local function TR_Hidden()
  local set, any = {}, false
  local s = TR_Call(TR.HIDDEN, TR.HOST)
  if type(s) == "string" then
    for k in string.gmatch(s, "[^,]+") do
      if not string.find(k, ".", 1, true) then
        set[TR_Id(k)] = true
        any = true
      end
    end
  end
  return set, any
end

local function TR_Locked(e)
  if e.kind == "mode" and type(VRFW_Mode) == "table" then
    if not VRFW_Mode.on(e.value) or not VRFW_Mode.unlocked(e.value) then
      return true
    end
  end
  if type(e.locked_fn) == "string" and e.locked_fn ~= "" then
    local f = _G[e.locked_fn]
    if type(f) ~= "function" then
      TR_Once("lockfn " .. e.key, "button " .. e.key .. ": locked function " .. e.locked_fn .. " is not defined (taken as unlocked)")
      return false
    end
    local ok, r = pcall(f, e.key)
    if not ok then
      TR_Once("lockerr " .. e.key, "button " .. e.key .. ": " .. e.locked_fn .. " failed: " .. tostring(r))
      return false
    end
    return r == true
  end
  return false
end

-- the row: the game's buttons as the title's own GetItemListIdx gives them (minus the hidden ones), the declared
-- buttons merged in by order; laid out on the instances the title has
local function TR_Build()
  tr.row = false
  local entries = TR_Entries()
  local hidden, any_hidden = TR_Hidden()
  if #entries == 0 and not any_hidden then
    return
  end
  local h = VRFW_Host.hosts and VRFW_Host.hosts[TR.T]
  local L = h and h.L
  local rt3, rt8 = nil, nil
  if L ~= nil then
    pcall(function() rt3, rt8 = L.t3, L.t8 end)
  end
  local place = {}
  if type(rt3) == "table" then
    for p, idx in ipairs(rt3) do
      place[idx] = place[idx] or p
    end
  end
  if any_hidden and type(rt8) ~= "table" then
    TR_Once("nohide", "the retail title items are not readable (EVT_DEBUG off?): [[hide]] of the game's buttons not applied")
  end
  local get_idx = VRFW_Host.original(TR.T, "GetItemListIdx")
  local base, gone, last = {}, {}, 0
  local blen = 0
  for i = 0, 31 do
    local ok, idx = pcall(get_idx, i, true)
    if not ok or type(idx) ~= "number" then
      break
    end
    blen = i + 1
    local id = type(rt8) == "table" and rt8[idx] or nil
    if id ~= nil and hidden[id] then
      gone[idx] = true
    else
      local o = place[idx] and place[idx] * 100 or (type(rt3) == "table" and last + 1 or (i + 1) * 100)
      last = o
      base[#base + 1] = {pos = i, idx = idx, order = o}
    end
  end
  local row, j = {}, 1
  for _, b in ipairs(base) do
    while j <= #entries and entries[j].order < b.order do
      row[#row + 1] = {e = entries[j]}
      j = j + 1
    end
    row[#row + 1] = b
  end
  for k = j, #entries do
    row[#row + 1] = {e = entries[k]}
  end
  local n = type(GetItemButtonNum) == "function" and GetItemButtonNum(true) or #row
  if type(n) ~= "number" then
    n = #row
  end
  if #row ~= n then
    TR_Log("WARN the row has " .. #row .. " buttons and the title " .. n .. " upper instances (the served row was not fitted): " ..
      (#row > n and "the last declared buttons are left out" or "the last instances stay empty"))
    while #row > n do
      local cut = nil
      for k = #row, 1, -1 do
        if row[k].e ~= nil then cut = k break end
      end
      table.remove(row, cut or #row)
    end
    while #row < n do
      row[#row + 1] = {empty = true}
    end
  end
  local by_idx, by_item, names = {}, {}, {}
  for p, s in ipairs(row) do
    s.at = p - 1
    if s.e ~= nil then
      by_idx[s.e.idx] = s.at
      by_item[s.e.item] = s.e
      s.e.at = s.at
      s.e.lock = TR_Locked(s.e)
      names[#names + 1] = s.e.key .. "@" .. s.at .. (s.e.lock and "(locked)" or "")
    elseif s.idx ~= nil then
      by_idx[s.idx] = s.at
    end
  end
  tr.row = {slots = row, by_idx = by_idx, by_item = by_item, gone = gone, blen = blen, n = n}
  TR_Log("row: " .. #row .. " buttons (" .. #base .. " of the game, " .. #entries .. " declared: " .. table.concat(names, ", ") .. ")")
end

local function TR_Row()
  if not tr.ready or tr.raw then
    return nil
  end
  if tr.row == nil then
    local ok, err = pcall(TR_Build)
    if not ok then
      tr.row = false
      TR_Log("ERROR building the row: " .. tostring(err))
    end
  end
  return tr.row or nil
end

-- the slot at upper position `pos` (nil = not ours: pass on)
local function TR_Slot(pos, upper)
  if upper ~= true or type(pos) ~= "number" then
    return nil
  end
  local r = TR_Row()
  return r and r.slots[pos + 1] or nil
end

local function TR_Label(e)
  local s = TR_Text(e.text)
  if s == "" then
    s = e.key
  end
  local g = TR_Call(TR.TEXT_ID, TR.GAIJI[e.players] or TR.GAIJI[1])
  if type(g) == "string" and g ~= "" then
    s = s .. "  " .. g
  end
  return s
end

-- ---- presses -----------------------------------------------------------------------------------------------------------
local function TR_Busy()
  return tr.co ~= nil
end

local function TR_Restore()
  funcLuaMenuCommand(TR.VISIBLE, TR.CURSOR, 0, true)
  funcLuaMenuCommand(TR.INPUT, TR.MENU, true)
end

local function TR_MessageCo(text)
  funcLuaMenuCommand(TR.INPUT, TR.MENU, false)
  funcLuaMenuCommand(TR.VISIBLE, TR.CURSOR, 0, false)
  coroutine.yield()
  funcLuaCommand(TR.MSG, text, 0, 0, 0, 0, 0, false)
  while funcLuaCommand(TR.MSG_BUSY) do
    coroutine.yield()
  end
  while not funcLuaCommand(TR.MSG_DONE) do
    coroutine.yield()
  end
  TR_Restore()
end

local function TR_OpenCo(menu)
  funcLuaMenuCommand(TR.INPUT, TR.MENU, false)
  funcLuaMenuCommand(TR.VISIBLE, TR.CURSOR, 0, false)
  coroutine.yield()
  funcLuaCommand(TR.OPEN_MENU, menu)
  funcLuaCommand(TR.CHILD, false)
  coroutine.yield()
  while funcLuaMenuCommand(TR.IS_MENU, menu) do
    coroutine.yield()
  end
  funcLuaCommand(TR.CHILD, true)
  TR_Restore()
end

local function TR_ModeCo(e)
  while type(VRFW_Mode) == "table" and VRFW_Mode.busy() do
    VRFW_Mode.step()
    coroutine.yield()
  end
end

local function TR_Refuse(e)
  funcLuaCommand(TR.SOUND, TR.BUZZER)
  TR_Log("button " .. e.key .. " is locked: refused")
  local text = TR_Text(e.locked_text)
  if text ~= "" and tr.co == nil then
    tr.co = coroutine.create(function() TR_MessageCo(text) end)
  end
  return 1
end

-- a press of declared button `e` (a1, a2 = OnEnter's; nxt = the title's own OnEnter)
local function TR_Press(e, nxt, a1, a2)
  if e.lock or TR_Locked(e) then
    return TR_Refuse(e)
  end
  if type(e.gate) == "string" and e.gate ~= "" then
    local f = _G[e.gate]
    if type(f) ~= "function" then
      TR_Log("button " .. e.key .. ": gate " .. e.gate .. " is not defined: refused")
      funcLuaCommand(TR.SOUND, TR.BUZZER)
      return 1
    end
    local ok, r = pcall(f, e.key)
    if not ok or r ~= true then
      if not ok then
        TR_Log("button " .. e.key .. ": gate " .. e.gate .. " failed: " .. tostring(r))
      end
      return 1
    end
  end
  TR_Log("button " .. e.key .. " pressed: " .. tostring(e.kind) .. " " .. e.value)
  if e.kind == "open_menu" then
    funcLuaCommand(TR.SOUND, TR.DECIDE)
    local m = TR_Crc(e.value)
    tr.co = coroutine.create(function() TR_OpenCo(m) end)
    return
  elseif e.kind == "lua" then
    local f = _G[e.value]
    if type(f) ~= "function" then
      TR_Log("button " .. e.key .. ": function " .. e.value .. " is not defined")
      funcLuaCommand(TR.SOUND, TR.BUZZER)
      return 1
    end
    return f(e.key, a2)
  elseif e.kind == "command" then
    funcLuaCommand(TR.SOUND, TR.DECIDE)
    TR_Call(TR_Crc(e.value), e.key)
    return
  elseif e.kind == "title" then
    -- the retail press of that title item, from this position; the title focuses this button when it comes back
    funcLuaCommand(TR.PARAM_SET, TR.FOCUS_KEY, 0, e.item, 1)
    tr.press = {pos = a2, id = e.as}
    local r = table.pack(pcall(nxt, a1, a2))
    tr.press = nil
    if not r[1] then
      pcall(funcLuaCommand, TR.PARAM_CLEAR, TR.FOCUS_KEY)
      error(r[2], 0)
    end
    if r[2] == 1 then
      pcall(funcLuaCommand, TR.PARAM_CLEAR, TR.FOCUS_KEY)
    end
    return table.unpack(r, 2, r.n)
  elseif e.kind == "mode" then
    if type(VRFW_Mode) ~= "table" then
      return TR_Refuse(e)
    end
    local ok, code = VRFW_Mode.start(e.value, "title_row", a2, {
      before = function()
        funcLuaMenuCommand(TR.INPUT, TR.MENU, false)
        funcLuaMenuCommand(TR.VISIBLE, TR.CURSOR, 0, false)
      end,
      back = function()
        TR_Restore()
      end,
    })
    if not ok then
      TR_Log("button " .. e.key .. ": mode " .. e.value .. " refused (code " .. tostring(code) .. ")")
      funcLuaCommand(TR.SOUND, TR.BUZZER)
      return 1
    end
    funcLuaCommand(TR.SOUND, TR.DECIDE)
    tr.co = coroutine.create(function() TR_ModeCo(e) end)
    return
  end
  TR_Log("button " .. e.key .. ": action " .. tostring(e.kind) .. " is not one the title row runs")
  funcLuaCommand(TR.SOUND, TR.BUZZER)
  return 1
end

-- ---- public ------------------------------------------------------------------------------------------------------------
VRFW_TitleRow = VRFW_TitleRow or {}

-- true = title item `id` is a declared button whose action runs inside the title (the title is still there after it)
function VRFW_TitleRow.stays(id)
  local r = TR_Row()
  local e = r and r.by_item[id]
  return e ~= nil and e.kind ~= "title"
end

function VRFW_TitleRow.item(key)
  for _, e in ipairs(TR_Entries()) do
    if e.key == key then
      return e.item
    end
  end
  return nil
end

function VRFW_TitleRow.position(key)
  local r = TR_Row()
  if not r then
    return nil
  end
  for _, s in ipairs(r.slots) do
    if s.e ~= nil and s.e.key == key then
      return s.at
    end
  end
  return nil
end

-- ---- handlers ----------------------------------------------------------------------------------------------------------
local function on(point, phase, fn)
  if type(_ENV[point]) == "function" then
    VRFW_Host.on(TR.T, point, { id = TR.ID, phase = phase, fn = fn })
  end
end

if VRFW_Host ~= nil and type(GetItemListIdx) == "function" and type(OnEnter) == "function" and type(Step) == "function" then
  on("OnInit", "around", function(nxt, ...)
    tr.ready, tr.row, tr.co, tr.press, tr.restore = false, nil, nil, nil, nil
    if TR_Call(TR.PARAM_HAS, TR.FOCUS_KEY) == true then
      local v = TR_Call(TR.PARAM_GET, TR.FOCUS_KEY)
      pcall(funcLuaCommand, TR.PARAM_CLEAR, TR.FOCUS_KEY)
      if type(v) == "number" and v < 0 then
        v = v + 4294967296
      end
      if type(v) == "number" and v ~= 0 then
        tr.restore = {item = v}
      end
    end
    -- the retail start picks the focus from the last request before its first yield, inside OnInit
    local r = table.pack(nxt(...))
    tr.restore = nil
    return table.unpack(r, 1, r.n)
  end)

  -- the instances are known: the row can be laid out (after the online guard's own pass on this point)
  on("SetupItemButtonNum", "after", function()
    tr.ready, tr.row = true, nil
  end)

  on("GetItemListIdx", "around", function(nxt, a1, a2)
    local s = TR_Slot(a1, a2)
    if s == nil then
      return nxt(a1, a2)
    elseif s.e ~= nil then
      return s.e.idx
    elseif s.empty then
      return TR.EMPTY
    end
    return nxt(s.pos, true)
  end)

  on("GetTextureNameItemButton", "around", function(nxt, a1, a2, a3)
    local s = TR_Slot(a1, a3)
    if s ~= nil and s.e ~= nil then
      return s.e.plate[a2] or 0
    elseif s ~= nil and s.empty then
      return 0
    end
    return nxt(a1, a2, a3)
  end)

  on("IsEnableMenuItemButton", "around", function(nxt, a1, a2)
    local s = TR_Slot(a1, a2)
    if s ~= nil and s.e ~= nil then
      return not s.e.lock
    elseif s ~= nil and s.empty then
      return false
    end
    return nxt(a1, a2)
  end)

  on("GetTextNameItemName", "around", function(nxt, a1, a2)
    local s = TR_Slot(a1, a2)
    if s ~= nil and (s.e ~= nil or s.empty) then
      return 0
    end
    return nxt(a1, a2)
  end)

  -- a1 = the label instance (upper ones = their position), a2 = upper
  on("GetTextItemName", "around", function(nxt, a1, a2)
    local s = TR_Slot(a1, a2)
    if s ~= nil and s.e ~= nil then
      return TR_Label(s.e)
    elseif s ~= nil and s.empty then
      return " "
    end
    return nxt(a1, a2)
  end)

  on("GetPlayableModeGaiji", "around", function(nxt, a1, a2)
    local s = TR_Slot(a1, a2)
    if s ~= nil and s.e ~= nil then
      return TR.GAIJI[s.e.players] or TR.GAIJI[1]
    elseif s ~= nil and s.empty then
      return 0
    end
    return nxt(a1, a2)
  end)

  on("GetTitleMenuItemId", "around", function(nxt, a1, a2)
    if tr.press ~= nil and a2 == true and a1 == tr.press.pos then
      return tr.press.id
    end
    local s = TR_Slot(a1, a2)
    local id
    if s ~= nil and s.e ~= nil then
      id = s.e.item
    elseif s ~= nil and s.empty then
      return 0
    else
      id = nxt(a1, a2)
    end
    -- the way back from a «title» press: this button stands for the request it made, the item it pressed does not
    local back = tr.restore
    if back ~= nil then
      local r = TR_Row()
      local e = r and r.by_item[back.item]
      if e ~= nil and e.as ~= nil then
        if s ~= nil and s.e == e then
          return e.as
        elseif id == e.as then
          return 0
        end
      end
    end
    return id
  end)

  on("GetLayerNameFromItemListIdx", "around", function(nxt, a1)
    local r = TR_Row()
    if r then
      if r.by_idx[a1] ~= nil then
        return TR.UPPER
      elseif r.gone[a1] then
        return 0
      end
    end
    return nxt(a1)
  end)

  on("GetLayerIndexFromItemListIdx", "around", function(nxt, a1)
    local r = TR_Row()
    if r then
      if r.by_idx[a1] ~= nil then
        return r.by_idx[a1]
      elseif r.gone[a1] then
        return 0
      end
    end
    return nxt(a1)
  end)

  -- the slide animation of a position the title's table does not reach: none
  on("GetOffsetAnimeItemAttachLocator", "around", function(nxt, a1, a2)
    local v = nxt(a1, a2)
    if v == nil then
      return 0
    end
    return v
  end)

  -- the balloon: a declared button's own text; a game button's from its own place in the title's table
  on("SetFlavorBalloonText", "around", function(nxt, ...)
    local r = TR_Row()
    if r and type(GetSelectItemLayerName) == "function" and GetSelectItemLayerName() == TR.UPPER then
      local sel = GetSelectItemIdx()
      local s = r.slots[(sel or -1) + 1]
      if s ~= nil and s.e ~= nil then
        local text = TR_Text(s.e.flavor)
        if text ~= "" and type(GetCurrentVisibleFlavorLayer) == "function" then
          funcLuaMenuCommand(TR.SET_TEXT, GetCurrentVisibleFlavorLayer(), TR.EXPLAIN, text, 0)
        end
        return
      elseif s ~= nil and s.empty then
        return
      elseif s ~= nil and s.pos ~= sel and type(SetSelectItemLayerInfo) == "function" then
        SetSelectItemLayerInfo(TR.UPPER, s.pos)
        tr.raw = true
        local res = table.pack(pcall(nxt, ...))
        tr.raw = false
        SetSelectItemLayerInfo(TR.UPPER, sel)
        if not res[1] then
          error(res[2], 0)
        end
        return table.unpack(res, 2, res.n)
      end
    end
    return nxt(...)
  end)

  -- the labels: the title tells upper from lower by the length of its own table; the row's length decides
  on("OnOpenLayer", "after", function(_, a1, a2)
    if a1 ~= TR.NAME or type(a2) ~= "number" then
      return
    end
    local r = TR_Row()
    if r and (a2 < r.blen) ~= (a2 < r.n) and type(SetupItemName) == "function" then
      SetupItemName(a2, a2 < r.n)
    end
  end)

  on("OnEnter", "around", function(nxt, a1, a2)
    if TR_Busy() then
      return 1
    end
    if a1 == TR.UPPER and type(a2) == "number" then
      local r = TR_Row()
      if r then
        local s = r.slots[a2 + 1]
        if s ~= nil and s.empty then
          funcLuaCommand(TR.SOUND, TR.BUZZER)
          return 1
        end
        -- by title item: a press another title code forces on any position (top-bar hand-offs) reaches the button too
        local id = GetTitleMenuItemId(a2, true)
        local e = r.by_item[id]
        if e ~= nil then
          return TR_Press(e, nxt, a1, a2)
        end
      end
    end
    return nxt(a1, a2)
  end)

  on("OnBack", "around", function(nxt, ...)
    if TR_Busy() then
      return 1
    end
    return nxt(...)
  end)

  on("OnFunction", "around", function(nxt, ...)
    if TR_Busy() then
      return
    end
    return nxt(...)
  end)

  on("Step", "after", function()
    if tr.co ~= nil then
      local ok, err = coroutine.resume(tr.co)
      if not ok then
        TR_Log("ERROR " .. tostring(err))
        pcall(TR_Restore)
      end
      if not ok or coroutine.status(tr.co) == "dead" then
        tr.co = nil
      end
    end
  end)
end
