local DataStores = game
  :GetService("ReplicatedStorage")
  :FindFirstChild("MockDataStoreService")
DataStores = DataStores and require(DataStores)
  or game:GetService("DataStoreService")

local DS = {}

-- todo

function DS.perform(methodName, storeName, key, ...)
  local store = DataStores:GetDataStore(storeName)
  store[methodName](store, key, ...)
end

return DS
