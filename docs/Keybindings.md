# Keybindings

Controller-specific bindings stay dormant until the native input package reports a connected controller. A keyboard-emulating mapper alone does not activate the addon.

Windrunner-Controller maps controller inputs to action-bar slots and provides
separate controls for menu navigation and pointer mode.

Button names below use Xbox labels. On PlayStation, A/X/Y/B map to
Cross/Square/Triangle/Circle, RB/LB map to R1/L1, LT/RT map to L2/R2, and
Start/Back map to Options/Share. The right-stick click is RS on Xbox and R3 on
PlayStation.

## Default Controller Layout

The tables below describe gameplay action slots. When an interface is open,
the same buttons can have navigation or pointer actions; see
[Navigation and Menus](#navigation-and-menus) for those controls.

### Action Bar - Right Star (Face Buttons)
| Button | Key | Default Action |
|--------|-----|----------------|
| A | 1 | Jump (System Binding) |
| X | 2 | Action Slot 2 |
| Y | 3 | Action Slot 3 |
| B | 4 | Action Slot 4 |

### Action Bar - Left Star (D-Pad)
| Button | Key | Default Action |
|--------|-----|----------------|
| D-Down | 5 | Action Slot 5 |
| D-Left | 6 | Action Slot 6 |
| D-Up | 7 | Action Slot 7 |
| D-Right | 8 | Action Slot 8 |

### Bumpers
| Button | Key | Default Action |
|--------|-----|----------------|
| RB | 9 | Action Slot 9 |
| LB | 0 | Action Slot 10 |

### With LT Modifier (Shift)
| Button | Key | Default Action |
|--------|-----|----------------|
| LT + A | Shift-1 | Action Slot 11 |
| LT + X | Shift-2 | Action Slot 12 |
| LT + Y | Shift-3 | Action Slot 13 |
| LT + B | Shift-4 | Action Slot 14 |
| LT + D-Down | Shift-5 | Action Slot 15 |
| LT + D-Left | Shift-6 | Action Slot 16 |
| LT + D-Up | Shift-7 | Action Slot 17 |
| LT + D-Right | Shift-8 | Action Slot 18 |
| LT + RB | Shift-9 | Action Slot 19 |
| LT + LB | Shift-0 | Action Slot 20 |

### With RT Modifier (Ctrl)
| Button | Key | Default Action |
|--------|-----|----------------|
| RT + A | Ctrl-1 | Action Slot 21 |
| RT + X | Ctrl-2 | Action Slot 22 |
| RT + Y | Ctrl-3 | Action Slot 23 |
| RT + B | Ctrl-4 | Action Slot 24 |
| RT + D-Down | Ctrl-5 | Action Slot 25 |
| RT + D-Left | Ctrl-6 | Action Slot 26 |
| RT + D-Up | Ctrl-7 | Action Slot 27 |
| RT + D-Right | Ctrl-8 | Action Slot 28 |
| RT + RB | Ctrl-9 | Action Slot 29 |
| RT + LB | Ctrl-0 | Interact (System Binding) |

### With LT+RT Modifier (Ctrl+Shift)
| Button | Key | Default Action |
|--------|-----|----------------|
| LT + RT + A | Ctrl-Shift-1 | Action Slot 31 |
| LT + RT + X | Ctrl-Shift-2 | Action Slot 32 |
| LT + RT + Y | Ctrl-Shift-3 | Action Slot 33 |
| LT + RT + B | Ctrl-Shift-4 | Action Slot 34 |
| LT + RT + D-Down | Ctrl-Shift-5 | Action Slot 35 |
| LT + RT + D-Left | Ctrl-Shift-6 | Action Slot 36 |
| LT + RT + D-Up | Ctrl-Shift-7 | Action Slot 37 |
| LT + RT + D-Right | Ctrl-Shift-8 | Action Slot 38 |
| LT + RT + RB | Ctrl-Shift-9 | Action Slot 39 |
| LT + RT + LB | Ctrl-Shift-0 | Action Slot 40 |

By default, LT/L2 and RT/R2 are held as modifiers, and LB/RB use slots 10/9
in every set. **Gameplay** can instead use bumpers as native modifiers and can
latch modifiers on a press. These choices update the binding screen and prompts.

### Default Navigation and Menu Controls
| Button | Action |
|--------|--------|
| D-Pad | Move cursor / Navigate menus; move between radial options |
| Left stick | With native controller input, move focus between menu controls |
| Either stick | With native controller input, select a radial option; choose Left / Right / Both on the Controller page |
| A | Select / Confirm |
| B | Back / Cancel |
| Start / Options | Open or close radial menu |
| Right-stick click (RS on Xbox, R3 on PlayStation) | With the optional mouse bridge, switch A/X between focus actions and clicks in menus, and between camera and pointer movement in the world |
| Back / Share | Toggle map |
| Left-stick click (LS on Xbox, L3 on PlayStation) | Target nearest enemy in the world |
| Back + Start / Share + Options | Pause or resume controller input |

With the native mouse bridge, the right stick moves the camera in the world and
the pointer in a standard UI menu. In the world, right-stick click (RS on Xbox, R3
on PlayStation) switches between camera and pointer movement. In menus, RS/R3
switches **A/X** between focused-control actions and pointer clicks (**A**
left-clicks, **X** right-clicks); the left stick or D-pad moves focus between controls. A
keyboard-mapped controller can navigate with its assigned keys. In menus
without the mouse bridge, RS/R3 leaves **A/X** in focus mode and reports that
right-stick mouse input needs the optional package. Native analog input selects
radial options with either stick by default; without it, use the D-pad or assigned cursor
direction keys. Pressing RS/R3 briefly shows which mode is active.

Change either stick click, Start/Options, or Back/Share under **Bindings > Other
controls**. These assignments require native controller input, can differ on
each modifier page, and are saved with profiles. A page without an override
inherits its base assignment. Choose a system action, **Quick
Menu**, **Switch pointer / focus mode**, or **Disabled**. Gameplay actions stop
while a menu owns focus; interface actions remain available. The pause
combination stays reserved even when its individual buttons are reassigned.

This view also shows the stick axes, trigger modifiers, and pointer clicks.
Select **Stick settings** for sensitivity, deadzones, and calibration.
**Reset these controls** resets the selected modifier page's editable controls,
including triggers when bumpers are modifiers. Keyboard-mapped controllers use
**Open Key Bindings** to assign their mapper keys.

In bags and banks, **Y / Triangle** opens **Item actions** for the selected item
(or the hovered item in native pointer mode). The popup includes contextual
use/equip, stack splitting, action-bar placement, appearance preview, and
confirmed destruction/disenchanting. Inside it, **A / Cross** selects and
**B / Circle** goes back; **Left / Right** adjusts a split amount, **X / Square**
chooses half, and **Y / Triangle** chooses all but one. This popup uses focus
controls even when pointer mode is enabled. See
[Inventory actions](features/CursorNavigation.md#inventory-actions).

## System Bindings

System Bindings let you assign controller slots to system actions (such as
Jump or Auto Run) instead of action-bar abilities. Configure them in the
**Bindings** section of `/controller`.
The Bindings page lists one input per row. Use **Inputs** to choose action buttons
or other controls, and **Modifier page** to select the base, LT/Shift, RT/Ctrl,
LT+RT/Ctrl+Shift, or enabled touch-bar assignments. Left/right changes these
choices in place. Confirm on an input opens its system-action picker. The four
round previews show its assignments across modifier pages.
Spell, item, and macro names reflect the active stance or form on the base set.

Choose **None (Action Bar)** to use the underlying action-bar ability, then use
**Place Action** to open a searchable spell, carried-item, and macro picker for
that control. The placement grid remains available from the quick menu. **Open Key Bindings** opens WoW's
keyboard binding screen. Enabled side bars appear under **Touch bars**.

### Side Bar Bindings

Side bar slots (touch screen bars) can also be assigned system bindings:

- **Left Side Bar** (slots 41-45): Labeled as "Left 1" through "Left 5"
- **Right Side Bar** (slots 46-50): Labeled as "Right 1" through "Right 5"

These bindings only appear in the config when the corresponding side bar is enabled and has at least one button configured. Side bar slots can be:
- Assigned system actions (like Jump, Auto Run, etc.)
- Left as action bar slots (click/touch to activate)
- Assigned a keyboard key in the standard WoW keybindings menu (Escape → Key Bindings → Windrunner Left Touch Bar / Windrunner Right Touch Bar). The key runs the selected system action, or uses the underlying action slot when set to **None (Action Bar)**.

WoW blocks clicking some protected actions, including Jump and Auto Run. When one of these is assigned to a touch-bar button, assign a key to that button in the same Key Bindings menu; the addon explains this if you try to click it.

### Available System Actions

| Category | Action | Description |
|----------|--------|-------------|
| **Movement** | Jump | Jump |
| | Toggle Auto Run | Toggle auto-run on/off |
| | Run/Walk | Toggle running/walking speed |
| **Targeting** | Interact | Uses Interact.dll when available; otherwise uses pointer mode if the mouse bridge is available |
| | Target Self | Target yourself |
| | Target Pet | Target your pet |
| | Target Nearest Enemy | Target nearest hostile |
| | Target Previous Enemy | Target previous hostile |
| | Target Nearest Friend | Target nearest friendly |
| | Target Previous Friend | Target previous friendly |
| | Assist Target | Assist current target |
| **Interface** | Open Bags | Open all bags |
| | Game Menu | Open the game menu |
| | World Map | Open/close the world map |
| | Character Panel | Open/close character info |
| | Spellbook | Open/close the spellbook |
| | Talents | Open/close the talent window |
| | Quest Log | Open/close the quest log |
| | Social | Open/close the friends list |
| **Camera** | Zoom In | Zoom camera in |
| | Zoom Out | Zoom camera out |
| **Combat** | Attack | Start auto-attack |
| | Pet Attack | Command pet to attack |
| | Stop Attack | Stop attacking |

Interact uses Interact.dll's nearest-target function when installed. Otherwise,
the mouse bridge enables pointer mode for right-clicking NPCs and objects. If
neither is available, the addon reports that interaction is unavailable; it
does not select an enemy as a substitute.

### Default System Bindings

| Button | System Action |
|--------|---------------|
| A (Slot 1) | Jump |
| RT + LB (R2 + L1 on PlayStation; Slot 30) | Interact |

## Configuring Keybindings

### In-Game Key Bindings Menu
From the add-on’s **Controller** or **Help & Tutorials** page, select
**Open Key Bindings** to jump to the **Windrunner-Controller** section. You can
also press Escape → Key Bindings and scroll to that section manually. Set your
preferred keys there.

### System Bindings Configuration
1. Type `/controller` to open configuration
2. Go to the **Bindings** tab
3. For each controller button slot, select either:
   - **None (Action Bar)** - Uses the action bar slot normally
   - **A system action** - Binds directly to that WoW action

## Controller Setup

### Controller Type and Button Prompts

Choose **Xbox** or **PlayStation** under **Interface**, or use the setup screen
for Xbox, PlayStation, Switch, and Steam Deck prompt presets. Prompt presets
change labels and artwork; they do not add native device compatibility.

### Native Input and Other Controllers

The native Windrunner Controller bridge supports XInput controllers and direct
DualSense input. Copy the addon and DLL into your WoW folder, add
`WindrunnerController.dll` to `dlls.txt`, and launch through VanillaFixes; see
the [installation guide](Installation.md).
For a controller not supported by that bridge, an external mapper can present
it to the native DLL as an XInput controller; this route still requires the DLL.

A keyboard-emulating mapper can send keys assigned in the in-game **Key
Bindings** menu. Assign gameplay keys to action slots under **Windrunner
Controller** and the radial-menu toggle under **Quick Menu**. While a supported
UI is open, mapped face and D-pad buttons use the focused control; buttons
without a menu action are ignored. Healer Mode keeps its focused group-member
casts. Use **Cursor Navigation** for extra menu movement and click keys. This
path does not require the DLL; native analog-stick input and
controller connection status remain unavailable without it.

Use `/controller` to see connection status and controls available in the current
setup. With native input, `/controller pause` and `/controller resume` control
that input. `/controller cursor` switches camera/pointer and menu focus/click
modes, while `/controller sensitivity 100-3000` adjusts camera/pointer speed;
both require the optional mouse bridge.

## Tips

- With default modifiers, hold LT/L2 for Shift, RT/R2 for Ctrl, or both for Ctrl+Shift.
- Use **Gameplay** to select trigger or bumper modifiers and optional latching.
- Practice the button combinations in a safe area
- Customize bindings if the defaults don't feel right

## Gameplay controls and utility rings

**Gameplay** selects native modifier buttons (triggers or bumpers), optional tap
latching, A/B menu confirmation, and D-pad repeat timing. With bumpers as native
modifiers, LT/RT become assignable controls and default to action buttons 10/9.
The action bar and binding screen update their prompts to match.

In **Bindings → Other controls**, assign stick clicks, Back/Start, and available
triggers for each of the four modifier pages. Pages without an override inherit
the base assignment. Back + Start remains the native pause/resume combination.

System actions include pet controls, target actions, pending loot rolls, the
utility-ring editor, and Utility Ring 1–12. Rings can also be assigned to action
buttons. Ring entries can be spells, carried items, action-slot macros, or native
system actions such as **Game Menu**, world map, bags, and character panels. For
direct native input, **Release held ring button to activate** makes release
confirm a deliberate stick/D-pad selection; release without a selection cancels.
Keyboard-mapped ring bindings use explicit confirmation.

While the on-screen keyboard is active, LB inserts a space and RB deletes a
character for native controllers. Mapped controllers can bind **Keyboard space**
and **Keyboard backspace** under the addon's keybinding header.

The setup screen offers Xbox, PlayStation, Switch, and Steam Deck prompt presets.
Switch/Deck choices change physical button labels and artwork; device support
still depends on the installed native bridge or keyboard-mapping software.
