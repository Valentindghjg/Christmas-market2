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

	-- A fake instance with the members hasAssets and root read.
	local function inst(className, name, children)
		local kids = children or {}
		local value = { Name = name, ClassName = className }
		function value:GetChildren()
			return kids
		end
		function value:IsA(c)
			return c == className
		end
		function value:FindFirstChildWhichIsA(c, recursive)
			for _, kid in ipairs(kids) do
				if kid:IsA(c) then
					return kid
				end
				if recursive then
					local deeper = kid:FindFirstChildWhichIsA(c, true)
					if deeper ~= nil then
						return deeper
					end
				end
			end
			return nil
		end
		return value
	end

	local function container(...)
		local value = { kids = { ... } }
		function value:GetChildren()
			return self.kids
		end
		return value
	end

	t.test("root prefers the ArtAssets folder with assets", function()
		local empty = inst("Folder", "ArtAssets")
		local full = inst("Folder", "ArtAssets", { inst("Folder", "Buildings", { inst("Model", "MarketStarter") }) })
		local other = inst("Folder", "Other", { inst("Model", "X") })
		expect.equal(ArtLibrary.root(container(empty, full)), full)
		expect.equal(ArtLibrary.root(container(full, empty)), full)
		expect.equal(ArtLibrary.root(container(other, empty)), empty)
		expect.equal(ArtLibrary.root(container(other)), nil)
		expect.equal(ArtLibrary.root(container()), nil)
		expect.equal(ArtLibrary.root(nil), nil)
	end)

	local function leftoverFolder()
		local kids = {}
		for _, name in ipairs({ "NPCs", "Vehicles", "Trees", "Buildings", "Environment", "Props" }) do
			table.insert(kids, inst("Folder", name))
		end
		return inst("Folder", "ArtAssets", kids)
	end

	t.test("hasAssets counts Models and MeshParts at any depth", function()
		expect.falsy(ArtLibrary.hasAssets(leftoverFolder()))
		expect.falsy(ArtLibrary.hasAssets(inst("Folder", "ArtAssets")))
		expect.truthy(ArtLibrary.hasAssets(inst("Folder", "A", { inst("Folder", "B", { inst("Model", "M") }) })))
		expect.truthy(ArtLibrary.hasAssets(inst("Folder", "A", { inst("MeshPart", "P") })))
		expect.falsy(ArtLibrary.hasAssets(inst("Folder", "A", { inst("Part", "P"), inst("Folder", "F") })))
	end)

	t.test("root skips an ArtAssets folder with only empty subfolders", function()
		local leftover, leftover2 = leftoverFolder(), leftoverFolder()
		local real = inst("Folder", "ArtAssets", { inst("Folder", "Buildings", { inst("Model", "MarketStarter") }) })
		expect.equal(ArtLibrary.root(container(leftover, real)), real)
		expect.equal(ArtLibrary.root(container(real, leftover)), real)
		expect.equal(ArtLibrary.root(container(leftover)), leftover)
		expect.equal(ArtLibrary.root(container(leftover, leftover2)), leftover)
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

	-- CM2-G9a A2: the HQ 1 art shrinks uniformly into the Stand box; art that fits keeps scale 1.
	t.test("fitScale shrinks only oversize art", function()
		expect.truthy(math.abs(ArtLibrary.fitScale(32.42, 24.36, 31.8, 23.8) - 23.8 / 24.36) < 1e-9)
		expect.equal(ArtLibrary.fitScale(18, 14, 31.8, 23.8), 1)
		expect.equal(ArtLibrary.fitScale(64, 12, 32, 24), 0.5)
		expect.equal(ArtLibrary.fitScale(0, 14, 31.8, 23.8), 1)
		expect.equal(ArtLibrary.fitScale(0 / 0, 14, 31.8, 23.8), 1)
	end)
end
