# Configuration Guide

The **Appearance** page provides live themes, accents, menu and text sizing,
opacity, focus outlines, animation preferences, notifications and action-bar
presets. These options are saved in profiles. See [Appearance](Appearance.md).

Open the configuration panel with `/controller`.
The sidebar includes Controller, Help & Tutorials, Gameplay, Interface, Bars,
Bindings, Profiles, and Share Profile.

Settings use one preference or action per row. Up/down selects the next row;
left/right adjusts numbers, toggles or choices without entering a popup. Confirm
opens an action or text field. Back returns to the categories, then closes the
window. Each page remembers focus and scrolls the selected row into view.

## Controller

The **Controller** page reports whether the native bridge and controller are ready,
shows prompts for the selected controller type, and lists the main controller
controls. Its **Bindings** and **Action Bars** shortcuts open those settings pages
and move controller focus to their first available control. **Controller Type**
opens Interface and focuses the Xbox/PlayStation prompt selector.

| Setting | Description | Default |
|---------|-------------|---------|
| Radial selection stick | Choose Left, Right, or Both for the quick menu and utility rings. A centered unused stick does not clear selection. Saved with your profile. | Both |
| Camera speed | Adjust with left/right in steps of 50. Requires the mouse bridge. Range: 100-3000. | 850 |
| Pointer speed | Adjust cursor movement independently of camera turning. Range: 100-3000. | 850 |
| Left-stick deadzone | Ignore centered-stick drift; adjust from 5% to 45% in 1% steps. Requires DLL 0.3.1. | 24% |
| Right-stick deadzone | Ignore camera/pointer drift; adjust from 5% to 45% in 1% steps. Requires DLL 0.3.1. | 27% |
| Calibrate sticks | Release both sticks for one second. Saves measured drift plus a 4% margin. Moving controls during measurement cancels calibration. | Manual |
| Show controller diagnostics | Show a small on-screen readout of connection and input details for troubleshooting | Off |

For native input, center both sticks and release every button after entering the
world. Native input enables left-stick movement, left-stick menu navigation,
button actions, and radial selection with the configured sticks. The optional mouse bridge enables right-stick
camera movement in the world and pointer movement in standard menus. With that
bridge, RS/R3 switches between camera and pointer movement in the world, and
between focused actions and pointer clicks in menus. Without it, D-pad focus
navigation still works and RS/R3 reports that mouse input is unavailable.
A keyboard-mapped controller can use the addon's in-game key bindings without
the native DLL. Assign mapper outputs to action slots under **Windrunner
Experience** and the radial-menu toggle under **Quick Menu** in WoW's **Key
Bindings** menu. While a supported UI is open, mapped face and D-pad buttons
use the focused control; buttons without a menu action are ignored. Healer Mode
keeps its focused group-member casts. Use **Cursor Navigation** for extra menu
movement and click keys. Direct XInput, DualSense,
analog-stick input, and native connection status require the optional
controller package.

Calibration waits for its activating controller button to be released. Gameplay
stays stopped during measurement and rearms on a fresh neutral sample afterwards.
Calibration cancels on focus loss, disconnect, or device replacement. Older DLLs
still support ordinary input, but deadzone controls stay disabled until the new
DLL loads. Previous sensitivity settings are used for both speeds until changed.

Healer Mode keeps left-stick movement and right-stick camera control while the
D-pad selects group members. Face and bumper actions use the current trigger
page; healing targets the selected member and restores your previous target.
Opening a regular menu suspends gameplay movement until the menu closes.

Numeric fields can be adjusted with the increase/decrease controls beside them.
Select a text field and press **A** to type with the virtual keyboard; **ENTER**
applies the edit, while **B** or **Escape** cancels it. If the virtual keyboard is
disabled, **B** or **Escape** leaves a focused text field without closing its
settings page.

## Help & Tutorials

This page repeats the controller setup steps, explains the core menu controls and
virtual keyboard, and provides buttons that jump directly to Controller,
Interface, Bars, and Bindings settings.

## Interface

### General

| Setting | Description | Default |
|---------|-------------|---------|
| Controller Type | Show Xbox or PlayStation prompts; setup also offers Switch-style and Steam Deck labels | Xbox |
| Healer Mode | Use the D-pad to choose a player, party, or raid frame; action bar buttons cast on that unit | Off |
| Dropdown Navigation | Enable controller cursor navigation inside dropdown menus | On |
| Debug Logging | Show detailed addon messages in chat for troubleshooting | Off |
| Language | Addon interface language; follows the game language until changed. A UI reload applies a language change. | Game language |
| Open all bags at vendor | Open bags when interacting with merchants, the auction house, or the bank | On |

### Crosshair

| Setting | Description | Default |
|---------|-------------|---------|
| Enable Crosshair | Show a targeting crosshair | On |
| X Offset | Horizontal position | 0 |
| Y Offset | Vertical position | 50 |
| Size | Crosshair size in pixels | 24 |
| Type | Cross or dot | Cross |
| Color | Color and opacity picker | White (80% opacity) |

