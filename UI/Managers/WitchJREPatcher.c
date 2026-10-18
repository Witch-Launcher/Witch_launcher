// On-device equivalent of the build-time libjvm mirror brk patches
// (scripts/patch_libjvm_mirror_brk.py + scripts/patch_libjvm_jit_alloc.py).
//
// The JDK-Java_iOS release archives ship some runtimes without the brk hooks
// (jre8 has no marker at all, jre17 has the marker but an unpatched libjvm).
// iOS 27 rejects runtime __TEXT patches, so the fallback has to happen on the
// file BEFORE the runtime is first loaded: patch, verify, then write the
// launcher's mirror marker.

#include "WitchJREPatcher.h"

#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define MIRROR_MAPPING_LOG "[JIT26] mapping at RW=%p, RX=%p\n"
#define JIT_ALLOC_REQUEST_LOG "[JIT26] Requesting %zu MB for JIT mapping\n"
#define SCAN_START 0x4000u
#define SCAN_END_CAP 0xC00000u

#define BRK_0x6A (0xD4200000u | (0x6Au << 5))
#define BRK_0xF00D (0xD4200000u | (0xF00Du << 5))
#define MOV_X16_1 0xD2800030u
#define STP_X8_X19_SP 0xA9004FE8u
#define LDR_X1_SP8 0xF94007E1u
#define STR_X8_SP 0xF90003E8u
#define NOP_INSN 0xD503201Fu

// Branch targets after the patch window (keep in sync with
// scripts/patch_libjvm_jit_alloc.py):
//   +0x54 mov x0, #0     — mmap(PROT_READ|PROT_EXEC) fallback entry
//   +0x74 cbz x0, err / +0x78 mov w21, #2 — vm_remap(src=x20) tail before brk #0x6a
// The old +0x48 target landed inside the getenv("XNU_HAS_TXM") check and fell
// into the app-side mmap fallback; TXM strips exec there -> SIGBUS at first stub.
#define JIT_ALLOC_MMAP_OFF 0x54u
#define JIT_ALLOC_VMREMAP_OFF 0x74u
#define CBZ_X0_ERR_INSN 0xB4000400u
#define MOV_W21_2_INSN 0x52800055u
#define MOV_X0_0_INSN 0xD2800000u

static uint32_t rd_u32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void wr_u32(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)(v & 0xFF);
    p[1] = (uint8_t)((v >> 8) & 0xFF);
    p[2] = (uint8_t)((v >> 16) & 0xFF);
    p[3] = (uint8_t)((v >> 24) & 0xFF);
}

// Decode `adrp w?, page; add w?, w?, #off` starting at pc. Returns the target
// address (file-offset based, __TEXT starts at 0 for these dylibs) or -1.
// `require_bl_or_brk` mirrors patch_libjvm_mirror_brk.py, which only accepts
// sites whose third word is already the replaced `brk #0x6a` (idempotency).
static int64_t decode_adrp_add(const uint8_t *data, size_t len, size_t pc, bool require_bl_or_brk) {
    if (pc + 12 > len) return -1;
    uint32_t w0 = rd_u32(data + pc);
    uint32_t w1 = rd_u32(data + pc + 4);
    if ((w0 & 0x9F000000u) != 0x90000000u || (w1 & 0xFF000000u) != 0x91000000u) return -1;
    if (require_bl_or_brk) {
        uint32_t w2 = rd_u32(data + pc + 8);
        if ((w2 & 0xFC000000u) != 0x94000000u && w2 != BRK_0x6A) return -1;
    }
    int64_t immlo = (int64_t)((w0 >> 29) & 0x3u);
    int64_t immhi = (int64_t)((w0 >> 5) & 0x7FFFFu);
    int64_t imm21 = (immhi << 2) | immlo;
    if (imm21 & 0x100000) imm21 -= 0x200000;
    int64_t page = (int64_t)(pc & ~(size_t)0xFFF) + (imm21 << 12);
    uint32_t imm12 = (w1 >> 10) & 0xFFFu;
    uint32_t shift = (w1 >> 22) & 0x1u;
    return page + (int64_t)(imm12 << (shift ? 12 : 0));
}

static size_t scan_end(size_t len) {
    return len < (size_t)SCAN_END_CAP ? len : (size_t)SCAN_END_CAP;
}

