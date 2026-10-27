#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include "dualsense.h"
#include "runtime.h"
#include <setupapi.h>
#include <hidsdi.h>
#include <hidpi.h>
#include <cstdlib>

namespace tc {
namespace {
SRWLOCK snapshotLock = SRWLOCK_INIT;
DualSenseConnection snapshot;
DualSenseDiagnostics diagnostics;
bool started = false;

void Publish(const DualSenseState& sample, std::uint64_t now) {
    AcquireSRWLockExclusive(&snapshotLock);
    const bool first = !snapshot.connected;
    snapshot.Accept(sample, now);
    ReleaseSRWLockExclusive(&snapshotLock);
    if (first) Log("DualSense HID input ready");
}

void PublishDisconnect() {
    AcquireSRWLockExclusive(&snapshotLock);
    const bool wasConnected = snapshot.connected;
    snapshot.Disconnect();
    ReleaseSRWLockExclusive(&snapshotLock);
    if (wasConnected) Log("DualSense HID disconnected; cleared input state");
}

void ConsumeReport(const std::uint8_t* report, DWORD bytes, std::uint64_t& lastValid) {
    DualSenseState parsed;
    if (!ParseDualSenseReport(report, bytes, parsed)) return;
    if (!lastValid) Log("DualSense HID report format: id=0x%02X bytes=%lu", report[0], bytes);
    lastValid = GetTickCount64();
    Publish(parsed, lastValid);
}

struct Device {
    HANDLE handle = INVALID_HANDLE_VALUE;
    DWORD reportLength = 0;
    void Close() {
        if (handle != INVALID_HANDLE_VALUE) { CloseHandle(handle); handle = INVALID_HANDLE_VALUE; }
        reportLength = 0;
    }
};

Device Discover() {
    Device found;
    DualSenseDiagnostics result;
    GUID hidGuid = {};
    HidD_GetHidGuid(&hidGuid);
    HDEVINFO devices = SetupDiGetClassDevsW(&hidGuid, nullptr, nullptr, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (devices == INVALID_HANDLE_VALUE) result.lastError = GetLastError();
    else
    for (DWORD index = 0; ; ++index) {
        SP_DEVICE_INTERFACE_DATA entry = {}; entry.cbSize = sizeof(entry);
        if (!SetupDiEnumDeviceInterfaces(devices, nullptr, &hidGuid, index, &entry)) break;
        ++result.interfaces;
        DWORD detailBytes = 0;
        SetupDiGetDeviceInterfaceDetailW(devices, &entry, nullptr, 0, &detailBytes, nullptr);
        if (detailBytes < sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W) || detailBytes > 65536) continue;
        auto detail = static_cast<SP_DEVICE_INTERFACE_DETAIL_DATA_W*>(std::malloc(detailBytes));
        if (!detail) break;
        detail->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W);
        if (!SetupDiGetDeviceInterfaceDetailW(devices, &entry, detail, detailBytes, nullptr, nullptr)) {
            ++result.detailFailures; result.lastError = GetLastError();
            std::free(detail); continue;
        }
        // Metadata-only handle checks the attributes before asking for input
        // access. Unrelated HID devices are never opened for reading.
        HANDLE metadata = CreateFileW(detail->DevicePath, 0, FILE_SHARE_READ | FILE_SHARE_WRITE,
                                      nullptr, OPEN_EXISTING, 0, nullptr);
        if (metadata == INVALID_HANDLE_VALUE) { ++result.metadataFailures; result.lastError = GetLastError(); }
        HIDD_ATTRIBUTES attributes = {}; attributes.Size = sizeof(attributes);
        const bool sony = metadata != INVALID_HANDLE_VALUE && HidD_GetAttributes(metadata, &attributes) &&
            attributes.VendorID == 0x054c && (attributes.ProductID == 0x0ce6 || attributes.ProductID == 0x0df2);
        if (metadata != INVALID_HANDLE_VALUE) { ++result.metadataAccessible; CloseHandle(metadata); }
        if (!sony) { std::free(detail); continue; }
        ++result.sonyInterfaces;
        HANDLE controller = CreateFileW(detail->DevicePath, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                                        nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, nullptr);
        const DWORD openError = controller == INVALID_HANDLE_VALUE ? GetLastError() : ERROR_SUCCESS;
        std::free(detail);
        if (controller == INVALID_HANDLE_VALUE) {
            ++result.accessFailures; result.lastError = openError;
            Log("DualSense HID input open failed: %lu (another program/HidHide may own or hide the device)", openError);
            continue;
        }
        PHIDP_PREPARSED_DATA preparsed = nullptr;
        HIDP_CAPS caps = {};
        const bool gamepad = HidD_GetPreparsedData(controller, &preparsed) &&
            HidP_GetCaps(preparsed, &caps) == HIDP_STATUS_SUCCESS && caps.UsagePage == 0x01 && caps.Usage == 0x05 &&
            (caps.InputReportByteLength == 64 || caps.InputReportByteLength == 78 || caps.InputReportByteLength == 10);
        if (preparsed) HidD_FreePreparsedData(preparsed);
        if (!gamepad) { ++result.unsupportedCollections; CloseHandle(controller); continue; }
        found.handle = controller; found.reportLength = caps.InputReportByteLength;
        Log("opened DualSense%s HID, input report length %lu", attributes.ProductID == 0x0df2 ? " Edge" : "", found.reportLength);
        break;
    }
    if (devices != INVALID_HANDLE_VALUE) SetupDiDestroyDeviceInfoList(devices);
    AcquireSRWLockExclusive(&snapshotLock);
    const bool changed = diagnostics.interfaces != result.interfaces || diagnostics.metadataAccessible != result.metadataAccessible ||
        diagnostics.sonyInterfaces != result.sonyInterfaces || diagnostics.accessFailures != result.accessFailures ||
        diagnostics.unsupportedCollections != result.unsupportedCollections || diagnostics.lastError != result.lastError ||
        diagnostics.detailFailures != result.detailFailures || diagnostics.metadataFailures != result.metadataFailures;
    diagnostics = result;
    ReleaseSRWLockExclusive(&snapshotLock);
    if (changed) Log("DualSense HID discovery: interfaces=%u metadataAccessible=%u Sony=%u detailFailures=%u metadataFailures=%u accessFailures=%u unsupported=%u error=%u",
                     result.interfaces, result.metadataAccessible, result.sonyInterfaces, result.detailFailures, result.metadataFailures,
                     result.accessFailures, result.unsupportedCollections, result.lastError);
    return found;
}

DWORD WINAPI Worker(void*) {
    const HANDLE event = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!event) { Log("ERROR: DualSense HID I/O event creation failed: %lu", GetLastError()); return 1; }
    Device device;
    OVERLAPPED pending = {}; pending.hEvent = event;
    bool reading = false;
    std::uint8_t report[78] = {};
    std::uint64_t openedAt = 0, lastValid = 0, nextDiscovery = 0;
    for (;;) {
        const auto now = GetTickCount64();
        if (device.handle == INVALID_HANDLE_VALUE) {
            if (now < nextDiscovery) { Sleep(8); continue; }
            nextDiscovery = now + 500;
            device = Discover();
            if (device.handle == INVALID_HANDLE_VALUE) continue;
            openedAt = GetTickCount64(); lastValid = 0; reading = false;
        }
        bool failed = false;
        // Drain ready reports, retaining the latest state. A bounded batch
        // prevents a busy controller from starving disconnect checks.
        for (unsigned batch = 0; batch < 32; ++batch) {
            DWORD bytes = 0;
            if (!reading) {
                pending = {}; pending.hEvent = event;
                ResetEvent(event);
                if (ReadFile(device.handle, report, device.reportLength, &bytes, &pending)) {
                    ConsumeReport(report, bytes, lastValid);
                    continue;
                }
                if (GetLastError() != ERROR_IO_PENDING) { failed = true; break; }
                reading = true;
            }
            if (WaitForSingleObject(event, 0) != WAIT_OBJECT_0) break;
            if (!GetOverlappedResult(device.handle, &pending, &bytes, FALSE)) { failed = true; break; }
            reading = false;
            ConsumeReport(report, bytes, lastValid);
        }
        const auto freshness = lastValid ? lastValid : openedAt;
        if (failed || GetTickCount64() - freshness >= 500) {
            // Publish disconnect first so native mouse/movement safety does
            // not depend on I/O cancellation completing quickly.
            PublishDisconnect();
            if (reading) {
                CancelIoEx(device.handle, &pending);
                DWORD ignored = 0;
                GetOverlappedResult(device.handle, &pending, &ignored, TRUE);
                reading = false;
            }
            device.Close();
            nextDiscovery = GetTickCount64() + 500;
            continue;
        }
        Sleep(4);
    }
}
} // namespace

bool StartDualSense() {
    if (started) return true;
    HANDLE worker = CreateThread(nullptr, 0, Worker, nullptr, 0, nullptr);
    if (!worker) { Log("ERROR: DualSense HID worker creation failed: %lu", GetLastError()); return false; }
    CloseHandle(worker);
    started = true;
    Log("DualSense direct HID backend enabled (Sony 054C:0CE6/0DF2, input only)");
    return true;
}

DualSenseConnection PollDualSense() {
    AcquireSRWLockShared(&snapshotLock);
    const DualSenseConnection result = snapshot;
    ReleaseSRWLockShared(&snapshotLock);
    return result;
}

DualSenseDiagnostics PollDualSenseDiagnostics() {
    AcquireSRWLockShared(&snapshotLock);
    const DualSenseDiagnostics result = diagnostics;
    ReleaseSRWLockShared(&snapshotLock);
    return result;
}
} // namespace tc
