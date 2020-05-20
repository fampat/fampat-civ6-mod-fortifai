-- ===========================================================================
--	FortifAI
--	FortifAIDistrict
--  Make the AI cities stronger to defeat,
--  in a more asymmetrical way, harder to crack overall
-- ===========================================================================

-- Variable to hold heal triggering
local districtCombatValidDefender = {};

-- Variable to track attack status
-- (trigger some actions only once per district-attack independent of damage type)
local districtAttackedOnce = {};

-- Track how much gold has been compensated
local goldCompensationThisTurn = 0;

-- This function grants districts with hitpoints and/or outer defense the ability
-- do gain back a potion of the lost hitpoints, this is additive to the general heal ability
-- cities (city-district) have. Only applies to AI controlled cities if attacked by a human player.
function OnDistrictDamageChanged(playerID, districtID, damageType, newDamage, oldDamage)
	-- Fetch the player (damaged player)
	local pPlayer = Players[playerID];

	-- Extra healing only applies to AI players
	if (pPlayer ~= nil and not pPlayer:IsHuman() and not pPlayer:IsBarbarian()) then
		-- Fetch the district types we want to act on
		local gDistrictCityCenterIndex = GameInfo.Districts["DISTRICT_CITY_CENTER"].Index;
		local gDistrictEncampementIndex = GameInfo.Districts["DISTRICT_ENCAMPMENT"].Index;

		-- Initiate damage variables
		local damageDelta = newDamage - oldDamage;
		local garrisonDamage = 0;
		local outerDamage = 0;

		-- Only reinforce district health if the damage taken is negative (not a heal)
		-- and if the district has been attacked (district is defender) -> AI/Human check in OnCombat-Function
		if (damageDelta > 1 and districtCombatValidDefender.districtID ~= nil) then
			-- Fetch players era data
			local pEra = GameInfo.Eras[pPlayer:GetEra()];

			-- Initialize heal modifiers
			local eGarrisonModifier = 0.0;
			local eOuterDefenseModifier = 0.0;
			local districtIsSiegedModifier = 0.50;

			-- Depending on the player era, the fortification heal differs
			-- The later the era, the higher the fortification heal bonus
			if pEra.ChronologyIndex == 2 then		-- Classic
				eGarrisonModifier = 0.0;
				eOuterDefenseModifier = 0.16;
				districtIsSiegedModifier = 0.50;	-- Only X% of eGarrisonModifier/eOuterDefenseModifier gets healed in case of a siege
			elseif pEra.ChronologyIndex == 3 then	-- Medieval
				eGarrisonModifier = 0.13;
				eOuterDefenseModifier = 0.25;
				districtIsSiegedModifier = 0.47;	-- Only X% of eGarrisonModifier/eOuterDefenseModifier gets healed in case of a siege
			elseif pEra.ChronologyIndex == 4 then	-- Renaissance
				eGarrisonModifier = 0.28;
				eOuterDefenseModifier = 0.35;
				districtIsSiegedModifier = 0.43;	-- Only X% of eGarrisonModifier/eOuterDefenseModifier gets healed in case of a siege
			elseif pEra.ChronologyIndex == 5 then	-- Industrial
				eGarrisonModifier = 0.36;
				eOuterDefenseModifier = 0.44;
				districtIsSiegedModifier = 0.38;	-- Only X% of eGarrisonModifier/eOuterDefenseModifier gets healed in case of a siege
			elseif pEra.ChronologyIndex == 6 then	-- Modern
				eGarrisonModifier = 0.44;
				eOuterDefenseModifier = 0.48;
				districtIsSiegedModifier = 0.35;	-- Only X% of eGarrisonModifier/eOuterDefenseModifier gets healed in case of a siege
			elseif pEra.ChronologyIndex >= 7 then	-- Atomic to information/future (with exp2)
				eGarrisonModifier = 0.49;
				eOuterDefenseModifier = 0.54;
				districtIsSiegedModifier = 0.32;	-- Only X% of eGarrisonModifier/eOuterDefenseModifier gets healed in case of a siege
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

				-- Garrison or outer defense can be damaged, differentiate handling
				if damagedDistrict ~= nil then
					-- Init message, modified-damage and garrisoned-unit info
					local fortifAIHealMessage = nil;
					local damageModified = nil;
					local districtConquered = false;

					-- Fetch sieged status
					if ExposedMembers.GetSiegeStatus ~= nil then
						local districtIsSieged = ExposedMembers.GetSiegeStatus(playerID, damagedDistrict:GetX(), damagedDistrict:GetY());

						-- On siege attacks reduce the fortification heal in case the city can be taken
						if districtIsSieged and not isCityInvincible() then
							eGarrisonModifier = eGarrisonModifier * districtIsSiegedModifier;
							eOuterDefenseModifier = eOuterDefenseModifier * districtIsSiegedModifier;
						end
					end

					-- If the city is invincible, heal it to the fullest
					-- This may be the case if its the last major-AI civ alive and domination victory is disabled!
					if isCityInvincible() then
						-- Max (100%) garrison and defense heal!
						eGarrisonModifier = 1;
						eOuterDefenseModifier = 1;
					end

					-- Fortify heal only triggers if the modifier is greater zero
					if (eGarrisonModifier > 0 or eOuterDefenseModifier > 0) then
						-- Expose fortified districts (suppress default damage/heal floater)
						ExposedMembers.FortifAIDistrict = damagedDistrict;

						-- Defenses has been damaged, if modifier is set: FORTIFY!
						if (eOuterDefenseModifier > 0 and damageType == DefenseTypes.DISTRICT_OUTER) then
							-- Take a part of the damage done to the district-outer-defense and turn it into heal
							damageModified = RoundNumber(damageDelta * eOuterDefenseModifier)
							local damageDeltaModifiedAsHeal = 0 - damageModified;

							-- AGAINST HUMANITY!
							damagedDistrict:ChangeDamage(damageType, damageDeltaModifiedAsHeal);

							-- Set a fortifAI message
							fortifAIDamageMessage = Locale.Lookup("LOC_WORLD_DISTRICT_DEFENSE_DAMAGE_INCREASE_FLOATER", -damageDelta);
							if eGarrisonModifier == 1 then
								fortifAIHealMessage = Locale.Lookup("LOC_FORTIFAI_AGAINST_THE_HUMANITY_DEFENSE_FULL", damageModified);
							else
								fortifAIHealMessage = Locale.Lookup("LOC_FORTIFAI_AGAINST_THE_HUMANITY_DEFENSE", damageModified);
							end
						end

						-- Garrison has been damaged, if modifier is set: FORTIFY!
						if (eGarrisonModifier > 0 and damageType == DefenseTypes.DISTRICT_GARRISON) then
							-- Get damage types
							local damageGarrison = damagedDistrict:GetDamage(DefenseTypes.DISTRICT_GARRISON);
							local damageGarrisonMax = damagedDistrict:GetMaxDamage(DefenseTypes.DISTRICT_GARRISON);

							-- Heal the district garrison-health with a part of the damage that has been done,
							-- but only if the district still has hitpoints
							if damageGarrison < damageGarrisonMax then
								-- Take a part of the damage done to the district and turn it into heal
								damageModified = RoundNumber(damageDelta * eGarrisonModifier)
								local damageDeltaModifiedAsHeal = 0 - damageModified;

								-- AGAINST HUMANITY!
								damagedDistrict:ChangeDamage(damageType, damageDeltaModifiedAsHeal);

								-- Set fortifAI messages
								fortifAIDamageMessage = Locale.Lookup("LOC_WORLD_DISTRICT_GARRISON_DAMAGE_INCREASE_FLOATER", -damageDelta);
								if eGarrisonModifier == 1 then
									fortifAIHealMessage = Locale.Lookup("LOC_FORTIFAI_AGAINST_THE_HUMANITY_HEALTH_FULL", damageModified);
								else
									fortifAIHealMessage = Locale.Lookup("LOC_FORTIFAI_AGAINST_THE_HUMANITY_HEALTH", damageModified);
								end
							else
								-- City has been conquered, prevent spawning garrison units and gold-compensation
								districtConquered = true;
							end
						end

						-- Spawn garrison and compensate for damage only
						-- if the district has not been conquered
						if not districtConquered then
							if districtAttackedOnce.districtID ~= nil then
								-- Spawn a defending unit if none is present
								SpawnDefendingUnit(damagedDistrict, pPlayer);
							end

							-- Compensate the damage with gold to the AI player to increase its change for defend proper
							CompensateDamageWithGold(damageModified, pPlayer);

							-- Drop fortifAI messages if they has been set - AGAINST HUMANITY!
							local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()];
							if (fortifAIHealMessage ~= nil and fortifAIDamageMessage ~= nil and pLocalPlayerVis:IsVisible(damagedDistrict:GetX(), damagedDistrict:GetY())) then
								Game.AddWorldViewText(EventSubTypes.DAMAGE, fortifAIDamageMessage, damagedDistrict:GetX(), damagedDistrict:GetY(), 0);
								Game.AddWorldViewText(0, fortifAIHealMessage, damagedDistrict:GetX(), damagedDistrict:GetY(), 0);
							end
						end
					end
				end
			end
		end
	end

	-- Reset district attacked-once flag
	districtAttackedOnce.districtID = nil;
