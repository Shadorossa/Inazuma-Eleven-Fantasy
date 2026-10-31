-- Battle Bay Deluxe: the Battle Bay's game layout shared by the Campaign and the Draft (docs/game/modes/estadio-bb.md
-- §2 / §3.2; the same values as vr_sigs::bb, which the VR-Framework's BB pages service uses). Declarations:
-- content\game\campaign.toml (enjoy, EnjoyTable, EnjoyRow, EvalCondition).

local U = require "lib/util"

local G = {}

-- the grid menu (EnjoySelectTeamMenu)
G.GRID_LAYER = 0x065471F6          -- the grid layer's hash (FindChildByHash; a decide's button on the grid)
G.BTN_CAMPAIGN_START = 0x140980D9  -- the button that starts the Campaña
G.SLOTS = 28                       -- grid slot records: this + GridMenu.Slots + i * 0x38 (GridSlot)
G.SLOT_STRIDE = 0x38
G.RIVALS = 7                       -- Session +0x2CA6F0: the Campaña's 7 rivals (u32)
G.S_RIVALS = 0x2CA6F0

-- where the grid's slot records start in the menu on the running build (game profile field GridMenu.Slots); nil
-- when the profile does not name it
local slot_base
function G.slot_base()
  if not slot_base then
    local ok, v = pcall(VRFW.game.field, "GridMenu.Slots")
    if ok and type(v) == "number" and v > 0 then
      slot_base = v
    end
  end
  return slot_base
end

-- the address of grid slot record `i` of `menu`; nil when the slot base is unknown on this build
function G.slot_addr(menu, i)
  local base = G.slot_base()
  if not base then
    return nil
  end
  return menu + base + i * G.SLOT_STRIDE
end

-- the enjoy_mode_team_config rows in memory, table order: { { team, cond, addr } … } (cond 0 = no unlock
-- condition); nil, why when the table is not readable
function G.enjoy_rows()
  local tblp = U.global("enjoy")
  if not tblp then
    return nil, "enjoy table not readable"
  end
  local tbl = U.struct("EnjoyTable", tblp)
  local rows, n = U.get(tbl, "rows"), U.get(tbl, "count")
  if not rows or rows < 0x10000 then
    return nil, "enjoy rows not readable"
  end
  if not n or n < 1 or n > 4096 then
    return nil, "enjoy row count not readable"
  end
  local out = {}
  for i = 0, n - 1 do
    local a = rows + i * 0x40
    local r = U.struct("EnjoyRow", a)
    local team, cond = U.get(r, "team"), U.get(r, "cond")
    if team == nil or cond == nil then
      return nil, "enjoy row " .. i .. " not readable"
    end
    out[#out + 1] = { team = team, cond = cond, addr = a }
  end
  return out
end

-- the enjoy row of `team` (its address), nil when none
function G.enjoy_row(team)
  local rows = G.enjoy_rows()
  if not rows then
    return nil
  end
  for _, r in ipairs(rows) do
    if r.team == team then
      return r.addr
    end
  end
  return nil
end

-- the game's unlock-condition evaluator (0xDCB560, the grid ctor's): true / false, nil when it could not run
function G.eval(cond)
  if not VRFW.is_on("EvalCondition") then
    return nil
  end
  local ok, v = U.call("EvalCondition", cond)
  if not ok then
    return nil
  end
  return U.truthy(v)
end

-- the VR-Framework's «win it to unlock it» rule (docs/framework/bb-pages.md §8): -1 not under it, 0 locked,
-- 1 unlocked; nil when the BB pages service is not there
function G.unlock_rule(team)
  local ok, r = pcall(VRFW.bb.unlock_rule, team)
  if ok and type(r) == "number" then
    return r
  end
  return nil
end

return G
