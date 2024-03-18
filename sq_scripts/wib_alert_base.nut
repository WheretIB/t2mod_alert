// NOTE: To keep installation simpler, all scripting is handled in this file.
// However, some functionality only kicks in when extra DML files are installed
// to enable those features.

// While I've been able to scan *all* object IDs in a level in a single tick
// of a script timer without issue, it might be wise to spread that out over
// time for performance or other reason.
const MAX_SCANNED_PER_LOOP = 500;
// Set this to lower than MAX_SCANNED_PER_LOOP to limit how many points of
// interest will be registered in a single pass through the level scanning.
const MAX_INITIALIZED_PER_LOOP = 50000;
// If our object scanning has this many completely empty loops in a row, we
// consider the scan complete. There's no way I can see to know how many
// objects exist in a level, object IDs can have gaps in them, and object IDs
// can even be reused as objects are destroyed and created. This should be set
// high enough to be thorough, but not so high as to waste time on empty space.
const MAX_EMPTY_SCAN_GROUPS = 3;

// This metaproperty allows us to listen to alertness messages the AI receives
const POI_ATTACHED = "WibAlertPoiAttached";

const AINonHostilityEnum_kAINH_Always = 6;

wibAlarmMessages <- []
wibLastAlertState <- {}

function PreFilterMessage(message)
{
	if (message.message == "Alertness")
	{
		print("PreFilterMessage Alertness")

		local copy = {}
		
		copy.oldLevel <- message.oldLevel
		copy.level <- message.level
		copy.from <- message.from
		copy.to <- message.to

		wibAlarmMessages.append(copy)
	}
	
	/*if (message.message != "Timer")
	{
		print(message.message);

		//DarkUI.TextMessage(message.message, 0, 2000);
	}*/

	// return 'true' if message should be intercepted and not sent to the target script instance
	return false;
}

// This script goes on an inventory item
class WibAlertToggler extends SqRootScript
{
	function OnBeginScript()
	{
		print("WibAlertToggler OnBeginScript")

		SetOneShotTimer("WipUpdateTimer", 0.25);
	}

	function GetDataOr(name, def)
	{
		local result = GetData(name);

		if (!result)
			result = def;

		return result;
	}

	function FormatUiMessage()
	{
		local firstAlerts = GetDataOr("FirstAlerts", 0);
		local secondAlerts = GetDataOr("SecondAlerts", 0);
		local thirdAlerts = GetDataOr("ThirdAlerts", 0);
		local showAlertMessages = GetData("ShowAlertMessages");

		if (showAlertMessages)
			return format("name_wib: \"%i first alert(s)\n%i second alert(s)\n%i hunt(s)\n(Alert display ON)\"", firstAlerts, secondAlerts, thirdAlerts);

		return format("name_wib: \"%i first alert(s)\n%i second alert(s)\n%i hunt(s)\n(Alert display OFF)\"", firstAlerts, secondAlerts, thirdAlerts);
	}

	function OnFrobInvEnd()
	{
		local showAlertMessages = GetData("ShowAlertMessages");
		showAlertMessages = !showAlertMessages;
		SetData("ShowAlertMessages", showAlertMessages);

		Property.SetSimple(self, "GameName", FormatUiMessage());
	}
	
