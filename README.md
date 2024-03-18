## Alert Tracker mod for Thief 1 and 2

This is a mod that can be install to track NPC alert count.

It is based on the Radar mod from https://github.com/saracoth/newdark-mods

Similar to that mod, it adds a new Compass item into the inventory.

That item displays the count of alerts events that were reported internally by the game:
* First level alerts
* Second level alerts
* Hunts started

Item has two modes of operation:
* By default, it only acts as a counter
* If toggled, a message will be shown on screen for every alert or settling remark

### Limitations

* It's not possible right now to find if alert was because of the player or for some unrelated reason
  * This is ok for most missions, but in some of them, you will get many 'false' alerts because opposing factions on the map alert to each other
* 'Silent' alerts that happen during patrolling NPCs standing on 'Wait' action are still reported
  * This is often ok because you might hear a settling remark later
  * This might not be ok when NPC settles silently on the same 'Wait' point
  * Alerts during conversations are still counted
* Some missions are unfortunately incompatible (don't know why)
  * For example, 'Radar' mod doesn't work in 'Black Parade' and this mod doesn't work as well

### Installation

1. Click 'Code' and then 'Download ZIP' on Github.
2. Extract archive into 'usermods' directory inside thief_gold/thief2 game folder
3. Check that mod is extracted so that you have a 'thief_gold\USERMODS\sq_scripts\wib_alert_base.nut' file
4. You can delete LICENSE and README.md files, they are only informational
