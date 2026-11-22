-- ArtLibrary lookup contract (CM2-AP). Uses fake nodes, so it runs in Studio and headless.
return function(t)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local ArtLibrary = require(Shared.ArtLibrary)
	local AssetCatalog = require(Shared.AssetCatalog)
	local expect = t.expect

	-- A fake instance with the members ArtLibrary reads.
	local function node(className, attributes, primaryPart)
		local value = { children = {}, PrimaryPart = primaryPart }
		function value:FindFirstChild(name)
			return self.children[name]
		end
		function value:IsA(name)
			return name == className
		end
		function value:GetAttribute(name)
			return attributes and attributes[name]
		end
		return value
	end

	local function tree(leaf)
		local root = node("Folder")
		local folder = node("Folder")
		folder.children.MarketStarter = leaf
		root.children.Buildings = folder
		return root
	end

	t.test("finds a nested path", function()
		local leaf = node("Model")
		local found, code = ArtLibrary.find(tree(leaf), "Buildings/MarketStarter")
		expect.equal(found, leaf)
		expect.equal(code, nil)
	end)

	t.test("reports MissingArtAsset for a nil root or a missing leaf", function()
		local model, code = ArtLibrary.find(nil, "Buildings/MarketStarter")
		expect.equal(model, nil)
		expect.equal(code, "MissingArtAsset")
		model, code = ArtLibrary.find(tree(node("Model")), "Buildings/MarketUpgrade1")
		expect.equal(model, nil)
		expect.equal(code, "MissingArtAsset")
		model, code = ArtLibrary.find(tree(node("Model")), "Props/MarketStarter")
		expect.equal(code, "MissingArtAsset")
	end)

	t.test("reports InvalidArtAsset for a non-Model and a Blender Model without PrimaryPart", function()
		local model, code = ArtLibrary.find(tree(node("Folder")), "Buildings/MarketStarter")
		expect.equal(model, nil)
		expect.equal(code, "InvalidArtAsset")
		model, code = ArtLibrary.find(tree(node("Model", { ArtSource = "blender" })), "Buildings/MarketStarter")
		expect.equal(model, nil)
		expect.equal(code, "InvalidArtAsset")
		local blender = node("Model", { ArtSource = "blender" }, node("Part"))
		expect.equal((ArtLibrary.find(tree(blender), "Buildings/MarketStarter")), blender)
		-- Legacy CC0 models without a PrimaryPart stay accepted.
		local legacy = node("Model")
		expect.equal((ArtLibrary.find(tree(legacy), "Buildings/MarketStarter")), legacy)
	end)

	t.test("rejects malformed art paths", function()
		for _, path in ipairs({ "", "trees/x", "A//B", "../X", "A/", "/A", "A/B/C/D/E", "A B" }) do
			expect.falsy(ArtLibrary.isValidPath(path))
			local model, code = ArtLibrary.find(tree(node("Model")), path)
			expect.equal(model, nil)
			expect.equal(code, "InvalidArtPath")
		end
		expect.truthy(ArtLibrary.isValidPath("Trees/DouglasFir/Medium"))
	end)

	t.test("accepts every AssetCatalog category and ID as an art path", function()
		for category, ids in pairs(AssetCatalog) do
			for _, assetId in pairs(ids) do
				expect.truthy(ArtLibrary.isValidPath(category .. "/" .. assetId))
			end
		end
	end)

	t.test("levelYaw snaps a part's yaw to the nearest half turn", function()
		local function rv(deg)
			return math.cos(math.rad(deg)), -math.sin(math.rad(deg))
		end
		for _, case in ipairs({ { -44.4, 44.4 }, { 135.6, 44.4 }, { 0, 0 }, { 180, 0 }, { -170, -10 }, { 100, 80 } }) do
			local degrees = math.deg(ArtLibrary.levelYaw(rv(case[1])))
			expect.truthy(math.abs(degrees - case[2]) < 1e-6)
		end
		expect.equal(ArtLibrary.levelYaw(0, 0), 0)
	end)
end
