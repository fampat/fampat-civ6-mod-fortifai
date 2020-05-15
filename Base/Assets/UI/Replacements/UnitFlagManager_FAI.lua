-- ========================================
-- FortifAI - Extension for UnitFlagManager
-- ========================================

-- Basegame context
include("UnitFlagManager");

-- Add a log event for loading this
print("Loading UnitFlagManager_FAI.lua");

-- Get the cached events
ORIGINAL_OnUnitDamageChanged = OnUnitDamageChanged;

-- Define our event (overrides the original-event via event-rebind in InitializeNow())
function OnUnitDamageChanged(playerID : number, unitID : number, newDamage : number, oldDamage : number)
	local pPlayer = Players[ playerID ];

	if (pPlayer ~= nil) then
		local pUnit = pPlayer:GetUnits():FindID(unitID);

		if (pUnit ~= nil) then
			local flag = GetUnitFlag(playerID, pUnit:GetID());

			if (flag ~= nil) then
				-- We need to check if the message should be supressed
				local suppressDamageMessages = false;

				if (ExposedMembers.FortifAIUnit ~= nil and ExposedMembers.FortifAIUnit:GetID() == unitID) then
					suppressDamageMessages = true;
				end

				flag:UpdateStats();

				-- So only unsupressed it will displayed
				if (flag.m_eVisibility == RevealedState.VISIBLE and not suppressDamageMessages) then	-- FortifAI
					local iDelta = newDamage - oldDamage;
					local szText;

					if (iDelta < 0) then
						szText = Locale.Lookup("LOC_WORLD_UNIT_DAMAGE_DECREASE_FLOATER", -iDelta);
					else
						szText = Locale.Lookup("LOC_WORLD_UNIT_DAMAGE_INCREASE_FLOATER", -iDelta);
					end

					UI.AddWorldViewText(EventSubTypes.DAMAGE, szText, pUnit:GetX(), pUnit:GetY(), 0);
				end
			end
		end
	end
end

-- Our custom initialize
function InitializeNow()
	-- Log execution
	print("UnitFlagManager_FAI.lua: InitializeNow")

	-- Unbind the original callback
	Events.UnitDamageChanged.Remove(ORIGINAL_OnUnitDamageChanged);

	-- Bind our function to the event callback
	Events.UnitDamageChanged.Add(OnUnitDamageChanged);
end

-- Our initialize
InitializeNow();
