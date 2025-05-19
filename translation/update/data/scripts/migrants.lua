-- These are the requirements for the perfect city
local MaxValues = 
{
    Attractivity = 2000,        -- An attractive City is a plus.
    PopulationCount = 13000,    -- City should be pretty large. 13k to fulfill this requirement fully.
    Happiness = 30,             -- They don't need more than 30 happiness to regard the city perfect
    Income = 10000,             -- 10k Coins in excess
    SatisfactionTier1 = 0.5,    -- Nongmin satisfied to at least 50%
    SatisfactionTier2 = 0.4,    -- Gongrens satisfied to at least 40%
    AverageLuxuryStorage = 200,  -- City should have a nice surplus of Luxury Goods
    MissingWorkforce = 1000      -- The city badly needs new workforce
}

-- These are the minimum requirements to spawn migrants
local MinValues =
{
    Attractivity = -100,        -- Dirty city is okay-ish
    PopulationCount = 300,      -- At least 300 population
    Happiness = 1,              -- At least positive happiness
    Income = 0,                 -- The city must at least have positive income
    SatisfactionTier1 = 0.3,    -- Nongmin need to be satisfied to at least 50%  
    SatisfactionTier2 = 0.2,    -- Gongren need to be satisfied to at least 40%
    AverageLuxuryStorage = 0,    -- Luxury is a Nice-to-Have
    MissingWorkforce = -500     -- The city has at least some need for new workforce.
}

local Weights = 
{
    Attractivity = 0.05,
    PopulationCount = 0.08,
    Happiness = 0.12,
    Income = 0.25,
    SatisfactionTier1 = 0.15,
    SatisfactionTier2 = 0.11,
    AverageLuxuryStorage = 0.05,
    MissingWorkforce = 0.18
}

local MaxChance = 0.55
local ChanceFactorPerTick = 0.05 -- A general multiplier so we can easily adjust to tick speed if we get too many migrants

-- there is no math.clamp function in anno so we have to write our own
function math.clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

