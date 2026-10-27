#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include "runtime.h"
#include "input_math.h"
#include "dualsense.h"
#include "glue.h"
#include "keyboard.h"
#include <Xinput.h>
#include <atomic>
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cwchar>

namespace tc {
namespace {
using GetStateFn = DWORD (WINAPI*)(DWORD, XINPUT_STATE*);
using SetStateFn = DWORD (WINAPI*)(DWORD, XINPUT_VIBRATION*);
SRWLOCK lock = SRWLOCK_INIT;
SRWLOCK logLock = SRWLOCK_INIT;
HMODULE module = nullptr;
HMODULE xinput = nullptr;
GetStateFn getState = nullptr;
SetStateFn setState = nullptr;
ControllerSelection selection;
constexpr int hidSlot = 4;
unsigned hidGeneration = 0, polledGeneration = 0;
ULONGLONG nextDiscovery = 0;
ControllerState state;
SafetyState safety;
std::atomic<bool> worldScriptReady{false};
std::atomic<std::uint64_t> glueOverrideAt{0};
MouseResidual residual;
WORD motorLeft = 0, motorRight = 0;
bool started = false;

bool GameForeground() {
    const HWND window = GetForegroundWindow();
    DWORD process = 0;
    if (window) GetWindowThreadProcessId(window, &process);
    return process != 0 && process == GetCurrentProcessId();
}

bool SendButtons(unsigned desired, long dx = 0, long dy = 0) {
    const unsigned old = safety.heldButtons;
    INPUT events[3] = {};
    unsigned count = 0;
    if (dx || dy) {
        events[count].type = INPUT_MOUSE;
        events[count].mi.dx = dx;
        events[count].mi.dy = dy;
        events[count].mi.dwFlags = MOUSEEVENTF_MOVE;
        ++count;
    }
    // Send button changes before movement so the very first camera frame
    // reaches the client with RMB already down.
    INPUT buttons = {};
    buttons.type = INPUT_MOUSE;
    if ((old ^ desired) & 1) buttons.mi.dwFlags |= (desired & 1) ? MOUSEEVENTF_LEFTDOWN : MOUSEEVENTF_LEFTUP;
    if ((old ^ desired) & 2) buttons.mi.dwFlags |= (desired & 2) ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_RIGHTUP;
    if (buttons.mi.dwFlags) {
        if (count) events[1] = events[0];
        events[0] = buttons;
        ++count;
    }
    if (!count) return true;
    const UINT sent = SendInput(count, events, sizeof(INPUT));
    if (!sent) return false;
    // Partial success of a button-plus-move batch still changed the buttons.
    if (buttons.mi.dwFlags) safety.heldButtons = desired;
    return sent == count;
}

void StopMotors() {
    if ((motorLeft || motorRight) && setState && selection.active >= 0 && selection.active < hidSlot) {
        XINPUT_VIBRATION off = {};
        setState(static_cast<DWORD>(selection.active), &off);
    }
    motorLeft = motorRight = 0;
}

void ReleaseLocked() {
    SendButtons(0);
    residual.Reset();
    StopMotors();
}

void SampleLocked() {
    XINPUT_STATE sample = {};
    const DualSenseConnection hid = PollDualSense();
    const int previous = selection.active;
    const auto now = GetTickCount64();
    const bool hidValid = hid.connected && !hid.Expired(now);
    if ((selection.active == hidSlot && (!hidValid || hid.generation != hidGeneration)) ||
        (selection.active >= 0 && selection.active < hidSlot && (!getState || getState(selection.active, &sample) != ERROR_SUCCESS))) {
        ReleaseLocked();
        selection.Set(-1);
        nextDiscovery = now;
    }
    if (selection.active < 0 && now >= nextDiscovery) {
        nextDiscovery = now + 500;
        for (int slot = 0; slot != XUSER_MAX_COUNT; ++slot) {
            if (getState && getState(slot, &sample) == ERROR_SUCCESS) { selection.Set(slot); break; }
        }
        if (selection.active < 0 && hidValid) { selection.Set(hidSlot); hidGeneration = hid.generation; }
    }
    if (selection.active == hidSlot) {
        sample.Gamepad.wButtons = static_cast<WORD>(hid.state.buttons);
        sample.Gamepad.bLeftTrigger = hid.state.lt; sample.Gamepad.bRightTrigger = hid.state.rt;
        sample.Gamepad.sThumbLX = hid.state.lx; sample.Gamepad.sThumbLY = hid.state.ly;
        sample.Gamepad.sThumbRX = hid.state.rx; sample.Gamepad.sThumbRY = hid.state.ry;
    }
    state = {};
    state.connected = selection.active >= 0;
    state.generation = selection.generation;
    state.foreground = GameForeground();
    if (state.connected) {
        state.buttons = sample.Gamepad.wButtons;
        state.lt = sample.Gamepad.bLeftTrigger / 255.0;
        state.rt = sample.Gamepad.bRightTrigger / 255.0;
        state.rawLx = Axis(sample.Gamepad.sThumbLX); state.rawLy = Axis(sample.Gamepad.sThumbLY);
        state.rawRx = Axis(sample.Gamepad.sThumbRX); state.rawRy = Axis(sample.Gamepad.sThumbRY);
        const Stick left = NormalizeStick(sample.Gamepad.sThumbLX, sample.Gamepad.sThumbLY,
                                         XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE / 32767.0);
        const Stick right = NormalizeStick(sample.Gamepad.sThumbRX, sample.Gamepad.sThumbRY,
                                          XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE / 32767.0);
        state.lx = left.x; state.ly = left.y; state.rx = right.x; state.ry = right.y;
    }
    safety.connected = state.connected;
    safety.foreground = state.foreground;
    if (!safety.CanInject(now)) ReleaseLocked();
    if (previous != selection.active) Log("controller slot: %d -> %d (generation %u)", previous, selection.active, selection.generation);
}

bool HeartbeatFresh(std::uint64_t now) {
    return safety.hasHeartbeat && now >= safety.heartbeat && now - safety.heartbeat < SafetyState::heartbeatMs;
}

bool ReadValue(std::uintptr_t address, void* out, std::size_t length) {
    MEMORY_BASIC_INFORMATION region = {};
    if (VirtualQuery(reinterpret_cast<LPCVOID>(address), &region, sizeof(region)) != sizeof(region)) return false;
    if (region.State != MEM_COMMIT || (region.Protect & (PAGE_GUARD | PAGE_NOACCESS))) return false;
    const DWORD access = region.Protect & 0xff;
    if (access != PAGE_READONLY && access != PAGE_READWRITE && access != PAGE_WRITECOPY &&
        access != PAGE_EXECUTE_READ && access != PAGE_EXECUTE_READWRITE && access != PAGE_EXECUTE_WRITECOPY)
        return false;
    const auto begin = reinterpret_cast<std::uintptr_t>(region.BaseAddress);
    const auto end = begin + region.RegionSize;
    if (address < begin || address >= end || (end - address) < length) return false;
    std::memcpy(out, reinterpret_cast<const void*>(address), length);
    return true;
}

struct WorldProbe {
    std::uint32_t client = 0;
    std::uint32_t player = 0;
    // Fail closed: an unreadable client global must never let Glue input run.
    bool inWorld = true;
};

// The client's action guard uses the client and player pointers to decide
// whether the player is ready. The client pointer alone is the reliable Glue
// boundary on this client: it is zero on the account login screen and non-zero
// once a world client exists. The script registration event is a second,
// addon-independent world signal. The player pointer is diagnostic only.
WorldProbe ReadWorld() {
    WorldProbe probe;
    if (!ReadValue(0x00B71290, &probe.client, sizeof(probe.client))) return probe;
    probe.inWorld = InWorldClient(probe.client) || worldScriptReady.load(std::memory_order_relaxed);
    if (probe.client && !ReadValue(static_cast<std::uintptr_t>(probe.client) + 0xD8,
                                   &probe.player, sizeof(probe.player)))
        probe.player = 0;
    return probe;
}

DWORD WINAPI Worker(void*) {
    bool seenWorld = false;
    bool lastInWorld = false;
    bool lastOverride = false;
    for (;;) {
        Sleep(8);
        ControllerState snapshot = {};
        std::uint64_t now = 0;
        bool fresh = false;
        AcquireSRWLockExclusive(&lock);
        SampleLocked();
        snapshot = state;
        now = GetTickCount64();
        fresh = HeartbeatFresh(now);
        ReleaseSRWLockExclusive(&lock);
        const WorldProbe world = ReadWorld();
        const std::uint64_t overrideAt = glueOverrideAt.load(std::memory_order_relaxed);
        const bool overrideActive = overrideAt != 0 && now >= overrideAt;
        if (!seenWorld || world.inWorld != lastInWorld) {
            Log("world probe: inWorld=%d client=0x%08X player=0x%08X scriptReady=%d override=%d",
                world.inWorld ? 1 : 0, world.client, world.player,
                worldScriptReady.load(std::memory_order_relaxed) ? 1 : 0,
                overrideAt != 0 ? 1 : 0);
            seenWorld = true;
            lastInWorld = world.inWorld;
        }
        if (overrideActive != lastOverride) {
            Log("glue override: %s", overrideActive ? "active" : "off");
            lastOverride = overrideActive;
        }
        // While a logout override is armed, keep Glue input off during the
        // transition, then force it on. This ignores both the heartbeat and the
        // script-registration world signals until the addon enters the world.
        bool glueInWorld = world.inWorld;
        bool glueFresh = fresh;
        if (overrideAt != 0) {
            glueInWorld = !overrideActive;
            glueFresh = !overrideActive;
        }
        GlueTick(snapshot, glueInWorld, glueFresh, now);
        KeyboardPump();
    }
}

bool LoadXInput() {
    wchar_t systemDirectory[MAX_PATH] = {};
    const UINT length = GetSystemDirectoryW(systemDirectory, MAX_PATH);
    if (!length || length >= MAX_PATH) return false;
    const wchar_t* providers[] = {L"xinput1_4.dll", L"xinput9_1_0.dll", L"xinput1_3.dll"};
    for (const auto provider : providers) {
        wchar_t path[MAX_PATH] = {};
        if (swprintf_s(path, L"%ls\\%ls", systemDirectory, provider) < 0) continue;
        HMODULE candidate = LoadLibraryW(path);
        if (!candidate) continue;
        auto getter = reinterpret_cast<GetStateFn>(GetProcAddress(candidate, "XInputGetState"));
        auto setter = reinterpret_cast<SetStateFn>(GetProcAddress(candidate, "XInputSetState"));
        if (!getter || !setter) { FreeLibrary(candidate); continue; }
        xinput = candidate; getState = getter; setState = setter;
        Log("XInput provider: %ls", path);
        return true;
    }
    return false;
}
} // namespace

void SetModule(HMODULE value) { module = value; }

void SetWorldScriptReady() {
    worldScriptReady.store(true, std::memory_order_relaxed);
    // A recent logout override may still be transitioning to the character
    // screen. Keep it until the addon explicitly enters the world; an older
    // orphaned override is cleared here as a safety net.
    const std::uint64_t overrideAt = glueOverrideAt.load(std::memory_order_relaxed);
    if (overrideAt == 0 || GetTickCount64() > overrideAt + 5000)
        glueOverrideAt.store(0, std::memory_order_relaxed);
}

void SetGlueOverride(bool enabled) {
    if (enabled) {
        // PLAYER_LOGOUT also fires on a UI reload. Delay the override so a
        // reload that immediately re-enters the world cannot re-enable Glue
        // input inside the world. Duplicate logout events keep the original
        // deadline instead of postponing it.
        worldScriptReady.store(false, std::memory_order_relaxed);
        if (glueOverrideAt.load(std::memory_order_relaxed) == 0)
            glueOverrideAt.store(GetTickCount64() + 2000, std::memory_order_relaxed);
        Log("glue override: armed for logout");
    } else {
        glueOverrideAt.store(0, std::memory_order_relaxed);
        worldScriptReady.store(true, std::memory_order_relaxed);
        Log("glue override: released for world");
    }
}

void Log(const char* format, ...) {
    wchar_t path[MAX_PATH] = {};
    if (!module || !GetModuleFileNameW(module, path, MAX_PATH)) return;
    wchar_t* slash = std::wcsrchr(path, L'\\');
    if (!slash) return;
    if (wcscpy_s(slash + 1, MAX_PATH - (slash + 1 - path), L"WindrunnerController.log") != 0) return;
    AcquireSRWLockExclusive(&logLock);
    FILE* file = nullptr;
    if (_wfopen_s(&file, path, L"ab") == 0 && file) {
        std::fprintf(file, "[%llu] ", GetTickCount64());
        va_list args; va_start(args, format);
        std::vfprintf(file, format, args);
        va_end(args);
        std::fputc('\n', file);
        std::fclose(file);
    }
    ReleaseSRWLockExclusive(&logLock);
}

bool StartRuntime() {
    if (started) return true;
    if (!LoadXInput()) Log("No system XInput provider; direct DualSense input remains available");
    // The startup hook and poller live for the lifetime of the game. Pin this
    // module so an accidental FreeLibrary cannot leave dangling callbacks.
    HMODULE pinned = nullptr;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
                          reinterpret_cast<LPCWSTR>(&StartRuntime), &pinned)) return false;
    if (!StartDualSense()) return false;
    AcquireSRWLockExclusive(&lock);
    SampleLocked();
    ReleaseSRWLockExclusive(&lock);
    HANDLE worker = CreateThread(nullptr, 0, Worker, nullptr, 0, nullptr);
    if (!worker) { Log("ERROR: polling thread creation failed: %lu", GetLastError()); return false; }
    CloseHandle(worker);
    started = true;
    return true;
}

