-- ===== EVT inarogue slot card BEGIN =====
-- INAROGUE's card on the VR-Framework's slot screen (its reserved-slot card, docs/refactor/if-adaptation-after-e3.md
-- §5): InaRogue reserves slot 4 (the single INAROGUE save) and gives the card its content here. The framework
-- screen shows the card only while the slot is enterable and calls these fields when it draws / acts (no engine call
-- at chunk load). Texts: InaRogue's text rows (text\rows\menu_text.toml, rogue_screens.toml; 9 languages).
do
  local CMD = {
    CARD = 2751131207,     -- CMND_EVT_RL_CARD () -> ok, best, running, phase, node, played, won, last, lastPhase,
                           --   count, pool, frags, tiers x5, albumOwned, albumTotal (rogue module)
    RESET = 2759097086,    -- CMND_EVT_SLOT_ROGUE_RESET () -> ok, code: the INAROGUE save + its sidecars archived
  }
  -- a text row in the game's language with {1}.. filled; nil when the row is missing
  local function Text(api, id, ...)
    local s = api.Call(api.C.TEXT_GET, id)
    if type(s) ~= "string" or s == "" then
      return nil
    end
    if select("#", ...) == 0 then
      return s
    end
    local a = table.pack(...)
    return (s:gsub("{(%d)}", function(k)
      local v = a[tonumber(k)]
      return v == nil and "" or tostring(v)
    end))
  end
  -- a provider text field: the row, read when the screen shows it (nil = the screen's own default)
  local function T(id)
    return function(api)
      return Text(api, id)
    end
  end
  local function N(v)
    return math.floor(tonumber(v) or 0)
  end

  VRFW_SS_RESERVED = VRFW_SS_RESERVED or {}
  VRFW_SS_RESERVED.inarogue = {
    row = "INAROGUE",
    title = "INAROGUE",
    ask = T(437172294 --[[InaRogue.slot.ask]]),
    -- InaRogue's own atlas: content/images/menu/220_img/evt_rogue/evt_slot_rogue.toml (image recipes made from the
    -- player's game files at the first start)
    art = {
      tex = "#/menu/220_img/evt_rogue/evt_slot_rogue.g4tx",
      body_on = "evt_slot_card_rogue_on", body_off = "evt_slot_card_rogue_off",
      band_on = "evt_slot_band_rogue_on", band_off = "evt_slot_band_rogue_off",
      icon = "evt_slot_icon_rogue_s", icon_off = "evt_slot_icon_rogue_s_off",
      strip = "evt_slot_strip_rogue",
      rows = {"evt_slot_ri_run", "evt_slot_ri_runs", "evt_slot_ri_frags", "evt_slot_ri_time_r", "evt_slot_ri_saved_r"},
    },
    -- rows: En curso, Jugadas / ganadas, Fragmentos (value = count); under the icon the best phase; bottom line the
    -- album of the INAROGUE save (values 18..19; an older loader: no footer)
    fill = function(api)
      local t = {api.Call(CMD.CARD)}
      local running = t[3] == true
          and Text(api, 1342355909 --[[InaRogue.slot.running_value]], N(t[4]), math.max(N(t[5]), 1))
          or Text(api, 3301637055 --[[InaRogue.slot.no_run]])
      local d = {
        line = N(t[2]) > 0 and Text(api, 3312042517 --[[InaRogue.slot.best_phase]], N(t[2]))
            or Text(api, 3805178667 --[[InaRogue.slot.no_phase]]),
        rows = {
          {Text(api, 3410987986 --[[InaRogue.slot.running]]), running},
          {Text(api, 564919435 --[[InaRogue.slot.played_won]]), string.format("%d / %d", N(t[6]), N(t[7]))},
          {Text(api, 219978234 --[[InaRogue.slot.fragments]])},
        },
        count = N(t[12]),
        empty = Text(api, 369058907 --[[InaRogue.slot.empty]]),
      }
      if type(t[19]) == "number" and t[19] > 0 then
        d.footer = Text(api, 1151350748 --[[InaRogue.slot.album]], N(t[18]), N(t[19]))
      end
      return d
    end,
    -- «Reiniciar» (CMD_FUNC2 on the card, inarogue.md §22): the loader archives slot 4 and its sidecars
    -- (evt_loader\backups\slot4\reset_<stamp>); the next entry is a clean first run
    reset = {
      button = 4215737381,   -- menu_text «Reiniciar»
      ask = T(3324694580 --[[evt_ir_reset_ask]]),
      done = T(2436758108 --[[evt_ir_reset_done]]),
      fail = T(121057726 --[[evt_ir_reset_fail]]),
      run = function(api)
        return api.Call(CMD.RESET)
      end,
    },
  }
end
-- ===== EVT inarogue slot card END =====
