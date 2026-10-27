# Cursor Navigation

Navigate supported UI elements using your controller without a mouse. You can
also assign keyboard keys to the cursor actions in the game's Key Bindings
screen.

## How It Works

The cursor navigation system allows you to:
- Select UI elements (buttons, items, NPCs)
- Navigate between interactive frames
- Interact with game world objects

## Controls

| Action | Default Binding |
|--------|-----------------|
| Move between controls | Left stick with native input, or D-pad (hold to repeat); keyboard keys can be assigned in Key Bindings |
| Select/Click | A Button (Cross on PlayStation); keyboard keys can be assigned in Key Bindings |
| Back/Cancel | B Button (Circle on PlayStation); passes a focused group loot roll; keyboard keys can be assigned in Key Bindings |
| Target nearest enemy in the world | Left-stick click (LS on Xbox, L3 on PlayStation) |
| Change right-stick mode | With the optional mouse bridge, right-stick click (RS on Xbox, R3 on PlayStation) switches A/X between focus actions and clicks in menus, and camera/pointer movement in the world |
| Open or close radial menu | Start / Options |
| Open map | Back / Share |

With the native mouse bridge, the right stick moves the pointer in a standard
menu while the left stick or D-pad moves focus between controls. Press RS/R3 to switch **A/X**
between focused-control actions and pointer clicks (**A** left-clicks,
**X** right-clicks); the right stick remains available for pointer movement.
Mapped face and D-pad buttons use the focused control while a supported UI is
open; action buttons without a menu action are ignored. Healer Mode keeps its
focused group-member casts. In the world, RS/R3 switches the right stick between
camera and pointer movement when the optional mouse bridge is available.
The radial menu accepts either stick by default. Choose **Left / Right / Both**
on the Controller page. D-pad and assigned cursor keys also work. A brief
on-screen label describes the active input mode.
If the mouse bridge is unavailable, RS/R3 leaves **A/X** on focused-control
actions and reports that right-stick mouse input needs the optional package.
Button names use Xbox labels; PlayStation prompts use Cross, Circle, Square,
and Triangle in the corresponding positions.

In settings, Up/Down previews categories while focus stays in the sidebar.
Right enters the selected page and restores the last focused setting.
Within a page, Up/Down follows rows, Left/Right follows controls in the row,
and focused settings scroll into view automatically. Back returns to categories;
Back again closes settings. Repeat delay and interval in Gameplay apply to
both the left stick and D-pad.

## Supported Frames

The cursor can navigate:
- Bags and inventory
- Character panel
- Pet stable
- Spell book
- Quest log
- Quest, gossip, taxi, and item text dialogs
- Vendor windows
- Trade skills and crafting
- Bank
- Mail
- Group loot rolls
- Trade windows
- Most standard UI elements

## Tooltip Display

When hovering over items or elements, the tooltip appears showing:
- Item stats and info
- Spell descriptions
- NPC information
- Context-specific controller actions, including Need, Greed, and Pass on loot rolls
- Empty equipment, bag, and bank slots don't offer unavailable actions; A places a carried item where supported
- Localized button labels on confirmation dialogs

## Inventory actions

Focus an occupied bag or bank slot and press **Y / Triangle** to open **Item
actions**. In native pointer mode, this opens actions for the hovered slot.
The popup uses your appearance theme and keeps controller focus inside it.
You can also assign **Item actions** under WoW's **Cursor Navigation** bindings,
or use `/ceitem` for the selected slot.

- **Use / Equip** adapts to **Sell**, **Auction**, **Trade**, **Attach**,
  **Deposit**, or **Withdraw** when the corresponding interface is open.
- **Pickup / Move** carries the item for placement in another slot.
- **Place on action bar** carries the item and opens the existing placement screen.
- **Split stack** lets you adjust the amount with **Left / Right**. **X / Square**
  chooses half; **Y / Triangle** chooses all but one. Select **Split** with
  **A / Cross**, then place the carried portion in an empty slot. Mouse users
  can use the amount buttons. No text entry is required.
- **Preview appearance** opens the dressing room for applicable gear.
- **Disenchant** appears for plausible gear when the profession spell is known.
  The client still checks item eligibility and Enchanting requirements.
- **Destroy** and **Disenchant** open a separate confirmation with **Cancel**
  selected first. Destroy deletes the entire selected stack.

**B / Circle** returns from a split or confirmation screen to the actions list,
then closes it and returns focus to the item. **Escape** closes the popup.
Native input requires button release before it resumes after closing, so a held
confirmation cannot become an accidental bag click.

The existing **A pickup**, **X bind**, and contextual **B use** bag shortcuts
remain available. Locked items disable modifying actions. Empty slots, carried
payloads and offline bank views cannot open item actions. The popup rechecks the
slot, item link, current stack size and interface before acting. Supported slot
formats are stock bags/bank, pfUI, Bagshui and Bagnon/Banknon. Cached items from
other characters are not supported.

## Tips

- The selected element has a gold outline and a subtle tint that stays clear
  across wide buttons, slots, and other control shapes
- On a newly opened panel, focus starts at the upper-left available control
  unless the panel provides a more useful starting point
- Confirmation prompts start on a visible **Cancel** or **No** choice when
  available, so **A** does not immediately accept the prompt
- Reopening a panel restores its last selected control when that control is
  still available
- If the selected control disappears, focus tries another control in that
  panel before moving to a different open panel
- Standard scroll panels keep the selected control in view as you move through
  their contents
- Use the crosshair to target enemies/NPCs in the world
- Some custom addon frames may not be fully supported
- Dropdowns, confirmation prompts, and other modal panels keep focus within
  the open screen until it closes
- The full-screen world map keeps focus on map controls; closing it restores the
  previous panel selection when that control is still available
- Press **B** or **Escape** to back out of menus. Timed group loot rolls start
  with **Pass** focused, keep focus within the visible roll cards, and accept
  the focused choice with **A**; press **B** to pass the roll
