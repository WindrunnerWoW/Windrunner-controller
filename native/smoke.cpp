#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdio>

int wmain(int argc, wchar_t** argv) {
    if (argc != 2) { std::fputs("Expected the built DLL path\n", stderr); return 1; }
    HMODULE dll = LoadLibraryW(argv[1]);
    if (!dll) { std::fprintf(stderr, "DLL load failed: %lu\n", GetLastError()); return 1; }
    using LoadFn = DWORD (__cdecl*)();
    const auto load = reinterpret_cast<LoadFn>(GetProcAddress(dll, "Load"));
    if (!load) { std::fputs("Undecorated Load export missing\n", stderr); FreeLibrary(dll); return 1; }
    // This test executable is deliberately unsupported. A normal DLL load
    // must do no patching, and Load must reject it before touching game sites.
    const DWORD result = load();
    FreeLibrary(dll);
    if (result == 0) { std::fputs("Unsupported executable was accepted\n", stderr); return 1; }
    std::puts("PASS: x86 DLL loads, exports Load, and rejects unsupported hosts safely");
    return 0;
}
