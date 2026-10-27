# Windrunner Controller

<div align="center">
  <img src="docs/images/menu.png" width="270"/>
  <img src="docs/images/bars.png" width="270"/>
  <img src="docs/images/radial.png" width="270"/>
</div>

<div align="center">
  <img src="docs/images/bindings.png" width="270"/>
  <img src="docs/images/keyboard.png" width="270"/>
  <img src="docs/images/placement.png" width="270"/>
</div>

<h6 align="center">
    <a href="docs/Installation.md">Installation</a>
    ·
    <a href="docs/Configuration.md">Configuration</a>
    ·
    <a href="docs/Troubleshooting.md">Troubleshooting</a>
    ·
    <a href="https://github.com/WindrunnerWoW/WindrunnerController/releases">Releases</a>
</h6>

<div align="center">
  <img src="https://github.com/WindrunnerWoW/WindrunnerController/actions/workflows/ci.yml/badge.svg" alt="CI"/>
  <img src="https://github.com/WindrunnerWoW/WindrunnerController/actions/workflows/release.yml/badge.svg" alt="Release"/>
</div>

Windrunner Controller turns World of Warcraft 1.12.1 into a controller-first game. It combines a complete console-style interface addon with a native Windows DLL that reads Xbox/XInput and Sony DualSense controllers directly. Connect a controller and the interface appears. Disconnect it and the normal UI comes back.

## 🚀 Features

- **Native controller input** — XInput, DualSense, and DualSense Edge over USB or Bluetooth.
- **Login and character selection** — the DLL maps controller input to keyboard and mouse before the addon loads.
- **No keyboard emulation in the world** — movement, camera, and actions use the client's native input path.
- **Automatic UI switching** — controller interface when connected, normal WoW UI when disconnected.
- **Controller action bars** — page switching, pet controls, stance bars, and visual button prompts.
- **Cursor and menu navigation** — move through menus, bags, loot, tooltips, and the world map with a controller.
- **Radial quick menu** — editable spell, item, and macro rings with search.
- **On-screen keyboard** — chat typing in the world, plus a native login keyboard that works before the addon loads.
- **Profiles and themes** — import/export layouts and switch between Ember, Frost, and Grove.
- **Localization** — English, German, Spanish, Korean, Simplified Chinese, and Traditional Chinese.
- **Controller tuning** — camera and pointer speed, deadzones, and stick calibration.

## 📦 Installation

The release ZIP is already laid out exactly like your WoW folder:

```text
Interface/
└── AddOns/
    └── Windrunner-Controller/
WindrunnerController.dll
```