end

function CompensateDamageWithGold (damageModified, pPlayer)
	-- Compensate damage done to AI with gold: Damage done -> multiply with factor -> As gold
	if (damageModified ~= nil and pPlayer ~= nil) then
		-- Compensation factor (10x) the damage amount as gold
		local damagePaymentFactor = 11;

		-- Round up the nice sum
		local pGoldCompensationValue = RoundNumber((damageModified * damagePaymentFactor), 0);

		-- Take this!
		pPlayer:GetTreasury():ChangeGoldBalance(pGoldCompensationValue);

		-- Add up gold compensation
		goldCompensationThisTurn = (goldCompensationThisTurn + pGoldCompensationValue);
	end
end

-- Check if the attacked city falls under invincible rules (no domination victory)
-- All cities of the last AI enemy are invincible to conquest, take other winning routes!
function isCityInvincible ()
	-- Loop victories and check if there are only 2 major civs left
	if (not isDominationVictoryEnabled() and getAliveMajorPlayerCount() == 2) then
		-- Iam an INVINCIBLE! Come and get me!
		return true;
	end

	-- Per default no invicibility
	return false;
end

-- Count alive major civs
function getAliveMajorPlayerCount ()
	-- Initial value
	local aliveMajorPlayerCount = 0;

	-- Fetch alive major civs
	local players = Game.GetPlayers{Alive = true, Major = true};

	-- Loop em
	for i, player in ipairs(players) do
		-- Count em
		aliveMajorPlayerCount = (aliveMajorPlayerCount + 1);
	end

	-- Return em
	return aliveMajorPlayerCount;
