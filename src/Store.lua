local Promise = require(script.Parent.Promise)
local DS = require(script.Parent.DataStoreInterface)

local Store = {}
Store.__index = Store

local msg = {
  newStoreNameString = function()
    return "Cannot construct a store without a string name!"
  end,
  commitNilValue = function()
    return "Cannot commit a nil value!"
  end,
  versionMismatch = function(key, entryIndex, datastoreEntryIndex)
    return ("Entry %s is at version %i while its datastore entry is at version %i. The datastore entry will be used instead.")
      :format(key, entryIndex, datastoreEntryIndex)
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

local function blankEntry()
  return {
    meta = {
      version = 0
    }
  }
end

function Store.new(name)
  assert(type(name) == "string", msg.newStoreNameString(name))
  
  return setmetatable({
    _name = name,
  }, Store)
end

function Store.isEntry(value)
  return type(value) == "table"
    and type(value.meta) == "table"
    and type(value.meta.version) == "number"
end

function Store:defaultTo(value)
  self._defaultValue = deep(value)
end

function Store:load(key)
  key = tostring(key)

  return Promise.new(function(resolve)
    local entry
    local datastoreEntry = DS.Get(self._name, key)

    if datastoreEntry == nil then
      entry = blankEntry()
    elseif Store.isEntry(datastoreEntry) then
      entry = datastoreEntry
    else
      warn(msg.willMigrate(key))
      entry = blankEntry()
      entry.data = datastoreEntry
    end

    if entry.data == nil then
      entry.data = deep(self._defaultValue)
    end

    resolve(entry)
  end)
end

function Store:commit(key, entry)
  key = tostring(key)

  assert(entry ~= nil, msg.commitNilValue())

  return Promise.new(function(resolve)
    DS.Update(self._name, key, function(oldEntry)
      if oldEntry ~= nil and Store.isEntry(oldEntry) then
        if oldEntry.meta.version == entry.meta.version then
          entry.meta.version += 1
          return entry
        else
          warn(msg.versionMismatch(
            key,
            entry._meta.version,
            oldEntry._meta.version
          ))
          return nil
        end
      else
        return entry
      end
    end)

    resolve()
  end)
end

return Store
