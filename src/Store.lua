local Promise = require(script.Parent.Promise)
local DS = require(script.Parent.DataStoreInterface)

local Store = {}
Store.__index = Store

local msg = {
  newStoreNameString = function()
    return "Cannot construct a store without a string name!"
  end,
  getNotLoaded = function(key)
    return ("Cannot get entry %s because it was not loaded or had just been cleared.")
      :format(key)
  end,
  setNotLoaded = function(key)
    return ("Cannot set entry %s because it was not loaded or had just been cleared.")
      :format(key)
  end,
  commitNotLoaded = function(key)
    return ("Cannot commit entry %s because it was not loaded or had just been cleared.")
      :format(key)
  end,
  versionMismatch = function(key, entryIndex, datastoreEntryIndex)
    return ("Entry %s is at version %i while its datastore entry is at version %i. The datastore entry will be used instead.")
      :format(key, entryIndex, datastoreEntryIndex)
  end,
  willMigrate = function(key)
    return ("Found an incompatible entry at datastore key %s. Data will be migrated.")
      :format(key)
  end
}

local function shallow(value)
  if type(value) == "table" then
    local new = {}
    for i, v in pairs(value) do
      new[i] = v
    end
    return new
  else
    return value
  end
end

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
    _meta = {
      version = 0
    }
  }
end

function Store.new(name)
  assert(type(name) == "string", msg.newStoreNameString(name))
  
  return setmetatable({
    _name = name,
    _loadedEntries = {}
  }, Store)
end

function Store.isEntry(value)
  return type(value) == "table"
    and type(value._meta) == "table"
    and type(value._meta.version) == "number"
end

function Store:get(key)
  key = tostring(key)
  local entry = self._loadedEntries[key]

  if not entry then
    error(msg.getNotLoaded(key))
  end

  return shallow(entry._data)
end

function Store:load(key)
  key = tostring(key)
  local entry = self._loadedEntries[key]

  return Promise.new(function(resolve)
    if entry then
      resolve()
    else
      local datastoreEntry = DS.Get(self._name, key)

      if datastoreEntry == nil then
        entry = blankEntry()
      elseif Store.isEntry(datastoreEntry) then
        entry = datastoreEntry
      else
        warn(msg.willMigrate(key))
        entry = blankEntry()
        entry._data = datastoreEntry
      end

      if entry._data == nil then
        entry._data = deep(self._defaultValue)
      end

      self._loadedEntries[key] = entry
      resolve()
    end
  end)
end

function Store:isLoaded(key)
  key = tostring(key)
  return self._loadedEntries[key] ~= nil
end

function Store:defaultTo(value)
  self._defaultValue = deep(value)
end

function Store:set(key, data)
  key = tostring(key)
  local entry = self._loadedEntries[key];

  if not entry then
    error(msg.setNotLoaded(key), 2)
  end

  entry._data = shallow(data)
end

function Store:clear(key)
  key = tostring(key)
  self._loadedEntries[key] = nil
end

function Store:commit(key)
  key = tostring(key)
  local entry = self._loadedEntries[key];

  if not entry then
    error(msg.commitNotLoaded(key), 2)
  end

  return Promise.new(function(resolve)
    DS.Update(self._name, key, function(oldEntry)
      if oldEntry ~= nil and Store.isEntry(oldEntry) then
        if oldEntry._meta.version == entry._meta.version then
          entry._meta.version += 1
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

    self:clear(key)
    resolve()
  end)
end

function Store:commitAll()
  local promises = {}
  for key, _ in pairs(self._loadedEntries) do
    table.insert(promises, self:commit(key))
  end
  return Promise.all(promises)
end

return Store
