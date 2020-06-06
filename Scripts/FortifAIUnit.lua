-- ===========================================================================
-- FortifAI
-- FortifAIUnit
-- Make the AI units stronger to defeat,
-- in a more asymmetrical way, harder to kill and more dangerous
-- ===========================================================================

-- Include the effect scaling
include("FortifAIEffectScale.lua");

-- Debugging mode switch
local debugMode = true;

-- Variable to hold extra wall damage triggering
local districtCombatValidDefender = {};

-- Variable to hold extra unit heal triggering
local unitCombatValidDefender = {};

-- Variable to track attack status
-- (trigger some actions only once per district-attack independent of damage type)
local districtAttackedOnce = {};

-- Track how much gold has been compensated
local goldCompensationThisTurn = 0;

-- Handle unit kill event
function OnUnitKilledInCombat(dPlayerID, dUnitID, aPlayerID, aUnitID)
	-- Fetch the players
	local dPlayer = Players[dPlayerID];
	local aPlayer = Players[aPlayerID];

	-- Human vs AI!
	if (aPlayer ~= nil and aPlayer:IsHuman() and dPlayer ~= nil and not dPlayer:IsHuman() and not dPlayer:IsBarbarian()) then
		local dUnit = dPlayer:GetUnits():FindID(dUnitID);
		local aUnit = aPlayer:GetUnits():FindID(aUnitID);

		-- Fetch players era data
		local pEra = GameInfo.Eras[aPlayer:GetEra()];

		-- If the human player is not at the effect-start-era, do nothing
		if pEra.ChronologyIndex < effectStartAtEra then
			-- Debug log
			WriteToLog("FortifAI effectStartAtEra not reached, bailing OnUnitKilledInCombat!");
			return;
		end

		-- Units are real?
		if (dUnit ~= nil and aUnit ~= nil) then
			local dUnitFormationClass = GameInfo.Units[dUnit:GetType()].FormationClass;
			local dPlayerCityCount = dPlayer:GetCities():GetCount();
			local aPlayerCityCount = aPlayer:GetCities():GetCount();

			-- Only land combat units
			if (dUnitFormationClass == "FORMATION_CLASS_LAND_COMBAT") then
				-- Calculate military power
				local dPlayerMilitaryMeight = GetMilitaryLandCombatStrength(dPlayer);
				local aPlayerMilitaryMeight = GetMilitaryLandCombatStrength(aPlayer);

				-- Fetch plot the attacker unit stands on
				local aUnitPlot = Map.GetPlot(aUnit:GetX(), aUnit:GetY());

				-- If the attacker unit (human) is within its own border, the AI will get a unit replacement (probably the AI tries to attack the human!)
				-- if the AI has less or equal city-count and less military strength than the defender (human)
				-- ELSE The defender AI will get a refund
				if (aUnitPlot ~= nil and aUnitPlot:GetOwner() == aPlayerID and dPlayerCityCount <= aPlayerCityCount and dPlayerMilitaryMeight < aPlayerMilitaryMeight) then
					-- Initialize city table
					local possibleCities = {};

					-- Loop players cities
					for _, dCity in dPlayer:GetCities():Members() do
						-- Fetch plot the city is build on
						local dCityPlot = Map.GetPlot(dCity:GetX(), dCity:GetY());

						-- Fetch units stationed in the city
						local dUnitsInCity = Units.GetUnitsInPlot(dCityPlot);

						-- Defaults to no combat unit is in city, this might change
						local dUnitLandCombat = false;

						-- Loop through units in city
						for _, dUnitInCity in ipairs(dUnitsInCity) do
							-- Check if a land combat unit is present
							if GameInfo.Units[dUnitInCity:GetType()].FormationClass == "FORMATION_CLASS_LAND_COMBAT" then
								-- I said earlier, this might... will change, now
								dUnitLandCombat = true;
								break;
							end
						end

						-- In case it did no change, add this city to the
						-- table of possible cities where a unit may spawn
						if not dUnitLandCombat then
							table.insert(possibleCities, dCity);
						end
					end

					-- Initially no city is set to spawn a unit
					local cityToSpawnUnit = nil;

					-- Either spawn a unit in a single city, or a random one on multiple possibilities,
					-- if none, compensate with gold
					if #possibleCities == 1 then
						-- Spawn unit in the only city that is available
						cityToSpawnUnit = possibleCities[0] or possibleCities[1];
					elseif #possibleCities > 1 then
						-- Spawn unit in a random available city
						local randomCityTableIndex = (Game.GetRandNum(#possibleCities) + 1);

						-- Spawn unit in this city
						cityToSpawnUnit = possibleCities[randomCityTableIndex];
					else
						-- Fetch units cost
						local dUnitCost = GameInfo.Units[dUnit:GetType()].Cost;

						-- Compensate with full unit cost (gold)
						CompensateWithGold(dPlayer, (dUnitCost * 2));
					end

					-- In case there is a city with space for a unit, spawn it
					if cityToSpawnUnit ~= nil then
						-- Old unit type?
						local dUnitType = dUnit:GetType();

						-- Insta create a new one! Hooray!
						dPlayer:GetUnits():Create(GameInfo.Units[dUnitType].Index, cityToSpawnUnit:GetX(), cityToSpawnUnit:GetY());

						-- Drop fortifAI messages if they has been set - AGAINST HUMANITY!
						local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()];
						if (pLocalPlayerVis:IsVisible(cityToSpawnUnit:GetX(), cityToSpawnUnit:GetY())) then
							Game.AddWorldViewText(0, Locale.Lookup("LOC_WORLD_REINFOCEMENT_GARRISON"), cityToSpawnUnit:GetX(), cityToSpawnUnit:GetY(), 0);
						end

						-- Debug log
						WriteToLog("Spawning defending garrison AI unit succeeded!");
					end
				else	-- AI is stronger than human
					-- Fetch defender units cost
					local dUnitCost = GameInfo.Units[dUnit:GetType()].Cost;

					-- For a strong AI the replacement is only a fraction
					local dCostCompensationModifier = effectScale(0.15);

					-- How much boost the AI will get is based on its number of cities and military meight compared to the human player
					-- AI Does have less or equal cities and military meight, increase replacement strength/compensation
					if (dPlayerCityCount <= aPlayerCityCount and dPlayerMilitaryMeight < aPlayerMilitaryMeight) then
						dCostCompensationModifier = effectScale(0.85);
					end

					-- Unit dies on non-human terrain due to human attack, give gold equal halfe the unit value to ai
					CompensateWithGold(dPlayer, (dUnitCost * dCostCompensationModifier));
				end
			end
		end
	end
end

-- Add gold as a compensation for a kill
function CompensateWithGold(pPlayer, pGoldAmount)
	-- Scale the gold amount accoringly
	local pScaledGoldAmount = effectScale(pGoldAmount);

	-- Player is real? and gold is real?
	if (pPlayer ~= nill and pScaledGoldAmount > 0) then
		-- Round the gold amount add it to the AI
		local pGoldRounded = RoundNumber(pScaledGoldAmount, 0)
		pPlayer:GetTreasury():ChangeGoldBalance(pGoldRounded);

		-- Add up gold compensation
		goldCompensationThisTurn = (goldCompensationThisTurn + pGoldRounded);

		-- Debug log
		WriteToLog("Damage compensated with gold: "..pGoldRounded);
	end
end

-- Local player turn-end event
function OnLocalPlayerTurnEnd()
	-- If repairs happend, trigger a message
	if goldCompensationThisTurn > 0 then
		-- Status message for war repairs for the AI
		ExposedMembers.StatusMessage(Locale.Lookup("LOC_FORTIFAI_WAR_REPAIR_AGAINST_HUMANITY_UNITS", goldCompensationThisTurn));

		-- Reset the gold-counter
		goldCompensationThisTurn = 0;
	end
end

-- In case a human ranged unit damaged a AI melee unit, heal the unit
function OnUnitDamageChanged(playerID, unitID, newDamage, oldDamage)
	-- Fetch the player (damaged player)
	local dPlayer = Players[playerID];

	-- Make sure the damaged player is an AI
	if (dPlayer ~= nil and not dPlayer:IsHuman() and not dPlayer:IsBarbarian()) then

		-- If the combat damaged a valid defender (human attacker vs AI defender)
		if unitCombatValidDefender.unitID ~= nil then
			-- Collect defender data
			dPlayer = Players[playerID];
			local dUnit = dPlayer:GetUnits():FindID(unitID);
			local dEra = GameInfo.Eras[dPlayer:GetEra()];

			-- Healing only is viable if the unit will survive the attack and the defending player era is at least classic
			if (dUnit ~= nil and dUnit:GetDamage() < dUnit:GetMaxDamage() and dEra.ChronologyIndex >= 2) then
				-- Collect attacker data
				local aPlayerID = unitCombatValidDefender.unitID.combatData.aPlayerID;
				local aUnitID = unitCombatValidDefender.unitID.combatData.aUnitID;
				local aPlayer = Players[aPlayerID];
				local aUnit = aPlayer:GetUnits():FindID(aUnitID);

				-- Units are real?
				if (aPlayer ~= nil and aUnit ~= nil and aPlayer:IsHuman()) then
					-- Fetch players era data
					local pEra = GameInfo.Eras[aPlayer:GetEra()];

					-- If the human player is not at the effect-start-era, do nothing
					if pEra.ChronologyIndex < effectStartAtEra then
						-- Debug log
						WriteToLog("FortifAI effectStartAtEra not reached, bailing OnUnitDamageChanged!");
						return;
					end

					-- Reset unit damage validation
					unitCombatValidDefender.unitID = nil;

					-- Fetch the attcker unit formation class
					local aUnitFormationClass = GameInfo.Units[aUnit:GetType()].FormationClass;
					local dUnitFormationClass = GameInfo.Units[dUnit:GetType()].FormationClass;

					-- We are only interessted in land combat units
					if (aUnitFormationClass == "FORMATION_CLASS_LAND_COMBAT" and dUnitFormationClass == "FORMATION_CLASS_LAND_COMBAT") then
						-- Fetch units combat range
						local aUnitRange = GameInfo.Units[aUnit:GetType()].Range;
						local dUnitRange = GameInfo.Units[dUnit:GetType()].Range;

						-- Only act on ranged attacks vs melee defender
						if (aUnitRange > 0 and dUnitRange == 0) then
							-- Variables huh?
							local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()];
							local dUnitHealModifier = effectScale(0.15);

							-- Collect plot/location data where defender was damaged
							local dPlot = Map.GetPlot(dUnit:GetX(), dUnit:GetY());

							-- Determine if the defneder is withn attackers borders (would result in an heal-boost for the invasion)
							local dUnitIsWithinHumanBorder = dPlot:GetOwner() == aPlayerID;

							-- Check if the attacker (human) has a melee unit adjacent to defening unit
							local dUnitHasHumanMeleeAdjacent = IsOtherPlayerMeleeUnitAdjacent(aPlayer, dUnit, dPlot);

							-- If AI unit got damaged within human borders, double heal capability; ITS AN AI INVASION AAAAAHHHHGGG!!!111
							if dUnitIsWithinHumanBorder then
								dUnitHealModifier = dUnitHealModifier * 2;
							end

							-- If human player does have a melee unit adjacent, no heal but a promotion at least!
							if dUnitHasHumanMeleeAdjacent then
								-- No promotion type per default
								local dUnitPromotionType = nil;

								-- No more heal, sorry dude
								dUnitHealModifier = 0;

								-- If the unit type allows for a ranged defense boost, apply it
								if GameInfo.Units[dUnit:GetType()].PromotionClass == "PROMOTION_CLASS_MELEE" then
									dUnitPromotionType = "PROMOTION_TORTOISE";
								elseif GameInfo.Units[dUnit:GetType()].PromotionClass == "PROMOTION_CLASS_HEAVY_CAVALRY" then
									dUnitPromotionType = "PROMOTION_BARDING";
								end

								-- Did he promote?
								if (dUnitPromotionType ~= nil) then
									-- Promoted flag
									local dPromoted = false;

									-- Look for matching promotions
									for gPromotion in GameInfo.UnitPromotions() do
										if (GameInfo.Units[dUnit:GetType()].PromotionClass == gPromotion.PromotionClass and
											gPromotion.UnitPromotionType == dUnitPromotionType and
											not dUnit:GetExperience():HasPromotion(gPromotion.Index)) then
												dUnit:GetExperience():SetPromotion(gPromotion.Index);
												dPromoted = true;
												break;
										end
									end

									-- Veteran message is only needed if the prmotion was real
									if dPromoted then
										-- Veteran message, I SURVIVED!
										if (pLocalPlayerVis:IsVisible(dUnit:GetX(), dUnit:GetY())) then
											Game.AddWorldViewText(0, Locale.Lookup("LOC_FORTIFAI_IVE_SURVIVED_PROMOTION"), dUnit:GetX(), dUnit:GetY(), 0);
										end

										-- Debug log
										WriteToLog("Promoted defending unit!");
									end
								end
							end

							-- Still only heal if the modifier is set
							if dUnitHealModifier > 0 then
								-- Calculate damage values for heal
								local damageDelta = newDamage - oldDamage;
								local damageModified = RoundNumber(damageDelta * dUnitHealModifier);
								local damageDeltaModifiedAsHeal = 0 - damageModified;

								-- Expose fortified unit (suppress default damage/heal floater)
								ExposedMembers.FortifAIUnit = dUnit;

								-- AGAINST HUMANITY!
								dUnit:ChangeDamage(damageDeltaModifiedAsHeal);

								-- Set fortifAI messages
								fortifAIDamageMessage = Locale.Lookup("LOC_WORLD_UNIT_DAMAGE_INCREASE_FLOATER", -damageDelta);

								-- If the AI is within human borders print the invasion message
								if dUnitIsWithinHumanBorder then
									fortifAIUnitHealMessage = Locale.Lookup("LOC_FORTIFAI_FOREIGN_TERRITORY_HEAL", damageModified);
								else
									fortifAIUnitHealMessage = Locale.Lookup("LOC_FORTIFAI_AGAINST_THE_HUMANITY_HEALTH", damageModified);
								end

								-- Drop fortifAI messages if they has been set - AGAINST HUMANITY!
								if (fortifAIUnitHealMessage ~= nil and fortifAIDamageMessage ~= nil and pLocalPlayerVis:IsVisible(dUnit:GetX(), dUnit:GetY())) then
									Game.AddWorldViewText(EventSubTypes.DAMAGE, fortifAIDamageMessage, dUnit:GetX(), dUnit:GetY(), 0);
									Game.AddWorldViewText(0, fortifAIUnitHealMessage, dUnit:GetX(), dUnit:GetY(), 0);

									-- Debug log
									WriteToLog("Healed defending unit: "..damageDeltaModifiedAsHeal);
								end
							end
						end
					end
				end
			end
		end
	end
