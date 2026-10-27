#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include "runtime.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <cmath>
#include <intrin.h>

#if !defined(_M_IX86)
#error WindrunnerController targets the 32-bit WoW 1.12.1 client.
#endif

namespace {
using LuaFunction = int (__fastcall*)(void*);
using RegisterFn = void (__fastcall*)(const char*, LuaFunction);
using NumberFn = double (__fastcall*)(void*, int);
using PushNumberFn = void (__fastcall*)(void*, double);
using PushBooleanFn = void (__fastcall*)(void*, int);
using LoadScriptFn = void (__cdecl*)();
using GuardFn = void (__fastcall*)(std::uint32_t);
using ActionGuardFn = int (__fastcall*)(int);
using GetTopFn = int (__fastcall*)(void*);
using SetTopFn = void (__fastcall*)(void*, int);
using PushStringFn = void (__fastcall*)(void*, const char*);
using RawGetFn = void (__fastcall*)(void*, int);
using TypeFn = int (__fastcall*)(void*, int);
using PCallFn = int (__fastcall*)(void*, int, int, int);
using ToStringFn = const char* (__fastcall*)(void*, int);
using GameTimeFn = std::uint64_t (__cdecl*)();
// __fastcall provides an explicit unused EDX slot while preserving the
// client's thiscall layout: controller in ECX, then four callee-cleaned args.
using MovementInputFn = int (__fastcall*)(void*, void*, std::uint32_t, std::uint32_t, std::uint32_t, std::uint32_t);

constexpr std::uintptr_t imageBase = 0x00400000;
constexpr std::uintptr_t scriptAddress = 0x00490250;
constexpr std::uintptr_t guardAddress = 0x0042A320;
constexpr std::uintptr_t actionGuardAddress = 0x00494A50;
constexpr std::uintptr_t movementInputAddress = 0x00515090;
constexpr std::uintptr_t jumpBodyAddress = 0x00513BE0;
auto scriptOrigin = reinterpret_cast<std::uintptr_t*>(0x00CEEAC0);
auto lastHardwareInput = reinterpret_cast<std::uint32_t*>(0x00CF0BC8);
constexpr std::uintptr_t inputControllerAddress = 0x00BE1148;
auto movementInput = reinterpret_cast<MovementInputFn>(movementInputAddress);
auto inputControllerSlot = reinterpret_cast<void**>(inputControllerAddress);
auto gameTime = reinterpret_cast<GameTimeFn>(0x0042C010);
auto registerLua = reinterpret_cast<RegisterFn>(0x00704120);
auto toNumber = reinterpret_cast<NumberFn>(0x006F3620);
auto pushNumber = reinterpret_cast<PushNumberFn>(0x006F3810);
auto pushBoolean = reinterpret_cast<PushBooleanFn>(0x006F39F0);
auto getTop = reinterpret_cast<GetTopFn>(0x006F3070);
auto setTop = reinterpret_cast<SetTopFn>(0x006F3080);
auto pushString = reinterpret_cast<PushStringFn>(0x006F3890);
auto rawGet = reinterpret_cast<RawGetFn>(0x006F3B00);
auto luaType = reinterpret_cast<TypeFn>(0x006F3400);
auto protectedCall = reinterpret_cast<PCallFn>(0x006F41A0);
auto toString = reinterpret_cast<ToStringFn>(0x006F3690);
LoadScriptFn previousScript = nullptr;
GuardFn previousGuard = nullptr;
ActionGuardFn previousActionGuard = nullptr;
DWORD mainThread = 0;
bool loaded = false;
enum class DispatchScope { None, Frame, Release };
DispatchScope dispatchScope = DispatchScope::None;
bool lastFrameActive = false;
std::uint32_t controllerMovementMask = 0;

struct Site {
    const char* name;
    std::uintptr_t address;
    unsigned char expected[64];
    unsigned length = 16;
};
const Site sites[] = {
    {"Player_LoadScriptFunctions", scriptAddress, {0x56,0xE8,0xFA,0x60,0x27,0x00,0xE8,0x45,0x66,0x0A,0x00,0xE8,0x90,0xF0,0x05,0x00}},
    {"InvalidFunctionPtrCheck", guardAddress, {0x55,0x8B,0xEC,0x83,0xEC,0x40,0xA1,0x00,0x48,0x88,0x00,0x85,0xC0,0x56,0x8B,0xF1}},
    {"FrameScript_RegisterFunction", 0x00704120, {0x56,0x57,0x8B,0xF9,0xE8,0xA7,0xFF,0xFF,0xFF,0x8B,0xF0,0x6A,0x00,0x8B,0xCE,0xE8}},
    {"LuaToNumber", 0x006F3620, {0x55,0x8B,0xEC,0x83,0xEC,0x10,0xE8,0xE5,0xFD,0xFF,0xFF,0x85,0xC0,0x74,0x1A,0x83}},
    {"LuaPushNumber", 0x006F3810, {0x55,0x8B,0xEC,0x8B,0x41,0x08,0xC7,0x00,0x03,0x00,0x00,0x00,0x8B,0x15,0xC0,0xEA}},
    {"LuaPushBoolean", 0x006F39F0, {0x8B,0x41,0x08,0xC7,0x00,0x01,0x00,0x00,0x00,0x56,0x8B,0xF2,0x8B,0x15,0xC0,0xEA}},
    {"ControllerActionGuard", actionGuardAddress, {0xA1,0xC0,0xEA,0xCE,0x00,0x85,0xC0,0x56,0x8B,0xF1,0x0F,0x84,0xB1,0x00,0x00,0x00}},
    {"JumpActionBody", jumpBodyAddress, {0xA1,0x9C,0xDA,0xC4,0x00,0x8B,0x0D,0x98,0xDA,0xC4,0x00,0x6A,0x75,0x50,0x51,0xBA}},
    {"LuaGetTop", 0x006F3070, {0x8B,0x41,0x08,0x2B,0x41,0x0C,0xC1,0xF8,0x04,0xC3,0x90,0x90,0x90,0x90,0x90,0x90}},
    {"LuaSetTop", 0x006F3080, {0x85,0xD2,0x8B,0x41,0x08,0x7C,0x38,0x56,0x8B,0x71,0x0C,0xC1,0xE2,0x04,0x03,0xF2}},
    {"LuaPushString", 0x006F3890, {0x85,0xD2,0x56,0x8B,0xF1,0x75,0x06,0x5E,0xE9,0x53,0xFF,0xFF,0xFF,0x57,0x83,0xC9}},
    {"LuaRawGet", 0x006F3B00, {0x85,0xD2,0x56,0x57,0x8B,0xF1,0x7E,0x0C,0x8B,0x46,0x0C,0xC1,0xE2,0x04,0x8D,0x44}},
    {"LuaType", 0x006F3400, {0xE8,0x0B,0x00,0x00,0x00,0x85,0xC0,0x75,0x04,0x83,0xC8,0xFF,0xC3,0x8B,0x00,0xC3}},
    {"LuaProtectedCall", 0x006F41A0, {0x55,0x8B,0xEC,0x83,0xEC,0x08,0x8B,0x45,0x0C,0x85,0xC0,0x56,0x57,0x75,0x04,0x33}},
    {"LuaToString", 0x006F3690, {0x56,0x57,0x8B,0xF9,0xE8,0x77,0xFD,0xFF,0xFF,0x8B,0xF0,0x85,0xF6,0x75,0x03,0x5F}},
    {"ControllerActionReady", 0x00494B11, {0x85,0xF6,0x74,0x05,0x83,0xFE,0x0B,0x75,0x26,0xE8,0x11,0x99,0x2E,0x00,0x85,0xC0,0x75,0x1D,0xE8,0x68,0x4D,0x2E,0x00,0x85,0xC0,0x75,0x14,0x8B,0x15,0x90,0x12,0xB7,0x00,0x8B,0x82,0xD8,0x00,0x00,0x00,0x85,0xC0,0x75,0x04,0x33,0xC0,0x5E,0xC3,0xB8,0x01,0x00,0x00,0x00,0x5E,0xC3}, 54},
    {"ClientReadinessFlagA", 0x0077E430, {0xA1,0xC4,0x4D,0xCF,0x00,0xC3,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90}, 16},
    {"ClientReadinessFlagB", 0x00779890, {0xA1,0xA0,0x4D,0xCF,0x00,0xC3,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90}, 16},
    {"MoveForwardStop", 0x00513E50, {0x56,0xE8,0x8A,0x05,0x00,0x00,0x33,0xC9,0x8B,0xF0,0xE8,0xF1,0x0B,0xF8,0xFF,0x85}},
    {"MoveBackwardStop", 0x00513EB0, {0x56,0xE8,0x2A,0x05,0x00,0x00,0x33,0xC9,0x8B,0xF0,0xE8,0x91,0x0B,0xF8,0xFF,0x85}},
    {"StrafeLeftStop", 0x00513FD0, {0x56,0xE8,0x0A,0x04,0x00,0x00,0x33,0xC9,0x8B,0xF0,0xE8,0x71,0x0A,0xF8,0xFF,0x85}},
    {"StrafeRightStop", 0x00514030, {0x56,0xE8,0xAA,0x03,0x00,0x00,0x33,0xC9,0x8B,0xF0,0xE8,0x11,0x0A,0xF8,0xFF,0x85}},
    {"MovementInputDispatcher", movementInputAddress, {0x55,0x8B,0xEC,0x53,0x8B,0x5D,0x08,0x56,0x8B,0x75,0x0C,0x85,0xF6,0x57,0x8B,0xF9}},
    {"GameCurrentTime", 0x0042C010, {0xE9,0x7B,0xF7,0xFF,0xFF,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90}, 16},
    {"GameCalibratedTime", 0x0042B790, {0x55,0x8B,0xEC,0x83,0xEC,0x08,0xE8,0xB5,0xFF,0xFF,0xFF,0x89,0x45,0xF8,0x89,0x55,0xFC,0xDF,0x6D,0xF8,0xDC,0x0D,0xC8,0x32,0x83,0x00,0xDC,0x05,0x88,0x4C,0x88,0x00,0xE8,0xFB,0xEA,0xFD,0xFF,0x8B,0xE5,0x5D,0xC3}, 41}
};

bool Readable(const void* address, std::size_t length, bool executable = false) {
    MEMORY_BASIC_INFORMATION region = {};
    if (VirtualQuery(address, &region, sizeof(region)) != sizeof(region)) return false;
    if (region.State != MEM_COMMIT || (region.Protect & (PAGE_GUARD | PAGE_NOACCESS))) return false;
    const DWORD access = region.Protect & 0xff;
    if (access != PAGE_READONLY && access != PAGE_READWRITE && access != PAGE_WRITECOPY &&
        access != PAGE_EXECUTE_READ && access != PAGE_EXECUTE_READWRITE && access != PAGE_EXECUTE_WRITECOPY)
        return false;
    if (executable && access != PAGE_EXECUTE_READ && access != PAGE_EXECUTE_READWRITE && access != PAGE_EXECUTE_WRITECOPY)
        return false;
    const auto begin = reinterpret_cast<std::uintptr_t>(address);
    const auto end = reinterpret_cast<std::uintptr_t>(region.BaseAddress) + region.RegionSize;
    return begin <= end && length <= end - begin;
}

bool KnownModCode(std::uintptr_t address) {
    if (!Readable(reinterpret_cast<const void*>(address), 1, true)) return false;
    HMODULE owner = nullptr;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                          reinterpret_cast<LPCWSTR>(address), &owner)) return false;
    wchar_t path[MAX_PATH] = {};
    if (!GetModuleFileNameW(owner, path, MAX_PATH)) return false;
    const wchar_t* name = std::wcsrchr(path, L'\\');
    name = name ? name + 1 : path;
    return _wcsicmp(name, L"nampower.dll") == 0 || _wcsicmp(name, L"SuperWoWhook.dll") == 0 ||
           _wcsicmp(name, L"SuperWoW.dll") == 0;
}

