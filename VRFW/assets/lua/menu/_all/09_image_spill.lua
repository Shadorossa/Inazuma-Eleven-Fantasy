-- VR-Framework › image spill, menu side (every script VM). A G4TX atlas holds at most 255 entries; the new sprites of
-- the mods that do not fit in a game atlas are built into sibling atlases (<stem>__vrfw_ovf<N>.g4tx beside it, the
-- image type: docs/framework/types/image.md «Entry limit»). A script sets a sprite with the game's sprite command
-- (funcLuaMenuCommand(558735651, layer, texture id or path, sprite, slot, 0, instance)) naming the game atlas; when
-- that sprite moved, the call names the sibling atlas instead, which is loaded first (CMND_LOAD_MENU_RES_TEXTURE) and
-- the call made again once it is in. Loading a game atlas by path also loads its sibling atlases. Without moved
-- sprites every call goes through unchanged. The engine's funcLuaMenuCommand is wrapped the moment it is
-- registered; the list is asked once per VM, at the first sprite command. No engine call at load time. One log
-- line per sibling atlas loaded in a VM.
-- Own atlases of sprite redirects (content\sprite_redirects, scripts\sprite_redirects.lua): the game's sprite setter
-- takes declared sprites from a mod's own atlas natively. A menu VM (one with __menuObjPtr) asks for the own atlases
-- once, right after its first menu command, and loads an own atlas only when a game atlas it serves is loaded at that
-- moment (`1506186496(texture id)` answers nothing for a texture the game does not hold); the others are loaded later
-- in the same VM when it loads one of their game atlases by path. Every texture a menu loads takes one entry of the
-- engine's menu texture list (2048 entries for all open menus, nie.exe 0x10E8BC0; a load past it is dropped and its
-- sprites draw nothing), so own atlases loaded by every menu VM filled it in matches with many open menus. Not
-- logged here: the framework's script logs the own atlases once per session (scripts\sprite_redirects.lua).
if VRFW_ImageSpill == nil then
  local S = {
    SET_SPRITE = 558735651,     -- (layer, texture id or path, sprite crc or name, slot, 0, instance)
    LOAD_TEX = VRFW_Cmd.LOAD_MENU_RES_TEXTURE,       -- CMND_LOAD_MENU_RES_TEXTURE(path)
    TEX_LOADING = 1506186496,   -- (texture id) -> true while it loads (funcLuaCommand)
    ATLASES = VRFW_Cmd.VRFW_IMAGE_SPILL_ATLASES,       -- CMND_VRFW_IMAGE_SPILL_ATLASES(0) -> n; (i) -> texture id of the i-th atlas
    FIND = VRFW_Cmd.VRFW_IMAGE_SPILL_FIND,          -- CMND_VRFW_IMAGE_SPILL_FIND(atlas, sprite) -> sibling texture id, sibling path
    SIBLINGS = VRFW_Cmd.VRFW_IMAGE_SPILL_SIBLINGS,      -- CMND_VRFW_IMAGE_SPILL_SIBLINGS(atlas, 0) -> n; (atlas, i) -> path, texture id
    OWN_ATLASES = VRFW_Cmd.VRFW_SPRITE_REDIRECT_ATLASES,   -- (0) -> n; (i, 0) -> path of the i-th own atlas; (i, -1) -> number of game atlases it serves; (i, k) -> texture id of the k-th one
    LOG = VRFW_Cmd.EVT_LOG,           -- CMND_EVT_LOG
    atlases = nil,              -- texture id -> true: the atlases with moved sprites (this VM)
    any = false,
    found = {},                 -- [atlas][sprite] -> { id, path } or false
    by_path = {},               -- game atlas path -> { { id, path } of a sibling atlas, ... }
    loaded = {},                -- sibling texture id -> true once asked to load in this VM
    pending = {},               -- "layer slot instance" -> the call that waits for its sibling atlas
    waiting = false,
    hooked = false,
    own_asked = false,          -- the own atlases of sprite redirects were asked for in this VM
    own_loaded = {},            -- own atlas path -> true once loaded in this VM
    own_by_game = nil,          -- game atlas texture id -> { own atlas path, ... } not loaded yet in this VM
  }
  VRFW_ImageSpill = S

  local function unsigned(v)
    if type(v) == "number" and v < 0 then return v + 4294967296 end
    return v
  end

  local function read_atlases()
    S.atlases = {}
    local ok, n = pcall(funcLuaCommand, S.ATLASES, 0)
    if ok and type(n) == "number" then
      for i = 1, n do
        local o, id = pcall(funcLuaCommand, S.ATLASES, i)
        if o and type(id) == "number" then S.atlases[unsigned(id)] = true end
      end
    end
    S.any = next(S.atlases) ~= nil
  end

  local function find(tex, spr)
    local t = unsigned(tex)
    local row = S.found[t]
    if row == nil then row = {} S.found[t] = row end
    local s = unsigned(spr)
    local hit = row[s]
    if hit == nil then
      local ok, id, path = pcall(funcLuaCommand, S.FIND, tex, spr)
      hit = (ok and type(id) == "number" and type(path) == "string") and { id = unsigned(id), path = path } or false
      row[s] = hit
    end
    return hit
  end

  local function load(real, hit, why)
    if S.loaded[hit.id] then return end
    S.loaded[hit.id] = true
    pcall(real, S.LOAD_TEX, hit.path)
    pcall(funcLuaCommand, S.LOG, "VRFW image spill: loading " .. hit.path .. " (" .. why .. ")")
  end

  local function loading(id)
    local ok, b = pcall(funcLuaCommand, S.TEX_LOADING, id)
    return ok and b == true
  end

  -- the sprite calls that waited for their sibling atlas, made again once it is in
  local function replay(real)
    local left = false
    for key, w in pairs(S.pending) do
      if loading(w.id) then
        left = true
      else
        S.pending[key] = nil
        pcall(real, table.unpack(w.args, 1, w.args.n))
      end
    end
    S.waiting = left
  end

  -- the game holds the texture (loaded or loading): the command answers a boolean, nothing for an unknown texture
  local function held(id)
    local ok, b = pcall(funcLuaCommand, S.TEX_LOADING, id)
    return ok and b ~= nil
  end

  -- an own atlas, loaded once in this VM; true while it is still loading
  local function load_own_atlas(real, path)
    local id = unsigned(VRFW_Crc32(path))
    if not S.own_loaded[path] then
      S.own_loaded[path] = true
      pcall(real, S.LOAD_TEX, path)
    end
    return loading(id), id
  end

  -- the own atlases waiting for the game atlas `game` (texture id), loaded now; the id of one still loading, if any
  local function load_own_for(real, game)
    local list = S.own_by_game[game]
    if list == nil then return nil end
    S.own_by_game[game] = nil
    local wait = nil
    for _, own in ipairs(list) do
      local busy, id = load_own_atlas(real, own)
      if busy then wait = id end
    end
    return wait
  end

  -- the own atlases of sprite redirects, asked for once in this VM (after its first menu command made with its own menu
  -- object): the ones whose game atlas the game holds now are loaded, the others wait for this VM to load or name their
  -- game atlas. CMND_LOAD_MENU_RES_TEXTURE reads the menu object without a null check: a menu VM gets __menuObjPtr
  -- before OnInit; a script without one (title_main names a menu that may not exist yet in __menuObjName) never loads
  -- them.
  local function load_own(real)
    if _ENV.__menuObjPtr == nil then return end
    S.own_asked = true
    S.own_by_game = {}
    local ok, n = pcall(funcLuaCommand, S.OWN_ATLASES, 0)
    if not ok or type(n) ~= "number" then return end
    for i = 1, n do
      local o, path = pcall(funcLuaCommand, S.OWN_ATLASES, i, 0)
      if o and type(path) == "string" then
        local games, now = {}, false
        -- a bounded walk over the count the command gives (it answers 0, not nil, past the last id)
        local oc, count = pcall(funcLuaCommand, S.OWN_ATLASES, i, -1)
        for k = 1, math.min(oc and tonumber(count) or 0, 8) do
          local og, id = pcall(funcLuaCommand, S.OWN_ATLASES, i, k)
          if not og or type(id) ~= "number" or id == 0 then break end
          games[#games + 1] = unsigned(id)
          if not now and held(id) then now = true end
        end
        if now or #games == 0 then
          load_own_atlas(real, path)
        else
          for _, id in ipairs(games) do
            local list = S.own_by_game[id]
            if list == nil then
              list = {}
              S.own_by_game[id] = list
            end
            list[#list + 1] = path
          end
        end
      end
    end
  end

  local function make(real)
    -- a game atlas loaded by path: its sibling atlases follow it
    local function load_game_atlas(path, ...)
      if S.atlases == nil then read_atlases() end
      if not S.any then
        return real(...)
      end
      local list = S.by_path[path]
      if list == nil then
        list = {}
        local ok, n = pcall(funcLuaCommand, S.SIBLINGS, path, 0)
        if ok and type(n) == "number" then
          for i = 1, n do
            local o, p, id = pcall(funcLuaCommand, S.SIBLINGS, path, i)
            if o and type(p) == "string" and type(id) == "number" then list[#list + 1] = { id = unsigned(id), path = p } end
          end
        end
        S.by_path[path] = list
      end
      local r = table.pack(real(...))
      for _, sib in ipairs(list) do load(real, sib, "with " .. path) end
      return table.unpack(r, 1, r.n)
    end

    local function handle(...)
      local cmd = ...
      if S.waiting then replay(real) end
      if cmd == S.SET_SPRITE then
        local _, layer, tex, spr, slot, _, inst = ...
        local key = tostring(layer) .. " " .. tostring(slot) .. " " .. tostring(inst)
        S.pending[key] = nil   -- a newer sprite for the same place
        if tex ~= nil and S.own_by_game ~= nil and next(S.own_by_game) ~= nil then
          -- a sprite of a game atlas whose own atlases wait: loaded now, the call made again once they are in
          local game = type(tex) == "string" and unsigned(VRFW_Crc32(tex)) or unsigned(tex)
          local wait = load_own_for(real, game)
          if wait ~= nil then
            S.pending[key] = { id = wait, args = table.pack(...) }
            S.waiting = true
          end
        end
        if S.atlases == nil then read_atlases() end
        if S.any then
          if tex ~= nil and spr ~= nil and (type(tex) == "string" or S.atlases[unsigned(tex)]) then
            local hit = find(tex, spr)
            if hit then
              local args = table.pack(...)
              args[3] = hit.id
              load(real, hit, "sprite " .. tostring(spr))
              if loading(hit.id) then
                S.pending[key] = { id = hit.id, args = args }
                S.waiting = true
              else
                S.pending[key] = nil
              end
              return real(table.unpack(args, 1, args.n))
            end
          end
        end
      elseif cmd == S.LOAD_TEX then
        local _, path = ...
        if type(path) == "string" then
          if S.own_by_game == nil or next(S.own_by_game) == nil then
            return load_game_atlas(path, ...)
          end
          local r = table.pack(load_game_atlas(path, ...))
          load_own_for(real, unsigned(VRFW_Crc32(path)))
          return table.unpack(r, 1, r.n)
        end
      end
      return real(...)
    end

    return function(...)
      if not S.own_asked then
        local r = table.pack(handle(...))
        load_own(real)
        return table.unpack(r, 1, r.n)
      end
      return handle(...)
    end
  end

  local current = rawget(_ENV, "funcLuaMenuCommand")
  if type(current) == "function" then
    S.hooked = true
    rawset(_ENV, "funcLuaMenuCommand", make(current))
  else
    -- the engine registers its functions after the chunks ran: wrap it then (chained onto any earlier __newindex)
    local okm, meta = pcall(getmetatable, _ENV)
    if okm and (meta == nil or type(meta) == "table") then
      if meta == nil then
        meta = {}
        if not pcall(setmetatable, _ENV, meta) then meta = nil end
      end
      if meta ~= nil then
        local previous = meta.__newindex
        meta.__newindex = function(globals, k, v)
          if previous == nil then
            rawset(globals, k, v)
          elseif type(previous) == "function" then
            previous(globals, k, v)
          else
            previous[k] = v
          end
          if k == "funcLuaMenuCommand" and type(v) == "function" and not S.hooked then
            local stored = rawget(globals, k)
            if type(stored) == "function" then
              S.hooked = true
              rawset(globals, k, make(stored))
            end
          end
        end
      end
    end
  end
end
