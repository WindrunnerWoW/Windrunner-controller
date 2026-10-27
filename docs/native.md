# Native controller bridge

Native XInput and direct Sony DualSense support for the Windows 32-bit World of Warcraft 1.12.1 (build 5875) client. Connect an Xbox/XInput controller or a DualSense/DualSense Edge over USB or Bluetooth. The controller navigates the login and character-selection screens, and **X** opens a native on-screen keyboard for account text. Then play with the controller. Steam is not required.

The native bridge provides input through a DLL. The **Windrunner-Controller** addon contains the controller logic and interface. The combined release installs both components together.

## Install and share

1. Extract `WindrunnerController-vX.Y.Z.zip` to a writable folder.
2. Copy the `Interface` folder into your WoW folder.
3. Copy `WindrunnerController.dll` next to `WoW.exe`.
4. Add `WindrunnerController.dll` on its own line in `dlls.txt` without removing existing entries.
5. Install VanillaFixes if it is missing. The DLL only loads through VanillaFixes.
6. Launch the game through VanillaFixes. The controller navigates the login screen and character selection; press **X** to open the on-screen keyboard for account text.
7. Enable **Windrunner-Controller** at character selection, enter the world, center the sticks, and release the buttons once to arm input. `/controller status` reports whether native input is available.

You can give other players the ZIP. It contains the addon, controller DLL, and documentation. It contains no game files or account data.

Controller support loads through VanillaFixes. Starting WoW.exe directly will not load it. Other launchers must preserve WindrunnerController.dll in dlls.txt and call the extension's Load export, as VanillaFixes does.

## Controls

| Input | Behavior |
| --- | --- |
| Left stick | Forward/back and strafe in the world; focus navigation in menus; radial selection when enabled |
| Right stick | Camera in play; radial selection when enabled; cursor in other menus or pointer mode |
| Right stick click (R3) | Toggle camera/cursor mode |
| A | Jump in the default game layout; confirm in menus |
| X / Y / B, D-pad, RB / LB | Windrunner-Controller action slots or menu controls |
| LT / RT / both | Action pages 2 / 3 / 4 |
| Left stick click | Select nearest enemy |
| Back | World map |
| Start | Open/close the Windrunner-Controller radial menu |
| Back + Start | Pause/resume controller input |

The UI uses Xbox labels. On DualSense, Cross = A, Square = X, Triangle = Y, Circle = B, L1/R1 = LB/RB, L2/R2 = LT/RT, Create = Back, and Options = Start. L3/R3 are stick clicks. Turn off Steam Input or DS4Windows mapping when testing direct DualSense input; HidHide must allow the game to see the controller. An active XInput controller keeps control until it disconnects.

The default TOGGLEAUTORUN action works from a controller action slot. `/controller` opens the configuration, and `/controller status` lists controller commands. Click R3 or run `/controller cursor` to switch between camera and pointer mode. In pointer mode, A holds the left mouse button and X holds the right mouse button. With the current addon, the radial menu accepts either stick by default, A to select, and B or Start to close. The Controller page provides independent camera and pointer speeds, adjustable deadzones, and one-second stick drift calibration. `/controller camera 100-3000` and `/controller pointer 100-3000` tune each speed; `/controller calibrate` measures centered-stick drift. `/controller sensitivity 100-3000` still sets both speeds together.

With the current addon, choose **Controller > Radial selection stick > Left / Right / Both** for the quick menu and utility rings. Both is the default. The left stick and D-pad move menu focus with the repeat settings configured in Gameplay.

## Login and character selection

The DLL loads before the addon and handles the Glue screens (login and character selection) on its own. When a controller is connected, the game is in the foreground, the client has no world pointer or registered world scripts, and the addon has no fresh heartbeat, the DLL emulates keyboard and mouse with `SendInput`:

| Input | Behavior |
| --- | --- |
| Left stick / D-pad | Arrow keys with repeat |
| Right stick | Mouse cursor |
| A / B | Left / right mouse button |
| X | Open or close the on-screen keyboard |
| Y / Start | Enter |
| Back | Escape |
| RB | Tab |
| LB | Shift+Tab |
| LT / RT | Mouse wheel up / down |

### On-screen keyboard

The addon and its Lua bridge are not available on the account login screen, so the DLL draws its own keyboard overlay. Press **X** (Square on DualSense) on the login or character-selection screen to open it, and press **X** again (or **Back**) to close it.

| Input | Behavior |
| --- | --- |
| Left stick / D-pad | Move the key selection |
| A | Type the selected key |
| B | Backspace (hold to repeat) |
| LB | Space (hold to repeat) |
| RB | Tab (switch field) |
| LT | Toggle uppercase and symbols |
| Y / Start | Enter |
| X / Back | Close the keyboard |

Mouse clicks on the overlay also work. Characters are sent as Unicode input to the focused login field, so the password field does not need a physical keyboard. The overlay never takes focus away from the game. If it is not visible, check that the game is running in windowed or fullscreen-windowed mode; topmost windows cannot draw over an exclusive fullscreen device.

Glue input stops as soon as the client reports a world pointer or world scripts, a fresh addon heartbeat, a disconnected controller, or a loss of foreground focus. On logout, the addon asks the DLL to re-enable Glue input for the character screen; the DLL starts that override two seconds after `PLAYER_LOGOUT` and cancels it on world entry, so a UI reload cannot re-enable Glue input inside the world.

Inside the world, native input stays inactive while typing, during loading screens, on disconnect, and when the game loses focus. Reconnection requires neutral sticks and buttons. Keyboard bindings remain available, and the merged addon does not save controller bindings over account bindings.

## Uninstall, update, and diagnostics

To update, close the game, replace `Interface/AddOns/Windrunner-Controller` and `WindrunnerController.dll`, and keep the DLL line in `dlls.txt`.

To uninstall, close the game, delete the addon folder and `WindrunnerController.dll`, and remove the DLL line from `dlls.txt`.

For troubleshooting, check `/controller status` and `WindrunnerController.log` beside `WoW.exe`. The log records `glue input: on` / `glue input: off`, `glue keyboard: open` / `glue keyboard: close`, `glue override: armed/active/off`, and `world probe: inWorld=... client=... player=... scriptReady=...` when Glue state changes. Status should show the native component version loaded (currently 0.3.1); an older DLL needs a full game restart. Unsupported API fingerprints keep the DLL disabled. This build targets WoW 1.12.1 build 5875, not newer Blizzard Classic clients. Direct HID support covers DualSense and DualSense Edge. DualShock 4 and other DirectInput-only controllers still need an XInput mapper. DualSense rumble, touchpad, and adaptive triggers are not implemented.

The bridge routes jump through the stock jump logic, handles TOGGLEAUTORUN in the client's input state, and exposes stick movement through the verified native input dispatcher. No on-disk game executable patch is used.

Autorun uses the same dispatcher and the same native input checks as stick
movement, matching the stock `ToggleAutoRun` behavior. After updating the DLL,
close and restart the game; a UI reload cannot activate native changes.

## Build and verify

Use Visual Studio C++ Build Tools with the Windows SDK. Run `pwsh -File native/build.ps1 -OutputDirectory artifacts/native` to compile the x86 DLL and run the native tests. The Lua regression suites and package builder are included in the repository.

`tests/Test-Addon.ps1` runs the addon suites against `addon/Windrunner-Controller`. `scripts/package-release.ps1` creates the combined and addon-only ZIPs without game files or account data.
