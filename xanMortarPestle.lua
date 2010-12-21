--A very special thanks to P3lim for Molinari for the inspiration and Blightdavid for his work on Prospect Easy.

local spells = {}
local setInCombat = 0

--[[------------------------
	LOCALIZATION
--------------------------]]

local locale = GetLocale()

local L = setmetatable(locale == "deDE" and {
	Weapon = "Waffe",
} or {}, {__index=function(t,i) return i end})


--[[------------------------
	CREATE BUTTON
--------------------------]]

--this will assist us in checking if we are in combat or not
local function checkCombat(btn, force)
	if setInCombat == 0 and InCombatLockdown() then
		setInCombat = 1
		btn:SetAlpha(0)
		btn:RegisterEvent('PLAYER_REGEN_ENABLED')
	elseif force or (setInCombat == 1 and not InCombatLockdown()) then
		setInCombat = 0
		btn:UnregisterEvent('PLAYER_REGEN_ENABLED')
		btn:ClearAllPoints()
		btn:SetAlpha(1)
		btn:Hide()
	end
end

local button = CreateFrame("Button", "xMP_ButtonFrame", UIParent, "SecureActionButtonTemplate,SecureHandlerEnterLeaveTemplate,AutoCastShineTemplate")
button:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
button:RegisterEvent('MODIFIER_STATE_CHANGED')

button:SetAttribute('alt-type1', 'macro')
button:RegisterForClicks("LeftButtonUp")
button:RegisterForDrag("LeftButton")
button:SetFrameStrata("DIALOG")

--secured on leave function to hide the frame when we are in combat
button:SetAttribute("_onleave", "self:ClearAllPoints() self:SetAlpha(0) self:Hide()") 

button:HookScript("OnLeave", function(self)
	AutoCastShine_AutoCastStop(self)
	if InCombatLockdown() then checkCombat(self) else self:Hide() end --prevent combat errors
end)

button:HookScript("OnReceiveDrag", function(self)
	AutoCastShine_AutoCastStop(self)
	if InCombatLockdown() then checkCombat(self) else self:Hide() end --prevent combat errors
end)
button:HookScript("OnDragStop", function(self, button)
	AutoCastShine_AutoCastStop(self)
	if InCombatLockdown() then checkCombat(self) else self:Hide() end --prevent combat errors
end)
button:Hide()

function button:MODIFIER_STATE_CHANGED(event, modi)
	if not modi then return end
	if not modi == 'LALT' or modi == 'RALT' then return end
	if not self:IsShown() then return end
	
	--clear the auto shine if alt key has been released
	if not IsAltKeyDown() and not InCombatLockdown() then
		AutoCastShine_AutoCastStop(self)
		self:Hide()
	elseif InCombatLockdown() then
		checkCombat(self)
	end
end

function button:PLAYER_REGEN_ENABLED()
	--player left combat
	checkCombat(self, true)
end

--set the sparkles otherwise it will throw an exception
for _, sparks in pairs(button.sparkles) do
	sparks:SetHeight(sparks:GetHeight() * 3)
	sparks:SetWidth(sparks:GetWidth() * 3)
end

--[[------------------------
	CORE
--------------------------]]

local frm = CreateFrame("frame", "xanMortarPestle_Frame", UIParent)
frm:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)

function frm:PLAYER_LOGIN()
	
	--milling
	if(IsSpellKnown(51005)) then
		spells[51005] = GetSpellInfo(51005)
	end

	--prospecting
	if(IsSpellKnown(31252)) then
		spells[31252] = GetSpellInfo(31252)
	end
	
	--disenchanting
	if(IsSpellKnown(13262)) then
		spells[13262] = GetSpellInfo(13262)
	end

	GameTooltip:HookScript('OnTooltipSetItem', function(self)
		local item, link = self:GetItem()
		if(item and link and not InCombatLockdown() and IsAltKeyDown() and not CursorHasItem()) then

			local id = type(link) == "number" and link or select(3, link:find("item:(%d+):"))
			id = tonumber(id)
			
			if not id then return end
			if not xMPDB then return end
		
			local _, _, qual, itemLevel, _, itemType = GetItemInfo(link)
			local color, spell = processCheck(id, itemType, qual)
			
			--check to show or hide the button
			if color and spell then
			
				local owner = self:GetOwner() --get the owner of the tooltip
				local bag = owner:GetParent():GetID()
				local slot = owner:GetID()

				button:SetAttribute('macrotext', string.format('/cast %s\n/use %s %s', spell, bag, slot))
				button:SetAllPoints(owner)
				button:SetAlpha(1)
				button:Show()
				
				AutoCastShine_AutoCastStart(button, color.r, color.g, color.b)
			else
				button:Hide()
			end
		end
	end)
	
	self:UnregisterEvent("PLAYER_LOGIN")
	self.PLAYER_LOGIN = nil
end

function processCheck(id, itemType, qual)
	if not spells then return nil end

	--first check milling
	if spells[51005] and xMPDB.herbs[id] then
		return {r=181/255, g=230/255, b=29/255}, spells[51005]
	end
	
	--second checking prospecting
	if spells[31252] and xMPDB.ore[id] then
		return {r=1, g=127/255, b=138/255}, spells[31252]
	end
	
	--otherwise check disenchat
	if spells[13262] and itemType and qual then
		--only allow if the type of item is a weapon or armor, and it's a specific quality
		if (itemType == ARMOR or itemType == L.Weapon) and qual > 1 and qual < 5 then
			return {r=128/255, g=128/255, b=1}, spells[13262]
		end
	end
	
	return nil
end

if IsLoggedIn() then frm:PLAYER_LOGIN() else frm:RegisterEvent("PLAYER_LOGIN") end