static bool mem_has(const uint8_t *data, size_t len, uint32_t insn) {
    uint8_t pat[4];
    wr_u32(pat, insn);
    if (len < 4) return false;
    for (size_t i = 0; i + 4 <= len; i += 4) {
        if (data[i] == pat[0] && data[i + 1] == pat[1] && data[i + 2] == pat[2] && data[i + 3] == pat[3]) {
            return true;
        }
    }
    return false;
}

static bool mem_has_string(const uint8_t *data, size_t len, const char *needle) {
    size_t nlen = strlen(needle);
    if (len < nlen) return false;
    for (size_t off = 0; off + nlen <= len; off++) {
        if (data[off] == (uint8_t)needle[0] && memcmp(data + off, needle, nlen) == 0) {
            return true;
        }
    }
    return false;
}

static uint8_t *read_file(const char *path, size_t *outLen) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    if (fseek(f, 0, SEEK_END) != 0) {
        fclose(f);
        return NULL;
    }
    long sz = ftell(f);
    if (sz <= 0) {
        fclose(f);
        return NULL;
    }
    if (fseek(f, 0, SEEK_SET) != 0) {
        fclose(f);
        return NULL;
    }
    uint8_t *data = malloc((size_t)sz);
    if (!data) {
        fclose(f);
        return NULL;
    }
    if (fread(data, 1, (size_t)sz, f) != (size_t)sz) {
        free(data);
        fclose(f);
        return NULL;
    }
    fclose(f);
    *outLen = (size_t)sz;
    return data;
}

// Write via temp file + rename so a kill mid-write cannot leave a truncated
// libjvm behind (the runtime would then fail to load entirely).
static bool write_file_atomic(const char *path, const uint8_t *data, size_t len) {
    char tmp[PATH_MAX];
    if (snprintf(tmp, sizeof(tmp), "%s.patching", path) >= (int)sizeof(tmp)) return false;
    FILE *f = fopen(tmp, "wb");
    if (!f) return false;
    bool ok = fwrite(data, 1, len, f) == len;
    if (fclose(f) != 0) ok = false;
    if (!ok) {
        unlink(tmp);
        return false;
    }
    struct stat st;
    if (stat(path, &st) == 0) {
        chmod(tmp, st.st_mode);
    }
    if (rename(tmp, path) != 0) {
        unlink(tmp);
        return false;
    }
    return true;
}

#pragma mark - patch_libjvm_mirror_brk.py port

static ssize_t find_mirror_bl_off(uint8_t *data, size_t len) {
    const char *needle = MIRROR_MAPPING_LOG;
    size_t nlen = strlen(needle);
    size_t str_off = SIZE_MAX;
    for (size_t off = 0; off + nlen <= len; off++) {
        if (data[off] == (uint8_t)needle[0] && memcmp(data + off, needle, nlen) == 0) {
            str_off = off;
            break;
        }
    }
    if (str_off == SIZE_MAX) return -1;

    size_t end = scan_end(len);
    for (size_t pc = SCAN_START; pc + 12 <= end; pc += 4) {
        if (decode_adrp_add(data, len, pc, true) != (int64_t)str_off) continue;
        size_t bl_off = pc + 8;
        uint32_t insn = rd_u32(data + bl_off);
        if ((insn & 0xFC000000u) == 0x94000000u || insn == BRK_0x6A) {
            return (ssize_t)bl_off;
        }
    }
    return -1;
}

bool witch_jre_patch_libjvm_mirror_brk(const char *libjvmPath) {
    size_t len = 0;
    uint8_t *data = read_file(libjvmPath, &len);
    if (!data) return false;

    bool ok = false;
    ssize_t bl_off = find_mirror_bl_off(data, len);
    if (bl_off >= 0) {
        uint32_t insn = rd_u32(data + bl_off);
        if (insn == BRK_0x6A) {
            ok = true; // already patched
        } else if ((insn & 0xFC000000u) == 0x94000000u) {
            wr_u32(data + bl_off, BRK_0x6A);
            ok = write_file_atomic(libjvmPath, data, len);
        }
    }
    free(data);
    return ok;
}

#pragma mark - patch_libjvm_jit_alloc.py port

