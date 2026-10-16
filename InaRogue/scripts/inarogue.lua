-- InaRogue › INAROGUE (docs/game/modes/inarogue.md; docs/framework/new-core/if-wave6a.md). Declarations:
-- content\game\rogue.toml. Part of Inazuma Fantasy until 2026-10-14 (the mod InaRogue since). Was the Rust module rogue of inazuma_fantasy.dll (≈16.7k lines) until 2026-10-10: the bank,
-- the run and its route map, the match pool, the boss tiers, the album, the unlocks for the office, the coaches, the
-- Rogue points and avatars, the formation book, the loot, the gacha coins, the owned-player lists, the retail
-- achievements switched off in the INAROGUE save and the debug probes are this script and scripts\lib\rogue\. Same
-- commands (CMND_INAROGUE_RL_* / CMND_INAROGUE_RU_*, aliases CMND_EVT_RL_* / CMND_EVT_RU_*), same blobs and JSON of mod
-- inazuma_fantasy (rogue_bank.json, rogue_run.json, rogue_formations.json, rogue_avatars.json, rogue_probe.json per slot;
-- rogue_unlocks.json, rogue_rivals_seen.json global), same catalogues (content\rogue\*.toml).
--
-- Since 2026-10-11 (IF final round, docs/framework/new-core/if-final-misc.md) also the overlay session wrappers
-- CMND_EVT_RL_SESSION_* (scripts\lib\rogue\svc_session.lua over VRFW.session), the «Sin rol» commands
-- (CMND_EVT_RL_NO_ROLE / _ALL / _ROLE_CARRY, scripts\lib\rogue\svc_misc.lua over scripts\board_role.lua's SET_ROLE)
-- and the coaches' stat_mult on the match copy (content\game\rogue.toml's [[VRFW.MatchStat]] InaRogue.Coach over
-- the multipliers this script publishes). A return to the title (the framework's game_reset event) drops every cache.

InaRogue.Mode = InaRogue.Mode or {}

local Core = require "lib/rogue/core"
local bank = require "lib/rogue/svc_bank"
local run = require "lib/rogue/svc_run"
local meta = require "lib/rogue/svc_meta"
local misc = require "lib/rogue/svc_misc"
local session = require "lib/rogue/svc_session"

Core.bank, Core.run, Core.meta = bank, run, meta

local ENABLED = Core.ENABLED

-- INAROGUE's save slot for the native answers (content\game\rogue.toml: inarogue.active, the coach's match
-- modifier, Utilities' kit-less uniform): filled whether the mode is on or not (the slot is reserved either way)
do
  local U = require "lib/rogue/util"
  local ok, e = pcall(VRFW.native.table_replace, "InaRogue.Slot", nil, { { U.ROGUE_SLOT, 1 } })
  if not ok then VRFW.warn("rogue: InaRogue.Slot: " .. tostring(e)) end
end
if not ENABLED then VRFW.log("rogue: module rogue off ([modules] rogue / [modes] inarogue / [phase]): INAROGUE commands answer nothing") end

-- every command handler: the slot caches follow the slot events first; nothing while the module is off
local function call(f, ...)
  if not ENABLED then return nil end
  Core.sync()
  return f(...)
end

-- the bank, the run start, the team screen, gacha, the slot card, the album
function InaRogue.Mode.BankCount(...) return call(bank.Count, ...) end
function InaRogue.Mode.BankGet(...) return call(bank.Get, ...) end
function InaRogue.Mode.BankAdd(...) return call(bank.Add, ...) end
function InaRogue.Mode.Chara(...) return call(bank.Chara, ...) end
function InaRogue.Mode.Budget(...) return call(bank.Budget, ...) end
function InaRogue.Mode.BankDebugFill(...) return call(bank.DebugFill, ...) end
function InaRogue.Mode.StarterInfo(...) return call(bank.StarterInfo, ...) end
function InaRogue.Mode.StarterGift(...) return call(bank.StarterGift, ...) end
function InaRogue.Mode.PickReset(...) return call(bank.PickReset, ...) end
function InaRogue.Mode.PickToggle(...) return call(bank.PickToggle, ...) end
function InaRogue.Mode.PickState(...) return call(bank.PickState, ...) end
function InaRogue.Mode.PickCommit(...) return call(bank.PickCommit, ...) end
function InaRogue.Mode.FragsAdd(...) return call(bank.FragsAdd, ...) end
function InaRogue.Mode.GachaGrant(...) return call(bank.GachaGrant, ...) end
function InaRogue.Mode.TeamReset(...) return call(bank.TeamReset, ...) end
function InaRogue.Mode.TeamSet(...) return call(bank.TeamSet, ...) end
function InaRogue.Mode.TeamClear(...) return call(bank.TeamClear, ...) end
function InaRogue.Mode.TeamSlot(...) return call(bank.TeamSlot, ...) end
function InaRogue.Mode.TeamInfo(...) return call(bank.TeamInfo, ...) end
function InaRogue.Mode.TeamFormation(...) return call(bank.TeamFormation, ...) end
function InaRogue.Mode.TeamFits(...) return call(bank.TeamFits, ...) end
function InaRogue.Mode.TeamCommit(...) return call(bank.TeamCommit, ...) end
function InaRogue.Mode.GachaDraw(...) return call(bank.GachaDraw, ...) end
function InaRogue.Mode.Card(...) return call(bank.Card, ...) end
function InaRogue.Mode.RunEnd(...) return call(bank.RunEnd, ...) end
function InaRogue.Mode.AlbumInfo(...) return call(bank.AlbumInfo, ...) end

-- the run
function InaRogue.Mode.RunInfo(...) return call(run.Info, ...) end
function InaRogue.Mode.RunStart(...) return call(run.Start, ...) end
function InaRogue.Mode.RunNode(...) return call(run.Node, ...) end
function InaRogue.Mode.RunEdge(...) return call(run.Edge, ...) end
function InaRogue.Mode.RunMove(...) return call(run.Move, ...) end
function InaRogue.Mode.RunStage(...) return call(run.Stage, ...) end
function InaRogue.Mode.RunResume(...) return call(run.Resume, ...) end
function InaRogue.Mode.RunMatch(...) return call(run.Match, ...) end
function InaRogue.Mode.RunReserve(...) return call(run.Reserve, ...) end
function InaRogue.Mode.RunResult(...) return call(run.Result, ...) end
function InaRogue.Mode.RunClear(...) return call(run.Clear, ...) end
function InaRogue.Mode.RunNextPhase(...) return call(run.NextPhase, ...) end
function InaRogue.Mode.RunAbandon(...) return call(run.Abandon, ...) end
function InaRogue.Mode.RunSquad(...) return call(run.Squad, ...) end
function InaRogue.Mode.RunSetHdl(...) return call(run.SetHdl, ...) end
function InaRogue.Mode.RunSetSlot(...) return call(run.SetSlot, ...) end
function InaRogue.Mode.RunRecruit(...) return call(run.Recruit, ...) end
function InaRogue.Mode.RunLaunch(...) return call(run.Launch, ...) end
function InaRogue.Mode.RunLoot(...) return call(run.Loot, ...) end
function InaRogue.Mode.RunRival(...) return call(run.Rival, ...) end

-- meta progress
function InaRogue.Mode.UnlockInfo(...) return call(meta.RuInfo, ...) end
function InaRogue.Mode.UnlockCard(...) return call(meta.RuCard, ...) end
function InaRogue.Mode.UnlockState(...) return call(meta.RuState, ...) end
function InaRogue.Mode.UnlockNews(...) return call(meta.RuNews, ...) end
function InaRogue.Mode.CoachList(...) return call(meta.CoachList, ...) end
function InaRogue.Mode.CoachPick(...) return call(meta.CoachPick, ...) end
function InaRogue.Mode.CoachRun(...) return call(meta.CoachRun, ...) end
function InaRogue.Mode.CoachItems(...) return call(meta.CoachItems, ...) end
function InaRogue.Mode.AvatarGet(...) return call(meta.AvatarGet, ...) end
function InaRogue.Mode.AvatarList(...) return call(meta.AvatarList, ...) end
function InaRogue.Mode.AvatarTeam(...) return call(meta.AvatarTeam, ...) end
function InaRogue.Mode.AvatarUnlock(...) return call(meta.AvatarUnlock, ...) end
function InaRogue.Mode.AvatarSelect(...) return call(meta.AvatarSelect, ...) end
function InaRogue.Mode.Points(...) return call(meta.Points, ...) end
function InaRogue.Mode.PointsGiven(...) return call(meta.PointsGiven, ...) end
function InaRogue.Mode.FormOwned(...) return call(meta.FormOwned, ...) end
function InaRogue.Mode.FormList(...) return call(meta.FormList, ...) end

-- the owned-player lists, the probes
function InaRogue.Mode.PartyCount(...) return call(misc.PartyCount, ...) end
function InaRogue.Mode.PartyHdl(...) return call(misc.PartyHdl, ...) end
function InaRogue.Mode.NoRole(...) return call(misc.NoRole, ...) end
function InaRogue.Mode.NoRoleAll(...) return call(misc.NoRoleAll, ...) end
function InaRogue.Mode.RoleCarry(...) return call(misc.RoleCarry, ...) end

-- the overlay session (registered at start: the framework recovers its journal then)
if ENABLED then session.start() end
function InaRogue.Mode.SessionBegin(...) return call(session.Begin, ...) end
function InaRogue.Mode.SessionEnd(...) return call(session.End, ...) end
function InaRogue.Mode.SessionState(...) return call(session.State, ...) end
function InaRogue.Mode.SessionReload(...) return call(session.Reload, ...) end
function InaRogue.Mode.SessionDiskCheck(...) return call(session.DiskCheck, ...) end
function InaRogue.Mode.SessionOrphan(...) return call(session.Orphan, ...) end
function InaRogue.Mode.ProbeInfo(...) return call(misc.ProbeInfo, ...) end
function InaRogue.Mode.ProbeCount(...) return call(misc.ProbeCount, ...) end
function InaRogue.Mode.ProbeSet13(...) return call(misc.ProbeSet13, ...) end
function InaRogue.Mode.ProbeRestore13(...) return call(misc.ProbeRestore13, ...) end
function InaRogue.Mode.ProbeKv(...) return call(misc.ProbeKv, ...) end

-- the INAROGUE save shows / sets no retail achievements («logros», inarogue.md §21)
if ENABLED then
  VRFW.on("hook:RL_TrophySetTier", function(ev) return misc.on_trophy(ev) end)
end

-- a return to the title: every slot cache is dropped (the next command reads the files again)
VRFW.on("game_reset", function() Core.forget_all() end)

-- ---------------------------------------------------------------------------------------- exports (mod.toml [exports])
-- Inazuma Fantasy (which requires InaRogue) reads these from its scripts: INAROGUE's save slot (its rules stay off
-- there) and the Rogue points item. (The «no move rank-up by use in INAROGUE» rule is data for the mod True Hissatsu:
-- content\true_hissatsu\inarogue.toml, on the state key inarogue.active.)
local U = require "lib/rogue/util"
function InaRogue.SaveSlot() return U.ROGUE_SLOT end
function InaRogue.PointsItem() return Core.cfg().points.item end
