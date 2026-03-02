local addon = cfSwingTimer
local DEFAULT_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

function addon.GetBarTexture()
	local bbfDB = BetterBlizzFramesDB
	if bbfDB and bbfDB.changeUnitFrameCastbarTexture and bbfDB.unitFrameCastbarTexture then
		local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
		if LSM then
			return LSM:Fetch(LSM.MediaType.STATUSBAR, bbfDB.unitFrameCastbarTexture)
		end
	end
	return DEFAULT_TEXTURE
end

function addon.ApplyDarkMode()
	local bbfDB = BetterBlizzFramesDB
	if not bbfDB or not bbfDB.darkModeUi then return end
	local c = bbfDB.darkModeColor or 1
	for _, bar in pairs(addon.bars) do
		if bar.border then
			bar.border:SetDesaturated(true)
			bar.border:SetVertexColor(c, c, c)
		end
	end
end
