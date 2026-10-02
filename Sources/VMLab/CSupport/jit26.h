#ifndef VMLAB_JIT26_H
#define VMLAB_JIT26_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/// Result of allocating a split RW/RX JIT region and preparing it with the attached
/// debugger script (StikDebug universal.js / legacy.js protocol).
typedef struct {
    int step;          // last step reached (see vmlab_jit_step_name)
    int err;           // 0 on success, else errno or kern_return_t of the failing step
    uint64_t rw;       // writable alias address (0 if not created)
    uint64_t rx;       // executable alias address (0 if not created)
    uint64_t size;     // bytes
    int test_result;   // value returned by the generated test function (expect 42), -1 if not run
} vmlab_jit_region_t;

/// Allocate `size` bytes as a split RW/RX pair the way UTM's QEMU fork does on iOS 26:
/// mmap RX, vm_remap an alias, mprotect alias RX, hand the RX alias to the debugger with
/// `brk #0xf00d` (command 1) so TXM lets it execute, then make the original RW.
/// PRECONDITION: CS_DEBUGGED must be set and a StikDebug script attached; a `brk` without
/// the script attached kills the process. When `use_breakpoints` is false the brk calls are
/// skipped (useful for a dry run on a non-TXM device).
vmlab_jit_region_t vmlab_jit_region_create(size_t size, bool use_breakpoints);

/// Write `mov w0,#42; ret` through the RW alias, flush the icache, call it via the RX
/// alias. Returns the function's return value or -1 on refusal. May crash if the region
/// was not prepared (that is the whole point of the test).
int vmlab_jit_region_test(vmlab_jit_region_t *region);

/// Tell the attached script to detach (`brk #0xf00d`, command 0). PRECONDITION as above.
void vmlab_jit26_detach(void);

const char *vmlab_jit_step_name(int step);

#endif
