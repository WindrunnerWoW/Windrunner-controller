# Controller acceptance checks

## Verification boundary

Automated checks cover Lua 5.0 parsing, current action dispatch, stance offsets,
healer targeting and target restoration, input safety transitions, radial-sector
selection, hint timers, tuning controls, calibration, native bridge behavior, and
DLL loading. They model the client APIs.

Inventory checks exercise the current item menu, native/mapped control routing,
bag ID resolution, addon slot formats, stack limits, stale item/context rejection,
bank access, confirmation defaults and focus restoration under Lua 5.0. They do
not establish live profession eligibility or server inventory behavior.

The full physical-controller checks below remain **not run**. Automated checks do
not establish rendering quality, actual client ABI behavior in the world, camera
feel, or physical USB/Bluetooth behavior. The limited live review below records
only what was observed.

## Live UI review — 12 October 2026

Reviewed the installed addon in `C:\TurtleDev\04_client\gamebak` with mouse and
keyboard, initially at a 640×480 game viewport. A fresh client launch was needed
after installing the new TOC/XML file list. The later DualSense session reported
native HID input ready and controller connected. The user confirmed both sticks,
triggers, L3/R3 and Share/Options respond in the passive tester without moving the
character. After correcting its display-only Y direction, the user confirmed
pushing the sticks up moves the dots up. This does not establish full gameplay
acceptance.

| Check | Observed result |
| --- | --- |
| Startup and setup | Reload succeeds after replacing the unsupported one-argument frame anchors. |
| DualSense input tester | PlayStation body and markers align after applying the artwork crop and drawing the body above its backdrop. Stick direction is confirmed by the user; native pointer direction was unchanged. |
| Settings and bindings | Settings open; PlayStation labels are readable; stick clicks, Share/Options and triggers appear in Other controls. |
| System-action picker | Both binding modes open the same categorized picker; the scrollable list replaces paging and offers menus, spells, items, and macros. No assignments changed during this check. |
| Utility ring editor | Empty editor opens and closes after replacing the unsupported `HasFocus` method. Ring execution remains untested live. |
| Typing lifecycle | Physical slash-command entry opens the keyboard; submitting `/ce` closes it and shows settings. With typing-only visibility selected, history appears during input and hides again afterward, including after reload. |
| Action bars | Modern circular icons render at the client window's original proportions. Cooldowns and combat feedback remain untested live. |
| Radial menu | Circular icons render without the previous inner squares. Selection, labels, portrait and readable PlayStation prompts fit the later widescreen viewport. Escape closes the menu. |
| Layout editor | Bar and chat targets are reachable with controller focus, and move mode shows Cross/Circle/Square hints. The user confirmed Action bars moves left/right correctly, Circle restores the position and keeps the editor open, and Square saves and exits. The saved main-bar position survived a UI reload. Manual mouse dragging and the full set of independent/side/pet/chat moves remain open. |
| Profile sharing | Popup layering verified. Long exports stay clipped inside the fixed scroll viewport. Preview parses the current export and the footer buttons remain usable; Close works. Import application and account-library selection remain untested live. |

Full pet commands, inventory transactions, loot rolls, target actions, modifier
dispatch, calibration, disconnect/reconnect and combat behavior remain open.

## Setup

Install the updated Windrunner-Controller addon and Windrunner-Controller 0.3.1.
Launch through VanillaFixes, log in, enter the world, and release all
controls. Check `/controller status`. Test native input with competing controller
mappers disabled, then test the keyboard-mapped path separately.

Repeat with an XInput pad and a DualSense over USB and Bluetooth when available.
Record client extensions, controller model, connection type, resolution, and UI
scale with each result.

