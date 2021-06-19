local Promise = require(script.Parent.Promise)
local DS = require(script.Parent.DataStoreInterface)
local Lock = require(script.Parent.Lock)

local Store = {}
Store.__index = Store

local msg = {
  newStoreNameString = "Cannot construct a store without a string name!",
  invalidEntry = "Value is not a valid entry!",
  lockedEntry = "Entry %s is currently used in another session!",
  abandonVersionMismatch = "Entry %s is at version %i while its datastore entry is at version %i. The datastore entry will be used instead.",
  abandonLockedEntry = "Entry %s is currently used in another session. The datastore version will be used instead.",
  willMigrate = "Found an incompatible entry at datastore key %s. Data will be migrated.",
}

local function deep(value)
  if type(value) == "table" then
    local new = {}
    for i, v in pairs(value) do
      new[i] = deep(v)
    end
    return new
  else
    return value
  end
end

function Store.new(name)
  assert(type(name) == "string", msg.newStoreNameString)

  return setmetatable({
    _name = name,
  }, Store)
end

-- type Entry = {
--   meta: {
--     version: number,
--     lock?: Lock
--   },
--   data: any
-- }
function Store.newEntry()
  return {
    meta = {
      version = 0,
    },
  }
end

function Store.isEntry(value)
  return type(value) == "table"
    and type(value.meta) == "table"
    and type(value.meta.version) == "number"
    and (value.meta.lock == nil or Lock.isValid(value.meta.lock))
end

function Store:defaultTo(value)
  self._defaultValue = deep(value)
end

-- Load and lock an entry from the store
-- throws when the entry is already aquired by another session
-- (key: any) => Promise<Entry>
function Store:load(key)
  key = tostring(key)

  return Promise.new(function(resolve, reject)
    local rejectValue, entry

    DS.perform("UpdateAsync", self._name, key, function(datastoreEntry)
      if datastoreEntry == nil then
        entry = Store.newEntry()
      elseif Store.isEntry(datastoreEntry) then
        entry = datastoreEntry
      else
        warn(msg.willMigrate:format(key))
        entry = Store.newEntry()
        entry.data = datastoreEntry
      end

      if
        entry.meta.lock ~= nil
        and not Lock.isAccessible(entry.meta.lock)
      then
        rejectValue = msg.lockedEntry:format(key)
        return nil
      end

      entry.meta.lock = Lock.new()

      if entry.data == nil then
        entry.data = deep(self._defaultValue)
      end

      -- update with the lock
      return entry
    end)

    if rejectValue then
      reject(rejectValue)
    else
      resolve(entry)
    end
  end)
end

local function writeToStore(storeName, key, modifier)
  key = tostring(key)

  return Promise.new(function(resolve)
    DS.perform("UpdateAsync", storeName, key, function(oldEntry)
      if oldEntry == nil or not Store.isEntry(oldEntry) then
        return modifier(oldEntry)
      end

      if
        oldEntry.meta.lock ~= nil
        and not Lock.isAccessible(oldEntry.meta.lock)
      then
        warn(msg.abandonLockedEntry:format(key))
        return nil
      end

      return modifier(oldEntry)
    end)

    resolve()
  end)
end

-- this is just for DRY
local function prepareEntry(key, entry, oldEntry)
  if oldEntry and oldEntry.meta.version ~= entry.meta.version then
    warn(msg.abandonVersionMismatch:format(
      key,
      entry.meta.version,
      oldEntry.meta.version
    ))
    return
  end

  entry.meta.version += 1
  return entry
end

-- write to an aquired entry in the store
-- incompatible versions / inaccessible locks will not reject,
-- only respects the existing entry in the datastore
-- (key: any, entry: Entry) => Promise<void>
function Store:set(key, entry)
  assert(Store.isEntry(entry), msg.invalidEntry)

  return writeToStore(self._name, key, function(oldEntry)
    local newEntry = prepareEntry(key, entry, oldEntry)
    if not newEntry then
      return
    end

    newEntry.meta.lock = Lock.new()
    return newEntry
  end)
end

-- commit an aquired entry in the store and release the lock
-- (key: any, entry: Entry) => Promise<void>
function Store:commit(key, entry)
  assert(Store.isEntry(entry), msg.invalidEntry)

  return writeToStore(self._name, key, function(oldEntry)
    local newEntry = prepareEntry(key, entry, oldEntry)
    if not newEntry then
      return
    end

    newEntry.meta.lock = nil
    return newEntry
  end)
end

-- update an aquired entry in the store.
-- if the datastore entry is incompatible / nil, the function will
-- receive a new / migrated entry
-- (key: any, fn: (entry: Entry) => Entry?) => Promise<void>
function Store:update(key, fn)
  return writeToStore(self._name, key, function(datastoreEntry)
    if not Store.isEntry(datastoreEntry) then
      local data = datastoreEntry
      datastoreEntry = Store.newEntry()
      datastoreEntry.data = data
    end

    local newEntry = fn(datastoreEntry)

    if newEntry then
      assert(Store.isEntry(newEntry), msg.invalidEntry)
      newEntry.meta.version += 1
      newEntry.meta.lock = Lock.new()
      return newEntry
    end
  end)
end

return Store