end

function OnDistrictDamageChanged(playerID, districtID, damageType, newDamage, oldDamage)
	-- Fetch the player (damaged player)
	local pPlayer = Players[playerID];

	-- Extra damage only applies to human players (attacker check for AI is done in OnCombat)
	if (pPlayer ~= nil and pPlayer:IsHuman()) then
		-- Fetch players era data
		local pEra = GameInfo.Eras[pPlayer:GetEra()];

		-- If the human player is not at the effect-start-era, do nothing
		if pEra.ChronologyIndex < effectStartAtEra then
			-- Reset district attacked-once flag
			districtAttackedOnce.districtID = nil;

			-- Debug log
			WriteToLog("FortifAI effectStartAtEra not reached, bailing OnDistrictDamageChanged!");

			return;
		end

		-- Fetch the district types we want to act on
		local gDistrictCityCenterIndex = GameInfo.Districts["DISTRICT_CITY_CENTER"].Index;
		local gDistrictEncampementIndex = GameInfo.Districts["DISTRICT_ENCAMPMENT"].Index;

		-- Initiate damage variables
		local damageDelta = newDamage - oldDamage;
		local outerDamage = 0;

		-- Only boost district damage if the damage taken is negative (not a heal)
		-- and if the district has been attacked (district is defender) -> AI/Human check in OnCombat-Function
		if (damageDelta > 1 and districtCombatValidDefender.districtID ~= nil and damageType == DefenseTypes.DISTRICT_OUTER) then
			-- Reset district damage validation
			districtCombatValidDefender.districtID = nil;

			-- Fetch players era data
			local pEra = GameInfo.Eras[pPlayer:GetEra()];

			-- Initialize heal modifiers
			local eOuterDefenseModifier = 0.0;

			-- Depending on the player era, the damage boost differs
			-- The later the era, the higher the damage boost
			if pEra.ChronologyIndex == 2 then		-- Classic
				eOuterDefenseModifier = effectScale(0.15);
			elseif pEra.ChronologyIndex == 3 then	-- Medieval
				eOuterDefenseModifier = effectScale(0.30);
			elseif pEra.ChronologyIndex == 4 then	-- Renaissance
				eOuterDefenseModifier = effectScale(0.45);
			elseif pEra.ChronologyIndex == 5 then	-- Industrial
				eOuterDefenseModifier = effectScale(0.55);
			elseif pEra.ChronologyIndex == 6 then	-- Modern
				eOuterDefenseModifier = effectScale(0.62);
			elseif pEra.ChronologyIndex >= 7 then	-- Atomic to information/future (with exp2)
				eOuterDefenseModifier = effectScale(0.67);
			end

			-- Loop the player cities
			for _, pCity in pPlayer:GetCities():Members() do
				-- City variables
				local pCityID = pCity:GetID();

				-- Possible districts which can be damaged
				local pDistrictCityCenter = pCity:GetDistricts():GetDistrict(gDistrictCityCenterIndex);
				local pDistrictEncampment = pCity:GetDistricts():GetDistrict(gDistrictEncampementIndex);

				-- Damage data collection
				local damagedDistrict = nil;

				-- Determine which district has been damaged (possible are city-center of encampment)
				if (pDistrictCityCenter ~= nil and pDistrictCityCenter:GetID() == districtID) then
					-- City-center has been damaged
					damagedDistrict = pDistrictCityCenter;
				elseif (pDistrictEncampment ~= nil and pDistrictEncampment:GetID() == districtID) then
					-- Encampment has been damaged
					damagedDistrict = pDistrictEncampment;
				end

				-- Only real damaged district shall pass!
				if damagedDistrict ~= nil then
					-- Init message, modified-damage
					local EnrAIgeDamageMessage = nil;
					local damageModified = nil;

					-- Fetch sieged status
					if ExposedMembers.GetSiegeStatus ~= nil then
						local districtIsSieged = ExposedMembers.GetSiegeStatus(playerID, damagedDistrict:GetX(), damagedDistrict:GetY());

						-- On siege attacks reduce the fortification heal
						if districtIsSieged then
							eOuterDefenseModifier = eOuterDefenseModifier * effectScale(1.50);
						end
					end

					-- Damage boost only triggers if the modifier is greater zero
					if eOuterDefenseModifier > 0 then
						-- Expose fortified districts (suppress default damage/heal floater)
						ExposedMembers.FortifAIUnitDistrict = damagedDistrict;

						-- Take a part of the damage done to the district-outer-defense and
						-- turn it into an additional damage boost
						damageModified = RoundNumber(damageDelta * eOuterDefenseModifier)

						-- AGAINST HUMANITY!
						damagedDistrict:ChangeDamage(damageType, damageModified);

						-- Set fortifAI messages
						fortifAIDamageMessage = Locale.Lookup("LOC_WORLD_DISTRICT_DEFENSE_DAMAGE_INCREASE_FLOATER", -damageDelta);
						EnrAIgeDamageMessage = Locale.Lookup("LOC_FORTIFAI_ENRAIGE_AGAINST_THE_HUMANITY_DEFENSE", damageModified);

						-- Drop the fortifAI messages if it has been set - AGAINST HUMANITY!
						local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()];
						if (EnrAIgeDamageMessage ~= nil and fortifAIDamageMessage ~= nil and pLocalPlayerVis:IsVisible(damagedDistrict:GetX(), damagedDistrict:GetY())) then
							Game.AddWorldViewText(EventSubTypes.DAMAGE, fortifAIDamageMessage, damagedDistrict:GetX(), damagedDistrict:GetY(), 0);
							Game.AddWorldViewText(0, EnrAIgeDamageMessage, damagedDistrict:GetX(), damagedDistrict:GetY(), 0);

							-- Debug log
							WriteToLog("Damage boosted against human: "..damageModified);
						end
					end
				end
			end
		end
	end

	-- Reset district attacked-once flag
	districtAttackedOnce.districtID = nil;
