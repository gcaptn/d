local D = require(script.Parent)

return function()
  describe("D", function()
    describe("loadStore", function()
      it("returns a cached store", function()
        local store = D.loadStore("test")
        local store2 = D.loadStore("test")
        expect(store).to.equal(store2)
      end)
    end)
  end)
end
