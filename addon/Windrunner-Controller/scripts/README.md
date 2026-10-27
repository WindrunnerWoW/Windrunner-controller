# Scripts

This folder contains utility scripts for the Windrunner-Controller addon.

## generate-binding-textures.py

Regenerates the original Xbox and PlayStation controller diagrams and connector
texture in `textures/bindings`. Requires Python, Pillow, and numpy. Run
`python scripts/generate-binding-textures.py`. Control centers in the artwork
match `CONTROL_POINTS` in `config/bindings.lua`; update both if moving controls.

## generate-radial-textures.py

Regenerates the six neutral radial-menu textures in `textures/radial`. Requires
Python, Pillow, and numpy. Run `python scripts/generate-radial-textures.py` from
the addon folder. The runtime uses uncompressed 32-bit TGA files with power-of-two
dimensions; tinting and selection rotation happen in Lua.

## Packaging

Release packages are created from the repository root with `scripts/package-release.ps1`. It builds both the combined addon + DLL ZIP and the addon-only ZIP, and excludes development files automatically. See the root `README.md` for the command.