static ssize_t find_jit_alloc_off(uint8_t *data, size_t len) {
    const char *needle = JIT_ALLOC_REQUEST_LOG;
    size_t nlen = strlen(needle);
    size_t str_off = SIZE_MAX;
    for (size_t off = 0; off + nlen <= len; off++) {
        if (data[off] == (uint8_t)needle[0] && memcmp(data + off, needle, nlen) == 0) {
            str_off = off;
            break;
        }
    }
    if (str_off == SIZE_MAX) return -1;

    size_t end = scan_end(len);
    for (size_t pc = SCAN_START; pc + 24 <= end; pc += 4) {
        if (decode_adrp_add(data, len, pc, false) != (int64_t)str_off) continue;
        uint32_t w2 = rd_u32(data + pc + 8);
        if ((w2 & 0xFC000000u) != 0x94000000u) continue;
        uint32_t first = rd_u32(data + pc + 12);
        uint32_t second = rd_u32(data + pc + 16);
        if (first == 0xAA1303E0u && (second & 0xFC000000u) == 0x94000000u) {
            return (ssize_t)(pc + 12);
        }
        if ((first == 0xAA1303E1u || first == LDR_X1_SP8) && second == 0xD2800000u) {
            uint32_t third = rd_u32(data + pc + 20);
            if ((third == MOV_X16_1 || third == 0xD2800200u) && rd_u32(data + pc + 24) == BRK_0xF00D) {
                return (ssize_t)(pc + 12);
            }
        }
    }
    return -1;
}

static uint32_t success_branch_insn(size_t patch_off) {
    size_t b_pc = patch_off + 28;
    size_t b_target = patch_off + JIT_ALLOC_VMREMAP_OFF;
    int64_t b_imm = ((int64_t)b_target - (int64_t)b_pc) / 4;
    return 0x14000000u | ((uint32_t)b_imm & 0x03FFFFFFu);
}

static bool verify_jit_alloc_tail(const uint8_t *data, size_t len, size_t patch_off) {
    if (patch_off + JIT_ALLOC_VMREMAP_OFF + 8 > len) return false;
    if (rd_u32(data + patch_off + JIT_ALLOC_MMAP_OFF) != MOV_X0_0_INSN) return false;
    if (rd_u32(data + patch_off + JIT_ALLOC_VMREMAP_OFF) != CBZ_X0_ERR_INSN) return false;
    if (rd_u32(data + patch_off + JIT_ALLOC_VMREMAP_OFF + 4) != MOV_W21_2_INSN) return false;
    return true;
}

static bool patch_brk_sequence(uint8_t *data, size_t len, size_t patch_off) {
    if (patch_off + 44 > len || patch_off + JIT_ALLOC_VMREMAP_OFF + 8 > len) return false;
    size_t cbz_pc = patch_off + 16;
    size_t mmap_target = patch_off + JIT_ALLOC_MMAP_OFF;
    int64_t cbz_imm = ((int64_t)mmap_target - (int64_t)cbz_pc) / 4;
    if (cbz_imm <= 0 || cbz_imm >= 0x40000) return false;

    uint32_t patch_words[11] = {
        LDR_X1_SP8,
        0xD2800000u,
        MOV_X16_1,
        BRK_0xF00D,
        0xB4000000u | (((uint32_t)cbz_imm & 0x7FFFFu) << 5),
        0xAA0003F4u,
        0xF90003E0u,
        success_branch_insn(patch_off),
        NOP_INSN,
        NOP_INSN,
        NOP_INSN,
    };
    for (size_t i = 0; i < 11; i++) {
        wr_u32(data + patch_off + i * 4, patch_words[i]);
    }
    return true;
}

