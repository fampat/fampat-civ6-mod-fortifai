-- =============================================================================
-- FortifAI
-- Scaling the effectiveness of everything
-- =============================================================================

-- The global config file
include("FortifAIConfig.lua");

-- Calculate the clamped scale value
function effectScale(value)
	if value == 0.0 then return 0.0; end
	return (value * clampEffectScale());
end

function clampEffectScale()
	if (effectScaleValue > 2.0) then return 2.0; end
	if (effectScaleValue < 0.0) then return 0.0; end
	return effectScaleValue;
end

function Initialize()
	print("Initialized with effectScaleValue: "..effectScaleValue);
end

Initialize()
