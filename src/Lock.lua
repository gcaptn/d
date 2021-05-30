local Lock = {}

Lock.constants = {
  placeId = game.PlaceId,
  jobId = game.JobId,
  lockExpire = 5 * 60
}

function Lock.new()
  return {
    placeId = Lock.constants.placeId,
    jobId = Lock.constants.jobId,
    timestamp = os.time(),
  }
end

function Lock.isValid(value)
  return type(value) == "table"
    and type(value.placeId) == "number"
    and type(value.jobId) == "string"
    and type(value.timestamp) == "number"
end

function Lock.isAccessible(lock)
  return Lock.isValid(lock) and (
    (
      lock.placeId == Lock.constants.placeId
      and lock.jobId == Lock.constants.jobId
    ) or (
      os.time() - lock.timestamp >= Lock.constants.lockExpire
    )
  )
end

return Lock