bool witch_jre_patch_libjvm_jit_alloc(const char *libjvmPath) {
    size_t len = 0;
    uint8_t *data = read_file(libjvmPath, &len);
    if (!data) return false;

    bool ok = false;
    ssize_t found = find_jit_alloc_off(data, len);
    if (found >= 0 && verify_jit_alloc_tail(data, len, (size_t)found)) {
        size_t patch_off = (size_t)found;
        size_t size_store_off = (patch_off >= 0x10) ? patch_off - 0x10 : SIZE_MAX;
        if (size_store_off != SIZE_MAX && size_store_off + 4 <= len && patch_off + 44 <= len) {
            uint32_t size_insn = rd_u32(data + size_store_off);
            uint32_t first = rd_u32(data + patch_off);
            uint32_t third = rd_u32(data + patch_off + 8);
            uint32_t brk_insn = rd_u32(data + patch_off + 12);
            uint32_t cbz_insn = rd_u32(data + patch_off + 16);
            uint32_t branch_insn = rd_u32(data + patch_off + 28);
            uint32_t tail_insn = rd_u32(data + patch_off + 32);
            uint32_t expected_cbz = 0xB4000000u | ((((uint32_t)(patch_off + JIT_ALLOC_MMAP_OFF) - (uint32_t)(patch_off + 16)) / 4) << 5);
            uint32_t expected_branch = success_branch_insn(patch_off);

            bool already_ok = first == LDR_X1_SP8 && third == MOV_X16_1 &&
                              brk_insn == BRK_0xF00D && cbz_insn == expected_cbz &&
                              branch_insn == expected_branch && tail_insn == NOP_INSN &&
                              size_insn == STP_X8_X19_SP;
            if (already_ok) {
                ok = true;
            } else if (first == LDR_X1_SP8 && brk_insn == BRK_0xF00D) {
                ok = patch_brk_sequence(data, len, patch_off) &&
                     write_file_atomic(libjvmPath, data, len);
            } else {
                bool first_matches = false;
                if (first == 0xAA1303E0u && (rd_u32(data + patch_off + 4) & 0xFC000000u) == 0x94000000u) {
                    first_matches = true;
                } else if ((first == 0xAA1303E1u || first == LDR_X1_SP8) && third == 0xD2800200u) {
                    first_matches = true;
                } else if ((first == 0xAA1303E1u || first == LDR_X1_SP8) &&
                           (third == MOV_X16_1 || third == 0xD2800200u) &&
                           brk_insn == BRK_0xF00D) {
                    first_matches = true;
                }
                if (first_matches) {
                    if (size_insn == STR_X8_SP) {
                        wr_u32(data + size_store_off, STP_X8_X19_SP);
                    } else if (size_insn != STP_X8_X19_SP) {
                        free(data);
                        return false;
                    }
                    ok = patch_brk_sequence(data, len, patch_off) &&
                         write_file_atomic(libjvmPath, data, len);
                }
            }
        }
    }
    free(data);
    return ok;
}

#pragma mark - Capability checks

WitchJREMirrorStatus witch_jre_libjvm_mirror_status(const char *jreDir) {
    char libjvm[PATH_MAX];
    if (snprintf(libjvm, sizeof(libjvm), "%s/lib/server/libjvm.dylib", jreDir) >= (int)sizeof(libjvm)) {
        return WitchJREMirrorStatusMissingLibjvm;
    }
    size_t len = 0;
    uint8_t *data = read_file(libjvm, &len);
    if (!data) return WitchJREMirrorStatusMissingLibjvm;

    bool has_6a = mem_has(data, len, BRK_0x6A);
    bool has_f00d = mem_has(data, len, BRK_0xF00D);
    bool has_mirror_code = mem_has_string(data, len, MIRROR_MAPPING_LOG) &&
                           mem_has_string(data, len, JIT_ALLOC_REQUEST_LOG);
    free(data);

    if (has_6a && has_f00d) return WitchJREMirrorStatusHooksPresent;
    if (has_mirror_code) return WitchJREMirrorStatusPatchable;
    return WitchJREMirrorStatusNoMirrorCode;
}

bool witch_jre_ensure_jit_ready(const char *jreDir) {
    if (!jreDir) return false;

    WitchJREMirrorStatus status = witch_jre_libjvm_mirror_status(jreDir);
    if (status == WitchJREMirrorStatusPatchable || status == WitchJREMirrorStatusHooksPresent) {
        char libjvm[PATH_MAX];
        if (snprintf(libjvm, sizeof(libjvm), "%s/lib/server/libjvm.dylib", jreDir) >= (int)sizeof(libjvm)) {
            return false;
        }
        // Both patchers are idempotent. jit_alloc re-runs even when hooks are
        // already present so a stale +0x48 success branch (pre-fix build, which
        // fell into the TXM-stripped mmap fallback and SIGBUSed at the first
        // stub) is refreshed to the vm_remap tail target.
        witch_jre_patch_libjvm_mirror_brk(libjvm);
        witch_jre_patch_libjvm_jit_alloc(libjvm);
        status = witch_jre_libjvm_mirror_status(jreDir);
    }
    if (status != WitchJREMirrorStatusHooksPresent) {
        return false;
    }

    char marker[PATH_MAX];
    if (snprintf(marker, sizeof(marker), "%s/.witch-mirror-mapping", jreDir) >= (int)sizeof(marker)) {
        return false;
    }
    FILE *f = fopen(marker, "wb");
    if (!f) return false;
    bool ok = fputs("witch-mirror-mapping-v1\n", f) >= 0;
    if (fclose(f) != 0) ok = false;
    return ok;
}