	// From Radar mod
	function IsAlertingTarget(target)
	{
		// Other states: Asleep, Efficient, Super Efficient, Normal, and Combat
		if (Property.Get(target, "AI_Mode") == eAIMode.kAIM_Dead)
		{
			print(format("IsAlertingTarget(%i) Target is dead", target))
			return false;
		}
		
		// Lobotomized AI are commonly used for corpses placed in the mission editor.
		if (Property.Get(target, "AI") == "null")
		{
			print(format("IsAlertingTarget(%i) AI is null", target))
			return false;
		}
		
		// Ignore nonhostiles
		local team = Property.Possessed(target, "AI_Team") ? Property.Get(target, "AI_Team") : -1;
		
		if (team == eAITeam.kAIT_Good)
		{
			print(format("IsAlertingTarget(%i) Team is good", target))
			return false;
		}
		
		if (team == eAITeam.kAIT_Neutral)
		{
			print(format("IsAlertingTarget(%i) Team is neutral", target))
			return false;
		}

		// Rats aren't neutral, but may as well be.
		// Inform others is false, non-hostile is Always,
		// and uses doors is false. AI is SimpleNC. Plus
		// Small Creature: true, this recipe should make
		// any creature effectively neutral. There may be
		// some weird scripting or source/receptron stuff,
		// but in general, better to treat them as neutral.
		if (
			// Smol == true.
			!!Property.Get(target, "AI_IsSmall")
			// Never hostile.
			&& Property.Get(target, "AI_NonHst") == AINonHostilityEnum_kAINH_Always
			// Informs others == false.
			&& !Property.Get(target, "AI_InfOtr")
			// Opens doors == false.
			&& !Property.Get(target, "AI_UsesDoors")
			// Simple noncombatant AI.
			&& Property.Get(target, "AI", "Behavior set") == "SimpleNC"
		)
		{
			print(format("IsAlertingTarget(%i) Team is a rat", target))
			return false;
		}
		
		return true;
	}

	function OnTimer()
	{
		//print("WibAlertToggler OnTimer")

		if (message().name != "WipUpdateTimer")
			return;

		// Check if we have something to process
		if (wibAlarmMessages.len() == 0)
		{
			// Repeat forever
			SetOneShotTimer("WipUpdateTimer", 0.25);
			return;
		}

		local str = ""
		
		local firstAlerts = GetDataOr("FirstAlerts", 0);
		local secondAlerts = GetDataOr("SecondAlerts", 0);
		local thirdAlerts = GetDataOr("ThirdAlerts", 0);
		local showAlertMessages = GetData("ShowAlertMessages");

		// Handle the queue of messages
		for (local i = 0; i < wibAlarmMessages.len(); i++)
		{
			local msg = wibAlarmMessages[i]
			
			print(format("Alertness message: %i -> %i (%i %i)", msg.oldLevel, msg.level, msg.from, msg.to))

			local lastLevel = msg.to in wibLastAlertState ? wibLastAlertState[msg.to] : 0;
			wibLastAlertState[msg.to] <- msg.level

			local linkedToArchetype = Object.Archetype(msg.to);
			local name = Object.GetName(linkedToArchetype);

			if (lastLevel >= 1 && msg.level == 0)
				str = format("%s\n%s has settled", str, name);

			if (msg.level <= lastLevel)
				continue;

			if (!IsAlertingTarget(msg.to))
				continue;

			if (msg.level == 1)
			{
				str = format("%s\nFirst Alert from %s", str, name);
				firstAlerts = firstAlerts + 1;
			}
			else if (msg.level == 2)
			{
				str = format("%s\nSecond Alert from %s", str, name);
				secondAlerts = secondAlerts + 1;
			}
			else if (msg.level == 3)
			{
				str = format("%s\nHunt from %s", str, name);
				thirdAlerts = thirdAlerts + 1;
			}

			/*if (Property.Possessed(msg.to, "AI_Alertness"))
			{
				local prop = Property.Get(msg.to, "AI_Alertness");

				str = format("%s\nGot alertness %i", str, prop);
			}*/
		}

		SetData("FirstAlerts", firstAlerts);
		SetData("SecondAlerts", secondAlerts);
		SetData("ThirdAlerts", thirdAlerts);

		Property.SetSimple(self, "GameName", FormatUiMessage());

		if (showAlertMessages)
			DarkUI.TextMessage(str, 0, 2000);

		wibAlarmMessages.clear()

		// Repeat forever
		SetOneShotTimer("WipUpdateTimer", 0.25);
	}
}

