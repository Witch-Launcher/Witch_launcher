#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <libgen.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include <CommonCrypto/CommonDigest.h>

extern int dyld_get_active_platform();

// ==================== Ad-hoc code signing ====================
// Mods that ship macOS dylibs (Distant Horizons' zstd/lz4/sqlite natives,
// for example) are extracted into the app container at runtime and loaded
// with dlopen(). dyld refuses a macOS platform binary inside an iOS
// process, so the launcher rewrites the LC_BUILD_VERSION platform before
// the load happens.
//
// That rewrite changes a byte which the embedded code signature covers, so
// the file stops being validly signed. Up to iOS 18 the launcher could get
// away with it: dyld asked the kernel to re-attach a signature over the
// patched file (F_ADDFILESIGS_RETURN) and the executable mapping was
// accepted. On iOS 26+ that attach is skipped on TXM devices (it crashes
// the process), so the kernel refuses the executable mapping of the patched
// file and dyld finally rejects the library with "not a mach-o file" - which
// is exactly how Distant Horizons kills the game on iOS 26.
//
// The fix is to rebuild the ad-hoc signature ourselves whenever the platform
// is patched: the code slots are re-hashed after the patch and a fresh
// CodeDirectory is written into the signature area of the file. The result
// is a properly signed iOS platform dylib, so the kernel maps it executable
// and dyld loads it without needing the fallback path.

#define PL_CODE_SIGNATURE_CMD 0x1d
#define PL_BUILD_VERSION_CMD 0x32
#define PL_SEGMENT_64_CMD 0x19

#define PL_CSMAGIC_EMBEDDED_SIGNATURE 0xfade0cc0
#define PL_CSMAGIC_CODEDIRECTORY 0xfade0c02
#define PL_CSMAGIC_REQUIREMENT 0xfade0c01
#define PL_CSMAGIC_BLOBWRAPPER 0xfade0b01

#define PL_CS_ADHOC 0x2
#define PL_CSSLOT_CODEDIRECTORY 0
#define PL_CSSLOT_REQUIREMENTS 2
#define PL_CSSLOT_SIGNATURESLOT 0x10000

#define PL_HASH_SIZE 32
#define PL_HASH_TYPE_SHA256 2
#define PL_CODE_DIRECTORY_VERSION 0x20400
#define PL_CODE_DIRECTORY_HEADER_SIZE 88
#define PL_PAGE_SIZE 4096

// The code signature structures are big endian, the Mach-O load commands are
// host endian (little endian on every device we ship to).
static void PLPutBE32(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)(v >> 24);
    p[1] = (uint8_t)(v >> 16);
    p[2] = (uint8_t)(v >> 8);
    p[3] = (uint8_t)v;
}

static void PLPutBE64(uint8_t *p, uint64_t v) {
    PLPutBE32(p, (uint32_t)(v >> 32));
    PLPutBE32(p + 4, (uint32_t)v);
}

static void PLPutHost32(uint8_t *p, uint32_t v) {
    memcpy(p, &v, sizeof(v));
}

// Collects everything the signer needs out of a Mach-O slice.
typedef struct {
    uint32_t buildVersionCmdOff;  // offset of the LC_BUILD_VERSION command
    uint32_t platform;            // current platform of that command
    uint32_t codeSignatureCmdOff; // offset of the LC_CODE_SIGNATURE command
    uint32_t sigDataoff;          // start of the embedded signature
    uint32_t sigDatasize;         // size of the embedded signature
    uint64_t textVmsize;          // vmsize of __TEXT (exec segment limit)
    BOOL hasDylibVersions;        // a LC_LOAD_DYLIB still carries /Versions/x
} PLMachOInfo;

