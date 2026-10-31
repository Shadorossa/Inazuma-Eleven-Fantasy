-- New Recruitment › with the option «Fichajes» on «Álbum» (NewRecruitment.RecruitFrom("office") false) the recruitment
-- office leaves the Mercado (market_menu): its bar is the bar of the shop whose entries open the office's contact set
-- (CMND_VRFW_SHOP_SCREENS, content\shop_redirects\office.toml), the last bar of the list (retail order, and after
-- Inazuma Fantasy's bars). While the office is off:
--   * the list's instance count answers one less (CMND_GET_CREATE_LAYER_NUM of the list layer): the retail setup gives
--     the list one focusable bar less, and every other reader of the count (BetterUI's L2 / R2 shop cycle) skips it;
--   * the left-over bar instance is hidden after each setup and focus change, and its decide does nothing.
-- The bar is found once per Mercado open (each bar's shop read through the retail IsCheckNoTokenShopIdx, the shop token
-- query answered here so no engine call is made); a bar that is not the last one is left as it is (a log line).
-- Wrappers over the retail globals; engine calls only inside the game's callbacks; every call goes through pcall.
local LIST = 536841765                    -- shop01_21_market_list_item: the Mercado's bars
local LAYER_NUM = 1175615627              -- CMND_GET_CREATE_LAYER_NUM (layer) -> instances
local SHOP_TOKENS = 3325760404            -- (shop id, kind) -> the shop's token items (asked by IsCheckNoTokenShopIdx)
local LAYER_VISIBLE = 711242136           -- CMND_SET_LAYER_VISIBLE (layer, instance, on)
local LOG = 3661580131                    -- CMND_EVT_LOG
local OFFICE_SETS = {"NewRecruitment.office", "new_recruitment.office"}   -- the office set's key (mod id, former id)

local state = {checked = false, hidden = nil, wrapped = false}   -- hidden = the office bar's instance (0-based)

local function log(...)
  pcall(funcLuaCommand, LOG, "NewRecruitment office bar", ...)
end

local function office_off()
  return type(NewRecruitment) == "table" and type(NewRecruitment.RecruitFrom) == "function"
    and (select(2, pcall(NewRecruitment.RecruitFrom, "office"))) == false
end

local function unsigned(v)
  return type(v) == "number" and v % 4294967296 or nil
end

-- the shops whose entries open the office's contact set
local function office_shops()
  local sets, shops = {}, {}
  for _, key in ipairs(OFFICE_SETS) do sets[VRFW_Crc32(key)] = true end
  local r = table.pack(pcall(funcLuaCommand, VRFW_Cmd.VRFW_SHOP_SCREENS))
  if r[1] and type(r[2]) == "number" then
    for i = 1, r[2] do
      local shop, set = unsigned(r[1 + 2 * i]), unsigned(r[2 + 2 * i])
      if shop ~= nil and set ~= nil and sets[set] then shops[shop] = true end
    end
  end
  return shops
end

-- the shop of bar k (1-based): the retail IsCheckNoTokenShopIdx reads it from the script's own list
local function shop_of(k)
  if type(IsCheckNoTokenShopIdx) ~= "function" then return nil end
  local real, seen = funcLuaCommand, nil
  funcLuaCommand = function(...)
    local cmd, shop = ...
    if cmd == SHOP_TOKENS then
      seen = shop
      return 0
    end
    return real(...)
  end
  pcall(IsCheckNoTokenShopIdx, k)
  funcLuaCommand = real
  return unsigned(seen)
end

-- once per Mercado open: the office bar's instance while the office is off
local function check(real_menu)
  if state.checked then return state.hidden end
  state.checked = true
  if not office_off() then return nil end
  local ok, count = pcall(real_menu, LAYER_NUM, LIST)
  if not ok or type(count) ~= "number" or count < 2 then return nil end
  local shops = office_shops()
  local last = shop_of(count)
  if last ~= nil and shops[last] then
    state.hidden = count - 1
    log("hidden: bar", count, "of", count)
    return state.hidden
  end
  for k = 1, count - 1 do
    local shop = shop_of(k)
    if shop ~= nil and shops[shop] then
      log("not the last bar: left", k, "of", count)
      return nil
    end
  end
  return nil
end

local function hide_bar()
  if state.hidden ~= nil then
    pcall(funcLuaMenuCommand, LAYER_VISIBLE, LIST, state.hidden, false)
  end
end

-- the list's instance count, one less while the office bar is hidden (the exact arguments passed on)
local function wrap_menu_command()
  if state.wrapped then return end
  local real = rawget(_ENV, "funcLuaMenuCommand")
  if type(real) ~= "function" then return end
  state.wrapped = true
  funcLuaMenuCommand = function(...)
    local cmd, layer = ...
    if cmd == LAYER_NUM and layer == LIST and select("#", ...) == 2 then
      local count = real(...)
      if type(count) == "number" and check(real) ~= nil then
        return count - 1
      end
      return count
    end
    return real(...)
  end
end

local retail_init = rawget(_ENV, "OnInit")
if type(retail_init) == "function" then
  function OnInit(...)
    state.checked, state.hidden = false, nil
    wrap_menu_command()
    return retail_init(...)
  end
end

local retail_setup = rawget(_ENV, "OnSetupLayer")
if type(retail_setup) == "function" then
  function OnSetupLayer(layer, index, ...)
    wrap_menu_command()
    local r = table.pack(retail_setup(layer, index, ...))
    if layer == LIST and index == state.hidden then hide_bar() end
    return table.unpack(r, 1, r.n)
  end
end

local retail_focus = rawget(_ENV, "OnChangeFocus")
if type(retail_focus) == "function" then
  function OnChangeFocus(layer, ...)
    local r = table.pack(retail_focus(layer, ...))
    if layer == LIST then hide_bar() end
    return table.unpack(r, 1, r.n)
  end
end

local retail_decide = rawget(_ENV, "OnDecideFocus")
if type(retail_decide) == "function" then
  function OnDecideFocus(layer, index, ...)
    if layer == LIST and state.hidden ~= nil and index == state.hidden then
      return
    end
    return retail_decide(layer, index, ...)
  end
end
