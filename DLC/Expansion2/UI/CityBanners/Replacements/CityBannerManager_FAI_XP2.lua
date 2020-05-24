-- ==========================================
-- FortifAI - Extension for CityBannerManager
-- ==========================================

-- Basegame context
include("CityBannerManager");

-- Add a log event for loading this
print("Loading CityBannerManager_FAI_XP2.lua");

-- Define our event (overrides the original-event via event-rebind in InitializeNow())
function FAI_OnDistrictDamageChanged(playerID:number, districtID:number, damageType:number, newDamage:number, oldDamage:number)
	local pPlayer = Players[ playerID ];
	if (pPlayer ~= nil) then
		local pDistrict = pPlayer:GetDistricts():FindID(districtID);
		if (pDistrict ~= nil) then
			local pCity = pDistrict:GetCity();

			-- Suppress defaul damage floater, instead the floater of fortifAI gets used
			local suppressDamageMessages = false;
			if ((ExposedMembers.FortifAIDistrict ~= nil and ExposedMembers.FortifAIDistrict:GetID() == districtID) or
				(ExposedMembers.FortifAIUnitDistrict ~= nil and ExposedMembers.FortifAIUnitDistrict:GetID() == districtID)) then
				suppressDamageMessages = true;
			end

			if (pDistrict:GetX() == pCity:GetX() and pDistrict:GetY() == pCity:GetY()) then
				local banner = GetCityBanner(playerID, pCity:GetID());
				if (banner ~= nil) then
					banner:UpdateStats();
				end
			else
				local miniBanner = GetMiniBanner(playerID, districtID);
				if (miniBanner ~= nil) then
					miniBanner:UpdateStats();
				end
			end

			-- Add the world space text to show the delta for the damage.
			-- Can the local team see the plot where the district is?
			local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()];
			if (pLocalPlayerVis ~= nil) then
				if (pLocalPlayerVis:IsVisible(pDistrict:GetX(), pDistrict:GetY()) and not suppressDamageMessages) then	-- FortifAI

					local iDelta = newDamage - oldDamage;
					local szText;

					if (damageType == DefenseTypes.DISTRICT_GARRISON) then
						if (iDelta < 0) then
							szText = Locale.Lookup("LOC_WORLD_DISTRICT_GARRISON_DAMAGE_DECREASE_FLOATER", -iDelta);
						else
							szText = Locale.Lookup("LOC_WORLD_DISTRICT_GARRISON_DAMAGE_INCREASE_FLOATER", -iDelta);
						end
					elseif (damageType == DefenseTypes.DISTRICT_OUTER) then
						if (iDelta < 0) then
							szText = Locale.Lookup("LOC_WORLD_DISTRICT_DEFENSE_DAMAGE_DECREASE_FLOATER", -iDelta);
						else
							szText = Locale.Lookup("LOC_WORLD_DISTRICT_DEFENSE_DAMAGE_INCREASE_FLOATER", -iDelta);
						end
					end

					UI.AddWorldViewText(EventSubTypes.DAMAGE, szText, pDistrict:GetX(), pDistrict:GetY(), 0);
				end
			end
		end
	end
	-- print("A District has been damaged");
	-- print(playerID, districtID, outerDamage, garrisonDamage);
end

-- Our custom initialize
function Initialize_FAI_CityBannerManager()
	-- Log execution
	print("CityBannerManager_FAI_XP2.lua: Initialize_FAI_CityBannerManager");

	-- Unbind the original callback
	Events.DistrictDamageChanged.Remove(OnDistrictDamageChanged);

	-- Bind our function to the event callback
	Events.DistrictDamageChanged.Add(FAI_OnDistrictDamageChanged);
end

-- Our initialize
Initialize_FAI_CityBannerManager();
