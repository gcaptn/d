local Promise = require(script.Parent.Promise)
local DS = require(script.Parent.DataStoreInterface)
local Lock = require(script.Parent.Lock)

local Store = {}
Store.__index = Store

local msg = {
  newStoreNameString = "Cannot construct a store without a string name!",
  invalidEntry = "Value is not a valid entry!",
  lockedEntry = function(key)
    return ("Entry %s is currently used in another session!"):format(key)
  end,
  abandonVersionMismatch = function(key, entryIndex, datastoreEntryIndex)
    return ("Entry %s is at version %i while its datastore entry is at version %i. The datastore entry will be used instead.")
      :format(key, entryIndex, datastoreEntryIndex)
  end,
  abandonLockedEntry = function(key)
    return ("Entry %s is currently used in another session. The datastore version will be used instead."):format(key)
  end,
  willMigrate = function(key)
    return ("Found an incompatible entry at datastore key %s. Data will be migrated.")
      :format(key)
  end,
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

function Store.newEntry()
  return {
    meta = {
      version = 0
    }
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

function Store:load(key)
  key = tostring(key)

  return Promise.new(function(resolve, reject)
    local rejectValue, entry

    DS.Update(self._name, key, function(datastoreEntry)
      if datastoreEntry == nil then
        entry = Store.newEntry()
      elseif Store.isEntry(datastoreEntry) then
        entry = datastoreEntry
      else
        warn(msg.willMigrate(key))
        entry = Store.newEntry()
        entry.data = datastoreEntry
      end

      if entry.meta.lock ~= nil and not Lock.isAccessible(entry.meta.lock) then
        rejectValue = msg.lockedEntry(key)
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

local function writeToStore(storeName, key, entry, modifier)
  assert(Store.isEntry(entry), msg.invalidEntry)
  key = tostring(key)
  
  return Promise.new(function(resolve)
    DS.Update(storeName, key, function(oldEntry)
      if oldEntry == nil or not Store.isEntry(oldEntry) then
        return modifier(entry)
      end

      if oldEntry.meta.version ~= entry.meta.version then
        warn(msg.abandonVersionMismatch(
          key,
          entry.meta.version,
          oldEntry.meta.version
        ))
        return nil
      end

      if oldEntry.meta.lock ~= nil and not Lock.isAccessible(oldEntry.meta.lock) then
        warn(msg.abandonLockedEntry(key))
        return nil
      end

      return modifier(entry)
    end)

    resolve()
  end)
end

function Store:write(key, entry)
  return writeToStore(self._name, key, entry, function(entry)
    entry.meta.version += 1
    entry.meta.lock = Lock.new()
    return entry
  end)
end

function Store:commit(key, entry)
  return writeToStore(self._name, key, entry, function(entry)
    entry.meta.version += 1
    entry.meta.lock = nil
    return entry
  end)
end

return Store