static void PLReadMachOInfo(const uint8_t *slice, uint32_t sliceSize, PLMachOInfo *info) {
    memset(info, 0, sizeof(*info));
    if (sliceSize < sizeof(struct mach_header_64)) return;
    const struct mach_header_64 *header = (const struct mach_header_64 *)slice;
    if (header->magic != MH_MAGIC_64) return;

    const uint8_t *cmds = slice + sizeof(struct mach_header_64);
    uint32_t remaining = sliceSize - (uint32_t)sizeof(struct mach_header_64);
    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (remaining < sizeof(struct load_command)) break;
        const struct load_command *cmd = (const struct load_command *)cmds;
        if (cmd->cmdsize < sizeof(struct load_command) || cmd->cmdsize > remaining) break;
        switch (cmd->cmd) {
            case PL_BUILD_VERSION_CMD: {
                if (info->buildVersionCmdOff == 0 && cmd->cmdsize >= 16) {
                    info->buildVersionCmdOff = (uint32_t)(cmds - slice);
                    memcpy(&info->platform, cmds + 8, sizeof(uint32_t));
                }
                break;
            }
            case PL_CODE_SIGNATURE_CMD: {
                if (info->codeSignatureCmdOff == 0 && cmd->cmdsize >= 16) {
                    info->codeSignatureCmdOff = (uint32_t)(cmds - slice);
                    memcpy(&info->sigDataoff, cmds + 8, sizeof(uint32_t));
                    memcpy(&info->sigDatasize, cmds + 12, sizeof(uint32_t));
                }
                break;
            }
            case PL_SEGMENT_64_CMD: {
                if (cmd->cmdsize >= 72) {
                    char segname[17];
                    memcpy(segname, cmds + 8, 16);
                    segname[16] = '\0';
                    if (strcmp(segname, "__TEXT") == 0) {
                        memcpy(&info->textVmsize, cmds + 24, sizeof(uint64_t));
                    }
                }
                break;
            }
            case LC_LOAD_DYLIB: {
                if (cmd->cmdsize >= 24) {
                    uint32_t nameOffset = 0;
                    memcpy(&nameOffset, cmds + 8, sizeof(uint32_t));
                    if (nameOffset < cmd->cmdsize) {
                        const char *dylibName = (const char *)(cmds + nameOffset);
                        if (strstr(dylibName, "/Versions/") != NULL) info->hasDylibVersions = YES;
                    }
                }
                break;
            }
            default:
                break;
        }
        cmds += cmd->cmdsize;
        remaining -= cmd->cmdsize;
    }
}

// Rewrites the platform of the given slice (macOS -> iOS). Returns YES only
// when the slice was really modified: a file that already carries the right
// platform must be left alone, otherwise its code signature is invalidated.
static BOOL PLPatchMachOPlatformForSlice(const char *path, struct mach_header_64 *header) {
    BOOL changed = NO;
    uint8_t *imageHeaderPtr = (uint8_t*)header + sizeof(struct mach_header_64);

    struct load_command *command = (struct load_command *)imageHeaderPtr;
    for(int i = 0; i < header->ncmds; i++) {
        if (command->cmd == LC_BUILD_VERSION) {
            struct build_version_command *buildver = (struct build_version_command *)command;
            int activePlatform = dyld_get_active_platform();
            if (buildver->platform == activePlatform) return NO; // it is already set, stop
            buildver->platform = activePlatform; // set to current platform
            changed = YES;
        } else if (command->cmd == LC_LOAD_DYLIB) {
            struct dylib_command *dylib = (struct dylib_command *)command;
            char *dylibName = (void *)dylib + dylib->dylib.name.offset;
            char *verPtr = strstr(dylibName, "/Versions/");
            if (verPtr) {
                // Remove "/Versions/X"
                int lastComponentLen = strlen(dylibName) - (verPtr - dylibName) - 11;
                memmove(verPtr, verPtr + 11, lastComponentLen);
                verPtr[lastComponentLen] = '\0';
                changed = YES;
            }
        }
        command = (struct load_command *)((void *)command + command->cmdsize);
    }
    return changed;
}

