#include "input_math.h"
#include "glue.h"
#include "keyboard.h"
#include "dualsense_protocol.h"
#include <cstdio>
#include <cstdlib>
#include <limits>

namespace {
int failures = 0;
void Check(bool condition, const char* name) {
    if (!condition) { ++failures; std::fprintf(stderr, "FAIL: %s\n", name); }
}
bool Near(double x, double y) { return std::abs(x - y) < 0.00001; }
}

int main() {
    using namespace tc;
    Check(!InputIsActive(0,0,0,0,0,0,0), "neutral input does not prevent idle");
    Check(InputIsActive(4096,0,0,0,0,0,0) && InputIsActive(0,0.5,0,0,0,0,0) &&
          InputIsActive(0,0,0,0,-0.8,0,0), "buttons triggers and sticks count as activity");
    Check(Near(Axis(-32768), -1) && Near(Axis(32767), 1), "asymmetric endpoints");
    const auto center = NormalizeStick(100, -100, 0.24);
    Check(center.x == 0 && center.y == 0, "circular deadzone removes drift");
    const auto edge = NormalizeStick(32767, 0, 0.24);
    Check(Near(edge.x, 1) && Near(edge.y, 0), "deadzone rescales full axis");
    const auto diagonal = NormalizeStick(32767, 32767, 0.24);
    Check(Near(std::hypot(diagonal.x, diagonal.y), 1), "diagonal stays inside unit circle");
    const auto negative = NormalizeStick(-32768, 0, 0.24);
    Check(Near(negative.x, -1), "negative full axis");
    Check(SelectController(-1, 0) == -1, "disconnected");
    Check(SelectController(-1, 4) == 2, "hotplug finds slot");
    Check(SelectController(2, 5) == 2, "active slot stable when second pad connects");
    Check(SelectController(2, 1) == 0, "disconnect selects remaining controller");
    ControllerSelection selected;
    Check(!selected.Set(-1) && selected.generation == 0, "unchanged selection has no generation");
    Check(selected.Set(2) && selected.generation == 1, "hotplug advances generation");
    selected.Set(-1); selected.Set(0);
    Check(selected.active == 0 && selected.generation == 3, "disconnect and replacement observable even between Lua polls");
    MouseResidual cursor;
    long total = 0;
    for (int i = 0; i < 10; ++i) total += cursor.Accumulate(0.1, 0, 0).x;
    Check(total == 1, "fractional cursor motion accumulates");
    Check(cursor.Accumulate(10000, -10000, 0).x == 250, "mouse rate bound");
    cursor.Reset(); cursor.Accumulate(-0.5, 0, 0);
    Check(cursor.Accumulate(250, 0, 0).x == 250, "residual cannot exceed rate bound");
    const auto invalid = cursor.Accumulate(std::numeric_limits<double>::quiet_NaN(), 1, 0);
    Check(invalid.x == 0 && invalid.y == 0 && cursor.mode == -1, "nonfinite mouse rejected");
    cursor.Accumulate(0.4, 0, 0);
    Check(cursor.Accumulate(0.4, 0, 1).x == 0, "camera switch clears cursor residual");
    SafetyState guard;
    Check(!guard.CanInject(0), "requires heartbeat and connection");
    guard.connected = guard.foreground = true;
    guard.Beat(100);
    guard.heldButtons = 3;
    Check(guard.CanInject(349) && guard.ReleaseDue(349) == 0, "within heartbeat");
    Check(guard.ReleaseDue(350) == 3 && guard.heldButtons == 0, "heartbeat expiry releases both buttons");
    Check(guard.ReleaseDue(351) == 0, "release idempotent");
    guard.Beat(400); guard.heldButtons = 2; guard.foreground = false;
    Check(guard.ReleaseDue(400) == 2, "focus loss releases camera");
    guard.foreground = true; guard.connected = false; guard.heldButtons = 1;
    Check(guard.ReleaseDue(400) == 1, "disconnect releases cursor");
    ControllerState glueState;
    Check(!GlueActive(glueState, false, false), "glue needs controller and focus");
    glueState.connected = glueState.foreground = true;
    Check(GlueActive(glueState, false, false), "glue active on glue screens");
    Check(!GlueActive(glueState, true, false), "glue never active in world");
    Check(!GlueActive(glueState, false, true), "addon heartbeat disables glue input");
    glueState.foreground = false;
    Check(!GlueActive(glueState, false, false), "glue requires foreground");
    Check(!InWorldClient(0) && InWorldClient(0x401000),
          "world client pointer is the Glue boundary");
    ControllerState arrows = {};
    Check(GlueArrows(arrows) == 0, "no arrows at rest");
    arrows.buttons = XINPUT_GAMEPAD_DPAD_UP;
    Check(GlueArrows(arrows) == GlueArrowUp, "dpad up maps to arrow up");
    arrows.buttons = XINPUT_GAMEPAD_DPAD_LEFT | XINPUT_GAMEPAD_DPAD_RIGHT;
    Check(GlueArrows(arrows) == 0, "opposing dpad directions cancel");
    arrows = {};
    arrows.lx = 0.9; arrows.ly = -0.9;
    Check((GlueArrows(arrows) & (GlueArrowRight | GlueArrowDown)) == (GlueArrowRight | GlueArrowDown),
          "diagonal stick maps to two arrows");
    arrows = {};
    arrows.lx = 0.5; arrows.ly = 0.5;
    Check(GlueArrows(arrows) == 0, "stick below glue threshold ignored");
    GlueRepeat pulse;
    Check(pulse.Update(false, 1000) == GlueEdge::None, "repeat idle");
    Check(pulse.Update(true, 1000) == GlueEdge::Down, "repeat initial press");
    Check(pulse.Update(true, 1000 + GlueRepeat::pulseMs - 1) == GlueEdge::None, "repeat holds the pulse");
    Check(pulse.Update(true, 1000 + GlueRepeat::pulseMs) == GlueEdge::Up, "repeat releases the pulse");
    Check(pulse.Update(true, 1000 + GlueRepeat::initialDelayMs - 1) == GlueEdge::None,
          "repeat waits for the initial delay");
    Check(pulse.Update(true, 1000 + GlueRepeat::initialDelayMs) == GlueEdge::Down,
          "repeat presses after the initial delay");
    Check(pulse.Update(true, 1000 + GlueRepeat::initialDelayMs + GlueRepeat::pulseMs) == GlueEdge::Up,
          "repeat releases the repeated pulse");
    GlueRepeat cancelled;
    Check(cancelled.Update(true, 0) == GlueEdge::Down && cancelled.Update(false, 10) == GlueEdge::Up &&
          !cancelled.down && !cancelled.held, "direction release lifts a held key");
    GlueButton button;
    Check(button.Update(false) == GlueEdge::None && button.Update(true) == GlueEdge::Down &&
          button.Update(true) == GlueEdge::None && button.Update(false) == GlueEdge::Up,
          "button edge detection");
    GlueWheel wheel;
    Check(!wheel.Update(false, 0), "wheel idle");
    Check(wheel.Update(true, 1000), "wheel first notch");
    Check(!wheel.Update(true, 1000 + GlueWheel::initialDelayMs - 1), "wheel waits before repeating");
    Check(wheel.Update(true, 1000 + GlueWheel::initialDelayMs), "wheel repeats");
    Check(!wheel.Update(true, 1000 + GlueWheel::initialDelayMs + GlueWheel::repeatMs - 1),
          "wheel repeat interval");
    Check(wheel.Update(true, 1000 + GlueWheel::initialDelayMs + GlueWheel::repeatMs), "wheel repeats again");
    Check(!wheel.Update(false, 5000) && !wheel.held, "wheel cancels on release");
    Check(KeyboardRowWidth(0) == KeyboardColumns && KeyboardRowWidth(3) == KeyboardColumns &&
          KeyboardRowWidth(4) == KeyboardSpecialKeys && KeyboardRowWidth(5) == 0, "keyboard row widths");
    Check(KeyboardShifted(L'a') == L'A' && KeyboardShifted(L'1') == L'!' && KeyboardShifted(L',') == L'<' &&
          KeyboardShifted(L'@') == L'@', "keyboard shift mapping");
    Check(KeyboardDirectionFrom(0, 0, 0) == KeyboardDirection::None &&
          KeyboardDirectionFrom(0, 0, XINPUT_GAMEPAD_DPAD_LEFT) == KeyboardDirection::Left &&
          KeyboardDirectionFrom(0.9, 0.1, 0) == KeyboardDirection::Right &&
          KeyboardDirectionFrom(-0.9, 0.1, 0) == KeyboardDirection::Left &&
          KeyboardDirectionFrom(0.1, -0.9, 0) == KeyboardDirection::Down &&
          KeyboardDirectionFrom(0.1, 0.9, 0) == KeyboardDirection::Up,
          "keyboard direction selection");
    int row = 0, col = KeyboardColumns - 1;
    Check(KeyboardMove(row, col, 0, 1) && row == 0 && col == 0, "keyboard row wraps horizontally");
    Check(!KeyboardMove(row, col, -1, 0) && row == 0 && col == 0, "keyboard clamps at top row");
    row = 3; col = 6;
    Check(KeyboardMove(row, col, 1, 0) && row == 4 && col == 3, "keyboard maps into special row");
    Check(!KeyboardMove(row, col, 1, 0) && row == 4, "keyboard clamps at special row");
    row = 4; col = 3;
    Check(KeyboardMove(row, col, -1, 0) && row == 3 && col == 7, "keyboard maps out of special row");
    KeyboardNavRepeat navigation;
    Check(navigation.Update(KeyboardDirection::Right, 1000), "keyboard nav first step");
    Check(!navigation.Update(KeyboardDirection::Right, 1319), "keyboard nav waits before repeating");
    Check(navigation.Update(KeyboardDirection::Right, 1320), "keyboard nav repeats");
    Check(navigation.Update(KeyboardDirection::Down, 1400), "keyboard nav turns immediately");
    Check(!navigation.Update(KeyboardDirection::None, 1500), "keyboard nav stops");
    Check(ClampUnit(-1) == 0 && ClampUnit(2) == 1 && ClampUnit(std::numeric_limits<double>::infinity()) == 0,
          "rumble bounds");
    Check(DualSenseAxis(0) == -32768 && DualSenseAxis(128) == 0 && DualSenseAxis(255) == 32767,
          "DualSense byte axes endpoints and center");
    Check(DualSenseAxis(0, true) == 32767 && DualSenseAxis(128, true) == 0 && DualSenseAxis(255, true) == -32768,
          "DualSense Y becomes positive up");
    const unsigned hatMasks[] = {1, 9, 8, 10, 2, 6, 4, 5, 0};
    for (unsigned hat = 0; hat < 9; ++hat)
        Check(DualSenseButtons(static_cast<std::uint8_t>(hat), 0) == hatMasks[hat], "DualSense eight-way dpad");
    Check(DualSenseButtons(0x18, 0) == 0x4000 && DualSenseButtons(0x28, 0) == 0x1000 &&
          DualSenseButtons(0x48, 0) == 0x2000 && DualSenseButtons(0x88, 0) == 0x8000,
          "DualSense physical face button positions");
    Check(DualSenseButtons(8, 0x01) == 0x0100 && DualSenseButtons(8, 0x02) == 0x0200 &&
          DualSenseButtons(8, 0x10) == 0x0020 && DualSenseButtons(8, 0x20) == 0x0010 &&
          DualSenseButtons(8, 0x40) == 0x0040 && DualSenseButtons(8, 0x80) == 0x0080,
          "DualSense shoulders menu and thumb buttons");
    std::uint8_t usb[64] = {1, 128, 128, 128, 128, 0, 0, 0, 8};
    DualSenseState parsed;
    Check(ParseDualSenseReport(usb, sizeof(usb), parsed) && parsed.buttons == 0 && parsed.lx == 0 && parsed.ly == 0,
          "DualSense neutral USB report");
    usb[1] = 255; usb[2] = 0; usb[5] = 81; usb[6] = 192; usb[8] = 0xf8; usb[9] = 0xf3;
    Check(ParseDualSenseReport(usb, sizeof(usb), parsed) && parsed.lx == 32767 && parsed.ly == 32767 &&
          parsed.lt == 81 && parsed.rt == 192 && parsed.buttons == 0xf3f0,
          "DualSense USB common payload offsets");
    usb[5] = 0; usb[6] = 0; usb[9] = 0x0c;
    Check(ParseDualSenseReport(usb, sizeof(usb), parsed) && parsed.lt == 255 && parsed.rt == 255,
          "DualSense Edge digital trigger stops");
    std::uint8_t simple[10] = {1, 128, 0, 255, 128, 0x41, 0x23, 0, 7, 240};
    Check(ParseDualSenseReport(simple, sizeof(simple), parsed) && parsed.ly == 32767 && parsed.rx == 32767 &&
          parsed.lt == 7 && parsed.rt == 240 && parsed.buttons == 0x2319,
          "DualSense Bluetooth simple payload offsets");
    std::uint8_t paddedSimple[78] = {};
    for (unsigned i = 0; i < sizeof(simple); ++i) paddedSimple[i] = simple[i];
    Check(ParseDualSenseReport(paddedSimple, sizeof(paddedSimple), parsed) && parsed.buttons == 0x2319,
          "DualSense Windows-padded Bluetooth simple report");
    // Independent fixture checksum produced by Python zlib.crc32 over the
    // literal 0xA1 prefix plus these 74 bytes, not the implementation above.
    std::uint8_t bluetooth[78] = {0x31, 0x10, 255, 0, 0, 255, 17, 201, 2, 0x21, 0x31};
    bluetooth[74] = 0x65; bluetooth[75] = 0x93; bluetooth[76] = 0x1f; bluetooth[77] = 0x4b;
    Check(DualSenseInputCRC(bluetooth, 74) == 0x4b1f9365,
          "DualSense Bluetooth CRC independently computed fixture");
    Check(ParseDualSenseReport(bluetooth, sizeof(bluetooth), parsed) && parsed.lx == 32767 && parsed.ly == 32767 &&
          parsed.rx == -32768 && parsed.ry == -32768 && parsed.lt == 17 && parsed.rt == 201 && parsed.buttons == 0x1139,
          "DualSense Bluetooth extended payload offsets and CRC");
    const unsigned beforeInvalid = parsed.buttons;
    bluetooth[4] ^= 1;
    Check(!ParseDualSenseReport(bluetooth, sizeof(bluetooth), parsed) && parsed.buttons == beforeInvalid,
          "DualSense corrupted Bluetooth report rejected transactionally");
    Check(!ParseDualSenseReport(nullptr, 0, parsed) && !ParseDualSenseReport(usb, 63, parsed) &&
          !ParseDualSenseReport(bluetooth, 77, parsed), "DualSense truncated reports rejected");
    usb[0] = 2;
    Check(!ParseDualSenseReport(usb, sizeof(usb), parsed), "DualSense unknown report ID rejected");
    DualSenseConnection hid;
    hid.Accept(parsed, 100);
    Check(hid.connected && hid.generation == 1 && !hid.Expired(599) && hid.Expired(600), "DualSense input freshness watchdog");
    hid.Disconnect();
    Check(!hid.connected && hid.generation == 2 && hid.state.buttons == 0 && hid.state.lx == 0 && hid.state.lt == 0,
          "DualSense disconnect clears held state");
    hid.Disconnect(); hid.Accept(parsed, 700);
    Check(hid.connected && hid.generation == 3, "DualSense hotplug advances generation only on transitions");
    if (failures) return EXIT_FAILURE;
    std::puts("PASS: native input/safety, glue and login-keyboard timing, and DualSense USB, Bluetooth, CRC, mappings, and hotplug");
    return EXIT_SUCCESS;
}
