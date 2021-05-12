local DataStores = game:GetService("ReplicatedStorage"):FindFirstChild("MockDataStoreService")
DataStores = DataStores
  and require(DataStores)
  or game:GetService("DataStoreService")

local DS = {}

-- todo

function DS.Get(storeName, key)
  local store = DataStores:GetDataStore(storeName)
  return store:GetAsync(key)
end

function DS.Update(storeName, key, fn)
  local store = DataStores:GetDataStore(storeName)
  store:UpdateAsync(key, fn)
end

return DS
