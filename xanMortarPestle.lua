--A very special thanks to P3lim (Molinari) for the inspiration behind the AutoShine and Blightdavid for his work on Prospect Easy.

local spells = {}
local setInCombat = 0
local lastItem

local colors = {
	[51005] = {r=181/255, g=230/255, b=29/255},	--milling
	[31252] = {r=1, g=127/255, b=138/255},  	--prospecting
	[13262] = {r=128/255, g=128/255, b=1},   	--disenchant
    [1804] = {r=200/255, g=75/255, b=75/255},       --lock picking  (Thanks to kaisoul)
}

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
	if InCombatLockdown() then checkCombat(self) else self:ClearAllPoints() self:Hide() end --prevent combat errors
end)

button:HookScript("OnReceiveDrag", function(self)
	AutoCastShine_AutoCastStop(self)
	if InCombatLockdown() then checkCombat(self) else self:ClearAllPoints() self:Hide() end --prevent combat errors
end)
button:HookScript("OnDragStop", function(self, button)
	AutoCastShine_AutoCastStop(self)
	if InCombatLockdown() then checkCombat(self) else self:ClearAllPoints() self:Hide() end --prevent combat errors
end)
button:Hide()

function button:MODIFIER_STATE_CHANGED(event, modi)
	if not modi then return end
	if modi ~= "LALT" or modi ~= "RALT" then return end
	if not self:IsShown() then return end
	
	--clear the auto shine if alt key has been released
	if not IsAltKeyDown() and not InCombatLockdown() then
		AutoCastShine_AutoCastStop(self)
		self:ClearAllPoints()
		self:Hide()
	elseif InCombatLockdown() then
		checkCombat(self)
	end
end

function button:PLAYER_REGEN_ENABLED()
	--player left combat
	checkCombat(self, true)
end

--AutoCastShineTemplate
--set the sparkles otherwise it will throw an error
--increase the sparkles a bit for clarity
for _, sparks in pairs(button.sparkles) do
	sparks:SetHeight(sparks:GetHeight() * 3)
	sparks:SetWidth(sparks:GetWidth() * 3)
end

--if the lootframe is showing then disable everything
LootFrame:HookScript("OnShow", function(self)
	if button:IsShown() and not InCombatLockdown() then
		AutoCastShine_AutoCastStop(button)
		button:ClearAllPoints()
		button:Hide()
	end
end)

--[[------------------------
	CORE
--------------------------]]

local frm = CreateFrame("frame", "xanMortarPestle_Frame", UIParent)
frm:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)

function frm:PLAYER_LOGIN()
	
	--check for DB
	if not XMP_DB then XMP_DB = {} end
	
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

	--lock picking (thanks to Kaisoul)
	if(IsSpellKnown(1804)) then
		spells[1804] = GetSpellInfo(1804)
	end
	
	GameTooltip:HookScript('OnTooltipSetItem', function(self)
		--do some checks before we do anything
		if InCombatLockdown() then return end	--if were in combat then exit
		if not IsAltKeyDown() then return end	--if the modifier is not down then exit
		if CursorHasItem() then return end	--if the mouse has an item then exit
	
		local item, link = self:GetItem()
		
		--reset if no item (link will be nil)
		lastItem = link
		
		--make sure we have an item, it's not an equipped one, and the darn lootframe isn't showing
		if item and link and not IsEquippedItem(link) and not LootFrame:IsShown() then

			local owner = self:GetOwner() --get the owner of the tooltip
			local bag = owner:GetParent():GetID()
			local slot = owner:GetID()
			
			--if it's the character frames <alt> equipment switch then ignore it
			if owner and owner:GetName() and strfind(owner:GetName(), "PaperDollFrame") then return end
		
			local id = type(link) == "number" and link or select(3, link:find("item:(%d+):"))
			id = tonumber(id)
			
			if not id then return end
			if not xMPDB then return end
		
			local _, _, qual, itemLevel, _, itemType = GetItemInfo(link)
			local spellID = processCheck(id, itemType, qual, link)
			
			--check to show or hide the button
			if spellID then
			
				--set the item for disenchant check
				lastItem = link

				button:SetAttribute('macrotext', string.format('/cast %s\n/use %s %s', spells[spellID], bag, slot))
				button:SetAllPoints(owner)
				button:SetAlpha(1)
				button:Show()
				
				AutoCastShine_AutoCastStart(button, colors[spellID].r, colors[spellID].g, colors[spellID].b)
			else
				button:ClearAllPoints()
				button:Hide()
			end
			
		end
	end)
	
	self:UnregisterEvent("PLAYER_LOGIN")
	self.PLAYER_LOGIN = nil
end

function processCheck(id, itemType, qual, link)
	if not spells then return nil end

	--first check milling
	if xMPDB.herbs[id] and spells[51005] then
		return 51005
	end
	
	--second checking prospecting
	if xMPDB.ore[id] and spells[31252] then
		return 31252
	end

	--third checking lock picking  (thanks to Kailsoul)
	if xMPDB.lock[id] and spells[1804] then
		return 1804
	end
	
	--otherwise check disenchat
	if itemType and qual and XMP_DB and spells[13262] then
		--only allow if the type of item is a weapon or armor, and it's a specific quality
		if (itemType == ARMOR or itemType == L.Weapon) and qual > 1 and qual < 5 and IsEquippableItem(link) and not XMP_DB[id] then
			return 13262
		end
	end
	
	return nil
end

--instead of having a large array with all the possible non-disenchant items
--I decided to go another way around this.  Whenever a user tries to disenchant an item that can't be disenchanted
--it learns the item into a database.  That way in the future the user will not be able to disenchant it.
--A one time warning will be displayed for the user ;)

local originalOnEvent = UIErrorsFrame:GetScript("OnEvent")
UIErrorsFrame:SetScript("OnEvent", function(self, event, msg, r, g, b, ...)
	if event ~= "SYSMSG" then
		--it's not a system message so lets grab it and compare with non-disenchant
		if msg == SPELL_FAILED_CANT_BE_DISENCHANTED and XMP_DB and button:IsShown() and lastItem then
			--get the id from the previously stored link
			local id = type(lastItem) == "number" and lastItem or select(3, lastItem:find("item:(%d+):"))
			id = tonumber(id)
			--check to see if it's already in the database, if it isn't then add it to the DE list.
			if id and not XMP_DB[id] then
				XMP_DB[id] = true
				DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF99CC33xanMortarPestle|r: %s added to database. %s", lastItem, SPELL_FAILED_CANT_BE_DISENCHANTED))
			end
		end
	end
	return originalOnEvent(self, event, msg, r, g, b, ...)
end)

if IsLoggedIn() then frm:PLAYER_LOGIN() else frm:RegisterEvent("PLAYER_LOGIN") end
