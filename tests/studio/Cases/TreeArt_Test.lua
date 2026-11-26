-- Tree art roles, paths, scales and label maths (CM2-12W). Uses fake nodes, so it runs in Studio
-- and headless.
return function(t)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local ArtLibrary = require(Shared.ArtLibrary)
	local GameConfig = require(Shared.GameConfig)
	local TreeArt = require(Shared.TreeArt)
	local UiTheme = require(Shared.UiTheme)
	local expect = t.expect

	local function near(actual, expected)
		expect.truthy(math.abs(actual - expected) < 1e-9)
	end

	-- A fake instance with the members ArtLibrary.find reads.
	local function node(className)
		local value = { children = {} }
		function value:FindFirstChild(name)
			return self.children[name]
		end
		function value:IsA(name)
			return name == className
		end
		function value:GetAttribute()
			return nil
		end
		return value
	end

	-- A fake ArtAssets root holding Trees/<species>/<size> for the given paths ("Trees/A/B").
	local function rootWith(paths)
		local root = node("Folder")
		local leaves = {}
		for _, artPath in ipairs(paths) do
			local _, species, size = string.match(artPath, "^(%u%w*)/(%u%w*)/(%u%w*)$")
			root.children.Trees = root.children.Trees or node("Folder")
			local speciesFolder = root.children.Trees.children[species] or node("Folder")
			root.children.Trees.children[species] = speciesFolder
			local leaf = node("Model")
			speciesFolder.children[size] = leaf
			leaves[artPath] = leaf
		end
		return root, leaves
	end

	local function allPaths()
		local paths = {}
		for speciesId in pairs(GameConfig.Trees) do
			for _, sizeId in ipairs(TreeArt.SIZES) do
				table.insert(paths, "Trees/" .. speciesId .. "/" .. sizeId)
			end
		end
		return paths
	end

	t.test("builds tree art paths and falls back for bad species or size", function()
		expect.equal(TreeArt.path("BlueSpruce", "Small"), "Trees/BlueSpruce/Small")
		expect.equal(TreeArt.path(nil, "Large"), "Trees/DouglasFir/Large")
		expect.equal(TreeArt.path("blue spruce", "Huge"), "Trees/DouglasFir/Medium")
		for speciesId in pairs(GameConfig.Trees) do
			for _, sizeId in ipairs(TreeArt.SIZES) do
				expect.truthy(ArtLibrary.isValidPath(TreeArt.path(speciesId, sizeId)))
			end
		end
	end)

	t.test("uses art for every role when the library has the path", function()
		local root, leaves = rootWith(allPaths())
		local checked = 0
		for speciesId in pairs(GameConfig.Trees) do
			for _, sizeId in ipairs(TreeArt.SIZES) do
				for _, role in ipairs(TreeArt.ROLES) do
					local choice = TreeArt.choose(root, ArtLibrary.find, role, speciesId, sizeId)
					expect.equal(choice.mode, "Art")
					expect.equal(choice.code, nil)
					expect.equal(choice.role, role)
					expect.equal(choice.template, leaves[choice.path])
					expect.equal(choice.path, "Trees/" .. speciesId .. "/" .. sizeId)
					checked += 1
				end
			end
		end
		expect.equal(checked, 5 * 12)
	end)

	t.test("falls back to the primitive for every role without art", function()
		for _, role in ipairs(TreeArt.ROLES) do
			local choice = TreeArt.choose(nil, ArtLibrary.find, role, "DouglasFir", "Large")
			expect.equal(choice.mode, "Primitive")
			expect.equal(choice.code, "MissingArtAsset")
			expect.equal(choice.template, nil)
			expect.equal(choice.primitiveScale, TreeArt.primitiveScale(role, "Large"))
		end
		local root, leaves = rootWith({ "Trees/BlueSpruce/Large" })
		local art = TreeArt.choose(root, ArtLibrary.find, "Display", "BlueSpruce", "Large")
		expect.equal(art.mode, "Art")
		expect.equal(art.template, leaves["Trees/BlueSpruce/Large"])
		expect.equal(art.primitiveScale, 1.0)
		local primitive = TreeArt.choose(root, ArtLibrary.find, "Display", "DouglasFir", "Large")
		expect.equal(primitive.mode, "Primitive")
		expect.equal(primitive.code, "MissingArtAsset")
		expect.equal(primitive.primitiveScale, 1.0)
	end)

	t.test("keeps today's primitive scales and sizes art to match", function()
		local expected = {
			Display = { Small = 0.6, Medium = 0.8, Large = 1.0 },
			Pickup = { Small = 0.6, Medium = 0.8, Large = 1.0 },
			Carried = { Small = 0.4, Medium = 0.4, Large = 0.4 },
			NpcCarried = { Small = 0.35, Medium = 0.4, Large = 0.45 },
			Roof = { Small = 0.35, Medium = 0.35, Large = 0.35 },
		}
		for role, scales in pairs(expected) do
			for sizeId, scale in pairs(scales) do
				expect.equal(TreeArt.PRIMITIVE_SCALES[role][sizeId], scale)
				expect.equal(TreeArt.primitiveScale(role, sizeId), scale)
			end
		end
		expect.equal(TreeArt.primitiveScale("Display", "Huge"), 0.8)
		expect.equal(TreeArt.artScale("Display", "Large", 10), 1)
		expect.equal(TreeArt.artScale("Pickup", "Small", 6), 1)
		near(TreeArt.artScale("Carried", "Small", 10), 0.46)
		near(TreeArt.artScale("Roof", "Large", 10), 0.4025)
		expect.equal(TreeArt.artScale("NpcCarried", "Large", 0), 1)
		expect.equal(TreeArt.artScale("NpcCarried", "Large", 0 / 0), 1)
		expect.equal(TreeArt.artScale("NpcCarried", "Large", math.huge), 1)
		expect.throws(function()
			TreeArt.primitiveScale("Nope", "Small")
		end)
		expect.throws(function()
			TreeArt.artScale("Nope", "Small", 10)
		end)
		expect.throws(function()
			TreeArt.pivotDrop("Nope", "Small")
		end)
		expect.throws(function()
			TreeArt.choose(nil, ArtLibrary.find, "Nope", "DouglasFir", "Small")
		end)
	end)

	t.test("puts every label above the tree top for each role, size and mode", function()
		local artTops = { Small = 6, Medium = 8, Large = 10 }
		for role, layoutId in pairs(TreeArt.LABEL_LAYOUTS) do
			local clearance = UiTheme.WorldLabels[layoutId].height
			local staggers = { 0 }
			if role == "Pickup" then
				table.insert(staggers, UiTheme.WorldLabels.PickupOrder.stagger)
			end
			for _, sizeId in ipairs(TreeArt.SIZES) do
				local scale = TreeArt.primitiveScale(role, sizeId)
				for _, stagger in ipairs(staggers) do
					-- Primitive: top 11.5 s, adornee (Trunk centre) 2.5 s.
					local top, adornee = TreeArt.PRIMITIVE_TOP * scale, TreeArt.PRIMITIVE_PIVOT * scale
					local offset = TreeArt.labelOffset(top, adornee, clearance, stagger)
					expect.truthy(adornee + offset >= top + 0.9)
					-- Art: top 6/8/10, adornee (ArtRoot) at the foot.
					offset = TreeArt.labelOffset(artTops[sizeId], 0, clearance, stagger)
					expect.truthy(0 + offset >= artTops[sizeId] + 0.9)
				end
			end
		end
		expect.equal(TreeArt.LABEL_LAYOUTS.Carried, nil)
		expect.equal(TreeArt.LABEL_LAYOUTS.NpcCarried, nil)
		expect.equal(TreeArt.LABEL_LAYOUTS.Roof, nil)
	end)

	t.test("drops the art foot to the primitive's foot when carried", function()
		near(TreeArt.pivotDrop("Carried", "Large"), 1.0)
		near(TreeArt.pivotDrop("NpcCarried", "Small"), 0.875)
	end)
end
