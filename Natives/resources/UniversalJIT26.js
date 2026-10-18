// Universal JIT Script, last updated 2026-29-03 (YYYY-DD-MM)
// Amethyst: synced with StikDebug 3.1.x universal.js + try/catch around
// prepare_memory_region so an outdated debugger fails loudly instead of
// producing a W^X SIGBUS crash in the JVM.
/*
 // JIT "syscalls"
 __attribute__((noinline,optnone,naked))
 void JIT26Detach(void) {
     asm("mov x16, #0 \n"
         "brk #0xf00d \n"
         "ret");
 }
 __attribute__((noinline,optnone,naked))
 void* JIT26PrepareRegion(void *addr, size_t len) {
     asm("mov x16, #1 \n"
         "brk #0xf00d \n"
         "ret");
 }

 __attribute__((noinline,optnone,naked))
void BreakSendJITScript(char* script, size_t len) {
    asm("mov x16, #2 \n"
        "brk #0xf00d \n"
        "ret");
}
 */
const CMD_DETACH = 0;
const CMD_PREPARE_REGION = 1;
const CMD_NEW_BREAKPOINTS = 2;
const CMD_OFFER_MIRROR_REGION = 5;
const CMD_VERIFY_MIRROR_OFFER = 6;
const commands = {
    [CMD_DETACH]: JIT26Detach,
    [CMD_PREPARE_REGION]: JIT26PrepareRegion,
    [CMD_NEW_BREAKPOINTS]: JIT26NewBreakpoints,
    [CMD_OFFER_MIRROR_REGION]: JIT26OfferMirrorRegion,
    [CMD_VERIFY_MIRROR_OFFER]: JIT26VerifyMirrorOffer
};
const legacyCommands = {
    [0x68]: JIT26NewBreakpoints,
    [0x69]: JIT26HandleBrk0x69,
    [0x6a]: JIT26HandleBrk0x6a,
    [0xf00d]: JIT26HandleBrk0xf00d
};

let detachAfterFirstBr = false;

const LOG_INFO = 1;
const LOG_VERBOSE = 2;
let logLevel = LOG_VERBOSE;
function log_verbose(msg) {
    if (logLevel >= LOG_VERBOSE) {
        log(msg);
    }
}

// To avoid having to re-parse these in each function, we save some registers here
let tid, x0, x1, x16, pc;
// Last region JIT26PrepareRegion blessed via prepare_memory_region. The brk
// 0x6a handler (this file + UniversalJIT26Extension.js) skips re-preparing the
// same RX region: the write-blessing costs one debugger round trip per 16 KB
// page (~30 s for a 240 MB CodeCache).
let lastPreparedRx = null;
let lastPreparedSize = 0n;
// Mirror region offered by the launcher's big preflight (brk cmd 5): a
// full-size region the launcher already blessed + exec-probed BEFORE the JVM
// started. When libjvm later asks for its 240 MB CodeCache (brk cmd 1 with
// addr=0) we serve this region instead of a fresh _M mapping, so the code
// cache cannot land in a band where the exec blessing is ineffective
// (iPad9/A13 TXM: 0x7000000000 prepare reports OK but every stub call SIGBUSes).
let offeredRx = null;
let offeredSize = 0n;
let offeredServed = false;
let detached = false;
let continuesWithSignal = true;
let pid = get_pid();
let attachResponse = send_command(`vAttach;${pid.toString(16)}`);

log(`pid = ${pid}`);
log(`attach_response = ${attachResponse}`);
    
