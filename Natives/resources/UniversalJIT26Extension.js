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

legacyCommands[0x6a] = function(brkResponse) {
    let rw = x1;
    let rx = parseRegNum(brkResponse, 0x02);
    let size = parseRegNum(brkResponse, 0x13);
    if (!rx) {
        rx = parseRegNum(brkResponse, 0x14);
    }
    if (!rw) {
        rw = parseRegNum(brkResponse, 0x08);
    }
    if (!rx || !rw) {
        log(`Mirror prepare brk 0x6a: missing rx/rw (x1=${x1}, x2=${parseRegNum(brkResponse, 0x02)})`);
        return;
    }
    if (!size || size < 16n * 1024n * 1024n) {
        if (rw > rx) {
            size = rw - rx;
        } else {
            log(`Mirror prepare brk 0x6a: invalid mirror layout rx=${rx} rw=${rw}`);
            return;
        }
    }
    log(`Mirror prepare brk 0x6a: RX=0x${rx.toString(16)} RW=0x${rw.toString(16)} size=0x${size.toString(16)}`);
    try {
        prepare_memory_region(rx, size);
        prepare_memory_region(rw, size);
        log(`Prepared mirror pair RX=0x${rx.toString(16)} RW=0x${rw.toString(16)}`);
    } catch (e) {
        log(`ERROR: mirror prepare failed: ${e}`);
    }
};

function parseRegNum(brkResponse, regNum) {
    const hex = regNum.toString(16).padStart(2, '0');
    const match = new RegExp(`${hex}:(?<reg>[0-9a-f]{16});`).exec(brkResponse);
    return match ? littleEndianHexStringToNumber(match.groups['reg']) : null;
}

log('Amethyst UniversalJIT26 extension loaded (handlers 0x69/0x6a, detach disabled)');