class WibAlertPoiListener extends SqRootScript
{
	/*function OnAlertness()
	{
		DarkUI.TextMessage("OnAlertness", 0, 2000);
	}
	function OnActionProgress()
	{
		DarkUI.TextMessage("OnActionProgress", 0, 2000);
	}
	function OnGoalProgress()
	{
		DarkUI.TextMessage("OnGoalProgress", 0, 2000);
	}
	function OnModeChange()
	{
		DarkUI.TextMessage("OnModeChange", 0, 2000);
	}
	function OnGoalChange()
	{
		DarkUI.TextMessage("OnGoalChange", 0, 2000);
	}
	function OnPatrolPoint()
	{
		DarkUI.TextMessage(format("OnPatrolPoint %i %i", message().to, message().patrolObj), 0, 2000);
	}
	function OnAIModeChange()
	{
		DarkUI.TextMessage(format("OnAIModeChange %i %i %i", message().to, message().mode, message().previous_mode), 0, 2000);
	}
	function OnActionChange()
	{
		DarkUI.TextMessage(format("OnActionChange %i", message().to), 0, 2000);
	}*/
}

// This script will be called on the player when the game starts, giving them a particular item.
class WibAlertGiveItem extends SqRootScript
{
	function GiveItemIfNeeded(whatItem)
	{
		// See comments below about the infinite recursion this addresses.
		local dataKey = "WibAlertGiving_" + whatItem;
		if (IsDataSet(dataKey))
		{
			print(format("WibAlert: Already working on giving %s", whatItem));
			return;
		}
		
		// Assuming this script is attached to the player, "self" refers
		// to that player. Every object with a "Contains" type link is
		// stuff in the player's inventory.
		local playerInventory = Link.GetAll("Contains", self);
		
		// Assume they don't have the desired item until we prove otherwise.
		local hasTheItem = false;
		// It may be possible to use the string directly everywhere we use
		// this variable, but it's probably less efficient than doing the
		// ID lookup once and storing the result. This approach was used
		// in the HolyH2O script sample as well.
		local theItemId = ObjID(whatItem);
		
		// Loop through everything in the player's inventory to find the token.
		foreach (link in playerInventory)
		{
			// Is the inventory item an instance of the wanted item?
			// (InheritsFrom *might* also detect other kinds of items based
			// on the archetype as well, but that's not relevant to this mod.)
			if ( Object.InheritsFrom(LinkDest(link), theItemId) )
			{
				// The player already has the item!
				hasTheItem = true;
				// So we can stop looking through their inventory.
				break;
			}
		}
		
		// If the player doesn't already have the item...
		if (!hasTheItem)
		{
			// Then create one and give it to them.
			SetData(dataKey, true);
			
			print(format("WibAlert: Giving player a %s", whatItem));
			
			// NOTE: In SS2, for some reason this resulted in a recursive
			// stack overflow going from OnBeginScript to GiveItemIfNeeded
			// to native code, and repeating those three infinitely :/
			Link.Create(LinkTools.LinkKindNamed("Contains"), self, Object.Create(theItemId));
			
			ClearData(dataKey);
		}
		else
		{
			print(format("WibAlert: Already gave %s", whatItem));
		}
	}

	// We only need this script to fire once, when the game simulation first starts.
	function OnSim()
	{
		print("WibAlertGiveItem OnSim")
		
		if (message().starting)
		{
			GiveItemIfNeeded("WibAlertControlItem");
		}
	}
}

// This script goes on one marker we add to every mission. It sets up and
// tears down the overlay handler. We also use it to pass along messages
// to the overlay handler, including persisted data with SetData()/GetData()
class WibAlertUi extends SqRootScript
{
	// A destructor function that removes the handler is a best practice
	// recommended by the sample overlay code that comes with NewDark.
	// Both the OnEndScript and destructor will generally do the same,
	// or nearly the same things.
	function destructor()
	{
	}
	
	// Per sample documentation, it's best practice to tear down the
	// overlay both when this instance is destroyed and when it
	// receives an EndScript message.
	function OnEndScript()
	{
		// Given that we have multiple things to do when tearing down
		// the handler, all that code was moved to the destructor, which
		// we can call by hand.
		destructor();
	}
	
	// This will trigger in Thief-like games, but not Shock-engine ones.
	function OnSim()
	{
		if (message().starting)
		{
			print("WibAlert: WibAlertUi OnSim starting");
			QueueNewScan(0.01);
		}
	}
	
	// This will fire on start of mission and after reloading saves.
	function OnBeginScript()
	{
		print("WibAlert: WibAlertUi OnBeginScript fired");
		
		QueueNewScan(0.01);
	}
	
