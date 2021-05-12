local Store = require(script.Store)
local D = {}

local loadedStores = {}

function D.LoadStore(storeName)
  local store = loadedStores[storeName]
  if not store then
    store = Store.new(storeName)
    loadedStores[storeName] = store
  end
  return store
end

return D