// Builds the ad-hoc CodeDirectory (plus its SuperBlob wrapper) for `file`.
// The signed region is [0, codeLimit); the caller must have finalised every
// byte of that region (including the LC_CODE_SIGNATURE command) beforehand.
//
// Only the CodeDirectory goes into the SuperBlob: the requirements blob and
// the signature blob wrapper are optional and would only make the signature
// bigger than the area the shipped signature leaves behind.
static uint8_t *PLBuildAdHocSignature(const uint8_t *file, uint32_t codeLimit,
                                      uint64_t execSegLimit, const char *ident,
                                      uint32_t *outSize) {
    size_t identLen = strlen(ident) + 1;
    uint32_t nCodeSlots = (codeLimit + PL_PAGE_SIZE - 1) / PL_PAGE_SIZE;
    uint32_t cdLength = PL_CODE_DIRECTORY_HEADER_SIZE + (uint32_t)identLen + nCodeSlots * PL_HASH_SIZE;
    uint32_t indexLength = 8;
    uint32_t total = 12 + indexLength + cdLength;

    uint8_t *blob = malloc(total);
    if (blob == NULL) return NULL;
    memset(blob, 0, total);

    // CodeDirectory
    uint8_t *cd = blob + 12 + indexLength;
    PLPutBE32(cd + 0, PL_CSMAGIC_CODEDIRECTORY);
    PLPutBE32(cd + 4, cdLength);
    PLPutBE32(cd + 8, PL_CODE_DIRECTORY_VERSION);
    PLPutBE32(cd + 12, PL_CS_ADHOC);
    PLPutBE32(cd + 16, PL_CODE_DIRECTORY_HEADER_SIZE + (uint32_t)identLen); // hashOffset
    PLPutBE32(cd + 20, PL_CODE_DIRECTORY_HEADER_SIZE);                    // identOffset
    PLPutBE32(cd + 24, 0);                                                // nSpecialSlots
    PLPutBE32(cd + 28, nCodeSlots);                                        // nCodeSlots
    PLPutBE32(cd + 32, codeLimit);                                        // codeLimit
    cd[36] = PL_HASH_SIZE;         // hashSize
    cd[37] = PL_HASH_TYPE_SHA256;  // hashType
    cd[38] = 0;                    // platform
    cd[39] = 12;                   // pageSize (4096)
    // spare2 / scatterOffset / teamOffset / spare3 stay zero
    PLPutBE64(cd + 56, 0);          // codeLimit64
    PLPutBE64(cd + 64, 0);          // execSegBase
    PLPutBE64(cd + 72, execSegLimit); // execSegLimit
    PLPutBE64(cd + 80, 0);          // execSegFlags
    memcpy(cd + PL_CODE_DIRECTORY_HEADER_SIZE, ident, identLen);
    for (uint32_t slot = 0; slot < nCodeSlots; slot++) {
        uint32_t start = slot * PL_PAGE_SIZE;
        uint32_t end = start + PL_PAGE_SIZE;
        if (end > codeLimit) end = codeLimit;
        uint8_t hash[PL_HASH_SIZE];
        CC_SHA256(file + start, (CC_LONG)(end - start), hash);
        memcpy(cd + PL_CODE_DIRECTORY_HEADER_SIZE + identLen + slot * PL_HASH_SIZE, hash, PL_HASH_SIZE);
    }

    // SuperBlob header + blob index
    PLPutBE32(blob + 0, PL_CSMAGIC_EMBEDDED_SIGNATURE);
    PLPutBE32(blob + 4, total);
    PLPutBE32(blob + 8, 1);
    PLPutBE32(blob + 12, PL_CSSLOT_CODEDIRECTORY);
    PLPutBE32(blob + 16, 12 + indexLength);

    *outSize = total;
    return blob;
}

// Rewrites the embedded ad-hoc signature of the (already patched) file so the
// patched bytes stay covered by a valid signature.
// `sliceBase` is the offset of the Mach-O slice inside the file (0 for a thin
// binary), the load commands of the slice live at that offset.
static BOOL PLSignAdHocInPlace(const char *path, int fd, uint8_t **ioMap, size_t *ioFileSize,
                               const PLMachOInfo *info, const char *ident, uint32_t sliceBase) {
    if (info->codeSignatureCmdOff == 0) {
        // No signature area to update - the file stays unsigned and dyld will
        // have to fall back to its own handling.
        return NO;
    }

    uint8_t *map = *ioMap;
    size_t fileSize = *ioFileSize;
    uint32_t dataoff = info->sigDataoff;
    uint32_t datasize = info->sigDatasize;
    if (dataoff > fileSize) return NO;
    if ((uint64_t)dataoff + datasize < fileSize) {
        // Something follows the signature - leave such a file alone.
        return NO;
    }

    // Work out the size of the new signature so the LC_CODE_SIGNATURE command
    // can be updated before the code slots are hashed (the command itself
    // lives inside the signed region).
    uint32_t nCodeSlots = (dataoff + PL_PAGE_SIZE - 1) / PL_PAGE_SIZE;
    size_t identLen = strlen(ident) + 1;
    uint32_t cdLength = PL_CODE_DIRECTORY_HEADER_SIZE + (uint32_t)identLen + nCodeSlots * PL_HASH_SIZE;
    uint32_t newSigSize = 12 + 8 + cdLength;

    // The new signature replaces the old one in place: the signed region ends
    // where the signature starts and the file keeps its size, so the segment
    // layout stays intact. A stale signature blob left behind would be picked
    // up by the kernel instead of the new one and fail validation.
    if (newSigSize > datasize) {
        // The new signature does not fit into the old area. For a well formed
        // binary this cannot happen (the shipped signature always covers at
        // least the same code slots), so bail out and let the caller restore
        // the file instead of producing a half signed dylib.
        return NO;
    }

    // The load command has to be final before the hashes are computed.
    PLPutHost32(map + sliceBase + info->codeSignatureCmdOff + 8, dataoff);
    PLPutHost32(map + sliceBase + info->codeSignatureCmdOff + 12, newSigSize);

    uint32_t sigSize = 0;
    uint8_t *sig = PLBuildAdHocSignature(map, dataoff, info->textVmsize, ident, &sigSize);
    if (sig == NULL) return NO;
    if (sigSize > newSigSize) {
        free(sig);
        return NO;
    }
    memcpy(map + dataoff, sig, sigSize);
    // Wipe the rest of the old signature area so no stale blob is left behind.
    if (datasize > sigSize) {
        memset(map + dataoff + sigSize, 0, datasize - sigSize);
    }
    free(sig);
    return YES;
}

