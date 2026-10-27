#pragma once

#include <cmath>
#include <cstdint>

namespace tc {

struct Stick { double x, y; };

// Signed XInput axes are asymmetric: -32768 and +32767 are both full travel.
inline double Axis(std::int16_t value) {
    return value < 0 ? value / 32768.0 : value / 32767.0;
}

inline Stick NormalizeStick(std::int16_t x, std::int16_t y, double deadzone) {
    const double nx = Axis(x), ny = Axis(y);
    const double magnitude = std::sqrt(nx * nx + ny * ny);
    if (magnitude <= deadzone) return {0.0, 0.0};
    const double clipped = magnitude > 1.0 ? 1.0 : magnitude;
    const double scale = (clipped - deadzone) / ((1.0 - deadzone) * magnitude);
    return {nx * scale, ny * scale};
}

inline double ClampUnit(double value) {
    if (!std::isfinite(value) || value <= 0.0) return 0.0;
    return value >= 1.0 ? 1.0 : value;
}

inline bool InputIsActive(unsigned buttons, double lt, double rt, double lx, double ly, double rx, double ry) {
    return buttons != 0 || lt >= 0.15 || rt >= 0.15 || std::abs(lx) >= 0.10 ||
           std::abs(ly) >= 0.10 || std::abs(rx) >= 0.10 || std::abs(ry) >= 0.10;
}

// Remain on the active controller until it disconnects. A newly connected
// lower-numbered controller must not unexpectedly take control from it.
inline int SelectController(int current, unsigned connectedMask) {
    if (current >= 0 && current < 4 && (connectedMask & (1u << current))) return current;
    for (int slot = 0; slot != 4; ++slot)
        if (connectedMask & (1u << slot)) return slot;
    return -1;
}

struct ControllerSelection {
    int active = -1;
    std::uint32_t generation = 0;
    bool Set(int next) {
        if (next == active) return false;
        active = next;
        ++generation;
        return true;
    }
};

struct MouseDelta { long x, y; };

struct MouseResidual {
    double x = 0.0, y = 0.0;
    int mode = -1;
    void Reset() { x = y = 0.0; mode = -1; }
    MouseDelta Accumulate(double dx, double dy, int nextMode) {
        if (nextMode != mode) { Reset(); mode = nextMode; }
        if (!std::isfinite(dx) || !std::isfinite(dy)) { Reset(); return {0, 0}; }
        if (dx == 0.0 && dy == 0.0) { x = y = 0.0; return {0, 0}; }
        dx = dx < -250.0 ? -250.0 : dx > 250.0 ? 250.0 : dx;
        dy = dy < -250.0 ? -250.0 : dy > 250.0 ? 250.0 : dy;
        x += dx; y += dy;
        const double roundedX = std::round(x), roundedY = std::round(y);
        const auto ix = static_cast<long>(roundedX < -250.0 ? -250.0 : roundedX > 250.0 ? 250.0 : roundedX);
        const auto iy = static_cast<long>(roundedY < -250.0 ? -250.0 : roundedY > 250.0 ? 250.0 : roundedY);
        x -= ix; y -= iy;
        return {ix, iy};
    }
};

struct SafetyState {
    static constexpr std::uint64_t heartbeatMs = 250;
    bool connected = false;
    bool foreground = false;
    bool hasHeartbeat = false;
    std::uint64_t heartbeat = 0;
    unsigned heldButtons = 0;
    void Beat(std::uint64_t now) { hasHeartbeat = true; heartbeat = now; }
    bool CanInject(std::uint64_t now) const {
        return connected && foreground && hasHeartbeat && now >= heartbeat &&
               now - heartbeat < heartbeatMs;
    }
    unsigned ReleaseDue(std::uint64_t now) {
        if (CanInject(now)) return 0;
        const unsigned released = heldButtons;
        heldButtons = 0;
        return released;
    }
};

} // namespace tc