std::uint32_t Read32(const unsigned char* at) {
    std::uint32_t value = 0;
    std::memcpy(&value, at, sizeof(value));
    return value;
}

bool KnownDetour(std::uintptr_t destination) {
    if (KnownModCode(destination)) return true;
    // The 32-bit gate preserves registers, establishes its FS context, and then
    // branches to the module's static stub. Keep the gate intact when chaining
    // existing extensions; jumping straight to the stub loses that context.
    const unsigned char gate[56] = {
        0x90,0x90,0x90,0x90,0x90,0x60,0x8B,0x4C,0x24,0x20,0xB8,0,0,0,0,
        0x51,0xFF,0xD0,0x59,0x89,0x08,0x64,0x8B,0x0D,0x14,0,0,0,0xB8,0,0,0,0,
        0x64,0xA3,0x14,0,0,0,0xB8,0,0,0,0,0x51,0xFF,0xD0,0x59,0x89,0x08,0x61,0xE9,0,0,0,0
    };
    const auto code = reinterpret_cast<const unsigned char*>(destination);
    if (!Readable(code, sizeof(gate), true)) return false;
    for (unsigned i = 0; i < sizeof(gate); ++i) {
        if ((i >= 11 && i <= 14) || (i >= 29 && i <= 32) || (i >= 40 && i <= 43) || i >= 52) continue;
        if (code[i] != gate[i]) return false;
    }
    const auto stub = destination + 56 + static_cast<std::int32_t>(Read32(code + 52));
    return KnownModCode(Read32(code + 11)) && KnownModCode(Read32(code + 40)) && KnownModCode(stub) &&
           Readable(reinterpret_cast<const void*>(Read32(code + 29)), sizeof(void*));
}

