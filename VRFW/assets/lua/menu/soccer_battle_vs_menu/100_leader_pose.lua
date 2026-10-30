-- VRFW 5v5 VS screen leader pose (soccer_battle_vs_menu, the VS screen of every 5v5 match: pachangas, friendlies,
-- challenges). Our side's leader is built by OnSetupCaptainCharaModel(layer, idx, true), which plays the clip
-- ステータスポーズ1L (VS画面ポーズ1L on a team without a leader). Only the menu packs of the motion sets c000101,
-- c000102 and c000111 hold that clip, so any other leader (a coach of another body or with his own skeleton) stands in
-- a T-pose. When the clip is missing from his packs the leader gets one they hold:
--   * c000101 / c000102 / c000111: the retail clip;
--   * another standard body set (c000NNN): VS画面ポーズ3L;
--   * a motion set of his own: 立ち1L, the one clip every menu pack holds.
-- His motion set comes from CMND_VRFW_CHARA_MOTION_SET (model key first, then his chara); without an answer the body
-- type decides (0 / 1 = retail clip, else VS画面ポーズ3L). funcLuaMenuCommand is swapped only for the retail call.
-- Wraps a global function only; no engine call at load time.
VRFW_VsLeaderPose = type(VRFW_VsLeaderPose) == "table" and VRFW_VsLeaderPose or {}
do
  local P = VRFW_VsLeaderPose
  local setup = rawget(_ENV, "OnSetupCaptainCharaModel")
  if not P.wrapped and type(setup) == "function" then
    P.wrapped = true
    local C = {
      LOG = VRFW_Cmd.EVT_LOG,          -- CMND_EVT_LOG
      MOTION_SET = VRFW_Cmd.VRFW_CHARA_MOTION_SET,   -- CMND_VRFW_CHARA_MOTION_SET
      MODEL_CHANGE = 59611540,   -- the retail model change (layer, idx, model key)
      PLAY_CLIP = 180466856,     -- the retail clip play (layer, idx, clip)
    }
    local CLIP_VS_POSE_3L = 3774626291   -- VS画面ポーズ3L
    local CLIP_STAND_1L = 2263925137     -- 立ち1L
    local RETAIL_CLIPS = { [4174155486] = true, [3536477041] = true }   -- ステータスポーズ1L, VS画面ポーズ1L
    local RETAIL_SETS = { c000101 = true, c000102 = true, c000111 = true }
    local RETAIL_BODIES = { [0] = true, [1] = true }

    local function hex(v) return VRFW_Id.hex(v) end

    local function log(...)
      pcall(funcLuaCommand, C.LOG, "VRFW vs leader", ...)
    end

    local function motion_set(key, chara)
      local ok, set = pcall(funcLuaCommand, C.MOTION_SET, key or 0, chara or 0)
      if ok and type(set) == "string" and set ~= "" then return set end
      return nil
    end

    -- the clip that replaces the retail one (nil = keep it) and why
    local function replacement(key, chara, body)
      local set = motion_set(key, chara)
      if set ~= nil then
        if RETAIL_SETS[set] then return nil, "set " .. set end
        if string.match(set, "^c000%d%d%d$") then return CLIP_VS_POSE_3L, "standard set " .. set end
        return CLIP_STAND_1L, "own set " .. set
      end
      if type(body) == "number" and not RETAIL_BODIES[body] then return CLIP_VS_POSE_3L, "body " .. body end
      return nil, "retail body / unknown"
    end

    P.replacement = replacement

    rawset(_ENV, "OnSetupCaptainCharaModel", function(layer, idx, ours, ...)
      if ours ~= true then
        return setup(layer, idx, ours, ...)
      end
      local chara, body = 0, nil
      local okl, _, hdl = pcall(GetTeamLeader, true)
      if okl and type(hdl) == "number" and hdl ~= 0 then
        local ok6, st6, base = pcall(GetSoccerCharaInfo, hdl, 6)
        if ok6 and st6 == true then chara = base end
        local okb, stb, bt = pcall(GetBodyTypeWithCharaHdl, hdl)
        if okb and stb == true then body = bt end
      end
      local real = funcLuaMenuCommand
      local key, from, to, why = 0, nil, nil, nil
      funcLuaMenuCommand = function(id, l, i, v, ...)
        if l == layer then
          if id == C.MODEL_CHANGE then
            key = v
          elseif id == C.PLAY_CLIP and RETAIL_CLIPS[v] then
            from = v
            to, why = replacement(key, chara, body)
            if to ~= nil then v = to end
          end
        end
        return real(id, l, i, v, ...)
      end
      local r = table.pack(pcall(setup, layer, idx, ours, ...))
      funcLuaMenuCommand = real
      log("pose: model key", hex(key), "chara", hex(chara), "body", tostring(body), "clip", tostring(from), "->",
        tostring(to or from), tostring(why), "ok", tostring(r[1]))
      if not r[1] then error(r[2], 0) end
      return table.unpack(r, 2, r.n)
    end)
  end
end
