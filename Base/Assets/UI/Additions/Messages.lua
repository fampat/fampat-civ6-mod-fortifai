-- ================================================
--	FortifAIMessages
--	UI messages - displays fortifai custom messages
-- ================================================

-- Includes
include( "InstanceManager" );

-- Display default time, ten seconds
local DEFAULT_TIME_TO_DISPLAY = 10;

-- Message handling variable
local m_fortifAIIM = InstanceManager:new( "FortifAIMessageInstance", "Root", Controls.StackOfFortifAIMessages );
local m_kMessages = {};

function OnStatusMessage(message, fDisplayTime)
	-- If a meesage has been set
	if message ~= nil then
		-- Instance handling
		local kTypeEntry = m_kMessages[0];

		-- Message type
		if (kTypeEntry == nil) then
			m_kMessages[0] = {
				InstanceManager = nil,
				MessageInstances= {}
			};

			-- Dunno... stuff nonetheless
			kTypeEntry = m_kMessages[0];
			kTypeEntry.InstanceManager	= m_fortifAIIM;
		end

		-- UI Instancing
		local pInstance:table = kTypeEntry.InstanceManager:GetInstance();
		table.insert(kTypeEntry.MessageInstances, pInstance);

		-- Display time relative to each other
		local timeToDisplay:number = (fDisplayTime > 0) and fDisplayTime or DEFAULT_TIME_TO_DISPLAY;

		-- Each messages instance configurations and text
		pInstance.StatusLabel:SetText(message);
		pInstance.Anim:SetEndPauseTime(timeToDisplay);
		pInstance.Anim:RegisterEndCallback(function() OnEndAnim(kTypeEntry,pInstance) end);
		pInstance.Anim:SetToBeginning();
		pInstance.Anim:Play();
		pInstance.Button:RegisterCallback(Mouse.eLClick, function() OnMessageClicked(kTypeEntry, pInstance) end);

		-- Possible not needed because this messages get attached to the base-game status.messages
		Controls.StackOfFortifAIMessages:CalculateSize();
		Controls.StackOfFortifAIMessages:ReprocessAnchoring();
	end
end

-- Attach the custom fortifai messages to the default status message stack
function AttachMessageToStatusMessages ()
	-- Fetch the stack of message InGame-Context of lua/xml file: Base/Assets/UI/Panels/StatusMessagePanels.lua/xml
	local StackOfMessages:table = ContextPtr:LookUpControl("/InGame/StatusMessagePanel/StackOfMessages");

	-- If its present, continue
	if StackOfMessages ~= nil then
		-- Append this messages to the status-messages
		StackOfMessages:AddChildAtIndex(Controls.StackOfFortifAIMessages, 1);

		-- Re-anchor and calculation for proper display
		StackOfMessages:CalculateSize();
		StackOfMessages:ReprocessAnchoring();
	end
end

-- Remove the message after its timeouted
function OnEndAnim(kTypeEntry, pInstance)
	RemoveMessage(kTypeEntry, pInstance);
end

-- Remove message on click
function OnMessageClicked(kTypeEntry, pInstance)
	RemoveMessage(kTypeEntry, pInstance);
end

-- Message removal helper
function RemoveMessage(kTypeEntry, pInstance)
	pInstance.Anim:ClearEndCallback();
	Controls.StackOfFortifAIMessages:CalculateSize();
	Controls.StackOfFortifAIMessages:ReprocessAnchoring();
	kTypeEntry.InstanceManager:ReleaseInstance(pInstance);
end

-- What to do if the game view is initialized
function OnLoadGameViewStateDone()
	-- We attach our messages to the status message, its modding afterall isnt it?
	AttachMessageToStatusMessages();
end

-- Init, uknow...
function Initialize()
	-- Add event handle for done initializing game view
	Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);

	-- Map the status-message funtion to a exposed member
	ExposedMembers.StatusMessage = OnStatusMessage;

	-- Init message log
	print("Initialized.");
end

Initialize();