BOOL PLPatchMachOPlatformForFile(const char *path) {
    // Cheap pre-check: the container holds a lot of files that are not
    // dylibs at all, and this runs for every executable mapping.
    int probe = open(path, O_RDONLY);
    if (probe == -1) return NO;
    uint32_t probeMagic = 0;
    if (read(probe, &probeMagic, sizeof(probeMagic)) != (ssize_t)sizeof(probeMagic)) {
        close(probe);
        return NO;
    }
    close(probe);
    if (probeMagic != MH_MAGIC_64 && probeMagic != FAT_CIGAM) return NO;

    int fd = open(path, O_RDWR, (mode_t)0600);
    if (fd == -1) return NO;
    struct stat s;
    if (fstat(fd, &s) != 0 || s.st_size < (off_t)sizeof(struct mach_header_64)) {
        close(fd);
        return NO;
    }

    size_t size = (size_t)s.st_size;
    void *map = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (map == MAP_FAILED) {
        close(fd);
        return NO;
    }

    // Locate the slice we have to deal with: a thin arm64 binary, or the
    // arm64 slice of a fat one.
    uint32_t magic = *(uint32_t *)map;
    uint8_t *slice = (uint8_t *)map;
    uint32_t sliceSize = (uint32_t)size;
    if (magic == FAT_CIGAM) {
        struct fat_header *header = (struct fat_header *)map;
        struct fat_arch *arch = (struct fat_arch *)(map + sizeof(struct fat_header));
        slice = NULL;
        for (int i = 0; i < OSSwapInt32(header->nfat_arch); i++) {
            if (OSSwapInt32(arch->cputype) == CPU_TYPE_ARM64) {
                slice = (uint8_t *)map + OSSwapInt32(arch->offset);
                sliceSize = (uint32_t)OSSwapInt32(arch->size);
                break;
            }
            arch = (struct fat_arch *)((void *)arch + sizeof(struct fat_arch));
        }
    } else if (magic == MH_MAGIC_64 && ((struct mach_header_64 *)map)->cputype == CPU_TYPE_ARM64) {
        // thin arm64 binary
    } else {
        munmap(map, size);
        close(fd);
        return NO;
    }
    if (slice == NULL) {
        munmap(map, size);
        close(fd);
        return NO;
    }

    // Read the header before touching anything: if the platform is already
    // the one we need, the file must be left completely alone. Rewriting it
    // would invalidate a perfectly valid code signature.
    PLMachOInfo info;
    PLReadMachOInfo(slice, sliceSize, &info);
    uint32_t originalPlatform = info.platform;

    BOOL patched = PLPatchMachOPlatformForSlice(path, (struct mach_header_64 *)slice);
    if (!patched) {
        // Nothing was modified - the file keeps its original signature.
        munmap(map, size);
        close(fd);
        return NO;
    }
    NSLog(@"[Witch] Patched the platform of %s", path);

    // The platform byte is covered by the code signature, so the signature
    // has to be rebuilt - otherwise the kernel refuses to map the patched file
    // executable on iOS 26+ and dyld drops the library.
    PLReadMachOInfo(slice, sliceSize, &info);
    char pathCopy[PATH_MAX];
    snprintf(pathCopy, sizeof(pathCopy), "%s", path);
    char ident[PATH_MAX];
    snprintf(ident, sizeof(ident), "%s", basename(pathCopy));
    size_t identLen = strlen(ident);
    if (identLen > 6 && strcmp(ident + identLen - 6, ".dylib") == 0) {
        ident[identLen - 6] = '\0';
    }

    uint8_t *mutableMap = (uint8_t *)map;
    size_t mutableSize = size;
    uint32_t sliceBase = (uint32_t)(slice - (uint8_t *)map);
    BOOL didSign = PLSignAdHocInPlace(path, fd, &mutableMap, &mutableSize, &info, ident, sliceBase);
    if (didSign) {
        NSLog(@"[Witch] Re-signed %s after the platform patch (ad-hoc)", path);
    } else {
        NSLog(@"[Witch] Could not re-sign %s after the platform patch - restoring the original platform", path);
        // Put the platform back so the file keeps its original (valid)
        // signature instead of being left with a broken one.
        if (info.buildVersionCmdOff != 0) {
            PLPutHost32(mutableMap + sliceBase + info.buildVersionCmdOff + 8, originalPlatform);
            msync(mutableMap, mutableSize, MS_SYNC);
        }
    }

    munmap(mutableMap, mutableSize);
    close(fd);
    return didSign;
}