bool CheckImageFile() {
    if (reinterpret_cast<std::uintptr_t>(GetModuleHandleW(nullptr)) != imageBase) {
        tc::Log("ERROR: game loaded at unexpected image base"); return false;
    }
    wchar_t path[MAX_PATH] = {};
    if (!GetModuleFileNameW(nullptr, path, MAX_PATH)) return false;
    FILE* file = nullptr;
    if (_wfopen_s(&file, path, L"rb") != 0 || !file) return false;
    std::fseek(file, 0, SEEK_END);
    const long size = std::ftell(file);
    std::rewind(file);
    if (size < 1024 || size > 64 * 1024 * 1024) { std::fclose(file); return false; }
    auto data = static_cast<unsigned char*>(std::malloc(static_cast<std::size_t>(size)));
    if (!data) { std::fclose(file); return false; }
    const bool read = std::fread(data, 1, size, file) == static_cast<std::size_t>(size);
    std::fclose(file);
    bool ok = read;
    const auto dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(data);
    if (!read || dos->e_magic != IMAGE_DOS_SIGNATURE || dos->e_lfanew < 0 ||
        static_cast<unsigned long>(dos->e_lfanew) > static_cast<unsigned long>(size) - sizeof(IMAGE_NT_HEADERS32)) ok = false;
    const IMAGE_NT_HEADERS32* pe = nullptr;
    if (ok) {
        pe = reinterpret_cast<const IMAGE_NT_HEADERS32*>(data + dos->e_lfanew);
        ok = pe->Signature == IMAGE_NT_SIGNATURE && pe->FileHeader.Machine == IMAGE_FILE_MACHINE_I386 &&
             pe->OptionalHeader.Magic == IMAGE_NT_OPTIONAL_HDR32_MAGIC && pe->OptionalHeader.ImageBase == imageBase &&
             pe->FileHeader.TimeDateStamp == 0x4510B6DB && pe->FileHeader.NumberOfSections > 0 &&
             pe->FileHeader.NumberOfSections < 97 && pe->OptionalHeader.SizeOfImage >= 0x008F0000;
    }
    if (ok) {
        const auto section = IMAGE_FIRST_SECTION(pe);
        const auto sectionOffset = reinterpret_cast<const unsigned char*>(section) - data;
        ok = sectionOffset >= 0 && static_cast<unsigned long long>(sectionOffset) +
             pe->FileHeader.NumberOfSections * sizeof(IMAGE_SECTION_HEADER) <= static_cast<unsigned long>(size);
        for (const auto& site : sites) {
            if (!ok) break;
            const DWORD rva = static_cast<DWORD>(site.address - imageBase);
            bool found = false;
            for (unsigned i = 0; i < pe->FileHeader.NumberOfSections; ++i) {
                const auto& segment = section[i];
                if (rva < segment.VirtualAddress || rva - segment.VirtualAddress > segment.SizeOfRawData) continue;
                const DWORD relative = rva - segment.VirtualAddress;
                if (relative + site.length > segment.SizeOfRawData) continue;
                const auto offset = static_cast<unsigned long long>(segment.PointerToRawData) + relative;
                if (offset + site.length > static_cast<unsigned long>(size)) continue;
                found = std::memcmp(data + offset, site.expected, site.length) == 0;
                break;
            }
            tc::Log("file fingerprint %s @0x%08lX: %s", site.name, static_cast<unsigned long>(site.address), found ? "match" : "FAIL");
            if (!found) ok = false;
        }
    }
    std::free(data);
    if (!ok) tc::Log("ERROR: unsupported executable layout; no memory patches installed");
    return ok;
}