end

function OnCombat(combatResult)
	-- Hook into district combat
  if (combatResult[CombatResultParameters.DEFENDER][CombatResultParameters.ID].type == ComponentType.DISTRICT) then
		-- Reset district flag
		local districtID = combatResult[CombatResultParameters.DEFENDER][CombatResultParameters.ID].id;

		-- Remove the district defender/attacked flag and reset exposed value
		districtCombatValidDefender.districtID = nil
		districtAttackedOnce.districtID = nil
		ExposedMembers.FortifAIUnitDistrict = nil;

		-- Attacker
		local aPlayerID = combatResult[CombatResultParameters.ATTACKER][CombatResultParameters.ID].player;
		local aPlayer = Players[aPlayerID];

		-- Defender
		local dPlayerID = combatResult[CombatResultParameters.DEFENDER][CombatResultParameters.ID].player;
		local dPlayer = Players[dPlayerID];

		-- Attacker is AI and defender is human
		if (aPlayer ~= nil and not aPlayer:IsHuman() and not aPlayer:IsBarbarian() and dPlayer ~= nil and dPlayer:IsHuman()) then
			-- Fetch players era data
			local pEra = GameInfo.Eras[dPlayer:GetEra()];

			-- If the human player is not at the effect-start-era, do nothing
			if pEra.ChronologyIndex < effectStartAtEra then
				-- Debug log
				WriteToLog("FortifAI effectStartAtEra not reached, bailing OnCombat!");

				return;
			end

			districtAttackedOnce.districtID = "ATTACKED";
			districtCombatValidDefender.districtID = "DEFENDER";
		end
  end

		-- Hook into unit combat
  if (combatResult[CombatResultParameters.DEFENDER][CombatResultParameters.ID].type == ComponentType.UNIT) then
		-- Reset unit flag
		local unitID = combatResult[CombatResultParameters.DEFENDER][CombatResultParameters.ID].id;

		-- Remove the unit defender flag and reset exposed value
		unitCombatValidDefender.unitID = nil
		ExposedMembers.FortifAIUnit = nil;

		-- Attacker
		local aPlayerID = combatResult[CombatResultParameters.ATTACKER][CombatResultParameters.ID].player;
		local aPlayer = Players[aPlayerID];

		-- Defender
		local dPlayerID = combatResult[CombatResultParameters.DEFENDER][CombatResultParameters.ID].player;
		local dPlayer = Players[dPlayerID];

		-- Attacker is human and defender is AI (not free cities AI)
		if (aPlayer ~= nil and aPlayer:IsHuman() and dPlayer ~= nil and not dPlayer:IsHuman() and not dPlayer:IsBarbarian()) then
			-- Fetch players era data
			local pEra = GameInfo.Eras[aPlayer:GetEra()];

			-- If the human player is not at the effect-start-era, do nothing
			if pEra.ChronologyIndex < effectStartAtEra then
				-- Debug log
				WriteToLog("FortifAI effectStartAtEra not reached, bailing OnCombat!");

				return;
			end

			local aUnitID = combatResult[CombatResultParameters.ATTACKER][CombatResultParameters.ID].id;

			-- Check leader type to filter for free city AI
			local dLeaderTypeName = PlayerConfigurations[dPlayer:GetID()]:GetLeaderTypeName();

			-- Exclude free city leaders from AI unit extra heal
			if dLeaderTypeName ~= "LEADER_FREE_CITIES" then
				local attackerCombatData = {};
				attackerCombatData.aUnitID = aUnitID;
				attackerCombatData.aPlayerID = aPlayerID;
				unitCombatValidDefender.unitID = {combatData=attackerCombatData};
			end
		end
	end