let totalBreakpoints = 0;
while (!detached) {
    totalBreakpoints++;
    log(`Handling signal ${totalBreakpoints}`);
    
    let brkResponse = send_command(`c`);
    log_verbose(`brkResponse = ${brkResponse}`);
    
    // extract tid, pc, x16
    let tmpMatch = /T[0-9a-f]+thread:(?<tid>[0-9a-f]+);/.exec(brkResponse);
    tid = tmpMatch ? tmpMatch.groups['tid'] : null;
    tmpMatch = /20:(?<reg>[0-9a-f]{16});/.exec(brkResponse);
    pc = tmpMatch ? tmpMatch.groups['reg'] : null;
    tmpMatch = /10:(?<reg>[0-9a-f]{16});/.exec(brkResponse);
    x16 = tmpMatch ? tmpMatch.groups['reg'] : null;
    if (!tid || !pc || !x16) {
        log(`Failed to extract registers: tid=${tid}, pc=${pc}, x16=${x16}`);
        continue;
    }
    pc = littleEndianHexStringToNumber(pc);
    x16 = littleEndianHexStringToNumber(x16);
    
    let instructionResponse = send_command(`m${pc.toString(16)},4`);
    log(`instruction at pc: ${instructionResponse}`);
    let instrU32 = littleEndianHexToU32(instructionResponse);
    
    // check if this is a brk
    if ((instrU32 & 0xFFE0001F)>>>0 != 0xD4200000) {
        log(`Skipping: instruction was not a brk (was 0x${instrU32.toString(16)})`);
        if (continuesWithSignal) {
            let signum = /^T(?<sig>[a-z0-9;]{2})/.exec(brkResponse);
            signum = signum ? signum.groups['sig'] : null;
            if (!signum) {
                log(`Failed to extract signal number: ${signum}`);
                continue;
            }
            log(`Continuing with signal 0x${signum}`);
            send_command(`vCont;S${signum}:${tid}`);
        }
        continue;
    }
    
    let brkImmediate = extractBrkImmediate(instrU32);
    log(`BRK immediate: 0x${brkImmediate.toString(16)} (${brkImmediate})`);
    if (legacyCommands[brkImmediate] != undefined) {
        // when we find a valid brk immediate command, parse x0 and x1
        tmpMatch = /00:(?<reg>[0-9a-f]{16});/.exec(brkResponse);
        x0 = tmpMatch ? tmpMatch.groups['reg'] : null;
        tmpMatch = /01:(?<reg>[0-9a-f]{16});/.exec(brkResponse);
        x1 = tmpMatch ? tmpMatch.groups['reg'] : null;
        if (!x0 || !x1) {
            log(`Failed to extract registers: x0=${x0}, x1=${x1}`);
            continue;
        }
        x0 = littleEndianHexStringToNumber(x0);
        x1 = littleEndianHexStringToNumber(x1);
        
        // jump over brk
        let pcPlus4 = numberToLittleEndianHexString(pc + 4n);
        let pcPlus4Response = send_command(`P20=${pcPlus4};thread:${tid};`);
        log(`pcPlus4Response = ${pcPlus4Response}`);
        
        // dispatch brk-immediate command
        const command = legacyCommands[brkImmediate];
        command(brkResponse);
    } else {
        log(`Skipping breakpoint: brk immediate 0x${brkImmediate.toString(16)} was not handled by this script. You could add it by evaluating legacyCommands[0x${brkImmediate.toString(16)}] = yourFunction;`);
        continue;
    }
}

function JIT26Detach() {
    let detachResponse = send_command(`D`);
    log_verbose(`detachResponse = ${detachResponse}`);
    detached = true;
}

