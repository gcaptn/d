local D = require(script.Parent)

return function()
  describe("D", function()
    it("returns a cached store", function()
      local store = D.LoadStore("test")
      local store2 = D.LoadStore("test")
      expect(store).to.equal(store2)
    end)
  end)
end
