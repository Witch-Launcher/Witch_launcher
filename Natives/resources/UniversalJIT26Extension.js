// Amethyst overrides loaded via JIT26SendJITScript immediately after StikDebug attach.
// Re-register critical handlers so stale assigned base scripts still work on iOS 27.
logLevel = LOG_INFO;
detachAfterFirstBr = false;

legacyCommands[0x69] = function(brkResponse) {
    x1 = x0;
    x0 = 0;
    JIT26PrepareRegion(brkResponse);
    if (detachAfterFirstBr) {
        JIT26Detach();
    }
};

function readRegister(regNum) {
    const hexReg = regNum.toString(16);
    let regResponse = send_command(`p${hexReg};thread:${tid};`);
    if (!regResponse || regResponse.startsWith('E') || regResponse.length < 16) {
        regResponse = send_command(`p${hexReg}`);
    }
    if (regResponse && !regResponse.startsWith('E') && regResponse.length >= 16) {
        return littleEndianHexStringToNumber(regResponse.substr(0, 16));
    }
    return null;
}

function parseRegNum(brkResponse, regNum) {
    const hex = regNum.toString(16).padStart(2, '0');
    const match = new RegExp(`${hex}:(?<reg>[0-9a-f]{16});`).exec(brkResponse);
    if (match) {
        return littleEndianHexStringToNumber(match.groups['reg']);
    }
    return readRegister(regNum);
}

legacyCommands[0x6a] = function(brkResponse) {
    let rw = x1;
    let rx = parseRegNum(brkResponse, 0x02);
    if (!rx) {
        rx = parseRegNum(brkResponse, 0x00);
    }
    if (!rw) {
        rw = parseRegNum(brkResponse, 0x01);
    }
    if (!rx || !rw) {
        log(`Mirror prepare brk 0x6a: missing rx/rw (rw=${rw}, rx=${rx})`);
        return;
    }
    // Accept any valid 64-bit user-space address range (0x100000000-0x800000000).
    if (rx < 0x100000000n || rx >= 0x800000000n || rw < 0x100000000n || rw >= 0x800000000n) {
        log(`Mirror prepare brk 0x6a: out-of-band rx=0x${rx.toString(16)} rw=0x${rw.toString(16)}, skipping (layout drift?)`);
        return;
    }
    let size = 0xf000000n; // 240 MB default
    if (rw > rx) {
        let diff = rw - rx;
        if (diff >= 16n * 1024n * 1024n) {
            size = diff;
        }
    }
    log(`Mirror prepare brk 0x6a: RX=0x${rx.toString(16)} RW=0x${rw.toString(16)} size=0x${size.toString(16)}`);
    try {
        let r1 = prepare_memory_region(rx, size);
        let r2 = prepare_memory_region(rw, size);
        log(`Prepared mirror pair RX=0x${rx.toString(16)} (${r1}) RW=0x${rw.toString(16)} (${r2})`);
    } catch (e) {
        log(`ERROR: mirror prepare failed: ${e}`);
    }
};

log('Amethyst UniversalJIT26 extension loaded (handlers 0x69/0x6a, detach disabled)');