struct Hook {
    unsigned char* entry = nullptr;
    unsigned char saved[6] = {};
    void* previous = nullptr;
    void* trampoline = nullptr;
    bool installed = false;
    unsigned length = 6;
};
Hook scriptHook, guardHook, actionGuardHook;

bool PrepareHook(Hook& hook, const Site& site, bool relocateCall, bool allowChain = true) {
    hook.entry = reinterpret_cast<unsigned char*>(site.address);
    if (!Readable(hook.entry, site.length, true)) return false;
    std::memcpy(hook.saved, hook.entry, hook.length);
    if (allowChain && hook.entry[0] == 0xE9) {
        const auto target = site.address + 5 + static_cast<std::int32_t>(Read32(hook.entry + 1));
        if (!KnownDetour(target)) {
            tc::Log("ERROR: unrecognized existing %s detour -> 0x%08lX", site.name, static_cast<unsigned long>(target));
            return false;
        }
        hook.previous = reinterpret_cast<void*>(target);
        tc::Log("cooperating with existing %s detour -> 0x%08lX", site.name, static_cast<unsigned long>(target));
        return true;
    }
    if (std::memcmp(hook.entry, site.expected, site.length) != 0) {
        tc::Log("ERROR: runtime %s fingerprint differs", site.name); return false;
    }
    const unsigned codeLength = hook.length + 5;
    auto code = static_cast<unsigned char*>(VirtualAlloc(nullptr, codeLength, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE));
    if (!code) return false;
    std::memcpy(code, hook.saved, hook.length);
    if (relocateCall) {
        const auto callee = site.address + 6 + static_cast<std::int32_t>(Read32(hook.saved + 2));
        const std::int32_t displacement = static_cast<std::int32_t>(callee - reinterpret_cast<std::uintptr_t>(code + 6));
        std::memcpy(code + 2, &displacement, 4);
    }
    code[hook.length] = 0xE9;
    const std::int32_t resume = static_cast<std::int32_t>(site.address + hook.length - reinterpret_cast<std::uintptr_t>(code + codeLength));
    std::memcpy(code + hook.length + 1, &resume, 4);
    DWORD oldProtect = 0;
    if (!VirtualProtect(code, codeLength, PAGE_EXECUTE_READ, &oldProtect)) { VirtualFree(code, 0, MEM_RELEASE); return false; }
    FlushInstructionCache(GetCurrentProcess(), code, codeLength);
    hook.previous = hook.trampoline = code;
    tc::Log("runtime %s fingerprint match; prepared %u-byte trampoline", site.name, hook.length);
    return true;
}

