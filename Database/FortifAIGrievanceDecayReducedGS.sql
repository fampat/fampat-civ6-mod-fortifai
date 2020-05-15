-- FortifAIGrievance
-- Author: Fampat, thanks and credits to zee
-- Reduces the grievance decay (depends on era)
-----------------------------------------------

-- From default decay of 10
UPDATE Eras_XP2 SET GrievanceDecayRate = 7 WHERE EraType = 'ERA_ANCIENT';

-- From default decay of 9
UPDATE Eras_XP2 SET GrievanceDecayRate = 6 WHERE EraType = 'ERA_CLASSICAL';

-- From default decay of 8
UPDATE Eras_XP2 SET GrievanceDecayRate = 5 WHERE EraType = 'ERA_MEDIEVAL';

-- From default decay of 7
UPDATE Eras_XP2 SET GrievanceDecayRate = 4 WHERE EraType = 'ERA_RENAISSANCE';

-- From default decay of 6
UPDATE Eras_XP2 SET GrievanceDecayRate = 4 WHERE EraType = 'ERA_INDUSTRIAL';

-- From default decay of 5
UPDATE Eras_XP2 SET GrievanceDecayRate = 3 WHERE EraType = 'ERA_MODERN';

-- From default decay of 4
UPDATE Eras_XP2 SET GrievanceDecayRate = 2 WHERE EraType = 'ERA_ATOMIC';

-- From default decay of 3
UPDATE Eras_XP2 SET GrievanceDecayRate = 1 WHERE EraType = 'ERA_INFORMATION';
