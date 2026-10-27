// Main-thread dispatch regression harness. It exercises the real bridge code
// with modeled client Lua APIs, without loading or modifying the game.
#include "bridge.cpp"
#include <string>
#include <vector>

namespace tc {
bool allowInput = true;
bool inputActive = false;
ControllerState sample;
bool StartRuntime() { return false; }
void SetWorldScriptReady() {}
void SetGlueOverride(bool) {}
ControllerState Poll() { return sample; }
bool CanDispatch() { return allowInput; }
bool HasActiveInput() { return inputActive; }
bool Mouse(double, double, unsigned, int) { return false; }
bool Rumble(double, double) { return false; }
void Release() {}
void Log(const char*, ...) {}
void SetModule(HMODULE) {}
}

namespace {
int failures = 0, calls = 0, rejectedCallback = 0, movementCalls = 0;
std::uint32_t committedMovementFlags = 0;
std::uintptr_t origin = 42, observedOrigin = 0;
bool worldReady = true, throwLuaError = false, nestedRelease = false;
std::uint32_t lastInput = 123;
std::uint64_t clockTicks = 0x100000456ull;
std::uint32_t movementStamp = 0;
bool movementExtraValid = false, acceptMovement = true, allowAutorun = true;
struct FakeInputController { std::uint32_t unused, flags; };
std::uint64_t __cdecl FakeGameTime() { return clockTicks; }
struct Value { int type; std::string text; int boolean = 0; double number = 0; };
struct FakeLua { std::vector<Value> stack; };
void Check(bool pass, const char* name) {
    if (!pass) { ++failures; std::fprintf(stderr, "FAIL: %s\n", name); }
}
int __fastcall FakeMovementInput(void* raw, void*, std::uint32_t mask, std::uint32_t down,
                                 std::uint32_t stamp, std::uint32_t extra) {
    auto* flags = &static_cast<FakeInputController*>(raw)->flags;
    movementStamp = stamp;
    movementExtraValid = extra == 0;
    ++movementCalls;
    if (!acceptMovement) return 0;
    *flags = down ? (*flags | mask) : (*flags & ~mask);
    // The stock movement commit clears autorun when player state blocks
    // movement. A processed input does not guarantee the requested flag stays.
    if (!allowAutorun) *flags &= ~0x1000u;
    committedMovementFlags = *flags & 0x10F0;
    return 1;
}
int __fastcall FakeGetTop(void* raw) { return static_cast<int>(static_cast<FakeLua*>(raw)->stack.size()); }
void __fastcall FakeSetTop(void* raw, int top) { static_cast<FakeLua*>(raw)->stack.resize(top); }
void __fastcall FakePushString(void* raw, const char* text) { static_cast<FakeLua*>(raw)->stack.push_back({4, text}); }
void __fastcall FakePushBoolean(void* raw, int boolean) { static_cast<FakeLua*>(raw)->stack.push_back({1, "", boolean}); }
void __fastcall FakePushNumber(void* raw, double number) { static_cast<FakeLua*>(raw)->stack.push_back({3, "", 0, number}); }
void __fastcall FakeRawGet(void* raw, int index) {
    Check(index == -10001, "only global table looked up");
    auto& value = static_cast<FakeLua*>(raw)->stack.back();
    Check(value.text == "WindrunnerController_DispatchFrame" || value.text == "WindrunnerController_DispatchRelease",
          "fixed handler names only");
    value.type = 6;
}
int __fastcall FakeType(void* raw, int index) {
    Check(index == -1, "type checks top"); return static_cast<FakeLua*>(raw)->stack.back().type;
}
const char* __fastcall FakeToString(void* raw, int) { return static_cast<FakeLua*>(raw)->stack.back().text.c_str(); }
int __fastcall FakeActionGuard(int) { observedOrigin = origin; return origin == 0 && worldReady ? 1 : 0; }
void __fastcall FakeCallbackGuard(std::uint32_t) { ++rejectedCallback; }
int __fastcall FakePCall(void* raw, int nargs, int nresults, int errfunc) {
    auto& lua = *static_cast<FakeLua*>(raw);
    Check(nargs == 0 && nresults == 0 && errfunc == 0, "fixed handler receives no arbitrary arguments");
    const auto handler = lua.stack.back().text;
    lua.stack.pop_back(); ++calls;
    Check(origin == 42, "Lua execution retains addon origin");
    if (handler == "WindrunnerController_DispatchRelease") {
        Check(dispatchScope == DispatchScope::Release, "release scope active");
        Check(ActionGuardWithCaller(0, 0x00513E5F) == (worldReady ? 1 : 0), "release permits movement stop guard");
        Check(ActionGuardWithCaller(0, 0x0051400F) == 0 && observedOrigin == 42, "release cannot authorize movement start");
        Check(ControllerActionGuard(0) == 0, "release rejects other kind-zero callers including jump");
        Check(ControllerActionGuard(5) == 0 && observedOrigin == 42, "release cannot authorize other actions");
    } else {
        Check(dispatchScope == DispatchScope::Frame, "frame scope active");
        Check(ControllerActionGuard(0) == (worldReady ? 1 : 0), "frame movement retains readiness checks");
        Check(ControllerActionGuard(5) == (worldReady ? 1 : 0), "frame action uses client guard");
        Check(origin == 42 && observedOrigin == 0, "origin cleared only inside original action guard");
        if (nestedRelease) {
            const int results = LuaRunRelease(raw);
            Check(results == 1 && lua.stack.back().boolean == 1, "nested focus cleanup succeeds");
            lua.stack.pop_back();
            Check(dispatchScope == DispatchScope::Frame, "nested cleanup restores frame scope");
        }
    }
    Check(origin == 42, "handler preserves origin after guard");
    if (throwLuaError) { lua.stack.push_back({4, "simulated Lua failure"}); return 1; }
    return 0;
}
}

