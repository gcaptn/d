local HttpService = game:GetService("HttpService")
local Store = require(script.Parent.Store)
local Lock = require(script.Parent.Lock)
local MockDataStores = require(game.ReplicatedStorage.MockDataStoreService)

return function()
  local store, datastore, testKey

  beforeEach(function()
    testKey = "testkey"..HttpService:GenerateGUID()
    store = Store.new("test")
    datastore = MockDataStores:GetDataStore("test")
  end)

  it("throws when constructing without a string name", function()
    expect(Store.new).to.throw()
  end)

  describe("Store.isValid()", function()
    it("can validate entries", function()
      expect(Store.isEntry(Store.newEntry())).to.equal(true)

      expect(Store.isEntry({
        meta = {
          version = 0
        }
      })).to.equal(true)

      expect(Store.isEntry()).to.equal(false)

      expect(Store.isEntry({
        meta = {
          version = ""
        }
      })).to.equal(false)

      expect(Store.isEntry({
        meta = {
          version = 0,
          lock = Lock.new()
        }
      })).to.equal(true)
    end)
  end)

  describe("Store:defaultTo()", function()
    it("sets a deep copy of a value as the default value", function()
      local default = {
        nested = {}
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
        [testKey] = testEntry
      })

      local _, entry = store:load(testKey):await()
      expect(entry.data).to.equal("testValue")
    end)

    it("migrates incompatible values from the datastore", function()
      datastore:ImportFromJSON({
        [testKey] = "testValue"
      })
      local _, entry = store:load(testKey):await()
      expect(entry.data).to.equal("testValue")
    end)

    it("loads the store's default value when empty", function()
      local default = {
        level = 0,
        items = {
            {
              name = "donut",
              type = "food"
            }
          }
        }

        store:defaultTo(default)
        local _, entry = store:load(testKey):await()
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
          [testKey] = entry
        })

      local success, _ = store:load(testKey):await()
      expect(success).to.equal(false)
    end)

    it("still loads if the session can access the lock", function()
      local entry = Store.newEntry()
      entry.meta.lock = Lock.new()
      entry.data = "testValue"

      datastore:ImportFromJSON({
        [testKey] = entry
      })

      local _, datastoreEntry = store:load(testKey):await()
      expect(datastoreEntry.data).to.equal("testValue")
    end)

    it("replaces the lock when successful", function()
      local oldEntry = Store.newEntry()
      datastore:ImportFromJSON({
        [testKey] = oldEntry
      })

      local _, datastoreEntry = store:load(testKey):await()
      expect(datastoreEntry.meta.lock).to.be.ok()

      oldEntry = Store.newEntry()
      local lock = Lock.new()
      lock.timestamp -= 10
      oldEntry.meta.lock = lock
      datastore:ImportFromJSON({
        [testKey] = oldEntry
      })

      _, datastoreEntry = store:load(testKey):await()
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
        [testKey] = correctEntry
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
        [testKey] = correctEntry
      })

      local wrongEntry = Store.newEntry()
      wrongEntry.data = "wrongEntry"

      writeFunction(testKey, wrongEntry)
      expect(datastore:GetAsync(testKey).data).to.equal("correctEntry")
    end)

    caseFn("increments the version number", function()
      local entry = Store.newEntry()
        
      datastore:ImportFromJSON({
        [testKey] = entry
      })

      writeFunction(testKey, entry)
      expect(datastore:GetAsync(testKey).meta.version).to.equal(1)
    end)
  end

  describe("Store:set()", function()
    writeToStoreTest(it, function(key, entry)
      store:set(key, entry):await()
    end)

    it("renews the lock", function()
      local entry = Store.newEntry()
      local oldLock = Lock.new()
      oldLock.timestamp -= 10
      entry.meta.lock = oldLock

      datastore:ImportFromJSON({
        [testKey] = entry
      })

      store:set(testKey, entry):await()

      local datastoreEntry = datastore:GetAsync(testKey)

      expect(datastoreEntry.meta.lock).to.be.ok()
      expect(Lock.isAccessible(datastoreEntry.meta.lock)).to.equal(true)
      expect(datastoreEntry.meta.lock.timestamp > oldLock.timestamp).to.equal(true)
    end)
  end)

  describe("Store:commit()", function()
    writeToStoreTest(it, function(key, entry)
      store:commit(key, entry):await()
    end)

    it("deletes the lock", function()
      local entry = Store.newEntry()
      local oldLock = Lock.new()
      oldLock.timestamp -= 10
      entry.meta.lock = oldLock

      datastore:ImportFromJSON({
        [testKey] = entry
      })

      store:commit(testKey, entry):await()
      expect(datastore:GetAsync(testKey).meta.lock).never.to.be.ok()
    end)
  end)
end