end

-- Check if the domination victory is enabled
function isDominationVictoryEnabled ()
	-- Loop victories
	for victory in GameInfo.Victories() do
		-- Determine type
		local victoryType = victory.VictoryType;

		-- Check conquest domination victory type and if its enabled
		if (victoryType == "VICTORY_CONQUEST" and Game.IsVictoryEnabled(victoryType)) then
			-- It is enabled, obviously ;)
			return true;
		end
	end
	-- Live long and prosper!
	return false;
end

-- Spawn a defending unit in district if none is present, unit-type depends on available techs
-- If a non-ranged unit already exists, replace it with a ranged unit and transfer promotions
function SpawnDefendingUnit (damagedDistrict, pPlayer)
	-- Player and district real?
	if (pPlayer ~= nil and damagedDistrict ~= nil) then
		-- Per default no combat unit is set
		local garrisonedLandCombatUnit = false;

		-- Init unit promotion count
		local pUnitPromotions = 0;

		-- Spawn chance in percent
		local improvementChance = 25;

		-- Throw the dice!
		local randomNumber = Game.GetRandNum(99);

		-- Spawn a garrisoned ranged unit only by chance
		if randomNumber <= improvementChance then
			-- Check the players available techs
			local pHasTechArcher = pPlayer:GetTechs():HasTech(GameInfo.Technologies["TECH_ARCHERY"].Index);												-- ANCIENT
			local pHasTechForCatapult = pPlayer:GetTechs():HasTech(GameInfo.Technologies["TECH_ENGINEERING"].Index);							-- CLASSIC
			local pHasTechForCrossbowman = pPlayer:GetTechs():HasTech(GameInfo.Technologies["TECH_MACHINERY"].Index);							-- MEDIEVAL
			local pHasTechForMusketman = pPlayer:GetTechs():HasTech(GameInfo.Technologies["TECH_GUNPOWDER"].Index);								-- RENSSASIANCE
			local pHasTechForBombard = pPlayer:GetTechs():HasTech(GameInfo.Technologies["TECH_METAL_CASTING"].Index);							-- RENSSASIANCE
			local pHasTechForFieldCannon = pPlayer:GetTechs():HasTech(GameInfo.Technologies["TECH_BALLISTICS"].Index);						-- INDUSTRIAL
			local pHasTechForInfantry = pPlayer:GetTechs():HasTech(GameInfo.Technologies["TECH_REPLACEABLE_PARTS"].Index);				-- MODERN
			local pHasTechForModernArmor = pPlayer:GetTechs():HasTech(GameInfo.Technologies["TECH_COMPOSITES"].Index);						-- MODERN
			local pHasTechForArtillery = pPlayer:GetTechs():HasTech(GameInfo.Technologies["TECH_STEEL"].Index);										-- MODERN
			local pHasTechForMachineGun = pPlayer:GetTechs():HasTech(GameInfo.Technologies["TECH_ADVANCED_BALLISTICS"].Index);		-- ATOMIC
			local pHasTechForRocketArtillery = pPlayer:GetTechs():HasTech(GameInfo.Technologies["TECH_GUIDANCE_SYSTEMS"].Index);	-- INFORMATION
			local pHasTechForGDR = pPlayer:GetTechs():HasTech(GameInfo.Technologies["TECH_ROBOTICS"].Index);											-- FUTURE

			-- Check player available civics for corps and armies
			local pHasCivicNationalism = pPlayer:GetCulture():HasCivic(GameInfo.Civics["CIVIC_NATIONALISM"].Index);
			local pHasCivicMobilization = pPlayer:GetCulture():HasCivic(GameInfo.Civics["CIVIC_MOBILIZATION"].Index);

			-- Loop the player units
			for _, pUnit in pPlayer:GetUnits():Members() do
				-- Check for unit in district
				if (pUnit ~= nil and damagedDistrict:GetX() == pUnit:GetX() and damagedDistrict:GetY() == pUnit:GetY()) then
					-- Fetch unit formation class
					local pUnitFormationClass = GameInfo.Units[pUnit:GetType()].FormationClass;

					-- If the currently garrisoned unit is combat type, pimp it, else spawn one
					if pUnitFormationClass == "FORMATION_CLASS_LAND_COMBAT" then
						-- Keep in mind a unit is garrisoned
						garrisonedLandCombatUnit = true;

						-- Promote a garrisoned unit if no new will be spawned
						for gPromotion in GameInfo.UnitPromotions() do
							if (GameInfo.Units[pUnit:GetType()].PromotionClass == gPromotion.PromotionClass) then
								if (not pUnit:GetExperience():HasPromotion(gPromotion.Index)) then
									if (gPromotion ~= nil) then
										-- Promote! Congratulation Soldier!
										pUnit:GetExperience():SetPromotion(gPromotion.Index);

										-- Veteran message, I SURVIVED!
										if (PlayersVisibility[Game.GetLocalPlayer()]:IsVisible(pUnit:GetX(), pUnit:GetY())) then
											Game.AddWorldViewText(0, Locale.Lookup("LOC_FORTIFAI_IVE_SURVIVED_PROMOTION"), pUnit:GetX(), pUnit:GetY(), 0);
										end

										-- The END
										break;
									end
								end
							end
						end

						-- Fetch unit formation state
						local pUnitFormation = pUnit:GetMilitaryFormation();
						local pUnitTypeName = GameInfo.Units[pUnit:GetType()].UnitType;

						-- If the civics exist, form corp or army (not possible for GDR)
						if pUnitTypeName ~= "UNIT_GIANT_DEATH_ROBOT" then
							if (pHasCivicMobilization and pUnitFormation <= 1) then
								pUnit:SetMilitaryFormation(MilitaryFormationTypes.ARMY_FORMATION);
							elseif (pHasCivicNationalism and pUnitFormation == 0) then
								pUnit:SetMilitaryFormation(MilitaryFormationTypes.CORPS_FORMATION);
							end
						end

						-- Not more further looping needed
						break;
					end
				end
			end

			-- If no unit is garrisoned in defending district,
			-- spawn a ranged unit depending on tech level
			if not garrisonedLandCombatUnit then
				local unitToSpawn = "UNIT_SLINGER";

				-- Choose the highest available unit for defense
				if (pHasTechForGDR and GameInfo.Units["UNIT_GIANT_DEATH_ROBOT"] ~= nil) then
					unitToSpawn = "UNIT_GIANT_DEATH_ROBOT";
				elseif pHasTechForModernArmor then
					unitToSpawn = "UNIT_MODERN_ARMOR";
				elseif pHasTechForMachineGun then
					unitToSpawn = "UNIT_MACHINE_GUN";
				elseif pHasTechForInfantry then
					unitToSpawn = "UNIT_INFANTRY";
				elseif pHasTechForFieldCannon then
					unitToSpawn = "UNIT_FIELD_CANNON";
				elseif pHasTechForMusketman then
					unitToSpawn = "UNIT_MUSKETMAN";
				elseif pHasTechForCrossbowman then
					unitToSpawn = "UNIT_CROSSBOWMAN";
				elseif pHasTechForCatapult then
					unitToSpawn = "UNIT_SWORDSMAN";
				elseif pHasTechArcher then
					unitToSpawn = "UNIT_ARCHER";
				end

				-- Spawn the new unit
				local pNewUnit = pPlayer:GetUnits():Create(GameInfo.Units[unitToSpawn].Index, damagedDistrict:GetX(), damagedDistrict:GetY());

				-- Drop fortifAI messages if they has been set - AGAINST HUMANITY!
				local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()];
				if (pLocalPlayerVis:IsVisible(damagedDistrict:GetX(), damagedDistrict:GetY())) then
					Game.AddWorldViewText(0, Locale.Lookup("LOC_WORLD_REINFOCEMENT_GARRISON"), damagedDistrict:GetX(), damagedDistrict:GetY(), 0);
				end

				-- If the civics exist, form corp or army (not possible for GDR)
				if unitToSpawn ~= "UNIT_GIANT_DEATH_ROBOT" then
					if pHasCivicMobilization then
						pNewUnit:SetMilitaryFormation(MilitaryFormationTypes.ARMY_FORMATION);
					elseif pHasCivicNationalism then
						pNewUnit:SetMilitaryFormation(MilitaryFormationTypes.CORPS_FORMATION);
					end
				end
			end
		end
	end