bool WriteCode(void* destination, const void* bytes, std::size_t length) {
    DWORD oldProtect = 0;
    if (!VirtualProtect(destination, length, PAGE_EXECUTE_READWRITE, &oldProtect)) return false;
    std::memcpy(destination, bytes, length);
    FlushInstructionCache(GetCurrentProcess(), destination, length);
    DWORD ignored = 0;
    const bool restored = VirtualProtect(destination, length, oldProtect, &ignored) != FALSE;
    if (!restored) tc::Log("ERROR: restoring code page protection failed: %lu", GetLastError());
    // The bytes are committed even if protection restoration failed. Callers
    // must retain their trampolines and know this hook is active.
    return true;
}

bool InstallHook(Hook& hook, void* replacement) {
    unsigned char jump[6] = {0xE9, 0, 0, 0, 0, 0x90};
    const auto displacement = static_cast<std::int32_t>(reinterpret_cast<std::uintptr_t>(replacement) -
                                                       reinterpret_cast<std::uintptr_t>(hook.entry + 5));
    std::memcpy(jump + 1, &displacement, 4);
    if (!WriteCode(hook.entry, jump, hook.length)) return false;
    hook.installed = true;
    return true;
}

int __fastcall LuaPoll(void* lua) {
    const tc::ControllerState state = tc::Poll();
    pushBoolean(lua, state.connected ? 1 : 0);
    pushNumber(lua, state.buttons);
    pushNumber(lua, state.lt); pushNumber(lua, state.rt);
    pushNumber(lua, state.lx); pushNumber(lua, state.ly);
    pushNumber(lua, state.rx); pushNumber(lua, state.ry);
    pushBoolean(lua, state.foreground ? 1 : 0);
    pushNumber(lua, state.generation);
    // Expose the game's own directional input flags for live diagnostics.
    // This reads the engine-owned controller only on its main thread and
    // checks both pointers before dereferencing; it never changes game state.
    std::uint32_t inputFlags = 0;
    if (GetCurrentThreadId() == mainThread &&
        Readable(reinterpret_cast<const void*>(inputControllerAddress), sizeof(void*))) {
        void* controller = nullptr;
        std::memcpy(&controller, reinterpret_cast<const void*>(inputControllerAddress), sizeof(controller));
        if (controller && Readable(controller, sizeof(void*) + sizeof(inputFlags)))
            std::memcpy(&inputFlags, static_cast<const unsigned char*>(controller) + sizeof(void*), sizeof(inputFlags));
    }
    pushNumber(lua, inputFlags);
    // Append raw axes; the original eleven return values remain compatible.
    pushNumber(lua, state.rawLx); pushNumber(lua, state.rawLy);
    pushNumber(lua, state.rawRx); pushNumber(lua, state.rawRy);
    return 15;
}

