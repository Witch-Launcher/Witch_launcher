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
const commands = {
    [CMD_DETACH]: JIT26Detach,
    [CMD_PREPARE_REGION]: JIT26PrepareRegion,
    [CMD_NEW_BREAKPOINTS]: JIT26NewBreakpoints
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
    
    let memResponse = send_command(`m${x0.toString(16)},${x1}`);

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

function parseRegNum(brkResponse, regNum) {
    const hex = regNum.toString(16).padStart(2, '0');
    const match = new RegExp(`${hex}:(?<reg>[0-9a-f]{16});`).exec(brkResponse);
    return match ? littleEndianHexStringToNumber(match.groups['reg']) : null;
}

// brk 0x6a: patched libjvm stops after mirror vm_remap (replaces printf).
function JIT26HandleBrk0x6a(brkResponse) {
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
    // Mirror superpage lives in a fixed 4 GB band (0x700000000-0x800000000).
    // Reject out-of-band pairs: a register-layout shift between JDK builds
    // would otherwise prepare_memory_region() on random addresses.
    if (rx < 0x700000000n || rx >= 0x800000000n || rw <= rx || rw > 0x800000000n) {
        log(`Mirror prepare brk 0x6a: out-of-band rx=0x${rx.toString(16)} rw=0x${rw.toString(16)}, skipping (layout drift?)`);
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

    // Mirror-mapped code cache uses a paired RW view at RX+size on iOS 26+/27.
    if (allocSize >= mirrorMin && jitPageAddress >= 0x700000000n && jitPageAddress < 0x800000000n) {
        const rwAddress = jitPageAddress + allocSize;
        try {
            prepare_memory_region(rwAddress, allocSize);
            prepare_memory_region(jitPageAddress, allocSize);
            log(`Prepared mirror pair RX=0x${jitPageAddress.toString(16)} RW=0x${rwAddress.toString(16)}`);
        } catch (e) {
            log_verbose(`Mirror RW prepare deferred (vm_remap may not have run yet): ${e}`);
        }
    }

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