### Chat

| Setting | Description | Default |
|---------|-------------|---------|
| Width | Chat frame width | 400 |
| Height | Chat frame height | 150 |
| Bottom Y | Distance between the chat frame and screen bottom (0-500) | 20 |
| Only show chat while typing | Hide history until Enter or the quick menu opens chat | Off |
| Move elements | Move each bar and panel with the D-pad, or drag its own handle | `/celayout` |
| Enable Chat Module | Let the addon manage chat positioning and behavior | On |
| Virtual Keyboard | Show the on-screen keyboard for chat and controller-focused text fields | On |
| Keyboard Layout | Follow the addon language or choose English, German, French, or Spanish | Automatic |

**Reset Chat Settings** asks for confirmation, then restores the chat module,
chat size and position, virtual keyboard preference, and keyboard layout.

## Bars

### Action Bar Layout

Select **Move elements** in Bars or Gameplay, or use `/celayout`. Opening the editor detaches the left/right action bars and the HUD while keeping their current positions. Each action group, touch bar, pet bar, chat panel, XP bar, reputation bar, cast bar, crosshair and action-page indicator has its own handle. Enabled panels remain selectable even when temporarily faded or idle. After detaching, moving chat or hiding reputation does not move the other bars, and action bars stay at the positions you chose.

Choose a target and press confirm to enter move mode; the D-pad then adjusts its position. Confirm saves, while Back restores its previous position and stays in the editor. Back outside move mode leaves the editor. Square/X saves and exits directly. **Step** changes the movement distance. Mouse dragging is also available. Positions are included in profiles. Leaving returns to settings when settings opened the editor.

| Setting | Description | Default |
|---------|-------------|---------|
| Appearance | Classic frames or Modern circular buttons | Modern |
| Button Size | Size of action buttons (20-80) | 60 |
| Padding | Space between buttons (0-100) | 65 |
| Star Padding | Distance between left and right groups | 600 |
| X Offset | Horizontal position offset | 0 |
| Y Offset | Vertical position from bottom | 70 |
| Scale | Overall scale (0.5-2.0) | 1.0 |
| Auto-update spell ranks | Update action bar spells when a higher rank is learned | On |
| Use travel form bar in prowl | For druids, use the travel form action bar while prowling in cat form | Off |

**Reset Layout** asks for confirmation, then restores the main bar's size,
spacing, position, scale, and appearance. It leaves side-bar settings and action
assignments unchanged.

### Side Action Bars

| Setting | Description | Default |
|---------|-------------|---------|
| Enable Left Side Bar | Show the left vertical action bar | Off |
| Enable Right Side Bar | Show the right vertical action bar | Off |
| Left Buttons (1-5) | Number of buttons on the left bar | 3 |
| Right Buttons (1-5) | Number of buttons on the right bar | 3 |

Side bars use action slots 41-45 on the left and 46-50 on the right. They share
button size, padding, and scale with the main action bars.

### XP and Reputation Bars

| Setting | Description | Default |
|---------|-------------|---------|
| Always Visible (XP) | Keep the XP bar visible instead of fading out | On |
| Always Visible (Reputation) | Keep the reputation bar visible instead of fading out | Off |
| Width | Bar width; 0 matches chat width | 0 (chat width) |
| Height | Bar height (20-100) | 20 |
| Timeout | Seconds before a non-persistent bar fades out (0-60) | 5 |
| Show Text | Display progress text on the bar | On |

### Cast Bar

| Setting | Description | Default |
|---------|-------------|---------|
| Enable Cast Bar | Show the custom cast bar | On |
| Height | Bar height in pixels | 20 |
| Color | Cast and channeling colors | Blue cast, gold channeling |

## Bindings

Assign a spell, item, macro, or system action to any controller input. Each
button can have separate assignments for no modifier, Shift, Ctrl, and
Ctrl+Shift.

Selecting an input opens one categorized picker with **Menus**, **Spells**,
**Items**, and **Macros** tabs and a scrollable result list. The search field
spans every category, so a spell can be found without switching tabs first.
Choosing a spell, item, or macro places it on the input's action-bar slot and
clears any system action on that slot; choosing a menu action assigns the
button instead. There are no previous/next pages.

Switch to **Other controls** to inspect every remaining native input. Left- and
right-stick clicks, Start/Options, Back/Share, and trigger actions can run system
actions, open the quick menu, switch pointer/focus mode, or be disabled. Auxiliary
assignments can differ across the four modifier pages and are saved with
profiles. The stick axes, pointer clicks, and reserved pause combination show
their contextual behavior. **Stick settings** opens sensitivity, deadzones, and
calibration.

### System Bindings

| Setting | Description | Default |
|---------|-------------|---------|
| Slot 1 (A) | System action for the A button | Jump |
| Slot 30 (RT+LB; R2+L1 on PlayStation) | System action for RT+LB | Interact |
| Other Slots | Assign a spell, item, macro, or system action | None (Action Bar) |

