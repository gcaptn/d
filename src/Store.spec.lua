local HttpService = game:GetService("HttpService")
local Store = require(script.Parent.Store)
local Lock = require(script.Parent.Lock)
local MockDataStores = require(game.ReplicatedStorage.MockDataStoreService)

return function()
  local store, datastore, testKey

  beforeEach(function()
    testKey = "testkey" .. HttpService:GenerateGUID()
    store = Store.new("test")
    datastore = MockDataStores:GetDataStore("test")
  end)

  describe("Store.new()", function()
    it("throws when constructing without a string name", function()
      expect(Store.new).to.throw()
    end)
  end)

  describe("Store.isValid()", function()
    it("can validate entries", function()
      expect(Store.isEntry(Store.newEntry())).to.equal(true)

      expect(Store.isEntry({
        meta = {
          version = 0,
        },
      })).to.equal(true)

      expect(Store.isEntry()).to.equal(false)

      expect(Store.isEntry({
        meta = {
          version = "",
          lock = Lock.new(),
        },
      })).to.equal(false)

      expect(Store.isEntry({
        meta = {
          version = 0,
          lock = Lock.new(),
        },
      })).to.equal(true)
    end)
  end)

  describe("Store:defaultTo()", function()
    it("sets a deep copy of a value as the default value", function()
      local default = {
        nested = {},
      }

      store:defaultTo(default)
      local storeDefault = store._defaultValue
      expect(storeDefault).never.to.equal(default)
      expect(storeDefault.nested).never.to.equal(default.nested)
    end)
  end)

  describe("Store:load()", function()
    it("loads from the datastore", function()
      local testEntry = Store.newEntry()
      testEntry.data = "testValue"

      datastore:ImportFromJSON({
        [testKey] = testEntry,
      })

      local entry = store:load(testKey):expect()
      expect(entry.data).to.equal("testValue")
    end)

    it("migrates incompatible values from the datastore", function()
      datastore:ImportFromJSON({
        [testKey] = "testValue",
      })
      local entry = store:load(testKey):expect()
      expect(entry.data).to.equal("testValue")
    end)

    it("loads the store's default value when empty", function()
      local default = {
        level = 0,
        items = {
          {
            name = "donut",
            type = "food",
          },
        },
      }

      store:defaultTo(default)
      local entry = store:load(testKey):expect()
      local value = entry.data

      expect(function()
        assert(type(value) == "table")
        assert(value.level == 0)
        assert(type(value.items) == "table")
        assert(type(value.items[1]) == "table")
        assert(value.items[1].name == "donut")
        assert(value.items[1].type == "food")
      end).never.to.throw()

      expect(value).never.to.equal(store._defaultValue)
      expect(value.items).never.to.equal(store._defaultValue.items)
    end)

    it("refuses to load if the lock is inaccessible", function()
      local entry = Store.newEntry()
      local lock = Lock.new()
      lock.jobId = "a"
      entry.meta.lock = lock

      datastore:ImportFromJSON({
        [testKey] = entry,
      })

      local success = store:load(testKey):await()
      expect(success).to.equal(false)
    end)

    it("still loads if the session can access the lock", function()
      local entry = Store.newEntry()
      entry.meta.lock = Lock.new()
      entry.data = "testValue"

      datastore:ImportFromJSON({
        [testKey] = entry,
      })

      local datastoreEntry = store:load(testKey):expect()
      expect(datastoreEntry.data).to.equal("testValue")
    end)

    it("replaces the lock when successful", function()
      local oldEntry = Store.newEntry()
      datastore:ImportFromJSON({
        [testKey] = oldEntry,
      })

      local datastoreEntry = store:load(testKey):expect()
      expect(datastoreEntry.meta.lock).to.be.ok()

      oldEntry = Store.newEntry()
      local lock = Lock.new()
      lock.timestamp -= 10
      oldEntry.meta.lock = lock
      datastore:ImportFromJSON({
        [testKey] = oldEntry,
      })

      datastoreEntry = store:load(testKey):expect()
      expect(datastoreEntry.meta.lock.timestamp > lock.timestamp).to.equal(true)
    end)
  end)

  local function writeToStoreTest(caseFn, writeFunction)
    caseFn("throws when no value is provided", function()
      expect(function()
        writeFunction(testKey)
      end).to.throw()
    end)

    caseFn("will not write to store when the version mismatches", function()
      local correctEntry = Store.newEntry()
      correctEntry.meta.version = 1
      correctEntry.data = "correctEntry"

      datastore:ImportFromJSON({
        [testKey] = correctEntry,
      })

      local wrongEntry = Store.newEntry()
      wrongEntry.meta.version = 0
      wrongEntry.data = "wrongEntry"

      writeFunction(testKey, wrongEntry)
      expect(datastore:GetAsync(testKey).data).to.equal("correctEntry")
    end)

    caseFn("will not write to store if the lock is inaccessible", function()
      local correctEntry = Store.newEntry()
      local usedLock = Lock.new()
      usedLock.jobId = "a"
      correctEntry.meta.lock = usedLock
      correctEntry.data = "correctEntry"

      datastore:ImportFromJSON({
        [testKey] = correctEntry,
      })

      local wrongEntry = Store.newEntry()
      wrongEntry.data = "wrongEntry"

      writeFunction(testKey, wrongEntry)
      expect(datastore:GetAsync(testKey).data).to.equal("correctEntry")
    end)

    caseFn("increments the version number", function()
      local entry = Store.newEntry()

      datastore:ImportFromJSON({
        [testKey] = entry,
      })

      writeFunction(testKey, entry)
      expect(datastore:GetAsync(testKey).meta.version).to.equal(1)
    end)
  end

  describe("Store:set()", function()
    writeToStoreTest(it, function(key, entry)
      store:set(key, entry):expect()
    end)

    it("renews the lock", function()
      local entry = Store.newEntry()
      local oldLock = Lock.new()
      oldLock.timestamp -= 10
      entry.meta.lock = oldLock

      datastore:ImportFromJSON({
        [testKey] = entry,
      })

      store:set(testKey, entry):expect()

      local datastoreEntry = datastore:GetAsync(testKey)

      expect(datastoreEntry.meta.lock).to.be.ok()
      expect(Lock.isAccessible(datastoreEntry.meta.lock)).to.equal(true)
      expect(datastoreEntry.meta.lock.timestamp > oldLock.timestamp).to.equal(true)
    end)
  end)

  describe("Store:commit()", function()
    writeToStoreTest(it, function(key, entry)
      store:commit(key, entry):expect()
    end)

    it("deletes the lock", function()
      local entry = Store.newEntry()
      local oldLock = Lock.new()
      oldLock.timestamp -= 10
      entry.meta.lock = oldLock

      datastore:ImportFromJSON({
        [testKey] = entry,
      })

      store:commit(testKey, entry):expect()
      expect(datastore:GetAsync(testKey).meta.lock).never.to.be.ok()
    end)
  end)

  describe("Store:update()", function()
    it("always passes an entry to the function", function()
      datastore:ImportFromJSON({
        [testKey] = "correctData",
      })

      -- incompatible entries
      store
        :update(testKey, function(previousEntry)
          expect(Store.isEntry(previousEntry)).to.equal(true)
          expect(previousEntry.data).to.equal("correctData")
        end)
        :expect()

      local default = { a = "defaultData" }
      store:defaultTo(default)

      -- nil entries
      store
        :update(testKey .. "1", function(previousEntry)
          expect(previousEntry).to.be.ok()
          expect(Store.isEntry(previousEntry)).to.equal(true)
          expect(previousEntry.data).never.to.equal(default) -- ensure deep copy
          expect(previousEntry.data.a).to.equal("defaultData")
        end)
        :expect()
    end)

    it("updates with the function's value", function()
      local entry = Store.newEntry()
      entry.meta.lock = Lock.new()
      entry.data = "wrongData"

      datastore:ImportFromJSON({
        [testKey] = entry,
      })

      store
        :update(testKey, function(previousEntry)
          expect(previousEntry.data).to.equal("wrongData")
          previousEntry.data = "correctData"
          return previousEntry
        end)
        :expect()

      local datastoreEntry = datastore:GetAsync(testKey)
      expect(datastoreEntry.data).to.equal("correctData")
      expect(datastoreEntry.meta.lock).to.be.ok()
    end)

    it("does not update when the function returns nil", function()
      local entry = Store.newEntry()
      entry.meta.lock = Lock.new()
      entry.data = "correctData"

      datastore:ImportFromJSON({
        [testKey] = entry,
      })

      store
        :update(testKey, function()
        end)
        :expect()

      expect(datastore:GetAsync(testKey).data).to.equal("correctData")
    end)

    it("errors when the entry is invalid", function()
      expect(function()
        store
          :update(testKey, function()
            return false
          end)
          :expect()
      end).to.throw()
    end)
  end)
end