end

-- Hook into combat action and make sure only AI districts, which get attackt by a human players, get fortify heal
function OnCombat(combatResult)
	-- Hook into district combat
    if (combatResult[CombatResultParameters.DEFENDER][CombatResultParameters.ID].type == ComponentType.DISTRICT) then
		-- Remove the district defender/attacked flag and reset exposed value
		districtCombatValidDefender.districtID = nil
		districtAttackedOnce.districtID = nil
		ExposedMembers.FortifAIDistrict = nil;

		-- Attacker
		local aPlayerID = combatResult[CombatResultParameters.ATTACKER][CombatResultParameters.ID].player;
		local aPlayer = Players[aPlayerID];

		-- Defender
		local dPlayerID = combatResult[CombatResultParameters.DEFENDER][CombatResultParameters.ID].player;
		local dPlayer = Players[dPlayerID];

		-- Extra healing-trigger only apply to AI defenders if the attacker is human and local player
		-- Also this only triggers if the AI is weaker in regards to military strength and city count
		if (aPlayer ~= nil and aPlayer:IsHuman() and dPlayer ~= nil and not dPlayer:IsHuman() and not dPlayer:IsBarbarian()) then
			-- Check leader type to filter for free city AI
			local dLeaderTypeName = PlayerConfigurations[dPlayer:GetID()]:GetLeaderTypeName();

			-- Exclude free city leaders from AI fortification heal
			if dLeaderTypeName ~= "LEADER_FREE_CITIES" then
				local districtID = combatResult[CombatResultParameters.DEFENDER][CombatResultParameters.ID].id;
				districtAttackedOnce.districtID = "ATTACKED";
				districtCombatValidDefender.districtID = "DEFENDER";
			end
		end
    end