end

-- Fetch land combat stats
function OnGetMilitaryLandCombatStrength (pPlayer)
	return GetMilitaryLandCombatStrength(pPlayer)
end

-- Calculate land combat stats
function GetMilitaryLandCombatStrength (pPlayer)
	-- Initial values
	local pMilitaryLandCombatStrength = 0;
	local pMilitaryLandCombatCost = 0;
	local pMilitaryLandCombatCount = 0;

	-- Player is real?
	if pPlayer ~= nil then
		-- Players units
		local pUnits = pPlayer:GetUnits();

		-- Player has units?
		if pUnits ~= nil then
			-- Loop all player-units
			for _, pUnit in pUnits:Members() do
				-- Unit is real?
				if pUnit ~= nil then
					-- Fetch combat class type
					local pUnitFormationClass = GameInfo.Units[pUnit:GetType()].FormationClass;

					-- We are only interessted in land combat units
					if (pUnitFormationClass == "FORMATION_CLASS_LAND_COMBAT" or pUnitFormationClass == "FORMATION_CLASS_AIR") then
						-- Fetch combat stats
						local pUnitCombatStrength = GameInfo.Units[pUnit:GetType()].Combat;
						local pUnitRangedCombatStrength = GameInfo.Units[pUnit:GetType()].RangedCombat;
						local pUnitMaxCombatStrength = 0

						-- Determine which is the higher combat value
						if pUnitCombatStrength > pUnitRangedCombatStrength then
							pUnitMaxCombatStrength = pUnitCombatStrength;
						else
							pUnitMaxCombatStrength = pUnitRangedCombatStrength;
						end

						-- Corp formations get 10 additional combat strength
						if pUnit:GetMilitaryFormation() == 1 then
							pUnitMaxCombatStrength = pUnitMaxCombatStrength + 10;
						end

						-- Army formations get 17 additional combat strength
						if pUnit:GetMilitaryFormation() == 2 then
							pUnitMaxCombatStrength = pUnitMaxCombatStrength + 17;
						end

						-- Fetch units level
						local pUnitLevel = ExposedMembers.UnitLevel(pPlayer:GetID(), pUnit:GetID());

						-- If the unit has been promoted, add military strength for each level
						if pUnitLevel > 0 then
							pUnitMaxCombatStrength = pUnitMaxCombatStrength + (pUnitLevel * 1.5);
						end

						-- Add it up
						pMilitaryLandCombatStrength = (pMilitaryLandCombatStrength + pUnitMaxCombatStrength);
						pMilitaryLandCombatCost = (pMilitaryLandCombatCost + GameInfo.Units[pUnit:GetType()].Cost);
						pMilitaryLandCombatCount = (pMilitaryLandCombatCount + 1);
					end
				end
			end
		end
	end

	-- Fetch treasury
	local pPlayerTreasury = pPlayer:GetTreasury():GetGoldBalance();

	-- In case a military is present, take treasury into account
	if pMilitaryLandCombatStrength > 0 then
		-- Player has treasury?
		if pPlayerTreasury > 0 then
			-- Calculate the potential military strength by taking into account how many units can be bought taking the present average units costs
			local potentialCombatStrength = ((pMilitaryLandCombatCount * (pPlayerTreasury / (pMilitaryLandCombatCost / pMilitaryLandCombatCount))) / 2)

			-- If there is potential combat strength, add it up
			if potentialCombatStrength > 0 then
				pMilitaryLandCombatStrength = (pMilitaryLandCombatStrength + potentialCombatStrength);
			end
		end
	-- No military units but treasury
	elseif pPlayerTreasury > 0 then
		-- Take a calculated unit price as base-cost based on
		-- era to calculate a potential military strength
		local pEra = GameInfo.Eras[pPlayer:GetEra()];
		local pChronoIndex = pEra.ChronologyIndex;
		pMilitaryLandCombatStrength = (pPlayerTreasury / (pChronoIndex * 80));
	end

	-- This is my ultimate power!
	return pMilitaryLandCombatStrength;