### Available System Actions

- **Movement:** Jump, Toggle Auto Run, Run/Walk
- **Targeting:** Interact, Target Self, Target Pet, Target Nearest Enemy, Target Previous Enemy, Target Nearest Friend, Target Previous Friend, Assist Target
- **Interface:** Open Bags, Game Menu, World Map, Character Panel, Spellbook, Talents, Quest Log, Social
- **Camera:** Zoom In, Zoom Out
- **Combat:** Attack, Pet Attack, Stop Attack

**Interact** uses Interact.dll when it is available. Otherwise, the optional
mouse bridge switches to pointer mode so you can right-click a target. Without
either option, the addon reports that interaction is unavailable; it does not
select an enemy as a substitute.

### Actions

| Control | Description |
|---------|-------------|
| Reset Bindings | Restore the default controller bindings for action slots and the quick menu. System-action assignments are kept. |
| Change Binding | Open the categorized picker for the selected input |
| Bind Spell or Item | Open the same picker on the Spells category for the selected input |

## Profiles

Profiles are saved per character and store addon settings, action slots, and
system action assignments. **Create New** activates a profile with default
settings and empty action slots. **Clone Current** creates and activates a copy
of the active profile. Switching profiles saves the current profile first. The
**Default** profile cannot be deleted; deleting another profile asks for
confirmation.

## Slash Commands

| Command | Description |
|---------|-------------|
| `/controller` | Open configuration |
| `/controller help` | Open Help & Tutorials directly |
| `/controller status` | Show controller connection and input status, plus controls available in the current setup |
| `/controller cursor` | Switch between focus/click and camera/pointer modes; requires the optional mouse bridge |
| `/controller pause` / `/controller resume` | Pause or resume native controller input |
| `/controller sensitivity 100-3000` | Set native camera/pointer speed; requires the optional mouse bridge |
| `/controller camera 100-3000` | Set camera speed independently |
| `/controller pointer 100-3000` | Set pointer speed independently |
| `/controller calibrate` | Measure centered-stick drift and set both deadzones |
| `/controller debug on` / `/controller debug off` | Show or hide the controller diagnostics overlay |
| `/cerank debug` | Show all spells on action bars |
| `/cerank update` | Update spells to highest rank |

## Config File Location

Interface settings are saved per character in:

```
WTF/Account/<Account>/<Realm>/<Character>/SavedVariables/Windrunner-Controller.lua
```

Controller speeds, deadzones, diagnostics, and the shared layout library are saved account-wide in:

```
WTF/Account/<Account>/SavedVariables/Windrunner-Controller.lua
```

## Resetting Configuration

To reset this character's interface settings, log out and delete its
per-character file above. To also reset controller sensitivity and diagnostics
for every character, delete the account-wide file too. Back up either file first
if you may want to restore its settings.

## Gameplay tools and sharing

The **Gameplay** section provides first-run setup/input testing, utility-ring
editing, profile sharing, pet controls, target context actions and pending loot
rolls. Quick-menu collections include Tools and available Professions.

| Gameplay setting | Behavior |
| --- | --- |
| Modifier buttons | Use triggers or bumpers for native Shift/Ctrl; bumpers as modifiers free LT/RT for actions. |
| Tap modifiers to latch | Press a modifier to toggle its layer; focus loss or profile/input changes clear latches. |
| Swap A/B menu confirm and cancel | Swap panel confirm/back while preserving dedicated pointer and keyboard actions. |
| Repeat delay / interval | Tune held D-pad navigation speed. |
| Bar layout | Choose controller clusters, crossbar or horizontal rows. |
| Show action bars | Always, during combat and menus, or outside combat and in menus. |
| Move elements | Open individual handles for each action group, HUD bar and panel. |
| Release held ring button | Native release activates a deliberate selection; mapped input explicitly confirms. |
| Reload UI after controller disconnect | Reload the interface three seconds after the controller disconnects, restoring the normal UI. A quick reconnect cancels it. |
| Remember typed words | Opt in to storing suggestion words for this character. |

Setup offers Xbox, PlayStation, Switch-style or Steam Deck prompt labels, then
passively displays observed buttons, sticks and triggers and offers stick
calibration. Switch-style and Steam Deck presets only change visual labels; they
do not add native hardware support.

Word suggestions are conservative and explicit. Optional remembered words and
saved phrases are stored per character; there is no autocorrect. Suggestions
serve virtual typing and do not rewrite slash commands.

The **Share Profile** window exports a versioned bounded text format and stores
up to twenty named account-wide exports. Imports are parsed and previewed before
Apply, then back up the current character profile. The parser accepts only
whitelisted settings, bindings and supported ring entries; it does not execute
imported Lua. Portable settings, controller bindings and utility rings are
included. Live action-bar snapshots, spellbook identities and macros are not
copied to another character; action-slot macro ring entries are omitted.