1. Download `WindrunnerController-vX.Y.Z.zip` from [Releases](https://github.com/WindrunnerWoW/WindrunnerController/releases).
2. Close World of Warcraft.
3. Extract the ZIP and copy the `Interface` folder and `WindrunnerController.dll` into your WoW folder.
4. Open `dlls.txt` in that folder with a text editor and add this line:

   ```text
   WindrunnerController.dll
   ```

   Do not remove or replace existing lines. If `dlls.txt` does not exist, create it with that line.
5. Install [VanillaFixes](https://github.com/hannesmann/vanillafixes) if you do not have it. The DLL only loads through VanillaFixes.
6. Launch the game through VanillaFixes: run `VanillaFixes.exe WoW.exe`.
7. Connect a controller. Log in; the controller navigates the login screen, and **X** / Square opens the on-screen keyboard for account text.
8. Enable **Windrunner-Controller** at character selection and enter the world.

> **Important:** Starting `WoW.exe` directly will not load the DLL. You must launch through VanillaFixes.

### Requirements

- Windows 32-bit World of Warcraft 1.12.1, build 5875.
- [VanillaFixes](https://github.com/hannesmann/vanillafixes) 1.5.3 or newer.
- An Xbox/XInput controller, DualSense, or DualSense Edge.
- Steam Input and DS4Windows should be disabled when testing direct DualSense input.

## 🎮 Controls

| Input | Behavior |
| --- | --- |
| Left stick | Move, navigate menus, or select a radial entry |
| Right stick | Camera, cursor, or radial selection |
| Right stick click (R3) | Toggle camera and cursor mode |
| A | Jump in the world; confirm in menus |
| X / Y / B | Action slots or menu controls |
| D-pad | Menu navigation and action slots |
| LB / RB | Action slots or menu controls |
| LT / RT | Action pages 2 and 3 |
| LT + RT | Action page 4 |
| Left stick click | Select nearest enemy |
| Back | World map |
| Start | Open or close the radial menu |
| Back + Start | Pause or resume controller input |

The interface shows Xbox labels by default. For DualSense, you can change the layout.

Before the world loads, the DLL provides its own login keyboard. Press **X** (Square on DualSense) on the login or character-selection screen to open it. Move with the left stick or D-pad, type with **A**, switch fields with **RB**, toggle uppercase/symbols with **LT**, and close it with **X** or **Back**. **B** is Backspace and **LB** is Space.

The **Tools** quick menu includes **Game menu**, and utility rings can hold native system actions such as Game Menu, world map, bags, and character panels. Add them through **Gameplay > Edit utility rings > Add Entry**.

## 🛠️ Usage

Open the configuration panel in game:

```text
/controller
```

Useful controller commands:

```text
/controller status          Show the DLL version and connection state
/controller help            Open Help & Tutorials
/controller cursor          Toggle camera and pointer mode
/controller calibrate       Measure stick drift
/controller camera 100-3000 Set camera speed
/controller pointer 100-3000 Set pointer speed
/controller sensitivity 100-3000 Set both speeds
```

The first-run setup walks through controller type, button prompts, stick calibration, and the basic layout. Everything can be changed later from the **Controller**, **Gameplay**, **Interface**, and **Appearance** pages.

## 💬 FAQ

#### Do I need a controller to use the addon?

Yes for the controller interface. The addon stays dormant without a native controller connection, so your normal UI is not changed.

#### Does the addon work without the DLL?

No. The addon provides the interface, but the DLL provides native input. Use the combined ZIP and add the DLL to `dlls.txt`.

#### Does it work on official Blizzard Classic clients?

No. This build targets the Windows 32-bit 1.12.1 client, build 5875, used by Windrunner WoW and similar Vanilla servers.

#### Where are my settings saved?

Per-character interface settings are stored in `WTF/.../SavedVariables/`. The account-wide controller preferences are stored in `WTF/Account/<Account>/SavedVariables/`. Updating the addon does not remove them.

## 🧑‍💻 Building from source

### Requirements

- Windows 10 or newer.
- Visual Studio 2022 Build Tools with **Desktop development with C++** and a Windows SDK.
- PowerShell 7 or Windows PowerShell 5.1.

### Build the native DLL

```powershell
pwsh -File native/build.ps1 -OutputDirectory artifacts/native
```

This compiles the x86 DLL, runs the native unit tests, bridge tests, and the DLL load smoke test.

### Run the addon tests

```powershell
pwsh -File tests/Test-Addon.ps1 -ExperienceAddonRoot addon/Windrunner-Controller
```

The script builds Lua 5.0.3 with MSVC when needed, then runs the controller, layout, inventory, radial, keyboard, and localization regression suites.

### Create a release ZIP

```powershell
pwsh -File scripts/package-release.ps1 -DllPath artifacts/native/WindrunnerController.dll
```

The output is written to `artifacts/WindrunnerController-vX.Y.Z.zip`, a drag-and-drop package with the addon and DLL.

### Publish a release

Every push to `main` publishes a release automatically. The Release workflow takes the latest `vX.Y.Z` tag and bumps it from the commit messages since then:

- `BREAKING CHANGE` or `type!:` bumps the major version
- `feat:` bumps the minor version
- anything else bumps the patch version

It then builds the DLL, packages the ZIP with the new version stamped into the `.toc`, tags the commit, and publishes a GitHub release with the ZIP attached.

### Project layout

```text
addon/Windrunner-Controller/  WoW addon source, copied to Interface/AddOns
native/                       C++ DLL source and native tests
scripts/                      Build and release packaging
tests/                        Lua 5.0 and native regression tests
docs/                         User documentation
```

For the native bridge contract and internals, see [docs/native.md](docs/native.md).

## 🩺 Troubleshooting

- **The addon does not appear in the AddOns list** — make sure the folder is exactly `Interface/AddOns/Windrunner-Controller` and `Windrunner-Controller.toc` is directly inside it.
- **`/controller status` says native input is unavailable** — launch the game through VanillaFixes, not `WoW.exe`. Confirm `WindrunnerController.dll` is listed in `dlls.txt`.
- **The controller connects but nothing responds** — center both sticks and release every button once. Check `/controller status` and `WindrunnerController.log` next to `WoW.exe`.
- **Sticks drift** — run `/controller calibrate` or adjust the deadzone on the Controller page.
- **DualSense is not detected** — disable Steam Input and DS4Windows, and make sure HidHide allows the game to see the controller.
- **The UI stays on the normal bars** — controller input is inactive while typing, in loading screens, when the game loses focus, or before the controller is armed.
- **The normal UI does not return after disconnecting** — the addon reloads the interface three seconds after a disconnect. A quick reconnect cancels it; disable it under **Gameplay > Reload UI after controller disconnect**.
- **The login keyboard is not visible** — use windowed or fullscreen-windowed mode. A topmost window cannot draw over an exclusive fullscreen device.

More help: [docs/Troubleshooting.md](docs/Troubleshooting.md).

## 🤝 Contributing

Contributions are welcome. Open an issue for bugs or feature requests, or send a pull request with a focused change. Please run the native and addon tests before opening a PR.

## 📄 License

Windrunner Controller is licensed under the **GNU Affero General Public License v3.0**. See [LICENSE](LICENSE) for the full text.