int __fastcall LuaMouse(void* lua) {
    const double dx = toNumber(lua, 1), dy = toNumber(lua, 2);
    const double buttonValue = toNumber(lua, 3), modeValue = toNumber(lua, 4);
    unsigned buttons = 0;
    if (std::isfinite(buttonValue) && buttonValue > 0.0) buttons = buttonValue >= 3.0 ? 3u : static_cast<unsigned>(buttonValue);
    const int mode = modeValue == 0.0 ? 0 : modeValue == 1.0 ? 1 : -1;
    pushBoolean(lua, tc::Mouse(dx, dy, buttons, mode) ? 1 : 0);
    return 1;
}

int __fastcall LuaRumble(void* lua) {
    pushBoolean(lua, tc::Rumble(toNumber(lua, 1), toNumber(lua, 2)) ? 1 : 0);
    return 1;
}

int __fastcall LuaRelease(void* lua) {
    tc::Release();
    pushBoolean(lua, 1);
    return 1;
}

int __fastcall LuaSetGlue(void* lua) {
    const double value = toNumber(lua, 1);
    if (!std::isfinite(value)) {
        pushBoolean(lua, 0);
        return 1;
    }
    tc::SetGlueOverride(value != 0.0);
    pushBoolean(lua, 1);
    return 1;
}

bool SetMovementMask(std::uint32_t desired) {
    constexpr std::uint32_t allowed = 0xF0;
    if ((desired & ~allowed) != 0 || GetCurrentThreadId() != mainThread ||
        dispatchScope == DispatchScope::None ||
        (dispatchScope == DispatchScope::Release && desired != 0) ||
        (dispatchScope == DispatchScope::Frame && !tc::CanDispatch())) return false;
    const std::uint32_t changed = controllerMovementMask ^ desired;
    if (!changed) return true;
    if (!Readable(inputControllerSlot, sizeof(void*)) ||
        !Readable(lastHardwareInput, sizeof(*lastHardwareInput))) return false;
    void* controller = nullptr;
    std::memcpy(&controller, inputControllerSlot, sizeof(controller));
    if (!controller || !Readable(controller, 8)) {
        if (desired == 0) { controllerMovementMask = 0; return true; }
        return false;
    }
    // A calibrated stick may move below XInput's built-in deadzone. Actual
    // movement transitions still need the client's current input timestamp.
    if (dispatchScope == DispatchScope::Frame)
        *lastHardwareInput = static_cast<std::uint32_t>(gameTime());
    const std::uint32_t stamp = *lastHardwareInput;
    for (std::uint32_t bit = 0x10; bit <= 0x80; bit <<= 1) {
        if ((changed & bit) == 0) continue;
        movementInput(controller, nullptr, bit, (desired & bit) != 0 ? 1u : 0u, stamp, 0);
    }
    // Verify the engine accepted the requested transitions before reporting
    // success. These bits are the same state consumed by the stock world tick.
    std::uint32_t flags = 0;
    std::memcpy(&flags, static_cast<const unsigned char*>(controller) + 4, sizeof(flags));
    if ((flags & desired) != desired || (flags & (changed & ~desired)) != 0) return false;
    controllerMovementMask = desired;
    return true;
}

int __fastcall LuaSetMovement(void* lua) {
    const double value = toNumber(lua, 1);
    const bool valid = std::isfinite(value) && value >= 0.0 && value <= 240.0 &&
        std::floor(value) == value && SetMovementMask(static_cast<std::uint32_t>(value));
    pushBoolean(lua, valid ? 1 : 0);
    return 1;
}

int Dispatch(void* lua, DispatchScope requested) {
    // Only our two named handlers can be dispatched; there is no arbitrary
    // Lua function/script argument and no persistent unlock switch.
    if (GetCurrentThreadId() != mainThread ||
        (requested == DispatchScope::Frame && (dispatchScope != DispatchScope::None || !tc::CanDispatch()))) {
        if (requested == DispatchScope::Frame) lastFrameActive = false;
        pushBoolean(lua, 0);
        return 1;
    }
    const int top = getTop(lua);
    pushString(lua, requested == DispatchScope::Frame ? "WindrunnerController_DispatchFrame" : "WindrunnerController_DispatchRelease");
    // Lua 5.0 GLOBALSINDEX. Raw lookup cannot execute an addon metamethod.
    rawGet(lua, -10001);
    if (luaType(lua, -1) != 6) {
        setTop(lua, top);
        pushBoolean(lua, 0); pushString(lua, "Controller dispatch handler is missing."); return 2;
    }
    const DispatchScope previous = dispatchScope;
    if (requested == DispatchScope::Frame) {
        const bool active = tc::HasActiveInput() || controllerMovementMask != 0;
        // Use the client's calibrated clock, like real window input does.
        // Held controls and the transition back to neutral count as input;
        // an untouched controller must not suppress ordinary idle detection.
        if (active || lastFrameActive) *lastHardwareInput = static_cast<std::uint32_t>(gameTime());
        lastFrameActive = active;
    } else lastFrameActive = false;
    dispatchScope = requested;
    const int error = protectedCall(lua, 0, 0, 0);
    // pcall catches Lua's longjmp before this scope is restored. No script
    // origin is cleared while executing Lua or changing Lua values.
    dispatchScope = previous;
    char message[512] = {};
    if (error) {
        const char* reason = luaType(lua, -1) == 4 ? toString(lua, -1) : "Controller handler raised a non-string error.";
        strncpy_s(message, reason ? reason : "Controller handler failed.", _TRUNCATE);
    }
    setTop(lua, top);
    pushBoolean(lua, error ? 0 : 1);
    if (error) { pushString(lua, message); return 2; }
    return 1;
}

