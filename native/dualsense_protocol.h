#pragma once

#include <cstddef>
#include <cstdint>

namespace tc {

// Protocol facts independently checked against SDL's PS5 HID driver and
// Linux hid-playstation. No implementation from either project is copied.
struct DualSenseState {
    unsigned buttons = 0;
    std::uint8_t lt = 0, rt = 0;
    std::int16_t lx = 0, ly = 0, rx = 0, ry = 0;
};

inline std::int16_t DualSenseAxis(std::uint8_t value, bool invert = false) {
    const int centered = static_cast<int>(value) - 128;
    if (!invert) return static_cast<std::int16_t>(centered < 0 ? centered * 256 : centered * 32767 / 127);
    return static_cast<std::int16_t>(centered > 0 ? -centered * 32768 / 127 : -centered * 32767 / 128);
}

inline unsigned DualSenseButtons(std::uint8_t faceAndHat, std::uint8_t other) {
    unsigned mapped = 0;
    // Standard XInput masks retain the addon's existing physical positions.
    if (faceAndHat & 0x10) mapped |= 0x4000; // Square -> X
    if (faceAndHat & 0x20) mapped |= 0x1000; // Cross -> A
    if (faceAndHat & 0x40) mapped |= 0x2000; // Circle -> B
    if (faceAndHat & 0x80) mapped |= 0x8000; // Triangle -> Y
    if (other & 0x01) mapped |= 0x0100; // L1
    if (other & 0x02) mapped |= 0x0200; // R1
    if (other & 0x10) mapped |= 0x0020; // Create -> Back
    if (other & 0x20) mapped |= 0x0010; // Options -> Start
    if (other & 0x40) mapped |= 0x0040; // L3
    if (other & 0x80) mapped |= 0x0080; // R3
    switch (faceAndHat & 0x0f) {
    case 0: mapped |= 0x0001; break;
    case 1: mapped |= 0x0009; break;
    case 2: mapped |= 0x0008; break;
    case 3: mapped |= 0x000a; break;
    case 4: mapped |= 0x0002; break;
    case 5: mapped |= 0x0006; break;
    case 6: mapped |= 0x0004; break;
    case 7: mapped |= 0x0005; break;
    default: break;
    }
    return mapped;
}

inline std::uint32_t DualSenseInputCRC(const std::uint8_t* bytes, std::size_t length) {
    std::uint32_t crc = 0xffffffffu;
    for (std::size_t i = 0; i <= length; ++i) {
        crc ^= i == 0 ? 0xa1u : bytes[i - 1];
        for (unsigned bit = 0; bit < 8; ++bit)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    }
    return ~crc;
}

inline bool ParseDualSenseReport(const std::uint8_t* report, std::size_t length, DualSenseState& output) {
    if (!report || !length) return false;
    std::size_t offset = 0;
    bool simple = false;
    if (report[0] == 0x01 && length == 64) offset = 1;
    else if (report[0] == 0x01 && (length == 10 || length == 78)) { offset = 1; simple = true; }
    else if (report[0] == 0x31 && length == 78) {
        const std::uint32_t received = static_cast<std::uint32_t>(report[74]) |
            (static_cast<std::uint32_t>(report[75]) << 8) | (static_cast<std::uint32_t>(report[76]) << 16) |
            (static_cast<std::uint32_t>(report[77]) << 24);
        if (DualSenseInputCRC(report, 74) != received) return false;
        offset = 2;
    } else return false;
    const auto data = report + offset;
    const auto face = data[simple ? 4 : 7], other = data[simple ? 5 : 8];
    DualSenseState parsed;
    parsed.lx = DualSenseAxis(data[0]); parsed.ly = DualSenseAxis(data[1], true);
    parsed.rx = DualSenseAxis(data[2]); parsed.ry = DualSenseAxis(data[3], true);
    parsed.lt = data[simple ? 7 : 4]; parsed.rt = data[simple ? 8 : 5];
    // DualSense Edge trigger stops can report digital presses with a zero
    // analog value. Preserve the press as full travel in that case.
    if (!parsed.lt && (other & 0x04)) parsed.lt = 255;
    if (!parsed.rt && (other & 0x08)) parsed.rt = 255;
    parsed.buttons = DualSenseButtons(face, other);
    output = parsed;
    return true;
}

struct DualSenseConnection {
    bool connected = false;
    unsigned generation = 0;
    std::uint64_t lastReport = 0;
    DualSenseState state;
    void Accept(const DualSenseState& latest, std::uint64_t now) {
        if (!connected) { connected = true; ++generation; }
        state = latest; lastReport = now;
    }
    void Disconnect() {
        if (connected) { connected = false; ++generation; }
        state = {};
    }
    bool Expired(std::uint64_t now) const { return connected && now - lastReport >= 500; }
};

} // namespace tc
