# Windrunner Controller

A controller-first interface for World of Warcraft 1.12.1 that pairs a console-style addon with native XInput and DualSense support.

The interface activates automatically when the native DLL detects a controller. Disconnecting restores the normal UI; reconnecting requires no reload.

## Features

- **🎮 Gamepad-Style Action Bars** - Controller-optimized button layout with visual button prompts
- **🔗 System Bindings** - Assign controller buttons to system actions (Jump, Auto Run, etc.)
- **🎯 Cursor Navigation** - Navigate UI elements with controller/keyboard
- **📻 Radial Menu** - Quick access menu for common actions
- **⌨️ Virtual Keyboard** - On-screen keyboard for chat input
- **💬 Chat Integration** - Repositioned chat frame with controller-friendly input
- **📊 XP/Reputation Bars** - Custom progress bars below chat
- **🔮 Cast Bar** - Custom casting bar above chat
- **🔄 Auto Spell Rank** - Automatically updates spells to highest rank
- **⚙️ Full Configuration** - Extensive options for customization

## Quick Start

1. [Install the addon and DLL](Installation.md), including the `dlls.txt` entry and VanillaFixes.
2. Connect a controller and launch the game through VanillaFixes: run `VanillaFixes.exe WoW.exe`.
3. The controller navigates login and character selection; press **X** (Square) to open the on-screen keyboard for account text. Enable **Windrunner-Controller** at character select.
4. Open `/controller`; choose Xbox or PlayStation under **Interface**.
5. Center both sticks and release every button after entering the world. Use the **Controller** page to check connection status and tune the sticks.

## Documentation

- [Installation Guide](Installation.md)
- [Configuration Options](Configuration.md)
- [Addon Integrations](AddonIntegrations.md)
- **Features:**
  - [Action Bars](features/ActionBars.md)
  - [Cursor Navigation](features/CursorNavigation.md)
  - [Radial Menu](features/RadialMenu.md)
  - [Virtual Keyboard](features/Keyboard.md)
  - [XP/Rep Bars](features/XPBars.md)
  - [Cast Bar](features/CastBar.md)
  - [Auto Spell Rank](features/AutoRank.md)
- [Keybindings](Keybindings.md)
- [Troubleshooting](Troubleshooting.md)

## Screenshots

![Action Bars](images/bars.png)

## Requirements

- World of Warcraft 1.12.1 (Vanilla) or TurtleWoW
- The combined Windrunner Controller release, launched through VanillaFixes
- Xbox/XInput, DualSense, or DualSense Edge controller

## Support

- Report issues on [GitHub Issues](https://github.com/WindrunnerWoW/WindrunnerController/issues)
- Check the [Troubleshooting Guide](Troubleshooting.md) for common problems

## License

Licensed under the GNU Affero General Public License v3.0. See the repository `LICENSE` file.
