// Created by Claris (Twitter @ClarisRobyn), please let me know of any bugs or other issues.

state("SonicMania", "Mania Plus V1.05.0713")
{
	// Values for splits
	byte CurrentLevel : 0xA9C5D4, 0x444358;
	byte ScoreTallyCheck : 0x462F56;
	byte TM2BossHealth : 0x476CA4;
	byte EREggmanHealth : 0x475B44;
	byte ERHeavyHealth : 0x4715CC;
	
	// Values for the Puyo split
	short Character1PositionX : 0x45E9A2; // Position is used to check when the player is in the Puyo area
	short Character1PositionY : 0x45E9A6;
	byte CharacterControl : 0x45E9EC; // If 0, the player disappears and control is taken away
	
	// Values for resets
	byte GameState : 0xA48776; // 8 when Dev Menu is open
	byte SavedLevel : 0xA48758; // Used to check when on the menu, as "CurrentLevel" does not work for that	
	
	// Values for starting the run. I have no idea what exactly the next two values are, but they seem to work for these purposes
	byte StartCheck : 0x4D01A8; // Is 80 on the menu and changes to 128 when a game is started
	byte StartingLevelCheck : 0x93ACA9; // Is 40 for new game or Green Hill (Mania), or 0 for new game or Green Hill (Encore), or after exiting back to the menu. Anything else means a different zone was selected
	byte DebugEnabled : 0x4B6EB4; // 0 if disabled, 1 if enabled
	
	// Emeralds and characters for checking for Egg Reverie
	byte Emeralds : 0xABB9B8, 0x10, 0x70; // One bit for each emerald, 0x7F when all emeralds are collected
	byte Character1 : 0xA9C5D4, 0x4;
	byte Character2 : 0xA9C5D4, 0x5;
}

startup
{
	settings.Add("PuyoSplit", false, "Split at the start of the Chemical Plant 2 Mean Bean boss");	
	refreshRate = 60;
}

init
{
	// This is how most other scripts I've looked at check for game version, so I'm just assuming this works fine
	if (modules.First().ModuleMemorySize == 0x72E8000)
		version = "Mania Plus V1.05.0713";
}

update
{
	// Don't run if the game isn't V1.05.0713
	if (version == "")
		return false;
		
	// Check if it's the final level, first checking for Encore Mode
	if (current.CurrentLevel == 64 && current.TM2BossHealth == 16) 
	{
		vars.EndOnTM = true;
	} 
	// If Mania Mode, make sure Egg Reverie won't be played; checks for all emeralds, and if so checks for either Sonic, or Knuckles + Knuckles
	else if (current.CurrentLevel == 36 && current.TM2BossHealth == 16 && !(current.Emeralds == 0x7F && (current.Character1 == 1 || (current.Character1 == 4 && current.Character2 == 4)))) 
	{
		vars.EndOnTM = true;
	}
	// Egg Reverie
	else if (current.CurrentLevel == 37 && current.EREggmanHealth == 8)
		vars.EndOnER = true;
}

start
{
	// Doesn't start if Debug is enabled. Doesn't start if beginning from a zone later than Green Hill
	if (current.StartCheck == 128 && old.StartCheck == 80 && current.DebugEnabled == 0 && (current.StartingLevelCheck == 40 || current.StartingLevelCheck == 0))
	{
		vars.EndOnTM = false;
		vars.EndOnER = false;
		vars.UpdateCount = 0;
		vars.LatestLevel = 0;
		vars.FalseStart = false;
		vars.ScoreTallySplit = false;
		vars.PuyoSplit = settings["PuyoSplit"];
		return true;
	};
}

reset
{
	// Reset on going back to the menu, when a false start is detected, or when the dev menu is opened
	return (current.SavedLevel == 2 && current.SavedLevel != old.SavedLevel) || vars.FalseStart || current.GameState == 8;
}

split
{	
	// Increase Update Count, used for telling how long the time has been running
	vars.UpdateCount++;

	// Split whenever it starts a new level
	if (current.CurrentLevel != old.CurrentLevel && current.CurrentLevel > vars.LatestLevel)
	{
		print("Attempting split for new level! Current: " + current.CurrentLevel);
		vars.LatestLevel = current.CurrentLevel;
		switch ((byte)current.CurrentLevel)
		{
			case 0: // Menus/cutscenes/etc.
			case 9: // GH1
			case 21: // SS2M
			case 31: // LR3
			case 36: // TM3
			case 50: // SS2M+
			case 59: // LR3+
			case 64: // TM3+
				return false;
			case 18: // PG2
			case 28: // OO2
			case 47: // PG2+
			case 56: // OO2+
				vars.ScoreTallySplit = true;
				return false;
			case 38: // GH1+, make sure enough time has passed so it doesn't split on a NG+ run
				return vars.UpdateCount > 120;
			default:
				// Workaround to avoid a potential false start
				if (vars.UpdateCount < 120)
				{
					vars.FalseStart = true;
					return false;
				}
				return true;
		}
	}
	
	// Split for Puyo if that option is enabled. Checks if the player position is in the Puyo area and that control has been taken away. There's got to be a less complicated way to check than this but this works for now
	if (vars.PuyoSplit && (current.CurrentLevel == 12 || current.CurrentLevel == 41) && current.CharacterControl == 0 && current.Character1PositionX > 7125 && current.Character1PositionX < 7155 && current.Character1PositionY > 2300 && current.Character1PositionY < 2330)
	{
		print("Split for Puyo boss!");
		vars.PuyoSplit = false;
		return true;
	}
	
	// Press Garden and Oil Ocean switch to Act 2 early, before the score tally. Split after the score tally instead for these two zones
	if (vars.ScoreTallySplit && current.ScoreTallyCheck == 0 && old.ScoreTallyCheck == 32)
	{
		print("Split after score tally!");
		vars.ScoreTallySplit = false;
		return true;
	}
	
	// Split when the TM2 boss dies if the game ends there
	if (vars.EndOnTM && (current.TM2BossHealth == 0 || current.TM2BossHealth == 255))
	{
		print("Split for TM ending!");
		vars.EndOnTM = false;
		return true;
	}
	
	// Split for ER when both bosses are dead
	if (vars.EndOnER && current.EREggmanHealth == 0 && current.ERHeavyHealth == 0)
	{
		print("Split for ER ending!");
		vars.EndOnER = false;
		return true;
	}
}
