#define WIN32_LEAN_AND_MEAN
#include "dualsense.h"
#include <windows.h>
#include <cstdarg>
#include <cstdio>

namespace tc {
void Log(const char* format, ...) {
    va_list args; va_start(args, format); std::vprintf(format, args); va_end(args); std::putchar('\n');
}
}

int main() {
    if (!tc::StartDualSense()) return 1;
    bool seen = false;
    for (unsigned i = 0; i < 40; ++i) {
        Sleep(100);
        const auto state = tc::PollDualSense();
        if (state.connected && !seen) {
            std::printf("DualSense report received: generation=%u buttons=%04X axes=%d,%d,%d,%d triggers=%u,%u\n",
                        state.generation, state.state.buttons, state.state.lx, state.state.ly, state.state.rx,
                        state.state.ry, state.state.lt, state.state.rt);
            seen = true;
        }
    }
    const auto devices = tc::PollDualSenseDiagnostics();
    std::printf("DISCOVERY: interfaces=%u metadataAccessible=%u Sony=%u detailFailures=%u metadataFailures=%u accessFailures=%u unsupported=%u error=%u\n",
                devices.interfaces, devices.metadataAccessible, devices.sonyInterfaces, devices.detailFailures, devices.metadataFailures, devices.accessFailures,
                devices.unsupportedCollections, devices.lastError);
    std::puts(seen ? "HARDWARE: direct DualSense HID input observed" : "HARDWARE: no direct DualSense input observed in 4 seconds");
    return 0;
}
