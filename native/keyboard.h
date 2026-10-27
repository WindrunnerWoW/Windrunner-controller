#pragma once

#include "glue.h"

#include <cmath>
#include <cstdint>

namespace tc {

// Login and character-selection keyboard. The addon and its Lua bridge are not
// available before the world loads, so the DLL draws and drives this overlay
// itself. The layout mirrors the addon keyboard: four 12-key rows plus a
// special-key row.

inline constexpr int KeyboardColumns = 12;
inline constexpr int KeyboardLetterRows = 4;
inline constexpr int KeyboardSpecialKeys = 6;
inline constexpr int KeyboardRows = KeyboardLetterRows + 1;

inline constexpr wchar_t KeyboardLayout[KeyboardLetterRows][KeyboardColumns] = {
    {L'1', L'2', L'3', L'4', L'5', L'6', L'7', L'8', L'9', L'0', L'-', L'='},
    {L'q', L'w', L'e', L'r', L't', L'y', L'u', L'i', L'o', L'p', L'[', L']'},
    {L'a', L's', L'd', L'f', L'g', L'h', L'j', L'k', L'l', L';', L'\'', L'@'},
    {L'z', L'x', L'c', L'v', L'b', L'n', L'm', L',', L'.', L'/', L'_', L'+'},
};

enum class KeyboardKey : int { Character, Shift, Tab, Space, Backspace, Enter, Close };

inline int KeyboardRowWidth(int row) {
    if (row >= 0 && row < KeyboardLetterRows) return KeyboardColumns;
    if (row == KeyboardLetterRows) return KeyboardSpecialKeys;
    return 0;
}

inline wchar_t KeyboardShifted(wchar_t value) {
    if (value >= L'a' && value <= L'z')
        return static_cast<wchar_t>(value - L'a' + L'A');
    switch (value) {
    case L'1': return L'!'; case L'2': return L'@'; case L'3': return L'#';
    case L'4': return L'$'; case L'5': return L'%'; case L'6': return L'^';
    case L'7': return L'&'; case L'8': return L'*'; case L'9': return L'(';
    case L'0': return L')'; case L'-': return L'_'; case L'=': return L'+';
    case L'[': return L'{'; case L']': return L'}'; case L';': return L':';
    case L'\'': return L'"'; case L',': return L'<'; case L'.': return L'>';
    case L'/': return L'?';
    default: return value;
    }
}

enum class KeyboardDirection { None, Up, Down, Left, Right };

inline KeyboardDirection KeyboardDirectionFrom(double lx, double ly, unsigned buttons) {
    if (buttons & XINPUT_GAMEPAD_DPAD_UP) return KeyboardDirection::Up;
    if (buttons & XINPUT_GAMEPAD_DPAD_DOWN) return KeyboardDirection::Down;
    if (buttons & XINPUT_GAMEPAD_DPAD_LEFT) return KeyboardDirection::Left;
    if (buttons & XINPUT_GAMEPAD_DPAD_RIGHT) return KeyboardDirection::Right;
    constexpr double threshold = 0.55;
    if (std::abs(lx) < threshold && std::abs(ly) < threshold) return KeyboardDirection::None;
    if (std::abs(ly) >= std::abs(lx))
        return ly >= 0.0 ? KeyboardDirection::Up : KeyboardDirection::Down;
    return lx >= 0.0 ? KeyboardDirection::Right : KeyboardDirection::Left;
}

// Moves the selection. Horizontal movement wraps inside a row; vertical
// movement clamps at the first/last row and keeps the relative column.
inline bool KeyboardMove(int& row, int& col, int deltaRow, int deltaCol) {
    if (deltaRow != 0) {
        int nextRow = row + (deltaRow > 0 ? 1 : -1);
        if (nextRow < 0) nextRow = 0;
        if (nextRow >= KeyboardRows) nextRow = KeyboardRows - 1;
        if (nextRow == row) return false;
        const int oldWidth = KeyboardRowWidth(row);
        const int newWidth = KeyboardRowWidth(nextRow);
        int nextCol = oldWidth > 1 && newWidth > 1
            ? (col * (newWidth - 1) + (oldWidth - 1) / 2) / (oldWidth - 1)
            : 0;
        if (nextCol < 0) nextCol = 0;
        if (nextCol >= newWidth) nextCol = newWidth - 1;
        row = nextRow;
        col = nextCol;
        return true;
    }
    if (deltaCol != 0) {
        const int width = KeyboardRowWidth(row);
        if (width <= 0) return false;
        int next = (col + deltaCol) % width;
        if (next < 0) next += width;
        if (next == col) return false;
        col = next;
        return true;
    }
    return false;
}

// Direction repeat for menu navigation. A new direction moves immediately;
// holding it then repeats with the same timing as Glue mode.
struct KeyboardNavRepeat {
    KeyboardDirection direction = KeyboardDirection::None;
    GlueRepeat repeat;
    bool Update(KeyboardDirection next, std::uint64_t now) {
        if (next != direction) {
            direction = next;
            repeat = GlueRepeat{};
            if (next == KeyboardDirection::None) return false;
            return repeat.Update(true, now) == GlueEdge::Down;
        }
        if (next == KeyboardDirection::None) {
            repeat.Update(false, now);
            return false;
        }
        return repeat.Update(true, now) == GlueEdge::Down;
    }
};

// Called only while Glue mode owns input. Returns true when the overlay
// consumed this tick (open, or just opened/closed).
bool KeyboardTick(const ControllerState& state, std::uint64_t now);
void KeyboardHide();
// Pumps the overlay window's messages on the polling thread.
void KeyboardPump();

} // namespace tc
