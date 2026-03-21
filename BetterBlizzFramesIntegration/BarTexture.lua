-- BarTexture.lua — Sync bar textures with BetterBlizzFrames castbar texture setting
local DEFAULT_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

function cfSwingTimer.GetBarTexture()
	local bbfDB = BetterBlizzFramesDB
	if bbfDB and bbfDB.changeUnitFrameCastbarTexture and bbfDB.unitFrameCastbarTexture then
		local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
		if LSM then
			return LSM:Fetch(LSM.MediaType.STATUSBAR, bbfDB.unitFrameCastbarTexture)
		end
	end
	local castTex = CastingBarFrame and CastingBarFrame:GetStatusBarTexture()
	if castTex then return castTex:GetTexture() end
	return DEFAULT_TEXTURE
end

local function ApplyTexture()
	local texture = cfSwingTimer.GetBarTexture()
	for _, bar in pairs(cfSwingTimer.bars) do
		if bar.isCenter then
			bar.bar:SetTexture(texture)
		else
			bar:SetStatusBarTexture(texture)
		end
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, arg1)
	if arg1 ~= "cfSwingTimer" and arg1 ~= "BetterBlizzFrames" then return end
	if not cfSwingTimer or not BetterBlizzFramesDB then return end

	self:UnregisterEvent("ADDON_LOADED")

	-- Hook BBF's texture update to reapply when settings change
	if BBF and BBF.UpdateCustomTextures then
		hooksecurefunc(BBF, "UpdateCustomTextures", ApplyTexture)
	end
end)
