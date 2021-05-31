local DataStores = game
  :GetService("ReplicatedStorage")
  :FindFirstChild("MockDataStoreService")
DataStores = DataStores and require(DataStores)
  or game:GetService("DataStoreService")

local DS = {}

-- todo

function DS.perform(task, storeName, key, fn)
  local store = DataStores:GetDataStore(storeName)
  store[task](store, key, fn)
end

return DS
