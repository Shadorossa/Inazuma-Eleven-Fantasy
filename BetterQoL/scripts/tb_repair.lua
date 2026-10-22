-- Team bank pages › Inazuma Fantasy's «Reparar duplicados» (its scripts\save_slots.lua, once on the load of a slot,
-- before the game reads it): the stored pages follow the cards the repair merged or released. The sidecar
-- team_banks.bin is this mod's blob, so the repair asks here (cross-mod calls: [exports] functions).
--
--   BetterQoL.TeamBanksMembers(slot)       -> { handles } of every member of the stored pages (the repair's tie-break:
--                                             a banked copy counts as docked); nil, why when the sidecar is unreadable
--   BetterQoL.TeamBanksRepair(slot, plan)  -> { moved, cleared, changed, fp_was, fp_now, lines = { … } }; nil, why
--
-- plan = { merges = { { dup, dup_param, kept, kept_param, kept_order }, … }, released = { handle, … },
--          docks_before = { [physical set] = hex }, docks_after = { … } } (the save's 16 team sets: per set its 3 teams
-- as name[128] + 29 member handles, hex-encoded; docks_after only when the save changed).
--
-- A released member becomes the kept card (handle + identity) unless the kept card is already in that team (then the
-- slot is emptied, like a released retail special card); team-field words that named the duplicate (captain handle,
-- captain param) name the kept card; counters recomputed; the sidecar's fingerprint of the mounted docks follows the
-- save when it matched the save before. Was the Rust saveslots::repair::merge_banks of Inazuma Fantasy.

local S = require "lib/tb_store"
local B = require "lib/tb_bytes"

local BLOB = "team_banks.bin"

local function read(slot)
  local ok, data, why = pcall(VRFW.save.get_blob, slot, BLOB)
  if not ok then return nil, tostring(data) end
  if data == nil then
    if why then return nil, tostring(why) end
    return false
  end
  local st, bad = S.decode(data)
  if not st then return nil, BLOB .. " of slot " .. slot .. ": " .. tostring(bad) end
  return st
end

function BetterQoL.TeamBanksMembers(slot)
  local st, why = read(slot)
  if st == nil then return nil, why end
  local out, seen = {}, {}
  if not st then return out end
  for _, b in ipairs(st.banks) do
    if b.content == "stored" then
      local w = B.words(b.sets, 0, S.WORDS)
      for d = 0, S.DOCKS - 1 do
        for t = 0, S.TEAMS - 1 do
          for k = 0, S.MEMBERS - 1 do
            local h = S.member_handle(w, d, t, k)
            if h ~= 0 and not seen[h] then
              seen[h] = true
              out[#out + 1] = h
            end
          end
        end
      end
    end
  end
  return out
end

local function unhex(s)
  return (s:gsub("..", function(x) return string.char(tonumber(x, 16) or 0) end))
end

-- the fingerprint of the mounted docks (logical sets 2..12) from the save's physical sets; nil when the game's
-- logical -> physical table cannot be read
local function docks_fp(sets)
  local p = {}
  for l = S.FIRST_DOCK, S.LAST_DOCK do
    local ok, ph = pcall(VRFW.call, "Party.LogicalToPhysical", 0, l)
    if not ok or type(ph) ~= "number" then return nil end
    local s = sets[ph] or sets[tostring(ph)]
    if type(s) ~= "string" then return nil end
    p[#p + 1] = unhex(s)
  end
  return S.crc32(table.concat(p))
end

function BetterQoL.TeamBanksRepair(slot, plan)
  local st, why = read(slot)
  if st == nil then return nil, why end
  local res = { moved = 0, cleared = 0, changed = false, lines = {} }
  if not st then return res end
  local released, by_dup = {}, {}
  for _, h in ipairs(plan.released or {}) do released[h] = true end
  for _, m in ipairs(plan.merges or {}) do by_dup[m.dup] = m end
  for bi, b in ipairs(st.banks) do
    if b.content == "stored" then
      local w = B.words(b.sets, 0, S.WORDS)
      local idents = B.words(b.idents, 0, S.IDENTS * 2)
      local any = false
      for d = 0, S.DOCKS - 1 do
        local touched = false
        for t = 0, S.TEAMS - 1 do
          local present = {}
          for k = 0, S.MEMBERS - 1 do
            local h = S.member_handle(w, d, t, k)
            if h ~= 0 and not released[h] then present[h] = true end
          end
          for k = 0, S.MEMBERS - 1 do
            local h = S.member_handle(w, d, t, k)
            if h ~= 0 and released[h] then
              touched = true
              local id = (d * S.TEAMS + t) * S.MEMBERS + k
              local m = by_dup[h]
              if m and not present[m.kept] then
                present[m.kept] = true
                w[S.wi(d, S.member_off(t, k))] = m.kept
                local named = false
                for off = t * S.TEAM_SIZE + S.TEAM_FIELDS[1], t * S.TEAM_SIZE + S.TEAM_FIELDS[2] - 4, 4 do
                  if w[S.wi(d, off)] == h then
                    w[S.wi(d, off)] = m.kept
                    named = true
                  end
                end
                if named then
                  for off = t * S.TEAM_SIZE + S.TEAM_FIELDS[1], t * S.TEAM_SIZE + S.TEAM_FIELDS[2] - 4, 4 do
                    if w[S.wi(d, off)] == m.dup_param then w[S.wi(d, off)] = m.kept_param end
                  end
                end
                idents[id * 2 + 1], idents[id * 2 + 2] = m.kept_param, m.kept_order
                res.moved = res.moved + 1
                res.lines[#res.lines + 1] = string.format("team-bank page %d dock %d team %d slot %d: 0x%08X -> kept 0x%08X", bi, d + S.FIRST_DOCK, t, k, h, m.kept)
              else
                S.clear_member(w, d, t, k)
                idents[id * 2 + 1], idents[id * 2 + 2] = 0, 0
                res.cleared = res.cleared + 1
                res.lines[#res.lines + 1] = string.format("team-bank page %d dock %d team %d slot %d: 0x%08X emptied%s", bi, d + S.FIRST_DOCK, t, k, h,
                  m and " (the kept card is already in that team)" or " (retail special card)")
              end
            end
          end
        end
        if touched then
          S.recount(w, d)
          any = true
        end
      end
      if any then
        b.sets = B.from_words(w)
        b.idents = B.from_words(idents)
      end
    end
  end
  res.changed = res.moved + res.cleared > 0
  -- the sidecar's fingerprint of the mounted docks follows the save when it matched the save before
  if plan.docks_before and plan.docks_after then
    local was, now = docks_fp(plan.docks_before), docks_fp(plan.docks_after)
    if was and now and was ~= now and st.fingerprint == was then
      res.fp_was, res.fp_now = st.fingerprint, now
      st.fingerprint = now
      res.changed = true
    elseif not (was and now) then
      res.lines[#res.lines + 1] = "the mounted docks' fingerprint was not followed (the game's team set table is not readable)"
    end
  end
  if res.changed then
    local ok, okw, where = pcall(VRFW.save.set_blob, slot, BLOB, S.encode(st, st.sha1, st.fingerprint))
    if not ok or not okw then return nil, BLOB .. " of slot " .. slot .. ": not written (" .. tostring(ok and where or okw) .. ")" end
    res.written = tostring(where)
  end
  return res
end
