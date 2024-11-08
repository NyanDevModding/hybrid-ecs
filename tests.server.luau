local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestEZ = require(ReplicatedStorage.DevPackages.testez)

TestEZ.TestBootstrap:run({
    ReplicatedStorage.hybrid,
    nil,
	{
		noXpcallByDefault = true,
	}
})