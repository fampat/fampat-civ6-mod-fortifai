-- =================================================
--	FortifAIProxy
--	Proxy helper to access UI functions from scripts
-- =================================================

-- Fetch the siege status of an district
function OnGetSiegeStatus (pPlayerID, pDistrictX, pDistrictY)
	-- Fetch player
	local pPlayer = Players[pPlayerID];

	-- Player is real?
	if (pPlayer ~= nil) then
		-- Determine siegeable districts
		local gDistrictCityCenterIndex = GameInfo.Districts["DISTRICT_CITY_CENTER"].Index;
		local gDistrictEncampementIndex = GameInfo.Districts["DISTRICT_ENCAMPMENT"].Index;

		-- Loop player cities
		for _, pCity in pPlayer:GetCities():Members() do
			-- Fetch city district
			local pDistrictCityCenter = pCity:GetDistricts():GetDistrict(gDistrictCityCenterIndex);
			local pDistrictEncampment = pCity:GetDistricts():GetDistrict(gDistrictEncampementIndex);

			-- If a valid district is found and its matching the requested coordinates, check siege status
			if (pDistrictCityCenter ~= nil and pDistrictCityCenter:GetX() == pDistrictX and pDistrictCityCenter:GetY() == pDistrictY) then
				-- SIEGE? YES? NO? HUH? -> This damn function only exists in UI context... but WHY firaxis?
				return pDistrictCityCenter:IsUnderSiege();
			end

		end
	end

	-- Defaults to no siege...
	return false;
end

-- Fetch the promotion level of an unit
function OnUnitLevel (pPlayerID, pUnitID)
	-- Fetch player
	local pPlayer = Players[pPlayerID];

	-- Player is real?
	if (pPlayer ~= nil) then
		-- Fetch unit
		local pUnit = pPlayer:GetUnits():FindID(pUnitID);

		-- Unit is existend
		if pUnit ~= nil then
			-- Return units level
			return pUnit:GetExperience():GetLevel();
		end
	end
	
	-- Defaults to, rookie!
	return 0;
end

-- Init, uknow...
function Initialize()
	-- Map the siege-status funtion to a exposed member
	ExposedMembers.GetSiegeStatus = OnGetSiegeStatus;

	-- Map the unit-level function to a exposed member
	ExposedMembers.UnitLevel = OnUnitLevel;

	-- Init message log
	print("Initialized.");
end

Initialize();
