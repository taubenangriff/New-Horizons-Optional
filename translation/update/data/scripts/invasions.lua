local InvasionFeatureUnlock = 1443234
local BuildupTimeUnlock = 1443335
local PyrphorianDefeatedUnlock = 1414020020
local InvasionChanceIncreasePerTick = 5
local InvasionBuildupProduct = 1440606
local InvasionProtectionProduct = 1414042213

math.randomseed(os.time())

local function StartInvasion()
    ts.Unlock.SetUnlockNet(InvasionFeatureUnlock);
end

local function ResetBuildup()
    ts.Economy.MetaStorage.AddAmount(InvasionBuildupProduct, -100000000)
end

local function IncreaseChance()
    ts.Economy.MetaStorage.AddAmount(InvasionBuildupProduct, InvasionChanceIncreasePerTick)
end

local function GetCurrentChance()
    return ts.Economy.MetaStorage.GetStorageAmount(InvasionBuildupProduct) / 10000
end


local function Update()
    print("Updating invasions...")
    -- use up Invasion protection first. If the player protects himself at a dumb time, it's their fault. 
    if(ts.Economy.MetaStorage.GetStorageAmount(InvasionProtectionProduct) > 0) then 
        ts.Economy.MetaStorage.AddAmount(InvasionProtectionProduct, -1)
        return
    end 
    -- Do nothing while Invasion is either active or buildup time hasn't run through
    if(ts.Unlock.GetIsUnlocked(InvasionFeatureUnlock)) then 
        return 
        print("Invasion is currently active. Discarding this spawn try.")
    end
    if(not ts.Unlock.GetIsUnlocked(BuildupTimeUnlock)) then 
        print("Invasion Buildup time has not ran through. Discarding this spawn try.")
        return 
    end
    if(ts.Unlock.GetIsUnlocked(PyrphorianDefeatedUnlock)) then 
        print("Pyrphorian Base has been defeated. Discarding this spawn try.")
        return 
    end

    local InvasionChance = GetCurrentChance()

    if math.random() < InvasionChance then 
        StartInvasion()
        ResetBuildup()
    else 
        IncreaseChance()
    end
end 

InvasionManager = {
    GetInvasionChance = GetCurrentChance,
    SetIncreaseChance = IncreaseChance,
    SetResetBuildup = ResetBuildup,
    StartInvasion = StartInvasion,
    Update = Update
}