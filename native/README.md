# Native controller bridge

Build the x86 DLL with Visual Studio 2022 C++ Build Tools and the Windows SDK:

```powershell
pwsh -File native/build.ps1 -OutputDirectory artifacts/native
```

The script emits `artifacts/native/WindrunnerController.dll`, uses the static MSVC
runtime (`/MT`), enables warnings as errors, and runs the native unit tests, bridge
tests, and an x86 DLL load smoke test.

## Runtime contract

The DLL exports a small set of functions for the addon. The most important entry
points are:

```lua
connected, buttons, lt, rt, lx, ly, rx, ry, foreground, generation, inputFlags,
rawLx, rawLy, rawRx, rawRy = WindrunnerController_Poll()

ok = WindrunnerController_Mouse(dx, dy, buttons, mode)
ok = WindrunnerController_Rumble(left, right)
ok = WindrunnerController_Release()
ok = WindrunnerController_SetGlue(enabled)
ok, message = WindrunnerController_RunFrame()
ok, message = WindrunnerController_RunRelease()
ok = WindrunnerController_SetMovement(mask)
ok = WindrunnerController_Jump()
ok, enabled = WindrunnerController_ToggleAutorun()
```

- `buttons` uses the standard XInput button mask.
- Trigger values are in `[0, 1]`.
- Stick axes use circular deadzones, rescale remaining travel, and clamp
  diagonals to the unit circle. Positive Y means up.
- `generation` changes when the active controller changes. The addon disarms
  until the new controller is neutral.
- `Mouse` emits relative mouse motion only. It never emits keyboard input.
- `Rumble` uses normalized motor strengths in `[0, 1]`.
- `Poll` refreshes a 250 ms heartbeat. The worker releases tracked mouse buttons
  when the heartbeat expires, the controller disconnects, or the client loses
  foreground focus.
- `RunFrame` and `RunRelease` dispatch through the client's protected Lua call
  boundary and restore the scope and stack on errors.

- The addon must call `WindrunnerController_Release()` on logout and when native
controller support is disabled. `WindrunnerController_SetGlue(0)` runs on
world entry and `(1)` on logout; the DLL delays the logout override by two
seconds so a UI reload cannot re-enable Glue input inside the world.

## Glue mode

The DLL is loaded before the addon, so it also covers the login and
character-selection (`Glue`) screens. Glue mode is active when a controller is
connected, the game is in the foreground, the client has no world client
pointer, no addon heartbeat is fresh, and the client has not registered its
in-world script functions. Those are independent world signals; script
registration also suppresses Glue input when the addon is disabled. Glue mode
emits keyboard and mouse events
with `SendInput`: sticks and D-pad map to arrow keys, the right stick moves the
cursor, A/B click, X opens the native on-screen keyboard, Y/Start send Enter,
Back sends Escape, LB/RB send Shift+Tab/Tab, and LT/RT turn the wheel. Every
emulated key and button is released when any Glue condition ends.

While the on-screen keyboard is open, the left stick and D-pad move the key
selection, A types the selected key, B is Backspace, LB is Space, RB is Tab, LT
toggles uppercase and symbols, Y/Start send Enter, and X or Back closes the
overlay. The window uses `WS_EX_NOACTIVATE`, so the game keeps keyboard focus,
and characters are injected as `SendInput` Unicode events.

## Input backends

- XInput is loaded from the Windows system directory. No XInput DLL is bundled.
- DualSense and DualSense Edge are read through a separate overlapped HID reader.
  USB report `01`, Bluetooth simple report `01`, and Bluetooth full report `31`
  are supported with CRC validation.
- The active backend is sticky until disconnect. XInput is preferred during
  selection.

## Install layout

The combined release places the DLL next to `WoW.exe` and the addon under
`Interface/AddOns/Windrunner-Controller`. You add `WindrunnerController.dll` to
`dlls.txt` and launch through VanillaFixes. See [docs/native.md](../docs/native.md)
for user-facing behavior and [docs/Installation.md](../docs/Installation.md) for
installation steps.

## Notes

- The bridge requires VanillaFixes to load. Starting `WoW.exe` directly does not
  load the DLL.
- Unsupported clients fail closed: the DLL validates the PE layout, client
  timestamp, image base, API fingerprints, and hook sites before installing hooks.
- The game executable is never modified on disk.
