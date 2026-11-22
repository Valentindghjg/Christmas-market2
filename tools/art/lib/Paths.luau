--!strict
-- Directory layout of the art pipeline (CM2-AP): all paths derive from --root and an art path.
-- Paths handed to Blender go through Paths.absolute (CM2-ART1).
local ArtLibrary = require("../../../src/shared/ArtLibrary")

local Paths = {}

Paths.DEFAULT_ROOT = "assets/art"

function Paths.isValid(artPath: string): boolean
	return ArtLibrary.isValidPath(artPath)
end

function Paths.leaf(artPath: string): string
	return string.match(artPath, "([^/]+)$") or artPath
end

function Paths.sourceDir(root: string, artPath: string): string
	return root .. "/source/" .. artPath
end

function Paths.blendFile(root: string, artPath: string): string
	return Paths.sourceDir(root, artPath) .. "/model.blend"
end

function Paths.specFile(root: string, artPath: string): string
	return Paths.sourceDir(root, artPath) .. "/asset.json"
end

function Paths.buildDir(root: string, artPath: string): string
	return root .. "/_build/" .. artPath
end

function Paths.rbxmFile(root: string, artPath: string): string
	return root .. "/rbxm/" .. artPath .. ".rbxm"
end

-- The directory part of a file path, for creating it before a write.
function Paths.parentDir(file: string): string
	return string.match(file, "^(.*)/[^/]+$") or "."
end

function Paths.isAbsolute(path: string, cwd: string): boolean
	if string.match(path, "^%a:[/\\]") ~= nil or string.match(path, "^[/\\][/\\]") ~= nil then
		return true
	end
	return string.sub(path, 1, 1) == "/" and string.sub(cwd, 1, 1) == "/"
end

function Paths.absolute(cwd: string, path: string): string
	local p = string.gsub(path, "\\", "/")
	local base = string.gsub(string.gsub(cwd, "\\", "/"), "/+$", "")
	if Paths.isAbsolute(p, cwd) then
		return p
	end
	if string.sub(p, 1, 1) == "/" then
		local drive = string.match(base, "^(%a:)")
		if drive ~= nil then
			return drive .. p
		end
	end
	while string.sub(p, 1, 2) == "./" do
		p = string.sub(p, 3)
	end
	if p == "" or p == "." then
		return if base == "" then "/" else base
	end
	return base .. "/" .. p
end

return Paths
