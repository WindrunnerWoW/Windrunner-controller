# Installation

## Download

Download the latest `WindrunnerController-vX.Y.Z.zip` from the [Releases page](https://github.com/WindrunnerWoW/WindrunnerController/releases).

## Install

The ZIP is laid out exactly like your WoW folder:

```text
Interface/
└── AddOns/
    └── Windrunner-Controller/
        ├── Windrunner-Controller.toc
        ├── main.lua
        └── ...
WindrunnerController.dll
```

1. Close World of Warcraft.
2. Extract the ZIP.
3. Copy the `Interface` folder into your WoW folder — the folder containing `WoW.exe`.
4. Copy `WindrunnerController.dll` into the same folder as `WoW.exe`.
5. Open `dlls.txt` in the WoW folder with a text editor.
6. Add this line at the end:

   ```text
   WindrunnerController.dll
   ```

   Do not remove or replace existing lines. If `dlls.txt` does not exist, create it with that line.
7. Install [VanillaFixes](https://github.com/hannesmann/vanillafixes) if you do not have it. The DLL only loads through VanillaFixes.
8. Launch the game through VanillaFixes:

   ```text
   VanillaFixes.exe WoW.exe
   ```

9. Enable **Windrunner-Controller** at the character select screen.
10. Connect a controller. It can navigate the login and character-selection screens; press **X** (Square) to open the on-screen keyboard and type account text. Enter the world, center both sticks, and release every button once.
11. Run `/controller status`.

> **Starting `WoW.exe` directly will not load the DLL.** Always launch through VanillaFixes.

## Requirements

- Windows 32-bit World of Warcraft 1.12.1, build 5875.
- VanillaFixes 1.5.3 or newer.
- Xbox/XInput, DualSense, or DualSense Edge controller.

Steam Input and DS4Windows should be disabled when testing direct DualSense input.

## Verify the installation

1. Connect a controller and launch the game.
2. Use the controller to navigate login and character selection. Press **X** (Square) to open the on-screen keyboard.
3. Center both sticks and release every button once in the world.
4. Run `/controller status`.

The status output should show the native DLL version and a connected controller.

## Updating

1. Close the game.
2. Download the new release ZIP and extract it.
3. Replace `Interface/AddOns/Windrunner-Controller` with the new folder.
4. Replace `WindrunnerController.dll` next to `WoW.exe`.
5. Keep the `WindrunnerController.dll` line in `dlls.txt`.

Your `WTF` settings are not touched.

## Uninstalling

1. Close the game.
2. Delete `Interface/AddOns/Windrunner-Controller`.
3. Delete `WindrunnerController.dll`.
4. Remove the `WindrunnerController.dll` line from `dlls.txt`.

To remove saved settings as well, delete the relevant `Windrunner-Controller.lua` files under `WTF/Account/.../SavedVariables/`.

## Troubleshooting installation

### The addon does not appear in the list

- The folder must be exactly `Interface/AddOns/Windrunner-Controller`.
- `Windrunner-Controller.toc` must be directly inside that folder.
- Enable **Load out of date AddOns** at character select.

### The addon loads but the controller does nothing

- Launch the game through VanillaFixes, not `WoW.exe`.
- Confirm `WindrunnerController.dll` is listed in `dlls.txt`.
- Run `/controller status`.
- Check `WindrunnerController.log` next to `WoW.exe`.

### The client is reported as unsupported

The package only supports the Windows 32-bit WoW 1.12.1 build 5875 client. It does not support newer Blizzard Classic clients.

See [Troubleshooting](Troubleshooting.md) for more help.