// brk 0x68
function JIT26NewBreakpoints(brkResponse) {
    let instructionResponse = send_command(`m${pc.toString(16)},4`);
    log(`instruction at pc: ${instructionResponse}`);
    let instrU32 = littleEndianHexToU32(instructionResponse);
    let brkImmediate = extractBrkImmediate(instrU32);
    
    // GDB RSP `m addr,length`: BOTH fields are hex. x1 arrives as a BigInt —
    // format it hex (its default toString is decimal, which over-reads).
    let memResponse = send_command(`m${x0.toString(16)},${x1.toString(16)}`);

    let scriptText = hexToAscii(memResponse);
    log_verbose(`Script text: ${scriptText}`);

    const res = runScriptAndCapture(scriptText);
    if (res.ok) {
        log('Script succeeded:', res.value);
    } else {
        log('Script failed:', res.name, res.message);
        log(res.stack);
    }
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

// Mirror superpage address band. iOS 26 placed the 240 MB reservation inside
// 0x700000000-0x800000000, but iOS 27 puts LARGE reservations high:
// hs_err_pid8878 (iPhone 13, iOS 27.0, Java 25) shows CodeHeap RX=0x700F004000
// (~481 GB) with the Java heap right after it. A 34 GB ceiling therefore
// misclassifies the true pair as "out-of-band" and leaves it unblessed ->
// SIGBUS at the first stub. Accept up to 1 TB; still rejects kernel addresses,
// tagged pointers and register garbage (0xCCCC.../0xDEAD.../0xFFFF...).
const MIRROR_BAND_LO = 0x100000000n;
const MIRROR_BAND_HI = 0x10000000000n;
function mirrorInBand(v) {
    return v !== null && v !== undefined && v >= MIRROR_BAND_LO && v < MIRROR_BAND_HI;
}

// brk 0x6a: patched libjvm stops after mirror vm_remap (replaces printf).
// Register truth (verified by disassembling get_debug_jit_mapping in the
// bundled Java 25 libjvm): the site replaced `bl printf`, and NOTHING reloads
// x1/x2 after the preceding calls, so x1/x2 hold call leftovers (garbage).
// The live values are x20 (callee-saved, carries the RX base from the alloc
// result) and x8 (freshly reloaded from the vm_remap out-slot = RW alias).
// x1/x2 are kept only as a legacy fallback for older libjvm builds.
function resolveMirrorPair(brkResponse, rxGuess, rwGuess) {
    const fmt = (v) => (v === null || v === undefined ? "?" : "0x" + v.toString(16));
    let x8v = null, x20v = null;
    try { x8v = parseRegNum(brkResponse, 0x08); } catch (e) { x8v = null; }
    try { x20v = parseRegNum(brkResponse, 0x14); } catch (e) { x20v = null; }
    log(`Mirror brk 0x6a regs: x1=${fmt(rwGuess)} x2=${fmt(rxGuess)} x8=${fmt(x8v)} x20=${fmt(x20v)}`);
    if (mirrorInBand(x20v) && mirrorInBand(x8v)) {
        log(`Mirror pair from x20/x8 (live regs): RX=0x${x20v.toString(16)} RW=0x${x8v.toString(16)}`);
        return { rx: x20v, rw: x8v };
    }
    if (mirrorInBand(rxGuess) && mirrorInBand(rwGuess)) {
        log(`Mirror pair from x1/x2 (legacy fallback)`);
        return { rx: rxGuess, rw: rwGuess };
    }
    return null;
}

function JIT26HandleBrk0x6a(brkResponse) {
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
    // Range-guard the resolved pair (see MIRROR_BAND_* above).
    if (!mirrorInBand(rx) || !mirrorInBand(rw)) {
        log(`Mirror prepare brk 0x6a: out-of-band rx=0x${rx.toString(16)} rw=0x${rw.toString(16)}, skipping (layout drift?)`);
        return;
    }
    // Size: prefer the size JIT26PrepareRegion actually blessed for this RX
    // region. NEVER derive it from rw-rx: the alias is vm_remap'd ANYWHERE, so
    // the difference can be gigabytes and the prepare would run off the end
    // (each page write silently fails but the walk takes minutes).
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
}

// brk 0x69 — allocate/prepare RX JIT region (BreakGetJITMapping)
function JIT26HandleBrk0x69(brkResponse) {
    x1 = x0;
    x0 = 0;
    JIT26PrepareRegion(brkResponse);
    if (detachAfterFirstBr) {
        JIT26Detach();
    }
}

// brk 0xf00d
function JIT26HandleBrk0xf00d(brkResponse) {
    // dispatch command via x16
    const command = commands[x16];
    if (command === undefined) {
        log(`Unknown command ${x16.toString(16)}`);
        return;
    }
    log(`Invoking command ${x16.toString(16)}`);
    command(brkResponse);
}

// brk 0xf00d cmd 5 — JIT26OfferMirrorRegion(void *addr, size_t size): the
// launcher reserved, blessed and exec-probed a full-size mirror region before
// the JVM started; remember it so JIT26PrepareRegion can serve it for the
// JVM's own 240 MB CodeCache request.
function JIT26OfferMirrorRegion(brkResponse) {
    offeredRx = x0;
    offeredSize = x1;
    offeredServed = false;
    log(`Launcher-offered mirror region: addr=0x${offeredRx.toString(16)} size=0x${offeredSize.toString(16)} (pre-blessed + exec-probed)`);
}

// brk 0xf00d cmd 6 — JIT26VerifyMirrorOffer(): echo the stored offer back
// through x0. The offer brk is otherwise fire-and-forget: a stale assigned
// script (evaluated without the extension) drops it silently and the JVM
// falls back to an unblessable high _M region. The launcher compares the
// echo against the region it offered and reports offer_verify=0|1.
function JIT26VerifyMirrorOffer(brkResponse) {
    let rx = 0n;
    if (typeof offeredRx === 'bigint' && offeredRx > 0n) {
        rx = offeredRx;
    }
    send_command(`P0=${numberToLittleEndianHexString(rx)};thread:${tid};`);
    log(`Mirror offer verify: rx=0x${rx.toString(16)}`);
}

function JIT26PrepareRegion(brkResponse) {
    let instructionResponse = send_command(`m${pc.toString(16)},4`);
    log(`instruction at pc: ${instructionResponse}`);
    let instrU32 = littleEndianHexToU32(instructionResponse);
    let brkImmediate = extractBrkImmediate(instrU32);
    
    if (x0 == 0n && x1 == 0n) {
        send_command(`P0=0000000000000000;thread:${tid};`);
        return;
    }

    let allocSize = x1;
    const freshX1 = parseRegNum(brkResponse, 0x01);
    if (freshX1 != null && freshX1 > allocSize) {
        allocSize = freshX1;
    }
    const mirrorMin = 16n * 1024n * 1024n;
    const mirrorSize = 0xf000000n;
    if (x0 == 0n && allocSize > 0n && allocSize < mirrorMin && allocSize < 0x4000n) {
        log(`JIT26PrepareRegion: suspicious alloc size 0x${allocSize.toString(16)}, using 0x${mirrorSize.toString(16)} for mirror superpage`);
        allocSize = mirrorSize;
    }

    let jitPageAddress = x0;
    if (x0 == 0n) {
        // Prefer the launcher's pre-checked region for large mirror requests
        // (libjvm's 240 MB CodeCache). The launcher blessed it and proved it
        // executes before the JVM started (see JIT26MirrorRegionPreflight);
        // that call also recorded lastPreparedRx/Size through the x0 != 0 path
        // below, so the brk 0x6a handler skips re-preparing this region.
        if (typeof offeredRx === 'bigint' && offeredRx > 0n && !offeredServed &&
            allocSize >= mirrorMin && offeredSize >= allocSize) {
            offeredServed = true;
            log(`Serving launcher-prechecked mirror region for request size=0x${allocSize.toString(16)} — skipping _M allocation`);
            jitPageAddress = offeredRx;
            lastPreparedRx = offeredRx;
            lastPreparedSize = offeredSize;
            log(`Allocated JIT page at address: 0x${jitPageAddress.toString(16)} (size=0x${offeredSize.toString(16)}) [served from launcher offer]`);
            let servedPutX0Response = send_command(`P0=${numberToLittleEndianHexString(jitPageAddress)};thread:${tid};`);
            log(`putX0Response = ${servedPutX0Response}`);
            return;
        }
        if (typeof offeredRx === 'bigint' && offeredRx > 0n && !offeredServed) {
            log(`Launcher-offer not served: req=0x${allocSize.toString(16)} offer=0x${offeredSize.toString(16)} (size mismatch?)`);
        }
        let requestRXResponse = send_command(`_M${allocSize.toString(16)},rx`);
        log_verbose(`requestRXResponse = ${requestRXResponse}`);
        
        if (!requestRXResponse || requestRXResponse.length === 0) {
            log(`Failed to allocate RX memory`);
            send_command(`P0=0000000000000000;thread:${tid};`);
            return;
        }
        
        jitPageAddress = BigInt(`0x${requestRXResponse}`);
        log(`Allocated JIT page at address: 0x${jitPageAddress.toString(16)} (size=0x${allocSize.toString(16)})`);
    }

    let prepareJITPageResponse;
    try {
        prepareJITPageResponse = prepare_memory_region(jitPageAddress, allocSize);
    } catch (e) {
        log(`ERROR: prepare_memory_region threw: ${e}`);
        log(`ERROR: JIT execution grant FAILED. This debugger build is too old for iOS 26.4+/27.`);
        log(`ERROR: Update StikDebug to 3.1.6 or newer and try again.`);
        send_command(`P0=00000000;thread:${tid};`);
        return;
    }
    log(`prepareJITPageResponse = ${prepareJITPageResponse}`);

    // Record the blessing so the brk 0x6a handler does not redo the per-page
    // prepare for this region (libjvm raises 0x6a after its vm_remap).
    lastPreparedRx = jitPageAddress;
    lastPreparedSize = allocSize;

    // NOTE: no "RW view at RX+size" prepare here. libjvm's vm_remap creates the
    // RW alias AFTER this call at a kernel-picked (VM_FLAGS_ANYWHERE) address,
    // so preparing RX+size would walk unmapped memory. The real alias arrives
    // as x8 on the brk 0x6a (x20=RX); writes through the alias do not need any
    // blessing — only the RX pages that will execute do.

    let putX0Response = send_command(`P0=${numberToLittleEndianHexString(jitPageAddress)};thread:${tid};`);
    log(`putX0Response = ${putX0Response}`);
}

// utilities
function littleEndianHexStringToNumber(hexStr) {
    const bytes = [];
    for (let i = 0; i < hexStr.length; i += 2) {
        bytes.push(parseInt(hexStr.substr(i, 2), 16));
    }
    let num = 0n;
    for (let i = 4; i >= 0; i--) {
        num = (num << 8n) | BigInt(bytes[i]);
    }
    return num;
}

function numberToLittleEndianHexString(num) {
    const bytes = [];
    for (let i = 0; i < 5; i++) {
        bytes.push(Number(num & 0xFFn));
        num >>= 8n;
    }
    while (bytes.length < 8) {
        bytes.push(0);
    }
    return bytes.map(b => b.toString(16).padStart(2, '0')).join('');
}

function littleEndianHexToU32(hexStr) {
    return parseInt(hexStr.match(/../g).reverse().join(''), 16);
}

function extractBrkImmediate(u32) {
    return (u32 >> 5) & 0xFFFF;
}

function hexToAscii(hexStr) {
    let str = '';
    for (let i = 0; i < hexStr.length; i += 2) {
        const byte = parseInt(hexStr.substr(i, 2), 16);
        if (byte === 0) break;
        str += String.fromCharCode(byte);
    }
    return str;
}

function runScriptAndCapture(scriptText) {
    try {
        const value = eval(scriptText);
        return { ok: true, value };
    } catch (err) {
        return {
            ok: false,
            name: err && err.name,
            message: err && err.message,
            stack: err && err.stack
        };
    }
}

// JIT26SetDetachAfterFirstBr(BOOL) — cmd 3
commands[3] = function(brkResponse) {
    detachAfterFirstBr = x0 != 0;
    log(`JIT26SetDetachAfterFirstBr(${detachAfterFirstBr}) called`);
};

// JIT26PrepareRegionForPatching(void *addr, size_t len) — cmd 4
commands[4] = function(brkResponse) {
    let x0str = x0.toString(16);
    let x1str = x1.toString(16);
    let bytes = send_command(`m${x0str},${x1str}`);
    send_command(`M${x0str},${x1str}:${bytes}`);
};

// For making your own script / adding your own breakpoints. you can send this string to BreakSendJITScript and it'll add it for any subsequent breakpoints
// x0, x1, x16, pc and tid are global variables. If you need more registers, parse them like:
// tmpMatch = /02:(?<reg>[0-9a-f]{16});/.exec(brkResponse); // x2
// let x2 = tmpMatch ? tmpMatch.groups['reg'] : null;
// if (!x2) {
//     log(`Failed to extract registers: x2=${x2}`);
//     return;
// }
// x2 = littleEndianHexStringToNumber(x2);
//
/*
commands[3] = wowBreakPoint;

function wowBreakPoint(brekpoint) {
    let instructionResponse = send_command(`m${pc.toString(16)},4`);
    log(`instruction at pc: ${instructionResponse}`);
    let instrU32 = littleEndianHexToU32(instructionResponse);
    let brkImmediate = extractBrkImmediate(instrU32);
    
    if (x0 == 0n && x1 == 0n) {
        return;
    }

    let jitPageAddress = x0;
    let prepareJITPageResponse = prepare_memory_region(jitPageAddress, x1);
    log(`prepareJITPageResponse = ${prepareJITPageResponse}`);

    let putX0Response = send_command(`P0=${numberToLittleEndianHexString(jitPageAddress)};thread:${tid};`);
    log(`putX0Response = ${putX0Response}`);
}
*/