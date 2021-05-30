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
    end)

    it("throws when constructing without a string name", function()
      expect(Store.new).to.throw()
    end)

    describe("load", function()
      it("loads from the datastore", function()
        datastore:ImportFromJSON({
          testKey = {
            meta = { version = 0 },
            data = "testValue"
          }
        })
        local _, entry = store:load("testKey"):await()
        expect(entry.data).to.equal("testValue")
      end)

      it("migrates incompatible values from the datastore", function()
        datastore:ImportFromJSON({
          testKey = "testValue"
        })
        local _, entry = store:load("testKey"):await()
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
        local _, entry = store:load("emptyKey"):await()
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

    describe("commit", function()
      it("throws when no value is provided", function()
        expect(function()
          store:commit("testKey")
        end).to.throw()
      end)

      it("will not write to store when the version mismatches", function()
        datastore:ImportFromJSON({
          testKey = {
            meta = { version = 1 },
            data = "correctEntry"
          }
        })

        local entry = {
          meta = { version = 0 },
          data = "wrongEntry"
        }

        store:commit("testKey", entry):await()
        expect(datastore:GetAsync("testKey").data).to.equal("correctEntry")
      end)
    end)
  end)
end