end

-- Check if a melee-unit is next to a unit
function IsOtherPlayerMeleeUnitAdjacent (oPlayer, dUnit, dPlot)
	-- Fetch all adjacent plots
	local dUnitAdjacentPlots = GetAdjacentPlots(dPlot);

	-- Loop adjacent plots
	for _, plot in ipairs(dUnitAdjacentPlots) do
		-- If the plot contains units, check further
		if plot:GetUnitCount() > 0 then
			-- Fetch units on plot
			local unitsOnPlot = Units.GetUnitsInPlot(plot);

			-- Continue if there are real units
			if unitsOnPlot ~= nil then
				-- Loop plots units
				for _, plotUnit in ipairs(unitsOnPlot) do
					-- Fetch the units formation class
					local plotUnitFormationClass = GameInfo.Units[plotUnit:GetType()].FormationClass;

					-- We are only interessted in land combat units
					if plotUnitFormationClass == "FORMATION_CLASS_LAND_COMBAT" then
						-- Fetch units combat range
						local plotUnitRange = GameInfo.Units[plotUnit:GetType()].Range;

						-- Only melee is considered, must be owned by the other player
						if (plotUnitRange == 0 and oPlayer:GetID() == plotUnit:GetOwner()) then
							return true;
						end
					end
				end
			end
		end
	end

	return false;
