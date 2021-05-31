local Players = game:GetService("Players")
local D = require(game:GetService("ReplicatedStorage").D)

local playerEntries = {}
local playerStore = D.loadStore("players")

playerStore:defaultTo({
  schemaVersion = 1,
  coins = 100,
})

local function upgradeSchema(entry)
  if entry.data.schemaVersion == 0 then
    entry.data.coins = 100
  end
  return entry
end

local function onPlayerAdded(player)
  playerStore
    :load(player.UserId)
    :andThen(function(entry)
      playerEntries[player.UserId] = upgradeSchema(entry)
    end)
    :catch(function()
      player:Kick("There was a problem loading your data.")
    end)
end

local function onPlayerRemoving(player)
  local entry = playerEntries[player.UserId]
  if entry then
    playerEntries[player.UserId] = nil
    playerStore:commit(player.UserId, entry):await()
  end
end

for _, player in ipairs(Players:GetPlayers()) do
  onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
