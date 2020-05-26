-- ================================================
--	FortifAIMessages
--	UI messages - displays fortifai custom messages
-- ================================================

-- Includes
include( "InstanceManager" );

-- Display default time, ten seconds
local DEFAULT_TIME_TO_DISPLAY = 7;

-- Message handling variables
local messageIM = InstanceManager:new("FortifAIMessageInstance", "FortifAIMessageContainer", Controls.FortifAIMessageStack);

-- Callback for handling messsage-requests
function OnStatusMessage(message, messageDisplayTimeSec)
	-- If a message has been set
	if message ~= nil then
		-- Fetch the stack of message InGame-Context of lua/xml file: Base/Assets/UI/Panels/StatusMessagePanels.lua/xml
		local defaultStack = ContextPtr:LookUpControl("/InGame/StatusMessagePanel/DefaultStack");

		-- If its present, continue
		if defaultStack ~= nil then
			-- Append this messages to the status-messages
			Controls.FortifAIMessageStack:ChangeParent(defaultStack);
		end

		-- UI Instancing
		local messageInstance = messageIM:GetInstance();

		-- Display time
		local timeToDisplay = (messageDisplayTimeSec ~= nil and messageDisplayTimeSec > 0) and messageDisplayTimeSec or DEFAULT_TIME_TO_DISPLAY;

		-- Each messages instance configurations and text
		messageInstance.Message:SetText(message);
		messageInstance.Anim:SetEndPauseTime(timeToDisplay);
		messageInstance.Anim:RegisterEndCallback(function() removeMessage(messageInstance, defaultStack) end);
		messageInstance.Anim:SetToBeginning();
		messageInstance.Anim:Play();
		messageInstance.Button:RegisterCallback(Mouse.eLClick, function() removeMessage(messageInstance, defaultStack) end);

		-- Caclulate stack sizes after instancing
		Controls.FortifAIMessageStack:CalculateSize();
		Controls.FortifAIMessageStack:ReprocessAnchoring();
		defaultStack:CalculateSize();
		defaultStack:ReprocessAnchoring();
	end
end

-- Message removal
function removeMessage(messageInstance, defaultStack)
	if (messageInstance ~= nil) then
		-- Remove tha callback
		messageInstance.Anim:ClearEndCallback();
		messageIM:ReleaseInstance(messageInstance);

		-- Caclulate stack size after instances has been released
		if (Controls.FortifAIMessageStack ~= nil) then
			Controls.FortifAIMessageStack:CalculateSize();
			Controls.FortifAIMessageStack:ReprocessAnchoring();
		end

		-- Caclulate stack size after instances has been released
		if (defaultStack ~= nil) then
			defaultStack:CalculateSize();
			defaultStack:ReprocessAnchoring();
		end
	end
end

-- Init, uknow...
function Initialize()
	-- Map the status-message function to a exposed member
	ExposedMembers.StatusMessage = OnStatusMessage;

	--Init message log
	print("Initialized.");
end

Initialize();