| Scenario | Expected result | Physical result |
| --- | --- | --- |
| First world entry | Held controls do nothing until neutral; readiness hint fades. | Not run |
| Calibration | A opens calibration; releasing A starts measurement; no movement occurs; settings save and input rearms. | Not run |
| Drift and full travel | Centered sticks remain still; full travel stays responsive after deadzone tuning. | Not run |
| Camera and pointer | Each speed changes only its own mode; R3 switches without a stuck mouse button. | Not run |
| Combat and modifiers | Press and release triggers alongside actions; displayed and executed pages agree. | Not run |
| Stances and forms | Warrior stances, druid forms/prowl, and rogue stealth use expected base and modifier slots. | Not run |
| Group healing | D-pad selects every member; casts hit that member; prior target returns; movement and turning continue. | Not run |
| Menus above healer focus | Inventory, merchant, settings, and radial menus capture input; closing restores healer control. | Not run |
| Interaction and looting | Interact or pointer fallback works; NPCs, loot windows, roll cards, and quests can be completed. | Not run |
| Inventory and action setup | Equip, use, sell, pick up, place, and clear actions using focus prompts; no unintended casts occur. | Not run |
| Item actions | Y/Triangle opens the focused/hovered item; split and place 1/half/all-but-one; preview gear; cancel/confirm destroy and disenchant; close bank or move the item while the menu is open. Verify pointer restoration and cached Bagshui/Bagnon views. | Not run |
| Chat and text fields | Virtual keyboard and physical typing agree; confirm applies once; cancel returns control. | Not run |
| Focus, disconnect, loading | Alt-tab, unplug, reconnect, replace controllers, reload, and zone while holding input; movement/mouse holds release and neutral is required. | Not run |
| Mapped controller | Jump/Autorun/Interact assignments and contextual navigation match their prompts. | Not run |
| UI scale and language | Text fits, focus is visible, and tooltips stay readable across resolutions/scales and Xbox/PlayStation prompts. | Not run |
| Appearance and profiles | Presets, accents, text/menu sizes, opacity and pointer preference update live; profile changes repaint all open addon UI. | Not run |
| Reduced animation | Quick menu opens immediately; status hints stay steady and still expire. | Not run |

## Visual review

Check the current rendered UI rather than the older screenshots in `docs/images`.
Check consistent padding, legible text from normal play distance, enough contrast
against the world, readable disabled controls, and clear focus on every actionable
control. Watch transitions and verify that notifications expire without covering
essential information. Capture current screenshots only after this pass.

## Addon-level feature acceptance scenarios

These full scenarios remain **Not run in a live game**. The narrower UI checks
above do not complete them. The automated Lua 5.0 suite models client APIs.

| Scenario | Expected result | Physical result |
| --- | --- | --- |
| Setup and prompts | Setup records observed buttons, stick motion and trigger values without interrupting normal polling; Xbox, PlayStation, Switch-style and Steam Deck prompts are readable. Alternate labels do not imply backend support. | Not run |
| Auxiliary modifier pages | Configure different stick-click, Start/Back and trigger actions on base, Shift, Ctrl and Ctrl+Shift pages; display and dispatch agree. | Not run |
| Pet, target and loot tools | Pet bar commands/slots, applicable unit actions, raid markers and pending roll choices are reachable and return focus safely. | Not run |
| Rings and action picker | Create/edit rings, add spell/item/macro entries, pick actions for slots, and activate/cancel on press or release as configured. | Not run |
| Layout and visibility | Independently move bars, touch bars, pet bar and chat; verify cluster/crossbar/horizontal layouts and always/combat/idle visibility at multiple UI scales. | Not run |
| Typing suggestions | Accept a suggestion or phrase through virtual typing; confirm slash commands and physical cursor-edited text are preserved; remembered words remain opt-in. | Not run |
| Profile sharing | Preview a valid import, apply after backup, reject malformed/oversized/unknown data without partial changes, and store/retrieve account layouts. Confirm action bars remain character-specific. | Not run |
| Local profile isolation | Save and clone a ring profile, edit the clone, and switch through a legacy profile without rings. Ring entries remain separate, old collections clear, and independent bars/pet positions restore. | Not run |

The native bridge remains limited to its documented XInput and DualSense inputs.
Switch-style and Steam Deck prompts are presentation presets only. Touchpad,
gyro, adaptive triggers, additional hardware buttons and smooth analog movement
remain excluded or require separate native work. No complete ConsolePort parity is
claimed.
