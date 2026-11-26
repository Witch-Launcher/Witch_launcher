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

// JIT26SetDetachAfterFirstBr(BOOL) — command 3. Re-registered here because a
// stale assigned base script (from an older launcher build) predates command 3
// and would otherwise stop dead on the launcher's detach-policy brk.
commands[3] = function(brkResponse) {
    detachAfterFirstBr = x0 != 0;
    log(`JIT26SetDetachAfterFirstBr(${detachAfterFirstBr}) called`);
};

// JIT26PrepareRegionForPatching(void *addr, size_t len) — command 4, used by
// the runtime libjvm __TEXT patch fallback (write_rx_u32).
commands[4] = function(brkResponse) {
    let x0str = x0.toString(16);
    let x1str = x1.toString(16);
    let bytes = send_command(`m${x0str},${x1str}`);
    send_command(`M${x0str},${x1str}:${bytes}`);
};

// Launcher-offered mirror region (cmd 5): the launcher reserved, blessed and
// exec-probed a full-size (240 MB) region before the JVM started; libjvm's own
// 240 MB request must be answered with THIS region, not a fresh _M mapping
// (A13/A14 TXM devices get unblessable high-band _M mappings; see
// JIT26MirrorRegionPreflight in jit_vm_remap_hook.m). Kept on globalThis so
// this file works on top of both the new base (which also has the offer logic
// and offeredRx/Size/Served globals) and stale assigned base scripts.
globalThis.amethystMirrorOffer = globalThis.amethystMirrorOffer || { rx: null, size: 0n, served: false };

// Keep the base's own cmd 5 handler: on a fresh base script it stores the
// offer in the base-scope offeredRx/offeredSize/offeredServed bindings, which
// this file cannot assign when it runs as a separate evaluated script. Chain
// to it first, then mirror the state into amethystMirrorOffer for the
// stale-base serve wrapper. globalThis guard: never chain to our own wrapper
// when the extension is re-delivered mid-session.
if (!globalThis.amethystBaseOfferHandler) {
    globalThis.amethystBaseOfferHandler = (typeof commands[5] === 'function') ? commands[5] : null;
}
commands[5] = function(brkResponse) {
    try {
        if (globalThis.amethystBaseOfferHandler) {
            globalThis.amethystBaseOfferHandler(brkResponse);
        }
    } catch (e) {
        log(`Base cmd 5 offer handler failed: ${e}`);
    }
    amethystMirrorOffer.rx = x0;
    amethystMirrorOffer.size = x1;
    amethystMirrorOffer.served = false;
    log(`Launcher-offered mirror region: addr=0x${x0.toString(16)} size=0x${x1.toString(16)} (pre-blessed + exec-probed)`);
};

// brk 0xf00d cmd 6 — JIT26VerifyMirrorOffer(): echo the offer back through x0
// so the launcher can prove the script actually received it (offer_verify=0|1
// in latestlog). Reads the base globals when present, else amethystMirrorOffer.
commands[6] = function(brkResponse) {
    let rx = 0n;
    try {
        if (typeof offeredRx !== 'undefined' && typeof offeredRx === 'bigint' && offeredRx > 0n) {
            rx = offeredRx;
        }
    } catch (e) {}
    if (rx === 0n && amethystMirrorOffer.rx !== null) {
        rx = amethystMirrorOffer.rx;
    }
    send_command(`P0=${numberToLittleEndianHexString(rx)};thread:${tid};`);
    log(`Mirror offer verify: rx=0x${rx.toString(16)}`);
};

// Serve the launcher offer for large mirror requests even when the assigned
// base script predates the offer support (stale UniversalJIT26.js). The
// wrapper only handles the exact served case (x0 == 0, request >= 16 MB,
// offer big enough) and delegates everything else to the base unchanged.
// Without this, a stale assigned base would silently fall back to _M and the
// A13/A14 crash would persist even though the launcher had a good region.
if (!globalThis.amethystBasePrepareRegion) {
    globalThis.amethystBasePrepareRegion = commands[1];
    commands[1] = function(brkResponse) {
        try {
            if (x0 == 0n && amethystMirrorOffer.rx !== null && !amethystMirrorOffer.served) {
                let allocSize = x1;
                const freshX1 = parseRegNum(brkResponse, 0x01);
                if (freshX1 != null && freshX1 > allocSize) {
                    allocSize = freshX1;
                }
                const mirrorMin = 16n * 1024n * 1024n;
                if (allocSize >= mirrorMin && amethystMirrorOffer.size >= allocSize) {
                    amethystMirrorOffer.served = true;
                    if (typeof offeredServed !== 'undefined') {
                        offeredServed = true;
                    }
                    if (typeof lastPreparedRx !== 'undefined') {
                        lastPreparedRx = amethystMirrorOffer.rx;
                        lastPreparedSize = amethystMirrorOffer.size;
                    }
                    log(`Serving launcher-prechecked mirror region for request size=0x${allocSize.toString(16)} — skipping _M allocation`);
                    log(`Allocated JIT page at address: 0x${amethystMirrorOffer.rx.toString(16)} (size=0x${amethystMirrorOffer.size.toString(16)}) [served from launcher offer]`);
                    let putX0Response = send_command(`P0=${numberToLittleEndianHexString(amethystMirrorOffer.rx)};thread:${tid};`);
                    log(`putX0Response = ${putX0Response}`);
                    return;
                }
                log(`Launcher-offer not served (wrapper): req=0x${allocSize.toString(16)} offer=0x${amethystMirrorOffer.size.toString(16)}`);
            }
        } catch (e) {
            log(`Launcher-offer serve failed (${e}); falling back to base prepare`);
        }
        return amethystBasePrepareRegion(brkResponse);
    };
}

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
    // Size: prefer the size the base script actually blessed for this RX
    // region. NEVER derive it from rw-rx: the RW alias is vm_remap'd ANYWHERE
    // (VM_FLAGS_ANYWHERE), so the difference can be gigabytes and the prepare
    // would walk off the end of the region (minutes of doomed M writes).
    let size = 0xf000000n; // 240 MB default
    if (typeof lastPreparedSize === 'bigint' && lastPreparedSize >= 0x4000n && lastPreparedSize < 0x40000000n) {
        size = lastPreparedSize;
    }
    if (typeof lastPreparedRx === 'bigint' && lastPreparedRx === rx) {
        log(`Mirror prepare brk 0x6a: RX=0x${rx.toString(16)} already blessed (size=0x${size.toString(16)}); RW alias 0x${rw.toString(16)} needs no prepare`);
        return;
    }
    log(`Mirror prepare brk 0x6a: RX=0x${rx.toString(16)} RW=0x${rw.toString(16)} size=0x${size.toString(16)}`);
    try {
        let r1 = prepare_memory_region(rx, size);
        log(`Prepared mirror RX=0x${rx.toString(16)} (${r1})`);
    } catch (e) {
        log(`ERROR: mirror prepare failed: ${e}`);
    }
};

log('Amethyst UniversalJIT26 extension loaded (handlers 0x69/0x6a, commands 3/4/5/6, mirror offer-serve, detach disabled)');
