#include "jit26.h"

#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <sys/mman.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <libkern/OSCacheControl.h>

// --- StikDebug universal protocol -------------------------------------------------------
// Identical to the functions documented in StikJIT/INTEGRATION.md. x16 carries the
// command, x0/x1 the arguments; the script advances pc past the brk and sets x0 on return.

#if defined(__arm64__)
__attribute__((noinline, optnone, naked))
static void JIT26Detach(void) {
    __asm__ volatile(
        "mov x16, #0\n"
        "brk #0xf00d\n"
        "ret\n");
}

__attribute__((noinline, optnone, naked))
static void *JIT26PrepareRegion(void *address, size_t length) {
    __asm__ volatile(
        "mov x16, #1\n"
        "brk #0xf00d\n"
        "ret\n");
}
#else
static void JIT26Detach(void) {}
static void *JIT26PrepareRegion(void *address, size_t length) { return address; }
#endif

void vmlab_jit26_detach(void) {
    JIT26Detach();
}

enum {
    STEP_NONE = 0,
    STEP_MMAP_RX,
    STEP_VM_REMAP,
    STEP_MPROTECT_RX,
    STEP_PREPARE_BRK,
    STEP_MPROTECT_RW,
    STEP_DONE,
};

const char *vmlab_jit_step_name(int step) {
    switch (step) {
        case STEP_NONE: return "none";
        case STEP_MMAP_RX: return "mmap(RX)";
        case STEP_VM_REMAP: return "vm_remap(alias)";
        case STEP_MPROTECT_RX: return "mprotect(alias, RX)";
        case STEP_PREPARE_BRK: return "brk JIT26PrepareRegion";
        case STEP_MPROTECT_RW: return "mprotect(original, RW)";
        case STEP_DONE: return "done";
        default: return "?";
    }
}

vmlab_jit_region_t vmlab_jit_region_create(size_t size, bool use_breakpoints) {
    vmlab_jit_region_t r = { .step = STEP_NONE, .err = 0, .rw = 0, .rx = 0, .size = size, .test_result = -1 };

    // 1. Allocate the buffer. On iOS 26 UTM maps it RX first (not RW) so TXM accepts it.
    r.step = STEP_MMAP_RX;
    void *buf = mmap(NULL, size, PROT_READ | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (buf == MAP_FAILED) {
        r.err = errno;
        return r;
    }

    // 2. Create a second mapping of the same pages.
    r.step = STEP_VM_REMAP;
    vm_address_t alias = 0;
    vm_prot_t cur_prot = 0, max_prot = 0;
    kern_return_t kr = vm_remap(mach_task_self(), &alias, size, 0, VM_FLAGS_ANYWHERE,
                                mach_task_self(), (vm_address_t)buf, FALSE,
                                &cur_prot, &max_prot, VM_INHERIT_NONE);
    if (kr != KERN_SUCCESS) {
        r.err = (int)kr;
        munmap(buf, size);
        return r;
    }

    // 3. Alias becomes the executable view.
    r.step = STEP_MPROTECT_RX;
    if (mprotect((void *)alias, size, PROT_READ | PROT_EXEC) != 0) {
        r.err = errno;
        munmap((void *)alias, size);
        munmap(buf, size);
        return r;
    }

    // 4. Let the debugger script prepare every page of the RX view.
    r.step = STEP_PREPARE_BRK;
    void *prepared = (void *)alias;
    if (use_breakpoints) {
        prepared = JIT26PrepareRegion((void *)alias, size);
        if (prepared == NULL) {
            r.err = -1;
            munmap((void *)alias, size);
            munmap(buf, size);
            return r;
        }
    }

    // 5. Original becomes the writable view.
    r.step = STEP_MPROTECT_RW;
    if (mprotect(buf, size, PROT_READ | PROT_WRITE) != 0) {
        r.err = errno;
        munmap((void *)alias, size);
        munmap(buf, size);
        return r;
    }

    r.step = STEP_DONE;
    r.rw = (uint64_t)buf;
    r.rx = (uint64_t)prepared;
    return r;
}

int vmlab_jit_region_test(vmlab_jit_region_t *region) {
    if (region == NULL || region->step != STEP_DONE || region->rw == 0 || region->rx == 0) {
        return -1;
    }
#if defined(__arm64__)
    // mov w0, #42 ; ret
    const uint32_t code[2] = { 0x52800540u, 0xD65F03C0u };
    memcpy((void *)region->rw, code, sizeof(code));
    sys_icache_invalidate((void *)region->rx, sizeof(code));
    typedef int (*fn_t)(void);
    fn_t fn = (fn_t)region->rx;
    int result = fn();
    region->test_result = result;
    return result;
#else
    return -1;
#endif
}
