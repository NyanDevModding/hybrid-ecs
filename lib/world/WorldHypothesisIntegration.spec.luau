local WorldFactory  = require(script.Parent.WorldFactory)
local Component = require(script.Parent.Parent.component.Component)
local WorldHypothesis = require(script.Parent.hypothesis.WorldHypothesis)
local WorldHypothesisMerger = require(script.Parent.hypothesis.WorldHypothesisMerger)

-- describe the manner the system world-hypothesis should work (with the help
-- of the merger)

return function ()
    local testWorld

    local SOME_COMPONENT = Component.new("some")
    local OTHER_COMPONENT = Component.new("other")

    beforeEach(function()
        testWorld = WorldFactory.createWorld(nil, false)
    end)

    describe("World-Hypothesis integration", function()
        describe("world changes listened to by hypothesis", function()
            it("should call the hypothesis' method if it is listening", function()
                -- changes are performed in the hypothesis and the it,
                -- while listening, should totally alter the behaviour of world
                -- to take the functions calls for the world
                testWorld:spawnAt(1, {SOME_COMPONENT()})
                testWorld:spawnAt(2, {SOME_COMPONENT()})
                testWorld:spawnAt(3, {SOME_COMPONENT(), OTHER_COMPONENT()})

                local testMerger = WorldHypothesisMerger.new(testWorld)
                local testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                -- start listening
                testWorld:openHypothesis(testHypothesis)

                testWorld:spawnAt(4, {SOME_COMPONENT()})
                testWorld:spawn({SOME_COMPONENT()}) -- at #5
                testWorld:insert(2, OTHER_COMPONENT())
                testWorld:remove(3, SOME_COMPONENT)
                testWorld:despawn(1)

                expect(testWorld:contains(1)).to.be.equal(false)
                expect(testWorld:getComponent(2, OTHER_COMPONENT)).to.be.ok()
                expect(testWorld:getComponent(3, SOME_COMPONENT)).never.to.be.ok()
                expect(testWorld:contains(4)).to.be.equal(true)
                expect(testWorld:contains(5)).to.be.equal(true)

                -- stop listening / abort the hypothesis
                testWorld:closeHypothesis()

                -- every expectation made earlier should now be the opposite
                expect(testWorld:contains(1)).to.be.equal(true)
                expect(testWorld:getComponent(2, OTHER_COMPONENT)).never.to.be.ok()
                expect(testWorld:getComponent(3, SOME_COMPONENT)).to.be.ok()
                expect(testWorld:contains(4)).to.be.equal(false)
                expect(testWorld:contains(5)).to.be.equal(false)
            end)
            it("should allow a stack of hypothesis (nested queries)", function()
                local testMerger = WorldHypothesisMerger.new(testWorld)

                local firstHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
                testWorld:openHypothesis(firstHypothesis)
                testWorld:spawnAt(1, {SOME_COMPONENT()})
                expect(firstHypothesis:contains(1)).to.be.equal(true)

                local secondHypothesis = WorldHypothesis.new(firstHypothesis, testMerger)
                testWorld:openHypothesis(secondHypothesis)
                testWorld:spawnAt(2, {SOME_COMPONENT()})
                expect(secondHypothesis:contains(1)).to.be.equal(true)
                expect(secondHypothesis:contains(2)).to.be.equal(true)
                expect(firstHypothesis:contains(2)).to.be.equal(false)

                local thirdHypothesis = WorldHypothesis.new(secondHypothesis, testMerger)
                testWorld:openHypothesis(thirdHypothesis)
                testWorld:spawnAt(3, {SOME_COMPONENT()})
                expect(thirdHypothesis:contains(1)).to.be.equal(true)
                expect(thirdHypothesis:contains(2)).to.be.equal(true)
                expect(thirdHypothesis:contains(3)).to.be.equal(true)
                expect(firstHypothesis:contains(3)).to.be.equal(false)
                expect(secondHypothesis:contains(3)).to.be.equal(false)

                testWorld:closeHypothesis()
                expect(testWorld:contains(3)).to.be.equal(false)
                testWorld:closeHypothesis()
                expect(testWorld:contains(2)).to.be.equal(false)
                testWorld:closeHypothesis()
                expect(testWorld:contains(1)).to.be.equal(false)
            end)
        end)
    end)
end