-- Character Reforged: the player page's SLOTS (docs/refactor/aura-mods-split.md «Player page»). The paged player page
-- (PERFIL, ATRIBUTOS, SUPERTÉCNICAS, the Hiper page, the retail pages, other mods' pages; research/grafts/plate_pages,
-- plate_model, plate_hiper_*: moved from Inazuma Fantasy on 2026-10-14) draws Character Reforged's own values; other
-- mods ADD values to it as data, an [[entry]] of one of the hosts of content\menus\player_page_host.toml whose action is
-- a command of theirs (action = { command = "CMND_..." }):
--
--   character_reforged.page_stat       (charaStHdl, idx 0..8) -> value (< 0 or not a number = no answer), ...
--                                      the stat a row / the radar shows (idx 8 = Suerte); without an answer: Character
--                                      Reforged's CMND_CHARACTERREFORGED_CHARA_STAT (the per-character stats, Suerte
--                                      derived from the curve)
--   character_reforged.page_luck_bonus (charaStHdl) -> a number added to Suerte's DEFAULT value (a training mod's
--                                      committed Suerte; not asked when a page_stat entry answered)
--   character_reforged.page_stat_max   (charaStHdl, idx) -> ok, value, base, bonus, delta, committed, min, max
--                                      the top of a stat's gauge on ATRIBUTOS = base + max (a training mod's limit);
--                                      without an answer: one scale for the 8 rows
--   character_reforged.page_stat_gain  (charaStHdl) -> ok, favouredMask, gain0 .. gain8 (stat idx order)
--                                      the stats a form adds (the ATRIBUTOS Normal / Miximax view, the Hiper page's
--                                      gains text); without an answer: no Miximax view
--
-- The last declared entry is asked first (load order: a mod loaded later overrides), then the earlier ones, then the
-- default. Asked only at run time (never while a chunk loads); every call goes through pcall.
-- Also here: Page.SkillSetOn() (the option «Tabla de habilidades» on the new set: the Hiper page is the page of the new
-- set's aura / mix slots, shown only then) and Page.MixOf(card) (the base's mix-slot store, scripts\mix_slots.lua).
-- For other mods' menu Lua: CharacterReforged.Page.Stat / LuckBonus / StatTop / GainsRaw / Providers / SkillSetOn /
-- MixOf.
CharacterReforged = type(CharacterReforged) == "table" and CharacterReforged or {}
if CharacterReforged.Page == nil then
  local Page = {}
  CharacterReforged.Page = Page
  Page.HOST_STAT = "character_reforged.page_stat"
  Page.HOST_LUCK_BONUS = "character_reforged.page_luck_bonus"
  Page.HOST_STAT_MAX = "character_reforged.page_stat_max"
  Page.HOST_STAT_GAIN = "character_reforged.page_stat_gain"
  Page.CMD_CHARA_STAT = 1938088826         -- crc32("CMND_CHARACTERREFORGED_CHARA_STAT")
  Page.LUCK = 8                            -- stat idx of Suerte
  Page.CMD_MIX_GET = 358194355             -- crc32("CMND_CHARACTERREFORGED_MIX_GET")
  Page.CMD_OPTION_GET = 4082322029         -- crc32("CMND_VRFW_OPTION_GET")
  Page.SKILL_SET_OPTION = "character_reforged.skill_set_view"   -- options.toml row (0 Victory Road, 1 the new set)
  Page.providerCache = {}                  -- host -> the command ids of its entries, last declared first

  local function EngineReady()
    return type(rawget(_ENV, "funcLuaCommand")) == "function"
  end

  -- the command ids declared on a host, last declared first (read once per VM, at the first run-time use)
  function Page.Providers(host)
    local cached = Page.providerCache[host]
    if cached ~= nil then
      return cached
    end
    local list = {}
    if not EngineReady() then
      return list
    end
    local menu = rawget(_ENV, "VRFW_Menu")
    if type(menu) == "table" and type(menu.entries) == "function" then
      local ok, entries = pcall(menu.entries, host)
      if ok and type(entries) == "table" then
        for i = #entries, 1, -1 do
          local entry = entries[i]
          local id = entry.value_id
          if type(id) ~= "number" and type(entry.value) == "string" and type(rawget(_ENV, "CALC_CRC")) == "function" then
            id = CALC_CRC(entry.value)
          end
          if entry.kind == "command" and type(id) == "number" and id ~= 0 then
            list[#list + 1] = id
          end
        end
      end
    end
    Page.providerCache[host] = list
    return list
  end

  -- the value of stat idx (0..8) of a chara status handle: the mods' answer, else Character Reforged's; nil = none
  function Page.Stat(hdl, idx)
    if not EngineReady() then
      return nil
    end
    for _, id in ipairs(Page.Providers(Page.HOST_STAT)) do
      local ok, value = pcall(funcLuaCommand, id, hdl, idx)
      if ok and type(value) == "number" and value >= 0 then
        return value
      end
    end
    local ok, value = pcall(funcLuaCommand, Page.CMD_CHARA_STAT, hdl, idx)
    if ok and type(value) == "number" and value >= 0 then
      if idx == Page.LUCK then
        value = value + Page.LuckBonus(hdl)
      end
      return value
    end
    return nil
  end

  -- the sum of the page_luck_bonus answers for a chara status handle (0 = none)
  function Page.LuckBonus(hdl)
    local sum = 0
    if not EngineReady() then
      return sum
    end
    for _, id in ipairs(Page.Providers(Page.HOST_LUCK_BONUS)) do
      local ok, bonus = pcall(funcLuaCommand, id, hdl)
      if ok and type(bonus) == "number" then
        sum = sum + bonus
      end
    end
    return sum
  end

  -- the top of stat idx's gauge (base + max of a training mod's answer); nil = no mod answers
  function Page.StatTop(hdl, idx)
    if not EngineReady() then
      return nil
    end
    for _, id in ipairs(Page.Providers(Page.HOST_STAT_MAX)) do
      local ok, answered, _, base, _, _, _, _, max = pcall(funcLuaCommand, id, hdl, idx)
      if ok and answered == true and type(base) == "number" and type(max) == "number" and base + max > 0 then
        return base + max
      end
    end
    return nil
  end

  -- the stat gains of a chara status handle's form, as the packed pcall of the answering command:
  -- {true, ok, favouredMask, gain0, ..., gain8}; {false} = no mod answers
  function Page.GainsRaw(hdl)
    if not EngineReady() then
      return {false}
    end
    for _, id in ipairs(Page.Providers(Page.HOST_STAT_GAIN)) do
      local result = {pcall(funcLuaCommand, id, hdl)}
      if result[1] and result[2] and type(result[4]) == "number" then
        return result
      end
    end
    return {false}
  end

  -- true while the option «Tabla de habilidades» shows the new set (6 moves + aura slot + mix slot)
  function Page.SkillSetOn()
    if not EngineReady() then
      return false
    end
    local ok, value = pcall(funcLuaCommand, Page.CMD_OPTION_GET, Page.SKILL_SET_OPTION)
    return ok and (value == 1 or value == true)
  end

  -- the mix-slot move of a saved card (Character Reforged's store); 0 = empty / no answer
  function Page.MixOf(card)
    if not EngineReady() or card == nil or card == 0 then
      return 0
    end
    local ok, move = pcall(funcLuaCommand, Page.CMD_MIX_GET, card)
    return (ok and type(move) == "number") and move or 0
  end
end
