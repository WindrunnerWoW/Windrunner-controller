#pragma once

#include "dualsense_protocol.h"

namespace tc {
// The backend has its own worker: HID discovery and overlapped I/O never
// block the main Lua thread or the runtime's focus/heartbeat watchdog.
bool StartDualSense();
DualSenseConnection PollDualSense();
struct DualSenseDiagnostics {
    unsigned interfaces = 0, metadataAccessible = 0, sonyInterfaces = 0;
    unsigned detailFailures = 0, metadataFailures = 0;
    unsigned accessFailures = 0, unsupportedCollections = 0, lastError = 0;
};
DualSenseDiagnostics PollDualSenseDiagnostics();
} // namespace tc
