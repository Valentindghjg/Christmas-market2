--!strict
-- VIP chat tag (CM2-46b): a player who owns the Evergreen VIP pass gets a gold [VIP] prefix in
-- TextChatService. The server sets the ShopPassVip attribute; the tag is cosmetic only.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)

-- This is the only script that assigns TextChatService.OnIncomingMessage (checked at CM2-46b
-- review). A callback member cannot be read at runtime, so there is no "already set" check here.

local tagColor = UiKit.Colors.Gold:ToHex()

TextChatService.OnIncomingMessage = function(message: TextChatMessage): any
	local source = message.TextSource
	if source == nil then
		return nil
	end
	local sender = Players:GetPlayerByUserId(source.UserId)
	if sender == nil or sender:GetAttribute("ShopPassVip") ~= true then
		return nil
	end
	local properties = Instance.new("TextChatMessageProperties")
	properties.PrefixText = '<font color="#' .. tagColor .. '">[VIP]</font> ' .. message.PrefixText
	return properties
end
