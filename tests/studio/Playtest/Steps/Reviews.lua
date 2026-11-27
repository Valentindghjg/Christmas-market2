--!strict
-- Playtest steps 42 and 43 (full mode): customer reviews, the lot sign and lot likes (CM2-G15).
-- Installed by RunPlaytest.execute after Steps/Checkout (it uses ensureDouglas from Steps/Npc).
-- Step details (moved from docs/TEST_PLAN.md, CM2-FAST):
-- `42 REVIEW_SIGN` (CM2-G15: every plot has `LotSign.Board`; R's board centre in the lot frame is
-- (23, 23) ± 0.1; on every plot the sign parts (`Post_L`, `Post_R`, `Board`, `Cap`) lie inside
-- `Sign`, the plot has `#Placement.DecorFences` `DecorFence` models and no `DecorFence` part
-- overlaps it (the detail reports the smallest `fence gap`); no displayed tree of R inside that
-- box; open orders expire first; a visit of profile 8 loaded at once gives reputation +9 and
-- `reviewCount` +1, and within 2 s `SignFront.Frame.Rating` shows the snapshot's `ReviewCount` and
-- `RatingTenths`; a second visit loaded after `advance(80)` gives +4 (2 stars, less than 9);
-- `reviewsRecent` gains the 5 (then the 2) at its end, trimmed to `RatingWindow`, `ratingTenths`
-- equals its rounded mean and the sign follows within 2 s; the window length is min(`reviewCount`,
-- 50); after `rejoin` `reviewCount`, `ratingTenths`, `likes` and `reviewsRecent` are unchanged and
-- the sign shows them again within 2 s; the sign's `NameSource` is `Filtered` (non-empty text) or
-- `Owner` (text "<player name>'s Tree Lot")), `43 LOT_LIKE` (CM2-G15: `resetLikes` on S; at S's
-- sign R's `Lot.Like` returns ok with `data.likes` = S likes + 1 and S's sign `Likes` attribute
-- follows within 2 s; a second like is `AlreadyLikedToday` with likes unchanged; at R's own sign
-- `OwnLot`; from R's counter a like of S is `OutOfReach`)
return function(ctx: any)
	local GameConfig = ctx.GameConfig
	local R = ctx.R
	local ReplicatedStorage = ctx.ReplicatedStorage
	local S = ctx.S
	local act = ctx.act
	local addStep = ctx.addStep
	local advance = ctx.advance
	local call = ctx.call
	local rejoin = ctx.rejoin
	local check = ctx.check
	local counterPart = ctx.counterPart
	local ensureDouglas = ctx.ensureDouglas
	local expireOrders = ctx.expireOrders
	local hasObject = ctx.hasObject
	local orderPart = ctx.orderPart
	local plotFolder = ctx.plotFolder
	local poll = ctx.poll
	local prompt = ctx.prompt
	local realPlayer = ctx.realPlayer
	local snap = ctx.snap
	local teleport = ctx.teleport
	local visit = ctx.visit
	local Reviews = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reviews")) :: any
	local Stocking = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Stocking")) :: any

	local ReputationByStars = GameConfig.Reviews.ReputationByStars

	local function signBoard(plotId: string?): BasePart
		local plot = plotFolder(plotId)
		local sign = plot and plot:FindFirstChild("LotSign")
		local board = sign and sign:FindFirstChild("Board")
		check(board ~= nil and board:IsA("BasePart"), "LotSign.Board missing on " .. tostring(plotId))
		return board :: BasePart
	end

	-- A TextLabel on the front face of a plot's sign: "Name", "Rating" or "Likes".
	local function signLabel(plotId: string?, name: string): TextLabel
		local face = signBoard(plotId):FindFirstChild("SignFront")
		local frame = face and face:FindFirstChild("Frame")
		local label = frame and frame:FindFirstChild(name)
		check(label ~= nil and label:IsA("TextLabel"), "SignFront.Frame." .. name .. " missing on " .. tostring(plotId))
		return label :: TextLabel
	end

	local function signKeepClear(): any
		for _, box in GameConfig.Placement.KeepClear do
			if box.id == "Sign" then
				return box
			end
		end
		check(false, "KeepClear box Sign missing")
		return nil
	end

	-- Lot-frame bounds {minX, maxX, minZ, maxZ} of a part on a plot (default R's).
	local function lotBounds(part: BasePart, plotId: string?): (number, number, number, number)
		local id = plotId or R.plotId
		local plot = plotFolder(id)
		check(
			plot ~= nil and plot:IsA("Model") and plot.PrimaryPart ~= nil,
			"plot " .. tostring(id) .. " has no PrimaryPart"
		)
		local center = ((plot :: Model).PrimaryPart :: BasePart).Position
		local facing = Stocking.facing(center.Z)
		local cf, half = part.CFrame, part.Size / 2
		local ex = math.abs(cf.RightVector.X) * half.X
			+ math.abs(cf.UpVector.X) * half.Y
			+ math.abs(cf.LookVector.X) * half.Z
		local ez = math.abs(cf.RightVector.Z) * half.X
			+ math.abs(cf.UpVector.Z) * half.Y
			+ math.abs(cf.LookVector.Z) * half.Z
		local x = part.Position.X - center.X
		local z = (part.Position.Z - center.Z) * facing
		return x - ex, x + ex, z - ez, z + ez
	end

	-- CM2-G15 Amendment 2: the review window after one more review, trimmed to RatingWindow.
	local function appended(recent: { number }, stars: number): { number }
		local list = table.clone(recent)
		table.insert(list, stars)
		while #list > GameConfig.Reviews.RatingWindow do
			table.remove(list, 1)
		end
		return list
	end

	local function sameList(a: { number }, b: { number }): boolean
		if #a ~= #b then
			return false
		end
		for index = 1, #a do
			if a[index] ~= b[index] then
				return false
			end
		end
		return true
	end

	local function listText(list: { number }): string
		return table.concat(list, ",")
	end

	-- The rounded mean of the window in tenths, computed here (not by Reviews.ratingTenths).
	local function meanTenths(recent: { number }): number?
		if #recent == 0 then
			return nil
		end
		local sum = 0
		for _, stars in recent do
			sum += stars
		end
		return math.floor(sum * 10 / #recent + 0.5)
	end

	-- The window gained `stars` at its end and the rating is the window's mean.
	local function checkWindow(prefix: string, before: any, after: any, stars: number)
		local expected = appended(before.reviewsRecent, stars)
		check(
			sameList(after.reviewsRecent, expected),
			string.format("%srecent %s, expected %s", prefix, listText(after.reviewsRecent), listText(expected))
		)
		check(
			after.ratingTenths == meanTenths(after.reviewsRecent),
			string.format(
				"%srating %s, mean of recent %s",
				prefix,
				tostring(after.ratingTenths),
				tostring(meanTenths(after.reviewsRecent))
			)
		)
	end

	-- The sign's rating line shows the snapshot's review count and rating within 2 s.
	local function signShowsRating(snapshot: any): boolean
		return poll(function()
			local rating = signLabel(R.plotId, "Rating")
			return rating:GetAttribute("ReviewCount") == snapshot.reviewCount
				and rating:GetAttribute("RatingTenths") == snapshot.ratingTenths
		end, 2)
	end

	-- Sells one tree to profile 8 and carries it; returns the order number.
	local function soldAndCarried(): number
		ensureDouglas(1)
		local number = visit(R.userId, 8)
		local ready = poll(function()
			return hasObject(R.plotId, "PickupTree_" .. number) and hasObject(R.plotId, "CustomerCar_" .. number)
		end, 3)
		check(ready, "pickup tree or car for #" .. number .. " missing within 3 s")
		teleport(orderPart(R.plotId, "PickupTree_" .. number))
		prompt("carry", number)
		return number
	end

	local function loadAt(number: number)
		teleport(orderPart(R.plotId, "CustomerCar_" .. number))
		prompt("load", number)
	end

	local function reviewSignStep(): string?
		-- 1. Geometry: every plot has a board; R's sits at the configured spot inside its box.
		for _, plotId in GameConfig.PersonalPlotIds do
			signBoard(plotId)
		end
		local box = signKeepClear()
		local board = signBoard(R.plotId)
		local bMinX, bMaxX, bMinZ, bMaxZ = lotBounds(board)
		local bx, bz = (bMinX + bMaxX) / 2, (bMinZ + bMaxZ) / 2
		check(
			math.abs(bx - GameConfig.Reviews.SignX) <= 0.1 and math.abs(bz - GameConfig.Reviews.SignZ) <= 0.1,
			string.format("board centre (%.2f, %.2f) in the lot frame", bx, bz)
		)
		-- Amendment 1: on every plot the sign parts lie inside KeepClear Sign and no part of a
		-- decorative DecorFence overlaps it.
		local fenceGap = math.huge
		for _, plotId in GameConfig.PersonalPlotIds do
			local sign = signBoard(plotId).Parent :: Instance
			for _, name in { "Post_L", "Post_R", "Board", "Cap" } do
				local part = sign:FindFirstChild(name)
				check(part ~= nil and part:IsA("BasePart"), plotId .. " LotSign." .. name .. " missing")
				local minX, maxX, minZ, maxZ = lotBounds(part :: BasePart, plotId)
				check(
					minX >= box.minX and maxX <= box.maxX and minZ >= box.minZ and maxZ <= box.maxZ,
					string.format(
						"%s LotSign.%s x %.2f..%.2f z %.2f..%.2f outside KeepClear Sign",
						plotId,
						name,
						minX,
						maxX,
						minZ,
						maxZ
					)
				)
			end
			local plot = plotFolder(plotId) :: Instance
			local fences = {}
			for _, child in plot:GetChildren() do
				if child:IsA("Model") and child.Name == "DecorFence" then
					table.insert(fences, child)
				end
			end
			check(
				#fences == #GameConfig.Placement.DecorFences,
				string.format(
					"plot %s has %d DecorFence, expected %d",
					plotId,
					#fences,
					#GameConfig.Placement.DecorFences
				)
			)
			for _, fence in fences do
				for _, descendant in fence:GetDescendants() do
					if descendant:IsA("BasePart") then
						local minX, maxX, minZ, maxZ = lotBounds(descendant, plotId)
						check(
							not (minX < box.maxX and box.minX < maxX and minZ < box.maxZ and box.minZ < maxZ),
							string.format(
								"%s DecorFence.%s x %.2f..%.2f z %.2f..%.2f overlaps KeepClear Sign",
								plotId,
								descendant.Name,
								minX,
								maxX,
								minZ,
								maxZ
							)
						)
						local dx = math.max(0, box.minX - maxX, minX - box.maxX)
						local dz = math.max(0, box.minZ - maxZ, minZ - box.maxZ)
						fenceGap = math.min(fenceGap, math.sqrt(dx * dx + dz * dz))
					end
				end
			end
		end
		for _, placement in snap(R.userId).placements do
			local x, z = placement.x, placement.z
			if type(x) == "number" and type(z) == "number" then
				check(
					not (x >= box.minX and x <= box.maxX and z >= box.minZ and z <= box.maxZ),
					string.format(
						"displayed tree %s at (%.1f, %.1f) inside KeepClear Sign",
						placement.placementId,
						x,
						z
					)
				)
			end
		end

		-- 2. No open order may expire or load while this step measures reputation.
		expireOrders()

		-- 3. Fast: loaded at once -> 5 stars.
		local fastOrder = soldAndCarried()
		local beforeFast = snap(R.userId)
		loadAt(fastOrder)
		local afterFast = snap(R.userId)
		local fastGain = afterFast.reputation - beforeFast.reputation
		check(
			fastGain == ReputationByStars[5],
			string.format("fast load: reputation +%d, expected +%d", fastGain, ReputationByStars[5])
		)
		check(
			afterFast.reviewCount == beforeFast.reviewCount + 1,
			string.format("fast load: reviewCount %d -> %d", beforeFast.reviewCount, afterFast.reviewCount)
		)
		check(type(afterFast.reviewsRecent) == "table", "snapshot has no reviewsRecent")
		checkWindow("fast load: ", beforeFast, afterFast, 5)
		check(signShowsRating(afterFast), "sign rating not updated within 2 s after the fast load")

		-- 4. Slow: 80 s at the car -> 2 stars and less reputation; the window ends in 5, 2.
		local slowOrder = soldAndCarried()
		advance(80)
		local beforeSlow = snap(R.userId)
		loadAt(slowOrder)
		local afterSlow = snap(R.userId)
		local slowGain = afterSlow.reputation - beforeSlow.reputation
		check(
			slowGain == ReputationByStars[2] and slowGain < fastGain,
			string.format("slow load: reputation +%d, expected +%d (2 stars)", slowGain, ReputationByStars[2])
		)
		check(
			afterSlow.reviewCount == beforeSlow.reviewCount + 1,
			string.format("slow load: reviewCount %d -> %d", beforeSlow.reviewCount, afterSlow.reviewCount)
		)
		checkWindow("slow load: ", beforeSlow, afterSlow, 2)
		local window = math.min(afterSlow.reviewCount, GameConfig.Reviews.RatingWindow)
		check(
			#afterSlow.reviewsRecent == window,
			string.format("recent window %d, expected %d", #afterSlow.reviewsRecent, window)
		)
		check(signShowsRating(afterSlow), "sign rating not updated within 2 s after the slow load")

		-- 5. Persist: the rating and likes survive a rejoin and the sign shows them again.
		rejoin(R.userId)
		local rejoined = snap(R.userId)
		for _, field in { "reviewCount", "ratingTenths", "likes" } do
			check(
				rejoined[field] == afterSlow[field],
				string.format("%s %s -> %s after rejoin", field, tostring(afterSlow[field]), tostring(rejoined[field]))
			)
		end
		check(sameList(rejoined.reviewsRecent, afterSlow.reviewsRecent), "recent reviews changed after rejoin")
		check(signShowsRating(rejoined), "sign rating not shown within 2 s after the rejoin")
		local likesShown = poll(function()
			return signLabel(R.plotId, "Likes"):GetAttribute("Likes") == rejoined.likes
		end, 2)
		check(likesShown, "sign likes not shown within 2 s after the rejoin")

		-- 6. Name: the filtered save name, or the owner's username fallback; never anything else.
		local nameLabel = signLabel(R.plotId, "Name")
		local named = poll(function()
			local source = nameLabel:GetAttribute("NameSource")
			return source == "Filtered" or source == "Owner"
		end, 2)
		local source = nameLabel:GetAttribute("NameSource")
		check(named, "sign NameSource " .. tostring(source))
		if source == "Owner" then
			local expected = realPlayer().Name .. "'s Tree Lot"
			check(nameLabel.Text == expected, string.format("sign name %q, expected %q", nameLabel.Text, expected))
		else
			check(nameLabel.Text ~= "", "filtered sign name is empty")
		end

		return string.format(
			"fast +%d (%s), slow +%d (%s), rating %s -> %s (window %d, last %s), reviews %d; name %s %q; fence gap %.2f",
			fastGain,
			Reviews.starText(5),
			slowGain,
			Reviews.starText(2),
			tostring(afterFast.ratingTenths),
			tostring(afterSlow.ratingTenths),
			#afterSlow.reviewsRecent,
			listText({
				afterSlow.reviewsRecent[#afterSlow.reviewsRecent - 1],
				afterSlow.reviewsRecent[#afterSlow.reviewsRecent],
			}),
			rejoined.reviewCount,
			tostring(source),
			nameLabel.Text,
			fenceGap
		)
	end
	addStep("42", "REVIEW_SIGN", { "03" }, reviewSignStep)

	local function lotLikeStep(): string?
		call("resetLikes", S.userId)
		local before = snap(S.userId)

		-- 1. A like at S's sign counts once and shows on the sign.
		teleport(signBoard(S.plotId))
		local liked = act(R.userId, "Lot.Like", { plotId = S.plotId })
		check(
			type(liked) == "table" and liked.ok == true,
			"Lot.Like failed: " .. tostring(type(liked) == "table" and liked.errorCode or liked)
		)
		check(
			type(liked.data) == "table" and liked.data.likes == before.likes + 1,
			string.format("likes %d -> %s", before.likes, tostring(type(liked.data) == "table" and liked.data.likes))
		)
		local shown = poll(function()
			return signLabel(S.plotId, "Likes"):GetAttribute("Likes") == before.likes + 1
		end, 2)
		check(shown, "S sign Likes not updated within 2 s")

		-- 2. A second like the same UTC day is refused.
		local again = act(R.userId, "Lot.Like", { plotId = S.plotId })
		check(
			type(again) == "table" and again.errorCode == "AlreadyLikedToday",
			"second like: " .. tostring(type(again) == "table" and again.errorCode or again)
		)
		check(snap(S.userId).likes == before.likes + 1, "likes changed on the second like")

		-- 3. Nobody likes their own lot.
		teleport(signBoard(R.plotId))
		local own = act(R.userId, "Lot.Like", { plotId = R.plotId })
		check(
			type(own) == "table" and own.errorCode == "OwnLot",
			"own lot: " .. tostring(type(own) == "table" and own.errorCode or own)
		)

		-- 4. Out of reach of S's sign.
		teleport(counterPart())
		local far = act(R.userId, "Lot.Like", { plotId = S.plotId })
		check(
			type(far) == "table" and far.errorCode == "OutOfReach",
			"far like: " .. tostring(type(far) == "table" and far.errorCode or far)
		)

		return string.format(
			"S likes %d -> %d; second like, own lot and out of reach refused",
			before.likes,
			before.likes + 1
		)
	end
	addStep("43", "LOT_LIKE", { "02", "02a" }, lotLikeStep)
end