int main() {
    mainThread = GetCurrentThreadId(); scriptOrigin = &origin;
    lastHardwareInput = &lastInput; gameTime = FakeGameTime;
    previousActionGuard = FakeActionGuard; previousGuard = FakeCallbackGuard;
    getTop = FakeGetTop; setTop = FakeSetTop; pushString = FakePushString;
    pushBoolean = FakePushBoolean; rawGet = FakeRawGet; luaType = FakeType;
    pushNumber = FakePushNumber;
    protectedCall = FakePCall; toString = FakeToString;
    tc::sample.connected = true; tc::sample.buttons = 4096;
    tc::sample.lx = 0.5; tc::sample.rawLx = 0.1; tc::sample.rawLy = -0.2;
    tc::sample.rawRx = 0.3; tc::sample.rawRy = -0.4;
    FakeLua poll;
    Check(LuaPoll(&poll) == 15 && poll.stack.size() == 15 && poll.stack[0].boolean == 1 &&
          poll.stack[1].number == 4096 && poll.stack[4].number == 0.5 &&
          poll.stack[11].number == 0.1 && poll.stack[12].number == -0.2 &&
          poll.stack[13].number == 0.3 && poll.stack[14].number == -0.4,
          "poll preserves original fields and appends raw axes for calibration");
    Check(ControllerActionGuard(0) == 0 && observedOrigin == 42, "ordinary addon movement remains blocked");
    FakeInputController fakeInputController = {};
    void* fakeInputControllerPointer = &fakeInputController;
    inputControllerSlot = &fakeInputControllerPointer;
    movementInput = FakeMovementInput;
    Check(!SetMovementMask(0x10), "movement input is refused outside an authorized dispatch scope");
    tc::allowInput = true;
    dispatchScope = DispatchScope::Frame;
    Check(SetMovementMask(0x90) && fakeInputController.flags == 0x90 && movementCalls == 2 && movementExtraValid,
          "authorized movement starts enter the client's native input dispatcher");
    Check(movementStamp == lastInput, "movement dispatch uses the client's hardware activity timestamp");
    Check(SetMovementMask(0x20) && fakeInputController.flags == 0x20 && movementCalls == 5 && movementExtraValid,
          "movement changes release old directions and start new directions");
    Check(ControllerActionAllowed() && origin == 42,
          "controller actions require the authorized frame scope");
    tc::allowInput = false;
    Check(!ControllerActionAllowed(), "stale or unfocused controller frame cannot jump");
    tc::allowInput = true;
    bool autorun = false;
    const int beforeAutorun = movementCalls;
    lastInput = 1;
    Check(ToggleAutorun(&autorun) && autorun && (fakeInputController.flags & 0x1000) != 0 &&
          (committedMovementFlags & 0x1000) != 0 && movementCalls == beforeAutorun + 1,
          "autorun starts actual movement through the client dispatcher, beyond setting its flag");
    Check(movementStamp == static_cast<std::uint32_t>(clockTicks) && movementExtraValid,
          "autorun dispatch uses current hardware time and the stock input arguments");
    Check(SetMovementMask(0x20) && (committedMovementFlags & 0x1000) != 0 && movementCalls == beforeAutorun + 1,
          "unchanged stick input does not cancel dispatched autorun");
    Check(ToggleAutorun(&autorun) && !autorun && (fakeInputController.flags & 0x1000) == 0 &&
          (committedMovementFlags & 0x1000) == 0 && movementCalls == beforeAutorun + 2,
          "a second press stops autorun through the client dispatcher");
    worldReady = false;
    Check(ToggleAutorun(&autorun) && autorun && movementCalls == beforeAutorun + 3 && origin == 42,
          "native autorun uses the movement dispatcher when the Lua action guard refuses");
    Check(ToggleAutorun(&autorun) && !autorun && movementCalls == beforeAutorun + 4 && origin == 42,
          "native autorun stops without changing addon origin or the Lua action guard");
    worldReady = true;
    allowAutorun = false;
    Check(ToggleAutorun(&autorun) && !autorun && movementCalls == beforeAutorun + 5,
          "a player-state movement restriction reports actual autorun state without a dispatch failure");
    allowAutorun = true;
    tc::allowInput = false;
    Check(!ToggleAutorun(&autorun) && movementCalls == beforeAutorun + 5,
          "stale or unfocused controller input cannot toggle autorun");
    tc::allowInput = true;
    acceptMovement = false;
    Check(ToggleAutorun(&autorun) && !autorun,
          "a processed autorun press reports OFF when the client ignores movement");
    acceptMovement = true;
    dispatchScope = DispatchScope::Release;
    Check(!ControllerActionAllowed() && !ToggleAutorun(&autorun),
          "release-only scope cannot jump or toggle autorun");
    const int beforeRelease = movementCalls;
    Check(SetMovementMask(0) && fakeInputController.flags == 0 && movementCalls == beforeRelease + 1 && movementExtraValid,
          "release scope stops controller-owned movement");
    Check(!SetMovementMask(0x10), "release scope cannot start movement");
    dispatchScope = DispatchScope::None;
    inputControllerSlot = reinterpret_cast<void**>(inputControllerAddress);
    movementInput = reinterpret_cast<MovementInputFn>(movementInputAddress);
    ScopedGuard(reinterpret_cast<std::uintptr_t>(&LuaRunFrame));
    ScopedGuard(reinterpret_cast<std::uintptr_t>(&LuaRunRelease));
    ScopedGuard(reinterpret_cast<std::uintptr_t>(&LuaJump));
    ScopedGuard(reinterpret_cast<std::uintptr_t>(&LuaToggleAutorun));
    ScopedGuard(0x12345678);
    Check(rejectedCallback == 1, "callback exception remains limited to bridge callbacks");
    lastInput = 123;
    FakeLua lua;
    lua.stack.push_back({3, "caller argument"});
    Check(LuaRunFrame(&lua) == 1 && lua.stack.size() == 2 && lua.stack.back().boolean == 1,
          "frame returns true and preserves caller stack");
    Check(dispatchScope == DispatchScope::None && origin == 42, "frame restores scope and origin");
    Check(lastInput == 123, "neutral frames preserve normal idle detection");
    tc::inputActive = true; lua.stack.resize(1); LuaRunFrame(&lua);
    Check(lastInput == 0x456, "real input records low32 of calibrated client clock");
    tc::inputActive = false; ++clockTicks; lua.stack.resize(1); LuaRunFrame(&lua);
    Check(lastInput == 0x457, "transition to neutral records input release time");
    ++clockTicks; lua.stack.resize(1); LuaRunFrame(&lua);
    Check(lastInput == 0x457, "later neutral frames do not keep client active");
    controllerMovementMask = 0x10; ++clockTicks; lua.stack.resize(1); LuaRunFrame(&lua);
    Check(lastInput == 0x459, "calibrated movement below the built-in deadzone still records activity");
    controllerMovementMask = 0; ++clockTicks; lua.stack.resize(1); LuaRunFrame(&lua);
    Check(lastInput == 0x45A, "calibrated movement release records activity once");
    lua.stack.resize(1); worldReady = false;
    LuaRunFrame(&lua); worldReady = true;
    Check(dispatchScope == DispatchScope::None, "world readiness refusal restores scope");
    lua.stack.resize(1); nestedRelease = true;
    LuaRunFrame(&lua); nestedRelease = false;
    lua.stack.resize(1); throwLuaError = true;
    Check(LuaRunFrame(&lua) == 2 && lua.stack.size() == 3 && lua.stack[1].boolean == 0 &&
          lua.stack[2].text == "simulated Lua failure", "Lua error returned without stranding privileged scope");
    Check(dispatchScope == DispatchScope::None && origin == 42, "Lua error restores scope and origin");
    throwLuaError = false; lua.stack.resize(1); tc::allowInput = false;
    const int before = calls;
    Check(LuaRunFrame(&lua) == 1 && lua.stack.back().boolean == 0 && calls == before,
          "disconnected, unfocused or stale frame never invokes Lua handler");
    lua.stack.resize(1);
    Check(LuaRunRelease(&lua) == 1 && lua.stack.back().boolean == 1, "cleanup remains available without controller focus");
    Check(ControllerActionGuard(5) == 0 && observedOrigin == 42, "ordinary actions remain blocked after cleanup");
    tc::allowInput = true; lua.stack.resize(1); dispatchScope = DispatchScope::Frame;
    Check(LuaRunFrame(&lua) == 1 && lua.stack.back().boolean == 0, "recursive frame denied");
    dispatchScope = DispatchScope::None;
    if (failures) return EXIT_FAILURE;
    std::puts("PASS: native dispatch scope, protected addon refusal, readiness, nested cleanup, Lua error and stack restoration");
    return EXIT_SUCCESS;
}
