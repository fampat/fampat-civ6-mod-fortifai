-- ========================================
-- FortifAI - Extension for UnitFlagManager
-- ========================================

-- Basegame context
include("UnitFlagManager");

-- Add a log event for loading this
print("Loading UnitFlagManager_FAI.lua");

-- Original function bindings
ORIGINAL_OnInit = OnInit;
ORIGINAL_OnUnitDamageChanged = OnUnitDamageChanged;

-- Define our event (overrides the original-event via event-rebind in InitializeNow())
function FAI_OnUnitDamageChanged(playerID : number, unitID : number, newDamage : number, oldDamage : number)
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

function FAI_OnInit(isHotload)
	-- Trigger the original init
	ORIGINAL_OnInit(isHotload);

	-- Unbind the original callback for damage and heal
	Events.UnitDamageChanged.Remove(ORIGINAL_OnUnitDamageChanged);

	-- Bin our version (FAI enhanced)
	Events.UnitDamageChanged.Add(FAI_OnUnitDamageChanged);
end

-- Our custom initialize
function Initialize_FAI_UnitFlagManager()
  -- Log execution
	print("UnitFlagManager_FAI.lua: Initialize_FAI_UnitFlagManager")

	-- Change context-init to our function
	ContextPtr:SetInitHandler(FAI_OnInit);
end

-- Our initialize
Initialize_FAI_UnitFlagManager();
