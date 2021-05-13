local Store = require(script.Parent.Store)
local MockDataStores = require(game.ReplicatedStorage.MockDataStoreService)

return function()
  describe("Stores", function()
    local store, datastore

    beforeEach(function()
      store = Store.new("test")
      -- todo: find a way to clear entire datastore
      MockDataStores:ImportFromJSON("{ \"DataStore\": {} }")
      datastore = MockDataStores:GetDataStore("test")
    end)

    it("can validate entries", function()
      expect(Store.isEntry({
        _meta = {
          version = 0
        }
      })).to.equal(true)

      expect(Store.isEntry()).to.equal(false)

      expect(Store.isEntry({
        _meta = {
          version = ""
        }
      })).to.equal(false)
    end)

    it("throws when constructing without a string name", function()
      expect(Store.new).to.throw()
    end)

    describe("load", function()
      it("gets from the active entries first", function()
        store._loadedEntries["testKey"] = {
          _data = "testValue"
        }
        local _, storeValue = store:load("testKey"):await()
        expect(storeValue).to.equal("testValue")
      end)

      it("loads from the datastore when there are no active entries found", function()
        datastore:ImportFromJSON({
          testKey = {
            _meta = { version = 0 },
            _data = "testValue"
          }
        })
        local _, storeValue = store:load("testKey"):await()
        expect(storeValue).to.equal("testValue")
      end)

      it("migrates incompatible values from the datastore", function()
        datastore:ImportFromJSON({
          testKey = "testValue"
        })
        local _, storeValue = store:load("testKey"):await()
        expect(storeValue).to.equal("testValue")
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
        local _, storeValue = store:load("emptyKey"):await()

        expect(function()
          assert(type(storeValue) == "table")
          assert(storeValue.level == 0)
          assert(type(storeValue.items) == "table")
          assert(type(storeValue.items[1]) == "table")
          assert(storeValue.items[1].name == "donut")
          assert(storeValue.items[1].type == "food")
        end).never.to.throw()
        expect(storeValue).never.to.equal(store._defaultValue)
        expect(storeValue.items).never.to.equal(store._defaultValue.items)
      end)
    end)

    describe("defaultTo", function()
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

    describe("set", function()
      it("throws when an entry has never been loaded", function()
        expect(function()
          store:set("testKey", "testValue")
        end).to.throw()
      end)

      it("only modifies the \"data\" key in the entry", function()
        store._loadedEntries["testKey"] = {
          _meta = { version = 0 }
        }
        store:set("testKey", "testValue")
        expect(store._loadedEntries["testKey"]._data).to.equal("testValue")
      end)
    end)

    describe("commit", function()
      it("throws when an entry has never been retrieved", function()
        expect(function()
          store:commit("testKey")
        end).to.throw()
      end)

      it("will not write to store when the version mismatches", function()
        datastore:ImportFromJSON({
          testKey = {
            _meta = { version = 1 },
            _data = "correctEntry"
          }
        })

        store._loadedEntries["testKey"] = {
          _meta = { version = 0 },
          _data = "wrongEntry"
        }

        store:commit("testKey"):await()
        expect(datastore:GetAsync("testKey")._data).to.equal("correctEntry")
      end)

      it("removes an entry from the active entries when successful", function()
        local entry = {
          _meta = { version = 0 }
        }

        datastore:ImportFromJSON({
          testKey = entry
        })

        store._loadedEntries["testKey"] = entry

        store:commit("testKey"):await()
        expect(store._loadedEntries["testKey"]).never.to.be.ok()
      end)
    end)

    describe("commitAll", function()
      it("commits every entry to the datastore", function()
        local expected = {
          testKey1 = { _meta = { version = 1 } },
          testKey2 = { _meta = { version = 1 } },
          testKey3 = { _meta = { version = 1 } },
          testKey4 = { _meta = { version = 1 } }
        }

        store._loadedEntries = {
          testKey1 = { _meta = { version = 0 } },
          testKey2 = { _meta = { version = 0 } },
          testKey3 = { _meta = { version = 0 } },
          testKey4 = { _meta = { version = 0 } }
        }

        datastore:ImportFromJSON(store._loadedEntries)

        local s = store:commitAll():await()
        expect(s).to.equal(true)

        for key, _ in pairs(expected) do
          expect(datastore:GetAsync(key)._meta.version)
            .to.equal(expected[key]._meta.version)
        end
      end)
    end)
  end)
end
