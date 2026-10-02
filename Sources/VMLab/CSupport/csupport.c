#include "csupport.h"

#include <errno.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <os/proc.h>
#include <CoreFoundation/CoreFoundation.h>

// csops(2) is a public XNU syscall used by UTM and friends to read code-signing status.
extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
#define CS_OPS_STATUS 0
#define CS_DEBUGGED 0x10000000

// Security framework SPI (exported, used by UTM). Declared here to avoid a private header.
typedef struct __SecTask *SecTaskRef;
extern SecTaskRef SecTaskCreateFromSelf(CFAllocatorRef allocator);
extern CFTypeRef SecTaskCopyValueForEntitlement(SecTaskRef task, CFStringRef entitlement, CFErrorRef *error);

uint32_t vmlab_cs_flags(void) {
    uint32_t flags = 0;
    if (csops(getpid(), CS_OPS_STATUS, &flags, sizeof(flags)) != 0) {
        return 0;
    }
    return flags;
}

bool vmlab_is_debugged(void) {
    return (vmlab_cs_flags() & CS_DEBUGGED) != 0;
}

bool vmlab_has_entitlement(const char *name) {
    if (name == NULL) return false;
    SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
    if (task == NULL) return false;
    CFStringRef key = CFStringCreateWithCString(kCFAllocatorDefault, name, kCFStringEncodingUTF8);
    bool result = false;
    if (key != NULL) {
        CFTypeRef value = SecTaskCopyValueForEntitlement(task, key, NULL);
        if (value != NULL) {
            if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
                result = CFBooleanGetValue((CFBooleanRef)value);
            }
            CFRelease(value);
        }
        CFRelease(key);
    }
    CFRelease(task);
    return result;
}

int vmlab_probe_jit_mmap(void) {
    const size_t len = 16384;
    void *p = mmap(NULL, len, PROT_READ | PROT_WRITE | PROT_EXEC,
                   MAP_PRIVATE | MAP_ANON | MAP_JIT, -1, 0);
    if (p == MAP_FAILED) {
        return errno ? errno : -1;
    }
    munmap(p, len);
    return 0;
}

uint64_t vmlab_available_memory(void) {
    return (uint64_t)os_proc_available_memory();
}
