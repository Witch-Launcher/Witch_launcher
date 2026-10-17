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

function resolveMirrorPair(brkResponse, rxGuess, rwGuess) {
    const inBand = (v) => v !== null && v !== undefined && v >= 0x100000000n && v < 0x10000000000n;
    const fmt = (v) => (v === null || v === undefined ? "?" : "0x" + v.toString(16));
    let x8v = null, x20v = null;
    try { x8v = parseRegNum(brkResponse, 0x08); } catch (e) { x8v = null; }
    try { x20v = parseRegNum(brkResponse, 0x14); } catch (e) { x20v = null; }
    log(`Mirror brk 0x6a regs: x1=${fmt(rwGuess)} x2=${fmt(rxGuess)} x8=${fmt(x8v)} x20=${fmt(x20v)}`);
    if (inBand(x20v) && inBand(x8v)) {
        log(`Mirror pair from x20/x8 (live regs): RX=0x${x20v.toString(16)} RW=0x${x8v.toString(16)}`);
        return { rx: x20v, rw: x8v };
    }
    if (inBand(rxGuess) && inBand(rwGuess)) {
        log(`Mirror pair from x1/x2 (legacy fallback)`);
        return { rx: rxGuess, rw: rwGuess };
    }
    return null;
}

legacyCommands[0x6a] = function(brkResponse) {
    let rwGuess = x1;
    let rxGuess = parseRegNum(brkResponse, 0x02);
    if (!rxGuess) {
        rxGuess = parseRegNum(brkResponse, 0x00);
    }
    if (!rwGuess) {
        rwGuess = parseRegNum(brkResponse, 0x01);
    }
    const pair = resolveMirrorPair(brkResponse, rxGuess, rwGuess);
    if (!pair) {
        log(`Mirror prepare brk 0x6a: no valid pair (rwGuess=${rwGuess}, rxGuess=${rxGuess}); region stays unblessed`);
        return;
    }
    const rx = pair.rx, rw = pair.rw;
    // Range-guard (band: 4 GB..1 TB — iOS 27 parks large reservations high,
    // e.g. CodeHeap RX=0x700F004000; see UniversalJIT26.js MIRROR_BAND_*).
    if (rx < 0x100000000n || rx >= 0x10000000000n || rw < 0x100000000n || rw >= 0x10000000000n) {
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
