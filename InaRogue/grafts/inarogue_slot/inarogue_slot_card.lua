-- ===== EVT inarogue slot card BEGIN =====
-- INAROGUE's card on the VR-Framework's slot screen (its reserved-slot card, docs/refactor/if-adaptation-after-e3.md
-- §5): InaRogue reserves slot 4 (the single INAROGUE save) and gives the card its content here. The framework
-- screen shows the card only while the slot is enterable and calls these fields when it draws / acts (no engine call
-- at chunk load). Texts: the menu_text rows of rogue_play_text_build.py (9 languages) when the field reads one, else
-- the Spanish literal the screen had before E3.
do
  local CMD = {
    CARD = 2751131207,     -- CMND_EVT_RL_CARD () -> ok, best, running, phase, node, played, won, last, lastPhase,
                           --   count, pool, frags, tiers x5, albumOwned, albumTotal (rogue module)
    RESET = 2759097086,    -- CMND_EVT_SLOT_ROGUE_RESET () -> ok, code: the INAROGUE save + its sidecars archived
  }
  -- a menu_text row in the game's language, the literal when the row is missing
  local function T(id, fallback)
    return function(api)
      local s = api.Call(api.C.TEXT_GET, id)
      return (type(s) == "string" and s ~= "") and s or fallback
    end
  end
  local function N(v)
    return math.floor(tonumber(v) or 0)
  end

  VRFW_SS_RESERVED = VRFW_SS_RESERVED or {}
  VRFW_SS_RESERVED.inarogue = {
    row = "INAROGUE",
    title = "INAROGUE",
    ask = "INAROGUE tiene una única partida propia (ranura 4), la misma desde cualquier ranura\n" ..
          "y separada de tus partidas normales. ¿Entrar en INAROGUE?",
    -- IF's own atlas (slot_rogue_art.py at pack time; Level-5-derived, never committed)
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
      local d = {
        line = N(t[2]) > 0 and string.format("Mejor fase alcanzada: %d", N(t[2])) or "Ninguna fase superada",
        rows = {
          {"En curso", t[3] == true and string.format("Fase %d · combate %d", N(t[4]), math.max(N(t[5]), 1)) or "Sin partida"},
          {"Jugadas / ganadas", string.format("%d / %d", N(t[6]), N(t[7]))},
          {"Fragmentos"},
        },
        count = N(t[12]),
        empty = "Se creará al entrar",
      }
      if type(t[19]) == "number" and t[19] > 0 then
        d.footer = string.format("Álbum: %d / %d", N(t[18]), N(t[19]))
      end
      return d
    end,
    -- «Reiniciar» (CMD_FUNC2 on the card, inarogue.md §22): the loader archives slot 4 and its sidecars
    -- (evt_loader\backups\slot4\reset_<stamp>); the next entry is a clean first run
    reset = {
      button = 4215737381,   -- menu_text «Reiniciar»
      ask = T(3324694580, "¿Reiniciar INAROGUE desde cero?\nSe archivan la partida del modo (ranura 4), el banco, " ..
              "la run, las formaciones y el equipo.\nLa próxima vez empezarás como la primera. (Copia en " ..
              "evt_loader/backups/slot4)"),
      done = T(2436758108, "INAROGUE reiniciado. Al entrar empezarás desde cero.\nTodo lo anterior está guardado " ..
               "en evt_loader/backups/slot4."),
      fail = T(121057726, "No se ha podido reiniciar INAROGUE (código {1}).\nSal de INAROGUE a tu partida y vuelve " ..
               "a intentarlo."),
      run = function(api)
        return api.Call(CMD.RESET)
      end,
    },
  }
end
-- ===== EVT inarogue slot card END =====
