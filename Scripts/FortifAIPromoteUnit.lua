-- ===========================================================================
-- FortifAI
-- FortifAIUnit
-- Credits go to Tiramisu (Steam) for Legit AI Cheats
-- Make the AI stronger as an opponent,
-- in a more asymmetrical way, harder to crack
-- ===========================================================================

-- Include the effect scaling
include("FortifAIEffectScale.lua");

-- Debugging mode switch
local debugMode = true;

-- This function grants one promotion to a random combat unit to an AI civilization,
-- every time it loses a unit in combat (during their or the attacker's turn)
-- if the attacker is within the AIs borders.
function OnUnitKilledInCombat(pVictimID, unitKilledID, pKillerID, unitAttackerID)
	-- Initial variables
	local pPlayerVictim = Players[pVictimID];
	local pPlayerKiller = Players[pKillerID];

	-- Check if players still exist
	if (pPlayerVictim ~= nil and pPlayerKiller ~= nil and
	    pPlayerVictim:IsAlive() and pPlayerKiller:IsAlive()) then
		-- Defaults to killer outsite AI borders
		local killerInAIBorders = false;

		-- Fetch killers units
		local pKillerUnits = pPlayerKiller:GetUnits();

		-- If killer has units, search for the killer-unit
		if pKillerUnits ~= nil then
			-- Fetch killer unit
			local killerUnit = pKillerUnits:FindID(unitAttackerID);

			-- Attacker unit still alive
			if killerUnit ~= nil then
				-- Fetch plot the killer unit stands on
				local plotKillerUnit = Map.GetPlot(killerUnit:GetX(), killerUnit:GetY());

				-- If the killer units is within borders of the victim player, legalize random promotion
				if (plotKillerUnit ~= nil and plotKillerUnit:GetOwner() == pVictimID) then
					killerInAIBorders = true;
				end
			end

			-- Unit promotions only apply to AI players (if a unit dies and the killer is within AIs borders)
			if (pPlayerVictim ~= nil and not pPlayerVictim:IsHuman() and not pPlayerVictim:IsBarbarian() and
				pPlayerKiller:IsHuman() and killerInAIBorders) then
				-- Victims units
				local pUnits = pPlayerVictim:GetUnits();

				-- Random one of it
				local pUnit = GetRandomCombatUnitByChance(pVictimID, pUnits);

				-- We got lucky?
				if (pUnit ~= nil) then
					-- Loop all possible promotions
					for promotion in GameInfo.UnitPromotions() do
						if (GameInfo.Units[pUnit:GetType()].PromotionClass == promotion.PromotionClass) then
							local unitExperience = pUnit:GetExperience();

							-- Apply a promotion to a unit it doesn not already have
							if (not unitExperience:HasPromotion(promotion.Index)) then
								if (promotion ~= nil) then
									unitExperience:SetPromotion(promotion.Index);

									-- Promotion notice eh..
									if (PlayersVisibility[Game.GetLocalPlayer()]:IsVisible(pUnit:GetX(), pUnit:GetY())) then
										Game.AddWorldViewText(0, Locale.Lookup("LOC_FORTIFAI_IVE_SURVIVED_PROMOTION"), pUnit:GetX(), pUnit:GetY(), 0);
									end

									-- Debug log
									WriteToLog("Replaced lost unit with a promotion!");

									-- End of the wor... err, loop
									break;
								end
							end
						end
					end
				end
			end
		end
	end
end

-- Select random unit
function GetRandomCombatUnitByChance(pPlayerID, pUnits)
	-- Select a unit by chance
	local unitSelectionChance = effectScale(75);

	-- Throw the dice!
	local randomNumber = Game.GetRandNum(99);

	-- Spawn a garrisoned ranged unit only by chance
	if randomNumber <= unitSelectionChance then
	  local iUnitIDs = {};

		-- Loop all player-units
		for _, pUnit in pUnits:Members() do
			local iHitpoints = pUnit:GetMaxDamage() - pUnit:GetDamage();

			-- List up all available units
			if (pUnit ~= nil and pUnit:GetCombat() > 0 and iHitpoints > 0 and pUnit:GetX() >= 0 and pUnit:GetY() >= 0) then
				iUnitIDs[#iUnitIDs + 1] = pUnit:GetID();
			end
		end

		-- Pick a random unit
		local validRandomNumber = (Game.GetRandNum((#iUnitIDs - 1)) + 1);
		return UnitManager.GetUnit(pPlayerID, iUnitIDs[validRandomNumber]);
	end

	return nil;
end

-- Debug function for logging
function WriteToLog(message)
	if (debugMode and message ~= nil) then
		print(message);
	end
end

function Initialize()
	-- Event hook to get notified if an unit gets killed
	Events.UnitKilledInCombat.Add(OnUnitKilledInCombat);

	-- Initialization code goes here (if any)
	print("Initialized.");
end

-- Initialize the script
Initialize();
