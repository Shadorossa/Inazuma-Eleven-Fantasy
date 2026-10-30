-- Saved JSON documents of a mod script: one per save slot (or one outside the slots), read once per slot, checked,
-- set aside when unreadable, written at once or staged with the game's save of the slot.
--   require "VRFW/lib/save_doc"      -- sets VRFW.save.doc in this VM (and returns the library)
--   local store = VRFW.save.doc("my_data.json", {
--     scope   = "slot",              -- "slot" (default): one document per save slot; "global": one outside the slots
--     version = 1,                   -- the document's `version` field; nil = not checked
--     migrate = function(j, slot) return j end,   -- a document of another version: the migrated one, or nil + why
--     decode  = function(j, slot) return doc end, -- the decoded JSON as the caller's document, or nil + why
--     encode  = function(doc, slot) return t end, -- the document as a table for VRFW.json.encode, or its text
--     default = function(slot) return {} end,     -- a new document (default: { version = version })
--     pretty  = false,               -- pretty JSON
--     stage   = false,               -- slot writes wait for the game's save of the slot while the slot service runs
--     aside   = true,                -- an unreadable or unusable document is set aside (.archive\); false = left there
--     log     = "tag",               -- the log tag (default: the document's name)
--     text    = false,               -- true: decode gets the file's text (not JSON-decoded, no version check)
--     loaded  = function(doc, slot, state) end,   -- after each read of get() (logs, one-time fixes)
--   })
--   store:get([slot])            -> the document of slot (default: the active one), cached per slot; read again
--                                   after a load, copy, delete, new game or reset of that slot (the slot events)
--   store:put(doc[, slot[, now]])-> ok, where: the document cached and written (staged unless `now`)
--   store:load(slot)             -> doc, state: read now, not cached; state "new" | "ok" | "migrated" | "bad"
--   store:write(doc, slot[, now])-> ok, where, staged: written now or staged (unless `now`), not cached
--   store:aside(why, slot)       -> the note of the blob set aside
--   store:forget()               -> drops the cached document
--   Doc.slot()                   -> the active slot (1 while the slot service does not run)
--   Doc.ready()                  -> the slot service runs

local Doc = {}

local stores = {}

function Doc.ready()
  local ok, r = pcall(VRFW.slots.ready)
  return ok and r == true
end

function Doc.slot()
  local ok, s = pcall(VRFW.slots.active)
  s = ok and tonumber(s) or nil
  if not s or s == 0 then return 1 end
  return s
end

local Store = {}
Store.__index = Store

local function scope_of(self, slot)
  if self.global then return "global" end
  return slot
end

function Store:log_error(...)
  VRFW.error(self.tag .. ":", ...)
end

function Store:log_warn(...)
  VRFW.warn(self.tag .. ":", ...)
end

function Store:new_doc(slot)
  if self.opts.default then return self.opts.default(slot) end
  return { version = self.opts.version }
end

function Store:aside(why, slot)
  local ok, note = pcall(VRFW.save.blob_aside, self.name, scope_of(self, slot))
  note = ok and note or tostring(note)
  self:log_error(string.format("%s%s: %s; set aside: %s", self.global and "" or ("slot " .. tostring(slot) .. ": "),
    self.name, tostring(why), tostring(note)))
  return note
end

-- unusable: set aside (or left there with aside = false), a new document
function Store:reject(why, slot)
  if self.opts.aside == false then
    self:log_warn(string.format("%s%s: %s; left as it is, a new document used", self.global and "" or ("slot " .. tostring(slot) .. ": "),
      self.name, tostring(why)))
  else
    self:aside(why, slot)
  end
  return self:new_doc(slot), "bad"
end

function Store:load(slot)
  if not self.global then slot = slot or Doc.slot() end
  local ok, text, why = pcall(VRFW.save.blob, self.name, scope_of(self, slot))
  if not ok then return self:reject(text, slot) end
  if text == nil and why ~= nil then return self:reject(why, slot) end
  if text == nil or text == "" then return self:new_doc(slot), "new" end
  if self.opts.text then
    local okd, d, derr = pcall(self.opts.decode, text, slot)
    if not okd then return self:reject(d, slot) end
    if d == nil then return self:reject(derr or "unusable", slot) end
    return d, "ok"
  end
  local okj, j, jerr = pcall(VRFW.json.decode, text)
  if not okj then return self:reject(j, slot) end
  if type(j) ~= "table" then return self:reject(j == nil and ("bad JSON: " .. tostring(jerr)) or "not an object", slot) end
  local state = "ok"
  local want = self.opts.version
  if want ~= nil and tonumber(j.version) ~= want then
    if not self.opts.migrate then return self:reject("version " .. tostring(j.version) .. " (expected " .. tostring(want) .. ")", slot) end
    local okm, m, merr = pcall(self.opts.migrate, j, slot)
    if not okm then return self:reject(m, slot) end
    if type(m) ~= "table" then return self:reject(merr or ("version " .. tostring(j.version) .. " cannot be migrated"), slot) end
    j, state = m, "migrated"
  end
  if self.opts.decode then
    local okd, d, derr = pcall(self.opts.decode, j, slot)
    if not okd then return self:reject(d, slot) end
    if d == nil then return self:reject(derr or "unusable", slot) end
    j = d
  end
  return j, state
end

function Store:text_of(doc, slot)
  local v = doc
  if self.opts.encode then v = self.opts.encode(doc, slot) end
  if type(v) == "string" then return v end
  return VRFW.json.encode(v, self.opts.pretty == true)
end

function Store:write(doc, slot, now)
  if not self.global then slot = slot or Doc.slot() end
  local ok, text = pcall(self.text_of, self, doc, slot)
  if not ok then return false, "cannot encode: " .. tostring(text) end
  if self.opts.stage and not now and not self.global and Doc.ready() then
    local oks, staged, where = pcall(VRFW.save.blob_stage, self.name, text, slot)
    if oks and staged then return true, where, true end
    self:log_warn("stage failed (" .. tostring(oks and where or staged) .. "): written now")
  end
  local okw, written, where = pcall(VRFW.save.blob_write, self.name, text, scope_of(self, slot))
  if not okw then return false, tostring(written) end
  return written == true, where, false
end

-- the slot events since the last check: a store whose slot was loaded, copied over, deleted, started anew or reset
-- drops its cached document (what the game never saved is gone with it)
local event_seen = nil

local function check_events()
  local ok, seq = pcall(VRFW.slots.event_seq)
  if not ok or type(seq) ~= "number" then return end
  if event_seen == nil or seq == event_seen then
    event_seen = seq
    return
  end
  for n = math.max(event_seen + 1, seq - 63), seq do
    local okk, kind, a, b = pcall(VRFW.slots.event, n)
    local slot = nil
    if okk and (kind == "switched" or kind == "deleted" or kind == "new_game" or kind == "reset") then slot = a end
    if okk and kind == "copied" then slot = b end
    if slot ~= nil then
      for _, s in ipairs(stores) do
        if not s.global and s.key == slot then s:forget() end
      end
    end
  end
  event_seen = seq
end

function Store:get(slot)
  if not self.global then check_events() end
  local key = self.global and "global" or (slot or Doc.slot())
  if self.doc ~= nil and self.key == key then return self.doc, key end
  local doc, state = self:load(key ~= "global" and key or nil)
  self.doc, self.key, self.state = doc, key, state
  if self.opts.loaded then self.opts.loaded(doc, key, state) end
  return doc, key
end

function Store:put(doc, slot, now)
  local key = self.global and "global" or (slot or Doc.slot())
  self.doc, self.key = doc, key
  return self:write(doc, key ~= "global" and key or nil, now)
end

function Store:forget()
  self.doc, self.key, self.state = nil, nil, nil
end

function Doc.new(name, opts)
  opts = opts or {}
  local self = setmetatable({ name = name, opts = opts, global = opts.scope == "global", tag = opts.log or name }, Store)
  stores[#stores + 1] = self
  return self
end

-- a slot the game loads from its file: the cached documents are read again (writes staged and not saved are gone)
pcall(VRFW.on, "slot_load", function(ev)
  if ev and ev.after_load then return nil end
  for _, s in ipairs(stores) do
    if not s.global then s:forget() end
  end
  return nil
end)

if type(VRFW) == "table" and type(VRFW.save) == "table" and rawget(VRFW.save, "doc") == nil then
  pcall(rawset, VRFW.save, "doc", Doc.new)
end

return Doc
