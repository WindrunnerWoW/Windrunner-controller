# Troubleshooting

Common issues and solutions for Windrunner-Controller.

## Installation Issues

### Addon doesn't appear in addon list
**Cause:** Folder structure is incorrect.

**Solution:**
1. Check that the folder is named exactly `Windrunner-Controller` (the AddOns list displays **Windrunner-Controller**)
2. Ensure `Windrunner-Controller.toc` is directly in the folder
3. Not nested like `Windrunner-Controller/Windrunner-Controller/`

### "Interface out of date" warning
**Cause:** TOC version doesn't match game version.

**Solution:**
- Click "Load out of date AddOns" on character select
- Or enable in AddOns menu settings

## Action Bar Issues

### Action bars don't appear
**Cause:** UI error or conflict with other addons.

**Solution:**
1. Type `/reload` to reload UI
2. Disable other action bar addons
3. Check for Lua errors: `/console scriptErrors 1`

### Buttons are in wrong positions
**Solution:**
1. Open `/controller` configuration
2. Go to "Action Bars" section
3. Click "Reset Layout" to restore defaults

### Spells not updating to highest rank
**Solution:**
1. Check that Auto-rank is enabled in config
2. Run `/cerank debug` to see current spell ranks
3. Run `/cerank update` to manually update

## Controller Input Issues

The **Controller** page in `/controller` shows the current input state and provides right-stick sensitivity and diagnostics settings.

### Controller input does not start
**Cause:** Native input starts in a safe, unarmed state after entering the world.

**Solution:**
1. Center both sticks and release every controller button
2. Bring the game window into focus
3. Check the status on the Controller page; it explains whether input is paused, disconnected, or ready

### Controller shows as disconnected
**Solution:**
1. Connect or wake the controller
2. Make sure the addon and DLL are installed, `WindrunnerController.dll` is listed in `dlls.txt`, and the game is launched through VanillaFixes
3. Enable controller diagnostics on the Controller page if the connection still is not detected

Automatic activation requires the native DLL and a connected XInput or DualSense controller. A keyboard mapper alone cannot provide connection status; the interface and controller bindings remain dormant without a native connection.

If the controller disconnects while in the world, the addon reloads the interface after three seconds so the normal UI returns. A quick reconnect cancels the reload. Turn this off with **Gameplay > Reload UI after controller disconnect**.

### Login keyboard doesn't appear
**Cause:** The game is in exclusive fullscreen, or Glue input is not active.

**Solution:**
1. Press **X** (Square on DualSense) while the login or character-selection screen has focus
2. Use windowed or fullscreen-windowed mode; a topmost window cannot draw over an exclusive fullscreen device
3. Check `WindrunnerController.log` for `glue keyboard: open` and confirm `WindrunnerController.dll` is loaded through VanillaFixes

### Buttons work, but right-stick camera or pointer does not
**Cause:** The DLL is missing its mouse-input export or is out of date.

**Solution:** Replace `WindrunnerController.dll` with the current release, keep its entry in `dlls.txt`, and launch through VanillaFixes. Keyboard-mapped controls and native button movement can continue to work without right-stick camera or pointer input.

### Controller input is paused
**Cause:** Controller input pauses while text fields are being edited, or after using the pause shortcut.

**Solution:** Press the on-screen cancel button to leave a text field. To resume after pausing, press the Controller page's displayed **Back + Start** shortcut (on PlayStation-style layouts, Share + Options).

### Auto Run pauses the controller or reports ON without moving

An older native controller bridge changed the autorun flag without committing
movement through the game's input dispatcher. A later version also applied a
Lua action check to native autorun and treated a refused press as a fatal error.
Update both the Windrunner-Controller addon and the corrected
`WindrunnerController.dll`, close WoW completely, and relaunch through
VanillaFixes. Reloading the UI does not reload the DLL.

If the controller is already paused by the old error, use `/controller resume`
or Share + Options (Back + Start), then release all controls once. The updated
addon handles a refused Auto Run press without pausing controller input.

Assign **Auto Run** to the desired button under `/controller` > **Bindings**. In the
world, press once to start and again to stop. Settings and other menus capture
controller buttons for navigation, so test after closing them.

### Right-stick camera or pointer moves too slowly
**Solution:** Open `/controller` > **Controller** and adjust **Right-stick sensitivity**. Higher values move the camera and pointer faster.

If direct controller input is unavailable but you use a keyboard mapper, the addon can still work through mapped WoW bindings. The Controller page shows this distinction in its status message.

## Cast Bar Issues

### Cast bar doesn't appear
**Cause:** Cast bar might be disabled.

**Solution:**
1. Open `/controller` configuration
2. Go to "Cast Bar" section
3. Enable "Enable Cast Bar"

### Cast bar is behind other elements
**Cause:** Frame strata issue.

**Solution:**
- This should be fixed in recent versions
- Try `/reload` to refresh the UI

## Chat Issues

### Chat frame is in wrong position
**Solution:**
1. The addon repositions chat to bottom center
2. This is intentional for controller use
3. Adjust position in Chat settings if needed

### Virtual keyboard doesn't appear
**Cause:** Keyboard might be disabled.

**Solution:**
1. Open `/controller` configuration
2. Go to **Interface** > **Chat**
3. Enable "Virtual Keyboard"

## XP/Rep Bar Issues

### Bars don't show
**Cause:** Bars may be set to fade out.

**Solution:**
1. Open `/controller` configuration
2. Go to "XP/Rep Bars" section
3. Enable "Always Visible" for the bars you want

### Bars show wrong colors
**Solution:**
- XP bar: Purple (not rested) or Blue (rested)
- Rep bar: Colors based on faction standing
- This is intentional behavior

## Performance Issues

### Low FPS or lag
**Cause:** Too many OnUpdate scripts.

**Solution:**
1. Disable features you don't use
2. Reduce number of enabled bars
3. Check for conflicts with other addons

## Error Messages

### "attempt to call nil value"
**Cause:** Function doesn't exist or addon loaded incorrectly.

**Solution:**
1. Replace the addon folder with the current release
2. Make sure all files are present
3. Check for missing dependencies

### "Script ran too long"
**Cause:** Infinite loop or heavy processing.

**Solution:**
1. Report the issue on GitHub with steps to reproduce
2. Try disabling specific features to isolate the problem

## Reporting Bugs

If you encounter a bug:

1. **Enable script errors:** `/console scriptErrors 1`
2. **Note the error message** that appears
3. **Document steps to reproduce** the issue
4. **Check existing issues** on GitHub
5. **Create a new issue** with:
   - Error message
   - Steps to reproduce
   - Your WoW version
   - Other addons installed

## Getting Help

- **GitHub Issues:** Report bugs and feature requests
- **Documentation:** Read through feature docs
- **Controller diagnostics:** Enable in `/controller` > **Controller** for connection and input details

## Reset Everything

If all else fails, reset to defaults:

1. Log out of WoW
2. Back up and delete the current character's `WTF/Account/<Account>/<Realm>/<Character>/SavedVariables/Windrunner-Controller.lua`
3. To also reset controller sensitivity and diagnostics, delete the account-wide `WTF/Account/<Account>/SavedVariables/Windrunner-Controller.lua`
4. Log back in and reconfigure settings
