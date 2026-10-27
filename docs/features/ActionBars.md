# Action Bars

Windrunner-Controller provides a gamepad-style action bar layout designed for controller use.

## Layout

The action bar uses a "star" layout with two groups of buttons. The ten base
inputs are the four face buttons, four D-pad directions, and the two bumpers.
The bumpers are action buttons in slots 9 and 10; the triggers modify the slot
set while held.

```
Left Star:  D-Pad + LB/RB
Right Star: A/X/Y/B
Modifiers:  Hold LT, RT, or both for additional slots
```

### Button Mapping

| Held input | Action slots |
|------------|--------------|
| No trigger | 1-10 |
| LT (L2 on PlayStation) | 11-20 (Shift modifier) |
| RT (R2 on PlayStation) | 21-30 (Ctrl modifier) |
| LT + RT (L2 + R2 on PlayStation) | 31-40 (Ctrl+Shift modifiers) |

Each set uses the same button order: A, X, Y, B, D-pad Down, Left, Up,
Right, RB, LB. Slot 1 defaults to Jump, and slot 30 defaults to Interact.
The center indicator shows the active trigger page and identifies the current
stance, form, or bonus bar on the base page.

> **Note:** Any button slot can be assigned to a System Binding (like Jump,
> Auto Run, etc.) instead of an action bar slot. See
> [Keybindings](../Keybindings.md) for details. Protected system actions still
> appear on the bar for reference; activate them with their assigned key or
> controller button, since clicking the icon cannot trigger them.

## Appearance Styles

### Classic
Traditional button style with clear borders and standard textures.

### Modern
Circular icons use a real portrait mask, thin rims, and small controller glyphs above each ability. Cooldown shading, pressed states, and active-action feedback also stay circular. The bumpers sit inside the two button diamonds. Modern is the default; this update selects it once for existing characters, then preserves later style choices.

## Customization

### Size & Position
- **Button Size**: 20-80 pixels
- **Padding**: Space between buttons in each star
- **Star Padding**: Distance between left and right star groups
- **X/Y Offset**: Position adjustment from bottom center
- **Scale**: Overall size multiplier

### Changing Layout

1. Open config with `/controller`
2. Open the **Bars** page
3. Adjust the controls; use the text boxes to enter exact values
4. Changes apply immediately

Use **Move elements** on the Bars page, or enter `/celayout` (also `/windrunnerlayout`). Choose a target button in the editor with the D-pad, then press confirm (Cross/A by default) to enter move mode. The D-pad now moves that target; confirm keeps the new position and cancel (Circle/B by default) restores its previous position while leaving the editor open. Press cancel again outside move mode to leave the editor. The **Step** button changes movement distance. Opening the editor unlocks the two action groups and the HUD at their current positions. Targets include each left/right group, enabled touch bars, chat, a live pet bar, XP, reputation, cast bar, crosshair and the action-page indicator.

Square/X saves the current move and closes the editor directly. Mouse users can drag the highlighted areas or click the directional buttons. **Done** also keeps the current move and closes the editor. Leaving the editor returns to settings when settings opened it. Escape closes it and cancels an unconfirmed move. **Reset positions** restores the default anchors without changing sizes or assignments. Positions are saved per character and included in profiles.

Button scale changes icon size and spacing without scaling the saved screen offset. The layout fits the game window. After opening Move elements, action bars remain where you place them without automatic chat avoidance.

The **Interface > Chat** section also has **Move elements** and **Only show chat while typing**. In that mode, press Enter or open Chat from the quick menu to reveal the history and input; closing input hides chat again. The layout editor temporarily reveals hidden chat. With the virtual keyboard disabled, typing uses the moved chat position; the virtual keyboard keeps its wider focused layout and returns to the saved position afterward. After opening Move elements, XP, reputation and cast bars keep their own saved anchors. Disabling the Chat Module returns chat to its original layout.

## Place Action

The Place Action frame shows action slots in rows for each form and trigger
modifier. Columns follow the controller button order shown above. Focus an
occupied slot and press **A** to pick up its action; press **A** again on a slot
to place or swap the action you are carrying. **B** clears an occupied slot
when your cursor is empty. On an empty slot, or while carrying an action, **B**
backs out and closes the frame. Empty slots show a **+** marker, which turns
gold while carrying an action. Press **Esc** or **X** to close the frame. The
footer and slot tooltip update to show the actions available for the focused
slot and cursor state. Slots assigned to system actions remain visible as
muted **System** markers; hover them to see the action, or change the assignment
in the **Bindings** section before placing an action there.

## Button Prompts

