  -- Shared by Utilities' passive configurator (research/grafts/passive_config: team dock + plate) and Inazuma
  -- Fantasy's Supertécnicas screen (research/grafts/ss2_pc_rows): included as @ICONS@, built into each mod's patch.
  -- ---- archetype icons of the status plate header ----------------------------------------------------------------
  -- Retail draws ONE build icon (chara field 36 = the archetype the configurator derives: slot 4's for a dual one) on
  -- _icon_build_dmy01 in the header's left strip (soccer11_04 / soccer11_04pp layouts). A dual archetype (slots 4
  -- and 5 of different archetypes, CMND_UTIL_PC_INFO) also shows slot 5's archetype on _icon_lock_status01: the
  -- 28 px quad right above it in the same strip, centred on it (retail hides that quad on every refresh, so a single
  -- archetype keeps the retail look). Hooked on UpdateCharaStatusPlateInfoByCharaStHdl, which every header refresh
  -- goes through (BySoccerCharaHdl / UseAttributeBg included).
  UTIL_PCI = UTIL_PCI or {}
  UTIL_PCI.CMD_INFO = @crc:CMND_UTIL_PC_INFO@
  UTIL_PCI.ICON_TEX = 2320109963 -- #/menu/200_icon/15_icon_common/icon_common.g4tx
  UTIL_PCI.LOCK_MESH = 1670039012 -- _icon_lock_status01
  UTIL_PCI.LOCK_DUMMY = @crc:icon_lock_status01@
  UTIL_PCI.LAYERS = UTIL_PCI.LAYERS or {}
  UTIL_PCI.LAYERS[1844915256] = true -- soccer11_04_formation_chara_status (plate, team dock)
  UTIL_PCI.LAYERS[607716004] = true -- soccer11_04_chara_status (Supertécnicas screen)

  -- ---- list picker rows (evt_pc_row, both pickers): the plate row's dark rounded square behind the icon -----------
  UTIL_PCI.PLATE_TEX = 4021797290 -- #/menu/00_soccer/soccer11/soccer11_20/soccer11_20.g4tx
  UTIL_PCI.ROW_BACK_MESH = 2172872396 -- _icon_cmd_type_base01 (72 px backing quad of evt_pc_row)
  UTIL_PCI.ROW_BACK_DUMMY = 1011017977 -- icon_cmd_type_base01
  UTIL_PCI.ROW_MASKED_MESH = 1255155594 -- _icon_cmd_type_dmy01 (unused)
  UTIL_PCI.PLATE_SLOT = 2597149412 -- teambuff_base01 (texture slot of the plate row's _teambuff_base01)
  -- the special passive's tile (soccer11_20 sprite): only when a mod's slot rules declare one ([slots] special_tile,
  -- answered by CMND_UTIL_PC_SPECIAL; the plate session sets it), else the retail tile
  UTIL_PCI.SPECIAL_TILE = UTIL_PCI.SPECIAL_TILE or 0

  -- ---- mods' passive icons ----------------------------------------------------------------------------------------
  -- A mod draws its own icon for a passive effect (sprite of the per-language atlas icon_teambuff) instead of the
  -- retail buff icon of the effect (GRAND_TOTAL_INFO buff icon, kept for the match HUD): its passive_config\*.toml
  -- [[effect_icon]] (Utilities, docs/game/mechanics/pasivas-configurables.md §3), answered by CMND_UTIL_PC_EFF_ICON
  -- (0 = none). Asked once per effect and VM. Wraps the retail SwapPassiveSkillEffectIcon (plate rows, techniques
  -- screen); the pickers ask UTIL_PCI.EffIcon.
  UTIL_PCI.TEAMBUFF_TEX = 2301895383 -- #/menu/200_icon/08_icon_teambuff/<LG>/icon_teambuff.g4tx
  UTIL_PCI.TEAMBUFF_SLOT = 3234721532 -- icon_teambuff_dmy01 (the retail row's buff icon slot)
  UTIL_PCI.CMD_EFF_ICON = @crc:CMND_UTIL_PC_EFF_ICON@
  UTIL_PCI.EFF_ICON = UTIL_PCI.EFF_ICON or {}
  function UTIL_PCI.EffIcon(eff)
    if type(eff) ~= "number" or eff == 0 then
      return nil
    end
    local v = UTIL_PCI.EFF_ICON[eff]
    if v == nil then
      local ok, spr = pcall(funcLuaCommand, UTIL_PCI.CMD_EFF_ICON, eff)
      v = (ok and type(spr) == "number") and spr or 0
      UTIL_PCI.EFF_ICON[eff] = v
    end
    return v ~= 0 and v or nil
  end
  function UTIL_PCI.RowEffIcon(L, k, eff)
    local spr = UTIL_PCI.EffIcon(eff)
    if spr ~= nil then
      pcall(funcLuaMenuCommand, 558735651, L, UTIL_PCI.TEAMBUFF_TEX, spr, UTIL_PCI.TEAMBUFF_SLOT, 0, k)
    end
    return spr ~= nil
  end
  -- special = an entry of a special slot: the declared special tile (UTIL_PCI.SPECIAL_TILE, 0 = none)
  function UTIL_PCI.RowBacking(L, k, show, badge, special)
    funcLuaMenuCommand(3405944500, L, UTIL_PCI.ROW_MASKED_MESH, false, k)
    funcLuaMenuCommand(3405944500, L, UTIL_PCI.ROW_BACK_MESH, show == true, k)
    if show then
      local tile = special and UTIL_PCI.SPECIAL_TILE ~= nil and UTIL_PCI.SPECIAL_TILE ~= 0 and UTIL_PCI.SPECIAL_TILE or nil
      pcall(funcLuaMenuCommand, 558735651, L, UTIL_PCI.PLATE_TEX, tile or (badge and 63179614) or 2597149412,
        UTIL_PCI.ROW_BACK_DUMMY, 0, k) -- special tile / teambuff_base02 / teambuff_base01
    end
  end

  function UTIL_PCI.DualIcon(L, idx, h, kind)
    if not UTIL_PCI.LAYERS[L] or type(h) ~= "number" or h == 0 or kind == 6 then
      return
    end
    idx = idx or 0
    if type(GetBuildTypeIconTextureNameByCharaStHdl) == "function" and GetBuildTypeIconTextureNameByCharaStHdl(h) == 0 then
      return
    end
    local ok, got, _, a, b = pcall(funcLuaCommand, UTIL_PCI.CMD_INFO, h)
    if not ok or got ~= true or type(a) ~= "number" or type(b) ~= "number" then
      return
    end
    if a < 0 or a > 5 or b < 0 or b > 5 or a == b or type(GeTeamBuffBuildTypeIconTextureName) ~= "function" then
      return
    end
    local tex = GeTeamBuffBuildTypeIconTextureName(b)
    if tex == nil or tex == 0 then
      return
    end
    funcLuaMenuCommand(558735651, L, UTIL_PCI.ICON_TEX, tex, UTIL_PCI.LOCK_DUMMY, 0, idx)
    funcLuaMenuCommand(3405944500, L, UTIL_PCI.LOCK_MESH, true, idx)
  end

  -- Install(wrap): the wrappers of SwapPassiveSkillEffectIcon (own effect icons on the plate rows) and
  -- UpdateCharaStatusPlateInfoByCharaStHdl (the dual archetype's 2nd icon). wrap(name, make) wraps global `name`
  -- (make(orig) returns the wrapper): Utilities' hook files pass their EVT_Host wrapper; without one (a script no
  -- host owns, e.g. Inazuma Fantasy's Supertécnicas screen) the globals are wrapped directly, once each. Hook() =
  -- Install with the direct wrapper (also once per frame from the plate: a global defined later is caught then).
  UTIL_PCI.done = UTIL_PCI.done or {}
  function UTIL_PCI.DirectWrap(name, make)
    local cur = _ENV[name]
    if type(cur) ~= "function" or UTIL_PCI.done[name] then
      return UTIL_PCI.done[name] == true
    end
    _ENV[name] = make(cur)
    UTIL_PCI.done[name] = true
    return true
  end
  function UTIL_PCI.Install(wrap)
    wrap = wrap or UTIL_PCI.DirectWrap
    if UTIL_PCI.installed == wrap then
      return
    end
    local a = wrap("SwapPassiveSkillEffectIcon", function(prev)
      return function(L, k, eff, ...)
        local r = table.pack(prev(L, k, eff, ...))
        pcall(UTIL_PCI.RowEffIcon, L, k, eff)
        return table.unpack(r, 1, r.n)
      end
    end)
    local b = wrap("UpdateCharaStatusPlateInfoByCharaStHdl", function(prev)
      return function(a1, a2, a3, a4, a5, a6, ...)
        local r1, r2, r3, r4 = prev(a1, a2, a3, a4, a5, a6, ...)
        pcall(UTIL_PCI.DualIcon, a1, a2, a3, a6)
        return r1, r2, r3, r4
      end
    end)
    if a and b then
      UTIL_PCI.installed = wrap
    end
  end
  function UTIL_PCI.Hook()
    if UTIL_PCI.installed == nil then
      UTIL_PCI.Install(UTIL_PCI.DirectWrap)
    end
  end
