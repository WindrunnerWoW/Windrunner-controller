#pragma once

#include <windows.h>

namespace tc {

struct ControllerState {
    bool connected = false;
    unsigned buttons = 0;
    double lt = 0, rt = 0, lx = 0, ly = 0, rx = 0, ry = 0;
    double rawLx = 0, rawLy = 0, rawRx = 0, rawRy = 0;
    bool foreground = false;
    unsigned generation = 0;
};

// Called by VanillaFixes' main-thread Load entry point, never under DllMain.
bool StartRuntime();
// Called on the main thread once the client has registered its in-world script
// functions. This is an independent world signal from the addon heartbeat.
void SetWorldScriptReady();
// Called by the addon on world entry/exit. Logout arms a short delayed Glue
// override so the login keyboard works again on the character screen.
void SetGlueOverride(bool enabled);
ControllerState Poll();
bool CanDispatch();
bool HasActiveInput();
bool Mouse(double dx, double dy, unsigned buttons, int mode);
bool Rumble(double left, double right);
void Release();
void Log(const char* format, ...);
void SetModule(HMODULE module);

} // namespace tc
