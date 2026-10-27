#pragma once

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include "runtime.h"

#include <Xinput.h>
#include <cstdint>

namespace tc {

enum class GlueEdge { None, Down, Up };

// Discrete key pulse: one press, then repeated presses while the direction is
// held. A real held key would repeat at the OS rate, which feels uneven at the
// login screen and cannot be unit tested.
struct GlueRepeat {
    static constexpr std::uint64_t initialDelayMs = 320;
    static constexpr std::uint64_t repeatMs = 90;
    static constexpr std::uint64_t pulseMs = 35;
    bool held = false;
    bool down = false;
    std::uint64_t nextPress = 0;
    std::uint64_t releaseAt = 0;

    GlueEdge Update(bool isHeld, std::uint64_t now) {
        if (!isHeld) {
            held = false;
            if (down) {
                down = false;
                return GlueEdge::Up;
            }
            return GlueEdge::None;
        }
        if (!held) {
            held = true;
            down = true;
            nextPress = now + initialDelayMs;
            releaseAt = now + pulseMs;
            return GlueEdge::Down;
        }
        if (down && now >= releaseAt) {
            down = false;
            return GlueEdge::Up;
        }
        if (!down && now >= nextPress) {
            down = true;
            releaseAt = now + pulseMs;
            nextPress = now + repeatMs;
            return GlueEdge::Down;
        }
        return GlueEdge::None;
    }
};

struct GlueButton {
    bool down = false;
    GlueEdge Update(bool pressed) {
        if (pressed == down) return GlueEdge::None;
        down = pressed;
        return pressed ? GlueEdge::Down : GlueEdge::Up;
    }
};

// Mouse wheel notches have no up event. Emit on press, then repeat while held.
struct GlueWheel {
    static constexpr std::uint64_t initialDelayMs = 300;
    static constexpr std::uint64_t repeatMs = 120;
    bool held = false;
    std::uint64_t next = 0;
    bool Update(bool pressed, std::uint64_t now) {
        if (!pressed) {
            held = false;
            return false;
        }
        if (!held) {
            held = true;
            next = now + initialDelayMs;
            return true;
        }
        if (now < next) return false;
        next = now + repeatMs;
        return true;
    }
};

enum GlueArrow : unsigned {
    GlueArrowUp = 1u << 0,
    GlueArrowDown = 1u << 1,
    GlueArrowLeft = 1u << 2,
    GlueArrowRight = 1u << 3
};

inline unsigned GlueArrows(const ControllerState& state, double threshold = 0.55) {
    unsigned arrows = 0;
    if (state.buttons & XINPUT_GAMEPAD_DPAD_UP) arrows |= GlueArrowUp;
    if (state.buttons & XINPUT_GAMEPAD_DPAD_DOWN) arrows |= GlueArrowDown;
    if (state.buttons & XINPUT_GAMEPAD_DPAD_LEFT) arrows |= GlueArrowLeft;
    if (state.buttons & XINPUT_GAMEPAD_DPAD_RIGHT) arrows |= GlueArrowRight;
    if (state.ly >= threshold) arrows |= GlueArrowUp;
    if (state.ly <= -threshold) arrows |= GlueArrowDown;
    if (state.lx <= -threshold) arrows |= GlueArrowLeft;
    if (state.lx >= threshold) arrows |= GlueArrowRight;
    // Opposing directions from the D-pad and stick cancel instead of producing
    // a stuck key.
    if ((arrows & (GlueArrowUp | GlueArrowDown)) == (GlueArrowUp | GlueArrowDown))
        arrows &= ~(GlueArrowUp | GlueArrowDown);
    if ((arrows & (GlueArrowLeft | GlueArrowRight)) == (GlueArrowLeft | GlueArrowRight))
        arrows &= ~(GlueArrowLeft | GlueArrowRight);
    return arrows;
}

// Glue input is a fallback for the DLL-owned screens only. It must never run in
// the world, and a fresh addon heartbeat means the Lua bridge owns input.
inline bool GlueActive(const ControllerState& state, bool inWorld, bool freshHeartbeat) {
    return state.connected && state.foreground && !inWorld && !freshHeartbeat;
}

// The client pointer exists only after the world client is created. The
// player pointer at client + 0xD8 is not reliable on every client build, so
// the client pointer is the Glue boundary.
inline bool InWorldClient(std::uint32_t client) {
    return client != 0;
}

void GlueTick(const ControllerState& state, bool inWorld, bool freshHeartbeat, std::uint64_t now);

} // namespace tc