ControllerState Poll() {
    AcquireSRWLockExclusive(&lock);
    // The addon polls every frame while it is loaded. A fresh heartbeat is an
    // independent world signal: it suppresses Glue input even if the client
    // pointer check ever disagrees during its own loading transitions.
    safety.Beat(GetTickCount64());
    state.foreground = GameForeground();
    safety.foreground = state.foreground;
    if (!state.foreground) ReleaseLocked();
    const ControllerState result = state;
    polledGeneration = state.generation;
    ReleaseSRWLockExclusive(&lock);
    return result;
}

bool CanDispatch() {
    AcquireSRWLockShared(&lock);
    const bool allowed = GameForeground() && safety.CanInject(GetTickCount64()) && polledGeneration == state.generation;
    ReleaseSRWLockShared(&lock);
    return allowed;
}

bool HasActiveInput() {
    AcquireSRWLockShared(&lock);
    const bool active = safety.CanInject(GetTickCount64()) && polledGeneration == state.generation &&
        InputIsActive(state.buttons, state.lt, state.rt, state.lx, state.ly, state.rx, state.ry);
    ReleaseSRWLockShared(&lock);
    return active;
}

bool Mouse(double dx, double dy, unsigned buttons, int mode) {
    AcquireSRWLockExclusive(&lock);
    safety.foreground = GameForeground();
    bool ok = false;
    if (safety.CanInject(GetTickCount64()) && (mode == 0 || mode == 1) &&
        std::isfinite(dx) && std::isfinite(dy)) {
        const MouseDelta movement = residual.Accumulate(dx, dy, mode);
        unsigned desired = buttons & 3u;
        if (mode == 1) desired = (desired & 1u) | ((dx != 0.0 || dy != 0.0) ? 2u : 0u);
        ok = SendButtons(desired, movement.x, movement.y);
    } else ReleaseLocked();
    ReleaseSRWLockExclusive(&lock);
    return ok;
}

bool Rumble(double left, double right) {
    AcquireSRWLockExclusive(&lock);
    safety.foreground = GameForeground();
    bool ok = false;
    if (safety.CanInject(GetTickCount64()) && setState && selection.active >= 0 && selection.active < hidSlot) {
        XINPUT_VIBRATION vibration = {};
        vibration.wLeftMotorSpeed = static_cast<WORD>(ClampUnit(left) * 65535.0);
        vibration.wRightMotorSpeed = static_cast<WORD>(ClampUnit(right) * 65535.0);
        ok = setState(selection.active, &vibration) == ERROR_SUCCESS;
        if (ok) { motorLeft = vibration.wLeftMotorSpeed; motorRight = vibration.wRightMotorSpeed; }
    } else StopMotors();
    ReleaseSRWLockExclusive(&lock);
    return ok;
}

void Release() {
    AcquireSRWLockExclusive(&lock);
    ReleaseLocked();
    safety.hasHeartbeat = false;
    ReleaseSRWLockExclusive(&lock);
}
} // namespace tc
