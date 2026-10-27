#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdio>
#include <cwchar>
#include <string>
#include <map>

// Read-only debugger observer for VanillaFixes/WoW startup. It does not patch
// either executable, send input, suppress application exceptions, or log in.
int wmain(int argc, wchar_t** argv) {
    if (argc != 2) { std::fputs("Usage: diagnose-launch.exe CLIENT_DIRECTORY\n", stderr); return 1; }
    const std::wstring directory = argv[1];
    const std::wstring launcher = directory + L"\\VanillaFixes.exe";
    std::wstring command = L"\"" + launcher + L"\" WoW.exe";
    STARTUPINFOW startup = {}; startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESHOWWINDOW; startup.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION child = {};
    if (!CreateProcessW(launcher.c_str(), &command[0], nullptr, nullptr, FALSE, DEBUG_PROCESS,
                        nullptr, directory.c_str(), &startup, &child)) {
        std::fprintf(stderr, "CreateProcess failed: %lu\n", GetLastError()); return 1;
    }
    DebugSetProcessKillOnExit(FALSE);
    CloseHandle(child.hProcess); CloseHandle(child.hThread);
    std::map<DWORD, HANDLE> processes;
    const auto deadline = GetTickCount64() + 15000;
    while (GetTickCount64() < deadline) {
        DEBUG_EVENT event = {};
        if (!WaitForDebugEvent(&event, 100)) continue;
        DWORD disposition = DBG_CONTINUE;
        switch (event.dwDebugEventCode) {
        case CREATE_PROCESS_DEBUG_EVENT:
            processes[event.dwProcessId] = event.u.CreateProcessInfo.hProcess;
            std::printf("CREATE pid=%lu base=%p\n", event.dwProcessId, event.u.CreateProcessInfo.lpBaseOfImage);
            if (event.u.CreateProcessInfo.hFile) CloseHandle(event.u.CreateProcessInfo.hFile);
            CloseHandle(event.u.CreateProcessInfo.hThread);
            break;
        case CREATE_THREAD_DEBUG_EVENT:
            CloseHandle(event.u.CreateThread.hThread);
            break;
        case LOAD_DLL_DEBUG_EVENT: {
            wchar_t path[1024] = {};
            if (event.u.LoadDll.hFile) {
                GetFinalPathNameByHandleW(event.u.LoadDll.hFile, path, 1024, FILE_NAME_NORMALIZED);
                CloseHandle(event.u.LoadDll.hFile);
            }
            std::wprintf(L"DLL pid=%lu base=%p %ls\n", event.dwProcessId, event.u.LoadDll.lpBaseOfDll, path);
            break;
        }
        case OUTPUT_DEBUG_STRING_EVENT: {
            auto process = processes.find(event.dwProcessId);
            if (process != processes.end()) {
                const auto& info = event.u.DebugString;
                const std::size_t length = info.nDebugStringLength > 4096 ? 4096 : info.nDebugStringLength;
                if (info.fUnicode) {
                    wchar_t message[4097] = {};
                    ReadProcessMemory(process->second, info.lpDebugStringData, message, length * sizeof(wchar_t), nullptr);
                    std::wprintf(L"DEBUG pid=%lu %ls\n", event.dwProcessId, message);
                } else {
                    char message[4097] = {};
                    ReadProcessMemory(process->second, info.lpDebugStringData, message, length, nullptr);
                    std::printf("DEBUG pid=%lu %s\n", event.dwProcessId, message);
                }
            }
            break;
        }
        case EXCEPTION_DEBUG_EVENT:
            std::printf("EXCEPTION pid=%lu code=0x%08lX at=%p first=%lu\n", event.dwProcessId,
                        event.u.Exception.ExceptionRecord.ExceptionCode, event.u.Exception.ExceptionRecord.ExceptionAddress,
                        event.u.Exception.dwFirstChance);
            if (event.u.Exception.ExceptionRecord.ExceptionCode != EXCEPTION_BREAKPOINT) disposition = DBG_EXCEPTION_NOT_HANDLED;
            break;
        case EXIT_PROCESS_DEBUG_EVENT: {
            std::printf("EXIT pid=%lu code=0x%08lX\n", event.dwProcessId, event.u.ExitProcess.dwExitCode);
            auto process = processes.find(event.dwProcessId);
            if (process != processes.end()) { CloseHandle(process->second); processes.erase(process); }
            break;
        }
        default: break;
        }
        ContinueDebugEvent(event.dwProcessId, event.dwThreadId, disposition);
        if (processes.empty()) break;
    }
    for (const auto& process : processes) {
        std::printf("DETACH pid=%lu after 15-second observation\n", process.first);
        DebugActiveProcessStop(process.first);
        CloseHandle(process.second);
    }
    return 0;
}
