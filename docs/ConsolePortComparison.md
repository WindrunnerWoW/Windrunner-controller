# ConsolePort feature comparison

Audited 11 October 2026 against ConsolePort 3.3.10, upstream commit
`2e693103ceb3934bf7a32badb5c7b543a688c7a5`. Implementation status was updated
12 October 2026 against the current Windrunner addon and Windrunner-Controller
0.3.1 source. Automated checks model client APIs. Limited live UI and DualSense
input-tester checks are recorded in [Controller acceptance](ControllerAcceptance.md);
full gameplay acceptance remains open. The remaining differences are listed below.

ConsolePort targets newer Blizzard clients, including modern Classic. Windrunner
targets the original Vanilla 1.12.1 client. Similar interface features are often
practical, but native movement, soft targeting, and hardware integration cannot
be assumed to work through the same APIs. The implementation approach below is
an assessment from the source, not a verified port.

## Next verification

1. Run the live visual/input checks in [Controller acceptance](ControllerAcceptance.md).
2. Verify pet abilities, inventory transactions, unit permissions, and loot rolls with actual client/server data.
3. Investigate soft targeting, true analog movement, and spell-reticle workflows separately in the native bridge.

## Gameplay coverage

| Feature | ConsolePort offers | Windrunner today | Remaining difference / validation |
| --- | --- | --- | --- |
| Complete pet controls | Pet actions, cooldowns, autocast toggles, and editing in its quick menu. [Pet module](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_World/Controller/Pet.lua). | A circular replacement HUD exposes all ten pet slots, cooldowns, active/autocast state, commands, and ability editing. Pet controls also have a controller menu. | Verify class-specific pet abilities and autocast behavior in the live client. |
| Configurable utility rings | Multiple editable rings containing spells, items, macros and other actions. Press/point/release or explicit confirmation, sticky selection, and automatic quest-item entries. [Ring settings](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Rings/Database.lua), [action mapping](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Rings/Model/Map.lua), [automatic entries](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Rings/Controller/Auto.lua). | Up to twelve editable rings with twelve spell, carried-item, action-slot macro, or native system-action entries each. System actions include the Game Menu (`TOGGLEGAMEMENU`), world map, bags, and character panels. Native held-button release can activate a deliberate stick/D-pad selection; neutral release cancels. Mapped input uses explicit confirmation. | Automatic quest entries and sticky selection are not implemented. Macro entries require a unique existing macro and a matching action-bar slot. |
| Broader bindings and modifier choices | Device presets can bind triggers as actions, combine inputs with modifiers, and include additional device buttons. Modifier settings also support latching and additional layers. [Device example](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort/Model/Gamepad/Deck.lua), [settings](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort/Model/Data/Variables.lua). | Stick clicks, Back/Start and available triggers support assignments on four modifier pages. Native trigger or bumper modifiers, tap latching, expanded Vanilla commands and menu timing are configurable. | Extra physical inputs require bridge or mapper support. Back + Start remains reserved for native pause/recovery. |
| Item context menus | A controller popup for use/equip, sell, trade, split stacks, disenchant, inspect appearance, destroy and add/remove ring entries when applicable. [Item menu](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Menu/View/Popup/ItemMenu.lua). | Y/Triangle opens contextual use/equip, selling, bank transfer, trade/mail, pickup, action placement, splitting, preview and confirmed destroy/disenchant actions. Items can be added to utility rings. | Verify real inventory/profession eligibility and addon interactions. Remove ring entries through the ring editor. |
| Unit context menu | A controller replacement for the unit right-click menu, including target details and applicable actions. [Unit menu](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Menu/View/Popup/UnitMenu.lua). | A target menu shows unit information and applicable follow, trade, inspect, invite, assist and raid-marker actions. It rejects changed targets and unavailable actions. | Verify live interaction distances and party/raid permissions. This is a Vanilla target menu, not every modern unit-menu option. |
| Dedicated loot interface | A custom loot frame and quick-menu group-roll collection. [World settings](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_World/Database.lua). | Stock loot and group-roll frames receive the shared theme. A consolidated pending-roll panel offers permitted Need/Greed/Pass actions with item/timer revalidation. | The stock loot list remains in use; verify actual loot/roll lifecycles and movement transitions. |

Local evidence: [radial menu](../radial/radial.lua), [control assignments](../config/controls.lua),
[native input dispatch](../WindrunnerController.lua), [system actions](../config/proxied.lua),
[stock-bar hiding](../actionbars/bars.lua), [cursor actions](../cursor/actions.lua),
[contextual prompts](../cursor/tooltip.lua), [pet controls](../actionbars/pet.lua),
[unit actions](../cursor/unitmenu.lua), and [pending rolls](../cursor/lootpanel.lua).

## Setup and interface coverage

