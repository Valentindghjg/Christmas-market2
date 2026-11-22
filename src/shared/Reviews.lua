--!strict
-- Customer reviews, the lot rating and lot likes (CM2-G15). Pure logic over a company record;
-- schema 15 stores `reviews = { count, recent }` and `likes = { total, day, today }`.
local GameConfig = require(script.Parent.GameConfig)
local SaveProfile = require(script.Parent.SaveProfile)

local Reviews = {}

-- Notify keys of review toasts; their first argument is the star count.
Reviews.TextKeys = {
	reviewGreat = true,
	reviewGood = true,
	reviewSlowService = true,
	reviewSlowTree = true,
	reviewVerySlow = true,
	reviewNoTree = true,
}

local function isFiniteInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

function Reviews.newReviews()
	return { count = 0, recent = {} }
end

function Reviews.newLikes()
	return { total = 0, day = 0, today = {} }
end

-- A proper array: keys exactly 1..n. Returns n, or nil when the table is not an array.
local function arrayLength(value: { [any]: any }): number?
	local entries = 0
	local maxKey = 0
	for key in pairs(value) do
		if not isFiniteInteger(key) or key < 1 then
			return nil
		end
		entries += 1
		if key > maxKey then
			maxKey = key
		end
	end
	if maxKey ~= entries then
		return nil
	end
	return entries
end

local function validReviews(reviews: any): boolean
	if type(reviews) ~= "table" or not isFiniteInteger(reviews.count) or reviews.count < 0 then
		return false
	end
	if type(reviews.recent) ~= "table" then
		return false
	end
	local length = arrayLength(reviews.recent)
	if length == nil or length > GameConfig.Reviews.RatingWindow or reviews.count < length then
		return false
	end
	for _, stars in ipairs(reviews.recent) do
		if not isFiniteInteger(stars) or stars < 1 or stars > 5 then
			return false
		end
	end
	return true
end

local function validLikes(likes: any): boolean
	if
		type(likes) ~= "table"
		or not isFiniteInteger(likes.total)
		or likes.total < 0
		or not isFiniteInteger(likes.day)
		or likes.day < 0
		or type(likes.today) ~= "table"
	then
		return false
	end
	local count = 0
	for key, value in pairs(likes.today) do
		if type(key) ~= "string" or #key < 1 or #key > 19 or string.match(key, "^%d+$") == nil then
			return false
		end
		if value ~= true then
			return false
		end
		count += 1
	end
	return count <= GameConfig.Reviews.MaxLikesPerDay
end

function Reviews.isValid(state: any): boolean
	return type(state) == "table" and validReviews(state.reviews) and validLikes(state.likes)
end

-- Config limits can shrink between builds; trim instead of locking the player out.
function Reviews.normalize(state: any)
	if type(state) ~= "table" then
		return
	end
	local reviews = state.reviews
	if type(reviews) == "table" and type(reviews.recent) == "table" then
		local recent = reviews.recent
		local excess = #recent - GameConfig.Reviews.RatingWindow
		if excess > 0 then
			local kept = {}
			for index = excess + 1, #recent do
				table.insert(kept, recent[index])
			end
			reviews.recent = kept
		end
	end
	local likes = state.likes
	if type(likes) == "table" and type(likes.today) == "table" then
		local count = 0
		for _ in pairs(likes.today) do
			count += 1
		end
		if count > GameConfig.Reviews.MaxLikesPerDay then
			likes.today = {}
		end
	end
end

-- Stars from the service time (queue + pickup seconds).
function Reviews.starsFor(serviceSeconds: number): number
	if type(serviceSeconds) ~= "number" or serviceSeconds ~= serviceSeconds then
		return 1
	end
	local limits = GameConfig.Reviews.StarMaxSeconds
	for index, maxSeconds in ipairs(limits) do
		if serviceSeconds <= maxSeconds then
			return 5 - (index - 1)
		end
	end
	return 1
end

function Reviews.textKeyFor(stars: number, queueSeconds: number, pickupSeconds: number): string
	if stars >= 5 then
		return "reviewGreat"
	elseif stars == 4 then
		return "reviewGood"
	elseif stars == 3 or stars == 2 then
		return if queueSeconds > pickupSeconds then "reviewSlowService" else "reviewSlowTree"
	end
	return "reviewVerySlow"
end

function Reviews.record(state: any, stars: number)
	local reviews = state.reviews
	table.insert(reviews.recent, stars)
	while #reviews.recent > GameConfig.Reviews.RatingWindow do
		table.remove(reviews.recent, 1)
	end
	reviews.count += 1
end

-- Average stars of the recent window in tenths, or nil without reviews.
function Reviews.ratingTenths(state: any): number?
	local recent = state.reviews.recent
	if #recent == 0 then
		return nil
	end
	local sum = 0
	for _, stars in ipairs(recent) do
		sum += stars
	end
	return math.floor(sum * 10 / #recent + 0.5)
end

function Reviews.utcDay(timestamp: number): number
	return math.floor(timestamp / 86400)
end

-- One like per player and lot per UTC day; never by the owner or a member of the save.
function Reviews.like(state: any, userId: number, day: number): (boolean, number | string)
	local key = SaveProfile.userIdText(userId)
	if state.members[key] ~= nil or userId == state.ownerUserId then
		return false, "OwnLot"
	end
	local likes = state.likes
	if likes.day ~= day then
		likes.day = day
		likes.today = {}
	end
	if likes.today[key] then
		return false, "AlreadyLikedToday"
	end
	local count = 0
	for _ in pairs(likes.today) do
		count += 1
	end
	if count >= GameConfig.Reviews.MaxLikesPerDay then
		return false, "LikesFull"
	end
	likes.today[key] = true
	likes.total += 1
	return true, likes.total
end

function Reviews.starText(stars: number): string
	local value = if type(stars) == "number" and stars == stars then stars else 1
	local s = math.clamp(math.floor(value), 1, 5)
	return string.rep("★", s) .. string.rep("☆", 5 - s)
end

function Reviews.signView(state: any)
	return {
		saveName = state.saveName,
		ownerUserId = state.ownerUserId,
		ratingTenths = Reviews.ratingTenths(state),
		reviewCount = state.reviews.count,
		likes = state.likes.total,
	}
end

return Reviews
