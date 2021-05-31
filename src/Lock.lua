local Lock = {}

Lock.constants = {
  jobId = game.JobId,
  lockExpire = 15 * 60
}

function Lock.new()
  return {
    jobId = Lock.constants.jobId,
    timestamp = os.time(),
  }
end

function Lock.isValid(value)
  return type(value) == "table"
    and type(value.jobId) == "string"
    and type(value.timestamp) == "number"
end

function Lock.isAccessible(lock)
  return Lock.isValid(lock) and (
    lock.jobId == Lock.constants.jobId
    or os.time() - lock.timestamp >= Lock.constants.lockExpire
  )
end

return Lock