| Feature | ConsolePort offers | Windrunner today | Remaining difference / validation |
| --- | --- | --- | --- |
| Direct action selection | Edit bindings and action loadout together; choose where to place a spell through a dedicated spell menu. [Binding editor](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Config/View/Guide/OverviewEditor.lua), [spell menu](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Menu/View/Popup/SpellMenu.lua). | Selecting a binding opens one categorized picker with Menus, Spells, Items, and Macros tabs in a scrollable list. The same picker adds utility-ring entries and revalidates the source/destination before applying. | Character spellbooks, bag availability and macro/action-slot identities must be verified in the live client. |
| Flexible bar builder | Cluster, horizontal/crossbar and regular layouts, configurable components, visibility and styling. [Layout presets](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Bar/Model/Presets.lua), [bar settings](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Bar/Model/Database.lua). | Cluster, crossbar and horizontal presets have independent left/right anchors, shared move mode for bars/pet/chat, and combat/idle visibility. Circular modern styling and profile-backed positions are available. | A general arbitrary component builder is not implemented. Verify world rendering and readability at real UI scales. |
| Setup wizard and input tester | Controller-specific presets and guided stick/button tests. [Device presets](https://github.com/seblindfors/ConsolePort/tree/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort/Model/Gamepad), [input tests](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Config/View/Guide/ControlsTest.lua). | A first-run setup screen offers prompt presets, passive native button/stick/trigger indicators and calibration access. Xbox, PlayStation, Switch and Steam Deck labels are available. | Prompt presets add no native hardware compatibility. Live input indicators require the bridge; test actual devices separately. |
| Faster typing | Dictionary suggestions, autocorrection, configurable command buttons and multiple character sets. [Keyboard settings](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Keyboard/Database.lua), [keyboard module](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Keyboard/ConsolePort_Keyboard.toc). | Explicit word suggestions, optional remembered words, saved phrases and direct space/backspace actions extend the existing keyboard. Stock Vanilla uses a safe virtual-append fallback; commands and ambiguous cursor edits are preserved. | No autocorrect is implemented. The built-in suggestions use a small English dictionary; Unicode prediction is not provided. |
| Sharing layouts and bindings | Import/export of custom layouts, shared/account layouts and binding backups. [Layout management](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Bar/View/Config/Loadout.lua), [binding settings](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort/Model/Data/Variables.lua). | A bounded versioned import/export format provides preview, a pre-apply backup and up to twenty account-wide named exports. It shares whitelisted settings, control bindings and spell/item ring entries. | Live action-bar snapshots and action-slot macro ring entries are omitted from portable exports. Local profiles retain character action snapshots. |
| Richer quick-menu information | Dynamic entries and subtitles, including bag capacity, character level, social information and context-dependent options. [Menu model](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Menu/Model/Buttons.lua). | The wheel includes bag capacity, character level and group information, plus Tools and available Professions collections for relevant Vanilla actions. | Retail-only panels are excluded. Verify localized profession spell matching in the client. |
| Navigation customization | Adjustable repeat timings, panel/on-demand cursor behavior, click/context/cancel buttons, and broader frame scanning. [Cursor settings](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort_Cursor/Database.lua). | D-pad repeat delay/interval and panel A/B confirm/cancel swapping are exposed. Owned popups capture controller input, and contextual prompts update with the chosen preset. | Pointer clicks and keyboard send/cancel keep their dedicated roles. General remapping of every menu action is not implemented. |

Local evidence: [binding editor](../config/bindings.lua), [placement grid](../actionbars/placement.lua),
[layout editor](../ui/layout.lua), [profiles](../config/profiles.lua),
[keyboard](../keyboard/keyboard.lua), [configuration](../config/config.lua),
[frame hooks](../cursor/hooks.lua), [navigation](../cursor/cursor.lua),
[gameplay settings](../config/features.lua), [action picker](../config/actionpicker.lua),
[setup](../config/setup.lua), and [sharing](../config/sharing.lua).

## Features requiring client-level investigation

| Feature | ConsolePort offers | Windrunner today | Boundary |
| --- | --- | --- | --- |
| Camera-based soft targeting and interaction hints | Enemy/friendly soft targets and interaction indicators through newer client targeting APIs. [Targeting implementation](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort/Controller/Targeting.lua). | A visual crosshair, explicit target commands, healer target redirection, and optional Interact.dll/pointer interaction. The crosshair does not itself implement soft targeting. | Investigate separately. Our current addon/bridge does not expose the newer soft-target events or unit tokens. A Vanilla equivalent needs an API/extension audit and real-client testing. |
| Analog movement and camera behavior | Run/walk thresholds, strafe-angle transitions and character/camera coupling. [Movement implementation](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort/Controller/Movement.lua). | Analog sticks are read, but movement becomes forward/back/strafe on/off flags. Camera/pointer speed, radial deadzones and stick calibration already exist. | Smooth speed/direction changes need native engine work. Adjustable camera response and inversion can be investigated separately; neither should be described as already implemented. |
| Automatic cursor transitions and ground-targeted spells | Cursor handling responds to spell targeting, pickups, movement and free/centered cursor modes. [Mouse handling](https://github.com/seblindfors/ConsolePort/blob/2e693103ceb3934bf7a32badb5c7b543a688c7a5/ConsolePort/Controller/Mouse.lua). | Explicit camera/pointer switching and menu routing. No equivalent automatic ground-spell targeting workflow. | A focused spell-reticle workflow may be possible through existing mouse support, but cursor positioning and confirmation need live validation. Keep manual switching available. |

Native evidence is in the companion repository's `native/bridge.cpp`,
`native/runtime.cpp`, `native/dualsense.cpp` and `README.md`. Touchpad/gyro input
and extra physical buttons are not exposed by the current addon input mask.
XInput rumble already has a bridge API; DualSense rumble/touchpad/adaptive triggers
are documented as unimplemented. Do not treat all haptics as missing or assume
that ConsolePort supports every hardware feature on every client.

## Features already present

Windrunner already has controller action bars and modifier pages, system actions,
stance/form offsets, UI focus navigation, contextual item and loot prompts,
healer focus with target restoration, a quick menu, virtual typing, movable bars
and chat, typing-only chat, cooldown numbers, profiles, appearance settings,
deadzone calibration, and input recovery gates. ConsolePort often offers more
configuration or a dedicated interface for the same task. Those differences
should not be reported as complete absence.

Achievements, retail collections, vehicles, dragonriding and modern ping systems
are not useful parity targets for the original Vanilla client. Prefer the
controller workflow improvements that apply to its actual gameplay.
