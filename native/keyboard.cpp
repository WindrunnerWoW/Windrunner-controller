#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include "keyboard.h"

namespace tc {
namespace {
constexpr int headerHeight = 28;
constexpr int padding = 14;
constexpr int gap = 4;
constexpr int maxWidth = 1000;
constexpr int minWidth = 560;
constexpr int bottomMargin = 28;

struct KeyCell {
    RECT rect = {};
    int row = 0;
    int col = 0;
    KeyboardKey kind = KeyboardKey::Character;
    wchar_t character = 0;
};

struct Layout {
    KeyCell cells[KeyboardLetterRows * KeyboardColumns + KeyboardSpecialKeys];
    int count = 0;
    RECT header = {};
};

struct Overlay {
    HWND window = nullptr;
    bool open = false;
    int row = 2;
    int col = 6;
    bool shift = false;
    int hover = -1;
    bool trackingLeave = false;
    Layout layout;
    GlueButton toggle, back, enter, tab, shiftTrigger;
    GlueRepeat confirm, erase, space;
    KeyboardNavRepeat nav;
    HFONT keyFont = nullptr;
    HFONT specialFont = nullptr;
    HFONT headerFont = nullptr;
    int fontDpi = 0;
    int fontKeyHeight = 0;
};

Overlay overlay;

struct Metrics {
    int keyWidth = 0;
    int keyHeight = 0;
    int specialWidth = 0;
    int specialHeight = 0;
    int gridTop = 0;
    int specialTop = 0;
    int height = 0;
};

Metrics ComputeMetrics(int width, int maxHeight) {
    Metrics metrics;
    metrics.keyWidth = (width - 2 * padding - (KeyboardColumns - 1) * gap) / KeyboardColumns;
    if (metrics.keyWidth < 18) metrics.keyWidth = 18;
    metrics.keyHeight = metrics.keyWidth * 3 / 4;
    if (metrics.keyHeight > 46) metrics.keyHeight = 46;
    if (metrics.keyHeight < 24) metrics.keyHeight = 24;
    metrics.specialWidth = (width - 2 * padding - (KeyboardSpecialKeys - 1) * gap) / KeyboardSpecialKeys;
    if (metrics.specialWidth < 20) metrics.specialWidth = 20;
    for (;;) {
        metrics.specialHeight = metrics.keyHeight - 4;
        if (metrics.specialHeight < 24) metrics.specialHeight = 24;
        metrics.gridTop = padding + headerHeight;
        metrics.specialTop = metrics.gridTop + KeyboardLetterRows * metrics.keyHeight +
                             (KeyboardLetterRows - 1) * gap + gap;
        metrics.height = metrics.specialTop + metrics.specialHeight + padding;
        if (maxHeight <= 0 || metrics.height <= maxHeight || metrics.keyHeight <= 24) break;
        --metrics.keyHeight;
    }
    return metrics;
}

int CellIndex(int row, int col) {
    if (row < KeyboardLetterRows) return row * KeyboardColumns + col;
    return KeyboardLetterRows * KeyboardColumns + col;
}

const KeyCell* SelectedCell() {
    const int index = CellIndex(overlay.row, overlay.col);
    if (index < 0 || index >= overlay.layout.count) return nullptr;
    return &overlay.layout.cells[index];
}

const wchar_t* SpecialLabel(KeyboardKey kind) {
    switch (kind) {
    case KeyboardKey::Shift: return L"Shift";
    case KeyboardKey::Tab: return L"Tab";
    case KeyboardKey::Space: return L"Space";
    case KeyboardKey::Backspace: return L"Bksp";
    case KeyboardKey::Enter: return L"Enter";
    case KeyboardKey::Close: return L"Close";
    default: return L"";
    }
}

void BuildLayout(int width, int height) {
    const Metrics metrics = ComputeMetrics(width, height);
    overlay.layout.count = 0;
    overlay.layout.header = {padding, padding, width - padding, padding + headerHeight};
    for (int row = 0; row < KeyboardLetterRows; ++row) {
        for (int col = 0; col < KeyboardColumns; ++col) {
            KeyCell& cell = overlay.layout.cells[overlay.layout.count++];
            const int x = padding + col * (metrics.keyWidth + gap);
            const int y = metrics.gridTop + row * (metrics.keyHeight + gap);
            cell.rect = {x, y, x + metrics.keyWidth, y + metrics.keyHeight};
            cell.row = row;
            cell.col = col;
            cell.kind = KeyboardKey::Character;
            cell.character = KeyboardLayout[row][col];
        }
    }
    static constexpr KeyboardKey specialKinds[KeyboardSpecialKeys] = {
        KeyboardKey::Shift, KeyboardKey::Tab, KeyboardKey::Space,
        KeyboardKey::Backspace, KeyboardKey::Enter, KeyboardKey::Close};
    for (int col = 0; col < KeyboardSpecialKeys; ++col) {
        KeyCell& cell = overlay.layout.cells[overlay.layout.count++];
        const int left = padding + col * (metrics.specialWidth + gap);
        const int right = col == KeyboardSpecialKeys - 1 ? width - padding : left + metrics.specialWidth;
        cell.rect = {left, metrics.specialTop, right, metrics.specialTop + metrics.specialHeight};
        cell.row = KeyboardLetterRows;
        cell.col = col;
        cell.kind = specialKinds[col];
        cell.character = 0;
    }
}

int HitTest(int x, int y) {
    for (int index = 0; index < overlay.layout.count; ++index) {
        const RECT& rect = overlay.layout.cells[index].rect;
        if (x >= rect.left && x < rect.right && y >= rect.top && y < rect.bottom) return index;
    }
    return -1;
}

void Invalidate() {
    if (overlay.window) InvalidateRect(overlay.window, nullptr, FALSE);
}

bool SendUnicode(wchar_t character) {
    INPUT input[2] = {};
    input[0].type = INPUT_KEYBOARD;
    input[0].ki.wVk = 0;
    input[0].ki.wScan = static_cast<WORD>(character);
    input[0].ki.dwFlags = KEYEVENTF_UNICODE;
    input[1] = input[0];
    input[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
    return SendInput(2, input, sizeof(INPUT)) == 2;
}

bool TapKey(WORD key) {
    INPUT input[2] = {};
    input[0].type = INPUT_KEYBOARD;
    input[0].ki.wVk = key;
    input[0].ki.wScan = static_cast<WORD>(MapVirtualKeyW(key, MAPVK_VK_TO_VSC));
    input[1] = input[0];
    input[1].ki.dwFlags = KEYEVENTF_KEYUP;
    return SendInput(2, input, sizeof(INPUT)) == 2;
}

void ResetActions() {
    overlay.back = GlueButton{};
    overlay.enter = GlueButton{};
    overlay.tab = GlueButton{};
    overlay.shiftTrigger = GlueButton{};
    overlay.confirm = GlueRepeat{};
    overlay.erase = GlueRepeat{};
    overlay.space = GlueRepeat{};
    overlay.nav = KeyboardNavRepeat{};
}

void ActivateSelected(bool repeat) {
    const KeyCell* cell = SelectedCell();
    if (!cell) return;
    switch (cell->kind) {
    case KeyboardKey::Character:
        SendUnicode(overlay.shift ? KeyboardShifted(cell->character) : cell->character);
        break;
    case KeyboardKey::Shift:
        if (!repeat) overlay.shift = !overlay.shift;
        break;
    case KeyboardKey::Tab:
        if (!repeat) TapKey(VK_TAB);
        break;
    case KeyboardKey::Space:
        SendUnicode(L' ');
        break;
    case KeyboardKey::Backspace:
        TapKey(VK_BACK);
        break;
    case KeyboardKey::Enter:
        if (!repeat) TapKey(VK_RETURN);
        break;
    case KeyboardKey::Close:
        if (!repeat) KeyboardHide();
        break;
    }
    if (overlay.open) Invalidate();
}

void EnsureFonts(HDC dc, int keyHeight) {
    const int dpi = GetDeviceCaps(dc, LOGPIXELSY);
    if (overlay.keyFont && overlay.fontDpi == dpi && overlay.fontKeyHeight == keyHeight) return;
    if (overlay.keyFont) DeleteObject(overlay.keyFont);
    if (overlay.specialFont) DeleteObject(overlay.specialFont);
    if (overlay.headerFont) DeleteObject(overlay.headerFont);
    overlay.fontDpi = dpi;
    overlay.fontKeyHeight = keyHeight;
    int keyPixels = MulDiv(18, dpi, 72);
    if (keyPixels > keyHeight * 3 / 5) keyPixels = keyHeight * 3 / 5;
    if (keyPixels < 12) keyPixels = 12;
    int specialPixels = keyPixels * 3 / 4;
    if (specialPixels < 10) specialPixels = 10;
    int headerPixels = MulDiv(11, dpi, 72);
    if (headerPixels > 16) headerPixels = 16;
    if (headerPixels < 9) headerPixels = 9;
    overlay.keyFont = CreateFontW(-keyPixels, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                                  DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
                                  CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
    overlay.specialFont = CreateFontW(-specialPixels, 0, 0, 0, FW_MEDIUM, FALSE, FALSE, FALSE,
                                      DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
                                      CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
    overlay.headerFont = CreateFontW(-headerPixels, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                                     DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
                                     CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
}

HFONT KeyFont(HFONT font) {
    return font ? font : static_cast<HFONT>(GetStockObject(DEFAULT_GUI_FONT));
}

void Paint(HDC dc, int width, int height) {
    if (overlay.layout.count <= 0) BuildLayout(width, height);
    const int keyHeight = overlay.layout.count > 0
        ? overlay.layout.cells[0].rect.bottom - overlay.layout.cells[0].rect.top
        : 32;
    EnsureFonts(dc, keyHeight);
    RECT full = {0, 0, width, height};
    HBRUSH background = CreateSolidBrush(RGB(18, 18, 22));
    FillRect(dc, &full, background);
    DeleteObject(background);
    SetBkMode(dc, TRANSPARENT);

    HGDIOBJ previousFont = SelectObject(dc, KeyFont(overlay.headerFont));
    SetTextColor(dc, RGB(170, 175, 190));
    RECT header = overlay.layout.header;
    DrawTextW(dc, L"Controller keyboard", -1, &header,
              DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
    RECT hint = overlay.layout.header;
    hint.right = width - padding;
    DrawTextW(dc, L"X close   A type   B back   LB space   RB tab   Y enter", -1, &hint,
              DT_RIGHT | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX | DT_END_ELLIPSIS);

    HPEN normalPen = CreatePen(PS_SOLID, 1, RGB(92, 95, 112));
    HPEN selectedPen = CreatePen(PS_SOLID, 3, RGB(130, 195, 255));
    HPEN shiftPen = CreatePen(PS_SOLID, 1, RGB(210, 170, 80));
    HBRUSH normalBrush = CreateSolidBrush(RGB(48, 50, 60));
    HBRUSH hoverBrush = CreateSolidBrush(RGB(62, 65, 78));
    HBRUSH selectedBrush = CreateSolidBrush(RGB(38, 82, 142));
    HBRUSH shiftBrush = CreateSolidBrush(RGB(120, 88, 28));
    HGDIOBJ previousPen = SelectObject(dc, normalPen);
    HGDIOBJ previousBrush = SelectObject(dc, GetStockObject(NULL_BRUSH));

    for (int index = 0; index < overlay.layout.count; ++index) {
        const KeyCell& cell = overlay.layout.cells[index];
        const bool selected = cell.row == overlay.row && cell.col == overlay.col;
        const bool shifted = overlay.shift && cell.kind == KeyboardKey::Shift;
        HBRUSH fill = selected ? selectedBrush : shifted ? shiftBrush : index == overlay.hover ? hoverBrush : normalBrush;
        FillRect(dc, &cell.rect, fill);
        HPEN pen = selected ? selectedPen : shifted ? shiftPen : normalPen;
        SelectObject(dc, pen);
        Rectangle(dc, cell.rect.left, cell.rect.top, cell.rect.right, cell.rect.bottom);

        SelectObject(dc, KeyFont(cell.kind == KeyboardKey::Character ? overlay.keyFont : overlay.specialFont));
        SetTextColor(dc, selected ? RGB(255, 255, 255) : RGB(228, 230, 236));
        wchar_t label[2] = {0, 0};
        const wchar_t* text = SpecialLabel(cell.kind);
        if (cell.kind == KeyboardKey::Character) {
            label[0] = overlay.shift ? KeyboardShifted(cell.character) : cell.character;
            text = label;
        }
        RECT textRect = cell.rect;
        DrawTextW(dc, text, -1, &textRect,
                  DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
    }

    SelectObject(dc, previousBrush);
    SelectObject(dc, previousPen);
    SelectObject(dc, previousFont);
    DeleteObject(normalPen);
    DeleteObject(selectedPen);
    DeleteObject(shiftPen);
    DeleteObject(normalBrush);
    DeleteObject(hoverBrush);
    DeleteObject(selectedBrush);
    DeleteObject(shiftBrush);
}

void PaintWindow(HWND window) {
    PAINTSTRUCT paint = {};
    HDC dc = BeginPaint(window, &paint);
    RECT client = {};
    GetClientRect(window, &client);
    if (client.right > 0 && client.bottom > 0) {
        HDC memory = CreateCompatibleDC(dc);
        HBITMAP bitmap = CreateCompatibleBitmap(dc, client.right, client.bottom);
        if (memory && bitmap) {
            HGDIOBJ previous = SelectObject(memory, bitmap);
            Paint(memory, client.right, client.bottom);
            BitBlt(dc, 0, 0, client.right, client.bottom, memory, 0, 0, SRCCOPY);
            SelectObject(memory, previous);
        }
        if (bitmap) DeleteObject(bitmap);
        if (memory) DeleteDC(memory);
    }
    EndPaint(window, &paint);
}

LRESULT CALLBACK OverlayProc(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_ERASEBKGND:
        return 1;
    case WM_MOUSEACTIVATE:
        return MA_NOACTIVATE;
    case WM_SIZE:
        if (overlay.window == window) {
            RECT client = {};
            GetClientRect(window, &client);
            if (client.right > 0 && client.bottom > 0) BuildLayout(client.right, client.bottom);
        }
        return 0;
    case WM_PAINT:
        PaintWindow(window);
        return 0;
    case WM_MOUSEMOVE: {
        const int x = static_cast<int>(static_cast<short>(LOWORD(lParam)));
        const int y = static_cast<int>(static_cast<short>(HIWORD(lParam)));
        const int hover = HitTest(x, y);
        if (hover != overlay.hover) {
            overlay.hover = hover;
            Invalidate();
        }
        if (!overlay.trackingLeave) {
            TRACKMOUSEEVENT track = {};
            track.cbSize = sizeof(track);
            track.dwFlags = TME_LEAVE;
            track.hwndTrack = window;
            if (TrackMouseEvent(&track)) overlay.trackingLeave = true;
        }
        return 0;
    }
    case WM_MOUSELEAVE:
        overlay.trackingLeave = false;
        if (overlay.hover != -1) {
            overlay.hover = -1;
            Invalidate();
        }
        return 0;
    case WM_SETCURSOR:
        if (LOWORD(lParam) == HTCLIENT) {
            POINT point = {};
            if (GetCursorPos(&point) && ScreenToClient(window, &point) && HitTest(point.x, point.y) >= 0) {
                SetCursor(LoadCursorA(nullptr, IDC_HAND));
                return TRUE;
            }
        }
        break;
    case WM_LBUTTONUP: {
        const int x = static_cast<int>(static_cast<short>(LOWORD(lParam)));
        const int y = static_cast<int>(static_cast<short>(HIWORD(lParam)));
        const int index = HitTest(x, y);
        if (index >= 0) {
            const KeyCell& cell = overlay.layout.cells[index];
            overlay.row = cell.row;
            overlay.col = cell.col;
            ActivateSelected(false);
        }
        return 0;
    }
    default:
        break;
    }
    return DefWindowProcW(window, message, wParam, lParam);
}

bool EnsureWindow() {
    if (overlay.window) return true;
    const HINSTANCE instance = GetModuleHandleW(nullptr);
    static const wchar_t className[] = L"WindrunnerControllerKeyboard";
    WNDCLASSEXW cls = {};
    cls.cbSize = sizeof(cls);
    cls.style = CS_HREDRAW | CS_VREDRAW;
    cls.lpfnWndProc = OverlayProc;
    cls.hInstance = instance;
    cls.hCursor = LoadCursorA(nullptr, IDC_ARROW);
    cls.lpszClassName = className;
    if (!RegisterClassExW(&cls) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return false;
    overlay.window = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_LAYERED,
        className, L"Windrunner Controller Keyboard", WS_POPUP,
        0, 0, 100, 100, nullptr, nullptr, instance, nullptr);
    if (!overlay.window) return false;
    SetLayeredWindowAttributes(overlay.window, 0, 238, LWA_ALPHA);
    return true;
}

bool PositionWindow() {
    const HWND target = GetForegroundWindow();
    if (!target) return false;
    DWORD process = 0;
    GetWindowThreadProcessId(target, &process);
    if (process != GetCurrentProcessId()) return false;
    RECT client = {};
    if (!GetClientRect(target, &client)) return false;
    POINT origin = {0, 0};
    if (!ClientToScreen(target, &origin)) return false;
    const int clientWidth = client.right - client.left;
    const int clientHeight = client.bottom - client.top;
    if (clientWidth <= 0 || clientHeight <= 0) return false;
    int width = clientWidth - 64;
    if (width > maxWidth) width = maxWidth;
    if (width < minWidth) width = clientWidth - 24;
    if (width > clientWidth - 8) width = clientWidth - 8;
    if (width < 320) return false;
    const Metrics metrics = ComputeMetrics(width, clientHeight - 16);
    const int x = origin.x + (clientWidth - width) / 2;
    int y = origin.y + clientHeight - metrics.height - bottomMargin;
    if (y < origin.y + 8) y = origin.y + 8;
    if (!SetWindowPos(overlay.window, HWND_TOPMOST, x, y, width, metrics.height,
                      SWP_NOACTIVATE | SWP_SHOWWINDOW)) return false;
    RECT windowClient = {};
    GetClientRect(overlay.window, &windowClient);
    BuildLayout(windowClient.right, windowClient.bottom);
    SetWindowRgn(overlay.window,
                 CreateRoundRectRgn(0, 0, windowClient.right + 1, windowClient.bottom + 1, 18, 18),
                 TRUE);
    return true;
}

bool OpenOverlay() {
    if (!EnsureWindow()) return false;
    overlay.open = true;
    overlay.row = 2;
    overlay.col = 6;
    overlay.shift = false;
    overlay.hover = -1;
    overlay.trackingLeave = false;
    ResetActions();
    if (!PositionWindow()) {
        overlay.open = false;
        return false;
    }
    ShowWindow(overlay.window, SW_SHOWNOACTIVATE);
    Invalidate();
    UpdateWindow(overlay.window);
    Log("glue keyboard: open");
    return true;
}
} // namespace

void KeyboardHide() {
    const bool wasOpen = overlay.open;
    overlay.open = false;
    overlay.hover = -1;
    overlay.trackingLeave = false;
    if (wasOpen && overlay.window) ShowWindow(overlay.window, SW_HIDE);
    if (wasOpen) {
        ResetActions();
        Log("glue keyboard: close");
    }
}

void KeyboardPump() {
    if (!overlay.window) return;
    MSG message = {};
    while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
}

bool KeyboardTick(const ControllerState& state, std::uint64_t now) {
    const GlueEdge toggle = overlay.toggle.Update((state.buttons & XINPUT_GAMEPAD_X) != 0);
    if (!overlay.open) {
        if (toggle == GlueEdge::Down) return OpenOverlay();
        return false;
    }
    if (toggle == GlueEdge::Down) {
        KeyboardHide();
        return true;
    }

    const KeyboardDirection direction = KeyboardDirectionFrom(state.lx, state.ly, state.buttons);
    if (overlay.nav.Update(direction, now)) {
        switch (direction) {
        case KeyboardDirection::Up: KeyboardMove(overlay.row, overlay.col, -1, 0); break;
        case KeyboardDirection::Down: KeyboardMove(overlay.row, overlay.col, 1, 0); break;
        case KeyboardDirection::Left: KeyboardMove(overlay.row, overlay.col, 0, -1); break;
        case KeyboardDirection::Right: KeyboardMove(overlay.row, overlay.col, 0, 1); break;
        default: break;
        }
        Invalidate();
    }

    if (overlay.shiftTrigger.Update(state.lt >= 0.5) == GlueEdge::Down) {
        overlay.shift = !overlay.shift;
        Invalidate();
    }

    if (overlay.erase.Update((state.buttons & XINPUT_GAMEPAD_B) != 0, now) == GlueEdge::Down)
        TapKey(VK_BACK);
    if (overlay.space.Update((state.buttons & XINPUT_GAMEPAD_LEFT_SHOULDER) != 0, now) == GlueEdge::Down)
        SendUnicode(L' ');
    if (overlay.tab.Update((state.buttons & XINPUT_GAMEPAD_RIGHT_SHOULDER) != 0) == GlueEdge::Down)
        TapKey(VK_TAB);
    if (overlay.enter.Update((state.buttons & (XINPUT_GAMEPAD_Y | XINPUT_GAMEPAD_START)) != 0) == GlueEdge::Down)
        TapKey(VK_RETURN);
    if (overlay.back.Update((state.buttons & XINPUT_GAMEPAD_BACK) != 0) == GlueEdge::Down) {
        KeyboardHide();
        return true;
    }

    const bool confirmed = (state.buttons & XINPUT_GAMEPAD_A) != 0;
    const bool repeated = overlay.confirm.held;
    if (overlay.confirm.Update(confirmed, now) == GlueEdge::Down) ActivateSelected(repeated);
    return true;
}
} // namespace tc
