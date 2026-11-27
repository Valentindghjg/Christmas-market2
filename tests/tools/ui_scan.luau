--!nonstrict
-- CM2-UI1: scans the sources for UI values that must come from UiTheme and for references to the
-- third-party UI pack (assets/third_party/swarve-essential-ui). Prints file:line per hit; exit 1 on any.
-- Run: lune run tests/tools/ui_scan.luau
local fs = require("@lune/fs")
local process = require("@lune/process")

local function listLua(dir: string, out: { string })
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			listLua(path, out)
		elseif string.match(name, "%.lua$") then
			table.insert(out, path)
		end
	end
end

local function lines(path: string): { string }
	local result = {}
	for line in string.gmatch(fs.readFile(path) .. "\n", "([^\n]*)\n") do
		table.insert(result, line)
	end
	return result
end

local hits = 0
local function hit(path: string, number: number, why: string, line: string)
	hits += 1
	print(string.format("%s:%d: %s: %s", path, number, why, (string.gsub(line, "^%s+", ""))))
end

local clientFiles, srcFiles = {}, {}
listLua("src/client", clientFiles)
listLua("src", srcFiles)

-- Literal colours, fonts and text sizes in the client belong in UiTheme.
local CLIENT_PATTERNS = {
	"Color3%.fromRGB%(%s*%d",
	"Color3%.new%(%s*[%d%.]",
	"Enum%.Font%.",
	"Font%.new%(",
	"TextSize%s*=%s*%d",
}
for _, path in ipairs(clientFiles) do
	for number, line in ipairs(lines(path)) do
		for _, pattern in ipairs(CLIENT_PATTERNS) do
			if string.find(line, pattern) then
				hit(path, number, "literal " .. pattern, line)
			end
		end
		if string.find(line, "rbxassetid", 1, true) then
			hit(path, number, "rbxassetid in client", line)
		end
		if path ~= "src/client/UiKit.lua" and string.find(line, "AutoButtonColor", 1, true) then
			hit(path, number, "AutoButtonColor outside UiKit", line)
		end
	end
end

-- Asset IDs of the third-party pack must not appear in src.
local packIds = {}
for id in string.gmatch(fs.readFile("assets/third_party/swarve-essential-ui/INVENTORY.md"), "%d%d%d%d%d%d%d+") do
	packIds[id] = true
end
for _, path in ipairs(srcFiles) do
	for number, line in ipairs(lines(path)) do
		if string.find(string.lower(line), "swarve", 1, true) then
			hit(path, number, "swarve", line)
		end
		for digits in string.gmatch(line, "%d%d%d%d%d%d%d+") do
			if packIds[digits] then
				hit(path, number, "pack asset id " .. digits, line)
			end
		end
	end
end
for number, line in ipairs(lines("src/shared/UiTheme.lua")) do
	if string.find(line, "rbxassetid", 1, true) then
		hit("src/shared/UiTheme.lua", number, "rbxassetid in UiTheme", line)
	end
end

print(string.format("[UI-SCAN] %d hit(s) in %d client files, %d src files", hits, #clientFiles, #srcFiles))
if hits > 0 then
	process.exit(1)
end
