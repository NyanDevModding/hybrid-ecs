local World = require(script.Parent.World)
local WorldProxy = require(script.Parent.WorldProxy)
local DefaultQueryCache = require(script.Parent.query_cache.DefaultQueryCache)

local WorldInterfaceModule = require(script.Parent.WorldInterface)
local QueryCacheInterfaceModule = require(script.Parent.query_cache.QueryCacheInterface)
local IdProviderInterfaceModule = require(script.Parent.id_provider.IdProviderInterface)

type WorldInterface = WorldInterfaceModule.WorldInterface
type QueryCacheInterface = QueryCacheInterfaceModule.QueryCacheInterface
type IdProviderInterface = IdProviderInterfaceModule.IdProviderInterface

local WorldFactory = {}

--[=[
    @within WorldFactory
    @function createWorld
    @param chunkSize number -- the size of a world chunk
    @param queryCache  QueryCacheInterface -- the query cache to use for the
    world, set to false to use no queryCache
    @param idProvider IdProviderInterface -- the id provider to use for the
    world
    @return WorldInterface -- the world

    Create a World proxified, suited for use in systems or anywhere outside
    the library.
]=]
function WorldFactory.createWorld(chunkSize : number, queryCache : (QueryCacheInterface | false)?, idProvider : IdProviderInterface?) : WorldInterface
    return WorldProxy.new(
        World.new(
            chunkSize,
            (
                if queryCache == nil then
                    DefaultQueryCache.new()
                elseif queryCache ~= false then
                    queryCache
                else
                    nil
            ),
            idProvider
        )
    )
end

return WorldFactory