end

-- Helper that fetches all plots surrounding the target plot
function GetAdjacentPlots (centerPlot)
	-- Storage for plots
	local adjacentPlots = {}

	-- Get all adjacent plots
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(centerPlot:GetX(), centerPlot:GetY(), direction);
		table.insert(adjacentPlots, adjacentPlot)
	end

	-- All the needs :)
	return adjacentPlots;
end

-- Round numbers helper
function RoundNumber(num, numDecimalPlaces)
  if numDecimalPlaces and numDecimalPlaces>0 then
    local mult = 10^numDecimalPlaces
    return math.ceil(num * mult + 0.5) / mult
  end
  return math.ceil(num + 0.5)
end

-- Debug function for logging
function WriteToLog(message)
	if (debugMode and message ~= nil) then
		print(message);
	end
end

-- Main function for initialization
function Initialize()
	-- Event hook to get notified if an unit gets killed
	Events.UnitKilledInCombat.Add(OnUnitKilledInCombat);

	-- Event hook to get notified if an unit gets damaged
	Events.UnitDamageChanged.Add(OnUnitDamageChanged);

	-- Event hook to get notified if an district gets damaged
	Events.DistrictDamageChanged.Add(OnDistrictDamageChanged);

	-- Event hook to get notified if a combat takes place
	Events.Combat.Add(OnCombat);

	-- Game-event for ending the turn
	Events.LocalPlayerTurnEnd.Add(OnLocalPlayerTurnEnd);

	-- Init exposed message variable
	ExposedMembers.FortifAIUnit = nil;
	ExposedMembers.FortifAIUnitDistrict = nil;

	-- Expose military strength calculator
	ExposedMembers.GetMilitaryLandCombatStrength = OnGetMilitaryLandCombatStrength;

	-- Init message log
	print("Initialized.");
end

-- Initialize the script
Initialize();