local function GetLargestArea()
    local LargestArea = nil 
    local PopMax = 0
    for j=1,50 do 
        for possibleSession = 1,20 do -- Sessions are dynamic :(
            local AreaID = {
                SessionID = possibleSession,
                AreaIndex = 1,
                IslandID = j
            }
            if(ts.Area.GetArea(AreaID).IsOwnedByCurrentParticipant) then --only use Player area
                NongCount = ts.Area.GetArea(AreaID).Economy.GetPopulationCount(15100000)
                GongCount = ts.Area.GetArea(AreaID).Economy.GetPopulationCount(15100001)
                HasNong = NongCount > 0
                HasGong = GongCount > 0 
                local PopLocal = 0
                if(HasNong) then 
                    PopLocal = PopLocal + NongCount
                end
                if(HasGong) then 
                    PopLocal = PopLocal + GongCount
                end
                if(PopMax < PopLocal) then 
                    PopMax = PopLocal 
                    LargestArea = AreaID 
                end
            end
        end
    end
    return LargestArea
end

local function GetPercentage(current, min, max)
    clamped = math.clamp(current, min, max)
    return (clamped - min) / (max - min)
end

local function CalculateMigrantProbability(TargetArea)
    -- Migrants will never go to an active warzone
    local IsAtWar = ts.Area.GetArea(TargetArea).IslandWarActive
    if(IsAtWar) then    
        return 0
    end

    -- GET ISLAND STATS

    -- Required Stats
    local PopulationCount = ts.Area.GetArea(TargetArea).Economy.PopulationCount
    -- Satisfaction of Population
    local SatisfactionTier1 = ts.Area.GetArea(TargetArea).Economy.GetSatisfaction(15100000) -- average satisfaction of nongmin
    local SatisfactionTier2 = ts.Area.GetArea(TargetArea).Economy.GetSatisfaction(15100001) -- average satisfaction of gongren
    
     -- SatisfactionTier1 will be NaN when no Residents of Tier1 are settling on the island
    local HasTier1 = not SatisfactionTier1 ~= SatisfactionTier1
    if not HasTier1 then            -- Count Nongmin-less islands as if they are at minimum required supply
        SatisfactionTier1 = MinValues.SatisfactionTier1
    end    
    local HasTier2 = not SatisfactionTier2 ~= SatisfactionTier2 
    if not HasTier2 then            -- Count Gongren-less islands as if they are at minimum required supply
        SatisfactionTier2 = MinValues.SatisfactionTier2
    end    

    -- Required Factors: 
    -- Population Count > Min
    -- SatisfactionTier1 > Min 
    -- SatisfactionTier > Min
    -- HasTier1 or HasTier2

    if(PopulationCount < MinValues.PopulationCount or not(HasTier1 or HasTier2) or SatisfactionTier1 < MinValues.SatisfactionTier1 or SatisfactionTier2 < MinValues.SatisfactionTier2) then 
        return 0
    end

    -- General Island Stats
    local Attractivity = ts.Area.GetArea(TargetArea).Economy.Attractivity
    local Happiness = ts.Area.GetArea(TargetArea).Happiness.AverageHappiness
    local Income = ts.Area.GetArea(TargetArea).TotalIncome -- Share Income minus Debt. Should be positive

    -- Surplus Luxury in Storage: Umeshu, Porcelain and Sake
    local AverageLuxuryStorage = 
        ts.Area.GetArea(TargetArea).Economy.GetStorageAmount(1440220)
        + ts.Area.GetArea(TargetArea).Economy.GetStorageAmount(1440206)
        + ts.Area.GetArea(TargetArea).Economy.GetStorageAmount(1440216)
    AverageLuxuryStorage = AverageLuxuryStorage / 3

    -- How much workforce is missing in the city? (note, we multiply by -1 here because we compute the absolute workforce that is MISSING)
    local MissingWorkforce = (ts.Area.GetArea(TargetArea).Economy.GetDelta(15100002) + ts.Area.GetArea(TargetArea).Economy.GetDelta(15100003)) * -1

    -- COMPUTE PERCENTAGES
    local AttractivityFactor = GetPercentage(Attractivity, MinValues.Attractivity, MaxValues.Attractivity)
    local PopulationCountFactor = GetPercentage(PopulationCount, MinValues.PopulationCount, MaxValues.PopulationCount)
    local HappinessFactor = GetPercentage(Happiness, MinValues.Happiness, MaxValues.Happiness)
    local IncomeFactor = GetPercentage(Income, MinValues.Income, MaxValues.Income)
    local AverageLuxuryStorageFactor = GetPercentage(AverageLuxuryStorage, MinValues.AverageLuxuryStorage, MaxValues.AverageLuxuryStorage)
    local MissingWorkforceFactor = GetPercentage(MissingWorkforce, MinValues.MissingWorkforce, MaxValues.MissingWorkforce)
    local SatisfactionTier1Factor = GetPercentage(SatisfactionTier1, MinValues.SatisfactionTier1, MaxValues.SatisfactionTier1)
    local SatisfactionTier2Factor = GetPercentage(SatisfactionTier2, MinValues.SatisfactionTier2, MaxValues.SatisfactionTier2)

    local CalculatedPercentage = AttractivityFactor * Weights.Attractivity
        + PopulationCountFactor * Weights.PopulationCount
        + HappinessFactor * Weights.Happiness 
        + IncomeFactor * Weights.Income
        + AverageLuxuryStorageFactor * Weights.AverageLuxuryStorage
        + MissingWorkforceFactor * Weights.MissingWorkforce
        + SatisfactionTier1Factor * Weights.SatisfactionTier1
        + SatisfactionTier2Factor * Weights.SatisfactionTier2

    CalculatedPercentage = math.clamp(CalculatedPercentage, 0, MaxChance)
    return CalculatedPercentage * ChanceFactorPerTick
end

-- returns true with the given percentage chance. (chance range between 0 and 100)
function TryByChance(chance)
    return math.random() < (chance)
end

local function SpawnMigrants()
    ts.Conditions.RegisterTriggerForCurrentParticipant(1414040601)
end

local function EvaluateMigrants()
    LargestArea = GetLargestArea()
    if(LargestArea == nil) then 
        print("Largest Area evaluation failed, no Migrant spawning possible on this tick. This is entirely normal and no reason to worry.")
        return
    end
    Probability = CalculateMigrantProbability(LargestArea)
    if(NewHorizons.Migrants.CheatSkipChance) then 
        Probability = 1
    end
    if TryByChance(Probability) then 
        SpawnMigrants()
    end
end 

local function ToggleIgnoreMigrantChance()
    NewHorizons.Migrants.CheatSkipChance = not NewHorizons.Migrants.CheatSkipChance 
end

Migrants = {
    GetLargestArea = GetLargestArea,
    EvaluateMigrants = EvaluateMigrants,
    SetCheatSpawnMigrants = SpawnMigrants,
    ToggleIgnoreMigrantChance = ToggleIgnoreMigrantChance,
    CheatSkipChance = nil
}