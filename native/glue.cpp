#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include "glue.h"
#include "input_math.h"
#include "keyboard.h"

namespace tc {
namespace {
constexpr double cursorSpeed = 1200.0; // pixels per second at full deflection
constexpr double triggerThreshold = 0.5;
constexpr std::uint64_t maxFrameMs = 50;

struct GlueState {
    bool active = false;
    bool overlayOpen = false;
    bool resumeNeutral = false;
    std::uint64_t lastTick = 0;
    GlueRepeat up, down, left, right;
    GlueButton leftMouse, rightMouse, enter, escape, tab, shift;
    GlueWheel wheelUp, wheelDown;
    MouseResidual cursor;
};

GlueState glue;

bool SendKey(WORD key, bool down) {
    INPUT input = {};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = key;
    input.ki.wScan = static_cast<WORD>(MapVirtualKeyW(key, MAPVK_VK_TO_VSC));
    input.ki.dwFlags = down ? 0 : KEYEVENTF_KEYUP;
    if (key == VK_UP || key == VK_DOWN || key == VK_LEFT || key == VK_RIGHT)
        input.ki.dwFlags |= KEYEVENTF_EXTENDEDKEY;
    return SendInput(1, &input, sizeof(input)) == 1;
}

bool SendMouseButton(bool left, bool down) {
    INPUT input = {};
    input.type = INPUT_MOUSE;
    input.mi.dwFlags = left ? (down ? MOUSEEVENTF_LEFTDOWN : MOUSEEVENTF_LEFTUP)
                            : (down ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_RIGHTUP);
    return SendInput(1, &input, sizeof(input)) == 1;
}

bool SendMouseMove(long dx, long dy) {
    INPUT input = {};
    input.type = INPUT_MOUSE;
    input.mi.dx = dx;
    input.mi.dy = dy;
    input.mi.dwFlags = MOUSEEVENTF_MOVE;
    return SendInput(1, &input, sizeof(input)) == 1;
}

bool SendWheel(bool up) {
    INPUT input = {};
    input.type = INPUT_MOUSE;
    input.mi.mouseData = static_cast<DWORD>(up ? WHEEL_DELTA : -WHEEL_DELTA);
    input.mi.dwFlags = MOUSEEVENTF_WHEEL;
    return SendInput(1, &input, sizeof(input)) == 1;
}

void Apply(GlueEdge edge, WORD key) {
    if (edge == GlueEdge::Down) SendKey(key, true);
    else if (edge == GlueEdge::Up) SendKey(key, false);
}

// Release only keys this module pressed. Physical keyboard state is untouched.
void ReleaseInjectedKeys() {
    if (glue.up.down) SendKey(VK_UP, false);
    if (glue.down.down) SendKey(VK_DOWN, false);
    if (glue.left.down) SendKey(VK_LEFT, false);
    if (glue.right.down) SendKey(VK_RIGHT, false);
    if (glue.enter.down) SendKey(VK_RETURN, false);
    if (glue.escape.down) SendKey(VK_ESCAPE, false);
    if (glue.tab.down) SendKey(VK_TAB, false);
    if (glue.shift.down) SendKey(VK_SHIFT, false);
    if (glue.leftMouse.down) SendMouseButton(true, false);
    if (glue.rightMouse.down) SendMouseButton(false, false);
}

void ReleaseHeld() {
    ReleaseInjectedKeys();
    glue = GlueState{};
}

// The overlay owns all controller input. Release anything the normal mapping
// was holding, but keep the mode and timing state intact.
void SuspendMappings() {
    const bool active = glue.active;
    const bool overlayOpen = glue.overlayOpen;
    const std::uint64_t lastTick = glue.lastTick;
    ReleaseInjectedKeys();
    glue = GlueState{};
    glue.active = active;
    glue.overlayOpen = overlayOpen;
    glue.lastTick = lastTick;
}
} // namespace

void GlueTick(const ControllerState& state, bool inWorld, bool freshHeartbeat, std::uint64_t now) {
    if (!GlueActive(state, inWorld, freshHeartbeat)) {
        KeyboardHide();
        if (glue.active) {
            ReleaseHeld();
            Log("glue input: off (inWorld=%d heartbeat=%d)", inWorld ? 1 : 0, freshHeartbeat ? 1 : 0);
        }
        return;
    }
    if (!glue.active) {
        glue = GlueState{};
        glue.active = true;
        glue.lastTick = now;
        Log("glue input: on (controller generation %u)", state.generation);
    }

    if (KeyboardTick(state, now)) {
        if (!glue.overlayOpen) {
            SuspendMappings();
            glue.overlayOpen = true;
        }
        return;
    }
    if (glue.overlayOpen) {
        SuspendMappings();
        glue.overlayOpen = false;
        // The button that closed the overlay may still be held and may also
        // have a normal Glue mapping (A, B, or Back). Do not let it leak into
        // the game as a mouse click or Escape.
        glue.resumeNeutral = true;
    }
    if (glue.resumeNeutral) {
        if (InputIsActive(state.buttons, state.lt, state.rt, state.lx, state.ly, state.rx, state.ry)) return;
        glue.resumeNeutral = false;
        glue.lastTick = now;
    }

    std::uint64_t elapsed = now > glue.lastTick ? now - glue.lastTick : 0;
    if (elapsed > maxFrameMs) elapsed = maxFrameMs;
    glue.lastTick = now;

    const unsigned arrows = GlueArrows(state);
    Apply(glue.up.Update((arrows & GlueArrowUp) != 0, now), VK_UP);
    Apply(glue.down.Update((arrows & GlueArrowDown) != 0, now), VK_DOWN);
    Apply(glue.left.Update((arrows & GlueArrowLeft) != 0, now), VK_LEFT);
    Apply(glue.right.Update((arrows & GlueArrowRight) != 0, now), VK_RIGHT);

    Apply(glue.enter.Update((state.buttons & (XINPUT_GAMEPAD_Y | XINPUT_GAMEPAD_START)) != 0), VK_RETURN);
    Apply(glue.escape.Update((state.buttons & XINPUT_GAMEPAD_BACK) != 0), VK_ESCAPE);
    // Order matters: pressing LB sends Shift before Tab, releasing sends the
    // modifier up before the key, matching a normal Shift+Tab chord.
    Apply(glue.shift.Update((state.buttons & XINPUT_GAMEPAD_LEFT_SHOULDER) != 0), VK_SHIFT);
    Apply(glue.tab.Update((state.buttons & (XINPUT_GAMEPAD_LEFT_SHOULDER | XINPUT_GAMEPAD_RIGHT_SHOULDER)) != 0),
          VK_TAB);

    const GlueEdge left = glue.leftMouse.Update((state.buttons & XINPUT_GAMEPAD_A) != 0);
    if (left != GlueEdge::None) SendMouseButton(true, left == GlueEdge::Down);
    const GlueEdge right = glue.rightMouse.Update((state.buttons & XINPUT_GAMEPAD_B) != 0);
    if (right != GlueEdge::None) SendMouseButton(false, right == GlueEdge::Down);

    if (glue.wheelUp.Update(state.lt >= triggerThreshold, now)) SendWheel(true);
    if (glue.wheelDown.Update(state.rt >= triggerThreshold, now)) SendWheel(false);

    const double scale = static_cast<double>(elapsed) / 1000.0;
    if (state.rx != 0.0 || state.ry != 0.0) {
        const MouseDelta delta = glue.cursor.Accumulate(state.rx * cursorSpeed * scale,
                                                        -state.ry * cursorSpeed * scale, 0);
        if (delta.x || delta.y) SendMouseMove(delta.x, delta.y);
    } else glue.cursor.Reset();
}
} // namespace tc