int __fastcall LuaRunFrame(void* lua) { return Dispatch(lua, DispatchScope::Frame); }
int __fastcall LuaRunRelease(void* lua) { return Dispatch(lua, DispatchScope::Release); }

int ActionGuardWithCaller(int kind, std::uintptr_t caller) {
    const bool movementStop = caller == 0x00513E5F || caller == 0x00513EBF ||
                              caller == 0x00513FDF || caller == 0x0051403F;
    if (GetCurrentThreadId() != mainThread || dispatchScope == DispatchScope::None ||
        (dispatchScope == DispatchScope::Release && (kind != 0 || !movementStop))) return previousActionGuard(kind);
    // The validated null-origin branch performs client/world readiness checks
    // without calling Lua or raising events. Restore the origin immediately;
    // never remove origin tracking from the Lua VM or other addon execution.
    const std::uintptr_t previous = *scriptOrigin;
    *scriptOrigin = 0;
    const int result = previousActionGuard(kind);
    *scriptOrigin = previous;
    return result;
}

int __fastcall ControllerActionGuard(int kind) {
    return ActionGuardWithCaller(kind, reinterpret_cast<std::uintptr_t>(_ReturnAddress()));
}

bool ControllerActionAllowed() {
    return GetCurrentThreadId() == mainThread && dispatchScope == DispatchScope::Frame &&
           tc::CanDispatch();
}

// Jump begins with a protected-action guard which rejects addon-origin calls.
// Reproduce the public function's saved-ESI frame, then tail-jump past that
// guard. A call here would add a return address where the game's epilogue
// expects the saved ESI value and corrupt the stack.
__declspec(naked) void __cdecl InvokeJumpBody() {
    __asm {
        push esi
        mov eax, 00513BE0h
        jmp eax
    }
}

bool ToggleAutorun(bool* enabled) {
    if (enabled) *enabled = false;
    if (!enabled || !ControllerActionAllowed() ||
        !Readable(inputControllerSlot, sizeof(void*)) ||
        !Readable(lastHardwareInput, sizeof(*lastHardwareInput))) return false;
    void* controller = nullptr;
    std::memcpy(&controller, inputControllerSlot, sizeof(controller));
    if (!controller || !Readable(controller, 8)) return false;
    auto* flags = reinterpret_cast<std::uint32_t*>(static_cast<unsigned char*>(controller) + 4);
    const bool requested = (*flags & 0x1000) == 0;
    // Stock ToggleAutoRun (0x00513DE0) dispatches this bit and then commits
    // movement through the controller. Writing flags alone skips that commit
    // and can report ON while the character remains stationary. Like stick
    // movement, this native hardware path uses the dispatcher directly; the
    // Lua protected-action gate is not a native movement readiness check.
    *lastHardwareInput = static_cast<std::uint32_t>(gameTime());
    movementInput(controller, nullptr, 0x1000, requested ? 1u : 0u, *lastHardwareInput, 0);
    *enabled = (*flags & 0x1000) != 0;
    // The stock commit can clear autorun when player state blocks movement.
    // Report the resulting state separately from whether input was dispatched.
    return true;
}

int __fastcall LuaJump(void* lua) {
    const bool allowed = ControllerActionAllowed();
    if (allowed) InvokeJumpBody();
    pushBoolean(lua, allowed ? 1 : 0);
    return 1;
}

int __fastcall LuaToggleAutorun(void* lua) {
    bool enabled = false;
    const bool ok = ToggleAutorun(&enabled);
    pushBoolean(lua, ok ? 1 : 0);
    pushBoolean(lua, enabled ? 1 : 0);
    return 2;
}

