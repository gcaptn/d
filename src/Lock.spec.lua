local Lock = require(script.Parent.Lock)

return function()
  describe("Lock.isValid()", function()
    it("can validate locks", function()
      expect(Lock.isValid(Lock.new())).to.equal(true)

      expect(Lock.isValid({
        placeId = 0,
        jobId = "",
        timestamp = 0
      })).to.equal(true)

      expect(Lock.isValid({
        placeId = 0,
        jobId = "",
      })).to.equal(false)

      expect(Lock.isValid({
        jobId = "",
        timestamp = 0
      })).to.equal(false)

      expect(Lock.isValid({
        placeId = 0,
        timestamp = 0
      })).to.equal(false)

      expect(Lock.isValid()).to.equal(false)
    end)
  end)

  describe("Lock.isAccessible()", function()
    it("returns false when the value isn't a valid lock", function()
      expect(Lock.isAccessible({
        placeId = 0,
        jobId = "",
      })).to.equal(false)
    end)

    it("returns true when the place and jobId matches the constants", function()
      expect(Lock.isAccessible(Lock.new())).to.equal(true)
    end)

    it("returns false when either the place or jobId mismatches", function()
      local lockWrongJobId = Lock.new()
      lockWrongJobId.jobId = "a"

      expect(Lock.isAccessible(lockWrongJobId)).to.equal(false)

      local lockWrongPlaceId = Lock.new()
      lockWrongPlaceId.placeId = -100

      expect(Lock.isAccessible(lockWrongJobId)).to.equal(false)
    end)

    it("returns true when the lock's timestamp expired", function()
      local lock = Lock.new()

      lock.jobId = "a"
      lock.placeId = -100
      lock.timestamp += Lock.constants.lockExpire * 2

      expect(Lock.isAccessible(lock)).to.equal(false)
    end)
  end)
end