	function QueueNewScan(afterDelay)
	{
		// Don't do anything if a scan is already scheduled.
		if (IsDataSet("ConsecutiveEmptyGroups"))
			return;
		
		// Start with objects 1 through whatever.
		SetData("AddToScanId", 1);
		SetData("ConsecutiveEmptyGroups", 0);

		SetOneShotTimer("WibAlertMissionScan", afterDelay);
	}
	
	function InitPointOfInterestIfNeeded(forItem)
	{
		// Do some quick checks up front.
		if (
			// Stopped existing.
			!Object.Exists(forItem)
			// Or it's already been processed
			|| Object.HasMetaProperty(forItem, POI_ATTACHED)
		)
		{
			return false;
		}

		Object.AddMetaProperty(forItem, POI_ATTACHED);
		return true;
	}

	// So the thing is, we don't know how many objects are in the
	// mission. We know they have numeric IDs, generally starting
	// from about 1 or so, and they count up from there. However,
	// gaps are possible if items are ever deleted. So we'll loop
	// through until we find enough "missing" items to feel like
	// we've found everything we're ever going to find.
	function OnTimer()
	{
		if (message().name != "WibAlertMissionScan")
			return;
		
		//print("WibAlert: Scanning area...");
		
		// We will scan objects down to and including this value.
		local scanFromInclusive = GetData("AddToScanId");

		//if (scanFromInclusive == 1) DarkUI.TextMessage("Scanning area....", 0, 1000);
		
		// We will scan objects up to and excluding this value.
		local scanCapExclusive = scanFromInclusive + MAX_SCANNED_PER_LOOP;
		// Unless we bail out early, the next round of scans
		// will start here.
		SetData("AddToScanId", scanCapExclusive);
		
		// We need these variables to help track our loop ending
		// logic.
		local consecutiveEmptyGroups = GetData("ConsecutiveEmptyGroups");
		local scannedAny = false;
		
		// If creating a lot of POI items becomes a performance
		// or other concern, MAX_INITIALIZED_PER_LOOP can limit
		// how many of those we spin up on each loop.
		local initializeCount = 0;

		// Loop through all the item IDs we're going to test this time.
		for (local i = scanFromInclusive - 1; ++i < scanCapExclusive; )
		{
			// If we exceeded our limit, save this index for the next
			// loop pass instead.
			if (initializeCount > MAX_INITIALIZED_PER_LOOP)
			{
				SetData("AddToScanId", i);
				break;
			}
			
			if (Object.Exists(i))
			{
				if (!Property.Possessed(i, "AI_Alertness"))
					continue;

				if (Property.Get(i, "AI_Mode") == eAIMode.kAIM_Dead)
					continue;
				
				if (Property.Get(i, "AI") == "null")
					continue;

				scannedAny = true;

				// If the object is a POI
				if (InitPointOfInterestIfNeeded(i))
				{
					print(format("WibAlert: Object %i is a point of interest", i));

					// And increment the counter if we did initialize it.
					++initializeCount;
				}
			}
		}

		// Track how many consecutive scan groups came up empty and,
		// if needed, halt scanning.
		if (!scannedAny)
		{
			// Increment and test consecutiveEmptyGroups.
			if (++consecutiveEmptyGroups > MAX_EMPTY_SCAN_GROUPS)
			{
				// We're done! Break the loop. We'll re-scan all
				// the objects again periodically, to cover any
				// new-to-the-mission items.
				ClearData("ConsecutiveEmptyGroups");
				
				//DarkUI.TextMessage("Scan complete.", 0, 1000);
				
				QueueNewScan(5.00);
				return;
			}
			
			// Remember the incremented value for later.
			SetData("ConsecutiveEmptyGroups", consecutiveEmptyGroups);
		}
		else if (consecutiveEmptyGroups > 0)
		{
			// We had an empty patch, but we found something this
			// time. Go back to a clean slate.
			SetData("ConsecutiveEmptyGroups", 0);
		}
		
		// Repeat! We're staggering the scans over time to avoid a
		// potential start-of-level lag spike, but in practice that
		// doesn't seem to be an issue. Still, better safe than sorry.
		SetOneShotTimer("WibAlertMissionScan", 0.1);
	}
}