The addon shows controller button icons based on your selected controller type:
- **Xbox**: A, B, X, Y, LB, RB, LT, RT
- **PlayStation**: Cross, Circle, Square, Triangle, L1, R1, L2, R2

Change the prompt style in the **Interface** settings. This changes the icons;
the action-slot layout stays the same.

## Side Action Bars (Touch Screen)

Two optional vertical action bars designed for touch screen input. These bars can be tapped directly on a touch-enabled display or assigned system bindings for keyboard/controller use.

### Position
- **Left Bar**: Left edge of screen, vertically centered
- **Right Bar**: Right edge of screen, vertically centered

### Configuration

| Setting | Description | Default |
|---------|-------------|---------|
| Enable Left Side Bar | Show left touch bar | Off |
| Enable Right Side Bar | Show right touch bar | Off |
| Left Buttons (1-5) | Number of buttons on left bar | 3 |
| Right Buttons (1-5) | Number of buttons on right bar | 3 |

### Action Slots
- Left bar uses action slots 41-45
- Right bar uses action slots 46-50

### Bindings

Side bar slots can be assigned system bindings (like Jump, Auto Run, etc.) in the **Bindings** section of `/controller`:

- **Left Side Bar**: Slots 41-45 (labeled as "Left 1" through "Left 5")
- **Right Side Bar**: Slots 46-50 (labeled as "Right 1" through "Right 5")

Each slot can be set to:
- **None (Action Bar)** - Uses the action bar slot normally (click/touch to activate)
- **A system action** - Binds directly to that WoW action (can be keybound)

> **Note:** Side bar bindings only appear in the Bindings config when the corresponding side bar is enabled and has at least one button configured.

### Features
- Same visual style as main action bars (button size, padding, scale)
- Supports drag & drop (Shift+click to pick up)
- Full functionality: cooldowns, range checking, usability colors
- Appears in Placement Frame when enabled for easy setup
- Can be assigned system bindings for keyboard/controller access

### Use Cases
- Touch screen devices (tablets, touch monitors)
- Frequently used abilities that don't need keybinds
- Consumables, mounts, or utility spells
- Secondary rotation abilities
- System actions (Jump, Auto Run, etc.) when assigned via bindings

## Druid Forms

Druids get dedicated action bars for forms that use a bonus bar. Aquatic Form
uses the regular bar, so it does not have a separate row in the placement frame.

| Form | Bonus Bar | Action Slots |
|------|-----------|--------------|
| Caster Form | None | 1-10 |
| Cat Form | 1 | 73-82 |
| Aquatic Form | None | 1-10 |
| Bear Form | 3 | 97-106 |
| Travel Form | 4 | 109-118 |
| Moonkin Form | 5 | 121-130 |

### Druid Stealth Feature

When enabled in the Action Bars config, druids in cat form will automatically use the travel form action bar (slots 109-118) when prowl/stealth is active. This allows you to have separate keybinds for prowl abilities.

**To enable:**
1. Open config with `/controller`
2. Open the **Bars** page
3. Check "Use travel form bar in prowl" (only visible to druids)

> **Note:** This feature is only available to druids and only appears in the config UI when playing a druid character.

## Tips

- Use the placement mode to fine-tune button positions
- The right star typically holds your most-used abilities
- By default, hold triggers for three additional slot sets; Gameplay can use bumper modifiers or tap latching.
- Use System Bindings for common actions like Jump, Auto Run, etc.
- Side bars share size/padding settings with main action bars
- Druids: Use the placement frame to set up abilities for each form
- Druids: Enable stealth feature to have separate prowl keybinds

## Layout, visibility and action picker

Choose **Clusters**, **Crossbar** or **Horizontal** in **Gameplay** settings. Independent
bar positioning gives the left and right controller groups separate anchors;
move mode also positions touch bars, pet bar and chat. Bar visibility can be set
to always, during combat and menus, or outside combat and in menus. Layout and anchors are saved per character
and restored with profiles.

The searchable action picker finds spells, carried items and macros for an
action slot or utility ring. Selection checks the destination and action data
again before applying. The share-profile format does not replace live action-bar
snapshots across characters.

## Auxiliary inputs by modifier page

The bindings editor has four action pages: base, Shift, Ctrl and Ctrl+Shift.
Auxiliary inputs (stick clicks, Start/Back and triggers) can have assignments
per page. The triggers can be configured as modifiers or actions. Touch side-bar
action slots remain separate slots 41-50.

## Pet controls

The circular pet bar exposes all ten pet action slots, active/autocast state and
cooldowns. **Gameplay → Pet controls** opens commands and an ability editor for
casting, autocast toggles and moving pet abilities. Move mode saves the pet bar's
position with the current character profile. Pet commands run only from user
input; periodic updates refresh display state.