end

-- Turn-end event
function OnTurnEnd()
	-- If repairs happend, trigger a message
	if goldCompensationThisTurn > 0 then
		-- Notify the player of what he has done!
		ExposedMembers.StatusMessage(Locale.Lookup("LOC_FORTIFAI_WAR_REPAIR_AGAINST_HUMANITY_DISTRICTS", goldCompensationThisTurn), 10);

		-- Reset the gold-counter
		goldCompensationThisTurn = 0;
	end
end

-- Round numbers helper
function RoundNumber(num, numDecimalPlaces)
  if numDecimalPlaces and numDecimalPlaces>0 then
    local mult = 10^numDecimalPlaces
    return math.ceil(num * mult + 0.5) / mult
  end
  return math.ceil(num + 0.5)
end

-- Main function for initialization
function Initialize()
	-- Init exposed message variable
	ExposedMembers.FortifAIDistrict = nil;

	-- Event hook to get notified if an district gets damaged
	Events.DistrictDamageChanged.Add(OnDistrictDamageChanged);

	-- Game-event for ending the turn
	Events.TurnEnd.Add(OnTurnEnd);

	-- Event hook to get notified if a combat takes place
	Events.Combat.Add(OnCombat);

	-- Init message log
	print("Initialized.");
end

-- Initialize the script
Initialize();