void __fastcall ScopedGuard(std::uint32_t function) {
    if (function == reinterpret_cast<std::uintptr_t>(&LuaPoll) || function == reinterpret_cast<std::uintptr_t>(&LuaMouse) ||
        function == reinterpret_cast<std::uintptr_t>(&LuaRumble) || function == reinterpret_cast<std::uintptr_t>(&LuaRelease) ||
        function == reinterpret_cast<std::uintptr_t>(&LuaSetGlue) ||
        function == reinterpret_cast<std::uintptr_t>(&LuaRunFrame) || function == reinterpret_cast<std::uintptr_t>(&LuaRunRelease) ||
        function == reinterpret_cast<std::uintptr_t>(&LuaSetMovement) || function == reinterpret_cast<std::uintptr_t>(&LuaJump) ||
        function == reinterpret_cast<std::uintptr_t>(&LuaToggleAutorun)) return;
    previousGuard(function);
}

void __cdecl RegisterBridge() {
    previousScript();
    if (GetCurrentThreadId() != mainThread) {
        tc::Log("ERROR: script registration called outside main thread; callbacks withheld"); return;
    }
    registerLua("WindrunnerController_Poll", LuaPoll);
    registerLua("WindrunnerController_Mouse", LuaMouse);
    registerLua("WindrunnerController_Rumble", LuaRumble);
    registerLua("WindrunnerController_Release", LuaRelease);
    registerLua("WindrunnerController_SetGlue", LuaSetGlue);
    registerLua("WindrunnerController_SetMovement", LuaSetMovement);
    registerLua("WindrunnerController_Jump", LuaJump);
    registerLua("WindrunnerController_ToggleAutorun", LuaToggleAutorun);
    registerLua("WindrunnerController_RunFrame", LuaRunFrame);
    registerLua("WindrunnerController_RunRelease", LuaRunRelease);
    // The client enters its world scripting phase here. This does not depend on
    // the addon being enabled and suppresses Glue input even without a heartbeat.
    tc::SetWorldScriptReady();
    tc::Log("registered ten Lua callbacks on main thread %lu", mainThread);
}
} // namespace

// VanillaFixes explicitly invokes each DLL's undecorated Load export on the
// game main thread after DLL injection and before the client starts scripting.
extern "C" DWORD __cdecl Load() {
    if (loaded) return 0;
    tc::Log("WindrunnerController 0.3.1 startup; raw stick calibration; x86 static CRT; thread %lu", GetCurrentThreadId());
    if (!CheckImageFile()) return 1;
    for (unsigned i = 2; i < sizeof(sites) / sizeof(sites[0]); ++i) {
        if (sites[i].address == actionGuardAddress) continue;
        const auto entry = reinterpret_cast<const void*>(sites[i].address);
        if (!Readable(entry, sites[i].length, true) || std::memcmp(entry, sites[i].expected, sites[i].length) != 0) {
            tc::Log("ERROR: runtime Lua API fingerprint differs: %s; no hooks installed", sites[i].name); return 1;
        }
        tc::Log("runtime Lua API fingerprint %s: match", sites[i].name);
    }
    actionGuardHook.length = 5; // complete MOV EAX,[absolute] instruction
    if (!Readable(scriptOrigin, sizeof(*scriptOrigin)) || !Readable(lastHardwareInput, sizeof(*lastHardwareInput)) ||
        !PrepareHook(scriptHook, sites[0], true) ||
        !PrepareHook(guardHook, sites[1], false) || !PrepareHook(actionGuardHook, sites[6], false, false)) return 1;
    mainThread = GetCurrentThreadId();
    previousScript = reinterpret_cast<LoadScriptFn>(scriptHook.previous);
    previousGuard = reinterpret_cast<GuardFn>(guardHook.previous);
    previousActionGuard = reinterpret_cast<ActionGuardFn>(actionGuardHook.previous);
    if (!tc::StartRuntime()) return 1;
    if (!InstallHook(guardHook, reinterpret_cast<void*>(&ScopedGuard))) return 1;
    if (!InstallHook(actionGuardHook, reinterpret_cast<void*>(&ControllerActionGuard))) {
        WriteCode(guardHook.entry, guardHook.saved, guardHook.length); return 1;
    }
    if (!InstallHook(scriptHook, reinterpret_cast<void*>(&RegisterBridge))) {
        if (WriteCode(guardHook.entry, guardHook.saved, guardHook.length)) guardHook.installed = false;
        if (WriteCode(actionGuardHook.entry, actionGuardHook.saved, actionGuardHook.length)) actionGuardHook.installed = false;
        tc::Log("ERROR: script hook failed; scoped guard restored"); return 1;
    }
    loaded = true;
    tc::Log("startup, scoped callback guard and controller action dispatch hooks installed; awaiting script initialization");
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE module, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) tc::SetModule(module);
    return TRUE;
}
